# Story 129-4: Generate Context Document Templates from Schema

**Jira:** MSSCI-15684
**Points:** 1
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/129-4-context-templates
**Assigned:** keith

## Acceptance Criteria

- [ ] Create `pf context template` command in `src/pf/context/cli.py`
- [ ] Generate blank template files for each component in the context schema
- [ ] Support template generation for all component types (structured, markdown, text, formatted_text, collection)
- [ ] Templates include inline documentation/comments specific to each component
- [ ] Command accepts optional `--tier` filter to generate only templates for a specific tier
- [ ] Output directory defaults to `./context-templates/` or accepts `--output` path
- [ ] Add tests for template generation with all component types
- [ ] Document command usage in `guides/context-schema.md`

## Context

This story generates blank context document templates from the machine-readable context schema (129-2, MSSCI-15682). Developers can use these templates to understand what context documents should contain and how to structure them. The story follows the completion of the context schema definition (129-2) and context validator module (129-3). Templates are generated from the schema metadata, eliminating manual document creation and keeping them in sync with schema updates.

## Technical Notes

- Templates are generated from `schemas/context-schema.yaml` which defines components and their metadata
- Each component has `description`, `type`, `source`, and validation rules - use these to populate template content
- For structured components (dataclass types), generate stub fields matching the schema definition
- For markdown components, generate markdown structure with section headers from required/recommended validation rules
- For collection types, generate sample item structure showing expected hierarchy
- Command should support a `--overwrite` flag to replace existing templates
- Store generated templates in `context-templates/{component-name}.{ext}` with appropriate file extensions

## SM Assessment (Setup)

Story 129-4 is a 1-point trivial workflow — template generation from the context schema built in 129-2. The `pf context template` command extends the existing `context` CLI group from 129-3. Dev should add a `template` subcommand to `pf/context/cli.py`, implement template generation logic that reads the schema and produces blank/stub documents per component type (structured, markdown, text, collection). Branch `feature/129-4-context-templates` is created from `develop` in the pennyfarthing repo.

## Dev Assessment (Implement)

**Implementation Complete:** Yes
**Files Changed:**
- `pf/context/templates.py` — Template generator: per-type generators (structured/markdown/text/formatted_text/collection), generate_templates with tier filter and overwrite support
- `pf/context/cli.py` — Added `pf context template` subcommand with --tier, --output, --overwrite options
- `pf/tests/test_context_templates.py` — 33 tests covering all 8 ACs
- `guides/context-schema.md` — Added template generator usage documentation

**Tests:** 33/33 passing (GREEN)
**Branch:** feature/129-4-context-templates (pushed)

**Handoff:** To Jean-Baptiste Emanuel Zorg (Reviewer) for review phase

## Dev Assessment (Lint Fixes)

**Fixes Applied:**
- `templates.py:39` — Extracted f-string backslash expression to variable (Python 3.11 compat)
- `templates.py:10` — Removed unused `yaml` import
- `templates.py:18,148` — Removed f-prefix from non-placeholder strings
- `templates.py:6-12` — Sorted import block
- `cli.py:53,115` — Added `from None` for exception chaining (B904)
- `cli.py:122` — Removed f-prefix from non-placeholder string

**Ruff:** All checks passed
**Tests:** 33/33 passing (GREEN)
**Branch:** feature/129-4-context-templates (pushed)

**Handoff:** Back to Zorg for re-review

## Reviewer Assessment

**Verdict:** APPROVED
**Review Round:** 2 (round 1 rejected for lint violations; all 6 findings fixed)
**Data flow traced:** `pf context template --tier X` → `template_cmd()` → `generate_templates()` → `load_schema(_default_schema_path())` → tier filter → per-type generator → `Path.write_text()` (safe — no injection, yaml.safe_load)
**Pattern observed:** Strategy dispatch via `_TYPE_GENERATORS` dict at `templates.py:181` — clean, extensible, all 5 component types covered
**Error handling:** `ValueError` for invalid tier caught in CLI with `from None` chaining; `yaml.safe_load` prevents arbitrary code execution; schema path resolution via `__file__` parents
**Tests:** 33/33 passing, covering all 8 ACs across 7 test classes
**Ruff:** All checks passed (0 violations)

**Handoff:** To Ruby Rhod (SM) for finish-story

## Related Stories

- **129-2 (MSSCI-15682):** Context schema definition (completed)
- **129-3 (MSSCI-15683):** Context validator module (completed)
- **129-5 (MSSCI-15694):** Frontmatter hooks integration (completed)