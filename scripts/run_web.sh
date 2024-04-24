#!/usr/bin/env bash

set -e

# Paths
INDEX_HTML="web/index.html"
INDEX_GENERATED="web/index_generated.html"
SECRETS_FILE="android/secrets.properties"

# Check for secrets file
if [ ! -f "$SECRETS_FILE" ]; then
  echo "❌ Error: $SECRETS_FILE not found."
  exit 1
fi

# Extract key from secrets.env
API_KEY=$(grep '^MAPS_API_KEY=' "$SECRETS_FILE" | cut -d '=' -f2-)

if [ -z "$API_KEY" ]; then
  echo "❌ Error: MAPS_API_KEY is empty or not set."
  exit 1
fi

# Inject key into a new HTML file
sed "s/{{MAPS_API_KEY}}/$API_KEY/g" "$INDEX_HTML" > "$INDEX_GENERATED"

# Backup original index.html
cp "$INDEX_HTML" "$INDEX_HTML.bak"

# Replace with generated file
cp "$INDEX_GENERATED" "$INDEX_HTML"

echo "✅ Injected API key and updated index.html"

# Run the app
flutter run

# Restore original placeholder index.html
mv "$INDEX_HTML.bak" "$INDEX_HTML"
rm "$INDEX_GENERATED"

echo "✅ Run complete and index.html restored"
