---
story_id: "162-9"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-9: finish robustness: pass a bounded timeout to _run gh subprocess calls (from 155-31 review)

## Story Details
- **ID:** 162-9
- **Jira Key:** (none — no Jira for this story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-9-finish-subprocess-timeouts
- **PR:** #181

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-05T18:01:40Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-05T17:14:22Z | 2026-08-05T17:16:02Z | 1m 40s |
| red | 2026-08-05T17:16:02Z | 2026-08-05T17:31:32Z | 15m 30s |
| green | 2026-08-05T17:31:32Z | 2026-08-05T17:41:47Z | 10m 15s |
| review | 2026-08-05T17:41:47Z | 2026-08-05T18:01:40Z | 19m 53s |
| finish | 2026-08-05T18:01:40Z | - | - |

## Acceptance Criteria
- Narrow or log the bare 'except Exception' at story_finish.py ~897 that degrades to in_progress unlogged AFTER the irreversible merge (pre-existing from 155-16, resurfaced in 162-1 review)

## Sm Assessment

**Scope:** 2-pt p2 robustness story, TDD. Two fixes in `pennyfarthing-dist/src/pf/sprint/story_finish.py`: (1) `_run` shells out to gh/git with NO timeout — a hung gh call (network, auth prompt, update check) wedges the finish ceremony indefinitely, potentially mid-way through the irreversible sequence; (2) folded AC: the bare `except Exception` in the post-merge status-transition arm (setup located it near line 1066 on current develop; originally cited ~897 — the file drifted through 162-1/3/4/6, locate by pattern) degrades to `in_progress` UNLOGGED after the irreversible merge.

**Technical approach for TEA:**
1. Failing tests: every `_run` subprocess call carries a bounded timeout; `TimeoutExpired` surfaces as a result-object failure (rule 6) naming the command that timed out — never an unhandled exception, never a wedge. Sensible tiering acceptable (longer for gh network calls, shorter for local git) but every call bounded.
2. Timeout mid-ceremony: a timeout AFTER the merge landed must not report the merge un-happened — the step record stays truthful (the 155/162 truthfulness contract).
3. The post-merge bare `except Exception`: narrowed or at minimum logs the exception with context; the degradation to `in_progress` must be LOUD (operator-visible message naming the caught error).
4. Suite exit 0 (7 loud 162-5 xfails only).

**Acceptance criteria:** the folded AC above + every `_run` call bounded + timeout failures are truthful result objects.

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED — 17 failing, 1 green-on-arrival over-reach guard. Suite otherwise exit 0.

**Test File:** pennyfarthing-dist/src/pf/tests/test_162_9_finish_subprocess_timeouts.py (1189 lines)
**Commit:** 691348730 (GPG signed, verified)

**Suite state:** 17 failed, 5645 passed, 4 skipped, 7 xfailed (the expected loud 162-5 xfails). Ruff clean.

### Call-site inventory (all ten, all currently unbounded)

Confirmed by the ledger the tests build, not by reading alone:

| # | argv | phase |
|---|------|-------|
| 1 | gh pr list --head BRANCH --json number --jq | branch to PR resolution |
| 2 | gh pr view PR --json state,mergeable,mergeStateStatus,baseRefName | pre-merge gate |
| 3 | gh pr merge PR --squash --delete-branch | irreversible |
| 4 | gh pr view PR (again) | post-merge verification |
| 5,6 | git rev-parse --verify --quiet REF (x2) | no-PR gate refs |
| 7 | git rev-list --count BASE..BRANCH | no-PR gate count |
| 8 | python -m pf.cli sprint epic archive | step 5 |
| 9,10,11 | git checkout BASE / git pull origin BASE / git branch -d -- BRANCH | step 6 cleanup |

(Eleven invocations across ten distinct code sites — rev-parse is one site called twice.)

### Designed interface for Dev

Nothing is pinned to a mechanism; these shapes satisfy the assertions.

1. **Timeout constants, one reviewable block.** Suggested tiering:
   - GH_TIMEOUT_S = 120.0 — network-facing gh calls
   - GIT_LOCAL_TIMEOUT_S = 30.0 — rev-parse, rev-list, branch -d
   - GIT_NETWORK_TIMEOUT_S = 120.0 — git pull
   - SUBCOMMAND_TIMEOUT_S = 120.0 — the step-5 pf.cli invocation

2. **Default the bound on the helper, do not sprinkle it across ten sites.**
   Give _run a keyword-only timeout defaulting to a bounded value and forward it
   to subprocess.run. That makes "every call bounded" a property rather than an
   audit, and the eleventh call site added next sprint inherits it. An
   explicitly passed timeout must reach subprocess unchanged — that is how the
   per-site tiering is expressed, and one test pins it.

3. **Envelope the tests enforce on the values:** every bound in [10s, 3600s],
   and every gh bound at least 30s. A tight bound on the irreversible merge
   trades a rare hang for a routine mid-merge kill.

4. **TimeoutExpired becomes a result, not an exception.** Either wrap each arm,
   or have _run return a synthetic non-zero CompletedProcess whose stderr names
   the command. Two constraints on the second shape:
   - the PRE-merge arms must still ABORT. A timed-out probe is NOT the permissive
     "unknown" that _pr_view degrades an error to — the process hanging now hangs
     on the next call too, and degrading a hung branch-to-PR probe drops finish
     into the no-PR arm where a merged-looking branch silently finishes.
   - the post-merge verification must stay distinguishable from "the PR is not
     MERGED". Routing a timed-out verification into the existing abort message is
     the trap: that message asserts a state finish has no evidence for and which
     is in fact false. Tests forbid both "is not MERGED" and "unmerged code"
     wording on that path.

5. **Post-done timeouts are recorded, not fatal.** Steps 5 and 6 run after the
   merge is verified, the story is done and the YAML written. Un-reporting a
   story that shipped is the same lie in reverse. Record a warning, keep going,
   still remove the session in step 7.

6. **Naming contract.** The tests read only the operator-facing prose values of
   the report (keys matching error/warn/message/reason/timeout/timed), never
   whole step dicts — so a message must actually name the program and its
   subcommand. Echoing str(TimeoutExpired) satisfies this.

7. **The folded AC.** Either narrow the broad status-read handler (155-16's
   no-escape test still forbids letting anything escape post-merge, so a narrowed
   version needs a loud catch-all that RETURNS) or keep the degradation and make
   it loud — bind the exception, print or log it, record a step. Both routes pass.
   The AST pin only requires that a broad handler, if present, binds its
   exception and does something with it beyond assigning a default.

### Test list

**TestEverySubprocessCallIsBounded** (2 RED)
- test_pr_merge_world_bounds_every_call — PR arm: gate view, merge, verification view, step 5, step 6 x3
- test_no_pr_branch_verification_world_bounds_every_call — no-PR arm: gh pr list, rev-parse x2, rev-list

**TestRunHelperDefaultsToBounded** (1 RED)
- test_run_supplies_a_bounded_timeout_and_honors_an_explicit_one — the seam itself, plus the override

**TestTimeoutValuesAreSane** (1 RED)
- test_bounds_are_neither_trigger_happy_nor_useless — the [10s, 3600s] envelope, gh at least 30s

**TestTimeoutBeforeDoneAbortsLoudly** (5 RED, parametrized)
- gh-pr-list, gh-pr-view-gate, gh-pr-merge, git-rev-parse, git-rev-list — each: no escape, loud abort invariants (session kept, no stray archive, no done transition, YAML still in_review), report names the timeout and the command

**TestPostMergeVerificationTimeoutStaysTruthful** (2 RED)
- test_verification_timeout_aborts_without_denying_the_merge — aborts, names gh pr view, and must NOT claim the PR is not MERGED nor blame unmerged code
- test_step_two_record_still_reports_the_merge_ran — the step-2 record names the PR, says verification is what failed, never asserts merged False

**TestTimeoutAfterDoneIsRecordedNotFatal** (4 RED, parametrized)
- epic-archive, git-checkout, git-pull, git-branch-delete — each: no escape, success stays True, done transition happened, timeout named, session still removed

**TestPostMergeStatusFallbackIsLoud** (2 RED)
- test_degradation_names_the_caught_error_somewhere_operator_visible — PermissionError injected at read_sprint call 2 only (call 3 is step 4b, whose own broad catch would otherwise satisfy loudness the status arm never earned); the error text must appear in the report, stdout, stderr or the log, marked as a problem
- test_broad_status_read_handler_does_more_than_assign_a_default — AST pin on the handler

**TestCleanFinishUnchanged** (1 GREEN, must stay green)
- test_clean_pr_finish_still_succeeds — healthy finish unaffected, and nothing reports a timeout that did not happen

### Harness notes

- Reuses 162-6's cwd-keyed stateful gh fake and its real-git-repo fixtures (real
  origin, real branch topology), so 162-6's repo routing keeps being exercised.
- The fake is installed one layer LOWER than 162-6's: it replaces the subprocess
  module object inside story_finish rather than the _run seam, because timeout is
  a kwarg of that call and a fake at _run cannot see it. Scoping it to the module
  means only story_finish's subprocess use is intercepted; git passes through to
  the real binary, gh is answered from the world, the step-5 CLI is canned.
- The timeout predicate takes the ledger, so "the post-merge verification" is
  expressible as "a view that happens after a merge" — the pre-merge gate view
  and the verification view are the same argv.
- The story branch name contains the word "timeouts" and is echoed into step
  records, which false-positived the green guard's no-spurious-timeout check.
  Fixed by stripping the branch name before any timeout-wording search.

### Rule coverage (lang-review python.md)

- #1 silent exception swallowing — the whole folded AC: the broad status-read
  handler must not swallow. Also the abort-versus-degrade choice for a timed-out
  pre-merge probe, which is the same bug class one level up.
- #4 logging correctness — the loudness test accepts print, log or step record
  but demands the error be named and marked as a problem.
- #6 test quality — every assertion checks a concrete value; the token checks
  read only operator-facing prose so no assertion can be satisfied by pre-existing
  step vocabulary; each parametrized case asserts its call site was actually
  reached before drawing conclusions.

**Handoff:** To Dev for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Status:** GREEN — 18/18 in the story file, suite exit 0.

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — bounded subprocess seam, per-site timeout handling, loud post-merge status fallback

**Tests:** 18/18 story file. Full suite 5662 passed, 4 skipped, 7 xfailed (the expected loud 162-5 xfails), 0 failed. Baseline was 5645 passed + 17 failed — exact match, no collateral.
**Ruff:** the changed file is clean. Package-wide count unchanged at 86 pre-existing errors in untouched files (verified against a stash of this branch's diff).
**Branch:** feat/162-9-finish-subprocess-timeouts (pushed, commit 6f70021c8, GPG signed, good signature)

### How it works

**The seam.** `_run` takes a keyword-only timeout defaulting to DEFAULT_TIMEOUT_S and forwards it to subprocess.run, so "every call is bounded" is a property of the helper rather than an eleven-site audit — and the twelfth site inherits it. An explicit timeout wins, which is how the tiering is expressed. Constants in one reviewable block, per TEA's suggested shape: DEFAULT 120s, GH 120s, GIT_LOCAL 30s (rev-parse, rev-list, branch delete), GIT_NETWORK 120s (pull), SUBCOMMAND 120s (the step-5 pf.cli call). All inside the [10s, 3600s] envelope, all gh bounds over 30s.

**TimeoutExpired becomes a result, not an exception.** `_run` catches it and returns a `_TimedOutProcess` — a CompletedProcess subclass with returncode 124, stderr carrying the exception's own text (which names the program, the subcommand and the bound that expired, so every operator-facing message gets the command name for free). `_timed_out()` is an isinstance check, deliberately NOT a marker attribute: a getattr probe invents a truthy attribute on the MagicMock results the finish suites hand back, which would read every faked call as timed out. Returncode 124 also means a timed-out result already reads as a failure to the pre-existing non-zero checks, so no arm silently treats it as success.

**Distinguishing "hung" from "unknown" at the probes.** `_pr_view` could only say None, which the finish path degrades permissively. Added `_pr_view_probe` returning `(view, timeout_message)` and `_pr_merge_verification` returning `(merged, timeout_message)`; `_pr_view`/`_pr_is_merged` stay as thin wrappers for the dry-run preview and other callers. `_branch_merge_state` grew a fourth state, timeout, kept distinct from unknown.

**Per-site policy.**
- gh pr list, the gate view, gh pr merge, rev-parse x2, rev-list: abort, naming the timeout and the command. No degradation into the no-PR arm and no merge attempted on an unread gate.
- the merge itself: the report says whether it landed is unknown and points at the 155-29 retry. It does not blame unmerged code.
- the post-merge verification: aborts (finish genuinely has no confirmation) but says the merge command completed and confirming the result timed out. The step-2 record names the PR and carries merge_command_completed rather than any merged boolean, so nothing asserts merged False for a merge that landed.
- step 5 and step 6: recorded as warnings, not fatal, story stays done, session still removed. Step 6 stops the cleanup chain at the first timeout rather than running a pull and a branch delete that assume the checkout landed.

**Folded AC.** Kept the broad fallback (155-16 still forbids anything escaping post-merge) and made it loud: binds the exception, prints a marked WARNING to stderr, and records a step "3a" status_read entry naming the error. Chose "keep and make loud" over narrowing because the reason 155-16 kept it is unchanged — this read runs after the irreversible merge, and an exotic exception escaping is strictly worse than a loud degradation.

**Handoff:** To Reviewer.

## Subagent Results

Eight specialists spawned. All received: Yes — all eight returned before the verdict was finalized.

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none — every Dev claim reproduced: 18/18 story file, suite exit 0 at 5662/4/7 with zero xpassed, ruff clean on the changed file, package count unchanged at 86, both commits good-signature, tree clean, and the subprocess audit found exactly one invocation, inside the helper | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 4: truthiness-as-flag on the probe pair; non-zero exits unguarded in step 6; reserved-kwarg collision in the run helper; stale state contract in the 162-4 test docstring. Cleared three seams explicitly — the sentinel type survives all normal value flow, the fourth state's single consumer dispatches exhaustively, and no downstream logic gates on the step 5 record | CONFIRMED 1, 2 and 4 (recorded MEDIUM/MEDIUM/LOW). DOWNGRADED 3 to note: the kwarg collision is pre-existing and unchanged, and no call site or test triggers it |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 5: OSError escaping the helper; step 5 reporting that it ran on a non-zero exit; step 6 ignoring non-zero exits; the two bridge transitions unchecked after the loud degradation; the dry-run preview degrading permissively | CONFIRMED all 5, and verified four of them are PRE-EXISTING on base develop rather than introduced — the diff strictly improves each. Recorded MEDIUM/defer. The bridge-transition gap is real but outside the AC, which asked for loudness at the read, and it is 155-16 behavior untouched here |
| 4 | reviewer-test-analyzer | Yes | findings | 6: the gate test never asserts the merge did not run; no coverage for an empty timeout message, for OSError, for a non-timeout step 6 failure, or for dry run at all; the AST locator couples to a local variable name. Cleared two of my sharpest questions — the fake re-exports the REAL exception class so the except clause behaves identically to production, and the ledger correctly rejects an unbounded override; also cleared the branch-name stripping as correctly scoped rather than masking | CONFIRMED the gate-test gap (MEDIUM) and the coverage gaps (LOW). Its harness and ledger clearances are load-bearing to my verdict and I reproduced the exception-class point independently |
| 5 | reviewer-type-design | Yes | findings | 5: unparameterized generic base; unconstrained predicate annotation; truthiness-as-flag on both probe returns; the stringly-typed state dict; lossy narrowing in the two thin wrappers | CONFIRMED the truthiness finding as the highest-value item, matching two other specialists independently (MEDIUM). The rest recorded LOW — no type checker is configured in this repo, which I verified, so none of them gates anything. The stringly-typed dict was NOT dismissed: recorded and downgraded because it predates this story and its consumer is exhaustive |
| 6 | reviewer-simplifier | Yes | findings | 3: the already-merged wrapper is now callerless in production; four constant names share one value; three structurally identical abort blocks | CONFIRMED the callerless wrapper and the stale docstring around it (LOW). DECLINED the constants collapse and the abort-block extraction: the visible tiering block is what TEA specified so the trade-off stays reviewable, and the distinct abort prose is the truthfulness contract this story is about — collapsing it would make the messages harder to audit, not easier |
| 7 | reviewer-security | Yes | findings | 2 low, plus four focus areas explicitly cleared: no shell invocation anywhere and list-form argv throughout; the re-entrant subcommand uses the absolute interpreter path so it bypasses PATH entirely; and the bounds reduce worst-case hang from unbounded to two minutes per call rather than adding a hazard. Its most valuable observation is one no other specialist made: the helper sets the sentinel's stderr to the exception's own text and DISCARDS the partial child stderr, which is exactly what keeps gh auth output and credential-helper chatter out of the operator-facing report | CONFIRMED the unguarded base value on checkout and pull as PRE-EXISTING and LOW. Recorded the discarded partial stderr as a LOW trade-off note. On the repr choice I recorded a counter-rationale rather than a finding — see below. Its suggested fix for the checkout guard is WRONG and must not be applied blindly; flagged for Dev |
| 8 | reviewer-rule-checker | Yes | clean | 29 rules across three sources, 51 instances, ZERO violations. Confirms both changed files are regular files inside the dist package and not symlinks or never-edit paths, and that all ten new no-throw surfaces satisfy rule 6 | ACCEPTED. It also settles the one rule question I had open by quoting the checklist text: the logging-correctness check is scoped to modules that import a logging framework, and this module imports none, so the new stderr write is not a violation. I therefore withdrew my own provisional note on it |

## Reviewer Assessment

**Verdict:** APPROVED

No Critical and no High findings. Every AC is met, and every claim Dev made was independently reproduced rather than taken on trust.

### Verified independently

**Suite and hygiene.** Story file 18/18. Full suite exit 0 at 5662 passed, 4 skipped, 7 xfailed — the expected loud 162-5 xfails — 0 failed and ZERO xpassed. Ruff clean on the changed file; package-wide count unchanged at 86 in untouched files. Both commits carry good GPG signatures. Working tree clean.

**Every invocation is bounded, structurally.** The whole module contains exactly ONE call into subprocess, at story_finish.py:282, inside the run helper. Zero call sites bypass it. The bound is a keyword-only parameter with a bounded default, so the property holds for the twelfth call site as well as the eleven audited. This is the right shape: it converts an audit into an invariant.

**The isinstance discrimination is sound, and Dev's rationale for rejecting a marker attribute is correct.** Probed directly: the predicate answers False for a MagicMock and False for a plain CompletedProcess carrying returncode 124, and True only for the dedicated subclass. It is also not gameable across the fake seams — the harness's fake subprocess module re-exports the REAL TimeoutExpired class, so the except clause in the run helper resolves to the same class in test and in production. A getattr marker probe would indeed have read every mocked result in the sibling finish suites as timed out. The type-based sentinel survives assignment, return and copy; there is no path that strips it.

**Truthfulness of the timeout arms — read, then traced.** Pre-done arms (branch-to-PR probe, gate view, merge, the two rev-parse probes, rev-list) all abort naming the command; none degrade into the no-PR arm. The gate abort returns before the merge loop is entered, so no merge is attempted on an unread gate. The merge arm says the landed state is unknown and points at the retry; I confirmed the 155-29 already-merged short-circuit it relies on genuinely exists at story_finish.py:968 and is driven by the gate probe on the re-run, so the advice it gives is accurate rather than aspirational. The verification arm carries `merge_command_completed` and NO `merged` key, and its prose says the merge command completed while confirming the result did not — it never asserts the PR failed to land. The state field on the branch-verification helper gained a fourth value kept distinct from unknown, and its one consumer dispatches all four explicitly with a catch-all else, so nothing falls through silently.

**Loudness is actually wired to the operator.** This is the check that mattered most, and it passes: the CLI renderer at sprint/cli.py:495-497 reads a step's `warning` and `error` keys and echoes them. Every new non-fatal entry — the step 5 record, the step 6 record, and the "3a" status-read record — carries `action` and `warning`, so all three render. The folded AC is satisfied twice over: the broad handler binds the exception, writes a marked line to stderr, and records a rendered step naming the error with its type.

**Deviation audit — ACCEPTED.** Stopping the step 6 chain at the first timeout is not merely defensible, it is safer than the spec text. After a hung checkout the process is still on the feature branch, so pulling the base there would merge base into the feature branch and the branch delete would target the branch currently checked out. The ceremony-level contract the spec cared about is honored: finish still succeeds, the story stays done, step 7 still removes the session. No undocumented deviations found.

### Findings — all non-blocking, none introduced as a live defect

| Severity | Issue | Location | Disposition |
|----------|-------|----------|-------------|
| MEDIUM | [TYPE] [TEST] The timeout signal from the probe pair travels as an optional STRING whose truthiness is the flag, and both consumers test truthiness rather than identity. An empty message collapses a timed-out probe back into the permissive unknown arm — the exact degradation this story exists to remove. NOT reachable today: the only construction site passes the exception's own text, which CPython never renders empty. Confirmed by probe: feeding an empty message yields a falsy second element and both consumers fall through. Latent invariant, not a shipped bug. | story_finish.py:325, consumers at 913 and 1088 | Defer — fix is identity instead of truthiness at two lines; fold with 162-20, which reworks these same probe seams |
| MEDIUM | Dry-run preview still routes a hung gate probe through the permissive wrapper, so it previews a merge it cannot promise while the real run now aborts at that same probe. Dev's Question CONFIRMED. This diff WIDENS the 155-31 preview/reality parity gap: before it, preview and reality were both permissive; now reality aborts and only the preview guesses. No side effects, no AC, no test. | story_finish.py:858 | Defer — fold into 162-20, which already covers the dry-run path never evaluating the block-reason gate. Same arm, same fix |
| MEDIUM | Non-timeout, non-zero exits in step 5 and step 6 are still discarded: step 5 records that it ran when the subcommand failed, and step 6 continues the chain past a fast checkout failure — the case Dev's own deviation rationale argues against. PRE-EXISTING; base develop discarded these results entirely, so this diff strictly improves the situation without finishing the job. | story_finish.py:682-695, 1499-1512 | Defer — one elif per site, mirroring the timeout arms |
| MEDIUM | The run helper still lets OSError and FileNotFoundError escape, so a missing gh binary or broken PATH strands the ceremony with a traceback instead of a result object, in violation of rule 6. PRE-EXISTING and unchanged, but this story rewrote the very helper where the fix belongs. | story_finish.py:281 | Defer — fold with Dev's shared bounded-subprocess helper finding; catch OSError alongside |
| MEDIUM | [TEST] Test strength gap: the gate-timeout case asserts the abort outcome but never asserts the merge did not run, and the predicate hangs ALL views — so a gate that silently fell through and then aborted at the post-merge verification would satisfy every current assertion identically. The implementation is correct; the guard is weaker than the claim it protects, and it is exactly the guard that would have to catch the truthiness collapse above. | test_162_9_finish_subprocess_timeouts.py:808 | Defer — one added assertion |
| LOW | [TEST] Uncovered paths: dry run is not exercised at all by this suite, the step 6 non-timeout failure is untested, and the fourth state on the branch-verification helper is only reached through the ceremony, never directly. | test file | Defer |
| LOW | [TYPE] The predicate parameter is annotated as unconstrained, and the sentinel subclasses an unparameterized generic. No type checker is configured in this repo, so neither gates anything. Also [TYPE]: the branch-verification helper's state field is a bare string with four magic values — flagged against the no-stringly-typed-state rule and NOT dismissed, only downgraded, because the dict predates this story and its single consumer dispatches all four explicitly with a catch-all else. | story_finish.py:243, 254, 536 | Defer |
| LOW | The already-merged boolean wrapper now has NO production caller — its last one became the verification pair. It survives only in sibling test imports, and the wrapper docstring's claim about its remaining callers is stale. The contract docstring in the 162-4 test file still lists three states, not four. | story_finish.py:387; test_162_4 file docstring | Defer |
| LOW | [SEC] The base branch value reaches checkout and pull with no double-dash guard, while the branch delete added here does carry one. PRE-EXISTING; the value comes from operator-controlled repo config, so exploitability is negligible and this is a consistency gap. WARNING FOR DEV: the reviewing specialist's suggested fix is wrong — a double dash before a branch name turns checkout into a PATH checkout, which is a different and destructive command. The correct forms put the separator after the ref or use the switch subcommand. | story_finish.py:673-675 | Defer, and do NOT apply the suggested patch as written |
| LOW | [SEC] The helper discards the partial child stderr buffered before the bound expired, keeping only the exception's own text. That is what prevents gh auth output leaking into reports, but it also drops the most diagnostic bytes an operator would want for a hang. Deliberate-looking trade, worth a comment at minimum. | story_finish.py:284 | Note |
| LOW | Four constant names share the value 120.0. This is the reviewable tiering TEA specified, so the duplication is intentional documentation of independent knobs rather than drift. | story_finish.py:228-236 | Note only, no change wanted |

### Security [SEC]

No Critical, High or Medium security findings. Explicitly cleared: no shell invocation anywhere in the module and list-form argv throughout, so none of the values flowing from the session file or repo config into a command can be interpreted as anything but an argument; refs are passed in fully-qualified form; the re-entrant subcommand uses the absolute interpreter path and therefore does not trust PATH. The new messages echo only the exception's own text, not captured child output, so gh auth failures and credential-helper chatter cannot reach the report.

### Dismissed, with rationale

[RULE] Nothing that matched a stated project rule was dismissed — the rule check returned ZERO violations across 29 rules over 51 instances, spanning both repos' critical rule blocks and the python lang-review checklist. Both changed files are confirmed regular files inside the dist package, not symlinks and not in a never-edit zone, so the source-of-truth rules hold. All ten new no-throw surfaces satisfy the result-object rule.

- **The repr-versus-str choice in the post-merge status handler** was raised as a possible info-leakage pattern. Recorded as a NON-finding rather than deferred: repr is the CORRECT choice in this exact handler. It is the catch-all for exotic exception types, and the specific failure it must report is one whose type the operator cannot otherwise guess. An exception with an empty or uninformative string form — precisely the kind that reaches a catch-all — would produce a warning naming nothing at all under str. Naming the type is the point. No concrete leak was identified, and the values in scope are sprint bookkeeping, not secrets.
- **My own provisional note that the new stderr write is a layering smell** was withdrawn after the rule-checker quoted the logging-correctness check and showed it is scoped to modules importing a logging framework, which this module does not. TEA also sanctioned stderr as an acceptable loud channel. Not a finding.
- **The reserved-kwarg collision in the subprocess helper** was downgraded to a note, not dismissed: it is pre-existing and unchanged, no call site or test triggers it, and the only reachable consequence is a loud error at a call site that does not exist.

**Handoff:** To SM for finish.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Improvement** (non-blocking): the `_TimedOutProcess` / `_timed_out` pair plus the bounded `_run` default is a general shape, and TEA's Gap above says the unbounded pattern recurs across the package. Affects `pennyfarthing-dist/src/pf/` broadly (lifting these three pieces into a shared bounded-subprocess helper would let the other modules adopt the bound without re-deriving the timeout-as-result decision, including the isinstance-not-getattr detail that MagicMock forces). *Found by Dev during implementation of 162-9.*
- **Question** (non-blocking): the dry-run preview still routes a timed-out gate probe through the permissive `_pr_view`, so a hung probe previews a merge it cannot actually promise. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (the 155-31 preview/reality parity contract may want the preview to say "could not read the PR state" rather than silently assuming not-merged). Left alone here because no AC or test covers it and dry run has no side effects. *Found by Dev during implementation of 162-9.*

### Reviewer (code review)
- **Gap** (non-blocking): the probe pair signals a hung call with an optional string whose truthiness is the flag, and both consumers test truthiness. An empty message silently collapses a hung probe back into the permissive unknown arm — the degradation this epic exists to remove. Unreachable today because the sole construction site passes the exception's own non-empty text, so this is a latent invariant rather than a shipped bug. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (consumers should test identity instead of truthiness, or the pair should return a separate boolean; the same seam 162-20 reworks). *Found by Reviewer during code review of 162-9.*
- **Conflict** (non-blocking): CONFIRMS Dev's Question and sharpens it — this story widens the 155-31 preview/reality parity gap rather than merely leaving it. Before this diff the preview and the real run were both permissive about an unreadable gate probe; now the real run aborts and only the preview still guesses a merge. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (the dry-run arm should route through the probe and preview the abort — the same arm and the same fix as backlog 162-20, which already covers the preview never evaluating the block-reason gate; fold them). *Found by Reviewer during code review of 162-9.*
- **Gap** (non-blocking): the post-done arms now surface hung commands but still discard non-zero exits — step 5 reports that it ran when the subcommand failed, and step 6 continues its chain past a fast checkout failure, which is the case Dev's own deviation rationale argues is unsafe. Pre-existing, and strictly improved by this story. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (one branch per site, mirroring the timeout arms). *Found by Reviewer during code review of 162-9.*
- **Gap** (non-blocking): the subprocess helper still lets OSError escape, so a missing gh binary strands the ceremony with a traceback instead of the result object rule 6 requires. Pre-existing, but this story rewrote the exact helper where the fix belongs. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (fold into the shared bounded-subprocess helper Dev proposes above: catch OSError alongside the timeout and return the same failure shape). *Found by Reviewer during code review of 162-9.*
- **Improvement** (non-blocking): the pre-merge gate test asserts the abort outcome but never asserts the merge did not run, and its predicate hangs every view — so a gate that fell through and aborted later at the verification would satisfy every assertion identically. Affects `pennyfarthing-dist/src/pf/tests/test_162_9_finish_subprocess_timeouts.py` (one ledger assertion pins the property the story claims). *Found by Reviewer during code review of 162-9.*
- **Gap** (non-blocking): the base branch value reaches checkout and pull with no double-dash guard while the branch delete added by this story does carry one. Pre-existing and negligible in practice — the value comes from operator-controlled repo config. Recording it mainly to carry a warning: the obvious-looking fix is wrong, because a double dash placed before a branch name turns checkout into a path checkout, a different and destructive command. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (put the separator after the ref, or move to the switch subcommand). *Found by Reviewer during code review of 162-9.*

### TEA (test design)
- **Gap** (non-blocking): the unbounded-subprocess pattern is not confined to the finish path. Other modules shell out through their own local helpers with no timeout while pipeline_replay/demo/mermaid do pass one. Affects the pf package broadly (a shared bounded-subprocess helper, rather than a per-module fix, would stop this recurring). *Found by TEA during test design for 162-9.*
- **Improvement** (non-blocking): a timed-out gh probe and a gh probe that errored are the same "unknown" to `_pr_view` today, but they are operationally different — an error is a fact about one call, a timeout predicts the next call will hang too. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (the permissive-unknown degradation contract may deserve a documented distinction beyond this story's scope). *Found by TEA during test design for 162-9.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### Dev (implementation)
- **Post-done step 6 stops the cleanup chain at the first timeout instead of attempting all three commands**
  - Spec source: 162-9 session, TEA design call 5 ("Post-done timeouts are recorded, not fatal")
  - Spec text: "Record a warning, keep going, still remove the session in step 7."
  - Implementation: the warning is recorded and step 7 still removes the session, but the two remaining cleanup commands are skipped rather than run.
  - Rationale: "keep going" is honored at the ceremony level (finish still succeeds, story stays done, session removed). Within step 6 the three commands are sequentially dependent — pull and branch-delete both assume the checkout landed, and a delete aimed at the branch we are still standing on fails anyway. Running them after a hung checkout produces two more failures that say nothing new.
  - Severity: minor
  - Forward impact: none — no sibling story reads step 6's internals; the step entry shape is unchanged apart from the added warning key.
  - **Reviewer audit: ACCEPTED.** The rationale is correct and the deviation is safer than the spec text, not merely equivalent. After a hung checkout the process is still standing on the feature branch: pulling the base there would merge the base INTO the feature branch, and the delete would target the branch currently checked out. The contract the spec text was protecting is honored at the level it meant — finish still succeeds, the story stays done, step 7 still removes the session. Noted separately above: the same argument applies to a fast non-zero checkout failure, which still does not stop the chain.

### Reviewer (audit)
- No undocumented deviations found. The implementation matches TEA's designed interface on all seven points, including the constants block, the helper-level default, the envelope on the values, and the abort-versus-record split either side of the done transition.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->