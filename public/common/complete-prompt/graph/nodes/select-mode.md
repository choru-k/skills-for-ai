---
id: select-mode
description: Select the best mode based on user request and context type.
status: active
tags: [node, modes]
links:
  - [[extract-conversation-context]]
---

# Select Mode

Rules:
- explicit mode from user wins
- default to `full` when omitted
- ask only if ambiguity blocks useful output

Mode intent examples:
- debugging -> `debug`
- design discussion -> `architect`
- quick transfer -> `brief`
- non-technical catch-all -> `general`
