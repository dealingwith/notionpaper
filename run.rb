# Set these variables in config.rb:
# NOTION_API_KEY = '[YOUR NOTION API KEY]'
# NOTION_BASE_URL = '[YOUR NOTION BASE URL]' # for example https://www.notion.so/username/
# CONFIG = {
#   'db_id' => '[ID OF THE NOTION DATABASE YOU WANT TO ACCESS]',
#   'chosen_filter_property_name' => '[TO FILTER, PUT PROPERTY NAME HERE]', # e.g. 'Status'
#   'chosen_filter_option_name' => '[PUT VALUE TO FILTER BY HERE]' # e.g. 'Todo'
# }
# CONFIG = nil # set to nil to use the interactive mode

load 'config.rb'
require './notionpaper'

create_notionpaper_files(CONFIG)
