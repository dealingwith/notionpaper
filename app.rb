load 'config.rb'
require 'sinatra'
require './notionpaper'

enable :sessions

get '/' do
  return params[:error] if params[:error]
  # if filter_option was not passed in, and does not exist in session, try grabbing it from the config
  if (params[:filter_option].nil? && session[:filter_option].nil?)
    return '<a href="/config_database">Configure</a>' unless defined?(CONFIG)
    show_message = "Using values from config.rb"
    session[:db_id] = CONFIG['db_id']
    session[:filter_property] = CONFIG['chosen_filter_property_name']
    session[:filter_option] = CONFIG['chosen_filter_option_name']
  # else if filter_option was passed in, use that
  elsif (params[:filter_option])
    session[:filter_option] = params[:filter_option]
  # else use all values from session
  else
    show_message = "Using values from session"
  end
  # if we have everything we need to query...
  if (session[:db_id] || session[:filter_property] || session[:filter_option])
    config = {
      'db_id' => session[:db_id],
      'chosen_filter_property_name' => session[:filter_property],
      'chosen_filter_option_name' => session[:filter_option]
    }
    tasks = get_notion_tasks(config)
  # else, things have gone wrong
  else
    tasks = []
    show_message = "Session is empty: #{session.inspect}"
  end
  erb :index, locals: { tasks: tasks, show_message: show_message }
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
  erb :config_property, locals: { properties: chosen_database['properties'] }
end

get '/config_filter/?' do
  session[:filter_property] = filter_property = params[:filter_property]
  notionpaper = NotionPaper.new()
  databases_list = notionpaper.get_notion_databases()
  chosen_database = notionpaper.databases_results.find { |db| db['id'] == session[:db_id] }
  filter_options = chosen_database['properties'][filter_property]['select']['options']
  erb :config_filter, locals: { filter_options: filter_options }
end
