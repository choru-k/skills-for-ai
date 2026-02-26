---
name: choru-ticket
description: Manage personal projects (no ticket IDs) in Obsidian vault. Supports project/plan workflow plus legacy-folder migration for users with multiple repos.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion, Skill
---

# Choru Personal Project Management (No Ticket IDs)

Manage personal work using project names (not ticket IDs). This skill delegates implementation planning to `/superplan`.

## Progressive Loading Contract (Skill Graph)

For each invocation, load in order:

1. `graph/index.md`
2. one MOC: `graph/mocs/intake.md`, `graph/mocs/planning.md`, `graph/mocs/migration.md`, or `graph/mocs/lifecycle.md`
3. only required node files under `graph/nodes/`
4. deep references only when needed (`references/folder-structure.md`, `references/migration.md`)

## Hard Rules

1. No ticket-number system is required for personal work.
2. Always pass explicit `target_directory` when delegating to `/superplan`.
3. Keep generated plan files inside `plans/YYYY-MM-DD-<plan-name>/`.
4. Read existing files before updating.
5. If invoked with `resolve_target_only: true`, resolve and return target metadata, then stop.

## Route by Intent

| Intent | MOC |
|------|------|
| Resolve/open project context | `graph/mocs/intake.md` |
| Create/recreate plan | `graph/mocs/planning.md` |
| Legacy migration | `graph/mocs/migration.md` |
| Project lifecycle actions | `graph/mocs/lifecycle.md` |

## Core Flows

### Intake Flow

| Stage | Load |
|------|------|
| Resolve project name | `graph/nodes/resolve-project-name.md` |
| Resolve project folder | `graph/nodes/resolve-project-folder.md` |
| Detect legacy layout | `graph/nodes/detect-legacy-layout.md` |
| Handle resolve-only mode | `graph/nodes/handle-resolve-target-only.md` |
| Return summary | `graph/nodes/return-summary.md` |

### Planning Flow

| Stage | Load |
|------|------|
| Resolve project name | `graph/nodes/resolve-project-name.md` |
| Resolve project folder | `graph/nodes/resolve-project-folder.md` |
| Resolve plan folder | `graph/nodes/resolve-plan-folder.md` |
| Delegate `/superplan` | `graph/nodes/delegate-superplan.md` |
| Update project hub | `graph/nodes/update-project-hub.md` |
| Return summary | `graph/nodes/return-summary.md` |

### Migration Flow

| Stage | Load |
|------|------|
| Resolve project folder / scan | `graph/nodes/resolve-project-folder.md` |
| Detect legacy markers | `graph/nodes/detect-legacy-layout.md` |
| Migrate one project | `graph/nodes/migrate-single-project.md` |
| Migrate many projects | `graph/nodes/migrate-bulk-projects.md` |
| Update project hub | `graph/nodes/update-project-hub.md` |
| Return summary | `graph/nodes/return-summary.md` |

### Lifecycle Flow

| Stage | Load |
|------|------|
| Resolve project name | `graph/nodes/resolve-project-name.md` |
| Resolve project folder | `graph/nodes/resolve-project-folder.md` |
| Apply lifecycle action | `graph/nodes/lifecycle-actions.md` |
| Return summary | `graph/nodes/return-summary.md` |

## Important

- Preserve existing notes and progress.
- Use Obsidian markdown and wikilinks (`[[...]]`).
- Prefer project-name language over ticket language for personal work.
