# Set these variables in config.rb:
# NOTION_API_KEY = '[YOUR NOTION API KEY]'
# NOTION_BASE_URL = '[YOUR NOTION BASE URL]' # for example https://www.notion.so/username/
# CONFIG = {
#   'db_id' => '[ID OF THE NOTION DATABASE YOU WANT TO ACCESS]',
#   'chosen_filter_property_name' => '[TO FILTER, PUT PROPERTY NAME HERE]', # e.g. 'Status'
#   'chosen_filter_option_name' => '[PUT VALUE TO FILTER BY HERE]' # e.g. 'Todo'
# }
# CONFIG = nil # set to nil to use the interactive mode

require 'redcarpet'
require 'pdfkit'
require './notionpaper'
load 'config.rb'

class CustomRender < Redcarpet::Render::HTML
  def list_item(text, list_type)
    notion_page_id = text.match(/ID:\[(.*)\]/)[1]
    text.sub!('[ ]', '<input type="checkbox">')
    %(<li style="list-style: none" onClick="location.href='/complete_task/#{notion_page_id}'">#{text}</li>)
  end
end

def cli_prompt_for_config_values()
  notionpaper = NotionPaper.new()
  # prompt user for all options
  databases_list = notionpaper.get_notion_databases()

  # present user with list of databases to choose from
  # see https://developers.notion.com/reference/database
  puts "** Databases"
  databases_list.each_with_index { |db, index| puts "#{index}: #{db[:title]}" }
  print "Enter the number of the database you want to use: "
  db_index = gets.chomp.to_i
  # get the database ID
  db_id = databases_list[db_index][:id]
  # get the database's info
  chosen_database = notionpaper.databases_results[db_index]

  # present the properties to filter by
  # see https://developers.notion.com/reference/property-object
  puts "** Choose a property to filter by"
  puts "N: No filter"
  properties = chosen_database['properties']
  properties.each_with_index { |prop, index| puts "#{index}: #{prop[1]['name']}" }
  print "Enter the number of the property you want to use: "
  chosen_filter = gets.chomp
  unless chosen_filter == 'N'
    chosen_filter_property = chosen_filter.to_i
    chosen_filter_property_name = properties.keys[chosen_filter_property]

    # present the options for the chosen property to filter by
    # see https://developers.notion.com/reference/post-database-query-filter
    puts "** Choose an option for the property to filter by"
    chosen_filter_property_options = properties[chosen_filter_property_name]['select']['options']
    chosen_filter_property_options.each_with_index { |option, index| puts "#{index}: #{option['name']}" }
    print "Enter the number of the option you want to use: "
    chosen_filter_option = gets.chomp.to_i
    chosen_filter_option_name = chosen_filter_property_options[chosen_filter_option]['name']
  end
  return {
    'db_id' => db_id,
    'chosen_filter_property_name' => chosen_filter_property_name,
    'chosen_filter_option_name' => chosen_filter_option_name
  }
end

print "Use values in config file? (y/n): "
use_config = gets.chomp

if ((use_config == 'y' || use_config == 'Y') && CONFIG)
  config = CONFIG
else
  config = cli_prompt_for_config_values()
end

tasks = get_notion_tasks(config)

taskpaper_content = ''
markdown_content = ''

tasks.each do |task|
  title = task.dig('properties', 'Name', 'title', 0, 'plain_text')
  next if title.nil?
  title.strip!
  url = "#{NOTION_BASE_URL}#{title.tr(" ", "-")}-#{task['id'].tr("-", "")}"
  taskpaper_content << "- #{title}\n"
  taskpaper_content << "  #{url}\n"
  markdown_content << "- [ ] ID:[#{task['id'].tr("-", "")}] [#{title}](#{url})\n"
end

File.write 'notion.taskpaper', taskpaper_content
File.write 'notion.markdown', markdown_content
html_content = Redcarpet::Markdown.new(CustomRender).render(markdown_content)
File.write 'notion.html', html_content
PDFKit.new(html_content).to_file("notion.pdf")
