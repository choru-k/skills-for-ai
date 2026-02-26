---
id: resolve-ticket-folder
description: Resolve active/archive ticket folder and create active folder for new tickets.
status: active
tags: [node, folder]
links:
  - [[handle-resolve-target-only]]
  - [[delegate-superplan]]
  - [[status-management-actions]]
  - "../../../skill-commons/graph/nodes/shared-active-archive-folder-state-contract.md"
---

# Resolve Ticket Folder

## Paths

- Active: `~/Desktop/choru/choru-notes/1-projects/work/CENG-XXXX/`
- Archive: `~/Desktop/choru/choru-notes/4-archive/work/CENG-XXXX/`

## Detection Order

1. Check active folder
2. Check archive folder
3. If not found, create active folder

## Behavior

- If active exists: read `main.md`, list markdown files, summarize current status, ask next action.
- If archived exists: summarize and ask whether to reopen.
- If new: create active folder and continue planning flow.

Use deep reference when needed: `references/folder-structure.md`.
