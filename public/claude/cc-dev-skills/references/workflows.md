# Workflow Patterns

## Sequential Workflows

For complex tasks, break operations into clear steps. Give Claude an overview towards the beginning of SKILL.md:

```markdown
Filling a PDF form involves these steps:

1. Analyze the form (run analyze_form.py)
2. Create field mapping (edit fields.json)
3. Validate mapping (run validate_fields.py)
4. Fill the form (run fill_form.py)
5. Verify output (run verify_output.py)
```

## Conditional Workflows

For tasks with branching logic, guide Claude through decision points:

```markdown
1. Determine the modification type:
   **Creating new content?** → Follow "Creation workflow" below
   **Editing existing content?** → Follow "Editing workflow" below

2. Creation workflow: [steps]
3. Editing workflow: [steps]
```

## Router/Dispatcher Pattern

For skills that delegate to sub-skills based on input analysis:

```markdown
## Routing

1. Analyze the request to determine scope:
   - **Small** (1-5 files, single concern) → Invoke `/task-small`
   - **Medium** (multi-phase, 6-15 files) → Invoke `/task-medium`
   - **Big** (new architecture, 15+ files) → Invoke `/task-big`

2. Heuristics:
   - Single function/component change → Small
   - Multiple related changes across modules → Medium
   - New service, app, or major refactor → Big
   - When uncertain, prefer one size smaller

3. Pass along all context from the user's request to the sub-skill.
```

Key elements: decision criteria, heuristics for edge cases, default behavior when ambiguous, context forwarding instructions.

## Lifecycle Management Pattern

For skills that manage persistent artifacts (tickets, tasks, documents) through states:

```markdown
## Workflow

1. **Determine target**: Extract identifier from context (branch name, user input, etc.)
   - Try to extract automatically before asking the user

2. **Check for existing**:
   - Search active directory: `active/<identifier>/`
   - Search archive directory: `archive/<identifier>/`
   - If found in archive → offer to reactivate
   - If found in active → summarize current state

3. **Status management**: Present current state and offer actions:
   - Update progress on existing plan
   - Reset and re-plan from scratch
   - Archive/close the item
   - Continue where left off

4. **Execute or delegate**: Based on chosen action, either:
   - Directly modify files
   - Invoke a sub-skill (e.g., `/planner`) with full context
```

Key elements: automatic extraction before asking, two-stage lookup (active + archive), state presentation with action choices, delegation with context.

## Checklist Pattern

For multi-step processes where progress tracking matters:

```markdown
## Implementation checklist

Track progress through each phase:

### Phase 1: Setup
- [ ] Create project structure
- [ ] Install dependencies
- [ ] Configure environment

### Phase 2: Implementation
- [ ] Implement core logic
- [ ] Add error handling
- [ ] Write tests

### Phase 3: Verification
- [ ] All tests passing
- [ ] Manual smoke test
- [ ] Documentation updated

Update checkboxes as each item completes. If blocked on an item, note the blocker and continue with unblocked items.
```

Key elements: grouped phases, checkbox tracking, explicit handling of blockers, permission to work out of order when blocked.
