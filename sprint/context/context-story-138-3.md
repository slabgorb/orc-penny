---
parent: 138
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

1. **Agent file exists at correct path** — `pennyfarthing-dist/agents/simplify-efficiency.md` is created following the tactical agent template structure
2. **Haiku model specified** — Agent definition specifies Haiku as the model, consistent with Rule 7
3. **Input contract defined** — Agent expects a list of changed file paths and reads those files for analysis
4. **Output contract uses SIMPLIFY_RESULT format** — Returns structured YAML with `agent: simplify-efficiency`, status, and findings array
5. **Finding categories appropriate to efficiency** — Categories include `over-engineering`, `premature-abstraction`, `redundant-operation`, `unnecessary-complexity`, etc.
6. **Intentional complexity respected** — Agent instructions acknowledge that error handling and edge case coverage may look like over-engineering but are often intentional; these should be flagged with low confidence, not asserted as problems
7. **Report-only behavior explicit** — Agent reports findings with simplification rationale, does NOT modify files
8. **Confidence levels assigned** — Each finding includes `confidence: high | medium | low`, with ambiguous cases defaulting to low
