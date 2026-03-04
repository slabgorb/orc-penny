---
parent: context-epic-136.md
workflow: tdd
---

# Story 136-29: Implement pf release dry-run command

## Business Context

The `pf release dry-run` command simulates the full release pipeline without side effects, letting developers preview exactly what a release would do before committing to it. This is critical for a framework distributed via npm — a bad release is expensive to roll back. The command already has scaffolding (`release/cli.py` registers it, `release/dry_run.py` has core logic) but has zero test coverage, meaning the existing implementation is unverified and potentially unreliable.

This story adds TDD coverage to validate the dry-run contract: version bumping, changelog checks, build validation, and pack simulation — all without mutating state.

## Technical Guardrails

**Key files:**
- `pennyfarthing-dist/src/pf/release/cli.py` — Click CLI with `dry-run` command (lines 74-114)
- `pennyfarthing-dist/src/pf/release/dry_run.py` — Core `dry_run_release()` function
- `pennyfarthing-dist/src/pf/tests/conftest.py` — Shared fixtures (`project_root`, etc.)
- `pennyfarthing-dist/src/pf/common/config.py` — `get_project_root()` used by CLI

**Patterns to follow:**
- Result objects: `{success, data?, error?, steps?}` with `dry_run: True` flag (ADR-0008)
- Click CLI testing: Use `click.testing.CliRunner` for CLI integration tests
- Unit tests: Use `tmp_path` fixtures with mock `package.json` and `CHANGELOG.md`
- subprocess mocking: Mock `subprocess.run` for `tsc` and `npm pack` calls — do not run real builds in tests
- Test file placement: `pennyfarthing-dist/src/pf/tests/test_release_dry_run.py`

**Dependencies:**
- `click` — CLI framework
- `subprocess` — Build/pack validation (must be mocked in tests)
- `pf.common.config.get_project_root()` — Project root discovery

**Do NOT touch:**
- `release/deprecate.py`, `release/verify_contents.py` — out of scope
- Real npm/tsc execution in tests — always mock subprocess calls

## Scope Boundaries

**In scope:**
- Tests for `dry_run_release()` core function (unit tests)
- Tests for `pf release dry-run` CLI command (integration tests via CliRunner)
- Input validation: invalid semver, invalid bump type, missing package.json
- Version bump computation: major, minor, patch, pre-release stripping
- Changelog detection: present with [Unreleased], present without, missing
- Build/pack step simulation: success and failure paths
- Result structure validation: correct keys, data shape, step format

**Out of scope:**
- Tests for `deprecate` or `verify` commands (separate stories)
- Real subprocess execution (tsc, npm pack) — mock only
- Changes to the existing implementation — that's Dev's job in GREEN phase
- E2E testing against real npm registry

## AC Context

**AC1: Command exists — `pf release dry-run` is callable via CLI**
- Test: CliRunner invokes `dry-run --help` and gets exit code 0
- Test: CliRunner invokes `dry-run` with no args against a valid project fixture
- Edge: Command registered in release group, accessible as `pf release dry-run`

**AC2: Version handling — accepts `--version` and `--bump` options**
- Test: `--version=2.0.0` sets target_version to "2.0.0"
- Test: `--bump=patch` on "1.2.3" produces "1.2.4"
- Test: `--bump=minor` on "1.2.3" produces "1.3.0"
- Test: `--bump=major` on "1.2.3" produces "2.0.0"
- Test: No version or bump defaults to current version
- Edge: `--version` overrides `--bump` when both provided
- Edge: Pre-release version "1.2.3-beta.1" with `--bump=patch` strips pre-release

**AC3: Dry-run simulation — runs through all steps without side effects**
- Test: Result contains steps for version_bump, changelog_update, build, pack
- Test: No files modified after dry-run (tmp_path state unchanged)
- Test: Result includes `dry_run: True` flag

**AC4: Output — displays current version, target version, and steps**
- Test: `data.current_version` matches package.json version
- Test: `data.target_version` matches computed version
- Test: `data.packages` lists discovered workspace packages
- Test: Each step has `action`, `detail`, and `success` keys

**AC5: No mutations — does NOT commit, tag, or publish**
- Test: subprocess.run never called with `git commit`, `git tag`, or `npm publish`
- Test: package.json content unchanged after dry-run

**AC6: Error handling — validates inputs and reports failures**
- Test: Invalid semver "not.a.version" returns `{success: False, error: "Invalid version: ..."}`
- Test: Invalid bump "mega" returns `{success: False, error: "Invalid bump type: ..."}`
- Test: Missing package.json returns `{success: False, error: "package.json not found..."}`
- Test: Malformed package.json returns `{success: False, error: "Failed to parse..."}`
- Test: Build failure (tsc non-zero) produces step with `success: False`
- Test: Pack failure (npm pack non-zero) produces step with `success: False`
