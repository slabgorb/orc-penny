# Story Context: PROJ-14258

## Pre-commit Hook for YAML Validation

**Epic:** PROJ-14253 (Sprint Data Management System)
**Points:** 2 | **Workflow:** trivial | **Priority:** P1

## Overview

Add pre-commit hook that runs sprint YAML validation on staged `sprint/*.yaml` files before allowing commits. Must complete in under 2 seconds.

## Technical Approach

The pre-commit hook adds sprint YAML validation as a new check in the existing `pennyfarthing/pennyfarthing-dist/scripts/hooks/pre-commit.sh` script. This script is installed at `.git/hooks/pre-commit` and currently performs branch protection and agent file validation. The new check uses `git diff --cached --name-only -- 'sprint/*.yaml'` to identify staged sprint YAML files, and invokes `validate_sprint_yaml()` from `pennyfarthing_scripts.sprint.validate_cmd` in a single Python process.

Performance is critical: the 2-second budget is achievable because (a) the fast path skips entirely when no sprint YAML is staged, (b) Python startup plus YAML parsing for 2-3 small files is well under 1 second, and (c) only staged files are validated. A single Python process validates all staged files to avoid repeated startup overhead.

## Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing/pennyfarthing-dist/scripts/hooks/pre-commit.sh` | Add "Check 3: Sprint YAML Validation" section |
| `.git/hooks/pre-commit` | Update (re-run installer or re-symlink) |
| `pennyfarthing/pennyfarthing-dist/scripts/hooks/README.md` | Update hook description table |

## Hook Script Design

1. **Detect staged sprint YAML files** — `git diff --cached --name-only -- 'sprint/*.yaml' 'sprint/archive/*.yaml'`, exclude `sprint-template.yaml`
2. **Early exit if none** — exit the section (not the script), fast path
3. **Single Python invocation** — `PYTHONPATH="$PROJECT_ROOT/pennyfarthing" python -c "..."` validates all files
4. **Actionable error messages** on failure:
   ```
   COMMIT BLOCKED - Sprint YAML validation failed
   Fix: Review errors above, then: just validate-sprint --fix sprint/current-sprint.yaml
   ```
5. **Exit codes** — `exit 1` blocks commit on failure

## Performance Strategy

- Early exit when no sprint YAML staged (< 10ms)
- Only validate staged files, not entire `sprint/` directory
- Single Python process for all files (avoids ~200ms per startup)
- Validation-only path uses `yaml.safe_load` (fast), not ruamel.yaml
- Expected: ~160ms total (Python startup + import + parse + validate)

## Installation Strategy

- Source: `pennyfarthing/pennyfarthing-dist/scripts/hooks/pre-commit.sh`
- Install: `pennyfarthing/pennyfarthing-dist/scripts/git/install-git-hooks.sh` creates symlinks
- Re-run installer after modifying source to update `.git/hooks/pre-commit`

## CI Compatibility

- No interactive prompts, clear stderr/stdout separation
- Exit 0 = pass, Exit 1 = fail
- Falls back to `python3` if venv missing; skip with warning if Python unavailable

## Test Strategy

- Manual: stage valid/invalid YAML, verify commit blocks/passes
- Standalone: run `.git/hooks/pre-commit` directly
- Performance: `time .git/hooks/pre-commit` < 2 seconds
- Edge cases: no YAML staged, malformed YAML, missing Python

## Dependencies

- **76-2:** `validate_sprint_yaml()` from `validate_cmd.py`
- **76-1:** `read_sprint()` from `yaml_io.py` (used indirectly)
- Existing pre-commit hook infrastructure

## Edge Cases

- No sprint YAML staged — fast exit, no delay
- `sprint-template.yaml` staged — exclude from validation (placeholder values)
- File staged but deleted before hook runs — "File not found" error
- Python venv missing — fall back to system `python3` or skip with warning
- Archive YAML files — include in validation
