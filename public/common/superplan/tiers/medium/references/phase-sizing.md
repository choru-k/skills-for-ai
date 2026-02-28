# Phase Sizing Reference (Medium Tier)

Rules for decomposing medium-scope work into clear, executable phases.

## Medium Tier Constraints

A medium plan typically fits:

| Constraint | Target |
|-----------|--------|
| Files modified | ~6-15 |
| Estimated effort | ~2-8 hours |
| Number of phases | 2-6 |

If scope is smaller than this, prefer `/superplan small`.
If architecture decisions dominate, prefer `/superplan big`.

## Phase Design Rules

Each phase should:
1. Deliver a meaningful milestone
2. Have clear dependencies
3. Include explicit verification criteria
4. Stay implementation-aware but not small-tier/TDD-detailed

## When to Split a Phase

### By size
If a phase likely exceeds ~5 files or ~2 hours by itself, split it.

### By dependency
If half the phase cannot begin before the other half, split at that boundary.

### By ownership/concern
If a phase mixes unrelated concerns (e.g., API + infra + UI), split by concern.

## Effort Estimation Guide

| Work Type | Typical Effort |
|-----------|----------------|
| Focused config + behavior update | ~1-2h |
| Multi-module feature slice | ~2-4h |
| Cross-cutting refactor + validation | ~4-8h |

## Checkpoint Guidance

A checkpoint must include:
1. Exact command or manual validation step
2. Expected observable result
3. Stop/reassess instruction if it fails

## Medium Plan `main.md` Template

```markdown
---
type: project
status: active
start-date: YYYY-MM-DD
area:
tier: medium
tags: [project]
---

# <Title>

## Status
- [ ] Phase 1: <name>
- [ ] Phase 2: <name>
- [ ] Phase 3: <name>

## Goal
<1-2 sentences: what we're building and why>

## Scope

**In scope:**
- <specific deliverables>

**Out of scope:**
- <explicit exclusions>

## Approach
<Technical approach in 3-5 sentences. Key decisions and rationale.>

## Phases

### Phase 1: <Name>
- **Milestone:** <what is true when done>
- **Files:** `file1.ext`, `file2.ext`
- **Depends on:** none
- **Effort:** ~<X>h
- **Verification:** <specific command/check>

### Phase 2: <Name>
- **Milestone:** <what is true when done>
- **Files:** `file3.ext`, `file4.ext`
- **Depends on:** Phase 1
- **Effort:** ~<X>h
- **Verification:** <specific command/check>

## Execution Order
1. Phase 1
2. Phase 2
3. Phase 3

## Files to Modify
- `path/to/file1.ext` — <what changes>
- `path/to/file2.ext` — <what changes>

## Related Files
- [[notes]]

## Log
- YYYY-MM-DD: Created medium plan
```
