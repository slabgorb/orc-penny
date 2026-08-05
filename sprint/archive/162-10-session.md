---
story_id: "162-10"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-10: _extract_branch: iterate annotation/backtick strips to a fixed point (annotation-inside-backticks residual) + document sentinel-set tradeoff (from 155-33 review)

## Story Details
- **ID:** 162-10
- **Jira Key:** (none — no Jira integration for this project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-10-extract-branch-fixed-point
- **PR:** #182

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-05T18:35:29Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-05T18:04:38Z | 2026-08-05T18:05:50Z | 1m 12s |
| red | 2026-08-05T18:05:50Z | 2026-08-05T18:15:15Z | 9m 25s |
| green | 2026-08-05T18:15:15Z | 2026-08-05T18:22:42Z | 7m 27s |
| review | 2026-08-05T18:22:42Z | 2026-08-05T18:35:29Z | 12m 47s |
| finish | 2026-08-05T18:35:29Z | - | - |

## Sm Assessment

**Scope:** 1-pt p2 bug, TDD. `_extract_branch` in `pennyfarthing-dist/src/pf/sprint/story_finish.py` applies its annotation/backtick strips ONCE in a fixed order — an annotation nested inside backticks (or vice versa) leaves residue in the extracted branch name, which then feeds every downstream git/gh call. Plus folded 162-4 AC: dash-leading values pass the lone-dash sentinel and reach downstream git calls.

**Technical approach for TEA:** (1) Failing tests: nested forms (annotation-inside-backticks, backticks-inside-annotation, doubled annotations) extract to the clean branch name — iterate strips to a fixed point; include a bound (no infinite loop on pathological input). (2) Sentinel-set tradeoff documented: which placeholder values mean "no branch" (lone dash, "(none)", empty) — pin the set with tests and a docstring rationale. (3) Dash-leading rejection: `-evil`/`--verify`-shaped values are rejected at the extractor (treated as no-branch or explicit error — pick the truthful arm: a session declaring a branch that can't be a branch should ABORT loudly, not silently no-PR-finish; log the choice). Syntactic-only check — revision-operator forms (feat~2) are 162-25's probe-layer story, don't duplicate.

**Acceptance criteria:**
1. Nested annotation/backtick forms extract cleanly (fixed-point iteration, bounded).
2. Sentinel set documented + pinned.
3. Dash-leading values never reach downstream git calls; chosen arm logged and truthful.
4. Suite exit 0 (7 loud 162-5 xfails only).

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## Story Context

**Component:** `_extract_branch()` in `pennyfarthing-dist/src/pf/sprint/story_finish.py`

**Problem:** The `_extract_branch()` function strips markdown annotations (e.g., "(pushed)", italics) and backticks from the session's branch field in a single fixed pass. When an annotation is nested INSIDE backticks (or vice versa), residual formatting remains in the extracted branch name, causing the branch probe to fail with invalid git names.

**Acceptance Criteria:**
1. Iterate strip passes to a fixed point — continue stripping until the branch value stabilizes (no further changes in consecutive passes)
2. Document the sentinel-set tradeoff: which placeholder values (e.g., lone dash) are meaningful vs. which ones pass checks unintentionally
3. Defense in depth: reject or ref-qualify dash-leading values at `_extract_branch` — the sentinel accepts only a lone dash, so dash-leading values like `-evil` reach all downstream git calls without validation (from 162-4 review)

**Affected Files:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_extract_branch()` function (touched by 162-1/3/4/6/9 stories)

**Scope:** This is a 1-point bug fix. Fix is expected to be straightforward (iterate to fixed point, add dash validation) with minimal surface area. Test suite should exit with code 0 (7 loud xfails only).

## TEA Assessment

**Tests Required:** Yes
**Status:** RED — 36 failures, all on assertions or on the not-yet-existing symbols below. Rest of suite green: 5719 passed, 4 skipped, 7 xfailed (the expected loud 162-5 xfails).

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_10_extract_branch_fixed_point.py` — new, 92 tests (35 red)
- `pennyfarthing-dist/src/pf/tests/test_162_4_branch_merge_state_ref_prefix.py` — 1 test restated (`TestThreatModelReachability`, now red). It pinned the OPPOSITE of AC-3: that the extractor lets a dash-leading value through, which is why the probe's argv hardening was load-bearing. Rewritten to pin the refusal, with a docstring recording that 162-4's ref-prefix hardening is unaffected and still pinned by its own real-git tests (the classifier takes values that never pass through the extractor).

**Designed interface for Dev** (tests bind to behavior; full rationale in the test module docstring):
1. `_extract_branch(fields) -> str | None` keeps its signature and its None-means-no-branch contract. Loop the two existing strips (trailing-annotation regex, tick strip) until the value stops changing, then test the sentinel set against that fixed point.
2. Bound the loop with a module-level constant `_MAX_BRANCH_STRIP_PASSES` (int, >= 2), consulted at call time — the tests monkeypatch it on the module, so a default-argument capture will not do. Belt must fail loud: residue left when the bound is spent raises, never returns.
3. New `InvalidBranchValue(ValueError)` exported from `pf.sprint.story_finish`, message contains the offending raw field value. Raised for: leading dash (after the lone-dash sentinel has had its chance), interior whitespace, unstrippable tick/paren residue. `finish_story` catches it and returns `{success: False, error: ...}` before any subprocess or irreversible step, in dry run too.
4. Chosen arm, logged: loud abort, NOT None. None routes finish into the no-PR arm — a silent SUCCESSFUL finish. A session that declares a branch which cannot be a branch is the unverifiable world, not the no-branch world.

**Test inventory:**
- `TestNestedAnnotationBacktickForms` (RED, AC-1) — 9-shape table (annotation inside ticks, inside doubled ticks, inner+outer annotation, nested ticks) extracts the clean name; a residue-character property assertion; idempotence (the fixed-point definition itself).
- `TestNestedSentinelFormsResolveToNoBranch` (RED, AC-1/2) — nested sentinel forms resolve to no-branch; `_field_is_sentinel` must agree on the same forms (the two normalizations must not drift — 155-34 reuses one deliberately).
- `TestStripIterationIsBounded` (RED, AC-1) — bound constant exists and permits real nesting; depths 64/512/4096 terminate under a 2s wall clock and reduce cleanly; a starved bound refuses loudly instead of returning half-reduced residue.
- `TestSentinelSetPinned` (green guards + AC-2) — exact set equality; each member bare/ticked/annotated; case-insensitivity; empty, whitespace-only, annotation-only, empty-ticks, and missing-key shapes; over-reach guard that branch names merely CONTAINING a sentinel token survive.
- `TestImpossibleBranchValuesRejected` (RED, AC-3) — 4 dash-leading shapes raise and name the value; each raises through every wrapper (so formatting cannot smuggle a dash past the fixed point); the exception subclasses ValueError; the lone dash stays the sentinel (AC-2/AC-3 boundary); interior whitespace and unstrippable residue raise.
- `TestRevisionOperatorFormsNotInScope` (green fence) — tilde/caret/at/colon forms still extract as names here; pinned so 162-10 does not absorb 162-25's probe-layer scope, and so 162-25 has a test to flip.
- `TestPrNumberExtractorUnaffected` (green guard) — the PR extractor does NOT share the strip logic (it scans for a hash-number); pinned so a shared-helper refactor cannot change what the PR field means.
- `TestCanonicalFormsUnchanged` (green guard) — the shapes 155-33/155-40 already rely on.
- `TestFinishAbortsOnImpossibleBranchValue` (RED, AC-3 integration) — abort is loud and quotes the value, zero subprocesses ran, no transition, no archive (session still in place); dry run refuses too (155-31 preview/reality parity); and the nested-annotated branch reaches the PR probe's head argument CLEAN.

**Handoff:** To Dev for GREEN.

## Delivery Findings

### TEA (test design)
- **Improvement** (non-blocking): the annotation strip is anchored to the END of the value, so a LEADING annotation (a value shaped as an annotation followed by a ticked branch) cannot reduce at all — a fixed-point loop does not help. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (the strip regex would need a leading-annotation arm). Deliberately unpinned here: out of the 1-pt scope, and under this story's AC-3 that shape now aborts loudly rather than reaching git, which is already truthful. *Found by TEA during test design.*
- **Gap** (non-blocking): `_field_is_sentinel` open-codes a copy of the extractor's normalization rather than calling it, so the two can drift silently. One test pins agreement on nested forms, but the duplication itself invites the next divergence. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (extract the normalization into one helper both call). *Found by TEA during test design.*
- **Question** (non-blocking): a bare annotation-only value reduces to empty, so it reads as "field never filled in" to the no-PR gate rather than as an affirmative no-branch declaration — the gate then refuses to finish a legitimately branchless story whose author wrote it that way. The extractor's answer (no branch) is unambiguous, so nothing here is pinned; worth a decision at the gate layer. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by TEA during test design.*

### Reviewer (code review)
- **Improvement** (non-blocking): the annotation strip cannot tell a trailing annotation from part of the name, so a value whose tail is parenthesized is silently REWRITTEN rather than refused. Measured: a value shaped as a dollar sign followed by a parenthesized word reduces to a bare dollar sign and extracts as that, and any name legitimately ending in parens loses its tail. The residue check cannot catch this because the transform succeeds and leaves no residue. Pre-existing regex behavior, harmless with shell=False, but it is the one remaining arm where the extractor changes a value instead of accepting or refusing it. Affects the story_finish extractor. *Found by Reviewer during code review.*
- **Gap** (non-blocking): the pass bound is reachable, contrary to the comment claiming it is not. A value of the form name followed by eight repetitions of backtick-space reduces one group per pass, needs nine passes, and is refused loudly at the bound even though it would have reduced cleanly. Loud, so not a correctness defect — but the bound comment and the Dev note both assert unreachability, and the slow-reducing family is unpinned by any test. Affects the story_finish normalization bound comment plus the 162-10 bound suite. *Found by Reviewer during code review.*
- **Gap** (non-blocking): the bound suite's depth parametrization at 64/512/4096 is depth-invariant — Python's strip removes every leading and trailing backtick in one call, so all three depths converge in exactly three passes. The parametrization pins regex and strip performance on long strings, not loop-iteration depth, so a regression that made iteration count grow with input size would not be caught there. Affects the 162-10 bound suite. *Found by Reviewer during code review, corroborated by reviewer-test-analyzer.*
- **Gap** (non-blocking): the dry-run arm of the finish-abort suite asserts only failure plus the quoted value, dropping the four invariants its non-dry-run sibling carries (zero subprocesses, no transition, no completed-list write, session still in place). Preview/reality parity is that test's stated purpose, so the weaker assertion set is inconsistent with its own goal. Affects the 162-10 finish-abort suite. *Found by reviewer-test-analyzer, confirmed by Reviewer.*
- **Improvement** (non-blocking): non-whitespace control characters pass the extractor's refusal arms and reach git argv. No injection (subprocess is argv-list, never shell) and git's own ref grammar rejects them, so the finish aborts loudly through the unverifiable arm — but the extractor's stated contract is to refuse values that cannot BE a branch, and git's check-ref-format is the authoritative exclusion list. Natural home is 162-25's probe layer, where delegating the whole question to check-ref-format would subsume this. Affects the story_finish extractor. *Found by reviewer-security, confirmed by Reviewer.*
- **Improvement** (non-blocking): the extractor still collapses two distinct worlds into None — an affirmative no-branch sentinel and a never-filled-in field — forcing finish to re-read the raw field and re-run the normalization through the gate predicate to recover a distinction the extractor already computed. This story materially improved it (both paths now share one helper instead of two copies, closing TEA's drift Gap), but the discriminated outcome type is the real fix. Affects the story_finish extractor and no-PR gate. *Found by reviewer-type-design, downgraded by Reviewer: deliberate 155-34 layering, no correctness gap, out of a 1-pt scope.*
- **Improvement** (non-blocking): the sentinel set is a mutable set whose own docstring says both of its edges are silent failures. A frozenset makes that contract enforceable at the type level and costs nothing — membership tests and the suite's set-equality pin both work unchanged. Affects the story_finish sentinel constant. *Found by reviewer-type-design, confirmed by Reviewer as a LOW nit.*

## Design Deviations

### Dev (implementation)
- No deviations from spec. TEA's designed interface was implemented as specified: module-level bound read at call time, sentinel test on the fixed point, InvalidBranchValue as a ValueError subclass quoting the raw value, finish_story converting it to a failure result before any subprocess.

### Reviewer (audit)
- **ACCEPTED** — Dev's interface implementation matches TEA's spec on all four points. Verified by reading the code and by exercising the extractor directly, not by trusting the note: bound is a module constant read inside the loop range (so the monkeypatch starvation test is meaningful, not a default-argument capture), the sentinel test runs against the fixed point (so nested sentinel forms and the lone dash both keep their meaning), the exception subclasses ValueError and quotes the raw value, and the conversion to a failure result sits ahead of every subprocess.
- **ACCEPTED, with the rationale corrected** — the bound value of 8 is sound but Dev's stated reason for it is factually wrong. Dev's key decision claims the deepest shape in TEA's table needs four passes, three of which change the value, and that a bound of 2 or 3 would refuse a legitimate field. Measured every shape in TEA's table: the deepest converges in three passes (two of which change the value), and nothing in the table exceeds that. The code comment is the accurate one — it says real sessions converge in two or three passes. The choice of 8 is conservatively above the true maximum either way, so the code is right and only the note is wrong; recorded here so the next story does not inherit a false premise about how much headroom the bound has.
- **FLAGGED (LOW, non-blocking)** — the same note, and the bound's own comment, assert that 8 is unreachable in practice. It is reachable: a slow-reducing shape hits it at eight alternating backtick-space groups. The behavior there is a loud refusal, which is the correct arm, so this is a comment-accuracy issue rather than a defect. Logged as a Delivery Finding.
- **UNDOCUMENTED** — nothing else. No undeclared behavior change found in the diff: the PR-number extractor, the canonical branch shapes, the revision-operator shapes, and the no-PR gate's sentinel-versus-empty distinction all behave exactly as they did on develop, each pinned by a green guard in the new suite and re-verified independently here.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` — new `_normalize_branch_field` helper loops the annotation strip and the tick strip to a fixed point, bounded by the module constant `_MAX_BRANCH_STRIP_PASSES` (8, read at call time); `_extract_branch` tests the sentinel set against the fixed point, then refuses dash-leading, interior-whitespace, and residue-bearing values with the new `InvalidBranchValue(ValueError)`; `_field_is_sentinel` now calls the shared helper instead of open-coding its own copy of the normalization; `finish_story` converts the refusal into a `{success: False, error}` result at the extraction site — before any subprocess, transition, or archive, dry run included; the sentinel-set tradeoff is documented at the set itself.

**Key decisions:**
- Bound is 8, not 2. The deepest real shape in TEA's table (nested ticks wrapping an annotated ticked name) needs four passes to reach its fixed point, three of which change the value. A bound of 2 or 3 would refuse a legitimate session field. The strips shrink monotonically, so 8 is unreachable in practice — it exists so a pathological value cannot spin.
- The refusal is one method on the fixed point rather than a pre-pass on the raw value, so no formatting layer can smuggle a dash past it, and the lone-dash sentinel keeps its meaning by being tested first.
- `_field_is_sentinel` swallows `InvalidBranchValue` and answers False. It is a predicate, and by the time finish consults it the extractor has already refused such a value loudly; raising a second time from the gate would only replace a report with a traceback. This closes TEA's non-blocking Gap finding about the duplicated normalization.

**Tests:** 5754 passed, 4 skipped, 7 xfailed (the expected loud 162-5 xfails), suite exit 0. Story suites: 111/111 (92 in `test_162_10_extract_branch_fixed_point.py` + 19 in the 162-4 suite including the restated `TestThreatModelReachability`). `ruff check` clean.

**Branch:** `feat/162-10-extract-branch-fixed-point` (commit `de49799da`, GPG signed, pushed)

**Handoff:** To Reviewer.

## Subagent Results

| # | Subagent | Status | Findings | Severity | Reviewer disposition |
|---|----------|--------|----------|----------|----------------------|
| 1 | reviewer-preflight | Returned | BLOCKED: 3 failures + 1 error, ruff 86 violations | claimed blocking | **DISMISSED — measurement artifact.** Refuted by re-running the suite as configured. See Preflight Refutation below. |
| 2 | reviewer-test-analyzer | Returned | 2 (depth parametrization depth-invariant; dry-run assertions thinner than its sibling) | medium, low | Both CONFIRMED, both non-blocking, logged as Delivery Findings. Its three negative answers (162-4 not orphaned, scope fence meaningful, monkeypatch mechanics correct) independently re-verified by me. |
| 3 | reviewer-type-design | Returned | 3 (None overloading forces a second normalization; mutable sentinel set; tri-state hidden from the signature) | high→med, med, low | All CONFIRMED as real, all downgraded to non-blocking with rationale, all logged. |
| 4 | reviewer-security | Returned | 1 (non-whitespace control chars pass the validator) | low | CONFIRMED, non-blocking, logged. Its four ALSO_CONSIDER traces (no shell=True, refusal at 847 before first subprocess at 883, dry-run branch at 930 downstream of both, repr-quoted messages) match my own independent trace line for line. |
| 5 | reviewer-rule-checker | Returned | 0 across 16 rules / 58 instances | — | Accepted. Spot-checked its two load-bearing claims (patch targets point at the consuming module; no broad ValueError handler wraps the extractor) — both hold. |
| — | edge_hunter, silent_failure_hunter, comment_analyzer, simplifier | Skipped | disabled | N/A | Disabled via workflow.reviewer_subagents. Their ground was covered by hand: I enumerated the extractor's boundary shapes directly, and the one swallow in the diff was audited (see below). |

**All received: Yes** — all 5 enabled subagents (preflight, test_analyzer, type_design, security, rule_checker) returned before any conclusion was written. The other 4 are disabled via settings and do not block the gate. One subagent's mechanical claim was refuted on re-measurement and is challenged in writing below; every other finding was either confirmed or downgraded with rationale, and none were dismissed without one.

### Preflight Refutation

Preflight returned BLOCKED on numbers that contradict themselves — three failures and one error alongside exit code 0, and 52 MORE passes than Dev reported. Both anomalies have one cause: it collected outside the configured testpaths.

- The project pins testpaths to the tests package. Three files named for collection sit OUTSIDE it, in the bmad and session packages. Preflight swept them in; they account for the extra passes, the three failures, and the fixture error.
- Those files are untouched by this branch — the branch changes exactly three files, none of them in those packages — and their last commit is on develop. Running them in isolation reproduces the identical 3 failed / 1 error, so the state is pre-existing and unrelated to the branch.
- Running the suite as the project configures it: **5754 passed, 4 skipped, 7 xfailed, exit 0, in 138s. Zero XPASS.** Dev's claim confirmed exactly, on my own run.
- Ruff on the three changed files: **All checks passed.** The 86-to-153 repo-wide count is the pre-existing drift the environment constraints already flagged; this branch adds none of it.

Preflight's mechanical claim was wrong, but the discipline it enforces was still applied — I did not accept Dev's numbers either. I reproduced them.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** the session's branch field (agent-authored, untrusted text) → session parse → normalization to a fixed point → sentinel test → refusal arms → git and gh argv. Safe because the refusal is positioned so that no value can pass it and still reach a subprocess: in the finish entry point, extraction and its handler sit at lines 846-853, the first subprocess is at line 883, and the dry-run branch is at line 930. Everything in between is pure Python — the PR-number extractor is a regex over a dict, the Jira fallback is a dict lookup, and repo resolution is file I/O. Everything BEFORE it is path construction, an existence check, and two file reads. So both the live and the preview arm refuse, and they refuse for the same reason rather than by two separate code paths. Dry-run parity here is structural, not asserted.

**Pattern observed:** refusal placed on the FIXED POINT rather than on the raw value, at the story_finish extractor. This is the correct choice and the non-obvious one. A pre-pass on the raw value would let any formatting layer smuggle a dash past the check — wrap the hostile value in backticks and an annotation and the pre-pass sees a tick, not a dash. Testing after normalization means every spelling of the same value converges on the same decision. I verified this holds rather than assuming it: four wrapped spellings of a dash-leading value all refuse. The ordering inside that check is also load-bearing and correct — the sentinel test runs BEFORE the dash refusal, which is the only reason the lone dash keeps its meaning as an affirmative no-branch mark while every other dash-leading value is refused.

**Error handling:** the refusal is loud and the message is usable, which is the whole point of the arm TEA chose. Verified reachable, including on the shape TEA predicted could not reduce: a value with a LEADING annotation cannot be reduced by an end-anchored strip, and it now aborts with a message naming both the raw value and what it reduced to, plus the remedy. That is exactly the truthful outcome — the alternative arm, returning no-branch, would have routed a garbled field into a silent SUCCESSFUL finish. One swallow exists in the diff, at the no-PR gate predicate, and it is justified: the predicate answers false rather than raising a second time, because by the time the gate is consulted the extractor has already refused such a value loudly. A traceback there would replace a report, not add information.

**Security analysis:** no injection surface. Subprocess is invoked with an argv list and never with a shell, so residual special characters are literal bytes. The dash-leading class — the actual threat, git reading a ref as an option — is refused. Interior whitespace is refused, which incidentally kills command-separator shapes that carry a space. What still passes is the revision-operator and path-traversal family, deliberately, because git's ref grammar rejects them at probe time and routes finish into its unverifiable abort. Error messages are repr-quoted, so a value carrying terminal escapes prints as escaped text rather than executing. Auth is not in scope for this function.

**Hard questions answered:**
- *Does the fixed-point loop terminate on adversarial input?* Yes, and I fed it pathological nesting rather than reasoning about it: alternating tick-and-paren nesting, 20 chained annotations, 4096-deep tick wrapping, unbalanced parens, and a whitespace bomb. Every one terminated in under a millisecond. I then brute-forced the entire input space over the relevant alphabet up to length 8 looking for the worst-case pass count, and separately constructed the slow-reducing family that the brute force revealed. Termination is guaranteed structurally — each changing pass strictly shortens the value — and the bound is a belt on top of that.
- *Is the bound of 8 justified?* The value is sound; Dev's reason for it is not. See the deviation audit. Measured maximum over TEA's table is three passes, not the four claimed.
- *Null and empty inputs?* Missing key, empty string, whitespace-only, annotation-only, and empty ticks all resolve to no-branch, and the gate predicate correctly distinguishes those from the affirmative sentinels. Verified directly.
- *Race conditions and timeouts?* None introduced — the change is pure string logic ahead of the subprocess envelope, and the existing bounded-subprocess envelope is untouched.

**PRIORITY finding — the reversed green guard is legitimate. 162-4's defense is NOT orphaned.** This was the item most likely to hide a silent regression, so I verified TEA's reasoning independently rather than accepting the docstring, and it holds on both axes:
- *Test coverage:* three test classes in the 162-4 suite drive the probe with dash-leading and flag-shaped values by calling the classifier and its argv helpers DIRECTLY, never through the extractor — the argv-shape assertion that no dash-leading candidate reaches git, the real-git replay that hands the emitted argv to the actual binary, and the real-git prefix-semantics test that writes a dash-leading ref with plumbing and demands the probe find it. None of them route through the extractor, so none of them were weakened. The reversed test was a reachability note, not the defense itself.
- *Production reachability, which the docstring asserts and TEA's note is right about:* the classifier's base argument is supplied from the repo config's default branch, which never passes through the extractor at all. So the ref-prefix hardening remains load-bearing in production, not merely in tests. Had that not been true I would have flagged the reversal as HIGH — a layer that only tests can reach is a layer that will be deleted by the next refactor.

**Scope fence intact.** Revision-operator shapes still extract as names — tilde, caret, at-sign, bare HEAD, a full ref path, single and double dot, colon, question mark, glob, and backslash all pass through untouched. The fence test exists and is meaningful: it asserts the extracted value equals the input, so any over-reach into that family fails it, and 162-25 has a test to flip when it takes the probe layer. This story absorbed no probe-layer scope.

**Specialist findings incorporated:**
- **[TEST]** reviewer-test-analyzer, 2 findings, both CONFIRMED and non-blocking. The bound suite's depth parametrization is depth-invariant — I reproduced its simulation and got the same answer, all three depths converge in exactly three passes because the tick strip collapses every repeated tick in one call, so the parametrization pins performance rather than iteration depth. And the dry-run arm of the finish-abort suite drops the four invariants its non-dry-run sibling asserts. Its three negative answers I re-verified myself rather than accepting: 162-4 is not orphaned, the revision-operator fence is meaningful, and the bound starvation genuinely monkeypatches the module attribute because the loop reads it at call time.
- **[TYPE]** reviewer-type-design, 3 findings, all CONFIRMED as real and all DOWNGRADED to non-blocking with rationale, none dismissed. Its high-confidence one — the extractor overloading None, forcing finish to re-normalize the raw field through the gate predicate — is a genuine design smell, but it is deliberate 155-34 layering, it produces no correctness gap, and this story materially IMPROVED it by collapsing two copies of the normalization into one shared helper, which is what closed TEA's drift Gap. The discriminated-outcome refactor is the right fix and is larger than a 1-pt bug. The mutable sentinel set is a fair LOW nit. The hidden tri-state is documented in the Raises section and has exactly one caller, which handles it correctly.
- **[SEC]** reviewer-security, 1 finding, CONFIRMED and non-blocking: non-whitespace control characters pass the refusal arms and reach argv, where argv-list invocation prevents injection and git's ref grammar forces a loud abort. Belt-tightening whose natural home is 162-25's probe layer. Its four order-of-operations traces match mine line for line: no shell invocation anywhere in the file, refusal at 846-853, first subprocess at 883, dry-run branch at 930, and repr-quoted messages that neutralize terminal escapes.
- **[RULE]** reviewer-rule-checker, 0 violations across 16 rules and 58 instances. Accepted, after spot-checking the two claims that would matter most if wrong: the patch targets in the new integration test point at the consuming module rather than the defining one (so the subprocess-count assertion is real), and no broad ValueError handler anywhere in the finish path wraps the extraction site — which matters because the new exception subclasses ValueError and a stray handler would have converted a loud refusal into a silent one. Both hold.
- **[PREFLIGHT]** REFUTED, not dismissed lightly — see the Preflight Refutation above. Its BLOCKED verdict rested on collecting outside the configured testpaths; the correct measurement reproduces Dev's numbers exactly and ruff is clean on all three changed files.

**Observations:** 12 recorded — 7 as Delivery Findings, 4 in the deviation audit, plus the preflight refutation. Zero Critical, zero High. All four acceptance criteria met and independently verified: nested forms extract cleanly under a bound (AC-1), the sentinel set is documented at the constant and pinned by exact set equality (AC-2), dash-leading values cannot reach a downstream git call and the loud arm is chosen and reasoned (AC-3), and the suite exits 0 with only the seven expected loud xfails (AC-4).

**Deferred, explicitly, none blocking:** the parenthesized-tail rewrite arm; the reachable bound and its overstated comment; the depth-invariant bound parametrization; the thin dry-run assertions; control characters at the extractor (natural home is 162-25); the None-overloading discriminated-type refactor; the frozenset nit.

**Handoff:** To SM for finish-story.