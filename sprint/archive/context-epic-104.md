# Epic 104: /bc CLI Panel Focus

**Jira:** PROJ-14952
**Repo:** pennyfarthing
**PRD:** `sprint/planning/bikerack-prd.md` (Growth Feature, Idea A)

## Overview

CLI-driven panel focus for BikeShow. User types `/bc {panel}` which runs `pf bc {panel}`, writing a `focus` key to `config.local.yaml`. WheelHub watches the file and broadcasts `panel:focus` over WebSocket. BikeShow client stashes the current layout and renders the requested panel fullscreen. `/bc reset` restores the saved layout. No stash stack — successive `/bc` calls preserve the original saved state.

## Stories

| ID | Title | Pts | Priority | Workflow |
|----|-------|-----|----------|----------|
| 104-1 | pf bc CLI command + /bc user skill | 2 | P1 | tdd |
| 104-2 | WheelHub config file watch + panel focus broadcast | 2 | P1 | tdd |
| 104-3 | BikeShow client layout stash/restore on panel focus | 3 | P1 | tdd |

## Architecture

```
CLI Layer (104-1)                Server Layer (104-2)              Client Layer (104-3)
─────────────────                ───────────────────               ──────────────────
/bc sprint                       config.local.yaml watcher         useFocusPanel hook
  │                                │                                 │
  ▼                                ▼                                 ▼
pf bc sprint                     Detect focus key change           Receive panel:focus event
  │                                │                                 │
  ▼                                ▼                                 ├─ panelId != null:
Write focus: "sprint"            broadcastFocusUpdate()            │   stash layout (once)
to config.local.yaml               │                              │   show single panel
                                   ▼                                 │
                                 /ws/focus WebSocket               ├─ panelId == null:
                                 → { type: 'update',              │   restore stashed layout
                                     focus: 'sprint' }
```

## Story 104-1: pf bc CLI Command + /bc User Skill

### CLI Pattern (follow existing)

**Registration:** `pennyfarthing_scripts/cli.py` — lazy import + `cli.add_command(bc)`

Existing pattern (line 68-71):
```python
from pennyfarthing_scripts.bikerack.cli import bikerack  # noqa: E402
cli.add_command(bikerack)
```

**Group structure:** `pennyfarthing_scripts/bc/cli.py` — Click group with panel subcommands

Model after `bikerack/cli.py` (simple group) and `theme/cli.py` (config manipulation).

### Config File

**Path:** `.pennyfarthing/config.local.yaml`

Current structure has top-level keys: `theme`, `workflow`, `pennyfarthing`, `display`, `notifications`, `layout`, `theme_characters`. Add `focus` as a new top-level key.

```yaml
focus: null          # no focus (normal layout)
focus: sprint        # focused on sprint panel
focus: git           # focused on git panel
```

**Config utilities:** `pennyfarthing_scripts/common/config.py`
- `get_project_root()` — finds project root
- `load_yaml_config(path)` — reads YAML safely
- No generic `save_config` exists — write one in `bc/focus.py` or use direct YAML write

### Valid Panel Names

From `BikeRackWorkspace.tsx` (line 33-45):
```
sprint, git, diffs, todo, workflow, background, audit-log, changed, ac, debug, settings
```

Also from `DockviewWorkspace.tsx` PANEL_INVENTORY: `tty` is available in full Cyclist.

### Skill Structure

**Path:** `pennyfarthing-dist/skills/bc/skill.md`

Model after existing skills: `pennyfarthing-dist/skills/cyclist/SKILL.md`, `pennyfarthing-dist/skills/sprint/skill.md`

Maps `/bc <arg>` → `pf bc <arg>`.

### Files to Create

| File | Purpose |
|------|---------|
| `pennyfarthing_scripts/bc/__init__.py` | Package init |
| `pennyfarthing_scripts/bc/cli.py` | Click group: `bc` with subcommands per panel + `reset` |
| `pennyfarthing_scripts/bc/focus.py` | Implementation: read/write `focus` in config.local.yaml |
| `pennyfarthing-dist/skills/bc/skill.md` | User skill mapping `/bc` → `pf bc` |

### Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing_scripts/cli.py` | Add `from pennyfarthing_scripts.bc.cli import bc` + `cli.add_command(bc)` |

---

## Story 104-2: WheelHub Config File Watch + Panel Focus Broadcast

### WebSocket Pattern (follow existing)

**File:** `packages/cyclist/src/websocket.ts`

Each WebSocket channel follows the same pattern:

1. **Client set:** `const focusClients = new Set<WebSocket>()` (line ~149 area)
2. **WSS instance:** `const focusWss = new WebSocketServer({ noServer: true })` (line ~385 area)
3. **Upgrade route:** `else if (pathname === '/ws/focus') { focusWss.handleUpgrade(...) }` (line ~490 area)
4. **Connection handler:** Send initial state on connect, register client, clean up on close (line ~752 area)
5. **Broadcast function:** `export function broadcastFocusUpdate(focus: string | null)` (line ~1595 area)

### Config File Watcher (extend existing)

The settings watcher at line 1172-1197 already watches `.pennyfarthing/config.local.yaml`. Two options:

**Option A (recommended): Extend existing watcher** — the settings watcher already fires on config.local.yaml changes. Add focus detection inside the same debounce callback:

```typescript
settingsDebounceTimer = setTimeout(async () => {
  try {
    const settings = await getSettingsForWebSocket(projectDir);
    broadcastSettingsUpdate(settings);
    // NEW: Also check for focus changes
    const focus = getConfigFocus(projectDir);
    broadcastFocusUpdate(focus);
  } catch (err) { ... }
}, SETTINGS_DEBOUNCE_MS);
```

**Option B: Separate focus-specific watcher** — unnecessary since config.local.yaml is already watched.

### Config Reading (server-side)

**Model:** `src/api/settings.ts` → `getSettingsForWebSocket()`

Create a simple focus reader:
```typescript
// In websocket.ts or a small helper
function getConfigFocus(projectDir: string): string | null {
  const configPath = join(projectDir, '.pennyfarthing', 'config.local.yaml');
  // Read and parse YAML, return config.focus || null
}
```

The server already imports `yaml` parsing via the settings API. Follow that pattern.

### Key Constraint

The focus broadcast should only fire when the `focus` value actually changes, not on every config write. Track `lastKnownFocus` to avoid spurious broadcasts.

### Files to Modify

| File | Change |
|------|--------|
| `packages/cyclist/src/websocket.ts` | Add `focusClients` set, `focusWss` WSS, `/ws/focus` upgrade route, connection handler, `broadcastFocusUpdate()`, extend config watcher |

---

## Story 104-3: BikeShow Client Layout Stash/Restore

### Dockview Layout API

**Serialize:** `api.toJSON(): SerializedDockview` — captures complete layout state
**Restore:** `api.fromJSON(layout: SerializedDockview)` — restores from serialized state

Both are used extensively in `DockviewWorkspace.tsx`:
- `fromJSON` at line 431 (initial layout restore)
- `toJSON` at line 536 (layout persistence on change)

Layout persistence hook: `useLayoutPersistence.ts` — saves to config.local.yaml via REST API.

### WebSocket Hook Pattern

**Model:** `src/public/hooks/useSprint.ts` — cleanest WebSocket hook example

Pattern:
1. Connect to `ws://{host}/ws/focus`
2. Receive `{ type: 'init', focus: string | null }` on connect
3. Receive `{ type: 'update', focus: string | null }` on changes
4. Call provided callback with new focus value
5. Auto-reconnect on disconnect (5s delay, like useSprint)

### Integration Target

**BikeRack mode:** `BikeRackWorkspace.tsx` — simple single-group layout, no sacred center
**Full Cyclist:** `DockviewWorkspace.tsx` — three-region layout with sacred message center

The focus feature primarily targets BikeRack (dashboard mode), but should also work in full Cyclist for consistency.

### Stash/Restore Logic

**Key constraint from PRD:** No stash stack. Single slot.

```
State machine:
  NORMAL → (focus event with panelId) → FOCUSED
    Action: Save current layout to stash (only if stash is empty)
    Action: Render single panel fullscreen

  FOCUSED → (focus event with different panelId) → FOCUSED
    Action: Do NOT re-stash (preserve original layout)
    Action: Render new panel fullscreen

  FOCUSED → (focus event with null / reset) → NORMAL
    Action: Restore layout from stash
    Action: Clear stash
```

### BikeRackWorkspace Changes

Current component (142 lines) has a simple `onReady` that adds all panels as tabs in one group. Changes needed:

1. Add `useFocusPanel` hook
2. Add state: `savedLayout: SerializedDockview | null`
3. On focus: stash `apiRef.current.toJSON()` (if not already stashed), then rebuild with single panel
4. On reset: `apiRef.current.fromJSON(savedLayout)`, clear stash

### DockviewWorkspace Changes

More complex — three-region layout with sacred center. Focus mode must:
1. Hide all groups except the one containing the target panel
2. Or: use `fromJSON` with a single-panel layout (simpler)
3. Reset: restore from stash via `fromJSON`

**Important:** The message panel (sacred center) should be hidden during focus mode. The whole point is single-panel fullscreen.

### Files to Create

| File | Purpose |
|------|---------|
| `packages/cyclist/src/public/hooks/useFocusPanel.ts` | WebSocket hook for `/ws/focus` events |

### Files to Modify

| File | Change |
|------|--------|
| `packages/cyclist/src/public/components/BikeRackWorkspace.tsx` | Integrate focus hook, stash/restore logic |
| `packages/cyclist/src/public/components/DockviewWorkspace.tsx` | Same focus integration for full Cyclist mode |

---

## Valid Panel IDs

| Panel ID | Title | In BikeRack | In Cyclist |
|----------|-------|-------------|------------|
| `sprint` | Sprint | yes | yes |
| `git` | Git | yes | yes |
| `diffs` | Diffs | yes | yes |
| `todo` | Todo | yes | yes |
| `workflow` | Workflow | yes | yes |
| `background` | Subagents | yes | yes |
| `audit-log` | Audit Log | yes | yes |
| `changed` | Changed | yes | yes |
| `ac` | AC | yes | yes |
| `debug` | Debug | yes | yes |
| `settings` | Settings | yes | yes |
| `tty` | Terminal | no | yes |
| `message` | Message | no | yes (sacred) |

`/bc` should accept all panel IDs except `message` (sacred center, not meaningful to "focus" on since it's always visible in Cyclist).

## Dependencies

- **No blockers.** This epic is self-contained.
- **Requires:** BikeRack MVP (epic 101) — already complete.
- **Related:** BikeRack follow-up (epic 102) — dockview layout already landed.

## Constraints

- **No stash stack** — `/bc reset` always restores the original saved state
- **File-based communication** — CLI writes config, server watches, no direct IPC
- **Existing watcher reuse** — config.local.yaml watcher already exists for settings; extend it
- **Layout persistence** — focus mode should NOT overwrite the persisted layout in config.local.yaml
