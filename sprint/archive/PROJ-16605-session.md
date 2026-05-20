---
story_id: "150-4"
jira_key: null
epic: "150"
workflow: "tdd"
---
# Story 150-4: Auto-generate command files for custom agents on pf init

## Story Details
- **ID:** 150-4
- **Title:** Auto-generate command files for custom agents on pf init
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/150-4-auto-generate-command-files-custom-agents

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-04-03T12:09:19Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-04-03T11:49:30Z | 2026-04-03T11:50:37Z | 1m 7s |
| red | 2026-04-03T11:50:37Z | 2026-04-03T11:57:57Z | 7m 20s |
| green | 2026-04-03T11:57:57Z | 2026-04-03T12:00:01Z | 2m 4s |
| spec-check | 2026-04-03T12:00:01Z | 2026-04-03T12:01:07Z | 1m 6s |
| verify | 2026-04-03T12:01:07Z | 2026-04-03T12:04:14Z | 3m 7s |
| review | 2026-04-03T12:04:14Z | 2026-04-03T12:08:35Z | 4m 21s |
| spec-reconcile | 2026-04-03T12:08:35Z | 2026-04-03T12:09:19Z | 44s |
| finish | 2026-04-03T12:09:19Z | - | - |

## Story Context

**Description:**
During pf init, scan agents-local/ and generate corresponding .claude/commands/pf-{name}.md activation files. Also generate .claude/skills/pf-{name}/ if a skill template exists. Existing custom commands should not be clobbered.

**Acceptance Criteria:**
1. On `pf init`, detect all custom agents in .pennyfarthing/agents-local/
2. For each agent {name}, create or update .claude/commands/pf-{name}.md with proper activation syntax
3. Generate .claude/skills/pf-{name}/ directory if skills template exists for the agent
4. Do not overwrite existing custom command files (preserve user modifications)
5. Log generation results to pf init output

**Points:** 2
**Priority:** p1
**Depends On:** 150-1, 150-2, 150-3

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No upstream findings during test design.

### Reviewer (code review)
- **Improvement** (non-blocking): `generate_custom_agent_commands()` does not validate `agent_name` before interpolation into content. While the normal creation path (`pf agent create`) enforces `[\w][\w.-]*`, manually created files bypass this. Adding the same regex check would provide defense-in-depth against malformed filenames. Affects `pennyfarthing-dist/src/pf/init/core.py` (add validation after line 677). *Found by Reviewer during code review.*

## Sm Assessment

**Story 150-4** is ready for the RED phase. This is a 2-point TDD story in epic 150 (Custom Agent Creation System), building on the completed foundation of 150-1 (agents-local directory with loader), 150-2 (pf agent create CLI), and 150-3 (theme character extension).

**Scope:** During `pf init`, scan `agents-local/` for custom agent definitions and auto-generate corresponding command and skill files. Core concern is idempotent generation — don't clobber user modifications.

**Routing:** TDD workflow → TEA (the Caterpillar) writes failing tests for the init-time generation logic, then Dev (the White Rabbit) makes them pass.

**Risks:** None identified. Dependencies are all complete. Straightforward feature extension.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core feature with 5 ACs, all require test coverage

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_init_custom_agents.py` - 32 tests across 8 test classes

**Tests Written:** 32 tests covering 5 ACs
**Status:** RED (31 failing, 1 vacuously passing — ready for Dev)

**Test Classes:**
| Class | AC | Tests | Description |
|-------|-----|-------|-------------|
| TestDetectCustomAgents | AC1 | 5 | Scan agents-local/, filter .md only, handle empty/missing |
| TestGenerateCommandFiles | AC2 | 5 | Command file creation, frontmatter, activation syntax |
| TestGenerateSkillDirectories | AC3 | 4 | Skill dir when template exists, skip when absent |
| TestPreserveExistingCommands | AC4 | 4 | No-clobber for commands and skill dirs |
| TestLogGenerationResults | AC5 | 4 | Result dict structure with lists and counts |
| TestInitIntegration | AC1-5 | 2 | Wired into init_project, idempotent reruns |
| TestEdgeCases | - | 4 | Dots, underscores, many agents, missing dirs |
| TestRuleEnforcement | SOUL | 3 | Return results (SOUL#10), type annotations, pathlib |

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| SOUL #10 return results | `test_returns_result_dict_not_throws` | failing |
| Type annotations | `test_function_has_type_annotations` | failing |
| Pathlib over os.path | `test_uses_pathlib_not_string_paths` | failing |

**Rules checked:** 3 applicable rules have test coverage
**Self-check:** 0 vacuous tests found — all assertions are meaningful

**Root cause of failures:** `generate_custom_agent_commands` function does not exist in `pf.init.core`. All 31 failures are ImportError.

**Implementation guidance for Dev:**
1. Create `generate_custom_agent_commands(project_dir: Path) -> dict` in `pf/init/core.py`
2. Scan `.pennyfarthing/agents-local/*.md` for custom agents
3. Generate `.claude/commands/pf-{name}.md` with YAML frontmatter + `<agent-activation>` block containing `pf agent start "{name}"`
4. Check `.pennyfarthing/templates/skills/pf-{name}.md` for skill templates — create `.claude/skills/pf-{name}/` if present
5. Skip existing command files (no-clobber)
6. Wire into `init_project()` for both consumer and dogfooding modes
7. Return `{success, data: {generated_commands, preserved_commands, generated_skills}}`

**Handoff:** To Dev (the White Rabbit) for implementation

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found. TEA and Dev both logged "No deviations" — confirmed: implementation matches all 5 ACs directly.

### Architect (reconcile)
- No additional deviations found. TEA, Dev, and Reviewer all confirmed zero deviations. Implementation maps 1:1 to all 5 ACs. No context files exist for epic 150 or story 150-4 to reconcile against. No AC deferrals to verify.

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

AC-by-AC verification:
- **AC1** (detect agents): Implementation scans `agents-local/*.md` with proper file/suffix filtering. Aligned.
- **AC2** (generate commands): Produces YAML frontmatter + `<agent-activation>` block with `pf agent start "{name}"`, matching built-in command format. Aligned.
- **AC3** (skill directories): Conditionally creates `.claude/skills/pf-{name}/` only when template exists at `.pennyfarthing/templates/skills/pf-{name}.md`. Aligned.
- **AC4** (no-clobber): Checks `cmd_file.exists()` before writing, preserves existing skill dirs. Tracks preserved files in result. Aligned.
- **AC5** (logging): Returns structured `{generated_commands, preserved_commands, generated_skills}` and wires into both dogfooding and consumer return paths of `init_project()`. Aligned.

**Architectural observations:**
- Function is properly standalone (testable without init_project), follows SOUL #10 (return results, don't throw)
- Placement in `init/core.py` is correct — this is init-time generation, not runtime behavior
- No unnecessary abstractions introduced

**Decision:** Proceed to verify

## Dev Assessment

**Implementation:** `generate_custom_agent_commands()` added to `pennyfarthing-dist/src/pf/init/core.py`
**Status:** GREEN — 32/32 tests passing, 0 regressions in related test suites (48 tests in test_agents_local + test_agent_create)

**What was built:**
1. `generate_custom_agent_commands(project_dir: Path) -> dict` — standalone function that scans `.pennyfarthing/agents-local/*.md`, generates `.claude/commands/pf-{name}.md` with YAML frontmatter + `<agent-activation>` block, and creates `.claude/skills/pf-{name}/` from templates at `.pennyfarthing/templates/skills/`
2. Wired into `init_project()` — called after gitignore update, result included as `custom_agents` in both consumer and dogfooding return paths

**Design decisions:**
- No-clobber: existing command files and skill directories are preserved, tracked in `preserved_commands` list
- Command file format matches built-in commands (pf-dev.md pattern): frontmatter → agent-activation → instructions
- Skill template copied as-is into skill directory (no transformation)
- Missing `.claude/commands/` directory is auto-created

**Handoff:** To TEA (the Caterpillar) for verify phase

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 2

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 3 findings | Name formatting duplication (1-liner, dismiss), test fixture sharing (medium, dismiss), loop helper extraction (medium, dismiss) |
| simplify-quality | 3 findings | Error handling gaps in iterdir/write_text/copy2 (medium, dismiss — matches existing init_project pattern) |
| simplify-efficiency | 1 finding | Repeated mock stack in integration tests (medium, dismiss — explicit is better for test code) |

**Applied:** 0 high-confidence fixes
**Flagged for Review:** 0 medium-confidence findings (all dismissed with rationale)
**Noted:** 7 low/medium observations, all dismissed
**Reverted:** 0

**Dismissal rationale:**
- Reuse findings: One-liner display_name pattern doesn't warrant shared utility. Test fixtures are already well-structured. Loop body is single-use.
- Quality findings: Wrapping IO in try-except would be inconsistent with existing `init_project()` code paths (lines 450-474) which also call `shutil.copy2()` and `_copy_tree()` without error wrapping. Not a regression.
- Efficiency findings: Explicit mock stacks in tests are clearer than hidden fixture coupling.

**Overall:** simplify: clean

**Quality Checks:** 80/80 tests passing (32 story + 30 agents-local + 18 agent-create)
**Handoff:** To Reviewer (the Queen of Hearts) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Yes | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Yes | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 2 | dismissed 2 (see rationale below) |
| 8 | reviewer-simplifier | Yes | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (2 enabled returned, 7 disabled/skipped)
**Total findings:** 0 confirmed, 2 dismissed (with rationale), 0 deferred

### Security Subagent Findings — Dismissal Rationale

**[SEC] Finding 1 — Path traversal via agent_name (medium confidence):** DISMISSED. The subagent claims filenames can contain `/` on POSIX systems. This is factually incorrect — `/` is the ONE character prohibited in filenames on all POSIX filesystems. `Path.iterdir()` returns actual filesystem entries; `.stem` of those entries cannot produce path traversal components. The attack vector does not exist.

**[SEC] Finding 2 — Content injection via agent_name (medium confidence):** DISMISSED as non-blocking, but logged as Improvement finding. Filenames can technically contain `"` and newlines, which would produce malformed content in the generated command file. However: (a) the generated content is markdown consumed by Claude, not directly executed by bash; (b) the attacker must have write access to `agents-local/`, which grants equivalent power via editing agent definitions directly; (c) the standard creation path `pf agent create` already validates names. This is a defense-in-depth hardening opportunity, not a vulnerability. Logged as non-blocking Improvement in Delivery Findings.

## Reviewer Assessment

**Verdict:** APPROVED

### Observations

1. [VERIFIED] `generate_custom_agent_commands()` returns result dict, never throws — `core.py:634` returns `{success: True, data: {...}}` on all paths. Early return on missing dir at line 659. Complies with SOUL #10.

2. [VERIFIED] No-clobber logic correct — `core.py:681` checks `cmd_file.exists()` before writing, routes to `preserved_commands` list. Skill dirs checked at line 715 with `skill_dir.is_dir()`. Existing user files are never touched.

3. [VERIFIED] Command file format matches built-in pattern — generated content at lines 689-704 follows same structure as `pf-dev.md`: YAML frontmatter → `<agent-activation>` → `<instructions>`. Consistent with SOUL #2 (One Truth, One Place — same pattern, one format).

4. [VERIFIED] Integration wiring correct — `core.py:541-542` calls `generate_custom_agent_commands(target_dir)` and extracts data. Result included in both dogfooding (line 559) and consumer (line 580) return paths as `custom_agents` key.

5. [VERIFIED] File filtering correct — `core.py:674` filters with `agent_file.is_file() and agent_file.suffix == ".md"`, excluding directories and non-markdown files. `sorted()` at line 673 ensures deterministic order.

6. [SEC] [LOW] agent_name not validated before content interpolation — `core.py:677` uses `agent_file.stem` directly. Security subagent flagged path traversal (dismissed — filesystem prevents `/` in filenames) and content injection (dismissed — markdown consumed by Claude, not shell-executed; same trust boundary as agent definitions). Defense-in-depth regex (matching `pf agent create`'s `[\w][\w.-]*` pattern) would guard against exotic filenames. Non-blocking — logged as Improvement.

### Data Flow Trace
`agents_local.iterdir()` → filter `.md` files → `agent_file.stem` → `f"pf-{agent_name}.md"` path construction → `cmd_file.write_text(content)`. Safe because: filesystem prevents `/` in stems, `pf-` prefix ensures files stay in commands dir, content is markdown not shell.

### Error Handling
Missing dir → early return with empty success result (line 659). Write failures would propagate as exceptions — consistent with existing `init_project()` pattern where `shutil.copy2` and `_copy_tree` also lack try/except wrappers.

### Rule Compliance
- SOUL #10 (Return results): Compliant — function returns dict on all paths
- SOUL #2 (One truth): Compliant — command file format mirrors built-in pattern
- SOUL #9 (Python owns runtime): Compliant — pure Python implementation in pf/init/

### Devil's Advocate

What if this code is broken? Let me argue the case.

The most credible failure mode is **idempotency under concurrent init runs**. If two `pf init` processes run simultaneously, both could check `cmd_file.exists()` → False, then both write the file. The last writer wins. This is harmless — both would write identical content since the agent definition hasn't changed. The only data race produces the same output, so it's benign.

A more interesting failure: **what if `agents-local/` contains hundreds of files?** The function iterates all of them synchronously, writing files for each. For 100 agents, that's 100+ filesystem writes during init. This could slow init noticeably on slow filesystems (NFS, encrypted volumes). But `init_project()` already performs bulk copies of all content dirs, commands, and skills — this adds marginal overhead proportional to custom agent count, which is typically 1-5.

What about **the skill template path convention**? The function looks for templates at `.pennyfarthing/templates/skills/pf-{name}.md`. This path is not documented in CLAUDE.md or any guide. A user creating a custom agent wouldn't know to put a skill template there without reading the source code. This is a discoverability gap but not a code bug — it's a documentation gap that story 150-5 (Custom agent stepped workflow) will likely address.

What if a user **manually creates an agent file without using `pf agent create`** and gives it a name that conflicts with a built-in agent? E.g., creates `agents-local/dev.md`. The function would generate `pf-dev.md` which already exists as a built-in command. The no-clobber check (`cmd_file.exists()`) protects against this — the built-in command is preserved. But the user wouldn't get feedback that their custom agent was skipped. This is acceptable — the custom agent still loads via the loader priority chain (agents-local beats agents), it just doesn't get a generated command file because one already exists.

None of these scenarios produce critical or high-severity issues. The devil's advocate found no hidden bombs.

**Handoff:** To SM (the Mad Hatter) for finish-story