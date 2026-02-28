---
name: superplan
description: |
  Hierarchical planner for big/medium/small tiers.
  Resolves save location, selects one tier, and executes that tier directly.
  Supports root→phase→item expansion workflow.
user-invocable: true
argument-hint: "[small|medium|big] [phase-<N>] [item-<N>]"
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# Superplan (Single-Skill Hierarchical Planner)

Single-skill planner. `/superplan` executes the selected tier directly in one invocation.

## Progressive Loading Contract (Skill Graph)

For each invocation, load in order:
1. `graph/index.md`
2. `graph/mocs/router-flow.md`
3. Required nodes under `graph/nodes/`
4. Tier playbook docs only after tier selection:
   - big: `../superplan-big/graph/index.md`
   - medium: `../superplan-medium/graph/index.md`
   - small: `../superplan-small/graph/index.md`

## Hard Rules

1. Resolve valid `target_directory` before tier work.
2. Execute exactly one tier (`big` or `medium` or `small`) per invocation.
3. Keep all generated files inside the ticket/project folder tree.
4. Do not chain-run another tier automatically in the same invocation.
5. Preserve existing files via read/update (no blind overwrite).

## Hierarchy Model

- **big** (ticket root): `main.md` + `phase-*.md`
- **medium** (expand one phase): `phase-<N>/main.md` + `item-*.md`
- **small** (expand one item): `phase-<N>/item-<N>/main.md` + `task-*.md` + `plan.md`

Use lazy expansion: only selected phase/item is expanded.

## Flow

| Stage | Load |
|------|------|
| Resolve target | `graph/nodes/resolve-target-directory.md` |
| Validate target | `graph/nodes/validate-target-directory.md` |
| Determine tier | `graph/nodes/determine-tier.md` |
| Resolve context | `graph/nodes/resolve-expansion-context.md` |
| Execute selected tier once | `graph/nodes/delegate-once.md` |
| Return summary | `graph/nodes/return-summary.md` |

## Tier Execution Mapping

- `big` -> execute big-tier playbook (former `superplan-big` flow)
- `medium` -> execute medium-tier playbook (former `superplan-medium` flow)
- `small` -> execute small-tier playbook (former `superplan-small` flow)

Always pass/use:
- `target_directory`
- selected tier
- ticket/project metadata
- user goals/constraints
- `phase_file` / `item_file` when available

## Return Contract

Return:
- selected tier
- target directory
- created/updated artifact paths
- expansion context used (`phase_file`, `item_file` when present)
- recommended next `/superplan ...` command when useful
