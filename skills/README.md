# Shared Skills Index

This directory is the shared cross-harness skill index.

Current setup:
- Shared skill sources live in this repository.
- Some entries are symlinks to plugin-owned skill folders (for example `plugins/*/skills/*` or `plugins/*/pi/skills/*`).
- Remaining entries are regular skill directories under `skills/*`.
- Plugin-backed symlinks are generated from `package.json#pi.skills` using `python3 scripts/sync-skills-index.py` (or `just skills-index-sync`).

Notable shared skills:
- `skill-playbook` — evaluate external resources, manage practice status, and run periodic best-practice reviews.
- `skill-commons` — shared reusable contract nodes for cross-skill consistency.
- `subagent-trace-debug` — quickly inspect Pi subagent trace trees, failures, and bottlenecks.

The index is self-contained and does not depend on `~/dotfiles/claude/skills/*`.
