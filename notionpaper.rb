require "notion-ruby-client"
require "awesome_print"
require "byebug"

class NotionPaper
  attr_reader :databases_results

  def initialize(notion_api_key)
    Notion.configure do |config|
      config.token = notion_api_key
    end
    @notion = Notion::Client.new
  end

  public

  def get_notion_databases()
    # get all databases this API key has access to
    databases_list = []
    filter_options = []
    query = { "filter": { "value": "database", "property": "object" } }
    @notion.search(query) do |db|
      File.write "db.json", JSON.pretty_generate(db)
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
            if (type == "select" || type == "status") # || type == 'checkbox')
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
    return databases_list
  end

  def run_notion_query(db_id, sorts, filter)
    begin
      if (filter.nil?)
        return @notion.database_query(database_id: db_id)
      else
        return @notion.database_query(database_id: db_id, sorts: sorts, filter: filter)
      end
    rescue => exception
      puts exception
      return false
    end
  end

  def complete_task(notion_page_id, filter_property, filter_option, filter_option_data)
    # TODO
    # properties = {
    #   "#{filter_property}": {
    #     "#{filter_option}": filter_option_data
    #   }
    # }
    # ap "COMPLETE_TASK PROPERTIES:"
    # ap properties
    # @notion.update_page(page_id: notion_page_id, properties: properties)
  end
end

def get_notion_tasks(config = nil, session = nil)
  if (session&.[](:notion_access_token))
    # it came from Notion OAuth
    notionpaper = NotionPaper.new(session[:notion_access_token])
  elsif (defined?(NOTION_API_KEY))
    # it came from config.rb
    notionpaper = NotionPaper.new(NOTION_API_KEY)
  else
    return []
  end

  if (config)
    # load database and filter configs from passed-in values
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

  return tasks
end

def process_subtasks(grouped_tasks, config)
  return grouped_tasks unless config["parent_property_name"]

  # tasks_returned = Marshal.load(Marshal.dump(grouped_tasks))

  grouped_tasks.each do |group, tasks|
    puts "Group: #{group}"
    puts "Tasks: #{tasks.length}"

    File.write "tasks_in_process_subtasks.json", JSON.pretty_generate(tasks)

    subtasks = []
    tasks.map do |task|
      # add a subtasks array to each task
      task[:subtasks] = []
      begin
        # check if this task has a parent relation defined
        if (!task.dig("properties", config["parent_property_name"], "relation")&.length&.zero?)
          # this is a subtask
          subtasks << task
        end
      rescue => exception
        puts exception
        ap task
      end
    end
    break if subtasks.empty?

    File.write "tasks_in_process_subtasks_before_reject.json", JSON.pretty_generate(tasks)

    # remove subtasks from tasks
    begin
      tasks.reject! { |task| subtasks.include?(task) }
    rescue => exception
      puts exception
    end

    File.write "tasks_in_process_subtasks_after_reject.json", JSON.pretty_generate(tasks)

    # mutate tasks to add subtasks to parent tasks
    puts "Subtasks: #{subtasks.length}"
    # ap subtasks
    puts "Tasks: #{tasks.length}"
    subtasks.each do |subtask|
      ap tasks
      tasks.map do |task|
        # ap task
        # exit()
        begin
          if (task[:id] == subtask.dig("properties", config["parent_property_name"], "relation", 0, "id"))
            task[:subtasks] << subtask
          end
        rescue => exception
          puts "****************** EXCEPTION:"
          puts exception
          puts "********** Task:"
          ap task
          puts "********** Subtask:"
          ap subtask
          # exit()
        end
      end
    end
  end

  return grouped_tasks
end

def group_tasks_by(tasks, config)
  if (config["group_by"])
    grouped_tasks = tasks.group_by do |task|
      task.dig("properties", config["group_by"], "select", "name")
    end
  else
    grouped_tasks = { "Notion tasks" => tasks }
  end
  return grouped_tasks
end

def convert_to_markdown(tasks_no_subtasks)
  markdown_content = "Data fetched on #{Time.now.strftime("%Y-%m-%d %H:%M")}\n\n"

  tasks_no_subtasks.each do |task|
    title = task.dig("properties", "Name", "title", 0, "plain_text")
    title&.strip!
    title = "Untitled" if title.nil?
    url = "#{task.dig("url")}"
    markdown_content << "- [ ] [#{title}](#{url})\n"
    # create a sub-list of subtasks
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

  return markdown_content
end

def convert_to_taskpaper(grouped_tasks)
  taskpaper_content = "Data fetched on #{Time.now.strftime("%Y-%m-%d %H:%M")}\n\n"
  grouped_tasks.each do |group, tasks|
    taskpaper_content << "#{group}:\n"
    if (tasks)
      tasks.each do |task|
        title = task.dig("properties", "Name", "title", 0, "plain_text")
        title&.strip!
        title = "Untitled" if title.nil?
        taskpaper_content << "  - #{title}\n"
        # create a sub-list of subtasks
        unless task[:subtasks].nil?
          task[:subtasks].each do |subtask|
            subtask_title = subtask.dig("properties", "Name", "title", 0, "plain_text")
            subtask_title&.strip!
            subtask_title = "Untitled" if subtask_title.nil?
            taskpaper_content << "    - #{subtask_title}\n"
          end
        end
      end
    end
  end

  return taskpaper_content
end
