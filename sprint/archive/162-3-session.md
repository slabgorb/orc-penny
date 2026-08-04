---
story_id: "162-3"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-3: _view_is_merged case-folds PR state, loosening the boolean that authorises the done transition; pin or revert (from 155-32 review)

## Story Details
- **ID:** 162-3
- **Jira Key:** Jira: none
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-3-view-is-merged-case-fold
- **PR:** #170

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-04T19:39:19Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-04T19:19:47Z | 2026-08-04T19:20:40Z | 53s |
| red | 2026-08-04T19:20:40Z | 2026-08-04T19:26:40Z | 6m |
| green | 2026-08-04T19:26:40Z | 2026-08-04T19:29:09Z | 2m 29s |
| review | 2026-08-04T19:29:09Z | 2026-08-04T19:39:19Z | 10m 10s |
| finish | 2026-08-04T19:39:19Z | - | - |

## Sm Assessment

**Scope:** 1-pt p1 TDD story. `_view_is_merged` in `pennyfarthing-dist/src/pf/sprint/story_finish.py` (~228) applies `.upper()` to the gh PR `state` before comparing to "MERGED". gh's API emits uppercase; the case-fold silently widens the predicate. Since 162-1 this one boolean authorizes THREE decisions: the done transition (merge short-circuit ~658), the conflict-gate exemption in `_pr_block_reason` (~312), and post-merge re-verification. Story choice: pin deliberately or revert to strict.

**Direction (SM call, TEA/Dev may override with rationale logged as deviation):** REVERT to strict comparison (`state == "MERGED"`, no case-fold). Rationale: truthfulness epic — no known caller emits lowercase; gh's contract is uppercase; a widened authorization surface on the boolean that flips stories to done is risk without benefit. If TEA/Dev find a legitimate lowercase producer (e.g. a fake or a gh version), pin instead and document it.

**Technical approach for TEA:** Failing tests: (1) `state="merged"` (lowercase) must NOT be treated as merged — no short-circuit, no conflict-gate exemption, no done transition; (2) `state="MERGED"` still authorizes all three; (3) sweep for other case-folds on gh state fields in story_finish.py (`mergeable`/`mergeStateStatus` comparisons) and pin those too if in scope. Note 162-2's stateful fake in test_155_15 and 162-1's tests both touch this predicate — keep suites green.

**Acceptance criteria:**
1. Lowercase/mixed-case `state` values are not treated as MERGED anywhere the predicate is consulted.
2. Uppercase "MERGED" behavior unchanged across all three decision sites.
3. Sibling finish suites (155-1/12/15/29/31/32, 162-1) green on develop HEAD (fe19faf1c).

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## TEA Assessment

**Tests Required:** Yes
**Decision:** REVERT to strict equality — SM direction confirmed, no deviation. Producer sweep found no lowercase-state producer anywhere: the real probe is `gh pr view --json state,...` (uppercase enum), and every fake in the finish suites (155-1/12/15/29/31/32/33/40, 160-3, 162-1, 162-2) emits "MERGED"/"OPEN"/"CLOSED". The only lowercase "merged" literal in story_finish.py is `_branch_merge_status`'s own return vocabulary (~364), a separate namespace that never reaches `_view_is_merged`.

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py` — 49 tests, 28 RED / 21 green-on-arrival guards

**Decision sites covered (4, one class each):**
| Site | Source | Test class |
|------|--------|------------|
| predicate itself | `_view_is_merged` ~268 | `TestViewIsMergedRejectsNonCanonicalState` |
| conflict-gate exemption | `_pr_block_reason` ~312 (162-1) | `TestConflictGateExemptionRequiresCanonicalMerged` |
| merge short-circuit + done transition | `finish_story` ~658 (155-29) | `TestShortCircuitRequiresCanonicalMerged` |
| post-merge re-verification | `_pr_is_merged` ~284, consumed ~712 | `TestPostMergeVerificationRequiresCanonicalMerged` |
| dry-run preview | `finish_story` ~565 (155-31) | `TestDryRunPreviewRequiresCanonicalMerged` |

Each site is parametrized over four non-canonical spellings ("merged", "Merged", "MeRgEd", "mERGED") so a partial fix names the spelling that leaked. Control group ("OPEN", "CLOSED", "", "MERGE", "MERGEDX", None view, missing key, null state) is green on both sides — proves the RED failures come from the case-fold and not from the predicate collapsing to a constant, and pins that the fix stays an equality check rather than drifting into a prefix or substring test.

**Existing tests Dev must update: NONE.** Verified empirically, not by inspection: with the one-line strict comparison applied locally, the new file goes 49/49 and the full 155/160-3/162 selection stays at 392 passed. No test on HEAD asserts lowercase-is-accepted, so the reviewer's "lowercase passes" note on 162-1 described the implementation's tolerance, not a pinned assertion.

**Green-on-arrival over-reach guards** (must stay green — these are what a sloppy fix breaks):
- `TestConflictGateStillBlocksCanonicalMergeability` — uppercase CONFLICTING / DIRTY still hard-block for an OPEN PR (155-12), UNKNOWN still falls through (gh #113). Present because a Dev who sweeps all three `.upper()` calls at once would silently drop the conflict abort.
- `TestConflictGateExemptionRequiresCanonicalMerged::test_non_canonical_merged_with_clean_mergeability_still_passes` — tightening the exemption must not turn an unvouchable state into a block by itself.
- `test_canonical_merged_still_short_circuits`, `test_canonical_merged_still_previews_the_skip`, `test_canonical_state_passes_verification` — AC-2, all three uppercase paths unchanged.

**Guidance for Dev:** one-line change at ~268, compare the raw `state` to "MERGED". Do NOT add compensating leniency (no `.strip()`, no alias set, no prefix match). Keep the `view is None` → False guard and the missing-key → False behaviour — four call sites lean on "unknown reads as not merged". Do NOT touch the `mergeable` / `mergeStateStatus` case-folds (see finding below).

**Sibling suites:** 149 passed at HEAD across 155-1/12/15/29/31/32/33/34/40 and 162-1; 392 passed with the fix applied.

**Status:** RED (28 failing for the right reason — ready for Dev)
**Commit:** 80667b2e0, GPG signed (good signature, key 7B37E56D8E241397)
**Handoff:** To Dev for GREEN

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_view_is_merged` now compares the raw `state` value to "MERGED" instead of case-folding it. Docstring records that the strictness is deliberate: gh emits an uppercase enum, no producer emits lowercase, and this boolean authorizes the done transition, so any other spelling (including missing key or unreadable probe) reads as not-merged, which is the safe answer at all four call sites.

Net diff is one expression plus the docstring paragraph. No compensating leniency added (no `.strip()`, no alias set, no prefix match). The `view is None` guard and the missing-key → False behavior are preserved. The `mergeable` / `mergeStateStatus` case-folds at ~314-315 were NOT touched, per TEA's scope note — they feed a BLOCKING predicate, so de-folding them loosens a safety gate rather than tightening an authorization.

**Note on the coercion:** the old expression wrapped the value in `str(...)` before folding. The new one compares the raw value, so a non-string `state` (e.g. `None`, an int) is unequal to "MERGED" and reads as not-merged — same outcome the `str()` path produced for every non-canonical value, and the control-group cases (None state, missing key, empty string) are green. No deviation: TEA's guidance was to compare the raw `state`.

**Tests:** 49/49 passing in the story file (GREEN — was 28 RED / 21 guards). Full 155/160-3/162 family selection: 392 passed, matching TEA's predicted count exactly, so no sibling suite regressed and the over-reach guards (`TestConflictGateStillBlocksCanonicalMergeability` and the three AC-2 uppercase-path guards) are still green.

**Lint:** ruff check clean on the changed file. Pre-existing format drift left alone — not reformatted.

**Branch:** feat/162-3-view-is-merged-case-fold (pushed)
**Commit:** 8c717207f, GPG signed (good signature, key 7B37E56D8E241397)

**Handoff:** To Reviewer

## Subagent Results

| # | Subagent | Status | Findings | Confirmed | Note |
|---|----------|--------|----------|-----------|------|
| 1 | reviewer-preflight | Returned | 0 | — | 49/49 story file; 227 passed on its 12-file selection (178 on develop, delta exactly 49 — no regression); ruff check clean; ruff format drift present on develop too |
| 2 | reviewer-test-analyzer | Returned | 4 | 3 confirmed, 1 downgraded | Headline finding (over-reach guard is decorative) CONFIRMED by my own mutation probe |
| 3 | reviewer-type-design | Returned | 2 | 2 confirmed as deferred | Independently derived the same old-vs-new disagreement set I did; both findings are the known parsed-enum follow-up |
| 4 | reviewer-security | Returned | 2 | 2 confirmed PRE-EXISTING | Neither introduced by this diff; fail-closed at all consumers verified |
| 5 | reviewer-rule-checker | Returned | 0 | — | 13 checklist rules + 5 project rules, 56 instances, zero violations |
| — | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| — | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| — | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| — | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |

**All received: Yes** — all 5 enabled subagents returned results before any conclusion was written. The 4 rows marked Skipped are disabled via `workflow.reviewer_subagents` and do not block the gate.

**Challenged:** none of my VERIFIED items contradict a subagent finding. Where a subagent and I differ, it is recorded explicitly in the Dismissed paragraph below (reviewer-security's two findings are real but pre-existing; reviewer-test-analyzer's non-string-state gap is downgraded with the monotone-subset proof as rationale). reviewer-test-analyzer's headline finding was CONFIRMED by my own mutation probe rather than dismissed.

## Reviewer Assessment

**Verdict:** APPROVED

**Scope verification — all four decision sites are strict.** The predicate is a single choke point, so the one-line change at `story_finish.py` 275 covers every consumer; I confirmed by grep that no site re-derives merged-ness independently. Sites: predicate 275; conflict-gate exemption 319; dry-run preview parity 572; merge short-circuit / done transition 665; post-merge re-verification via `_pr_is_merged` 291, consumed at 719.

**Data flow traced:** `gh pr view --json state,mergeable,mergeStateStatus,baseRefName` stdout → `_run` (list-form argv, no shell) → `json.loads` → `isinstance` dict guard → `_view_is_merged` → five consumers. Safe because every consumer is fail-closed: False means "do not short-circuit", "do not exempt from the conflict gate", "preview the merge", and "refuse the done transition" respectively. There is no branch where False reaches a MORE permissive path, and a gh failure or unparseable payload degrades to None → False, never to merged.

**The tightening is monotone — this is the load-bearing safety property.** I derived the complete old-vs-new disagreement set independently and reviewer-type-design derived it separately to the same answer: new is a strict subset of old. Because `json.loads` can only yield str/int/float/bool/None/list/dict, and none of the non-str types ever satisfied the old expression either (str of None folds to NONE, str of True folds to TRUE, and so on), the disagreement set is exactly the case variants of merged — precisely the intended change. **This retires Dev's flagged second edge:** dropping the `str()` coercion has no observable effect. There is no input for which the new code returns True and the old returned False, so the change cannot widen any authorization. Dev's note was the right thing to flag and the wrong thing to worry about.

**Over-reach check passed.** The `mergeable` and `mergeStateStatus` folds at 321-322 are correctly untouched. They feed a BLOCKING predicate at 323, where folding biases toward blocking; de-folding would loosen a safety gate. This is the opposite risk profile from an authorizing predicate and the scope call is right.

**Cross-module consistency (positive observation):** `pf/preflight/finish.py` 193 already compared strictly. This story brings `story_finish.py` into line with its sibling rather than inventing a new convention — and 193's `mergedAt` corroboration is exactly what backlog 162-18 proposes to add here.

**Adversarial mutation battery (self-restoring, hash-verified; tree confirmed clean after).** I replaced the fixed expression with seven mutants and re-ran the story suite:

| Mutant | Result | Read |
|--------|--------|------|
| revert to the upper-fold | 28 failed | RED tests are genuinely red |
| casefold variant | 28 failed | equivalent to the fold |
| startswith on MERGE | 2 failed | prefix drift caught |
| substring containment | 1 failed | substring drift caught |
| constant False | 9 failed | AC-2 uppercase guards are real, not vacuous |
| constant True | 38 failed | predicate has not collapsed to a constant |
| **strip then compare** | **49 passed — NOT caught** | see finding R1 |

**Verified good:** TEA's producer sweep holds under spot-check. Every `pr_state` default across the finish suites is uppercase, and the only lowercase merged literal in the module is `_branch_merge_state`'s own return vocabulary at 371/429, consumed solely at 759 in the no-PR arm — a genuinely separate namespace that never reaches the predicate. Commit format conventional and both commits carry good GPG signatures. Format drift is not chargeable: tox gates only ruff check, and develop carries identical drift.

**Findings — three MEDIUM, none blocking.** All three are test-durability and documentation-accuracy issues around a fix whose shipped behavior I could not break. None is a correctness defect, so none meets the Critical/High bar.

| Severity | Issue | Location |
|----------|-------|----------|
| MEDIUM | R1 — docstring claims "no stripping" but no test pins it | `story_finish.py` 267 / test file 105-121 |
| MEDIUM | R2 — over-reach guard does not guard what its docstring claims | test file 437-443 |
| MEDIUM | R3 — fixture folds case when deriving `mergedAt`, a landmine for 162-18 | test file 208 |

**R1.** The new docstring enumerates three prohibitions — no case folding, no stripping, no aliases. Folding and aliasing are pinned (28 and 1-2 mutant failures). Stripping is not: a `.strip()` mutant passes all 49. Neither parametrize list carries a whitespace-padded spelling, so a future author can add `.strip()` leniency and stay green against a docstring that forbids it. Not reachable via gh, which emits a clean JSON enum, so this is regression-barrier durability rather than live risk. Adding a padded spelling to the control list closes it.

**R2.** reviewer-test-analyzer flagged `TestConflictGateStillBlocksCanonicalMergeability` as decorative, and my mutation probe CONFIRMS it: with both folds at 321-322 removed, the story suite stays 49/49 and the full family stays 392 passed. Zero tests fail. The class only ever feeds uppercase values, so the folds it claims to protect are no-ops on its own inputs. The class docstring's assertion that "a Dev who sweeps all three case-folds at once cannot silently drop the conflict abort" is therefore factually false, and TEA's session claim that the deferred fold is "guarded meanwhile" by this class does not hold. The class still has value — it pins that canonical values block after THIS change — but it does not provide the over-reach protection it advertises. This matters concretely because 162-18 and 162-19 will both touch this function expecting that guard to exist. One lowercase input pair makes it real.

**R3.** The fixture derives `mergedAt` with a case-fold, so a non-canonical spelling gets a populated merge timestamp — the fake vouches for a merge the test is asserting did not happen. Inert today because nothing reads `mergedAt`. It becomes an active false-pass generator the moment 162-18 lands `mergedAt` corroboration: every RED test in this file would pass for the wrong reason. Worth fixing as the first step of 162-18 rather than as rework here.

**Deviation audit:** Dev logged no deviations, and I found none. SM's direction (revert to strict) and TEA's guidance (raw comparison, keep the None and missing-key guards, leave the two folds alone, add no compensating leniency) were followed exactly. Dev's coercion note is correctly classified as a non-deviation — my analysis above shows it is not even a behavior change.

**Specialist incorporation:**
- **[TEST]** reviewer-test-analyzer returned 4 findings. Its headline — that the over-reach guard is decorative — I CONFIRMED by independent mutation probe and promoted to finding R2. Its `mergedAt` fixture fold became R3. Its missing `_merge_invoked` precondition assertion on the site-3 abort path is a fair point I fold into R2's remediation (the abort test would pass on an unrelated early exit). Its non-string-state gap is downgraded to non-finding per the monotone-subset proof. It also independently cleared the mock.patch targets, confirmed the RED tests are genuinely red on HEAD, and confirmed no shared mutable fixture state.
- **[TYPE]** reviewer-type-design returned 2 findings, both the known parsed-enum follow-up: `_pr_view` returns an unvalidated `dict[str, Any]` straight off `json.loads`, and `state` is a stringly-typed gh enum re-read at four sites. It derived the old-vs-new disagreement set independently and reached the identical conclusion I did — the change is a strict tightening with no real-input delta. It also ruled the fold asymmetry between the authorizing and blocking predicates deliberate and policy-correct. Both findings are deferred, already tracked as TEA's Improvement and backlog 162-19.
- **[SEC]** reviewer-security returned 2 findings, both explicitly PRE-EXISTING and untouched here. It verified argv is list-form with no shell interpolation at every gh and git call site, that the PR number is digits-only from a regex so there is no injection surface, that a gh failure can never read as merged, that all four consumers are fail-closed, and that the test file is fully hermetic — every subprocess call, plus the transition and completed-row writers, are patched, so no real repository can be mutated. No introduced security issue.
- **[RULE]** reviewer-rule-checker returned zero violations across all 13 python checklist rules plus 5 project rules, 56 instances examined. It confirmed the diff touches only `pennyfarthing-dist/` source paths and no symlinked runtime path, that both commits are conventionally formatted and GPG-signed, and that the bool-returning private predicate is a legitimate exception to the result-object rule since the public contract at `finish_story` is unchanged. Its only note — `Path.write_text` without an explicit encoding in test fixtures — is outside the rule's stated scope and concerns ASCII YAML; I agree it is not a finding.

**Dismissed:** reviewer-security's two findings (gh stderr surfaced verbatim, and the broad status-read catch) are both real but PRE-EXISTING and untouched by this diff — not chargeable here. reviewer-test-analyzer's non-string-state gap is downgraded to non-finding: the monotone-subset proof shows those cases cannot behave differently, so a test would document rather than protect.

**Handoff:** To SM for finish-story

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings. TEA's two findings (the remaining `mergeable`/`mergeStateStatus` case-folds, and the stringly-typed `state` field wanting a canonicalising reader at the `_pr_view` boundary) both held up during implementation and are the right follow-ups; nothing to add. *Found by Dev during implementation.*

### TEA (test design)
- **Gap** (non-blocking): `_pr_block_reason` also case-folds `mergeable` and `mergeStateStatus` (`story_finish.py` ~314-315) — the two remaining gh-enum case-folds after this story. Deliberately left OUT of scope: those feed a BLOCKING predicate, so de-folding them loosens a safety gate (a lowercase "conflicting" would stop aborting) rather than tightening an authorisation, which is the opposite risk profile from `state` and a separate decision. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (a follow-up story would drop both `.upper()` calls and decide whether an unrecognised `mergeable` value should block or fall through). Guarded meanwhile by `TestConflictGateStillBlocksCanonicalMergeability`, which pins that the canonical uppercase values still block. *Found by TEA during test design.*
- **Improvement** (non-blocking): all four decision sites read merged-ness off a stringly-typed `state` field, so every future consumer re-derives the same "which spellings count?" question that produced this bug. A parsed enum or a single canonicalising reader at the `_pr_view` boundary would make the answer unrepresentable-if-wrong instead of re-litigated per call site. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_pr_view` return type). Out of scope for a 1-pt revert. *Found by TEA during test design.*

### Reviewer (code review)
- **Gap** (non-blocking): the new docstring forbids stripping, but no test pins it — a `.strip()` mutant passes all 49. Neither parametrize list carries a whitespace-padded spelling. Affects `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py` (add a padded spelling such as a trailing-space MERGED to the control list, so the docstring's third prohibition is enforced rather than merely asserted). Folding and aliasing ARE pinned; only stripping is unguarded. Not reachable via gh, so this is regression-barrier durability, not live risk. *Found by Reviewer during code review.*
- **Conflict** (non-blocking): TEA's deferred-fold finding claims the remaining `mergeable`/`mergeStateStatus` folds are "guarded meanwhile" by `TestConflictGateStillBlocksCanonicalMergeability`. Verified false by mutation: removing both `.upper()` calls at `story_finish.py` 321-322 leaves the story suite at 49/49 and the full family at 392 passed — zero failures. The class feeds only uppercase values, so the folds are no-ops on its own inputs, and its docstring's over-reach claim does not hold. Affects `pennyfarthing-dist/src/pf/tests/test_162_3_view_is_merged_strict_state.py` 437-443 (add one lowercase input pair) and the de-fold follow-up story's premise, which must not assume an existing guard. Relevant to 162-18 and 162-19, both of which touch this function. *Found by Reviewer during code review.*
- **Gap** (non-blocking): the test fixture derives `mergedAt` with a case-fold (`test_162_3_view_is_merged_strict_state.py` 208), so a non-canonical spelling receives a populated merge timestamp — the fake vouches for a merge the test asserts did not happen. Inert today because no production code reads `mergedAt`. Affects the same test file, and becomes an active false-pass generator the moment backlog 162-18 lands `mergedAt` corroboration: every RED test in the file would then pass for the wrong reason. Best fixed as the first step of 162-18. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): corroborating the type-design sweep — `pf/preflight/finish.py` 193 already compared PR state strictly AND corroborated with `mergedAt`. This story aligns `story_finish.py` with that sibling, and 193 is a working precedent for the 162-18 design. Affects `pennyfarthing-dist/src/pf/preflight/finish.py` (reference implementation, no change needed). *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 1 findings (0 Gap, 0 Conflict, 0 Question, 1 Improvement)
**Blocking:** None

- **Improvement:** corroborating the type-design sweep — `pf/preflight/finish.py` 193 already compared PR state strictly AND corroborated with `mergedAt`. This story aligns `story_finish.py` with that sibling, and 193 is a working precedent for the 162-18 design. Affects `pennyfarthing-dist/src/pf/preflight/finish.py`.

### Downstream Effects

- **`pennyfarthing-dist/src/pf/preflight`** — 1 finding

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec. SM's direction (revert to strict), TEA's guidance (one-line raw comparison, keep the None and missing-key guards, leave the `mergeable`/`mergeStateStatus` folds alone) were followed exactly.