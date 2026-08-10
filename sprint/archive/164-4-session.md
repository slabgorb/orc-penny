---
story_id: "164-4"
jira_key: ""
epic: "164"
workflow: "trivial"
---
# Story 164-4: Guard whitespace-only sprint name in archive path

## Story Details
- **ID:** 164-4
- **Jira Key:** (none — local-only)
- **Workflow:** trivial
- **Stack Parent:** none
- **Branch:** feat/164-4-guard-whitespace-sprint-name
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-08-10T15:49:51Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T15:34:38Z | - | - |

## Technical Context

**Bug Location:** `pennyfarthing/pennyfarthing-dist/src/pf/sprint/archive_epic.py::get_archive_path()` lines 56–57

**Root Cause:** When sprint name is whitespace-only (e.g., `'   '`), the expression `str(name).split()[-1]` returns an empty list from `.split()`, and accessing `[-1]` raises `IndexError` at line 57. This happens **upstream** of the 155-7 sanitization guard at line 71 (`validate_sprint_id(sprint_id)`), so the IndexError bypasses the guard and crashes `pf sprint epic archive` / story finish with a traceback instead of a clean ValueError.

**Existing Guard:** Lines 61–64 already raise a clean ValueError when sprint name is empty/absent:
```python
raise ValueError(
    "Cannot resolve archive filename: sprint metadata has neither 'name' "
    "nor 'number' set. Check sprint/current-sprint.yaml."
)
```

**Acceptance Criteria:**
1. `get_archive_path()` guards the empty-token case (name is whitespace-only / `.split()` yields `[]`) and raises **the same actionable ValueError shape** used by 155-7 sanitization (message includes guidance like "Check sprint/current-sprint.yaml") **instead of an IndexError**.
2. One test case with `name='   '` (whitespace-only) asserts the clean ValueError (not IndexError). A legit name still works (regression guard).

**Exact Error Message Format:** Match the style from `path_validation.py::_validate_ref()`:
- Starts with `"Invalid sprint id"`
- Includes guidance: `"Check sprint/current-sprint.yaml"`
- Example: `"Invalid sprint id '': must not be empty. Check sprint/current-sprint.yaml."`

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/archive_epic.py` — guard empty token list from whitespace-only name before `[-1]` access (lines 56-63)
- `pennyfarthing-dist/src/pf/tests/test_get_archive_path.py` — 2 new tests: whitespace-only name raises ValueError with guidance; legit name regression guard

**Tests:** 10/10 passing (GREEN)
**Branch:** feat/164-4-guard-whitespace-sprint-name (pushed)

**Handoff:** To Reviewer

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 5/5 pass, ruff clean, no TODOs/skips | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 4 pre-existing issues (mkdir before validate, non-string YAML, falsy scalars, double load) | Dismissed — pre-existing, not in this diff |
| 3 | reviewer-silent-failure-hunter | Yes | findings | ensure_archive_file docstring missing Raises declaration; all 3 callers wrap correctly | Low |
| 4 | reviewer-test-analyzer | Yes | findings | test_legit_sprint_name_still_resolves tautological (Medium); jira_sprint_name path not tested (Medium); whitespace variants narrow (Low) | Medium/Medium/Low |
| 5 | reviewer-comment-analyzer | Yes | findings | get_archive_path Raises doc missing new whitespace case (downgraded Medium); inline comment scope narrow (Medium); ensure_archive_file no Raises section (Medium) | Medium/Medium/Medium |
| 6 | reviewer-type-design | Yes | findings | str(name) implicit narrowing — rebind to name_str: str would be cleaner | Low |
| 7 | reviewer-security | Yes | clean | None — Unicode NBSP falls through to validate_sprint_id which rejects it; CWE-22 chain intact | N/A |
| 8 | reviewer-simplifier | Yes | findings | walrus operator style (Low); centralize empty-check in validator (Low); str() cast intent (Low) | Low/Low/Low |
| 9 | reviewer-rule-checker | Yes | clean | None — Rule 6 satisfied by documented Raises contract; no new file opens; encoding= N/A | N/A |

**All received:** Yes

## Delivery Findings

### Reviewer (code review)
- **Gap** (non-blocking): `test_legit_sprint_name_still_resolves` uses `name="TO Sprint 2699"` / `number=2699` — both name-token path and number-fallback produce identical output; assertion cannot distinguish which code path ran. Use `number=9999` to make it load-bearing. Pre-existing pattern also in `test_uses_name_token_when_name_present`. Affects `pennyfarthing-dist/src/pf/tests/test_get_archive_path.py:69`. *Found by Reviewer during code review.* [TEST]
- **Gap** (non-blocking): `jira_sprint_name` whitespace-only path not tested — same `or`-chain, same guard fires, same bug surface as `name`. Affects `pennyfarthing-dist/src/pf/tests/test_get_archive_path.py`. *Found by Reviewer during code review.* [TEST]
- **Gap** (non-blocking): `get_archive_path()` Raises docstring doesn't enumerate the new whitespace-only name case; `ensure_archive_file()` has no Raises section at all. Callers already wrap generically — documentation completeness only. Affects `pennyfarthing-dist/src/pf/sprint/archive_epic.py:38,93`. *Found by Reviewer during code review.* [DOC]
- **Gap** (non-blocking): Inline comment at line 53 says "Fail loud if neither is set" — scope is now too narrow; it should include the whitespace-only case. Affects `pennyfarthing-dist/src/pf/sprint/archive_epic.py:53`. *Found by Reviewer during code review.* [DOC]

## Design Deviations

No deviations from spec.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `sprint_info.get("name")` (whitespace-only YAML string `"   "`) → `str(name).split()` returns `[]` → `if not tokens:` guard fires at line 58 → raises `ValueError("Invalid sprint id '   ': must not be empty. Check sprint/current-sprint.yaml.")` → propagates through `ensure_archive_file()` → caught by `archive_epic()` / `archive.py` / `story_finish.py` try/except ValueError → returned as `{success: False, error: ...}`. IndexError cannot occur: guard precedes `tokens[-1]` at line 63.

**Pattern observed:** Input validation before index access at `archive_epic.py:57–63`. Matches existing shape at lines 65–70. Consistent with project ValueError contract. [RULE] — Rule 6 satisfied by documented Raises contract.

**Error handling:** All three callers wrap `get_archive_path()`/`ensure_archive_file()` via try/except ValueError: `archive.py:65–68`, `archive_epic.py:565–568`, `story_finish.py:112–115`. No uncaught raise path. [SILENT]

**Security:** [SEC] Clean — Unicode-whitespace NBSP bypass non-issue (validate_sprint_id's charset check catches it); CWE-22 chain intact; no information disclosure.

**Observations:**
1. [EDGE] Guard at line 58 precedes `tokens[-1]` at line 63 — IndexError structurally impossible. Pre-existing edge cases (non-string YAML, falsy scalars) all pre-existing, not introduced here.
2. [TEST] `test_legit_sprint_name_still_resolves` tautological — Medium, pre-existing pattern, not blocking. `jira_sprint_name` whitespace path not tested — Medium, gap only.
3. [DOC] `get_archive_path()` Raises section incomplete; `ensure_archive_file()` has no Raises section; inline comment at line 53 scope too narrow — all Medium, documentation gaps only, callers already wrap generically.
4. [TYPE] `str(name)` cast is correct and necessary given `Any` from dict; implicit narrowing is Low concern.
5. [SIMPLE] Walrus operator and centralizing empty-check are Low style suggestions; current form is clear.

**Findings:**
| Severity | Issue | Location |
|----------|-------|----------|
| [MEDIUM] | [TEST] `test_legit_sprint_name_still_resolves` tautological — use `number=9999` to distinguish name-path from number-fallback | `test_get_archive_path.py:69` |
| [MEDIUM] | [TEST] `jira_sprint_name` whitespace-only path not tested | `test_get_archive_path.py` |
| [MEDIUM] | [DOC] `get_archive_path()` Raises doc missing new whitespace case; inline comment scope too narrow | `archive_epic.py:38,53` |
| [LOW] | [DOC] `ensure_archive_file()` missing Raises section | `archive_epic.py:93` |
| [LOW] | [TYPE] `str(name)` implicit narrowing — rebind to `name_str: str` would be cleaner | `archive_epic.py:57` |
| [LOW] | [SIMPLE] Walrus operator would collapse 4-line pattern to 3 | `archive_epic.py:57–63` |

**Handoff:** To SM for finish-story