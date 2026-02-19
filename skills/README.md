# Shared Skills Index

This directory is the shared cross-harness skill index.

Current setup:
- Shared skill sources live in this repository.
- Some entries are symlinks to local plugin skill folders under `plugins/*/skills/*`.
- Remaining entries are regular skill directories under `skills/*`.

Notable shared skills:
- `skill-playbook` — evaluate external resources, manage practice status, and run periodic best-practice reviews.

The index is self-contained and does not depend on `~/dotfiles/claude/skills/*`.
