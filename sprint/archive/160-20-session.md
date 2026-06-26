---
story_id: "160-20"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 160-20: Fix missing-await in Frame brownfield routes

## Story Details
- **ID:** 160-20
- **Jira Key:** (local only — no Jira claim)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-26T22:03:03Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-26T21:34:30Z | 2026-06-26T21:34:30Z | immediate |
| red | 2026-06-26T21:34:30Z | 2026-06-26T21:49:18Z | 14m 48s |
| green | 2026-06-26T21:49:18Z | 2026-06-26T21:55:31Z | 6m 13s |
| review | 2026-06-26T21:55:31Z | 2026-06-26T22:03:03Z | 7m 32s |
| finish | 2026-06-26T22:03:03Z | - | - |

## Technical Approach

The Frame brownfield analysis routes (`get_dead_code`, `get_complexity`, `get_dependencies`) invoke async helper functions (`find_stale_files`, `analyze_complexity`, `analyze_dependencies`) but fail to await the coroutines. This causes:
- RuntimeWarning: coroutine never awaited
- Functions return coroutine objects instead of real results
- Analysis features broken

**Fix:** Add `await` keyword to all three coroutine calls in the brownfield route handlers.

**Acceptance Criteria:**
1. All three coroutine calls are properly awaited in Frame brownfield routes
2. Routes return actual analysis results (not coroutine objects)
3. RuntimeWarning messages are eliminated
4. Tests verify the routes execute and return expected data structures

## Story Context
**Type:** Bug  
**Points:** 2  
**Priority:** p1

**Acceptance Criteria:**
- [ ] RuntimeWarning: coroutine never awaited is gone
- [ ] get_dead_code, get_complexity, get_dependencies return real results
- [ ] Tests pass for all three routes

**Related Finding:** Discovered during 160-17 (Dev phase) brownfield analysis.

## SM Assessment

Story selected as the next p1 from the 160-16/160-17 Frame fail-loud review cycle (tied with 160-18/160-19; chosen for highest real-world impact — these routes silently never execute). Independent, no `depends_on`, no Jira (local-only sprint). Scope is tight and well-specified: three brownfield route handlers in `pf/frame/` call async helpers (`find_stale_files`, `analyze_complexity`, `analyze_dependencies`) without `await`.

Routing: explicit `tdd` workflow tag honored over the 2pt-trivial default — a missing-await bug needs RED tests proving the routes actually execute and return real results (not coroutine objects) before the one-line-ish fix lands. Handing to TEA (Lord Melchett) for the RED phase. Branch `feat/160-20-frame-brownfield-await-fix` off `develop`.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Bug fix with behavioral ACs — the routes must actually execute the analysis and return real results, not coroutine objects.

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_160_20_frame_brownfield_await.py` (new) — 6 tests, two layers.

**Tests Written:** 6 covering the 3 routes / 3 ACs.
**Status:** RED — **6 failed, 0 errored** (verified via scoped `uv run pytest <file>`).

### Coverage

| Route | Layer 1 — executed-flag + sentinel | Layer 2 — real helper → 200 | Bugs caught |
|-------|------------------------------------|------------------------------|-------------|
| get_dead_code | `test_get_dead_code_awaits_and_returns_real_result` | `test_dead_code_real_helper_returns_200` | await + `len(DeadCodeResult)` |
| get_complexity | `test_get_complexity_awaits_and_returns_real_result` | `test_complexity_real_helper_returns_200` | await + str→Path |
| get_dependencies | `test_get_dependencies_awaits_and_returns_real_result` | `test_dependencies_real_helper_returns_200` | await + str→Path |

**RED evidence (right-reason failures):**
- Layer 1 (×3): `assert executed["ran"] is True` fails → "helper coroutine was never awaited — the analysis never executed" (the async body never runs on the `to_thread` path).
- Layer 2 dead-code: HTTP 500 `"object of type 'coroutine' has no len()"`.
- Layer 2 complexity/deps: HTTP 500 `"Object of type coroutine is not JSON serializable"`.

**Self-check:** 0 vacuous tests — every test asserts status **and** content; Layer 1 also asserts the execution flag.

### Fix interface for Dev (GREEN) — `pf/frame/routes/analysis.py`
The three helpers are `async def`, so `asyncio.to_thread(fn, ...)` is wrong (it returns an un-awaited coroutine). Await them directly, AND fix the two secondary bugs the await currently masks:
- `get_dead_code`: `result = await find_stale_files(project_dir)` **and** change `len(result)` → `len(result.stale_files)` (DeadCodeResult has no `__len__`). Note `_safe_to_dict(result)` then serializes the whole DeadCodeResult — confirm the `{"files", "total"}` shape you want.
- `get_complexity`: `result = await analyze_complexity(Path(project_dir))` (helper does `target_path.resolve()` — needs a `Path`).
- `get_dependencies`: `result = await analyze_dependencies(Path(project_dir))` (same Path requirement).
- The "RuntimeWarning: coroutine never awaited" AC is satisfied automatically once the coroutines are awaited (tested indirectly — see Design Deviations).

**Handoff:** To Dev (Baldrick) for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/routes/analysis.py` — awaited the three async helpers directly (dropped the `asyncio.to_thread` wrap), wrapped `project_dir` in `Path(...)`, and fixed `get_dead_code` to use `result.stale_files` for both the serialized list and the `total` count.

**Tests:** 6/6 passing (GREEN) — `test_160_20_frame_brownfield_await.py`.
**Regression:** 70 `test_frame_routes.py` + 72 frame/sweep batch (160-16/17, 159-8, 161-1, frame_server) all green. `ruff check` clean.
**Live smoke test:** `PF_PROJECT_DIR=<repo>` → `/api/dead-code` **200** with **20 real stale files**; `/api/complexity` & `/api/dependencies` **200** with real `*Result` dicts degrading gracefully (eslint/npm absent) and `target_path` correctly resolved — proves the `Path` fix end-to-end, not just under mocks.
**Branch:** `feat/160-20-frame-brownfield-await-fix` (pushed). Commit `df4d4da24`.

**Scope note:** Fixed only the 3 routes the story names. The sibling routes turned out MORE broken than "missing await" and are deferred to a new story (see Delivery Findings + Design Deviations).

**Handoff:** To Reviewer (Captain Darling) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 (76 tests green, ruff clean, 0 smells) | N/A |
| 2 | reviewer-edge-hunter | No | Skipped — disabled | N/A | Disabled via settings; covered by Reviewer |
| 3 | reviewer-silent-failure-hunter | No | Skipped — disabled | N/A | Disabled via settings; covered by Reviewer |
| 4 | reviewer-test-analyzer | No | Skipped — disabled | N/A | Disabled via settings; covered by Reviewer |
| 5 | reviewer-comment-analyzer | No | Skipped — disabled | N/A | Disabled via settings; covered by Reviewer |
| 6 | reviewer-type-design | No | Skipped — disabled | N/A | Disabled via settings; covered by Reviewer |
| 7 | reviewer-security | Yes | findings | 1 (CWE-209 `str(e)` info-leak, medium conf) | confirmed 1 (downgraded LOW, non-blocking) |
| 8 | reviewer-simplifier | No | Skipped — disabled | N/A | Disabled via settings; covered by Reviewer |
| 9 | reviewer-rule-checker | No | Skipped — disabled | N/A | Disabled via settings; covered by Reviewer |

**All received:** Yes (2 enabled returned; 7 disabled via `workflow.reviewer_subagents`, covered by Reviewer directly)
**Total findings:** 1 confirmed (downgraded to LOW, non-blocking), 0 dismissed, 0 deferred

> Subagent toggles: only `preflight` + `security` enabled. Per the disabled-subagents discipline, I performed edge / silent-failure / test-quality / comment / type-design / simplifier / rule-checker analysis myself (results in Rule Compliance + Observations).

## Rule Compliance (`pennyfarthing-dist/gates/lang-review/python.md`)

| # | Rule | Applies? | Verdict | Evidence |
|---|------|----------|---------|----------|
| 9 | Async/await — missing await returns coroutine, never executes | YES (core) | ✅ Fixed | 3 routes now `await fn(...)` directly; live run shows **0** "coroutine never awaited" warnings, status 200 |
| 5 | Path handling — pathlib, `resolve()` before security checks | YES | ✅ Compliant | `Path(project_dir)` (pathlib); helpers `.resolve()` (deadcode:121, complexity:170, deps:126). No `open()` in diff → no encoding= concern |
| 1 | Silent exception swallowing | partial | ⚠️ Pre-existing | `except Exception: return {...}, 500` is unchanged context (not a changed line); surfaces the error to the client (not silent) — see [SEC] |
| 6 | Test quality — vacuous asserts, mock target | YES | ✅ Mostly | monkeypatch targets where-used (`analysis.find_stale_files`); strong executed-flag + content asserts. One LOW: Layer-2 `"success" in data` weak (status==200 is the binding gate) |
| 3 | Type annotations at boundaries | YES | ✅ Compliant | handlers `(request: Request) -> JSONResponse` |
| 2,7,8,10,11,12 | mutable defaults / resource leaks / unsafe deserialization / imports / input-validation / deps | N/A | — | not touched by diff |

## Reviewer Assessment

**Verdict:** APPROVED

**Story 160-20** fixes a real, confirmed bug: three Frame brownfield routes wrapped `async def` helpers in `asyncio.to_thread`, producing un-awaited coroutines so the analysis never ran (routes 500'd). The fix awaits the helpers directly and corrects the two secondary bugs (`len(DeadCodeResult)`, `str→Path`) that "return real results" (AC2) requires.

**Independent verification (not taken on faith):**
- **Inverse binding probe:** reverted source to `origin/develop` (keeping the new test file) → 6/6 RED; restored → 6/6 GREEN. The tests genuinely bind to the fix.
- **Real-route discharge (AC1):** `PF_PROJECT_DIR=<repo>` live run — `/api/dead-code` 200 with **20 real stale files**; `/api/complexity` & `/api/dependencies` 200 with real `*Result` dicts (graceful eslint/npm-absent), `target_path` correctly resolved. **0 "coroutine never awaited" warnings** — AC1 satisfied directly.
- **Sibling-deferral validation:** ran the out-of-scope routes — `/api/hotspots` & `/api/code-markers` 500 `analyze_repo() missing ... 'path'`; `/api/health-score` 500 `unexpected keyword argument 'use_cache'`. DISTINCT deeper bugs, not the same await fix — Dev's deferral to a separate story is correct.

**Observations:**
- [VERIFIED] AC1 — no coroutine-never-awaited warning: live `warnings.catch_warnings(record=True)` run, 0 across all 3 routes — `analysis.py:80,97,114` now `await` directly.
- [VERIFIED] AC2 — real results: dead-code returns 20 real files; complexity/deps return real result dicts at status 200 — `analysis.py:80-82,97,114`.
- [VERIFIED][TYPE] str→Path correctness: `Path(project_dir)` satisfies helpers' `target_path.resolve()` — `complexity/analyze.py:170`, `dependencies/analyze.py:126`.
- [VERIFIED][SIMPLE] minimal, no dead code: diff removes the needless `to_thread` wrap; `asyncio` still used by the 3 un-fixed sibling routes (ruff clean) — `analysis.py:63`.
- [VERIFIED][RULE] lang-review #9 (async) fixed, #5 (path) compliant — see Rule Compliance.
- [VERIFIED][DOC] no stale/misleading comments introduced; test docstring accurate.
- [VERIFIED][EDGE] env-controlled `project_dir` edge cases (missing dir / empty → cwd) degrade to graceful `success=False` 200, not crashes.
- [LOW][TEST] Layer-2 `assert "success" in data` (complexity/deps) is a weak secondary check — the 500 envelope also carries `success`; binding gate is `status == 200`, so the test is sound but `"target_path" in data` would discriminate better. Non-blocking nit — `test_160_20_frame_brownfield_await.py`.
- [LOW][SEC][SILENT] CWE-209: `except Exception as e: return {"success": False, "error": str(e)}, 500` leaks raw exception text (paths, git/eslint/npm stderr). PRE-EXISTING (context line, not a changed hunk), localhost-only binding, house style across all 7 analysis routes → confirmed, downgraded LOW, non-blocking — `analysis.py:84,101,118`.

### Devil's Advocate

Suppose this code is broken. The `get_dead_code` shape changed from (broken) whole-result serialization to `result.stale_files` — could a consumer break? No: the route never worked (always 500), so there is no working baseline to regress; the new `{files, total}` shape matches the intent encoded by the original `len(result)`. Could `Path(project_dir)` mishandle a weird env value? If `PF_PROJECT_DIR` is unset, `os.getcwd()` is used; if `""`, `Path("")` → `Path(".")` — both benign; helpers `.resolve()` and on a non-repo/non-node dir return `success=False` gracefully (verified 200, not a crash). The malicious-user angle: the routes read NO input from the HTTP request (only an unused `request: Request`); `project_dir` is operator-set env, not request-controlled — no CWE-22 vector from a client, corroborated by the security specialist. Did the await fix introduce a blocking call on the event loop? No — the helpers are genuinely async (they `await` subprocess/git via `create_subprocess_exec`), so awaiting directly is correct and non-blocking; `to_thread` was wrong precisely because the work is already async I/O. The now-reachable `str(e)` leak: a local user could read filesystem paths from a 500 body — true, but localhost-bound and local dev info, not secrets; pre-existing and tracked as a follow-up. Do the still-broken siblings mislead anyone? No: they were already broken, this PR doesn't worsen them, and the deferral is documented with reproduced evidence and a follow-up recommendation. Nothing rises to Critical/High.

**Handoff:** To SM (Edmund Blackadder) for finish-story.

## Delivery Findings

No upstream findings at setup.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (blocking): `get_dead_code` has a second bug beyond the await — `len(result)` on a `DeadCodeResult` dataclass (no `__len__`) raises `TypeError`, so the route 500s even after the await fix. Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py` (use `len(result.stale_files)` / `result.total_files`). *Found by TEA during test design.*
- **Gap** (blocking): `get_complexity` and `get_dependencies` pass a `str` (`project_dir`) to helpers whose first line is `target_path.resolve()` (Path-only) → `AttributeError` after the await fix. Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py` (wrap in `Path(project_dir)`). *Found by TEA during test design.*
- **Improvement** (non-blocking): the sibling routes `get_hotspots`, `get_health_score`, `get_code_markers` have the IDENTICAL `await asyncio.to_thread(async_fn, ...)` bug — their helpers `analyze_repo` (hotspots), `analyze_healthscore`, `analyze_repo` (codemarkers) are also `async def`. Out of this story's scope but recommend fixing in the same PR for consistency, else they stay silently broken. Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py`. *Found by TEA during test design.*
- **Improvement** (non-blocking): existing `test_frame_routes.py` tests for these routes assert `status_code in (200, 500)` + `isinstance(data, dict)`, which PASS on the 500 crash — this lax tolerance is why the bug shipped. Recommend tightening to require 200 + real-result keys. Affects `pennyfarthing-dist/src/pf/tests/test_frame_routes.py`. *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): the sibling brownfield routes have DEEPER bugs than missing-await and warrant their own story. `get_hotspots` and `get_code_markers` call `analyze_repo(name, path: Path, ...)` but pass only `project_dir` — the required `path` arg is missing (project_dir lands in `name`); `get_health_score` passes `use_cache=False` to `analyze_healthscore(target_path, weights, cache_ttl)`, which has no `use_cache` param (TypeError). Not the same one-line await fix — each needs a design decision (`name` source, `use_cache` replacement) + tests. Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py`. *Found by Dev during implementation.* (Supersedes TEA's "identical bug, same-PR" recommendation.)
- **Improvement** (non-blocking): TEA's point stands — `test_frame_routes.py` route tests accept `status_code in (200, 500)`; tightening them to require 200 + real-result keys would catch this whole bug class. A natural companion to the sibling-routes story. Affects `pennyfarthing-dist/src/pf/tests/test_frame_routes.py`. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking): CONFIRMED + seconded — sibling routes `get_hotspots`/`get_health_score`/`get_code_markers` 500 with DISTINCT deeper bugs (verified live: `analyze_repo() missing 1 required positional argument 'path'`; `analyze_healthscore() unexpected keyword argument 'use_cache'`). Needs its own story (design `name`/`path` + replace `use_cache` + tests), not a same-PR fix. **SM: file the follow-up story before/at finish.** Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): CWE-209 info-leakage — the three routes' `except Exception as e: return JSONResponse({"success": False, "error": str(e)}, 500)` returns raw exception text (filesystem paths, git/eslint/npm stderr) to the HTTP client. Pre-existing house style across all 7 analysis routes; mitigated by localhost-only Frame binding. Recommend a generic client message + server-side `logger.error(...)`. Sibling concern to backlog story 160-18 (sanitize Frame outputs before network exposure). Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py` (+ 4 sibling routes). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): seconding TEA/Dev — existing `test_frame_routes.py` route tests accept `status_code in (200, 500)`, which masked this bug class; tighten to require 200 + real-result keys. Affects `pennyfarthing-dist/src/pf/tests/test_frame_routes.py`. *Found by Reviewer during code review.*

## Design Deviations

No deviations from spec at setup.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Tests force the complete fix (await + secondary bugs), broadening the literal "missing-await" framing**
  - Spec source: context-story-160-20.md / session AC2
  - Spec text: "get_dead_code, get_complexity, get_dependencies return real results"
  - Implementation: the Layer-2 real-helper tests stay RED through an await-only fix because they also fail on the `len(DeadCodeResult)` and `str→Path` bugs, forcing Dev to fix those too.
  - Rationale: a HTTP 500 is not a "real result"; awaiting alone leaves all three routes still 500ing, so the secondary fixes are required by AC2.
  - Severity: minor
  - Forward impact: Dev's GREEN must address all sub-fixes per route (see Fix interface in TEA Assessment).
- **Sibling routes with the identical bug are flagged, not tested (scope boundary)**
  - Spec source: session scope / story title
  - Spec text: "get_dead_code/get_complexity/get_dependencies invoke ... WITHOUT await"
  - Implementation: only the 3 named routes are tested; `get_hotspots`/`get_health_score`/`get_code_markers` (same `to_thread(async_fn)` bug) are recorded as a non-blocking Delivery Finding instead.
  - Rationale: honor story scope as the highest-authority spec source; siblings are a follow-up recommendation.
  - Severity: minor
  - Forward impact: a follow-up story is warranted if Dev does not opt to fix the siblings in this PR.
- **No direct assertion on the "coroutine never awaited" RuntimeWarning**
  - Spec source: session AC list
  - Spec text: "RuntimeWarning: coroutine never awaited is gone"
  - Implementation: tested indirectly — the executed-flag (proves the async body ran) plus a 200 with real content (proves no coroutine reached serialization) together pin that the coroutine is awaited; no `pytest.warns`/`recwarn` assertion.
  - Rationale: that RuntimeWarning fires at garbage-collection time and is non-deterministic; asserting on it directly would be flaky. The root cause (await) is pinned robustly by the flag + status + content.
  - Severity: minor
  - Forward impact: none.

### Dev (implementation)
- **Scoped to the 3 tested routes; did NOT extend the fix to the sibling routes**
  - Spec source: TEA Delivery Finding (sibling routes) / session scope
  - Spec text: "recommend fixing [hotspots/health-score/code-markers] in the same PR for consistency"
  - Implementation: fixed only get_dead_code/get_complexity/get_dependencies; left the siblings for a separate story.
  - Rationale: reading the callee signatures showed the siblings have DISTINCT deeper bugs (missing required `path` arg; non-existent `use_cache` kwarg) needing design + tests, not a blind one-line edit — fixing them untested would be scope creep with its own risk. A focused, fully-tested PR plus a precise follow-up serves SOUL #1/#14 better.
  - Severity: minor
  - Forward impact: a new story should cover the sibling routes (recorded in Delivery Findings).
- **get_dead_code serializes `result.stale_files`, not the whole DeadCodeResult**
  - Spec source: TEA Fix interface / session AC2
  - Spec text: "`_safe_to_dict(result)` then serializes the whole DeadCodeResult — confirm the `{files, total}` shape you want"
  - Implementation: returns `{"files": _safe_to_dict(result.stale_files), "total": len(result.stale_files)}` — `files` is the stale-files list, `total` its count.
  - Rationale: honors the route's original `{files, total}` contract (the pre-bug code did `len(result)` expecting a list). A present-but-failed git scan therefore returns `{"files": [], "total": 0}` rather than a success/error envelope.
  - Severity: minor
  - Forward impact: `/api/dead-code` consumers get `{files, total}` only (no success/error envelope) — matches the original intended shape; surfacing git errors would be a separate enhancement.

### Reviewer (audit)
All TEA and Dev deviations reviewed and stamped:
- TEA "Tests force the complete fix (await + secondary bugs)" → ✓ ACCEPTED: a 500 is not a real result; AC2 correctly requires the len/Path fixes. Verified the secondary bugs are real (live run + binding probe).
- TEA "Sibling routes flagged, not tested (scope boundary)" → ✓ ACCEPTED: correct scope call; I independently confirmed the siblings are distinct deeper bugs warranting a separate story.
- TEA "No direct assertion on the RuntimeWarning" → ✓ ACCEPTED: the GC-timed warning is flaky to assert; I verified AC1 directly via a live `catch_warnings` run (0 warnings), so the indirect approach is sound.
- Dev "Scoped to the 3 tested routes; did NOT extend to siblings" → ✓ ACCEPTED: correctly overrides TEA's same-PR suggestion — the siblings have distinct deeper bugs (reproduced live); blind untested fixes would be the riskier choice.
- Dev "get_dead_code serializes result.stale_files, not the whole DeadCodeResult" → ✓ ACCEPTED: honors the original `{files, total}` contract; the route never worked so there is no regression. (Minor: a present-but-failed git scan returns `{files:[], total:0}` without surfacing the error — acceptable; folds into the CWE-209 follow-up if error surfacing is later added.)

No undocumented deviations found.