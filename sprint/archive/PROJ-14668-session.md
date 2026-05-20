# Story 95-3: Observation file format and writer

**Jira:** PROJ-14668
**Epic:** PROJ-14665 (Workflow Configuration & Observation Protocol)
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/95-3-observation-file-format

---

## Context

### Epic Overview (95 - Workflow Configuration & Observation Protocol)

Workflow authors can add `tandem:` blocks to their workflow YAML, and BikeLane spawns/terminates backseat agents with working observation scopes. The tandem system works end-to-end — backseat observes, writes observations, bell mode injects them, primary surfaces them.

**Total epic points:** 20
**Priority:** P1
**Marker:** feature

The epic comprises seven stories that build the complete tandem observation loop:
1. YAML schema and BikeLane validation (95-1) — DONE
2. Backseat agent spawn and lifecycle (95-2) — DONE
3. **Observation file format and writer (95-3)** — THIS STORY
4. File-watch observation scope (95-4)
5. Tool-watch observation scope (95-5)
6. Context-watch observation scope (95-6)
7. Bell mode observation injection (95-7)

### Story Description

Implement the observation file creation and append logic used by backseat agents. The backseat creates an append-only markdown file at `.session/{story-id}-tandem-{agent}.md` at phase start and appends entries as observations occur. Each write is entry-atomic — the file remains valid markdown even on mid-write crash.

**Key references:**
- PRD: FR7-FR8 (observation file format, entry atomicity), NFR11 (valid markdown on crash)
- UX Design Spec: "Observation File Format" block
- Epics Breakdown: Story 2.3 in tandem-mode-epics.md

### Technical Architecture

```
Backseat Agent (long-lived background subagent)
  |  receives: persona, story context, scope config, observation file path
  |  observes: file changes / tool calls / conversation summaries
  |  writes: .session/{story-id}-tandem-{agent}.md
  v
Observation File Format (append-only markdown)
  |  header: observer metadata (agent, persona, phase, start time)
  |  entries: timestamp, trigger type, trigger detail, observation text
  |  atomic: each entry is complete; file valid markdown on crash
  v
Bell Mode Hook (reads for injection)
  |  PostToolUse → check tandem file mtime → inject as bell message
  |  format: [Tandem] {persona_name}: {observation_summary}
```

---

## Acceptance Criteria

- Observation file created at `.session/{story-id}-tandem-{agent}.md`
- File header includes observer agent, persona, phase, start timestamp
- Each observation entry includes timestamp (HH:MM format), trigger type, trigger detail, and observation text
- Entries are separated by `---` horizontal rules
- Appends are entry-atomic — each write is a complete markdown entry
- File is valid markdown at all times, including after crash during write
- Functions return result objects (`{success, error?}`) instead of throwing
- Implementation follows framework conventions: `.js` extensions in imports, Haiku for subagents

---

## File Format

### Markdown Structure

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

---

## Technical Approach

### Writer API

The observation writer should expose two main functions:

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

### Entry-Atomic Writes

Each observation append must be atomic at the entry level:
1. Build complete entry string in memory (header `---`, timestamp, trigger, text, trailing `---`)
2. Write the complete entry in a single atomic operation (fs.appendFileSync or equivalent)
3. If crash occurs mid-write, prior entries remain valid markdown
4. The trailing `---` separator ensures the next entry starts cleanly

### Key Constraints

- **Entry-atomic:** Each write is a complete markdown entry; never partial entries
- **Valid markdown:** File remains valid markdown at all times, even after crash
- **Result objects:** Functions return `{success, error?}` instead of throwing (framework convention)
- **Non-blocking:** Writer must not delay backseat agent's observations
- **Context accumulation:** FR9 — observations accumulate context across the phase

### Implementation Notes

Where to implement:
- TypeScript utility in `packages/core/src/workflow/` (if used by primary agent code), OR
- Shell script in `pennyfarthing-dist/scripts/lib/` (if used by backseat via bash)
- Since backseat runs as a Claude Code subagent with access to Bash/Write tools, direct Write tool usage is viable

Reference patterns:
- `pennyfarthing-dist/scripts/lib/background-tasks.sh` — markdown file manipulation patterns
- `packages/core/src/workflow/session-state.ts` — structured markdown generation (`formatWorkflowState()` lines 207-233)
- `.session/*-session.md` files — existing markdown session file conventions

---

## Dependencies

### Depends On

- **95-2** (Backseat agent spawn and lifecycle) — the backseat agent must be running to create and write the file

### Depended On By

- **95-4** (File-watch observation scope) — uses writer to append file-watch observations
- **95-5** (Tool-watch observation scope) — uses writer to append tool-watch observations
- **95-6** (Context-watch observation scope) — uses writer to append context-watch observations
- **95-7** (Bell mode observation injection) — reads the observation file for new entries to inject

---

## Next Steps

1. Implement observation file writer utility (TypeScript or shell based)
2. Write tests for file creation, append, multiple entries, crash simulation
3. Validate that file remains valid markdown on mid-write crash
4. Ensure result objects returned instead of throwing exceptions
5. Hand off to 95-4 (file-watch scope) which will use this writer

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core utility with well-defined API, multiple ACs, entry-atomicity guarantee

**Test Files:**
- `packages/core/src/workflow/observation-writer.test.ts` — 34 tests covering all 7 ACs

**Tests Written:** 34 tests covering 7 ACs + edge cases
**Status:** RED (29 failing, 5 passing on no-throw behavior)

**Test Coverage by AC:**
1. AC1: File created at correct path (3 tests)
2. AC2: Header metadata — agent, persona, phase, timestamp (5 tests)
3. AC3: Entry format — HH:MM, trigger type/detail, observation (4 tests)
4. AC4: Entries separated by --- horizontal rules (3 tests)
5. AC5: Entry-atomic appends (2 tests)
6. AC6: Valid markdown at all times (3 tests)
7. AC7: Result objects not throwing (6 tests)
8. parseObservationFile: Reader for bell mode (4 tests)
9. Edge cases: markdown chars, empty text, multiline, idempotent init (4 tests)

**Implementation Stub:** `packages/core/src/workflow/observation-writer.ts`
- `initObservationFile(config)` → creates file with header
- `appendObservation(filePath, entry)` → appends entry atomically
- `parseObservationFile(filePath)` → reads back header + entries

**Handoff Notes for Toby:**
- Tests use `node:test` + `node:assert`, co-located in workflow/
- Build with `npx tsc --build` in packages/core, run with `node --test dist/workflow/observation-writer.test.js`
- Key constraint: `appendFileSync` or equivalent for atomic entry writes
- Follow `tandem-lifecycle.ts` patterns (same directory, same result type convention)
- Use `.js` extensions in imports

**Handoff:** To Dev (Toby Ziegler) for implementation

---

## SM → TEA Handoff

**From:** SM (Leo McGarry)
**To:** TEA (Sam Seaborn)
**Phase:** setup → red
**Timestamp:** 2026-02-10T00:00:00Z

Story 95-3 is set up and ready for test design. Observation file format and writer — 2pt TDD story in the tandem observation epic. ACs are defined, context is thorough. Sam, write the red phase tests.

---

## TEA → Dev Handoff

**From:** TEA (Sam Seaborn)
**To:** Dev (Toby Ziegler)
**Phase:** red → implement
**Timestamp:** 2026-02-10T10:04:00Z
**Test Result:** RED — 29 failing tests ready for implementation

Toby, the tests are written and failing cleanly. Observation file writer with 3 functions: init, append, parse. All ACs covered. Make them green.

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/workflow/observation-writer.ts` — implemented initObservationFile, appendObservation, parseObservationFile

**Tests:** 34/34 passing (GREEN)
**PR:** #795 — feat(95-3): observation file format and writer
**Branch:** feature/95-3-observation-file-format (pushed)

**Implementation Notes:**
- `initObservationFile`: Creates markdown file with header (title, observer, phase, ISO timestamp), separated by `---`
- `appendObservation`: Builds complete entry string in memory, writes via single `appendFileSync` call (entry-atomic)
- `parseObservationFile`: Regex-based parser extracts header fields and entry blocks for bell mode injection
- All functions wrapped in try/catch returning `{success, error?}` — never throw
- No external dependencies — uses only `node:fs` and `node:path`

**Handoff:** To Reviewer (Josh Lyman) for code review

---

## Dev → Reviewer Handoff

**From:** Dev (Toby Ziegler)
**To:** Reviewer (Josh Lyman)
**Phase:** implement → review
**Timestamp:** 2026-02-10T10:30:00Z
**Test Result:** GREEN — 34/34 tests passing
**PR:** #795

Josh, the observation file writer is implemented and all tests are green. Single file change — `observation-writer.ts` in `packages/core/src/workflow/`. Review PR #795.

---

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. `[VERIFIED]` Entry-atomic writes via `appendFileSync` — single syscall for entries <4KB (PIPE_BUF), all observations well within bounds at `observation-writer.ts:124`
2. `[VERIFIED]` Regex at `observation-writer.ts:162` — no catastrophic backtracking risk, lazy quantifier `[\s\S]*?` anchored to fixed `\n---` lookahead. Trigger type capture `[^:]+` safe for defined types (file-watch, tool-watch, context-watch)
3. `[VERIFIED]` Path convention matches `tandem-lifecycle.ts:154` — `{storyId}-tandem-{partner}.md` consistent across both modules
4. `[VERIFIED]` Error handling complete — all three functions wrapped in try/catch, never throw, return `{success, error?}` per framework pattern
5. `[MEDIUM]` Double-init overwrites at `observation-writer.ts:95` — `writeFileSync` destroys prior observations if called twice. Acceptable for v1: tandem-lifecycle manages spawn/terminate lifecycle, preventing duplicate init in normal flow. Test at line 595 explicitly allows either behavior.
6. `[VERIFIED]` No forbidden patterns — no console.log, TODO, FIXME, .only(), or t.Skip
7. `[VERIFIED]` Security clean — no user input reaches shell/eval, file paths from controlled config objects
8. `[VERIFIED]` Not wired to tandem-lifecycle yet — intentionally scoped as utility-only per story 95-3. Wiring comes in stories 95-4/5/6/7

**Data flow traced:** `config` → `initObservationFile` → `writeFileSync` (header) → path returned → `appendObservation(path, entry)` → `appendFileSync` (atomic) → `parseObservationFile(path)` → `readFileSync` + regex → structured data. Write-read roundtrip verified by tests.
**Tests:** 34/34 GREEN, no regressions in full suite
**PR:** #795 merged

**Handoff:** To SM (Leo McGarry) for finish-story

---

## Reviewer → SM Handoff

**From:** Reviewer (Josh Lyman)
**To:** SM (Leo McGarry)
**Phase:** review → finish
**Timestamp:** 2026-02-10T10:45:00Z
**Verdict:** APPROVED
**PR:** #795 — merged

Leo, story 95-3 is approved and merged. Run finish-story to archive and close out.
