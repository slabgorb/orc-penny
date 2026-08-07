---
story_id: "162-29"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-29: B2: project workflow overrides unreachable

## Story Details
- **ID:** 162-29
- **Jira Key:** (none — Jira not enabled)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-29-project-workflow-overrides-unreachable
- **PR:** #189

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-07T12:31:40Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-07T11:10:50.661400+00:00 | 2026-08-07T11:12:11Z | 1m 20s |
| red | 2026-08-07T11:12:11Z | 2026-08-07T11:31:56Z | 19m 45s |
| green | 2026-08-07T11:31:56Z | 2026-08-07T11:44:58Z | 13m 2s |
| review | 2026-08-07T11:44:58Z | 2026-08-07T11:58:12Z | 13m 14s |
| green | 2026-08-07T11:58:12Z | 2026-08-07T12:17:14Z | 19m 2s |
| review | 2026-08-07T12:17:14Z | 2026-08-07T12:31:40Z | 14m 26s |
| finish | 2026-08-07T12:31:40Z | - | - |

## Sm Assessment

**Verdict:** READY

Setup complete for 162-29 (p1, 2 pts, tdd) — the last p1 in the epic. Branch `feat/162-29-project-workflow-overrides-unreachable` from the develop tip including #186/#187/#188. Peloton mode active (team peloton-162-29, subagent orchestration). Scope: get_phase_owner resolves owners/redirects from the installed dist root before {project_root}/.pennyfarthing/workflows/, while phases are written from project YAML — the two-readers disagreement pattern this epic keeps closing, workflow-YAML flavor. Fixing resolution order turns the four 143-9 verify-phase xfails green; flipping them from xfail is in scope. Note: 162-28 heavily reworked complete_phase.py/gate_recovery.py, so story-text line numbers may have drifted.

## TEA Assessment

**Verdict:** RED

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_29_workflow_override_resolution.py` — new, 32 tests (24 failing, 8 passing as regression guards)
- `pennyfarthing-dist/src/pf/tests/test_143_9_tdd_cycle_e2e.py` — four verify-phase xfails unquarantined, now failing live
- `pennyfarthing-dist/src/pf/tests/test_162_5_quarantine_policy.py` — two anti-vacuity guards reshaped to pin marker discovery synthetically

**Tests Written:** 32 new + 4 unquarantined, covering 6 ACs derived during RED (the sprint YAML recorded none)

**Status:** RED — 29 story-related failures. Commit `54576cf3e`, GPG-signed.

**Root cause (confirmed empirically):** `pf.prime.workflow` asks `get_dist_root()` first and only falls back to `{project_root}/.pennyfarthing/workflows/`. `get_dist_root()` ends in a `pf._dist` bundled-package fallback which `is_populated()` reports True for and which ships every stock workflow, so the dist branch never misses and the project override is dead code. Six functions share the defect: `get_phase_owner`, `get_phase_tandem_config`, `get_phase_team_config`, `get_phase_skills`, `get_phase_gate_recovery`, and `_get_step_config_block` (the last has no project fallback at all). The writers read the project path only, so the two sides disagree.

**Suite numbers:** 6046 passed, 33 failed, 4 skipped, 0 xfailed. 29 story-related (24 new + 4 unquarantined + 1 policy in-scope guard) plus the 4 environment-dependent `test_frame_routes` failures tracked as 162-49.

**Satisfiability verified:** a scratch patch routing all six readers through `find_workflow_file(get_all_workflows_dirs(root), name)` with a dist fallback turned all 29 green and produced no other regressions across the full suite. Reverted before commit — no source files are modified.

**Handoff:** To Dev for implementation

## Dev Assessment

**Verdict:** GREEN

**Round:** rework 1 (reviewer HIGH-1 + both MEDIUMs + both LOWs addressed)

**Implementation Complete:** Yes

**Reviewer HIGH-1 accepted without argument.** The measurement was correct and my round-1 rationale was wrong. "Writers must never stamp from dist" conflated *don't let dist outrank a project override* (correct, and the tier order already guarantees it) with *never read dist at all* (the defect). Tiering means project-overrides-dist, not project-only. In the dist-only consumer layout the readers resolved `tdd` while every writer resolved nothing, and because `_validate_phase_names` cannot distinguish "workflow has no phases" from "file not found", it stopped correcting agent names and stamped `**Phase:** finish — the bug its own docstring exists to prevent. I verified the harm before fixing it: `_validate_phase_names(root, "tdd", "red", "dev")` returned `("red", "dev")`.

**Files Changed (10):**
- `workflow/helpers.py` — new `resolve_workflow_file(workflow_name, project_root)`: the single precedence definition for readers and writers alike (`project/workflows/` → `.pennyfarthing/workflows/` → dist floor, flat and nested at every tier). New `is_contained_path` CWE-22 guard, enforced on every candidate inside `find_workflow_file`. New `get_dist_workflows_dir`. `get_all_workflows_dirs` gains `include_dist` (keyword-only, default False) and de-dupes the tier when `.pennyfarthing/workflows` is a symlink to the dist dir.
- `prime/workflow.py` — private `_resolve_workflow_file` deleted; all six readers now call the shared helper. `get_dist_root` import dropped.
- `handoff/complete_phase.py` — three writer call sites on the shared resolver.
- `handoff/resolve_gate.py` — `_find_workflow_yaml` on the shared resolver; `_list_available_workflows` now enumerates the same tiers the resolver searches (closes my own round-1 Delivery Finding).
- `subagent/chain.py`, `subagent/gate.py` — shared resolver, plus the Rule 6 `try`/`except → None` degrade.
- `handoff/cli.py` — gate_type/next_phase/next_agent resolution was on `get_workflows_dir` alone: blind to *both* the project tier and dist. Now on the shared resolver.
- `workflow/cli.py` — story `workflow:` field existence check on the shared resolver.
- `peloton/live.py` — two phase/agent resolution sites on the shared resolver.
- `tests/test_162_29_workflow_override_resolution.py` — 32 → 76 tests.

**Scope line I drew, and why:** *resolution* of a single named workflow now goes through one helper with the dist floor; *enumeration* (`pf workflow list`, and the 8 stepped-workflow CLI sites at `workflow/cli.py:145,263,462,569,735,906,1033,1353`) does not. Adding dist to enumeration would change what `pf workflow list` prints, which is a product decision, not a correctness one — hence `include_dist` defaults to False. The 8 stepped-workflow sites are single-tier resolution and *are* the same defect class, but they are a separate command family with no test coverage in this story; expanding into them mid-rework is how the last round went wrong. Filed precisely as a Delivery Finding instead.

**Recurrence guard (new):** `TestResolverIsTheSinglePrecedenceDefinition` asserts that no module in the phase-ownership path contains a `"workflows"` path literal or the two-tier `find_workflow_file(get_all_workflows_dirs(...))` shape. This epic keeps re-finding the same defect; a test that fails when someone reintroduces it is worth more than my correcting today's call sites. It earned its keep immediately — it caught `resolve_gate._list_available_workflows`, which I had filed as a finding last round instead of fixing.

**Tests:** GREEN. 44 new tests this round.
- `test_162_29_workflow_override_resolution.py` — 76/76 (was 32)
- `test_143_9_tdd_cycle_e2e.py` — 57/57 · `test_162_5_quarantine_policy.py` — 7/7 · `test_dist_root.py` — 35/35 (both npm watch items still pass)
- `test_141_25_project_workflows.py` — 29/29 (the pre-existing `find_workflow_file`/`get_all_workflows_dirs` contract tests, unchanged by the new signature)
- Full suite: **6119 passed, 4 failed, 4 skipped, 0 xfailed** (169s).

**On the 4 failures — correcting the record, including my own earlier wording.** These are `test_frame_routes.py` persona-route cases. They are *not* flaky or environment-dependent: they fail deterministically here, 4/4 on every run, with a real signature mismatch — `TypeError: load_persona() got an unexpected keyword argument 'session_id'` at `frame/routes/data_proxy.py:72`. I confirmed they are not mine by stashing my entire diff and re-running: still 4 failed. So they are pre-existing on this branch and unrelated to 162-29 (tracked as 162-49), but "environment-dependent" — which TEA wrote, I repeated, and the Reviewer inferred from not reproducing them — is the wrong label. Something in the Reviewer's environment (likely an installed `pf` shadowing the source tree) hid a genuine break. Worth knowing before 162-49 is triaged as flakiness.

**Verification of the fix in the live repo, not just tests:** in the dogfood layout readers and writers now agree on all five tdd phases, `_validate_phase_names(root,"tdd","red","dev")` → `("red","green")`, a traversal name returns `None`, and the symlinked `.pennyfarthing/workflows` tier still resolves (the containment guard resolves both sides, so symlinked tiers are unaffected). `pf handoff resolve-gate` and `pf workflow check` both still behave correctly end to end.

**Lint:** `ruff check` clean on all changed files except one pre-existing `E402` in `peloton/live.py`, which I verified is present at HEAD via `git show` and did not introduce. `ruff format --check` clean on `helpers.py`, `prime/workflow.py`, `subagent/chain.py` and the test file. `complete_phase.py`, `resolve_gate.py` and `subagent/gate.py` remain pre-existing-unformatted, as accepted last round.

**Branch:** `feat/162-29-project-workflow-overrides-unreachable` (pushed). Commit `56099190a`, GPG-signed. No PR — SM creates it in finish.

**Handoff:** To Reviewer

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### TEA (test design)
- **Gap** (non-blocking): `.pennyfarthing/project/workflows/` is honored only by `pf.workflow.helpers.get_all_workflows_dirs` (used by the `pf workflow` CLI and peloton). `handoff/complete_phase.py`, `handoff/resolve_gate.py`, `subagent/chain.py` and `subagent/gate.py` all hardcode `.pennyfarthing/workflows/` and never see the higher-priority tier. Fixing only prime's dist-vs-project ordering re-creates the same disagreement one tier up. Affects those four modules (route them through the shared helper). *Found by TEA during test design.*
- **Improvement** (non-blocking): `get_dist_root()`'s `pf._dist` fallback makes every "does the dist copy exist?" check unconditionally true, so any resolver written as dist-first silently loses its project fallback. This defect class will recur; a single shared workflow-file resolver is the durable fix. Affects `pf/common/config.py` and all workflow-YAML readers. *Found by TEA during test design.*
- **Gap** (non-blocking): `pf.workflow.state.get_phase_owner` is a second, unrelated function of the same name that hardcodes TDD/trivial phase owners in a Python dict and defaults unknown phases to `"sm"`. It reads no YAML at all, so it cannot honor any override, and `pf workflow phase-check` calls it. Affects `pennyfarthing-dist/src/pf/workflow/state.py` and `workflow/cli.py:86`. *Found by TEA during test design.*
- **Gap** (non-blocking): the sprint YAML recorded no problem description and no acceptance criteria for this story; `context-story-162-29.md` is all placeholders. TEA derived the six ACs from the story title and the 143-9 xfail comments. Affects `sprint/epic-162.yaml`. *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): `resolve_gate._list_available_workflows` still scans only `{root}/.pennyfarthing/workflows/`, so a workflow shipped solely in `.pennyfarthing/project/workflows/` is missing from the "available workflows" list in gate error messages. Same defect class as this story, but cosmetic (error text only) and no test forces it. Affects `pennyfarthing-dist/src/pf/handoff/resolve_gate.py:~340` (route through `get_all_workflows_dirs`). *Found by Dev during implementation.*
- **Improvement** (non-blocking): the tiered resolver now exists in two places — `pf.prime.workflow._resolve_workflow_file` (three tiers, includes dist) and `pf.workflow.helpers.get_all_workflows_dirs` (two tiers, project only). The writers deliberately never read dist, so the split is intentional, but `_resolve_workflow_file` belongs in `pf.workflow.helpers` as the one public entry point with the dist tier opt-in via a flag. Affects `pennyfarthing-dist/src/pf/workflow/helpers.py` and `prime/workflow.py`. *Found by Dev during implementation.*
- **Gap** (non-blocking): confirming TEA's finding — `get_dist_root()`'s unconditional `pf._dist` fallback still makes every "does the dist copy exist?" test true. This story removed the six readers that tripped over it, but the trap is intact for the next dist-first resolver anyone writes. Affects `pennyfarthing-dist/src/pf/common/config.py` (consider a `require_project_populated` flag or a docstring warning). *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (blocking): the four writer modules cannot see the dist tier, so the two-readers disagreement remains live for any consumer whose workflows exist only in dist — the project's own `npm_layout` shape (`.pennyfarthing/` holding just `config.local.yaml`). Verified: reader `get_phase_owner("tdd","red")` → `'tea'` while `complete_phase._get_phase_agent` → `'red'`, `_load_workflow_phases` → `[]`, `chain`/`gate._load_workflow_phases` → `None`, `resolve_gate._find_workflow_yaml` → `None`. Worse, `_validate_phase_names` bypasses correction on `[]`, so `('red','dev')` is returned where `('red','green')` is correct — silently reinstating the `**Phase:** finish bug. Affects `handoff/complete_phase.py`, `handoff/resolve_gate.py`, `subagent/chain.py`, `subagent/gate.py` (route through the 3-tier resolver). *Found by Reviewer during code review.*
- **Gap** (non-blocking): CWE-22 — `workflow_name` is joined into candidate paths unsanitized at `workflow/helpers.py`:61,65, and `prime/workflow.py`:140 takes the session `**Workflow:**` value with only `.lower()`. A crafted value (`../../../tmp/evil`, or an absolute path) resolves and loads YAML from outside the project root, controlling the `agent:` that decides phase ownership. Pre-existing on develop, but this diff funnels every caller through one function, making it a single fix point. Epic 162's own sweep (26cb554) established the guard — `candidate.resolve().is_relative_to(base.resolve())` — and it was not applied here. Affects `pennyfarthing-dist/src/pf/workflow/helpers.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `get_all_workflows_dirs` gates each tier on `is_dir()` and silently returns `[]` when neither project dir exists, which is what converts a missing tier into "no workflow exists" for every writer. A resolver that distinguished "tier absent" from "workflow absent" would have made this story's residual gap loud instead of silent. Affects `pennyfarthing-dist/src/pf/workflow/helpers.py`. *Found by Reviewer during code review.*
- **Question** (non-blocking): is quarantine *quantity* meant to be unpoliced? Post-162-29 the policy tests enforce that every xfail carries a reason and a tracking reference but never cap the count (develop's `>= 5` was a floor, not a ceiling). Deliberate per TEA, but worth an explicit policy note so a future reviewer does not re-litigate it. Affects `pennyfarthing-dist/src/pf/tests/test_162_5_quarantine_policy.py`. *Found by Reviewer during code review.*

### Dev (rework 1)
- **Gap** (non-blocking): eight stepped-workflow CLI sites resolve a single workflow through `get_workflows_dir()` alone — single-tier, blind to both `.pennyfarthing/project/workflows/` and dist. Same defect class as this story's HIGH: in a pip/npm consumer, `pf workflow start/resume/status/complete-step` cannot find any workflow. Affects `pennyfarthing-dist/src/pf/workflow/cli.py:145,263,462,569,735,906,1033,1353` (route through `resolve_workflow_file`). Deliberately left out of this story to avoid a mid-rework scope expansion; the new recurrence guard does not cover them because they are enumeration-adjacent command paths, not the phase-ownership path. *Found by Dev during rework 1.*
- **Improvement** (non-blocking): `is_contained_path` (`workflow/helpers.py`) and `is_safe_shard_path` (`sprint/shard_merge.py`) are now the same four-line CWE-22 guard in two packages. A third copy is the likely next step. Consolidate into `pf.common` and have both call it. Affects `pennyfarthing-dist/src/pf/common/`, `workflow/helpers.py`, `sprint/shard_merge.py`. *Found by Dev during rework 1.*
- **Gap** (blocking for 162-49): the four `test_frame_routes.py` persona failures are **not** environment-dependent flakiness, which is how they are currently labelled. They reproduce deterministically with this branch's changes fully stashed and are a real signature mismatch: `load_persona()` got an unexpected keyword argument `session_id`, raised at `frame/routes/data_proxy.py:72`. Whoever picks up 162-49 should treat it as a live break in the persona route, not a CI-environment artifact. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` and the `load_persona` signature. *Found by Dev during rework 1.*
- **Question** (non-blocking): `pf.workflow.state.get_phase_owner` remains a second same-named function that hardcodes phase owners in a dict and defaults unknown phases to `"sm"`; `pf workflow phase-check` calls it. Now that resolution is unified behind one helper, that function is the last reader of phase ownership that consults no YAML at all — its own story should probably just delete it in favor of `prime.workflow.get_phase_owner`. Affects `pennyfarthing-dist/src/pf/workflow/state.py`, `workflow/cli.py:86`. *Found by Dev during rework 1 (confirming TEA).*

### Reviewer (code review, cycle 1)
- **Gap** (non-blocking): the deferred-sites inventory is incomplete. Beyond the eight `workflow/cli.py` lines Dev named, two more sites are the same defect class: `workflow/cli.py:341` (`get_all_workflows_dirs(root)` without `include_dist`, so route enumeration is dist-blind and a story with no explicit `workflow:` field hits `SystemExit(1)` in a consumer layout) and `prime/loader.py:391-403` (a hand-rolled two-tier project-then-dist resolver for stepped-workflow step files, which also misses `project/workflows/` entirely and interpolates `workflow_name` into a path with no containment guard). Both belong in the follow-up story alongside the eight. *Found by Reviewer during code review.*
- **Gap** (non-blocking): `pf workflow list` and the gate's available-workflows hint now disagree about which workflows exist. Measured in the npm layout: `resolve_workflow_file("tdd")` resolves and `resolve_gate._list_available_workflows` returns 34, while `get_all_workflows_dirs(root)` backing `workflow/cli.py:341` returns `[]` — so the user sees an empty list from one command and a resolvable workflow from another. `include_dist=False` is a defensible default for enumeration, but the two enumeration surfaces should at least agree. Affects `pennyfarthing-dist/src/pf/workflow/cli.py:341`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the recurrence guard `TestResolverIsTheSinglePrecedenceDefinition` has two evasion vectors and a scope gap. `test_no_hand_rolled_workflows_path` matches only the double-quoted `"workflows"` literal, so single-quoted `'workflows'` bypasses it; `test_no_two_tier_resolution` matches the collapsed run `find_workflow_file(get_all_workflows_dirs`, which the natural two-statement refactor evades — asserting `find_workflow_file` is not imported at all outside `helpers.py` would close both. `PHASE_OWNERSHIP_MODULES` also omits `peloton/live.py`, `workflow/cli.py` and `prime/loader.py`, the three modules this rework touched. Affects `pennyfarthing-dist/src/pf/tests/test_162_29_workflow_override_resolution.py`. *Found by Reviewer during code review.*
- **Gap** (blocking for pipeline honesty, non-blocking for this story): **the Python suite's result depends on the working directory.** `frame/routes/data_proxy.py:35-42` resolves the project dir from `os.getcwd()`, so with cwd `pennyfarthing-dist/` (no `.pennyfarthing/`) the four persona-route tests short-circuit to a 404 at line 69 and pass **vacuously**; from `pennyfarthing/` they correctly fail on the real `load_persona` signature mismatch. Same command, same source, 6123/0 versus 6119/4. This misled my own cycle-1 assessment and `reviewer-preflight` in cycle 2. The suite needs a cwd-independent fixture (set `PF_PROJECT_DIR` in conftest) so a number cannot silently depend on where it was run. Affects `pennyfarthing-dist/src/pf/tests/conftest.py`, `frame/routes/data_proxy.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_resolve_path` (`workflow/helpers.py:219-226`) returns `Path(path_str)` verbatim for absolute paths taken from workflow YAML content, feeding `iterdir()` in `count_steps`/`find_step_file` — the one unguarded path-join sink left in the module now that `find_workflow_file` is fixed. Pre-existing, stepped-workflow-only, read-only impact, requires write access to a workflows dir. Apply `is_contained_path` against `project_root`. Affects `pennyfarthing-dist/src/pf/workflow/helpers.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `peloton/live.py:23` still trips `ruff check` (E402, pre-existing — the file went 3 errors → 1 in this rework); moving that import above the `logger` assignment zeroes the file. Four files still fail `ruff format --check`, all four pre-existing at develop. Affects `pennyfarthing-dist/src/pf/peloton/live.py`. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 2 findings (2 Gap, 0 Conflict, 0 Question, 0 Improvement)
**Blocking:** None

- **Gap:** `resolve_gate._list_available_workflows` still scans only `{root}/.pennyfarthing/workflows/`, so a workflow shipped solely in `.pennyfarthing/project/workflows/` is missing from the "available workflows" list in gate error messages. Same defect class as this story, but cosmetic (error text only) and no test forces it. Affects `pennyfarthing-dist/src/pf/handoff/resolve_gate.py:~340`.
- **Gap:** confirming TEA's finding — `get_dist_root()`'s unconditional `pf._dist` fallback still makes every "does the dist copy exist?" test true. This story removed the six readers that tripped over it, but the trap is intact for the next dist-first resolver anyone writes. Affects `pennyfarthing-dist/src/pf/common/config.py`.

### Downstream Effects

Cross-module impact: 2 findings across 2 modules

- **`pennyfarthing-dist/src/pf/common`** — 1 finding
- **`pennyfarthing-dist/src/pf/handoff`** — 1 finding

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### TEA (test design)
- **Reshaped two 162-5 anti-vacuity guards:** Scope said flip the four 143-9 xfails. Flipping them empties the tree's xfail set, and `test_markers_exist_to_check` / `test_xfail_markers_are_actually_being_checked` assert the real tree holds quarantines — so paying off the debt broke the guards that police the debt. Repointed both at a synthetic module so they pin detection correctness instead of debt volume, and split the tree-reachability claim into its own test. Reason: leaving them as-is would have forced Dev to either keep a fake xfail alive or delete the guards.
- **Pinned the `.pennyfarthing/project/workflows/` tier as well:** Story text names only the dist-vs-`.pennyfarthing/workflows/` ordering. Tests additionally require the `project/workflows/` tier to outrank it, matching the order `get_all_workflows_dirs` already establishes. Reason: a fix that reorders only two of the three tiers reproduces the same two-readers disagreement one tier up.
- **Pinned "broken override must not fall through":** Not in the story text. A malformed or agent-less project override must return None rather than the packaged answer. Reason: `complete_phase._load_workflow_phases` returns `[]` for those files, so any fallback answer is a fresh disagreement.
### Dev (implementation)
- **Extended the fix to the four writer modules:** Scope named only the six `pf.prime.workflow` readers, and no test in the RED suite forces the writers to change. Routed `complete_phase.py`, `resolve_gate.py`, `subagent/chain.py` and `subagent/gate.py` through `find_workflow_file(get_all_workflows_dirs(root), wf)` anyway. Reason: fixing prime alone would have made prime honor `.pennyfarthing/project/workflows/` while the writers still could not see that tier — the story would have closed one two-readers disagreement by opening another. TEA flagged this as an optional fold-in; it is six mechanical call sites with no behavior change for single-tier projects, and the suite confirms zero regressions.
- **Did not reformat three pre-existing unformatted files:** `complete_phase.py`, `resolve_gate.py` and `subagent/gate.py` fail `ruff format --check` at HEAD, before any of my edits. Left them failing rather than folding a whole-file reformat into this diff. Reason: `ruff check` (the actual lint gate) passes on all five files, and a reformat would bury a 6-line semantic change in hundreds of lines of noise for the Reviewer.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 6 | confirmed 4, dismissed 0, deferred 2 |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | findings | 4 | confirmed 3, dismissed 0, deferred 1 |
| 7 | reviewer-security | Yes | findings | 3 | confirmed 2, dismissed 1, deferred 0 |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | clean | 0 violations (1 pre-existing note) | confirmed 0, dismissed 1, deferred 0 |

**All received:** Yes
**Total findings:** 9 confirmed, 2 dismissed (with rationale), 3 deferred

Dismissals:
- `reviewer-rule-checker` reported `subagent/chain.py` and `subagent/gate.py` `_load_workflow_phases` as "compliant: returns list | None" under Rule 6 — **dismissed as incorrect**: neither function has a `try`/`except`, and my probe shows both raise `yaml.ParserError` on a malformed file and `AttributeError: 'NoneType' object has no attribute 'get'` on an empty one. Re-raised under my own analysis as MEDIUM-2 below.
- `reviewer-security` finding 2 (trust inversion, "NEWLY introduced") — **dismissed as by-design**: project-overrides-packaged is the story's entire purpose and TEA pinned it as an AC; the tier ordering matches `get_all_workflows_dirs`, which the `pf workflow` CLI and peloton already used. Its composition with the traversal gap is retained inside MEDIUM-3 rather than as a separate finding.

Deferred: test-analyzer's `_iter_quarantine_markers` full-pipeline gap and its quarantine-quantity note (both LOW, and it agrees the redesign does not weaken policing); type-design's `WorkflowResolution` newtype suggestion (design-level, belongs with Dev's own "resolver in two places" finding).

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Writers are still blind to the dist tier, so the two-readers disagreement stays live in the npm/pip layout — and it silently reintroduces the `**Phase:** finish bug `_validate_phase_names` exists to prevent | `handoff/complete_phase.py`:421-423, 399-409; `subagent/chain.py`:197; `subagent/gate.py`:29; `handoff/resolve_gate.py`:339 | Route the four writers through the same 3-tier resolver as the readers (lift `_resolve_workflow_file` into `pf.workflow.helpers` with the dist tier opt-in, per Dev's own Delivery Finding). If project-only writers are genuinely intended, prove it with a test pinning npm-layout behaviour and re-file this as a blocking Delivery Finding naming the `**Phase:** finish regression |
| [MEDIUM] | `_load_workflow_phases` in chain/gate raises uncaught on malformed or empty workflow YAML while every sibling degrades; the diff newly widens the trigger to the project tier | `subagent/chain.py`:197-203; `subagent/gate.py`:29-36 | Wrap in `try`/`except Exception: return None` to match `complete_phase._load_workflow_phases`. Violates project Rule 6 (don't throw) |
| [MEDIUM] | CWE-22: `workflow_name` is joined unsanitized; a crafted session `**Workflow:**` value resolves and loads YAML from outside the project root | `workflow/helpers.py`:61,65; source at `prime/workflow.py`:140 | Add the containment guard epic-162's own sweep (26cb554) established — `candidate.resolve().is_relative_to(d.resolve())` — inside `find_workflow_file`. Pre-existing, but this diff makes it a single fix point |
| [MEDIUM] | Test gaps on the new resolver: no flat-vs-nested collision within one tier, no symlink case, two assertions too wide to discriminate | `tests/test_162_29_workflow_override_resolution.py`:279, 320 | Add the collision and symlink fixtures; replace `is not None` (:320) and the `None == None`-passing equality (:279) with concrete owner values |
| [LOW] | `_resolve_workflow_file` docstring claims "the first tier holding a file is authoritative", but a broken symlink or an empty `{name}/` dir at the top tier silently falls through to a lower tier | `prime/workflow.py`:33-44 | Soften the docstring to "the first tier holding a *readable* file", or treat a present-but-unusable entry as authoritative |
| [LOW] | A workflow file whose inner `workflow.name` disagrees with its filename is accepted silently and answers under the filename | `workflow/helpers.py`:59-67 | Non-blocking; consider a warning |

### Observations

- **[TYPE][HIGH]** Confirmed empirically in the project's own canonical consumer layout. `test_dist_root.py`:90-150 (`npm_layout`) creates `.pennyfarthing/` containing *only* `config.local.yaml` — no `workflows/` dir — with workflows solely under `node_modules/@pennyfarthing/core/pennyfarthing-dist/workflows/`. In that exact shape: reader `get_phase_owner("tdd","red")` → `'tea'`, but `complete_phase._get_phase_agent` → `'red'`, `complete_phase._load_workflow_phases` → `[]`, `chain._load_workflow_phases` → `None`, `gate._load_workflow_phases` → `None`, `resolve_gate._find_workflow_yaml` → `None`. `get_all_workflows_dirs` gates each tier on `is_dir()`, so with neither project dir present it returns `[]` and every writer resolves nothing.
- **[HIGH]** The concrete harm, verified: `_validate_phase_names(root,"tdd","red","dev")` returns `('red','dev')` in npm layout versus `('red','green')` when `.pennyfarthing/workflows/` is populated. `complete_phase.py`:421-423 (`if not phases: return from_phase, to_phase`) cannot distinguish "workflow has no phases" from "file not found", so the agent name `dev` is written straight to the session `**Phase:**` line — the exact bug the function's own docstring (`complete_phase.py`:417-419) says it exists to prevent. `_get_phase_agent`'s `return phase` fallback likewise stamps `| red (red) |` into the Handoff History table at `complete_phase.py`:251 instead of `| red (tea) |`.
- **[HIGH]** This is **not a regression** — develop's writers were project-only too. It is a scope-and-honesty failure: Dev's Design Deviation states the fold-in was mandatory because "fixing prime alone would have closed one two-readers disagreement by opening another," and the rationale "writers must never stamp from dist" conflates *don't let dist override the project* (correct) with *never read dist at all* (the defect). Tiering means project-overrides-dist, not project-only. No test covers the writer side in npm layout — `test_dist_root.py`:454 and :613 pin only the reader.
- **[TYPE][MEDIUM]** `_load_workflow_phases` nullability is inconsistent across the three modules the diff rewrote from the *same* underlying call: chain/gate return `list|None`, `complete_phase` returns `list` with `[]` as the not-found sentinel. Callers are written against different contracts.
- **[SEC][MEDIUM]** CWE-22 verified reachable: `_resolve_workflow_file("../../outside/evil", root)` resolved to `…/.pennyfarthing/workflows/../../outside/evil.yaml` and loaded it, yielding phase owner `PWNED`; an absolute-path name resolves too. `prime/workflow.py`:140 does `result["workflow"] = value.lower()` with no sanitization, so a session file's `**Workflow:**` line is the delivery vector. Pre-existing on develop in both readers and writers; `yaml.safe_load` is used throughout so there is no RCE, but the `agent:` field decides which agent runs a phase.
- **[SEC][LOW]** Symlink escape at the newly-live tier is real (a `project/workflows/tdd.yaml` symlink pointing outside the root resolved to owner `EVIL`), but marginal: writing into that directory already requires local write access, and the file could carry the payload directly without a symlink. The same `resolve()`/`is_relative_to()` guard closes it alongside the traversal.
- **[VERIFIED]** The 162-5 guard reshape is a **legitimate redesign, not weakened debt-policing** — and I probed the specific question. The two real-tree policy tests still iterate `_iter_quarantine_markers()` over the live tree (`test_162_5_quarantine_policy.py`:152, :186), so 20 new xfails would still each be forced to carry a reason and a tracking reference; only *quantity* is unpoliced, which was equally true of develop's `>= 5` floor. Moving the vacuity guards onto `SYNTHETIC_MODULE` is correct because they guard *detection*, and coupling a detection guard to debt volume made paying off debt fail. The vacuity hole that move could have opened is closed by the new `test_tree_scan_reaches_the_test_suite` (>50 modules plus self-membership). No self-pollution: `_markers_in_source` inspects only `decorator_list`, so the markers inside the `SYNTHETIC_MODULE` string constant are invisible to the tree walk. Independently corroborated by `reviewer-test-analyzer`.
- **[VERIFIED]** The four unquarantined 143-9 xfails pass for the story's reason, not by accident — **only the `@pytest.mark.xfail` decorators were removed; no test body, assertion or fixture was touched** (diff `test_143_9_tdd_cycle_e2e.py`:644-680). The `project` fixture writes a six-phase `TDD_WORKFLOW` with `verify`/`tea` to `.pennyfarthing/workflows/tdd.yaml`, which the old dist-first resolver could not see; the packaged five-phase `tdd.yaml` answered and `verify` yielded `None`. Corroborated by `reviewer-test-analyzer`.
- **[VERIFIED][RULE]** Rule 8 exposure is **reduced**, not added — the literal `root / "pennyfarthing-dist"` at `prime/workflow.py`:51 consolidates five pre-existing occurrences (develop `prime/workflow.py`:157, 357, 400, 444, 513) into one, and is reached only when `get_dist_root()` returns `None`. `reviewer-rule-checker` found 0 violations across all 10 rules / 31 instances.
- **[VERIFIED]** Import-cycle claim holds: `grep -rn "pf.prime" src/pf/workflow/` returns nothing, `pf/workflow/__init__.py` imports only `scale` and `state`, and importing all four touched modules together succeeds.
- **[VERIFIED]** The ruff-format deviation is truthful — preflight independently confirmed via `git show develop:` that `complete_phase.py`, `resolve_gate.py` and `subagent/gate.py` all already failed `ruff format --check` on develop. `ruff check` passes on all five files.
- **[VERIFIED]** `pf.workflow.state.get_phase_owner` (the duplicate, dict-hardcoded function) was **not touched** — `git diff develop...HEAD -- src/pf/workflow/state.py` is empty. Correctly deferred to its own story.
- **[VERIFIED]** Suite is green: 6079 passed, 0 failed, 4 skipped, 0 xfailed. The 4 `test_frame_routes` failures TEA and Dev saw did not reproduce, consistent with them being environment-dependent (162-49). Working tree clean; both commits GPG-signed (RSA 5CAE68A3…1397).
- **[VERIFIED]** Malformed/agent-less overrides do **not** fall through for the six readers, as TEA pinned — probed a malformed top tier shadowing a valid lower tier and a flat-malformed/nested-valid collision within one tier; `get_phase_owner` returned `None` in both, never the packaged answer. The claim is structural for the readers. It is *not* uniform across the writers (MEDIUM-2).
- **[GOOD PATTERN]** Collapsing six hand-rolled path-guess blocks into one documented resolver (`prime/workflow.py`:22-53) is the right shape and nets −18 lines; it also incidentally gains nested-layout support at the dist tier for five readers that previously tried only flat `{name}.yaml`.

### Rule Compliance

| Rule | Applies | Instances checked | Result |
|------|---------|-------------------|--------|
| 1 — never edit `.pennyfarthing/` symlinks | Yes | 8 changed files | Compliant — all under `pennyfarthing-dist/src/pf/` |
| 2 — never edit sprint YAML directly | No | 0 | N/A — no sprint YAML in diff |
| 3 — never edit `node_modules/` | No | 0 | N/A |
| 4 — modify `pennyfarthing-dist/` | Yes | 8 | Compliant |
| 5 — `.js` extensions in TS imports | No | 0 | N/A — Python only (ADR-0034) |
| 6 — return result objects, don't throw | Yes | 13 functions | **2 violations** — `chain.py:197`, `gate.py:29` raise on malformed/empty YAML (MEDIUM-2). Other 11 compliant (`None`/`False`/`[]` on failure) |
| 7 — match model to task | No | 0 | N/A — no model selection in diff |
| 8 — runtime uses `.pennyfarthing/`, never `pennyfarthing-dist/` | Yes | 6 resolution paths | Compliant — 1 literal at `prime/workflow.py`:51, pre-existing and consolidated 5→1 |
| 9 — dogfood symlinks, edit source | Yes | 8 | Compliant |
| 10 — concise answers | No | 0 | N/A — communication rule |

### Devil's Advocate

Assume this fix is broken. The strongest case: it fixes the half of the problem that had tests and declares the other half solved by assertion. The epic's recurring defect is *two readers of one fact disagreeing*. Before this change the disagreement was project-vs-dist inside `prime`. After it, `prime` reads three tiers and the four writers read two — the asymmetry did not close, it moved. Dev's deviation entry names precisely this risk and then reasons its way past it with "writers must never stamp from dist," which sounds like a safety invariant but is a category error: the danger was ever letting dist *outrank* a project override, not letting dist serve as the base layer. Strip the rationale away and what remains is four functions that return "no workflow exists" for a workflow the reader in the same process just resolved successfully.

A malicious user needs no exotic input: a crafted session file with `**Workflow:** ../../../tmp/evil` reaches an unsanitized path join and makes any readable YAML on the box the phase-ownership authority — including the `agent:` field that decides whether `review` is owned by `reviewer` or by `sm`. Epic 162 already built the guard for exactly this shape and it was not applied to the function this diff funnelled every caller into.

A confused user fares worse, because their failure is silent. Anyone who `pip install`s or `npm install`s the framework and does not populate `.pennyfarthing/workflows/` gets a system where `pf` resolves phase owners correctly and then writes the wrong thing into the session file — `**Phase:** finish instead of `**Phase:** finish `| red (red) |` in the Handoff History — with no error, no warning, and no test that would notice. Subagent chaining and gate loading return `None` and simply do nothing. The bug `_validate_phase_names` was written to prevent is back for that entire class of installation.

A stressed filesystem exposes the last edge: an empty or half-written `tdd.yaml` (interrupted editor, truncated checkout) makes `chain.py` and `gate.py` raise `AttributeError` from `None.get` rather than degrade, and this diff newly points those two modules at a tier they could not previously reach. A broken symlink or an empty `{name}/` directory at the top tier quietly falls through to the packaged file, contradicting the resolver's own "first tier is authoritative" docstring — so the very invariant TEA wrote tests to defend has undocumented holes on both sides.

### Deviation Audit

- **TEA — reshaped two 162-5 anti-vacuity guards:** **ACCEPTED.** Verified the debt-policing tests still walk the real tree, the synthetic fixture pins detection with both accept and reject cases, and the new tree-reachability test closes the vacuity hole. Correct call, and it removed a genuine catch-22 for Dev.
- **TEA — pinned the `.pennyfarthing/project/workflows/` tier:** **ACCEPTED.** Reordering only two of three tiers would have reproduced the defect one tier up.
- **TEA — pinned "broken override must not fall through":** **ACCEPTED for the readers, FLAGGED as incomplete.** Structural and verified for the six readers, but the same requirement is unmet in `chain.py`/`gate.py`, which raise instead (MEDIUM-2), and the docstring's absolute phrasing does not survive broken symlinks or empty `{name}/` dirs (LOW).
- **Dev — extended the fix to the four writer modules:** **FLAGGED [HIGH].** The right instinct, executed halfway. Folding the writers onto `get_all_workflows_dirs` closed the project-tier skew and opened nothing new, but it left the dist-tier skew fully intact while the deviation text claims the disagreement is resolved. See HIGH-1.
- **Dev — did not reformat three pre-existing unformatted files:** **ACCEPTED.** Independently verified true at develop; `ruff check` passes; keeping a 6-line semantic change legible is the right trade.

### Reviewer (audit)

- **Undocumented deviation:** the fix silently adds nested-layout (`{name}/workflow.yaml`) support at the dist tier for five readers that previously accepted only flat `{name}.yaml` (`get_phase_owner`, `get_phase_tandem_config`, `get_phase_team_config`, `get_phase_skills`, `get_phase_gate_recovery`). Benign and arguably a fix, but it is a behaviour expansion beyond the story with no test at the dist tier and no deviation entry.

**Handoff:** Back to Dev

### Dev (rework 1)
- **Reversed my round-1 position on the writers reading dist:** Round 1 I wrote that the writers must stay project-only. That was wrong and the Reviewer's measurement proved it. Corrected to: one resolver, project tiers outrank dist, dist is the floor for readers and writers alike. Reason: the invariant that matters is *no two readers of one fact disagree*; "never read dist" broke that invariant while sounding like it protected one.
- **Extended past the four writers to three more resolution readers:** Scope named the writers. I also moved `handoff/cli.py`, `workflow/cli.py`'s story-workflow lookup and `peloton/live.py` onto the shared resolver. Reason: they read the same fact with fewer tiers, so leaving them would reproduce the exact asymmetry this round exists to close — the same mistake as round 1, one module over. `handoff/cli.py` was the worst of the three: single-tier, so it could not see `project/workflows/` either.
- **Did not extend to the eight stepped-workflow CLI sites:** They are the same defect class and I am not claiming otherwise. Left them and filed a Delivery Finding naming each line. Reason: separate command family, no coverage in this story's suite, and round 1's lesson is that a half-done sweep is worse than a named one.
- **Added `include_dist` as an opt-in flag rather than always including dist in `get_all_workflows_dirs`:** Reason: that function also backs enumeration (`pf workflow list`, and the gate's available-workflows hint). Always-on dist would silently change what those commands print — a product change smuggled inside a bug fix. Resolution gets the floor; enumeration keeps its current semantics unless deliberately opted in (`_list_available_workflows` opts in, because a gate hint that omits a resolvable name is a lie).
- **Reformatted the test file:** `ruff format` was already failing on `test_162_29_workflow_override_resolution.py` at HEAD (TEA's commit). Since I was adding 44 tests to it, I let the formatter run, which also joins two pre-existing lines outside my additions. Reason: the file is now format-clean and the collateral change is four lines of pure whitespace. Noting it so the diff's two unrelated hunks are not a surprise.

## Subagent Results

**Cycle: 1**

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 2 | confirmed 0, dismissed 2, deferred 0 |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 4 | confirmed 4, dismissed 0, deferred 0 |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | findings | 4 | confirmed 4, dismissed 0, deferred 0 |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 1, dismissed 0, deferred 1 |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | clean | 0 violations | confirmed 0, dismissed 0, deferred 0 |

**All received:** Yes
**Total findings:** 9 confirmed, 2 dismissed (with rationale), 1 deferred

Dismissals — both from `reviewer-preflight`, both measurement artifacts I reproduced and refuted:
- **"Dev's 4-failed claim is FALSE; 6123 passed / 0 failed, definitively"** — **dismissed.** Preflight ran pytest with cwd `pennyfarthing-dist/`, which contains no `.pennyfarthing/` directory. `frame/routes/data_proxy.py:35-42` resolves the project dir from `os.getcwd()` and returns a 404 at line 69 before reaching the broken call at line 72, so the 4 persona tests pass **vacuously**. Same command, cwd `pennyfarthing/` (the documented invocation): **4 failed, 6119 passed**. Same command with `PF_PROJECT_DIR` set: 4 failed. 6119 + 4 = 6123 — same tests, different cwd. Dev is right; preflight repeated my own cycle-1 mistake.
- **"6 ruff violations, status: blocked"** — **dismissed.** Preflight forced `--select=E,W,F,I`, enabling E501, which this project's config does not select. Under project config the 9 changed files yield **1** error (pre-existing E402 at `peloton/live.py:23`, down from 3 on develop). Not a blocker and not newly introduced.

Deferred: `reviewer-security`'s `_resolve_path` absolute-path sink (`helpers.py:219-226`) — real but pre-existing, not in this diff, stepped-workflow-only; filed as a Delivery Finding for the follow-up rather than expanded into this story.

## Reviewer Assessment

**Verdict:** APPROVED

The cycle-1 HIGH and both MEDIUMs are closed, and I verified each by measurement rather than by reading the diff. Everything remaining is polish or pre-existing, filed below.

**Data flow traced:** session file `**Workflow:** <value>` → `prime/workflow.py:140` (`result["workflow"] = value.lower()`, still unsanitized at the source) → `resolve_workflow_file` → `get_all_workflows_dirs(root, include_dist=True)` → `find_workflow_file`, where every candidate is now containment-checked by `is_contained_path` (`helpers.py:34-37`, `resolve()` + `is_relative_to`, fail-closed) before `yaml.safe_load`. Safe because sanitization moved to the sink that every caller shares, which is the right place for it — the traversal, absolute-path and symlink-escape payloads I landed in cycle 1 are all rejected while legitimate flat and nested names still resolve.

**Pattern observed:** one public `resolve_workflow_file` (`workflow/helpers.py:91-119`) is now the single precedence definition for readers and writers alike, with the old private competitor deleted from `prime/workflow.py` — verified no second three-tier resolver survives.

**Error handling:** `chain.py:197-211` and `gate.py:29-44` now wrap parse + `.get()` in `try/except`, returning `None` for all three failure shapes (malformed, empty, scalar) instead of raising `ParserError`/`AttributeError`.

### Observations

- **[VERIFIED] The HIGH is closed — measured in the npm layout that produced it.** Reader `get_phase_owner("tdd","red")` → `'tea'`, and now every writer agrees: `_get_phase_agent` → `'tea'` (was `'red'`), `_load_workflow_phases` → 5 phases (was `[]`), `_get_phase_tandem` → `None` correctly, `chain`/`gate._load_workflow_phases` → 5 phases (was `None`), `resolve_gate._find_workflow_yaml` → FOUND (was `None`), `_list_available_workflows` → 34 workflows (was `[]`). Decisively: `_validate_phase_names(root,"tdd","red","dev")` → `('red','green')`, where cycle 1 measured `('red','dev')`. The `**Phase:** finish reinstatement is gone.
- **[VERIFIED][SEC] CWE-22 closed, no false positives.** All four attack shapes → `None`: `../../outside/evil`, `../outside/evil`, an absolute path (the distinct mechanism where `Path.__truediv__` discards the base), and a valid symlink inside the tier pointing outside. Legitimate flat (`ok.yaml`) and nested (`nest/workflow.yaml`) both still resolve to `'tea'`, and the dogfood symlinked-dist layout resolves without tier duplication — so the guard did not silently break resolution, which was the likeliest way this fix could have gone wrong.
- **[VERIFIED][RULE] chain/gate degrade.** Probed malformed, empty and no-`workflow`-key: `chain` → `None`, `gate` → `None`, `prime` → `None`, `complete_phase` → `[]`. No raises. `reviewer-rule-checker` independently confirmed by reading, and `reviewer-test-analyzer` confirmed the three pinned shapes are genuinely distinct and include the `safe_load("") → None → AttributeError` case.
- **[TEST][VERIFIED] The traversal fixtures are genuinely discriminating, not vacuous.** `reviewer-test-analyzer` traced the fixture path arithmetic: all four payload files are actually created on disk at the path pre-fix code would have loaded, and the symlink target is real, so `candidate.exists()` was True pre-fix. This is the specific thing I was asked to distrust and it holds.
- **[TYPE][MEDIUM] The `include_dist=False` default leaves an enumeration disagreement of the same class.** Measured in npm layout: `resolve_workflow_file("tdd")` resolves, `resolve_gate._list_available_workflows` lists 34 — but `get_all_workflows_dirs(root)` (backing `pf workflow list` at `workflow/cli.py:341`) returns `[]`. So a consumer runs `pf workflow list`, sees nothing, and concludes no workflows exist while `tdd` is fully resolvable. `reviewer-type-design` independently flagged the same line and adds that `workflow_route_cmd` falls to `SystemExit(1)` for any story without an explicit `workflow:` field in that layout. Non-blocking — enumeration semantics are a defensible product call and this is pre-existing behaviour — but it is the epic's own pattern in the enumeration surface, so it belongs in the follow-up rather than in a docstring.
- **[MEDIUM] The named deferral is sound in principle but its inventory is incomplete.** The eight `workflow/cli.py` sites (145, 263, 462, 569, 735, 906, 1033, 1353) all use single-tier `get_workflows_dir()` — they miss `project/workflows/` *and* dist — and deferring them is the right call: separate command family, stepped workflows, zero coverage in this suite, and Dev's own "a half-done sweep is worse than a named one" reasoning. But two same-class sites are not in the named list: `workflow/cli.py:341` (route enumeration, above) and **`prime/loader.py:391-403`**, a hand-rolled two-tier project-then-dist resolver for stepped-workflow step files that also interpolates `workflow_name` into a path with no containment guard. `prime/loader.py` is in the story's own module family and in neither the deferral nor the recurrence guard.
- **[TEST][LOW] The recurrence guard is real but thinner than it looks — two evasion vectors.** `test_no_hand_rolled_workflows_path` asserts `'"workflows"' not in source`; I confirmed single-quoted `'workflows'` bypasses it entirely (ruff-format normalizes to double quotes here, so the practical risk is low). `test_no_two_tier_resolution` matches the collapsed token run `find_workflow_file(get_all_workflows_dirs`, which the natural two-statement refactor (`dirs = get_all_workflows_dirs(root)` then `find_workflow_file(dirs, name)`) evades. `reviewer-test-analyzer` reached the same two conclusions independently. On the false-block question I asked about: no module currently contains `"workflows"`, so it is not blocking legitimate code today, but a docstring or error string containing the word would trip it — acceptable for a tripwire with an actionable failure message.
- **[LOW] The guard's scope excludes the three modules this rework just swept.** `PHASE_OWNERSHIP_MODULES` lists 6 modules; `peloton/live.py`, `workflow/cli.py` and `prime/loader.py` are absent, so regressions in the sites Dev just fixed there are unguarded.
- **[TYPE][LOW] Nullability still diverges.** `chain`/`gate._load_workflow_phases` return `list|None`; `complete_phase._load_workflow_phases` returns `list` with `[]`. `_get_phase_agent` still returns `str`, using the phase name as a lookup-failure proxy — the structural conflation that made cycle 1's bug silent. Suppressed now that dist is reachable, but a malformed YAML at a resolvable tier still routes through it. Cosmetic today, worth fixing where the follow-up touches these.
- **[TEST][LOW] Six of seven writer callsites have an npm-layout regression test.** `complete_phase._get_phase_tandem` — explicitly one of the four in the cycle-1 HIGH — got the fix but not the dist-only test. Also, the parametrized reader-vs-writer equality test over five phases has a `None == None` tautology risk for phases other than `red`, shielded in practice because the packaged `tdd.yaml` contains all five.
- **[VERIFIED] Lint is a net improvement, not a regression.** Under project config the 9 changed files produce **1** ruff error — pre-existing E402 at `peloton/live.py:23`; that file had **3** errors on develop (E402 + 2×I001), so Dev fixed two. 4 files still fail `ruff format --check`; all 4 already failed at develop. Moving the `peloton/live.py` import above `logger` would zero it, which is a two-line cleanup for the follow-up.
- **[VERIFIED][RULE] Rule 8 exposure reduced again.** The `root / "pennyfarthing-dist"` literal now exists once, in `get_dist_workflows_dir` (`helpers.py:56`), consolidating the 6 occurrences that were in `prime/workflow.py` at the base commit. `reviewer-rule-checker`: 0 violations across all 10 rules / 47 instances.
- **[VERIFIED] The three additional readers were genuinely swept** — `handoff/cli.py:347`, `peloton/live.py:127,162`, `workflow/cli.py:325` all call `resolve_workflow_file`, and `handoff/cli.py` was previously single-tier (could not see `project/workflows/` either), so this was a real fix rather than churn.
- **[SEC][LOW, deferred] `_resolve_path` (`helpers.py:219-226`) returns `Path(path_str)` verbatim for absolute paths** taken from workflow YAML content, feeding `iterdir()` in `count_steps`/`find_step_file`. Pre-existing, not in this diff, stepped-workflow-only, requires write access to a workflows dir, read-only impact. The one unguarded sibling sink left in the module.
- **[VERIFIED] TOCTOU in `find_workflow_file`** (`exists()` then `is_contained_path()` are separate syscalls) is not exploitable — a symlink swapped between the calls is re-resolved by `is_contained_path` and rejected. There is no ordering where an in-scope `exists()` yields an out-of-scope `resolve()`. Noted for completeness only.

### Rule Compliance

| Rule | Applies | Instances | Result |
|------|---------|-----------|--------|
| 1 — never edit `.pennyfarthing/` symlinks | Yes | 9 changed files | Compliant — all under `pennyfarthing-dist/src/pf/` |
| 2 — never edit sprint YAML directly | No | 0 | N/A |
| 3 — never edit `node_modules/` | No | 0 | N/A |
| 4 — modify `pennyfarthing-dist/` | Yes | 9 | Compliant |
| 5 — `.js` extensions in TS imports | No | 0 | N/A — Python only |
| 6 — return result objects, don't throw | Yes | 14 functions | Compliant — cycle-1's 2 violations (`chain.py`, `gate.py`) fixed and probe-verified; `is_contained_path` fails closed |
| 7 — match model to task | No | 0 | N/A |
| 8 — runtime uses `.pennyfarthing/`, never `pennyfarthing-dist/` | Yes | 3 | Compliant — 1 literal in `get_dist_workflows_dir`, pre-existing, 6→1 |
| 9 — dogfood symlinks, edit source | Yes | 9 | Compliant |
| 10 — concise answers | No | 0 | N/A |

### Devil's Advocate

The case that this should still be rejected rests on the enumeration split. Dev made `resolve_workflow_file` the one true precedence definition and then carved out an exception: `get_all_workflows_dirs` defaults to omitting the floor tier. The justification — enumeration must not silently change — is a real product concern, but the consequence is that the codebase now holds two answers to "which workflows exist," and I measured them disagreeing 34 to 0 in the layout this story exists to support. A user in an npm project runs `pf workflow list`, sees an empty list, and is told by the same binary a moment later that `tdd` resolved fine. That is the epic's signature defect wearing different clothes, and a keyword-only flag defaulting to the unsafe value is precisely the footgun that produced the cycle-1 HIGH. The next developer who needs resolution and reaches for the obvious-looking `get_all_workflows_dirs` gets dist-blindness, and the recurrence guard watches only six modules — not `workflow/cli.py`, not `peloton/live.py`, not `prime/loader.py`, the three places this rework just touched.

Push further and the guard itself is a string match. Single-quote the literal and it sees nothing; split the two-tier call across two statements and it sees nothing. It reads as a structural invariant and is really a copy-paste tripwire.

What holds this back from a rejection is that none of it is a fail-open and none of it is new. Every disagreement I just described existed on develop and exists identically at HEAD; this rework strictly reduced the disagreement surface rather than moving it. The session-corrupting path — the one that stamps agent names into `**Phase:**` and silently disables `_validate_phase_names` — is closed and I measured it closed at all seven writer callsites. The traversal is closed against four distinct payloads with no false positives on legitimate names, verified against the real dogfood symlink layout where a naive containment check would have broken everything. The deferral is named with line numbers instead of quietly skipped, which is the behaviour I asked for in cycle 1. Rejecting a second time over enumeration polish and a tripwire's quoting style would be scope creep dressed as rigour, and it would spend a round-trip on findings that the follow-up story is the right home for.

### Deviation Audit

- **Dev — reversed the round-1 position on writers reading dist:** **ACCEPTED**, and worth crediting: the correction is stated plainly, the reasoning ("the invariant is that no two readers of one fact disagree") is the right one, and I verified the outcome by measurement rather than taking the claim.
- **Dev — extended to three more resolution readers (`handoff/cli.py`, `workflow/cli.py` story lookup, `peloton/live.py`):** **ACCEPTED.** Verified all three now call `resolve_workflow_file`; `handoff/cli.py` was single-tier, so this closed a real gap rather than adding churn.
- **Dev — did not extend to the eight stepped-workflow CLI sites:** **ACCEPTED with a flag.** The deferral reasoning is sound and naming the lines is exactly right. Flagged only because the inventory misses `workflow/cli.py:341` and `prime/loader.py:391-403`; both must join the follow-up.
- **Dev — `include_dist` as an opt-in flag:** **ACCEPTED as a judgment call, FLAGGED as a residual.** Not smuggling a product change into a bug fix is the correct instinct, and opting `_list_available_workflows` in because "a gate hint that omits a resolvable name is a lie" is good reasoning. But the same argument applies to `pf workflow list`, and the flag's default is the unsafe one. Filed, not blocked.
- **Dev — reformatted the test file:** **ACCEPTED.** Four lines of whitespace, disclosed in advance, file is now format-clean.

### Reviewer (audit)

- **Correction to my own cycle-1 assessment.** I labelled the 4 `test_frame_routes` failures "environment-dependent (162-49)" and reported a clean 6079/0. That was wrong. They are a real, deterministic break — `frame/routes/data_proxy.py:72` calls `load_persona(project_dir, session_id=session_id)` while `prime/persona.py:93` defines `load_persona(agent_name, project_root=None)`, a plain `TypeError`. My clean number came from running pytest with cwd `pennyfarthing-dist/`, where `_detect_pf_project` finds no `.pennyfarthing/` and the route short-circuits to a 404 before reaching the broken call. Not an installed-package shadow: `pf.__file__` resolves to the source tree under every invocation I tried. Dev was right and I was wrong.
- **The suite's result depends on the working directory**, which is a pipeline-honesty problem larger than this story: 4 tests pass vacuously from one cwd and fail correctly from another, and `reviewer-preflight` reached the same false conclusion I did this cycle. Filed as a Delivery Finding.

**Handoff:** To SM for finish-story