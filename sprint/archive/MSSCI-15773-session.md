# Story 133-2: Add finding-capture to agent exit behaviors

## Story Details
- **ID:** 133-2
- **Jira Key:** MSSCI-15773
- **Title:** Add finding-capture to agent exit behaviors
- **Points:** 3
- **Epic:** 133 — Agent Finding Capture & Workflow Unblocking (MSSCI-15771)
- **Workflow:** tdd
- **Assignee:** keith.avery@1898andco.io

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-27T13:27:28Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-27T08:15:00-06:00 | 2026-02-27T13:16:20Z | -3520s |
| red | 2026-02-27T13:16:20Z | 2026-02-27T13:21:36Z | 5m 16s |
| green | 2026-02-27T13:21:36Z | 2026-02-27T13:24:30Z | 2m 54s |
| verify | 2026-02-27T13:24:30Z | 2026-02-27T13:26:02Z | 1m 32s |
| review | 2026-02-27T13:26:02Z | 2026-02-27T13:27:28Z | 1m 26s |
| finish | 2026-02-27T13:27:28Z | - | - |

## Business Context

This story is part of epic 133 which implements a systematic approach for agents to capture and report findings discovered during story delivery.

**Background:** The session file is the source of truth for story context, and the PR description is the primary artifact read by the boss. Session files must capture not just workflow mechanics (phases, assessments, handoffs) but also **upstream effects discovered during implementation**: spec gaps, architecture issues, documentation drift.

Previously these observations were buried in free-text agent assessments. The boss had to read all three assessments (TEA, Dev, Reviewer) to extract findings that matter for future planning. Nothing flowed upward.

**Story 133-1** (completed) added the `## Delivery Findings` section placeholder to the session template. **Story 133-2** adds the actual finding-capture behavior to agent exit flows — each agent (TEA, Dev, Reviewer) must append findings to the Delivery Findings section during their exit protocol before handoff.

**Success Criteria:** Every agent that enters a TDD workflow must have finding-capture instructions in their assessment template. When an agent exits, they append their findings to the session file using the ADR-0031 format. The SM then compiles these into an Impact Summary and generates the PR description from the session file.

## Technical Context

### Key Files to Modify

From ADR-0031 Files Affected table:

| File | Changes |
|------|---------|
| `pennyfarthing-dist/agents/tea.md` | Add finding-capture section to assessment template (red and verify phases) |
| `pennyfarthing-dist/agents/dev.md` | Add finding-capture section to assessment template (green phase) |
| `pennyfarthing-dist/agents/reviewer.md` | Add finding-capture template to review phase assessment |
| `pennyfarthing-dist/agents/sm.md` | **No changes in this story** (that's 134-1 — Impact Summary compilation) |

### Finding Format (from ADR-0031)

Each finding is a markdown list item appended to `## Delivery Findings` in the session file:

```markdown
- **{Type}** ({urgency}): {One sentence description}.
  Affects `{relative/path/to/doc.md}` ({what needs to change}).
  *Found by {Agent} during {human-phase-name}.*
```

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking
**Human phase names:** test design (TEA red), implementation (Dev green), test verification (TEA verify), code review (Reviewer)

If an agent has no findings:

```markdown
- No upstream findings during {human-phase-name}.
```

### Workflow Context

The **tdd** workflow has six phases:

1. **setup** (SM) — Create session file with Delivery Findings section placeholder
2. **red** (TEA) — Design failing tests → append findings if any
3. **green** (Dev) — Implement to pass tests → append findings if any
4. **verify** (TEA) — Verify quality and test coverage → append findings if any
5. **review** (Reviewer) — Code review → append findings if any
6. **finish** (SM) — Compile Impact Summary and create PR with full body

This story modifies steps 2, 3, 4, and 5.

### Acceptance Criteria

- [ ] TEA assessment template (red phase) includes finding-capture section with format
- [ ] TEA assessment template (verify phase) includes finding-capture section with format
- [ ] Dev assessment template (green phase) includes finding-capture section with format
- [ ] Reviewer assessment template (review phase) includes finding-capture section with format
- [ ] All finding-capture sections explain the ADR-0031 format (Type, urgency, path, agent, phase)
- [ ] All sections include example: "- No upstream findings during {phase}."
- [ ] Assessment templates explain: "Agents ONLY append to ## Delivery Findings. Never edit or remove another agent's entries."
- [ ] No changes to sm.md in this story (SM compilation is 134-1)
- [ ] No changes to gates or exit protocols — only assessment templates
- [ ] tdd workflow tests still pass

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

- No upstream findings during test design.
- No upstream findings during implementation.
- No upstream findings during test verification.
- No upstream findings during code review.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Agent definition files must contain finding-capture instructions per ADR-0031

**Test Files:**
- `tests/python/test_finding_capture.py` - 30 pytest tests covering all 10 ACs

**Tests Written:** 30 tests covering 10 ACs
**Status:** RED (23 failing, 7 passing — guard rails hold)

**Test Categories:**
- AC1-4: Agent-specific reference tests (TEA red/verify, Dev green, Reviewer review)
- AC5: Finding format tests (types, urgency, format template) — parametrized across 3 agents
- AC6: "No upstream findings" example — parametrized across 3 agents
- AC7: Append-only rule — parametrized across 3 agents
- AC8: SM exclusion (passing — sm.md has no finding-capture, correct)
- AC9: Exit section guard (passing — no Delivery Findings in `<exit>` sections)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/tea.md` - Added Delivery Findings capture section to assessment template (red + verify phases)
- `pennyfarthing-dist/agents/dev.md` - Added Delivery Findings capture section to assessment template (green phase)
- `pennyfarthing-dist/agents/reviewer.md` - Added Delivery Findings capture section to assessment templates (review phase)

**Tests:** 30/30 passing (GREEN)
**Branch:** feat/133-2-finding-capture-agent-exit (pushed)

**Handoff:** To next phase (verify or review)

## TEA Verify Assessment

**Tests:** 30/30 passing (GREEN)
**Implementation Quality:** Clean — finding-capture sections placed correctly in `<assessment-template>` tags, not in `<exit>` sections
**ADR-0031 Compliance:** Format matches spec exactly. All four types, both urgency levels, human phase names correct.
**Scope:** No changes to sm.md, no changes to gates or exit protocols. Only assessment templates modified.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Agent reads finding-capture instructions from `<assessment-template>` → writes findings to `## Delivery Findings` in session file (safe because append-only, no cross-agent mutation)
**Pattern observed:** Consistent subsection structure across all three agent files at tea.md:136, dev.md:162, reviewer.md:132 — ADR-0031 format replicated exactly
**Error handling:** TEA correctly handles dual-phase with `{phase-name}` placeholder and phase name table; Dev/Reviewer hardcode their single phases — appropriate asymmetry
**Handoff:** To SM for finish-story

## SM Assessment

Story 133-2 is a 3-point TDD story adding finding-capture to agent exit behaviors in tea.md, dev.md, and reviewer.md. ADR-0031 defines the exact format. This is a documentation/template change — modifying agent definition markdown, not executable code. TEA should write tests that verify the finding-capture instructions exist in each agent's assessment template. No changes to sm.md (that's 134-1).