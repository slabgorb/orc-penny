# Story 86-13: Tandem backseat not activating from CLI invocation

**Status:** in_progress
**Phase:** review
**Workflow:** tdd
**Jira:** PROJ-15126
**Branch:** fix/tandem-backseat-cli-activation
**Repos:** pennyfarthing
**Points:** 2
**Epic:** 86 — Agent Collaboration — Tandem to Teams

## Story Context

The tandem backseat observer is not activating when invoked from CLI (non-Cyclist) sessions. The tandem protocol defines a background observer that monitors the primary agent's work and provides suggestions. This works in Cyclist but fails in plain CLI invocation.

## Acceptance Criteria

- [ ] Tandem backseat activates correctly from CLI invocation
- [ ] Background task spawns and writes to observation file
- [ ] PostToolUse hook detects and injects observations
- [ ] Works in both CLI and Cyclist contexts

## Technical Notes

Key files for tandem protocol:
- `pennyfarthing-dist/guides/tandem-protocol.md` — protocol definition
- `pennyfarthing-dist/agents/tandem-backseat.md` — backseat agent definition
- Agent behavior guide tandem section — activation logic in each agent
- PostToolUse hook — observation injection

## SM Assessment

Story setup complete:
- Branch `fix/tandem-backseat-cli-activation` created and pushed
- Jira ticket PROJ-15126 claimed
- Context established: tandem backseat activation failure in CLI (non-Cyclist) invocation
- Root cause area identified: PostToolUse hook observation injection in CLI context

Routing to TEA for test-first (red phase) approach on tandem backseat activation bug. Will focus on reproducing failure and establishing baseline test coverage for tandem protocol in CLI context.

## TEA Assessment

**Tests Required:** Yes
**Root Cause:** `complete_phase.py` never reads workflow YAML for `tandem:` blocks and never writes `**Tandem:**` line to session file during phase transitions. Without this line, agents skip the entire backseat spawn sequence.

**Test File:**
- `tests/python/test_complete_phase_tandem.py` — 13 tests (6 failing, 7 passing)

**Tests Written:** 13 tests covering 4 ACs:
- AC1: Tandem line written when transitioning to tandem-enabled phase (3 tests + placement)
- AC2: No tandem line for phases without tandem config (2 tests)
- AC3: Tandem line removed when entering non-tandem phase (1 test)
- AC4: Tandem line updated when partner changes between phases (2 tests)
- Regression: Existing complete_phase behavior preserved (4 tests)

**Status:** RED (6 failing on assertions — true RED, not import/syntax errors)

**Fix Required In:** `pennyfarthing_scripts/handoff/complete_phase.py`
- Read workflow YAML for `tandem:` block on to_phase
- Write/update/remove `**Tandem:** {partner} ({scope})` line in session metadata

**Handoff:** To Dev (Inigo Montoya) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/handoff/complete_phase.py` — added `_get_phase_tandem()` helper and tandem line management in `complete_phase()`

**Approach:** Before updating the Phase field, the function now: (1) removes any existing `**Tandem:**` line, (2) reads workflow YAML for tandem config on `to_phase`, (3) inserts `**Tandem:** {partner} ({scope})` after the `**Workflow:**` line if tandem is configured.

**Tests:** 13/13 passing (GREEN)
**PR:** #952 — fix: tandem backseat activation from CLI
**Branch:** fix/tandem-backseat-cli-activation (pushed)

**Handoff:** To Reviewer (Westley) for code review
