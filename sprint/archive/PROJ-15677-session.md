# Story 131-1: Update sm-setup-exit Gate with Context Validation Cascade

## Story Details
- **ID:** 131-1
- **Jira Key:** PROJ-15677
- **Workflow:** trivial
- **Assigned:** keith.avery@slabgorb.io
- **Points:** 2
- **Priority:** P1

## Description
Update the sm-setup exit gate to include context validation cascade checks. This enhancement validates that all required context is available before proceeding to the next phase.

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-26T11:29:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-26T11:18:33Z | 2026-02-26T11:19:09Z | 36s |
| implement | 2026-02-26T11:19:09Z | 2026-02-26T11:25:29Z | 6m 20s |
| review | 2026-02-26T11:25:29Z | 2026-02-26T11:29:00Z | 3m 31s |
| finish | 2026-02-26T11:29:00Z | - | - |

## Work Context
- **Repository:** pennyfarthing
- **Branch:** feat/131-1-update-sm-setup-exit-gate
- **Base Branch:** develop

## SM Assessment

**Story:** Update sm-setup-exit Gate with Context Validation (2pts, trivial)
**Repos:** pennyfarthing (branch: `feat/131-1-update-sm-setup-exit-gate`)
**Scope:** Enhance the sm-setup-exit gate to validate context files exist before allowing handoff from SM setup phase.
**Routing:** trivial → Dev (implement phase) for implementation, then Reviewer.
**Risk:** Low — gate enhancement, no breaking changes. Existing gate behavior preserved.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/gates/sm-setup-exit.md` — replaced `story-context-exists` check (#3) with `epic-context-validated` (#3) and `story-context-validated` (#4), renumbered `branch-created` to #5. Added fallback behavior for when `pf context-docs` CLI is not yet available. Updated recovery actions to reference `/pf-context create` commands.

**Key design decisions:**
- Added fallback for each context check (file existence) when CLI unavailable — prevents gate from blocking all work until 129-3 is merged to develop
- Story context check accepts SM Assessment as alternative to dedicated context file — not all stories have separate context docs
- Recovery actions are now actionable: "Run `/pf-context create epic {N}`" instead of vague "Write context"

**Tests:** Gate is a markdown definition — no unit tests. Verified manually that XML structure is valid and check names match GATE_RESULT YAML.
**Branch:** feat/131-1-update-sm-setup-exit-gate (pushed)

**Note:** Dependency `pf context-docs validate` CLI (from 129-3) exists on `feature/129-3-context-validator` branch but was never merged to develop. Branches 129-3 and 129-4 need merging for full cascade to work.

**Handoff:** To Reviewer (Granny Weatherwax) for review

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | Gate structure valid — XML tags properly formed, model=haiku preserved | `sm-setup-exit.md:1` |
| [VERIFIED] | GATE_RESULT consistency — 5 checks in both pass/fail blocks, names match | `sm-setup-exit.md:56-77,83-110` |
| [MEDIUM] | Fallback detection ambiguity — "if pf context-docs is not available" relies on implicit LLM reasoning to distinguish exit-2-command-not-found from exit-2-file-not-found | `sm-setup-exit.md:33-34` |
| [LOW] | "Technical approach" in story context fallback is vague | `sm-setup-exit.md:46-48` |
| [VERIFIED] | Recovery actions reference real `/pf-context create` skill | `sm-setup-exit.md:107-108` |
| [VERIFIED] | No breaking changes to checks #1 and #2 | `sm-setup-exit.md:16-22` |
| [LOW] | Acceptance criteria check dropped — acceptable since ACs live in sprint YAML/Jira | n/a |

**Data flow:** Gate markdown → Haiku subagent → GATE_RESULT YAML → handoff system. Check names are reporting-only; renaming is safe.
**Error handling:** Fallback to file-existence checks when CLI unavailable. Correct degradation.
**Security:** No concerns — gate definition only, no executable code.

**Handoff:** To SM (Captain Carrot) for finish-story