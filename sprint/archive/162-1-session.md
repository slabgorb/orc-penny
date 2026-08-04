---
story_id: "162-1"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-1: finish evaluates the conflict gate before the already-merged short-circuit, so a MERGED PR with stale DIRTY mergeability aborts with un-actionable rebase advice (from 155-32 review)

## Story Details
- **ID:** 162-1
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-1-finish-conflict-gate-order
- **PR:** #168

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-04T18:34:42Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-04T18:15:22Z | 2026-08-04T18:17:10Z | 1m 48s |
| red | 2026-08-04T18:17:10Z | 2026-08-04T18:22:33Z | 5m 23s |
| green | 2026-08-04T18:22:33Z | 2026-08-04T18:26:32Z | 3m 59s |
| review | 2026-08-04T18:26:32Z | 2026-08-04T18:34:42Z | 8m 10s |
| finish | 2026-08-04T18:34:42Z | - | - |

## Story Context

**Bug:** The finish flow in `pennyfarthing/pennyfarthing-dist/src/pf/sprint/finish.py` evaluates the conflict/mergeability gate BEFORE the already-merged short-circuit (shipped in story 155-29). When a PR is already MERGED but has stale DIRTY mergeability data cached from `gh pr view`, the finish command aborts with un-actionable "rebase your branch" advice instead of recognizing the PR is already done.

**Origin:** Finding from 155-32 code review.

**Fix:** Reorder gate evaluation so the already-merged short-circuit is checked FIRST, or skip the conflict gate when PR state is already MERGED.

**Points:** 1 (p1)

## Sm Assessment

**Scope:** 1-pt p1 TDD story. Reorder gate evaluation in the finish flow so the already-merged short-circuit (155-29) is checked before the conflict/mergeability gate. A MERGED PR must never abort finish on stale DIRTY mergeability data.

**Technical approach for TEA:** Locate the finish flow's merge step (`pennyfarthing/pennyfarthing-dist/src/pf/sprint/` — likely `finish.py` or `merge_pr` helper). Write a failing test: PR view returns state=MERGED with mergeable=DIRTY (stale cache) → finish must short-circuit as already-merged, NOT abort with rebase advice. Also pin the ordering: conflict gate only evaluated for OPEN PRs.

**Acceptance criteria:**
1. MERGED + stale DIRTY mergeability → finish short-circuits successfully (no abort, no rebase advice).
2. OPEN + DIRTY → conflict gate still aborts with rebase advice (existing behavior preserved).
3. Story-scoped tests green.

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_1_finish_merged_before_conflict_gate.py` — 17 tests (10 RED, 7 green-on-arrival guards)

**Tests Written:** 17 tests covering 3 ACs
**Status:** RED (10 failing — ready for Dev)
**Commit:** `f71152c` on `feat/162-1-finish-conflict-gate-order` (GPG signed, `%G? = G`)

### Root cause (confirmed by reading source)

`pennyfarthing-dist/src/pf/sprint/story_finish.py` line ~600:

```python
pr_view = _pr_view(pr_number)
block_reason = _pr_block_reason(pr_number, pr_view)   # conflict gate — FIRST
if block_reason:
    return {"success": False, "error": block_reason}
...
elif pr_number and _view_is_merged(pr_view):          # 155-29 short-circuit — SECOND
```

`_pr_block_reason` (line 287) reads only `mergeable` / `mergeStateStatus`; it never
consults `state`. GitHub stops recomputing mergeability once a PR merges, so a
`state=MERGED` snapshot can still carry `mergeable=CONFLICTING` /
`mergeStateStatus=DIRTY`. The gate wins and finish returns
`PR #999 is CONFLICTING — rebase on develop and resolve the conflicts before finishing`.

### Designed interface for Dev

Make "did it already land?" the FIRST question asked of the shared snapshot. Tests
bind to `finish_story` behavior, not to a mechanism — either shape passes:

1. Call site: `if not _view_is_merged(pr_view): block_reason = _pr_block_reason(...)`
2. Helper: `_pr_block_reason` returns `None` when `_view_is_merged(view)` is true.

Constraints the guard tests enforce:
- The discriminator must be `state == "MERGED"`, **not** "state != OPEN" — a
  CLOSED-unmerged conflicting PR must still abort.
- An unreadable probe (`pr_view is None`) must still block nothing *and* short-circuit
  nothing — it falls through to the real merge + post-merge verification.
- Only ONE step-2 entry may appear in the result; the merged path must produce the
  155-29/155-30 record (`merged: True`, `already_merged: True`, PR named, not `skipped`).
- The rebase wording must be absent from *every* operator-visible string (top-level
  `error` and each step's `error`/`action`) — relocating the message does not pass.

### RED tests (fail on HEAD at the conflict-gate abort)

`TestMergedPrIgnoresStaleMergeability`:
- `test_merged_pr_with_stale_mergeability_completes[conflicting+dirty|conflicting-only|dirty-only]` — finish succeeds, reaches `done`, session removed
- `test_merged_pr_never_reports_rebase_advice[3 params]` — no rebase/CONFLICTING text anywhere in the report
- `test_merged_pr_with_stale_mergeability_skips_merge_attempt` — no `gh pr merge` (with `merge_rc=0`, so a tolerant gh cannot mask it)
- `test_merged_pr_step2_record_is_truthful` — exactly one step-2 entry, the already-merged record
- `test_dry_run_preview_matches_real_run_on_stale_snapshot` — preview/reality parity (155-31): the plan already says "already merged — will skip merge" on this snapshot while the real run aborts
- `test_branch_resolved_merged_pr_with_stale_mergeability_completes` — same via the `gh pr list --head` fallback entry point

### Green-on-arrival guards (must stay green)

`TestConflictGateStillBlocksUnmergedPrs`:
- `test_open_conflicting_pr_still_aborts_with_rebase_advice[3 params]` — abort names PR + base branch, no merge attempted, session kept, archive dir empty, no `done`
- `test_closed_unmerged_conflicting_pr_still_aborts`
- `test_unreadable_probe_conflicting_pr_falls_through_to_merge`
- `test_human_mode_merged_stale_snapshot_stays_advisory`
- `test_clean_open_pr_still_merges`

### Verification

`test_162_1_*`: 10 failed, 7 passed. Sibling finish suites all green and unaffected:
`test_155_12` (14), `test_155_15` (18), `test_155_29` (5), `test_155_31` (15),
`test_155_32` (18) — 70 passed. `ruff check` + `ruff format` clean on the new file.

### Rule Coverage (python lang-review)

- #1 silent exception swallowing — covered indirectly: `test_unreadable_probe_conflicting_pr_falls_through_to_merge` pins that an unreadable `gh pr view` is never read as "merged" (no silent false-done hole).
- #3 type annotation gaps — all test helpers annotated.
- #6 test quality — no vacuous assertions; every assert pins a specific value with a failure message; the parametrized cases exercise three genuinely distinct field combinations (`_pr_block_reason` blocks on either field independently), not one path three times.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_pr_block_reason` now returns `None` for a `state == MERGED` snapshot (early return before the `mergeable`/`mergeStateStatus` read), plus a docstring paragraph recording why MERGED is the sole exemption.

**Approach:** TEA offered two shapes; took the helper-level one (shape 2). Net +10 lines, 2 of them logic. The gate helper is the thing that owns "should this abort?", so putting the merged check inside it keeps the precedence with the decision rather than in a caller's statement order, and it holds for any future call site. No reordering of the call site, no new helper, no signature change.

**Tests:** 17/17 story tests passing (GREEN — the 10 RED now pass, all 7 guards still green).

Sibling finish suites, all green and unchanged from baseline: `test_155_12` (10), `test_155_15` (14), `test_155_29` (9), `test_155_31` (9), `test_155_32` (21). Combined story + siblings: 80 passed.

Broader `-k "finish or story_finish"` sweep: 222 selected, 217 passed, 5 failed. Those 5 are pre-existing on HEAD — verified by stashing the fix and re-running (baseline: 15 failed = the 10 story RED + these same 5). They live in `test_143_9_tdd_cycle_e2e.py` (2) and `test_153_4_story_mutation_on_sharded_yaml.py` (3), unrelated modules.

**Lint:** `ruff check` clean. `ruff format --check` reports the file would reformat, but every hunk in `ruff format --diff` is a pre-existing line-length drift elsewhere in the file (lines ~803, ~832, ~974, ~1010) — none touch the edited region. Left alone deliberately: reformatting them would bury a 2-line fix in unrelated churn.

**Commit:** `4797926b1` on `feat/162-1-finish-conflict-gate-order`, GPG signed (`%G? = G`), pushed to origin. No PR created (SM owns that in the finish phase).

**Handoff:** To review phase.

## Subagent Results

| # | Subagent | Status | Findings | Confirmed | Notes |
|---|----------|--------|----------|-----------|-------|
| 1 | reviewer-preflight | Complete | 0 | 0 | 17/17 story, 63 sibling, 217 broader finish tests pass. `ruff check` clean; format drift confined to lines 803/832/974/1010, outside the edited 298–323 region. |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Complete | 4 | 4 (all Low) | Parametrization collapses to one path post-fix; `_result_blob` sweep omits `detail`/`message`; no absent-`state` or lowercase-`state` case. |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Complete | 3 | 3 (all deferred) | Order-dependent invariant; `str \| None` conflates three outcomes; dry-run omits the conflict gate. |
| 7 | reviewer-security | Complete | 4 | 2 deferred, 1 downgraded, 1 out-of-diff | `state`-only trust with no `mergedAt` corroboration; short-circuit skips fresh re-verification; `_pr_view` schema trust; pre-existing bare `except` at line 897. |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Complete | 0 | 0 | 13/13 python checks pass, 47 instances. Repo/never-edit topology verified: both files under `pennyfarthing-dist/**` (owned), gitflow onto `develop`. |

**All received: Yes** — all 5 enabled subagents (preflight, test-analyzer, type-design, security, rule-checker) returned results before any conclusion was written. The 4 subagents disabled via `workflow.reviewer_subagents` (edge_hunter, silent_failure_hunter, comment_analyzer, simplifier) are recorded as Skipped and do not block the gate.

### Cross-subagent contradiction (challenged)

**Challenged:** reviewer-rule-checker reported the `STALE_MERGEABILITY` parametrization exercises "independent code paths"; reviewer-test-analyzer reported all three cases now collapse to the same early return. **test-analyzer is correct post-fix** — the new guard returns before either `mergeable` or `mergeStateStatus` is read, so the three cases are path-identical on the merged class. rule-checker described the pre-fix world. Resolution: not a defect. The parametrization was genuinely three-path as a RED test and remains valuable as a fence against a partial revert that exempts only one field. No action.

## Reviewer Assessment

**Verdict:** APPROVED

Two logic lines, verified load-bearing and correctly scoped. No Critical or High findings.

### Independent verification (not taken on the subagents' word)

**Truth table probe** — called `_pr_block_reason` directly across 13 snapshot shapes. The merged exemption fires for and only for `state == MERGED`:

| `state` | `mergeable` | `mergeStateStatus` | Result |
|---------|-------------|--------------------|--------|
| `MERGED` | `CONFLICTING` | `DIRTY` | pass |
| `MERGED` | (absent) | `DIRTY` | pass |
| `MERGED` | `CONFLICTING` | (absent) | pass |
| `merged` (lowercase) | `CONFLICTING` | `DIRTY` | pass |
| `CLOSED` | `CONFLICTING` | `DIRTY` | **BLOCK** |
| `CLOSED` | (absent) | `DIRTY` | **BLOCK** |
| `OPEN` | `CONFLICTING` | `DIRTY` | **BLOCK** |
| `OPEN` | (absent) | `DIRTY` | **BLOCK** |
| `OPEN` | `CONFLICTING` | (absent) | **BLOCK** |
| `` (empty) | `CONFLICTING` | `DIRTY` | **BLOCK** |
| `state` key absent | `CONFLICTING` | `DIRTY` | **BLOCK** |
| `OPEN` | `UNKNOWN` | `UNKNOWN` | pass (falls through, as designed) |
| snapshot `None` | — | — | pass (falls through, as designed) |

This answers the three questions the SM raised directly: the exemption holds ONLY for `MERGED` (CLOSED-unmerged still blocks); it is parametrized against both stale fields independently (all three merged shapes pass, all three unmerged shapes block); and `.upper()` normalization is real.

**Self-restoring revert probe** — wrote the `develop` version of `story_finish.py` over HEAD's, ran the story suite (10 failed / 7 passed), restored from a pre-copied backup, confirmed `git status --porcelain` clean and `git diff --stat` empty. The fix is load-bearing and the tests are not vacuous. Working tree left untouched.

**Data flow traced** — `gh pr view --json state,mergeable,mergeStateStatus,baseRefName` → `_pr_view` (rc check → `json.loads` in `try` → `isinstance(data, dict)` → else `None`) → the single consolidated `pr_view` snapshot → `_pr_block_reason` at line 613 → `_view_is_merged(pr_view)` at line 658. Safe because every degradation is permissive-to-`None` and every field read is `str()`-coerced, so a non-string or absent `state` can never equal `"MERGED"`.

**Paired-exemption invariant (the hole I went looking for and did not find)** — the danger in bypassing a safety gate is a snapshot that gets exempted from the gate but is then NOT caught by the short-circuit, falling through to `gh pr merge` on a conflicting PR with the gate disarmed. That cannot happen: the gate exemption at line 312 and the short-circuit at line 658 evaluate the same predicate `_view_is_merged` against the *same object* `pr_view`, with nothing mutating it in between. The exemption and the short-circuit are exactly co-extensive. This is the correctness argument for the fix, and it holds.

**Wiring** — `_pr_block_reason` has exactly one caller (line 613), inside the `pr_merge_mode == "auto"` branch. `get_pr_merge_mode` is closed over `{auto, human}` with invalid values coerced to the `auto` default, so there is no third mode that skips the gate silently. Human mode never fetches a snapshot and never reaches the gate — correct, since human mode never auto-merges.

**Pattern observed (good)** — `story_finish.py`:299-308. The new docstring paragraph records not just the rule but the *scope boundary* and its reason ("Only `MERGED` is exempt: a CLOSED-without-merging PR did NOT land"). That is the precise failure mode a future reader would otherwise re-introduce by broadening the check to `state != "OPEN"`. Consistent with the file's existing convention of citing story/issue provenance inline.

**Error handling** — the merged path returns the 155-29/155-30 record (`merged: True`, `already_merged: True`) and skips `gh pr merge`, which is the point: gh exits non-zero on an already-merged PR and would wedge every retry at line 700. No operator-visible string on the merged path carries rebase advice — `_REBASE_ADVICE` (`rebase|CONFLICTING|resolve the conflicts`, case-insensitive) is asserted absent across the top-level `error` and every step's `error`/`action`.

### Deviation Audit

- **TEA — stale-shape parametrization (3 shapes vs. the ACs' `DIRTY` only):** ACCEPTED. `_pr_block_reason` blocks on either field independently; a one-field fix would leave the other aborting the retry. My truth table confirms both fields were genuinely independent triggers pre-fix.
- **TEA — extra `CLOSED`-unmerged guard:** ACCEPTED, and this is the most valuable test in the suite. The ACs as written admit a `state != "OPEN"` fix that would mark a story done for code that was thrown away. This guard is what makes the exemption safe.
- **TEA — extra dry-run parity RED test:** ACCEPTED. 155-31's parity contract was genuinely broken by the same root cause.
- **Dev — helper-level shape over call-site reorder:** ACCEPTED. TEA sanctioned either shape; putting the precedence next to the decision rather than in a caller's statement order is the better of the two and holds for any future call site.
- **Dev — pre-existing ruff format drift left untouched:** ACCEPTED. Confirmed by preflight that all four drift hunks (lines 803, 832, 974, 1010) fall outside the edited 298–323 region. Reformatting them would bury a 2-line fix in unrelated churn.
- **UNDOCUMENTED deviations:** none found.

### Deferred findings (non-blocking — for SM to file as follow-ups)

| Severity | Issue | Location |
|----------|-------|----------|
| [MEDIUM] | **[SEC]** `state == MERGED` is the sole authority for skipping the gate, the merge, AND the post-merge re-verification, with no corroborating field. `_PR_VIEW_FIELDS` does not request `mergedAt`. Requiring `mergedAt` non-null alongside `state` would make the bypass need two independent GitHub fields to agree. Note this also *removes an accidental safety net*: pre-fix, a wrongly-reported `MERGED` on a truly conflicting PR was caught by the gate. That net cannot be kept — a `CONFLICTING` field on a `MERGED` snapshot is exactly the legitimate stale-data case — so corroboration is the right replacement. | `story_finish.py`:228, 658 |
| [MEDIUM] | **[TYPE]** The tri-state decision (block / proceed / already-merged) is squeezed through `str \| None`, so precedence lives only in statement order inside one function body and the caller re-derives merged-ness independently at line 658. Safe today only because both reads hit the same object. TEA and Dev both flagged this; a `_classify_pr(view) -> PrVerdict` consolidation absorbs all three layers. | `story_finish.py`:287, 658 |
| [MEDIUM] | **[TYPE]** Dry-run preview never calls `_pr_block_reason`, so an OPEN+CONFLICTING PR previews "Merge PR #N (squash, delete branch)" and then hard-aborts in the real run. This is 155-31's parity contract broken in the *opposite* direction from the half this story fixed — pre-existing, and the natural companion to it. Found independently by me and by reviewer-type-design. | `story_finish.py`:565-576 |
| [LOW] | **[TEST]** `_result_blob` sweeps `error` and `action` but not `message` or `detail`. `message` *is* a live step key (human-mode step 2), so the "every operator-visible string" claim in its own docstring is not quite true. No live hole — human mode never reaches the conflict gate — but relocating advice into `message` would pass silently. | test file:260-270 |
| [LOW] | **[TEST]** Coverage gaps, all verified correct by my truth table but unpinned by tests: `state` absent from the snapshot entirely, and lowercase/mixed-case `state`. | test file:186, 573 |
| [LOW] | **[SEC]** `_pr_view` validates only `isinstance(data, dict)`, not field types. Pre-existing, and `str()` coercion means a non-string `state` can never equal `"MERGED"` — so I downgraded reviewer-security's Rule #8 flag from medium to low rather than dismissing it. | `story_finish.py`:251 |

**[RULE]** reviewer-rule-checker returned a clean sweep — 13/13 python lang-review checks, 47 instances, 0 violations — and independently verified repo topology against `repos.yaml`: both changed files sit under `pennyfarthing-dist/**` (owned by the `pennyfarthing` repo), neither is in a `never_edit` zone (which covers only `node_modules/**`, `packages/*/dist/**`, `*.tsbuildinfo`), and the branch correctly targets `develop` per gitflow. I spot-checked its two most failure-prone claims myself: mock patch targets (`get_pr_merge_mode` is a lazy in-body import, so patching `pf.common.pr_config.get_pr_merge_mode` is the correct target, not the consuming module — confirmed at `story_finish.py`:542 and :598) and check #13 fix-introduced-regressions (the 2-line guard adds no exception handling, no mutable default, no annotation loss). Both hold. Its one error is the parametrization claim, challenged above.

**Dismissed:** none of the rule-matching findings. **[SEC]** reviewer-security's bare-`except` flag at line 897 does match python lang-review #1, is outside this diff, and is recorded as an upstream Delivery Finding rather than a finding against this story.

**Handoff:** To SM for finish-story.

## Delivery Findings

### TEA (test design)
- **Improvement** (non-blocking): `_pr_block_reason` and `_view_is_merged` both read the same snapshot but neither knows the other exists, so their precedence lives only in statement order at the call site. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (a single `_classify_pr(view)` returning an explicit precedence-ordered verdict would make the ordering unforgettable rather than positional). Not in scope for a 1-pt fix. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): the guard order inside `_pr_block_reason` is now itself load-bearing and unenforced — the merged check must precede the `mergeable`/`mergeStateStatus` read, and nothing but the 162-1 tests stops a future edit from inserting a new block condition above it. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (TEA's proposed `_classify_pr(view)` returning a precedence-ordered verdict would absorb this too). Same root shape as TEA's finding, one layer down. *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): the already-merged short-circuit now trusts `state == MERGED` from one `gh pr view` snapshot to skip the conflict gate, the merge, and the post-merge re-verification — three gates on one field, with no corroborating signal. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (add `mergedAt` to `_PR_VIEW_FIELDS` and require it non-null in `_view_is_merged`, so the bypass needs two independent GitHub fields to agree). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `--dry-run` never evaluates the conflict gate, so an OPEN+CONFLICTING PR previews a merge the real run hard-aborts — 155-31's preview/reality parity broken in the opposite direction from the merged half this story fixed. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` lines 565-576 (the dry-run arm needs a third branch previewing the conflict abort). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_result_blob` in the 162-1 test file claims to sweep "every operator-visible string" but omits the `message` key, which is live on the human-mode step-2 record. Affects `pennyfarthing-dist/src/pf/tests/test_162_1_finish_merged_before_conflict_gate.py` (append `message` and `detail` to the sweep). *Found by Reviewer during code review.*
- **Question** (non-blocking): `story_finish.py` line 897 carries a bare `except Exception:` degrading to `current_status = "in_progress"` with no logging and no stated justification, running *after* the irreversible merge has landed. Matches python lang-review check #1. Outside this story's diff — pre-existing from 155-16. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (narrow the catch or log the swallowed exception type). *Found by Reviewer during code review.*

## Design Deviations

### TEA (test design)
- **Stale-shape parametrization:** ACs name only `DIRTY`. Tests parametrize three shapes (`CONFLICTING+DIRTY`, `CONFLICTING`-only, `DIRTY`-only). Reason: `_pr_block_reason` blocks on `mergeable == CONFLICTING` **or** `mergeStateStatus == DIRTY`; a fix that addresses one field leaves the other aborting the retry.
- **Extra guard beyond the ACs (`CLOSED`-unmerged):** ACs contrast MERGED against OPEN only, which admits a fix keyed on "state != OPEN". That would treat a closed-without-merging PR as landed and finish a story whose code was thrown away, so the test pins `state == MERGED` as the sole exemption.
- **Extra RED test beyond the ACs (dry-run parity):** the same stale snapshot makes `--dry-run` promise a skip that the real run refuses, so 155-31's parity contract is also broken by this bug and is pinned here.

### Dev (implementation)
- No deviations from spec. TEA's designed interface sanctioned either the call-site reorder or the helper-level early return; the helper-level shape was chosen from within that permitted set, so this is a sanctioned choice rather than a divergence. Rationale recorded in the Dev Assessment.