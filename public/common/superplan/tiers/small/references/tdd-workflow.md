# TDD 5-Step Workflow Reference

This is the canonical task file format for `/superplan small`. Every task file must follow this structure.

## Task File Template

```markdown
# Task <N>: <Task Name>

## Overview
<1-2 sentences describing what this task accomplishes and why>

## Scope
- **Files:** `path/to/file1.ext`, `path/to/file2.ext`
- **Effort:** ~<X>m
- **Depends on:** <task reference or "none">
- **Blocks:** <task reference or "none">

## Step 1: Write Test

**File:** `path/to/test_file.ext`

```<lang>
<complete test code — no placeholders>
```

**What this tests:** <1 sentence explaining what the test verifies>

## Step 2: Verify Test Fails

```bash
<exact command to run the test>
```

**Expected output pattern:**
```
<what failure looks like — e.g., "FAILED: expected X but got Y" or "ModuleNotFoundError">
```

If the test passes at this point, the feature already exists — skip to Step 5.

## Step 3: Implement

### 3a. <First change>

**File:** `path/to/file.ext`

<Description of what to change and why>

```<lang>
<code snippet — complete enough to implement without guessing>
```

### 3b. <Second change> (if needed)

**File:** `path/to/other_file.ext`

<Description and code>

## Step 4: Verify Test Passes

```bash
<exact same command from Step 2>
```

**Expected output:**
```
<what success looks like — e.g., "All tests passed" or "OK (1 test)">
```

**Additional verification (if applicable):**
```bash
<any manual check, lint, type-check command>
```

## Step 5: Commit

```bash
git add path/to/file1.ext path/to/file2.ext path/to/test_file.ext
git commit -m "type(scope): description"
```

## Error Protocol

If any step fails:

1. **Strike 1:** Read the error message carefully. Fix the most likely cause. Re-run.
2. **Strike 2:** Re-read this task file and main.md. Try an alternative approach. Re-run.
3. **Strike 3:** STOP. Log the error in main.md's Log section. Do not proceed.

**Context safety:**
- Save progress every 2 major operations
- Re-read plan files before major decisions
- Never repeat the exact same failed approach

## Exit Criteria

- [ ] Test from Step 1 passes
- [ ] No regressions (existing tests still pass)
- [ ] Changes committed with conventional commit message
- [ ] <any task-specific criteria>
```

## When Automated Tests Don't Apply

For tasks involving config files, documentation, or other non-testable changes, replace Steps 1-2 and Step 4 with manual verification:

```markdown
## Step 1: Define Verification

**Verification command:**
```bash
<command that produces observable output>
```

**Expected output:** <what correct output looks like>

## Step 2: Verify Current State

Run the verification command above and confirm the current output does NOT match the expected output (i.e., the change hasn't been made yet).

## Step 3: Implement
<same as above>

## Step 4: Verify Change

Run the verification command from Step 1.

**Expected output:**
```
<exact expected output after implementation>
```
```

## Commit Message Convention

Use conventional commits:

| Type | When |
|------|------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Code restructuring without behavior change |
| `test` | Adding or updating tests only |
| `docs` | Documentation only |
| `chore` | Build, config, tooling changes |
| `style` | Formatting, whitespace, no logic change |

Format: `type(scope): brief description`

Examples:
- `feat(auth): add JWT token refresh endpoint`
- `fix(api): handle null response in user lookup`
- `chore(ci): add test coverage reporting`

## Effort Estimation Guide

| Effort | Typical Tasks |
|--------|---------------|
| ~15m | Single function change, config tweak, typo fix |
| ~30m | New function + test, small refactor, add endpoint |
| ~1h | New module/class, multi-file feature, migration |
| ~2h | Complex feature with tests, significant refactor |

If a single task exceeds ~1h, consider splitting it into subtasks.

## Context Safety Rules

These rules prevent wasted work during execution:

1. **2-Action Rule:** After every 2 significant operations (file edits, test runs), save a progress note to main.md's Log section
2. **Plan-first:** Re-read the current task file before starting each step
3. **Error logging:** Append ALL errors to main.md Log with timestamp and what was tried
4. **No repeat failures:** If approach A fails, try approach B. Never retry the exact same approach expecting a different result
5. **Checkpoint on success:** After each task completes, update the Status checklist in main.md before starting the next task

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Start coding without reading the plan | Re-read main.md and current task file first |
| Stuff large outputs into context | Write findings to the Log section |
| Repeat a failed approach | Track attempts, mutate approach (3-strike rule) |
| Skip verification steps | Run every test command, even if "obvious" |
| Create vague task descriptions | Include exact file paths, commands, and code |
| Modify files not listed in Scope | Update scope first, then proceed |
