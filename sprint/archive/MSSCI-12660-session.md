# Session: MSSCI-12660 - Update agent command files to use Python CLI

## Story Information

| Field | Value |
|-------|-------|
| **Story ID** | MSSCI-12660 |
| **Jira Key** | MSSCI-12660 |
| **Title** | Update agent command files to use Python CLI |
| **Epic** | MSSCI-12655 (Pennyfarthing Python CLI) |
| **Points** | 2 |
| **Workflow** | trivial |
| **Assignee** | keith.avery |
| **Repos** | pennyfarthing |
| **Branch** | feat/MSSCI-12660-agent-python-cli |

## Session State

| Field | Value |
|-------|-------|
| **Phase** | approved |
| **Owner** | SM |
| **Created** | 2026-01-30 |

## Phase History

| Phase | Agent | Status | Notes |
|-------|-------|--------|-------|
| setup | SM | complete | Session created, Jira claimed, branch ready |
| implement | Dev | complete | 15 files updated, PR #560 |
| review | Reviewer | complete | APPROVED - no blocking issues |

## Acceptance Criteria

- [x] All agent commands use Python CLI invocation
- [x] Bash scripts remain available as fallback

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/commands/sm.md` - Use Python CLI
- `pennyfarthing-dist/commands/dev.md` - Use Python CLI
- `pennyfarthing-dist/commands/tea.md` - Use Python CLI
- `pennyfarthing-dist/commands/reviewer.md` - Use Python CLI
- `pennyfarthing-dist/commands/architect.md` - Use Python CLI
- `pennyfarthing-dist/commands/orchestrator.md` - Use Python CLI
- `pennyfarthing-dist/commands/pm.md` - Use Python CLI
- `pennyfarthing-dist/commands/devops.md` - Use Python CLI
- `pennyfarthing-dist/commands/tech-writer.md` - Use Python CLI
- `pennyfarthing-dist/commands/ux-designer.md` - Use Python CLI
- `pennyfarthing-dist/commands/health-check.md` - Use Python CLI
- `pennyfarthing-dist/commands/parallel-work.md` - Use Python CLI
- `pennyfarthing-dist/commands/set-theme.md` - Use Python CLI
- `pennyfarthing-dist/commands/work.md` - Use Python CLI
- `pennyfarthing-dist/commands/prime.md` - Updated documentation

**Tests:** N/A (trivial workflow, no tests required for markdown file changes)
**PR:** #560 - feat(MSSCI-12660): update agent commands to use Python CLI
**Branch:** feat/MSSCI-12660-agent-python-cli (pushed)

**Handoff:** To Heimdall (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. `[VERIFIED]` All 15 command files correctly use `python3 -m pennyfarthing_scripts.cli agent start "<name>"`
2. `[VERIFIED]` Python CLI works correctly and returns context (tested with `--json`)
3. `[VERIFIED]` No Python code changes - markdown only
4. `[LOW]` parallel-work.md changed agent from "parallel-work" to "sm" - correct, no parallel-work agent
5. `[LOW]` set-theme.md refresh loads "sm" instead of dynamic agent (cosmetic)
6. `[VERIFIED]` Documentation in prime.md correctly reflects Python CLI
7. `[PRE-EXISTING]` Phase parsing issue with table format not in this PR scope

**Data flow:** `/sm` → bash → `python3 -m pennyfarthing_scripts.cli agent start "sm"` → `prime()` → context output ✓

**Security:** No issues - local command execution only

**Handoff:** To Baldur the Bright (SM) for story completion

## Epic Context

See: [sprint/context/context-epic-67.md](../sprint/context/context-epic-67.md)

### Summary

This story is part of Epic 67 (Pennyfarthing Python CLI) which creates a unified CLI entry point using Click. The preceding stories in Phase 1 established:

- MSSCI-12656: Click dependency and CLI entry point (`pf` command)
- MSSCI-12657: `pf workflow check` command
- MSSCI-12658: `pf workflow phase-check` command
- MSSCI-12659: `pf agent start` command

This story (MSSCI-12660) updates the agent command files (sm.md, dev.md, tea.md, reviewer.md, etc.) to invoke the Python CLI instead of bash scripts. The bash scripts remain as fallback.

## Notes

- Branch created in pennyfarthing repo: `feat/MSSCI-12660-agent-python-cli`
- Jira ticket claimed and assigned to keith.avery
