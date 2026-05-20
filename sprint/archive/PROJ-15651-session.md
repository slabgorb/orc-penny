# Story 132-15: Add practice story to guided tour sprint step

**Story ID:** 132-15
**Jira:** PROJ-15651
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/132-15-practice-story-guided-tour-sprint
**Assigned:** keith.avery@slabgorb.io

## Acceptance Criteria

1. Running the guided tour step 4 creates a practice epic and story in sprint YAML
2. Developer can claim the practice story with `pf sprint work tour-practice-1`
3. Developer can make a trivial edit and complete the story with `pf sprint story finish tour-practice-1`
4. `pf sprint status` shows the practice story progressing through backlog -> in_progress -> done
5. All practice artifacts are cleaned up before proceeding to step 5
6. The practice flow works without Jira configured (local-only mode)
7. Sprint validation passes both during and after the practice exercise
8. If the tour is interrupted mid-practice, resuming the tour or running cleanup detects and removes orphaned artifacts
9. The "Try It" and "Dig In" switch options still work alongside the new practice section
10. Existing step-04 explanatory content is preserved — the practice section augments, not replaces

## Context

This story transforms the guided tour's step-04-sprint from a passive explanation into a hands-on exercise. The developer creates a practice epic/story, claims it, makes an edit, completes the story, then cleans up — experiencing the full sprint lifecycle.

### Technical Approach

1. **Create practice lifecycle module** at `pennyfarthing-dist/src/pf/tour/practice.py` with `create_practice_epic()`, `cleanup_practice()`, and `detect_orphaned_practice()` functions
2. **Create practice epic template** at `pennyfarthing-dist/workflows/guided-tour/templates/epic-tour-practice.yaml`
3. **Modify step-04-sprint.md** to add the practice exercise between the existing explanations and the deep-dive section
4. Key design choices: Option A (temporary shard file), trivial workflow, no Jira, `tour_artifact: true` marker, idempotent cleanup

## Key Files

- `pennyfarthing/pennyfarthing-dist/workflows/guided-tour/steps/step-04-sprint.md` — Modify to add practice section
- `pennyfarthing/pennyfarthing-dist/src/pf/tour/practice.py` — Create practice lifecycle module
- `pennyfarthing/pennyfarthing-dist/workflows/guided-tour/templates/epic-tour-practice.yaml` — Create practice epic template
- `pennyfarthing/pennyfarthing-dist/workflows/guided-tour/workflow.yaml` — Possibly add practice_epic_id variable

## Story Context File

See `sprint/context/context-132-15.md` for full technical approach, key files, and implementation details.

## SM Assessment (setup)

Story setup complete. Session file created, Jira claimed (PROJ-15651), branch `feat/132-15-practice-story-guided-tour-sprint` created from `develop` in pennyfarthing repo. Context file at `sprint/context/context-132-15.md` has full technical details. 3-point story with 10 ACs — creating practice lifecycle module, epic template, and modifying step-04-sprint.md. Ready for TEA to design tests.

## TEA Assessment (red)

**Tests Required:** Yes
**Test File:** `pennyfarthing-dist/src/pf/tests/test_tour_practice.py`
**Tests Written:** 34 tests covering all 10 ACs
**Status:** RED (all 34 failing — 2 assertion failures, 32 fixture errors for missing files)

Test classes:
- `TestPracticeEpicTemplate` (9 tests) — AC1, AC6, AC7: template YAML structure, tour_artifact marker, null jira, trivial workflow, minimal points
- `TestPracticeModule` (7 tests) — AC1, AC5, AC8: create_practice_epic(), cleanup_practice(), detect_orphaned_practice() functions and signatures
- `TestStepFourPracticeSection` (6 tests) — AC2, AC3, AC4: practice exercise with sprint work/finish commands, status progression
- `TestCleanupInstructions` (3 tests) — AC5: cleanup section, shard removal, session removal
- `TestExistingOptionsPreserved` (2 tests) — AC9: Try It and Dig In switch options preserved
- `TestExistingContentPreserved` (3 tests) — AC10: sprint hierarchy, status demo, Jira mention preserved
- `TestSprintValidationTolerance` (4 tests) — AC7: standard fields present, correct statuses

**Handoff:** To Ponder Stibbons for implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/tour/__init__.py` - Package init for tour module
- `pennyfarthing-dist/src/pf/tour/practice.py` - Practice lifecycle: create_practice_epic(), cleanup_practice(), detect_orphaned_practice() with idempotent operations and result objects
- `pennyfarthing-dist/workflows/guided-tour/templates/epic-tour-practice.yaml` - Practice epic template with tour_artifact markers, trivial workflow, null jira, 1-point story
- `pennyfarthing-dist/workflows/guided-tour/steps/step-04-sprint.md` - Sprint step with concepts, commands, hands-on practice exercise (5 phases), cleanup, and deep-dive section preserving Try It / Dig In options

**Tests:** 34/34 passing (GREEN)
**Branch:** feat/132-15-practice-story-guided-tour-sprint (pushed)

**Handoff:** To next phase (verify or review)

## TEA Assessment (verify)

**Tests Verified:** Yes
**Test File:** `pennyfarthing-dist/src/pf/tests/test_tour_practice.py`
**Status:** GREEN — 34/34 passing, all 10 ACs covered
**Implementation Review:** Clean — practice module, template, and step file all present with correct structure.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** REJECTED

### Findings

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | **Missing sprint index registration** — `create_practice_epic()` copies the template shard to `sprint/` but never adds the epic ref to `current-sprint.yaml`. The `shard_merge.merge_epic_shards()` only loads shards listed in the index; unindexed shards are skipped with an "Unindexed shard — skipping" warning. This means `pf sprint status`, `pf sprint work`, and `pf sprint backlog` will NOT see the practice story. The docstring (line 31) explicitly claims "registers the epic ref in current-sprint.yaml" but the code doesn't do it. Breaks AC1, AC2, AC4. | `practice.py:28-57` | Add code to append `epic-tour-practice` to the `epics:` list in `current-sprint.yaml`. Similarly, `cleanup_practice()` must remove the ref on cleanup. |
| [MEDIUM] | **No behavioral tests** — All 34 tests are structural: file exists, YAML has fields, function has parameters, markdown contains strings. None actually call `create_practice_epic()`, `cleanup_practice()`, or `detect_orphaned_practice()` with real or mock inputs. The integration gap (missing index registration) would have been caught by a test that calls `create_practice_epic()` then checks `load_sprint()`. | `test_tour_practice.py` | Add behavioral tests that invoke the lifecycle functions with a tmp_path fixture and verify the sprint system can discover the practice story. |
| [MEDIUM] | **Inconsistent error handling** — `cleanup_practice()` correctly wraps `target.unlink()` in try/except (line 86-89), but `create_practice_epic()` lets `shutil.copy2()` raise uncaught. Violates project convention: "return result objects, don't throw." | `practice.py:56` | Wrap `shutil.copy2` in try/except OSError, return `{success: False, error: ...}`. |
| [LOW] | **Docstring-code mismatch** — Docstring says "registers the epic ref" but code doesn't. Even after fixing, update the docstring to match actual behavior. | `practice.py:29-38` | Sync docstring with implementation. |
| [VERIFIED] | Template YAML structure — all fields correct (`tour_artifact: true`, `jira: null`, `workflow: trivial`, `points: 1`, `status: backlog`, `status: active` on epic) | `epic-tour-practice.yaml` | — |
| [VERIFIED] | step-04-sprint.md — preserves existing content, has 5-phase practice section, mentions correct CLI commands, preserves Try It/Dig In options | `step-04-sprint.md` | — |
| [VERIFIED] | Security — no injection vectors, `yaml.safe_load` used, no secrets, Path objects used safely | all files | — |
| [VERIFIED] | Forbidden patterns — no `console.log`, no hardcoded secrets, no bare TODOs | all files | — |

### Data Flow Trace

**Input:** `create_practice_epic(project_root)` → copies `epic-tour-practice.yaml` into `sprint/`
**Expected flow:** shard in `sprint/` → `current-sprint.yaml` `epics:` list → `merge_epic_shards()` → `load_sprint()` → `get_story_by_id("tour-practice-1")` → `pf sprint work tour-practice-1`
**Actual flow:** shard in `sprint/` → NOT in `epics:` list → `merge_epic_shards()` warns "Unindexed shard — skipping" → story invisible → `pf sprint work` returns "Story not found"

### Pattern Observed

The tests verify component EXISTENCE but not component WIRING. This is the "unconnected components" anti-pattern — every piece exists in isolation but nothing confirms they plug together. The `shard_merge.py` discovery mechanism (index-driven, not glob-driven) is the integration point that was missed.

### Hard Questions

- **What happens when a user runs `pf sprint work tour-practice-1`?** Story not found (epic not indexed).
- **What happens if `shutil.copy2` fails?** Unhandled exception propagates — no result object returned.
- **What if sprint/ has no `current-sprint.yaml`?** `create_practice_epic` only checks `sprint_dir.exists()`, doesn't verify the index file.

**Handoff:** Back to Igor (TEA) for behavioral test coverage of the integration gap, then to Ponder Stibbons (Dev) for the fix.

## TEA Assessment (red — post-review)

**Tests Required:** Yes
**Test File:** `pennyfarthing-dist/src/pf/tests/test_tour_practice.py`
**Tests Added:** 18 behavioral tests using tmp_path fixtures
**Total Tests:** 52 (34 structural + 18 behavioral)
**Status:** RED — 3 failing, 49 passing

Failing tests (exposing review findings):
- `TestCreatePracticeEpicBehavioral::test_registers_epic_in_sprint_index` — create doesn't add ref to current-sprint.yaml (AC1, AC2, AC4)
- `TestCreatePracticeEpicBehavioral::test_catches_copy_errors` — shutil.copy2 raises uncaught OSError (convention violation)
- `TestCleanupPracticeBehavioral::test_removes_epic_ref_from_index` — cleanup doesn't remove ref from index (dangling reference)

New test classes:
- `TestCreatePracticeEpicBehavioral` (7 tests) — creates mock project, calls create_practice_epic(), verifies shard creation, idempotency, index registration, error handling
- `TestCleanupPracticeBehavioral` (6 tests) — verifies file removal, index cleanup, graceful handling of missing artifacts
- `TestDetectOrphanedPracticeBehavioral` (5 tests) — verifies detection of shard, session, archive artifacts

**Handoff:** To Ponder Stibbons (Dev) for implementation fixes.

## Dev Assessment (post-review fix)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/tour/practice.py` — Added `_register_epic_in_index()` and `_unregister_epic_from_index()` helpers; `create_practice_epic()` now registers shard in sprint index; `cleanup_practice()` now removes ref from index; `shutil.copy2` wrapped in try/except

**Tests:** 52/52 passing (GREEN)
**Branch:** feat/132-15-practice-story-guided-tour-sprint (pushed)

**Handoff:** To next phase (verify or review)

## TEA Assessment (verify — post-review)

**Tests Verified:** Yes
**Test File:** `pennyfarthing-dist/src/pf/tests/test_tour_practice.py`
**Status:** GREEN — 52/52 passing, all 10 ACs covered + 3 reviewer findings fixed
**Implementation Review:** Clean — all three reviewer findings addressed: sprint index registration, error handling, and cleanup index removal. Docstring now matches actual behavior.

**Handoff:** To Reviewer for re-review

## Reviewer Assessment (re-review)

**Verdict:** REJECTED

### Prior Findings Status

| Finding | Status |
|---------|--------|
| [HIGH] Sprint index registration | FIXED but **broken differently** — see new finding below |
| [MEDIUM] Error handling (shutil.copy2) | FIXED correctly at `practice.py:90-93` |
| [MEDIUM] Cleanup index removal | FIXED but uses wrong ref — same root cause as new finding |

### New Finding

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | **Double-prefixed shard ref** — `_register_epic_in_index()` appends `PRACTICE_EPIC_ID` = `"epic-tour-practice"` to the `epics:` list. But `shard_merge.merge_epic_shards()` constructs filenames as `f"epic-{ref}.yaml"`, so this ref resolves to `epic-epic-tour-practice.yaml` — a file that doesn't exist. The actual shard is `epic-tour-practice.yaml`, so the ref should be `"tour-practice"`. The practice story is still invisible to the sprint system. | `practice.py:16,40` | Add `PRACTICE_EPIC_REF = "tour-practice"` and use it for index registration/unregistration instead of `PRACTICE_EPIC_ID`. |
| [MEDIUM] | **Test asserts wrong ref** — `test_registers_epic_in_sprint_index` asserts `"epic-tour-practice"` is in the epics list, but the correct ref for shard_merge resolution is `"tour-practice"`. Test and code share the same naming error. | `test_tour_practice.py:468` | Update test to assert `"tour-practice"` in epics list. |
| [VERIFIED] | Error handling fix — `shutil.copy2` wrapped correctly at `practice.py:90-93` |
| [VERIFIED] | Guard clauses — both helpers handle missing index, None data |
| [VERIFIED] | Idempotent registration — duplicate check at line 39 |

### Data Flow Trace (re-verified)

**Existing convention:** Index ref `PROJ-15488` → `f"epic-{ref}.yaml"` → `epic-PROJ-15488.yaml` (exists)
**Practice epic:** Index ref `epic-tour-practice` → `f"epic-{ref}.yaml"` → `epic-epic-tour-practice.yaml` (DOES NOT EXIST)
**Correct ref:** `tour-practice` → `f"epic-{ref}.yaml"` → `epic-tour-practice.yaml` (exists)

**Handoff:** Back to Igor (TEA) to fix the test assertion, then to Ponder Stibbons (Dev) to fix the ref constant.

## TEA Assessment (red — shard ref fix)

**Tests Required:** Yes (test corrections + new end-to-end resolution test)
**Test File:** `pennyfarthing-dist/src/pf/tests/test_tour_practice.py`
**Total Tests:** 53 (added `test_registered_ref_resolves_to_shard`)
**Status:** RED — 3 failing, 50 passing

Failing tests:
- `test_registers_epic_in_sprint_index` — asserts `"tour-practice"` in epics (code registers `"epic-tour-practice"`)
- `test_registered_ref_resolves_to_shard` — verifies `f"epic-{ref}.yaml"` matches actual shard file (NEW)
- `test_removes_epic_ref_from_index` — cleanup must remove `"tour-practice"` ref (code removes `"epic-tour-practice"`)

**Handoff:** To Ponder Stibbons (Dev) to add `PRACTICE_EPIC_REF` constant and use it for index operations.

## Dev Assessment (shard ref fix)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/tour/practice.py` — Added `PRACTICE_EPIC_REF = "tour-practice"` constant; `_register_epic_in_index()` and `_unregister_epic_from_index()` now use `PRACTICE_EPIC_REF` instead of `PRACTICE_EPIC_ID` so that `shard_merge`'s `f"epic-{ref}.yaml"` resolves to the actual shard file

**Tests:** 53/53 passing (GREEN)
**Branch:** feat/132-15-practice-story-guided-tour-sprint (pushed)

**Handoff:** To next phase (verify or review)

## TEA Assessment (verify — shard ref fix)

**Tests Verified:** Yes
**Test File:** `pennyfarthing-dist/src/pf/tests/test_tour_practice.py`
**Status:** GREEN — 53/53 passing, all 10 ACs covered + reviewer shard ref finding fixed
**Implementation Review:** Clean — `PRACTICE_EPIC_REF` constant added, both index helpers use correct ref, `shard_merge` resolution verified by `test_registered_ref_resolves_to_shard`.

**Handoff:** To Reviewer for re-review

## Reviewer Assessment (re-review — shard ref fix)

**Verdict:** APPROVED

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | Double-prefix fix — `PRACTICE_EPIC_REF = "tour-practice"` used for index ops, resolves to correct shard filename | `practice.py:17,40-41,57-58` |
| [VERIFIED] | Naming contract — `f"epic-{PRACTICE_EPIC_REF}.yaml"` == `PRACTICE_SHARD_NAME`. Self-documenting constants. | `practice.py:16-19` |
| [VERIFIED] | End-to-end ref resolution test — `test_registered_ref_resolves_to_shard` proves the index ref maps to the actual file | `test_tour_practice.py:478-497` |
| [VERIFIED] | Error handling — `shutil.copy2` wrapped, `target.unlink()` wrapped, all public functions return result objects | `practice.py:91-93,127-130` |
| [VERIFIED] | Security — `yaml.safe_load` used, no user-controlled path construction, Path objects throughout | `practice.py:35,52` |

**Data flow traced:** `create_practice_epic(root)` → copies shard → registers `"tour-practice"` in index → `shard_merge` constructs `f"epic-tour-practice.yaml"` → file exists → story visible to `pf sprint` commands.

**Handoff:** To Captain Carrot (SM) for finish-story