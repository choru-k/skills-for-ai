# front-compaction plugin

This plugin contains both Pi and Claude front-compaction implementations.

## Layout

- `skills/front-compaction-claude/` - Claude marketplace-facing skill entry
- `claude/skills/front-compaction-claude/SKILL.md` - Claude wrapper source (same behavior)
- `claude/hooks/front-compaction/` - Claude prepare/reinject/validate scripts
- `pi/skills/front-compaction-pi/` - Pi-facing shared skill entry
- `pi/extensions/front-compaction.ts` - Pi extension command implementation (`/front-compaction-pi`, alias: `/front-compaction`)
- `pi/extensions/front-compaction-core.ts` - pure helper logic for Pi extension
- `pi/tests/` - Pi extension helper tests

Shared index note:
- `skills/front-compaction-pi` at repo root points to `plugins/front-compaction/pi/skills/front-compaction-pi` for Pi shared-skill loading.

## Tests

Pi helper tests:

```bash
bash plugins/front-compaction/pi/tests/test-front-compaction-pi.sh
```

Claude hook validation:

```bash
bash plugins/front-compaction/claude/hooks/front-compaction/validate-front-compaction.sh
```

Claude E2E:

```bash
bash scripts/claude-skill-e2e/test-claude-skills.sh --skill front-compaction-claude
```
