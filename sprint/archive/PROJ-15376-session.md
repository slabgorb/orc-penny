# Story 122-3: Remove dead interactive components after SettingsPanel conversion

**Jira:** PROJ-15376
**Epic:** epic-122 (SettingsPanel Read-Only Conversion)
**Points:** 1
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/122-3-remove-dead-interactive-components
**Assigned:** slabgorb@gmail.com

---

## Description

After 122-1 lands, audit and remove components that are no longer used: ThemePalette, FontPicker, FontSizePicker, and any Switch toggle wrappers if only consumed by SettingsPanel. Check for other consumers before deleting. Clean up unused imports in SettingsPanel.tsx. Do NOT remove the PATCH /api/settings endpoint — other tools may use it.

## Acceptance Criteria

- [ ] No orphaned component files remain
- [ ] No unused imports in SettingsPanel
- [ ] Build passes clean

## Context

This is the final cleanup story for epic-122. Stories 122-1 (read-only conversion) and 122-2 (CLI command reference) are already done. This story removes the dead code left behind.

## Assessments

### Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/public/components/ThemePalette/` — Deleted (index.tsx + CSS). No consumers after SettingsPanel conversion.
- `packages/core/src/public/components/FontPicker/` — Deleted (index.tsx + CSS). No consumers after SettingsPanel conversion.
- `packages/core/src/public/components/ui/switch.tsx` — Deleted. Zero imports anywhere in codebase.
- `packages/core/src/public/styles/tailwind.css` — Removed dead `.cyclist-switch` and `.theme-palette-menu` CSS blocks.
- `packages/cyclist/tests/PROJ-12768-color-palette-system.test.ts` — Deleted (tested dead ThemePalette).
- `packages/cyclist/tests/PROJ-12769-font-customization.test.ts` — Deleted (tested dead FontPicker/FontSizePicker).

**Retained (verified live consumers):**
- `utils/color-presets.ts` — Used by App.tsx
- `utils/font-presets.ts` — Used by App.tsx
- `ModeSwitch/` — Used by Editor.tsx + usePlanModeExit.ts
- `PATCH /api/settings` endpoint — Preserved per story requirements

**Build:** Clean (tsc + vite, both core and cyclist)
**Tests:** 14/14 passing on 122-1 test file. 4 pre-existing failures (missing jest-dom matchers — not caused by this change).
**Branch:** feature/122-3-remove-dead-interactive-components (pushed)

**Handoff:** To Reviewer for code review

### Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] Consumer audit — ThemePalette, FontPicker, FontSizePicker, ui/switch: zero imports in core/src and cyclist/src. No barrel re-exports.
2. [VERIFIED] Retained components alive — color-presets.ts (App.tsx:24), font-presets.ts (App.tsx:23), ModeSwitch (Editor.tsx:31, usePlanModeExit.ts:11).
3. [VERIFIED] PATCH /api/settings preserved — server/api/settings.ts:54 has 3 PATCH routes intact. Constraint honored.
4. [VERIFIED] CSS cleanup scoped — only `.cyclist-switch` and `.theme-palette-menu` removed. Adjacent rules untouched.
5. [VERIFIED] Test deletion safe — remaining 122-1 test has negative assertions ("should NOT render") that pass correctly with components gone.
6. [LOW] 4 pre-existing test failures (missing jest-dom matchers) — not caused by this change.
7. [VERIFIED] Build clean — tsc + vite, core + cyclist, no new warnings.

**Data flow traced:** SettingsPanel.tsx → fetch('/api/settings') → WebSocket '/ws/settings'. Read-only path only. No writes from UI. PATCH endpoint preserved for external tool use.
**Error handling:** SettingsPanel catches fetch and WebSocket parse errors (lines 86, 102). Adequate.

**Handoff:** To SM for finish