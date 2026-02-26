# Catalog Inventory Audit

## Source Inputs

Inventory coverage was derived from these active references:

1. Claude public plugin registry:
   - `.claude-plugin/marketplace.json`
2. Pi package outputs:
   - `package.json#pi.skills`
   - `package.json#pi.extensions`
3. Runtime extension reference check:
   - `/Users/cheol/dotfiles/pi/settings.json` (`extensions` includes `front-compaction.ts`)

## Coverage Results

- Catalog file: `catalog/skills.yaml`
- Total entries: 25
  - skills: 24
  - extensions: 1
- Visibility split:
  - public: 21
  - private: 4
- Target split:
  - claude: 5
  - pi: 2
  - common: 18

Coverage notes:
- All marketplace plugins have corresponding catalog skill entries under their plugin source roots.
- All current `package.json#pi.skills` and `package.json#pi.extensions` paths are represented in catalog entries.
- Pi runtime extension reference (`front-compaction.ts`) aligns with catalog extension entry `front-compaction-extension`.

## Private Classification Assertions

The following are intentionally classified as `visibility: private` in `catalog/skills.yaml`:

- `choru-ticket`
- `work-lessons`
- `work-ticket`
- `work-workspace`

These private classifications reflect the architecture decision that private skills must not be emitted in public distribution artifacts.

## Known Gaps and Follow-ups

1. **Public manifest cleanup status (resolved):**
   - `package.json#pi.skills` no longer includes private entries (`choru-ticket`, `work-*`).
   - CI/local private-leak checks enforce this going forward.

2. **Claude runtime local extras not in this repo:**
   - `dotfiles/claude/skills/installed/*` contains separately managed skills.
   - Those are out of scope for `skills-for-ai` catalog migration.

3. **Legacy/duplicate source paths in front-compaction plugin:**
   - Claude wrapper exists in multiple plugin subpaths; catalog currently points to the lifecycle source of truth path.

## Verification Commands

```bash
jq '.plugins | length' .claude-plugin/marketplace.json
jq '.pi.skills | length' package.json
jq '.pi.extensions | length' package.json
rg -n '^  - id:' catalog/skills.yaml | wc -l
rg -n 'visibility: private' catalog/skills.yaml
rg -n 'choru-ticket|work-lessons|work-ticket|work-workspace' catalog/skills.yaml
```
