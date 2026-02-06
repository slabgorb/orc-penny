# Story 76-1: Core yaml_io module with deterministic serialization

**Jira:** MSSCI-14254
**Epic:** Epic 76 - Sprint Data Management System (MSSCI-14253)
**Points:** 5
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/76-1-yaml-io-module
**Assigned:** keithavery

## Acceptance Criteria

- Same input produces byte-identical output
- Round-trip integrity (read → write → read = identical)
- Atomic writes prevent partial file corruption
- Key ordering matches sprint-template.yaml

## Context

See `sprint/context/context-epic-76.md` for full technical context.

### Key Deliverables
- `pennyfarthing_scripts/sprint/yaml_io.py` with `read_sprint()`, `write_sprint()`, `canonical_dump()`
- `pennyfarthing_scripts/tests/test_yaml_io.py` with round-trip and atomic write tests
- `pyproject.toml` updated with `ruamel.yaml` dependency

### Technical Notes
- Uses `ruamel.yaml` for deterministic serialization (comment preservation, key ordering, block scalar control)
- `read_sprint(path)` returns `ruamel.yaml.CommentedMap`
- `canonical_dump(data)` applies template key ordering, block scalars for multiline, 2-space indent
- Atomic write pattern: temp file + `os.replace()`
- Must handle both `current-sprint.yaml` and `sprint/archive/*.yaml` formats

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core infrastructure module — deterministic serialization demands rigorous proof

**Test Files:**
- `pennyfarthing_scripts/tests/test_yaml_io.py` — 36 tests across 5 classes

**Tests Written:** 36 tests covering 4 ACs
- AC1: Deterministic output (7 tests) — byte-identical, no trailing whitespace, 2-space indent, block scalars
- AC2: Round-trip integrity (8 tests) — minimal/full round-trip, multiline strings, lists, integers, dates, double round-trip, real file
- AC3: Atomic writes (7 tests) — file creation, overwrite, no temp remnant, original preserved on failure, directory checks
- AC4: Key ordering (7 tests) — constant definitions, sprint/epic/story key order verification, scrambled reordering, unknown keys at end
- Plus 6 read_sprint error handling tests (nonexistent, malformed, empty, type preservation)

**Status:** RED (29 failing, 6 passing, 1 skipped — all failures are NotImplementedError)

**Stub:** `pennyfarthing_scripts/sprint/yaml_io.py` — constants defined, functions raise NotImplementedError

**Handoff:** To Dev for implementation (GREEN phase)

## Dev Assessment

**Implementation:** Complete
**Test Result:** GREEN (35 passed, 1 skipped, 0 failed)

**Files Changed:**
- `pennyfarthing_scripts/sprint/yaml_io.py` — Full implementation (259 lines)
- `pyproject.toml` — Added `ruamel.yaml>=0.18` dependency

**Implementation Details:**
- `read_sprint()`: Uses `ruamel.yaml.YAML()` with `preserve_quotes=True`, raises `FileNotFoundError`/`ValueError` appropriately
- `canonical_dump()`: Reorders keys via `_sort_mapping()` + `_canonicalize()`, applies `LiteralScalarString` for multiline, strips trailing whitespace
- `write_sprint()`: Atomic via temp file + `os.replace()`, validates input is `Mapping`, cleans up temp on failure
- Helper functions: `_make_yaml()`, `_sort_mapping()`, `_ensure_block_scalars()`, `_canonicalize()`, `_to_commented_map()`

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #673
**Data flow traced:** File path → `Path.exists()` check → `YAML().load()` → `CommentedMap` (read); data → `Mapping` validation → `canonical_dump()` → temp file → `os.replace()` (write). Both paths handle failure cleanly.
**Pattern observed:** Atomic write pattern (temp + replace) correctly implemented at `yaml_io.py:249-253` with cleanup at `yaml_io.py:255-258`
**Error handling:** `FileNotFoundError` for missing files, `ValueError` for malformed/empty, `TypeError` for non-mapping input — all verified at `yaml_io.py:68-69,75-76,78-79,244-245`
**Tests:** 35 passed, 1 skipped (real sprint file), 0 failed. Pre-existing `test_sprint_module_exists` failure unrelated (fails on develop).
**Observations:**
- [VERIFIED] AC1: Deterministic output — byte-identical across calls
- [VERIFIED] AC2: Round-trip integrity — including double round-trip byte comparison
- [VERIFIED] AC3: Atomic writes — temp file cleanup, original preserved on failure
- [VERIFIED] AC4: Key ordering — sprint/epic/story constants, scrambled reordering
- [LOW] `__init__.py` not updated with yaml_io re-exports (style nit, not blocking)
- [LOW] `_canonicalize()` coupled to sprint structure (appropriate for module scope)
- [LOW] Vacuous isinstance check in `test_round_trip_preserves_date_strings:313`
**Security:** No injection vectors. File I/O only, no shell/eval/pickle.
**Handoff:** To SM for finish-story

## Session Log

- Setup: Story claimed, branch created, session initialized
- Handoff: SM → TEA for test design (TDD red phase)
- TEA: 36 tests written, RED state confirmed (29 fail), committed to feature/76-1-yaml-io-module
- Handoff: TEA → Dev for implementation
- Dev: Implementation complete, 35/36 tests GREEN, committed to feature/76-1-yaml-io-module
- Handoff: Dev → Reviewer for code review
- Reviewer: APPROVED — PR #673 created and merged, all ACs verified
- Handoff: Reviewer → SM for finish-story
