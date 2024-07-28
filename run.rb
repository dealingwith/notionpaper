# Set these variables in config.rb:
# NOTION_API_KEY = '[YOUR NOTION API KEY]'
# CONFIG = {
#   'db_id' => '[ID OF THE NOTION DATABASE YOU WANT TO ACCESS]',
#   'chosen_filter_property_name' => '[TO FILTER, PUT PROPERTY NAME HERE]', # e.g. 'Status'
#   'filter_options' => ['In Progress', 'Priority'] # <-- e.g.
# }
# CONFIG = nil # set to nil to use the interactive mode

require "erb"
# require "pdfkit"
require "./notionpaper"
require "awesome_print"
require "tty-prompt"
require "tty-spinner"
load "config.rb"

def cli_prompt_for_config_values()
  # prompt user for all options
  prompt = TTY::Prompt.new

  notionpaper = NotionPaper.new(NOTION_API_KEY)

  spinner = TTY::Spinner.new("[:spinner] Loading databases...", format: :dots)
  spinner.auto_spin # Automatic animation with default interval

  # present user with list of databases to choose from
  # see https://developers.notion.com/reference/database
  databases_list = notionpaper.get_notion_databases()

  spinner.success("Done!") # Stop animation

  # prompt user to choose a database
  chosen_database = prompt.select("Select database:", databases_list.map { |db| db[:title] })
  # get the database from the list
  chosen_database = databases_list.find { |db| db[:title] == chosen_database }
  # get the properties of the chosen database
  properties = chosen_database[:filter_properties]
  # get the names of the properties
  filter_choices = properties.map { |prop| prop[:name] }
  # add a "None" option
  filter_choices.unshift("None")
  # prompt user to choose a property to filter by
  chosen_filter_prop = prompt.select("Select property to filter by:", filter_choices)

  if chosen_filter_prop == "None"
    chosen_filter_prop = nil
    chosen_filter_options = nil
  else
    # get the property object
    chosen_filter_prop = properties.find { |prop| prop[:name] == chosen_filter_prop }
    # get the options of the chosen property
    filter_options = chosen_filter_prop[:options].map { |option| option["name"] }
    # prompt user to choose options to filter by
    chosen_filter_options = prompt.multi_select("Select option(s) to filter by:", filter_options)
  end

  # prompt user to choose whether to process subtasks
  process_subtasks = prompt.yes?("Process subtasks?")

  if process_subtasks
    # prompt user for parent property name
    parent_property_name = prompt.ask("What is your parent task property name (e.g. 'Parent Task')?")
  else
    parent_property_name = nil
  end

  # prompt user to choose whether to use output folder and/or date folder
  use_output_folder = prompt.yes?("Use output folder?")
  use_date_folder = prompt.yes?("Use date folder?")

  return {
           "db_id" => chosen_database[:id],
           "chosen_filter_property_name" => chosen_filter_prop&.[](:name),
           "filter_type" => chosen_filter_prop&.[](:type),
           "filter_options" => chosen_filter_options,
           "parent_property_name" => parent_property_name,
           "use_output_folder" => use_output_folder,
           "use_date_folder" => use_date_folder,
         }
end

prompt = TTY::Prompt.new
if (ARGV[0] && ARGV[0] == "--use-config")
  use_config = true
else
  use_config = prompt.yes?("Use values in config file?")
end

if (use_config && defined?(CONFIG) && CONFIG)
  config = CONFIG
else
  if (use_config && (!defined?(CONFIG) || !CONFIG))
    puts "No `CONFIG` found in config file."
  end
  config = cli_prompt_for_config_values()
end

puts "## Config:"
config.each { |key, value| puts "#{key}: #{value}" }

spinner = TTY::Spinner.new("[:spinner] Loading tasks...", format: :dots)
spinner.auto_spin # Automatic animation with default interval

# get all tasks
tasks = get_notion_tasks(config)
grouped_tasks = group_tasks_by(tasks, config)
if grouped_tasks
  File.write "tasks_grouped.json", JSON.pretty_generate(grouped_tasks)
end
tasks = process_subtasks(grouped_tasks, config)

File.write "tasks.json", JSON.pretty_generate(tasks)

# exit()

taskpaper_content = convert_to_taskpaper(tasks)
markdown_content = convert_to_markdown(tasks)

# use output and/or date-based folders for output
output_folder = nil
date_folder = nil
if config["use_output_folder"]
  output_folder = "output"
  Dir.mkdir(output_folder) unless Dir.exist?(output_folder)
end
if config["use_date_folder"]
  if config["use_output_folder"]
    date_folder = "#{output_folder}/#{Time.now.strftime("%Y-%m-%d")}"
  else
    date_folder = Time.now.strftime("%Y-%m-%d")
  end
  Dir.mkdir(date_folder) unless Dir.exist?(date_folder)
  output_folder = date_folder
end

# write to files
taskpaper_output_file = config["taskpaper_output_file"] || "notion.taskpaper"
File.write "#{output_folder}/#{taskpaper_output_file}", taskpaper_content

markdown_output_file = config["markdown_output_file"] || "notion.markdown"
File.write "#{output_folder}/#{markdown_output_file}", markdown_content

html_output_file = config["html_output_file"] || "notion.html"
html_content = ERB.new(File.read("views/_tasks.erb")).result(binding)
File.write "#{output_folder}/#{html_output_file}", html_content

spinner.success("Done!") # Stop animation
puts "Output files written to #{output_folder}"

# begin
#   PDFKit.new(html_content).to_file("notion.pdf")
# rescue Exception
#   puts "PDF generation failed"
# end
