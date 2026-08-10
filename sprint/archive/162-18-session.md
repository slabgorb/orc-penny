---
story_id: "162-18"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-18: Add mergedAt corroboration to the MERGED bypass in story_finish

## Story Details
- **ID:** 162-18
- **Jira Key:** (Jira disabled for this epic)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-18-mergedat-corroboration
- **PR:** #198

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T14:20:27Z
**Round-Trip Count:** 2

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T13:10:49Z | 2026-08-10T13:12:01Z | 1m 12s |
| red | 2026-08-10T13:12:01Z | 2026-08-10T13:20:47Z | 8m 46s |
| green | 2026-08-10T13:20:47Z | 2026-08-10T13:32:11Z | 11m 24s |
| review | 2026-08-10T13:32:11Z | 2026-08-10T13:48:04Z | 15m 53s |
| green | 2026-08-10T13:48:04Z | 2026-08-10T13:56:12Z | 8m 8s |
| review | 2026-08-10T13:56:12Z | 2026-08-10T14:05:13Z | 9m 1s |
| green | 2026-08-10T14:05:13Z | 2026-08-10T14:09:55Z | 4m 42s |
| review | 2026-08-10T14:09:55Z | 2026-08-10T14:20:27Z | 10m 32s |
| finish | 2026-08-10T14:20:27Z | - | - |

## Spec: Acceptance Criteria

**AC1:** Fix the test fixture that derives mergedAt via case-fold (test_162_3 file, line ~208) — inert now, becomes a false-pass generator once mergedAt corroboration lands (162-3 review R3).

**AC2:** Add a whitespace-padded MERGED spelling to the 162-3 parametrize lists — a `.strip()` mutant currently passes all 49 (162-3 review R1); also add a lowercase input pair to `TestConflictGateStillBlocksCanonicalMergeability`, currently decorative (both blocking-side folds removable with zero failures — 162-3 review R2, mutation-confirmed).

**Core change:** The MERGED bypass in `story_finish` currently trusts a single `state` snapshot field to gate the conflict-gate exemption, the merge short-circuit, and post-merge re-verify. Add `mergedAt` to `_PR_VIEW_FIELDS` and require `mergedAt` to corroborate a MERGED state before those paths trust it (state==MERGED AND mergedAt present/non-null).

## Source Files & Line Hints

**Primary implementation:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_PR_VIEW_FIELDS` (add mergedAt), MERGED-bypass logic, conflict-gate exemption, merge short-circuit, post-merge re-verify (~line 320-380 region for bypass logic)

**Tests:**
- `pennyfarthing-dist/src/pf/tests/test_162_3*.py` — test fixture (line ~208), parametrize lists, `TestConflictGateStillBlocksCanonicalMergeability`
- `pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py` — related finish tests

## SM Assessment

**Routing:** 1 pt, workflow `tdd` (phased) → full pipeline SM→TEA→Dev→Reviewer (explicit `tdd` tag overrides the 1-2pt trivial fallback; the story hardens the finish-truthfulness machinery so the review phase earns its keep). Peloton-inline (SM lead; SM owns PR + merge + finish).

**Spec:** Title + AC1 + AC2 above are the spec. Core: the MERGED bypass in `story_finish` trusts a lone `state` snapshot to gate three paths (conflict-gate exemption, merge short-circuit, post-merge re-verify). Add `mergedAt` to `_PR_VIEW_FIELDS` and require corroboration (state==MERGED AND non-null `mergedAt`) before any of those paths trust MERGED.

**For TEA:** RED must (a) pin that a state==MERGED-with-null-mergedAt snapshot is NOT trusted by each of the three bypass paths (the corroboration gap), and (b) implement AC1/AC2 test hardening — fix the case-fold fixture (~test_162_3:208) that would become a false-pass generator, add the whitespace-padded MERGED parametrize entry that kills the `.strip()` mutant, and add the lowercase pair to `TestConflictGateStillBlocksCanonicalMergeability`. This story is largely test-integrity work — the mutation-confirmed weak spots (R1/R2/R3) are the target.

**Constraints:** TDD (failing test first). Scoped runs only (`uv run pytest src/pf/tests/test_162_3*.py -q` etc. from `pennyfarthing-dist/`) — NEVER the full suite. `ruff check` changed files. Result objects, don't throw.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_18_mergedat_corroboration.py` — 19 tests; 9 true-RED core corroboration tests + 10 green-on-arrival controls
- `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py` — AC1/AC2 hardenings (all 67 tests green)

**Root cause confirmed:** `_view_is_merged` (line ~463) checks only `view.get("state") == "MERGED"`. `mergedAt` is absent from `_PR_VIEW_FIELDS` (line 379). The three bypass paths — conflict-gate exemption (`_pr_block_reason` line 522), already-merged short-circuit (line 1326), and post-merge re-verify (`_pr_merge_verification` lines 493-494) — all flow through this predicate and trust state alone.

**True-RED tests** (fail against current code, for the right reason — no corroboration check):
- `test_pr_view_fields_includes_mergedat` — `_PR_VIEW_FIELDS` lacks `mergedAt`
- `TestViewIsMergedRequiresMergedAt::test_merged_state_without_mergedat_is_not_merged[explicit-null]`
- `TestViewIsMergedRequiresMergedAt::test_merged_state_without_mergedat_is_not_merged[key-absent]`
- `TestConflictGateExemptionRequiresMergedAt::test_merged_state_without_mergedat_does_not_exempt_conflict_block[explicit-null]`
- `TestConflictGateExemptionRequiresMergedAt::test_merged_state_without_mergedat_does_not_exempt_conflict_block[key-absent]`
- `TestShortCircuitRequiresMergedAt::test_merged_state_without_mergedat_still_attempts_merge`
- `TestPostMergeVerificationRequiresMergedAt::test_merged_state_without_mergedat_fails_verification[null-mergedat]`
- `TestPostMergeVerificationRequiresMergedAt::test_merged_state_without_mergedat_fails_verification[absent-mergedat]`
- `TestPostMergeVerificationRequiresMergedAt::test_merge_that_reports_merged_without_mergedat_aborts_finish`

**Hardening (AC2 — green-on-arrival, all PASS):**
- AC1/R3: `_view_payload` fixture case-fold fixed (`state.upper() == "MERGED"` → `state == "MERGED"`)
- AC2/R1: `" MERGED"` and `"MERGED "` added to `NON_CANONICAL_MERGED` — all parametrized 162-3 tests pass (67 total)
- AC2/R2: `pytest.param("conflicting", "dirty", ...)` and `pytest.param("conflicting", "unknown", ...)` added to `TestConflictGateStillBlocksCanonicalMergeability` — pass (current code case-folds)

**Run output:**
```
uv run pytest src/pf/tests/test_162_18_mergedat_corroboration.py src/pf/tests/test_162_3_view_is_merged_strict_state.py -q
9 failed, 77 passed
```
(9 true-RED, 77 green — exact expected state)

**Dev interface:**
1. Add `mergedAt` to `_PR_VIEW_FIELDS` (line 379): `"state,mergeable,mergeStateStatus,baseRefName,mergedAt"`
2. In `_view_is_merged` (line ~463): require `view.get("state") == "MERGED" and bool(view.get("mergedAt"))` — do NOT change `_pr_block_reason`'s `.upper()` on `mergeable`/`mergeStateStatus` (out of scope, opposite risk profile)

**Tests Written:** 19 tests (9 RED, 10 green) covering the CORE AC; 9 hardening edits in test_162_3 (all green)
**Status:** RED (9 failing — ready for Dev)

**Handoff:** To Dev for implementation

## Delivery Findings

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)
- **Gap** (non-blocking): AC1 was under-specified for a corroboration world. It prescribed changing the 162-3 `_view_payload` derivation from `state.upper() == "MERGED"` to `state == "MERGED"` — which removes the false-pass generator but replaces it with a false-*negative* generator: once the predicate requires timestamp corroboration, every non-canonical state in that fixture yields a null timestamp, so the state comparison stops being the thing under test. The correct shape is the one TEA used in its own 162-18 helper: make the timestamp an explicit parameter independent of `state`. Affects `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py` (fixture + `NON_CANONICAL_MERGED` call sites). Future stories that add a second conjunct to a predicate must re-check that the existing single-conjunct suite still varies only the conjunct it names. *Found by Reviewer during code review.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_PR_VIEW_FIELDS`: added `mergedAt` field. `_view_is_merged`: added `and bool(view.get("mergedAt"))` corroboration.
- `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py` — 3 inline canonical MERGED fixtures updated to include `mergedAt` (matching TEA's parametrized fixture at line 212 which already had it).
- `pennyfarthing-dist/src/pf/tests/test_155_15_finish_blocked_merge_no_stray_archive.py` — `_make_fake_run` view dict: added `mergedAt` conditional on current state.
- `pennyfarthing-dist/src/pf/tests/test_162_1_finish_merged_before_conflict_gate.py` — stateful `_stateful` fake view dict: added `mergedAt` conditional on `state["merged"]`.
- `pennyfarthing-dist/src/pf/tests/test_162_6_finish_repo_context.py` — `_make_run` view dict: added `mergedAt` conditional on current live state.
- `pennyfarthing-dist/src/pf/tests/test_162_9_finish_subprocess_timeouts.py` — `fake_run` view dict: added `mergedAt` conditional on `live["state"]`.
- `pennyfarthing-dist/src/pf/tests/test_demo_finish_hook.py` — 10 inline `'{"state": "MERGED"}'` stubs: added `mergedAt`.
- `pennyfarthing-dist/src/pf/tests/test_story_finish_no_jira.py` — 1 inline MERGED stub: added `mergedAt`.
- `pennyfarthing-dist/src/pf/tests/test_160_3_jira_sentinel_gating.py` — 1 inline MERGED stub: added `mergedAt`.

**The exact production change:**
1. `_PR_VIEW_FIELDS` (line 379): `"state,mergeable,mergeStateStatus,baseRefName,mergedAt"`
2. `_view_is_merged` (line 463): `return view.get("state") == "MERGED" and bool(view.get("mergedAt"))`

All three bypass paths route through `_view_is_merged`. No inline `state == "MERGED"` checks outside the helper needed updating.

**Test fixture scope note:** TEA's probed interface was correct, but the regression suite's `gh pr view` fakes (across 8 test files) returned `{"state": "MERGED"}` without `mergedAt`. These were updated to include `mergedAt` when state is MERGED — reflecting real GitHub output. TEA had already done this correctly for the 162-3 parametrized fixture (line 212) and the 162-1 `_make_run` helper; the rest were missed.

**Scoped tests:** 86/86 passing (9 newly-green + 77 controls)
**Regression batch:** 517/517 passing (`-k "finish or merge or 155_1"`)
**ruff:** All checks passed
**Branch:** `feat/162-18-mergedat-corroboration` (pushed)

**Handoff:** To Reviewer

## Dev Assessment (Rework — Round-Trip 1)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_PR_VIEW_FIELDS` block comment extended to name `mergedAt` and its role. `_view_is_merged` docstring extended with corroboration rationale. Predicate tightened to bind `merged_at` and require `isinstance(merged_at, str) and bool(merged_at)`.
- `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py` — `_view_payload`: `mergedat` is now an explicit param (default `"2026-08-04T00:00:00Z"`) independent of `state`. All `NON_CANONICAL_MERGED`/`ALREADY_NOT_MERGED` inline dict literals now include non-null `mergedAt`. Conflict-gate inline dict updated. Comment at lines 110-114 updated to match observed mutant behaviour.

**Per-item status:**
- R1 — FIXED. `_view_payload` decoupled; non-null `mergedAt` added to every inline dict literal in the non-canonical paths. Mutant kills confirmed: `.strip()` kills 12 tests (leading-whitespace + trailing-whitespace params across 6 test methods); `.upper()` kills 24 tests (lowercase/titlecase/mixedcase/inverted params across 6 test methods).
- R2 — FIXED. `_PR_VIEW_FIELDS` comment names `mergedAt` and cites 162-18. `_view_is_merged` docstring has a paragraph covering the corroboration conjunct, rationale, and the "real `gh` output never emits MERGED without non-null `mergedAt`" guarantee.
- R3 — DEFERRED (per SM).
- R4 — FIXED. Predicate is now `merged_at = view.get("mergedAt"); return view.get("state") == "MERGED" and isinstance(merged_at, str) and bool(merged_at)`. 9 pinning tests still pass.
- R5 — DEFERRED (per SM; follow-up story to be filed).

**Mutant results:**
- `.strip()` mutant: 12 FAILED — whitespace params across `TestViewIsMergedRejectsNonCanonicalState`, `TestConflictGateExemptionRequiresCanonicalMerged`, `TestShortCircuitRequiresCanonicalMerged`, `TestPostMergeVerificationRequiresCanonicalMerged`, `TestDryRunPreviewRequiresCanonicalMerged`.
- `.upper()` mutant: 24 FAILED — case-variant params (lowercase, titlecase, mixedcase, inverted) across the same five classes.

**Scoped tests:** 86/86 passing
**Regression batch:** 517/517 passing (`-k "finish or merge or 155_1"`)
**ruff:** All checks passed
**Branch:** `feat/162-18-mergedat-corroboration` (pushed; commit `76b0a6155`)

## Dev Assessment (Round-Trip 2)

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — C2-1: reverted R4 — `merged_at` local binding removed, predicate restored to `return view.get("state") == "MERGED" and bool(view.get("mergedAt"))`. Docstring: "non-null, non-empty string" wording trimmed to "non-null"; corroboration paragraph kept intact.
- `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py` — C2-2: added `"mergedAt": "2026-08-04T00:00:00Z"` to the `_pr_view` patch in `test_non_canonical_state_fails_verification`.

**Per-item status:**
- C2-1 — FIXED. `isinstance` and `bool` guards gone. Bare `bool(view.get("mergedAt"))` restored. Docstring aligned: no type language, corroboration paragraph preserved.
- C2-2 — FIXED. Post-merge-verify patch now has non-null `mergedAt`. `.upper()` mutant kills 29 tests (was 24 in round-trip 1); `TestPostMergeVerificationRequiresCanonicalMerged::test_non_canonical_state_fails_verification` now appears for all 4 case-variant params, confirming the state comparison is live at this site.

**Scoped tests:** 86/86 passing
**Regression batch:** 517/517 passing (`-k "finish or merge or 155_1"`)
**ruff:** All checks passed
**Branch:** `feat/162-18-mergedat-corroboration` (pushed; commit `f141cf6ce`)
**Working tree:** clean

## Design Deviations

### Dev (implementation)
- **Test fixture scope wider than TEA probed:** TEA's two-liner was correct for the production change, but 8 existing test files had `gh pr view` fakes returning `{"state": "MERGED"}` without `mergedAt`. Updated those fakes to include `mergedAt` when state is MERGED. This is a data-accuracy fix (GitHub always includes `mergedAt` in MERGED PR views), not a behavior change. Affects: `test_155_15`, `test_162_1` (stateful stub), `test_162_6`, `test_162_9`, `test_demo_finish_hook` (×10), `test_story_finish_no_jira`, `test_160_3_jira_sentinel_gating`.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Reviewer (audit)
- **Dev's declared deviation — ACCEPTED.** The 8-file fixture widening is correct and necessary. Every added timestamp is conditional on the fake's own MERGED state (`... if <state expr> == "MERGED" else None`) or is an inline literal on a hard-coded MERGED stub; none are unconditional, none flip a test's meaning. Verified by reading all 8 diffs. `test_162_6`'s hoist of `live.get(here, world.state)` into a `current_state` local is behavior-preserving (it removes a double evaluation rather than introducing one). This is data-accuracy alignment with real `gh` output, not masking.
- **UNDOCUMENTED (Reviewer-added):** the AC1 fixture edit is a behavior-changing test edit whose blast radius on the pre-existing 162-3 suite was not assessed. See R1 below.

## Subagent Results

**All received: Yes** — 5 of 5 enabled specialists returned. None errored.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 86/86 scoped tests pass, `ruff` clean, no debug artifacts; noted the timestamp ternary duplicated across 4 fixtures and long lines in JSON payloads | Confirmed (folded into R3, cosmetic) |
| 2 | reviewer-rule-checker | Yes | clean | 0 violations across 18 rules / 61 instances — edits are all in `pennyfarthing-dist/` (not the symlinked runtime), all Python, no mutable defaults, no bare excepts, mock targets all correct for the local-import pattern | Confirmed clean — [RULE] |
| 3 | reviewer-security | Yes | findings | 2 low-confidence: same-source corroboration (both fields from one `gh` payload, so no defence against a tampered `gh` binary); truthiness accepts any non-empty string | Partly confirmed → R4; same-source point dismissed with rationale below — [SEC] |
| 4 | reviewer-test-analyzer | Yes | findings | 2 high-confidence vacuous-assertion findings on the 162-3 suite; independently reproduced both surviving mutants in an isolated worktree (67/67 pass under each) | **Confirmed — this is R1**, arrived at independently of my own probe — [TEST] |
| 5 | reviewer-type-design | Yes | findings | 3: stringly-typed field registry vs untyped snapshot (the structural root of this very bug class), unvalidated truthiness on an `Any`, state as bare string rather than a literal union | Confirmed as R5 (deferred, out of scope) + R4 — [TYPE] |

**Dismissed with rationale:** the security specialist's same-source-corroboration point ([SEC], low confidence) is correct as stated but is not a defect. Both fields necessarily arrive in one `gh pr view` payload, and the threat model here is GitHub's own API inconsistency plus the gh no-op-merge bug (gh #71/#60) — not a hostile `gh` binary on `PATH`, which would already own every other decision finish makes. Independent out-of-band corroboration would require a second credentialled API call and is disproportionate. Worth a docstring sentence (folded into R2) so a future reader does not mistake the check for tamper resistance; not worth a code change.

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] [TEST] | R1 — AC2 is not satisfied, and the change silently voids all of 162-3's protection. Every `NON_CANONICAL_MERGED` assertion in the 162-3 suite is now vacuous: the direct-predicate tests pass a view dict with no timestamp key at all, and the integration tests build payloads whose timestamp is derived via exact `state == "MERGED"` (the AC1 edit) — so for `merged` / `Merged` / `MeRgEd` / `mERGED` / `" MERGED"` / `"MERGED "` the timestamp is always null and the second conjunct alone returns not-merged. The state comparison is no longer under test anywhere. Mutation-proven, not theorized: with a `.strip()` mutant on the state comparison, 67/67 pass; with a `.upper()` mutant, 67/67 pass and 517/517 pass across the whole `finish or merge or 155_1 or 162_3 or 162_18` batch (that batch demonstrably contains all 67 + all 19). AC2 required the whitespace entries to "kill the `.strip()` mutant" — they cannot. The inline comment at `test_162_3...py:110-111` asserting a `.strip()` mutant "would accept these" is mutation-disproven. This is exactly the inert-test defect class AC1/AC2 exist to eliminate, reintroduced one layer up. | `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py`:209 (`_view_payload` derivation), :318, :336, :349, :356 (dict literals with no timestamp key), :110-114 (new params + false comment) | Decouple the corroboration timestamp from `state` in the 162-3 suite so `state` is the only variable: give `_view_payload` an explicit non-null default independent of `state` (same shape TEA already used in `test_162_18...py:145`), and add a non-null timestamp to every `_view_is_merged({...})` dict literal in the `NON_CANONICAL_MERGED` / `ALREADY_NOT_MERGED` paths. Then re-run both mutants — `.strip()` and `.upper()` must each fail at least the whitespace and case params respectively. Fix the `:110-111` comment to match observed reality. Test-only change; no production edit needed. |
| [MEDIUM] [SEC] | R2 — the trust predicate's documentation no longer describes the predicate. `_view_is_merged`'s docstring covers only the state comparison and closes with "Any spelling other than `MERGED` (including a missing key or an unreadable probe) reads as 'not merged', which is the safe answer at all four call sites" — the timestamp corroboration, now half of the load-bearing conjunction, is undocumented. The `_PR_VIEW_FIELDS` block comment above it enumerates each field's purpose (`state` for the merged checks, the other three for the conflict gate) and does not account for the field that was just added. On machinery whose entire job is to be un-deletable, an undocumented conjunct is an invitation to delete it. | `pennyfarthing-dist/src/pf/sprint/story_finish.py`:376-378, :447-463 | Extend the block comment to name the new field and its role, and add a docstring paragraph stating that a `MERGED` state is trusted only when corroborated by a non-null timestamp, why (a state snapshot alone authorises the `done` transition and three bypasses), and that real `gh` output never emits one without the other. |
| [MEDIUM] [SEC] [TYPE] | R4 — the corroboration accepts any truthy value, not a timestamp. `bool(view.get("mergedAt"))` on a value typed `Any` is satisfied by the string `"null"`, `"false"`, `"0"`, or `"pending"`. Real `gh` output is JSON-parsed, so a JSON null becomes Python `None` and is correctly rejected — which is why I rate this hardening rather than a live defect. But this predicate's entire job is to be the un-fool-able half of a trust check, and "non-empty string" is one `isinstance` away. Raised independently by both the security and type-design specialists. | `pennyfarthing-dist/src/pf/sprint/story_finish.py`:463 | Cheap hardening while Dev is already in the file for R1: bind the value and require `isinstance(merged_at, str) and bool(merged_at)`. Do not add timestamp-format parsing — that trades a real-input false-negative risk for a hypothetical one and would need its own pinning tests. |
| [LOW] [TYPE] | R5 — the structural root of this bug class survives the fix. The field registry is a comma-joined `str` and the snapshot it produces is `dict[str, Any]`, so nothing connects a declared field to its consumer. That gap is *exactly* how this defect was born: the timestamp was read at the predicate while absent from the field list, and no checker could see it. This story patches the instance; the class remains, and the next field added on one side only will fail silently in the same direction. Out of scope for a 1-point story — recording so it is not lost. | `pennyfarthing-dist/src/pf/sprint/story_finish.py`:376-379 | Do NOT fix here. File a follow-up story for a `TypedDict` snapshot (`state`, `mergeable`, `mergeStateStatus`, `baseRefName`, `mergedAt`) with the field list derived from its keys, so a read-without-request becomes a type error. Optionally a literal union for the state enum, though its current failure mode is safe-direction. |
| [LOW] | R3 — the 155-15 fixture re-evaluates the compound expression `pr_state if landed else pre_merge_pr_state` a second time to derive the timestamp, where the sibling fixtures in `test_162_6` / `test_162_9` hoist it to a local. Cosmetic divergence only; the two copies cannot drift apart silently because they sit on adjacent lines. | `pennyfarthing-dist/src/pf/tests/test_155_15_finish_blocked_merge_no_stray_archive.py`:265-268 | Optional: hoist to a local for parity with the other fixtures. Not blocking. |

**Verified good (first-hand):**
- **[RULE] Project-rule compliance is clean.** All 10 changed files sit under `pennyfarthing-dist/` — no edits reached the symlinked runtime tree. No new raised exceptions (the changed helper is a private predicate returning `bool`, contract unchanged), no mutable default arguments, no bare excepts, no star imports, no new dependencies. The mock targets are correct for the local-import pattern in the finish flow (patching the merge-mode reader at its defining module rather than at the consumer, because the consumer imports it inside the function body).
- **Production change is minimal and correct in shape.** Two lines, both exactly as TEA specified. `_pr_block_reason`'s case folding on the mergeability fields was correctly left alone (out of scope, opposite risk profile).
- **All bypass paths route through the single predicate — confirmed, and there are four, not three.** Grepped every `MERGED` / `state` / merged comparison in `story_finish.py`. Call sites: `:483` (`_pr_is_merged`), `:494` (post-merge verification), `:522` (conflict-gate exemption), `:1326` (already-merged short-circuit), plus `:1188` — the dry-run preview, a fourth site the story description omits, which correctly inherits corroboration and preserves the 155-31 preview/reality parity. No inline state comparison escapes the helper. `:1496`'s `merge_state["state"] == "merged"` is the independent git-ancestry probe — a different domain with lowercase sentinels, correctly untouched.
- **Data flow traced end-to-end:** `gh pr view --json <field list>` → `_pr_view_probe` → snapshot dict → `_view_is_merged` → three bypasses + preview → `done` transition. The new field enters at the field list and is consumed only inside the one predicate; no other consumer reads it, so no path can observe it half-applied.
- **Blast radius on legitimate merges — assessed, risk is real but acceptable, and the degraded mode is fail-closed.** (a) The field name is valid: `gh pr view --json mergedAt` reaches GraphQL PR resolution, while a control (`--json bogusFieldXyz`) is rejected up front with "Unknown JSON field" — so the field list will not start failing wholesale. (b) GitHub sets the timestamp non-null iff the PR merged; a `MERGED` state with a null timestamp is not a producible API response, so no genuine merge loses its bypass. (c) Even in the paranoid case, the new failure mode is conservative rather than destructive: the predicate reads not-merged, finish attempts `gh pr merge` on an already-merged PR, gh exits non-zero, and the existing non-zero abort fires — which the suite pins directly (`test_merged_state_with_mergedat_still_short_circuits` uses a failing merge return code precisely to prove the short-circuit is what fired). Combined with the 155-15 no-stray-archive guarantee, a false not-merged costs a retry, never a corrupted archive or a premature `done`.
- **The 9 pinning tests are real, not vacuous.** Mutation-verified: reverting the corroboration conjunct fails 8 of them; dropping the field from the field list fails the 9th. They also carry genuine over-reach guards — a non-`MERGED` state with a timestamp present still reads not-merged, a clean PR with an unvouchable snapshot is still not blocked, a fully corroborated snapshot still short-circuits, and the pre-existing fields must survive in the field list. The end-to-end abort test asserts on four independent consequences (result, no `done` transition, session retained, no stray archive) rather than a single boolean.
- **Error handling / null inputs:** the `view is None` → not-merged contract survives and is pinned. A missing key, an explicit null, and an unreadable probe all converge on the safe answer. Timeout is still reported distinctly from not-merged via the verification tuple (162-9) — corroboration does not collapse those two facts.
- **Regression batch re-run first-hand:** 517 passed / 6077 deselected on `-k "finish or merge or 155_1"`. Scoped run 86 passed. `ruff check` clean across all 10 changed files.
- **Security:** no new external input, no injection surface — the added field is a read-only enum-adjacent timestamp consumed only as a truthiness test. The change strictly tightens an authorisation predicate.

**Mutation probes (all self-restoring; `git status` on `pennyfarthing/` clean, `git diff` empty after):** revert corroboration conjunct → 8 failed; drop field from field list → 1 failed (the field-list test); `.strip()` on state → 67/67 **passed** (mutant survives — R1); `.upper()` on state → 67/67 and 517/517 **passed** (mutant survives — R1).

**Handoff:** Back to Dev (test-only fix for R1 + R2; R3 optional). The production change stands as written — do not touch `story_finish.py`'s predicate logic.

## Subagent Results

**All received: Yes** — 5 of 5 enabled specialists returned, scoped to the rework diff `2e36f1080..HEAD`. None errored.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 86/86 scoped pass, `ruff` clean, no new smells; longest rework line 106 chars, within limits | Confirmed clean |
| 2 | reviewer-rule-checker | Yes | findings | 1 violation of 16 rules: the `tdd` workflow constraint — two new production conjuncts landed with no pinning test; enumerated the three missing assertions | **Confirmed — C2-1** — [RULE] |
| 3 | reviewer-security | Yes | clean | Tightening is monotonic (no new True-returning path), cannot raise; audited the new docstring's factual claims and found no overclaim | Confirmed clean — [SEC] |
| 4 | reviewer-test-analyzer | Yes | findings | Both mutants now killed (24 and 12); found the one surviving vacuous assertion; proved both new conjuncts deletable with zero failures | **Confirmed — C2-1 and C2-2** — [TEST] |
| 5 | reviewer-type-design | Yes | findings | The `isinstance` form does not close the concrete case it was raised for — `"null"` is still a non-empty `str` and still passes; the local-binding/short-circuit form and the fixture signature change are correct with no call-site breakage | **Confirmed — folded into C2-1** — [TYPE] |

**Convergence note:** three specialists reached C2-1 independently by different routes — a rule audit against the stated workflow constraint, a mutation probe, and a type analysis of the guard's actual coverage. My own probes reached it a fourth time. That is not a marginal finding.

## Reviewer Assessment

**Verdict:** REJECTED

**Cycle:** 2 (re-review of rework commit `76b0a6155`)

### Prior findings — disposition

| ID | Status | Evidence |
|----|--------|----------|
| R1 [HIGH, blocker] | **ADDRESSED** | Verified first-hand. `_view_payload` now takes an explicit `mergedat` keyword defaulting to a non-null timestamp, and the dict literals at `:329`, `:347`, `:360`, `:367`, `:392` carry one. Both establishing mutants now die: `.strip()` on the state comparison → **12 failed / 55 passed** (exactly the 6 assertion sites × 2 whitespace params), `.upper()` → **24 failed / 43 passed**. Dev's reported counts match mine exactly. The comment at `:110-113` now describes what the params actually pin. |
| R2 [MEDIUM] | **ADDRESSED** | The field-list block comment names the new field and its role as the second conjunct; the predicate docstring adds a paragraph covering what is corroborated, why (three irreversible steps), and that real `gh` output never emits the state without the timestamp. The security specialist audited each factual claim — including "set by GitHub at merge time and never cleared" — and found no overclaim. |
| R4 [MEDIUM] | **PARTIALLY ADDRESSED → now C2-1** | The `isinstance` guard was added as suggested, but landed unpinned, and does not close the concrete case that motivated it. See C2-1. |
| R5 [LOW] | Deferred by SM | Follow-up story for the `TypedDict` snapshot. Not re-flagged. |
| R3 [LOW] | Deferred by SM | Not re-flagged. |

### New findings

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] [RULE] [TEST] [TYPE] | C2-1 — the rework shipped two new production conjuncts as mutation-proven dead code, violating this story's stated `tdd` constraint. `isinstance(merged_at, str)` and `bool(merged_at)` are each deletable with **zero** test failures — I probed both: dropping `isinstance` → 86/86 pass; dropping `bool` → 86/86 pass. No test anywhere supplies `mergedAt` as an empty string or as a non-string truthy value. The existing 9 pins cover null and absent, and those already pass under the old bare truthiness form, so they pin nothing new. Two aggravating factors. First, the story's constraint is explicit — "TDD (failing test first)" — and this is production logic in the predicate that authorises four bypasses, added with no failing test. Second, and decisively: an unpinned guard in the merge-trust machinery is *precisely* the defect class this story exists to eliminate. The rework fixed that class in the 162-3 suite and reintroduced it one layer down in the same commit. I am not dismissing this as cosmetic despite having asked for the hardening myself — I asked for the guard, and a guard nothing can prove is a guard nothing will keep. Compounding: the type specialist showed the guard does not even close the case it was raised for — `"null"` is a non-empty `str`, so it still passes both conjuncts, and the realistic `None` was already rejected by the previous form, meaning `isinstance` currently buys protection only against non-string truthy values that real JSON parsing cannot produce. | `pennyfarthing-dist/src/pf/sprint/story_finish.py`:474-476; missing pins in `pennyfarthing-dist/src/pf/tests/test_162_18_mergedat_corroboration.py` | **Pick one, both acceptable.** (a) *Pin it:* add three assertions to the 162-18 corroboration class — `{"state": "MERGED", "mergedAt": ""}` → False (pins `bool`), `{"state": "MERGED", "mergedAt": True}` → False (pins `isinstance`; note a bare `bool()` would accept this, so it fails without the guard), and keep the existing null/absent pins. Verify by re-running my two probes: each conjunct's deletion must now fail at least one test. Do NOT add timestamp-format parsing. (b) *Or revert it:* restore `bool(view.get("mergedAt"))`, drop the docstring's "non-empty string" wording to match, and let the deferred `TypedDict` story own the value's type end-to-end — that story will parse at the `_pr_view` boundary and make the question moot. Option (b) is legitimate: it returns the code to a state whose every conjunct is pinned. |
| [MEDIUM] [TEST] | C2-2 — one residual vacuous assertion from R1's class survives, at the most load-bearing of the four sites. `test_non_canonical_state_fails_verification` patches the view probe with `{"state": state, "mergeable": "MERGEABLE"}` — no timestamp — so for all 6 non-canonical spellings the second conjunct alone forces the rejection and the state comparison is inert. Proven: none of its 6 parametrisations appear among the 24 failures under the `.upper()` mutant. This is the post-merge re-verify — the last guard before `done`. Severity is MEDIUM rather than HIGH only because the state comparison is now genuinely pinned at four other sites (so the mutants do die at file level) and because the wrapper this test exercises adds no logic over the predicate, which is directly pinned at `:329`. It is a test that claims to pin something it does not. | `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py`:653-655 | One dict key: add `"mergedAt": "2026-08-04T00:00:00Z"` to the patch return value, matching the pattern the rework established at every sibling site. Confirm it then appears in the `.upper()` mutant failure list. |

### Verified good (first-hand, cycle 2)
- **Scoped tests:** 86 passed. **Regression:** 517 passed / 6077 deselected on `-k "finish or merge or 155_1"` — unchanged from cycle 1, so the `isinstance` tightening broke no existing finish or merge fake (all supply string literals or null). `ruff` clean on both changed files.
- **No new breakage in the rework diff.** 2 files, 34 insertions. The fixture's new keyword-only parameter cannot break its call site positionally, and the sole caller omits it, so every payload built through that helper now carries a non-null timestamp — which is what makes the state comparison load-bearing.
- **Considered trade-off, accepted:** the non-null default means fixtures now describe some states unrealistically (an `OPEN` PR carrying a merge timestamp, which real `gh` never emits). That is the correct trade here and is documented in the helper's new docstring — realism in the corroborating field would re-mask the state comparison, and the 162-18 suite owns the null-timestamp realism separately.
- **Predicate form is correct:** the local binding evaluates the lookup once, and the conjunction short-circuits left to right so the state check still fires first. Cannot raise on any input, including a null view, an absent key, or a non-string value.
- **[SEC] The tightening is monotonic and the new documentation is accurate.** Every input the new form accepts, the old form also accepted — so no path can newly return merged, and the blast-radius judgment from cycle 1 stands unchanged: a real merged PR always carries a non-null string timestamp, and the degraded mode remains fail-closed (a retry, never a premature `done`).

**Mutation probes (all self-restoring; `pennyfarthing/` `git status` and `git diff` empty after):** `.strip()` on state → 12 failed (**killed**); `.upper()` on state → 24 failed (**killed**), with the post-merge-verification pin absent from the failures (C2-2); drop `isinstance` conjunct → 86 passed (**survives**, C2-1); drop `bool` conjunct → 86 passed (**survives**, C2-1).

**Handoff:** Back to Dev. Test-only for C2-2 plus C2-1 option (a); or a 2-line production revert plus a docstring wording change for C2-1 option (b). Everything else in the rework is correct and should not be touched — the R1 fix and the documentation are both good work and the mutant kills are real.

## Subagent Results

**Cycle: 2**

**Method:** all 5 enabled subagents re-run against the delta, AND targeted re-verification of both characterized findings with the exact probes that established them in cycle 2 (`.upper()` and `.strip()` mutants on the state comparison, plus deletion of the corroboration conjunct). Both methods used; where they disagreed, my own probes decided.

**All received: Yes** — 5 of 5 enabled specialists returned, scoped to the delta `76b0a6155..HEAD`. None errored. Two returned claims that contradicted my own measurements; I re-measured and adjudicated both rather than adopting them.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 86/86 pass; claims a NEW long-line violation at `test_162_3...py`:655 (104 chars) and that "ruff would reject this on a full-suite run" | **DISMISSED — false positive**, adjudicated below |
| 2 | reviewer-rule-checker | Yes | clean | 0 violations of 13 rules; independently identified the correct test pinning the corroboration conjunct and declared the cycle-2 `tdd`-constraint violation closed | Confirmed — [RULE] |
| 3 | reviewer-security | Yes | clean | Removing the type guard reopens no fail-open path (the value is always `json.loads` output: ISO string or `None`); the reverted form remains strictly tighter than the pre-story baseline; reflowed docstring introduces no new false claim | Confirmed — [SEC] |
| 4 | reviewer-test-analyzer | Yes | findings | Confirmed both mutant kills with exact counts and the repaired site; but claims the corroboration conjunct is entirely unpinned ("delete it → 67/67 pass") | Mutant counts **confirmed**; unpinned claim **DISMISSED — scoping artifact**, adjudicated below — [TEST] |
| 5 | reviewer-type-design | Yes | findings | Revert is type-coherent for the realistic input domain; notes the docstring says "non-null" while `bool()` also rejects `""` | Confirmed as N3 (nit) — [TYPE] |

**Adjudication 1 — the "unpinned conjunct" claim is a scoping artifact, DISMISSED.** The test-analyzer measured `test_162_3*.py` alone (67 tests) and correctly observed 67/67 passing when the conjunct is deleted. But that file's charter is the state comparison; the corroboration pins live in `test_162_18_mergedat_corroboration.py`. Re-measured across the scoped pair: deleting the conjunct fails **8 tests** spanning all four bypass paths — the predicate class (both null and absent), the conflict-gate exemption (both), the short-circuit, the post-merge verification (both), and the end-to-end abort. The rule-checker reached the same conclusion independently and named the pinning test correctly. The conjunct is fully pinned, and the file separation is the right design, not a gap: 162-3 owns "no case folding," 162-18 owns "corroboration required." Demanding that 162-3 also pin corroboration would recreate exactly the entanglement that caused R1.

**Adjudication 2 — the long-line claim is a false positive, DISMISSED.** There is no `[tool.ruff]` section and no `ruff.toml` in the package, so `E501` is not in the selected rule set; `ruff check` on both changed files passes, which I verified twice. The claim that "ruff would reject this on a full-suite run" is wrong — no configuration exists under which it would. Only by explicitly forcing `--select E501` do 3 lines flag (`:360`, `:655`, `:666`), and that file already carried over-length lines at `develop`. The story's stated constraint is "`ruff check` changed files," which passes. Recorded as N2 below for accuracy, not as a defect.

## Reviewer Assessment

**Verdict:** APPROVED

**Cycle:** 3 (re-review of rework commit `f141cf6ce`)

### Prior findings — disposition

| ID | Status | Evidence |
|----|--------|----------|
| C2-1 [HIGH, blocker] | **ADDRESSED** — via option (b), the revert | The predicate is back to a single corroboration conjunct; the local binding and the type guard are both gone, so the two probes that established C2-1 no longer have a droppable sub-conjunct to target — the finding is obsolete by construction rather than merely patched. Critically, the remaining conjunct is **not** unpinned: dropping it fails **8 tests** across all four bypass paths (verified first-hand; see Adjudication 1). Choosing the revert over the pin was the better of the two options I offered — it leaves every surviving conjunct pinned and hands the value's typing to the deferred follow-up, rather than adding a guard whose concrete motivating case (`"null"` as a non-empty string) it never actually closed. |
| C2-2 [MEDIUM] | **ADDRESSED** | The post-merge-verify patch now carries a non-null timestamp. Under the `.upper()` mutant its 4 case-fold parametrisations now appear in the failure list (they were absent in cycle 2); under `.strip()` its 2 whitespace parametrisations now fail. The site is live at both mutant classes. |
| R5, R3 | Deferred by SM | Not re-flagged. |

### Findings — none blocking

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [LOW] [TYPE] [SEC] | N1 — the docstring says the state is trusted when "corroborated by a non-null `mergedAt`", but the check is truthiness, which also rejects an empty string. The code is therefore *stricter* than documented — the safe direction, and unreachable in practice since the field arrives as either an ISO-8601 string or JSON null. Raised by the type specialist and corroborated by the security specialist as a precision gap rather than a factual error. | `pennyfarthing-dist/src/pf/sprint/story_finish.py`:463 | None required. If touched for another reason, "non-null" → "non-empty" would make description and implementation exact. Not worth a commit on its own. |
| [LOW] | N2 — the file now has 3 lines that would flag if `E501` were ever selected (`:360`, `:655`, `:666`), two of them from earlier cycles of this story. Not a violation today and not a regression in kind — the file already carried over-length lines at `develop`. | `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py`:655 | None. Recorded so that a future `E501` enablement has the inventory. |

### Verified good (first-hand, cycle 3)
- **Scoped tests:** 86 passed. **Regression:** 517 passed / 6077 deselected on `-k "finish or merge or 155_1"` — identical across all three cycles, so neither the guard's addition nor its removal disturbed any existing finish or merge fake. `ruff check` clean on both changed files under the repo's actual configuration.
- **The delta contains nothing but the two requested fixes.** 2 files: the predicate revert plus a docstring reflow, and one added dict key. No opportunistic edits, no scope creep, no new call sites.
- **[SEC] The revert reopens no fail-open path and remains strictly tighter than the pre-story baseline.** For a regression to exist there would have to be a truthy non-string value, and the field is always `json.loads` output — an ISO-8601 string or `None`. The removed guard was defence-in-depth against an input the wire contract cannot produce. Every input the current form accepts, the state-only baseline also accepted, so the story's safety gain is intact.
- **[RULE] The cycle-2 `tdd`-constraint violation is closed.** Every conjunct remaining in the predicate is pinned by a test that fails when it is removed — verified by deletion, not by inspection. No new rule violation in the delta; edits confined to `pennyfarthing-dist/`, no new raised exceptions, mock target correct.
- **[TEST] Mutation coverage is now genuinely load-bearing at all four bypass sites plus the dry-run preview.** The test-analyzer's independent sweep found no remaining view dict or patch return value missing a non-null timestamp, matching my own grep.
- **Blast-radius judgment unchanged from cycle 1 and still sound:** a real merged PR always carries a non-null timestamp, the field name is valid, and the degraded mode is fail-closed — a retry, never a premature `done` or a stray archive.

**Mutation probes (all self-restoring; `pennyfarthing/` `git status` and `git diff` empty after):** `.upper()` on the state comparison → **28 failed / 39 passed (killed)**, with the post-merge-verify site's 4 case-fold params now among the failures; `.strip()` → **14 failed / 53 passed (killed)**, up from 12 in cycle 2, the +2 being that same site's whitespace params. Both counts move in exactly the direction and magnitude C2-2's fix predicts. Drop the corroboration conjunct → **8 failed** (the conjunct is pinned). Dev's commit message reports 29 for `.upper()` where I measure 28; that is not an error on either side — a naive mutant form raises on the null-state test and yields one extra failure, whereas my form guards the null, so the two counts are each correct for their own mutant. Worth noting only so the number is not treated as a discrepancy later.

**Assessment of the three-cycle arc:** the production change ends where TEA specified it — a two-line corroboration, every conjunct pinned, four bypass paths plus the preview covered, and 517 regression tests untouched. The two round trips were spent entirely on test integrity, which is what this story was chartered to buy.

**Handoff:** To SM for finish-story.