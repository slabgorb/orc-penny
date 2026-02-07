# MSSCI-14394: Subagent spans never clear on task completion

**Status:** in_progress
**Phase:** finish
**PR:** https://github.com/1898andCo/pennyfarthing/pull/701
**Workflow:** trivial
**Jira:** MSSCI-14394
**Repos:** pennyfarthing
**Branch:** bugfix/subagent-span-cleanup
**Assignee:** kavery
**Points:** 2

---
## Bug Analysis

**Symptom:** SubagentSpan indicators (the "Gaff Processing task: ..." lines) never disappear after subagent tasks complete. They accumulate across the entire conversation, consuming significant screen real estate.

**Root cause:** `transformMessage()` in `MessagePanel.tsx` only extracts `text` blocks from `user`-type SDK messages. The Claude SDK delivers `tool_result` blocks inside `user`-type messages, but these are silently dropped. The existing cleanup code correctly looks for `tool_result` with a `tool_id` matching the Task's parent_id, but never fires because no `tool_result` MessageData is created.

**Key files:**
- `packages/cyclist/src/public/components/panels/MessagePanel.tsx` — transformMessage + cleanup logic

---
## Dev Assessment

**Changes (1 file, +38/-10):**
1. Added `SDKToolResultBlock` interface for `tool_result` content blocks
2. In `transformMessage()` user-type handler: extract `tool_result` blocks alongside text blocks
3. Updated cleanup logic from single-task `find()` to multi-task `filter()`+`Set` for simultaneous completions

**Data flow verified:**
- SDK sends `user` message with `content: [{ type: 'tool_result', tool_use_id: 'task-xyz' }]`
- `transformMessage` now extracts this as `{ type: 'tool_result', tool_id: 'task-xyz' }`
- `handleSDKMessage` cleanup finds `tool_result` with no `parent_id`, gets `tool_id`
- Matches against existing messages with `parent_id === 'task-xyz'`
- Filters them out, appends new stamped messages

**Tests:** 1842/1842 passing (1 pre-existing markdown table failure, unrelated)
**TypeScript:** No new errors introduced

**Note:** User also requested consolidating indicators to bottom of message view. That's a larger UX change — this fix handles the immediate "never goes away" bug. The consolidation could be a follow-up.

**Handoff:** To Reviewer (J.F. Sebastian)

---
## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 1841/1841 passing (2 pre-existing failures: MSSCI-12780 ProgressPanel, MSSCI-14191 bellMode). No new regressions.
**Forbidden patterns:** Clean — no console.log, TODO, HACK, or security concerns.

**Data flow traced:** SDK `user` message with `tool_result` content blocks → `transformMessage` extraction → `handleSDKMessage` cleanup via `completedTaskIds` Set → `setMessages` filter removes child messages with matching `parent_id`. Verified field name alignment between server (`tool_use_id` at websocket.ts:1381) and client (`resultBlock.tool_use_id` at MessagePanel.tsx:173).

**Observations:**
1. `[VERIFIED]` Type guard `(block): block is SDKToolResultBlock => block.type === 'tool_result'` at MessagePanel.tsx:168 — correct narrowing, matches SDK shape
2. `[VERIFIED]` Undefined `tool_use_id` handled — cleanup filter at L306 checks `&& m.tool_id`, excludes undefined
3. `[VERIFIED]` Non-Task tool_results won't cause spurious removal — `idsToRemove` only contains IDs with matching `parent_id` children in prev state
4. `[VERIFIED]` Race: tool_result + new subagent messages in same batch — `prev` is filtered but `stamped` is fully appended, new messages survive
5. `[LOW]` Extracted tool_results accumulate in messages array invisibly (filtered by MessageView L125) — not a regression, same as all tool_results

**Pattern observed:** Batch cleanup using `Set` at MessagePanel.tsx:311 — correct upgrade from single-match `find()` to multi-match `filter()` for when multiple Task tools complete simultaneously.

**Handoff:** To SM (Captain Bryant) for finish-story
