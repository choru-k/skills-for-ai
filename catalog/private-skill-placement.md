# Private Skill Placement Contract

## Scope and Inputs

This contract defines where private skills are stored and how local runtimes consume them after Phase 2 migration.

Inputs:
- `catalog/private-boundary-decision.md`
- `catalog/skills.yaml`
- Current runtime references in dotfiles (`~/.claude/skills`, `~/.share-ai/skills`, Pi settings)

## Placement Matrix

| Skill ID | Current source path | Target private-lane path | visibility | target |
|----------|---------------------|--------------------------|------------|--------|
| `choru-ticket` | `skills/choru-ticket/SKILL.md` | `skills/choru-ticket/SKILL.md` (private repo) | `private` | `common` |
| `work-lessons` | `skills/work-lessons/SKILL.md` | `skills/work-lessons/SKILL.md` (private repo) | `private` | `common` |
| `work-ticket` | `skills/work-ticket/SKILL.md` | `skills/work-ticket/SKILL.md` (private repo) | `private` | `common` |
| `work-workspace` | `skills/work-workspace/SKILL.md` | `skills/work-workspace/SKILL.md` (private repo) | `private` | `common` |

Notes:
- Target path mirrors current relative layout to reduce rewiring complexity.
- Only repository boundary changes; skill IDs and target semantics remain stable.

## Consumption Model

### Claude local runtime
- Private skills are linked from private checkout into local Claude skill search paths (direct symlink or merged local index).
- Public marketplace install flow is not used for private skills.

### Pi local runtime
- Private skills are loaded through local skill index paths in Pi settings (via dotfiles wiring in Phase 3).
- Public `package.json#pi` output must exclude private skill IDs.

### Public distribution outputs
- Private skills must not appear in:
  - `.claude-plugin/marketplace.json`
  - `package.json#pi.skills`
  - `package.json#pi.extensions`

## Private Skill Assertions

The following IDs are mandatory private-lane skills:
- `choru-ticket`
- `work-lessons`
- `work-ticket`
- `work-workspace`

Assertions:
1. `visibility` stays `private` for all four IDs.
2. `target` stays `common` unless explicitly re-approved by architecture review.
3. Public outputs fail validation if any of these IDs appear.

## Migration Preconditions

1. Private repository lane exists and is accessible on local developer machines.
2. Private checkout has mirrored skill paths from the placement matrix.
3. Runtime rewiring plan (Phase 3) is prepared before removing in-repo copies.
4. Rollback instructions (Phase 2 item-4) are ready before cutover.

## Verification Commands

```bash
# private IDs exist and remain private in catalog
rg -n "id: (choru-ticket|work-lessons|work-ticket|work-workspace)|visibility: private" catalog/skills.yaml

# after migration cutover: ensure no private IDs in public outputs
rg -n "choru-ticket|work-lessons|work-ticket|work-workspace" .claude-plugin/marketplace.json package.json

# ensure placement contract remains explicit
rg -n "choru-ticket|work-lessons|work-ticket|work-workspace|private repo|public distribution" catalog/private-skill-placement.md
```
