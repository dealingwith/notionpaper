require 'notion_ruby'
require 'redcarpet'
load 'config.rb'
# Set these variables in config.rb:
# NOTION_API_KEY
# NOTION_BASE_URL
# NOTION_DB_ID

class CustomRender < Redcarpet::Render::HTML
  def list_item(text, list_type)
    notion_page_id = text.match(/ID:\[(.*)\]/)[1]
    text.sub!('[ ]', '<input type="checkbox">')
    %(<li style="list-style: none" onClick="location.href='/complete_task/#{notion_page_id}'">#{text}</li>)
  end
end

def create_notionpaper_files
  notion = NotionRuby.new({ access_token: NOTION_API_KEY })
  query = {
    "filter": {
      "and": [
        {
          "property": 'Status',
          "select": {
            "does_not_equal": 'Done'
          }
        },
        {
          "property": 'Status',
          "select": {
            "does_not_equal": 'Archive'
          }
        }
      ]
    },
    "sorts": [
      {
        "property": 'Status',
        "direction": 'descending'
      },
      {
        "property": 'Created',
        "direction": 'descending'
      }
    ],
    page_size: 100
  }
  results = notion.databases(NOTION_DB_ID).query(query)

  tasks = results['results']

  File.write 'tasks.rb', tasks.to_s

  taskpaper_content = ''
  markdown_content = ''

  tasks.each do |task|
    # title = task['properties']['Name']['title'][0]['plain_text'].strip
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
  File.write 'notion.html', Redcarpet::Markdown.new(CustomRender).render(markdown_content)
end
