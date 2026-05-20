# Context: Story 125-6 — Migrate Cyclist sprint panel to canonical data service

**Jira Issue:** PROJ-15427
**Points:** 2
**Priority:** P2
**Workflow:** tdd
**Epic:** 125 — Sprint State Engine Consolidation (PROJ-15421)

## Problem

The Cyclist sprint panel (used by the Enhanced Sprint Panel in the web UI and BikeRack TUI) reads sprint data directly from YAML files in TypeScript (`sprint-data.ts`). This creates a parallel implementation that duplicates logic already in the Python CLI (`pf sprint data --json`), causing:

- **Divergent parsing logic** — TypeScript and Python shard merging can differ, leading to data inconsistencies between CLI and UI
- **Duplicate maintenance burden** — YAML schema changes must be updated in both TS and Python
- **Architectural misalignment** — UI should consume from canonical data source (the CLI), not reinvent parsing

Story 125-5 introduced `pf sprint data --json` as the single source of truth. This story consolidates by making `sprint-data.ts` a thin subprocess wrapper that calls the CLI and broadcasts results via WebSocket—eliminating the TS/Python divergence entirely.

## Architecture

### Current Flow (Divergent)

```
Cyclist sprint panel user → useSprintData() hook
  → /ws/sprint WebSocket (from Cyclist server)
    → getSprintData(projectDir) in sprint-data.ts
      → Direct YAML file reads: readFileSync(current-sprint.yaml, future.yaml)
      → shard merging in TypeScript (mergeEpicShards, mergeInitiativeShards)
      → YAML-to-TS transformation (transformStory, transformEpic)
    → broadcastSprintUpdate() sends to all connected clients
```

### Target Flow (Canonical)

```
Cyclist sprint panel user → useSprintData() hook
  → /ws/sprint WebSocket (from Cyclist server)
    → getSprintData(projectDir) in sprint-data.ts (THIN WRAPPER)
      → execSync('pf sprint data --json', {cwd: projectDir})
        → [CLI parses YAML, merges shards, returns canonical JSON]
      → Parse subprocess output → SprintData type
    → broadcastSprintUpdate() sends to all connected clients
```

### Key Files

| File | Role | Change |
|------|------|--------|
| `packages/cyclist/src/sprint-data.ts` | Data aggregation service | Replace inline YAML parsing with subprocess call to `pf sprint data --json`. Keep shard merging and transformation logic in CLI only. |
| `packages/cyclist/src/websocket.ts` | WebSocket broadcast layer | No change — continues to call `getSprintData()` and broadcast. Add file watcher for sprint/ directory to trigger refresh on YAML changes. |
| `pennyfarthing-dist/pf/sprint/cli.py` | Python CLI (already done in 125-5) | Already has `pf sprint data` command with `--json` output. No changes. |

### Subprocess Integration Pattern

The sprint panel will follow the same subprocess pattern used elsewhere in the codebase:

```typescript
// Thin wrapper: call CLI, parse JSON output
export function getSprintData(projectDir: string, userEmail?: string | null): SprintData {
  try {
    const output = execSync('pf sprint data --json', {
      cwd: projectDir,
      encoding: 'utf-8',
      timeout: 5000,
    });
    const parsed = JSON.parse(output);
    // Optional: validate shape with TypeScript types or zod schema
    return parsed as SprintData;
  } catch (err) {
    console.error('[sprint-data] Failed to fetch from CLI:', err);
    // Return sensible defaults or throw
    return getEmptySprintData();
  }
}
```

### File Watcher Refresh

The existing file watcher at `websocket.ts` lines 1115-1139 already monitors `sprint/` directory and calls `broadcastSprintUpdate()` on YAML changes. No new watcher setup needed — it will trigger subprocess refresh automatically.

## Acceptance Criteria

### AC1: Sprint data comes from pf sprint data --json subprocess
- **Given** the enhanced sprint panel loads
- **When** `getSprintData(projectDir)` is called
- **Then** it executes `pf sprint data --json` via subprocess
- **And** parses the JSON output into SprintData type
- **And** does NOT read sprint/*.yaml files directly

### AC2: sprint-data.ts no longer implements shard merging or YAML parsing
- **Given** `sprint-data.ts` after migration
- **When** inspecting the code
- **Then** it contains NO calls to:
  - `readFileSync()` (except test fixtures if any)
  - `parseYaml()`
  - `mergeEpicShards()` or `mergeInitiativeShards()`
  - `parse` from `yaml` package (can be removed from imports)
- **And** all YAML logic lives in Python CLI only

### AC3: WebSocket broadcast unchanged from consumer perspective
- **Given** a sprint panel client connected to /ws/sprint
- **When** sprint YAML changes (via file watcher or tool output)
- **Then** it receives the same WebSocket message structure as before:
  - `{ type: 'init', ...SprintData }` on connection
  - `{ type: 'update', ...SprintData }` on refresh
- **And** latency is acceptable (<200ms refresh after file write)

### AC4: File watcher triggers subprocess refresh (not direct YAML read)
- **Given** a sprint/*.yaml file changes on disk
- **When** the existing file watcher fires
- **Then** it calls `broadcastSprintUpdate(projectDir)` (no args change)
  - Which calls `getSprintData(projectDir)` (now subprocess-based)
  - Which executes `pf sprint data --json`
- **And** the result is broadcast to all sprint WebSocket clients
- **And** no direct file reads occur after the subprocess

## Implementation Notes

### Scope: TypeScript Only

This story is a pure TypeScript refactor. The Python CLI's `pf sprint data --json` command (story 125-5) is complete and unchanged. No Python changes needed.

### Key Simplifications

1. **Remove** `mergeEpicShards()` and `mergeInitiativeShards()` — CLI handles this
2. **Remove** `transformStory()` and `transformEpic()` — CLI returns ready-to-use JSON
3. **Remove** YAML parsing logic (status mapping, future epic transformation, etc.) — CLI owns this
4. **Keep** type definitions (`SprintStory`, `SprintEpic`, `SprintData`, etc.) — these define the contract
5. **Keep** `getEmptySprintData()` helper for error fallback

### Error Handling

If subprocess fails (CLI not available, malformed output, timeout):
- Log error with timestamp and context
- Return `getEmptySprintData()` (empty sprint, no stories)
- UI will render gracefully (no crash on missing data)
- Retry on next file watcher event or WebSocket reconnect

### Execution Environment

The subprocess runs in the orchestrator root (projectDir), where `pf` is installed and in PATH. The `.pennyfarthing/` directory is present, so `pf sprint data` has access to config and sprint files.

### Testing Strategy (for Dev Phase)

1. **Unit:** Mock `execSync` to return test JSON, verify parse
2. **Integration:** Run real `pf sprint data --json`, verify output matches current sprint state
3. **E2E:** Load sprint panel, edit sprint YAML, verify broadcast within 100ms debounce window
4. **Error:** Simulate CLI failure, verify fallback behavior

### Performance Considerations

- Subprocess startup (~50-200ms) per `getSprintData()` call
- File watcher debounce remains 100ms (no increase in overhead)
- Broadcast is async via WebSocket (non-blocking)
- Consider caching JSON output with short TTL (1s) if performance becomes an issue — fall back to sync call on cache miss

## Move 2 Context

This is the second story in Move 2 of Epic 125.

- **125-5** ✓ — Implement `pf sprint data --json` (complete)
- **125-6** (this) — Migrate Cyclist to use it (in progress)
- **125-7** — Remove direct YAML reading from other TS components
- **125-8** — Archive completed epics via CLI, remove TS archive logic

After 125-6, the sprint panel is fully canonical. After 125-8, all TS/Python divergence on sprint state is eliminated.
