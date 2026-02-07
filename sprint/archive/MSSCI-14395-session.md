# Session: MSSCI-14395

**Story:** Render AskUserQuestion tool via Reflector QuickActions
**Epic:** epic-78 — Cyclist Permission System
**Points:** 3 | **Priority:** P1
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** `feature/MSSCI-14395-ask-user-question-reflector`
**Assignee:** keithavery
**Jira:** MSSCI-14395

## Problem

When Claude uses the `AskUserQuestion` tool, Cyclist renders it as a generic collapsed ToolCallBlock with raw JSON. The user has no way to select an answer — the interactive options are invisible.

## Goal

Detect `AskUserQuestion` tool_use messages in the stream and render them through the existing Reflector QuickActions UI, so users can click option buttons to respond.

## Acceptance Criteria

- [ ] AskUserQuestion tool_use renders interactive buttons instead of collapsed JSON
- [ ] Single-select questions show clickable option buttons
- [ ] Multi-select questions show checkboxes or toggleable buttons
- [ ] User selection is sent back to Claude via WebSocket as a message
- [ ] Existing Reflector marker QuickActions continue to work unchanged
- [ ] ToolCallBlock still renders normally for all other tool types

## Technical Approach

Use the existing Reflector/QuickActions infrastructure:

1. **Detection:** In MessageView or ToolCallBlock, detect when a tool_use has `tool_name === "AskUserQuestion"`
2. **Conversion:** Convert the tool input's `questions[].options` array into the QuickActions button format
3. **Rendering:** Render through existing QuickActions component (same as CYCLIST:CHOICES markers)
4. **Response:** User clicks → response sent via `/ws/claude` WebSocket (same path as marker responses)

### Key Files

- `packages/cyclist/src/public/components/QuickActions.tsx` — Existing button rendering
- `packages/cyclist/src/public/hooks/useMarkerActions.ts` — Marker → action conversion
- `packages/cyclist/src/public/components/ToolCallBlock.tsx` — Generic tool rendering
- `packages/cyclist/src/public/components/MessageView.tsx` — Message display + QuickActions mount point

### Data Flow

```
Claude CLI stdout → tool_use {name: "AskUserQuestion", input: {questions: [...]}}
  → MessageView detects AskUserQuestion tool_use
  → Renders QuickActions-style buttons instead of ToolCallBlock
  → User clicks option
  → Response sent via /ws/claude WebSocket
  → Claude receives as next user message
```

## Status Log

| Time | Agent | Action |
|------|-------|--------|
| — | SM | Story created, session setup |
| — | TEA | 20 failing tests written (RED state confirmed) |
| — | Dev | Implementation complete, 20/20 tests GREEN, PR #706 |
| — | Reviewer | APPROVED — 10 observations, no blocking issues, merged |

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (16 failing, 4 passing — stubs throw, source assertions fail)

**Test Files:**
- `packages/cyclist/tests/MSSCI-14395-ask-user-question-reflector.test.tsx` — 20 tests covering all 6 ACs

**Stubs Created:**
- `packages/cyclist/src/public/components/AskUserQuestionBlock.tsx` — Component stub (throws)
- `packages/cyclist/src/public/utils/askUserQuestion.ts` — Utility stub (throws)

**Tests Written:** 20 tests covering 6 ACs
- AC1 (3 tests): Detect AskUserQuestion in MessageView, render question text
- AC2 (4 tests): Single-select buttons, descriptions, headers, disable after click
- AC3 (3 tests): Multi-select toggle, submit button, toggle on/off
- AC4 (3 tests): Send single-select via WebSocket, send multi-select, no auto-execute
- AC5 (3 tests): Existing yesno/choices/handoff markers still work
- AC6 (4 tests): Other tools still use ToolCallBlock, isAskUserQuestion utility

**Implementation Guidance for Dev:**
1. Implement `isAskUserQuestion()` in `utils/askUserQuestion.ts` — simple `tool_name === 'AskUserQuestion'` check
2. Implement `AskUserQuestionBlock` component — render question text, option buttons, handle single/multi-select
3. Modify `MessageView.tsx` to intercept AskUserQuestion tool_use and render AskUserQuestionBlock instead of ToolCallBlock
4. Wire up `useClaudeContext().send()` for sending responses back

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation:** Complete
**Tests:** 20/20 passing (GREEN)
**PR:** https://github.com/1898andCo/pennyfarthing/pull/706

**Files Changed:**
- `packages/cyclist/src/public/utils/askUserQuestion.ts` — `isAskUserQuestion()` utility
- `packages/cyclist/src/public/components/AskUserQuestionBlock.tsx` — Interactive question renderer
- `packages/cyclist/src/public/components/MessageView.tsx` — Intercepts AskUserQuestion before ToolCallBlock

**Approach:** Minimal. Three files touched. Component uses existing Button/Badge from shadcn, existing ClaudeContext for WebSocket send. No new dependencies.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** AskUserQuestion tool_use → MessageView intercept → AskUserQuestionBlock render → user click → send() via ClaudeContext WebSocket → Claude receives. Safe, same path as QuickActions.
**Pattern observed:** Clean early-return branch before ToolCallBlock at MessageView.tsx:231. Follows existing component patterns (shadcn Button/Badge, useClaudeContext).
**Error handling:** Null-safe with `toolUse.input?.questions || []`. Multi-select submit disabled when empty. Buttons disabled after selection.
**Security:** No injection vectors. React auto-escapes text content. No dangerouslySetInnerHTML.
**Observations:** 10 items reviewed (5 verified good, 2 low, 1 medium, 0 high/critical).
**Handoff:** To SM for finish-story
