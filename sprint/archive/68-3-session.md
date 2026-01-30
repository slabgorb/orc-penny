# Story 68-3: Create Sprint panel as top-level tab

**Story ID:** 68-3
**Jira:** (not linked)
**Status:** in_progress
**Workflow:** trivial
**Phase:** approved
**Repos:** pennyfarthing
**Feature Branch:** feat/68-3-sprint-panel-tab

## Context

Epic 68 is converting sidebar sections to top-level tabs. Stories 68-1 (Background Tasks) and 68-2 (Todos) are complete. This story does the same for the Sprint panel (story details section).

Reference implementation: Follow the todos-panel.js and background-panel.js patterns:
- New tab button in `.tab-bar`
- Panel markup in `#sprint-panel` with `.vertical-panel` class
- Panel JS module for initialization
- Tab bar integration via PanelManager

## Acceptance Criteria

- [ ] Sprint/Story section removed from sidebar
- [ ] New "SPRINT" tab in top tab bar
- [ ] Sprint panel as vertical panel (like Todos/Background)
- [ ] Panel shows story details, ACs, etc.
- [ ] Collapse/expand via tab toggle works

## Files to Reference

- `packages/cyclist/src/public/index.html` - HTML structure
- `packages/cyclist/src/public/styles.css` - Panel styling
- `packages/cyclist/src/public/js/todos-panel.js` - Reference implementation
- `packages/cyclist/src/public/js/sidebar/story.js` - Story module to integrate
- `packages/cyclist/src/public/js/panel-manager.js` - Panel management

## Reviewer Assessment

**Verdict:** APPROVED

**Build:** Passes (tsc compiles successfully)

**Observations:**

| Severity | Issue | Location | Notes |
|----------|-------|----------|-------|
| [VERIFIED] | XSS protection | `story.js:25-33` | `escapeHtml()` properly escapes all user-facing content |
| [VERIFIED] | Pattern followed | `sprint-panel.js:28-53` | Correctly extends VerticalPanel like todos/background panels |
| [VERIFIED] | PanelManager integration | `sprint-panel.js:116-138` | Proper registration with open/close callbacks |
| [MEDIUM] | Duplicate story.update() | `sprint-panel.js:71` + `sidebar/index.js:250` | Both IPC listeners call story.update() - wasteful but harmless |
| [LOW] | Pre-existing: unescaped PR# | `story.js:297` | PR number not escaped in innerHTML - low risk (integers only) |

**Data flow traced:** WebSocket/IPC → `story.onUpdate` → `updatePanelDisplay()` → `story.update()` → DOM updates (verified safe)

**Acceptance Criteria:**
- [x] Sprint/Story section removed from sidebar (HTML line 235-237)
- [x] New "SPRINT" tab in top tab bar (PanelManager order 4)
- [x] Sprint panel as vertical panel (extends VerticalPanel)
- [x] Panel shows story details, ACs, etc. (HTML lines 282-336)
- [x] Collapse/expand via tab toggle works (onOpen/onClose wired)

**PR Status:** Already merged to develop (c214ea5de)

**Handoff:** To SM for story completion
