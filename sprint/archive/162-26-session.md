---
story_id: "162-26"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-26: Ref-qualified Branch values (origin/x, refs/heads/x) double-prefix in _branch_merge_state and abort where the old bare probe verified — fails closed but needs design: strip-prefix is UNSOUND (collides with the look-alike-branch threat 162-4 defends against); consider candidate widening or rejection at the extractor. Also document the base field's dual shape at story_finish.py:371 (prefixed on definitive arms, bare on not-found arms) (from 162-4 review)

## Story Details
- **ID:** 162-26
- **Jira Key:** (none — Jira integration disabled)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-26-ref-qualified-branch-values-merge-state
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the story title is the full spec. Two deliverables: (A) fix the ref-qualified-Branch double-prefix abort in `_branch_merge_state`; (B) document the `base` field's dual shape at the relevant site (title cites `story_finish.py:371`; line has drifted — find the arm that returns `base` prefixed on definitive answers vs bare on not-found).

**Defect (confirmed by SM):** `pennyfarthing-dist/src/pf/sprint/story_finish.py`, `_branch_merge_state` (~line 781). It builds candidates as `f"refs/heads/{branch}"` and `f"refs/remotes/{remote}/{branch}"` (line ~857). When `branch` arrives **already ref-qualified** (`origin/x`, `refs/heads/x`), the candidate becomes `refs/heads/origin/x` / `refs/remotes/origin/refs/heads/x` → neither resolves → the probe aborts (`unmerged`/`unknown`) where the OLD bare probe would have verified. False-abort on a done story.

**Why the obvious fix is wrong:** naive strip-prefix (`origin/x` → `x`) is **UNSOUND** — 162-4 defends against a real look-alike branch created by the `git checkout -b origin/x` typo. A literal branch *named* `origin/x` lives at `refs/heads/origin/x`; stripping the prefix would make it collide with the intended `x` and could answer `merged` for unlanded work. The full-ref-candidate invariant (162-4, documented in the docstring lines 821-830) must be preserved — every candidate stays a FULL ref path; a bare name is never passed to git.

**Design decision (SM recommendation — Dev owns the final call, Reviewer scrutinizes soundness):** prefer **candidate widening at `_branch_merge_state`** over stripping. When `branch` is ref-qualified, ADD the correctly-interpreted full-ref candidate (e.g. `origin/x` → also probe `refs/remotes/origin/x`; `refs/heads/x` → probe it directly) WHILE STILL probing the literal-name candidates (`refs/heads/origin/x`) so the 162-4 look-alike branch remains resolvable and distinct. All candidates remain full refs → soundness preserved, no bare name reaches git, no collision. The alternative — **rejection/canonicalization at the extractor** (reject ref-qualified Branch values where they are produced, keeping stored Branch bare) — is also acceptable IF Dev can prove every producer is covered; widening is safer because it is local and cannot be bypassed by a new producer. Whichever is chosen, the fix must NOT reintroduce the bare-name or DWIM shadow risks 162-4 closed.

**TEA (RED):** write failing tests driving `_branch_merge_state` directly (fake `_run` — the hermetic seam) with ref-qualified `branch` inputs (`origin/<name>`, `refs/heads/<name>`) that today double-prefix and abort, asserting the correct merged/unmerged verdict. Include a REGRESSION test that a literal look-alike branch `refs/heads/origin/x` is still resolved distinctly (162-4 must stay green — do not let the fix answer `merged` for the look-alike). Also pin the `base` dual-shape (prefixed on definitive arms, bare on not-found) so the documentation change is anchored.

**Constraints (binding):** scoped runs only — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/<finish-tests>.py -q`; NEVER full suite. `_run` is THE seam — fake it, pass explicit `cwd`/`repo_path`. `ruff check` changed files. Result objects `{success,...}`, no throws. Preserve every 162-4 / 162-25 invariant in the docstring.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T12:39:10Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T12:18:10+00:00 | 2026-08-11T12:19:19Z | 1m 9s |
| red | 2026-08-11T12:19:19Z | 2026-08-11T12:24:59Z | 5m 40s |
| green | 2026-08-11T12:24:59Z | 2026-08-11T12:29:26Z | 4m 27s |
| review | 2026-08-11T12:29:26Z | 2026-08-11T12:39:10Z | 9m 44s |
| finish | 2026-08-11T12:39:10Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): the SM Assessment's premise that `refs/heads/x` double-prefixes is **wrong** — `_classify_branch_name` (162-25) refuses any value whose first path component is `refs` *before* the candidate loop, so it already returns `unknown` with the correct actionable "not a valid branch name" reason and emits ZERO git. Only the **remote-qualified** form (`origin/x`) reaches the loop and double-prefixes. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_branch_merge_state` — deliverable (A) shrinks to the remote-qualified case; do NOT widen `refs/`-prefixed values, that would delete a 162-25 invariant). *Found by TEA during test design.*
- **Question** (non-blocking): cross-remote form — `origin/x` declared in a repo whose configured remote is `upstream`. Widening to `refs/remotes/origin/x` is sound (still a full ref) but is not pinned; Dev's call. Affects `_branch_merge_state`. *Found by TEA during test design.*
- **Improvement** (non-blocking): the `base` field's dual shape is now pinned on 9 arms, and the docstring's "``count``/``base`` on a definitive answer" line does not say that `base` is the winning FULL ref on definitive/post-resolution arms but the BARE declared value on every pre-resolution arm. That is deliverable (B)'s exact wording target. Affects `story_finish.py` `_branch_merge_state` docstring. *Found by TEA during test design.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **`refs/heads/x` pinned GREEN as a regression, not written RED:** SM Assessment said both `origin/x` and `refs/heads/x` double-prefix and asked for RED coverage of both. Verified against the code: `refs/`-prefixed values never reach the candidate loop (162-25 name gate refuses them in-process, zero subprocesses). Writing a RED test asserting `merged` for `refs/heads/x` would order Dev to DELETE the 162-25 invariant and reintroduce the `refs/heads/refs/heads/x` confusion. Reason: soundness beats literal compliance — it is pinned as AC-4 (green-on-arrival) instead, so the fix cannot "helpfully" resolve it.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_26_ref_qualified_branch_merge_state.py` — drives `_branch_merge_state` directly over a faked `_run` seam (`FakeGit` routes argv → per-ref rc/stdout); `repo_path`/`base`/`remote` always explicit, every faked call asserted to carry `cwd=str(repo_path)` (`_assert_cwd_pinned`). No chdir, no real repo, no config resolution.

**Tests Written:** 21 tests covering 5 ACs — **3 RED**, 18 green-on-arrival regression pins.
**Status:** RED (3 failing — ready for Dev)

**Scoped run:** `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_26_ref_qualified_branch_merge_state.py -q` → `3 failed, 18 passed in 0.20s`. `ruff check` clean.

### RED (must go green — deliverable A)
`TestRemoteQualifiedBranchClassifies`:
1. `test_remote_qualified_merged_branch_reads_merged`
   `AssertionError: remote-qualified 'origin/feat-x' must classify, got {'state': 'unknown', 'base': 'develop', 'reason': 'branch not found locally or on origin'}`
2. `test_remote_qualified_unmerged_branch_reads_unmerged_with_true_count`
   `AssertionError: expected unmerged, got {'state': 'unknown', 'base': 'develop', 'reason': 'branch not found locally or on origin'}`
3. `test_widening_uses_the_configured_remote_not_hardcoded_origin`
   `AssertionError: expected merged, got {'state': 'unknown', 'base': 'develop', 'reason': 'branch not found locally or on upstream'}`

All three fail on the DOUBLE-PREFIX ABORT (`refs/heads/origin/feat-x` + `refs/remotes/origin/origin/feat-x` both rc=1 → not-found), not on a fixture error — the fake answers rc=0 for the correctly-interpreted `refs/remotes/<remote>/feat-x`, which today is never probed.

### 162-4 LOOK-ALIKE GUARD (the invariant the fix must not break)
**`TestLookAlikeBranchStaysDistinct::test_literal_lookalike_wins_over_widened_candidate_and_is_not_merged`** is the guard. Both refs exist: `refs/heads/origin/feat-x` (the `git checkout -b origin/x` typo branch, 2 unlanded commits) and `refs/remotes/origin/feat-x` (merged, count 0). It asserts `state != "merged"`, `state == "unmerged"`, `count == 2`, and that the single `rev-list` range is `refs/remotes/origin/develop..refs/heads/origin/feat-x` with `probed_refs()[0] == refs/heads/origin/feat-x`.
- A **naive strip-prefix** implementation FAILS it (resolves the remote-tracking ref → false `merged` on unlanded work).
- A **widening** implementation that probes the widened candidate BEFORE the literal one also FAILS it.
- Companion: `test_lookalike_alone_still_resolves_rather_than_reading_missing`.

### Other green-on-arrival pins
- `TestRefsPrefixedValuesStayRefused` (4): 162-25 gate — `refs/heads/x`, `refs/remotes/origin/x`, `refs/tags/v1.0` stay `unknown` + "not a valid branch name" quoting the value, no `count`; and zero subprocesses.
- `TestBaseFieldDualShape` (9): **anchors deliverable (B)** — `base` is the winning FULL ref on post-resolution arms (`refs/remotes/origin/develop`, local fallback `refs/heads/develop`, rev-list rc!=0, unparseable stdout) and the BARE declared value on pre-resolution arms (branch-not-found, base-not-found, name-gate refusal, refused base value, remote-qualified not-found).
- `TestSeamFidelity` (3): no candidate may double-prefix a `refs/` path; the canonical bare branch case is byte-identical (`{"state": "merged", "count": 0, "base": "refs/remotes/origin/develop"}`) with `refs/heads/feat-x` probed first; every candidate starts with `refs/heads/` or `refs/remotes/` (162-4 core).

**Commit:** `cb76e92d3` (signed, verified `G`) on `feat/162-26-ref-qualified-branch-values-merge-state`.

**Handoff:** To Dev for implementation
### Dev (implementation)
- **Cross-remote form resolved as NOT widened:** TEA left it unpinned (Dev's call). Widening keys off the CONFIGURED remote only — `origin/x` in a repo whose remote is `upstream` stays not-found (a loud abort, same as any unresolvable branch) rather than probing `refs/remotes/origin/x`. Reason: a value qualified with a remote this repo does not use is a typo, not an intent, and the not-found arm already gives the operator an actionable reason. Widening it would only guess.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` — (A) `_branch_merge_state` builds its branch candidates into a list and, when `branch` is remote-qualified (`<configured-remote>/<name>`), APPENDS the correctly-interpreted `refs/remotes/<remote>/<name>`; (B) docstring now documents the `base` field's dual shape.

**Design choice (widening, not stripping):** the widened candidate is appended AFTER the two literal candidates, so `refs/heads/<remote>/<name>` keeps first-probe priority. That is what preserves 162-4: a real look-alike branch from the `git checkout -b origin/x` typo still wins resolution and is counted for its OWN commits, so its unlanded work can never be answered for by the merged remote-tracking ref. Every candidate remains a FULL ref path — no bare name reaches git's argv, no DWIM shadow, and the winning candidate is still the rev-list range endpoint. Keyed off the configured `remote` (162-6), never a hardcoded `origin`. `refs/`-prefixed values are NOT widened: the 162-25 name gate refuses them before the candidate loop, at zero subprocess cost, and that invariant is untouched.

**Tests:** 21/21 passing (GREEN) — the 3 RED tests now pass, all 18 green-on-arrival pins held.
- **162-4 look-alike guard PASSED:** `test_literal_lookalike_wins_over_widened_candidate_and_is_not_merged` — `unmerged`, count 2, single rev-list range ending at `refs/heads/origin/feat-x`, literal probed first.
- **162-25 refusal PASSED:** `TestRefsPrefixedValuesStayRefused` (4) — still `unknown` + "not a valid branch name", zero subprocesses.
- Regression batch: 242/242 passing across `test_162_4_*`, `test_162_25_*`, `test_162_6_*`, `test_162_9_*`, `test_162_48_*`, `test_162_10_*`.
- `ruff check` clean on the changed file.

**Branch:** `feat/162-26-ref-qualified-branch-values-merge-state` (pushed)
**Commit:** `ff6abe24d` (signed, verified `G`)

**Handoff:** To Reviewer
### Reviewer (code review)
- **Improvement** (non-blocking): `_git_cleanup`'s branch-delete (`git branch -d -- <branch>`) targets a LOCAL branch, but 162-26 makes `merged` newly reachable via the widened REMOTE-tracking ref — a case where `refs/heads/<remote>/<name>` provably does not exist. The delete is then a guaranteed no-op whose rc!=0 is swallowed (only `checkout` failures and timeouts stop the chain). Not destructive and not introduced here, but the step-6 report reads clean for a cleanup that did nothing. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` `_git_cleanup` (cleanup loop ~1065) — consider a warning when `git branch -d` fails. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the `if widened not in candidates` dedupe guard is provably dead — the stripped suffix is strictly shorter than `branch`, so `widened` can never equal either literal candidate. Affects `story_finish.py:886`. *Found by Reviewer during code review.*

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
| 1 | reviewer-preflight | Yes | clean | 21/21 scoped GREEN, 162-4 (19) + 162-25 (46) no regression, ruff clean, 0 TODOs/skips | N/A |
| 2 | reviewer-rule-checker | Yes | clean | 0 violations across 5 rules / 18 instances (result objects, dist-not-symlink, `_run` cwd seam, FULL-ref invariant, scoped runs) | N/A |
| 3 | reviewer-security | Yes | clean | 0 findings; notes `remote` is not `_classify_remote_name`-validated inside `_branch_merge_state` (not exploitable) | 1 CONFIRMED as [LOW] defense-in-depth, pre-existing |
| 4 | reviewer-test-analyzer | Yes | findings | 3: stale docstring + dropped post-fix assertion; timeout arms unexercised in this file; zero-subprocess pin only on one variant | 1 CONFIRMED [MEDIUM], 2 CONFIRMED [LOW] (1 partially dismissed) |
| 5 | reviewer-type-design | Yes | findings | 3: stringly-typed BranchName-vs-RefPath, dual-shape `base` in `dict[str, Any]`, load-bearing `base` read at :1653 | 2 CONFIRMED [LOW] as deferred debt, 1 dismissed |

**All received: Yes** — 5 of 5 enabled specialists returned. No subagent errored or timed out. Every finding above was independently confirmed or dismissed against the code by the Reviewer; no specialist finding was accepted on assertion alone.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** session `Branch:` field -> `finish_story` no-PR arm (:1619) -> `_branch_merge_state(repo_path, branch, base=repo_config.default_branch, remote=repo_config.remote_name)` -> `_classify_branch_name` gate (refs/-prefix, dash-leading, control chars, `check-ref-format`) -> candidate list -> `git rev-parse --verify --quiet <candidate>` -> winning candidate is the rev-list range endpoint -> merged/unmerged. Safe because every candidate is built by an f-string that structurally begins `refs/heads/` or `refs/remotes/`; the widened value is a SUFFIX of an already-validated name re-prefixed, so no bare name — and therefore no dash-leading argv token and no DWIM tag/look-alike shadow — can reach git.

**Soundness rulings (the whole story):**
1. **162-4 look-alike invariant: HOLDS, and provably.** `candidates` is `[refs/heads/<branch>, refs/remotes/<remote>/<branch>]` with the widened ref `append`ed last (:887), so the literal interpretation keeps first-probe priority and `break`s. `branch_ref` is the winning candidate and is the sole rev-list endpoint (:928) — there is no shadow fallback. Adversarial case constructed and confirmed: both refs exist, remote-tracking merged (count 0), typo branch 2 unlanded -> `unmerged`, count 2, single range `refs/remotes/origin/develop..refs/heads/origin/feat-x`. Second-order case also correct: a PUSHED typo branch (`refs/remotes/<remote>/<remote>/<name>`, which is what pushing the typo actually creates) is candidate[1] and still outranks the widened ref — the literal interpretation wins at both local and remote tiers.
2. **162-25 refusal: UNTOUCHED, zero-cost.** The name gate runs at :862 and returns before `candidates` is ever built; widening is unreachable for `refs/`-prefixed values. Pinned by `TestRefsPrefixedValuesStayRefused` including `fake.calls == []`.
3. **Configured remote (162-6): CORRECT.** `qualifier = f"{remote}/"` keys off the threaded `remote` (normalized `(remote or "").strip() or "origin"`), never a literal `origin`. Verified with `remote="upstream"`; origin repos byte-identical (`test_bare_canonical_branch_is_unaffected` pins the exact dict and probe order).
4. **Full-ref invariant: STRUCTURALLY GUARANTEED**, not merely tested. Empty-suffix guard (`branch[len(qualifier):]` truthiness) correctly declines to widen a bare `<remote>/`.
5. **Cross-remote (`origin/x` in an `upstream` repo): Dev's non-widening decision UPHELD as sound.** Dev's stated rationale ("a foreign remote qualifier is a typo") is the weaker argument; the decisive one is range coherence — the base ref resolves under `refs/remotes/upstream/<base>`, so widening to `refs/remotes/origin/<name>` would count `refs/remotes/upstream/develop..refs/remotes/origin/x`, comparing across two different upstreams and able to answer `merged` for work that never landed in the configured integration remote. Not widening fails CLOSED with an actionable reason naming the remote actually probed. Correct call, not a gap.

**Pattern observed:** append-not-prepend candidate widening with the winning candidate carried through as the range endpoint — `story_finish.py:865-895` + `:928`. The ordering IS the security property, and the comment at :867-880 says so at the point of risk.

**Error handling:** result objects throughout, no throws; `_timed_out` checked on every probe with `timeout` kept distinct from `unknown` (:900, :915, :930); not-found and unparseable-output arms both return `unknown`, which the no-PR arm treats as abort (rule #1: unknown is not merged). Null/empty inputs: `base or _resolve_base_branch`, `(remote or "").strip() or "origin"`, empty-suffix guard.

**Test verification (my own run):**
- `test_162_26_ref_qualified_branch_merge_state.py` -> **21 passed** in 0.17s.
- Regression: `test_162_4_* test_162_25_* test_162_6_* test_162_9_* test_162_26_*` -> **118 passed**.
- `ruff check` on both changed files -> clean.
- **Mutation proof (the guard has teeth):** changed `candidates.append(widened)` to `candidates.insert(0, widened)`. Result: **2 failed** — `test_literal_lookalike_wins_over_widened_candidate_and_is_not_merged` and `test_every_candidate...`/`test_todays_candidates_are_the_double_prefixed_pair` (`assert 'refs/heads/origin/feat-x' in ['refs/remotes/origin/feat-x', ...]`). The 162-4 guard is load-bearing, not decorative. Source restored, tree clean.

**Findings (all non-blocking):**
| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [LOW] | Stale test docstring: `test_todays_candidates_are_the_double_prefixed_pair` still claims "the correctly-interpreted ref is (today) NOT [probed]" and instructs Dev to update it post-fix; the claim is now false and the name misdescribes the test. Its assertions are correct and load-bearing (mutation-proven), so this is documentation drift on a guard test. | `src/pf/tests/test_162_26_ref_qualified_branch_merge_state.py:520-531` | Rename/reword to state what it now guards: literal-first probe order + no `refs/heads/refs/` double-prefix. |
| [LOW] | Dead dedupe guard: `if widened not in candidates` can never be False (the stripped suffix is strictly shorter than `branch`, so `widened` differs from both literals). | `story_finish.py:886` | Drop the guard, or keep with a comment saying it is belt-and-braces. |
| [LOW] | Docstring line-wrap artifact from the insertion: "All probes route / through ``_run``" wraps mid-phrase. | `story_finish.py:812-813` | Reflow. |
| [LOW] | Step-6 cleanup delete silently no-ops on the newly-reachable widened-merged path (see Delivery Findings). | `story_finish.py` `_git_cleanup` ~1065 | Follow-up story, not this one. |
| [MEDIUM] | **[TEST]** `test_todays_candidates_are_the_double_prefixed_pair` was supposed to flip its second assertion post-fix (its own docstring instructs Dev to) and instead the assertion was DROPPED. Nothing in that test verifies the widened candidate is present — it passes with or without the widening code. The stale "the correctly-interpreted ref is (today) NOT [probed]" claim is now factually false. Confirmed by reviewer-test-analyzer and independently by reviewer-rule-checker. Non-blocking only because AC-1/AC-2/AC-3 pin the real behavior with teeth (mutation-proven). | `test_162_26_ref_qualified_branch_merge_state.py:519-531` | Add `assert REMOTE_TRACKING_REF in probed` (after the literal) and reword the docstring to describe what it now guards. |
| [LOW] | **[TEST]** All four `timeout` arms are structurally unreachable in this file: `_timed_out` is an `isinstance(_, _TimedOutProcess)` check and `FakeGit` only ever returns a plain `CompletedProcess`. PARTIALLY DISMISSED — timeout behavior is owned by `test_162_9_finish_subprocess_timeouts.py` (passing in my run), so this is a scope boundary, not a coverage hole; but the `base` dual-shape for the rev-list-timeout arm (full ref) is then unpinned anywhere in the AC-5 set. | `test_162_26_...py:150` (FakeGit) | Optional: one rev-list-timeout test to complete the AC-5 dual-shape matrix. |
| [LOW] | **[TEST]** The zero-subprocess guarantee (162-25 AC-3) is asserted only for `refs/heads/<name>`; the `refs/remotes/` and `refs/tags/` variants are pinned for verdict/reason but not for subprocess count. | `test_162_26_...py:412` | Parametrize over the same three values as its sibling. |
| [LOW] | **[SEC]** `_branch_merge_state` validates `branch` and `base` via `_classify_branch_name` but never validates `remote`, unlike `_git_cleanup` which gates it through `_classify_remote_name` (162-48 F2). 162-26 makes `remote` newly load-bearing (it forms the `qualifier`). CONFIRMED as defense-in-depth only, NOT exploitable: `subprocess` is called with a list (no shell), and the widened candidate is structurally locked to a `refs/remotes/` prefix, so a hostile `remote_name: origin/evil` yields an unresolvable full ref — no injection, no false `merged`. Pre-existing (162-6), not introduced here. | `story_finish.py:854` | Follow-up: mirror `_git_cleanup`'s remote gate on the read path. |
| [LOW] | **[TYPE]** The result's `base` key is two incompatible types under one `dict[str, Any]`: a resolved `RefPath` on post-resolution arms, a bare declared `BranchName` on pre-resolution arms. This story documents the ambiguity rather than fixing it. VERIFIED SAFE TODAY at both call sites — the dry-run caller (:1282) never reads `base`; the real-run caller reads it only on the `merged` (:1635) and `unmerged` (:1653) arms, both post-resolution. Documenting was the right call for this story's scope, but a discriminated `TypedDict` union (or splitting into `base_ref`/`base_name`) is the real fix. | `story_finish.py:781` | Follow-up story — do not expand 162-26's scope. |
| [LOW] | **[TYPE]** The 162-4 full-ref invariant — the security property of this whole function — is enforced by f-string convention and prose, not by types. `BranchName`/`RefPath` `NewType`s would make the widening a single checked coercion instead of an implicit convention. | `story_finish.py:865-895` | Follow-up; noted as epic-level debt. |
| [DISMISSED] | **[TYPE]** "load-bearing `merge_state['base']` read at :1653 could embed a bare name if a future arm violates the invariant" — hypothetical about code that does not exist; the invariant is now documented and test-pinned on 9 arms. No action. | `story_finish.py:1653` | None. |
| [RULE] | reviewer-rule-checker returned **0 violations** across all 5 applicable project rules (18 instances). Independently confirmed: every candidate is an f-string structurally prefixed `refs/heads/`/`refs/remotes/`; every `_run` carries explicit `cwd`; all arms return result objects; edits are in `pennyfarthing-dist/`, not the `.pennyfarthing/` symlinks. | — | None. |

**Deviation audit:**
- **TEA — `refs/heads/x` pinned GREEN rather than written RED: ACCEPTED.** TEA read the code over the SM Assessment and was right: the 162-25 gate refuses `refs/`-prefixed values before the candidate loop. Writing that RED would have ordered Dev to delete a live security invariant. Correct call, correctly logged.
- **Dev — cross-remote form not widened: ACCEPTED** with a stronger rationale supplied above (range coherence across remotes).
- **UNDOCUMENTED deviations:** none found. Both deliverables (A fix, B docstring) are present and the (B) wording matches the code on all arms I checked, including the rev-list timeout arm (`base_ref`, full) versus the base-probe timeout arm (bare) — the docstring's "before a base ref resolves" split is truthful.

**Handoff:** To SM for finish-story