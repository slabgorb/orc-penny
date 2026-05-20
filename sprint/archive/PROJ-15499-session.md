# Story 120-14: OTEL enrichment and background task tracking in CLI mode

**Status:** In Progress
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Jira:**
**Branch:** feature/120-14-otel-cli-enrichment
**Sprint:** 2608

## Story Context

Type: Bug | Points: 5 | Priority: P1 | Epic: 120 (PROJ-15396)

### Problem

Cyclist's OTEL enrichment pipeline and background task tracking depend on the Claude message stream flowing through websocket.ts (web mode). In CLI mode, only OTEL data reaches Cyclist — storePendingToolInput() is never called, breaking three downstream systems:

1. **Subagents panel** — always empty in CLI mode
2. **Audit Log enrichment** — missing fileSize, lineCount, language, gitStatus, command, exitCode
3. **mcp_tool entries** — show "-" for input

### Fix Direction

1. Make processLogEvents() enrich directly from OTEL tool_parameters
2. Track Task starts from OTEL event detection
3. Add mcp_tool input extraction with proper OTEL field mapping
4. Keep message stream correlation as enhancement layer (not hard requirement)

### Key Files

- packages/cyclist/src/otlp-receiver.ts — processLogEvents() enrichment logic
- packages/cyclist/src/websocket.ts — currently only place storePendingToolInput() called
- packages/cyclist/src/span-correlation.ts — correlation bridge
- packages/cyclist/src/file-enrichment.ts — enrichment implementations

### Acceptance Criteria

- [ ] Audit Log shows enriched data (fileSize, command, exitCode, etc.) in CLI mode
- [ ] Subagents panel shows Task tool invocations in CLI mode
- [ ] mcp_tool entries display meaningful input text
- [ ] Web mode behavior unchanged (enrichment still uses correlation when available)
- [ ] Enrichment works for: Read, Edit, Write, Bash, Task, mcp_tool

## Assessments

### Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/otlp-receiver.ts` — CLI enrichment fallback, Task OTEL tracking, MCP tool input display

**Approach:**
All changes in `processLogEvents()`. When `pendingInput` (from web mode message stream) is unavailable, an `else if (parsedToolParams)` branch creates a synthetic correlation from OTEL `tool_parameters` and runs the same enrichment functions (Read/Edit/Write/Bash). Web mode is untouched — the `else if` structure ensures the existing `pendingInput` path takes priority.

For Task tracking in CLI mode: since OTEL `tool_result` fires after completion, we call `trackBackgroundTask()` then immediately `completeBackgroundTask()` with the result data.

For MCP tools: extract server/tool from `mcp__server__tool` qualified names, and stringify non-string param values instead of showing `[object Object]`.

**Tests:** 59/59 passing (3 OTEL-related test files). 13 pre-existing failures in unrelated modules.
**Branch:** feature/120-14-otel-cli-enrichment (pushed)

**Handoff:** To Reviewer for code review

### Reviewer Assessment

**Verdict:** APPROVED

| Severity | Issue | Location |
|----------|-------|----------|
| [VERIFIED] | Web mode preserved — `else if` ensures pendingInput path priority | otlp-receiver.ts:944 |
| [MEDIUM] | Synthetic ID `otel-${timestamp}-${toolName}` could collide for same-ms events. Sequential processing mitigates. | otlp-receiver.ts:952 |
| [LOW] | CLI fallback doesn't set toolEvent.traceId/spanId (no regression — OTEL lacks these in CLI) | otlp-receiver.ts:944-1008 |
| [VERIFIED] | Enrichment functions reused correctly with proper error handling | otlp-receiver.ts:968-1007 |
| [VERIFIED] | Task track+complete pattern correct for after-the-fact OTEL detection | otlp-receiver.ts:1014-1026 |
| [VERIFIED] | MCP name extraction safe, guarded by `!input` | otlp-receiver.ts:803-806 |
| [VERIFIED] | No forbidden patterns (console.log, TODO, secrets) | diff-wide |

**Data flow traced:** OTEL POST → processLogEvents → parsedToolParams → synthetic correlation → enrichment functions → enriched toolEvent → recordToolEvent → listeners
**Error handling:** All enrichment wrapped in try/catch, consistent with existing pattern
**Tests:** 59/59 pass, type check clean

**Handoff:** To SM for finish-story