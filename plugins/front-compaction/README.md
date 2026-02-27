# front-compaction plugin assets

This folder now contains plugin-specific operational assets for front-compaction.
Canonical skill/extension sources are outside this folder:

- Claude skill source: `claude/cc-front-compaction/SKILL.md`
- Pi skill source: `pi/pi-front-compaction/SKILL.md`
- Pi extension source: `pi/extensions/front-compaction.ts`
- Pi extension core helpers: `pi/extensions/front-compaction-core.ts`

Local plugin assets kept here:

- Claude hook scripts: `claude/hooks/front-compaction/`
- Pi helper tests: `pi/tests/`
- Plugin metadata: `.claude-plugin/plugin.json`

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
