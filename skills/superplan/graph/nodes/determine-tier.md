---
id: determine-tier
description: Select big, medium, or small tier using arguments first, then inference.
status: active
tags: [node, tiering]
links:
  - [[resolve-expansion-context]]
---

# Determine Tier

## Priority

1. Use explicit `$ARGUMENTS` (`small|medium|big`).
2. If absent, infer from scope:
   - small: focused change, 1-5 files
   - medium: multi-item phase, 6-15 files
   - big: architecture/system redesign, 15+ files
3. Ask user only when ambiguous.

## Output Contract

Return selected `tier`.
