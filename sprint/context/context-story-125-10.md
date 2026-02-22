# Context: Story 125-10 — Add pf sprint focus commands (use/close/status)

**Jira Issue:** MSSCI-15431
**Points:** 2
**Priority:** P3
**Epic:** 125 — Sprint State Engine Consolidation (MSSCI-15421)
**Workflow:** trivial

## Problem

Sprint context (focus) management is currently manual and opaque to users. The `pf sprint use` command exists and switches the active sprint via a preference stored in `.pennyfarthing/config.local.yaml`, but there is no way to:

1. **Close or complete a focus context** — once a sprint is focused, there's no CLI command to mark it as completed
2. **Query focus status** — users can't check what sprint is currently active without reading the config file directly
3. **Manage focus lifecycle** — focus contexts lack structure for lifecycle tracking (creation, usage, completion)

Currently, focus switching requires manual editing of `.pennyfarthing/config.local.yaml` or remembering the `pf sprint use NAME` command. After story 125-9 adds lifecycle fields (status, participants, start_date, etc.) to the sprint schema, this story adds the CLI layer to operationalize those fields.

## Architecture

### Current Flow (Sprint Switching Only)

```
User: pf sprint use main
  → CLI: sprint.use() command [cli.py:127]
    → loader.switch_sprint(name) [loader.py:121]
      → validate name against sprint/sprints.yaml
      → load .pennyfarthing/config.local.yaml
      → set config['sprint']['active'] = name
      → save config back to disk
    → CLI returns message + sprint metadata
```

### Current Config Structure

In `.pennyfarthing/config.local.yaml`:

```yaml
sprint:
  active: main  # Per-user preference for which sprint to use

focus: sprint   # Panel focus (unrelated — managed by pf bc)
```

### Post-125-9 Schema (for context)

Story 125-9 extends the sprint/sprints.yaml schema with lifecycle fields:

```yaml
sprints:
  main:
    name: Main Project Sprint
    description: ...
    type: project
    repos: [pennyfarthing]
    status: active          # NEW: lifecycle status
    participants: [...]     # NEW: who's in this sprint
    start_date: 2026-02-01  # NEW: when started
```

### Key Files

| File | Role | Current |
|------|------|---------|
| `pennyfarthing-dist/pf/sprint/cli.py` | Sprint CLI commands | `use`, `list`, `active` commands already defined |
| `pennyfarthing-dist/pf/sprint/loader.py` | Sprint loading and switching | `switch_sprint()`, `get_active_sprint_name()` functions |
| `pennyfarthing-dist/pf/common/config.py` | Config file I/O | `load_pennyfarthing_config()`, `save_pennyfarthing_config()` |
| `.pennyfarthing/config.local.yaml` | Per-user sprint preference | Stores `sprint.active` key |

### Existing `pf sprint use` Implementation

The `sprint_use()` command (lines 127–161 in cli.py) already does:

```python
@sprint.command("use")
@click.argument("name")
def sprint_use(name: str):
    """Switch the active sprint (per-user preference)."""
    from pf.sprint.loader import switch_sprint

    result = switch_sprint(name)
    if result["success"]:
        entry = result.get("sprint", {})
        click.echo(result["message"])
        # Display metadata...
    else:
        raise click.ClickException(result["error"])
```

The `switch_sprint()` function in loader.py (lines 121–149):
- Validates sprint name against sprint/sprints.yaml
- Loads the registry if present
- Sets `config['sprint']['active'] = name` or clears it with `name="default"`
- Saves back to config.local.yaml
- Returns `{success, message, sprint, error?}`

## Acceptance Criteria

### AC1: pf sprint focus use NAME switches active sprint context
- **Given** sprint registry has an entry for "main"
- **When** user runs `pf sprint focus use main`
- **Then** the command succeeds
- **And** `.pennyfarthing/config.local.yaml` has `sprint.active: main`
- **And** user sees a confirmation message with sprint metadata
- **And** subsequent `pf sprint focus status` returns "main"

### AC2: pf sprint focus close NAME marks focus as completed
- **Given** user has switched to a sprint with `pf sprint focus use NAME`
- **When** user runs `pf sprint focus close NAME`
- **Then** the command marks the sprint focus as completed/closed
- **And** `.pennyfarthing/config.local.yaml` stores the close timestamp
- **And** the sprint preference is cleared (reverts to default)
- **And** subsequent `pf sprint focus status` shows "no active focus" or lists recently closed sprints

### AC3: pf sprint focus status shows current focus and all active contexts
- **Given** a sprint is currently focused via `pf sprint focus use NAME`
- **When** user runs `pf sprint focus status`
- **Then** output shows:
  - Current active sprint name
  - Sprint metadata (description, type, participants, etc.)
  - Start date and duration
  - Number of active stories in the sprint
  - List of recently closed sprints (from history)

### AC4: pf sprint focus commands work without registry
- **Given** the project has no sprint/sprints.yaml registry
- **When** user runs `pf sprint focus use`, `pf sprint focus close`, or `pf sprint focus status`
- **Then** each command either:
  - Returns an appropriate error message explaining that a registry is needed, OR
  - Falls back gracefully to working with sprint/current-sprint.yaml only

## Implementation Notes

### Step 1: Add focus lifecycle fields to config schema

Update `load_pennyfarthing_config()` and related functions in `pf/common/config.py` to handle:

```yaml
sprint:
  active: main                    # Currently active sprint
  focus_history:                  # NEW: Track closed sprints
    - name: secondary
      closed_at: 2026-02-15T10:30:00Z
      days_active: 8
```

Or store in a separate `focus` key to avoid conflicts with panel focus management (which already uses `focus: sprint_panel_name`).

### Step 2: Add `pf sprint focus use` command (alias/refactor of `pf sprint use`)

In `sprint/cli.py`, either:

**Option A (Recommended):** Refactor existing `pf sprint use` under a new `focus` subgroup:

```python
@sprint.group()
def focus():
    """Focus context management (use, close, status)."""
    pass

@focus.command("use")
@click.argument("name")
def focus_use(name: str):
    """Switch active sprint focus..."""
    # Reuse switch_sprint() from loader.py
```

**Option B:** Keep `pf sprint use` and add `pf sprint focus use` as an alias.

Recommendation: Option A for clarity and consistency with the `pf bc` panel focus commands.

### Step 3: Add `pf sprint focus close` command

In `sprint/focus.py` (new file), implement:

```python
def close_focus(sprint_name: str, project_root: Path | None = None) -> dict[str, Any]:
    """Mark a sprint focus as completed and add to history.

    Returns {success, message, closed_at?, error?}
    """
    root = project_root or get_project_root()
    config = load_pennyfarthing_config(root)

    # Get current active sprint
    current_active = config.get("sprint", {}).get("active")
    if current_active != sprint_name:
        return {"success": False, "error": f"Sprint '{sprint_name}' is not currently active"}

    # Add to history
    focus_history = config.get("sprint", {}).get("focus_history", [])
    start_date = config.get("sprint", {}).get("focus_start_date")  # Set when switched
    closed_at = datetime.now().isoformat()

    history_entry = {
        "name": sprint_name,
        "closed_at": closed_at,
        "days_active": calculate_days_since(start_date),
    }
    focus_history.append(history_entry)

    # Clear active and set history
    config["sprint"]["active"] = None
    config["sprint"]["focus_history"] = focus_history
    save_pennyfarthing_config(root, config)

    return {"success": True, "message": f"Closed focus '{sprint_name}'", "closed_at": closed_at}
```

### Step 4: Add `pf sprint focus status` command

In `sprint/focus.py`, implement:

```python
def get_focus_status(project_root: Path | None = None) -> dict[str, Any]:
    """Get current focus and history.

    Returns {success, current?, history?, error?}
    """
    root = project_root or get_project_root()
    config = load_pennyfarthing_config(root)

    current = config.get("sprint", {}).get("active")
    history = config.get("sprint", {}).get("focus_history", [])

    result = {"success": True}

    if current:
        registry = load_sprint_registry(root)
        sprint_meta = registry.get("sprints", {}).get(current, {})
        result["current"] = {
            "name": current,
            "start_date": config.get("sprint", {}).get("focus_start_date"),
            "metadata": sprint_meta,
        }
    else:
        result["current"] = None

    result["history"] = history[:10]  # Last 10 closed sprints
    return result
```

### Step 5: Wire up CLI commands

In `sprint/cli.py`, add the focus subgroup:

```python
@sprint.group()
def focus():
    """Focus context management."""
    pass

@focus.command("use")
@click.argument("name")
def focus_use(name: str):
    """Switch active sprint focus."""
    from pf.sprint.focus import use_focus
    result = use_focus(name)
    # Handle output

@focus.command("close")
@click.argument("name")
def focus_close(name: str):
    """Mark sprint focus as completed."""
    from pf.sprint.focus import close_focus
    result = close_focus(name)
    # Handle output

@focus.command("status")
def focus_status():
    """Show current focus and history."""
    from pf.sprint.focus import get_focus_status
    result = get_focus_status()
    # Format and display
```

### Step 6: Update `pf sprint use` / `pf sprint active` for backward compat

Keep existing `pf sprint use` working (don't break backward compatibility), but consider deprecating in favor of `pf sprint focus use`.

### Testing Strategy

1. **Unit tests** (`test_sprint_focus.py`):
   - `test_focus_use_valid_sprint()` — switch to registered sprint
   - `test_focus_use_unregistered()` — error handling
   - `test_focus_close_with_history()` — track closed sprints
   - `test_focus_status_empty()` — no active focus
   - `test_focus_status_with_history()` — display recent closes

2. **Integration tests**:
   - Run full workflow: `use` → `status` → `close` → `status`
   - Verify config file updates
   - Test without registry (fallback behavior)

3. **Manual testing**:
   - `pf sprint focus use main && pf sprint focus status`
   - `pf sprint focus close main && pf sprint focus status`
   - Verify `.pennyfarthing/config.local.yaml` changes

## Dependency Notes

- **Depends on 125-9:** Sprint schema with lifecycle fields (status, participants, start_date)
- **Extends 125-1:** SprintContext consolidation (uses loader.py infrastructure)
- **Related to 104-1/104-4:** Panel focus management (pf bc), different config key but similar pattern

## Out of Scope

- Jira integration for closing sprints
- UI integration for focus status display (that's a separate story)
- Historical analytics on focus duration
- Multi-user focus tracking (per-user config only)
