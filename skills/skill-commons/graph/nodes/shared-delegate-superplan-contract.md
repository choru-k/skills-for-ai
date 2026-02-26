---
id: shared-delegate-superplan-contract
description: Standard payload and hard rule for delegating to superplan.
status: active
tags: [contract, delegation]
links:
  - [[shared-return-summary-contract]]
---

# Shared Contract: delegate-superplan

Hard rule:
- never call `/superplan` without explicit `target_directory`.

Required delegation payload shape:
- `target_directory`
- `ticket_type` or project type
- ticket/project identifier
- requested tier when present (`small|medium|big`)
- user goals/constraints/context

This keeps planning delegation deterministic and auditable.
