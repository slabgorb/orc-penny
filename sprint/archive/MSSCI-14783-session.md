# Story 100-8: Sprint panel: fix next-up to honor assigned_to field

**Jira:** MSSCI-14783
**Epic:** 100 — UI Tweak Bucket
**Points:** 2
**Priority:** P1
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14783-sprint-panel-fix-next-up

## Description

The Sprint panel's "next up" display should honor the `assigned_to` field when determining which story to show next. Currently it may not be filtering or prioritizing based on assignment.

## Technical Context

- **Sprint panel:** Located in Cyclist (`packages/cyclist/src/components/`) — look for SprintPanel
- **Sprint data:** Stories have an `assigned_to` field in sprint YAML
- **Scope:** Fix the next-up logic to filter/prioritize by assigned_to

## Acceptance Criteria

- [ ] Sprint panel next-up respects the assigned_to field
- [ ] Unassigned stories still appear when no assigned filter applies
- [ ] Panel displays correctly after the fix

### SM Assessment

- Story 100-8 set up for trivial workflow (SM → Dev → Reviewer → SM)
- Feature branch created in pennyfarthing repo: feature/MSSCI-14783-sprint-panel-fix-next-up
- Jira MSSCI-14783 claimed and moved to In Progress
- Sprint panel next-up logic needs to honor assigned_to field
- Handing off to Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/sprint-data.ts` — Added `userEmail` param to `getSprintData()`, rewrote next-story logic to prefer assigned stories
- `packages/cyclist/src/websocket.ts` — Wired `getUserEmail()` from OTEL receiver into both WebSocket call sites

**Tests:** N/A (trivial workflow, no TEA phase)
**PR:** #836 — fix(sprint-panel): next-up honors assigned_to field
**Branch:** feature/MSSCI-14783-sprint-panel-fix-next-up (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `getUserEmail()` → `getSprintData(projectDir, userEmail)` → `SprintData.nextStory` → WebSocket → `useSprint` → `SprintPanel` next-up section. Complete chain.
**Pattern observed:** Three-tier fallback (assigned→unassigned→any) at `sprint-data.ts:424-426`
**Error handling:** Null email gracefully degrades to original behavior at `sprint-data.ts:427-429`
**Wiring:** Both WebSocket call sites updated (`websocket.ts:832,1565`). No orphaned callers.
**Observations:** 5/5 verified. No blocking issues found.

**Handoff:** To SM for finish-story

## Handoff Complete

**Status:** SUCCESS
**Timestamp:** 2026-02-12
**Next Agent:** SM (Scrum Master)
**Action Required:** Execute finish-story to close out story 100-8 and move Jira MSSCI-14783 to Done

The PR has been merged successfully. All acceptance criteria met.
