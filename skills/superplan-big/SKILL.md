---
name: superplan-big
description: |
  Architecture-level planner for new apps, services, or major system changes.
  Creates big-tier root plan files in the ticket folder: `main.md` + `phase-*.md` stubs.
  Called by superplan router.
user-invocable: false
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# Big Plan Skill (Root Architecture + Phase Stubs)

**Announce:** "Creating a big architecture plan with phase stubs."

This tier creates architecture-level root artifacts only.

## Progressive Loading Contract (Skill Graph)

1. `graph/index.md`
2. `graph/mocs/big-execution.md`
3. Required nodes only
4. Deep reference only when needed: `references/architecture-template.md`

## Hard Rules

1. Use caller-provided `target_directory` as ticket root.
2. Create only:
   - `<target_directory>/main.md`
   - `<target_directory>/phase-1.md`, `phase-2.md`, ...
3. Do **not** create `phase-*` directories in this tier.
4. Do **not** create `item-*`, `task-*`, or `plan.md` in this tier.
5. Preserve existing root files (read/update, no blind overwrite).

## Scope

Use big tier when work:
- requires architecture decisions
- spans many components/services (~15+ files)
- needs multi-phase sequencing over days/weeks

## Execution Flow

| Stage | Load |
|------|------|
| Resolve root target | `graph/nodes/resolve-root-target.md` |
| Gather requirements | `graph/nodes/gather-big-requirements.md` |
| Architecture analysis | `graph/nodes/perform-architecture-analysis.md` |
| Write root main | `graph/nodes/write-root-main.md` |
| Write phase stubs | `graph/nodes/write-phase-stubs.md` |
| Return summary | `graph/nodes/big-return-summary.md` |

## Output Requirements

### Root `main.md`
Must include:
- frontmatter (`tier: big`)
- goal/scope in-out
- architecture overview
- components/data flow
- key decisions + alternatives
- risk register
- phase index (`[[phase-1]]`, `[[phase-2]]`, ...)
- required findings sections (Quality / Architecture / Security / Performance / Tester)
- approval block
- log

### `phase-*.md` stubs
Each stub must include:
- goal
- scope in/out
- dependencies
- exit criteria checklist
- expand instruction: run `/superplan medium`

## Return Contract

Return:
- root `main.md` path
- created `phase-*.md` list
- recommended first phase for `/superplan medium`
