---
story_id: "162-71"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-71: get_dist_root scope leak: config.py fallback #4 (bundled pf._dist) fires even with explicit project_root (unlike #2); guard it. Also 17 npm-layout canonical tests in test_dist_root.py pass ONLY because of the leak (masking the defect) — re-disposition them (162-30 review MEDIUM)

## Story Details
- **ID:** 162-71
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-71-get-dist-root-scope-leak-guard
- **PR:** https://github.com/slabgorb/pennyfarthing/pull/246 (merged to develop, squash 303bd676b)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-13T14:06:10Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-13T12:54:43Z | 2026-08-13T12:56:06Z | 1m 23s |
| red | 2026-08-13T12:56:06Z | 2026-08-13T13:18:18Z | 22m 12s |
| green | 2026-08-13T13:18:18Z | 2026-08-13T13:51:18Z | 33m |
| review | 2026-08-13T13:51:18Z | 2026-08-13T14:06:10Z | 14m 52s |
| finish | 2026-08-13T14:06:10Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

- **Improvement (non-blocking):** The `npm_layout` fixture's agent stubs (`dev.md`, `reviewer.md`, `tea.md`, and originally `sm.md`) are skeletal and fail agent-validation. This never surfaced because the unguarded leak substituted the *real* bundled agents for validation. Enriching `sm.md` was enough for the end-to-end test's `passed >= 1` contract; the other three remain deliberate stubs. If a future test needs multiple valid agents in this fixture, enrich them too.
- **Conflict (BLOCKING):** 162-71's guard directive directly contradicts shipped story **162-29**'s `TestDistFallbackPreserved` / `TestWritersSeeDistTier` contracts (17 tests). Applying the guard breaks bundled/dist workflow resolution for pip/npm/dist-only consumers. See Dev Assessment for full analysis. Requires Architect/product adjudication before proceeding.
- **Improvement (non-blocking):** `get_dist_root()` has **no node_modules walk** at all — the "npm consumer" support is really the bundled `pf._dist` fallback on *auto-detect* (`project_root=None`). The fixture name `npm_layout` and the old AC5 ("no symlink required") over-promised a capability that doesn't exist. Consider renaming the fixture / revisiting whether node_modules resolution is a real requirement (out of scope here).

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

No design deviations

## Dev Assessment

**GREEN BLOCKED — cross-story architectural conflict. `config.py` reverted (clean tree). No implementation shipped.**

### What happened
Applied the one-line guard (`if project_root is None:` around fallback #4) exactly as TEA specified. Result:
- `test_dist_root.py`: **37/37 green** (TEA's target met).
- **Full suite: +17 regressions**, all in `test_162_29_workflow_override_resolution.py`. Baseline (pre-change) had only 1 unrelated pre-existing failure (`test_162_5_quarantine_policy::test_every_xfail_cites_a_tracking_reference`).

### The conflict (irreconcilable as scoped)
Story **162-29** (already shipped, epic 162) deliberately relies on the exact behavior 162-71 calls a "leak." Its `get_dist_root(project_root=root)` bundled fallback under an explicit root is how *readers and writers agree* on workflow resolution in a dist-only / pip / npm layout. Named contracts that break:
- `TestDistFallbackPreserved::test_no_project_workflows_dir_falls_back_to_dist`
- `TestDistFallbackPreserved::test_project_dir_present_but_workflow_absent_falls_back`
- `TestWritersSeeDistTier::*` (9 incl. parametrized) — "writers must see the dist tier and agree with the reader"
- `TestWorkflowNameContainment::test_legitimate_names_still_resolve`
- `TestResolverEdgeCases::test_empty_nested_dir_at_top_tier_falls_through`
- `TestResolverIsTheSinglePrecedenceDefinition::{test_resolver_precedence_is_project_then_dist, test_dist_tier_is_off_by_default_for_enumeration}`

162-29's module docstring point 3 is explicit: *"The dist fallback still works when the project ships no override."* The same call — `get_dist_root(project_root=root)` — is required by 162-29 to return the bundled dist and by 162-71 to return `None`. There is no signal to distinguish the two intents at the call.

### Root-cause read (for adjudication)
162-71's "unlike #2" premise looks like a **category error**. Fallback #2 is `__file__`-relative (accidental — returns wherever the code is installed); fallback #4 is the **deliberate** bundled-package fallback that pip/npm consumers (and 162-29's writers) depend on. Guarding #4 like #2 removes a load-bearing capability.

The genuinely-valuable half of 162-71 — the vacuous npm tests in `test_dist_root.py` — has already been fixed by TEA independent of the guard (the 13 patch-pattern re-dispositions don't require the guard and stay green). What conflicts with 162-29 is specifically:
- The `config.py` guard (not applied).
- TEA's 3 NEW guard RED tests + the rewritten `TestGetDistRootNpm` (they assert `None` under an explicit root — directly contradicting 162-29's `TestDistFallbackPreserved`).

### Recommendation
Do NOT ship the guard. Route to Architect / product decision. Likely outcome: 162-71's "guard it" directive is superseded by 162-29's `TestDistFallbackPreserved` contract; keep the test-hygiene half (13 patch-pattern re-dispositions), drop the guard tests. Confirm before I touch either story.

### RESOLUTION (Keith, 2026-08-13): "Drop guard, keep test fixes"
Confirmed: fallback #4 is a deliberate, load-bearing capability (162-29 depends on it), not an accidental leak like #2. 162-71's "guard it" directive is a misdiagnosis and is **superseded by 162-29's `TestDistFallbackPreserved` contract**.

**Final deliverable (test-hygiene only, no behavior change):**
- `config.py`: **unchanged** (no guard). Fallback #4 keeps firing under an explicit `project_root` — as 162-29 requires.
- `test_dist_root.py`:
  - Dropped `TestGetDistRootExplicitRootScopeGuard` (all guard tests) and reverted the `TestGetDistRootNpm` rewrite — their `None`-under-explicit-root assertions contradicted 162-29.
  - **Kept** the 13 call-site/integration re-dispositions to the patch-pattern (`patch(...get_dist_root, return_value=<npm_dist>)`) — hermetic: they now assert the call-site contract against controlled fixture content instead of depending on whatever the real bundled `_dist` ships.
  - Kept the `npm_layout` `sm.md` enrichment (valid agent) required by the patched end-to-end validation test.

**Verification:** `test_dist_root.py` 35 passed; `test_162_29` 76 passed; `config.py` clean; **full suite: 1 failed, 7557 passed** — the single failure is the pre-existing, unrelated `test_162_5_quarantine_policy::test_every_xfail_cites_a_tracking_reference` (fails identically on baseline before any change). Zero regressions from this story.

**Story scope collapsed** from "guard + re-disposition 17" to "test hygiene: 13 patch-pattern re-dispositions." **SM action:** update 162-71's record and file a note that its guard portion is superseded by 162-29's `TestDistFallbackPreserved`. The 162-30 review finding that spawned 162-71 conflated fallback #2 (`__file__`-accidental) with #4 (deliberate bundled fallback).

**Source:** 162-30 review finding, MEDIUM severity. p1, 2pts, tdd, repo `pennyfarthing/` (gitflow → PR targets `develop`).

**Defect (primary):** In `config.py`'s `get_dist_root()` resolution chain, fallback #4 (bundled `pf._dist`) fires even when an explicit `project_root` is passed. This is inconsistent with fallback #2, which correctly guards on an explicit `project_root`. The fix is to add the same explicit-`project_root` guard to fallback #4 so a caller that names a project root does not silently fall through to the bundled dist.

**Secondary (test re-disposition):** 17 npm-layout canonical tests in `test_dist_root.py` currently pass *only because of this leak* — they exercise the bundled-dist fallback path that the guard will close. Once the guard lands they will change behavior. TEA must re-disposition them: distinguish tests that legitimately assert the no-explicit-root fallback (keep) from those that were passing by accident under an explicit root (fix/re-point to assert the guarded behavior). These must not be blindly deleted — measure actual behavior first.

**RED-phase focus for TEA:**
1. Write a failing test proving fallback #4 does NOT fire when an explicit `project_root` is supplied (mirror the fallback #2 guard test).
2. Audit the 17 npm-layout canonical tests in `test_dist_root.py` — identify which pass only due to the leak and specify their correct disposition.

**Out of scope:** unrelated `get_dist_root`/`get_project_root` refactors (see sibling stories 162-53/54/64). Keep the guard surgical and consistent with fallback #2.

## Tea Assessment

**RED complete. 3 failing tests pin the defect; 34 pass. `config.py` untouched (test-only deliverable).**

**File:** `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_dist_root.py`

### The defect (empirically confirmed)
`get_dist_root(project_root=X)` with no dist under `X` returns the globally-bundled `pf._dist` — ignoring the caller's explicit scope. Fallback #4 (`config.py:110-119`) lacks the `if project_root is None:` guard that fallback #2 has (`config.py:98`). Verified live: in this dev env `pf._dist.is_populated()` is `True`, so the leak actively fires.

### GREEN task for Dev (one-line guard)
Wrap fallback #4 in `config.py` with `if project_root is None:` (mirror fallback #2). I temporarily applied exactly this and the **full suite went 37/37 green, then reverted** — so the guard is proven sufficient and non-breaking. Do NOT touch fallbacks #1/#3 (they're correctly scoped to `root`).

### Tests added (RED — fail now, pass after guard)
- `TestGetDistRootExplicitRootScopeGuard::test_explicit_root_does_not_leak_to_bundled_dist`
- `TestGetDistRootExplicitRootScopeGuard::test_npm_only_layout_returns_none_under_explicit_root`
- `TestGetDistRootNpm::test_node_modules_only_layout_is_unsupported`

Plus regression-green guards (already pass, must stay green): `test_explicit_root_still_finds_local_dist`, `test_explicit_root_still_finds_inlined_dist`.

### The 17 masking tests — re-dispositioned (matches story's "17")
Measured empirically (simulated the guard, saw exactly 17 fail). Split:
- **4 pure-resolution tests** (`TestGetDistRootNpm`): rewrote to assert the honest behavior — a node_modules-only layout is unsupported → `None`. Collapsed to 2 meaningful tests + folded into the guard class.
- **13 call-site/integration tests**: re-dispositioned to the **patch-pattern already established in this file** (3 sibling tests — `gate_file`, `theme_discovery`, `gate_resolution` — already do this). Each now `patch(...get_dist_root, return_value=<npm_dist>)`, so they test the call-site contract ("consume `get_dist_root()`, don't hardcode paths") independent of the resolution leak. These pass **both** before and after the guard.
- Two originally-suspected tests do **not** depend on the leak and were left alone: `test_statusline_theme_resolves_in_npm` (secondary fallback) and `test_cli_help_finds_registry_in_npm` (never calls `get_dist_root`).

### Verification evidence
- RED now: `3 failed, 34 passed`.
- With guard applied (temp, reverted): `37 passed`.
- `ruff check` on the test file: clean.

**Handoff:** Dev applies the one-line guard in `config.py`. No test changes needed in GREEN — the suite already encodes the target state.
## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (35 passed, ruff clean, +87/−28) | N/A |
| 2 | reviewer-security | Yes | clean | none | N/A |
| 3 | reviewer-type-design | Yes | clean | none | N/A |
| 4 | reviewer-rule-checker | Yes | clean | none (13 rules, 0 violations) | N/A |
| 5 | reviewer-test-analyzer | Yes | findings | 3 (2× missing positive backstop, 1× disjunctive assertion) | Non-blocking — all pre-existing, not introduced by diff; recorded for future strengthening |

**All received:** Yes (5/5 specialists returned; 4 clean, 1 non-blocking findings)

## Reviewer Assessment

**Verdict:** APPROVED

No blocking code findings. Test-only diff; production code unchanged.

### Specialist subagent findings
- **[SEC]** clean (0 findings). All changed paths derive from pytest `tmp_path`; mocks patch internal path-resolution, not any auth/permission/security gate — no risk of masking a production check.
- **[TYPE]** clean (0 findings). Every `patch(..., return_value=...)` supplies a `pathlib.Path` — the non-`None` branch of `get_dist_root() -> Path | None`. No `Path`/`str` mixing.
- **[RULE]** clean (13 rules checked, 0 violations). All 10 patch targets independently confirmed as "patches where **used**, not where defined." Context-manager `with patch(...)` usage compliant; `assert "SM Agent" in content` still satisfied (fixture first line unchanged).
- **[TEST]** 3 non-blocking findings, all **pre-existing weaknesses not introduced by this diff** (the assertions were unchanged; only the `patch()` wrapper was added). Recorded for a future strengthening pass; not grounds for rework on a test-hygiene diff that currently passes with real fixture content:
  - `test_workflow_validator_finds_workflows_in_npm` (~L418): sole assertion `assert not has_dir_not_found` passes vacuously if `report.details == []`. Missing the `passed>0 or warnings>0` backstop its agent-validator sibling has. **Recommend** adding that backstop.
  - `test_tandem_awareness_finds_agents_in_npm` (~L732): same missing backstop.
  - `test_agent_validator_finds_agents_in_npm` (~L405): `passed>0 or warnings>0` is disjunctive — a fixture with 0 passing agents still passes. `test_validate_agent_end_to_end_npm` covers the same call site with the stronger `passed>=1`, mitigating exposure.

### Scope reviewed
Single file: `pennyfarthing-dist/src/pf/tests/test_dist_root.py` (+87/−28). `config.py` confirmed unmodified (no guard shipped — correct per the 162-29 conflict resolution). No production behavior change, so security/edge/type-design lenses N/A; reviewed as a test-quality change.

### Checks performed
- **Non-vacuity:** each of the 13 patch-pattern tests retains discriminating power — a call site that hardcoded `root/pennyfarthing-dist` (instead of consuming `get_dist_root()`) would not be redirected by the patch, would find nothing under `npm_layout`, and the assertion would fail. Contract still enforced.
- **Patch targets valid:** all 9 distinct targets patch the module where `get_dist_root` is imported (verified vs. import sites; a wrong target raises `AttributeError`). All 13 pass, confirming resolution.
- **No orphans:** deleted `TestGetDistRootExplicitRootScopeGuard` leaves no dangling refs; `TestGetDistRootNpm` restored to original; `bare_project` still legitimately used by `TestGetDistRootNotFound`.
- **Fixture enrichment safe:** `sm.md` `<coordination-discipline>`/`<parameters>` additions cause no collateral (full suite green; no test asserts sm.md invalid).
- **Verification:** `test_dist_root.py` 35 passed; full suite 7557 passed / 1 pre-existing unrelated failure; ruff clean.

### Non-blocking observations (for the record / future cleanup)
1. **Coverage tradeoff:** patching `get_dist_root` means these call-site tests no longer exercise real resolution end-to-end — they test call-site *consumption* only. Acceptable: resolution is covered separately (`TestGetDistRoot*`), and the "npm resolution" they previously exercised was always the bundled-dist fallback, never a real node_modules walk.
2. **Notional "npm" framing:** with `get_dist_root` patched, the fixture's `node_modules/…` tree is largely irrelevant to what these tests assert. The naming (`*_in_npm`, `npm_layout`) now overstates what's exercised. Consider a rename/clarify sweep — out of scope here (ties to the non-blocking finding about `get_dist_root` having no node_modules walk).
3. **Churn vs. hygiene:** since the guard was dropped, the original tests would also have passed. The value of this diff is hermeticity (removing an implicit dependency on whatever the real bundled `pf._dist` ships). Net quality-positive and consistent with the 3 pre-existing patched sibling tests.

### Blocking-for-SM (process, not code)
- **Story record must be corrected.** Delivered scope is test-hygiene only; the guard directive is **superseded by 162-29's `TestDistFallbackPreserved`**. SM: update 162-71 and file a note that the 162-30 review finding conflated fallback #2 (`__file__`-accidental) with #4 (deliberate bundled fallback). Consider whether this even warrants the original 2pt/p1 framing.
- **Heads-up (not this story):** `test_162_5_quarantine_policy::test_every_xfail_cites_a_tracking_reference` fails on `develop` baseline — pre-existing, unrelated. Worth its own story if not already tracked.