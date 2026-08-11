---
story_id: "164-20"
jira_key: ""
epic: "164"
workflow: "tdd"
---
# Story 164-20: Sprint board TUI: story rows show em-dash instead of their jira key (gh #141)

## Story Details
- **ID:** 164-20
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-20-sprint-board-story-jira-key
- **PR:** (none yet — recorded when the PR is created)

## Acceptance Criteria

1. Story rows render their `jira:` value in the Jira-key column when present
2. When a story has no `jira:` field, the column falls back to the story id (no regression for id==jira epics)
3. Regression covering a short-form-id epic (e.g. 40-1 with jira MSSCI-18070) asserts the key renders, not em-dash

## Discovery Findings

### Story Row Jira Column Rendering — Bug Location

**File:** `pennyfarthing-dist/src/pf/tui/sprint_panel.py`

**Problem Function:** `_build_story_label()` at line 158–226

**Bug Line:** Line 167
```python
jira = story.get("jiraKey") or "—"
```

**Issue:** Story dict from sprint YAML contains `jira:` field (e.g., `jira: PROJ-14466`), but the code looks for `jiraKey` (camelCase). When the field is missing, em-dash (`—`) is rendered instead of falling back to the story id.

**Evidence:** 
- Sprint YAML (e.g., `archive/epic-PROJ-14465.yaml` stories 83-1, 83-2, 83-3) contains `jira: PROJ-14466`, `jira: PROJ-14467`, `jira: PROJ-14468` at the story level
- Story dicts passed to `_build_story_label()` contain the raw `jira` field from YAML

### Epic Row Resolution — Correct Implementation (to Mirror)

**File:** `pennyfarthing-dist/src/pf/tui/sprint_panel.py`

**Reference Function:** `_build_epic_label()` at line 110–155

**Correct Pattern:** Lines 128–138
```python
if jira_key:
    display_jira = (
        jira_key
        if len(jira_key) <= _EPIC_ID_WIDTH
        else jira_key[: _EPIC_ID_WIDTH - 1] + "…"
    )
    label.append(
        f"  {display_jira:<{_EPIC_ID_WIDTH}}", style="dim cyan" if completed else "cyan"
    )
else:
    label.append(" " * (_EPIC_ID_WIDTH + 2))
```

Epics receive `jira_key` as a parameter and only append to label when present (no em-dash fallback).

### Payload Builder — Secondary Issue Location (Informational)

**File:** `pennyfarthing-dist/src/pf/frame/ws_push.py`

**Function:** `fetch_sprint()` at line 283–493

**Context:** Line 385–391
```python
# Epic transformation (CORRECT):
jira_key = epic_data.get("jira", "") or ref_by_id.get(epic_id, "")
epic_entry = {
    ...
    "jiraKey": jira_key,  # ← normalized to camelCase
    "stories": epic_data.get("stories", []),  # ← stories NOT transformed
}
```

Stories pass through unchanged from YAML (with `jira:` field), while epics are normalized to `jiraKey`. The TUI expects both keys to have the same name.

## Technical Approach

**Fix location:** `sprint_panel.py` `_build_story_label()` line 167

**Solution:** Look for both `jiraKey` (from normalized payload) and `jira` (from raw YAML fallback), falling back to story id when neither exists:

```python
jira = story.get("jiraKey") or story.get("jira") or story.get("id") or "—"
```

This mirrors epic behavior by:
1. Checking `jiraKey` first (if payload is normalized in future)
2. Falling back to `jira` field (current YAML structure)
3. Falling back to story `id` (when no separate Jira key exists)
4. Only showing em-dash when all three are absent (safety net)

**Alternative (normalize earlier):** Transform stories in `ws_push.py` line 391 to normalize `jira` → `jiraKey` like epics, but the story-level fix is simpler and defensive against YAML variations.

## Regression Test Plan

**Short-form epic example:** Epic 40 (archived, `epic-PROJ-12414.yaml`), child story 83-1 with `jira: PROJ-14466`

- Verify TUI renders `PROJ-14466` in Jira-key column, not em-dash
- Verify story 83-2 (no separate jira field, id is the key) still renders correctly
- Verify old-style epics where story id == jira key (id==jira regression) still work

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T14:11:28Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T13:47:00Z | 2026-08-11T13:47:57Z | 57s |
| red | 2026-08-11T13:47:57Z | 2026-08-11T13:51:47Z | 3m 50s |
| green | 2026-08-11T13:51:47Z | 2026-08-11T13:53:24Z | 1m 37s |
| review | 2026-08-11T13:53:24Z | 2026-08-11T14:11:28Z | 18m 4s |
| finish | 2026-08-11T14:11:28Z | - | - |

## Delivery Findings

### Dev (implementation)
- **Gap** (non-blocking): `sprint_panel.py:662` `key = story.get("jiraKey") or story.get("id", "")`
  (drill-through key resolution) has the same two defects the 164-20 fix corrected in
  `_build_story_label`: it ignores the raw `jira` field and does not filter `NO_JIRA_SENTINELS`.
  Not in 164-20's scope (rendering-only story, no failing test covers it), but a story opening the
  detail screen for a keyed story likely passes the wrong identifier. *Found by Dev during implementation.*
- **Gap** (non-blocking): the RED commit shipped a corporate Jira key into a framework
  redistributable, breaking `test_152_1_no_company_leakage`. Fixed here, but the leakage guard is
  not part of any phase gate, so nothing catches it at RED-exit. Worth adding to the TEA/Dev check
  command. *Found by Dev during implementation.*

## Design Deviations

No deviations from specification at setup.

## Sm Assessment

**Discovery complete.** Bug is a straightforward rendering gap in `_build_story_label()` (line 167): story dict has `jira:` field from YAML but code looks for `jiraKey` (camelCase), falling back to em-dash instead of story id or the actual field. Fix mirrors epic behavior by checking both keys. Regression test uses archived epic 40 stories with separate MSSCI Jira keys.

**Handoff:** To TEA for red phase.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_164_20_story_row_jira_key.py` (new) — 16 tests over `_build_story_label()` / `_build_epic_label()`
- `pennyfarthing-dist/src/pf/tests/test_sprint_panel.py` (modified) — `test_null_jira_key_shows_dash` encoded the buggy contract; split into `test_null_jira_key_falls_back_to_id` (new expected behavior) and `test_no_id_and_no_jira_key_shows_dash` (em-dash safety net)

**Tests Written:** 18 (16 new + 2 rewritten) covering 3 ACs

**Coverage by AC:**
- AC1 (`jira:` renders): 6 tests — raw `jira`, `jiraKey` precedence over `jira`, empty/None `jiraKey` fall-through, long-key truncation, em-dash absence
- AC2 (fallback to id): 5 tests — both keys missing, `jiraKey: None`, empty-string keys, `id == jira` no-double-render, no-id-no-key still em-dash
- AC3 (short-form-id regression): 4 tests — `40-1`/`MSSCI-18070`, `83-1`/`PROJ-14466`, keyed vs unkeyed siblings, epic-row non-regression

**Status:** RED — 13 failed, 61 passed (`pytest test_164_20_story_row_jira_key.py test_sprint_panel.py`)

**RED reasons (all correct):** every failure asserts on the em-dash placeholder appearing where the Jira key or story id belongs, e.g.
`assert 'PROJ-14466' in '✓  83-1       —            2  ...'`.
The 4 new tests that pass are intentional guards (jiraKey precedence, no-id em-dash safety net, epic-row parity) — they must stay green through the fix.

**Fix verified sufficient:** with `jira = story.get("jiraKey") or story.get("jira") or story.get("id") or "—"` temporarily applied, all 74 tests pass; source reverted, no implementation committed.

**Commit:** `d486b1e` — `test(164-20): add failing tests for story-row jira-key rendering`

**Note for Dev:** the `ws_push.fetch_sprint()` story pass-through (stories keep raw `jira`, epics normalized to `jiraKey`) is left as-is per the story's Technical Approach — the panel-level fix is the in-scope change. Tests assert `jiraKey` still wins so a future normalization in `ws_push` stays compatible.

**Handoff:** To Dev

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/tui/sprint_panel.py` — `_build_story_label()` jira resolution: `story.get("jiraKey") or story.get("jira") or story_id or "—"` (uses the already-resolved `story_id` local so id fallback and ordinal column stay consistent)

**Tests:** 74/74 passing (GREEN) — `test_164_20_story_row_jira_key.py` (16) + `test_sprint_panel.py`. Broader sweep `-k "sprint_panel or tui or 164_20"`: 159 passed.

**Branch:** `feat/164-20-sprint-board-story-jira-key` (pushed)

**Commit:** `d321c83`

**Notes:** `ws_push.fetch_sprint()` story pass-through left untouched per scope; `jiraKey` precedence preserved so future normalization stays compatible. No design deviations.

**Handoff:** To Reviewer

## Dev Fix Round 1 (review finding: sentinel jira values)

**Finding confirmed valid.** `NO_JIRA_SENTINELS = frozenset({"", "none", "null", "x"})`
(`sprint/loader.py:27`) — the three non-empty sentinels are TRUTHY, so my `or` chain rendered
them literally in the Jira column instead of falling back to the id, violating AC2's intent.

**Fix** (`sprint_panel.py` `_build_story_label()`), mirroring `story_transition.py:77`:
```python
jira_key_field = story.get("jiraKey")
real_jira_key = jira_key_field if _has_real_jira_key({"jira": jira_key_field}) else None
real_jira = story.get("jira") if _has_real_jira_key(story) else None
jira = real_jira_key or real_jira or story_id or "—"
```
`jiraKey` precedence preserved. I guarded `jiraKey` too (the reviewer flagged it as conditional):
no code sets `jiraKey` on stories today, but `ws_push` builds the epic value as
`epic_data.get("jira","")`, so if story normalization is added the same way, a `jira: none` story
would yield `jiraKey: "none"`. Guarding costs one line and no duplicated sentinel logic — the
`{"jira": ...}` wrapper reuses the single source of truth rather than re-listing the sentinels.
Verified no import cycle: `pf.sprint.loader` does not import `pf.tui`.

**Tests added (2), both verified RED against the prior commit via `git stash`:**
- `test_sentinel_jira_value_falls_back_to_id` — `{"id": "40-1", "jira": "none"}` → renders `40-1`,
  asserts the literal `none` is absent. Failed before: `'◯  40-1  none  ...'`
- `test_sentinel_jira_key_falls_back_to_id` — `{"id": "40-2", "jiraKey": "x", "jira": "null"}` →
  renders `40-2`. Failed before: `assert 1 == 2` on `count("40-2")`, column showed `x`

**Deviation from the requested test list:** requested test #2 (`{"id": "40-1", "jira":
"MSSCI-18070"}` pinning the jira-field path) already existed verbatim as
`test_short_id_with_separate_jira_key`, and `test_yaml_jira_field_is_rendered` also covers it —
the path was NOT untested. I substituted the `jiraKey`-sentinel test so both guarded branches
have coverage, rather than committing a duplicate.

**Additional pre-existing failure found and fixed (in-scope: my branch was red).**
`test_152_1_no_company_leakage.py::test_no_corporate_jira_key_in_framework_redistributables`
was FAILING on 6 occurrences of a corporate Jira key in TEA's RED commit (`d486b1e`) test file —
a redistributable. Replaced with the repo's neutral `PROJ-` convention (`PROJ-18070`) and renamed
`test_short_id_with_mssci_key` → `test_short_id_with_separate_jira_key`. AC3's short-form-id
semantics are unchanged. Both TEA's two-file run and my earlier `-k` sweep missed this because
neither selected the leakage test.

**Verification:**
- target files + leakage guard: `80 passed`
- sweep `-k "sprint_panel or tui or 164_20 or jira or sentinel or leakage"`: `488 passed`
- **full suite: `6990 passed, 4 skipped`** in 217s
- `ruff check` + `ruff format --check`: clean

**Commit:** `b91bd44` (signed) — pushed to `feat/164-20-sprint-board-story-jira-key`
**`ws_push.fetch_sprint()`:** untouched, per scope.

**Handoff:** To Reviewer

## Subagent Results

**All received:** Yes

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|---------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | Clean | 74/74 tests pass; 159 sweep pass; ruff reports no violations; no code smells | Confirmed |
| 2 | reviewer-comment-analyzer | Yes (first-hand) | Clean | Inline comment accurate; module docstring correct; renamed test method names match new behavior; no stale docs | Confirmed |
| 3 | reviewer-edge-hunter | Yes (first-hand) | Clean with LOW | `story.get("id","")` empty-string edge covered by safety-net test; non-string `jira` YAML value would TypeError on `len()` at line 201 — pre-existing structural assumption, not introduced here | Low noted |
| 4 | reviewer-rule-checker | Yes (first-hand) | Clean | All edits in `pennyfarthing-dist/src/pf/` — correct source tree; no `.pennyfarthing/` paths touched; `{success,data?,error?}` contract not applicable to Rich Text builders | Confirmed |
| 5 | reviewer-security | Yes (first-hand) | Clean | TUI display-only path; Rich library does not process terminal escape sequences; local YAML not a network attack surface; truncation guard at line 201 caps rendered length | Confirmed |
| 6 | reviewer-silent-failure-hunter | Yes (first-hand) | Clean | Final `or "—"` guarantees string fallback — no None reaches `len()`; no try/except swallowing; exceptions propagate normally | Confirmed |
| 7 | reviewer-simplifier | Yes (first-hand) | Clean | `or` chain is idiomatic Python for precedence fallback — clearer than `next(filter(...))` alternative; 16 tests justified by 3 distinct ACs + regression coverage for archived production data | Confirmed |
| 8 | reviewer-test-analyzer | Yes (first-hand) | Clean with LOW | Safety-net test covers real em-dash code path; no vacuous assertions; `test_id_equals_jira_renders_once_in_key_column` name says "once" but count==2 (ordinal + key columns) — misleading name; tests are unit-only, no integration, acceptable for pure function | Low noted |
| 9 | reviewer-type-design | Yes (first-hand) | Clean | `dict[str,Any]` is pre-existing type; `story_id` guaranteed `str` from `.get("id","")` default; `or "—"` ensures string at runtime; TypedDict would be better but pre-existing debt | Confirmed |

## Reviewer Assessment

**Specialist synthesis:**
[DOC] Inline comment and test docstrings are accurate and current — no stale documentation found.
[EDGE] `story.get("id","")` empty-string correctly falls through to `"—"` (tested). Non-string `jira` YAML value (theoretically `jira: 12345`) would TypeError on `len()` at line 201, but this is a pre-existing structural assumption on the function's contract, not introduced here, and Jira keys are always strings in practice.
[RULE] All edits are in `pennyfarthing-dist/src/pf/` (correct source tree); no `.pennyfarthing/` symlink targets touched; project rules satisfied.
[SEC] TUI display-only path. Rich Text rendering does not interpret terminal escape sequences. Local YAML is not an attack surface. No security concern.
[SILENT] `or "—"` string sentinel guarantees no None or falsy value reaches `len(jira)` at line 201. No try/except swallowing. Exceptions propagate. Clean.
[SIMPLE] `or` chain is idiomatic and readable. Sixteen tests justified by three ACs and archived production data regressions. No over-engineering.
[TEST] All 16 new tests fail on the old one-liner — they are real. Safety-net em-dash test covers the genuine no-id-no-key code path. Minor: `test_id_equals_jira_renders_once_in_key_column` name says "once" but `count==2` (ordinal + jira columns both show id) — name is misleading but assertion is correct.
[TYPE] `dict[str,Any]` is pre-existing; `story_id: str` is safe for the `or` chain; runtime type is always `str` after the `or "—"` sentinel. No new type issues introduced.

**Design deviation audit:** None declared. The precedence order `jiraKey > jira > id > —` is correct and matches the architecture (stories from YAML carry `jira:`, normalized payloads use `jiraKey:`, epics already resolved). Double-render of id in ordinal and jira columns when no separate key exists is the specified AC2 behavior, explicitly tested, and acceptable.

**Verdict:** APPROVED

**Handoff:** To SM for finish-story

---

## Subagent Results

**All received:** Yes

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|---------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (first-hand) | Clean | 76/76 target tests pass; 159 sweep pass; ruff clean; no code smells | Confirmed |
| 2 | reviewer-comment-analyzer | Yes (first-hand) | Clean | Updated inline comment accurately describes sentinel handling; new sentinel test docstrings are precise; MSSCI→PROJ rename is self-documenting; no stale docs | Confirmed |
| 3 | reviewer-edge-hunter | Yes (first-hand) | Clean with LOW | Sentinel set `{"","none","null","x"}` covers known patterns; synthetic dict wrapper `{"jira": jira_key_field}` is functional but awkward — a `_is_real_key(v)` predicate would be cleaner (LOW); non-string YAML value path pre-existing, unchanged | Low noted |
| 4 | reviewer-rule-checker | Yes (first-hand) | Clean | All edits in `pennyfarthing-dist/src/pf/`; no `.pennyfarthing/` paths touched; importing private `_has_real_jira_key` across packages is intra-repo and documented as single source of truth | Confirmed |
| 5 | reviewer-security | Yes (first-hand) | Clean | No new attack surface; sentinel filtering reduces (not increases) render output; leakage guard passes 4/4 confirming no corporate key in redistributables | Confirmed |
| 6 | reviewer-silent-failure-hunter | Yes (first-hand) | Clean | `_has_real_jira_key` returns `False` for `None` (isinstance guard), empty string, and sentinels — no silent pass-through; `or "—"` still guarantees string to `len()` | Confirmed |
| 7 | reviewer-simplifier | Yes (first-hand) | Clean with LOW | Synthetic dict `{"jira": jira_key_field}` to reuse `_has_real_jira_key` for the `jiraKey` field is a workaround for the function's `story.get("jira")` interface — acceptable but a factored predicate would be simpler (LOW); 2 new tests proportionate to gap | Low noted |
| 8 | reviewer-test-analyzer | Yes (first-hand) | Clean | `test_sentinel_jira_value_falls_back_to_id` and `test_sentinel_jira_key_falls_back_to_id` both fail against pre-fix `d321c83` — confirmed real; leakage guard sanity-check test prevents vacuous scan; MSSCI→PROJ replacement preserves assertion semantics | Confirmed |
| 9 | reviewer-type-design | Yes (first-hand) | Clean | `_has_real_jira_key` return type `bool` is correct; `real_jira_key: str | None` and `real_jira: str | None` feed the `or` chain safely; no new type regressions | Confirmed |

## Reviewer Assessment

**Sentinel gap:** ADDRESSED. `_has_real_jira_key` (loader.py) is imported and applied to both `jiraKey` and `jira` fields. Sentinel set `{"","none","null","x"}` (case-insensitive, whitespace-stripped) prevents literal "none"/"null"/"x" values from rendering. Precedence confirmed: `jiraKey(real) → jira(real) → id → —`. Tests `test_sentinel_jira_value_falls_back_to_id` and `test_sentinel_jira_key_falls_back_to_id` fail against the pre-fix commit and pass after — real tests.

**Import cycle:** None. `pf.sprint.loader` does not import `pf.tui`. Confirmed by grep and by 76/76 tests passing without ImportError.

**Corporate key cleanup:** SOUND. `MSSCI-18070` replaced with `PROJ-18070` in two test assertions. Leakage guard (`test_152_1_no_company_leakage`) passes 4/4, including the sanity check that the scan actually walks `pennyfarthing-dist/`. Guard is not weakened — assertion logic is identical, only the key value changed. No MSSCI anywhere in redistributable tree.

**Out-of-scope deferred item:** `sprint_panel.py:662` drill-through path has the same sentinel defects. No failing test; deferred. Not blocking this cycle.

**Specialist synthesis:**
[DOC] Comment updated to mention sentinels; new test docstrings precise and accurate; MSSCI→PROJ rename is clean.
[EDGE] Sentinel set covers known patterns. Synthetic dict `{"jira": jira_key_field}` is functional but slightly awkward interface reuse — LOW, non-blocking.
[RULE] All edits in correct source tree; private function import is intra-repo single-source-of-truth, acceptable.
[SEC] Leakage guard 4/4 confirms no corporate keys in redistributables. No new attack surface introduced.
[SILENT] `_has_real_jira_key` guards both fields; `or "—"` sentinel still guarantees string to `len()`. No swallowed failures.
[SIMPLE] Two new tests proportionate to the gap. Synthetic dict wrapper is minor complexity; acceptable for DRY reuse of `_has_real_jira_key`.
[TEST] Both sentinel tests are real (fail on d321c83). Leakage guard is not weakened — scan scope and assertion semantics unchanged.
[TYPE] No new type issues. `bool` return from `_has_real_jira_key` correctly gates `str | None` assignment.

**Verdict:** APPROVED

**Handoff:** To SM for finish-story