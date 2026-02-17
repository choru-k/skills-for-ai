# Migrating from Basic to Advanced Hooks

This guide shows how to migrate from basic command hooks to advanced prompt-based and agent-based hooks, and how to update deprecated output formats.

## Why Migrate?

Prompt-based hooks offer several advantages:

- **Natural language reasoning**: LLM understands context and intent
- **Better edge case handling**: Adapts to unexpected scenarios
- **No bash scripting required**: Simpler to write and maintain
- **More flexible validation**: Can handle complex logic without coding

Agent-based hooks go further:

- **Multi-turn verification**: Can read files, run searches, inspect code
- **Up to 50 tool-use turns**: Complex verification workflows
- **Actual state verification**: Not just reasoning about input data

## Update Deprecated Output Formats

### PreToolUse: Use `hookSpecificOutput` (Not Top-Level `decision`)

**Before (deprecated):**
```json
{
  "decision": "approve",
  "reason": "Safe operation"
}
```

**After (correct):**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Safe operation"
  }
}
```

**Mapping:** `"approve"` → `"allow"`, `"block"` → `"deny"`. The new format also supports `"ask"` to escalate to the user.

### Prompt/Agent Hook Response: Use `ok`/`reason` (Not `approve`/`block`)

**Before (wrong):**
```
Return 'approve' or 'block' with reason.
```

**After (correct):**
```
Respond with {"ok": true} or {"ok": false, "reason": "explanation"}.
```

The LLM responds with structured JSON:

```json
{"ok": true}
{"ok": false, "reason": "Tests not passing"}
```

### Stop/SubagentStop: Still Use Top-Level `decision`

Stop hooks are **not** deprecated — they still use top-level `decision: "block"`:

```json
{
  "decision": "block",
  "reason": "Tests must pass before stopping"
}
```

Only PreToolUse moved to `hookSpecificOutput`.

### Prompt Placeholder: Use `$ARGUMENTS` (Not `$TOOL_INPUT`)

**Before (wrong):**
```json
"prompt": "Analyze command: $TOOL_INPUT"
"prompt": "Check prompt: $USER_PROMPT"
"prompt": "Review result: $TOOL_RESULT"
```

**After (correct):**
```json
"prompt": "Analyze this hook input: $ARGUMENTS"
```

`$ARGUMENTS` is the single placeholder that contains the full hook input JSON. If `$ARGUMENTS` is not present in the prompt, input JSON is appended automatically.

## Migration Example: Bash Command Validation

### Before (Basic Command Hook)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash validate-bash.sh"
          }
        ]
      }
    ]
  }
}
```

**Script (validate-bash.sh):**
```bash
#!/bin/bash
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

if [[ "$command" == *"rm -rf"* ]]; then
  echo '{"decision": "deny", "reason": "Dangerous command"}' >&2
  exit 2
fi
```

**Problems:**
- Only checks exact "rm -rf" pattern
- Misses variations (`rm -fr`, `rm -r -f`)
- Misses other dangerous commands
- Uses deprecated output format

### After (Advanced Prompt Hook)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Analyze this bash command for safety. Check for: 1) Destructive operations (rm -rf, dd, mkfs) 2) Privilege escalation (sudo, su) 3) Network operations without consent. Context: $ARGUMENTS. Respond {\"ok\": true} if safe, {\"ok\": false, \"reason\": \"explanation\"} if not.",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

**Benefits:**
- Catches all variations and patterns
- Understands intent, not just literal strings
- No script file needed
- Context-aware decisions

## Migration Example: File Write Validation

### Before (Deprecated Output Format)

```bash
#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')

if [[ "$file_path" == *".."* ]]; then
  echo '{"decision": "deny", "reason": "Path traversal"}' >&2
  exit 2
fi
```

### After (Correct Output Format)

```bash
#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [ -z "$file_path" ]; then
  exit 0
fi

if [[ "$file_path" == *".."* ]]; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Path traversal detected"}}'
  exit 0
fi

if [[ "$file_path" == *.env ]] || [[ "$file_path" == *secret* ]]; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: "Sensitive file — confirm with user"}}'
  exit 0
fi

exit 0
```

**Key changes:**
1. Use `hookSpecificOutput` with `hookEventName: "PreToolUse"`
2. Use `permissionDecision` (allow/deny/ask) instead of `decision`
3. Output to stdout with exit 0, not stderr with exit 2 (for JSON decisions)
4. Can escalate to user with `"ask"` (new capability)

## When to Keep Command Hooks

Command hooks still have their place:

### 1. Deterministic Performance Checks
```bash
#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')
size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)

if [ "$size" -gt 10000000 ]; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "File too large (>10MB)"}}'
  exit 0
fi
exit 0
```

### 2. External Tool Integration
```bash
#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')
if ! security-scanner "$file_path"; then
  echo "Security scan failed" >&2
  exit 2
fi
exit 0
```

### 3. Very Fast Checks (< 50ms)
```bash
#!/bin/bash
command=$(jq -r '.tool_input.command')
if [[ "$command" =~ ^(ls|pwd|echo)$ ]]; then
  exit 0
fi
```

## Hybrid Approach

Combine both for multi-stage validation:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/quick-check.sh",
            "timeout": 5
          },
          {
            "type": "prompt",
            "prompt": "Deep analysis of bash command safety: $ARGUMENTS",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

## Migration Checklist

- [ ] Replace `$TOOL_INPUT`, `$TOOL_RESULT`, `$USER_PROMPT` with `$ARGUMENTS`
- [ ] Update PreToolUse output to `hookSpecificOutput` format
- [ ] Change `"approve"` → `"allow"` and `"block"` → `"deny"` in PreToolUse
- [ ] Update prompt hooks to expect `ok`/`reason` response (not `approve`/`block`)
- [ ] Remove `"matcher": "*"` from Stop hooks (no matcher support)
- [ ] Update config format to `{"hooks": {...}}` wrapper
- [ ] Fix default timeout references (command: 600s, not 60s)
- [ ] Consider migrating complex scripts to prompt/agent hooks
- [ ] Test thoroughly with sample input
- [ ] Document changes in plugin README
