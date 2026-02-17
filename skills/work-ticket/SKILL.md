---
name: work-ticket
description: Manage work Jira tickets and plans in Obsidian vault. Use for "plan work ticket", "manage ticket", "create ticket plan", or any CENG-XXXX ticket.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion, Skill
---

# Work Ticket Management

Manage work Jira tickets and implementation plans in the Obsidian vault.
This skill owns ticket-folder lifecycle and is the preferred ticket entry point for planning via `/superplan`.

## Hard Rules

1. When delegating to `superplan`, always pass explicit ticket context and `target_directory`.
2. `superplan` must receive explicit `target_directory`.
3. All generated plan files must stay in that ticket folder.

## Workflow

This skill may be invoked directly by the user or selected by `/superplan` when user chooses work ticket storage.

### 1. Extract Ticket Number

Try branch first:

```bash
git branch --show-current
```

Extract `CENG-\d+` (e.g., `feature/CENG-1234-description` → `CENG-1234`).
If not found, ask user for ticket number.

### 2. Fetch Jira Details (New Tickets)

For new tickets not yet in vault:

```bash
jira issue view CENG-XXXX --plain --comments 3
```

Use summary/description/acceptance criteria/comments to inform planning.

### 3. Folder Structure

```
~/Desktop/choru/choru-notes/
├── 1-projects/
│   └── work/
│       └── CENG-XXXX/
└── 4-archive/
    └── work/
        └── CENG-XXXX/
```

### 4. Find or Create Folder

Check active first, then archive:

```bash
ls -d ~/Desktop/choru/choru-notes/1-projects/work/CENG-XXXX 2>/dev/null
ls -d ~/Desktop/choru/choru-notes/4-archive/work/CENG-XXXX 2>/dev/null
```

- If found in `1-projects/work/`: read `main.md`, list `.md` files, summarize status, ask next action.
- If found in `4-archive/work/`: summarize and ask whether to reopen.
- If new: create `~/Desktop/choru/choru-notes/1-projects/work/CENG-XXXX/`.

### 5. Delegate Planning (Ticket-Scoped)

When user asks to create/recreate a plan, invoke:

```
Skill: superplan
```

Pass explicit context:
- `target_directory`: `~/Desktop/choru/choru-notes/1-projects/work/CENG-XXXX/`
- `ticket_type`: `work`
- `ticket_name`: `CENG-XXXX`
- Jira details (summary, acceptance criteria, constraints)
- Requested tier from user if present (`small|medium|big`)
- Full user goal/context

**Important:** Never call `superplan` without `target_directory`.

### 6. Direct Call Support from /superplan

If invoked by `/superplan` with `resolve_target_only: true`:
1. Resolve/create ticket folder
2. Return `target_directory` and ticket metadata
3. **Stop** (do not call `/superplan` again)

This prevents delegation loops.

### 7. Status Management Actions

Based on request, you may:
1. **Review status**
2. **Update plans** or re-run `/superplan` with same `target_directory`
3. **Add notes/task files** as needed
4. **Archive ticket** when complete:
   ```bash
   mv ~/Desktop/choru/choru-notes/1-projects/work/CENG-XXXX ~/Desktop/choru/choru-notes/4-archive/work/
   ```
5. **Reopen ticket** by moving it back to `1-projects/work/`

## Integration Notes

- `/jira` skill for direct ticket operations (`view`, `list`, `create`)
- `/work-workspace` for git worktree operations

## Important

- Always read existing content before updating.
- Preserve notes/progress.
- Use Obsidian-compatible markdown and wikilinks.
