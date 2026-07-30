---
story_id: "155-9"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-9: Harden finish archive epic-field: test caller-wiring/edges, tighten vacuous assertion, guard step-4b read_sprint (155-4 review deferrals)

## Story Details
- **ID:** 155-9
- **Jira Key:** (none — Jira-less story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 2
- **Type:** chore
- **Priority:** p3
- **Repos:** pennyfarthing
- **Branch:** feat/155-9-archive-epic-field-hardening
- **PR:** #152 - fix(155-9): harden finish archive epic-field — coverage pins + step-4b read_sprint guard

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-27T12:56:25Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-27T12:35:13Z | 2026-07-27T12:36:42Z | 1m 29s |
| red | 2026-07-27T12:36:42Z | 2026-07-27T12:45:03Z | 8m 21s |
| green | 2026-07-27T12:45:03Z | 2026-07-27T12:47:34Z | 2m 31s |
| review | 2026-07-27T12:47:34Z | 2026-07-27T12:56:25Z | 8m 51s |
| finish | 2026-07-27T12:56:25Z | - | - |

## Story Context

**From 155-4 Reviewer deferred findings (LOW, PR pennyfarthing#126):**

The 155-4 tests hit only the `_add_story_to_completed` seam. Several gaps remain:

1. The step-4b de-swallow in `finish_story` (the other half of the bug) is uncovered
2. The jira-keyed-epic priority branch uncovered
3. The standalone-story explicit-fallback uncovered
4. The `except ValueError` branch (story_finish.py:112-118) uncovered
5. Vacuous assertion at test_155_4_finish_archive_epic_field.py:177 ('assert ghost is None or ...strip()') accepts a fabricated non-empty epic on the raise-path — tighten to 'assert ghost is None'
6. story_finish.py:464 step-4b read_sprint is unwrapped — an unexpected I/O error there now crashes finish AFTER merge/transition (steps 4c-7 skipped); add a graceful-degrade guard (near-nil window since read succeeded earlier same run, but defensible)

**Note:** Finding 5 (non-blocking, accepted): 4b {success:False} prints but top-level finish exit code stays 0 — invisible to non-interactive $? callers; acceptable per documented non-fatal intent, revisit only if finish gains hard-fail semantics.

## Sm Assessment

Story 155-9 selected via `pf sprint work next` (merge gate passed — PR #51 is sprint bookkeeping awaiting Keith's merge, not a story PR). Setup complete: session file, story/epic context, and branch `feat/155-9-archive-epic-field-hardening` off `develop` in `pennyfarthing/`. Jira-less story — claim skipped, no key fabricated.

Routing: explicit `workflow: tdd` tag overrides the 1-2pt trivial fallback → phased TDD, next agent TEA (red phase). Scope is test-hardening of the 155-4 archive epic-field work: six enumerated gaps in Story Context, all in `story_finish.py` and `test_155_4_finish_archive_epic_field.py`. TEA owns test design; Dev implements the step-4b guard (item 6) minimally.

## Impact Summary

All findings non-blocking; story shipped via PR pennyfarthing#152. Follow-up work implied:
- **story_finish.py**: record a skipped/failed 4b step when `find_story_in_data` returns None without an exception (Dev finding, pre-existing); rename the step-4b read binding to avoid the stale-`data` trap (Reviewer).
- **test_155_9_finish_archive_epic_hardening.py**: strengthen the guard-test error assert to pin exception-text fidelity (Reviewer); `encoding=` omissions fold into existing story 155-23 (Reviewer).

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- **Gap** (non-blocking): When the step-4b re-read succeeds but `find_story_in_data` returns `None` (story vanished from sprint data mid-finish), the `if completed_story:` block skips silently — no 4b step is recorded at all. Pre-existing behavior, distinct from the exception path this story guards.
  Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (record a skipped/failed 4b step on the None path too).
  *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): Guard-test error assertion pins only non-emptiness, not that the recorded 4b message reflects the injected exception — a generic placeholder string would pass; assert the exception text appears (mirroring the `"144-9" in err` style of the sibling ValueError test).
  Affects `pennyfarthing-dist/src/pf/tests/test_155_9_finish_archive_epic_hardening.py` (strengthen `entries[0]["error"]` assert in TestStep4bReadSprintGuard).
  *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `data` local is reused across three temporally-distinct read_sprint snapshots (story_finish.py:299/532/612); on the guard's except path it retains a stale snapshot — harmless today but a latent trap; bind the step-4b read to a distinct name.
  Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (rename step-4b read binding).
  *Found by Reviewer during code review.*
- **Gap** (non-blocking): New test file's 6 `read_text`/`write_text` calls omit `encoding=` — inherited sibling-file convention, test-only; fold into the existing encoding-sweep story 155-23 rather than filing new work.
  Affects `pennyfarthing-dist/src/pf/tests/test_155_9_finish_archive_epic_hardening.py` (encoding= sweep, deliver via 155-23).
  *Found by Reviewer during code review.*

## Design Deviations

### TEA (test design)
- **Gaps 1–4 are intentional green-on-arrival coverage pins, not RED tests**
  - Spec source: context-story-155-9.md, Problem items 1–4
  - Spec text: "the step-4b de-swallow in finish_story ... the jira-keyed-epic priority branch ... the standalone-story explicit-fallback ... the except ValueError branch ... uncovered"
  - Implementation: 9 tests in `test_155_9_finish_archive_epic_hardening.py` that PASS against HEAD — the 155-4 implementation already shipped these branches; the gap was coverage, not behavior
  - Rationale: forcing a spurious RED on shipped-correct code would require breaking it; green pins lock the uncovered branches against regression (`ac-as-green-regression-guard` pattern)
  - Severity: minor
  - Forward impact: Dev's only code change is the gap-6 guard; Reviewer should not read the green tests as vacuous
  - → ✓ ACCEPTED by Reviewer: inverse-binding probe confirms the pins are real (2 failed / 11 passed on develop source — the 2 guard tests bind, all pins held); test-analyzer found zero vacuous assertions in the new file
- **Gap 6 contract pinned beyond the literal "add a guard" wording**
  - Spec source: context-story-155-9.md, Problem item 6
  - Spec text: "story_finish.py:464 step-4b read_sprint is unwrapped ... add a graceful-degrade guard"
  - Implementation: the 2 RED tests additionally require (a) the 4b failure be RECORDED as a failed step with an error message, (b) `success: True` overall, (c) steps 4c–7 still run and the session is removed
  - Rationale: a bare try/except-pass guard would satisfy "doesn't crash" but silently skip the bookkeeping — the exact swallow class epic 155 exists to kill (SOUL #10); the recorded-step contract matches the existing 4b failure wiring
  - Severity: minor
  - Forward impact: constrains Dev to a record-and-continue guard shape; wording of the error message is left free
  - → ✓ ACCEPTED by Reviewer: the beyond-wording contract is exactly the truthfulness-epic intent; test-analyzer's mutation runs prove it kills silent-swallow and no-record guard shapes
- **Gap 5 fixed by editing the sibling 155-4 test file during RED**
  - Spec source: context-story-155-9.md, Problem item 5
  - Spec text: "vacuous assertion at test_155_4_finish_archive_epic_field.py:177 ... tighten to 'assert ghost is None'"
  - Implementation: edited `test_155_4_finish_archive_epic_field.py` in place (tightened assert + explanatory comment); verified still green
  - Rationale: the story explicitly scopes this test edit, and the TEA definition mandates fixing vacuous assertions in pre-existing tests; deferring it to Dev would split one logical change across phases
  - Severity: minor
  - Forward impact: none — the tightened assert passes against HEAD and any correct fix
  - → ✓ ACCEPTED by Reviewer: story-scoped edit; test-analyzer confirms the old disjunct's dead arm is gone and the contract is strictly stronger

### Dev (implementation)
- **Broad `except Exception` on the step-4b guard**
  - Spec source: session TEA Assessment, "Designed interface for Dev (gap 6)"
  - Spec text: "Catch breadth (Exception vs (OSError, ValueError)) is Dev's call — both parametrized cases must pass"
  - Implementation: `except Exception` around the step-4b `read_sprint`/`find_story_in_data` re-read, with the failure recorded in the step entry
  - Rationale: the guard runs after the irreversible merge/transition where ANY escape strands the story (session kept, steps 4c-7 skipped); narrowing to (OSError, ValueError) would leave e.g. a ruamel parser exception un-guarded for zero benefit — the broad catch is the fail-loud-recorded kind lang-review #1 permits, not a swallow
  - Severity: minor
  - Forward impact: none — pre-empts a Reviewer lang-review #1 flag on the diff
  - → ✓ ACCEPTED by Reviewer: rule #1 requires the failure be surfaced, not the catch be narrow — the recorded step entry satisfies it; `except Exception` does not catch KeyboardInterrupt/SystemExit (BaseException), so no over-catch

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_9_finish_archive_epic_hardening.py` (new) — 11 tests: 9 green-on-arrival coverage pins (gaps 1–4), 2 genuinely RED guard tests (gap 6, parametrized oserror/valueerror)
- `pennyfarthing-dist/src/pf/tests/test_155_4_finish_archive_epic_field.py` (edited) — gap 5: vacuous `ghost is None or ...strip()` tightened to `ghost is None`; still green

**Tests Written:** 11 new + 1 tightened, covering all 6 story-context gaps
**Status:** RED confirmed — scoped run `uv run pytest test_155_9_*.py test_155_4_*.py -rA`: **2 failed, 11 passed, 0 errored**. Both failures are the gap-6 guard tests, failing via explicit `pytest.fail` carrying the escaped exception (`ValueError`/`PermissionError` propagating out of `finish_story` at the step-4b re-read) — the right reason, verified directly (not via testing-runner prose).

**Designed interface for Dev (gap 6):** wrap the step-4b block's `read_sprint`/`find_story_in_data` re-read in `story_finish.py` (the `--- Step 4b ---` block) so an exception there (a) appends a `{"step": "4b", "action": "add_completed_story", "success": False, "error": ...}` step, (b) does NOT abort finish (steps 4c–7 run, session removed, `success: True`). Catch breadth (Exception vs (OSError, ValueError)) is Dev's call — both parametrized cases must pass. No other source change is needed; gaps 1–5 are already-shipped behavior now pinned by tests.

### Rule Coverage

| Rule (python.md) | Test(s) | Status |
|------|---------|--------|
| #1 no silent swallowing | `test_step4b_read_sprint_crash_must_not_abort_finish` (recorded-step assert), `test_finish_surfaces_step4b_failure_and_still_completes` | 2 failing / 1 passing |
| #5 path handling (CWE-22) | `test_unsafe_sprint_id_surfaces_ensure_archive_valueerror` | passing (pin) |
| #6 test quality | gap-5 tightening in `test_155_4_finish_archive_epic_field.py`; self-check below | passing |

**Rules checked:** 3 of 3 applicable lang-review rules have test coverage (#2–#4 mutable defaults/annotations/logging: no new source code in RED; test files annotated)
**Self-check:** 1 vacuous assertion found in pre-existing 155-4 suite and fixed (gap 5); no `let _ =`-class, always-true, or dead-arm asserts in the new suite; lint clean (`ruff check` passed after removing one unused import)

**Handoff:** To Dev (B.A.) for the gap-6 graceful-degrade guard in `story_finish.py`

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — wrapped the step-4b `read_sprint`/`find_story_in_data` re-read in a try/except (23+/2-); on exception, appends a `{"step": "4b", "action": "add_completed_story", "success": False, "error": ...}` step and continues with steps 4c-7. Exactly TEA's designed interface; no other source change.

**Tests:** 13/13 story tests passing (GREEN — was 2 failed/11 passed at RED); finish-flow regression batch 107/107 (`test_155_1`, `test_155_12`, `test_155_15`, `test_155_8`, `test_155_3`, `test_story_finish_no_jira`, `test_151_3`, `test_147_12`, `test_archive_epic`, `test_archive_epic_field_validation`); `ruff check` clean. Scoped runs only (full suite leaks a branch checkout via test_git_utils).

**Branch:** feat/155-9-archive-epic-field-hardening (pushed, commits b9177be40 test + 473f2e83d fix)

**Handoff:** To Reviewer (Colonel Lynch) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (120 tests green, ruff clean, tree clean, no debug code) | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly by Reviewer (binding analysis on except path, no dup step entries, BaseException breadth, `data`/`_epic` post-4b consumption traced) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly: the new except RECORDS the failure; the adjacent non-exception `completed_story is None` silent skip is pre-existing and already filed by Dev as a Delivery Finding |
| 4 | reviewer-test-analyzer | Yes | findings | 2 (medium) | confirmed 2 (downgraded: 1 MEDIUM non-blocking, 1 LOW), dismissed 0 |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered directly: new comment block accurate for the guarded path; tightened-assert comment accurate; no stale docs |
| 6 | reviewer-type-design | Yes | findings | 3 (1 medium, 2 low) | confirmed 3 (all non-blocking: medium one duplicates Dev's own Delivery Finding), dismissed 0 |
| 7 | reviewer-security | Yes | clean | 2 notes (low, non-blocking) | confirmed 2 as informational — sink traced to local CLI stdout only (cli.py:468-484), no network path |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — domain covered directly: 23+/2- minimal guard, matches sibling step-entry shape, no over-engineering |
| 9 | reviewer-rule-checker | Yes | findings | 1 (rule #5, high confidence) | confirmed 1, downgraded LOW non-blocking (inherited sibling-file convention; deferral target exists: backlog story 155-23 encoding sweep) |

**All received:** Yes (5 returned, 4 disabled with domains covered directly)
**Total findings:** 8 confirmed (0 blocking), 0 dismissed, 6 deferred as non-blocking notes/findings

### Rule Compliance

Per lang-review python.md, applied to every changed symbol (rule-checker exhaustive pass, cross-checked by me):

| Rule | Instances | Verdict |
|------|-----------|---------|
| #1 silent swallowing | new `except Exception` (story_finish.py:612-626) | COMPLIANT — failure recorded in step entry, comment + deviation document the breadth; does not catch BaseException |
| #2 mutable defaults | 9 new functions | COMPLIANT (None/immutable defaults) |
| #3 annotations | finish_story unchanged sig; all new test helpers annotated | COMPLIANT |
| #4 logging | no logging imports in touched files | N/A |
| #5 path/encoding | 6 test-file read_text/write_text without encoding= | CONFIRMED LOW — test-only, tmp_path ASCII fixtures, inherited sibling convention; deferred to 155-23 (the existing encoding-sweep backlog story). Rule-matching → not dismissed |
| #6 test quality | 9 test functions / 10 cases + tightened 155-4 assert | COMPLIANT — zero vacuous asserts; mutation-verified; old dead-arm disjunct removed |
| #7 resource leaks | Path read/write (self-closing) | COMPLIANT |
| #8-#12 | no instances in diff | N/A |
| #13 fix-introduced regressions | cli.py:468-487 caller; test_demo_finish_hook 4b consumer; 14 finish_story test files | COMPLIANT — caller reads error via .get, happy path byte-identical; full caller-file sweep run (see below) |

### Reviewer observations (own analysis + confirmed subagent findings)

1. [VERIFIED] The guard converts a post-merge crash into a recorded result — story_finish.py:612-626 binds `completed_story = None` unconditionally in the except and appends a `success: False` step with error text; complies with SOUL #10 and the documented no-throw contract. Inverse-binding probe: with source reverted to origin/develop and the new tests kept, exactly the 2 guard tests fail (escaped PermissionError/ValueError) and all 11 others pass — the tests bind to this fix.
2. [VERIFIED] Caller safety — cli.py:468-484 iterates steps printing `step["step"]/["action"]` (always present in the new entry) and `.get("error")` defensively; no KeyError surface. Only production caller (grep-verified).
3. [VERIFIED] Subset-green check — beyond Dev's 10-file regression batch I ran the 6 remaining test files touching finish_story: 97 passed, 3 failed in test_153_4 — reproduced identically on clean origin/develop source (Jira-transition environmental failures, `transition_story` internals, untouched by this diff) → pre-existing, out of scope.
4. [TEST] (MEDIUM, non-blocking) Guard-test error assert checks only non-emptiness (test_155_9:~569), not that the recorded message reflects the injected exception — a generic-placeholder error string would pass. Mutation runs prove the tests kill the two plausible wrong-fix shapes (no-record, no-sentinel), so the guard contract itself is pinned; only the message-fidelity dimension is unpinned. Deferred as Delivery Finding.
5. [TEST] (LOW) `_read_sprint_then_boom` is call-order-coupled (also fires at the line-532 wrapped read, harmlessly). Deliberate, documented in the fake's docstring; a future unguarded read between validation and 4b would shift the failure site. Test-maintenance note only.
6. [TYPE] (LOW) `data` local reused across three temporally-distinct reads (299/532/612); on the except path it silently retains a stale snapshot. Harmless today (consumed on next line, never referenced after 4b — grep-verified). Maintenance note.
7. [TYPE] (MEDIUM→non-blocking) `completed_story is None` without exception → no 4b entry recorded (silent skip). Pre-existing path, NOT introduced by this diff, and already self-reported by Dev as a Delivery Finding. Confirmed; defer.
8. [SEC] {exc} interpolation in the new 4b error entry is CWE-209-shaped but the sink is local CLI stdout only — security subagent traced every consumer; no Frame/network route wraps finish_story. Confirmed non-blocking (consistent with the 160-18/160-22 network-sink series scope).
9. [RULE] Test-file encoding= omissions — confirmed LOW, deferred to 155-23 (see Rule Compliance).
10. [EDGE]/[SILENT]/[DOC]/[SIMPLE] domains covered directly (subagents disabled): no findings beyond the above.

### Devil's Advocate

Assume this guard is wrong. What's the worst it can do? First: it could mask a real, persistent sprint-data corruption — the finish completes, prints one failed 4b step, and the completed-row bookkeeping is simply absent. Is that acceptable? Yes by design: the merge and done-transition already happened irreversibly before step 4b; crashing there (the old behavior) left MORE damage — session stranded, steps 4c-7 skipped, raw traceback at the CLI — and repaired nothing. The failure is recorded in the steps output the operator actually sees. Second: could the broad `except Exception` eat something that should abort finish? The only statements guarded are a read and a pure lookup; no mutation happens inside the try, so there is no half-written state to roll back — the worst hidden failure class is "bookkeeping skipped", which is precisely the documented non-fatal contract. KeyboardInterrupt/SystemExit pass through (BaseException). Third: could the tests lie? The strongest attack is that both guard tests inject exceptions via a call-counting fake — if a refactor reorders read_sprint calls, the test could exercise the wrong site. True (finding 5), but today's binding is proven by the inverse probe and by mutation runs that kill the no-record and no-sentinel variants. Fourth: a malicious/garbled sprint YAML — the charset guard (155-7) and the empty-epic write guard (151-2) are both covered by new in-diff tests surfacing as result objects, and the write guard leaves the archive byte-identical (asserted). Fifth: the 4b failure prints but finish exits 0 — invisible to `$?` scripts; that is the story-context's accepted Finding 5, explicitly out of scope. Nothing here rises to blocking.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** sprint YAML (user-authored) → read_sprint → find_story_in_data → _resolve_epic_ref → _get_epic_ref → archive row epic → _write_archive_file empty-epic guard (safe: unresolvable epic → `{success: False}` result, unsafe sprint id → ValueError surfaced as result, refused write leaves file byte-identical — all pinned by in-diff tests)
**Pattern observed:** guard's failure step entry mirrors the sibling add_result failure entry shape at story_finish.py:634-640 — consistent step-entry contract
**Error handling:** post-merge bookkeeping crash → recorded `{"step": "4b", success: False, error}` + steps 4c-7 continue + session removed (story_finish.py:612-626, pinned by 2 parametrized tests)
**Tests:** 10/10 story cases green; 107/107 Dev regression batch; +97/100 extended caller sweep (3 pre-existing test_153_4 failures reproduced on clean develop); inverse-binding probe 2-failed/11-passed; ruff clean
**Findings:** 0 blocking. 6 non-blocking (deferred — see observations 4-9)
**Specialist findings incorporated:** [TEST] error-fidelity assert + fake call-order coupling (2, non-blocking); [TYPE] stale `data` binding + pre-existing None-path silent skip + int/str step-key union (3, non-blocking); [SEC] {exc}→local-stdout-only sink confirmed clean; [RULE] test-file encoding= omissions (LOW, deferred to 155-23); [EDGE], [SILENT], [DOC], [SIMPLE] domains covered directly (subagents disabled) — no findings
**Handoff:** To SM for finish-story