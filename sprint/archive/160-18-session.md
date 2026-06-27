---
story_id: "160-18"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-18: Frame fail-loud sweep: sanitize the warnings sink before any network exposure

## Story Details
- **ID:** 160-18
- **Jira Key:** (not in Jira)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch Strategy:** gitflow (feat/160-18-frame-warnings-sink-sanitize)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-27T08:47:07Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-27T08:19:29Z | 2026-06-27T08:19:29Z | immediate |
| red | 2026-06-27T08:19:29Z | 2026-06-27T08:34:47Z | 15m 18s |
| green | 2026-06-27T08:34:47Z | 2026-06-27T08:39:37Z | 4m 50s |
| review | 2026-06-27T08:39:37Z | 2026-06-27T08:47:07Z | 7m 30s |
| finish | 2026-06-27T08:47:07Z | - | - |

## Technical Approach

### Audit Scope
The task is to audit all `warnings.warn(...)` call sites added/touched by stories 160-4, 160-12, 160-15, and 160-16 in the Frame/data_proxy code path. This arose from a Reviewer finding in 160-16 that identified potential information leaks in warning messages.

### Risk
Each warning that interpolates a raw exception (`{exc}` / `str(exc)`) or a local filesystem path (e.g. `repo_path`) is a **low-severity info-leak risk** IF Frame ever forwards warnings to a network client. Frame's current architecture routes warnings to stderr only, but the safety boundary should be explicit to prevent future regressions.

### Remediation Strategy
For each problematic warning site:
1. **Option A:** Emit `type(exc).__name__` plus a fixed human description instead of the raw exception text/path (behavior change — removes the info leak surface).
2. **Option B:** Confirm and document via code comment that the warnings sink is stderr-only and never network-forwarded (assertion/documentation, no behavior change).

**Preference:** Apply both where feasible — safer typing + defensive comment explaining the boundary.

## Acceptance Criteria
- [ ] All `warnings.warn(...)` call sites in Frame/data_proxy touched by 160-4, 160-12, 160-15, 160-16 are audited.
- [ ] Each warning that leaks raw exception text or filesystem paths is either:
  - Rewritten to emit `type(exc).__name__` + fixed description, OR
  - Documented with a defensive comment asserting stderr-only sink + no network exposure.
- [ ] Code review confirms no raw exception/path material reaches network consumers.
- [ ] All changes integrate cleanly into the 160-* fail-loud epic narrative.

## Sm Assessment

**Routing decision:** Story 160-18 selected as next work (p1, 2pt, tdd/phased). Chosen over the CLI picker's p2 default (155-5) because the explicit priority field ranks it higher and it continues the Frame fail-loud sweep momentum from recently-landed 160-17/20/21. User confirmed selection.

**Scope handed to TEA (Lord Melchett, red phase):** Audit every `warnings.warn(...)` site added or touched by stories 160-4, 160-12, 160-15, 160-16 in the Frame/`data_proxy` path. Identify warnings that interpolate raw exception text (`{exc}`/`str(exc)`) or local filesystem paths (`repo_path`) — these are the low-severity info-leak surface. Design failing tests that pin the remediation: either sanitized output (`type(exc).__name__` + fixed description) or a documented/asserted stderr-only sink that is never network-forwarded.

**Setup verified:** session file created, fields set (workflow tdd, phase red, epic 160), story + epic context written, branch `feat/160-18-frame-warnings-sink-sanitize` created off `develop` in the pennyfarthing repo. Merge gate clear (no open PRs). No Jira (local-only sprint).

**Handoff:** → TEA for the RED phase.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Security/behavior change to 5 warning sites — needs failing tests pinning the sanitization contract.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_18_warning_sink_sanitization.py` — 6 tests across the 5 `data_proxy.py` warn sites + a fix-agnostic AST guard.

**Tests Written:** 6 tests
**Status:** RED (verified — all 6 fail on `AssertionError` against current code; file collects clean)

**Threat-model finding (drives the strategy):** Frame does **not** currently forward Python warnings to any network client — verified: the only `catch_warnings`/`showwarning` in `pf/` is in `sprint/validator.py` (unrelated YAML capture). Default sink is stderr. So this is **preventive/defense-in-depth**, exactly as the story frames it. I pinned **Option A (sanitize at source)** rather than Option B (document stderr-only) because Option B is untestable (can't cheaply assert "no *future* code forwards warnings") and fragile (Frame already ships an OTLP/WebSocket surface). See Design Deviations.

**The contract each test pins:** on an induced failure, the warning (1) still fires (fail-loud preserved), (2) still names its subject (git/repos/theme/jira/gh), (3) contains `type(exc).__name__`, (4) does NOT contain `str(exc)` (sentinel), and (5) for the git site does NOT contain `repo_path`. Degrade behavior (None/{}/single-repo-fallback/field-None) asserted unchanged.

**DESIGNED INTERFACE for Dev (Baldrick):** add a tiny module-level summariser to `data_proxy.py` — e.g. `def _safe_exc(exc: Exception) -> str: return type(exc).__name__` — and route all 5 warns through it, dropping `repo_path` entirely at L194 (the fixed filename `{p.name}` at L225 is non-sensitive and may stay). Full spec in the test file's module docstring. The AST guard passes once each leak is a `_safe_exc(exc)`/`type(exc).__name__` expression (Call/Attribute, not a bare Name).

### Rule Coverage

| Rule (python.md) | Test(s) | Status |
|------|---------|--------|
| #4 logging — never emit sensitive data | all 6 (no raw `str(exc)`/path in sink) | failing |
| #5 path handling — no path info-leak (CWE-22-adjacent) | `test_git_info_warning_drops_repo_path_and_raw_exc` | failing |
| #1 silent-exception — fail-loud not regressed to silence | 5 behavioral tests (`pytest.warns` required) | failing |
| #11 security — info-leak at boundary | all 6 + AST guard | failing |
| #13 fix-regressions — no over-correction (subject kept, degrade unchanged) | green guards inside each behavioral test | failing |
| #6 test quality — meaningful assertions, no vacuous | self-check (below) | n/a |

**Rules checked:** 5 of 13 applicable lang-review rules have test coverage (others — mutable defaults, async, deserialization, deps, imports — N/A to this change).
**Self-check:** 0 vacuous tests. Every test asserts specific message content + concrete degrade values; the AST guard asserts an empty computed offenders list.

**Handoff:** To Dev (Baldrick) for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` — added `_safe_exc(exc) -> type(exc).__name__` helper; routed all 5 warning sites through it. The git-info warn (L194) now drops `repo_path` entirely; repos/theme/jira/gh warns drop the raw `{exc}` while keeping their subject. Each kept its `stacklevel=2` and its surrounding catch-all/degrade behavior.

**Implementation notes (matches TEA's designed interface exactly):**
- `_safe_exc` emits only `type(exc).__name__` — the "fixed description" is the existing message prefix (e.g. "Failed to parse git info"), satisfying "type(exc).__name__ + fixed description".
- Git site: `f"Failed to parse git info ({_safe_exc(exc)})"` — no path, no raw exc.
- Repos site: `f"Failed to load repos config {p.name} ({_safe_exc(exc)})"` — `{p.name}` is the fixed filename `repos.yaml` (non-sensitive), per TEA's note.
- Theme/jira/gh: `f"... ({_safe_exc(exc)})"`.
- No imports added/removed (`warnings` already imported; `_safe_exc` is new and used) → ruff clean.

**Tests:** 6/6 passing (GREEN) — verified by direct scoped run. **90/90** regression batch green (`test_160_16_fail_loud_3.py` + `test_160_17_fail_loud_4.py` + `test_frame_routes.py`) — the sanitized messages keep their subject words so the prior `pytest.warns(match=...)` assertions still pass. `ruff check` clean.
**Branch:** `feat/160-18-frame-warnings-sink-sanitize` (pushed to origin)

**Handoff:** To Reviewer (Captain Darling) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 1 (low) | confirmed 1 (low test-hygiene), dismissed 0, deferred 0 |
| 2 | reviewer-edge-hunter | No | Skipped — disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | No | Skipped — disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | No | Skipped — disabled | N/A | Disabled via settings (test quality verified by Reviewer directly) |
| 5 | reviewer-comment-analyzer | No | Skipped — disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | No | Skipped — disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 4 | confirmed 4 (1 low in-scope, 3 out-of-scope/deferred), dismissed 0, deferred 3 |
| 8 | reviewer-simplifier | No | Skipped — disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | No | Skipped — disabled | N/A | Disabled via settings (rule compliance verified by Reviewer directly — see Rule Compliance) |

**All received:** Yes (2 enabled subagents returned; 7 disabled via `workflow.reviewer_subagents` and pre-filled as Skipped)
**Total findings:** 5 confirmed (1 low in-scope code, 1 low test-hygiene, 3 deferred out-of-scope), 0 dismissed, 3 deferred

## Reviewer Assessment

**Verdict:** APPROVED

**Subagent dispatch (all 8 tags):**
- `[EDGE]` — N/A (edge_hunter disabled). I checked boundary cases myself: `_safe_exc` cannot raise (`type().__name__` is always a str); `exc` is always bound by `except ... as exc`.
- `[SILENT]` — N/A (silent_failure_hunter disabled). Verified directly: no `except` was regressed to silence; every warn still fires (security subagent's 5/5 fail-loud check corroborates).
- `[TEST]` — N/A (test_analyzer disabled). Verified directly: tests assert specific message content + a fix-agnostic AST guard; non-vacuous. One LOW fixture-coupling note (below).
- `[DOC]` — N/A (comment_analyzer disabled). The 5 touched comments accurately describe the sanitisation; the `_safe_exc` docstring states the threat model.
- `[TYPE]` — N/A (type_design disabled). `_safe_exc(exc: Exception) -> str` is fully annotated; no stringly-typed regressions.
- `[SEC]` — **ACTIVE.** 4 findings: 1 LOW in-scope (`_safe_exc` dynamic-name edge), 3 out-of-scope deferred (`get_context` L322, `get_project_info` L466, `get_git_all` L274). None block this PR's scope (the 5 warnings.warn sites).
- `[SIMPLE]` — N/A (simplifier disabled). The change is minimal (one 2-line helper + 5 one-line call rewrites); no over-engineering.
- `[RULE]` — N/A (rule_checker disabled). Rule compliance verified directly — see Rule Compliance section.

**Observations:**
1. `[VERIFIED]` All 5 `data_proxy.py` `warnings.warn` sites now route through `_safe_exc(exc)` → `type(exc).__name__`; `repo_path` is dropped entirely from the git-info warn. Evidence: diff hunks for `_get_git_info`, `_get_repos_config`, `get_theme_agents`, `_get_identity` (jira + gh). Complies with python.md #4 (no sensitive data in observable sink) and #11 (no path to network consumer).
2. `[VERIFIED]` Fail-loud preserved — every `except` still calls `warnings.warn`; no regression to silent `pass`. Degrade behavior (None / `{}` / single-repo fallback / field-None) unchanged. Complies with python.md #1. Evidence: my read + security subagent 5/5 fail-loud-preserved check + 96/96 tests green.
3. `[VERIFIED]` `p.name` retention in `_get_repos_config` is safe — both candidates are `.../repos.yaml`, so `p.name` is the constant filename `"repos.yaml"`, never user/path data. Evidence: data_proxy.py:202-205 candidates list.
4. `[VERIFIED]` The AST guard `test_no_data_proxy_warning_interpolates_raw_exc_or_path` scans the *live* module for any `warnings.warn` interpolating a bare `exc`/`repo_path` — a durable regression net catching future un-sanitised warns, not a one-shot point test. Evidence: test file Bucket E.
5. `[SEC][LOW]` `_safe_exc` dynamic-exception-name edge (data_proxy.py:~50): `type(exc).__name__` could leak if a dynamically-named exception class encoded data in its name (e.g. `type("TokenError_sk_live_x", (Exception,), {})`). Negligible — stdlib + pf-internal exceptions have static identifiers. Confirmed at LOW; acceptable documented risk per the current threat model. Non-blocking.
6. `[SEC][LOW][TEST]` The `_reset_identity_cache` fixture couples to private module globals (`_identity_cache`/`_identity_cache_time`); a rename would silently stop clearing the cache. Bounded — the behavioral `pytest.warns` asserts would then fail loudly. Non-blocking (preflight note, corroborated).
7. `[SEC][DEFERRED — OUT OF SCOPE]` `get_context` (data_proxy.py:322) returns `str(e)` in the `/api/context` JSONResponse body — a live network info-leak (CWE-209). NOT a `warnings.warn` site, NOT changed by this PR, and explicitly story **160-19**'s territory (the get_context swallow). Confirmed real (I read L316-322); deferred, already captured as a TEA Delivery Finding. Does not block this scoped PR.
8. `[SEC][DEFERRED — OUT OF SCOPE]` `get_project_info` (data_proxy.py:466) returns the raw absolute `project_dir` (e.g. `/Users/<name>/...`) unconditionally in the response body — pre-existing leak, NEW finding from the security subagent (TEA/Dev had not flagged it). Confirmed real (I read L460-466). Out of scope (response-body sink, not warnings); captured as a new Delivery Finding for a follow-up.

**Data flow traced:** an induced failure inside `_get_git_info` → `except Exception as exc` → `warnings.warn(f"Failed to parse git info ({_safe_exc(exc)})")` → message contains only `"Failed to parse git info (ValueError)"`; the `repo_path` and `str(exc)` never reach the sink. Safe because `_safe_exc` collapses the exception to its type name and the path argument is no longer interpolated.

**Pattern observed:** centralised sanitiser (`_safe_exc`) reused at every sink — good single-source pattern (SOUL #2), consistent with the 160-16/17 fail-loud helpers. data_proxy.py:45-55.

**Error handling:** unchanged and correct — all handlers remain catch-all-then-degrade (defensible for async routes / the poll loop where any escape is a 500 / blank panel). No new failure paths introduced.

### Rule Compliance (python.md lang-review)

| Rule | Applies to | Verdict |
|------|-----------|---------|
| #1 silent exception swallowing | 5 `except` blocks (unchanged) | PASS — warns preserved, no new swallow |
| #3 type annotations at boundaries | `_safe_exc(exc: Exception) -> str` | PASS — fully annotated |
| #4 never emit sensitive data (observable sink) | 5 sanitised warns | PASS (type name only). Out-of-scope `get_context`/`get_project_info` response bodies violate #4 → deferred findings, not this PR's sink |
| #5 path handling | git-info warn (repo_path), repos read | PASS — `repo_path` dropped; `encoding="utf-8"` already present (160-16); no new string-path concat |
| #6 test quality | new test file | PASS — specific assertions + AST guard, 0 vacuous; 1 LOW fixture-coupling note |
| #11 info-leak at boundary | the 5 warnings (PR scope) | PASS. Response-body sinks (`get_context`, `get_project_info`, `get_git_all`) are untouched + out of scope → deferred |
| #13 fix-introduced regressions | the sanitisation diff | PASS — subject preserved, degrade unchanged, 96/96 tests green, ruff clean |
| #2,#7,#8,#9,#10,#12 | — | N/A (no mutable defaults / resources / deserialization / async / deps changes) |

### Devil's Advocate

Suppose this PR is broken. The most damaging claim: it *advertises* a security fix while leaving the worst leak in the same file untouched. `get_context` ships `str(e)` straight into an HTTP response body — a strictly worse channel than a stderr warning — and `get_project_info` hands every client the user's absolute home path. A cynic says: the PR sanitised the *theoretical* sink (warnings Frame doesn't even forward today) and ignored the two *actual* network-exposed sinks three functions away. Is the story therefore incomplete? I weighed this hard. The answer is no for THIS PR: the story's AC is explicitly scoped to "all `warnings.warn` call sites" — the response-body sinks are a different mechanism, `get_context` is the literal subject of the already-queued 160-19, and `get_project_info` is a genuinely separate pre-existing bug. Holding a clean, correct, well-tested scoped change hostage to adjacent unrelated leaks would be scope creep with its own untested risk — the exact anti-pattern the sidecars warn against. But I am NOT letting them slip: both are confirmed and routed to follow-ups. Second attack: does sanitisation break debuggability? Losing `str(exc)` means a developer reading stderr sees "Failed to load repos config repos.yaml (ScannerError)" without the line/column — mildly worse for local triage. Acceptable: the type + subject still localise the fault, and the security gain is durable. Third attack: could `_safe_exc` itself be the leak? Only if an exception class is dynamically named with secret data — negligible, and noted LOW. Fourth: a confused future dev adds a new raw-`{exc}` warn — the AST guard test catches it. Fifth: did the warn get silently dropped under the multi-line reformat at the repos site? No — verified the warn still fires (test + 96/96 green). The PR survives the assault for its scope.

**Handoff:** To SM (Edmund Blackadder) for finish-story. Two out-of-scope info-leak findings (`get_project_info` absolute-path, `get_context` → 160-19) are captured for follow-up — recommend SM file/fold them after this PR lands (avoid the epic-YAML id-collision trap of adding stories pre-merge).

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->
### TEA (test design)
- **Gap** (non-blocking): `get_context` (`data_proxy.py:305`) puts `str(e)` directly into the `/api/context` JSON **response body** — a *live, currently network-exposed* info-leak (strictly worse than the theoretical warnings leak this story fixes). It is OUT OF SCOPE here (response body, not the warnings sink) and overlaps story **160-19** (the get_context swallow). Affects `pf/frame/routes/data_proxy.py` get_context except-handler (sanitize `error` before returning, or fold into 160-19). *Found by TEA during test design.*
- **Improvement** (non-blocking): `ws_push.py` has the SAME warnings-leak class outside this story's data_proxy scope — `{path.name}` (L66/88), `{exc}` (L446/520), `{agent_name}` (L502). The `_safe_exc` helper Dev introduces should live somewhere reusable so a follow-up can sweep ws_push too. Affects `pf/frame/ws_push.py`. Recommend a sibling follow-up story. *Found by TEA during test design.*
### Dev (implementation)
- No new upstream findings during implementation. TEA's two findings stand: (1) `get_context` (L305) leaks `str(e)` into the `/api/context` response body — recommend folding into **160-19**; (2) `ws_push.py` same-class warn leaks — sibling follow-up. I scoped `_safe_exc` as a private helper in `data_proxy.py` (minimal, matches the story scope); a follow-up sweeping ws_push should promote it to a shared module (e.g. `pf/frame/__init__` or a small `frame/safe.py`). *Found by Dev during implementation.*
### Reviewer (code review)
- **Gap** (non-blocking): `get_project_info` (`data_proxy.py:466`) returns the raw absolute `project_dir` (e.g. `/Users/<name>/Projects/...`, leaking the OS username + filesystem layout) unconditionally in the `/api/project-info` JSON **response body** — a pre-existing info-leak (CWE-22-adjacent), NOT a `warnings.warn` site, so OUT OF SCOPE for 160-18. NEW finding (surfaced by reviewer-security; not previously flagged). Affects `pf/frame/routes/data_proxy.py` get_project_info (return `Path(project_dir).name` or omit `path`). Recommend a follow-up story (same info-leak theme). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `get_git_all` (`data_proxy.py:274`) returns the repo-relative `path` from repos.yaml to the client, disclosing internal topology — low severity (relative paths, Frame is localhost/IDE-sidebar). Bundle into the same response-body sanitization follow-up as get_project_info. *Found by Reviewer during code review.*
- **Confirmation** (non-blocking): `get_context` (`data_proxy.py:322`) `str(e)` in the response body — verified real; already captured by TEA. Recommend folding into story **160-19** (the get_context swallow) rather than a separate story. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->
### TEA (test design)
- **Pinned Option A (sanitize) over Option B (document stderr-only)**
  - Spec source: context-story-160-18.md (title), 160-16 Reviewer finding
  - Spec text: "emit type(exc).__name__ + fixed description, or confirm stderr-only sink"
  - Implementation: tests enforce sanitized messages at each call site; no test asserts "stderr-only"
  - Rationale: Option B is untestable (can't cheaply assert no *future* code forwards warnings) and fragile (Frame ships an OTLP/WebSocket surface one refactor from warning-forwarding). Verified Frame forwards no warnings today, so sanitizing at source is the durable, testable guarantee.
  - Severity: minor
  - Forward impact: Dev must add a sanitiser + edit 5 call sites, not just a comment.
- **Scoped tests to data_proxy.py; ws_push.py same-class leaks deferred**
  - Spec source: Sm Assessment scope, story title
  - Spec text: "in the Frame/`data_proxy` path"
  - Implementation: no tests cover ws_push.py's analogous warn leaks
  - Rationale: honor the story's data_proxy scope; ws_push logged as a Delivery Finding for a follow-up.
  - Severity: minor
  - Forward impact: ws_push.py sanitization remains a follow-up; recommend the `_safe_exc` helper be reusable.
- **Healthy/no-warn green guards not re-tested**
  - Spec source: prior art (`test_160_16_fail_loud_3.py`, `test_160_17_fail_loud_4.py`)
  - Spec text: those suites already assert healthy paths emit no warning
  - Implementation: this file tests only the sanitization delta on the failing paths
  - Rationale: avoid duplicating existing green-on-arrival coverage; the new tests still assert the warning STILL fires + degrade unchanged.
  - Severity: trivial
  - Forward impact: none.
### Dev (implementation)
- **Retained the pre-existing broad `except Exception` blocks (did not narrow)**
  - Spec source: story title / TEA designed interface; lang-review python.md #1 (broad except)
  - Spec text: "sanitize the warnings sink"; #1 prefers specific exception types
  - Implementation: only the `warnings.warn(...)` message inside each existing catch-all was changed; the `except Exception` lines are unchanged (not in my diff)
  - Rationale: these handlers feed async FastAPI routes (`get_git`/`get_git_all`/`get_theme_agents`) and the `_get_identity` probe (no outer guard) + the Frame poll loop — any escape is a 500 / blank panel, strictly worse than a warn. Consistent with the 160-16/160-17 prior art that added them. Narrowing is out of this story's scope (sanitization, not exception-type hardening).
  - Severity: minor
  - Forward impact: none — the broad excepts predate this PR; a future hardening story could narrow them.
- **`_safe_exc` scoped as a private helper in `data_proxy.py`, not a shared module**
  - Spec source: TEA designed interface ("a tiny module-level summariser to `data_proxy.py`")
  - Spec text: "add a tiny module-level summariser to data_proxy.py"
  - Implementation: `_safe_exc` is module-private to `data_proxy.py`
  - Rationale: minimal change matching the data_proxy-only story scope (SOUL: simplest code that passes). The ws_push follow-up (Delivery Finding) should promote it to a shared location when it reuses it.
  - Severity: trivial
  - Forward impact: the ws_push follow-up will relocate/duplicate the helper.

### Reviewer (audit)
- **TEA: Pinned Option A (sanitize) over Option B (document stderr-only)** → ✓ ACCEPTED by Reviewer: Option A is the durable, testable choice; Option B can't be asserted against future warning-forwarding. Aligns with SOUL #1.
- **TEA: Scoped tests to data_proxy.py; ws_push deferred** → ✓ ACCEPTED: honors story scope; ws_push captured as a Delivery Finding.
- **TEA: Healthy/no-warn green guards not re-tested** → ✓ ACCEPTED: already covered by 160-16/17; the new tests still assert warn-fires + degrade-unchanged.
- **Dev: Retained the pre-existing broad `except Exception` blocks** → ✓ ACCEPTED: narrowing is out of scope; the catch-alls are defensible for async-route/poll-loop contexts (any escape = 500/blank panel, strictly worse). The `except` lines are unchanged context, not introduced by this PR.
- **Dev: `_safe_exc` scoped as a private helper (not shared module)** → ✓ ACCEPTED: minimal, matches data_proxy-only scope; the ws_push follow-up should promote it.
- **No UNDOCUMENTED spec deviations found.** The two out-of-scope response-body leaks (`get_context`, `get_project_info`) are pre-existing bugs in untouched sinks, captured as Delivery Findings — not spec deviations of this PR.