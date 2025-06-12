#!/usr/bin/env bash
set -euo pipefail

# === Configuration ===
API_KEY="${API_KEY:-your_openai_api_key_here}"
MODEL="dall-e-3"
SIZE="1024x1024"

# === Default Values ===
DEFAULT_JSON="./some.json" # Path to the input JSON file
DEFAULT_OUTPUT="./images" # Directory to save generated images
DEFAULT_FIELDS="name,movement" # Comma-separated fields to extract from JSON
DEFAULT_PROMPT="Here is the description of how to do a {name}: {movement} Please generate a 2D pixel art style image that displays the start and end position of a {name}." # Default prompt template

# === Helper Functions ===
usage() {
  echo "Usage: $0 [--json path] [--output dir] [--fields name,movement]"
  exit 1
}

error_exit() {
  echo "❌ $1"
  exit 1
}

# === Parse Args or Prompt ===
INPUT_JSON="${1:-$DEFAULT_JSON}"
while [ -z "$INPUT_JSON" ]; do
  read -rp "Enter the path to the input JSON file: " INPUT_JSON
done
if [ ! -f "$INPUT_JSON" ]; then
  error_exit "File not found: $INPUT_JSON"
fi

OUTPUT_DIR="${2:-$DEFAULT_OUTPUT}"
while [ -z "$OUTPUT_DIR" ]; do
  read -rp "Enter the directory to save generated images: " OUTPUT_DIR
done

FIELD_INPUT="${3:-$DEFAULT_FIELDS}"
while [ -z "$FIELD_INPUT" ]; do
  read -rp "Enter comma-separated fields to extract from JSON (e.g. name,movement): " FIELD_INPUT
done

IFS=',' read -ra FIELDS <<< "$FIELD_INPUT"

BASENAME=$(basename -- "$INPUT_JSON")
FILENAME="${BASENAME%.*}"
mkdir -p "$OUTPUT_DIR/$FILENAME"

# === Prompt Setup ===
PROMPT_TEMPLATE="${PROMPT_TEMPLATE:-$DEFAULT_PROMPT}"
while [ -z "$PROMPT_TEMPLATE" ]; do
  read -rp "Enter the prompt template (use {name}, {movement}, etc. as placeholders): " PROMPT_TEMPLATE
done

# === Build jq Filter ===
FILTER="select("
for FIELD in "${FIELDS[@]}"; do
  FILTER+="has(\"$FIELD\") and "
done
FILTER="${FILTER% and })" # Trim trailing "and"

# === Image Generation Loop ===
jq -c ".. | objects | $FILTER" "$INPUT_JSON" | while IFS= read -r OBJECT; do

  FIELD_VALUES=()
  declare -A FIELD_MAP
  for FIELD in "${FIELDS[@]}"; do
    VALUE=$(echo "$OBJECT" | jq -r --arg field "$FIELD" '.[$field]')
    FIELD_VALUES+=("$VALUE")
    FIELD_MAP[$FIELD]="$VALUE"
  done

  DISPLAY_NAME="${FIELD_VALUES[0]}"
  SAFE_NAME=$(echo "$DISPLAY_NAME" | tr ' ' '_' | tr -dc 'A-Za-z0-9_-')

  # Replace placeholders in the prompt template with field values
  PROMPT="$PROMPT_TEMPLATE"
  for FIELD in "${FIELDS[@]}"; do
    PROMPT="${PROMPT//\{$FIELD\}/${FIELD_MAP[$FIELD]}}"
  done

  echo "🖼️ Generating image for: $DISPLAY_NAME"

  RESPONSE=$(curl -s https://api.openai.com/v1/images/generations \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "{
      \"model\": \"$MODEL\",
      \"prompt\": \"$PROMPT\",
      \"n\": 1,
      \"size\": \"$SIZE\"
    }")

  IMAGE_URL=$(echo "$RESPONSE" | jq -r '.data[0].url // empty')

  if [ -n "$IMAGE_URL" ]; then
    curl -s "$IMAGE_URL" -o "$OUTPUT_DIR/$FILENAME/${SAFE_NAME}.png"
    echo "✅ Saved: $OUTPUT_DIR/$FILENAME/${SAFE_NAME}.png"
  else
    echo "❌ Failed to generate image for: $DISPLAY_NAME"
    echo "Response: $RESPONSE"
    echo
  fi
done
