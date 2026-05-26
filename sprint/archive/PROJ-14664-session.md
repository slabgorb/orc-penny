# Story 90-2: Implement SM confidence gate file

**Jira:** PROJ-14664
**Epic:** 90 — Confidence Circuit Breaker (via Gate)
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/90-2-sm-confidence-gate
**Assignee:** slabgorb@gmail.com

## Acceptance Criteria

1. Gate file `gates/confidence-sm.md` exists in `pennyfarthing-dist/gates/` following the Gate PRD schema
2. Gate has `<gate>`, `<purpose>`, `<pass>`, and `<fail>` blocks
3. Gate checks whether SM agent instruction is ambiguous (vague commands like "continue", "next", "start" without target)
4. `<fail>` block returns clarifying options when instruction is ambiguous
5. `<pass>` block lets the agent proceed when instruction is unambiguous
6. Gate uses `model="haiku"` (per Gate PRD defaults)
7. Gate validates against existing schema (same structure as `gates/tests-pass.md`)

## Technical Context

- Gate PRD: `sprint/planning/gate-prd.md` — full schema specification
- Existing gate: `pennyfarthing-dist/gates/tests-pass.md` — reference implementation
- Gate runner: stories 106-2, 106-4 (already complete)
- Schema: `<gate name="confidence-sm" model="haiku">` with `<purpose>`, `<pass>`, `<fail>`

## Key Files

- `pennyfarthing-dist/gates/confidence-sm.md` — NEW: the gate file to create
- `pennyfarthing-dist/gates/tests-pass.md` — existing gate for schema reference
- `sprint/planning/gate-prd.md` — Gate PRD with full requirements

## TEA Assessment

**Tests Required:** Yes
**Reason:** Gate file is new implementation — needs schema validation, content checks, and discovery tests

**Test Files:**
- `pennyfarthing_scripts/tests/test_confidence_sm_gate.py` — 25 tests covering all 7 ACs

**Tests Written:** 25 tests covering 7 ACs
- AC1 (4 tests): File existence, discovery via resolve_gate_file()
- AC2 (6 tests): Schema structure — gate/purpose/pass/fail tags, parse_gate_file validation
- AC3 (3 tests): Ambiguity detection — purpose references ambiguity, gate name, SM agent reference
- AC4 (3 tests): Fail block — content, clarification options, GATE_RESULT template
- AC5 (3 tests): Pass block — content, proceed indication, GATE_RESULT template
- AC6 (2 tests): Model attribute — parse returns "haiku", gate tag has explicit attribute
- AC7 (4 tests): Schema consistency — required keys, name matches filename, content matches file, GATE_RESULT in both blocks

**Status:** RED (25 failing — 10 assertion failures, 15 fixture errors, all due to missing gate file)
**Commit:** `416f168` on `feature/90-2-sm-confidence-gate`

**Handoff:** To Jack Torrance (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/gates/confidence-sm.md` — SM confidence gate file (71 lines)

**Tests:** 25/25 passing (GREEN)
**PR:** #914 — feat(90-2): SM confidence gate file
**Branch:** feature/90-2-sm-confidence-gate (pushed)

**Self-Review:**
- [x] Gate follows tests-pass.md schema pattern
- [x] All 7 acceptance criteria met
- [x] Tests passing (not skipped)
- [x] No debug artifacts
- [x] model="haiku" explicitly set

**Handoff:** To Roland Deschain (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #914 — feat(90-2): SM confidence gate file

**Review Summary:**
- [x] Schema compliance — gate structure matches tests-pass.md reference pattern
- [x] GATE_RESULT contract — both pass/fail blocks include valid YAML templates with correct status
- [x] Ambiguity categories — three clear failure modes (missing target, ambiguous scope, multiple interpretations) with actionable recovery options
- [x] No forbidden patterns — no debug artifacts, secrets, or test pollution
- [x] Data flow — gate_file.py discovery → parse_gate_file extraction → content integrity verified
- [x] All 25 tests GREEN (0 skipped)

**Observations:**
- AC3 test `test_content_references_sm_agent` uses loose match for `"sm "` (trailing space) — functional but could false-match. Not blocking.
- Gate file is clean, well-structured, follows PRD conventions precisely.

**Handoff:** To SM for story completion

## Handoff History

| Timestamp | From | To | Notes |
|-----------|------|----|-------|
| 2026-02-15T14:36:27Z | user | sm | Story setup initiated |
| 2026-02-15T14:40:00Z | sm | tea | TDD red phase — write failing tests |
| 2026-02-15T14:42:00Z | tea | dev | 25 tests RED, ready for implementation |
| 2026-02-15T14:46:00Z | dev | reviewer | 25/25 GREEN, PR #914 created |
| 2026-02-15T15:00:00Z | reviewer | sm | APPROVED, PR #914 merged |