# Migration Map (Phase 2)

## Inputs

- `catalog/skills.yaml` (current classified inventory)
- `catalog/private-boundary-decision.md` (private lane decision)
- `catalog/private-skill-placement.md` (private placement contract)
- Current public outputs:
  - `.claude-plugin/marketplace.json`
  - `package.json#pi`
  - `skills/` generated index

## Mapping Matrix

| Subject | Current state | Target state | Action | Affects |
|---------|---------------|--------------|--------|---------|
| `choru-ticket` | in public repo at `skills/choru-ticket/SKILL.md` (`private`,`common`) | private repo mirror path `skills/choru-ticket/SKILL.md` | move source-of-truth to private lane | private skill lane + local runtime links |
| `work-lessons` | in public repo at `skills/work-lessons/SKILL.md` (`private`,`common`) | private repo mirror path `skills/work-lessons/SKILL.md` | move source-of-truth to private lane | private skill lane + local runtime links |
| `work-ticket` | in public repo at `skills/work-ticket/SKILL.md` (`private`,`common`) | private repo mirror path `skills/work-ticket/SKILL.md` | move source-of-truth to private lane | private skill lane + local runtime links |
| `work-workspace` | in public repo at `skills/work-workspace/SKILL.md` (`private`,`common`) | private repo mirror path `skills/work-workspace/SKILL.md` | move source-of-truth to private lane | private skill lane + local runtime links |
| `.claude-plugin/marketplace.json` | currently public plugin list | unchanged plugin list, explicit assertion: no private skill IDs/paths | validate no private references | Claude public distribution lane |
| `package.json#pi.skills` | contains public skill paths only (private paths removed in Phase 4) | contains public skill paths only | enforce via guardrail checks | Pi public distribution lane |
| `package.json#pi.extensions` | public extension entries | unchanged unless private extensions are introduced later | validate no private extension paths | Pi public distribution lane |
| `skills/` generated index | contains symlink/dirs including private skills | public index only in public repo; private skills supplied by private lane locally | regenerate and remove stale public-private overlap | runtime discovery + local link hygiene |

## Compatibility Bridges

1. **Bridge A: local runtime continuity during cutover**
   - Keep local symlinks for private skills working while source-of-truth moves to private repo.
   - Remove when Phase 3 runtime wiring is validated.

2. **Bridge B: catalog-first validation before file moves**
   - Keep private entries in `catalog/skills.yaml` as `visibility: private` during transition.
   - Remove transitional notes after migration stages complete.

3. **Bridge C: phased public-output cleanup**
   - Remove private paths from `package.json#pi.skills` only after private lane links are in place.
   - Stop if local runtime checks fail.

## Coverage Summary

- Private skills mapped: 4/4 (`choru-ticket`, `work-lessons`, `work-ticket`, `work-workspace`).
- Public output artifacts mapped: 3/3 (`.claude-plugin/marketplace.json`, `package.json#pi`, `skills/`).
- Mapping intent: deterministic, lane-separated, and compatible with staged cutover.
