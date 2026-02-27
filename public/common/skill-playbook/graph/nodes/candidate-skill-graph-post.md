---
id: candidate-skill-graph-post
description: Candidate evaluation of "Skill Graphs > SKILL.md" post.
status: adopted
last_status_change: 2026-02-19
status_reason: promoted to best practice
source: https://x.com/arscontexta/status/2023957499183829467?s=46
verdict: valid-with-constraints
confidence: medium
adopted_as: bp-skill-graph-post
tags: [candidate, architecture, skill-graph]
links:
  - [[workflow-analyze-validate-decide-adopt]]
  - [[validation-rubric]]
  - [[status-lifecycle]]
  - [[bp-skill-graph-post]]
---

# Candidate: Skill Graphs > Single SKILL.md

## What it is

A proposal to structure skill knowledge as a graph of small markdown nodes connected by wikilinks, with YAML descriptions for scan-first traversal.

Core claim: one large `SKILL.md` is insufficient for complex domains; a linked graph improves retrieval, composability, and depth.

## Validity Assessment

- **Verdict**: `valid-with-constraints`
- **Confidence**: `medium`

### Why it looks valid

- Matches real scaling pain: large skill files become hard to maintain.
- Supports progressive disclosure (index → MOC → node) and better context loading.
- Fits current repo direction (already split into references/templates in multiple skills).

### Constraints / risks

- Link quality can degrade (link spam, ambiguous jumps).
- Requires metadata discipline (frontmatter must stay current).
- Needs lightweight linting to prevent broken/orphaned nodes.

## Recommendation

Pilot first on high-complexity skills:
1. `second-opinion`
2. `superplan` family
3. `work-ticket`

Keep `SKILL.md` as thin router; move depth into graph nodes.

## Decision

- 2026-02-19: user chose **adopt**.
- Promoted to [[bp-skill-graph-post]].
