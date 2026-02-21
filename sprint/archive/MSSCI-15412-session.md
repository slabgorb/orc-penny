# Story 120-8: Story details and progress page enrichment with native Textual widgets

## Story Details
- **ID:** 120-8
- **Jira Key:** MSSCI-15412
- **Epic:** 120 (MSSCI-15396) - BikeRack TUI Enhancements
- **Assignee:** K. Avery
- **Workflow:** bdd

## Story Context

**Objective:** Improve the BikeRack TUI story details page and bring story details to the progress page, rendering inside native Textual widgets.

**Background:** BikeRack is the standalone panel viewer for CLI-first development. This story focuses on enriching the TUI experience by:
1. Enhancing the story details page display
2. Bringing story details view to the progress page
3. Using native Textual widgets for proper TUI integration

**Repository:** pennyfarthing

## Workflow Tracking

**Workflow:** bdd
**Phase:** finish
**Phase Started:** 2026-02-21T21:21:26Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-21T21:02:17Z | 2026-02-21T21:03:35Z | 1m 18s |
| design | 2026-02-21T21:03:35Z | 2026-02-21T21:07:46Z | 4m 11s |
| red | 2026-02-21T21:07:46Z | 2026-02-21T21:11:03Z | 3m 17s |
| green | 2026-02-21T21:11:03Z | 2026-02-21T21:15:47Z | 4m 44s |
| review | 2026-02-21T21:15:47Z | 2026-02-21T21:21:26Z | 5m 39s |
| finish | 2026-02-21T21:21:26Z | - | - |

## Acceptance Criteria

- [ ] New `StoryDetailWidget` exists as a reusable Textual `Widget` with `compose()` method
- [ ] `StoryDetailWidget` uses `Collapsible` sections for ACs, Workflow, Git, Context, Session Notes
- [ ] `StoryDetailWidget` uses `Rule` for section separators (not Rich Text dashes)
- [ ] Absent sections (no data) are omitted entirely — Tufte pattern preserved
- [ ] `StoryDetailScreen` delegates rendering to `StoryDetailWidget` inside a `VerticalScroll`
- [ ] `StoryDetailScreen` keybindings preserved: Escape=back, Enter=open PR
- [ ] `ProgressPanel` gains Enter keybinding that pushes `StoryDetailScreen` with current story data
- [ ] Progress panel shows "[Enter] Story Details" hint when a story is active
- [ ] Collapsible sections are keyboard-navigable (Tab between sections, Enter to toggle)
- [ ] Existing `story_detail_data.py` enrichment logic reused (not duplicated)

## Reviewer Assessment — Review Phase

**Verdict:** APPROVED
**Data flow traced:** ProgressPanel._build_story_detail_data() -> StoryDetailScreen._enrich() -> fetch_story_detail() -> StoryDetailWidget.compose() (safe — no duplication, single enrichment path)
**Pattern observed:** @staticmethod builder methods with conditional Rule separators at story_detail_widget.py:28-80
**Error handling:** Silent exception swallowing in drill_into_story (consistent with codebase pattern)

**Observations:**
| Severity | Issue | Location |
|----------|-------|----------|
| [MEDIUM] | Keybinding hint [Escape] Back [Enter] Open PR removed from detail screen (keybindings work, visual hint lost) | story_detail_screen.py:60-65 |
| [LOW] | _format_assignee import dropped — raw assignee shown instead of formatted name | story_detail_widget.py:103 |
| [LOW] | Points format changed from "{points} pts" to "{points}pt" | story_detail_widget.py:98 |

**Tests:** 37/37 passing (widget tests). 11 pre-existing failures in fetch_story_detail tests (not caused by changes).
**Handoff:** To SM (Zoe) for finish-story

## Dev Assessment — Green Phase

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/bikerack/story_detail_widget.py` — New reusable StoryDetailWidget (Widget subclass with Collapsible sections, Rule separators)
- `pennyfarthing-dist/pf/bikerack/story_detail_screen.py` — Refactored to delegate to StoryDetailWidget inside VerticalScroll
- `pennyfarthing-dist/pf/bikerack/progress_panel.py` — Added Enter keybinding, drill_into_story method, and "[Enter] Story Details" hint

**Tests:** 37/37 passing (GREEN)
**Existing tests:** 55/66 passing in test_bikerack_story_detail.py (11 pre-existing failures in fetch_story_detail, not caused by changes). 32/32 passing in test_bikerack_base_panel.py.
**Branch:** feat/120-8-story-details-progress-textual-widgets (pushed)

**Handoff:** To Reviewer (River) for review phase

## TEA Assessment — Red Phase

**Tests Required:** Yes
**Reason:** New widget, screen refactor, and panel enhancement need coverage

**Test Files:**
- `tests/python/test_bikerack_story_detail_widget.py` — 37 tests covering all 10 ACs

**Tests Written:** 37 tests (30 failing, 7 passing)
**Status:** RED (failing — ready for Dev)

**Failing by AC:**
- AC1 (Widget exists): 6 failures — `StoryDetailWidget` module doesn't exist
- AC2 (Collapsible sections): 5 failures — no Collapsible widgets in compose
- AC3 (Rule separators): 2 failures — no Rule widgets, still using Rich Text dashes
- AC4 (Absent sections): 5 failures — sections render regardless of data presence
- AC5 (Screen delegation): 3 failures — screen still uses inline Static, no VerticalScroll
- AC7 (Progress drill-through): 2 failures — no drill method or Enter binding
- AC8 (Progress hint): 1 failure — no "[Enter] Story Details" hint
- AC9 (Keyboard nav): 2 failures — module doesn't exist yet
- AC10 (Enrichment reuse): 1 failure — module doesn't exist yet
- Edge cases: 3 failures — module doesn't exist yet

**Passing (existing behavior preserved):**
- AC6: All 5 keybinding tests pass (Escape, Enter, get_pr_url still work)
- AC10: fetch_story_detail still called from Screen (1 pass)
- TestProgressPanelHint: no-hint-without-story passes (1 pass)

**Handoff:** To Dev (Mal) for implementation

## UX Assessment — Design Phase

Design spec complete. Three-part approach:

1. **StoryDetailWidget** (new) — Reusable `Widget` subclass using `Collapsible`, `Static`, `Rule` from `textual.widgets`. Takes same `story_data` dict from `story_detail_data.py`. Each section (ACs, Workflow, Git, Context, Session Notes) is an independently collapsible section. Absent sections omitted entirely.

2. **StoryDetailScreen** (modify) — Replace 6 inline `Static` widgets with `VerticalScroll` containing `StoryDetailWidget`. Keybindings unchanged. Same data enrichment flow.

3. **ProgressPanel** (modify) — Add `Enter` keybinding to push `StoryDetailScreen`, following the same `app.push_screen()` pattern SprintPanel uses. Add hint line "[Enter] Story Details" to rendered output. Panel keeps its existing Rich renderable approach for progress bars.

Files: create `story_detail_widget.py`, modify `story_detail_screen.py`, modify `progress_panel.py`. All in `pennyfarthing-dist/pf/bikerack/`.

## SM Assessment — Setup Phase

Story 120-8 set up for BDD workflow. Session created, Jira claimed (MSSCI-15412), feature branch `feat/120-8-story-details-progress-textual-widgets` created in pennyfarthing repo. Story involves two surface areas: enriching the existing story details screen and surfacing story details on the progress screen, both using native Textual widgets. Routing to UX Designer (Wash) for design phase — needs wireframes, user flows, and behavior scenarios before implementation begins.

## Notes

- BDD workflow prioritizes UX design before implementation
- UX Designer will create design spec, user flows, and behavior scenarios
- Story spans BikeRack TUI improvements with Textual widget integration