---
id: resolve-project-folder
description: Resolve active/archive project folder and create canonical structure for new projects.
status: active
tags: [node, folder]
links:
  - [[detect-legacy-layout]]
  - [[resolve-plan-folder]]
  - [[lifecycle-actions]]
  - "../../../skill-commons/graph/nodes/shared-active-archive-folder-state-contract.md"
---

# Resolve Project Folder

Check in order:
1. active: `~/Desktop/choru/choru-notes/1-projects/personal/<project-name>/`
2. archive: `~/Desktop/choru/choru-notes/4-archive/personal/<project-name>/`
3. create new active folder if missing

For new folders, ensure:
- `plans/`
- `notes/`

If active exists, read `main.md` when present and summarize status.
If archived exists, ask whether to reopen.
