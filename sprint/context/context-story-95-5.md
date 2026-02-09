# Story Context: 95-5 - Tool-Watch Observation Scope

## Summary

Implement tool call observation for the backseat agent running with `scope: tool-watch`. The backseat receives tool call information (name, params, results) from the primary agent within one tool-use cycle. Large tool results are truncated to a configurable max size. Non-blocking to the primary agent.

## Planning References

- **PRD:** FR11-FR12 (tool-watch scope, truncation), NFR1 (non-blocking), NFR4 (one tool-use cycle delivery). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Three Observation Scopes" table in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 2.5 in `sprint/planning/tandem-mode-epics.md` under "Epic 2"

## Current State

### PostToolUse hook (existing)

**File:** `pennyfarthing/pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` (107 lines)

The PostToolUse hook:
- Fires after every tool call by the primary agent
- Receives tool name and parameters as hook arguments
- Currently checks bell queue for user feedback messages
- Outputs `hookSpecificOutput` JSON to inject context into primary agent
- Could be extended to write tool call data to a file the backseat reads

### OTEL spans (reference)

**File:** Referenced in Cyclist OTEL documentation
- Claude Code emits OTEL spans for tool calls
- Cyclist's WheelHub server intercepts and processes these spans
- Could be an alternative source of tool call data

### No tool-watch infrastructure exists

- No mechanism to forward tool call data to a background subagent
- The PostToolUse hook is the natural interception point

## Target State

After implementation:

1. Backseat with `scope: tool-watch` receives tool call data after each primary agent tool use
2. Data includes: tool name, parameters (key fields), and result (potentially truncated)
3. Delivery within one tool-use cycle (primary's next tool call sees the observation injected)
4. Large results truncated to configurable max size (prevent context window overflow)
5. Non-blocking to primary agent

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `bell-mode-hook.sh` | `pennyfarthing/pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` | Extend to write tool call data to a shared file |
| `bellmode_hook.py` | `pennyfarthing/pennyfarthing_scripts/bellmode_hook.py` | Same extension in Python implementation |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| Observation writer | (from 95-3) | API for writing observation entries |
| `bell-mode-hook.sh` | `pennyfarthing/pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` | Current hook structure, output format |

## Technical Approach

### Data Flow

```
Primary Agent → Tool Call → PostToolUse Hook fires
                               |
                               v
                         Hook writes tool call data
                         to shared file (append-only)
                               |
                               v
                         Backseat reads new entries
                         from shared file (polling)
                               |
                               v
                         Backseat writes observation
                         to tandem observation file
```

### Tool Call Data File

A separate file from the observation file — this is the input channel:

**Location:** `.session/{story-id}-tandem-toolcalls.jsonl`

Each line is a JSON object:

```json
{"timestamp":"2026-02-10T10:30:00Z","tool":"Bash","params":{"command":"npm test"},"result_preview":"All 42 tests passed","result_size":1234}
```

### Hook Extension

In `bell-mode-hook.sh`, after the bell queue check:

1. Check if tandem tool-watch is active (look for `.session/*-tandem-toolcalls.jsonl` marker or config flag)
2. If active, append current tool call data as JSONL line
3. Truncate result to max size (e.g., 500 chars) before writing
4. This runs synchronously within the hook — must be fast

### Backseat Polling

The backseat agent:
1. Periodically reads the toolcalls JSONL file (every 3-5 seconds)
2. Tracks last-read line count
3. For new entries, analyzes the tool calls and writes observations
4. Accumulates context — "the developer has run tests 3 times, each time fixing the same module"

### Truncation

Large tool results (file reads, test output) should be truncated:
- Default max: 500 characters
- Configurable via tandem config or environment variable
- Truncated results include `[truncated from {original_size} chars]` suffix

### Observation Entry Example

```markdown
---

## [10:33] Observation
**Trigger:** tool-watch: Bash (npm test -- --filter notification)
Tests for the notification module passed (42/42). The developer is running targeted tests after each edit to NotificationService.ts, suggesting incremental TDD. The test filter matches the file-watch observations of notification module changes.

---
```

## Acceptance Criteria

- Backseat receives tool call data (name, params, result) from primary agent
- Data delivered within one tool-use cycle
- Large results truncated to configurable max size
- Truncation indicator included when results are truncated
- Non-blocking to primary agent (hook execution remains fast)
- Observations include analysis, not just raw tool call replay
- Context accumulates across tool calls

## Dependencies

### Depends On

- **95-3** (Observation file format) — writes using the observation file format

### Depended On By

- **95-7** (Bell mode injection) — reads tool-watch observations for injection

## Risks / Open Questions

1. **Hook performance:** Appending JSONL in the PostToolUse hook adds I/O. Must complete within the existing hook time budget (NFR2). JSONL append is fast (single write), but verify with benchmarking.

2. **Result truncation policy:** What constitutes a "large" result? Options:
   - Character count (simple, predictable)
   - Token estimate (more accurate for LLM context)
   - Tool-specific rules (e.g., always truncate Bash output, never truncate Edit)
   Start with character count for MVP.

3. **Sensitive data:** Tool results may contain secrets, API keys, or credentials. The tool call data file should be in `.session/` (already gitignored). Consider whether additional scrubbing is needed.

4. **Dual hook implementations:** Both `bell-mode-hook.sh` (bash) and `bellmode_hook.py` (python) need the same extension. Keep logic minimal to avoid drift between implementations.

5. **Tool call metadata:** The PostToolUse hook receives tool name and parameters, but does it receive the full result? Need to verify what data is available in the hook context. If results aren't available in the hook, this story needs an alternative approach (e.g., OTEL span interception).
