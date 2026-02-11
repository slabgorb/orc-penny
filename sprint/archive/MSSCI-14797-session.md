# Story 100-4: Remove persona name from quick agent picker

## Story Info

- ID: 100-4
- Jira: MSSCI-14797
- Title: Remove persona name from quick agent picker
- Points: 1
- Priority: P1
- Epic: 100 (UI Tweak Bucket)
- Repos: pennyfarthing
- Assigned to: K. Avery
- Status: in_progress
- Workflow: trivial

## Context Summary

The quick agent picker was introduced in story 100-2. This story refines the UI by removing the persona name display from the quick agent picker buttons, simplifying the visual presentation.

### Epic Context (100: UI Tweak Bucket)

Collection of small UI tweaks, polish, and cosmetic fixes across Cyclist and framework components. This story is part of a broader initiative to polish the Cyclist interface.

### Existing Foundation

- Story 100-2 added the quick agent picker in control bar with QuickActions component
- QuickActions renders agent selection buttons with persona metadata
- Current implementation displays both persona icon and name

### Implementation Approach

Modify the QuickActions component in Cyclist to remove the persona name text while keeping the icon/visual representation:

1. **Locate QuickActions component**
   - File: `pennyfarthing/packages/cyclist/src/components/QuickActions.tsx`
   - Current rendering includes persona name in button text

2. **Update QuickActions rendering**
   - Remove persona name text from button labels
   - Keep icon or visual identifier for agent selection
   - Maintain tooltip for accessibility (show full name on hover)

3. **Test changes**
   - Verify picker still shows all available agents
   - Confirm icon/visual is clear without text
   - Check that selection still works

### Target Changes

- **Modify:** `pennyfarthing/packages/cyclist/src/components/QuickActions.tsx`
  - Remove persona name from button text display
  - Add tooltip or aria-label with full persona name for accessibility
  - Keep visual icon representation intact

## Acceptance Criteria

- [ ] Quick agent picker buttons display only icon/visual (no persona name)
- [ ] Tooltip or aria-label provides full persona name on hover
- [ ] Agent selection functionality works correctly
- [ ] Visual layout is clean and uncluttered

## Branch

- feat/100-4-remove-persona-name-quick-picker (pennyfarthing repo)

## Phase: finish

## Workflow Checklist

- [ ] SM: Story setup complete
- [ ] Dev: Implementation (GREEN phase)
- [ ] Reviewer: Code review
- [ ] SM: Story completion

---

## Session Log

### Setup Phase

**What will be done:**
- Remove persona name from quick agent picker UI
- Simplify visual presentation while maintaining functionality
- Add accessibility features (tooltip/aria-label)

**Next:** Dev implements the UI changes

### Handoff to Dev

**Timestamp:** 2026-02-11
**From:** SM (setup)
**To:** Dev (implement)
**Status:** Ready for implementation

Dev will now implement the UI changes to remove persona name from quick agent picker buttons in the QuickActions component.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/ControlBar.tsx` - Removed character name span from AgentQuickPicker dropdown, added title and aria-label attrs
- `packages/cyclist/src/public/styles/tailwind.css` - Removed unused `.agent-option-character` class, reduced dropdown min-width
- `packages/cyclist/tests/MSSCI-14762-agent-quick-picker.test.tsx` - Updated test to check title attr instead of textContent for character name

**Tests:** 17/17 passing (GREEN)
**PR:** #810 — feat(100-4): remove persona name from quick agent picker
**Branch:** feat/100-4-remove-persona-name-quick-picker (pushed)

**Handoff:** To Reviewer for code review

### Handoff to Reviewer

**Timestamp:** 2026-02-11
**From:** Dev (implement)
**To:** Reviewer (review)
**Status:** Implementation complete, all tests passing (17/17 GREEN)
**PR:** #810 ready for code review

Reviewer will now conduct code review of the quick agent picker persona name removal changes.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `/api/theme-agents/full` → `agents` state → `agent.role` rendered in span, `agent.character` in title/aria-label → click → `onAgentSwitch(role)` → `send(\`/${role}\`)` (safe, no user input in path)
**Pattern observed:** Proper accessibility pattern — visual simplification with tooltip+aria-label fallback at `ControlBar.tsx:149-150`
**Error handling:** Fetch error at line 74 silently caught (pre-existing, acceptable for non-critical UI)
**Security:** No injection vectors — title attribute doesn't execute, data sourced from server API
**[LOW]** Extra blank line at `tailwind.css:4297-4298` — cosmetic, not blocking

**Handoff:** To SM for finish-story

### Handoff to SM

**Timestamp:** 2026-02-11
**From:** Reviewer (review)
**To:** SM (finish)
**Verdict:** APPROVED
**PR:** #810 merged
**Status:** Code review complete, all changes approved

SM will now complete the story, merge the PR, and finalize the work.
