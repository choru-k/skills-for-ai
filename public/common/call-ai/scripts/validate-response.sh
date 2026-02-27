#!/usr/bin/env bash
# Validate AI response quality
# Usage: validate-response.sh <response-file> [--strict]
#
# Exit codes:
#   0 - Response passes all checks
#   1 - Response has warnings (non-fatal)
#   2 - Response failed validation (fatal)

set -euo pipefail

RESPONSE_FILE="${1:-}"
STRICT_MODE="${2:-}"

if [[ -z "$RESPONSE_FILE" ]]; then
  echo "Usage: validate-response.sh <response-file> [--strict]"
  echo ""
  echo "Options:"
  echo "  --strict    Treat warnings as errors"
  exit 2
fi

if [[ ! -f "$RESPONSE_FILE" ]]; then
  echo "✗ File not found: $RESPONSE_FILE"
  exit 2
fi

# Initialize counters
WARNINGS=0
ERRORS=0

# Get file stats
CHARS=$(wc -c < "$RESPONSE_FILE" | tr -d ' ')
LINES=$(wc -l < "$RESPONSE_FILE" | tr -d ' ')
WORDS=$(wc -w < "$RESPONSE_FILE" | tr -d ' ')

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Response Validation: $(basename "$RESPONSE_FILE")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check 1: Empty file
if [[ $CHARS -eq 0 ]]; then
  echo "✗ FATAL: Response is empty (0 bytes)"
  ERRORS=$((ERRORS + 1))
fi

# Check 2: Suspiciously short
if [[ $CHARS -gt 0 && $CHARS -lt 50 ]]; then
  echo "⚠️  WARNING: Suspiciously short response (<50 chars)"
  WARNINGS=$((WARNINGS + 1))
fi

# Check 3: Very long (potential runaway)
if [[ $CHARS -gt 100000 ]]; then
  echo "⚠️  WARNING: Very long response (>100K chars) - may be truncated or runaway"
  WARNINGS=$((WARNINGS + 1))
fi

# Check 4: Error indicators in response
if grep -qi '"status":\s*"error"' "$RESPONSE_FILE" 2>/dev/null; then
  echo "✗ FATAL: Response contains structured error JSON"
  ERRORS=$((ERRORS + 1))
fi

# Check 5: Common error strings
if grep -qiE "^error:|Error:" "$RESPONSE_FILE" 2>/dev/null; then
  echo "⚠️  WARNING: Response may contain error messages"
  WARNINGS=$((WARNINGS + 1))
fi

# Check 6: AI refusal patterns
if grep -qiE "I cannot|I'm unable to|I can't help|I apologize, but I" "$RESPONSE_FILE" 2>/dev/null; then
  echo "⚠️  WARNING: Possible AI refusal detected"
  WARNINGS=$((WARNINGS + 1))
fi

# Check 7: Truncation indicators
if grep -qE '\.\.\.$|…$' "$RESPONSE_FILE" 2>/dev/null; then
  echo "⚠️  WARNING: Response may be truncated (ends with ...)"
  WARNINGS=$((WARNINGS + 1))
fi

# Check 8: Rate limit / quota errors
if grep -qiE "rate.?limit|quota|429|too many requests" "$RESPONSE_FILE" 2>/dev/null; then
  echo "⚠️  WARNING: Rate limit or quota error detected"
  WARNINGS=$((WARNINGS + 1))
fi

# Check 9: Context length errors
if grep -qiE "context.?length|token.?limit|maximum.?length|too long" "$RESPONSE_FILE" 2>/dev/null; then
  echo "⚠️  WARNING: Context/token length error detected"
  WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Size:     $CHARS chars, $WORDS words, $LINES lines"
echo "  Errors:   $ERRORS"
echo "  Warnings: $WARNINGS"
echo ""

# Determine exit code
if [[ $ERRORS -gt 0 ]]; then
  echo "✗ FAILED: Response has $ERRORS error(s)"
  exit 2
elif [[ $WARNINGS -gt 0 && "$STRICT_MODE" == "--strict" ]]; then
  echo "✗ FAILED (strict mode): Response has $WARNINGS warning(s)"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo "⚠️  PASSED with $WARNINGS warning(s)"
  exit 0
else
  echo "✓ PASSED: Response looks valid"
  exit 0
fi
