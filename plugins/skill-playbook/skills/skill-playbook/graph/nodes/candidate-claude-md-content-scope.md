---
id: candidate-claude-md-content-scope
description: Candidate evaluation of guidance for what belongs in CLAUDE.md vs what should be excluded.
status: proposed
last_status_change: 2026-02-23
status_reason: kept as proposed pending later review
source: https://x.com/morganlinton/status/2025259512148693409?s=46
verdict: valid
confidence: medium
next_review: 2026-03-23
tags: [candidate, claude-md, project-memory, documentation]
links:
  - [[workflow-analyze-validate-decide-adopt]]
  - [[validation-rubric]]
  - [[status-lifecycle]]
---

# Candidate: CLAUDE.md Content Scope (Signal over Noise)

## What it is

A practical guide on using `CLAUDE.md` as high-signal project memory for agent onboarding: include only context the model cannot infer from code, and exclude generic advice, redundant prose, secrets, and stale guidance.

## Key claims

1. `CLAUDE.md` should store project-specific operational context (commands, conventions, footguns, boundaries), not generic engineering principles.
2. Redundant or overly broad content degrades usefulness by adding instruction noise.
3. Stale instructions are actively harmful and should be pruned.
4. Teams should align on shared `CLAUDE.md` conventions rather than copy-pasting “perfect file” templates.

## Evidence observed

- Structured include/exclude checklist with concrete examples.
- Consistent with known prompt/context engineering principle: relevance and specificity outperform generic verbosity.
- No controlled benchmark or quantitative before/after measurements in the post.

## Rubric scoring (1-5)

- Problem Fit: **5** (directly addresses common CLAUDE.md misuse and prompt-noise issues)
- Evidence Strength: **3** (strong practitioner reasoning, limited empirical data)
- Compatibility: **5** (highly compatible with current repo and agent-memory workflows)
- Operational Cost: **4** (low implementation cost, moderate ongoing maintenance)
- Reversibility: **5** (fully reversible via normal markdown edits/version control)

## Validity Assessment

- **Verdict**: `valid`
- **Confidence**: `medium`
- **Why**: The guidance aligns well with practical agent onboarding needs and existing conventions. Risk is low and adoption is straightforward, provided the file is actively maintained.

## Risks / constraints

- Advice is intentionally high-level; teams still need local conventions and examples.
- Without ownership, “keep it concise” can drift into under-documentation.
- Requires periodic cleanup to prevent stale instructions.

## Recommendation

Adopt now, with one constraint: assign explicit ownership/review cadence so `CLAUDE.md` remains current.

## Decision

- 2026-02-23: user chose **keep candidate**.
- Status remains `proposed`; revisit for adoption after further review.
