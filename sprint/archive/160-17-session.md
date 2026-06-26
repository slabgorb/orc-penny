---
story_id: "160-17"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-17: ws_push/data_proxy fail-loud sweep part 4

## Story Details
- **ID:** 160-17
- **Title:** ws_push/data_proxy fail-loud sweep part 4: warn-then-degrade the remaining data_proxy silent swallows — get_theme_agents (~L314 except Exception: return JSONResponse({})) + _get_identity jira/gh os.popen probes (~L372/L382 except Exception: pass) — from 160-16 TEA/Dev/Reviewer findings
- **Points:** 2
- **Jira Key:** (none — local sprint)
- **Workflow:** tdd
- **Repo:** pennyfarthing
- **Branch:** feat/160-17-data-proxy-fail-loud-part4
- **Stack Parent:** 160-16 (direct follow-up from TEA/Dev/Reviewer findings)

## Story Context

**Type:** Bug fix / Hardening (fail-loud sweep continuation, part 4 of 4)

**Upstream Finding:** Story 160-16 completed the third fail-loud sweep (part 3), fixing three silent-swallow sites in data_proxy and fetch_persona. During code review, the Reviewer identified two additional silent-swallow sites in the same file (data_proxy.py) that should be treated with the same warn-then-degrade pattern:

1. **data_proxy.get_theme_agents** (~L314) — returns `JSONResponse({})` on any exception, silently swallowing theme agent fetch failures
2. **data_proxy._get_identity** (~L372/L382) — `except Exception: pass` block wrapping `os.popen()` calls for jira/gh CLI probes; failure to detect identity sources is silent

**Technical Approach:**
- Audit both locations for current exception handling behavior
- Replace silent returns/passes with explicit exception propagation or fail-loud logging (warn-then-degrade pattern established in 160-16)
- Add test coverage confirming exceptions are surfaced (not silently swallowed)
- Verify integration with calling routes — ensure exceptions propagate appropriately without raising into caller

**Acceptance Criteria:**
- AC-1: data_proxy.get_theme_agents warns on exception instead of silently returning `JSONResponse({})` (not silent swallow); degrades gracefully to empty theme list
- AC-2: data_proxy._get_identity warns when jira/gh os.popen probes fail (not `except Exception: pass`); degrades gracefully (likely returns None or empty dict)
- AC-3: All changes covered by unit tests; TEA validates fail-loud behavior before code review
- AC-4: Series-wide deviations (info-leakage in warn text, diagnostic clarity) are logged if encountered; optional follow-up for future sweep

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-26T10:50:37Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-26T08:26:52Z | 2026-06-26T08:29:10Z | 2m18s |
| red | 2026-06-26T08:29:10Z | 2026-06-26T08:45:22Z | 16m 12s |
| green | 2026-06-26T08:45:22Z | 2026-06-26T08:51:18Z | 5m 56s |
| review | 2026-06-26T08:51:18Z | 2026-06-26T09:02:45Z | 11m 27s |
| red | 2026-06-26T09:02:45Z | 2026-06-26T10:41:32Z | 1h 38m |
| green | 2026-06-26T10:41:32Z | 2026-06-26T10:45:14Z | 3m 42s |
| review | 2026-06-26T10:45:14Z | 2026-06-26T10:50:37Z | 5m 23s |
| finish | 2026-06-26T10:50:37Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): `get_context` (the FastAPI context route, `data_proxy.py:~284-311`) has the SAME silent-swallow shape this sweep is closing — `except Exception` returns an all-`None` context dict with the error string embedded but emits NO `warnings.warn`. A natural **part-5** candidate. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (apply the same warn-then-degrade). *Found by TEA during test design.*
- **Improvement** (non-blocking): The jira/gh probes shell `os.popen("jira me --raw 2>/dev/null")` / `"gh api user 2>/dev/null"`, discarding the tool's OWN stderr. So even after warn-then-degrade the warning can only say "non-empty unparseable output", never WHY (auth expired, rate-limited, network). Consider capturing stderr (`2>&1` or `subprocess.run(capture_output=True)`) to enrich the warn text. Affects `data_proxy.py::_get_identity`. *Found by TEA during test design.*
- **Question** (non-blocking): AC-4 names "info-leakage in warn text" as a series-wide concern — that is precisely the scope of sibling story **160-18** (sanitize the warnings sink before network exposure). My RED pins warn PRESENCE by subject-keyword regex only (not exact text), leaving wording to Dev; Dev/Reviewer should NOT re-solve info-leak here — defer raw-`{exc}`/path sanitization to 160-18 to avoid double-handling. Affects `data_proxy.py` warn strings. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): Confirmed TEA's part-5 candidate — `get_context` (`data_proxy.py:~299`) is the LAST silent swallow in this file: `except Exception` returns an all-`None` context shape with the error embedded in the body but emits NO `warnings.warn`. Same warn-then-degrade fix applies. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py::get_context`. *Found by Dev during implementation.*
- **Improvement** (non-blocking): The frame regression batch surfaced 5 PRE-EXISTING `RuntimeWarning: coroutine '{find_stale_files|analyze_complexity|analyze_dependencies}' was never awaited` from the brownfield dead-code/complexity/dependencies routes — those async analyzers are invoked without `await`, so they never execute and the route returns a coroutine/empty result (lang-review #9 missing-await). Unrelated to this story but a real bug worth a follow-up. Affects the frame brownfield routes (see `test_frame_routes.py::TestDeadCodeRoute/TestComplexityRoute/TestDependenciesRoute`). *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (blocking): `get_theme_agents` calls `get_crew_manifest(project_dir)` where `project_dir` is a **str** (`_get_project_dir()` → `os.environ.get(...)`/`os.getcwd()`), but `get_crew_manifest` → `get_current_theme` does `root / ".pennyfarthing"` requiring a **Path** → raises `TypeError: unsupported operand type(s) for /: 'str' and 'str'` on EVERY call. The new `warnings.warn` therefore fires on every `/api/theme-agents` request — a warn over a CONSTANT bug (warn-spam, fail-loud defeated). Confirmed at runtime AND independently by `reviewer-preflight` (the existing `test_get_theme_agents_returns_json` now emits this exact warn). Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py::get_theme_agents` (pass `Path(project_dir)` to `get_crew_manifest`). *Found by Reviewer during code review.*
- **Gap** (non-blocking): Even after the Path fix, `get_crew_manifest` returns `list[CrewMember]` while the route serializes `crew if isinstance(crew, dict) else {}` → always `{}`, and `CrewMember` isn't JSON-serializable — so the theme-agents panel has NEVER rendered data (this is why AC-1's "degrades to empty" is permanently active). Separate pre-existing serialization bug; fold into the rework or file a follow-up. Affects `data_proxy.py::get_theme_agents`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `[SEC]` jira/gh probes call `_json.loads(result)` then `.get(...)` with no `isinstance(data, dict)` guard — a non-dict JSON shape raises `AttributeError`, now caught+warned (graceful, but the warn would mislabel a shape error as a parse error). Optional hardening: `if isinstance(data, dict):` before field access. Affects `data_proxy.py::_get_identity`. *Found by Reviewer during code review (corroborated by reviewer-security #8/#11).*
- **Improvement** (non-blocking): `[SEC]` the three `warnings.warn(f"...: {exc}")` interpolate raw `{exc}` (JSONDecodeError carries an input excerpt; OSError carries local paths) — low-sev info-leak IF Frame ever forwards warnings to a network client. This is series-wide house style; mitigation is explicitly owned by **story 160-18**. Do NOT fix here. Affects all `data_proxy.py` warn strings. *Found by Reviewer during code review (corroborated by reviewer-security).*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Empty-stdout probe stays SILENT (warn only on non-empty unparseable)**
  - Spec source: context-story-160-17.md, AC-2
  - Spec text: "data_proxy._get_identity warns when jira/gh os.popen probes fail (not `except Exception: pass`)"
  - Implementation: tests pin a warn ONLY when a probe returns NON-EMPTY but unparseable stdout (`test_identity_jira/gh_probe_garbage_warns`); an EMPTY-stdout probe degrades SILENTLY (`test_identity_empty_stdout_stays_silent`).
  - Rationale: `json.loads("")` raises on EVERY installed-but-unauthenticated jira/gh (the `2>/dev/null` ate the tool's own error → empty stdout). A blanket "warn on any probe exception" would spam every gh-installed-but-unauthed user. This mirrors 160-16's "missing repos.yaml stays silent" — absent/empty is the normal not-configured state; present-but-broken is the fault worth surfacing. Reviewer may override if unauthed-should-warn is desired.
  - Severity: minor
  - Forward impact: Dev must branch on empty-vs-non-empty stdout before/around `json.loads`; `test_identity_empty_stdout_stays_silent` enforces it.
- **Non-dict crew coercion is OUT OF SCOPE (stays silent)**
  - Spec source: context-story-160-17.md, AC-1
  - Spec text: "get_theme_agents warns on exception instead of silently returning `JSONResponse({})`; degrades gracefully to empty theme list"
  - Implementation: the warn covers ONLY the `except Exception` path; the pre-existing `crew if isinstance(crew, dict) else {}` non-dict coercion stays silent (`test_theme_agents_non_dict_crew_stays_silent`).
  - Rationale: the `isinstance` fallback is a clean type coercion, not a swallowed error. Warning there is out of scope and would over-apply the fix.
  - Severity: minor
  - Forward impact: Dev's warn must wrap only the `except`, not the `isinstance` branch.
- **Intentional GREEN regression guards (5 of 9 tests green on HEAD)**
  - Spec source: context-story-160-17.md, AC-3
  - Spec text: "All changes covered by unit tests; TEA validates fail-loud behavior before code review"
  - Implementation: 4 tests are genuinely RED (DID NOT WARN); 5 are green-on-arrival guards — healthy seam-checks (real data flows back, per the 160-15 constant-bug lesson) plus the silence guards above.
  - Rationale: per `ac-as-green-regression-guard`, preservation requirements (healthy paths resolve data; non-dict/empty/absent stay silent) are correctly green and guard the fix against over-warping. Not spurious greens.
  - Severity: minor
  - Forward impact: none.
- **RED verified via direct scoped pytest, not the `testing-runner` subagent**
  - Spec source: agent-behavior guide ("Tests: Use testing-runner subagent, never run directly")
  - Spec text: "Use `testing-runner` subagent, never run directly"
  - Implementation: verified RED with `uv run pytest src/pf/tests/test_160_17_fail_loud_4.py -q` (4 failed, 5 passed, 0 errored).
  - Rationale: the full suite leaks a `feature/test` checkout (`test_git_utils.py`) onto the live repo, and `testing-runner` is non-deterministic and can clobber the active session file; the scoped single-file run is the established verification path for this fail-loud story family (160-12/15/16) — see TEA sidecar `scoped-red-run` / `dont-run-the-SUT-runner`.
  - Severity: minor
  - Forward impact: none.

### Dev (implementation)
- **Empty-stdout guard via `if result.strip():` (honors TEA empty-silent contract)**
  - Spec source: context-story-160-17.md, AC-2 + TEA Design Deviation #1
  - Spec text: "data_proxy._get_identity warns when jira/gh os.popen probes fail (not `except Exception: pass`)"
  - Implementation: guarded each probe's parse with `if result.strip():` so EMPTY stdout skips `json.loads` entirely (silent); only NON-EMPTY unparseable output reaches the `except` → warns.
  - Rationale: implements TEA's empty-stdout-silent contract — the literal AC said "warns on failure", but `json.loads("")` raises on every unauthed gh/jira, so a blanket warn would spam those users. The strip-guard distinguishes present-but-broken from not-configured.
  - Severity: minor
  - Forward impact: none — matches the pinned tests (`_empty_stdout_stays_silent`, `_*_probe_garbage_warns`).
- **Kept broad `except Exception` (not narrowed) at all three sites**
  - Spec source: lang-review python #1 (silent exception swallowing → catch specific)
  - Spec text: "`except Exception` ... must catch specific exceptions"
  - Implementation: kept `except Exception as exc` (now warn-then-degrade) rather than narrowing to `json.JSONDecodeError` / the manifest's specific error types.
  - Rationale: both sites feed an async route (`get_theme_agents`) / a cached identity probe with NO outer guard — any escaped exception 500s the route, strictly worse than a warned degrade. Matches 160-16's same-file decision; the fail-loud warn (not the narrowing) is what #1 actually demands in a route/poll context.
  - Severity: minor
  - Forward impact: none.
- **GREEN verified via direct scoped pytest, not the `testing-runner` subagent**
  - Spec source: agent-behavior guide ("Tests: Use testing-runner subagent, never run directly")
  - Spec text: "Use `testing-runner` subagent, never run directly"
  - Implementation: verified GREEN directly — `uv run pytest` on the new file + `test_160_16`/`test_160_15`/`test_frame_routes` regression batch (99 passed) + `ruff check src/pf/frame/routes/data_proxy.py` (clean).
  - Rationale: the full suite leaks a `feature/test` checkout (`test_git_utils.py`), and `testing-runner` can rewrite source to force GREEN (Dev sidecar `testing-runner-can-mutate-source`). Scoped direct runs are the established path for this fail-loud family (160-12/15/16).
  - Severity: minor
  - Forward impact: none.

### Reviewer (audit)
- **TEA #1 (empty-stdout stays silent)** → ✓ ACCEPTED: sound and verified — the `if result.strip():` guard correctly silences the common unauthed gh/jira (empty stdout) case while warning on genuine garbage; mirrors 160-16 missing-file-silent. No warn-spam on this path.
- **TEA #2 (non-dict crew coercion out of scope, stays silent)** → ✓ ACCEPTED (concept) / ✗ but the underlying path is BROKEN: warning on the `isinstance` coercion is correctly out of scope, BUT that very `isinstance(crew, dict)` branch is itself a latent bug — `get_crew_manifest` returns `list[CrewMember]`, never a dict, so the route always returns `{}` (see blocking finding). The deviation's reasoning is fine; the code it points at is not. Captured as a Delivery Finding.
- **TEA #3 (intentional GREEN regression guards)** → ✗ FLAGGED: `test_theme_agents_healthy_no_warning` patches `get_crew_manifest` to return a dict, which MASKED the constant `str→TypeError` bug AND the list-vs-dict mismatch. A green guard that patches the seam it should be exercising gave false confidence and let the warn-over-constant-bug ship to review. The rework must add a guard that drives the REAL `get_crew_manifest` (valid Path project dir) and asserts no warn. This is the root of the REJECT.
- **TEA #4 (RED via direct scoped pytest)** → ✓ ACCEPTED: established practice for this story family; branch-leak and runner-mutation risks are real.
- **Dev #1 (empty-stdout guard via `if result.strip():`)** → ✓ ACCEPTED: correct, minimal implementation of TEA's contract; verified.
- **Dev #2 (kept broad `except Exception`)** → ✓ ACCEPTED: correct for these route/probe paths — narrowing risks a 500/poll-loop crash (per `narrowed-exception-rewrite-lets-new-class-escape`). The fail-loud warn, not the narrowing, is what #1 demands here.
- **Dev #3 (GREEN via direct scoped pytest)** → ✓ ACCEPTED: same rationale as TEA #4.
- **UNDOCUMENTED (Reviewer):** Neither TEA nor Dev verified `get_crew_manifest` against the REAL str argument the route passes — the seam was patched in every theme-agents test. Spec (AC-1) said "warns on exception"; the code warns on a CONSTANT exception (every call), which is noise, not fail-loud. Severity: HIGH. This is the blocking finding.

#### Round 2 (Reviewer audit)
- **TEA round-2 #1 (crew serialization shape left to Dev)** → ✓ ACCEPTED: sound — no frontend consumer pins the shape (grep found none); `test_theme_agents_serializes_crew_members` verifies DATA presence, leaving Dev the `{role: character}` vs `[{role, character}]` choice. Verified at runtime: the route returns `{"sm":"Edmund Blackadder",...}`.
- **Dev round-2 #1 (did NOT add the `[SEC]` `isinstance(data, dict)` guard)** → ✓ ACCEPTED — and the reasoning is SHARPER than my round-1 suggestion: a bare `if isinstance(data, dict):` (no `else`) would make a non-dict probe response degrade SILENTLY, reintroducing the swallow this story removes. The current path WARNS on the `AttributeError` (correct fail-loud). I formally WITHDRAW the round-1 `[SEC]` optional-hardening suggestion as superseded.
- **Round-1 blocking finding** → ✓ RESOLVED: `get_theme_agents` now passes `Path(project_dir)` (no constant `TypeError`) and serializes the crew. Verified by (a) runtime discharge — real route returns `{role: character}` for the full crew with NO warn; (b) inverse binding probe — the two round-2 tests FAIL on round-1 source, PASS on round-2 source.

## SM Assessment

**Setup Complete:** Story context document created, branch created, session file written.

**Next Phase:** red (TEA designs tests for the two identified silent-swallow sites: `get_theme_agents` L314 and `_get_identity` L372/L382 in data_proxy.py)

**Context Sources:**
- Prior sessions: `sprint/archive/160-15-session.md` (part 2), `sprint/archive/160-16-session.md` (part 3)
- Review findings from 160-16: Delivery Findings, TEA/Dev/Reviewer Assessment sections identify the part-4 candidates
- Source file: `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (~L314 get_theme_agents, ~L372/L382 _get_identity)
- Pattern: warn-then-degrade, matching 160-12/160-15/160-16 house style (`warnings.warn(f"Failed to … : {exc}", stacklevel=2)`)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Two user-controlled error paths (a FastAPI route + an identity probe) silently swallow exceptions — exactly the fail-loud class this sweep targets. Behavioral coverage is required to drive and lock the warn-then-degrade fix.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_17_fail_loud_4.py` (new) — 9 tests across two buckets (get_theme_agents, _get_identity).

**Tests Written:** 9 tests (4 RED + 5 green regression guards) covering AC-1, AC-2, AC-3.
**Status:** RED confirmed — `4 failed, 5 passed, 0 errored` via `uv run pytest src/pf/tests/test_160_17_fail_loud_4.py -q`. All 4 failures are `Failed: DID NOT WARN` (assertion failures, not import/collection errors) — clean RED for the right reason.

**AC → Test map:**
| AC | Tests | Status |
|----|-------|--------|
| AC-1 get_theme_agents warns + degrades to `{}` | `test_theme_agents_crew_error_warns_not_silent` (RED); guards: `_healthy_no_warning`, `_non_dict_crew_stays_silent` | failing (RED) |
| AC-2 _get_identity warns on probe fail + degrades | `test_identity_jira_probe_garbage_warns`, `_gh_probe_garbage_warns`, `_jira_fails_gh_still_resolves_warn_in_place` (RED); guards: `_both_probes_healthy_no_warning`, `_empty_stdout_stays_silent`, `_neither_tool_installed_stays_silent` | failing (RED) |
| AC-3 unit-tested, TEA validates fail-loud | whole file; RED verified | satisfied |
| AC-4 series-wide deviations logged | Design Deviations + Delivery Findings (info-leak deferred to 160-18) | satisfied |

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 Silent exception swallowing | `test_theme_agents_crew_error_warns_not_silent`, `test_identity_jira_probe_garbage_warns`, `test_identity_gh_probe_garbage_warns`, `test_identity_jira_fails_gh_still_resolves_warn_in_place` | failing |
| #4 Error paths must surface (warn) | same four warns tests (house style: `warnings.warn`, per 160-12/15/16) | failing |
| #8 / #11 `json.loads` on external-tool output | `test_identity_*_probe_garbage_warns` (drives guarding the loads) | failing |
| #6 Test quality (no vacuous assertions) | self-check on all 9 tests | pass |
| #9 Async pitfalls (blocking `get_crew_manifest` in async route) | observed in `get_theme_agents` — pre-existing, OUT OF SCOPE (this story is the swallow, not an async refactor) | noted |

**Rules checked:** 3 of 3 directly-applicable source rules covered (#1 primary, #4, #8); #6 test-quality self-check passed; #9 observed but out of scope.
**Self-check:** 0 vacuous tests found — every test asserts specific values (response body equals exact dict; identity fields equal exact strings/`None`; warns matched by subject regex). No `assert True`, no truthy-only checks, no `let _ =`.

**Warn-in-place contract (critical for Dev):** `_get_identity` has NO outer try/except. The per-probe fix MUST warn-then-`pass` in place — a "remove the try / let it raise" fix would raise out of the whole function (500 on `/api/identity`) and skip the sibling probe. `test_identity_jira_fails_gh_still_resolves_warn_in_place` forbids that (asserts gh's `octocat` still resolves after jira's probe fails).

**Handoff:** To Baldrick (Dev) for GREEN — implement warn-then-degrade at both sites per the designed interface in the test module docstring. Honor the empty-stdout-silent contract (Design Deviation #1) and keep both fixes warn-in-place. Defer warn-text info-leak sanitization to 160-18 (Delivery Finding).

### Round 2 (rework — TEA)
**Trigger:** Reviewer REJECTED round 1 (warn over a constant `str/Path` bug in `get_theme_agents`); Keith chose "Full: make the panel work" (see Rework Scope above).

**Tests reworked** (theme-agents Bucket A only; `_get_identity` tests untouched — Reviewer approved them):
- REMOVED the two seam-patched guards (`test_theme_agents_healthy_no_warning` returned a dict, `test_theme_agents_non_dict_crew_stays_silent`) — they masked the constant bug.
- ADDED `test_theme_agents_real_manifest_no_warn_on_valid_dir`: drives the REAL `get_crew_manifest` against a bare `.pennyfarthing/` tmp dir (`PF_PROJECT_DIR`), asserts NO warn. RED today (str → `TypeError` → warn); GREEN once the route passes a `Path`. Verified `get_crew_manifest(Path(bare_dir)) == []` with no warn.
- ADDED `test_theme_agents_serializes_crew_members`: fake asserts the route hands a `Path` AND returns `list[CrewMember]`; body must carry the character names. RED today (`isinstance(list, dict)` → `{}`); GREEN once the route serializes the list.
- KEPT `test_theme_agents_crew_error_warns_not_silent` (exception → warn).

**Rework RED state:** `2 failed, 7 passed` via `uv run pytest src/pf/tests/test_160_17_fail_loud_4.py -q`. The two new tests fail for the right reason (the captured warn reads "route must pass a Path to get_crew_manifest, got str").

**Dev directives (GREEN, round 2):**
1. `get_theme_agents`: pass a `Path` — `get_crew_manifest(Path(project_dir))` (kills the constant `TypeError`/warn-spam).
2. Serialize the `list[CrewMember]` (a dataclass with `role`+`character`, NOT JSON-able) — replace `crew if isinstance(crew, dict) else {}`. Shape is YOUR call (`{m.role: m.character for m in crew}` is the simplest, matches the legacy dict expectation; `[asdict(m) for m in crew]` also fine). The tests pin DATA presence, not shape.
3. Keep the `except Exception as exc: warnings.warn(...)` — it now fires only on genuine `get_crew_manifest` errors.
4. Optionally fold in the `[SEC]` `isinstance(data, dict)` guard on the jira/gh `_json.loads`.

### Round 2 Design Deviation (TEA)
- **Crew serialization shape left to Dev**
  - Spec source: Reviewer Assessment (round 1) + Rework Scope (user-directed)
  - Spec text: "the route must return a JSON-serializable shape so the panel renders real data"
  - Implementation: `test_theme_agents_serializes_crew_members` asserts only that the character names appear in the body (`"Edmund Blackadder"`/`"Lord Melchett"` in `json.dumps(body)`), not a specific dict/list shape.
  - Rationale: no current frontend consumer pins the shape (grep found none); leaving it fix-agnostic avoids over-constraining Dev while still forcing real data through.
  - Severity: minor
  - Forward impact: a future frontend consumer of `/api/theme-agents` must agree on the shape Dev picks.

**Handoff (round 2):** To Baldrick (Dev) for GREEN — apply the two `get_theme_agents` fixes above; `_get_identity` is done.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` — three warn-then-degrade edits (26 insertions, 9 deletions):
  - `get_theme_agents` (async route): `except Exception as exc` now `warnings.warn("Failed to load theme agents: {exc}")` before `return JSONResponse({})`. The `isinstance` non-dict coercion returns inside the try (before `except`) → stays silent for free.
  - `_get_identity` jira probe: parse guarded by `if result.strip():`; `except` now `warnings.warn("Failed to parse jira identity probe: {exc}")`.
  - `_get_identity` gh probe: same shape — `if result.strip():` + `warnings.warn("Failed to parse gh identity probe: {exc}")`.
  - `import warnings` already present (added in 160-16); no new imports.

**Tests:** 9/9 passing (GREEN) — `uv run pytest src/pf/tests/test_160_17_fail_loud_4.py -q` → `9 passed`.
**Regression:** new file + `test_160_16` + `test_160_15` + `test_frame_routes` → `99 passed` (5 PRE-EXISTING `coroutine never awaited` RuntimeWarnings in unrelated brownfield routes — captured as a Delivery Finding, not introduced here). `ruff check data_proxy.py` → clean.
**Branch:** `feat/160-17-data-proxy-fail-loud-part4` (pushed; commit `d4fc38bf4`, signed).

**Self-review (judgment checks):**
- [x] Wired — both sites are live FastAPI route / cached identity probe paths; warn-then-degrade preserves existing return shapes.
- [x] Follows project patterns — `warnings.warn(f"...: {exc}", stacklevel=2)` matches 160-12/15/16 house style.
- [x] All ACs met — AC-1 (theme-agents warns+degrades), AC-2 (both probes warn-in-place + empty-silent), AC-3 (tested), AC-4 (deviations/findings logged, info-leak deferred to 160-18).
- [x] Error handling — catch kept broad on purpose (route/probe must never raise); warn surfaces the fault.

**Handoff:** To Captain Darling (Reviewer) for adversarial review. Watch items: the empty-stdout-silent contract (Dev Deviation #1 — confirm or override); the deliberately-broad `except` (Dev Deviation #2); and the two carried-forward Delivery Findings (`get_context` part-5 candidate, the missing-`await` brownfield routes).

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 1 (surfaced the `str/str` TypeError warn in `test_frame_routes`) | confirmed 1 (corroborates the blocking finding; preflight misclassified it as "fix working") |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings — analyzed by Reviewer (see `[EDGE]`) |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings — analyzed by Reviewer (see `[SILENT]`) |
| 4 | reviewer-test-analyzer | No | Skipped | disabled | Disabled via settings — analyzed by Reviewer (see `[TEST]`) |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings — analyzed by Reviewer (see `[DOC]`) |
| 6 | reviewer-type-design | No | Skipped | disabled | Disabled via settings — analyzed by Reviewer (see `[TYPE]`) |
| 7 | reviewer-security | Yes | findings | 3 (2× #8/#11 medium, 1× info-leak low) | confirmed 3, all non-blocking (see `[SEC]`) |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings — analyzed by Reviewer (see `[SIMPLE]`) |
| 9 | reviewer-rule-checker | No | Skipped | disabled | Disabled via settings — analyzed by Reviewer (see `[RULE]`) |

**All received:** Yes (2 enabled returned: preflight + security; 7 disabled via `workflow.reviewer_subagents` and analyzed by Reviewer per `disabled-reviewer-subagents-shift-burden-to-you`)
**Total findings:** 1 confirmed blocking (HIGH), 5 confirmed non-blocking, 2 VERIFIED

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] `[SILENT]` | `get_theme_agents` passes a **str** (`_get_project_dir()`) to `get_crew_manifest`, which does `root / ".pennyfarthing"` → `TypeError: str/str` on EVERY call. The new `warnings.warn` therefore fires on every `/api/theme-agents` request — a warn over a CONSTANT bug (warn-spam, fail-loud defeated). The story shipped the exact 160-15 trap because TEA's "healthy" test patched `get_crew_manifest` out, never exercising the real path. | `data_proxy.py:322` (`crew = get_crew_manifest(project_dir)`) | Pass `Path(project_dir)` so the steady state returns its list and the warn fires only on genuine errors. TEA must add a guard driving the REAL `get_crew_manifest` (valid Path dir) asserting no warn. |
| [MEDIUM] `[TYPE]` | Even with the Path fix, `get_crew_manifest` returns `list[CrewMember]` but the route checks `isinstance(crew, dict)` → always `{}`; `CrewMember` isn't JSON-serializable. The panel has NEVER shown data. | `data_proxy.py:323` | Fold serialization into the rework (e.g. `[asdict(m) for m in crew]` or a `{role: character}` dict) or file a follow-up. |
| [MEDIUM] `[TEST]` | `test_theme_agents_healthy_no_warning` / `_non_dict_crew_stays_silent` patch `get_crew_manifest` entirely → mask the constant `str→TypeError`. The green guards proved the route's dict-passthrough, not production reality. | `test_160_17_fail_loud_4.py:122,141` | Add a real-path no-warn guard (valid `PF_PROJECT_DIR` / `Path`) that would have caught the TypeError. |
| [LOW] `[SEC]` | jira/gh `_json.loads(result)` → `.get(...)` with no `isinstance(data, dict)` guard; a non-dict JSON shape raises `AttributeError` (caught+warned, but mislabeled). | `data_proxy.py:394,409` | Optional: `if isinstance(data, dict):` before field access. |
| [LOW] `[SEC]` | `{exc}` interpolated into all 3 warns → info-leak IF Frame forwards warnings to a network client. **Series-wide; owned by 160-18.** | `data_proxy.py:333,398,413` | Do NOT fix here — defer to 160-18. |

### Rule Compliance (python lang-review checklist)

- **#1 Silent exception swallowing** — the diff correctly converts 3 `except Exception: pass`/`return {}` swallows into warn-then-degrade. COMPLIANT in form. BUT `get_theme_agents`'s warn fires over a constant bug (#13 regression below).
- **#4 Error surfacing** — `warnings.warn` added at all 3 sites (house style, matches 160-12/15/16). COMPLIANT.
- **#6 Test quality** `[TEST]` — VIOLATION: the two `get_theme_agents` green guards patch the SUT seam, masking the constant bug. The `_get_identity` tests are sound (specific value asserts, real `os.popen`/`shutil.which` seams).
- **#8 Unsafe deserialization / #11 Input validation** `[SEC]` `[RULE]` — `_json.loads` on `os.popen` output with no shape guard before `.get()` (jira+gh). MEDIUM, non-blocking (the `except` degrades it).
- **#9 Async pitfalls** — `get_theme_agents` (async) calls blocking sync `get_crew_manifest`; pre-existing. The missing-`await` brownfield routes (Dev finding) are a separate #9 violation. Noted, out of scope.
- **#13 Fix-introduced regressions** — VIOLATION (the HIGH finding): the fix converts a silently-swallowed constant `TypeError` into a per-call warn — a behavior regression introduced by this diff (silent → spam). This is the blocking issue.

### Other dispatch coverage (disabled specialists, done by Reviewer)
- `[EDGE]` — Boundary enumeration: empty stdout (✓ guarded silent), non-empty garbage (✓ warns), valid JSON (✓ parsed), neither-tool-installed (✓ `which` gate skips). `get_theme_agents`: healthy/exception/non-dict all traced. The uncovered boundary is the REAL str-arg path (the HIGH finding).
- `[DOC]` — Comments are accurate and match the code (AC tags, rationale). No stale/misleading docs. VERIFIED.
- `[SIMPLE]` — No over-engineering; the 3 edits are minimal warn-then-degrade. The `if result.strip():` guard is necessary (empty-silent contract), not gold-plating. VERIFIED.
- `[RULE]` — Beyond #8/#11 above, no other lang-review violations introduced; `import warnings` already present, no dead imports (ruff clean).

### Verified Good
- `[VERIFIED]` `_get_identity` empty-stdout silence — `data_proxy.py:394` `if result.strip():` skips `json.loads` on empty output; `test_identity_empty_stdout_stays_silent` + runtime (unauthed gh → empty → silent) confirm no spam. Complies with the empty-silent contract (TEA Dev #1). No constant-bug trap here (gh authed → valid JSON; unauthed → empty → silent).
- `[VERIFIED]` warn-in-place — `data_proxy.py:386-413` each probe has its own `try`; a jira failure warns then continues to gh (`test_identity_jira_fails_gh_still_resolves_warn_in_place` asserts `octocat` resolves). Complies with SOUL #10 (no raise out of the cached probe).
- `[VERIFIED]` deliberately-broad `except Exception` retained — correct for an async route / cached probe that must never raise; narrowing would risk a 500 (per `narrowed-exception-rewrite-lets-new-class-escape`).

### Devil's Advocate

Argue this code is broken: it already is, and the diff makes part of it louder without making it right. The headline AC-1 claim — "`get_theme_agents` warns on exception instead of silently returning `{}`" — is technically true and practically wrong: the exception it now warns on is `TypeError: str/str`, raised on *every* invocation because the route hands `get_crew_manifest` a `str` where a `Path` is required. So a feature sold as "fail-loud diagnostics" actually emits a fixed, content-free alarm on every poll/test run — the boy who cried wolf. A real future failure of `get_crew_manifest` (a genuinely malformed theme) would be indistinguishable from the perpetual str/str noise, so the warn cannot do the one job it was added for. Worse, the panel it claims to diagnose has *never* worked: `get_crew_manifest` returns `list[CrewMember]`, the route only forwards a `dict`, and `CrewMember` isn't JSON-serializable — three independent reasons the theme-agents panel is permanently empty, none addressed. A confused user reading "Failed to load theme agents" in their logs would chase a transient when the truth is a hard wiring bug. A stressed reviewer trusting the 9 green tests would ship it, because the tests patch the broken function out of existence — the green is a green of the test's own making, not the code's. On the identity side, a misbehaving `gh`/`jira` that emits a JSON *array* instead of an object slips past `if result.strip():`, raises `AttributeError` on `.get()`, and gets relabeled "Failed to parse" — a true statement about a false cause. The only thing standing between this and an actual 500 is the broad `except` the author (correctly) kept. The fix is one `Path()` call plus a test that runs the real function — small, but mandatory: shipping a constant alarm as "fail-loud" is the precise anti-pattern this whole sweep exists to eliminate (SOUL #1).

**Handoff:** Back to Lord Melchett (TEA) for rework (red) — add a guard exercising the REAL `get_crew_manifest` (valid `Path` project dir) that asserts no warn on the healthy path; then Baldrick (Dev) passes `Path(project_dir)` and folds in the list→dict serialization. The `_get_identity` changes are sound and need no rework.

### Rework Scope (user-directed, 2026-06-26)
Keith chose **"Full: make the panel actually work"** — so this rework expands 160-17 beyond the warn-fix to ALSO repair the long-standing empty-panel bug, all in this story:
1. **Path fix** — `get_theme_agents` must pass a `Path` (e.g. `get_crew_manifest(Path(project_dir))`) so `get_crew_manifest` returns its list instead of raising `TypeError` (kills the warn-spam).
2. **Serialize the crew** — `get_crew_manifest` returns `list[CrewMember]` (a dataclass/NamedTuple with `role` + `character`). The route must return a JSON-serializable shape so the panel renders real data. Suggested shape: a `{role: character}` dict (matches the legacy `isinstance(crew, dict)` expectation; TEA pins the exact shape). The `isinstance(crew, dict) else {}` line should be replaced accordingly.
3. **TEA tests (rework):** replace the seam-patching `test_theme_agents_healthy_no_warning` with a guard that drives the REAL `get_crew_manifest` against a valid `PF_PROJECT_DIR`/`Path` project dir and asserts (a) NO warn AND (b) the route body contains the actual crew (e.g. the `sm`/`tea` roles → character names) — this would have caught the constant `str/str` TypeError. Keep an exception-path test (patch `get_crew_manifest` to RAISE → still warns + degrades to `{}`).
4. `_get_identity` tests + impl are APPROVED as-is — do not rework them.
Also fold in the optional `[SEC]` `isinstance(data, dict)` guard on the jira/gh `_json.loads` if cheap; defer the `{exc}` info-leak to 160-18.

## Dev Assessment — Round 2 (rework)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py::get_theme_agents` (9 insertions, 4 deletions):
  - Pass `get_crew_manifest(Path(project_dir))` instead of the raw str → no more `TypeError: str/str` on every call (kills the round-1 warn-spam).
  - Serialize the returned `list[CrewMember]` as `{member.role: member.character for member in crew}` → the panel now receives real data instead of the always-`{}` from the old `isinstance(crew, dict)` check.
  - `except Exception as exc: warnings.warn(...)` retained — now fires ONLY on genuine `get_crew_manifest` errors.
- `_get_identity` UNCHANGED (Reviewer-approved round 1).

**Tests:** 9/9 passing (GREEN) — `uv run pytest src/pf/tests/test_160_17_fail_loud_4.py -q`. The two round-2 regression tests (`_real_manifest_no_warn_on_valid_dir`, `_serializes_crew_members`) now pass.
**Regression:** `test_160_16` + `test_160_15` + `test_frame_routes` → `90 passed`; critically, `test_get_theme_agents_returns_json` NO LONGER emits the `str/str` warn (the only remaining `TestThemeAgentsRoute` warning is the pre-existing `StarletteDeprecationWarning`). `ruff check data_proxy.py` → clean.
**Branch:** `feat/160-17-data-proxy-fail-loud-part4` (pushed; commit `7cfd4f9c0`, signed).

### Round 2 Design Deviation (Dev)
- **Did NOT add the `[SEC]` `isinstance(data, dict)` guard on the jira/gh probes**
  - Spec source: Reviewer Assessment (round 1), `[SEC]` "optional hardening" finding
  - Spec text: "Optional: `if isinstance(data, dict):` before field access."
  - Implementation: left the probes as-is. A non-dict JSON response (e.g. a JSON array) still raises `AttributeError` on `.get()` → caught by `except Exception as exc: warnings.warn(...)` → degrades with a warning.
  - Rationale: this is a FAIL-LOUD sweep. A bare `if isinstance(data, dict):` (no `else`) would make a non-dict probe response degrade SILENTLY — reintroducing exactly the silent-swallow this story removes. The current path already WARNS on a malformed shape (the round-1 fix), which is the correct fail-loud behavior. The "swallowed silently" premise of the finding was superseded by the round-1 warn.
  - Severity: minor
  - Forward impact: none — a non-dict probe response warns + degrades (field stays `None`).

**Handoff:** To Captain Darling (Reviewer) for re-review (round 2). The blocking finding is resolved: `get_theme_agents` passes a `Path` (no constant warn) and serializes the crew (panel renders data). `_get_identity` is unchanged from the approved round 1.

## Subagent Results — Round 2

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 | confirmed: 90/90 green, ruff clean, `str/str` warn GONE (`str_str_warn_present: false`) — blocking finding resolved |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | analyzed by Reviewer (see `[EDGE]`) |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | analyzed by Reviewer (see `[SILENT]`) |
| 4 | reviewer-test-analyzer | No | Skipped | disabled | analyzed by Reviewer (see `[TEST]`) |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | analyzed by Reviewer (see `[DOC]`) |
| 6 | reviewer-type-design | No | Skipped | disabled | analyzed by Reviewer (see `[TYPE]`) |
| 7 | reviewer-security | Yes | clean | 0 | N/A — narrower exposure than round 1 (strict dataclass projection vs arbitrary-dict passthrough) (see `[SEC]`) |
| 8 | reviewer-simplifier | No | Skipped | disabled | analyzed by Reviewer (see `[SIMPLE]`) |
| 9 | reviewer-rule-checker | No | Skipped | disabled | analyzed by Reviewer (see `[RULE]`) |

**All received:** Yes (2 enabled returned: preflight + security, both clean; 7 disabled via settings, analyzed by Reviewer)
**Total findings:** 0 blocking, 0 non-blocking new (round-1 non-blocking findings stand as Delivery Findings)

## Reviewer Assessment — Round 2

**Verdict:** APPROVED

**Round-1 blocking finding — RESOLVED.** `get_theme_agents` now passes `get_crew_manifest(Path(project_dir))` (no more constant `TypeError: str/str`) and serializes `list[CrewMember]` as `{member.role: member.character for member in crew}`. Verified three independent ways:
1. **Runtime discharge** (the real route, real theme): `PF_PROJECT_DIR=<orchestrator> get_theme_agents()` → `status 200`, body `{"sm":"Edmund Blackadder","tea":"Lord Melchett","dev":"Baldrick","reviewer":"Captain Darling",...}`, `warns: []`. Real crew rendered, zero warnings.
2. **Inverse binding probe**: with `data_proxy.py` reverted to round-1 source (keeping the round-2 tests), `test_theme_agents_real_manifest_no_warn_on_valid_dir` and `test_theme_agents_serializes_crew_members` both FAIL; on round-2 source both PASS. The regression guard genuinely binds — it would have caught round 1.
3. **Preflight**: `str_str_warn_present: false` — the existing `test_get_theme_agents_returns_json` no longer emits the constant warn.

**Data flow traced:** `_get_project_dir()` (env/cwd str) → `Path(...)` → `get_crew_manifest(Path)` → `list[CrewMember]` (from theme YAML, dev-controlled) → `{role: character}` dict → `JSONResponse` (standard JSON escaping). Safe — no untrusted boundary, strictly narrower than the prior arbitrary-dict passthrough.

**Dispatch coverage:**
- `[SILENT]` — the `except` warns then degrades to `{}`; the warn now fires ONLY on genuine `get_crew_manifest` errors (not constantly). `_get_identity` unchanged (approved round 1). VERIFIED.
- `[TEST]` — reworked guards drive the REAL `get_crew_manifest` (no seam patch) + pin serialization; inverse probe proves binding. The masking gap from round 1 is closed.
- `[SEC]` — reviewer-security clean; the dict comprehension over typed `CrewMember` adds no injection/info-leak surface; `{exc}` info-leak remains deferred to 160-18. My round-1 `[SEC]` isinstance suggestion is WITHDRAWN (Dev correctly showed a bare guard would reintroduce silence).
- `[EDGE]` — empty crew → `{}`; populated crew → `{role: character}`; `get_crew_manifest` raises → warn + `{}`. All three traced.
- `[TYPE]` — `list[CrewMember]` (dataclass: `role`, `character`) now correctly projected to a JSON-able dict; the always-false `isinstance(crew, dict)` dead branch removed.
- `[SIMPLE]` — minimal change (one `Path(...)` + one comprehension); no over-engineering.
- `[DOC]` — the inline comments accurately describe the round-2 fix and the bug it closes.
- `[RULE]` — lang-review #1 compliant (warns); no new #8/#11 violation (dict comp on typed internal data).

### Verified Good
- `[VERIFIED]` no warn-spam — `get_theme_agents` against a valid project dir returns crew with `warns: []` (runtime). The round-1 constant-bug regression (#13) is gone.
- `[VERIFIED]` panel renders data — body carries the full `{role: character}` crew map, fixing the long-standing empty-panel bug (Keith's "Full" scope delivered).
- `[VERIFIED]` `_get_identity` untouched — `git diff` shows only `get_theme_agents` changed since round 1; the approved probe behavior is preserved.

### Devil's Advocate (round 2)
Could this still be broken? Three angles. (1) Duplicate roles: `{m.role: m.character}` would silently drop a collision — but `get_crew_manifest` builds one entry per role from `AGENT_ROLES` ∪ `theme_characters`, so roles are unique; no data loss. (2) A `CrewMember` missing `role`/`character`: it's a dataclass always constructed with both, so `m.role`/`m.character` can't `AttributeError` on a well-formed member; a malformed one would route to the `except` → warn (fail-loud), not a 500. (3) `Path(project_dir)` on a weird env value: `Path` accepts any str; a nonexistent dir resolves no theme → `get_crew_manifest` returns `[]` → `{}` (verified). The serialization shape (`{role: character}`) has no current frontend consumer to break, and is documented as a TEA deviation. The remaining `{exc}` info-leak is correctly owned by 160-18. No new defect found; the one real bug (the constant warn) is fixed and guarded.

**Handoff:** To Edmund Blackadder (SM) for finish-story. Two non-blocking Delivery Findings carry forward as follow-up candidates: `get_context` (part-5 silent swallow) and the missing-`await` brownfield routes (`find_stale_files`/`analyze_complexity`/`analyze_dependencies`).