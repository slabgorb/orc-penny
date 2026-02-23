---
stepsCompleted:
  - step-01-validate
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
  - step-05-import-to-future
inputDocuments:
  - sprint/planning/context-gate-prd.md
  - sprint/planning/architecture.md
  - docs/adr/0029-context-gate-architecture.md
---

# Formalized Epic & Story Context Creation - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for the Formalized Epic & Story Context Creation system, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

**Context Validation**
- FR1: Gates can validate that a context file exists, follows naming conventions, and has non-empty required sections
- FR2: Gates can validate that story context references a valid parent epic context
- FR3: The `sm-setup-exit` gate can validate epic context before story context (sequential cascade)
- FR4: A TEA gate can validate story context before RED phase proceeds
- FR5: Gates can report specific validation failures (missing file, empty section, broken parent link) to the calling agent

**Context Creation**
- FR6: The SM agent can invoke context creation when a gate fails
- FR7: The `/pf-context create epic` skill can generate an epic context document from sprint YAML data and planning references
- FR8: The `/pf-context create story` skill can generate a story context document using a tandem session
- FR9: The skill can select the tandem pairing (PM+Architect or PM+UX-Designer) based on the story's workflow field
- FR10: The operator can invoke `/pf-context create` manually without a tandem session
- FR11: The skill can populate a single template with optional sections based on workflow type

**Context Templates**
- FR12: A single context template can include or exclude sections based on a `sections:` frontmatter field
- FR13: Epic context documents can contain Overview, Planning Documents, Background, Technical Architecture, and Cross-Story Dependencies sections
- FR14: Story context documents can contain Business Context, Technical Guardrails, Scope Boundaries, AC Context, and References sections
- FR15: UX story context documents can additionally contain Interaction Patterns, Accessibility Requirements, and Visual Constraints sections
- FR16: Story context frontmatter can declare a `parent:` field linking to the epic context

**Schema & Validation Infrastructure**
- FR17: A validation script can check context files against a defined schema
- FR18: The validator can distinguish between structural errors (missing sections) and content errors (empty sections)
- FR19: The validator can be called by any gate without duplicating validation logic

**Agent Integration**
- FR20: The TEA agent can read story and epic context as primary input during RED phase
- FR21: The SM agent can attempt one context creation per level (epic, story) before failing with a manual-creation message
- FR22: The PM agent can produce context as primary author in a tandem session
- FR23: The Architect agent can inject technical guardrails via tandem observation during context creation
- FR24: The UX-Designer agent can inject interaction patterns via tandem observation during context creation

**Bug Fixes**
- FR25: `checkStoryContext` can correctly identify story context files using the `context-story-{N-N}.md` naming convention
- FR26: `checkEpicContext` can correctly identify epic context files for any Jira project key (dynamic — not hardcoded to MSSCI)
- FR27: Context file naming and resolution supports both numeric IDs (e.g., `97`, `125-3`) and Jira-keyed IDs (e.g., `PROJ-123`, `MSSCI-15395`) where the project key is dynamic

### NonFunctional Requirements

**Performance**
- NFR1: Context validation script completes in under 2 seconds for any context file
- NFR2: `/pf-context create` skill (without tandem) completes template population in under 30 seconds
- NFR3: Full tandem context creation session completes in under 10 minutes for a typical 2-3 point story
- NFR4: Gate checks (sm-setup-exit, TEA gate) add no more than 3 seconds to agent activation

**Integration**
- NFR5: Context validation script is callable from any gate definition without modification to the gate framework
- NFR6: `/pf-context create` skill works within the existing skill invocation infrastructure (no new runtime plumbing)
- NFR7: Tandem sessions use the existing tandem protocol configuration — no custom tandem infrastructure
- NFR8: Context files are readable by any agent using standard Read tool — no special parsing required
- NFR9: Schema validation is compatible with both Python (pf CLI) and TypeScript (Cyclist) consumers

### Additional Requirements

**From Architecture (ADR-0029):**
- Module lives at `pf/context_docs/validate.py` (not `pf/context/`) due to collision with existing `pf/context.py`
- CLI registered as `pf context-docs validate` with sugar alias
- Schema YAML at `pennyfarthing-dist/templates/context-schema.yaml` — single source of truth for both template generation and validation
- Python validator returns `ValidationResult` dataclass (never throws) — follows `sprint/validator.py` pattern
- CLI exit codes: 0 = valid, 1 = invalid, 2 = file not found; YAML output on stdout
- Gates call CLI via bash subprocess, not Python imports
- Tandem partner selection: `tdd`/`trivial` → Architect, `bdd`/`bdd-tandem` → UX-Designer
- SM attempts ONE creation per level then fails (no retry loops)
- Context files in `sprint/context/` only — naming: `context-epic-{id}.md`, `context-story-{id}.md`
- Bug fixes are additive — fix patterns, don't refactor surrounding code
- No backward compatibility required — existing ~50 ad-hoc epic context files can be migrated or recreated
- Jira project key is dynamic (read from config or sprint YAML) — never hardcode a specific project key
- Separate impl in `generic-sm-setup.ts:429-447` works for numeric IDs but untested for Jira-keyed IDs

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | 1 | Gate validates existence, naming, non-empty sections |
| FR2 | 1 | Gate validates story context parent link |
| FR3 | 3 | sm-setup-exit gate: epic before story cascade |
| FR4 | 3 | TEA gate: story context before RED phase |
| FR5 | 1 | Gates report specific validation failures |
| FR6 | 3 | SM invokes creation on gate failure |
| FR7 | 2 | `/pf-context create epic` skill |
| FR8 | 2 | `/pf-context create story` with tandem |
| FR9 | 2 | Tandem pairing selection by workflow field |
| FR10 | 2 | Manual creation without tandem |
| FR11 | 2 | Template population by workflow type |
| FR12 | 1 | Single template with optional sections |
| FR13 | 1 | Epic context section definitions |
| FR14 | 1 | Story context section definitions |
| FR15 | 1 | UX story context additional sections |
| FR16 | 1 | Story context `parent:` frontmatter |
| FR17 | 1 | Validation script checks against schema |
| FR18 | 1 | Structural vs content error distinction |
| FR19 | 1 | Validator callable by any gate |
| FR20 | 3 | TEA reads context during RED phase |
| FR21 | 3 | SM attempts one creation per level then fails |
| FR22 | 2 | PM produces context as primary author |
| FR23 | 2 | Architect injects technical guardrails via tandem |
| FR24 | 2 | UX-Designer injects interaction patterns via tandem |
| FR25 | 1 | Fix `checkStoryContext` filename pattern |
| FR26 | 1 | Fix `checkEpicContext` for dynamic Jira project keys |
| FR27 | 1 | Context naming supports both numeric and Jira-keyed IDs |

## Epic List

### Epic 1: Context Validation & Visibility
After this epic: developers see accurate context status in Cyclist and can validate any context file via CLI. Fix the broken context checks so Cyclist tells the truth. Establish the schema as single source of truth. Build the validator that gates and skills will depend on.
**FRs covered:** FR1, FR2, FR5, FR12-FR19, FR25-FR27

### Epic 2: Automated Context Creation
After this epic: developers produce context documents via `/pf-context create` — manually or with tandem collaboration. Build the creation skills. PM authors context from schema-derived templates. Architect or UX-Designer injects domain-specific observations via tandem. Manual escape hatch for spikes.
**FRs covered:** FR7-FR11, FR22-FR24

### Epic 3: Gate-Enforced Context Pipeline
After this epic: no story starts without validated context. SM triggers creation on failure. TEA consumes context as primary input. Wire the validator into sm-setup-exit as a sequential cascade. Add TEA context gate. SM auto-invokes creation skill on gate failure. TEA reads context during RED phase. The loop is closed.
**FRs covered:** FR3, FR4, FR6, FR20, FR21

## Epic 1: Context Validation & Visibility

Developers see accurate context status in Cyclist and can validate any context file via CLI.

### Story 1.1: Fix Context Check Bugs in sprint-data.ts

As a developer using Cyclist,
I want the sprint panel to accurately show which stories and epics have context documents,
So that I can see at a glance what's ready for development.

**Acceptance Criteria:**

**Given** `checkStoryContext` in `sprint-data.ts` checks for story context files
**When** a story context file exists at `sprint/context/context-story-125-3.md`
**Then** `checkStoryContext("125-3")` returns true
**And** the previous pattern `{storyId}-context.md` is no longer used

**Given** `checkEpicContext` in `sprint-data.ts` checks for epic context files
**When** an epic context file exists at `sprint/context/context-epic-PROJ-123.md`
**Then** `checkEpicContext("PROJ-123")` returns true
**And** the regex handles any Jira project key pattern (not hardcoded to `MSSCI` or numeric-only)

**Given** an epic uses a numeric ID like `97`
**When** `checkEpicContext("97")` is called
**Then** it returns true if `sprint/context/context-epic-97.md` exists

**Given** the Cyclist sprint panel renders story rows
**When** context files exist for a story and its parent epic
**Then** the `hasContext` field reflects the actual filesystem state

### Story 1.2: Create Context Schema YAML

As a framework developer,
I want a single YAML schema that defines required and optional sections for context documents,
So that templates and validators share one source of truth with zero drift.

**Acceptance Criteria:**

**Given** the schema file is created at `pennyfarthing-dist/templates/context-schema.yaml`
**When** the schema defines epic context structure
**Then** it lists required sections: Overview, Background, Technical Architecture
**And** it lists optional sections: Planning Documents, Cross-Story Dependencies
**And** it specifies no required frontmatter for epic context

**Given** the schema defines story context structure
**When** the story section is read
**Then** it lists required sections: Business Context, Technical Guardrails, Scope Boundaries, AC Context
**And** it lists optional sections: Interaction Patterns, Accessibility Requirements, Visual Constraints
**And** it specifies `parent` as required frontmatter
**And** it specifies `workflow` as optional frontmatter

**Given** each section entry in the schema
**When** the entry is read
**Then** it contains a `name` field (display heading) and a `description` field (purpose guidance for content authors)

### Story 1.3: Build Context Validator Python Module and CLI

As a developer or gate evaluator,
I want a CLI command that validates context files against the schema,
So that gates and operators can check context quality without manual inspection.

**Acceptance Criteria:**

**Given** the validator module exists at `pf/context_docs/validate.py`
**When** `pf context-docs validate epic 97` is run
**Then** it locates `sprint/context/context-epic-97.md`
**And** checks that all required sections from the schema have non-empty content
**And** returns YAML output on stdout with `valid`, `type`, `id`, `file`, and `errors` fields

**Given** `pf context-docs validate story 125-3` is run
**When** the story context file exists
**Then** it validates required sections are present and non-empty
**And** validates that `parent:` frontmatter references an existing epic context file
**And** returns YAML output with validation results

**Given** a context file is missing a required section
**When** the validator runs
**Then** the error includes `severity: error` and identifies the missing section by name
**And** the exit code is 1 (invalid)

**Given** a context file has a required section header but no content beneath it
**When** the validator runs
**Then** the error distinguishes this as a content error (empty section) vs structural error (missing section)
**And** the exit code is 1 (invalid)

**Given** the context file does not exist
**When** the validator runs
**Then** the exit code is 2 (file not found)
**And** the YAML output includes the expected file path

**Given** the validator is called with a Jira-keyed ID like `PROJ-123`
**When** it resolves the context file path
**Then** it looks for `sprint/context/context-epic-PROJ-123.md` or `context-story-PROJ-123.md` as appropriate

**Given** the validator needs the schema
**When** it loads `context-schema.yaml`
**Then** it resolves the path via the `find-root.sh` pattern (walk up to `.pennyfarthing/`)
**And** the validator returns `ValidationResult` objects — never throws exceptions

**Given** the validator is invoked from any gate definition
**When** the gate evaluator runs `pf context-docs validate`
**Then** it works without modification to the gate framework (NFR5)
**And** completes in under 2 seconds (NFR1)

### Story 1.4: Generate Context Document Templates from Schema

As a context author (PM agent or operator),
I want markdown templates that match the schema exactly,
So that I have a skeleton to fill in when creating context documents.

**Acceptance Criteria:**

**Given** the context schema YAML exists
**When** the epic template is generated at `pennyfarthing-dist/templates/context-epic.md`
**Then** it contains `## {section_name}` headings for all required sections
**And** it contains `## {section_name}` headings for all optional sections (marked as optional)
**And** each section includes the description from the schema as a guidance comment

**Given** the story template is generated at `pennyfarthing-dist/templates/context-story.md`
**When** the template is read
**Then** it includes YAML frontmatter with `parent:` and `workflow:` fields
**And** it contains all required story sections as `##` headings
**And** it contains optional UX sections with a note that they apply to bdd/bdd-tandem workflows only

**Given** a new required section is added to `context-schema.yaml`
**When** the templates are regenerated
**Then** the new section appears in the template automatically
**And** no manual template editing is required

## Epic 2: Automated Context Creation

Developers produce context documents via `/pf-context create` — manually or with tandem collaboration.

### Story 2.1: `/pf-context create epic` Skill

As a developer or SM agent,
I want to run `/pf-context create epic {id}` to generate an epic context document,
So that epic-level context exists before any story work begins.

**Acceptance Criteria:**

**Given** the `/pf-context` skill is defined at `pennyfarthing-dist/skills/pf-context/skill.md`
**When** `/pf-context create epic 128` is invoked
**Then** the skill reads the epic template from `pennyfarthing-dist/templates/context-epic.md`
**And** reads epic metadata from sprint YAML (title, description, planning doc references)
**And** spawns a PM subagent to fill the template sections
**And** writes the result to `sprint/context/context-epic-128.md`

**Given** the epic ID uses a Jira project key like `PROJ-456`
**When** `/pf-context create epic PROJ-456` is invoked
**Then** the skill resolves the correct epic data from sprint YAML
**And** writes to `sprint/context/context-epic-PROJ-456.md`

**Given** the skill completes context creation
**When** the output file is written
**Then** the skill runs `pf context-docs validate epic {id}` on the output
**And** if validation fails, the PM subagent fixes the issues and re-validates

**Given** an operator invokes the skill manually
**When** they run `/pf-context create epic {id}`
**Then** the skill works without requiring an active session or workflow state

### Story 2.2: `/pf-context create story` Skill (PM-Only Mode)

As a developer or SM agent,
I want to run `/pf-context create story {id}` to generate a story context document,
So that story-level context exists with business context, guardrails, and scope boundaries.

**Acceptance Criteria:**

**Given** `/pf-context create story 128-2` is invoked
**When** the skill starts
**Then** it verifies that epic context exists for the parent epic (e.g., `context-epic-128.md`)
**And** fails with a clear message if epic context is missing

**Given** epic context exists
**When** the skill creates story context
**Then** it reads the story template from `pennyfarthing-dist/templates/context-story.md`
**And** reads story metadata from sprint YAML (title, ACs, workflow field, labels)
**And** reads the parent epic context for broader context
**And** spawns a PM subagent to fill the template sections
**And** sets `parent: context-epic-128.md` in frontmatter
**And** sets `workflow:` in frontmatter from the story's workflow field

**Given** the story's workflow field is `bdd` or `bdd-tandem`
**When** the skill populates the template
**Then** it includes the optional UX sections (Interaction Patterns, Accessibility Requirements, Visual Constraints)

**Given** the story's workflow field is `tdd` or `trivial`
**When** the skill populates the template
**Then** it omits the optional UX sections

**Given** the `--no-tandem` flag is passed
**When** the skill runs
**Then** it creates context with PM-only — no backseat observer is spawned

**Given** the skill completes
**When** the output file is written to `sprint/context/context-story-128-2.md`
**Then** the skill runs `pf context-docs validate story 128-2` on the output
**And** if validation fails, the PM subagent fixes the issues and re-validates

### Story 2.3: Tandem Partner Selection and Integration

As a developer,
I want story context creation to automatically pair the PM with the right specialist,
So that context documents include domain-specific technical or UX guardrails.

**Acceptance Criteria:**

**Given** `/pf-context create story 128-2` is invoked without `--no-tandem`
**When** the story's workflow field is `tdd` or `trivial`
**Then** the skill selects Architect as the tandem partner
**And** spawns a backseat observer via the existing `tandem-backseat.md` protocol in the background

**Given** the story's workflow field is `bdd` or `bdd-tandem`
**When** the skill selects a tandem partner
**Then** it selects UX-Designer as the backseat observer

**Given** the Architect backseat is active during context creation
**When** the PM subagent is filling template sections
**Then** the Architect observes the work and injects technical guardrails via the observation file
**And** the PostToolUse hook delivers observations to the PM's context as `[Tandem]` injections
**And** the PM incorporates relevant observations into Technical Guardrails and Scope Boundaries sections

**Given** the UX-Designer backseat is active during context creation
**When** the PM subagent is filling template sections
**Then** the UX-Designer injects interaction patterns and accessibility observations
**And** the PM incorporates them into the UX optional sections

**Given** the tandem backseat fails to spawn or crashes mid-creation
**When** the skill detects the failure
**Then** it logs a warning and continues with PM-only creation
**And** the context document is still valid (just without partner input)

**Given** the skill completes
**When** context creation is finished
**Then** the skill terminates the backseat background task before returning

## Epic 3: Gate-Enforced Context Pipeline

No story starts without validated context. SM triggers creation on failure. TEA consumes context as primary input.

### Story 3.1: Update sm-setup-exit Gate with Context Validation Cascade

As a developer starting story work,
I want the SM setup gate to validate both epic and story context before proceeding,
So that no story enters the workflow without validated context documents.

**Acceptance Criteria:**

**Given** the `sm-setup-exit` gate is evaluated during SM setup
**When** the gate reaches the context validation check
**Then** it runs `pf context-docs validate epic {epic_id}` first
**And** if epic validation fails, the gate fails with the validator's error message
**And** epic validation must pass before story validation is attempted

**Given** epic context validation passes
**When** the gate proceeds to story validation
**Then** it runs `pf context-docs validate story {story_id}`
**And** if story validation fails, the gate fails with the validator's error message

**Given** both epic and story context validation pass
**When** the gate evaluates
**Then** the context check passes and the gate proceeds to remaining checks

**Given** the gate calls `pf context-docs validate`
**When** parsing the result
**Then** it maps exit code 0 to `check.status: pass`
**And** maps exit code 1 to `check.status: fail` with detail from the first error message
**And** maps exit code 2 to `check.status: fail` with detail "Context file not found"

**Given** both validation calls are made
**When** the gate completes
**Then** total context validation overhead is under 4 seconds (two calls, each under 2s per NFR1)

### Story 3.2: SM Auto-Triggers Context Creation on Gate Failure

As a developer,
I want the SM agent to automatically create missing context when the gate fails,
So that I don't have to manually intervene for every missing context file.

**Acceptance Criteria:**

**Given** the sm-setup-exit gate fails on epic context validation
**When** the SM agent processes the gate failure
**Then** SM invokes `/pf-context create epic {epic_id}`
**And** after creation completes, SM re-runs the gate from the beginning

**Given** the sm-setup-exit gate fails on story context validation (epic passed)
**When** the SM agent processes the gate failure
**Then** SM invokes `/pf-context create story {story_id}`
**And** after creation completes, SM re-runs the gate from the beginning

**Given** both epic and story context are missing
**When** the SM agent processes the cascade
**Then** SM creates epic context first, then story context, then re-runs the gate

**Given** SM has already attempted one context creation for a level (epic or story)
**When** the gate fails again for the same level after creation
**Then** SM does not retry creation
**And** SM reports a clear failure message: "Context creation failed for {type} {id}. Create manually with `/pf-context create {type} {id}`"

**Given** context creation succeeds and the gate re-run passes
**When** SM proceeds with setup
**Then** the workflow continues to the next phase (TEA handoff) without additional intervention

### Story 3.3: TEA Context Gate and Agent Integration

As a test engineer agent,
I want validated context documents loaded as primary input during RED phase,
So that test strategy is informed by the full business and technical picture.

**Acceptance Criteria:**

**Given** the TEA agent activates for RED phase
**When** the TEA agent reads story context
**Then** it loads `sprint/context/context-story-{story_id}.md`
**And** it loads `sprint/context/context-epic-{epic_id}.md` (resolved from story context `parent:` frontmatter)
**And** uses both documents as primary input for test strategy

**Given** the TEA agent needs to validate context before starting RED phase
**When** TEA's activation or gate checks context
**Then** it runs `pf context-docs validate story {story_id}`
**And** if validation fails, TEA reports the failure and does not proceed to test writing

**Given** story context contains Technical Guardrails
**When** TEA reads the section
**Then** TEA incorporates the guardrails into test strategy (e.g., testing constraints, dependency boundaries, performance limits)

**Given** story context contains UX optional sections (bdd workflow)
**When** TEA reads Interaction Patterns and Accessibility Requirements
**Then** TEA incorporates them into acceptance test strategy (e.g., keyboard navigation tests, responsive layout checks)

**Given** the TEA agent definition at `pennyfarthing-dist/agents/tea.md`
**When** this story is complete
**Then** the agent definition includes instructions to read epic and story context during RED phase
**And** context loading is documented as a required step before test strategy formulation
