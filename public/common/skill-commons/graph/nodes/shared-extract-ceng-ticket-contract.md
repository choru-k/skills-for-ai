---
id: shared-extract-ceng-ticket-contract
description: Standard CENG ticket extraction flow from git branch with ask fallback.
status: active
tags: [contract, ticket]
links: []
---

# Shared Contract: extract CENG ticket

Preferred extraction flow:

1. run `git branch --show-current`
2. extract `CENG-\d+` if present
3. if missing, ask user for ticket number
4. return normalized `ticket_name` (e.g., `CENG-1234`)

Use this contract for work-ticketed flows.
