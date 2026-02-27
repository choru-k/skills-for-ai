---
name: superplan-small
description: |
  Small-scope planner that expands one `item-*.md` into an execution directory.
  Creates `item-N/main.md`, `task-*.md`, and executable `plan.md`.
  Called by superplan router.
user-invocable: false
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# Small Plan Skill (Expand One Item into Execution Plan)

**Announce:** "Expanding one item into task files and executable plan.md."

This tier creates detailed executable TDD plans for exactly one item.

## Progressive Loading Contract (Skill Graph)

1. `graph/index.md`
2. `graph/mocs/small-execution.md`
3. Required nodes only
4. Always read deep reference before task generation: `references/tdd-workflow.md`

## Hard Rules

1. Use caller-provided `target_directory` as phase directory (`.../phase-<N>/`).
2. Expand exactly one `item-*.md` per invocation.
3. Create outputs only inside selected item directory:
   - `item-<N>/main.md`
   - `item-<N>/task-*.md`
   - `item-<N>/plan.md`
4. Keep one concern per task file.
5. Do not invoke other planners.

## Scope Limits (enforced)

Per item expansion:
- max 5 files modified
- max ~2 hours effort
- max 5 tasks

If limits are exceeded, stop and instruct user to split item or revisit `/superplan medium`.

## Execution Flow

| Stage | Load |
|------|------|
| Resolve item | `graph/nodes/resolve-item-entry.md` |
| Enforce limits | `graph/nodes/enforce-small-scope-limits.md` |
| Create item dir | `graph/nodes/create-item-directory.md` |
| Analyze item | `graph/nodes/analyze-item.md` |
| Write item main | `graph/nodes/write-item-main.md` |
| Write task files | `graph/nodes/write-task-files.md` |
| Write plan.md | `graph/nodes/write-executable-plan.md` |
| Update source item | `graph/nodes/update-parent-item-entry.md` |
| Return summary | `graph/nodes/small-return-summary.md` |

## Output Requirements

### `item-<N>/main.md`
Must include:
- frontmatter (`tier: small`, `item: <N>`)
- status checklist linking task files
- goal/scope in-out
- approach
- files to modify
- links to `[[plan]]` and task files
- log

### `task-*.md`
Must follow required TDD shape from `references/tdd-workflow.md`:
1. Overview
2. Scope
3. Write test
4. Verify fail
5. Implement
6. Verify pass
7. Commit
8. Error protocol
9. Dependencies
10. Exit criteria

### `plan.md`
Must include:
- execution contract with priority `ISSUE -> TEST -> STRUCT`
- Red -> Green -> Refactor loop for `ISSUE` and `TEST`
- failing regression-first rule for `ISSUE`
- TEST queue (required)
- STRUCT queue (optional)
- findings sections (Quality / Architecture / Security / Performance / Tester)
- approval block
- fast suite commands

## Return Contract

Return:
- selected item entry path
- created item directory path
- created `main.md`, `plan.md`, and `task-*.md` paths
- recommended execution order
- effort estimate
