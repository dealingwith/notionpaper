load 'config.rb'
require 'erb'
require 'pdfkit'
require 'awesome_print'
require 'sinatra'
require 'csv'
require 'faraday'
require 'moneta'
require 'moneta/adapters/file'
require './notionpaper'

enable :sessions

def initialize
  super()
  # initialize the Moneta store
  @store = Moneta.new(:File, dir: 'data')
end

# this magically allows sessions to persist across server restarts
configure do
  set :session_secret, SESSION_SECRET
end

before do
  @development = ENV['RACK_ENV'] == 'development'
  if request.get?
    # if there is a session, try to load data from Moneta store
    if (session[:session_id])
      @session_data = get_session_from_moneta
      return
    end
    @session_data = {}
  end
end

after do
  if request.get?
    # if there is a session, try to save data to Moneta store
    if (session[:session_id])
      save_session_to_moneta(@session_data)
    end
  end
end

get '/' do
  # last config screen was subtasks, so we'll store that in session
  if (params&.[](:parent_property_name))
    @session_data[:parent_property_name] = params[:parent_property_name] == '' ? nil : params[:parent_property_name]
  end

  # if NOTION_API_KEY is defined in config.rb
  if (defined?(NOTION_API_KEY))
    notion_access_token = @session_data[:notion_access_token] = NOTION_API_KEY
  else # grab the access token from the session
    notion_access_token = @session_data[:notion_access_token] || nil
  end

  # if NOTION_CLIENT_ID is defined in config.rb
  if (defined?(NOTION_CLIENT_ID))
    notion_client_id = NOTION_CLIENT_ID
  else
    notion_client_id = nil
  end

  # if NGROK_URL is defined in config.rb
  if (defined?(NGROK_URL))
    ngrok_url = NGROK_URL
  else
    ngrok_url = nil
  end

  tasks, show_message = get_tasks

  erb :index, locals: {
    tasks: tasks,
    show_message: show_message,
    filter_options: @session_data[:filter_options],
    ngrok_url: ngrok_url,
    notion_client_id: notion_client_id,
    notion_access_token: notion_access_token
  }
end

get '/notion_auth' do
  puts "-----------------"
  puts "We're back from Notion auth!"

  # using Faraday
  conn = Faraday.new(
    url: 'https://api.notion.com/v1/oauth/token',
    headers: {
      'Content-Type' => 'application/json'
    }) do |conn|
    conn.request :authorization, :basic, NOTION_CLIENT_ID, NOTION_OAUTH_CLIENT_SECRET
  end

  response = conn.post do |req|
    req.body = {code: params[:code], grant_type: "authorization_code", redirect_uri: "#{NGROK_URL}/notion_auth"}.to_json
  end

  @session_data[:notion_access_token] = JSON.parse(response.body)['access_token']

  redirect '/'
end

get '/complete_task/:id' do
  # TODO
  # redirect '/?error=No session' if session[:filter_property].nil?

  # notion_page_id = params[:id].tr("-", "")
  # notion = NotionPaper.new()
  # notion.complete_task(notion_page_id, session[:filter_property], session[:filter_type], 'Done')
  # puts "Completed task #{notion_page_id}"
  # redirect '/'
  # leaving this in for future debugging:
  # erb :complete_task, locals: { notion_update_payload: notion_update_payload }
end

get '/api/complete_task/:id' do
  # TODO
  # notion_page_id = params[:id].tr("-", "")
  # notion = NotionRuby.new({ access_token: NOTION_API_KEY })
  # notion_update_payload = {
  #   properties: {
  #     "#{session[:filter_property]}": { select: { name: 'Done' } }
  #   }
  # }
  # notion.pages(notion_page_id).update(notion_update_payload)
  # config = {
  #   'db_id' => session[:db_id],
  #   'chosen_filter_property_name' => session[:filter_property],
  #   'filter_options' => session[:filter_options]
  # }
  # tasks = get_notion_tasks(config)
  # erb '_tasks'.to_sym, locals: { tasks: tasks, filter_options_data: session[:filter_options_data] }, layout: false
end

get '/config_database/?' do
  notionpaper = NotionPaper.new(@session_data[:notion_access_token])
  @session_data[:databases_list] = notionpaper.get_notion_databases()
  erb :config_database, locals: { databases_list: @session_data[:databases_list] }
end

get '/config_property/?' do
  @session_data[:db_id] = db_id = params[:db_id]
  chosen_database = @session_data[:databases_list].find { |db| db[:id] == db_id }
  erb :config_property, locals: { properties: chosen_database[:filter_properties] }
end

get '/config_filter/?' do
  @session_data[:filter_property] = filter_property = params[:filter_property]
  @session_data[:filter_type] = filter_type = params[:filter_type]
  chosen_database = @session_data[:databases_list].find { |db| db[:id] == @session_data[:db_id] }
  filter_options = chosen_database[:filter_properties].find { |prop| prop[:name] == filter_property }[:options]
  erb :config_filter, locals: { filter_options: filter_options }
end

get '/config_subtasks/?' do
  if (params[:filter_options])
    @session_data[:filter_options] = params[:filter_options].split(',')
  end
  erb :config_subtasks
end

get '/download_markdown' do
  session_id = session.id # session[:session_id]

  tasks, _ = get_tasks

  # convert to markdown
  markdown_content = convert_to_markdown(tasks)

  Tempfile.open("#{session_id}_tasksheet.markdown", "/tmp/") do |f|
    f.write(markdown_content)
    f.rewind
    send_file(f.path, :filename => "tasksheet.markdown")
  end
end

get '/download_taskpaper' do
  session_id = session.id # session[:session_id]

  tasks, _ = get_tasks

  # convert to taskpaper
  taskpaper_content = convert_to_taskpaper(tasks)

  Tempfile.open("#{session_id}_tasksheet.taskpaper", "/tmp/") do |f|
    f.write(taskpaper_content)
    f.rewind
    send_file(f.path, :filename => "tasksheet.taskpaper")
  end
end

get '/download_pdf' do
  session_id = session.id # session[:session_id]

  tasks, _ = get_tasks

  pdf_content = PDFKit.new(ERB.new(File.read('views/_tasks.erb')).result(binding)).to_pdf

  Tempfile.open("#{session_id}_tasksheet.pdf", "/tmp/") do |f|
    f.write(pdf_content)
    f.rewind
    send_file(f.path, :filename => "tasksheet.pdf")
  end
end

get '/download_csv' do
  tasks, _ = get_tasks(false)
  temp_file = Tempfile.new('tasksheet.csv')

  CSV.open(temp_file, "w") do |csv|
    csv << ['Task', 'URL']
    tasks.each do |task|
      title = task.dig('properties', 'Name', 'title', 0, 'plain_text')
      title&.strip!
      title = 'Untitled' if title.nil? || title == ''
      csv << [title, "#{task.dig('url')}"]
    end
  end

  send_file(temp_file.path, :filename => "tasksheet.csv")
end

def get_tasks(do_subtasks = true)
  # if everything required is stored in session, we'll use that
  if (@session_data[:db_id] && @session_data[:filter_property] && @session_data[:filter_type] && @session_data[:filter_options])
    show_message = "Using values from session"
  # else try grabbing data out of the config
  elsif (defined?(CONFIG))
    show_message = "Using values from config.rb and/or session"
    @session_data[:db_id] = @session_data[:db_id] || CONFIG['db_id']
    @session_data[:filter_property] = @session_data[:filter_property] || CONFIG['chosen_filter_property_name']
    @session_data[:filter_type] = @session_data[:filter_type] || CONFIG['filter_type']
    @session_data[:filter_options] = @session_data[:filter_options] || CONFIG['filter_options']
    @session_data[:parent_property_name] = @session_data[:parent_property_name] || CONFIG['parent_property_name'] || nil
  end

  # if we have everything we need to query...
  if (@session_data[:db_id] && @session_data[:filter_property] && @session_data[:filter_type] && @session_data[:filter_options])
    config = {
      'db_id' => @session_data[:db_id],
      'chosen_filter_property_name' => @session_data[:filter_property],
      'filter_type' => @session_data[:filter_type],
      'filter_options' => @session_data[:filter_options]
    }
    if (@session_data[:parent_property_name])
      config['parent_property_name'] = @session_data[:parent_property_name]
    end

    # get all tasks
    tasks = get_notion_tasks(config, @session_data)
    tasks = process_subtasks(tasks, config) if tasks && do_subtasks
  else # things have gone wrong, or it's just the first time the user has visited the page
    tasks = []
    show_message = "Session is empty"
  end
  [tasks, show_message]
end

def save_session_to_moneta(values=nil)
  session_data = get_session_from_moneta
  session_data.merge!(values) if values

  @store.store(session[:session_id], session_data)
end

def get_session_from_moneta
  session_data = @store.load(session[:session_id])

  if (session_data.nil?) # if we can't find the session in the store, we'll just return
    return {}
  end

  return session_data
end
