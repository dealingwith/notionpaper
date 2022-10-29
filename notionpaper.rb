require 'notion_ruby'
require 'redcarpet'
require 'awesome_print'

class CustomRender < Redcarpet::Render::HTML
  def list_item(text, list_type)
    notion_page_id = text.match(/ID:\[(.*)\]/)[1]
    text.sub!('[ ]', '<input type="checkbox">')
    %(<li style="list-style: none" onClick="location.href='/complete_task/#{notion_page_id}'">#{text}</li>)
  end
end

class NotionPaper
  def initialize()
    @notion = NotionRuby.new({ access_token: NOTION_API_KEY })
  end

  def get_notion_databases()
    # get all databases this API key has access to
    databases = @notion.databases
    @databases_results = databases['results']
    File.write 'databases_to_json.json', databases # for debugging
    databases_list = []
    @databases_results.each_with_index { |db, index|
      id = db['id']
      title = db['title'][0]['plain_text']
      databases_list << { id: id, title: title }
    }
    return databases_list
  end

  def run_notion_query(db_id, query)
    @notion.databases(db_id).query(query)
  end

  def cli_prompt_for_config_values()
    # prompt user for all options
    databases_list = get_notion_databases()

    # present user with list of databases to choose from
    # see https://developers.notion.com/reference/database
    puts "** Databases"
    databases_list.each_with_index { |db, index| puts "#{index}: #{db[:title]}" }
    print "Enter the number of the database you want to use: "
    db_index = gets.chomp.to_i
    # get the database ID
    db_id = databases_list[db_index][:id]
    # get the database's info
    chosen_database = @databases_results[db_index]

    # present the properties to filter by
    # see https://developers.notion.com/reference/property-object
    puts "** Choose a property to filter by"
    puts "N: No filter"
    properties = chosen_database['properties']
    properties.each_with_index { |prop, index| puts "#{index}: #{prop[1]['name']}" }
    print "Enter the number of the property you want to use: "
    chosen_filter = gets.chomp
    unless chosen_filter == 'N'
      chosen_filter_property = chosen_filter.to_i
      chosen_filter_property_name = properties.keys[chosen_filter_property]

      # present the options for the chosen property to filter by
      # see https://developers.notion.com/reference/post-database-query-filter
      puts "** Choose an option for the property to filter by"
      chosen_filter_property_options = properties[chosen_filter_property_name]['select']['options']
      chosen_filter_property_options.each_with_index { |option, index| puts "#{index}: #{option['name']}" }
      print "Enter the number of the option you want to use: "
      chosen_filter_option = gets.chomp.to_i
      chosen_filter_option_name = chosen_filter_property_options[chosen_filter_option]['name']
    end
    return [db_id, chosen_filter_property_name, chosen_filter_option_name]
  end
end

def create_notionpaper_files(config=nil)
  notionpaper = NotionPaper.new()
  if (config)
    # load database and filter configs from passed-in values
    db_id, chosen_filter_property_name, chosen_filter_option_name = config['db_id'], config['chosen_filter_property_name'], config['chosen_filter_option_name']
  else
    db_id, chosen_filter_property_name, chosen_filter_option_name = *notionpaper.cli_prompt_for_config_values()
  end

  unless chosen_filter_property_name.nil? || chosen_filter_option_name.nil?
    query = {
      "filter": {
        "property": chosen_filter_property_name,
        "select": {
          "equals": chosen_filter_option_name
        }
      },
      page_size: 100
    }
  else
    query = { page_size: 100 }
  end

  results = notionpaper.run_notion_query(db_id, query)
  tasks = results['results']

  File.write 'tasks.rb', tasks.to_s # for debugging

  taskpaper_content = ''
  markdown_content = ''

  tasks.each do |task|
    title = task.dig('properties', 'Name', 'title', 0, 'plain_text')
    next if title.nil?
    title.strip!
    url = "#{NOTION_BASE_URL}#{title.tr(" ", "-")}-#{task['id'].tr("-", "")}"
    taskpaper_content << "- #{title}\n"
    taskpaper_content << "  #{url}\n"
    markdown_content << "- [ ] ID:[#{task['id'].tr("-", "")}] [#{title}](#{url})\n"
  end

  File.write 'notion.taskpaper', taskpaper_content
  File.write 'notion.markdown', markdown_content
  File.write 'notion.html', Redcarpet::Markdown.new(CustomRender).render(markdown_content)
end
