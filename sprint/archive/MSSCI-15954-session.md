# 103-23: Statusline and TUI context bar use different color thresholds

**Story ID:** 103-23
**Jira:** MSSCI-15954
**Epic:** 103 — BikeRack TUI — Terminal-Native Dashboard
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/103-23-color-threshold-alignment

---
## Story

### Title
Statusline and TUI context bar use different color thresholds

### Description
The statusline (displayed in the Cyclist/CLI context bar) and the TUI context bar use different color threshold values for visual indicators. These need to be unified to provide consistent visual feedback across both interfaces.

### Type
Bug (Priority: P2)

### Points
1 point

### Acceptance Criteria
- [ ] Identify the current color threshold values used in statusline
- [ ] Identify the current color threshold values used in TUI context bar
- [ ] Determine the correct threshold values that should be used
- [ ] Update statusline to use unified thresholds
- [ ] Update TUI context bar to use unified thresholds
- [ ] Verify visual consistency between both components

## Context

### Technical Approach
1. Search for color threshold logic in statusline implementation
2. Search for color threshold logic in TUI context bar implementation
3. Compare the two implementations to understand the discrepancy
4. Consolidate to a single source of truth for color thresholds (likely a shared utility)
5. Update both components to reference the unified thresholds
6. Test both interfaces to confirm consistent color behavior

### Related Items
- Epic: 103 — BikeRack TUI — Terminal-Native Dashboard
- Similar stories: 103-26 (Status line [rev] tag has insufficient text contrast)

## Assessment

**SM Assessment (Leo McGarry):**

1-point trivial bug. The statusline and TUI context bar have divergent color threshold values — they should share a single source of truth. Story 136-4 already extracted shared TUI color thresholds and contrast constants, so the fix is likely wiring both consumers to the same constants.

**Routing:** Trivial workflow → Toby Ziegler (Dev) picks up at `implement` phase. Straightforward alignment — find the two threshold sets, unify them.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/bikerack/base_panel.py` — `render_progress_bar` warn_high thresholds 50/80 → 70/85
- `pennyfarthing-dist/src/pf/bikerack/context_meter_footer.py` — context tier styling thresholds 50/80 → 70/85
- `pennyfarthing-dist/src/pf/bikerack/debug_panel.py` — sparkline color thresholds 50/80 → 70/85

**Threshold alignment after fix:**

| Component | Green | Yellow | Red |
|-----------|-------|--------|-----|
| Statusline (`statusline.py`) | ≤70% | 71-85% | >85% |
| StatsStrip (`StatsStrip.tsx`) | <70% | 70-84% | ≥85% |
| TUI progress bar (`base_panel.py`) | ≤70% | 71-85% | >85% |
| TUI context footer (`context_meter_footer.py`) | ≤70% | 71-85% | >85% |
| TUI debug sparkline (`debug_panel.py`) | ≤70% | 71-85% | >85% |

**Tests:** No regressions — all sprint panel and BikeRack tests passing
**Branch:** feature/103-23-color-threshold-alignment (pushed)

**Handoff:** To Josh Lyman (Reviewer) for code review

## Delivery Findings

### Dev (implementation)

- **Improvement** (non-blocking): The four threshold boundaries (statusline 70/85, StatsStrip 70/85, TUI 70/85, ContextConfig 60/65/85) should ideally reference shared constants rather than hardcoded values in each file. Story 136-4 title says "Extract shared TUI color thresholds" but no shared module was created — thresholds are still duplicated. Affects multiple files across Python and TypeScript. *Found by Dev during implementation.*

### Reviewer (code review)

- **Improvement** (non-blocking): StatsStrip uses `>= 70` (70 is warning) while statusline and TUI use `> 70` / `<= 70` (70 is green). Off-by-one at exactly 70%. Affects `packages/core/src/public/components/StatsStrip.tsx:52`. *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `percent` integer (0-100, clamped at `base_panel.py:69`) → threshold comparison → Rich style string → `Text.append()`. Pure display logic, no mutations, no side effects.

**Pattern observed:** Consistent three-tier threshold pattern (green/yellow/red) applied identically across all three files. Matches existing statusline pattern at `statusline.py:326-333`.

**Error handling:** Input clamped to 0-100 before threshold checks (`base_panel.py:69`). No division, no external calls, no failure modes.

**Observations:** 6 total — 4 verified good, 1 LOW (StatsStrip off-by-one at 70%), 1 confirmed no-issue (statusline bold-red tier at 95% is cosmetic). No Critical or High issues.

**Handoff:** To Leo McGarry (SM) for finish-story

---

**Created:** 2026-03-02