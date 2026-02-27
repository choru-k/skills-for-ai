---
id: routing
description: Routing flow for action selection, repository selection, and ticket extraction.
status: active
tags: [moc, routing]
links:
  - [[determine-action]]
  - [[select-repository]]
  - [[extract-ticket-number]]
  - [[return-summary]]
---

# Routing MOC

## Flow

1. [[determine-action]]
2. [[select-repository]] (if action requires repo)
3. [[extract-ticket-number]] (for create/switch/cleanup)
4. route to execution MOC
