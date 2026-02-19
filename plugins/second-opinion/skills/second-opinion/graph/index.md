---
id: second-opinion-index
description: Entry point for second-opinion execution via progressive disclosure.
status: active
tags: [index, second-opinion, skill-graph]
links:
  - [[execution]]
  - [[synthesis]]
---

# Second Opinion Skill Graph

Use this index first, then load only the minimum needed nodes.

## Progressive Disclosure Order

1. `index.md` (this file)
2. One MOC (`[[execution]]` or `[[synthesis]]`)
3. Relevant node(s)
4. Deep references only if needed (`reference/*.md`, `examples/*`)

## Route Selection

- Normal `/so` run → [[execution]]
- Synthesis-only question → [[synthesis]]
- Failure handling → `reference/troubleshooting.md`

## Global Invariants

- Always generate context via `/complete-prompt` using Skill tool.
- Always pass `--refs` when external AIs can read the same codebase.
- Do not manually recreate complete-prompt XML.
- Return synthesis + raw response file paths.

## Deep References

- Workflow details: `reference/workflow.md`
- Synthesis rules: `reference/synthesis-guide.md`
- Architecture: `reference/architecture.md`
- Troubleshooting: `reference/troubleshooting.md`
