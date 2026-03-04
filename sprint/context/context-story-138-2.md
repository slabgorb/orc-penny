---
parent: context-epic-138.md
workflow: trivial
---

# Story 138-2: Create simplify-quality subagent definition

## Business Context

The Simplify Integration epic automates code quality review within the TEA verify phase by spawning three Haiku teammates, each analyzing changed files through a specific lens. **simplify-quality** is the second teammate, responsible for catching semantic quality issues (naming conventions, readability, code structure, dead code, unnecessary comments) that linters cannot detect. This prevents code review round-trips between Dev and Reviewer for quality-focused rejections.

## Technical Guardrails

**Subagent Definition Pattern:**
- Tactical agent per `pennyfarthing-dist/agents/templates/agent-template-tactical.md`
- Haiku model (Rule 7: never Opus for mechanical tasks)
- Report-only (no file modifications) — findings aggregated by TEA leader
- Receives changed file list from `git diff --name-only`
- Returns structured `SIMPLIFY_RESULT` YAML format (FR-5 in PRD)

**Lint Boundary:**
- Does NOT enforce eslint/ruff rules — focuses on semantic quality only
- Analyzes: naming clarity, readability, structure, dead code, unnecessary comments

## Scope Boundaries

**In scope:**
- `pennyfarthing-dist/agents/simplify-quality.md` agent definition file
- Tactical agent template structure (persona, role, helpers, responsibilities, skills, context, reasoning-mode, on-activation, workflows, assessment, handoff, exit)

**Out of scope:**
- NOT lint rules — that's eslint/ruff territory
- NOT file modifications — teams report only
- TEA integration (story 138-4)
- Workflow YAML updates (stories 138-5, 138-6)

## AC Context

Finding categories: `naming`, `readability`, `structure`, `dead-code`, `comments`

Example output:
```yaml
SIMPLIFY_RESULT:
  agent: simplify-quality
  status: clean | findings
  findings:
    - file: "path/to/file.ts"
      line: 42
      category: "naming"
      description: "Variable `x` obscures its purpose"
      suggestion: "Rename to `config_path` for clarity"
      confidence: high | medium | low
```

**Testable Detail:**
1. Agent file created at correct path following tactical template
2. Haiku model specified in definition
3. Input/output contracts documented
4. Finding categories scoped to semantic quality (not lint)
5. No file modification logic — report-only
6. Each finding includes confidence level
7. Lint overlap explicitly excluded from instructions
