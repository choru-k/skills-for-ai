---
id: resolve-expansion-context
description: Resolve phase/item context payload before delegating child planner.
status: active
tags: [node, context]
links:
  - [[delegate-once]]
---

# Resolve Expansion Context

Build most specific payload based on tier.

## Big

- `target_directory` only

## Medium

- `target_directory`
- `phase_file` when user selected `phase-<N>`

## Small

- `target_directory` (phase directory if known; otherwise ticket root)
- `item_file` when user selected `item-<N>`
- `phase_file` when available

If context is incomplete, child planner should ask user to choose phase/item.
