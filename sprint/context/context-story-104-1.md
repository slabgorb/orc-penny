# Story 104-1: pf bc CLI command + /bc user skill

**Jira Key:** PROJ-14975
**Points:** 5
**Workflow:** tdd
**Status:** ready

---

## Story Title

Create a new `pf bc` Click CLI group in `pennyfarthing_scripts/bc/` with subcommands for each panel (sprint, git, diffs, todo, workflow, background, audit-log, changed, ac, debug, settings, tty) plus `reset`. Also create a `/bc` user skill in `pennyfarthing-dist/skills/bc/skill.md`. The CLI reads/writes a `focus` key in `.pennyfarthing/config.local.yaml`.

---

## Acceptance Criteria

1. **CLI group `pf bc` created and registered**
   - Location: `pennyfarthing_scripts/bc/cli.py`
   - Imported and registered in `pennyfarthing_scripts/cli.py` via `cli.add_command(bc)`
   - Group has 13 subcommands: `sprint`, `git`, `diffs`, `todo`, `workflow`, `background`, `audit-log`, `changed`, `ac`, `debug`, `settings`, `tty`, `reset`
   - Returns result objects `{success, data?, error?}` instead of throwing

2. **`pf bc [panel]` subcommands**
   - Each panel subcommand writes the panel name to `.pennyfarthing/config.local.yaml` under `focus` key
   - Updates only the `focus` key; preserves all other config keys (theme, display, layout, etc.)
   - Output: `{"success": true, "panel": "sprint"}` with exit code 0
   - On config write failure: `{"success": false, "error": "reason"}` with exit code 1
   - Validates panel name against allowed list before writing

3. **`pf bc reset` subcommand**
   - Removes the `focus` key from `.pennyfarthing/config.local.yaml`
   - Output: `{"success": true, "message": "focus cleared"}` with exit code 0
   - On failure: `{"success": false, "error": "reason"}` with exit code 1

4. **`/bc` user skill created**
   - Location: `pennyfarthing-dist/skills/bc/skill.md`
   - Metadata block: `name: bc`, `description`, `args: "[panel|reset]"`
   - Maps `/bc [panel]` → `pf bc [panel]` and `/bc reset` → `pf bc reset`
   - Validates panel name before routing
   - Displays result to user (success/error messages)

5. **Edge cases handled**
   - Invalid panel name: clear error message listing valid panels
   - Config file doesn't exist: create `.pennyfarthing/config.local.yaml` with header and focus key
   - Config file missing `.pennyfarthing/` directory: mkdir with parents
   - YAML parse error on existing config: report and fail gracefully
   - All writes use `yaml.dump()` with `default_flow_style=False, sort_keys=False`

---

## Valid Panel Names

```
sprint
git
diffs
todo
workflow
background
audit-log
changed
ac
debug
settings
tty
```

(Extracted from `.pennyfarthing/config.local.yaml` `layout.panels` keys and Cyclist panel list)

---

## Implementation Patterns

### CLI Group Structure

**Pattern from `pennyfarthing_scripts/theme/cli.py` and `pennyfarthing_scripts/bikerack/cli.py`:**

```python
"""BC CLI — Focus panel management.

Usage:
    pf bc [PANEL]
    pf bc reset
"""

from __future__ import annotations

import click

@click.group(invoke_without_command=True)
@click.pass_context
def bc(ctx):
    """Panel focus management.

    \b
    Commands:
      sprint      - Focus on Sprint panel
      git         - Focus on Git panel
      ...
      reset       - Clear focus setting
    """
    # Optional: default subcommand if needed
    if ctx.invoked_subcommand is None:
        ctx.invoke(help)  # or just pass


@bc.command("sprint")
def focus_sprint():
    """Focus on Sprint panel."""
    # Implementation


@bc.command("reset")
def reset_focus():
    """Clear focus setting."""
    # Implementation
```

### Config Management Pattern

**Pattern from `pennyfarthing_scripts/theme/cli.py` lines 176-199:**

```python
import yaml
from pathlib import Path
from pennyfarthing_scripts.common.config import get_project_root

root = get_project_root()
config_path = root / ".pennyfarthing" / "config.local.yaml"

# Read existing config
config: dict = {}
if config_path.exists():
    try:
        existing = yaml.safe_load(config_path.read_text())
        if existing and isinstance(existing, dict):
            config = existing
    except Exception:
        pass

# Update specific key
config["focus"] = panel_name

# Write with header
config_path.parent.mkdir(parents=True, exist_ok=True)
header = (
    "# Pennyfarthing Local Configuration\n"
    "# This file is gitignored - your personal preferences\n\n"
)
config_path.write_text(
    header + yaml.dump(config, default_flow_style=False, sort_keys=False)
)
```

### Return Result Objects

**Pattern from `pennyfarthing_scripts/bikerack/cli.py` lines 114-120:**

```python
def stop_bikerack(project_dir):
    # ... implementation ...
    return {"success": True, "message": "BikeRack stopped"}

# In CLI command:
result = stop_bikerack(project_dir)

if result["success"]:
    click.echo(result["message"])
else:
    click.echo(result["message"], err=True)
    sys.exit(1)
```

### CLI Registration Pattern

**Pattern from `pennyfarthing_scripts/cli.py` lines 68-71:**

```python
# Import and register bc group
from pennyfarthing_scripts.bc.cli import bc  # noqa: E402

cli.add_command(bc)
```

(Place after bikerack registration, before any inline @cli.group() definitions)

---

## Key Files to Create

### 1. `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing_scripts/bc/__init__.py`
Empty file or minimal module docstring.

### 2. `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing_scripts/bc/cli.py`
Main CLI implementation with:
- `@click.group()` bc function with invoke_without_command
- 12 panel subcommands (sprint, git, diffs, todo, workflow, background, audit-log, changed, ac, debug, settings, tty)
- 1 reset subcommand
- Each panel command calls shared function `set_panel_focus(panel_name)` or similar
- Result object returns with {success, data/message/error, exit code}

### 3. `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/skills/bc/skill.md`
Skill definition with:
- YAML frontmatter: name, description, args
- Routing documentation
- Command examples for each panel
- Result format documentation

---

## Key Files to Modify

### 1. `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing_scripts/cli.py`

**After line 71 (after bikerack registration), add:**

```python
# Import and register bc group
from pennyfarthing_scripts.bc.cli import bc  # noqa: E402

cli.add_command(bc)
```

---

## Implementation Notes

### Panel Name Validation

Use constant at top of `bc/cli.py`:

```python
VALID_PANELS = [
    "sprint",
    "git",
    "diffs",
    "todo",
    "workflow",
    "background",
    "audit-log",
    "changed",
    "ac",
    "debug",
    "settings",
    "tty",
]
```

Validate before writing config:

```python
if panel not in VALID_PANELS:
    return {
        "success": False,
        "error": f"Invalid panel '{panel}'. Valid panels: {', '.join(VALID_PANELS)}"
    }
```

### Config Write Logic

```python
def set_panel_focus(panel_name: str, project_dir: Path | None = None) -> dict:
    """Set focus panel in config.

    Args:
        panel_name: Panel name (sprint, git, etc.)
        project_dir: Override project root (optional)

    Returns:
        {success: bool, data?: str, error?: str}
    """
    try:
        root = project_dir or get_project_root()
        config_path = root / ".pennyfarthing" / "config.local.yaml"

        # Validate panel name
        if panel_name not in VALID_PANELS:
            return {"success": False, "error": f"Invalid panel: {panel_name}"}

        # Load existing config
        config: dict = {}
        if config_path.exists():
            try:
                existing = yaml.safe_load(config_path.read_text())
                if existing and isinstance(existing, dict):
                    config = existing
            except Exception as e:
                return {"success": False, "error": f"Failed to parse config: {e}"}

        # Update focus key
        config["focus"] = panel_name

        # Write with header
        config_path.parent.mkdir(parents=True, exist_ok=True)
        header = (
            "# Pennyfarthing Local Configuration\n"
            "# This file is gitignored - your personal preferences\n\n"
        )
        config_path.write_text(
            header + yaml.dump(config, default_flow_style=False, sort_keys=False)
        )

        return {"success": True, "data": panel_name}

    except Exception as e:
        return {"success": False, "error": str(e)}
```

### Reset Logic

```python
def clear_panel_focus(project_dir: Path | None = None) -> dict:
    """Clear focus setting from config.

    Returns:
        {success: bool, message?: str, error?: str}
    """
    try:
        root = project_dir or get_project_root()
        config_path = root / ".pennyfarthing" / "config.local.yaml"

        if not config_path.exists():
            return {"success": True, "message": "No focus setting to clear"}

        # Load and update config
        config: dict = {}
        try:
            existing = yaml.safe_load(config_path.read_text())
            if existing and isinstance(existing, dict):
                config = existing
        except Exception:
            pass

        # Remove focus key if present
        config.pop("focus", None)

        # Write back
        config_path.parent.mkdir(parents=True, exist_ok=True)
        header = (
            "# Pennyfarthing Local Configuration\n"
            "# This file is gitignored - your personal preferences\n\n"
        )
        config_path.write_text(
            header + yaml.dump(config, default_flow_style=False, sort_keys=False)
        )

        return {"success": True, "message": "focus cleared"}

    except Exception as e:
        return {"success": False, "error": str(e)}
```

### CLI Command Template

For each panel command:

```python
@bc.command("sprint")
def focus_sprint():
    """Focus on Sprint panel."""
    from pennyfarthing_scripts.bc.core import set_panel_focus

    result = set_panel_focus("sprint")
    if result["success"]:
        click.echo(f"Focus: {result['data']}")
    else:
        click.echo(f"Error: {result['error']}", err=True)
        sys.exit(1)
```

Or extract to separate module `bc/core.py` with shared functions.

---

## Testing Strategy

### Unit Tests

Test location: `tests/bc_cli_test.py` or similar

1. **set_panel_focus(panel)**
   - Valid panel names write correctly
   - Invalid panel returns error
   - Config file created if missing
   - Existing keys preserved on update
   - YAML formatting correct

2. **clear_panel_focus()**
   - Removes focus key
   - Preserves other keys
   - Returns success if already missing

3. **Config validation**
   - Parse error handling
   - Missing directory creation
   - Header preservation

### Integration Tests

1. **pf bc sprint** → config updated, exit 0
2. **pf bc invalid-panel** → error message, exit 1
3. **pf bc reset** → focus key removed, exit 0

---

## Related Files & Patterns

| File | Purpose | Pattern Used |
|------|---------|--------------|
| `pennyfarthing_scripts/theme/cli.py` | Config management pattern | Lines 176-199, 189-191 |
| `pennyfarthing_scripts/bikerack/cli.py` | CLI group structure + result objects | Lines 19-31, 114-120 |
| `pennyfarthing_scripts/common/config.py` | Project root detection | `get_project_root()` |
| `pennyfarthing_scripts/cli.py` | CLI registration | Lines 34-71 |
| `.pennyfarthing/config.local.yaml` | Config file structure | Lines 1-151 of actual config |
| `pennyfarthing-dist/skills/sprint/skill.md` | Skill documentation format | Full file reference |
| `pennyfarthing-dist/skills/theme/skill.md` | Config-writing skill pattern | Full file reference |

---

## Edge Cases & Error Handling

| Scenario | Expected Behavior | Exit Code |
|----------|-------------------|-----------|
| Invalid panel name | Error message listing valid panels | 1 |
| Config file corrupted | Error: "Failed to parse config" | 1 |
| `.pennyfarthing/` directory missing | Auto-create with mkdir parents=True | 0 |
| Config file missing | Create with header + focus key | 0 |
| Read-only filesystem | Error: "Permission denied" | 1 |
| reset when focus not set | Success: "No focus setting to clear" | 0 |

---

## Skill Implementation Notes

The `/bc` skill will map user input to CLI commands:

- `/bc` or `/bc status` → Show current focus (read config, display)
- `/bc [panel]` → `pf bc [panel]` and display result
- `/bc reset` → `pf bc reset` and display result
- `/bc invalid` → Error: invalid panel name (list valid options)

Skill should validate panel names before calling CLI to provide fast user feedback.

---

## Config File Example

After `pf bc sprint`:

```yaml
# Pennyfarthing Local Configuration
# This file is gitignored - your personal preferences

theme: the-expanse
focus: sprint
workflow:
  permission_mode: accept
  bell_mode: true
  relay_mode: true
pennyfarthing: {}
display:
  colorPreset: tokyo-night
  # ... rest of config preserved
```

After `pf bc reset`:

```yaml
# Pennyfarthing Local Configuration
# This file is gitignored - your personal preferences

theme: the-expanse
workflow:
  permission_mode: accept
  bell_mode: true
  relay_mode: true
pennyfarthing: {}
display:
  colorPreset: tokyo-night
  # ... rest of config preserved
```

(No `focus` key)

---

## Success Criteria Checklist

- [ ] `pennyfarthing_scripts/bc/cli.py` created with all 13 subcommands
- [ ] `pennyfarthing_scripts/bc/__init__.py` exists
- [ ] `pennyfarthing_scripts/cli.py` updated with bc registration
- [ ] `pennyfarthing-dist/skills/bc/skill.md` created
- [ ] Config writes preserve existing keys (theme, display, layout, etc.)
- [ ] Invalid panel names rejected with helpful error
- [ ] `reset` removes focus key completely
- [ ] All CLI commands return result objects {success, data?, error?}
- [ ] Exit codes: 0 for success, 1 for error
- [ ] Config file header preserved
- [ ] YAML formatting: default_flow_style=False, sort_keys=False
- [ ] Tests pass for all edge cases
