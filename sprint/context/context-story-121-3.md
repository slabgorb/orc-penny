# Context: Story 121-3 — Fix footer keybinding labels — bracket display is inaccurate

**GitHub Issue:** 1898andCo/pennyfarthing#1050
**Jira:** MSSCI-15394
**Points:** 1
**Epic:** 121 — Debug Panel and Brownfield Tools Fixes

## Problem

The BikeRack TUI footer displayed keybinding hints with incorrect or inconsistent bracket formatting around key names. The `BindingFooter` widget showed labels like `[Prev` and `]Next` with mismatched bracket notation, making the footer menu hard to read and semantically confusing.

Additionally, the footer layout fragmented across three separate components:
- `BindingFooter` — keybinding hints (Textual `Footer` subclass)
- `ContextMeterFooter` — context usage bar
- `#project-dir` — project name (plain Static widget)

This made the footer cluttered and difficult to maintain.

## Solution: Unified StatusFooter

Consolidated the footer into a single widget that:
1. Removes `BindingFooter` entirely (bracket labels were the source of confusion)
2. Replaces `ContextMeterFooter` + `#project-dir` + `BindingFooter` with `StatusFooter`
3. Creates a single-line footer with left-aligned content and right-aligned context bar:
   - **Left:** Project name + model indicator (dimmed)
   - **Right:** Context usage progress bar

The new design:
- Eliminates bracket notation confusion (keybindings now hidden via `show=False`)
- Centralizes footer state and rendering
- Cleaner, more maintainable code path

### Key Changes

**Bindings updated in `tui.py` (lines 430–442):**
- `bracketright` action: changed description from `]Next` to `Next panel` with `show=False`
- `bracketleft` action: changed description from `[Prev` to `Prev panel` with `show=False`
- Quit and split bindings also set `show=False` to hide from footer

**`context_meter_footer.py` rewrite:**
- Renamed class: `ContextMeterFooter` → `StatusFooter`
- New `_render_status()` method builds full-width footer line
- Subscribes to both `/ws/context` and `/ws/stats` channels
- New helper `_clean_model_name()` strips `claude-` prefix and date stamps

**`portrait_resolver.py` enhancement:**
- Added `_is_lfs_pointer()` to gracefully skip unresolved git-lfs pointer files

## Key Files

| File | Lines | Role |
|------|-------|------|
| `pf/bikerack/context_meter_footer.py` | 266 | StatusFooter widget — unified footer rendering |
| `pf/bikerack/tui.py` | 1053 | BikeRackApp layout — removed BindingFooter + #project-dir, mounted StatusFooter |
| `pf/bikerack/portrait_resolver.py` | 172 | Added LFS pointer detection for portrait resolution |

## Acceptance Criteria

✓ **AC1: Keybinding labels are removed from footer**
- Hidden via `show=False` on bracket bindings

✓ **AC2: Single unified footer displays project + model + context bar**
- StatusFooter consolidates all footer content in one widget

✓ **AC3: No visual regression in context usage display**
- `_render_context_bar()` preserves existing meter styling

✓ **AC4: Tests updated to verify new footer structure**
- Old `BindingFooter` tests removed
- New `StatusFooter` tests verify single-widget footer
