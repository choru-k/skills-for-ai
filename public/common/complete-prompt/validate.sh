#!/bin/bash
# Validate a generated handoff prompt
# Usage: ./validate.sh <prompt-file>

FILE="$1"

if [[ -z "$FILE" ]]; then
  echo "Usage: ./validate.sh <prompt-file>"
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

echo "Validating: $FILE"
echo "────────────────────────────────────────"

# 1. XML validity
if command -v xmllint &> /dev/null; then
  if xmllint --noout "$FILE" 2>/dev/null; then
    echo "✅ XML: Valid"
  else
    echo "❌ XML: Invalid"
    xmllint --noout "$FILE"
    exit 1
  fi
else
  echo "⚠️  XML: Skipped (xmllint not found)"
fi

# 2. Required sections
REQUIRED=("summary" "system-role" "next-steps")
for section in "${REQUIRED[@]}"; do
  if grep -q "<$section>" "$FILE"; then
    echo "✅ Section: <$section> present"
  else
    echo "❌ Section: <$section> MISSING"
  fi
done

# 3. Size check
CHARS=$(wc -c < "$FILE" | tr -d ' ')
WORDS=$(wc -w < "$FILE" | tr -d ' ')
echo "────────────────────────────────────────"
echo "📊 Size: $CHARS chars, ~$WORDS words"

if [[ $CHARS -gt 20000 ]]; then
  echo "⚠️  Warning: Large file (>20K chars)"
fi

echo "────────────────────────────────────────"
echo "✅ Validation complete"
