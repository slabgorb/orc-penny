---
story_id: "144-1"
jira_key: "PROJ-16385"
epic: "PROJ-16384"
workflow: "tdd"
---

# Story 144-1: Deviation format spec and gate validation upgrade

## Story Details

- **ID:** 144-1
- **Jira Key:** PROJ-16385
- **Epic:** PROJ-16384 (Specification Fidelity Gates)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-12T23:37:53Z

### Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-12T23:23:47Z | 2026-03-12T23:24:40Z | 53s |
| red | 2026-03-12T23:24:40Z | 2026-03-12T23:30:02Z | 5m 22s |
| green | 2026-03-12T23:30:02Z | 2026-03-12T23:36:03Z | 6m 1s |
| verify | 2026-03-12T23:36:03Z | 2026-03-12T23:36:47Z | 44s |
| review | 2026-03-12T23:36:47Z | 2026-03-12T23:37:53Z | 1m 6s |
| finish | 2026-03-12T23:37:53Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No upstream findings during test design.

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

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** https://github.com/slabgorb/pennyfarthing/pull/1362 (squash-merge auto-enabled)

**Findings:** None blocking. One minor observation: `_ENTRY_NO_BOLD_RE` regex defined but its branch in `_parse_entries` is unreachable (dead code). Harmless — not worth a fix cycle.

**AC Coverage:** All 7 ACs verified through 56 passing tests. Implementation follows existing `findings.py` pattern. Gate upgrade preserves XML structure per gate-schema.md.

**Handoff:** To The Mad Hatter (SM) for finish

## TEA Verify Assessment

**Phase:** finish
**Status:** GREEN confirmed — 56/56 tests passing

### Simplify Report

**Files Analyzed:** 1 code file (deviations.py), 2 markdown (guide + gate), 1 test file
**Teammates:** skipped — single small Python module, no duplication or complexity concerns

**Overall:** simplify: clean

**Quality Checks:** All passing (56/56 tests, 0.05s)
**Handoff:** To The Queen of Hearts (Reviewer) for code review

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/guides/deviation-format.md` — new guide with 6-field format spec, agent subsections, worked examples
- `pennyfarthing-dist/src/pf/gates/deviations.py` — validate_deviations() with section/subsection parsing, field validation
- `pennyfarthing-dist/gates/deviations-logged.md` — upgraded from existence check to 6-field format validation

**Tests:** 56/56 passing (GREEN)
**Branch:** feat/144-1-deviation-format-spec-gate-validation (pushed)

**Handoff:** To TEA for verify phase

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story delivers a new guide file and a Python validation function — both require test coverage.

**Test Files:**
- `tests/python/test_deviations_gate.py` — 56 tests covering all 7 ACs
- `pennyfarthing-dist/src/pf/gates/deviations.py` — stub module (compiles, returns wrong results)

**Tests Written:** 56 tests covering 7 ACs
**Status:** RED (42 failing, 14 passing — failures are assertion errors, not import errors)

**AC Coverage:**
| AC | Tests | What They Verify |
|----|-------|------------------|
| AC-1 | 11 | Guide file exists, contains all 6 field names, worked example, enum values |
| AC-2 | 5 | Guide contains 3 agent subsection headings under ## Design Deviations |
| AC-3 | 7 | Valid entries pass for tea/dev/architect, field order independence, whitespace tolerance |
| AC-4 | 7 | Missing fields produce entry-specific recovery messages with field list |
| AC-5 | 6 | "No deviations from spec." passes, empty subsection fails, phrase doesn't suppress validation |
| AC-6 | 6 | Absent section produces distinct message, section vs subsection failures differ |
| AC-7 | 4 | Repeated runs produce identical results, no file modifications or side effects |
| Edge | 10 | File not found, section boundaries, HTML comments, severity/impact enum validation |

**Handoff:** To The White Rabbit (Dev) for implementation

## SM Assessment

**Story:** 144-1 — Deviation format spec and gate validation upgrade
**Workflow:** TDD (phased) — routing to TEA for red phase
**Branch:** `feat/144-1-deviation-format-spec-gate-validation` (pennyfarthing repo)
**Jira:** PROJ-16385 claimed

This is the foundation story for Epic 144 (Specification Fidelity Gates). It defines the deviation format spec and upgrades gate validation. Stories 144-2 and 144-3 depend on the format established here. TEA should design tests that validate the deviation format structure and gate enforcement.