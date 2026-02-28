# front-compaction plugin assets

This folder now contains plugin-specific operational assets for front-compaction.
Canonical skill/extension sources are outside this folder:

- Claude skill source: `public/claude/cc-front-compaction/SKILL.md`
- Pi skill source: `public/pi/pi-front-compaction/SKILL.md`
- Pi extension source: `public/pi/extensions/front-compaction.ts`
- Pi extension core helpers: `public/pi/extensions/front-compaction-core.ts`

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

Claude E2E case file:

- `public/claude/cc-front-compaction/tests/claude/front-compaction.e2e.json`
