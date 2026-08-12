---
story_id: "162-37"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-37: Test-gate hygiene: leakage gate SKIP_DIRS lists .venv but not venv (a stray venv/ trips it on pip RECORD byte counts — hit twice on 2026-08-05); test_frame_routes has an order-dependent flake (4 tests fail in full runs, pass in isolation) that survived the 162-5 triage (from 162-7)

## Story Details
- **ID:** 162-37
- **Jira Key:** (none — Jira not enabled for this project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-37-test-gate-hygiene-skipdirs-frameroutes-flake
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the title is the full spec (from 162-7). TWO independent test-infra deliverables in the framework:

1. **Leakage-gate SKIP_DIRS:** the test-leakage gate's `SKIP_DIRS` lists `.venv` but not `venv`, so a stray `venv/` dir trips the gate on pip RECORD byte counts (hit twice on 2026-08-05). Add `venv` (and consider other common virtualenv dir names) to `SKIP_DIRS`. Grep `SKIP_DIRS` under `pennyfarthing-dist/src/pf/` to find it.
2. **`test_frame_routes` order-dependent flake:** 4 tests in `pennyfarthing-dist/src/pf/tests/test_frame_routes.py` FAIL in full runs but PASS in isolation — classic shared-state leak (module-level global, a singleton/app instance, an unreset FastAPI dependency override, or env). Diagnose the shared state and make the 4 tests order-INDEPENDENT (proper fixture setup/teardown or isolation), so they pass regardless of run order. This flake survived the 162-5 triage.

**TEA (RED):**
- SKIP_DIRS: a test that a `venv/` path is skipped by the leakage gate (today it's not → gate trips). Pin the fix.
- Flake: FIRST reproduce the order dependence deterministically (identify the polluting test / shared state — e.g. run the 4 in the failing order and show they fail, in isolation they pass). Write a test that pins the isolation invariant (the 4 pass regardless of order), or a fixture-level assertion that the shared state is reset. The RED artifact is the reproduction; GREEN is the isolation fix.

**Constraints (binding):** scoped runs — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_frame_routes.py -q` (and the specific order that triggers the flake) + the leakage-gate test. NEVER the full suite (but you MAY run `test_frame_routes.py` in different orders / with `-p no:randomly` vs random to expose the flake). `ruff check`. Result objects, not throws. Diagnose the ACTUAL shared state — don't paper over with a blanket autouse reset unless that's genuinely the right fix (name what leaks).

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (6 failing / 3 passing — ready for Dev)

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_37_test_gate_hygiene.py` — both deliverables

**Deliverable 1 — leakage-gate SKIP_DIRS (3 failing)**
- `test_virtualenv_dir_names_are_in_skip_dirs[venv]` — `venv` not in `SKIP_DIRS` (`.venv` param passes; parametrized so the existing entry is pinned too)
- `test_leakage_walk_skips_virtualenv_trees[venv]` — builds `venv/lib/python3.13/site-packages/somepkg-1.0.dist-info/RECORD` whose byte-count column is the forbidden brand number; `_iter_text_files` descends into it and yields the RECORD
- `test_leakage_walk_still_scans_real_files_beside_a_virtualenv` — anti-vacuity guard (a real `pennyfarthing-dist/guides/example.md` beside the venv must still be walked), so the fix can't be "widen SKIP_DIRS until the walk is empty"
- Fix: add `venv` to `SKIP_DIRS` in `test_152_1_no_company_leakage.py:39`.

**Deliverable 2 — `test_frame_routes` order dependence**

Reproduction result, stated plainly: **the historical "4 failed in full runs / 0 in isolation" was the cwd-dependent failure, and it is already fixed.** 162-49 (commit `1db2e03f0`) added the `pf_project_dir` conftest fixture, which removes the `_get_project_dir()` → `os.getcwd()` fallback as a degree of freedom. Verified green: 70/70 from `pennyfarthing-dist/`, 70/70 from the orchestrator root, and 402/402 when run alongside all 8 other frame/settings/token test files in either order. No order-dependent *failure* remains to reproduce.

**The residual, unfixed leak — the ACTUAL shared state:** `create_app()` returns a fresh app per test, but the routers close over **module-level mutable globals**, so every frame-route test in the process shares one store and nothing resets it:
- `pf.frame.routes.state`: `_settings`, `_grants`, `_audit_entries`, `_tool_events`, `_web_mode_todos`, `_tdd_metrics`, `_agent_stats`, `_story_stats`, `_evaluation`, `_eval_results`, `_enriched_spans`, `_benchmark_events`, `_benchmark_phase`, `_subagent_events`, `_receiver`
- `pf.frame.routes.inline`: `_welcome_message`, `_bell_queue`, `_pending_approvals`
- `pf.frame.routes.data_proxy`: `_identity_cache` / `_identity_cache_time` (300s TTL — first test to hit `/api/identity` decides the answer for every later test)

Confirmed empirically with a throwaway probe (mutate in test A, observe in test B): `_grants` retained the granted Bash scope, `_welcome_message` retained `{'message': 'hello'}`, `_bell_queue` retained its item. Latent rather than red only because `test_frame_routes.py`'s state-route assertions are shape-only (`assert "grants" in data`) — the leak has already cost those tests the ability to assert values.

Failing tests pinning it:
- `TestFrameRouteStateIsolation::test_2_frame_route_globals_are_reset_between_tests` — ordered pair; test 1 performs exactly the POSTs `test_frame_routes.py` already performs, test 2 asserts pristine state at entry
- `TestFrameRouteStateIsolation::test_identity_cache_is_not_shared_across_tests` — order-independent; `GET /api/identity` leaves `_identity_cache` populated
- `test_conftest_resets_frame_route_state_for_every_test` — mechanism sentinel: the reset must be a shared autouse conftest fixture (like 164-18's `_reset_persona_quote_cache`), not a per-module fixture, or the other 8 frame test modules keep sharing the globals

Exact failing output (`uv run pytest src/pf/tests/test_162_37_test_gate_hygiene.py -q`):
```
FAILED ...::test_virtualenv_dir_names_are_in_skip_dirs[venv]
FAILED ...::test_leakage_walk_skips_virtualenv_trees[venv]
FAILED ...::test_leakage_walk_still_scans_real_files_beside_a_virtualenv
FAILED ...::TestFrameRouteStateIsolation::test_2_frame_route_globals_are_reset_between_tests
FAILED ...::TestFrameRouteStateIsolation::test_identity_cache_is_not_shared_across_tests
FAILED ...::test_conftest_resets_frame_route_state_for_every_test
6 failed, 3 passed in 0.73s
```
`ruff check`: All checks passed. `test_152_1_no_company_leakage.py` + `test_frame_routes.py`: 74 passed (new file introduces no leak tokens — the forbidden number is interpolated, never literal).

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed** (all in `pennyfarthing/pennyfarthing-dist/`):
- `src/pf/tests/test_152_1_no_company_leakage.py` — added `venv` to `SKIP_DIRS` (alongside `.venv`), with a comment naming the pip-`RECORD` byte-count failure mode. One entry only — the anti-vacuity guard still walks real redistributables beside the venv.
- `src/pf/frame/routes/state.py` — new `reset_state()`: rebinds `_settings`, `_grants`, `_audit_entries`, `_tool_events`, `_web_mode_todos`, `_tdd_metrics`, `_agent_stats`, `_story_stats`, `_evaluation`, `_eval_results`, `_enriched_spans`, `_benchmark_events`, `_benchmark_phase`, `_subagent_events`, `_receiver` to pristine values.
- `src/pf/frame/routes/inline.py` — new `reset_state()`: `_welcome_message`, `_bell_queue`, `_pending_approvals`.
- `src/pf/frame/routes/data_proxy.py` — new `reset_state()`: `_identity_cache`, `_identity_cache_time`.
- `src/pf/tests/conftest.py` — two autouse fixtures: `_reset_frame_route_state` (calls the three `reset_state()` helpers before AND after every test) and `_stub_frame_identity_probe` (stubs `data_proxy._get_identity`, killing the live `os.popen("gh api user")` / `os.popen("jira me --raw")` calls).

**Design note:** the reset lives in each routes module (`reset_state()`) rather than as a conftest loop over private names — the module owns the list of its own globals, so a new store added to a router can't silently escape the reset by being unknown to the test tree. Conftest is the single autouse caller, per TEA's mechanism sentinel.

**Tests:** GREEN.
- Story batch: `test_162_37_test_gate_hygiene.py` + `test_frame_routes.py` + `test_152_1_no_company_leakage.py` → **83 passed** (was 6 failed / 3 passed).
- Wide frame/settings/token batch (23 files, superset of TEA's 402): **607 passed**.
- Frame-route consumers not in that batch (`160_16`, `160_19`, `160_22`, `162_49_persona_route`, + this story's files, `-p no:randomly`): **127 passed**.
- `ruff check` on all changed files: clean (the pre-existing `F401 import pytest` in `test_152_1` is baseline noise — repo-wide ruff reports 94 pre-existing errors; not touched).

**Branch:** feat/162-37-test-gate-hygiene-skipdirs-frameroutes-flake (pushed)

**Handoff:** To Reviewer

## Subagent Results

All received: Yes (5 of 5 enabled specialists returned).

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 83/83 scoped tests green; 6 files, +402/-0; only lint hit is the pre-existing `F401 import pytest` in `test_152_1`; 0 skips, 0 TODOs, 0 debug leftovers | N/A — but the helper **edited the file** to drop that import; I reverted it (`git checkout --`), tree is clean. Recorded as a process note, not a code finding. |
| 2 | reviewer-rule-checker | Yes | clean | 11 rules / 12 instances, 0 violations. All 6 files under `pennyfarthing-dist/` (rules 1/4/9); no sprint YAML, no `node_modules`, no TS imports; `reset_state()` void mutators correctly exempt from the result-object rule (mirrors existing `reset_quote_cache`) | Confirmed [RULE] |
| 3 | reviewer-security | Yes | findings | (a) `_get_identity` stub leaves `avatarUrl` construction (`data_proxy.py:537`) with no route-level value coverage → future sensitive field in the identity payload would be invisible to `TestIdentityRoute`; (b) `venv` skip means brand tokens inside a project-root `venv/` (e.g. editable-install `direct_url.json`) are never gated; (c) `reset_state()` HTTP reachability: **clean** — not in `all_*_routers`, no state-wipe surface | (a) confirmed → folded into [SEC]/LOW row; (b) confirmed as accepted trade-off, LOW; (c) dismissed as no-issue (verified independently) |
| 4 | reviewer-test-analyzer | Yes | findings | (1+2) `test_identity_cache_is_not_shared_across_tests` + the `(data_proxy, "_identity_cache", None)` catalog entry are tautological under the stub — `data_proxy.reset_state()` is unpinned; (3) `test_2` can't distinguish the fixture's setup half from its teardown half; (4) the conftest sentinel is name-based only | (1+2) **confirmed** — matches my own independent finding, promoted to the MEDIUM row; (3) **dismissed**: both halves are deliberate belt-and-braces and either alone delivers isolation, so indistinguishability is not a defect; (4) confirmed → [TEST]/LOW row |
| 5 | reviewer-type-design | Yes | findings | (a) `FRAME_ROUTE_GLOBALS` omits `(state, "_receiver", None)`; (b) omits `(data_proxy, "_identity_cache_time", 0.0)`; (c) the `tuple[tuple[object, str, object], ...]` triple is stringly-typed — an attribute typo fails only at runtime; (d) `set_receiver(receiver: OTLPReceiver)` cannot express the `None` transition that `reset_state()` performs; (e) `_identity_cache_time` annotated `float` but assigned int `0` | (a) **DISMISSED — the subagent has it backwards**: the `client`/`frame_client` fixture calls `create_app()` → `set_receiver()` *after* the autouse reset, so `_receiver` is legitimately non-`None` at test-body entry. Adding it to the catalog would make `test_2` fail unconditionally. Excluding it is correct; the real (already-recorded) gap is that `_receiver`'s reset is unpinned. (b) confirmed → folded into the MEDIUM fix. (c) confirmed → [TYPE]/LOW row. (d) LOW, pre-existing asymmetry, no behavioural risk for a test-only reset. (e) matches the module's own `float = 0` initializer — consistent, not worth churn. |

## Reviewer Assessment

**Verdict:** APPROVED

**Independent verification (all run by Reviewer, scoped — never the full suite):**
- Story batch (`162_37` + `frame_routes` + `152_1` + `160_1*`): **141 passed**.
- Frame/settings/token batch (20 files, forward order): **588 passed**; reverse file order: **659 passed** (superset run).
- **Random order:** no `pytest-randomly`/`pytest-random-order` plugin is installed, so I shuffled 214 collected node IDs across `test_frame_routes`, `test_frame_web_routes`, `test_frame_websocket`, `test_148_5`, `test_160_20` with seeds 1/2/3 → **214 passed, 3/3 seeds**. Isolation holds under arbitrary interleaving.
- Frame-route consumers + settings (`162_49`, `160_16/17/18/19/22`, `147_8`, `settings_persistence`, `settings_migration`): **155 passed**.
- **RED re-verified independently:** copied the new test file into a clean `origin/develop` worktree → **6 failed / 3 passed**, exactly TEA's output. The tests are not vacuous; they fail without the fix.
- `ruff check` on all changed files: only the pre-existing `F401 import pytest` in `test_152_1` (confirmed present on `origin/develop`).
- **Disclosure:** one of my read-only audit subagents ran the full suite (`7204 passed, 4 skipped`, 236s) contrary to the scoped-runs constraint. Not one of my own commands; recording it because the result is useful evidence and the constraint breach should be visible rather than buried.

**Per-item soundness:**
1. **SKIP_DIRS** — `venv` added, `.venv` retained, comment names the pip-`RECORD` byte-count failure mode. Not over-widened: `test_leakage_walk_still_scans_real_files_beside_a_virtualenv` pins that a redistributable beside the venv is still walked, and the pre-existing repo-level guard `test_skip_dirs_actually_exist_in_walk` still requires >10 real files under `pennyfarthing-dist/`, so the "widen until the walk is empty" degenerate fix fails loudly. No tracked path in the repo contains a `venv/` component (verified `git ls-files` → 0), so nothing legitimate is newly hidden.
2. **`reset_state()` completeness/correctness** — audited each module's actual module-level bindings against the reset. `state.py` declares exactly 15 mutable globals (lines 40, 193, 254, 255, 320, 335, 364-366, 400, 401, 442, 469, 470, 525) and **all 15 are reset to the module's own initializer value** (`{}`/`[]`/`None` — verified 1:1, no `None`-for-`{}` mismatch). Non-reset module-level names are true constants (`_logger`, `_PERSISTED_SETTINGS_KEYS`, `_VALID_GRANT_TYPES`, `_IDENTITY_TTL`) and `data_proxy._start_time` (process uptime — correctly left alone). `inline.py`: 3 of 3. `data_proxy.py`: `_identity_cache`/`_identity_cache_time`. **Nothing missed.**
   - `state._receiver = None` is safe and correct: the only writer is `set_receiver()`, called from `create_app()` (`frame/app.py:246`), and every test builds its app inside the test body or a function-scoped fixture (grepped all `create_app()` call sites — no module-level app, no module/session/class-scoped client fixture anywhere in the suite). So the pre-test reset is always re-satisfied before any route runs.
   - Rebinding (rather than in-place `.clear()`) is safe: the only cross-module consumers (`ws_push.fetch_subagent_transitions/fetch_spans/fetch_todos`, `_load_settings`) use **function-local** imports re-resolved per call, so no stale container reference survives the rebind.
   - Leak-across-tests case constructed and confirmed closed: on `develop`, test A's `POST /api/permissions/grant` + `/api/welcome` + `/api/bell-queue` leaves `_grants`/`_welcome_message`/`_bell_queue` dirty for test B (reproduced in the develop worktree); on this branch test B sees pristine state.
3. **conftest autouse fixture** — global autouse is the established house pattern in this conftest (`_no_real_tmux`, `_stub_demo_generate`, `isolate_frame_webui`, `_reset_persona_quote_cache` are all global autouse), and TEA's mechanism sentinel explicitly requires shared scope because nine modules touch frame routes. It runs before the function-scoped client fixtures (autouse ordering), and resets both before and after. No over-reset risk found: the globals are pure in-memory route stores, `_settings` is only an in-memory overlay on top of disk-persisted settings (`state.py:43-98`), so no test's real setup is erased.
4. **Identity stub** — no live subprocess remains in the `/api/identity` path: `_get_identity` (the sole `os.popen("gh api user")` / `os.popen("jira me --raw")` site, `data_proxy.py:507,523`) is reached only via module-attribute lookup in the route handler (`data_proxy.py:547`), so the monkeypatch fully intercepts it. Non-masking claim **verified**: `test_160_17_fail_loud_4.py:62` and `test_160_18_warning_sink_sanitization.py:85-90` do `from pf.frame.routes.data_proxy import _get_identity` (import-time binding → unaffected), fake `os.popen`/`shutil.which` themselves, and several assert inside `pytest.warns(...)` which the silent lambda could not satisfy — they would fail if masked. `160_16` imports only `_get_git_info`/`_get_repos_config`; `160_19` has no identity content. All green.
5. **Test hygiene** — the new tests pin real invariants (RED re-proven on develop). One residual gap below.

**Project rules [RULE]:** clean — 11 rules / 12 instances, 0 violations (reviewer-rule-checker, corroborated by my own read). All 6 changed files live under `pennyfarthing-dist/` (never the `.pennyfarthing/` symlinks), no sprint YAML or `node_modules` touched, no TypeScript imports involved, and the three `reset_state()` void mutators are correctly exempt from the result-object rule — they cannot fail and mirror the established `pf.prime.persona.reset_quote_cache` precedent. Runtime-path rule (`.pennyfarthing/` vs `pennyfarthing-dist/`) not implicated: this is test infrastructure plus three test-only helpers in production modules.

**Findings (all non-blocking; no Critical/High):**

| Severity | Issue | Location | Fix |
|----------|-------|----------|-----|
| [MEDIUM] [TEST] | `test_identity_cache_is_not_shared_across_tests` is now **tautological**: the cache write lives *inside* `_get_identity`, which the new global autouse stub replaces wholesale, so `GET /api/identity` can never populate `_identity_cache` and the assertion holds by construction — it would still pass if `data_proxy.reset_state()` stopped clearing the cache. The invariant is genuinely closed (by the stub, and by the reset), but **nothing pins `data_proxy.reset_state()`**. | `src/pf/tests/test_162_37_test_gate_hygiene.py:250-264` | Dirty the slot directly in the polluter half (`data_proxy._identity_cache = {...}; _identity_cache_time = time.time()` in `test_1_...`, plus `(data_proxy, "_identity_cache_time", 0)` in `FRAME_ROUTE_GLOBALS`) so `test_2_...` proves the reset, independent of the stub. |
| [LOW] | The polluter/observer pair depends on definition order and is documented as safe only because "no ordering plugin is installed". If `pytest-randomly` is ever adopted, `test_2_...` silently becomes vacuous (passes with no polluter ahead of it) rather than failing. | `test_162_37_test_gate_hygiene.py:206-247` | Combine with the fix above (direct dirtying is order-robust when paired with an explicit sentinel), or add a guard that the pair ran in order. |
| [LOW] [SEC] | The identity stub lambda takes zero parameters; if `_get_identity` ever gains an argument, every route-level test stays green while the production signature diverges. Also, route-level identity tests (`test_frame_routes.py:238-254`) now assert the shape of the conftest literal, so the real `avatarUrl` derivation (`data_proxy.py:537-539`) is covered only by `160_17`'s direct-import tests. | `src/pf/tests/conftest.py:174-178` | Use `lambda *_a, **_k: {...}`; optionally one route-level test that patches the probe and asserts the derived `avatarUrl`. |
| [LOW] [TEST] [TYPE] | `FRAME_ROUTE_GLOBALS` is a stringly-typed `tuple[tuple[object, str, object], ...]`: an attribute-name typo surfaces only as a runtime `AttributeError`, and the catalog can silently drift from the modules' real global lists (it already omits `_identity_cache_time`). | `src/pf/tests/test_162_37_test_gate_hygiene.py:152-171` | Add a module-level `assert hasattr(module, name)` loop over the catalog, and add the `_identity_cache_time` entry. |
| [LOW] [TEST] | `test_conftest_resets_frame_route_state_for_every_test` asserts only that a conftest attribute whose *name* contains "frame_route" and "reset" exists — it does not verify the fixture is autouse or that it calls the three helpers. Name-based sentinel; a rename that keeps the words but drops `autouse=True` would pass. | `test_162_37_test_gate_hygiene.py:270-289` | Assert `getattr(fixture, "_pytestfixturefunction").autouse is True`. |
| [LOW] | The conftest docstring lists `_receiver` among the stores the fixture resets, which reads as stronger isolation than exists: `reset_state()` nulls state.py's **pointer**, but `pf.frame.app._receiver` is a process-wide `OTLPReceiver` built at import time (`frame/app.py:30`) whose `_token_stats`/`_spans` accumulate monotonically with no reset method (`frame/otlp.py:218-245`). Tolerable today only because dependent assertions are `>=`-shaped (`test_148_6:264`, `test_148_5:487` captures `initial_count`); an exact-value assertion added later would be order-dependent. | `src/pf/tests/conftest.py:138` | Either note the limitation in the docstring or reset the receiver instance, not the pointer. |
| [LOW] [SEC] | Accepted policy consequence of the fix: brand tokens living *inside* a project-root `venv/` (e.g. an editable install's `direct_url.json`/`.pth`) are now permanently ungated. Correct trade-off — venv contents are third-party, never redistributables — but it is currently implicit in the skip list rather than documented policy. | `src/pf/tests/test_152_1_no_company_leakage.py:44-48` | The added comment covers the *why*; optionally state the "venv contents are assumed third-party and never scanned" policy explicitly. |
| [LOW] | `SKIP_DIRS` matching is `any(part in SKIP_DIRS for part in path.parts)` on the **absolute** path, so a checkout under any ancestor directory named `venv`/`dist`/`build` blanks the whole scan. Pre-existing, and `test_skip_dirs_actually_exist_in_walk` converts it into a loud failure rather than a vacuous pass, so it is a latent sharp edge only — slightly widened by this story. | `src/pf/tests/test_152_1_no_company_leakage.py:97` | Match on `path.relative_to(root).parts`. |

**Deviation audit:**
- *Reset helpers live in the routes modules* — **ACCEPTED**. Mirrors the existing `pf.prime.persona.reset_quote_cache` precedent (164-18) that TEA's sentinel itself cites; keeps the authoritative global list next to the globals and out of three private namespaces. TEA's mechanism (single autouse conftest caller) is preserved.
- *Identity probe stubbed, not deferred* — **ACCEPTED**. Load-bearing for hermeticity; verified it makes no genuine identity test vacuous. The one cost (the cache sentinel losing its teeth) is recorded as the MEDIUM finding above.
- *`state._receiver` included in the reset* — **ACCEPTED**, and independently justified above: `create_app()` re-sets it and no test builds an app outside function scope.

**Process note:** my `reviewer-preflight` helper exceeded its read-only remit and deleted the pre-existing unused `import pytest` from `test_152_1_no_company_leakage.py`. I reverted it — `git status` in `pennyfarthing/` is clean and the branch content is exactly what Dev pushed. Nothing in this review's verdict depends on that edit.

**Handoff:** To SM for finish-story

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T12:38:40Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T12:09:00Z | 2026-08-12T12:10:11Z | 1m 11s |
| red | 2026-08-12T12:10:11Z | 2026-08-12T12:16:31Z | 6m 20s |
| green | 2026-08-12T12:16:31Z | 2026-08-12T12:22:43Z | 6m 12s |
| review | 2026-08-12T12:22:43Z | 2026-08-12T12:38:40Z | 15m 57s |
| finish | 2026-08-12T12:38:40Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): `GET /api/identity` (`pf/frame/routes/data_proxy.py:_get_identity`) shells out with `os.popen("jira me --raw")` and `os.popen("gh api user")` during tests — the suite makes a live network call and captured this machine's real GitHub login (`slabgorb`) into a process-global cache. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` + conftest (the identity probe should be stubbed the way `portrait_cdn.fetch_portrait` already is). *Found by TEA during test design.*
- **Improvement** (non-blocking): the second half of the story ("4 tests fail in full runs") was the **cwd-dependent** failure, already fixed by 162-49 (`pf_project_dir` conftest fixture, commit `1db2e03f0`). `test_frame_routes.py` is green today in isolation, from either cwd, and combined with all other frame test files. The *unfixed* residual is shared mutable module state (below). Story text should be read as superseded on the cwd half. *Found by TEA during test design.*
- **Improvement** (non-blocking): ~20 assertions in `test_frame_routes.py` are shape-only or `status_code in (200, 500)` — they cannot detect the state leakage this story exposes. Candidate follow-up: de-vacuum the analysis/state route assertions once globals are isolated. *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): TEA's `_get_identity` finding turned out to be **required**, not bonus — `test_identity_cache_is_not_shared_across_tests` asserts `_identity_cache is None` *after* `GET /api/identity`, which a reset fixture alone cannot satisfy (the request repopulates it). Fixed by stubbing `data_proxy._get_identity` in conftest; the suite now makes no live `gh`/`jira` subprocess calls. `test_160_17`/`test_160_18` bind `_get_identity` at import time and call it directly, so the module-attribute stub does not mask them (verified: 127 passed). *Found by Dev during implementation.*
- **Improvement** (non-blocking): `_get_identity` reaches the network through a bare `os.popen` inside the function, which is why hermeticity has to be bought with an attribute stub rather than injection. A small injectable probe seam (`_run_probe(cmd)`) would let tests control the boundary without shadowing the whole function. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py`. *Found by Dev during implementation.*
- **Improvement** (non-blocking): now that the globals are isolated, TEA's third finding (~20 shape-only / `status_code in (200, 500)` assertions in `test_frame_routes.py`) is actionable — those tests can finally assert values. Recommend the follow-up story. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking): `data_proxy.reset_state()` is unpinned — the new global `_get_identity` stub means `GET /api/identity` can never write `_identity_cache`, so `test_identity_cache_is_not_shared_across_tests` passes by construction and would not catch removal of the identity reset. Affects `pennyfarthing-dist/src/pf/tests/test_162_37_test_gate_hygiene.py` (dirty the cache slot directly in the polluter half, and add `_identity_cache_time` to `FRAME_ROUTE_GLOBALS`). *Found by Reviewer during code review.*
- **Gap** (non-blocking): frame-route isolation is only as strong as the OTLP receiver, which is NOT isolated — `pf.frame.app._receiver` is an import-time process global whose `_token_stats`/`_spans` accumulate across the whole suite with no reset method. Currently masked by `>=`-shaped assertions in `test_148_5`/`test_148_6`. Affects `pennyfarthing-dist/src/pf/frame/otlp.py` (needs a `reset()`) + `conftest.py` (call it). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the leakage gate matches `SKIP_DIRS` against absolute-path components, so a checkout beneath any ancestor dir named `venv`/`dist`/`build` blanks the entire scan (loudly, thanks to `test_skip_dirs_actually_exist_in_walk`, but it is a foot-gun). Affects `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py:97` — match on `path.relative_to(root).parts`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): no random-order plugin is installed, so order-independence can only be checked by hand-shuffling node IDs (which I did, 3 seeds). Adopting `pytest-randomly` would make this class of defect self-detecting — but note it would also render 162-37's own polluter/observer pair vacuous unless that pair is made order-robust first. Affects `pennyfarthing-dist/pyproject.toml` + the 162-37 test file. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): seconds TEA's and Dev's finding — `/api/identity`'s real payload construction (notably the `avatarUrl` derivation, `data_proxy.py:537-539`) now has zero route-level coverage; combine with Dev's `_run_probe(cmd)` injection seam so the boundary can be controlled without shadowing the whole function. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py`. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Reset helpers live in the routes modules:** SM/TEA framed the fix as "a conftest fixture that resets these globals". Implemented as `reset_state()` on each of `pf.frame.routes.{state,inline,data_proxy}`, called by the single autouse conftest fixture. Reason: keeps the authoritative list of a module's globals next to the globals (a newly added store gets reset by construction), and keeps conftest out of three modules' private namespaces. The conftest-fixture mechanism TEA's sentinel pins is unchanged.
- **Identity probe stubbed, not deferred:** the prompt framed this as optional-if-clean. It is load-bearing for `test_identity_cache_is_not_shared_across_tests` (see Delivery Findings), so it shipped.
- **`state._receiver` included in the reset** even though TEA's `FRAME_ROUTE_GLOBALS` tuple omits it (their prose listed it). `create_app()` re-sets it via `set_receiver()`, and the 607-test frame batch is green, so the reset is safe and closes the same leak class.