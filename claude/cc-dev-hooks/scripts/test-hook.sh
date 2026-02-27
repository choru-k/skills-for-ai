#!/bin/bash
# Hook Testing Helper
# Tests a hook with sample input and shows output
# Supports all 14 hook events with correct input schemas

set -euo pipefail

# Usage
show_usage() {
  echo "Usage: $0 [options] <hook-script> <test-input.json>"
  echo ""
  echo "Options:"
  echo "  -h, --help      Show this help message"
  echo "  -v, --verbose   Show detailed execution information"
  echo "  -t, --timeout N Set timeout in seconds (default: 60)"
  echo ""
  echo "Examples:"
  echo "  $0 validate-bash.sh test-input.json"
  echo "  $0 -v -t 30 validate-write.sh write-input.json"
  echo ""
  echo "Creates sample test input with:"
  echo "  $0 --create-sample <event-type>"
  echo ""
  echo "Valid event types:"
  echo "  PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest,"
  echo "  UserPromptSubmit, Stop, SubagentStop, SubagentStart,"
  echo "  TeammateIdle, TaskCompleted, SessionStart, SessionEnd,"
  echo "  PreCompact, Notification"
  exit 0
}

# Create sample input
create_sample() {
  event_type="$1"

  case "$event_type" in
    PreToolUse)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/tmp/test.txt",
    "content": "Test content"
  },
  "tool_use_id": "toolu_01TestABC123"
}
EOF
      ;;
    PostToolUse)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/tmp/test.txt",
    "content": "Test content"
  },
  "tool_response": {
    "filePath": "/tmp/test.txt",
    "success": true
  },
  "tool_use_id": "toolu_01TestABC123"
}
EOF
      ;;
    PostToolUseFailure)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "PostToolUseFailure",
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm test",
    "description": "Run test suite"
  },
  "tool_use_id": "toolu_01TestABC123",
  "error": "Command exited with non-zero status code 1",
  "is_interrupt": false
}
EOF
      ;;
    PermissionRequest)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "PermissionRequest",
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf node_modules",
    "description": "Remove node_modules directory"
  },
  "permission_suggestions": [
    {"type": "toolAlwaysAllow", "tool": "Bash"}
  ]
}
EOF
      ;;
    Stop)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "stop_hook_active": false
}
EOF
      ;;
    SubagentStop)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "SubagentStop",
  "stop_hook_active": false,
  "agent_id": "agent-test123",
  "agent_type": "Explore",
  "agent_transcript_path": "/tmp/subagents/agent-test123.jsonl"
}
EOF
      ;;
    SubagentStart)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "SubagentStart",
  "agent_id": "agent-test123",
  "agent_type": "Explore"
}
EOF
      ;;
    TeammateIdle)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "TeammateIdle",
  "teammate_name": "researcher",
  "team_name": "my-project"
}
EOF
      ;;
    TaskCompleted)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "TaskCompleted",
  "task_id": "task-001",
  "task_subject": "Implement user authentication",
  "task_description": "Add login and signup endpoints",
  "teammate_name": "implementer",
  "team_name": "my-project"
}
EOF
      ;;
    UserPromptSubmit)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "UserPromptSubmit",
  "prompt": "Write a function to calculate factorial"
}
EOF
      ;;
    SessionStart)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "SessionStart",
  "source": "startup",
  "model": "claude-sonnet-4-5-20250929"
}
EOF
      ;;
    SessionEnd)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "SessionEnd",
  "reason": "other"
}
EOF
      ;;
    PreCompact)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "PreCompact",
  "trigger": "manual",
  "custom_instructions": ""
}
EOF
      ;;
    Notification)
      cat <<'EOF'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/tmp/test-project",
  "permission_mode": "default",
  "hook_event_name": "Notification",
  "message": "Claude needs your permission to use Bash",
  "title": "Permission needed",
  "notification_type": "permission_prompt"
}
EOF
      ;;
    *)
      echo "Unknown event type: $event_type"
      echo ""
      echo "Valid types: PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest,"
      echo "  UserPromptSubmit, Stop, SubagentStop, SubagentStart, TeammateIdle,"
      echo "  TaskCompleted, SessionStart, SessionEnd, PreCompact, Notification"
      exit 1
      ;;
  esac
}

# Parse arguments
VERBOSE=false
TIMEOUT=60

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_usage
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -t|--timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --create-sample)
      create_sample "$2"
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [ $# -ne 2 ]; then
  echo "Error: Missing required arguments"
  echo ""
  show_usage
fi

HOOK_SCRIPT="$1"
TEST_INPUT="$2"

# Validate inputs
if [ ! -f "$HOOK_SCRIPT" ]; then
  echo "❌ Error: Hook script not found: $HOOK_SCRIPT"
  exit 1
fi

if [ ! -x "$HOOK_SCRIPT" ]; then
  echo "⚠️  Warning: Hook script is not executable. Attempting to run with bash..."
  HOOK_SCRIPT="bash $HOOK_SCRIPT"
fi

if [ ! -f "$TEST_INPUT" ]; then
  echo "❌ Error: Test input not found: $TEST_INPUT"
  exit 1
fi

# Validate test input JSON
if ! jq empty "$TEST_INPUT" 2>/dev/null; then
  echo "❌ Error: Test input is not valid JSON"
  exit 1
fi

echo "🧪 Testing hook: $HOOK_SCRIPT"
echo "📥 Input: $TEST_INPUT"
echo ""

if [ "$VERBOSE" = true ]; then
  echo "Input JSON:"
  jq . "$TEST_INPUT"
  echo ""
fi

# Set up environment
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/tmp/test-project}"
export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(pwd)}"
export CLAUDE_ENV_FILE="${CLAUDE_ENV_FILE:-/tmp/test-env-$$}"

if [ "$VERBOSE" = true ]; then
  echo "Environment:"
  echo "  CLAUDE_PROJECT_DIR=$CLAUDE_PROJECT_DIR"
  echo "  CLAUDE_PLUGIN_ROOT=$CLAUDE_PLUGIN_ROOT"
  echo "  CLAUDE_ENV_FILE=$CLAUDE_ENV_FILE"
  echo ""
fi

# Run the hook
echo "▶️  Running hook (timeout: ${TIMEOUT}s)..."
echo ""

start_time=$(date +%s)

set +e
output=$(timeout "$TIMEOUT" bash -c "cat '$TEST_INPUT' | $HOOK_SCRIPT" 2>&1)
exit_code=$?
set -e

end_time=$(date +%s)
duration=$((end_time - start_time))

# Analyze results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results:"
echo ""
echo "Exit Code: $exit_code"
echo "Duration: ${duration}s"
echo ""

case $exit_code in
  0)
    echo "✅ Hook approved/succeeded"
    ;;
  2)
    echo "🚫 Hook blocked/denied"
    ;;
  124)
    echo "⏱️  Hook timed out after ${TIMEOUT}s"
    ;;
  *)
    echo "⚠️  Hook returned unexpected exit code: $exit_code"
    ;;
esac

echo ""
echo "Output:"
if [ -n "$output" ]; then
  echo "$output"
  echo ""

  # Try to parse as JSON
  if echo "$output" | jq empty 2>/dev/null; then
    echo "Parsed JSON output:"
    echo "$output" | jq .

    # Check for deprecated output format
    if echo "$output" | jq -e '.decision' >/dev/null 2>&1; then
      event_name=$(jq -r '.hook_event_name' "$TEST_INPUT" 2>/dev/null || echo "unknown")
      if [ "$event_name" = "PreToolUse" ]; then
        echo ""
        echo "⚠️  WARNING: Using deprecated top-level 'decision' for PreToolUse."
        echo "   Migrate to hookSpecificOutput.permissionDecision format."
      fi
    fi

    # Check for hookSpecificOutput
    if echo "$output" | jq -e '.hookSpecificOutput' >/dev/null 2>&1; then
      echo ""
      echo "✅ Uses modern hookSpecificOutput format"
    fi
  fi
else
  echo "(no output)"
fi

# Check for environment file
if [ -f "$CLAUDE_ENV_FILE" ]; then
  echo ""
  echo "Environment file created:"
  cat "$CLAUDE_ENV_FILE"
  rm -f "$CLAUDE_ENV_FILE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $exit_code -eq 0 ] || [ $exit_code -eq 2 ]; then
  echo "✅ Test completed successfully"
  exit 0
else
  echo "❌ Test failed"
  exit 1
fi
