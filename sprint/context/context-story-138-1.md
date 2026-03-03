---
parent: 138
workflow: trivial
---

# Story 138-1: Create simplify-reuse subagent definition

## Business Context

Code duplication is one of the most common quality issues in agentic coding sessions. Dev agents frequently reimplement logic that already exists elsewhere, creating maintenance burdens and inconsistency. The simplify-reuse Haiku teammate addresses this by scanning changed files for duplicated logic, extractable helpers, and shared patterns — catching reuse opportunities before the Reviewer ever sees the code. This reduces Dev-Reviewer round-trips and produces cleaner, more maintainable output.

This is the first of three simplify teammate definitions. Each teammate focuses on a single quality dimension with an isolated context window, keeping token costs low (Rule 7: Haiku for mechanical tasks).

## Technical Guardrails

- **Create:** `pennyfarthing-dist/agents/simplify-reuse.md`
- **Follow:** Tactical agent template at `pennyfarthing-dist/agents/templates/agent-template-tactical.md`
- **Model:** Haiku (Rule 7 — never Opus for mechanical tasks)
- **Input contract:** Receives list of changed files from `git diff --name-only` (passed by TEA)
- **Output contract:** Returns `SIMPLIFY_RESULT` YAML format (see FR-5 in PRD)
- **Behavior:** Report findings only — does NOT modify files directly
- **Context isolation:** Receives only changed file list and file contents — no session history, no story context
- **Lint boundary:** Focuses on semantic reuse (duplicated logic, extractable patterns) — does NOT flag style issues already caught by eslint/ruff

## Scope Boundaries

**In scope:**
- Agent definition markdown file with role, instructions, input/output contracts
- Focus areas: duplicated logic across changed files, extractable helpers, shared patterns
- Structured finding format with file paths, line references, and suggested extractions
- Confidence levels (high/medium/low) for each finding

**Out of scope:**
- TEA integration logic (story 138-4)
- Workflow YAML changes (story 138-5)
- SIMPLIFY_RESULT format definition (story 138-7 — but this agent must use the format)
- Modifying any existing agent definitions
- Runtime behavior — this is a static agent definition file

## AC Context

1. **Agent file exists at correct path** — `pennyfarthing-dist/agents/simplify-reuse.md` is created following the tactical agent template structure
2. **Haiku model specified** — Agent definition specifies Haiku as the model, consistent with Rule 7
3. **Input contract defined** — Agent expects a list of changed file paths and reads those files for analysis
4. **Output contract uses SIMPLIFY_RESULT format** — Returns structured YAML with `agent: simplify-reuse`, status, and findings array
5. **Finding categories appropriate to reuse** — Categories include `duplicated-logic`, `extractable-helper`, `shared-pattern`, etc.
6. **Report-only behavior explicit** — Agent instructions clearly state it reports findings and does NOT modify files
7. **Confidence levels assigned** — Each finding includes `confidence: high | medium | low` to guide TEA's aggregation decisions
