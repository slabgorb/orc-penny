# Epic 122: SettingsPanel Read-Only Conversion

**Priority:** P1
**Status:** in_progress
**Repos:** pennyfarthing

## Overview

Remove interactive controls from the Cyclist SettingsPanel and replace with a read-only display of all settings. The `/pf-settings` CLI skill becomes the single entry point for changing configuration. This reduces UI complexity and eliminates a class of state-sync bugs between the UI and config.local.yaml.

## Stories

### 122-1: Convert SettingsPanel from interactive controls to read-only display (3 pts, P1)
- Remove: theme dropdown, ThemePalette color picker, FontPicker/FontSizePicker, Bell/Relay Mode toggles
- Replace with structured read-only view grouped by: Theme & Display, Workflow, Notifications
- Keep /api/settings GET + WebSocket listener for live updates
- Panel must render in both Cyclist and BikeRack

**Key files:**
- Panel: `packages/core/src/public/components/panels/SettingsPanel.tsx`
- Color picker: `packages/core/src/public/components/ThemePalette.tsx`
- Font pickers: `packages/core/src/public/components/FontPicker.tsx`, `FontSizePicker.tsx`
- Settings API: `packages/core/src/server/api/` (settings routes)
- WebSocket: `packages/core/src/server/` or `packages/cyclist/src/websocket.ts`

### 122-2: Add CLI command reference and usage guide to SettingsPanel (2 pts, P1)
- Show dot-path key next to each setting for `/pf-settings set` usage
- Include quick-reference block with example commands

### 122-3: Remove dead interactive components after SettingsPanel conversion (1 pt, P2)
- Audit ThemePalette, FontPicker, FontSizePicker for other consumers
- Remove orphaned component files if safe
- Clean unused imports
