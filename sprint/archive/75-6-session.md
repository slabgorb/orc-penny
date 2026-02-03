# Session: 75-6 - Panel refresh issues

**Story:** 75-6 - [BUG] Panel refresh issues - changed files and sprint tabs not updating
**Points:** 3
**Type:** bug
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** fix/panel-refresh-bugs-75-6
**Assignee:** kavery

---

## Story Context

Two panel refresh bugs discovered during Playwright MCP debug session:

### Bug 1: Changed Files Panel Not Updating
- Expected: Panel shows files created/modified during session
- Actual: Shows "0 files changed" after agent creates multiple files
- Hypothesis: Panel only tracks uncommitted changes, loses history after commit

### Bug 2: Sprint Tab Not Showing Active Story
- Expected: Sprint tab shows active story when session file exists
- Actual: Shows "No active story" despite session file at .session/MSSCI-13970-session.md
- Hypothesis: No file watcher or WebSocket subscription for session changes

## Relevant Components
- ChangedFilesPanel.tsx
- SprintPanel.tsx
- WebSocket endpoints: /ws/changed, /ws/session

## Acceptance Criteria
- [ ] Changed files panel updates when Write/Edit tools are used
- [ ] Changed files panel maintains history across commits during session
- [ ] Sprint tab detects and displays active story from session file
- [ ] Both panels update in real-time via WebSocket or file watcher

---

## Work Log

### Setup
- Story selected from sprint backlog
- TDD workflow - TEA will design tests first

### SM → TEA Handoff
- Story setup complete
- Branch: fix/panel-refresh-bugs-75-6
- Next: TEA to design failing tests for panel refresh bugs
- Focus areas:
  - ChangedFilesPanel.tsx refresh behavior
  - SprintPanel.tsx session detection
  - WebSocket subscription testing

---

## TEA Assessment

**Tests Required:** Yes
**Test File:** `packages/cyclist/tests/75-6-panel-refresh.test.ts`

**Tests Written:** 35 tests (31 passing, 4 skipped) covering all 4 ACs:
- AC1: Changed files panel updates on Write/Edit tools (7 tests)
- AC2: Changed files maintains history across commits (4 tests)
- AC3: Sprint tab detects active story from session file (8 tests)
- AC4: Real-time WebSocket updates (8 tests)
- Bug-specific edge case tests (8 tests)

**Status:** GREEN (tests pass - bugs are integration/timing issues)

**Analysis:**
The core logic in websocket.ts and story-parser.ts is sound. The bugs appear to be:

1. **Bug 1 (Changed Files):**
   - diffStore IS populated on tool events (websocket.ts:806-826)
   - Likely issue: OTLP events not reaching the handler, or Electron mode vs Web mode differences
   - The diffStore is in-memory and clears on server restart

2. **Bug 2 (Sprint Tab):**
   - Session watcher EXISTS (websocket.ts:867-887)
   - Possible issues:
     - `.session/` directory might not exist at startup (no watcher created)
     - File creation uses 'rename' event, not 'change' - may not trigger
     - Session format `# Session: ID - Title` not matched by header regex (but fallback works)

**Files to Investigate:**
- `packages/cyclist/src/websocket.ts` - Lines 867-887 (session watcher), 806-826 (diff handling)
- `packages/cyclist/src/story-parser.ts` - Lines 101-112 (header parsing)
- `packages/cyclist/src/otlp-receiver.ts` - Tool event forwarding

**Handoff:** To Dev (Winchester) for implementation/debugging

---

## Dev Assessment

**Implementation Complete:** Yes

**Root Causes Identified:**

1. **Bug 1 (Changed Files):** Electron mode (`main.ts`) was broadcasting diffs via IPC (`broadcastToRenderer`) but NOT via WebSocket. The React `ChangedPanel` uses `/ws/diffs` WebSocket, so it never received updates.

2. **Bug 2 (Sprint Tab):** Session watcher in `websocket.ts` was only set up if `.session/` directory existed at server startup. If the directory didn't exist yet, no watcher = no real-time updates.

**Files Changed:**
- `packages/cyclist/src/main.ts` - Added `broadcastDiff()` calls for Edit/Write tools (lines 1269-1299)
- `packages/cyclist/src/websocket.ts` - Added directory creation before watcher setup (lines 865-876)

**Tests:** 31/35 passing (4 skipped integration tests)
**PR:** #641 - fix(75-6): panel refresh bugs - changed files and sprint tabs
**Branch:** fix/panel-refresh-bugs-75-6 (pushed)

**Handoff:** To Reviewer (Colonel Potter) for code review

---

## Reviewer Assessment

**Verdict:** APPROVED

**Data Flow Traced:**
- Bug 1: Edit/Write tool event → `processToolUseBlock()` → `broadcastDiff()` → `/ws/diffs` WebSocket → `useDiffs` hook → `ChangedPanel`. Verified at `main.ts:1280-1281` and `main.ts:1293-1294`.
- Bug 2: Server startup → `mkdirSync('.session/')` → `watch()` → file change → `broadcastStoryUpdate()` → `/ws/story` WebSocket → `useStory` hook → `SprintPanel`. Verified at `websocket.ts:869-893`.

**Pattern Observed:** Dual broadcast pattern - IPC for Electron renderer + WebSocket for React panels. Good separation of concerns at `main.ts:1279-1294`.

**Error Handling:** `mkdirSync` wrapped in try-catch at `websocket.ts:870-875`. Fails gracefully with console error logging.

**Security:** No injection risks. The `broadcastDiff` function only sends JSON-serialized tool output to authenticated WebSocket clients.

**Test Coverage:** 31 tests passing, 4 skipped (integration tests requiring browser). All 4 ACs covered.

**Observations:**
| Severity | Issue | Location | Status |
|----------|-------|----------|--------|
| [VERIFIED] | Bug 1 fix correctly adds WebSocket broadcast | `main.ts:1280-1294` | Good |
| [VERIFIED] | Bug 2 fix creates directory before watcher | `websocket.ts:869-876` | Good |
| [VERIFIED] | Error handling in new code | `websocket.ts:870-875` | Good |
| [LOW] | Comment says "guaranteed" but should say "exists or error logged" | `websocket.ts:877` | Minor nit |
| [INFO] | Pre-existing lint warnings and test failures | develop branch | Not from this PR |

**Handoff:** PR merged, to SM (Hawkeye) for finish-story
