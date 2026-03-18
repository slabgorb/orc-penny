# Epic 147: Configuration Gap Closure

## Overview

Close the gaps between Pennyfarthing's configuration system and the BikeRack TUI settings panel. The audit identified two configuration files serving different purposes — `config.local.yaml` (user preferences) and `repos.yaml` (project topology) — with the TUI covering 15/17 preference settings but zero topology settings.

## Architecture

**Two panels, two files:**

| Panel | File | Purpose |
|-------|------|---------|
| Settings (existing) | `config.local.yaml` | User preferences — theme, permissions, workflow modes |
| Repos (new) | `repos.yaml` | Project topology — repos, build commands, PR strategy |

These remain separate files. The Settings panel gets quick-win additions (Jira, saddle, colorPreset). The Repos panel is a new BikeRack panel for repos.yaml visibility and editing.

## Key Files

### Settings System (existing)
- `pennyfarthing-dist/src/pf/settings/settings.py` — DEFAULTS dict, get/set with dot-path, coercion
- `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` — SettingSpec registry, _SPECS list, build_setting_specs()
- `pennyfarthing-dist/src/pf/bikerack/settings_panel.py` — Textual SettingsPanel widget
- `pennyfarthing-dist/src/pf/wheelhub/routes/state.py` — /api/settings/ endpoints

### Repos System (existing)
- `pennyfarthing-dist/src/pf/git/repos.py` — RepoConfig dataclass, load_repos_config(), load_repos_yaml_raw()
- `.pennyfarthing/repos.yaml` — project topology file

### Repos System (new, created by this epic)
- `pennyfarthing-dist/src/pf/bikerack/repos_meta.py` — RepoFieldSpec registry (147-4)
- `pennyfarthing-dist/src/pf/bikerack/repos_panel.py` — Textual ReposPanel widget (147-5)

### Jira System (existing, referenced)
- `pennyfarthing-dist/src/pf/jira/client.py` — _resolve_jira_config() reads config.local.yaml → jira.project, jira.url

## Planning Documents

- Configuration Audit Report (in-conversation, 2026-03-13) — full gap analysis
- ADR-0034: Python-first architecture

## Patterns

### SettingSpec Pattern (reuse for all Track 1 stories)

```python
SettingSpec(
    key="dot.path.key",
    label="Human Label",
    widget_type="switch" | "select" | "input",
    group="Group Name",
    options=[("Label", "value"), ...],  # for select only
    options_factory=callable,            # for dynamic options
    description="Short description",
    hidden=False,
)
```

Add to `_SPECS` list in `settings_meta.py`. The `build_setting_specs()` function auto-discovers from DEFAULTS and uses explicit specs when available. Widget IDs are derived from keys via `_key_to_id()`.

### RepoFieldSpec Pattern (new, for Track 2 stories)

Mirror SettingSpec but scoped to per-repo fields:

```python
@dataclass
class RepoFieldSpec:
    field: str           # RepoConfig field name
    label: str
    widget_type: str     # "switch" | "select" | "input" | "readonly"
    group: str           # "General" | "Build" | "PR" | "Quality" | "Topology"
    options: list[tuple[str, Any]] | None = None
    description: str = ""
    read_only: bool = False
```

### Save Mechanism

- **Settings:** `set_setting(key, value)` or `set_setting_typed(key, value)` — writes config.local.yaml
- **Repos:** New `set_repo_field(repo_name, field, value)` — writes repos.yaml (147-6)

## Dependency Graph

```
Track 1 (independent, can parallelize):
  147-1 (Jira DEFAULTS)     — standalone
  147-2 (saddle_mode spec)   — standalone
  147-3 (colorPreset)        — standalone

Track 2 (sequential):
  147-6 (set_repo_field)     — no UI dependency, can start early
  147-4 (repos_meta.py)      — defines field specs
  147-5 (repos_panel.py)     — depends on 147-4 and 147-6
  147-7 (WheelHub API)       — depends on 147-6

Track 3:
  147-8 (validators)         — depends on 147-6, independent of Track 1
```

---

## Story Details

### 147-1: Add Jira config to DEFAULTS and TUI settings panel (1pt, trivial)

**Problem:** `jira.project` and `jira.url` are loaded by `jira/client.py` from config.local.yaml but aren't in DEFAULTS, so they're invisible to the settings panel and `pf settings show`.

**AC:**
1. DEFAULTS in settings.py includes `"jira": {"project": "MSSCI", "url": "https://1898andco.atlassian.net"}`
2. SHOW_KEYS in settings.py already includes "jira" — verify it works
3. Two explicit SettingSpecs added to settings_meta.py: `jira.project` (input, Integration group) and `jira.url` (input, Integration group)
4. `pf settings show` displays jira.project and jira.url with (default) annotation
5. BikeRack settings panel shows Integration group with both fields
6. Existing `jira/client.py` _resolve_jira_config() continues to work (no changes needed)

**Key files to modify:**
- `pennyfarthing-dist/src/pf/settings/settings.py` — add jira to DEFAULTS
- `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` — add 2 SettingSpecs

**Key files to reference:**
- `pennyfarthing-dist/src/pf/jira/client.py` — _resolve_jira_config() at line 19

---

### 147-2: Promote saddle_mode to explicit SettingSpec (1pt, trivial)

**Problem:** `workflow.saddle_mode` exists in DEFAULTS but has no explicit SettingSpec. It's auto-inferred with a generated label ("Saddle Mode") and no description. Should have a curated spec like all other workflow settings.

**AC:**
1. Explicit SettingSpec added to _SPECS list for `workflow.saddle_mode`
2. Label: "Saddle Mode", group: "Workflow", widget: switch
3. Description: "Background observer tandem pairing"
4. Setting renders in Workflow group alongside other workflow settings (not auto-inferred position)

**Key files to modify:**
- `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` — add SettingSpec to _SPECS

---

### 147-3: Unhide colorPreset with Select widget (1pt, trivial)

**Problem:** `display.colorPreset` exists in DEFAULTS and has a SettingSpec but is marked `hidden=True` and listed in HIDDEN_KEYS. Users must use CLI or manual edit.

**AC:**
1. SettingSpec for `display.colorPreset` changed from input to select widget
2. `hidden=False` on the spec
3. `display.colorPreset` removed from HIDDEN_KEYS set
4. Options list includes at least the current value ("Catppuccin", "catppuccin")
5. Setting appears in Display group in the settings panel

**Note:** If only one color preset is implemented, this story may be deferred. Check BikeRack CSS for available presets before implementing.

**Key files to modify:**
- `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` — update SettingSpec, remove from HIDDEN_KEYS

---

### 147-4: Create RepoFieldSpec registry in repos_meta.py (2pts, tdd)

**Problem:** repos.yaml has 22+ configurable fields per repo with zero TUI representation. Need a metadata registry (like settings_meta.py for settings) that describes which repo fields to expose and how to render them.

**AC:**
1. New file `pennyfarthing-dist/src/pf/bikerack/repos_meta.py` created
2. `RepoFieldSpec` dataclass defined with: field, label, widget_type, group, options, description, read_only
3. `REPO_FIELDS_META` dict maps field names to RepoFieldSpec instances
4. `build_repo_field_specs()` function returns ordered list of specs
5. At minimum these fields have explicit specs:

| Group | Field | Widget | Read-Only |
|-------|-------|--------|-----------|
| General | description | input | No |
| General | type | select (orchestrator/framework/api/ui/cli/library) | Yes |
| General | branch_strategy | select (trunk-based/gitflow) | No |
| General | default_branch | input | No |
| Build | test_command | input | No |
| Build | build_command | input | No |
| Build | lint_command | input | No |
| Build | test_filter_flag | input | No |
| PR | pr_strategy | select (standard/stacked) | No |
| PR | stack_tool | input | No |
| Quality | simplify | switch | No |
| Topology | owns | readonly | Yes |
| Topology | never_edit | readonly | Yes |
| Topology | symlinks | readonly | Yes |

6. `GLOBAL_REPO_FIELDS` list for top-level repos.yaml fields (pr_title_format, build_order)

**Key files to reference:**
- `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` — pattern to follow
- `pennyfarthing-dist/src/pf/git/repos.py` — RepoConfig dataclass (field names, types, defaults)

---

### 147-5: Create ReposPanel with per-repo collapsible sections (3pts, tdd)

**Problem:** No TUI panel for viewing or editing repos.yaml. Need a panel that renders per-repo settings with collapsible sections, using the RepoFieldSpec registry from 147-4.

**AC:**
1. New file `pennyfarthing-dist/src/pf/bikerack/repos_panel.py` created
2. ReposPanel widget extends textual.widget.Widget
3. Panel renders one Collapsible section per repo (from repos.yaml)
4. Within each repo section, fields grouped by RepoFieldSpec group (General, Build, PR, Quality, Topology)
5. Editable fields (switch, select, input) save to repos.yaml via set_repo_field()
6. Read-only fields (topology) display as Label widgets showing the current value
7. Global settings section at top ("Project") for pr_title_format
8. Status bar at bottom for save feedback (green "Saved" / red "Error")
9. Panel registered in BikeRack with `pf bc repos` command
10. REPOS_CSS defined with appropriate styling (mirror SettingsPanel pattern)
11. SettingChanged-like message posted on changes for app reactivity

**Dependencies:** 147-4 (repos_meta.py), 147-6 (set_repo_field)

**Key files to reference:**
- `pennyfarthing-dist/src/pf/bikerack/settings_panel.py` — widget pattern to follow exactly
- `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` — spec pattern

**Key files to modify:**
- `pennyfarthing-dist/src/pf/bikerack/repos_panel.py` — new file
- `pennyfarthing-dist/src/pf/bc/cli.py` — register "repos" panel
- BikeRack app registration (wherever panels are composed)

---

### 147-6: Add set_repo_field writer to git/repos.py (2pts, tdd)

**Problem:** `git/repos.py` has comprehensive read functions but no write capability. The ReposPanel needs to persist field changes back to repos.yaml.

**AC:**
1. `set_repo_field(repo_name: str, field: str, value: Any) -> dict` added to repos.py
2. Function loads raw YAML, updates the field, writes back
3. YAML write preserves key order (sort_keys=False)
4. Returns `{success: True, data: updated_config}` or `{success: False, error: message}`
5. Validates repo_name exists in repos dict (returns error if not)
6. Validates field is a known RepoConfig field (returns error if not)
7. `set_global_repo_field(field: str, value: Any) -> dict` for top-level fields (pr_title_format)
8. Round-trip test: load → set → load verifies value persisted correctly

**Key files to modify:**
- `pennyfarthing-dist/src/pf/git/repos.py` — add set_repo_field(), set_global_repo_field()

---

### 147-7: Add repos API endpoints to WheelHub (1pt, trivial)

**Problem:** WheelHub serves config.local.yaml at /api/settings/ but has no endpoints for repos.yaml. The React GUI cannot read or modify repository topology.

**AC:**
1. `repos_router` created with prefix `/api/repos`
2. `GET /api/repos/` — returns all repo configs (using load_repos_config)
3. `PATCH /api/repos/{repo_name}` — updates fields on a repo entry (using set_repo_field)
4. `GET /api/repos/pr-title-format` — returns global PR title format
5. Router registered in all_state_routers list
6. Error responses follow existing pattern (JSONResponse with error key)

**Dependencies:** 147-6 (set_repo_field)

**Key files to modify:**
- `pennyfarthing-dist/src/pf/wheelhub/routes/state.py` — add repos_router
- `pennyfarthing-dist/src/pf/wheelhub/app.py` — register router (if not auto-included via all_state_routers)

---

### 147-8: Add write-time validators to settings and repo writers (2pts, tdd)

**Problem:** Neither config.local.yaml nor repos.yaml has write-time validation. Invalid values (wrong enum, wrong type) can be written via CLI or manual edit with no feedback until runtime failure.

**AC:**
1. `VALIDATORS` dict added to settings.py mapping dot-paths to validation callables
2. `set_setting()` and `set_setting_typed()` check VALIDATORS before writing
3. Invalid values raise `ValueError` with descriptive message
4. At minimum these validators exist:
   - `permission_mode` — must be in (standard, accept, strict)
   - `workflow.permission_mode` — must be in (standard, accept, strict)
   - `workflow.pr_mode` — must be in (draft, ready)
   - `workflow.pr_merge` — must be in (auto, manual)
   - `workflow.startup_agent` — must be in valid agent list
   - `portrait_size` — must be in (auto, large, medium, small, off)
   - `portrait_position` — must be in (left, right)
   - `portrait_dock` — must be in (top, bottom)
5. `set_repo_field()` validates by round-tripping through RepoConfig dataclass
6. Tests verify that invalid values are rejected with clear error messages
7. Tests verify that valid values pass validation and persist correctly

**Key files to modify:**
- `pennyfarthing-dist/src/pf/settings/settings.py` — add VALIDATORS, integrate into set_setting/set_setting_typed
- `pennyfarthing-dist/src/pf/git/repos.py` — add validation to set_repo_field
