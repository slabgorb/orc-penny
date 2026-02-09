# Epic 97: CLI Tandem & Shipping Workflow

## Overview

CLI users see tandem status in their statusline, and the framework ships `tdd-tandem` -- a ready-to-use workflow demonstrating tandem in action with Architect backseating during implementation phases.

**Total points:** 4
**Priority:** P2
**Marker:** feature
**Repo:** pennyfarthing
**Stories:** 2

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **PRD** (`sprint/planning/tandem-mode-prd.md`) | FR22-FR25 (CLI statusline, shipping workflow), NFR14 (statusline protocol), "CLI Statusline" section, "Journey 1: Workflow Author" |
| **UX Design Spec** (`sprint/planning/tandem-mode-ux-design.md`) | "Journey 3: CLI User with Tandem" (statusline-only journey), "Feedback Patterns" table (CLI column) |
| **Epic Breakdown** (`sprint/planning/tandem-mode-epics.md`) | Epic 4 full section (Stories 4.1-4.2), FR Coverage Map (FR22-FR25), NFR Coverage (NFR14) |

## Background

### Two Capabilities

1. **CLI statusline tandem indicator** -- When a tandem phase is active, the statusline shows both agent names: `[Toby Ziegler] + Will Bailey`. When the phase ends (or backseat crashes), the suffix drops.

2. **tdd-tandem shipping workflow** -- A ready-to-use workflow YAML that extends the standard TDD flow with Architect backseating during the green phase. Users can adopt tandem without writing custom YAML.

### Why P2

This epic is lower priority because:
- CLI tandem is a secondary UI surface (Cyclist portrait is primary)
- The shipping workflow requires Epic 95 (observation protocol) to be fully functional
- Neither story blocks other tandem work

## Technical Architecture

### CLI Statusline

#### Current Statusline Implementation

**File:** `pennyfarthing-dist/scripts/misc/statusline.sh` (258 lines)

The statusline renders a fixed-width 4-segment format:
```
[ROLE] Theme | repo | branch | model [progress] pct%
```

**Segment 1 (Agent section, ~20 chars):**
- Role displayed as 3-char abbreviation in reverse video with agent-specific ANSI color
- Theme name from persona config appended in dim text
- Color map: PM→purple, SM→blue, DEV→green, TEA→teal, Reviewer→red, Architect→orange, DevOps→cyan, UX→pink, TechWriter→white, Orchestrator→magenta

**Agent name retrieval flow:**
1. `agent-session.sh start "tea" "session-id"` writes agent name to `.session/agents/{session-id}`
2. Statusline reads JSON context from Claude Code stdin
3. Looks up session ID → reads `.session/agents/{session-id}` for agent name
4. Falls back to most recent agent file if session ID doesn't match
5. Character name fetched from theme YAML: `.pennyfarthing/personas/themes/{theme}.yaml`

**Input:** JSON via stdin (from Claude Code):
```json
{
  "workspace.current_dir": "/path/to/project",
  "session_id": "uuid",
  "model": "claude-opus-4-6",
  "context_window": {
    "current_usage": { "input_tokens": N },
    "context_window_size": 200000
  }
}
```

#### Tandem Statusline Extension

**What changes:** Segment 1 grows to show both agents when tandem is active.

**Current format:** `[DEV] Toby Ziegler`
**Tandem format:** `[DEV] Toby Ziegler + Will Bailey`

**How to detect tandem state:** Two options:
- **File-based:** Check for active tandem observation file at `.session/*-tandem-*.md`. If one exists and is recent (mtime within last 60s), tandem is active. Extract backseat agent name from file header.
- **Session-based:** Extend `.session/agents/{session-id}` to optionally include a second line with the backseat agent name. `agent-session.sh` would write this when BikeLane spawns the backseat.

File-based is simpler and doesn't require changing the session protocol. The observation file already has the observer's agent name and persona in its header.

**Key constraint:** No statusline protocol changes required (NFR14). The statusline script already reads stdin JSON and files from `.session/` -- it just reads one more file.

### Shipping Workflow

#### Existing tdd.yaml (Base)

**File:** `pennyfarthing-dist/workflows/tdd.yaml`

```yaml
workflow:
  name: tdd
  description: Test-driven development with code review
  version: "1.0.0"
  phases:
    - name: setup
      agent: sm
      output: [session_file, branches, story_context]
    - name: red
      agent: tea
      input: [session_file, story_context]
      output: [failing_tests]
      gate:
        type: tests_fail
        condition: All acceptance criteria have test coverage
    - name: green
      agent: dev
      input: [failing_tests, story_context]
      output: [implementation, passing_tests]
      gate:
        type: tests_pass
        condition: All tests passing, no skipped tests
    - name: review
      agent: reviewer
      input: [implementation, passing_tests]
      output: [approval]
      gate:
        type: approval
        condition: Code review approved, no blocking issues
    - name: finish
      agent: sm
      input: [approval]
      output: [archived_session, story_summary]
  triggers:
    types: [feature, enhancement]
    points:
      min: 3
    default: true
```

#### tdd-tandem.yaml (New)

The shipping workflow extends standard TDD with a `tandem:` block on the green phase:

```yaml
workflow:
  name: tdd-tandem
  description: TDD with Architect observing during implementation
  version: "1.0.0"
  phases:
    - name: setup
      agent: sm
      output: [session_file, branches, story_context]
    - name: red
      agent: tea
      input: [session_file, story_context]
      output: [failing_tests]
      gate:
        type: tests_fail
        condition: All acceptance criteria have test coverage
    - name: green
      agent: dev
      input: [failing_tests, story_context]
      output: [implementation, passing_tests]
      gate:
        type: tests_pass
        condition: All tests passing, no skipped tests
      tandem:
        partner: architect
        scope: file-watch
    - name: review
      agent: reviewer
      input: [implementation, passing_tests]
      output: [approval]
      gate:
        type: approval
        condition: Code review approved, no blocking issues
    - name: finish
      agent: sm
      input: [approval]
      output: [archived_session, story_summary]
  triggers:
    tags: [tandem]
    points:
      min: 3
    default: false
```

Key differences from standard `tdd.yaml`:
- Name: `tdd-tandem` (distinct from `tdd`)
- Green phase has `tandem: { partner: architect, scope: file-watch }`
- Triggers: explicit `tandem` tag, NOT default (users opt in)
- Non-tandem phases run identically to standard TDD

#### Workflow Discovery

Existing `list-workflows.sh` (`pennyfarthing-dist/scripts/workflow/list-workflows.sh`) auto-discovers workflow files in `.pennyfarthing/workflows/`. Placing `tdd-tandem.yaml` there makes it appear in `/workflow list` automatically with its description.

**Workflow types already supported:**
- Flat YAML: `*.yaml` at root level (tdd.yaml, trivial.yaml, bdd.yaml, etc.)
- Directory: `subdirectory/workflow.yaml` (architecture/, prd/, etc.)

The new file is flat YAML at root level -- simplest form.

### Component Map

```
Agent Session (agent-session.sh)
  |  writes agent name to .session/agents/{session-id}
  v
BikeLane (workflow-executor.ts)
  |  spawns backseat → creates .session/{story}-tandem-{agent}.md
  v
Statusline Script (statusline.sh)
  |  reads .session/agents/{session-id} for primary agent
  |  checks .session/*-tandem-*.md for backseat agent  <-- NEW
  |  renders: [DEV] Toby Ziegler + Will Bailey
  v
CLI Display

Workflow YAML (tdd-tandem.yaml)  <-- NEW FILE
  |  defines phases with tandem: block on green
  v
Workflow Loader (workflow-loader.ts)
  |  loads + validates (including tandem schema from Epic 95)
  v
Workflow List (list-workflows.sh)
  |  auto-discovers tdd-tandem in /workflow list
```

### Key Files (Existing, to be Modified)

| File | Path | Lines | Change |
|------|------|-------|--------|
| Statusline script | `pennyfarthing-dist/scripts/misc/statusline.sh` | 258 | Add tandem detection: check `.session/*-tandem-*.md` for active backseat. Extract observer agent name. Render `+ {backseat character}` suffix |
| Agent session | `pennyfarthing-dist/scripts/core/agent-session.sh` | 394 | No changes needed if using file-based detection. Optional: extend to write backseat info |

### Key Files (New)

| File | Path | Purpose |
|------|------|---------|
| tdd-tandem.yaml | `pennyfarthing-dist/workflows/tdd-tandem.yaml` | Shipping workflow -- standard TDD + Architect tandem on green phase |

### Key Files (Reference Only)

| File | Path | Purpose |
|------|------|---------|
| tdd.yaml | `pennyfarthing-dist/workflows/tdd.yaml` | Base workflow to extend |
| 2party-tdd.yaml | `pennyfarthing-dist/workflows/2party-tdd.yaml` | Complex workflow reference (refinement parties, review loops, `instructions:` blocks) |
| bdd.yaml | `pennyfarthing-dist/workflows/bdd.yaml` | Another phased workflow example (SM → UX → TEA → Dev → Reviewer → SM) |
| list-workflows.sh | `pennyfarthing-dist/scripts/workflow/list-workflows.sh` | Workflow discovery script -- auto-discovers new YAML files |
| workflow-schema.md | `pennyfarthing-dist/guides/workflow-schema.md` | Schema documentation -- needs tandem section after Epic 95 |
| Config | `.pennyfarthing/config.local.yaml` | Theme setting -- determines character name lookup |
| Theme file | `.pennyfarthing/personas/themes/{theme}.yaml` | Maps agent name → character name for display |

### Statusline Color Handling

The existing color map in `statusline.sh`:

| Agent | Color | ANSI |
|-------|-------|------|
| PM | purple | `\033[35m` |
| SM | blue | `\033[34m` |
| DEV | green | `\033[32m` |
| TEA | teal | `\033[36m` |
| Reviewer | red | `\033[31m` |
| Architect | orange | `\033[33m` |
| DevOps | cyan | `\033[96m` |
| UX | pink | `\033[95m` |
| TechWriter | white | `\033[37m` |
| Orchestrator | magenta | `\033[95m` |

The backseat character name in the `+ Will Bailey` suffix should use the backseat agent's color, not the primary's. This visually distinguishes the two agents in the statusline.

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|-------------|
| 97-1 | CLI statusline tandem indicator | 2 | P0 | Epic 95-2 (backseat spawn creates tandem observation file) |
| 97-2 | Ship tdd-tandem workflow | 2 | P1 | Epic 95-1 (tandem YAML schema validation) |

## Story Notes

### 97-1: CLI statusline tandem indicator

**What to do:** Modify `statusline.sh` to detect an active tandem phase and append the backseat agent's character name to the statusline display.

**Detection logic (add after agent name lookup):**
```bash
# Check for active tandem observation file
TANDEM_FILE=$(ls -t .session/*-tandem-*.md 2>/dev/null | head -1)
if [ -n "$TANDEM_FILE" ]; then
  # Check if file is recent (within last 60s = actively observed)
  TANDEM_MTIME=$(stat -f %m "$TANDEM_FILE" 2>/dev/null || stat -c %Y "$TANDEM_FILE" 2>/dev/null)
  NOW=$(date +%s)
  if [ $((NOW - TANDEM_MTIME)) -lt 60 ]; then
    # Extract observer agent from file header
    TANDEM_AGENT=$(grep '^**Observer:**' "$TANDEM_FILE" | sed 's/.*: \([^ ]*\).*/\1/')
    # Look up character name from theme
    TANDEM_CHARACTER=$(...)
  fi
fi
```

**Display format:**
- Without tandem: `[DEV] Toby Ziegler`
- With tandem: `[DEV] Toby Ziegler + Will Bailey`
- Width budget: the agent section is ~20 chars. With tandem, it needs ~35-40 chars. May need to truncate character names or abbreviate.

**Key constraints:**
- No statusline protocol changes (NFR14)
- No tandem indicator when no `tandem:` configuration exists
- Indicator drops when phase ends or backseat crashes (observation file stops updating)

### 97-2: Ship tdd-tandem workflow

**What to do:** Create `pennyfarthing-dist/workflows/tdd-tandem.yaml` with the standard TDD phase sequence plus `tandem: { partner: architect, scope: file-watch }` on the green phase.

**Key requirements:**
- Standard TDD phases: setup → red → green → review → finish
- Only green phase has tandem config
- Non-tandem phases run identically to standard `tdd`
- Triggers: `tags: [tandem]`, NOT `default: true` (users opt in)
- Appears in `/workflow list` with description

**Verification:**
- BikeLane loads and validates the workflow successfully (Epic 95-1 validation)
- Running a story with tdd-tandem spawns Architect as backseat during green phase
- Non-tandem phases have no backseat, no tandem indicator

## Constraints

- **No statusline protocol changes** (NFR14): Use existing stdin JSON format and file-based detection
- **Opt-in workflow**: `tdd-tandem` is NOT default -- requires explicit `tandem` tag or workflow selection
- **Identical non-tandem phases**: setup, red, review, finish run exactly as standard `tdd`
- **File placement**: Workflow YAML goes in `pennyfarthing-dist/workflows/` (source of truth), gets symlinked to `.pennyfarthing/workflows/` at install time

## Dependencies

**Depends on:**
- Epic 95-1 (Tandem YAML schema) -- the `tandem:` block must be parseable by BikeLane
- Epic 95-2 (Backseat agent spawn) -- the observation file must exist for statusline detection

**Depended on by:**
- Nothing. This is the shipping layer -- CLI polish and a ready-to-use workflow.
