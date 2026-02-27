---
id: migrate-single-project
description: Migrate one legacy project from flat root files into a dated plan folder.
status: active
tags: [node, migration]
links:
  - [[update-project-hub]]
---

# Migrate Single Project

Use `references/migration.md` as source of truth.

Steps:
1. preview candidate files
2. ask confirmation + migration slug (default `legacy-import`)
3. create `plans/YYYY-MM-DD-<slug>/`
4. move legacy plan files (`task-*`, `phase-*`, and plan-style `main.md`)
5. ensure project hub `main.md` links migrated plan

Return moved files + destination.
