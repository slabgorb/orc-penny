# Story 76-5: Pre-commit hook for YAML validation

**Jira:** MSSCI-14258
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14258-pre-commit-yaml-validation
**Workflow:** trivial
**Phase:** approved
**Started:** 2026-02-05

## Story

Add pre-commit hook that runs /sprint validate on all sprint/*.yaml files before allowing commits.

Requirements:
- Run in < 2 seconds
- Clear exit codes (0 = pass, non-zero = fail)
- Actionable error messages with fix commands
- Works in CI (no interactive prompts)

## Acceptance Criteria

- Blocks commits with invalid YAML
- Error message includes fix command
- Completes in under 2 seconds
- Works in non-interactive CI environment

## Context

**Epic:** MSSCI-14253 (Sprint Data Management System)
**Points:** 2 | **Priority:** P1

### Technical Approach

The pre-commit hook adds sprint YAML validation as a new check in the existing `pennyfarthing/pennyfarthing-dist/scripts/hooks/pre-commit.sh` script. This script is installed at `.git/hooks/pre-commit` and currently performs branch protection and agent file validation. The new check uses `git diff --cached --name-only -- 'sprint/*.yaml'` to identify staged sprint YAML files, and invokes `validate_sprint_yaml()` from `pennyfarthing_scripts.sprint.validate_cmd` in a single Python process.

### Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing/pennyfarthing-dist/scripts/hooks/pre-commit.sh` | Add "Check 3: Sprint YAML Validation" section |
| `.git/hooks/pre-commit` | Update (re-run installer or re-symlink) |
| `pennyfarthing/pennyfarthing-dist/scripts/hooks/README.md` | Update hook description table |

### Performance Strategy

- Early exit when no sprint YAML staged (< 10ms)
- Only validate staged files, not entire `sprint/` directory
- Single Python process for all files (avoids ~200ms per startup)
- Validation-only path uses `yaml.safe_load` (fast), not ruamel.yaml
- Expected: ~160ms total (Python startup + import + parse + validate)

### Dependencies

- **76-2:** `validate_sprint_yaml()` from `validate_cmd.py`
- **76-1:** `read_sprint()` from `yaml_io.py` (used indirectly)
- Existing pre-commit hook infrastructure

### Edge Cases

- No sprint YAML staged -- fast exit, no delay
- `sprint-template.yaml` staged -- exclude from validation (placeholder values)
- File staged but deleted before hook runs -- "File not found" error
- Python venv missing -- fall back to system `python3` or skip with warning
- Archive YAML files -- include in validation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/scripts/hooks/pre-commit.sh` - Added Check 3: Sprint YAML Validation
- `pennyfarthing-dist/scripts/hooks/README.md` - Updated hook description

**Tests:**
- Fast path (no YAML staged): 0.085s, exit 0
- Valid YAML: 0.176s, exit 0 (format warnings shown, non-blocking)
- Invalid YAML: 0.152s, exit 1 (schema errors shown, commit blocked)
- Template exclusion: `sprint-template.yaml` correctly skipped

**PR:** #678 - feat(hooks): add sprint YAML validation to pre-commit hook
**Branch:** feature/MSSCI-14258-pre-commit-yaml-validation (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** staged file path → git diff → grep filter → Python validate_sprint_yaml() → ValidateResult → exit code → commit gate (safe — no injection vectors)
**Pattern observed:** Follows existing Check 2 pattern (detect staged files, validate, block on failure) at pre-commit.sh:111-189
**Error handling:** Deleted file warning (line 145-148), missing Python graceful skip (line 131-132), PYTHONPATH save/restore (line 137-172)
**Note:** [LOW] Python invoked per-file instead of batched, but measured <200ms for typical commits — not blocking

**Handoff:** To SM for finish-story

## Session Log

- **2026-02-05** SM: Story setup, routing to Dev (trivial workflow)
- **2026-02-05** Dev: Implementation complete, PR #678 created, handing off to Reviewer
- **2026-02-05** Reviewer: APPROVED — no Critical/High issues, all ACs met
