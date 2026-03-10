---
parent: context-epic-142.md
workflow: tdd
---

# Story 142-2: BMAD Simulator CLAUDE.md Template and Story File

## Business Context

This story creates the BMAD simulator — the CLAUDE.md templates that faithfully reproduce what a BMAD dev and reviewer agent would see during a benchmark run. Without these templates, there's no BMAD pipeline to compare against. The templates must use BMAD's actual instructions verbatim with zero Pennyfarthing contamination, so the comparison is defensible.

This is a dependency for story 142-3 (Pipeline Replay BMAD Adapter) which wires these templates into the Peloton harness.

## Technical Guardrails

### Corrected BMAD Source Files

**Per ADR-0035 and delivery findings from 142-1:** The PRD/epic breakdown references `instructions.xml` but BMAD v6 uses `workflow.md` files. The correct source files are:

| File | Purpose |
|------|---------|
| `BMAD-METHOD/src/bmm/agents/dev.agent.yaml` | Full agent definition: "Amelia" persona, critical_actions, principles, menu triggers |
| `BMAD-METHOD/src/bmm/workflows/4-implementation/dev-story/workflow.md` | 10-step dev workflow with `<workflow>` XML tags |
| `BMAD-METHOD/src/bmm/workflows/4-implementation/dev-story/checklist.md` | Enhanced Definition of Done checklist |
| `BMAD-METHOD/src/bmm/workflows/4-implementation/code-review/workflow.md` | 5-step adversarial review workflow |
| `BMAD-METHOD/src/bmm/workflows/4-implementation/code-review/checklist.md` | Senior Developer Review validation checklist |
| `BMAD-METHOD/src/bmm/workflows/4-implementation/create-story/template.md` | Story file format template |

**Pinned commit:** `b7315c6e329eb72dc464f4e540bb67cdd22a9749`

### CLAUDE.md Construction (from ADR-0035)

**BMAD Dev CLAUDE.md:**
1. Agent persona (dev.agent.yaml → persona section — role, identity, communication_style, principles)
2. Critical actions (dev.agent.yaml → critical_actions — all 8 rules)
3. Dev workflow (dev-story/workflow.md — verbatim, full XML)
4. Definition of Done checklist (dev-story/checklist.md — verbatim)
5. Story file content (translated from scenario context)
6. project-context.md (target project coding standards)

**BMAD Reviewer CLAUDE.md:**
1. Adversarial reviewer role (code-review/workflow.md preamble)
2. Code review workflow (code-review/workflow.md — verbatim, full XML)
3. Review checklist (code-review/checklist.md — verbatim)

### Key Constraint: No PF Contamination

The templates must NOT contain:
- Pennyfarthing persona themes or character names
- Sidecar content (patterns, gotchas, decisions)
- Session file references or workflow engine state
- BikeLane phase/handoff/gate system references
- Tandem protocol, bell mode, relay mode references

### Story File Translation (from ADR-0035)

When translating PF scenario context to BMAD story file format:
- `## Story` — reformat as "As a... I want... so that..."
- `## Acceptance Criteria` — copy verbatim (already Given/When/Then)
- `## Tasks / Subtasks` — leave empty (ADR-0035 documents the risk and rationale)
- `## Dev Notes` — combine epic Technical Architecture + story Technical Guardrails
- `## Dev Agent Record`, `## File List` — leave empty (populated by BMAD agent)

### Location

Templates should live in the pennyfarthing framework repo since they're part of the benchmark infrastructure. Likely location: `pennyfarthing-dist/` under the benchmark or peloton area. Follow existing patterns for benchmark assets.

## Scope Boundaries

**In scope:**
- BMAD dev CLAUDE.md template (static template with verbatim BMAD content injection points)
- BMAD reviewer CLAUDE.md template
- Story file translator function (PF scenario context → BMAD story file format)
- Tests verifying templates contain BMAD content and exclude PF content

**Out of scope:**
- `--pipeline bmad` flag on replay harness (story 142-3)
- Worktree setup logic (story 142-3)
- Context parity verification (story 142-4)
- Running benchmarks (story 142-5)

## AC Context

### AC1: BMAD Dev CLAUDE.md Template

The template must inject all sections from dev.agent.yaml (persona, critical_actions, principles — not just the "Amelia" name) plus the full workflow.md and checklist.md verbatim.

**Testable:** Template output contains exact strings from BMAD source files. No PF-specific strings present. Sections appear in the documented order.

**Edge case:** The dev.agent.yaml has YAML frontmatter with markdown body — the template needs to parse both the structured fields (persona, critical_actions) and render them as CLAUDE.md sections.

### AC2: BMAD Reviewer CLAUDE.md Template

Same pattern but simpler — no separate agent definition file, just the code-review workflow.md preamble + workflow + checklist.

**Testable:** Template output contains exact strings from code-review source files. No PF reviewer agent content present.

### AC3: Story File Translator

Given a Peloton scenario's context documents (epic context + story context), produce a BMAD-format story file following create-story/template.md structure.

**Testable:** Output follows BMAD template structure. Story, AC, Dev Notes sections populated. Tasks/Subtasks and Dev Agent Record sections present but empty. story_path is provided in the prompt.

**Edge case:** What if the scenario context docs have different section names than expected? The translator should be resilient to minor variations.
