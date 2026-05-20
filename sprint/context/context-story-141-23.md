---
parent: context-epic-141.md
workflow: tdd
story_id: 141-23
jira_key: PROJ-16160
---

# Story 141-23: Add actionable fix instructions to all validators that can halt agents

## Business Context

Agents in the Pennyfarthing framework encounter validation errors that terminate their work stream with minimal guidance on how to proceed. When a validator rejects input, the agent receives "validation failed" but no path to recovery. This forces escalation to human operators and breaks the agent's ability to self-correct.

This story addresses a critical user experience gap: every validator failure must include specific fix instructions so agents can understand what went wrong and how to correct it. This moves agents from passive rejection to active problem-solving.

**Business value:**
- Agents achieve higher autonomy and success rates
- Human operators spend less time troubleshooting validator failures
- Framework demonstrates agent-centric error messages (aligned with Pennyfarthing's philosophy)

## Technical Guardrails

From Epic 141 (Agent Reliability and Recovery):
- **Validator scope:** Focus on validators that can halt agent progress (not noise validation)
- **Error message format:** Establish consistent structure (reason + fix instructions)
- **No validator removal:** Only add guidance; don't change validation logic
- **Backward compatibility:** Existing error handling paths must not break
- **Test-first approach:** All changes verified by automated tests

Key integration points:
- PreToolUse hooks intercept tool calls — validators here have highest visibility to agents
- Gate validators run at phase transitions — failures are show-stoppers
- Schema validators enforce data contracts — must be precise in guidance
- CLI validators check command arguments — most user-facing entry points

## Scope Boundaries

**In scope:**
- Survey all PreToolUse hooks and extract validator failures
- Survey all gate validators (sm-setup-exit, tea-context, dev-exit, quality-pass, approval, etc.)
- Survey schema validators in story, sprint, workflow, and assessment validation
- Survey handoff validators for assessment format and session state
- Add "To fix:" guidance to error messages for all identified validators
- Create tests that verify error messages include actionable guidance
- Document the validator taxonomy and error message format standard

**Out of scope:**
- Refactoring validator architecture (deferred to 141-24)
- Creating a centralized validator registry (deferred to 141-24)
- Implementing auto-correction mechanisms (deferred to future epic)
- Changing validation logic itself — only error messages are modified

## AC Context

### AC1: All validators that can halt agents are identified and cataloged

**What must be true:**
- A complete list exists of every validation point that can reject an agent's work
- The list categorizes validators by type (PreToolUse, gate, schema, handoff, CLI)
- Each entry documents: validator name, entry point file, failure reason, expected input format

**Edge cases:**
- Conditional validators (only active in certain modes/workflows)
- Cascading validators (one validator chains to another)
- Custom/plugin validators outside main codebase

**Test approach:**
- Grep sweep for common error patterns in codebase
- Manual audit of known gate files and hook implementations
- Documentation of the catalog in the final PR

### AC2: Each validator produces error messages with specific fix instructions

**What must be true:**
- Every validator error includes: (1) what went wrong, (2) why it matters, (3) how to fix it
- Error messages follow a consistent format
- Messages are written in plain language (no jargon)
- "To fix:" section is always present

**Example:**
```
PreToolUse validator: story_context_required
Reason: Tool requires story context to validate execution scope
Expected: {story_id, phase, workflow_name}
To fix: Ensure you have called `pf.story.load(story_id)` before using this tool. Check .session/story-id-session.md exists and contains a Story ID.
```

**Edge cases:**
- Validators with multiple failure modes (return different messages per mode)
- Nested validators (error bubbling from sub-validator)
- Validators with optional parameters (conditional fix instructions)

**Test approach:**
- Unit tests for each validator: invoke with invalid input, capture error message, verify format
- Format validation: all errors must match regex `/.*(To fix:|How to fix:|Next steps:).*/i`

### AC3: Fix instructions are actionable — agents can follow them to resolve the issue

**What must be true:**
- Instructions reference specific files, commands, or API calls
- Instructions are concrete (not abstract advice)
- Instructions can be executed within the constraints of the agent's context
- Instructions include example corrected input or retry command

**Examples (good):**
- "To fix: Run `pf sprint work` to load the current sprint context into your session."
- "To fix: Ensure the story context includes 'workflow: tdd' in .session/{story-id}-session.md."
- "To fix: Check that your assessment uses the format: ### {Agent} ({phase}) with one finding per line starting with '- **Type** (urgency):'."

**Examples (bad):**
- "To fix: Ensure your input is valid." (not specific enough)
- "To fix: Ask the human for help." (not actionable by agent)
- "To fix: Use a different approach." (too vague)

**Edge cases:**
- Validators for external data (Jira API, Git API) — fix instructions must account for failures beyond agent's control
- Validators with multiple failure modes — each mode needs its own specific instruction
- Cascading failures — instructions at each level must guide toward root cause

**Test approach:**
- Manual walkthrough: simulate agent receiving error, follow instructions, verify error resolves
- Template matching: verify instructions contain specific, actionable references (commands, file paths, API calls)

### AC4: Tests verify that error messages include fix guidance

**What must be true:**
- Automated tests cover all validators identified in AC1
- Tests invoke each validator with invalid input
- Tests assert error messages contain guidance (not just failure reason)
- Tests pass in CI/CD pipeline

**Test structure:**
```python
def test_validator_preToolUse_storyContextRequired_includesFixGuidance():
    # Setup: invoke tool without story context
    result = invoke_tool_without_context(...)
    # Assert: error includes both reason and fix
    assert "To fix:" in result.error_message
    assert "story context" in result.error_message.lower()
    assert len(result.error_message) > 100  # Sufficient detail
```

**Edge cases:**
- Async validators (callbacks) — test harness must await completion
- Conditional validators (mode-dependent) — test with/without mode flag
- Validators with timeout behavior — verify timeout errors also include fix guidance

**Test approach:**
- Unit tests in native test runner (Node test, pytest, bash bats)
- Integration tests with mock agent workflows
- Regression tests: verify existing passing tests still pass

## Interaction Patterns

**Agent-validator interaction:**
1. Agent calls tool or transitions phase
2. Validator runs, detects failure
3. Validator returns error with fix instructions
4. Agent reads error message
5. Agent executes fix instructions
6. Agent retries operation

**Error message lifecycle:**
- Validator generates error message with fix guidance
- Error propagates through hook/gate handler
- Error delivered to agent (via API response, session log, or CLI output)
- Agent can parse and act on guidance

## Validator Taxonomy

**Categories:**

| Category | Examples | Entry Point |
|----------|----------|-------------|
| **PreToolUse hooks** | story_context_required, workflow_name_valid, phase_valid | `.pennyfarthing/hooks/pre-tool-use.py` |
| **Gate validators** | sm_setup_exit, tea_context, tests_fail, dev_exit, quality_pass, approval | `pennyfarthing-dist/gates/*.yaml` |
| **Schema validators** | story schema, sprint schema, workflow schema, assessment schema | Python schema validators in `pf/schemas/` |
| **Handoff validators** | assessment_format, session_state_valid, findings_format | `pf.handoff` module validators |
| **CLI validators** | command syntax, argument types, option constraints | `pf cli` subcommand validators |

## Acceptance Criteria Mapping

| AC | Evidence | Status |
|----|----------|--------|
| AC1 | Catalog document in PR description | pending |
| AC2 | Error messages follow format; grep finds all "To fix:" sections | pending |
| AC3 | Manual walkthrough: follow instructions, verify recovery | pending |
| AC4 | Test suite in `tests/validators/` with >80% pass | pending |

---

## Dependencies

**Depends On:**
- None (story is independent)

**Depended On By:**
- Story 141-24 (Validator framework improvements) — builds on this story's taxonomy
- Epic 142 (Agent Learning) — may use validator error messages as training signals

---

## Testing Strategy

### Unit Tests
- Test each validator independently with invalid input
- Verify error message format and guidance presence
- Test with different failure modes (when applicable)

### Integration Tests
- Full workflow simulation: agent encounters validator error, follows fix instructions, retries
- Verify error messages appear in session logs and are agent-readable

### Acceptance Tests (Manual)
- For each AC, document test case and evidence
- Validator catalog review by Architect
- Fix instruction review by Product Manager

### Regression Tests
- Ensure existing passing workflows still pass
- Verify no performance regression from error message generation

---

## Risk Factors

**Risk: Incomplete validator survey**
- *Mitigation:* Use grep patterns to find common error returns; manual code review of identified files
- *Impact:* Some validators might be missed; addressable in follow-up story

**Risk: Non-actionable fix instructions**
- *Mitigation:* Product Manager reviews error messages; manual walkthrough of agent-facing errors
- *Impact:* Agents still frustrated; addressable through iteration

**Risk: Performance impact from error message generation**
- *Mitigation:* Keep messages short; no I/O in error paths; benchmark before/after
- *Impact:* Minimal — error messages are generated only on failure (infrequent path)

---

## Timeline & Milestones

- **RED (test design):** Survey validators, catalog failures, design test structure
- **GREEN (implementation):** Add fix guidance to validators, implement tests
- **VERIFY (TEA):** Confirm all validators covered, tests passing
- **REVIEW (Reviewer):** Code review, manual walkthrough of error messages
- **FINISH (SM):** Merge to develop, update documentation

---
