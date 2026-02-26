---
id: shared-active-archive-folder-state-contract
description: Standard folder-state resolution pattern for active/archive/new lifecycle paths.
status: active
tags: [contract, lifecycle, folder]
links:
  - [[shared-return-summary-contract]]
---

# Shared Contract: active/archive/new folder state

Resolution order:
1. check active path
2. check archive path
3. create new active path when missing

Return state as one of:
- `active`
- `archived`
- `new`

Behavioral expectations:
- preserve existing notes
- ask confirmation before archive/reopen transitions
