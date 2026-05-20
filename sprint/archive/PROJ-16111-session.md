# Story 136-29: Implement pf release dry-run command

**Jira:** PROJ-16111
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/pf-release-dry-run
**Epic:** 136

## Story
Implement pf release dry-run command

## Context

### Research Findings
The release command module (`pennyfarthing/pennyfarthing-dist/src/pf/release/`) already exists with:

**Current Structure:**
- `cli.py` — Click CLI group with three commands: `deprecate`, `dry-run`, `verify`
- `dry_run.py` — Core logic for simulating release pipeline (version bump, changelog, build, pack)
- `deprecate.py` — Logic to deprecate npm versions
- `verify_contents.py` — Package manifest verification

**Existing dry-run Implementation:**
- Command: `pf release dry-run [OPTIONS]`
- Options: `--version`, `--bump {major|minor|patch}`
- Returns: Result dict with version info, package list, and execution steps
- Simulates: version bump, changelog update, build check (tsc), pack check (npm pack --dry-run)
- Does NOT: commit, tag, or publish

**Main CLI Registration:**
The command is already registered in `cli.py` lazy_commands at line 83:
```python
"release": ("pf.release.cli", "release"),
```

**Key Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/cli.py` — main CLI entry point with lazy command registry
- `pennyfarthing/pennyfarthing-dist/src/pf/release/cli.py` — Click CLI commands
- `pennyfarthing/pennyfarthing-dist/src/pf/release/dry_run.py` — Core dry-run logic
- `pennyfarthing/pennyfarthing-dist/src/pf/release/deprecate.py` — Deprecation logic
- `pennyfarthing/pennyfarthing-dist/src/pf/release/verify_contents.py` — Manifest verification

### Acceptance Criteria
Based on the story showing "Implement pf release dry-run command" with 3 points on TDD workflow:

1. **Command exists** — `pf release dry-run` is callable via CLI
2. **Version handling** — accepts `--version` (explicit) or `--bump {major|minor|patch}` options
3. **Dry-run simulation** — runs through version bump, changelog, build, and pack without side effects
4. **Output** — displays current version, target version, and execution steps with status
5. **No mutations** — does NOT commit, tag, or publish
6. **Error handling** — validates semver format, checks file presence, reports build/pack failures
7. **Tests** — TDD workflow requires RED-GREEN-REFACTOR with full test coverage

### Next Steps (TDD Flow)
1. **RED phase (TEA)** — Write failing tests for `pf release dry-run` command
2. **GREEN phase (DEV)** — Implement minimal dry-run command to pass tests
3. **REFACTOR phase (REVIEWER)** — Review implementation, ensure reliability
4. **Complete** — Archive story when all phases pass

## SM Assessment

**Story readiness:** READY. The release module already has partial scaffolding — `cli.py` registers the command group and `dry_run.py` contains core logic. TEA needs to evaluate existing code coverage gaps and write failing tests for the dry-run command's full contract.

**Key risks:**
- Existing implementation may already pass some tests — TEA should verify what's actually wired vs. stubbed
- Build/pack simulation depends on workspace state (node_modules, tsconfig) — tests may need fixtures

**Routing:** TDD phased → TEA (Leeloo) for RED phase. 3 points, standard TDD flow.

## TEA Assessment

**Tests Required:** Yes
**Reason:** 3-point TDD story requires comprehensive coverage of dry-run contract

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_release_dry_run.py` - Full test suite for dry_run_release() and CLI

**Tests Written:** 39 tests covering all 6 ACs across 9 test classes
**Status:** RED (1 failing — `test_empty_version_string_rejected`)

**Findings:** The existing implementation (`release/dry_run.py` + `release/cli.py`) is nearly complete and passes 38/39 tests. The single failure exposes a real validation gap: `dry_run_release()` accepts empty string as `version` parameter without rejecting it. The semver regex `_SEMVER_RE` does not match empty string, but the `if version and not _SEMVER_RE.match(version)` guard short-circuits on falsy empty string, treating it as "no version provided" rather than "invalid version."

**Test Coverage Summary:**
- AC1 (CLI exists): 5 CLI integration tests via CliRunner
- AC2 (Version handling): 6 version bump tests + pre-release edge case
- AC3 (Simulation): 7 step structure and content tests
- AC4 (Output): Covered by step and package discovery tests
- AC5 (No mutations): 3 mutation-detection tests
- AC6 (Error handling): 5 input validation + 2 build/pack failure tests

**Handoff:** To Korben Dallas (Dev) for GREEN phase — fix empty version validation gap

## Delivery Findings

### TEA (test design)
- **Gap** (non-blocking): Empty version string `""` passes validation in `dry_run_release()` due to falsy short-circuit in `if version and not _SEMVER_RE.match(version)`. Affects `pennyfarthing-dist/src/pf/release/dry_run.py` (line 46 — needs explicit empty-string check). *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/release/dry_run.py` - Fixed empty version string validation: `if version and not` → `if version is not None and not`

**Tests:** 39/39 passing (GREEN)
**Branch:** feat/pf-release-dry-run (pushed)

**Handoff:** To Jean-Baptiste Emanuel Zorg (Reviewer) for review phase

## TEA Verify Assessment

**Tests:** 39/39 passing (GREEN confirmed)
**Implementation Review:** Correct. Single-line fix changes truthiness check to identity check, preserving `None` passthrough while catching empty string.
**Regression Risk:** None — change is strictly additive (rejects previously-accepted invalid input)
**Verify Result:** PASS

**Handoff:** To Jean-Baptiste Emanuel Zorg (Reviewer) for review phase

## Delivery Findings (verify)

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- **Improvement** (non-blocking): `bump` validation at `dry_run.py:43` uses same truthiness pattern (`if bump and`) that was just fixed for `version`. Programmatic callers could pass `bump=""` and it would silently be treated as "no bump". Mitigated by Click's `click.Choice` constraint at CLI layer. Affects `pennyfarthing-dist/src/pf/release/dry_run.py` (line 43 — consider `if bump is not None and` for consistency). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): No `timeout` parameter on `subprocess.run` calls at `dry_run.py:105,121`. Hanging tsc/npm pack would block the command indefinitely. Affects `pennyfarthing-dist/src/pf/release/dry_run.py` (add `timeout=120` to subprocess calls). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** CLI `--version`/`--bump` → Click parse → `dry_run_release()` → validation → read-only file access → subprocess (tsc, npm pack) → result dict. No mutations, no user input in shell commands.
**Pattern observed:** Result dict `{success, data, error, steps}` follows ADR-0008 at `dry_run.py:136-145`. Consistent with project conventions.
**Error handling:** All input validation returns structured error results (not exceptions) at `dry_run.py:42-57`. CLI translates to stderr + exit(1) at `cli.py:112-114`.
**Security:** Static subprocess command lists, no shell=True, no interpolation. Clean.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] | Bump validation truthiness pattern | `dry_run.py:43` | Optional consistency fix |
| [MEDIUM] | No subprocess timeout | `dry_run.py:105,121` | Optional hardening |

**Handoff:** To Ruby Rhod (SM) for finish-story