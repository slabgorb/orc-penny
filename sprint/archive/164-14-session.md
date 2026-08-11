---
story_id: "164-14"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 164-14: SM agent: reconsider TodoWrite ban (or document the reasoning) (gh #46)

## Story Details
- **ID:** 164-14
- **Type:** chore
- **Points:** 1
- **Jira Key:** (none — local-only)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-14-sm-todowrite-ban-reasoning
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T11:16:57Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T20:45:01Z | - | - |

## Acceptance Criteria

1. **DISCOVERY:** Locate and document the exact wording of the current TodoWrite ban in `pennyfarthing-dist/agents/sm.md` (the `<critical>` block lists "CANNOT: ... TodoWrite"). Verify `pennyfarthing-dist/agents/` is the source of truth and `.pennyfarthing/agents/` is a symlink to it. Check for other references to the ban in guides, workflows, or other agent definitions that need consistency updates.

2. **DOCUMENTED REASONING:** Replace the blanket "CANNOT: TodoWrite" with a scoped, documented rule that:
   - Explicitly explains WHY the ban exists (SM's coordination-discipline forbids implementation task-decomposition — breaking a story into code-level subtasks is Dev/TEA's job, not SM's)
   - Documents the intent: the ban stops SM from doing implementation task-planning (that violates "route, don't solve" coordination discipline)
   - Was NOT meant to forbid SM from using todo/task tracking for legitimate COORDINATION work (story-level progress tracking across a multi-story run, workflow-phase tracking)

3. **NARROWED RULE:** Update `sm.md` to replace:
   ```
   - **CANNOT:** Write/edit code, TodoWrite, plan implementation details
   ```
   with a structured rule that:
   - **Forbids:** Using todo/task tools for implementation task-decomposition (code-level subtask planning, which is Dev/TEA's lane)
   - **Explicitly permits:** Using todo/task tools for coordination-level progress tracking (story-level multi-story orchestration, workflow-phase tracking)

4. **CONSISTENCY CHECK:** Ensure the narrowed wording does not contradict the existing `<coordination-discipline>` block ("route, don't solve") and does not introduce contradictions elsewhere in the agent definition.

5. **ASSERTION/TEST:** Write a markdown-level assertion (code comment or marked section) in `sm.md` that pins the new documented rule so future readers understand:
   - The ban exists to protect SM's coordination role
   - It does NOT forbid all TodoWrite usage, only implementation task-planning
   - Coordination-level task tracking is permitted
   - Example: "SM may use TodoWrite to track story-level progress in multi-story orchestration but MUST NOT decompose implementation work into code-level subtasks"

## Current State (Discovery)

### Current Wording (sm.md line 30)
Located in `<critical>` block:
```
- **CANNOT:** Write/edit code, TodoWrite, plan implementation details
```

### Related Coordination Discipline (sm.md lines 12–24)
```
<coordination-discipline>
**You are not here to solve problems. You are here to route them.**

The moment you start reading implementation files or planning how code should work, 
you've failed your role. You are the conductor—you don't play the instruments.

**Default stance:** Detached. Who owns this?
...
**Your job is done when the next agent has context. Not when the problem is solved.**
</coordination-discipline>
```

### Other References Found
- `pennyfarthing-dist/workflows/quick-dev/steps/step-05-adversarial-review.md` — REVIEWER (not SM) uses TodoWrite to turn findings into TODOs. Shows TodoWrite is permitted for other agents; the SM ban is specific to SM's role.

### Reasoning Behind the Ban (inferred from coordination-discipline)
The ban exists because:
1. Implementation task-decomposition (breaking a story into code-level subtasks) is Dev/TEA's job
2. If SM starts decomposing code-level work, SM is "solving" rather than "routing" — violating coordination-discipline
3. The example: SM should NOT write "Refactor function X into three helper functions" as a TODO tree for Dev

### Legitimate SM Use of Todo/Task Tracking (NOT currently documented)
SM could legitimately use TodoWrite for:
1. **Multi-story orchestration progress:** Tracking which stories in an epic are ready for the next phase
2. **Workflow-phase tracking:** Documenting phase entry/exit progress across a sprint
3. **Coordination checkpoints:** Recording gate checks, handoff readiness, inter-story dependencies

## Design Direction

**NARROW AND DOCUMENT** the ban rather than remove it:
- Keep the principle (SM doesn't decompose implementation work)
- Replace blanket "CANNOT: TodoWrite" with scoped, explicit rule
- Document the reasoning in the agent definition
- Explicitly permit coordination-level usage
- Ensure consistency with coordination-discipline ("route, don't solve")

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story changes a markdown agent definition (sm.md) — content assertions are the appropriate test form.

**Test Files:**
- `pennyfarthing/tests/python/test_164_14_sm_todowrite_ban.py` - 10 tests across 3 classes asserting the narrowed+documented rule state

**Tests Written:** 10 tests covering all 3 ACs (7 failing RED, 3 passing consistency guards)
**Status:** RED (7 failing — ready for Dev)

**Handoff:** To Dev for implementation (editing sm.md)

## Delivery Findings

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/agents/sm.md` — replaced bare `CANNOT: TodoWrite` with scoped rule: forbidden scope (implementation task-decomposition) + rationale + permitted scope (coordination-level tracking)

**Tests:** 10/10 passing (GREEN)
**Branch:** feat/164-14-sm-todowrite-ban-reasoning (pushed)

**Handoff:** To Reviewer

## Design Deviations

No deviations from spec.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

<!-- Reviewer: write your schema-compliant assessment below. -->

## Subagent Results

**Story:** 164-14 | **Branch:** feat/164-14-sm-todowrite-ban-reasoning | **Timestamp:** 2026-08-11T12:00:00Z

**All received:** Yes (9/9 specialists returned)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|---------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | PASS | 10/10 tests pass (`python3 -m pytest tests/python/test_164_14_sm_todowrite_ban.py`). No lint issues. No code smells. Clean diff (2 lines sm.md + 261-line test file). | Accept |
| 2 | reviewer-comment-analyzer | Yes | PASS | [DOC] All test docstrings are accurate and describe pre/post state precisely. The `**TodoWrite/task tools:**` label in sm.md is clear and consistent with existing `**CAN:**`/`**CANNOT:**` labeling convention. No stale or misleading documentation found. | Accept |
| 3 | reviewer-edge-hunter | Yes | Minor | [EDGE] `test_permitted_scope_uses_coordination_level_compound` has Python operator-precedence ambiguity on its last `or` clause: `"progress tracking" in lower and "coordination" in lower` binds as a unit due to `and > or`. If `"coordination-level"` / `"story-level"` / `"multi-story orchestration"` / `"coordination tracking"` were all absent but "progress tracking" and "coordination" appeared anywhere (e.g., the existing coordination-discipline block), this clause alone could satisfy the assertion vacuously. Low risk: current text hits the first branch (`"coordination-level"`). Minor. | Accept (non-blocking) |
| 4 | reviewer-rule-checker | Yes | PASS | [RULE] Correct source path edited (`pennyfarthing-dist/agents/sm.md`). Verified `.pennyfarthing/agents` is a directory-level symlink to `../pennyfarthing/pennyfarthing-dist/agents` — change propagates automatically. Project rule 1 satisfied. Test file correctly placed under `tests/python/`. | Accept |
| 5 | reviewer-security | Yes | PASS | [SEC] No secrets in diff. Regex patterns all use bounded quantifiers (`.{0,200}`, `.{0,300}`) — no ReDoS risk. `SM_PATH` constructed from `Path(__file__).parent` chain, not user-controlled input. No injection vectors. | Accept |
| 6 | reviewer-silent-failure-hunter | Yes | Minor | [SILENT] `_read_sm()` calls `pytest.skip()` if `sm.md` is missing rather than failing — a deleted or moved file would yield 0-tests-ran instead of 10 failures. Acceptable for a file-existence guard, but worth noting. No swallowed errors or vacuous bool checks found. | Accept (non-blocking) |
| 7 | reviewer-simplifier | Yes | PASS | [SIMPLE] 261-line test file for a 2-line markdown change is proportionate: AC5 explicitly required test coverage, and content-assertion tests on markdown require proximity-based regex. No dead code, no redundant logic, no over-engineering beyond scope. | Accept |
| 8 | reviewer-test-analyzer | Yes | Minor | [TEST] No dedicated test for AC5 ("pinned markdown assertion" as a named structural concept). All 10 tests would fail correctly on regression (verified by reading each assertion against current sm.md content). `test_permitted_scope_uses_coordination_level_compound` operator-precedence gap (see edge-hunter) is the only latent false-pass path. Test class structure (Documented/Narrowed/Consistency) maps cleanly to ACs 1–3. | Accept (non-blocking) |
| 9 | reviewer-type-design | Yes | PASS | [TYPE] `_read_sm()` correctly annotated `-> str`. `bool()` cast on `re.search()` is idiomatic Python. `Path` typing used throughout. No stringly-typed APIs, no missing annotations. Clean. | Accept |

## Reviewer Assessment

**Specialist synthesis:** [DOC] test docstrings accurate, sm.md label consistent with `**CAN:**`/`**CANNOT:**` convention. [EDGE] minor operator-precedence gap in one test's `or` clause (non-blocking). [RULE] correct source path edited; `.pennyfarthing/agents` symlink confirmed. [SEC] no secrets, bounded regex, no user-controlled paths. [SILENT] `pytest.skip` on missing file noted (guard, acceptable). [SIMPLE] 261-line test proportionate to AC5's coverage requirement, no over-engineering. [TEST] no dedicated AC5 named-concept test (minor); all 10 assertions fail correctly on regression. [TYPE] clean annotations, idiomatic `bool()` cast.

### Findings Summary

| Severity | Tag | Finding | Location |
|----------|-----|---------|----------|
| Minor | [EDGE] | `test_permitted_scope_uses_coordination_level_compound` boolean precedence — last `or` clause binds as `(progress_tracking AND coordination)`, could vacuously pass if other branches were absent | `tests/python/test_164_14_sm_todowrite_ban.py:155–163` |
| Minor | [SILENT] | `pytest.skip` on missing file — 0 tests run rather than 10 failures if sm.md is deleted | `tests/python/test_164_14_sm_todowrite_ban.py:44–47` |
| Minor | [TEST] | No explicit test for AC5 "pinned assertion" as a named structural concept | `tests/python/test_164_14_sm_todowrite_ban.py` |

No Critical or High findings. All findings are Minor (non-blocking).

### Mandatory Review Steps

- [x] **5+ observations:** 9 specialist results + 3 classified findings documented
- [x] **Data flow traced:** sm.md rule text → agent runtime via `.pennyfarthing/agents` symlink → LLM context (safe: symlink propagates automatically from edited source)
- [x] **Wiring:** `pennyfarthing-dist/agents/sm.md` is the source of truth; `.pennyfarthing/agents/` symlink confirmed pointing to it
- [x] **Pattern identified:** `**TodoWrite/task tools:**` bullet follows existing `**CAN:**`/`**CANNOT:**` labeling pattern at `sm.md:29–31`
- [x] **Error handling:** Tests use `pytest.skip` on missing file (acceptable guard); regex patterns are bounded (no failure modes)
- [x] **Security analysis:** No secrets, no injection, bounded regex, no user-controlled paths
- [x] **Hard questions:** Could SM misread the scoped rule? Wording is unambiguous — "must not" for forbidden, "may use" for permitted. No ambiguity.
- [x] **Subagent findings incorporated:** All 9 specialist results reviewed and classified
- [x] **Deviation audit:** Session file documents "No deviations from spec" — confirmed, no undocumented deviations found

### Design Deviations Audit

Session file states: "No deviations from spec." Confirmed — implementation matches all 5 ACs exactly as specified.

**Verdict:** APPROVED

**Handoff:** To SM for finish-story