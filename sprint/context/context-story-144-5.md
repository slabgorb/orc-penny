---
parent: context-epic-144.md
workflow: trivial
---

# Story 144-5: Add Assumptions Section to Story Context Schema

## Business Context

The spec fidelity pipeline depends on Architect being able to validate cross-story assumptions before TEA writes tests. Without a required `## Assumptions` section in the story context schema, authors have no structural anchor to declare what they expect from sibling stories — and Architect has nothing to check against.

This story closes that gap by making `## Assumptions` a required field in `context-schema.yaml`. Once in place, every context document the PM authors must explicitly declare sibling story dependencies or state "No cross-story assumptions." This gives the Architect spec-check phase (story 144-6) a machine-readable input and gives the Reviewer and Architect spec-reconcile phase (story 144-7) the forward-impact map they need to catch broken assumptions early.

The direct payoff: broken assumptions — where a sibling story deviated from what this story expected — get caught before TEA writes tests against the wrong spec, not after Dev has already built the wrong thing.

## Technical Guardrails

**File to modify:** `pennyfarthing/pennyfarthing-dist/templates/context-schema.yaml`

- The PRD and epic reference `pennyfarthing-dist/schemas/context-schema.md` but the actual authoritative schema file is `pennyfarthing/pennyfarthing-dist/templates/context-schema.yaml`. Target the actual file.
- The schema is YAML, not Markdown. Add `Assumptions` to the `story.required_sections` list alongside the existing four required sections.
- The template at `pennyfarthing/pennyfarthing-dist/templates/context-story-template.md` should also receive a new `## Assumptions` section so that PM-authored documents are scaffolded correctly from the start.
- ADR-0029 Rule #2 applies: this schema file is the ONLY authority for required sections. Validators and templates must read it — do not hardcode section names elsewhere.
- Do not modify the `epic` block in context-schema.yaml — this change is story-scoped only.
- Do not create a new schema file; modify the existing one in place.
- Do not modify any gate scripts or validators in this story — that validation wiring is out of scope (see Scope Boundaries).

## Scope Boundaries

**In scope:**
- Add `Assumptions` to `story.required_sections` in `pennyfarthing/pennyfarthing-dist/templates/context-schema.yaml`
- Add a `## Assumptions` section with instructional placeholder text to `pennyfarthing/pennyfarthing-dist/templates/context-story-template.md`

**Out of scope:**
- Wiring the Assumptions section into gate validation logic — that is story 144-6 (spec-check gate reads the section)
- Creating or modifying any gate definition files (`deviations-logged.md`, `spec-check-pass.md`, etc.)
- Updating existing context documents in `sprint/context/` to add the Assumptions section — not required for this story
- Any changes to the `epic` required sections in context-schema.yaml
- Any changes to workflow YAML files

## AC Context

**AC 1 — Schema requires `## Assumptions` section:**

> Given the context schema at `pennyfarthing-dist/schemas/context-schema.md` [actual file: `pennyfarthing-dist/templates/context-schema.yaml`]
> When a PM creates a new story context document
> Then the schema requires a `## Assumptions` section

The `story.required_sections` list in `context-schema.yaml` must include `Assumptions` as a fifth entry. The section name must match exactly — the context gate validator matches section headers by name.

**AC 2 — Assumption format references sibling story, claim, and spec basis:**

> Given the `## Assumptions` section
> When populated by the PM
> Then each assumption references: sibling story ID, what's assumed, which spec/AC it's based on
> And format example: "Assumes story 5-1 delivers `Regex { pattern: String, flags: String }` per AC-3"

The template placeholder text must convey this three-part format: (1) sibling story ID, (2) what's assumed about its output, (3) which spec or AC backs it. The example in the AC itself is the canonical format to reproduce in the template guidance.

**AC 3 — "No cross-story assumptions" is a valid explicit declaration:**

> Given a story with no cross-story assumptions
> When the PM fills the section
> Then "No cross-story assumptions" is valid (explicit declaration, not empty)

The template must document this escape hatch clearly. The PM must always provide content — an empty section is not valid (see AC 4).

**AC 4 — Empty section fails context gate validation:**

> Given a story context document with an empty `## Assumptions` section (no content, not even "No cross-story assumptions")
> When the context gate validates the document
> Then it fails with: "Assumptions section must be non-empty — list assumptions or state 'No cross-story assumptions'"

This AC validates the gate behavior (144-6's concern), but the schema and template must make the requirement clear enough that authors never leave the section empty inadvertently. The template placeholder should make it impossible to miss.

## Assumptions

No cross-story assumptions within epic 144.

This story is Phase A (independent) — it has no dependencies on other in-progress stories. It assumes `pennyfarthing/pennyfarthing-dist/templates/context-schema.yaml` is the authoritative schema file (the PRD path `pennyfarthing-dist/schemas/context-schema.md` is a documentation artifact, not the actual file location).

Stories 144-6 (Architect spec-check phase) and 144-7 (Architect spec-reconcile phase) both depend on this story having delivered the `## Assumptions` section in the schema. The spec-check gate (144-6) reads `## Assumptions` from story context documents and fails if the section is absent — that gate behavior is only correct once the schema makes the section required.
