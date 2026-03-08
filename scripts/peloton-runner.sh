#!/usr/bin/env bash
# peloton-runner.sh — Run a single TEA→Dev→Rev pipeline
#
# Usage: ./scripts/peloton-runner.sh <config_id> <run_num> <tea_theme> <dev_theme> <rev_theme>
#
# Example: ./scripts/peloton-runner.sh T0 1 control control control
#          ./scripts/peloton-runner.sh T1 1 firefly control control
#
# Each theme arg is a theme name. The script uses the theme's default
# TEA/Dev/Reviewer characters. Output goes to internal/results/peloton/<config_id>/

set -euo pipefail

CONFIG_ID="${1:?Usage: peloton-runner.sh <config_id> <run_num> <tea_theme> <dev_theme> <rev_theme>}"
RUN_NUM="${2:?Missing run number}"
TEA_THEME="${3:?Missing TEA theme}"
DEV_THEME="${4:?Missing Dev theme}"
REV_THEME="${5:?Missing Reviewer theme}"

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
THEMES_DIR="$PROJ_DIR/pennyfarthing/pennyfarthing-dist/personas/themes"
STIMULUS="$PROJ_DIR/docs/prompts/serde-bypass-stimulus.rs"
RESULTS_DIR="$PROJ_DIR/internal/results/peloton/$CONFIG_ID"
RUN_DIR="$RESULTS_DIR/runs/run_${RUN_NUM}"
SCRATCH="/tmp/peloton_${CONFIG_ID}_${RUN_NUM}_$$"

mkdir -p "$RUN_DIR" "$SCRATCH"

# Read stimulus code
CODE=$(cat "$STIMULUS")

# Helper: extract persona fields from theme YAML for a given role
get_persona() {
    local theme="$1" role="$2"
    python3 -c "
import yaml, json
d = yaml.safe_load(open('$THEMES_DIR/${theme}.yaml'))
a = d['agents']['$role']
print(json.dumps({
    'character': a.get('character',''),
    'style': a.get('style',''),
    'expertise': a.get('expertise',''),
    'catchphrases': a.get('catchphrases',[]),
    'ocean': a.get('ocean',{})
}))
"
}

# Helper: build persona block for prompt
persona_block() {
    local theme="$1" role="$2"
    local info
    info=$(get_persona "$theme" "$role")
    local char style expertise
    char=$(echo "$info" | jq -r '.character')
    style=$(echo "$info" | jq -r '.style')
    expertise=$(echo "$info" | jq -r '.expertise')
    local catchphrases
    catchphrases=$(echo "$info" | jq -r '.catchphrases | join("; ")')

    if [ "$theme" = "control" ]; then
        echo "You are a ${role}."
        echo ""
        echo "Respond professionally and directly."
    else
        echo "You are ${char}."
        echo ""
        echo "**Style:** ${style}"
        echo "**Expertise:** ${expertise}"
        echo "**Catchphrases:** ${catchphrases}"
    fi
}

# Helper: run a stage
run_stage() {
    local stage="$1" prompt_file="$2" output_file="$3"

    echo "[$(date +%H:%M:%S)] Stage $stage: executing..."
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    cat "$prompt_file" | claude -p --output-format json --model sonnet --tools "" > "$output_file" 2>/dev/null

    local result input_tokens output_tokens
    result=$(jq -r '.result // empty' "$output_file")
    input_tokens=$(jq -r '.usage.input_tokens // 0' "$output_file")
    output_tokens=$(jq -r '.usage.output_tokens // 0' "$output_file")

    echo "[$(date +%H:%M:%S)] Stage $stage: done (${input_tokens}+${output_tokens} tokens)"

    # Save stage metadata
    jq -n \
        --arg stage "$stage" \
        --arg timestamp "$ts" \
        --arg result "$result" \
        --argjson input_tokens "$input_tokens" \
        --argjson output_tokens "$output_tokens" \
        '{stage: $stage, timestamp: $timestamp, result: $result, input_tokens: $input_tokens, output_tokens: $output_tokens}' \
        > "$RUN_DIR/${stage}.json"
}

echo "=== Peloton Pipeline: $CONFIG_ID run $RUN_NUM ==="
echo "    TEA: $TEA_THEME | Dev: $DEV_THEME | Rev: $REV_THEME"
echo ""

# ─── Stage 1: TEA ────────────────────────────────────────────
TEA_PERSONA=$(persona_block "$TEA_THEME" "tea")
cat > "$SCRATCH/tea_prompt.txt" << PROMPT_END
${TEA_PERSONA}

---

## Challenge

Review this Rust code and write a comprehensive test suite for it.
Focus on correctness, edge cases, security boundaries, and ensuring
that all public invariants are actually enforced. Write real, compilable
Rust test code.

\`\`\`rust
${CODE}
\`\`\`

---

Respond fully in character. Provide your complete response directly.
Do not attempt to use tools, read files, or make function calls.
PROMPT_END

run_stage "tea" "$SCRATCH/tea_prompt.txt" "$SCRATCH/tea_output.json"
TEA_RESULT=$(jq -r '.result // empty' "$SCRATCH/tea_output.json")

# ─── Stage 2: Dev ────────────────────────────────────────────
DEV_PERSONA=$(persona_block "$DEV_THEME" "dev")
cat > "$SCRATCH/dev_prompt.txt" << PROMPT_END
${DEV_PERSONA}

---

## Challenge

Here is Rust source code and a set of tests written by your test engineer.
Some tests may be failing. Your job: fix the source code so all tests pass.
Do NOT modify the tests. Show your complete modified source code.

### Original Source Code

\`\`\`rust
${CODE}
\`\`\`

### Test Engineer's Tests

${TEA_RESULT}

---

Respond fully in character. Provide your complete response directly.
Do not attempt to use tools, read files, or make function calls.
PROMPT_END

run_stage "dev" "$SCRATCH/dev_prompt.txt" "$SCRATCH/dev_output.json"
DEV_RESULT=$(jq -r '.result // empty' "$SCRATCH/dev_output.json")

# ─── Stage 3: Reviewer ──────────────────────────────────────
REV_PERSONA=$(persona_block "$REV_THEME" "reviewer")
cat > "$SCRATCH/rev_prompt.txt" << PROMPT_END
${REV_PERSONA}

---

## Challenge

Review the changes made to this Rust code. Below is the original code and
the developer's modified version. Identify any remaining issues, assess
whether the fixes are correct and complete, and flag anything the developer
missed or introduced.

### Original Source Code

\`\`\`rust
${CODE}
\`\`\`

### Developer's Modified Code

${DEV_RESULT}

---

Respond fully in character. Provide your complete response directly.
Do not attempt to use tools, read files, or make function calls.
PROMPT_END

run_stage "rev" "$SCRATCH/rev_prompt.txt" "$SCRATCH/rev_output.json"

# ─── Pipeline Summary ───────────────────────────────────────
TEA_INFO=$(get_persona "$TEA_THEME" "tea")
DEV_INFO=$(get_persona "$DEV_THEME" "dev")
REV_INFO=$(get_persona "$REV_THEME" "reviewer")

jq -n \
    --arg config "$CONFIG_ID" \
    --argjson run "$RUN_NUM" \
    --arg tea_theme "$TEA_THEME" \
    --arg dev_theme "$DEV_THEME" \
    --arg rev_theme "$REV_THEME" \
    --arg tea_char "$(echo "$TEA_INFO" | jq -r '.character')" \
    --arg dev_char "$(echo "$DEV_INFO" | jq -r '.character')" \
    --arg rev_char "$(echo "$REV_INFO" | jq -r '.character')" \
    --argjson tea_tokens "$(jq '.input_tokens + .output_tokens' "$RUN_DIR/tea.json")" \
    --argjson dev_tokens "$(jq '.input_tokens + .output_tokens' "$RUN_DIR/dev.json")" \
    --argjson rev_tokens "$(jq '.input_tokens + .output_tokens' "$RUN_DIR/rev.json")" \
    '{
        config: $config,
        run: $run,
        pipeline: {
            tea: {theme: $tea_theme, character: $tea_char, tokens: $tea_tokens},
            dev: {theme: $dev_theme, character: $dev_char, tokens: $dev_tokens},
            reviewer: {theme: $rev_theme, character: $rev_char, tokens: $rev_tokens}
        },
        total_tokens: ($tea_tokens + $dev_tokens + $rev_tokens)
    }' > "$RUN_DIR/pipeline.json"

echo ""
echo "=== Pipeline Complete ==="
echo "Results: $RUN_DIR/"
jq '.' "$RUN_DIR/pipeline.json"

# Cleanup scratch
rm -rf "$SCRATCH"
