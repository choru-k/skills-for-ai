---
name: cc-mung-notify
description: Install and validate mung desktop notification hooks for Claude Code with metadata-first source/session/kind/dedupe lanes.
disable-model-invocation: true
---

# cc-mung-notify

Use this skill when you want to set up or validate `mung` notifications for Claude Code.

## What it provides

- Hook-based alerts for Claude lifecycle events
- Metadata-first mung contract:
  - `--source`
  - `--session`
  - `--kind` (`action` / `update`)
  - `--dedupe-key` session lanes
- Focus on-click helper for wezterm/ghostty + tmux/zellij contexts

## Source files

- `hooks/hooks.json`
- `hooks/mung-notify.sh`
- `hooks/mung-focus.sh`
- `README.md`
- `E2E.md`

## Validation

Run deterministic smoke:

```bash
bash public/claude/cc-mung-notify/tests/test-hook-smoke.sh
```

Run live Claude E2E:

```bash
bash public/claude/cc-mung-notify/tests/test-claude-e2e.sh
```
