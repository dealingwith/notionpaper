require "notion-ruby-client"
require "awesome_print"

class NotionPaper
  attr_reader :databases_results, :config, :session

  def initialize(notion_api_key, config = nil, session = nil)
    Notion.configure do |config|
      config.token = notion_api_key
    end
    @notion = Notion::Client.new
    @config = config
    @session = session
  end

  def get_notion_databases
    databases_list = []
    query = { "filter": { "value": "database", "property": "object" } }
    @notion.search(query) do |db|
      db[:results].each do |database|
        if (database[:title]&.first&.dig("plain_text"))
          db_obj = {
            :id => database[:id],
            :title => database[:title]&.first&.dig("plain_text"),
            :filter_properties => [],
          }
          database[:properties].each do |prop|
            filter_prop_options = {
              :name => nil,
              :type => nil,
              :options => nil,
            }
            type = prop[1][:type]
            if (type == "select" || type == "status")
              filter_prop_options[:name] = prop[0]
              filter_prop_options[:type] = type
              filter_prop_options[:options] = prop[1][type.to_sym][:options]
              db_obj[:filter_properties].push(filter_prop_options)
            end
          end
          databases_list.push db_obj
        end
      end
    end
    databases_list
  end

  def run_notion_query(db_id, sorts, filter)
    begin
      if (filter.nil?)
        @notion.database_query(database_id: db_id)
      else
        @notion.database_query(database_id: db_id, sorts: sorts, filter: filter)
      end
    rescue => exception
      puts exception
      false
    end
  end

  def get_notion_tasks
    notionpaper = self
    config = @config
    session = @session
    if config
      db_id = config["db_id"]
      chosen_filter_property_name = config["chosen_filter_property_name"]
      filter_type = config["filter_type"]
      filter_options = config["filter_options"]
    else
      return []
    end
    if !chosen_filter_property_name.nil? && !filter_options.nil?
      subquery = []
      filter_options.each { |option|
        subquery << {
          :property => chosen_filter_property_name,
          filter_type.to_sym => { equals: option },
        }
      }
      filter = {
        "or": subquery,
      }
      sorts = [
        {
          "property": chosen_filter_property_name,
          "direction": "descending",
        },
      ]
    else
      filter = nil
      sorts = nil
    end
    results = notionpaper.run_notion_query(db_id, sorts, filter)
    File.write "results.json", JSON.pretty_generate(results)
    if results
      tasks = results["results"]
    else
      tasks = []
    end
    tasks
  end

  def process_subtasks(tasks)
    config = @config
    return tasks unless config && config["parent_property_name"]
    subtasks = []
    tasks_no_subtasks = tasks.map do |task|
      task[:subtasks] = []
      task
    end
    tasks.each do |task|
      if (!task.dig("properties", config["parent_property_name"], "relation")&.length&.zero?)
        subtasks << task
        tasks_no_subtasks.delete_if { |t| t[:id] == task[:id] }
      end
    end
    subtasks.each do |subtask|
      tasks_no_subtasks.each do |task|
        if (task[:id] == subtask.dig("properties", config["parent_property_name"], "relation", 0, "id"))
          task[:subtasks] << subtask
        end
      end
    end
    tasks_no_subtasks
  end

  def group_tasks_by(tasks)
    config = @config
    return tasks unless config && config["group_by"] && config["group_by_type"]
    tasks.group_by do |task|
      task.dig("properties", config["group_by"], config["group_by_type"], "name") || "Inbox"
    end
  end

  def convert_grouped_to_markdown(grouped_tasks)
    markdown_content = ""
    grouped_tasks.each do |group, tasks|
      markdown_content << "## #{group}\n\n"
      if (tasks)
        markdown_content << convert_to_markdown(tasks)
      end
      markdown_content << "\n"
    end
    markdown_content
  end

  def convert_grouped_to_taskpaper(grouped_tasks)
    taskpaper_content = ""
    grouped_tasks.each do |group, tasks|
      taskpaper_content << "#{group}:\n"
      if (tasks)
        taskpaper_content << convert_to_taskpaper(tasks, "  ")
      end
      taskpaper_content << "\n"
    end
    taskpaper_content
  end

  def convert_title(title_array)
    title = title_array.map { |t| t["plain_text"].to_s.strip }.reject(&:empty?).join(" ")
    title = "Untitled" if title.empty?
    title
  end

  def convert_to_markdown(tasks)
    markdown_content = ""
    tasks.each do |task|
      title = convert_title(task.dig("properties", "Name", "title"))
      url = "#{task.dig("url")}"
      markdown_content << "- [ ] [#{title}](#{url})\n"
      unless task[:subtasks].nil?
        task[:subtasks].each do |subtask|
          subtask_title = subtask.dig("properties", "Name", "title", 0, "plain_text")
          subtask_title&.strip!
          subtask_title = "Untitled" if subtask_title.nil?
          subtask_url = "#{subtask.dig("url")}"
          markdown_content << "  - [ ] [#{subtask_title}](#{subtask_url})\n"
        end
      end
    end
    markdown_content
  end

  def convert_to_taskpaper(tasks, indent = "")
    taskpaper_content = ""
    tasks.each do |task|
      title = convert_title(task.dig("properties", "Name", "title"))
      taskpaper_content << "#{indent}- #{title}\n"
      unless task[:subtasks].nil?
        task[:subtasks].each do |subtask|
          subtask_title = subtask.dig("properties", "Name", "title", 0, "plain_text")
          subtask_title&.strip!
          subtask_title = "Untitled" if subtask_title.nil?
          taskpaper_content << "#{indent}  - #{subtask_title}\n"
        end
      end
    end
    taskpaper_content
  end

  def convert_to_logseq(tasks, indent = "")
    markdown_content = ""
    tasks.each do |task|
      title = convert_title(task.dig("properties", "Name", "title"))
      url = "#{task.dig("url")}"
      markdown_content << "#{indent}- TODO [#{title}](#{url})\n"
      unless task[:subtasks].nil?
        task[:subtasks].each do |subtask|
          subtask_title = subtask.dig("properties", "Name", "title", 0, "plain_text")
          subtask_title&.strip!
          subtask_title = "Untitled" if subtask_title.nil?
          subtask_url = "#{subtask.dig("url")}"
          markdown_content << "#{indent}  - TODO [#{subtask_title}](#{subtask_url})\n"
        end
      end
    end
    markdown_content
  end

  def convert_grouped_to_logseq(grouped_tasks)
    markdown_content = ""
    grouped_tasks.each do |group, tasks|
      markdown_content << "- ##{group}\n"
      if (tasks)
        markdown_content << convert_to_logseq(tasks, "  ")
      end
    end
    markdown_content
  end
end
