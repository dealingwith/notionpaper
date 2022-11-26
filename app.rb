load 'config.rb'
require 'awesome_print'
require 'sinatra'
require './notionpaper'

enable :sessions

get '/' do
  return params[:error] if params[:error]
  # if filter_options was passed in, use that
  if (params[:filter_options])
    session[:filter_options] = params[:filter_options].split(',')
  # if everything is stored in session, we'll use that
  elsif (session[:db_id] && session[:filter_property] && session[:filter_type] && session[:filter_options])
    show_message = "Using values from session"
  # try grabbing data out of the config
  elsif (defined?(CONFIG))
    show_message = "Using values from session OR config.rb"
    session[:db_id] = session[:db_id] || CONFIG['db_id']
    session[:filter_property] = session[:filter_property] || CONFIG['chosen_filter_property_name']
    session[:filter_type] = session[:filter_type] || CONFIG['filter_type']
    session[:filter_options] = session[:filter_options] || CONFIG['filter_options']
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
  session[:databases_list], session[:filter_options] = *notionpaper.get_notion_databases()
  ap session[:databases_list]
  ap session[:filter_options]
  erb :config_database, locals: { databases_list: session[:databases_list] }
end

get '/config_property/?' do
  session[:db_id] = db_id = params[:db_id]
  chosen_database = session[:databases_list].find { |db| db[:id] == db_id }
  filter_options = session[:filter_properties].select { |prop| prop[:id] == db_id && prop[:type] == 'select' }
  filter_options = filter_options.map { |prop| prop[:options] }
  ap "FILTER_OPTIONS"
  ap filter_options
  erb :config_property, locals: { properties: filter_options }
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
