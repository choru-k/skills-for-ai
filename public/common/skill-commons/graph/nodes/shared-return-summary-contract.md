---
id: shared-return-summary-contract
description: Standard concise return summary schema for routing/action skills.
status: active
tags: [contract, output]
links: []
---

# Shared Contract: return summary

Return concise summary with:
- identity (`ticket_name` or `project_name` where relevant)
- resolved key path(s) (`target_directory` or affected paths)
- state/action taken
- next suggested action

Rules:
- keep concise and structured
- do not over-claim side effects
- clearly separate resolved context from executed operations
