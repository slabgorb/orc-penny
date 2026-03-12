# Standalone: Add tests for core API routes (settings through welcome)

**Jira:** MSSCI-16209
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16209-add-tests-core-api-routes
**PR:** 1288
**Started:** 2026-03-05
**Completed:** 2026-03-05

---

## Description

Add test files for 8 API routes: settings, stats, story, telemetry, theme-agents, todos, token-stats, welcome. 81 tests covering router shape, response shapes, happy paths, and error cases.

## Files Changed

| File | Change |
|------|--------|
| packages/core/src/server/api/settings.test.ts | Added |
| packages/core/src/server/api/stats.test.ts | Added |
| packages/core/src/server/api/story.test.ts | Added |
| packages/core/src/server/api/telemetry.test.ts | Added |
| packages/core/src/server/api/theme-agents.test.ts | Added |
| packages/core/src/server/api/todos.test.ts | Added |
| packages/core/src/server/api/token-stats.test.ts | Added |
| packages/core/src/server/api/welcome.test.ts | Added |
