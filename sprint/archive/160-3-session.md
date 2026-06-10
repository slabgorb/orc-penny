---
story_id: "160-3"
jira_key: "none"
epic: "160"
workflow: "tdd"
---
# Story 160-3: Gate raw-truthy story.get('jira') in story_transition.py:75 + story_finish.py:174 via shared _has_real_jira_key + extract NO_JIRA_SENTINELS constant (from 156-2 review)

## Story Details
- **ID:** 160-3
- **Jira Key:** none
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 2
- **Type:** bug
- **Priority:** p3

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-10T19:51:08Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-10T19:39:49Z | 2026-06-10T19:41:04Z | 1m 15s |
| red | 2026-06-10T19:41:04Z | 2026-06-10T19:45:06Z | 4m 2s |
| green | 2026-06-10T19:45:06Z | 2026-06-10T19:48:00Z | 2m 54s |
| review | 2026-06-10T19:48:00Z | 2026-06-10T19:51:08Z | 3m 8s |
| finish | 2026-06-10T19:51:08Z | - | - |

## Sm Assessment

**Story:** 160-3 — story_transition.py:75 and story_finish.py:174 gate Jira behavior on raw-truthy `story.get('jira')`; sentinel strings like "none"/"skip" are truthy, so explicitly no-Jira stories still hit Jira code paths. From 156-2 review.

**Scope:** Extract a shared `_has_real_jira_key(story)` helper and a `NO_JIRA_SENTINELS` constant in pennyfarthing-dist/src/pf/sprint/ (one truth, one place — 156-2 already established the sentinel-handling pattern somewhere in this package; find it and consolidate rather than invent a parallel one). Replace the raw-truthy gates at both named call sites, and audit the sprint package for any OTHER raw-truthy `story.get('jira')` gates — fix those too if found (report in handoff which were found/fixed).

**Acceptance criteria:**
1. A story with `jira: none` (or any sentinel) does NOT trigger Jira code paths in story transition or story finish.
2. A story with a real Jira key (e.g. PROJ-12345) still triggers Jira paths exactly as before.
3. Sentinel set lives in ONE constant (`NO_JIRA_SENTINELS`); the helper is shared, not duplicated per module.
4. Missing/empty `jira` field behaves as no-Jira (unchanged from current falsy behavior).
5. No regression in existing transition/finish tests.

**Technical approach:** TEA locates the 156-2 sentinel logic and the two call sites, confirms current misbehavior, writes failing tests (sentinel string → no Jira path; real key → Jira path; case sensitivity decision derived from existing code). Dev consolidates. Watch import direction to avoid circular imports between transition/finish modules and wherever the helper lands.

**Routing:** tdd (phased) — TEA (red) → Dev (green) → Reviewer (review). 2 points, repo pennyfarthing, branch `feat/160-3-jira-sentinel-gating` off develop.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

No design deviations

## Tea Handoff

**Phase:** finish → green | **Agent:** tea | **Status:** RED confirmed

### What exists today (audit)

The 156-2 sentinel logic ALREADY exists, but **only** in `story_update.py` and is **private**:
- `pennyfarthing-dist/src/pf/sprint/story_update.py:24` — `_NO_JIRA_SENTINELS = {"", "none", "null", "x"}`
- `pennyfarthing-dist/src/pf/sprint/story_update.py:27` — `_has_real_jira_key(story: dict[str, Any]) -> bool`
  - Semantics: `key = story.get("jira")`; if not a str → `return bool(key)`; else `return key.strip().lower() not in _NO_JIRA_SENTINELS`. **Case-insensitive, whitespace-stripped.**
- Used internally at `story_update.py:160` and `:199` — do NOT regress those.
- **Note:** `"skip"` is NOT a sentinel in the established set (SM brief mentioned it as an example only). Tests pin the real set; do not add "skip".

**Raw-truthy gates (the bug), confirmed empirically:**
- `story_transition.py:75` — `jira_key = story.get("jira")`, gated at `:123` `if jira_key:` → a `jira: none` story calls `get_client()` and reports `jira_key="none"`.
- `story_finish.py:192` — `jira_key = story.get("jira")` (the sprint-YAML fallback) → archives session as `none-session.md`, dry-run emits `Transition none to Done`, leaks `jira_key="none"`.

**Audit of other raw-truthy `story.get("jira")` gates in pf/sprint:** the other hits are **epic** dicts (`epic.get("jira")`), `loader.py` jira==story_id identity matches, `cli.py` display-only echoes, and `archive_epic`/`shard_merge` which `str(... or "")` already. **None of those are story-level Jira-behavior gates** — only the two named call sites mishandle the sentinel-string case. (`story_finish._extract_jira_key` at `:82` already rejects non-`PROJ-\d+` session values; the leak is the YAML fallback at `:192`, not the session path.)

### Designed interface for Dev (AC3 — ONE constant, ONE shared helper)

Consolidate into `pf.sprint.loader` (already imported by transition, finish, and update; has no back-dependency on them → no circular import):

- **`pf.sprint.loader.NO_JIRA_SENTINELS: frozenset[str] = frozenset({"", "none", "null", "x"})`** — public, the single source of truth.
- **`pf.sprint.loader._has_real_jira_key(story: dict[str, Any]) -> bool`** — moved verbatim from story_update; same semantics (non-str → `bool(key)`; str → `key.strip().lower() not in NO_JIRA_SENTINELS`).
- **`story_update.py`** must consume the shared definition (import it; keep `_NO_JIRA_SENTINELS`/`_has_real_jira_key` as aliases pointing at loader's objects if convenient — test asserts the value sets are equal, not the binding name). Remove the duplicated literal set.

**Apply the gates:**
- `story_transition.py`: derive the effective key from `_has_real_jira_key(story)`. When false, `jira_key` reported in the result must be `None` (not `""`/`"none"`) and the `jira_transition` step must be `{"skipped": True}` with `get_client()` never called — same shape the existing no-jira path already produces.
- `story_finish.py`: after the YAML fallback at `:192`, null out `jira_key` when `not _has_real_jira_key(story)` so `archive_name`, the `jira_done` step, and the result's `jira_key` all behave like no-Jira (story-ID archive name, skipped jira step, `jira_key=None`).

### RED evidence

- Test file: `pennyfarthing-dist/src/pf/tests/test_160_3_jira_sentinel_gating.py` (committed `be1a509a7`, GPG-signed, good sig).
- Targeted run (this file): **23 failed, 6 passed**.
  - Failing for the right reasons (the bug + missing shared surface): all `TestSharedSentinelSurface` (4, ImportError/parallel-def), `TestTransitionSkipsSentinelJira` for sentinel **strings** none/None/NONE/x/"  none  " (15), all `TestFinishSkipsSentinelJira` (3), `TestMissingOrEmptyJira::test_transition_empty_string_jira_skips_client` (1 — current code returns `""` not `None`).
  - Passing (already-correct, must STAY green): `jira: null` (YAML→Python `None`, already falsy) ×3, missing-jira ×1, real-key transition + finish (AC2 regression) ×2.
- Existing suites green (no regression): `test_story_transition.py` + `test_story_finish_no_jira.py` + `test_story_update.py` → **93 passed**.
- Did NOT run full pytest (it switches git branches).

### Test names by AC
- AC1 (transition no-Jira): `TestTransitionSkipsSentinelJira::{test_transition_does_not_call_jira_client, test_transition_reports_jira_key_none, test_transition_marks_jira_step_skipped}` (parametrized over sentinel set).
- AC1 (finish no-Jira): `TestFinishSkipsSentinelJira::{test_finish_archives_under_story_id_not_sentinel, test_finish_reports_jira_key_none, test_finish_dry_run_skips_jira_for_sentinel}`.
- AC2 (real key unchanged): `TestRealJiraKeyUnchanged::{test_transition_real_key_calls_jira, test_finish_real_key_unchanged}`.
- AC3 (one constant + shared helper): `TestSharedSentinelSurface::{test_no_jira_sentinels_constant_importable, test_has_real_jira_key_importable, test_story_update_uses_shared_definition, test_helper_semantics_match_156_2}`.
- AC4 (missing/empty as no-Jira): `TestMissingOrEmptyJira::{test_transition_missing_jira_skips_client, test_transition_empty_string_jira_skips_client}`.
- AC5 (no regression): existing suites + AC2 tests above.
## Dev Handoff

**Phase:** finish → review | **Agent:** dev | **Status:** GREEN confirmed

### Approach
Implemented TEA's designed interface verbatim — no deviations. Consolidated the 156-2 sentinel logic into `pf.sprint.loader` (no back-dependency on transition/finish/update → no circular import), then gated both raw-truthy call sites on the shared helper so sentinel strings normalize to `None` and behave exactly like a missing key.

### Changes (file:line)
- `pennyfarthing-dist/src/pf/sprint/loader.py:22` — added public `NO_JIRA_SENTINELS: frozenset[str] = frozenset({"", "none", "null", "x"})` and `_has_real_jira_key(story)` (moved verbatim from story_update; non-str → `bool(key)`, str → `key.strip().lower() not in NO_JIRA_SENTINELS`).
- `pennyfarthing-dist/src/pf/sprint/story_update.py:18` — now imports `NO_JIRA_SENTINELS` + `_has_real_jira_key` from loader; removed the duplicated literal set + local helper; kept `_NO_JIRA_SENTINELS = NO_JIRA_SENTINELS` private alias for back-compat (identity-equal to shared).
- `pennyfarthing-dist/src/pf/sprint/story_transition.py:15,75` — import `_has_real_jira_key`; `jira_key = story.get("jira") if _has_real_jira_key(story) else None`. Existing `if jira_key:` gate at :123 now skips client + emits `{"jira_transition", "skipped": True}` for sentinels; result `jira_key` is `None`.
- `pennyfarthing-dist/src/pf/sprint/story_finish.py:29,191` — import `_has_real_jira_key`; YAML fallback now adopts the key only when `story and _has_real_jira_key(story)`. Because `archive_name` (:206), dry-run step 3 (:231), and the result `jira_key` are all computed from this value, all three behave as no-Jira for sentinels.

### Audit (other raw-truthy `story.get("jira")` gates)
Confirmed TEA's audit — the only two story-level Jira-behavior gates were the named call sites. Other hits (epic dicts, loader identity matches, cli display echoes, archive_epic/shard_merge which already `str(... or "")`) are not story-level gates; left untouched.

### Tests
- `test_160_3_jira_sentinel_gating.py` + `test_story_transition.py` + `test_story_finish_no_jira.py` + `test_story_update.py` → **122 passed** (29 new: 23 previously-RED now green + 6 already-green; 93 existing regression suite). No full pytest run (branch-switch hazard).
- ruff check: all 4 changed files pass. ruff format: my changed lines conform; 2 files show pre-existing format drift on unrelated lines (left untouched per "your lines only").

### Commit
`3cc3d13eb` — `fix(sprint): gate sentinel jira values in transition and finish` — GPG-signed (good sig, Keith Avery).

### Open questions
None.

## Subagent Results

(Peloton inline mode — reviewer performed these specialist checks directly rather than spawning background subagents.)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (inline) | clean | 122 targeted tests pass; ruff check clean on all 4 changed files; working trees clean | N/A |
| 2 | reviewer-security | Yes (inline) | clean | no security surface — pure data-classification logic; no user-input injection path; sentinel set is a closed literal frozenset | N/A |

**All received: Yes** (2/2; inline-mode direct checks. Consolidation/audit/edge findings folded into the Reviewer Assessment below.)

## Reviewer Assessment

**Verdict:** APPROVED

**Spec fidelity (5 ACs) — all verified:**
- **AC1 (sentinel → no Jira):** `story_transition.py:77` `jira_key = story.get("jira") if _has_real_jira_key(story) else None` and `story_finish.py:194` `if story and _has_real_jira_key(story):` both gate on the shared helper. Downstream in finish: `archive_name`/`dialogue_archive_name` (:209/:213), dry-run step 3 (:234-237), and real step 3 `jira_done`/`skipped` (:356-359) all branch on `if jira_key:`, so a nulled key routes to the no-Jira path (story-ID archive name, skipped jira step, `jira_key=None` in result).
- **AC2 (real key unchanged):** `_has_real_jira_key({'jira':'PROJ-12345'})` → True (verified at runtime); transition_story / jira_done run exactly as before.
- **AC3 (ONE constant, shared helper):** runtime check `story_update._NO_JIRA_SENTINELS is loader.NO_JIRA_SENTINELS` → **True** (identity-equal, not just value-equal). story_update imports both symbols from loader and deleted its local literal/helper. Zero drift possible.
- **AC4 (missing/empty = no-Jira):** `''`→False, missing→False, `None`→False (verified).
- **AC5 (no regression):** 122 passed across the 4 targeted suites.

**Consolidation correctness:** loader is the correct home — already imported by transition/finish/update with no back-dependency on them; `python -c "from pf.sprint.loader import ..."` plus importing story_update succeeded → **no circular import**. Helper moved verbatim from 156-2; semantics confirmed identical at runtime: case-insensitive (`NONE`→False), whitespace-stripped (`'  none  '`→False), non-str → `bool(key)` (`123`→True, `None`→False). `"skip"` correctly NOT added to the set.

**story_finish nulling — downstream trace (review concern #3):** PR-merge steps (dry-run :226-233; live :258-328) key **exclusively on `pr_number`**, never `jira_key`. The loud merge-abort guards (gh #71/#60) return `jira_key` only as a passive result field. Nulling the sentinel key has **zero effect on any merge or branch-delete behavior**. Only archive name / jira_done step / result `jira_key` are affected — exactly as designed.

**TEA audit spot-check (review concern #4):** I re-ran the grep myself over `pf/sprint/`. Only mutable story-level concern was `story_update.py:188` (`jira_key = story.get("jira")` is raw) — but it is consumed solely inside `if update_jira and _has_real_jira_key(story):` (:190), so the gate already guards it (no leak). All other hits are epic dicts, loader `== story_id` identity matches, cli display echoes, or `str(... or "")` archive refs — none are story-level Jira-behavior gates. **TEA's audit holds.**

**Data flow traced:** `jira: none` (sprint YAML) → `story.get("jira")` → `_has_real_jira_key` → `None` → no `get_client()`, `jira_transition: skipped`, archive under `160-3-session.md`, result `jira_key=None`. Safe.

**Quality gates:** ruff check on all 4 changed files → All checks passed. 122 targeted tests pass (no full pytest run — branch-switch hazard honored).

**Deviation audit:** session declares "No design deviations" / "No upstream findings" — confirmed; Dev implemented TEA's interface verbatim. Nothing to flag.

**Observations:**
1. Comment-doc accuracy: loader docstring/comment correctly reference gh #12 and story 160-3 — no stale comments. (verified good)
2. `_has_real_jira_key` is exported with a leading underscore yet imported cross-module — mild API-surface smell (private name used as package-internal shared symbol), but intentional and consistent with TEA's interface. Non-blocking.
3. `story_update._NO_JIRA_SENTINELS = NO_JIRA_SENTINELS` back-compat alias is dead within the module (only the helper is used) but harmless and documented. (verified good)
4. Error handling: finish's YAML-fallback `try/except Exception: pass` (:196) is pre-existing and unchanged; the sentinel gate sits inside it correctly. (verified good)
5. [SEC] No security surface — pure data-classification logic over a closed literal `frozenset`, no user-input injection path, no auth/credential handling. Clean.

**Deferred findings (non-blocking, SM may file follow-ups):**
| Severity | Finding | Location |
|----------|---------|----------|
| [LOW] | `_has_real_jira_key` is a leading-underscore name imported across 3 modules; consider promoting to a public name (`has_real_jira_key`) to match its actual package-internal-shared role. | `loader.py:27` |
| [LOW] | `_NO_JIRA_SENTINELS` alias in story_update is unused dead code (only the helper is referenced); could be removed in a later cleanup. | `story_update.py:30` |

**Handoff:** To SM for finish-story.