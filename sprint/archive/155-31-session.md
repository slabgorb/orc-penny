---
story_id: "155-31"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-31: finish dry-run: preview 'already merged — will skip' instead of 'Merge PR #N' for a merged PR (from 155-29 review)

## Story Details
- **ID:** 155-31
- **Jira Key:** N/A (local sprint only)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/155-31-finish-dry-run-merged-preview
- **PR:** #164 - dry-run already-merged preview

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-01T09:59:12Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-01T09:42:26Z | 2026-08-01T09:43:54Z | 1m 28s |
| red | 2026-08-01T09:43:54Z | 2026-08-01T09:51:28Z | 7m 34s |
| green | 2026-08-01T09:51:28Z | 2026-08-01T09:54:40Z | 3m 12s |
| review | 2026-08-01T09:54:40Z | 2026-08-01T09:59:12Z | 4m 32s |
| finish | 2026-08-01T09:59:12Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): the HUMAN-mode dry-run preview for an already-merged PR still says "PR #N — waiting for human review and merge" — also stale, but it mirrors the real run's probe-free human arm (155-32 placement rationale), so this story pins it unchanged.
  Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (potential follow-up: probe-and-preview for human mode too, if the API round trip is judged acceptable).
  *Found by TEA during test design.*
- **Gap** (non-blocking): dry-run step 6 previews `Delete local branch: None` when the session has no `**Branch:**` line — pre-existing cosmetic untruth in the same preview block, out of this story's scope.
  Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (guard the step-6 preview on `branch`).
  *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): `_run` (story_finish.py:175) passes no `timeout=` to `subprocess.run`, so a wedged `gh` process hangs finish AND now the dry-run preview indefinitely — pre-existing class across all finish gh calls, surfaced by the dry-run gaining its first network call.
  Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (add a bounded timeout to `_run`, degrade like rc!=0).
  *Found by Reviewer during code review.*
- **Question** (non-blocking): the dry-run preview is a point-in-time snapshot (TOCTOU) — a PR merged between `--dry-run` and the real finish will preview "Merge PR #N" then short-circuit at run time. Inherent to preview semantics; the 155-29 short-circuit makes the divergence harmless. No action proposed, recorded for completeness.
  Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (nothing — informational).
  *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **AC record lives in the test-file docstring**
  - Spec source: context-story-155-31.md, Acceptance Criteria section
  - Spec text: "No acceptance criteria recorded in the sprint YAML — TEA to define during the RED phase."
  - Implementation: AC-1..AC-5 defined and numbered in the docstring of `test_155_31_finish_dry_run_merged_preview.py`; that docstring is the authoritative AC record (155-10/155-13 precedent).
  - Rationale: the context file delegates AC authorship to TEA; recording them beside the tests keeps spec and enforcement in one place.
  - Severity: minor
  - Forward impact: Dev and Reviewer read ACs from the test-file docstring, not the context file.
- **Preview wording pinned by keyword only**
  - Spec source: story title (session file)
  - Spec text: "preview 'already merged — will skip' instead of 'Merge PR #N'"
  - Implementation: tests assert case-insensitive "already merged" + "skip" keywords and the ABSENCE of "Merge PR #"; exact phrasing is left to Dev.
  - Rationale: established message-wording convention (155-12 and siblings) — pin the actionable keywords, not the prose.
  - Severity: minor
  - Forward impact: Dev may phrase the preview freely as long as both keywords appear and the merge promise is gone.
- **Probe placement pinned to the auto-mode arm (human/no-PR arms probe-free)**
  - Spec source: 155-32 in-code rationale (story_finish.py pre-merge probe comment) + SM assessment ("build on the consolidated probe")
  - Spec text: "It stays inside the auto-mode branch on purpose. Human merge mode never auto-merges, so it needs neither answer; hoisting the fetch … would add an API round trip to every human-mode finish"
  - Implementation: green guards assert ZERO `gh pr view` calls for human-mode and no-PR dry-runs; exactly ONE for the auto-mode merged preview.
  - Rationale: the dry-run preview should mirror the real run's probe placement — same design, same cost profile. TEA design choice; Reviewer may override.
  - Severity: minor
  - Forward impact: a fix that hoists the probe above the mode branch will fail the human-mode guard by design.
- **Six green-on-arrival guards are intentional**
  - Spec source: AC-3/AC-4/AC-5 (test-file docstring)
  - Spec text: "an OPEN PR still previews Merge PR #N … probe error falls back … dry-run stays a dry-run … human mode and no-PR path make NO gh pr view call"
  - Implementation: `TestDryRunPreviewUnchangedPaths` (4 tests) + `TestDryRunStaysSideEffectFree` (2 tests) pass on HEAD and must stay green post-fix.
  - Rationale: over-reach protection — the merged preview must not leak into open-PR/probe-error/human/no-PR arms, and the probe must not drag real Step-2 side effects into the dry-run.
  - Severity: minor
  - Forward impact: gate/Reviewer must not read the 6 passing tests as spurious; they are the fix's boundary.
- **Single-probe count pinned to exactly 1**
  - Spec source: SM assessment (session) + 155-32 shipped consolidation
  - Spec text: "must build on the consolidated PR-view probe from 155-32 … rather than adding a second probe"
  - Implementation: `test_dry_run_uses_single_consolidated_view_probe` asserts `gh pr view` invocations == 1 (not >= 1) in the merged dry-run.
  - Rationale: 0 probes = today's guessing bug; 2+ readmits the duplicated-probe class 155-32 removed. Equality is the only assert that enforces both edges.
  - Severity: minor
  - Forward impact: an implementation calling `_pr_view` twice (or adding a separate probe helper) fails by design.

### Dev (implementation)
- No deviations from spec. The implementation is TEA's designed interface verbatim: `_view_is_merged(_pr_view(pr_number))` gating the auto-mode Step-2 preview arm, one consolidated probe, human/no-PR arms untouched.

### Reviewer (audit)
All six logged deviations audited — every entry stamped:
- **AC record lives in the test-file docstring** → ✓ ACCEPTED by Reviewer: established 155-10/155-13 precedent; the docstring is a complete, numbered AC record with a designed interface.
- **Preview wording pinned by keyword only** → ✓ ACCEPTED by Reviewer: keyword pins ("already merged" + "skip", "Merge PR #" absent) capture the truthfulness contract; prose freedom is correct.
- **Probe placement pinned to the auto-mode arm** → ✓ ACCEPTED by Reviewer: verified `get_pr_merge_mode` returns only auto|human (pr_config.py:55-59 normalizes invalid → auto), so the elif arm IS auto mode — the pin mirrors the real run's 155-32 placement exactly. No override needed.
- **Six green-on-arrival guards are intentional** → ✓ ACCEPTED by Reviewer: each guard binds a real over-reach edge (open-PR, probe-error, human, no-PR, side-effects, plan shape); none is vacuous — all assert concrete values.
- **Single-probe count pinned to exactly 1** → ✓ ACCEPTED by Reviewer: equality is the only assert enforcing both the 0-probe (guessing) and 2-probe (dedup regression) edges.
- **Dev: No deviations from spec** → ✓ ACCEPTED by Reviewer: diff inspected — implementation is the designed interface verbatim (story_finish.py:399-417), 19 insertions confined to the dry-run auto arm.
No undocumented deviations found: the diff contains nothing beyond the designed interface plus its rationale comment.

## Sm Assessment

Agents record observations and findings during their phase work.

### Related Stories & Commits
- **155-29** (merged as pennyfarthing#160, commit 268acc8fa): Added short-circuit to finish Step 2 when PR is already merged
- **155-32** (merged as pennyfarthing#162): Consolidated back-to-back `gh pr view` probes into one shared call

### Story Scope
From the title and epic context:
- The finish **dry-run preview** currently says "Merge PR #N" for already-merged PRs
- Should instead preview "already merged — will skip" to accurately reflect what finish will do
- The logic built on the short-circuit added in 155-29 but was not yet reflected in the preview output
- Must build on the consolidated PR-view probe from 155-32 (completed) rather than adding a second probe

### Technical Hooks
Finish logic lives in `pennyfarthing-dist/src/pf/sprint/finish` area (story_finish.py and related modules). The preview is generated during the dry-run phase before actual merge/archive steps.
## TEA Assessment

**Tests Required:** Yes
**Reason:** Behavioral bug — the dry-run preview contradicts the real run's 155-29 short-circuit.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_31_finish_dry_run_merged_preview.py` (new) — dry-run Step-2 preview parity with the real run's already-merged short-circuit; committed as cab036f6a on `feat/155-31-finish-dry-run-merged-preview`.

**Tests Written:** 9 tests covering 5 ACs (AC record = test-file docstring)
**Status:** RED (3 failing on assertions, 6 intentional green guards — ready for Dev)

- RED (3): `test_merged_pr_preview_says_already_merged_will_skip` (AC-1 positive), `test_merged_pr_preview_drops_merge_promise` (AC-1 negative), `test_dry_run_uses_single_consolidated_view_probe` (AC-2). All fail with AssertionError showing the buggy string `'Merge PR #999 (squash, delete branch)'` / 0 probes. Verified by direct scoped run AND testing-runner (155-31-tea-red): 3 failed / 6 passed / 0 errored.
- Green guards (6, intentional — see Design Deviations): open-PR merge preview kept, probe-error falls back to merge preview, human-mode unchanged + probe-free, no-PR unchanged + probe-free, no side effects (no `gh pr merge`/archive/transition/cleanup), full step plan intact with exactly one step-2 entry.
- Green-sim: designed interface applied to a scratch working copy → 9/9 pass; source restored (`git checkout --`, 0 dirty lines). The pinned contract is satisfiable exactly as designed.
- Sibling sweep: 78 finish-family tests (155-1/6/12/15/16/29/32) pass untouched — no pre-adjustments needed.
- Lint: `ruff check` clean on the new test file.

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 no silent swallow/fallback | `test_probe_error_falls_back_to_merge_preview` (probe error must never read as "merged") | green guard |
| #6 test quality (no vacuous asserts) | separate positive + negative wording tests; probe-count equality; independent asserts per invariant | self-checked |

**Rules checked:** 2 of 2 applicable lang-review rules have test coverage (test-only change — remaining rules target implementation code Dev will write)
**Self-check:** 0 vacuous tests found — every test asserts concrete values (`== 1`, `is True`, exact substrings, regex on captured action strings)

**Designed interface for Dev (from the test-file docstring):** in the `if dry_run:` Step-2 auto arm, `if _view_is_merged(_pr_view(pr_number)):` → append `{"step": 2, "action": f"PR #{pr_number} already merged — will skip merge"}`, else keep the existing merge preview. `_pr_is_merged(pr_number)` equally acceptable (same single consolidated probe).

**Handoff:** To Dev (The White Rabbit) for implementation
## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — dry-run Step-2 auto-mode preview now consults the 155-32 consolidated probe (`_view_is_merged(_pr_view(pr_number))`): a MERGED PR previews `PR #N already merged — will skip merge`; an OPEN or unreadable state keeps the `Merge PR #N (squash, delete branch)` preview. 19 insertions, 1 deletion — no other paths touched.

**Tests:** 9/9 story tests passing (GREEN); epic-155 family sweep 238/238 passing; testing-runner formal verification (155-31-dev-green): 49 passed / 0 failed / 0 errored (story file + 155-1/155-29/155-32 sibling regression). `ruff check` clean on the changed file.
**Branch:** feat/155-31-finish-dry-run-merged-preview (pushed, commits cab036f6a test + cee6d6712 impl)

**AC verification (AC record = test-file docstring):** AC-1 merged preview wording + no merge promise ✓; AC-2 exactly one consolidated `gh pr view` probe ✓; AC-3 open-PR / probe-error previews unchanged ✓; AC-4 dry-run side-effect free, full step plan intact ✓; AC-5 human-mode and no-PR arms probe-free ✓.

**Handoff:** To Reviewer (The Queen of Hearts) for code review
## Subagent Results

| # | Subagent | Received | Status | Findings | Decisions |
|---|----------|----------|--------|----------|-----------|
| 1 | reviewer-preflight | Yes | clean | none | tests 9+238 green, lint clean, tree clean, 0 smells |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | clean | none | confirmed clean with line evidence (see [SEC] notes) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (2 enabled subagents returned; 7 disabled via `workflow.reviewer_subagents` settings — their domains assessed by Reviewer directly, see Rule Compliance and observations)

## Reviewer Assessment

**Verdict:** APPROVED

**Dispatch tags:** [SEC] confirmed clean (enabled); [EDGE] [SILENT] [TEST] [DOC] [TYPE] [SIMPLE] [RULE] subagents disabled via settings — domains covered by Reviewer's own pass below.

**Data flow traced:** session `**PR:** #999 …` → `_extract_pr_number` `re.search(r"#(\d+)")` (digits only, story_finish.py:162-166) → `_pr_view(pr_number)` → `_run(["gh","pr","view",pr_number,"--json",…])` list-argv, no shell (story_finish.py:175-177) → JSON parse with rc!=0/decode-error/isinstance-dict guards → None|dict (story_finish.py:186-211) → `_view_is_merged` None→False (story_finish.py:214-223) → bool → preview f-string interpolating only the digit-only pr_number → `click.echo` verbatim (cli.py:483-487). Safe because: no shell, no sensitive interpolation, unknown state degrades to the merge preview (never fabricates "merged").

**Observations:**
1. [VERIFIED] Auto-arm equivalence — evidence: pr_config.py:41-59 `get_pr_merge_mode` validates against VALID_PR_MERGE_MODES and falls back to "auto", so the dry-run `elif pr_number:` arm executes exactly when the real Step 2 auto branch would; the parity the story demands is structural, not coincidental. Complies with rule #11 (input normalized at boundary).
2. [VERIFIED] Consolidated probe reuse — evidence: story_finish.py:407 calls `_view_is_merged(_pr_view(pr_number))`, the 155-32 pair; no new probe helper, no second view call (pinned ==1 by test). Complies with SOUL #2 one-truth.
3. [VERIFIED] Permissive unknown-state degrade — evidence: story_finish.py:186-211 returns None on rc!=0/bad JSON/non-dict; 214-223 maps None→False → merge preview, mirroring the real run's fall-through comment (story_finish.py:489-495). Complies with rule #1 — no silent fallback fabricating state; degrade direction is the safe one (previewing a merge that will short-circuit is harmless; previewing a skip that will merge would not be).
4. [VERIFIED] Dry-run purity preserved — evidence: the new arm appends preview dicts only; the block still returns at story_finish.py:431 before any mutation; `TestDryRunStaysSideEffectFree` asserts no merge/archive/transition/cleanup empirically.
5. [SEC] Security subagent confirmed clean — argv-only subprocess (all 6 `_run` call sites), digit-only interpolation in the preview string, no exc/path leak (160-18/160-22 precedent honored), fully-mocked `_run` in every test (no network escape).
6. [VERIFIED] Wiring — evidence: cli.py:483-487 renders `step['step']`/`step['action']` generically; both keys present in the new dicts; no consumer parses the "Merge PR #" wording (repo-wide grep: only story_finish.py:417 and tests).
7. [LOW] The auto-mode dry-run with a PR now costs one gh API round trip where it previously cost zero — this is AC-2's explicit design (truthfulness over latency, SOUL #13); noted so nobody reads the new latency as a regression.
8. [TEST] Test quality (test-analyzer domain, assessed directly): patch targets correct — `pf.sprint.story_finish._run` (where used); `pf.common.pr_config.get_pr_merge_mode` patched at source module, which is the ONLY correct target for the late `from … import` inside the dry-run block; assertions are concrete (==1, exact substrings, is True); positive and negative wording pins are independent tests (mutation-resistant per 155-30 lesson).

**Rule Compliance** (lang-review python.md, 13 checks vs the diff):
| # | Check | Result |
|---|-------|--------|
| 1 | silent exceptions | compliant — no new try/except; unknown-state degrade is explicit, commented, and test-pinned |
| 2 | mutable defaults | compliant — no new signatures with mutable defaults (test factories use str/keyword-only defaults) |
| 3 | type annotations | compliant — no new public functions; test helpers annotated |
| 4 | logging | N/A — report strings are the product; no error path added |
| 5 | path handling | N/A — no file I/O in the diff |
| 6 | test quality | compliant — no vacuous asserts, no skips, patch-where-used honored (see obs 8) |
| 7 | resource leaks | N/A — no resources opened |
| 8 | unsafe deserialization | compliant — json parsing behind pre-existing guards; no shell=True; no yaml/pickle/eval |
| 9 | async pitfalls | N/A — no async code |
| 10 | import hygiene | compliant — zero new imports (helpers are same-module) |
| 11 | input validation | compliant — pr_number digit-constrained; gh JSON isinstance-guarded; mode normalized |
| 12 | dependency hygiene | N/A — no dependency changes |
| 13 | fix-introduced regressions | compliant — 238 epic-155 family tests green; re-scan of the fix diff found nothing new |

**Tenant isolation audit:** N/A — no tenant-scoped data, trait methods, or multi-tenant structures exist in this code path; the change touches a local CLI report string.

**Error handling:** probe failure → None → False → merge preview (story_finish.py:186-223, 407); merge-mode misconfiguration → normalized to auto (pr_config.py:55-59); malformed session PR line → pr_number None → "No PR to merge" arm. Every failure mode lands on a defined preview, none raises through `finish_story`.

**Pattern observed:** good — preview/reality parity enforced by reusing the real run's own predicate helpers rather than duplicating logic (story_finish.py:407 vs 482); the comment block (399-406) documents WHY the probe placement mirrors 155-32, which is exactly the prove-the-work standard (SOUL #14).

### Devil's Advocate

Let me argue this code is broken. First: the dry-run just became a network operation. An operator on a plane runs `pf sprint story finish 155-31 --dry-run` expecting a pure local preview and instead waits on a gh call with NO timeout — `_run` passes none — so a wedged gh hangs the "harmless" preview forever. Is that a blocker? No: the dry-run was never network-pure (the `gh pr list` PR-resolution fallback predates this story), the real finish has the identical exposure, and gh itself has HTTP timeouts; but I refuse to let it pass unrecorded — it is now a Delivery Finding (Improvement, non-blocking) because the dry-run path made the exposure more likely to be noticed. Second: TOCTOU — the preview probes NOW, the operator acts LATER; a PR merged in between makes the preview a lie in the opposite direction ("Merge PR #N" then run-time skip). But the 155-29 short-circuit makes the stale preview harmless, and a preview that re-probed at run time is… the run itself. Recorded as a Question, no action. Third: could a confused user read "already merged — will skip merge" as "the story is already finished, no need to run finish"? Plausible misreading — but the surrounding steps 1/3-7 still preview the archive/Jira/YAML work remaining, which contradicts that reading; wording freedom stays with Dev. Fourth: the human-mode preview still says "waiting for human review and merge" for a merged PR — a residual lie this story deliberately excluded (TEA logged it; I checked the real human arm makes no probe either — parity holds, follow-up filed as a TEA finding). Fifth: mocked worlds — every test fakes `_run`; could the real gh JSON shape differ? `_PR_VIEW_FIELDS` and `_view_is_merged` are exercised against real gh by the 155-29/155-32 lineage in production use; the fakes mirror recorded gh payloads including the GraphQL already-merged stderr. I find no Critical or High. The head, this once, stays attached.

**Handoff:** To SM (The Mad Hatter) for finish-story