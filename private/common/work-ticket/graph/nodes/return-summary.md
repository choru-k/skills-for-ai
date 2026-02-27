---
id: return-summary
description: Return concise ticket context and action summary for the current invocation.
status: active
tags: [node, output]
links:
  - "../../../skill-commons/graph/nodes/shared-return-summary-contract.md"
---

# Return Summary

Return concise summary including:
- `ticket_name`
- resolved `target_directory`
- folder state (`active`, `archived`, `new`)
- action taken (`delegated`, `resolved-only`, `status-update`, etc.)
- next suggested action
