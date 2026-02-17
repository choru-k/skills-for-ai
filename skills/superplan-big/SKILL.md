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

You create the **forest view** and define phase boundaries.

## Hard Rules

1. Use caller-provided `target_directory` as the **ticket root**.
2. Create only big-tier root artifacts:
   - `<target_directory>/main.md`
   - `<target_directory>/phase-1.md`, `phase-2.md`, ...
3. Do **not** create `phase-*` directories in this tier.
4. Do **not** create `item-*`, `task-*`, or `plan.md` in this tier.
5. Use **lazy expansion**: phase directories are created later by `superplan-medium`.

## Scope

Use this tier when work:
- Requires architecture decisions
- Spans many components/services (~15+ files)
- Needs multi-phase sequencing over days/weeks

## 1. Determine Target Root

Use `target_directory` from caller. Keep all outputs in this folder.

## 2. Gather Requirements (if needed)

Ask up to **3 targeted questions** only when critical context is missing:
- Business/user outcome
- Constraints and trade-offs
- Timeline/milestones

## 3. Architecture Analysis

Before writing:
- Define system boundaries
- Define high-level data flow
- Select stack/approach rationale
- Identify key risks and mitigations
- Split work into clear executable phases

## 4. Write Root main.md

Create `<target_directory>/main.md` with:
- Frontmatter (`tier: big`)
- Goal/scope (in/out)
- Architecture overview
- Components and data flow
- Key decisions + alternatives
- Risk register
- **Phase Index** linking to `[[phase-1]]`, `[[phase-2]]`, ...
- `## Quality Findings`
- `## Architecture Findings`
- `## Security Findings`
- `## Performance Findings`
- `## Tester Findings`
- `## Approval` (Quality / Architecture / Security / Performance / Tester / Overall)
- Log

## 5. Write phase stubs (`phase-*.md`)

Create one stub per phase at ticket root.

Template:

```markdown
---
type: phase-entry
status: pending
parent: [[main]]
phase: <N>
---

# Phase <N>: <Phase Title>

## Goal
<what this phase delivers>

## Scope
- In: ...
- Out: ...

## Dependencies
- Depends on: <none or prior phase>

## Exit Criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

## Expand
- Run `/superplan medium` for this phase.
- This will create `./phase-<N>/main.md` and `item-*.md` files.
```

## 6. Return Summary

Return:
- Root `main.md` path
- Created `phase-*.md` list
- Recommended first phase to expand with `/superplan medium`

## Important Notes

- Big tier is architecture + phased decomposition only.
- Keep phase stubs concise and executable.
- Preserve existing root files: read/update, do not blindly overwrite.
