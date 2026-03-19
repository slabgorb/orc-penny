---
story_id: "150-5"
jira_key: "MSSCI-16606"
epic: "MSSCI-16564"
workflow: "tdd"
---
# Story 150-5: Configurable drift tolerance — adjustable threshold for acceptable vs flagged deviations

## Story Details
- **ID:** 150-5
- **Jira Key:** MSSCI-16606
- **Epic:** MSSCI-16564 (Epic 150)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-19T15:39:34Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-19T15:32:08Z | 2026-03-19T15:32:54Z | 46s |
| red | 2026-03-19T15:32:54Z | 2026-03-19T15:34:54Z | 2m |
| green | 2026-03-19T15:34:54Z | 2026-03-19T15:36:35Z | 1m 41s |
| spec-check | 2026-03-19T15:36:35Z | 2026-03-19T15:36:51Z | 16s |
| verify | 2026-03-19T15:36:51Z | 2026-03-19T15:37:15Z | 24s |
| review | 2026-03-19T15:37:15Z | 2026-03-19T15:39:28Z | 2m 13s |
| spec-reconcile | 2026-03-19T15:39:28Z | 2026-03-19T15:39:34Z | 6s |
| finish | 2026-03-19T15:39:34Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings during implementation.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### Architect (reconcile)
- No additional deviations found.

## Subagent Results

| Subagent | Received | Status | Findings | Decision |
|----------|----------|--------|----------|----------|
| reviewer-preflight | Yes | clean | none | N/A |
| reviewer-edge-hunter | Yes | findings | 7 (4H/2M/1L) | dismissed — config comes from trusted YAML |
| reviewer-silent-failure-hunter | Yes | findings | 4 (1H/2M/1L) | dismissed — intentional defaults fallback |
| reviewer-test-analyzer | Yes | findings | 19 (6H/8M/5L) | 1 confirmed, 18 dismissed |
| reviewer-comment-analyzer | Yes | findings | 2 (1H/1M) | 1 confirmed — dead findings param |
| reviewer-type-design | Yes | findings | 8 (3H/3M/2L) | deferred — matches pf.gates pattern |
| reviewer-security | Yes | findings | 4 (1H/3M) | dismissed — internal tool, trusted config |
| reviewer-simplifier | Yes | findings | 8 (2H/3M/3L) | 1 confirmed — dead findings param |
| reviewer-rule-checker | Yes | findings | 1 (1H) | dismissed — intentional graceful fallback |

**All received:** Yes

## Reviewer Assessment

**Verdict: APPROVED**

### Confirmed Findings (non-blocking)

1. **[DOC][SIMPLE] evaluate_drift() has unused `findings` parameter** (medium) — Documented, accepted in signature, but never referenced in function body. Dead code. Non-blocking: callers pass it but it's harmless.

2. **[TEST] Missing boundary tests for threshold equality** (low) — Tests check `score > threshold` but not `score == threshold`. Non-blocking: logic is correct for strict inequality.

3. **[EDGE] No validation that fail_threshold >= warn_threshold** (low) — Config from trusted YAML; inverted thresholds are a misconfiguration, not a security issue.

### Dismissed Findings

- **[TYPE] All-dict API with no TypedDicts** — Matches existing `pf.gates` pattern. Deferred.
- **[SEC] Info leakage / threshold inversion** — Internal framework tool, config from trusted YAML.
- **[SILENT] Broad exception in load_drift_config** — Intentional: graceful fallback to defaults is the design.
- **[RULE] Bare except swallowing errors** — Same as above; intentional per return-results pattern.
- **[TEST] Vacuous import assertions / copy-paste config** — TEA style; non-blocking.

## Sm Assessment

**Status:** Setup complete. Session file created, branch `feat/150-5-drift-tolerance` created from develop. Jira MSSCI-16606 claimed. Ready for RED phase.

## Tea Assessment

**Status:** RED — 21 failed, 15 passed (36 total tests)

**Test file:** `tests/python/test_150_5_drift_tolerance.py`
**Stub module:** `pennyfarthing-dist/src/pf/gates/drift_tolerance.py`

**Test coverage (6 ACs):**
- AC-1: `load_drift_config()` — reads tolerance from config YAML, defaults when missing (8 tests)
- AC-2: `evaluate_drift()` — applies thresholds for pass/warn/fail status (8 tests)
- AC-3: `DEFAULT_CONFIG` constant — sensible defaults for all fields (6 tests)
- AC-4: `calculate_weighted_score()` — configurable severity weights (7 tests)
- AC-5: Zero-tolerance mode — fails on any findings (3 tests)
- AC-6: Never throws — return-results pattern on all functions (4 tests)

**No design deviations.**

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/gates/drift_tolerance.py` — full implementation of load_drift_config(), evaluate_drift(), calculate_weighted_score()

**Tests:** 36/36 passing (GREEN)
**Branch:** feat/150-5-drift-tolerance (pushed)

**AC Coverage:**
- AC-1: load_drift_config() reads YAML, merges with defaults — DONE
- AC-2: evaluate_drift() applies pass/warn/fail thresholds — DONE
- AC-3: DEFAULT_CONFIG with sensible defaults — DONE
- AC-4: calculate_weighted_score() with configurable weights — DONE
- AC-5: Zero-tolerance mode works correctly — DONE
- AC-6: All functions follow return-results pattern — DONE

**Handoff:** To Architect for spec-check

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

Clean 2-point implementation. Loads config from YAML, applies thresholds, uses configurable weights. Delegates nothing — standalone utility module. All 6 ACs met and tested. No scope creep.

**Decision:** Proceed to verify

## Tea Assessment (verify)

**Verification:** PASSED — 36/36 tests passing. All RED-phase tests confirmed GREEN. No regressions.