# Session: 67-1 - Editor mode toggle

## Story
**ID:** 67-1
**Title:** Editor mode toggle: rich text vs plain textarea
**Points:** 2
**Workflow:** trivial
**Epic:** MSSCI-11715 (Cyclist UI/UX Improvements)

## Context

User reported that the TipTap rich text editor is too unresponsive and they're not using any rich text features. Need a settings toggle to switch between:

1. **Rich text mode** (TipTap) - current default, full formatting support
2. **Plain text mode** (textarea) - lightweight, faster input

## Existing Work

A textarea-based editor has already been created at:
- `pennyfarthing/packages/cyclist/src/public/js/editor-textarea.js`

The index.html was modified to support dynamic loading but needs cleanup.

Key files:
- `pennyfarthing/packages/cyclist/src/public/js/editor.js` - TipTap editor
- `pennyfarthing/packages/cyclist/src/public/js/editor-textarea.js` - Plain textarea editor
- `pennyfarthing/packages/cyclist/src/public/index.html` - Editor initialization
- `pennyfarthing/packages/cyclist/src/public/js/settings-sync.js` - Settings management

## Acceptance Criteria

- [ ] Settings toggle in Cyclist preferences for editor mode (rich/plain)
- [ ] Plain textarea mode uses editor-textarea.js for faster input
- [ ] Rich text mode uses TipTap editor (current default)
- [ ] Setting persists in localStorage
- [ ] Both modes support: Enter to submit, Shift+Enter for newline, image paste, command history, tab completion

## Implementation Notes

The editor-textarea.js module maintains API compatibility with editor.js, re-exporting the same functions from shared modules (message-queue, tab-completion, etc.).

Current index.html changes need review - there's dynamic import logic that should be simplified.

---

## Phase: finish

**Assigned:** sm
**Status:** Approved - ready for finish-story

---

## Reviewer Assessment (Round 1)

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Closure bug: `currentMode` captured at init, never updated. Toggle won't work after first switch. | `settings-panel.js:119` | Track selected mode in mutable variable or re-read from storage in click handler |
| [MEDIUM] | Formatting toolbar visible in plain text mode but buttons do nothing | `index.html:94` + `editor-textarea.js` | Hide `#editor-toolbar` when textarea mode active |

**Data flow traced:** localStorage → index.html init → dynamic import → editor creation (OK)
**Pattern observed:** Good API compatibility via re-exports at `editor-textarea.js:47-77`
**Error handling:** Image paste errors logged to console (acceptable)

**Handoff:** Back to Dev (Naomi) for fixes

---

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED with Medium observations (non-blocking)

| Severity | Issue | Location | Status |
|----------|-------|----------|--------|
| [VERIFIED] | Closure bug fixed | `settings-panel.js:107` | `let selectedMode` now properly mutable |
| [VERIFIED] | Toolbar hiding implemented | `settings-panel.js:157,173` | `toolbar.style.display` set correctly |
| [VERIFIED] | Previous rejection issues resolved | Multiple files | All fixes applied |
| [MEDIUM] | console.log statements in production | `editor-textarea.js:532,538,548,577` & `settings-panel.js:158,174` | Non-blocking: debug logging, consider removing before release |
| [MEDIUM] | No error handling on dynamic import/script load | `settings-panel.js:162-168` | Non-blocking: script.onerror not handled, would silently fail |
| [LOW] | Module import mismatch: message-view-init imports from editor.js only | `message-view-init.js:24` | Works because both editors call shared module state, but architecturally fragile |

**Data flow traced:**
- User clicks toggle → `selectedMode` updated → `settingsSync.set()` → `swapEditor()` called
- `swapEditor()` clears container → dynamically imports correct editor → creates new editor instance
- Both editors use shared state from `./editor/message-queue.js` for `isProcessing`, `setProcessing`
- `resetSubmitting` is per-editor module state, but works because IPC handler calls editor.js exports

**Pattern observed:** Good architectural decision to use shared modules for common state (`editor/message-queue.js`, `editor/tab-completion.js`) - both editor implementations leverage same underlying state. The `isSubmitting` flag is local but `resetSubmitting` is re-exported from both modules.

**Error handling:**
- Image paste errors logged, non-blocking
- Dynamic script loading has no error handler - silent failure possible but unlikely

**Security:** No XSS vectors found; input sanitization via existing MessageView patterns.

**Hard questions checked:**
- What if user toggles rapidly? Each `swapEditor` clears container, last one wins - acceptable
- What if TipTap bundle fails to load? Silent failure, user stuck - medium risk, but existing code path

**Handoff:** To SM (Camina) for finish-story

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/js/editor-textarea.js` - New lightweight textarea editor
- `packages/cyclist/src/public/js/settings-panel.js` - Editor mode toggle UI
- `packages/cyclist/src/public/js/settings-sync.js` - EDITOR_MODE storage key
- `packages/cyclist/src/public/index.html` - Dynamic editor loading
- `packages/cyclist/src/public/styles.css` - Toggle and reload notice styles

**Tests:** Build passes (no dedicated tests for trivial workflow)
**PR:** #555 - feat(cyclist): add editor mode toggle setting (67-1)
**Branch:** 67-1-editor-mode-toggle (pushed)

**Handoff:** To Reviewer (Chrisjen) for code review
