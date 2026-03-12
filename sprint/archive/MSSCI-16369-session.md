# Story 143-11: Update PF activation skills for native subagents

**Jira:** MSSCI-16369
**Epic:** 143 — Native Subagent Migration
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16369-update-pf-activation-skills
**Workflow:** trivial
**Phase:** finish
**Status:** in_progress
**Assigned:** keith.avery@1898andco.io
**Started:** 2026-03-12

## Story Context

Update the Pennyfarthing activation skills (the `/pf-*` slash commands that activate agents) to work correctly with native Claude Code subagents. Currently these skills use in-conversation persona switching; they need to be updated to align with the native subagent architecture established in stories 143-1 through 143-6.

## Acceptance Criteria

- [ ] All `/pf-*` activation skills updated for native subagent compatibility
- [ ] Skills correctly load agent context via `pf agent start`
- [ ] No breaking changes to existing activation flow

## SM Assessment

**Routing:** Trivial workflow → direct to Dev (Reverend Mother). 3-point feature, standalone from 143-7 chain.

**Context:** Stories 143-1 through 143-6 established native subagent definitions and `pf agent start` activation. The `/pf-*` skills in `pennyfarthing-dist/skills/` currently contain agent-activation instructions that predate native subagents. Dev needs to audit each skill and update activation patterns to use `pf agent start` consistently.

**Key files:** `pennyfarthing-dist/skills/pf-*.md` (source of truth, symlinked to `.claude/skills/`).

**Risk:** Low — skill files are markdown, changes are localized. Main concern is ensuring the activation output from `pf agent start` is consumed correctly by each skill's instructions.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/init/core.py` — Added `.claude/agents` to `_CLAUDE_DIRS` and `_DOGFOODING_SYMLINKS`; added consumer-mode copy of agents to `.claude/agents/`
- `pennyfarthing-dist/src/pf/doctor/checks.py` — Added `check_agents()` health check and registered in `CHECKS`
- `pennyfarthing-dist/src/pf/doctor/core.py` — Imported and registered `check_agents` in `_CHECK_FNS`
- `pennyfarthing-dist/src/pf/tests/test_doctor.py` — Added agents to fixture, added pass/fail tests for `check_agents`
- `pennyfarthing-dist/src/pf/tests/test_init_command.py` — Added agents to mock_dist fixture, added init and copy tests
- `.pennyfarthing/repos.yaml` (orchestrator) — Added `.claude/agents` symlink and never_edit entry
- `.claude/agents` (orchestrator) — Created symlink → `pennyfarthing/pennyfarthing-dist/agents`

**Tests:** 105/105 passing (GREEN) — test_doctor.py (48) + test_init_command.py (57)
**Branch:** feat/MSSCI-16369-update-pf-activation-skills (pushed)

**Notes:** Audit found all 11 activation commands already use `pf agent start` (updated in 143-1 through 143-3). The missing piece was the `.claude/agents/` directory — required for Claude Code to discover native subagent definitions when SM spawns via the Agent tool. Init and doctor updated for consumer projects.

**Handoff:** To Reviewer (Leto II) for code review.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `init_project()` → `_CONTENT_DIRS["agents"]` → `.pennyfarthing/agents/` copy → conditional `.claude/agents/` copy at `init/core.py:470`. Dogfooding path: `_DOGFOODING_SYMLINKS` → `_ensure_dogfooding_symlinks()` creates relative symlink. Both paths verified correct.
**Pattern observed:** Follows existing `check_commands`/`check_skills` pattern exactly — same structure, same error handling, same test pattern at `doctor/checks.py:97-105`
**Error handling:** `check_agents()` returns `CheckResult(status="fail")` on missing dir or empty dir — no throws, consistent with project principle #10 (Return Results, Don't Throw)
**Security:** No new user-input surfaces. File copies use existing `_copy_tree`. Symlinks use existing `os.path.relpath` pattern.
**Observations:**
- `[VERIFIED]` Symlink `is_dir()` follows links — check works in dogfooding mode
- `[VERIFIED]` `README.md` excluded from agent count, `templates/` subdir excluded by `is_file()` filter
- `[VERIFIED]` `repos.yaml` never_edit and symlinks both updated
- `[VERIFIED]` No forbidden patterns in diff
- `[LOW]` Test asserts `>= 1` agents when mock has 3 — minor, matches existing test style

**Handoff:** To Stilgar (SM) for finish-story

## Delivery Findings

- No upstream findings during implementation.

### Reviewer (code review)

- No upstream findings during code review.