# Story 123-6: Consumer install smoke test in CI

## Story Details
- **ID:** 123-6
- **Workflow:** tdd
- **Jira:** PROJ-15371
- **Points:** 3
- **Priority:** p1

## Description
CI job that packs, installs in a clean temp directory, and runs pennyfarthing doctor to validate. Every 11.x packaging bug would have been caught by this.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-21T20:42:13Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-21T00:00:00Z | 2026-02-21T20:28:03Z | 20h 28m |
| red | 2026-02-21T20:28:03Z | 2026-02-21T20:33:21Z | 5m 18s |
| green | 2026-02-21T20:33:21Z | 2026-02-21T20:34:54Z | 1m 33s |
| verify | 2026-02-21T20:34:54Z | 2026-02-21T20:42:13Z | 7m 19s |
| finish | 2026-02-21T20:42:13Z | - | - |

## Acceptance Criteria
- [ ] AC1: Smoke test script packs @pennyfarthing/core into a tarball using `pnpm pack`
- [ ] AC2: Tarball installs cleanly in an isolated temp directory with no peer dependency errors
- [ ] AC3: `pennyfarthing` CLI binary is accessible and responds to `--version` after install
- [ ] AC4: `pennyfarthing doctor` runs and reports no critical failures on the fresh install
- [ ] AC5: Temp directory is cleaned up after test (trap on EXIT)
- [ ] AC6: CI workflow includes a `smoke-test` job that runs the test script on push/PR

## Assessment — SM Setup
- Story claimed in Jira (PROJ-15371), assigned to Keith Avery, moved to In Progress
- Session file created with story context and workflow tracking
- Feature branch `feat/123-6-consumer-install-smoke-test-ci` created from develop in pennyfarthing repo
- TDD workflow: TEA writes failing tests for CI smoke test, then Dev implements
- Key context: Every 11.x packaging bug would have been caught by a pack-install-doctor pipeline step

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story deliverable IS a test — the smoke test script + CI integration

**Test Files:**
- `tests/integration/test_consumer_install.sh` - End-to-end consumer install smoke test

**Tests Written:** 14 assertions covering 6 ACs
**Status:** RED (1 failing — AC6: CI workflow missing smoke-test job)

**What the test does:**
1. `pnpm pack` → creates tarball (AC1)
2. `npm install <tarball>` in isolated temp dir (AC2)
3. `pennyfarthing --version` to verify CLI binary (AC3)
4. `pennyfarthing init --force` + `pennyfarthing doctor --json` to validate install health (AC4)
5. Verifies 8 key paths exist in installed package (AC5 — cleanup via EXIT trap)
6. Checks CI workflow for `smoke-test` job (AC6 — **this is the RED failure**)

**What Dev needs to do:**
- Add a `smoke-test` job to `.github/workflows/ci.yml` that runs `tests/integration/test_consumer_install.sh`
- The job needs: Node 20, pnpm 9, `pnpm install`, `pnpm run build`, then run the test script
- Consider: should it run on every push/PR or only on release branches? (I'd say every push — it's the whole point)

**Handoff:** To Dev for implementation (add CI job)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `.github/workflows/ci.yml` - Added `smoke-test` job (depends on `build`, runs the test script)

**Tests:** 14/14 passing (GREEN)
**Branch:** feat/123-6-consumer-install-smoke-test-ci (pushed)

**Implementation details:**
- Job runs after `build` completes (`needs: build`)
- Full setup: Node 20, pnpm 9, install, build, then execute smoke test
- Runs on every push/PR to develop and main (same triggers as other CI jobs)

**Handoff:** To Reviewer

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Observation | Location |
|----------|------------|----------|
| [VERIFIED] | All 6 ACs covered — 14 assertions match Dev's claim | `test_consumer_install.sh` |
| [VERIFIED] | Data flow: `pnpm pack` → tarball → `npm install` → CLI binary → doctor (safe, isolated) | `test_consumer_install.sh:67-170` |
| [VERIFIED] | CI job follows existing patterns (self-hosted, checkout, node+pnpm, install, build, run) | `.github/workflows/ci.yml:57-83` |
| [VERIFIED] | Error handling: EXIT trap, `set -uo pipefail`, manual pass/fail counters | `test_consumer_install.sh:17,51,234-238` |
| [VERIFIED] | Security: no injection, proper quoting, `mktemp -d`, no secrets | full script |
| [MEDIUM] | Doctor JSON parsing uses `sed` extraction — fragile if output format changes | `test_consumer_install.sh:155` |
| [LOW] | `pnpm pack` stderr suppressed (`2>/dev/null`) — could hinder CI debugging | `test_consumer_install.sh:67` |

**Pre-existing failures:** 10 cyclist tests in `100-9-archived-epics.test.ts` — no commits on this branch, already `continue-on-error: true` in CI.

**Handoff:** To SM for finish-story

## Notes
- Repo: pennyfarthing
- Branch: feat/123-6-consumer-install-smoke-test-ci