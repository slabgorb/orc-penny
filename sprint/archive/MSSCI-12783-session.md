# Story Session: MSSCI-12783

**Story:** Bug: Skill Content Displayed as User Message
**Epic:** Epic 64 - Cyclist UX Polish (MSSCI-12764)
**Points:** 2
**Priority:** P1
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** fix/MSSCI-12783-skill-content-display-bug
**Jira:** MSSCI-12783

## Problem Statement

When skills are loaded/read, the full skill markdown content is displayed in the message view as a user message. This spams the conversation with internal context that should be hidden.

**Example:** Loading `/sprint` skill shows the entire skill file content in a blue user message bubble.

**Expected:** Skill loading should be silent or show only a brief indicator (e.g., "Loaded /sprint skill"). The full content is for Claude's context, not user display.

## Acceptance Criteria

- [ ] Skill content is NOT displayed as user messages in the conversation
- [ ] Skill loading may show a brief indicator or be silent
- [ ] Skill content is still available to Claude's context (via --append-system-prompt or similar)
- [ ] No regression in skill functionality

## Technical Context

The issue likely involves how Cyclist processes messages that contain skill content. When the Skill tool is invoked, the skill markdown gets injected but appears in the UI as a user message.

Key areas to investigate:
- Message classification/filtering in Cyclist
- How skill content arrives (via user message vs system prompt)
- Message rendering logic that determines what to display

## Files to Investigate

- `packages/cyclist/src/public/components/Message.tsx` - Message rendering
- `packages/cyclist/src/api/` - API message handling
- Skill loading mechanism

## TEA Assessment

**Tests Required:** Yes
**Reason:** Bug fix requires verification that skill content is properly filtered

**Test Files:**
- `packages/cyclist/tests/MSSCI-12783-skill-content-filter.test.tsx` - Skill content filtering tests

**Tests Written:** 23 tests covering all 4 ACs
- AC1: 6 tests for skill content NOT displayed as user messages
- AC2: 2 tests for skill loading indicator behavior
- AC3: 1 test for skill functionality preservation
- AC4: 5 tests for normal message display (no regression)
- Utility: 8 tests for isSkillContent helper function
- Integration: 1 test for transformMessage filtering

**Status:** RED (15 failing, 8 passing - ready for Dev)

**Implementation Guidance:**
1. Create `isSkillContent(content: string): boolean` utility in `src/public/utils/messageFilters.ts`
2. Skill content markers to detect:
   - `<command-message>` and `<command-name>` tags
   - `Base directory for this skill:` prefix
   - `Launching skill:` prefix
3. Integrate filtering into `MessageView.tsx` or `MessagePanel.tsx transformMessage()`
4. Ensure normal user messages mentioning "skill" are NOT filtered

**Handoff:** To Dev (Inigo Montoya) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/utils/messageFilters.ts` - New utility with isSkillContent() function
- `packages/cyclist/src/public/components/MessageView.tsx` - Integrated filtering in groupedContent useMemo
- `packages/cyclist/tests/MSSCI-12783-skill-content-filter.test.tsx` - Updated to use real utility

**Tests:** 23/23 passing (GREEN)
**PR:** #598 - fix(cyclist): filter skill content from user message display
**Branch:** fix/MSSCI-12783-skill-content-display-bug (pushed)

**Handoff:** To Reviewer (Westley) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data Flow Traced:** `messages[]` → `groupedContent useMemo` → `isSkillContent(msg.content)` → filter/skip
- Safe because: render-time filtering, original array unmodified

**Pattern Observed:** Clean utility function with marker array at `messageFilters.ts:14-19`
- Uses `String.includes()` for each marker - simple, safe, no ReDoS risk

**Error Handling:** Proper null/undefined handling at `messageFilters.ts:28-31`
- Returns `false` for falsy or non-string inputs

**Security:** No XSS risk (no `dangerouslySetInnerHTML`), no secrets

**Observations:**
| Severity | Issue | Location |
|----------|-------|----------|
| [LOW] | Unused `filterSkillContentMessages` export | messageFilters.ts:42-55 |
| [MEDIUM] | Test fixture defines 5 markers, impl has 4 | Docs mismatch only |

**No Critical or High issues found.**

**PR #598 merged and branch deleted.**

**Handoff:** To SM (Vizzini) for finish-story

## Session Log

- **2026-02-01:** Story setup by SM (Vizzini)
- **2026-02-01:** TEA (Fezzik) wrote 23 failing tests, confirmed RED state
- **2026-02-01:** Dev (Inigo Montoya) implemented fix, all tests GREEN, PR #598 created
- **2026-02-01:** Reviewer (Westley) APPROVED, merged PR #598
