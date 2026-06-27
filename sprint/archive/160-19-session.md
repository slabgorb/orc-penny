---
story_id: "160-19"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-19: Fail-loud sweep part 5: warn-then-degrade get_context silent swallow

## Story Details
- **ID:** 160-19
- **Jira Key:** (none — Jira not enabled)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-27T09:33:31Z
**Repos:** pennyfarthing
**Branch:** feat/160-19

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-27T09:05:47.994088+00:00 | 2026-06-27T09:09:12Z | 3m 24s |
| red | 2026-06-27T09:09:12Z | 2026-06-27T09:22:05Z | 12m 53s |
| green | 2026-06-27T09:22:05Z | 2026-06-27T09:26:49Z | 4m 44s |
| review | 2026-06-27T09:26:49Z | 2026-06-27T09:33:31Z | 6m 42s |
| finish | 2026-06-27T09:33:31Z | - | - |

## SM Assessment

**Story:** Fail-loud sweep part 5 — the final silent swallow in `pennyfarthing/pennyfarthing-dist/src/pf/frame/data_proxy.py`. The `get_context` function (~L299) has an `except Exception` block that returns an all-None context shape with the error embedded but emits NO `warnings.warn`. From 160-17 TEA/Dev/Reviewer findings.

**Technical approach:** Make the except block warn-then-degrade — emit `warnings.warn(...)` before returning the existing degraded all-None shape, matching the pattern from sibling sweep stories (160-17, 160-18). Preserve the return shape so callers are unaffected beyond the new warning.

**Acceptance criteria:**
- `get_context`'s `except Exception` emits `warnings.warn` before returning the degraded shape.
- Degraded all-None return shape preserved (no caller-visible behavior change beyond the warning).
- A test asserts the warning is emitted on the exception path (`pytest.warns`).
- No silent swallows remain in `data_proxy.py` (completes the file's sweep).

**Scope boundary (important):** Story 160-22 (info-leak sanitization) overlaps on `get_context` at L322 — the `str(e)` embedded in the response body. 160-19 ships FIRST per the user; 160-22 sanitizes afterward. Do NOT sanitize the `str(e)` leak in this story — that is 160-22's scope. Stay within the fail-loud (`warnings.warn`) change.

**Repo/branch:** `pennyfarthing/` on `feat/160-19`, targets `develop` (gitflow) — NOT `main`.

**Routing:** Phased TDD, 2pts. Next: TEA (Lord Melchett) for the RED phase.

## TEA Assessment

**Tests Required:** Yes
**Reason:** A behavioral change to an API route (fail-loud) plus a constant-bug fix — both need regression coverage.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_19_get_context_fail_loud.py` — 4 tests (3 RED, 1 green-on-arrival guard)

**Tests Written:** 4 tests covering the fail-loud AC, the degrade-shape AC, and the constant bug the swallow hides.
- `test_get_context_returns_real_data_when_check_context_succeeds` — RED: forces the constant-bug fix (real `ContextResult` values must reach the body) + no-warn on a healthy call.
- `test_get_context_real_check_context_degrades_gracefully` — RED: real end-to-end wiring; a no-transcript project must yield a graceful sentinel (`no_transcript`), not a `TypeError` crash string.
- `test_get_context_warns_on_genuine_exception` — RED: the core fail-loud AC (`warnings.warn` on a genuine `check_context` exception; route must not raise).
- `test_get_context_degrades_to_all_none_on_genuine_exception` — GREEN-on-arrival guard: degrade shape preserved (see Design Deviations).

**Status:** RED — verified targeted run: `3 failed, 1 passed in 0.29s`.

### Rule Coverage

| Rule (python lang-review) | Test(s) | Status |
|---------------------------|---------|--------|
| #1 silent exception swallowing | `test_get_context_warns_on_genuine_exception` | failing (RED) |
| #4 logging: never log sensitive data (warnings sink) | cross-file: `test_160_18` AST guard forbids raw `str(e)` in any `data_proxy` warn | passing (baseline confirmed) |
| #6 test quality (meaningful asserts; mock where used) | self-check below | pass |
| #9 async pitfalls (route must never raise/500) | every test asserts "must NOT raise" | failing/guard |

**Rules checked:** 4 of 13 applicable; the rest (mutable defaults, paths, resource leaks, deserialization, deps) aren't exercised by this small route change.
**Self-check:** 0 vacuous tests — every test pins specific values; seams patch `data_proxy.check_context` (where used) and `context_window.find_transcript` (deterministic no-data path).

**Designed interface for Dev (Baldrick) — see the test module docstring for full detail:**
1. **Fix the constant bug:** call `result = check_context(project_dir=project_dir)` directly; delete the invalid `ContextConfig(project_dir=project_dir)` construction (`ContextConfig` has no such field). The healthy path must return real `percent`/`tokens`/`status`.
2. **Add warn-then-degrade:** in the `except`, `warnings.warn(f"Failed to check context ({_safe_exc(e)})", stacklevel=2)` BEFORE returning the unchanged all-`None` degraded shape. Use `_safe_exc` (160-18 sink convention) — a raw `{e}` turns the `test_160_18` AST guard red.
3. **Scope guard:** leave the response-body `error: str(e)` (L322) as-is — that is story 160-22.

**Handoff:** To Dev (Baldrick) for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` — `get_context`: (1) replaced the constant-bug `ContextConfig(project_dir=project_dir)` + `check_context(config)` with a direct `check_context(project_dir=project_dir)`; (2) added `warnings.warn(f"Failed to check context ({_safe_exc(e)})", stacklevel=2)` in the `except` before the unchanged degraded return; (3) dropped the now-unused `ContextConfig` import (ruff F401).

**Tests:** 4/4 passing (GREEN) — `test_160_19_get_context_fail_loud.py`. Regression batch (160-16/17/18 + `test_frame_routes.py`) = 100 passed; `ruff check data_proxy.py` clean. Scoped runs only (never full suite — branch leak).

**Live smoke (real wiring, not just mocks):** `PF_PROJECT_DIR=<orchestrator> get_context()` now returns real data — `{percent: 21, tokens: 219757, status: "OK", error: None}` with NO warning (was all-`None` + the `TypeError` string before the fix).

**Scope guard honored:** response-body `error: str(e)` (L322) left untouched — story 160-22. No silent swallows remain in `data_proxy.py`.

**Branch:** feat/160-19 (pushed; targets `develop`).

**Handoff:** To Reviewer (Captain Darling) for code review.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (blocking): `get_context` (`data_proxy.py:~301`) constructs `ContextConfig(project_dir=project_dir)`, but `ContextConfig` has no `project_dir` field, so the route raises `TypeError` on EVERY request and the silent `except` returns an all-`None` body — the `/api/context` panel has never shown real data through this route. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` `get_context` (call `check_context(project_dir=project_dir)` directly; drop the bogus `ContextConfig` construction). *Found by TEA during test design.*
- **Improvement** (non-blocking): fixing the constant bug shrinks story 160-22's `get_context` leak window — the response-body `error: str(e)` (L322) currently leaks the raw `TypeError` on every request; post-fix it fires only on genuine exceptions. 160-22 still owns the body sanitisation. Affects `data_proxy.py` `get_context` L322 (160-22 scope). *Found by TEA during test design.*

### Dev (implementation)
- No NEW upstream findings. TEA's blocking constant-bug finding is RESOLVED in this PR (`get_context` now calls `check_context(project_dir=project_dir)` directly). The response-body `error: str(e)` leak (L322) remains tracked as story 160-22; this PR shrinks its window to genuine exceptions only (it no longer fires on every request). *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): `get_context` now actually executes `check_context` synchronously inside an `async def` route (previously it always raised `TypeError` before reaching it, so this is the first time the route does real transcript I/O). The whole `data_proxy.py` file does sync I/O in async routes (the Frame poll-loop pattern) — pre-existing and consistent, not a regression here. If `/api/context` latency on large transcripts ever matters, a file-wide follow-up could wrap these calls in `asyncio.to_thread`. Affects `data_proxy.py` (all async routes; file-wide). *Found by Reviewer during code review.*
- **Confirmation** (non-blocking): the CWE-209 `str(e)` response-body leak ([SEC] finding) is pre-existing and already tracked by story 160-22 (get_context L322) — no new follow-up story needed. This PR reduces its blast radius (except now fires only on genuine errors, not every request). Affects `data_proxy.py` `get_context` (160-22 scope). *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Scope expanded to fix the constant bug, not just add the warn**
  - Spec source: context-story-160-19.md (title) + SM Assessment
  - Spec text: "warn-then-degrade get_context silent swallow — ... emits NO warnings.warn"
  - Implementation: the tests also REQUIRE fixing the `ContextConfig(project_dir=...)` constant bug, not only adding a warn.
  - Rationale: a warn-only change would fire on EVERY request (warn-spam over a constant bug) — the blocking defect 160-17 round-2 was rejected for. A correct warn-then-degrade is impossible while the try-body is 100% broken (SOUL #1: fix the system, not the symptom).
  - Severity: moderate
  - Forward impact: Dev's GREEN must include the call fix; response-body `str(e)` sanitisation remains story 160-22.
- **One green-on-arrival regression guard**
  - Spec source: 160-19 AC "degraded all-None return shape preserved"
  - Spec text: "The degraded all-None return shape is preserved (no behavior change for callers beyond the warning)."
  - Implementation: `test_get_context_degrades_to_all_none_on_genuine_exception` passes on arrival (the all-`None` shape already exists via today's swallow); it is a guard pinning that the fail-loud change must not alter the shape.
  - Rationale: per `ac-as-green-regression-guard` — a shape-preservation AC is best expressed as a guard that stays green, not an artificially-reddened test.
  - Severity: minor
  - Forward impact: none

### Dev (implementation)
- **Retained the broad `except Exception` catch-all (lang-review #1)**
  - Spec source: python lang-review #1 (silent exception swallowing) + sibling fixes 160-16/17/18
  - Spec text: "except Exception ... must catch specific exceptions"
  - Implementation: kept the catch-all `except Exception as e` in `get_context`, now warn-then-degrade rather than narrowed to specific types.
  - Rationale: this feeds an async FastAPI route + the Frame ~5s poll loop that must never 500 / blank the panel; a warn + graceful degrade is strictly safer than letting an unforeseen exception escape. Matches the retained-catch-all decision in 160-16/17/18.
  - Severity: minor
  - Forward impact: none — unchanged context from the sibling sweep stories; not a new pattern.

### Reviewer (audit)
- **TEA: scope expanded to fix the constant bug** → ✓ ACCEPTED by Reviewer: sound. A warn-then-degrade over a try-body that raises `TypeError` on every call would warn-spam — the exact 160-17 round-2 rejection. Fixing the `ContextConfig` miscall is the only way to make the warn fire on genuine failures (SOUL #1). Live smoke confirms the route now returns real data.
- **TEA: one green-on-arrival regression guard** → ✓ ACCEPTED by Reviewer: correct per `ac-as-green-regression-guard`; the all-`None` degrade shape pre-exists, so a guard that stays green is the honest expression of "shape preserved." Asserts specific fields (not vacuous).
- **Dev: retained the broad `except Exception` catch-all** → ✓ ACCEPTED by Reviewer: consistent with 160-16/17/18. This feeds an async route + the Frame poll loop where any escape is a 500/blank panel — strictly worse than warn-then-degrade. Not a new pattern; lang-review #1 is satisfied (no longer silent).
- No UNDOCUMENTED spec deviations found — the diff matches TEA's designed interface exactly.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 smells; 100 tests passed, 0 failed; ruff clean | confirmed 0, dismissed 0, deferred 0 |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings |
| 4 | reviewer-test-analyzer | No | Skipped | disabled | Disabled via settings |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings |
| 6 | reviewer-type-design | No | Skipped | disabled | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 1 (CWE-209 str(e) response-body leak) | confirmed 1 (pre-existing, deferred to 160-22), dismissed 0, deferred 1 |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings |
| 9 | reviewer-rule-checker | No | Skipped | disabled | Disabled via settings |

**All received:** Yes (2 enabled returned; 7 disabled via `workflow.reviewer_subagents`)
**Total findings:** 0 confirmed-blocking, 1 confirmed-non-blocking (pre-existing, tracked by 160-22), 0 dismissed

Disabled-subagent domains were assessed directly by the Reviewer (see tagged observations below).

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** A minimal, correct fix that closes the last silent swallow in `data_proxy.py` AND fixes a constant bug the swallow was hiding (`ContextConfig(project_dir=...)` → `TypeError` on every request). Verified live: `/api/context` now returns real data instead of an all-`None` body. Tests green (100 passed), ruff clean, no new security issues. The one security finding is pre-existing and explicitly tracked by story 160-22.

**Data flow traced:** `_get_project_dir()` (env `PF_PROJECT_DIR` or cwd) → `check_context(project_dir=...)` → `ContextResult` → JSON body. On exception → `_safe_exc(e)` (type name only) into `warnings.warn` (server-side log) + degraded all-`None` body. Input is env/cwd, not HTTP request data — no injection vector.

### Rule Compliance (python lang-review, against the diff)
- **#1 silent exception swallowing:** COMPLIANT — `get_context`'s `except` now emits `warnings.warn` before degrading; no longer silent. Broad catch-all retained intentionally (Dev deviation, ACCEPTED — async route/poll loop must never 500).
- **#3 type annotations:** COMPLIANT — `get_context() -> JSONResponse` is annotated; no new params.
- **#4 logging / never log sensitive data:** COMPLIANT — the new warn routes through `_safe_exc(e)` = `type(exc).__name__` (data_proxy.py:55); no raw `str(e)`/path. Cross-file `test_160_18` AST guard stays green.
- **#9 async pitfalls:** NOTED (non-blocking) — `check_context` is a synchronous (blocking) call inside an `async def`; pre-existing, file-wide pattern (every route here does sync I/O), newly reachable now that the constant bug is fixed. Not introduced as a defect by this PR. Captured as a non-blocking Delivery Finding.
- **#10 import hygiene:** COMPLIANT — now-unused `ContextConfig` import removed; ruff confirms no F401.
- **#6 test quality:** COMPLIANT — 4 tests, specific value assertions, mocks patch where used (`data_proxy.check_context`, `context_window.find_transcript`); one documented green-on-arrival guard.
- **#2/#5/#7/#8/#11/#12/#13:** N/A — no mutable defaults, path manipulation, resource handles, deserialization, user-input boundary, dependency, or fix-regression constructs in the diff.

### Observations (tagged by subagent domain)
1. `[VERIFIED]` Constant-bug fix correct — `check_context(project_dir=project_dir)` matches signature `check_context(explicit_session=None, project_dir=None)`; live smoke `PF_PROJECT_DIR=<orchestrator>` returned `{percent:21, tokens:219757, status:"OK", error:None}`, no warn. data_proxy.py:304.
2. `[VERIFIED]` Warn is sanitized — `_safe_exc(e)` returns type name only (data_proxy.py:55); complies with #4 + 160-18 sink convention. data_proxy.py:325.
3. `[VERIFIED]` Degraded shape preserved — `except` returns the same all-`None` body; only the warn was prepended. data_proxy.py:319–332.
4. `[VERIFIED]` Last silent swallow closed — 160-16/17 swept the file's other sites; grep shows no remaining bare/silent `except` in `data_proxy.py`.
5. `[VERIFIED]` Dead-import removal safe — `ContextConfig` was used only at the deleted line; ruff clean.
6. `[SEC]` CWE-209 `str(e)` response-body leak at data_proxy.py:~333 — CONFIRMED but PRE-EXISTING and deferred to story 160-22; not a regression. LOW for this PR; this PR shrinks its blast radius (fires only on genuine errors now).
7. `[SILENT]` (subagent disabled — Reviewer direct) The change is the *inverse* of a silent failure: it converts a silent swallow to fail-loud and fixes the masked bug. No new swallow introduced. VERIFIED.
8. `[TEST]` (disabled — Reviewer direct) Tests are sound; one cosmetic nit — `test_get_context_degrades_to_all_none_on_genuine_exception` emits an unconsumed `UserWarning` into the test summary (the warn fires but isn't wrapped in `pytest.warns`/`recwarn`). Non-blocking style nit, not a correctness issue.
9. `[EDGE]` (disabled — Reviewer direct) Three boundary paths covered: genuine exception (warn+degrade), no-transcript (graceful `no_transcript` sentinel, no warn — no warn-spam), healthy (real data, no warn). VERIFIED.
10. `[TYPE]` (disabled — Reviewer direct) No type-surface changes; `ContextResult` fields read via direct attr + `getattr(..., None)` defaults. Fine.
11. `[DOC]` (disabled — Reviewer direct) New comments are accurate — reference `_safe_exc` and name 160-22 scope; use "below" rather than a brittle line number. No stale docs.
12. `[SIMPLE]` (disabled — Reviewer direct) Minimal 3-edit change; no over-engineering or dead code.
13. `[RULE]` (disabled — Reviewer direct) See Rule Compliance above — lang-review #1/#3/#4/#6/#10 all compliant; #9 noted non-blocking.

### Devil's Advocate
Suppose this code is broken. The most dangerous move here is the one that looks most benign: the route now *actually runs* `check_context` for the first time in its life — every prior call died at `ContextConfig(...)` before touching it. So this PR doesn't just add a warn; it switches on a code path that has never executed in production. What if `check_context` is itself buggy on some input? It is not wrapped in `asyncio.to_thread`, so a slow transcript parse blocks the event loop, and if it raised on a malformed transcript the user would now see a warn every ~5s poll — the very warn-spam we feared. Mitigations checked: `check_context` returns `ContextResult(error="no_transcript"/"no_usage_data")` on the common empty cases WITHOUT raising (verified in source), so the warn fires only on genuinely unexpected failures, not routinely — the `no-transcript` test pins exactly this. A confused user reading the `/api/context` JSON could still see `error: "<some absolute path>"` on a genuine failure — real, but pre-existing and owned by 160-22; this PR strictly reduces how often that path is hit. A malicious user has no new lever: `project_dir` comes from env/cwd, not the request, so the fixed call opens no injection or traversal vector. What about removing the import — could something else import `ContextConfig` transitively from this module? It's a re-export only if referenced; grep shows no other use, and ruff/tests are green. What if `result` lacks an attribute? The healthy branch uses `getattr(result, ..., None)` for the optional fields and direct access for `percent/tokens/status/error`, all of which exist on `ContextResult`. The honest residual risk — sync I/O on the event loop — is file-wide and pre-existing; I logged it as a non-blocking follow-up rather than block a 2-point fix on an architectural pattern shared by every route in the file. Nothing here rises to Critical or High.

**Verdict:** APPROVED — no Critical/High issues. The sole security finding is pre-existing and tracked by 160-22. Tests green, lint clean, live behavior verified.

**Handoff:** To SM (Edmund Blackadder) for finish-story.