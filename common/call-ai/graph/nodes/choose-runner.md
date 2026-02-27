---
id: choose-runner
description: Choose the best available runner based on environment and installed scripts.
status: active
tags: [node, execution]
links:
  - [[run-single-request]]
  - [[run-parallel-requests]]
---

# Choose Runner

Use `ask-ai-runner.sh` as the canonical runner selector.

Priority order:
- If `$ZELLIJ` is set: use `ask-ai-zellij.sh`
- If `$TMUX` is set and `ask-ai-tmux.sh` exists: use `ask-ai-tmux.sh` (currently delegates to headless `ask-ai.sh`)
- If Ghostty is detected (`$TERM_PROGRAM=ghostty` or `$GHOSTTY_RESOURCES_DIR`): use `ask-ai-ghostty.sh` (currently delegates to headless `ask-ai.sh`)
- Otherwise: use `ask-ai.sh`

Execution mode:
- one model -> single call path
- multiple models -> parallel path via `scripts/run-parallel.sh`
