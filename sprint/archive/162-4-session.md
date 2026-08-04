---
story_id: "162-4"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-4: Harden _branch_merge_state probe candidates via ref-prefixing — refs/heads/ and refs/remotes/origin/ resolve correctly and cannot be flag-parsed; the naive -- separator breaks rev-parse --verify (probed rc=1) (from 155-34 review)

## Story Details
- **ID:** 162-4
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-4-branch-merge-state-ref-prefix
- **PR:** #171

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-04T20:19:48Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-04T19:44:19.518214Z | 2026-08-04T19:45:41Z | 1m 21s |
| red | 2026-08-04T19:45:41Z | 2026-08-04T19:55:00Z | 9m 19s |
| green | 2026-08-04T19:55:00Z | 2026-08-04T19:58:35Z | 3m 35s |
| review | 2026-08-04T19:58:35Z | 2026-08-04T20:19:48Z | 21m 13s |
| finish | 2026-08-04T20:19:48Z | - | - |

## Sm Assessment

**Scope:** 1-pt p1 TDD story carrying a PROBED fix shape from the 155-34 review. `_branch_merge_state` in `pennyfarthing-dist/src/pf/sprint/story_finish.py` (~364+) probes branch candidates via `git rev-parse --verify` with bare names — a branch name starting with a dash could be flag-parsed by git.

**Probed fix shape (carry this, not alternatives):** prefix probe candidates with full ref paths — `refs/heads/<name>` for local, `refs/remotes/origin/<name>` for remote. Both resolve correctly and cannot be flag-parsed. The naive `--` separator was PROBED AND REJECTED in the 155-34 review: `git rev-parse --verify -- <ref>` returns rc=1 (the separator kills rev-parse). Do not resurrect it.

**Technical approach for TEA:** Failing tests: (1) probe candidates are emitted with refs/heads/ and refs/remotes/origin/ prefixes; (2) a dash-leading branch name (e.g. `-evil` or `--verify`) is probed safely — never passed as a bare token rev-parse could flag-parse; (3) existing merge-state classification behavior (merged/unmerged/unknown vocabulary, ~364 lowercase namespace noted in 162-3) unchanged for normal names. Verify against the real git binary where practical (rev-parse semantics are the whole story).

**Acceptance criteria:**
1. All rev-parse --verify probe candidates are fully ref-prefixed; no bare branch name reaches rev-parse.
2. Dash-leading branch names cannot be interpreted as flags.
3. Classification vocabulary and outcomes unchanged for canonical branch names; sibling finish suites green on develop HEAD (b71105f95).

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_4_branch_merge_state_ref_prefix.py` — 19 tests, 9 RED on HEAD, 10 green-on-arrival guards. Commit 3d5d4ea1a (GPG signed).

**Probe map (every rev-parse candidate in `_branch_merge_state`, story_finish.py ~390-408):**
- branch arm: `branch`, then `origin/<branch>` — both bare.
- base arm: `origin/<base>`, then `base` — both bare.
- the winning strings then feed `rev-list --count <base_ref>..<branch_ref>`, so a bare winner carries the defect into the counting step.

**What real git 2.54.0 actually does with bare candidates (probed, not assumed):**
1. `rev-parse --verify --quiet --default` → rc=128, "fatal: --default requires an argument".
2. `rev-parse --verify --quiet --local-env-vars` → rc=1 but EXECUTES the option and prints git's env var names to stdout. The branch name became a flag.
3. Bare names DWIM through refs/, refs/tags/, refs/heads/, refs/remotes/ — so a TAG named `<branch>`, or a local branch literally named `origin/<branch>` (the `git checkout -b origin/x` typo), shadows the intended ref. In both fixtures that shadow yields a FALSE merged/count 0 on a branch with real unlanded commits — i.e. the exact 155-34 false-done, reachable without any adversary.
4. `refs/heads/-evil` is creatable by plumbing (`update-ref` accepts it, `git branch` does not) and resolves when prefixed, but a bare probe returns rc=1 — a real branch reads as "not found".
5. `-evil` bare is swallowed quietly by git (rc=1), which is why only the argv-shape assertions catch it. Noted in the suite.

**Test inventory:**
- TestProbeCandidatesAreRefPrefixed — `test_branch_arm_candidates_are_fully_ref_prefixed` (RED), `test_base_arm_candidates_are_fully_ref_prefixed` (RED), `test_no_bare_dash_leading_name_appears_in_any_probe_argv` (RED), `test_rev_list_range_endpoints_are_fully_ref_prefixed` (RED), `test_double_dash_separator_not_used` (guard — the rejected shape stays dead), `test_probes_still_verify_quietly` (guard).
- TestRealGitRejectsFlagParsing — `test_probe_argv_is_never_flag_parsed_by_real_git` parametrized over `-evil` (guard), `--default` (RED), `--local-env-vars` (RED). Captures the emitted argv from a fake, then REPLAYS it against the real git binary: rc must be 0 or 1, no fatal, no env leak.
- TestRealGitPrefixSemantics (real git, no `_run` patch) — `test_dash_leading_ref_that_exists_is_found_not_reported_missing` (RED), `test_tag_shadow_does_not_answer_for_the_branch` (RED), `test_local_lookalike_branch_does_not_shadow_remote_tracking_ref` (RED).
- TestCanonicalClassificationUnchanged (AC-3 guards, real git) — merged/count 0/no reason; unmerged/count 2; missing branch → unknown + "not found" + no count; missing base → unknown naming the base; `test_upstream_base_wins_over_stale_local_base`; `test_local_branch_wins_over_stale_origin_branch`.
- TestThreatModelReachability — `_extract_branch` sentinels only a lone dash, so `-evil` reaches the probe intact.

**Designed interface for Dev:**
- Signature and return contract unchanged: `{state: merged|unmerged|unknown, count?, base, reason?}`. Only the candidate strings change.
- branch arm: `refs/heads/<branch>` BEFORE `refs/remotes/origin/<branch>`. base arm: `refs/remotes/origin/<base>` BEFORE `refs/heads/<base>`. Both orders are asserted — they are 155-34 behavior, not incidental.
- Whatever candidate wins a probe must be the same string used in the rev-list range. Prefix-then-range-bare is explicitly failed.
- `base` in the returned dict is operator-facing prose in `finish_story`; tests only require it NAMES the base, so bare `develop` or `refs/remotes/origin/develop` both pass. Dev's call.
- Do NOT use the `--` separator (probed rc=1, guard test fails if resurrected). All probes stay inside `_run` with explicit `cwd=str(project_root)`; the real-git tests do not patch `_run`, so a dropped cwd fails them.

**Status:** RED (9 failing on assertions, right reasons)
**Sibling suites:** all 155-* / 162-* / 151-5 finish suites green. The 5 remaining failures in that selection (143-9 x3, 153-4 x2) are the known pre-existing baseline, untouched by this suite.

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Commit:** 8845fe09a (GPG signed, verified G) — pushed to origin/feat/162-4-branch-merge-state-ref-prefix

**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_branch_merge_state` probe candidates ref-prefixed. Branch arm: refs/heads/branch then refs/remotes/origin/branch. Base arm: refs/remotes/origin/base then refs/heads/base. Docstring updated to record both defects (flag-parse, DWIM shadow), the rejected separator with its rc, and the range-endpoint contract.
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_4_branch_merge_state_ref_prefix.py` — one-line import move for ruff UP035 (Callable from collections.abc). No test logic touched.

**Mechanism (2 candidate tuples, nothing else):** the winning candidate string already flowed into the rev-list range and into the returned base field, so prefixing the candidates fixed the probe, the counting step, and the range endpoints in one change. No separator, no new helper, no signature change.

**Tests:** 19/19 on the story file (GREEN). Full finish selection: 500 passed, 16 failed.

**Baseline correction (matters for the review gate):** the handoff brief listed the known baseline as 143-9 x3 and 153-4 x2. Measured on this branch with my change stashed, those two files alone fail 16 (13 in 143-9, 3 in 153-4) — the same 16 that fail with the change applied, identical test IDs. So the change adds zero failures, but the baseline number in the TEA/SM notes is understated, not the failure count.

**Ruff:** clean on both changed files. No pre-existing drift reformatted.

**Handoff:** To Reviewer

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 19/19 story tests pass; finish-family 79 pass / 16 fail, all 16 identical on develop; ruff clean both files; no debug code | N/A — corroborated by my own independent full-suite failure-set diff |
| 2 | reviewer-test-analyzer | Yes | findings | (a) claims the local-look-alike test is tautological; (b) the verify/quiet guard covers only the branch arm | (a) DISMISSED with evidence — the DWIM reasoning is wrong (gitrevisions checks refs/remotes/<name>, not each remote's namespace) and my bare-name mutation shows the test failing; (b) CONFIRMED as Low, deferred |
| 3 | reviewer-edge-hunter | Yes | findings | (a) ref-qualified Branch value double-prefixes and now aborts; (b) dual shape of the returned `base` field; (c) a HEAD Branch value now aborts | (a) CONFIRMED but downgraded to Medium non-blocking — fails closed, outside AC-3, and the proposed normalization is itself unsound; (b) CONFIRMED as a doc gap, Medium, deferred; (c) CONFIRMED as Low, same class, deferred |
| 4 | reviewer-comment-analyzer | Yes | findings | (a) the return-contract sentence wrongly implies `base` is absent on unknown returns; (b) the dual shape is undocumented; (c) the edited prose is vaguer than the paragraph above it | (a) CONFIRMED but pre-existing wording, Medium, deferred; (b) CONFIRMED, folded into the same finding; (c) CONFIRMED as Low, deferred. All four docstring facts it probed against real git came back TRUE |
| 5 | Explore (staleness scope check) | Yes | findings | staleness.py:443 PARTIALLY CONFIRMED — bare-ref shape real, but flag-parse and typo vectors unreachable; only tag-shadow residue, advisory consequence. Also found a second site at data_proxy.py:189 | CONFIRMED for follow-up filing at reduced severity; both recorded under Delivery Findings. Out of this story's scope |

| 6 | reviewer-security | Yes | findings | Git revision operators (tilde, caret, at-brace reflog) survive the ref prefix, so a manipulated Branch value can resolve an ancestor of the intended branch and read as merged | CONFIRMED and independently re-probed by me, but PRE-EXISTING and identical on bare names — see the pre-existing exposure note below. Does not block 162-4; must be filed as its own p1 |
| 7 | reviewer-type-design | Yes | findings | (a) the `base` key is semantically polymorphic across arms and leaks git ref syntax into operator prose, recommends using the bare name in all arms; (b) the state vocabulary is bare str rather than a Literal union | (a) NOTED, and I decline the recommended change — Dev's deviation is accepted on its merits (naming the ref actually consulted is what distinguishes a stale remote-tracking answer from a local one) and both shapes pass the suite; the residual is the doc gap already filed. It correctly agrees no newtype is warranted; (b) DISMISSED as pre-existing and out of scope — AC-3 pins the vocabulary unchanged |
| 8 | reviewer-rule-checker | Yes | clean | 15 rules, 21 instances, 0 violations. Both commits GPG-signed with a good signature; commit format, branch strategy, source-of-truth location, and test naming all compliant | N/A — I spot-verified the signature status independently (both commits report G) |

**All received: Yes** (8 of 8 enabled specialists returned; none errored)

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** session Branch field -> _extract_branch (strips annotations/backticks, sentinels a lone dash) -> _branch_merge_state(project_root, branch) -> two ref-prefixed rev-parse probe arms -> winning candidate strings -> rev-list --count range -> finish_story's no-PR gate at story_finish.py:769. Safe because every candidate is now a full ref path, so no argv position git can flag-parse and no rev name git can DWIM to a tag or look-alike branch, and the same winning string is the range endpoint — the counting step cannot fall back into either shadow.

**Verification I ran myself (not taken on trust) — four mutations on a throwaway detached worktree of 8845fe09a, then removed:**
1. Reverted both candidate tuples to bare names: 9 failed / 10 passed. The 9 are exactly TEA's declared RED set.
2. Swapped candidate order in both arms: 4 failed — both argv-order assertions AND the two real-git precedence tests (upstream base wins, local branch wins). Order is bound twice over, mechanically and semantically.
3. Prefixed the probes but made the rev-list range endpoints bare: 7 failed, including both real-git shadow tests and the canonical merged/unmerged pair. The prefix-then-range-bare cheat is genuinely failed.
4. Reintroduced the separator token in the probe argv: 9 failed, including the dedicated guard. The rejected shape stays dead.

**Regression evidence (independent of Dev's numbers):** full python suite, random order disabled, on both refs. Develop at b71105f95 fails 31; this branch fails 30. Failure ID sets diffed — the branch set is a strict SUBSET. The one delta is a healthscore cache-path test that fails only in the temp worktree (no runtime dir), an artifact of my probe, not of the change. Zero regressions.

**Baseline correction confirmed:** ran the two known-failing files on develop at b71105f95 in a clean worktree — 16 failed / 61 passed, 13 in 143-9 and 3 in 153-4, identical test IDs to this branch. Dev's correction is right; the 5 carried through setup and RED was understated. Compare against 16.

**Pattern observed:** `unknown` is still fail-closed at story_finish.py:770-800 — every non-merged classification aborts before any irreversible step, with the session kept. The ref-prefix change moves two failure modes (flag-parse, DWIM shadow) OUT of the false-merged class and INTO the abort class, which is the correct direction for this gate.

**Error handling:** all four non-definitive paths return a `reason` and route to the loud abort; rev-list failure and unparseable output are both handled explicitly (story_finish.py:428-438). No swallowed errors introduced.

**Docstring claims independently probed against real git 2.54.0 — all true:** the separator form returns rc=1 even for an existing ref; `--local-env-vars` exits 1 but prints 15 environment variable names; bare name DWIM resolves a same-named tag ahead of the branch; a local branch named origin/<name> shadows the remote-tracking ref. The docstring is accurate, not decorative.

**Deviation audit:**
- `base` field is now the prefixed ref — **ACCEPTED.** I traced every consumer: it is read only twice, both prose (the skip step's branch_verified_merged_into value and the unmerged abort sentence). Nothing passes it to git, compares it to a branch name, or parses it. Dev's rationale holds — naming the exact ref consulted distinguishes a stale remote-tracking answer from a local one. See finding 2 for the residual doc gap.
- Docstring expanded beyond the code change — **ACCEPTED.** Every factual claim verified above. Keeping the probed-and-rejected separator with its rc in the code is the only thing standing between a future cleanup and a reintroduced regression.
- Touched TEA's test file for UP035 — **ACCEPTED.** One import line, ruff clean, no assertion or fixture touched; all 19 tests still bind (mutation-proven above).
- No undocumented deviations found.

**[RULE] Project rules:** exhaustive check came back clean — 15 rules, 21 instances, 0 violations. The edits are inside pennyfarthing-dist (source of truth), no symlink target or node_modules touched, no path literals introduced, Python-only, test file placed and named per the established convention, both commits GPG-signed with a good signature and conventional subjects, and the branch targets develop per gitflow. The result-object rule is satisfied on all five return paths — nothing raises.

**[TYPE] Type design:** no newtype is warranted for a two-tuple change in one private function, and I agree. The one live observation is that the `base` key spans two string domains (bare configured name on the not-found arms, full ref path elsewhere). The recommendation was to push the bare name into every arm; I decline it — Dev's deviation is accepted on its merits and both shapes pass the suite — so the residual is the documentation gap recorded below, not a code change. The bare-str state vocabulary is pre-existing and AC-3 pins it unchanged.

**[TEST] Test quality:** mutation testing (above) is the primary evidence and it is strong — every property the story claims is bound by at least one test, and three of the four mutations were caught by real-git semantic tests as well as argv assertions, so the suite is not merely shape-checking. Two residuals: one Low gap (the quiet/verify flag guard covers only the branch arm) and one dismissed claim, next.

**[TEST] Dismissed subagent finding (with evidence):** a test-quality pass claimed test_local_lookalike_branch_does_not_shadow_remote_tracking_ref is tautological, on the theory that bare `widget` DWIMs to refs/remotes/origin/widget. That is wrong — gitrevisions checks refs/remotes/<name>, i.e. refs/remotes/widget, not each remote's namespace. The first bare candidate misses and the second resolves refs/heads/origin/widget ahead of refs/remotes/origin/widget. Mutation 1 above shows the test failing on bare names. The test binds; the docstring's 3-RED claim for that class is correct.

**Non-blocking findings (deferred, all Medium or below — none blocks this story):**

| Severity | Issue | Location |
|----------|-------|----------|
| [MEDIUM] | A ref-qualified Branch value (origin/x, refs/heads/x) now double-prefixes and resolves nothing, so finish aborts where the old bare probe verified it. Fails CLOSED, and such values are outside AC-3's canonical names, so not a defect in this story. The obvious strip-the-prefix fix is unsound — it collides with the very look-alike-branch threat this story defends against — so it needs its own design, not a patch here. | story_finish.py:402 |
| [MEDIUM] | The return contract at story_finish.py:371 does not document that `base` is the bare configured name on the two not-found arms but the full prefixed ref on the definitive and rev-list-failure arms. The dual shape is intentional (see deviation audit) but undocumented in the code; the same sentence also implies `base` is absent on unknown returns, which was already inaccurate before this change. | story_finish.py:371 |
| [LOW] | The prose edit "then the remote-tracking ref / origin's ref" is vaguer than the concrete ref paths named three sentences earlier in the same docstring. | story_finish.py:388-390 |
| [LOW] | test_probes_still_verify_quietly inspects only the branch arm's argv; the base arm could drop the quiet or verify flags without failing a test. | test_162_4 file:430 |
| [LOW] | A prunable worktree registry entry from an earlier phase was left in the framework repo's git dir. I pruned it; noting so it is not mistaken for mine. | pennyfarthing/.git |

**[SEC] Pre-existing exposure this story does NOT close (the one thing that would be High if it were new):** git revision operators survive the ref prefix. I probed it directly — refs/heads/develop~1, refs/heads/develop@{0} and the caret form all resolve rc=0. So a Branch value of feat~2 becomes refs/heads/feat~2, resolves to an ancestor of the real branch tip, counts zero commits ahead, and reads as merged — the 155-34 false-done, from a different direction. `_extract_branch` sentinels only a lone dash and does not validate ref syntax. Crucially, the bare-name code on develop resolves the identical expression (I verified bare develop~1 is also rc=0), so this diff neither introduces nor worsens it, and it is outside all three ACs. That is why it does not block: it is a separate defect needing its own story, not scope creep on a 1-pointer. A clean fix exists and is already probed — `git check-ref-format --branch` rejects these values (rc=128 on develop~1), which composes with this gate's fail-closed contract: invalid name goes to unknown, which aborts. Recommend SM file it at p1; it is the highest-value item in this review.

**Observations count:** 5 blocking-check areas cleared (data flow, order, range endpoints, separator, regressions) plus 5 non-blocking findings and 3 deviations audited.

**Handoff:** To SM for finish-story.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): the same bare-name pattern lives in `pennyfarthing-dist/src/pf/sprint/staleness.py:443` — `git -C <repo> rev-parse --verify --quiet <ref>` with an unprefixed ref. Same flag-parse and tag/look-alike DWIM exposure as 162-4. Affects `pennyfarthing-dist/src/pf/sprint/staleness.py` (needs the same ref-prefixing treatment, plus its own tests). Out of this story's scope. *Found by TEA during test design.*
- **Improvement** (non-blocking): `_extract_branch` treats only a lone `-` as a sentinel, so a dash-leading branch value flows into every git call downstream of it. Ref-prefixing fixes `_branch_merge_state`, but defense in depth at the extractor (reject or reference-qualify dash-leading values) would cover future probes. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_extract_branch`). *Found by TEA during test design.*
- **Improvement** (non-blocking): the probe candidates hardcode the `origin` remote. A repo whose upstream is named otherwise silently loses the remote arm. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_branch_merge_state`) — deliberately unpinned by the 162-4 tests, which preserve today's `origin` assumption. *Found by TEA during test design.*
- **Question** (non-blocking): the merge-state answer is only as good as the local remote-tracking refs; nothing fetches before probing, so a stale `refs/remotes/origin/<base>` can still misclassify. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (whether the no-PR gate should fetch first). *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): the pre-existing baseline failure count carried through setup and RED is wrong — 143-9 fails 13, not 3, and 153-4 fails 3, not 2 (16 total, verified with this story's change stashed). Affects the finish-family baseline recorded in SM/TEA assessments (needs re-measuring once, then quoting accurately, or a later story to actually fix them). *Found by Dev during implementation.*
- **Improvement** (non-blocking): TEA's Gap on `staleness.py:443` is the same bug in the same shape and is a near-identical one-line fix (prefix the ref in the rev-parse probe). Affects `pennyfarthing-dist/src/pf/sprint/staleness.py` — worth filing now while the probed fix shape and the git semantics are documented in 162-4's docstring and test module. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking): TEA's staleness finding is PARTIALLY CONFIRMED for follow-up filing, and should not carry 162-4's threat model verbatim. The bare-ref shape at staleness.py:443 is real (candidates origin/<base> then bare <base>), but flag-parse and typo vectors are NOT reachable there: base_branch comes from a two-entry literal table with a fail-closed membership gate, so only develop/main/origin-prefixed forms of those can ever reach git. Only the tag-shadow DWIM residue survives, and its consequence is advisory — a false clean or false drift on a staleness verdict that nothing destructive consumes, unlike the 162-4 site whose verdict gates a branch-deleting finish. File as low-severity hardening for house-rule consistency, not as a security defect. Affects `pennyfarthing-dist/src/pf/sprint/staleness.py` (prefix both candidates; also return the resolved full ref, since the human summary hardcodes an origin label and misreports a local fallback). *Found by Reviewer during code review.*
- **Gap** (non-blocking): a SECOND bare-ref site not previously reported — `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py:189` builds the range HEAD..origin/develop, whose remote endpoint is DWIM-shadowable by a tag or a local branch named origin/develop. Hardcoded literal so there is no input vector; it feeds only a dashboard counter. Worth folding into the same one-line follow-up as staleness. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): a ref-qualified value in the session's Branch field (origin/x or refs/heads/x) now double-prefixes and resolves nothing, so the no-PR gate aborts where the old bare probe verified it. Fail-closed and outside AC-3's canonical-name scope, so not a 162-4 defect — but the naive strip-the-prefix normalization is unsound, because it collides with the look-alike-branch threat this story defends against. Needs its own story with a real design (candidate widening, or rejection at the extractor). Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_extract_branch` and `_branch_merge_state`). *Found by Reviewer during code review.*
- **Gap** (non-blocking for 162-4, but file at p1): git revision operators survive the ref prefix, so a Branch value like feat~2, feat^1 or feat@{1} resolves an ancestor of the real branch tip and the no-PR gate reads count 0 as merged — the 155-34 false-done from a direction ref-prefixing does not cover. Verified by probe: the prefixed and bare forms both resolve rc=0, so this is pre-existing and untouched by 162-4, and outside its ACs. The probed fix shape to carry: validate with `git check-ref-format --branch` before prefixing (rejects these values rc=128) and let an invalid name fall into the existing unknown-aborts path. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_extract_branch` and/or the top of `_branch_merge_state`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the dual shape of the returned `base` field is intentional but undocumented, and the existing return-contract sentence also wrongly implies `base` is absent on unknown returns. A one-sentence docstring correction closes both. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by Reviewer during code review.*
- **Question** (non-blocking): the finish-family baseline is now measured at 16 on develop b71105f95, but the wider suite carries 31 unrelated failures on that same commit (peloton portrait panes and others). Nothing in this story touches them, but a review gate that quotes a moving baseline invites the exact understatement Dev caught here. Affects the sprint's treatment of the known-failing set (worth one story to either fix or formally quarantine them). *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **base field is now the prefixed ref:** TEA left it to Dev (bare or prefixed both pass). Implemented prefixed, because it is the string actually probed — the operator-facing abort prose in `finish_story` now names the exact ref the classifier consulted, which distinguishes a stale remote-tracking answer from a local one. Unknown-branch/unknown-base reasons still quote the bare configured base, since no ref resolved there to name.
- **Docstring expanded beyond the code change:** the fix is two tuples, so the reason it is those tuples (and not the `--` separator, rc=1) lives only in the docstring. Recorded there to stop the separator being reintroduced as an "obvious" cleanup.
- **Touched TEA's test file:** one import line, for ruff UP035 on the new file. No test logic or assertion changed.