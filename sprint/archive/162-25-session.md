---
story_id: "162-25"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-25: Git revision operators survive ref-prefixing in _branch_merge_state: refs/heads/feat~2, @{0}, caret forms all resolve (probed rc=0) to an ANCESTOR of the real tip — count 0 ahead reads merged, the 155-34 false-done from a direction prefixing doesn't cover; pre-existing on bare names too. Probed fix: validate with git check-ref-format --branch (rejects rc=128) and route invalid names to the existing unknown-aborts path (from 162-4 review)

## Story Details
- **ID:** 162-25
- **Jira Key:** (none — Jira not enabled for this project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-25-revision-operators-ref-prefixing
- **PR:** #187

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-06T18:06:07Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-06T17:21:48Z | 2026-08-06T17:23:32Z | 1m 44s |
| red | 2026-08-06T17:23:32Z | 2026-08-06T17:39:53Z | 16m 21s |
| green | 2026-08-06T17:39:53Z | 2026-08-06T17:50:35Z | 10m 42s |
| review | 2026-08-06T17:50:35Z | 2026-08-06T18:06:07Z | 15m 32s |
| finish | 2026-08-06T18:06:07Z | - | - |

## Sm Assessment

**Verdict:** READY

Setup complete for 162-25 (p1, 1 pt, tdd). Session file, story context, and feature branch `feat/162-25-revision-operators-ref-prefixing` (pennyfarthing repo, from origin/develop at the PR #186 tip) in place. Peloton mode active (team peloton-162-25, subagent orchestration). Routing to TEA for red: failing tests showing git revision operators (`refs/heads/feat~2`, `@{0}`, caret forms) survive ref-prefixing in `_branch_merge_state` and resolve to an ancestor of the real tip, reading falsely merged; probed fix direction is `git check-ref-format --branch` validation routing invalid names to the existing unknown-aborts path.

## Tea Assessment

**Verdict:** RED

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_25_revision_operator_branch_values.py` — 46 tests over `_branch_merge_state`, real git fixture (no `_run` patching in the semantic tests, per the 155-34 hermetic-seam contract)

**Tests Written:** 46 tests covering AC-1..AC-6 — 26 failing (RED), 20 green-on-arrival regression guards.
**Status:** RED (failing for the right reasons — ready for Dev)

**Root cause (verified against real git 2.54.0):** 162-4 made every probe candidate a full ref path, but `refs/heads/<name>` is still parsed as a REVISION, not a ref path — so every `gitrevisions(7)` suffix operator survives the prefixing and is honored inside it. On a branch three commits ahead of the base, `refs/heads/feat~3`, `refs/heads/feat^^^`, `refs/heads/feat@{3}`, `refs/heads/feat~3^{commit}` and `refs/heads/feat:` all resolve rc=0 to an ancestor of the tip (or the root tree). Per 162-4's own contract the winning candidate is reused as the `rev-list --count <base>..<branch>` endpoint, so the count is **0** and the classifier returns `merged` — `finish_story`'s no-PR gate then records `skipped: branch-verified-merged` and finishes the story on unlanded code. Independent of 162-4: the pre-162-4 bare probe resolved `feat~3` to the same ancestor.

Near misses matter too and are pinned: `feat~1` reports count 2 for a 3-ahead branch (the abort prose quotes a wrong number), and `feat@{0}`/`feat^0`/`feat~0`/`feat^{}` classify correctly only by luck (`@{1}` is an ancestor again). Three more forms — `feat@{u}`, a value that already carries its own `refs/heads/` prefix, and an embedded control character — already abort, but with the reason "branch not found locally or on origin", which sends the operator hunting for a deleted branch instead of fixing a malformed field.

**Designed contract for Dev (behavior, not mechanism):** a refused name returns `{"state": "unknown", "base": <prose>, "reason": <quotes the value, says it is not a valid branch name>}` with **no** `count` key, and no `rev-parse`/`rev-list` may be emitted for it (validate before resolving). `git check-ref-format --branch` satisfies every test; so does a pure-Python validator. Two traps are pinned as guards: (a) crf `--branch` **expands** `@{-N}` (rc=0, prints the previously-checked-out branch), so rc=0 is not license to substitute its stdout — that would verify a branch the session never declared; (b) a narrow allowlist regex such as `^[A-Za-z0-9/_-]+$` breaks `release-1.2.3` and `feat/v1.0`, which are legal and covered by green controls.

**Suite:** `pytest pennyfarthing-dist/src/pf/tests/` → **30 failed, 5954 passed, 4 skipped, 5 xfailed**. 26 failures are this story's RED; the other 4 are the known pre-existing `test_frame_routes.py::TestPersonaRoute`/`TestBackwardCompatibility` persona failures from the orchestrator root. `ruff check` clean on the new file.

**Commit:** `53cfb538e` (GPG-signed, verified good) on `feat/162-25-revision-operators-ref-prefixing`.

**Handoff:** To Dev for green.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Conflict** (non-blocking): the story title, the context doc and TEA's brief all name `git check-ref-format --branch` as the probed fix. That flag is the wrong tool twice over: it refuses dash-leading names, which 162-4 explicitly pins as classifiable (`refs/heads/-evil` is a legal refname plumbing really creates, and `test_dash_leading_ref_that_exists_is_found_not_reported_missing` failed against a `--branch` gate), and it DWIM-expands `@{-N}`. Plain refname mode on the prefixed value has neither problem. Affects the probed-fix wording carried in `sprint/current-sprint.yaml`/`sprint/context/context-story-162-25.md` (nothing to change in code). *Found by Dev during implementation.*
- **Improvement** (non-blocking): refname-mode validation closes TEA's `@{...}` follow-up for free — `refs/heads/<v>` bans `@{`, so `@{u}`, `@{0}` and `@{-1}` are all refused before any probe, and no value can reach the ref arms via a reflog expansion. TEA's third Delivery Finding (a follow-up to refuse `@{` outright) needs no story. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by Dev during implementation.*
- **Gap** (non-blocking): the `origin` hardcoding TEA flagged is still open, and validation does not touch it — a repo whose upstream is not `origin` still reads `unknown`. Third story to defer it; it wants its own. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_branch_merge_state` candidate list). *Found by Dev during implementation.*

### TEA (test design)
- **Conflict** (non-blocking): `sprint/context/context-story-162-25.md`'s Acceptance Criteria section carries 162-10's extractor ACs (parenthesized-tail values silently rewritten; control characters reaching argv), not this story's title. I covered the control-character item as a rejected form; the parenthesized-tail rewrite lives in `_normalize_branch_field`, a different function, and is NOT covered here. Affects `sprint/context/context-story-162-25.md` (regenerate from the story YAML, or file the tail-rewrite item as its own story). *Found by TEA during test design.*
- **Gap** (non-blocking): the same missing validation applies to the BASE arm, whose value comes from repos.yaml `default_branch` — unvalidated operator input. `base='develop~1'` turns a genuinely merged branch into `unmerged` count 1 and puts `refs/remotes/origin/develop~1` (a nonexistent ref) into the operator-facing abort message. Direction of harm is a loud false-abort, not a silent false-done, so it is off the epic's headline class — but it is the same one-line fix. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_branch_merge_state` base arm; pinned by `TestBaseArmValidatesToo`). *Found by TEA during test design.*
- **Improvement** (non-blocking): `git check-ref-format --branch` is a validator with a DWIM mode — it accepts and EXPANDS `@{-N}` (and `@{u}` when an upstream is configured), answering rc=0. A crf-only gate therefore lets those through to the ref probes; the outcome is still an abort ("branch not found"), so it is not a hole today, but a follow-up may want to refuse any value containing `@{` outright rather than relying on the probe missing. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by TEA during test design.*
- **Question** (non-blocking): the candidates still hardcode `origin` (carried over unresolved from 162-4's Delivery Findings). A multi-remote repo whose upstream is not `origin` cannot be verified at all and reads `unknown`. Out of scope here; flagging that two stories have now deferred it. *Found by TEA during test design.*

### Reviewer (code review)
- **Gap** (non-blocking): `_git_cleanup` passes a bare, unvalidated `base` to `git checkout <base>` and `git pull origin <base>` (`story_finish.py`:815-816) with neither a `--` guard nor the new `_valid_branch_name` gate, while its own sibling `git branch -d -- <branch>` at :820 *is* guarded and carries a comment saying why. A repos.yaml `default_branch` that is dash-leading or operator-bearing therefore still reaches `git checkout` in argv flag position — the same 162-4 class this epic exists to close. Out of scope for 162-25 (Step 6 runs after the story is already recorded done, and the value comes from committed config), but it is the last unguarded argv position left in this file. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_git_cleanup`). *Found by Reviewer during code review.*
- **Gap** (non-blocking): values that are legal REFNAMES but not branch names — `HEAD`, `@`, and an operator-free self-prefixed `refs/heads/<branch>` — pass the new gate (`git check-ref-format refs/heads/HEAD` rc=0, verified) and fall through to the generic "branch not found locally or on origin". That is exactly the wrong-diagnosis class `WRONG_REASON_FORMS` exists to kill, so AC-2 is satisfied only for the subset git refuses as refnames. No false-done (the probe fails, nothing is classified). Wants either the invalid-name diagnosis extended to non-branch refnames or an explicit AC narrowing. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_branch_merge_state`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): re-pin the new probe's timeout arm to `state == "timeout"` (not `in {"timeout","unknown"}`) using 162-9's subprocess-level patching pattern rather than stubbing `_run`, and drop the now-dead `project` fixture from that test. Affects `pennyfarthing-dist/src/pf/tests/test_162_25_revision_operator_branch_values.py` (`TestTimedOutValidationIsNotMerged`). *Found by Reviewer during code review.*
- **Conflict** (blocking for context hygiene, non-blocking for code): confirming TEA's finding by direct inspection — `sprint/context/context-story-162-25.md`'s Acceptance Criteria section contains 162-10's extractor ACs (parenthesized-tail rewriting, control characters into argv), not this story's. The AC-1..AC-6 that TEA and Dev worked to were derived from the story TITLE, not from the context doc. Regenerate the doc from the story YAML, or the next agent to read it will implement the wrong story. Affects `sprint/context/context-story-162-25.md`. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 6 findings (4 Gap, 1 Conflict, 0 Question, 1 Improvement)
**Blocking:** None

- **Gap:** the `origin` hardcoding TEA flagged is still open, and validation does not touch it — a repo whose upstream is not `origin` still reads `unknown`. Third story to defer it; it wants its own. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`.
- **Conflict:** `sprint/context/context-story-162-25.md`'s Acceptance Criteria section carries 162-10's extractor ACs (parenthesized-tail values silently rewritten; control characters reaching argv), not this story's title. I covered the control-character item as a rejected form; the parenthesized-tail rewrite lives in `_normalize_branch_field`, a different function, and is NOT covered here. Affects `sprint/context/context-story-162-25.md`.
- **Gap:** the same missing validation applies to the BASE arm, whose value comes from repos.yaml `default_branch` — unvalidated operator input. `base='develop~1'` turns a genuinely merged branch into `unmerged` count 1 and puts `refs/remotes/origin/develop~1` (a nonexistent ref) into the operator-facing abort message. Direction of harm is a loud false-abort, not a silent false-done, so it is off the epic's headline class — but it is the same one-line fix. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`.
- **Gap:** `_git_cleanup` passes a bare, unvalidated `base` to `git checkout <base>` and `git pull origin <base>` (`story_finish.py`:815-816) with neither a `--` guard nor the new `_valid_branch_name` gate, while its own sibling `git branch -d -- <branch>` at :820 *is* guarded and carries a comment saying why. A repos.yaml `default_branch` that is dash-leading or operator-bearing therefore still reaches `git checkout` in argv flag position — the same 162-4 class this epic exists to close. Out of scope for 162-25 (Step 6 runs after the story is already recorded done, and the value comes from committed config), but it is the last unguarded argv position left in this file. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`.
- **Gap:** values that are legal REFNAMES but not branch names — `HEAD`, `@`, and an operator-free self-prefixed `refs/heads/<branch>` — pass the new gate (`git check-ref-format refs/heads/HEAD` rc=0, verified) and fall through to the generic "branch not found locally or on origin". That is exactly the wrong-diagnosis class `WRONG_REASON_FORMS` exists to kill, so AC-2 is satisfied only for the subset git refuses as refnames. No false-done (the probe fails, nothing is classified). Wants either the invalid-name diagnosis extended to non-branch refnames or an explicit AC narrowing. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`.
- **Improvement:** re-pin the new probe's timeout arm to `state == "timeout"` (not `in {"timeout","unknown"}`) using 162-9's subprocess-level patching pattern rather than stubbing `_run`, and drop the now-dead `project` fixture from that test. Affects `pennyfarthing-dist/src/pf/tests/test_162_25_revision_operator_branch_values.py`.

### Downstream Effects

Cross-module impact: 6 findings across 3 modules

- **`pennyfarthing-dist/src/pf/sprint`** — 4 findings
- **`pennyfarthing-dist/src/pf/tests`** — 1 finding
- **`sprint/context`** — 1 finding

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **`check-ref-format` refname mode instead of `--branch`:** Story title and TEA's brief both specify `git check-ref-format --branch <value>`; implemented `git check-ref-format refs/heads/<value>`. Reason: a `--branch` gate regressed 162-4's `test_dash_leading_ref_that_exists_is_found_not_reported_missing` — `--branch` refuses `-evil` (rc=128) while `refs/heads/-evil` is a legal refname 162-4 pins as classifiable. Refname mode refuses every operator form in TEA's `REJECTED_FORMS` (the grammar bans `~ ^ : ? * [`, `@{` and control characters), accepts all four `ORDINARY_NAMES`, and has no DWIM mode — so AC-6's `@{-1}` trap is closed by construction rather than by a caller remembering not to read stdout. TEA's own docstring leaves mechanism to Dev; all 46 tests pass unmodified.
- **No test files touched.** TEA's tests were correct as written.

### TEA (test design)
- **Base arm added to scope (AC-4):** Story title scopes the bug to the branch value; tests also require the `base` value to be validated. Reason: identical missing validation on operator-supplied input in the same function, reachable from repos.yaml `default_branch`, and satisfied by the same one-line fix — leaving it untested would invite a half-fix.
- **`refs/heads`-prefixed forms pinned as reason-quality, not false-merged:** Brief asked for failing tests on "bare and refs/heads-prefixed" forms. A session value of `refs/heads/feat~3` is prefixed AGAIN into `refs/heads/refs/heads/feat~3`, which does not resolve, so it already aborts today — no false-merged to reproduce. Reason: verified with real git; it is pinned instead in `TestInvalidNameReasonIsActionable` (its reason must name the value invalid rather than "branch not found"). The story title's `refs/heads/feat~2` is the CANDIDATE the code builds from a bare `feat~2`, which is where the false-merged reproduces.
- **Reachability test written tolerantly:** `TestThreatModelReachability` accepts either pass-through or an `InvalidBranchValue` raise from `_extract_branch`, and only forbids silent REWRITING. Reason: same layer-boundary precedent as 162-4's reachability test after 162-10 tightened the extractor — the classifier's own hardening must stay load-bearing regardless of where the refusal lands.
### Reviewer (audit)

Every logged deviation adjudicated; each load-bearing claim re-derived against real git 2.54.0 rather than taken on the author's word.

- **Dev — `check-ref-format` refname mode instead of `--branch`** → ✓ ACCEPTED by Reviewer. Both claims independently verified. (a) `git check-ref-format --branch '@{-1}'` answers rc=0 and prints the previously-checked-out branch — it expands rather than validates, so `--branch` is not a pure validator; `git check-ref-format 'refs/heads/@{-1}'` answers rc=1 because the refname grammar bans `@{`. (b) `git check-ref-format refs/heads/-evil` answers rc=0, preserving 162-4's pin that a dash-leading ref stays classifiable, and 19/19 of 162-4's ref-prefix tests pass. I swept 37 forms through real git: every form in `REJECTED_FORMS` plus `@{-1}`, `@{u}`, `^{tree}`, `^{/regex}`, `:/text` is rc=1, and all four `ORDINARY_NAMES` are rc=0. Refname mode is strictly stronger than the probed fix, not a shortcut around it — this deviation improves on the story title, and the title's wording is what should change.
- **Dev — no test files touched** → ✓ ACCEPTED by Reviewer: the test file is added once at `53cfb538e` and unmodified by `eb9a1fbb3`. The fix was made to pass tests as written, which is what makes the RED→GREEN transition meaningful.
- **TEA — base arm added to scope (AC-4)** → ✓ ACCEPTED by Reviewer: the same unvalidated operator input in the same function, reachable from repos.yaml `default_branch`, closed by the same gate. Leaving it out would have invited a half-fix that a later story pays for. `TestBaseArmValidatesToo` pins the merged→unmerged inversion concretely.
- **TEA — `refs/heads`-prefixed forms pinned as reason-quality, not false-merged** → ✓ ACCEPTED by Reviewer, premise verified: `refs/heads/refs/heads/feat~3` does not resolve, so there is genuinely no false-merged to reproduce for that shape. Note the boundary this leaves — the operator-FREE self-prefixed form is a legal refname that passes the gate; filed as a Delivery Findings Gap rather than charged against this deviation.
- **TEA — reachability test written tolerantly** → ✓ ACCEPTED by Reviewer: matches 162-4's layer-boundary precedent, and forbidding silent REWRITING while permitting either pass-through or refusal is the right invariant — it keeps the classifier's own hardening load-bearing no matter where a future story puts the refusal.

**Undocumented deviations found:** one, Low.
- **Fixture docstring contradicts two of its own tests:** the `project` fixture docstring (`test_162_25_revision_operator_branch_values.py`:253) states "No `_run` patching anywhere in this fixture's tests", but `TestNoRefProbeForInvalidNames` (:510) installs a delegating spy over `_run` and `TestTimedOutValidationIsNotMerged` (:725) stubs it wholesale. Neither TEA nor Dev logged the divergence. Severity: L — the AC-3 spy delegates to the real `_run` and forwards `cwd`, so 155-34's substance (real git, hermetic seam) survives; the docstring is simply now false and will mislead the next author who trusts it.

## Dev Assessment

**Verdict:** GREEN

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — new `_valid_branch_name(value, cwd)` helper (`git check-ref-format refs/heads/<value>` through `_run`, `GIT_LOCAL_TIMEOUT_S`); `_branch_merge_state` validates both `branch` and `base` before any ref resolution, routing a refusal to the existing unknown-abort path.

**Approach:** One pre-resolution gate over both arms. A refused value returns `{"state": "unknown", "base": <base>, "reason": "<label> '<value>' is not a valid branch name (git check-ref-format rejected it)"}` — no `count` key, value quoted verbatim so the abort names the string in the operator's session file, and prose distinct from the branch-not-found diagnosis. A validation call that blows its timeout returns `{"state": "timeout", ...}` (162-9). Validation precedes every `rev-parse`/`rev-list`, so git never evaluates the operator and there is no rc=0 to second-guess (AC-3).

Refname mode rather than the `--branch` mode named in the story title — see Design Deviations. It refuses every form in TEA's `REJECTED_FORMS` plus `@{-1}`, accepts all four awkward-but-legal `ORDINARY_NAMES`, and has no DWIM expansion, which closes AC-6 structurally.

**Tests:** 46/46 story tests passing (GREEN). Scoped sweep (`-k "finish or handoff or gate or sprint or branch"`): 1641 passed, 3 skipped, 0 failed — including 162-4's 19 ref-prefix tests, which a `--branch` gate had regressed. Full suite `pytest pennyfarthing-dist/src/pf/tests/`: **4 failed, 5980 passed, 4 skipped, 5 xfailed** — the 4 failures are the known pre-existing `test_frame_routes.py` persona failures from the orchestrator root, unchanged from TEA's baseline. `ruff check` clean on the changed file. No test files modified.

**Branch:** `feat/162-25-revision-operators-ref-prefixing` (pushed)
**Commit:** `eb9a1fbb3` (GPG-signed, verified good)

**Handoff:** To Reviewer for review.
## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | confirmed 0, dismissed 0, deferred 0 |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 4 | confirmed 3, dismissed 1, deferred 0 |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | findings | 4 | confirmed 2, dismissed 2, deferred 0 |
| 7 | reviewer-security | Yes | clean | none | confirmed 0, dismissed 0, deferred 0 |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | findings | 2 | confirmed 1, dismissed 0, deferred 1 |

**All received:** Yes (5 enabled returned, 3 with findings; 4 disabled via `workflow.reviewer_subagents`)
**Total findings:** 6 confirmed, 3 dismissed (with rationale), 1 deferred

### Dismissals (with rationale)

- **[TEST] vacuous `state.get("count") != AHEAD_COMMITS - 1` pre-check** (test file:449) — DISMISSED. The analyzer is right that the assertion only bites for the `~1` case and would not catch `merged`/count=0. But it is a redundant *additional* assertion sitting immediately above `_assert_state_is_refusal`, which pins `state == "unknown"` and `"count" not in state` and therefore already excludes `merged`. A redundant-but-true assertion documenting the wrong-count case is taste, not a defect. No rule matches it.
- **[TYPE] `cwd: str` vs the file's `Path | None` convention** — DISMISSED as taste. The call site converts once at `story_finish.py`:707 (`cwd = str(repo_path)`) and passes the same `str` to every probe in the function; the new helper matching its siblings' *actual* parameter shape at this call depth is consistency, not divergence. No rule requires `Path` at leaf helpers.
- **[TYPE] unparameterized `subprocess.CompletedProcess` return annotation** — DISMISSED as taste. `_run` always passes `text=True`, and the annotation is valid; tightening to `[str]` is a nicety with no failure mode. Noted for whoever next touches the signature.

### Deferred

- **[RULE] `TestNoRefProbeForInvalidNames` patches `_run` (test file:510)** — DEFERRED to the docstring correction already filed. The rule-checker rates this a high-confidence 155-34 violation; I DOWNGRADE it to Low rather than dismiss, because the substance of 155-34 (real git executes; a probe that dropped `cwd` would fail outright) is preserved — the spy calls `real_run(cmd, **kwargs)` and forwards `cwd`, so every git invocation still runs against the fixture repo. What is actually broken is the fixture docstring's absolute claim, logged under Design Deviations → Reviewer (audit). AC-3 is an *ordering* property, and argv observation is the honest way to assert ordering; a pure state check cannot distinguish "validated first" from "probed and then discarded".

### Challenging my own VERIFIEDs against subagent findings

- I marked the operator-refusal behavior VERIFIED. The test-analyzer flagged `HEAD`/`@` as passing validation in the same area. Re-read: those are not operator forms and do not resolve (`git rev-parse --verify --quiet refs/heads/HEAD` rc=1 in the fixture), so my VERIFIED on AC-1 (no false-merged) stands on `story_finish.py`:711-722 + :727. I did NOT claim AC-2 fully verified — the analyzer's finding is confirmed and filed, and my own sweep independently found the operator-free `refs/heads/<branch>` case in the same class.
- I marked argv safety VERIFIED; the rule-checker agreed (`--` unsupported, prefix closes flag position) and the security agent reported clean on the same vector. No contradiction.
- I marked the `count` contract VERIFIED as fail-closed; the type-design agent flagged it as latent-untyped. Not a contradiction: it confirmed no `.get("count", 0)` exists in any caller, matching my read of `story_finish.py`:1342-1345. Filed as Low/latent, VERIFIED retained with that qualification.

### Rule Compliance

Rules enumerated from `CLAUDE.md` (orchestrator + `pennyfarthing/`), `pyproject.toml` ruff config, and the epic's own standing contracts (155-34 hermetic seam, 162-4 argv/ref-path, 162-9 bounded timeouts). Every rule checked against every changed construct — 2 production constructs (`_valid_branch_name`, `_branch_merge_state`'s validation loop) and 9 test classes.

| Rule | Source | Instances | Verdict |
|------|--------|-----------|---------|
| 1. Never edit `.pennyfarthing/` symlinks | CLAUDE.md #1 | 2 files | COMPLIANT — both under `pennyfarthing-dist/`; `git diff --name-only` shows nothing else |
| 4. Modify `pennyfarthing-dist/` as single source of truth | CLAUDE.md #4 | 2 files | COMPLIANT |
| 6. Return result objects, don't throw | CLAUDE.md #6 | 3 new return paths + 1 helper | COMPLIANT — timeout/invalid arms return dicts matching the function's existing contract; no new `raise`; `_run` converts `TimeoutExpired` to `_TimedOutProcess` at :363 |
| 8. Runtime scripts use `.pennyfarthing/` paths | CLAUDE.md #8 | 0 | N/A — no runtime path literals added |
| Local git plumbing uses `GIT_LOCAL_TIMEOUT_S` | 162-9 / :307-315 | 1 new call | COMPLIANT — :654 uses `GIT_LOCAL_TIMEOUT_S` (30.0s), same as the `rev-parse`/`rev-list` siblings; `check-ref-format` is local string validation with no network |
| `timeout` state distinct from `unknown` | 162-9 | 2 arms | COMPLIANT in production (:713 vs :715) — but the *test* guard conflates them (confirmed finding) |
| Full ref paths, never bare names in argv | 162-4 | 1 new argv | COMPLIANT — `f"refs/heads/{value}"` at :652 can never begin with `-` |
| `--` argv guard where supported | 162-4 | 1 new call | COMPLIANT / N-A — `git check-ref-format -- refs/heads/foo` returns rc=129; `--` is unsupported, so omitting it is required, not a lapse |
| All git calls through `_run` with explicit `cwd` | 155-34 | 1 new call | COMPLIANT — :651-654, and `cwd` has no default so a cwd-less call is a `TypeError` |
| Tests must not patch `_run` for semantic assertions | 155-34 | 9 test classes | 7 COMPLIANT, 2 divergent (:510 delegating spy — downgraded to Low; :725 full stub — confirmed Low) |
| Story-numbered test file naming/location | precedent | 1 file | COMPLIANT — matches `test_162_4_*`, `test_162_9_*`, `test_162_10_*` in the same dir |
| ruff line length / lint | `pyproject.toml` | 2 files | COMPLIANT — `line-length = 100` with `E501` ignored; `ruff check` clean |
| f-string multiline join integrity | correctness | 1 string | COMPLIANT — :718 fragment ends `"...branch name "` with trailing space; concatenation reads correctly |
| Python only (no JS/TS logic added) | `pennyfarthing/CLAUDE.md` | 2 files | COMPLIANT |

**Tenant isolation audit:** N/A — this is a single-tenant local CLI/orchestrator. No trait methods handling multi-tenant data, no `tenant_id`-bearing structs, no auth surface in the diff. The analogous trust boundary here is the session file's `**Branch:**` field, audited under Security below.

### Devil's Advocate

Let me argue this change is broken. The strongest attack is that it is *validation theater*: a gate that asks git a question git is happy to answer wrongly. `check-ref-format` in refname mode answers "is this a syntactically legal ref path", which is emphatically NOT the question the code needs answered — "does this string name the branch the session declared". Those two questions diverge, and I found three values where they do: `HEAD`, `@`, and a self-prefixed `refs/heads/<branch>` all sail through the gate. So a reviewer who reads the docstring's confident prose and concludes "operator forms are impossible now" has been sold a narrower guarantee than advertised. The gate closes the *suffix-operator* grammar, not the *not-a-branch* semantics. That is a real conceptual gap, and it is exactly the kind of gap that spawned this story in the first place — 162-4 also believed it had closed the door, and this story is the receipt.

Second attack: the fix adds two subprocess spawns to a hot-ish path and, worse, adds a new *failure* mode. Before, a hung filesystem or an exhausted process table could only break the probes; now it can break validation, and a `_TimedOutProcess` there returns `state: "timeout"` with `reason` set to a bare `str(TimeoutExpired)` that never mentions which of the two values was being validated or that validation (rather than resolution) was the step that hung. An operator debugging a stuck finish gets "Command [...] timed out after 30.0 seconds" and no hint that their `default_branch` was the input under test. That is an observability regression relative to the invalid-name arm two lines below, which carefully quotes both `label` and `value`.

Third attack: a confused user. The reason string says "git check-ref-format rejected it", naming a plumbing command the operator has probably never run, while the sprint YAML and context doc still say the fix is `--branch`. Someone who tries to reproduce the rejection by running `git check-ref-format --branch -evil` will get rc=1 for a value the code *accepts*, and conclude the message is lying.

Fourth: a malicious user controls the session markdown. Could they inject a newline into `reason` and forge a `**Verdict:**` line? I tested this rather than assumed it: `git check-ref-format` rejects newline, tab, space, and `\x01` inside a refname (all rc=1), and the extractor independently rejects whitespace, so the quoted value cannot carry a line break. The vector is closed twice over, by construction. Similarly `..`, `//`, leading `.`, trailing `.` and `.lock` are all rc=1, so ref-path traversal into `refs/remotes/` is impossible.

What survives of these attacks? The first is a genuine scope boundary (filed, Low — no false-done, because a non-resolving value aborts). The second and third are real but cosmetic observability/doc issues (filed, Low). The fourth dies on evidence. None of them reopens the silent false-done this story exists to close, and none of them makes the code worse than what it replaces. The attacks land on the *margins* of the fix, not its core.

### Observations

- `[VERIFIED]` **The false-done class is genuinely closed.** I swept 37 values through real git 2.54.0 in a purpose-built 3-ahead fixture. Every form in `FALSE_MERGED_FORMS` and `MISCLASSIFIED_FORMS` — `feat~3`, `feat^^^`, `feat@{3}`, `feat~3^{commit}`, `feat:`, `feat~1`, `feat@{0}`, `feat^0`, `feat~0`, `feat^{}` — plus `@{u}`, `@{-1}`, `^{tree}`, `^{/regex}`, `:/text` returns rc=1 from `git check-ref-format refs/heads/<v>`, while `git rev-parse --verify --quiet refs/heads/<v>` returns rc=0 for most of them. That rc=0/rc=1 split IS the bug and IS the fix. Gate at `story_finish.py`:711-722, before the probes at :727/:746. Complies with 162-4's ref-path rule and 162-9's timeout tiering.
- `[VERIFIED]` **No value passes the gate and resolves to a non-tip.** Of the 37 swept, only `HEAD`, `@`, `-evil`, `--local-env-vars`, `refs/heads/feat`, and the four `ORDINARY_NAMES` are rc=0 from the gate; of those, only an actually-existing branch resolves, which is correct classification, not a hole. Evidence: `story_finish.py`:727 probes `refs/heads/{branch}` — a legal-but-nonexistent refname returns rc=1 and falls to the branch-not-found abort at :735-739.
- `[VERIFIED]` **162-4 interplay intact.** `git check-ref-format refs/heads/-evil` → rc=0, so 162-4's `test_dash_leading_ref_that_exists_is_found_not_reported_missing` premise survives; 19/19 of `test_162_4_branch_merge_state_ref_prefix.py` pass. `git check-ref-format -- refs/heads/foo` → rc=129, so `--` is genuinely unsupported and its omission at :652 is correct rather than an inconsistency with 162-4's convention. Argv safety comes from the `refs/` prefix, which cannot begin with `-` for any input.
- `[VERIFIED]` **Injection and traversal closed by construction.** `../heads/main`, `a/../../refs/heads/main`, `feat/../main`, `feat//x`, `/feat`, `feat/`, `.feat`, `feat.`, `feat.lock`, `feat 1`, tab, newline, `\x01`, and empty are all rc=1. So the `reason` at :718-720 cannot carry a line break into a session file — the `**Verdict:**` forgery vector that this branch's parent story (162-21) hardened against is closed here too. `_run` is list-form with no `shell=True` (:361).
- `[VERIFIED]` **Fail-closed at every caller arm — the abort is actually honored.** `story_finish.py`:1323-1330 `merged` → skip+continue; :1332 `timeout` → abort; :1342 `unmerged` → abort; :1350 `else` catch-all absorbs `unknown` *and any future state string*, each returning `{"success": False}`. Without this the gate would be decorative; with it, a refused value provably cannot finish a story. Complies with the function's own documented "rule #1: unknown is not merged".
- `[VERIFIED]` **Both arms gated, in the right order.** The loop at :711 iterates `(branch, base)` and runs *after* the `base` fallback at :708, so a `default_branch` resolved from repos.yaml is validated too — not just an explicitly-passed base. Validation strictly precedes every `rev-parse`/`rev-list`, satisfying AC-3 structurally rather than by convention.
- `[VERIFIED]` **Tests are honest.** Independent pre-fix verification in a throwaway `develop` worktree: **26 failed / 20 passed** — exactly TEA's claimed RED split. The RED tests assert their fixture premise from raw git (`_raw_count`, `_resolves`, `_assert_not_a_branch_name`) before touching the classifier, so they fail loudly on a git-grammar change rather than passing for the wrong reason. Controls assert real counts (`count == 1` for each `ORDINARY_NAME`, `== 3` for `AHEAD`, `== 0` for `LANDED`), proving the probe/count path still executes rather than merely that validation no-oped.
- `[VERIFIED]` **Suite numbers are honest.** `5980 passed, 4 failed, 4 skipped, 5 xfailed`; the 4 failures are exactly `test_frame_routes.py::TestPersonaRoute` (3) + `TestBackwardCompatibility` (1), pre-existing and with zero overlap with `story_finish.py`. `ruff check` clean. Both commits GPG-signed, `%G? = G`. `pennyfarthing/` working tree clean.
- `[MEDIUM]` `[TEST]``[RULE]` **The new probe's timeout arm is not meaningfully pinned.** `TestTimedOutValidationIsNotMerged` (test file:709-735) is weak on two axes at once: it stubs `_run` wholesale so no real git runs (making the `project` fixture dead weight), and it accepts `state in {"timeout", "unknown"}`. 162-9's whole point is that those two say different things to the operator. The implementation is correct — :713 returns `"timeout"` — but a regression collapsing that arm into `"unknown"` would pass this guard. 162-9's own tests patch at subprocess level (`fake_module.run`) instead, which is the pattern to copy. Non-blocking: no production defect, but the AC is effectively unguarded.
- `[LOW]` `[TEST]` **AC-2 holds only for the refname-illegal subset.** `HEAD`, `@`, and an operator-free self-prefixed `refs/heads/<branch>` pass the gate (verified rc=0) and receive the generic "branch not found locally or on origin" — the wrong-diagnosis class `WRONG_REASON_FORMS` exists to eliminate. An operator who typed `HEAD` into the Branch field is sent hunting for a deleted branch. No false-done. `story_finish.py`:711; untested at test file:201.
- `[LOW]` `[DOC]` **Stale comment misstates the shipped guard's strength.** `WRONG_REASON_FORMS`' docstring (test file:196-201) says `@{-1}` "will let it through to the ref probes and answer the generic branch-not-found". False under refname mode: `refs/heads/@{-1}` is rc=1 and gets the invalid-name reason. The comment describes the rejected `--branch` design, so a future reader underestimates the guard — and a refactor back to `--branch` would silently reopen the DWIM trap that `TestValidationDoesNotDwimOrRewrite` exists to catch.
- `[LOW]` `[TYPE]` **Predicate name, process return.** `_valid_branch_name` (`story_finish.py`:621) reads as a bool but returns `CompletedProcess`, which is *always truthy* — `if _valid_branch_name(value, cwd):` would accept every rejected name, including the operator forms this story closes. The sole call site (:711-714) checks `_timed_out` then `returncode` correctly, and returning the raw result is a deliberate, documented choice (a `_TimedOutProcess` must be routed, not read as an answer). But no other helper in this file pairs a `_valid_*` name with a process return. A rename (`_check_ref_format`) or a tri-state `Literal` would make the contract self-enforcing.
- `[LOW]` `[TYPE]` **`count`-absence is load-bearing but untyped.** `_branch_merge_state` returns `dict[str, Any]`; the story's contract is that a refused value carries NO `count`. Verified no caller does `.get("count", 0)` — the only access is inside the `unmerged` guard at :1342-1345 — so there is no bug today. A `TypedDict` union keyed on `state` would make the invariant a checker guarantee instead of a convention the tests alone defend.
- `[LOW]` **Timeout reason loses the input under test.** :713 returns `reason = check.stderr` only, so a validation timeout reports `"Command [...] timed out after 30.0 seconds"` without the `label`/`value` the invalid-name arm two lines below quotes so carefully. An operator cannot tell whether it was the branch or the base that hung, or that validation was the step at all.
- `[VERIFIED]` **Pattern followed correctly, not just cited.** Dev routed the refusal into the *existing* unknown-abort shape rather than inventing a state: the returned dict keeps `base` (which `finish_story`'s report shape depends on — pinned by `_assert_state_is_refusal` at test file:359) and adds only `reason`. Docstring length (:622-650) matches house style in this module (`_branch_merge_state`'s own is 48 lines). No new state string, so the caller's `else` catch-all needed no change.

### Data Flow Traced

Session `**Branch:** feat/162-25-ahead~3` → `_extract_branch` (`story_finish.py`:277, strips markdown/backticks/parenthetical tail, refuses dash-leading and interior whitespace, passes `~` through unchanged — pinned by `TestThreatModelReachability`) → `finish_story` no-PR arm (:1313) → `_branch_merge_state(repo_path, branch, base)` → `base` fallback (:708) → **new gate** `_valid_branch_name` (:711) → `_run(["git","check-ref-format","refs/heads/feat/162-25-ahead~3"], cwd=…)` → rc=1 → return `{"state":"unknown","base":…,"reason":"branch value '…~3' is not a valid branch name (…)"}` with no `count` → caller's `else` arm (:1350) → `{"success": False}` with the story NOT recorded done, session preserved.

Safe because the operator string never reaches a `rev-parse` or `rev-list` argv (asserted by the delegating spy at test file:510), so git never evaluates the suffix operator and there is no rc=0 for the code to second-guess; and because the abort is terminal at every caller arm rather than falling through to a skip.

**Wiring:** no UI surface in this diff. The operator-facing surface is the finish report's `error` string (:1338/:1353) and the `steps[]` entry, both reachable via `pf sprint finish`; `reason` flows into that prose and is never written into session markdown, so it cannot forge workflow state.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** session `**Branch:** feat/162-25-ahead~3` → `_extract_branch` (passes `~` through unchanged) → `finish_story`'s no-PR arm (`story_finish.py`:1313) → `_branch_merge_state` → new `_valid_branch_name` gate (:711) → `git check-ref-format refs/heads/feat/162-25-ahead~3` rc=1 → `{"state":"unknown", "base":…, "reason":"branch value '…~3' is not a valid branch name …"}` with no `count` → caller's `else` arm (:1350) → `{"success": False}`, story NOT recorded done. Safe because the operator string never reaches a `rev-parse`/`rev-list` argv, so git never evaluates the suffix operator and there is no rc=0 to second-guess — and because the abort is terminal at all four caller arms rather than falling through to a skip.

**Pattern observed:** the refusal is routed into the *existing* unknown-abort shape rather than a new state — the dict keeps `base` (which `finish_story`'s report shape depends on) and adds only `reason`, so the caller's `else` catch-all needed no change. `story_finish.py`:715-722 vs the sibling branch-not-found return at :735-739.

**Error handling:** exhaustively fail-closed. `story_finish.py`:1323 `merged`→skip, :1332 `timeout`→abort, :1342 `unmerged`→abort, :1350 `else`→abort, absorbing `unknown` and any future state string; every abort returns `{"success": False}`. Null/empty inputs: an empty branch value yields `refs/heads/` which is rc=1 (verified), so it aborts rather than crashing; `base` falls back via `_resolve_base_branch` at :708 *before* validation, so a resolved `default_branch` is gated too.

**Security analysis:** clean. The argv is `f"refs/heads/{value}"`, which cannot begin with `-` for any input, so no flag injection; `_run` is list-form with no `shell=True` (:361); `git check-ref-format -- …` returns rc=129 so `--` is correctly omitted rather than negligently. Traversal (`..`, `//`, leading/trailing `.`, `.lock`) and all whitespace/control characters are rc=1 — verified against real git, not inferred — so the verbatim-quoted `value` in `reason` cannot carry a newline and cannot forge a `**Verdict:**` line in any operator-facing artifact.

**Deviation audit:** 5 logged deviations, all ✓ ACCEPTED with premises independently re-verified against real git 2.54.0; 1 undocumented deviation found and logged (Low — fixture docstring contradicts two of its own tests).

**Findings:** 0 Critical, 0 High, 1 Medium, 5 Low.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] | `[TEST]` `[RULE]` New probe's timeout arm not meaningfully pinned: test stubs `_run` wholesale (dead `project` fixture) *and* accepts `state in {"timeout","unknown"}`, so it cannot catch a regression collapsing 162-9's distinction | `test_162_25_revision_operator_branch_values.py`:709-735 | Follow-up: assert `state == "timeout"`, patch at subprocess level per 162-9's precedent |
| [LOW] | `[TEST]` AC-2 holds only for the refname-illegal subset — `HEAD`, `@`, self-prefixed `refs/heads/<branch>` pass the gate and get the generic branch-not-found diagnosis | `story_finish.py`:711 | Follow-up: extend invalid-name reason, or narrow the AC explicitly |
| [LOW] | `[TEST]` Stale comment describes the rejected `--branch` design, understating the shipped guard and hiding a trap from a future refactor | `test_162_25_…py`:196-201 | Follow-up: correct to refname-mode behavior |
| [LOW] | `[TYPE]` `_valid_branch_name` reads as a predicate but returns an always-truthy `CompletedProcess`; sole call site is correct | `story_finish.py`:621 | Follow-up: rename or return a tri-state |
| [LOW] | `[TYPE]` `count`-absence is load-bearing but untyped; no caller does `.get("count", 0)` today | `story_finish.py`:658 | Optional: `TypedDict` union keyed on `state` |
| [LOW] | `[RULE]` Fixture docstring claims "no `_run` patching anywhere in this fixture's tests" while two tests patch it; plus the validation timeout reason drops the `label`/`value` under test, unlike the invalid-name arm | `test_162_25_…py`:253, `story_finish.py`:713 | Follow-up: correct the docstring; include which field hung |

**Subagent findings incorporated:** `[SEC]` reviewer-security returned **clean** — I re-tested its whole vector list against real git rather than accepting it: argv can never begin with `-` (the arg is `refs/heads/…`), `_run` is list-form with no `shell=True`, `--` is genuinely unsupported (rc=129), traversal (`..`, `//`, leading/trailing `.`, `.lock`) and every whitespace/control character are rc=1, and the abort is fail-closed at all four caller arms. `[TEST]` reviewer-test-analyzer: 4 findings, 3 confirmed above, 1 dismissed (redundant `count` pre-check — `_assert_state_is_refusal` already carries it). `[TYPE]` reviewer-type-design: 4 findings, 2 confirmed above, 2 dismissed as taste (`cwd: str` shape, unparameterized `CompletedProcess`). `[RULE]` reviewer-rule-checker: 2 findings — 1 confirmed above, 1 downgraded from its high-confidence 155-34 violation to Low (the AC-3 spy delegates to the real `_run` and forwards `cwd`, so the hermetic seam survives; the docstring is what is false) and explicitly NOT dismissed. Preflight returned clean with every handoff number independently verified.

Nothing blocking. The story's headline class — a `gitrevisions(7)` suffix operator resolving to an ancestor and reading `merged` — is empirically closed, and I confirmed it by sweeping 37 forms through real git rather than trusting the handoff: every operator form is rc=1 at the gate while `rev-parse` still answers rc=0 for most of them, which is precisely the gap. The Medium and the Lows all sit on the margins (test precision, reason quality, naming, observability) and none reopens a false-done. Dev's refname-mode deviation is not a shortcut around the story title — it is strictly stronger than the probed fix, closing AC-6's `@{-1}` DWIM trap by construction while preserving 162-4's dash-leading pin, and I verified both halves of that claim directly.

**Suite:** 46/46 story tests; 19/19 on 162-4's ref-prefix regression suite; full suite **5980 passed, 4 failed, 4 skipped, 5 xfailed** — the 4 exactly the pre-existing `test_frame_routes.py` persona failures, zero overlap with `story_finish.py`. Independent pre-fix worktree run: **26 failed / 20 passed**, matching TEA's claimed RED split exactly — the tests genuinely discriminate. `ruff check` clean; both commits GPG-signed (`%G? = G`); `pennyfarthing/` tree clean.

**Handoff:** To SM for finish-story