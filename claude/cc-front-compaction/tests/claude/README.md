# cc-front-compaction Claude E2E tests

This folder contains Claude CLI E2E cases for the `cc-front-compaction` skill.

Run the skill-specific suite from the shared harness:

```bash
cd /Users/cheol/Desktop/choru/skills-for-ai
bash scripts/claude-skill-e2e/test-claude-skills.sh --skill cc-front-compaction
```

Run a single case:

```bash
bash scripts/claude-skill-e2e/test-claude-skills.sh --case /Users/cheol/Desktop/choru/skills-for-ai/plugins/front-compaction/skills/cc-front-compaction/tests/claude/front-compaction.e2e.json
```
