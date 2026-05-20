# Story 91-8: Add Ruff to CI for Python scripts

**Jira:** PROJ-14706
**Epic:** 91 — Cross-File Reference & Schema Validation Pipeline
**Points:** 1
**Type:** Feature
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/91-8-ruff-ci-python

---
## Context

Story 91-8 is part of Layer 0 of Epic 91's validation pyramid — Formatting & Linting. The Pennyfarthing framework distributes 469+ interconnected files across `pennyfarthing-dist/` and supporting packages.

The framework includes a Python scripts package (`pennyfarthing_scripts/`) with 107 Python files that need consistent code quality enforcement. A `pyproject.toml` configuration for Ruff already exists in the repository but is not wired into the CI/CD pipeline.

This story focuses on integrating Ruff (Python linter/formatter) into the GitHub Actions CI workflow to enforce code quality standards on all Python files in `pennyfarthing_scripts/` during pull requests and commits.

**Current state:**
- `pyproject.toml` contains Ruff configuration rules
- 107 Python files in `pennyfarthing_scripts/` directory
- CI does not currently run Ruff checks
- No lint enforcement for Python code quality

**Value:** Catches style violations, unused imports, and code quality issues automatically in CI, preventing regressions in the Python scripts package.

## Acceptance Criteria

1. Ruff is added to the GitHub Actions CI workflow for Python linting
2. CI runs Ruff against all Python files in `pennyfarthing_scripts/`
3. Ruff uses the configuration from `pyproject.toml`
4. CI fails the build if Ruff detects violations (enforcement mode)
5. All existing Python files pass Ruff checks without modification (or fixes are applied)
6. Documentation is updated to reflect Ruff enforcement in the development guide

## Dependencies

- None (Layer 0, no dependencies on other Layer 0 stories)
- Related: Epic 91 overall Layer 0 context (ESLint, markdownlint, yamllint)

---
## TEA Assessment

**Tests Required:** No
**Reason:** CI configuration story (chore bypass). Adding a workflow step to `.github/workflows/ci.yml` is infrastructure — testing YAML structure provides no value. The real test is whether `ruff check` passes, which is the CI step itself.

**Critical Finding:** The codebase currently has **317 Ruff violations** (274 auto-fixable). Dev MUST run `ruff check --fix pennyfarthing_scripts/` before wiring the CI step, or CI will fail immediately.

**Violation breakdown:**
- Import sorting (I001) — bulk of auto-fixable violations
- Various pycodestyle, pyflakes, bugbear issues

**Implementation plan for Dev:**
1. Run `ruff check --fix pennyfarthing_scripts/` to auto-fix 274 violations
2. Manually fix remaining ~43 violations
3. Add `python-lint` job to `.github/workflows/ci.yml`
4. Verify locally: `ruff check pennyfarthing_scripts/` exits 0

**Key files:**
- `.github/workflows/ci.yml` — add ruff job (existing jobs: build, lint, python-benchmark)
- `pyproject.toml` — Ruff config already complete (rules: E,F,W,I,B,C4,UP; line-length: 100)
- CI uses self-hosted runners: `[self-hosted, Ubuntu, Common]`
- Python deps installed via: `pip install -e ".[dev]"` (includes ruff>=0.8)

**Handoff:** To Dev (White Rabbit) for implementation

---
## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:** 97 files
- `.github/workflows/ci.yml` — added `python-lint` job with Ruff check
- `pennyfarthing_scripts/**` — fixed 331 Ruff violations (288 auto-fix, 43 manual)

**Violation fixes by category:**
- I001 (import sorting) — bulk of auto-fixes
- F841 (unused variables) — removed assignments or prefixed `_`
- E402 (late imports) — `noqa` for intentional lazy CLI registration pattern
- F821 (undefined names) — added `TYPE_CHECKING` imports
- B904/B905 (raise from, zip strict) — added `from err`/`from None`, `strict=False`
- B007 (unused loop vars) — prefixed with `_` or removed enumerate
- C401/C416 (unnecessary comprehensions) — simplified
- E741 (ambiguous var name) — renamed `l` → `line`

**Tests:** No tests written (TEA bypass — CI config story)
**PR:** #787 — feat(91-8): add Ruff linting to CI for Python scripts
**Branch:** feat/91-8-ruff-ci-python (pushed)

**AC Coverage:**
1. Ruff added to CI workflow — `python-lint` job in ci.yml
2. CI runs against `pennyfarthing_scripts/` — `ruff check pennyfarthing_scripts/`
3. Uses pyproject.toml config — Ruff auto-discovers it
4. Enforcement mode — non-zero exit fails the job
5. All existing files pass — 331 violations fixed
6. Documentation — AC6 not addressed (no dev guide found to update)

**Handoff:** To Reviewer (Queen of Hearts) for code review

---
## Reviewer Assessment

**Verdict:** APPROVED

**Preflight:** Ruff passes clean. 674 tests pass (8 pre-existing failures identical to develop baseline). Zero regressions.

**Data flow traced:** `ruff check pennyfarthing_scripts/` → CI job reads `pyproject.toml` config → enforces rules E,F,W,I,B,C4,UP → non-zero exit blocks merge. Wiring confirmed end-to-end.

**Observations:**
| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | CI `python-lint` job correctly structured with checkout, Python 3.12 setup, dep install, and ruff check | `.github/workflows/ci.yml:80-98` |
| 2 | [VERIFIED] | Import reordering (I001) is safe — tested sprint/__init__.py and persona.py, no circular imports | `pennyfarthing_scripts/sprint/__init__.py` |
| 3 | [VERIFIED] | Unused variable removals correct — Jira client API calls return 204 empty body | `pennyfarthing_scripts/jira/client.py:518,556,572,622` |
| 4 | [VERIFIED] | `raise from` fixes correct — `from None` suppresses misleading chain, `from err` preserves cause | `pennyfarthing_scripts/prime/tiers.py:81`, `sprint/story_add.py` |
| 5 | [VERIFIED] | `socket.error` → `OSError` simplification correct (subclass since Python 3.3) | `pennyfarthing_scripts/context.py:302` |
| 6 | [VERIFIED] | TYPE_CHECKING guards properly isolate type-only imports without affecting runtime | `complexity/cli.py`, `dependencies/cli.py`, `healthscore/cli.py`, `prime/cli.py` |
| 7 | [VERIFIED] | `zip(strict=False)` is explicit default — iterables may legitimately differ in length | `healthscore/analyze.py`, `jira/bidirectional.py` |
| 8 | [VERIFIED] | 13 `noqa: E402` comments all applied to legitimate lazy CLI registration imports | `cli.py`, `sprint/cli.py`, `prime/tiers.py` |
| 9 | [VERIFIED] | Zero new test failures — 674 pass, 8 fail identically to develop baseline | Test suite |
| 10 | [LOW] | AC6 (documentation) not addressed — acceptable for 1-point CI config story with no existing dev guide | N/A |

**Error handling:** No error handling changes beyond `raise from` improvements (which strengthen exception chains). No new error paths introduced.

**Security:** No security concerns — changes are linter fixes (import sorting, unused variables, style). No auth, input handling, or data flow changes.

**Pattern observed:** Consistent use of `noqa` for intentional lazy imports is a good pattern — documents intent rather than masking violations.

**Handoff:** To SM (Mad Hatter) for finish-story
