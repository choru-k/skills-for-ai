---
id: parse-request
description: Parse AI selector and prompt source from /call-ai input.
status: active
tags: [node, parsing]
links:
  - [[preflight-check]]
---

# Parse Request

Supported forms:
- `/call-ai "prompt"` -> default pair (codex+gemini thorough)
- `/call-ai :all "prompt"` -> all configured models
- `/call-ai codex|gemini|claude "prompt"` -> single AI

Output:
- target AI set
- prompt text or prompt file path
- expected response count
