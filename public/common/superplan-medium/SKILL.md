---
name: superplan-medium
description: |
  Medium-scope planner that expands a selected `phase-*.md` into a phase directory.
  Creates `phase-N/main.md` and `item-*.md` stubs for that phase only.
  Called by superplan router.
user-invocable: false
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# Medium Plan Skill (Expand One Phase)

**Announce:** "Expanding one phase into a medium plan with item stubs."

This tier expands exactly one root phase into ordered item stubs.

## Progressive Loading Contract (Skill Graph)

1. `graph/index.md`
2. `graph/mocs/medium-execution.md`
3. Required nodes only
4. Deep reference only when needed: `references/phase-sizing.md`

## Hard Rules

1. Use caller-provided `target_directory` as ticket root.
2. Expand exactly one phase per invocation.
3. Create only medium-tier artifacts for that phase:
   - `<target_directory>/phase-<N>/main.md`
   - `<target_directory>/phase-<N>/item-1.md`, `item-2.md`, ...
4. Do not create `item-*` directories in this tier.
5. Do not create `task-*` or `plan.md` in this tier.
6. Preserve existing content by read/update (no blind overwrite).

## Execution Flow

| Stage | Load |
|------|------|
| Resolve phase | `graph/nodes/resolve-phase-entry.md` |
| Create phase dir | `graph/nodes/create-phase-directory.md` |
| Decompose to items | `graph/nodes/decompose-phase-into-items.md` |
| Write phase main | `graph/nodes/write-phase-main.md` |
| Write item stubs | `graph/nodes/write-item-stubs.md` |
| Update root phase | `graph/nodes/update-root-phase-entry.md` |
| Return summary | `graph/nodes/medium-return-summary.md` |

## Output Requirements

### `phase-<N>/main.md`
Must include:
- frontmatter (`tier: medium`, `phase: <N>`)
- goal/scope
- approach
- item index with dependency order (`[[item-1]]`, ...)
- files likely touched
- verification checkpoints
- required findings sections (Quality / Architecture / Security / Performance / Tester)
- approval block
- log

### `item-*.md` stubs
Each stub must include:
- goal
- scope in/out
- dependencies
- exit criteria checklist
- expand instruction: run `/superplan small`

## Return Contract

Return:
- selected phase entry path
- created phase directory path
- created `item-*.md` list
- recommended first item for `/superplan small`
