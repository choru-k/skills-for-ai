# Best Practices

Consolidated guidance for writing effective skills. Consult this reference when editing a skill.

## Description Writing

The `description` field is the primary triggering mechanism — Claude uses it to decide when to apply the skill.

**Formula:** `[Main purpose]. [What it does]. Use for "[trigger1]", "[trigger2]", "[trigger3]", or [contextual examples].`

**Guidelines:**
- Start with an action verb describing the core capability
- Use an action verb or noun phrase (e.g., "Guide for creating skills", "Manage Jira tickets")
- Include specific trigger phrases users would naturally say
- Include file types, domain terms, and contextual signals
- Keep under 1024 characters
- Do not use angle brackets (`<` or `>`)

**Good example:**
```
Manage work Jira tickets and plans in Obsidian vault. Use for "plan work ticket",
"manage ticket", "create ticket plan", or any CENG-XXXX ticket.
```

**Bad example:**
```
A tool for working with tickets.
```

**Why it matters:** Skill descriptions are always in context (unless `disable-model-invocation: true`). Claude matches user requests against these descriptions to decide which skill to invoke. Vague descriptions cause missed triggers or false triggers.

## Prompt Engineering for Skills

### Right Altitude Principle

Write instructions at the altitude Claude needs — not too high-level (vague) and not too low-level (micromanaging what Claude already knows).

- **Too high:** "Make a good commit message" (Claude already knows how)
- **Right altitude:** "Use conventional commits format: `type(scope): description`. Always include scope. Body wraps at 72 chars."
- **Too low:** "A commit message starts with a type keyword followed by an opening parenthesis then a scope name then a closing parenthesis then a colon then a space then..."

### Imperative Language

Always use imperative/infinitive form in skill instructions:
- "Extract the text" not "The text should be extracted"
- "Run the validation script" not "You might want to run the validation script"

### Examples Over Explanations

Input/output pairs are more token-efficient and less ambiguous than prose:

```markdown
## Commit message format

Generate commit messages following these examples:

**Input:** Added user authentication with JWT tokens
**Output:**
feat(auth): implement JWT-based authentication

Add login endpoint and token validation middleware
```

### Structural Organization

- Use numbered steps for sequential processes
- Use decision trees for branching logic
- Use tables for reference data
- Use headers (##, ###) to create scannable structure
- Group related instructions — don't scatter related guidance across the file

### Progressive Context Loading

Don't put everything in SKILL.md. For any content that's only needed in specific scenarios, put it in a reference file and link to it with clear "when to read" guidance:

```markdown
For tracked changes, see [references/redlining.md](references/redlining.md).
```

## Output Patterns

### Template Pattern

Provide templates when output format matters. Match strictness to your needs.

**Strict (API responses, data formats):**
```markdown
## Report structure

ALWAYS use this exact template:

# [Analysis Title]
## Executive summary
[One-paragraph overview]
## Key findings
- Finding 1 with data
- Finding 2 with data
## Recommendations
1. Actionable recommendation
2. Actionable recommendation
```

**Flexible (when adaptation is useful):**
```markdown
## Report structure

Sensible default format — adjust sections as needed:

# [Analysis Title]
## Executive summary
[Overview]
## Key findings
[Adapt based on what you discover]
## Recommendations
[Tailor to context]
```

### Examples Pattern

For output quality that depends on seeing examples, provide input/output pairs:

```markdown
## Commit message format

**Example 1:**
Input: Added user authentication with JWT tokens
Output:
feat(auth): implement JWT-based authentication

Add login endpoint and token validation middleware

**Example 2:**
Input: Fixed bug where dates displayed incorrectly
Output:
fix(reports): correct date formatting in timezone conversion

Use UTC timestamps consistently across report generation
```

Examples help Claude understand desired style and detail more clearly than descriptions alone.

## Anti-Patterns

**Avoid these common mistakes:**

| Anti-Pattern | Why It's Bad | Fix |
|---|---|---|
| "When to Use" section in the body | Body loads after triggering — too late | Move trigger info to `description` |
| Explaining what Claude already knows | Wastes context tokens | Only add non-obvious knowledge |
| Deeply nested reference files | Claude may not discover them | Keep references one level deep |
| Duplicating info across SKILL.md and references | Wastes tokens, risks inconsistency | Single source of truth |
| Overly verbose TODO blocks | Template bloat | Concise placeholders |
| Adding README, CHANGELOG, etc. | Clutter — skills are for AI, not humans | Only SKILL.md + resources |
| Using `context: fork` for guidelines-only skills | Subagent gets guidelines but no task | Only fork skills with explicit tasks |
| Vague description without trigger phrases | Missed or false triggers | Include specific trigger phrases |

## Testing & Iteration

### Two Claudes Method

1. **Claude A** (skill creator): Writes/edits the skill
2. **Claude B** (fresh session): Tests the skill with realistic requests

This reveals blind spots: Claude B doesn't share Claude A's context about the skill's intent.

### Observation Checklist

After each test invocation, check:

- [ ] Did the skill trigger on the right keywords?
- [ ] Did Claude use the bundled scripts/references appropriately?
- [ ] Was the output format correct?
- [ ] Did Claude ask unnecessary questions (over-specified) or miss steps (under-specified)?
- [ ] Was context usage efficient (no redundant file reads)?

### Evaluation-Driven Development

For critical skills, create test cases before writing the skill:

```
Test: "Rotate this PDF 90 degrees"
Expected: Runs rotate_pdf.py with --angle 90, produces rotated file

Test: "Merge these three PDFs"
Expected: Runs merge script in order, produces single output file
```

Write the skill to pass these test cases, then iterate.

## Quality Checklist

Before considering a skill done:

- [ ] `description` includes trigger phrases and "when to use" guidance
- [ ] SKILL.md body is under 500 lines
- [ ] No duplicate information between SKILL.md and reference files
- [ ] All reference files are linked from SKILL.md with "when to read" context
- [ ] Scripts are tested and executable
- [ ] No extraneous files (README, CHANGELOG, etc.)
- [ ] Frontmatter fields use only supported properties
- [ ] Imperative language throughout
- [ ] Examples preferred over lengthy explanations
- [ ] Passes `quick_validate.py`
