# Epic 68: Cyclist Sidebar Panels to Top-Level Tabs

## Overview

Promote sidebar sections to independent top-level tabs using existing VerticalPanel infrastructure. Sections currently compete for vertical space in the sidebar - promoting them to tabs gives each its own panel.

## Epic Details

- **Epic ID**: epic-68
- **JIRA Key**: MSSCI-12676
- **Points**: 12
- **Priority**: P1
- **Status**: active
- **Repository**: pennyfarthing

## New Tabs

The following new tabs will be added alongside existing SETTINGS:

1. **BACKGROUND** - Background tasks panel ✅
2. **TODOS** - Todo/task list panel ✅
3. **SPRINT** - Story/sprint awareness panel ✅
4. **GIT** - Git status panel

## Sidebar Removal

After all sections are moved to dedicated panels, the sidebar becomes empty and can be removed:

5. **Persona → Message Panel Header** - Move portrait/persona to top of message panel
6. **Remove Sidebar** - Delete sidebar entirely once empty

## Technical Approach

Uses existing VerticalPanel class infrastructure - no new resize infrastructure needed. Each tab is a separate VerticalPanel instance with independent state management.

## Stories

### 68-1: Create Background Tasks panel as top-level tab (2 points)
Extract background-tasks section from sidebar into its own VerticalPanel. Wire up existing background-tasks.js module.

**Acceptance Criteria:**
- BACKGROUND tab visible in tab bar
- Panel toggles on tab click
- Badge shows active task count
- Existing task rendering works in new location

### 68-2: Create Todos panel as top-level tab (2 points)
Extract todos section from sidebar into its own VerticalPanel. Wire up existing tasks.js module.

**Acceptance Criteria:**
- TODOS tab visible in tab bar
- Panel toggles on tab click
- Progress shows in tab (e.g., "3/5")
- Existing todo rendering works in new location

### 68-3: Create Sprint panel as top-level tab (2 points)
Extract story/sprint section from sidebar into its own VerticalPanel. Include AC section within this panel.

**Acceptance Criteria:**
- SPRINT tab visible in tab bar
- Panel toggles on tab click
- Story, sprint stats, ACs all render in panel
- Epic context expandable section works

### 68-4: Create Git panel as top-level tab (2 points)
Extract git section from sidebar into its own VerticalPanel. Wire up existing git.js module.

**Acceptance Criteria:**
- GIT tab visible in tab bar
- Panel toggles on tab click
- Badge shows dirty file count
- Multi-repo status renders correctly

### 68-5: Move Portrait/Persona section to Message panel header (2 points)
Move the persona section (portrait, character name, theme, quote) from sidebar to the top of the message panel. This is the final sidebar section that needs a new home.

**Acceptance Criteria:**
- Persona info displays at top of message panel
- Portrait thumbnail, character name, theme visible
- Click opens persona popup modal (existing functionality)
- Persona section removed from sidebar

### 68-6: Remove sidebar panel entirely (2 points)
With all sections moved to dedicated panels and message panel header, remove the now-empty sidebar.

**Acceptance Criteria:**
- Sidebar element removed from HTML
- SIDEBAR tab no longer appears in tab bar
- No JavaScript errors from missing sidebar
- All former sidebar content accessible via other panels

## Implementation Details

All panels extend VerticalPanel class and follow existing panel patterns:
- Use existing resize infrastructure
- Integrate with state management (LocalStorage)
- Update tab bar to show new tabs
- Migrate existing rendering logic from sidebar.js to panel-specific modules
