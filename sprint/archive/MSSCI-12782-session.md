# MSSCI-12782: Bug: Debug Panel Formatting and Missing OTEL Data

**Status:** in_progress
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Jira:** MSSCI-12782
**Branch:** feat/MSSCI-12782-debug-panel-otel
**Epic:** epic-64 (MSSCI-12465)
**Assigned:** Keith Avery

## Context
This story addresses two issues with the Debug panel in Cyclist:
1. TOKEN STATS displays raw JSON instead of formatted UI
2. OTEL telemetry data (tool calls, spans, timing) not displaying

## Acceptance Criteria
- [ ] Token stats formatted as readable UI (cards or table)
- [ ] OTEL spans/traces displayed (tool invocations, durations)
- [ ] Hierarchical view of agent activity

## Technical Approach

The DebugPanel needs to:
1. **Format token stats** - Use the existing `<dl>` structure but add `data-testid` attributes and ensure stats render as formatted cards, not raw JSON
2. **Add OTEL spans section** - Subscribe to `auditLog.getEntries()` and `auditLog.onEntry()` to display tool events
3. **Group spans by tool type** - Create collapsible groups showing tool name, count, aggregate duration, and individual span details

Key infrastructure already exists:
- `auditLog` IPC API in preload.ts (getEntries, getTypes, getStats, onEntry)
- `otlp-receiver.ts` already captures and stores tool events
- Existing pattern from tier/token breakdown can be extended

## Files
- packages/cyclist/src/public/components/panels/DebugPanel.tsx (main implementation)
- packages/cyclist/src/preload.ts (auditLog API already exists)
- packages/cyclist/src/public/styles/tailwind.css (styles for span groups)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Bug fix with clear acceptance criteria requiring UI changes

**Test Files:**
- `packages/cyclist/tests/MSSCI-12782-debug-panel-otel.test.ts` - 20 tests covering all ACs

**Tests Written:** 20 tests covering 3 ACs
- AC1: Token stats formatting (5 tests)
- AC2: OTEL spans display (7 tests)
- AC3: Hierarchical activity view (5 tests)
- Integration: Real-time updates (3 tests)

**Status:** RED (all 20 tests failing - ready for Dev)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/panels/DebugPanel.tsx` - Added OTEL spans section with tool groups, updated token stats with data-testids
- `packages/cyclist/tests/MSSCI-12782-debug-panel-otel.test.ts` - Fixed async timing in tests

**Tests:** 20/20 passing (GREEN)
**PR:** #615 - feat(MSSCI-12782): Debug Panel OTEL Telemetry Display
**Branch:** feat/MSSCI-12782-debug-panel-otel (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** electronAPI.auditLog.getEntries() → setSpans() → groupSpansByTool() → React render (safe - React auto-escapes)
**Pattern observed:** Good use of optional chaining for null safety at `DebugPanel.tsx:176-201`
**Error handling:** Null API guard at line 177, optional chaining throughout
**Tests:** 20/20 passing

| Severity | Issue | Location |
|----------|-------|----------|
| [VERIFIED] | Data flow properly wired | `DebugPanel.tsx:196-201` |
| [VERIFIED] | Comprehensive test coverage | 20 tests |
| [VERIFIED] | Security safe (no XSS) | JSX auto-escapes |
| [LOW] | No .catch() on getEntries | `DebugPanel.tsx:196` |
| [LOW] | Unbounded span growth | Acceptable for debug panel |

**PR Merged:** #615 merged to develop
**Handoff:** To SM for finish-story

## Handoff
- **Timestamp (SM→TEA):** 2026-02-02T21:35:00Z
- **Timestamp (TEA→Dev):** 2026-02-02T21:45:00Z
- **Timestamp (Dev→Reviewer):** 2026-02-02T22:00:00Z
- **Timestamp (Reviewer→SM):** 2026-02-02T22:40:00Z
- **From:** reviewer
- **To:** sm
- **Phase:** finish
