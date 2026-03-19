---
story_id: "150-3"
jira_key: "MSSCI-16604"
epic: "MSSCI-16564"
workflow: "tdd"
---
# Story 150-3: Internal spec-drift pre-check during review phase

## Story Details
- **ID:** 150-3
- **Jira Key:** MSSCI-16604
- **Epic:** MSSCI-16564 (Epic 150)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** green
**Phase Started:** 2026-03-19T10:43:27Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-19T00:00:00Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No upstream findings during RED phase.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

## TEA Assessment

**Test Strategy:** RED phase — wrote 53 tests (37 failing, 16 passing) across 10 test classes.

**Files Created:**
- `tests/python/test_150_3_spec_drift_precheck.py` — comprehensive test suite
- `pennyfarthing-dist/src/pf/gates/spec_drift_precheck.py` — stub module (returns wrong results)

**Test Classes (mapped to ACs):**
1. `TestGateFileFormat` (AC-1) — gate file exists and follows gate-schema.md format (7 tests)
2. `TestModuleExists` (AC-2) — Python module exists with correct function signature (5 tests)
3. `TestNoDriftDetected` (AC-3) — returns success when no drift (8 tests)
4. `TestDetectsMissingACCoverage` (AC-4) — detects missing AC coverage (6 tests)
5. `TestDetectsMalformedDeviations` (AC-5) — detects malformed/incomplete deviations (4 tests)
6. `TestDetectsScopeCreep` (AC-6) — detects files not traceable to ACs (4 tests)
7. `TestFlagsMajorDeviations` (AC-7) — flags major/breaking deviations (3 tests)
8. `TestFindingsFormat` (AC-8) — findings have category, severity, detail (4 tests)
9. `TestDriftScore` (AC-9) — drift_score reflects aggregate severity (5 tests)
10. `TestNeverThrows` (AC-10) — return-results pattern, never throws (7 tests)

**RED Phase Result:** 37 FAILED, 16 PASSED — proper RED state confirmed.