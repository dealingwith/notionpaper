# Set these variables in config.rb:
# NOTION_API_KEY = '[YOUR NOTION API KEY]'
# CONFIG = {
#   'db_id' => '[ID OF THE NOTION DATABASE YOU WANT TO ACCESS]',
#   'chosen_filter_property_name' => '[TO FILTER, PUT PROPERTY NAME HERE]', # e.g. 'Status'
#   'filter_options' => ['In Progress', 'Priority'] # <-- e.g.
# }
# CONFIG = nil # set to nil to use the interactive mode

require 'erb'
require 'pdfkit'
require './notionpaper'
require 'awesome_print'
load 'config.rb'

def cli_prompt_for_config_values()
  notionpaper = NotionPaper.new(NOTION_API_KEY)
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
  if chosen_filter == 'N'
    chosen_filter_property = nil
    chosen_filter_options = nil
  else
    chosen_filter_property = properties[chosen_filter.to_i]
    # present the options for the chosen property to filter by
    # see https://developers.notion.com/reference/post-database-query-filter
    puts "** Choose option(s) for the property to filter by"
    chosen_filter_property[:options].each_with_index { |option, index| puts "#{index}: #{option['name']}" }
    print "Enter the number(s) of the option(s) you want to use (separated by spaces): "
    chosen_filter_options = gets.split.map {|option_index| chosen_filter_property[:options][option_index.to_i][:name]}
  end
  print "Process subtasks? (y/n): "
  process_subtasks = gets.chomp.downcase
  if process_subtasks == 'y'
    print "What is your parent task property name (e.g. 'Parent Task')? "
    parent_property_name = gets.chomp
  else
    parent_property_name = nil
  end
  return {
    'db_id' => chosen_database[:id],
    'chosen_filter_property_name' => chosen_filter_property&.[](:name),
    'filter_type' => chosen_filter_property&.[](:type),
    'filter_options' => chosen_filter_options,
    'parent_property_name' => parent_property_name
  }
end

if (ARGV[0] && ARGV[0] == '--use-config')
  use_config = true
else
  print "Use values in config file? (y/n): "
  answer = gets.chomp
  use_config = (answer == 'y' || answer == 'Y')
end

if (use_config && defined?(CONFIG) && CONFIG)
  config = CONFIG
else
  if (use_config && (!defined?(CONFIG) || !CONFIG))
    puts "No `CONFIG` found in config file."
  end
  config = cli_prompt_for_config_values()
end

# get all tasks
tasks = get_notion_tasks(config)
tasks = process_subtasks(tasks, config)

taskpaper_content = convert_to_taskpaper(tasks)
markdown_content = convert_to_markdown(tasks)

File.write 'notion.taskpaper', taskpaper_content
File.write 'notion.markdown', markdown_content
html_content = ERB.new(File.read('views/_tasks.erb')).result(binding)
File.write 'notion.html', html_content
# begin
#   PDFKit.new(html_content).to_file("notion.pdf")
# rescue Exception
#   puts "PDF generation failed"
# end
