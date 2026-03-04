---
parent: context-epic-138.md
workflow: trivial
---

# Story 138-1: Create simplify-reuse subagent definition

## Business Context

The `simplify-reuse` agent catches code duplication before the Reviewer agent, reducing round-trip rejections. It operates as one member of a three-agent team spawned by TEA during the verify phase of TDD workflows. By analyzing changed files for duplicated logic and extractable helper functions, simplify-reuse helps keep implementations lean and DRY, improving framework health without changing the reviewer's adversarial role.

## Technical Guardrails

This is a **tactical subagent definition** — a Haiku-class helper that runs in isolation with no side effects. Follow the tactical agent template at `pennyfarthing-dist/agents/templates/agent-template-tactical.md` for consistent section ordering and structure.

### Core Requirements

- **Model:** Haiku (per Rule 7: never Opus for mechanical tasks)
- **Behavior:** Report-only. Do NOT modify files. Analyzes and suggests.
- **Invocation:** Via Agent tool with `run_in_background: true`, spawned by TEA with a file list
- **Output Format:** SIMPLIFY_RESULT YAML (see below)
- **Confidence Levels:** high, medium, low — TEA auto-applies high, reviews medium/low manually

### SIMPLIFY_RESULT Format

The subagent MUST return findings in this exact structure:

```yaml
SIMPLIFY_RESULT:
  agent: simplify-reuse
  status: clean | findings
  findings:
    - file: "path/to/file.ts"
      line: 42
      category: "duplicated-logic"
      description: "What was found"
      suggestion: "What to do about it"
      confidence: high | medium | low
```

If status is `clean`, the `findings` array is empty or omitted.

### Categories (for simplify-reuse)

- `duplicated-logic` — same code pattern appears multiple times
- `extractable-helper` — function that could be extracted to reduce duplication
- `shared-validation` — validation logic repeated across files or functions
- `copy-paste-pattern` — suspicious near-identical blocks
- `missing-abstraction` — pattern suggests a missing utility function

## Scope Boundaries

**In scope:**
- Definition file: `pennyfarthing-dist/agents/simplify-reuse.md`
- Follows tactical agent template: title, persona, role, helpers, responsibilities, skills, context, reasoning-mode, on-activation, Assessment Template, Handoff, exit
- Detailed behavior for analyzing changed files for duplication and extraction opportunities
- Example workflow showing input (file list from `git diff --name-only`), analysis, and output format

**Out of scope:**
- Integration into TEA verify phase — that's story 138-4
- The simplify-quality agent definition — that's story 138-2
- The simplify-efficiency agent definition — that's story 138-3
- Workflow YAML modifications (`tdd.yaml`, `tdd-tandem.yaml`) — those are story 138-5 and 138-6
- Session assessment template updates — that's story 138-7

## AC Context

A story is complete when:
- [ ] File `pennyfarthing-dist/agents/simplify-reuse.md` exists and follows the tactical template structure
- [ ] Agent definition clearly describes what files it receives and what it analyzes for
- [ ] Output format section shows the SIMPLIFY_RESULT YAML structure with representative fields
- [ ] Responsibilities include "analyze changed files for duplication" and "report findings only"
- [ ] Confidence levels (high/medium/low) are documented with TEA's decision rules
- [ ] The agent can be invoked via Agent tool with parameters: file list, story context (optional)
- [ ] No code modifications — the definition explicitly states "Report only. Do NOT edit files."
- [ ] Definition can be read and used as a template for simplify-quality and simplify-efficiency stories
