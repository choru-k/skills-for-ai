---
id: delegate-once
description: Execute exactly one tier workflow for the selected tier.
status: active
tags: [node, execution]
links:
  - [[return-summary]]
---

# Execute Tier Once

## Hard Rule

Execute exactly one tier per invocation.

## Mapping

- `big` -> run big-tier workflow docs under `tiers/big/graph/`
- `medium` -> run medium-tier workflow docs under `tiers/medium/graph/`
- `small` -> run small-tier workflow docs under `tiers/small/graph/`

## Payload / Context

Use:
- `target_directory`
- selected tier
- ticket/project metadata
- user goals/constraints
- `phase_file` / `item_file` when available

Do not invoke another skill. Perform the selected tier work directly in `/superplan`.
Do not auto-run additional tiers in the same invocation.
