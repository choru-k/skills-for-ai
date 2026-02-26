# Migration Verification Checklist

## Preflight Checks

1. Confirm working tree is clean or intentionally staged for migration.
2. Confirm required contract docs are present:
   - `catalog/migration-map.md`
   - `catalog/migration-stages.md`
   - `catalog/private-skill-placement.md`
3. Capture baseline snapshots of public outputs for comparison.
4. Confirm private lane checkout is available for private skills.

## Postflight Checks

1. Re-run public output validation checks.
2. Confirm private skills resolve through private lane local wiring.
3. Confirm no unexpected drift in generated index/manifests.
4. Record pass/fail result and any deviations.

## Manifest Checks

```bash
# public plugin registry should have no private IDs
rg -n "choru-ticket|work-lessons|work-ticket|work-workspace" .claude-plugin/marketplace.json

# pi package public outputs should have no private IDs
rg -n "choru-ticket|work-lessons|work-ticket|work-workspace" package.json

# package JSON parse sanity
jq '.pi.skills | length' package.json
jq '.pi.extensions | length' package.json
```

Expected:
- no matches for private IDs in public manifests
- package JSON parses cleanly

## Index Checks

```bash
# generated index should be in sync
python3 scripts/sync-skills-index.py --check

# public index should not contain private skill names post-cutover
rg -n "choru-ticket|work-lessons|work-ticket|work-workspace" skills
```

Expected:
- sync check passes
- no private skill entries in public repo `skills/` after cutover

## Runtime Reference Checks

```bash
# verify Pi lane split + extension path
python3 - <<'PY'
import json
from pathlib import Path
p = Path('/Users/cheol/dotfiles/pi/settings.json')
data = json.loads(p.read_text())
skills = data.get('skills', [])
assert '~/.share-ai/private-skills' in skills
assert '~/.share-ai/skills' in skills
assert skills.index('~/.share-ai/private-skills') < skills.index('~/.share-ai/skills')
print('ok')
PY
rg -n "front-compaction\.ts" /Users/cheol/dotfiles/pi/settings.json

# verify Claude canonical wrapper naming remains stable
rg -n "Skill\(cc-front-compaction\)" /Users/cheol/dotfiles/claude/settings.json
! rg -n "front-compaction-claude" /Users/cheol/dotfiles/claude/settings.json

# verify private bridge links for Claude/runtime lane
for s in choru-ticket work-lessons work-ticket work-workspace; do
  test "$(readlink /Users/cheol/dotfiles/claude/skills/$s)" = "../../share-ai/private-skills/$s"
  test "$(readlink /Users/cheol/dotfiles/claude/skills/choru/$s)" = "../../../share-ai/private-skills/$s"
  test "$(readlink /Users/cheol/dotfiles/share-ai/private-skills/$s)" = "../skills/$s"
done

# verify canonical Pi command + compatibility alias registrations remain
rg -n 'registerFrontCompactionCommand\(|"pi-front-compaction"|"front-compaction"|"front-compaction-pi"' plugins/front-compaction/pi/extensions/front-compaction.ts

# verify private IDs remain private in catalog
rg -n "id: (choru-ticket|work-lessons|work-ticket|work-workspace)|visibility: private" catalog/skills.yaml
```

Expected:
- runtime references are present and intentional
- private-lane bridge links resolve as documented
- canonical `cc-front-compaction` and `pi-front-compaction` naming is preserved
- private IDs are still marked `visibility: private`

## Cutover Pass/Fail Gates

## Pass
All of the following must be true:
1. Manifest checks show no private IDs in public outputs.
2. Index checks pass and show no private entries in public index.
3. Runtime reference checks confirm private-lane bridge links + canonical wrapper naming.
4. No unresolved errors in migration logs.

## Fail
Any of the following is a fail-stop trigger:
1. Private ID appears in any public output.
2. `scripts/sync-skills-index.py --check` fails unexpectedly.
3. Runtime cannot resolve required private skills through `private-skills` bridge or canonical wrappers drift.
4. Output drift cannot be explained by intended migration changes.
