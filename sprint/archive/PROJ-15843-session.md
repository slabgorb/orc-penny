# Story 136-3: Fix init/doctor prefix filtering for Python dist layout

**Jira:** PROJ-15843
**Story ID:** 136-3
**Epic:** 136
**Repos:** pennyfarthing
**Branch:** fix/136-3-fix-init-doctor-prefix-filtering
**Workflow:** trivial
**Phase:** finish
**Status:** in-progress
**Assigned:** slabgorb@gmail.com

---

## Story Context

This story is part of **Epic 136: Post-Install Reliability** which addresses five root causes affecting 18+ open issues stemming from the Python-first migration. The distribution now uses `pip`/`pipx`/`uv tool install`, but the codebase retains monorepo path assumptions.

**The Problem:** When `pf` is pip-installed, the `get_dist_root()` function resolves to a `_dist/` package path that is a stub containing only `__init__.py`. The `pf init` command tries to glob `commands/pf-*.md` and `skills/pf-*/` from this stub path, finds nothing, and copies zero commands and skills into the project. Subsequently, `pf doctor` reports false positives: it warns about missing "symlinks" (which are now file copies in the pip era) and nags about missing `node_modules/` (which pip consumers will never have).

**Outcome:** Fresh pip installs appear broken even though the package is fine. Both init and doctor produce confusing output with inaccurate labels.

**Dependencies:** This story depends on **136-1 (Unified pf Discovery)**, which ensures `get_dist_root()` returns a usable path. Once that path is correct, this story makes init and doctor actually work for both monorepo developers and pip consumers.

## Technical Approach

### Key Changes

1. **Fix `_find_pf_commands()` and `_find_pf_skills()`** in `pennyfarthing-dist/src/pf/init/core.py`
   - These functions must locate commands/skills in pip `_dist/` layout, not just `dist_root/commands/` and `dist_root/skills/`
   - Must work with both real directories and symlinks (dev layout uses symlinks)
   - Ensure discovered files are correctly globbed and copied

2. **Rename `check_symlinks()` to `check_content_dirs()`** in `pennyfarthing-dist/src/pf/doctor/checks.py`
   - Update label to "Content directories present" (not "Symlink targets present")
   - Clarify that these are file copies, not symlinks, in the post-migration era

3. **Suppress `node_modules` warning for pip installs** in `pennyfarthing-dist/src/pf/doctor/checks.py`
   - `check_node_packages()` must detect install method (pip/pipx/uv) and return `pass` status
   - Only warn about missing `node_modules` for monorepo layouts where npm is expected

4. **Update `is_populated()`** in `pennyfarthing-dist/src/pf/_dist/__init__.py`
   - Currently only checks `agents/` and `commands/`; must also verify `skills/` presence
   - This helps detect whether `_dist/` has bundled/symlinked content

### Files to Modify

- `pennyfarthing-dist/src/pf/init/core.py` — `_find_pf_commands()`, `_find_pf_skills()`
- `pennyfarthing-dist/src/pf/common/config.py` — ensure `get_dist_root()` pip fallback returns usable path
- `pennyfarthing-dist/src/pf/doctor/checks.py` — rename check, suppress node_modules warning, update labels
- `pennyfarthing-dist/src/pf/_dist/__init__.py` — update `is_populated()` to check skills

### Files to Read (No Changes)

- `pennyfarthing-dist/src/pf/init/core.py` (`init_project`) — understand full copy flow
- `pennyfarthing-dist/src/pf/doctor/models.py` — `CheckResult` dataclass signature
- `pennyfarthing-dist/src/pf/init/core.py` (`verify_pf_cli`) — install method detection

### Backward Compatibility

All changes must work identically in monorepo layout where `get_dist_root()` returns `pennyfarthing-dist/`. Commands, skills, and content directories are discovered from the same relative paths. Doctor checks produce the same pass/fail results (with updated labels).

## Acceptance Criteria

### AC1: init copies commands in pip layout

**Given** a pip-installed `pf` where `get_dist_root()` returns the `_dist/` package path
**And** the `_dist/` directory contains `commands/pf-*.md` files (bundled or symlinked)
**When** the user runs `pf init` in a fresh project
**Then** `_find_pf_commands()` discovers all `pf-*.md` files from `_dist/commands/`
**And** they are copied to both `.pennyfarthing/commands/` and `.claude/commands/`
**And** the `data.commands_copied` count in the result is greater than 0

### AC2: init copies skills in pip layout

**Given** a pip-installed `pf` where `get_dist_root()` returns the `_dist/` package path
**And** the `_dist/` directory contains `skills/pf-*/` directories (bundled or symlinked)
**When** the user runs `pf init` in a fresh project
**Then** `_find_pf_skills()` discovers all `pf-*` skill directories from `_dist/skills/`
**And** they are copied to both `.pennyfarthing/skills/` and `.claude/skills/`
**And** the `data.skills_copied` count in the result is greater than 0

### AC3: doctor content-dirs check uses accurate label

**Given** a project initialized with `pf init` (file copies, not symlinks)
**When** the user runs `pf doctor`
**Then** the check previously named `symlinks` is now named `content_dirs`
**And** the CHECKS registry description reads "Content directories present"
**And** the pass detail reads "All content directories present"
**And** the fail detail lists missing directories by name

### AC4: doctor suppresses node_modules warning for pip installs

**Given** a pip-installed project with no `node_modules/` directory
**When** the user runs `pf doctor`
**Then** `check_node_packages()` returns status `pass` with detail indicating node packages are not required for pip installs
**And** the check does NOT return status `warn`

### AC5: monorepo backward compatibility

**Given** a monorepo development environment where `get_dist_root()` returns `pennyfarthing-dist/`
**When** the user runs `pf init` followed by `pf doctor`
**Then** init copies the same commands, skills, and content directories as before
**And** doctor reports the same pass/fail results (with updated labels)
**And** no regressions in the monorepo developer workflow

## SM Assessment

**Setup complete.** Story 136-3 is ready for implementation.

- Jira PROJ-15843 claimed and moved to In Progress
- Branch `fix/136-3-fix-init-doctor-prefix-filtering` created from `develop`
- Session file created with full context, technical approach, and 5 ACs
- Trivial workflow — straight to Dev for implementation
- Dependency on 136-1 (unified pf discovery) is satisfied (completed in prior sprint work)

**Routing:** → Dev (Lucius Vorenus) for `implement` phase

## Delivery Findings

<!-- delivery-findings -->

### Dev (implementation)

- **Improvement** (non-blocking): `_find_pf_commands()` and `_find_pf_skills()` in `init/core.py` already work correctly with the `_dist/` path — no code changes needed there. The real fix was in 136-1 (`get_dist_root()`). Affects `pennyfarthing-dist/src/pf/init/core.py` (no change needed). *Found by Dev during implementation.*
- **Improvement** (non-blocking): `check_node_packages()` uses `package.json` presence as the npm project indicator rather than install method detection. This is simpler and doesn't require subprocess calls. Affects `pennyfarthing-dist/src/pf/doctor/checks.py` (implemented). *Found by Dev during implementation.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/_dist/__init__.py` — Added `skills/` to `is_populated()` check
- `pennyfarthing-dist/src/pf/doctor/checks.py` — Renamed `check_symlinks` → `check_content_dirs`, updated labels, suppressed `node_modules` warning for pip consumers
- `pennyfarthing-dist/src/pf/doctor/core.py` — Updated import and check function map
- `pennyfarthing-dist/src/pf/tests/test_doctor.py` — Updated test references, added pip consumer test

**Tests:** 46/46 passing (GREEN)
**Branch:** fix/136-3-fix-init-doctor-prefix-filtering (pushed)

**Handoff:** To Reviewer (Marcus Tullius Cicero) for code review

### Reviewer (code review)

- No upstream findings during code review.

## Reviewer Assessment

**Verdict:** APPROVED

**Preflight:** 101 tests pass (46 doctor + 55 init), all imports clean, no regressions.

**Data flow traced:** `check_node_packages(root)` → `root/node_modules` exists? → `root/package.json` exists? → status. Pure filesystem reads, no injection vectors. `checks.py:120-131`

**Pattern observed:** `package.json` as npm indicator is the right heuristic — simpler than subprocess-based install method detection, no false positives for standard layouts. `checks.py:128`

**Error handling:** All check functions handle missing directories gracefully (return fail/pass, never raise). `is_populated()` tightening verified against `pyproject.toml` package-data — `skills/**/*` is included.

**Observations:**
- [VERIFIED] Rename consistency — `check_symlinks` → `check_content_dirs` in all 3 files, no stale references
- [VERIFIED] `is_populated()` skills check is safe — `_dist/skills` exists in dev (symlink) and in wheel (package-data line 37)
- [VERIFIED] Test coverage complete — pip consumer pass, npm project warn, existing pass cases preserved
- [VERIFIED] Security — read-only filesystem checks, no user input parsed, no shell execution
- [LOW] `package.json` heuristic could miss edge cases with unconventional npm layouts, but standard usage is covered

**Handoff:** To SM (Titus Pullo) for finish-story