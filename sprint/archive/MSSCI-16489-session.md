---
story_id: "150-1"
jira_key: "MSSCI-16489"
epic: null
workflow: "tdd"
---
# Story 150-1: Impact Summary enhancement — downstream effects and deviation justifications in PR body

## Story Details
- **ID:** 150-1
- **Jira Key:** MSSCI-16489
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 3

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-23T09:30:04Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-23T00:00:00Z | 2026-03-23T09:01:59Z | 9h 1m |
| red | 2026-03-23T09:01:59Z | 2026-03-23T09:10:51Z | 8m 52s |
| green | 2026-03-23T09:10:51Z | 2026-03-23T09:21:12Z | 10m 21s |
| spec-check | 2026-03-23T09:21:12Z | 2026-03-23T09:22:40Z | 1m 28s |
| verify | 2026-03-23T09:22:40Z | 2026-03-23T09:24:59Z | 2m 19s |
| review | 2026-03-23T09:24:59Z | 2026-03-23T09:29:11Z | 4m 12s |
| spec-reconcile | 2026-03-23T09:29:11Z | 2026-03-23T09:30:04Z | 53s |
| finish | 2026-03-23T09:30:04Z | - | - |

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

### Reviewer (code review)
- No upstream findings during code review.

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found. TEA and Dev both logged "No deviations from spec" — confirmed accurate. Implementation matches story ACs without spec drift.

### Architect (reconcile)
- No additional deviations found. All three ACs (downstream effects section, deviation justifications from session, PR body suitability) are implemented as specified. TEA and Dev deviation entries verified accurate — no missed deviations, no spec drift. Sibling story boundaries (150-2 through 150-5) confirmed clean by spec-check phase.

## Sm Assessment

**Story:** 150-1 — Impact Summary enhancement — downstream effects and deviation justifications in PR body
**Workflow:** tdd (phased) → red phase routes to TEA (the Caterpillar)
**Branch:** `feat/150-1-impact-summary-enhancement` on pennyfarthing repo (targets develop)
**Jira:** MSSCI-16489 — assigned to Keith Avery, claimed

### Context
This is the keystone story of epic 150 "Prove the Work — PR Explanation Quality" (SOUL.md principle #14). The goal is to enhance the Impact Summary that appears in PR bodies to include:
- Downstream effect analysis (what does this change affect beyond the immediate files?)
- Spec deviation justifications (why did we deviate, linked to session Delivery Findings)
- Clear explanations so the external reviewer doesn't have to reverse-engineer intent

### Routing
3-point TDD story → TEA writes failing tests first (red phase), then Dev implements (green phase), then Reviewer reviews.

### Acceptance Criteria (from sprint YAML)
TEA should consult the story definition in sprint YAML and the epic context for full ACs. Key areas:
- Impact Summary includes downstream effects section
- Deviation justifications are pulled from session file
- Output is suitable for PR body inclusion

**Handoff to:** TEA (the Caterpillar) for red phase

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core enhancement to compile_impact_summary() and write_impact_summary_to_session() — needs comprehensive test coverage for new downstream effects and deviation justification features.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_150_1_impact_summary_enhancement.py` — 50 tests covering 6 ACs + lang-review rules + section ordering

**Tests Written:** 50 tests covering 6 ACs
**Status:** RED (39 failing, 11 passing backward-compat)

### AC Coverage

| AC | Description | Tests | Status |
|----|-------------|-------|--------|
| AC1 | Downstream effects analysis | 8 tests | failing |
| AC2 | Deviation justifications | 9 tests | failing |
| AC3 | Enhanced write reads deviations | 9 tests | failing |
| AC4 | Backward compatibility | 7 tests | 4 passing, 3 failing |
| AC5 | Edge cases | 6 tests | failing |
| AC6 | Return shape pattern | 5 tests | failing |

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #2 mutable defaults | `test_no_mutable_default_deviations` | failing |
| #3 type annotations | `test_type_annotations_on_compile` | failing |
| #7 resource leaks | `test_tempfile_cleanup_in_write` | passing |

**Rules checked:** 3 of 13 applicable Python lang-review rules have test coverage
**Self-check:** 0 vacuous tests found — all assertions check specific values or structure

### Test Design Notes

**Key API change tested:** `compile_impact_summary(findings, deviations=None)` — optional `deviations` parameter defaults to `None` (not mutable `[]`). When provided, produces `### Downstream Effects` and `### Deviation Justifications` subsections within the Impact Summary.

**Downstream effects structure:** Findings grouped by parent directory of affected path. Each group has module name and finding count. Result data includes `downstream_effects: list[dict]` with `module` and `count` keys.

**Deviation justifications structure:** Each deviation's description, rationale, severity, and forward_impact rendered. Breaking deviations highlighted. Result data includes `deviation_count` and `breaking_deviation_count`.

**Section ordering within Impact Summary:**
1. `**Upstream Effects:**` count line
2. `**Blocking:**` / `**BLOCKING:**` items
3. Individual finding bullets
4. `### Downstream Effects`
5. `### Deviation Justifications` (only when deviations exist)

**Handoff:** To the White Rabbit (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/findings/summary.py` — Added `deviations` parameter to `compile_impact_summary()`, downstream effects grouping by module via `_group_by_module()`, deviation justifications rendering, `_parse_session_deviations()` for reading Design Deviations from session markdown, updated `write_impact_summary_to_session()` to parse and pass deviations, fixed idempotency whitespace normalization

**Tests:** 50/50 passing (GREEN), 113 total with existing suites (0 regressions)
**Branch:** feat/150-1-impact-summary-enhancement (pushed)

**Handoff:** To verify phase (TEA)

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

### Spec Sources Checked
- **Story title:** "Impact Summary enhancement — downstream effects and deviation justifications in PR body"
- **SM Assessment ACs:** downstream effects section, deviation justifications from session, PR body suitability
- **Epic 150 description:** "Improve PR output so external reviewer understands changes without reverse-engineering"

### AC Verification

| AC | Spec | Code | Status |
|----|------|------|--------|
| Downstream effects section | Impact Summary includes downstream effects | `_group_by_module()` groups findings by parent dir, renders `### Downstream Effects` with module counts and cross-cutting label | Aligned |
| Deviation justifications from session | Pull from Design Deviations section | `_parse_session_deviations()` reads deviations, `compile_impact_summary(deviations=...)` renders `### Deviation Justifications` with rationale, severity, forward impact | Aligned |
| PR body suitability | Output suitable for PR body inclusion | Standard markdown `### ` subsections within `## Impact Summary`; `pr_body.py` passes Impact Summary through verbatim — no changes needed there | Aligned |

### Sibling Story Boundary Check
- **150-2** (PR body template generation): Implementation stays in `summary.py`, does not modify `pr_body.py`. Clean boundary.
- **150-4** (Deviation traceability): `_parse_session_deviations()` parses `spec_source`/`spec_text`/`forward_impact` as optional fields. 150-4 would make them required. No conflict.
- **150-5** (Configurable drift tolerance): Not touched. No conflict.

### Architecture Notes
- `deviations` parameter uses `None` default (not mutable `[]`) — correct per Python lang-review rule #2
- `_group_by_module()` uses `PurePosixPath.parent` for module extraction — platform-independent
- Return shape extended with `downstream_effects`, `deviation_count`, `breaking_deviation_count` — backward-compatible (callers that don't read these fields are unaffected)
- Idempotency fix normalizes whitespace around insertion point — prevents blank line accumulation

**Decision:** Proceed to verify

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 2

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | Duplication with pr_body.py (pluralization, breaking counter, prefix, rendering loop, atomic write) |
| simplify-quality | 1 finding | `"error": None` on success inconsistent across module |
| simplify-efficiency | 5 findings | Test consolidation opportunities, whitespace trimming complexity, type annotation meta-test |

**Applied:** 0 high-confidence fixes (all cross-file duplication — scope belongs to future refactoring story, not 150-1)
**Flagged for Review:** 3 medium-confidence findings (deviation rendering duplication with pr_body.py, atomic write pattern, test consolidation)
**Noted:** 3 low-confidence observations (error key style, whitespace regex alternative, type annotation meta-test)
**Reverted:** 0

**Overall:** simplify: clean (no changes applied — findings are cross-file scope, not regressions)

**Quality Checks:** All passing (163 tests across 4 test files, 0 failures)

**Handoff:** To the Queen of Hearts (Reviewer) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 50/50 GREEN, no smells |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 2 | deferred 2 (pre-existing patterns) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (2 returned, 7 disabled via settings)
**Total findings:** 0 confirmed, 0 dismissed, 2 deferred (pre-existing codebase patterns)

### Security Findings (deferred)

1. **[SEC] tempfile cleanup uses except not finally** at summary.py:276-288 — `NamedTemporaryFile(delete=False)` cleanup in `except` block rather than `finally`. If `close()` raises, temp file orphans. However, identical pattern exists in `capture.py:167-181` (pre-existing). Fixing here alone creates inconsistency. **Deferred:** Should be a separate cleanup story across the findings module.

2. **[SEC] read_text()/NamedTemporaryFile without encoding=** at summary.py:249,276 — Omits `encoding='utf-8'`. Could misparse on non-UTF-8 locales. Same pattern in `capture.py:134`. **Deferred:** Pre-existing pattern, should be fixed module-wide.

## Reviewer Assessment

**Verdict:** APPROVED

### Observations

1. [VERIFIED] `compile_impact_summary()` backward compatibility — calling without `deviations` kwarg still works, returns all original fields (`markdown`, `finding_count`, `blocking_count`). New fields (`downstream_effects`, `deviation_count`, `breaking_deviation_count`) are additive. Evidence: summary.py:42-43 defaults `deviations=None`, line 60-61 converts to `[]`. Tests: `TestBackwardCompat` class (7 tests, all passing).

2. [VERIFIED] `_parse_session_deviations()` correctly skips "No deviations from spec" markers — summary.py:174 case-insensitive check `"no deviations from spec" in stripped.lower()`. Prevents false positives. Test: `test_empty_deviations_no_justifications`.

3. [VERIFIED] Mutable default avoided — summary.py:43 uses `deviations: list[dict] | None = None`, not `deviations: list[dict] = []`. Compliant with Python lang-review rule #2. Test: `test_no_mutable_default_deviations`.

4. [VERIFIED] Idempotency — `write_impact_summary_to_session()` called twice produces identical output. Evidence: `_remove_existing_impact_summary()` strips the old section (summary.py:302-325), then `before.rstrip + "\n\n" + summary + "\n\n" + after.lstrip` normalizes whitespace (summary.py:270-273). Test: `test_idempotent_with_deviations`.

5. [VERIFIED] Breaking deviation highlighting — summary.py:108,138 checks `"breaking" in d.get("forward_impact", "").lower()`. Renders `**BREAKING** —` prefix. Test: `test_breaking_deviation_highlighted`, `test_breaking_count_in_data`.

6. [VERIFIED] `_group_by_module()` uses `PurePosixPath` not `Path` — summary.py:30 — platform-independent path parsing for display purposes only, not filesystem access. Correct choice. No rule #5 violation.

7. [VERIFIED] Return shape follows SOUL.md #10 — all functions return `{success, data?, error?}` dicts. New data fields are additive. Evidence: summary.py:151-161 (compile), summary.py:290-298 (write). Tests: `TestReturnShape` class (5 tests).

8. [SEC] tempfile pattern — pre-existing `except` not `finally` pattern (see Security Findings above). Deferred to module-wide cleanup. Not a regression.

9. [SEC] encoding parameter — pre-existing omission of `encoding='utf-8'`. Deferred. Not a regression.

### Rule Compliance

| Rule | Instances Checked | Status |
|------|-------------------|--------|
| #1 Silent exceptions | 1 (except block at :286) | Compliant — returns error result, doesn't swallow |
| #2 Mutable defaults | 1 (`deviations` param) | Compliant — uses None default |
| #3 Type annotations | 3 functions (compile, _group, _parse, write) | Compliant — all annotated |
| #5 Path handling | 2 (read_text, NamedTemporaryFile) | Pre-existing gap — no encoding= (deferred) |
| #7 Resource leaks | 1 (tempfile pattern) | Pre-existing gap — except not finally (deferred) |
| #10 Import hygiene | All imports | Compliant — no star imports, no unused |

### Devil's Advocate

What if `_parse_session_deviations()` encounters malformed markdown — say `- **Unclosed bold` without closing `**`? The regex `r"^- \*\*(.+?)\*\*\s*$"` won't match, so the line is silently skipped. No crash, no partial parse — safe degradation. What about field values containing colons, like `- Rationale: Use f-strings: they're faster`? The regex `r"^- (.+?):\s*(.+)$"` uses non-greedy first capture, correctly matching `Rationale` as key and the full remainder as value. Tested this mentally — correct.

What about `_group_by_module` with a bare filename `file.py` (no directory)? `PurePosixPath("file.py").parent` returns `"."`. Findings group under module `"."` — cosmetically imperfect but not a bug. R1 format findings always have path components from real codebases.

What if `## Impact Summary` appears inside a code block in the session? The removal regex would match it and corrupt the content. But session files are agent-authored markdown — no code blocks contain this heading. Theoretical, not practical.

What about concurrent writes to the session file? Two agents calling `write_impact_summary_to_session()` simultaneously could race. The atomic `replace()` prevents corruption, but the second writer would overwrite the first. In practice, only SM's finish flow calls this function, and it runs sequentially. No real risk.

No devil's advocate findings warrant escalation.

**Data flow traced:** Session markdown content → `_parse_session_deviations()` (regex extraction) → deviation dicts → `compile_impact_summary()` (string formatting) → markdown string → atomic write back to session file. All internal agent-authored content — no external user input in this data path.

**Pattern observed:** Good — follows existing codebase patterns in findings module (result objects, atomic writes, regex parsing). No novel patterns introduced.

**Error handling:** `write_impact_summary_to_session` returns `{success: False, error: str}` on missing file (line 247) and on write failure (line 288). No silent failures.

**Handoff:** To the Mad Hatter (SM) for finish-story