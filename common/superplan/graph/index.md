---
id: superplan-index
description: Entrypoint for superplan router execution.
status: active
tags: [index, superplan, router]
links:
  - [[router-flow]]
---

# Superplan Graph Index

Use this index first, then load only the nodes needed for the current invocation.

## Progressive Disclosure

1. `graph/index.md`
2. `graph/mocs/router-flow.md`
3. Relevant nodes under `graph/nodes/`
4. Child tier skill docs only after delegation decision

## Routing

- Always execute as router-only skill.
- Resolve target first, then tier, then delegate exactly one child planner.

## MOCs

- [[router-flow]]
