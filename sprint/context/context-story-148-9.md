# Story 148-9: Peloton live mode — persistent tmux panes for team mode agents

**Points:** 3
**Workflow:** tdd
**Status:** backlog

---

## Story Title

Pre-spawn persistent tmux panes for each agent role at story start, so that Claude's native team mode (`TeamCreate`/`SendMessage`) operates through visible, interactive tmux panes. The user can switch to any agent's pane at any time. Panes survive the full story lifecycle.

---

## Background: Why This Exists

**Saddle mode** (143-17/18) tried to solve agent collaboration with a single pane. Problems:
- **One-way** — you summon an agent, but there's no structured return path
- **No coordination** — agents don't know about each other
- **Relay required polling** — passing work between panes meant polling for completion, which was fragile

**Claude's native team mode** (`TeamCreate`, `SendMessage`, `TeamDelete`) solves the coordination problem. Agents can communicate bidirectionally. But team mode agents run as background subprocesses — the user can't see or interact with them.

**Peloton mode** bridges this gap: pre-spawn persistent tmux panes, one per agent role. Team mode coordinates the agents; tmux panes give them a visible, interactive home.

This is **not** the Peloton Replay benchmark mode (148-8). That replays scenarios for scoring. This is the **live working mode** for real stories.

---

## Acceptance Criteria

1. **`pf peloton start` pre-spawns panes based on workflow**
   - Reads the active story's workflow YAML to determine which agent roles are needed
   - Creates one tmux pane per unique agent role in the workflow phases
   - Pane naming: `peloton-{role}` (e.g., `peloton-tea`, `peloton-dev`, `peloton-reviewer`)
   - Panes are registered in `.pennyfarthing/tmux-panes.json` with role `agent`
   - Does NOT start `claude` in the panes yet — just idle shells, ready to go

2. **`pf peloton next` activates the next phase's agent in its pane**
   - Determines the current workflow phase from session file
   - Launches `claude -p "$(pf agent start {role})"` in that role's pane (reusing saddle's subprocess pattern)
   - Updates peloton state to track which pane is active
   - User can interact with the agent in that pane

3. **`pf peloton switch <role>` lets user jump to any pane**
   - Focuses the named pane (tmux select-pane)
   - If agent isn't started in that pane yet, optionally starts it
   - Works even if that role's phase hasn't been reached in the workflow

4. **Panes persist through the full story lifecycle**
   - Panes are NOT killed between phases (unlike saddle which stops agent on phase change)
   - Previous agent's session remains visible — user can scroll back through its output
   - State file tracks all peloton panes: `.pennyfarthing/peloton-state.json`

5. **`pf peloton stop` tears down all peloton panes**
   - Kills all panes with `peloton-` prefix
   - Removes peloton state file
   - Does NOT kill protected panes (claude, tui)

6. **`pf peloton status` shows pane state**
   - Lists all peloton panes with: role, pane_id, active/idle, agent started (yes/no)
   - Shows current workflow phase

---

## Technical Approach

### Reuse Existing Infrastructure

| Component | Existing Code | How Peloton Uses It |
|-----------|---------------|---------------------|
| Pane creation | `pf.tmux.panes.split_pane()` | Spawn panes at story start |
| Pane registry | `pf.tmux.registry` | Register peloton panes |
| Agent launching | `pf.saddle.core.start_agent()` pattern | Launch claude with agent prompt in pane |
| Workflow phases | `pf.workflow.cli` | Read phase list from workflow YAML |
| Team coordination | Claude's `TeamCreate`/`SendMessage` | Native — no custom coordination needed |
| Session file | `.session/{story-id}-session.md` | Already the coordination layer |

### State Management

```json
// .pennyfarthing/peloton-state.json
{
  "story_id": "148-9",
  "workflow": "tdd",
  "panes": {
    "tea": {"pane_id": "%10", "agent_started": false},
    "dev": {"pane_id": "%11", "agent_started": false},
    "reviewer": {"pane_id": "%12", "agent_started": true}
  },
  "active_role": "reviewer",
  "created_at": "2026-03-14T07:00:00Z"
}
```

### CLI Commands

```bash
pf peloton start                    # Spawn panes for current story's workflow
pf peloton next                     # Activate next phase agent in its pane
pf peloton switch <role>            # Jump to any pane
pf peloton status                   # Show pane states
pf peloton stop                     # Tear down all peloton panes
```

### Key Design Decisions

1. **Lazy activation** — panes are created empty at start, agents launched only when their phase is reached (or user switches to them). This avoids wasting resources starting agents that may not be needed.

2. **User is the conductor** — `pf peloton next` advances the workflow. No automatic phase advancement. The user decides when to move on.

3. **No custom coordination** — Claude's native team mode handles agent-to-agent communication. Peloton just provides the tmux infrastructure.

4. **Saddle pattern reuse** — agent launching follows saddle's proven `claude -p "$(pf agent start {role})"` pattern.

---

## Technical Guardrails

- **Python-only** (SOUL #9)
- **Return results** `{success, data?, error?}` — never throw
- **Use `pf tmux` commands** — never raw `tmux send-keys`
- **Protected panes** — never kill `claude` or `tui` panes
- **Reuse saddle's agent launch pattern** — don't reinvent
- **No polling** — user-driven advancement, not automated

## Key Files

| File | Action | Purpose |
|------|--------|---------|
| `pennyfarthing-dist/src/pf/peloton/live.py` | Create | Core peloton live mode logic |
| `pennyfarthing-dist/src/pf/peloton/cli.py` | Modify | Add start/next/switch/status/stop commands |
| `.pennyfarthing/peloton-state.json` | Managed | Runtime state tracking |

## Scope Boundaries

- **In scope:** Pane pre-spawning, agent activation, user switching, status, teardown
- **Out of scope:** Automatic phase advancement, replay/benchmarking (that's 148-8), modifying team mode itself, GUI integration
