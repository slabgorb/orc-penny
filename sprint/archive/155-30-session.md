---
story_id: "155-30"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 155-30: Test polish: pin jira_key/steps key presence in 155-16 failure-result tests (from 155-16 review)

## Story Details
- **ID:** 155-30
- **Jira Key:** (skipped — no key)
- **Workflow:** tdd
- **Repos:** pennyfarthing
- **Branch:** feat/155-30-finish-test-key-pins (off develop)
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-31T17:19:40Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-31T16:59:42Z | 2026-07-31T17:01:10Z | 1m 28s |
| red | 2026-07-31T17:01:10Z | 2026-07-31T17:11:04Z | 9m 54s |
| green | 2026-07-31T17:11:04Z | 2026-07-31T17:14:08Z | 3m 4s |
| review | 2026-07-31T17:14:08Z | 2026-07-31T17:19:40Z | 5m 32s |
| finish | 2026-07-31T17:19:40Z | - | - |

## Sm Assessment

**Scope:** 1-point p1 test-polish story, tdd workflow. Pure test-hardening — no production code changes expected. Two sources, both review follow-ups against the `finish_story` failure-result/step-record tests:

1. **From 155-16 review (story title):** the 155-16 failure-result tests assert key presence in OR-form (e.g. `'jira_key' in r or 'steps' in r`), which lets a delete-key mutation survive. Pin `jira_key` and `steps` key presence with independent assertions.
2. **From 155-29 review (folded-in AC):** in `test_155_29`, pin the `already_merged` step-record key with its own assertion (same OR-form weakness), and add a combo test covering branch-resolved-PR × already-merged.

**Technical approach for TEA:** locate the 155-16 and 155-29 test files/cases in `pennyfarthing/tests/` (search for `155_16` / `155_29` / `already_merged` / `finish`). RED phase here means demonstrating the assertion gap (mutation-style: a deleted key currently survives the OR-form assertions), then strengthening assertions so each required key is pinned independently, plus the new combo test. Since this is test-only work, the "failing test" framing is the strengthened/new assertions against current behavior — they should PASS against correct production behavior; the deliverable is tighter pins, not a production fix. If TEA finds the pinned assertions actually FAIL against current production code, that's a Delivery Finding (blocking) — stop and report, don't fix production in this story.

**Acceptance criteria:**
- [ ] 155-16 failure-result tests assert `jira_key` and `steps` presence independently (no OR-form)
- [ ] `test_155_29` pins `already_merged` step-record key with its own assertion
- [ ] New combo test: branch-resolved-PR × already-merged path
- [ ] Full story-scoped test suite green

**Routing:** tdd → TEA (red) → Dev (green) → Reviewer → SM finish. Jira: skipped (no key).

## TEA Assessment

**Tests Required:** Yes
**Reason:** Test-polish story — the tests ARE the deliverable (assertion hardening per 155-16/155-29 review findings).

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_16_finish_status_read_guard.py` — pinned `jira_key` (present, `is None` in the no-Jira world) and `steps` (present, carrying the pre-abort `merge_pr` history) outright in the status-read-guard failure dict; docstring updated
- `pennyfarthing-dist/src/pf/tests/test_155_29_finish_short_circuit_merged_pr.py` — split the `merged or already_merged` OR-form into two independent `is True` assertions in `test_short_circuit_step_record_is_truthful`; added `test_branch_resolved_pr_already_merged_short_circuits` (session with no `**PR:**` line → PR resolved via `gh pr list --head` → already-MERGED → short-circuit, truthful step-2 record naming the resolved PR); extended `_make_already_merged_run` with `list_stdout` and `_make_project` with `session_body` (defaults preserve all existing tests)

**Tests Written:** 1 new test + 8 strengthened assertions covering both ACs
**Status:** GREEN-on-arrival (intentional — see Design Deviations). Story-scoped: 14/14 pass. Commit `8fc8181ad` on `feat/155-30-finish-test-key-pins`.

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #6 test quality (delete-key-surviving OR-form/defaulted-get) | pinned keys in `test_status_read_failure_returns_loud_result`, independent `merged`/`already_merged` asserts | passing (mutation-resistant by construction) |
| #1 no silent swallow (probe-error fall-through) | pre-existing `test_precheck_probe_error_falls_through_to_merge` unchanged, still green | passing |

**Rules checked:** 2 of 2 applicable lang-review rules (test-only diff — remaining rules target production code, none changed)
**Self-check:** 0 vacuous assertions; every new assert checks a concrete value (`is True`, `is None`, exact `pr == "999"`)

**Full-suite note:** 5353 passed / 30 failed — all 30 in pre-existing unrelated modules (see Delivery Findings); cache at `.session/test-runs/155-30-tea-red.md`.

**Handoff:** To Dev (B.A.) for GREEN — verification-only: confirm story-scoped green, no production change expected.

## Dev Assessment

**Implementation Complete:** Yes (verification-only — no production changes, as designed)
**Files Changed:**
- None beyond TEA's test commit `8fc8181ad` — the story is test polish; production (`story_finish.py`) already implements every pinned behavior.

**Verification performed:**
- Story-scoped: `test_155_16_finish_status_read_guard.py` + `test_155_29_finish_short_circuit_merged_pr.py` — 14/14 GREEN
- Finish-family regression batch (`-k finish`): 158 passed / 5 failed — all 5 in `test_143_9_tdd_cycle_e2e.py` and `test_153_4_story_mutation_on_sharded_yaml.py`, **proven pre-existing** by re-running on clean `develop` without the 155-30 commit (fails identically; evidence in Dev findings below)
- `ruff check` on both test files: all checks passed
- Test-run cache: `.session/test-runs/155-30-dev-green.md`

**Tests:** 14/14 story-scoped passing (GREEN)
**Branch:** feat/155-30-finish-test-key-pins (pushed)

**Handoff:** To Reviewer (Colonel Lynch) for review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 14/14 tests pass, ruff clean |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | clean | none | N/A — 4/4 delete-key mutants killed by new pins; combo test traced end-to-end, not vacuous |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | clean | none | N/A — all pinned keys trace to real story_finish.py contract lines; immutable defaults |
| 7 | reviewer-security | Yes | clean | none | N/A — no new attack surface; fakes never invoke real gh/git |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | clean | none | N/A — 13/13 python.md rules pass or N/A; SOUL #10/#13/#14 pass |

**All received:** Yes (5 enabled returned, 4 disabled via settings)
**Total findings:** 0 confirmed, 0 dismissed, 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

**Scope reviewed:** test-only diff, 2 files, +123/−9 (commit `8fc8181ad`) — no production code changed.

**Data flow traced:** session markdown (`SESSION_BRANCH_ONLY`, no `**PR:**` line) → `_parse_session`/`_extract_pr_number` returns None → `gh pr list --head` fallback (story_finish.py:327-332) → fake stdout `"999\n"` → `.strip()` → `pr_number="999"` → `_pr_block_reason` (UNKNOWN → no block) → `_pr_is_merged` (MERGED) → short-circuit step record `{merged: True, already_merged: True, pr: "999"}` → asserted key-by-key. Safe because every hop is pinned against the real production parse, and a broken fallback fails the test rather than passing silently (a skipped entry carries no `pr` key, so `entry.get("pr") == "999"` catches it — verified by test-analyzer).

**Pattern observed:** good — mutation-resistant independent key pins replacing OR-form/defaulted-get probes, at test_155_16_finish_status_read_guard.py:293-306 and test_155_29_finish_short_circuit_merged_pr.py:441-447; fixture extension via keyword-only immutable defaults (`session_body`, `list_stdout`) preserves all existing call sites.

**Error handling:** the strengthened test keeps the no-throw wrapper (`pytest.fail` on any raise, test_155_16:264-271), so the SOUL #10 result-dict contract stays pinned; new asserts only tighten the failure-dict shape.

**Observations (≥5):**
- [VERIFIED] AC-1: `jira_key`/`steps` pinned outright in the status-read-guard failure test — test_155_16:293-303 asserts `"jira_key" in result`, `result["jira_key"] is None`, `"steps" in result`; matches production dict at story_finish.py:574-583. Complies with lang-review #6 (concrete values, no truthy-only checks). [TEST][RULE]
- [VERIFIED] AC-2: OR-form split into independent `merged is True` / `already_merged is True` asserts — test_155_29:441-447; mutation runs prove each kills its delete-key mutant where the OR-form survived. [TEST]
- [VERIFIED] AC-3: combo test binds the branch-resolution fallback to the short-circuit — fake `gh pr list` stdout matches production `--jq ".[0].number"` + `.strip()` parsing exactly (story_finish.py:328-332). [TYPE][RULE]
- [VERIFIED] No new attack surface: all subprocess interaction routed through mocked `_run`; static fixtures only; no yaml.load/pickle/eval/shell=True; tmp_path-scoped writes. Complies with lang-review #5/#8/#11. [SEC]
- [VERIFIED] `"merge_pr" in _step_actions(result)` content pin proves `steps` carries the live pre-abort history, not a defaulted `[]` — test_155_16:304-306. [TEST]
- [LOW] `SESSION_BRANCH_ONLY` duplicates `SESSION_WITH_PR` minus one line — acceptable explicit-fixture duplication; a `.replace()` derivation would couple the two. Not blocking. [SIMPLE — self-assessed; subagent disabled]
- [LOW] Combo test omits its sibling's `not entry.get("skipped")` assert — functionally covered (a skipped entry would fail the `pr`/`merged` pins). Not blocking. [EDGE — self-assessed; subagent disabled]

**Tag coverage note:** [EDGE], [SILENT], [DOC], [SIMPLE] subagents disabled via settings — those domains self-assessed above and in Devil's Advocate ([SILENT]: no new except blocks in diff; [DOC]: both module docstrings updated to describe the 155-30 polish accurately — verified against the actual edits).

**Hard questions:** multi-PR branches (`gh pr list` returns several) — production takes `.[0]` via jq; single-PR fake is representative. Huge/empty stdout — `.strip()` on empty falls through to no-PR path, covered by sibling tests. Race between view and merge — out of scope for a test-polish diff, production behavior unchanged.

**Tenant isolation audit:** N/A — single-user CLI, no tenant model; no trait/data-handler methods in diff.

**Challenged VERIFIEDs:** no subagent contradicts any VERIFIED (all five clean); no project rule conflicts (rule-checker exhaustive pass).

### Rule Compliance

| Rule (python.md) | Instances in diff | Judgment |
|------------------|-------------------|----------|
| #1 silent exceptions | 0 new except blocks | N/A — compliant |
| #2 mutable defaults | `session_body: str`, `list_stdout: str` | compliant (immutable str) |
| #3 type annotations | new test method + changed helpers | compliant (annotated; nested closures exempt) |
| #6 test quality | every new/changed assertion | compliant — concrete value pins, mutation-verified |
| #5/#8/#11 paths/deser/input | 0 instances | N/A — no such code in diff |
| #4/#7/#9/#10/#12 | 0 instances | N/A |
| #13 meta-check | full diff re-scan | compliant (rule-checker) |
| SOUL #10 result dicts | no-throw wrapper preserved | compliant |
| SOUL #14 prove the work | mutation evidence + traced fakes | compliant |

### Devil's Advocate

Assume this diff is broken. Where would it lie to us? First suspect: the pins could be pinning the wrong contract — a test that asserts `jira_key is None` would be actively harmful if production legitimately returned `""` in some worlds, turning a cosmetic normalization into a red suite. I checked: `_extract_jira_key` returns `str | None` and the no-key path is `None` end-to-end (story_finish.py:152-159, 315-324); the shard in this harness has no `jira` field, so `None` is the one true value. If a future story normalizes that to `""`, this test failing is the desired loud signal on a report-contract change, not noise. Second suspect: the combo test could pass vacuously if branch resolution silently failed and the assertions happened to match a degenerate entry. Test-analyzer proved the opposite — a `None` pr_number produces a `skipped` entry whose missing `pr` key fails the `== "999"` assert. Third suspect: the mutation claims could be theater — asserted but never run. They were run: four mutants, four kills, self-restored tree verified clean afterward. Fourth suspect: the fake world could drift from gh reality — `mergeable: UNKNOWN` on merged PRs is documented gh behavior (GitHub stops computing mergeability post-merge), and the realistic rc=1 "already merged" stderr matches the actual GraphQL error string. Fifth suspect: green-on-arrival tests reviewed by the same pipeline that wrote them — the structural risk of a test-polish story. Mitigated here by independent mutation verification and by every pin tracing to a production line number. Nothing found that changes the verdict; the two LOW observations above came out of this exercise.

**Handoff:** To SM (Faceman) for finish-story.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): 30 pre-existing full-suite failures in unrelated modules (test_143_10_reviewer_dev_roundtrip, test_143_9_tdd_cycle_e2e, test_153_4_story_mutation_on_sharded_yaml, test_independence, test_init_justfile, test_peloton_portrait_panes) — framework-wide issues predating 155-30; story-scoped files are 14/14 green.
  Affects `pennyfarthing-dist/src/pf/tests/` (separate stories needed to repair those modules).
  *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): confirmed the 5 finish-family regression failures (3× test_143_9_tdd_cycle_e2e, 2× test_153_4_story_mutation_on_sharded_yaml "Jira sync failed") reproduce on clean `develop` without the 155-30 commit — pre-existing baseline, same set TEA flagged; candidate for a dedicated repair story if none exists.
  Affects `pennyfarthing-dist/src/pf/tests/test_143_9_tdd_cycle_e2e.py` and `test_153_4_story_mutation_on_sharded_yaml.py` (module repair out of 155-30 scope).
  *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): the pre-existing failure baseline (TEA's 30 / Dev's finish-family 5) spans at least 6 modules with no tracked owner story — worth a single triage story that either repairs or quarantines them so future story-scoped green claims don't need per-story re-proof.
  Affects `pennyfarthing-dist/src/pf/tests/` (baseline triage story in the backlog).
  *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

1 deviation

- **No genuine RED state — all tests green-on-arrival by design**
  - Rationale: 155-30 is a test-polish story pinning already-shipped 155-16/155-29 behavior; a failing state would require mutating production, which TEA cannot and should not do
  - Severity: minor
  - Forward impact: Dev green phase is verification-only (no production change expected); Reviewer should judge pins by mutation reasoning, not RED evidence

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **No genuine RED state — all tests green-on-arrival by design**
  - Spec source: session Sm Assessment (155-30 scope); tdd workflow red phase
  - Spec text: "RED phase: write failing tests" (tdd workflow) vs. "the deliverable is tighter pins, not a production fix... they should PASS against correct production behavior" (Sm Assessment)
  - Implementation: strengthened assertions + new combo test all PASS on HEAD; mutation resistance is the deliverable (delete-key mutants on `jira_key`/`steps`/`merged`/`already_merged` now fail where the old OR-form/defaulted-get probes survived)
  - Rationale: 155-30 is a test-polish story pinning already-shipped 155-16/155-29 behavior; a failing state would require mutating production, which TEA cannot and should not do
  - Severity: minor
  - Forward impact: Dev green phase is verification-only (no production change expected); Reviewer should judge pins by mutation reasoning, not RED evidence

### Dev (implementation)
- No deviations from spec. Verification-only green phase: no production code written (none required — TEA's pins are green-on-arrival against shipped 155-16/155-29 behavior, per the TEA deviation above); no test modifications.

### Reviewer (audit)
- **TEA "No genuine RED state — all tests green-on-arrival by design"** → ✓ ACCEPTED by Reviewer: correct for a test-polish story; the RED-equivalent evidence exists — test-analyzer's four delete-key mutation runs each fail the new pins, which is exactly what a RED state would have demonstrated. The deviation's forward-impact note ("judge by mutation reasoning, not RED evidence") was followed and the reasoning held.
- **Dev "No deviations from spec (verification-only green)"** → ✓ ACCEPTED by Reviewer: proper restraint — no code exists that no test demanded; the develop-branch re-run proving the 5 regression failures pre-exist is exactly the right evidence standard (SOUL #14).
- No undocumented deviations found: the diff does nothing beyond the three ACs plus the two docstring updates describing them.