---
story_id: "164-25"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 164-25: Fix remaining Frame brownfield routes (hotspots/health-score/code-markers): same to_thread(async_fn) shape as 160-20 but DISTINCT deeper arg bugs

## Story Details
- **ID:** 164-25
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-25-frame-brownfield-routes-hotspots-health-markers
- **PR:** #245
- **Repos:** pennyfarthing

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-13T13:16:06Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T19:12:06Z | 2026-08-12T19:14:07Z | 2m 1s |
| red | 2026-08-12T19:14:07Z | 2026-08-13T12:26:01Z | 17h 11m |
| green | 2026-08-13T12:26:01Z | 2026-08-13T13:00:49Z | 34m 48s |
| review | 2026-08-13T13:00:49Z | 2026-08-13T13:16:06Z | 15m 17s |
| finish | 2026-08-13T13:16:06Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Findings below this marker -->

### TEA (test design)
- **Question** (non-blocking): The old `get_health_score` passed `use_cache=False`, whose intent was caching OFF. Simply *removing* the kwarg leaves `analyze_healthscore` at its default `cache_ttl=300` — silently re-enabling caching. The CLI precedent maps "no cache" to `cache_ttl=0` (`healthscore/cli.py:53`). Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py` (Dev should pass `cache_ttl=0` to preserve the disable-cache intent, not just drop the kwarg). The RED tests only assert `use_cache` absent + a `Path` target, so either choice passes the gate — this is a behavior decision Dev must make deliberately. *Found by TEA during test design.*
- **Gap** (non-blocking): `analyze_repo` (hotspots + code-markers) requires both `name` and `path`; the story flagged the name/path source as an open design decision. The established convention (`hotspots/cli.py:82`, `codemarkers/cli.py:81`) is `analyze_repo(Path(project_dir).name, Path(project_dir))` — display name = repo basename, path = the project dir. Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py`. Tests pin this convention. *Found by TEA during test design.*
- **Improvement** (non-blocking): The route tests pin `Path(project_dir)` **unresolved** (matching the working sibling routes dead-code/complexity/dependencies, which pass `Path(project_dir)` without `.resolve()`). If Dev adds `.resolve()` the path-equality assertions fail by design — keep the route layer consistent and let `analyze_repo`/`analyze_healthscore` resolve internally (they already do). Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py`. *Found by TEA during test design.*
- **Improvement** (non-blocking): Sibling analysis-route tests (dead-code, complexity, dependencies, agent-load) still use the permissive `status_code in (200, 500)` tuple. Out of scope for 164-25 (those routes are not defective) but the same tuple masked the 160-20 defect, so they remain latent masking risks. Affects `pennyfarthing-dist/src/pf/tests/test_frame_routes.py`. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): The working sibling routes `get_hotspots`/`get_code_markers`/`get_health_score`/`get_complexity`/`get_dependencies`/`get_dead_code` all repeat the same `_get_project_dir()` → `Path(...)` → `await analyze_*(...)` shape with duplicated `try/except → 500` boilerplate. A single decorator/helper could de-duplicate it, but that is a refactor beyond this fix's scope. Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py`. *Found by Dev during implementation.*
- No blocking upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): `test_health_score_omits_use_cache_kwarg` asserts `use_cache` is absent but does not positively assert `cache_ttl == 0`. AC2 ("removes use_cache") is satisfied and tested, but Dev's beyond-AC `cache_ttl=0` behavioral contract (caching OFF) has no protecting assertion — a future refactor to `analyze_healthscore(Path(project_dir))` would silently re-enable the 300s cache and no test would fail. Affects `pennyfarthing-dist/src/pf/tests/test_frame_routes.py` (add `assert kwargs.get("cache_ttl") == 0`). Recommended TEA follow-up. *Found by Reviewer during code review.* [TEST]
- **Improvement** (non-blocking): The three rewritten route classes have no error-path (HTTP 500) test — the `except Exception → 500` branch is unexercised for hotspots/health-score/code-markers. The old permissive `(200,500)` tuple at least admitted the 500 outcome. Affects `pennyfarthing-dist/src/pf/tests/test_frame_routes.py` (add a patched-to-raise test per route asserting 500 + `{"success": False, "error": ...}`). *Found by Reviewer during code review.* [TEST]
- **Improvement** (non-blocking): `TestHotspotsRoute`/`TestCodeMarkersRoute` docstrings describe the bug as `asyncio.to_thread(analyze_repo, ...)`, but the route's module-local aliases are `analyze_hotspots`/`analyze_code_markers` (`analyze_repo` is the underlying, also-shared codemarkers name). Cosmetic accuracy nit. Affects `pennyfarthing-dist/src/pf/tests/test_frame_routes.py`. *Found by Reviewer during code review.* [DOC]
- **Improvement** (non-blocking, pre-existing/repo-wide): All six analysis routes return raw `str(e)` in the 500 body (CWE-209 info-leak of absolute paths) and emit no server-side log on the error path. Not a triggered project rule (`analysis.py` imports no logger, so lang-review #4 does not fire) and near-zero exploitability for a local dev dashboard, but worth a hardening pass. NOT introduced or worsened by this diff (the `except` blocks are unchanged context). Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py`. *Found by Reviewer during code review.* [SILENT][SEC]
- **Improvement** (non-blocking, pre-existing): `days = int(request.query_params.get("days", "90"))` (analysis.py:60) sits outside the `try`, so a non-integer `?days=` yields FastAPI's generic 500 rather than the route's `{"success": False}` contract or a 400; `days` also has no range guard. Unchanged context line — out of scope for this fix. Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py`. *Found by Reviewer during code review.* [EDGE][SEC]

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### TEA (test design)
- **Contract-level (mock) tests instead of pure end-to-end status checks**
  - Spec source: context-story-164-25.md, AC "All Frame brownfield analysis routes pass"
  - Spec text: "tighten test_frame_routes.py analysis-route tests which accept status_code in (200,500)"
  - Implementation: Route tests monkeypatch the analysis collaborators with an async recording spy and assert the *call contract* (awaited once; `Path` not `str`; `name` present; no `use_cache`) in addition to `status_code == 200`.
  - Rationale: `pf_project_dir` is not a git repo, so exercising the real git-mining analysis against it is non-deterministic (may 500 on a non-repo). The spy pins the route's contract with its collaborator deterministically and catches the `to_thread(async_fn)` never-awaited bug directly (empty `calls`).
  - Severity: minor
  - Forward impact: The route's *real* integration with the git-mining functions is not exercised here; that path is covered by each analysis module's own tests. Dev/Reviewer should not read a green route test as proof the underlying analysis runs.
- **`use_cache` intent (cache_ttl) surfaced as a finding, not hard-asserted**
  - Spec source: context-story-164-25.md, AC "Health score route removes use_cache kwarg"
  - Spec text: "get_health_score passes a non-existent use_cache kwarg to analyze_healthscore ... use_cache removal"
  - Implementation: Tests assert `use_cache` is absent and the target is a `Path`, but do NOT assert `cache_ttl=0`.
  - Rationale: The AC says "remove use_cache" and is silent on `cache_ttl`. Whether to preserve the original caching-OFF intent (`cache_ttl=0`) is a genuine behavior decision left to Dev — logged as a Delivery Finding rather than over-constrained in a test.
  - Severity: minor
  - Forward impact: none (finding routes the decision to Dev)

### Dev (implementation)
- **Resolved TEA's `use_cache` finding as `cache_ttl=0`, not a bare kwarg drop**
  - Spec source: context-story-164-25.md, AC "Health score route removes use_cache kwarg"; TEA Delivery Finding (Question)
  - Spec text: "get_health_score passes a non-existent use_cache kwarg ... use_cache removal"
  - Implementation: `await analyze_healthscore(Path(project_dir), cache_ttl=0)` — removed `use_cache` AND passed `cache_ttl=0`.
  - Rationale: A bare drop would default to `cache_ttl=300`, silently re-enabling caching and inverting the original `use_cache=False` (caching OFF) intent. `cache_ttl=0` preserves that intent and matches the CLI `--no-cache` → `cache_ttl=0` precedent (`healthscore/cli.py:53`). The health-score endpoint should serve fresh scores.
  - Severity: minor
  - Forward impact: none — behavior matches the pre-defect intent; TEA's tests pass either way.

### Reviewer (audit)
- **TEA: Contract-level (mock) tests instead of pure end-to-end status checks** → ✓ ACCEPTED by Reviewer: The spy approach is not just defensible, it is *required* — I empirically verified that `unittest.mock.AsyncMock` would increment `call_count` at call-time under `asyncio.to_thread(async_fn)` (registering the never-awaited call), whereas `_AsyncCallSpy` records inside the awaited coroutine body and stays empty. The custom spy is what makes the missing-`await` defect detectable in RED. Loss of real git-mining integration coverage is acceptable and correctly flagged.
- **TEA: `use_cache` intent surfaced as a finding, not hard-asserted** → ✓ ACCEPTED by Reviewer: Routing the beyond-AC `cache_ttl` decision to Dev rather than over-constraining the test was the right call. See my delivery finding recommending a follow-up positive assertion for the `cache_ttl=0` contract Dev ultimately chose.
- **Dev: Resolved TEA's `use_cache` finding as `cache_ttl=0`, not a bare kwarg drop** → ✓ ACCEPTED by Reviewer: Correct. A bare drop defaults to `cache_ttl=300`, silently re-enabling caching and inverting the original `use_cache=False` intent. `cache_ttl=0` preserves it and matches the `--no-cache` → `cache_ttl=0` CLI precedent (`healthscore/cli.py:53`). Signature verified against `analyze_healthscore(target_path, weights=None, cache_ttl=300)`.
- **No undocumented deviations found.** The `Path(project_dir)` unresolved convention is documented (TEA finding #3, Dev deviation) and matches all four untouched sibling routes.

## Story Context

**Type:** Enhancement
**Points:** 5
**Repos:** pennyfarthing

### Problem
Fix remaining Frame brownfield routes with deeper argument bugs:
- `get_hotspots` / `get_code_markers` call `analyze_repo(name, path)` but only pass `project_dir` (missing required 'path' arg)
- `get_health_score` passes non-existent `use_cache` kwarg to `analyze_healthscore`
- `test_frame_routes.py` analysis-route tests accept `status_code in (200, 500)` — loose assertion masked the 160-20 bug

### Solution Approach
Same `to_thread(async_fn)` shape fix as 160-20 (need Path() + await), plus:
1. Determine name/path source design for analyze_repo calls
2. Remove use_cache kwarg from get_health_score
3. Tighten test assertions to expect 200 (or specific expected codes), not permissive tuple

### Source
From 160-20 TEA/Dev/Reviewer findings

### Acceptance Criteria
- [ ] Hotspots route calls analyze_repo with correct name/path arguments
- [ ] Health score route removes use_cache kwarg
- [ ] Code markers route calls analyze_repo with correct name/path arguments
- [ ] test_frame_routes.py analysis-route tests assert specific status codes (not permissive tuple)
- [ ] All Frame brownfield analysis routes pass

## SM Assessment

Story set up and routed to TEA for the RED phase of the TDD workflow.

**Scope & routing.** 3-pt (context block's "5" is cosmetic; sprint YAML says 3), p2, `tdd` → SM → TEA → Dev → Reviewer. Single repo: `pennyfarthing/` (gitflow, PR targets develop). No Jira key — Jira claim skipped by design.

**The core work is a 160-20 sibling with THREE distinct deeper bugs — not just the async-shape fix.** TEA must design failing tests that pin each one independently:
1. `get_hotspots` and `get_code_markers` call `analyze_repo` with a required `path` argument missing (only `project_dir` passed). A design decision is required on the name/path source — TEA/Dev should surface where `name` and `path` legitimately come from in the route context, not guess.
2. `get_health_score` passes a non-existent `use_cache` kwarg to `analyze_healthscore` — decision is almost certainly "remove it," but confirm against the current `analyze_healthscore` signature.
3. The `to_thread(async_fn)` shape fix from 160-20 (`Path()` wrap + `await`).

**The masking-test fix is a first-class AC, not cleanup.** The existing `test_frame_routes.py` analysis-route tests assert `status_code in (200, 500)` — that permissive tuple is exactly what let the 160-20 defect ship. TEA must tighten these to assert the specific expected code (200 on success) so the regression is actually pinned. A green suite under the old loose assertion is not acceptance here.

**Handoff note for TEA (Igor):** ground the RED tests in the real `analyze_repo` / `analyze_healthscore` signatures — read them first. The design decisions (name/path source, use_cache removal) should be logged as Design Deviations / Delivery Findings so Dev implements against a pinned interface, not an inferred one.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Three brownfield bugs + a masking-assertion fix, all needing independent pins.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_frame_routes.py` — rewrote `TestHotspotsRoute`, `TestHealthScoreRoute`, `TestCodeMarkersRoute` with a shared async recording spy (`_AsyncCallSpy`) and tightened status assertions.

**Tests Written:** 11 tests covering all 5 ACs
**Status:** RED (11 failing, verified by testing-runner run `164-25-tea-red`; 66 unrelated tests still pass — no regression)

Grounded the interface in the real signatures and the CLI convention:
- `hotspots.analyze.analyze_repo(name: str, path: Path, days=90, ...)` — CLI calls `analyze_repo(p.name, p, ...)` (`hotspots/cli.py:82`)
- `codemarkers.analyze.analyze_repo(name: str, path: Path, days=90, ...)` — CLI calls `analyze_repo(project_root.name, project_root, ...)` (`codemarkers/cli.py:81`)
- `healthscore.analyze.analyze_healthscore(target_path: Path, weights=None, cache_ttl=300)` — no `use_cache` param; CLI maps `--no-cache` → `cache_ttl=0` (`healthscore/cli.py:53`)

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #9 async — missing await (coroutine never executes) | `test_hotspots_awaits_analyze_repo_once`, `test_health_score_awaits_analyze_once`, `test_code_markers_awaits_analyze_repo_once` | failing |
| #5 path handling — `Path` not `str` | `test_hotspots_passes_name_and_path_object`, `test_health_score_passes_path_object`, `test_code_markers_passes_name_and_path_object` | failing |
| #6 test quality — de-vacuum permissive status tuple | `test_get_hotspots_returns_200`, `test_get_health_score_returns_200`, `test_get_code_markers_returns_200` | failing |
| AC1/AC3 — correct args | `*_passes_name_and_path_object`, `test_hotspots_forwards_days_param` | failing |
| AC2 — drop use_cache | `test_health_score_omits_use_cache_kwarg` | failing |

**Rules checked:** 3 of 13 lang-review rules apply to this diff (#5, #6, #9) — all covered.
**Self-check:** 0 vacuous tests. Every test asserts a specific value (exact status, `Path` instance, kwarg absence, call count, basename membership). The spy body only records when the coroutine is genuinely awaited, so the `calls == 1` assertions cannot pass against the buggy `to_thread(async_fn)` shape.

**AC → test map:**
- Hotspots correct name/path → `test_hotspots_passes_name_and_path_object` (+ `test_hotspots_forwards_days_param`)
- Health score removes use_cache → `test_health_score_omits_use_cache_kwarg`
- Code markers correct name/path → `test_code_markers_passes_name_and_path_object`
- Tighten permissive tuples → `test_get_*_returns_200` (== 200, was `in (200, 500)`)
- All brownfield analysis routes pass → all three `*_returns_200` + `*_awaits_*_once`

**Handoff:** To Dev for implementation. Read the two Delivery Findings before implementing — the `cache_ttl=0` intent and the unresolved-`Path` convention are the two decisions that determine GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/routes/analysis.py` — fixed the three brownfield routes; removed the now-unused `asyncio` import.

**Changes:**
- `get_hotspots`: `await analyze_hotspots(path.name, path, days=days)` where `path = Path(project_dir)` — awaited directly (no `to_thread`), supplies `name` (basename) + `path` (`Path`).
- `get_code_markers`: `await analyze_code_markers(path.name, path)` — same shape.
- `get_health_score`: `await analyze_healthscore(Path(project_dir), cache_ttl=0)` — dropped invalid `use_cache`, used `cache_ttl=0` to preserve the disable-cache intent (see Dev deviation).
- Removed `import asyncio` (no remaining users → would fail ruff F401).

**Tests:** 11/11 targeted passing (GREEN); 77/77 `test_frame_routes.py`; full suite 7530 passed / 4 skipped, 0 failures caused by this change (one pre-existing unrelated xfail-marker issue in `test_162_83_toctou_decision.py`). Verified by testing-runner run `164-25-dev-green`. Ruff clean.

**Decisions against TEA findings:**
- `cache_ttl=0` (finding 1) — logged as Dev deviation.
- `Path(project_dir)` left unresolved (finding 3) — followed; matches sibling routes, `analyze_*` resolve internally.

**AC status:**
- [x] Hotspots route calls analyze_repo with correct name/path arguments
- [x] Health score route removes use_cache kwarg
- [x] Code markers route calls analyze_repo with correct name/path arguments
- [x] test_frame_routes.py analysis-route tests assert specific status codes (TEA, red phase)
- [x] All Frame brownfield analysis routes pass

**Branch:** feat/164-25-frame-brownfield-routes-hotspots-health-markers (pushed)

**Handoff:** To Reviewer for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (77 pass, ruff clean, 0 smells) | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 5 | confirmed 0 blocking, deferred 4 (pre-existing/out-of-scope), dismissed 1 (symlink/.resolve) |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 5 | confirmed 0 blocking, deferred 5 (pre-existing no-log/broad-except + out-of-diff healthscore probe) |
| 4 | reviewer-test-analyzer | Yes | findings | 4 | confirmed 2 non-blocking (cache_ttl assertion gap, no 500-path test), noted 2 low (Path coupling intentional, isinstance noise) |
| 5 | reviewer-comment-analyzer | Yes | findings | 2 | confirmed 2 non-blocking Low (docstring alias naming) |
| 6 | reviewer-type-design | Yes | findings | 2 | arg types/order VERIFIED correct; 2 deferred (pre-existing _get_project_dir str / unresolved Path, callees resolve) |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 0 new (both pre-existing, out-of-scope); CWE-22 explicitly 0 violations |
| 8 | reviewer-simplifier | Yes | findings | 3 | dismissed 1 (AsyncMock — empirically defeats RED signal), noted 2 low style (_all_values, redundant guards) |
| 9 | reviewer-rule-checker | Yes | clean | none (13 checks / 46 instances / 0 violations) | N/A |

**All received:** Yes (9 returned, 7 with findings, 2 clean)
**Total findings:** 0 confirmed blocking, 5 confirmed non-blocking (filed as Delivery Findings), 1 dismissed with rationale, remainder deferred as pre-existing/out-of-scope

**Working-tree audit:** `pf reviewer audit-tree` exited non-zero, flagging untracked `sprint/context/context-story-164-25.md`. Verified FALSE POSITIVE: mtime `2026-08-12 15:12` (created during TEA-phase SM setup, a day before this review), a markdown context doc (not source), and **zero `.py` files dirty in either repo**. All reviewer subagents are read-only (no Write/Edit access) and could not have created it. No mutation-testing corruption occurred; the audit keyed on a pre-existing untracked orchestrator doc. Deliberately did NOT `git clean -fd` (would destroy legitimate pre-existing work). Source tree integrity confirmed clean.

### Rule Compliance

Rubric: `.pennyfarthing/gates/lang-review/python.md` (13 checks). Exhaustive enumeration over changed symbols (`analysis.py` 3 routes; `test_frame_routes.py` 11 tests + `_AsyncCallSpy` + `_all_values`).

| # | Rule | Applies? | Verdict |
|---|------|----------|---------|
| 1 | Silent exception swallowing | Yes (3 except blocks) | Compliant — API-boundary catch surfaces error via 500, does not suppress. Broad `except` is pre-existing/unchanged context; not a new violation. |
| 2 | Mutable default arguments | Yes (6 defs) | Compliant — no mutable defaults. |
| 3 | Type annotations at boundaries | Yes (3 handlers + helpers) | Compliant — `(request: Request) -> JSONResponse`; `Any` on private spy justified. |
| 4 | Logging coverage/correctness | No | `analysis.py` imports no `logging`/`structlog` → rule does not trigger. (Missing-log observation filed as non-blocking improvement, not a rule violation.) |
| 5 | Path handling | Yes (3 Path uses) | Compliant — pathlib throughout, no string concat. `.resolve()` not required at boundary: `project_dir` is env/cwd-sourced (not HTTP input), and all 3 callees `.resolve()` internally. |
| 6 | Test quality | Yes (11 tests) | Compliant — exact-value assertions, correct monkeypatch targets (where-used), no vacuous asserts. |
| 7 | Resource leaks | No | No file/socket/lock/temp usage in diff. |
| 8 | Unsafe deserialization | No | No pickle/yaml/eval/exec/subprocess in diff. |
| 9 | Async/await pitfalls | Yes (3 awaits + spy) | Compliant — the FIX: `await analyze_*(...)` replaces `to_thread(async_fn)`; coroutines correctly awaited. This is the story's core defect, now resolved. |
| 10 | Import hygiene | Yes (2 changes) | Compliant — removed now-unused `asyncio`; added explicit `from typing import Any` (consistent with existing `analysis.py`). |
| 11 | Input validation at boundaries | Partial | `days` parse-outside-try + no range guard is a pre-existing gap on an UNCHANGED line — filed non-blocking, out-of-scope. No new input paths added. |
| 12 | Dependency hygiene | No | No dependency/manifest changes. |
| 13 | Fix-introduced regressions | Yes | Re-scanned all 3 fixes against #1–#12 — no regressions introduced. |

### Observations

- [VERIFIED] Argument shape/order/type correct for all 3 routes — evidence: `analyze_hotspots(path.name, path, days=days)` and `analyze_code_markers(path.name, path)` match `analyze_repo(name: str, path: Path, days=90, ...)` (`hotspots/analyze.py:299`, `codemarkers/analyze.py:255`); `analyze_healthscore(Path(project_dir), cache_ttl=0)` matches `analyze_healthscore(target_path: Path, weights=None, cache_ttl=300)` (`healthscore/analyze.py:27`). Complies with lang-review #3/#5/#9. [TYPE][RULE]
- [VERIFIED] The `to_thread(async_fn)` never-awaited defect is genuinely fixed — evidence: `analysis.py:63,137,168` now use bare `await`; RED phase (`164-25-tea-red`) showed the spy `calls` empty and 500s, GREEN (`164-25-dev-green`) shows 11/11 + 7530-test sweep clean. [RULE]
- [VERIFIED] Return dataclasses serialize safely — evidence: `HotspotResult`/`CodeMarkersResult`/`HealthscoreResult` are `@dataclass` with `repo_path`/`target_path` stored as `str(...)` in the callee, so no raw `Path` reaches `_safe_to_dict` (`analysis.py:38`). [TYPE]
- [VERIFIED] `_AsyncCallSpy` is the correct test mechanism, not over-engineering — evidence: empirical check shows `AsyncMock.call_count==1` under `to_thread(async_fn)` (call-time recording) vs custom-spy `calls==0` (await-time recording). The custom class is required for the missing-`await` RED signal. Dismisses [SIMPLE] finding #1. [SIMPLE]
- [LOW] `test_health_score_omits_use_cache_kwarg` lacks a positive `cache_ttl==0` assertion — the beyond-AC caching-OFF contract is unprotected (`test_frame_routes.py:751`). Filed as non-blocking follow-up. [TEST]
- [LOW] No error-path (500) test for the 3 rewritten route classes (`test_frame_routes.py`). Filed non-blocking. [TEST]
- [LOW] Test-class docstrings say `analyze_repo` where the route alias is `analyze_hotspots`/`analyze_code_markers` (`test_frame_routes.py:618,800`). Cosmetic. [DOC]
- [LOW/pre-existing] Raw `str(e)` in 500 body + no error-path logging across all 6 routes (`analysis.py:66,140,171,...`); `days` parse outside try + no range guard (`analysis.py:60`). Pre-existing, out-of-scope, repo-wide. [SILENT][SEC][EDGE]

### Devil's Advocate

Let me argue this code is broken. First attack: the tests are theater. Every route test monkeypatches the real analysis function with `_AsyncCallSpy` returning a canned `{"success": True}`, so `assert status_code == 200` and `isinstance(data, dict)` prove only that FastAPI can serialize a hand-fed dict — the real `analyze_repo`/`analyze_healthscore` are never invoked. If those functions choke on this repo's git history, or `_safe_to_dict` mishandles a nested dataclass they return, no test here catches it. The story's own AC5 ("backward-compatible response shapes") is therefore unverified for these three routes by this change — a reviewer trusting the green checkmark could ship a route that 500s in production against a real repo. Second attack: the `cache_ttl=0` decision is a silent behavior change with no guardrail. The comment claims it "preserves intent," but there is no test asserting `cache_ttl==0`; a well-meaning refactor that drops the kwarg re-enables a 300-second cache, and the health-score panel would serve stale scores with zero test failures — the exact class of silent regression (weak assertion masks behavior) that this entire story was spun off to eliminate. Third attack: input hostility. A confused user hits `/api/hotspots?days=abc` and gets FastAPI's generic 500, not the `{"success": False}` shape the route advertises and its siblings honor — an inconsistent contract. `?days=99999999` forwards an absurd span to git-log with no clamp. A stressed filesystem raising deep in the analyzer surfaces its absolute path verbatim in the HTTP body. Fourth attack: `PF_PROJECT_DIR="/"` makes `path.name == ""`, feeding an empty display name into `analyze_repo`. 

Rebuttal: attacks 3 and 4 land on unchanged, pre-existing context lines and degenerate/trusted-source inputs (env-controlled, local dev dashboard) — real but out of scope, and filed as non-blocking findings. Attack 2 is genuine but sits *beyond* the tested AC (AC2 "removes use_cache" is asserted); filed as a recommended follow-up. Attack 1 is the sharpest — integration coverage genuinely narrowed — but the trade is deliberate and documented (TEA deviation): the spy is the only mechanism that catches the missing-`await` defect deterministically without a git-repo fixture, and the underlying analysis functions carry their own module tests. None of these rise to a correctness defect in the changed lines. The fix itself is exactly right.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** HTTP GET `/api/hotspots?days=N` → `_get_project_dir()` (env `PF_PROJECT_DIR`/cwd, trusted) → `path = Path(project_dir)` → `await analyze_hotspots(path.name, path, days=days)` → `HotspotResult` dataclass → `_safe_to_dict` → `JSONResponse`. Safe: no request-controlled path reaches the filesystem (CWE-22 N/A); `days` is the only user input and is unchanged from prior behavior.

**Pattern observed:** Correct async collaboration — bare `await` on an async collaborator (`analysis.py:63,137,168`), replacing the `asyncio.to_thread(async_fn)` anti-pattern. Matches the working sibling routes (dead-code/complexity/dependencies).

**Error handling:** Broad `except Exception → 500` on all three routes (`analysis.py:65,139,170`) — pre-existing, unchanged, uniform across the module; surfaces errors rather than swallowing them. No new error-handling regression.

**Rule compliance:** lang-review 13/13 clean (rule-checker: 46 instances, 0 violations). Core rule #9 (async/await) — the story's defect — now compliant.

**Findings by specialist:** 0 blocking; 5 non-blocking filed as Delivery Findings; 1 dismissed.
- [TEST] cache_ttl==0 not positively asserted (`test_frame_routes.py:751`); no 500 error-path test — non-blocking follow-ups.
- [DOC] test-class docstrings name `analyze_repo` vs route aliases `analyze_hotspots`/`analyze_code_markers` — cosmetic, non-blocking.
- [TYPE] arg types/order VERIFIED correct against callee signatures; pre-existing `_get_project_dir()` str-return / unresolved-`Path` deferred (callees `.resolve()` internally).
- [SEC] no new vulnerabilities; CWE-22 explicitly 0 (project_dir is trusted env, not HTTP input); pre-existing `str(e)` 500-body leak (CWE-209) deferred.
- [SILENT] pre-existing no-log-on-500 across all 6 routes — not a triggered rule (#4 requires an existing logger import); non-blocking.
- [EDGE] pre-existing `days` parse-outside-try / no range guard on unchanged line — out of scope.
- [SIMPLE] AsyncMock-replacement suggestion DISMISSED (empirically registers the never-awaited call, defeating the RED signal); `_all_values`/redundant-guard nits noted, non-blocking.
- [RULE] rule-checker clean — 13 checks / 46 instances / 0 violations; core async/await rule #9 (the fixed defect) compliant.

**Handoff:** To SM for finish-story.