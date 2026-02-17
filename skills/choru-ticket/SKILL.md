---
name: choru-ticket
description: Manage personal projects (no ticket IDs) in Obsidian vault. Supports project/plan workflow plus legacy-folder migration for users with multiple repos.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion, Skill
---

# Choru Personal Project Management (No Ticket IDs)

Manage personal work using **project names** instead of ticket numbers.
This skill is the preferred organizer for personal work and delegates implementation planning to `/superplan`.

## Recommended System

Use **project + plan**:

1. **Project folder (long-lived)**
   - vision, repo map, notes, active plan index
2. **Plan folder (short-lived)**
   - one initiative/milestone
   - `/superplan` writes plan files here

This model works best when you have several projects and repos.

## Hard Rules

1. No ticket-number system is required for personal work.
2. Always pass explicit `target_directory` when delegating to `/superplan`.
3. Keep generated plan files inside `plans/YYYY-MM-DD-<plan-name>/`.
4. Read existing files before updating.

## References

- `references/folder-structure.md`
- `references/migration.md` (use when migrating legacy folders)

## Folder Structure (Target)

```text
~/Desktop/choru/choru-notes/
├── 1-projects/
│   └── personal/
│       └── <project-name>/
│           ├── main.md                # Project hub
│           ├── repos.md               # Repo map (optional)
│           ├── plans/
│           │   └── YYYY-MM-DD-<plan-name>/
│           │       ├── main.md
│           │       └── task-*.md / phase-*.md / related files
│           └── notes/
└── 4-archive/
    └── personal/
        └── <project-name>/
```

## Workflow

### 1. Resolve Project

If missing, ask:
- Question: "Which personal project is this for?"
- Header: "Project"
- Description: "Use a stable kebab-case name (e.g., `study-rust`, `home-lab`, `content-system`)"

Normalize to kebab-case.

### 2. Find or Create Project Folder

Check active first, then archive:

```bash
ls ~/Desktop/choru/choru-notes/1-projects/personal/ 2>/dev/null
ls ~/Desktop/choru/choru-notes/4-archive/personal/ 2>/dev/null
```

- If active exists: read `main.md` if present and summarize status.
- If archived exists: summarize and ask whether to reopen.
- If new: create
  - `~/Desktop/choru/choru-notes/1-projects/personal/<project-name>/`
  - `plans/`
  - `notes/`

### 3. Detect Legacy Flat Layout

After resolving project folder, detect old layout:
- Any root `task-*.md` or `phase-*.md`
- OR root `main.md` looks like a plan file (`tier: small|medium|big`) and `plans/` is missing/empty

If detected, ask:
- "I found legacy plan files in project root. Migrate to project+plan structure now?"

Options:
1. **Migrate now (recommended)**
2. **Not now (continue in compatibility mode)**

### 4. Resolve Plan Folder (for planning)

When planning is requested, create/find:

```text
~/Desktop/choru/choru-notes/1-projects/personal/<project-name>/plans/YYYY-MM-DD-<plan-name>/
```

Use this as `target_directory`.

### 5. Delegate to /superplan

Invoke:

```text
Skill: superplan
```

Pass:
- `target_directory`
- `ticket_type: personal-project`
- `project_name`
- `plan_name`
- requested tier if present (`small|medium|big`)
- full user context/constraints

### 6. Update Project Hub

After plan create/update:
- Ensure project root `main.md` exists
- Add/update link to the plan
- Add dated log entry

## Migration Helper (Single Project)

When user asks to migrate (or chooses migrate in step 3):

1. Read `references/migration.md`
2. Preview files to move and show user
3. Ask for migration plan slug (default: `legacy-import`)
4. Create `plans/YYYY-MM-DD-<slug>/`
5. Move legacy plan files from project root into that plan folder:
   - `main.md` (if it is plan-style)
   - `task-*.md`
   - `phase-*.md`
6. Ensure project root `main.md` is a project hub and links the migrated plan
7. Return migration summary (moved files + target path)

## Migration Helper (Bulk)

If user asks to migrate many projects:
1. Scan all active personal project folders for legacy markers
2. Show candidate list
3. Confirm migration scope (all / selected)
4. Run single-project migration per project
5. Return summary table (project, moved files count, destination)

## Direct Call Support from /superplan

If invoked by `/superplan` with `resolve_target_only: true`:
1. Resolve/create project folder
2. Resolve/create plan folder
3. Return `target_directory` and project metadata
4. **Stop** (do not call `/superplan` again)

This prevents delegation loops.

## Status Actions

Based on user request, you may:
1. List personal projects (active + archived)
2. Show active plans for a project
3. Create/update notes (`notes/*.md`)
4. Update `repos.md` with repository links
5. Migrate legacy project folders to project+plan structure
6. Archive/reopen project folders

## Important

- Preserve existing notes and progress.
- Use Obsidian markdown and wikilinks (`[[...]]`).
- Prefer project-name language over ticket language for personal work.
