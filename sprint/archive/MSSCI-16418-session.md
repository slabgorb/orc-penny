---
story_id: "147-7"
jira_key: "MSSCI-16418"
epic: "MSSCI-16411"
workflow: "trivial"
---
# Story 147-7: Add repos API endpoints to WheelHub

## Story Details
- **ID:** 147-7
- **Jira Key:** MSSCI-16418
- **Epic:** MSSCI-16411 (Configuration Gap Closure)
- **Workflow:** trivial
- **Stack Parent:** none (not stacked)
- **Points:** 1
- **Priority:** p1

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-23T13:38:50Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-23T13:26:53Z | 2026-03-23T13:28:01Z | 1m 8s |
| implement | 2026-03-23T13:28:01Z | 2026-03-23T13:32:36Z | 4m 35s |
| review | 2026-03-23T13:32:36Z | 2026-03-23T13:38:50Z | 6m 14s |
| finish | 2026-03-23T13:38:50Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
### Reviewer (code review)
- **Improvement** (non-blocking): PATCH `/api/repos/{name}` accepts arbitrary field names with no allowlist. Story 147-8 (validators) will add field validation to `set_repo_field`, but the route itself should also have an allowlist of mutable fields. Affects `pennyfarthing-dist/src/pf/frame/routes/repos.py` (add field allowlist to patch_repo). *Found by Reviewer during code review.*

### Dev (implementation)
- **Improvement** (non-blocking): Pre-existing `load_persona()` signature mismatch in `data_proxy.py:58` — calls with `(project_dir, session_id=session_id)` but function now expects `(agent_name, project_root)`. Causes `TestBackwardCompatibility::test_error_responses_have_error_field` to fail. Not related to this story. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (needs signature update). *Found by Dev during implementation.*

## Impact Summary

**Upstream Effects:** 2 findings (0 Gap, 0 Conflict, 0 Question, 2 Improvement)
**Blocking:** None

- **Improvement:** PATCH `/api/repos/{name}` accepts arbitrary field names with no allowlist. Story 147-8 (validators) will add field validation to `set_repo_field`, but the route itself should also have an allowlist of mutable fields. Affects `pennyfarthing-dist/src/pf/frame/routes/repos.py`.
- **Improvement:** Pre-existing `load_persona()` signature mismatch in `data_proxy.py:58` — calls with `(project_dir, session_id=session_id)` but function now expects `(agent_name, project_root)`. Causes `TestBackwardCompatibility::test_error_responses_have_error_field` to fail. Not related to this story. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py`.

### Downstream Effects

- **`pennyfarthing-dist/src/pf/frame/routes`** — 2 findings

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- Dev logged "No deviations from spec" — ✓ ACCEPTED by Reviewer: Confirmed. Implementation matches all 6 ACs exactly. The AC5 note about `all_state_routers` vs `all_repos_routers` is a valid clarification, not a deviation.

## Sm Assessment

**Story:** 147-7 — Add repos API endpoints to WheelHub (1pt, trivial)
**Jira:** MSSCI-16418 — already assigned to Keith Avery
**Repos:** pennyfarthing
**Branch:** feat/147-7-add-repos-api-endpoints-wheelhub (on develop)

**Routing:** Trivial workflow — setup → implement (Dev) → review → finish. No TEA phase needed for a 1-point story.

**Recommendation:** Hand off to Dev (White Rabbit) for implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/routes/repos.py` — added PATCH /{name} endpoint (uses set_repo_field), added GET /pr-title-format endpoint

**Tests:** 190/191 passing (GREEN) — 1 pre-existing failure unrelated to this story
**Branch:** feat/147-7-add-repos-api-endpoints-wheelhub (pushed)

**AC Coverage:**
1. `repos_router` with `/api/repos` prefix — pre-existing, verified
2. `GET /api/repos/` — pre-existing, returns all repo configs via load_repos_yaml
3. `PATCH /api/repos/{repo_name}` — added, delegates to set_repo_field, supports multi-field updates
4. `GET /api/repos/pr-title-format` — added, returns global PR title format
5. Router registered via all_repos_routers in app.py — pre-existing
6. Error responses follow existing pattern (JSONResponse with error key) — verified

**Note:** The epic context says "add repos_router to all_state_routers" but the router is already registered via `all_repos_routers` which is separately included in `app.py`. This is the correct pattern — repos routes are a distinct route group, not state routes.

**Handoff:** To Queen of Hearts (Reviewer) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 185 repos tests pass, 67 frame routes pass, 3 pre-existing failures (persona sig mismatch) |
| 2 | reviewer-edge-hunter | Yes | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Yes | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Yes | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 4 | confirmed 1, dismissed 3 |
| 8 | reviewer-simplifier | Yes | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (2 active, 7 disabled via settings)
**Total findings:** 1 confirmed (medium), 3 dismissed

### Security Findings Disposition

1. **[SEC] Arbitrary field injection — no allowlist on PATCH fields** (high confidence)
   - **Decision: Confirmed as [MEDIUM]** — `set_repo_field` accepts any field name/value (repos.py:318-320). However: (a) Frame binds to 127.0.0.1 only, (b) story 147-8 (validators) is the planned follow-up that adds field validation, (c) the PATCH endpoint correctly delegates to `set_repo_field` and will inherit validators when added. Not blocking for a localhost-only config editor. Logged as delivery finding.

2. **Unsanitized repo name in path parameter** (medium confidence)
   - **Decision: Dismissed** — `set_repo_field` already validates repo_name exists at repos.py:315 and returns `{success: False}` if not found. The route collects this as an error. The validation exists, just in the library layer not the route layer. Consistent with the GET `/{name}` handler which also delegates name validation to `_load_repos_yaml`.

3. **Write amplification DoS via large body** (medium confidence)
   - **Decision: Dismissed** — Frame is localhost-only (launcher.py:127). A legitimate client sends 1-3 fields. O(N) file writes on a small YAML config is negligible. No existing endpoints in state.py have body size limits (e.g., `patch_settings` at state.py:64-68). This is consistent with the pre-existing pattern.

4. **Info leakage via error messages** (low confidence)
   - **Decision: Dismissed** — Frame serves only localhost. Internal paths are already visible to any local process. This is consistent with every other error response in the codebase (e.g., state.py error handlers).

### Rule Compliance

**SOUL.md Principle 10 (Return Results, Don't Throw):**
- `get_pr_title_format` (repos.py:98): Returns JSONResponse — compliant
- `patch_repo` (repos.py:124): Delegates to `set_repo_field` which returns result dicts, never throws — compliant

**SOUL.md Principle 2 (One Truth, One Place):**
- No definition duplication introduced. `_load_repos_yaml` and `_serialize_repo` helpers reused. `set_repo_field` imported, not reimplemented — compliant

**CLAUDE.md Rule: Never edit `.pennyfarthing/` symlinked dirs:**
- The PATCH endpoint writes to repos.yaml via `set_repo_field`. repos.yaml is NOT symlinked (it's a local config file) — compliant

### Devil's Advocate

This code looks clean. Too clean? Let me argue it's broken.

**The partial write problem is real.** Imagine a UI that sends `{"description": "New desc", "branch_strategy": "invalid_value"}`. The first field writes successfully to disk. The second fails. The user gets a 400 error. They retry. The first field has been silently persisted from the first attempt. If 147-8 validators reject `branch_strategy`, the user sees "Some fields failed to update" but doesn't realize `description` was already written. In a concurrent scenario — two browser tabs editing different repos — the sequential read-modify-write in `set_repo_field` could produce a TOCTOU race: Tab A reads, Tab B reads, Tab A writes, Tab B writes (overwriting Tab A's changes). However, this is a localhost config editor with typically one user. The race is theoretical.

**What about malicious build_command?** If someone writes `{"build_command": "rm -rf /"}` via PATCH, that string gets persisted to repos.yaml. Downstream, `pf ci` or similar tooling executes `build_command` in a shell. This is command injection — but only exploitable by someone who already has localhost access, which means they already have shell access and don't need the API to run `rm -rf /`. The threat model for localhost APIs is fundamentally different from remote APIs.

**What if repos.yaml is corrupted?** `yaml.dump` could produce invalid YAML if the value contains problematic characters. But `yaml.safe_load` + `yaml.dump` round-trips cleanly for the types involved (strings, lists, dicts, bools). Not a real concern.

**Devil's advocate conclusion:** No new findings beyond the confirmed [MEDIUM] field injection. The partial write concern is real but acceptable for a 1-point localhost config editor story.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** HTTP PATCH body → `request.json()` → field iteration → `set_repo_field(name, field, value, project_root)` → yaml read-modify-write to `.pennyfarthing/repos.yaml`. Safe because: input validation at route level (dict check), repo name validation in set_repo_field (repos.py:315), localhost-only binding (launcher.py:127).

**Pattern observed:** [VERIFIED] Follows existing route pattern from state.py — router prefix, JSONResponse returns, error key pattern. Evidence: repos.py:69 mirrors state.py:34. Route ordering correct: static `/pr-title-format` before parameterized `/{name}` at repos.py:97 vs 108.

**Error handling:** [VERIFIED] `set_repo_field` returns `{success, data?, error?}` (repos.py:325-330) — compliant with SOUL.md principle 10. Route handler collects errors without throwing (repos.py:134-141). Invalid JSON body → Starlette 422. Empty/non-dict body → 400 (repos.py:129-130).

**Security analysis:** [SEC] Localhost-only (127.0.0.1). No auth needed — consistent with all Frame endpoints. Field injection mitigated by planned 147-8 validators.

**Wiring:** [VERIFIED] Router registered in app.py via `all_repos_routers` (app.py:169,184). `set_repo_field` import is deferred (repos.py:126) — no circular import risk.

**Observations:**
1. [VERIFIED] `/pr-title-format` registered before `/{name}` — repos.py:97 vs 108 — correct FastAPI route ordering
2. [VERIFIED] Error responses use `{"error": ...}` pattern — repos.py:103, 130, 144 — consistent with state.py
3. [VERIFIED] `set_repo_field` returns result dicts per SOUL.md #10 — repos.py:126, git/repos.py:325-330
4. [SEC] No field allowlist on PATCH — confirmed medium, mitigated by localhost + planned 147-8
5. [VERIFIED] Router properly included in `all_repos_routers` — repos.py:153, app.py:169

[EDGE] No findings (disabled)
[SILENT] No findings (disabled)
[TEST] No findings (disabled)
[DOC] No findings (disabled)
[TYPE] No findings (disabled)
[SEC] 1 confirmed medium — field injection, mitigated by localhost binding and planned 147-8 validators
[SIMPLE] No findings (disabled)
[RULE] No findings (disabled)

**Handoff:** To The Mad Hatter (SM) for finish-story