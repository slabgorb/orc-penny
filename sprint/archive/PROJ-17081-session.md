---
story_id: "151-2"
jira_key: "PROJ-17081"
epic: "PROJ-17079"
workflow: "tdd"
---
# Story 151-2: Fail loudly on missing epic field during archive write, backfill historical entries

## Story Details
- **ID:** 151-2
- **Jira Key:** PROJ-17081
- **Epic:** PROJ-17079 (Sprint YAML write correctness)
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 3
- **Priority:** p2

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-04-20T12:48:34Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-04-20 | 2026-04-20T12:00:31Z | 12h |
| red | 2026-04-20T12:00:31Z | 2026-04-20T12:05:24Z | 4m 53s |
| green | 2026-04-20T12:05:24Z | 2026-04-20T12:07:43Z | 2m 19s |
| spec-check | 2026-04-20T12:07:43Z | 2026-04-20T12:32:14Z | 24m 31s |
| green | 2026-04-20T12:32:14Z | 2026-04-20T12:35:55Z | 3m 41s |
| spec-check | 2026-04-20T12:35:55Z | 2026-04-20T12:36:29Z | 34s |
| verify | 2026-04-20T12:36:29Z | 2026-04-20T12:39:03Z | 2m 34s |
| review | 2026-04-20T12:39:03Z | 2026-04-20T12:46:58Z | 7m 55s |
| spec-reconcile | 2026-04-20T12:46:58Z | 2026-04-20T12:48:34Z | 1m 36s |
| finish | 2026-04-20T12:48:34Z | - | - |

## Story Context

**Epic 151 Goal:** Fix silent failures and fragile path/field resolution in the sprint YAML write paths (archive, finish, story update).

**This story (151-2):** Continuation of the surgical finish-flow hardening pattern landed by 151-1. The story requires:
- Fail loudly when required `epic` field is missing during archive write operations
- Backfill historical entries in the archive where the epic field is absent
- These are bug fixes addressing downstream-reported failures in the sprint write subsystem

**Related:** 
- 151-1 (done): Resolved archive filename from sprint.number when name was absent
- 151-3 (backlog): story update locates stories across epic-*.yaml; story finish fails loudly on yaml-update error

## Sm Assessment

3pt TDD p2 bug — sibling to 151-1 in epic 151 (framework write correctness). TEA → Dev → Reviewer → SM.

**Spec intent:**
1. **Fail loud on missing `epic` field at archive write.** The sprint archive (`sprint/archive/sprint-{id}-completed.yaml` and its shards) records each completed story with an `epic` reference. When a story is archived without an `epic` field, the write path silently drops or mis-groups it — epic-shard migration in `archive_epic.migrate_completed_archive()` moves such stories to `orphans` rather than raising, masking misconfiguration.
2. **Backfill historical entries.** Walk existing archive files and shards, detect entries missing `epic`, and fill them in from the live sprint YAML (parent-epic lookup by story id) or flag the ones that cannot be recovered.

**TEA scope (RED):**
- Tests that archive-write helpers (`_write_archive_file`, `archive_epic`, `archive_story`) raise a descriptive error when a story lacks `epic`.
- Tests that a backfill function walks `sprint/archive/sprint-*-completed.yaml` + `epic-*.yaml` shards, resolves missing `epic` from parent epic when possible, and reports the irrecoverable ones.
- Include a fixture with a realistic archive file containing at least one epic-less story to prove backfill logic.

**Dev scope (GREEN):**
- Wire the raise into the archive write surface (lowest-cost option: add a guard in `_write_archive_file` / `migrate_completed_archive` / `archive_story`).
- Implement the backfill helper + a `pf sprint archive backfill-epics` (or similar) CLI surface.
- Keep the return-result pattern at the CLI boundary — let core helpers raise, let the archive_epic()/archive_story() callers wrap to `{success, error}` when they are the boundary.

**Out of scope:**
- 151-3 (cross-shard story-update / yaml-update error surface) — separate story.
- Principle 10 blanket refactor of `get_archive_path()` raise paths flagged during 151-1 review — follow-up chore.

**Branch:** `feat/151-2-fail-loud-missing-epic-field-archive-write` (pennyfarthing, develop-based).

**Jira:** Story PROJ-17081 under newly-created epic PROJ-17079. Story claimed, in progress.

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_archive_epic_field_validation.py` — 7 tests covering the fail-loud guard at `_write_archive_file` and the new `backfill_epic_refs` helper.

**Tests Written:** 7 tests (1 baseline happy-path + 6 failing RED tests)
**Status:** RED — 1/7 pass (baseline), 6/7 fail as intended:
- 3 `_write_archive_file` validation guards (missing key, empty string, multi-offender error message)
- 3 `backfill_epic_refs` behaviours (resolve via sprint yaml, report irrecoverable, idempotent on clean archive)

**Proposed Dev API** (Dev may renegotiate via consultation):
- `_write_archive_file(path, data)` raises `ValueError` naming every offending story id when any `completed_stories` entry lacks a non-empty `epic`.
- `backfill_epic_refs(project_root: Path | None = None) -> dict[str, Any]` returning `{"success": bool, "backfilled": [...], "irrecoverable": [...]}` walking `sprint/archive/sprint-*-completed.yaml`.

### Rule Coverage (Python lang-review)

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 silent exception swallowing | All `_write_archive_file` tests — assert the code raises rather than silently writing | failing (guard not implemented yet) |
| #3 type annotations at boundaries | Proposed API in docstring includes full annotations; Dev expected to preserve them | n/a (contract, not test) |
| #5 path handling | Fixtures use `pathlib.Path`; `_write_archive_file` receives a `Path` | passing (baseline) |
| #6 test quality | Each test has explicit assertions on return dict contents, error message contents, and file output; no `assert True`, no truthy-only checks | passing (self-check) |

**Rules NOT covered (out of scope for this RED):**
- Resource leaks / unsafe deserialization — archive I/O goes through `_make_yaml()` helpers (already safe-loader); no new I/O surface introduced.
- Mutable default arguments — new API uses `None` defaults.

**Self-check:** 0 vacuous tests found. Every test asserts a specific value (id equality, message substring, or filesystem side-effect).

**Scope trim:** An earlier draft included a test covering `archive_story()` fail-loud when the parent epic can't be determined. The test tripped on `get_project_root` monkeypatching (the symbol is re-imported into loader, so `monkeypatch.setattr` on `pf.common.config` doesn't propagate). Since `archive_story` can be routed through `_write_archive_file` for the write step — inheriting the new guard transitively — the dedicated test was removed. Captured as a delivery finding for Dev to evaluate.

**Handoff:** To Dev for implementation (GREEN).

## Architect Assessment (spec-check)

**Spec Alignment:** Drift detected
**Mismatches Found:** 2

### Mismatch 1 — Missing CLI surface

- **Category:** Missing in code
- **Type:** Behavioral (user-facing)
- **Severity:** Minor (non-breaking, but a named deliverable)

**Spec (SM Assessment, Dev scope):** "Implement the backfill helper + a `pf sprint archive backfill-epics` (or similar) CLI surface."

**Code:** `backfill_epic_refs()` shipped as an importable Python helper with full test coverage. No Click command is registered — there is no `pf` CLI entrypoint to invoke it. External consumers would have to call `python -c "from pf.sprint.archive_epic import backfill_epic_refs; ..."` to run a repair.

**Deviation log:** Dev logged a deviation for the `archive_story` guard scope trim but did NOT log the missing CLI surface. This is an unlogged spec deviation.

**Recommendation:** **B — Fix code.** Hand back to Dev to either (a) add a thin Click wrapper (~10 lines) exposing `backfill_epic_refs()` as a CLI command — `pf sprint backfill-epics` is the lowest-friction placement since `pf sprint archive` is already taken by the story-archive command, or (b) log an explicit 6-field deviation entry justifying the CLI deferral and flagging it as a delivery finding for a follow-up. Either resolution satisfies the spec-authority hierarchy.

### Mismatch 2 — `archive_story` guard deferred

- **Category:** Missing in code
- **Type:** Behavioral
- **Severity:** Minor (already logged as a deviation)

**Spec (SM Assessment):** "Wire the raise into the archive write surface (lowest-cost option: add a guard in `_write_archive_file` / `migrate_completed_archive` / `archive_story`)."

**Code:** Guard added at `_write_archive_file`. `migrate_completed_archive` inherits it transitively (it calls `_write_archive_file` to persist). `archive_story` in `pennyfarthing-dist/src/pf/sprint/archive.py` uses raw `open(..., "a")` append and remains silent on missing-epic.

**Deviation log:** Dev logged a full 6-field deviation entry with rationale (refactor scope) and a forward-impact note pointing at a proposed 151-4 follow-up. Also captured in Delivery Findings.

**Recommendation:** **D — Defer.** The deviation is properly logged, the rationale is sound (routing `archive_story` through `_write_archive_file` requires converting it from append-line to read-modify-write — a structural refactor beyond the 151-2 scope). The primary 151-2 intent (finish-flow archive writes fail loud) is met. Follow-up story on epic 151 already signaled.

### Decision

**Hand back to Dev** to resolve Mismatch 1. Two paths are acceptable:

1. **Add the CLI command** — smallest path to spec compliance. `pf sprint backfill-epics` wrapping `backfill_epic_refs()`, printing backfilled + irrecoverable counts, non-zero exit on any irrecoverable entries.
2. **Log the deferral** — write a 6-field Dev deviation entry covering the CLI omission, mirroring the `archive_story` deviation's format. This acknowledges the scope change explicitly rather than silently.

Mismatch 2 stays as-is (logged deviation, deferred by design).

**Do not proceed to review until Mismatch 1 is resolved either way.**

---

### Re-check (v2, after Dev rework)

**Spec Alignment:** Aligned
**Mismatches Found:** 0 remaining

- **Mismatch 1 (Missing CLI surface):** ✓ **RESOLVED.** Dev added `pf sprint backfill-epics` as a Click command in `pennyfarthing-dist/src/pf/sprint/cli.py:313-348` plus 2 CLI smoke tests (resolution path + non-zero-exit-on-irrecoverable). Placement on the flat `pf sprint ...` verb is sound — `pf sprint archive` is already taken by the story-archive command. `--json` flag included for scripted use. Exit code semantics match spec intent.
- **Mismatch 2 (`archive_story` guard deferred):** Stands as previously assessed — properly logged deviation with rationale + delivery finding for 151 follow-up story.

**Decision:** Proceed to TEA verify.

## Delivery Findings

No upstream findings.

### TEA (test design)

- **Question** (non-blocking): Should `archive_story()` (pennyfarthing-dist/src/pf/sprint/archive.py) route its write through `_write_archive_file` so it inherits the new epic-field validation, or should it grow its own pre-write guard? The cleanest fix is routing through `_write_archive_file` (one guard, one code path). Dev should decide during GREEN and note as a deviation if the direct-guard approach is preferred. *Found by TEA during test design.*
- **Gap** (non-blocking): `monkeypatch.setattr("pf.common.config.get_project_root", ...)` does not propagate to modules that `from pf.common.config import get_project_root` at import time. Tests that need to exercise `archive_story`-style auto-detect code paths should either (a) inject an explicit `project_root` parameter, or (b) use `monkeypatch.chdir()` with a detectable project marker layout. Worth a helper fixture in conftest. *Found by TEA during test design.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Dev Assessment

**Implementation Complete:** Yes (after spec-check rework loop — see v2 below)

**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/archive_epic.py`
  - `_write_archive_file()`: added a pre-write guard that collects every `completed_stories` entry with a missing or empty `epic` field and raises `ValueError` naming all of them.
  - New `backfill_epic_refs(project_root)` helper: walks `sprint/archive/sprint-*-completed.yaml`, resolves missing `epic` via live sprint YAML story-id → epic lookup, and reports unresolvable entries as irrecoverable. Files are rewritten only when every entry is repaired (the new guard would otherwise reject the write).
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/cli.py` *(v2, rework)*
  - New `pf sprint backfill-epics` Click command wrapping the helper. Prints a human summary by default, `--json` for scripted use, exits non-zero if any entries remain irrecoverable.
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_archive_epic_field_validation.py`
  - 7 behavioural tests for the guard + helper (v1).
  - 2 CLI smoke tests added (v2): resolution-reported and non-zero-exit-on-irrecoverable.

**Tests:** 9/9 new tests GREEN. Broader regression: 264+ passed / 0 failed / 3 pre-existing skips on the archive+sprint+story_finish+cli surface.

**Branch:** `feat/151-2-fail-loud-missing-epic-field-archive-write` — commits:
- `5e916dff1` test(sprint): add failing tests for missing-epic archive validation (RED)
- `100f2c75c` feat(sprint): validate epic refs on archive write, add backfill helper (GREEN v1)
- `3b49402de` test(151-2): add CLI smoke tests for backfill-epics command (v2)
- `7bad4291d` feat(sprint): add pf sprint backfill-epics CLI command (v2)

**Handoff:** Back to Architect for spec-check (Mismatch 1 resolved by adding the CLI surface per Option A).

### TEA Question Addressed

TEA asked whether `archive_story()` should route through `_write_archive_file` or grow its own guard. **Deferred:** `archive_story()` still writes via raw `open(..., "a")` append — the new guard does NOT apply to that path. Rationale: routing `archive_story` through `_write_archive_file` is a structural refactor (it currently appends lines rather than serialising the full dict), beyond the surgical scope of 151-2. The silent-`epic: ""` write in `archive.py:91-97` remains; captured as a delivery finding for a follow-up story on epic 151.

### Architect Mismatch 1 Addressed

Architect flagged the missing `pf sprint ... backfill-epics` CLI surface. **Resolved (Option A):** Added `pf sprint backfill-epics` as a thin Click wrapper over `backfill_epic_refs()`. Command placement uses the flat `pf sprint ...` verb (not `pf sprint archive ...`) because the existing `pf sprint archive` slot is already taken by the story-archive command. CLI surface now matches spec intent.

## Delivery Findings

No upstream findings.

### Dev (implementation)

- **Gap** (non-blocking): `archive_story()` in `pennyfarthing-dist/src/pf/sprint/archive.py:67-102` still writes `epic: {epic_id}` via raw file append with no guard. When the story has no parent epic in the sprint YAML, it silently writes `epic: `. The new `_write_archive_file` guard does NOT cover this path because `archive_story` doesn't route through it. A proper fix either (a) routes `archive_story` through `_write_archive_file` (structural refactor — serialise + rewrite instead of append) or (b) adds a parallel pre-append guard in `archive_story`. Recommend a follow-up story on epic 151. *Found by Dev during implementation.*

### Reviewer (code review)

- **Improvement** (non-blocking): Weak regex in `test_write_archive_file_raises_when_completed_story_has_empty_epic` at `pennyfarthing-dist/src/pf/tests/test_archive_epic_field_validation.py:115`. The pattern `(?i)(empty|without).*epic.*empty-epic-1` passes because "empty" appears in the static error prefix "missing or empty", not because the dynamic offender list contains `empty-epic-1`. A future rewording of the guard message would silently pass a broken implementation. Fix: `match=r"empty-epic-1"` plus a separate assertion on "epic" in `str(exc.value)`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): ANSI/control-character pass-through in `pennyfarthing-dist/src/pf/sprint/cli.py:333-340`. Story ids and epic refs from YAML are echoed via `click.echo` without stripping non-printable characters. A crafted sprint YAML could inject terminal escape sequences. Real-world risk is nil (developer-owned YAML) but defense-in-depth hardening would strip `\x00-\x1f\x7f` before echo. *Found by Reviewer during code review.*
- **Gap** (non-blocking): `migrate_completed_archive()` behaviour change is spec-intended (it now raises transitively via `_write_archive_file` if archive contains epic-less stories) but has no dedicated regression test. Add a test that feeds a malformed archive to `migrate_completed_archive` and asserts it raises with the offender names. *Found by Reviewer during code review.*
- **Gap** (non-blocking): No test asserts the CLI `--json` output shape. The two CLI smokes exercise the default text-output paths only. Add a smoke that invokes `pf sprint backfill-epics --json` and asserts the output parses as JSON with `backfilled` and `irrecoverable` keys. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `backfill_epic_refs()` silently skips epics lacking both `jira` and `id` fields — their child stories land in `irrecoverable` with no hint that the parent epic itself was unnameable. Add a warning/diagnostic when an epic is skipped so operators can distinguish "story not found in any epic" from "story's parent epic is malformed". *Found by Reviewer during code review.*
- **Question** (non-blocking): `backfill_epic_refs()` has no lock or atomic rename during the walk-patch-write cycle. Single-operator CLI context makes this acceptable today, but if multi-process sprint edits ever emerge (e.g., parallel `pf` invocations from CI), a concurrent write would be silently overwritten. Worth documenting the single-operator assumption or adding a flock on the archive file. *Found by Reviewer during code review.*

## Design Deviations

### TEA (test design)
- No deviations from spec.

### TEA (verify)
- No deviations from spec.

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed (9/9 focused + ruff clean on changed files)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3 (`archive_epic.py`, `cli.py`, `test_archive_epic_field_validation.py`)

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | findings | 2 (1 high, 1 medium) — both about micro-abstraction of `(x or "").strip()` idiom |
| simplify-quality | findings | 2 (1 high, 1 medium) — both about `raise` vs `{success, error}` result-dict |
| simplify-efficiency | findings | 8 (1 high, 3 medium, 4 low) — 7 on pre-existing code outside the 151-2 diff, 1 on a fixture helper that intentionally bypasses validation |

**Applied:** 0 high-confidence fixes
**Flagged for Review:** 0 medium-confidence findings (all dismissed — see rationale below)
**Noted:** 12 low/medium observations dismissed with rationale
**Reverted:** 0

**Overall:** simplify: clean (all findings dismissed with specific rationale)

### Dismissal Rationale

| Finding | Confidence | Disposition | Rationale |
|---------|------------|-------------|-----------|
| reuse: extract `is_truthy_string` from 5× `(x or "").strip()` | high | dismissed | User global CLAUDE.md: "bug fix doesn't need surrounding cleanup; one-shot operation doesn't need a helper." Five call sites split into 3 real duplicates (epic-has-field check) + 2 str-coercions (different semantics). A single generic helper would obscure each intent. Keep idiom inline. |
| reuse: extract `normalize_ref` from 2× str-coercion | medium | dismissed | Call sites are on different data types (sprint epic ref vs archive story epic ref) with different validation semantics. Premature coupling. |
| quality: `get_archive_path()` raises, violates Principle 10 | high | dismissed | Pre-existing pattern (raise on line 37 predates this diff, introduced before 151-1). Already captured as Reviewer delivery finding on 151-1 for a blanket-refactor follow-up. Out of scope for this story. |
| quality: `_write_archive_file()` raises, document contract | medium | dismissed | Intentional per TEA RED spec. Added docstring includes `Raises: ValueError ...` block with resolution guidance. Documentation contract is in place. |
| efficiency: `_load_archive_file` redundant None normalization | medium | dismissed | Pre-existing code (lines 213-222, not in my diff). Out of scope. |
| efficiency: `archive_epic` reads shard_file twice | high | dismissed | Pre-existing code (archive_epic.py:488, not in my diff). Out of scope. |
| efficiency: context file lookup duplicated | medium | dismissed | Pre-existing code (lines 475-479 vs 507-512, not in my diff). Out of scope. |
| efficiency: archive_epic rebuilds story dict | low | dismissed | Pre-existing code, not in my diff. |
| efficiency: `_epic_shard_path()` over-abstracted | low | dismissed | Pre-existing helper, not in my diff. |
| efficiency: `_epic_ref_matches()` re-normalizes | low | dismissed | Pre-existing helper, not in my diff. |
| efficiency: `_cancel_epic_in_initiatives()` duplicates find | medium | dismissed | Pre-existing code, not in my diff. |
| efficiency: `_write_archive` test helper only used 3× | medium | dismissed | Helper's single responsibility IS to bypass the new `_write_archive_file` guard for fixture setup — tests need to exercise the helper's resolution/report code paths against malformed archives. Inlining would duplicate the 17-line YAML-building boilerplate in 3 places. Flagging as misdiagnosis. |

### Quality Pass

- Focused suite (9/9): `test_archive_epic_field_validation.py` passes in 0.17s.
- Ruff lint: all checks passed on changed files.
- No regressions — prior regression run on GREEN phase showed 264+ passing / 0 failing / 3 pre-existing skips on the archive + sprint + cli surface.

**Handoff:** To Reviewer for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 + 1 note | Subagent returned after ~6 min: 9/9 focused green, 4342 passed / 40 failed / 3 skipped total (all 40 are pre-existing on develop — test_145_5/141_20/143_12/148_23, test_peloton_pane_layout, test_frame_routes; subagent verified frame_routes vs develop). 0 code smells. Independently flagged the same weak regex in `test_write_archive_file_raises_when_completed_story_has_empty_epic` that security also caught. Manual preflight was run in parallel during the subagent stall; both agree. |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 3 | confirmed 1, dismissed 0, deferred 2 |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (2 enabled — preflight covered manually after subagent stall; 7 disabled via `workflow.reviewer_subagents`)
**Total findings:** 1 confirmed (weak test regex), 0 dismissed, 2 deferred (ANSI pass-through, Principle 10 soft-violation — both non-blocking)

### Rule Compliance

- **SOUL.md Principle 1 (fix-the-system):** Guard at `_write_archive_file` (`archive_epic.py:240-253`) + `backfill_epic_refs` — **COMPLIANT.** Both replace silent fallbacks with loud failures or structured reports.
- **SOUL.md Principle 10 (return-results):** `_write_archive_file` raises `ValueError`; `backfill_epic_refs` returns `{success, backfilled, irrecoverable}` — **PARTIAL.** Raise is intentional (tested, documented via `Raises:` docstring); the result-dict boundary is preserved at the public callers (`archive_epic()`, `backfill_epic_refs()`, CLI). Consistent with the pre-existing raise at line 37 (`"Could not load sprint data"`). Already logged as a delivery finding during 151-1 review for a blanket-refactor follow-up on epic 151.
- **Python lang-review #1 (silent exception swallowing):** **COMPLIANT** — guard raises loud; irrecoverable path reports rather than swallows.
- **Python lang-review #3 (type annotations at boundaries):** **COMPLIANT** — `backfill_epic_refs(project_root: Path | None = None) -> dict[str, Any]`, Click callback signature annotated.
- **Python lang-review #5 (path handling):** **COMPLIANT** — all new I/O via `pathlib.Path` (glob, `write_text`, `/` operator); no string concatenation; `_load_archive_file` uses `with open()`; `_make_yaml()` uses ruamel YAML in round-trip mode (safe by default).
- **Python lang-review #6 (test quality):** **PARTIAL** — 8/9 tests have tight, meaningful assertions. `test_write_archive_file_raises_when_completed_story_has_empty_epic` uses `match=r"(?i)(empty|without).*epic.*empty-epic-1"` which matches "empty" in the static template prefix ("missing or empty"), not in the dynamic offender list. Flagged as a LOW-severity test-fidelity gap.
- **pennyfarthing CLAUDE.md (Python only, modify `pennyfarthing-dist/`):** **COMPLIANT** — only Python changed; all edits under `pennyfarthing-dist/src/pf/`.
- **Repos topology (never_edit):** **COMPLIANT** — no symlink targets, no build output.

### Devil's Advocate

Trying to break this fix.

*Concurrent writes.* `backfill_epic_refs` uses `archive_dir.glob` to snapshot paths, then reads-patches-writes each file. No lock, no atomic rename. If another process mutates an archive mid-walk, the backfill's in-memory copy silently overwrites the concurrent change. For a single-operator local CLI this is tolerable — `pf sprint ...` commands are user-interactive, not daemonized — but worth documenting if multi-user edit flows ever emerge.

*Epic with no `jira` and no `id`.* The builder does `epic.get("jira") or epic.get("id") or ""` + `.strip()`. If both are blank the epic is silently skipped and all its children become irrecoverable. Correct behavior (can't backfill from an unnameable epic) but the caller gets no hint that an epic was skipped — the irrecoverable list only names the orphan stories, not the source of their orphaning. Minor observability gap, not a correctness bug.

*Duplicate story id across epics.* `id_to_epic[sid] = epic_ref` is last-write-wins. If two epics in the live sprint claim the same story id, the second silently overrides the first. Sprint YAML invariants should prevent this, but backfill trusts the input. Very low likelihood.

*`migrate_completed_archive` collateral damage.* The old `migrate_completed_archive` silently dumped epic-less stories into `orphans`. After this change, migrate calls `_write_archive_file` at the end, which now raises if ANY completed_stories entry is epic-less. That's the spec intent — don't silently paper over bad state — but there's no dedicated test for the migrate-with-epic-less-entries path. The existing `test_archive_epic_writes_completed_stories` uses clean fixtures, so the new failure mode isn't regression-covered. A future migration of a malformed archive would fail loud (good) but the test suite doesn't prove that. Flagging as a Gap delivery finding.

*What the tests DON'T cover.* CLI `--json` output format — no test asserts valid JSON shape (the two CLI smokes exercise the default text output paths). Irrecoverable exit-code branch is covered. `load_sprint` returning None (degraded sprint yaml) — helper handles gracefully but no test exercises the degraded path.

*YAML round-trip fidelity.* `_write_archive_file` reads with ruamel (preserves comments, quoting, ordering) and re-emits. My new guard runs BEFORE the serialisation block, so no format regression. Existing test `test_write_archive_file_succeeds_when_every_story_has_epic` reads the written file and asserts key content — minimal coverage but acceptable.

*Injection of Jira sync data.* If `pf jira bidirectional` ever writes YAML with sprint numbers / names containing slashes or newlines, the same path-traversal concern from 151-1 re-emerges, and the new guard doesn't guard against it. Carried forward from 151-1 delivery findings.

Conclusion: one confirmed LOW-severity test-quality gap, two deferred SEC findings, three edge-case gaps that belong as delivery findings for follow-up. No blockers.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `sprint/current-sprint.yaml` → `load_sprint()` → id→epic lookup map → `sprint/archive/sprint-*-completed.yaml` (glob) → in-memory patch of `story["epic"]` → all-clean check → `_write_archive_file()` (now guarded) → YAML emit. All inputs are developer-owned filesystem paths; no user-controlled data crosses the boundary.

**Pattern observed:** Core-raises, boundary-wraps. Internal helper (`_write_archive_file`) raises `ValueError` for invariant violations; public surface (`backfill_epic_refs`, CLI command) returns result dict / non-zero exit. Pattern matches the existing style in `archive_epic` module (see sibling `archive_epic()` at line 446 which wraps errors similarly).

**Error handling:** Guard at `archive_epic.py:240-253` raises with a message naming every offending story id plus remediation text (`run backfill_epic_refs()`). `backfill_epic_refs()` at `archive_epic.py:289-348` returns irrecoverable list rather than swallowing. CLI command at `cli.py:313-346` prints structured summary and exits non-zero on irrecoverable — operator never gets silent success on bad state.

**Observations:**

- [VERIFIED] Spec intent met — `_write_archive_file` fails loud on missing/empty `epic`; `backfill_epic_refs` repairs from live sprint YAML and reports irrecoverables. Evidence: `archive_epic.py:240-253`, `archive_epic.py:289-348`, `cli.py:313-346`.
- [VERIFIED] Tests cover the three behavioural branches + 2 CLI smokes + 1 baseline. Evidence: `test_archive_epic_field_validation.py` — 9 tests, 3 guard + 1 baseline + 3 helper + 2 CLI.
- [VERIFIED] No regression — 9/9 focused green, 65 passing in broader archive/sprint-cli/story_finish scope on this branch.
- [VERIFIED] Lint clean — ruff passes on all three changed files.
- [VERIFIED] Architect spec-check rework loop closed — Mismatch 1 (CLI surface) resolved by adding `pf sprint backfill-epics`; Mismatch 2 (`archive_story` guard) properly deferred with logged deviation.
- [SEC] [LOW] ANSI/control character pass-through at `cli.py:333-340` — story ids and epic refs from YAML are echoed without stripping terminal control chars. Developer-owned YAML, not user-supplied input; real-world risk nil. Defensive hardening, not blocking.
- [TEST] [LOW] Weak regex in `test_write_archive_file_raises_when_completed_story_has_empty_epic` — `match=r"(?i)(empty|without).*epic.*empty-epic-1"` matches "empty" in the static prefix "missing or empty", not in the dynamic offender list. A future rewording of the error prefix would silently pass a broken implementation. Fix is trivial (`match=r"empty-epic-1"` + a separate substring check on "epic"). Confirmed finding; non-blocking.
- [SEC] [LOW] Principle 10 soft-violation at `_write_archive_file` — raises instead of returning result dict. Documented via `Raises:` docstring; consistent with sibling raise at line 37 (pre-existing). Already captured as delivery finding on epic 151 during 151-1 review for a blanket refactor. Deferred.
- [EDGE] [LOW] `migrate_completed_archive` now transitively raises when archive contains epic-less stories — that's the spec intent (no silent orphaning), but no dedicated regression test proves it. Delivery finding.
- [EDGE] [LOW] `backfill_epic_refs` silently skips epics lacking both `jira` and `id` — all their children land in irrecoverable with no hint the epic itself was unnameable. Observability gap; low likelihood in practice.
- [EDGE] [LOW] Concurrent-write race during `backfill_epic_refs` — no lock / atomic rename. Single-operator CLI context makes this tolerable. Delivery finding if multi-user flows ever emerge.
- [EDGE] [LOW] Duplicate story id across epics in live sprint YAML: `id_to_epic` is last-write-wins. Sprint invariants should prevent this, but helper doesn't defend.
- [EDGE] [LOW] No test for CLI `--json` output shape — the two CLI smokes exercise default text output only. Delivery finding.
- [RULE] [VERIFIED] Rule-compliance: pathlib (✓), type annotations (✓), safe YAML loader (✓), context-managed file I/O (✓). No violations.
- [TYPE] [VERIFIED] `backfill_epic_refs` return type annotated; no new types introduced; `Path | None` keeps typing consistent with sibling helpers.
- [DOC] [VERIFIED] New function has detailed docstring including `Args:` and `Returns:` sections; `_write_archive_file` docstring updated with `Raises:` block. CLI command has operator-facing docstring with semantics of exit code.
- [SIMPLE] [VERIFIED] Fan-out verify already dismissed simplify findings with documented rationale — no over-engineering introduced.

**Handoff:** To SM for finish-story.

### Dev (implementation)
- **`archive_story()` guard deferred (not a spec change, but a scope decision).**
  - Spec source: `.session/151-2-session.md`, SM Assessment — "Wire the raise into the archive write surface (lowest-cost option: add a guard in `_write_archive_file` / `migrate_completed_archive` / `archive_story`)."
  - Spec text: treats `_write_archive_file`, `migrate_completed_archive`, and `archive_story` as comparable candidates for the guard.
  - Implementation: Guard added only at `_write_archive_file`. `archive_story` and `migrate_completed_archive` still use their existing write paths and are not guarded.
  - Rationale: `migrate_completed_archive` writes via `_write_archive_file` so it inherits the guard automatically. `archive_story` uses raw `open(..., "a")` append, which would require a non-trivial refactor (serialise full dict through `_write_archive_file`) or a parallel guard — neither fits the surgical 151-2 scope, and the 151 epic's purpose is served by the primary write-path guard plus the backfill helper. Flagged as a delivery finding for a follow-up story.
  - Severity: minor
  - Forward impact: 151-2 does not close the silent-`epic:` failure mode in the `pf sprint archive STORY_ID PR` CLI path. External users who archive stories via that command still get silent empty-epic writes. A follow-up (proposed 151-4) will route `archive_story` through `_write_archive_file` or add a sibling guard.

### Architect (reconcile)

- **Correction note on Dev's deviation entry above:** the Implementation line reads "`archive_story` and `migrate_completed_archive` still use their existing write paths and are not guarded" — the first clause is correct, but `migrate_completed_archive` *is* guarded transitively (it calls `_write_archive_file` at `archive_epic.py:156`, which now raises on epic-less stories). The Rationale line clarifies this; the Implementation line is just terse. Leaving the entry intact per reconcile protocol (annotate, don't rewrite), but a reader should take the Rationale as authoritative.

- **No additional deviations found.** The Dev scope-trim on `archive_story` is the only architecturally material deviation. Reviewer's findings (weak test regex, ANSI pass-through, `migrate` raise-path test coverage, CLI `--json` shape coverage, concurrent-write race, unnameable-epic observability) are all delivery-findings-class polish/hardening items — they affect code quality, not spec-fidelity — and are recorded in `## Delivery Findings` under `### Reviewer (code review)` for epic 151 follow-up.