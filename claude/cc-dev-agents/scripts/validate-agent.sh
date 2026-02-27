#!/bin/bash
# Subagent File Validator
# Validates subagent markdown files for correct structure and content

set -euo pipefail

# Usage
if [ $# -eq 0 ]; then
  echo "Usage: $0 <path/to/agent.md>"
  echo ""
  echo "Validates subagent file for:"
  echo "  - YAML frontmatter structure"
  echo "  - Required fields (name, description)"
  echo "  - Optional field formats (model, tools, permissionMode, maxTurns, memory, etc.)"
  echo "  - System prompt presence and length"
  echo "  - Example blocks in description"
  exit 1
fi

AGENT_FILE="$1"

echo "🔍 Validating subagent file: $AGENT_FILE"
echo ""

# Check 1: File exists
if [ ! -f "$AGENT_FILE" ]; then
  echo "❌ File not found: $AGENT_FILE"
  exit 1
fi
echo "✅ File exists"

# Check 2: Starts with ---
FIRST_LINE=$(head -1 "$AGENT_FILE")
if [ "$FIRST_LINE" != "---" ]; then
  echo "❌ File must start with YAML frontmatter (---)"
  exit 1
fi
echo "✅ Starts with frontmatter"

# Check 3: Has closing ---
if ! tail -n +2 "$AGENT_FILE" | grep -q '^---$'; then
  echo "❌ Frontmatter not closed (missing second ---)"
  exit 1
fi
echo "✅ Frontmatter properly closed"

# Extract frontmatter and system prompt
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$AGENT_FILE")
SYSTEM_PROMPT=$(awk '/^---$/{i++; next} i>=2' "$AGENT_FILE")

# Check 4: Required fields
echo ""
echo "Checking required fields..."

error_count=0
warning_count=0

# Check name field
NAME=$(echo "$FRONTMATTER" | grep '^name:' | sed 's/name: *//' | sed 's/^"\(.*\)"$/\1/')

if [ -z "$NAME" ]; then
  echo "❌ Missing required field: name"
  ((error_count++))
else
  echo "✅ name: $NAME"

  # Validate name format
  if ! [[ "$NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]]; then
    echo "❌ name must start/end with alphanumeric and contain only letters, numbers, hyphens"
    ((error_count++))
  fi

  # Validate name length
  name_length=${#NAME}
  if [ $name_length -lt 3 ]; then
    echo "❌ name too short (minimum 3 characters)"
    ((error_count++))
  elif [ $name_length -gt 50 ]; then
    echo "❌ name too long (maximum 50 characters)"
    ((error_count++))
  fi

  # Check for generic names
  if [[ "$NAME" =~ ^(helper|assistant|agent|tool)$ ]]; then
    echo "⚠️  name is too generic: $NAME"
    ((warning_count++))
  fi
fi

# Check description field
DESCRIPTION=$(echo "$FRONTMATTER" | grep '^description:' | sed 's/description: *//')

if [ -z "$DESCRIPTION" ]; then
  echo "❌ Missing required field: description"
  ((error_count++))
else
  desc_length=${#DESCRIPTION}
  echo "✅ description: ${desc_length} characters"

  if [ $desc_length -lt 10 ]; then
    echo "⚠️  description too short (minimum 10 characters recommended)"
    ((warning_count++))
  elif [ $desc_length -gt 5000 ]; then
    echo "⚠️  description very long (over 5000 characters)"
    ((warning_count++))
  fi

  # Check for example blocks
  if ! echo "$DESCRIPTION" | grep -q '<example>'; then
    echo "⚠️  description should include <example> blocks for triggering"
    ((warning_count++))
  fi

  # Check for "Use this agent when" pattern
  if ! echo "$DESCRIPTION" | grep -qi 'use this agent when'; then
    echo "⚠️  description should start with 'Use this agent when...'"
    ((warning_count++))
  fi
fi

# Check optional fields
echo ""
echo "Checking optional fields..."

# Check model field (optional, defaults to inherit)
MODEL=$(echo "$FRONTMATTER" | grep '^model:' | sed 's/model: *//')

if [ -n "$MODEL" ]; then
  echo "✅ model: $MODEL"

  case "$MODEL" in
    inherit|sonnet|opus|haiku)
      # Valid model
      ;;
    *)
      echo "⚠️  Unknown model: $MODEL (valid: inherit, sonnet, opus, haiku)"
      ((warning_count++))
      ;;
  esac
else
  echo "💡 model: not specified (defaults to inherit)"
fi

# Check for color field (optional, used for UI identification)
COLOR=$(echo "$FRONTMATTER" | grep '^color:' | sed 's/color: *//')

if [ -n "$COLOR" ]; then
  echo "✅ color: $COLOR"
fi

# Check tools field (optional)
TOOLS=$(echo "$FRONTMATTER" | grep '^tools:' | sed 's/tools: *//')

if [ -n "$TOOLS" ]; then
  echo "✅ tools: $TOOLS"
else
  echo "💡 tools: not specified (subagent has access to all tools)"
fi

# Check disallowedTools field (optional)
DISALLOWED_TOOLS=$(echo "$FRONTMATTER" | grep '^disallowedTools:' | sed 's/disallowedTools: *//')

if [ -n "$DISALLOWED_TOOLS" ]; then
  echo "✅ disallowedTools: $DISALLOWED_TOOLS"

  # Warn if both tools and disallowedTools are set
  if [ -n "$TOOLS" ]; then
    echo "⚠️  Both 'tools' and 'disallowedTools' are set — use one or the other, not both"
    ((warning_count++))
  fi
fi

# Check permissionMode field (optional)
PERMISSION_MODE=$(echo "$FRONTMATTER" | grep '^permissionMode:' | sed 's/permissionMode: *//')

if [ -n "$PERMISSION_MODE" ]; then
  echo "✅ permissionMode: $PERMISSION_MODE"

  case "$PERMISSION_MODE" in
    default|acceptEdits|delegate|dontAsk|bypassPermissions|plan)
      # Valid permission mode
      ;;
    *)
      echo "⚠️  Unknown permissionMode: $PERMISSION_MODE (valid: default, acceptEdits, delegate, dontAsk, bypassPermissions, plan)"
      ((warning_count++))
      ;;
  esac
fi

# Check maxTurns field (optional)
MAX_TURNS=$(echo "$FRONTMATTER" | grep '^maxTurns:' | sed 's/maxTurns: *//')

if [ -n "$MAX_TURNS" ]; then
  echo "✅ maxTurns: $MAX_TURNS"

  # Validate is a positive integer
  if ! [[ "$MAX_TURNS" =~ ^[1-9][0-9]*$ ]]; then
    echo "❌ maxTurns must be a positive integer (got: $MAX_TURNS)"
    ((error_count++))
  fi
fi

# Check memory field (optional)
MEMORY=$(echo "$FRONTMATTER" | grep '^memory:' | sed 's/memory: *//')

if [ -n "$MEMORY" ]; then
  echo "✅ memory: $MEMORY"

  case "$MEMORY" in
    user|project|local)
      # Valid memory scope
      ;;
    *)
      echo "⚠️  Unknown memory scope: $MEMORY (valid: user, project, local)"
      ((warning_count++))
      ;;
  esac
fi

# Check 5: System prompt
echo ""
echo "Checking system prompt..."

if [ -z "$SYSTEM_PROMPT" ]; then
  echo "❌ System prompt is empty"
  ((error_count++))
else
  prompt_length=${#SYSTEM_PROMPT}
  echo "✅ System prompt: $prompt_length characters"

  if [ $prompt_length -lt 20 ]; then
    echo "❌ System prompt too short (minimum 20 characters)"
    ((error_count++))
  elif [ $prompt_length -gt 10000 ]; then
    echo "⚠️  System prompt very long (over 10,000 characters)"
    ((warning_count++))
  fi

  # Check for second person
  if ! echo "$SYSTEM_PROMPT" | grep -q "You are\|You will\|Your"; then
    echo "⚠️  System prompt should use second person (You are..., You will...)"
    ((warning_count++))
  fi

  # Check for structure
  if ! echo "$SYSTEM_PROMPT" | grep -qi "responsibilities\|process\|steps"; then
    echo "💡 Consider adding clear responsibilities or process steps"
  fi

  if ! echo "$SYSTEM_PROMPT" | grep -qi "output"; then
    echo "💡 Consider defining output format expectations"
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $error_count -eq 0 ] && [ $warning_count -eq 0 ]; then
  echo "✅ All checks passed!"
  exit 0
elif [ $error_count -eq 0 ]; then
  echo "⚠️  Validation passed with $warning_count warning(s)"
  exit 0
else
  echo "❌ Validation failed with $error_count error(s) and $warning_count warning(s)"
  exit 1
fi
