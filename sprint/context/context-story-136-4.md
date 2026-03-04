---
parent: context-epic-136.md
workflow: trivial
---

# Story 136-4: Extract shared TUI color thresholds and contrast constants

## Business Context

The BikeRack TUI uses green/yellow/red color bands to indicate resource usage severity (context window percentage, sparklines, footer meter). The threshold values (50% and 80%) and their associated Rich style strings are copy-pasted identically across three modules. When a designer or developer wants to adjust these bands -- say, shifting the yellow threshold from 80% to 75% -- they must find and update three separate files and hope they catch all instances. This is a maintenance hazard that has already survived multiple refactors untouched.

Extracting these into a single shared constants module eliminates the duplication, makes threshold tuning a one-line change, and establishes a pattern for future TUI styling constants. This is a pure refactor with no visual or behavioral changes.

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/bikerack/colors.py` (new) | Create shared constants module: threshold values, style-from-percent function, `_TIER_STYLES` dict |
| `pennyfarthing-dist/src/pf/bikerack/base_panel.py` | Import thresholds from `colors.py`; replace inline `if/elif/else` in `render_progress_bar` (lines 76-81) with shared function call |
| `pennyfarthing-dist/src/pf/bikerack/debug_panel.py` | Import `_TIER_STYLES` and threshold function from `colors.py`; remove local `_TIER_STYLES` dict (lines 23-28); replace inline thresholds in `_render_sparkline` (lines 402-407) |
| `pennyfarthing-dist/src/pf/bikerack/context_meter_footer.py` | Import threshold function from `colors.py`; replace inline thresholds in `_render_context_bar` (lines 254-259) |

### Key Files to Consume (Read-Only)

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/src/pf/bikerack/progress_panel.py` | Verify callers that pass `fill_style` override still work (lines 293, 323) |
| `pennyfarthing-dist/src/pf/bikerack/sprint_panel.py` | Verify callers that pass `fill_style` override still work (line 128) |
| `pennyfarthing-dist/src/pf/bikerack/story_detail_screen.py` | Verify callers that use default `warn_high=False` still work (line 192) |

### Patterns to Follow

- Place shared constants in a new `colors.py` module inside `pf.bikerack` -- keep it focused on color/style resolution, not general utilities
- The threshold function should accept a percent value and return a Rich style string (e.g., `"green"`, `"yellow"`, `"red"`), matching the exact strings currently produced
- Preserve `render_progress_bar`'s `fill_style` parameter -- it takes priority over threshold-computed styles when not `None`
- Preserve `render_progress_bar`'s `warn_high` parameter -- when `False`, the function returns `"blue"` regardless of percent
- `_TIER_STYLES` dict moves to `colors.py` as a module-level constant; `debug_panel.py` imports it from there
- Python 3.10+ -- use `|` union types, not `Optional[]`
- No new dependencies -- Rich is already used everywhere

### What NOT to Touch

- `render_progress_bar`'s signature or return type (callers depend on it)
- `ProgressPanel._render_burndown` and `SprintPanel` fill_style overrides (they bypass thresholds intentionally)
- The `_SPARKLINE_CHARS` constant in `debug_panel.py` (unrelated to color thresholds)
- TUI data pipeline behavior (that is story 136-5)
- Any files outside `pennyfarthing-dist/src/pf/bikerack/`

## Scope Boundaries

**In scope:**
- New `colors.py` module with threshold constants and style-resolution function
- Move `_TIER_STYLES` dict from `debug_panel.py` to `colors.py`
- Update all three consumer files to import from `colors.py` instead of inlining thresholds
- Verify no visual change in any panel's rendered output

**Out of scope:**
- Making thresholds configurable at runtime (config file, env var, etc.)
- Adding new color schemes or styles
- Changing the actual threshold values (50, 80) or style strings
- Refactoring `render_progress_bar`'s signature or adding new parameters
- TUI data pipeline improvements (story 136-5)
- Any non-Python files (JS, TS, YAML, etc.)

## AC Context

### AC1: Shared constants module exists

**Given** no `colors.py` exists in `pf.bikerack`
**When** the developer creates `pennyfarthing-dist/src/pf/bikerack/colors.py`
**Then** it exports:
- `WARN_THRESHOLD_LOW = 50` -- percent below which style is `"green"`
- `WARN_THRESHOLD_HIGH = 80` -- percent at or below which style is `"yellow"`, above which is `"red"`
- `TIER_STYLES: dict[str, str]` -- mapping `{"FULL": "bold green", "REFRESH": "bold yellow", "HANDOFF": "bold cyan", "MINIMAL": "bold red"}`
- `def warn_style(percent: int | float) -> str` -- returns `"green"` if `percent < 50`, `"yellow"` if `percent <= 80`, `"red"` otherwise

**Edge cases:**
- `percent` of exactly 50 returns `"yellow"` (not `"green"`) -- matches current `< 50` check
- `percent` of exactly 80 returns `"yellow"` (not `"red"`) -- matches current `<= 80` check
- `percent` of 0 returns `"green"`; `percent` of 100 returns `"red"`

### AC2: base_panel.py uses shared constants

**Given** `render_progress_bar` in `base_panel.py` has inline threshold logic (lines 76-81)
**When** the developer replaces it with a call to `warn_style()` from `colors.py`
**Then** the `warn_high=True` code path calls `warn_style(percent)` instead of inline `if/elif/else`
**And** the `fill_style` override still takes priority when not `None`
**And** the `warn_high=False` code path still returns `"blue"` unconditionally
**And** `render_progress_bar`'s function signature is unchanged
**And** all existing callers (`ProgressPanel`, `SprintPanel`, `DebugPanel`, `ContextMeterFooter`, `StoryDetailScreen`) produce identical output

**Edge cases:**
- `fill_style="green"` with `warn_high=True` and `percent=90` -- fill_style wins, bar is green (not red)
- `warn_high=False` with `percent=95` -- bar is blue (thresholds not consulted)

### AC3: debug_panel.py uses shared constants

**Given** `debug_panel.py` has a local `_TIER_STYLES` dict (lines 23-28) and inline thresholds in `_render_sparkline` (lines 402-407)
**When** the developer updates `debug_panel.py`
**Then** `_TIER_STYLES` is imported from `colors.py` instead of defined locally
**And** `_render_sparkline` calls `warn_style(pct)` instead of inline `if/elif/else`
**And** the sparkline renders identically: each character gets `"green"`, `"yellow"`, or `"red"` based on its percent value
**And** `_render_context` still uses `_TIER_STYLES` for tier badge styling

### AC4: context_meter_footer.py uses shared constants

**Given** `_render_context_bar` in `context_meter_footer.py` has inline thresholds (lines 254-259) for the tier label style
**When** the developer replaces them with `warn_style()` from `colors.py`
**Then** the tier label appended to the footer bar uses `f"bold {warn_style(percent)}"` instead of inline `if/elif/else`
**And** the footer bar renders identically for all percent values

**Edge cases:**
- `percent=0` with tier `"FULL"` -- tier label is `"bold green"`
- `percent=79` with tier `"REFRESH"` -- tier label is `"bold yellow"`
- `percent=81` with tier `"MINIMAL"` -- tier label is `"bold red"`

### AC5: No visual regression

**Given** all three files now import from `colors.py`
**When** each panel renders at percent values 0, 25, 49, 50, 79, 80, 81, 100
**Then** the Rich style string produced is identical to the prior inline logic at every test value
**And** no import errors occur in any module
**And** no circular imports exist (colors.py has no intra-package imports)
