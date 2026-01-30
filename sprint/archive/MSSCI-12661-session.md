# Session: MSSCI-12661 - Add startup benchmark to CI

## Story Details

| Field | Value |
|-------|-------|
| **Story ID** | MSSCI-12661 |
| **Jira Key** | MSSCI-12661 |
| **Title** | Add startup benchmark to CI |
| **Points** | 1 |
| **Epic** | 67 - Pennyfarthing Python CLI |
| **Epic Jira** | MSSCI-12655 |
| **Workflow** | trivial |
| **Phase** | approved |
| **Repos** | pennyfarthing-orchestrator |
| **Feature Branch** | feat/MSSCI-12661-startup-benchmark-ci |
| **Assignee** | keith |

## Epic Context

See: `sprint/context/context-epic-67.md`

The Python CLI uses Click with lazy-loaded subgroups for fast startup (<200ms target). This story adds CI enforcement of the startup time requirement.

## Technical Context

### Problem Statement

The Python CLI startup time requirement (<200ms) is tested locally in `pennyfarthing/tests/python/test_cli.py` (class `TestStartupPerformance`), but this check does not run in CI. The startup time benchmark needs to be added to the CI pipeline to prevent performance regressions.

### Existing Infrastructure

**CI Configuration:**
- Location: `pennyfarthing/.github/workflows/ci.yml`
- Current jobs: `build` (pnpm build + tests) and `lint`
- No Python test execution currently

**Existing Startup Tests:**
- Location: `pennyfarthing/tests/python/test_cli.py`
- Key test: `test_cli_startup_under_200ms()` in `TestStartupPerformance` class
- Runs CLI 3 times and asserts average startup < 200ms
- Also tests: lazy imports, cold import time (<100ms)

### Technical Approach

1. **Add Python environment to CI** - Setup Python 3.10+ in the build job
2. **Install Python dependencies** - Run `pip install -e .` or use pyproject.toml
3. **Run startup benchmark** - Execute pytest for `test_cli.py::TestStartupPerformance`
4. **Optional: Add dedicated job** - Consider a separate `python-tests` job

### Key Files

| File | Purpose |
|------|---------|
| `pennyfarthing/.github/workflows/ci.yml` | CI pipeline configuration |
| `pennyfarthing/tests/python/test_cli.py` | Contains startup performance tests |
| `pennyfarthing/pyproject.toml` | Python package configuration |

### Acceptance Criteria

1. CI runs the startup benchmark test (`test_cli_startup_under_200ms`)
2. Build fails if startup time exceeds 200ms
3. CI also runs related lazy import tests for complete coverage

### Implementation Notes

- CI environments may have different performance characteristics than local
- Consider if 200ms threshold needs adjustment for CI
- The test already runs 3 iterations and averages, which helps with variance

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/.github/workflows/ci.yml` - Added `python-benchmark` job

**Tests:** 4/4 passing locally
**PR:** Part of existing PR #560 (branch feat/MSSCI-12660-agent-python-cli)
**Branch:** feat/MSSCI-12660-agent-python-cli (pushed)

**Implementation Details:**
- Added new `python-benchmark` CI job
- Uses Python 3.12 setup with actions/setup-python@v5
- Installs package with `pip install -e ".[dev]"`
- Runs TestStartupPerformance tests (startup < 200ms)
- Runs TestLazyImports tests (no eager imports)

**Acceptance Criteria Met:**
- [x] CI runs startup benchmark test
- [x] Build fails if startup > 200ms (test assertion)
- [x] CI runs related lazy import tests

**Commit:** `673a51f0a` - ci: add Python startup benchmark to CI

**Handoff:** To Reviewer for code review

## Session Log

### Setup Phase
- Created session file
- Reviewed epic context and existing tests
- Identified CI configuration and test files

### Implement Phase
- Added `python-benchmark` job to CI workflow
- Verified tests pass locally (4/4)
- Committed and pushed to branch

### Handoff: Dev -> Reviewer
- **Timestamp:** 2026-01-30
- **From:** Dev (implement phase)
- **To:** Reviewer (review phase)
- **Test Result:** GREEN (4/4 tests pass locally)
- **Status:** Ready for code review
- **Notes:** Implementation adds Python startup benchmark to CI. Heimdall (Reviewer) to verify CI configuration and test coverage.

## Reviewer Assessment

**Verdict:** APPROVED

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | `[VERIFIED]` | CI workflow YAML syntax valid | `ci.yml:81-105` |
| 2 | `[VERIFIED]` | Modern actions (v4/v5) used | `ci.yml:86-92` |
| 3 | `[VERIFIED]` | Python 3.12 matches requirement | `ci.yml:91` |
| 4 | `[VERIFIED]` | Dev deps installed correctly | `ci.yml:95-97` |
| 5 | `[LOW]` | No pip caching (non-blocking) | `ci.yml:94-97` |

**Data flow traced:** CI trigger → checkout → python setup → pip install → pytest TestStartupPerformance → pass/fail
**Pattern observed:** Follows existing CI job pattern with clean separation
**Error handling:** pytest exits non-zero on failure → build blocked (correct)
**Security:** No secrets, credentials, or external network calls

### Handoff: Reviewer -> SM
- **Timestamp:** 2026-01-30
- **From:** Reviewer (review phase)
- **To:** SM (approved phase)
- **Verdict:** APPROVED
- **Status:** Ready for finish-story
- **Notes:** Code review approved. Implementation is correct, all tests pass, CI configuration follows best practices. Ready for SM to mark story complete and close in sprint.
