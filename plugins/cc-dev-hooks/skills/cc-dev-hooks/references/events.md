# Hook Events — Detailed Reference

This reference provides the complete input/output schema for each of the 14 hook events. For a summary table and general output patterns, see the main `SKILL.md`.

## Common Input Fields (All Events)

Every event includes these fields via stdin JSON:

| Field | Description |
|-------|-------------|
| `session_id` | Current session identifier |
| `transcript_path` | Path to conversation JSON |
| `cwd` | Current working directory |
| `permission_mode` | `"default"`, `"plan"`, `"acceptEdits"`, `"dontAsk"`, or `"bypassPermissions"` |
| `hook_event_name` | Name of the event that fired |

---

## SessionStart

**When:** Session begins or resumes.
**Matcher:** Session source — `startup`, `resume`, `clear`, `compact`.
**Can block:** No.

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "/Users/.../.claude/projects/.../session.jsonl",
  "cwd": "/Users/.../project",
  "permission_mode": "default",
  "hook_event_name": "SessionStart",
  "source": "startup",
  "model": "claude-sonnet-4-5-20250929"
}
```

| Field | Description |
|-------|-------------|
| `source` | How the session started: `"startup"`, `"resume"`, `"clear"`, `"compact"` |
| `model` | Model identifier |
| `agent_type` | (Optional) Present when `claude --agent <name>` is used |

### Output

Any text printed to stdout is added as context for Claude.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Context string added to Claude"
  }
}
```

### Environment — `CLAUDE_ENV_FILE`

SessionStart hooks have access to `$CLAUDE_ENV_FILE`. Write `export` statements to persist env vars for the session:

```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=production' >> "$CLAUDE_ENV_FILE"
  echo 'export DEBUG_LOG=true' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

**Note:** Only SessionStart hooks have access to `CLAUDE_ENV_FILE`. Use append (`>>`) to preserve variables set by other hooks.

---

## UserPromptSubmit

**When:** User submits a prompt, before Claude processes it.
**Matcher:** No matcher support — always fires.
**Can block:** Yes (exit 2 or `decision: "block"`).

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "UserPromptSubmit",
  "prompt": "Write a function to calculate factorial"
}
```

| Field | Description |
|-------|-------------|
| `prompt` | The user's submitted prompt text |

### Output

Two ways to add context (exit 0):
- **Plain text stdout** — added as hook output in transcript
- **JSON with `additionalContext`** — added more discretely

To block a prompt:

```json
{
  "decision": "block",
  "reason": "Explanation shown to user",
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Additional context for Claude"
  }
}
```

---

## PreToolUse

**When:** After Claude creates tool parameters, before execution.
**Matcher:** Tool name — `Bash`, `Edit`, `Write`, `Read`, `Glob`, `Grep`, `Task`, `WebFetch`, `WebSearch`, MCP tool names.
**Can block:** Yes.

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm test"
  },
  "tool_use_id": "toolu_01ABC123..."
}
```

### Tool Input Fields

**Bash:**

| Field | Type | Description |
|-------|------|-------------|
| `command` | string | Shell command to execute |
| `description` | string | Optional description |
| `timeout` | number | Optional timeout (ms) |
| `run_in_background` | boolean | Run in background? |

**Write:**

| Field | Type | Description |
|-------|------|-------------|
| `file_path` | string | Absolute path to write |
| `content` | string | Content to write |

**Edit:**

| Field | Type | Description |
|-------|------|-------------|
| `file_path` | string | Absolute path to edit |
| `old_string` | string | Text to find |
| `new_string` | string | Replacement text |
| `replace_all` | boolean | Replace all occurrences? |

**Read:**

| Field | Type | Description |
|-------|------|-------------|
| `file_path` | string | Absolute path to read |
| `offset` | number | Optional start line |
| `limit` | number | Optional line count |

**Glob:**

| Field | Type | Description |
|-------|------|-------------|
| `pattern` | string | Glob pattern |
| `path` | string | Optional search directory |

**Grep:**

| Field | Type | Description |
|-------|------|-------------|
| `pattern` | string | Regex pattern |
| `path` | string | Optional search path |
| `glob` | string | Optional file filter |
| `output_mode` | string | `"content"`, `"files_with_matches"`, `"count"` |
| `-i` | boolean | Case insensitive |
| `multiline` | boolean | Multiline matching |

**WebFetch:**

| Field | Type | Description |
|-------|------|-------------|
| `url` | string | URL to fetch |
| `prompt` | string | Processing prompt |

**WebSearch:**

| Field | Type | Description |
|-------|------|-------------|
| `query` | string | Search query |
| `allowed_domains` | array | Include-only domains |
| `blocked_domains` | array | Excluded domains |

**Task (subagent):**

| Field | Type | Description |
|-------|------|-------------|
| `prompt` | string | Task for agent |
| `description` | string | Short description |
| `subagent_type` | string | Agent type |
| `model` | string | Optional model override |

### Output — Decision Control

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Destructive command blocked",
    "updatedInput": {"command": "safer-command"},
    "additionalContext": "Extra context for Claude"
  }
}
```

| Field | Description |
|-------|-------------|
| `permissionDecision` | `"allow"` (bypass permissions), `"deny"` (block), `"ask"` (prompt user) |
| `permissionDecisionReason` | For allow/ask: shown to user. For deny: shown to Claude |
| `updatedInput` | Modify tool input before execution |
| `additionalContext` | Context added before tool executes |

**Deprecated:** Top-level `decision`/`reason` for PreToolUse. Use `hookSpecificOutput.permissionDecision` instead. `"approve"` → `"allow"`, `"block"` → `"deny"`.

---

## PermissionRequest

**When:** Permission dialog is about to be shown to the user.
**Matcher:** Tool name (same as PreToolUse).
**Can block:** Yes (deny permission).

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "PermissionRequest",
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf node_modules"
  },
  "permission_suggestions": [
    {"type": "toolAlwaysAllow", "tool": "Bash"}
  ]
}
```

| Field | Description |
|-------|-------------|
| `permission_suggestions` | "Always allow" options the user would normally see |

### Output — Decision Control

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "updatedInput": {"command": "npm run lint"},
      "updatedPermissions": [{"type": "toolAlwaysAllow", "tool": "Bash"}]
    }
  }
}
```

| Field | Description |
|-------|-------------|
| `behavior` | `"allow"` or `"deny"` |
| `updatedInput` | For allow: modify tool input |
| `updatedPermissions` | For allow: apply permission rules |
| `message` | For deny: tells Claude why |
| `interrupt` | For deny: if `true`, stops Claude |

**Note:** PermissionRequest hooks do NOT fire in non-interactive mode (`-p`). Use PreToolUse for automated decisions.

---

## PostToolUse

**When:** After a tool completes successfully.
**Matcher:** Tool name.
**Can block:** No (tool already ran).

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/path/to/file.txt",
    "content": "file content"
  },
  "tool_response": {
    "filePath": "/path/to/file.txt",
    "success": true
  },
  "tool_use_id": "toolu_01ABC123..."
}
```

### Output

```json
{
  "decision": "block",
  "reason": "Lint errors detected in written file",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Lint output: ...",
    "updatedMCPToolOutput": "replacement output for MCP tools only"
  }
}
```

| Field | Description |
|-------|-------------|
| `decision` | `"block"` prompts Claude with reason. Omit to allow |
| `additionalContext` | Additional context for Claude |
| `updatedMCPToolOutput` | For MCP tools only: replaces tool output |

---

## PostToolUseFailure

**When:** After a tool execution fails.
**Matcher:** Tool name.
**Can block:** No (tool already failed).

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "PostToolUseFailure",
  "tool_name": "Bash",
  "tool_input": {"command": "npm test"},
  "tool_use_id": "toolu_01ABC123...",
  "error": "Command exited with non-zero status code 1",
  "is_interrupt": false
}
```

| Field | Description |
|-------|-------------|
| `error` | What went wrong |
| `is_interrupt` | Whether failure was caused by user interruption |

### Output

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUseFailure",
    "additionalContext": "Additional failure context for Claude"
  }
}
```

---

## Notification

**When:** Claude Code sends a notification.
**Matcher:** Notification type — `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`.
**Can block:** No.

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "Notification",
  "message": "Claude needs your permission to use Bash",
  "title": "Permission needed",
  "notification_type": "permission_prompt"
}
```

### Output

Can return `additionalContext` to add context to the conversation.

---

## SubagentStart

**When:** A subagent is spawned via the Task tool.
**Matcher:** Agent type — `Bash`, `Explore`, `Plan`, custom agent names.
**Can block:** No.

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "SubagentStart",
  "agent_id": "agent-abc123",
  "agent_type": "Explore"
}
```

### Output

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStart",
    "additionalContext": "Follow security guidelines for this task"
  }
}
```

The `additionalContext` is injected into the subagent's context.

---

## SubagentStop

**When:** A subagent has finished responding.
**Matcher:** Agent type (same as SubagentStart).
**Can block:** Yes (prevent subagent from stopping).

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "~/.claude/projects/.../abc123.jsonl",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "SubagentStop",
  "stop_hook_active": false,
  "agent_id": "def456",
  "agent_type": "Explore",
  "agent_transcript_path": "~/.claude/projects/.../abc123/subagents/agent-def456.jsonl"
}
```

| Field | Description |
|-------|-------------|
| `stop_hook_active` | `true` if already continuing from a stop hook — check to prevent loops |
| `agent_id` | Unique subagent identifier |
| `agent_type` | Agent type (used for matcher) |
| `agent_transcript_path` | Subagent's own transcript |

### Output

Same as Stop hooks — use `decision: "block"` with `reason`.

---

## Stop

**When:** Main Claude Code agent finishes responding. Does NOT fire on user interrupt.
**Matcher:** No matcher support — always fires.
**Can block:** Yes.

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "~/.claude/projects/.../session.jsonl",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "stop_hook_active": true
}
```

| Field | Description |
|-------|-------------|
| `stop_hook_active` | `true` when Claude is already continuing due to a stop hook. **Check this to prevent infinite loops** |

### Output

```json
{
  "decision": "block",
  "reason": "Tests must pass before stopping"
}
```

### Preventing Infinite Loops

```bash
#!/bin/bash
INPUT=$(cat)
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0  # Allow stop — we already ran once
fi
# ... your validation logic ...
```

---

## TeammateIdle

**When:** An agent team teammate is about to go idle.
**Matcher:** No matcher support — always fires.
**Can block:** Yes (exit 2 keeps teammate working).

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "TeammateIdle",
  "teammate_name": "researcher",
  "team_name": "my-project"
}
```

### Output

Exit code only — no JSON decision control. Exit 2 + stderr message keeps teammate working.

```bash
#!/bin/bash
if [ ! -f "./dist/output.js" ]; then
  echo "Build artifact missing. Run the build before stopping." >&2
  exit 2
fi
exit 0
```

**Note:** TeammateIdle does NOT support prompt or agent hook types.

---

## TaskCompleted

**When:** A task is being marked as completed. Fires when any agent uses TaskUpdate to complete a task, or when a teammate finishes with in-progress tasks.
**Matcher:** No matcher support — always fires.
**Can block:** Yes (exit 2 prevents completion).

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "TaskCompleted",
  "task_id": "task-001",
  "task_subject": "Implement user authentication",
  "task_description": "Add login and signup endpoints",
  "teammate_name": "implementer",
  "team_name": "my-project"
}
```

| Field | Description |
|-------|-------------|
| `task_id` | Task identifier |
| `task_subject` | Task title |
| `task_description` | Detailed description (may be absent) |
| `teammate_name` | Teammate completing task (may be absent) |
| `team_name` | Team name (may be absent) |

### Output

Exit code only — no JSON decision control.

```bash
#!/bin/bash
INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject')

if ! npm test 2>&1; then
  echo "Tests not passing. Fix before completing: $TASK_SUBJECT" >&2
  exit 2
fi
exit 0
```

---

## PreCompact

**When:** Before context compaction.
**Matcher:** Trigger — `manual` (from `/compact`), `auto` (context window full).
**Can block:** No.

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "PreCompact",
  "trigger": "manual",
  "custom_instructions": ""
}
```

| Field | Description |
|-------|-------------|
| `trigger` | `"manual"` or `"auto"` |
| `custom_instructions` | For manual: what user passes to `/compact`. For auto: empty |

---

## SessionEnd

**When:** Session terminates.
**Matcher:** Reason — `clear`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other`.
**Can block:** No.

### Input

```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "default",
  "hook_event_name": "SessionEnd",
  "reason": "other"
}
```

No decision control — cannot block session termination. Use for cleanup and logging.

---

## Exit Code 2 Behavior Summary

| Event | Can Block? | What Happens on Exit 2 |
|-------|-----------|----------------------|
| PreToolUse | Yes | Blocks tool call |
| PermissionRequest | Yes | Denies permission |
| UserPromptSubmit | Yes | Blocks prompt, erases from context |
| Stop | Yes | Prevents stopping, continues conversation |
| SubagentStop | Yes | Prevents subagent from stopping |
| TeammateIdle | Yes | Teammate continues working |
| TaskCompleted | Yes | Task not marked complete |
| PostToolUse | No | Shows stderr to Claude |
| PostToolUseFailure | No | Shows stderr to Claude |
| Notification | No | Shows stderr to user only |
| SubagentStart | No | Shows stderr to user only |
| SessionStart | No | Shows stderr to user only |
| SessionEnd | No | Shows stderr to user only |
| PreCompact | No | Shows stderr to user only |
