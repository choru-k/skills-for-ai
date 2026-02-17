---
name: superplan-small
description: |
  Small-scope planner that expands one `item-*.md` into an execution directory.
  Creates `item-<N>/main.md`, `task-*.md`, and executable `plan.md`.
  Called by superplan router.
user-invocable: false
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# Small Plan Skill (Expand One Item into Execution Plan)

**Announce:** "Expanding one item into task files and executable plan.md."

You create detailed, executable TDD plans for exactly one item.

## Hard Rules

1. Use caller-provided `target_directory` as the **phase directory** (e.g., `.../phase-1/`).
2. Expand exactly one `item-*.md` per invocation.
3. Create outputs only inside that item directory:
   - `item-<N>/main.md`
   - `item-<N>/task-*.md`
   - `item-<N>/plan.md`
4. Keep one concern per task file.
5. Do not invoke other planners.

**Reference:** Read `references/tdd-workflow.md` before generating task files.

## Constraints

Per item expansion, keep scope small:
- **Max 5 files** modified across all tasks
- **Max ~2 hours** estimated effort
- **Max 5 tasks**

If scope exceeds limits, stop and return:
> "This item exceeds small-plan limits (>5 files or >2h). Split the item or revisit phase decomposition in `/superplan medium`."

## 1. Resolve Item Entry

Resolve which item to expand.

Priority:
1. Use caller-provided `item_file` if present.
2. Otherwise detect `item-*.md` in phase directory and ask user to choose one.
3. If no item stubs exist, stop and instruct to run `/superplan medium` for this phase first.

## 2. Create Item Directory

For selected `item-<N>.md`, create:

```text
<phase_directory>/item-<N>/
```

All small outputs for this invocation stay in that folder.

## 3. Analyze the Item

Before writing:
- Read selected `item-<N>.md`
- Read phase `main.md`
- Determine smallest independently testable tasks
- Determine exact files and commands

Ask **max 2 clarifying questions** only if ambiguity blocks execution.

## 4. Write `item-<N>/main.md`

Create item-local main plan:

```markdown
---
type: project
status: active
tier: small
item: <N>
tags: [project]
---

# Item <N>: <Title>

## Status
- [ ] Task 1: <name> → [[task-1-name]]
- [ ] Task 2: <name> → [[task-2-name]]

## Goal
<1-2 sentences>

## Scope
**In scope:**
- ...

**Out of scope:**
- ...

## Approach
<2-4 sentences>

## Files to Modify
- `path/to/file.ext` — ...

## Execution
- Run incremental implementation using [[plan]]

## Related Files
- [[plan]]
- [[task-1-name]]

## Log
- YYYY-MM-DD: Created item execution plan
```

## 5. Write `task-*.md`

Create task files in item directory using TDD 5-step structure from `references/tdd-workflow.md`.

Each task file must include:
1. Overview
2. Scope
3. Step 1: Write Test
4. Step 2: Verify Test Fails
5. Step 3: Implement
6. Step 4: Verify Test Passes
7. Step 5: Commit
8. Error Protocol
9. Dependencies
10. Exit Criteria

## 6. Write `item-<N>/plan.md`

Create executable queue for coding agents.

It must include:

1. **Execution Contract**
   - Always follow this file.
   - Pick next unchecked actionable item by priority: `ISSUE` → `TEST` → `STRUCT`.
   - `ISSUE`/`TEST`: Red → Green → Refactor.
   - `ISSUE`: add failing regression test first.
   - `STRUCT`: structural-only (no behavior change).
   - Run fast full tests after each cycle.
   - Mark completed item.
   - Continue automatically until no required unchecked actionable items remain, blocked, or interrupted.

2. **TEST Queue**
   - `- [ ] TEST 01: <behavior>` format
   - each entry includes test file, command, red/green signals, minimal implementation boundary

3. **STRUCT Queue** (optional)
4. **Quality Findings** (`ISSUE Q-*`)
5. **Architecture Findings** (`ISSUE ARCH-*`)
6. **Security Findings** (`ISSUE SEC-*`)
7. **Performance Findings** (`ISSUE PERF-*`)
8. **Tester Findings** (`ISSUE T-*`)
9. **Approval** (Quality / Architecture / Security / Performance / Tester / Overall)
10. **Fast Suite** commands

Minimum required headings in `plan.md`:
- `## Quality Findings`
- `## Architecture Findings`
- `## Security Findings`
- `## Performance Findings`
- `## Tester Findings`
- `## Approval`

## 7. Update Parent Item Entry

Update selected `item-<N>.md` to include:
- link to `[[item-<N>/main]]`
- status (`expanded` / `in-progress`)
- last-updated date

Do not overwrite critical existing notes.

## 8. Return Summary

Return:
- selected item entry path
- created item directory path
- `main.md`, `plan.md`, and `task-*.md` paths
- recommended execution order
- effort estimate

## Important Notes

- Preserve existing content by read/update, not blind overwrite.
- Use Obsidian wikilinks.
- Be specific with paths, commands, and code guidance.
- `plan.md` must be directly executable by coder + quality/specialist-reviewers + tester loop.
