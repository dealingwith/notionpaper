require 'notion_ruby'
class NotionPaper
  attr_reader :databases_results

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

end

def get_notion_tasks(config=nil)
  notionpaper = NotionPaper.new()

  if (config)
    # load database and filter configs from passed-in values
    db_id = config['db_id']
    chosen_filter_property_name = config['chosen_filter_property_name']
    chosen_filter_option_name = config['chosen_filter_option_name']
    chosen_multifilter_option_names = config['chosen_multifilter_option_names']
  else
    return
  end

  if !chosen_filter_property_name.nil?
    if !chosen_multifilter_option_names.nil?
      query = {
        "filter": {
          "or": [
            {
              "property": chosen_filter_property_name,
              "select": {
                "equals": chosen_multifilter_option_names[0]
              }
            },
            {
              "property": chosen_filter_property_name,
              "select": {
                "equals": chosen_multifilter_option_names[1]
              }
            }
          ]
        },
        page_size: 100
      }
      p query
    elsif !chosen_filter_option_name.nil?
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
  else
    query = { page_size: 100 }
  end

  results = notionpaper.run_notion_query(db_id, query)
  tasks = results['results']

  File.write 'tasks.rb', tasks.to_s # for debugging

  return tasks
end
