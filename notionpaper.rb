# require 'notion_ruby'
require 'notion-ruby-client'

class NotionPaper
  attr_reader :databases_results

  def initialize()
    # @notion = NotionRuby.new({ access_token: NOTION_API_KEY })
    Notion.configure do |config|
      config.token = NOTION_API_KEY
    end
    @notion = Notion::Client.new
  end

  public

  def get_notion_databases()
    # get all databases this API key has access to
    databases_list = []
    filter_options = []
    query = {"filter": {"value": "database", "property": "object"}}
    @notion.search(query) do |db|
      db[:results].each do |database|
        if (database[:title]&.first&.[](:plain_text))
          db_obj = {
            :id => database[:id],
            :title => database[:title]&.first&.[](:plain_text),
            :filter_properties => []
          }
          filter_prop_options = {
            :id => database[:id],
            :name => '',
            :type => '',
            :options => []
          }
          database[:properties].each do |prop|
            type = prop[1][:type]
            if (type == 'select' || type == 'status' || type == 'checkbox')
              filter_prop_options[:name] = prop[1][:name]
              filter_prop_options[:type] = type
              filter_prop_options[:options].push prop[1][type.to_sym][:options]
              filter_options.push(filter_prop_options)
            end
          end
          databases_list.push db_obj
        end
      end
    end
    return [databases_list, filter_options]
  end

  def run_notion_query(db_id, query)
    puts query
    begin
      @notion.databases(db_id).query(query)
    rescue => exception
      puts exception
      return false
    end
  end

end

def get_notion_tasks(config=nil)
  notionpaper = NotionPaper.new()

  if (config)
    # load database and filter configs from passed-in values
    db_id = config['db_id']
    chosen_filter_property_name = config['chosen_filter_property_name']
    filter_type = config['filter_type']
    filter_options = config['filter_options']
  else
    return
  end

  if !chosen_filter_property_name.nil?
    if !filter_options.nil?
      subquery = []
      filter_options.each { |option|
        subquery << {
          :property => chosen_filter_property_name,
          filter_type.to_sym => { equals: option }
        }
      }
      query = {
        "filter": {
          "or": subquery
        },
        page_size: 100
      }
    else
      query = { page_size: 100 }
    end
  else
    query = { page_size: 100 }
  end
  query[:sorts] = [
    {
        "property": chosen_filter_property_name,
        "direction": "descending"
    }
  ]
  results = notionpaper.run_notion_query(db_id, query)
  if results
    tasks = results['results']
  else
    tasks = []
  end

  # File.write 'tasks.rb', tasks.to_s # for debugging

  return tasks
end
