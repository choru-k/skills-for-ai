# Work Ticket Folder Structure

## Location

All work ticket plans are stored in the Obsidian vault:

```
~/Desktop/choru/choru-notes/1-projects/work/    # Active tickets
~/Desktop/choru/choru-notes/4-archive/work/      # Completed tickets
```

## Folder Organization

Tickets are organized by lifecycle status using PARA:

```
choru-notes/
├── 1-projects/
│   └── work/
│       ├── CENG-1234/
│       │   ├── main.md           # Main plan file
│       │   ├── api-design.md     # Task-specific file
│       │   └── testing-plan.md   # Task-specific file
│       └── CENG-5678/
│           ├── main.md
│           └── implementation.md
└── 4-archive/
    └── work/
        └── CENG-9999/
            ├── main.md
            └── implementation.md
```

## Workflow

1. **New ticket** - Create folder in `1-projects/work/CENG-XXXX/`
2. **Active work** - Update files in `1-projects/work/CENG-XXXX/`
3. **PR merged** - Move folder to `4-archive/work/CENG-XXXX/`
4. **Reopened** - Move folder back to `1-projects/work/` if more work needed

## File Conventions

### main.md

The primary file for each ticket. Contains:

1. **Header** - Ticket number and title
2. **Status** - Checklist of major tasks
3. **Overview** - Brief description
4. **Related Files** - Links to task files
5. **Notes** - Additional context

### Task Files

Individual `.md` files for specific tasks:

- Use descriptive kebab-case names
- Each file focuses on one aspect of the implementation
- Include detailed notes, code snippets, decisions

## Obsidian Compatibility

- Use wiki-links: `[[other-file]]` or `[[other-file|Display Text]]`
- Use standard markdown headers, lists, code blocks
- Tags can be used: `#work #planning`

## Examples

### Active Ticket

```
1-projects/work/CENG-5714/
├── main.md                    # Overall plan and status
├── api-changes.md             # API design decisions
├── database-schema.md         # DB migration notes
└── testing-strategy.md        # Test plan
```

### Example main.md

```markdown
---
type: project
status: active
start-date: 2024-01-15
area: career
tags:
  - work
  - CENG-5714
---

# CENG-5714: Implement Feature X

## Status
- [x] Design API
- [x] Database schema
- [ ] Implementation
- [ ] Testing
- [ ] Documentation

## Overview
Implement feature X to allow users to do Y.

## Related Files
- [[api-changes]] - API design
- [[database-schema]] - Schema changes
- [[testing-strategy]] - Test plan

## Jira Link
https://clumio.atlassian.net/browse/CENG-5714

## Notes
- Discussed with team on 2024-01-15
- Depends on CENG-5700 being merged first
```
