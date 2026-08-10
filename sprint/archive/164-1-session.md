---
story_id: "164-1"
jira_key: ""
epic: "164"
workflow: "tdd"
---
# Story 164-1: finish: partial session archive left on dialogue-copy OSError + misattributed step in archive except (155-15 review)

## Story Details
- **ID:** 164-1
- **Jira Key:** (none — local story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-1-partial-session-archive-oserror (created)
- **PR:** https://github.com/slabgorb/pennyfarthing/pull/197

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T14:04:17Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T13:01:34Z | - | - |

## Technical Context

### Problem Summary
Story 164-1 addresses a bug discovered during review of story 155-15 (finish: blocked merge leaves no stray archive). The issue is in `pennyfarthing-dist/src/pf/sprint/story_finish.py` in the archive step (lines 1587–1616).

**Bug 1: Partial Archive Left on OSError**
When archiving a completed story, the code attempts to copy both the session file (step 1) and optionally a dialogue file (step 1b). These operations are within a single try-except block. If the session copy succeeds but the dialogue copy raises OSError (disk full, permission denied, etc.), a partial archive is left behind — the session file is copied to `sprint/archive/` but the exception causes finish to abort before updating story status or removing the session. On retry, the stale session archive blocks progress.

**Bug 2: Misattributed Step in Exception Handler**
The except handler (line 1599–1606) catches ANY OSError from either copy operation but always reports `step: 1` in the result, even when the error originated in step 1b (dialogue copy). This misattribution obscures which operation failed and hides which file was partially archived.

### Root Cause Analysis
Lines 1587–1616 in `story_finish.py`:
```python
try:
    archive_dest = archive_dir / archive_name
    shutil.copy2(session_path, archive_dest)
    steps.append({"step": 1, "action": "archive_session", "dest": str(archive_dest)})

    if dialogue_path.exists():
        dialogue_dest = archive_dir / dialogue_archive_name
        shutil.copy2(dialogue_path, dialogue_dest)
        steps.append(
            {"step": "1b", "action": "archive_dialogue", "dest": str(dialogue_dest)}
        )
except OSError as exc:
    steps.append(
        {
            "step": 1,                           # ← BUG: Always step 1, never step 1b
            "action": "archive_session",         # ← BUG: Always archive_session
            "success": False,
            "error": str(exc),
        }
    )
    return { ... }
```

**Problems:**
1. If `shutil.copy2(session_path, archive_dest)` succeeds but `shutil.copy2(dialogue_path, dialogue_dest)` raises OSError, the session IS copied but the error handler reports success=False with step=1, creating a stray archive.
2. The exception handler cannot distinguish between a session-copy failure (step 1) and a dialogue-copy failure (step 1b), so it always reports step 1 with action archive_session.

### Solution Approach

Wrap the session and dialogue archives in separate try-except blocks. Each block should:
1. Attempt the copy operation
2. Append a success entry to `steps`
3. On OSError, append a failure entry with the CORRECT step/action and abort with a result dict
4. If the session copy succeeds but the dialogue copy fails, remove the partial archive before returning to ensure no stray file is left behind

**Implementation strategy:**
- Step 1 (session archive): wrap in try-except, catch OSError, abort immediately if it fails
- Step 1b (dialogue archive): only attempted if Step 1 succeeds; wrap in separate try-except, catch OSError, clean up the session archive copy if dialogue copy fails, then abort
- Each handler appends the correct step number and action to the steps list
- Both handlers return a consistent result dict with success=False before any later irreversible step (Jira transition, YAML update, etc.)

### Acceptance Criteria

1. **AC1:** When `shutil.copy2(session_path, archive_dest)` raises OSError, finish aborts with step=1/action=archive_session/success=False and returns before any irreversible step (merge already happened, but no Jira transition, no YAML update, no cleanup)
2. **AC2:** When `shutil.copy2(dialogue_path, dialogue_dest)` raises OSError, finish aborts with step=1b/action=archive_dialogue/success=False; the session archive is removed so no stray file is left
3. **AC3:** A test case covers OSError during dialogue copy; asserts no stray session archive is left behind (test_155_15_* pattern or new test_164_1_finish_dialogue_oserror_no_stray_archive.py)
4. **AC4:** A test case covers OSError during session copy; asserts finish aborts before the YAML transition and the session remains unremoved
5. **AC5:** Existing finish tests (155-15, 162-6, 162-9) continue to pass; no regression on already-merged/already-archived paths

## Delivery Findings

### Reviewer (code review)
- **Gap** (non-blocking): `except OSError: pass` on `archive_dest.unlink()` at `story_finish.py:1620` produces no diagnostic signal when cleanup itself fails. The returned error dict and steps list contain no trace of whether the stray archive was removed. An operator hitting a permission-denied unlink would see `success=False` with the dialogue-copy error but no indication the stray session archive persists in `sprint/archive/`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): TOCTOU between `dialogue_path.exists()` (line 1611) and `shutil.copy2` (line 1614). If the dialogue file is deleted between the check and the copy, `FileNotFoundError` (subclass of `OSError`) triggers the rollback which destroys the valid session archive. Recoverable on retry (exists() returns False, dialogue skipped), but creates an unnecessary retry cycle. Not a regression — original code also fails the scenario. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

No deviations from spec.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_164_1_finish_dialogue_oserror_no_stray_archive.py` — 7 tests across 3 classes covering both defects and regression guards

**Tests Written:** 7 tests covering AC1, AC2, AC3, AC4, AC5
**Status:** RED — 3 tests failing for the right reasons, 4 passing as regression guards

**RED failures:**
1. `TestDialogueOsErrorLeavesNoStrayArchive::test_no_stray_session_archive_when_dialogue_copy_raises` — Bug A: stray `164-1-session.md` left in sprint/archive/
2. `TestDialogueOsErrorMisattributedStep::test_failure_step_is_1b_when_dialogue_copy_raises` — Bug B: handler reports step=1 instead of "1b"
3. `TestDialogueOsErrorMisattributedStep::test_failure_action_is_archive_dialogue_when_dialogue_copy_raises` — Bug B: handler reports action=archive_session instead of archive_dialogue

**Passing regression guards (already-correct behavior):**
- result is failure on dialogue OSError (no-throw contract held)
- no done transition on dialogue OSError (abort before YAML)
- session OSError → step=1/action=archive_session (correct attribution, AC1)
- session OSError → no done transition (AC4)

**Design note:** `_copy2_real` is captured at module level to prevent the test's own `shutil.copy2` side-effect from recursing through the mock when the first call does the real copy. `patch("pf.sprint.story_finish.shutil.copy2")` replaces the attribute on the shared shutil module object, so any attribute lookup inside the patch context (including through an alias) finds the mock.

**Handoff:** To Dev for implementation (split try/except into two separate blocks)

## Workflow Tracking (updated by TEA)
**Phase advanced to:** red complete → ready for green

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — Split single try/except into two independent blocks; dialogue-copy failure now cleans up stray session archive and reports step="1b"/action="archive_dialogue"

**Tests:** 7/7 passing (GREEN) — new test file; 23/23 155-15 regression; 8/8 162-6; 16/16 162-9
**Branch:** feat/164-1-partial-session-archive-oserror (pushed)

**Handoff:** To Reviewer

## Subagent Results

**All received:** Yes

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 7/7 new pass, 81/81 regression pass (155-15, 162-6, 162-9) | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | TOCTOU dialogue_path.exists→copy2 (medium); unlink failure not propagated to caller (medium) | TOCTOU confirmed [LOW] non-blocking — pre-existing, recoverable on retry; unlink silent confirmed [MEDIUM] non-blocking |
| 3 | reviewer-silent-failure-hunter | Yes | findings | `except OSError: pass` on unlink (line 1620) swallowed — stray archive can persist with no signal in return dict (medium) | Confirmed [MEDIUM] non-blocking — best-effort cleanup accepted pattern |
| 4 | reviewer-test-analyzer | Yes | findings | No test for unlink-failure path (low); `_make_fake_run` "merge" in parts token dispatch (low); `test_does_not_transition_to_done` weak assertion (low) | All confirmed [LOW] non-blocking |
| 5 | reviewer-comment-analyzer | Yes | findings | Module docstring (line 7) shows pre-fix single-block pseudocode (stale); TestDialogueOsError class docstring line 244 says "Current behavior: single except" (stale); TestMisattributedStep class docstring line 337 same issue (stale) | Confirmed [LOW] non-blocking — historical context; SOUL #14 reference verified real |
| 6 | reviewer-rule-checker | Yes | clean | encoding= on all 4 write_text calls; success key on both return dicts; no bare raise; no additional pf rules violated | N/A |
| 7 | reviewer-security | Yes | findings | story_id path traversal via dialogue_dest (low, pre-existing); shutil.copy2 symlink follow (low, pre-existing); str(exc) path info leakage (low, informational) | All confirmed [LOW] non-blocking — pre-existing patterns, not introduced by this diff; developer-local tool |
| 8 | reviewer-simplifier | Yes | findings | `unlink(missing_ok=True)` at line 1619 would replace nested try/except OSError: pass (low) | Confirmed [LOW] non-blocking — cleaner but not blocking |
| 9 | reviewer-type-design | Yes | findings | `step: int | str` union undocumented in type system (low, pre-existing); `dict[str, Any]` return annotation hides shape contract (low, pre-existing) | Confirmed pre-existing, not a regression, [LOW] non-blocking |

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `shutil.copy2(dialogue_path, dialogue_dest)` raises OSError → `archive_dest.unlink()` removes stray session copy → steps append step="1b"/action="archive_dialogue"/success=False → returns `{success: False, ...}` before `transition_story("done")` is ever reached. No Jira transition, no YAML update, no session removal. Safe because no irreversible post-archive step is reached.

**Pattern observed:** Best-effort cleanup with broad swallowed error at `story_finish.py:1618-1621`. [SIMPLE] `archive_dest.unlink(missing_ok=True)` (Python 3.8+) would eliminate the nested try entirely — logged as non-blocking.

**Error handling:** [SILENT] `except OSError` at line 1590 (session copy) and line 1615 (dialogue copy) both return result dicts — no throw, SOUL #10 respected. Inner `except OSError: pass` at line 1620 is intentional best-effort cleanup. Trade-off: unlink failure is silent; stray archive can persist with no diagnostic signal. Non-blocking.

**RED verification:** Confirmed. On 2ba129a40 code: exactly 3 tests fail for the stated reasons (stray archive present, step=1 not "1b", action=archive_session not archive_dialogue). 4 regression guards pass. Failure messages precisely describe each bug.

**Test count:** 7/7 new tests pass (GREEN). 81/81 regression tests pass (155-15, 162-6, 162-9). [TEST] No test for unlink-failure path; unlink behavior is correct but untested. Non-blocking.

**Observations:**
1. [RULE] `encoding="utf-8"` on all 4 fixture write_text calls; result dicts have `success` key; no bare raise — all project rules met.
2. [EDGE] TOCTOU at story_finish.py:1611: `dialogue_path.exists()` races with `copy2`. If dialogue deleted between check and copy, `FileNotFoundError` triggers rollback that removes the valid session archive. Recoverable on retry, not a regression. [LOW]
3. [TYPE] `step` field is `int` for step 1 and `str` for step "1b" — pre-existing pattern throughout finish_story, not introduced here. No type annotations added or broken. [LOW] pre-existing.
4. [DOC] Three test file docstrings describe pre-fix "current behavior" as broken and tests as "RED" — stale after GREEN lands. Historical context; no reader will mistake test expectations. [LOW] non-blocking.
5. [SEC] `story_id` path traversal via `dialogue_archive_name` is pre-existing (line 1162), not introduced by this diff. Requires write access to sprint YAML to exploit. [LOW] pre-existing, informational.

**Findings by severity:**
| Severity | Tag | Issue | Location | Disposition |
|----------|-----|-------|----------|-------------|
| [MEDIUM] | [SILENT][EDGE] | `except OSError: pass` on `archive_dest.unlink()` — stray archive can silently persist, no signal in return dict or steps | story_finish.py:1620 | Non-blocking — best-effort cleanup is accepted pattern; captured as Delivery Finding |
| [LOW] | [EDGE] | TOCTOU `dialogue_path.exists()` + `copy2` — concurrent dialogue delete triggers rollback destroying valid session archive; recoverable on retry | story_finish.py:1611 | Non-blocking — pre-existing pattern, unusual scenario |
| [LOW] | [SIMPLE] | `archive_dest.unlink(missing_ok=True)` eliminates nested try | story_finish.py:1619 | Non-blocking — simplification opportunity |
| [LOW] | [TEST] | No test for unlink-failure path | test_164_1_...py | Non-blocking — intentional best-effort |
| [LOW] | [DOC] | 3 stale class/module docstrings describe pre-fix behavior as "current" | test_164_1_...py:7,244,337 | Non-blocking — historical context |
| [LOW] | [TYPE][SEC] | Pre-existing: int\|str step union untyped; story_id path traversal | story_finish.py:1162,1593 | Non-blocking — pre-existing, not introduced by diff |

**Handoff:** To SM for finish-story