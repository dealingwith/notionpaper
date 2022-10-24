load 'config.rb'
require 'sinatra'
require './notionpaper'

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
