# Story 91-24: Sprint shard write-time validation and reference integrity

**Jira:** PROJ-14734
**Epic:** 91
**Points:** 5
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/sprint-shard-validation
**Assignee:** sm

---

## Context

### Problem Summary

Epics created and promoted through the `epics-and-stories` workflow fail validation and cause cascading failures when synced to Jira and displayed in the Sprint Panel:

1. **Double-prefix filenames:** `epic_promote()` writes files as `epic-epic-94.yaml` because epic ID contains the prefix and the writer prepends it again
2. **No schema enforcement on write:** Epic YAML written without validation — fields out of order, missing required fields like `jira:`, malformed IDs
3. **Silent ref resolution failure:** `_merge_epic_shards()` skips unresolvable references without warning, making nearly half of stories invisible in the Sprint Panel
4. **Jira idempotency missing:** Epics synced to Jira twice (PROJ-14659 and PROJ-14662) because no duplicate detection existed
5. **Reference format inconsistency:** Sprint YAML references mixed formats (`PROJ-14510` works; `epic-94` resolves to broken `epic-epic-94.yaml`)
6. **Stale workflow sessions:** Completed workflow sessions blocked SM from picking up new work

### Root Cause

The sprint infrastructure (`pennyfarthing_scripts/sprint/`) has four separate epic write paths (epic_add, epic_promote, jira_create_epic, import_epic) but shares no validation logic. Reference normalization happens implicitly in `_get_epic_ref()` with silent fallbacks, and the loader skips unresolvable shards without reporting.

### Design Solution (ADR-0022)

Add validation gates at **write-time** (prevent bad data) and **load-time** (detect bad data):

#### 1. Write-Time Validation

New `validate_epic_shard()` function in `validator.py` enforces:
- `id`, `title`, `status`, `stories` fields required
- `id` must NOT start with `epic-` prefix (prevents double-prefix filenames)
- If `jira` present, must match `PROJ-\d{5}` format
- `stories` must be a list of dicts with `id`, `title`, `points`, `status`
- No duplicate story IDs within the epic

Called from all four write paths:
- `epic_add.py:add_epic()` — before writing shard
- `cli.py:epic_promote()` — after transforming, before `write_sprint()`
- `jira/create.py:create_epic_in_jira()` — after writing back Jira keys
- `import_epic.py:import_epic()` — after generating YAML

#### 2. Reference Normalization

Harden `_get_epic_ref()` in `yaml_io.py` to canonicalize references:
- If `jira:` present and valid → use Jira key (e.g., `PROJ-14659`)
- If `id` is `epic-94` → extract `94`, return `94`
- If `id` is `94` → return `94`
- If `id` is `PROJ-14659` → return `PROJ-14659`
- Reject IDs that would create double-prefix filenames
- Single source of truth — used for both shard filenames and sprint index references

#### 3. Load-Time Warnings

In `_merge_epic_shards()` in `loader.py`, emit warnings for unresolvable refs instead of silent skip:
```python
import warnings

for ref in epics:
    epic_file = sprint_dir / f"epic-{ref}.yaml"
    if not epic_file.exists():
        warnings.warn(f"Sprint epic ref '{ref}' not found: {epic_file}")
        continue
```

Add `--strict` mode to `validate_sprint_file()` that treats unresolvable refs as errors.

#### 4. Jira Idempotency Guard

In `create_epic_in_jira()`, before creating:
- Check if any existing Jira epic has same title (JQL search)
- If found, warn and require `--force` to create duplicate

#### 5. Session Cleanup

Add `validate_sessions()` helper to detect completed workflow sessions:
- Read `**Status:**` or completion percentage
- Warn if 100% complete sessions exist in `.session/`
- Call from `pf agent start` activation path

### Key Files

Files modified in this story:

| File | Changes |
|------|---------|
| `pennyfarthing_scripts/sprint/validator.py` | Add `validate_epic_shard()`, extend required field checking |
| `pennyfarthing_scripts/sprint/yaml_io.py` | Harden `_get_epic_ref()` with normalization and validation |
| `pennyfarthing_scripts/sprint/loader.py` | Add warnings for unresolvable refs, `--strict` mode |
| `pennyfarthing_scripts/sprint/epic_add.py` | Call `validate_epic_shard()` before write |
| `pennyfarthing_scripts/sprint/cli.py` | Call `validate_epic_shard()` in `epic_promote()` |
| `pennyfarthing_scripts/sprint/jira/create.py` | Add idempotency check, call validator |
| `pennyfarthing_scripts/sprint/import_epic.py` | Call `validate_epic_shard()` on generated YAML |

---

## Acceptance Criteria

1. `validate_epic_shard()` rejects epics missing id, title, status, or stories
2. `_get_epic_ref()` strips `epic-` prefix from IDs to prevent double-prefix filenames
3. `epic_add`, `epic_promote`, `jira_create_epic`, and `import_epic` all call validator before write
4. `_merge_epic_shards()` emits warning for each unresolvable ref instead of silent skip
5. Jira create epic checks for existing epic with same title before creating
6. Existing validator tests pass; new tests cover all five validation rules

---

## Technical Approach

### Test-Driven Development (TDD Flow)

1. **TEA (Test Engineer/Architect)** writes tests for all five validation rules and reference normalization
2. **Dev** implements validator and integration in all four write paths
3. **Reviewer** checks coverage and integration completeness

### Coverage Areas

- Unit tests for `validate_epic_shard()` with all field combinations
- Unit tests for `normalize_epic_ref()` with all ID formats
- Unit tests for loader warnings with mock filesystem
- Integration test for full write → load → validate cycle
- Jira idempotency test with mock API
- Session cleanup detection test

### Python package layout

```
pennyfarthing_scripts/sprint/
├── validator.py (add validate_epic_shard)
├── yaml_io.py (harden _get_epic_ref)
├── loader.py (add warnings, --strict)
├── epic_add.py (call validator)
├── cli.py (epic_promote calls validator)
├── jira/
│   └── create.py (idempotency check)
├── import_epic.py (call validator)
└── tests/
    └── test_epic_shard_validation.py (NEW)
```

---

## Key References

- **ADR-0022:** `/Users/keithavery/Projects/pf-1/docs/adr/0022-sprint-shard-validation.md`
- **Epic Context:** `/Users/keithavery/Projects/pf-1/sprint/context/context-epic-91.md`
- **Framework Validator (Layer 1):** `pennyfarthing-dist/` source validation from stories 91-1 and 91-2

---

## SM → TEA Handoff

**Date:** 2026-02-10
**From:** SM (Leo McGarry)
**To:** TEA (Sam Seaborn)
**Phase:** red (write failing tests)

### Handoff Notes
- ADR-0022 has the full design — five validation fixes at two levels
- All changes scoped to `pennyfarthing_scripts/sprint/`
- Key files: `yaml_io.py`, `epic.py`, `loader.py`, `jira/bidirectional.py`
- Branch `feat/sprint-shard-validation` is ready in the pennyfarthing repo
- Write tests for all five validation rules before any implementation

---

## TEA Assessment

**Tests Required:** Yes
**Test File:** `pennyfarthing_scripts/tests/test_epic_shard_validation.py` (new)

**Tests Written:** 45 tests covering all 6 ACs
**Status:** GREEN (all pass — implementation already exists)

### Critical Finding

All five ADR-0022 validation rules are **already implemented** in the codebase:
1. `validate_epic_shard()` exists in `validator.py` with full field/prefix validation
2. `_get_epic_ref()` already strips `epic-` prefix in `yaml_io.py`
3. `_merge_epic_shards()` already emits `warnings.warn()` in `loader.py`
4. All four write paths already call validator (epic_add, epic_promote, jira/create, import_epic)
5. `create_epic_in_jira()` already has idempotency check with `--force` flag
6. `validate_sprint_file()` already has `--strict` mode

The tests pass GREEN because the implementation landed without tests. The test suite now provides the safety net that was missing.

### Test Coverage by AC

| AC | Tests | Status |
|----|-------|--------|
| AC1: Required field validation | 14 tests (TestValidateEpicShardRequiredFields + TestEpicPrefixRejection) | PASS |
| AC2: _get_epic_ref normalization | 8 tests (TestGetEpicRefNormalization) | PASS |
| AC3: Write path integration | 5 tests (TestWritePathValidatorIntegration) | PASS |
| AC4: Loader warnings | 6 tests (TestLoaderWarnings) | PASS |
| AC5: Jira idempotency | 3 tests (TestJiraIdempotencyGuard) | PASS |
| AC6: Integration + existing | 5 tests (TestValidationIntegration) | PASS (2 skipped: need orchestrator root) |

### Gap: AC5 (Session Cleanup)

ADR-0022 proposed a `validate_sessions()` helper for detecting stale completed workflow sessions. This was not implemented and is not tested. It could be deferred to a separate story since it's a quality-of-life improvement, not a data integrity issue.

### Recommendation for Dev

Since all implementation exists and tests pass, Dev should:
1. Review tests for any edge cases missed
2. Decide if session cleanup (AC5 gap) belongs in this story or a follow-up
3. If no additional implementation needed, proceed to review

**Handoff:** To Dev (Toby Ziegler) for review/implementation gap assessment

---

## TEA → Dev Handoff

**Date:** 2026-02-10
**From:** TEA (Sam Seaborn)
**To:** Dev (Toby Ziegler)
**Phase:** implement
**Test Result:** GREEN — all 43 tests pass (2 skipped)

### Handoff Notes
- Implementation already exists — tests verify existing code
- Test file: `pennyfarthing_scripts/tests/test_epic_shard_validation.py`
- 45 tests covering all 6 acceptance criteria
- One gap: session cleanup helper (validate_sessions) not implemented
- Dev should assess if additional implementation is needed or if this goes straight to review

---

## Dev Assessment

**Implementation Complete:** Yes — all ACs already implemented, tests now provide coverage
**Files Changed:**
- `pennyfarthing_scripts/tests/test_epic_shard_validation.py` (new) — 45 tests covering all 6 ACs

**Tests:** 43/45 passing, 2 skipped (GREEN)
**Pre-existing failure:** `test_yaml_io.py::test_write_preserves_sharded_format` fails on `develop` too — not our regression
**PR:** #793 — test: add epic shard validation tests (91-24)
**Branch:** feat/sprint-shard-validation (pushed)

**Session cleanup gap:** ADR-0022 proposed `validate_sessions()` but it's not in the ACs. Deferred — not a data integrity issue.

**Handoff:** To Reviewer (Josh Lyman) for code review

---

## Dev → Reviewer Handoff

**Date:** 2026-02-10
**From:** Dev (Toby Ziegler)
**To:** Reviewer (Josh Lyman)
**Phase:** review
**PR:** #793

### Handoff Notes
- All implementation was already in place — this PR adds test coverage only
- 45 tests, 43 pass, 2 skipped (need orchestrator root for real sprint file tests)
- Pre-existing test_yaml_io failure on develop is NOT our regression
- Session cleanup (validate_sessions) deferred — not in ACs
- Straightforward review: one new test file, no production code changes

---

## Reviewer Assessment

**Verdict:** APPROVED

**Tests:** 43/43 passed, 2 skipped (expected — need orchestrator root)
**Pre-existing failure:** `test_yaml_io.py::test_write_preserves_sharded_format` on develop — NOT our regression

**Data flow traced:** Epic dict → `validate_epic_shard()` → `ValidationResult` → caller checks `.valid` → returns `{success: False}` on failure. All four write paths (`epic_add.py:81`, `cli.py:936`, `jira/create.py:191`, `import_epic.py:325`) call validator before disk/API writes. Safe — validation blocks before side effects.

**Pattern observed:** Tests use `tmp_path` fixture for real filesystem operations (AC1/AC2/AC3/AC4), falling back to `inspect.getsource()` only for paths requiring external services (AC3 epic_promote, AC5 Jira). Pragmatic tradeoff at `test_epic_shard_validation.py:429-457`.

**Error handling:** `validate_epic_shard()` at `validator.py:269` returns `ValidationResult(valid=True)` then accumulates errors via `add_error()`. Never throws. Callers at all four write paths check `.valid` before proceeding. Consistent with codebase pattern.

**Security:** No injection vectors — validation is pure dict inspection. Jira key pattern `PROJ-\d{5}` is anchored (`^...$`), no ReDoS risk. `yaml.safe_load` used for test fixtures (not `yaml.load`). No hardcoded secrets.

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [MEDIUM] | AC3/AC5 source inspection tests | `test_epic_shard_validation.py:429-457,583-609` | 5 tests use `inspect.getsource()` — verify text presence, not execution path. Pragmatic given external deps. |
| [LOW] | Skipped tests hardcode relative path | `test_epic_shard_validation.py:674,690` | `Path(__file__).parent.parent.parent` only works from orchestrator root. Expected. |
| [VERIFIED] | AC1: Required field validation | `test_epic_shard_validation.py:80-213` | 14 tests, thorough |
| [VERIFIED] | AC2: _get_epic_ref normalization | `test_epic_shard_validation.py:282-351` | 8 tests including double-prefix |
| [VERIFIED] | AC3: Write path integration | `test_epic_shard_validation.py:359-457` | 5 tests, 2 behavioral + 3 source inspection |
| [VERIFIED] | AC4: Loader warnings | `test_epic_shard_validation.py:465-572` | 6 tests, all behavioral |
| [VERIFIED] | AC5: Jira idempotency | `test_epic_shard_validation.py:580-609` | 3 tests, source inspection |
| [VERIFIED] | AC6: Integration | `test_epic_shard_validation.py:617-701` | 5 tests including roundtrip |
| [VERIFIED] | No forbidden patterns | Entire file | Clean |

**Handoff:** To SM (Leo McGarry) for finish-story
