---
story_id: "155-32"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-32: finish Step 2: consolidate the back-to-back gh pr view probes (_pr_block_reason + _pr_is_merged pre-check) into one shared call (from 155-29 review)

## Story Details
- **ID:** 155-32
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-31T20:08:20Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-31T18:22:22Z | 2026-07-31T18:24:42Z | 2m 20s |
| red | 2026-07-31T18:24:42Z | 2026-07-31T19:22:23Z | 57m 41s |
| green | 2026-07-31T19:22:23Z | 2026-07-31T19:35:05Z | 12m 42s |
| review | 2026-07-31T19:35:05Z | 2026-07-31T20:08:20Z | 33m 15s |
| finish | 2026-07-31T20:08:20Z | - | - |

## SM Assessment

Story setup complete. Branch `feat/155-32-consolidate-pr-view-probes` created off `develop` in `pennyfarthing/`.

**Scope:** Refactor-only. Consolidate the two back-to-back `gh pr view` probes in the
pre-merge path of `finish_story` (`pennyfarthing-dist/src/pf/sprint/story_finish.py`):
`_pr_block_reason` (L197, `--json mergeable,mergeStateStatus,baseRefName`, called at L384)
and `_pr_is_merged` (L180, `--json state`, called at L430) into a single call.

**Boundary:** The post-merge `_pr_is_merged` at L480 is NOT part of this consolidation —
it must remain a fresh probe or the gh #71/#60 merge verification is defeated.

Six ACs and the regression surface are written to `sprint/context/context-story-155-32.md`.
No Jira key on this story — Jira steps skipped.

**Next:** TEA for RED phase.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (7 failing — ready for Dev)

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_32_finish_single_pr_view_probe.py` —
  21 tests over `finish_story`'s pre-merge PR probing. Harness mirrors
  `test_155_29_finish_short_circuit_merged_pr.py`: a command-dispatching fake for
  `story_finish._run` plus patched `transition_story` / `_add_story_to_completed`.

**Tests Written:** 21 tests covering 6 ACs — 7 RED, 14 green-on-arrival guards.

### RED (must go green)

| Test | AC | Fails because |
|------|----|---------------|
| `test_open_pr_issues_one_pre_merge_view` | AC-1 | pre-merge window has 2 views |
| `test_already_merged_pr_issues_one_view_total` | AC-1 | same, on the short-circuit path |
| `test_clean_path_issues_one_view_on_each_side_of_the_merge` | AC-1+5 | 3 views today; pins 1 pre / 1 post |
| `test_non_dict_payload_aborts_cleanly_instead_of_raising` ×4 | AC-4 (extended) | uncaught `AttributeError` escapes `finish_story` |

Verified failure output — the three AC-1 tests print the offending pair verbatim:
`gh pr view 999 --json mergeable,mergeStateStatus,baseRefName | gh pr view 999 --json state`

### Green-on-arrival guards (over-reach protection)

| Class | AC | Guards against |
|-------|----|----------------|
| `TestPostMergeVerificationStaysFresh` | AC-5 | replaying the pre-merge snapshot post-merge (gh #71/#60) |
| `TestBlockingBehaviorPreserved` | AC-2 | losing CONFLICTING/DIRTY blocking or dropping `baseRefName` from the rebase message; also pins that UNKNOWN/null mergeability must NOT block |
| `TestShortCircuitRecordPreserved` | AC-3 | `merged` / `already_merged` keys, independently asserted (155-30 lesson) |
| `TestUnverifiableStateFallsThrough` | AC-4 | a shared failure path that blocks, or that reads "merged" |
| `TestHumanModeIssuesNoProbe` | AC-6 | hoisting the fetch above the merge-mode gate |
| `TestModuleRuleCompliance` | — | an unannotated new helper |

### The trap this suite is built around

The cheap way to satisfy an AC-1 call count is to memoize the PR view across
`finish_story` — one fetch, three readers. That silently reopens gh #71/#60: the
post-merge verification would re-read `state: OPEN` and wedge every clean finish.
Counting views on each side of the merge boundary makes that shape fail —
**HEAD = 3 views, correct fix = 2, whole-function memo = 1.** Dev should read
`test_clean_path_issues_one_view_on_each_side_of_the_merge` before choosing a shape.

### Rule Coverage

| Rule (lang-review python) | Test(s) | Status |
|------|---------|--------|
| #1 silent exception swallowing | `test_broken_probe_falls_through_to_merge_then_aborts_loud` (×4), `test_non_dict_payload_aborts_cleanly_instead_of_raising` (×4) | 4 passing / 4 failing |
| #3 type annotations at boundaries | `test_all_module_level_functions_are_fully_annotated` | passing |
| #6 test quality | self-check (below); per-key independent assertions on the step-2 record | passing |
| #2, #5, #7–#12 | not applicable — see Design Deviations | n/a |

**Rules checked:** 3 of 3 applicable lang-review rules have test coverage; 9 documented
as not applicable to this diff.
**Self-check:** 0 vacuous tests. Every test carries a value-specific assertion; no
`assert True`, no bare-truthy asserts, no OR-form assertions that a key-deletion mutant
could survive.

### Regression Surface

- Epic-155 suites (`155_1`, `155_12`, `155_15`, `155_16`, `155_29`): **127 passed**.
  No call-count assertion in `test_155_12` needed updating after all — it patches all
  `view` calls uniformly rather than counting them.
- Full suite: 5367 passed / 37 failed. **30 of those 37 are pre-existing failures on
  `develop`** (`test_peloton_portrait_panes`, `test_independence`, `test_init_justfile`),
  confirmed by running the suite with this file excluded. The other 7 are the intended RED.
- `ruff check` and `ruff format` clean on the new file.

RED verified directly by pytest (output above) rather than via `testing-runner` — the
direct run gives the per-test failure reasons the subagent would only summarize.

**Handoff:** To Dev for implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Tests:** 21/21 passing on the 155-32 suite (GREEN); 148/148 across the epic-155 surface
**Branch:** `feat/155-32-consolidate-pr-view-probes` (pushed)

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — one shared pre-merge probe
- `pennyfarthing-dist/src/pf/tests/test_155_15_finish_blocked_merge_no_stray_archive.py`
  — fake now returns the full field union per view (see Design Deviations)

### Shape

Split the fetch from the reads, so one snapshot answers both pre-merge questions:

| Symbol | Role |
|--------|------|
| `_PR_VIEW_FIELDS` | `state,mergeable,mergeStateStatus,baseRefName` — the union |
| `_pr_view(pr)` | the single fetch + parse; `None` when state can't be established |
| `_view_is_merged(view)` | pure read over a caller-supplied snapshot |
| `_pr_block_reason(pr, view)` | pure read; now takes the snapshot instead of fetching |
| `_pr_is_merged(pr)` | unchanged contract; `_view_is_merged(_pr_view(pr))` — still fetches |

Auto-mode finish: **3 `gh pr view` calls → 2** (one pre-merge, one post-merge).

### On the trap TEA built the suite around

I did not memoize. `_pr_is_merged` deliberately keeps its `(pr_number) -> bool`
signature and re-fetches, because it runs *after* the merge and exists to observe what
the merge produced — answering it from the pre-merge snapshot would verify nothing and
reopen gh #71/#60. The snapshot-reading variant is a separate function, so passing a
stale snapshot to the post-merge check isn't a one-token slip at the call site; the
post-merge entry point cannot accept one at all.

The probe also stays **inside** the auto-mode branch rather than being hoisted above the
merge-mode gate — hoisting would add a round trip to every human-mode finish and put the
hard-blocking conflict gate on a path that is deliberately advisory.

### TEA's `AttributeError` finding — fixed

`_pr_view` guards `isinstance(data, dict)`. `null`, `[]`, `"str"` and bare numbers are
valid JSON that `json.loads` accepts and that then raise `AttributeError` on `.get`,
escaping `finish_story` instead of returning `{success, error}` (CLAUDE.md rule #6). The
guard sits in the shared fetch, so the post-merge path inherits it too — it was
vulnerable to the same crash before.

### Verification

- 155-32 suite: **21/21 pass** (was 7 failed / 14 passed).
- Epic-155 surface (`155_1`, `155_12`, `155_15`, `155_16`, `155_29`, `155_32`):
  **148/148 pass**.
- Full suite: **5374 passed / 30 failed**. All 30 are pre-existing on `develop` —
  verified by `git stash`, re-running the three implicated files on the clean tree, and
  matching failure counts *and* test names (17 failures from `143_9`/`143_10`/`153_4`
  both before and after). Baseline before this story was 5353 passed / 30 failed; the
  +21 is exactly this story's tests.
- `ruff check` clean on both changed files. `ruff format` deliberately not run — see
  Design Deviations.

### Self-review

- [x] All 6 ACs met, each with a passing test
- [x] Follows project patterns — result objects, no throwing, `.js`-style relative
      import rules N/A (Python)
- [x] Error handling: every probe failure mode resolves to the permissive
      "don't block, not merged" and falls through to the guarded merge
- [x] No debug code; working tree clean; correct branch
- [x] No PR created (SM owns that in finish)

**Handoff:** To Reviewer.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered by me (see [EDGE] items) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered by me (see [SILENT] items) |
| 4 | reviewer-test-analyzer | Yes | findings | 5 | confirmed 5, dismissed 0, deferred 0 |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered by me (see [DOC] items) |
| 6 | reviewer-type-design | Yes | findings | 4 | confirmed 3, dismissed 1, deferred 0 |
| 7 | reviewer-security | Yes | findings | 1 | confirmed 1 (rationale corrected — see F2/F8) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — domain covered by me |
| 9 | reviewer-rule-checker | Yes | clean | 0 violations / 18 rules / 41 instances | N/A |

**All received:** Yes (5 returned, 4 disabled via settings)
**Total findings:** 9 confirmed (0 Critical, 0 High, 1 Medium, 8 Low), 1 dismissed with rationale, 0 deferred

### Independent corroboration

Two findings were reached independently by me and by a specialist, which raises confidence:
- The `test_155_15` clean-merge coverage gap — I found it by instrumenting `_run`; test-analyzer found it separately and, like me, **verified against `develop` that it is pre-existing**. Neither of us attributed it to this diff.
- The mode fetch/read guard coupling — I traced it from the control flow; type-design flagged it as `broken-invariant`.

test-analyzer also did the check I most wanted: it **mutated `_pr_is_merged` to reuse the pre-merge snapshot** and confirmed 5 tests fail, including the named discriminator. The anti-memoization guard is not vacuous.

## Reviewer Assessment

**Verdict:** APPROVED

No Critical or High issues. The consolidation is correct, the load-bearing merge verification is intact, and the one behaviour I most suspected — a memoized snapshot silently defeating the gh #71/#60 post-merge check — is provably absent and provably guarded against.

**Data flow traced:** `pr_number` → `_pr_view()` → `gh pr view` argv → `json.loads` → `dict|None` → `_view_is_merged` / `_pr_block_reason` → merge decision → `done` transition. Safe at each hop: argv is list-form with no `shell=True` (`story_finish.py:175-177`); every parse failure resolves to `None`; `None` reads as *both* "don't block" and "not merged", so no failure mode can skip the merge or fake a completion.

**Pattern observed:** fetch/read separation with an asymmetric signature — `_pr_view(pr) -> dict|None` + pure readers, but `_pr_is_merged(pr_number)` deliberately keeps a fetching signature (`story_finish.py:223-238`). This puts the AC-5 guarantee in the type signature rather than in reviewer vigilance: the post-merge entry point *cannot* be handed a stale snapshot. Good pattern; worth reusing.

**Error handling:** `_pr_view` (`story_finish.py:184-209`) returns `None` on non-zero exit, `JSONDecodeError`/`ValueError`, and non-dict payload. The `isinstance(data, dict)` guard fixes a pre-existing crash where `null`/`[]`/`"str"`/`42` escaped `finish_story` as an `AttributeError` instead of a result object (CLAUDE.md rule #6) — and because it sits in the *shared* fetch, the post-merge path inherits the fix too.

### Findings

| # | Severity | Source | Issue | Location | Introduced? |
|---|----------|--------|-------|----------|-------------|
| F1 | [MEDIUM] | own | Conflict gate runs before the already-merged check, so a MERGED PR with stale `DIRTY` mergeability aborts with "rebase and resolve conflicts" and wedges the 155-29 retry | `story_finish.py:435-454` | **No** — verified identical on `develop` |
| F2 | [LOW] | `[SEC]` `[TYPE]` | `.upper()` on `state` silently loosens the most safety-critical boolean from exact match; undocumented, untested | `story_finish.py:223` | Yes |
| F3 | [LOW] | `[TEST]` + own | `test_155_15` "clean merge" tests never invoke `gh pr merge`; class docstring claims otherwise | `test_155_15…py:630-640, 546-560` | **No** — verified on `develop` |
| F4 | [LOW] | `[TYPE]` | `dict[str, Any]` with no comment justifying `Any` (lang-review python #3) | `story_finish.py:184, 212, 240, 434` | Follows module convention (6 uncommented `Any` on develop) |
| F5 | [LOW] | `[TYPE]` + own | Fetch guard `== "auto"` vs read guard `!= "human"` are two independent comparisons kept in sync by convention | `story_finish.py:435, 467, 482` | Yes (latent only) |
| F6 | [LOW] | `[TEST]` | AST annotation guard never checks `args.vararg` / `args.kwarg` | `test_155_32…py:940` | Yes |
| F7 | [LOW] | `[TEST]` `[RULE]` | Parametrized cases sharing one branch (lang-review python #6) | `test_155_32…py:733-740, 813-821` | Yes |
| F8 | [LOW] | `[DOC]` (self, disabled) | Stale line refs `# L396-398` / `# L423-472` in module header | `test_155_15…py:16-17` | **No** — already stale on develop |

Source key: `[SEC]` reviewer-security · `[TEST]` reviewer-test-analyzer · `[TYPE]` reviewer-type-design ·
`[RULE]` reviewer-rule-checker (swept 18 rules / 41 instances, **0 violations**; F7 is my own
application of its rule #6 to the new parametrize blocks, which it passed) · `[DOC]`/`[EDGE]`/`[SILENT]`
domains were disabled via settings and covered by me directly.

**On F1 (the one Medium).** I built a MERGED-plus-`DIRTY` world and ran it against both revisions. Both abort with `PR #315 is CONFLICTING — rebase on develop…`, never reaching the short-circuit. So this diff did not introduce it. I am flagging it anyway because this refactor makes the fix nearly free: both answers now come from one snapshot, so checking "merged" before "conflicting" is a pure reorder with no extra I/O. It sits squarely in epic 155's subject (finish truthfulness) and directly undermines 155-29's retry guarantee. Follow-up story, not a blocker.

**On F5.** Type-design rated this `broken-invariant`, medium confidence. I read `pr_config.py:16-17,55-58`: `get_pr_merge_mode` validates against `VALID_PR_MERGE_MODES = {"auto","human"}` and falls back to `"auto"`, so a third value **cannot** reach this code in production. Downgraded to LOW as latent-only. `Literal["auto","human"]` would make it a type error rather than a silent fall-through.

**On F4 — rule-matching, so downgraded rather than dismissed.** lang-review python #3 says "`Any` is acceptable only with a comment explaining why." The four new sites have none, so this is a genuine rule violation and I am not dismissing it. Severity is LOW because `develop` already carries 6 uncommented `Any` in this same module — the diff followed the convention rather than introducing it. Fix belongs in a module-wide cleanup (or a `PrSnapshot` TypedDict, per type-design).

**Dismissed (1).** Type-design's "optional-abuse" suggestion to return a tagged `PrViewOk | PrViewUnknown` instead of `None` — dismissed as speculative generality: the module has no logger at all (`story_finish.py` imports neither `logging` nor `structlog`, confirmed by rule-checker), so there is no consumer for the discarded reason today, and adding a result type with no reader is exactly the abstraction the Dev brief warns against.

### Verified

- `[VERIFIED]` **Post-merge check re-fetches.** `story_finish.py:536` calls `_pr_is_merged(pr_number)`, whose body (`:238`) is `_view_is_merged(_pr_view(pr_number))` — a fresh `_run`. Measured on the branch with instrumented `_run`: **pre=1, post=1, total=2** `gh pr view` calls on the clean path, matching AC-1 and AC-5 exactly. Complies with the AC-5 requirement that the post-merge probe stay separate.
- `[VERIFIED]` **TOCTOU window did not widen.** The gate block (`:434-454`) and Step 2 (`:467`) are adjacent with no intervening I/O; the conflict check is now a pure function where it was previously a network round trip, so the fetch→merge window is *narrower* in wall-clock than before.
- `[SILENT]` `[VERIFIED]` **No swallowed error opens a false-done hole.** All three `_pr_view` failure exits (`:207,209,211`) return `None`; `_view_is_merged(None)` is `False` (`:220-221`) and `_pr_block_reason(None)` is `None` (`:255-256`) — matching the pre-diff `rc != 0` semantics of both originals exactly. Permissive, but never credulous.
- `[EDGE]` `[VERIFIED]` **Review-required guardrail unaffected.** `mergeable=MERGEABLE, mergeStateStatus=BLOCKED, state=OPEN` still passes the gate and falls through to the real merge; all 14 `test_155_15` tests pass for the right reasons.
- `[VERIFIED]` **No regression.** Preflight independently reproduced the baseline: `develop` 30 failed / 5353 passed; branch 30 failed / 5374 passed (+21 = exactly this story's tests). I separately confirmed by worktree that `143_9`/`143_10`/`153_4` fail identically on both revisions.
- `[RULE]` `[VERIFIED]` **Topology respected.** All 3 changed files are under `pennyfarthing-dist/src/pf/` — no `.pennyfarthing/` symlink targets, no `node_modules/`, correct repo (CLAUDE.md rules #1/#4).

### Devil's Advocate

Assume this is broken. Where would it bite?

The strongest attack is on the shared snapshot's *meaning*. Two questions that were previously answered by two independent observations are now answered by one. That is the entire story, and it silently converts an accidental redundancy into a single point of failure. If `gh` ever returns a partial payload — a field present but empty because a token lacks `read:org` for `mergeStateStatus`, say — both readers now degrade together instead of independently. Before, a mergeability failure could not corrupt the merged check, because the merged check made its own call. I tested `{}`, `null`, `[]`, missing keys, and null-valued keys: all degrade permissively and abort loud. But the *coupling* is real and permanent, and no test pins "one field unreadable, the other fine," because the fake always returns all four together. That is the residue this refactor leaves behind.

The second attack is on `.upper()` (F2). This is the boolean that lets finish declare a story shipped. Widening what counts as `MERGED` is the wrong direction to be sloppy in, even when the payload is first-party and the enum is uppercase today. It cost nothing to preserve exact matching; it was changed for stylistic symmetry with `mergeable`, and no AC asked for it. If GitHub ever emits a differently-cased or aliased state, this now says "shipped" where it used to say "not verified."

Third: a stressed filesystem or a rate-limited GitHub. A 403/429 from `gh` gives a non-zero exit → `None` → don't block, not merged → real merge attempted → that also fails → loud abort with the session intact. Correct, though the operator sees a merge failure rather than "GitHub is rate-limiting you" — the discarded stderr (type-design's dismissed finding) is genuinely lost diagnostic value, even if a tagged result type is overkill today.

Fourth, the confused-user path: F1. An operator retrying a finish after a post-merge abort, whose already-merged PR still reports stale `DIRTY`, is told to "rebase and resolve the conflicts" on a PR that is already merged and has no conflicts. They cannot comply. That is the worst user-facing failure in this area, it is pre-existing, and this refactor is what makes it a one-line fix.

Nothing here rises to blocking. The merge gate cannot be tricked into a false `done` by any input I constructed.

### Process note

Both `reviewer-preflight` and `reviewer-test-analyzer` checked out `develop` in the shared working tree to establish a baseline — at my instruction — and left it there; `test-analyzer` reported restoring "its original state" but that state was captured mid-run while another agent had already switched branches. I restored `feat/155-32-consolidate-pr-view-probes` before exiting. Parallel subagents sharing one working tree is a real hazard for any instruction involving `git checkout`/`stash`; I did my own verification in throwaway `git worktree`s instead, which is the safe pattern.

**Handoff:** To SM for finish-story.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)

- **Gap** (non-blocking): Both PR probes crash on a valid-JSON non-object payload.
  `_pr_is_merged` and `_pr_block_reason` do `json.loads(stdout).get(...)` under a guard
  catching only `(json.JSONDecodeError, ValueError)`; `null`, `[]`, `"str"` and bare
  numbers parse fine and then raise an uncaught `AttributeError`, which propagates out
  of `finish_story` as a traceback instead of the `{success, error}` result object the
  codebase contracts for (CLAUDE.md rule #6). Verified on HEAD for all four payloads.
  Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (the consolidated probe
  parse needs an `isinstance(data, dict)` guard). *Found by TEA during test design.*

- **Improvement** (non-blocking): The 155-12 pre-merge conflict gate probes only in auto
  merge mode, so a CONFLICTING PR finished in human merge mode gets no early warning at
  all — it is left `in_review` for a human who discovers the conflict at merge time.
  Defensible as designed (human mode is deliberately non-load-bearing) and pinned green
  by `TestHumanModeIssuesNoProbe`, but a *non-blocking advisory* in human mode would be
  a real UX gain. Out of scope here — 155-32 must not add probes to human mode.
  Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by TEA during test design.*

- **Improvement** (non-blocking): `pennyfarthing-dist/src/pf/preflight/finish.py:210` runs
  a third `gh pr view` on the same PR (`--json state,mergedAt,mergeable,url`) during
  finish preflight. Out of scope for 155-32 (different module, different entry point),
  but it is the same redundancy one call site further out — worth a follow-up story if
  the epic wants the whole finish path down to one probe.
  *Found by TEA during test design.*

### Dev (implementation)

- **Gap** (non-blocking): `test_155_15`'s `_make_fake_run` returned a payload whose
  *shape* depended on which `--json` fields were requested — real `gh` always returns
  every field named. That fiction was invisible while two separate probes existed and
  broke the moment they merged, failing two clean-merge tests for a reason unrelated to
  what they assert. Fixed here. Worth a wider sweep: any other `gh`-dispatching fake
  that models response shape rather than response *content* carries the same latent
  trap. Affects `pennyfarthing-dist/src/pf/tests/` (audit the `gh pr view` fakes).
  *Found by Dev during implementation.*

- **Improvement** (non-blocking): `story_finish.py` and
  `test_155_15_finish_blocked_merge_no_stray_archive.py` both fail `ruff format --check`
  at HEAD, independent of this story. Not fixed here — reformatting would bury the
  behavioural diff in unrelated churn. Affects the repo generally (a `ruff format` sweep
  plus a CI format gate would stop the drift). *Found by Dev during implementation.*

- **Improvement** (non-blocking): the full suite has 30 pre-existing failures on
  `develop` — `test_143_9_tdd_cycle_e2e` (13), `test_peloton_portrait_panes` (10),
  `test_153_4_story_mutation_on_sharded_yaml` (3), `test_independence` (2),
  `test_143_10_reviewer_dev_roundtrip` (1), `test_init_justfile` (1). Two of the
  `test_153_4` failures are in `TestFinishStorySuccessOnShardedYaml` and so touch this
  module's territory, though not this change. Verified pre-existing by stashing.
  A red baseline this large makes every story's regression check a manual diffing
  exercise. Affects `pennyfarthing-dist/src/pf/tests/`. *Found by Dev during implementation.*

### Reviewer (code review)

- **Gap** (non-blocking): The pre-merge conflict gate is evaluated BEFORE the already-merged
  short-circuit, so a PR that is already MERGED but whose mergeability is still reported stale
  as `CONFLICTING`/`DIRTY` aborts finish with "rebase on develop and resolve the conflicts" —
  advice the operator cannot act on, wedging exactly the retry 155-29 exists to enable.
  Reproduced against both `develop` and this branch, so it is pre-existing, not introduced.
  Worth filing because this story makes the fix nearly free: both answers now come from one
  snapshot, so checking merged-before-conflicting is a pure reorder with no extra I/O.
  Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (reorder the gate, add a
  MERGED+DIRTY test). *Found by Reviewer during code review.*

- **Gap** (non-blocking): `test_155_15`'s `TestCleanMergeArchivesAndCompletes` and
  `test_clean_merge_still_archives_dialogue` claim to guard "a verified merge (`gh pr merge`
  returns 0 AND state == MERGED)" but never invoke `gh pr merge` at all — their stateless
  `pr_state="MERGED"` fake trips the already-merged short-circuit. Verified by instrumenting
  `_run` on both revisions; pre-existing since 155-29, and found independently by
  reviewer-test-analyzer. `merge_rc` is accepted but unused on those paths. Coverage now
  exists in `test_155_32` via a stateful fake, so this is a naming/fidelity defect rather than
  a hole. Affects `pennyfarthing-dist/src/pf/tests/test_155_15_finish_blocked_merge_no_stray_archive.py`
  (switch to a stateful fake or rename the tests). *Found by Reviewer during code review.*

- **Improvement** (non-blocking): `dict[str, Any]` is used at four new sites with no comment
  justifying `Any`, which lang-review python #3 requires. Not introduced as a pattern —
  `develop` already carries 6 uncommented `Any` in this same module — so the fix is a
  module-wide cleanup, ideally a `PrSnapshot` TypedDict over the four `_PR_VIEW_FIELDS` keys
  so stringly-keyed `.get()` typos become static errors. Affects
  `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by Reviewer during code review,
  corroborating reviewer-type-design.*

- **Improvement** (non-blocking): The PR-number branch-resolution fallback assigns
  `pr_number = result.stdout.strip()` from `gh pr list --jq .[0].number` with no digit
  validation, unlike the session-file path which is `\d+`-regex extracted. Safe today only
  because the value originates from `gh` itself; the code is not safe *because it validates*.
  Note: reviewer-security asserted `pr_number` is digit-validated before reaching the probes —
  that is true only of the session path, so its rationale was incomplete even though its
  conclusion held. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py:331` (validate the
  resolved value). *Found by Reviewer during code review.*

- **Improvement** (non-blocking): Consolidating to one probe couples the two answers'
  failure modes — a partial payload now degrades both readers together where previously each
  made its own call. No test pins "one field unreadable, the other fine," because every fake
  returns all four fields together. Not a defect today (all degradations are permissive and
  abort loud), but it is the structural residue of this refactor and the place a future bug
  would hide. Affects `pennyfarthing-dist/src/pf/tests/test_155_32_finish_single_pr_view_probe.py`
  (add a per-field-absent case). *Found by Reviewer during code review.*

- **Improvement** (non-blocking): Running reviewer subagents in parallel against a single
  shared working tree is unsafe whenever their instructions involve `git checkout`/`stash` —
  two of them switched the repo to `develop` for baseline comparison and the tree was left
  there, which would have broken the finish flow had it not been caught. Agents needing a
  different revision should use a throwaway `git worktree`. Affects
  `pennyfarthing-dist/agents/reviewer-*.md` (state the constraint in the subagent briefs).
  *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

8 deviations

- **Tested non-dict JSON payloads beyond AC-4's literal wording**
  - Rationale: literally these payloads parse, so they sit just outside AC-4 as worded,
  - Severity: minor
  - Forward impact: Dev must add a non-dict guard to the consolidated probe parse.
- **Tests bind to the subprocess command sequence, not to any helper interface**
  - Rationale: an AC-1 call-count assertion is only meaningful at the syscall boundary,
  - Severity: minor
  - Forward impact: none — but Dev should know the suite will not catch a *renamed*
- **AC-1 pinned as "one view on each side of the merge", not a bare total**
  - Rationale: a total-count assertion is satisfiable by memoizing the view for the
  - Severity: minor
  - Forward impact: none — it constrains Dev away from a shape that would be a
- **No test written for lang-review python checks #2, #5, #7–#12**
  - Rationale: not applicable to this diff. The change is a pure refactor inside one
  - Severity: minor
- **Edited a prior story's test harness (`test_155_15`) to unblock this refactor**
  - Rationale: the branching encoded an assumption that two distinct probes exist —
  - Severity: minor
  - Forward impact: none — but future stories touching the probes should know
- **Kept `_pr_is_merged(pr_number)` as a fetching function rather than a snapshot reader**
  - Rationale: one uniform `(view)` signature across both readers would have been
  - Severity: minor
- **Did not run `ruff format` on the touched files**
  - Rationale: verified by stashing the change that both files already fail
  - Severity: minor
  - Forward impact: none — a repo-wide `ruff format` sweep is its own chore story.
- **Kept `_pr_is_merged(pr_number)` as a fetching function rather than a snapshot reader**

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)

- **Tested non-dict JSON payloads beyond AC-4's literal wording**
  - Spec source: context-story-155-32.md, AC-4
  - Spec text: "non-zero `gh` exit or unparseable JSON must yield *both* 'do not block'
    and 'not merged', so the flow falls through to the real merge attempt"
  - Implementation: `TestNonDictProbePayloadDoesNotCrashFinish` additionally covers
    payloads that ARE parseable but are not JSON objects (`null`, `[]`, `"str"`, `42`).
    These are RED on HEAD — they raise an uncaught `AttributeError` out of `finish_story`.
  - Rationale: literally these payloads parse, so they sit just outside AC-4 as worded,
    but squarely inside its intent (an unverifiable PR state must abort loud, not
    explode). Included because this story rewrites that exact parse into ONE shared
    place: an `isinstance(data, dict)` guard costs Dev one line now, whereas deferring
    copies the crash forward into the new shared helper — SOUL #1, fix the system.
  - Severity: minor
  - Forward impact: Dev must add a non-dict guard to the consolidated probe parse.
    Four extra RED tests.

- **Tests bind to the subprocess command sequence, not to any helper interface**
  - Spec source: context-story-155-32.md, "Technical Approach"
  - Spec text: "Shape of the refactor (struct vs. optional-snapshot param vs. small
    fetch helper) is Dev's call."
  - Implementation: every test drives `finish_story` end to end and asserts over the
    argv sequence captured by a fake `story_finish._run`. No test imports, names, or
    signature-checks `_pr_is_merged`, `_pr_block_reason`, or any new helper.
  - Rationale: an AC-1 call-count assertion is only meaningful at the syscall boundary,
    and binding to helper names would pre-decide the refactor the context explicitly
    left open. Dev may rename or delete either probe function freely.
  - Severity: minor
  - Forward impact: none — but Dev should know the suite will not catch a *renamed*
    helper, only a changed call pattern.

- **AC-1 pinned as "one view on each side of the merge", not a bare total**
  - Spec source: context-story-155-32.md, AC-1 and AC-5
  - Spec text: AC-1 "issues exactly one `gh pr view` invocation, not two"; AC-5 "the
    post-merge verification remains a fresh, separate `gh pr view` call"
  - Implementation: `test_clean_path_issues_one_view_on_each_side_of_the_merge` asserts
    `pre == 1 and post == 1` rather than a total count.
  - Rationale: a total-count assertion is satisfiable by memoizing the view for the
    whole function — which would pass AC-1 while silently replaying the pre-merge
    snapshot into the post-merge check and reopening gh #71/#60. Splitting the count at
    the merge boundary makes the wrong implementation fail. HEAD=3, correct fix=2,
    whole-function memo=1.
  - Severity: minor
  - Forward impact: none — it constrains Dev away from a shape that would be a
    regression.

- **No test written for lang-review python checks #2, #5, #7–#12**
  - Spec source: `.pennyfarthing/gates/lang-review/python.md`
  - Spec text: "Write at least one test per applicable check."
  - Implementation: covered #1 (silent exception swallowing — the fall-through and
    non-dict suites), #3 (type annotations — AST check over the module), and #6 (test
    quality — self-check, no vacuous assertions, independent per-key assertions).
    Skipped the rest.
  - Rationale: not applicable to this diff. The change is a pure refactor inside one
    synchronous function with no new arguments (#2), no constructors (#5), no resources
    (#7), no untrusted deserialization (#8 — `gh` output is trusted first-party, and the
    non-dict guard above is the robustness case), no async (#9), no new imports (#10),
    no user-input boundary (#11), and no dependency changes (#12).
  - Severity: minor
  - Forward impact: none

### Dev (implementation)

- **Edited a prior story's test harness (`test_155_15`) to unblock this refactor**
  - Spec source: context-story-155-32.md, "Regression Surface"
  - Spec text: "`test_155_12_finish_conflicting_pr.py` — counts `gh pr view` calls (see
    L461 comment; a call-count assertion there may legitimately need updating to
    reflect the new count)"
  - Implementation: `test_155_12` needed no change. The file that did was
    `test_155_15_finish_blocked_merge_no_stray_archive.py`, whose `_make_fake_run`
    branched on the `--json` field list and returned `{mergeable, mergeStateStatus,
    baseRefName}` — **with no `state` key** — for any request naming `mergeable`. The
    shared probe requests both, so that branch also caught the *post-merge*
    verification and answered it with a stateless payload, reading as "not merged" and
    failing two clean-merge tests. The fake now returns all four fields for every view.
  - Rationale: the branching encoded an assumption that two distinct probes exist —
    exactly the thing this story removes. It was also a fiction regardless: real `gh`
    returns every field named in `--json`, so response shape never depended on which
    subset was asked for. No assertion or test intent changed; the `pr_state`,
    `mergeable` and `merge_state_status` knobs keep their meanings.
  - Severity: minor
  - Forward impact: none — but future stories touching the probes should know
    `test_155_15`'s fake is now shape-agnostic and will not distinguish call sites.

- **Kept `_pr_is_merged(pr_number)` as a fetching function rather than a snapshot reader**
  - Spec source: context-story-155-32.md, AC-5
  - Spec text: "The **post-merge** verification at L480 remains a fresh, separate
    `gh pr view` call."
  - Implementation: `_pr_is_merged` keeps its `(pr_number) -> bool` signature and
    internally does `_view_is_merged(_pr_view(pr_number))`. The snapshot-taking reader
    is the separate `_view_is_merged(view)`.
  - Rationale: one uniform `(view)` signature across both readers would have been
    tidier, but it makes "pass the pre-merge snapshot to the post-merge check" a
    one-token mistake at the call site. Keeping the post-merge entry point *unable* to
    accept a stale snapshot puts the AC-5 guarantee in the signature rather than in a
    reviewer's vigilance.
  - Severity: minor
  - Forward impact: none

- **Did not run `ruff format` on the touched files**
  - Spec source: `.pennyfarthing/gates/lang-review/python.md`
  - Spec text: project quality checks / formatter cleanliness
  - Implementation: `ruff check` passes on both files. `ruff format --check` reports
    both as needing reformatting, and I left that alone.
  - Rationale: verified by stashing the change that both files already fail
    `format --check` at HEAD, and every hunk the formatter wants is in pre-existing
    code I never touched (`story_finish.py` L577/L721/L760, `test_155_15` L547/L566).
    Reformatting would bury a behavioural diff in unrelated churn. My own additions
    are formatter-clean.
  - Severity: minor
  - Forward impact: none — a repo-wide `ruff format` sweep is its own chore story.

### Reviewer (audit)

All seven logged deviations audited. Six ACCEPTED, one ACCEPTED WITH NOTE, one UNDOCUMENTED
deviation added.

**TEA deviations:**

- **Tested non-dict JSON payloads beyond AC-4's literal wording** → ✓ ACCEPTED by Reviewer:
  correct call, and the strongest single judgement in this story. The crash was real (I
  reproduced `AttributeError` on `null`/`[]`/`"str"`/`42` against both probes on `develop`),
  it lived in the exact parse being consolidated, and the fix was one `isinstance`. Deferring
  would have copied a rule-#6 violation forward into the new shared helper.
- **Tests bind to the subprocess command sequence, not to any helper interface** → ✓ ACCEPTED:
  the right altitude for a call-count AC. Verified the token-split is unambiguous — `"merge"`
  is matched by exact list membership, and no other command `story_finish` issues carries that
  token. TEA's caveat that the suite won't catch a *renamed* helper is accurate and honest.
- **AC-1 pinned as "one view on each side of the merge", not a bare total** → ✓ ACCEPTED:
  and independently validated. test-analyzer mutated `_pr_is_merged` to reuse the pre-merge
  snapshot and 5 tests failed, including this discriminator. The guard does what TEA claimed.
- **No test written for lang-review python checks #2, #5, #7–#12** → ✓ ACCEPTED: I re-derived
  applicability independently and rule-checker swept all 13 checks across 41 instances with
  0 violations. The N/A reasoning holds.

**Dev deviations:**

- **Edited a prior story's test harness (`test_155_15`)** → ✓ ACCEPTED by Reviewer: the change
  is behaviour-preserving, which I verified rather than assumed. All 14 `test_155_15` tests
  pass for the right reasons; the review-required guardrail case (`MERGEABLE`/`BLOCKED`/`OPEN`)
  is unaffected; and the only tests whose path changed (`pr_state="MERGED"`) already bypassed
  the merge on `develop` via 155-29's pre-check. Dev's diagnosis — that response shape keyed
  on the requested field list was always a fiction — is correct.
- **Kept `_pr_is_merged(pr_number)` as a fetching function rather than a snapshot reader**
  → ✓ ACCEPTED: this is the best decision in the diff. The asymmetry looks untidy and is
  load-bearing: it makes the AC-5 violation *unrepresentable* at the call site instead of
  merely discouraged. Encoding a guarantee in a signature beats documenting it.
- **Did not run `ruff format` on the touched files** → ✓ ACCEPTED WITH NOTE: I verified the
  claim by stashing — both files fail `format --check` at `develop`, and every hunk the
  formatter wants is outside the diff. Keeping the churn out was right. Note: preflight
  reports formatting drift as an outstanding item, so whoever runs the eventual sweep should
  know this was a deliberate deferral, not an oversight.

**Undocumented deviation (added by Reviewer):**

- **`state` comparison silently loosened from exact-match to case-insensitive:** Spec source
  is the pre-diff behaviour of `_pr_is_merged`, which compared `state == "MERGED"` exactly —
  deliberately *not* `.upper()`-folded, unlike the sibling `mergeable`/`mergeStateStatus`
  reads. The new `_view_is_merged` does `str(view.get("state", "")).upper() == "MERGED"`
  (`story_finish.py:223`). This widens the single boolean that authorises the `done`
  transition. Not logged by Dev, not requested by any AC, and not covered by any test in the
  new suite (which otherwise covers null/absent `mergeable` thoroughly). Not exploitable —
  `gh`'s `PullRequestState` enum is always uppercase — so severity is LOW, but a
  completion-truthfulness check in epic 155 should not be loosened as a styling side effect.
  Severity: low. Forward impact: none today; pin it or revert it.