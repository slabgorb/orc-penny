# Story 95-4: File-watch observation scope

**Jira:** PROJ-14669
**Epic:** PROJ-14665 (Workflow Configuration & Observation Protocol)
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/95-4-file-watch-observation-scope

---

## Context

### Epic Overview (95 - Workflow Configuration & Observation Protocol)

Workflow authors can add `tandem:` blocks to their workflow YAML, and BikeLane spawns/terminates backseat agents with working observation scopes. The tandem system works end-to-end — backseat observes, writes observations, bell mode injects them, primary surfaces them.

**Total epic points:** 20
**Priority:** P1
**Marker:** feature
**Repo:** pennyfarthing
**Stories:** 7

The epic comprises seven stories that build the complete tandem observation loop:
1. YAML schema and BikeLane validation (95-1) — DONE
2. Backseat agent spawn and lifecycle (95-2) — DONE
3. Observation file format and writer (95-3) — DONE
4. **File-watch observation scope (95-4)** — THIS STORY
5. Tool-watch observation scope (95-5)
6. Context-watch observation scope (95-6)
7. Bell mode observation injection (95-7)

### Story Description

Implement file change detection for the backseat agent with `file-watch` scope. The backseat polls or watches the working tree for create/modify/delete events and writes observations to the tandem observation file. Detects changes within 5 seconds, non-blocking to primary agent, accumulates context across observations within the phase.

**Key references:**
- Epic Context: File-watch scope implementation, detection within 5 seconds (NFR3), non-blocking (NFR1)
- PRD: FR12 (file-watch trigger), NFR1 (non-blocking), NFR3 (5-second detection), FR9 (context accumulation)
- UX Design Spec: "Observation File Format" block, observation trigger types

### Prior Story Context (95-3)

Story 95-3 (PROJ-14668) established the observation file format and writer:
- File location: `.session/{story-id}-tandem-{agent}.md`
- Header includes: observer agent, persona, phase, start timestamp
- Entries: timestamp (HH:MM), trigger type, trigger detail, observation text
- Entries separated by `---` horizontal rules
- Entry-atomic writes — file remains valid markdown even on crash
- Implemented `ObservationWriter` class with `createFile()` and `append()` methods

The `95-3-observation-file-format` branch contains:
- `packages/core/src/workflow/observation-writer.ts` — core writer implementation
- `packages/core/src/workflow/observation-writer.test.ts` — comprehensive tests for entry atomicity

For this story, we build the file-watch detection mechanism that triggers observation writes.

---

## Technical Notes

### File-Watch Scope Design

The `file-watch` scope detects changes in the working tree and reports them as observations. Key design decisions:

1. **Detection mechanism:** Two options:
   - Real-time: Use `fs.watch()` or `chokidar` npm package for file system events
   - Polling: Periodic `git status` or `git diff` calls (simpler, no dependencies, works in all environments)
   - Recommended: Polling via `git status --porcelain` or `git diff-files --name-status` — already in working tree, no npm dependencies

2. **Detection interval:** Poll every 1-2 seconds to meet 5-second detection requirement (NFR3)

3. **Change detection:** Capture:
   - New files (untracked in `git status --porcelain`)
   - Modified files (staged or unstaged changes)
   - Deleted files (removed from working tree)
   - Ignore `.pennyfarthing/`, `.session/`, `node_modules/`, and other non-source directories

4. **Observation format:**
   ```
   **Trigger:** file-watch: {event_type}: {file_path}
   {detailed change description}
   ```
   Example:
   ```
   **Trigger:** file-watch: modify: packages/core/src/workflow/index.ts
   Added observation-writer import and export.
   ```

5. **Context accumulation (FR9):** Track observed files across the phase to avoid redundant observations. When the same file changes multiple times, update prior observation or add new timestamp-tagged entry.

### Integration with 95-3 Observation Writer

The backseat agent will:
1. Instantiate `ObservationWriter` at phase start with file path from BikeLane config
2. Call `writer.createFile()` with agent persona and phase info
3. On each file change detection, call `writer.append()` with trigger type and observation text
4. Cleanup/close writer on phase end (per 95-2 lifecycle management)

### Backseat Agent Prompt

The backseat agent prompt (launched by BikeLane in 95-2) needs to:
- Import and use `ObservationWriter` from `@pennyfarthing/core`
- Implement polling loop with configurable interval (default 1-2 seconds)
- Call `git status --porcelain` or `git diff` to detect changes
- Format observations with file-watch trigger type
- Handle errors gracefully (continue observing if a write fails)
- Respect scope config from BikeLane (only file-watch, not tool-watch or context-watch)

### Key Constraints

- **Non-blocking (NFR1):** File polling must not consume excessive CPU. Backseat runs as separate Claude Code subagent, so blocking I/O is acceptable within that process
- **Detection speed (NFR3):** Detect changes within 5 seconds — 1-2 second poll interval achieves this
- **Backward compatible (NFR15):** File-watch is one scope among three; other scopes unaffected
- **Haiku for subagents:** Backseat uses Haiku model only
- **Return result objects:** Functions return `{success, data?, error?}` instead of throwing
- **Use `.js` extensions:** All relative TypeScript imports use `.js` extensions

### Reference Architecture (from Epic Context)

```
Backseat Agent (long-lived background subagent, Haiku model)
  |  receives: persona, story context, scope config, observation file path
  |  observes: file changes via polling
  |  writes: .session/{story-id}-tandem-{agent}.md
  v
Observation File (append-only markdown)
  |  entries: timestamp, trigger type (file-watch), trigger detail, observation text
  v
Bell Mode Hook (future: 95-7)
  |  PostToolUse → check tandem file mtime → inject as bell message
```

### Implementation Checklist

- [ ] File-watch scope detection logic (polling via git or fs.watch)
- [ ] Integration with `ObservationWriter` from 95-3
- [ ] Backseat agent prompt template with file-watch implementation
- [ ] Ignore rules for non-source directories
- [ ] Context accumulation logic (avoid redundant observations)
- [ ] Error handling (continue if write fails)
- [ ] Tests for file change detection (create, modify, delete)
- [ ] Integration test with backseat spawn (from 95-2)

---

## Development Environment

**Working directory:** `/Users/keithavery/Projects/pf-1/pennyfarthing`
**Branch:** `feature/95-4-file-watch-observation-scope`
**Develop branch:** pulled from origin, up to date with latest (includes 95-1, 95-2, 95-3 implementations)

**Key files to review:**
- `packages/core/src/workflow/observation-writer.ts` — Writer implementation from 95-3
- `packages/core/src/workflow/observation-writer.test.ts` — Writer tests from 95-3
- `packages/core/src/workflow/workflow-executor.ts` — BikeLane backseat spawn from 95-2
- `packages/core/src/workflow/workflow-schema.ts` — Tandem YAML schema from 95-1

**Next steps:**
1. Review `ObservationWriter` implementation and test patterns
2. Design file-watch polling logic (git-based or fs-watch)
3. Implement backseat agent prompt template with file-watch
4. Add file-watch specific tests
5. TDD workflow: test-first, implement, code review

---

## SM Assessment

**Story:** 95-4 — File-watch observation scope (3pts, TDD)
**Setup:** Complete — Jira claimed, branch created, session ready
**Handoff:** To TEA (Sam Seaborn) for test design phase
**Notes:** This is story 4 of 7 in epic 95 (Workflow Configuration & Observation Protocol). Stories 95-1 through 95-3 are complete. Story 95-3 (ObservationWriter) provides the write infrastructure this story depends on.

---

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `packages/core/src/workflow/file-watch.test.ts` — 25 tests across 11 suites covering all 10 ACs
- `packages/core/src/workflow/file-watch.ts` — Stub module (throws `Not implemented`)

**Tests Written:** 25 tests covering 10 ACs:
| AC | Tests | What it covers |
|----|-------|----------------|
| AC1: File create | 3 | Single file, multiple files, subdirectories |
| AC2: File modify | 1 | Detect content changes to existing files |
| AC3: File delete | 1 | Detect removed files |
| AC4: Poll timing | 2 | Poll ≤ 2000ms, default interval |
| AC5: Non-blocking | 2 | detectFileChanges fast, startFileWatcher returns immediately |
| AC6: Observation writes | 2 | file-watch trigger type, event type in trigger detail |
| AC7: Context accumulation | 2 | No duplicates for unchanged files, new entry on re-change |
| AC8: Ignore paths | 4 | .pennyfarthing/, node_modules/, .session/, non-ignored detected |
| AC9: Error resilience | 2 | Invalid workDir returns error, watcher survives write failures |
| AC10: Result objects | 3 | All 3 functions return {success, data?, error?} |
| Edge cases | 3 | Empty dir, rapid changes, idempotent stop |

**Status:** RED — 24 failing, 1 passing (config assertion). All failures are `Not implemented` throws from stubs. Tests compile cleanly, fail on assertions not imports.

**API Contract for Dev:**
- `detectFileChanges(config)` → `Promise<FileWatchResult<FileChange[]>>` — one-shot detection
- `startFileWatcher(config)` → `Promise<FileWatchResult<FileWatchHandle>>` — starts polling loop
- `stopFileWatcher(handle)` → `Promise<FileWatchResult>` — stops polling (idempotent)
- `createFileWatchScope(config)` → `FileWatchHandle` — normalize config with defaults

**Implementation Notes for Dev:**
1. Recommended approach: snapshot-based diffing (fs.readdirSync recursive, compare mtimes between polls)
2. Don't use git — tests create files in temp directories without git repos
3. `ignorePaths` filter should match path segments (startsWith or includes)
4. Context accumulation: track `Map<path, mtime>` between polls, only report actual changes
5. `startFileWatcher` with `observationFilePath` should call `appendObservation()` from observation-writer
6. All functions MUST return result objects, never throw

**Handoff:** To Dev (Toby Ziegler) for implementation

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/workflow/file-watch.ts` — Full implementation: snapshot-based file change detection using recursive readdirSync + mtime diffing, polling watcher with observation-writer integration, ignore path filtering, error resilience
- `packages/core/src/workflow/file-watch.test.ts` — Minor fix: added missing mkdirSync for AC8 .session/ ignore test

**Tests:** 25/25 passing (GREEN)
**PR:** #798 — feat(95-4): file-watch observation scope
**Branch:** feature/95-4-file-watch-observation-scope (pushed)

**Implementation Details:**
- `detectFileChanges`: One-shot snapshot diff with inode-based directory recreation detection to handle test isolation
- `startFileWatcher`: setInterval-based polling loop with per-handle snapshot state via WeakMap, writes observations via appendObservation on changes
- `stopFileWatcher`: Idempotent — clears interval timer, sets running=false
- `createFileWatchScope`: Config normalizer with default poll interval (1000ms)
- No external dependencies — pure node:fs + node:path
- Context accumulation: only reports actual changes between polls, not previously reported unchanged files

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. `[VERIFIED]` Data flow traced: `scanDir` → `diffSnapshots` → `FileChange[]` → `appendObservation` — clean pipeline, no mutation of shared state during diffing at `file-watch.ts:134-155`
2. `[VERIFIED]` Error resilience: try-catch around `appendObservation` call at `file-watch.ts:239-247`, plus `appendObservation` itself returns result objects. Defense-in-depth.
3. `[VERIFIED]` Race condition handling: `readdirSync`/`statSync` gap correctly caught at `file-watch.ts:123-126`. Node.js single-threaded event loop makes `stopFileWatcher` safe at `file-watch.ts:270-274`.
4. `[VERIFIED]` Ignore path logic at `file-watch.ts:112` correctly handles root-level and nested ignored directories. No false positives on similarly-named paths.
5. `[VERIFIED]` No forbidden patterns: no `console.log`, no `TODO`, no debug code, no `t.Skip()`.
6. `[MEDIUM]` Inode-based directory recreation detection at `file-watch.ts:178-181` is platform-specific (macOS/Linux). Not a blocker — framework targets Darwin.
7. `[LOW]` Global `snapshots` map at `file-watch.ts:84` persists string-keyed entries for process lifetime. Acceptable for backseat agent single-directory use case.

**Pattern observed:** Snapshot-based diffing with `Map<path, mtime>` follows the same immutable-compare pattern used elsewhere in the workflow engine. WeakMap for per-handle state prevents cross-watcher contamination.

**Error handling:** All four public functions return `{success, error?}` result objects per framework pattern. Never throw. AC9 tests verify resilience under write failures.

**Security:** No user input reaches file paths unsanitized — `workDir` comes from config, `ignorePaths` from config. `relative()` prevents path traversal. No external dependencies.

**Test fix:** Added missing `mkdirSync` at `file-watch.test.ts:465` is a legitimate test setup fix — all other AC8 tests already had this pattern.

**Handoff:** To SM for finish-story
