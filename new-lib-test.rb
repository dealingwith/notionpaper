require './notionpaper'
require 'awesome_print'

load 'config.rb'

notionpaper = NotionPaper.new()

databases_list = notionpaper.get_notion_databases()

ap databases_list
