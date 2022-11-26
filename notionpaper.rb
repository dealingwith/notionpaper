# require 'notion_ruby'
require 'notion-ruby-client'
require 'awesome_print'

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
        if (database[:title]&.first&.dig('plain_text'))
          db_obj = {
            :id => database[:id],
            :title => database[:title]&.first&.dig('plain_text'),
            :filter_properties => []
          }
          database[:properties].each do |prop|
            filter_prop_options = {
              :name => nil,
              :type => nil,
              :options => nil
            }
            type = prop[1][:type]
            if (type == 'select') # || type == 'status' || type == 'checkbox')
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
      @notion.database_query(database_id: db_id, sorts: sorts, filter: filter)
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
      filter = {
        "or": subquery
      }
    else
      filter = { }
    end
  else
    filter = { }
  end
  sorts = [
    {
        "property": chosen_filter_property_name,
        "direction": "descending"
    }
  ]
  results = notionpaper.run_notion_query(db_id, sorts, filter)
  if results
    tasks = results['results']
  else
    tasks = []
  end

  # File.write 'tasks.rb', tasks.to_s # for debugging

  return tasks
end
