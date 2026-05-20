---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain-skipped
  - step-06-innovation-skipped
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
classification:
  projectType: developer_tool
  domain: developer_productivity_agent_orchestration
  complexity: medium
  projectContext: brownfield
inputDocuments:
  - ~/Projects/BMAD-METHOD/src/bmm/workflows/4-implementation/create-story/instructions.xml
  - ~/Projects/BMAD-METHOD/src/bmm/workflows/4-implementation/create-story/template.md
  - ~/Projects/BMAD-METHOD/src/bmm/workflows/4-implementation/create-story/checklist.md
  - ~/Projects/BMAD-METHOD/src/bmm/workflows/3-solutioning/create-epics-and-stories/steps/step-01-validate-prerequisites.md
  - ~/Projects/BMAD-METHOD/src/bmm/workflows/3-solutioning/create-epics-and-stories/steps/step-02-design-epics.md
  - ~/Projects/BMAD-METHOD/src/bmm/workflows/3-solutioning/create-epics-and-stories/steps/step-03-create-stories.md
  - ~/Projects/BMAD-METHOD/src/bmm/workflows/3-solutioning/create-epics-and-stories/steps/step-04-final-validation.md
  - pennyfarthing/pennyfarthing-dist/gates/sm-setup-exit.md
  - pennyfarthing/pennyfarthing-dist/guides/tandem-protocol.md
  - pennyfarthing/pennyfarthing-dist/guides/bikelane.md
  - pennyfarthing/pennyfarthing-dist/guides/session-artifacts.md
  - sprint/context/context-epic-97.md
documentCounts:
  bmadWorkflows: 7
  pfGates: 1
  pfGuides: 3
  pfContextExamples: 1
workflowType: 'prd'
---

# Product Requirements Document - Formalized Epic & Story Context Creation

**Author:** Keith Avery
**Date:** 2026-02-23

## Executive Summary

Pennyfarthing inherited the concept of epic and story context documents from BMAD, where they provide structured technical context that downstream agents (TEA, Dev) consume during implementation. In Pennyfarthing, ~120 context files exist in `sprint/context/` but creation is entirely ad-hoc — no templates, no enforcement, inconsistent quality. Two bugs in the existing context-checking code (`checkStoryContext` uses a legacy filename pattern, `checkEpicContext` fails for PROJ-keyed epics) mean the Cyclist sprint panel never accurately reflects context status.

This PRD defines a formalized context creation system: a `/pf-context create` skill that generates context documents via PM+Architect or PM+UX-Designer tandem sessions, a schema validator that checks structure and content, and gate updates that enforce context existence before story work begins. TEA consumes context as primary input for test strategy.

**Differentiator:** Gate-enforced, tandem-produced context documents that eliminate the gap between what the epic says and what the Dev actually knows when starting work.

## Success Criteria

### User Success

- SM activates for story setup → gate checks for epic and story context → if missing, SM triggers context creation workflow before proceeding
- Context creation workflow produces a document the Dev can use as primary reference without re-reading upstream artifacts
- PM+Architect tandem (technical stories) and PM+UX-Designer tandem (UX stories) produce context collaboratively in a single pass
- TEA reads story/epic context as primary input for test strategy — no more inferring acceptance criteria from session files alone
- Developer reports zero "I had to go read the epic PRD myself" moments after context exists

### Business Success

- 100% of stories started through PF workflows have context documents (gate-enforced, no exceptions)
- Context creation adds minimal ceremony — under 10 minutes for a typical 2-3 point story
- Eliminates the current drift between what's in the epic and what the Dev actually knows when starting work

### Technical Success

- Gate validates both epic context (`context-epic-{N}.md`) and story context (`context-story-{N-N}.md`) existence and required sections
- Two existing bugs fixed: `checkStoryContext` legacy filename pattern, `checkEpicContext` PROJ-key regex
- Architect agent performs quality review of generated context before gate passes
- Context creation integrates with existing skill invocation infrastructure
- Tandem configuration reuses existing tandem protocol infrastructure — no new plumbing
- TEA agent loads context documents during test strategy phase (RED)

### Measurable Outcomes

| Metric | Target |
|--------|--------|
| Stories with context at start | 100% (gate-enforced) |
| Context creation time | < 10 min per story |
| Context bugs (legacy filename, regex) | 0 (fixed) |
| Gate coverage | Epic + Story context checked |
| Quality control | Architect review before gate pass |
| TEA context utilization | 100% of stories |

## User Journeys

### Journey 1: Captain Carrot (SM) — Story Setup (Happy Path)

Captain Carrot activates for story 127-3. Runs `sm-setup-exit` gate. Gate checks:
1. Session file exists — yes
2. Session fields set — yes
3. Epic context exists (`context-epic-127.md`) — yes
4. **Story context exists (`context-story-127-3.md`) — no**

Gate fails with clear message: *"Story context missing. Triggering context creation."*

Captain Carrot invokes the context creation workflow. Workflow detects story is labeled `tdd` (technical) → selects PM+Architect tandem. Tandem runs, produces `context-story-127-3.md`. Architect reviews, approves quality. Captain Carrot re-runs gate — passes. Proceeds to TEA handoff.

**Reveals:** Gate failure messaging, automatic tandem selection, re-run after creation.

### Journey 2: Lord Vetinari (PM) + Leonard of Quirm (Architect) — Technical Context Creation

Lord Vetinari activates as primary, Leonard of Quirm as tandem backseat. Lord Vetinari reads epic context, story description, and acceptance criteria from sprint YAML. Drafts context document from template — fills in business context, user impact, dependencies, and scope boundaries. Leonard of Quirm observes via tandem protocol, injects observations: *"This touches the WebSocket broadcast path — Dev needs to know about the event loop constraint"*, *"Missing: the subprocess timeout from 125-3 is a dependency."*

Lord Vetinari incorporates Leonard of Quirm's technical guardrails. Leonard of Quirm does final quality check — confirms required sections present, technical accuracy sufficient. Context file written to `sprint/context/context-story-127-3.md`.

**Reveals:** Template sections, tandem observation injection points, quality check criteria.

### Journey 3: Lord Vetinari (PM) + Adora Belle Dearheart (UX-Designer) — UX Context Creation

Same flow as Journey 2 but for a `bdd`-labeled story. Lord Vetinari activates with Adora Belle Dearheart as tandem. Lord Vetinari drafts business context. Adora Belle Dearheart injects: *"The current panel layout won't accommodate this — user needs to see X and Y simultaneously"*, *"Accessibility: this needs keyboard navigation."*

Adora Belle Dearheart's observations focus on interaction patterns, visual constraints, and accessibility requirements rather than technical architecture.

**Reveals:** Tandem pairing selection logic (workflow label → tandem partner), UX-specific template sections.

### Journey 4: Igor (TEA) — Consuming Context for Test Strategy

Igor activates for RED phase. Reads `context-story-127-3.md`. Finds: business context, acceptance criteria (already in session), **plus** technical guardrails from Leonard of Quirm, dependency notes, scope boundaries. Igor writes test strategy informed by the full picture — not just the AC bullet points but the *why* behind them and the technical constraints Ponder Stibbons will face.

**Reveals:** Context document must be structured so TEA can extract testable constraints quickly.

### Journey 5: Captain Carrot (SM) — Epic Context Missing (First Story in Epic)

Captain Carrot activates for story 128-1 — first story in a new epic. Gate checks epic context — missing. Captain Carrot triggers epic context creation workflow. Lord Vetinari reads epic description, planning docs, and PRD references. Produces `context-epic-128.md` with epic-level overview, architecture decisions, cross-story dependencies, and domain context. Then proceeds to story context creation.

**Reveals:** Epic context creation is a separate (simpler) flow that gates story context creation. Two-level cascade: epic context → story context → gate pass.

### Journey 6: The Operator — Manual Context Creation

The operator is working on a spike or exploratory story. Doesn't want the full tandem ceremony. Runs `/pf-context create story 128-2` directly. Gets the template, fills it in manually, saves. Gate passes on next Captain Carrot activation.

**Reveals:** Manual escape hatch — skill/command for operator-driven creation.

### Journey Requirements Summary

| Journey | Capabilities Revealed |
|---------|----------------------|
| Captain Carrot Happy Path | Gate checks story+epic context, auto-triggers creation, re-runs after |
| Lord Vetinari + Leonard of Quirm | Template with required sections, tandem observation injection, Architect quality review |
| Lord Vetinari + Adora Belle Dearheart | Tandem pairing selection by workflow/label, UX-specific template sections |
| Igor Consumption | Context structured for quick extraction of testable constraints |
| Epic Context Cascade | Two-level creation flow, epic gates story |
| Manual Escape Hatch | Direct skill/command for operator-driven creation |

## Developer Tool Specific Requirements

### Delivery Architecture

- **Skill-based delivery:** `/pf-context create epic|story` skill, not a new BikeLane workflow
- **Gate enforcement:** Gate stays pure pass/fail; calling agent (SM, TEA) acts on failure
- **Tandem orchestration:** Reuses existing tandem protocol config

### Tandem Selection Logic

- Default: Story `workflow` field determines pairing — `tdd`/`trivial` → PM+Architect, `bdd`/`bdd-tandem` → PM+UX-Designer
- Override: `--tandem architect|ux` flag on skill invocation

### Template Structure

Single template with optional sections controlled by `sections:` frontmatter field. Skill reads workflow type and includes/excludes sections automatically.

**Epic context (`context-epic-{N}.md`):**
- Overview, Planning Documents, Background, Technical Architecture, Cross-Story Dependencies

**Story context (`context-story-{N-N}.md`):**
- Core (always): Business Context, Technical Guardrails, Scope Boundaries, AC Context, References
- UX (when `bdd`/`bdd-tandem`): Interaction Patterns, Accessibility Requirements, Visual Constraints
- Frontmatter: `parent:` field linking to epic context

### Schema Validation

- JSON Schema or script-based validation for context files
- Validates required sections have non-empty content (not just file existence)
- Validates frontmatter fields (`parent:` links to existing epic context)
- Validates naming convention (`context-epic-{N}.md`, `context-story-{N-N}.md`)
- Gates call the validator — gate logic stays simple, validator handles the details

### Gate Strategy

- `sm-setup-exit` gate: Validates epic context then story context (sequential cascade). Fail → SM invokes `/pf-context create`. One attempt per level, then fail with clear message for manual creation.
- TEA gate: Validates story context exists and passes schema validation before RED phase
- Gates are pure pass/fail — validator script does the heavy lifting

### TEA Integration

- TEA agent definition updated to read story/epic context during RED phase
- Gate-enforced: TEA cannot proceed without validated context

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Problem-solving MVP — enforce the context loop end to end. Gates check, agents create, agents consume.

### MVP Feature Set (Phase 1)

**Core Journeys Supported:** All 6

**Sequenced Deliverables:**

| # | Feature | Depends On |
|---|---------|------------|
| 1 | Fix `checkStoryContext` + `checkEpicContext` bugs | — |
| 2 | Context validation schema/script | — |
| 3 | Context document templates (single, optional sections) | — |
| 4 | `/pf-context create epic` skill | #3 |
| 5 | `/pf-context create story` skill with tandem selection | #3, #4 |
| 6 | Update `sm-setup-exit` gate (sequential cascade) | #1, #2 |
| 7 | Add TEA gate (context validated before RED) | #2 |
| 8 | Update TEA agent definition to read context | #7 |

### Post-MVP Features

**Phase 2 (Growth):**
- `--tandem architect|ux` manual override flag
- Context quality metrics in Cyclist sprint panel
- Architect as explicit quality reviewer role

**Phase 3 (Vision):**
- Context lineage graph (PRD → epic → story → session)
- Brownfield auto-population from hotspot analysis
- Context staleness detection via hash comparison

### Risk Mitigation Strategy

**Technical Risk:** Tandem orchestration within skill invocation — SM spawning tandem mid-setup. Fallback: PM-only creation, Architect reviews after.
**Resource Risk:** Items 1-3 are independent and can be parallelized. Items 4-5 are the critical path.

## Functional Requirements

### Context Validation

- **FR1:** Gates can validate that a context file exists, follows naming conventions, and has non-empty required sections
- **FR2:** Gates can validate that story context references a valid parent epic context
- **FR3:** The `sm-setup-exit` gate can validate epic context before story context (sequential cascade)
- **FR4:** A TEA gate can validate story context before RED phase proceeds
- **FR5:** Gates can report specific validation failures (missing file, empty section, broken parent link) to the calling agent

### Context Creation

- **FR6:** The SM agent can invoke context creation when a gate fails
- **FR7:** The `/pf-context create epic` skill can generate an epic context document from sprint YAML data and planning references
- **FR8:** The `/pf-context create story` skill can generate a story context document using a tandem session
- **FR9:** The skill can select the tandem pairing (PM+Architect or PM+UX-Designer) based on the story's workflow field
- **FR10:** The operator can invoke `/pf-context create` manually without a tandem session
- **FR11:** The skill can populate a single template with optional sections based on workflow type

### Context Templates

- **FR12:** A single context template can include or exclude sections based on a `sections:` frontmatter field
- **FR13:** Epic context documents can contain Overview, Planning Documents, Background, Technical Architecture, and Cross-Story Dependencies sections
- **FR14:** Story context documents can contain Business Context, Technical Guardrails, Scope Boundaries, AC Context, and References sections
- **FR15:** UX story context documents can additionally contain Interaction Patterns, Accessibility Requirements, and Visual Constraints sections
- **FR16:** Story context frontmatter can declare a `parent:` field linking to the epic context

### Schema & Validation Infrastructure

- **FR17:** A validation script can check context files against a defined schema
- **FR18:** The validator can distinguish between structural errors (missing sections) and content errors (empty sections)
- **FR19:** The validator can be called by any gate without duplicating validation logic

### Agent Integration

- **FR20:** The TEA agent can read story and epic context as primary input during RED phase
- **FR21:** The SM agent can attempt one context creation per level (epic, story) before failing with a manual-creation message
- **FR22:** The PM agent can produce context as primary author in a tandem session
- **FR23:** The Architect agent can inject technical guardrails via tandem observation during context creation
- **FR24:** The UX-Designer agent can inject interaction patterns via tandem observation during context creation

### Bug Fixes

- **FR25:** `checkStoryContext` can correctly identify story context files using the `context-story-{N-N}.md` naming convention
- **FR26:** `checkEpicContext` can correctly identify epic context files for PROJ-keyed epics

## Non-Functional Requirements

### Performance

- **NFR1:** Context validation script completes in under 2 seconds for any context file
- **NFR2:** `/pf-context create` skill (without tandem) completes template population in under 30 seconds
- **NFR3:** Full tandem context creation session completes in under 10 minutes for a typical 2-3 point story
- **NFR4:** Gate checks (sm-setup-exit, TEA gate) add no more than 3 seconds to agent activation

### Integration

- **NFR5:** Context validation script is callable from any gate definition without modification to the gate framework
- **NFR6:** `/pf-context create` skill works within the existing skill invocation infrastructure (no new runtime plumbing)
- **NFR7:** Tandem sessions use the existing tandem protocol configuration — no custom tandem infrastructure
- **NFR8:** Context files are readable by any agent using standard Read tool — no special parsing required
- **NFR9:** Schema validation is compatible with both Python (pf CLI) and TypeScript (Cyclist) consumers
