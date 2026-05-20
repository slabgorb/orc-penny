# Story 132-2: Add Welcome Banner Discovery Nudge

## Story Details
- **ID:** 132-2
- **Jira:** PROJ-15618
- **Title:** Add Welcome Banner Discovery Nudge
- **Points:** 1
- **Epic:** 132 / PROJ-15616 (Developer Discovery & Onboarding)
- **Workflow:** trivial
- **Assignee:** Keith Avery

## Acceptance Criteria
- Welcome banner displays on first session launch for new users
- Banner includes nudge to explore getting started guide
- Nudge dismissible without blocking access to framework
- Configurable via config file (optional)

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-25T12:07:24Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-25T11:39:00Z | 2026-02-25T11:39:49Z | 49s |
| implement | 2026-02-25T11:39:49Z | 2026-02-25T11:51:40Z | 11m 51s |
| review | 2026-02-25T11:51:40Z | 2026-02-25T12:01:27Z | 9m 47s |
| implement | 2026-02-25T12:01:27Z | 2026-02-25T12:04:45Z | 3m 18s |
| review | 2026-02-25T12:04:45Z | 2026-02-25T12:07:24Z | 2m 39s |
| finish | 2026-02-25T12:07:24Z | - | - |

## Context
- Trivial workflow: SM → Dev → Reviewer → SM
- Skips TEA (no tests required for 1pt story)
- Next phase: implement (Dev)
- Repository: pennyfarthing
- Branch: feat/132-2-welcome-banner-nudge

## SM Assessment — Setup Phase

**Status:** Ready for Dev

Story is straightforward — 1pt trivial workflow. Add a discovery nudge to the welcome banner that points new users toward the getting started guide. Session created, branch ready, Jira claimed.

**Routing:** SM → Dev (Ponder Stibbons) → Reviewer → SM
**Key ACs:** Dismissible nudge, configurable, no blocking behavior.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/hooks/__init__.py` - Added `discovery_nudge` field to CyclistSettings, config loading from `workflow:` section
- `pennyfarthing-dist/src/pf/hooks/session_start.py` - Added nudge display logic with persistent marker, CLI tip line, Cyclist API payload flag, additionalContext emission
- `tests/python/test_setup_detection.py` - Fixed mock return value for updated `_show_welcome` signature

**Tests:** 14/14 passing (GREEN)
**Branch:** feat/132-2-welcome-banner-nudge (pushed)

**AC Coverage:**
- Banner displays on first session: persistent marker `.pennyfarthing/.discovery-nudge-shown` ensures one-time display
- Nudge to explore guide: "Tip: Run /pf-help to explore commands, agents, and workflows"
- Dismissible: Non-blocking tip line, only shows once, additionalContext is advisory
- Configurable: `discovery_nudge: false` under `workflow:` in `config.local.yaml`

**Handoff:** To Reviewer (Granny Weatherwax) for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] | Cyclist mode silently drops `show_nudge` — TS handler only destructures `{project, theme}`, `WelcomeMessage` interface has no `show_nudge` field. Nudge marked as shown but never displayed in Cyclist. | `session_start.py:290-303`, `server.ts:207`, `welcome.ts:15-18` | Add `show_nudge` to `WelcomeMessage` interface, destructure it in the route handler, include in broadcast payload |
| [MEDIUM] | If `.pennyfarthing/` doesn't exist, `_mark_nudge_shown()` silently fails (catches OSError) and nudge repeats every session because marker can never be written | `session_start.py:248-270` | Guard `_should_show_nudge()` — return `False` if `.pennyfarthing/` dir doesn't exist |
| [LOW] | Marker file `.pennyfarthing/.discovery-nudge-shown` not in `.gitignore` | orchestrator `.gitignore` | Add gitignore entry (can be follow-up chore) |

**Data flow traced:** `main()` → `_show_welcome()` → `load_settings()` → `_should_show_nudge()` → display → `_mark_nudge_shown()` → `additionalContext`. Clean chain but Cyclist branch is broken.
**Pattern observed:** Config loading follows existing `isinstance(x, bool)` guard pattern at `__init__.py:221-222`. Good.
**Error handling:** `_mark_nudge_shown()` catches OSError but this masks the repeated-nudge bug.

**Handoff:** Back to Dev (Ponder Stibbons) for fixes

## Dev Assessment (Round 2)

**Implementation Complete:** Yes — reviewer findings addressed
**Fixes Applied:**
- `pennyfarthing-dist/src/pf/hooks/session_start.py` - Added `.pennyfarthing/` directory existence guard in `_should_show_nudge()` to prevent repeated nudge when directory is missing
- `packages/core/src/server/api/welcome.ts` - Added `showNudge` to `WelcomeMessage` interface, included in broadcast payload
- `packages/core/src/server/server.ts` - Destructure `show_nudge` from request body, pass to `broadcastWelcome()`

**Tests:** 14/14 passing (GREEN), TypeScript compiles clean
**Branch:** feat/132-2-welcome-banner-nudge (pushed)

**Handoff:** To Reviewer (Granny Weatherwax) for re-review

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

### Original Findings — Disposition

| Original Finding | Status | Verification |
|-----------------|--------|-------------|
| [MEDIUM] Cyclist drops `show_nudge` | FIXED | `showNudge` added to `WelcomeMessage` interface (`welcome.ts:18`), broadcast payload (`welcome.ts:36`), request destructure (`server.ts:207`), coercion (`server.ts:209`) |
| [MEDIUM] Missing `.pennyfarthing/` dir causes repeated nudge | FIXED | `_should_show_nudge()` returns False when dir missing (`session_start.py:257-258`) |
| [LOW] `.gitignore` entry | DEFERRED | Acceptable follow-up chore |

### Observations

1. [VERIFIED] Data flow: `main()` → `_show_welcome()` → `_should_show_nudge()` → display → `_mark_nudge_shown()` → `HookResponse`. Clean in both CLI and Cyclist.
2. [VERIFIED] Type coercion Python→HTTP→TS: `bool` → JSON → `!!show_nudge`. Correct.
3. [VERIFIED] Config loading follows existing `isinstance(x, bool)` guard pattern (`__init__.py:221-222`)
4. [VERIFIED] Return type change `_show_welcome() -> bool` handled — test mock updated (`test_setup_detection.py:277`)
5. [VERIFIED] `HookResponse` conditional import follows existing pattern (`session_start.py:442`)
6. [LOW] Pre-existing: Cyclist API failure → marker still written → user never sees nudge. Acceptable (prevents retry loop).

### Preflight: 14/14 tests GREEN, TypeScript clean, no TODOs

**Handoff:** To SM (Captain Carrot) for finish-story