---
id: extract-ticket-number
description: Resolve CENG ticket number from branch first, then ask user if missing.
status: active
tags: [node, ticket]
links:
  - [[fetch-jira-details]]
  - "../../../skill-commons/graph/nodes/shared-extract-ceng-ticket-contract.md"
---

# Extract Ticket Number

## Primary method

Run:

`git branch --show-current`

Extract `CENG-\d+` from branch name.

## Fallback

If no ticket pattern exists, ask user for ticket number.

## Output Contract

Return normalized `ticket_name` (e.g., `CENG-1234`).
