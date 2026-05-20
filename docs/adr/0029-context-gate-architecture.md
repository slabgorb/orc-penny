# ADR-0029: Formalized Epic & Story Context Creation

**Status:** Proposed
**Date:** 2026-02-23
**Author:** architect (Leonard of Quirm)
**PRD:** sprint/planning/context-gate-prd.md

## Context

Pennyfarthing inherited epic and story context documents from BMAD. ~120 context files exist in `sprint/context/` but creation is entirely ad-hoc — no templates, no enforcement, inconsistent quality. Two bugs in the existing context-checking code mean the Cyclist sprint panel never accurately reflects context status:

1. **`checkStoryContext` (sprint-data.ts:198-201):** Looks for `{storyId}-context.md` but actual files use `context-story-{N-N}.md`. Every story context check returns false.
2. **`checkEpicContext` (sprint-data.ts:187-193):** Regex `\d+` fails for PROJ-keyed epics. PROJ epic context always returns false.

Three separate context-checking implementations exist today, none correct for all cases:

| Location | Bugs |
|----------|------|
| `sprint-data.ts:checkStoryContext()` | Wrong filename pattern |
| `sprint-data.ts:checkEpicContext()` | PROJ regex failure |
| `generic-sm-setup.ts:checkEpicContext()` | Works for numeric, untested for PROJ |

The correct implementation exists in Python (`story_detail_data.py:177-208`) but is only used by BikeRack story detail, not by gates or Cyclist.

### Problem Statement

No formalized process exists to create, validate, or enforce context documents before story work begins. TEA writes test strategy without full technical context. Dev starts implementation without knowing constraints the Architect would surface. Gates check file existence but not content quality.

### Decision Drivers

1. Gate-enforced context existence and quality before story work begins
2. Tandem-produced context (PM + Architect or UX-Designer) for richer technical detail
3. Single source of truth for section requirements (template and validator share one schema)
4. Reuse existing infrastructure — tandem protocol, gate system, skill invocation, ValidationResult pattern
5. Backward compatibility with ~50 existing epic context files (no frontmatter, varied heading styles)
6. Dual-consumer validation (Python canonical, TypeScript via subprocess) per NFR9

## Considered Options

### Option A: Separate Template + Schema (Rejected)

Maintain template as a standalone markdown file and schema as Python validation logic.

**Pros:** Simple, familiar pattern.
**Cons:** Template and schema drift over time. Adding a required section means editing two files.

### Option B: Single-Source Schema (Selected)

One YAML file (`context-schema.yaml`) defines required/optional sections. Template generation and validation both read this file.

**Pros:** Zero drift. Adding a section is one edit. Schema is reviewable YAML.
**Cons:** Template generation adds a small abstraction.

### Option C: SM Creates Context Inline (Rejected)

SM reads template and fills from sprint YAML, no skill invocation, no tandem.

**Pros:** Simplest possible implementation.
**Cons:** Loses tandem collaboration — the entire point is that PM + specialist produce better context than one agent alone.

### Option D: JSON Schema for Context Files (Rejected)

Use JSON Schema to validate markdown context files.

**Pros:** Industry standard.
**Cons:** Over-engineered. Context files are markdown with YAML frontmatter. A Python validator checking section headers is simpler and more maintainable.

### Option E: TypeScript Validator (Rejected)

Write validation logic in TypeScript alongside the existing TS code.

**Pros:** Same language as Cyclist.
**Cons:** Creates a second implementation. NFR9 requires dual-consumer — Python is canonical, TS calls via subprocess (established pattern from story 125-3).

## Decision Outcome

**Selected: Single-Source Schema with Tandem Context Creation**

### Component Structure

```
SM Agent (setup phase)
  │
  │ 1. handoff resolve-gate → sm-setup-exit gate
  │    gate calls: pf context-docs validate epic {N}
  │                pf context-docs validate story {N-N}
  │
  │ 2. If fail → invoke /pf-context create
  ▼
┌─────────────────────────────────────────────────────┐
│  /pf-context Skill                                  │
│  Reads: story workflow field → selects tandem partner│
│  Spawns: PM (primary) + Partner (backseat)          │
│                                                     │
│  ┌────────────┐    tandem     ┌──────────────────┐  │
│  │ PM Agent   │◄──injection──►│ Architect or UX  │  │
│  │ (primary)  │               │ (backseat)       │  │
│  └─────┬──────┘               └──────────────────┘  │
│        │ Reads schema → fills template → writes     │
│        ▼                                            │
│  sprint/context/context-{type}-{id}.md              │
└─────────────────────────────────────────────────────┘
  │
  │ 3. SM re-runs gate → pass
  ▼
TEA Agent (RED phase)
  │ Reads: context-epic-{N}.md + context-story-{N-N}.md
```

| Component | Responsibility | Location |
|-----------|---------------|----------|
| Context Schema | Defines required/optional sections for epic and story context | `pennyfarthing-dist/templates/context-schema.yaml` |
| Context Validator | Validates context files against schema | `pf/context_docs/validate.py` |
| Context Validator CLI | `pf context-docs validate {type} {id}` — exit 0/1/2 + YAML stdout | `pf/context_docs/cli.py` |
| `/pf-context` Skill | Orchestrates creation: PM primary + tandem backseat | `pennyfarthing-dist/skills/pf-context/skill.md` |
| sm-setup-exit Gate | Sequential cascade: epic context → story context | `pennyfarthing-dist/gates/sm-setup-exit.md` (updated) |
| Bug Fixes | Fix filename pattern + PROJ regex | `packages/cyclist/src/sprint-data.ts` |

### Interfaces

**`pf context-docs validate {type} {id}`** — CLI contract:

```yaml
# stdout (YAML)
valid: true|false
type: epic|story
id: "97"
file: "sprint/context/context-epic-97.md"
errors:
  - message: "Missing required section: Technical Architecture"
    path: "sections.technical_architecture"
    severity: error|warning
```
Exit codes: 0 = valid, 1 = invalid, 2 = file not found.

**Context Schema** (`context-schema.yaml`):

```yaml
epic:
  required_sections: [Overview, Background, Technical Architecture]
  optional_sections: [Planning Documents, Cross-Story Dependencies]
  required_frontmatter: []
story:
  required_sections: [Business Context, Technical Guardrails, Scope Boundaries, AC Context]
  optional_sections: [Interaction Patterns, Accessibility Requirements, Visual Constraints]
  required_frontmatter: [parent]
```

**Story context frontmatter:**
```yaml
---
parent: context-epic-{N}.md
workflow: tdd
---
```

**Tandem partner selection:** `tdd`/`trivial` → Architect, `bdd`/`bdd-tandem` → UX-Designer. Override via `--tandem` flag.

## Consequences

### Positive

- Gate-enforced context eliminates "Dev didn't know about the constraint" failures
- Single-source schema prevents template/validator drift — one edit adds a section everywhere
- Tandem creation (PM + specialist) produces richer context than any single agent
- Reuses five existing patterns: ValidationResult, gate-calls-script, skill infrastructure, tandem protocol, Python CLI
- Backward compatible: ~50 existing epic context files pass validation without modification
- Bug fixes restore accurate `hasContext` display in Cyclist sprint panel

### Negative

- Two subprocess calls added to SM setup gate (< 4s total latency)
- New Python module (`pf/context_docs/`) adds to the `pf/` package surface area
- Tandem backseat failure is silent (PM continues solo) — context may lack specialist input without operator noticing

### Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Backward incompat with existing epic files | High | Med | No frontmatter required for epics, fuzzy section heading match |
| `pf/context.py` naming collision | Med | High | Module at `pf/context_docs/`, separate CLI group |
| Tandem backseat crash | Low | Med | PM continues solo, log warning, context still valid |
| Schema YAML not found at runtime | High | Low | Resolved via `find-root.sh` pattern, hardcoded fallback |
| Story 125-3 removes TS check functions | Low | Med | Bug fix is 2 lines, harmlessly gone if removed |
| Agent hardcodes section names | Med | Med | Consistency Rule #2: schema is ONLY authority |

## Implementation Consistency Rules

> These rules prevent AI agents from making conflicting implementation choices.

1. **Context file naming is canonical:** Epic = `context-epic-{id}.md`, Story = `context-story-{id}.md`. Raw ID, no `epic-` prefix.
2. **Schema is the ONLY authority for required sections.** Templates and validators MUST read `context-schema.yaml`. Never hardcode section names.
3. **Validator returns ValidationResult, not exceptions.** Follow `sprint/validator.py` pattern.
4. **Gate calls CLI, not Python directly.** `pf context-docs validate` is the interface for gates.
5. **Tandem partner selection follows workflow field.** `tdd`/`trivial` → Architect, `bdd`/`bdd-tandem` → UX-Designer.
6. **SM attempts ONE creation per level, then fails.** No retry loops.
7. **Context files live in `sprint/context/` only.**
8. **Story context frontmatter MUST have `parent:` field** linking to existing epic context.
9. **`--no-tandem` flag skips partner spawn.** Manual escape hatch.
10. **Bug fixes are additive.** Fix patterns, don't refactor surrounding code.

## Implementation Plan

| # | Deliverable | Depends On | Repo |
|---|-------------|------------|------|
| 1 | Fix `checkStoryContext` + `checkEpicContext` in sprint-data.ts | — | pennyfarthing |
| 2 | Context schema YAML (`context-schema.yaml`) | — | pennyfarthing |
| 3 | Context validator Python module + CLI (`pf/context_docs/`) | #2 | pennyfarthing |
| 4 | Context document templates (generated from schema) | #2 | pennyfarthing |
| 5 | `/pf-context create epic` skill | #2, #4 | pennyfarthing |
| 6 | `/pf-context create story` skill with tandem selection | #2, #4, #5 | pennyfarthing |
| 7 | Update `sm-setup-exit` gate (sequential cascade) | #1, #3 | pennyfarthing |
| 8 | TEA agent update — read context during RED phase | #3 | pennyfarthing |

Items 1-4 are independent and can be parallelized. Items 5-6 are the critical path. Items 7-8 integrate the pipeline.

## Related Decisions

- [ADR-0009: Session File Coordination](0009-session-file-coordination.md) — session file patterns used by context creation
- [ADR-0012: Tandem Agent Pairing](0012-tandem-agent-pairing.md) — tandem protocol reused for PM + specialist
- [ADR-0025: Script-First Gate Extraction](0025-script-first-gate-extraction.md) — gate file schema, CLI-based gate evaluation

---

*Generated by Pennyfarthing architecture workflow*
