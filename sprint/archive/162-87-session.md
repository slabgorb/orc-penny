---
story_id: "162-87"
jira_key: ""
epic: "epic-162"
workflow: "tdd"
---
# Story 162-87: data_proxy git-panel base/remote polish: non-origin remote_name test coverage, honest _get_repos_config type/docstring, get_git root-repo edge handling, developBehind to baseBehind rename (162-71 review follow-up)

## Story Details
- **ID:** 162-87
- **Jira Key:** (none — framework-internal story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-87-data-proxy-polish
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-17T17:27:25Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-17T16:34:03Z | 2026-08-17T16:37:09Z | 3m 6s |
| red | 2026-08-17T16:37:09Z | 2026-08-17T16:46:02Z | 8m 53s |
| green | 2026-08-17T16:46:02Z | 2026-08-17T17:04:50Z | 18m 48s |
| review | 2026-08-17T17:04:50Z | 2026-08-17T17:19:19Z | 14m 29s |
| green | 2026-08-17T17:19:19Z | 2026-08-17T17:25:02Z | 5m 43s |
| review | 2026-08-17T17:25:02Z | 2026-08-17T17:27:25Z | 2m 23s |
| finish | 2026-08-17T17:27:25Z | - | - |

## Technical Context

### Problem Statement

This story addresses four distinct findings from the Reviewer during the 162-71 code review (see `sprint/archive/162-71-session.md` Delivery Findings, lines 173–198). The 162-71 work de-hardcoded `origin/develop` at git-probe sites, but left four gaps:

1. **Test coverage gap on non-origin remotes** — data_proxy tests only exercise the default `origin` remote, leaving a regressor path where `remote` is re-hardcoded while `base` stays dynamic.
2. **Dishonest `_get_repos_config` type/docstring** — the function claims "Each entry carries `base` and `remote`" but the single-repo fallback shape omits both keys.
3. **Root-repo edge case in `get_git`** — the route falls to `repos[0]` when repos.yaml has no path-"."-declared repo, and an empty `repos: {}` dict silently defaults to the fallback shape.
4. **Misleading `developBehind` field name** — the field now carries per-repo base counts (main for trunk-based orchestrator, develop for gitflow pennyfarthing), so the gitflow-specific name actively leaks the wrong assumption. API rename: `developBehind` → `baseBehind` across producers (data_proxy), TUI consumer (git_panel), and web consumer (web/).

### Technical Approach

Approach: TDD (RED first). Story scope is cleanly split into four acceptance criteria, each a distinct fix.

**Red Phase (TEA):**
- AC1 requires mutation-probe-resistant test coverage: a test that fails against a tautological/hardcoded `remote="origin"` in the probe, and only passes through the real remote-name thread. Shape: `_write_project(..., remote_name="upstream")` fixture variant asserting `upstream` appears in the git argv, no `origin` fallback.
- AC2–4 define observable behavioral/type corrections; TEA defines failing tests that pin the correct behavior.

**Green Phase (Dev) & Beyond:**
- AC4 has a cross-module rename blast radius: `_get_git_info` return dict + `get_git_all` (producers), `git_panel.py` TUI display, and `web/src/` consumers. Trace all references; nothing old-named may remain.
- AC3 edge handling is a validation/logging gap, not data corruption — graceful degradation acceptable.

### Acceptance Criteria

**AC1 — non-origin remote_name test coverage:**
Add a test case to `test_162_71_data_proxy_base_branch.py` that fixtures a project with `remote_name="upstream"` (instead of the default `origin`) and asserts that the git argv passed to `subprocess.run` contains `upstream/<base>` (not `origin/<base>`). The test must fail against a hardcoded `remote="origin"` in the probe and only pass through the real remote-name thread (mutation-probe shape). This pins the remote axis as a live behavioral thread, not a dead code path.

**AC2 — honest `_get_repos_config` type/docstring:**
Update the `_get_repos_config` function's docstring and type annotation to accurately describe the return shape and the single-repo fallback's contract. The main path (repos.yaml found and valid) returns entries with `base` and `remote` keys; the single-repo fallback returns entries with only `name` and `path` (no `base`/`remote`). Use a `TypedDict(total=False)` annotation or a union type to express the optional keys. Verify the corrected docstring against the real return shape in `data_proxy.py`.

**AC3 — `get_git` root-repo edge handling:**
Handle the two edge cases in the `get_git` route (the single-repo panel): (1) repos.yaml declares multiple repos and none with `path: "."`, so `repos[0]` is a non-root fallback, and (2) an empty `repos: {}` yields a silent fallback. Add logging or surface a config mismatch so operators see when the route is probing the wrong repo. Document the expected repos.yaml shape (root repo must declare `path: "."`).

**AC4 — `developBehind` → `baseBehind` rename:**
Rename the JSON field `developBehind` to `baseBehind` across all producers and consumers: (1) `_get_git_info` return dict in `data_proxy.py` (line ~290), (2) `get_git_all` route response (line ~398), (3) `git_panel.py` TUI consumer reading the field, and (4) `web/src/` JavaScript/TypeScript consumers referencing `developBehind`. Trace all references; the old name must not appear in production code. This generalizes the field name away from the gitflow-specific assumption (develop → generic base).

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (blocking): `ws_push.fetch_git` is a SECOND producer of the behind-base field (`developBehind`) that the story title did not name, and it calls `_get_git_info(repo_path)` with NO base/remote args — so it ignores repos.yaml config and always probes `origin/develop` (RED test proves `HEAD..origin/develop` for a main-repo). AC4's rename MUST include this producer or the HTTP transport emits `baseBehind` while the WebSocket transport emits `developBehind` and the web consumer (typed `baseBehind`) breaks. Renaming it there while leaving it develop-hardcoded is a named lie. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py` (line ~173 field rename + thread base/remote from repo config into `_get_git_info`, mirroring `get_git_all`). Pinned by `test_ws_fetch_git_uses_baseBehind` + `test_ws_fetch_git_honors_configured_base`. *Found by TEA during test design.*
- **Improvement** (non-blocking): The story's AC4 assumed `git_panel.py` (TUI) reads the field — it does NOT (grep for "Behind" in `tui/git_panel.py` is empty; the panel renders name/branch/ahead/behind/clean/dirtyFiles only). No web component displays the field either — it exists only in the `web/src/api/types.ts` `GitRepo` type and `web/src/test/fixtures/git.ts` fixtures. The rename must still update those TS type/fixtures + the `tests/python/test_tui_git_panel.py` sample dicts (lines 53/66/82/357) for consistency, but there is no live display consumer to break. Affects `web/src/api/types.ts`, `web/src/test/fixtures/git.ts`, `pennyfarthing/tests/python/test_tui_git_panel.py`. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): Pre-existing, unrelated full-suite failure `test_162_5_quarantine_policy.py::test_every_xfail_cites_a_tracking_reference` — the offender is `test_162_83_toctou_decision.py`'s xfail reason, which the policy regex flags despite naming `162-83`. PROVEN pre-existing: fails on the baseline (my impl stashed) at `d1876c054`. NOT caused by 162-87 (this diff adds zero xfail markers). Affects `pennyfarthing-dist/src/pf/tests/test_162_5_quarantine_policy.py` / `test_162_83_toctou_decision.py` (the policy regex or the 162-83 xfail reason format need reconciling — a separate story). *Found by Dev during implementation.*
- **Question** (non-blocking): The web-layer verification (TS typecheck / vitest) could not run — the `web/` toolchain (pnpm/tsc/vitest) is not installed in this session. The `developBehind` → `baseBehind` rename in `web/src/api/types.ts` + `web/src/test/fixtures/git.ts` is syntactically correct and consistent (type + fixtures renamed together, no component reads the field) but is not toolchain-verified here. Affects `web/` (a web-toolchain run should confirm the type rename compiles before/at external review). *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (blocking): `RepoConfig(TypedDict, total=False)` marks `name`/`path` as optional though they are always present, so the annotation still doesn't "accurately describe the return shape" (AC2) — the exact honest-contract defect class the story fixes (SOUL #14; corroborated by type-design + rule-checker). Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (split into required base + `total=False` extension). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): ruff `I001` unsorted import block would fail a CI ruff gate. Affects `pennyfarthing-dist/src/pf/tests/test_162_87_data_proxy_polish.py` (`ruff check --fix`). *Found by Reviewer during code review.*
- **Gap** (non-blocking): AC2 default-fill path (`or "develop"`/`or "origin"` when a repos.yaml entry omits `default_branch`/`remote_name`) is untested; a regression hardcoding `""` would pass. Affects `pennyfarthing-dist/src/pf/tests/test_162_87_data_proxy_polish.py` (add an omit-keys fixture). *Found by Reviewer during code review — file as follow-up.*
- **Improvement** (non-blocking): `test_get_git_warns_on_empty_repos_config`'s `"root" or "repos"` disjunction is weaker than its sibling; tighten to pin `"root"`. Affects `pennyfarthing-dist/src/pf/tests/test_162_87_data_proxy_polish.py`. *Found by Reviewer during code review — file as follow-up.*


## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **AC4 scope extended to the ws_push producer + made base-aware**
  - Spec source: session AC4 (`developBehind` → `baseBehind` rename across producers `data_proxy`, TUI, web)
  - Spec text: "Rename the JSON field `developBehind` to `baseBehind` across all producers and consumers: (1) `_get_git_info` ... (2) `get_git_all` ... (3) `git_panel.py` TUI consumer ... (4) `web/src/` consumers"
  - Implementation: Added `ws_push.fetch_git` (WebSocket transport) as a THIRD producer that must rename in lockstep AND thread the configured base/remote (it currently ignores repos.yaml). Pinned by two extra RED tests.
  - Rationale: `fetch_git` emits the same field over the WebSocket channel; renaming only the HTTP producers diverges the two transports and breaks the web consumer. Leaving it develop-hardcoded makes a field named `baseBehind` a lie. Same two-transport-divergence class 162-49 fixed in this file.
  - Severity: minor
  - Forward impact: Dev must edit `ws_push.py` (rename + thread base/remote), not only `data_proxy.py`.
- **AC4 assumption corrected: git_panel.py is not a consumer of the field**
  - Spec source: session AC4, item (3)
  - Spec text: "`git_panel.py` TUI consumer reading the field"
  - Implementation: No test written against `git_panel.py` reading the field, because it does not read it (verified: no "Behind" reference in `tui/git_panel.py`). Rename of TS types/fixtures + `test_tui_git_panel.py` sample dicts is covered as a non-blocking finding.
  - Rationale: writing a test for a non-existent consumer would be vacuous.
  - Severity: minor
  - Forward impact: Dev renames the TS/fixture references for consistency; no TUI display change needed.
- **AC1 & AC2 pinned as green-on-arrival coverage (not RED behavior tests)**
  - Spec source: session AC1, AC2
  - Spec text: AC1 "Add a test case ... asserts that the git argv ... contains `upstream/<base>`"; AC2 "Update the ... docstring and type annotation to accurately describe the return shape"
  - Implementation: AC1's HTTP-route remote threading already works (162-71 shipped it), so the AC1 tests PASS on arrival — they close the missing-coverage gap the reviewer named, with a mutation-probe shape (a hardcoded `origin` fails). AC2 is a docstring/annotation change with no runtime-observable behavior, so the AC2 tests pin the RUNTIME CONTRACT the honest docstring must describe (fallback omits base/remote); they also PASS on arrival and guard against a "fix" that adds base/remote to the fallback.
  - Rationale: TDD RED is not achievable for a coverage pin or a docstring edit; the tests still enforce the contract and are mutation-resistant.
  - Severity: minor
  - Forward impact: Dev must still (a) correct the `_get_repos_config` docstring + type annotation (AC2) even though no test toggles red→green for it — the AC2 tests will FAIL if the fix wrongly mutates the runtime shape.

### Dev (implementation)
- No deviations from spec. Implemented exactly the contract TEA's 11 tests pin, including the TEA-logged AC4 expansion to the `ws_push` producer (renamed the field AND threaded configured base/remote into `fetch_git`). AC2 fixed as docstring + `RepoConfig` `TypedDict(total=False)` annotation without mutating the runtime fallback shape. AC3 uses this file's established `warnings.warn` fail-loud pattern. Renamed the `_get_git_info` local `develop_behind` → `base_behind` (cosmetic, matches the new field name).

### Reviewer (audit)
- **TEA: "AC4 scope extended to the ws_push producer + made base-aware"** → ✓ ACCEPTED by Reviewer: correct and necessary — verified `ws_push.fetch_git` now threads `base`/`remote` identically to `get_git_all`, closing the two-transport divergence. Renaming without this would have shipped a base-unaware field named `baseBehind`. Sound call.
- **TEA: "AC4 assumption corrected: git_panel.py is not a consumer"** → ✓ ACCEPTED by Reviewer: verified `tui/git_panel.py` reads name/branch/ahead/behind/clean/dirtyFiles only; no `baseBehind` consumer. Not writing a vacuous test for a non-existent consumer is correct.
- **TEA: "AC1 & AC2 pinned as green-on-arrival coverage"** → ✓ ACCEPTED by Reviewer (with note): green-on-arrival is the right shape for a coverage pin (AC1) and a docstring/annotation change (AC2). Note: the AC2 runtime-contract pin correctly guards the fallback SHAPE, but a `TypedDict` annotation is not runtime-observable, so it could not catch the F1 honesty gap — that required type-level review. Not a fault in the deviation; it's why F1 surfaced here.
- **Dev: "No deviations from spec"** → ✓ ACCEPTED as a truthful record. The `total=False` choice followed AC2's explicitly-offered mechanism, so it is not a spec deviation — but it does not meet AC2's headline "accurately describe the return shape" goal (finding F1). Rework corrects it; no dishonesty in the log.

## SM Assessment

Setup complete, story routed to TEA for the RED phase. This is a 162-71 review follow-up; ACs are grounded verbatim against the reviewer findings in `sprint/archive/162-71-session.md` and the live source in `frame/routes/data_proxy.py`.

**Scope split (4 ACs, all in one story — a 3pt polish tail):**
- AC1 — non-origin `remote_name` test coverage (mutation-probe shape mandatory)
- AC2 — honest `_get_repos_config` type/docstring
- AC3 — `get_git` root-repo edge handling
- AC4 — `developBehind` → `baseBehind` rename (cross-module blast radius)

**Routing to TEA (RED):**
- AC1 is the load-bearing one for TDD: the new `remote_name="upstream"` test MUST be mutation-probe-resistant — it fails against a tautological hardcoded `origin` and only passes through the real remote thread. This project treats fixture-induced tautologies on headline behavior as blocking (per prior epic-162 rework cycles). Design the test so a hardcoded `origin` in the probe produces a FAIL.
- AC2/AC3 pin observable type/edge contracts — write failing assertions on the corrected return shape and the config-mismatch surfacing.
- AC4 is a rename: pin the NEW field name `baseBehind` in the route-response test AND require a producer→consumer trace (`data_proxy.py` producers, `git_panel.py` TUI, `web/src/` frontend) so Dev leaves no `developBehind` reference in production code.

**Base:** feature branch `feat/162-87-data-proxy-polish` off clean `develop` (pennyfarthing gitflow). Merge gate clear — no open pennyfarthing PRs.

**Handoff:** Captain Murdock (TEA) owns the RED phase. No code from SM.

## TEA Assessment

**Tests Required:** Yes
**Reason:** n/a

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_87_data_proxy_polish.py` — 11 tests across the 4 ACs (new file; commit `d1876c054`).

**Tests Written:** 11 tests covering 4 ACs
**Status:** RED (7 failing as designed, 4 green-on-arrival coverage pins) — ready for Dev

**RED breakdown (verified via testing-runner, `162-87-tea-red`):** `7 failed, 4 passed`, zero collection errors.

| AC | Test | On arrival | Enforces |
|----|------|-----------|----------|
| AC1 | `test_git_all_honors_non_origin_remote` | PASS | non-`origin` remote threaded on `/api/git/all` (mutation-probe: rejects `origin/main`) |
| AC1 | `test_git_single_honors_non_origin_remote` | PASS | same on `/api/git/` |
| AC2 | `test_repos_yaml_entries_carry_base_and_remote` | PASS | repos.yaml entries carry base+remote |
| AC2 | `test_single_repo_fallback_omits_base_and_remote` | PASS | fallback carries ONLY name+path (honest contract) |
| AC3 | `test_get_git_warns_when_no_root_repo_among_multiple` | **FAIL** | fail-loud warning when no `.`-path repo |
| AC3 | `test_get_git_warns_on_empty_repos_config` | **FAIL** | fail-loud warning on empty `repos: {}` |
| AC4 | `test_get_git_info_unit_returns_baseBehind` | **FAIL** | `_get_git_info` returns `baseBehind` |
| AC4 | `test_git_all_response_uses_baseBehind` | **FAIL** | `/api/git/all` emits `baseBehind` |
| AC4 | `test_git_single_response_uses_baseBehind` | **FAIL** | `/api/git/` emits `baseBehind` |
| AC4 | `test_ws_fetch_git_uses_baseBehind` | **FAIL** | ws_push transport emits `baseBehind` |
| AC4 | `test_ws_fetch_git_honors_configured_base` | **FAIL** | ws_push honors configured base (not hardcoded develop) |

### Rule Coverage (python lang-review)

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 silent-exceptions / #4 logging (fail-loud) | `test_get_git_warns_when_no_root_repo_among_multiple`, `test_get_git_warns_on_empty_repos_config` | failing (RED) |
| #3 type-annotations at boundary | AC2 pair pins the runtime shape the honest annotation must describe | passing (guards the fix) |
| #6 test-quality (self-check) | all 11 self-reviewed — no vacuous assertions; AC1 mutation-probe-shaped; AC2 asserts exact key sets | pass |
| #8 unsafe-deserialization | `yaml.safe_load` already used in `_get_repos_config`; no change | n/a |

**Rules checked:** 4 of 13 lang-review rules are applicable to this diff (routes/config/subprocess); the rest (async, deps, deserialization-of-untrusted, resource leaks) don't apply to the changed surface.
**Self-check:** 0 vacuous tests found.

### Dev implementation notes
- **AC3 shape:** established fail-loud pattern in this file is `warnings.warn(...)`. Emit a warning in `get_git` when no root repo is resolvable (no `.`-path entry among multiple repos, or empty `repos: {}`). The tests assert `pytest.warns` + a message mentioning `root`/`repos` — keep the message operator-actionable but exact wording is free.
- **AC4 is 3 producers, not 1:** `_get_git_info` (data_proxy:290), `get_git_all` (data_proxy:398), AND `fetch_git` (ws_push:173). Also thread base/remote into `fetch_git` (mirror `get_git_all`). Then rename the TS type/fixtures + `test_tui_git_panel.py` sample dicts. See Delivery Findings.
- **AC2 is docstring + annotation only:** correct `_get_repos_config`'s docstring (scope the "carries base+remote" claim to the repos.yaml path) and its return annotation (`TypedDict(total=False)` or scoped type). Do NOT add base/remote to the fallback — the AC2 tests will fail if you do.

**Handoff:** To Sergeant B.A. Baracus (Dev) for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` — AC2 (`RepoConfig` TypedDict + honest docstring), AC3 (fail-loud warning in `get_git` when no root repo), AC4 (`_get_git_info` returns `baseBehind`; `get_git_all` emits `baseBehind`; local var `develop_behind`→`base_behind`).
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — AC4 (`fetch_git` emits `baseBehind` AND now threads configured base/remote into `_get_git_info`, mirroring `get_git_all` — fixes the two-transport divergence).
- `web/src/api/types.ts` — AC4 (`GitRepo.developBehind` → `baseBehind`).
- `web/src/test/fixtures/git.ts` — AC4 (fixture keys renamed).
- `tests/python/test_tui_git_panel.py` — AC4 (sample payload dicts renamed).
- `pennyfarthing-dist/src/pf/tests/test_160_16_fail_loud_3.py` — AC4 (docstring reference renamed).

**Tests:** GREEN — story file 11/11 passing (`162-87-dev-green`); regression set (162-71, 160-16, TUI git panel) 54/54 passing; full Python suite `7584 passed, 4 skipped, 1 xfailed, 1 failed` where the single failure is the pre-existing, unrelated `test_162_5_quarantine_policy` xfail-citation lint (proven pre-existing at `d1876c054` with impl stashed — see Delivery Findings).
**Commits:** `d1876c054` (TEA tests), `61d275210` (impl).
**Branch:** `feat/162-87-data-proxy-polish` (pushed to origin).

**Self-review:**
- [x] All 4 ACs met (AC1/AC2 coverage pins stay green; AC3/AC4 behavior implemented)
- [x] Code follows project patterns (`warnings.warn` fail-loud; `.get(..., default)` config threading; `TypedDict(total=False)`)
- [x] Rename complete across every producer + typed consumer; no `developBehind` left in production code (build/ artifacts excluded — regenerated)
- [x] Error handling: AC3 fail-loud warning; degrade-unchanged fallback preserved
- [ ] Web typecheck not runnable this session (toolchain absent) — flagged as a finding

**Handoff:** To Colonel Decker (Reviewer) for adversarial review.

### Dev Rework (Round-Trip 1) — per-finding disposition

Commit `61dcef3f1`. Re-verified GREEN: 65/65 story+regression, ruff clean on all changed files, new classes import cleanly.

- **F1 (blocking) — FIXED:** Split `RepoConfig` into `class _RepoConfigBase(TypedDict)` (required `name`, `path`) + `class RepoConfig(_RepoConfigBase, total=False)` (optional `base`, `remote`). `name`/`path` are now correctly required; `{}` is no longer a valid `RepoConfig`; direct `repo["name"]`/`repo["path"]` subscript is type-safe. Docstring updated to describe the two-level split. `data_proxy.py:303`.
- **F2 (low) — FIXED (by F1):** With required `name`/`path`, `{}` no longer satisfies `RepoConfig`, so the `root: RepoConfig | dict[str, str] | None` union arm is now a meaningful signal (empty-repos fallback), exactly as reviewer-type-design noted. Left the annotation as-is — it is now accurate. `data_proxy.py:381`.
- **F5 (must-fix lint) — FIXED:** `ruff check --fix` resolved `I001` import-block ordering in `test_162_87_data_proxy_polish.py`; all changed files now pass `ruff check`.
- **F3 (medium) — DEFERRED:** tighten `test_get_git_warns_on_empty_repos_config` assertion — routed to follow-up per Reviewer disposition.
- **F4 (medium) — DEFERRED:** add AC2 default-fill (`or "develop"`/`or "origin"`) coverage — routed to follow-up per Reviewer disposition.

**Handoff:** Back to Colonel Decker (Reviewer) for cycle-1 re-review.

## Subagent Results

**Working-tree audit:** `pf reviewer audit-tree` reported DIRTY, but the two flagged files are the KNOWN FALSE POSITIVE (162-86 datapoint 6): `.pennyfarthing/sidecars/sm/patterns.md` (modified at session start, pre-existing) and `sprint/context/context-story-162-87.md` (sm-setup's legitimate untracked context artifact) — both orchestrator-repo files, not subagent mutations of reviewed source. The REVIEWED repo `pennyfarthing/` is verified clean (`git -C pennyfarthing status --porcelain` empty). `git clean -fd` NOT run (would delete the context doc). Subagents were read-only; no source mutation.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 1 (ruff I001) | confirmed 1 (F5) |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 2 | confirmed 2 (F3, F4 — deferred to follow-up) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | findings | 2 | confirmed 2 (F1 blocking, F2 folds into F1) |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | findings | 1 | confirmed 1 (F1 corroborated, SOUL #14) |

**All received:** Yes (5 enabled returned, 4 disabled via settings)
**Total findings:** 3 distinct confirmed (F1 blocking; F5 must-fix lint; F2 folds into F1), 2 confirmed deferred to follow-up (F3, F4), 0 dismissed
**Disabled-domain coverage:** [EDGE], [SILENT], [DOC], [SIMPLE] assessed first-hand by the Reviewer (see tagged observations below).

## Reviewer Assessment

**Verdict:** REJECTED — one blocking honest-contract violation (F1) + one CI-breaking lint (F5); testable/testing findings folded or deferred.

This is a well-executed change overall: the `developBehind`→`baseBehind` rename is atomic across all three producers (`_get_git_info`, `get_git_all`, `ws_push.fetch_git`) and the typed TS consumer; the ws_push base-awareness fix correctly closes the two-transport divergence (verified: `fetch_git` now threads `base`/`remote` exactly as `get_git_all` does); the AC3 fail-loud warning is sound and sanitized. It is rejected on ONE issue that goes to the story's own purpose — an honest type contract — plus a lint that would fail CI.

**Data flow traced:** repos.yaml `default_branch`/`remote_name` → `_get_repos_config` (RepoConfig entries) → `get_git`/`get_git_all`/`fetch_git` → `_get_git_info(base, remote)` → git argv `HEAD..{remote}/{base}` (single argv token; `[SEC]` confirmed no injection — list-form `subprocess.run`, no `shell=True`, a malicious `remote_name` only fails refname resolution → `None`). JSON field `baseBehind` → HTTP JSONResponse + WS payload → web `GitRepo.baseBehind` (typed; no component displays it). Safe end-to-end at runtime.

### Blocking findings

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] `[TYPE]` `[RULE]` | **F1 — `RepoConfig(TypedDict, total=False)` is a dishonest contract.** `total=False` marks ALL four keys optional, but `name`/`path` are ALWAYS present (both the repos.yaml path and the fallback set them); the docstring itself says so. `{}` type-checks as a valid `RepoConfig`, and callers do direct subscript `repo["name"]`/`repo["path"]` (`get_git_all` L419/L425, `fetch_git`) which the annotation makes unsound. This is the SAME defect class the story exists to fix (a type that lies about its shape) — corroborated independently by `reviewer-type-design` (high) and `reviewer-rule-checker` (high, under SOUL #14 honest-contracts, which cannot be dismissed). AC2's headline requirement is "accurately describe the return shape"; `total=False` does not, even though the AC offered it as one mechanism. | `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py:303` | Split into a required base + optional extension so `name`/`path` are required and `base`/`remote` optional: `class _RepoConfigBase(TypedDict): name: str; path: str` then `class RepoConfig(_RepoConfigBase, total=False): base: str; remote: str`. (Python 3.11+ `Required[]` markers are an equivalent alternative.) |
| [HIGH] `[preflight]` | **F5 — ruff `I001` unsorted/unformatted import block** (would fail a CI ruff gate). | `pennyfarthing-dist/src/pf/tests/test_162_87_data_proxy_polish.py:46` | `ruff check --fix` the file (import-block ordering). |

### Non-blocking findings

- **F2 `[TYPE]` (Low):** `root: RepoConfig | dict[str, str] | None` has a redundant `dict[str, str]` arm — with `total=False`, `{}` already satisfies `RepoConfig`. Folds into F1's fix: once `name`/`path` are required, simplify to `root: RepoConfig | None` (treat the empty-repos edge via `.get()` fallbacks). Apply alongside F1. `data_proxy.py:381`.
- **F3 `[TEST]` (Medium, deferred → follow-up):** `test_get_git_warns_on_empty_repos_config` uses a weak `"root" in msg or "repos" in msg` disjunction — asymmetrically weaker than its sibling's `"root"`-only assertion, so the two edge cases could silently diverge. Tighten to pin `"root"`. `test_162_87_data_proxy_polish.py:280`.
- **F4 `[TEST]` (Medium, deferred → follow-up):** AC2 tests always supply `default_branch`/`remote_name`, so the `or "develop"`/`or "origin"` default-fill path (repos.yaml entry present but omitting a key) is untested — a regression hardcoding `""` would pass. Add a fixture omitting those keys asserting `base=="develop"`/`remote=="origin"`. `data_proxy.py:345-348`.

### Rule Compliance (python lang-review + SOUL/CLAUDE)

Cross-checked against `reviewer-rule-checker` (17 rules, 48 instances):
- **#1 silent-exceptions:** COMPLIANT — AC3 converts a silent fallback into a loud `warnings.warn` before degrading; no new swallowing. `[SILENT]` confirmed first-hand.
- **#3 type-annotations:** boundary handlers annotated; `_get_repos_config` improved to `list[RepoConfig]` — but the TypedDict itself is imprecise (F1).
- **#4 logging:** COMPLIANT — `data_proxy`/`ws_push` use the established `warnings.warn` fail-loud pattern (they don't import `logging`); AC3 warning uses it correctly.
- **#5 path-handling / #8 unsafe-deserialization:** COMPLIANT — `pathlib` + `encoding="utf-8"`; `yaml.safe_load` unchanged.
- **#6 test-quality:** COMPLIANT on assertions (AC1/AC4 mutation-probe + presence/absence dual-assert verified real; mock target `subprocess.run` correct for both modules); F3/F4 are hardening gaps, not vacuous assertions.
- **#9 async-pitfalls / #11 input-validation:** COMPLIANT — no new blocking calls; base/remote are operator config, not network input. `[SEC]` clean.
- **#16 CLAUDE.md TS boundary:** COMPLIANT — `web/` changes are type-only field renames, no logic, no import changes.
- **SOUL #14 honest-contracts:** VIOLATION → F1.
- **160-18/160-22 sanitized messages:** COMPLIANT — AC3 warning interpolates only `len(repos)` (int) + static text; no paths/usernames/content.

### Disabled-domain first-hand coverage
- `[EDGE]` — Root resolution: `.`-repo found → no warning; none-at-`.` → warn + `repos[0]`; empty `repos` → warn + `{}` → `.get()` defaults. All boundaries handled; base/remote embedded as a single argv token (no flag/edge leakage). VERIFIED `data_proxy.py:380-402`.
- `[SILENT]` — AC3 is a net fail-loud improvement; no swallowed errors introduced. VERIFIED.
- `[DOC]` — Docstrings updated honestly (AC2), ws_push comment explains the two-transport fix, no stale `developBehind`/"deferred follow-up" prose remains. One doc/type mismatch: the RepoConfig docstring asserts name/path "always present" while `total=False` says otherwise → that mismatch IS F1.
- `[SIMPLE]` — Change is minimal and non-over-engineered; the only simplification is F2 (redundant union arm), folded into F1.

### Devil's Advocate

Argue this is broken. **Malicious/odd repos.yaml:** a `remote_name` of `--upload-pack=evil` or `; rm -rf ~` — does it escape? No: `f"HEAD..{remote}/{base}"` is one f-string → one argv element in a list-form `subprocess.run` (no `shell=True`); git treats it as a single (bad) revision range, fails resolution, `_run` returns `None`, `baseBehind` is `None`. No shell, no flag injection. repos.yaml is operator-owned local config anyway. **Confused operator:** declares three repos, none at `.` — pre-change this silently probed `repos[0]`'s base; now it warns loudly (the AC3 improvement). Good. **Empty `repos: {}`:** `_get_repos_config` returns `[]` → `get_git` warns, `root={}`, `.get("base","develop")` → probes `origin/develop`; degraded but announced. **Stressed filesystem / unreadable repos.yaml:** caught by the pre-existing `_get_repos_config` except → warns (sanitized) → single-repo fallback. **Type-checker's view (the real bug):** `total=False` tells mypy/pyright every `repo["path"]` MIGHT KeyError and `{}` is a valid `RepoConfig` — the annotation actively misdescribes the runtime invariant. On a story whose sole purpose is an honest `_get_repos_config` contract, shipping a type that lies about name/path being optional reproduces the exact defect class 162-71 flagged. That is why F1 blocks: not a runtime crash, but a broken promise on the deliverable itself, cheap to fix correctly. **Web skew:** a consumer running an old web bundle expecting `developBehind` against a new server sending `baseBehind` — mitigated because they ship together in one release and no component reads the field today; noted, not blocking.

**Handoff:** Back to Sergeant B.A. Baracus (Dev) for rework (green). Per-finding disposition required on return (FIXED/DEFERRED each).

## Review Correlation

| # | Source | Finding | Classification | Checklist Check | Action |
|---|--------|---------|---------------|-----------------|--------|
| 1 | internal | F1: RepoConfig(total=False) marks name/path optional but they're always present | EXISTING_CHECK | python-review #3 type-annotations (SOUL #14 honest-contracts) | FIXED: Split into _RepoConfigBase (required) + RepoConfig (optional extension) |
| 2 | internal | F2: Redundant dict[str, str] union arm with total=False RepoConfig | EXISTING_CHECK | python-review #3 type-annotations | FIXED (by F1): Now accurate with required name/path |
| 3 | internal | F3: test_get_git_warns_on_empty_repos_config assertion too weak | EXISTING_CHECK | python-review #6 test-quality | DEFERRED: Follow-up story to tighten assertion |
| 4 | internal | F4: AC2 default-fill path (_or "develop"_/_or "origin"_) untested | EXISTING_CHECK | python-review #6 test-quality | DEFERRED: Follow-up story to add fixture coverage |
| 5 | internal | F5: ruff I001 unsorted import block would fail CI | TOOLING | N/A | FIXED: ruff check --fix applied to test_162_87_data_proxy_polish.py |

### Signal Summary
- **Internal findings: 5** (all from Reviewer Assessment)
- **New checks added: 0** (all findings map to existing checklist rules)
- **Existing checks violated: 2** (F1, F2 → #3 type-annotations; F3, F4 → #6 test-quality)
- **Tooling gaps: 1** (F5 → ruff CI config)

## Subagent Results

**Cycle: 1**

**Method:** targeted re-verification by the Reviewer of each cycle-0 finding against the rework diff (`61dcef3f1`). No fresh generalist subagent sweep — the cycle-0 characterizations are precise, so targeted probes are the stronger evidence (per the re-review protocol). Working-tree audit: `pf reviewer audit-tree` DIRTY on orchestrator-repo files only (`.pennyfarthing/sidecars/sm/patterns.md` pre-existing, `sprint/epic-162.yaml` written by the `--review-verdict` bookkeeping, `sprint/context/context-story-162-87.md` sm-setup artifact) — the KNOWN false positive; reviewed repo `pennyfarthing/` verified clean (`git -C pennyfarthing status --porcelain` empty). `git clean -fd` NOT run.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (re-verified) | clean | F5 fixed | confirmed fixed |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes (re-verified) | findings | F3, F4 deferred | deferred 2 (follow-up) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes (re-verified) | clean | F1 fixed, F2 folded | confirmed fixed |
| 7 | reviewer-security | Yes (re-verified) | clean | none | N/A |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes (re-verified) | clean | F1 fixed (SOUL #14 compliant) | confirmed fixed |

**All received:** Yes (5 enabled re-verified, 4 disabled via settings)
**Total findings:** 0 outstanding blocking — F1/F2/F5 FIXED; F3/F4 deferred to follow-up

## Reviewer Assessment

**Verdict:** APPROVED (cycle-1 re-review; supersedes the round-1 REJECTED verdict)

The single blocking finding is resolved and the CI-breaking lint is cleared. Targeted re-verification against rework commit `61dcef3f1`:

- **F1 `[TYPE]` `[RULE]` — FIXED.** `RepoConfig` is now a two-level TypedDict: `class _RepoConfigBase(TypedDict)` declares required `name`/`path`; `class RepoConfig(_RepoConfigBase, total=False)` adds optional `base`/`remote`. Verified at `data_proxy.py:303-323`. The contract is now honest: `name`/`path` required, `base`/`remote` optional, `{}` is no longer a valid `RepoConfig`, and the direct `repo["name"]`/`repo["path"]` subscripts in `get_git_all`/`fetch_git` are type-safe. This satisfies AC2's "accurately describe the return shape" and clears the SOUL #14 honest-contract violation that both `reviewer-type-design` and `reviewer-rule-checker` flagged.
- **F2 `[TYPE]` — FIXED (by F1).** With `name`/`path` now required, `{}` no longer satisfies `RepoConfig`, so the `root: RepoConfig | dict[str, str] | None` union arm is a meaningful signal for the empty-repos fallback (exactly as reviewer-type-design predicted). Annotation is now accurate.
- **F5 `[preflight]` — FIXED.** `ruff check` passes clean on `data_proxy.py`, `ws_push.py`, and `test_162_87_data_proxy_polish.py` (re-run this cycle).
- **F3 `[TEST]`, F4 `[TEST]` — DEFERRED to follow-up** (Medium, non-blocking): tighten the empty-repos warning assertion; add AC2 default-fill coverage. Recorded for SM to file.

**Regression re-confirm:** story + regression tests 65/65 (incl. story file 11/11 this cycle); `[SEC]` unchanged (clean — no injection, sanitized warning); `[SILENT]` AC3 fail-loud intact; `[DOC]` docstrings now fully honest (the RepoConfig docstring/type mismatch that WAS F1 is gone); `[SIMPLE]`/`[EDGE]` unaffected by the type-only rework.

**Data flow (unchanged, re-confirmed safe):** repos.yaml → `_get_repos_config` (typed `list[RepoConfig]`) → git routes → `_get_git_info(base, remote)` → single-token git argv → `baseBehind` in HTTP + WS payloads → typed web consumer.

**Handoff:** To Lieutenant Templeton "Faceman" Peck (SM) for finish-story.
- **Deferred to follow-up: 2** (F3, F4 per Reviewer disposition)