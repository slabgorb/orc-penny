# Story 47-1: Cascade attribution on dpgd-116 existing results

**Story ID:** 47-1
**Jira:** MSSCI-16294
**Epic:** 47 — Strategic Role Benchmarking (PM & Architect)
**Points:** 2
**Status:** in_progress
**Repos:** pennyfarthing
**Branch:** main
**Workflow:** trivial
**Phase:** finish

## Acceptance Criteria

- [x] Attribution table covering all 7 findings x 20 themes
- [x] Summary: what percentage of catches appear persona/context-driven vs code-obvious
- [x] Signal assessment: is there enough variance to justify 47-3 through 47-7?
- [x] Results written to `internal/results/cascade-attribution-dpgd-116.md`

## Context

This is the first story in the exploratory Strategic Role Benchmarking epic. The goal is to determine whether persona choice at the strategic level (PM, Architect) affects downstream pipeline outcomes.

Cascade attribution traces defect catches back to their upstream source: was the catch enabled by the code itself (code-obvious), the agent's role definition (role-driven), the persona's character (persona-driven), or upstream context documents (context-driven)?

This story analyzes existing dpgd-116 pipeline-replay results (20 themes x 4 runs, already complete) — no new pipeline runs needed. The signal found here determines whether the more expensive downstream stories (47-3 through 47-7) are worth pursuing.

## Technical Approach

1. Read all `score.yaml` files across 20 themes for dpgd-116 (`internal/results/pipeline-replay/dpgd-116/*/run-*/score.yaml`)
2. For each finding x theme x run, examine the `evidence` field
3. Classify each catch into attribution categories: code-obvious, role-driven, persona-driven, context-driven
4. Tabulate results and assess variance across themes
5. Write analysis to `internal/results/cascade-attribution-dpgd-116.md`

## SM Assessment

Story 47-1 is ready for implementation. This is a 2-point trivial story — analysis of existing data, no new pipeline runs needed. All context files are in place. The dpgd-116 results are already available in `internal/results/pipeline-replay/`. Dev should classify findings by attribution category across 20 themes and write the analysis document. Signal assessment here gates the rest of the epic.

## Dev Assessment (revision 2)

**Implementation Complete:** Yes
**Files Changed:**
- `internal/results/cascade-attribution-dpgd-116.md` - Full cascade attribution analysis (7 findings × 19 themes + control)

**Tests:** N/A (analysis document, no code changes)
**Branch:** main (no branch needed — analysis artifact only)

**Reviewer Fixes Applied:**
- [HIGH] Corrected context methodology: all runs included static context docs via `build_phase_claude_md()`. Context-driven attribution is now marked N/A (unmeasurable — context held constant), not 0%.
- [HIGH] Rewrote signal assessment: persona variance = none, context variance = untestable from this data. 47-3/47-4 are critical to generate context variance. 47-6/47-7 gated on 47-5 results.
- [MEDIUM] Removed "Difficulty-gated" category. C1 folded into role-driven with difficulty annotation.

**Key Findings:**
- 0% of catches are persona-driven
- Context-driven attribution is unmeasurable (context was held constant, not varied)
- All detection variance explained by role definition
- Reviewer dominates catches (catches findings assigned to TEA and Dev)
- Control (no theme) performs at or above themed mean
- 47-3/47-4 are critical — they generate the context variance this data lacks

**Handoff:** Back to review

## Delivery Findings

### Dev (implementation)

- **Improvement** (non-blocking): I5 and I6 (`phase_ideal: tea`) are caught exclusively by Reviewer (0 TEA catches). Suggests TEA agent definition needs a "review your own test quality" checklist item. Affects `pennyfarthing-dist/agents/tea.md` (add self-review gate for test assertions).
- **Question** (non-blocking): The comparison.yaml only covers 14 of 19 themes — 5 themes (alice-in-wonderland, enlightenment-thinkers, snow-crash, star-trek-tng, star-trek-tos) were missing. Their data exists in individual score.yaml files. Should comparison.yaml be regenerated? Affects `internal/results/pipeline-replay/dpgd-116/comparison.yaml` (incomplete theme coverage).

### Reviewer (code review)

- **Gap** (blocking): Analysis incorrectly claims "dpgd-116 runs used no upstream context documents" and classifies 0% as context-driven. In fact, `build_phase_claude_md()` in `pipeline_replay.py` reads epic and story context docs and bakes them into every agent's CLAUDE.md for every run. The same static context docs were used across all themes — meaning context was *held constant*, not absent. The analysis cannot classify "context-driven" as 0% because there is no variance in the independent variable. Affects `internal/results/cascade-attribution-dpgd-116.md` (factual error in methodology and conclusions).
- **Gap** (blocking): Signal assessment conclusion is undermined by the context misunderstanding. The document says context ablation (47-6) and A/B pipeline (47-7) are "premature" because "dpgd-116 shows no persona effect at the pipeline level." The correct framing: dpgd-116 shows no *persona* effect, but says nothing about *context* effect because context was not varied. Stories 47-3/47-4 generate different context docs per persona — the whole point is to test whether different upstream context changes downstream detection. The signal assessment must be rewritten with this understanding.
- **Improvement** (non-blocking): The "Difficulty-gated" category in the Attribution Summary (C1, 24% weight) is not a real attribution category — it's an observation about catch rate. C1 is role-driven like the others (caught by reviewer and tea when caught at all), just harder to detect. Simplify to role-driven with a difficulty note.

## Reviewer Assessment (round 1)

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Factual error: claims runs had no upstream context docs; they did (same static docs for all themes) | cascade-attribution-dpgd-116.md:148, methodology notes | Correct to state context was held constant, not absent. Remove "context-driven: 0%" claim — cannot measure what wasn't varied. |
| [HIGH] | Signal assessment draws wrong conclusion from context misunderstanding — says 47-6/47-7 premature because "no persona effect" but the question is about context effect, which this data cannot answer | cascade-attribution-dpgd-116.md:144-160 | Rewrite signal assessment: persona variance = no, context variance = untestable from this data, 47-3/47-4 still critical to generate the variance needed |
| [MEDIUM] | "Difficulty-gated" is not a real attribution category | cascade-attribution-dpgd-116.md:108 | Fold C1 into role-driven with difficulty annotation |

**Handoff:** Back to Dev for fixes

## Reviewer Assessment (round 2)

**Verdict:** APPROVED

**Fixes verified:**
- [HIGH] Context methodology: Line 12 now states "context was held constant across themes, not absent." Line 108 marks context-driven as "N/A." Line 175 documents `build_phase_claude_md()`. **Fixed.**
- [HIGH] Signal assessment: Lines 146-150 cleanly separate persona=NO from context=UNKNOWN. Lines 154-160 correctly frame 47-3/47-4 as critical and gate 47-6/47-7 on 47-5. **Fixed.**
- [MEDIUM] Difficulty-gated category removed. C1 at line 57 is now "Role-driven (low catch rate due to difficulty)." Attribution summary at line 106 shows 100% role-driven. **Fixed.**

**Observations:**
1. [VERIFIED] All three blocking findings resolved — context claim corrected, signal assessment rewritten, category simplified
2. [VERIFIED] Raw heatmap data unchanged — only interpretation was revised
3. [VERIFIED] `build_phase_claude_md()` correctly referenced at lines 12, 154, 175
4. [LOW] "Code-obvious" still defined in Attribution Categories table (line 20) but never used in the summary — vestigial definition, not blocking
5. [VERIFIED] Recommendation correctly identifies the epic's core question as context variance, not persona variance

**Handoff:** To Leo McGarry for finish-story

### Reviewer (re-review)

- No additional upstream findings during re-review. All prior findings addressed.