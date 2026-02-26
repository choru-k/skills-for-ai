---
id: preflight-check
description: Validate prompt quality, CLI availability, and optional file input before execution.
status: active
tags: [node, validation]
links:
  - [[select-models]]
---

# Preflight Check

Confirm:
- prompt is self-contained
- expected output format is clear
- selected model set fits task
- prompt file exists when file mode is used
- required CLIs exist (`codex`, `gemini`, `claude` as needed)

If a required check fails, stop with actionable guidance.
