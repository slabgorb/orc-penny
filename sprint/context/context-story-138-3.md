---
parent: context-epic-138.md
workflow: trivial
---

# Story 138-3: Create simplify-efficiency subagent definition

## Business Context

Dev agents tend to over-engineer — introducing unnecessary abstractions, premature optimizations, and redundant operations that add complexity without value. The simplify-efficiency Haiku teammate targets this pattern, reviewing changed files for unnecessary complexity and over-engineering. Unlike linters or the Reviewer, this teammate is constructive: it identifies where code can be simplified, not where it's wrong. This is directly inspired by Claude Code's `/simplify` efficiency pass.

This is the third of three simplify teammate definitions. A key nuance: this teammate must respect intentional complexity (error handling, edge case coverage) and flag rather than force removal of such patterns.

## Technical Guardrails

- **Create:** `pennyfarthing-dist/agents/simplify-efficiency.md`
- **Follow:** Tactical agent template at `pennyfarthing-dist/agents/templates/agent-template-tactical.md`
- **Model:** Haiku (Rule 7)
- **Input contract:** Receives list of changed files from `git diff --name-only` (passed by TEA)
- **Output contract:** Returns `SIMPLIFY_RESULT` YAML format (see FR-5 in PRD)
- **Behavior:** Report findings only — does NOT modify files directly
- **Context isolation:** Receives only changed file list and file contents — no session history
- **Intentional complexity:** Must distinguish over-engineering from necessary complexity (error handling, edge cases). Flag ambiguous cases with `confidence: low` rather than asserting removal.

## Scope Boundaries

**In scope:**
- Agent definition markdown file with role, instructions, input/output contracts
- Focus areas: unnecessary complexity, redundant operations, over-engineering, premature abstractions
- Nuanced handling of intentional complexity (flag, don't force)
- Structured finding format with specific simplifications and rationale
- Confidence levels for each finding

**Out of scope:**
- TEA integration logic (story 138-4)
- Workflow YAML changes (story 138-5)
- SIMPLIFY_RESULT format definition (story 138-7 — but this agent must use the format)
- Performance optimization suggestions (this is about code simplicity, not runtime speed)
- Modifying any existing agent definitions

## AC Context

**Testable detail:**

- File created at `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/agents/simplify-efficiency.md`
- Contains all required tactical agent sections in correct order: `<persona>`, `<role>`, `<helpers>`, `<responsibilities>`, `<skills>`, `<context>`, `<reasoning-mode>`, `<on-activation>`, workflow section, assessment template, handoff protocol, `<exit>`
- `<responsibilities>` includes at least 4 efficiency-focused duties (e.g., unnecessary complexity detection, over-abstraction analysis, redundant operation identification, premature optimization flagging)
- `<helpers>` specifies Haiku model and describes what helper tasks do
- Workflow section describes: receive changed file list → analyze for efficiency issues → return SIMPLIFY_RESULT YAML with agent, status, and findings array
- Finding categories include `over-engineering`, `unnecessary-complexity`, `premature-abstraction`, `redundant-operations`, or equivalent
- Confidence guidance documented: high = objectively simpler after removal, medium = likely beneficial, low = ambiguous or potentially intentional (error handling, edge cases)
- Assessment template shows expected SIMPLIFY_RESULT output format with findings containing file, line, category, description, suggestion, confidence
- Handoff section present and follows pattern from tactical template (gate resolution, phase completion, marker)
