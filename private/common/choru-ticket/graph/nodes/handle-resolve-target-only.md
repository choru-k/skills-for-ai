---
id: handle-resolve-target-only
description: Support resolve-only calls from superplan by returning metadata and stopping.
status: active
tags: [node, integration]
links:
  - [[return-summary]]
  - "../../../skill-commons/graph/nodes/shared-resolve-target-only-contract.md"
---

# Handle resolve_target_only

If invoked by `/superplan` with `resolve_target_only: true`:
1. resolve/create project folder
2. resolve/create plan folder
3. return `target_directory` + project metadata
4. stop (do not call `/superplan`)

This prevents delegation loops.
