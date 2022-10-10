require 'sinatra'
require './notionpaper'

# TODO: figure out how to get Sinatra to hot-reload the app when the files change
get '/' do
  File.read('notion.html')
end

get '/refresh' do
  create_notionpaper_files()
  redirect '/'
end

get '/complete_task/:id' do
  notion_page_id = params[:id].tr("-", "")
  notion = NotionRuby.new({ access_token: NOTION_API_KEY })
  notion.pages(notion_page_id).update({ properties: { Status: { select: { name: 'Done' } } } })
  redirect '/'
end
