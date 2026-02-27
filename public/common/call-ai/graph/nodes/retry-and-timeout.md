---
id: retry-and-timeout
description: Reliability policy for retries, backoff, and wall-clock timeout safety net.
status: active
tags: [node, reliability]
links:
  - [[handle-failures]]
---

# Retry and Timeout

Behavior is script-defined and should be preserved:
- internal retries with backoff/jitter in `ask-ai*.sh`
- process liveness monitoring in `run-parallel.sh`
- wall-clock kill safety net (`AI_MAX_TIMEOUT`)

Do not duplicate retry logic in skill instructions; rely on scripts.
