#!/usr/bin/env bash
# Validate skill graph metadata and wikilinks.
#
# Usage:
#   graph-qa.sh                     # validate all skills with graph/
#   graph-qa.sh --skill superplan   # validate one skill graph
#   graph-qa.sh --skill superplan --skill work-ticket

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="${SKILLS_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

python3 - "$SKILLS_ROOT" "$@" <<'PY'
import re
import sys
from pathlib import Path

try:
    import yaml
except Exception as exc:  # pragma: no cover
    print("✗ graph-qa requires PyYAML (python module 'yaml').", file=sys.stderr)
    print(f"  Import error: {exc}", file=sys.stderr)
    sys.exit(2)

skills_root = Path(sys.argv[1])
args = sys.argv[2:]

skill_filters = []
i = 0
while i < len(args):
    arg = args[i]
    if arg in {"-h", "--help"}:
        print("Usage: graph-qa.sh [--skill <name>]...")
        sys.exit(0)
    if arg == "--skill":
        if i + 1 >= len(args):
            print("✗ --skill requires a value", file=sys.stderr)
            sys.exit(2)
        skill_filters.append(args[i + 1])
        i += 2
        continue
    print(f"✗ Unknown argument: {arg}", file=sys.stderr)
    sys.exit(2)

if not skills_root.exists():
    print(f"✗ Skills root not found: {skills_root}", file=sys.stderr)
    sys.exit(2)

if skill_filters:
    skill_dirs = [skills_root / name for name in skill_filters]
else:
    skill_dirs = sorted([p for p in skills_root.iterdir() if p.is_dir() and not p.name.startswith('.')])

graph_dirs = []
for skill_dir in skill_dirs:
    if not skill_dir.exists():
        print(f"✗ Skill not found: {skill_dir}")
        sys.exit(1)
    graph_dir = skill_dir / "graph"
    if graph_dir.exists() and graph_dir.is_dir():
        graph_dirs.append(graph_dir)
    elif skill_filters:
        print(f"✗ No graph/ directory for skill: {skill_dir.name}")
        sys.exit(1)

if not graph_dirs:
    print("No graph directories found.")
    sys.exit(0)

required_keys = {"id", "description", "status", "tags", "links"}
allowed_status = {
    "active",
    "draft",
    "proposed",
    "piloting",
    "adopted",
    "rejected",
    "deprecated",
    "archived",
}

errors = []
checked_files = 0

wikilink_pattern = re.compile(r"\[\[([^\]]+)\]\]")


def parse_frontmatter(text: str, path: Path):
    if not text.startswith("---\n"):
        errors.append(f"{path}: missing YAML frontmatter")
        return None, text

    end = text.find("\n---\n", 4)
    if end == -1:
        errors.append(f"{path}: malformed YAML frontmatter delimiter")
        return None, text

    raw = text[4:end]
    body = text[end + 5 :]

    try:
        data = yaml.safe_load(raw)
    except Exception as exc:
        errors.append(f"{path}: invalid YAML frontmatter: {exc}")
        return None, body

    if not isinstance(data, dict):
        errors.append(f"{path}: frontmatter must be a YAML object")
        return None, body

    return data, body


def normalize_target(raw: str) -> str:
    target = raw.split("|", 1)[0].strip()
    if target.startswith("[[") and target.endswith("]]" ):
        target = target[2:-2].strip()
    return target


def split_anchor(target: str) -> str:
    return target.split("#", 1)[0].strip()


def is_http_target(target: str) -> bool:
    return target.startswith("http://") or target.startswith("https://")


def is_markdown_path_target(base_target: str) -> bool:
    return "/" in base_target or base_target.endswith(".md")


def resolve_markdown_path(current_file: Path, base_target: str):
    """Resolve path-like markdown target relative to current file."""
    if not base_target:
        return None

    raw_path = Path(base_target)
    candidates = []

    if str(raw_path).startswith("~"):
        expanded = Path(str(raw_path)).expanduser()
        candidates.append(expanded)
    elif raw_path.is_absolute():
        candidates.append(raw_path)
    else:
        candidates.append((current_file.parent / raw_path))

    # Also allow omitted .md extension for path-like links.
    if raw_path.suffix == "":
        if str(raw_path).startswith("~"):
            candidates.append(Path(str(raw_path) + ".md").expanduser())
        elif raw_path.is_absolute():
            candidates.append(Path(str(raw_path) + ".md"))
        else:
            candidates.append(current_file.parent / (str(raw_path) + ".md"))

    for candidate in candidates:
        try:
            resolved = candidate.resolve()
        except Exception:
            resolved = candidate
        if resolved.exists() and resolved.is_file():
            return resolved

    return None

for graph_dir in graph_dirs:
    markdown_files = sorted(graph_dir.rglob("*.md"))
    if not markdown_files:
        errors.append(f"{graph_dir}: graph directory has no markdown files")
        continue

    parsed = {}
    known_targets = set()
    id_to_path = {}

    # First pass: parse + gather ids and stems
    for md in markdown_files:
        checked_files += 1
        text = md.read_text(encoding="utf-8")
        fm, body = parse_frontmatter(text, md)
        parsed[md] = (fm, body)

        known_targets.add(md.stem)

        if not isinstance(fm, dict):
            continue

        node_id = fm.get("id")
        if isinstance(node_id, str) and node_id.strip():
            node_id = node_id.strip()
            known_targets.add(node_id)
            if node_id in id_to_path:
                errors.append(
                    f"{md}: duplicate id '{node_id}' (already used by {id_to_path[node_id]})"
                )
            else:
                id_to_path[node_id] = md
        else:
            errors.append(f"{md}: missing or invalid 'id'")

    # Second pass: validate metadata and links
    for md in markdown_files:
        fm, body = parsed[md]
        if not isinstance(fm, dict):
            continue

        missing = sorted(required_keys - set(fm.keys()))
        if missing:
            errors.append(f"{md}: missing required frontmatter keys: {', '.join(missing)}")

        description = fm.get("description")
        if not isinstance(description, str) or not description.strip():
            errors.append(f"{md}: 'description' must be a non-empty string")

        status = fm.get("status")
        if not isinstance(status, str) or status not in allowed_status:
            errors.append(
                f"{md}: invalid 'status' ({status!r}); allowed: {', '.join(sorted(allowed_status))}"
            )

        tags = fm.get("tags")
        if not isinstance(tags, list):
            errors.append(f"{md}: 'tags' must be a YAML list")

        links = fm.get("links")
        if not isinstance(links, list):
            errors.append(f"{md}: 'links' must be a YAML list")
            links = []

        fm_targets = []
        for item in links:
            # YAML parses unquoted wiki-links like [[node-id]] into nested single-item lists.
            while isinstance(item, list) and len(item) == 1:
                item = item[0]

            if isinstance(item, str):
                fm_targets.append(normalize_target(item))
                continue

            errors.append(f"{md}: frontmatter links entries must be strings or nested single-item wiki-link lists")

        body_targets = [normalize_target(t) for t in wikilink_pattern.findall(body)]

        for target in fm_targets + body_targets:
            if not target:
                continue

            if is_http_target(target):
                continue

            base_target = split_anchor(target)
            if not base_target:
                continue

            if is_markdown_path_target(base_target):
                resolved = resolve_markdown_path(md, base_target)
                if resolved is None:
                    errors.append(f"{md}: broken markdown path link [[{target}]]")
                continue

            if base_target not in known_targets:
                errors.append(f"{md}: broken wikilink target [[{target}]]")

if errors:
    print("\n✗ Graph QA failed")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    for err in errors:
        print(f"- {err}")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"Errors: {len(errors)}")
    sys.exit(1)

print("✓ Graph QA passed")
print(f"Checked graph directories: {len(graph_dirs)}")
print(f"Checked markdown files: {checked_files}")
PY
