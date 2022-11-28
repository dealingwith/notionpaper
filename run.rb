# Set these variables in config.rb:
# NOTION_API_KEY = '[YOUR NOTION API KEY]'
# NOTION_BASE_URL = '[YOUR NOTION BASE URL]' # for example https://www.notion.so/username/
# CONFIG = {
#   'db_id' => '[ID OF THE NOTION DATABASE YOU WANT TO ACCESS]',
#   'chosen_filter_property_name' => '[TO FILTER, PUT PROPERTY NAME HERE]', # e.g. 'Status'
#   'filter_options' => ['In Progress', 'Priority'] # <-- e.g.
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
  chosen_database = databases_list[gets.chomp.to_i]

  # present the properties to filter by
  # see https://developers.notion.com/reference/property-object
  puts "** Choose a property to filter by"
  puts "N: No filter"
  properties = chosen_database[:filter_properties]
  properties.each_with_index { |prop, index| puts "#{index}: #{prop[:name]}" }
  print "Enter the number of the property you want to use: "
  chosen_filter = gets.chomp
  chosen_filter_property = properties[chosen_filter.to_i]
  unless chosen_filter == 'N'
    # present the options for the chosen property to filter by
    # see https://developers.notion.com/reference/post-database-query-filter
    puts "** Choose option(s) for the property to filter by"
    chosen_filter_property[:options].each_with_index { |option, index| puts "#{index}: #{option['name']}" }
    print "Enter the number(s) of the option(s) you want to use (separated by spaces): "
    chosen_filter_options = gets.split.map {|option_index| chosen_filter_property[:options][option_index.to_i][:name]}
  end
  return {
    'db_id' => chosen_database[:id],
    'chosen_filter_property_name' => chosen_filter_property[:name],
    'filter_type' => chosen_filter_property[:type],
    'filter_options' => chosen_filter_options 
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
