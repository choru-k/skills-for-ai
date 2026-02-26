#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

echo "[1/3] Baseline public contract check"
python3 scripts/sync-catalog-artifacts.py --check --lane public >/dev/null

echo "[2/3] Drift scenario (expected failure with exit code 4)"
DRIFT_REPO="$(mktemp -d)"
trap 'rm -rf "${DRIFT_REPO}" "${LEAK_REPO:-}"' EXIT
cp -a "${REPO_ROOT}/." "${DRIFT_REPO}/"

cd "${DRIFT_REPO}"
python3 - <<'PY'
import json
from pathlib import Path

path = Path("package.json")
data = json.loads(path.read_text(encoding="utf-8"))
skills = data.get("pi", {}).get("skills")
if not isinstance(skills, list) or len(skills) < 2:
    raise SystemExit("pi.skills must contain at least two entries for drift simulation")
skills[0], skills[1] = skills[1], skills[0]
path.write_text(f"{json.dumps(data, indent=2, ensure_ascii=False)}\n", encoding="utf-8")
PY

DRIFT_OUTPUT="$(mktemp)"
set +e
python3 scripts/sync-catalog-artifacts.py --check --lane public >"${DRIFT_OUTPUT}" 2>&1
DRIFT_RC=$?
set -e
if [[ "${DRIFT_RC}" -eq 0 ]]; then
  echo "ERROR: drift scenario unexpectedly passed" >&2
  cat "${DRIFT_OUTPUT}" >&2
  exit 1
fi
if [[ "${DRIFT_RC}" -ne 4 ]]; then
  echo "ERROR: expected drift exit code 4, got ${DRIFT_RC}" >&2
  cat "${DRIFT_OUTPUT}" >&2
  exit 1
fi
if ! grep -q '^DRIFT ' "${DRIFT_OUTPUT}"; then
  echo "ERROR: expected DRIFT output in drift scenario" >&2
  cat "${DRIFT_OUTPUT}" >&2
  exit 1
fi

rm -f "${DRIFT_OUTPUT}"


echo "[3/3] Private leak scenario (expected failure)"
LEAK_REPO="$(mktemp -d)"
cp -a "${REPO_ROOT}/." "${LEAK_REPO}/"

cd "${LEAK_REPO}"
python3 - <<'PY'
import json
from pathlib import Path

path = Path("package.json")
data = json.loads(path.read_text(encoding="utf-8"))
skills = data.get("pi", {}).get("skills")
if not isinstance(skills, list):
    raise SystemExit("pi.skills must be an array")
if "skills/work-ticket/SKILL.md" not in skills:
    skills.append("skills/work-ticket/SKILL.md")
path.write_text(f"{json.dumps(data, indent=2, ensure_ascii=False)}\n", encoding="utf-8")
PY

LEAK_OUTPUT="$(mktemp)"
set +e
bash scripts/check-private-leaks.sh >"${LEAK_OUTPUT}" 2>&1
LEAK_RC=$?
set -e
if [[ "${LEAK_RC}" -eq 0 ]]; then
  echo "ERROR: private leak scenario unexpectedly passed" >&2
  cat "${LEAK_OUTPUT}" >&2
  exit 1
fi
if ! grep -Eq 'private skill paths leaked|private ID leaked' "${LEAK_OUTPUT}"; then
  echo "ERROR: expected private-leak failure output" >&2
  cat "${LEAK_OUTPUT}" >&2
  exit 1
fi

rm -f "${LEAK_OUTPUT}"

echo "contract scenario validation passed"
