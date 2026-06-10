---
story_id: "160-1"
jira_key: "none"
epic: "160"
workflow: "tdd"
---
# Story 160-1: validate_epic_shard skips per-story value checks (status enum, points numeric) — shard updates validate weaker than inline/indexed (from 156-1 M2)

## Story Details
- **ID:** 160-1
- **Jira Key:** none
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-10T19:20:15Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-10T19:10:38.975573+00:00 | 2026-06-10T19:11:37Z | 58s |
| red | 2026-06-10T19:11:37Z | 2026-06-10T19:14:09Z | 2m 32s |
| green | 2026-06-10T19:14:09Z | 2026-06-10T19:16:44Z | 2m 35s |
| review | 2026-06-10T19:16:44Z | 2026-06-10T19:20:15Z | 3m 31s |
| finish | 2026-06-10T19:20:15Z | - | - |

## Sm Assessment

**Story:** 160-1 — validate_epic_shard skips per-story value checks (status enum, points numeric); shard updates validate weaker than inline/indexed. From 156-1 review finding M2.

**Scope:** The sprint validator (pennyfarthing-dist/src/pf/sprint) applies per-story value checks — status enum membership, numeric points — when validating inline/indexed sprint stories, but `validate_epic_shard` skips those checks for shard files (`sprint/epic-*.yaml`). Since most stories live in shards, shard-path updates get weaker validation than the inline path. Fix is parity: shard validation must run the same per-story value checks.

**Acceptance criteria:**
1. `validate_epic_shard` rejects shard stories with invalid status values (outside the status enum) the same way inline validation does.
2. `validate_epic_shard` rejects shard stories with non-numeric points.
3. Existing valid shards continue to pass (no regression in current sprint fixtures).
4. Error messages identify the offending story id and field, consistent with inline-path errors.

**Technical approach:** Locate where inline/indexed per-story validation lives in the validator and reuse that same routine from `validate_epic_shard` (one truth, one place — don't duplicate the enum/points checks). TEA writes failing tests demonstrating a shard with bad status / non-numeric points currently passes shard validation; Dev wires the shared check in.

**Routing:** tdd (phased) — TEA (red) → Dev (green) → Reviewer (review). 2 points, repo pennyfarthing, branch `feat/160-1-validate-epic-shard-story-checks` off develop.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### Reviewer (code review)
- **Gap** (non-blocking): `validate_epic_shard` crashes with `AttributeError: 'str' object has no attribute 'get'` when a story entry in the `stories` list is a non-dict (e.g. a bare string or null). The crash occurs at the PRE-EXISTING line `story_id = story.get("id")` (validator.py:409), which predates this story and is also present on `develop`. The 160-1 change actually adds a defensive `isinstance(story, dict)` guard before the new value-check block, but the crash fires upstream of it. Affects `pennyfarthing-dist/src/pf/sprint/validator.py:408-409` (guard the per-story loop against non-dict entries, e.g. emit a typed error instead of crashing). *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### Dev (implementation)
- **Presence-error filtering instead of dropping the shard presence loop:** The designed interface offered "delegate presence or keep both, either is fine." I kept the shard loop's own presence check and filtered out `validate_story`'s "Missing required field" errors when merging, so the two presence sources don't double-report. Net effect matches the spec's intent; no test impact.
- **Path base = story's own id (AC4 fix option a):** Called `validate_story(story, path_base, idx)` with `path_base = str(story_id)`, so value-error paths become `94-2.stories[0].status` — the offending story id appears in the path. This is the spec's recommended option (a). No change to `validate_story` itself.

## Tea Assessment

**Tests Required:** Yes
**Test File:** `pennyfarthing-dist/src/pf/tests/test_epic_shard_validation.py` (canonical home for `validate_epic_shard` tests; new class `TestShardStoryValueChecks` added)
**Tests Written:** 6 tests covering 4 ACs (4 failing RED + 2 passing-path guards)
**Status:** RED — 4 new tests fail for the right reason; 46 existing tests in file + 50 in `test_sprint_validator.py` still pass.

## Tea Handoff

### Gap confirmed
`validate_epic_shard` (validator.py:333-426) per-story loop (lines 408-424) only checks duplicate IDs and required-field PRESENCE. It never checks field VALUES. The inline/indexed path `validate_story` (validator.py:197-262) DOES check:
- **status enum:** `status not in VALID_STORY_STATUSES` → `Invalid status '{status}'. To fix: Use one of: ...` (lines 234-241)
- **numeric points:** `not isinstance(points, (int, float))` → `Invalid points value '{points}'. To fix: Use a number...` (lines 244-250)

So a shard story with `status: bogus` or `points: "three"` currently passes shard validation. That is the bug.

### Status enum (derived from code, not assumption)
`VALID_STORY_STATUSES` = `{backlog, ready, in_progress, in_review, done, canceled, planning, split}` (validator.py:69-78).

### Designed interface for Dev (GREEN)
**One truth, one place** (SM technical approach + CLAUDE.md rule 6): do NOT duplicate the enum/points checks inside `validate_epic_shard`. Reuse the existing inline routine.

Recommended implementation: in the `validate_epic_shard` per-story loop (after the required-field presence check, ~line 424), call the shared per-story validator and merge its result:

```python
story_result = validate_story(story, epic_id, idx)
result.merge(story_result)
```

`validate_story(story, epic_id, story_index)` already exists and produces:
- status error path `{epic_id}.stories[{idx}].status`
- points error path `{epic_id}.stories[{idx}].points`
- jira error path `{epic_id}.stories[{idx}].jira`

Caveats for Dev to resolve so tests pass AND no regression:
1. **Required-field messages may now duplicate.** Both the shard loop's presence check and `validate_story` emit "Missing required field: ..." — keep the existing `test_story_missing_required_fields` green (it asserts presence of title/points/status in the joined messages; duplication won't break it, but avoid changing wording). Prefer delegating the presence check to `validate_story` and dropping the shard loop's own presence loop, OR keep both — either is acceptable as long as existing tests stay green.
2. **AC4 — offending story id must be locatable.** My tests assert `"94-2" in (e.message + e.path)`. `validate_story` puts the *epic* id + story *index* in the path (`94.stories[1].status`), NOT the story's own id `94-2`. For the test to pass, the offending story's own id must appear in the error message or path. Two valid fixes: (a) pass the story's own id as the `epic_id`/path base when delegating, or (b) augment `validate_story` (or the shard call site) so the path/message includes the story id. Match the inline path's *field naming* (status/points) — that part is already consistent.
3. **AC3 — no regression.** `test_shard_story_with_valid_status_from_enum_passes` iterates every enum member; `test_shard_story_with_numeric_points_passes` covers int + float (incl. 0 and 2.5). Keep float accepted.

### Test names (all in `TestShardStoryValueChecks`)
- `test_shard_story_with_invalid_status_fails` (AC1, RED)
- `test_shard_story_with_valid_status_from_enum_passes` (AC1/AC3 guard, currently GREEN)
- `test_shard_story_with_non_numeric_points_fails` (AC2, RED)
- `test_shard_story_with_numeric_points_passes` (AC2/AC3 guard, currently GREEN)
- `test_valid_shard_with_multiple_good_stories_still_passes` (AC3, currently GREEN)
- `test_invalid_status_error_identifies_story_and_field` (AC4, RED)
- `test_non_numeric_points_error_identifies_story_and_field` (AC4, RED)

### Run command (targeted — never full suite, it switches git branches)
`python3 -m pytest pennyfarthing-dist/src/pf/tests/test_epic_shard_validation.py -v`

**Commit:** `0017650` on `feat/160-1-validate-epic-shard-story-checks`, GPG-signed (G), tree clean.
## Dev Handoff

**Phase:** finish → review  |  **Agent:** dev  |  **Status:** GREEN

### Summary
Brought `validate_epic_shard` to parity with the inline path. The per-story loop now delegates value validation (status-enum membership, numeric points, jira format) to the existing `validate_story` routine — one truth, one place, no duplicated checks.

### Change
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/validator.py` (validate_epic_shard per-story loop, after the required-field presence check ~line 425): added a delegated `validate_story(story, path_base, idx)` call where `path_base = str(story_id) if story_id else epic_id`. Merged its errors back into the result, filtering out its "Missing required field" messages to avoid duplicating the shard loop's own presence check, and preserving severity. 13 insertions, no deletions.

### Why the path-base choice
AC4 requires the offending story's own id to be locatable. `validate_story` builds paths from `{epic_id}.stories[{idx}]`; passing the story's own id as that base yields paths like `94-2.stories[0].status`, so `"94-2" in (e.message + e.path)` holds.

### Test results (targeted only — full suite avoided, it switches branches)
`python3 -m pytest test_epic_shard_validation.py test_sprint_validator.py -q`
→ **100 passed, 2 skipped** (2 skips pre-existing, unrelated). All 4 RED tests in `TestShardStoryValueChecks` now GREEN; all 3 guard tests stay GREEN; no regression in the 50 sprint-validator tests.

### Lint
`ruff check validator.py` → All checks passed. `ruff format` reports one would-reformat block at line ~496 (`_is_epic_shard` return), pre-existing code I did not touch — left as-is per "fix only your changed lines."

### Deviations
See Design Deviations → Dev. Both are within the spec's offered latitude (presence filtering; AC4 fix option a).

### Commit
`d6ee0a038` on `feat/160-1-validate-epic-shard-story-checks`, GPG-signed (Good signature), tree clean. Branch not yet pushed (peloton inline mode).

## Subagent Results

Peloton inline mode: the specialist analyses were performed inline by the reviewer (no background subagents spawned). Each lane's checks were run directly against the diff and verified by command/REPL.

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (inline) | clean | 100 passed / 2 skipped (pre-existing); `ruff check` clean on both changed files; branch unchanged after run | N/A |
| 2 | reviewer-silent-failure-hunter | Yes (inline) | finding (non-blocking) | "Missing required field" filter is a message-prefix string-match (validator.py:436) — verified it cannot swallow any value error since all value-error wordings differ; couples to message text. Deferred [LOW]. | Confirmed, deferred |
| 3 | reviewer-edge-hunter | Yes (inline) | finding (non-blocking) | Non-dict story entry crashes at PRE-EXISTING `story.get("id")` (validator.py:409, also on develop); new isinstance guard sits downstream. Deferred [LOW]. | Confirmed, deferred (pre-existing) |
| 4 | reviewer-test-analyzer | Yes (inline) | clean | 7 tests, no vacuous assertions; enum + numeric-type iteration; AC4 asserts story id locatable; diagnostic failure messages | N/A |
| 5 | reviewer-security | Yes (inline) | clean | Pure local YAML-validation function; no auth, no untrusted-network input, no injection sink, no secrets. `JIRA_KEY_PATTERN` regex is bounded (no catastrophic-backtracking alternation on the jira path). No attack surface introduced. | N/A |

**All received: Yes**

## Reviewer Assessment

**Verdict:** APPROVED

**Spec fidelity — all 4 ACs verified:**
- **AC1 (status enum rejection):** PASS. Shard story with `status: bogus` now fails; every enum member accepted. Verified by `test_shard_story_with_invalid_status_fails` + `..._valid_status_from_enum_passes` and by direct REPL probe (`status: 'bogus'` → `Invalid status 'bogus'`).
- **AC2 (non-numeric points rejection):** PASS. `points: "three"` now fails; int + float (0, 2.5) accepted. Verified by `test_shard_story_with_non_numeric_points_fails` + `..._numeric_points_passes`.
- **AC3 (no regression):** PASS. 100 passed / 2 skipped across `test_epic_shard_validation.py` + `test_sprint_validator.py` (skips pre-existing, unrelated). No double-reporting of "Missing required field".
- **AC4 (error identifies story id + field):** PASS. `path_base = str(story_id)` yields paths like `94-2.stories[0].status`; both AC4 tests assert `"94-2" in (message + path)` and pass. Verified the missing-id fallback to `epic_id` works (REPL).

**Delegation approach — assessed adversarially:**
- **Filter brittleness (string-match on `"Missing required field"`):** Acceptable, not blocking. The filter is a prefix-match on `err.message`, which couples to message wording. BUT the only producer of "Missing required field" messages is the presence check in `validate_story`; all value errors are worded "Invalid status…" / "Invalid points value…" / "Invalid Jira key format…" — none can be swallowed. Verified by enumerating value-error wordings. Minor coupling risk if message text changes; not a correctness defect today.
- **Severity/ordering survives:** Confirmed. `err.severity` is threaded through `result.add_error(...)`. Ordering: presence errors first, then value errors per story — consistent and deterministic.
- **No real error swallowed:** Confirmed via REPL — jira-format, status, and points errors all surface through the delegation; only genuine "Missing required field" duplicates are dropped.
- **Bonus parity:** jira-key format on shard stories is now also validated (was not in the 2 named ACs but matches inline-path parity intent). Good.

**Security [SEC]:** No security impact. This is a pure local YAML-validation function — no authentication path, no untrusted network input, no injection sink, no secret handling. The only regex on the delegated path (`JIRA_KEY_PATTERN`) is bounded and not vulnerable to catastrophic backtracking. The change only adds rejections (tightens validation), it cannot loosen a security control. No attack surface introduced.

**Test quality:** 7 meaningful tests, no vacuous assertions. Guard tests iterate the full enum and multiple numeric types (incl. float 2.5, zero). AC4 tests assert both the bad value AND the story id are locatable. Failure messages are diagnostic.

**Data flow traced:** shard YAML story dict → `validate_epic_shard` per-story loop → `validate_story(story, str(story_id), idx)` → value checks → filtered merge into `result.errors` → `result.valid` flips False on any ERROR-severity entry. Safe.

**Deferred findings (non-blocking — SM to file follow-up):**
| Severity | Finding | Location | Note |
|----------|---------|----------|------|
| [LOW] | Non-dict story entry (bare string / null in `stories`) crashes with `AttributeError` at `story.get("id")` — PRE-EXISTING on `develop`, not introduced by 160-1; new `isinstance` guard sits downstream of the crash | validator.py:408-409 | Guard the loop against non-dict entries |
| [LOW] | "Missing required field" filter couples to message wording (prefix string-match) | validator.py:436 | Could use a structured marker instead of text prefix if wording ever changes |

**Deviation audit:** Both Dev deviations (presence-error filtering; path_base = story's own id, AC4 option a) were within the SM/TEA-offered latitude and are ACCEPTED — net effect matches spec intent, all tests green, no double-reporting.

**Verified by running:**
- `python3 -m pytest test_epic_shard_validation.py test_sprint_validator.py -q` → 100 passed, 2 skipped (branch unchanged; full suite avoided per branch-switch hazard).
- `ruff check validator.py test_epic_shard_validation.py` → All checks passed.
- REPL probes: jira parity, non-dict crash (attributed to develop via `git show develop:`), missing-id fallback, value-error wording enumeration.

**Handoff:** To SM for finish-story.