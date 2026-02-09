# Story Context: 95-3 - Observation File Format and Writer

## Summary

Implement the observation file creation and append logic used by backseat agents. The backseat creates an append-only markdown file at `.session/{story-id}-tandem-{agent}.md` at phase start and appends entries as observations occur. Each write is entry-atomic — the file remains valid markdown even on mid-write crash.

## Planning References

- **PRD:** FR7-FR8 (observation file format, entry atomicity), NFR11 (valid markdown on crash). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Observation File Format" block in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 2.3 in `sprint/planning/tandem-mode-epics.md` under "Epic 2"

## Current State

### Session files (existing pattern)

**Directory:** `.session/`
- Session files use markdown format with metadata headers
- Example: `.session/{story-id}-session.md`
- Convention: metadata at top, structured sections below

### No observation file infrastructure exists

- No tandem observation files
- No append-only file writer
- No entry-atomic write pattern in the codebase

### Background tasks (reference)

**File:** `pennyfarthing/pennyfarthing-dist/scripts/lib/background-tasks.sh` (178 lines)
- Demonstrates session file markdown manipulation patterns
- `bg_task_add()` inserts table rows using `awk` (lines 71-80)
- Pattern: find insertion point, append formatted content

## Target State

After implementation:

1. Backseat agent creates observation file at phase start: `.session/{story-id}-tandem-{agent}.md`
2. File has a markdown header with observer metadata (agent, persona, phase, start time)
3. Each observation is appended as a complete markdown entry with timestamp, trigger, and text
4. Appends are entry-atomic — each write is a complete entry, never partial
5. File remains valid markdown at all times, even after crash during write
6. Bell mode hook (story 95-7) can read this file to inject observations

## Key Files

### Files to Create

| File | Purpose |
|------|---------|
| Observation writer utility | Shared function for creating and appending to tandem observation files |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| Session files | `.session/*-session.md` | Existing markdown session file conventions |
| `background-tasks.sh` | `pennyfarthing/pennyfarthing-dist/scripts/lib/background-tasks.sh` | Pattern for markdown file manipulation |
| `session-state.ts` | `pennyfarthing/packages/core/src/workflow/session-state.ts` | Pattern for structured markdown generation (`formatWorkflowState()` lines 207-233) |

## Technical Approach

### File Format

```markdown
# Tandem Observations: {story-id}
**Observer:** {agent} ({persona})
**Phase:** {phase}
**Started:** {ISO timestamp}

---

## [10:30] Observation
**Trigger:** file-watch: src/components/Header.tsx modified
The Header component now imports useTheme but doesn't destructure the return value consistently with other components in the project.

---

## [10:35] Observation
**Trigger:** tool-watch: Bash (npm test)
Test suite passed with 2 warnings about deprecated API usage in the notification module.

---
```

### File Location

`.session/{story-id}-tandem-{agent}.md`

Example: `.session/95-3-tandem-architect.md`

### Entry-Atomic Writes

Each observation append must be atomic at the entry level:
1. Build complete entry string in memory (header `---`, timestamp, trigger, text, trailing `---`)
2. Write the complete entry in a single `fs.appendFileSync()` or equivalent
3. If crash occurs mid-write, prior entries remain valid markdown
4. The trailing `---` separator ensures the next entry starts cleanly

### Writer API

The observation writer should expose:

```typescript
interface ObservationEntry {
  triggerType: string;       // file-watch, tool-watch, context-watch
  triggerDetail: string;     // e.g., "src/foo.ts modified"
  observation: string;       // The observation text
}

interface ObservationWriterConfig {
  storyId: string;
  agent: string;
  persona: string;
  phase: string;
  sessionDir: string;        // Path to .session/
}

// Create file with header
function initObservationFile(config: ObservationWriterConfig): { success: boolean; path?: string; error?: string }

// Append entry
function appendObservation(filePath: string, entry: ObservationEntry): { success: boolean; error?: string }
```

Note: Returns result objects `{success, data?, error?}` per framework convention — no throwing.

### Implementation Steps

1. Define observation file header format
2. Implement `initObservationFile()` — creates file with metadata header
3. Implement `appendObservation()` — builds complete entry and appends atomically
4. Timestamp format: `[HH:MM]` for entries, ISO for header
5. Write tests: file creation, append, multiple entries, crash simulation (partial write recovery)

## Acceptance Criteria

- Observation file created at `.session/{story-id}-tandem-{agent}.md`
- File header includes observer agent, persona, phase, start timestamp
- Each observation entry includes timestamp, trigger type, trigger detail, and observation text
- Entries are separated by `---` horizontal rules
- Appends are entry-atomic — each write is a complete markdown entry
- File is valid markdown at all times, including after crash during write
- Functions return result objects (`{success, error?}`) instead of throwing

## Dependencies

### Depends On

- **95-2** (Backseat agent spawn) — the backseat agent must be running to create and write the file

### Depended On By

- **95-4** (File-watch scope) — uses writer to append file-watch observations
- **95-5** (Tool-watch scope) — uses writer to append tool-watch observations
- **95-6** (Context-watch scope) — uses writer to append context-watch observations
- **95-7** (Bell mode injection) — reads the observation file for new entries

## Risks / Open Questions

1. **File locking:** If bell mode hook reads the file while the backseat is writing, could it get a partial read? Entry-atomic writes mitigate this — each write is a complete entry. The hook should read up to the last complete `---` separator.

2. **File growth:** Long-running phases could accumulate many observations. Consider a max file size or entry count. For MVP, unbounded is acceptable — phases are time-limited by sprint workflow.

3. **Where to implement:** The writer could be a TypeScript utility in `packages/core/src/workflow/` or a shell script in `pennyfarthing-dist/scripts/lib/`. Since the backseat runs as a Claude Code subagent with access to Bash/Write tools, a shell utility may be more practical. Alternatively, the backseat can write directly using the Write tool with append semantics.
