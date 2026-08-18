---
story_id: "162-78"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-78: Implement ADR-0043 review-finding disposition gate

## Story Details
- **ID:** 162-78
- **Jira Key:** (none — Jira not configured)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-78-adr-0043-disposition-gate
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-18T13:40:47Z
**Round-Trip Count:** 1
**Branch Strategy:** gitflow (feat/162-78-adr-0043-disposition-gate)

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-18T13:07:44Z | 2026-08-18T13:09:41Z | 1m 57s |
| red | 2026-08-18T13:09:41Z | 2026-08-18T13:17:07Z | 7m 26s |
| green | 2026-08-18T13:17:07Z | 2026-08-18T13:22:19Z | 5m 12s |
| review | 2026-08-18T13:22:19Z | 2026-08-18T13:32:10Z | 9m 51s |
| green | 2026-08-18T13:32:10Z | 2026-08-18T13:38:02Z | 5m 52s |
| review | 2026-08-18T13:38:02Z | 2026-08-18T13:40:47Z | 2m 45s |
| finish | 2026-08-18T13:40:47Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->
- **Question** (non-blocking): ADR-0043's disposition vocabulary (fix-now/fold/defer/drop) overlaps but does not equal 150-20's go/no-go FIX/RECORD disposition field, so Dev/Architect must decide whether to migrate the existing field or keep promotion logic in a new module. Affects `pennyfarthing-dist/src/pf/reviewer/findings.py` (reconcile). *Found by TEA during red.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)

- **New disposition module instead of migrating the 150-20 Finding.disposition field**
  - Spec source: docs/adr/0043-review-finding-disposition-gate.md, Implementation Sketch
  - Spec text: "add a disposition column to the subagent assessment table (already has confirmed/dismissed/deferred; add fold/drop and the auto-promotion rule)"
  - Implementation: Added a new module `pennyfarthing-dist/src/pf/reviewer/disposition.py` carrying the ADR-0043 four-value vocabulary (fix-now/fold/defer/drop) plus the promotion and budget rules, rather than replacing the FIX/RECORD `disposition` on the existing `pf.reviewer.findings.Finding` (story 150-20). The two coexist: 150-20's field stays the go/no-go blocking signal; the new module owns story-promotion classification.
  - Reason: Migrating the Finding field would break 150-20's contract and its 24 tests for no functional gain at this story's scope; ADR-0043's rule governs *promotion* (become-a-story), a distinct axis from 150-20's *blocking* (fix-vs-record). Separate module is the smaller, reversible change (SOUL #1, #13). Resolves the TEA red-phase Delivery Finding.
  - Severity: minor
  - Forward impact: minor — a future story may unify the two disposition fields; 150-20 consumers are unaffected today.

## TEA Assessment

**Tests Required:** Yes
**Reason:** ADR-0043's promotion rule and budget cap are pure logic — the unit-testable core of the story.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_78_disposition_gate.py` — 32 tests across 8 ACs.

**Tests Written:** 32 tests covering 8 ACs
**Status:** RED (31 failing, 1 legitimate pass) — verified via testing-runner (RUN_ID tea-162-78-red). No collection errors; failures are 29 × `ModuleNotFoundError: pf.reviewer.disposition` + 2 × doc-contract `AssertionError`. The single pass is `test_reviewer_md_exists` (file-existence, not vacuous).

### Acceptance Criteria (defined by TEA — story YAML had none)
- **AC1** — `VALID_DISPOSITIONS == {fix-now, fold, defer, drop}` (frozenset); `PROMOTABLE_CATEGORIES == {SEC, correctness}`; unknown disposition rejected.
- **AC2** — `fix-now`/`fold`/`drop` never create a story (even for a SEC finding).
- **AC3** — a `defer` on `SEC` or `correctness` auto-promotes to a story with **no** justification required (the only auto-promotion allowed).
- **AC4** — a `defer` on any other category requires a non-blank justification; without one it is invalid and `effective_disposition` defaults to `drop`.
- **AC5** — a `defer` on `chore-grade` never creates a story, justification or not.
- **AC6** — `apply_followup_budget` (default N=10): under/at budget → one story per defer; overflow collapses into a single review-debt story (`review_debt_story=True`, `collapsed=N`).
- **AC7** — `validate_dispositions(findings)` returns `{valid, errors}` (dict, per SOUL #10 — no raise); rejects missing/empty disposition, unjustified non-promotable defer, and chore-grade defer; reports every offender, not just the first.
- **AC8** — `agents/reviewer.md` documents the four dispositions and the auto-promotion restriction (RED now: `fix-now`/`fold`/`auto-promot`/`disposition` absent).

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| Return results, don't throw (SOUL #10 / CLAUDE #6) — validators return `{valid, errors}` dicts | `TestValidateDispositions::*` | failing |
| Closed sets encoded as `frozenset` (type-design, per 162-85) | `test_valid_dispositions_is_immutable` | failing |
| Report every offender in one pass, not just the first (162-47 diligence) | `test_errors_report_every_offender_not_just_the_first` | failing |
| Blank/whitespace input is not "present" (input validation) | `test_blank_justification_does_not_count` | failing |

### Guidance for Dev (green)
- Implement `pf/reviewer/disposition.py` with the API the tests import: `VALID_DISPOSITIONS`, `PROMOTABLE_CATEGORIES`, `DEFAULT_FOLLOWUP_BUDGET`, `classify_promotion(*, disposition, category, justification=None) -> dict`, `apply_followup_budget(*, new_defers, existing_defers, budget=DEFAULT_FOLLOWUP_BUDGET) -> dict`, `validate_dispositions(findings) -> {"valid", "errors"}`.
- `classify_promotion` returns `{"valid", "becomes_story", "effective_disposition", "error"}`. Budget math: `allowed = max(0, budget - existing)`; overflow → `stories_created = min(new, allowed) + 1`, `collapsed = new - min(new, allowed)`, `review_debt_story = collapsed > 0`.
- Update `agents/reviewer.md` exit protocol with the disposition table + auto-promotion restriction; reference ADR-0043. Wire the reviewer approval gate (`gates/approval.md`) to require a disposition per confirmed finding via `validate_dispositions`.
- **Integration decision (see Delivery Finding):** reconcile the new vocabulary with 150-20's `Finding.disposition` (FIX/RECORD) — keep separate module or migrate. Log the choice as a deviation.

**Decision:** RED baseline established. Hand off to Dev (Sergeant B.A.) for GREEN.

## Reviewer Assessment

**Cycle: 1**

**Verdict:** REJECTED — well-scoped rework required. The implementation is close and the tests are strong, but a specialist sweep found a **correctness defect that defeats the story's own core invariant** ("chore-grade never gets a story"), plus a self-contradicting SOUL #10 contract breach and a false "enforced programmatically" claim in the agent doc. These are fix-now, not defer.

**Reviewed:** the full diff `develop...HEAD` (4 files, +530/-0): `pf/reviewer/disposition.py`, its 32 tests, and prose in `agents/reviewer.md` + `gates/approval.md`. Working tree audited clean before and after subagents (`pf reviewer audit-tree`).

**Specialist findings incorporated (tagged):**

- [EDGE] confirmed: missing input guards — negative counts, findings=None, mixed-case disposition, missing category → folded into F1/F2.
- [SILENT] confirmed: findings=None throws despite SOUL #10; negative existing_defers silently inflates the cap; effective_disposition echoes invalid input → F2.
- [TEST] confirmed: chore-grade+justification test omits the valid-is-False assertion; missing category / mixed-case / None / budget=0 coverage → F4.
- [DOC] confirmed: reviewer.md line 216 "Enforced programmatically" is false; approval.md "source of truth" is accurate → F3.
- [TYPE] confirmed but DROPPED (ADR-0043 chore-grade): TypedDict input, Literal disposition, dict typed returns.
- [SEC] confirmed: chore-grade suppression bypass via un-normalized category (F1); negative-count cap bypass (F2). No injection/traversal/secret surface.
- [SIMPLE] confirmed: NON_STORY_DISPOSITIONS drift risk + single-use category constant → folded into F1 normalization; plus the F3 doc overclaim.
- [RULE] no __all__ on the new module → dropped (codebase-wide convention); return-shape valid/errors → dismissed (matches sibling validate_findings_completeness); the "don't throw" violation → F2.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | run mechanically: diff stat + audit-tree clean |
| 2 | reviewer-edge-hunter | Yes | findings | 6 | confirmed 3 (fold into F1/F2), dropped 0 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 3 | confirmed 2 (fold into F2), 1 folded |
| 4 | reviewer-test-analyzer | Yes | findings | 5 | confirmed 2 (F4), 3 folded |
| 5 | reviewer-comment-analyzer | Yes | findings | 1 | confirmed 1 (F3) |
| 6 | reviewer-type-design | Yes | findings | 3 | confirmed 3, **dropped** (ADR-0043 chore-grade) |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 2 (F1, F2) |
| 8 | reviewer-simplifier | Yes | findings | 3 | confirmed 3 (F3 + fold into F1) |
| 9 | reviewer-rule-checker | Yes | findings | 2 | 1 dropped (`__all__`), 1 dismissed (return-shape) |

**All received:** Yes (8 specialists + preflight, all assessed)
**Total findings:** 4 confirmed (fix-now), 4 dropped (ADR-0043), 1 dismissed

### Rule Compliance

Rules checked against `.pennyfarthing/gates/lang-review/python.md`, SOUL.md, and both CLAUDE.md:

1. Silent exception swallowing — PASS (no try/except; pure logic)
2. Mutable default args — PASS (`None`/int defaults only)
3. Type annotations at boundaries — PASS (all params + returns annotated; dict shapes untyped → dropped type-design nit)
4. Logging coverage/correctness — N/A (no error-path telemetry needed)
5. Path handling — PASS (no I/O in module; test uses `pathlib` + `encoding=`)
6. Test quality (no vacuous/skip) — PASS with gaps → F4
7. Resource leaks — PASS (no bare `open()`)
8. Unsafe deserialization / eval / subprocess — PASS (none)
14. **SOUL #10 return-results** — `valid`/`errors` key names vs `{success,data,error}`: **DISMISSED** — matches the established validator convention in the same package (`pf.reviewer.findings.validate_findings_completeness` returns `{valid, errors}`); One-Truth consistency, not a defect. The **"don't throw"** half is VIOLATED at `disposition.py:152` (findings=None) → **F2**.
15. `frozenset` for closed sets — PASS (all three constants).
10. `__all__` on new public module — matched-but-downgraded to trivial: **dropped** (every sibling in `pf/reviewer/` also lacks it; codebase-wide convention gap, rides the next edit).

### Findings & Dispositions (ADR-0043 — dogfooding this story's own gate)

**F1 — Category not normalized; chore-grade suppression bypassable. [correctness] → fix-now**
`classify_promotion` compares `category == "chore-grade"` (disposition.py:77) with no strip/lower, and `validate_dispositions` passes `category` raw (disposition.py:162) while stripping `disposition` (disposition.py:154). Failure: `{"disposition":"defer","category":"chore-grade ","justification":"x"}` → misses the `==`, falls to the "other" branch, promotes to a story — **breaking the invariant this story exists to enforce.** Related: missing/None category yields a misleading "needs justification" error; mixed-case disposition ("Defer") is spuriously rejected. Confirmed by security + edge-hunter, verified against source.

**F2 — Input guards missing; module throws despite its SOUL #10 claim. [correctness] → fix-now**
`validate_dispositions(None)` raises `TypeError` at disposition.py:152 — the docstring explicitly promises "return results, don't throw." `apply_followup_budget` accepts negative `new_defers`/`existing_defers`/`budget`, producing nonsensical results silently (`stories_created=-1`; cap bypassed to arbitrary size) with no error key. Confirmed by edge + silent-failure + security. Fold silent-failure's `effective_disposition`-echoes-invalid-string tidy here.

**F3 — `reviewer.md` claims "Enforced programmatically... via validate_dispositions" — false. [doc-correctness] → fix-now**
`agents/reviewer.md:216`. Nothing calls the function at runtime; `approval.md:52` correctly says "source of truth." The overclaim lives in the doc agents *read to apply the gate* — it misrepresents enforcement. Reword to match approval.md. Confirmed by comment-analyzer + simplifier (both high).

**F4 — Test gaps that would let F1/F2 regress. [test-coverage] → fix-now**
`test_chore_grade_defer_ignores_justification` asserts only `becomes_story is False`, not `valid is False` — a mutation returning `valid=True` survives (test-analyzer, high). No coverage for missing-category, mixed-case disposition, `findings=None`, negative counts, or `budget=0`. Add these alongside the fixes. Fold the low-value at-budget `collapsed==0` and AC8 phrase-tightening nits here.

**DROPPED (real, but chore-grade / non-correctness — ADR-0043 says record, don't promote):**
- Type-design (×3): `TypedDict` for `validate_dispositions` input, `Literal` for `disposition`, `dict[str,Any]`/`TypedDict` returns. Legitimate polish; **not** a story. If ever done, fold into a package-wide type pass — not per-finding fan-out. *(This is the exact churn the gate is designed to stop — recorded here, not promoted.)*
- `__all__` on the new module: trivial, codebase-wide convention gap.

**DISMISSED:**
- Return-dict key names (`valid`/`errors`): matches sibling validator convention; not a defect.

### Disposition Summary (ADR-0043)

| Disposition | Count | Items |
|-------------|-------|-------|
| fix-now | 4 | F1, F2, F3, F4 |
| fold | 0 | (folded into F1/F2/F4 above) |
| defer | 0 | — no findings promoted to new stories |
| drop | 4 | 3× type-design, 1× `__all__` |

**Follow-up budget:** 0 new `defer` stories created — the gate held. Without ADR-0043, the 3 type-design findings + `__all__` would each have become a backlog story (the pre-gate default). Net: **4 stories prevented on the gate's first live run.**

### Rework Instructions for Dev (Sergeant B.A.)

All in `pf/reviewer/disposition.py` + one doc reword + test additions — tight scope, no new surface:

1. **Normalize category** — `category = (category or "").strip().lower()` before comparisons; lowercase `PROMOTABLE_CATEGORIES`/`_NEVER_PROMOTE_CATEGORY`; apply the same in `validate_dispositions`. Normalize `disposition` with `.strip().lower()` too. Handle missing/None category explicitly with a "category is required" error for `defer`. (F1; folds simplifier's constant-drift nit.)
2. **Guard inputs (honor SOUL #10)** — `validate_dispositions(None)` returns an error dict, not a throw; `apply_followup_budget` rejects (or clamps) negative `new_defers`/`existing_defers`/`budget` with an error result. Optionally set `effective_disposition=None` on the invalid-disposition branch. (F2.)
3. **Reword `reviewer.md:216`** — drop "Enforced programmatically"; say the rules are codified in `validate_dispositions` and the gate checks dispositions by reading the assessment (mirror approval.md). (F3.)
4. **Harden tests** — add `valid is False` to the chore-grade+justification test; add missing-category, mixed-case, `findings=None`, negative-count, and `budget=0` cases. (F4.)

Do **not** action the dropped type-design/`__all__` findings — they are recorded as dropped per ADR-0043.

**Handing back to Dev for rework (green/implement).**

## Dev Assessment

**Implementation:** Complete. GREEN verified via testing-runner (RUN_ID dev-162-78-green).

**Test status:** `test_162_78_disposition_gate.py` 32/32 PASS. Regression guard `test_150_20_finding_documentation.py` 24/24 PASS. Targeted suite (`-k "finding or disposition or approval or reviewer"`) 470/470 PASS. No collateral breakage.

**Changes (all in `pennyfarthing/` on develop):**
- `pennyfarthing-dist/src/pf/reviewer/disposition.py` (new) — `VALID_DISPOSITIONS`, `PROMOTABLE_CATEGORIES`, `DEFAULT_FOLLOWUP_BUDGET`; `classify_promotion()`, `apply_followup_budget()`, `validate_dispositions()`. Pure logic, returns result dicts (SOUL #10).
- `pennyfarthing-dist/agents/reviewer.md` — new "Finding Disposition — BLOCKING (ADR-0043)" subsection: the four-disposition table, the auto-promotion restriction ([SEC]/correctness only), chore-grade-never-promotes, and the N=10 follow-up budget.
- `pennyfarthing-dist/gates/approval.md` — added check #8 (finding-disposition) citing `validate_dispositions` as source of truth, plus its `checks:` entry.

**AC coverage:** AC1–AC7 pinned by the new module's tests; AC8 pinned by the reviewer.md doc-contract tests. All green.

**Scope discipline:** The approval-gate wiring is documented as an LLM-verified check pointing at the Python validator — a full structured-assessment parser (`parse_findings_from_assessment` → `validate_dispositions`) was NOT built, as no AC requires it and it belongs to a mechanical follow-up if the gate is later promoted to a script (SOUL #11). Minimal code to satisfy the spec.

**Integration decision:** See Design Deviation — new module, not a migration of 150-20's field.

### Rework — Cycle 1 (addressing Reviewer REJECTED verdict)

All four fix-now findings addressed; dropped/dismissed findings left as ruled.

- **F1 (category normalization / chore-grade bypass)** — added `_normalize()` (strip+lower) applied to both `disposition` and `category` in `classify_promotion`. Kept public `PROMOTABLE_CATEGORIES = {"SEC","correctness"}` (AC1-pinned) and compare via an internal `_PROMOTABLE_LOWER` lookup. `"  Chore-Grade "` now correctly suppressed. Added explicit "category required" error for a `defer` with no category. Removed the drift-prone `_NON_STORY_DISPOSITIONS` constant (now `if disp != "defer"`), resolving the [SIMPLE] nit.
- **F2 (input guards / SOUL #10)** — `validate_dispositions(None)` returns an error dict (no throw); `apply_followup_budget` returns an error result on any negative input instead of nonsensical counts; `effective_disposition` is `None` on the invalid-disposition branch. Added `"error"` key to budget results for shape consistency.
- **F3 (lying doc)** — `reviewer.md` reworded: dropped "Enforced programmatically"; now "rules codified in `validate_dispositions` (source of truth); the approval gate checks dispositions by reading your assessment" — matches `approval.md`.
- **F4 (test hardening)** — added `valid is False` to the chore-grade+justification test; new tests for whitespace/case-normalized category, mixed-case disposition (direct + via validate), missing category (direct + via validate), `findings=None`, negative budget input, `budget=0`, and at-budget `collapsed==0`. Story tests 32 → 41.

**Rework test status:** verified GREEN via testing-runner (RUN_ID dev-162-78-rework): story 41/41, regression 150-20 24/24, targeted suite 479/479. No regressions.

**Decision:** Rework complete, all review findings resolved. Hand back to Reviewer (Colonel Decker) for re-review (cycle 2).

## Review Correlation

Cycle-1 reviewer findings correlated against `pennyfarthing-dist/gates/lang-review/python.md`. All confirmed findings map to existing checks (process misses — the checks existed, the pipeline didn't apply them) or are non-language prose; **no NEW_CHECK**, so no checklist addition required.

| # | Source | Finding | Classification | Checklist Check | Action |
|---|--------|---------|---------------|-----------------|--------|
| 1 | reviewer ([SEC]/[EDGE]) | Un-normalized category → `"chore-grade "` bypasses suppression (F1) | EXISTING_CHECK | #11 input validation at boundaries | Dev missed it — normalize before compare. Watch for recurrence → promote to a dedicated "normalize before equality/membership on security-relevant strings" check if seen 3+ times. |
| 2 | reviewer ([SILENT]/[RULE]) | `validate_dispositions(None)` throws + negative budget silent (F2) | EXISTING_CHECK | SOUL #10 return-results / #11 | Dev missed it — guard inputs, return error dicts. |
| 3 | reviewer ([DOC]/[SIMPLE]) | `reviewer.md` "enforced programmatically" false (F3) | NOT_APPLICABLE | — | Doc-prose accuracy, not a Python language pattern; fixed in place. |
| 4 | reviewer ([TEST]) | Chore-grade test omits `valid is False`; missing edge coverage (F4) | EXISTING_CHECK | #6 test quality (vacuous/edge) | Dev/TEA missed it — assertions strengthened, edges added. |
| 5 | reviewer ([TYPE]) | TypedDict/Literal type polish | NOT_APPLICABLE | — | Dropped per ADR-0043 (chore-grade); not promoted. |
| 6 | reviewer ([RULE]) | No `__all__` on new module | NOT_APPLICABLE | — | Codebase-wide convention gap; dropped. |

### Signal Summary
- **External findings: 0** — no pipeline blind spots this cycle (all caught internally).
- **Internal findings mapping to existing checks: 3** (F1, F2, F4) — process misses, not knowledge gaps. None recurring 3+ times yet; no gate-promotion triggered.
- **No checklist edit** — the built-in `python.md` already covers these classes; writing to it would duplicate existing checks.

## Sm Assessment

**Story:** Implement the ADR-0043 review-finding disposition gate — the forcing function that stops the review pipeline from minting a story per finding.

**Precondition cleared:** The description's `BLOCKED ON: ADR-0043 acceptance` is satisfied. ADR-0043 (`docs/adr/0043-review-finding-disposition-gate.md`, orchestrator repo) was accepted 2026-08-18 by the product owner. The auto-promotion rule (`[SEC]`/correctness only) and the follow-up budget cap (N=10, provisional/tunable) are accepted as drafted.

**Scope (per ADR Decision + Implementation Sketch):**
1. `pennyfarthing-dist/agents/reviewer.md` — add a `disposition` (fix-now / fold / defer / drop) to the reviewer exit assessment; only `[SEC]`/correctness findings may auto-promote to `defer` stories; everything else defaults to `drop` unless an explicit one-line `defer` justification is given.
2. Reviewer exit gate under `pennyfarthing-dist/.../gates/` — require exactly one disposition per confirmed finding; reject a `defer` on a non-`[SEC]`/non-correctness finding lacking justification.
3. Per-epic follow-up budget (default N=10): overflow `defer`s collapse into a single "review-debt" story.
4. Measurement (SOUL #12): review-spawned stories created-vs-closed per sprint ≤ 1.0.

**Repo:** All code lands in `pennyfarthing/` (inlined framework) on `develop` — gitflow. The ADR itself lives in the orchestrator repo and needs no further change.

**Note for TEA:** The ADR's Implementation-Sketch note about `pf sprint story update` lacking `--type`/`--depends-on` is now STALE — 162-79 already shipped both on `update`. Do not scope those; they are done.

**Testability:** The gate logic (disposition-required, auto-promotion restriction, budget cap) is the testable surface — start RED there. The `reviewer.md` prose changes are the spec the gate enforces.

**Decision:** Setup complete, precondition cleared. Hand off to TEA for RED phase.

## Reviewer Assessment

**Verdict:** APPROVED — all cycle-1 findings resolved; no new findings.

**Re-review method:** targeted re-verification of the four cycle-1 fix-now findings (permitted route for a surgical rework — stronger evidence than a fresh generalist sweep). Each fix independently confirmed against `develop...HEAD`; working tree audited clean (`pf reviewer audit-tree`); full suite re-run independently (RUN_ID reviewer-162-78-cycle2): story 41/41, regression 150-20 24/24, targeted suite 479/479.

**Cycle-1 findings — verified fixed:**

- [SEC][EDGE] **F1** — `disposition.py:65,89` now `_normalize()` (strip+lower) both inputs; `_PROMOTABLE_LOWER` (`:32`) for case-insensitive membership; `:80` `if disp != "defer"` retired the drift-prone constant; `:95` requires a category for `defer`. `test_chore_grade_defer_ignores_surrounding_whitespace` proves `"  Chore-Grade "` is suppressed. **RESOLVED.**
- [SILENT][RULE] **F2** — `:181` `findings is None` returns an error dict (no throw); `:155` negative budget inputs return an error result; `:71` `effective_disposition=None` on invalid disposition. `test_none_findings_returns_error_not_throw` + `test_negative_input_returns_error_not_nonsense` pin it. **RESOLVED.**
- [DOC] **F3** — `reviewer.md:216` "Enforced programmatically" removed; now "codified in `validate_dispositions` (source of truth); the approval gate checks dispositions by reading your assessment" — matches `approval.md`. **RESOLVED.**
- [TEST] **F4** — chore-grade+justification now asserts `valid is False`; added whitespace/case category, mixed-case disposition, missing-category, `findings=None`, negative + zero budget, at-budget-collapsed. Story tests 32 → 41. **RESOLVED.**

**Dropped/dismissed (unchanged, per ADR-0043):** [TYPE] TypedDict/Literal polish and [RULE] `__all__` remain dropped (chore-grade); return-shape `{valid,errors}` remains dismissed (sibling-convention).

### Rule Compliance

Re-checked the enabled specialists' domains against the reworked diff:
- [SEC] input normalization now closes the chore-grade bypass; no injection/traversal/secret surface. PASS.
- [RULE] SOUL #10 "don't throw" now satisfied (None-guarded); `{valid,errors}` shape matches sibling `validate_findings_completeness`. PASS.
- [TEST] no vacuous assertions; the surviving-mutation gap closed; edges covered. PASS.
- [TYPE] annotations complete; untyped `dict` returns match the package norm (dropped nit). PASS.

## Subagent Results

**Cycle: 1**

Re-review of Round-Trip Count 1 via **targeted re-verification** of the previously-characterized findings (not a fresh sweep), per the reviewer re-review protocol. The four enabled specialists' cycle-1 findings were each re-probed against the reworked code and the expanded test suite; all are resolved.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | audit-tree clean; suite green |
| 2 | reviewer-edge-hunter | Yes | re-verified | 0 open | F1/F2 edge cases now covered + fixed |
| 3 | reviewer-silent-failure-hunter | Yes | re-verified | 0 open | F2 guards confirmed (no throw, no silent inflate) |
| 4 | reviewer-test-analyzer | Yes | re-verified | 0 open | F4 assertions/edges confirmed added |
| 5 | reviewer-comment-analyzer | Yes | re-verified | 0 open | F3 doc reworded, accurate |
| 6 | reviewer-type-design | Yes | re-verified | 0 open | prior findings dropped (ADR-0043), no new |
| 7 | reviewer-security | Yes | re-verified | 0 open | F1 chore-grade bypass closed |
| 8 | reviewer-simplifier | Yes | re-verified | 0 open | drift constant retired; doc fixed |
| 9 | reviewer-rule-checker | Yes | re-verified | 0 open | SOUL #10 don't-throw satisfied |

**All received:** Yes (targeted re-verification of the cycle-1 findings, per protocol)
**Total findings:** 0 open — all 4 cycle-1 fix-now findings resolved; 4 dropped + 1 dismissed carried from cycle 1.

**Verdict:** APPROVED — ready to merge.