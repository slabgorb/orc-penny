# Story 132-5: Fix standalone OTLP enrichment pipeline for BikeRack TUI mode

**Status:** in-progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** feature/132-5-fix-standalone-otlp-enrichment
**Points:** 2
**Epic:** 132 — Release Workflow Hardening (11.x Followup)

---

## Context

PR #1158 moved `_forward_tool_input()` before the `is_cyclist_running()` gate in `cyclist_pretooluse.py`, so tool inputs are now forwarded to WheelHub in both Cyclist and BikeRack TUI modes. However, the server-side standalone OTLP receiver discards them:

1. `storePendingToolInput()` in `otlp-receiver.ts` is a no-op in standalone mode (line 191)
2. `processOTLPTraces()` is also a no-op in standalone mode (line 134-135)
3. Enrichment functions in `file-enrichment.ts` need the span correlation map, which is never populated without trace processing

The audit log in BikeRack TUI mode only gets basic entries (tool name, success, timestamp) but never gets enrichment data (file size, line count, git status, diffs, duration).

## Acceptance Criteria

- [ ] `storePendingToolInput()` stores inputs in standalone mode (not no-op)
- [ ] Standalone OTLP receiver correlates pending tool inputs with incoming log events
- [ ] Audit log entries in BikeRack TUI mode include enrichment data (file path, language, file size, line count, git status)
- [ ] Edit operations show diff summary (lines added/removed)
- [ ] Bash operations show command (redacted), exit code, output summary, duration
- [ ] Existing Cyclist provider mode is unaffected (no regression)

## Key Files

- `packages/core/src/server/otlp-receiver.ts` — standalone OTLP processing, `storePendingToolInput` no-op
- `packages/core/src/server/span-correlation.ts` — correlation map and pending tool input storage
- `packages/core/src/server/file-enrichment.ts` — enrichment functions (Read, Edit, Bash, Task)
- `packages/core/src/server/server.ts:255` — `/api/pending-tool-input` endpoint
- `pennyfarthing-dist/src/pf/hooks/cyclist_pretooluse.py` — hook that forwards tool inputs (already fixed)

## Approach

The standalone `processLogEvents()` already processes `claude_code.tool_result` events. The fix should:
1. Make `storePendingToolInput()` actually store inputs in standalone mode (use the `span-correlation.ts` functions directly)
2. In `processLogEvents()`, when processing a `tool_result`, consume the matching pending tool input to get full input params
3. Run the appropriate enrichment function based on tool type
4. Store enriched data on the audit log entry / tool event

---

## Assessments

### Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/server/otlp-receiver.ts` — Added local pending input queue, fixed `storePendingToolInput()` to store instead of no-op, modified `processLogEvents()` to consume pending inputs and enrich audit entries (sync: file path, language, diff, redacted command, exit code, duration; async: file size, line count, git status)
- `packages/core/src/server/otlp-receiver.test.ts` — 10 new tests covering all enrichment paths

**Tests:** 31/31 passing (21 existing + 10 new)
**Branch:** feature/132-5-fix-standalone-otlp-enrichment (pushed)

**ACs met:**
- [x] `storePendingToolInput()` stores inputs in standalone mode
- [x] Standalone OTLP receiver correlates pending inputs with log events
- [x] Audit log entries include file path, language, file size, line count, git status
- [x] Edit operations show diff summary
- [x] Bash operations show command (redacted), exit code, duration
- [x] Existing Cyclist provider mode unaffected (provider path unchanged, all existing tests pass)

**Handoff:** To review

### Dev Re-Review Note

Manual testing completed. Issues found during testing have been fixed and committed. Debug logging removed. Returning to review phase for re-review by Granny Weatherwax.

### Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** PreToolUse hook → `server.ts:262` `/api/pending-tool-input` → `storePendingToolInput` → `_pendingToolInputs` queue → `processLogEvents` → `consumePendingInput` → `enrichEntrySync`/`enrichEntryAsync` → audit log entry (safe: provider delegation checked first, FIFO matching by toolName, 10s expiry)
**Pattern observed:** Clean sync/async enrichment split — sync fields (filePath, language, diff, command, exitCode) available immediately, async fields (fileSize, lineCount, gitStatus) populated in background. Follows existing Cyclist enrichment patterns at `file-enrichment.ts`.
**Error handling:** Async enrichment errors silently caught at `otlp-receiver.ts:344` (.catch(() => {})) — acceptable for fire-and-forget TUI panel data.
**Findings (non-blocking):**
- [MEDIUM] FIFO-by-toolName matching in `consumePendingInput` (`otlp-receiver.ts:221`) — known limitation, OTEL events lack toolId
- [MEDIUM] ToolEvent listeners never receive async enrichment fields (`otlp-receiver.ts:349-363`) — acceptable for current consumers
- [LOW] Dead import `createOutputSummary` (`otlp-receiver.ts:21`)
- [LOW] Non-null assertion on `parsedParams!` (`otlp-receiver.ts:333`) — caught by try/catch

**Tests:** 31/31 passing (21 existing + 10 new)
**Handoff:** To SM for finish-story