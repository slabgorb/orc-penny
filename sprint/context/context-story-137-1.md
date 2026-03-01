---
parent: 137
---

# Story 137-1: Research spike — <switch> and <gate> tag design for stepped workflows

## Business Context

Story 137-1 is a research spike within Epic 137 (Stepped workflow modernization). The goal is to audit existing stepped workflows and design XML tag specifications for conditional branching and gate handling. This foundational work will inform implementation stories that modernize gate behavior, add step skipping capabilities, and enable collaborative workflows.

## Technical Guardrails

- Research only — no implementation code in this story
- Focus on existing stepped workflow files in `pennyfarthing-dist/workflows/`
- Design output: XML tag specs and ADR documentation
- Prototype designs in `architecture` step-03 YAML
- No changes to active workflows during research phase
- Ensure <output> tag contract covers format, target file, and required sections

## Scope Boundaries

**In Scope:**
- Audit all stepped workflows for conditional branching patterns (quick-dev mode, prerelease_skip_steps, architecture continuation)
- Design <switch> tag spec with on, case, default, next attributes
- Design enhanced <gate> tag spec for stepped context
- Rationalize <output> tag contract across all steps
- Write ADR documenting design decisions

**Out of Scope:**
- Implementation of <switch> or <gate> tags
- Changes to existing workflows
- Collaboration features (handled by separate story)
- UI/UX updates

## AC Context

1. **All stepped workflows audited** — identify conditional branching patterns in architecture, interview, and other stepped workflows
2. **<switch> tag spec designed** — document on, case, default, next attributes with examples
3. **Enhanced <gate> tag spec designed** — extend gate behavior for stepped context (e.g., continuation logic)
4. **Both prototypes in architecture step-03** — demonstrate spec usage in existing workflow YAML
5. **<output> tag contract rationalized** — every step declares format, target file, and required sections
6. **ADR written** — document design decisions, rationale, and impact
