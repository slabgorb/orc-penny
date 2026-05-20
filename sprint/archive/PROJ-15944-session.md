# Story 136-12: pf CLI missing setup command — users try CLI before discovering skill

## Story Details
- **ID:** 136-12
- **Jira Key:** PROJ-15944
- **Workflow:** trivial
- **Assigned to:** keithavery

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-03T11:32:42Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-02T21:11:59Z | 2026-03-02T21:14:09Z | 2m 10s |
| implement | 2026-03-02T21:14:09Z | 2026-03-03T09:45:54Z | 12h 31m |
| review | 2026-03-03T09:45:54Z | 2026-03-03T11:32:42Z | 1h 46m |
| finish | 2026-03-03T11:32:42Z | - | - |

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

## SM Assessment

**Story:** 136-12 — pf CLI missing setup command
**Points:** 1 | **Priority:** p2 | **Workflow:** trivial

**Summary:** Users try `pf setup` at the CLI before discovering the `/setup` skill. Need to add a `pf setup` command that either runs the setup flow directly or directs users to the skill.

**Routing:** Trivial workflow → Toby Ziegler (Dev) for implementation, then Josh Lyman (Reviewer).

**Risks:** None — straightforward 1-point addition.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/cli.py` - Added `setup` as lazy command alias for `init`; moved `init` to hidden backward-compat aliases

**Tests:** N/A — CLI alias registration, no new logic to test
**Branch:** develop (pushed)

**Handoff:** To Josh Lyman (Reviewer) for code review.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `pf setup` → `LazyGroup.get_command` → `import_module("pf.init.cli")` → `init()` → `init_project()` (safe — hardcoded module paths, local fs only)
**Pattern observed:** Reuses existing `_HIDDEN_ALIASES` mechanism for backward compat at `cli.py:113`
**Error handling:** Inherits `init` command's error paths — `SystemExit(1)` on missing dist root, result objects for failures
**Tests:** 55/55 existing init tests passing (GREEN)
**Handoff:** To Leo McGarry (SM) for finish-story