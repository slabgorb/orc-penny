---
story_id: "160-24"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-24: Harden update --epic: uniform result shape + docstring, tighten tests, add edge cases

## Story Details
- **ID:** 160-24
- **Jira Key:** (none)
- **Epic:** 160 - Sprint CRUD & validator hardening (epic 156 follow-ups)
- **Workflow:** tdd
- **Type:** (unspecified)
- **Points:** 2
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-27T11:57:48Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-27T11:26:22Z | 2026-07-27T11:27:26Z | 1m 4s |
| red | 2026-07-27T11:27:26Z | 2026-07-27T11:41:23Z | 13m 57s |
| green | 2026-07-27T11:41:23Z | 2026-07-27T11:45:01Z | 3m 38s |
| review | 2026-07-27T11:45:01Z | 2026-07-27T11:52:41Z | 7m 40s |
| red | 2026-07-27T11:52:41Z | 2026-07-27T11:54:48Z | 2m 7s |
| green | 2026-07-27T11:54:48Z | 2026-07-27T11:56:16Z | 1m 28s |
| review | 2026-07-27T11:56:16Z | 2026-07-27T11:57:48Z | 1m 32s |
| finish | 2026-07-27T11:57:48Z | - | - |

## Sm Assessment

Setup complete for 160-24 (p1, 2 pts, reviewer follow-up from 160-6). Story context at `sprint/context/context-story-160-24.md`; branch `feat/160-24-harden-update-epic-result` created on `pennyfarthing/develop`. Workflow is phased tdd — next agent is TEA for the red phase. Scope: uniform result shape + docstring for `update --epic`, tighter tests, edge cases. No Jira key (local-only story), no stack parent, no blockers. Open PR #51 is sprint bookkeeping awaiting Keith's merge and does not gate this work.

## TEA Assessment

**Tests Required:** Yes
**Reason:** n/a (tdd workflow, behavioral ACs)

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_24_update_epic_result_shape.py` (new) — uniform result shape, docstring contract, same-epic no-op, dry-run+field / empty-epic edge guards
- `pennyfarthing-dist/src/pf/tests/test_160_6_update_epic_delegates_move.py` (edited) — AC2 help-text tightening ("delegates"), AC3 AST call-site delegation check

**Tests Written:** 12 new + 2 tightened, covering all 5 ACs
**Status:** RED (6 failing on AssertionError, 21 passing, 0 errored — verified by scoped direct run AND testing-runner)

RED set (all AssertionError, right-reason verified from failure bodies):
1. `test_update_epic_result_includes_story_id` — epic path returns move shape, no top-level `story_id` (must be `"152-2"`, the new id)
2. `test_update_epic_dry_run_result_includes_story_id` — dry-run epic path missing `story_id`
3. `test_returns_docstring_documents_both_shapes` — Returns: section says only "Dict with success status and optional error"
4. `test_move_story_same_epic_does_not_renumber` — empirically confirmed: `to_epic="151"` renumbers 151-3 → 151-5 and rewrites the sibling's `depends_on`
5. `test_move_story_same_epic_prefixed_form_does_not_renumber` — `to_epic="epic-151"` same bug; forces normalization-aware detection (compare resolved epic dicts, e.g. `target_epic is source_epic`, not raw strings)
6. `test_update_epic_same_epic_does_not_renumber` — same bug through the `update --epic` path; on a success no-op, also pins AC1's `story_id == "151-3"`

Green-on-arrival guards (intentional, see Design Deviations): dry-run+field-flag rejection, empty-string epic (API + CLI), CLI output names real ids (anti-`None` regression), cross-epic move over-reach guard, AST-anchor self-check.

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 silent failure (silent renumber = silently discarded user intent) | `test_move_story_same_epic_does_not_renumber` + prefixed + update-path variants | failing |
| #1 fail-loud on bad input | `test_update_epic_empty_string_fails_loud`, `test_cli_update_epic_empty_string_exits_nonzero` | passing (guard) |
| #6 test quality (vacuous/weak assertions) | AC2/AC3 tightenings in 160-6 file; self-check on own suite | passing |
| SOUL #10 result objects | shape tests assert result dicts, never exceptions | failing (RED 1–2) |

**Rules checked:** 3 of 3 applicable lang-review rules have coverage (#2–#5 target implementation code, none touched this phase)
**Self-check:** 0 vacuous tests found (every test asserts concrete values; both files ruff-clean)

**Handoff:** To Sergeant B.A. Baracus (Dev) for GREEN. Fix shape: add `story_id` to the epic-path result (from `move_result.story.new_id`; keep the `story` details the CLI reads), document both shapes in the Returns docstring, and detect same-epic in `move_story` by comparing RESOLVED epics (the `epic-151` form must be caught), no-op or report — never renumber.

## TEA Assessment (rework r2)

**Tests Required:** Yes (Reviewer rework findings — all testable)
**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_24_update_epic_result_shape.py` (amended, commit 17f7f4fc5) — new `TestSameEpicReportContract` (6 tests) + guard docstring notes + fixture `encoding="utf-8"`

**Status:** RED (2 failing on AssertionError — the same-epic × dry-run carry pair; 16 passing incl. 4 new green-on-arrival mutation guards, 0 errored; ruff clean)

Rework coverage vs Reviewer findings:
- [HIGH] no_op untested → `test_move_story_same_epic_reports_no_op` + `test_update_epic_same_epic_reports_no_op` (green mutation guards — deleting the key now fails 2+ tests)
- [MEDIUM] CLI branches uncovered → `test_cli_move_same_epic_says_nothing_to_move` + `test_cli_update_same_epic_says_nothing_to_move` (exit 0 + message + anti-None; deleting either branch now fails a test)
- [MEDIUM] same-epic × dry-run unspecified → `test_move_story_same_epic_dry_run_carries_flag` + `test_update_epic_same_epic_dry_run_shape` (RED — drive Dev's one-line fix)
- [LOW] docstring notes + fixture encoding → done in this commit; commit-scope hygiene → this commit uses `test(160-24):`

**Handoff:** To Sergeant B.A. Baracus (Dev) for GREEN — thread `"dry_run": dry_run` (or the flag only when True) through `move_story`'s same-epic no-op branch and update its docstring's no-op sentence to mention the carried flag. Nothing else: the other 4 findings are closed by tests alone.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### TEA (test design)
- **Improvement** (non-blocking): `move_story`'s dry-run result carries no `new_id`, so a dry-run preview cannot tell the user what the renumbered id would be; the dry-run shape test deliberately accepts either id — Dev may compute the would-be id for a better preview.
  Affects `pennyfarthing-dist/src/pf/sprint/story_move.py` (dry-run `details` could include a computed `new_id`).
  *Found by TEA during test design.*
- **Gap** (non-blocking): `update_story`'s in-progress auto-assign wraps `subprocess.run(["jira", "me"])` in a bare `except Exception: pass` (lang-review #1 silent swallow) — pre-existing, outside this story's --epic scope.
  Affects `pennyfarthing-dist/src/pf/sprint/story_update.py` (narrow the catch or warn).
  *Found by TEA during test design.*

### TEA (test design, rework r2)
- No upstream findings during rework test design.

### Reviewer (re-review r2)
- No upstream findings during re-review.

### Reviewer (code review)
- **Gap** (non-blocking): `find_epic` resolves epic ids but never jira keys, so `--epic PROJ-17079` (the source epic's jira key) errors "not found" while story ids DO accept jira keys — an input-format asymmetry between the two arguments.
  Affects `pennyfarthing-dist/src/pf/sprint/loader.py` (`find_epic` could match `epic.jira` like `find_story_in_data` does).
  *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the loader's return-live-references invariant is load-bearing for the same-epic identity check but undocumented.
  Affects `pennyfarthing-dist/src/pf/sprint/loader.py` (docstring note on `find_epic`/`find_story_in_data`: returns references into sprint_data, never copies — identity comparisons rely on it).
  *Found by Reviewer during code review.*
- **Improvement** (non-blocking): consider an explicit outcome discriminant (`kind`/`outcome`) for the move/update result union instead of accreting boolean tags (`dry_run`, `no_op`).
  Affects `pennyfarthing-dist/src/pf/sprint/story_move.py` + `story_update.py` (API design, future story).
  *Found by Reviewer during code review.*

### Dev (implementation)
- No upstream findings. (TEA's non-blocking dry-run `new_id` Improvement was deliberately not implemented — minimal-change discipline; it remains open for a future story.)

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

8 deviations

- **Same-epic outcome implemented as success no-op, not rejection**
  - Rationale: The AC permits no-op or report; a success no-op is idempotent (re-running a move command whose state already holds should not error) and satisfies TEA's fix-agnostic tests including the `story_id == "151-3"` pin
  - Severity: minor
  - Forward impact: none — callers checking only `success` see no behavior change for same-epic input
- **CLI no-op rendering added without a pinning test**
  - Rationale: Without it a same-epic invocation would print "Moved story None to epic 151 as None" — the exact regression class TEA's anti-`None` guard catches on the cross-epic path
  - Severity: minor
  - Forward impact: none — output-only; the `no_op` result key is the stable contract
- **Edge-guard tests are green-on-arrival by design**
  - Rationale: Current code already rejects those inputs; the tests pin the behavior so AC1's shape refactor cannot open a dry-run bypass or an empty-target regression
  - Severity: minor
  - Forward impact: Gate/Reviewer must read the 5 passing new tests as intentional guards, not spurious greens
- **AC2/AC3 tightenings are green-on-arrival test-quality changes**
  - Rationale: These ACs upgrade weak assertions, not behavior — the tautological `"epic" in output` and the substring scan could pass on a comment or the flag name alone
  - Severity: minor
  - Forward impact: none — Dev makes no change for AC2/AC3
- **Dry-run story_id value left fix-agnostic**
  - Rationale: `move_story`'s dry-run result computes no `new_id` today, so pinning the new id would dictate extra implementation the AC doesn't require (filed as a non-blocking Improvement finding instead)
  - Severity: minor
  - Forward impact: Dev chooses the dry-run id; either satisfies the suite
- **Rework r2: contract pins are green-on-arrival by design (mutation guards)**
  - Rationale: The Reviewer's findings were coverage holes, not behavior bugs — the correct rework RED pins the shipped contract so mutation can no longer delete it, and leaves genuinely-RED only the unimplemented dry_run carry-through
  - Severity: minor
  - Forward impact: Dev's fix is one line (`"dry_run": dry_run` — or the flag only when True — in move_story's no-op branch); gate must read the 4 passing new tests as intentional
- **Rework r2: dry_run carried as always-present key on the no-op path**
  - Rationale: Reviewer offered two designs; carrying the flag is the one that keeps result["dry_run"] truthful for scripts, and the tests stay agnostic about the False-case representation
  - Severity: minor
  - Forward impact: none — both threading styles satisfy the suite
- **Same-epic outcome left fix-agnostic + prefixed-form variant added beyond the literal AC**
  - Rationale: "no-ops or reports" names two valid designs — pinning one would be TEA invention. The prefixed variant is required because `find_epic` normalizes "epic-151" to the same epic dict, so a naive raw-string compare would pass the plain test yet keep the bug
  - Severity: minor
  - Forward impact: Dev must compare resolved epics (e.g. identity), not raw `to_epic` strings

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_move.py` — same-epic detection by resolved-epic identity (`target_epic is source_epic`, catching the `epic-151` form `find_epic` normalizes) returning `{"success": True, "no_op": True, "story": {...}}` before any mutation; docstring documents the no-op; move CLI renders the no-op case
- `pennyfarthing-dist/src/pf/sprint/story_update.py` — `--epic` path wraps the delegated move result with a top-level `story_id` (`new_id` after a real move, unchanged id for dry-run/no-op); Returns docstring documents both shapes; update CLI renders the no-op case

**Tests:** 100/100 passing (GREEN — verified by testing-runner run `160-24-dev-green`: the 6 RED tests now pass, plus the 160-6, 153-3, 156-3, and story_update regression suites; ruff clean on all four changed files)
**Branch:** feat/160-24-harden-update-epic-result (pushed, commits 4c19876cc test + 78be9dfc5 impl)

**AC trace:** AC1 → story_id wrapper + docstring; AC2/AC3 → TEA's tightened 160-6 tests pass unchanged; AC4 → same-epic/dry-run+field/empty-epic tests green; AC5 → move_story no-op with identity comparison.

**Handoff:** To Colonel Lynch (Reviewer) for review phase.

## Dev Assessment (rework r2)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_move.py` (commit 1619085da) — same-epic no-op branch now carries `"dry_run": dry_run` through verbatim (with a why-comment), and the Returns docstring documents the carried flag. That was the entire code fix the rework required; the other 4 Reviewer findings were closed by TEA's tests alone.

**Tests:** 106/106 passing (GREEN — testing-runner run `160-24-dev-green-r2`; the 2 rework RED tests now pass; ruff clean)
**Branch:** feat/160-24-harden-update-epic-result (pushed, 4 commits: 4c19876cc, 78be9dfc5, 17f7f4fc5, 1619085da)

**Handoff:** Back to Colonel Lynch (Reviewer) for re-review.

### Dev (implementation, rework r2) — Design Deviations
Logged inline here for locality: none — the fix implements the Reviewer's suggested design verbatim (unconditional carry, the style TEA's tests left open).

### Dev (implementation, rework r2) — Delivery Findings
- No upstream findings during rework implementation.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 1 (commit scope) | confirmed 1 (LOW, non-blocking) |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 4 | confirmed 3, downgraded 1 (docstring note → LOW) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | findings | 5 | confirmed 2, dismissed 2 (with citations), deferred 1 |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | clean | 1 observational note | confirmed 1 (LOW, non-blocking) |

**All received:** Yes (5 enabled returned, 4 disabled via settings)
**Total findings:** 8 confirmed, 2 dismissed (with rationale), 1 deferred

### Rule Compliance

Rubric: `.pennyfarthing/gates/lang-review/python.md` (13 checks) + SOUL #2/#10/#14. Rule-checker ran all 16 exhaustively over all 4 changed files (47 instances); I spot-verified its load-bearing claims myself:

- **#1 silent exceptions:** no new try/except in the diff — verified by reading both source files end-to-end. Pre-existing `except Exception: pass` at `story_update.py:217` untouched (already a TEA delivery finding). PASS.
- **#3 annotations at boundaries:** `move_story`/`update_story` keep full annotations incl. `-> dict[str, Any]` returns — `story_move.py:69`, `story_update.py:34`. PASS.
- **#5 path handling:** AST-scan test reads with `encoding="utf-8"`; new fixture `write_text` calls omit `encoding=` but mirror the identical pre-existing convention in the 160-6 fixture — noted LOW, not a regression. PASS with note.
- **#6 test quality:** all `assert result[...]` check specific values (`is True`/`is False`); AST delegation check mutation-verified meaningful (inline-reimplementation-with-import fails it). PASS — but see [TEST] findings: coverage gaps are a #6-adjacent failure caught by mutation, not vacuous assertions.
- **#11 input validation:** empty `--epic ''` fail-loud verified (`find_epic("")` → None); conflict check precedes dry-run. PASS.
- **#13 fix-regressions meta-check:** story_id backfill verified against all 3 move result shapes; docstrings verified line-by-line against actual returns. PASS.
- **SOUL #2:** `--epic` delegates via a single `move_story` call site (`story_update.py:125`), AST-enforced. PASS. **SOUL #10:** all new paths return result dicts, raises confined to the CLI translation layer. PASS. **SOUL #14:** docstrings accurate per line-by-line cross-check. PASS.
- Checks #2/#4/#7/#8/#9/#10/#12: N/A or zero instances in diff (verified by rule-checker enumeration).

### Observations

1. [VERIFIED] Same-epic no-op fires before any mutation — `story_move.py:116` returns before the `stories.remove` at line 138; security specialist independently traced the same ordering. Complies with fail-loud/#11 and the mutation-atomicity precedent (155-12).
2. [VERIFIED] Identity comparison is sound today — `find_epic` (`loader.py:214`) and `find_story_in_data` (`loader.py:406`) return live references into the same `data["epics"]` list from one `read_sprint`; the `epic-151` normalization case is covered by a dedicated RED-turned-green test.
3. [VERIFIED] `story_id` backfill (`story_update.py:132`) produces the documented value on all three shapes — real move → new_id, dry-run → unchanged id, no-op → unchanged id — confirmed by rule-checker path enumeration and by the passing shape tests.
4. [TEST][HIGH] The `no_op` contract key is asserted by NO test — mutation-proven: removing `no_op` from the return (keeping the non-renumbering behavior) passes all 12 tests. AC5's "reports" deliverable is therefore unverified; both CLIs dispatch on this key and Dev's own deviation names it "the stable contract". `test_160_24_update_epic_result_shape.py` TestSameEpicMove.
5. [TEST][MEDIUM] Both CLI no-op branches have zero coverage — mutation-proven: deleting the branch from `story_update_command` passes the full 27-test suite. User-facing output ("already in epic … nothing to move") is silently deletable. `story_update.py:422`, `story_move.py:208`.
6. [TEST][TYPE][MEDIUM] Same-epic + `dry_run=True` is unspecified and untested: the no-op check precedes the dry-run check, so the result silently drops the `dry_run` key. Corroborated independently by type-design and test-analyzer (direct-call verification). Needs a pinned contract (carry `"dry_run": dry_run` through, or document the precedence) + test.
7. [TYPE][LOW deferred] Loader identity invariant ("returns live references, never copies") is relied on by `story_move.py:116` but undocumented in `loader.py` docstrings — behavioral tests guard the regression; deferred as a non-blocking Improvement (docstring note).
8. [TYPE][LOW] In-place mutation of `move_result` and the `or`-chain truthiness fallback are safe in this domain (ids are non-empty `N-N` strings from `generate_story_id`) — `{**move_result, "story_id": ...}` and presence-checks would be marginally more robust; fold into rework if convenient.
9. [DISMISSED] type-design's "story_id semantics diverge per arm" API-change suggestion — dismissed citing AC-1's explicit contract: "returns a uniform result shape including story_id (e.g. from move_result.story.new_id)". The spec chose post-move-id semantics; the `story` sub-dict (old_id/new_id) plus `no_op`/`dry_run` tags provide disambiguation, and the docstring documents the divergence. Non-blocking Improvement captured for a possible discriminant key.
10. [DISMISSED] type-design's "identity check could break if loader returns copies" as a current defect — the invariant holds today (verified at loader.py source) and the behavioral suite catches the regression; captured instead as the deferred docstring Improvement (observation 7).
11. [LOW] Commit `4c19876cc` uses `test:` without the `(160-24)` scope (preflight). History rewrite mid-branch not warranted; squash-merge title will carry the compliant format.
12. [LOW] Two edge-guard tests lack per-test green-on-arrival docstring notes (module docstring covers them); align with siblings during rework.

**Data flow traced:** CLI `--epic "epic-152"` → `story_update_command` → `update_story` conflict check (`story_update.py:100-124`) → `move_story` → `find_epic` normalization → identity check → remove/renumber/dep-rewrite → `validate_sprint_document` → `write_sprint`; every failure path returns `{success: False, error}` and no write occurs on validation failure. Safe: no mutation precedes validation-relevant early returns.
**Pattern observed:** good — validate-before-first-mutation preserved by placing the no-op return at `story_move.py:116`, ahead of the first `remove()`; consistent with the 155-12 mutation-order precedent.
**Error handling:** story-not-found / epic-not-found / empty-epic all produce result objects with actionable messages (`story_move.py:97-110`); ClickException only at the CLI boundary.

### Devil's Advocate

Assume this change is broken. First: the no-op contract is a ghost. I can delete the `no_op` key — the one thing AC5 added as the "report" — and every test stays green; that is not a hypothetical, the test-analyzer did it by mutation. A future refactor that rebuilds the same-epic branch and forgets the key would ship silently, and both CLIs would fall through to the "Moved story None to epic 151 as None" path the anti-None guard only pins for cross-epic moves. Second: the dry-run promise is now ambiguous. A user running `--epic 151 --dry-run` on a same-epic story gets a result indistinguishable from a real invocation — the `dry_run` key vanishes. Today the no-op writes nothing either way, so no data is harmed, but any script keying on `result["dry_run"]` to decide "nothing happened yet" reads a lie. Third: the identity comparison bets on an undocumented loader invariant; a well-meaning "return copies for safety" refactor re-opens the exact silent-renumber bug this story fixes, and only a behavioral test three files away would say so. Fourth: `find_epic` never matches an epic's JIRA key — `move_story("151-3", to_epic="PROJ-17079")` errors "not found" even though that IS the source epic; fail-loud, so acceptable, but the story-id argument accepts jira keys while to_epic doesn't — an asymmetry a confused user will hit. Fifth: a whitespace variant `--epic " 151"` fails loud rather than matching — consistent, but unpinned. The first three are real; the first is the reject.

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | AC5's "report" deliverable (`no_op: True`) is asserted by no test — mutation-proven deletable while all 12 tests pass; the key is the documented stable contract both CLIs dispatch on | `pennyfarthing-dist/src/pf/tests/test_160_24_update_epic_result_shape.py` (TestSameEpicMove) | TEA: assert `result.get("no_op") is True` on the same-epic success path (API + update-path variants) |
| [MEDIUM] | CLI no-op branches have zero coverage — deleting the branch passes the full suite; user-facing output silently deletable | `story_update.py:422`, `story_move.py:208` | TEA: CliRunner tests for both commands with a same-epic `--epic`, asserting exit 0 + "already in epic" message + no "None" in output |
| [MEDIUM] | Same-epic × dry-run interaction unspecified: no-op branch drops the `dry_run` key from the result | `pennyfarthing-dist/src/pf/sprint/story_move.py:116` | Dev: carry `"dry_run": dry_run` through the no-op branch (or explicitly pin/document precedence); TEA: pin the chosen shape with a test |
| [LOW] | Two edge-guard tests lack per-test green-on-arrival docstring notes; new fixture `write_text` omits `encoding=`; commit `4c19876cc` missing scope | test file / fixtures / git history | Fold into rework: docstring notes + `encoding="utf-8"` on new fixture writes; squash-merge title carries the scope |

**Verdict rationale:** The implementation itself is sound — same-epic detection, mutation ordering, result-shape backfill, and docstrings all verified clean across 16 rules by exhaustive check plus my own reads. What fails is the story's own charter: this is a p1 *test-hardening* story ("tighten tests, add edge cases"), and mutation testing proves the new contract surface (the `no_op` report key and both CLI branches) can be deleted without a single test noticing, plus one genuinely unspecified interaction (same-epic × dry-run). Findings are testable → rework routes to TEA (red) with one one-line Dev change folded in.

**Handoff:** Back to Captain Murdock (TEA) for rework RED — add the missing contract assertions and the same-epic × dry-run pin; Sergeant Baracus follows with the one-line `dry_run` carry-through.

## Reviewer Assessment

**Verdict:** APPROVED (re-review r2; supersedes the round-1 REJECTED verdict above)

**Re-review protocol:** the rework delta (7-line impl change in `story_move.py` + 117 test lines, commits 17f7f4fc5 + 1619085da) was verified by re-running the EXACT mutations that escaped round 1, plus the full scoped batch and lint. Round-1's full 5-specialist panel + 16-rule exhaustive check already covered the base diff; findings closure evidence:

| Round-1 finding | Status | Evidence |
|-----------------|--------|----------|
| [HIGH] `no_op` key untested | CLOSED | Mutation re-run: falsifying `no_op` now fails **6** tests (round 1: 0) |
| [MEDIUM] CLI no-op branches uncovered | CLOSED | Mutation re-run: disabling the update-CLI branch now fails **1** test (round 1: 0); move-CLI branch has a symmetric pin |
| [MEDIUM] same-epic × dry-run unspecified | CLOSED | `"dry_run": dry_run` carried through (`story_move.py` no-op branch, with why-comment + docstring); the 2 rework RED tests now pass |
| [LOW] docstrings / fixture encoding / commit scope | CLOSED | Guard docstrings note green-on-arrival; fixture writes use `encoding="utf-8"`; rework commits use `test(160-24):`/`feat(160-24):` |

**Meta-check (#13, fix-introduced regressions):** the fix adds one dict key, one comment, one docstring sentence — re-scanned against checks #1–#12: no new excepts, defaults, annotation gaps, or boundary changes. Ruff clean on all 4 files; 106/106 scoped tests pass; working tree clean at 1619085da.

**Dispatch-tag closure:** [EDGE] boundary set (same-epic, prefixed form, empty epic, dry-run×no_op, conflict combo) now fully pinned; [SILENT] no swallows introduced, fail-loud preserved (security + rule-checker clean); [TEST] mutation holes closed as evidenced above; [DOC] docstrings verified accurate line-by-line incl. the new carried-flag sentence; [TYPE] result-union coherent and documented — discriminant idea captured as a non-blocking Improvement; [SEC] clean (no new input surface; no-op precedes all mutation); [SIMPLE] no unnecessary complexity — the fix is the minimal truthful shape; [RULE] 16/16 rules pass, zero violations.

**Data flow traced:** `--epic 151 --dry-run` on a same-epic story → conflict check → `move_story` → identity no-op → `{success, no_op, dry_run, story}` → `story_id` backfill → CLI no-op echo — every key now test-pinned end-to-end.
**Pattern observed:** good — mutation-guard tests documenting their Reviewer-finding provenance in docstrings (`test_160_24_update_epic_result_shape.py`, TestSameEpicReportContract), a pattern worth repeating.
**Error handling:** unchanged from round-1 verification; all failure paths return result objects.

**Handoff:** To Lieutenant Faceman (SM) for finish — PR creation and merge.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### Dev (implementation)
- **Same-epic outcome implemented as success no-op, not rejection**
  - Spec source: context-story-160-24.md, AC-5
  - Spec text: "move_story detects to_epic == source_epic and no-ops or reports instead of silently renumbering"
  - Implementation: Returns `{"success": True, "no_op": True, "story": {...}}` with the unchanged details; both CLIs echo "already in epic X — nothing to move"
  - Rationale: The AC permits no-op or report; a success no-op is idempotent (re-running a move command whose state already holds should not error) and satisfies TEA's fix-agnostic tests including the `story_id == "151-3"` pin
  - Severity: minor
  - Forward impact: none — callers checking only `success` see no behavior change for same-epic input
  - → ✓ ACCEPTED by Reviewer: idempotent no-op is the better design; but its `no_op` report key MUST be test-pinned — see [HIGH] finding
- **CLI no-op rendering added without a pinning test**
  - Spec source: session file story scope (uniform result shape / no silent behavior)
  - Spec text: "uniform result shape including story_id" (AC-1); TEA handoff: "keep the `story` details the CLI reads"
  - Implementation: Added a `no_op` branch to both `story move` and `story update` CLI success output
  - Rationale: Without it a same-epic invocation would print "Moved story None to epic 151 as None" — the exact regression class TEA's anti-`None` guard catches on the cross-epic path
  - Severity: minor
  - Forward impact: none — output-only; the `no_op` result key is the stable contract
  - → ✗ FLAGGED by Reviewer: honestly logged, but mutation testing proves the branch AND the "stable contract" key are both deletable with zero test failures — the deviation's premise ("output-only") understates it; rework adds the pinning tests

### TEA (test design)
- **Edge-guard tests are green-on-arrival by design**
  - Spec source: context-story-160-24.md, AC-4
  - Spec text: "New tests cover same-epic --epic, --epic + --dry-run + field-flag (reject-under-dry-run), and --epic '' (empty string)"
  - Implementation: The dry-run+field-flag rejection and empty-string tests PASS on HEAD (the conflict check precedes dry-run handling; `find_epic` finds no epic id "") — only the same-epic tests are RED
  - Rationale: Current code already rejects those inputs; the tests pin the behavior so AC1's shape refactor cannot open a dry-run bypass or an empty-target regression
  - Severity: minor
  - Forward impact: Gate/Reviewer must read the 5 passing new tests as intentional guards, not spurious greens
  - → ✓ ACCEPTED by Reviewer: verified non-tautological by test-analyzer (conflict check precedes dry-run; find_epic('') is None) — correct guards
- **AC2/AC3 tightenings are green-on-arrival test-quality changes**
  - Spec source: context-story-160-24.md, AC-2/AC-3
  - Spec text: "asserts distinguishing help text (e.g. 'delegates')" / "tightened to an AST call-site check"
  - Implementation: Edited the two 160-6 tests in place; both pass immediately (help already says "delegates"; the `move_story` call site exists)
  - Rationale: These ACs upgrade weak assertions, not behavior — the tautological `"epic" in output` and the substring scan could pass on a comment or the flag name alone
  - Severity: minor
  - Forward impact: none — Dev makes no change for AC2/AC3
  - → ✓ ACCEPTED by Reviewer: AST check mutation-verified meaningful (inline reimplementation with lingering import correctly fails it)
- **Dry-run story_id value left fix-agnostic**
  - Spec source: context-story-160-24.md, AC-1
  - Spec text: "returns a uniform result shape including story_id (e.g. from move_result.story.new_id)"
  - Implementation: Non-dry-run pins `story_id == "152-2"` (the new id, per the AC example); the dry-run test accepts `"151-3"` OR `"152-2"`
  - Rationale: `move_story`'s dry-run result computes no `new_id` today, so pinning the new id would dictate extra implementation the AC doesn't require (filed as a non-blocking Improvement finding instead)
  - Severity: minor
  - Forward impact: Dev chooses the dry-run id; either satisfies the suite
  - → ✓ ACCEPTED by Reviewer: agrees with author reasoning; the non-blocking Improvement finding covers the computed-new-id option
- **Rework r2: contract pins are green-on-arrival by design (mutation guards)**
  - Spec source: Reviewer Assessment (rework findings), AC-5
  - Spec text: "[HIGH] assert result.get('no_op') is True on the same-epic success path"; "[MEDIUM] CliRunner tests for both commands"
  - Implementation: 4 of the 6 new TestSameEpicReportContract tests pass on HEAD (the implementation already ships no_op and the CLI branches); only the 2 dry-run-carry tests are RED
  - Rationale: The Reviewer's findings were coverage holes, not behavior bugs — the correct rework RED pins the shipped contract so mutation can no longer delete it, and leaves genuinely-RED only the unimplemented dry_run carry-through
  - Severity: minor
  - Forward impact: Dev's fix is one line (`"dry_run": dry_run` — or the flag only when True — in move_story's no-op branch); gate must read the 4 passing new tests as intentional
  - → ✓ ACCEPTED by Reviewer (r2): correct rework shape — green pins close mutation holes, RED drives only the real change; mutation re-runs confirm
- **Rework r2: dry_run carried as always-present key on the no-op path**
  - Spec source: Reviewer Assessment finding 3 (same-epic × dry-run unspecified)
  - Spec text: "carry 'dry_run': dry_run through the no-op branch (or explicitly pin/document precedence)"
  - Implementation: Tests pin `dry_run: True` present on same-epic dry-run results; the non-dry-run no-op tests use `.get("no_op") is True` without forbidding a `dry_run: False` key, so Dev may thread the flag unconditionally or only-when-True
  - Rationale: Reviewer offered two designs; carrying the flag is the one that keeps result["dry_run"] truthful for scripts, and the tests stay agnostic about the False-case representation
  - Severity: minor
  - Forward impact: none — both threading styles satisfy the suite
  - → ✓ ACCEPTED by Reviewer (r2): Dev chose unconditional carry — the more truthful shape; docstring updated to match
- **Same-epic outcome left fix-agnostic + prefixed-form variant added beyond the literal AC**
  - Spec source: context-story-160-24.md, AC-5
  - Spec text: "move_story detects to_epic == source_epic and no-ops or reports instead of silently renumbering"
  - Implementation: Tests accept EITHER a success no-op/report OR a fail-loud rejection; only the silent renumber (empirically 151-3 → 151-5 + dep rewrite) fails. Added a `to_epic="epic-151"` variant not literally in the AC
  - Rationale: "no-ops or reports" names two valid designs — pinning one would be TEA invention. The prefixed variant is required because `find_epic` normalizes "epic-151" to the same epic dict, so a naive raw-string compare would pass the plain test yet keep the bug
  - Severity: minor
  - Forward impact: Dev must compare resolved epics (e.g. identity), not raw `to_epic` strings
  - → ✓ ACCEPTED by Reviewer: prefixed-form variant is exactly the fix-forcing edge case needed; identity comparison verified sound at loader.py

### Reviewer (audit)
- **Same-epic × dry-run precedence undocumented:** Spec (AC4) enumerates --epic+--dry-run+field-flag but not same-epic+dry-run; code silently drops the `dry_run` key on that path. Not documented by TEA/Dev. Severity: M — included in rework findings.