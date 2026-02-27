---
id: delegate-superplan
description: Delegate to superplan with explicit target directory and personal project context.
status: active
tags: [node, delegation]
links:
  - [[update-project-hub]]
  - "../../../skill-commons/graph/nodes/shared-delegate-superplan-contract.md"
---

# Delegate Superplan

Invoke `superplan` for plan creation/recreation.

Required payload:
- `target_directory`
- `ticket_type: personal-project`
- `project_name`
- `plan_name`
- requested tier when present (`small|medium|big`)
- full user context/constraints

Hard rule: never call `/superplan` without explicit `target_directory`.
