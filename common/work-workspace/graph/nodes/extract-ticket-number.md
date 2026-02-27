---
id: extract-ticket-number
description: Resolve CENG ticket for create/switch/cleanup operations.
status: active
tags: [node, ticket]
links:
  - [[create-worktree]]
  - [[switch-worktree]]
  - [[cleanup-worktrees]]
  - "../../../skill-commons/graph/nodes/shared-extract-ceng-ticket-contract.md"
---

# Extract Ticket Number

Try branch first:

`git branch --show-current 2>/dev/null || echo ""`

Extract `CENG-\d+` when present.

If missing, ask user for ticket number.
Return normalized `ticket_name`.
