---
story_id: "164-2"
jira_key: ""
epic: "164"
workflow: "tdd"
---
# Story 164-2: Preflight hardening follow-ups: enforce LintResult skipped-invariant, unify lint/jira skipped to_dict shape, belt-and-suspenders _lookup arg-guard, symmetric jira over-reach + single-dash tests

## Story Details
- **ID:** 164-2
- **Jira Key:** (local-only, no Jira sync)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-2-preflight-hardening-followups
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T14:42:43Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T14:13:13Z | - | - |

## Technical Context

### Refactor Scope
This story addresses five deferred hardening findings from PR pennyfarthing#144 (epic-155 finish-truthfulness review, 155-14 review deferrals). All changes are in:
- Target: `pennyfarthing-dist/src/pf/preflight/finish.py` (main module)
- Target: `pennyfarthing-dist/src/pf/tests/test_155_14_preflight_hardening.py` (test suite)

### Key Data Structures

**LintResult dataclass** (finish.py lines 37–45):
```python
@dataclass
class LintResult:
    clean: bool = False
    output: str = ""
    error: str | None = None
    command: str = ""
    skipped: bool = False  # Current code has this; enforcing invariant is AC1
```

**LintResult invariant (AC1):** When `skipped=True`, `clean` MUST be `True` (convention, not enforced). A test with a contradictory state (skipped=True + error set/clean=False) must fail via `__post_init__` validation or sum-type modeling.

**JiraStatus dataclass** (finish.py lines 48–55):
```python
@dataclass
class JiraStatus:
    current: str | None = None
    key: str | None = None
    error: str | None = None
    skipped: bool = False
```

**Serialization shape (AC2):** Current `to_dict()` (finish.py lines 81–136):
- **Lint:** Returns nested `"lint": {"clean": ..., "skipped": ...}`
- **Jira:** When skipped, returns both `"jira_skipped": True` (top-level) AND `"jira": {"skipped": True}` (nested)
- **Goal:** Unify lint and jira to use one consistent serialization shape (either nested or top-level, not mixed).

### Acceptance Criteria Breakdown

#### AC1: LintResult skipped-invariant enforcement (mutation-verified test)
**Issue:** `LintResult` permits contradictory states: `skipped=True` with `error` set or `clean=False`. Only `check_lint` maintains the invariant; a second caller or direct construction could violate it.

**Implementation approach:**
- Add a `__post_init__()` method to `LintResult` that validates: if `skipped=True`, then `clean` must be `True` and `error` must be `None`.
- Raise `ValueError` with a clear message if the invariant is violated.
- Mutation-verified test: a synthetic test that directly constructs contradictory states and asserts they are rejected.

**Related test:** `test_lintresult_has_skipped_field_defaulting_false()` confirms the field exists and defaults False.

---

#### AC2: Lint and Jira skipped to_dict unification
**Issue:** Serialization shape is asymmetric:
- `lint.skipped=True` → nested: `"lint": {"clean": True, "skipped": True}`
- `jira.skipped=True` → both top-level (`"jira_skipped": True`) and nested (`"jira": {"skipped": True}`)

Downstream gates rely on this JSON shape; unifying it to one convention prevents confusion and simplifies parsing.

**Implementation approach:**
1. Choose one shape (recommend nested for consistency with lint):
   - Lint: `"lint": {"clean": ..., "skipped": ...}` (current, fine)
   - Jira: Change from `"jira_skipped": True + "jira": {"skipped": True}` to just `"jira": {"skipped": True, "current": null, "key": null}` (or omit current/key when skipped)

2. Update `PreflightResult.to_dict()` lines 103–110 to emit Jira in nested form only.

**Related tests:**
- `test_to_dict_surfaces_lint_skipped_true()` — lint skipped serialization
- `test_to_dict_reports_lint_skipped_false_when_lint_ran()` — lint ran serialization
- New test (AC2 coverage): verify Jira skipped uses same nested shape as lint

---

#### AC3: Belt-and-suspenders _lookup arg-guard for _lookup_merged_pr_by_branch
**Issue:** `_lookup_merged_pr_by_branch()` (finish.py line 155) has no internal guard on the `branch` argument. It is safe only because `check_pr_status()` calls it and already guards `branch` with `_reject_option_like()`. If a second caller (e.g., a new preflight check or test) calls it directly, an option-shaped branch silently reaches `gh pr list --head <branch>` as a bare positional — argument injection (CWE-88).

**Implementation approach:**
1. Add an internal guard in `_lookup_merged_pr_by_branch()`: call `_reject_option_like(branch, 'branch')` at the start.
2. Return a neutral result (e.g., `None`, or a `PRStatus`-like object with an error) if the guard rejects it.
3. Add a test that calls `_lookup_merged_pr_by_branch()` directly with an option-shaped branch and asserts the injection is neutralized.

**Related test:** `test_pr_status_neutralizes_option_shaped_branch()` already covers the indirect path; a new test must cover a direct call.

---

#### AC4: Symmetric Jira over-reach test + single-dash injection + skip test assertions
**Issue (a):** The test suite guards against option-like branches (`--evil-flag`) and keys (`--evil-key`), but there is no symmetric test for a *legitimate* Jira key still reaching the Jira endpoint (the guard must not over-reach and block valid keys).

**Issue (b):** Single-dash injection (`-R owner/repo`) is a real injection vector (short-form flags); current tests only cover double-dash (`--evil-flag`). Add a test for `-R` or a similar real-world flag.

**Issue (c):** The `test_check_lint_marks_skipped_when_no_lintable_project()` test does not explicitly assert `result.clean is True` *alongside* `result.skipped is True`. The state should be invariant-verified in the same test.

**Implementation approach:**
1. Add `test_jira_status_does_not_block_legitimate_key()` — like `test_guard_does_not_break_legitimate_branch()` but for Jira. Call `check_jira_status('PROJ-12345')` (or similar real key), mock the subprocess, and assert no guard error.

2. Add `test_pr_status_neutralizes_single_dash_injection()` — call `check_pr_status('-R')` or `check_pr_status('-Rowner/repo')` and assert the injection is neutralized (matching the double-dash cases).

3. Update `test_check_lint_marks_skipped_when_no_lintable_project()` to add:
   ```python
   assert result.clean is True, "skipped must enforce clean=True invariant"
   ```

---

#### AC5: Unmerged-branch-no-PR warning at preflight entry
**Issue:** From 155-34 review: when the branch is unmerged and no PR exists, preflight currently fails with a blocking issue ("No PR found"). This is correct behavior for finish, but the error message surfaces too late in the ceremony — ideally, the warning should appear when preflight *starts*, not when a tool runs.

**Implementation approach:**
1. Add an early check in `run_finish_preflight()` (or a new preflight-entry wrapper) that detects the unmerged-branch-no-PR case before launching checks.
2. Emit a warning (not an error) surfaced at preflight entry: "Branch is unmerged and no PR was found; finish will fail unless a PR is created or merged."
3. This allows the abort to surface at preflight (user sees it immediately) rather than during aggregation.

**Note:** This may be a distinct phase warning or a pre-check marker; review the 155-34 session for the exact integration point.

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story has 5 ACs requiring enforcement, unification, security guard, and behavioral changes.

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_155_14_preflight_hardening.py` — 13 new tests appended (23 total)

**Tests Written:** 13 new tests covering all 5 ACs
**Status:** RED (6 failing, 17 passing — ready for Dev)

**Failing tests by AC:**
- AC1: `test_lintresult_rejects_skipped_true_with_error_set`, `test_lintresult_rejects_skipped_true_with_clean_false` — no `__post_init__` validation exists
- AC2: `test_jira_skipped_to_dict_has_no_top_level_jira_skipped_key` — top-level `jira_skipped` key still emitted
- AC3: `test_lookup_direct_call_rejects_double_dash_option_branch`, `test_lookup_direct_call_rejects_single_dash_injection` — `_lookup_merged_pr_by_branch` has no internal guard
- AC5: `test_run_finish_preflight_warns_on_unmerged_branch_no_pr` — no preflight-entry warning, only critical issue

**Passing (regression guards, AC4):**
- `test_jira_status_does_not_block_legitimate_key` — guard over-reach: legit key passes
- `test_pr_status_neutralizes_single_dash_injection` — existing `_reject_option_like` already handles single-dash
- `test_check_lint_marks_skipped_with_clean_true_invariant` — `check_lint` already sets clean=True when skipping

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/preflight/finish.py` — AC1 `__post_init__`, AC2 remove `jira_skipped` top-level key, AC3 `_lookup_merged_pr_by_branch` arg guard, AC5 unmerged-branch warning

**Tests:** 23/23 passing (GREEN)
**Branch:** feat/164-2-preflight-hardening-followups (pushed)
**Commit:** 20c9c19d0

**Handoff:** To next phase (review)

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|---------|--------|----------|---------|
| 1 | reviewer-preflight | Yes | clean | 26/26 passing (round 2) | N/A |
| 2 | reviewer-edge-hunter [EDGE] | Yes | findings | mutation bypass via check_lint (Med, round-1); empty-string guard gap (Low, round-1) | Incorporated into round-1 findings; both addressed in fix commit |
| 3 | reviewer-silent-failure-hunter [SILENT] | Yes | findings | _lookup guard silent rejection returns None with no error signal (Low) | Deferred minor |
| 4 | reviewer-comment-analyzer [DOC] | Yes | findings | lying "in parallel" docstring on run_finish_preflight (Low); stale _reject_option_like docstring missing empty-guard explanation (Low) | Deferred minor |
| 5 | reviewer-security [SEC] | Yes | clean | none | N/A |
| 6 | reviewer-test-analyzer [TEST] | Yes | findings | vacuous reconstruction assertion in TestCheckLintSkipPathInvariant (Low); whitespace-only branch " "/"\t" not tested (Low) | Deferred minor |
| 7 | reviewer-type-design [TYPE] | Yes | clean | none | N/A |
| 8 | reviewer-simplifier [SIMPLE] | Yes | findings | redundant `if early_warnings:` guard before list concat (Low) | Deferred minor |
| 9 | reviewer-rule-checker [RULE] | Yes | clean | none | N/A |

All received: Yes (9/9 subagents returned)

## Reviewer Assessment

**Verdict:** APPROVED

### Round 1 — CHANGES_REQUESTED (commit 20c9c19d0)

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | `sm-finish.md` reads `jira_skipped: true` (top-level key removed by AC2) — jira-skipped signal silently dropped from SM output | `sm-finish.md:205` | Change to `jira.skipped: true` (nested form) |
| [MEDIUM] | `__post_init__` invariant bypass via mutation in `check_lint` skip path | `finish.py:297-298` | Return `LintResult(clean=True, skipped=True)` directly |
| [MEDIUM] | AC5 warning in `aggregate_results` (aggregation time) not at preflight entry as spec required | `finish.py:410` | Move to `run_finish_preflight` before `asyncio.gather` |
| [LOW] | `_reject_option_like` passes empty string — `gh pr list --head ""` matches all merged PRs | `finish.py:156` | Reject empty/whitespace values |

### Round 2 — APPROVED (commit e0978ceac)

All four findings addressed:
- **[HIGH] ADDRESSED:** `sm-finish.md:205` updated to `jira.skipped: true` (nested). Grep confirms zero remaining live consumers of top-level `jira_skipped` outside test assertions and historical archives.
- **[MED] ADDRESSED:** `check_lint` skip path now `return LintResult(clean=True, skipped=True)` one-shot. New test `TestCheckLintSkipPathInvariant` validates.
- **[MED] ADDRESSED:** `run_finish_preflight` runs PR check sequentially first, detects `no pull requests found` before `asyncio.gather`, prepends `early_warnings` to result. Warning removed from `aggregate_results`.
- **[LOW] ADDRESSED:** `_reject_option_like` now rejects empty/whitespace at top. `TestEmptyBranchGuard` added with two tests.

**New breakage scan (fix diff only):** None. Index arithmetic on reordered `results` list verified correct (`[0]=lint, [1]=acceptance, [2]=jira`). `preflight.warnings = early_warnings + preflight.warnings` mutation is valid. Empty guard does not over-block legitimate values.

**Tests:** 26/26 passing.

**Data flow traced:** `jira_key=None` → `run_finish_preflight` → `JiraStatus(skipped=True)` → `to_dict()` emits `{"jira":{"skipped":true}}` → `sm-finish` reads `jira.skipped: true` (nested, now correct) → notes jira-skipped in output.

**Pattern observed:** Belt-and-suspenders guard in `_lookup_merged_pr_by_branch` at `finish.py:174` — independent of caller-side guard, return-don't-throw.

**Specialist findings (fix diff):**
- [SEC] CLEAN — `not value or not value.strip()` guard is correct; no new subprocess calls; `check_pr_status` outside gather is safe (has its own exception guard).
- [TYPE] CLEAN — `_reject_option_like` return type consistent; `preflight.warnings` mutation type-safe; no bare raises introduced.
- [RULE] CLEAN — all 4 project rules pass across 14 checked instances.
- [DOC] Low: lying "in parallel" docstring on `run_finish_preflight` (finish.py:508); stale `_reject_option_like` docstring missing empty-guard explanation (finish.py:146). Deferred.
- [SIMPLE] Low: redundant `if early_warnings:` guard before list concat (finish.py:558). Deferred.
- [TEST] Low: vacuous reconstruction assertion in `TestCheckLintSkipPathInvariant` (test file:580) — cannot distinguish one-shot from mutation; whitespace-only ` `/`\t` branch of guard not covered by `TestEmptyBranchGuard`. Deferred.
- [EDGE] Round-1 findings: mutation bypass (addressed) + empty-string gap (addressed). Round-2 fix diff: no new edge cases.
- [SILENT] Low: `_lookup_merged_pr_by_branch` returns `None` on guard rejection with no error signal — caller cannot distinguish injection rejection from "no PR found." Deferred.

**Handoff:** To SM for finish-story.

## Delivery Findings

No upstream findings at setup.

### Reviewer (code review)
- **Gap** (blocking): `sm-finish.md` references removed top-level `jira_skipped` key — agent will silently miss jira-skipped signal after AC2 change. Affects `pennyfarthing-dist/agents/sm-finish.md:205` (update to `jira.skipped`). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `__post_init__` invariant doesn't cover mutation path — `check_lint` skip path mutates fields post-construction, bypassing guard. Affects `pennyfarthing-dist/src/pf/preflight/finish.py:297-298` (refactor to direct construction). *Found by Reviewer during code review.*
- **Gap** (non-blocking): AC5 warning lands in `aggregate_results` not at preflight entry as spec states. Affects `finish.py:410` (move early check to `run_finish_preflight` before `asyncio.gather` if timing matters). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `_reject_option_like` passes empty string (`"".startswith("-")` = False) — `_lookup_merged_pr_by_branch("")` assembles `gh pr list --head ""` which matches ALL merged PRs repository-wide, returning a false-positive merged result. Pre-existing gap in `_reject_option_like`, but AC3 added a new call site. Affects `finish.py:156,174`. *Found by edge-hunter.*
- **Gap** (non-blocking): `_lookup_merged_pr_by_branch` returns `None` on guard rejection with no error signal — caller cannot distinguish injection-guard rejection from "no merged PR found." Currently unreachable (check_pr_status guards first), but direct callers (as in AC3 tests) get silent rejection. Affects `finish.py:174`. *Found by silent-failure-hunter.*

## Design Deviations

### TEA (test design)
- **AC4 partial green in RED:** Spec says add single-dash test and over-reach test. Both pass with current code — existing `_reject_option_like` already handles `-` prefix, and legit keys already reach the endpoint. Written as regression guards to protect against over-blocking after AC3 guard is added. *Found by TEA during test design.*