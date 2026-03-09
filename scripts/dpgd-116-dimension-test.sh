#!/usr/bin/env zsh
#
# dpgd-116-dimension-test.sh — Run 8 targeted themes to test dimension hypotheses
#
# Hypotheses under test:
#   H1: meritocratic authority > hierarchical        (+8.2 spread, n=21)
#   H2: confrontation conflict > consensus/debate    (+9.0 spread, n=18)
#   H3: personal stakes > institutional              (+7.5 spread, n=14)
#   H4: conversational formality > formal/ceremonial (+6.8 spread, n=21)
#   H5: ensemble cooperation > unified               (+6.6 spread, n=15)
#
# Themes selected:
#   PREDICT LOW  (all/most "bad" signals — should score D-tier <48%):
#     vorkosigan-saga    -5 net (all 5 bad)
#     imperial-radch     -4 net (4 bad)
#
#   PREDICT HIGH (all/most "good" signals — should score A/B-tier >55%):
#     agatha-christie    +4 net (4 good)
#     big-lebowski       +4 net (4 good)
#
#   ISOLATORS (mixed signals — test which dimensions dominate):
#     ted-lasso          +3/-2  good authority+stakes+formality, BAD consensus+unified
#     software-pioneers  +3/-2  good meritocratic+conversational+ensemble, BAD debate+institutional
#     historical-figures +2/-3  good meritocratic+ensemble, BAD debate+institutional+formal
#     greek-mythology    +2/-2  good competition+ensemble, BAD hierarchical+ceremonial
#
# Usage:
#   ./scripts/dpgd-116-dimension-test.sh                    # run all 8 themes x 4 runs
#   ./scripts/dpgd-116-dimension-test.sh --themes "ted-lasso,big-lebowski"  # subset
#   ./scripts/dpgd-116-dimension-test.sh --runs 2           # fewer runs per theme
#   ./scripts/dpgd-116-dimension-test.sh --dry-run          # just show what would run
#
# Must be run from a regular terminal, NOT inside Claude Code.

set -euo pipefail

SCENARIO="/Users/keithavery/Projects/orc-ax/.local-archive/benchmarks/scenarios/dpgd-116.yaml"
PROJECT_DIR="/Users/keithavery/Projects/orc-ax"
RUNS=4
DRY_RUN=false
SELECTED_THEMES=""

# All 8 experimental themes in order: predict-low, predict-high, isolators
ALL_THEMES=(
    # Predict LOW
    vorkosigan-saga
    imperial-radch
    # Predict HIGH
    agatha-christie
    big-lebowski
    # Isolators
    ted-lasso
    software-pioneers
    historical-figures
    greek-mythology
)

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --runs)    RUNS="$2"; shift 2 ;;
        --themes)  SELECTED_THEMES="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --scenario) SCENARIO="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--runs N] [--themes t1,t2,...] [--dry-run] [--scenario PATH]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Filter themes if --themes specified
if [[ -n "$SELECTED_THEMES" ]]; then
    IFS=',' read -rA THEMES <<< "$SELECTED_THEMES"
else
    THEMES=("${ALL_THEMES[@]}")
fi

TOTAL_RUNS=$(( ${#THEMES[@]} * RUNS ))
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DPGD-116 Dimension Hypothesis Test                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Themes:    ${#THEMES[@]}                                              ║"
echo "║  Runs/theme: ${RUNS}                                              ║"
echo "║  Total:     ${TOTAL_RUNS} pipeline calls                              ║"
echo "║  Scenario:  dpgd-116                                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Verify scenario exists
if [[ ! -f "$SCENARIO" ]]; then
    echo "ERROR: Scenario file not found: $SCENARIO"
    exit 1
fi

# Track results
STARTED_AT=$(date +%s)
COMPLETED=0
FAILED=0

for theme in "${THEMES[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Theme: ${theme}  (${RUNS} runs)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if $DRY_RUN; then
        echo "  [DRY RUN] pf benchmark replay run $SCENARIO --theme $theme --n $RUNS --project-dir $PROJECT_DIR"
        echo ""
        continue
    fi

    THEME_START=$(date +%s)

    # Symlink axiathon repo if needed (scenario uses relative path)
    if [[ ! -e "$PROJECT_DIR/axiathon" ]]; then
        ln -s /Users/keithavery/Projects/axiathon "$PROJECT_DIR/axiathon"
        echo "  (created axiathon symlink)"
    fi

    if pf benchmark replay run "$SCENARIO" \
        --theme "$theme" \
        --n "$RUNS" \
        --project-dir "$PROJECT_DIR" \
        --output-dir "/Users/keithavery/Projects/pf-1/internal/results/pipeline-replay"; then
        COMPLETED=$((COMPLETED + 1))
        THEME_ELAPSED=$(( $(date +%s) - THEME_START ))
        echo "  ✓ ${theme} completed in $(( THEME_ELAPSED / 60 ))m$(( THEME_ELAPSED % 60 ))s"
    else
        FAILED=$((FAILED + 1))
        echo "  ✗ ${theme} FAILED"
    fi

    echo ""
done

TOTAL_ELAPSED=$(( $(date +%s) - STARTED_AT ))

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  COMPLETE                                                   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Completed: ${COMPLETED}/${#THEMES[@]} themes                                    ║"
echo "║  Failed:    ${FAILED}                                              ║"
echo "║  Duration:  $(( TOTAL_ELAPSED / 60 ))m$(( TOTAL_ELAPSED % 60 ))s                                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Run analysis:"
echo "  pf benchmark analyze $SCENARIO"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
