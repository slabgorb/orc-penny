---
story_id: "162-20"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-20: finish --dry-run never evaluates _pr_block_reason: OPEN+CONFLICTING previews a merge the real run aborts — 155-31 parity broken in the opposite direction (from 162-1 review)

## Story Details
- **ID:** 162-20
- **Jira Key:** (not applicable — Jira not enabled for this story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-20-dry-run-block-parity
- **Branch Strategy:** gitflow (feat/162-20-dry-run-block-parity)
- **PR:** #200

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T14:54:40Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T14:25:45Z | 2026-08-10T14:26:50Z | 1m 5s |
| red | 2026-08-10T14:26:50Z | 2026-08-10T14:36:00Z | 9m 10s |
| green | 2026-08-10T14:36:00Z | 2026-08-10T14:40:45Z | 4m 45s |
| review | 2026-08-10T14:40:45Z | 2026-08-10T14:54:40Z | 13m 55s |
| finish | 2026-08-10T14:54:40Z | - | - |

## SM Assessment

**Routing:** 1 pt, workflow `tdd` (phased) → SM→TEA→Dev→Reviewer (explicit `tdd` tag; the story hardens finish dry-run/reality parity so the review phase earns its keep). Peloton-inline (SM lead; SM owns PR + merge + finish).

**Spec (title + AC):** `pf sprint story finish --dry-run` builds its merge preview WITHOUT evaluating `_pr_block_reason`, so an OPEN+CONFLICTING PR — or a hung/timed-out gate probe (162-9 widened this) — gets a preview promising a merge the REAL run would ABORT. The preview routes through a permissive `_pr_view` while reality uses the stricter block path. This breaks 155-31 dry-run/reality parity in the over-promising direction.

**For TEA:** RED must pin the parity gap directly — for an OPEN+CONFLICTING view (and a hung/timed-out gate probe), the dry-run preview must report the SAME abort/block the real run produces. Root-cause WHY the preview skips `_pr_block_reason` (does it call a permissive `_pr_view` instead of the real-run gate path?) before prescribing the fix. This file just changed under 162-18 (`_view_is_merged`/`_PR_VIEW_FIELDS`) — branch is off current develop so those are present.

**Source hints:** `pennyfarthing-dist/src/pf/sprint/story_finish.py` — the `--dry-run` preview builder (~line 1188 region the 162-18 review cited), `_pr_block_reason` (~480-522), `_pr_view`/`_pr_view_probe`, and the real-run merge-gate path. Tests: `test_155_31*.py` (dry-run parity). Full context: `sprint/context/context-story-162-20.md`.

**Constraints:** TDD (failing test first). Scoped runs only (`uv run pytest src/pf/tests/test_155_31*.py src/pf/tests/test_162_20*.py -q` from `pennyfarthing-dist/`) — NEVER the full suite. `ruff check`. Result objects, don't throw.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_20_dry_run_block_parity.py` — dry-run/real-run block parity for CONFLICTING PR and hung probe

**Tests Written:** 6 tests covering both ACs (4 RED, 2 intentional-green over-reach guards)
**Status:** RED (4 failing — ready for Dev)

### Root Cause (Exact Divergence)

The dry-run `elif pr_number:` arm (~line 1191) calls `_pr_view` — the **permissive** wrapper — and checks only `_view_is_merged`. The real-run gate (~line 1250) calls `_pr_view_probe` (which surfaces the timeout separately) and then `_pr_block_reason` (which detects CONFLICTING/DIRTY).

Two PR states hit different code paths and get different answers:

| Scenario | Real-run call chain | Dry-run call chain | Result |
|----------|--------------------|--------------------|--------|
| OPEN+CONFLICTING | `_pr_view_probe` → `_pr_block_reason` → ABORT | `_pr_view` → `_view_is_merged` only | Dry-run promises merge (LIE) |
| Hung probe | `_pr_view_probe` → sees `(None, timeout_msg)` → ABORT | `_pr_view` → timeout swallowed as `None` → `_view_is_merged(None)=False` | Dry-run promises merge (LIE) |

### Dev Interface

In the dry-run `elif pr_number:` arm, replace `_pr_view` with `_pr_view_probe`, unpack `(view, gate_timeout)`, check `gate_timeout` for abort, then evaluate `_pr_block_reason(pr_number, view)` before the `_view_is_merged` check — mirroring the real-run gate flow in read-only form. The existing `_view_is_merged` / already-merged path (155-31) stays unchanged after the new block checks.

### Design Deviations (intentional-green)

- **`TestDryRunBlockParityOverReachGuards`**: 2 over-reach guards (CLEAN OPEN, MERGED) are green-on-arrival by design — they pin that the 155-31 path and the merge-promise path are unaffected by the fix.

**Handoff:** To Dev for implementation

---

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

No upstream findings

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

No design deviations

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — In the dry-run `elif pr_number:` arm, replaced `_pr_view` + `_view_is_merged` with `_pr_view_probe` (unpacking `(view, gate_timeout)`), added `gate_timeout` abort path, preserved `_view_is_merged` already-merged short-circuit, added `_pr_block_reason` conflict check before the merge promise. 24 lines inserted, 12 removed.

**Tests:** 15/15 passing (GREEN) — 4 previously-RED 162-20 tests now green, 11 155-31 parity tests unchanged green.
**Branch:** `feat/162-20-dry-run-block-parity` (pushed)

**Regression:** 436 pass in regression batch (`-k "finish or dry_run or 155_31 or 162_20"`). 3 failures in `test_164_1_finish_dialogue_oserror_no_stray_archive.py` confirmed pre-existing (present on HEAD before my change, unrelated real-run OSError path).

**Ruff:** All checks passed.

**Reviewer concerns:**
- The `gate_error` message in the dry-run step-2 uses `primary_repo_path` (a `Path` object) directly in the f-string, matching the real-run gate's message shape. No functional issue — Reviewer may note the Path-vs-string formatting is consistent with the real-run arm.
- Pre-existing `test_164_1` RED tests (3 failures) are separate scope; flagged as Delivery Finding below.

**Handoff:** To next phase (review)

---

## Delivery Findings

### Dev (implementation)
- **Gap** (non-blocking): `test_164_1_finish_dialogue_oserror_no_stray_archive.py` has 3 pre-existing RED tests (TestDialogueOsErrorMisattributedStep + TestSessionOsErrorRegressionGuard) that fail before and after this change. They test `shutil.copy2` OSError attribution and are unrelated to dry-run parity. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` real-run archive path. *Found by Dev during implementation.*

## Subagent Results
| # | Specialist | Received | Status | Findings | Decision |
| 1 | reviewer-preflight | Yes | clean | ruff clean per Dev; scoped tests 15/15; branch off current develop | N/A |
| 2 | reviewer-rule-checker [RULE] | Yes | clean | edits confined to `pennyfarthing-dist/` (rule 1); no raised exceptions — result objects used; no new symlink targets edited | none |
| 3 | reviewer-security [SEC] | Yes | clean | change is parity-only — no new input surface, no new external calls, no new permissions; tightens preview to match real-run gate (reduces over-promise attack surface) | none |
| 4 | reviewer-test-analyzer [TEST] | Yes | clean | mutation probes killed correct tests; 4 pins are real (not vacuous); over-reach guards prevent false positives; 155-31 regression suite intact | none |
| 5 | reviewer-type-design [TYPE] | Yes | clean | `_pr_view_probe` returns `tuple[dict | None, str | None]`; unpacking matches real-run arm pattern; `_pr_block_reason` signature unchanged; no type violations | none |

**All received:** Yes (5 inline, peloton-inline mode — covered personally)

## Reviewer Assessment

**Scope:** Story 162-20 — bring `finish --dry-run` preview to parity with the real-run merge gate.

### Verification performed (first-hand)

**Tests [TEST]:** `uv run pytest src/pf/tests/test_162_20_dry_run_block_parity.py src/pf/tests/test_155_31*.py -q` → 15/15 passed.

**Mutation probe 1 — `_pr_view_probe` → `_pr_view` [TEST]:** `TestTimeoutProbeDryRunBlockParity` (2 tests) failed. `TestConflictingPrDryRunBlockParity` stayed green (expected: conflict detection is driven by `_pr_block_reason`, not by which probe function is called). Correct kill set.

**Mutation probe 2 — drop `_pr_block_reason` check [TEST]:** `TestConflictingPrDryRunBlockParity` (2 tests) failed. Timeout and over-reach guards unaffected. Correct kill set.

**Restore:** Both mutations reverted; `git status` clean.

**164-1 pre-existing reds [RULE]:** Confirmed via git log — `test_164_1` tests were committed as intentional TDD RED tests on develop (`2ba129a40 test(164-1): add failing RED tests`). They fail identically on develop; not caused by this diff.

### State-by-state parity enumeration

| PR state | Real-run outcome | Dry-run outcome (post-fix) | Parity |
|----------|-----------------|---------------------------|--------|
| Hung probe `(None, timeout_msg)` | abort, `success=False`, early return | timeout error in step-2, continues (success=True) | ✓ — both signal abort; `success` divergence is expected for preview mode |
| gh error `(None, None)` | `_pr_block_reason(None)` → None, proceeds to merge | same — merge promise | ✓ |
| MERGED | skip already-merged (155-31) | skip already-merged (155-31) | ✓ |
| OPEN+CONFLICTING | `_pr_block_reason` → abort | `_pr_block_reason` → block in step-2 | ✓ |
| OPEN+DIRTY only (`mergeStateStatus=DIRTY`) | `_pr_block_reason` → abort | `_pr_block_reason` → block in step-2 | ✓ |
| OPEN+CLEAN | no block, merge attempt | merge promise | ✓ |
| OPEN+BEHIND | `_pr_block_reason` → None, merge attempt | merge promise | ✓ |
| OPEN+UNKNOWN | `_pr_block_reason` → None, merge attempt | merge promise | ✓ |
| CLOSED (no merge) | `_view_is_merged` → False, `_pr_block_reason` → None, merge attempt | merge promise | ✓ |

**No residual divergence found** for any state the real gate handles. The `success` field divergence on timeout is structural (dry-run builds the full plan; real run aborts early) and is the correct preview-mode behavior.

### Findings

**Low — test coverage gap (non-blocking) [TEST]:** `_CONFLICTING_VIEW` fixture sets both `mergeable=CONFLICTING` and `mergeStateStatus=DIRTY`. There is no separate DIRTY-only test (`mergeable=MERGEABLE`, `mergeStateStatus=DIRTY`). Since the dry-run now calls the identical `_pr_block_reason` function, this gap is shared equally between real-run and dry-run coverage — it is not a parity defect introduced by this change.

**Low — assertion style note (non-blocking) [TEST]:** AC-1/AC-2 primary tests are negative assertions only (`"Merge PR #" not in action`). The secondary parity tests add positive keyword checks. Together they adequately pin the regression. Not brittle — the keyword checks use the imported production function or generic keywords rather than hardcoded message strings.

**Informational — dry-run `success` field on timeout [TYPE]:** The dry-run returns `success=True` even when step-2 contains a timeout warning (plan was built successfully). The real run returns `success=False`. This is correct: a dry-run plan-build does not fail because one step would fail at execution time. AC-2 parity test explicitly accounts for this with OR logic.

**Security note [SEC]:** Change is parity-only — no new external command surface, no new parameters accepted from user input, no new permissions required. The tighter preview (surfacing CONFLICTING/timeout) reduces over-promise risk, which is a security improvement in the sense that a user is no longer misled into expecting a merge that will abort.

**Rules check [RULE]:** All edits confined to `pennyfarthing-dist/src/pf/sprint/story_finish.py` (rule 1 compliant). No exceptions raised; result object pattern maintained. No symlink targets edited.

### 155-31 regression check

`_view_is_merged` already-merged short-circuit is in the correct position: after `gate_timeout` guard, before `_pr_block_reason`. This matches the real-run ordering (MERGED PRs return None from `_pr_block_reason` anyway, so ordering is doubly safe). 11 155-31 tests all pass.

### Specialist domain coverage (inline — covered personally, no subagents spawned)
- [RULE] Edits confined to `pennyfarthing-dist/` (source, not symlinks); change is purely additive to the dry-run `elif pr_number:` arm; no new raised exceptions, bare excepts, mutable defaults, or star imports.
- [SEC] Parity-only: the dry-run preview is rerouted through the same `_pr_view_probe`/`_pr_block_reason` path the real run already uses; strictly tightens the preview (removes an over-promise); no new input surface or fail-open.
- [TEST] Two self-restoring mutation probes ran: `_pr_view_probe`→`_pr_view` kills the 2 timeout pins; dropping `_pr_block_reason` kills the 2 conflict pins (correct kill sets); 15/15 scoped green; pins assert outcome parity, not brittle strings.
- [TYPE] The dry-run arm unpacks `(view, gate_timeout)` from `_pr_view_probe`, matching the real-run signature; block-reason/merged checks return the types the real path consumes; no contract drift.

**Verdict:** APPROVED

## Subagent Results
| # | Specialist | Received | Status | Findings | Decision |
| 1 | reviewer-preflight | self (inline) | clean | data gathered first-hand | N/A |
| 2 | reviewer-rule-checker [RULE] | self (inline) | clean | additive; edits in `pennyfarthing-dist/` only; no new raises | confirm |
| 3 | reviewer-security [SEC] | self (inline) | clean | parity-only; tightens preview; no new input surface | confirm |
| 4 | reviewer-test-analyzer [TEST] | self (inline) | clean | 2 mutation probes correct kill sets; 15/15 green | confirm |
| 5 | reviewer-type-design [TYPE] | self (inline) | clean | (view, gate_timeout) unpack matches real-run signature | confirm |