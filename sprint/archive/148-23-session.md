---
story_id: "148-23"
jira_key: ""
epic: "MSSCI-16421"
workflow: "tdd"
---

# Story 148-23: Reviewer handoff gate instructions unclear — struggles to complete gate reliably

**Phase:** red
**Workflow:** tdd
**Branch:** feat/148-23-reviewer-handoff-gate
**Repos:** pennyfarthing

## Context

The reviewer agent's exit protocol has three nested gate checks (approval, subagent-completion, subagent-dispatch) with instructions scattered across 5+ files. Reviewers struggle to complete the gate reliably because:

1. **No unified doc** — Instructions split across agent definition, 3 gate files, and implementation code
2. **Ambiguous "All received"** — Reviewers write context like `Yes (6 returned, 2 assessed)` but gate expects simple `Yes/No`
3. **Tag dispatch logic unclear** — Reviewers don't know if omitting a tag means "no findings" or "didn't run subagent"
4. **No clear recovery instructions** — Gate failure messages don't explain which rows are optional vs mandatory
5. **Bold markdown support added but not documented** — Gate tolerates `**All received:** Yes` but examples show plain text

### Key Files
- `pennyfarthing-dist/agents/reviewer.md` — Agent definition with exit protocol and subagent-completion-gate
- `pennyfarthing-dist/gates/approval.md` — Approval gate with 3 nested sub-gates
- `pennyfarthing-dist/guides/handoff-cli.md` — Handoff CLI exit sequence
- `pennyfarthing-dist/src/pf/handoff/complete_phase.py` — Gate implementation (what actually validates)
- `pennyfarthing-dist/src/pf/tests/test_148_17_reviewer_gate_markdown.py` — Existing gate tests

## Acceptance Criteria

- [ ] AC1: Reviewer agent definition has clear, self-contained gate completion instructions (no need to cross-reference other files)
- [ ] AC2: Gate error messages include actionable recovery steps (what to fix and how)
- [ ] AC3: The "All received" line semantics are documented and match implementation behavior
- [ ] AC4: Examples in the agent definition match what the gate implementation actually checks

## TEA Assessment

**Tests Required:** Yes
**Reason:** All 4 ACs require verifiable changes to docs and error messages

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_148_23_reviewer_gate_clarity.py` — 21 tests across 4 AC classes

**Tests Written:** 21 tests covering 4 ACs
**Status:** RED (8 failing, 13 passing regression guards)

### Failing Tests (what Dev must fix)

**AC1 — Self-contained gate instructions (3 failures):**
- `test_reviewer_md_documents_all_accepted_all_received_formats` — reviewer.md must document plain, bold, bold+value formats
- `test_reviewer_md_has_gate_troubleshooting_section` — reviewer.md needs a troubleshooting/recovery section for common gate failures
- `test_reviewer_md_contains_exit_sequence_steps` — reviewer.md must include `pf handoff resolve-gate` and `pf handoff complete-phase` commands inline

**AC2 — Actionable error messages (2 failures):**
- `test_missing_subagent_table_error_includes_example_row` — error for missing subagent table must include an example table row format
- `test_missing_assessment_error_shows_example_heading` — error must show `## Reviewer Assessment` (not generic `{Agent} Assessment`)

**AC3 — "All received" semantics (2 failures):**
- `test_all_received_with_parenthetical_context_is_documented` — gate silently accepts `Yes (context...)` but this isn't documented
- `test_reviewer_md_documents_all_received_is_gate_checked` — reviewer.md must state this line is machine-validated by the gate

**AC4 — Examples match implementation (1 failure):**
- `test_reviewer_md_exit_gate_type_matches_implementation` — reviewer.md must specify `gate_type=approval` in exit protocol

### Passing Tests (regression guards)
13 tests verify existing correct behavior: template table passes completion check, assessment passes dispatch check, subagent lists match between docs and code, dispatch tags match, error messages use "To fix:" prefix, "No" values correctly fail, etc.

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/reviewer.md` — Added accepted "All received" formats, troubleshooting section, inline exit commands with gate_type=approval, parenthetical context docs, gate validation note
- `pennyfarthing-dist/src/pf/handoff/complete_phase.py` — Added example table row to missing-section error, changed generic `{Agent} Assessment` to specific `## Reviewer Assessment`

**Tests:** 21/21 passing (GREEN)
**Branch:** feat/148-23-reviewer-handoff-gate (pushed)

**Handoff:** To next phase

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none — 471 gate tests pass, no lint issues | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | Confirmed hardcoded "Reviewer Assessment" regression in generic error path | confirmed 1 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | Same finding — non-reviewer agents get misleading error message | confirmed 1 (same as #2) |
| 4 | reviewer-test-analyzer | Yes | findings | test_missing_assessment_error_shows_example_heading validates the bug — forces hardcoding | confirmed 1 |
| 5 | reviewer-comment-analyzer | Yes | clean | New documentation sections are accurate and well-structured | N/A |
| 6 | reviewer-type-design | Yes | clean | No type issues in this diff | N/A |
| 7 | reviewer-security | Yes | clean | No security concerns | N/A |
| 8 | reviewer-simplifier | Yes | clean | Changes are minimal and focused | N/A |

**All received:** Yes
**Total findings:** 1 confirmed, 0 dismissed (with rationale), 0 deferred

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Hardcoded "Reviewer Assessment" in generic error path — `complete_phase()` is called for ALL agents (TEA, Dev, Architect, etc.) but error now says "Add a `## Reviewer Assessment` heading" instead of the generic `## {Agent} Assessment`. A Dev agent hitting this guard with gate_type="dev_exit" would receive wrong instructions. | `pennyfarthing-dist/src/pf/handoff/complete_phase.py:73` | Restore generic form using the `from_phase` agent lookup: `f"## {from_agent.title()} Assessment"` or keep generic `## {Agent} Assessment` pattern. The regex at line 66 already correctly accepts any `## X Assessment`. |

**Data flow traced:** `complete_phase(gate_type="dev_exit")` → line 65 guard fires (not in skip list) → line 73 error says "Reviewer Assessment" → Dev agent gets wrong recovery advice
**Pattern observed:** Good pattern in reviewer.md docs — inline exit commands replacing cross-reference is a real improvement (lines 288-293)
**Error handling:** The example row format addition to the missing-section error (line 356-358) is good and actionable
**Observations:**
- [EDGE] The hardcoded error message is wrong for 5 of 7 gate types (only `approval` is reviewer-specific)
- [SILENT] No silent failures — gate validation logic itself is unchanged and correct
- [TEST] The test `test_missing_assessment_error_shows_example_heading` drove this regression — it asserts `## Reviewer Assessment` in the error. Fix: make the test call with gate_type="approval" and check from_phase-derived agent name, OR accept the generic pattern
- [DOC] All reviewer.md additions are accurate — formats match regex, commands match workflow YAML, troubleshooting covers real failure modes
- [TYPE] No type issues
- [SEC] No security concerns
- [SIMPLE] Changes are appropriately scoped — minimal and focused on the actual problem

**Fix guidance:** The error message at `complete_phase.py:73` should either:
1. Use `from_phase` to look up the agent name: `f"## {from_agent.title()} Assessment"` (but `from_agent` is computed later at line 102, so move the lookup or use a simpler approach)
2. Restore the generic pattern: `"## {Agent} Assessment"` (with literal braces showing the placeholder pattern)
3. Make it dynamic: compute agent name from `from_phase` before the guard

The corresponding test should verify agent-appropriate messaging, not hardcode "Reviewer".

**Handoff:** Back to Dev for fix

## Re-Review Assessment (rework)

**Verdict:** APPROVED

Dev moved `from_agent = _get_phase_agent(...)` before the assessment guard (line 63) and uses `f"## {agent_name} Assessment"` (line 76) where `agent_name = from_agent.replace("-", " ").title()`. This correctly produces agent-appropriate error messages:
- reviewer → "Reviewer Assessment"
- dev → "Dev Assessment"
- architect → "Architect Assessment"

[HIGH] finding from initial review is **resolved**. 471 gate tests pass, no regressions.

**Minor observation [LOW]:** `.title()` produces "Tea" and "Sm" for acronym agents instead of "TEA"/"SM". Cosmetic only — the regex accepts any capitalization and the error is advisory. Not blocking.

- [EDGE] Dynamic agent name resolves all gate_type edge cases
- [SILENT] No silent failures introduced
- [TEST] Test correctly uses from_phase="review" which resolves to "Reviewer"
- [DOC] No doc changes needed for rework
- [TYPE] No type issues
- [SEC] No security concerns
- [SIMPLE] Fix is minimal — moved one line up, added one `.title()` call

**Handoff:** To SM for finish-story
