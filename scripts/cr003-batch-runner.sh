#!/bin/bash
# CR-003 Batch Benchmark Runner
# Runs multiple theme:role combinations sequentially
#
# Usage: ./scripts/cr003-batch-runner.sh <config_file> [runs_per_combo]
#        ./scripts/cr003-batch-runner.sh --list-themes
#
# Config file format (one combo per line):
#   theme:role
#   theme:source_role:role    (cross-role)
#   # comments and blank lines are ignored
#
# Examples:
#   echo "firefly:dev" > batch.txt
#   echo "firefly:reviewer" >> batch.txt
#   echo "hogans-heroes:dev" >> batch.txt
#   echo "firefly:reviewer:dev" >> batch.txt   # River Tam (reviewer) in dev seat
#   ./scripts/cr003-batch-runner.sh batch.txt 10
#
# Quick mode (no config file):
#   ./scripts/cr003-batch-runner.sh --theme firefly --roles dev,reviewer,tea [runs]
#
# Output: internal/results/personas/cr-003/<theme>/<role>/summary.yaml per combo
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="${BASE_DIR}/scripts/cr003-persona-runner-v2.sh"
THEMES_DIR="${BASE_DIR}/pennyfarthing/pennyfarthing-dist/personas/themes"

# --list-themes mode
if [[ "${1:-}" == "--list-themes" ]]; then
  echo "Available themes:"
  ls "$THEMES_DIR" | sed 's/\.yaml$//' | sort | column
  exit 0
fi

# --theme quick mode
if [[ "${1:-}" == "--theme" ]]; then
  THEME="${2:?--theme requires a theme name}"
  ROLES="${3:?--theme requires --roles <role1,role2,...>}"
  # Strip --roles prefix if present
  ROLES="${ROLES#--roles}"
  ROLES="${ROLES# }"
  # Handle: --theme firefly --roles dev,reviewer 10
  if [[ "${3:-}" == "--roles" ]]; then
    ROLES="${4:?--roles requires role list}"
    RUNS="${5:-10}"
  else
    RUNS="${4:-10}"
  fi

  echo "=== CR-003 Batch: ${THEME} x [${ROLES}] x N=${RUNS} ==="
  echo ""

  RESULTS=()
  FAILED=()

  IFS=',' read -ra ROLE_ARRAY <<< "$ROLES"
  for ROLE in "${ROLE_ARRAY[@]}"; do
    ROLE=$(echo "$ROLE" | xargs)  # trim whitespace
    echo ">>> Starting ${THEME}:${ROLE} (N=${RUNS})"
    if bash "$RUNNER" "$THEME" "$ROLE" "$RUNS"; then
      RESULTS+=("${THEME}:${ROLE} -- OK")
    else
      RESULTS+=("${THEME}:${ROLE} -- FAILED")
      FAILED+=("${THEME}:${ROLE}")
    fi
    echo ""
  done

  echo "=== Batch Complete ==="
  for r in "${RESULTS[@]}"; do echo "  $r"; done
  if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo "FAILURES: ${#FAILED[@]}"
    for f in "${FAILED[@]}"; do echo "  $f"; done
    exit 1
  fi
  exit 0
fi

# Config file mode
CONFIG="${1:?Usage: $0 <config_file> [runs] OR --theme <theme> --roles <roles> [runs] OR --list-themes}"
RUNS="${2:-10}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config file not found: ${CONFIG}"
  exit 1
fi

# Parse config and count combos
COMBOS=()
while IFS= read -r line; do
  line=$(echo "$line" | xargs)  # trim
  [[ -z "$line" || "$line" == \#* ]] && continue
  COMBOS+=("$line")
done < "$CONFIG"

echo "=== CR-003 Batch Benchmark ==="
echo "  Config: ${CONFIG}"
echo "  Combos: ${#COMBOS[@]}"
echo "  Runs per combo: ${RUNS}"
echo ""

RESULTS=()
FAILED=()

for combo in "${COMBOS[@]}"; do
  # Parse theme:role or theme:source_role:role
  IFS=':' read -ra PARTS <<< "$combo"

  if [[ ${#PARTS[@]} -eq 2 ]]; then
    THEME="${PARTS[0]}"
    ROLE="${PARTS[1]}"
    echo ">>> Starting ${THEME}:${ROLE} (N=${RUNS})"
    if bash "$RUNNER" "$THEME" "$ROLE" "$RUNS"; then
      RESULTS+=("${combo} -- OK")
    else
      RESULTS+=("${combo} -- FAILED")
      FAILED+=("$combo")
    fi

  elif [[ ${#PARTS[@]} -eq 3 ]]; then
    THEME="${PARTS[0]}"
    SOURCE_ROLE="${PARTS[1]}"
    ROLE="${PARTS[2]}"
    echo ">>> Starting ${THEME}:${SOURCE_ROLE}-as-${ROLE} (N=${RUNS})"
    if bash "$RUNNER" "$THEME" "$ROLE" "$RUNS" --as "$SOURCE_ROLE"; then
      RESULTS+=("${combo} -- OK")
    else
      RESULTS+=("${combo} -- FAILED")
      FAILED+=("$combo")
    fi

  else
    echo "WARNING: Invalid combo format: ${combo} (expected theme:role or theme:source:role)"
    RESULTS+=("${combo} -- SKIPPED (invalid format)")
  fi

  echo ""
done

# Summary
echo "========================================="
echo "=== Batch Complete ==="
echo "========================================="
for r in "${RESULTS[@]}"; do echo "  $r"; done

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo ""
  echo "FAILURES: ${#FAILED[@]}"
  for f in "${FAILED[@]}"; do echo "  $f"; done
  exit 1
fi

echo ""
echo "All ${#COMBOS[@]} combos completed successfully."

# Print comparison table
echo ""
echo "=== Quick Comparison ==="
python3 << PYEOF
import yaml, glob, os

base = '${BASE_DIR}/internal/results/personas/cr-003'
rows = []
for combo in """$(printf '%s\n' "${COMBOS[@]}")""".strip().split('\n'):
    parts = combo.strip().split(':')
    if len(parts) == 2:
        theme, role = parts
        path = f'{base}/{theme}/{role}/summary.yaml'
    elif len(parts) == 3:
        theme, source, role = parts
        path = f'{base}/{theme}/{source}-as-{role}/summary.yaml'
    else:
        continue
    if os.path.exists(path):
        d = yaml.safe_load(open(path))
        s = d.get('statistics', {})
        dp = d.get('detection_profile', {})
        f1 = dp.get('f1_serde_bypass', '?')
        rows.append((combo, s.get('mean', 0), s.get('std_dev', 0), s.get('n', 0), f1))

if rows:
    print(f'{"Spec":<35} {"Mean":>6} {"StdDev":>7} {"N":>3} {"F1":>5}')
    print('-' * 60)
    for spec, mean, std, n, f1 in sorted(rows, key=lambda x: -x[1]):
        print(f'{spec:<35} {mean:>6.2f} {std:>7.2f} {n:>3} {f1:>5}')
PYEOF
