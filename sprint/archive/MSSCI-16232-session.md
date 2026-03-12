# MSSCI-16232: Sprint panel: differentiate in-review stories from backlog

**Jira:** MSSCI-16232
**Points:** 2
**Priority:** p1
**Workflow:** trivial
**Phase:** finish
**Status:** in_progress
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16232-sprint-panel-review-styling

---

## Acceptance Criteria

- [ ] `getStatusBadgeInfo()` returns a unique icon and className for `in_review` status
- [ ] Assignee badge uses a different color class when story is in review
- [ ] TUI sprint panel visually distinguishes in-review stories from backlog stories

## Technical Approach

File: `packages/core/src/public/components/panels/SprintPanel.tsx`

1. Add `case 'in_review'` to `getStatusBadgeInfo()` with a review-specific icon (e.g., Eye from lucide-react) and `status-in-review` className
2. In the story-item rendering, conditionally add a review-specific class to the assignee badge when `story.status === 'in_review'`
3. Add corresponding CSS for `status-in-review` and review-state assignee badge styling

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/public/components/panels/SprintPanel.tsx` - Added `Eye` icon import, `in_review` case in `getStatusBadgeInfo()`, `outline` badge variant for review status, conditional `assignee-in-review` class on assignee badge
- `packages/core/src/public/styles/tailwind.css` - Added `status-in-review` (accent color + border) and `assignee-in-review` (accent color, bold, no italic) CSS rules

**Tests:** 18/18 passing (sprint-data.test.js GREEN)
**Branch:** feat/MSSCI-16232-sprint-panel-review-styling (pushed)

**Handoff:** To Reviewer (River) for code review

## Delivery Findings

- No upstream findings during implementation.

### Reviewer (code review)

- **Improvement** (non-blocking): `cancelled` status also falls through to backlog default in `getStatusBadgeInfo()`. Affects `packages/core/src/public/components/panels/SprintPanel.tsx` (add cancelled case with strikethrough or X icon). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `pf sprint data --json` → `mapStoryStatus()` (sprint-data.ts:160) → WebSocket → `useSprint` hook (useSprint.ts:28) → `getStatusBadgeInfo()` (SprintPanel.tsx:114) → Eye icon + status-in-review class. Type-safe end-to-end.
**Pattern observed:** Consistent use of `var(--accent)` CSS variable with fallback at tailwind.css:1736-1744. Matches existing status styling pattern.
**Error handling:** N/A — pure rendering change, no failure paths introduced. Unknown statuses still fall through to backlog default.
**Security:** No user input, no dynamic content injection. Clean.

**Observations:**
1. [VERIFIED] `in_review` in type union at sprint-data.ts:34 and useSprint.ts:28
2. [VERIFIED] Eye icon import and switch case at SprintPanel.tsx:114
3. [VERIFIED] CSS specificity correct — `.assignee-in-review` overrides base `.story-assignee`
4. [VERIFIED] All 30+ theme presets covered via `--accent` variable
5. [LOW] Badge variant ternary 3 levels deep at SprintPanel.tsx:185 — acceptable, pre-existing pattern
6. [VERIFIED] No forbidden patterns in diff
7. [VERIFIED] Build passes, tests green (18/18)

**Handoff:** To Zoe (SM) for finish

## SM Assessment

Story created from user request. The `in_review` status already exists in the data model (`sprint-data.ts:34`) but the UI doesn't differentiate it from backlog. Single-file fix in `SprintPanel.tsx`. Trivial workflow — straight to Dev (Mal).