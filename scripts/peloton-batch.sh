#!/usr/bin/env bash
# peloton-batch.sh — Run full experimental matrix for Peloton benchmark
#
# Usage: ./scripts/peloton-batch.sh [--n N] [--configs CONFIG_LIST]
#
# Default: N=5 runs per config, all 17 configs
# Example: ./scripts/peloton-batch.sh --n 1 --configs "T0,T1"  (proof of concept)

set -euo pipefail

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$PROJ_DIR/scripts/peloton-runner.sh"
N=5

# Parse args
CONFIGS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --n) N="$2"; shift 2 ;;
        --configs) CONFIGS="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# Full experimental matrix: config_id tea_theme dev_theme rev_theme
declare -A MATRIX
# Control baseline
MATRIX[T0]="control control control"
# TEA seat variations
MATRIX[T1]="firefly control control"
MATRIX[T2]="mash control control"
MATRIX[T3]="hogans-heroes control control"
MATRIX[T4]="gilligans-island control control"
# Dev seat variations
MATRIX[D1]="control firefly control"
MATRIX[D2]="control mash control"
MATRIX[D3]="control hogans-heroes control"
MATRIX[D4]="control gilligans-island control"
# Reviewer seat variations
MATRIX[R1]="control control firefly"
MATRIX[R2]="control control mash"
MATRIX[R3]="control control hogans-heroes"
MATRIX[R4]="control control gilligans-island"
# Full theme teams
MATRIX[FF]="firefly firefly firefly"
MATRIX[MA]="mash mash mash"
MATRIX[HH]="hogans-heroes hogans-heroes hogans-heroes"
MATRIX[GI]="gilligans-island gilligans-island gilligans-island"

# Filter configs if specified
if [ -n "$CONFIGS" ]; then
    IFS=',' read -ra SELECTED <<< "$CONFIGS"
else
    SELECTED=(T0 T1 T2 T3 T4 D1 D2 D3 D4 R1 R2 R3 R4 FF MA HH GI)
fi

TOTAL=$((${#SELECTED[@]} * N))
CURRENT=0
START_TIME=$(date +%s)

echo "╔══════════════════════════════════════════════╗"
echo "║  Peloton Benchmark: ${#SELECTED[@]} configs × N=$N = $TOTAL pipelines  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

for config in "${SELECTED[@]}"; do
    themes="${MATRIX[$config]}"
    read -r tea_theme dev_theme rev_theme <<< "$themes"

    for run in $(seq 1 "$N"); do
        CURRENT=$((CURRENT + 1))
        echo ""
        echo "━━━ [$CURRENT/$TOTAL] $config run $run ━━━"
        bash "$RUNNER" "$config" "$run" "$tea_theme" "$dev_theme" "$rev_theme"
    done
done

END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINUTES=$(( ELAPSED / 60 ))
SECONDS=$(( ELAPSED % 60 ))

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Complete: $TOTAL pipelines in ${MINUTES}m${SECONDS}s              ║"
echo "╚══════════════════════════════════════════════╝"
echo "Results: internal/results/peloton/"
