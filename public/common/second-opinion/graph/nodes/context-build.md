---
id: context-build
description: Build handoff context with /complete-prompt and --refs.
status: active
tags: [node, context]
links:
  - [[coordinator-dispatch]]
---

# Context Build

## Non-Negotiable Rule

External AIs have zero conversation context. Always use `/complete-prompt` via Skill tool.

## Mode Selection

Use mode based on question type (see `reference/workflow.md`):
- default: `full`
- quick: `brief`
- debugging: `debug`
- design: `architect`
- review/comparison: `diff`

## Invocation

Call:
- `complete-prompt {mode} --refs`

Always include `--refs` when receiving AI can read the same working directory.

## Output Required

Capture `PROMPT_FILE_PATH` and do not proceed if missing.
