# Private Lane Repository Boundary Decision

## Decision Summary

**Decision:** Use a dedicated private repository lane for private skills, separate from the public `skills-for-ai` repository.

- Public repository (`skills-for-ai`) remains the source for public artifacts and public manifests only.
- Private skills move to a private repository with a mirrored skill structure.
- Private skills are consumed locally via dotfiles/runtime wiring, not via public package/plugin outputs.

## Decision Criteria

1. Prevent accidental private data/skill publication.
2. Keep public release artifacts auditable and minimal.
3. Keep local day-to-day workflows practical for Claude/Pi use.
4. Keep migration complexity manageable with rollback options.
5. Preserve compatibility during transition (`cc-*`, `pi-*`, existing aliases where needed).

## Options Considered

1. **Option A — Single public repo with mixed visibility entries**
   - Keep private + public skills together, rely on metadata filters.
2. **Option B — Separate private repository lane (chosen)**
   - Public repo contains only public-distribution content.
   - Private repo contains private skills and local-only metadata.
3. **Option C — Store private skills directly inside dotfiles only**
   - Skip dedicated private skills repository, keep private skills embedded in dotfiles.

## Chosen Boundary

Adopt **Option B**.

### Public lane (authoritative for public distribution)
- Repository: `skills-for-ai` (public)
- Contains:
  - public skills/extensions
  - public manifest outputs (`.claude-plugin/marketplace.json`, `package.json#pi`)
  - public catalog contracts/docs
- Must not include private skill source files after migration completes.

### Private lane (authoritative for local private skills)
- Repository: private skills repository (name/path decided operationally, private VCS only)
- Contains:
  - `choru-ticket`
  - `work-lessons`
  - `work-ticket`
  - `work-workspace`
- Uses the same metadata model (`id`, `kind`, `visibility`, `target`, `path`) for consistency.

## Rejected Alternatives

### Option A rejected
- High leak risk due to mixed private/public assets in one publishable repository.
- Requires perfect filtering discipline at all times.

### Option C rejected
- Over-couples skill lifecycle to dotfiles internals.
- Harder to reuse/share private skills across machines and workflows.

## Security and Operational Rationale

### Security
- Physical repository separation lowers accidental publish risk compared with policy-only filtering.
- Public CI/publish checks can assert zero references to private skill paths/IDs.

### Operational
- Public release workflows stay simple and deterministic.
- Private lane can evolve independently (access control, backup policy, local-only experimentation).
- Migration can be staged skill-by-skill with compatibility bridges.

## Local Workflow Impact

1. Developers keep using public skills from `skills-for-ai` as today.
2. Private skills (`choru-ticket`, `work-*`) are edited in private repository checkout.
3. Dotfiles wiring (Phase 3) will link private skills into local runtime search paths for Claude/Pi.
4. Public install flows (`claude plugin`, `pi install`) no longer carry private skills once migration is complete.
5. Existing local usage should be preserved via controlled rewiring and rollback checklist before cutover.
