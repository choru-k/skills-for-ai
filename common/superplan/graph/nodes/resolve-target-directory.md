---
id: resolve-target-directory
description: Resolve target_directory before any tier decision or delegation.
status: active
tags: [node, routing]
links:
  - [[validate-target-directory]]
---

# Resolve Target Directory

## Case A: Called by ticket skill

If caller provides `target_directory`, use it directly.

## Case B: Called directly

Ask user where to save:
- `choru-ticket`
- `work-ticket`
- direct absolute path

For direct path:
1. Ask absolute path
2. `mkdir -p` when needed
3. Verify existence

## Output Contract

Return resolved `target_directory`.
