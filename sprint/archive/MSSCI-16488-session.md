---
story_id: "148-26"
jira_key: "MSSCI-16488"
epic: "MSSCI-16421"
workflow: "trivial"
---
# Story 148-26: Bug: Peloton should never open more than one tmux pane per agent role

## Story Details
- **ID:** 148-26
- **Jira Key:** MSSCI-16488
- **Workflow:** trivial
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-23T14:18:04Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-23 | 2026-03-23T14:10:45Z | 14h 10m |
| implement | 2026-03-23T14:10:45Z | 2026-03-23T14:15:01Z | 4m 16s |
| review | 2026-03-23T14:15:01Z | 2026-03-23T14:18:04Z | 3m 3s |
| finish | 2026-03-23T14:18:04Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- No upstream findings during code review.

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- Dev logged "No deviations from spec" — ✓ ACCEPTED by Reviewer: Confirmed. Fix is minimal dedup logic that matches the story title exactly.

## Sm Assessment

**Story:** 148-26 — Bug: Peloton should never open more than one tmux pane per agent role (1pt, trivial)
**Jira:** MSSCI-16488 — already assigned to Keith Avery
**Repos:** pennyfarthing
**Branch:** feat/148-26-peloton-single-tmux-pane-per-role (on develop)

**Routing:** Trivial workflow — setup → implement (Dev) → review → finish.

**Recommendation:** Hand off to Dev (White Rabbit) for implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/peloton/pane_orchestrator.py` — deduplicate roles in spawn_agent_panes input + guard _try_create_portrait against existing portraits

**Root Cause:** Two issues in `pane_orchestrator.py`:
1. `spawn_agent_panes` iterates `scenario_phases` without deduplication. When a workflow has the same agent in multiple phases (e.g., TEA in "red" and "verify"), `_create_pane` correctly returns the existing pane, BUT `_try_create_portrait` runs again and creates a duplicate portrait pane.
2. `_try_create_portrait` had no guard against existing portrait panes for the same role.

**Fix:** Added input dedup in `spawn_agent_panes` (lines 127-132) + early return in `_try_create_portrait` if `get_portrait_pane(role)` already exists (line 341).

**Tests:** 155/155 passing (GREEN)
**Branch:** feat/148-26-peloton-single-tmux-pane-per-role (pushed)

**Handoff:** To Queen of Hearts (Reviewer) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 155/155 tests pass, no smells |
| 2 | reviewer-edge-hunter | Yes | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Yes | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Yes | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | clean | none | N/A — no external attack surface, TOCTOU not applicable (single-threaded) |
| 8 | reviewer-simplifier | Yes | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (2 active, 7 disabled)
**Total findings:** 0 confirmed, 0 dismissed

### Rule Compliance

**SOUL.md Principle 10 (Return Results, Don't Throw):** No new return paths — existing `{success, data?, error?}` preserved. Compliant.
**SOUL.md Principle 2 (One Truth, One Place):** Dedup in `spawn_agent_panes`, guard in `_try_create_portrait`. Two layers but different purposes (input sanitization vs defense-in-depth). Compliant.

### Devil's Advocate

Is this fix actually complete? Let me argue it's broken.

**What if `_create_pane` is called directly, bypassing `spawn_agent_panes`?** The `_create_pane` method itself has its own dedup via `get_pane(role)` (line 272). But `_try_create_portrait` is only called from `spawn_agent_panes`, not from `_create_pane`. So if someone calls `_create_pane` directly, they don't get portraits at all — not a duplication concern.

**What if `spawn_agent_panes` is called multiple times on the same orchestrator?** Say first call with `["tea", "dev"]`, second call with `["dev", "reviewer"]`. First call: creates tea+dev panes. Second call: dedup within `["dev", "reviewer"]` produces `["dev", "reviewer"]`. `_create_pane("dev")` returns existing. `_try_create_portrait("dev", ...)` now hits the guard — portrait already exists. `_create_pane("reviewer")` creates new. `_try_create_portrait("reviewer", ...)` creates new portrait. This is correct.

**What about the result dict?** `spawn_agent_panes` returns `{role: ManagedPane}`. If called twice, only the second call's result is visible to the caller. But the orchestrator's internal `self.panes` list has ALL panes. This isn't a bug — the method signature implies one-shot usage.

**What if `scenario_phases` has a role that already has a pane from a previous call but NOT in the dedup set?** E.g., first call `["tea"]`, second call `["tea", "dev"]`. Second call: dedup produces `["tea", "dev"]`. `_create_pane("tea")` finds existing via `get_pane`, returns it. `_try_create_portrait` guard catches existing portrait. Correct.

**Devil's advocate conclusion:** No new findings. The fix is sound — dedup at input and guard at portrait creation are both necessary and sufficient.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `scenario_phases` → dedup via seen set → `unique_roles` → `_create_pane(role)` per role → `_try_create_portrait(role, theme, pane)` with guard. Single-threaded, no TOCTOU.

**Pattern observed:** [VERIFIED] Dedup uses `seen` set + ordered list — preserves first-occurrence order. Evidence: pane_orchestrator.py:128-132.

**Error handling:** [VERIFIED] No new error paths. Dedup is silent (expected behavior). Guard is silent early return. Existing error handling for missing panes unchanged.

**Wiring:** [VERIFIED] `get_portrait_pane(role)` at line 163 correctly constructs `f"{role}-portrait"` key, matching the role assigned at line 374 (`f"{role}-portrait"`).

**Observations:**
1. [VERIFIED] Input dedup preserves order — pane_orchestrator.py:128-132 uses `seen` set + append
2. [VERIFIED] Portrait guard uses `get_portrait_pane` — pane_orchestrator.py:339 correctly checks `f"{role}-portrait"` pattern
3. [VERIFIED] `_create_pane` already had dedup at line 272 — the input dedup is defense-in-depth, preventing unnecessary processing
4. [VERIFIED] No TOCTOU — single-threaded Python, no async between check and create
5. [VERIFIED] 155 peloton tests pass — broad coverage of pane lifecycle

[EDGE] No findings (disabled)
[SILENT] No findings (disabled)
[TEST] No findings (disabled)
[DOC] No findings (disabled)
[TYPE] No findings (disabled)
[SEC] No findings — clean (no external attack surface)
[SIMPLE] No findings (disabled)
[RULE] No findings (disabled)

**Handoff:** To The Mad Hatter (SM) for finish-story