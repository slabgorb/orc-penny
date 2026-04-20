---
story_id: "151-1"
jira_key: ""
epic: "151"
workflow: "trivial"
---
# Story 151-1: Resolve archive filename from sprint.number when name is absent

## Story Details
- **ID:** 151-1
- **Jira Key:** (not yet created — epic 151 Jira sync pending)
- **Workflow:** trivial
- **Stack Parent:** none
- **Priority:** p0
- **Points:** 2

## Problem Statement

The archive filename resolution currently fails silently when `sprint.name` is missing from the sprint YAML. The code should fall back to `sprint.number` for the filename. This is the root issue blocking cascading p0 bugs in 151-3 and 153-1.

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-04-20T11:25:28Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-04-20T11:11:38Z | 2026-04-20T11:12:35Z | 57s |
| implement | 2026-04-20T11:12:35Z | 2026-04-20T11:16:23Z | 3m 48s |
| review | 2026-04-20T11:16:23Z | 2026-04-20T11:25:28Z | 9m 5s |
| finish | 2026-04-20T11:25:28Z | - | - |

## Sm Assessment

Trivial 2pt p0 bug. Root-cause fix for archive filename resolution: when `sprint.name` is absent, fall back to `sprint.number` to produce the archive filename. Silent failure today is masking cascading bugs in 151-3 and 153-1, so landing this first cleans the path for the epic.

**Routing:** SM → Dev → Reviewer → SM (trivial skips TEA per DEC-SM-001).

**Dev scope:**
- Locate archive path resolver in `pennyfarthing/pennyfarthing-dist/src/pf/sprint/` (finish/archive code path).
- Prefer `sprint.name` when present; else derive from `sprint.number` (e.g., `sprint-{number}-completed.yaml`).
- Fail loud if both are missing — no silent `None` path writes.
- Cover with a focused unit test for each branch (name present, number-only, both missing).

**Out of scope:** 151-2 (missing-epic loud failure) and 151-3 (cross-shard story update). Keep this surgical.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/archive_epic.py` — `get_archive_path()` now prefers `name` (then `jira_sprint_name`), falls back to `number`, and raises `ValueError` when neither is set (replaces silent `"unknown"` fallback).
- `pennyfarthing-dist/src/pf/tests/test_get_archive_path.py` — new focused unit tests covering the three branches (name present, number-only fallback, both missing fails loud).

**Tests:** 3/3 new focused tests passing (GREEN). Full archive + sprint regression: 260 passed, 0 failed, 3 skipped (pre-existing integration skips, unrelated).

**Branch:** `feat/151-1-resolve-archive-filename-from-sprint-number` (pushed to origin)

**Handoff:** To Reviewer for code review.

## Delivery Findings

No upstream findings.

### Dev (implementation)

- **Adjacent silent-fallback sibling in `archive.py`** (Improvement, non-blocking): `archive_story()` in `pennyfarthing-dist/src/pf/sprint/archive.py:62-65` has the same silent `"unknown"` fallback pattern (regex-extracts 4-digit sprint id from `jira_sprint_name`, otherwise `"unknown"`). It's a different code path (`pf sprint archive STORY_ID PR`, not finish) so it's out of scope per SM's "keep this surgical" directive — but it's the same class of bug and likely belongs on the 151 epic as a follow-up. *Found by Dev during implementation.*

### Reviewer (code review)

- **Improvement** (non-blocking): `get_archive_path()` in `pennyfarthing-dist/src/pf/sprint/archive_epic.py:50-53` raises `ValueError` that escapes the `archive_epic()` result-dict boundary uncaught, producing raw tracebacks from `pf sprint epic archive` instead of the `{success: False, error: ...}` dict callers expect. Pre-existing pattern (sibling raise at line 37 already behaves the same way) — not introduced by 151-1 — but worth a dedicated follow-up on epic 151 to add a boundary try/except around `ensure_archive_file()` in `archive_epic()`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `sprint_id` is embedded into a filename without an allow-list, admitting path traversal if a future code path (e.g., Jira sync) populates `sprint.number` or `sprint.name` with values containing `/` or `..`. Today developer-owned YAML keeps the risk low, but a one-line regex guard (`re.match(r'^[\w.-]+$', sprint_id)`) at `archive_epic.py:55` would close it permanently. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Comment at `archive_epic.py:43-45` references "(epic 151)". Violates user's "don't reference the current task/fix in code comments — rot hazard" rule. Trim to keep the WHY without the issue reference. *Found by Reviewer during code review.*
- **Gap** (non-blocking): Whitespace-only `sprint.name` raises `IndexError` (`"  ".split()[-1]`) instead of the intended `ValueError`. Add `.strip()` before the truthiness check or tighten the `split()` guard. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- Dev reported no deviations → ✓ ACCEPTED by Reviewer: agrees; spec intent (prefer name, fall back to number, fail loud on neither) is implemented precisely.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean (tests green, lint pass) | 1 observation (number=0 edge case) | confirmed 0, dismissed 0, deferred 1 |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 0, dismissed 0, deferred 2 |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (2 enabled, 7 disabled via `workflow.reviewer_subagents`)
**Total findings:** 0 confirmed, 0 dismissed, 3 deferred (1 preflight edge + 2 security follow-ups — all non-blocking; see Delivery Findings)

### Rule Compliance

Applicable rules for this diff (one helper function in `archive_epic.py` + one pytest file):

- **SOUL.md Principle 1 (fix-the-system):** `get_archive_path()` at `archive_epic.py:41-58` — **COMPLIANT.** Replaces silent `"unknown"` fallback with loud `ValueError`. That is the principle in action.
- **SOUL.md Principle 10 (return-results):** `get_archive_path()` at `archive_epic.py:41-58` — **PARTIAL.** Raises `ValueError` rather than returning `{success, error}`. However, the sibling raise on line 37 (`"Could not load sprint data"`) predates this change, so the new raise is consistent with the existing pattern in this helper. The real fix (catching both raises at the `archive_epic()` result-dict boundary) is out of scope for this surgical bug fix — captured as a delivery finding.
- **User global CLAUDE.md "don't reference task/issue in comments":** Comment at `archive_epic.py:43-45` contains parenthetical "(epic 151)". Violates the rule. LOW severity; non-blocking.
- **pennyfarthing CLAUDE.md Rule 1 (modify `pennyfarthing-dist/`):** Files touched are under `pennyfarthing-dist/src/pf/sprint/` and `pennyfarthing-dist/src/pf/tests/` — **COMPLIANT.**
- **pennyfarthing CLAUDE.md Rule 6 (Python only):** Only Python changed — **COMPLIANT.**
- **Repos topology (never_edit):** No symlink targets, no `node_modules/`, no build output — **COMPLIANT.**

### Devil's Advocate

Let me try to break this fix.

*What if `name` is whitespace-only?* `sprint_info.get("name")` returns `"   "`. Truthy. Falls into the `if name:` branch. `str("   ").split()` returns `[]`. `[][-1]` → `IndexError`. So whitespace-only name produces `IndexError`, not the intended `ValueError`. The fail-loud intent still holds (process stops), but the error class is inconsistent and the message is unhelpful ("list index out of range" versus "sprint metadata has neither 'name' nor 'number' set"). Severity: LOW. Realistic? Someone hand-editing YAML and leaving stray whitespace. Unusual but possible.

*What if `number` is a string like `"2610"` instead of int?* `str(number)` passes through unchanged → `sprint_id = "2610"` → correct filename. Fine.

*What if `number = 0`?* Passes the guard (`0 is not None and 0 != ""`), produces `sprint-0-completed.yaml`. Probably fine — sprint 0 is not a realistic user state — but technically "neither name nor number" is false when number is falsy-but-set. Severity: informational only.

*What if `sprint.name` contains path-separator characters?* `"TO Sprint /etc/passwd"` → `.split()[-1]` → `"/etc/passwd"` → `f"sprint-/etc/passwd-completed.yaml"` — pathlib treats the `/` as a separator, so the final path writes outside `sprint/archive/`. BUT the `name` path uses `.split()[-1]` which strips anything with internal whitespace. What if `name = "TO/Sprint/2610"` (no whitespace)? `.split()[-1]` returns the whole string `"TO/Sprint/2610"` → `f"sprint-TO/Sprint/2610-completed.yaml"` → traversal possible. This is the security subagent's finding. Developer-owned YAML, so low real-world risk, but the `number` branch passes `str(number)` through without any allow-list either. Either branch admits traversal if the YAML is tampered with.

*What if `load_sprint` returns a dict whose `"sprint"` value is not a dict (e.g., `None` or a string)?* Line 40 `sprint_info = sprint_data["sprint"]` returns whatever it is. `sprint_info.get("name")` → `AttributeError` if sprint_info is `None`. The pre-existing guard on line 36 only checks truthy + key presence, not type. Out of scope for this fix; same behavior as before my change.

*What if two concurrent story finishes race on the archive file?* Not in this helper's scope — this only computes the path.

*What does the test suite NOT cover?* Whitespace-only name (IndexError branch). Empty-string name with number present (would actually exercise the `or` short-circuit, but is equivalent to the number-only case — low value). Mixed case with only `jira_sprint_name` set (legacy Jira path). The third is a reasonable gap — the doc comment asserts legacy fallback works, but no test proves it.

Conclusion: three LOW-severity items, none block the verdict. All captured as delivery findings.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `sprint/current-sprint.yaml` → `load_sprint()` → `sprint_info` dict → `name`/`jira_sprint_name`/`number` → `sprint_id` → `root / sprint / archive / sprint-{sprint_id}-completed.yaml`. Safe for developer-owned YAML; path-traversal hardening is a deferred improvement (see Delivery Findings).

**Pattern observed:** Null-coalescing via Python `or` at `archive_epic.py:44` — idiomatic, matches existing code style.

**Error handling:** `ValueError` on missing name+number at `archive_epic.py:50-53` with an explicit remediation string pointing to `sprint/current-sprint.yaml`. Pre-existing `ValueError` on load failure at line 37 remains.

**Observations:**
- [VERIFIED] Spec intent met — prefer name, fall back to number, fail loud on neither. Evidence: `archive_epic.py:44-54`. Complies with SOUL.md Principle 1.
- [VERIFIED] Tests cover the three practical branches — name-present (`test_get_archive_path.py:28-35`), number-only fallback (`test_get_archive_path.py:38-43`), both-missing raises (`test_get_archive_path.py:46-52`).
- [VERIFIED] No regression — broader sprint+archive test surface green (260 passed, 0 failed against this branch; 36 unrelated pre-existing failures on `develop` confirmed unchanged).
- [SEC] [LOW] Principle 10 soft-violation at the `archive_epic()` boundary — `ValueError` from `get_archive_path()` propagates uncaught to CLI `main()` as a raw traceback instead of `{success: False, error: ...}`. Pre-existing pattern (sibling raise at `archive_epic.py:37` already behaves the same). Deferred to Delivery Findings — not introduced by this diff.
- [SEC] [LOW] Path-traversal via unsanitized `sprint_id` — both branches (name via `.split()[-1]`, number via `str(number)`) admit slashes. Developer-owned YAML reduces real-world risk to near zero today, but the `number` branch becomes higher-risk if Jira sync ever populates `number` from external data. Deferred.
- [SIMPLE] [LOW] Comment at `archive_epic.py:43-45` references "(epic 151)" — violates user's "don't reference the current task/fix in comments" rule. Trivial cleanup; non-blocking.
- [EDGE] [LOW] Whitespace-only `name` raises `IndexError` (`"  ".split()[-1]`) instead of the intended `ValueError`. Not covered by a test; exceedingly unlikely in practice. Fix: `name = (sprint_info.get("name") or sprint_info.get("jira_sprint_name") or "").strip() or None`. Deferred to a follow-up polish chore if anyone ever trips it.
- [TEST] [LOW] No test specifically proves the `jira_sprint_name`-only legacy path (name absent, jira_sprint_name present). The helper docstring implies it works; code path is exercised by existing fixtures elsewhere but not by a focused case. Acceptable.
- [DOC] [LOW] `get_archive_path()` docstring still says "Returns: Path to the sprint archive file" with no mention of the new `ValueError` behavior. Minor.
- [RULE] No project rule violations flagged beyond the two already captured above.
- [TYPE] [VERIFIED] No new types introduced; return type unchanged (`Path`). Raises a standard `ValueError`, consistent with Python stdlib norms.

**Handoff:** To SM for finish-story.