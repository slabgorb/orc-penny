# Story: MSSCI-14299 - Wire up stepped workflow session state advancement

**Jira:** MSSCI-14299
**Epic:** MSSCI-14298 - Stepped Workflow Infrastructure
**Points:** 5
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14299-stepped-workflow-state-advancement
**Started:** 2026-02-05T19:00:00.000Z

## Acceptance Criteria
- [ ] Session file Current Step increments when a step completes
- [ ] Session file Steps Completed array populates correctly
- [ ] Session file Status changes to completed when all steps done
- [ ] Completion percentage updates in session file
- [ ] Works for all stepped workflows (epics-and-stories, prd, research, etc.)

## Technical Context

The framework has a complete TypeScript API for stepped workflow state management in `packages/core/src/workflow/` but nothing invokes it at runtime. The key gap:

**What exists:**
- `session-state.ts` provides `parseSessionState()`, `updateSessionContent()`, `updateWorkflowState()`, and `formatWorkflowState()` for reading/writing a `## Workflow State` markdown section in session files
- `workflow-executor.ts` provides `completeStep()` which parses state, calls `updateWorkflowState()`, and writes back to session content
- `step-parser.ts` parses step files with `<step-meta>` YAML blocks and `<!-- GATE -->` markers
- Full test coverage exists for all the above (session-state.test.ts, workflow-executor.test.ts)

**What is missing:**
- No CLI command/script exposes `completeStep()` for invocation
- No HTTP endpoint on WheelHub server for step advancement
- No skill definition that agents can call to advance steps
- No hook that fires automatically after a step executes
- The `index.ts` barrel export does NOT re-export session-state or workflow-executor modules
- The `/workflow` command references start/resume/status but has no step-completion mechanism

**15 stepped workflows affected:** architecture, brainstorming, code-review, dev-story, epics-and-stories, git-cleanup, implementation-readiness, interactive-debug, prd, product-brief, project-context, project-setup, quick-dev, quick-spec, release, research, retrospective, sprint-planning, ux-design

**Fix approach:** Expose step completion via a mechanism Claude can invoke -- likely a CLI script (in `pennyfarthing_scripts/` or `pennyfarthing-dist/scripts/`) or a skill definition, so that session state updates as steps complete.

## Key Files

- `pennyfarthing/packages/core/src/workflow/session-state.ts` - State read/write (parseSessionState, updateSessionContent, formatWorkflowState)
- `pennyfarthing/packages/core/src/workflow/session-state.test.ts` - Existing tests for state tracking
- `pennyfarthing/packages/core/src/workflow/workflow-executor.ts` - completeStep(), startWorkflow(), resumeWorkflow(), getWorkflowStatus()
- `pennyfarthing/packages/core/src/workflow/workflow-executor.test.ts` - Existing executor tests
- `pennyfarthing/packages/core/src/workflow/step-parser.ts` - Step file parsing
- `pennyfarthing/packages/core/src/workflow/index.ts` - Module barrel (needs expansion)
- `pennyfarthing/pennyfarthing-dist/commands/workflow.md` - /workflow command
- `pennyfarthing/pennyfarthing-dist/workflows/epics-and-stories/workflow.yaml` - Example stepped workflow
- `pennyfarthing/pennyfarthing-dist/workflows/prd/workflow.yaml` - Example tri-modal stepped workflow

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (33 tests failing — ready for Dev)

**Test Files:**
- `tests/unit/test_complete_step.sh` — 23 bash tests (20 failing, 3 passing baselines)
- `packages/core/src/workflow/complete-step-integration.test.ts` — 15 TypeScript tests (13 failing, 2 passing baselines)

**Tests Written:** 33 tests covering all 5 ACs

| AC | Tests | Category |
|----|-------|----------|
| AC1: Current Step increments | 3 bash | Step advancement |
| AC2: Steps Completed array | 4 bash | Array population + idempotency |
| AC3: Status → completed | 4 bash | Status transition |
| AC4: Completion % updates | 4 bash | Percentage calculation + timestamp |
| AC5: All workflows | 3 bash | Cross-workflow + auto-detect |
| Barrel exports (session-state) | 5 TS | Module re-exports |
| Barrel exports (executor) | 6 TS | Module re-exports |
| CLI script exists | 2 TS | File existence + executable |
| End-to-end functional | 2 TS | completeStep() behavior verification |
| Edge cases | 3 bash | Error handling |

**Implementation Requirements for Dev:**

1. **Create `pennyfarthing-dist/scripts/workflow/complete-step.sh`** — bash script following the pattern of `start-workflow.sh` and `resume-workflow.sh`:
   - Accept optional workflow name arg (auto-detect from session if not given)
   - Read session file, extract current step and steps completed
   - Increment current step, add completed step to array
   - Update `## Workflow State` section (Current Step, Steps Completed, Last Updated)
   - Update `## Progress` section (Completion %)
   - Set Status to `completed` when all steps are done
   - Output next step content (or completion message)

2. **Update `packages/core/src/workflow/index.ts`** — add re-exports for:
   - From `session-state.js`: `initWorkflowState`, `parseSessionState`, `updateSessionContent`, `updateWorkflowState`, `formatWorkflowState`, `WorkflowState`, `SessionStateResult`, `UpdateResult`
   - From `workflow-executor.js`: `completeStep`, `startWorkflow`, `resumeWorkflow`, `getWorkflowStatus`, `hasActiveWorkflow`, `detectIncompleteWorkflow`, `WorkflowDefinition` (executor version), `StartResult`, `ResumeResult`, `WorkflowStatus`, `StatusResult`

3. **Key design note:** The existing `completeStep()` in workflow-executor.ts does NOT auto-set status to `completed` — it only updates stepsCompleted and currentStep. The bash script must detect when all steps are done (stepsCompleted.length >= totalSteps) and set status accordingly via sed.

**Handoff:** To Major Winchester (Dev) for implementation

## Dev Assessment (Round 1)

**Status:** GREEN (all 38 tests passing, 93 existing tests pass)
**PR:** https://github.com/1898andCo/pennyfarthing/pull/681

**Changes Made:**
1. `pennyfarthing-dist/scripts/workflow/complete-step.sh` (new, 186 lines)
   - Follows pattern of sibling scripts (start-workflow.sh, resume-workflow.sh)
   - Accepts optional workflow name (auto-detects from session)
   - Supports `--step N` for explicit step number
   - Updates all session state fields via sed
   - Handles completion detection (stepsCompleted count >= totalSteps)
   - Outputs next step content or completion message

2. `packages/core/src/workflow/index.ts` (modified)
   - Added re-exports for session-state: initWorkflowState, updateWorkflowState, parseSessionState, updateSessionContent, formatWorkflowState + types
   - Added re-exports for workflow-executor: completeStep, startWorkflow, resumeWorkflow, getWorkflowStatus, loadStep, hasActiveWorkflow, detectIncompleteWorkflow + types
   - Resolved WorkflowDefinition naming conflict via `ExecutorWorkflowDefinition` alias

3. `packages/core/src/workflow/complete-step-integration.test.ts` (fixed)
   - Corrected path resolution from 5 levels up to 4 levels up

**Handoff:** To Avasarala (Reviewer) for code review

## Dev Assessment (Round 2 — post-review fix)

**Status:** GREEN (23/23 bash tests pass, TypeScript clean)
**PR:** https://github.com/1898andCo/pennyfarthing/pull/681

**Reviewer Issues Addressed:**
- [HIGH] Rewrote `complete-step.sh` → `complete-step.py` using Python, pathlib, re, yaml
- [MEDIUM] `--step N` now validated via argparse `type=int` (clean error on non-numeric)
- [MEDIUM] No more regex injection — Python uses `re.findall(r"\d+")` for array parsing
- [LOW] No more `sed -i ''` — cross-platform `Path.write_text()` instead

**Changes Made:**
1. `pennyfarthing-dist/scripts/workflow/complete-step.py` (new, replaces .sh)
   - Python with `#!/usr/bin/env python3`, follows pattern of `check.py` and `get-workflow-type.py`
   - Uses `pathlib.Path` for all file operations (cross-platform)
   - Uses `re.sub()` with `re.MULTILINE` for session state updates (no sed)
   - Uses `argparse` with `type=int` for `--step` validation
   - Honors `PROJECT_ROOT` env var (test harness compatibility)
   - Uses `yaml.safe_load()` for workflow YAML parsing

2. `pennyfarthing-dist/scripts/workflow/complete-step.sh` (deleted)

3. `tests/unit/test_complete_step.sh` (updated references to .py)

4. `packages/core/src/workflow/complete-step-integration.test.ts` (updated references to .py)

**Handoff:** To Avasarala (Reviewer) for re-review

## Reviewer Assessment

**Verdict:** REJECTED

| # | Severity | Issue | Location |
|---|----------|-------|----------|
| 1 | [HIGH] | CLI script must be Python, not bash. User explicitly requested Python. Python siblings exist in same directory (`check.py`, `get-workflow-type.py`). Bash `sed -i ''` is macOS-only and fragile for markdown parsing. | `pennyfarthing-dist/scripts/workflow/complete-step.sh` |
| 2 | [MEDIUM] | No numeric validation on `--step N` argument. Non-numeric values produce confusing bash arithmetic error. | `complete-step.sh:126,162` |
| 3 | [MEDIUM] | User input injected into regex via `grep -qE` without escaping. Mitigated by arithmetic abort but fragile. | `complete-step.sh:152` |
| 4 | [LOW] | `sed -i ''` is macOS-only. GNU sed requires `sed -i` without empty string arg. | `complete-step.sh:188-194` |
| 5 | [VERIFIED] | Barrel exports correct — all session-state and workflow-executor symbols re-exported. WorkflowDefinition conflict handled via alias. | `index.ts:50-78` |
| 6 | [VERIFIED] | Integration test path resolution fix correct (4 levels up). | `complete-step-integration.test.ts:131` |
| 7 | [VERIFIED] | CI green: build, lint, benchmark pass. 23/23 bash tests pass. TypeScript clean. |

**Data flow traced:** CLI args → session file lookup (find/explicit) → grep/sed field extraction → arithmetic step advancement + completion % → sed write-back → stdout next step content. Flow is correct but implementation language must change.

**Blocking:** Issue #1 (HIGH) — rewrite `complete-step.sh` as `complete-step.py` using `pennyfarthing_scripts` infrastructure. Tests (`test_complete_step.sh`) will also need updating to invoke the Python script.

**Approved changes:** `index.ts` barrel exports and `complete-step-integration.test.ts` path fix are good to keep.

**Handoff:** Back to Naomi (Dev) for Python rewrite

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

| # | Observation | Location |
|---|-------------|----------|
| 1 | [VERIFIED] Round 1 HIGH resolved: Script rewritten from bash to Python. Uses pathlib, re.sub, argparse, yaml.safe_load. | `complete-step.py` |
| 2 | [VERIFIED] Round 1 MEDIUM resolved: `--step N` uses argparse type=int — clean error on non-numeric. | `complete-step.py:153` |
| 3 | [VERIFIED] Round 1 MEDIUM resolved: Array parsing uses `re.findall(r"\d+")` — no regex injection. | `complete-step.py:114` |
| 4 | [VERIFIED] Round 1 LOW resolved: Uses Path.write_text() — cross-platform, no sed. | `complete-step.py:264` |
| 5 | [VERIFIED] parse_session_field uses re.escape(field) — safe against special chars. | `complete-step.py:48` |
| 6 | [VERIFIED] All re.sub replacements use safe types (ints, formatted arrays, timestamps, literal strings). | `complete-step.py:237-261` |
| 7 | [VERIFIED] re.sub patterns scoped to `^- \*\*` prefix — won't match assessment sections. |
| 8 | [VERIFIED] Barrel exports unchanged from round 1 (already approved). | `index.ts:50-78` |
| 9 | [VERIFIED] CI all green: build, lint, Python CLI benchmark all SUCCESS. 23/23 tests pass. TypeScript clean. |
| 10 | [LOW] import os inside find_project_root() rather than top level. Not blocking. | `complete-step.py:31` |

**Data flow traced:** sys.argv → argparse (validates --step as int) → find_project_root() (env or walk) → find_session_file() (glob or explicit) → read_text() → parse_session_field() (re.escape) → arithmetic → re.sub() multiline → write_text(). Clean end-to-end.

**Handoff:** Merging PR, then to Drummer (SM) for finish-story
