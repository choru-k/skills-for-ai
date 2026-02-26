---
id: work-ticket-index
description: Entrypoint for work-ticket execution using progressive disclosure.
status: active
tags: [index, work-ticket]
links:
  - [[intake]]
  - [[planning]]
  - [[lifecycle]]
---

# Work Ticket Graph Index

Use this index first, then load only the MOC and nodes needed for the current request.

## Progressive Disclosure

1. `graph/index.md`
2. one MOC (`[[intake]]`, `[[planning]]`, or `[[lifecycle]]`)
3. required node(s)
4. deep reference only when needed: `references/folder-structure.md`

## Route by Intent

- Ticket discovery/open/create -> [[intake]]
- Plan creation/recreation -> [[planning]]
- Archive/reopen/status updates -> [[lifecycle]]

## Invariants

- Always pass explicit `target_directory` when calling `/superplan`.
- If called with `resolve_target_only: true`, resolve folder and return metadata, then stop.
- Keep all plan artifacts inside the ticket folder.
