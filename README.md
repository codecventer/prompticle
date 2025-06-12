# prooompt.sh

## Overview

`prooompt.sh` is a Bash script that generates images using the OpenAI DALL-E API, based on data from a JSON file. The script extracts specified fields from each object in the JSON, constructs a prompt for each (which can be customized), and saves the generated images to a specified directory.

## Usage

```bash
./prooompt.sh [input_json] [output_dir] [fields]
```

- `input_json`: Path to the input JSON file (default: `./some.json`)
- `output_dir`: Directory to save generated images (default: `./images`)
- `fields`: Comma-separated fields to extract from JSON (default: `name,movement`)

If any of these arguments are not provided or are empty, the script will prompt you to enter them interactively.

You will also be prompted for a prompt template if not set. The template can use placeholders like `{name}` and `{movement}` which will be replaced with values from the JSON.

## Example

Suppose your `some.json` looks like:

```json
[
  {"name": "Jump", "movement": "Move up and down"},
  {"name": "Run", "movement": "Move quickly forward"}
]
```

Run the script:

```bash
./prooompt.sh some.json images name,movement
```

You will be prompted for a prompt template if not set. Example:

```
Enter the prompt template (use {name}, {movement}, etc. as placeholders): Here is the description of how to do a {name}: {movement}. Please generate a 2D pixel art style image that displays the start and end position of a {name}.
```

The script will generate images for each object and save them as PNG files in `images/some/`.

## Environment Variables

- `API_KEY`: Your OpenAI API key (required)
- `MODEL`: The DALL-E model to use (default: `dall-e-3`)
- `SIZE`: Image size (default: `1024x1024`)
- `PROMPT_TEMPLATE`: (optional) Set a default prompt template

## Notes

- The script requires `jq` and `curl` to be installed.
- The script will exit with an error if the input JSON file does not exist.
- The output directory will be created if it does not exist.

## License

MIT

# prompticle
