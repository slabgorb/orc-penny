# Story 120-1: Story detail screen: markdown preview with context and session

**Jira:** PROJ-15397
**Branch:** feature/120-1-story-detail-markdown-preview
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** finish
**Points:** 3
**Assignee:** slabgorb@gmail.com
## Story Context

Enhance the BikeRack TUI StoryDetailScreen to show a rich markdown preview panel with story information, epic/story context files (sprint/context/), and session notes (.session/). Currently the detail screen shows structured metadata but doesn't render the actual context or session markdown content. Add a scrollable markdown preview section that loads and renders context-epic-N.md, context-story-ID.md, and the session file when available.

## Acceptance Criteria

- [ ] Add markdown preview section to StoryDetailScreen layout
- [ ] Load and render context-epic-N.md if available
- [ ] Load and render context-story-ID.md if available
- [ ] Load and render session file (.session/{story-id}-session.md) if available
- [ ] Markdown content is scrollable within the detail screen
- [ ] Preview section gracefully handles missing files (no errors, just skip)
- [ ] Preview integrates with existing dossier layout (header, AC, workflow, git info)

## Technical Context

### Current Architecture

**StoryDetailScreen** (`/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/pf/bikerack/story_detail_screen.py`):
- Textual Screen extending the Textual TUI framework
- Already renders dossier layout with sections: header, context checkboxes, AC checklist, workflow, git info, session notes
- Uses Rich Text widgets for styled output
- Accepts story_data dict with enriched story metadata (points, status, jiraKey, workflow, branch, PR URL, etc.)
- Has bindings: Escape (pop_screen), Enter (open_pr_link)

**Story Detail Data** (`/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/pf/bikerack/story_detail_data.py`):
- `fetch_story_detail(story_id)` enriches story data from session files and context files
- `_find_session_file(story_id)` locates {story-id}-session.md at .session/{story-id}-session.md
- `_parse_session_file(session_path)` extracts metadata fields (title, phase, workflow, branch, jira, points, ACs, session notes)
- `_check_context_files(story_id)` detects epic and story context files at sprint/context/context-epic-N.md and context-story-ID.md
- Returns dict with has_epic_context, has_story_context, epic_context_path, story_context_path

### Key Patterns

1. **File Discovery**: Story detail data module already locates context files and session files. New code should reuse `_check_context_files()`, `_find_session_file()`, and file loading logic.

2. **Textual Widgets**: Current layout uses `Static(Text(...))` widgets. For markdown preview, consider:
   - `RichLog` for scrollable markdown rendering with Rich library
   - `Static(Markdown(...))` if Textual supports markdown directly
   - Manual parsing with Rich Markdown class

3. **Context Files**: Structure is `sprint/context/context-epic-{EPIC_ID}.md` and `context-story-{STORY_ID}.md`
   Files contain markdown narrative context for development.

4. **Session File**: Located at `.session/{STORY_ID}-session.md`, contains story metadata (frontmatter) + acceptance criteria + session log sections.

### Related Stories & Tests

- **Story 110-2**: Story drill-through with dossier detail screen (original feature — already implemented)
- **Tests**: `/Users/keithavery/Projects/pf-1/pennyfarthing/tests/python/test_bikerack_story_detail.py` — comprehensive test suite for StoryDetailScreen and fetch_story_detail

### Implementation Notes

- Markdown rendering: Textual doesn't have native markdown support. Use Rich's `Markdown` class parsed into renderable Text objects, or use a markdown library like `mistune` + Rich for rendering.
- Scrolling: Wrap markdown preview in a Textual container with overflow handling (e.g., Static with max-height, or use a ScrollableContainer if available)
- Error handling: If context or session files fail to load, gracefully skip that section (don't error)
- Integration: Add markdown preview section between AC checklist and workflow section in current dossier layout

## SM Assessment

**Setup complete.** Story 120-1 claimed in Jira (PROJ-15397), branch `feature/120-1-story-detail-markdown-preview` created off develop in pennyfarthing repo.

**Technical approach:** Extend existing `StoryDetailScreen` with a scrollable markdown preview section. Reuse `_check_context_files()` and `_find_session_file()` from `story_detail_data.py` for file discovery. Render markdown content using Textual's `Markdown` widget or Rich's `Markdown` class. Graceful fallback when files don't exist.

**Risk:** Low. Existing infrastructure handles file discovery. Main work is layout integration and markdown rendering. 3 points appropriate for TDD.

**Routing:** TEA (Jayne) designs tests first per TDD workflow.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Feature story with 7 ACs requiring data layer changes and UI additions

**Test Files:**
- `tests/python/test_story_detail_markdown_preview.py` - 32 tests covering all 7 ACs

**Tests Written:** 32 tests covering 7 ACs
**Status:** RED (24 failing on assertions, 8 passing edge cases — confirmed)

**Test Strategy:**
- **Data layer (AC2-4, AC6):** Tests verify `fetch_story_detail()` returns three new content fields: `epic_context_content`, `story_context_content`, `session_file_content`. Tests use `tmp_path` fixtures with real files to verify content loading, empty defaults, partial availability, and unreadable file handling.
- **UI layer (AC1, AC5, AC7):** Tests verify `compose()` yields a `dossier-preview` widget (VerticalScroll container) with rendered markdown content. Tests check preview appears alongside existing sections (header, AC, workflow, git) and before the hint.
- **Key implementation guidance for Dev:**
  1. Add content loading to `fetch_story_detail()` — read files at paths returned by `_check_context_files()`, read raw session file content
  2. Add three `setdefault()` calls for new fields: `epic_context_content`, `story_context_content`, `session_file_content` (default: `""`)
  3. Add `VerticalScroll` section to `compose()` with id `dossier-preview` — render content via Rich `Markdown` or `Static(Text(...))` widgets inside the scrollable container
  4. Only yield the preview section when at least one content field is non-empty

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/bikerack/story_detail_data.py` - Added content loading for epic context, story context, and session file into three new fields with graceful error handling and empty-string defaults
- `pennyfarthing-dist/pf/bikerack/story_detail_screen.py` - Added `_PreviewBlock` widget (renders without app context), `_MarkdownPreview` (VerticalScroll subclass with compose() override), preview section in compose() yielding scrollable container with id "dossier-preview". Fixed _enrich merge to respect empty strings as intentional values.

**Tests:** 32/32 passing (GREEN)
**Branch:** feature/120-1-story-detail-markdown-preview (pushed)

**Handoff:** To Reviewer for code review

## TEA Verification

**Tests Verified:** 32/32 passing (GREEN confirmed)
**Test File:** `tests/python/test_story_detail_markdown_preview.py`

**Coverage by AC:**
- AC1 (Preview section): 3 tests — compose yields `dossier-preview`, omits when empty, renders with session-only
- AC2 (Epic context): 5 tests — content returned, non-empty string, contains file text, empty when missing, rendered in preview
- AC3 (Story context): 5 tests — content returned, non-empty string, contains file text, empty when missing, rendered in preview
- AC4 (Session file): 5 tests — content returned, non-empty string, contains raw markdown, empty when missing, rendered in preview
- AC5 (Scrollable): 2 tests — preview is VerticalScroll, contains child widgets
- AC6 (Graceful missing): 5 tests — no crash on missing files, defaults to empty string, skips preview when empty, partial content renders, unreadable file handled
- AC7 (Layout integration): 3 tests — existing sections preserved, preview before hint, all three content types in preview

**Implementation Review:**
- Data layer: proper try/except with empty-string fallback, setdefault ensures all three content keys exist
- Screen: `_PreviewBlock` renders without app context (testable), `_MarkdownPreview` extends VerticalScroll for scrollability
- Merge logic: `_enrich` respects empty strings as intentional values (won't overwrite with enriched data)

**Verdict:** GREEN verified. Ready for Reviewer.
**Handoff:** To Reviewer (River) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Review Verdict:** approved
**Review Findings:** Clean implementation, no critical or high issues

**Data flow traced:** Sprint panel story dict → `_enrich()` → `fetch_story_detail()` reads files → content fields → `compose()` → `_MarkdownPreview(VerticalScroll)` → `_PreviewBlock.render()`. Paths built internally, no injection risk.

**Observations:**

| Severity | Issue | Location |
|----------|-------|----------|
| [VERIFIED] | Error handling: try/except with empty-string fallback on all reads | `story_detail_data.py:234-253` |
| [VERIFIED] | Security: no path injection, Rich Text (not HTML) | `story_detail_data.py:174-186` |
| [VERIFIED] | Wiring: both sprint_panel call sites pass raw story dict, _enrich loads content | `sprint_panel.py:437,490` |
| [VERIFIED] | Regression: 11 pre-existing failures confirmed (stash test), zero new regressions | `test_bikerack_story_detail.py` |
| [VERIFIED] | Pattern: _PreviewBlock renders without app context, clean testability | `story_detail_screen.py:19-38` |
| [MEDIUM] | _enrich merge change removes `val != ""` — verified safe for current call sites | `story_detail_screen.py:78` |
| [LOW] | No file size limit on content reads — acceptable for TUI context files | `story_detail_data.py:234-253` |

**Tests:** 32/32 new tests pass. 55/66 existing tests pass (11 failures pre-existing).

**Handoff:** To Zoe (SM) for finish-story