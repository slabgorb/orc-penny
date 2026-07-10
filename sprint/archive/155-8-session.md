---
story_id: "155-8"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-8: Delegate epic-ref resolution to canonical _get_epic_ref (155-4 review deferral)

## Story Details
- **ID:** 155-8
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch Strategy:** gitflow (feat/155-8)

**PR:** #145 - refactor(155-8): delegate epic-ref resolution to canonical _get_epic_ref
**Branch:** feat/155-8

## Context

### Technical Approach
Fix divergent `_resolve_epic_ref` implementations across three call sites by delegating to the canonical `_get_epic_ref` utility. This addresses a consistency issue discovered in 155-4 Reviewer feedback where two independent reimplementations of `str(epic.get("jira") or epic.get("id"))` handle sentinel-jira epics and epic-prefixed no-jira epics differently.

**Call sites to refactor:**
1. `story_finish.py:59` (`_resolve_epic_ref`)
2. `archive_epic.py:330` (`backfill_epic_refs`)

**Delegate to canonical:**
- `yaml_io.py:312` (`_get_epic_ref`)

### Acceptance Criteria
1. Both resolvers (`story_finish.py` and `archive_epic.py`) call `_get_epic_ref`
2. Regression test pins that sentinel-jira epics resolve identically across all three paths
3. Regression test pins that epic-prefixed no-jira epics resolve identically across all three paths

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-10T13:06:29Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-10T12:37:07Z | 2026-07-10T12:38:41Z | 1m 34s |
| red | 2026-07-10T12:38:41Z | 2026-07-10T12:56:06Z | 17m 25s |
| green | 2026-07-10T12:56:06Z | 2026-07-10T12:59:42Z | 3m 36s |
| review | 2026-07-10T12:59:42Z | 2026-07-10T13:06:29Z | 6m 47s |
| finish | 2026-07-10T13:06:29Z | - | - |

## Sm Assessment

Routed from `NEW_WORK_STATE` at Client's direction (chose 155-8 over the ID-order pick 155-7). This is a **2pt phased TDD** story in the active finish-truthfulness epic (155), repo `pennyfarthing` → **`develop`** base branch (gitflow).

**Scope is narrow and well-bounded:** delegate two divergent epic-ref formulas (`story_finish.py:59`, `archive_epic.py:330`) to the canonical `_get_epic_ref` (`yaml_io.py:312`). Latent-only today (every live epic has a real PROJ-* jira so all three resolvers agree), so the value is in the **regression test** pinning sentinel-jira and `epic-`-prefixed no-jira epics resolving identically across all three paths — that test is the real deliverable and the reason this stays `tdd`, not `trivial`.

**Watch-outs for the team:**
- The `epic-`-prefixed-no-jira case is the ADR-0022 double-prefix trap (`epic-epic-94.yaml`). TEA's RED test must exercise it explicitly.
- Confirm `_get_epic_ref` is exported/importable from `yaml_io.py` at both call sites before Dev refactors.
- Branch `feat/155-8` already cut off `develop`. PR targets `develop`.

Handing to TEA (Captain Murdock) for RED phase.

## TEA Assessment

### Red Phase (test writing)

**Tests Required:** Yes
**Reason:** n/a — this is the regression-pin story; the failing tests ARE the deliverable.

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_155_8_epic_ref_canonical_delegation.py` — pins the two divergent call sites to the canonical `_get_epic_ref`.

**Tests Written:** 11 tests (8 RED + 3 intentional green guards) covering 3 ACs.
**Status:** RED (8 failing on `AssertionError`, 0 errored) — ready for Dev.

**Divergence proven (probe + tests), latent-only today:**

| Epic shape | `_get_epic_ref` (canonical) | local `or` formula (both sites) |
|---|---|---|
| sentinel-jira `{id:94, jira:"none"}` | `94` | `none` ❌ |
| `epic-`-prefixed `{id:"epic-94"}` | `94` | `epic-94` ❌ (ADR-0022 double-prefix) |

The truthy `NO_JIRA_SENTINELS` values (`none`/`null`/`x`) and the `epic-` prefix are the only two shapes that diverge; empty-string jira falls through identically on both formulas.

### Rule Coverage

| AC / Rule | Test(s) | Status |
|------|---------|--------|
| AC1 `_resolve_epic_ref` delegates | `test_resolve_epic_ref_matches_canonical[both]`, `test_resolve_epic_ref_delegates_to_canonical` (AST) | failing |
| AC2 `backfill_epic_refs` delegates | `test_backfill_epic_ref_matches_canonical[both]`, `test_backfill_delegates_to_canonical` (AST) | failing |
| AC3 all-three-agree regression pin | `test_all_three_resolvers_agree[sentinel-jira]`, `[epic-prefixed-no-jira]` | failing |
| SOUL #2 one-truth (structural) | `test_*_delegates_to_canonical` (AST call-check) | failing |
| over-reach guard (green) | `test_preserved_cases_unchanged_across_resolvers[real-jira, numeric-id]` | passing (intentional) |
| oracle anchor (green) | `test_canonical_oracle_anchor` | passing (intentional) |

**Rules checked:** 3 of 3 ACs + SOUL #2 have test coverage.
**Self-check:** 0 vacuous tests — every test asserts a concrete ref equality or a structural call presence; no `let _ =`, no `assert True`, no always-None checks.

**Test strategy notes for Dev (GREEN):**
- `_get_epic_ref` is the oracle — behavioral tests assert each site == `_get_epic_ref(epic)`, so they pass whether you delegate or (undesirably) re-derive the same value. The two **AST structural tests forbid a third inline copy** — you MUST call `_get_epic_ref` in both function bodies (SOUL #2).
- `archive_epic.py` **already imports** `_get_epic_ref` (line 16, used at line 474) — the `backfill_epic_refs` site (line 330) just swaps the `or` chain for `_get_epic_ref(epic)`.
- `story_finish.py` does **not** import it yet — add `from pf.sprint.yaml_io import _get_epic_ref` (it currently imports only `read_sprint`), then replace the `ref = str(epic.get("jira") or epic.get("id") or "").strip()` line (actual line ~63, not 59) with `ref = _get_epic_ref(epic)`. Note `_get_epic_ref` already strips + falls through, so the surrounding `if ref:` guard still holds (`_get_epic_ref` returns `""` only for an id-less epic).

**Handoff:** To Dev (Sergeant B.A. Baracus) for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` — added `_get_epic_ref` to the `yaml_io` import; `_resolve_epic_ref` now calls `_get_epic_ref(epic)` instead of the inline `str(epic.get("jira") or epic.get("id") or "").strip()`.
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/archive_epic.py` — `backfill_epic_refs`'s `id_to_epic` builder now calls `_get_epic_ref(epic)` (import already present).

**Approach:** Minimal 2-line-per-site delegation (`delegate-to-existing-resolver` pattern, same class as sister 155-3). Both call sites now route through the single canonical formula (SOUL #2), so sentinel-jira (`none`/`null`/`x`) and `epic-`-prefixed no-jira epics resolve identically across all three paths. The surrounding truthiness guards (`if ref:` fallthrough in `_resolve_epic_ref`; `if not epic_ref: continue` in the backfill loop) are preserved unchanged — `_get_epic_ref` returns `""` only for an id-less epic, matching the old formula's falsy result. Followed TEA's AST structural tests: delegated via an actual `_get_epic_ref` call, did **not** re-derive the value inline.

**Tests:** 11/11 passing (GREEN) — the 8 previously-RED now pass, the 3 green guards held. Regression batch `test_155_4 test_155_3 test_archive_epic test_yaml_io test_story_finish_no_jira test_151_3` = 87 passed / 1 skipped (pre-existing shard-ref warning, unrelated). `ruff check` clean on both files.
**Branch:** feat/155-8 (pushed, `e01b089b4`)

**Handoff:** To Reviewer (Colonel Decker) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 98 passed / 1 skipped, ruff clean, 0 smells | N/A |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 2 (low) | confirmed 0, dismissed 2 (self-attenuated) |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings |
| 6 | reviewer-type-design | Yes | findings | 3 (low) | confirmed 0 blocking; 1 → non-blocking Delivery Finding, 2 dismissed |
| 7 | reviewer-security | Yes | clean | 1 (low, pre-existing/out-of-scope) | dismissed 1 (pre-existing, dev-config) |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | clean | 0 violations (13 checks + SOUL #2/#10) | N/A |

**All received:** Yes (5 enabled returned, 4 disabled pre-filled)
**Total findings:** 0 confirmed blocking, 3 dismissed (with rationale), 1 deferred to non-blocking Delivery Finding

## Reviewer Assessment

**Verdict:** APPROVED

A textbook SOUL #2 consolidation refactor: two divergent inline epic-ref formulas (`str(epic.get("jira") or epic.get("id") or "").strip()`) at `story_finish.py::_resolve_epic_ref` and `archive_epic.py::backfill_epic_refs` now delegate to the single canonical `_get_epic_ref`. Minimal (2 lines + 1 import), correct, fully consolidated, and rigorously tested. No Critical/High findings.

### Observations (tagged by source)

1. `[VERIFIED]` **Consolidation is complete.** My own grep for `epic.get("jira") or epic.get("id")` across `sprint/` returns nothing in live code (only the new test's docstring). `[RULE]` corroborates: `_get_epic_ref` is now the sole resolver — story_finish.py:66, archive_epic.py:332 (new) + :476 (pre-existing), epic_add/epic_update/yaml_io. Evidence: grep empty; SOUL #2 satisfied.
2. `[VERIFIED]` **Control flow preserved.** The truthiness guards `if ref:` (story_finish.py:64) and `if not epic_ref: continue` (archive_epic.py:333) still hold — `_get_epic_ref` returns `""` only for an id-less epic, matching the old formula's falsy result for the resolvable cases. Evidence: yaml_io.py:332 `return stripped or epic_id`.
3. `[RULE]` `[VERIFIED]` **Import hygiene clean.** story_finish.py:35 adds `_get_epic_ref` (used at :66); archive_epic.py:16 already imported it (no duplicate); `re` remains used (SESSION_FIELD_RE, story_finish.py:37) — no dead import. Confirmed by rule-checker check #10 and my own inspection.
4. `[TEST]` `[VERIFIED]` **Tests are robust, not vacuous.** test-analyzer empirically reverted the delegation → 8/11 correctly RED (matches the documented split); then injected a no-op `_get_epic_ref` call while keeping the old formula → the behavioral tests (`test_*_matches_canonical`, `test_all_three_resolvers_agree`) still failed, proving the AST structural test can't be gamed in isolation. Fixtures isolate via explicit `project_root` + `tmp_path`.
5. `[TYPE]` **[LOW, non-blocking]** `_get_epic_ref` does not `.strip()` its return (the old inline formula did). A whitespace-only id could pass the truthy guard. Pre-existing property of the *untouched* canonical function; YAML strips unquoted scalars, so this needs pathological quoted config. The story deliberately adopts canonical behavior → captured as a non-blocking Delivery Finding for a defense-in-depth follow-up on `_get_epic_ref` (affects all callers), not a 155-8 blocker.
6. `[TYPE]` **[LOW, dismissed]** `id: 0` (int zero) now resolves to `"0"` vs old `""`. Dismissed: integer epic id `0` is not a real schema value (ids are `{epic}-{seq}` / numeric-string), and resolving a real epic 0 to `"0"` is arguably more correct than silently dropping it. Pre-existing canonical behavior.
7. `[SEC]` **[LOW, dismissed]** `_get_epic_ref`'s fallback returns a raw `id` that flows into a filename (`sprint-{ref}-completed.yaml`); no traversal sanitization. Dismissed for this story: identical to the old formula and the 3 pre-existing `_get_epic_ref` call sites the diff didn't touch; source is developer-authored sprint YAML, not untrusted input. If anything the new JIRA-pattern gate makes the `jira`-derived segment *more* constrained. Pre-existing, out of scope.
8. `[TYPE]` **[LOW, dismissed]** Bare `Mapping` (not `Mapping[str, Any]`) on `_get_epic_ref`. Pre-existing, cosmetic, out of scope for this diff.
9. `[EDGE]` `[SILENT]` `[DOC]` `[SIMPLE]` — N/A (subagents disabled via `workflow.reviewer_subagents` settings). I independently checked: no new swallowed errors (no try/except in diff), no stale comments (the two added comments accurately describe the delegation), no over-engineering (this is a *simplification*).

### Rule Compliance

Mapped to `.pennyfarthing/gates/lang-review/python.md` for the changed lines:

| Rule | Applies? | Verdict |
|------|----------|---------|
| #1 Silent exception swallow | No — no try/except in diff hunks (pre-existing `except (FileNotFoundError, ValueError)` at story_finish.py:57 is unchanged context) | Compliant |
| #3 Type annotations at boundaries | Yes — new test helpers all annotated (`-> None/bool/Any`); `Any` on private helpers is exempt | Compliant |
| #5 Path handling | Yes (test) — `Path` throughout, `read_text(encoding="utf-8")` | Compliant |
| #6 Test quality | Yes — no vacuous asserts, every test asserts a concrete value, no skips, params exercise distinct paths (verified by rule-checker + test-analyzer) | Compliant |
| #10 Import hygiene | Yes — new import used, no dup, no dead import | Compliant |
| SOUL #2 One Truth | Yes (core intent) — no third copy remains | Compliant |
| SOUL #10 Return Results | Yes — `_resolve_epic_ref` returns `""` on failure, `backfill_epic_refs` returns result dict; both contracts preserved | Compliant |

### Data flow traced

`epic` dict (from `read_sprint`/`load_sprint` over developer-authored `current-sprint.yaml`) → `_get_epic_ref(epic)` → epic ref string → written as the `epic:` field of a completed-story archive row **and** (elsewhere, line 476) the `epic-{ref}.yaml` shard filename. Safe because: the ref is derived identically at every site now (the whole point), source is local dev config not untrusted input, and the JIRA-pattern gate constrains the `jira`-derived path segment more tightly than before.

### Devil's Advocate

Let me argue this code is broken. The sharpest attack: the refactor silently changes behavior for degenerate epics. Consider an id-less sentinel-jira epic `{"jira": "none"}` with no `id`. The old formula returned `str("none" or "" or "")` = `"none"` — a truthy, garbage ref that flowed straight into a filename `sprint-none-completed.yaml`. The new `_get_epic_ref` returns `""` (sentinel fails JIRA_PATTERN, empty id → empty), so `_resolve_epic_ref` now falls through to the explicit `jira_epic`/`epic` fallback and, failing that, the fail-loud empty result; `backfill_epic_refs` now `continue`s and marks the story irrecoverable. That IS a behavior change — but it is precisely the *intended* correction: `"none"` was the exact garbage this epic exists to eliminate. A confused user who previously saw a `sprint-none-completed.yaml` will now instead see the story correctly reported as irrecoverable (backfill) or trigger the explicit fail-loud error (finish) — strictly better, and consistent with gh #16's "never fabricate an epic" mandate. Second attack: could historical archive rows written with the OLD `epic-94`/`none` values now mismatch new `94` values, corrupting grouping? No — `backfill_epic_refs` only rewrites rows whose `epic` is *empty*, and the shard filename path already used canonical `_get_epic_ref` (line 476), so aligning the `id_to_epic` map to canonical *removes* a latent mismatch rather than creating one; the full finish/archive regression batch (87 passed / 1 skipped) confirms no existing behavior broke. Third attack: whitespace/zero-id edge cases (the TYPE findings) — real but pathological, pre-existing in the canonical function, and gated behind quoted-YAML config that the parser strips anyway. No attack lands as a blocker. The change is safe.

### Verdict rationale

No Critical or High findings. All low-confidence notes are pre-existing properties of the untouched canonical `_get_epic_ref`, deliberately adopted by delegation. Tests adversarially verified. Consolidation complete. **APPROVED** — handoff to SM for finish.

**Handoff:** To SM (Lieutenant Faceman) for finish-story.

## Delivery Findings

<!-- Append findings below. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): `story_finish.py` imports only `read_sprint` from `yaml_io`; the GREEN delegation needs `_get_epic_ref` added to that import. Affects `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` (add `_get_epic_ref` to the `from pf.sprint.yaml_io import ...` line). `archive_epic.py` already imports it, so only this one site needs the import edit. *Found by TEA during test design.*
- **Improvement** (non-blocking): the context/SM line reference `story_finish.py:59` points at the docstring; the actual divergent `or` formula is at ~line 63. `archive_epic.py:330` is exact. Affects `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` (Dev should edit the formula line, not line 59). *Found by TEA during test design.*

### Dev (implementation)
- Both TEA findings confirmed and resolved during GREEN (added the `_get_epic_ref` import to `story_finish.py`; edited the formula at the actual line, not line 59). No new upstream findings — the two divergent sites were the complete scope; no third copy of the epic-ref formula exists elsewhere (grep confirms `_get_epic_ref` is now the only resolver). *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): the canonical `_get_epic_ref` does not `.strip()` its return and coerces `id: 0` (int) to `"0"`; a defense-in-depth follow-up could add `.strip()` + explicit empty/zero handling so a whitespace-only or zero id can't pass callers' truthy guards or land in a filename. Affects `pennyfarthing/pennyfarthing-dist/src/pf/sprint/yaml_io.py` (`_get_epic_ref`, ~line 312 — a shared change touching all 5 call sites, hence deferred, not folded into 155-8). Also low-sev: the fallback returns a raw `id` into filename construction with no traversal sanitization (dev-authored config, pre-existing). *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 1 findings (0 Gap, 0 Conflict, 0 Question, 1 Improvement)
**Blocking:** None

- **Improvement:** the context/SM line reference `story_finish.py:59` points at the docstring; the actual divergent `or` formula is at ~line 63. `archive_epic.py:330` is exact. Affects `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py`.

### Downstream Effects

- **`pennyfarthing/pennyfarthing-dist/src/pf/sprint`** — 1 finding

### Deviation Justifications

2 deviations

- **Added AST structural delegation tests beyond behavioral equality**
  - Rationale: behavioral tests alone pass if Dev re-derives the same value inline — a third copy of the formula, the exact anti-pattern this story exists to remove (SOUL #2). The AST test enforces true consolidation.
  - Severity: minor
  - Forward impact: none — Dev satisfies both by a one-line delegation at each site
- **Three intentionally green-on-arrival guard tests**
  - Rationale: the oracle anchor protects the resolver the behavioral tests depend on; the preservation cases guard against the delegation over-applying and breaking the common real-jira path. Per `ac-as-green-regression-guard`, intentional green — not spurious.
  - Severity: minor
  - Forward impact: none — they stay green through the fix; a red here means the fix over-reached

## Design Deviations

### TEA (test design)
- **Added AST structural delegation tests beyond behavioral equality**
  - Spec source: context-story-155-8.md, AC "both resolvers call `_get_epic_ref`"
  - Spec text: "both resolvers call _get_epic_ref; regression test pins ... resolve identically"
  - Implementation: alongside behavioral `== _get_epic_ref(epic)` tests, added two `ast`-based tests asserting each function body literally calls `_get_epic_ref` (not just produces an equal value)
  - Rationale: behavioral tests alone pass if Dev re-derives the same value inline — a third copy of the formula, the exact anti-pattern this story exists to remove (SOUL #2). The AST test enforces true consolidation.
  - Severity: minor
  - Forward impact: none — Dev satisfies both by a one-line delegation at each site
- **Three intentionally green-on-arrival guard tests**
  - Spec source: context-story-155-8.md, ACs (all framed as regression pins)
  - Spec text: "regression test pins ... resolve identically across all three paths"
  - Implementation: `test_canonical_oracle_anchor` (pins `_get_epic_ref` literals) and `test_preserved_cases_unchanged_across_resolvers[real-jira, numeric-id]` pass on HEAD by design
  - Rationale: the oracle anchor protects the resolver the behavioral tests depend on; the preservation cases guard against the delegation over-applying and breaking the common real-jira path. Per `ac-as-green-regression-guard`, intentional green — not spurious.
  - Severity: minor
  - Forward impact: none — they stay green through the fix; a red here means the fix over-reached

### Dev (implementation)
- No deviations from spec. Implemented exactly per the ACs and TEA's test plan: delegated both call sites to `_get_epic_ref` via a real call (satisfying the AST structural tests), no inline re-derivation, no scope creep, guards preserved.

### Reviewer (audit)
- **TEA: Added AST structural delegation tests beyond behavioral equality** → ✓ ACCEPTED by Reviewer: sound and load-bearing for SOUL #2. test-analyzer empirically confirmed the AST test alone is name-only (could false-pass in isolation) but the paired behavioral tests catch a gamed no-op call — the combination correctly forbids a third inline copy.
- **TEA: Three intentionally green-on-arrival guard tests** → ✓ ACCEPTED by Reviewer: legitimate over-reach guards, verified non-vacuous (they fail if delegation is removed or `_get_epic_ref` regresses). Agrees with author reasoning.
- **Dev: No deviations from spec** → ✓ ACCEPTED by Reviewer: implementation matches the ACs and test plan exactly; diff is a clean 2-line delegation + 1 import.
- No undocumented deviations found. The one behavior change (id-less sentinel/`epic-`-prefixed epics now resolve to the canonical ref instead of the garbage `none`/`epic-94`) is the story's intended fix, not an unlogged divergence.