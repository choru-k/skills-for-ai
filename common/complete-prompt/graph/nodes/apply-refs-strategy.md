---
id: apply-refs-strategy
description: Apply full-content vs reference-only strategy based on --refs and receiver environment.
status: active
tags: [node, refs]
links:
  - [[load-template]]
---

# Apply Refs Strategy

## Without `--refs`

Embed full file contents in XML CDATA where relevant.

## With `--refs`

Use reference mode:
- include file paths and key blocks
- avoid full file content payload
- add note that receiver can read local files

Use `--refs` only when receiving AI has codebase access.
