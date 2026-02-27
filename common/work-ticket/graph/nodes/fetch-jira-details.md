---
id: fetch-jira-details
description: Fetch jira details for new tickets to seed planning context.
status: active
tags: [node, jira]
links:
  - [[resolve-ticket-folder]]
---

# Fetch Jira Details

For tickets not yet in vault, run:

`jira issue view CENG-XXXX --plain --comments 3`

Capture:
- summary
- description
- acceptance criteria
- relevant comments

Use this context when delegating to `/superplan`.
