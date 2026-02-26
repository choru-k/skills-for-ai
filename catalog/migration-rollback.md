# Migration Rollback Runbook

## Trigger Conditions

Start rollback immediately if any of the following occurs:
1. Private IDs appear in public artifacts (`.claude-plugin/marketplace.json`, `package.json`, `skills/`).
2. Local runtime loses access to required private skills during/after cutover.
3. Manifest/index drift is detected and cannot be reconciled quickly.
4. Migration validation gates fail at Stage 2 or Stage 3.

## Rollback Inputs

- Last known-good git commit hash (public repo)
- Baseline snapshots captured during preflight
- Current migration branch state
- Private lane checkout path (for local runtime relink if needed)
- Current runtime bridge state in dotfiles (`share-ai/private-skills`, Claude private link targets, Pi skills lane order)

## Rollback Steps

1. **Freeze migration changes**
   - Stop further writes and notify operator.

2. **Restore public artifacts from known-good commit**

```bash
git restore --source <KNOWN_GOOD_COMMIT> .claude-plugin/marketplace.json package.json
```

3. **Restore generated index state**

```bash
git restore --source <KNOWN_GOOD_COMMIT> skills
python3 scripts/sync-skills-index.py --check
```

4. **Restore catalog/runtime contracts if partially edited**

```bash
git restore --source <KNOWN_GOOD_COMMIT> catalog/migration-map.md catalog/migration-stages.md catalog/runtime-wiring-matrix.md catalog/migration-verification-checklist.md catalog/migration-rollback.md
```

5. **Re-apply runtime bridge continuity links (if broken)**

```bash
cd /Users/cheol/dotfiles
for s in choru-ticket work-lessons work-ticket work-workspace; do
  ln -sfn ../skills/$s share-ai/private-skills/$s
  ln -sfn ../../share-ai/private-skills/$s claude/skills/$s
  ln -sfn ../../../share-ai/private-skills/$s claude/skills/choru/$s
done
```

6. **Restore Pi lane ordering (if drifted)**
   - Ensure `~/.share-ai/private-skills` is still present before `~/.share-ai/skills` in `pi/settings.json`.

7. **Record incident context**
   - Capture failure cause, commands executed, and restored commit references.

## Verification After Rollback

Run:

```bash
python3 scripts/sync-skills-index.py --check
rg -n "choru-ticket|work-lessons|work-ticket|work-workspace" .claude-plugin/marketplace.json package.json
rg -n "id: (choru-ticket|work-lessons|work-ticket|work-workspace)|visibility: private" catalog/skills.yaml
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
rg -n "Skill\(cc-front-compaction\)" /Users/cheol/dotfiles/claude/settings.json
! rg -n "front-compaction-claude" /Users/cheol/dotfiles/claude/settings.json
```

Expected:
- index check passes
- no private IDs in public outputs
- private IDs remain explicitly private in catalog
- runtime bridge lane and canonical wrapper naming are restored

## Recovery Gates

Rollback is considered successful only when all are true:
1. Public artifacts match known-good baseline/commit.
2. Verification checks pass with no private leakage.
3. Local runtime bridge paths (`share-ai/private-skills`, Claude private links, Pi lane ordering) are restored.
4. Canonical wrapper naming (`cc-front-compaction`, `pi-front-compaction`) and alias expectations are intact.
5. Incident log is completed with next-action decision (retry vs defer).

## Incident Log Template

```markdown
- Timestamp:
- Operator:
- Trigger condition:
- Failed stage/gate:
- Known-good commit restored:
- Commands executed:
- Verification results:
- Runtime status (Claude/Pi):
- Next action:
```
