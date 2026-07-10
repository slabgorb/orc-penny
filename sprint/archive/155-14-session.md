---
story_id: "155-14"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-14: Preflight hardening: gh arg-injection guard, LintResult.skipped truthful reporting, async stat, skip-branch test coverage

## Story Details
- **ID:** 155-14
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none

**Merged PR:** slabgorb/pennyfarthing#144 (squash `617f41b2a` → `develop`, merged 2026-07-10T12:00:17Z, human-authorized). Merge independently verified — `finish` takes the NO-PR path.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-10T11:45:04Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-10T11:23:52Z | 2026-07-10T11:25:34Z | 1m 42s |
| red | 2026-07-10T11:25:34Z | 2026-07-10T11:33:30Z | 7m 56s |
| green | 2026-07-10T11:33:30Z | 2026-07-10T11:37:13Z | 3m 43s |
| review | 2026-07-10T11:37:13Z | 2026-07-10T11:45:04Z | 7m 51s |
| finish | 2026-07-10T11:45:04Z | - | - |

## Sm Assessment

**Story:** 155-14 — Preflight hardening (2 pts, p1, chore, tdd). Repo: `pennyfarthing/` (gitflow, targets `develop`). No Jira key — orchestrator-internal sprint work.

**Origin:** Follow-up hardening in epic-155 (finish/merge/archive truthfulness). The target code is the sm-finish **preflight** path under `pennyfarthing/pennyfarthing-dist/src/pf/` (finish/preflight/lint modules). TEA locates exact files.

**Acceptance Criteria (title is the spec — 4 deliverables):**
1. **gh arg-injection guard** — validate/sanitize args (PR numbers, branch names, story IDs) passed to `gh` subprocess calls in preflight so untrusted values cannot inject extra flags/commands.
2. **`LintResult.skipped` truthful reporting** — a skipped lint must NOT report as passing; surface skipped state honestly (SOUL #10: truthful state, return-don't-throw).
3. **async stat** — make the preflight file stat non-blocking / async.
4. **skip-branch test coverage** — add test coverage for the branch-skip code path.

**Routing:** tdd (phased) → TEA writes failing tests covering all four ACs (RED), then Dev (GREEN), then Reviewer. Each new guard should be mutation-verified (deleting it fails a test). Keep exception catches narrow (lang-review rule #1: no broad `except Exception`).

**Gate checklist:** session ✓ (bare-named `.session/155-14-session.md`), fields set ✓, story context written (`sprint/context/context-story-155-14.md`) ✓, branch `feat/155-14` created ✓, Jira ✓ (none — explicitly skipped).

**Handoff → TEA (Captain H.M. "Howling Mad" Murdock) for RED phase.**

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (9 failing, 1 passing — ready for Dev)

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_155_14_preflight_hardening.py` — 10 tests across the four ACs, all against `pf.preflight.finish`. Reuses the 155-5 async-subprocess fake pattern (`_Recorder` records argv; `_patched` swaps `create_subprocess_exec`/`_shell`).

**Tests Written:** 10 tests covering 4 ACs. RED verified via `testing-runner` (RUN_ID `155-14-tea-red`): 9 fail for the right reason (real gaps, no import/collection errors), 1 passes (a genuine over-reach guard).

### AC → Test → Failure-reason map

| AC | Test(s) | RED reason |
|----|---------|-----------|
| 1 gh arg-injection | `test_pr_status_neutralizes_option_shaped_branch`, `test_jira_status_neutralizes_option_shaped_key` | `--evil-flag`/`--evil-key` reach `gh pr view`/`jira issue view` as a **bare positional** (argv proven) |
| 1 over-reach guard | `test_guard_does_not_break_legitimate_branch` | **PASS** — legit branch already flows to gh & parses (must stay green) |
| 2 LintResult.skipped | `test_lintresult_has_skipped_field_defaulting_false`, `test_check_lint_marks_skipped_when_no_lintable_project`, `test_check_lint_not_skipped_when_linter_actually_runs`, `test_to_dict_surfaces_lint_skipped_true`, `test_to_dict_reports_lint_skipped_false_when_lint_ran` | `LintResult` has **no `skipped` field** (AttributeError / TypeError on ctor); `to_dict()` doesn't surface it |
| 3 async stat | `test_detection_stat_runs_off_event_loop_thread` | `Path.exists()` in `_detect_lint_command` runs on the **event-loop thread** (thread-identity assertion) |
| 4 skip-branch | `test_skip_branch_runs_no_subprocess_and_reports_skipped` | `lint_cmd is None` early return not covered; no `skipped` state |

### Rule Coverage (`.pennyfarthing/gates/lang-review/python.md`)

| Rule | Test(s) | Status |
|------|---------|--------|
| #8 subprocess command/arg injection (CWE-78/88) | `test_pr_status_neutralizes_*`, `test_jira_status_neutralizes_*` | failing |
| #11 input validation at boundaries | same as #8 (branch/jira_key validated before subprocess) | failing |
| #9 blocking I/O in async | `test_detection_stat_runs_off_event_loop_thread` | failing |
| #6 test quality (no vacuous asserts) | self-check pass — removed a vacuous `repo` test (repo is an option *value*, not a vector) | n/a |
| #1 narrow exception catches | checked — no new broad `except Exception` required by these ACs; Dev's guard must use narrow catches / return-don't-throw (SOUL #10) | note |

**Rules checked:** 5 of 13 lang-review rules apply to this diff; the 3 behavioral ones (#8/#11, #9, #6) have failing/self-check coverage.
**Self-check:** 1 vacuous test found and removed (`repo` injection — repo is not an injection vector).

### Verification contract for Dev (GREEN)

1. **AC1:** guard `branch` (in `check_pr_status`) and `jira_key` (in `check_jira_status`) — the two **bare positionals**. Either reject option-shaped (leading-`-`) values returning a truthful error (no throw, SOUL #10), OR insert a `--` end-of-options marker before the positional. `repo` needs no guard (passed as an option *value*). Legit branch test must stay green.
2. **AC2:** add `skipped: bool = False` to `LintResult`; set `skipped=True` on the no-lint-command path (do not conflate with a genuine `clean` pass); surface it in `PreflightResult.to_dict()["lint"]["skipped"]` (always emit the bool, mirroring `jira_skipped`).
3. **AC3:** offload the `package.json`/`pyproject.toml` existence stats in `_detect_lint_command` via `asyncio.to_thread` so they run off the event-loop thread.
4. **AC4:** the skip-branch test just needs AC2 + the early-return to hold (`command == ""`, no subprocess).

**Handoff:** To Dev for implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Tests:** 20/20 passing (GREEN) — 10 new (`test_155_14_preflight_hardening.py`) + 10 sibling regression (`test_155_5_preflight_false_blocks.py`). Verified via `testing-runner` (RUN_ID `155-14-dev-green`). Ruff: clean.
**Branch:** `feat/155-14` (pushed, commit `48e2c6f27`)

**Files Changed:**
- `pennyfarthing-dist/src/pf/preflight/finish.py` (+40/-2)

**AC → implementation:**
1. **gh arg-injection guard** — new `_reject_option_like(value, kind)` helper; `check_pr_status` guards `branch`, `check_jira_status` guards `jira_key`. An option-shaped (leading-`-`) value returns a truthful `error` string and never launches the subprocess (return-don't-throw, SOUL #10; CWE-88). Chose *reject* over `--` marker: simpler, and git/PR/Jira refs never legitimately start with `-`. `_lookup_merged_pr_by_branch` needs no separate guard — `check_pr_status` validates `branch` before it can reach that fallback.
2. **LintResult.skipped** — added `skipped: bool = False`; set `True` on the no-lintable-project path (alongside `clean=True` so it stays non-blocking); surfaced in `PreflightResult.to_dict()["lint"]["skipped"]` (always emitted, mirroring `jira_skipped`).
3. **async stat** — `_detect_lint_command` (which stats `package.json`/`pyproject.toml`) now runs via `await asyncio.to_thread(...)` in `check_lint`, off the event-loop thread.
4. **skip-branch coverage** — the `lint_cmd is None` early return now sets `skipped=True` and leaves `command==""`; covered by the new test.

**Self-review:** minimal change (no new abstractions beyond the one guard helper); narrow control flow, no broad `except` added; ruff clean; sibling suite green (no regression).

**Handoff:** To Reviewer for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 20/20 target green, ruff clean, smells clean; 16 pre-existing develop failures noted | confirmed 0, deferred 0 (regression proven pre-existing) |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 3 (mutation-tested: all AC tests fail correctly when impl reverted) | confirmed 0 blocking, 3 deferred (M/L coverage gaps) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | findings | 4 | confirmed 0 blocking, 4 deferred (M/L design nits) |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 0 blocking, 2 deferred (L: defense-in-depth + pre-existing OOS) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | clean | 0 (16 rules, 34 instances, exhaustive) | N/A |

**All received:** Yes (5 enabled returned; 4 disabled pre-filled)
**Total findings:** 0 confirmed blocking, 0 dismissed, 9 deferred (all Medium/Low, non-blocking)

### Rule Compliance

Exhaustive enumeration against `.pennyfarthing/gates/lang-review/python.md` (13 rules) + SOUL.md — corroborated by `reviewer-rule-checker` (clean, 0 violations):

| Rule | Applies to | Instances | Verdict |
|------|-----------|-----------|---------|
| #1 Silent exception swallowing | new try/except | 0 new blocks in diff (grep-verified) | compliant (no new catches) |
| #2 Mutable default args | `_reject_option_like`, `LintResult.skipped`, `_FakeProc` | 3 | compliant (all immutable defaults) |
| #3 Type annotations at boundaries | `_reject_option_like(value: str, kind: str) -> str \| None` | 1 | compliant (fully annotated) |
| #6 Test quality | 10 new tests | 10 | compliant (mutation-proven, no vacuous asserts, correct patch targets) |
| #8 Subprocess/shell injection | 4 exec call sites | 4 | compliant (argv-exec, no shell=True; CWE-88 guarded) |
| #9 Async pitfalls | `await asyncio.to_thread(...)`, sync guard calls | 3 | compliant (correct offload, no missing await) |
| #10 Import hygiene | new imports | 0 new in source; test imports explicit | compliant |
| #11 Input validation at boundaries | `branch`, `jira_key`, `repo` | 3 | compliant (both positionals guarded; repo correctly out-of-scope as option-value) |
| SOUL #10 Return-don't-throw | `_reject_option_like` | 1 | compliant (returns `str \| None`, never raises) |
| SOUL #2 One-truth | shared guard helper reused at 2 sites | 1 | compliant (single helper, not duplicated) |

### Devil's Advocate

Let me argue this code is broken. **The guard is a leaky abstraction defended only by call-ordering.** `_reject_option_like` lives in `check_pr_status`/`check_jira_status`, but the actual dangerous subprocess in the merged-PR fallback is inside `_lookup_merged_pr_by_branch`, which has *no guard of its own*. Today it's safe only because its sole caller validates `branch` first — but that's an invariant enforced by nothing. A future dev adding a second caller (a plausible "look up PR by branch" reuse) silently reopens CWE-88 with zero test or type signal. The security subagent flagged exactly this. **A malicious/confused input angle:** what about a branch named `--repo`? Rejected (leading dash) — good. A branch that is a *valid* git ref but semantically hostile, like `feat/--json`? `startswith("-")` is False, so it passes — but in argv it's a single atomic token `feat/--json`, and `gh pr view feat/--json` treats it as one operand, not a flag, because the token's first byte isn't `-`. So no injection. Confirmed safe. **The `skipped` field is a half-measure:** it prevents "skip masquerades as pass" only in the *pass* direction. The dataclass still permits `LintResult(skipped=True, error="boom")` — a nonsensical "skipped but failed" state — because the invariant lives in one code path, not `__post_init__`. A future producer could construct that. But: no such producer exists today, `aggregate_results` never gates on `skipped`, and a skip stays non-blocking regardless. **The serialization asymmetry** (`jira_skipped` top-level flag vs. lint's nested-only key) means a downstream gate script pattern-matching the established `jira_skipped` convention finds no `lint_skipped` analogue — a real consistency trap, though no such consumer exists yet. **What about a stressed filesystem?** `asyncio.to_thread(_detect_lint_command)` — if the threadpool is saturated, detection queues but never blocks the loop; on `Path.exists` raising (permission error), it propagates out of `to_thread` and is caught by `check_lint`'s existing broad `except Exception` → `result.error` set — degraded but truthful, not a crash. **Verdict of the exercise:** every attack I can construct either hits the guard or is neutralized by argv-exec semantics. The uncovered items are latent-fragility and consistency nits, not live defects. Nothing here rises to High/Critical.

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** All four ACs are implemented correctly, minimally, and are mutation-proven by their tests. The core deliverable — the `gh`/`jira` argument-injection guard — was independently verified **complete and correct** by the security specialist (all 4 subprocess sites enumerated; both live positional vectors guarded before reachability; `repo` correctly scoped out as an option-value; no `startswith("-")` bypass against the real CLI parsers). Rule-checker returned clean across 16 rules / 34 instances. No Critical or High findings. Zero regressions (the 16 broader-suite failures were proven pre-existing on `develop` at `d804d01a3`, independent of this diff).

**Data flow traced:** untrusted `branch` (CLI) → `_reject_option_like` guard (`finish.py:204`, rejects leading-`-` → truthful error, no subprocess) → `gh pr view` argv / fallback `_lookup_merged_pr_by_branch` (both reached only post-guard). Safe. Identical path for `jira_key` at `finish.py:317`.

**Pattern observed:** single shared guard helper reused at both call sites (SOUL #2), return-don't-throw error surfacing (SOUL #10) consistent with the file's existing `result.error` idiom — `finish.py:139,204,317`.

**Error handling:** guard returns a truthful error string rather than launching a subprocess or raising; `asyncio.to_thread` offload propagates stat errors into the existing `except Exception` → `result.error` path (degraded-but-truthful).

**Confirmed findings (all deferred — Medium/Low, non-blocking):**
- `[TEST]` (M) No symmetric over-reach test for a legit `jira_key` — the shared helper is transitively proven by the branch over-reach test, but a jira-specific test would localize it. `test_155_14_preflight_hardening.py`.
- `[TYPE]` (M) `to_dict()` serialization asymmetry: `lint.skipped` nests under `lint` with no top-level flag, unlike `jira_skipped`. Consistency nit; no consumer breaks. `finish.py:93`.
- `[TYPE]` (M) `LintResult` invariant (`skipped ⇒ clean, no error`) is convention-only, not enforced by `__post_init__`. `finish.py:37`.
- `[SEC]` (L) `_lookup_merged_pr_by_branch` has no internal guard — safe only by caller invariant (defense-in-depth). `finish.py:155`.
- `[SEC]` (L) `check_acceptance_criteria` `story_id` path-traversal (CWE-22) — **pre-existing, out of scope**; owned by sibling 155-7. `finish.py:357`.
- `[TYPE]` (L) `kind: str` → `Literal["branch","jira key"]`; `[TYPE]` (L) `aggregate_results` doesn't read `lint.skipped` (by design); `[TEST]` (L) single-dash `-R` case not exercised; `[TEST]` (L) skip test doesn't also assert `clean is True`.
- `[EDGE]` `[SILENT]` `[DOC]` `[SIMPLE]` — subagents disabled via `workflow.reviewer_subagents`; domains spot-checked by Reviewer (no edge/silent-failure/doc/complexity concerns in a +40-line additive diff).
- `[RULE]` clean — 0 violations (rule-checker, exhaustive).

**Handoff:** To SM for finish-story.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### TEA (test design)
- **Improvement** (non-blocking): `check_acceptance_criteria` also performs blocking I/O in an async function — `session_file.exists()` and `session_file.read_text()` on the event-loop thread. Affects `pennyfarthing-dist/src/pf/preflight/finish.py` (`check_acceptance_criteria`, ~L319-326). Out of scope for 155-14 (title scopes "async stat" to lint detection), but the same lang-review #9 defect. Candidate follow-up. *Found by TEA during test design.*
- **Improvement** (non-blocking): `check_pr_status` (L219) and `check_lint` (L274) use broad `except Exception as e` — the epic-155 narrow-catch direction (see sibling 155-16) would tighten these to `(OSError, json.JSONDecodeError)`. Not required by 155-14's ACs; noting for consistency. Affects `pennyfarthing-dist/src/pf/preflight/finish.py`. *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation. (Both TEA findings above confirmed accurate while editing; neither is in 155-14's scope — left for follow-up.)

### Reviewer (code review)
- **Improvement** (non-blocking): `to_dict()` serializes `lint.skipped` as a nested key only, while `jira_skipped` also emits a top-level flag + collapsed dict — same "not checked" concept, two wire shapes. Affects `pennyfarthing-dist/src/pf/preflight/finish.py` (`PreflightResult.to_dict`, ~L93-105) — unify the two conventions. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `LintResult` permits contradictory `skipped=True, error=...` states; the skipped⇒clean invariant is convention-only. Affects `pennyfarthing-dist/src/pf/preflight/finish.py` (`LintResult`, L37) — consider `__post_init__` enforcement or a sum type. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_lookup_merged_pr_by_branch` has no internal arg-guard — safe only by the `check_pr_status` caller invariant; a future second caller would silently reopen CWE-88. Affects `pennyfarthing-dist/src/pf/preflight/finish.py` (L155) — add belt-and-suspenders `_reject_option_like(branch, "branch")` or assert. *Found by Reviewer during code review.*
- **Gap** (non-blocking): no symmetric over-reach test proving a legitimate `jira_key` still reaches `jira issue view` after guarding; single-dash (`-R`) injection case not exercised. Affects `pennyfarthing-dist/src/pf/tests/test_155_14_preflight_hardening.py` — add the two cases. *Found by Reviewer during code review.*
- **Gap** (non-blocking): `check_acceptance_criteria` builds a path from unguarded `story_id` (CWE-22 path traversal), and still does blocking `exists()`/`read_text()` on the event loop (lang-review #9). Pre-existing, OUT OF SCOPE for 155-14 — path-traversal owned by sibling 155-7, async-I/O echoes TEA's earlier finding. Affects `pennyfarthing-dist/src/pf/preflight/finish.py` (`check_acceptance_criteria`, ~L319-357). *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### TEA (test design)
- **Dropped `repo` from the arg-injection guard scope**
  - Spec source: story title (155-14), AC-1 "gh arg-injection guard"
  - Spec text: "gh arg-injection guard"
  - Implementation: Tests guard only the bare *positionals* (`branch`, `jira_key`); `repo` is passed as the value to `--repo` and is not an option-position vector, so no guard/test is written for it.
  - Rationale: A subprocess value consumed by an explicit option flag cannot be reinterpreted as a flag — guarding it would be a vacuous test (lang-review #6). Focuses the guard on the real CWE-88 vectors.
  - Severity: minor
  - Forward impact: none — if a future call passes `repo` as a positional, a new guard/test would be needed.
- **AC1 contract accepts two implementations (reject OR `--` marker)**
  - Spec source: story title (155-14), AC-1
  - Spec text: "gh arg-injection guard"
  - Implementation: The security-property assertion (`_token_is_neutralized`) passes for either a reject-before-launch guard or a `--` end-of-options marker, rather than pinning one mechanism.
  - Rationale: Both fully neutralize the injection; over-specifying the mechanism would couple the test to one implementation.
  - Severity: minor
  - Forward impact: none.

### Dev (implementation)
- No deviations from spec. Implemented exactly what the four failing tests required — reject-guard for the two positionals (AC1), `skipped` field + `to_dict` surfacing (AC2), `asyncio.to_thread` stat offload (AC3), and the skip-branch early return (AC4). No abstractions added beyond the single `_reject_option_like` helper the guard tests demand.

### Reviewer (audit)
- **TEA: Dropped `repo` from the arg-injection guard scope** → ✓ ACCEPTED by Reviewer: the `reviewer-security` specialist independently enumerated all subprocess sites and confirmed `repo` is consumed as the *value* of `--repo` (never a bare positional), so a leading-dash `repo` is not reparsed as a flag by gh's Cobra/pflag parser. Not a CWE-88 vector — correct scope boundary.
- **TEA: AC1 contract accepts two implementations (reject OR `--` marker)** → ✓ ACCEPTED by Reviewer: Dev chose *reject*; security analysis confirms reject is the safer choice (subprocess never launches → no residual injection path, unlike a misplaced `--`). Sound.
- **Dev: No deviations from spec** → ✓ ACCEPTED by Reviewer: verified against the diff — implementation matches the four ACs with no undocumented divergence. No UNDOCUMENTED deviations found during review.