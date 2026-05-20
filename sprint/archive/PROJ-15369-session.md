# Story 123-4: Implement pf release dry-run command

**Jira:** PROJ-15369
**Branch:** feature/123-4-pf-release-dry-run
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** finish
**Points:** 3
**Assignee:** keith.avery@slabgorb.io

## Story Context

Simulate the full release pipeline without publishing. Run version bump, changelog, build, pack steps without committing, tagging, or publishing.

## Technical Context

The `pf release` command module is located in `pennyfarthing/pennyfarthing-dist/pf/release/`. Current implementation includes:

**Existing Release Infrastructure:**
- `pf/release/cli.py` — Click CLI group with release commands
- `pf/release/deprecate.py` — Deprecation logic for published versions
- Current command: `pf release deprecate --version=X.Y.Z --reason="..."` with `--dry-run` flag support

**Deprecate Command Pattern:**
- Validates inputs (version, reason, CHANGELOG existence)
- Checks npm registry for version existence
- Dry-run mode returns planned steps without executing
- Executes three steps: npm deprecate, changelog update, git notes
- Returns result object per ADR-0008: `{success, data?, error?, steps?}`
- Each step includes `action`, `detail`, and `success` fields

**Related Files:**
- `pennyfarthing/pennyfarthing-dist/scripts/git/release.sh` — Git release script
- `pennyfarthing/pennyfarthing-dist/workflows/release.yaml` — Release workflow definition
- `pennyfarthing/pennyfarthing-dist/gates/release-ready.md` — Release gate definition
- `pennyfarthing/pennyfarthing-dist/commands/pf-release.md` — Deprecated command docs (redirects to /pf-git release)

**Framework Release Pipeline Components:**
The full release pipeline involves:
1. Version bump (package.json, TypeScript version constants)
2. Changelog generation/updates
3. Build process (pnpm build, TypeScript compilation)
4. Pack step (npm pack validation)
5. Publishing to npm registry

**Key Implementation Patterns:**
- Use `.js` extensions in TypeScript imports
- Return result objects `{success, data?, error?}` instead of throwing
- Use Haiku for subagents, never Opus
- Dry-run support via flag parameter
- Step-by-step execution tracking with detailed reporting

## Acceptance Criteria

1. Implement `pf release dry-run` command as a new subcommand under `pf release`
2. Support `--version` option to target a specific version (default: current from package.json)
3. Run through version bump, changelog, build, and pack steps
4. Show dry-run output listing all steps that would be executed
5. Do NOT commit, tag, or publish during dry-run
6. Integration test validates dry-run simulation accuracy
7. Documentation in command help text with usage examples

## SM Assessment

**Setup complete.** Story 123-4 claimed in Jira (PROJ-15369), branch `feature/123-4-pf-release-dry-run` created off develop in pennyfarthing repo.

**Technical approach:** Follow the existing `pf release deprecate` pattern. New `dry-run` subcommand in `pf/release/cli.py` with core logic in a dedicated module. Simulates version bump, changelog, build, and pack steps — returns result object with step details per ADR-0008. Dry-run flag is inherent (the command itself IS the dry run).

**Risk:** Low. Existing release infrastructure provides clear patterns. 3 points is right-sized for TDD with integration tests.

**Routing:** TEA (Jayne) designs tests first per TDD workflow. Existing deprecate tests provide a template.

## TEA Assessment

**Tests Required:** Yes
**Reason:** New command with core logic, version computation, subprocess calls, and multiple failure modes.

**Test Files:**
- `tests/python/test_release_dry_run.py` — 47 tests across 10 test classes

**Tests Written:** 47 tests covering 7 ACs
- CLI Registration (3): Command accessible from release group and main CLI
- Happy Path (7): Returns success, dry_run flag, steps, version data
- Version Resolution (7): patch/minor/major bump, explicit override, prerelease detection
- Version Bump Step (2): Files listed, version transition shown
- Changelog Step (2): Detection and unreleased section awareness
- Build Step (3): tsc validation, failure reporting
- Pack Step (3): npm pack --dry-run, failure reporting
- No Side Effects (7): VERSION, package.json, CHANGELOG.md unchanged; no git commit/tag, no npm publish
- Error Handling (6): Missing package.json, missing VERSION, missing changelog, invalid bump, invalid version, malformed JSON
- Workspace Detection (2): Package discovery and naming
- CLI Integration (5): Success/error output, step display, --version and --bump flags

**Status:** RED (29 failing, 18 passing — failures are assertion-based, zero import errors)

**Note:** Merged 123-3 (deprecate command) from `feature/123-3-add-pf-release-deprecate-command` into develop, rebased 123-4 on top.

**Handoff:** To Mal (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/release/dry_run.py` — Core logic: version reading, bump computation, 4-step pipeline simulation
- `pennyfarthing-dist/pf/release/cli.py` — Added `dry-run` subcommand with `--version` and `--bump` options
- `tests/python/test_release_dry_run.py` — Fixed test filter bug (cwd path matching false positives)

**Tests:** 47/47 passing (GREEN), 32/32 deprecate tests still green
**Branch:** feature/123-4-pf-release-dry-run (pushed)

**AC Coverage:**
1. `pf release dry-run` registered as subcommand under `pf release` group
2. `--version` option with default from package.json, `--bump` for major/minor/patch
3. Four pipeline steps: version_bump, changelog_update, build (tsc --noEmit), pack (npm pack --dry-run)
4. Returns result object with step details per ADR-0008
5. Zero file modifications, no git commit/tag, no npm publish
6. 47 integration tests validate all simulation paths
7. Help text with usage examples in CLI command docstring

**Handoff:** To River (Reviewer) for review

## TEA Verify Assessment

**Verification:** GREEN confirmed
**Dry-run tests:** 47/47 passing
**Deprecate tests:** 32/32 passing (no regression)
**Total:** 79/79 GREEN

**AC Verification:**
1. `pf release dry-run` registered as subcommand — confirmed via CLI registration tests
2. `--version` and `--bump` options — confirmed via version resolution tests
3. Four pipeline steps simulated — confirmed via step-specific test classes
4. Result object with step details — confirmed via happy path tests
5. Zero side effects — confirmed via 7 no-side-effects tests
6. 47 integration tests validate simulation — confirmed
7. Help text in CLI docstring — confirmed via CLI integration tests

**Handoff:** To River (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `version`/`bump` CLI input → validated at `dry_run.py:43-47` → `_bump_version` computes target → result dict. `project_root` used as `cwd` only, never interpolated into commands. All subprocess calls use list form. Safe — no injection path.

**Pattern observed:** Follows ADR-0008 result object pattern (`{success, data, error, steps}`) — matches existing `deprecate.py` exactly. Step format `{action, detail, success}` consistent across both commands.

**Error handling:** Missing package.json → error (`dry_run.py:52`). Malformed JSON → caught (`dry_run.py:56`). Invalid bump → error (`dry_run.py:44`). Invalid version → error (`dry_run.py:47`). Missing CHANGELOG → step-level failure, simulation continues (`dry_run.py:97-102`).

**Observations:**

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [VERIFIED] | CLI wired end-to-end | `cli.py:74`, `pf/cli.py` lazy load | CliRunner tests confirm |
| [VERIFIED] | No side effects | `dry_run.py:73-134` | 7 tests verify no mutation |
| [VERIFIED] | No command injection | `dry_run.py:105,121` | List-form subprocess, no shell=True |
| [VERIFIED] | ADR-0008 compliance | `dry_run.py:136-145` | Result shape matches deprecate |
| [MEDIUM] | No subprocess timeout | `dry_run.py:105,121` | CLI tool, non-blocking |
| [MEDIUM] | Weak tsc test assertion | `test_release_dry_run.py:285` | Fallback trivially true |
| [LOW] | Non-standard prerelease bump | `dry_run.py:150` | Strips suffix before bump |
| [LOW] | No version format guard on pkg.json | `dry_run.py:59,152` | Near-impossible edge case |

**Handoff:** To Zoe (SM) for finish-story