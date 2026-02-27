# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## Project Overview

A collection of AI-agent skills with dual distribution metadata:
- Claude marketplace metadata: `.claude-plugin/marketplace.json`
- Pi package metadata: `package.json#pi`

Canonical source-of-truth layout is human-first:
- `common/`
- `claude/`
- `pi/`

Legacy compatibility bridge paths (`skills/*`, `plugins/*/skills/*`, `plugins/*/pi/skills/*`, `plugins/*/pi/extensions/*`) are retired and guarded.

## Repository Structure

```text
common/
  <skill-id>/
    SKILL.md
claude/
  <skill-id>/
    SKILL.md
pi/
  <skill-id>/
    SKILL.md
  extensions/
    *.ts
plugins/
  <plugin-name>/
    .claude-plugin/plugin.json   # plugin metadata only (name/description/version)
    ...                          # plugin-specific non-skill assets (if any)
catalog/
.claude-plugin/marketplace.json
package.json
scripts/
```

## Key Files

- `catalog/skills.yaml`: canonical inventory (`id`, `kind`, `visibility`, `target`, `path`)
- `scripts/sync-catalog-artifacts.py`: sync/check for `package.json#pi` and `.claude-plugin/marketplace.json`
- `scripts/check-legacy-bridges.sh`: fail if retired legacy bridge paths reappear
- `scripts/check-public-output-drift.sh`: drift + legacy guardrail wrapper
- `scripts/check-private-leaks.sh`: private leak guardrail
- `common/call-ai/ai-registry.yaml`: model/provider registry for `call-ai`

## Adding or Updating Skills

1. Add/update canonical skill sources only:
   - `common/<id>/SKILL.md` (shared)
   - `claude/<id>/SKILL.md` (Claude-only)
   - `pi/<id>/SKILL.md` (Pi-only)
2. Add/update catalog entry in `catalog/skills.yaml`.
3. Run:
   - `just catalog-sync`
   - `just drift-check`
   - `just private-leak-check`
   - `just contract-scenario-check`

## Adding Pi Extensions

1. Add/update `pi/extensions/<name>.ts`.
2. Add/update extension entry in `catalog/skills.yaml` (`kind: extension`, `target: pi`).
3. Run catalog sync/check commands above.

## Guardrail Command Flow

```bash
just catalog-check
just legacy-bridge-check
just drift-check
just private-leak-check
bash common/skill-playbook/scripts/graph-qa.sh
just contract-scenario-check
just pi-pack-dry-run
```

## Installation Methods

- Claude marketplace: `claude plugin marketplace add choru-k/skills-for-ai && claude plugin install <name>`
- Claude manual: copy from canonical roots (`common/` / `claude/`) into `~/.claude/skills/`
- Pi package: `pi install git:github.com/choru-k/skills-for-ai` (or npm package after publish)
