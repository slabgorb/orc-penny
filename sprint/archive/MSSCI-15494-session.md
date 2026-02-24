# Story 126-6: Frontmatter hooks on all agents and skills
**Jira:** MSSCI-15494
**Epic:** 126 — Python-First Installation
**Points:** 5
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/126-6-frontmatter-hooks-agents-skills
**Assigned:** keith.avery@1898andco.io

## Acceptance Criteria
- All agent .md files have frontmatter hooks for their lifecycle
- Relevant skill directories have frontmatter hooks
- settings.local.json reduced to 5 infrastructure hooks
- No functional regression — all hooks still fire correctly

## Context
This story consolidates component-specific hooks from settings.local.json into frontmatter defined in agent and skill files. Currently settings.local.json contains 13 hooks; after this work it should only contain 5 infrastructure-only hooks. This is part of the Python-first installation epic that simplifies Pennyfarthing configuration and initialization.

## Technical Approach
The work involves:
1. Adding frontmatter hook definitions to all agent .md files in `pennyfarthing-dist/agents/`
2. Adding frontmatter hooks to relevant skill directories in `pennyfarthing-dist/skills/`
3. Removing component-specific hooks from the settings.local.json template, keeping only 5 infrastructure hooks
4. Testing that all hooks fire correctly during agent lifecycle and skill operations

## SM Assessment — Setup Phase
- Story claimed in Jira (MSSCI-15494), moved to In Progress
- Session file created with ACs, context, and technical approach
- Feature branch `feature/126-6-frontmatter-hooks-agents-skills` created from develop in pennyfarthing repo
- Workflow: tdd (5 pts) — routes to TEA (Igor) for red phase
- Key risk: Hook migration must be regression-free; existing hook behavior must be preserved
- Handoff to TEA for test design

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core architectural change — hooks moving from centralized settings to distributed frontmatter

**Test Files:**
- `tests/python/test_frontmatter_hooks.py` — 34 tests covering all 4 ACs
- `pennyfarthing-dist/src/pf/hooks/frontmatter.py` — stub module with interfaces

**Tests Written:** 34 tests covering 4 ACs
**Status:** RED (18 failing on assertions — verified clean RED state)

**Architecture Notes for Dev:**
- 5 infrastructure hooks defined in `init/core.py` `_MINIMAL_SETTINGS`: session-start, session-stop, pre-edit-check, context-warning, bell-mode
- 8 component hooks to move into agent/skill frontmatter: setup-env, auto-load-sm, reflector-check, cyclist-pretooluse, context-breaker, schema-validation, sprint-yaml, statusline
- Stub module at `pf/hooks/frontmatter.py` defines expected interface: `parse_frontmatter()`, `parse_agent_hooks()`, `parse_skill_hooks()`, `collect_all_frontmatter_hooks()`, `to_settings_format()`, `merge_with_infrastructure()`, `count_hooks_in_settings()`
- Agent frontmatter format: YAML `hooks:` key grouped by event type (SessionStart, Stop, PreToolUse, PostToolUse)
- Agent validator in `validate/adapters/agent.py` uses frontmatter to classify main vs subagent — will need updating
- `_MINIMAL_SETTINGS` in `init/core.py` already matches the 5-hook target

**Handoff:** To Ponder Stibbons (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**All Tests Passing:** Yes — 34/34 frontmatter hook tests GREEN

**Changes Made:**

1. **`pf/hooks/frontmatter.py`** — Full implementation of frontmatter hook parsing module:
   - `parse_frontmatter()` — Extract YAML between `---` delimiters
   - `parse_agent_hooks()` / `parse_skill_hooks()` — Parse hooks from agent/skill files
   - `collect_all_frontmatter_hooks()` — Scan agents/ and skills/ directories, deduplicate
   - `to_settings_format()` — Convert to Claude Code settings structure
   - `merge_with_infrastructure()` — Deep merge with deduplication
   - `count_hooks_in_settings()` — Count total hook entries

2. **11 agent .md files** — Added frontmatter hooks to all main agents (sm, tea, dev, reviewer, architect, pm, tech-writer, ux-designer, devops, orchestrator, ba):
   - `PreToolUse`: `pf hooks schema-validation` (matcher: Write)
   - `Stop`: `pf hooks reflector-check`

3. **`skills/pf-sprint/SKILL.md`** — Added hooks to existing frontmatter:
   - `PostToolUse`: `pf hooks sprint-yaml` (matcher: Edit|Write)

4. **`validate/adapters/agent.py`** — Updated agent classifier:
   - Added `_is_subagent_frontmatter()` — checks for `name` + `tools` fields
   - Main agents with hooks-only frontmatter correctly classified as main (not subagent)

**Pre-existing Issues (not caused by this story):**
- Agent validator tests show 2 failures: `tea.md` missing `<critical>`, `tech-writer.md` missing `<helpers>`, `tandem-backseat.md` missing multiple sections. Verified via `git stash` that these sections were absent before our changes.

**Commits:**
- `test: add failing tests for frontmatter hooks (126-6)` (TEA)
- `feat(hooks): implement frontmatter hook declarations for agents and skills (126-6)` (Dev)

**Branch:** `feature/126-6-frontmatter-hooks-agents-skills` — pushed to origin

**Handoff:** To Reviewer (Granny Weatherwax) for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Case-sensitive filesystem bug: `SKILL.md` hardcode misses 9/24 lowercase `skill.md` files on Linux | `frontmatter.py:177` | Check both casings or use case-insensitive match |
| [MEDIUM] | Mutation hazard: returns original dict (not copy) when frontmatter_hooks is empty | `frontmatter.py:226-227` | Always deepcopy before return |
| [LOW] | Dead code: `FrontmatterHooks` dataclass never used | `frontmatter.py:41-45` | Remove |

**Data flow traced:** Agent content → `parse_frontmatter()` → `parse_agent_hooks()` → `collect_all_frontmatter_hooks()` → `merge_with_infrastructure()` → settings dict. Sound except skill file lookup bug.

**Handoff:** Back to Dev (Ponder Stibbons) for fixes

## Dev Assessment (Review Fixes)

**All three review findings addressed:**
1. **[HIGH] Case-sensitive skill lookup** — Added fallback from `SKILL.md` to `skill.md` at `frontmatter.py:177`
2. **[MEDIUM] Mutation hazard** — Moved `deepcopy` before the early return at `frontmatter.py:226`
3. **[LOW] Dead code** — Removed unused `FrontmatterHooks` dataclass and `field` import

**Tests:** 34/34 passing (GREEN)
**Commit:** `fix(hooks): address review findings for frontmatter hooks (126-6)`
**Branch:** pushed to origin

**Handoff:** Back to Reviewer (Granny Weatherwax) for re-review

## Reviewer Assessment (Re-review)

**Verdict:** APPROVED

**Previous findings — all verified fixed:**
| # | Severity | Finding | Verification |
|---|----------|---------|-------------|
| 1 | [HIGH] | Case-sensitive skill lookup | Fallback `SKILL.md` → `skill.md` at `frontmatter.py:169-172` |
| 2 | [MEDIUM] | Mutation hazard in merge | `deepcopy` before early return at `frontmatter.py:220-222` |
| 3 | [LOW] | Dead `FrontmatterHooks` class | Removed, clean imports |

**New observations:**
| # | Tag | Observation | Location |
|---|-----|-------------|----------|
| 1 | [VERIFIED] | Data flow: frontmatter YAML → parse → HookDeclaration → settings format. No input mutation | `frontmatter.py:44-201` |
| 2 | [VERIFIED] | `yaml.safe_load()` — no code execution risk | `frontmatter.py:57` |
| 3 | [VERIFIED] | Agent adapter correctly distinguishes hook-only vs subagent frontmatter | `agent.py:63-65` |
| 4 | [VERIFIED] | Cross-file dedup by (event, command, matcher) tuple | `frontmatter.py:144-151` |
| 5 | [VERIFIED] | Error handling: missing dirs, malformed YAML, None/empty inputs | Throughout |
| 6 | [LOW] | `merge_with_infrastructure` dedup uses command-only matching (not command+matcher). Theoretical only — hook sets are disjoint | `frontmatter.py:228-236` |
| 7 | [VERIFIED] | 34/34 tests GREEN, all 4 ACs covered | `test_frontmatter_hooks.py` |

**Pre-existing issue (not blocking):** `test_bellmode_tandem_injection.py` ImportError on develop.

**Handoff:** To Captain Carrot (SM) for finish-story