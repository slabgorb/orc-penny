# Story Context: 95-4 - File-Watch Observation Scope

## Summary

Implement file change detection for the backseat agent running with `scope: file-watch`. The backseat monitors the working tree for file create, modify, and delete events, and writes observations to the tandem observation file. Detection must occur within 5 seconds of the change, must not block the primary agent, and must accumulate context across observations within the phase.

## Planning References

- **PRD:** FR9 (file-watch scope), FR10 (context accumulation), NFR1 (non-blocking), NFR3 (5s detection). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Three Observation Scopes" table in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 2.4 in `sprint/planning/tandem-mode-epics.md` under "Epic 2"

## Current State

### No file-watch infrastructure exists

The codebase has no file change detection for tandem purposes. The primary agent uses tools (Glob, Grep, Read, Write, Edit) to interact with files, but no background watcher tracks these changes.

### Backseat agent context

The backseat runs as a long-lived Claude Code subagent (from 95-2) with access to Bash, Glob, Grep, Read tools. It can:
- Run shell commands (`git status`, `git diff`, `find`)
- Read files and directories
- Write to the observation file (from 95-3)

### Observation file (from 95-3)

The backseat writes to `.session/{story-id}-tandem-{agent}.md` using the entry-atomic append pattern. Each observation includes trigger type `file-watch` and trigger detail (file path + event type).

## Target State

After implementation:

1. Backseat with `scope: file-watch` detects file changes (create, modify, delete) in the working tree
2. Changes detected within 5 seconds of occurrence
3. Observations written with trigger type `file-watch` and detail: `{path} {created|modified|deleted}`
4. Non-blocking to primary agent — backseat runs independently as background subagent
5. Context accumulates — backseat builds understanding across observations (e.g., "this is the third file in the notification module to be modified")

## Key Files

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| Observation writer | (from 95-3) | API for appending observations |
| `background-tasks.sh` | `pennyfarthing/pennyfarthing-dist/scripts/lib/background-tasks.sh` | Background task patterns |

## Technical Approach

### Implementation Strategy

The backseat is a Claude Code subagent — it reasons and acts in a loop. The simplest file-watch implementation uses periodic polling:

**Option A: Git-based polling (recommended)**
1. Backseat runs `git status --porcelain` periodically (every 3-5 seconds)
2. Compares output to previous snapshot
3. New or changed entries become observations
4. Simple, reliable, works without additional dependencies
5. Naturally filters `.gitignore`d files

**Option B: Find-based polling**
1. Run `find . -newer {timestamp-file} -type f` periodically
2. Touch a timestamp marker file after each check
3. New files since last check become observations

**Option C: fs.watch / chokidar**
1. Use filesystem events for real-time detection
2. More complex setup within a subagent context
3. May not be practical since the backseat is a Claude Code agent, not a Node.js process

### Recommended: Option A

The backseat agent's prompt instructs it to:
1. Take initial snapshot: `git status --porcelain` + `git diff --stat`
2. Enter observation loop (every 3-5 seconds):
   - Run `git status --porcelain` and `git diff --name-only`
   - Compare to previous snapshot
   - For each new/changed file, read relevant content and write observation
3. Accumulate context: maintain mental model of what's changing and why
4. Write observations via the append pattern from 95-3

### Observation Entry Example

```markdown
---

## [10:32] Observation
**Trigger:** file-watch: src/components/Header.tsx modified
The Header component now imports useTheme from the new theme context. This follows the same pattern used in Footer.tsx (modified 2 minutes ago). The migration from vanilla CSS to theme hooks is progressing through the component tree top-down.

---
```

### Backseat Prompt Addition (file-watch scope)

```
## File-Watch Scope Instructions

Monitor the working tree for file changes. Every 3-5 seconds:
1. Run: git status --porcelain
2. Run: git diff --name-only
3. Compare to your previous snapshot
4. For new/changed files, read the relevant portions
5. Write an observation noting what changed and your analysis

Focus on:
- Patterns across multiple file changes
- Consistency with project conventions
- Potential issues or improvements
- How changes relate to the story's acceptance criteria

Accumulate context — reference earlier observations when relevant.
```

## Acceptance Criteria

- Backseat detects file creates, modifies, and deletes in the working tree
- Detection occurs within 5 seconds of the change
- Observations written with trigger type `file-watch`
- Trigger detail includes file path and event type (created/modified/deleted)
- Observation text includes analysis, not just raw file listing
- Context accumulates across observations within the phase
- Non-blocking to primary agent
- `.gitignore`d files are excluded

## Dependencies

### Depends On

- **95-2** (Backseat agent spawn) — backseat must be running
- **95-3** (Observation file format) — writes using the observation file format

### Depended On By

- **95-7** (Bell mode injection) — reads file-watch observations for injection into primary agent

## Risks / Open Questions

1. **Polling frequency vs token usage:** Each polling cycle uses the backseat's context window (git commands, file reads, observation writes). Polling every 3 seconds for a 30-minute phase could consume significant tokens. Consider adaptive polling — more frequent when changes are happening, less frequent during quiet periods.

2. **Large diffs:** If the primary agent writes a large file, `git diff` output could be very long. The backseat should focus on summary-level analysis, not full diffs. Truncate or summarize large changes.

3. **Git state conflicts:** If the primary agent is mid-`git add` or `git commit`, the backseat's `git status` might see transient state. This is acceptable — the backseat's observations are advisory, not authoritative.

4. **Scope boundaries:** Should the backseat only watch files in the current repo, or also the orchestrator repo? Likely just the `pennyfarthing/` repo based on the story's `repos: pennyfarthing` field.
