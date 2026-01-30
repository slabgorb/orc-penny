# Story 68-5: Move Portrait/Persona Section to Message Panel Header

## Session Information

- **Story ID**: 68-5
- **Title**: Move Portrait/Persona section to Message panel header
- **JIRA Key**: MSSCI-12676 (Epic 68)
- **Points**: 2
- **Priority**: P1
- **Status**: in_progress
- **Workflow**: trivial
- **Phase**: approved
- **Assignee**: keith
- **Repository**: pennyfarthing
- **Feature Branch**: feat/68-5-move-portrait-to-message-header

## Epic Context

**Epic 68**: Cyclist Sidebar Panels to Top-Level Tabs

This epic promotes sidebar sections to independent top-level tabs using existing VerticalPanel infrastructure. Previously completed stories in this epic:

- 68-1: Create Background Tasks panel as top-level tab ✅
- 68-2: Create Todos panel as top-level tab ✅
- 68-3: Create Sprint panel as top-level tab ✅
- 68-4: Create Git panel as top-level tab ✅

**68-5** is the final critical step: Move the persona section (portrait, character name, theme, quote) from the sidebar to the top of the message panel. This frees up the last sidebar content, enabling complete sidebar removal in story 68-6.

## Acceptance Criteria

- [ ] Persona info displays at top of message panel
- [ ] Portrait thumbnail, character name, theme visible
- [ ] Click opens persona popup modal (existing functionality)
- [ ] Persona section removed from sidebar

## Technical Context

### Current Implementation

The persona section is currently rendered in the sidebar with these components:

- **persona.js** - Main module for persona state management and updates
  - Updates persona display (character name, theme, quote)
  - Manages persona popup modal (MSSCI-12403 implementation)
  - Stores current helper name and theme data
  - Provides `updatePersona()` function for IPC updates

- **portrait.js** - Portrait image loading and caching
  - Handles multi-resolution portrait loading (small/medium/large/original)
  - Supports theme-specific portraits from CDN
  - Manages fallback chain for missing portraits
  - Supports 102 different themes

- **sidebar/index.js** - Sidebar panel orchestration
  - Currently renders persona section within sidebar
  - Includes persona HTML structure in sidebar DOM

### Current HTML Structure

The persona section likely follows this pattern in the sidebar:
- Portrait image container (#portrait-container)
- Character name (#character-name)
- Theme name (#theme-name)
- Character quote (#character-quote)
- Popup trigger functionality

### Files to Modify

1. **pennyfarthing/packages/cyclist/src/public/index.html**
   - Add persona header section to #message-panel (above #message-view)
   - Move persona HTML elements (portrait, character-name, theme-name, character-quote)
   - Remove persona-section from sidebar HTML

2. **pennyfarthing/packages/cyclist/src/public/js/persona.js**
   - Update DOM element selectors for new header location
   - Ensure popup modal still functions correctly
   - Ensure IPC persona updates work with new DOM structure

3. **pennyfarthing/packages/cyclist/src/public/js/sidebar/portrait.js**
   - Adapt portrait element selectors to new location
   - Consider responsive layout for header (more compact than sidebar)
   - Support image loading at new resolution (likely small/medium)

4. **pennyfarthing/packages/cyclist/src/public/js/sidebar/index.js**
   - Remove persona section initialization from sidebar
   - Remove persona-related DOM references

5. **pennyfarthing/packages/cyclist/src/public/css/** (as needed)
   - Add CSS for persona header in message panel
   - Compact layout suitable for header position
   - Horizontal orientation to match header style
   - Remove sidebar-specific persona CSS

### Implementation Strategy

**Compact Header Layout**:
- Horizontal layout (left-to-right): portrait thumbnail | name, theme, quote
- Small portrait size (64x64 or small/medium resolution)
- Minimal vertical height to preserve message panel space
- Click-to-open persona popup modal (existing functionality)

**Styling Approach**:
- Header should blend with existing message panel styling
- Consider minimal borders/separators
- Theme colors should work with light/dark mode
- Maintain clickable/hover states for modal trigger

**Module Integration**:
- persona.js DOM selectors must point to new message panel location
- portrait.js should work with new sizing and location
- Popup modal functionality must remain intact
- Existing IPC update mechanism must continue working

## Definition of Done

- [ ] Persona header section added to message panel
- [ ] Portrait, character name, and theme display correctly in header
- [ ] Click/tap opens persona popup modal
- [ ] All persona DOM elements removed from sidebar
- [ ] No console errors related to persona
- [ ] Persona updates from IPC still work
- [ ] Visual layout is compact and header-appropriate
- [ ] Persona header responsive (visible in narrow and wide windows)

## Related Stories

- **68-4** (completed): Git panel top-level tab - last panel before this
- **68-6** (upcoming): Remove sidebar entirely - depends on this story's completion

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `packages/cyclist/src/public/index.html` - Added persona header, hidden sidebar section
- `packages/cyclist/src/public/js/persona.js` - Added header element selectors and popup trigger
- `packages/cyclist/src/public/js/sidebar/portrait.js` - Added header thumbnail loading
- `packages/cyclist/src/public/styles.css` - Added compact header styling (89 lines)

**Build:** ✅ Passing
**Lint:** ✅ Passing
**PR:** [#571](https://github.com/1898andCo/pennyfarthing/pull/571) - feat(cyclist): move persona section from sidebar to message header
**Branch:** feat/68-5-move-portrait-to-message-header (pushed)

**Implementation Notes:**
- Compact horizontal layout: 32px portrait thumbnail, character name, role badge, theme name
- Click handler triggers existing persona popup modal
- Original sidebar elements hidden but kept for backwards compatibility (IPC updates still work)
- Portrait module updated to load thumbnails in both locations
- Full cleanup deferred to 68-6 when sidebar is removed entirely

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Preflight:**
- Build: ✅ Passing
- Lint: ✅ Passing
- Git: Clean working tree

**Data flow traced:** IPC persona update → `updatePersona()` → header elements (`header-character-name`, `header-character-role`, `header-theme-name`) at `persona.js:111-119`. Safe: uses `textContent` assignment, not innerHTML.

**Wiring verified:** Click handler on `#persona-header` triggers `showPersonaPopup()` at `persona.js:458-463`. Portrait loading wired via `loadPortraitWithTheme()` at `portrait.js:170-181`.

**Error handling:** Portrait fallback chain (theme → discworld → placeholder) preserved for header thumbnail at `portrait.js:173-180`. Event listeners cleaned up in `destroy()` at `portrait.js:291-294`.

**Edge cases:** Null/undefined inputs handled with fallbacks (`|| 'Loading...'`, `|| ''`).

**Observations:**
| # | Severity | Issue | Location |
|---|----------|-------|----------|
| 1 | [VERIFIED] | Data flow correct | `persona.js:111-119` |
| 2 | [VERIFIED] | Click handler wired | `persona.js:458-463` |
| 3 | [VERIFIED] | Error handling preserved | `portrait.js:173-180` |
| 4 | [VERIFIED] | Backwards compatibility | `index.html:179-190` |
| 5 | [LOW] | CSS sibling selector cosmetic issue | `styles.css:5917-5919` |

**No blocking issues (Critical/High).** Low severity CSS selector issue is cosmetic only.

**Handoff:** To SM (Titus Pullo) for finish-story
