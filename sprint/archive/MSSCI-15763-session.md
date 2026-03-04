# Standalone: Move sprint calculations to backend

**Jira:** MSSCI-15763
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-15763-move-sprint-calcs-to-backend
**PR:** 1165
**Started:** 2026-02-27
**Completed:** 2026-02-27

---

## Description

Move epic progress, completion status, and hasContext computation from SprintPanel frontend to sprint-data.ts backend. Fixes cancelled-points bug where completed epics showed <100% progress because calculateEpicProgress() only counted 'done' while isEpicCompleted() also counted 'cancelled'. Adds context file detection per ADR-0029 patterns.

## Files Changed

| File | Change |
|------|--------|
| packages/core/src/server/sprint-data.ts | Add EpicProgress, computation helpers, context checks, active/completed split |
| packages/cyclist/src/sprint-data.ts | Same changes (identical duplicate) |
| packages/core/src/public/hooks/useSprint.ts | Add EpicProgress, isCompleted, completedEpics types |
| packages/core/src/public/components/panels/SprintPanel.tsx | Remove calculateEpicProgress/isEpicCompleted, consume pre-computed data |
| packages/core/src/server/sprint-data.test.ts | 18 new tests for computation helpers |
