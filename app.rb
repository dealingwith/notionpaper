load 'config.rb'
require 'sinatra'
require './notionpaper'

enable :sessions

get '/' do
  File.read('notion.html')
end

get '/refresh/?' do
  if params[:filter_option].nil? && session[:filter_option].nil?
    create_notionpaper_files(CONFIG)
  else
    session[:filter_option] = params[:filter_option] unless params[:filter_option].nil?
    create_notionpaper_files({
      'db_id' => session[:db_id],
      'chosen_filter_property_name' => session[:property_name],
      'chosen_filter_option_name' => session[:filter_option]
    })
  end
  redirect '/'
end

get '/complete_task/:id' do
  notion_page_id = params[:id].tr("-", "")
  notion = NotionRuby.new({ access_token: NOTION_API_KEY })
  notion.pages(notion_page_id).update({ properties: { Status: { select: { name: 'Done' } } } })
  redirect '/'
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
  session[:property_name] = property_name = params[:property_name]
  notionpaper = NotionPaper.new()
  databases_list = notionpaper.get_notion_databases()
  chosen_database = notionpaper.databases_results.find { |db| db['id'] == session[:db_id] }
  filter_options = chosen_database['properties'][property_name]['select']['options']
  erb :config_filter, locals: { filter_options: filter_options }
end
