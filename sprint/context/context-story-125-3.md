# Context: Story 125-3 — Replace TypeScript sprint-data.ts resolution with SprintContext

**GitHub Issue:**
**Points:** 2
**Epic:** 125 — Sprint State Engine Consolidation (PROJ-15421)

## Problem

The TypeScript server in Cyclist independently reimplements sprint data resolution logic, creating a reader divergence with Python. The `sprint-data.ts` module (656 lines) contains its own shard merging and registry resolution code that diverges from the canonical Python implementation in `loader.py` and `resolver.py`.

This creates three problems:

1. **Duplicate implementation logic** — sprint-data.ts and Python loader both merge epic shards, resolve registry entries, and collect repository lists, but with subtle differences in error handling and edge case behavior.

2. **Orphan epic shard detection mismatch** — Python's orphan detection scans the disk for `epic-*.yaml` files and warns about unreferenced shards. TypeScript doesn't detect orphans; it only processes explicitly referenced shards.

3. **Future initiative resolution differences** — The shard merging algorithm for future initiatives differs between the two implementations, potentially causing mismatched data in the UI when switching between Python CLI and Cyclist.

The root cause is that TypeScript implemented this independently (story 120-6) before the Python SprintContext consolidation (story 125-1/125-2) was complete. Now that Python has a canonical `resolve_sprint_context()` function and unified `SprintData` loading, TypeScript should use it instead of reimplementing.

## Architecture

### Current Flow (TypeScript Only)

```
Cyclist WebSocket server (websocket.ts)
  → broadcastSprintUpdate(projectDir)
    → getSprintData(projectDir)
      → read sprint/current-sprint.yaml
      → mergeEpicShards() (TS impl)
      → mergeInitiativeShards() (TS impl)
      → read sprint/future.yaml
      → checkStoryContext() per story
      → checkEpicContext() per epic
      → calculate metrics
  → JSON.stringify({ type: 'update', ...sprintData })
  → broadcast to /ws/sprint clients
```

### Post-125-2 Python Flow (Reference)

```
Python CLI: pf sprint data --json
  → resolve_sprint_context(project_root) [PROJ-15422]
    → SprintContext dataclass
  → load_sprint() [loader.py]
    → shard_merge.merge_epic_shards() [Python impl]
    → shard_merge.merge_initiative_shards() [Python impl]
    → orphan_detection.find_orphan_epics() [Python impl]
  → JSON output
```

### Key Files

| File | Role | Lines | Responsibility |
|------|------|-------|-----------------|
| `/pennyfarthing/packages/cyclist/src/sprint-data.ts` | TypeScript sprint data aggregation | 656 | mergeEpicShards(), mergeInitiativeShards(), getSprintData() |
| `/pennyfarthing/packages/cyclist/src/websocket.ts` | WebSocket server, broadcast loop | 1680+ | broadcastSprintUpdate(), file watchers, client management |
| `/pennyfarthing/pennyfarthing-dist/pf/core/models.py` | Python SprintContext dataclass | 31 | SprintContext frozen dataclass |
| `/pennyfarthing/pennyfarthing-dist/pf/core/resolver.py` | Python sprint context resolution | 138 | resolve_sprint_context() function, registry lookup |
| `/pennyfarthing/pennyfarthing-dist/pf/sprint/loader.py` | Python sprint data loader | ~400 | load_sprint(), shard merging, context file checks |
| `/pennyfarthing/pennyfarthing-dist/pf/sprint/shard_merge.py` | Python shard merging logic | ~300 | merge_epic_shards(), merge_initiative_shards(), orphan detection |

### Design Decision: Option A (Subprocess)

Per the proposal (sprint-state-consolidation-proposal.md), this story implements **Option A**: TypeScript calls the Python CLI via subprocess and parses JSON output.

```
Cyclist WebSocket server
  → broadcastSprintUpdate(projectDir)
    → execSync('pf sprint data --json', {cwd: projectDir})
    → parse JSON as SprintData
    → broadcast to /ws/sprint clients
```

**Rationale:**
- Reuses existing `pf sprint data` command (already exists)
- Eliminates duplicate logic immediately
- Python is the single source of truth
- Simple integration — child process, JSON over stdout
- Future: Can migrate to HTTP endpoint (Option B) when WheelHub matures
- Safety: TypeScript retains in-memory format; can add conformance tests (Option C)

### TypeScript SprintData Format (unchanged)

The TypeScript `SprintData` interface remains the same — it defines the shape for broadcast and UI consumption:

```typescript
export interface SprintData {
  currentStory: SprintStory | null;
  nextStory: SprintStory | null;
  epics: SprintEpic[];
  completedEpics: SprintEpic[];
  futureEpics: FutureEpic[];
  sprint: { number, name, done, remaining, inProgress, endDate };
  metrics: SprintMetrics;
}
```

The change is **where the data comes from**, not what it looks like.

## Acceptance Criteria

### AC1: sprint-data.ts uses SprintContext (via subprocess or shared logic)
- **Given** sprint-data.ts has the original mergeEpicShards() and getSprintData() functions
- **When** broadcastSprintUpdate() is called with a project directory
- **Then** getSprintData() calls `pf sprint data --json` subprocess instead of reimplementing shard merge
- **And** the returned SprintData structure is identical to before
- **And** all five test fixtures pass without modification (setup, epics, orphans, future, metrics)

### AC2: Orphan epic shard detection matches Python behavior
- **Given** sprint/epic-orphan-test.yaml exists on disk but is not referenced in current-sprint.yaml or any epic shard
- **When** getSprintData(projectDir) is called
- **Then** the result does not include the orphan epic (same as Python `pf sprint data --json`)
- **And** no warnings are logged by sprint-data.ts (Python CLI handles logging)

### AC3: Future initiative resolution matches Python behavior
- **Given** future.yaml contains initiatives with nested epic references (e.g., "epic-42")
- **When** getSprintData(projectDir) is called
- **Then** future initiatives' `children` array is populated with the same epics that Python resolves
- **And** initiative status mapping ('ready', 'blocked', 'planning') matches Python's mapFutureStatus()

### AC4: WebSocket broadcast still works with new data path
- **Given** the sprint WebSocket watcher detects a change to sprint/current-sprint.yaml
- **When** broadcastSprintUpdate(projectDir) is called
- **Then** JSON message is sent to all /ws/sprint clients within 100ms
- **And** the message structure is { type: 'update', ...sprintData } (unchanged)
- **And** no errors appear in logs if `pf sprint data` subprocess fails
- **And** UI clients render the sprint panel correctly

## Implementation Notes

### Step 1: Add `pf sprint data --json` command (if not already exists)

Check if Python CLI has a `data` subcommand that outputs SprintData JSON. If not, add:

```bash
pf sprint data --json
```

This command should:
- Call `resolve_sprint_context(project_root)`
- Call the internal loader to get resolved SprintData
- Output as JSON (no formatting)
- Exit code 0 on success, non-zero on error

### Step 2: Replace mergeEpicShards() and mergeInitiativeShards() with subprocess call

In `sprint-data.ts`, refactor `getSprintData()` to:

1. Call `execSync('pf sprint data --json', { cwd: projectDir, encoding: 'utf-8' })` or use async variant
2. Parse the JSON output as SprintData
3. Return the result

Handle subprocess errors gracefully:
- If `pf` command is not found → log error, return empty SprintData
- If JSON parse fails → log error, return empty SprintData
- If exit code is non-zero → log stderr, return empty SprintData

### Step 3: Verify WebSocket broadcast still works

Run the existing test suite:

```bash
npm test packages/cyclist/tests/PROJ-14189-sprint-panel.test.ts
npm test packages/cyclist/tests/100-6-sprint-metrics.test.ts
```

The broadcast loop in websocket.ts (lines 1631–1639) remains unchanged:

```typescript
function broadcastSprintUpdate(projectDir: string): void {
  const sprintData = getSprintData(projectDir, getUserEmail());
  const message = JSON.stringify({ type: 'update', ...sprintData });
  for (const client of sprintClients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  }
}
```

Only the **source** of `sprintData` changes (subprocess instead of in-memory merge).

### Step 4: Remove dead code (mergeEpicShards, mergeInitiativeShards, checkEpicContext, checkStoryContext)

Once the subprocess call is working, remove or deprecate:
- `mergeEpicShards()` function (~30 lines)
- `mergeInitiativeShards()` function (~25 lines)
- `checkEpicContext()` function (~7 lines)
- `checkStoryContext()` function (~4 lines)

The context checking logic (`hasContext` fields) is already in Python's loader. If TS still needs to display context availability, it should come from the Python JSON output (add to SprintStory and SprintEpic interfaces if needed).

### Step 5: Add integration test

Create a test that:
1. Sets up a mock project with sprint/, future.yaml, context files
2. Calls getSprintData(projectDir)
3. Verifies the result matches what `pf sprint data --json` outputs directly
4. Tests error handling (missing pf command, malformed JSON, subprocess exit codes)

### Potential Gotchas

1. **Circular imports:** If Cyclist imports from pf modules, be aware of Python package structure. The subprocess approach avoids this entirely.

2. **Performance:** Subprocess spawning adds ~100-200ms overhead per call. File watchers trigger on every sprint/*.yaml change. Debounce is already in place (100ms in websocket.ts line 1124), so this should be acceptable. If needed, cache the result per debounce cycle.

3. **Path resolution:** The subprocess runs with `cwd: projectDir`, so relative paths in sprint/sprints.yaml must resolve from projectDir. Verify that `resolve_sprint_context()` uses absolute paths in the returned SprintContext.

4. **User email:** getSprintData() currently accepts a `_userEmail` parameter (used for nextStory selection). The subprocess call doesn't pass this. Either:
   - Add `--user-email` flag to `pf sprint data` command
   - Fetch user email separately in getSprintData() before calling subprocess
   - Remove the parameter (nextStory is rarely used in UI)

### Testing Strategy

1. **Unit tests:** Verify getSprintData() output structure matches TypeScript interfaces.
2. **Integration tests:** Run against real project directory with multi-shard epics and future.yaml.
3. **Regression tests:** Run existing Cyclist test suite (no behavioral changes from client perspective).
4. **Error handling:** Test with missing `pf` command, malformed YAML, missing sprint files.
5. **Performance:** Measure broadcast latency before/after (should be <500ms end-to-end).

### Future Iterations (Out of Scope)

- **Option B (HTTP endpoint):** Once WheelHub matures, expose `/api/sprint/data` backed by Python CLI, move WebSocket client to fetch via HTTP instead of subprocess.
- **Option C (Conformance tests):** Add test suite comparing Python and TypeScript implementations with identical inputs, ensure outputs match.
- **Orphan detection UI:** Display warnings about unreferenced epic shards in a panel or log (currently Python logs, TypeScript never checks).
