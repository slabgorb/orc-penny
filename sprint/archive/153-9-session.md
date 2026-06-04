---
story_id: "153-9"
jira_key: ""
epic: "153"
workflow: "tdd"
---
# Story 153-9: Fix test_git_utils.py leaking a feature/test checkout onto the live repo (full pytest suite silently switches the working branch)

## Story Details
- **ID:** 153-9
- **Jira Key:** (none — kanban-only project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 3
- **Type:** bug
- **Priority:** p1

## Workflow Tracking
**Workflow:** tdd
**Phase:** review
**Phase Started:** 2026-06-04T20:14:51Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-04T00:00:00Z | 2026-06-04T00:00:00Z | 0m |
| red | 2026-06-04T00:00:00Z | 2026-06-04T17:56:48Z | 17h 56m |
| green | 2026-06-04T17:56:48Z | 2026-06-04T18:02:38Z | 5m 50s |
| review | 2026-06-04T18:02:38Z | 2026-06-04T18:12:50Z | 10m 12s |
| green | 2026-06-04T18:12:50Z | 2026-06-04T20:14:51Z | 2h 2m |
| review | 2026-06-04T20:14:51Z | - | - |

## Story Summary

**Root Cause:** Running the full pytest suite (`pytest pennyfarthing-dist/src/pf/tests/`) silently switches the live working tree onto a stale branch named 'feature/test'. The test_git_utils.py module exercises `git_utils.create_or_checkout_branch()` and `create_feature_branches()` with branch 'feature/test' using tmp_path fixtures, but a checkout leaks onto the process cwd (the real repo). The leaked branch predates recent work (e.g. loader.py without find_story_in_data), breaking imports and cascading bogus failures across unrelated modules.

**Acceptance Criteria:**
1. Running the full pytest suite leaves the working tree on its original branch — no 'feature/test' (or any) checkout leaks onto the live repo
2. create_or_checkout_branch and create_feature_branches pin all git subprocess calls to the passed repo path; none rely on process cwd
3. A regression test asserts the helper does not change the branch of a repository other than the one explicitly passed in
4. The git_utils tests run hermetically against tmp_path fixtures only, with no side effects on the surrounding repository

## Technical Approach

1. **Audit git_utils helpers** — Review `create_or_checkout_branch()` and `create_feature_branches()` in pennyfarthing-dist/src/pf/git/utils.py to identify any subprocess calls that implicitly use process cwd instead of the explicit repo path parameter
2. **Pin subprocess calls** — Refactor any git subprocess invocations to explicitly pass the repo path via `cwd` parameter, eliminating implicit reliance on process cwd
3. **Add regression test** — Create a test that runs git operations on a temporary repository and verifies the original repo's branch is unchanged
4. **Verify hermetic tests** — Ensure all git_utils tests use tmp_path fixtures with isolated repositories and no side effects on the outer repository

## Sm Assessment

**Routing:** tdd workflow, 3 pts, bug, p1 — phased pipeline (setup → red → green → review → finish). Setup complete; handing off to TEA (Igor) for the RED phase.

**Why this story now:** Highest-priority bug in the backlog and foundational — the full pytest suite currently corrupts the live working tree by leaking a `feature/test` checkout onto the real repo, which has bitten epic 153 work twice. Until this is fixed we cannot safely run a full suite, so it blocks reliable verification for every downstream story.

**Context for TEA:** Root cause and four acceptance criteria are documented above. The fix lives in `pennyfarthing-dist/src/pf/git/utils.py` (`create_or_checkout_branch`, `create_feature_branches`). RED phase must produce failing tests that (a) prove a git helper called against a tmp_path repo does NOT change the surrounding repo's branch, and (b) assert all subprocess calls are pinned to the passed repo path rather than process cwd. Tests must be hermetic — tmp_path fixtures only, zero side effects on the outer repo. **Note for whoever writes/runs tests:** because this very bug switches branches via the live repo, avoid running the full suite to verify — use targeted test runs (the `testing-runner` subagent) until the fix lands.

**Repo:** pennyfarthing/ (gitflow → develop). Branch `feat/153-9-git-utils-test-branch-leak` created. Orchestrator stays on `main`.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Bug fix with an explicit regression-test acceptance criterion.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_git_utils_isolation.py` (new) — two RED regression tests for the branch leak.

**Tests Written:** 2 tests covering ACs 1 and 4 (ACs 2 & 3 verified already-satisfied by source — see Design Deviations).
**Status:** RED (failing — ready for Dev). Verified via scoped run: `cd pennyfarthing-dist && uv run pytest src/pf/tests/test_git_utils_isolation.py -q` → `2 failed`. Live repo branch unchanged before/after the run. (Full suite NOT run — it is the documented leak; scoped run per the `scoped-red-run` pattern.)

| Test | AC | Mechanism | Status |
|------|-----|-----------|--------|
| `test_partial_failure_tests_do_not_leak_branch_to_outer_repo` | AC1, AC4 | Runs the offending `-k partial_failures` tests inside an isolated sandbox repo (cwd + `PROJECT_ROOT` pinned); asserts the sandbox branch is unchanged. RED: sandbox switched `main` → `feature/test`. | failing |
| `test_git_utils_tests_use_no_live_cwd_repo_paths` | AC4 | Static guard: asserts `test_git_utils.py` contains no live-cwd repo path (`Path(".")` / `Path.cwd()`). RED: `Path(".")` present. | failing |

**Root cause (for Dev):** Not the source — every git call in `create_branches.py` already pins `cwd=path`. The leak is `test_git_utils.py` passing `Path(".")` (the live repo) into `create_feature_branches`; `should_create_branch(None)` is permissive for the unknown `"good-repo"`, so a real `checkout develop` + `checkout -b feature/test` runs against the surrounding repo.

**Fix shape:** Test hygiene only — make the two partial-failure tests use a `tmp_path` git repo instead of `Path(".")` (details in Delivery Findings). No production code change; do not add a source guard.

**Self-check:** Both tests carry meaningful behavioral/static assertions; the meta-test guards against false-green by asserting the inner tests actually ran. No vacuous assertions.

**Handoff:** To Dev (Ponder Stibbons) for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/tests/test_git_utils.py` — `test_status_all_handles_partial_failures` and `test_branches_handles_partial_failures` now use the existing `temp_git_repo` (`tmp_path`) fixture instead of `Path(".")`, so neither test operates on the live repo.
- `pennyfarthing-dist/src/pf/tests/test_git_utils_isolation.py` — ruff-format only (regression tests authored by TEA in RED).

**No source/production change.** Per TEA's finding (and verified independently): every git call in `create_branches.py` already pins `cwd=path`, so AC2/AC3 hold as-is. No source guard added — operating on a repo it is explicitly handed is correct behavior (`pf git branches .`).

**Tests:** 59/59 passing (GREEN) — `test_git_utils.py` 57 + `test_git_utils_isolation.py` 2. Lint (`ruff check`) and format clean.

**Leak proof (AC1):** Ran the full `test_git_utils.py` (57 passed) and confirmed the live working branch (`feat/153-9-git-utils-test-branch-leak`) was unchanged before and after — the checkout no longer leaks. Verified directly via scoped `uv run pytest` rather than `testing-runner` (this story is about test side-effects; per the `testing-runner-can-mutate-source` gotcha).

**AC coverage:**
- AC1 (full suite leaves working tree on original branch) — proven by the before/after branch check above.
- AC2/AC3 (git calls pinned to passed path / regression test) — already satisfied by source; enforced by the isolation regression tests.
- AC4 (tests hermetic, tmp_path only) — both offending tests now use `temp_git_repo`; static guard passes.

**Branch:** `feat/153-9-git-utils-test-branch-leak` (pushed, commit `fb80543f1`, signed).

**Handoff:** To Reviewer (Granny Weatherwax) for code review.

### Dev Rework — round 1 (addressing Reviewer REJECT)

Commit `9c8c9781f` (signed, pushed). All five Reviewer findings fixed in the regression tests; no production change.

| Reviewer finding | Fix |
|------------------|-----|
| [HIGH] vacuous false-green guard (`"no tests ran"` never printed; pytest says `deselected`/exit 5) | replaced with `assert result.returncode == 0` (0=ran+passed, 4=collection err, 5=none collected) |
| [HIGH] `_make_repo` swallowed git failures → could false-green if `develop` absent | `_git_checked` on every setup step + assert `develop` branch exists and start==`main` |
| [MED] no subprocess timeout | `timeout=120` on the inner pytest, `pytest.fail` on `TimeoutExpired` |
| [MED] static guard scanned comments + missed `os.getcwd()` | replaced substring scan with **AST-based** `_live_cwd_calls` — ignores comments/docstrings, catches `Path(".")`/`Path.cwd()`/`os.getcwd()`/`Path(os.curdir)` |
| [MED] partial-failure tests asserted only `len==2` | now assert good-repo succeeded (error None / action CREATED|CHECKED_OUT) and bad-repo skipped/errored |

**Guards proven non-vacuous** (the precise failure of the original): AST guard catches each planted vector and ignores the file's own prose; `returncode==0` gate rejects rc 4 and rc 5 (verified empirically). 59 passed, ruff clean, live branch unchanged before/after.

**Handoff:** Back to Reviewer (Granny Weatherwax) for re-review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (59 passed, lint clean, no branch leak) | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 7 | confirmed 4 (guard/timeout/_make_repo/static-vectors), dismissed 0, deferred 3 (low-prob env/default-branch) |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 4 | confirmed 2 (false-green via _make_repo + returncode), dismissed 0, deferred 2 (pre-existing fixture check=False, dup) |
| 4 | reviewer-test-analyzer | Yes | findings | 4 | confirmed 4 (vacuous guard, static brittleness, 2× missing assertions) |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings |
| 6 | reviewer-type-design | No | Skipped | disabled | Disabled via settings |
| 7 | reviewer-security | Yes | clean | none (3 rules checked, 0 violations) | N/A |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings |
| 9 | reviewer-rule-checker | No | Skipped | disabled | Disabled via settings (rule-by-rule done by Reviewer below) |

**All received:** Yes (5 enabled returned, 4 disabled pre-filled)
**Total findings:** 6 confirmed (2 High, 4 Medium/Low), 0 dismissed, 5 deferred/non-blocking

## Reviewer Assessment

**Verdict:** REJECTED

The fix itself is correct and verified — swapping `Path(".")` → `temp_git_repo` removes the leak (preflight: 59 passed, full `test_git_utils.py` leaves the live branch unchanged). The rejection is about the **regression tests' trustworthiness**: this story's deliverable IS a reliable leak guard, and the meta-test's false-green guard is provably vacuous.

### Rule Compliance (pennyfarthing-dist/gates/lang-review/python.md, all 13 checks enumerated)

- **#1 silent exceptions** — `_git(..., check=False)` is deliberate (not an `except: pass`), but it discards returncodes in `_make_repo`, feeding finding [SILENT-1]. No bare excepts. → finding, not clean.
- **#2 mutable defaults** — none. ✓
- **#3 type annotations** — all new functions annotated (`_git(repo: Path, *args: str) -> subprocess.CompletedProcess`, `_make_repo(repo: Path) -> str`, `_current_branch(repo: Path) -> str`, tests `-> None`). ✓
- **#4 logging** — N/A (test code, no logging). ✓
- **#5 path handling** — pathlib throughout; `Path(__file__).resolve()` before use; `write_text`/`read_text` (UTF-8 default, acceptable for tests). ✓
- **#6 test quality** — **FAIL**: vacuous false-green guard [TEST]/[EDGE]/[SILENT], plus two `len(results)==2`-only assertions whose `# one should error, one should not` comment is never asserted [TEST].
- **#7 resource leaks** — `subprocess.run` (no leak), no unclosed handles. ✓
- **#8 unsafe deserialization** — none; security subagent confirmed (no pickle/eval/exec, no shell=True, args are fixed lists). ✓
- **#9 async pitfalls** — modified tests add a fixture param only; no blocking calls introduced; source `asyncio.gather` not in diff. ✓
- **#10 import hygiene** — `os, subprocess, sys, pathlib.Path`; no star imports, no cycles. ✓
- **#11 input validation** — no external input; subprocess path derived from `__file__`. ✓
- **#12 dependency hygiene** — no dependency changes. ✓
- **#13 fix-introduced regressions** — the `temp_git_repo` swap introduces no new check #1–#12 violation. ✓

### Observations

- **[HIGH][TEST][EDGE][SILENT] Vacuous false-green guard** at `test_git_utils_isolation.py:91` — `assert "no tests ran" not in result.stdout.lower()` is meant to prove the inner tests actually ran. **Verified empirically:** a zero-match `-k` prints `"57 deselected"` (exit 5) and a collection/import error exits 4 — *neither* produces "no tests ran". The guard can never fire. If a future change renames the inner tests or breaks their import, the meta-test runs zero leak-exercising tests, `end_branch == start_branch` passes trivially, and the regression silently stops guarding. Fix: `assert result.returncode == 0` (verified: real run rc=0, zero-match rc=5, error rc=4) and/or assert the expected tests ran (`"passed" in result.stdout`).
- **[HIGH][SILENT] `_make_repo` setup failures are swallowed** at `test_git_utils_isolation.py:38-55` — every `_git()` uses `check=False` and returncodes are discarded. If the `develop` branch (the precondition the leak path needs) silently fails to create, a future reintroduced leak would not fire and the meta-test false-greens. Fix: check returncodes / assert the `develop` branch exists before launching the inner pytest.
- **[MEDIUM][EDGE] No `timeout=` on the inner pytest subprocess** at `test_git_utils_isolation.py:80` — a hung inner test (e.g. a git credential prompt) hangs the outer run and CI indefinitely. Fix: add `timeout=` with a clear failure message.
- **[MEDIUM][TEST] Static guard scans comments/docstrings and misses vectors** at `test_git_utils_isolation.py:108-116` — the substring scan trips on prose containing the literal (it already forced a comment reword during GREEN) and misses `os.getcwd()` / `Path(os.curdir)`. Fix: add those vectors and exclude comment/docstring lines (or note the isolation file's own docstring is exempt).
- **[MEDIUM][TEST] Modified partial-failure tests assert only `len(results)==2`** at `test_git_utils.py:632,645` — the `# one should have error, one should not` comment is never asserted; both-error or both-success would pass. Since the diff already touches these tests, strengthen: assert good-repo succeeded (no error / action not ERROR) and bad-repo errored. (Pre-existing gap, but in the modified lines.)
- **[VERIFIED] The core fix is correct** — `test_git_utils.py:626,639` now pass `temp_git_repo` (the tmp_path fixture at lines 47-70, with `main`+`develop`), not `Path(".")`. Evidence: preflight ran the full `test_git_utils.py` (57 passed) with the live branch `feat/153-9-git-utils-test-branch-leak` unchanged before/after. Complies with python.md #5/#6 and AC4.
- **[VERIFIED][SEC] No security exposure** — security subagent checked python.md #5/#8/#11 across 6 call sites: subprocess uses fixed-list args (no `shell=True`), path from `__file__.resolve()`, no deserialization. Evidence: `test_git_utils_isolation.py:36,80`.
- **[DOC] (subagent disabled)** — assessed by Reviewer: the new file's module docstring and AC mapping are accurate and match the verified behavior. No stale/misleading docs. ✓
- **[TYPE] (subagent disabled)** — assessed by Reviewer: no new types/dataclasses; annotations present and correct (see #3). ✓
- **[SIMPLE] (subagent disabled)** — assessed by Reviewer: the meta-test (subprocess-pytest) is heavier than a pure-unit test, but it is the only faithful way to observe a test-suite side-effect; not over-engineered. The static guard is a reasonable cheap second line. No unnecessary complexity to remove. ✓
- **[RULE] (subagent disabled)** — exhaustive rule-by-rule enumeration done by Reviewer in the Rule Compliance section above; the only failing rule is #6 (test quality), captured in the findings.

### Devil's Advocate

Argue the code is broken. The whole point of story 153-9 is a *durable* guard against the `feature/test` leak — yet the headline regression test, `test_partial_failure_tests_do_not_leak_branch_to_outer_repo`, can pass while testing nothing. I proved pytest emits "deselected" (exit 5), not "no tests ran", so the false-green guard is dead code: rename the inner tests, or let `pf.git.create_branches` become unimportable, and the inner pytest collects zero leak-exercising tests, the sandbox branch is trivially unchanged, and the meta-test reports GREEN. A future developer could literally revert the `temp_git_repo` fix, rename the partial-failure tests during an unrelated refactor, and this guard would wave it through — the exact regression it exists to prevent. Worse, `_make_repo` swallows every git error: on a machine where commit signing is forced or `init.defaultBranch` is patched mid-run, the `develop` branch may never be created, so even a faithfully-reintroduced leak has no branch to check out, and again the test false-greens. A confused maintainer reading "2 passed" would trust a guard that guards nothing. The static guard is similarly soft: it already false-positived on its own comment text during GREEN (forcing a reword), and it misses `os.getcwd()` — so a future leak introduced via `os.getcwd()` instead of `Path(".")` sails past both guards. And a stressed CI box that hangs the inner pytest (no `timeout=`) would wedge the whole suite. None of this breaks the *current* behavior — the fix works today — but the deliverable is a trustworthy guard, and a guard with a vacuous liveness check is the software equivalent of a smoke detector with the battery removed. The two High findings (returncode assertion + verify `develop`) close the false-green hole cheaply; without them the PR ships false assurance.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | False-green guard is vacuous (pytest emits "deselected"/exit 5, never "no tests ran"); meta-test can pass while running zero leak tests | `test_git_utils_isolation.py:91` | Replace with `assert result.returncode == 0`; optionally assert expected tests ran (`"passed" in stdout`) |
| [HIGH] | `_make_repo` swallows git failures; if `develop` isn't created the leak path is unreachable → false green | `test_git_utils_isolation.py:38-55` | Check `_git` returncodes / assert `develop` branch exists before the inner pytest run |
| [MEDIUM] | No `timeout=` on inner pytest subprocess — a hung inner test hangs CI | `test_git_utils_isolation.py:80` | Add `timeout=` with a diagnostic message |
| [MEDIUM] | Static guard scans comments/docstrings (already churned GREEN) and misses `os.getcwd()`/`os.curdir` | `test_git_utils_isolation.py:108-116` | Add the missing vectors; exclude comment/docstring lines or note the file's own docstring is exempt |
| [MEDIUM] | Partial-failure tests assert only `len==2`; never assert "one errored, one succeeded" | `test_git_utils.py:632,645` | Assert good-repo succeeded and bad-repo errored |

**Handoff:** Back to TEA (Igor) for red rework — these are test-design robustness fixes to the regression tests TEA authored.

## Delivery Findings

No upstream findings at setup.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (blocking): `test_branches_handles_partial_failures` and `test_status_all_handles_partial_failures` pass `("good-repo", Path("."))` — the live repo — into the branch/status helpers, so the suite checks out `feature/test` on the surrounding repository. Affects `pennyfarthing-dist/src/pf/tests/test_git_utils.py` (replace `Path(".")` with a `tmp_path`-based git repo fixture so both tests are hermetic; the `bad-repo` `Path("/nonexistent")` entry is fine as-is). **Do NOT add a source guard** to `create_or_checkout_branch` — operating on the repo it is handed is correct (`pf git branches .`); the fix is test hygiene only. *Found by TEA during test design.*
- **Improvement** (non-blocking): During this story the pennyfarthing checkout was switched off `feat/153-9-git-utils-test-branch-leak` to `chore/portrait-cdn-configurable-base` by concurrent portrait-CDN work and a commit landed there — a live instance of the shared-checkout branch-coordination hazard this story addresses. Affects developer workflow (multiple sessions sharing one working tree). Surfaced as context, not part of this story's scope. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): The static guard `test_git_utils_tests_use_no_live_cwd_repo_paths` does a naive whole-file substring match for `Path(".")`, so even a *comment* mentioning the literal trips it (it did during GREEN until I reworded my comments). Affects `pennyfarthing-dist/src/pf/tests/test_git_utils_isolation.py` (could scope the check to argument positions / non-comment lines if it proves annoying). Low priority — the guard works and catches the real anti-pattern. *Found by Dev during implementation.*
- **Improvement** (non-blocking): The shared-checkout branch switching TEA flagged recurred during GREEN — the checkout was moved feat/153-9 → `develop` (portrait commit cherry-picked there) between RED handoff and GREEN start; I switched back (clean tree, no work lost). Reinforces the coordination hazard; out of scope here. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (blocking): The meta-test's false-green guard is vacuous — empirically verified that pytest emits `"deselected"`/exit 5 (not "no tests ran") for a zero-match `-k`, and exit 4 for collection errors. The regression can pass while running zero leak-exercising tests. Affects `pennyfarthing-dist/src/pf/tests/test_git_utils_isolation.py:91` (replace with `assert result.returncode == 0`, optionally assert `"passed" in stdout`). *Found by Reviewer during code review.*
- **Gap** (blocking): `_make_repo` swallows git returncodes; if the `develop` branch isn't created the leak path is unreachable and the meta-test false-greens. Affects `pennyfarthing-dist/src/pf/tests/test_git_utils_isolation.py:38-55` (verify each `_git` succeeded / assert `develop` exists before the inner run). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): No `timeout=` on the inner pytest subprocess (`:80`) → a hung inner test wedges CI; static guard (`:108-116`) scans comments/docstrings and misses `os.getcwd()`/`os.curdir`; the two modified partial-failure tests (`test_git_utils.py:632,645`) assert only `len==2` and never assert "one errored, one succeeded". Affects `test_git_utils_isolation.py` and `test_git_utils.py`. *Found by Reviewer during code review.*

## Design Deviations

None at setup.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **AC2/AC3 already satisfied by source; regression reframed to suite-hermeticity**
  - Spec source: context-story-153-9.md, AC-2 and AC-3
  - Spec text: "create_or_checkout_branch and create_feature_branches pin all git subprocess calls to the passed repo path; none rely on process cwd" and "A regression test asserts the helper does not change the branch of a repository other than the one explicitly passed in"
  - Implementation: Verified every git call in `create_branches.py` already passes `cwd=path` — the source does NOT rely on process cwd, so AC2 holds today. The leak is test-only: `test_git_utils.py` passes `Path(".")` (the live repo) into the helpers, and `should_create_branch(None)` is permissive for unknown repos, so a real `checkout` runs against the surrounding repo. The regression tests therefore assert the test SUITE leaves the surrounding repo's branch unchanged (a behavioral meta-test running the offending tests in a sandbox + a static guard), instead of an AC3-literal helper-isolation property that already passes.
  - Rationale: An AC3-literal test (cwd=bystander, target=other repo → bystander unchanged) passes against current source, so it would not be RED and would not drive the real fix. Asserting "helper must refuse a cwd/`Path(".")` target" would force a source guard that breaks legitimate `pf git branches .` usage where operating on the cwd repo is correct.
  - Severity: minor
  - Forward impact: Dev fix is test-file hygiene (use a `tmp_path` git repo), not a source change; no production behavior changes.

### Dev (implementation)
- No deviations from spec. Implemented exactly the fix shape TEA specified: swapped `Path(".")` for the existing `temp_git_repo` `tmp_path` fixture in both partial-failure tests; no source/production change.

### Reviewer (audit)
- **TEA: "AC2/AC3 already satisfied by source; regression reframed to suite-hermeticity"** → ✓ ACCEPTED by Reviewer: independently confirmed — every git call in `create_branches.py` passes `cwd=path`, and preflight ran the full `test_git_utils.py` with the live branch unchanged. Reframing the regression to suite-hermeticity is sound; forcing a source guard would break legitimate `pf git branches .`. The reframing is accepted; my rejection is about the *robustness* of that regression test (vacuous false-green guard), not the reframing decision.
- **Dev: "No deviations from spec"** → ✓ ACCEPTED by Reviewer: the implementation is exactly the agreed `Path(".")` → `temp_git_repo` swap; no undocumented divergence.
- No undocumented deviations found. The two High findings are robustness gaps in the regression test, not spec deviations.