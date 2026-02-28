---
name: cc-front-compaction
description: Prepare manual front-only compaction for Claude Code by compacting oldest N% with hard tail replay default. Use only when user explicitly asks for /cc-front-compaction.
argument-hint: "[percent] [optional focus]"
disable-model-invocation: true
allowed-tools: Bash($HOME/.share-ai/views/claude/cc-front-compaction/hooks/front-compaction/prepare-front-compaction.sh *)
---

Prepare front compaction context pack for the current Claude session:

!`$HOME/.share-ai/views/claude/cc-front-compaction/hooks/front-compaction/prepare-front-compaction.sh --session-id ${CLAUDE_SESSION_ID} --cwd "$CLAUDE_PROJECT_DIR" $ARGUMENTS`

After preparation:
1. Tell the user to run `/compact` immediately.
2. Explain that hard tail replay is injected on `SessionStart(compact)`.
3. If the script prints `Unsupported:` or validation error text, do not suggest fallback; surface the failure clearly.
