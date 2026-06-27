---
story_id: "160-22"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-22: Sanitize Frame response-body info-leaks (data_proxy.py)

## Story Details
- **ID:** 160-22
- **Jira Key:** (none — Jira not configured)
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 2
- **Type:** bug
- **Priority:** p1

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-27T10:16:36Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-27T09:50:52.529141+00:00 | 2026-06-27T09:52:08Z | 1m 15s |
| red | 2026-06-27T09:52:08Z | 2026-06-27T10:04:13Z | 12m 5s |
| green | 2026-06-27T10:04:13Z | 2026-06-27T10:08:53Z | 4m 40s |
| review | 2026-06-27T10:08:53Z | 2026-06-27T10:16:36Z | 7m 43s |
| finish | 2026-06-27T10:16:36Z | - | - |

## Story Summary

Sanitize Frame response-body info-leaks in `pennyfarthing/pennyfarthing-dist/src/pf/frame/data_proxy.py`:

1. **get_project_info** (~L466) — currently returns raw absolute `project_dir` (leaks OS username + filesystem layout) in JSON response body. Sanitize to basename or omit entirely.

2. **get_git_all** (~L274) — currently returns repo-relative paths directly in JSON response body. Sanitize or omit.

3. **get_context** (~L322) — overlaps with 160-19 which has already shipped (fail-loud get_context refactor). Do NOT re-fix; verify no regression exists.

**Context:** These are pre-existing security info-leaks surfaced by the 160-18 Reviewer security pass.

## Acceptance Criteria

- Response bodies for `get_project_info` and `get_git_all` endpoints no longer expose absolute filesystem paths or usernames.
- Response bodies for `get_project_info` and `get_git_all` endpoints no longer expose sensitive path information.
- Tests assert sanitized output (no absolute paths, no usernames).
- No regression in `get_context` behavior from 160-19 ship.

## Delivery Findings

### TEA (test design)

- **Conflict** (non-blocking): The session story summary / SM assessment state get_context's body `str(e)` is out of scope ("already addressed by 160-19"), but 160-19's shipped artifact deferred it to 160-22 and the leak is live. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (L333 `"error": str(e)` → `_safe_exc(e)`; scope reconciled in this RED — see Design Deviations). *Found by TEA during test design.*
- **Improvement** (non-blocking): Surveyed the other `data_proxy.py` routes for additional response-body path/secret leaks — `get_mode` (pid/platform), `get_identity` (avatarUrl), `get_story`, and `_get_git_info.dirtyFiles` (repo-relative paths) are not sensitive-path disclosures. The three sinks in this story (project_info, git_all, get_context) appear to be the complete response-body info-leak set in this file. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (no further action needed). *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation. Confirmed TEA's survey: live smoke against the real repo (`PF_PROJECT_DIR=<orchestrator>`) returned `project-info {name: orc-penny, path: orc-penny}` and `git/all` paths `['.', 'pennyfarthing']` — no absolute path in any body. The fix is a pure-pathlib value change with no external dependency, so mock-vs-real divergence (the 154-1 lesson) does not apply here. *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): `get_git_all` `Path(repo["path"]).name or repo["path"]` re-emits the raw value for empty-basename inputs (`"/"`, `""`, `"//"`). For the legitimate `"."` default the result is identical; only the degenerate `path: /` misconfig surfaces a (non-sensitive) `"/"`. Recommend `Path(repo["path"]).name or "."` to match the existing `_get_repos_config` fallback style (`Path(project_dir).name or "project"`, L244). Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (L278; one-char hardening — fold into a follow-up, not worth a rework cycle). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `get_context` SUCCESS path returns `result.error` unsanitised. Safe today (`check_context` only sets the literals `"no_transcript"`/`"no_usage_data"`), but a latent CWE-209 if a future `check_context` path sets `result.error` to a raw message/path. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (~L319; out of this diff — add a defensive comment or whitelist if `check_context` ever changes). *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 3 findings (0 Gap, 0 Conflict, 0 Question, 3 Improvement)
**Blocking:** None

- **Improvement:** Surveyed the other `data_proxy.py` routes for additional response-body path/secret leaks — `get_mode` (pid/platform), `get_identity` (avatarUrl), `get_story`, and `_get_git_info.dirtyFiles` (repo-relative paths) are not sensitive-path disclosures. The three sinks in this story (project_info, git_all, get_context) appear to be the complete response-body info-leak set in this file. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py`.
- **Improvement:** `get_git_all` `Path(repo["path"]).name or repo["path"]` re-emits the raw value for empty-basename inputs (`"/"`, `""`, `"//"`). For the legitimate `"."` default the result is identical; only the degenerate `path: /` misconfig surfaces a (non-sensitive) `"/"`. Recommend `Path(repo["path"]).name or "."` to match the existing `_get_repos_config` fallback style (`Path(project_dir).name or "project"`, L244). Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py`.
- **Improvement:** `get_context` SUCCESS path returns `result.error` unsanitised. Safe today (`check_context` only sets the literals `"no_transcript"`/`"no_usage_data"`), but a latent CWE-209 if a future `check_context` path sets `result.error` to a raw message/path. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py`.

### Downstream Effects

- **`pennyfarthing-dist/src/pf/frame/routes`** — 3 findings

### Deviation Justifications

3 deviations

- **Scope expansion: get_context response-body `str(e)` IS in 160-22**
  - Rationale: SOUL #1/#14 — a live response-body info-leak in the exact file this security story sanitises, owned by no other story, must not ship. Higher-authority evidence (the upstream story's artifact + the live code) overrides the session's mistaken interpretation.
  - Severity: major (scope)
  - Forward impact: Dev makes a one-line change (`str(e)` → `_safe_exc(e)`); 160-19's tests stay green (`_safe_exc` returns a non-empty string). Reviewer may scope it back out, but the leak would then need its own story.
- **Contract choice: sanitise `path` to basename, do NOT omit the field**
  - Rationale: `test_frame_routes.py::test_project_info_shape` asserts `"path" in data` (Node.js shape parity, story 48-2 AC5); omitting breaks it and any client reading `path`. Basename removes the leak while keeping every existing route test green — Dev should not need to edit `test_frame_routes.py`.
  - Severity: minor
  - Forward impact: none — backward-compatible response shape preserved.
- **Two intentional green-on-arrival guards**
  - Rationale: pins the regression boundary so Dev's fix touches only the leaking value, not the response shape.
  - Severity: minor
  - Forward impact: none.

## Design Deviations

### TEA (test design)

- **Scope expansion: get_context response-body `str(e)` IS in 160-22**
  - Spec source: session `## Story Summary` item 3 / `## SM Assessment` ("get_context ... OUT of scope — already addressed by shipped 160-19"); story title ("get_context str(e) (L322) overlaps 160-19")
  - Spec text: "get_context (~L322) — overlaps with 160-19 which has already shipped ... Do NOT re-fix; verify no regression."
  - Implementation: Added `test_get_context_error_body_does_not_leak_raw_exception` requiring the body `error` to be sanitised to the exception type name. 160-19's SHIPPED test (`test_160_19_get_context_fail_loud.py`) states in three places that the response-BODY `str(e)` sanitisation was DEFERRED to 160-22; the leak is live at `data_proxy.py:333` (`"error": str(e)`). The session's "already done / out of scope" reading is factually wrong.
  - Rationale: SOUL #1/#14 — a live response-body info-leak in the exact file this security story sanitises, owned by no other story, must not ship. Higher-authority evidence (the upstream story's artifact + the live code) overrides the session's mistaken interpretation.
  - Severity: major (scope)
  - Forward impact: Dev makes a one-line change (`str(e)` → `_safe_exc(e)`); 160-19's tests stay green (`_safe_exc` returns a non-empty string). Reviewer may scope it back out, but the leak would then need its own story.

- **Contract choice: sanitise `path` to basename, do NOT omit the field**
  - Spec source: story title ("sanitize to basename/omit"); `## SM Assessment` ("Confirm whether the desired contract is basename-only vs full omission")
  - Spec text: "sanitize to basename/omit"
  - Implementation: Tests pin `path` present + value == basename (not absent) for both get_project_info and get_git_all.
  - Rationale: `test_frame_routes.py::test_project_info_shape` asserts `"path" in data` (Node.js shape parity, story 48-2 AC5); omitting breaks it and any client reading `path`. Basename removes the leak while keeping every existing route test green — Dev should not need to edit `test_frame_routes.py`.
  - Severity: minor
  - Forward impact: none — backward-compatible response shape preserved.

- **Two intentional green-on-arrival guards**
  - Spec source: TEA pattern `ac-as-green-regression-guard`
  - Spec text: "When an AC is 'behavior X is UNCHANGED' (a preservation requirement), its test is correctly GREEN on HEAD."
  - Implementation: `test_git_all_preserves_repo_fields` (relative `alpha` round-trips, fields intact) and the `name`-basename half of `test_project_info_preserves_shape_with_basename` are GREEN today by design — they guard that the sanitisation does not drop fields/shape.
  - Rationale: pins the regression boundary so Dev's fix touches only the leaking value, not the response shape.
  - Severity: minor
  - Forward impact: none.

### Dev (implementation)
- No deviations from spec. Implemented TEA's designed interface verbatim: `get_project_info.path` → `Path(project_dir).name`; `get_git_all.path` → `Path(repo["path"]).name or repo["path"]`; `get_context.error` → `_safe_exc(e)`. No new imports (`Path` and `_safe_exc` already present); response shapes unchanged; the broad `except`/`warnings.warn` in get_context were left untouched (only the body `error` value changed). I adopted TEA's scope expansion (get_context body sanitisation) — that scope deviation is owned and documented under TEA above; nothing further to log here.

### Reviewer (audit)
- **TEA: Scope expansion — get_context body `str(e)` IS in 160-22** → ✓ ACCEPTED by Reviewer: Sound and required. Independently verified — 160-19's shipped test docstring + the Dev/Reviewer 160-19 sidecars all state the response-body leak was DEFERRED to 160-22, and the live code carried `"error": str(e)` at L333. The session's "out of scope" reading was the error; bringing it in-scope is correct (SOUL #1/#14) and is NOT a double-fix (160-19 only fixed the constant bug + the warning).
- **TEA: Contract — basename, not omit** → ✓ ACCEPTED by Reviewer: Correct. `test_frame_routes.py::test_project_info_shape` asserts `"path" in data`; basename keeps the Node.js shape (48-2 AC5) and the regression batch confirms zero existing-test edits. Omit would have broken backward compat.
- **TEA: Two green-on-arrival guards** → ✓ ACCEPTED by Reviewer: Legitimate preservation guards (`ac-as-green-regression-guard`), correctly pinning that the fix touches only the leaking value.
- **Dev: No deviations** → ✓ ACCEPTED by Reviewer: Confirmed — the diff implements TEA's interface verbatim, no new imports, shapes unchanged.
- No UNDOCUMENTED deviations found: the diff matches the logged scope exactly.

## Branch Info

**Branch Strategy:** gitflow (feat/160-22-frame-response-sanitize off develop)
**Branch:** feat/160-22-frame-response-sanitize

## SM Assessment

**Routing:** Phased TDD workflow, 2pts, p1 security fix → SM → TEA (RED) → Dev (green) → Reviewer → SM (finish). Handing to TEA to write failing tests first.

**Scope is well-bounded:** Two concrete response-body sinks in `data_proxy.py` — `get_project_info` (~L466, absolute `project_dir`) and `get_git_all` (~L274, repo paths). The third sink (`get_context` str(e), ~L322) is OUT of scope — already addressed by shipped 160-19; TEA should only guard against regression, not re-fix it.

**For TEA (Lord Melchett):** Write tests that assert the JSON response bodies for these two endpoints contain no absolute filesystem paths and no OS username. Confirm whether the desired contract is basename-only vs full omission per endpoint before writing assertions — the story leaves "basename or omit" open. These are pre-existing leaks (160-18 reviewer-security pass), so existing tests likely assert the leaky shape; expect to update them.

**No blockers.** No deps, no Jira (local kanban), merge gate clear (no open PRs).

## TEA Assessment

**Tests Required:** Yes
**Reason:** p1 security story — response-body info-leaks at API boundaries.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_22_response_body_sanitization.py` (new) — 6 tests covering the three response-body sinks in `data_proxy.py`.

**Tests Written:** 6 tests covering 3 sinks
**Status:** RED (verified — 5 failed on the leak assertion, 1 green-on-arrival shape guard, 0 errored). Verified by direct scoped run (`uv run pytest <file> -rA`), NOT testing-runner (per sidecar: don't trust the spy's prose on security RED reasons). Each RED failure output shows the actual leak in the body (absolute path / `..` traversal / raw exception string).

| # | Test | Sink | RED/GREEN |
|---|------|------|-----------|
| 1 | `test_project_info_does_not_leak_absolute_path` | get_project_info `path` | RED |
| 2 | `test_project_info_preserves_shape_with_basename` | get_project_info `path` | RED (basename driver) |
| 3 | `test_git_all_does_not_leak_absolute_repo_path` | get_git_all `path` | RED |
| 4 | `test_git_all_strips_parent_traversal_to_basename` | get_git_all `path` | RED |
| 5 | `test_git_all_preserves_repo_fields` | get_git_all shape | GREEN-guard |
| 6 | `test_get_context_error_body_does_not_leak_raw_exception` | get_context `error` | RED |

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #11 security — no sensitive fs path/exception disclosure at API boundaries | tests 1,3,4,6 (`_abs_path_leaks` walker + sentinel + raw-`str(e)` checks) | failing |
| #6 test quality — meaningful assertions, patch-where-used | all (each asserts specific values; `check_context` patched on `data_proxy`, lang-review #6) | n/a |

**Rules checked:** #11 (primary) has direct RED coverage; #6 self-checked.
**Self-check:** 0 vacuous tests. Every test asserts a specific value; no `assert True`/`is_none()`-on-always-None/bare truthy. The one green guard (`preserves_repo_fields`) checks field presence + a basename round-trip, not a tautology.

### DESIGNED INTERFACE for Dev (Baldrick) — GREEN

Keep each response SHAPE backward-compatible (Node.js parity); sanitise only the VALUE. Reuse the existing module-level `_safe_exc` (added by 160-18).

1. **get_project_info** (~L472): `"path": Path(project_dir).name` (basename, == `name`).
2. **get_git_all** (~L273): `"path": Path(repo["path"]).name or repo["path"]` — basename; the `or repo["path"]` keeps a bare `"."` for the default repo (`Path(".").name` is `""`).
3. **get_context** (~L333): `"error": _safe_exc(e)` — NEVER raw `str(e)`. (Do not touch the warning at L327 — already sanitised.)

No existing `test_frame_routes.py` test needs editing (basename keeps `"path" in data` true). Cross-file guard to respect: `test_160_18`'s AST check still forbids raw-`exc` in `warnings.warn` — don't regress the warns.

**Handoff:** To Dev for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` — sanitised the three response-body sinks (14 insertions, 4 deletions): `get_project_info.path` → basename; `get_git_all.path` → basename with `or repo["path"]` fallback; `get_context` body `error` → `_safe_exc(e)`. Each change carries an explanatory comment; no new imports.

**Tests:** 6/6 passing (GREEN) on `test_160_22_response_body_sanitization.py`. Regression batch 80/80 (`test_160_18` AST guard, `test_160_19` get_context, `test_frame_routes.py` shape tests) — basename keeps `"path" in data` true, so no existing test needed editing. `ruff check` clean. Live smoke against the real repo: no absolute path in any body (`path: orc-penny`; git/all `['.', 'pennyfarthing']`).

**Branch:** feat/160-22-frame-response-sanitize (pushed, commit `af9dcad9c`)

**For Reviewer (Captain Darling):** Diff is 14/-4 in one file. Note the scope point: this PR sanitises `get_context`'s body `error` (the live `str(e)` leak at L333). 160-19 explicitly deferred that to 160-22 (see its test docstring + the Dev `fail-loud-sweep-part5` sidecar) — the session's original "out of scope" reading was wrong; reconciled under Design Deviations → TEA. The broad `except Exception` catch-alls were intentionally left in place (async routes / poll loop must never 500) consistent with 160-16/17/18/19.

**Handoff:** To Reviewer for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 smells (86/86 tests green, ruff clean) | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — did myself (clean; degenerate `/` & home-dir basename are non-issues within the basename contract) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — did myself (no new swallows; existing broad excepts untouched) |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings — did myself (6 meaningful tests; 1 LOW nit: noqa'd unused `pytest` import) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — did myself (comments accurate; get_context comment correctly updated from "left as-is" to "sanitised") |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — did myself (all values remain `str`; no type changes) |
| 7 | reviewer-security | Yes | findings | 2 LOW | confirmed 2, dismissed 0, deferred 0 (both non-blocking) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — did myself (minimal 3-value change; no dead code/over-engineering) |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — did myself (Rule Compliance below) |

**All received:** Yes (2 enabled returned; 7 disabled via `workflow.reviewer_subagents`)
**Total findings:** 2 confirmed (both LOW, non-blocking), 0 dismissed, 0 deferred-blocking

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** A correctly-scoped p1 security fix. The three response-body info-leaks (CWE-209) in `data_proxy.py` are closed for all realistic inputs; response shapes are preserved (Node.js parity), tests are green (86/86), ruff clean, and the scope reconciliation (get_context body, deferred here by 160-19) is sound and well-documented. No Critical/High findings — only two LOW non-blocking observations.

### Rule Compliance (lang-review/python.md — done myself, rule_checker disabled)

| Rule | Applies? | Verdict |
|------|----------|---------|
| #1 silent exception swallowing | yes (get_context except) | Compliant — no NEW swallow; pre-existing broad catch retained intentionally (async route / poll loop must never 500), only the body `error` value changed |
| #3 type annotations | yes | Compliant — route signatures unchanged (`-> JSONResponse`); all sanitised values are `str` |
| #4 logging/sensitive data | yes (the warn) | Compliant — `warnings.warn` line untouched, still routes through `_safe_exc`; no sensitive data added |
| #5 path handling (CWE-838/59) | checked | N/A — no `read_text`/`open` without encoding and no `Path.resolve()` in the diff; uses `pathlib.Path` (preferred) |
| #6 test quality | yes | Compliant — 6 tests with specific-value assertions; 1 LOW: noqa'd unused `pytest` import |
| #11 security (info-leak at boundary) | yes — THE story | Compliant — bodies no longer disclose absolute paths / raw exception messages |
| #13 fix-introduced regressions | yes | Compliant — 80-test regression batch green; basename keeps `"path" in data` true |
| #2/#7/#8/#9/#10/#12 | no | Not triggered by this diff |

### Observations (tags; disabled subagents self-verified)

- **[VERIFIED] [SEC] get_project_info closed** — `data_proxy.py:487` `Path(project_dir).name` — `.name` never contains a separator, so no absolute path survives; degenerate `/`→`""` is not a leak. Complies with rule #11.
- **[VERIFIED] [SEC] get_git_all closed for real inputs** — `data_proxy.py:278` strips absolute parents and `../` traversal; the internal absolute `repo_path` (used only for `_get_git_info`) is NOT returned — traced: only `repo["path"]` basename reaches the body. `dirtyFiles[].path` from `git status --porcelain` are repo-RELATIVE (verified `_get_git_info` L177 `path = line[3:]`), not a leak.
- **[VERIFIED] [SEC] get_context closed + consistent** — `data_proxy.py:339` `_safe_exc(e)` = `type(e).__name__`, matching the 160-18 warning sink (one-truth, SOUL #2). 160-19's degrade-shape test stays green (non-empty string).
- **[LOW] [SEC] get_git_all `or repo["path"]` degenerate residual** — re-emits `"/"`/`""`/`"//"` verbatim for empty-basename inputs. Non-sensitive, absurd config; recommend `or "."` (matches L244 style). Non-blocking Delivery Finding. *(security subagent, confirmed + downgraded by blast radius.)*
- **[LOW] [SEC] get_context success-path `result.error` latent risk** — out-of-diff; safe today (sentinel strings only). Non-blocking Delivery Finding. *(security subagent.)*
- **[LOW] [TEST] noqa'd unused `pytest` import** in the new test file — harmless, documented "for parity/future use".
- **[VERIFIED] [SIMPLE] minimal** — 3 value changes + comments, no dead code, no new imports.
- **[VERIFIED] [DOC] comments accurate** — the get_context comment correctly updated from "left as-is here" to "likewise sanitised via _safe_exc".
- **[VERIFIED] [TYPE] no type regressions** — all sanitised fields remain `str`.
- **[N/A] [EDGE] / [SILENT] / [RULE]** — covered under Rule Compliance + the edge cases above; no boundary/silent-failure/rule violations.

**Data flow traced:** `PF_PROJECT_DIR`/cwd → `_get_project_dir()` → `Path(...).name` → body `path` (absolute form never reaches the body). `repos.yaml path` → `repo["path"]` → `Path(...).name or repo["path"]` → body `path` (internal absolute `repo_path` used for git, not returned). `check_context` exception → `_safe_exc(e)` → body `error`. All three sinks safe.

**Tenant isolation:** N/A — no multi-tenant data or trait methods in this code.

### Devil's Advocate

Argue this is broken. A motivated network client hitting the localhost Frame API wants the operator's home directory. Could they still get it? `get_project_info.path` is now a basename — but the basename IS the project folder name, which for many users encodes nothing, yet for a repo cloned to `/home/alice/work` the basename "work" is innocuous while `/home/alice` would not be reachable. What about a repo deliberately checked out AT the home directory (`/home/alice`)? Then `get_git_all` would surface basename "alice" — the username. That is a real residual, but it is inherent to the agreed "basename" contract (the story explicitly chose basename/omit), affects only a pathological layout, and discloses a single folder name rather than the full path tree. A confused operator misreading `path: "."` in `git/all` as "no repo configured"? The `.` is the established default and the UI consumed it before this change unchanged. A stressed filesystem: `Path()` on a bizarre value — `Path("\x00")` would raise, but `_get_project_dir`/`repos.yaml` cannot produce a NUL (env + YAML string). What if `repos.yaml` has `path: ../../../../etc`? `Path("../../../../etc").name` = "etc" — traversal stripped, only "etc" shown (not sensitive). What if an exception type name itself is attacker-controlled? It cannot be — exception classes are defined in source, not derived from request data; `type(e).__name__` is bounded. The one genuine gap the advocate surfaces is the degenerate `or repo["path"]` re-emitting `"/"` — already captured as a LOW non-blocking finding. Conclusion: no path for a network client to extract the absolute project path or a raw exception message through the changed routes; the residuals are degenerate-input or contract-inherent, none Critical/High.

**Handoff:** To SM for finish-story.