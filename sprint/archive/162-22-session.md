---
story_id: "162-22"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-22: Port the 162-2 stateful gh-pr-merge fake to test_155_1_finish_verifies_merge.py:489 — its clean-merge happy-path test uses a fixed MERGED view, trips the 155-29 short-circuit, and never invokes gh pr merge (ironic: 155-1 made the merge load-bearing) (from 162-2 review)

## Story Details
- **ID:** 162-22
- **Jira Key:** (not used — Jira disabled for this project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-22-port-stateful-ghpr-fake-to-155-1
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the story title is the full spec (test-hardening bug, no separate ACs).

**Defect:** in `pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py`, the clean-merge happy-path test (~line 489) stubs a **fixed `MERGED` PR view**. Because 155-29 added a short-circuit that treats an already-`MERGED` view as done, the test never drives the `gh pr merge` code path — even though 155-1's whole point was to make the merge load-bearing. The test is therefore vacuous for the behavior it claims to verify.

**Fix shape:** replace the fixed-MERGED stub with the shared **stateful** `GhPrFake` (from `test_162_23_gh_pr_fake.py`, landed by 162-23): the fake reports the PR as NOT-merged until `gh pr merge` is actually invoked, then flips to MERGED. This forces the happy path to genuinely call merge; assert the merge invocation happened (not just the final state). Do NOT trip the 155-29 short-circuit.

**TEA (RED):** rewrite the happy-path test to use the stateful `GhPrFake` and assert `gh pr merge` was invoked. Demonstrate the *old* fixed-MERGED form was vacuous (short-circuits, merge never called) and the new form fails if merge isn't invoked. If the production finish code already invokes merge correctly, the hardened test will pass once ported — that's fine; the deliverable is the non-vacuous test. If it exposes a real finish-path gap, log it for Dev.

**Constraints (binding):** reuse the shared `GhPrFake` (don't fork a new fake — 162-23 consolidated them). Scoped runs only: `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_155_1_finish_verifies_merge.py -q`; NEVER the full suite. `ruff check` changed files. Return objects `{success,...}` not throws.

## TEA Assessment

**Tests Required:** Yes
**Outcome:** Hardened test **PASSES** — pure test hardening, no production bug. Dev's GREEN phase is a no-op verification.

**Test File:** `pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py`

**Tests changed/added (class `TestFinishSuccessPathUnchanged`):**
- `test_clean_merge_marks_done_and_removes_session` — rewritten: binds the stateful shared `GhPrFake(merge_rc=0, pr_state="MERGED", pre_merge_state="OPEN")`, asserts `len(fake.merge_calls) == 1` and that the merge targeted PR `#288`, then the pre-existing done/session assertions. `pre_merge_state` is pinned explicitly (not inherited from the fake's default) so a future default change cannot silently re-arm the 155-29 short-circuit.
- `test_fixed_merged_view_short_circuits_and_never_merges` — NEW vacuity sentinel: with `pre_merge_state="MERGED"` finish succeeds with `merge_calls == []`, pinning *why* a fixed-MERGED stub can never stand in for a clean merge.

**Reuse:** shared `GhPrFake` from `pf.tests.helpers.gh_pr_fake` (landed by 162-23). No new fake forked. The file was already importing `GhPrFake` post-162-23, but the happy path still passed no `pre_merge_state` and made **no merge-invocation assertion**.

**Merge-invocation evidence (scratch probe, `finish_story` under each fake):**
- OLD fixed-MERGED view: `success=True`, `merge_calls=[]` — vacuous; passed without ever merging.
- NEW stateful view: `success=True`, `merge_calls=[['gh','pr','merge','288','--squash','--delete-branch']]` — merge genuinely exercised.

**Mutation/sensitivity proof:** temporarily replaced the production `gh pr merge` invocation in `story_finish.py:1461` with a `gh pr view`. Result: `test_clean_merge_marks_done_and_removes_session` FAILED (`assert 0 == 1`, ledger empty). Pre-hardening that mutation left the happy path green. Production file restored (verified clean via `git status`).

**Scoped run:** `uv run pytest src/pf/tests/test_155_1_finish_verifies_merge.py -q` → 11 passed. `ruff check` → clean. Full suite never run.

**Handoff:** To Dev (GREEN = no-op verification; nothing to implement).

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T12:14:54Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T12:00:41.083944+00:00 | 2026-08-11T12:02:51Z | 2m 9s |
| red | 2026-08-11T12:02:51Z | 2026-08-11T12:06:15Z | 3m 24s |
| green | 2026-08-11T12:06:15Z | 2026-08-11T12:08:16Z | 2m 1s |
| review | 2026-08-11T12:08:16Z | 2026-08-11T12:14:54Z | 6m 38s |
| finish | 2026-08-11T12:14:54Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): 162-23's mechanical migration to `GhPrFake` fixed the *statefulness* of this happy path (default `pre_merge_state="OPEN"`) but left it with **no merge-invocation assertion** — it still passed under a mutation that deletes the `gh pr merge` call. Sibling files migrated by 162-23 (`test_155_12`, `test_155_15`, `test_162_1`) may carry the same latent hole: stateful fake, no ledger assertion. Affects `pennyfarthing-dist/src/pf/tests/test_155_*.py`, `test_162_1*.py` (audit each happy path for a `merge_calls` assertion). *Found by TEA during test design.*
- **Improvement** (non-blocking): `pre_merge_state` defaulting to `"OPEN"` means correctness of every clean-merge test depends on a helper default. Consider making it a required argument, or adding a `GhPrFake` invariant check, so the 155-29 short-circuit cannot be re-armed by a default change. Affects `pennyfarthing-dist/src/pf/tests/helpers/gh_pr_fake.py`. *Found by TEA during test design.*

### Reviewer (code review)
- **Conflict** (non-blocking): TEA's mutation evidence does not reproduce. Deleting the `gh pr merge` argv at `story_finish.py:1461` fails the happy-path test on **both** the hardened and the `origin/develop` versions of `test_155_1_finish_verifies_merge.py` — the pre-existing test was mutation-sensitive via its `result["success"]` assertion, because 162-23 had already made the fake stateful. Affects the session record and any follow-up story derived from it (re-scope the sibling audit to "asserts invocation vs. only downstream state"). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): class docstring at `test_155_1_finish_verifies_merge.py:414` describes the pre-162-23 fixed-`MERGED` world as if it were the immediately prior state. Affects `pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py` (reword to name 162-23 explicitly). *Found by Reviewer during code review.*

## Dev Assessment

**GREEN Phase Status:** Verification-only — no production change needed.

**Test Execution:** Scoped run `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_155_1_finish_verifies_merge.py -q` → **11 passed** (verified 2026-08-11T12:06Z).

**Verification:** TEA's hardened test passes because production code at `story_finish.py:1461` already correctly invokes `gh pr merge`. The test now:
- Uses stateful `GhPrFake(pre_merge_state="OPEN")` to force the merge path (not the 155-29 short-circuit)
- Asserts `len(fake.merge_calls) == 1` — proving merge is exercised, not vacuous
- Includes sentinel test `test_fixed_merged_view_short_circuits_and_never_merges` pinning why fixed-MERGED would be a false negative

**No production changes made.** The finish path is correct; the test hardening is complete.

**ruff check:** Clean. **Commit:** 3cbd31b (TEA's hardened test) — no new commit needed.

## Subagent Results

**All received: Yes** (5 of 5 enabled specialists returned).

| # | Specialist | Received | Status | Findings | Decision |
| 1 | reviewer-preflight | Yes | clean | 11 passed, ruff clean, 0 skips/TODOs/console.log | N/A |
| 2 | reviewer-rule-checker | Yes | clean | 15 rules / 12 instances, 0 violations (correct source path, result-object asserts, patch-decorator order, index-after-len guard) | N/A |
| 3 | reviewer-security | Yes | clean | `_run` fully patched — no real `gh`/git/network escape; no injection, no secrets | N/A |
| 4 | reviewer-test-analyzer | Yes | findings | 1 medium-confidence: sentinel test patches `mock_transition` but never asserts it | CONFIRMED, downgraded to [LOW] — non-blocking |
| 5 | reviewer-type-design | Yes | findings | 3: `current_state: str` too wide (low), static-vs-stateful mode not type-discriminated (medium), `"288" in argv` forward-fragile (low) | 2 DEFERRED (out-of-scope file), 1 CONFIRMED [LOW] |

## Reviewer Assessment

**Verdict:** APPROVED (no Critical/High). Test-only diff, 1 file, +55/-4.

**My own runs (evidence):**
- Scoped run `uv run pytest src/pf/tests/test_155_1_finish_verifies_merge.py -q` → **11 passed**. `ruff check` → clean. Full suite never run.
- **Mutation proof (new test):** replaced production argv at `story_finish.py:1461` (`gh pr merge …` → `gh pr view`). `test_clean_merge_marks_done_and_removes_session` **FAILED** at line 445 (`0 == len([])`, empty `merge_calls`). Production file restored; `git status` clean.
- **Mutation proof (pre-hardening / develop version of the test):** same mutation, `origin/develop` copy of the file → the happy path **ALSO FAILED** (at old line 435, `result["success"] is True`). So the pre-existing test was *not* mutation-blind.

**Data flow traced:** `GhPrFake.__call__` → `story_finish._run` patch → `finish_story` step-2 auto-merge arm (`story_finish.py:1460-1463`) → `_landed` flips → subsequent `gh pr view` reports `MERGED` → verify-merge passes → transition/session removal. Ledger `merge_calls` is the only assertion that observes the invocation itself rather than its downstream state.

**Pattern observed:** correct reuse of the 162-23 consolidated helper — `from pf.tests.helpers.gh_pr_fake import GhPrFake` (no forked fake), and `pre_merge_state` pinned explicitly at `test_155_1_finish_verifies_merge.py:441` so the helper default can't silently re-arm the 155-29 short-circuit. `"288" in fake.merge_calls[0]` is exact list-element membership (not a substring trap) — argv element is the literal PR number.

**Sentinel test:** `test_fixed_merged_view_short_circuits_and_never_merges` is non-tautological — it drives real production code through the 155-29 pre-check and pins `merge_calls == []`; it flips if the short-circuit is ever removed.

**Findings (all non-blocking):**

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] | TEA's recorded mutation evidence ("Pre-hardening that mutation left the happy path green") does not reproduce. On `origin/develop` the happy path already used the stateful `GhPrFake` (default `pre_merge_state="OPEN"`), did **not** trip the 155-29 short-circuit, and **failed** under the merge-deletion mutation via the `result["success"]` assertion. The residual gap this story closes is narrower than claimed: it adds a *direct invocation* assertion instead of relying on the downstream verify-merge state check. | session file, TEA Assessment | Correct the record; no code change. |
| [MEDIUM] | Stale/misleading docstring: the class docstring at `test_155_1_finish_verifies_merge.py:414-421` says "this class's happy path used to stub a **fixed `MERGED`** PR view … the test passed while asserting nothing about the merge". As of the immediately preceding commit that was false (162-23 had already made it stateful). The comment describes the pre-162-23 world without saying so. | `pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py:414` | Reword to "before 162-23 …" / "still asserted nothing about the merge invocation" in a follow-up. |
| [LOW] | Merge-ledger assertions run before `assert result["success"] is True`, so a production failure surfaces as a confusing `merge_calls` diff rather than the actual error payload. | `test_155_1_finish_verifies_merge.py:443-452` | Optional reorder; cosmetic. |
| [LOW] [TEST] | Sentinel test asserts only `success` and `merge_calls == []`; it patches `transition_story` but never asserts it, and does not pin the `already_merged: True` step record that is the actual 155-29 contract. A regression where the short-circuit returns success without transitioning to `done` still passes. Confirmed from reviewer-test-analyzer; downgraded to LOW because the short-circuit's transition behavior is covered by the pre-existing already-merged tests in this file and no production code changed in this story. | `test_155_1_finish_verifies_merge.py:487-492` | Optional strengthening: add `assert _requested_done(mock_transition)`. |
| [LOW] [TYPE] | `"288" in fake.merge_calls[0]` is exact list-element equality and is sound against today's argv (`story_finish.py:1461`), but becomes silently vacuous if production ever switches to a `--pr=288` flag form. Same implicit contract at line 360. | `test_155_1_finish_verifies_merge.py:450` | Optional: `assert fake.merge_calls[0][3] == "288"`, or comment the element-vs-substring semantics. |
| [INFO] [RULE] | reviewer-rule-checker: 15 rules, 12 instances, **0 violations** — edited under `pennyfarthing-dist/` source (not `.pennyfarthing/` symlink), no sprint YAML touched, result-object assertions (no throw expectations), `@patch` decorator order matches parameter order, `merge_calls[0]` indexed only after the `len == 1` guard. | — | None. |
| [INFO] [SEC] | reviewer-security: **clean**. `pf.sprint.story_finish._run` is the sole subprocess gateway and is fully replaced by `GhPrFake` inside both `with patch(...)` blocks; `_add_story_to_completed` and `transition_story` cover remaining side-effect paths. No real `gh`/git/network call escapes, no shell interpolation, no secrets, all path components and the `"155-1"` story ID are hardcoded literals. | — | None. |
| [INFO] [TYPE] | Deferred (out of scope — unchanged file): reviewer-type-design flagged `gh_pr_fake.py:89` (`current_state: str` wider than `GhPrState`) and `gh_pr_fake.py:56` (static-vs-stateful modes not type-discriminated; 6 other callsites in this file rely on the implicit `pre_merge_state="OPEN"` default, and the `merge_rc=0, pr_state="OPEN"` trio at lines 290/308/325 gets a never-transitioning fake). This is the same risk TEA already logged as an Improvement. Not a defect in this diff — the changed test defends itself by pinning `pre_merge_state` explicitly. | `pennyfarthing-dist/src/pf/tests/helpers/gh_pr_fake.py:56,89` | Follow-up story, not this one. |
| [INFO] | Verified good: no forked fake, no vacuous assertions, no `type: ignore`, no skipped tests / TODOs, scoped run only, no production changes, working tree clean. | — | None. |

**Deviation audit:** `## Design Deviations` = "No design deviations yet." Nothing undocumented found — the diff matches the SM fix shape (shared stateful fake, explicit `pre_merge_state`, invocation assertion, sentinel).

**Out of scope (noted, not required):** TEA's sibling-audit finding (`test_155_12`, `test_155_15`, `test_162_1`) should be re-scoped before anyone acts on it — its premise ("passed under a mutation that deletes the merge call") is the same claim that failed to reproduce here. The real, narrower question for siblings is whether they assert the merge *invocation* or only downstream state.

**Handoff:** To SM for finish-story.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

No design deviations yet.