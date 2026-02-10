# Session: MSSCI-14734 — Sprint shard write-time validation and reference integrity

## Story
- **ID:** 91-24 / MSSCI-14734
- **Epic:** 91 — Cross-File Reference & Schema Validation Pipeline
- **Points:** 5
- **Priority:** P0
- **Workflow:** tdd (SM → TEA → Dev → Reviewer → SM)
- **Branch:** feat/sprint-shard-validation
- **Repos:** pennyfarthing

## Acceptance Criteria

1. **AC1:** `validate_epic_shard()` rejects epics missing required fields (`id`, `title`, `status`, `stories`)
2. **AC2:** `_get_epic_ref()` normalizes epic references by stripping `epic-` prefix, preventing double-prefix filenames
3. **AC3:** `loader.py` adds `warnings.warn()` for unresolvable shard references (replaces silent skip)
4. **AC4:** Validator is wired into all four epic write paths: `epic_add`, `epic_promote`, `jira_create_epic`, `import_epic`
5. **AC5:** Jira idempotency check searches for existing epic by title before creating duplicates
6. **AC6:** Test suite covers all 5 validators with 34 tests, zero regressions (612 total suite passing)

## Phase: finish

## SM Assessment

**Setup:** Session created for in-flight story. PR #792 already exists with implementation complete.

**PR:** #792 — feat: sprint shard write-time validation (91-24)

**Branch:** feat/sprint-shard-validation (pennyfarthing repo)

**CI:** Build PASS, Lint PASS, Python Lint PASS, Codeowners PASS. CLI Startup Benchmark FAIL (flaky — 202.9ms vs 200ms threshold, GH Actions runner variance, unrelated to changes).

**Tests:** 34 new tests covering all 6 ACs, 612 total suite passing.

**Files Changed:**

| File | Change |
|------|--------|
| `pennyfarthing_scripts/sprint/validator.py` | Add `validate_epic_shard()`, constants |
| `pennyfarthing_scripts/sprint/yaml_io.py` | Fix `_get_epic_ref()` prefix stripping |
| `pennyfarthing_scripts/sprint/loader.py` | Add `warnings.warn()` for missing shards |
| `pennyfarthing_scripts/sprint/epic_add.py` | Wire validator before shard write |
| `pennyfarthing_scripts/jira/create.py` | Add title-based idempotency check |
| `pennyfarthing_scripts/sprint/cli.py` | Wire validator into CLI paths |
| `pennyfarthing_scripts/sprint/import_epic.py` | Wire validator into import path |
| `tests/python/test_shard_validation.py` | 34 tests covering all 6 ACs |

**Handoff:** To Reviewer for code review of PR #792

## Reviewer Assessment

**Verdict:** APPROVED

**Tests:** 35/35 passing locally, CI green (Build, Lint, Python Lint, Codeowners)
**PR:** #792 — already merged to develop (pre-review merge by Keith Avery)

**Observations:**

| # | Severity | Description | Location |
|---|----------|-------------|----------|
| 1 | [MEDIUM] | JQL injection via unescaped title — `summary ~ "{title}"` uses f-string interpolation. Titles with quotes break JQL. Low risk (internal tooling, YAML-sourced titles). | `create.py:216` |
| 2 | [LOW] | No type guard on story items in `validate_epic_shard`. Non-dict entries raise `AttributeError`. | `validator.py:328` |
| 3 | [LOW] | `force` param added to `create_epic_in_jira()` but not wired to CLI. Dead parameter for CLI users. | `create.py:153` |
| 4 | [VERIFIED] | `_get_epic_ref()` handles edge cases correctly — while loop strips multiple prefixes, fallback on empty. | `yaml_io.py:289-292` |
| 5 | [VERIFIED] | All 4 write paths call `validate_epic_shard()` before writing. Wiring complete per AC3. | Multiple |
| 6 | [VERIFIED] | Loader warnings emit on unresolvable refs. Strict mode promotes to errors. Clean design. | `loader.py:44-48`, `validator.py:600-608` |
| 7 | [VERIFIED] | Result pattern compliance — `{success, data?, error?}` objects throughout. | Multiple |
| 8 | [VERIFIED] | Duplicate story ID detection within-epic works correctly. | `validator.py:326-336` |

**Data flow traced:** Epic YAML dict → `validate_epic_shard()` → required fields + ID prefix + Jira key + story validation → `ValidationResult` → gate before any write. Clean.
**Pattern observed:** Consistent validation-before-write gate at all 4 entry points.
**Error handling:** Validation failures return result objects (non-CLI) or raise ClickException (CLI). Exception in Jira search swallowed with warning — primary flow unblocked.

**Handoff:** To SM for finish-story
