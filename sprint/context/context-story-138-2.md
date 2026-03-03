---
parent: 138
workflow: trivial
---

# Story 138-2: Create simplify-quality subagent definition

## Business Context

Agentic code often suffers from poor naming, unclear structure, dead code, and unnecessary comments — issues that are semantic rather than syntactic, making them invisible to linters. The simplify-quality Haiku teammate fills this gap by reviewing changed files for readability and structural quality. By catching these issues during TEA's verify phase, the Reviewer can focus on logic bugs and security rather than rejecting code for naming or readability problems, reducing round-trip cycles.

This is the second of three simplify teammate definitions, each operating in an isolated context window for token efficiency.

## Technical Guardrails

- **Create:** `pennyfarthing-dist/agents/simplify-quality.md`
- **Follow:** Tactical agent template at `pennyfarthing-dist/agents/templates/agent-template-tactical.md`
- **Model:** Haiku (Rule 7)
- **Input contract:** Receives list of changed files from `git diff --name-only` (passed by TEA)
- **Output contract:** Returns `SIMPLIFY_RESULT` YAML format (see FR-5 in PRD)
- **Behavior:** Report findings only — does NOT modify files directly
- **Context isolation:** Receives only changed file list and file contents — no session history
- **Lint boundary:** Does NOT enforce style rules already covered by eslint/ruff — focuses on semantic quality (naming clarity, readability, structure, dead code, unnecessary comments)

## Scope Boundaries

**In scope:**
- Agent definition markdown file with role, instructions, input/output contracts
- Focus areas: naming conventions, readability, code structure, dead code, unnecessary comments
- Structured finding format with specific improvements and rationale
- Confidence levels for each finding

**Out of scope:**
- TEA integration logic (story 138-4)
- Workflow YAML changes (story 138-5)
- SIMPLIFY_RESULT format definition (story 138-7 — but this agent must use the format)
- Style enforcement that overlaps with linters (indentation, semicolons, etc.)
- Modifying any existing agent definitions

## AC Context

1. **Agent file exists at correct path** — `pennyfarthing-dist/agents/simplify-quality.md` is created following the tactical agent template structure
2. **Haiku model specified** — Agent definition specifies Haiku as the model, consistent with Rule 7
3. **Input contract defined** — Agent expects a list of changed file paths and reads those files for analysis
4. **Output contract uses SIMPLIFY_RESULT format** — Returns structured YAML with `agent: simplify-quality`, status, and findings array
5. **Finding categories appropriate to quality** — Categories include `naming`, `readability`, `dead-code`, `unnecessary-comment`, `structure`, etc.
6. **No lint overlap** — Agent instructions explicitly state it does NOT flag issues already caught by eslint or ruff
7. **Report-only behavior explicit** — Agent reports findings with rationale, does NOT modify files
8. **Confidence levels assigned** — Each finding includes `confidence: high | medium | low`
