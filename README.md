# Codename: TaskSheet

## What is it?

It started out as a Notion tasks DB -to- Taskpaper command-line utility (prior art: [dealingwith/trellopaper](https://github.com/dealingwith/trellopaper)). Then we started on a web-app version...which currently simply displays the task list, but aspires to:

* Print the list beautifully to various paper sizes, ideal for inserting into paper journals and notebooks
* Support basic entry manipulation (other metadata, completion states)

Very much a WIP.

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
  'chosen_filter_property_name' => '[TO FILTER, PUT PROPERTY NAME HERE]', # e.g. what you've named the column in Notion, e.g. 'Status'
  'filter_type' => 'select', # or Notion's new 'status' is supported
  'filter_options' => ['In Progress', 'Priority'] # what values in that column to filter by, those are examples, could be anything
}
```

### To run the web app

#### Using Notion OAuth

Do not have NOTION_API_KEY in your `config.rb`

Start [ngrok](https://ngrok.com/):

`ngrok http 4567`

Visit you ngrok URL to activate it

Update [your Notion app](https://www.notion.so/my-integrations)'s Redirect URI to you ngrok URL + `/notion_auth`

`$ ruby app.rb`

Go to `http://127.0.0.1:4567/`

#### To run with hot-reload

`$ gem install rerun`

`$ rerun 'ruby app.rb'`

Go to `http://127.0.0.1:4567/`

### To run the command-line app

`$ ruby run.rb --use-config`

Observe output in `notion.taskpaper`, `notion.markdown`, and `notion.html`.

### To run the app with dynamic config options

#### Command-line

`$ ruby run.rb`

The command-line app will ask if you want to use values in the config or not. If not, it will prompt you for which database, which property to filter by, and which option of that property to filter by.

#### Web app

Set `CONFIG` in `config.rb` to `nil` or comment it out completely, then re-run the app.

## Important:

_Currently only supports filter properties that can do `equals`_, i.e. it does this type of request to the Notion API:

```json
{
  "filter": {
    "property": "filter_property_name",
    "filter_type": {
      "equals": "filter_option"
    }
  }
}
```

## Dependencies

* The Notion API
  * [docs](https://developers.notion.com/reference/intro)
  * [developers.notion.com](https://developers.notion.com/)
* [notion-ruby-client](https://github.com/orbit-love/notion-ruby-client)
* [Sinatra](https://sinatrarb.com/)
* [Moneta](https://github.com/moneta-rb/moneta)
