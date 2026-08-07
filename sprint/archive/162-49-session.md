---
story_id: "162-49"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-49: Fix live break in persona route: data_proxy.py:72 calls load_persona(project_dir, session_id=...) vs persona.py:93 signature load_persona(agent_name, project_root=None) → TypeError. The 4 test_frame_routes failures are cwd-dependent-VACUOUS elsewhere: data_proxy.py:35-42 takes project dir from os.getcwd(), so from pennyfarthing-dist/ the route 404s before line 72 and tests pass vacuously (6123/0 vs 6119/4). Include conftest PF_PROJECT_DIR fixture so suite numbers can't depend on cwd (162-29 reviewer finding)

## Story Details
- **ID:** 162-49
- **Jira Key:** (none — kanban story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-49-persona-route-live-break
- **PR:** #190

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-07T14:59:44Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-07T13:33:39Z | 2026-08-07T13:35:17Z | 1m 38s |
| red | 2026-08-07T13:35:17Z | 2026-08-07T13:51:50Z | 16m 33s |
| green | 2026-08-07T13:51:50Z | 2026-08-07T14:04:04Z | 12m 14s |
| review | 2026-08-07T14:04:04Z | 2026-08-07T14:18:26Z | 14m 22s |
| green | 2026-08-07T14:18:26Z | 2026-08-07T14:29:09Z | 10m 43s |
| review | 2026-08-07T14:29:09Z | 2026-08-07T14:59:44Z | 30m 35s |
| finish | 2026-08-07T14:59:44Z | - | - |

## Sm Assessment

**Story:** 162-49 (2 pts, p1, tdd) — fix a LIVE break plus a test-vacuity mechanism that let the break hide.

**Scope — two coupled defects, one story:**
1. **Live TypeError:** `frame/routes/data_proxy.py:72` calls `load_persona(project_dir, session_id=session_id)` but `prime/persona.py:93` defines `load_persona(agent_name, project_root=None)`. Any request reaching that line raises.
2. **cwd-dependent vacuity:** `data_proxy.py:35-42` derives the project dir from `os.getcwd()`. Run pytest from `pennyfarthing-dist/` and `_detect_pf_project` finds no `.pennyfarthing/`, the route 404s before line 72, and the 4 `test_frame_routes` tests pass vacuously (6123/0 from one cwd, 6119/4 from another). This fooled the 162-29 Reviewer's cycle-1 count AND `reviewer-preflight` — it is a pipeline-honesty defect, not just a flake.

**Acceptance shape (TEA derives formal ACs):**
- RED pins the TypeError at the real callsite with a test that reaches line 72 (project dir fixture present, not 404-shortcircuited).
- A conftest fixture (`PF_PROJECT_DIR` or equivalent) makes the frame-route tests cwd-independent — same pass/fail count from repo root and from `pennyfarthing-dist/`.
- Green: the route calls `load_persona` with its actual signature and the 4 formerly-failing tests pass non-vacuously.
- Suite stays exit 0.

**Routing:** 3-phase TDD (red → green → review), TEA first. Peloton-inline mode — agents return to SM, no relay markers.

**Risk notes for TEA:** the fix has two plausible shapes (change the call vs change the signature) — that's Dev's call, but the RED tests must pin behavior (persona payload for a valid agent/session), not the current broken signature. Beware `os.getcwd()` patching vs fixture injection; the story asks for the fixture so suite numbers can't depend on cwd — an env-var or conftest chdir is acceptable, a per-test monkeypatch scattered 4 times is not.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (failing — ready for Dev)

### Acceptance Criteria (derived by TEA — sprint YAML carried none)

- **AC1** `GET /api/persona` against a valid PF project returns HTTP 200 and does not raise. Today it raises `TypeError: load_persona() got an unexpected keyword argument 'session_id'`.
- **AC2** The 200 payload matches the persona contract the TUI header already consumes (`tui/app.py::_render_header` / `_resolve_portrait`) and that `frame/ws_push.py::fetch_persona` already produces: `character`, `role`, `roleDescription`, `quote`, `theme`, `trait`, `isStreaming`, `portraitPath` — with `character`/`role`/`theme` reflecting the active agent and configured theme, not placeholders.
- **AC3** `GET /api/persona/full` returns 200 and a superset of the AC2 keys.
- **AC4** The route resolves the active agent from the project dir it was given (`.session/agents/`, the same resolution statusline and `fetch_persona` use) — never from `os.getcwd()`. Changing the active agent changes the persona returned.
- **AC5** Absent-input cases stay 404 with a distinguishable `error` string: no active agent (and unknown agent) → `"No active persona"`; non-PF project dir → `"Not a Pennyfarthing project"`.
- **AC6** `pf.prime.persona.load_persona`'s signature is unchanged. It has 6 correct production callers (`ws_push`, `persona/cli`, `prime/cli` x2, `prime/tiers` x2) and ~25 correct test callers; `data_proxy.py:72,85` are the only wrong ones. The fix goes in the caller, not the shared API.
- **AC7** cwd-independence: `/api/persona` returns identical status and body from the orchestrator root, from `pennyfarthing-dist/`, and from an unrelated temp dir; and no data-proxy GET route short-circuits on `"Not a Pennyfarthing project"` while `PF_PROJECT_DIR` names a real project.
- **AC8** The cwd-independence mechanism is a shared conftest fixture (`pf_project_dir`), wired in once at the `client` fixture — not a monkeypatch copy-pasted per test.

### Test Files

- `pennyfarthing-dist/src/pf/tests/conftest.py` — new shared fixtures: `pf_project_dir` (hermetic PF project under tmp_path, exports `PF_PROJECT_DIR`, clears `PROJECT_ROOT`/`CLAUDE_PROJECT_DIR`/`PF_THEME`/`SESSION_ID`), `active_agent` (retarget the `.session/agents/` marker), `run_from_cwd` (chdir for cwd-invariance probes).
- `pennyfarthing-dist/src/pf/tests/test_162_49_persona_route.py` — new, 15 tests across AC1–AC8.
- `pennyfarthing-dist/src/pf/tests/test_frame_routes.py` — `client` fixture now depends on `pf_project_dir` (one wiring point for the whole module); 4 pre-existing vacuous assertions de-vacuumed.

**Tests Written:** 15 new + 4 pre-existing tightened, covering 8 ACs.

### Vacuity Repair (pre-existing tests)

Four assertions admitted both the success path and the cwd short-circuit, so they held even when the route never reached the code under test:

- `TestPersonaRoute::test_get_persona_returns_json` — `status_code in (200, 404)` → `== 200` + payload assertion
- `TestPersonaRoute::test_get_persona_full_returns_json` — same
- `TestPersonaRoute::test_persona_not_found_returns_404` — `if status == 404:` guard meant body asserts never ran; the no-active-agent state is now *constructed*
- `TestBackwardCompatibility::test_error_responses_have_error_field` — same guard pattern

### Fail-For-The-Right-Reason Evidence

Frame-route files (`test_frame_routes.py` + `test_162_49_persona_route.py`):

| cwd | before (develop) | after (this branch) |
|-----|------------------|---------------------|
| orchestrator root | 4 failed / 66 passed | 14 failed / 71 passed |
| `pennyfarthing-dist/` | 0 failed / 70 passed | 14 failed / 71 passed |

Whole `src/pf/tests/` suite — the number the 162-29 Reviewer and `reviewer-preflight` were fooled by:

| cwd | before (develop) | after (this branch) |
|-----|------------------|---------------------|
| orchestrator root | 4 failed / 6119 passed | 14 failed / 6124 passed / 4 skipped |
| `pennyfarthing-dist/` | 0 failed / 6123 passed | 14 failed / 6124 passed / 4 skipped |

Byte-identical counts from both cwds at suite scale — the vacuity channel is closed. All 14 failures are the new/tightened tests; zero collateral damage to the other ~6110. Every failure is the real defect (`TypeError: load_persona() got an unexpected keyword argument 'session_id'` at `data_proxy.py:72`), not a collection error. Satisfiability was verified with a throwaway probe fix delegating both routes to `fetch_persona()`: 85/85 passed. Probe reverted; only test files are modified.

**Handoff:** To Dev for implementation (GREEN).

## Dev Assessment

**Status:** GREEN (all 14 RED tests pass; no collateral damage)
`Commit:` 71e30cc08 (GPG-signed, `G`), pushed to `origin/feat/162-49-persona-route-live-break`

### Implementation

Two files changed, both in `pennyfarthing-dist/src/pf/frame/`.

`ws_push.py` — extracted `fetch_persona`'s body into `build_persona_payload(project_dir, full=False)`. Same logic, same fail-loud/degrade semantics, but the project dir is now a parameter instead of being read from the environment inside the function. `fetch_persona()` is now a one-line delegation, so the WebSocket channel's behavior is unchanged. `full=True` adds `roleTitle`, `quirk`, `motto`, `helperName`, `helperStyle` on top of the base contract.

`routes/data_proxy.py` — both persona routes now call `_persona_response(full)`, which resolves the project dir via the module's own `_get_project_dir()` (so `PF_PROJECT_DIR` wins, `os.getcwd()` is only the last-resort fallback and is never reached under the fixture), keeps the existing `_detect_pf_project` 404, and delegates payload construction to `build_persona_payload`. The broken `load_persona(project_dir, session_id=..., full=...)` calls are gone, and the now-unused `load_persona` import was dropped. `load_persona`'s signature is untouched (AC6).

Why delegate rather than inline a corrected `load_persona` call: the route needed four things — agent resolution from `.session/agents/`, the correct `load_persona` call, portrait resolution, and the TUI payload shape. `fetch_persona` already had all four, correct and in production use. Inlining a fixed copy would have left two implementations of one contract, which is the condition that produced this bug. The extraction is net-neutral in line count.

`build_persona_payload` lives in `ws_push.py` because that is where the working implementation was; it is imported lazily inside `_persona_response` so no import cycle is possible in either direction (`ws_push` already imports `data_proxy` helpers lazily).

### Test Results

| scope | orchestrator root | `pennyfarthing-dist/` |
|-------|-------------------|------------------------|
| `test_162_49_persona_route.py` + `test_frame_routes.py` | 85 passed / 0 failed | 85 passed / 0 failed |
| whole `src/pf/tests/` | 6138 passed / 4 skipped / **0 failed** | 6129 passed / 4 skipped / **9 failed** |

The 14 RED tests are green, and none of the other ~6124 regressed — from the orchestrator root the suite is fully green, exit 0.

The 9 failures from the `pennyfarthing-dist/` cwd are a **second, independent cwd-dependence channel**, not a regression and not in this story's scope. Verified: they fail identically with my two files stashed (i.e. at TEA's RED commit), and they also fail at `514f9a6ac~1` — before 162-29's workflow changes. All 9 are `pf workflow list` / `pf workflow show` invocations exiting 1 because workflow discovery resolves the project root from the cwd and finds no `.pennyfarthing/` above `pennyfarthing-dist/`. Files: `test_guided_tour.py` (3), `test_workflow_list_team.py` (5), `test_dead_scripts.py` (1). This is exactly the class TEA's third Delivery Finding predicted. Logged as a Dev Delivery Finding; it needs its own story.

This also means TEA's claim of byte-identical suite counts from both cwds was accurate for the frame-route module but not for the whole suite — the persona vacuity channel is closed, the workflow-discovery one is not.

### Lint

`ruff check` clean on both touched files. `ruff format --check` flags `ws_push.py`, but every hunk is pre-existing drift elsewhere in the file (`ThreadPoolExecutor` call, `fetch_git`'s dict literal, `subprocess.run` arg wrapping, `POLL_CHANNELS`); zero hunks touch my added lines. Left unformatted deliberately — reformatting the file would bury a 40-line change in ~200 lines of unrelated churn.

### For Reviewer

- `/api/persona/full`'s superset keys are my invention — TEA's Question finding correctly notes the contract was never written down. The tests only require "superset of base"; I chose the remaining `Persona` fields. If that shape matters to the IDE sidebar, it should be specified.
- `ws_push._get_project_dir()` honors `FRAME_PROJECT_DIR` before `PF_PROJECT_DIR`; `data_proxy._get_project_dir()` does not. Delegating to `build_persona_payload(project_dir)` rather than to `fetch_persona()` is what keeps that divergence out of the HTTP path — the route's own resolution stays authoritative. Worth confirming the two resolvers should differ at all.
- Per TEA's second finding, this route has no confirmed live consumer. I fixed it as scoped; whether it should exist is a separate call.

> Superseded by the Rework Round 1 section below. The second bullet above was inverted — delegating with an explicit project dir preserved the resolver divergence rather than containing it, which is B1.

## Reviewer Assessment

**Verdict:** APPROVED

`Cycle 1 verdict was REJECTED` on 4 blocking findings. Cycle 2 verified all four fixed at `faa304554` + `1b38404eb`; the verdict line above is the cycle-2 result. The cycle-1 findings below are preserved unchanged as the record of what was rejected and why — per-finding disposition is in the `Cycle 2 Re-Review` section at the end of this assessment.

`Reviewed:` branch `feat/162-49-persona-route-live-break`, commits `94a112cc3` (TEA) and `71e30cc08` (Dev), diffed against `develop`. Review was by measurement, not diff-reading: every finding below was reproduced first-hand. Working tree left clean (`git status --short` empty); all probes ran in `/tmp` scratch copies, since removed.

`What is genuinely fixed:` defect 1 is really dead. The `TypeError` is gone, `load_persona`'s signature is untouched (`inspect.signature` returns `(agent_name: 'str', project_root: 'Path | None' = None)` — AC6 holds), the duplicate persona builder is deleted rather than patched, and the four vacuous assertions TEA identified are genuinely de-vacuumed (constructed 404 states, not guard-wrapped hopes). The extraction is the right shape. The rejection is not about the approach.

### Blocking findings

`B1 — the route is still cwd-dependent in production; AC4 is not met, and the docstring asserts the opposite.` [RULE] [TYPE]
`data_proxy.py:77` claims resolution "follows `PF_PROJECT_DIR`, never `os.getcwd()`". `data_proxy.py:37` is unchanged: `os.environ.get("PF_PROJECT_DIR", os.getcwd())`. The only project-dir variable production sets is `FRAME_PROJECT_DIR` (`frame/launcher.py:128`), which this resolver does not read — nothing in `src/pf/frame` or `src/pf/launch` ever sets `PF_PROJECT_DIR`. Measured under production-shaped env (`FRAME_PROJECT_DIR` set, cwd elsewhere): HTTP `/api/persona` and `/api/persona/full` both return `404 {"error": "Not a Pennyfarthing project"}` while `fetch_persona()` on the identical env returns the full payload. Two transports, one shared builder, two different answers. AC4 says "never from `os.getcwd()`"; AC7 holds only because the fixture sets `PF_PROJECT_DIR`. The live break is converted from a 500 to a wrong 404 in the configuration `pf frame start --project-dir X` explicitly supports. I verified the fix in a scratch copy — align `data_proxy._get_project_dir()` with `ws_push`'s (`FRAME_PROJECT_DIR` → `PF_PROJECT_DIR` → cwd) and add `FRAME_PROJECT_DIR` to the fixture's cleared set: 110/110 related tests pass and the probe flips to 200 on both routes. Two lines. Independently confirmed by the rule-checker and type-design subagents.

`B2 — the extraction regressed the fail-loud contract on the channel that has a live consumer.` [TYPE] [RULE]
`_get_project_dir()` was the first statement inside `fetch_persona`'s `try`; it is now evaluated in the caller, outside it. `os.getcwd()` raises `FileNotFoundError` when the cwd has been unlinked — reachable, since the launcher sets the server's cwd to the project dir, so a `git worktree remove`, a `mv`, or a temp-dir cleanup while Frame is alive triggers it. Measured on both sides with the cwd deleted: on `develop`, `fetch_persona()` returns `{}` and emits `UserWarning: Failed to load persona: [Errno 2] No such file or directory`; on `HEAD` it raises `FileNotFoundError`, which `poll_and_broadcast`'s `except Exception: pass` (`ws_push.py:786-787`) swallows. The persona panel silently stops updating with zero diagnostic — the exact swallow epic 160 spent five stories removing, and the contract the comment at `ws_push.py:541-547` still claims to uphold. The Dev assessment states "same fail-loud/degrade semantics" and "the WebSocket channel's behavior is unchanged"; both are measurably false. Fix: call `_get_project_dir()` inside the `try`.

`B3 — blocking network I/O now runs on the ASGI event loop, for up to ~120s per request.` [SEC] [TYPE] [RULE]
`get_persona`/`get_persona_full` are `async def` with no `await` and call the synchronous `_persona_response` inline, so `build_persona_payload` → `resolve_portrait_path` → `portrait_cdn.fetch_portrait` executes on the loop. On a cache miss `fetch_portrait` walks all four size buckets, each `urllib.request.urlopen(req, timeout=30)` (`portrait_cdn.py:135`, `_SIZE_ORDER` at `:74-79`), and the negative result is never cached, so every request retries. Measured with a stubbed 1s download: one `/api/persona` request issued 4 CDN attempts, and a concurrent `/ping` issued at +0.1s did not complete until +4.14s — the loop was stalled for the full request. In production that is up to 120s of frozen WebSocket pushes, OTLP ingest, and `/health` whenever the CDN is slow or the machine is offline. Genuinely new: on `develop` the route raised `TypeError` before reaching any of this. The WebSocket side offloads the identical callable via `run_in_executor(get_shared_executor(), ...)` (`ws_push.py:779`); the HTTP path is the only unoffloaded caller. Fix: `await asyncio.to_thread(build_persona_payload, ...)`, the pattern already used at `frame/routes/analysis.py:63`. Found independently by the security and type-design subagents.

`B4 — the one genuinely new behavior in this story has zero test coverage.` [TEST] [TYPE]
I deleted all ten lines of the `if full:` block (`ws_push.py:530-539`) in a scratch copy and ran the two frame-route files: 85 passed, 0 failed. AC3 is a subset check only (`PERSONA_CONTRACT_KEYS - set(data) == set()`); nothing asserts `roleTitle`, `quirk`, `motto`, `helperName`, or `helperStyle`. There is no `FULL_CONTRACT_KEYS`. Dev's own logged Deviation 1 flags this shape as invented — an invented contract with no test pinning it is one refactor away from silently vanishing. On a story whose entire subject is assertions that admit the broken path, shipping the new behavior unpinned is the same defect class. Fix: assert the full key set and its values.

### Follow-up findings (non-blocking)

- `New vacuity in the neighbours.` [RULE] [TEST] Rewiring the module-wide `client` fixture to a hermetic tmp project de-vacuumed 4 persona tests and hollowed several others. Probed under the fixture: `/api/git` returns `404 {"error":"Not a git repository"}`, so `test_git_info_shape`'s `if response.status_code == 200:` body never executes; `/api/theme-agents` and `/api/story` now return fixture data, so `test_get_theme_agents_returns_json` asserts only `isinstance(data, dict)`. Five surviving disjunctive assertions at `test_frame_routes.py:136, 152, 160, 295` and the `in (200, 500)` cluster from `:585` onward. Same pattern, opposite direction — worth its own de-vacuuming pass.
- `Second cwd channel — Dev's conclusion stands but the diagnosis is wrong.` The 9 failures are real and pre-existing (`test_guided_tour.py` 3, `test_workflow_list_team.py` 5, `test_dead_scripts.py::test_pf_workflow_type` 1), none import the changed modules, and out-of-scope is the right call. But Dev attributed them to discovery "finding no `.pennyfarthing/` above `pennyfarthing-dist/`". The opposite is true: there is a stray gitignored `pennyfarthing/.pennyfarthing/` (dated Aug 6, containing only `.cache/` and `config.local.yaml`, no `workflows` symlink), and `get_project_root()` stops at it instead of walking up to the orchestrator root — `Error: Workflows directory not found at .../pennyfarthing/.pennyfarthing/workflows`. Two consequences: the failures are a local environment artifact and will not reproduce in CI, so a two-cwd CI diff would not have caught them; and the actual code defect is that discovery accepts an incomplete `.pennyfarthing/` without validating it. Also note the suite now fails from `pennyfarthing/` as well as from `pennyfarthing-dist/` (9 failed, 6129 passed, exit 1 from both) — only the orchestrator root is green. The follow-up story should be scoped to the validation defect, not to cwd-invariance.
- `New ruff-format drift in the test files.` `ruff format --check` fails on `test_162_49_persona_route.py` (5 hunks) and `test_frame_routes.py` (1 hunk, line 733). Unlike `ws_push.py`'s pre-existing drift, this is new: `test_frame_routes.py` is format-clean at `develop` and dirty at `HEAD`, and the other file is entirely new code. All are unnecessary line-wraps under the 100-column config. Trivial to fix, but it means "keep the files you touch clean" was met on the source files and missed on the test files, and no deviation was logged for it.
- `The fixture is not hermetic against the variable that matters.` `pf_project_dir` clears `PROJECT_ROOT`, `CLAUDE_PROJECT_DIR`, `PF_THEME`, `SESSION_ID` — but not `FRAME_PROJECT_DIR`, which wins over `PF_PROJECT_DIR` in `ws_push.py:44`. The docstring claims it clears "every other ambient variable that could redirect project-root resolution". Verified harmless today only because `data_proxy` ignores that variable — i.e. the suite's green depends on the very divergence B1 describes. It becomes load-bearing the moment B1 is fixed, and the AC8 sentinel does not guard it.
- `Session identity was dropped.` The fix deletes the `SESSION_ID` read; `launcher.py:132-135` forwards it with the comment "Forward session ID so Frame resolves the correct agent persona", so that intent is now unimplemented. Relatedly, `ws_push.py:483` claims "same logic as `statusline._resolve_agent`" — it is not: `statusline.py:241-269` keys off `session_id` first and applies a 1-hour staleness window, while `build_persona_payload` uses max-mtime with neither. Two sessions in one project will see each other's persona. Pre-existing on the WebSocket channel, so not a regression, but the extraction was the moment to make identity an explicit parameter.
- `portraitPath discloses the absolute home path.` [SEC] The payload stringifies a path rooted at `Path.home()`, leaking the OS username and confirming the install. Frame binds 127.0.0.1 but has no auth and sets `allow_origins=["*"]` with `allow_credentials=True` (`frame/app.py:151-152`), so any page in the developer's browser can read it. Pre-existing on the WebSocket channel (which has no origin check either), newly reachable by plain `fetch` — this story widens the door rather than opening it. Return a basename or an opaque handle; nothing serves files by that path.
- `{} conflates absent with broken.` `build_persona_payload` returns `{}` for four distinct causes including the outer `except Exception`, and the route maps falsy to `404 "No active persona"`. A corrupt theme YAML or a permission error is reported to the client as "nothing is active." Relatedly, `ws_push.py:517` and `:547` interpolate raw `str(exc)` into warnings, bypassing `data_proxy._safe_exc()`, which exists (story 160-18) precisely because raw exception text "can carry file-content fragments, absolute paths (with usernames), or tokens" — and this code is now on the HTTP path that policy was drawn around. Not a live leak (warnings go to `.session/frame.log`), but the discipline should follow the code.
- `Bidirectional lazy-import cycle.` `data_proxy` now function-imports `ws_push` while `ws_push` function-imports `data_proxy` at four sites (`:99, :130, :420, :456`). No import-time cycle today because both directions are function-local and uncommented — which is what makes it latent. A neutral `frame/persona.py` is the right home.
- `Type surface nits.` `project_dir: str | Path` has no `Path` caller and is re-normalized three times in the body; `PF_PROJECT_DIR=""` is a set-but-empty value that silently degrades to a relative path. `full` should be keyword-only. `active_agent` and `run_from_cwd` lack return annotations despite being cross-module fixtures. A `PersonaPayload` TypedDict pair would express the base/superset relation the tests describe in prose (`TypedDict` is already used at `session/test_cache.py:61`, `quality/ratchet.py:16`).
- `No auth or origin check on Frame at all.` Systemic, predates this story, deserves its own story.
- `Still no confirmed live consumer for this route` (TEA's finding, unresolved).

### Rule Compliance

| Rule | Verdict | Evidence |
|------|---------|----------|
| 1 Never edit `.pennyfarthing/` symlinked dirs | PASS | 5 changed files, all under `pennyfarthing-dist/src/pf/` |
| 2 Never edit sprint YAML directly | N/A | no sprint YAML in diff |
| 3 Never edit `node_modules/` | PASS | not present in diff |
| 4 Modify `pennyfarthing-dist/` only | PASS | all edits at the dist source |
| 5 `.js` extensions in relative TS imports | N/A | Python-only diff |
| 6 Return result objects, don't throw | CONCERN | `build_persona_payload` returns a bare dict with `{}` as a four-way sentinel; house-consistent with the `fetch_*` family, so not a violation, but it is what produces B2 and the absent-vs-broken conflation |
| 7 Match model to task | N/A | no tier config changed |
| 8 Runtime uses `.pennyfarthing/` paths | PASS | no `pennyfarthing-dist` literal in either source file; test-file hits are docstrings plus one test-only layout derivation |
| 9 Dogfood symlinks | PASS | no command/skill paths touched |
| 10 Concise answers | N/A | process rule |
| Python: silent exception swallowing | FAIL | B2 — a warn-and-degrade became a silent escape into `except Exception: pass` |
| Python: async/await pitfalls | FAIL | B3 — blocking network and file I/O on the event loop in two `async def` handlers |
| Python: test quality | FAIL | B4 plus the new vacuity in neighbouring tests |
| Python: type annotations at boundaries | FAIL | two public fixtures lack return annotations |
| Python: import hygiene | CONCERN | bidirectional function-local cycle, no `__all__` on newly public API |
| Python: path handling | PASS | `pathlib` throughout, `encoding="utf-8"` on every new write |
| Python: mutable defaults / resource leaks / unsafe deserialization | PASS | none introduced; YAML reads go through pre-existing `safe_load` |
| Python: security input validation | PASS | traced hostile `.session/agents/` content — reaches only dict-key lookups, never path interpolation; no traversal |
| `ruff check` on all 5 changed files | PASS | all checks passed |
| `ruff format --check` on changed files | FAIL | new drift in both test files; `ws_push.py`'s drift is pre-existing and non-overlapping (accepted) |

### Deviation Audit

`Deviation 1 — /api/persona/full's superset keys chosen by Dev.` Rationale accepted, execution rejected. The reasoning is sound: the unexposed `Persona` fields are the only non-arbitrary superset, and a byte-identical payload would make the endpoint provably redundant. But the shape ships with no test asserting it (B4), and coerces `None` to `""` while `Persona.to_dict()` omits falsy optionals — a third serialization of the same dataclass. Keep the keys; pin them; write the contract down.

`Deviation 2 — payload builder placed in ws_push.py rather than a neutral module.` Accepted for this story. Extraction in place is the minimal change that removes the duplicate implementation, and moving it would touch `fetch_persona`'s callers for no behavioral gain. Noted that it closes a bidirectional function-local import cycle; the neutral-module relocation is a follow-up, not a blocker. The reasoning offered alongside it — that delegating to `build_persona_payload` rather than `fetch_persona` "keeps that divergence out of the HTTP path" — is inverted: it preserves the divergence and leaves the route unable to see the only variable production sets. That is B1.

`Deviation 3 — ws_push.py left with pre-existing ruff-format drift.` Accepted, verified independently. `ruff format --check` flags the file at `develop` too, and comparing the formatted output against `HEAD` puts every changed hunk outside Dev's added lines (drift clusters at roughly lines 37-383 and 623-775; the new code sits at 460-560). Not reformatting was the right call.

### Subagent Detail (cycle 1)

| # | Subagent | Status | Findings | Confirmed by me |
|---|----------|--------|----------|-----------------|
| 1 | `preflight` | Returned late | 9 smells + measured counts | 85/85 both cwds and the 9-failure node IDs match my own runs; its two corrections to my draft both verified first-hand — the stray `pennyfarthing/.pennyfarthing/` (confirmed present, gitignored, no `workflows`) and new format drift in the test files (confirmed `test_frame_routes.py` clean at `develop`, dirty at `HEAD`) |
| 2 | `edge_hunter` | Skipped | disabled via settings | N/A |
| 3 | `silent_failure_hunter` | Skipped | disabled via settings | N/A |
| 4 | `test_analyzer` | Returned after phase close | 12 findings, 6-mutation table | see Addendum; its mutation C independently reproduces my `full`-block result (B4), and its git-vacuity finding matches my `/api/git` probe; the vacuous-`character` test verified by reading `:153-163` |
| 5 | `comment_analyzer` | Skipped | disabled via settings | N/A |
| 6 | `type_design` | Returned | 11 findings | B1, B2, B3, B4 all confirmed by direct measurement; stale-statusline-comment and session-identity claims confirmed by reading `statusline.py:241-269` |
| 7 | `security` | Returned | 1 blocking, 5 non-blocking, 1 nit | B3 confirmed by timing measurement; `portraitPath` leak and CORS posture confirmed by reading `frame/app.py:151-152`; its no-traversal finding independently re-traced and agreed |
| 8 | `simplifier` | Skipped | disabled via settings | N/A |
| 9 | `rule_checker` | Returned | 9 FAIL rows | B1 confirmed with matching evidence; the new-vacuity finding confirmed by probing `/api/git` under the fixture |

One enabled subagent (`test_analyzer`) never reported; `preflight` returned after this assessment was first drafted and its two corrections are folded in above. The missing test-analyzer coverage was replaced with my own mutation probes rather than assumed — noted here so the gap is visible rather than papered over.

`Fixture accuracy nits` (from preflight, verified): `pf_project_dir`'s docstring says it creates `.session/agents/dev` marking `dev` active, but the code writes `.session/agents/current` containing `"dev"`. Production markers are `.session/agents/<session-uuid>` with the agent name as content, so the fixture does not resemble real data. Because `active_agent` wipes all markers before writing one, the multi-marker most-recent-mtime precedence path — the actual production shape, and the one that diverges from `statusline._resolve_agent` — is never exercised. Its `iterdir()`/`unlink()` loop also raises on any subdirectory.

### Addendum — `test_analyzer` results (returned after phase completion)

The `test_analyzer` subagent reported after this assessment was filed. It does not change the verdict; it reinforces B4 and adds three items Dev should fold into the rework.

`Positive evidence — the tests do bite.` Its mutation table (mutations applied to byte-for-byte backups, restored and SHA-256-verified, tree confirmed clean) independently establishes what my own probes only sampled: reintroducing the broken `load_persona(project_dir, session_id=...)` call fails 14 tests; swapping `_get_project_dir()` for `os.getcwd()` fails 10; hardcoding `agent_name = "dev"` fails 2; dropping `project_root=project_dir` from the `load_persona` call fails 4. The RED suite is genuine, not decorative.

`Independent confirmation of B4.` Its mutation C — making `/api/persona/full` call `_persona_response(full=False)` — passes 85/85, matching my own result from deleting the `if full:` block. Two independent mutations, same conclusion: the `/full` behavior is entirely unpinned.

`New — which tests catch a cwd regression is itself cwd-dependent.` This is the sharpest finding of the review and belongs in the story's own subject matter. Running the identical `os.getcwd()` mutation from two cwds produces two different failing sets: from the orchestrator root, `test_persona_returns_200_not_type_error` and `test_persona_payload_matches_tui_contract` still PASS (the real repo has a live `dev` persona to find), and the three AC5/404 tests fail instead; from `pennyfarthing/`, the reverse. Only the tests asserting fixture-specific values (`..._reflects_active_agent_and_theme`, `..._tracks_a_different_active_agent`, and the two `TestCwdIndependence` tests) pin provenance rather than merely shape. At least one test always catches, so the guard holds — but the AC5 tests would be materially stronger asserting an ambient-distinguishable value.

`New — one of the new tests is vacuous on any non-200 response.` `test_162_49_persona_route.py:153-163` reads `character = data.get("character", "")` with no status assertion. On any 404 the body is `{"error": ...}`, so `character` is `""`, and both `"/" not in ""` and `"" != "Unknown"` hold — the test passes on every error response. Verified by reading the source; the subagent also observed it passing under a mutation while its siblings failed. Redundant with `:138` so the coverage loss is small, but it is the same defect class the story exists to remove. Also `"Unknown"` is a sentinel nothing in this code path produces.

`New — the portrait branch is never exercised by the HTTP route tests.` `portraitPath` is `None` throughout the fixture (no portrait assets, and the test theme omits `shortName`/`ocean`), so `resolve_portrait_path` is never reached from these tests — only the older 160-16 `fetch_persona` tests cover it. That matters directly for B3: the branch responsible for the event-loop stall has no HTTP-level coverage. The security subagent flagged the same gap from the other side — the fixture avoids a network call only accidentally, so anyone adding `ocean:` to the test theme silently converts the suite into a network-dependent one with a 30s timeout. The fixture should stub `portrait_cdn.fetch_portrait` explicitly.

`Fixture leakage — clean, question closed.` Independently confirms my own reading: none of the three new fixtures is autouse, `monkeypatch` teardown restores env and cwd, the only other conftest in the tree is path-setup only, and of the other files touching `PF_PROJECT_DIR` (8) or chdir (7, plus one raw `os.chdir` with a `finally` restore) none collide. Two residual nits: `active_agent`'s `unlink()` loop raises on a subdirectory, and `prime/persona.py`'s module-level `_quote_cache` is keyed `(agent, theme)` while the fixture reuses one theme name, so a theme carrying a `catchphrases` list would make quote values order-dependent across tests.

`Also noted:` `test_signature_rejects_the_buggy_call` (`:256-269`) is near-tautological given the parameter-list assertion at `:251` — it exercises `inspect`, not `pf`. Harmless. And `test_non_pf_project_dir_returns_not_a_project` (`:223-234`) hand-rolls `monkeypatch.setenv` rather than using a fixture — justified, since it needs a non-PF dir, but it is the one place AC8's "one fixture, not a copy-pasted monkeypatch" is bent, and it leaves `PROJECT_ROOT`/`CLAUDE_PROJECT_DIR` set. Harmless only because `data_proxy._get_project_dir()` reads neither — it rots the moment B1 is fixed.

### Cycle 2 Re-Review

`Commits:` `faa304554` (B1-B4) and `1b38404eb` (addendum close-out), both GPG-signed (`G`). Framework tree clean. Method: re-ran the exact probes that established each cycle-1 finding, then mutation-verified that each fix is pinned by a test that dies when the fix is reverted. Dev's claims were treated as hypotheses, not evidence.

`Blocking findings — all four resolved.`

| # | Finding | Probe result | Pinned by |
|---|---------|--------------|-----------|
| B1 | route cwd-dependent in production | production-shaped env (`FRAME_PROJECT_DIR` set, cwd elsewhere) now returns 200 from both routes, payload byte-matches `fetch_persona()` | reverting the resolver kills 3 tests in `TestProductionProjectDirResolution` |
| B2 | fail-loud regression on the WS channel | deleted-cwd probe returns `{}` plus `Failed to load persona: [Errno 2] No such file or directory` — develop's exact message | hoisting resolution back out of the `try` kills `test_unlinked_cwd_warns_and_returns_empty` |
| B3 | blocking network I/O on the event loop | concurrent `/ping` now completes at +0.12s against a 4.04s persona request; cycle 1 measured +4.14s | reverting `asyncio.to_thread` kills 2 tests, one builder-level and one at the real `urlopen` site |
| B4 | `full` branch untested | both cycle-1 mutations now die — deleting the `if full:` block: 3 failed; swapping `/full` to `full=False`: 3 failed | `FULL_ONLY_KEYS` + `TestFullContractIsPinned` |

`Counts verified independently:` frame-route files 97 passed / 0 failed from both the `pennyfarthing/` and `pennyfarthing-dist/` cwds; whole suite 6150 passed / 4 skipped / 0 failed, exit 0, from the orchestrator root. `ruff check` clean on all five changed files; `ruff format --check` now clean on both test files, closing the drift I flagged in cycle 1. `ws_push.py`'s pre-existing drift is unchanged, per accepted Deviation 3.

`Addendum items — dispositions accepted.` The vacuous `character` test now asserts `status_code == 200` and indexes rather than `.get`s, with the reasoning recorded in the docstring. `portrait_cdn.fetch_portrait` is stubbed in the fixture, so hermeticity is a property of the fixture rather than an accident of the theme YAML omitting `ocean` — this was the sharper half of that finding and it was understood correctly. The `/api/git` hollowing and the two fixture nits are deferred with reasoning, which is a legitimate answer. Dev also closed a hole my addendum only predicted: `test_non_pf_project_dir_returns_not_a_project` now clears the ambient set, which matters because post-B1 an ambient `FRAME_PROJECT_DIR` would have flipped its expected 404 to a 200.

`Two self-corrections in the Rework section are honest and correctly scoped.` The portrait-degradation warning being unreachable is real — `portrait_resolver.py:85-90` wraps `fetch_portrait` in `except Exception: return None`, so a CDN failure never reaches `build_persona_payload`'s inner portrait `try`. Logging it as a Delivery Finding rather than fixing it here is right; it is a 160-16 contract question in a different module. One narrowing: the warning is unreachable *via CDN failure*, not unreachable outright — `discover_all_theme_dirs` raising would still surface it. The serial-execution caveat for two-cwd suites (concurrent runs race the wheel-build dir in `test_pypi_packaging`) is a genuinely useful finding for any future two-cwd CI step and belongs on follow-up 2.

`One claim did not survive verification (non-blocking).` Dev states the `os.getcwd()` mutation is "now caught by the same 20 tests from all three cwds." Measured across four cwds: 20 failing from the orchestrator root and from `pennyfarthing/`, but 23 from `pennyfarthing-dist/` and from `/tmp`. Normalizing node IDs and diffing the sets, two tests still catch the mutation from the orchestrator root while passing it from the other two — `test_non_pf_project_dir_returns_not_a_project` and `test_frame_routes.py::TestBackwardCompatibility::test_error_responses_have_error_field`. Both expect a 404, and under a mutation that reads `os.getcwd()` directly no amount of env clearing can help them: from a cwd that happens to lack `.pennyfarthing/` the route 404s for the wrong reason and the assertion is satisfied accidentally. Only a `run_from_cwd` into a known non-PF directory would make them cwd-robust.

This is not blocking, and it is a real improvement on cycle 1. The cycle-1 defect was that the *core* "reaches 200" tests flipped, so the mutation could slip past the tests that matter. Now 20 tests catch it from every cwd tested and the failing set is never empty or near-empty; the residual is two peripheral 404 tests whose individual sensitivity does not weaken the guard. Recorded as a follow-up rather than a rejection, but the claim as written overstates what the tests do and should not be carried into the PR description.

`Also non-blocking, unchanged from cycle 1 and now purely a latency matter:` a cache-missing persona request still issues four serial `urlopen(timeout=30)` attempts and does not cache the negative result, so it can still cost ~120s of wall clock — now off the event loop, which is what B3 was about, but against a bounded thread pool. Sustained requests against an unreachable CDN could still saturate that pool. That is a `portrait_cdn` concern rather than a persona-route one; folding it into follow-up 6.

`Rule compliance re-check:` the three python.md rows that failed in cycle 1 now pass — silent exception swallowing (B2 fixed), async/await pitfalls (B3 fixed), and test quality (B4 fixed, plus the vacuous assertion repaired). Type annotations on the two public fixtures and the `str | Path` union remain as noted; both were non-blocking and deferred. Nothing under `.pennyfarthing/`, `node_modules/`, or outside `pennyfarthing-dist/` was touched in either commit.

### Recommended follow-up stories

1. Unify project-dir resolution across the five duplicated `_get_project_dir()` copies (`data_proxy`, `analysis`, `repos`, `state`, `ws_push`) into one resolver honoring `FRAME_PROJECT_DIR` → `PF_PROJECT_DIR` → cwd. Closes B1's root cause for all 7 data-proxy routes.
2. Make `get_project_root()` validate a candidate `.pennyfarthing/` (require `workflows`) instead of stopping at the first one it sees — the stray gitignored `pennyfarthing/.pennyfarthing/` currently breaks 9 workflow tests from two of three cwds. Separately, add a two-cwd CI run diffing the counts (TEA's and Dev's shared finding); note it would not have caught these 9, since the trigger is a local untracked directory.
3. De-vacuum the remaining `test_frame_routes.py` assertions — the five surviving `in (200, 4xx|5xx)` disjunctions and the `if status == 200:` guards.
4. Write down the `/api/persona/full` contract, or delete the endpoint; it still has no confirmed consumer.
5. Make persona resolution session-aware via the canonical `statusline._resolve_agent`, and fix the stale "same logic as statusline" comment.
6. Frame has no auth and `allow_origins=["*"]`; stop returning absolute filesystem paths in payloads.
7. Relocate the persona payload builder to a neutral `frame/persona.py` and break the `data_proxy` ↔ `ws_push` cycle.
8. (cycle 2) Make the two remaining 404-expecting tests cwd-robust via `run_from_cwd` into a known non-PF directory, so no test can satisfy an expected 404 accidentally from the invocation cwd.
9. (cycle 2) `portrait_cdn.fetch_portrait` does not cache negative results, so a cache miss costs four serial 30s attempts on every request against a bounded thread pool. Add negative caching or a circuit breaker.
10. (cycle 2) `portrait_resolver.py:85-90` swallows every CDN exception, making `build_persona_payload`'s portrait fail-loud warning unreachable via that path — a 160-16 contract gap in a different module (Dev's Delivery Finding).

## Dev Assessment — Rework Round 1

**Status:** GREEN (four blocking findings plus all addendum items fixed and pinned)
`Commit:` faa304554 for B1-B4, then 1b38404eb for the addendum (both GPG-signed, `G`, pushed). First pass was 71e30cc08.

All four blockers accepted as stated — each was reproducible and each diagnosis held up. Every fix was then mutation-verified: revert the fix, confirm the new test fails, restore. No test was weakened.

### B1 — production cwd-dependence (AC4)

`data_proxy._get_project_dir()` now reads `FRAME_PROJECT_DIR` → `PF_PROJECT_DIR` → cwd, matching `ws_push`. Confirmed the premise first-hand: `launcher.py:128` exports `FRAME_PROJECT_DIR`, and `grep` across `src/pf` finds no writer of `PF_PROJECT_DIR` outside tests. Replaced the docstring that claimed "never `os.getcwd()`" with an accurate one naming the launcher.

The Reviewer's related point that the suite's green *depended* on the divergence was the sharpest part of the finding, so `pf_project_dir` now clears `FRAME_PROJECT_DIR` as well (it outranks `PF_PROJECT_DIR` in both resolvers), and the AC8 sentinel asserts it — otherwise an ambient value from a running Frame server could redirect resolution straight past the fixture.

Three tests pin it: `FRAME_PROJECT_DIR` alone resolves with the cwd elsewhere; `FRAME_PROJECT_DIR` outranks a decoy `PF_PROJECT_DIR`; and the HTTP payload equals `fetch_persona()`'s under production-shaped env, so the two resolvers cannot drift apart again. Probe: revert the one-line resolver → 3 failures.

### B2 — fail-loud regression on the WebSocket channel

Resolution is back inside a `try`. `fetch_persona()` now catches `OSError` around `_get_project_dir()`, warns with develop's exact message, and returns `{}`; `build_persona_payload` keeps taking an explicit dir, so the HTTP path is unaffected. My first-pass claim that "the WebSocket channel's behavior is unchanged" was measurably false — the Reviewer was right to call it out rather than accept the assertion.

Pinned by a test that chdirs into a directory, unlinks it, and asserts `pytest.warns(UserWarning)` plus `{}`. Probe: hoist the call back out of the `try` → that test fails.

### B3 — blocking I/O on the event loop

Both handlers now `await asyncio.to_thread(build_persona_payload, project_dir, full=full)`, the pattern at `routes/analysis.py:63`; `_persona_response` became `async`.

The first version of this test compared thread idents against the test's own thread and passed even with the fix reverted — TestClient already runs the app in a separate thread, so it proved nothing. Caught it with the mutation probe and rewrote it to call `asyncio.get_running_loop()` inside the builder: a running loop is only visible from the loop's own thread, so reaching it means the blocking work is on the loop. Probe against the corrected test: revert to the inline call → fails. Worth flagging as a near-miss of exactly this story's defect class.

### B4 — the `full=True` key set had zero coverage

Added `FULL_ONLY_KEYS` plus four tests: every full-only key present; every value matches the theme; the base payload does *not* carry them (so `full=True` cannot decay into a no-op while still satisfying "superset"); and a sparse-theme case using `tea`, which declares no quirk and no helper, pinning the `None` → `""` coercion the Reviewer noted as a third serialization of `Persona`. Probe: delete all ten lines of the `if full:` block → 3 failures (was 85/85 green).

### Test results

| scope | orchestrator root | `pennyfarthing-dist/` |
|-------|-------------------|------------------------|
| `test_162_49_persona_route.py` + `test_frame_routes.py` | 97 passed / 0 failed | 97 passed / 0 failed |
| whole `src/pf/tests/` | 6150 passed / 4 skipped / **0 failed** | 6141 passed / 4 skipped / 9 failed |

97 in the frame-route files, up from 85 — twelve new regression pins (9 for B1-B4, 3 for the portrait branch). Whole suite from the orchestrator root is green, exit 0. Neither the `FRAME_PROJECT_DIR` clear nor the `fetch_portrait` stub broke anything.

`One correction on my own measurement method.` My first attempt at these numbers ran the two cwds CONCURRENTLY and reported a packaging ERROR (`test_pypi_packaging`) — a different test each run. That was my own artifact: two suites racing on the same wheel-build directory. Re-run serially, `test_pypi_packaging` is 54/54 and both suites are clean. Every count in this section is from a serial run. Worth stating plainly given that this story is about not trusting suite numbers.

The 9 failures from other cwds are the same pre-existing set, untouched. I have corrected my own Delivery Finding: the Reviewer's re-diagnosis is right and I verified it — a stray gitignored `pennyfarthing/.pennyfarthing/` (`.cache/` + `config.local.yaml`, no `workflows`) stops `get_project_root()` early. It is a local environment artifact that will not reproduce in CI, and the real defect is discovery accepting an incomplete `.pennyfarthing/`.

### Lint

`ruff check` and `ruff format --check` both clean on all five changed files except `ws_push.py`, whose remaining drift is the pre-existing, non-overlapping set the Reviewer independently verified and accepted (Deviation 3). Confirmed again that none of the rework's added lines appear in that drift. The new drift in both test files is fixed, and a deviation is logged for having missed it the first time.

### Not addressed (deliberately)

Per SM's instruction, scope was B1-B4 plus the format issue. Untouched: neighbour-test vacuity under the rewired fixture, the five-way resolver unification (I did verify `analysis.py:35`, `repos.py:24`, `state.py:27` still read only `PF_PROJECT_DIR`, so those routes remain blind to the production variable — logged as a Delivery Finding), `portraitPath`'s absolute-path disclosure, session-identity resolution, the `{}` four-way sentinel, the lazy-import cycle, type nits, and Frame's missing auth. All are Reviewer-filed follow-ups.

### Addendum items — FIXED / DEFERRED

`Commit:` 1b38404eb (GPG-signed, `G`), pushed. Supersedes faa304554 for these items; B1-B4 above are unchanged.

| # | Addendum item | Status |
|---|---------------|--------|
| 1 | B4's second mutation (`/full` delegating `full=False`) must also die | FIXED — verified, not assumed |
| 2 | Vacuous `character` assertion at `:153-163` | FIXED |
| 3 | Portrait branch has no HTTP coverage; fixture avoids the network only accidentally | FIXED — both halves |
| 4 | Shape-vs-provenance: which tests catch a cwd regression is itself cwd-dependent | FIXED (was offered as deferrable) |
| 5 | Hand-rolled monkeypatch at `:223-234` "rots the moment B1 is fixed" | FIXED (was offered as deferrable) |
| 6 | `test_signature_rejects_the_buggy_call` is near-tautological | DEFERRED — see below |
| — | `/api/git` 404 under the fixture hollows neighbouring tests | DEFERRED → Reviewer follow-up story 3 |
| — | `active_agent` unlink loop; `_quote_cache` theme reuse | DEFERRED → follow-up, per SM |

Every addendum item now has a disposition. Nothing is silently unchanged.

`1 — B4 double mutation.` Ran both probes against the current tests. Deleting the whole `if full:` block: 3 failed / 94 passed. Swapping `/api/persona/full` to `_persona_response(full=False)`: 3 failed / 94 passed. Both mutations die on `test_full_payload_carries_every_full_only_key`, `test_full_payload_values_come_from_the_theme`, and `test_absent_theme_fields_serialize_as_empty_strings`.

`2 — vacuous assertion.` `test_persona_does_not_leak_project_path_as_character` now asserts `status_code == 200` first and indexes `response.json()["character"]` instead of `.get("character", "")`. Kept rather than deleted: it is the only negative-shape guard against the original bug's argument-swap, and with the status assertion it is no longer vacuous. Left `"Unknown"` in place — the Reviewer is right that nothing in this path produces it today, but `load_persona` does default `character` to `"Unknown"` when a config override exists without theme data, so it is not dead.

`3 — portrait branch.` Two halves, both done. (a) `pf_project_dir` now stubs `pf.package.portrait_cdn.fetch_portrait` to return None, so hermeticity is a property of the fixture rather than of a theme-YAML omission — previously anyone adding `ocean:` to the test theme would have silently converted every test using the fixture into a network-dependent one with a 30s timeout. (b) Three new route-level tests give `dev` a resolvable `shortName`/`ocean` slug and exercise the branch over HTTP: the resolved path reaches `portraitPath`, the CDN call runs off the event-loop thread, and a broken CDN costs the portrait but not the persona.

The off-loop test matters more than the builder-level B3 test: that one stubs `build_persona_payload` itself, so it cannot see where the real blocking work runs. This one lets the whole payload path execute and checks the thread at the actual `urlopen` site.

One expectation of mine was wrong. I wrote the degradation test asserting `pytest.warns(UserWarning, "Failed to resolve portrait")` and it failed — `DID NOT WARN`. Cause: `resolve_portrait_path` wraps the CDN call in its own `except Exception: return None` (`tui/portrait_resolver.py:86-90`), so a broken CDN is swallowed one level below and `build_persona_payload`'s inner handler never sees it. Pinned the real behaviour rather than the behaviour I assumed, and logged the swallow as a Delivery Finding instead of widening scope into `portrait_resolver`.

`4 — provenance over shape.` Took this rather than deferring; it was two lines. Added `theme == "conftest-test-theme"` to `test_persona_returns_200_not_type_error` and `test_persona_payload_matches_tui_contract`. Measured the effect with the Reviewer's own `os.getcwd()` mutation, from three cwds:

| cwd | tests catching the mutation (before → after) |
|-----|----------------------------------------------|
| orchestrator root | 10 → 20 |
| `pennyfarthing/` | 10 → 20 |
| `pennyfarthing-dist/` | 10 → 23 |

The failing set is now the same 20 from every cwd (dist adds 3 more because the route also 404s on project detection there). The Reviewer's point stands in the abstract — a real ambient project satisfies shape assertions — but the guard no longer depends on which directory pytest ran from.

`5 — hand-rolled monkeypatch at :223-234.` FIXED rather than deferred, because the addendum was right that it rots on contact with B1. `test_non_pf_project_dir_returns_not_a_project` needs a NON-PF directory, which `pf_project_dir` cannot supply, so it sets `PF_PROJECT_DIR` by hand. The moment `FRAME_PROJECT_DIR` started outranking `PF_PROJECT_DIR`, an ambient `FRAME_PROJECT_DIR` — exported by any running Frame server, so present on most developer machines — would redirect resolution to a real project and turn the asserted 404 into a 200. It now clears the same five-variable ambient set the fixture clears, which also closes the `PROJECT_ROOT`/`CLAUDE_PROJECT_DIR` leak the addendum noted. It still hand-rolls its env; that part is inherent to needing a non-PF dir and stays as TEA's documented AC8 bend.

`6 — near-tautological signature test.` DEFERRED, no follow-up story filed. `test_signature_rejects_the_buggy_call` (`:256-269`) asserts that `inspect.Signature.bind` rejects `session_id=`/`full=`, which is a property of `inspect`, not of `pf` — the real assertion is the parameter-list check at `:251`. The Reviewer's own disposition is "harmless", and it is TEA's test expressing AC6's intent. Deleting it would be a cosmetic change to another agent's test with no coverage gain, and AC6 is independently pinned by `:251` and by the four production-callsite tests. Recorded as a deliberate no-op rather than an omission; if the Reviewer wants it gone in cycle 2, it is a one-line delete.

`Deferred — /api/git under the fixture.` Not addressed, deliberately, with reasoning rather than silence. Un-hollowing it needs one of two things: `git init` inside `pf_project_dir` (subprocess git in a fixture used by two modules, changing `/api/git`'s response for every test that touches it), or rewriting the five surviving disjunctive assertions in `test_frame_routes.py`. The second is exactly the Reviewer's follow-up story 3, and those assertions are TEA's. Neither is a one-or-two-line change, and neither is load-bearing for B1-B4. Scoped out per SM's instruction; recorded here so it is an explicit hand-off rather than an omission.

`Deferred — fixture nits.` `active_agent`'s `iterdir()`/`unlink()` loop raises on a subdirectory, and `prime/persona.py`'s module-level `_quote_cache` keyed `(agent, theme)` makes quote values order-dependent if a theme carries `catchphrases`. Both real; both flagged by SM as follow-up material.

### For Reviewer (round 2)

- `build_persona_payload` still takes a project dir and `fetch_persona` still resolves one — two entry points, one of which now has an `OSError` guard the other does not need. Worth confirming that split reads correctly rather than looking like an asymmetry.
- The B3 test asserts *where* the builder runs, not how long it takes. That is deliberate (a timing assertion would be flaky), but it means a future change that moves the blocking call somewhere else on the loop would not be caught.
- `full` is still positional-or-keyword rather than keyword-only; left as-is since the Reviewer filed it under type nits.

## Subagent Results

**Cycle: 1**

`Scope of this cycle tag, stated plainly:` the enabled subagents were NOT re-spawned for cycle 2. The table below is the cycle-1 roster. Cycle-2 verification was done by first-hand measurement instead — re-running the exact probes that established each of B1-B4, plus five self-restoring mutations confirming each fix is pinned by a test that dies when the fix is reverted. For verifying four specific, already-characterized findings that is stronger evidence than a fresh generalist sweep, but it is not the same thing as re-running the specialists, and this tag should not be read as claiming otherwise.

All received: Yes — all 5 enabled subagents returned (rows 1, 4, 6, 7, 9). Rows 2, 3, 5, 8 were never spawned because they are disabled via settings, so they have nothing to receive and do not block this gate.

All 5 enabled subagents returned and were adversarially re-verified first-hand before any finding was accepted. 4 of 9 were disabled via `workflow.reviewer_subagents`. Detail, including which of their claims I confirmed by measurement, is in the `Subagent Detail (cycle 1)` table inside the Reviewer Assessment.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | issues | measured counts + 9 smells; 2 corrections to my draft | Accepted after verifying both first-hand — the stray `pennyfarthing/.pennyfarthing/` and new test-file format drift |
| 2 | reviewer-edge-hunter | No | disabled | none | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | No | disabled | none | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | issues | 12 findings + 6-mutation table | Accepted; its mutation C independently reproduced my B4 result. Filed as the assessment Addendum |
| 5 | reviewer-comment-analyzer | No | disabled | none | Disabled via settings |
| 6 | reviewer-type-design | Yes | issues | 11 findings | Accepted for B1/B2/B3; confirmed each by direct measurement before promoting to blocking |
| 7 | reviewer-security | Yes | issues | 1 blocking, 5 non-blocking, 1 nit | B3 accepted after timing measurement; its no-path-traversal finding independently re-traced and agreed |
| 8 | reviewer-simplifier | No | disabled | none | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | issues | 9 FAIL rows | Accepted; B1 confirmed with matching evidence, new-vacuity finding confirmed by probing `/api/git` |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): `frame/ws_push.py::fetch_persona` is a complete, correct, already-shipped implementation of exactly what the persona HTTP route needs — agent resolution from `.session/agents/`, correct `load_persona` call, portrait resolution, and the payload shape the TUI consumes. The broken route is duplicated intent, not missing capability. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (should delegate rather than re-derive). *Found by TEA during test design.*
- **Gap** (non-blocking): the persona HTTP route has no live consumer — the TUI reads the `persona` WebSocket channel (`ws_push`), not `GET /api/persona`. That absence of a consumer is why a hard `TypeError` sat undetected. Worth confirming whether the IDE/VS Code sidebar uses the HTTP route, or whether the route should be deleted instead of fixed. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py`. *Found by TEA during test design.*
- **Gap** (non-blocking): `_get_project_dir()`'s `os.getcwd()` fallback is a general vacuity hazard, not persona-specific — all 7 data-proxy GET routes share it. `pf_project_dir` now covers the frame-route module, but nothing prevents a future test module from reintroducing cwd dependence. A repo-wide guard (autouse fixture or a CI run from two cwds with a diff on the counts) would close the class. Affects `pennyfarthing-dist/src/pf/tests/conftest.py` and CI config. *Found by TEA during test design.*
- **Question** (non-blocking): `GET /api/persona/full`'s contract is undefined — `load_persona` has no `full` concept, and the removed call invented a `full=True` kwarg. The RED tests only require `/full` to be a superset of the base keys. If `/full` is meant to add `quirk`/`motto`/`helper_name`/`helper_style`, that should be written down; if it is meant to be identical, the endpoint is redundant. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py`. *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): a second cwd-dependence channel survives this story. Run `python3 -m pytest src/pf/tests/` from `pennyfarthing-dist/` and 9 tests fail that pass from the orchestrator root — `test_guided_tour.py` (3), `test_workflow_list_team.py` (5), `test_dead_scripts.py::test_pf_workflow_type` (1). All are `pf workflow list`/`show` invocations exiting 1 because workflow discovery resolves the project root from the cwd and finds no `.pennyfarthing/` above `pennyfarthing-dist/`. Confirmed pre-existing: fails identically at TEA's RED commit and at `514f9a6ac~1`, before 162-29. Same failure class as this story's defect 2 — suite counts still depend on the invocation directory, so `reviewer-preflight` can still be fooled outside the frame-route module. Affects `pennyfarthing-dist/src/pf/tests/test_guided_tour.py`, `test_workflow_list_team.py`, `test_dead_scripts.py`, and workflow root resolution. Needs its own story. *Found by Dev while verifying GREEN from both cwds.*
- **Improvement** (non-blocking): TEA's third finding (a repo-wide cwd guard) now has concrete evidence behind it — the 9 failures above are what a two-cwd CI diff would have caught years ago. A CI step running the suite from two directories and diffing the counts would close the class rather than one module at a time. Affects CI config. *Found by Dev while verifying GREEN from both cwds.*
- **Correction to both findings above** (non-blocking): my diagnosis was wrong and the Reviewer's replacement is right — I confirmed it independently. There IS a `.pennyfarthing/` above `pennyfarthing-dist/`: a stray gitignored `pennyfarthing/.pennyfarthing/` (dated Aug 6, `.cache/` and `config.local.yaml` only, no `workflows` symlink; `git check-ignore` confirms `.gitignore:83`). `get_project_root()` stops at that incomplete directory instead of walking up to the orchestrator root, hence `Workflows directory not found`. Two consequences I got backwards: the failures are a local environment artifact that will NOT reproduce in CI, so the two-cwd CI diff I recommended would not have caught them; and the real defect is that discovery accepts an incomplete `.pennyfarthing/` without validating it. The follow-up story should be scoped to that validation defect. The two-cwd CI guard is still worth having on its own merits — just not as the fix for these 9. *Corrected by Dev during rework round 1.*
- **Gap** (non-blocking): `FRAME_PROJECT_DIR` vs `PF_PROJECT_DIR` is duplicated across five `_get_project_dir()` copies (`data_proxy`, `analysis`, `repos`, `state`, `ws_push`). B1's fix aligned one of them; the other three still read only `PF_PROJECT_DIR` and so are still blind to the variable production sets. I did not touch them — out of scope for B1-B4, and the Reviewer already filed the unification as follow-up story 1. Flagging that the divergence is still live for the routes I did not fix. Affects `pennyfarthing-dist/src/pf/frame/routes/analysis.py`, `repos.py`, `state.py`. *Found by Dev during rework round 1.*

- **Gap** (non-blocking): `resolve_portrait_path` swallows CDN failures silently. `tui/portrait_resolver.py:86-90` wraps the `portrait_cdn.fetch_portrait` call in `except Exception: return None`, so a broken or unreachable CDN is indistinguishable from "this agent has no portrait" — and `build_persona_payload`'s own "Failed to resolve portrait" warn can never fire for the most likely failure cause. Found by writing a test that asserted the warn and getting `DID NOT WARN`. Same silent-swallow class epic 160 swept out of `ws_push` and `data_proxy`, in a module that sweep did not reach. Affects `pennyfarthing-dist/src/pf/tui/portrait_resolver.py`. Out of scope here (the story's ACs say nothing about portraits); pairs naturally with the Reviewer's follow-up 6. *Found by Dev during rework round 1 addendum.*
- **Gap** (non-blocking): `test_pypi_packaging.py`'s wheel-build tests are not safe to run concurrently — two pytest processes over the same tree race on the build output and one reports a spurious ERROR (I hit it twice, on a different test each time, while timing two-cwd runs in parallel). Any future two-cwd CI job of the kind TEA and I both recommended will need these serialized or given separate build dirs, or it will produce exactly the untrustworthy numbers the job exists to prevent. Affects `pennyfarthing-dist/src/pf/tests/test_pypi_packaging.py` and CI config. *Found by Dev during rework round 1 addendum.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)

- **Fixture is opt-in, not autouse:** The SM brief asked for a conftest `PF_PROJECT_DIR` fixture. `pf_project_dir` lives in conftest but is requested explicitly, wired in once at `test_frame_routes.py`'s `client` fixture. Reason: an autouse fixture would retarget project-root resolution for all ~6100 tests, several hundred of which read the real repo. One wiring point per module satisfies the "not scattered per-test monkeypatches" requirement without that blast radius.
- **Contract is agent-based, not session-based:** SM's acceptance shape said "persona payload for a valid agent/session". There is no `session_id` concept anywhere in persona loading — the invented `session_id=` kwarg is the bug itself. The active agent comes from the `.session/agents/` marker (the resolution statusline and `ws_push.fetch_persona` already use). ACs pin agent resolution and drop `session_id` from the contract entirely.
- **AC6 forecloses one of the two fix shapes:** SM listed "change the call vs change the signature" as Dev's call. AC6 requires `load_persona`'s signature stay `(agent_name, project_root=None)`, so only the caller may change. Reason: 6 correct production callers and ~25 correct test callers depend on the current signature; widening the shared API to accommodate one broken caller would be the wrong direction. Dev retains latitude on *how* the route is fixed (delegate to `fetch_persona` vs. inline the correct call).
- **Modified pre-existing tests as well as adding new ones:** SM asked TEA to decide between modifying the 4 failing tests and adding new ones. Did both — the 4 pre-existing assertions were genuinely vacuous (`status_code in (200, 404)`, `if status == 404:` guards) and are the mechanism that hid the break, so leaving them intact would have preserved the defect the story is about.
### Dev (implementation)

- **`/api/persona/full`'s superset keys are chosen by Dev, not specified**
  - Spec source: TEA Assessment AC3; TEA Delivery Finding (Question) on the undefined `/full` contract
  - Spec text: "`GET /api/persona/full` returns 200 and a superset of the AC2 keys"
  - Implementation: base contract plus `roleTitle`, `quirk`, `motto`, `helperName`, `helperStyle` — the remaining optional `Persona` fields
  - Rationale: AC3 only constrains "superset". Returning a byte-identical payload would satisfy the tests but make the endpoint provably redundant, and inventing new derived fields would be worse. The unexposed `Persona` fields are the only non-arbitrary superset available.
  - Severity: minor
  - Forward impact: minor — if an IDE-sidebar consumer expects different `/full` keys, this is the shape it will get. The contract still needs writing down (TEA's open Question).

- **Payload builder placed in `ws_push.py` rather than a neutral module**
  - Spec source: TEA Delivery Finding (Improvement) — "should delegate rather than re-derive"
  - Spec text: "`frame/ws_push.py::fetch_persona` is a complete, correct, already-shipped implementation of exactly what the persona HTTP route needs"
  - Implementation: extracted `build_persona_payload(project_dir, full=False)` in place in `ws_push.py`; `data_proxy` imports it lazily inside the route helper
  - Rationale: a shared payload builder arguably belongs in a neutral module rather than the WebSocket-push module, but moving it would touch `fetch_persona`'s callers and tests for no behavioral gain. Extraction in place is the minimal change that removes the duplicate implementation.
  - Severity: minor
  - Forward impact: none functionally — an HTTP route now depends on a `ws_push` symbol, which reads slightly off-altitude. A future refactor could relocate it to `frame/persona.py` with no behavior change.

- **`ws_push.py` left with pre-existing ruff-format drift**
  - Spec source: Dev brief — "keep the files YOU touch clean"
  - Spec text: "Repo-wide ruff failures are pre-existing — keep the files YOU touch clean"
  - Implementation: `ruff check` is clean on both touched files; `ruff format --check` still flags `ws_push.py` on hunks that predate this story and do not overlap my lines. Not reformatted.
  - Rationale: `ruff format` on the whole file produces ~200 lines of unrelated churn (`ThreadPoolExecutor` call, `fetch_git` dict literal, `subprocess.run` args, `POLL_CHANNELS`), burying a 40-line fix and making review harder. My added lines are format-clean.
  - Severity: minor
  - Forward impact: none — `ws_push.py` remains as unformatted as it was on develop.
### Dev (implementation) — rework round 1

- **Missed new ruff-format drift in the test files on the first pass**
  - Spec source: Dev brief — "keep the files YOU touch clean"
  - Spec text: "Repo-wide ruff failures are pre-existing — keep the files YOU touch clean"
  - Implementation: `ruff format` applied to `test_162_49_persona_route.py` and `test_frame_routes.py`. Both now pass `--check`.
  - Rationale: I checked only the two source files I edited and never ran `--check` on the test files, so I logged a deviation defending `ws_push.py`'s pre-existing drift while shipping *new* drift next to it — `test_frame_routes.py` was format-clean at `develop` and dirty at `71e30cc08`. No deviation covered that, which is the actual process miss. `ws_push.py` remains unformatted per the Reviewer-accepted Deviation 3.
  - Severity: minor
  - Forward impact: none — both test files are now format-clean.

- **Cleared `FRAME_PROJECT_DIR` in TEA's `pf_project_dir` fixture**
  - Spec source: TEA Assessment AC8; TEA Deviation "Fixture is opt-in, not autouse"
  - Spec text: "`pf_project_dir` (hermetic PF project under tmp_path, exports `PF_PROJECT_DIR`, clears `PROJECT_ROOT`/`CLAUDE_PROJECT_DIR`/`PF_THEME`/`SESSION_ID`)"
  - Implementation: added `FRAME_PROJECT_DIR` to the cleared set and to the AC8 sentinel's assertion loop.
  - Rationale: editing another agent's fixture needs justification. B1's fix makes `FRAME_PROJECT_DIR` outrank `PF_PROJECT_DIR` in `data_proxy` as it already did in `ws_push`, so an ambient value — trivially present, any developer with Frame running has it exported — would redirect resolution past the fixture and silently re-open the vacuity channel this story exists to close. The fixture docstring already claimed to clear "every other ambient variable that could redirect project-root resolution"; this makes the claim true rather than changing the intent.
  - Severity: minor
  - Forward impact: none expected — verified the whole suite still passes from the orchestrator root (6147 passed / 0 failed) after the change.

- **Added regression tests for B1, B2 and B3, not only for B4**
  - Spec source: SM rework brief
  - Spec text: "four specific blockers, each measured first-hand, each 1-2 lines plus one test addition"
  - Implementation: nine new tests — 4 for B4's `/full` contract, 3 for B1's resolver precedence and cross-transport agreement, 1 for B2's warn-and-degrade, 1 for B3's off-loop execution.
  - Rationale: the brief scoped one test addition (B4). B1, B2 and B3 were each a one-or-two-line source change that nothing in the suite would have caught if reverted — the exact condition that produced B4. On a story whose subject is assertions that admit the broken path, shipping three unpinned fixes would repeat the defect. Confirmed each pin by mutation probe rather than assuming it.
  - Severity: minor
  - Forward impact: none — additive tests only, no production behavior implied beyond the four fixes.
### Dev (implementation) — rework round 1 addendum

- **Stubbed `portrait_cdn.fetch_portrait` inside TEA's `pf_project_dir` fixture**
  - Spec source: TEA Assessment AC8; Reviewer addendum, portrait-branch item
  - Spec text: "`pf_project_dir` (hermetic PF project under tmp_path, exports `PF_PROJECT_DIR`, clears `PROJECT_ROOT`/`CLAUDE_PROJECT_DIR`/`PF_THEME`/`SESSION_ID`)"
  - Implementation: added `monkeypatch.setattr("pf.package.portrait_cdn.fetch_portrait", lambda *a, **kw: None)` to the fixture.
  - Rationale: second edit to another agent's fixture, so justifying it explicitly. The fixture was network-free only because the test theme omits `shortName`/`ocean` and the portrait slug never resolved — an omission, not a guard. Adding an `ocean:` key for any unrelated reason would have converted every test using this fixture into a network-dependent one with a 30s timeout per size bucket. Returning None preserves the existing `portraitPath: None` behaviour exactly, so no existing assertion changes.
  - Severity: minor
  - Forward impact: tests wanting the portrait branch must override the stub, which the three new portrait tests do. Verified the whole suite from the orchestrator root is unchanged at 0 failures.

- **Strengthened two of TEA's shape assertions into provenance assertions**
  - Spec source: TEA Assessment AC1/AC2; Reviewer addendum, shape-vs-provenance item (offered as deferrable)
  - Spec text: AC1 "returns HTTP 200 and does not raise"; AC2 "payload matches the persona contract ... `character`/`role`/`theme` reflecting the active agent and configured theme"
  - Implementation: added `theme == "conftest-test-theme"` to `test_persona_returns_200_not_type_error` and `test_persona_payload_matches_tui_contract`.
  - Rationale: editing tests I did not write, so logging it. Both were status/key-set only, which a real ambient PF project with a live persona also satisfies — so under an `os.getcwd()` regression they passed from some cwds and failed from others. AC2 already demands the theme reflect configuration, so this makes the test match its stated AC rather than adding a new requirement. Measured: mutation coverage went 10 → 20 tests, and the failing set is now cwd-stable.
  - Severity: minor
  - Forward impact: none — strictly tighter assertions on the same ACs.

- **Pinned the portrait-failure path's actual behaviour rather than its documented intent**
  - Spec source: `ws_push.build_persona_payload`'s inner-try comment (AC-3, story 160-16)
  - Spec text: "warn IN PLACE then degrade — keep portrait_path=None and fall through to return the full persona"
  - Implementation: `test_portrait_failure_degrades_without_losing_the_persona` asserts the 200 and `portraitPath is None`, but NOT the warning, because no warning is emitted.
  - Rationale: I wrote the test expecting the warn and it failed with `DID NOT WARN`. `resolve_portrait_path` swallows the exception itself (`portrait_resolver.py:86-90`), so the outer handler is unreachable for CDN failures. Asserting the warn would have meant either a failing test or "fixing" `portrait_resolver`, which is outside this story's ACs. Pinned what the code does and logged the swallow as a Delivery Finding.
  - Severity: minor
  - Forward impact: the degrade path is now covered; the missing diagnostic remains an upstream gap for the follow-up that touches portraits.