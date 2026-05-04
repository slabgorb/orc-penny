---
story_id: "151-3"
jira_key: "MSSCI-17082"
epic: "MSSCI-17079"
workflow: "tdd"
---

# Story 151-3: story update locates stories across epic-*.yaml; story finish fails loudly on yaml-update error

## Story Details
- **ID:** 151-3
- **Jira Key:** MSSCI-17082 (skipped — project uses kanban, created locally)
- **Epic:** MSSCI-17079 (Sprint YAML write correctness)
- **Workflow:** tdd
- **Points:** 3
- **Stack Parent:** none
- **Implementation Repo:** pennyfarthing
- **Branch:** feat/151-3-story-update-shard-aware (on develop)

## Context

This story addresses a critical bug in sprint story management where `story update` and `story finish` commands fail when stories are stored across sharded epic-*.yaml files. The issue manifests in:

1. **Problem:** Story lookup and update operations assume stories are in a single sprint YAML file, but the framework uses sharded epic-*.yaml files
2. **Impact:** `story finish` fails loudly with yaml-update errors when trying to locate and update stories across multiple shards
3. **Root locations:** Implementation at `pennyfarthing-dist/src/pf/`:
   - `jira/bidirectional.py` — `execute_sync_plan()`, `_update_story_in_sprint()`
   - `sprint/yaml_io.py` — YAML write/read operations

**See SM patterns sidecar:** `sprint-yaml-sharded` for detailed bug context.

## Workflow Tracking

**Workflow:** tdd
**Phase:** spec-check
**Phase Started:** 2026-05-04T14:41:55Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-05-04T13:45:57Z | 2026-05-04T13:47:52Z | 1m 55s |
| red | 2026-05-04T13:47:52Z | 2026-05-04T14:09:54Z | 22m 2s |
| green | 2026-05-04T14:09:54Z | 2026-05-04T14:41:55Z | 32m 1s |
| spec-check | 2026-05-04T14:41:55Z | - | - |

## Delivery Findings

<!-- Append-only. Each agent appends under their own subheading. -->

### TEA (test design)

- **Conflict** (non-blocking): SM scope claims AC1 (shard-aware `update_story`) and AC4 (shard-aware `execute_sync_plan`) are open bugs.
  Affects `pennyfarthing-dist/src/pf/sprint/story_update.py` and `pennyfarthing-dist/src/pf/jira/bidirectional.py` (no change required — they already use `read_sprint`/`write_sprint`, which are shard-aware).
  The SM patterns sidecar entry `sprint-yaml-sharded` is stale; the bug it describes was already fixed before this story landed. 13 passing regression tests in `test_151_3_yaml_write_correctness.py` document the correct current behavior. Worth updating the sidecar after merge.
  *Found by TEA during test design.*

- **Improvement** (non-blocking): `_extract_jira_key` in `pennyfarthing-dist/src/pf/sprint/story_finish.py` (line 78) hard-codes `^PROJ-\d+$` and silently returns None for any other prefix (e.g., `MSSCI-17082`).
  Affects all stories whose Jira key uses a non-`PROJ` project prefix.
  This project's stories use `MSSCI-`; finish skips Jira transitions with no warning. Out of scope for 151-3 (does not affect YAML write correctness) but worth filing as a follow-up.
  *Found by TEA during test design.*

- **Gap** (non-blocking): `pf validate context-story {story_id}` referenced in the TEA agent definition does not exist as a CLI subcommand.
  Affects `pennyfarthing-dist/src/pf/validate/cli.py` and the TEA `<on-activation>` block.
  Available validators are `adr, agent, architecture, context, prd, schema, skill-command, sprint, tandem-awareness, theme, version, workflow`. Either add `context-story` as a per-story validator or update the agent definition to call `pf validate context` (project-level). Project-level passed (3/0/0) so I proceeded.
  *Found by TEA during test design.*

- **Improvement** (non-blocking): The `PostToolUse:Edit` sprint-YAML validation hook runs an inline Node script that does `import yaml`, but the orchestrator repo has no `node_modules` — `package.json` and `package-lock.json` are deleted.
  Affects the project-level Claude hook configuration (not in 151-3 scope).
  Every sprint YAML edit produces a misleading `ERR_MODULE_NOT_FOUND` error. Real validation via `pf sprint validate` works. Either restore Node deps or migrate the hook to call `pf sprint validate`.
  *Found by TEA during test design.*

## Design Deviations

### TEA (test design)

- **AC1, AC2, AC4 already implemented in current code; tests written as regression coverage rather than RED.**
  - Spec source: SM Assessment in 151-3-session.md, AC1/AC2/AC4
  - Spec text: "AC1: succeeds when story X-Y lives in sprint/epic-*.yaml shard"; "AC2: returns non-zero and prints a clear error"; "AC4: updates shard stories the same as top-level"
  - Implementation: 12 of the 13 ACs-passing tests run against unchanged production code and validate already-correct behavior; only AC3 (loud finish failures) drives the RED set (4 failing tests).
  - Rationale: Spec authority hierarchy says session scope wins. The session ACs were derived from a stale patterns sidecar. Rather than skip ACs that turned out green, I kept the assertions as regression coverage so a future regression in the shard-aware path will fail loudly. RED set is the genuine bug surface (silent except in `story_finish.py`).
  - Severity: minor
  - Forward impact: Dev should focus on `pf/sprint/story_finish.py` only — no changes required to `update_story` or `execute_sync_plan`.

- **No `pf validate context-story` gate enforced before test design (validator does not exist).**
  - Spec source: TEA agent definition `<on-activation>` step 2
  - Spec text: "pf validate context-story {story_id} — Exit 0: proceed; Exit 1 or 2: STOP"
  - Implementation: Ran project-level `pf validate context` (3 passed, 0 errors) and proceeded using the embedded `## SM Assessment` block in the session file as story context.
  - Rationale: The named CLI subcommand does not exist (filed as Gap delivery finding). Stopping would block the entire workflow on a tooling gap rather than a genuine missing-context problem. The session file contains explicit ACs, scope, out-of-scope, and implementation surface — sufficient for test design.
  - Severity: minor
  - Forward impact: Filed under Delivery Findings → Gap. Workflow can proceed; tooling gap should be patched separately.

### Dev (implementation)

- **Updated 2 pre-existing tests in `tests/python/test_story_finish.py` to mock `transition_story`.**
  - Spec source: TEA test `test_finish_unknown_story_returns_failure` and SM Assessment AC3
  - Spec text: AC3 — "story finish returns non-zero and prints a clear error when YAML write fails (e.g., target story not found in any shard, write permission, schema invalid). No silent success."
  - Implementation: `test_removes_session_file` and `test_no_jira_key_still_succeeds` now patch `pf.sprint.story_finish.transition_story` to return `{"success": True, "to_status": "done"}` so they exercise their real intent (session-file cleanup, no-jira-key path) instead of relying on the silent-success behaviour AC3 is removing.
  - Rationale: Without the mock both tests went green only because pre-fix `finish_story` always returned `success=True` — they were testing the bug AC3 explicitly forbids. The original 83-2 fixture has `status: planning`, which is not a legal source state for `transition_story("done")`; story 99-1 was not in the YAML at all. Mocking is the smallest possible change that preserves each test's stated intent (per its name / comment) while letting AC3's loud-failure contract hold elsewhere. Adjusting the shared `project_tree` fixture would have rippled through `test_dry_run_no_side_effects`, which asserts the literal text `status: planning` in the shard.
  - Severity: minor
  - Forward impact: 4 pre-existing failing tests in `test_story_finish.py` / `test_jira_bidirectional_sync.py` remain — `test_dry_run_returns_steps`, `test_updates_story_status_to_done`, `test_returns_steps_on_success`, `test_module_exists`. Unrelated to 151-3 (count mismatch, fixture state issues, wrong import path). Worth a separate cleanup story.

- **Did NOT modify the `try / except: pass` block around `_add_story_to_completed` (lines 297-308 of pre-fix code).**
  - Spec source: TEA Implementation Hint #3
  - Spec text: "Verify story exists in YAML before declaring success. If `find_story` returns `None` after `read_sprint`, surface that as a failure rather than swallowing it under the `try / except Exception: pass` blocks at lines 297-308."
  - Implementation: The `try: data = read_sprint(...); ...; except Exception: pass` block is left untouched. The new `transition_story` short-circuit guarantees execution does not reach this block when the story is missing from YAML — `transition_story` already returns `{"success": False}` for missing stories and my new short-circuit returns before line 297.
  - Rationale: Two reasons. (a) `_add_story_to_completed` is a *secondary* aggregation step — its own internal `try/except: pass` is annotated `Non-fatal — findings collection has fallback strategies` (line 56). Adding a second loud-failure layer above it would invert that explicit design choice. (b) All 17 of TEA's tests already pass without changing this block — the missing-story scenario is caught one level up at `transition_story`. Editing additional code without a failing test driving the change violates Dev minimalist-discipline.
  - Severity: minor
  - Forward impact: If a future story needs `_add_story_to_completed` failures to be loud it should add a test driving that contract and revisit the line-56 docstring first.

## SM Assessment

**Routing:** TDD phased workflow (3 pts, P0 framework reliability bug). Next agent: TEA for RED phase.

**Scope (what TEA must produce failing tests for):**
1. `pf sprint story update` must locate stories in sharded epic-*.yaml files, not just `current-sprint.yaml`. Cover: `--status`, `--points`, `--assigned-to`, and other field updates.
2. `pf sprint story finish` must detect and surface YAML write failures loudly — no silent skip when the target story can't be found.
3. `execute_sync_plan` in `jira/bidirectional.py` must use the same shard-aware loader/writer that `load_sprint`/`write_sprint` use, not raw `current-sprint.yaml` reads.

**Implementation surface (do not implement — this is for context):**
- `pennyfarthing-dist/src/pf/sprint/yaml_io.py` — canonical loader/writer (`load_sprint`, `write_sprint`)
- `pennyfarthing-dist/src/pf/jira/bidirectional.py` — `execute_sync_plan`, `_update_story_in_sprint` (the silent-skip site)
- `pennyfarthing-dist/src/pf/sprint/story.py` (or wherever `update`/`finish` CLIs live)

**Out of scope:** Refactoring the sharded layout itself; new CLI flags; Jira-side behavior changes (project is kanban / Jira is fiction-locally per project memory).

**Acceptance criteria (TEA, expand into tests):**
- AC1: `pf sprint story update X-Y --status canceled` succeeds when story X-Y lives in `sprint/epic-*.yaml` shard, not `current-sprint.yaml`. Verified by reading the shard back.
- AC2: `pf sprint story update` returns non-zero and prints a clear error when STORY_ID does not exist in any shard or in `current-sprint.yaml`.
- AC3: `pf sprint story finish` returns non-zero and prints a clear error when YAML write fails (e.g., target story not found in any shard, write permission, schema invalid). No silent success.
- AC4: `execute_sync_plan` updates shard stories the same as top-level `current-sprint.yaml` stories — no silent skip.
- AC5: Existing `current-sprint.yaml`-only story paths still work (regression).

**Repo:** pennyfarthing (gitflow, target `develop`).

**Jira:** MSSCI-17082 not yet created in Jira — local-only kanban story. No Jira claim performed.

**Branch:** `feat/151-3-story-update-shard-aware` (created on develop).

I think we should follow the process, sir. It's the law.
---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story is a 3-pt P0 framework reliability fix; the loud-failure contract for `pf sprint story finish` must be pinned in a regression test before any implementation touches `story_finish.py`.

**Test Files:**
- `pennyfarthing/tests/python/test_151_3_yaml_write_correctness.py` — 17 tests across 4 classes, covering all 5 ACs and the lang-review §1 (silent except) rule.

**Tests Written:** 17 tests covering 5 ACs
**Status:** RED (4 failing tests, 13 passing — see breakdown below)

### Failing tests (the bug surface for Dev)

All 4 failures are in `TestFinishStoryLoudFailures` and target `pennyfarthing-dist/src/pf/sprint/story_finish.py`:

| Test | What it pins |
|------|---------------|
| `test_finish_returns_failure_when_transition_fails` | When `transition_story` returns `success=False`, `finish_story` must propagate `success=False` (today it appends a `warning` to `steps` and returns `success=True`). |
| `test_finish_unknown_story_returns_failure` | When the story_id does not exist in any shard / standalone / top-level list, `finish_story` must return `success=False` (today it returns `success=True` with a warning). |
| `test_finish_does_not_silently_swallow_read_sprint_errors` | When `read_sprint` raises, `finish_story` must surface the failure (today the bare `except Exception: current_status = "in_progress"` swallows it). |
| `test_story_finish_module_has_no_bare_except_pass_yaml_read` | Static check on `story_finish.py` source: the `try / read_sprint / except Exception: current_status = ...` block (lines ~241-250 of pre-fix code) must be gone. |

### Passing tests (regression coverage — keep green)

| Class | Count | What's covered |
|-------|-------|---------------|
| `TestUpdateStoryWritesShardFile` | 5 | AC1+AC5 — `update_story` writes status/points/assigned_to back to the shard file, doesn't corrupt sibling stories, top-level `stories:` list still works. |
| `TestUpdateStoryNotFound` | 4 | AC2 — unknown story returns `success=False`, error includes story id, YAML untouched, CLI exits non-zero. |
| `TestSyncPlanShardAware` | 4 | AC4 — `execute_sync_plan` and `_update_story_in_sprint` find and persist shard story changes; unknown jira key does not falsely report `changes_applied`. |

### Rule Coverage (lang-review/python.md)

| Rule | Test(s) | Status |
|------|---------|--------|
| §1 Silent exception swallowing | `test_finish_does_not_silently_swallow_read_sprint_errors`, `test_story_finish_module_has_no_bare_except_pass_yaml_read` | failing (RED) |
| §6 Test quality | Self-checked: every test has at least one specific `assert` — no `assert True`, no `assert is_some`, no truthy-only checks. Each failing assertion includes a contextual message explaining what contract is broken. | passing |

**Rules checked:** 2 of 8 lang-review rules apply directly to this story. The remaining rules (mutable defaults, type annotations, logging, path handling, resource leaks, unsafe deserialization) are not implicated by the diff Dev will produce — silent-exception is the only one in scope.

**Self-check (vacuous tests):** 0 vacuous assertions found in the 17 tests. Every `assert` checks a specific value or specific failure mode.

### Spec authority resolution

The session-level SM Assessment (highest authority) lists 5 ACs. Investigation showed AC1/AC2/AC4/AC5 are already met in current code — only AC3 has a real bug. Per `<spec-authority>` hierarchy, I logged the conflict against the SM patterns sidecar (lower authority) under Design Deviations and kept all 5 ACs covered. Tests for already-met ACs serve as regression coverage and will fail if Dev's fix accidentally regresses the shard-aware paths.

### Implementation hint for Dev (Ponder Stibbons)

`pennyfarthing-dist/src/pf/sprint/story_finish.py` needs three changes (all in `finish_story()`):

1. **Remove the bare-`except Exception:` block at lines 241-250** that silently sets `current_status = "in_progress"` on `read_sprint` failure. Replace with explicit handling that returns `{"success": False, "error": ...}`.

2. **Track transition failures.** When `transition_story()` returns `success=False`, accumulate the error and return `{"success": False, "error": ..., "steps": [...]}` from `finish_story` instead of appending a warning to `steps` and returning `success=True`.

3. **Verify story exists in YAML before declaring success.** If `find_story` returns `None` after `read_sprint`, surface that as a failure rather than swallowing it under the `try / except Exception: pass` blocks at lines 297-308.

Out-of-scope for this story: the `_extract_jira_key` PROJ-only regex (Delivery Finding 2), the broken Node yaml hook (Delivery Finding 4), the missing `context-story` validator (Delivery Finding 3). Each warrants its own story.

### Test execution evidence

```
tests/python/test_151_3_yaml_write_correctness.py
  TestUpdateStoryWritesShardFile (5 PASS)
  TestUpdateStoryNotFound (4 PASS)
  TestFinishStoryLoudFailures (4 FAIL — RED state confirmed)
  TestSyncPlanShardAware (4 PASS)

  4 failed, 13 passed in 0.29s
```

Run command (uv-based, no editable install needed in repo venv):

```
uv run --with 'pytest>=8' --with 'pytest-asyncio>=1' --with 'pytest-mock' \
  --with 'pyyaml' --with 'ruamel.yaml' --with 'httpx' --with 'click' \
  --with 'pydriller' --with 'textual' --with 'websockets' --with 'textual-image' \
  --with 'watchfiles' --with 'fastapi' --with 'uvicorn[standard]' \
  --with-editable pennyfarthing-dist -- python -m pytest \
  tests/python/test_151_3_yaml_write_correctness.py -v
```

**Handoff:** To Dev (Ponder Stibbons) for GREEN — make the 4 failing tests pass without breaking the 13 regression tests.

A good Igor ith never without thpare tetht patternth.
---

## Dev Assessment

**Implementation Complete:** Yes
**Status:** GREEN (17/17 of 151-3 tests passing; 4 pre-existing failures in adjacent files unchanged)

### Files Changed

| File | Change | Lines |
|------|--------|-------|
| `pennyfarthing-dist/src/pf/sprint/story_finish.py` | Replaced two silent-exception sites with explicit failure propagation | +21 -8 |
| `tests/python/test_story_finish.py` | Updated 2 pre-existing tests that depended on the silent-success bug now being fixed | +18 -3 |

### Implementation Summary

Two changes inside `finish_story()`, both small:

1. **`read_sprint` failure path (was lines 241-250).** The bare `try/except Exception: current_status = "in_progress"` is replaced with a narrowed `except (FileNotFoundError, ValueError) as exc` that returns `{"success": False, "error": "Failed to read sprint YAML at ...", "steps": steps}`. Other exception classes propagate naturally — those represent programming errors, not file-state errors. This satisfies AC3's "loud failure on YAML read errors" and lang-review §1's "no silent exception swallowing".

2. **`transition_story` failure short-circuit (was after line 296).** When `t_result.get("success")` is False, after appending the diagnostic warnings to `steps` the function now returns `{"success": False, "error": t_result.get("error", "Transition failed"), "steps": steps, ...}` instead of falling through to step 4b/4c/5/6/7. Destructive cleanup (archive_epics, git checkout/pull/branch -d, session removal) only runs on real success. This satisfies AC3's "loud failure on YAML write / transition failure".

The `try/except: pass` block at lines 297-308 around `_add_story_to_completed` is intentionally left alone — it's a non-destructive secondary operation and only runs after the success path is confirmed by the short-circuit above. TEA's tests do not require it to fail loudly, and changing it would be scope creep.

### Test Outcomes

```
tests/python/test_151_3_yaml_write_correctness.py
  TestUpdateStoryWritesShardFile (5 PASS)
  TestUpdateStoryNotFound (4 PASS)
  TestFinishStoryLoudFailures (4 PASS)  <- previously RED, now GREEN
  TestSyncPlanShardAware (4 PASS)

  17 passed in 0.15s
```

Adjacent suites (`test_story_finish.py`, `test_jira_bidirectional_sync.py`, `test_sprint_story_command.py`):

```
4 failed, 88 passed in 1.26s
```

The 4 failures are **pre-existing on `develop`**, unrelated to 151-3:

| Test | Pre-existing reason |
|------|---------------------|
| `test_story_finish.py::TestFinishStoryDryRun::test_dry_run_returns_steps` | Asserts `len(steps) == 7` but dry-run path emits 8 steps (counting bug in test). |
| `test_story_finish.py::TestFinishStoryYamlUpdate::test_updates_story_status_to_done` | Fixture has 83-2 in `status: planning` which can't legally transition to `done`. |
| `test_story_finish.py::TestFinishStoryErrors::test_returns_steps_on_success` | Same fixture issue — relies on transition succeeding for `planning` status. |
| `test_jira_bidirectional_sync.py::TestModuleImport::test_module_exists` | Looks for `pf/jira/bidirectional.py` at the wrong path (no `pennyfarthing-dist/src/` prefix). |

Verified by stashing my changes and running the same test set — same 4 failures appear without 151-3 in place. Each warrants a follow-up but is out of scope for this story.

Full `pennyfarthing-dist/src/pf/tests/` run: **4357 passed, 21 pre-existing failed, 4 errored** (build/packaging, environment-dependent). None of the 21 failures touch `story_finish.py`, sprint YAML write paths, or any code I modified — they're spread across agent-validator, TDD-cycle E2E, reviewer-gate-clarity, peloton-pane, and PyPI-packaging suites.

### PR

Not created. Per Dev workflow definition, PR creation is SM's responsibility in the finish phase.

**Branch:** `feat/151-3-story-update-shard-aware` (pushed to origin, 2 commits: `97271dc2b` test + `80517fa9a` impl).

### Handoff

To Reviewer (Granny Weatherwax) — review the failure-propagation contract change in `story_finish.py` and confirm the test-fixture update doesn't mask any other behavior change.

By the High Energy Magic, the silent failures are now loud.

## Architect Assessment (spec-check)

**Spec Alignment:** Drift detected — **CRITICAL**
**Mismatches Found:** 4
**Decision:** Hand back. Do not proceed to verify.

### Root Cause

The branch `feat/151-3-story-update-shard-aware` was created from merge-base `2ad627cfa` (the merge of PR #31, story 151-2). After that point, develop received commit `b5d00bbd4` — **PR #33 "MSSCI-17082 - feat(sprint): story update locates stories across epic-*.yaml; story finish fails loudly on yaml-update error"** — which addresses the SAME Jira key (MSSCI-17082) and the SAME ACs as this story. Neither SM nor TEA nor Dev noticed develop had moved forward with an in-flight resolution of the same scope.

The branch is now ~3 days behind develop on exactly the files this story touches, and a `develop..feat/151-3` diff REVERSES large portions of the already-merged fix.

### Mismatches

- **Reverts shard-aware bidirectional sync (`_update_story_in_sprint`)** (Missing in code — Behavioral, **Critical**)
  - Spec (AC4): "execute_sync_plan updates shard stories the same as top-level current-sprint.yaml stories — no silent skip."
  - Code on develop: `_update_story_in_sprint` searches `epics[].stories`, `standalone_stories`, AND top-level `stories` list.
  - Code on feat/151-3: searches ONLY `epics[].stories`. The `standalone_stories` and `stories` branches are removed; `Mapping` import gone; helper `_apply` gone.
  - Recommendation: **B — Fix code.** Rebase onto develop; this code already exists upstream.

- **Reverts loud-error reporting in `execute_sync_plan`** (Missing in code — Behavioral, **Critical**)
  - Spec (AC4): "no silent skip" when `_update_story_in_sprint` returns False.
  - Code on develop: appends `f"{change.key}: story not found in sprint YAML — {change.field} update was not applied"` to `result.errors`.
  - Code on feat/151-3: the `else: result.errors.append(...)` block is deleted — failures revert to silent skip.
  - Recommendation: **B — Fix code.** Rebase onto develop.

- **Reverts step-entry error structure in `finish_story` else-branch** (Different behavior — Behavioral, **Major**)
  - Spec (AC3): "returns non-zero and prints a clear error when YAML write fails. No silent success."
  - Code on develop: step entries on the failure path use `"success": False, "error": transition_error`; final return uses `f"yaml-update step failed during finish: {transition_error}"`.
  - Code on feat/151-3: step entries demoted to `"warning": ...` (no explicit `success: False`); final return error loses the `"yaml-update step failed during finish: "` prefix.
  - This is *technically* still loud (top-level `success: False` is preserved), but consumers inspecting `steps[].success` will see no failure flag, and the error string loses context. Net regression in observability.
  - Recommendation: **B — Fix code.** Rebase onto develop.

- **Replaces existing 607-line test file with a 503-line one** (Different behavior — Architectural, **Major**)
  - Spec source: TEA Assessment / git history.
  - Code on develop: `tests/python/test_151_3_sharded_update_and_finish_loud.py` (607 lines, 18 tests, all passing on develop).
  - Code on feat/151-3: the file is deleted and replaced with `test_151_3_yaml_write_correctness.py` (503 lines, 17 tests). Coverage overlaps but is not a strict superset (e.g., the developed tests for `standalone_stories` shard-aware bidirectional updates are gone).
  - Recommendation: **B — Fix code.** Rebase onto develop and keep the existing test file. If the new file adds value beyond the existing one, ADD missing tests rather than DELETE existing ones.

### Genuine Net-New Value on This Branch

Exactly one improvement is novel: **narrowing the bare `except Exception` around `read_sprint(sprint_path)` to `except (FileNotFoundError, ValueError)`** with an explicit `success: False` return. Develop still has the bare `except Exception: current_status = "in_progress"` silent swallow. This change is correct and worth preserving — but it's a ~10-line chore-sized change, not a 3-point story.

### Required Action (hand-back to SM)

1. **Abort the current implementation.** Do not merge `feat/151-3-story-update-shard-aware` as-is — it would revert PR #33's fixes for AC2 / AC4 and the step-entry contract for AC3.
2. **Reconcile with develop.** Story MSSCI-17082 / 151-3 is materially complete on develop already. Verify b5d00bbd4 against the 5 ACs:
   - AC1 (shard-aware update_story): met by existing read/write_sprint shard merging.
   - AC2 (update returns non-zero on missing): worth confirming with a regression test if not already present.
   - AC3 (finish loud failure on YAML error): mostly met — only the `read_sprint` bare-except remains a silent swallow site.
   - AC4 (execute_sync_plan shard-aware): met by b5d00bbd4.
   - AC5 (regression of top-level path): met.
3. **Rescope as a chore.** The remaining genuine bug (bare `except Exception` around `read_sprint`) is small. Either:
   - Cherry-pick commit `80517fa9a`'s read_sprint narrowing onto develop as a `chore` / sub-1-pt patch, OR
   - Mark 151-3 as "delivered upstream by PR #33" in sprint YAML and close.
4. **Update Delivery Findings.** TEA's note that "AC1, AC2, AC4 already implemented in current code" was the canary — that observation should have triggered a base-branch verification before RED phase began. Add a `pf-check` style preflight in the SM/setup phase: `git merge-base HEAD origin/develop` vs `git log origin/develop --since=<sprint-start> -- <implementation surface>` to flag stories whose scope has been overtaken upstream.

### Spec-Reconcile Carry-Forward

If/when this story resumes after rebase, spec-reconcile (post-review) will need to add deviation entries for the work done by b5d00bbd4 retroactively (since those changes ARE the implementation). I'm flagging this now to avoid a duplicate audit-trail surprise later.

The spec-check gate above (`pf handoff resolve-gate`) returned `status: ready` — but that gate checks structural alignment (ACs listed, Dev complete flag set, deviation subsections formatted), not branch-base correctness. The structural checks pass; the substance does not.

I am not proceeding to `complete-phase` or `marker`. Returning control to SM (Captain Carrot Ironfoundersson) for rebase and rescope.

Oh dear, I appear to have invented the same machine twice. Modo, fetch the gardening shears — this branch needs pruning.