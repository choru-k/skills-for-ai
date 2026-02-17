#!/bin/bash
# Hook Schema Validator
# Validates hooks.json structure and checks for common issues
# Supports all 14 hook events, 3 hook types (command, prompt, agent),
# async hooks, and new handler fields (statusMessage, once, model)

set -euo pipefail

# Usage
if [ $# -eq 0 ]; then
  echo "Usage: $0 <path/to/hooks.json>"
  echo ""
  echo "Validates hook configuration file for:"
  echo "  - Valid JSON syntax"
  echo "  - Required fields"
  echo "  - Hook type validity (command, prompt, agent)"
  echo "  - Matcher patterns"
  echo "  - Timeout ranges"
  echo "  - Async field usage"
  echo "  - Model field usage"
  echo "  - All 14 event types"
  exit 1
fi

HOOKS_FILE="$1"

if [ ! -f "$HOOKS_FILE" ]; then
  echo "❌ Error: File not found: $HOOKS_FILE"
  exit 1
fi

echo "🔍 Validating hooks configuration: $HOOKS_FILE"
echo ""

# Check 1: Valid JSON
echo "Checking JSON syntax..."
if ! jq empty "$HOOKS_FILE" 2>/dev/null; then
  echo "❌ Invalid JSON syntax"
  exit 1
fi
echo "✅ Valid JSON"

# Detect format: settings format (has "hooks" wrapper) or direct event format
has_hooks_wrapper=$(jq 'has("hooks")' "$HOOKS_FILE")
has_description=$(jq 'has("description")' "$HOOKS_FILE")

if [ "$has_hooks_wrapper" = "true" ]; then
  echo "📋 Detected: Plugin/settings format (with 'hooks' wrapper)"
  HOOKS_PATH=".hooks"
else
  # Check if top-level keys look like events (legacy direct format)
  first_key=$(jq -r 'keys[0]' "$HOOKS_FILE")
  VALID_EVENTS=("PreToolUse" "PostToolUse" "PostToolUseFailure" "PermissionRequest" "UserPromptSubmit" "Stop" "SubagentStop" "SubagentStart" "TeammateIdle" "TaskCompleted" "SessionStart" "SessionEnd" "PreCompact" "Notification")
  is_event=false
  for valid_event in "${VALID_EVENTS[@]}"; do
    if [ "$first_key" = "$valid_event" ]; then
      is_event=true
      break
    fi
  done

  if [ "$is_event" = "true" ]; then
    echo "⚠️  Detected: Direct event format (no 'hooks' wrapper)"
    echo "   Recommended: Wrap in {\"hooks\": {...}} for settings files"
    HOOKS_PATH="."
  else
    echo "⚠️  Unknown format — attempting to validate as direct format"
    HOOKS_PATH="."
  fi
fi

# Check 2: Root structure
echo ""
echo "Checking event types..."
VALID_EVENTS=("PreToolUse" "PostToolUse" "PostToolUseFailure" "PermissionRequest" "UserPromptSubmit" "Stop" "SubagentStop" "SubagentStart" "TeammateIdle" "TaskCompleted" "SessionStart" "SessionEnd" "PreCompact" "Notification")

# Events that don't support matchers
NO_MATCHER_EVENTS=("UserPromptSubmit" "Stop" "TeammateIdle" "TaskCompleted")

# Events that support prompt/agent hooks
PROMPT_AGENT_EVENTS=("PreToolUse" "PostToolUse" "PostToolUseFailure" "PermissionRequest" "UserPromptSubmit" "Stop" "SubagentStop" "TaskCompleted")

for event in $(jq -r "$HOOKS_PATH | keys[]" "$HOOKS_FILE" 2>/dev/null); do
  found=false
  for valid_event in "${VALID_EVENTS[@]}"; do
    if [ "$event" = "$valid_event" ]; then
      found=true
      break
    fi
  done

  if [ "$found" = false ]; then
    echo "⚠️  Unknown event type: $event"
  fi
done
echo "✅ Event types checked"

# Check 3: Validate each hook
echo ""
echo "Validating individual hooks..."

error_count=0
warning_count=0

for event in $(jq -r "$HOOKS_PATH | keys[]" "$HOOKS_FILE" 2>/dev/null); do
  hook_count=$(jq -r "$HOOKS_PATH.\"$event\" | length" "$HOOKS_FILE")

  for ((i=0; i<hook_count; i++)); do
    # Check matcher
    matcher=$(jq -r "$HOOKS_PATH.\"$event\"[$i].matcher // empty" "$HOOKS_FILE")

    # Warn if matcher on no-matcher event
    if [ -n "$matcher" ]; then
      for no_match_event in "${NO_MATCHER_EVENTS[@]}"; do
        if [ "$event" = "$no_match_event" ]; then
          echo "⚠️  $event[$i]: Matcher '$matcher' will be ignored ($event doesn't support matchers)"
          ((warning_count++))
          break
        fi
      done
    fi

    # Check hooks array exists
    hooks=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks // empty" "$HOOKS_FILE")
    if [ -z "$hooks" ] || [ "$hooks" = "null" ]; then
      echo "❌ $event[$i]: Missing 'hooks' array"
      ((error_count++))
      continue
    fi

    # Validate each hook in the array
    hook_array_count=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks | length" "$HOOKS_FILE")

    for ((j=0; j<hook_array_count; j++)); do
      hook_type=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks[$j].type // empty" "$HOOKS_FILE")

      if [ -z "$hook_type" ]; then
        echo "❌ $event[$i].hooks[$j]: Missing 'type' field"
        ((error_count++))
        continue
      fi

      if [ "$hook_type" != "command" ] && [ "$hook_type" != "prompt" ] && [ "$hook_type" != "agent" ]; then
        echo "❌ $event[$i].hooks[$j]: Invalid type '$hook_type' (must be 'command', 'prompt', or 'agent')"
        ((error_count++))
        continue
      fi

      # Check type-specific fields
      if [ "$hook_type" = "command" ]; then
        command=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks[$j].command // empty" "$HOOKS_FILE")
        if [ -z "$command" ]; then
          echo "❌ $event[$i].hooks[$j]: Command hooks must have 'command' field"
          ((error_count++))
        else
          # Check for hardcoded paths
          if [[ "$command" == /* ]] && [[ "$command" != *'${CLAUDE_PLUGIN_ROOT}'* ]] && [[ "$command" != *'$CLAUDE_PROJECT_DIR'* ]]; then
            echo "⚠️  $event[$i].hooks[$j]: Hardcoded absolute path detected. Consider using \${CLAUDE_PLUGIN_ROOT} or \$CLAUDE_PROJECT_DIR"
            ((warning_count++))
          fi
        fi

        # Check async field
        async=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks[$j].async // empty" "$HOOKS_FILE")
        if [ "$async" = "true" ]; then
          echo "💡 $event[$i].hooks[$j]: Async hook — will run in background (cannot block)"
        fi

      elif [ "$hook_type" = "prompt" ] || [ "$hook_type" = "agent" ]; then
        prompt=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks[$j].prompt // empty" "$HOOKS_FILE")
        if [ -z "$prompt" ]; then
          echo "❌ $event[$i].hooks[$j]: ${hook_type^} hooks must have 'prompt' field"
          ((error_count++))
        fi

        # Check for deprecated placeholders
        if echo "$prompt" | grep -qE '\$TOOL_INPUT|\$TOOL_RESULT|\$USER_PROMPT'; then
          echo "⚠️  $event[$i].hooks[$j]: Uses deprecated placeholder. Replace \$TOOL_INPUT/\$TOOL_RESULT/\$USER_PROMPT with \$ARGUMENTS"
          ((warning_count++))
        fi

        # Check if prompt/agent hooks are used on supported events
        supported=false
        for pa_event in "${PROMPT_AGENT_EVENTS[@]}"; do
          if [ "$event" = "$pa_event" ]; then
            supported=true
            break
          fi
        done
        if [ "$supported" = false ]; then
          if [ "$event" = "TeammateIdle" ]; then
            echo "❌ $event[$i].hooks[$j]: TeammateIdle does not support ${hook_type} hooks (use command only)"
            ((error_count++))
          else
            echo "⚠️  $event[$i].hooks[$j]: ${hook_type^} hooks may not be supported on $event"
            ((warning_count++))
          fi
        fi

        # Check async on prompt/agent (not supported)
        async=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks[$j].async // empty" "$HOOKS_FILE")
        if [ "$async" = "true" ]; then
          echo "❌ $event[$i].hooks[$j]: 'async' is only supported on command hooks, not ${hook_type}"
          ((error_count++))
        fi

        # Check model field
        model=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks[$j].model // empty" "$HOOKS_FILE")
        if [ -n "$model" ] && [ "$model" != "null" ]; then
          echo "💡 $event[$i].hooks[$j]: Using custom model: $model"
        fi
      fi

      # Check timeout
      timeout=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks[$j].timeout // empty" "$HOOKS_FILE")
      if [ -n "$timeout" ] && [ "$timeout" != "null" ]; then
        if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
          echo "❌ $event[$i].hooks[$j]: Timeout must be a number"
          ((error_count++))
        elif [ "$timeout" -gt 600 ]; then
          echo "⚠️  $event[$i].hooks[$j]: Timeout ${timeout}s exceeds default max (600s for command, 60s for agent, 30s for prompt)"
          ((warning_count++))
        elif [ "$timeout" -lt 1 ]; then
          echo "⚠️  $event[$i].hooks[$j]: Timeout ${timeout}s is too low"
          ((warning_count++))
        fi
      fi

      # Check statusMessage field
      statusMessage=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks[$j].statusMessage // empty" "$HOOKS_FILE")
      if [ -n "$statusMessage" ] && [ "$statusMessage" != "null" ]; then
        echo "💡 $event[$i].hooks[$j]: Custom status message: '$statusMessage'"
      fi

      # Check once field
      once=$(jq -r "$HOOKS_PATH.\"$event\"[$i].hooks[$j].once // empty" "$HOOKS_FILE")
      if [ "$once" = "true" ]; then
        echo "💡 $event[$i].hooks[$j]: Will run only once per session"
      fi
    done
  done
done

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
