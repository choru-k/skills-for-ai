---
name: front-compaction-claude
description: Prepare manual front-only compaction for Claude Code by compacting oldest N% with hard tail replay default. Use only when user explicitly asks for /front-compaction-claude.
argument-hint: "[percent] [optional focus]"
disable-model-invocation: true
allowed-tools: Bash($HOME/dotfiles/claude/hooks/front-compaction/prepare-front-compaction.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/claude/hooks/front-compaction/prepare-front-compaction.sh *)
---

Prepare front compaction context pack for the current Claude session:

!`${CLAUDE_PLUGIN_ROOT:-$HOME/dotfiles}/claude/hooks/front-compaction/prepare-front-compaction.sh --session-id ${CLAUDE_SESSION_ID} --cwd "$CLAUDE_PROJECT_DIR" $ARGUMENTS`

After preparation:
1. Tell the user to run `/compact` immediately.
2. Explain that hard tail replay is injected on `SessionStart(compact)`.
3. If the script prints `Unsupported:` or validation error text, do not suggest fallback; surface the failure clearly.
