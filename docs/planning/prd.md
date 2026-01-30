---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain (skipped)
  - step-06-innovation (skipped)
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
classification:
  projectType: CLI Tool / Developer Tooling
  domain: Developer Experience (DX) / Build Infrastructure
  complexity: Medium
  projectContext: brownfield
inputDocuments:
  - docs/adr/0005-single-source-of-truth-symlinks.md
  - pennyfarthing/pennyfarthing_scripts/__init__.py
workflowType: 'prd'
documentCounts:
  briefCount: 0
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 21
partyModeContext: |
  From party mode brainstorm on 2026-01-30:
  - Problem: Script path discovery breaks due to symlink chains
  - Solution direction: Single Python CLI (`pf`) that knows its own location
  - Key insight: "The problem isn't finding scripts - it's that scripts exist as separate files"
  - Existing Python infrastructure in pennyfarthing_scripts/ (60+ files, v7.6.1)
  - Distribution via `uv` / `uvx pennyfarthing`
---

# Product Requirements Document - Pennyfarthing Python CLI

**Author:** Keith Avery
**Date:** 2026-01-30

## Success Criteria

### User Success (The Agent)

- **Zero path errors** - When an agent invokes a Pennyfarthing command, it executes. Period.
- **No manual recovery** - Agents never need to "read the script and do it manually"
- **Consistent behavior** - Same command, same result, regardless of installation method

### Business Success (Framework Health)

- **Elimination of symlink-related issues** - No more broken symlink tickets/debugging
- **Reduced agent context waste** - Agents spend tokens on work, not path debugging
- **Simpler maintenance** - One codebase (Python), not bash+symlinks+node

### Technical Success

- **Single entry point** - All script functionality accessible via one mechanism
- **Self-locating** - The CLI knows where it lives without PROJECT_ROOT hunting
- **No symlinks** - Zero symlinks in the critical path

### Measurable Outcomes

- Path-related errors in agent sessions: **Current → 0**
- Manual script execution by agents: **Eliminated**

## Product Scope

### MVP - Minimum Viable Product

- Python CLI that replaces critical bash scripts (workflow, sprint, agent-session)
- Self-locating: knows its own install path without environment variables
- Invocable from agent commands without path construction
- Internal only: ships with npm package, runs inside Cyclist

### Growth Features (Post-MVP)

- Migration of remaining bash scripts to Python
- Performance optimizations (lazy loading, caching)
- Enhanced error messages with recovery suggestions

### Vision (Future)

- Complete elimination of bash scripts
- Single `pf` command for all Pennyfarthing operations
- Plugin architecture for project-specific extensions

## User Journeys

### Journey 1: Agent Executing a Workflow Command

**Persona:** SM Agent (Baldur the Bright) running inside Cyclist

**Opening Scene:** SM activates via `/sm` command. The command file needs to check workflow state.

**Current Pain:** Command contains `.pennyfarthing/scripts/core/run.sh workflow/check.sh` - symlink is broken, agent sees error, tries to manually read and execute, wastes context.

**New Experience:**
- Command contains: `python -m pennyfarthing_scripts.cli workflow check`
- Python module resolution finds it (no paths needed)
- Returns structured output: "Story 67-2 in RED phase, owned by TEA"

**Resolution:** SM gets the answer, outputs handoff marker, exits. Zero path debugging.

### Journey 2: Framework Developer Adding a Command

**Persona:** Keith maintaining Pennyfarthing

**Opening Scene:** Need to add `workflow fix-phase` command.

**New Experience:**
- Add function to `pennyfarthing_scripts/workflow/cli.py`
- Register with Click decorator
- Test: `python -m pennyfarthing_scripts.cli workflow fix-phase --help`

**Resolution:** No symlinks to create. No `run.sh` to update. Just Python code.

### Journey 3: Migrating a Bash Script

**Persona:** Developer migrating `sprint/archive-story.sh`

**Opening Scene:** Bash script exists, works, but contributes to symlink complexity.

**New Experience:**
- Port logic to `pennyfarthing_scripts/sprint/archive.py`
- Add CLI entry point
- Update agent commands to use Python invocation
- Delete bash script

**Resolution:** One less bash script. One less symlink target. Cleaner codebase.

## Journey Requirements Summary

| Journey | Capability Needed |
|---------|------------------|
| Agent Execution | Module-based invocation (`python -m`), no path construction |
| Developer Extension | Click-based CLI, decorator registration, standard Python patterns |
| Migration | Coexistence during transition, incremental adoption |

## CLI Technical Requirements

### Invocation Pattern

- **Command:** `python -m pennyfarthing_scripts.cli <module> <action>`
- **Structure:** `pf <module> <action>` (e.g., `pf sprint status`, `pf workflow check`)

### Output Format

- **Default:** Markdown text (human-readable, agent-friendly)
- **Flag:** `--json` for structured JSON output (machine parsing)

### Error Handling

- **Exit code 0:** Command executed successfully (result may be "empty", "not found" - that's valid)
- **Exit code non-zero:** Real error (file corrupt, permissions, bug)
- **Design principle:** "Nothing here" is an answer. "I couldn't look" is an error.
- **Hard fail on real errors:** Creates bug story in Pennyfarthing automatically
- **Stderr:** Error details for debugging (only on real errors)

### Project Root Discovery

- **Solution:** Editable pip install (`pip install -e ./path/to/pennyfarthing`)
- **Mechanism:** Python module resolution handles location
- **Sync:** Requires pip install after npm install (or automated via postinstall/just recipe)

### Distribution

- Ships with npm package (not published to PyPI)
- Internal only - runs inside Cyclist
- Requires `pip install -e` step for module resolution

## Migration Phases

### Phase 1: MVP - Agent Activation (Stop the Bleeding)

Scripts called on every agent activation - highest frequency, highest pain:

| Script | New Command | Purpose |
|--------|-------------|---------|
| `workflow-status-check` | `pf workflow check` | Detect workflow state |
| `agent-session.sh start` | `pf agent start <name>` | Load agent context |
| `phase-check-start.sh` | `pf workflow phase-check` | Verify phase ownership |

### Phase 2: Core Operations

Scripts for daily workflow operations:

| Script | New Command | Purpose |
|--------|-------------|---------|
| `sprint-status.sh` | `pf sprint status` | Show sprint state |
| `available-stories.sh` | `pf sprint backlog` | List available work |
| `handoff-marker.sh` | `pf workflow handoff` | Emit handoff marker |

### Phase 3: Full Migration

Incremental migration of remaining scripts as bandwidth allows. Low-frequency utilities can stay bash longer.

## Functional Requirements

### CLI Core

- **FR1:** Agent can invoke CLI commands via `python -m pennyfarthing_scripts.cli <module> <action>`
- **FR2:** CLI can output results in markdown format (default)
- **FR3:** CLI can output results in JSON format (via `--json` flag)
- **FR4:** CLI can report valid "empty" states with exit code 0
- **FR5:** CLI can report real errors with non-zero exit code and stderr message

### Workflow Operations

- **FR6:** Agent can check current workflow state (story ID, phase, owner)
- **FR7:** Agent can verify phase ownership for a given workflow and phase
- **FR8:** Agent can emit handoff markers for Cyclist
- **FR9:** Agent can detect workflow state: FINISH, NEW_WORK, IN_PROGRESS, EMPTY_BACKLOG

### Agent Lifecycle

- **FR10:** Agent can start a session with persona and context loading
- **FR11:** Agent can load sprint context at activation
- **FR12:** Agent can load sidecar memory (patterns, gotchas, decisions)

### Sprint Operations

- **FR13:** Agent can view current sprint status (progress, points, stories)
- **FR14:** Agent can view available stories in backlog
- **FR15:** Agent can get story details by ID

### Error Handling

- **FR16:** CLI can create bug story automatically on hard failure
- **FR17:** CLI can distinguish "valid empty state" from "real error"

### Developer Experience

- **FR18:** Developer can add new commands via Click decorators
- **FR19:** Developer can test commands locally via `python -m` invocation
- **FR20:** Developer can migrate bash scripts incrementally (coexistence)

## Non-Functional Requirements

### Performance

- **NFR1:** CLI commands complete within 500ms for typical operations
- **NFR2:** CLI startup time under 200ms (no slow imports blocking agent activation)
- **NFR3:** JSON output parsing adds no measurable overhead vs markdown

### Reliability

- **NFR4:** CLI never silently fails - always produces output or error
- **NFR5:** Partial failures (e.g., one field missing) don't crash entire command
- **NFR6:** Graceful degradation when optional dependencies unavailable

### Integration

- **NFR7:** CLI output is parseable by existing bash scripts during migration
- **NFR8:** CLI can coexist with bash scripts (no conflicts)
- **NFR9:** CLI respects existing file formats (session files, sprint YAML)

