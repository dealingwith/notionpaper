# Codename: Notionpaper

## Quickstart

`$ bundle`

`$ touch config.rb`

Add the following to `config.rb`:

```rb
NOTION_API_KEY = '[YOUR NOTION API KEY]'
NOTION_BASE_URL = '[YOUR NOTION BASE URL]' # for example https://www.notion.so/username/
# optional:
CONFIG = {
  'db_id' => '[ID OF THE NOTION DATABASE YOU WANT TO ACCESS]',
  'chosen_filter_property_name' => '[TO FILTER, PUT PROPERTY NAME HERE]', # e.g. 'Status'
  'chosen_filter_option_name' => '[PUT VALUE TO FILTER BY HERE]' # e.g. 'Todo'
}
```

### To run the web app

`$ ruby app.rb`

Go to `http://127.0.0.1:4567/`

#### To run with hot-reload

`$ gem install rerun`

`$ rerun 'ruby app.rb'`

Go to `http://127.0.0.1:4567/`

### To run the command-line app

`$ ruby run.rb`

Observe output in `notion.taskpaper`, `notion.markdown`, and `notion.html`.

#### To run the command-line app with dynamic config options

Set `CONFIG` in `config.rb` to `nil`, then re-run the command-line app.

```rb
CONFIG = nil
```

It will prompt you for which database, which property to filter by, and which option of that property to filter by.

Remember that this `config.rb` will break the web app.

## Important:

_Currently only supports filter properties that can do `equals`_, i.e. it does:

```json
{
  "filter": {
    "property": "chosen_filter_property_name",
    "select": {
      "equals": "chosen_filter_option_name"
    }
  }
}
```

## Dependencies

* The Notion API
  * [docs](https://developers.notion.com/reference/intro)
  * [developers.notion.com](https://developers.notion.com/)
* [notion-ruby](https://github.com/decoch/notion-ruby)
* [Sinatra](https://sinatrarb.com/)
* [redcarpet](https://github.com/vmg/redcarpet)
