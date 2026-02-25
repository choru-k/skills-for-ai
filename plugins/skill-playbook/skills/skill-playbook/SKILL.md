---
name: skill-playbook
description: Analyze external posts/news/resources, evaluate validity, track lifecycle status, and curate/review best practices for your skills system.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
argument-hint: "[evaluate|adopt|status|review|list] [url|topic|candidate-id|bp-id]"
---

# Skill Playbook

Evaluate external ideas, decide deliberately, and maintain a living best-practice set.

## Goal

Use a repeatable loop:
1. Analyze a resource
2. Explain what it is + validity verdict
3. Let user decide
4. If approved, add as a best practice
5. Track status over time
6. Review practices periodically

## Storage

```text
skill-playbook/
├── SKILL.md
├── graph/
│   ├── index.md
│   ├── mocs/
│   │   ├── workflow.md
│   │   └── standards.md
│   └── nodes/
│       ├── workflow-analyze-validate-decide-adopt.md
│       ├── validation-rubric.md
│       ├── status-lifecycle.md
│       ├── review-best-practices.md
│       ├── candidate-*.md
│       └── bp-*.md
├── templates/
│   ├── candidate-template.md
│   ├── best-practice-template.md
│   └── review-report-template.md
├── reviews/
│   └── YYYY-MM-DD.md
├── scripts/
│   └── graph-qa.sh
└── adoption.md
```

## Hard Rules

1. Do not mark anything as adopted without explicit user approval.
2. Separate **claims** from **evidence**.
3. Always produce a verdict: `valid`, `valid-with-constraints`, `not-valid`, or `unknown`.
4. Every candidate and best-practice note must include `status` in frontmatter.
5. Keep candidate notes even when rejected (institutional memory).
6. Add wikilinks when publishing a best practice.
7. Keep review metadata current for adopted best practices.
8. Run `scripts/graph-qa.sh` after structural graph edits.

## Status Model

Use [[status-lifecycle]] as the source of truth.

## Actions

### `evaluate` (default)

Use this when user provides a URL, post, article, or idea.

1. Load [[workflow-analyze-validate-decide-adopt]], [[validation-rubric]], and [[status-lifecycle]].
2. Analyze the resource and extract key claims.
3. Score validity with the rubric.
4. Create/update candidate note: `graph/nodes/candidate-<slug>.md`.
5. Present concise output:
   - What it is
   - Validity verdict + why
   - Adoption recommendation
6. Ask user decision: adopt now / keep as candidate / reject.
7. Apply status + bookkeeping:
   - adopt now → create `bp-<slug>.md`, set candidate status to `adopted`, update MOC + `adoption.md`
   - keep candidate → status `proposed` or `piloting`
   - reject → status `rejected`

### `adopt`

Use when candidate already exists and user now wants adoption.

1. Read candidate file
2. Convert into best-practice note (`bp-<slug>.md`) from template
3. Set best-practice status to `adopted`
4. Set `last_reviewed` and `review_by` in best-practice frontmatter
5. Update `graph/mocs/standards.md` and `adoption.md`
6. Run `scripts/graph-qa.sh` to validate metadata and links

### `status`

Use to explicitly update lifecycle state for any candidate or best-practice note.

1. Read target note (`candidate-*` or `bp-*`)
2. Ask for new status (if not explicit)
3. Validate transition via [[status-lifecycle]]
4. Update frontmatter fields:
   - `status`
   - `last_status_change`
   - `status_reason` (short)
5. Sync `adoption.md`
6. Run `scripts/graph-qa.sh` if links or graph structure were changed

### `review`

Periodic review of all adopted best practices.

1. Load [[review-best-practices]]
2. Find all `graph/nodes/bp-*.md` with `status: adopted`
3. Review each practice and label outcome:
   - `keep` (still good)
   - `revise` (update needed)
   - `deprecate` (no longer valid)
4. Update each reviewed note:
   - `last_reviewed`
   - `review_by`
   - `status` (if deprecated)
5. Run `scripts/graph-qa.sh`
6. Write a review report: `reviews/YYYY-MM-DD.md` using template
7. Sync `adoption.md`

### `list`

Read `adoption.md` and summarize by:
- status (`proposed`, `piloting`, `adopted`, `rejected`, `deprecated`)
- review state (`due`, `upcoming`, `not-applicable`)

## Output Format for `evaluate`

```markdown
## Resource Summary
- Type: post/news/doc
- Core idea: ...

## Validity Assessment
- Verdict: valid | valid-with-constraints | not-valid | unknown
- Confidence: high | medium | low
- Why: ...

## Recommendation
- Adopt now | Pilot first | Reject for now

## Decision Needed
- Do you want to add this as a best practice?
```

## References

- [[workflow-analyze-validate-decide-adopt]]
- [[validation-rubric]]
- [[status-lifecycle]]
- [[review-best-practices]]
- `scripts/graph-qa.sh`
