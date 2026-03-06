---
parent: context-epic-44.md
workflow: tdd
---

# Story 44-1: Add --multi-judge flag to /solo command

## Business Context

Single-judge evaluation produces unreliable scores (>50% error rate per Galileo research). This story adds the `--multi-judge N` flag to `/solo`, enabling ensemble scoring where each agent run is evaluated N times with randomized presentation order. This is the entry point for the entire multi-judge system — without it, no other story in this epic can function.

The flag must be backward-compatible: `--multi-judge 1` (or omitting the flag) behaves identically to current single-judge behavior, ensuring existing workflows and baseline data remain valid.

## Technical Guardrails

**Key files to modify:**
- `pennyfarthing-dist/commands/pf-solo.md` — Add `--multi-judge N` parameter to the command spec
- `pennyfarthing-dist/skills/pf-judge/SKILL.md` — Add support for randomized presentation order per invocation

**Patterns to follow:**
- Existing `/solo` command flow: execute agent → judge → finalize-run → save
- Multi-judge inserts a loop between execute and finalize: judge ×N with results collected as array
- Each judge invocation must randomize the order of scenario context sections to control position bias
- Store individual verdicts as `runs/judge_{i}.json` alongside the agent response

**Integration points:**
- Judge verdicts feed into 44-2 (Krippendorff Alpha) for agreement calculation
- Aggregated results feed into 44-3 (finalize-run) for storage

**Do NOT:**
- Implement agreement statistics here (that's 44-2)
- Modify finalize-run storage format (that's 44-3)
- Change single-judge behavior in any way

## Scope Boundaries

**In scope:**
- `--multi-judge N` CLI flag on `/solo` (default N=3, valid range 1-5)
- Loop invoking judge N times per run
- Randomized presentation order for each judge invocation
- Storing judge verdicts as array (`judges[]` field)
- Computing aggregated score as mean of `weighted_total` across judges
- `judge_agreement` placeholder section in summary YAML (populated by 44-2)

**Out of scope:**
- Krippendorff/Cronbach Alpha calculation (44-2)
- Finalize-run validation changes (44-3)
- Parallel judge execution (sequential is fine for v1)

## AC Context

**AC: `/solo theme:agent --scenario X --multi-judge 3` invokes judge 3 times per run**
- Test: Run with `--multi-judge 3`, verify 3 judge output files created per run
- Edge: `--multi-judge 1` produces exactly 1 judge file (backward compat)
- Edge: `--multi-judge 0` or `--multi-judge 6` should error with clear message

**AC: Each judge invocation randomizes presentation order of scenario context**
- Test: Capture the prompt sent to each judge invocation, verify section ordering differs
- The scenario description, code under review, and expected issues should appear in shuffled order
- Randomization must be per-invocation (not per-run)

**AC: Judge verdicts stored as array in `runs/judge_{i}.json`**
- Test: After multi-judge run, `runs/` contains `judge_0.json`, `judge_1.json`, `judge_2.json`
- Each file contains full judge verdict: dimension scores, weighted_total, rationale
- Format matches existing single-judge output (same schema, just multiple files)

**AC: Aggregated score (mean of weighted_totals) used as the run's canonical score**
- Test: If judges score 78, 82, 75 → canonical score = 78.33
- The canonical score is what appears in summary YAML and comparison tables

**AC: `--multi-judge 1` behaves identically to current single-judge**
- Test: Compare output of `--multi-judge 1` with omitting the flag entirely — identical structure
- No `judges[]` array when N=1, just the single verdict (backward compat)

**AC: Summary YAML includes `judge_agreement` section**
- Test: Summary YAML contains `judge_agreement:` key with placeholder for agreement stats
- Actual values populated by 44-2; this story just adds the structural section
