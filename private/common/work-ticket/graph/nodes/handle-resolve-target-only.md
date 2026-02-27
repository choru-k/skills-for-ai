---
id: handle-resolve-target-only
description: Resolve and return target metadata when called by superplan in resolve-only mode.
status: active
tags: [node, integration]
links:
  - [[return-summary]]
  - "../../../skill-commons/graph/nodes/shared-resolve-target-only-contract.md"
---

# Handle resolve_target_only

If invoked by `/superplan` with `resolve_target_only: true`:

1. resolve/create ticket folder
2. return `target_directory` + ticket metadata
3. stop (do not call `/superplan` again)

This prevents delegation loops.
