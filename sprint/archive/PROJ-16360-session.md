# Session: PROJ-16360 — Create native subagent definitions for TEA and Reviewer

## Story
- **ID:** 143-2 / PROJ-16360
- **Epic:** 143 — Native Subagent Migration (PROJ-16358)
- **Points:** 3
- **Type:** Feature
- **Priority:** P0
- **Workflow:** trivial
- **Branch:** feat/143-2-native-subagent-tea-reviewer-defs

## Description

Create native Claude Code subagent definitions for the TEA (Test Engineer) and Reviewer agents in `pennyfarthing-dist/agents/native/`. These definitions will be deployed at runtime via `.pennyfarthing/agents/` symlinks, enabling isolated context windows for testing and code review phases.

Reference the Dev agent definition (created in PR #144) as a template. Follow ADR-0037 tool restrictions and assessment templates.

## Acceptance Criteria

1. TEA definition created at `pennyfarthing-dist/agents/native/tea.md`
   - Follows Dev template pattern
   - Includes test-driven discipline block
   - Defines allowed-tools for test file write/edit only
   - Includes Pre-Test Topology Check section
   - Includes TEA Assessment template

2. Reviewer definition created at `pennyfarthing-dist/agents/native/reviewer.md`
   - Follows Dev template pattern
   - Includes adversarial mindset discipline block
   - Defines allowed-tools for read-only + bash
   - Includes Pre-Review Topology Check section
   - Includes Reviewer Assessment template

3. Both files follow agent definition conventions:
   - YAML frontmatter with proper metadata
   - Markdown sections with clear hierarchy
   - Consistent with agent-template-strategic.md guidance
   - Include workflow step-by-step instructions
   - Include assessment/handoff templates for SM consumption

4. Files integrated into pennyfarthing-dist:
   - Deployed at runtime via `.pennyfarthing/agents/` symlink
   - Tested that files are readable and valid YAML/Markdown
   - Committed to feat/143-2 branch

## Phase: setup

**Started:** 2026-03-12
**Session Lead:** SM-setup (Haiku subagent)

## SM Assessment

**Setup Complete:** Yes
**Session:** Created with story metadata and ACs
**Branch:** feat/143-2-native-subagent-tea-reviewer-defs (pennyfarthing repo, off develop)
**Jira:** PROJ-16360 claimed
**Context:** 143-2-context.md created with technical approach
**Reference:** native/dev.md from story 143-1 serves as template

**Handoff:** To Dev for implementation (trivial workflow → implement phase)

## Design Deviations

### Dev (implementation)
- **TEA tool restrictions:** AC says "allowed-tools for test file write/edit only" but Claude Code frontmatter `allowed-tools` cannot restrict by file path — only by tool name. TEA gets full Write/Edit/Bash. Reason: file-path restrictions require gate validation per ADR-0037, not frontmatter enforcement. → ✓ ACCEPTED by Reviewer: Correct — Claude Code `allowed-tools` has no path-scoping. Gate enforcement is the right layer per ADR-0037.
- **Reviewer tool list:** AC says "read-only + bash" — implemented as Read, Bash, Glob, Grep, Agent (no Write/Edit). Agent tool included so Reviewer can spawn its 8 specialist subagents. → ✓ ACCEPTED by Reviewer: Agent tool is required for specialist subagent spawning. Read-only intent preserved by excluding Write/Edit.

## Delivery Findings

### Dev (implementation)
- **Gap** (non-blocking): ADR-0037 notes file-path tool restrictions "may need enforcement via agent instructions + gate validation" — no gate exists yet to verify TEA only edits test files or Dev only edits prod files. Affects `pennyfarthing-dist/gates/` (needs new gate). *Found by Dev during implementation.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/native/tea.md` — Native subagent definition for TEA with test-paranoia discipline, RED/verify workflows, simplify fan-out, assessment/handoff templates
- `pennyfarthing-dist/agents/native/reviewer.md` — Native subagent definition for Reviewer with adversarial mindset, read-only tools, 8 specialist subagents, severity-gated verdicts, deviation audit

**Tests:** N/A (markdown definition files, validated by `pf validate agent` — 27 passed, 3 warnings pre-existing)
**Branch:** feat/143-2-native-subagent-tea-reviewer-defs (pushed)

**Self-review:**
- [x] Files accessible via `.pennyfarthing/agents/native/` symlink
- [x] YAML frontmatter valid (parsed successfully)
- [x] Agent validation passed
- [x] All ACs met
- [x] Follows dev.md template pattern
- [x] Working tree clean
- [x] Correct branch

**Handoff:** To Reviewer (Queen of Hearts) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** SM prompt → native agent file loaded → agent receives session context + persona via prompt → agent writes deliverables + handoff doc → returns to SM. Static definitions, no runtime data flow within.
**Pattern observed:** Both files follow ADR-0037 faithfully — static role + tools in YAML frontmatter, dynamic context via SM prompt injection. Consistent with `native/dev.md` template at lines 1-14.
**Error handling:** N/A — markdown definition files, no runtime error paths.
**Observations:** 2 medium (missing `<critical>` CAN/CANNOT boundary tags on TEA, bare-text critical block on Reviewer — both consistent with dev.md template pattern), 1 low (verify workflow summarized vs in-conversation detail — acceptable since SM injects full context). None blocking. All suitable for follow-up in subsequent epic stories.

**Handoff:** To the Mad Hatter (SM) for finish-story