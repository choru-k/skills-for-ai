---
id: choru-ticket-index
description: Entrypoint for personal project ticketless planning workflow.
status: active
tags: [index, choru-ticket]
links:
  - [[intake]]
  - [[planning]]
  - [[migration]]
  - [[lifecycle]]
---

# Choru-Ticket Graph Index

Use this index first, then load only the MOC and nodes needed for the user request.

## Progressive Disclosure

1. `graph/index.md`
2. one MOC (`[[intake]]`, `[[planning]]`, `[[migration]]`, `[[lifecycle]]`)
3. required node(s)
4. deep references only when needed

## Deep References

- `references/folder-structure.md`
- `references/migration.md`

## Invariants

- Always pass explicit `target_directory` when delegating to `/superplan`.
- Keep generated plan files under `plans/YYYY-MM-DD-<plan-name>/`.
- If called with `resolve_target_only: true`, resolve and return metadata, then stop.
