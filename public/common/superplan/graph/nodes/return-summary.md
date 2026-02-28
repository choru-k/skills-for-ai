---
id: return-summary
description: Return concise execution result after one tier run.
status: active
tags: [node, output]
links:
  - "../../../skill-commons/graph/nodes/shared-return-summary-contract.md"
---

# Return Summary

Return:
- selected tier
- target directory
- created/updated artifact paths
- expansion context used (`phase_file`, `item_file` if any)
- recommended next command (for example `/superplan medium` or `/superplan small`)

Do not claim work for tiers that were not executed in this invocation.
