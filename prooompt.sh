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
OUTPUT_DIR="${2:-$DEFAULT_OUTPUT}"
FIELD_INPUT="${3:-$DEFAULT_FIELDS}"

if [ ! -f "$INPUT_JSON" ]; then
  error_exit "File not found: $INPUT_JSON"
fi

IFS=',' read -ra FIELDS <<< "$FIELD_INPUT"

BASENAME=$(basename -- "$INPUT_JSON")
FILENAME="${BASENAME%.*}"
mkdir -p "$OUTPUT_DIR/$FILENAME"

# === Build jq Filter ===
FILTER="select("
for FIELD in "${FIELDS[@]}"; do
  FILTER+="has(\"$FIELD\") and "
done
FILTER="${FILTER% and })" # Trim trailing "and"

# === Image Generation Loop ===
jq -c ".. | objects | $FILTER" "$INPUT_JSON" | while IFS= read -r OBJECT; do
  FIELD_VALUES=()
  for FIELD in "${FIELDS[@]}"; do
    VALUE=$(echo "$OBJECT" | jq -r --arg field "$FIELD" '.[$field]')
    FIELD_VALUES+=("$VALUE")
  done

  DISPLAY_NAME="${FIELD_VALUES[0]}"
  SAFE_NAME=$(echo "$DISPLAY_NAME" | tr ' ' '_' | tr -dc 'A-Za-z0-9_-')

  PROMPT="Here is the description of how to do a ${FIELD_VALUES[0]}: ${FIELD_VALUES[1]}. Please generate a 2D pixel art style image that displays the start and end position of a ${FIELD_VALUES[0]}."

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
