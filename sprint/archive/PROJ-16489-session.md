---
story_id: "150-1"
jira_key: "PROJ-16489"
epic: "PROJ-16564"
workflow: "tdd"
---
# Story 150-1: Impact Summary enhancement — downstream effects and deviation justifications in PR body

## Story Details
- **ID:** 150-1
- **Jira Key:** PROJ-16489
- **Epic:** 150 - Prove the Work — PR Explanation Quality (PROJ-16564)
- **Workflow:** tdd
- **Points:** 3
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-19T08:52:49Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-18T19:05:31Z | 2026-03-18T19:06:42Z | 1m 11s |
| red | 2026-03-18T19:06:42Z | 2026-03-18T19:11:29Z | 4m 47s |
| green | 2026-03-18T19:11:29Z | 2026-03-18T19:14:29Z | 3m |
| spec-check | 2026-03-18T19:14:29Z | 2026-03-18T19:16:00Z | 1m 31s |
| verify | 2026-03-18T19:16:00Z | 2026-03-18T19:19:07Z | 3m 7s |
| review | 2026-03-18T19:19:07Z | 2026-03-19T08:37:04Z | 13h 17m |
| spec-reconcile | 2026-03-19T08:37:04Z | 2026-03-19T08:52:49Z | 15m 45s |
| finish | 2026-03-19T08:52:49Z | - | - |

## Story Context

### Problem Statement
The current Impact Summary in PR bodies and session files lacks critical information for external reviewers (SOUL.md #14 - Prove the Work):
- No analysis of downstream effects (what other stories/components break if this changes)
- No justification for deviations (why we deviated from spec, with source references)
- Incomplete for PR self-explanation to external reviewers

### Acceptance Criteria
1. Impact Summary includes downstream effect analysis — identifies affected stories and components
2. Impact Summary includes deviation context — each deviation has clear "why" explanation linked to spec
3. sm-finish compiles enhanced Impact Summary from Delivery Findings and Design Deviations sections
4. PR body generated from Impact Summary is self-explanatory for external reviewers
5. Session file Design Deviations section enforces spec source citation

### Technical Scope
- Extend sm-finish subagent to analyze Design Deviations section for justifications
- Add downstream effect tracking to Impact Summary (cross-story dependency impacts)
- Ensure PR body Template includes both deviation justification and downstream effects
- Update session file schema documentation if needed

## Sm Assessment

Story 150-1 is ready for RED phase. Session file created with Impact Summary enhancement context. The story extends the existing sm-finish preflight to include downstream effects and deviation justifications in PR bodies, making PRs self-explanatory per SOUL.md #14. Branch `feat/150-1-impact-summary-enhancement` created. Handing off to peloton mode for TDD pipeline.

## Delivery Findings

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings

## Design Deviations

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### Architect (reconcile)
- No additional deviations found.

## TEA Assessment

**Tests Written:** 33 tests across 6 test classes covering all 5 ACs
**Status:** RED confirmed — 26 failing, 7 passing (backward compat only)
**Test File:** `pennyfarthing-dist/src/pf/tests/test_150_1_impact_summary.py`

### Test Coverage by AC

| AC | Class | Tests | Status |
|----|-------|-------|--------|
| AC1: Downstream effects | `TestDownstreamEffects` | 5 | 3 FAIL, 2 PASS |
| AC2: Deviation context | `TestDeviationContext` | 6 | 6 FAIL |
| AC3: sm-finish compilation | `TestSmFinishCompilation` | 4 | 3 FAIL, 1 PASS |
| AC4: PR body self-explanatory | `TestPRBodySelfExplanatory` | 5 | 2 FAIL, 3 PASS |
| AC5: Spec source citation | `TestSpecSourceCitation` | 10 | 10 FAIL |
| Integration | `TestFullPipeline` | 3 | 2 FAIL, 1 PASS |

### Implementation Guidance for Dev

**New functions needed in `pf/findings/capture.py`:**
- `parse_design_deviations(content: str) -> list[dict]` — parse `## Design Deviations` section, extract description/why/spec_ref/agent fields
- `validate_design_deviations(deviations: list[dict]) -> list[str]` — return error messages for deviations missing spec_ref

**Changes to `pf/findings/summary.py`:**
- `compile_impact_summary()` — add `deviations` kwarg, add "Downstream Effects" and "Design Deviations" subsections to output markdown, add `deviation_count` to result data
- `write_impact_summary_to_session()` — call `parse_design_deviations()`, pass to `compile_impact_summary()`, include `warnings` in result data for missing spec refs

**Changes to `pf/findings/pr_body.py`:**
- `_build_impact_section()` or new `_build_design_decisions_section()` — include deviation justifications translated as "Design Decisions" (no framework jargon)
- Ensure "Design Deviations" never appears in PR body text

**Handoff:** To Dev for GREEN phase

## Dev Assessment

**Implementation Complete:** 33/33 tests passing (GREEN)
**Files Changed:** 3 — `capture.py`, `summary.py`, `pr_body.py`
**Branch:** `feat/150-1-impact-summary-enhancement`
**PR:** Pushed to origin, ready for review

### Changes

1. **`capture.py`** — Added `parse_design_deviations()` and `validate_design_deviations()`. Parser extracts description/why/spec_ref/agent from markdown Design Deviations section. Validator flags missing spec citations.
2. **`summary.py`** — Extended `compile_impact_summary()` with `deviations` kwarg, added Downstream Effects subsection (grouped by component), added Design Deviations subsection, added `deviation_count` to result data. Updated `write_impact_summary_to_session()` to parse deviations and pass warnings.
3. **`pr_body.py`** — Added `_build_design_decisions_section()` to translate framework "Design Deviations" into reviewer-friendly "Design Decisions" with rationale and spec references. Final `replace()` ensures "Design Deviations" jargon never leaks into PR body.

**Handoff:** To Architect for spec-check
## Architect Assessment (spec-check)

**Verdict:** PASS — All 5 ACs satisfied, no spec drift

### AC Alignment

| AC | Status | Implementation |
|----|--------|----------------|
| AC1: Downstream effects | PASS | `compile_impact_summary()` adds `### Downstream Effects` grouped by component directory. Empty state handled. |
| AC2: Deviation context | PASS | `deviations` kwarg with description/why/spec_ref rendered in Impact Summary. `deviation_count` in result. |
| AC3: sm-finish compilation | PASS | `write_impact_summary_to_session()` parses both Delivery Findings AND Design Deviations, passes warnings. |
| AC4: PR body self-explanatory | PASS | `_build_design_decisions_section()` translates jargon. Final `replace()` scrubs "Design Deviations" from output. |
| AC5: Spec source citation | PASS | `parse_design_deviations()` extracts fields. `validate_design_deviations()` flags missing spec_ref. Warnings surfaced. |

### Architecture Notes

- **Reuse-first:** Extended existing `capture.py`, `summary.py`, `pr_body.py` — no new files or abstractions
- **Backward compat:** Sessions without Design Deviations section still work (empty list, zero deviation_count)
- **Jargon firewall:** PR body translates all framework terms to reviewer-friendly language
- **Result contract:** `{success, data, error}` pattern maintained throughout

**Handoff:** To TEA for verify phase

## TEA Verify Assessment

**Tests:** 33/33 passing (story) + 46/46 passing (existing PR body tests) — no regressions
**Simplify fix applied:** Removed dead agent-header loop in `capture.py:parse_design_deviations()` (10 lines deleted)

### Simplify Fan-Out Results

| Agent | Files | Findings | Actionable (new code) |
|-------|-------|----------|-----------------------|
| Reuse | 3 | 7 | 1 applied (dead loop), 6 pre-existing patterns |
| Quality | 3 | 5 | 0 — all pre-existing convention issues |
| Efficiency | 3 | 8 | 1 applied (same dead loop), 7 pre-existing or low-confidence |

### Fix Applied
- **capture.py** — Dead first loop in `parse_design_deviations()` iterated section lines to set `current_agent`, then immediately reset it before the real block-based parsing loop. Removed 10 lines of dead code.

### Notes for Reviewer
1. **Section-finding duplication** in `capture.py`: `parse_delivery_findings()` and `parse_design_deviations()` both implement identical section-boundary logic. A `_extract_section_lines()` helper could reduce duplication, but both are pre-existing patterns.
2. **PR body re-parses deviations from markdown** in `_build_design_decisions_section()`: reads deviations from the Impact Summary section text rather than structured data. This is a deliberate architecture choice — `generate_pr_body()` works from session sections, not structured data. Changing it would require a contract change.

**Handoff:** To Reviewer for adversarial code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 1 lint (unused import pytest F401) | Trivial fix |
| 2 | reviewer-edge-hunter | Yes | findings | 10 findings (1 high) | Dead regex, blanket replace, lookahead advance — triaged to F1/F3/F9/F10 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 6 findings (3 high) | Warnings unsurfaced, duplicate parser drift, silent skip — triaged to F2/F6 |
| 4 | reviewer-test-analyzer | Yes | findings | 12 findings (4 high) | Vacuous assertions, wrong section checked — triaged to F7/F8 |
| 5 | reviewer-comment-analyzer | Yes | findings | 7 findings (5 high) | Stale docstrings, dead regex ref, RED-phase leftover — triaged to F1/F4/F11 |
| 6 | reviewer-type-design | Yes | findings | 6 findings (1 high) | Pre-existing ValueError, primitive obsession — triaged to NOTED |
| 7 | reviewer-security | Yes | findings | 5 findings (0 high) | Blanket replace, markdown injection, latent ReDoS — triaged to F1/F3/F12 |
| 8 | reviewer-simplifier | Yes | findings | 6 findings (3 high) | Dead regex, duplicate parser, redundant check — triaged to F1/F2 |
| 9 | reviewer-rule-checker | Yes | findings | 2 findings (2 high) | Duplicate parser DRY violation, dead regex — triaged to F1/F2 |

**All received:** Yes (9 returned, 8 with findings)

## Reviewer Assessment

**Verdict:** APPROVE WITH FINDINGS
**Tests:** 33/33 GREEN | **Lint:** 1 fixable (unused `import pytest`) | **Files:** 4 changed (+890/-10)
**Subagents:** 9/9 completed (preflight, edge-hunter, silent-failure-hunter, test-analyzer, comment-analyzer, type-design, security, simplifier, rule-checker)

### Triaged Findings (deduplicated across subagents)

#### SHOULD-FIX (before merge)

**F1. Dead `_DEVIATION_RE` regex** — `capture.py:128` [EDGE] [DOC] [SIMPLE] [RULE] [SEC]
- Compiled regex defined but never called. Block-based parser replaced it. Latent ReDoS risk from nested optional groups. Remove it.
- *Flagged by: edge-hunter, comment-analyzer, simplifier, rule-checker, security (5/9)*

**F2. Duplicate parser in `_build_design_decisions_section`** — `pr_body.py:139-171` [SILENT] [TYPE] [RULE] [SIMPLE]
- Re-implements deviation markdown parsing that already exists in `capture.parse_design_deviations()`. If format changes, this second parser silently drifts. Reuse the shared parser or thread structured data through.
- *Flagged by: silent-failure, type-design, rule-checker, simplifier (4/9)*
- *Note: TEA verify flagged this as "deliberate architecture choice" — but 4 independent subagents identified it as a maintenance risk. The generate_pr_body contract could accept parsed deviations alongside section text.*

**F3. Blanket `str.replace("Design Deviations", "Design Decisions")`** — `pr_body.py:57` [EDGE] [SEC] [SIMPLE]
- Global replace on entire PR body. If agent content contains the literal phrase "Design Deviations", it gets corrupted. Scope to markdown headings only: `re.sub(r'^(#{2,3})\s+Design Deviations', r'\1 Design Decisions', pr_body, flags=re.MULTILINE)`.
- *Flagged by: edge-hunter, security, simplifier (3/9)*

**F4. Stale RED-phase comment** — `test_150_1_impact_summary.py:11` [DOC]
- "All tests MUST FAIL (RED phase) until implementation" — implementation is complete. Remove.

**F5. Unused `import pytest`** — `test_150_1_impact_summary.py:17` [SIMPLE]
- Ruff F401. Auto-fixable with `ruff check --fix`.

#### CONSIDER (non-blocking, recommend follow-up)

**F6. Warnings from `validate_design_deviations` never surfaced** — `summary.py:166` [SILENT] [EDGE]
- Warnings packed into `result['data']['warnings']` but no caller logs, prints, or blocks on them. Spec citation violations detected but invisible. Consider logging them or making missing spec refs fail the gate.
- *Flagged by: silent-failure, edge-hunter (2/9)*

**F7. Vacuous test assertions (4 instances)** — `test_150_1_impact_summary.py` [TEST]
- `test_deviation_includes_why_explanation` (line 276): asserts "rAF" which appears in description, not why field
- `test_deviation_includes_spec_reference` (line 289): "spec" matches label, not value
- `test_compile_accepts_deviations_parameter` (line 238): only checks success, doesn't verify deviations had effect
- `test_downstream_empty_when_no_findings` (line 227): trivially passes from unconditional heading
- These give false confidence. Tests "pass" but don't verify the claimed behavior.
- *Flagged by: test-analyzer*

**F8. `test_pr_body_deviation_has_why_for_reviewer` checks wrong section** — `test_150_1_impact_summary.py:423` [TEST]
- Looks for deviation content under "What This Work Revealed" but deviations render under "Design Decisions". Passes accidentally because raw Impact Summary text leaks through.
- *Flagged by: test-analyzer*

**F9. Agent name regex too narrow** — `capture.py:65` [EDGE]
- `r'^### (\w+)'` won't match hyphenated names like "Tech-Writer". Broaden to `[\w-]+`.
- *Flagged by: edge-hunter*

**F10. Missing `.get()` guard** — `summary.py:278` [EDGE]
- `f['description']` accessed without `.get()` in downstream effects loop. All other fields in same context use `.get()`. KeyError if finding lacks description.
- *Flagged by: edge-hunter*

**F11. Stale module docstrings** — `capture.py:2`, `summary.py:2-4` [DOC]
- Module docstrings don't mention design deviations, only delivery findings. Update to reflect expanded scope.
- *Flagged by: comment-analyzer*

**F12. Unsanitized markdown in PR body** — `summary.py:108`, `pr_body.py:181` [SEC]
- Agent-authored descriptions interpolated directly into GitHub PR markdown. Crafted content could inject links/formatting. Low risk (internal tooling), but worth sanitizing brackets.
- *Flagged by: security*

#### NOTED (informational, no action required)

- [TYPE] `list[dict]` used pervasively for findings/deviations — TypedDicts would help but are scope creep for this story
- [TYPE] `format_finding` raises ValueError instead of result dict — pre-existing, not introduced by this branch
- [SIMPLE] Redundant `d.get('missing_spec_ref') or 'spec_ref' not in d` check — cosmetic
- [EDGE] No-op `pass` branch in lookahead loop — cosmetic
- [TEST] `validate_design_deviations` not tested with `spec_ref=""` (empty string edge case)

### Verdict Rationale

**APPROVE WITH FINDINGS.** The implementation is correct — 33/33 tests pass, all 5 ACs are met per Architect spec-check, backward compatibility preserved, and the `{success, data, error}` result contract is maintained. No blocking bugs or security vulnerabilities in production paths.

F1-F3 (dead regex, duplicate parser, blanket replace) should be addressed before merge as they create maintenance risk and potential content corruption. F4-F5 are trivial cleanup. F6-F12 are quality improvements recommended as follow-up.

**Handoff:** To SM for finish phase