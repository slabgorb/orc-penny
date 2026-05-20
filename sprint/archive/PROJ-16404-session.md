---
story_id: "143-17"
jira_key: "PROJ-16404"
epic: "PROJ-16358"
workflow: "tdd"
---
# Story 143-17: Saddle — tmux-based interactive agent workspace

## Story Details
- **ID:** 143-17
- **Jira Key:** PROJ-16404
- **Epic:** PROJ-16358 (Native Subagent Migration)
- **Workflow:** tdd
- **Points:** 5
- **Priority:** p1
- **Repos:** pennyfarthing
- **Stack Parent:** none

## Context

### Background
During story 143-16 (BikeRack observability for subagent transitions), scope was redirected from post-hoc event timeline visualization to a new concept: **Saddle** — an interactive tmux-based agent workspace.

**What is Saddle?**
- The Saddle is a tmux pane that splits the CLI pane horizontally — the original CLI pane stays on top, the Saddle (active agent) sits beneath it, and the BikeRack TUI sits underneath
- Each agent runs in the Saddle pane (visible, interactive, not backgrounded)
- User can see live agent output in real time
- User can interrupt/pause an agent mid-phase
- User can resume or redirect the agent after inspection
- Fits the bike metaphor: BikeRack (TUI dashboard), WheelHub (server), TirePump (context clearing), Saddle (agent workspace)

**Layout (top to bottom):**
```
┌─────────────────────────┐
│  CLI pane (original)    │  ← user's main Claude Code session
├─────────────────────────┤
│  Saddle pane (agent)    │  ← active agent runs here, interactive
├─────────────────────────┤
│  BikeRack TUI           │  ← observability dashboard
└─────────────────────────┘
```

### What Stays
The telemetry foundation shipped in 143-16 remains:
- Event emitter for agent lifecycle events
- WebSocket channel for real-time updates to BikeRack
- WheelHub FastAPI endpoints for observability
- This story adds the **interactive tmux pane interface** on top of that foundation

### Why Saddle?
Current model: SM spawns subagents via Agent tool, they run in background, user can't see or interrupt them
- Agents finish → handoff document returned → SM reads it and chains to next phase
- User must wait for full phase to complete before seeing output
- No way to interrupt mid-phase if agent is stuck

Proposed model (Saddle):
- SM launches agent in a visible tmux pane
- User can watch execution unfold in real time
- User can Ctrl+C to interrupt agent without killing the session
- Agent pause state recorded in session file
- User can resume from that pause or manually advance to next phase
- Integrates with existing handoff document contract (no schema change needed)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish (TEA writes failing tests)
**Phase Started:** 2026-03-13T11:12:28Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T10:51:14Z | 2026-03-13T10:51:14Z | - |
| red | 2026-03-13T10:52:39Z | 2026-03-13T11:00:03Z | 7m 24s |
| green | 2026-03-13T11:00:03Z | 2026-03-13T11:09:38Z | 9m 35s |
| verify | 2026-03-13T11:09:38Z | 2026-03-13T11:09:48Z | 10s |
| review | 2026-03-13T11:09:48Z | 2026-03-13T11:12:28Z | 2m 40s |
| finish | 2026-03-13T11:12:28Z | - | - |

## Design Questions for Architect

The following questions need clarity before TEA writes tests:

1. **tmux Integration**
   - Does Saddle replace the Agent tool spawning, or wrap it?
   - Should SM call `pf tmux run {agent}` instead of Agent tool, or should Agent tool internally use tmux?
   - How does Saddle interact with the existing `pf tmux run` infrastructure?

2. **Agent Handoff During Interactive Mode**
   - When user pauses an agent mid-phase, how is the session state saved?
   - When user resumes, does the agent restart from the beginning or continue from where it paused?
   - If user redirects to next phase (bypassing pause), how does SM know the previous phase incomplete?

3. **Interrupt & Resume**
   - How does the user interrupt an agent (Ctrl+C)? Does it kill the subprocess or pause it?
   - After interrupt, is the agent context (tools invoked, files written) preserved for resume?
   - Can user manually edit the handoff document before resuming, or is it read-only?

4. **BikeRack Integration**
   - How does BikeRack show agent status when running in tmux pane (vs backgrounded)?
   - Should BikeRack show the tmux pane output inline, or link to it, or both?
   - How does the user switch between multiple agents if running in tandem mode?

5. **Backwards Compatibility**
   - Can Saddle coexist with the current backgrounded Agent tool mode?
   - Should there be a config flag to enable/disable Saddle per workflow or agent?

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- Added `mock_tmux` fixture to 9 tests that need tmux pane creation — tests were calling real tmux which fails in small panes. Spec didn't mention mocking strategy; this was necessary for CI/dev environments without a large tmux session.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

## TEA Assessment

**Tests Required:** Yes
**Reason:** 5-point feature story — core Saddle module needs full test coverage

**Test Files:**
- `tests/python/test_143_17_saddle.py` — 26 tests across 6 classes

**Tests Written:** 26 tests covering 5 ACs
- AC1: Saddle pane creation and layout (4 tests)
- AC2: Agent start/stop lifecycle (6 tests)
- AC3: Registry integration — saddle as protected role (7 tests)
- AC4: Status reporting (3 tests)
- AC5: Handoff integration — relay uses saddle pane (2 tests)
- Edge cases: tmux down, empty name, double-stop (4 tests)

**Status:** RED (17 failing via NotImplementedError, 9 passing on registry + handoff mocks)

**Implementation created:**
- `pf/saddle/__init__.py` — package stub
- `pf/saddle/core.py` — 4 stub functions: `ensure_saddle_pane`, `start_agent`, `stop_agent`, `status`
- `pf/tmux/registry.py` — added "saddle" to `PROTECTED_ROLES` and `_TITLE_CLASSIFIERS`

**Handoff:** To The White Rabbit (Dev) for implementation

## Dev Assessment

**Implementation Files:**
- `pf/saddle/core.py` — 4 public functions + state management (182 lines)
- `pf/saddle/__init__.py` — package stub
- `pf/tmux/registry.py` — added "saddle" to `PROTECTED_ROLES` and `_TITLE_CLASSIFIERS`

**Implementation Details:**
- `ensure_saddle_pane`: Creates tmux pane by splitting below CLI pane (10 lines absolute), sets title "Saddle", persists pane_id to state file. Reuses existing pane if state file has one.
- `start_agent`: Validates agent name against `VALID_AGENTS`, ensures saddle pane, sends `claude /pf-{agent}` via `send_keys`, emits telemetry event (fire-and-forget), updates state.
- `stop_agent`: Sends Ctrl-C to saddle pane, clears active/agent in state file.
- `status`: Reads state file, returns `{active, agent, pane_id}`.
- State stored in `.pennyfarthing/saddle-state.json` — JSON with `active`, `agent`, `pane_id` fields.
- Uses module-level `from pf.tmux import panes as _panes` so test patches propagate correctly.

**Test Modifications:**
- Added `mock_tmux` fixture to 9 tests that call real tmux — patches `is_tmux_running`, `get_session_name`, `list_live_panes`, `_run_tmux`, `set_pane_title`, `send_keys`

**Test Results:** 26/26 passing

**Handoff:** To TEA for verification

## SM Assessment

Story 143-17 is ready for TEA RED phase. This is a foundational story for making agents more interactive and observable. The design questions above are critical to scope and implementation, but they shouldn't block TEA from writing acceptance tests. TEA can start with the high-level requirement: "When an agent is spawned, the user can see its output in real time and can interrupt it without losing the session context."

**Key constraints:**
- Must preserve the existing handoff document contract (no schema changes)
- Must work with gitflow PRs in pennyfarthing repo
- Must maintain compatibility with existing TDD workflow phases
- Telemetry backbone from 143-16 is available and should be reused

**Recommended next steps:**
1. TEA writes failing tests that verify: agent output visible in tmux, interrupt-safe, pause context preserved
2. Dev uses those tests to guide implementation of tmux integration
3. Architect clarifies design questions during dev phase as implementation details emerge