# Story Session: MSSCI-14191

**Story:** [BUG] Message queue behavior not working correctly
**Points:** 2
**Priority:** P2
**Epic:** epic-76 (Dockview Panel Migration)
**Jira:** MSSCI-14191
**Repos:** pennyfarthing

**Workflow:** tdd
**Phase:** finish
**Assignee:** Claude

## Story Scope (Rewritten)

The message queue in Cyclist (`useMessageQueue.ts`) should behave differently based on bell mode state.

### Acceptance Criteria

**When Bell Mode is OFF:**
1. Messages typed while Claude is streaming are queued one at a time
2. Each queued message shows:
   - A **dismiss button** → removes it from the queue
   - An **instant send button** → STOPS Claude streaming AND sends ONLY that message (other queued messages remain in queue)
3. When Claude stops streaming (naturally or via abort), ALL queued messages are dequeued and sent at once

**When Bell Mode is ON:**
1. Messages are queued with a **bell icon marker** (🔔)
2. Messages are injected at first opportunity via PostToolUse hook
3. When streaming ends, any remaining messages (not yet consumed by hook) dequeue at once

**Mode Switching:**
1. If bell mode is turned ON while messages are already queued → those messages become bell-mode messages (eligible for hook injection, show 🔔 marker)
2. If bell mode is turned OFF while messages are queued → those messages revert to standard queue behavior (wait for stream end or instant-send)

**Queue Limits & Attachments:**
1. Maximum queue size is 10 messages
2. Queued messages can include image attachments

### Implementation Files
- `pennyfarthing/packages/cyclist/src/public/hooks/useMessageQueue.ts` - Queue logic
- `pennyfarthing/packages/cyclist/src/public/components/Editor.tsx` - Queue UI (dismiss/send buttons)
- `pennyfarthing/packages/cyclist/src/public/components/MessagePanel.tsx` - Turn complete handling
- `pennyfarthing/pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` - PostToolUse injection

### Current Behavior (Bug)
Need TEA to investigate what's actually broken vs expected behavior above.

## Session Log

### Setup (SM) - Initial
- Created session file
- Routed to TEA for TDD workflow

### TEA Assessment - First Pass
- Misdiagnosed scope as "audio notifications" (wrong)
- Wrote tests for wrong feature

### Dev Assessment - First Pass
- Implemented audio notification feature (wrong scope)
- Cleaned up: removed implementation files, deleted feature branch

### SM Scope Rewrite (2026-02-04)
- User clarified actual ACs for message queue behavior
- Rewrote story scope based on useMessageQueue.ts and ADR-0016
- Ready to restart TDD workflow with correct scope
- Handing off to TEA for test design

## TEA Assessment

**Tests Required:** Yes
**Reason:** Architectural bug found - dual hook instances cause broken functionality

### Root Cause Identified

**THE BUG:** `Editor.tsx` and `MessagePanel.tsx` each call `useMessageQueue()` separately, creating TWO independent React state instances.

- `Editor.tsx:236` calls `useMessageQueue()` → Instance A (has the queue data)
- `MessagePanel.tsx:229` calls `useMessageQueue()` → Instance B (empty queue)

**Result:**
- Queue displays correctly (Editor's instance has the data)
- "Send Now" button does nothing (`injectMessage` operates on MessagePanel's empty queue)
- Turn complete doesn't send messages (`handleTurnComplete` operates on MessagePanel's empty queue)

### Test File
- `pennyfarthing/packages/cyclist/tests/MSSCI-14191-message-queue.test.ts`

### Test Results: RED (3 failing, 22 passing)

**Failing tests (architectural):**
1. `should use shared queue state between Editor and MessagePanel` - MessageQueueContext doesn't exist
2. `should have Editor use MessageQueueContext instead of useMessageQueue` - Editor uses hook directly
3. `should have MessagePanel use MessageQueueContext instead of useMessageQueue` - MessagePanel uses hook directly

### Implementation Guidance for Dev

**Fix approach:** Create a `MessageQueueContext` to share queue state:

1. **Create** `src/public/contexts/MessageQueueContext.tsx`:
   - Export `MessageQueueProvider` (wraps App, holds queue state)
   - Export `useMessageQueueContext()` (returns shared queue state)
   - Move `useMessageQueue` logic into the provider

2. **Update** `Editor.tsx`:
   - Import `useMessageQueueContext` instead of `useMessageQueue`
   - Remove direct `useMessageQueue()` call

3. **Update** `MessagePanel.tsx`:
   - Import `useMessageQueueContext` instead of `useMessageQueue`
   - Remove direct `useMessageQueue()` call

4. **Wrap app** with `MessageQueueProvider` in the component tree

**Status:** RED (failing - ready for Dev)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `src/public/contexts/MessageQueueContext.tsx` - New context wrapping useMessageQueue for shared state
- `src/public/App.tsx` - Wrapped app with MessageQueueProvider
- `src/public/components/Editor.tsx` - Updated to use useMessageQueueContext
- `src/public/components/panels/MessagePanel.tsx` - Updated to use useMessageQueueContext

**Tests:** 25/25 passing (GREEN)
**Full Suite:** 1438/1438 passing
**PR:** #650 - fix(cyclist): share message queue state via context
**Branch:** feature/MSSCI-14191-message-queue-context (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** Editor.queueMessage() → shared context queue → MessagePanel.handleTurnComplete()/injectMessage() - both now operate on same queue instance via `useMessageQueueContext`

**Wiring verified:**
- `[VERIFIED]` MessagePanel:360 - onInject properly wires injectMessage with abort/submit deps
- `[VERIFIED]` MessagePanel:280 - handleTurnComplete called on completion with submitRef
- `[VERIFIED]` App.tsx:140-173 - Provider hierarchy: ClaudeProvider → MessageQueueProvider → content
- `[VERIFIED]` No direct useMessageQueue imports in Editor or MessagePanel

**Error handling:** `[VERIFIED]` useMessageQueueContext throws clear error if used outside provider

**Pattern observed:** Standard React Context pattern at `contexts/MessageQueueContext.tsx:50` - follows existing ClaudeContext.tsx

**Tests:** 1438/1438 passing, includes 3 architectural tests that verify the fix

**No blocking issues found.** Clean, minimal fix for a real architectural bug.

**Handoff:** To SM for finish-story
