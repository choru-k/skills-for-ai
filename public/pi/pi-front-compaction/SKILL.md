---
name: pi-front-compaction
description: Manual partial compaction workflow for Pi. Use when user asks to compact only the oldest front portion of the conversation by percentage (for example 30% or 50%).
user-invocable: true
---

# Front Compaction

Use this skill when the user asks for **front-only partial compaction**.

## Scope

- Target: **Pi coding agent**
- Trigger: **manual only**
- Rule: compact the **oldest N%** of complete user+assistant turns
- Default percent: **30%**
- Output: replace that oldest segment with one structured summary block
- Keep newer turns unchanged

## How to Run

Use the extension command directly:

```text
/pi-front-compaction
```

Set percent explicitly:

```text
/pi-front-compaction 30
/pi-front-compaction 50
```

Add optional focus text after percent:

```text
/pi-front-compaction 30 focus on unresolved TODOs and file-level decisions
```

Compatibility aliases:

```text
/front-compaction
/front-compaction-pi
```

If no percent is provided, it defaults to **30**.

## Required Behavior

- Do **not** use `/compact` as a fallback for this skill.
- If true partial in-session compaction cannot be performed, fail clearly with an `Unsupported:` message.
- This workflow is manual-only (no automatic threshold trigger).
