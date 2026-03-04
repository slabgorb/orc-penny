# Story 132-1: Fix pf-* prefix filter in init and doctor

**Status:** in-progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** feature/132-1-fix-pf-prefix-filter-init-doctor
**Points:** 2
**Epic:** 132 — Release Workflow Hardening (11.x Followup)
**Jira:** (none)

## Story Details

### Acceptance Criteria

1. **pf init** command correctly filters and copies only `pf-*` prefixed command files
   - Should exclude non-pf-* files in the commands directory
   - Symlink targets should be properly validated

2. **pf doctor** command correctly identifies and counts all `pf-*` prefixed commands and skills
   - Commands check should filter by glob pattern `pf-*` correctly
   - Skills check should filter directories starting with `pf-` correctly
   - Both checks should report accurate counts

3. All health checks pass after fix is applied
   - init copies correct number of commands
   - doctor reports correct pf-* command and skill counts

### Key Files

- **Init core:** `/Users/keithavery/Projects/pf-2/pennyfarthing/pennyfarthing-dist/src/pf/init/core.py`
  - `_find_pf_commands()` at line 302 — uses glob pattern
  - `_find_pf_skills()` at line 310 — uses startswith filter

- **Doctor checks:** `/Users/keithavery/Projects/pf-2/pennyfarthing/pennyfarthing-dist/src/pf/doctor/checks.py`
  - `check_commands()` at line 96 — uses glob pattern
  - `check_skills()` at line 107 — uses startswith + is_dir filter

### Problem Analysis

The issue appears to be:
1. `check_commands()` uses `glob("pf-*")` without filtering by file type (should be `.is_file()`)
2. `check_skills()` correctly uses both `.is_dir()` and `.startswith("pf-")`
3. `_find_pf_commands()` uses `glob("pf-*.md")` which should be safe but may need verification
4. `_find_pf_skills()` uses `.startswith("pf-")` which is correct

## Next Steps

1. Investigate the exact filtering behavior in both init and doctor
2. Create minimal test cases to reproduce the issue
3. Fix the filtering logic to ensure correct pf-* prefix matching
4. Verify all health checks pass

---

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `_find_pf_commands()` → `init_project()` → `shutil.copy2()` (safe — filesystem paths only, no user input)
**Pattern observed:** Consistent filtering pattern across init/doctor: glob with extension + `.is_file()`/`.is_dir()` at `checks.py:101`, `core.py:307`
**Error handling:** Both functions degrade gracefully — return empty list if directory missing at `checks.py:99-100`, `core.py:305-306`

**Observations:**
- `[VERIFIED]` `check_commands()` fix adds both `.md` extension and `.is_file()` filter
- `[VERIFIED]` `_find_pf_commands()` adds defensive `.is_file()` guard
- `[VERIFIED]` Symlink handling correct — `Path.is_file()` follows through
- `[VERIFIED]` Init/doctor now use consistent filtering (`pf-*.md` + file check)
- `[VERIFIED]` `check_skills()` and `_find_pf_skills()` already correct, left alone
- `[LOW]` Tests don't explicitly verify directory exclusion — acceptable for 2-point scope

**Handoff:** To SM for finish-story

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/doctor/checks.py` - `check_commands()` now uses `glob("pf-*.md")` with `.is_file()` filter instead of bare `glob("pf-*")`
- `pennyfarthing-dist/src/pf/init/core.py` - `_find_pf_commands()` now enforces `.is_file()` on glob results

**Tests:** 45/45 passing in test_doctor.py (GREEN)
**Branch:** feature/132-1-fix-pf-prefix-filter-init-doctor (pushed)
**Health Checks:** All 10 doctor checks pass — 37 commands, 22 skills correctly counted

**Note:** 1 pre-existing failure in `test_init_frontmatter_integration.py` (infrastructure hooks count 7 vs expected 5) — unrelated to this story, confirmed by testing before/after changes.

**Handoff:** To next phase (review)

---

## SM Assessment

**Setup Complete:** Yes
**Branch:** feature/132-1-fix-pf-prefix-filter-init-doctor (created)
**Session:** Created with ACs, key files, problem analysis
**Next Phase:** implement (Dev)