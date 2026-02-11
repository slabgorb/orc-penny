# Story 100-5: Sprint panel: show closed epics for current sprint

**Jira:** MSSCI-14780
**Epic:** 100 — UI Tweak Bucket
**Points:** 2
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing-orchestrator
**Branch:** feat/100-5-sprint-panel-show-closed-epics
**Assigned:** Keith Avery

## Acceptance Criteria

- [ ] SprintPanel displays closed/completed epics from current sprint
- [ ] Closed epics shown in a visually distinct section (grayed out, collapsed by default)
- [ ] Each closed epic displays its title, point count, and completion date
- [ ] Responsive design maintains layout on all panel widths
- [ ] Data loads from `current-sprint.yaml` completed epics section
- [ ] Updates in real-time when sprint YAML changes

## Technical Context

Story 100-5 is part of Epic 100 (UI Tweak Bucket), a collection of small UI tweaks and polish for Cyclist components. This story focuses on enhancing the SprintPanel to display closed/completed epics from the current sprint.

**Key Files:**
- `pennyfarthing/packages/cyclist/src/public/components/panels/SprintPanel.tsx` - Main panel component
- `pennyfarthing/packages/cyclist/src/public/hooks/useSprint.ts` - React hook for sprint data
- `pennyfarthing/packages/cyclist/src/sprint-data.ts` - Sprint data aggregation
- `sprint/current-sprint.yaml` - Current sprint metadata

**Related Stories:**
- 100-6: Sprint panel: sprint metrics from completed/current/future
- 100-7: Sprint panel: play button to start stories inline
- 100-8: Sprint panel: fix next-up to honor assigned_to field

The SprintPanel currently displays the current/active story. This story extends it to also show closed epics in a separate section, providing better visibility into sprint completion.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/panels/SprintPanel.tsx` - Split epics into active/completed sections, extracted EpicGroup component
- `packages/cyclist/src/public/styles/tailwind.css` - Added completed-epics section styling (opacity 0.5, hover 0.7)
- `packages/cyclist/tests/MSSCI-14189-enhanced-sprint-panel.test.tsx` - Updated section hierarchy test for flexible section ordering

**Tests:** 40/40 passing (GREEN)
**PR:** #811 — feat(cyclist): show closed epics in Sprint panel
**Branch:** feat/100-5-sprint-panel-show-closed-epics (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** WebSocket → useSprint hook → data.epics → filter by isEpicCompleted → activeEpics/completedEpics → EpicGroup render (safe, no data layer changes)
**Pattern observed:** Clean component extraction of EpicGroup at SprintPanel.tsx:246, follows existing component patterns (ContextIndicator, StatusBadge, PriorityDot)
**Error handling:** Archive/promote error handling preserved through onArchive prop delegation at SprintPanel.tsx:323
**Low observations:** Empty "Current Epics" heading when all epics done (SprintPanel.tsx:575); no dedicated test for completed-epics-section testid
**Handoff:** To SM for finish-story

## Session Log

- SM: Story setup complete, routing to Dev
- SM: Handoff to Dev for implementation
- Dev: Implementation complete, PR #811 created, handing off to Reviewer
- Handoff: Tests passing (GREEN), advancing from implement → review phase
- Reviewer: APPROVED — clean extraction, correct behavior, no blocking issues
