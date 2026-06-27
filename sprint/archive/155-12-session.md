---
story_id: "155-12"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 155-12: Finish completes ceremony when merge_pr fails on a CONFLICTING/DIRTY PR - done-but-unmerged (gh #113)

## Story Details
- **ID:** 155-12
- **Jira Key:** (none — local kanban)
- **Workflow:** tdd
- **Type:** bug
- **Points:** 2
- **Priority:** p1
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-27T12:33:17Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-27T11:59:21Z | - | - |
| red | - | 2026-06-27T12:16:23Z | unknown |
| green | 2026-06-27T12:16:23Z | 2026-06-27T12:23:39Z | 7m 16s |
| review | 2026-06-27T12:23:39Z | 2026-06-27T12:33:17Z | 9m 38s |
| finish | 2026-06-27T12:33:17Z | - | - |

## Sm Assessment

**Setup complete — routing to TEA (Lord Melchett) for the RED phase.**

- **Story:** 155-12 (p1, 2pts, tdd) — finish ceremony continues past a failed/
  unmergeable `merge_pr`, recording stories as done over unmerged PRs (gh #113).
- **Repo/branch:** `pennyfarthing` (gitflow) → `feat/155-12-finish-conflicting-pr`
  cut off clean, current `develop`.
- **Jira:** none (local kanban) — claim skipped.
- **Context:** `sprint/context/context-story-155-12.md` — I enriched it from gh #113
  (the `pf context create` stub had no description/ACs). Full problem statement,
  live repro, scope, and AC1–AC4 (pre-merge hard gate, post-merge `mergedAt`
  verification, preflight `ready_to_finish: false`, both-path tests) are there.
- **TEA focus:** write failing tests pinning that a CONFLICTING/DIRTY PR aborts
  finish BEFORE any irreversible step (session intact, YAML untouched, non-zero
  exit), and that a CLEAN PR still completes the ceremony. Likely seams:
  `story_finish.py` ceremony + `pf.preflight`.
- **Out of scope:** the `pf.*` interpreter issue is sibling 155-11 (gh #112).

## TEA Assessment

**Tests Required:** Yes
**Reason:** p1 data-integrity bug in the finish ceremony — behavioural contract must be pinned.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_12_finish_conflicting_pr.py` (new) — pre-merge hard gate + preflight conflict surfacing.

**Tests Written:** 10 tests (4 RED + 6 green-on-arrival guards) covering AC1–AC4.
**Status:** RED confirmed — `4 failed, 6 passed, 0 errored` (scoped `uv run pytest`, verified directly; testing-runner NOT trusted for failure reasons per sidecar).

**RED (drive the fix):**
| Test | AC | Fails today because |
|------|----|----|
| `TestPreMergeGate::test_conflicting_pr_does_not_attempt_merge` | AC1 | no pre-check → `gh pr merge` is attempted on a CONFLICTING PR |
| `TestPreMergeGate::test_conflicting_pr_leaves_no_stray_archive` | AC1 | Step 1 `archive_session` copies before the merge → stray archive on abort |
| `TestPreMergeGate::test_conflicting_pr_error_is_actionable` | AC1 | abort message is generic gh stderr, no rebase/resolve guidance |
| `TestPreflightSurfacesConflict::test_conflicting_pr_issue_is_actionable` | AC3 | `aggregate_results` ignores `PRStatus.mergeable` → generic "still open / merge the PR" |

**Green-on-arrival guards (must stay green — over-reach / regression):**
`TestPreMergeGate::test_conflicting_pr_keeps_session_and_does_not_mark_done`, `TestPostMergeVerifyStillHolds::test_zero_rc_but_open_pr_still_aborts` (AC2, 155-1), `TestCleanPathNotOverBlocked::test_clean_mergeable_pr_completes` (AC4), `TestPreflightSurfacesConflict::test_conflicting_pr_blocks_finish`, `TestPreflightHealthyPrNotBlocked::test_merged_pr_is_ready`, `TestNoSilentSwallowOnProbeError::test_probe_error_never_silently_finishes`. (See Design Deviations — these are intentional green.)

### Rule Coverage

| Rule (python.md) | Test(s) | Status |
|------|---------|--------|
| #1 silent exception swallowing | `test_probe_error_never_silently_finishes` (+ the whole fail-loud suite) | guard (green) |
| #4 subprocess injection (shell=True / interpolation) | N/A — `_run` is list-form, PR number is digit-only (`_extract_pr_number` regex `#(\d+)`); no new shell calls | not violated |
| #3 encoding= / Path.resolve | N/A — no new file opens in scope | not applicable |
| #5 asyncio.gather return_exceptions | N/A — `run_finish_preflight` already passes `return_exceptions=True`; AC3 tests hit the sync `aggregate_results` | not applicable |

**Rules checked:** 1 of 1 genuinely-applicable lang-review rule (#1) has a dedicated guard; #3/#4/#5 assessed N/A with rationale.
**Self-check:** 0 vacuous tests — every test asserts a concrete value/behaviour; no `let _ =`, no `assert True`, no always-None `is_none()`.

**Designed interface for Dev (GREEN):**
- In `finish_story`, BEFORE Step 1 `archive_session`: when a PR is resolved and merge mode is `auto`, probe `gh pr view <pr> --json mergeable,mergeStateStatus`. If not mergeable/clean → return `{"success": False, "error": "PR #<n> is CONFLICTING — rebase on <base> and resolve before finishing", ...}` and run NO irreversible step (no archive, no merge, no transition, no session removal). Keep the 155-1 post-merge `_pr_is_merged` verification intact.
- In `preflight/finish.py::aggregate_results`: when `pr.mergeable == "CONFLICTING"` (PR not merged), emit a critical issue that names the conflict and tells the operator to rebase/resolve — not the generic "Merge the PR before finishing".
- Treat `mergeable == "UNKNOWN"` conservatively (see Delivery Findings Question) — do NOT hard-block.

**Handoff:** To Dev (Baldrick) for GREEN implementation.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — added `_pr_block_reason(pr_number)` (probes `gh pr view --json mergeable,mergeStateStatus,baseRefName`); inserted a pre-merge gate AFTER the dry-run return and BEFORE Step 1 `archive_session` — in `auto` mode a CONFLICTING/DIRTY PR aborts with an actionable rebase message and runs NO irreversible step; removed the now-redundant `get_pr_merge_mode` import (the gate imports it earlier in scope).
- `pennyfarthing-dist/src/pf/preflight/finish.py` — `aggregate_results` now emits a "rebase the PR and resolve the conflicts" critical issue when `pr.mergeable == "CONFLICTING"`, instead of the misleading generic "Merge the PR before finishing".

**Tests:** 10/10 story tests passing (GREEN — the 4 RED now pass, the 6 guards stayed green). Regression: 61 finish-flow siblings (155-1/151-3/155-3/155-4/no-jira/147-12) + 17 preflight-independence green. `ruff check` clean.

**Real-gh check:** `gh pr view <n> --json mergeable,mergeStateStatus,baseRefName` confirmed valid; a MERGED PR returns `mergeable: UNKNOWN` → the gate's `UNKNOWN`→don't-block path is correct (no false block on merged/computing PRs; the 155-1 `_pr_is_merged` backstop catches a real conflict the merge attempt then hits). Resolves TEA's UNKNOWN Question.

**Branch:** feat/155-12-finish-conflicting-pr (pushed)

**Handoff:** To Reviewer (Captain Darling) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 88 passed (10 story + 78 regression), ruff clean, 0 smells | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer ([EDGE]) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer ([SILENT]) |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer ([TEST]) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer ([DOC]) |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer ([TYPE]) |
| 7 | reviewer-security | Yes | findings | 1 (LOW: baseRefName interpolation) | confirmed 1 (downgraded LOW, non-blocking), deferred to follow-up |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer ([SIMPLE]) |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer ([RULE]) |

**All received:** Yes (2 enabled returned — preflight + security; 7 disabled via `workflow.reviewer_subagents`, covered directly per `disabled-reviewer-subagents-shift-burden-to-you`)
**Total findings:** 1 confirmed (LOW, non-blocking), 0 dismissed, 1 deferred (follow-up hardening)

## Review Observations

1. `[VERIFIED]` Pre-merge gate sits BEFORE Step 1 `archive_session` — evidence: `story_finish.py` gate block (`if pr_number and get_pr_merge_mode()=="auto": ... return`) is inserted immediately after the dry-run `return` and before `# --- Step 1: Archive session ---` / `archive_dest = ...`. Complies with the issue's "do not archive/remove the session or touch the YAML." Pinned by `test_conflicting_pr_leaves_no_stray_archive`.
2. `[SILENT]` (self — subagent disabled) Fail-loud chain verified end-to-end: `_pr_block_reason` returns `None` on `returncode!=0` and on `(JSONDecodeError, ValueError)` — documented sentinels meaning "do not block", NOT a swallow. A genuinely CONFLICTING PR cannot silently complete: if the probe errors → `None` → falls through to `gh pr merge` (rc!=0 on a dirty PR) → 155-1's returncode guard aborts; if the merge no-ops → `_pr_is_merged` (`story_finish.py:175-182`) returns False → abort. No silent-failure hole introduced.
3. `[EDGE]` (self) `mergeable` taxonomy fully handled: `CONFLICTING`/`mergeStateStatus==DIRTY` → block; `MERGEABLE`/`UNKNOWN`/missing/`""` → `None`. `UNKNOWN`→don't-block validated against REAL `gh` (a merged PR returns `mergeable: UNKNOWN`). `BEHIND`/`BLOCKED` fall through to merge + backstop — conservative and in-scope (#113 is specifically CONFLICTING/DIRTY). Empty `gh` stdout → `json.loads("")` → caught → `None`. `baseRefName` missing → `or "the base branch"` fallback.
4. `[SEC]` reviewer-security LOW confirmed + downgraded: `baseRefName` (from `gh` JSON) is interpolated into the returned error string — a theoretical terminal-escape vector. Downgraded to LOW/non-blocking: git refname rules (`git check-ref-format`) forbid ASCII control characters, so a real branch name cannot carry escape sequences; and this is developer-local CLI output, not a network response. Captured as an optional-hardening Delivery Finding (`re.sub(r'[^\w/.-]','',base)`), consistent with the 160-18/160-22 sanitisation ethos. Not a blocker (`severity-by-blast-radius`).
5. `[TEST]` (self) Inverse-binding probe run: reverted both source files to `origin/develop` keeping the new test file → `4 failed, 6 passed` — the exact original RED. Proves the 4 behavioural tests genuinely bind to the fix (not green-for-the-wrong-reason) and the 6 guards are intentional green. Mock target correct: `patch("pf.sprint.story_finish._run")` patches where used. No vacuous assertions.
6. `[TYPE]` (self) `_pr_block_reason(pr_number: str) -> str | None` — clean signature, `Optional` return as sentinel; defensive `str(data.get(...)).upper()` coercion on `gh` fields. No stringly-typed regressions (`PRStatus.mergeable` is a pre-existing `str | None`).
7. `[DOC]` (self) Docstrings/comments accurate and non-misleading: the helper docstring correctly states `None` covers UNKNOWN/error and references the `_pr_is_merged` backstop; the gate and preflight comments match behaviour.
8. `[SIMPLE]` (self) Minimal implementation. TEA's SOUL-#2 consolidation (`_pr_is_merged` + `_pr_block_reason` sharing one `gh pr view`) was deliberately deferred by Dev — acceptable minimalism, captured as a non-blocking Delivery Finding, not over-engineered.
9. `[RULE]` (self) python.md #1–#13 enumerated against the diff — all compliant (see `### Rule Compliance`).
10. `[VERIFIED]` Import hygiene: `from pf.common.pr_config import get_pr_merge_mode` moved into the gate (function scope); the redundant Step-2 re-import removed — evidence: diff `@@ -314` deletes the duplicate import. `ruff check` clean; no F811/F401.

### Rule Compliance (python.md, exhaustive over the diff)

| # | Rule | Verdict | Evidence |
|---|------|---------|----------|
| 1 | Silent exception swallowing | COMPLIANT | `_pr_block_reason` typed catch `(JSONDecodeError, ValueError)` returns documented `None` sentinel; not a swallow; backstopped by `_pr_is_merged`. |
| 2 | Mutable default arguments | N/A | No new defaults. |
| 3 | Type annotations at boundaries | COMPLIANT | `_pr_block_reason(pr_number: str) -> str | None` fully annotated. |
| 4 | Logging coverage/correctness | N/A | Module returns result dicts/steps (SOUL #10), no logging; error is returned, not logged. |
| 5 | Path handling | N/A | No new file opens or path concatenation in the diff. |
| 6 | Test quality | COMPLIANT | Meaningful assertions; correct mock target; inverse-binding probe confirms binding; no skips/vacuous asserts. |
| 7 | Resource leaks | N/A | No new resources. |
| 8 | Unsafe deserialization | COMPLIANT | List-form `_run` (no `shell=True`); `pr_number` digit-only (`#(\d+)`); `json.loads` on local `gh` stdout with failure handled. |
| 9 | Async pitfalls | N/A | No new async; `aggregate_results` is sync. |
| 10 | Import hygiene | COMPLIANT | Import relocated, redundant removed; no star/circular; ruff clean. |
| 11 | Input validation at boundaries | COMPLIANT | `pr_number` digit-only; `mergeable`/`mergeStateStatus` coerced via `str().upper()`. (`baseRefName` → LOW [SEC], see above.) |
| 12 | Dependency hygiene | N/A | No dependency changes. |
| 13 | Fix-introduced regressions | COMPLIANT | 78-test regression batch green; inverse-binding probe confirms no green-for-wrong-reason. |

### Devil's Advocate

Suppose this code is broken. **gh outage / rate-limit:** the new gate adds a `gh pr view` before the merge; if `gh` is down, `returncode!=0` → `None` → the gate does NOT block — it falls through to the existing merge path, where `gh pr merge` also fails and 155-1's returncode guard aborts. So an outage degrades to the prior failure behaviour, never a false-block and never a silent done. **TOCTOU:** between the gate's `gh pr view` and the later `gh pr merge`, `develop` could advance and introduce a conflict; the gate would have said "mergeable" but the merge then fails → 155-1 aborts. The window is fully backstopped, no new corruption. **`mergeStateStatus==DIRTY` but `mergeable==MERGEABLE`:** the gate blocks on EITHER signal; `DIRTY` is a settled "can't create a clean merge commit", so blocking is correct, and `gh` only reports `DIRTY` after computing (it returns `UNKNOWN` while computing) — so no transient false-block. **`BEHIND`/`BLOCKED` PRs:** not blocked (correct — base-behind/failing-checks are not merge conflicts; they fall to the merge attempt + backstop). **Malicious input:** the only external strings are `pr_number` (digit-only regex → no shell injection, list-form subprocess) and `baseRefName` (subject to git refname rules → no control chars → the LOW terminal-escape finding is non-exploitable in practice). **Confused user:** the abort message names the PR and says "rebase on <base> and resolve the conflicts before finishing" — unambiguous and actionable, a strict improvement over the prior generic gh stderr. **Stressed filesystem:** the gate performs no filesystem writes; because it now precedes `archive_session`, a conflicting finish avoids the archive copy entirely — strictly better than before. **Unexpected `get_pr_merge_mode()` value:** the gate runs only when `== "auto"`; any other value skips it and proceeds to the existing human/auto/else merge handling — no crash. I could not manufacture a break. The design is defensively sound and consistently backstopped by the 155-1 verification it was built to complement.

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** Story 155-12 adds the pre-merge mergeability hard-gate that sibling 155-1 left open (gh #113). The gate correctly precedes every irreversible finish step, fails loud with an actionable rebase message, treats indeterminate (`UNKNOWN`/error) mergeability conservatively (backstopped by 155-1's post-merge `_pr_is_merged`), and surfaces the conflict in the finish preflight. Implementation is minimal and faithful to TEA's designed interface.

**Data flow traced:** session `**PR:**` field → `_extract_pr_number` (`#(\d+)`, digit-only) → `_pr_block_reason` runs `gh pr view <n> --json mergeable,mergeStateStatus,baseRefName` (list-form subprocess, no shell) → on CONFLICTING/DIRTY returns an error string → `finish_story` returns `{success: False, error}` with NO archive/merge/transition/session-removal. Safe: input is digit-constrained; `baseRefName` is git-refname-constrained; no network sink.

**Subagent dispatch tags:** `[EDGE]` `[SILENT]` `[TEST]` `[DOC]` `[TYPE]` `[SEC]` `[SIMPLE]` `[RULE]` — preflight + security returned (clean / 1 LOW); the other seven were disabled via `workflow.reviewer_subagents` and covered directly by the Reviewer (see Observations).

**Findings:**

| Severity | Issue | Location | Disposition |
|----------|-------|----------|-------------|
| [LOW] | `baseRefName` from `gh` JSON interpolated into the returned error string (theoretical terminal-escape) | `story_finish.py` `_pr_block_reason` | Confirmed, non-blocking — non-exploitable (git refname rules forbid control chars; local CLI not network). Optional `re.sub` hardening → Delivery Finding. |

No Critical/High issues. Tests pass (88), regression clean, ruff clean, tests proven to bind (inverse-binding probe). All 13 python.md rules compliant.

**Handoff:** To SM (Edmund Blackadder) for finish-story.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### TEA (test design)
- **Improvement** (blocking): The mergeability gate must run BEFORE Step 1 `archive_session`, not just before the merge. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`finish_story` — today Step 1 copies the session into `sprint/archive/` at L306-308, unconditionally, before Step 2's merge; an aborted CONFLICTING finish therefore leaves a stray archived copy). Pinned by `test_conflicting_pr_leaves_no_stray_archive`. *Found by TEA during test design.*
- **Improvement** (non-blocking): `_pr_is_merged` (L168) and the new pre-merge mergeability probe both call `gh pr view` — consider one consolidated PR-status fetch (`gh pr view <n> --json state,mergeable,mergeStateStatus,mergedAt`) reused by both the gate and the post-merge check (SOUL #2, fewer gh round-trips). Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by TEA during test design.*
- **Question** (non-blocking): `gh`'s `mergeable` field returns `UNKNOWN` while GitHub is still computing mergeability. A naive "block unless MERGEABLE/CLEAN" gate would false-block a PR GitHub simply hasn't finished checking. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (gate should treat `UNKNOWN` conservatively — e.g. brief retry or fall through to the merge attempt guarded by the 155-1 backstop, NOT a hard block). My RED tests use `CONFLICTING` explicitly so they do not constrain the `UNKNOWN` decision — Dev's call. *Found by TEA during test design.*
- **Gap** (non-blocking): the finish preflight's `check_lint` (`pennyfarthing-dist/src/pf/preflight/finish.py` L169-195) shells `npm run lint` on this Python-only repo — a pre-existing false-blocker already owned by sibling story **155-5** (stale `repos.yaml` `language: javascript`). Out of scope for 155-12; noted so Dev does not "fix" it here. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): TEA's SOUL-#2 consolidation (one `gh pr view` shared by the new `_pr_block_reason` gate and `_pr_is_merged`) was deliberately NOT done — kept the change minimal and the two concerns (pre-merge gate vs post-merge verify) separable. The gate adds one `gh pr view` round-trip on the finish path. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (future refactor: fetch `state,mergeable,mergeStateStatus,mergedAt` once and share). *Found by Dev during implementation.*
- **Improvement** (non-blocking): the real-gh check confirmed a MERGED (and freshly-opened/computing) PR reports `mergeable: UNKNOWN`, so the gate's `UNKNOWN`→don't-block branch is load-bearing, not merely defensive — re-finishing an already-merged PR is correctly not blocked (merge no-ops, 155-1 verifies MERGED). Resolves TEA's UNKNOWN Question. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): sanitize `baseRefName` before interpolating it into the abort message (e.g. `re.sub(r'[^\w/.-]', '', base)`) — defense-in-depth against a terminal-escape edge that git refname rules already prevent and that has no network sink. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_pr_block_reason`). Optional hardening, consistent with the 160-18/160-22 sanitisation series. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): re-confirms TEA/Dev's SOUL-#2 consolidation — `_pr_is_merged` and `_pr_block_reason` could share one `gh pr view --json state,mergeable,mergeStateStatus,mergedAt`. Deferred by Dev; a valid future refactor, not required here. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### TEA (test design)
- **AC2 (post-merge `mergedAt` verification) tested as a GREEN-on-arrival guard, not RED**
  - Spec source: context-story-155-12.md, AC2
  - Spec text: "after attempting the merge, verify mergedAt != null (or a merge commit exists) before proceeding"
  - Implementation: AC2 is already shipped by sibling 155-1 (`_pr_is_merged` checks `state == MERGED`); I assert it as an intentional regression guard (`TestPostMergeVerifyStillHolds`) rather than forcing a spurious RED.
  - Rationale: writing a RED test for already-correct behavior would be false-RED; the value here is ensuring 155-12's new gate does not regress it.
  - Severity: minor
  - Forward impact: none
- **AC3 preflight `ready_to_finish: false` is GREEN-on-arrival; the RED is specifically conflict-surfacing**
  - Spec source: context-story-155-12.md, AC3
  - Spec text: "surface this in the sm-finish preflight as ready_to_finish: false with the PR state in issues[]"
  - Implementation: an OPEN+CONFLICTING PR is already `ready_to_finish: false` (it is OPEN). The genuine gap is that `aggregate_results` ignores `PRStatus.mergeable`, so the conflict is reported as the generic "PR is still open / Merge the PR" (misleading — you must rebase first). RED test pins that the conflict is named (`test_conflicting_pr_issue_is_actionable`); the ready-False assertion is kept as a guard.
  - Rationale: faithful to "PR state in issues[]" — the conflict state must reach the operator, not just a generic open-PR message.
  - Severity: minor
  - Forward impact: none
- **Abort/issue message wording left to Dev (assert only an actionable keyword)**
  - Spec source: context-story-155-12.md, AC1/AC3
  - Spec text: 'a clear message ("PR #N is CONFLICTING — rebase on <base> and resolve before finishing")'
  - Implementation: tests assert the message names the PR and matches `rebase|resolve|conflict` (case-insensitive), not an exact string.
  - Rationale: per TEA practice, pin the behavioural contract (actionable remedy) without coupling to exact wording.
  - Severity: minor
  - Forward impact: none
- **Added a rule-#1 (no-silent-swallow) probe-error guard beyond the literal ACs**
  - Spec source: .pennyfarthing/gates/lang-review/python.md rule #1; SOUL #1/#10
  - Spec text: "except Exception: pass — swallows all errors silently"
  - Implementation: `TestNoSilentSwallowOnProbeError` pins that an unverifiable PR state (failed `gh pr view`) fails loud, never finishes silently — so the new gate cannot open a silent-fallback hole bypassing the 155-1 backstop. GREEN today; a guard, not a RED.
  - Rationale: the central lang-review rule for a fail-loud story; cheap insurance against the exact failure class this story exists to kill.
  - Severity: minor
  - Forward impact: none

### Dev (implementation)
- No deviations from spec. Implemented TEA's designed interface verbatim — pre-merge gate before `archive_session`, `gh pr view --json mergeable,mergeStateStatus` probe, actionable rebase message, `UNKNOWN`/`gh`-error → don't-block (155-1 backstop), and the preflight conflict issue. The probe additionally fetches `baseRefName` so the message names the real base branch (within the designed interface, not a divergence).

### Reviewer (audit)
- **TEA — AC2 post-merge verify tested as green-on-arrival guard** → ✓ ACCEPTED by Reviewer: 155-1 already ships `_pr_is_merged`; asserting it as a regression guard (not a forced RED) is correct, not a false-RED.
- **TEA — AC3 preflight ready-False green; RED is conflict-surfacing** → ✓ ACCEPTED by Reviewer: an OPEN+CONFLICTING PR is already `ready_to_finish: false`; the genuine gap (naming the conflict in `issues[]`) is correctly the RED. Faithful to "PR state in issues[]".
- **TEA — abort/issue message wording left to Dev** → ✓ ACCEPTED by Reviewer: pinning an actionable-keyword regex over an exact string is sound TEA practice; Dev's wording satisfies it.
- **TEA — rule-#1 no-silent-swallow probe-error guard beyond literal ACs** → ✓ ACCEPTED by Reviewer: the central lang-review rule for a fail-loud story; I independently verified the fail-loud chain (probe error → None → merge → 155-1 abort) holds.
- **Dev — No deviations from spec (+ `baseRefName` within-interface)** → ✓ ACCEPTED by Reviewer: implementation matches TEA's designed interface verbatim; the extra `baseRefName` fetch names the base branch in the message (within the interface, not a divergence). No undocumented deviations found in review.