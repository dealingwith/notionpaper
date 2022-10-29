load 'config.rb'
require 'sinatra'
require './notionpaper'

enable :sessions

get '/' do
  File.read('notion.html')
end

get '/refresh' do
  create_notionpaper_files(CONFIG)
  redirect '/'
end

get '/complete_task/:id' do
  notion_page_id = params[:id].tr("-", "")
  notion = NotionRuby.new({ access_token: NOTION_API_KEY })
  notion.pages(notion_page_id).update({ properties: { Status: { select: { name: 'Done' } } } })
  redirect '/'
end

get '/config_database' do
  notionpaper = NotionPaper.new()
  databases_list = notionpaper.get_notion_databases()
  erb :config_database, locals: { databases_list: databases_list }
end

get '/config_property' do
  database_id = params[:db_id]
  notionpaper = NotionPaper.new()
  databases_list = notionpaper.get_notion_databases()
  chosen_database = notionpaper.databases_results.find { |db| db['id'] == database_id }
  erb :config_property, locals: { properties: chosen_database['properties'] }
end
