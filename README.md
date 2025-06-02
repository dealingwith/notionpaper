# Notionpaper

A Notion tasks DB-to-Taskpaper (etc) command-line utility 

(prior art: [trellopaper](https://github.com/dealingwith/trellopaper)).

## Quickstart

### Requirements

You must have a Notion API key. Get one from [Notion developers](https://developers.notion.com/).

- run `bundle`
- Put your Notion API key in the env var NOTION_API_KEY or declare in `config.rb`
  - `touch config.rb`
  - Open and add `NOTION_API_KEY = "[YOUR NOTION API KEY]"`

### To run the app with dynamic config options

#### Command-line

`notionpaper` (or `ruby run.rb`)

The command-line app will ask if you want to use values in the config or not. If not, it will prompt you for:
- Which database to use
- Which property to filter by (and which values)
- Whether to process subtasks (and the parent property name)
- Which property to group tasks by (and its type)
- Whether to use output and/or date folders

### To set up config.rb (optional)

Add the following to `config.rb`:

```rb
CONFIG = {
  "db_id" => "[ID OF THE NOTION DATABASE YOU WANT TO ACCESS]", # The Notion database to fetch tasks from
  "chosen_filter_property_name" => "[PROPERTY NAME]", # The property (column) to filter tasks by, e.g. 'Status'
  "filter_type" => "select", # The type of the filter property, e.g. 'select' or 'status'
  "filter_options" => ["In Progress", "Priority"], # The values to filter for in the chosen property
  "parent_property_name" => "[PARENT PROPERTY NAME]", # (Optional) The property used to link subtasks to parent tasks (for subtasks support)
  "group_by" => "[PROPERTY NAME]", # (Optional) The property to group tasks by, e.g. 'Status' or 'Project'
  "group_by_type" => "[PROPERTY TYPE]", # (Optional) The type of the group_by property, e.g. 'select' or 'status'
  "use_output_folder" => true, # (Optional) Whether to write output files to an 'output' folder
  "use_date_folder" => true, # (Optional) Whether to write output files to a date-named subfolder
  "taskpaper_output_file" => "notion.taskpaper", # (Optional) Filename for TaskPaper output
  "markdown_output_file" => "notion.markdown", # (Optional) Filename for Markdown output
  "html_output_file" => "notion.html", # (Optional) Filename for HTML output
  "logseq_output_file" => "notion_logseq.md", # (Optional) Filename for Logseq output
}
```

#### What each config value means

- `db_id`: The Notion database to fetch tasks from. This is the unique ID of your Notion database.
- `chosen_filter_property_name`: The property (column) to filter tasks by, e.g. 'Status'.
- `filter_type`: The type of the filter property, e.g. 'select' or 'status'.
- `filter_options`: The values to filter for in the chosen property. Only tasks with these values will be included.
- `parent_property_name`: (Optional) The property used to link subtasks to parent tasks. Set this if you want to process subtasks.
- `group_by`: (Optional) The property to group tasks by, e.g. 'Status' or 'Project'.
- `group_by_type`: (Optional) The type of the group_by property, e.g. 'select' or 'status'.
- `use_output_folder`: (Optional) If true, output files will be written to an 'output' folder.
- `use_date_folder`: (Optional) If true, output files will be written to a date-named subfolder (e.g. 'output/2025-06-01').
- `taskpaper_output_file`: (Optional) Filename for TaskPaper output.
- `markdown_output_file`: (Optional) Filename for Markdown output.
- `html_output_file`: (Optional) Filename for HTML output.
- `logseq_output_file`: (Optional) Filename for Logseq output.

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

## Running the CLI from Anywhere

To run the `notionpaper` CLI tool from any directory, add the project directory to your PATH. For example, if your project is located at `/Users/foo/code/notionpaper`, add the following line to your shell profile (e.g., `~/.zshrc` for zsh):

```sh
export PATH="$PATH:/Users/danielmiller/code/notionpaper"
```

After adding this line, reload your shell configuration.

Now you can run `notionpaper` from any directory in your terminal.

You can pass in values from a config file anywhere by using the following parameters:

`notionpaper --config-path <config_file.rb>`

## TODO

- Display filter property
- Multiple databases
- Additional inputs
  - local file
  - logseq
- Mark as done
- Sort
- Write new config from command line
- Load local config from a diff directory
- Nested subtasks
