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

You are a router only. You do not create plan content yourself.

## Hard Rules

1. Resolve valid `target_directory` before delegation.
2. Delegate exactly one tier (`big` OR `medium` OR `small`) per invocation.
3. Keep all generated files inside the ticket/project folder tree.
4. Do not auto-run child planners in the same invocation.

## Hierarchy Model

- **big** (ticket root): creates `main.md` + `phase-*.md`
- **medium** (expand one phase): creates `phase-<N>/main.md` + `item-*.md`
- **small** (expand one item): creates `phase-<N>/item-<N>/main.md` + `task-*.md` + `plan.md`

Use lazy expansion: only selected phase/item is expanded.

## 1. Resolve Save Location

### Case A: Called by ticket skills

If caller provides `target_directory`, use it directly.

### Case B: Called directly

Ask where to save:
- choru-ticket (personal project)
- work-ticket (work/Jira)
- direct folder path

If direct path is chosen:
1. Ask absolute path.
2. `mkdir -p <path>` when needed.
3. Verify it exists.

## 2. Validate Target Directory

If missing, stop and ask for save method again.

If coming from ticket skills, expected roots:
- `~/Desktop/choru/choru-notes/1-projects/personal/`
- `~/Desktop/choru/choru-notes/1-projects/work/`

If outside these roots, ask for confirmation.

## 3. Determine Tier

Use `$ARGUMENTS` first (`small|medium|big`).
If absent, infer:
- small: focused change, 1-5 files
- medium: multi-item phase, 6-15 files
- big: architecture/system redesign, 15+ files

Ask only if truly ambiguous.

## 4. Resolve Expansion Context

Before delegating, pass the most specific context available:

- For **big**: ticket root only (`target_directory`).
- For **medium**:
  - pass `target_directory` (ticket root)
  - pass `phase_file` if user specified `phase-<N>`
- For **small**:
  - pass `target_directory` (phase directory if known; otherwise ticket root)
  - pass `item_file` if user specified `item-<N>`
  - pass `phase_file` when available to help small locate item context

If context is incomplete, child planner should ask user to choose the phase/item.

## 5. Delegate Once

Invoke exactly one planner:
- `superplan-big`
- `superplan-medium`
- `superplan-small`

Pass:
- `target_directory`
- selected tier
- ticket/project metadata
- user goals/constraints
- resolved `phase_file`/`item_file` when available

## 6. Return Summary

Return:
- selected tier
- target directory
- delegated planner
- expansion context passed (`phase_file`/`item_file` if any)

## Important Notes

- Router only: do not write plan files in this skill.
- Keep flow one-by-one across tiers.
- For medium/small runs, prefer explicit selected phase/item context.
