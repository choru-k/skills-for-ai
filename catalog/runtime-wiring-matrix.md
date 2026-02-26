# Runtime Wiring Matrix (Phase 3)

## Inputs

- `~/dotfiles/symlink.sh`
- `~/dotfiles/claude/settings.json`
- `~/dotfiles/pi/settings.json`
- `~/dotfiles/share-ai/README.md`
- `~/dotfiles/claude/skills/README.md`
- `~/dotfiles/pi/README.md`
- `catalog/private-boundary-decision.md`
- `catalog/private-skill-placement.md`
- `catalog/migration-map.md`

## Current-State Baseline

### Claude Runtime Baseline

| Subject | Current wiring | Evidence source | Notes |
|---------|----------------|-----------------|-------|
| Claude root | `~/.claude -> ~/dotfiles/claude` | `symlink.sh` + `ls -ld ~/.claude` | Runtime reads dotfiles-managed Claude config directly. |
| Claude skill discovery root | `~/.claude/skills -> ~/dotfiles/claude/skills` | `ls -ld ~/.claude ~/.claude/skills` | Flat symlink discovery model is active. |
| Shared public skill lane | public/common skills resolve via `../../share-ai/skills/*` | `ls -la ~/dotfiles/claude/skills` | Public/common lane remains sourced from `skills-for-ai` shared index. |
| Shared private-skill bridge lane | private/common skills (`choru-ticket`, `work-*`) resolve via `../../share-ai/private-skills/*` | `readlink ~/dotfiles/claude/skills/work-ticket` + `ls -la ~/dotfiles/share-ai/private-skills` | Bridge links currently point to `../skills/*` for compatibility and can be repointed to private repo lane during cutover. |
| Claude lifecycle wrapper (`cc-*`) | `~/.claude/skills/cc-front-compaction -> ~/Desktop/choru/skills-for-ai/plugins/front-compaction/skills/cc-front-compaction` | `ls -la ~/dotfiles/claude/skills` | `cc-*` wrapper path remains plugin-direct. |
| Claude runtime permissions | `Skill(cc-front-compaction)`, `Skill(work-ticket)`, `Skill(work-lessons)` in allowlist | `claude/settings.json` | Canonical `cc-*` wrapper naming is preserved; no stale `front-compaction-claude` entry. |

### Pi Runtime Baseline

| Subject | Current wiring | Evidence source | Notes |
|---------|----------------|-----------------|-------|
| Pi settings root | `~/.pi/agent/settings.json -> ~/dotfiles/pi/settings.json` | `symlink.sh` + `ls -ld ~/.pi/agent/settings.json` | Pi runtime config is dotfiles-managed. |
| Pi skills lanes | `"skills": ["~/.share-ai/private-skills", "~/.share-ai/skills", "!README.md"]` | `pi/settings.json` | Private bridge lane is explicit and listed before shared public lane. |
| Pi front-compaction extension path | `~/dotfiles/pi/extensions/front-compaction.ts -> ~/Desktop/choru/skills-for-ai/plugins/front-compaction/pi/extensions/front-compaction.ts` | `pi/settings.json` + `ls -l ~/dotfiles/pi/extensions/front-compaction.ts` | Extension implementation remains plugin-direct via dotfiles symlink. |
| Pi lifecycle command naming | canonical `/pi-front-compaction`, aliases `/front-compaction`, `/front-compaction-pi` | `plugins/front-compaction/pi/extensions/front-compaction.ts` | Alias continuity remains extension-owned compatibility contract. |

## Baseline Evidence

Path and wiring checks used for this baseline:

```bash
ls -ld ~/.claude ~/.share-ai ~/.agents/skills ~/.pi/agent/settings.json
ls -la ~/dotfiles/claude/skills
ls -la ~/dotfiles/share-ai/private-skills
ls -l ~/dotfiles/pi/extensions/front-compaction.ts
rg -n "Skill\(cc-front-compaction\)|Skill\(work-ticket\)|Skill\(work-lessons\)" ~/dotfiles/claude/settings.json
rg -n '"skills"|"extensions"|front-compaction\.ts' ~/dotfiles/pi/settings.json
```

## Implemented Runtime State (Post Item-2/Item-3)

| Area | Implemented state | Validation |
|------|-------------------|------------|
| Claude private/common links | `claude/skills/{choru-ticket,work-*}` and `claude/skills/choru/{choru-ticket,work-*}` now point to `share-ai/private-skills/*` | `readlink` checks for each private skill link |
| Claude canonical wrapper naming | `cc-front-compaction` remains canonical wrapper path and settings allowlist entry | `readlink claude/skills/cc-front-compaction` + settings `rg` |
| Pi lane split | `pi/settings.json` includes `~/.share-ai/private-skills` before `~/.share-ai/skills` | JSON assertion script |
| Pi alias continuity | `/pi-front-compaction` plus `/front-compaction`, `/front-compaction-pi` remain registered | `rg` against extension command registration |

## Target-State Matrix

| Lane | Target wiring | Source of truth | Contract |
|------|---------------|-----------------|----------|
| Claude lifecycle wrappers (`cc-*`) | direct links at `~/.claude/skills/cc-*` to plugin wrapper paths | public repo plugin roots | wrapper naming remains Claude-specific and explicit. |
| Claude shared public/common lane | `~/.claude/skills/<public-common>` resolves via `../../share-ai/skills/<id>` | `~/.share-ai/skills` public index | public/common skills stay in shared public lane. |
| Claude private/common lane | `~/.claude/skills/{choru-ticket,work-*}` resolves via `../../share-ai/private-skills/<id>` | private-lane bridge links | bridge path stays stable while private source-of-truth migrates. |
| Pi lifecycle wrappers (`pi-*`) | `pi-front-compaction` skill remains in shared public lane | public repo plugin path via shared index | Pi-facing naming remains canonical `pi-*`. |
| Pi private/common lane | Pi loads `~/.share-ai/private-skills` in addition to shared public lane | `pi/settings.json` + bridge links | private IDs resolve through explicit private bridge lane. |
| Pi front-compaction extension | `~/dotfiles/pi/extensions/front-compaction.ts` remains symlink to plugin extension source | public repo plugin extension path | compatibility aliases remain extension-owned contract. |

## Compatibility Alias Inventory

| Runtime | Canonical name | Compatibility aliases | Status |
|---------|----------------|-----------------------|--------|
| Claude | `cc-front-compaction` | none required | canonical only; stale `front-compaction-claude` root naming remains disallowed. |
| Pi | `/pi-front-compaction` | `/front-compaction`, `/front-compaction-pi` | keep aliases until explicit deprecation decision. |

## Required Deltas by File

### symlink.sh

Applied in Phase 3:
1. Added maintenance of `share-ai/private-skills/{choru-ticket,work-*}` bridge links.
2. Rewired Claude private/common skill links to resolve through private bridge lane.
3. Kept `cc-*` plugin-direct links unchanged.

Remaining cutover delta:
- Repoint bridge links from `../skills/*` to private repository checkout paths when private lane source-of-truth migration is executed.

### claude/settings.json

Applied in Phase 3:
1. Structural change not required.
2. Preserved canonical allowlist entries (`Skill(cc-front-compaction)`, `Skill(work-ticket)`, `Skill(work-lessons)`).
3. Confirmed stale `front-compaction-claude` naming is absent.

### pi/settings.json

Applied in Phase 3:
1. Added `~/.share-ai/private-skills` ahead of `~/.share-ai/skills`.
2. Kept extension path entry for `~/dotfiles/pi/extensions/front-compaction.ts` unchanged.
3. Kept alias behavior extension-owned (no settings-level alias rewrite).

## Verification Commands

```bash
# root wiring
ls -ld ~/.claude ~/.share-ai ~/.pi/agent/settings.json ~/.agents/skills

# claude links
for s in choru-ticket work-lessons work-ticket work-workspace; do
  test "$(readlink ~/dotfiles/claude/skills/$s)" = "../../share-ai/private-skills/$s"
  test "$(readlink ~/dotfiles/claude/skills/choru/$s)" = "../../../share-ai/private-skills/$s"
  test "$(readlink ~/dotfiles/share-ai/private-skills/$s)" = "../skills/$s"
done
readlink ~/dotfiles/claude/skills/cc-front-compaction
rg -n "Skill\(cc-front-compaction\)" ~/dotfiles/claude/settings.json
! rg -n "front-compaction-claude" ~/dotfiles/claude/settings.json

# pi settings + extension linkage
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
ls -l ~/dotfiles/pi/extensions/front-compaction.ts
rg -n 'registerFrontCompactionCommand\(|"pi-front-compaction"|"front-compaction"|"front-compaction-pi"' /Users/cheol/Desktop/choru/skills-for-ai/plugins/front-compaction/pi/extensions/front-compaction.ts
```

## Phase 3 Runtime Pass/Fail Gates

## Pass
All of the following must be true:
1. Claude private/common links resolve via `share-ai/private-skills/*` bridge targets.
2. `cc-front-compaction` remains canonical and stale Claude wrapper naming is absent.
3. Pi settings include both private and shared lanes in expected order.
4. Pi extension still registers `/pi-front-compaction` and both compatibility aliases.

## Fail
Any of the following is a fail-stop trigger:
1. Any private/common Claude link resolves directly to `../../share-ai/skills/*` instead of `../../share-ai/private-skills/*`.
2. `front-compaction-claude` naming reappears in Claude runtime references.
3. `~/.share-ai/private-skills` is missing from Pi settings or ordered after shared public lane.
4. Pi extension no longer registers one or more expected alias commands.
