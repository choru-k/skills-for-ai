# front-compaction plugin

This plugin contains both Pi and Claude front-compaction implementations.

Naming convention:
- `cc-*` means Claude lifecycle integration (session hooks, `/compact` replay flow).
- `pi-*` means Pi lifecycle integration (extension command + `session_before_compact` handling).

## Layout

- `skills/cc-front-compaction/` - Claude marketplace-facing skill entry
- `claude/skills/cc-front-compaction/SKILL.md` - Claude wrapper source (same behavior)
- `claude/hooks/front-compaction/` - Claude prepare/reinject/validate scripts
- `pi/skills/pi-front-compaction/` - Pi-facing shared skill entry
- `pi/extensions/front-compaction.ts` - Pi extension command implementation (`/pi-front-compaction`, aliases: `/front-compaction`, `/front-compaction-pi`)
- `pi/extensions/front-compaction-core.ts` - pure helper logic for Pi extension
- `pi/tests/` - Pi extension helper tests

Shared index note:
- `skills/pi-front-compaction` at repo root points to `plugins/front-compaction/pi/skills/pi-front-compaction` for Pi shared-skill loading.

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
bash scripts/claude-skill-e2e/test-claude-skills.sh --skill cc-front-compaction
```
