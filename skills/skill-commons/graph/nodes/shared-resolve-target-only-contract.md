---
id: shared-resolve-target-only-contract
description: Standard contract for resolve_target_only integration calls to avoid delegation loops.
status: active
tags: [contract, integration]
links:
  - [[shared-return-summary-contract]]
---

# Shared Contract: resolve_target_only

When called with `resolve_target_only: true`:

1. resolve/create required target path(s)
2. return `target_directory` plus minimal metadata
3. stop immediately (do not invoke downstream planner)

Purpose:
- prevent recursive delegation
- provide deterministic target resolution behavior
