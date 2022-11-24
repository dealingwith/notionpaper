load 'config.rb'
require 'sinatra'
require './notionpaper'

enable :sessions

get '/' do
  return params[:error] if params[:error]
  # if filter_option was not passed in, and does not exist in session, try grabbing it from the config
  if (defined?(CONFIG) && session[:filter_options].nil?)
    show_message = "Using values from config.rb"
    session[:db_id] = CONFIG['db_id']
    session[:filter_property] = CONFIG['chosen_filter_property_name']
    params[:filter_type] = CONFIG['filter_type']
    session[:filter_options] = CONFIG['filter_options']
  # else if filter_options was passed in, use that
  elsif (params[:filter_options])
    session[:filter_options] = params[:filter_options].split(',')
  # else use all values from session
  else
    show_message = "Using values from session"
  end
  # if we have everything we need to query...
  if (session[:db_id] && session[:filter_property] && session[:filter_type] && session[:filter_options])
    config = {
      'db_id' => session[:db_id],
      'chosen_filter_property_name' => session[:filter_property],
      'filter_type' => session[:filter_type],
      'filter_options' => session[:filter_options]
    }
    tasks = get_notion_tasks(config)
  # else, things have gone wrong
  else
    tasks = []
    show_message = "Session is empty: #{session.inspect}"
  end
  erb :index, locals: { tasks: tasks, show_message: show_message, filter_options_data: session[:filter_options_data] }
end

get '/complete_task/:id' do
  redirect '/?error=No session' if session[:filter_property].nil?
  notion_page_id = params[:id].tr("-", "")
  notion = NotionRuby.new({ access_token: NOTION_API_KEY })
  notion_update_payload = {
    properties: {
      "#{session[:filter_property]}": { select: { name: 'Done' } }
    }
  }
  notion.pages(notion_page_id).update(notion_update_payload)
  redirect '/'
  # leaving this in for future debugging:
  # erb :complete_task, locals: { notion_update_payload: notion_update_payload }
end

get '/api/complete_task/:id' do
  notion_page_id = params[:id].tr("-", "")
  notion = NotionRuby.new({ access_token: NOTION_API_KEY })
  notion_update_payload = {
    properties: {
      "#{session[:filter_property]}": { select: { name: 'Done' } }
    }
  }
  notion.pages(notion_page_id).update(notion_update_payload)
  config = {
    'db_id' => session[:db_id],
    'chosen_filter_property_name' => session[:filter_property],
    'filter_options' => session[:filter_options]
  }
  tasks = get_notion_tasks(config)
  erb '_tasks'.to_sym, locals: { tasks: tasks, filter_options_data: session[:filter_options_data] }, layout: false
end

get '/config_database/?' do
  notionpaper = NotionPaper.new()
  databases_list = notionpaper.get_notion_databases()
  erb :config_database, locals: { databases_list: databases_list }
end

get '/config_property/?' do
  session[:db_id] = db_id = params[:db_id]
  notionpaper = NotionPaper.new()
  databases_list = notionpaper.get_notion_databases()
  chosen_database = notionpaper.databases_results.find { |db| db['id'] == db_id }
  available_properties = []
  chosen_database['properties'].each do |property|
    # 11/24/2022: having issues querying for 'status', skipping for now
    if (property[1]['type'] == 'select') # || property[1]['type'] == 'status' || property[1]['type'] == 'checkbox')
      available_properties << [property[0], property[1]['type']]
    end
  end
  erb :config_property, locals: { properties: available_properties }
end

get '/config_filter/?' do
  session[:filter_property] = filter_property = params[:filter_property]
  session[:filter_type] = filter_type = params[:filter_type]
  notionpaper = NotionPaper.new()
  databases_list = notionpaper.get_notion_databases()
  chosen_database = notionpaper.databases_results.find { |db| db['id'] == session[:db_id] }
  filter_options_data = chosen_database['properties'][filter_property][filter_type]['options']
  session[:filter_options_data] = filter_options_data
  erb :config_filter, locals: { filter_options_data: filter_options_data }
end
