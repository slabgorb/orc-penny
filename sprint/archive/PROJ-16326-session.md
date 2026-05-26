# Session: 142-2

**Story:** 142-2 — BMAD Simulator CLAUDE.md Template and Story File
**Jira:** PROJ-16326
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/142-2-bmad-simulator-template
**Assigned:** slabgorb@gmail.com

## Context

- Epic context: `sprint/context/context-epic-142.md`
- Story context: `sprint/context/context-story-142-2.md`
- ADR: `docs/adr/0035-bmad-comparison-methodology.md`

## Story

As a benchmark engineer, I want a CLAUDE.md template that faithfully reproduces what a BMAD dev agent would see, so that the BMAD pipeline run uses BMAD's actual instructions without PF contamination.

**Points:** 2
**Priority:** P1

## Acceptance Criteria

**Given** the BMAD dev agent definition at `BMAD-METHOD/src/bmm/agents/dev.agent.yaml`
**And** the dev workflow at `BMAD-METHOD/src/bmm/workflows/4-implementation/dev-story/workflow.md`
**And** the checklist at `BMAD-METHOD/src/bmm/workflows/4-implementation/dev-story/checklist.md`
**When** the BMAD dev CLAUDE.md template is built
**Then** it contains the full agent definition (persona, critical_actions, principles) from `dev.agent.yaml`
**And** it contains the full `workflow.md` content verbatim (10-step dev workflow with XML tags)
**And** it contains the full `checklist.md` content verbatim (Definition of Done)
**And** it contains the story file content (translated from scenario context)
**And** it contains `project-context.md` content from the target project
**And** it contains NO Pennyfarthing persona, sidecars, workflow engine context, or session metadata

**Given** the BMAD reviewer workflow at `BMAD-METHOD/src/bmm/workflows/4-implementation/code-review/workflow.md`
**And** the code review checklist at `BMAD-METHOD/src/bmm/workflows/4-implementation/code-review/checklist.md`
**When** the BMAD reviewer CLAUDE.md template is built
**Then** it contains the adversarial review instructions verbatim (5-step workflow)
**And** it contains the review checklist verbatim
**And** it contains NO Pennyfarthing reviewer agent definition or sidecars

**Given** a Peloton scenario's epic and story context documents
**When** the story file is created for the BMAD dev agent
**Then** it follows BMAD's `create-story/template.md` structure
**And** a `story_path` is provided in the prompt so BMAD's step 1 skips sprint-status lookup

## Delivery Findings

<!-- Delivery findings from agents -->
### TEA (test design)
- No upstream findings during test design.

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## TEA Assessment

**Tests Required:** Yes
**Reason:** AC1-AC3 require verifiable template output and contamination checks

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_bmad_adapter.py` — 28 tests across 4 test classes

**Tests Written:** 28 tests covering 3 ACs
- AC1 (Dev CLAUDE.md): 11 tests — verbatim content (persona, critical_actions, workflow XML, checklist), story/project-context injection, PF contamination checks (no pennyfarthing, no sidecars, no session metadata, no workflow engine)
- AC2 (Reviewer CLAUDE.md): 5 tests — adversarial role, workflow XML, checklist, dev output injection, PF contamination
- AC3 (Story translator): 7 tests — BMAD template structure, user story format, ACs preserved, empty Tasks/Subtasks, Dev Notes populated, Dev Agent Record present
- BmadConfig: 3 tests — valid config, invalid root, missing files

**Status:** RED (failing on `ModuleNotFoundError: No module named 'pf.benchmark.bmad_adapter'`)
**Module under test:** `pf.benchmark.bmad_adapter` — exports `BmadConfig`, `build_bmad_dev_claude_md`, `build_bmad_reviewer_claude_md`, `translate_story_file`

**Handoff:** To Reverend Mother (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/bmad_adapter.py` - BmadConfig validator, dev/reviewer CLAUDE.md builders, story file translator

**Tests:** 26/26 passing (GREEN)
**Branch:** feature/142-2-bmad-simulator-template (pushed)

**Handoff:** To next phase (review)

## Delivery Findings

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test verification)
- No upstream findings during test verification.

## TEA Verify Assessment

**Tests:** 26/26 passing (GREEN confirmed)
**Quality-Pass:** All checks pass

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 2

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | clean | No duplication or extraction opportunities |
| simplify-quality | 4 findings | Type safety (medium x2), error handling (low), false dead-code (high — textwrap IS used) |
| simplify-efficiency | 6 findings | Test parametrization (high x3), section extraction (high x1), dir setup (medium), validation (low) |

**Applied:** 0 high-confidence fixes
**Rationale:** Quality agent's only high-confidence finding was factually wrong (textwrap.dedent used on 6 lines). Efficiency agent's high-confidence findings are test style preferences (parametrize vs individual methods) — not defects, and individual test methods provide clearer failure isolation.
**Flagged for Review:** 4 medium-confidence findings (type safety, section extraction, dir setup)
**Noted:** 2 low-confidence observations (error handling pattern, batch file validation)
**Reverted:** 0

**Overall:** simplify: clean (no changes applied)

**Handoff:** To Leto II (Reviewer) for code review

### Reviewer (code review)
- **Improvement** (non-blocking): `translate_story_file()` accepts `config` parameter but never uses it; `story_template()` method is dead code. Affects `pennyfarthing-dist/src/pf/benchmark/bmad_adapter.py` (remove unused param or wire up template reading). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `translate_story_file()` hardcodes story structure instead of reading `config.story_template()`. Affects `pennyfarthing-dist/src/pf/benchmark/bmad_adapter.py` (consider using template file for forward-compatibility with BMAD template changes). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**

| Severity | Issue | Location | Notes |
|----------|-------|----------|-------|
| [MEDIUM→FIXED] | `config` param was unused in `translate_story_file()` | `bmad_adapter.py:174` | Now reads `config.story_template()` |
| [MEDIUM→FIXED] | Was hardcoding story structure instead of reading BMAD template | `bmad_adapter.py:190` | Now substitutes BMAD template placeholders |
| [LOW] | Bare `dict` return type on `dev_agent_yaml()` | `bmad_adapter.py:60` | Minor type annotation gap |
| [VERIFIED] | Safe YAML: `yaml.safe_load()` | `bmad_adapter.py:61` | No unsafe deserialization |
| [VERIFIED] | Zero PF contamination in output | All builder functions | Tests cover 11 negative assertions |
| [VERIFIED] | Keyword-only args via `*` separator | All 3 builder functions | Good API design |
| [VERIFIED] | Fail-fast file validation in `__post_init__` | `bmad_adapter.py:48-58` | All 6 files checked at construction |
| [VERIFIED] | No security concerns | Full module | No shell exec, path traversal, or injection vectors |

**Data flow traced:** `story_content` string → f-string interpolation → output markdown (safe: markdown-to-markdown, no execution context)
**Pattern observed:** Config-as-validator pattern with lazy file reads — good separation at `bmad_adapter.py:22-76`
**Error handling:** `FileNotFoundError` in `__post_init__` with descriptive messages; `KeyError` possible on malformed YAML but acceptable given validated source files

**Handoff:** To Stilgar (SM) for finish-story