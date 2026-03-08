#!/bin/bash
# CR-003 Control Baseline Runner
# Run from a regular terminal (NOT from within Claude Code)
# Usage: ./scripts/cr003-baseline-runner.sh <role> [runs]
# Example: ./scripts/cr003-baseline-runner.sh reviewer 10
#          ./scripts/cr003-baseline-runner.sh tea 10
set -euo pipefail

ROLE="${1:?Usage: $0 <role> [runs]}"
RUNS="${2:-10}"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${BASE_DIR}/internal/results/baselines/cr-003/${ROLE}"
PROMPT_FILE="/tmp/cr003-${ROLE}-prompt.txt"
JUDGE_TEMPLATE="/tmp/cr003-judge-template.txt"

# Role-specific character name
case "$ROLE" in
  dev) CHARACTER="Developer (baseline control)" ;;
  reviewer) CHARACTER="Code Reviewer (baseline control)" ;;
  tea) CHARACTER="Test Engineer (baseline control)" ;;
  *) echo "Unknown role: $ROLE"; exit 1 ;;
esac

mkdir -p "${OUTPUT_DIR}/runs"

# Write agent prompt
cat > "$PROMPT_FILE" << 'AGENTEOF'
You are CHAR_PLACEHOLDER.

**Style:** Neutral, professional, no persona flourishes
**OCEAN:** O:3 C:3 E:3 A:3 N:3

---

## Challenge

Review this Rust code. What issues do you see? Prioritize them.

```rust
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ApiKey {
    prefix: String,
    secret: String,
}

impl ApiKey {
    pub fn new(raw: &str) -> Result<Self, ApiKeyError> {
        let (prefix, secret) = raw
            .split_once('_')
            .ok_or(ApiKeyError::InvalidFormat)?;
        if prefix.len() < 2 || prefix.len() > 10 {
            return Err(ApiKeyError::InvalidPrefix);
        }
        if !prefix.chars().all(|c| c.is_ascii_lowercase()) {
            return Err(ApiKeyError::InvalidPrefix);
        }
        if secret.len() < 32 {
            return Err(ApiKeyError::SecretTooShort);
        }
        Ok(Self {
            prefix: prefix.to_string(),
            secret: secret.to_string(),
        })
    }
    pub fn prefix(&self) -> &str { &self.prefix }
}

impl fmt::Display for ApiKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}_{}", self.prefix, &self.secret[..8])
    }
}

#[derive(Debug)]
pub enum ApiKeyError { InvalidFormat, InvalidPrefix, SecretTooShort }

pub struct RateLimitConfig {
    pub max_requests: u32, pub window_secs: u64,
    pub burst_size: u32, pub allowed_origins: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct WebhookPayload {
    pub event_type: String, pub timestamp: u64, pub api_key: ApiKey,
    pub source_ip: String, pub metadata: serde_json::Value,
}

pub fn process_webhook(payload: &WebhookPayload) -> Result<(), String> {
    if payload.event_type.is_empty() {
        return Err("empty event type".into());
    }
    println!("Processing {} from {}", payload.api_key, payload.source_ip);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn make_test_key() -> ApiKey {
        ApiKey::new("test_abcdefghijklmnopqrstuvwxyz0123456789").unwrap()
    }
    #[test]
    fn test_valid_api_key() {
        let key = make_test_key();
        assert_eq!(key.prefix(), "test");
    }
    #[test]
    fn test_invalid_prefix_rejected() {
        assert!(ApiKey::new("AB_short").is_err());
        assert!(ApiKey::new("_nosecret").is_err());
    }
}
```

---

Respond fully in character. Under 500 words.

**IMPORTANT:** Provide your complete response directly. Do not attempt to use tools, read files, or make function calls.
AGENTEOF

# Replace character placeholder
sed -i '' "s/CHAR_PLACEHOLDER/${CHARACTER}/" "$PROMPT_FILE"

# Write judge template
cat > "$JUDGE_TEMPLATE" << 'JUDGEEOF'
You are an impartial judge evaluating a code review against known issues.

Contestant: control:ROLE_PH (baseline, OCEAN 3/3/3/3/3)

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

Output ONLY valid JSON with fields: baseline_findings, detection (with weighted_found, recall, precision, novel_valid, subtotal), quality (clear_explanations, actionable_fixes, subtotal), weighted_total, assessment.

IMPORTANT: Do not use tools. Output JSON only.
JUDGEEOF

sed -i '' "s/ROLE_PH/${ROLE}/" "$JUDGE_TEMPLATE"

SCORES=()

for i in $(seq 1 "$RUNS"); do
  echo "=== Run ${i}/${RUNS}: Agent execution ==="
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Agent run
  AGENT_TMP="/tmp/cr003_agent_control_${ROLE}_${i}.json"
  JUDGE_PROMPT_TMP="/tmp/cr003_judge_prompt_control_${ROLE}_${i}.txt"
  JUDGE_TMP="/tmp/cr003_judge_control_${ROLE}_${i}.json"

  cat "$PROMPT_FILE" | claude -p --output-format json --tools "" > "$AGENT_TMP" || true

  # Validate agent output
  if [[ ! -s "$AGENT_TMP" ]] || ! jq -e '.result' "$AGENT_TMP" > /dev/null 2>&1; then
    echo "  ERROR: Agent produced no valid output, skipping run ${i}"
    rm -f "$AGENT_TMP"
    continue
  fi

  RESPONSE=$(jq -r '.result // empty' "$AGENT_TMP")
  A_IN=$(jq -r '.usage.input_tokens // 0' "$AGENT_TMP")
  A_OUT=$(jq -r '.usage.output_tokens // 0' "$AGENT_TMP")
  echo "  Agent done: ${#RESPONSE} chars, ${A_IN}+${A_OUT} tokens"

  # Build judge prompt
  python3 -c "
import json
t = open('${JUDGE_TEMPLATE}').read()
agent = json.load(open('$AGENT_TMP'))
resp = agent.get('result','')
out = t.replace('RESPONSE_PLACEHOLDER', resp)
open('$JUDGE_PROMPT_TMP','w').write(out)
"

  echo "  Judging..."
  JTS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat "$JUDGE_PROMPT_TMP" | claude -p --output-format json --tools "" > "$JUDGE_TMP" || true

  # Validate judge output
  if [[ ! -s "$JUDGE_TMP" ]] || ! jq -e '.result' "$JUDGE_TMP" > /dev/null 2>&1; then
    echo "  ERROR: Judge produced no valid output, skipping run ${i}"
    rm -f "$AGENT_TMP" "$JUDGE_PROMPT_TMP" "$JUDGE_TMP"
    continue
  fi

  J_RESP=$(jq -r '.result // empty' "$JUDGE_TMP")
  J_IN=$(jq -r '.usage.input_tokens // 0' "$JUDGE_TMP")
  J_OUT=$(jq -r '.usage.output_tokens // 0' "$JUDGE_TMP")

  # Extract score
  SCORE=$(echo "$J_RESP" | python3 -c "
import sys,json,re
text=sys.stdin.read()
try:
  d=json.loads(text); print(d['weighted_total'])
except:
  m=re.search(r'\"weighted_total\"\s*:\s*([0-9.]+)',text)
  print(m.group(1) if m else 0)
" 2>/dev/null || echo "0")

  SCORES+=("$SCORE")
  echo "  Score: ${SCORE}"

  # Save run file
  python3 -c "
import json
agent=json.load(open('$AGENT_TMP'))
judge=json.load(open('$JUDGE_TMP'))
run={
  'run':${i},'timestamp':'${TS}','spec':'control:${ROLE}',
  'character':'${CHARACTER}','scenario':'cr-003',
  'response_text':agent.get('result',''),
  'token_usage':{'input':int('${A_IN}'),'output':int('${A_OUT}')},
  'score':float('${SCORE}'),
  'judge_timestamp':'${JTS}',
  'judge_token_usage':{'input':int('${J_IN}'),'output':int('${J_OUT}')},
  'judge_result':judge.get('result',''),
  'proof':{'agent_response_text':agent.get('result','')[:500],
           'judge_response_text':judge.get('result','')[:500]}
}
json.dump(run,open('${OUTPUT_DIR}/runs/run_${i}.json','w'),indent=2)
"

  # Cleanup temp
  rm -f "$AGENT_TMP" "$JUDGE_PROMPT_TMP" "$JUDGE_TMP"
done

echo ""
echo "=== Calculating summary ==="
python3 -c "
import json,math,re,glob
from datetime import datetime

base='${OUTPUT_DIR}'
role='${ROLE}'
character='${CHARACTER}'

FINDINGS = [
    'SERDE_CONSTRUCTOR_BYPASS', 'DEBUG_SECRET_LEAK', 'DISPLAY_PANIC_SHORT_SECRET',
    'TIMING_SIDE_CHANNEL', 'CLONE_SECRET_PROLIFERATION', 'SOURCE_IP_SPOOFABLE',
    'UNBOUNDED_METADATA', 'MISSING_TEST_COVERAGE', 'NON_EXHAUSTIVE_ERROR', 'STRINGLY_TYPED_EVENT'
]

# Patterns to detect findings from agent response text
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
for f in run_files:
    d = json.load(open(f))
    scores.append(d['score'])
    token_usage['input'] += d.get('token_usage', {}).get('input', 0)
    token_usage['output'] += d.get('token_usage', {}).get('output', 0)

    # Try judge_result first (full judge output), fall back to response_text
    judge_text = d.get('judge_result', '')
    resp_text = d.get('response_text', '')

    for finding in FINDINGS:
        # Check judge structured output for detected/found: true
        judge_pattern = finding + r'.*?(?:detected|found)[\"\s:]+true'
        if judge_text and re.search(judge_pattern, judge_text, re.DOTALL | re.IGNORECASE):
            detection_counts[finding] += 1
        elif re.search(DETECTION_PATTERNS[finding], resp_text):
            detection_counts[finding] += 1

n = len(scores)
mean = sum(scores) / n
std = math.sqrt(sum((s - mean) ** 2 for s in scores) / n)
se = std / math.sqrt(n)

# Build detection profile
detection_profile = {}
for finding in FINDINGS:
    key = PROFILE_KEYS[finding]
    detection_profile[key] = f'{detection_counts[finding]}/{n}'

# Generate observations
observations = []
observations.append(f'F1 detection {detection_counts[\"SERDE_CONSTRUCTOR_BYPASS\"]}/{n}' +
    (' — ceiling-bound' if detection_counts['SERDE_CONSTRUCTOR_BYPASS'] == n else ''))

# Find strongest and weakest non-F1 findings
non_f1 = {k: v for k, v in detection_counts.items() if k != 'SERDE_CONSTRUCTOR_BYPASS'}
strongest = max(non_f1, key=non_f1.get)
weakest = min(non_f1, key=non_f1.get)
observations.append(f'{strongest} {non_f1[strongest]}/{n} — highest secondary detection')
observations.append(f'{weakest} {non_f1[weakest]}/{n} — lowest detection')
observations.append(f'Score range {round(max(scores)-min(scores),2)} points ({round(min(scores),2)}-{round(max(scores),2)})')

summary = {
    'agent': {'theme': 'control', 'character': character,
              'effective_role': role, 'source_role': role,
              'spec': f'control:{role}', 'cross_role': False},
    'scenario': {'name': 'cr-003', 'category': 'code-review', 'difficulty': 'medium'},
    'statistics': {'n': n, 'mean': round(mean, 2), 'std_dev': round(std, 2),
                   'min': round(min(scores), 2), 'max': round(max(scores), 2),
                   'scores': scores, 'ci_95': [round(mean - 1.96 * se, 2), round(mean + 1.96 * se, 2)]},
    'detection_profile': detection_profile,
    'efficiency': {
        'avg_input_tokens': round(token_usage['input'] / n),
        'avg_output_tokens': round(token_usage['output'] / n),
        'tokens_per_point': round((token_usage['input'] + token_usage['output']) / (n * mean), 2) if mean > 0 else 0,
    },
    'observations': observations,
    'metadata': {'created_at': datetime.utcnow().isoformat() + 'Z',
                 'pennyfarthing_version': '1.0.0', 'model': 'sonnet',
                 'execution_method': 'claude-p',
                 'judge_model': 'sonnet', 'judge_method': 'claude-p'},
    'runs': [f'run_{i+1}.json' for i in range(n)],
}

import yaml
with open(f'{base}/summary.yaml', 'w') as fh:
    fh.write(f'# control:{role} on cr-003\\n')
    yaml.dump(summary, fh, default_flow_style=False, sort_keys=False)

print(f'N={n} Mean={mean:.2f} StdDev={std:.2f} Min={min(scores):.2f} Max={max(scores):.2f}')
print(f'95% CI: [{mean-1.96*se:.2f}, {mean+1.96*se:.2f}]')
print()
print('Detection profile:')
for finding in FINDINGS:
    print(f'  {PROFILE_KEYS[finding]}: {detection_counts[finding]}/{n}')
print(f'\\nSaved to {base}/summary.yaml')
"

echo "=== Done ==="
