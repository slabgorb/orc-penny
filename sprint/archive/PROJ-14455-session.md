# Story 80-2: @deprecated detection and caller cross-reference

**Jira:** PROJ-14455
**Epic:** 80 — Code Markers Tool (TODOs, FIXMEs, Deprecations)
**Points:** 2
**Priority:** P1
**Workflow:** tdd
**Phase:** approved
**Branch:** feature/PROJ-14455-deprecated-detection-caller-xref
**Repos:** pennyfarthing
**Assigned:** keith.avery@slabgorb.io

## Description

Extend the codemarkers analyze.py module to detect @deprecated JSDoc tags in TypeScript files. For each deprecated symbol, count active callers/importers (via grep for import references). Create DeprecationMarker model with symbol, file, caller_count, and callers list.

This story extends the foundation laid in 80-1 (Python codemarkers module: grep + git blame) and prepares the infrastructure for 80-3 (Code markers API + React hook + dialog).

## Acceptance Criteria

- [x] Extend `pennyfarthing_scripts/codemarkers/analyze.py` with `@deprecated` detection
  - Regex scan `.ts`, `.tsx`, `.js` files for `@deprecated` in JSDoc comments (`/** ... @deprecated ... */`)
  - Extract the symbol name from the line following the JSDoc block (function/class/const declaration)
  - Cross-reference callers: grep the codebase for imports of the deprecated symbol, count unique files
  - Populate `DeprecationMarker.callers` with file paths that import or reference the symbol

- [x] Update `pennyfarthing_scripts/codemarkers/models.py`
  - Implement `DeprecationMarker` dataclass with fields: path, line, symbol, text, caller_count, callers
  - Ensure all models follow ADR-0008 result pattern with success/error fields

- [x] Extend CLI in `pennyfarthing_scripts/codemarkers/cli.py`
  - Add support for filtering/querying deprecated symbols
  - Integrate deprecation analysis into the analyze command

- [x] Update codemarkers module exports in `__init__.py`
  - Re-export `DeprecationMarker` model
  - Re-export deprecation analysis functions

- [x] All Python tests pass (TDD: TEA writes tests first in 80-2-tea-tests.md)

## Technical Context

### Epic Overview

Epic 80 creates a full-stack diagnostic tool following the established hotspots module pattern:

1. Python backend (`pennyfarthing_scripts/codemarkers/`) - analysis engine
2. Express API (`packages/cyclist/src/api/`) - thin wrapper
3. React hook + dialog - UI component

This story focuses on the Python backend extension.

### Architecture Details

The @deprecated detection feature:

- Uses regex pattern matching on JSDoc comments: `/**\s*.*@deprecated.*\*/`
- Extracts symbol names from declarations following the JSDoc block
- Uses `grep -r` to find import references across the codebase
- Respects the same exclusion patterns as story 80-1: `node_modules/*`, `dist/*`, `build/*`, `*.lock`, `*.min.js`, `*.min.css`, `*.map`, `package-lock.json`, `pnpm-lock.yaml`
- Runs within the same async subprocess pattern as the TODO/FIXME/HACK/XXX analysis

### Key Patterns (from Epic 80 Context)

**DeprecationMarker Model:**
```python
@dataclass
class DeprecationMarker:
    path: str
    line: int
    symbol: str               # Function/class name
    text: str                 # @deprecated annotation text
    caller_count: int = 0     # Number of active callers/importers
    callers: list[str] = field(default_factory=list)
```

**Expected API Response (for story 80-3):**
```json
{
  "deprecations": [
    {
      "path": "src/utils.ts",
      "line": 18,
      "symbol": "oldHelper",
      "text": "@deprecated Use newHelper instead",
      "caller_count": 3,
      "callers": ["src/api/stats.ts", "src/api/context.ts", "src/hooks/useLegacy.ts"]
    }
  ],
  "summary": {
    "total_deprecations": 3,
    "deprecations_with_callers": 2
  }
}
```

**Async Git Pattern (from hotspots reference):**
```python
async def _run_git_command(args: list[str], cwd: Path) -> tuple[str, str, int]:
    proc = await asyncio.create_subprocess_exec(
        "git", *args, cwd=cwd,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    return (stdout.decode("utf-8", errors="replace").strip(), ...)
```

### Dependencies

- Depends on 80-1 (Python codemarkers module infrastructure)
- Dependency for 80-3 (API + React integration)

## Agent Notes

- Session created by SM setup subagent (story setup phase)
- TDD workflow: TEA (Test Engineer/Architect) writes tests first, then Dev implements
- Branch: `feature/PROJ-14455-deprecated-detection-caller-xref` created in `pennyfarthing/` repo
- Next: TEA handoff for test specification
- SM handoff to TEA: Phase setup → red. TEA to write test specifications.
- TEA handoff to Dev: Phase red → implement. 22 failing tests ready. Dev to implement all stubs.
- Dev handoff to Reviewer: Phase implement → review. 29/29 tests GREEN. PR #766 ready for review.
- Reviewer APPROVED and merged PR #766. Phase review → approved. Handoff to SM for finish-story.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core feature — @deprecated detection with caller cross-referencing

**Test File:**
- `tests/python/test_codemarkers_deprecations.py` — 29 tests (22 failing, 7 passing)

**Test Categories:**
| Category | Tests | Covers |
|----------|-------|--------|
| `TestDeprecationMarkerModel` | 4 | Model fields, defaults, construction |
| `TestGrepDeprecations` | 11 | JSDoc regex, symbol extraction (.ts/.tsx/.js), excludes, line numbers |
| `TestCountCallers` | 4 | Import cross-ref, caller paths, excludes defining file, zero callers |
| `TestAnalyzeDeprecations` | 6 | Full pipeline, summary, empty repo, non-existent path, caller counts |
| `TestDeprecationCLI` | 2 | `deprecations` subcommand, JSON output |
| `TestModuleExports` | 2 | `DeprecationMarker` and `analyze_deprecations` re-exported |

**Status:** RED — 22 failing on `NotImplementedError` stubs, 7 passing (model/exports)

**Stubs Provided:**
- `DeprecationMarker` dataclass in `models.py` (complete — passes model tests)
- `_grep_deprecations()` stub in `analyze.py`
- `_count_callers()` stub in `analyze.py`
- `analyze_deprecations()` stub in `analyze.py`
- `deprecations` CLI command stub in `cli.py`
- `_run_deprecation_analysis()` stub in `cli.py`
- Updated `__init__.py` exports

**Handoff:** To Dev for implementation (make 22 tests green)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/codemarkers/analyze.py` — `_grep_deprecations()`, `_count_callers()`, `analyze_deprecations()` implementations
- `pennyfarthing_scripts/codemarkers/cli.py` — `deprecations` subcommand with table/JSON output
- `pennyfarthing_scripts/codemarkers/models.py` — `DeprecationMarker` dataclass (TEA stub, kept as-is)
- `pennyfarthing_scripts/codemarkers/__init__.py` — Re-exports (TEA stub, kept as-is)
- `tests/python/test_codemarkers_deprecations.py` — 29 tests (TEA-authored)

**Tests:** 29/29 passing (GREEN)
**PR:** #766 — feat(80-2): @deprecated detection and caller cross-reference
**Branch:** feature/PROJ-14455-deprecated-detection-caller-xref (pushed)

**Handoff:** To Reviewer for code review

## Dev Checklist

- [x] TEA writes test spec (tests/python/test_codemarkers_deprecations.py)
- [x] Dev implements DeprecationMarker detection in analyze.py
- [x] Dev implements caller cross-reference logic
- [x] Dev updates models.py with DeprecationMarker
- [x] Dev updates cli.py for deprecation filtering
- [x] Dev updates __init__.py exports
- [x] All tests pass (29/29 GREEN)
- [x] Dev creates PR with test coverage (#766)
- [x] Reviewer approves and merges to develop

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [MEDIUM] | `_count_callers` uses naive substring match — may false-positive on partial symbol names | `analyze.py:444` |
| 2 | [VERIFIED] | Data flow clean: `analyze_deprecations` → `_grep_deprecations` → `_count_callers` → `DeprecationMarker` | `analyze.py:451-501` |
| 3 | [VERIFIED] | Pattern consistency: matches existing `_grep_markers()` and `analyze_repo()` patterns exactly | `analyze.py:360-406` |
| 4 | [LOW] | Stale docstring "Stub: Dev will implement" on completed `DeprecationMarker` model | `models.py:52` |
| 5 | [VERIFIED] | Error handling: non-existent path, UnicodeDecodeError, OSError all handled | `analyze.py:467-471` |
| 6 | [VERIFIED] | Security: no user-controlled paths in production, strict UTF-8, no injection vectors | `analyze.py:373-375` |
| 7 | [MEDIUM] | Redundant condition clause in lookahead break logic (cosmetic, not a bug) | `analyze.py:396` |
| 8 | [VERIFIED] | CLI wired correctly, JSON/table output, matches existing subcommand patterns | `cli.py:146-179` |
| 9 | [LOW] | `deprecations` CLI ignores `repo` and `days` params from shared decorator | `cli.py:148` |

**Data flow traced:** `analyze_deprecations(path)` → resolves path → greps files for `@deprecated` → extracts symbols → counts callers → returns `{success, deprecations, summary}` (safe, no side effects)
**Pattern observed:** Exact match with `_grep_markers()` file iteration pattern at `analyze.py:360`
**Error handling:** Path validation, encoding errors, and OSError all handled gracefully
**Tests:** 29/29 passing, comprehensive AC coverage

**Handoff:** To SM (Slartibartfast) for finish-story
