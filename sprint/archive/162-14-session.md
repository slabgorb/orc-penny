---
story_id: "162-14"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-14: pf sprint work next ignores priority — picker recommended p3 155-17 over six available p1 stories (found during 155-33 setup)

## Story Details
- **ID:** 162-14
- **Jira Key:** (Jira disabled for this story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-14-priority-picker
- **PR:** #196

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T13:05:35Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T12:42:45Z | 2026-08-10T12:44:45Z | 2m |
| red | 2026-08-10T12:44:45Z | 2026-08-10T12:49:26Z | 4m 41s |
| green | 2026-08-10T12:49:26Z | 2026-08-10T12:51:53Z | 2m 27s |
| review | 2026-08-10T12:51:53Z | 2026-08-10T12:57:52Z | 5m 59s |
| green | 2026-08-10T12:57:52Z | 2026-08-10T13:02:47Z | 4m 55s |
| review | 2026-08-10T13:02:47Z | 2026-08-10T13:05:35Z | 2m 48s |
| finish | 2026-08-10T13:05:35Z | - | - |

## Story Context

### Problem Statement

The `pf sprint work next` command's picker is not respecting story priority when selecting the next available story. During 155-33 setup, the picker recommended a P3 story (155-17) even though six P1 stories were available in the backlog.

### Technical Approach

The picker logic lives in `pennyfarthing/pennyfarthing-dist/src/pf/sprint/work.py`, specifically the `get_next_story()` function (lines 101–148). This function must:

1. **Filter available stories** to only those with status in `{backlog, ready, planning}` and unassigned or assigned to current user
2. **Sort by priority** using a canonical priority order: P0 > P1 > P2 > P3 (lower numeric value = higher priority)
3. **Prefer own assignments** — if you have assigned stories, select the highest-priority one of those first
4. **Return the first story** in the sorted list

Current behavior: The function sorts correctly by priority (lines 131–138), but the observed bug suggests either:
- Priority values in the sprint YAML are inconsistent/missing, causing fallback to P2
- The sort order has been inverted (higher index selected instead of lower)
- The available_statuses filter is inadvertently excluding P1 stories

### Acceptance Criteria

**AC1:** `pf sprint work next` selects the highest-priority available story from the backlog.

**AC2:** A P1 story is never passed over for a lower-priority (P2, P3) story when both are unassigned/available.

**AC3:** Given six available P1 stories and one P3 story, `pf sprint work next` returns one of the P1 stories (not the P3).

### Source Files to Investigate/Fix

- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/work.py` — main picker logic
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/loader.py` — story loading and filtering
- Test coverage: `pennyfarthing/pennyfarthing-dist/src/pf/tests/` — TDD phase must add tests for priority sorting before implementing fix

## SM Assessment

**Routing:** 2 pts, workflow `tdd` (phased) → full pipeline SM→TEA→Dev→Reviewer. Running peloton-inline (SM stays lead, drives each role via subagent; SM owns PR + merge + finish).

**Spec:** The story title is the spec — `pf sprint work next` must select the highest-priority available story; a p1 must never be passed over for a lower-priority story. Title-as-spec (no separate ACs), consistent with this epic.

**Technical approach for TEA/Dev:** Picker lives in `pennyfarthing-dist/src/pf/sprint/work.py` `get_next_story()`. Root-cause the priority-sort failure before fixing — the session's three hypotheses (missing/inconsistent priority values falling back to p2, inverted sort, or a filter excluding p1s) are candidates, not conclusions. RED must reproduce the reported failure: six available p1s + one p3 → picker returns a p1.

**Constraints:** TDD (failing test first). Scoped test runs only (`uv run pytest src/pf/tests/test_<...>.py -q` from `pennyfarthing-dist/`) — NEVER the full suite (pre-existing red leaks). `ruff check` changed files. Return result objects, don't throw.

## Delivery Findings

No upstream findings.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-edge-hunter | Yes | findings | Whitespace-padding gap (`.strip()` missing); raw priority return path; pre-existing assignment-dominates-priority sort order | INCORPORATED |
| 2 | reviewer-test-analyzer | Yes | findings | Tests sensitive to bug; no explicit-None priority test; no P0 test; patch-target drift risk on module-level import refactor; dominated id assertion | INCORPORATED |
| 3 | reviewer-preflight | Yes | clean | Tests 4/4 pass; ruff clean per Dev assessment; manual run confirms GREEN | INCORPORATED |
| 4 | reviewer-security | Yes | clean | No auth/injection/secrets surface in sort-key logic; priority values are internal YAML strings not user input | INCORPORATED |
| 5 | reviewer-type-design | Yes | clean | No type contract changes; `dict[str,Any]` return preserved; `.upper()` type-safe (str→str); `or "P2"` guard prevents None AttributeError | INCORPORATED |
| 6 | reviewer-rule-checker | Yes | clean | Return result-object pattern respected; no throws; `.js` extension rule N/A (Python); no project rule violations in changed files | INCORPORATED |

All received: Yes

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Test file `test_162_14_work_next_priority.py` is on disk but UNTRACKED — not committed to the feature branch. PR diff contains only `work.py`. Merging loses all regression coverage. | `pennyfarthing-dist/src/pf/tests/test_162_14_work_next_priority.py` (untracked) | `git add` the file and amend/new commit before PR |
| [MEDIUM] | Second `priority_order` call site in `cli.py:1520` has the same uppercased-key/lowercase-YAML bug, unfixed. `pf sprint check <epic_id>` returns wrong `first_story` priority order. Outside story ACs but same root cause. | `pennyfarthing-dist/src/pf/sprint/cli.py:1520` | Fix or file follow-up story |
| [LOW] | Whitespace-padded priority values (e.g. `" p1 "`) are truthy so `or` doesn't fire; `.upper()` preserves padding; dict lookup misses; falls to weight 2. `.strip()` needed before `.upper()`. | `work.py:136` | `(s.get("priority") or "P2").strip().upper()` |
| [LOW] | Return path at `work.py:147` echoes raw priority string without normalization. If YAML stores `p1` caller sees `"priority": "p1"` while sort used `"P1"`. Downstream equality checks against `"P1"` false-negative. | `work.py:147` | Return `.upper()` coerced value or note it's intentionally raw |

**Data flow traced:** `get_next_story()` → `get_all_stories()` mock → sort key `(s.get("priority") or "P2").upper()` lookup → `sorted_stories[0]` → return dict. Traced for p1, p3, None, empty-string inputs. Fix is logically correct.

**Pattern observed:** `(x or default).upper()` None-guard pattern at `work.py:136` — correct for None/missing/empty, but omits `.strip()`. TEA's alternative `s.get("priority", "P2").upper()` would throw `AttributeError` on None; Dev's choice is the better guard.

**Error handling:** `get_next_story()` returns `{available: False, error: "..."}` on empty backlog — correct result-object pattern, no throws observed.

**None-guard verified first-hand:** Python probe confirms:
- missing key → weight 2 ✓  |  `None` value → weight 2 ✓  |  `""` → weight 2 ✓
- `"p1"` → weight 1 ✓  |  `"P1"` → weight 1 ✓  |  `" p1 "` → weight 2 ⚠️ (whitespace defect)

**Tests verified:** 4/4 pass from disk. Tests are non-vacuous — assertions on `selected_id` and `selected_priority.lower()` are real. Guard test pins assignment-preference axis. BUT the file is untracked and absent from HEAD commit `176035384` (which contains only `work.py`).

**Second call site confirmed:** `cli.py:1519-1520` — independent `priority_order` dict with uppercase keys, same `s.get("priority", "P2")` without `.upper()`. Story's ACs don't cover `pf sprint check`, but the bug is identical.

**Working tree:** Pennyfarthing repo has one untracked file (the uncommitted test file). I performed no mutations. Tree otherwise clean.

**[TEST]** Four tests cover AC1/AC2/AC3 + assignment-preference guard. All three RED→GREEN tests are genuinely sensitive to the bug (verified). Gap: (1) no `{priority: None}` explicit-None test — present-but-None key diverges from missing-key under `get("priority", "P2")` alternative, not pinned; (2) no P0 test; (3) patch target `pf.sprint.loader.get_all_stories` is correct today (local import) but silently breaks if `work.py` switches to module-level import — latent maintenance hazard; (4) `selected_id != "155-17"` assertion is dominated by the priority assertion and adds no detection power. Tests pass from disk but the file is UNTRACKED — absent from HEAD commit, would not survive `git clone`.

**[RULE]** No project rule violations in `work.py`. Return result-object pattern (`{available, story, ...}`) respected. `.js` extension rule not applicable (Python). No throws.

**[SEC]** No auth, injection, or secrets surface in the changed code. Priority sort key processes only internal YAML strings, no user input. No security findings.

**[TYPE]** `dict[str, Any]` return type on `get_next_story()` unchanged. No new type contracts introduced. `.upper()` on a `str` is type-safe; the `or "P2"` guard ensures `.upper()` is never called on `None`.

**Handoff:** Back to Dev — stage and commit the test file; optionally fix `cli.py:1520` and `work.py:147` while there.

## Design Deviations

No deviations.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_14_work_next_priority.py` — regression suite for priority picker case-sensitivity bug

**Root Cause:**
`get_next_story()` in `work.py` (line 131) defines `priority_order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}` with uppercase keys. Sprint YAML stores priorities in lowercase (`p1`, `p2`, `p3` — confirmed in `sprint/epic-162.yaml` and `sprint/epic-163.yaml`). `priority_order.get("p1", 2)` misses the key, returns the default `2` for every lowercase value. All stories collapse to equal sort weight; Python's stable `sorted()` preserves list order. Whichever story loads first wins — in the 155-33 incident that was p3 story 155-17.

**Tests Written:** 4 tests covering AC1/AC2/AC3 + assignment-preference guard

| Test | Status | What it pins |
|------|--------|-------------|
| `test_p3_first_in_list_does_not_beat_six_p1s` | RED | Exact 162-14 scenario: p3 listed first, six p1s follow |
| `test_p1_beats_p2_when_p2_listed_first` | RED | AC2: p1 beats p2 regardless of list order |
| `test_missing_priority_does_not_beat_p1` | RED | Edge: missing-priority → P2 default must not beat p1 |
| `test_own_assigned_p1_beats_unassigned_p1` | GREEN (guard) | Assignment-preference axis must survive the fix |

**Status:** RED (3 failing, 1 guard passing — defect reproduced)

**Failing assertion (primary test):**
```
assert selected_id != "155-17"
AssertionError: get_next_story() selected p3 story 155-17 instead of a p1
```

**Run command:**
```
uv run pytest src/pf/tests/test_162_14_work_next_priority.py -q
```
Result: `3 failed, 1 passed in 0.21s`

**Interface Dev must satisfy to go GREEN:**
In `pennyfarthing-dist/src/pf/sprint/work.py`, `get_next_story()`, the sort key must normalise priority to uppercase before the dict lookup. Minimal fix:

```python
priority_order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
# Change:
priority_order.get(s.get("priority", "P2"), 2)
# To:
priority_order.get(s.get("priority", "P2").upper(), 2)
```

This makes `"p1".upper()` → `"P1"` → weight 1, `"p3".upper()` → `"P3"` → weight 3. Missing-priority stories keep their `"P2"` default (already uppercase — unchanged). No other files need modification.

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/work.py` — line 136: normalise priority to uppercase before dict lookup

**Fix shape:** TEA suggested `s.get("priority", "P2").upper()` — but that throws on `None` (present-but-None priority key). Implemented the safer `(s.get("priority") or "P2").upper()` which handles missing key, None value, and any existing uppercase values identically. One character wider than TEA's suggestion; zero behaviour change for well-formed data.

**Tests:** 4/4 passing (GREEN)
- `test_p3_first_in_list_does_not_beat_six_p1s` — was RED, now GREEN
- `test_p1_beats_p2_when_p2_listed_first` — was RED, now GREEN
- `test_missing_priority_does_not_beat_p1` — was RED, now GREEN
- `test_own_assigned_p1_beats_unassigned_p1` — guard, stayed GREEN

**Regression:** 1054 passed, 3 skipped (`-k "work or sprint or next"`) — no collateral breakage

**Ruff:** clean

**Branch:** `feat/162-14-priority-picker` (committed `176035384`)

**Design Deviations:** TEA's one-liner (`s.get("priority", "P2").upper()`) would throw `AttributeError` on a None-valued priority key. Used `(s.get("priority") or "P2").upper()` instead — same result for all non-None inputs, correct P2 default for None.

**Handoff:** To Reviewer

## Dev Assessment (rework round 1)

**Item 1 — untracked test file:** FIXED. Test file committed in `2973d2a`. `git log develop..HEAD --stat` confirms `test_162_14_work_next_priority.py` present as a `new file`.

**Item 2 — cli.py twin:** FIXED. `pennyfarthing-dist/src/pf/sprint/cli.py:1520` same `(s.get("priority") or "P2").strip().upper()` normalisation applied. Added `TestSprintCheckEpicSort` with two tests pinning the sort behavior directly. Testing inline rather than via CliRunner because the `pf sprint check` epic path requires `find_epic`, `load_sprint`, and full sprint-file infrastructure — a CliRunner test would be heavyweight for a one-line fix; the sort-key behavior is what matters and is fully pinned.

**Item 3 — `.strip()`:** FIXED. Applied at both `work.py:136` and `cli.py:1520`. `TestSprintCheckEpicSort.test_whitespace_padded_priority_normalises` pins the behaviour.

**Item 4 — raw lowercase priority in return value:** DEFERRED (recorded, no code change).

**Tests:** 6/6 passing (`test_162_14_work_next_priority.py`) — 4 original + 2 new cli.py sort tests
**Ruff:** clean (`work.py`, `cli.py`, test file)
**Tree:** clean — no `??` untracked files
**Commits:** `176035384` (original fix), `2973d2a` (rework — test file + cli.py twin + strip)

## Subagent Results

**Cycle: 1**
Method: targeted re-verification of all round-1 characterized findings (direct probes per finding, not generalist sweep).

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-edge-hunter | Yes | clean | Whitespace case re-verified — `.strip()` now applied at both sites; `" p1 ".strip().upper()` → `"P1"` → weight 1 ✓ | RESOLVED |
| 2 | reviewer-test-analyzer | Yes | clean | 6/6 pass; `test_whitespace_padded_priority_normalises` pins the strip gap; `TestSprintCheckEpicSort` pins cli.py twin inline | RESOLVED |
| 3 | reviewer-preflight | Yes | clean | `git status` clean; `git log` shows all 3 expected files in commit `2973d2a` | RESOLVED |
| 4 | reviewer-security | Yes | clean | No new security surface introduced by rework | RESOLVED |
| 5 | reviewer-type-design | Yes | clean | No type contract changes in rework diff | RESOLVED |
| 6 | reviewer-rule-checker | Yes | clean | No project rule violations in rework diff | RESOLVED |

All received: Yes

## Reviewer Assessment

**Cycle:** 1
**Verdict:** APPROVED

| Finding | Status | Evidence |
|---------|--------|----------|
| [HIGH] Test file untracked | ADDRESSED | Commit `2973d2abdb95b31225bb5156f62c7f4c7a197849` shows `test_162_14_work_next_priority.py` as `new file` in `--stat`; `git status` clean (no `??`) |
| [MEDIUM] `cli.py:1520` twin unfixed | ADDRESSED | `(s.get("priority") or "P2").strip().upper()` applied at `cli.py:1520`; `TestSprintCheckEpicSort` class pins it with `test_p3_first_does_not_beat_p1_in_epic_sort` |
| [LOW] `.strip()` missing at `work.py:136` | ADDRESSED | Both `work.py:136` and `cli.py:1520` now use `.strip().upper()`; `test_whitespace_padded_priority_normalises` passes |
| [LOW] Raw return path | DEFERRED | SM decision — not re-flagged |

**Tests verified first-hand:** `uv run pytest src/pf/tests/test_162_14_work_next_priority.py -q` → **6 passed in 0.14s** (4 original + 2 new).

**Diff scan (`git diff 176035384..HEAD`):** Three files changed, all expected:
- `cli.py` line 1520: one-token fix `.strip().upper()` — no collateral changes
- `work.py` line 136: `.strip()` added — no collateral changes
- Test file: 217-line addition, new file, no modifications to existing tests

No new breakage introduced by the rework.

**None-guard re-check:** `.strip()` before `.upper()` preserves all prior guard correctness — `None`/missing/empty still fall to `"P2"` via `or`; clean strings normalise correctly.

**[TEST]** 6/6 pass. `test_whitespace_padded_priority_normalises` specifically pins the `.strip()` gap. `TestSprintCheckEpicSort.test_p3_first_does_not_beat_p1_in_epic_sort` pins the `cli.py` twin fix. All round-1 tests unchanged and green. No vacuous assertions introduced.

**[RULE]** No project rule violations in rework diff. Return result-object pattern still respected in `work.py`. No throws.

**[SEC]** No new security surface in rework. `.strip()` added to internal string processing only.

**[TYPE]** No type contract changes. `.strip()` on a `str` returns `str`; chain `.strip().upper()` is type-safe. No new parameters or return types introduced.

**Working tree:** Clean — `git status` confirms "nothing to commit, working tree clean". No mutations performed.

**Handoff:** To SM for finish.