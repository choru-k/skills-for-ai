# Claude Skill E2E Harness

Shared runner for Claude CLI skill/extension end-to-end tests.

## Files

- `claude-skill-harness.py` - core harness (`run` / `case`)
- `test-claude-skills.sh` - run one case, one skill, or one directory of cases
- `test-claude-skill-harness.sh` - self-tests with stub Claude CLI
- `cases/` - shared example cases

## Usage

Run all colocated tests for one skill:

```bash
cd /Users/cheol/Desktop/choru/skills-for-ai
bash scripts/claude-skill-e2e/test-claude-skills.sh --skill front-compaction-claude
```

Run one explicit case:

```bash
bash scripts/claude-skill-e2e/test-claude-skills.sh --case plugins/front-compaction/skills/front-compaction-claude/tests/claude/front-compaction.e2e.json
```

## Case placement convention

- shared skills: `skills/<skill-name>/tests/claude/*.json`
- plugin skills: `plugins/*/skills/<skill-name>/tests/claude/*.json`

Compatibility wrappers remain at:
- `plugins/call-ai/skills/call-ai/scripts/claude-skill-harness.py`
- `plugins/call-ai/skills/call-ai/scripts/test-claude-skills.sh`
- `plugins/call-ai/skills/call-ai/scripts/test-claude-skill-harness.sh`
