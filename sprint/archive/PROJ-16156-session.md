# Story 141-13: Fix Jira story transition — claim stories as In Progress during setup

**Jira:** PROJ-16156
**Epic:** 141 — Tech Debt Audit
**Points:** 1
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** fix/PROJ-16156-jira-claim-transition

## Story Context

When the SM agent runs `pf jira claim {JIRA_KEY}` during story setup, Jira stories are assigned to the current user but are not transitioned to "In Progress." The `claim_story()` function in `pf/jira/claim.py` wraps the transition call in `except Exception: pass` (lines 131-155), silently swallowing all failures. The result is a partial claim: assignment succeeds but status never moves.

## Acceptance Criteria

**AC1:** `pf jira claim {JIRA_KEY}` transitions the story to "In Progress" in Jira

**AC2:** Transition failures are reported, not silently swallowed — return `{success: False, drift: True, remediation: ...}`

**AC3:** Story ID lookup failure does not silently skip the transition — use `read_sprint()` (which merges shards)

**AC4:** Sprint YAML status updates to `in_progress` with `started` date when claim succeeds

## SM Assessment

1-point trivial bug fix. Root cause is clear: silent exception handling in `claim_story()`. Primary file: `pennyfarthing/pennyfarthing-dist/src/pf/jira/claim.py`. Context doc at `sprint/context/context-story-141-13.md` has full technical details including line numbers, scope boundaries, and test command.

Routing to Dev (Toby Ziegler) — trivial workflow, straight to implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/jira/claim.py` — Replaced two `except Exception: pass` blocks with proper error surfacing. Story ID lookup failure now returns `{success: False, drift: True, remediation: ...}`. Transition failures propagate `drift`/`remediation` from `transition_story()` result. Removed redundant second `read_sprint()` call for `assigned_to` update (now uses same data path).

**Tests:** 28/28 passing (GREEN)
**Branch:** fix/PROJ-16156-jira-claim-transition (pushed)

**Handoff:** To Reviewer (Josh Lyman) for code review

## Delivery Findings

### Dev (implementation)

- No upstream findings during implementation.

### Reviewer (code review)

- **Improvement** (non-blocking): `assigned_to` update block (claim.py:182-192) lacks error handling — could throw instead of returning result object on unexpected YAML errors. Affects `pennyfarthing-dist/src/pf/jira/claim.py` (wrap in try/except, return result dict on failure). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `issue_key` → `check_availability()` → Jira API → `assign_issue_sync()` → Jira API → `read_sprint()` → story lookup → `transition_story()` → YAML write + Jira transition → `read_sprint()` → `assigned_to` write. All paths return result dicts.
**Pattern observed:** Drift detection with remediation hint follows `story_transition.py` convention at `claim.py:151-152,165-170`
**Error handling:** Assign, transition, and lookup failures all surface properly. Only `assigned_to` write (line 182-192) lacks guard — MEDIUM, not blocking.
**Tests:** 28/28 jira tests + 4/4 claim-specific tests passing
**Handoff:** To SM (Leo McGarry) for finish-story