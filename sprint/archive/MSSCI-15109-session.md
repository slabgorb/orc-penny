# Story 86-14: Agent behavior: team-mode protocol

## Story Details
- **ID:** 86-14
- **Jira Key:** MSSCI-15109
- **Epic:** 86 (MSSCI-14509)
- **Title:** Agent behavior: team-mode protocol
- **Workflow:** tdd
- **Points:** 2
- **Priority:** P1

## Story Context

Add `<team-mode>` section to `agent-behavior.md` and individual agent `.md` files defining how agents behave when they are a team lead or a teammate.

### Acceptance Criteria
- [ ] `agent-behavior.md` has `<team-mode>` section covering: team creation, teammate spawning, SendMessage communication, cleanup before handoff
- [ ] Lead agents know: create team on phase entry, spawn teammates per YAML, shut down teammates before exit protocol
- [ ] Teammate agents know: they're a teammate (not lead), communicate via SendMessage, go idle when done, respond to shutdown requests
- [ ] Exit protocol has team-mode branch: cleanup team THEN run normal handoff
- [ ] Reflector markers still used for inter-phase handoff (unchanged)
- [ ] SendMessage used for intra-phase teammate communication (new)

### Key Files
- `pennyfarthing-dist/agents/agent-behavior.md` (add `<team-mode>` section)
- `pennyfarthing-dist/agents/dev.md` (lead behavior for green phase)
- `pennyfarthing-dist/agents/reviewer.md` (lead behavior for review phase)

### Dependencies
- **Blocked by:** 86-8 (Teammate activation via spawn prompts)
- **Blocks:** 86-15 (Team-enabled workflow templates)

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-18T07:54:27Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-18T07:33:18Z | 2026-02-18T07:34:31Z | 1m 13s |
| red | 2026-02-18T07:34:31Z | 2026-02-18T07:41:56Z | 7m 25s |
| green | 2026-02-18T07:41:56Z | 2026-02-18T07:47:57Z | 6m 1s |
| review | 2026-02-18T07:47:57Z | 2026-02-18T07:54:27Z | 6m 30s |
| finish | 2026-02-18T07:54:27Z | - | - |

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story follows established validation adapter pattern (same as 86-4 tandem awareness)

**Test Files:**
- `pennyfarthing_scripts/validate/adapters/team_mode.py` — validation adapter with section extraction, topic checking, lead/teammate/exit/comm validators
- `tests/python/test_agent_team_mode.py` — 42 tests covering all 6 ACs

**Tests Written:** 42 tests covering 6 ACs
- AC1 (behavior guide `<team-mode>`): 8 tests
- AC2 (lead agent behavior): 8 tests
- AC3 (teammate awareness): 6 tests
- AC4 (exit protocol team branch): 4 tests
- AC5 (reflector markers unchanged): 2 tests
- AC6 (SendMessage intra-phase): 3 tests
- Validator integration: 4 tests
- Real file integration: 7 tests (all FAIL — RED state)

**Status:** RED (36 pass, 6 fail — real files need `<team-mode>` sections)

**What Dev Must Implement:**
1. Add `<team-mode>` section to `pennyfarthing-dist/guides/agent-behavior.md` covering: TeamCreate, spawning, SendMessage, cleanup/TeamDelete
2. Add team-mode branch to `<agent-exit-protocol>` in `agent-behavior.md` (team cleanup before handoff)
3. Add `<team-mode>` lead section to `pennyfarthing-dist/agents/dev.md`
4. Add `<team-mode>` lead section to `pennyfarthing-dist/agents/reviewer.md`

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/guides/agent-behavior.md` — added `<team-mode>` section (team creation, spawning, SendMessage, teammate behavior, cleanup) and updated `<agent-exit-protocol>` with team cleanup branch (step 3)
- `pennyfarthing-dist/agents/dev.md` — added `<team-mode>` lead section for green phase (TeamCreate, spawn per YAML, SendMessage coordination, shutdown before exit)
- `pennyfarthing-dist/agents/reviewer.md` — added `<team-mode>` lead section for review phase (same pattern as dev)

**Tests:** 42/42 passing (GREEN)
**PR:** #964 — feat(86-14): add team-mode protocol to agent definitions
**Branch:** `feat/86-14-team-mode-protocol` (pushed)

**AC Coverage:**
- AC1: `<team-mode>` in agent-behavior.md covers TeamCreate, spawning, SendMessage, cleanup/TeamDelete
- AC2: dev.md and reviewer.md have lead-specific `<team-mode>` sections referencing phase entry, spawn per YAML, shutdown before exit
- AC3: agent-behavior.md `<team-mode>` documents teammate behavior — identity (not the lead), SendMessage, go idle, shutdown_response
- AC4: `<agent-exit-protocol>` now has step 3: "If team is active: Shut down all teammates → TeamDelete to clean up" — before gate resolution
- AC5: Reflector `<critical>` section with CYCLIST markers remains unchanged
- AC6: `<team-mode>` explicitly distinguishes inter-phase (Reflector markers) from intra-phase (SendMessage)

**Pre-existing failures (not caused by this story):**
- `test_agent_validator.py` has 2 pre-existing failures: tandem-backseat.md, tea.md, tech-writer.md missing required sections

**Open question from user:**
User asked about "pulling this logic into gates" — may want to consolidate `team_mode.py` validator into existing `agent.py` validator or into workflow phase gates. Current approach follows the `tandem_awareness.py` pattern (separate adapter). Reviewer should surface this for architectural discussion.

**Handoff:** To Westley (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 42/42 passing (GREEN)
**Data flow traced:** `validate_behavior_guide_team_mode(path)` → `path.read_text()` → `extract_team_mode_section()` → `_BEHAVIOR_GUIDE_TOPICS` keyword check → errors/warnings. Safe — no user input, regex is non-backtracking.
**Pattern observed:** `<team-mode>` follows same placement as `<tandem-consultation>` — shared behavior in guide, role-specific in agents. Consistent at `agent-behavior.md:98-139`, `dev.md:196-207`, `reviewer.md:154-165`.
**Error handling:** All validator functions return `(errors, warnings)` tuples. Missing files, empty sections, missing topics all produce clear error messages.

**Findings:**

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [MEDIUM] | Validator not registered in CLI — `team_mode` not in `VALIDATORS` dict, so `pf validate` won't run it | `validate/cli.py:19-26` | Unlike tandem_awareness which IS registered. Could address when consolidating per user's gate question |
| [MEDIUM] | `validate_teammate_awareness()` defined and tested but never called from `run()` — AC3 passes only via fixture unit tests, not real file integration | `team_mode.py:121-147` vs `run()` at `:251-325` | Teammate topic regression against real files won't be caught |
| [LOW] | Double file read for behavior guide | `team_mode.py:59,276` | Minor inefficiency |
| [LOW] | `report.passed` not incremented for exit/comm checks | `team_mode.py:275-300` | Reporting inconsistency |
| [VERIFIED] | TDD discipline — RED then GREEN commits | git log `77ab549`, `b557115` | |
| [VERIFIED] | All 6 ACs covered — 42 tests, 7 real-file integration | `test_agent_team_mode.py` | |
| [VERIFIED] | Exit protocol renumbering correct | `agent-behavior.md:161-182` | |
| [VERIFIED] | Pattern consistent with tandem_awareness adapter | Both adapter files | |
| [VERIFIED] | No security concerns — regex safe, no exec, no user input | `team_mode.py:17` | |

**Architectural note:** User asked about consolidating into gates. The MEDIUM findings (not registered, `validate_teammate_awareness` not in `run()`) support doing so in a follow-up. Current approach is acceptable for this story scope.

**Handoff:** To Vizzini (SM) for finish-story

## Story Context Files
- Epic context: `/Users/keithavery/Projects/pf-2/sprint/context/context-epic-86.md`
- Epic definition: `/Users/keithavery/Projects/pf-2/sprint/epic-MSSCI-14509.yaml`