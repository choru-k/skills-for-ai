---
id: superplan-index
description: Entrypoint for single-skill superplan execution.
status: active
tags: [index, superplan, router]
links:
  - [[router-flow]]
---

# Superplan Graph Index

Use this index first, then load only nodes needed for the current invocation.

## Progressive Disclosure

1. `graph/index.md`
2. `graph/mocs/router-flow.md`
3. Relevant nodes under `graph/nodes/`
4. Tier playbook docs only after tier decision

## Routing + Execution

- Resolve target first, then tier, then execute exactly one tier workflow.
- Do not chain-run multiple tiers in one invocation.

## MOCs

- [[router-flow]]
