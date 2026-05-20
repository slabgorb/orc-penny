# Story 103-17: DebugPanel (log viewer)

**Jira:** PROJ-14972
**Epic:** BikeRack TUI — Terminal-Native Dashboard
**Points:** 1
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/103-17-debugpanel-log-viewer

## Description

Port the React DebugPanel to BikeRack TUI. The React DebugPanel (`packages/core/src/public/components/panels/DebugPanel.tsx`) is a context usage dashboard that displays health gauge, context tier, token stats, and sparkline. Port the key data displays to Rich renderables in the TUI.

## Functional Requirements

- FR20: DebugPanel — context usage and token stats display (ported from React)

## Technical Context

### Source: React DebugPanel

**File:** `pennyfarthing/packages/core/src/public/components/panels/DebugPanel.tsx`

The React DebugPanel subscribes to TWO WebSocket channels:
1. **`/ws/context`** — Context usage data (tokens, percent, tier, tokenCounts, baseline, available)
2. **`/ws/token-stats`** — Token consumption stats (inputTokens, outputTokens, cacheReadTokens, cacheCreationTokens, totalCostUsd)

Key features to port:
- **Context usage bar** — tokens used / total, percentage
- **Context tier badge** — FULL, REFRESH, HANDOFF, MINIMAL with savings %
- **Token stats** — input, output, cache read, cache write, cost
- **Component breakdown** — per-component token counts (collapsible in React, can be simplified for TUI)

Features NOT to port (too complex for TUI / not applicable):
- HealthGauge with drill-down dialogs (hotspots, complexity, dead code, etc.)
- ContextSparkline (SVG-based)
- Interactive dialog popups

### TUI Implementation Pattern

Extends BasePanel like other BikeRack panels. Since this needs TWO channels, it may need to subscribe to both `context` and `token-stats` in `on_mount()`.

**Reference:** `pennyfarthing/pennyfarthing_scripts/bikerack/changed_panel.py` for the BasePanel pattern.

### Tier Color Mapping (Rich styles)

- `FULL` → `"bold green"`
- `REFRESH` → `"bold yellow"`
- `HANDOFF` → `"bold cyan"`
- `MINIMAL` → `"bold red"`

## Acceptance Criteria

- [ ] DebugPanel extends BasePanel, registered in BikeRack TUI
- [ ] Subscribes to `/ws/context` — displays tokens, percent, tier
- [ ] Subscribes to `/ws/token-stats` — displays input/output/cache/cost
- [ ] Tier badge with color coding
- [ ] Token stats formatted with locale separators
- [ ] Empty states for missing data
- [ ] Tests pass

## SM Assessment

Story 103-17 is a straightforward 1-point panel implementation following the proven BasePanel pattern from 103-14 (ChangedPanel). All context is loaded — epic context, technical patterns, WebSocket channel contract, and color mapping. 1-point TDD story — skipping TEA, routing directly to Dev for implementation.

**Handoff:** SM → Dev (implement phase)
**Routing:** 1-pt story, skip TEA per DEC-SM-001

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/debug_panel.py` — DebugPanel ported from React, dual-channel subscription (context + token-stats), Rich renderables for tier badges, token counts, cost display
- `tests/python/test_bikerack_debug_panel.py` — 35 tests covering all ACs (existence, subscriptions, rendering, tier colors, formatting, empty states, error handling, combined view)

**Tests:** 35/35 passing (GREEN) + 114 existing panel tests (no regressions)
**PR:** #900 — feat(103-17): DebugPanel for BikeRack TUI
**Branch:** feature/103-17-debugpanel-log-viewer (pushed)

**Design notes:**
- Overrides `on_mount()` to subscribe to both `context` and `token-stats` channels (BasePanel only supports one)
- Internal `_handle_context_message` / `_handle_token_stats_message` handlers store data, then `_rerender()` combines both sources
- Skipped HealthGauge, ContextSparkline, and dialog popups (not applicable to TUI)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Observation | Location |
|----------|-------------|----------|
| [MEDIUM] | Custom handlers skip `_mounted` guard (consistent with BasePanel pattern) | `debug_panel.py:79,90` |
| [LOW] | `render_panel(payload)` ignores payload, reads instance state | `debug_panel.py:105` |
| [LOW] | Unused `call` import | `test_bikerack_debug_panel.py:25` |
| [LOW] | HANDOFF tier untested (3 of 4 covered) | test fixtures |
| [VERIFIED] | Data flow: WS → handler → state → rerender → Rich renderables | end-to-end |
| [VERIFIED] | Error handling: `_safe_int`/`_safe_float` handle all edge cases | `debug_panel.py:27-44` |
| [VERIFIED] | Empty states: placeholder text renders correctly | `debug_panel.py:113,207` |
| [VERIFIED] | Security: all values sanitized before display | `debug_panel.py` |
| [VERIFIED] | Pattern compliance: BasePanel, PANEL_ICONS, panel_name | `debug_panel.py:63-65` |
| [VERIFIED] | Dual-channel wiring: both subscriptions in on_mount | `debug_panel.py:72-77` |

**Data flow traced:** WS context → `_handle_context_message` → `_context_data` → `_render_context()` → Rich Text/Table. Clean.
**Pattern observed:** Dual-channel BasePanel extension — novel but well-structured at `debug_panel.py:72-77`
**Error handling:** `_safe_int`/`_safe_float` converters + bare except in `_rerender()` (matches BasePanel pattern)

**Handoff:** To SM for finish-story
