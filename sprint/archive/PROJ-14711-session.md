# Story 91-13: Skill registry and command schema validation

**Jira:** PROJ-14711
**Epic:** 91 — Cross-File Reference & Schema Validation Pipeline
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing-orchestrator
**Branch:** feature/91-13-skill-registry-command-schema-validation
**Assigned:** keith.avery

## Acceptance Criteria

- Enforce existing `skill-registry.schema.json` validation on `pennyfarthing-dist/skill-registry.yaml`
- Add command file structural validation for 49 command files in `pennyfarthing-dist/commands/*.md`
- Integrate into validation pipeline (likely as part of Layer 2 schema validation)
- Zero false positives against current codebase
- Adapted approach from story 91-11 (Workflow YAML schema) and 91-12 (Agent definition schema)

## Technical Context

Story 91-13 is part of **Layer 2: Schema Validation** in the Cross-File Reference & Schema Validation Pipeline (epic 91). This epic ports a proven validation pipeline from BMAD-METHOD to Pennyfarthing for 469+ interconnected files with 1,685+ cross-references.

### Layer 2 Overview

Layer 2 adds schema-level validation on top of Layer 1's file reference validation:

- **91-11** (Workflow YAML schema, 5 pts): 24 workflows across 3 variants (phased, stepped, procedural)
- **91-12** (Agent definition schema, 5 pts): 19 agent files, required sections, helper model values
- **91-13** (Skill/command schema, 3 pts): Enforce `skill-registry.schema.json`, 49 commands, 22 skills

### Key Files & Context

From epic context:

| Item | Count | Location |
|------|-------|----------|
| Skills | ~22 | `pennyfarthing-dist/skills/*/` |
| Commands | ~49 | `pennyfarthing-dist/commands/*.md` |
| Skill registry | 1 | `pennyfarthing-dist/skill-registry.yaml` |
| Skill registry schema | 1 | `pennyfarthing-dist/skill-registry.schema.json` |

### Prior Story Work

**91-11** (Workflow YAML schema) and **91-12** (Agent definition schema) established the pattern for Layer 2:
- Zod schema approach (adapted from BMAD PR #1529)
- Integration into validation pipeline with `--strict` mode support
- Unit test suite using `node:test`
- GHA workflow annotation support (`::warning` format)

Expected that 91-13 will follow similar patterns.

### Validation Pyramid Context

```
    Layer 3: Graph Validation
        Step transitions, reachability (placeholder)

      Layer 2: Schema Validation
        YAML fields, required props, enums ← 91-13 here
        (91-11: workflows, 91-12: agents, 91-13: skills/commands)

    Layer 1: File Reference Validation
      Cross-file refs, path resolution (PR #721, complete)

  Layer 0: Formatting & Linting
    ESLint, Ruff, markdownlint, yamllint (91-7, 91-8, 91-9, 91-10, all done)
```

## SM Assessment

Story 91-13 is a 3-point TDD story for skill registry and command schema validation as part of the cross-file reference and schema validation pipeline (epic 91). This story depends on research story 91-5 (Layer 2 schema approach), which concluded with a recommendation to adapt the Zod approach from BMAD PR #1529. Stories 91-11 and 91-12 have already established the implementation pattern and can serve as reference implementations.

Routing to TEA for test design phase.

## TEA Assessment

**Tests Required:** Yes
**Reason:** 3-point TDD story with clear schema validation requirements

**Test Files:**
- `tests/python/test_skill_command_validator.py` — 41 tests across 9 test classes

**Tests Written:** 41 tests covering all ACs
**Status:** RED (failing — ModuleNotFoundError for `pennyfarthing_scripts.validate.adapters.skill_command`)

**Implementation Notes for Dev:**
- Create `pennyfarthing_scripts/validate/adapters/skill_command.py` following pattern from `workflow.py` and `agent.py`
- Must export: `discover_command_files`, `discover_skill_registry`, `run`, `validate_command_file`, `validate_skill_registry`
- `validate_skill_registry(root)` → validates `skill-registry.yaml` against `skill-registry.schema.json` using JSON Schema (jsonschema library or manual)
- `validate_command_file(path)` → validates command markdown: YAML frontmatter with `description` field required, warn on empty body
- `run(root, fix, strict)` → returns `ValidateReport(validator="skill-command")`
- Register `"skill-command"` in `VALIDATORS` dict in `cli.py`
- Schema is at `pennyfarthing-dist/skills/skill-registry.schema.json`, registry at `pennyfarthing-dist/skills/skill-registry.yaml`
- Commands at `pennyfarthing-dist/commands/*.md` (46 files currently)
- Must add `deprecated` and `redirect` to schema if not already present (registry uses them for `story` and `theme-creation` skills)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/validate/adapters/skill_command.py` — new validator adapter (manual JSON Schema validation, command frontmatter validation)
- `pennyfarthing_scripts/validate/cli.py` — registered `skill-command` in VALIDATORS dict
- `pennyfarthing-dist/skills/skill-registry.schema.json` — added `deprecated`/`redirect` fields to skill definition
- `pennyfarthing-dist/commands/setup.md` — added missing YAML frontmatter

**Tests:** 39/39 passing (GREEN)
**PR:** #800 — feat(91-13): skill registry and command schema validation
**Branch:** feature/91-13-skill-registry-command-schema-validation (pushed to pennyfarthing repo)

**Notes:**
- Used manual JSON Schema validation (no `jsonschema` dependency) — handles the subset used by skill-registry.schema.json
- `setup.md` was the only command file without frontmatter — added it to achieve zero false positives
- Schema needed `deprecated` and `redirect` properties added (used by `story` and `theme-creation` skills)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `skill-registry.yaml` → `yaml.safe_load()` → `_validate_against_schema()` → schema errors → `run()` → `ValidateReport`. Commands: `*.md` → `_parse_frontmatter()` → description check → report. Both flows confirmed against real codebase via AC4 tests.
**Pattern observed:** Follows established adapter pattern (workflow.py, agent.py) — `run()` signature, error/warning collection, `[ERROR]`/`[WARN]` prefixes, strict mode, passed counting at `skill_command.py:1-292`
**Error handling:** Missing files, malformed YAML, non-dict data, schema violations all produce clean errors without crashes. `yaml.safe_load()` used correctly (not `yaml.load()`). Verified at `skill_command.py:167-175` and `skill_command.py:219-228`
**Medium:** Missing CLI subcommand (other validators have `@validate.command()` — non-blocking, reachable via `pf validate`)
**Low:** Unused `_SEMVER_RE` at `skill_command.py:17`
**Tests:** 39/39 GREEN, zero false positives against real codebase
**Handoff:** To SM for finish-story

## Work Log

- **2026-02-10 10:51** SM: Story setup, feature branch created, session file created
- **2026-02-10** SM: Handoff to TEA for test design (red phase)
- **2026-02-10** TEA: Wrote 41 failing tests in `test_skill_command_validator.py`. RED state confirmed (ModuleNotFoundError). Committed to develop.
- **2026-02-10** TEA: Handoff to Dev for implementation (implement phase)
- **2026-02-10** Dev: Implemented skill_command.py adapter, registered in CLI, updated schema, fixed setup.md. 39/39 GREEN. PR #800 created.
- **2026-02-10** Dev: Handoff to Reviewer for code review (review phase)
- **2026-02-10** Reviewer: APPROVED — 39/39 tests GREEN, zero false positives, no critical/high issues. PR #800 merged.
