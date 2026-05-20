# Story 86-3: Dialogue file management

**Story ID:** 86-3
**Jira:** [PROJ-14498](https://slabgorb.atlassian.net/browse/PROJ-14498)
**Epic:** 86 — Agent Collaboration — Tandem to Teams
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Assignee:** Keith Avery
**Repos:** pennyfarthing
**Branch:** feat/86-3-dialogue-file-management

---

## Acceptance Criteria

1. Dialogue file created at `.session/{story-id}-dialogue.md` on first consultation
2. Each exchange appended with: timestamp, agents, question summary, response, outcome
3. Outcome tracked: applied / deferred / rejected
4. Summary section auto-generated: total exchanges, key decisions, time in tandem
5. Dialogue file archived alongside session file on story completion
6. Dialogue file readable by Reviewer for audit

---

## Technical Context

Story 86-2 delivered the consultation protocol (`packages/core/src/consultation/consultation-protocol.ts`). Story 86-3 adds the persistence layer: creating, appending, and archiving dialogue files that record all consultation exchanges. ADR-0012 defines the exact file format.

### Key Files
- `packages/core/src/consultation/dialogue-manager.ts` — Core TypeScript module (pure functions)
- `packages/core/src/consultation/dialogue-manager.test.ts` — Tests (42 tests)
- `pennyfarthing-dist/scripts/core/dialogue-manager.sh` — Shell wrapper for agents
- `pennyfarthing_scripts/sprint/story_finish.py` — Updated with dialogue archival step

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Persistence layer with file I/O, parsing, and archival — tests essential

**Test Files:**
- `packages/core/src/consultation/dialogue-manager.test.ts` — 42 tests covering all 6 ACs

**Tests Written:** 42 tests covering 6 ACs + result format compliance
**Status:** GREEN (pre-implemented — tests and implementation delivered together)

**AC Coverage:**
- AC1: 6 tests (file creation, header, character names, auto-init)
- AC2: 9 tests (exchange format, timestamp, agents, question, response, ordering)
- AC3: 6 tests (applied/deferred/rejected outcomes, error cases)
- AC4: 7 tests (summary count, key decisions, time calculation, refresh)
- AC5: 5 tests (archive copy, naming fallback, content preservation, dir creation)
- AC6: 5 tests (well-formed markdown, round-trip parse, field parsing)
- Result format: 4 tests ({success, data?, error?} compliance)

**Note:** Both tests and implementation were pre-written. No RED state was necessary — verified GREEN with 42/42 passing, 0 regressions on consultation-protocol (37/37).

**Handoff:** To Dev (Jack Torrance) — implementation already complete, fast-track to review

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/consultation/dialogue-manager.ts` — Pure functions: create, format, parse, summary, append, update, refresh, archive
- `packages/core/src/consultation/dialogue-manager.test.ts` — 42 tests covering all 6 ACs
- `pennyfarthing-dist/scripts/core/dialogue-manager.sh` — Shell wrapper (init/append/outcome/summarize/archive)
- `pennyfarthing_scripts/sprint/story_finish.py` — Step 1b: dialogue archival alongside session archive

**Tests:** 42/42 passing (GREEN) + 37/37 consultation-protocol (no regressions)
**PR:** #926 - feat(consultation): dialogue file management (86-3)
**Branch:** feat/86-3-dialogue-file-management (pushed)

**Handoff:** To Reviewer (Roland Deschain) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 42/42 passing, 0 regressions (37/37 consultation-protocol)
**Lint:** Clean (1 LOW unused param)
**TypeScript:** Compiles clean

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | VERIFIED | ADR-0012 format compliance with reasonable extensions | `dialogue-manager.ts:73-119` |
| 2 | VERIFIED | Result format `{success, data?, error?}` on all IO functions | `dialogue-manager.ts:267-407` |
| 3 | VERIFIED | Data flow round-trip: create → append → disk → parse | `dialogue-manager.test.ts:582-598` |
| 4 | VERIFIED | Error handling — all paths return result objects, never throw | `dialogue-manager.ts:273-347` |
| 5 | VERIFIED | story_finish.py — dialogue archival as Step 1b, graceful skip | `story_finish.py:+129-161` |
| 6 | VERIFIED | Shell wrapper — strict mode, outcome validation, deps exist | `dialogue-manager.sh:14-322` |
| 7 | MEDIUM | `refreshSummary()` drops content after Summary marker (OK today) | `dialogue-manager.ts:369-376` |
| 8 | MEDIUM | Sync fs in async functions — fine for CLI, latent server trap | `dialogue-manager.ts:267-407` |
| 9 | LOW | Unused `startedAt` param in `generateSummary()` | `dialogue-manager.ts:232` |
| 10 | LOW | Shell `echo -e` portability — prefer `printf '%b'` | `dialogue-manager.sh:268` |

**Handoff:** To SM (Johnny Smith) for finish-story