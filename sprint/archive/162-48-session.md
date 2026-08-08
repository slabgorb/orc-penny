---
story_id: "162-48"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-48: 162-25 follow-ups: guard _git_cleanup bare base argv (checkout/pull at story_finish.py:815-816, last unguarded argv in file, 162-4 class); de-hardcode origin remote (third deferral); harden timeout-arm test to subprocess-level patching asserting state==timeout; precise diagnosis for refname-legal non-branches (HEAD, @, self-prefixed)

## Story Details
- **ID:** 162-48
- **Jira Key:** (none — kanban-only)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-48-git-cleanup-argv-hardening
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-08T14:04:38Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-08T12:16:50Z | - | - |

## Tea Assessment

RED established. 34 failing tests, 9 green-on-arrival regression pins, no
collateral damage (full finish-family sweep: 35 fail / 1512 pass, every
failure inside the new file). Commit `2947380bf`, signed.

### Test files

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/tests/test_162_48_cleanup_argv_and_remote.py` | New — 43 tests, all four AC items |
| `pennyfarthing-dist/src/pf/tests/test_162_25_revision_operator_branch_values.py` | Item 3 — `TestTimedOutValidationIsNotMerged` hardened in place |
| `pennyfarthing-dist/src/pf/tests/test_153_2_skip_branch_creation.py` | Relaxed exact cleanup-argv equality; mock now returns rc=0 |

The full AC record is the new file's module docstring (155-13 precedent — the
sprint YAML carries only a title). Ground truth for every claim was probed
against git 2.54.0 and is re-asserted in-test as a fixture premise, so a git
version that changes its grammar fails loudly rather than passing for the
wrong reason.

### Item 1 — the bare base argv in `_git_cleanup` (story_finish.py:815-816)

`base = repo_config.default_branch` is a hand-edited repos.yaml value reaching
git as `["git","checkout",base]` and `["git","pull","origin",base]`. The
`git branch -d --` line three lines below already carries `--`; these do not.
Three verified consequences:

- **Flag position.** `default_branch: -f` makes it `git checkout -f`, which
  silently discards every uncommitted modification in the story repo (probed:
  rc=0, no output, working tree reverted). The RED run shows `git checkout -f`
  genuinely executing.
- **Pathspec DWIM.** With no branch of that name, `git checkout notes.txt`
  restores the indexed copy over the operator's edit and answers rc=0. Test
  `test_base_naming_a_tracked_path_does_not_discard_local_edits` runs the real
  helper against a real repo and shows the edit destroyed.
- **The chain never stops.** The loop breaks only on `_timed_out`, so a
  checkout that fails outright is unrecorded and the pull plus branch delete
  run anyway — and the returned entry has no `warning`, so the finish report
  reads as a clean step 6.

Tests: `TestCleanupRefusesAnUnusableBase` (8 params),
`TestCleanupNeverTouchesTheWorkingTree`,
`TestCleanupArgvIsGuardedForAGoodBase` (2),
`TestCleanupStopsWhenTheBaseBranchIsMissing`.

### Item 2 — the hardcoded `origin` remote (third deferral)

`RepoConfig.remote` already exists but holds a **clone URL**, so a remote NAME
needs its own field. In a repo whose remote is not named `origin`,
`refs/remotes/origin/<base>` never resolves, the base arm falls back to the
stale local `refs/heads/<base>`, and a branch that landed upstream reads
`unmerged` — a loud false abort on a story that is done. `git pull origin
<base>` also fails outright, unchecked.

Tests: `TestRepoConfigCarriesARemoteName` (3),
`TestCleanupPullsFromTheConfiguredRemote`, `TestRemoteNameIsValidated` (6),
`TestMergeStateProbesTheConfiguredRemote` (2),
`TestFinishPassesTheConfiguredRemoteThrough`.

The last one is the 162-6 lesson restated: a correctly parameterised helper is
worthless if the call site keeps passing the root's answer. It drives
`finish_story` on an `upstream`-remote fixture and asserts the no-PR gate
forwards the story repo's configured remote to the probe.

### Item 3 — the timeout-arm test was a shallow mock

The 162-25 test patched `story_finish._run` and returned a hand-built
`_TimedOutProcess`, then accepted `state in {"timeout","unknown"}`. The mock
stood in for the code under test (`_run`'s real `TimeoutExpired` →
`_TimedOutProcess` conversion was never exercised) and the `or unknown`
escape hatch would have passed a timeout misrouted into the permissive arm —
the one thing 162-9 forbids. Rewritten in place to patch at the
`subprocess.run` boundary and assert `state == "timeout"` exactly, with no
`count` and a reason carrying the real timeout text.

That half is **green on arrival** — the behavior was already right, the test
was not. The RED half is `TestTimeoutIsPinnedAtTheSubprocessBoundary::
test_cleanup_attempts_no_mutation_when_validation_times_out`: cleanup today
discovers a hung git by *running the mutating checkout first*.

### Item 4 — refname-legal values that are not branches

162-25 validates with `check-ref-format refs/heads/<value>` (refname mode,
deliberately not `--branch`, which refuses the dash-leading names 162-4 wants
classified and DWIM-expands `@{-N}`). Refname mode accepts three families that
are not branches. Probed:

```
git check-ref-format refs/heads/HEAD                    -> rc=0
git check-ref-format --branch HEAD                      -> rc=128
git check-ref-format refs/heads/@                       -> rc=0
git check-ref-format refs/heads/refs/heads/feat         -> rc=0
git rev-parse --verify --quiet refs/heads/HEAD          -> rc=1
```

None resolves once prefixed, so all three fall through to `"branch not found
locally or on origin"` — 162-25's AC-2 failure mode verbatim, on the family
its own validator does not cover. It sends the operator hunting a deleted
branch when the fix is a malformed field. In cleanup they are worse than
imprecise: `git checkout HEAD` and `git checkout @` succeed without leaving
the feature branch, so the pull that follows lands the remote's default branch
on top of it.

Tests: `TestRefnameLegalNonBranchesAreRefusedPrecisely` (8).
`test_the_families_do_not_share_one_reason` compares the prose with the quoted
value stripped out, so it pins genuinely distinct diagnoses rather than one
template with a different value substituted.

### Interface Dev must implement

1. `pf.git.repos.RepoConfig` gains `remote_name: str = "origin"`, parsed from
   the `remote_name` key in repos.yaml. `remote` keeps its meaning (clone
   URL). `upstream_ref` becomes
   `f"{self.remote_name or 'origin'}/{self.default_branch}"`.
2. `_branch_merge_state(repo_path, branch, base=None, *, remote=None)` — new
   keyword-only `remote`; `None`/empty means `"origin"`. Every remote-tracking
   candidate becomes `refs/remotes/{remote}/{name}`. Return contract unchanged.
3. The finish call site (story_finish.py:1313) passes
   `remote=repo_config.remote_name if repo_config else None`, exactly as it
   already passes `base`.
4. One shared validator, used by both functions, refuses: anything
   `check-ref-format refs/heads/<value>` rejects (today's rule, unchanged);
   `HEAD` and `@`; any value whose first path component is `refs`.
   `_git_cleanup` is **stricter** — it additionally refuses a dash-leading
   `base` and validates the remote name the same way. The asymmetry is
   deliberate and has its own regression pin: 162-4 keeps dash-leading names
   classifiable on the read path (a probe can prefix them into
   `refs/heads/-evil`), but no `git checkout` argv reaches one safely.
   The refusal reason quotes the value verbatim (never an internally prefixed
   form), says it is not a valid branch name, and distinguishes its family.
5. `_git_cleanup`, on any refusal or validation timeout, emits **zero** git
   subprocesses and returns one entry:
   `{"step": 6, "action": "git_cleanup", "branch": branch, "warning": "<reason quoting the offending value>"}`.
   For an accepted base it confirms the base branch exists before checking it
   out, and stops the chain (no pull, no delete) with a `warning` when it does
   not. The checkout argv carries `--`; the pull argv carries the base as a
   qualified `refs/heads/<base>` or after a `--`, never a bare rev.

### Rule Coverage

`.pennyfarthing/gates/lang-review/python.md` checks exercised: unvalidated
external input reaching a subprocess argv (items 1, 2, 4 — the whole file);
no-throw result contract (`_git_cleanup` returns entries, never raises, even
on a validation timeout); bounded subprocess (item 3, now pinned at the real
`subprocess.run` boundary); no silent skip (every refusal must carry a
`warning` the finish report can surface). Test-quality self-check: no
`assert True`, no bare `let _`-equivalent, no `is_none()` on an always-None
value; every argv assertion runs against a real git repo through a
delegating spy rather than a fake that would make it tautological.

### Notes for SM

- The session arrived in phase `setup`, not `red`, so the workflow phase was
  repaired before the exit protocol. Flagged rather than papered over.
- Two-cwd suite runs must stay serial (concurrent pytest races
  `test_pypi_packaging`'s wheel-build dir). Both runs above were serial.

## Dev Assessment

GREEN. All 43 tests in the new file pass (34 that were RED, plus the 9
green-on-arrival pins, still green). Finish-family sweep: 1888 passed, 0
failed. Full suite: 6401 passed, 4 skipped, 9 failed — the same 9 fail on the
pre-change tree (verified by stashing the diff and re-running the three files:
identical `9 failed, 38 passed`), all of them workflow-list/CLI-discovery
tests that resolve no workflows from the `pennyfarthing/` cwd. Untouched by
this story.

### Files changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/git/repos.py` | `RepoConfig.remote_name` field + parse; `upstream_ref` honors it |
| `pennyfarthing-dist/src/pf/sprint/story_finish.py` | `_classify_branch_name` validator; `_branch_merge_state(*, remote=)`; `_git_cleanup` validate-probe-then-mutate; call-site wiring |

### Item 1 + 4 — one validator, two strictness levels

`_classify_branch_name(value, cwd, *, allow_dash_leading=True)` returns
`(verdict, detail)` where verdict is `ok` / `refused` / `timeout`. The three
in-process families run BEFORE the `check-ref-format` subprocess — that
ordering is what makes cleanup's "zero git subprocesses on refusal" a property
of the function rather than an audit of its branches:

- `HEAD` / `@` → `git's own alias for the current checkout, not a branch`
- first path component `refs` → `this field must hold a bare branch name, not a full ref path`
- dash-leading, only when `allow_dash_leading=False` → `a dash-leading value reaches git's argv as a flag`
- otherwise `check-ref-format refs/heads/<value>` unchanged → `git check-ref-format rejected it`

The call site composes the prose and does the quoting, so the value is quoted
verbatim and never in its internally prefixed form. That is also what lets the
remote name reuse the same validator while reading as `remote name 'X' is not
usable (...)` instead of claiming it is not a branch name.

The dash asymmetry is the knob, not two code paths: the read path passes the
default and keeps classifying `-evil` (162-4), cleanup passes
`allow_dash_leading=False`. Both regression pins hold.

### Item 1 — cleanup is now validate → read-only probe → mutate

Order in `_git_cleanup`: validate `base`, validate `remote`, `rev-parse
--verify --quiet refs/heads/<base>`, then the three mutations. Every early
return goes through one local `stopped(reason)` closure, so there is exactly
one output shape for "step 6 did not run and here is why" and no path can
return a clean-looking entry. Argv now reads `git checkout <base> --` and
`git pull <remote> refs/heads/<base>`.

The existence probe is what closes AC-3b as a side effect: cleanup's first
subprocess is read-only, so a hung git is discovered there rather than by the
mutating checkout.

### Item 2 — the remote name

`remote_name` is a new field rather than a reinterpretation of `remote`, which
holds the clone URL. Parsed as `data.get("remote_name", "") or "origin"`, so a
key that is absent, empty, or explicitly null all mean `origin` and every
repos.yaml in the wild is byte-for-byte unchanged in behavior.
`_branch_merge_state` normalizes with `(remote or "").strip() or "origin"`,
which also keeps `refs/remotes//<name>` unconstructible.

Both not-found reason strings now name the actual remote rather than the word
origin — a probe that looked at `upstream` must not tell the operator it
looked at `origin`. Only the substring `not found` is asserted anywhere, and
that survives.

### Item 3

Green on arrival for the read-path half, as TEA described. The cleanup half is
closed by the read-only probe above.

### For the Reviewer

- The checkout return-code check is the one thing I added beyond the literal
  interface — logged as a deviation below with the reasoning.
- `_git_cleanup` validates the remote name with a BRANCH-name validator.
  Correct for every value the tests cover, and it keeps one gate; a genuinely
  remote-specific grammar (git's own remote-name rules are narrower) would be
  a second rule to keep in sync. Worth a second opinion.
- `pf.settings.validators.validate_repo_field` has no field whitelist that
  needed `remote_name` added, so `pf sprint`/`pf git` writers are unaffected —
  but I only grepped for one field name to establish that.
- Pre-existing `ruff format` drift in `story_finish.py` (line-collapse
  suggestions throughout, none of them mine after the one fix). Left alone
  rather than reformatting 1700 lines inside a bugfix. `ruff check` is clean.

## Subagent Results

**Cycle: 0** (first review, no completed rework round-trips).

This review ran in the main session (peloton stopped by the Client), so the
five ENABLED `reviewer-*` specialists WERE spawnable and were dispatched in
parallel as background analysts. The four disabled-by-settings specialists are
recorded as Skipped per `workflow.reviewer_subagents`, and their lanes were
covered by the Reviewer directly (noted in-row).

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 43 new-file pass; 1521 finish-family, 0 fail; ruff clean; 8 pre-existing workflow-discovery fails orthogonal | confirmed 0 blocking |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings; boundary paths covered by Reviewer + test-analyzer mutation battery |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings; silent-skip class covered by Reviewer ([SILENT] below) |
| 4 | reviewer-test-analyzer | Yes | findings | mutation battery 8 killed / 2 survived (M1/M2 mutually masking); 153_2 relaxation legit; timeout rewrite legit | confirmed 1 (coverage), 0 blocking |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings; docstring overclaim caught by Reviewer ([DOC] F7) |
| 6 | reviewer-type-design | Yes | findings | F1 (non-str YAML crash) HIGH; verdict not Literal MEDIUM; dead fallback LOW | F1 folded; others deferred |
| 7 | reviewer-security | Yes | findings | F1 (non-str crash) MEDIUM; F2 (slash remote → local-path pull) MEDIUM; core hardening clean | F1+F2 folded |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings; no over-engineering seen by Reviewer |
| 9 | reviewer-rule-checker | Yes | clean | 13/13 python.md checks pass; F3 stale repos.yaml language config confirmed; pre-existing open()-encoding cluster | confirmed 0 blocking |

**All received:** Yes (5 enabled returned, 3 with findings; 4 disabled recorded Skipped)
**Total findings:** 2 confirmed-and-FOLDED (F1, F2), 4 confirmed-and-DEFERRED (F3, test-coverage, verdict-Literal, docstring), several pre-existing noted. 0 remaining blocking.

## Reviewer Assessment

**Verdict:** APPROVED

A blocking finding was found in the first pass (F1, a confirmed no-throw crash
introduced by this diff) and FOLDED in place before this verdict, per the
established pre-merge-fold pattern — the story never left the review phase, so
this is a single cycle-0 approval, not a rework round-trip. Fold commit
`6209d1a08` (GPG-signed, good sig). Everything below was re-measured against
this branch's source; nothing is taken from prose.

### The four ACs are delivered and correct, verified by execution

- **AC-1 (bare base argv):** `git checkout <base> --` closes pathspec-DWIM
  (`git checkout notes.txt --` → rc 128, edit preserved; bare form → rc 0, edit
  destroyed); the pull carries `refs/heads/<base>`, never a bare rev. No
  mutating argv takes an unvalidated hand-edited value. `[SEC]`
- **AC-2 (de-hardcoded remote):** threaded config → `_branch_merge_state` probe
  AND the pull; a branch landed on a non-`origin` remote reads `merged`
  end-to-end (`upstream`-remote fixture). Call site wires it exactly as it
  wires `base` (162-6 lesson). `[RULE]`
- **AC-3 (timeout arm):** the test now patches `subprocess.run`, so the real
  `TimeoutExpired → _TimedOutProcess` conversion is exercised, asserting
  `state == "timeout"` exactly (the permissive `or "unknown"` escape removed).
  `[TEST]`
- **AC-4 (refname-legal non-branches):** `HEAD`, `@`, `refs/…`-prefixed, and
  dash-leading each get a distinct, value-quoting diagnosis; zero subprocesses
  on the in-process refusals. Restored after catching a stray on-disk mutation
  (see process finding below). `[EDGE]` `[TYPE]`

### [TEST] Mutation battery, re-run by the specialist — 8 killed / 2 survived

The two survivors (remove checkout-rc stop; ignore existence-probe rc) are the
same fact twice: the base-existence probe and the checkout-rc stop are mutually
masking, so neither is independently pinned by the single missing-base test.
The behavior is correct with both present; the coverage is redundant, not
absent. Non-blocking, deferred to a follow-up (pin the checkout-conflict arm
directly).

### [SEC][TYPE] F1 — non-string YAML name field crashed the no-throw path — FOLDED

Reproduced first-hand against this branch's source: `remote_name: True` →
`_git_cleanup` raised `AttributeError: 'bool' object has no attribute 'strip'`;
`default_branch: 2` → `_branch_merge_state` raised `'int' object has no
attribute 'split'`. The `.split()` crash is INTRODUCED by this diff's new
`_classify_branch_name`. Two specialists flagged it (type HIGH, security
MEDIUM); I confirmed it and — with the Client's go-ahead — folded a one-line
`str(...)` coercion at the single ingestion point (`_parse_repo_entry`) for
both `remote_name` and `default_branch`. Post-fold both inputs coerce to a
string and flow to a proper `warning`/`unknown` result instead of raising. Pin
added and RED-verified.

### [SEC] F2 — slash-bearing remote name read as a local-path URL — FOLDED

Security probed end-to-end: `remote_name: subdir/evil` is a legal refname, so
the shared branch-name validator accepted it, but `git pull subdir/evil <ref>`
fetches from `./subdir/evil` if it is a repo, running its client-side hooks.
Folded a 4-line `_classify_remote_name` wrapper that refuses a slash-bearing
remote name before the shared grammar, wired into `_git_cleanup`'s remote slot.
The branch-name validator is unchanged (dash asymmetry intact). Pin added and
RED-verified. Ordinary single-token names (`upstream`) still reach the pull —
control test confirms no over-refusal.

### [RULE] Rule compliance — python.md walked (all 13 pass)

rule-checker walked all 13 `python.md` checks against the diff: 13/13 pass, no
violations introduced. No new bare `except`, no mutable defaults, full
annotations on the new surfaces, no silent error path (every refusal carries a
`warning`), argv is a list with no `shell=True`, `yaml.safe_load` throughout,
no resource/async/import findings. The `test_153_2` relaxation is a legitimate
de-coupling (its contract is "the three ops run", not the exact argv, now
pinned in this story) and the `CompletedProcess(returncode=0)` replacing a bare
`MagicMock` removes a real trap.

### [DOC] F7 — docstring overclaims "ZERO git subprocesses" on refusal

Non-blocking, deferred: the `check-ref-format`-rejected family costs one
read-only subprocess and a validation timeout costs one — the code and tests
are right, only the prose is imprecise ("zero MUTATING git commands" is the
accurate wording).

### [SIMPLE] No unnecessary complexity

The single validator with a strictness knob is the right shape (8/10 mutations
died); the new remote wrapper is 4 lines and testable in isolation. No dead
code introduced by the fold (the `or 'origin'` fallback in `upstream_ref`,
flagged LOW by type-design, is now belt-and-suspenders after the parse
coercion — left in as defensive, deferred).

### CRITICAL process finding — a review subagent left an on-disk source mutation

While running the fold's verification I found `_classify_branch_name` on disk
was MISSING its `if value in _NON_BRANCH_ALIASES` guard — the `HEAD`/`@` refusal
— which my new alias tests and the existing `TestRefnameLegalNonBranchesAreRefusedPrecisely`
caught (4 failures). `git diff HEAD` proved the two lines were deleted from the
working tree, not by any of my edits. The `reviewer-test-analyzer` ran a
10-mutation battery ("M8: remove HEAD/@ alias check") and, having only
Read/Bash/Glob/Grep (no Edit), evidently mutated the source ON DISK via Bash and
did not restore M8. Had I approved on the specialists' prose without re-running
the suite, this would have shipped a git-checkout hardening with its central
alias guard silently removed. I restored the two lines; the full working tree
now diffs against HEAD as ONLY the intended fold (audited). This is a
first-class pipeline defect (a review tool corrupting the code under review) —
filed as a follow-up, and it argues that mutation-testing subagents must operate
on a scratch copy or a git worktree, never the working tree.

### Re-measured numbers (post-fold)

| Claim | Measured | Method |
|-------|----------|--------|
| New test file | 47 passed (43 + 4 fold pins) | `pytest test_162_48_...` |
| Touched suites (162-48 + 162-25 + 153-2) | 110 passed, 0 failed | direct |
| Finish-family sweep | 1531 passed, 0 failed | `-k "finish or repos or 162 or 153"` serial |
| F1 repro | no raise; coerces to str; returns warning/unknown | in-process against branch source |
| ruff check | All checks passed | repos.py, story_finish.py, new test file |
| Pre-existing failures | 8–9 workflow-discovery, orthogonal to diff | preflight + Dev's clean-tree worktree |

### Why this lands

The three claims the story exists to make are true by execution: no mutating
argv takes an unvalidated value; the remote is threaded config→probe→pull and
the non-`origin` case works end to end; and the refname-legal non-branch
families get distinct diagnoses. The two real residual holes (F1 no-throw
crash, F2 slash-remote) were folded before landing with RED-verified pins; the
remaining findings are coverage/prose/config and are filed as follow-ups. The
diff is strictly monotonic and the working tree is audited clean.

`[EDGE]` `[SILENT]` `[TEST]` `[DOC]` `[TYPE]` `[SEC]` `[SIMPLE]` `[RULE]`

**Handoff:** To SM for finish-story.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->
- Gap (non-blocking, TEA): the session was handed over in phase `setup` rather
  than `red`; SM's phase advance did not happen. Repaired with
  `pf workflow fix-phase` before the RED exit protocol.
- Improvement (non-blocking, TEA): `test_153_2_skip_branch_creation.py`'s
  cleanup tests patched `_run` with a bare `MagicMock`, whose `returncode`
  compares unequal to `0`. Any story that adds a read-only probe ahead of
  cleanup's mutations silently turns those tests into "cleanup skipped".
  Pinned rc=0 explicitly here; the same latent trap likely exists in other
  `_run`-mocking suites.
- Improvement (non-blocking, TEA): `check-ref-format` in refname mode is now
  called from two places with two different strictness levels (read path vs
  cleanup). Worth one named helper rather than two call sites drifting apart.

### Reviewer (code review)

- **Improvement** (non-blocking): F1 no-throw crash on a non-string YAML name
  field — FOLDED in this review (commit `6209d1a08`). Follow-up only if the
  symmetric coercion should be extended to every `str`-annotated `RepoConfig`
  field. Affects `pf/git/repos.py`.
- **Improvement** (non-blocking): F2 slash-bearing remote name read as a
  local-path URL — FOLDED. A future strict remote-name grammar would extend
  `_classify_remote_name`. Affects `pf/sprint/story_finish.py`.
- **Gap** (non-blocking): F3 — `.pennyfarthing/repos.yaml` declares
  `language: javascript`/`typescript` for a Python-only framework (ADR-0034), so
  the lang-review gate never auto-attaches `python.md`; every Python review this
  epic has been checklist-blind. One-line config fix, high value. Affects
  `.pennyfarthing/repos.yaml` + the gate's language resolver.
- **Gap** (non-blocking): test coverage — the base-existence probe and the
  checkout-rc stop are mutually masking (mutation battery M1/M2); add a test
  that pins the checkout-conflict arm directly and one that asserts the
  existence probe runs before any mutation. Affects
  `pf/tests/test_162_48_cleanup_argv_and_remote.py`.
- **Improvement** (non-blocking): `_classify_branch_name` returns a
  stringly-typed `(verdict, detail)` against three module constants; a `Literal`
  return type would make a future 4th verdict a static error at the call sites
  rather than a silent mutation-proceeds fall-through. Affects
  `pf/sprint/story_finish.py`.
- **Improvement** (non-blocking): F7 docstring overclaims "ZERO git
  subprocesses" on refusal — the `check-ref-format`-rejected and timeout arms
  each cost one read-only subprocess. Prose only. Affects
  `pf/sprint/story_finish.py`.
- **Gap** (blocking-class PIPELINE defect, non-blocking to THIS story): a
  `reviewer-*` mutation-testing subagent left an on-disk source mutation
  (`_classify_branch_name`'s `_NON_BRANCH_ALIASES` guard deleted) that would
  have shipped had the Reviewer not re-run the suite. Mutation-testing subagents
  must operate on a scratch copy or git worktree, never the working tree.
  Affects the reviewer-test-analyzer subagent definition / review workflow.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Cleanup also stops the chain when `git checkout` returns non-zero, not only when the base is missing or a probe times out**
  - Spec source: `.session/162-48-session.md`, TEA's designed interface item 5
  - Spec text: "For an accepted base it additionally confirms the base branch
    exists before checking it out, and stops the chain (no pull, no delete)
    with a `warning` when it does not."
  - Implementation: the existence probe is exactly as specified, and the
    mutation loop additionally returns `stopped(...)` when the checkout's
    return code is non-zero.
  - Rationale: the existence probe closes the typo case but not the other way
    a checkout fails — a local modification that would be overwritten. Measured
    on git 2.54.0: `git checkout <base> --` with a conflicting dirty file exits
    1 and leaves the FEATURE branch checked out, at which point the next
    command in the chain, `git pull <remote> refs/heads/<base>`, merges the
    base's commits onto the feature branch. That is the same "the chain never
    stops on failure" defect item 1's third bullet names, on the arm the
    existence probe does not reach; leaving it would have shipped a known
    instance of the bug this story exists to remove. Two lines, one shared
    `stopped()` output shape, no new test needed to keep the argv assertions
    honest.
  - Severity: minor
  - Forward impact: none — no sibling story reads step 6's entry shape, and the
    warning uses the same wording as every other cleanup stop.
- **The remote name is validated by the branch-name validator rather than a remote-specific grammar**
  - Spec source: `.session/162-48-session.md`, TEA's designed interface item 4
  - Spec text: "`_git_cleanup` additionally refuses a dash-leading `base` and
    validates the remote name the same way."
  - Implementation: literally the same way — `_classify_branch_name(remote,
    cwd, allow_dash_leading=False)` — with remote-specific prose composed at
    the call site.
  - Rationale: this IS what the spec asked for; logged because "the same way"
    means a remote name is now checked against `check-ref-format
    refs/heads/<value>`, which is narrower than git's remote-name rules in
    principle and wider in others. It refuses every value AC-2e names (flags,
    `--upload-pack=`, whitespace, control characters, `refs/`-prefixed) and
    accepts ordinary names, and one gate cannot drift from itself.
  - Severity: minor
  - Forward impact: minor — a future story wanting a strict remote-name grammar
    should extend the one validator, not add a second call site.
### Reviewer (audit)

Both Dev deviations stamped:

- **Dev-1 (checkout rc!=0 also stops the chain)** → ✓ ACCEPTED by Reviewer:
  reproduced by execution (git 2.54.0) — a conflicting dirty file makes
  `git checkout <base> --` exit 1 and leaves the FEATURE branch checked out, so
  the following `git pull` would land the base's commits onto it. The existence
  probe cannot reach this arm (the base exists). Two lines through the one
  `stopped()` shape; the only gap is it had no independent test (deferred as a
  test-coverage follow-up, see mutation battery M1/M2).
- **Dev-2 (remote validated by the branch-name validator)** → ✓ ACCEPTED and
  EXTENDED by Reviewer: this was TEA's "the same way", verified to refuse the
  whole AC-2e adversarial set. The review fold (F2) tightens it: a
  `_classify_remote_name` wrapper now refuses a slash-bearing remote name BEFORE
  deferring to the branch grammar, because git reads `subdir/evil` as a
  local-path URL. The forward-impact note Dev wrote ("a future story wanting a
  strict remote-name grammar should extend the one validator") is exactly what
  the fold did.
- **Reviewer fold (F1 str-coercion + F2 slash guard)** → logged as a
  Reviewer-authored change under Client authorization; not a spec deviation
  (both close confirmed defects), recorded here for provenance. Commit
  `6209d1a08`.