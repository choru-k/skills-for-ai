---
id: delegate-superplan
description: Delegate ticket-scoped planning to superplan with explicit target_directory.
status: active
tags: [node, delegation]
links:
  - [[return-summary]]
  - "../../../skill-commons/graph/nodes/shared-delegate-superplan-contract.md"
---

# Delegate Superplan

Invoke `superplan` when user asks to create/recreate plan.

## Required payload

- `target_directory`: `~/Desktop/choru/choru-notes/1-projects/work/CENG-XXXX/`
- `ticket_type`: `work`
- `ticket_name`: `CENG-XXXX`
- jira details (summary, acceptance criteria, constraints)
- requested tier if present (`small|medium|big`)
- full user goal/context

## Hard Rule

Never call `/superplan` without explicit `target_directory`.
