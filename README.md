# Codename: TaskSheet

## What is it?

It started out as a Notion tasks DB-to-Taskpaper command-line utility (prior art: [dealingwith/trellopaper](https://github.com/dealingwith/trellopaper)).

## Quickstart

### To run the CLI

`bundle`

`touch config.rb`

Add the following to `config.rb`:

```rb
NOTION_API_KEY = "[YOUR NOTION API KEY]"
# optional:
CONFIG = {
  "db_id" => "[ID OF THE NOTION DATABASE YOU WANT TO ACCESS]",
  "chosen_filter_property_name" => "[TO FILTER, PUT PROPERTY NAME HERE]", # e.g. what you've named the column in Notion, e.g. 'Status'
  "filter_type" => "select", # or Notion's new 'status' is supported
  "filter_options" => ["In Progress", "Priority"] # what values in that column to filter by, those are examples, could be anything
}
```

Additional optional config values--these are not yet asked via the CLI workflow and can only be defined in the config file:

```rb
"use_output_folder" => true,
"use_date_folder" => true,
"taskpaper_output_file" => filename,
"markdown_output_file" => filename,
"html_output_file" => filename,
```

Run the CLI: `ruby run.rb` or `bundle exec ruby run.rb`

Observe output in `notion.taskpaper`, `notion.markdown`, and `notion.html`. (PDF output is currently disabled, but feel free to un-comment those lines and give it a shot.)

### To run the app with dynamic config options

#### Command-line

`ruby run.rb`

The command-line app will ask if you want to use values in the config or not. If not, it will prompt you for which database, which property to filter by, and which option of that property to filter by.

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

* The Notion API. See the [docs](https://developers.notion.com/reference/intro) on [developers.notion.com](https://developers.notion.com/)
* [notion-ruby-client](https://github.com/orbit-love/notion-ruby-client)

## TODO

- Group-by config'd via CLI inputs
- Display filter property
- Multiple databases
- Additional inputs
  - local file
  - logseq
- Mark as done
- Sort
- Write new config from command line
- Nested subtasks
