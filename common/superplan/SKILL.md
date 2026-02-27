---
name: superplan
description: |
  Hierarchical planning router for big/medium/small tiers.
  Resolves save location, selects tier, and delegates one tier per run.
  Supports root→phase→item expansion workflow.
user-invocable: true
argument-hint: "[small|medium|big] [phase-<N>] [item-<N>]"
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion, Skill
---

# Superplan (Hierarchical Router)

Router-only skill. It must not generate plan artifacts directly.

## Progressive Loading Contract (Skill Graph)

For each invocation, load in order:
1. `graph/index.md`
2. `graph/mocs/router-flow.md`
3. Only required nodes under `graph/nodes/`
4. Delegate to exactly one child tier skill

## Hard Rules

1. Resolve valid `target_directory` before delegation.
2. Delegate exactly one tier (`big` or `medium` or `small`) per invocation.
3. Keep all generated files inside the ticket/project folder tree.
4. Do not auto-run child planners in the same invocation.
5. Router does not write tier artifacts itself.

## Hierarchy Model

- **big** (ticket root): `main.md` + `phase-*.md`
- **medium** (expand one phase): `phase-<N>/main.md` + `item-*.md`
- **small** (expand one item): `phase-<N>/item-<N>/main.md` + `task-*.md` + `plan.md`

Use lazy expansion: only selected phase/item is expanded.

## Router Flow

| Stage | Load |
|------|------|
| Resolve target | `graph/nodes/resolve-target-directory.md` |
| Validate target | `graph/nodes/validate-target-directory.md` |
| Determine tier | `graph/nodes/determine-tier.md` |
| Resolve context | `graph/nodes/resolve-expansion-context.md` |
| Delegate once | `graph/nodes/delegate-once.md` |
| Return summary | `graph/nodes/return-summary.md` |

## Delegation Targets

- `big` -> `superplan-big`
- `medium` -> `superplan-medium`
- `small` -> `superplan-small`

Always pass:
- `target_directory`
- selected tier
- ticket/project metadata
- user goals/constraints
- `phase_file` / `item_file` when available

## Return Contract

Return:
- selected tier
- target directory
- delegated planner
- expansion context passed (`phase_file`, `item_file` when present)

Do not claim artifact creation by router itself.
