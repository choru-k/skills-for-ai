---
name: superplan-medium
description: |
  Medium-scope planner that expands a selected `phase-*.md` into a phase directory.
  Creates `phase-<N>/main.md` and `item-*.md` stubs for that phase only.
  Called by superplan router.
user-invocable: false
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# Medium Plan Skill (Expand One Phase)

**Announce:** "Expanding one phase into a medium plan with item stubs."

You expand exactly one phase from root `phase-*.md` into actionable items.

## Hard Rules

1. Use caller-provided `target_directory` as ticket root.
2. Expand exactly one phase per invocation.
3. Create only medium-tier artifacts for that phase:
   - `<target_directory>/phase-<N>/main.md`
   - `<target_directory>/phase-<N>/item-1.md`, `item-2.md`, ...
4. Do **not** create `item-*` directories in this tier.
5. Do **not** create `task-*` or `plan.md` in this tier.
6. Use **lazy expansion**: item directories are created later by `superplan-small`.

## 1. Resolve Phase Entry

Resolve which phase to expand.

Priority:
1. Use caller-provided `phase_file` if present.
2. Otherwise detect root `phase-*.md` files and ask user to choose one.
3. If no phase stubs exist, stop and instruct to run `/superplan big` first (or create a phase stub explicitly).

## 2. Create Phase Directory

Given selected `phase-<N>.md`, create:

```text
<target_directory>/phase-<N>/
```

All medium outputs for this invocation stay in that folder.

## 3. Analyze and Decompose

Before writing:
- Re-read selected root phase entry
- Clarify intended phase outcome
- Break phase into independently executable **items**
- Order items by dependency

Ask up to **2 clarifying questions** only if needed.

## 4. Write `phase-<N>/main.md`

Create `<target_directory>/phase-<N>/main.md` with:
- Frontmatter (`tier: medium`, `phase: <N>`)
- Goal and scope for this phase
- Approach
- Item index with dependency order
- Files likely touched
- Verification checkpoints
- `## Quality Findings`
- `## Architecture Findings`
- `## Security Findings`
- `## Performance Findings`
- `## Tester Findings`
- `## Approval` (Quality / Architecture / Security / Performance / Tester / Overall)
- Log

Use wikilinks to item stubs: `[[item-1]]`, `[[item-2]]`, ...

## 5. Write item stubs (`item-*.md`)

Create item entries inside phase folder.

Template:

```markdown
---
type: item-entry
status: pending
parent: [[main]]
item: <N>
---

# Item <N>: <Item Title>

## Goal
<small, independently testable outcome>

## Scope
- In: ...
- Out: ...

## Dependencies
- Depends on: <none or item-x>

## Exit Criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

## Expand
- Run `/superplan small` for this item.
- This will create `./item-<N>/main.md`, `task-*.md`, and `plan.md`.
```

## 6. Update Root Phase Entry

Update selected root `phase-<N>.md` to include:
- link to `[[phase-<N>/main]]`
- item count
- current status (`expanded` / `in-progress`)

Do not overwrite important existing content.

## 7. Return Summary

Return:
- Selected phase entry path
- Created phase directory path
- Created `item-*.md` list
- Recommended first item to expand with `/superplan small`

## Important Notes

- Medium tier = phase-level expansion only.
- No task-level details in this tier.
- Preserve existing content by read/update instead of blind overwrite.
