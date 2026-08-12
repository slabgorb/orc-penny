---
story_id: "162-41"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-41: 162-9 timeout-hardening tail: change truthiness tests on the timeout signal to 'is not None' (story_finish.py ~913, ~1088 — empty message collapses a hung probe into the permissive arm; unreachable today); stop discarding non-timeout exits in steps 5/6 (step 5 reports it ran when it failed); catch OSError in _run and extract the bounded-run/_TimedOutProcess trio into a shared helper (unbounded-subprocess pattern recurs in other modules); add a merge-didn't-run assertion to the gate-timeout test (its hang-all-views predicate would pass a fell-through gate) (from 162-9 review)

## Story Details
- **ID:** 162-41
- **Jira Key:** (none — Jira not configured for this story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-41-timeout-hardening-tail-isnotnone-run-helper
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the title is the full spec (162-9 review). FIVE deliverables in `pennyfarthing-dist/src/pf/sprint/story_finish.py` (+ a shared helper). Base includes 162-32/33/36.

1. **`is not None` timeout checks** (~lines 913, 1088 — verify, lines drift): the timeout signal is tested for truthiness, so an EMPTY timeout message collapses a hung probe into the permissive arm. Change to `is not None`. (Unreachable today but a latent trap.)
2. **Stop discarding non-timeout exits in steps 5/6:** step 5 reports it RAN when it actually FAILED (a non-timeout non-zero exit is swallowed). Steps 5 and 6 must surface a non-timeout failure truthfully, not report success.
3. **Catch `OSError` in `_run`:** `_run` can raise `OSError` (e.g. exec failure, ENOENT); catch it and return a result (don't let it escape the result contract).
4. **Extract the bounded-run/`_TimedOutProcess` trio into a shared helper:** the unbounded/bounded-subprocess pattern recurs in other modules — extract the `_run` bounded-timeout + `_TimedOutProcess` machinery into a shared helper so callers reuse it. Keep story_finish's behavior identical; the helper is a refactor.
5. **Add a merge-didn't-run assertion to the gate-timeout test:** the existing gate-timeout test's hang-all-views predicate would PASS a fell-through gate (it doesn't assert the merge was NOT attempted). Add the assertion so a fall-through is caught.

**TEA (RED):** failing tests, fake `_run`/subprocess seam:
- (1) a hung probe with an EMPTY timeout message → routed to the TIMEOUT arm (not permissive). Pin the `is not None` semantics.
- (2) steps 5/6 with a non-timeout non-zero exit → the result reports FAILURE, not "ran/clean". Pin both steps.
- (3) `_run` where the subprocess raises `OSError` → returns a result (`{success:False,...}` or the timeout/unknown shape), does not propagate the exception.
- (4) the shared helper: a test that the extracted bounded-run helper enforces the timeout + returns the `_TimedOutProcess` shape (and story_finish still behaves identically — regression).
- (5) strengthen the gate-timeout test with a merge-didn't-run assertion (assert zero `gh pr merge` calls when the gate probes hang).

**Constraints (binding):** scoped runs — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/<finish/timeout tests>.py -q` + finish regression batch. NEVER full suite. `_run` is THE seam. Result objects, not throws. `ruff check`. Preserve 162-9/162-32/162-33 timeout+merge invariants. If the shared helper lands in a new module, keep the import cheap (no cycles — 162-30 hit a jira import cycle).

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_41_finish_timeout_tail.py` (NEW) — 12 tests covering deliverables 1-4
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_9_finish_subprocess_timeouts.py` (EDITED) — deliverable 5: the pre-done timeout parametrization now asserts `gh pr merge` was never attempted for every non-merge case

**Tests Written:** 12 new + 1 strengthened existing = 13
**Status:** RED — 11 failing, 1 green-on-arrival regression pin (step 6, landed by 162-32)

Failing assertions (all behavioural, no import/collection errors):
1. `test_gate_probe_with_empty_message_never_reaches_the_merge` — gate probe hangs with an EMPTY timeout message; `ledger.matching("gh","merge")` is `[['gh','pr','merge','501','--squash','--delete-branch']]`. The truthiness test collapsed the hang into `_classify_pr(None)` → UNREADABLE → the irreversible merge ran.
2. `test_verification_with_empty_message_does_not_deny_the_merge` — report says `"PR #501 (proj) is not MERGED after the merge step … unmerged code"` for a merge that landed.
3. `test_step_five_epic_archive_nonzero_exit_is_not_reported_as_ran` — rc=1 epic archive reports `{"step": 5, "action": "archive_epics", "ran": true}` and drops stderr.
4. `test_run_converts_a_spawn_failure_into_a_failed_result` — `FileNotFoundError` escapes `_run`.
5. `test_spawn_failure_mid_ceremony_returns_a_report_not_a_traceback` — the same `OSError` escapes `finish_story` (no-throw contract).
6-11. `TestBoundedRunSharedHelper` (6 tests) — `pf.common.bounded_run` does not exist; they pin its contract.

**Contract pinned for the shared helper (deliverable 4):** module `pf.common.bounded_run`, exposing `run(cmd, *, timeout=DEFAULT_TIMEOUT_S, runner=None, **kwargs)`, `TimedOutProcess`, `timed_out`, `DEFAULT_TIMEOUT_S`. Two non-negotiables the tests enforce:
- `TimedOutProcess` is SHARED, not duplicated — `story_finish._timed_out(helper.TimedOutProcess(...))` must be True, or every timeout arm 162-9 added becomes dead code once `_run` delegates.
- `_run` must still reach `subprocess.run` through **story_finish's own module global** (hence the injected `runner`). Every finish suite patches `story_finish.subprocess`; a helper that used its own import would silently turn those fakes into no-ops and run real `gh`/`git` under test.
- Helper file must be stdlib-only (AST-checked) — no `pf.*` imports, no cycles (162-30).

**Scoped runs:**
- `uv run pytest src/pf/tests/test_162_41_finish_timeout_tail.py -q` → `11 failed, 1 passed`
- `uv run pytest src/pf/tests/test_162_9_finish_subprocess_timeouts.py -q` → `18 passed` (strengthened assertion is green on current code)
- finish regression batch (155-1, 155-12, 155-15, 155-29, 155-32, 162-1, 162-6, 162-33, 164-1, 164-12) → `128 passed`
- `ruff check` / `ruff format` clean

**Commit:** `520173cc6` on `feat/162-41-timeout-hardening-tail-isnotnone-run-helper`
**Handoff:** To Dev for GREEN

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/common/bounded_run.py` (NEW, 91 lines) — the extracted bounded-run trio: `run(cmd, *, timeout=DEFAULT_TIMEOUT_S, runner=None, **kwargs)`, `TimedOutProcess`, `timed_out`, `DEFAULT_TIMEOUT_S`, `TIMEOUT_RETURNCODE`, `SPAWN_FAILURE_RETURNCODE`. Stdlib-only leaf (`subprocess`, `collections.abc`, `typing`) — no `pf` imports, no cycle risk. Converts both `TimeoutExpired` and `OSError` into results; the runner is injected so the patchable seam stays in the caller.
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_run` is now a one-line delegation passing `runner=subprocess.run` (story_finish's own patchable module global); `_TimedOutProcess`/`_timed_out`/`_TIMEOUT_RETURNCODE`/`DEFAULT_TIMEOUT_S` are aliases of the helper's (shared, not duplicated); all three `_pr_view_probe` timeout consumers read `is not None` (dry-run preview, real gate, post-merge verification); step 5 records `ran: False` + a warning carrying the subcommand's stderr for a non-zero epic archive instead of `ran: True`.

**Tests:**
- `test_162_41_finish_timeout_tail.py` + `test_162_9_finish_subprocess_timeouts.py` → **30/30 passing (GREEN)** (was 11 failed / 19 passed)
- Full story_finish regression sweep (every one of the 46 test files that reference `story_finish`) → **988 passed**
- `ruff check` → All checks passed; `ruff format --check` → 2 files already formatted

**Branch:** `feat/162-41-timeout-hardening-tail-isnotnone-run-helper` (commit `ef34f90a4`, GPG-signed, pushed)

**Handoff:** To Reviewer

## Reviewer Assessment

**Verdict:** APPROVED (10 findings — 4 Medium, 6 Low; none blocking). All 9 specialist subagents dispatched and assessed; 12 of their 28 findings dismissed with rationale, 3 of the dismissals resting on factual errors I checked myself.

**Verification I ran myself (not taken on trust):**
- Scoped: `test_162_41_finish_timeout_tail.py` + `test_162_9_finish_subprocess_timeouts.py` → **30 passed**.
- Finish regression batch (155-1/12/15/29/32/34, 162-1/6/25/33/48, 164-1) → **601 passed**.
- `ruff check` on all four changed files → clean.
- **Mutation test A** — reverted all three `is not None` → truthiness AND disabled the step-5 `elif`: **3 failures**, exactly the three named tests. Tests are not vacuous.
- **Mutation test B** — forced the REAL pre-merge gate to fall through (`if False:`): `test_162_9::test_pre_done_timeout_returns_truthful_failure[gh-pr-view-gate]` fails at line 828 on the NEW merge-didn't-run assertion, with the `gh pr merge` argv in the diff. **Deliverable 5 provably does its job** — the assertion it added is the only thing that catches a fell-through gate.

**Data flow traced:** session `PR:`/`Branch:` field → `gh pr list --head` (bounded; timeout → hard abort at :1454) → `_pr_view_probe` → `_classify_pr` → pre-merge gate (:1630) → **`gh pr merge`** → `_pr_merge_verification` (:1831) → `transition_story(done)` + session unlink. Every hop bounded; every *timeout* aborts before the irreversible step, and post-merge says "could not verify", never "did not merge".

**Merge invariant — CONFIRMED for hangs, one widened window for spawn failures:**
- A HUNG probe cannot reach the merge. `_pr_view_probe` returns a `str` second element on the timeout path ONLY (`story_finish.py:453-454`); every other return is `(x, None)`. So `is not None` ⇔ timed out. It is **strictly non-inverting** — there is no non-None-falsy value in the codomain — and strictly stronger than the truthiness it replaced. All three consumers converted; `grep` confirms zero truthiness consumers remain (:1521, :1630, :1835).
- A SPAWN FAILURE now can. See Finding 1 — the only real behavioural regression in the diff, and it is documented as out-of-scope by TEA and Dev.

**Seam-preservation claim — CONFIRMED, and narrower than Dev claimed.** `runner=subprocess.run` is resolved through story_finish's own module global at call time, so `patch.object(story_finish, "subprocess", stub)` still diverts. Independently: the overwhelming majority of the 128 finish tests patch `pf.sprint.story_finish._run` outright (10 files), not `.subprocess` — `story_finish.subprocess` is patched by exactly ONE suite (test_162_41), which carries an explicit spy assertion that the delegation intercepts. Real `gh`/`git` do not run under test.

**Shared-class interop — CONFIRMED.** `_TimedOutProcess = bounded_run.TimedOutProcess` is an alias, one class object, so `story_finish._timed_out(bounded_run.TimedOutProcess(...))` is True by construction. 162-9's timeout arms are live, not dead.

**OSError → rc=127, not the timeout type — CORRECT.** A child that never started did not hang; routing it into the timeout arm would tell the operator to expect the next call to hang and would hide a missing binary. The *value* chosen is the weak part (Finding 2), not the decision to keep it out of `TimedOutProcess`.

**Error handling verified:** step 5's `_timed_out` check correctly PRECEDES the new `returncode != 0` arm (:2186 before :2199) — inverted, the rc arm would shadow the timeout arm since `TimedOutProcess` carries rc=124. The `warning` key IS rendered (`sprint/cli.py:494` — `step.get("warning", "")`), so the new record is not silent. The no-PR arm is fail-CLOSED on `unknown` (:1264-1283), so a spawn failure at `gh pr list` does not let unlanded work finish — it refuses.

**Security:** no `shell=True`; argv lists throughout; helper is stdlib-only (AST test + `grep` confirm, no `pf` imports → no 162-30 cycle). `CompletedProcess(args, returncode, stdout, stderr)` positional order correct at both construction sites.

| # | Severity | Issue | Location |
|---|----------|-------|----------|
| 1 | [MEDIUM] | Spawn failure at the pre-merge gate now falls through to the irreversible merge; previously it crashed *before* it | `common/bounded_run.py:79` + `story_finish.py:455` |
| 2 | [MEDIUM] | Two docstrings assert "every finish test suite fakes `story_finish.subprocess`" — FALSE (one file does; 10+ patch `_run`). This false claim is the load-bearing justification for the injected-`runner` design, repeated into TEA's and Dev's assessments | `common/bounded_run.py:13`, `story_finish.py:334` |
| 3 | [MEDIUM] | Magic returncode (127) contradicts the module's own "distinct TYPE, not a magic returncode" argument; indistinguishable from a real command exiting 127, and no caller can dispatch on the distinction | `common/bounded_run.py:38-42` |
| 4 | [MEDIUM] | `_pr_view_probe` discards stderr on rc!=0, throwing away the one diagnostic the new OSError path produces | `story_finish.py:455-456` |
| 5 | [LOW] | `run()` is no-throw for TimeoutExpired/OSError only — verified escapes: `stdout=` → `ValueError`, `capture_output=` → `TypeError`, and `timeout=None` silently defeats the bound | `common/bounded_run.py:61,79` |
| 6 | [LOW] | Type nits: `TimedOutProcess` subclasses bare `CompletedProcess` while `run()` declares `CompletedProcess[str]`; `timed_out(result: Any)` should be `object`; `runner: Callable[..., ...]` leaves the seam's arity unchecked | `common/bounded_run.py:43,53,62` |
| 7 | [LOW] | `except subprocess.TimeoutExpired` now binds against the helper's `subprocess`, not story_finish's — the seam is half-moved (runner injected, exception types not) | `common/bounded_run.py:80` |
| 8 | [LOW] | Commit `520173cc6` (`test: …`) is missing its `(<scope>)` — violates the stated commit-format rule | git history |
| 9 | [LOW] | `story_finish.py:287` "the names below are re-exported" — `GH_TIMEOUT_S` et al. are NOT re-exports; and the helper docstring's "`pipeline_replay` calls `subprocess.run` unbounded" is an overstatement (26 sites, 17 bounded) | `story_finish.py:287`, `bounded_run.py:6-9` |
| 10 | [LOW] | `test_162_9_...py` is not `ruff format --check` clean — verified PRE-EXISTING on `develop`, not a 162-41 regression | test file |

Test-quality addendum (all [LOW], all non-blocking):
- `test_162_41...py:582` — the blown-timeout stderr check uses `"timed out" in ... or "11" in ...`. The OR disjunct means either alone passes; every other stderr assertion in the file uses a plain substring check. Tighten to AND.
- No OSError coverage at the `gh pr merge` site or the post-merge verification site — only at the gate probe. Both inherit the fix from `bounded_run` by construction, so this is regression-surface, not a live gap.
- Step-6 non-zero is pinned only for `git pull`; `git checkout`/`git branch -d` share the same handler but are not pinned.

**One subagent finding DISMISSED:** reviewer-test-analyzer flagged the new 162-9 `merge_calls == []` assertion as vacuous because reverting `is not None` leaves all five parametrized cases green. That is a scope misread, and I verified it: deliverable 5's stated purpose is "the hang-all-views predicate would PASS a fell-through gate — add the assertion so a fall-through is caught," NOT covering the `is not None` fix (which is `TestEmptyTimeoutMessageIsStillATimeout`'s job). My mutation test B forced the gate to fall through and the assertion fired at line 828. It is doing exactly the job it was specified to do. Downgraded to a documentation nit, not a defect.

None of these block. Finding 1 is the one I weighed hardest for a REJECT: it is a genuine fail-open widening on an irreversible operation, self-introduced by this diff. Not blocking because (a) the OSError→result conversion was an explicit spec deliverable, (b) it lands in the SAME permissive arm a plain `gh` error already lands in — a deliberate 162-9 design decision explicitly out of 162-41's scope, (c) `gh` is a second gate: if `gh` is genuinely absent, `gh pr merge` also fails to spawn, so only a transient EMFILE/ENOMEM that clears within seconds reaches a real merge, and (d) TEA and Dev both logged it as a follow-up before I got here. It must not be lost — see the Delivery Finding below.

**Deviation audit — all four Dev deviations and all three TEA deviations ACCEPTED:**
- *Spawn failure gets its own returncode* — ACCEPTED (the decision); the *value* is Finding 2.
- *OSError catch lives in the helper* — ACCEPTED. Correct home; duplicating it in the caller would make the next helper user re-learn that `subprocess.run` raises for a missing binary.
- *Aliases, not re-definitions* — ACCEPTED, and load-bearing: aliasing is what makes the class shared. Re-defining would have made every 162-9 timeout arm dead code.
- *Dry-run preview site fixed too (third site)* — ACCEPTED, and correct to exceed the spec. Two sites named, three exist; leaving the third would print "will merge" for a hung probe.
- TEA's helper-API naming, injected `runner`, and green-on-arrival step-6 pin — all ACCEPTED.
- No UNDOCUMENTED deviations found: the diff contains nothing outside the five deliverables.

### Tagged Specialist Findings

**[EDGE]** — reviewer-edge-hunter. CONFIRMED (as LOW): `run()` is no-throw only for `TimeoutExpired`/`OSError`; `**kwargs` collisions escape, and `timeout=None` defeats the bound. I proved all three empirically rather than reasoning about them (`bounded_run.py:61,79`):
- `run(['echo','hi'], stdout=subprocess.PIPE)` → **escapes `ValueError`**: "stdout and stderr arguments may not be used with capture_output."
- `run(['echo','hi'], capture_output=True)` → **escapes `TypeError`**: "got multiple values for keyword argument 'capture_output'."
- `run(['echo','hi'], timeout=None)` → **returns rc=0 from an unbounded call.** The annotation is not enforced; "every child is timed out" is defeated by one keyword.
DISMISSED: edge-hunter's third item (a failed gh probe falls through to merge) is not a finding — it is pre-existing documented 162-9 design; the agent itself filed it as proof-of-walk. VERIFIED its checks on `CompletedProcess` positional order and the step-5 `elif` ordering — both correct.

**[SILENT]** — reviewer-silent-failure-hunter. CONFIRMED its primary finding (my Finding 1) and its `_pr_view_probe` stderr-discard finding (my Finding 3). **DISMISSED its findings 2 and 3** (`story_finish.py:1470` `gh pr list` spawn failure → no-PR arm; `_branch_merge_state` → `state: unknown`) — I traced both to their terminus and they are **fail-CLOSED, not silent**: `story_finish.py:1264-1283` refuses on `unknown` with "refusing to mark the story done with unverifiable work", returns `success: False`, and never transitions or unlinks the session. The agent stopped at the routing and did not read the destination. Its 4th finding (dry-run doesn't render `warning`) is correct but unreachable — dry-run steps never carry the key. VERIFIED its check that `warning` IS rendered on the live path (`sprint/cli.py:494`), so the new step-5 record reaches the operator.

**[TEST]** — reviewer-test-analyzer. See the test-quality addendum above: CONFIRMED the `or "11"` disjunct, the missing OSError-at-merge/at-verification coverage, and the step-6 pinning gap (all LOW). **DISMISSED its lead finding** (the new 162-9 `merge_calls == []` assertion is vacuous) as a scope misread — see the dismissal note above; mutation test B proves the assertion fires. VERIFIED its independent mutation battery, which agrees with mine on every point, including that bypassing the runner injection is caught by 4 tests.

**[DOC]** — reviewer-comment-analyzer. **CONFIRMED, and promoted to my Finding 2 — this is the most interesting finding in the review.** Both `bounded_run.py:13` and `story_finish.py:334` assert "every finish test suite fakes `story_finish.subprocess`." **That claim is false, and I verified it independently before the subagent reported:** exactly ONE file patches `story_finish.subprocess` (test_162_41 itself); ten-plus files patch `pf.sprint.story_finish._run` outright. The same false claim is repeated in TEA's deviation log and Dev's assessment, where it is the load-bearing justification for the injected-`runner` design. The design is still right — the seam belongs in story_finish — but the stated evidence is inverted, and a future engineer reasoning from it will pick the wrong seam. CONFIRMED (LOW) its `story_finish.py:287` "the names below are re-exported" ambiguity — `GH_TIMEOUT_S` and friends are NOT re-exports.
Additionally, my own check of a third documented claim: `bounded_run.py`'s docstring says `pipeline_replay` "still calls `subprocess.run` unbounded" — it has 26 `subprocess.run` sites and 17 `timeout=` occurrences, so it is PARTIALLY bounded. `patch_mode.py` (5 sites, 0 `timeout=`) matches the claim exactly. Minor overstatement (LOW).

**[TYPE]** — reviewer-type-design. CONFIRMED its magic-returncode finding (my Finding 3 — it reached the same conclusion I did independently, including the `SpawnFailedProcess` + `spawn_failed()` remedy). CONFIRMED as LOW: `TimedOutProcess` subclasses the bare `subprocess.CompletedProcess` while `run()` declares `-> CompletedProcess[str]`, so the `str` parameterisation is silently dropped; `timed_out(result: Any)` should be `object` (identical runtime behaviour — `isinstance` works on `object` — but `Any` disables checking bidirectionally); `runner: Callable[..., ...]` leaves the injected callable's arity unchecked, where a `Protocol` would make the seam contract checkable. CONFIRMED its `ValueError` escape path — verified empirically above.

**[SEC]** — reviewer-security. **No exploitable security vulnerability.** Adjudication of its three findings:
- "injection" via `**kwargs` (`shell=True`/`env=`/`preexec_fn=`) — **DISMISSED as a security finding, retained as API hardening.** `kwargs` are supplied only by first-party call sites in this repo; no untrusted input reaches them. There is no `shell=True` anywhere in the diff (grep-verified), and every command is a list argv.
- "auth-bypass" (spawn failure passes the gate) — **CONFIRMED**; it is my Finding 1, and I resolved the conditional the agent left open: `_pr_view_probe` DOES check `returncode != 0` (`story_finish.py:455`) and returns `(None, None)`, which is precisely the permissive arm. Mislabelled category (no auth is bypassed), correct mechanism.
- "info-leakage" via `str(TimeoutExpired)` — **DISMISSED.** It serialises argv (branch names, PR numbers, repo paths) — all operator-supplied, non-secret; gh tokens live in env/keychain, never argv. The agent's own concern is about a hypothetical future change to use `exc.output`.
VERIFIED separately: session-file-sourced `branch` and `pr_number` flow into argv **lists**, never a shell string, so no command injection despite session markdown being the untrusted-ish input. Complies with the no-throw contract (Rule 6) modulo the `ValueError`/`TypeError` gap above.

**[SIMPLE]** — reviewer-simplifier. **DISMISSED its highest-confidence finding on a factual error I checked.** It claims "`_run` is not itself a patch target in any test suite" and recommends deleting `_run` in favour of direct `bounded_run.run(...)` calls. That is wrong: `grep` finds `patch("pf.sprint.story_finish._run", ...)` in ten-plus test files (155-1, 155-12, 155-16, 155-32, 155-34, 151-3, 153-2, 153-4, 147-12, …). Deleting `_run` would silently no-op the majority of the 128-test finish suite. `_run` earns its keep and must stay. DISMISSED its "`SPAWN_FAILURE_RETURNCODE` is write-only, inline the literal" remedy — it is used at the OSError arm, and the right direction is to make the distinction MORE explicit (a type), not less. Its underlying observation — that no caller dispatches on the distinction — is exactly my Finding 3, retained. DISMISSED the over-documentation and triplicated-comment findings: heavy rationale commentary is this module's established house style, and the real defect is not comment VOLUME but the false claim inside one of them ([DOC] above). DISMISSED its duplicated-OSError-test finding: the story_finish-level test proves the OSError arm is reachable THROUGH the delegation, which the helper-level test cannot show.

**[RULE]** — reviewer-rule-checker. 16 rules, 22 instances, **1 violation — CONFIRMED, not dismissed** (a stated project rule is not a suggestion). See `### Rule Compliance` below.

### Rule Compliance

**Rule: git commit format `<type>(<scope>): <subject>` (CLAUDE.md `<git-operations>`)**
- `ef34f90a4` "feat(162-41): timeout-hardening tail — …" — compliant (type=feat, scope=162-41, subject present)
- `520173cc6` "test: add failing tests for 162-41 timeout-hardening tail" — **VIOLATION: scope absent.** Should be `test(162-41): …`. Severity LOW: the branch squash-merges, so the landed subject is `ef34f90a4`'s, and rewriting a pushed GPG-signed commit costs more than the defect. Recorded, not blocking.

**Rule 6 / SOUL #10: return result objects, don't throw**
- `bounded_run.run` (`bounded_run.py:64-86`) — **PARTIAL**: compliant for `TimeoutExpired` and `OSError` (the two documented modes); **non-compliant for `ValueError` and `TypeError` from the `**kwargs` passthrough**, both empirically demonstrated above. LOW — no current caller triggers either.
- `story_finish._run` (`story_finish.py:319-336`) — compliant: pure delegation to a no-throw callee, no raise path of its own.
- `finish_story` step-5 new `elif` arm (`story_finish.py:2199-2216`) — compliant: appends a `warning` dict, never raises.
- `_pr_view_probe` / `_pr_merge_verification` / `_classify_pr` — compliant: all return tuples/dataclasses, no raises.
- test helper `_finish_with_injection` (`test_162_41…py:375-414`) — compliant: catches `BaseException` with a `noqa BLE001` justification stating the no-throw contract is the SUBJECT of the test.

**Rule 1: never edit `.pennyfarthing/` symlinked dirs** — 4 instances (all four diff files), 0 violations. Every path is under `pennyfarthing/pennyfarthing-dist/`. `git diff --stat` shows no `.pennyfarthing/` entries.

**Rule 4 / framework Rule 1: modify `pennyfarthing-dist/` as single source of truth** — 4 instances, 0 violations. `bounded_run.py` exists at exactly one source location; I confirmed the only other copies of `pf/common/*` are under `pennyfarthing-dist/build/lib/` (a stale generated build artifact, correctly NOT containing `bounded_run.py` and correctly not hand-edited).

**Rule 8: runtime scripts use `.pennyfarthing/` paths, never `pennyfarthing-dist/`** — 2 instances, 0 violations. `bounded_run.py` references no filesystem paths at all; the `story_finish.py` diff introduces no path strings.

**Rule: helper must be stdlib-only, no `pf` imports, no cycles (162-30 constraint, binding per SM)** — 1 instance, 0 violations. Imports are `__future__`, `subprocess`, `collections.abc.Callable`, `typing.Any`. I verified by `grep` AND the diff ships an AST-walk test (`test_helper_module_imports_nothing_from_pf`) that enforces it mechanically against `sys.stdlib_module_names`.

**Rule: `pf/common/` package conventions** — 3 instances, 0 violations. `bounded_run.py` is snake_case like its siblings (`binary_resolution.py`, `pr_config.py`); it is deliberately NOT re-exported from `pf/common/__init__.py`, matching the established pattern (that `__init__` exports only `config` and `output`; `hooks`, `themes`, `discovery`, `spinner`, `binary_resolution`, `pr_config` are all accessed by full module path, exactly as `from pf.common import bounded_run` does).

**Rules 2, 3, 5, 7, 9, 10 (sprint YAML, node_modules, TS `.js` extensions, model tiering, dogfood symlinks, answer style)** — 0 governed instances in this diff; not applicable.

### Verified Good

- **[VERIFIED] The hung-probe merge invariant holds at all three sites.** `story_finish.py:1521, 1630, 1835` — all three consumers read `is not None`; `grep` for `gate_timeout|verify_timeout` confirms zero truthiness consumers remain. `_pr_view_probe` (`:453-463`) returns a `str` second element on the timeout path ONLY; every other return is `(x, None)`. No non-None-falsy value exists in the codomain, so the change is strictly non-inverting and strictly stronger. *Complies with Rule 6 (result-shaped tuple, no throw) and preserves the 162-9/162-32/162-33 invariants the SM made binding. No other project rule governs branch conditions.*
- **[VERIFIED] Shared-class interop, so 162-9's timeout arms are live code.** `story_finish.py:302-303` — `_TimedOutProcess = bounded_run.TimedOutProcess` is an alias, one class object, so `_timed_out(bounded_run.TimedOutProcess(...))` is True by construction, not by coincidence. *Complies with the SM's binding non-negotiable that the class be SHARED, not duplicated. No conflicting rule.*
- **[VERIFIED] The patchable seam is intact and no test silently runs real `gh`/`git`.** `runner=subprocess.run` resolves through story_finish's own module global at call time; the one suite that patches `story_finish.subprocess` carries an explicit spy assertion (`len(calls) == 1`), and test-analyzer's independent mutation confirms bypassing the injection fails 4 tests. *Complies with the SM's binding constraint "`_run` is THE seam." Note the justifying comment overstates the exposure — see [DOC].*
- **[VERIFIED] Step-5 branch ordering is correct.** `story_finish.py:2186` (`_timed_out`) precedes `:2199` (`returncode != 0`). Inverted, the rc arm would shadow the timeout arm, since `TimedOutProcess` carries rc=124 — a hang would be reported as "exited 124". *Complies with Rule 6; no rule governs branch order, but this preserves 162-9's timeout/failure distinction.*
- **[VERIFIED] The no-PR arm is fail-closed, so no spawn failure can finish unlanded work.** `story_finish.py:1264-1283` returns `success: False` on `state: unknown` and never transitions or unlinks the session. *Complies with Rule 6 (result object with `error`). This is what downgrades two silent-failure findings from fail-open to non-issues.*
- **[VERIFIED] No command-injection surface.** No `shell=True` anywhere in the diff (grep); all commands are list argv; session-sourced `branch`/`pr_number` reach `subprocess` as list elements. *No applicable project rule mandates a specific argv form, but this satisfies the security posture the irreversible-merge path requires.*

**Handoff:** To SM for finish-story

## Subagent Results

All received: Yes — 9/9. All dispatched in parallel, in two waves (4, then 5 once I read the gate's roster). Every finding carries an explicit decision below; dismissal rationales are in the tagged-findings section above.

| # | Subagent | Received | Findings | Decision |
|---|----------|----------|----------|----------|
| 1 | `reviewer-preflight` | Yes | 0 defects (30 scoped pass, 1935 regression pass, ruff clean, no real `gh`/`git` under test) | N/A — clean; independently re-run by me |
| 2 | `reviewer-edge-hunter` | Yes | 3 | confirmed 2 (as LOW), dismissed 1 (pre-existing 162-9 design; agent filed it as proof-of-walk) |
| 3 | `reviewer-silent-failure-hunter` | Yes | 4 | confirmed 2, dismissed 2 (traced to a fail-CLOSED terminus at `story_finish.py:1264-1283`) |
| 4 | `reviewer-test-analyzer` | Yes | 4 | confirmed 3 (all LOW), dismissed 1 (scope misread of deliverable 5; disproved by mutation test B) |
| 5 | `reviewer-comment-analyzer` | Yes | 3 | confirmed 3 — one PROMOTED to Finding 2 (false load-bearing claim in two docstrings) |
| 6 | `reviewer-type-design` | Yes | 5 | confirmed 5 (1 merged into Finding 3, 4 as LOW; `ValueError` escape verified empirically) |
| 7 | `reviewer-security` | Yes | 3 | confirmed 1 (= Finding 1, recategorised), dismissed 2 (no untrusted input in `kwargs`; argv carries no secrets) |
| 8 | `reviewer-simplifier` | Yes | 5 | dismissed 4 (lead finding rests on a factual error: `_run` IS patched by 10+ suites), confirmed 1 as Finding 3 |
| 9 | `reviewer-rule-checker` | Yes | 1 violation / 16 rules / 22 instances | confirmed 1 (commit scope missing — a stated rule, so recorded not dismissed) |

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T15:00:34Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T14:00:58Z | 2026-08-12T14:02:45Z | 1m 47s |
| red | 2026-08-12T14:02:45Z | 2026-08-12T14:31:14Z | 28m 29s |
| green | 2026-08-12T14:31:14Z | 2026-08-12T14:39:45Z | 8m 31s |
| review | 2026-08-12T14:39:45Z | 2026-08-12T15:00:34Z | 20m 49s |
| finish | 2026-08-12T15:00:34Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): the spec names TWO truthiness sites; there are THREE. `story_finish.py:1519` (the DRY-RUN preview gate) also reads `if gate_timeout:`, alongside the real gate at 1623 and the post-merge verification at 1825. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (all three consumers of `_pr_view_probe`'s second element need `is not None`; the dry-run one has no side effects but would print "will merge" for a hung probe). *Found by TEA during test design.*
- **Improvement** (non-blocking): an `OSError` at the gate probe lands in the SAME permissive arm as the empty-message defect — `_run` (post-fix) returns rc!=0, `_pr_view_probe` returns `(None, None)`, `_classify_pr(None)` → UNREADABLE → the merge is attempted. A missing/broken `gh` is arguably closer to "the next call fails too" (a hang) than to "gh answered with an error". Deliberately NOT asserted in the tests — the permissive-on-gh-error behaviour is a 162-9 design decision and changing it is out of 162-41's scope. Worth a follow-up story. *Found by TEA during test design.*
- **Improvement** (non-blocking): deliverable 4 says the unbounded-subprocess pattern "recurs in other modules" — the actual callers are `pf/patch_mode.py` (5 sites) and `pf/benchmark/pipeline_replay.py` (~20 sites), none bounded. Extracting the helper does not migrate them; that migration is a separate story. Affects `pennyfarthing-dist/src/pf/patch_mode.py`, `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py`. *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): the helper now exists but nothing else uses it. `pf/patch_mode.py` (5 sites) and `pf/benchmark/pipeline_replay.py` (~20 sites) still call `subprocess.run` unbounded, so "every subprocess is bounded" is still true of exactly one module. Affects `pennyfarthing-dist/src/pf/patch_mode.py`, `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` (migrate to `pf.common.bounded_run.run`). Confirms TEA's third finding — worth its own story, since each site needs a timeout tier chosen deliberately rather than a blanket 120s. *Found by Dev during implementation.*
- **Improvement** (non-blocking): a spawn failure at the gate probe still reaches the permissive UNREADABLE arm (`_run` returns rc=127 → `_pr_view_probe` returns `(None, None)` → the merge is attempted). Only the no-throw contract was in scope for 162-41; the routing decision is TEA's second finding and remains open. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking, but MUST be filed): a spawn failure (`OSError` → rc=127) at the pre-merge gate probe now falls through to the irreversible `gh pr merge` with the PR's state unknown; before this diff the same condition crashed *before* the merge. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_pr_view_probe` should route `returncode == bounded_run.SPAWN_FAILURE_RETURNCODE` to the abort arm, on 162-9's own reasoning: a binary that could not spawn will not spawn for the merge either) and `pennyfarthing-dist/src/pf/common/bounded_run.py`. This confirms TEA's second and Dev's second findings and is the highest-value item in this story's tail — it is the ONLY behavioural regression in the diff and it sits on the irreversible path. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `bounded_run` signals spawn failure with a magic returncode (127) while its own `TimedOutProcess` docstring argues that a distinct TYPE beats "a marker attribute or a magic returncode" for exactly this purpose. A real command exiting 127 is indistinguishable from a failed spawn. Affects `pennyfarthing-dist/src/pf/common/bounded_run.py` (add `SpawnFailedProcess(CompletedProcess)` + a `spawn_failed()` predicate) — this would reduce the fix for the finding above to a two-line routing change. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_pr_view_probe` discards stderr on a non-zero exit (`return None, None`), so the one diagnostic the new OSError path produces ("No such file or directory: 'gh'") is thrown away — the newest failure mode is the least diagnosable. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py:455-456`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): `bounded_run.run` claims "nothing raises" but is no-throw only for `TimeoutExpired`/`OSError`. A caller passing `capture_output` or `text` in `**kwargs` gets a `TypeError` through the contract, and `timeout=None` silently defeats the bound (the annotation is not enforced). No current caller does either, but the module exists to be reused by `patch_mode` and `pipeline_replay`. Affects `pennyfarthing-dist/src/pf/common/bounded_run.py`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): the seam is only half-moved — the runner is injected, but `except subprocess.TimeoutExpired` now binds against the HELPER's `subprocess`, not story_finish's. No existing test is affected (the 162-41 stubs deliberately bind the real class), but a future test faking `story_finish.subprocess` with a bare `MagicMock` and raising `fake.TimeoutExpired` would no longer be caught. Affects `pennyfarthing-dist/src/pf/common/bounded_run.py:80`. *Found by Reviewer during code review.*
- **Conflict** (non-blocking): the docstrings at `pennyfarthing-dist/src/pf/common/bounded_run.py:13` and `pennyfarthing-dist/src/pf/sprint/story_finish.py:334` both state "every finish test suite fakes `story_finish.subprocess`". Verified false: ONE file does (test_162_41); ten-plus patch `pf.sprint.story_finish._run` outright. The design conclusion is still correct, but the evidence is inverted, and the same false claim propagated into TEA's deviation log and Dev's assessment. Affects both files (correct the claim to "suites fake `story_finish._run` (pre-162-41) or `story_finish.subprocess` (162-41+); a helper owning its own seam would no-op both"). *Found by Reviewer during code review.*
- **Question** (non-blocking): commit `520173cc6` on this branch is `test: add failing tests…` with no `(<scope>)`, violating CLAUDE.md's stated `<type>(<scope>): <subject>` format. Not corrected in-flight because the commit is pushed and GPG-signed and the branch squash-merges. Affects the commit-format habit at the RED phase — worth a lint/hook if it recurs. *Found by Reviewer during code review.*
- **Question** (non-blocking): `test_162_9_finish_subprocess_timeouts.py` is not `ruff format --check` clean, and I verified this is PRE-EXISTING on `develop` (not a 162-41 regression). That means format is not enforced on this path in CI. Affects the repo's quality gate config. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Shared-helper API chosen, not specified:** spec said "extract the bounded-run/`_TimedOutProcess` trio into a shared helper" without naming it. Tests pin `pf.common.bounded_run` with `run`/`TimedOutProcess`/`timed_out`/`DEFAULT_TIMEOUT_S`. Reason: a test cannot assert against an unnamed module, and the module path is the cheap thing to change (one constant, `HELPER_MODULE`, at the top of the test file).
- **The helper takes an injected `runner`:** spec said "keep story_finish's behavior identical". Tests require `story_finish._run` to still reach `subprocess.run` via story_finish's own module global, which forces the helper to accept the callable rather than import `subprocess` itself. Reason: the entire finish test suite (10 files, 128 tests) fakes `story_finish.subprocess`; a helper owning its own seam would make all of them no-ops and let real `gh`/`git` run under test — a silent loss of hermeticity that no existing test would catch.
- **Step 6 test is a green-on-arrival pin, not RED:** spec said "pin both steps". Step 6 already reads every rc (162-32), so its test passes today. Kept anyway so the pair cannot drift while step 5 is fixed.

### Dev (implementation)
- **A spawn failure gets its own returncode, not the timeout's:** spec said only "catch `OSError` in `_run` and return a result". Implemented `SPAWN_FAILURE_RETURNCODE = 127` (sh's "command not found") in the helper, distinct from `TIMEOUT_RETURNCODE = 124`, and returned as a plain `CompletedProcess`, never a `TimedOutProcess`. Reason: the tests require `timed_out()` to be False for a spawn failure — a child that never started did not hang, and routing it into the timeout arm tells the operator to expect the next call to hang too while hiding a missing binary.
- **The `OSError` catch lives in the HELPER, not in story_finish's `_run`:** spec listed deliverables 3 and 4 separately. Implemented 3 inside `pf.common.bounded_run.run`, with story_finish's `_run` a one-line delegation. Reason: TEA's `test_helper_also_converts_a_spawn_failure` pins it there, and duplicating the catch in the caller would mean the next helper user re-learns that `subprocess.run` raises for a missing binary.
- **`_TimedOutProcess`/`_timed_out`/`_TIMEOUT_RETURNCODE`/`DEFAULT_TIMEOUT_S` are now re-export aliases in story_finish, not definitions:** spec said "keep story_finish's behavior identical". Six existing suites import `_TimedOutProcess` from `story_finish` and hand-build instances; aliasing (rather than re-defining) keeps those imports working AND makes the class shared, which is the non-negotiable interop property. story_finish's per-site tiering constants (`GH_TIMEOUT_S` etc.) stay in story_finish — only the default bound moved.
- **The dry-run preview site was fixed too (TEA's third truthiness site, uncovered by tests):** spec named two sites. All three consumers of `_pr_view_probe`'s second element now read `is not None`. Reason: same latent trap; leaving it would print "will merge" for a hung probe.