---
id: delegate-once
description: Delegate exactly one child planner for the selected tier.
status: active
tags: [node, delegation]
links:
  - [[return-summary]]
---

# Delegate Once

## Hard Rule

Delegate exactly one tier per invocation.

## Mapping

- `big` -> `superplan-big`
- `medium` -> `superplan-medium`
- `small` -> `superplan-small`

## Payload

Include:
- `target_directory`
- selected tier
- ticket/project metadata
- user goals/constraints
- `phase_file` / `item_file` when available

Do not auto-run additional planners in same invocation.
