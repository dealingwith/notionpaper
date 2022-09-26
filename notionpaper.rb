require 'notion_ruby'
require 'redcarpet'
load 'config.rb'
# Set these variables in config.rb:
# NOTION_API_KEY
# NOTION_BASE_URL
# NOTION_DB_ID

class CustomRender < Redcarpet::Render::HTML
  def list_item(text, list_type)
    super(text, list_type) unless list_type == :unordered
    text.sub!('[ ]', '<input type="checkbox">')
    %(<li style="list-style: none">#{text}</li>)
  end
end

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
  title = task['properties']['Name']['title'][0]['plain_text'].strip
  url = "#{NOTION_BASE_URL}#{title.tr(" ", "-")}-#{task['id'].tr("-", "")}"
  taskpaper_content << "- #{title}\n"
  taskpaper_content << "  #{url}\n"
  markdown_content << "- [ ] [#{title}](#{url})\n"
end

File.write 'notion.taskpaper', taskpaper_content
File.write 'notion.markdown', markdown_content
File.write 'notion.html', Redcarpet::Markdown.new(CustomRender).render(markdown_content)

