---
id: resolve-project-name
description: Resolve personal project name, normalize to kebab-case, and preserve stable naming.
status: active
tags: [node, project]
links:
  - [[resolve-project-folder]]
---

# Resolve Project Name

If project name is missing, ask user for it.

Guidance:
- stable kebab-case (`study-rust`, `home-lab`, `content-system`)
- avoid ticket-style naming

Normalize to kebab-case and return `project_name`.
