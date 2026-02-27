---
id: return-format
description: Return final response blocks and artifact pointers in a traceable structure.
status: active
tags: [node, output]
links: []
---

# Return Format

Return grouped outputs per AI/model with:
- response content (or summary + path)
- failure details where applicable
- artifact paths (`.responses/*`) for traceability

For mixed outcomes, clearly separate successes from failures.
