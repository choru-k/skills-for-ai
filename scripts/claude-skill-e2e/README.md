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
bash scripts/claude-skill-e2e/test-claude-skills.sh --skill cc-front-compaction
```

Run one explicit case:

```bash
bash scripts/claude-skill-e2e/test-claude-skills.sh --case public/claude/cc-front-compaction/tests/claude/front-compaction.e2e.json
```

## Case placement convention

- public common skills: `public/common/<skill-name>/tests/claude/*.json`
- public Claude-only skills: `public/claude/<skill-name>/tests/claude/*.json`
- private lane (optional): `private/common/<skill-name>/tests/claude/*.json`, `private/claude/<skill-name>/tests/claude/*.json`
