# Story 91-11: Workflow YAML schema validation

**Jira:** MSSCI-14709
**Epic:** 91 — Cross-File Reference & Schema Validation Pipeline
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/workflow-yaml-schema-validation
**Assigned:** keith.avery@1898andco.io

## Story

Adapt from BMAD PR #1529 for Pennyfarthing workflow structure. 24 workflow definitions, 3 variants (phased, stepped, procedural).

## Acceptance Criteria

- AC1: `pf validate workflow` discovers all workflow YAML files (root-level *.yaml + subdirectory workflow.yaml)
- AC2: Common fields validated: `workflow.name` required; `workflow.type` must be phased/stepped/procedural
- AC3: Phased workflows: `phases` required, each phase needs `name` + `agent`
- AC4: Stepped workflows: `steps` required (with `path` + `pattern`); `agent` required
- AC5: Procedural workflows: `agent` required; `instructions`/`checklist` recommended
- AC6: Agent references cross-checked against `agents/*.md` file stems
- AC7: `--strict` promotes warnings to errors; `pf validate` includes workflow validator
- AC8: Zero false positives on current develop branch (25 real workflow files)
- AC9: Gate type validation: known set of valid gate types for phased workflows

## Context

- Epic context: `sprint/context/context-epic-91.md`
- Related: Story 91-12 (agent definition validation - DONE) provides patterns to follow
- Scope: `pennyfarthing-dist/workflows/**/*.yaml` (24 files, 3 variants)
- BMAD reference: PR #1529 Zod-based schema validation

## Technical Notes

- Layer 2 validation in the CI pipeline (above Layer 0 linting, Layer 1 file refs)
- Three workflow variants: phased, stepped, procedural
- Must validate required fields, enums, structural constraints per variant
- Story 91-5 (research) covers gap analysis — check if completed for prior art

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core validation logic — every AC needs test coverage

**Test Files:**
- `tests/python/test_workflow_validator.py` — 47 tests across 10 classes (9 ACs + edge cases)

**Tests Written:** 47 tests covering 9 ACs
**Status:** RED (34 failing on assertions, 13 trivially pass against stubs)

**Implementation Files:**
- `pennyfarthing_scripts/validate/adapters/workflow.py` — stub adapter with function signatures
- `pennyfarthing_scripts/validate/cli.py` — needs `workflow` added to VALIDATORS dict + Click command

**Pattern:** Follow `adapters/agent.py` exactly — `run()` returns `ValidateReport`, `[ERROR]`/`[WARN]` detail format, `--strict` promotes warnings, `discover → validate_common → validate_{variant}` pipeline.

**Key Design Decisions:**
- Python adapter (not Zod/JS) — matches existing validate framework
- Three variant validators: `validate_phased()`, `validate_stepped()`, `validate_procedural()`
- Discovery: root-level `*.yaml` + subdirectory `workflow.yaml` (exclude non-workflow YAML like templates)
- Agent cross-refs are warnings (not errors) — agents might be defined in themes
- Gate types from known set; unknown types are warnings

**Handoff:** To Dev (White Rabbit) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/validate/adapters/workflow.py` — full validator (320 lines): discovery, common, phased, stepped, procedural validation
- `pennyfarthing_scripts/validate/cli.py` — added `workflow` to VALIDATORS dict + Click command

**Tests:** 47/47 passing (GREEN)
**PR:** #799 — feat(91-11): workflow YAML schema validation
**Branch:** feat/workflow-yaml-schema-validation (pushed)

**Handoff:** To Reviewer (Queen of Hearts) for code review

## Reviewer Assessment

**Verdict:** APPROVED

| # | Severity | Finding | Location |
|---|----------|---------|----------|
| 1 | [VERIFIED] | Follows `adapters/agent.py` pattern — ValidateReport, [ERROR]/[WARN] format, --strict | `workflow.py` |
| 2 | [VERIFIED] | Discovery finds 24 real workflows, excludes template YAML | `workflow.py:33-55` |
| 3 | [VERIFIED] | YAML parse errors handled gracefully, no crash on malformed input | `workflow.py:246-252` |
| 4 | [VERIFIED] | `yaml.safe_load` used (safe), not `yaml.load` | `workflow.py:248` |
| 5 | [LOW] | Unused import in test file — **FIXED** in review | `test_workflow_validator.py:25` |
| 6 | [VERIFIED] | All 3 variant validators check agent cross-refs | `workflow.py:149,186,222` |
| 7 | [VERIFIED] | Gate validation: missing type=error, unknown type=warning | `workflow.py:154-165` |
| 8 | [VERIFIED] | 47 tests, 9 ACs, integration test against 24 real files | `test_workflow_validator.py` |
| 9 | [VERIFIED] | CLI registration + Click command properly added | `cli.py:23,131-138` |

**Data flow traced:** YAML file -> yaml.safe_load -> validate_common + validate_{variant} -> ValidateReport (safe: no code execution, no external calls)
**Error handling:** YAML parse errors caught, non-dict workflow keys caught, missing directories reported
**Security:** yaml.safe_load prevents code injection; no file writes; read-only validator

**Handoff:** To SM (Mad Hatter) for finish-story

## SM Assessment

Story setup complete. 5-point TDD story for Layer 2 schema validation. Story 91-12 (agent definition validation) is already done and provides established patterns — TEA should study that implementation first. 24 workflow YAMLs across 3 variants (phased, stepped, procedural) need structural validation. BMAD PR #1529 provides Zod reference but Pennyfarthing uses Python scripts, so TEA needs to decide on validation approach (Python/Zod/JSON Schema). Handing to TEA for red phase — define ACs and write failing tests.
