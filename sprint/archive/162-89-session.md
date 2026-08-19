---
story_id: "162-89"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-89: depends_on & story-tooling completion (162-79/162-13 review tails)

## Story Details
- **ID:** 162-89
- **Jira Key:** (none — YAML-only story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-89-depends-on-tooling-completion
- **PR:** (none yet — recorded when the PR is created)
- **Repos:** pennyfarthing

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-19T16:34:49Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-19T13:24:17Z | 2026-08-19T13:26:07Z | 1m 50s |
| red | 2026-08-19T13:26:07Z | 2026-08-19T13:36:13Z | 10m 6s |
| green | 2026-08-19T13:36:13Z | 2026-08-19T13:46:41Z | 10m 28s |
| review | 2026-08-19T13:46:41Z | 2026-08-19T16:26:54Z | 2h 40m |
| green | 2026-08-19T16:26:54Z | 2026-08-19T16:33:06Z | 6m 12s |
| review | 2026-08-19T16:33:06Z | 2026-08-19T16:34:49Z | 1m 43s |
| finish | 2026-08-19T16:34:49Z | - | - |

## Acceptance Criteria

This 5-point TDD consolidation folds eight granular epic-162 tails, all touching `pf sprint story_update.py` / `story_add.py` / `validator.py`:

1. **162-45 (stack-ready):** Multi-parent depends_on consumer support
   - Implement stack-ready gate at `pennyfarthing-dist/gates/stack-ready.md`
   - Emit machine-readable stack metadata
   - Unpin two boundary tests in `test_162_13_list_depends_on.py` (un-xfail/enable them)

2. **162-46 (validator/story_move polish):** Consolidate validator refactor
   - Rewrite int-entry as `str(entry)==old_id` for clarity
   - Unify container-check logic
   - Harden cycle-test coverage

3. **162-80 (update flag):** Add `--clear-depends-on` flag to `pf sprint story update`
   - Allow removal of dependency without hand-editing YAML
   - Parity with `--depends-on` workflow

4. **162-81 (transitive cycles):** Detect 2-hop depends_on cycles
   - Detect A→B, B→A patterns in `update_story`
   - Add cycle validation to shard validation route
   - Reject with clear error message

5. **162-82 (add target validation):** Validate `--depends-on` target in `story add`
   - Check target story exists
   - Guard against self-reference
   - Achieve parity with `story update`

6. **162-83 (terminal-state semantics - CLIENT DECISION):** Formalize depends_on semantics for terminal-state targets
   - **DONE (not yet archived)** → SATISFIED (aligns with archived per gh #90)
   - **ARCHIVED** → SATISFIED (existing behavior, gh #90)
   - **CANCELED** → WARNING (surface abandoned dependency; do NOT hard-fail merged-sprint validation)
   - Decision: record verbatim in `validator.py` lines 567+
   - Existing logic in `_get_archived_story_ids()` / `_normalize_depends_on()`

7. **162-84 (--type polish):** Complete 162-79 `--type` refinement
   - Scope comment parity across help text
   - Add word-boundary help test

8. **162-85 (optional hardening):** Harden VALID_STORY_TYPES/VALID_STORY_STATUSES
   - Convert to frozenset + Literal type hints
   - No behavioral change, optional

## Technical Approach

### Phase: RED (TEA)
- Write failing tests for each of the 8 acceptance criteria above
- Use `testing-runner` to validate test coverage
- Tests must cover:
  - CLI flag validation and error paths
  - Cycle detection logic (2-hop, transitive)
  - Terminal-state classification (DONE, ARCHIVED, CANCELED)
  - Target existence + self-ref guards in `story add`
  - Unpinned boundary tests from 162-13 must fail before implementation

### Phase: GREEN (Dev)
- Implement each AC against the failing test suite
- Key files touched: `story_add.py`, `story_update.py`, `validator.py`
- Emit stack-ready gate metadata machine-readably
- Ensure cycle detection rejects malformed depends_on chains
- Handle terminal-state classification per 162-83 decision

### Phase: Review (Reviewer)
- Validate all 8 AC have passing test coverage
- Confirm validator logic aligns with 162-83 decision
- Check cycle detection handles edge cases (self-ref, 2-hop, transitive)
- Verify gate machine-readability for stack-ready

## Delivery Findings

No upstream findings.

## Review Correlation

Cycle-1 rework correlates the internal Reviewer's findings against the Python lang-review checklist. No external or CI findings. No NEW_CHECK required — every finding maps to an existing checklist item or is a project-specific product/gate-design decision.

| # | Source | Finding | Classification | Checklist Check | Action |
|---|--------|---------|----------------|-----------------|--------|
| 1 | reviewer | B1 fail-open: gate consumer auto-passed on unknown story id | PROCESS | (silent-fallback class) | Fixed (found-flag, fail-closed). `silent_failure_hunter` is disabled here — had it run it may have flagged this; noted in Delivery Findings. |
| 2 | reviewer | B2 canceled parent blocked at merge gate (diverged from 162-83) | NOT_APPLICABLE | — | Project-specific product semantics; resolved by Client decision (warn, don't block). Fixed + tested. |
| 3 | reviewer | B3 dead `Literal` type hints (162-85 AC not load-bearing) | EXISTING_CHECK | #3 type annotations | Dev missed applying the Literals; now annotate `update_story`; drift-guard test added. |
| 4 | reviewer | S1 `VALID_SPRINT_STATUSES` left mutable | EXISTING_CHECK | #3 (immutability consistency) | Fixed → frozenset + test. |
| 5 | reviewer | S3 test-quality (tautology, weak exit-code assertions, missing state/coverage) | EXISTING_CHECK | #6 test quality | Fixed all four in the diff. |
| 6 | reviewer | D1 `--sprint-file` path traversal (CWE-22) | EXISTING_CHECK | #11 input validation | Deferred — pre-existing parity across 3 commands; follow-up story. |
| 7 | reviewer | D2 `open()` without `encoding=` in test fixtures | TOOLING | #5 path handling | Deferred — matches suite convention; follow-up to add via ruff config + suite-wide sweep. |

### Signal Summary
- **External findings: 0**
- **CI findings: 0**
- **Internal findings: 7** (3 blockers fixed, 2 should-fixes fixed, 2 deferred to follow-ups)
- **New checks added: 0** (all map to existing checks #3/#5/#6/#11 or are project-specific)

## Design Deviations

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- **Added `pf sprint story stack-ready` CLI + gate rewire beyond the pinned `evaluate_stack_ready` contract**
  - Spec source: .session/162-89-session.md, AC 162-45
  - Spec text: "Implement stack-ready gate at `pennyfarthing-dist/gates/stack-ready.md`; Emit machine-readable stack metadata"
  - Implementation: TEA pinned only the Python consumer `evaluate_stack_ready`. To fulfil the gate half of the AC (and avoid an orphaned/deletable consumer — the 162-18 unpinned-code lesson), I added a thin `pf sprint story stack-ready [--json] [--sprint-file]` command over the consumer, rewired `gates/stack-ready.md` to call it, and added two CLI-wiring regression tests (`TestStackReadyCliWiring`).
  - Rationale: The consumer is only real end-to-end if the gate consumes it; a thin, tested CLI wrapper is the minimal way to wire markdown-shell gate → Python logic without orphaning code.
  - Severity: minor
  - Forward impact: none
- **`stack_ready.py` imports validator private helpers (`_get_archived_story_ids`, `_iter_all_stories`, `_normalize_depends_on`)**
  - Spec source: SOUL.md, Rule 2 (One Truth, One Place)
  - Spec text: "Every definition lives in exactly one location; everything else is a symlink, an import, or a bug."
  - Implementation: Reused the validator's existing scalar/list normalizer, all-stories iterator, and archived-id resolver instead of re-implementing them in the new module.
  - Rationale: One-truth reuse keeps stack-ready's depends_on parsing and archived-satisfied semantics byte-identical to the validator's, so the two can't drift.
  - Severity: minor
  - Forward impact: none

## SM Assessment

Setup complete for 162-89 (5pt p2 tdd consolidation punchlist, pennyfarthing repo, YAML-only — no Jira). Branch `feat/162-89-depends-on-tooling-completion` cut off `develop`. Merge gate clear (no open PRs in either repo). Context doc and session written with all eight epic-162 tails folded as ACs, plus the Client's 162-83 ruling recorded verbatim (DONE→satisfied, ARCHIVED→satisfied, CANCELED→WARNING).

**Note for TEA:** this is a large 5-item behavioral punchlist plus two low-risk polish items (162-84, 162-85). AC 162-45 requires *unpinning* the two boundary tests in `test_162_13_list_depends_on.py` — those become part of the RED baseline. All ACs are honest RED (net-new behavior or currently-pinned/xfail'd) except possibly 162-85 (optional, no-behavior-change hardening) — state green-on-arrival explicitly if 162-85's assertions already pass, so the `tests-fail` gate reads on the true-RED ACs.

Routing to TEA for RED phase.

## TEA Assessment

**RED verified: 19 failed, 41 passed** (testing-runner RUN_ID `162-89-tea-red`). Two files:
- NEW `pennyfarthing-dist/src/pf/tests/test_162_89_depends_on_tooling_completion.py` — one class per folded tail.
- MODIFIED `test_162_13_list_depends_on.py` — unpinned the two scalar-only stack-ready boundary tests (162-45): `TestStackReadyGateConsumerIsScalarOnly` → `TestStackReadyConsumerResolvesMultiParent`; the limitation pin is now a positive multi-parent assertion.

Commit: `715e20f48` on `feat/162-89-depends-on-tooling-completion`.

### Honest-RED classification (green-on-arrival stated up front — 162-87/88 discipline)

**TRUE RED — Dev must make these pass:**
| AC | RED tests | What's missing on develop |
|----|-----------|---------------------------|
| 162-45 | 6 (new) + 1 (162-13) | `pf.sprint.stack_ready` module does not exist |
| 162-80 | 4 | `--clear-depends-on` flag + `clear_depends_on` kwarg absent |
| 162-81 | 3 | `validate_epic_shard` never calls `_validate_depends_on` |
| 162-82 | 2 | `add_story` lacks explicit self-ref / target-exists guards with update's message shape |
| 162-83 | 1 | canceled target emits no WARNING |
| 162-85 | 2 | `VALID_STORY_TYPES` / `VALID_STORY_STATUSES` are `set`, not `frozenset` |

**GREEN-ON-ARRIVAL — passed at RED, pinned as regression guards (do NOT read as vacuous):**
- **162-46** — the int-entry rewrite `str(entry)==old_id` is *defensive*: real story ids are dashed ("162-1"), so no int stringify-matches an `old_id`; `entry == old_id` already behaves correctly for every reachable input. `TestMoveRewritesDependenciesPin` (2 tests) pins the rewrite so the refactor can't regress it. Container-check unify + cycle-test hardening are behavior-preserving; no honest RED exists — do NOT fabricate one.
- **162-84** — `TestTypeHelpWordBoundary` passes now (help already lists every type as a whole word). Scope-comment parity is comment-only (no behavioral test).
- **162-83 done/archived** — `test_done_target_is_satisfied...` + `test_archived_target_is_satisfied` pin the SATISFIED half of the Client decision (already true); only the CANCELED→WARNING half is RED.

### Interface Dev must build (test contracts)

1. **`pf.sprint.stack_ready.evaluate_stack_ready(sprint_data: dict, story_id: str) -> dict`** (new module). Machine-readable verdict resolving scalar OR list `depends_on`:
   ```
   {"story_id", "ready": bool, "is_root": bool,
    "parents": [{"id", "status", "satisfied": bool}, ...],
    "blocking": [ids not satisfied]}
   ```
   A parent is `satisfied` when its status is `done` OR it resolves to an archived/completed story (gh #90). Root (no depends_on) → `ready=True, is_root=True, parents=[]`. Wire the `stack-ready.md` gate to emit/consume this (replaces the scalar shell capture). Archived resolution must honor `get_project_root` (see `_get_archived_story_ids`).
2. **`--clear-depends-on`** on `story update` + `clear_depends_on: bool` kwarg on `update_story` → deletes the `depends_on` KEY (not blank). Idempotent no-op when absent. Reject `--clear-depends-on` + `--depends-on` together (no silent drop).
3. **Shard-route depends_on validation** — `validate_epic_shard` must run cycle + dangling detection over the shard's stories (reuse `_normalize_depends_on` / `_report_dependency_cycles` on the shard's own id set). Error wording contains "circular" / names the dangling ref, matching the full-sprint path.
4. **`add_story` parity guards** — reject BEFORE insert: self-ref → error contains "itself"; dangling target → error contains "does not resolve to a known story" (verbatim parity with `update_story`).
5. **CANCELED→WARNING** in `_validate_depends_on` — when a resolved target's status is `canceled`, `result.add_error(..., severity=ValidationSeverity.WARNING)` naming the target and "cancel". Must NOT set `valid=False`. done/archived unchanged (satisfied, silent).
6. **frozenset+Literal** — `VALID_STORY_TYPES` / `VALID_STORY_STATUSES` become `frozenset`; pair with `Literal[...]` type aliases where these gate annotated params (type-checker concern; runtime test pins only the frozenset).

### Rule Coverage (`.pennyfarthing/gates/lang-review/python.md`)
- **#3 Type annotations at boundaries** — the new `evaluate_stack_ready` is a public boundary; its RED tests pin the return contract. 162-85's `Literal` typing targets this rule directly.
- **#6 Test quality** — every test asserts a specific value/shape; no `assert True`/bare-truthy. Green-on-arrival pins are explicitly labeled so they aren't read as vacuous. No skips.
- **#11 Input validation at CLI boundaries** — 162-82 (add-time target/self-ref guards) and 162-80 (mutual-exclusion of clear/set) are boundary-validation pins.
- Remaining checks (#1 silent-except, #2 mutable-default, #5 path, #7 resource, #8 deserialization, #9 async) — N/A to this diff (pure YAML/dict logic, no I/O beyond existing `read_sprint`/`write_sprint`, no new exception handling or async).

### Notes for Reviewer
- The 7 `stack_ready` failures are `ModuleNotFoundError`, not collection errors — imports are method-local by design so the suite collects and the other ACs' RED is observable. Correct RED for a net-new module.
- Pre-existing unrelated suite failure (`test_162_83_toctou_decision`, per SM sidecar) is NOT in scope and NOT touched — that `test_162_83_*` file is a different renumbered story, unrelated to punchlist item 162-83.

Routing to Dev (GREEN).

## Dev Assessment

**GREEN verified: 62/62 story tests pass, 567 passed in the regression sweep, 0 failures, ruff clean** (testing-runner RUN_ID `162-89-dev-green-2`).

Commits on `feat/162-89-depends-on-tooling-completion` (pushed):
- `715e20f48` (test, TEA) — RED suite.
- `bcfafe381` (feat, Dev) — implementation.

### What each behavioral AC's fix looks like
| AC | Change | File(s) |
|----|--------|---------|
| 162-45 | New `evaluate_stack_ready(sprint_data, story_id)` → machine-readable per-parent verdict (scalar OR list, archived-aware). New `pf sprint story stack-ready` CLI; `stack-ready.md` gate rewired to consume it. | `sprint/stack_ready.py` (new), `sprint/cli.py`, `gates/stack-ready.md` |
| 162-80 | `--clear-depends-on` flag + `clear_depends_on` kwarg; deletes the key; mutually exclusive with `--depends-on` and part of the `--epic` conflict set. | `sprint/story_update.py` |
| 162-81 | `validate_epic_shard` now runs `_validate_depends_on` over the shard's own id set (wrapped as a single-epic pseudo-sprint) — cycles + dangling caught on the shard route. | `sprint/validator.py` |
| 162-82 | `add_story` self-ref + target-existence guards, rejected BEFORE insert, verbatim message parity with `update_story`. | `sprint/story_add.py` |
| 162-83 | `_validate_depends_on` emits a `ValidationSeverity.WARNING` (non-blocking) when a resolved target's status is `canceled`; done/archived stay satisfied+silent. | `sprint/validator.py` |
| 162-85 | `VALID_STORY_TYPES` / `VALID_STORY_STATUSES` → `frozenset` + paired `StoryType` / `StoryStatus` `Literal` aliases. | `sprint/validator.py` |
| 162-46 / 162-84 | Green-on-arrival per TEA — no source change needed; pinned by regression tests. | — |

### Bug found and fixed during GREEN (transparency for Reviewer)
First GREEN run had 3 failures: `evaluate_stack_ready` consulted the archive fallback for an **active, non-done** parent, and `_get_archived_story_ids()` reads the **real on-disk** archive — so a synthetic active id (`162-1`) false-matched a real archived story of the same id and reported `ready=True`. Fixed by mirroring the validator's own resolution order: an active story's status is authoritative (satisfied iff `done`); the archive is consulted **only** for refs absent from the active sprint. Re-verified clean.

### Downstream effects
- New public surface: `pf sprint story stack-ready` and `pf.sprint.stack_ready.evaluate_stack_ready`. Gate `stack-ready.md` now depends on the CLI command — any future rename must update both.
- `VALID_STORY_TYPES`/`VALID_STORY_STATUSES` are now `frozenset`; any caller that mutated them (none found in-repo) would now fail — that's the intended hardening.
- The canceled→WARNING path adds warnings to merged-sprint validation results; consumers that count `result.errors` should filter by severity (existing code keys `valid` off ERROR-severity only, so no behavior change).

Routing to Reviewer.

## Dev Assessment (Rework — Cycle 1)

Addressed Colonel Decker's REJECTED verdict. Commit `29dafa183` on `feat/162-89-depends-on-tooling-completion` (pushed, signed). **70 story tests green (+8), 575 regression, ruff clean.**

**Blockers fixed:**
- **B1 (fail-open):** `evaluate_stack_ready` now returns a `found` field; an unknown story id → `found: False, ready: False` (no silent gate auto-pass). CLI prints "Not found" + exits 1. Tests: `test_unknown_story_is_not_ready_and_flagged`, `test_root_verdict_reports_found_true`, `test_cli_unknown_story_exits_nonzero`.
- **B2 (canceled gate, Client decision):** a canceled parent → `satisfied: True` + a `warnings[]` note; does NOT block. Mirrors 162-83 across the gate and `validate_full_sprint`. Tests: `test_canceled_parent_warns_but_does_not_block`, `test_shard_route_canceled_dep_warns_not_errors`.
- **B3 (dead Literals):** `StoryStatus`/`StoryType` now annotate `update_story(status=, story_type=)` (load-bearing), plus drift-guard tests `set(get_args(Literal)) == frozenset`.

**Should-fixes folded in:** S1 `VALID_SPRINT_STATUSES` → frozenset (+ test); S2 `StackReadyVerdict`/`ParentVerdict` TypedDicts; S3 test-quality (removed tautological `str(value)` assert, pinned the clear/set mutual-exclusion message, added state assertion to the idempotent-clear test, added shard-route canceled-WARNING test); S4 `story_stack_ready -> None`.

**Deferred to follow-ups (report-not-block):** D1 `--sprint-file` path traversal (pre-existing parity across `stack-ready`/`update`/`add`); D2 `open()` `encoding=` (suite convention — needs a suite-wide sweep, not a spot-fix); D3 `_resolve_depends_on` diagnostic discard (low, documented). These belong in new stories, not this diff.

Routing back to Reviewer for cycle-1 re-review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | confirmed 0, dismissed 0, deferred 0 (567 pass, ruff clean, tree clean) |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | N/A — covered first-hand [EDGE] |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | N/A — covered first-hand [SILENT] |
| 4 | reviewer-test-analyzer | Yes | findings | 6 | confirmed 5, dismissed 0, deferred 1 |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | N/A — covered first-hand [DOC] |
| 6 | reviewer-type-design | Yes | findings | 6 | confirmed 5, dismissed 0, deferred 1 |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 1, dismissed 0, deferred 1 (path-traversal = pre-existing parity) |
| 8 | reviewer-simplifier | No | Skipped | disabled | N/A — covered first-hand [SIMPLE] |
| 9 | reviewer-rule-checker | Yes | findings | 10 | confirmed 1, dismissed 0, deferred 9 (encoding = suite convention) |

**All received:** Yes

**Working-tree audit:** `pf reviewer audit-tree` reported DIRTY on the untracked orchestrator artifact `sprint/context/context-story-162-89.md` (sm-setup's context doc) — the KNOWN false positive (162-86/87/88 dp7). Reviewed repo `pennyfarthing/` verified clean via `git -C pennyfarthing status --porcelain` (empty). Did NOT run `git clean -fd`.

## Reviewer Assessment

**Verdict:** REJECTED

Adversarial review of the 162-89 diff (8 files, +1080/-51) against the 8-tail punchlist. Tests are green (567 pass) and ruff is clean, but three findings block approval — two are correctness/merge-safety on the new `evaluate_stack_ready` gate consumer, and one is AC-fidelity on 162-85. Specialist findings incorporated: [TEST] test-analyzer (canceled-gate divergence, fail-open untested, 4 test-quality gaps); [TYPE] type-design (dead Literals, drift, TypedDict, fail-open conflation, mutable sprint-status set); [SEC] security (fail-open merge-gate bypass, --sprint-file path parity); [RULE] rule-checker (encoding convention, missing return annotation). Disabled specialists covered first-hand: [EDGE] the shard-route now depends on real on-disk archive state (consistent with `validate_full_sprint`, acceptable); [SILENT] `_resolve_depends_on` discards `_normalize_depends_on` diagnostics (low, documented); [DOC] docstrings and the rewired `stack-ready.md` gate are accurate and current — no stale comments; [SIMPLE] `status_by_id` is built twice in `evaluate_stack_ready` (trivial, not worth churn).

### BLOCKERS — must fix before approval

**B1. `evaluate_stack_ready` fail-open on an unknown story id is a silent merge-gate bypass.** [SEC][TYPE][TEST — triple-corroborated]
`stack_ready.py` returns `{ready: True, is_root: True, parents: [], blocking: []}` when `story_id` matches no active story. The stack-ready gate consumes this to allow a PR merge, so a stale/typo'd/renumbered id (a real scenario — epic renumbers cause id collisions) makes the entire dependency chain silently skip and the gate auto-pass. Fail-open conflates "true root (no depends_on)" with "story not found."
*Fix:* distinguish the two — add a `found: bool` to the verdict; when the story is not found, return `found: False` and do NOT report `ready: True` unconditionally (let the gate treat not-found as block-or-warn, not silent pass). Add a test pinning the not-found path.

**B2. `evaluate_stack_ready` blocks on a canceled parent, silently diverging from the Client's 162-83 decision — undocumented and untested.** [TEST]
The gate marks a parent satisfied only if `status == "done"`, so a story whose only parent was canceled is permanently blocked at stack-ready. The validator (per the Client's 162-83 ruling) treats canceled as a non-blocking WARNING. The two subsystems now disagree with no test and no comment. *Note:* blocking-on-canceled at a **merge-ordering** gate is defensible (a canceled parent never lands, so merging the child may drop its base) — but that is a deliberate, Client-adjacent choice that must be explicit, not implicit.
**CLIENT DECISION (resolved during review):** mirror 162-83 at the merge gate — a canceled parent must NOT block. *Fix:* in `evaluate_stack_ready`, treat a canceled parent as `satisfied: True` with a warning marker in its parent-verdict entry (e.g. a `warning` field or a top-level `warnings` list), so `ready` stays `True` and the abandoned dep is surfaced, not enforced. Add a test: canceled parent → `ready is True` AND the verdict surfaces the canceled warning. Keep the validator's canceled→WARNING behavior as-is (now consistent across both surfaces).

**B3. 162-85's `Literal` half is decorative — the AC asked for "Literal type hints" but the Literals annotate nothing.** [TYPE — high, ×2]
`StoryType` / `StoryStatus` are defined but never used in any signature; `update_story(status=..., story_type=...)` remain `str | None`, so a type checker cannot catch an out-of-set value at any call site. And the Literal ↔ frozenset value lists are two hand-maintained copies with only a "keep in sync" comment — silent drift risk. As delivered, the Literal hardening is the worst of both worlds (maintenance cost, zero enforcement). Same type-honesty class this project rejected on in 162-87.
*Fix:* make the Literals load-bearing — annotate `update_story`'s `status: StoryStatus | None` and `story_type: StoryType | None` (and `add_story` where applicable) — AND add a drift-guard test: `set(get_args(StoryStatus)) == VALID_STORY_STATUSES` (same for `StoryType`).

### SHOULD FIX — fold into the rework (cheap, in-scope)
- **S1.** `VALID_SPRINT_STATUSES` left as a mutable `set` while 162-85 froze the two story sets — same module, same hardening goal. Make it `frozenset`. [TYPE]
- **S2.** Give `evaluate_stack_ready` a `StackReadyVerdict` TypedDict (with `ParentVerdict`) so the machine-readable contract has a static shape — this also makes B1's `found` field robust. [TYPE]
- **S3. Test-quality** (lang-review #6): (a) remove the now-tautological `assert str(value) == "162-1"` in `test_162_13` (unpin left it meaningless); (b) `test_clear_and_set_together_is_rejected` asserts only `exit_code != 0` — assert the "cannot be combined" message so it pins the mutual-exclusion branch; (c) `test_clear_is_idempotent_on_story_without_dep` asserts only `exit_code == 0` — read back the YAML and assert `depends_on` absent (a `depends_on: null` write would pass today); (d) add a shard-route canceled-WARNING test to `TestShardRouteCycleDetection`. [TEST]
- **S4.** `story_stack_ready` missing `-> None` return annotation. [RULE #3]

### DEFER — follow-up stories (report-not-block)
- **D1.** `--sprint-file` path traversal (CWE-22): no `resolve_path`/containment on `stack-ready`, `story update`, `story add`. Security confirmed this is **pre-existing parity across all three commands — no regression from 162-89**. File a follow-up to add `resolve_path=True` (+ project-root containment) to all three together. [SEC]
- **D2.** 9× `open(..., "w")` without `encoding=` in the new test fixtures (rule #5). This matches established suite convention (sibling test files use 0/4 with `encoding=`). Spot-fixing only this file would be inconsistent — file a suite-wide follow-up. [RULE #5]
- **D3.** `_resolve_depends_on` discards `_normalize_depends_on` diagnostics — low, documented; only bites if a malformed depends_on reaches the gate. [SILENT]

### Reviewer Question for Client / SM (B2) — RESOLVED
Asked the Client during review whether the stack-ready **merge gate** should block on a canceled parent (as implemented) or mirror the 162-83 validation ruling. **Client chose: mirror 162-83 — canceled parent warns but does NOT block the merge.** B2 fix instruction updated accordingly; canceled semantics are now consistent across the validator and the stack-ready gate.

Round-trip: rework routes to Dev (green). The blockers are focused; the SHOULD items are cheap and in-scope; the DEFER items are pre-existing/convention and belong in follow-ups.

## Subagent Results
**Cycle: 1**

Cycle-1 used TARGETED re-verification (re-read the changed code + independently re-ran the blocker-closing tests), not a fresh subagent sweep — the cycle-0 sweep already covered the full diff and the rework is scoped to the three blockers + should-fixes.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | (cycle-0, re-verified) tests 70 story/575 regression green, ruff clean |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | N/A — covered first-hand [EDGE] |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | N/A — covered first-hand [SILENT]; B1 fail-open now fail-closed |
| 4 | reviewer-test-analyzer | Yes | findings | 0 open | (cycle-0, re-verified) all 6 findings resolved in rework |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | N/A — covered first-hand [DOC] |
| 6 | reviewer-type-design | Yes | findings | 0 open | (cycle-0, re-verified) Literals load-bearing, TypedDict added, found-flag added, VALID_SPRINT_STATUSES frozen |
| 7 | reviewer-security | Yes | findings | 1 deferred | (cycle-0, re-verified) fail-open fixed; path-traversal deferred (pre-existing parity) |
| 8 | reviewer-simplifier | No | Skipped | disabled | N/A — covered first-hand [SIMPLE] |
| 9 | reviewer-rule-checker | Yes | findings | 2 deferred | (cycle-0, re-verified) return-annotation fixed; encoding deferred (suite convention) |

**All received:** Yes

**Working-tree audit (cycle 1):** `pf reviewer audit-tree` again reported DIRTY only on the untracked orchestrator artifact `sprint/context/context-story-162-89.md` (the known false positive, 162-86/87/88 dp7). Reviewed repo `pennyfarthing/` verified clean via `git -C pennyfarthing status --porcelain` (empty). Did NOT run `git clean -fd`.

## Reviewer Assessment

**Verdict:** APPROVED

Cycle-1 re-review of commit `29dafa183`. All three cycle-0 blockers are resolved, verified by re-reading the fixes and independently re-running the blocker-closing tests (10/10 pass; full suite 70 story + 575 regression green, ruff clean). Specialist findings incorporated: [TEST] test-analyzer — fail-open now has an explicit `found`-flag test, canceled-parent behavior tested on both the consumer and shard routes, mutual-exclusion and idempotent-clear tests strengthened to assert message/state (not just exit code), tautological `str(value)` assertion removed; [TYPE] type-design — `StoryStatus`/`StoryType` Literals are now load-bearing (annotate `update_story`) with a `get_args == frozenset` drift-guard test, `StackReadyVerdict`/`ParentVerdict` TypedDicts define the machine-readable contract, `VALID_SPRINT_STATUSES` frozen for consistency, and the unknown-id/root conflation is resolved via `found`; [SEC] security — the fail-open merge-gate bypass is closed (unknown id → `found: False, ready: False`, gate no longer auto-passes); [RULE] rule-checker — `story_stack_ready` now annotated `-> None`. Disabled specialists re-covered first-hand: [EDGE] the found/root/blocking/warning branches of `evaluate_stack_ready` are each tested; [SILENT] the former fail-open silent-pass is eliminated; [DOC] docstrings and the `stack-ready.md` gate accurately describe the multi-parent + canceled-warn behavior; [SIMPLE] no over-engineering — the TypedDicts and `found` field are the minimal shape the contract needs.

**B1 (fail-open) — RESOLVED.** `evaluate_stack_ready` returns `found: False, ready: False` for an unresolvable id; the gate no longer silently auto-passes on a stale/typo'd story id. Verified: `stack_ready.py:99` + `test_unknown_story_is_not_ready_and_flagged` + `test_cli_unknown_story_exits_nonzero`.

**B2 (canceled gate divergence) — RESOLVED per Client decision.** A canceled parent is `satisfied: True` with a `warnings[]` note and does NOT block, mirroring the 162-83 validator semantics across both surfaces. Verified: `test_canceled_parent_warns_but_does_not_block` + `test_shard_route_canceled_dep_warns_not_errors`.

**B3 (dead Literals) — RESOLVED.** `update_story(status: StoryStatus | None, story_type: StoryType | None)` makes the Literals load-bearing, and `test_story_status_literal_matches_frozenset` / `test_story_type_literal_matches_frozenset` guard against drift. The 162-85 AC ("frozenset + Literal type hints") is now genuinely satisfied.

SHOULD-fixes S1/S2/S3/S4 all landed. DEFER items D1 (path-traversal, pre-existing parity), D2 (`encoding=`, suite convention), D3 (`_resolve_depends_on` diagnostics, low) are correctly out of scope — file follow-up stories. No new findings introduced by the rework. All 8 punchlist ACs are delivered and tested.

Round-Trip Count 1. Approving → SM for finish.