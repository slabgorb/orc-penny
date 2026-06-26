---
story_id: "160-16"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-16: ws_push/data_proxy fail-loud sweep part 3

## Story Details
- **ID:** 160-16
- **Title:** ws_push/data_proxy fail-loud sweep part 3: warn on present-but-broken in data_proxy._get_git_info (subprocess int-parse silent->None) + _get_repos_config (repos.yaml parse swallow) + the fetch_persona inner portrait-resolver except Exception: pass (ws_push ~L497, AC-3) — from 160-15 TEA/Dev/Reviewer findings
- **Points:** 1
- **Jira Key:** (none — local sprint)
- **Workflow:** tdd
- **Repo:** pennyfarthing
- **Branch:** feat/160-16-ws-push-fail-loud-sweep-3
- **Stack Parent:** 160-15 (follow-up from TEA/Dev/Reviewer findings)

## Story Context

**Type:** Bug fix / Hardening (fail-loud sweep continuation)

**Upstream Finding:** Story 160-15 completed the second fail-loud sweep across ws_push, surfacing silent exception handlers and missing error propagation. This follow-up addresses three specific locations in data_proxy and fetch_persona that still swallow errors silently:

1. **data_proxy._get_git_info** — subprocess int-parse failure silently returns None instead of raising/warning
2. **data_proxy._get_repos_config** — repos.yaml parse errors swallowed without surfacing to caller
3. **fetch_persona** inner portrait-resolver (ws_push ~L497) — broad `except Exception: pass` that hides portrait fetch failures

**Technical Approach:**
- Audit each location for current exception handling behavior
- Replace silent None/pass returns with explicit exception propagation or fail-loud logging
- Add test coverage confirming exceptions are surfaced (not silently swallowed)
- Verify integration with ws_push caller flow — ensure exceptions propagate appropriately up the stack

**Acceptance Criteria:**
- AC-1: data_proxy._get_git_info raises or logs when subprocess int-parse fails (not silent None)
- AC-2: data_proxy._get_repos_config raises or logs when repos.yaml parse fails (not silent swallow)
- AC-3: fetch_persona inner portrait-resolver (ws_push ~L497) raises or logs on portrait fetch error (not `except Exception: pass`)
- AC-4: All changes covered by unit tests; TEA validates fail-loud behavior before code review

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-25T20:00:18Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-25T19:31:45Z | - | - |
| red | - | 2026-06-25T19:44:37Z | unknown |
| green | 2026-06-25T19:44:37Z | 2026-06-25T19:50:29Z | 5m 52s |
| review | 2026-06-25T19:50:29Z | 2026-06-25T20:00:18Z | 9m 49s |
| finish | 2026-06-25T20:00:18Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): `data_proxy.py` has the SAME silent-swallow class at two more sites not in this story's scope — `get_theme_agents` (~L314, `except Exception: return JSONResponse({})`) and `_get_identity` (~L372/L382, `os.popen(...)` jira/gh probes inside `except Exception: pass`). Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (a fail-loud sweep part 4 should warn-then-degrade these too). *Found by TEA during test design.*
- No blocking findings — the three named sites are self-contained and the swallow behavior was verified against source before REDding.

### Dev (implementation)
- No new upstream findings during implementation. TEA's part-4 candidate stands; refinement noted: of the two, `get_theme_agents` (~L314) is a FULLY silent `except Exception: return {}`, whereas the `get_context` route (~L286) already surfaces `error: str(e)` in its JSON body — so a part-4 sweep should prioritise `get_theme_agents` and the `_get_identity` jira/gh probes. *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): SERIES-WIDE info-leakage channel — the fail-loud warnings across the whole 160-4/12/15/16 sweep interpolate the raw exception (`{exc}`) and local paths (`repo_path`) into `warnings.warn`. Harmless today (warnings route to stderr, local single-user daemon), but a low-severity leak of filesystem layout / file-content fragments IF the Frame server is ever changed to forward its `warnings` stream to a network-exposed client panel. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` + `ws_push.py` + the prior sweep sites (sanitize the warnings sink, or emit `type(exc).__name__` + a fixed description, before any network exposure). Best fixed once, series-wide, not per-story. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): AC-2's warning uses `p.name`, but BOTH candidate paths (`.pennyfarthing/repos.yaml` and `repos.yaml`) share the basename `repos.yaml`, so the message can't say which file failed. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py:225` (use the full `p` for the diagnostic). Minor. *Found by Reviewer during code review.*
- Endorse TEA/Dev's part-4 candidate (`get_theme_agents` + `_get_identity` silent swallows) — same class, same file, out of this story's scope.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Intentional green-on-arrival regression guards (5 tests)**
  - Spec source: context-story-160-16.md, AC-1 / AC-2 / AC-3
  - Spec text: "warn on present-but-broken in _get_git_info … _get_repos_config … fetch_persona inner portrait-resolver"
  - Implementation: 5 tests assert NO warning on healthy/absent inputs (healthy git counts, valid repos.yaml, missing repos.yaml, resolved portrait, no-portrait-found) — these pass on current HEAD by design.
  - Rationale: pin the fail-loud fix to PRESENT-but-broken inputs only; without them Dev could over-apply and warn-spam on every 5s Frame poll (the normal absent-config / no-portrait cases). Per `ac-as-green-regression-guard`.
  - Severity: minor
  - Forward impact: none
- **AC-2 extended beyond the literal "parse swallow" to add `encoding="utf-8"` (CWE-838)**
  - Spec source: context-story-160-16.md, AC-2; `.pennyfarthing/gates/lang-review/python.md` #5
  - Spec text: "_get_repos_config (repos.yaml parse swallow)"
  - Implementation: added a fix-agnostic AST source-scan asserting the guarded `read_text` passes `encoding="utf-8"`, plus an undecodable-bytes behavioral test.
  - Rationale: the UnicodeDecodeError taxonomy case is part of "present-but-broken repos.yaml" and lives in the same guarded `yaml.safe_load(p.read_text())` statement; pinning encoding is the natural read-hygiene fix, consistent with the 160-12 sweep. Title named only the parse swallow.
  - Severity: minor
  - Forward impact: Dev must add `encoding="utf-8"` to `data_proxy.py:202`.
- **AC-1 return value left fix-agnostic (None OR a well-formed dict)**
  - Spec source: context-story-160-16.md, AC-1
  - Spec text: "subprocess int-parse silent->None"
  - Implementation: the int-parse RED asserts the warning fires + `result is None OR (dict with branch populated)`; it does not force a single degrade shape.
  - Rationale: both a per-`int()` try/warn (returns the full dict, ahead=None) and an outer-`except` warn (returns None) satisfy fail-loud; over-constraining would reject a valid fix. The branch-populated check still guards against a half-built dict that would KeyError in `get_git_all`.
  - Severity: minor
  - Forward impact: none

### Dev (implementation)
- **AC-1: warned on the existing catch-all `except Exception` rather than narrowing to `ValueError`**
  - Spec source: `test_160_16_fail_loud_3.py` AC-1; `.pennyfarthing/gates/lang-review/python.md` #1
  - Spec text: "subprocess int-parse silent->None" → warn (not silent None)
  - Implementation: added `warnings.warn(...)` to the pre-existing broad `except Exception as exc: return None` in `_get_git_info`; did not narrow the catch.
  - Rationale: `_get_git_info` feeds the async `get_git`/`get_git_all` routes and the Frame poll loop, which must never raise; a catch-all that warns-then-degrades is fail-loud without risking a 500 / blank panel. Narrowing would let unrelated failures propagate uncaught. TEA's test pins warn + graceful degrade, not the catch breadth (matched the chosen `(I)` per `ac-as-green-regression-guard`).
  - Severity: minor
  - Forward impact: none
- **AC-2: one neutral "Failed to load …" warning instead of a read-vs-parse wording split**
  - Spec source: `test_160_16_fail_loud_3.py` AC-2
  - Spec text: warn naming `repos.yaml` on a present-but-broken file (test matches `(?i)repos`)
  - Implementation: a single `warnings.warn(f"Failed to load repos config {p.name}: {exc}")` covering read + decode + parse, not the read-vs-parse split that 160-15 added to `fetch_sprint`.
  - Rationale: AC-2 carries no wording-split requirement; the one `try` wraps both `read_text` and `safe_load`, and "load" is honest for all three failure modes (malformed / undecodable / unreadable). Minimal per minimalist-discipline. A split, if the Reviewer wants it, is a trivial follow-up.
  - Severity: minor
  - Forward impact: none

### Reviewer (audit)
- **TEA: green-on-arrival regression guards (5 tests)** → ✓ ACCEPTED by Reviewer: the no-over-warning / missing-file-silent / healthy-path guards are exactly what pins the fail-loud fix to present-but-broken inputs and averts poll-loop warn-spam. Verified independently via the inverse binding probe (5 guards held on develop source).
- **TEA: AC-2 extended to add `encoding="utf-8"` (CWE-838)** → ✓ ACCEPTED by Reviewer: the encoding fix is in scope for "present-but-broken repos.yaml" (the undecodable-bytes taxonomy), addresses lang-review #5, and the AST source-scan makes it refactor-robust.
- **TEA: AC-1 return left fix-agnostic (None OR well-formed dict)** → ✓ ACCEPTED by Reviewer: not over-constraining the degrade shape is correct; the warn is the contract, and the branch-populated guard still prevents a downstream KeyError in `get_git_all`.
- **Dev: kept the catch-all `except Exception` (warn, not narrow) at AC-1** → ✓ ACCEPTED by Reviewer: retaining the broad catch is the RIGHT call for these heterogeneous async-route / poll-loop paths — narrowing risks a poll-loop crash or 500 (per `narrowed-exception-rewrite-lets-new-class-escape`). Same endorsement applies to the retained breadth at AC-2/AC-3.
- **Dev: AC-2 one neutral "Failed to load …" warning, not a read-vs-parse split** → ✓ ACCEPTED by Reviewer: AC-2 imposes no split requirement; "load" is honest across read+decode+parse, and the single `try` wraps both. (Captured the `p.name`-vs-full-path diagnostic nit as a separate non-blocking Delivery Finding.)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Three named silent-swallow sites need fail-loud behavior pinned by tests (TDD red phase).

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_16_fail_loud_3.py` — 11 tests across 3 ACs (new)

**Tests Written:** 11 tests covering 3 ACs (6 RED + 5 intentional green-on-arrival regression guards)
**Status:** RED (6 failing — ready for Dev), verified with a scoped single-file run (`uv run pytest src/pf/tests/test_160_16_fail_loud_3.py`): **6 failed, 5 passed, 0 errored**.

### Verified swallow sites (against source, before REDding)
| AC | Site | Current swallow | Fix contract |
|----|------|-----------------|--------------|
| AC-1 | `data_proxy._get_git_info` (~L187) | outer `except Exception: return None` hides `int()` parse of `rev-list --count` → repo renders unknown/clean | warn (naming git/count), degrade unchanged |
| AC-2 | `data_proxy._get_repos_config` (~L211) | `except Exception: pass` over `yaml.safe_load(p.read_text())`; `read_text` lacks `encoding=` | add `encoding="utf-8"`, warn (naming repos.yaml), keep single-repo fallback |
| AC-3 | `ws_push.fetch_persona` inner resolver (~L497) | `except Exception: pass` swallows `resolve_portrait_path` failure | warn **in place**, keep `portraitPath=None`, **return the full persona dict** (inner try MUST stay — removing it blanks the panel) |

### Rule Coverage
| Rule | Test(s) | Status |
|------|---------|--------|
| #1 silent exception swallowing | `test_git_info_bad_count_warns_not_silent`, `test_repos_config_malformed_yaml_*`, `test_repos_config_undecodable_bytes_*`, `test_repos_config_permission_denied_*`, `test_persona_portrait_resolver_failure_*` | failing (5) |
| #5 missing `encoding=` (CWE-838) | `test_repos_config_read_text_has_utf8_encoding` | failing (1) |

**Rules checked:** 2 of 2 applicable lang-review rules covered. #7 resource-leaks N/A (no `open()`/`Session()`/`connect()` introduced; reads use auto-closed `Path.read_text`).
**Self-check:** 0 vacuous tests — every test has a meaningful assert; green guards assert real returned data (branch/counts, repo topology, portraitPath) plus the absence of a *specifically-patterned* warning, not bare `recwarn` presence.

**RED failure reasons (all correct):** 5× `DID NOT WARN` (the silent swallows) + 1× `read_text missing encoding=` (the source scan). No import/collection/fixture errors.

**Handoff:** To Dev (Baldrick) for GREEN — make the 6 RED tests pass without regressing the 5 green guards. Bind to the exact sites in the table above; mirror the 160-15 `warnings.warn(f"Failed to … : {exc}", stacklevel=2)` house style. **Do NOT remove the inner portrait try (AC-3)** — warn in place.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` — `import warnings`; AC-1 `_get_git_info` outer except now warns (`Failed to parse git info for {repo_path}`) before `return None`; AC-2 `_get_repos_config` reads with `encoding="utf-8"` and warns (`Failed to load repos config {p.name}`) instead of `except Exception: pass`.
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — AC-3 `fetch_persona` inner portrait resolver warns in place (`Failed to resolve portrait for {agent_name}`), inner try kept so the persona dict still returns with `portraitPath=None`.

**Approach:** Minimal warn-then-degrade at each site, matching the 160-12/160-15 house style. All three keep their catch-all/inner-try structure because they feed async FastAPI routes (`get_git`/`get_git_all`) and the long-lived Frame poll loop — raising would 500 the route or blank the panel (strictly worse than a warning).

**Tests:** 11/11 passing (GREEN) — the 6 previously-RED now warn correctly; the 5 green guards (healthy git counts, valid repos.yaml, missing repos.yaml, resolved portrait, no-portrait-found) still emit no spurious warning. Verified scoped: `uv run pytest src/pf/tests/test_160_16_fail_loud_3.py` → 11 passed.
**Regression:** 343 passed (frame + 160-4/12/15 + 159-8 + 161-1 batch), 0 failed. `ruff check` on both changed files: clean (no dead imports — `warnings` added + used; `import yaml` still in use).
**Branch:** feat/160-16-ws-push-fail-loud-sweep-3 (pushed; commit 768db83bc)

**Self-review:**
- [x] Wired — the warns flow through the live `get_git`/`get_git_all`/persona-poll paths
- [x] Follows project patterns — same `warnings.warn(f"…: {exc}", stacklevel=2)` shape as the prior sweeps
- [x] All ACs met (AC-1/2/3 behavioral + AC-4 test coverage); 2 minor deviations logged (kept catch-all; neutral wording)
- [x] Error handling — fail-loud warn, graceful degrade, never raises

**Handoff:** To Reviewer (Captain Darling) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 blocking | N/A — tests 11/11 scoped + 343/0 regression, ruff clean, 0 smells |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — covered by Reviewer manually (see Observations) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — covered by Reviewer manually (this PR's domain) |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings — covered by Reviewer manually (inverse binding probe) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — covered by Reviewer manually |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — covered by Reviewer manually (no type changes) |
| 7 | reviewer-security | Yes | findings | 2 (low-sev info-leak) | confirmed 0 blocking · 2 deferred → non-blocking Delivery Finding |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — covered by Reviewer manually (minimal diff) |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — covered by Reviewer manually (lang-review pass below) |

**All received:** Yes (2 enabled returned: preflight + security; 7 disabled via `workflow.reviewer_subagents` — analysed by Reviewer directly)
**Total findings:** 0 confirmed blocking, 0 dismissed, 3 deferred (non-blocking Delivery Findings)

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** A broken `repos.yaml` (or a non-numeric `git rev-list --count`, or a raising portrait resolver) → previously vanished silently → now surfaces as a `warnings.warn` (stderr/Python warnings) while the function still degrades gracefully (`_get_repos_config` → single-repo fallback; `_get_git_info` → `None` → `get_git_all` renders unknown/clean; `fetch_persona` → full persona dict with `portraitPath=None`). No new raise escapes any async route or the 5s Frame poll loop. Safe.

**Pattern observed:** `warnings.warn(f"Failed to … {subject}: {exc}", stacklevel=2)` — consistent with the 160-4/160-12/160-15 fail-loud sweep house style — at `data_proxy.py:194`, `data_proxy.py:225`, `ws_push.py:502`.

**Error handling:** All three sites warn-then-degrade; none raise. Broad `except Exception` deliberately retained (correct for these heterogeneous subprocess/file/persona poll-loop paths — narrowing would risk a poll-loop crash or 500).

### Rule Compliance (lang-review python.md)

| # | Rule | Verdict | Evidence |
|---|------|---------|----------|
| 1 | Silent exception swallowing | COMPLIANT | 3 silent sites (`pass`/`return None`) → `warnings.warn` + degrade. `data_proxy.py:194,225`; `ws_push.py:502`. Retained breadth is not "silent". `[SILENT][RULE]` |
| 3 | Type annotations | COMPLIANT | No signature changes; annotated returns (`dict\|None`, `list[dict[str,str]]`, `dict`) intact. `[TYPE]` |
| 4 | Logging coverage/correctness | COMPLIANT | Module uses `warnings.warn` (sweep house style), not `logging`; f-string in warn matches 160-4/12/15 prior art. `[DOC]` |
| 5 | Path handling (CWE-838) | COMPLIANT | `read_text(encoding="utf-8")` added — `data_proxy.py:209`. No new `Path.resolve()` need (paths are env/cwd-derived, not user input). `[SEC]` |
| 6 | Test quality | COMPLIANT | 11 meaningful tests; mock targets patched at source module (function-local imports resolve there); AST scan paired with behavioral test; no vacuous asserts. `[TEST]` |
| 7 | Resource leaks | COMPLIANT | `read_text` auto-closes; no bare `open()`/Session/connect. |
| 8 | Unsafe deserialization | COMPLIANT | `yaml.safe_load` (not `yaml.load`); subprocess args-list, no `shell=True`. `[SEC]` |
| 11 | Input validation / info leakage | COMPLIANT (1 low note) | git args hardcoded; repos.yaml path server-local. `{exc}`/`repo_path` in warns = low-sev info-leak channel → non-blocking Delivery Finding. `[SEC]` |
| 13 | Fix-introduced regressions | COMPLIANT | Broad except retained (no new escape class); `encoding="utf-8"` forces deterministic decode (hardening, not regression). `[RULE]` |

### Observations

1. `[VERIFIED][SILENT]` AC-1 `_get_git_info` warns then `return None` — `data_proxy.py:188-194` — fires only on present-but-broken git output (int-parse of `rev-list --count`); early returns guard missing git/.git. No steady-state spam.
2. `[VERIFIED][SEC][RULE]` AC-2 `_get_repos_config` `read_text(encoding="utf-8")` + warn — `data_proxy.py:209,218-225` — CWE-838 fixed; warn fires only when the file is PRESENT-but-broken (the `is_file()` gate skips absent config, confirmed by the missing-file green guard).
3. `[VERIFIED][SILENT]` AC-3 inner portrait try PRESERVED — `ws_push.py:494-502` — warn-in-place keeps `portrait_path=None` and returns the full persona; `resolve_portrait_path` self-swallows CDN errors and returns None on the common path (`portrait_resolver.py:78-91`), so no poll-loop spam. Removing the inner try would route the error to the outer catch-all and blank the panel — the test pins this.
4. `[SEC]` `{exc}`/`repo_path` interpolated into warnings — `data_proxy.py:194`, `ws_push.py:502` — low-severity info-leakage IF Frame ever forwards warnings to a network client. House-style-consistent; non-blocking series-wide Delivery Finding.
5. `[LOW]` AC-2 warning uses `p.name`, but both candidates share basename `repos.yaml` — `data_proxy.py:225` — can't distinguish which path failed; minor diagnostic nit, non-blocking Delivery Finding.
6. `[TEST][VERIFIED]` Inverse binding probe — reverted source to `origin/develop` keeping the new test file → **6 failed / 5 passed**: the 6 behavioral tests genuinely bind to the fix; the 5 intentional green guards held.
7. `[SIMPLE][VERIFIED]` Minimal diff (warn + encoding only), no over-engineering; all three return contracts preserved.
8. `[EDGE][VERIFIED]` Edge cases: empty/missing `repo_path` → early `None`; both repos.yaml candidates broken → 2 warns + fallback (accurate, not steady-state spam).
9. `[DOC][VERIFIED]` New comments accurately explain WHY each warn-then-degrade choice was made (esp. the AC-3 inner-try rationale); no stale/misleading comments introduced.

### Devil's Advocate

Suppose this code is broken. The most dangerous shape for a fail-loud sweep added to a *poll loop* is warn-spam: a `warnings.warn` placed over a condition that recurs every 5-second cycle would flood stderr forever and bury real signal — exactly the 160-15 `fetch_context` trap, where a constructor raised `TypeError` on every single call. Could AC-3 be that trap? `fetch_persona` runs each poll; if `resolve_portrait_path` raised on the common "no portrait / offline" path, the new warn would fire continuously. So I read the resolver: `portrait_resolver.py:78` returns `None` when no slug resolves, and lines 86-91 wrap the CDN fetch in its *own* `try/except Exception: return None` — it never raises on the steady-state path, only on an abnormal theme-discovery throw. The warned call is also pre-existing (the `try` body is unchanged), so a constant failure would already have broken the working portrait feature. Trap avoided. Next: could a confused operator with a latin-1 `repos.yaml` now get a hard failure where it previously "worked"? The `encoding="utf-8"` makes a non-UTF-8 file raise `UnicodeDecodeError` → caught → warn → single-repo fallback. That is louder than before, but the file *is* malformed for a UTF-8 config, the function still degrades, and this is the intended hardening, not a crash. Could a malicious user weaponise the warning? `repo_path`/`agent_name`/`p.name` are all server-local, framework-written strings, not HTTP input; the git subprocess uses an args list with `shell=False` and a `which`-resolved binary, so no command injection; the repos.yaml path derives from a launch-time env var, not a request parameter, so no traversal vector is opened by this diff. The residual `{exc}` interpolation could echo filesystem paths or a few bytes of file content into a warning — a real but low-severity leak that only matters if the warnings stream is ever network-exposed, which it is not here and which is a property of the entire sweep, not this PR. Finally, could the AC-1 change KeyError downstream? `get_git_all` reads `info["branch"]` only when `info` is truthy; the function still returns `None` on failure, so the guarded access is safe. No broken path survives scrutiny — the diff is correct, minimal, and well-tested.

**Subagent dispatch tags present:** `[EDGE]` `[SILENT]` `[TEST]` `[DOC]` `[TYPE]` `[SEC]` `[SIMPLE]` `[RULE]`.

**Handoff:** To SM (Edmund Blackadder) for finish-story.