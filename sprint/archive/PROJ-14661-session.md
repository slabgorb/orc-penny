# Session: PROJ-14661 — Apply thinking throbber to PersonaHeader portrait

## Story
- **ID:** 94-2 / PROJ-14661
- **Epic:** 94 — Primary Portrait Thinking Indicator (Baseline Fix)
- **Points:** 2
- **Workflow:** tdd (SM → TEA → Dev → Reviewer → SM)
- **Branch:** feature/PROJ-14661-persona-header-thinking-throbber

## Acceptance Criteria
- [ ] PersonaHeader portrait shows avatar-throb animation when isStreaming is true
- [ ] Animation stops when isStreaming becomes false
- [ ] Works in compact mode (40px portrait)
- [ ] prefers-reduced-motion: static opacity fallback (0.85)
- [ ] No visual regression on existing message avatars

## Phase: finish

## Reviewer Assessment

**Verdict:** APPROVED
**Reviewer:** Josh Lyman (reviewer agent)

**Data flow traced:** Server `setStreamingState()` → WS broadcast `{type:'streaming', isStreaming}` → `usePersona` hook → `PersonaHeader` destructures → `.avatar-thinking` class on `.persona-portrait` div (safe — fully wired end-to-end)

**Observations:**
1. [VERIFIED] 2-line production change — minimal blast radius at `PersonaHeader.tsx:63,126`
2. [VERIFIED] WebSocket disconnect resets `isStreaming` to false at `usePersona.ts:84` — no stuck animation
3. [VERIFIED] CSS class concatenation order correct — `avatar-thinking` and `avatar-observation-pulse` coexist safely
4. [VERIFIED] `prefers-reduced-motion` fallback at `tailwind.css:877-882` applies to all `.avatar-thinking` consumers
5. [VERIFIED] Message.tsx uses independent `isStreaming` from `useMessageStream` — no regression path
6. [LOW] Dual animation overlap (thinking + observation-pulse) resolves correctly — pulse is one-shot, thinking resumes after
7. [VERIFIED] Empty persona early-return at line 107 prevents spurious animation — portrait div doesn't exist

**Tests:** 14/14 new, 35/35 regression — all passing
**Handoff:** To SM for finish-story
