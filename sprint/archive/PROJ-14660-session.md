# Story 94-1: Extend usePersona hook with streaming state

**Story ID:** 94-1
**Jira:** [PROJ-14660](https://slabgorb.atlassian.net/browse/PROJ-14660)
**Epic:** epic-94
**Workflow:** trivial
**Phase:** finish
**PR:** #788 - feat(94-1): extend usePersona hook with streaming state
**Repos:** pennyfarthing
**Branch:** feat/PROJ-14660-persona-streaming-state
**Assigned:** slabgorb@gmail.com

---

## Description

Expose isStreaming flag from usePersona hook reflecting whether the agent is actively generating, so components can react to thinking state. WebSocket delivers persona state updates; defaults to false when inactive.

## Acceptance Criteria

- [ ] usePersona hook exposes `isStreaming: boolean` property
- [ ] isStreaming reflects active generation state from WebSocket persona updates
- [ ] Defaults to `false` when agent is inactive or no persona state received
- [ ] Components consuming usePersona can react to streaming/thinking state changes

---

## SM Assessment

**Routing:** Trivial workflow (2pt) — direct to Dev, skip TEA.
**Story:** Extend usePersona hook to expose `isStreaming` boolean reflecting active generation state.
**Epic context:** Part of epic-94 "Primary Portrait Thinking Indicator" — this is the data layer (94-1), visual indicator follows (94-2).
**Branch:** `feat/PROJ-14660-persona-streaming-state` in pennyfarthing repo.
**Key files:** `packages/cyclist/src/public/hooks/usePersona.ts`, WebSocket persona broadcast in `api/persona.ts`.
**Handoff:** → Dev (Toby Ziegler) for implementation.

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/api/persona.ts` — Added `setStreamingState()` and `getStreamingState()` for module-level streaming state tracking with broadcast to persona WebSocket clients
- `packages/cyclist/src/websocket.ts` — Wired streaming state to Claude message flow in both Electron mode (`broadcastClaudeMessage`/`broadcastClaudeComplete`/`broadcastClaudeError`) and Web mode (per-client `sendMessage` loop)
- `packages/cyclist/src/public/hooks/usePersona.ts` — Added `isStreaming: boolean` to `UsePersonaResult` interface; parses from WebSocket messages (both inline persona payloads and dedicated `streaming` type messages); defaults to `false`; resets on WebSocket disconnect
- `packages/cyclist/src/api/index.ts` — Export new persona functions

**Architecture:** Server-side approach (Option A from epic context). Streaming state tracked as module-level boolean in `persona.ts`, set/cleared by Claude message flow in `websocket.ts`, broadcast to `/ws/persona` clients as either inline `isStreaming` field on persona data or as separate `{ type: 'streaming', isStreaming }` message. No-op guard prevents redundant broadcasts.

**Tests:** 35/35 persona tests passing (GREEN). No new test failures introduced. 29 pre-existing failures in unrelated suites.
**PR:** #788 — feat(94-1): extend usePersona hook with streaming state
**Branch:** feat/PROJ-14660-persona-streaming-state (pushed)

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** REJECTED
| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | CSS layout regression — PersonaHeader portrait and text overflow/clipping visible in Cyclist UI. Badge ("REV") overlaps portrait, quote text is truncated/clipped, and sidebar labels ("clear", "STATUS") are misaligned | `packages/cyclist/src/public/components/PersonaHeader.tsx` + associated CSS | Investigate and fix the layout regression. Ensure portrait, badge, character name, theme label, and quote render correctly without overlap or clipping |

**Data flow traced:** `setStreamingState(true)` in `websocket.ts:337` → `broadcastPersona` spreads `isStreaming` into persona JSON → WS `/ws/persona` → `usePersona.ts:65-72` parses both dedicated `streaming` messages and inline `isStreaming` field → state exposed via hook return. Flow is sound.
**Pattern observed:** No-op guard at `persona.ts:33` prevents redundant broadcasts — good defensive pattern.
**Error handling:** Streaming state cleared on error (`websocket.ts:369`, `websocket.ts:1404`) and on WS disconnect (`usePersona.ts:84`) — correct.
**Observation:** The streaming state data plumbing is clean. However, a CSS layout regression is visible in the PersonaHeader area — portrait clipping, badge overlap, and text truncation. This is a visual defect that must be fixed before merge.

**Handoff:** Back to Dev for CSS layout fix

---

## Dev Assessment (Revision 2 — CSS Fix)

**Fix Applied:** PersonaHeader CSS layout overflow and clipping
**Files Changed:**
- `packages/cyclist/src/public/styles/tailwind.css` — Added `overflow: hidden` and `min-width: 0` to `.persona-header`; changed `.persona-portrait-group` and `.persona-portrait` from `flex-shrink: 0` to `flex-shrink: 1` with `min-width: 48px` and `aspect-ratio: 1` so portrait scales down in narrow panels; changed `.persona-name-row` from `flex-wrap: wrap` to `flex-wrap: nowrap` with `overflow: hidden`; added text truncation (`overflow: hidden`, `text-overflow: ellipsis`, `white-space: nowrap`) to `.persona-character` and `.persona-theme`

**Root cause:** Portrait group and portrait had `flex-shrink: 0`, so when the dockview panel narrowed below the combined content width (~300px), the header overflowed its container causing portrait clipping, badge overlap, and text cutoff.

**Tests:** 35/35 persona tests passing (GREEN). Build passes.
**Branch:** feat/PROJ-14660-persona-streaming-state (pushed)

**Handoff:** To Reviewer for re-review

---

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

**Observations:**
1. `[VERIFIED]` Data flow: `setStreamingState(true)` at `websocket.ts:337` → module boolean at `persona.ts:9` → broadcast via `broadcastPersona()` at `persona.ts:23` and `setStreamingState()` at `persona.ts:32` → WS `/ws/persona` → `usePersona.ts:65-72` parses both message types → hook returns `isStreaming`. Sound.
2. `[VERIFIED]` No-op guard at `persona.ts:33` prevents redundant broadcasts. Good defensive pattern.
3. `[VERIFIED]` Error handling: streaming state cleared on complete (`websocket.ts:354`, `:1398`), error (`websocket.ts:369`, `:1404`), and WS disconnect (`usePersona.ts:84`). All paths covered.
4. `[VERIFIED]` CSS fix: root cause was `flex-shrink: 0` on portrait group/portrait. Changed to `flex-shrink: 1` with `min-width: 48px` floor, `aspect-ratio: 1` for circle, `overflow: hidden` on header. Text truncation added to character/theme. Correct fix.
5. `[LOW]` `overflow: hidden` on `.persona-header` clips `focus-visible` outline (`outline-offset: 2px` at `tailwind.css:302`). Cosmetic a11y — non-blocking, can address separately.
6. `[VERIFIED]` All 4 ACs met. No forbidden patterns. 35/35 persona tests GREEN. Build passes.
7. `[VERIFIED]` Initial persona payload includes `isStreaming` on WS connect at `websocket.ts:554` — new clients get correct state immediately.

**Handoff:** Merging PR #788, then to SM (Leo McGarry) for finish-story

---
