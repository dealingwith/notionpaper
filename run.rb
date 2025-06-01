# main CLI script to fetch tasks from Notion and convert them to TaskPaper, Markdown, Logseq, and HTML formats.

# require "awesome_print"

require "erb"
require File.expand_path("./notionpaper.rb", File.dirname(__FILE__))
require "tty-prompt"
require "tty-spinner"
load File.expand_path("./config.rb", File.dirname(__FILE__))

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

notionpaper = NotionPaper.new(NOTION_API_KEY, config)
tasks = notionpaper.get_notion_tasks
if config["parent_property_name"]
  tasks = notionpaper.process_subtasks(tasks)
end
if config["group_by"] && config["group_by_type"]
  tasks = notionpaper.group_tasks_by(tasks)
end
taskpaper_content = "Data fetched on #{Time.now.strftime("%Y-%m-%d %H:%M")}\n\n"
markdown_content = "Data fetched on #{Time.now.strftime("%Y-%m-%d %H:%M")}\n\n"
logseq_content = "- Data fetched on #{Time.now.strftime("%Y-%m-%d %H:%M")}\n"
if (config["group_by"] && config["group_by_type"])
  taskpaper_content << notionpaper.convert_grouped_to_taskpaper(tasks)
  markdown_content << notionpaper.convert_grouped_to_markdown(tasks)
  logseq_content << notionpaper.convert_grouped_to_logseq(tasks)
else
  taskpaper_content << notionpaper.convert_to_taskpaper(tasks)
  markdown_content << notionpaper.convert_to_markdown(tasks)
  logseq_content << notionpaper.convert_to_logseq(tasks)
end
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
taskpaper_output_file = config["taskpaper_output_file"] || "notion.taskpaper"
File.write "./#{output_folder}/#{taskpaper_output_file}", taskpaper_content
logseq_output_file = config["logseq_output_file"] || "notion_logseq.md"
File.write "./#{output_folder}/#{logseq_output_file}", logseq_content
markdown_output_file = config["markdown_output_file"] || "notion.markdown"
File.write "./#{output_folder}/#{markdown_output_file}", markdown_content
html_output_file = config["html_output_file"] || "notion.html"
html_template = config["group_by"] ? "_grouped_tasks.erb" : "_tasks.erb"
html_content = ERB.new(File.read(File.expand_path("views/#{html_template}", File.dirname(__FILE__)))).result(binding)
File.write "./#{output_folder}/#{html_output_file}", html_content

spinner.success("Done!") # Stop animation
puts "Output files written to #{output_folder}"
