#!/bin/bash

# === Configuration ===
API_KEY="your_openai_api_key_here"
MODEL="dall-e-3"
SIZE="1024x1024"

# === Prompt User for Input ===
read -rp "Enter the path to your JSON file: " INPUT_JSON
if [ ! -f "$INPUT_JSON" ]; then
  echo "❌ Error: File not found at $INPUT_JSON"
  exit 1
fi

read -rp "Enter the output directory for images: " OUTPUT_DIR
read -rp "Enter the fields to use (comma-separated, no whitespaces - e.g., name,movement): " FIELD_INPUT

IFS=',' read -ra FIELDS <<< "$FIELD_INPUT"

# === Prepare Output Path ===
BASENAME=$(basename -- "$INPUT_JSON")
FILENAME="${BASENAME%.*}" # e.g., cardio.json → cardio
mkdir -p "$OUTPUT_DIR/$FILENAME"

# === Build jq filter for required fields ===
FILTER="select("
for FIELD in "${FIELDS[@]}"; do
  FILTER+="has(\"$FIELD\") and "
done
FILTER="${FILTER% and })" # Remove trailing 'and'

# === Search JSON for matching objects and generate images ===
jq -c ".. | objects | $FILTER" "$INPUT_JSON" | while IFS= read -r OBJECT; do
  declare -A FIELD_VALUES
  for FIELD in "${FIELDS[@]}"; do
    VALUE=$(echo "$OBJECT" | jq -r --arg field "$FIELD" '.[$field]')
    FIELD_VALUES["$FIELD"]="$VALUE"
  done

  # === Use first field as filename ===
  DISPLAY_NAME="${FIELD_VALUES[${FIELDS[0]}]}"
  SAFE_NAME=$(echo "$DISPLAY_NAME" | tr ' ' '_' | tr -dc 'A-Za-z0-9_-')

  # === Construct prompt ===
  PROMPT="Here is the description of how to do a ${FIELD_VALUES["name"]}: ${FIELD_VALUES["movement"]} Please generate a 2D pixel art style image that displays the start and end position of a ${FIELD_VALUES["name"]}."

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
  echo "Response: $RESPONSE"
  echo

  IMAGE_URL=$(echo "$RESPONSE" | jq -r '.data[0].url')

  if [[ "$IMAGE_URL" != null && "$IMAGE_URL" != "null" ]]; then
    curl -s "$IMAGE_URL" -o "$OUTPUT_DIR/$FILENAME/${SAFE_NAME}.png"
    echo "✅ Saved: $OUTPUT_DIR/$FILENAME/${SAFE_NAME}.png"
  else
    echo "❌ Failed to generate image for $DISPLAY_NAME"
    echo
  fi
done
