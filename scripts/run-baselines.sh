#!/usr/bin/env bash
# run-baselines.sh — Run Control + BMAD baseline samples for Peloton dpgd-116
#
# Purpose: Capture post-isolation baselines (BMAD separated from PF) to measure
# whether recent changes improved PF pipeline coverage.
#
# Runs: 2x Control, 2x BMAD (sequential — each run takes ~15-20 min)
#
# Version differentiation: pipeline.yaml records framework_version with
# PF commit hash + semver + agent file hashes (Control), or BMAD commit (BMAD).

set -euo pipefail

PROJECT_DIR="/Users/keithavery/Projects/orc-ax"
SCENARIO="${PROJECT_DIR}/benchmarks/scenarios/dpgd-116.yaml"
OUTPUT_DIR="${PROJECT_DIR}/benchmarks/results"
BMAD_ROOT="/Users/keithavery/Projects/BMAD-METHOD"
RUNS=1

cd "$PROJECT_DIR"

echo "============================================"
echo "Peloton Baseline Run — dpgd-116"
echo "============================================"
echo "Date:       $(date '+%Y-%m-%d %H:%M:%S')"
echo "PF commit:  $(cd pennyfarthing && git rev-parse HEAD | cut -c1-12)"
echo "PF version: $(cd pennyfarthing && grep 'version =' pyproject.toml | head -1)"
echo "BMAD commit: $(cd "$BMAD_ROOT" && git rev-parse HEAD | cut -c1-12)"
echo "Runs/agent: ${RUNS}"
echo "Output:     ${OUTPUT_DIR}"
echo "============================================"
echo ""

# --- Control baselines (PF agents, no persona) ---
echo ">>> Phase 1/2: Control baseline (${RUNS} runs)"
echo ""
pf benchmark replay run "$SCENARIO" \
    --n "$RUNS" \
    --output-dir "$OUTPUT_DIR" \
    --skip-score

echo ""
echo ">>> Control runs complete."
echo ""

# --- BMAD baselines ---
echo ">>> Phase 2/2: BMAD baseline (${RUNS} runs)"
echo ""
pf benchmark replay run "$SCENARIO" \
    --n "$RUNS" \
    --output-dir "$OUTPUT_DIR" \
    --bmad-root "$BMAD_ROOT" \
    --skip-score

echo ""
echo ">>> BMAD runs complete."
echo ""

echo "============================================"
echo "All baseline runs finished at $(date '+%H:%M:%S')"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Score:   pf benchmark replay judge benchmarks/scenarios/dpgd-116.yaml --results-dir benchmarks/results"
echo "  2. Compare: pf benchmark replay compare benchmarks/scenarios/dpgd-116.yaml --results-dir benchmarks/results"
