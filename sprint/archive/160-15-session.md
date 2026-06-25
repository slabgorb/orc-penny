---
story_id: "160-15"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-15: ws_push fail-loud sweep part 2: extend warn-on-present-but-broken to remaining pre-existing silent swallows (fetch_git subprocess-parse, fetch_context degraded-shape, outer fetch_persona catch-all) + add L171 main-sprint-read behavioral test and read-vs-parse warning wording (from 160-12 Reviewer findings)

## Story Details
- **ID:** 160-15
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch Strategy:** gitflow (feat/160-15-ws-push-fail-loud-2)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-25T15:07:04Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-25T11:51:25Z | 2026-06-25T14:02:18Z | 2h 10m |
| red | 2026-06-25T14:02:18Z | 2026-06-25T14:21:04Z | 18m 46s |
| green | 2026-06-25T14:21:04Z | 2026-06-25T14:59:08Z | 38m 4s |
| review | 2026-06-25T14:59:08Z | 2026-06-25T15:07:04Z | 7m 56s |
| finish | 2026-06-25T15:07:04Z | - | - |

## Sm Assessment

**Story shape:** Direct follow-up to 160-12 (commit `c4de6fe0e` "feat(160-12): fail-loud read hygiene sweep across ws_push fetchers"). 160-12 introduced a "warn-on-present-but-broken" pattern — warn (not silently swallow) when data is *present but malformed*. This story extends that pattern to the remaining pre-existing silent swallows the Reviewer flagged.

**Source file:** `pennyfarthing-dist/src/pf/frame/ws_push.py`
**Predecessor tests:** `pennyfarthing-dist/src/pf/tests/test_160_12_ws_push_read_hygiene.py` — mirror its style for the new test file.

**Scope (3 swallows + 1 test + wording):**
1. `fetch_git` — subprocess-parse failures should warn when output is present-but-unparseable rather than swallow.
2. `fetch_context` — degraded-shape data should warn.
3. outer `fetch_persona` catch-all — the broad exception handler should warn on present-but-broken.
4. Add a behavioral test for the L171 main-sprint-read path (currently uncovered).
5. Refine warning wording to distinguish **read failures** from **parse failures** (read-vs-parse wording).

**Acceptance criteria (derived — no AC in YAML, title is authoritative):**
- `fetch_git`, `fetch_context`, and the outer `fetch_persona` catch-all warn on present-but-broken instead of silent swallow.
- A behavioral test covers the L171 main-sprint-read path.
- Warning messages distinguish read failures from parse failures.

**Routing:** 1pt but explicitly tagged `tdd` (phased) — respecting the YAML over the points heuristic since this adds behavioral tests. TEA writes RED tests first.

**Constraints:** pennyfarthing repo → gitflow, branch already cut off `develop`. Edit source at `pennyfarthing-dist/`, never `.pennyfarthing/`. Return result objects, no throws (SOUL #10). This story is itself a fail-loud sweep — fix the system (the swallow), not the symptom.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Behavioral fail-loud changes to four code paths (3 silent swallows + the L171 wording) — needs RED coverage, not a chore bypass.

**Test File:** (new)
- `pennyfarthing-dist/src/pf/tests/test_160_15_ws_push_fail_loud_2.py` — 9 tests across 4 buckets.

**Tests Written:** 9 (6 RED + 3 intentional GREEN regression guards).
**Status:** RED confirmed — **6 failed / 3 passed / 0 errored** via scoped `uv run pytest <file>` (NOT testing-runner / full suite — avoids the `test_git_utils` branch-leak, per the `scoped-red-run` pattern). Every RED fails for the right reason (5× "DID NOT WARN", 1× degraded-shape assertion from the wiring bug), not import/syntax.

### Coverage Map

| Bucket (swallow) | Test | Today | RED reason / guard |
|------------------|------|-------|--------------------|
| fetch_diffs subprocess-parse (`ws_push.py:~197`) | `test_diffs_subprocess_failure_warns_and_survives` | RED | DID NOT WARN |
| fetch_diffs (guard) | `test_diffs_healthy_emits_no_warning` | GREEN | no over-warning |
| fetch_context failure (`~425`) | `test_context_failure_warns_and_degrades` | RED | DID NOT WARN |
| fetch_context degraded-shape | `test_context_degraded_result_shape_warns` | RED | DID NOT WARN |
| fetch_context healthy/wiring | `test_context_healthy_returns_real_data_no_warning` | RED | degraded None-shape (TypeError wiring bug) |
| fetch_persona outer catch-all (`~489`) | `test_persona_load_failure_warns_and_degrades` | RED | DID NOT WARN |
| fetch_persona (guard) | `test_persona_no_match_emits_no_warning` | GREEN | no over-warning |
| main-sprint read-vs-parse (`~215`) | `test_main_sprint_parse_failure_warns_says_parse_and_survives` | RED | wording says "read" not "parse" |
| main-sprint read-side (guard) | `test_main_sprint_undecodable_read_failure_warns_and_survives` | GREEN | read-side wording preserved |

### Rule Coverage (lang-review/python.md)

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 silent exception swallowing | all 6 RED warn/degrade tests (file/subprocess I/O is user-controlled → must surface) | failing |
| #4 logging/surfacing on error paths | every warn test asserts a `UserWarning` (module convention = `warnings.warn`, accepted in 160-12) | failing |
| #6 test quality | self-check below; every test pairs `pytest.warns`/`recwarn` with a return-shape/identity assert | pass |

**Self-check (#6):** 0 vacuous tests. No `assert True`, no truthy-only `assert result`, no always-None asserts, no unexplained skips. The 3 GREEN guards are proven non-vacuous (the sibling 6 are RED on the same paths).

**Handoff:** To Dev (Reverend Mother) for GREEN. **Read the DESIGNED INTERFACE block in the test docstring** — `fetch_context` needs a ROOT-CAUSE wiring fix (`check_context(project_dir=project_dir)` directly), not just a warn, or it would warn-spam every 5s poll. See the blocking Delivery Finding.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — four fail-loud fixes (part 2 of the ws_push sweep):
  - `fetch_diffs` (`~197`): `except Exception: pass` → warn naming `repo['name']`, keep `finally: os.chdir`. A repo's diff subprocess/parse failure now surfaces instead of silently vanishing.
  - `fetch_context` (`~409`): root-cause wiring fix — dropped the bogus `ContextConfig(project_dir=...)` (raised `TypeError` on every call, hidden by the swallow → panel never showed real data), now calls `check_context(project_dir=project_dir)` directly, THEN warns on genuine failure/degraded shape.
  - `fetch_persona` (`~489`): outer `except Exception: return {}` → warn then degrade. The common no-persona state is an in-try early return, unaffected.
  - `fetch_sprint` main read (`~215`): split read-vs-parse wording — read/decode via `_read_text_file` ("Failed to read"), parse via inline `try` ("Failed to parse"). Preserves the `or {}` empty-file coercion.

**Tests:** 9/9 passing (GREEN) — `test_160_15_ws_push_fail_loud_2.py` (6 RED→GREEN + 3 regression guards held). Scoped run only (branch-leak avoidance). Regression batch `test_160_12_* test_160_4_* test_frame_* test_159_8_* test_161_1_*` = 326 passed. `ruff check ws_push.py` clean (no dead `ContextConfig` import).
**Branch:** feat/160-15-ws-push-fail-loud-2 (gitflow → develop)

**Handoff:** To Reviewer (Leto II) for code review.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)

- **Gap** (blocking): `fetch_context` is broken on EVERY call — `config = ContextConfig(project_dir=project_dir)` raises `TypeError` because `ContextConfig` has no `project_dir` field, and `check_context`'s first positional is `explicit_session` (it takes `project_dir` as a kwarg and builds its own config via `load_config`). The silent `except Exception: return {None-shape}` has hidden this, so the context panel has NEVER shown real data. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py:fetch_context` (call `check_context(project_dir=project_dir)` directly, drop the bogus `ContextConfig(...)`, THEN warn on genuine failure). This is the root cause behind the "degraded-shape" bucket and is required for the fail-loud warn to be meaningful (a warn without the wiring fix fires every 5s poll). *Found by TEA during test design.*
- **Improvement** (non-blocking): `fetch_git` delegates to `data_proxy._get_git_info`, whose OWN outer `except Exception: return None` (`pennyfarthing-dist/src/pf/frame/routes/data_proxy.py:187`) silently swallows subprocess-output PARSE errors (the `int(...)` conversions on `rev-list` output) — a repo then renders as branch="unknown"/clean=True with zero diagnostics. A sibling `_get_repos_config` (`data_proxy.py:211`) also swallows a malformed `repos.yaml`. Out of the ws_push file scope for this 1-pt story; a follow-up `data_proxy` fail-loud sweep should extend the treatment here. *Found by TEA during test design.*

### Dev (implementation)

- **Improvement** (non-blocking): The `data_proxy._get_git_info` (`pennyfarthing-dist/src/pf/frame/routes/data_proxy.py:187`) and `_get_repos_config` (`data_proxy.py:211`) outer `except Exception` swallows remain after this story — confirmed during implementation while wiring `fetch_diffs`/`fetch_git`. They are the natural "part 3" of the ws_push fail-loud sweep but live outside the ws_push file scope. Affects `data_proxy.py` (extend the warn-on-present-but-broken treatment to the subprocess-output `int(...)` parse and the `repos.yaml` parse). *Found by Dev during implementation. Re-affirms TEA's non-blocking finding above.*

### Reviewer (code review)

- **Improvement** (non-blocking): The inner `except Exception: pass` inside `fetch_persona`'s portrait-resolver block (`pennyfarthing-dist/src/pf/frame/ws_push.py` ~L497, labeled `# AC-3: graceful degradation`) is still a silent swallow — distinct from the OUTER catch this story hardened. It degrades an optional portrait, so it's lower-priority than the data_proxy swallows, but it is the same fail-loud class. Affects `ws_push.py` (a follow-up could warn-then-degrade here too). Corroborated independently by reviewer-preflight. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Re-affirms the TEA/Dev `data_proxy` follow-up (`_get_git_info`/`_get_repos_config` swallows) as the natural "part 3" of this sweep. Affects `data_proxy.py`. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)

- **"fetch_git subprocess-parse" swallow tested as `fetch_diffs` (the actual ws_push subprocess-parse-with-`pass` site)**
  - Spec source: context-story-160-15.md Title; 160-12 Reviewer finding
  - Spec text: "fetch_git (subprocess parse, `except Exception: pass`)"
  - Implementation: The RED test targets `fetch_diffs` (`ws_push.py:~197`) — the only `except Exception: pass` wrapping a subprocess+parse INSIDE ws_push.py. `fetch_git` itself has no try/except; it delegates to `data_proxy._get_git_info` (outside the ws_push file scope).
  - Rationale: The story is framed "**ws_push** fail-loud sweep part 2"; keeping the git bucket inside ws_push.py (where the literal `except Exception: pass` over subprocess-parse is `fetch_diffs`) preserves part 1's file scope (160-12). `_get_git_info`'s sibling swallow is captured as a follow-up Delivery Finding rather than widening blast radius for a 1-pt story.
  - Severity: minor
  - Forward impact: Dev hardens `fetch_diffs` (warn naming the repo); `_get_git_info` (data_proxy) is left for a follow-up.

- **`fetch_context` fix is a root-cause wiring fix, not just a warn**
  - Spec source: context-story-160-15.md Title ("fetch_context degraded-shape"); SOUL.md #1
  - Spec text: "extend warn-on-present-but-broken to ... fetch_context degraded-shape"
  - Implementation: `test_context_healthy_returns_real_data_no_warning` requires `fetch_context` to return REAL data on success. Today `ContextConfig(project_dir=project_dir)` raises `TypeError` on every call, so the degraded-shape is CONSTANT (panel never worked). The test forces Dev to call `check_context(project_dir=project_dir)` directly, then warn on genuine failure.
  - Rationale: A warn added without the wiring fix would fire on every 5s poll (the TypeError is constant) — fail-loud must surface a GENUINE failure, not a constant code bug (SOUL #1). The wiring fix is therefore in-scope for the fetch_context bucket.
  - Severity: minor (test design); the underlying bug is significant (see blocking Delivery Finding)
  - Forward impact: Dev fixes the `check_context` call, not only adds a warn.

- **3 tests are intentionally GREEN on HEAD (regression guards)**
  - Spec source: SOUL.md #6; AC (no over-warning / read-side preservation)
  - Spec text: "A genuinely absent/healthy input emits no read-failure warning; the read side keeps its wording."
  - Implementation: `test_diffs_healthy_emits_no_warning`, `test_persona_no_match_emits_no_warning`, `test_main_sprint_undecodable_read_failure_warns_and_survives` pass today and must STAY green post-fix.
  - Rationale: Per `ac-as-green-regression-guard` — preservation requirements are correctly green-on-arrival; forcing a spurious RED would be dishonest. Documented so Reviewer/gate know they are not vacuous (the sibling 6 are RED on the same paths).
  - Severity: minor
  - Forward impact: Dev must not over-warn on healthy/absent inputs, and must keep the READ-side wording ("read"/"decode") after the read-vs-parse split.

- **Fail-loud realized as `warnings.warn` + graceful degradation (not raise); read-vs-parse split keyed on "read"/"parse" verbs**
  - Spec source: 160-12 precedent (`_read_text_file`/`_read_yaml_file`); SOUL.md #10
  - Spec text: "read-vs-parse warning wording"
  - Implementation: Tests assert `pytest.warns(UserWarning)` + a graceful return (never a raised exception). The parse test matches `r"(?i)pars"`, the read test matches `r"(?i)(read|decod)"` — mirroring the module's existing `_read_yaml_file` ("Failed to parse {name}") / `_read_text_file` ("Failed to read {name}") wording. The malformed-YAML `ScannerError` text ("mapping values are not allowed here") contains no "pars", so the parse test is a clean RED on the current "read" wording.
  - Rationale: These run in the long-lived Frame poll loop whose outer `except Exception: pass` would swallow a raise and blank the panel — a warning is strictly better. Keying the wording assertion on the module's own established verbs keeps the contract faithful and fix-agnostic.
  - Severity: minor
  - Forward impact: Dev surfaces via `warnings.warn`; parse failures say "parse", read/decode failures say "read"/"decode".

### Dev (implementation)

- No deviations from spec. All four buckets implemented exactly as the TEA tests and DESIGNED INTERFACE block specify: `fetch_diffs` warns naming `repo['name']`; `fetch_context` got the root-cause wiring fix (`check_context(project_dir=...)`, `ContextConfig` dropped) then warns on genuine failure; `fetch_persona` outer catch-all warns then degrades to `{}`; `fetch_sprint` main read splits read-vs-parse wording by reusing `_read_text_file` (read side) plus an inline parse `try` — this PRESERVES the `or {}` empty-file coercion (no behavior change for empty files), unlike 160-12's wholesale `_read_yaml_file` swap.

### Reviewer (audit)

All five logged deviations audited; every one ACCEPTED. No undocumented deviations found.

- **TEA #1 — "fetch_git subprocess-parse" tested as `fetch_diffs`** → ✓ ACCEPTED by Reviewer: the only literal `except Exception: pass` over a subprocess+parse *inside ws_push.py* is `fetch_diffs`; `fetch_git` has no try/except and delegates to `data_proxy._get_git_info` (out of file scope). Scoping the git bucket to ws_push.py preserves 160-12's file scope and the data_proxy swallow is captured as a follow-up. Correct call.
- **TEA #2 — `fetch_context` root-cause wiring fix, not just a warn** → ✓ ACCEPTED by Reviewer: verified `ContextConfig` has no `project_dir` field (old call raised `TypeError` every poll), and `check_context(project_dir=...)` (`context_window.py:311`) is the correct API that builds its own config via `load_config`. Fixing the wiring (SOUL #1) before warning is mandatory — a warn over a constant code bug would fire every 5s. The fix restores a panel that never worked.
- **TEA #3 — 3 intentionally-GREEN regression guards** → ✓ ACCEPTED by Reviewer: independently reproduced via the inverse probe (revert source to origin/develop, keep new test file → 6 failed / 3 passed). The 3 guards (`..._diffs_healthy...`, `..._persona_no_match...`, `..._undecodable_read...`) hold on both develop and HEAD; the 6 behavioral tests are RED on develop. Non-vacuous, correctly green-on-arrival.
- **TEA #4 — `warnings.warn` + graceful degradation; read-vs-parse keyed on verbs** → ✓ ACCEPTED by Reviewer: matches the 160-12 module convention (`warnings.warn`, not `logging`) and the long-lived poll loop's need to never raise (outer `except Exception: pass` would blank the panel). Keying the assertion on the message prefix verb ("parse"/"read") is faithful to the module's own `_read_yaml_file`/`_read_text_file` wording.
- **Dev — "No deviations from spec."** → ✓ ACCEPTED by Reviewer: confirmed faithful to the DESIGNED INTERFACE. Notably the `fetch_sprint` read-vs-parse split reuses `_read_text_file` AND preserves the `or {}` empty-file coercion (no behavior change for empty files) — a cleaner choice than 160-12's wholesale `_read_yaml_file` swap, with no hidden deviation.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none in-scope (3 pre-existing swallows noted) | confirmed 0, deferred 1 (portrait inner swallow → follow-up) |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — edge analysis done by Reviewer (see Rule Compliance / Devil's Advocate) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — Reviewer did this analysis (story's core risk surface) |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings — Reviewer assessed test quality + ran inverse binding probe |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — Reviewer reviewed the new comments (accurate, cite gh #50/SOUL #1) |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — no type/signature changes in diff |
| 7 | reviewer-security | Yes | clean | 0 | confirmed 0 (info-leak/injection/CWE-22 all assessed not-a-finding) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — diff is minimal; import hygiene improved (ContextConfig removed) |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — Reviewer ran the python.md 13-check enumeration manually (see Rule Compliance) |

**All received:** Yes (2 enabled returned clean; 7 disabled pre-filled per `workflow.reviewer_subagents`)
**Total findings:** 0 confirmed blocking, 0 dismissed, 2 deferred (non-blocking follow-ups → Delivery Findings)

### Rule Compliance (lang-review/python.md — full 13-check enumeration)

Diff scope: `ws_push.py` (4 catch sites + 1 import removal) + new test file. Enumerated every changed construct against every applicable check.

| # | Check | Instances in diff | Verdict |
|---|-------|-------------------|---------|
| 1 | Silent exception swallowing | 4 catch sites (`fetch_diffs`, `fetch_sprint` parse, `fetch_context`, `fetch_persona`) | COMPLIANT — all now `warnings.warn` then degrade; the broad `except Exception` is RETAINED deliberately (narrowing the heterogeneous subprocess/attr/persona paths would risk a new class escaping → poll-loop crash, my `narrowed-exception-rewrite-lets-new-class-escape` gotcha). Surfacing satisfies the anti-silent intent. |
| 2 | Mutable default args | 0 | N/A |
| 3 | Type annotation gaps | 0 signature changes | COMPLIANT (all fetchers keep `-> dict[str, Any]`) |
| 4 | Logging coverage/correctness | 4 warn sites | COMPLIANT — module convention is `warnings.warn` (accepted 160-12), not the `logging` module; no sensitive data interpolated (repo name, filename basename, OS/YAML exc text) |
| 5 | Path handling | `_read_text_file(sprint_path)` reuse; `Path(project_dir,...)` | COMPLIANT — `encoding="utf-8"` preserved via helper; Path-join not string concat; no new `Path.resolve()` gap introduced (pre-existing profile unchanged) |
| 6 | Test quality | 9 tests | COMPLIANT — each pairs `pytest.warns`/`recwarn` with an exact return-shape assert; healthy test asserts exact dict `{12,345,"OK"}`; 0 vacuous; binding proven by inverse probe |
| 7 | Resource leaks | 0 new `open()`/conn | N/A |
| 8 | Unsafe deserialization | `yaml.safe_load(text)`; subprocess list-form | COMPLIANT — SafeLoader; no `shell=True` |
| 9 | Async pitfalls | 0 (changed fns are sync, run in executor) | N/A |
| 10 | Import hygiene | removed unused `ContextConfig`; runtime `from pf.context_window import check_context` | COMPLIANT — F401 cleared (ruff clean); runtime import intentional (avoids import cost) |
| 11 | Input validation at boundaries | `sprint_path` static suffix on env-var root | COMPLIANT — no untrusted path component; local self-authored config |
| 12 | Dependency hygiene | 0 dep changes | N/A |
| 13 | Fix-introduced regressions (meta) | undecodable-bytes / broad-catch | COMPLIANT — `_read_text_file` explicitly catches `UnicodeDecodeError` (a `ValueError`) so it cannot escape the read split; covered by `test_main_sprint_undecodable_read_failure_warns_and_survives`. Regression batch 326 passed. |

### Devil's Advocate

Let me argue this code is broken. **Warn-spam in the poll loop.** These fetchers run every 5 seconds forever; a warning that fires on a *constant* condition would flood the developer's stderr unboundedly. Does any new warn fire on a steady-state condition? I traced each: `fetch_context` was the dangerous one — but `check_context` (`context_window.py:311–390`) *returns* a `ContextResult` on the no-transcript / no-usage paths (it sets `result.error` and returns; it never raises), so the common empty-session poll returns data without warning. The old `ContextConfig(project_dir=...)` raised `TypeError` on *every* call — so ironically the pre-fix code is what would have warn-spammed had the warn existed; the wiring fix is exactly what prevents the flood. `fetch_persona`'s outer warn only fires on a genuine `load_persona` exception, not on the in-`try` early returns for the no-persona case. `fetch_diffs` warns only inside the per-repo `except`. So no steady-state spam.

**A confused user / malicious repos.yaml.** What if `repo['name']` is missing, or contains format-string metacharacters? `_get_repos_config` always synthesizes `{"name": ..., "path": ...}`, so `repo['name']` cannot `KeyError`. f-string interpolation happens once at the literal site; `warnings.warn` treats the result as an opaque string, so `{}`/`%s` in a repo name cannot trigger secondary expansion or injection (security subagent concurs).

**A stressed filesystem.** Undecodable bytes in `current-sprint.yaml`: the old single `try` caught `UnicodeDecodeError` (a `ValueError`) under `except Exception`; the new split routes the read through `_read_text_file`, which catches `(OSError, UnicodeDecodeError)` *explicitly*. This is precisely the class of bug where a fail-loud rewrite converts silent-drop into a crash — but here the undecodable case is covered by a passing green guard, and the parse case by a RED→GREEN test. A `chmod 000` sprint file raises `PermissionError` (an `OSError`) → caught by `_read_text_file` → warns "read" → degrades. A file deleted between `is_file()` and read (TOCTOU) → `FileNotFoundError` → `_read_text_file` returns None silently → empty shape. All graceful.

**What about partial diffs?** If `subprocess.run` succeeds but parsing raises midway, some entries may already be in `diffs` before the warn — but that partial-append behavior is pre-existing and unchanged by this diff; the warn strictly improves diagnostics. **Conclusion of the exercise:** the one real risk (poll-loop warn-spam) is structurally avoided by the wiring fix, and the one regression class (exception escaping a narrowed catch) is avoided by retaining the broad catch and by `_read_text_file`'s explicit `UnicodeDecodeError` handling. No new finding surfaced.

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** A tight, well-proven fail-loud sweep (part 2 of 160-12). Four previously-silent swallow paths in `ws_push.py` now surface diagnostics via the established `warnings.warn` convention and degrade gracefully, plus a genuine root-cause wiring fix for `fetch_context` (a panel that *never* showed real data). 9/9 tests GREEN, 326-test regression batch GREEN, ruff clean, working tree clean. No Critical/High issues.

**Observations (8, exceeds the 5 minimum):**

1. `[VERIFIED]` `fetch_diffs` now warns naming `repo['name']` instead of `except Exception: pass` — evidence: `ws_push.py:197–203`; `repo` always carries `name`/`path` (`data_proxy._get_repos_config:204–209`). Warn is in the per-repo `except`, `finally` restores cwd, loop continues → siblings still contribute. Complies with python.md #1.
2. `[VERIFIED]` `fetch_context` wiring fix is correct AND non-spamming `[SILENT]` — evidence: `check_context` (`context_window.py:311–390`) returns a `ContextResult` (sets `result.error`, never raises) on no-transcript/no-usage, so the common poll path returns real/default data with no warn; warn fires only on genuine exceptions. Old `ContextConfig(project_dir=...)` raised `TypeError` every call (root cause of the never-populated panel). Complies with SOUL #1.
3. `[VERIFIED]` `fetch_sprint` read-vs-parse split cannot let `UnicodeDecodeError` escape `[RULE]` (python.md #13) — evidence: `_read_text_file` (`ws_push.py:47–67`) catches `(OSError, UnicodeDecodeError)` explicitly and warns "read"; inline parse `except` warns "parse"; both degrade to the empty shape, never raise. Covered by `test_main_sprint_undecodable_read_failure...` (guard) + `test_main_sprint_parse_failure...` (RED→GREEN). Preserves `or {}` empty-file coercion.
4. `[VERIFIED]` `[TEST]` Tests bind to the fix — inverse probe: reverting `ws_push.py` to `origin/develop` (keeping the new test file) yields 6 failed / 3 passed (the 6 behavioral RED tests fail; the 3 intentional green guards hold). Restored clean. No green-for-wrong-reason.
5. `[VERIFIED]` `[TYPE]` `[SIMPLE]` Import hygiene improved — removed unused `ContextConfig`; ruff clean (no F401). No type/signature changes. Diff is minimal.
6. `[VERIFIED]` `[DOC]` New comments are accurate — they correctly cite gh #50, SOUL #1, the TypeError root cause, and the read-vs-parse rationale. No stale/misleading docs introduced.
7. `[SEC]` `[LOW, non-blocking]` Warning messages interpolate `{exc}` / `repo['name']` / `sprint_path.name` — assessed for info-leak/injection/CWE-22 and cleared (single-user local tool, stderr only, `warnings.warn` is not a format template, no untrusted path component). Security subagent concurs: 0 findings.
8. `[SILENT]` `[LOW, non-blocking]` Pre-existing inner `except Exception: pass` in `fetch_persona`'s portrait-resolver (`ws_push.py` ~L497, "AC-3 graceful degradation") and the `data_proxy` `_get_git_info`/`_get_repos_config` swallows remain — out of this story's file scope; captured as follow-ups (the natural "part 3"). Corroborated by preflight + TEA + Dev.

**Subagent dispatch:** `[EDGE]` (disabled — Reviewer covered: TOCTOU, undecodable bytes, partial diffs, missing repo name — all graceful), `[SILENT]` (disabled — Reviewer covered, see obs 2/8), `[TEST]` (disabled — Reviewer covered, see obs 4), `[DOC]` (disabled — see obs 6), `[TYPE]` (disabled — see obs 5), `[SEC]` (returned clean, see obs 7), `[SIMPLE]` (disabled — see obs 5), `[RULE]` (disabled — Reviewer ran full python.md enumeration, see Rule Compliance).

**Data flow traced:** undecodable/malformed `current-sprint.yaml` → `_read_text_file`/`yaml.safe_load` → `warnings.warn` (read vs parse) → degraded `{"sprint":{},"epics":[]}` → poll loop survives (safe because no raise reaches the outer `except Exception: pass`).

**Pattern observed:** consistent `except Exception as exc: warnings.warn(...) ; degrade` mirroring 160-12's accepted convention — `ws_push.py:197, 233, 443, 510`.

**Error handling:** every changed path returns a result/degraded shape, never throws (SOUL #10) — verified at the four catch sites.

**Handoff:** To SM (Stilgar) for finish-story.