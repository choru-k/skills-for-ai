---
id: migrate-bulk-projects
description: Scan and migrate multiple legacy personal projects with explicit confirmation scope.
status: active
tags: [node, migration]
links:
  - [[migrate-single-project]]
  - [[return-summary]]
---

# Migrate Bulk Projects

Flow:
1. scan active personal projects for legacy markers
2. show candidate list
3. confirm scope (all or selected)
4. run single-project migration for each selected project
5. return summary table (project, moved file count, destination)
