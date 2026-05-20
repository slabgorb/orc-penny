---
story_id: "147-10"
jira_key: "PROJ-16429"
epic: "PROJ-16411"
workflow: "tdd"
---
# Story 147-10: Summon agent into saddle from running session — pf saddle summon

## Story Details
- **ID:** 147-10
- **Jira Key:** PROJ-16429
- **Workflow:** tdd
- **Stack Parent:** none

## Story Context

### Problem Statement
The saddle mode supports launching agents via `start_agent()`, which sends `claude /pf-{agent_name}` to a tmux pane. However, there's no way for a running agent session to summon another agent into the saddle — e.g., an SM might want to call Dev mid-conversation to fix CI without losing context.

### Acceptance Criteria
1. `pf saddle summon <agent>` CLI command exists and launches agent in saddle pane
2. Summoned agent receives full `pf agent start` context (persona, agent definition, sidecars) — NOT a stripped-down subagent
3. Optional `--task` flag to pass task description to the summoned agent
4. Saddle state tracks the summoned agent (reuses existing state management)
5. Works when tmux/BikeRack is running; clear error when not

### Relevant Code
- Saddle core: `pennyfarthing-dist/src/pf/saddle/core.py` (has `start_agent()`, `stop_agent()`, `status()`, `ensure_saddle_pane()`)
- Saddle CLI: `pennyfarthing-dist/src/pf/saddle/cli.py`
- Current implementation: `start_agent()` sends `claude /pf-{agent_name}` to tmux saddle pane

### Design Goals
- Enable mid-conversation delegation: SM says "Dev, go fix CI" and Dev gets a real session (not a subagent)
- Summoned agent gets full prime output context, not stripped-down prompt
- Reuse existing saddle state management where possible

## Workflow Tracking
**Workflow:** tdd
**Phase:** spec-reconcile
**Phase Started:** 2026-03-13T19:16:18Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T16:21:02Z | 2026-03-13T16:22:41Z | 1m 39s |
| red | 2026-03-13T16:22:41Z | 2026-03-13T16:28:26Z | 5m 45s |
| green | 2026-03-13T16:28:26Z | 2026-03-13T16:40:11Z | 11m 45s |
| spec-check | 2026-03-13T16:40:11Z | 2026-03-13T16:41:24Z | 1m 13s |
| verify | 2026-03-13T16:41:24Z | 2026-03-13T16:46:23Z | 4m 59s |
| review | 2026-03-13T16:46:23Z | 2026-03-13T17:04:46Z | 18m 23s |
| red | 2026-03-13T17:04:46Z | 2026-03-13T17:17:36Z | 12m 50s |
| green | 2026-03-13T17:17:36Z | 2026-03-13T18:18:16Z | 1h |
| spec-check | 2026-03-13T18:18:16Z | 2026-03-13T18:22:17Z | 4m 1s |
| verify | 2026-03-13T18:22:17Z | 2026-03-13T18:30:18Z | 8m 1s |
| review | 2026-03-13T18:30:18Z | 2026-03-13T18:40:39Z | 10m 21s |
| red | 2026-03-13T18:40:39Z | 2026-03-13T18:46:46Z | 6m 7s |
| green | 2026-03-13T18:46:46Z | 2026-03-13T18:52:43Z | 5m 57s |
| spec-check | 2026-03-13T18:52:43Z | 2026-03-13T19:02:55Z | 10m 12s |
| verify | 2026-03-13T19:02:55Z | 2026-03-13T19:06:25Z | 3m 30s |
| review | 2026-03-13T19:06:25Z | 2026-03-13T19:16:18Z | 9m 53s |
| spec-reconcile | 2026-03-13T19:16:18Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No upstream findings during test design.

### TEA (test design, round 2)
- No upstream findings during test design (round 2). Reviewer findings were clear and actionable.

### Dev (implementation)
- No upstream findings during implementation.

### Dev (implementation, round 2)
- No upstream findings during implementation (round 2).

### Reviewer (code review)
- **Gap** (blocking): Task parameter in `summon_agent()` is interpolated into shell command without `shlex.quote()` escaping — CWE-78 shell injection. Affects `pennyfarthing-dist/src/pf/saddle/core.py` (line 225, must escape `effective_task`). *Found by Reviewer during code review.*
- **Gap** (blocking): No test verifies shell safety of task parameter — `test_summon_task_with_special_characters` checks Python-level round-trip only, not shell-level safety. Affects `tests/python/test_147_10_saddle_summon.py` (needs test with `"`, `$`, `` ` `` in task that verifies command is shell-safe). *Found by Reviewer during code review.*

### TEA (test design, round 3)
- No upstream findings during test design (round 3). Reviewer round 2 findings were precise — the shell quoting context issue was clear and testable.

### Reviewer (code review, round 2)
- **Gap** (blocking): `shlex.quote()` fix for CWE-78 is INEFFECTIVE. `shlex.quote()` wraps task in single quotes, but the output is embedded inside a double-quoted shell string where single quotes are literal characters with no protective effect. `$()` and backtick expansion still occurs. Proven: `echo "Your task: '$(echo INJECTED)'"` executes the subshell. Affects `pennyfarthing-dist/src/pf/saddle/core.py` (lines 222-225, must either close double quotes before task so shlex.quote operates at top level, OR escape `$`, `` ` ``, `\`, `"` with backslashes for double-quote context). *Found by Reviewer during code review.*
- **Gap** (blocking): All 6 `TestSummonShellSafety` tests are false positives — they verify `shlex.quote(task) in command` (single-quote characters present) but don't verify the quoting prevents shell expansion in the actual double-quoted context. Affects `tests/python/test_147_10_saddle_summon.py` (tests must verify correct escaping for the actual shell quoting structure, not just presence of shlex.quote output). *Found by Reviewer during code review.*

### Dev (implementation, round 3)
- No upstream findings during implementation (round 3).

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

### TEA (test design, round 2)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### Dev (implementation, round 2)
- No deviations from spec.

### Reviewer (audit)
- TEA and Dev both logged "No deviations" — confirmed accurate. Implementation matches all 5 ACs exactly.
- **Undocumented security gap:** AC3 specifies "--task flag to pass task description" but does not mention shell safety. Implementation interpolates task directly into shell command without escaping. Not a spec deviation per se (spec is silent on safety), but a CWE-78 vulnerability that must be fixed.

### Reviewer (audit, round 2)
- TEA and Dev round 2 both logged "No deviations" — confirmed accurate. The shlex.quote() addition was intended as a security fix, not a spec change.
- **CRITICAL: The CWE-78 fix is ineffective.** `shlex.quote()` output is placed inside an existing double-quoted string where single quotes have no protective meaning. The vulnerability from round 1 persists. This is not a spec deviation but a failed security fix.

### TEA (test design, round 3)
- No deviations from spec.

### Dev (implementation, round 3)
- No deviations from spec.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 4 | confirmed 1 (shell injection), dismissed 3 (stop_agent return, KeyError guard, race condition — match existing patterns) |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 4 | dismissed 4 (stop_agent return matches start_agent, telemetry is intentional fire-and-forget, state-after-send inherent to pattern, _load_state is pre-existing) |
| 4 | reviewer-test-analyzer | Yes | findings | 11 | confirmed 3 (send_keys not verified, shell escaping untested, task inclusion incomplete), dismissed 8 (vacuous/coupling/low concerns) |
| 5 | reviewer-comment-analyzer | Yes | findings | 3 | confirmed 1 (CLI help text lacks safety note), dismissed 2 (error docs and empty-string docs match module style) |
| 6 | reviewer-type-design | Yes | findings | 4 | dismissed 4 (untyped dict, optional field, stringly-typed agent — all module-wide patterns, not story scope) |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 1 (CWE-78 task injection), dismissed 1 (agent_name safe — already noted) |
| 8 | reviewer-simplifier | Yes | findings | 2 | confirmed 2 (effective_task redundant, second _load_state redundant — both LOW) |

**All received:** Yes
**Total findings:** 7 confirmed (1 critical, 1 high, 2 medium, 3 low), 16 dismissed (with rationale above), 0 deferred

## TEA Assessment

**Tests Required:** Yes
**Reason:** New feature — `pf saddle summon` command with core function and CLI wiring

**Test Files:**
- `tests/python/test_147_10_saddle_summon.py` - 25 tests covering all 5 ACs

**Tests Written:** 25 tests covering 5 ACs
- AC1 (CLI command): 6 tests — command exists, argument required, valid/invalid agents, JSON output
- AC2 (full prime context): 3 tests — command uses claude with prompt, includes agent activation, differs from start_agent
- AC3 (--task flag): 6 tests — without task, with task in command, task in data, CLI flag, special chars, empty task
- AC4 (state tracking): 5 tests — active state, pane_id, stops existing, reuses pane, stop works after summon
- AC5 (error cases): 6 tests — no tmux, invalid agent, empty agent, all valid agents, result contract, CLI error

**Status:** RED (21 failing on NotImplementedError, 4 passing on CLI scaffolding)

**Stubs created:**
- `pennyfarthing-dist/src/pf/saddle/core.py` — `summon_agent()` stub raising NotImplementedError
- `pennyfarthing-dist/src/pf/saddle/cli.py` — `pf saddle summon` command wired to stub

**Handoff:** To the White Rabbit (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/saddle/core.py` — implemented `summon_agent()`: validates agent, checks tmux, stops existing agent, ensures saddle pane, builds `claude -p "$(pf agent start {agent})"` command with optional task, sends to pane, updates state

**Tests:** 25/25 passing (GREEN)
**Branch:** feat/147-10-saddle-summon-agent

**Implementation Notes:**
- `summon_agent()` follows the same pattern as `start_agent()` but builds a `claude -p` command with subshell expansion of `pf agent start` for full prime context
- Empty task string is treated as no task (no empty artifacts in command)
- Task text appears in both the command string and result data for visibility
- Telemetry emits `agent_summon` event (distinct from `agent_start`)

**Handoff:** To next phase (verify)

## TEA Assessment (verify)

**Tests:** 25/25 passing (GREEN confirmed post-simplify)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | Validation/state duplication between start_agent and summon_agent; CLI error handling repetition |
| simplify-quality | 3 findings | Unused MagicMock import; `.get()` inconsistency in stop_agent; silent pass lacks comment |
| simplify-efficiency | 3 findings | Redundant state load; CLI error pattern repetition; test loop coverage excess |

**Applied:** 1 high-confidence fix (removed unused `MagicMock` import from test file)
**Flagged for Review:** 5 medium-confidence findings (validation extraction, telemetry helper, CLI error handler, redundant state load, CLI error pattern)
**Noted:** 3 low-confidence observations (CLI decorator opportunity, silent pass comment, test loop coverage)
**Reverted:** 0

**Triage rationale for not applying high-confidence reuse findings (#1, #2):** The duplication between `start_agent` and `summon_agent` is real but intentional — extracting helpers would refactor pre-existing code beyond story scope. The Reviewer can flag this if they disagree.

**Overall:** simplify: applied 1 fix

**Handoff:** To the Queen of Hearts (Reviewer) for code review.

## Architect Assessment (spec-check)

**Spec Alignment:** All 5 ACs satisfied.

| AC | Status | Evidence |
|----|--------|----------|
| AC1 — CLI command | PASS | `summon` command in saddle group, takes agent arg, outputs JSON |
| AC2 — Full prime context | PASS | `claude -p "$(pf agent start {agent})"` — subshell expansion provides full prime output |
| AC3 — --task flag | PASS | Optional `--task` in CLI, `task` kwarg in core, empty string = no task |
| AC4 — State tracking | PASS | Reuses `_load_state`/`_save_state`, stops existing agent, updates active/agent/pane_id |
| AC5 — Error cases | PASS | tmux check, agent validation, result dict contract throughout |

**Implementation quality:** Clean reuse of existing patterns from `start_agent()`. The only novel code is the command construction (`claude -p` with subshell expansion vs `claude /pf-{agent}`). No new abstractions, no unnecessary complexity.

**Deviation check:** TEA and Dev both report no deviations. Confirmed — implementation matches spec exactly.

**Handoff:** To the Caterpillar (TEA) for verify phase.

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [CRITICAL] [SEC][EDGE] | CWE-78: Task parameter interpolated into shell command without escaping. `f'Your task: {effective_task}"'` allows shell metacharacters (`"`, `$`, `` ` ``) to break out of the double-quoted string and execute arbitrary commands in the tmux pane. | `core.py:225` | Wrap task with `shlex.quote()`: `import shlex` at top, `shlex.quote(effective_task)` in command construction. |
| [HIGH] [TEST] | Shell safety not tested. `test_summon_task_with_special_characters` checks Python dict round-trip only. A task containing `"` or `$(...)` would break the shell command but pass all current tests. | `test_147_10_saddle_summon.py:197` | Add test with shell-dangerous chars (`"`, `$()`, `` ` ``) and verify the resulting command string is shell-safe (e.g., task is quoted). |
| [MEDIUM] [TEST] | `send_keys` mock is never verified called. Tests check the returned command string but never assert `send_keys` was invoked with it. | `test_147_10_saddle_summon.py:62` | Use `patch` with `wraps` or capture `call_args` to verify `send_keys` received the command. |
| [MEDIUM] [TEST] | Task inclusion test uses naive substring match — `assert "Fix the failing Ruff CI check" in command` — which passes regardless of quoting correctness. | `test_147_10_saddle_summon.py:178` | After shell injection fix, verify the task appears inside `shlex.quote()` output. |
| [LOW] [SIMPLE] | `effective_task = task if task else None` is redundant — `if task:` works directly since `task` is already `str | None`. | `core.py:221` | Remove `effective_task`, use `if task:` directly. |
| [LOW] [SIMPLE] | Second `_load_state()` at line 243 is redundant — state was already loaded at line 209, and no external save occurred between them. | `core.py:243` | Reuse the state dict from line 209. |
| [LOW] [DOC] | CLI `--task` help text doesn't mention that task is embedded in a shell command. | `cli.py:52` | Moot once `shlex.quote()` fix is applied. |

**Data flow traced:** `task` (CLI `--task` arg) → `summon_agent(task=)` → f-string interpolation → `_panes.send_keys()` → tmux `send-keys` → shell execution in pane. The task string reaches shell execution without sanitization.

**Pattern observed:** [VERIFIED] `summon_agent` correctly follows `start_agent`'s validation/state/pane pattern at `core.py:199-217`. Good reuse.

**Error handling:** [VERIFIED] All error paths return result dicts, no exceptions escape. Matches module convention.

**Security analysis:** CWE-78 shell injection via task parameter. Agent name is safe (validated against `VALID_AGENTS`).

**Wiring:** [VERIFIED] CLI → core function → tmux pane. Properly wired.

**Handoff:** Back to the Caterpillar (TEA) for shell injection test, then the White Rabbit (Dev) for fix.

## SM Assessment

**Setup complete.** Story 147-10 session initialized, Jira PROJ-16429 claimed and moved to In Progress, feature branch `feat/147-10-saddle-summon-agent` created in pennyfarthing repo.

**Routing:** TDD workflow → Caterpillar (TEA) for RED phase — write failing tests for `pf saddle summon`.

**Key context for TEA:** Existing saddle code at `pennyfarthing-dist/src/pf/saddle/core.py` has `start_agent()` which sends `claude /pf-{agent}` to tmux. New `summon()` function should be similar but support `--task` flag. Test the CLI command, state tracking, error cases (no tmux, invalid agent), and task passthrough.

## TEA Assessment (round 2)

**Tests Required:** Yes
**Reason:** CWE-78 shell injection — Reviewer found task parameter reaches `tmux send_keys` without `shlex.quote()` escaping

**Test Files:**
- `tests/python/test_147_10_saddle_summon.py` — 8 new/strengthened tests in `TestSummonShellSafety` class + 2 updated in `TestSummonTaskFlag`

**Tests Written:** 8 new tests (6 in `TestSummonShellSafety`, 2 strengthened in `TestSummonTaskFlag`):
- Double-quote breakout (`"`) — verifies `shlex.quote(task)` in command
- Command substitution (`$(...)`) — prevents shell expansion
- Backtick expansion (`` ` ``) — prevents legacy shell expansion
- Semicolon injection (`;`) — prevents command chaining
- Newline injection (`\n`) — prevents tmux command injection
- `send_keys` mock verification — confirms mock receives escaped command
- Strengthened `test_summon_with_task_includes_task_in_command` — checks `shlex.quote()` not just substring
- Strengthened `test_summon_task_with_special_characters` — checks command escaping, not just data dict

**Status:** RED (8 failing on assertion — `shlex.quote(task)` not found in command, 23 passing)

**Fix required for Dev:**
1. `import shlex` at top of `core.py`
2. Wrap task with `shlex.quote(effective_task)` in the command f-string at line 225
3. Also address LOW findings: remove redundant `effective_task` variable, remove redundant second `_load_state()` at line 243

**Handoff:** To the White Rabbit (Dev) for shell injection fix

## Dev Assessment (round 2)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/saddle/core.py` — added `import shlex`, wrapped task with `shlex.quote(task)` in command f-string, removed redundant `effective_task` variable, removed redundant second `_load_state()` call

**Tests:** 31/31 passing (GREEN)
**Branch:** feat/147-10-saddle-summon-agent (pushed)

**Implementation Notes:**
- `shlex.quote()` wraps the task in single quotes, preventing shell metacharacters from being interpreted
- Removed `effective_task` intermediary — `if task:` is sufficient since `task` is already `str | None`
- Reused `state` dict from line 209 instead of re-loading at line 243

**Handoff:** To next phase (verify)

## Architect Assessment (spec-check, round 2)

**Spec Alignment:** All 5 ACs remain satisfied. Reviewer findings fully addressed.

| AC | Status | Evidence |
|----|--------|----------|
| AC1 — CLI command | PASS | `summon` in saddle group, unchanged |
| AC2 — Full prime context | PASS | `claude -p "$(pf agent start {agent})"`, unchanged |
| AC3 — --task flag | PASS | Task now escaped via `shlex.quote(task)` at line 224 — shell-safe |
| AC4 — State tracking | PASS | Reuses `_load_state`/`_save_state`, redundant second load removed |
| AC5 — Error cases | PASS | tmux check, agent validation, result dict contract, unchanged |

**Reviewer findings status:**

| Finding | Severity | Status |
|---------|----------|--------|
| CWE-78 shell injection | CRITICAL | FIXED — `shlex.quote(task)` at line 224 |
| Shell safety untested | HIGH | FIXED — 6 new tests in `TestSummonShellSafety` |
| `send_keys` mock unverified | MEDIUM | FIXED — `test_send_keys_receives_shell_safe_command` |
| Naive substring match | MEDIUM | FIXED — tests now check `shlex.quote(task) in command` |
| Redundant `effective_task` | LOW | FIXED — removed, using `if task:` directly |
| Redundant second `_load_state()` | LOW | FIXED — reuses state from line 210 |
| CLI help text | LOW | Moot — `shlex.quote()` makes the embedding safe |

**Deviation check:** TEA and Dev both report no deviations in round 2. Confirmed — the fix is purely additive security hardening, no spec changes.

**Handoff:** To the Caterpillar (TEA) for verify phase.

### TEA (test design, verify round 2)
- No deviations from spec.

### TEA (test design, round 3)
- No deviations from spec.

### TEA (test verification, round 2)
- **Improvement** (non-blocking): `summon_agent()` uses stale state dict after `stop_agent()` and `ensure_saddle_pane()` both save state. All three fields are explicitly overwritten so no functional bug, but inconsistent with `start_agent()` which reloads state before final save. Affects `pennyfarthing-dist/src/pf/saddle/core.py` (line 242 should reload state for defensive consistency). *Found by TEA during test verification.*

## TEA Assessment (verify, round 2)

**Phase:** spec-reconcile
**Status:** GREEN confirmed — 31/31 tests passing

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 3 findings | CLI error handling repetition (high), validation duplication (high), activation flow abstraction (medium) |
| simplify-quality | 2 findings | State staleness after stop_agent (high), unused `call` import (high) |
| simplify-efficiency | 4 findings | CLI error pattern (medium), validation duplication (high), telemetry duplication (high), test mock duplication (low) |

**Applied:** 1 high-confidence fix (removed unused `call` import from test file)
**Flagged for Review:** 5 medium-confidence findings (validation extraction, telemetry helper, CLI error handler, state reload consistency, activation flow abstraction — all refactor pre-existing code beyond story scope)
**Noted:** 2 low-confidence observations (test mock duplication, CLI decorator opportunity)
**Reverted:** 0

**Triage rationale:** Duplication findings (#3-6) are real but affect pre-existing code (`start_agent`, CLI error pattern). Extracting helpers would refactor beyond story scope. State staleness (#1) is technically correct but all three fields are explicitly overwritten, and the Reviewer in round 1 explicitly directed removal of the second `_load_state()`. Flagging for Reviewer to decide.

**Overall:** simplify: applied 1 fix

**Quality Checks:** 31/31 tests passing
**Handoff:** To the Queen of Hearts (Reviewer) for code review.

## TEA Assessment (round 3)

**Tests Required:** Yes
**Reason:** CWE-78 shell injection fix was ineffective — `shlex.quote()` inside double quotes provides no protection. Tests must verify correct quoting context.

**Test Files:**
- `tests/python/test_147_10_saddle_summon.py` — 8 tests rewritten/added, 1 new test

**Tests Written:** 8 rewritten + 1 new = 9 tests changed:
- Rewritten 6 `TestSummonShellSafety` tests: now verify task appears AFTER closing `"` (not just that `shlex.quote()` characters exist in string)
- Rewritten 2 `TestSummonTaskFlag` tests: same structural check
- Added `test_send_keys_failure_returns_error`: covers `send_keys` failure path (Reviewer MEDIUM finding)
- Added shared `_assert_task_outside_dquotes()` helper for consistent structural validation

**Status:** RED (8 failing on assertion — task is inside double-quoted section, 24 passing)

**Fix required for Dev:**
1. Close the double-quoted section BEFORE the task so `shlex.quote()` operates at top level:
   `f'claude -p "$(pf agent start {agent_name})\n\nYour task: "{shlex.quote(task)}'`
2. Also update module docstring in `cli.py` to include "summon" (LOW finding)

**Handoff:** To the White Rabbit (Dev) for proper shell quoting fix.

## Subagent Results (round 2)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 31/31 tests pass, lint clean | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 3 | confirmed 1 (pf agent start output can break quoting — subsumed by CRITICAL), dismissed 2 (stop_agent return, _save_state return — match start_agent pattern) |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 5 | dismissed 5 (stop_agent return x2, bare except x2, state staleness — all match start_agent pattern, not new to this story) |
| 4 | reviewer-test-analyzer | Yes | findings | 6 | confirmed 1 (send_keys failure path untested — MEDIUM), dismissed 5 (weak empty-task test, tautological assertions — low value, not blocking) |
| 5 | reviewer-comment-analyzer | Yes | findings | 3 | confirmed 1 (stale module docstring omits summon — LOW), dismissed 2 (CLI docstring and error dict docs match module convention) |
| 6 | reviewer-type-design | Yes | findings | 2 | dismissed 2 (optional task field, untyped dict — both match module-wide patterns in start_agent/stop_agent, not story scope) |
| 7 | reviewer-security | Yes | findings | 1 | confirmed 1 — **CWE-78 STILL PRESENT: shlex.quote() inside double quotes is INEFFECTIVE** (CRITICAL) |
| 8 | reviewer-simplifier | Yes | clean | none | N/A |

**All received:** Yes
**Total findings:** 3 confirmed (1 critical, 1 medium, 1 low), 14 dismissed (with rationale above), 0 deferred

### Reviewer (audit, round 2)
- TEA and Dev round 2 both logged "No deviations" — confirmed accurate. The shlex.quote() addition is a security fix, not a spec deviation.
- **CRITICAL: The CWE-78 fix is INEFFECTIVE.** The `shlex.quote()` output is embedded inside an existing double-quoted string where single quotes are literal characters, not protective. Shell expansion (`$()`, backticks) still occurs. Verified by shell test: `echo "Your task: '$(echo INJECTED)'"` outputs `Your task: 'INJECTED'` — the subshell executed. Tests pass because they check for `shlex.quote(task) in command` (verifying the single-quote characters are present) but don't verify the quoting actually prevents shell expansion in a double-quoted context.

## Reviewer Assessment (round 2)

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [CRITICAL] [SEC] | CWE-78 PERSISTS: `shlex.quote(task)` wraps task in single quotes, but the result is embedded inside a double-quoted string (`"$(pf agent start dev)\n\nYour task: '$(echo PWNED)'"`). In bash, **single quotes inside double quotes are literal characters** — they do NOT prevent `$()`, backtick, or `"` expansion. Proven: `echo "Your task: '$(echo INJECTED)'"` → outputs `Your task: 'INJECTED'` (subshell executed). The round 1 fix is a no-op. | `core.py:222-225` | **Option A (recommended):** Close the double quotes before the task, let `shlex.quote()` operate at the top level where single quotes ARE protective: `f'claude -p "$(pf agent start {agent_name})\n\nYour task: "{shlex.quote(task)}'`. This produces `"...Your task: "'safe-quoted-task'"` where the shell sees: double-quoted prefix + single-quoted task (concatenated). **Option B:** Escape double-quote-special chars (`$`, `` ` ``, `\`, `"`) with backslashes: `task.replace('\\','\\\\').replace('$','\\$').replace('`','\\`').replace('"','\\"')`. |
| [HIGH] [TEST] | All 6 `TestSummonShellSafety` tests are FALSE POSITIVES. They assert `shlex.quote(task) in command` — which verifies single-quote characters exist in the string, NOT that they prevent shell expansion. The tests give a false sense of security while the vulnerability remains exploitable. | `test_147_10_saddle_summon.py:225-317` | After fixing the escaping (Option A or B above), tests must verify the CORRECT escaping pattern — either that the task appears outside double quotes (Option A) or that `$` and backticks are backslash-escaped (Option B). |
| [MEDIUM] [TEST] | `send_keys` failure path untested. Line 230-232 handles `send_result["success"] == False` but no test makes send_keys return failure. | `core.py:230-232` | Add test: patch send_keys to return `{success: False, error: "..."}`, verify summon_agent returns error dict. |
| [LOW] [DOC] | Module docstring says "pf saddle start/stop/status commands" — missing "summon". | `cli.py:1` | Update to include summon. |

**Data flow traced:** `task` (CLI `--task`) → `summon_agent(task=)` → `shlex.quote(task)` → f-string inside `"..."` → `_panes.send_keys()` → `tmux send-keys` (literal keystrokes) → shell in target pane parses double-quoted string → `$()` and backtick expansion STILL OCCURS inside double quotes regardless of inner single quotes.

**Shell proof:**
```bash
$ echo "Your task: '$(echo INJECTED)'"
Your task: 'INJECTED'
```
The `$(echo INJECTED)` executed. Single quotes inside double quotes = decoration, not protection.

**Pattern observed:** [VERIFIED] `summon_agent` correctly follows `start_agent` validation/state/pane pattern. The ONLY problem is the command quoting.

**Error handling:** [VERIFIED] All error paths return result dicts. Matches module convention.

**Security analysis:** CWE-78 shell injection via task parameter remains exploitable. `shlex.quote()` is the RIGHT tool but applied in the WRONG context (inside double quotes instead of at the top quoting level). Agent name remains safe (VALID_AGENTS whitelist).

**Wiring:** [VERIFIED] CLI → core → tmux. Properly wired.

**Simplify findings (from TEA verify):** Duplication between start_agent/summon_agent is real but beyond story scope — AGREED, not blocking.

**Handoff:** Back to the Caterpillar (TEA) for corrected shell safety tests, then the White Rabbit (Dev) for proper fix.

## Dev Assessment (round 3)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/saddle/core.py` — Fixed CWE-78: closed double-quoted section BEFORE the task so `shlex.quote()` operates at top level. Command now produces `"...Your task: "'safe-task'` where shell sees double-quoted prefix + single-quoted task (concatenated).
- `pennyfarthing-dist/src/pf/saddle/cli.py` — Updated module docstring to include "summon" (LOW doc finding).

**Tests:** 32/32 passing (GREEN)
**Branch:** feat/147-10-saddle-summon-agent

**Reviewer round 2 findings addressed:**
| Finding | Severity | Status |
|---------|----------|--------|
| CWE-78 shlex.quote inside dquotes | CRITICAL | FIXED — closed dquotes before task, shlex.quote at top level |
| Shell safety tests are false positives | HIGH | FIXED by TEA round 3 — tests now check structural quoting context |
| send_keys failure path untested | MEDIUM | FIXED by TEA round 3 — `test_send_keys_failure_returns_error` |
| Module docstring missing summon | LOW | FIXED — updated to "start/stop/status/summon" |

**Handoff:** To next phase (verify)

## Architect Assessment (spec-check, round 3)

**Spec Alignment:** All 5 ACs remain satisfied. Reviewer round 2 CWE-78 finding properly resolved.

| AC | Status | Evidence |
|----|--------|----------|
| AC1 — CLI command | PASS | `summon` in saddle group, unchanged |
| AC2 — Full prime context | PASS | `claude -p "$(pf agent start {agent})"`, unchanged |
| AC3 — --task flag | PASS | Task now in separate quoting context — double quotes close before `shlex.quote(task)` at top level |
| AC4 — State tracking | PASS | Reuses `_load_state`/`_save_state`, unchanged from round 2 |
| AC5 — Error cases | PASS | tmux check, agent validation, send_keys failure path — all covered |

**Reviewer round 2 findings status:**

| Finding | Severity | Status |
|---------|----------|--------|
| CWE-78 shlex.quote inside dquotes | CRITICAL | FIXED — `f'...Your task: "{shlex.quote(task)}'` closes double quotes before task. Shell sees: double-quoted prefix + single-quoted task (concatenated). Single quotes at top level ARE protective. |
| Shell safety tests false positives | HIGH | FIXED — `_assert_task_outside_dquotes()` helper verifies structural quoting context, not just substring presence |
| send_keys failure path untested | MEDIUM | FIXED — `test_send_keys_failure_returns_error` patches send_keys to return failure |
| Module docstring missing summon | LOW | FIXED — cli.py now says "start/stop/status/summon" |

**Shell quoting verification:** The command `claude -p "$(pf agent start dev)\n\nYour task: "'Fix the $(broken) test'` produces correct shell parsing: `"..."` (double-quoted section with command substitution for pf agent start) then `'...'` (single-quoted task, no expansion). This is Option A from the Reviewer's recommendation.

**Deviation check:** TEA and Dev round 3 both report no deviations. Confirmed — the change is a security fix to the quoting structure, not a spec change.

**Handoff:** To the Caterpillar (TEA) for verify phase.

### TEA (test verification, round 3)
- No upstream findings during verification (round 3).

### TEA (test design, verify round 3)
- No deviations from spec.

## TEA Assessment (verify, round 3)

**Phase:** spec-reconcile
**Status:** GREEN confirmed — 32/32 tests passing

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 6 findings | Mock setup duplication in shell safety tests (high), CLI error pattern repetition (high), validation duplication between start/summon (high), lifecycle management duplication (high), telemetry duplication (medium), _assert_task_outside_dquotes extraction (medium) |
| simplify-quality | 1 finding | Unused `Path` import in test file (high) |
| simplify-efficiency | 5 findings | Double state load in start/summon (high), telemetry duplication (high), CLI error pattern (high), test mock duplication (high), ensure_saddle_pane double list_live_panes call (medium) |

**Applied:** 1 high-confidence fix (removed unused `Path` import from test file)
**Flagged for Review:** 5 medium/high-confidence findings (validation extraction, lifecycle management extraction, telemetry helper, CLI error handler, test mock consolidation — all refactor pre-existing code beyond story scope)
**Noted:** 2 medium-confidence observations (_assert_task_outside_dquotes already extracted as class method, ensure_saddle_pane double call is pre-existing)
**Reverted:** 0

**Triage rationale:** Duplication findings between `start_agent` and `summon_agent` are real but consistently flagged across all 3 rounds. Extracting helpers would refactor pre-existing code beyond story scope. The Reviewer has agreed this is not blocking in rounds 1 and 2.

**Overall:** simplify: applied 1 fix

**Quality Checks:** 32/32 tests passing
**Handoff:** To the Queen of Hearts (Reviewer) for code review.

## Subagent Results (round 3)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 32/32 tests pass, no code smells | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 4 | dismissed 4: "unclosed double quote" is WRONG (exactly 2 quotes, properly paired — verified with Python trace showing open at idx 10, close at idx 45); empty string handling is by design (AC3 test covers this); KeyError guard on pane_result matches start_agent pattern; newline concern conflates Python `\n` with literal `\n` |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 2 | dismissed 2: stop_agent() return ignored matches identical pattern in start_agent (line 125); telemetry bare except is intentional fire-and-forget (Story 143-16 pattern) |
| 4 | reviewer-test-analyzer | Yes | findings | 13 | confirmed 2 (lint: import sorting I001, list comprehension C416 — both LOW), dismissed 11: "vacuous assertion" claims are WRONG — `_assert_task_outside_dquotes` correctly verifies the pattern `Your task: "<shlex-quoted>` which structurally proves the double quote closes before the task (confirmed by real bash tests showing `$(echo INJECTED)` NOT executed); tautological/coupling findings are low-value |
| 5 | reviewer-comment-analyzer | Yes | findings | 1 | dismissed 1: claim that comment is "lying" is WRONG — the comment correctly states "Close double quotes BEFORE the task" and Python trace confirms exactly 2 double quotes with the closing `"` appearing before `shlex.quote()` output |
| 6 | reviewer-type-design | Yes | findings | 3 | dismissed 3: inconsistent nullability of `task` key matches CLI optional pattern throughout module; stringly-typed agent_name and task are pre-existing module-wide patterns in start_agent/stop_agent/status |
| 7 | reviewer-security | Yes | findings | 2 | dismissed 2: claim that CWE-78 "still present" is WRONG — verified with real bash shell tests that `$(echo INJECTED)` remains literal, `$HOME` is NOT expanded, backticks NOT executed. Specialist confused subprocess.run safety with tmux send-keys → shell parsing. tmux sends keystrokes to a shell which parses the quoting — and the quoting IS correct at the shell level |
| 8 | reviewer-simplifier | Yes | findings | 2 | dismissed 2: state reload redundancy was addressed in round 2 per Reviewer direction; command building helper extraction would be over-engineering for a single function |

**All received:** Yes
**Total findings:** 2 confirmed (both LOW lint issues), 27 dismissed (with rationale above), 0 deferred

**Critical note on specialist accuracy this round:** 5 of 8 specialists (edge-hunter, silent-failure-hunter, comment-analyzer, security, test-analyzer) raised findings about the quoting structure being broken or the CWE-78 fix being ineffective. All of these claims are **demonstrably false** — verified by: (1) Python string trace showing exactly 2 properly-paired double quotes, (2) real bash shell tests confirming `$()`, backticks, `$HOME`, semicolons, and mixed injection payloads are all rendered literal. The specialists analyzed Python string representation without understanding shell quoting context.

### Reviewer (audit, round 3)
- TEA and Dev round 3 both logged "No deviations" — confirmed accurate. The quoting structure change is a security fix, not a spec deviation.
- No undocumented deviations found. Implementation matches all 5 ACs exactly.

### Reviewer (code review, round 3)
- **Improvement** (non-blocking): Two lint issues in test file — import sorting (I001) and unnecessary list comprehension at line 77 (C416). Affects `tests/python/test_147_10_saddle_summon.py` (run `ruff check --fix` to auto-resolve). *Found by Reviewer during code review.*

## Reviewer Assessment (round 3)

**Verdict:** APPROVED

| Severity | Issue | Location | Status |
|----------|-------|----------|--------|
| [LOW] [LINT] | Import block unsorted (I001) | `test_147_10_saddle_summon.py:12` | Non-blocking, auto-fixable |
| [LOW] [LINT] | Unnecessary list comprehension (C416) | `test_147_10_saddle_summon.py:77` | Non-blocking, auto-fixable |

**Round 2 findings — all resolved:**

| Finding | Severity | Round 3 Status |
|---------|----------|----------------|
| CWE-78 shlex.quote inside dquotes | CRITICAL | FIXED — double quote closes BEFORE task, shlex.quote at top level. Verified with 12 dangerous inputs in real bash: `$(echo INJECTED)` NOT executed, `$HOME` NOT expanded, backticks NOT executed, semicolons/pipes/redirects all literal. |
| Shell safety tests false positives | HIGH | FIXED — `_assert_task_outside_dquotes()` verifies structural pattern `Your task: "<shlex-quoted>` which correctly proves the closing `"` precedes the task |
| send_keys failure path untested | MEDIUM | FIXED — `test_send_keys_failure_returns_error` at line 328 |
| Module docstring missing summon | LOW | FIXED — `cli.py:1` now reads "start/stop/status/summon" |

**Data flow traced:** `task` (CLI `--task`) → `summon_agent(task=)` → `shlex.quote(task)` → placed AFTER closing `"` in command string → `_panes.send_keys()` → tmux sends keystrokes to shell → shell parses: `"$(pf agent start dev)\n\nYour task: "` (double-quoted, $() expands intentionally) + `'$(echo PWNED)'` (single-quoted at top level, NO expansion). SAFE.

**Pattern observed:** [VERIFIED] `summon_agent` correctly follows `start_agent` validation/state/pane pattern at `core.py:200-217`. Clean reuse, no unnecessary abstractions.

**Error handling:** [VERIFIED] All error paths return result dicts. `send_keys` failure returns error dict (line 234-235). Telemetry fire-and-forget (line 238-243). Matches module convention.

**Security analysis:** CWE-78 shell injection via task parameter is RESOLVED. Verified with real bash tests — 12 dangerous inputs all remain literal. Agent name safe via VALID_AGENTS whitelist.

**Wiring:** [VERIFIED] CLI `summon` command → `core.summon_agent()` → `ensure_saddle_pane()` → `_panes.send_keys()`. Properly wired end-to-end.

**Simplify findings (from TEA verify round 3):** Duplication between start_agent/summon_agent is real but beyond story scope — AGREED, not blocking. Consistently flagged across all 3 rounds.

**Hard questions:**
- Null/empty task? Empty string treated as no-task (line 221 `if task:`). Covered by test at line 218.
- All valid agents? Iterated and verified by test at line 435.
- tmux not running? Returns clear error. Covered by test at line 417.
- Concurrent summon? `stop_agent()` called first (line 212). Covered by test at line 379.

**Handoff:** To the Mad Hatter (SM) for finish-story.