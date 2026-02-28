---
name: work-ticket
description: Manage work Jira tickets and plans in Obsidian vault. Use for "plan work ticket", "manage ticket", "create ticket plan", or any CENG-XXXX ticket.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion, Skill
---

# Work Ticket Management

Manage work Jira tickets and implementation plans in the Obsidian vault.
This skill owns ticket-folder lifecycle and is the preferred ticket entry point for planning via `/superplan`.

## Progressive Loading Contract (Skill Graph)

For each invocation, load in order:

1. `graph/index.md`
2. One MOC: `graph/mocs/intake.md`, `graph/mocs/planning.md`, or `graph/mocs/lifecycle.md`
3. Only required node files under `graph/nodes/`
4. Deep reference only when needed: `references/folder-structure.md`

## Hard Rules

1. When delegating to `superplan`, always pass explicit ticket context and `target_directory`.
2. `superplan` must receive explicit `target_directory`.
3. All generated plan files must stay in that ticket folder.
4. If invoked with `resolve_target_only: true`, resolve and return target metadata, then stop.

## Route by Intent

| Intent | MOC |
|------|------|
| Find/create ticket context | `graph/mocs/intake.md` |
| Create/recreate plan | `graph/mocs/planning.md` |
| Status/archive/reopen actions | `graph/mocs/lifecycle.md` |

## Core Flows

### Intake Flow

| Stage | Load |
|------|------|
| Extract ticket | `graph/nodes/extract-ticket-number.md` |
| Fetch Jira details (new ticket) | `graph/nodes/fetch-jira-details.md` |
| Resolve folder | `graph/nodes/resolve-ticket-folder.md` |
| Handle resolve-only mode | `graph/nodes/handle-resolve-target-only.md` |
| Return summary | `graph/nodes/return-summary.md` |

### Planning Flow

| Stage | Load |
|------|------|
| Resolve folder | `graph/nodes/resolve-ticket-folder.md` |
| Delegate `/superplan` | `graph/nodes/delegate-superplan.md` |
| Return summary | `graph/nodes/return-summary.md` |

### Lifecycle Flow

| Stage | Load |
|------|------|
| Resolve folder | `graph/nodes/resolve-ticket-folder.md` |
| Apply lifecycle action | `graph/nodes/status-management-actions.md` |
| Return summary | `graph/nodes/return-summary.md` |

## Integration Notes

- `/work-jira` skill for direct ticket operations (`view`, `list`, `create`)
- `/work-workspace` for git worktree operations

## Important

- Always read existing content before updating.
- Preserve notes/progress.
- Use Obsidian-compatible markdown and wikilinks.
