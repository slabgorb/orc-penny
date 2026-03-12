#!/bin/bash
# CR-003 Re-Judge Script
# Re-scores existing run files with a new judge rubric without re-running agents.
# Reads response_text from existing run files, sends through judge, updates scores.
#
# Usage: ./scripts/cr003-rejudge.sh <results_dir>
#
# Examples:
#   ./scripts/cr003-rejudge.sh internal/results/baselines/cr-003/dev
#   ./scripts/cr003-rejudge.sh internal/results/baselines/cr-003/reviewer
#   ./scripts/cr003-rejudge.sh internal/results/baselines/cr-003/tea
#   ./scripts/cr003-rejudge.sh all-baselines    # shortcut for all three
#
# This uses the SAME judge rubric as cr003-persona-runner.sh (no persona scoring).
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
JUDGE_TEMPLATE="/tmp/cr003-rejudge-template.txt"

# Build judge template (matches persona-runner exactly)
cat > "$JUDGE_TEMPLATE" << 'JUDGEEOF'
You are an impartial judge evaluating a code review against known issues.

Contestant: SPEC_PLACEHOLDER

Expected Findings (weights: CRITICAL=15, HIGH=10, MEDIUM=5, LOW=2, total=69):
CRITICAL: SERDE_CONSTRUCTOR_BYPASS - derive(Deserialize) bypasses new() validation
HIGH: DEBUG_SECRET_LEAK - Debug prints secret | DISPLAY_PANIC_SHORT_SECRET - secret[..8] panics if <8 bytes | TIMING_SIDE_CHANNEL - PartialEq timing attack
MEDIUM: CLONE_SECRET_PROLIFERATION - Clone+no Zeroize | SOURCE_IP_SPOOFABLE - string not validated | UNBOUNDED_METADATA - serde_json::Value DoS | MISSING_TEST_COVERAGE - only 2 tests
LOW: NON_EXHAUSTIVE_ERROR - missing #[non_exhaustive] | STRINGLY_TYPED_EVENT - String not enum

Response to Evaluate:
RESPONSE_PLACEHOLDER

Scoring rules:
- recall = weighted_found / 69, precision = tp / (tp + fp)
- detection.subtotal = (recall * 50) + (precision * 15) + min(novel_valid * 3, 10)
- Quality (25 max): (clear_explanations/10 * 12.5) + (actionable_fixes/10 * 12.5)
- weighted_total = detection.subtotal + quality.subtotal
- Do NOT score on persona/character voice. Only detection and quality matter.

Output ONLY valid JSON with these fields:
- baseline_findings: object mapping each finding ID to {detected: bool, weight: number}
- detection: {weighted_found, recall, precision, novel_valid, subtotal}
- quality: {clear_explanations, actionable_fixes, subtotal}
- weighted_total: number
- assessment: string (1-2 sentence summary)

IMPORTANT: Do not use tools. Output JSON only.
JUDGEEOF

rejudge_dir() {
  local DIR="$1"
  echo "=== Re-judging: ${DIR} ==="

  local RUN_FILES=($(ls "${DIR}/runs"/run_*.json 2>/dev/null | sort))
  if [[ ${#RUN_FILES[@]} -eq 0 ]]; then
    echo "  No run files found in ${DIR}/runs/"
    return 1
  fi

  echo "  Found ${#RUN_FILES[@]} run files"

  for RUN_FILE in "${RUN_FILES[@]}"; do
    local RUN_NAME=$(basename "$RUN_FILE" .json)
    local SPEC=$(python3 -c "import json; print(json.load(open('$RUN_FILE')).get('spec','unknown'))")
    echo "  Re-judging ${RUN_NAME} (${SPEC})..."

    # Extract response_text from existing run file
    local RESPONSE=$(python3 -c "import json; print(json.load(open('$RUN_FILE')).get('response_text',''))")
    if [[ -z "$RESPONSE" ]]; then
      echo "    SKIP: No response_text in ${RUN_FILE}"
      continue
    fi

    # Build judge prompt
    local JUDGE_PROMPT_TMP="/tmp/cr003_rejudge_${RUN_NAME}.txt"
    python3 -c "
import json
t = open('${JUDGE_TEMPLATE}').read()
d = json.load(open('$RUN_FILE'))
spec = d.get('spec', 'unknown')
resp = d.get('response_text', '')
out = t.replace('SPEC_PLACEHOLDER', spec).replace('RESPONSE_PLACEHOLDER', resp)
open('$JUDGE_PROMPT_TMP', 'w').write(out)
"

    # Run judge
    local JUDGE_TMP="/tmp/cr003_rejudge_judge_${RUN_NAME}.json"
    cat "$JUDGE_PROMPT_TMP" | claude -p --output-format json --tools "" > "$JUDGE_TMP" || true

    # Validate judge output
    if [[ ! -s "$JUDGE_TMP" ]] || ! jq -e '.result' "$JUDGE_TMP" > /dev/null 2>&1; then
      echo "    ERROR: Judge produced no valid output, skipping"
      rm -f "$JUDGE_PROMPT_TMP" "$JUDGE_TMP"
      continue
    fi

    local J_RESP=$(jq -r '.result // empty' "$JUDGE_TMP")
    local J_IN=$(jq -r '.usage.input_tokens // 0' "$JUDGE_TMP")
    local J_OUT=$(jq -r '.usage.output_tokens // 0' "$JUDGE_TMP")

    # Extract new score
    local NEW_SCORE=$(echo "$J_RESP" | python3 -c "
import sys,json,re
text=sys.stdin.read()
try:
  d=json.loads(text); print(d['weighted_total'])
except:
  m=re.search(r'\"weighted_total\"\s*:\s*([0-9.]+)',text)
  print(m.group(1) if m else 0)
" 2>/dev/null || echo "0")

    local OLD_SCORE=$(python3 -c "import json; print(json.load(open('$RUN_FILE')).get('score', 0))")
    echo "    Old: ${OLD_SCORE} → New: ${NEW_SCORE}"

    # Update run file in place: new score, new judge result, preserve everything else
    python3 -c "
import json
run = json.load(open('$RUN_FILE'))
judge = json.load(open('$JUDGE_TMP'))

run['old_score'] = run.get('score', 0)
run['score'] = float('${NEW_SCORE}')
run['judge_result'] = judge.get('result', '')
run['judge_timestamp'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
run['judge_token_usage'] = {'input': int('${J_IN}'), 'output': int('${J_OUT}')}
run['judge_rubric'] = 'v2-no-persona'
run['proof']['judge_response_text'] = judge.get('result', '')[:500]

json.dump(run, open('$RUN_FILE', 'w'), indent=2)
"

    rm -f "$JUDGE_PROMPT_TMP" "$JUDGE_TMP"
  done

  # Regenerate summary
  echo "  Regenerating summary..."
  python3 << PYEOF
import json,math,re,glob,yaml
from datetime import datetime

base='${DIR}'

FINDINGS = [
    'SERDE_CONSTRUCTOR_BYPASS', 'DEBUG_SECRET_LEAK', 'DISPLAY_PANIC_SHORT_SECRET',
    'TIMING_SIDE_CHANNEL', 'CLONE_SECRET_PROLIFERATION', 'SOURCE_IP_SPOOFABLE',
    'UNBOUNDED_METADATA', 'MISSING_TEST_COVERAGE', 'NON_EXHAUSTIVE_ERROR', 'STRINGLY_TYPED_EVENT'
]

DETECTION_PATTERNS = {
    'SERDE_CONSTRUCTOR_BYPASS': r'[Dd]eserializ.*bypass|bypass.*valid|derive.*Deserialize.*bypass|serde.*bypass',
    'DEBUG_SECRET_LEAK': r'[Ss]ecret.*expos|[Ss]erializ.*secret|[Dd]ebug.*secret|secret.*leak|[Ss]ecret.*log',
    'DISPLAY_PANIC_SHORT_SECRET': r'panic|secret\[\.\.8\]|unwrap.*short|slice.*bound|index.*bound',
    'TIMING_SIDE_CHANNEL': r'timing.*attack|timing.*side.?channel|constant.?time|PartialEq.*timing',
    'CLONE_SECRET_PROLIFERATION': r'[Cc]lone.*secret|secret.*memor|[Zz]eroize|heap.*secret|plaintext.*mem',
    'SOURCE_IP_SPOOFABLE': r'source.?ip.*valid|ip.*string|unvalidat.*ip|IpAddr|log.*inject',
    'UNBOUNDED_METADATA': r'unbounded.*metadata|metadata.*size|Value.*size|exhaustion|arbitrar.*json|arbitrar.*nest',
    'MISSING_TEST_COVERAGE': r'test.*coverage|no test.*deserial|coverage.*gap|test.*gap',
    'NON_EXHAUSTIVE_ERROR': r'non.?exhaustive|Display.*Error.*impl|error.*Display|ApiKeyError.*Display|lacks.*Display',
    'STRINGLY_TYPED_EVENT': r'event.?type.*enum|stringly|string.*enum.*event|typed.*event',
}

PROFILE_KEYS = {
    'SERDE_CONSTRUCTOR_BYPASS': 'f1_serde_bypass',
    'DEBUG_SECRET_LEAK': 'debug_secret_leak',
    'DISPLAY_PANIC_SHORT_SECRET': 'display_panic',
    'TIMING_SIDE_CHANNEL': 'timing_side_channel',
    'CLONE_SECRET_PROLIFERATION': 'clone_proliferation',
    'SOURCE_IP_SPOOFABLE': 'source_ip_spoofable',
    'UNBOUNDED_METADATA': 'unbounded_metadata',
    'MISSING_TEST_COVERAGE': 'missing_test_coverage',
    'NON_EXHAUSTIVE_ERROR': 'non_exhaustive_error',
    'STRINGLY_TYPED_EVENT': 'stringly_typed_event',
}

scores = []
token_usage = {'input': 0, 'output': 0}
detection_counts = {f: 0 for f in FINDINGS}

run_files = sorted(glob.glob(f'{base}/runs/run_*.json'))
first_run = json.load(open(run_files[0]))

for f in run_files:
    d = json.load(open(f))
    scores.append(d['score'])
    token_usage['input'] += d.get('token_usage', {}).get('input', 0)
    token_usage['output'] += d.get('token_usage', {}).get('output', 0)

    judge_text = d.get('judge_result', '')
    resp_text = d.get('response_text', '')

    for finding in FINDINGS:
        judge_pattern = finding + r'.*?(?:detected|found)[\"\s:]+true'
        if judge_text and re.search(judge_pattern, judge_text, re.DOTALL | re.IGNORECASE):
            detection_counts[finding] += 1
        elif re.search(DETECTION_PATTERNS[finding], resp_text):
            detection_counts[finding] += 1

n = len(scores)
mean = sum(scores) / n
std = math.sqrt(sum((s - mean) ** 2 for s in scores) / n)
se = std / math.sqrt(n)

detection_profile = {}
for finding in FINDINGS:
    key = PROFILE_KEYS[finding]
    detection_profile[key] = f'{detection_counts[finding]}/{n}'

observations = []
f1 = detection_counts['SERDE_CONSTRUCTOR_BYPASS']
observations.append(f'F1 detection {f1}/{n}' +
    (' -- ceiling-bound' if f1 == n else f' -- {round(f1/n*100)}% detection rate'))
non_f1 = {k: v for k, v in detection_counts.items() if k != 'SERDE_CONSTRUCTOR_BYPASS'}
strongest = max(non_f1, key=non_f1.get)
weakest = min(non_f1, key=non_f1.get)
observations.append(f'{strongest} {non_f1[strongest]}/{n} -- highest secondary detection')
observations.append(f'{weakest} {non_f1[weakest]}/{n} -- lowest detection')
observations.append(f'Score range {round(max(scores)-min(scores),2)} points ({round(min(scores),2)}-{round(max(scores),2)})')
breadth = sum(1 for v in detection_counts.values() if v > 0)
observations.append(f'Detection breadth: {breadth}/{len(FINDINGS)} finding types detected at least once')

# Preserve agent metadata from first run
spec = first_run.get('spec', 'unknown')
theme = first_run.get('theme', spec.split(':')[0] if ':' in spec else 'control')
role = first_run.get('role', first_run.get('effective_role', spec.split(':')[-1] if ':' in spec else 'unknown'))
character = first_run.get('character', '')
source_role = first_run.get('source_role', role)
cross_role = first_run.get('cross_role', False)
ocean = first_run.get('ocean', '')

summary = {
    'agent': {
        'theme': theme, 'character': character,
        'effective_role': role, 'source_role': source_role,
        'spec': spec, 'cross_role': cross_role,
    },
    'scenario': {'name': 'cr-003', 'category': 'code-review', 'difficulty': 'medium'},
    'statistics': {
        'n': n, 'mean': round(mean, 2), 'std_dev': round(std, 2),
        'min': round(min(scores), 2), 'max': round(max(scores), 2),
        'scores': scores,
        'ci_95': [round(mean - 1.96 * se, 2), round(mean + 1.96 * se, 2)],
    },
    'detection_profile': detection_profile,
    'efficiency': {
        'avg_input_tokens': round(token_usage['input'] / n),
        'avg_output_tokens': round(token_usage['output'] / n),
        'tokens_per_point': round((token_usage['input'] + token_usage['output']) / (n * mean), 2) if mean > 0 else 0,
    },
    'observations': observations,
    'metadata': {
        'created_at': datetime.utcnow().isoformat() + 'Z',
        'pennyfarthing_version': '1.0.0',
        'model': 'sonnet',
        'execution_method': first_run.get('execution_method', 'claude-p'),
        'judge_model': 'sonnet',
        'judge_method': 'claude-p',
        'judge_rubric': 'v2-no-persona',
        'rejudged': True,
    },
    'runs': [f'run_{i+1}.json' for i in range(n)],
}

if ocean:
    summary['agent']['ocean'] = ocean

with open(f'{base}/summary.yaml', 'w') as fh:
    fh.write(f'# {spec} on cr-003 (re-judged v2)\n')
    yaml.dump(summary, fh, default_flow_style=False, sort_keys=False)

print(f'  N={n} Mean={mean:.2f} StdDev={std:.2f} CI=[{mean-1.96*se:.2f}, {mean+1.96*se:.2f}]')
print(f'  Saved to {base}/summary.yaml')
PYEOF
}

# Handle "all-baselines" shortcut
if [[ "${1:-}" == "all-baselines" ]]; then
  for ROLE in dev reviewer tea; do
    rejudge_dir "${BASE_DIR}/internal/results/baselines/cr-003/${ROLE}"
    echo ""
  done
  echo "=== All baselines re-judged ==="
  exit 0
fi

# Single directory mode
DIR="${1:?Usage: $0 <results_dir> OR $0 all-baselines}"
if [[ ! -d "$DIR" ]]; then
  # Try relative to base
  DIR="${BASE_DIR}/${DIR}"
fi
if [[ ! -d "$DIR" ]]; then
  echo "ERROR: Directory not found: $1"
  exit 1
fi

rejudge_dir "$DIR"
echo "=== Done ==="
