# Story 98-24: OTEL enrichment and background task tracking in CLI mode

**Type:** Bug | **Points:** 5 | **Priority:** P1 | **Epic:** 98

## Debug Findings (2026-02-15)

### Root Cause

Cyclist's OTEL enrichment pipeline and background task tracking depend on the Claude message stream flowing through `websocket.ts` (web mode). In CLI mode, only OTEL data reaches Cyclist — `storePendingToolInput()` is never called, breaking three downstream systems.

### Affected Panels

1. **Subagents panel** — always empty in CLI mode. `trackBackgroundTask()` only called from `websocket.ts:1328` (web mode stream). OTEL Task events lack `tool_parameters` (confirmed in code comment at `otlp-receiver.ts:825-828`).

2. **Audit Log enrichment** — only `durationMs` present, missing `fileSize`, `lineCount`, `language`, `gitStatus`, `command`, `exitCode`, `outputSummary`, `workingDirectory`. Enrichment gated on `if (pendingInput)` at `otlp-receiver.ts:893`. No pending input in CLI mode → entire enrichment block (Read/Edit/Write/Bash) skipped.

3. **`mcp_tool` entries** — show "-" for input. MCP tool OTEL events use `tool_name: "mcp_tool"` with non-standard field names the input parser at `otlp-receiver.ts:809` can't extract.

### Key Files

| File | Relevance |
|------|-----------|
| `packages/cyclist/src/otlp-receiver.ts` | `processLogEvents()` at L791, enrichment at L919-963, background task completion at L886-890 |
| `packages/cyclist/src/websocket.ts` | `storePendingToolInput` at L1325, `trackBackgroundTask` at L1332 — only called in web mode stream |
| `packages/cyclist/src/span-correlation.ts` | `storePendingToolInput`/`consumePendingToolInput` — the correlation bridge |
| `packages/cyclist/src/file-enrichment.ts` | `enrichReadSpan`, `enrichEditSpan`, `enrichBashSpan`, `enrichWriteSpan` |

### Data Flow (CLI mode — broken)

```
Claude Code CLI → OTEL POST /v1/otlp/logs → processLogEvents()
  → tool_parameters parsed (L804-813) ✓ (basic input extracted)
  → consumePendingToolInput() → returns undefined ✗ (nothing stored)
  → enrichment block skipped (L893 gate) ✗
  → recordToolEvent() with minimal data ✓
```

### Data Flow (Web mode — works)

```
Claude SDK → /ws/claude → websocket.ts stream handler
  → storePendingToolInput(toolId, toolName, input) ✓
  → trackBackgroundTask() for Task tools ✓
  → OTEL arrives → consumePendingToolInput() → match found ✓
  → enrichment runs (Read/Edit/Write/Bash) ✓
  → recordToolEvent() with full enrichment ✓
```

### Fix Direction

1. **Make `processLogEvents()` enrich directly from OTEL `tool_parameters`** — `parsedToolParams` already available at L870-874. For Read/Edit/Write, extract `file_path` and call enrichment. For Bash, extract `command`.
2. **Track Task starts from OTEL** — when `tool_parameters` is available (not always for Task), or add a secondary OTEL-based start path using `tool_name === 'Task'` event detection.
3. **Add `mcp_tool` input extraction** — inspect actual OTEL field names for MCP tools, add to input parser at L809.
4. **Keep message stream correlation as enhancement layer** — better data when available, but not a hard requirement for enrichment.

### Acceptance Criteria

- [ ] Audit Log shows enriched data (fileSize, command, exitCode, etc.) in CLI mode
- [ ] Subagents panel shows Task tool invocations in CLI mode
- [ ] `mcp_tool` entries display meaningful input text
- [ ] Web mode behavior unchanged (enrichment still uses correlation when available)
- [ ] Enrichment works for: Read, Edit, Write, Bash, Task, mcp_tool
