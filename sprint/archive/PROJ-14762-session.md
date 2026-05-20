# Session: PROJ-14762 — Quick agent picker in control bar

## Story
- **ID:** PROJ-14762 (100-2)
- **Epic:** 100 — UI Tweak Bucket
- **Points:** 3
- **Workflow:** TDD
- **Branch:** `feature/PROJ-14762-quick-agent-picker` (pennyfarthing repo)
- **Repo:** pennyfarthing

## Acceptance Criteria
1. A compact agent picker control appears in the ControlBar, positioned **before** the Bell Mode toggle
2. The picker uses an appropriate Lucide icon as its trigger button
3. Clicking the picker opens a lightweight dropdown listing available agents (role + character name)
4. Selecting an agent from the dropdown sends the `/{role}` command to switch agents
5. The picker updates in real-time when the active agent changes (via WebSocket persona updates)
6. The existing AgentPopup (via PersonaHeader click) continues to work unchanged
7. Tests cover: rendering, dropdown open/close, agent selection, real-time updates

## Design Notes
- **Icon:** Use an appropriate Lucide icon (e.g., `Users`, `UserCog`, or `Contact`) — placed before Bell Mode in the toggles section
- **Dropdown:** Lightweight popover/dropdown, NOT a full modal like AgentPopup
- **Data source:** Same `/api/theme-agents/full` endpoint used by AgentPopup
- **Agent switch:** Send `/{agent.role}` via `useClaudeContext().send()` — same mechanism as AgentPopup

## Key Files
| File | Purpose |
|------|---------|
| `packages/cyclist/src/public/components/ControlBar.tsx` | Control bar — add picker here |
| `packages/cyclist/src/public/components/AgentPopup.tsx` | Existing full agent popup (reference) |
| `packages/cyclist/src/public/components/PersonaHeader.tsx` | Current persona display (reference) |
| `packages/cyclist/src/public/components/panels/MessagePanel.tsx` | Parent layout |
| `packages/cyclist/src/public/hooks/usePersona.ts` | Persona WebSocket hook |
| `packages/cyclist/src/public/contexts/ClaudeContext.tsx` | Claude send() for agent switching |
| `packages/cyclist/src/public/styles/tailwind.css` | Styles |

## TEA Notes
- **Test file:** `packages/cyclist/tests/PROJ-14762-agent-quick-picker.test.tsx`
- **Red state:** 14 fail / 3 pass (3 passing = existing controls regression tests)
- **Test groups:**
  - `rendering and position` — picker exists, positioned before Bell Mode (2 tests)
  - `icon` — Lucide SVG icon in button (1 test)
  - `dropdown open/close` — click open, toggle close, Escape, outside click (5 tests)
  - `agent selection` — sends `/{role}`, current agent marked (2 tests)
  - `real-time updates` — reflects `currentAgent` prop changes (1 test)
  - `existing controls` — bell, relay, stop/reset unchanged (3 tests, PASS)
  - `accessibility` — aria-label, aria-expanded, listbox/option roles (3 tests)
- **Key test IDs expected:** `agent-quick-picker`, `agent-quick-picker-dropdown`, `agent-option-{role}`
- **Data source:** Tests mock `fetch('/api/theme-agents/full')` returning agent roster
- **Run command:** `cd packages/cyclist && npx vitest run tests/PROJ-14762-agent-quick-picker.test.tsx`

## Dev Notes
- **Files modified:**
  - `packages/cyclist/src/public/components/ControlBar.tsx` — added `AgentQuickPicker` component, `onAgentSwitch` prop, `handleAgentSwitch` in hook
  - `packages/cyclist/src/public/styles/tailwind.css` — dropdown styles
- **Icon:** `UserCog` from lucide-react
- **Architecture:** Picker is a self-contained function component inside ControlBar.tsx. Fetches `/api/theme-agents/full` on mount. Agent switch delegated via `onAgentSwitch` prop (avoids requiring ClaudeProvider in all ControlBar consumers). `useControlBar` hook provides `handleAgentSwitch` that calls `send("/{role}")`.
- **Tests:** 17/17 pass, full suite 2408/2408 pass

## Reviewer Notes
- **Verdict:** APPROVE with fix applied
- **Fix applied:** MessagePanel was not wiring `handleAgentSwitch` / `onAgentSwitch` — picker rendered but clicking agents was a no-op. Fixed by adding destructure + prop pass-through.
- **Files modified by reviewer:** `packages/cyclist/src/public/components/panels/MessagePanel.tsx`
- **Full suite:** 2408 pass (2 flaky pre-existing failures in `PROJ-14204-agent-popup-polish` intermittently appear in full run but pass in isolation — not related to this change)

### Review Checklist
- [x] AC1: Picker before Bell Mode — confirmed via DOM order test + code inspection
- [x] AC2: Lucide icon (UserCog) — correct
- [x] AC3: Lightweight dropdown, not modal — confirmed (conditional render, absolute positioned)
- [x] AC4: Sends `/{role}` — `onAgentSwitch` → `handleAgentSwitch` → `send("/{role}")` (now wired correctly)
- [x] AC5: Real-time updates — `currentAgent` prop flows from `useControlBar` persona WS → picker
- [x] AC6: Existing controls unchanged — regression tests pass
- [x] AC7: Tests cover all behaviors — 17 tests across 7 groups
- [x] Escape handling: Uses capture phase (`true`) to close dropdown before ControlBar's stop handler fires — correct priority
- [x] Outside click: `mousedown` listener with `contains()` check — standard pattern
- [x] No ClaudeProvider dependency in ControlBar component itself — good, avoids breaking existing consumers
- [x] Silently swallows fetch errors for agent list — acceptable for UI polish feature
- [x] CSS uses theme variables with fallbacks — correct

## Phase
- [x] SM: Story setup, context, branch
- [x] TEA: Test strategy and red tests
- [x] Dev: Implementation (green tests)
- [x] Reviewer: Code review
- [x] SM: Finish — PR #803, story done
