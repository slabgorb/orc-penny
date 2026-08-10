---
story_id: "164-10"
jira_key: ""
epic: "164"
workflow: "trivial"
---
# Story 164-10: Finish-family test conftest: autouse patch for finish_story Step 4c demo-generation subprocesses (pre-existing isolation gap, from 155-33 review)

## Story Details
- **ID:** 164-10
- **Jira Key:** (none — local-only)
- **Workflow:** trivial
- **Stack Parent:** none
- **Branch:** feat/164-10-finish-family-conftest-demo-isolation
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-08-10T19:10:06Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T18:40:56Z | - | - |

## Discovery Findings

### Test Isolation Gap — Step 4c Demo-Generation Leakage

When running the finish-family test suite in full (`pytest -k finish`), 3 tests in `test_164_1_finish_dialogue_oserror_no_stray_archive.py` fail despite passing in isolation:

- `test_failure_step_is_1b_when_dialogue_copy_raises`
- `test_failure_action_is_archive_dialogue_when_dialogue_copy_raises`
- `test_session_oserror_reports_step_1_archive_session`

**Root cause:** Story finish's Step 4c (`demo_orchestrator.generate()` at line 1938 in `story_finish.py`) runs *inside* finish_story() and may spawn subprocesses or perform I/O. When tests run in sequence without isolation, mock state from earlier tests (particularly Step 4c demo-generation calls or other subprocess invocations in test_demo_finish_hook.py or test_162_9_finish_subprocess_timeouts.py) persists, causing downstream tests to see "PR is not in MERGED state after the merge step" instead of the expected shutil.copy2 OSError.

**Failure pattern:** The tests' `_run` mock dispatcher's state is leaking across test boundaries. The Step 2 (merge_pr) is failing when it should never reach there (Step 1b should fail first). This suggests either:
1. The mock is not being properly reset between tests, OR
2. Step 4c is spawning real subprocesses that affect the test environment

**AC2/AC3 refactor needed:** These tests were written for story 164-1 (partial session archive cleanup on dialogue OSError) and pass individually. They fail in batch because of pre-existing isolation gaps in the test conftest that do NOT patch Step 4c demo-generation.

### Acceptance Criteria Analysis

**Listed AC (mis-filed from 155-34):**
> "Pin 155-34's three unpinned defensive probe paths: origin/<base> preference over a stale local base, the origin/<branch> fallback candidate, and the backticked/annotated sentinel variant (from 155-34 review)"

**Status:** **Mis-filed** — This AC belongs to a separate story (155-34) about branch-resolution probing, not about demo-generation test isolation. The actual scope of 164-10 is narrower: isolate finish_story Step 4c demo-generation during finish-family tests so the 164-1 tests pass reliably.

**Scope for 164-10:**
1. Add autouse conftest fixture that patches `pf.demo.orchestrator.generate()` to a no-op stub
2. Verify that the 3 failing tests now pass reliably when run in full suite
3. Ensure no real assertions are masked (fixture is *only* demo-generation isolation, not behavioral)

### Pre-Existing Acceptance Criteria (Primary)

1. An autouse conftest fixture isolates finish_story Step 4c demo-generation (no real subprocess/demo generation during finish-family tests); the 3 previously-failing 164-1 tests now pass reliably regardless of ordering.
2. Existing finish-family tests still pass; the fixture doesn't mask real assertions (it only stubs the demo-generation side effect).

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/tests/conftest.py` — added `_stub_demo_generate` autouse fixture patching `pf.demo.orchestrator.generate` to `{"success": True}` no-op for all tests; demo tests that exercise generate() apply their own `@patch` decorators which override the stub
- `pennyfarthing-dist/src/pf/tests/test_164_1_finish_dialogue_oserror_no_stray_archive.py` — added `mergedAt` field to `_make_fake_run` view response; 162-18 (mergedAt corroboration) landed after 164-1's tests were written, causing 3 tests to fail because the post-merge verification returned not-merged before the archive step was reached

**Tests:** 7/7 passing (164-1 tests); 6858 passing full suite (0 failures)
**Branch:** feat/164-10-finish-family-conftest-demo-isolation (pushed)

**Root Cause Clarification:** The session's "state leakage from demo generation" diagnosis was partially inaccurate. The actual root cause was `_make_fake_run` missing `mergedAt` in its gh-pr-view response. Story 162-18 added corroboration (state==MERGED AND mergedAt non-null) after 164-1's tests were written, so the post-merge check returned not-merged and never reached the archive/shutil step. Both fixes were applied: `mergedAt` added to fake (primary fix) + demo stub added to conftest (hygiene as specified in scope).

**Mis-filed AC Note:** The acceptance criteria mentioning "pin 155-34's three defensive probe paths" is confirmed mis-filed (noted in session Discovery Findings). Not implemented here.

**Handoff:** To Reviewer

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | All 298 finish-family tests pass; 37 critical-path pass; no debug code | N/A |
| 2 | reviewer-edge-hunter | Yes | clean | mergedAt pre-merge=None/post-merge=ISO correct; `merge in parts` routing pre-existing | N/A |
| 3 | reviewer-silent-failure-hunter | Yes | clean | No swallowed errors; stub is intentional isolation | N/A |
| 4 | reviewer-test-analyzer | Yes | clean | Zero masking: all 13 demo_finish_hook tests patch generate themselves; all 9 CLI tests patch pf.demo.cli.generate; help/registration tests don't call generate | N/A |
| 5 | reviewer-comment-analyzer | Yes | findings | Docstring says test_demo_cli uses `@patch("pf.demo.orchestrator.generate")` but it patches `pf.demo.cli.generate`; stub is inert not overriding for those tests | LOW — no functional impact |
| 6 | reviewer-type-design | Yes | findings | Stub returns `{"success": True}` missing `"data"` key; story_finish only checks `.get("success")` so no current breakage | LOW — non-blocking hygiene |
| 7 | reviewer-security | Yes | clean | No security issues in test-only code | N/A |
| 8 | reviewer-simplifier | Yes | findings | `_make_fake_run` reimplements GhPrFake; already drifted once | LOW — informational |
| 9 | reviewer-rule-checker | Yes | clean | All 10 project rules checked; zero violations | N/A |

**All received:** Yes

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `_make_fake_run` view response → `_pr_is_merged()` at story_finish.py:439 → `state=="MERGED" and bool(view.get("mergedAt"))` → MERGED → archive step reached → OSError raised and asserted. Flow is now correct end-to-end.
**Pattern observed:** Deferred import + module-attribute access at story_finish.py:1936 (`from pf.demo import orchestrator as demo_orchestrator` then `demo_orchestrator.generate(...)`) makes `monkeypatch.setattr("pf.demo.orchestrator.generate", ...)` the correct interception point.
**Error handling [SILENT]:** demo generation is non-fatal — story_finish.py:1941–1955 records both success and failure/exception as a step with optional `warning` field. [TEST] Covered by test_demo_finish_hook.py TestDemoHookErrorHandling; all 5 error-path tests present and patching generate themselves. [SEC] No security issues — test-only code, no auth/injection/secrets surface. [RULE] All 10 project rules verified clean; stub return `{"success": True}` satisfies rule 6 minimal shape.
**Global autouse stub masking [TEST]:** NONE. All 13 tests in test_demo_finish_hook.py have their own `@patch("pf.demo.orchestrator.generate")` (lines 121, 153, 176, 219, 261, 284, 317, 354, 388, 430, 469, 532, 581) which override the stub. All CLI tests that reach generate patch `pf.demo.cli.generate` (separate name — stub is inert, not overriding). Tests that only check help/registration never call generate. Zero masking of current coverage.
**164-1 mergedAt fake [EDGE]:** CORRECT. Production corroboration at story_finish.py:439 requires both `state=="MERGED"` and `bool(view.get("mergedAt"))`. Old fake omitted mergedAt → `bool(None)` = False → never reached archive step. New fake adds `"mergedAt": "2026-08-04T00:00:00Z" if current_state == "MERGED" else None` — identical to GhPrFake at helpers/gh_pr_fake.py:90–91. Archive step is now genuinely exercised.
**155-34 AC:** Correctly deferred. Branch-resolution probing is a different story and component. Not a gap in 164-10's scope.

| Severity | Issue | Location | Tag |
|----------|-------|----------|-----|
| [LOW] | Conftest docstring says test_demo_cli uses `@patch("pf.demo.orchestrator.generate")` — it actually patches `pf.demo.cli.generate`; stub is inert (not overriding) for those tests | conftest.py:77 | [DOC] |
| [LOW] | Stub returns `{"success": True}` missing `"data"` key; future caller inspecting `.get("data")` without a local patch would silently get None | conftest.py:83 | [TYPE] |
| [LOW] | `_make_fake_run` is a local reimplementation that mirrors GhPrFake and has already drifted once; replace with GhPrFake to prevent recurrence | test_164_1:154 | [SIMPLE] |

**Handoff:** To SM for finish-story

## Delivery Findings

**No upstream findings at this stage.**

## Design Deviations

### Dev (implementation)
- **Root cause correction:** Spec said tests "FAIL in full suite but PASS in isolation — state leakage from demo generation". Actual root cause: `_make_fake_run` missing `mergedAt` (added by 162-18 after 164-1 tests were written). Demo stub added as specified hygiene; `mergedAt` fix is the gate-opener. *Found by Dev during implementation.*