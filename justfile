set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
    @just --list

# Install this repository as a local Pi package.
pi-install-local:
    pi install .

# Preview npm package contents and metadata before publish.
pi-pack-dry-run:
    npm pack --dry-run

# Sync skills/ symlink index from package.json#pi.skills.
skills-index-sync:
    python3 scripts/sync-skills-index.py

# Check that skills/ symlink index matches package.json#pi.skills.
skills-index-check:
    python3 scripts/sync-skills-index.py --check
