---
story_id: "162-19"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-19: Consolidate _pr_block_reason/_view_is_merged into a _classify_pr(view) precedence-ordered verdict

## Story Details
- **ID:** 162-19
- **Jira Key:** (none — Jira not configured for this epic)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-19-classify-pr-consolidation
- **PR:** #202

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T15:36:02Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T14:57:41Z | 2026-08-10T14:58:50Z | 1m 9s |
| red | 2026-08-10T14:58:50Z | 2026-08-10T15:08:10Z | 9m 20s |
| green | 2026-08-10T15:08:10Z | 2026-08-10T15:16:36Z | 8m 26s |
| review | 2026-08-10T15:16:36Z | 2026-08-10T15:23:39Z | 7m 3s |
| green | 2026-08-10T15:23:39Z | 2026-08-10T15:33:05Z | 9m 26s |
| review | 2026-08-10T15:33:05Z | 2026-08-10T15:36:02Z | 2m 57s |
| finish | 2026-08-10T15:36:02Z | - | - |

## SM Assessment

**Routing:** 2 pts, workflow `tdd` (phased) → SM→TEA→Dev→Reviewer. Peloton-inline (SM lead; SM owns PR + merge + finish). This is a BEHAVIOR-PRESERVING REFACTOR of the finish trust machinery — high blast radius → Opus reviewer.

**Spec (title + AC):** `_pr_block_reason` and `_view_is_merged` split a PR's disposition across two functions whose call ORDER at each site is positional and unenforced. Consolidate into one `_classify_pr(view)` returning a precedence-ordered verdict (e.g. merged > timeout/unreadable > blocked(conflicting/dirty) > mergeable), so ordering is encoded ONCE. Also: `_result_blob` should carry message/detail keys; add `_pr_view` field-type validation (reject a malformed/partial view rather than silently mis-classify). AC nudges a parsed-enum at the `_pr_view` boundary (precedent `pf/preflight/finish.py:193` — strict + mergedAt-corroborated). This dovetails with deferred `[[162-70]]` (TypedDict snapshot).

**CRITICAL for TEA/Dev — BEHAVIOR PRESERVATION:** every existing call site must produce the IDENTICAL outcome after consolidation. Call-site inventory to preserve (verify exact lines against current develop, which includes 162-18 + 162-20):
- merge short-circuit (already-merged skip, ~1326)
- conflict gate (real-run block, ~522/1250)
- post-merge re-verify (~494)
- dry-run preview (~1191, just brought to parity by 162-20)

**For TEA:** RED must (1) CHARACTERIZE current behavior — pin the exact verdict each call site produces for every PR state (merged/timeout/conflicting/dirty/mergeable/None-view/malformed) BEFORE the refactor exists, so the refactor is provably behavior-preserving; (2) pin the NEW precedence ordering is enforced structurally (not positionally); (3) pin the new `_pr_view` field-type validation rejects a malformed view. The existing 162-3/162-18/162-20/155-31 suites are the regression net — they must ALL stay green.

**Constraints:** TDD. Scoped runs only (`uv run pytest src/pf/tests/test_162_19*.py test_162_3*.py test_162_18*.py test_162_20*.py test_155_31*.py -q` from `pennyfarthing-dist/`) — NEVER the full suite. `ruff check`. Result objects, don't throw. Note the 3 pre-existing `test_164_1` reds are intentional TDD RED on develop — ignore them.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **`_pr_view` field-type validation realized inside `_classify_pr`:** Spec said "add `_pr_view` field-type validation" as a distinct gate; implemented as rule 4 of `_classify_pr` (non-str `state` → UNREADABLE) rather than a separate `_pr_view` wrapper function. Reason: validation belongs at the classification boundary, not at the fetch boundary.
- **`_result_blob` realized as `_PRClassification.message`/`.detail`:** Spec said "`_result_blob` should carry message/detail keys"; realized as NamedTuple fields `.message` and `.detail` on the `_classify_pr` return object. Reason: the return object IS the result blob — no separate dict needed.
- **Rule order option A (Reviewer R1):** TEA's contract specified MERGED > UNREADABLE > BLOCKED > MERGEABLE. Reviewer R1 found that placing UNREADABLE (non-str state) before BLOCKED introduced a fail-open regression on malformed+CONFLICTING views. Adopted option A: BLOCKED rule runs before the non-str-state UNREADABLE guard, preserving pre-refactor `_pr_block_reason` fail-closed semantics exactly (12,961 shapes checked, zero divergence). A fuller fail-closed treatment of UNREADABLE at the gates (e.g. aborting on unreadable probes rather than falling through) is intentionally out of scope for this behavior-preserving refactor.
- **`PRVerdict` → `_PRVerdict`:** Reviewer R1 flagged visibility inconsistency (public enum, private classifier). Renamed to `_PRVerdict` (module-private) for consistency with `_classify_pr` and `_PRClassification`.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — added `PRVerdict` (StrEnum), `_PRClassification` (NamedTuple), `_classify_pr(view)`; rewrote `_view_is_merged` + `_pr_block_reason` as thin wrappers; refactored 4 call sites to route on verdict

**`_classify_pr` shape:**
- Input: `dict[str, Any] | None`
- Rules (precedence order): None → UNREADABLE; non-str state → UNREADABLE; `state=="MERGED" and mergedAt` → MERGED; `mergeable.upper()=="CONFLICTING" or mergeStateStatus.upper()=="DIRTY"` → BLOCKED; else MERGEABLE
- Returns `_PRClassification(verdict, message, detail)` — BLOCKED carries conflict message + base branch in `detail`

**Call-site diffs (before → after):**
- Dry-run merged check (~1236): `elif _view_is_merged(view)` → `cl = _classify_pr(view); if cl.verdict == PRVerdict.MERGED`
- Dry-run conflict check (~1244): `block_reason = _pr_block_reason(pr_number, view)` → `elif cl.verdict == PRVerdict.BLOCKED` (single `_classify_pr` call covers both)
- Real-run conflict gate (~1319): `block_reason = _pr_block_reason(repo_pr, view)` → `cl = _classify_pr(view); block_reason = _pr_block_reason(...) if cl.verdict == PRVerdict.BLOCKED else None`
- Already-merged short-circuit (~1375): `_view_is_merged(pr_views.get(repo_path))` → `_classify_pr(pr_views.get(repo_path)).verdict == PRVerdict.MERGED`

**Wrappers kept (not inlined):**
- `_view_is_merged`: imported directly by test_162_3, test_162_18; used by `_pr_is_merged`, `_pr_merge_verification` — kept as one-liner wrapper
- `_pr_block_reason`: imported directly by test_162_3, test_162_18, test_162_20, test_162_19 (`test_blocked_message_matches_pr_block_reason_content`) — kept; reconstructs `PR #{pr_number} is CONFLICTING...` message from `cl.detail`

**Tests:** 46/46 new tests passing (GREEN); 101/101 regression net (162-3/162-18/162-20/155-31) green; `test_164_1` 3 pre-existing reds unaffected
**Branch:** feat/162-19-classify-pr-consolidation (pushed)
**Ruff:** Clean (fixed `str + enum.Enum` → `enum.StrEnum` per UP042)

**Reviewer concerns:**
- `_classify_pr` at the `already-merged short-circuit` call site now calls `_classify_pr(pr_views.get(repo_path))` which may be `None` if the gate loop stored `None` for that repo_path. The old `_view_is_merged(None)` returned `False` (safe); `_classify_pr(None).verdict == PRVerdict.MERGED` also returns `False` (UNREADABLE ≠ MERGED). Behavior preserved.
- Double `_classify_pr` call at the real-run conflict gate (once for verdict routing, once inside `_pr_block_reason` wrapper). Minor — pure computation, no I/O.

**Handoff:** To Reviewer

---

### Dev Assessment — Rework R1

**Per-item status:**
1. **[HIGH] Rule order (option A)** — FIXED. Reordered `_classify_pr`: BLOCKED conflict check now runs before non-str-`state` UNREADABLE guard. Differential harness: 12,961 shapes checked (all `state × mergedAt × mergeable × mergeStateStatus × baseRefName` combinations + missing-key subsets + None), zero divergence on both `_view_is_merged` and `_pr_block_reason`.
2. **[MEDIUM] Malformed+conflict characterization pins** — FIXED. Added `TestMalformedStateConflictCharacterization` (10 new tests): malformed/null `state` × {CONFLICTING, DIRTY, clean} shapes; asserts BLOCKED for conflict, UNREADABLE for clean, actionable message with base branch.
3. **[LOW] False docstring in `TestPrViewFieldTypeValidation`** — FIXED. Removed false claim that malformed+`_pr_block_reason` = None; replaced with accurate description noting malformed+CONFLICTING → BLOCKED is handled by `TestMalformedStateConflictCharacterization`.
4. **[LOW] Real-run gate double-classify** — FIXED. Both call sites (real-run gate + dry-run) now use `f"PR #{n} is {cl.message}"` directly; `_pr_block_reason` wrapper no longer called at those sites.
5. **[LOW] Visibility: `PRVerdict` → `_PRVerdict`** — FIXED. Renamed + added `isinstance(result.verdict, _PRVerdict)` assertion in `TestResultTypeContract` (4 parametrized cases).
6. **[LOW] Design deviations** — FIXED. Added three entries: `_pr_view` validation placement, `_result_blob` realized as NamedTuple, rule order option A decision.

**Tests:** 161/161 passing (scoped: 162-19 + 162-3 + 162-18 + 162-20 + 155-31)
**Differential harness:** 12,961 shapes, zero divergence on both wrappers
**Ruff:** Clean
**Branch:** feat/162-19-classify-pr-consolidation (pushed)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Behavior-preserving refactor of finish trust machinery; characterization pins required before Dev consolidates the two functions.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_19_classify_pr.py` — behavior matrix characterization, verdict contract pins, precedence structural test, field-type validation, result_blob message/detail keys

**Tests Written:** 31 tests covering all 12 PR states across all 4 ACs
**Status:** RED (ImportError — `_classify_pr` does not exist yet)

**Behavior Matrix (12 PR states → _classify_pr verdict):**

| PR State | Verdict |
|----------|---------|
| MERGED + mergedAt non-null | MERGED |
| MERGED + mergedAt=None (clean) | MERGEABLE |
| MERGED + mergedAt=None (conflicting) | BLOCKED |
| OPEN + CONFLICTING | BLOCKED |
| OPEN + DIRTY | BLOCKED |
| OPEN + CLEAN/MERGEABLE | MERGEABLE |
| OPEN + BEHIND | MERGEABLE |
| OPEN + UNKNOWN | MERGEABLE |
| CLOSED unmerged + clean | MERGEABLE |
| CLOSED unmerged + CONFLICTING | BLOCKED |
| view=None (gh error/timeout) | UNREADABLE |
| malformed view (non-str state) | UNREADABLE |

**`_classify_pr` Contract Dev Must Implement:**

Precedence: MERGED > UNREADABLE > BLOCKED > MERGEABLE (encoded once, not positionally)

```
def _classify_pr(view: dict[str, Any] | None) -> _PRClassification:
```

Return object MUST have: `.verdict` (PRVerdict enum or equivalent), `.message` (str|None), `.detail` (str|None)

Rules:
1. `view is None` → UNREADABLE
2. `view["state"]` not a `str` (or missing) → UNREADABLE
3. `state == "MERGED"` AND `bool(mergedAt)` → MERGED (beats any conflict fields)
4. `mergeable == "CONFLICTING"` OR `mergeStateStatus == "DIRTY"` (case-folded) → BLOCKED with message/detail
5. All else → MERGEABLE

Timeout: `_pr_view_probe` returns `(None, timeout_msg)`. Callers check `timeout_msg` separately; `_classify_pr(None)` → UNREADABLE covers the view side.

**True-RED assertions:** All 31 — entire file fails at import (`cannot import name '_classify_pr'`)

**RED output:**
```
ImportError: cannot import name '_classify_pr' from 'pf.sprint.story_finish'
```

**Regression net:** 162-3/162-18/162-20/155-31 → 101 passed ✓

**Handoff:** To Dev for implementation
## Subagent Results

| Specialist | Received | Status | Findings |
|------------|----------|--------|----------|
| reviewer-preflight | Received: self (inline) | PASS | Scoped suites 147/147 green (`test_162_19` 46 + regression net 101); `ruff check` clean on both changed files; `git status` clean after two self-restoring mutation probes; `test_164_1` pre-existing reds untouched. |
| reviewer-rule-checker [RULE] | Received: self (inline) | CONCERNS (2 LOW) | Result-object rule honored (no new raises; `_classify_pr` total over all inputs). Edited source is `pennyfarthing-dist/` (correct SoT, no `.pennyfarthing/` symlink touched), branch targets `develop` per `repos.yaml`. LOW: AC-named `_pr_view` field-type validation landed inside `_classify_pr`, not at the `_pr_view` boundary; AC-named `_result_blob` message/detail keys landed as `_PRClassification.message`/`.detail`. Both are defensible renames but are undocumented deviations (`## Design Deviations` still reads "No deviations yet"). |
| reviewer-security [SEC] | Received: self (inline) | PASS | No new attack surface. `_run` keeps list-form argv (no shell), no new interpolation into a command — `base`/`pr_number` reach only operator-facing message strings. No secrets, no auth logic, no new logging of PR payloads. One security-adjacent note folded into the HIGH finding below: the gate's malformed-input path changed from fail-closed to fail-open. |
| reviewer-test-analyzer [TEST] | Received: self (inline) | CONCERNS (1 HIGH, 2 LOW) | Pins are real, not vacuous — mutation probe A (swap precedence rules 3/4) killed 5 tests incl. the `test_162_18` corroborated-merge regression; probe B (drop the `isinstance(state, str)` guard) killed 11. HIGH: no case covers malformed-`state` + CONFLICTING/DIRTY — the exact shape where behavior diverges — and `TestPrViewFieldTypeValidation`'s docstring asserts a factually false premise about pre-refactor behavior. LOW: the precedence sweep at `test_162_19_classify_pr.py:624` omits any multi-match malformed view; helpers duck-type via `_verdict()`/`hasattr`, so the tests would still pass if the result were a plain dict (enum/NamedTuple types unpinned). |
| reviewer-type-design [TYPE] | Received: self (inline) | CONCERNS (2 LOW) | `PRVerdict` StrEnum + `_PRClassification` NamedTuple are the right shape: closed verdict set, single ordered evaluation, `.message`/`.detail` carried with the verdict. LOW: `PRVerdict` is public while `_classify_pr`/`_PRClassification` are underscore-private — inconsistent visibility for a module-private concept. LOW: `_PRClassification.message` is typed `str | None` with the non-None-for-BLOCKED invariant enforced only by convention, and the real-run gate discards `cl.message` to re-derive the same string inside `_pr_block_reason`, re-splitting the construction the story set out to consolidate. |

**All received:** Yes

## Reviewer Assessment

**Verdict:** REJECTED

**Specialist coverage (all performed inline by Reviewer):** [RULE] project-rule conformance — result objects, `pennyfarthing-dist/` source-of-truth, `develop` target: PASS with two undocumented-deviation LOWs. [SEC] no new command-injection, secret, or auth surface; the only security-adjacent issue is the gate's fail-closed → fail-open flip in the HIGH below. [TEST] pins are mutation-proven real (5 and 11 kills), but the matrix has no malformed-`state` + CONFLICTING case and one test docstring asserts a false premise about pre-refactor behavior. [TYPE] `PRVerdict`/`_PRClassification` are the right closed-set shape; visibility inconsistency and an unpinned result-type contract are LOW.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Behavior-preservation failure: `_pr_block_reason` (and both call sites that route on it) now returns `None` — "do not block" — for a view whose `state` is missing/non-str but which carries `mergeable == CONFLICTING` or `mergeStateStatus == DIRTY`. Pre-refactor it returned the actionable `PR #{n} is CONFLICTING ...` block message. Confirmed by differential harness against `develop`: 588 divergent view shapes, all of this one class; `_view_is_merged` diverges on zero. The conflict gate flipped from fail-closed to fail-open on malformed input — the precise input class the module's own docstrings call "load-bearing, not defensive padding". | `story_finish.py:423-428` (rule 2 ordered above rule 4), consumed at `:1319` (real-run gate) and `:1236-1242` (dry-run) | Choose deliberately and pin it: (a) preserve — let the BLOCKED conflict-field check run before the `state` type guard (or have the BLOCKED path read conflict fields independently of `state` validity), or (b) fail closed — make UNREADABLE from a non-`None` view abort the real-run gate with "could not read PR state" instead of falling through to `gh pr merge`. Either way add a test for malformed-`state` + CONFLICTING, fix the false premise in `TestPrViewFieldTypeValidation`'s docstring, and log the choice under `## Design Deviations`. |
| [MEDIUM] | Characterization gap that let the above through: TEA's 12-row matrix pairs "malformed view" only with otherwise-empty views, so no pin compares old vs new for a view matching both rule 2 and rule 4. Dev's assessment asserts "Behavior preserved" having enumerated only the `view is None` case. | `test_162_19_classify_pr.py:706-729`; Dev Assessment "Reviewer concerns" | Extend the matrix to the multi-match malformed shapes and re-derive the preservation claim from a differential run, not from inspection. |
| [LOW] | AC-named `_pr_view` field-type validation and `_result_blob` message/detail keys were implemented under different names/locations without a `## Design Deviations` entry. | `story_finish.py:400-449` | Log both as accepted deviations with rationale. |
| [LOW] | Real-run gate classifies twice (`_classify_pr` for routing, again inside the `_pr_block_reason` wrapper) and drops `cl.message`. | `story_finish.py:1318-1320` | Prefer `cl.message` with the `PR #{n} is ` prefix applied once, keeping the wrapper for the suites that import it. |
| [LOW] | `PRVerdict` public vs `_classify_pr`/`_PRClassification` private; result-shape tests duck-type, so the enum/NamedTuple contract is unpinned. | `story_finish.py:385`; `test_162_19_classify_pr.py:790-800` | Align visibility; add one assertion on `isinstance(result.verdict, PRVerdict)`. |

**Call-site-by-call-site behavior preservation (all 4 enumerated):**

1. **Post-merge re-verify** (`_pr_is_merged`:543 → `_view_is_merged`:515 → `_classify_pr`; and `_pr_merge_verification`:546) — **IDENTICAL.** Differential harness over 3,392 view shapes (7 `state` × 4 `mergedAt` × 6 `mergeable` × 5 `mergeStateStatus` × 5 `baseRefName`, plus all 32 missing-key subsets, plus `None`): zero divergences for `_view_is_merged`. Routing unchanged — still re-fetches a FRESH snapshot via `_pr_view`, and rules 1–3 reproduce the old strict `state == "MERGED" and bool(mergedAt)` exactly, including UNREADABLE ≠ MERGED for the `None` view. The strictness 162-3 bought (no case folding, no aliases) survives: rule 3 uses `==`, not the case-folded comparison rules 4 uses.
2. **Real-run conflict gate** (:1318) — **DIVERGES** on the malformed-`state` + conflict-fields class (HIGH above). Identical on every well-formed shape, incl. 162-18's corroborated-merge exemption and the CLOSED-unmerged-must-still-block case.
3. **Already-merged short-circuit** (:1375) — **IDENTICAL.** `_classify_pr(pr_views.get(repo_path)).verdict == PRVerdict.MERGED` matches `_view_is_merged` pointwise per the sweep above, and the missing-key/`None` snapshot still reads as NOT merged, so an unreadable gate probe still falls through to the real merge attempt rather than silently skipping it (155-29 invariant intact).
4. **Dry-run preview** (:1232-1246) — **DIVERGES** on the same malformed class; the timeout arm is untouched and still evaluated before classification, and MERGED-before-BLOCKED-before-else reproduces 162-20's ordering on all well-formed shapes.

**Precedence — structurally encoded, verified:** MERGED > UNREADABLE > BLOCKED > MERGEABLE is a single ordered evaluation inside one function with early returns; no caller re-establishes order. Probed multi-match views: `state=MERGED` + `mergedAt` + `mergeable=CONFLICTING` + `mergeStateStatus=DIRTY` → MERGED (162-18's corroborated-merge-beats-conflict preserved), and `state=MERGED` + `mergedAt=None` + CONFLICTING → BLOCKED (no corroboration, still hard-blocks). Mutation probe A proved the ordering is load-bearing and pinned. The one ordering I dispute is rule 2 above rule 4 — see the HIGH.

**Field-type validation:** a non-`str` `state` (`None`, `0`, `False`, `[]`, `["OPEN"]`) and a missing `state` key both yield UNREADABLE with no raise, and `_classify_pr` is total over the whole 3,392-shape sweep plus `None` — no exception escapes, so the `{success, error}` contract holds. Over-reach guard present (valid `str` state never UNREADABLE). The defect is not the guard, it is its precedence relative to BLOCKED.

**Mutation probes (self-restoring, both killed tests):** A — swapped precedence rules 3↔4 → 5 failed (`test_merged_verdict_takes_precedence_over_dirty_merge_state`, both structural precedence tests, and `test_162_18::test_fully_corroborated_merged_still_exempt`). B — replaced the `isinstance(state, str)` guard with `state = str(state)` → 11 failed (all `test_malformed_view_is_unreadable_not_mergeable` params + UNREADABLE contract tests). Source restored from backup after each; `git status --porcelain` empty and `git diff` empty in `pennyfarthing/`; scoped suites re-run post-restore at 147/147.

**Data flow traced:** `gh pr view --json state,mergeable,mergeStateStatus,baseRefName,mergedAt` → `_pr_view_probe` (timeout/rc/JSON/`isinstance(data, dict)` filters, unchanged) → `_classify_pr(view)` → verdict → gate abort / already-merged skip / merge attempt → post-merge `_pr_is_merged` re-verify → `done` transition. Safe at the merge boundary: the fail-open path in the HIGH finding reaches only `gh pr merge`, which itself fails on a conflicting PR, and the load-bearing post-merge verification still guards the `done` transition and the archive — so this is a lost diagnostic and a broken invariant, not a data-corruption path. That is why it is HIGH and not CRITICAL.

**Error handling:** every arm returns a result object; `None` view, missing keys, wrong types, and timeout are each handled distinctly, with the timeout arm (`_pr_view_probe`'s second element) still evaluated ahead of classification at both gates so "could not read" stays separable from "did not merge" (162-9).

**Pattern observed (good):** precedence collapsed into one ordered function with the historical rationale (162-1/162-3/162-18) carried into rule comments at `story_finish.py:400-420` — the docstring debt the old two-function split accumulated is now stated once where it is enforced.

**Deviation audit:** `## Design Deviations` reads "No deviations yet" — inaccurate. Two UNDOCUMENTED deviations (the `_pr_view`-boundary validation relocated into `_classify_pr`; `_result_blob` realized as `_PRClassification.message`/`.detail`), both ACCEPTED on substance, and one FLAGGED design choice (UNREADABLE ordered above BLOCKED) which is the HIGH finding.

**Handoff:** Back to Dev — the HIGH is a one-decision fix plus a pin; the MEDIUM is TEA-adjacent (extend the matrix and re-derive the preservation claim differentially).

### Reviewer (code review)
- **Gap** (blocking): Behavior-preservation verification for this refactor was done by inspection, not differentially. A 40-line harness that imports the pre-refactor module from `develop` and sweeps both wrappers over a generated view space found the one divergence in seconds. Affects the finish trust machinery generally (`pennyfarthing-dist/src/pf/sprint/story_finish.py`) — worth a reusable differential-characterization helper for future refactors of this module, and worth adding to the TEA guide for behavior-preserving-refactor stories. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_classify_pr` now owns the whole PR-disposition decision, which makes the deferred `[[162-70]]` TypedDict snapshot a smaller change than filed — the validation seam is a single function instead of five field reads. Affects `[[162-70]]` scoping. *Found by Reviewer during code review.*
---

## Subagent Results

**Cycle: 1**

Re-review of commit `a786e64a4`. Method: targeted re-verification of each previously characterized finding — the establishing differential harness re-run against `develop` (11,648 shapes), a self-restoring mutation probe that re-introduces the cycle-1 defect, and direct re-inspection of all four call sites and the new pins. All five specialist domains re-covered inline below.

| Specialist | Received | Status | Findings |
|------------|----------|--------|----------|
| reviewer-preflight | Received: self (inline) | PASS | Scoped suites 161/161 green (was 147 — +14 new pins); `ruff check` clean on both changed files; `test_164_1` pre-existing reds untouched; `git status` clean in `pennyfarthing/` after a self-restoring mutation probe; suite re-run post-restore at 60/60 for the story file. |
| reviewer-rule-checker [RULE] | Received: self (inline) | PASS | Both cycle-1 LOWs closed: three `## Design Deviations` entries now logged (validation placement, `_result_blob`→NamedTuple fields, option-A rule order) plus a fourth for the `_PRVerdict` rename. Result-object rule still honored — `_classify_pr` remains total (no raise) across the full sweep. Source edits confined to `pennyfarthing-dist/`; no symlinked `.pennyfarthing/` path touched; branch still targets `develop`. |
| reviewer-security [SEC] | Received: self (inline) | PASS | The fail-open flip is gone — the conflict gate is fail-closed again on malformed input. No shell, list-form argv unchanged; `base`/`pr_number` still reach only operator-facing strings. No new logging of PR payloads, no auth/secret surface. |
| reviewer-test-analyzer [TEST] | Received: self (inline) | PASS | Cycle-1 HIGH gap closed by `TestMalformedStateConflictCharacterization` (10 pins: malformed `state` ∈ {`None`, `42`, `[]`, `True`} × {CONFLICTING → BLOCKED, DIRTY → BLOCKED, clean → UNREADABLE} + an actionable-message pin). Mutation-proven: regressing the rule order back to cycle-1 killed 7 tests, 5 of them in this new class. The false-premise docstring in `TestPrViewFieldTypeValidation` is corrected and now states the real pre-refactor behavior. `TestResultTypeContract` closes the duck-typing gap. LOW (nit): the malformed-message pin asserts keywords rather than exact string equality — acceptable, since exact equality is covered by `test_blocked_message_matches_pr_block_reason_content` and proven exhaustively by the differential harness. |
| reviewer-type-design [TYPE] | Received: self (inline) | PASS | `_PRVerdict` rename aligns visibility with `_classify_pr`/`_PRClassification`; `isinstance(result.verdict, _PRVerdict)` now pins the result type. Call sites consume `cl.message` directly — the double-classify is gone. LOW (nit): stale doc refs — `_pr_block_reason`'s docstring still cites "rule 4" and `_view_is_merged`'s cites "rules 1–3" after the renumbering, and the test module header still names `PRVerdict` and claims a non-None `message` for UNREADABLE. Comments only; no behavior impact. |

**All received:** Yes

## Reviewer Assessment

*(Cycle 2 — `Cycle: 1` rework of `162-19`, commit `a786e64a4`.)*

**Verdict:** APPROVED

**Specialist coverage (all performed inline by Reviewer):** [RULE] deviations now documented, result-object contract intact — PASS. [SEC] fail-closed restored at the conflict gate, no new surface — PASS. [TEST] the missing multi-match characterization now exists and is mutation-proven; the false-premise docstring is corrected — PASS. [TYPE] `_PRVerdict` visibility aligned and the result type pinned by `isinstance` — PASS.

**Per-finding disposition:**

| Cycle-1 finding | Status | Evidence |
|---|---|---|
| [HIGH] fail-open on malformed-`state` + CONFLICTING/DIRTY | **ADDRESSED (option A)** | Differential harness re-run first-hand: **11,648 view shapes × 2 functions = 23,296 comparisons against `develop`, ZERO divergences** on both `_view_is_merged` and `_pr_block_reason`, including the `None` view. The 588-shape divergent class from cycle 1 is gone. |
| [MEDIUM] characterization gap in the behavior matrix | **ADDRESSED** | `TestMalformedStateConflictCharacterization` (10 pins) covers malformed `state` × {CONFLICTING, DIRTY, clean}; mutation probe killed 7 tests. |
| [LOW] undocumented deviations | **ADDRESSED** | Four `## Design Deviations` entries, incl. an explicit scope statement that fuller fail-closed UNREADABLE handling is out of scope for a behavior-preserving refactor — the right call. |
| [LOW] double-classify / discarded `cl.message` | **ADDRESSED** | `:1254` and `:1336` now use `f"PR #{n} is {cl.message}"`; one `_classify_pr` call per site. |
| [LOW] `PRVerdict` visibility + unpinned result type | **ADDRESSED** | `_PRVerdict` rename applied module-wide (no stale code references — only doc text); `TestResultTypeContract` asserts `isinstance(result.verdict, _PRVerdict)`. |

**Differential behavior-preservation proof (the load-bearing check):** harness imports the pre-refactor module from `develop` via `importlib` and sweeps both wrappers over 11 `state` × 5 `mergedAt` × 7 `mergeable` × 6 `mergeStateStatus` × 5 `baseRefName` (= 11,550) plus all 32 missing-key subsets of three distinct base views plus the `None` view — 11,648 shapes, comparing return value *and* exception identity. Result: **0 divergences**. This independently corroborates Dev's 12,961-shape claim (different generator, same conclusion) and is the strongest form of the preservation proof available: `_pr_block_reason` returns the byte-identical `PR #{n} is CONFLICTING — rebase on {base} …` string everywhere `develop` did, and `_view_is_merged` is pointwise identical.

**Call sites re-verified (all 4):** post-merge re-verify (`_pr_is_merged`:554 / `_pr_merge_verification`:557 → `_view_is_merged`:535) — IDENTICAL, still re-fetches a fresh snapshot, still separates timeout from "did not merge"; real-run conflict gate (:1331) — IDENTICAL, and malformed+conflict once again hard-blocks before any irreversible step (gh #113 intent restored); already-merged short-circuit (:1391) — IDENTICAL, unreadable snapshot still reads NOT merged; dry-run preview (:1245) — IDENTICAL, timeout arm still evaluated before classification, 162-20 parity preserved.

**Precedence, re-verified:** now MERGED > BLOCKED > UNREADABLE > MERGEABLE, still a single ordered evaluation with early returns inside one function. Rule 2 reads `state` before validating its type, which is safe by construction (`42 == "MERGED"` is `False`) and documented as such. Multi-match probes hold: `MERGED+mergedAt+CONFLICTING+DIRTY` → MERGED (162-18 corroborated-merge-beats-conflict intact, confirmed by `test_162_18::test_fully_corroborated_merged_still_exempt` passing); `MERGED+mergedAt=None+CONFLICTING` → BLOCKED; `state=None+CONFLICTING` → BLOCKED; `state=None+clean` → UNREADABLE.

**Mutation probe (self-restoring):** moved the UNREADABLE `state`-type guard back above the BLOCKED rule (i.e. re-introduced the cycle-1 defect) → **7 tests failed**, 5 in the new characterization class incl. `test_blocked_message_for_malformed_state_is_actionable`. Source restored from backup; story suite re-run at 60/60; `git status --porcelain` empty in `pennyfarthing/`. The regression is now permanently pinned — that is the durable value of this rework.

**Error handling / field validation:** `_classify_pr` remains total over all 11,648 shapes plus `None` — no exception escapes, so `finish_story`'s `{success, error}` contract holds. Malformed-and-clean views still degrade permissively to a merge attempt guarded by the post-merge verification, which is the pre-refactor behavior, not a new risk.

**Pattern observed (good):** the rule-order docstring now carries the *reason* for the non-obvious ordering (BLOCKED before the type guard) and cites the review that produced it — the next person tempted to "clean up" the order by moving validation first will read why not. That comment is the actual fix; the code change alone would have been re-broken.

**Remaining nits (LOW, non-blocking, no follow-up story warranted):** stale doc references after the renumbering/rename — `_pr_block_reason` cites "rule 4" (blocking is now rule 3), `_view_is_merged` cites "rules 1–3" (MERGED is now rule 2), and the test module header still names `PRVerdict` and claims a non-None `message` for UNREADABLE. Sweep opportunistically on the next touch of this module.

**Deviation audit (cycle 2):** four entries under `## Design Deviations`, all **ACCEPTED** — validation placement (correct: classification boundary, not fetch boundary), `_result_blob` as NamedTuple fields (correct: the return object *is* the blob), option-A rule order (correct, and it supersedes TEA's contract ordering for the right reason — behavior preservation was AC #1), `_PRVerdict` rename. Zero UNDOCUMENTED deviations this cycle.

**Handoff:** To SM for finish-story.

### Reviewer (code review, cycle 2)
- **Improvement** (non-blocking): The differential-characterization harness (import the pre-refactor module from the base branch via `importlib`, sweep both APIs over a generated input space, compare return value and exception identity) found the cycle-1 defect in seconds and proved the cycle-2 fix exhaustively. Worth promoting into the TEA guide as the required RED artifact for behavior-preserving-refactor stories — a 12-row hand-written matrix cannot cover multi-match input shapes, which is exactly where refactors of precedence logic break. Affects `pennyfarthing-dist/guides/` (TEA behavior-preserving-refactor guidance). *Found by Reviewer during code review.*