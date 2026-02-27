---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
  - step-05-import-to-future
inputDocuments:
  - sprint/planning/session-feedback-prd.md
  - sprint/planning/session-feedback-prd-validation.md
  - docs/adr/0031-session-feedback-system.md
---

# Session Feedback System - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for the Session Feedback System, decomposing the requirements from the PRD, Architecture ADR-0031, and validation report into implementable stories. Where the ADR diverges from the PRD, the ADR is authoritative.

## Requirements Inventory

### Functional Requirements

**Phase 1: Impact Summary**

FR1: Session files MUST include an `## Impact Summary` section after Delivery Findings
FR2: Impact Summary MUST contain a count of findings by type (Gap, Conflict, Question, Improvement)
FR3: Impact Summary MUST flag Blocking items with bold `**BLOCKING:**` prefix on a dedicated line before the finding list
FR4: Impact Summary MUST contain a one-line description per finding
FR5: `sm-finish` subagent MUST generate the Impact Summary from Delivery Findings (not retroactive assessment scanning)
FR6: Impact Summary MUST be generated even when no findings exist ("No upstream effects noted")
FR7: Archived session files MUST preserve the Impact Summary section

**Phase 2: Structured Delivery Findings**

FR8: Session files MUST include a `## Delivery Findings` section before agent assessments
FR9: Each finding MUST be a markdown list item with: type (bold), urgency (parenthetical), one-sentence description, affected spec (relative path), and what needs to change
FR10: Finding types MUST be one of: Gap, Conflict, Question, Improvement
FR11: Finding urgency MUST be one of: blocking, non-blocking
FR12: TEA agent MUST capture findings during RED phase (or write explicit "No findings" entry)
FR13: Dev agent MUST capture findings during GREEN phase (or write explicit "No findings" entry)
FR14: Reviewer agent MUST capture findings during REVIEW phase (or write explicit "No findings" entry)
FR15: `sm-finish` MUST compile Impact Summary from structured Delivery Findings entries
FR16: Delivery Findings MUST be pure markdown list items (no YAML blocks) for human readability and script parseability

**Late PR Creation (from ADR)**

FR20: SM MUST create PR after review approval (not before), with full body generated from session file
FR21: PR body MUST use zero framework jargon — translation map: TEA→"Test design", Dev→"Implementation", Reviewer→"Code review", SM→"Story completion", AC→"Requirements"
FR22: PR body MUST include: Summary, What Was Done, What This Work Revealed (Impact Summary), Docs That May Need Updating, Details (assessments cleaned of jargon), Full Findings
FR23: `reviewer-preflight` MUST handle missing PR_NUMBER gracefully (PR doesn't exist during review phase)

**Phase 2 Growth: Aggregation**

FR17: A script MUST be able to collect Delivery Findings across archived sessions for a given sprint
FR18: Aggregated findings MUST be groupable by type, affected spec, and urgency
FR19: Retrospective workflow SHOULD consume aggregated findings as input

### NonFunctional Requirements

NFR1: Performance — SM Impact Summary generation < 30 seconds; finding entry by agent < 5 seconds (template fill); sprint aggregation < 10 seconds for 20 stories
NFR2: Backward Compatibility — existing sessions without new sections MUST continue to parse. Verified by running sm-finish against archived sessions that lack new sections; all must complete without error
NFR3: Schema Consistency — new sections follow existing session file markdown structure; finding format is fixed per ADR R1; field names match tier model terminology
NFR4: Agent Adoption — agent definitions updated with finding capture responsibility; capture adds < 2 minutes to phase time; template snippets provided in agent guides

### Additional Requirements

**From ADR-0031 (authoritative):**

- Pure markdown findings — no YAML code blocks, no schema validation complexity
- Agent self-report model — agents write findings when they have full context, not SM guessing later
- "No findings" is explicit (R3) — distinguishes "checked and found nothing" from "forgot to check"
- Agents ONLY append to Delivery Findings — never edit or remove another agent's entries (R2)
- Doc references use relative paths from project root (R4)
- Impact Summary is compiled from findings, not editorial — SM reads verbatim (R6)
- Session file section order: Description → ACs → Technical Context → Delivery Findings → Impact Summary → Assessments → Phase Log

**From ADR-0031 — Files Affected:**

- `agents/sm-finish.md` — PR creation moves after summary compilation; --body includes full session content
- `agents/reviewer-preflight.md` — PR_NUMBER becomes optional; step 5 conditional
- `agents/reviewer.md` — Remove PR_NUMBER from required params; add finding-capture template
- `agents/sm-setup.md` — Add `## Delivery Findings` placeholder to session template
- `agents/tea.md` — Add finding-capture to assessment template
- `agents/dev.md` — Add finding-capture to assessment template
- `agents/sm.md` — Add Impact Summary compilation + PR body generation to finish flow
- `guides/session-artifacts.md` — Document new sections

**From Validation Report:**

- FR3 measurability resolved by ADR's explicit bold prefix format
- NFR2-NFR3 need explicit verification methods (added above)
- PRD frontmatter metadata gap is non-blocking

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | Epic 2 | Impact Summary section in session files |
| FR2 | Epic 2 | Count findings by type |
| FR3 | Epic 2 | Bold BLOCKING prefix |
| FR4 | Epic 2 | One-line description per finding |
| FR5 | Epic 2 | SM generates Impact Summary from findings |
| FR6 | Epic 2 | Generate even when no findings |
| FR7 | Epic 2 | Archive preserves Impact Summary |
| FR8 | Epic 1 | Delivery Findings section in session files |
| FR9 | Epic 1 | Finding format: type, urgency, description, spec, action |
| FR10 | Epic 1 | Types: Gap, Conflict, Question, Improvement |
| FR11 | Epic 1 | Urgency: blocking, non-blocking |
| FR12 | Epic 1 | TEA captures findings in RED |
| FR13 | Epic 1 | Dev captures findings in GREEN |
| FR14 | Epic 1 | Reviewer captures findings in REVIEW |
| FR15 | Epic 2 | SM compiles summary from structured findings |
| FR16 | Epic 1 | Pure markdown format, script-parseable |
| FR17 | Epic 3 | Collect findings across archived sessions |
| FR18 | Epic 3 | Group by type, spec, urgency |
| FR19 | Epic 3 | Retro workflow consumes aggregated findings |
| FR20 | Epic 2 | PR created after review with full body |
| FR21 | Epic 2 | Zero framework jargon in PR |
| FR22 | Epic 2 | PR body structure (Summary, What Done, Revealed, etc.) |
| FR23 | Epic 1 | Reviewer-preflight handles missing PR_NUMBER |

**Coverage: 23/23 FRs mapped. Zero orphans.**

## Epic List

### Epic 1: Agent Finding Capture & Workflow Unblocking
Agents can systematically record upstream findings discovered during their phase. The reviewer workflow is unblocked to operate without a PR. A validation script confirms finding format correctness before downstream compilation.

**FRs covered:** FR8, FR9, FR10, FR11, FR12, FR13, FR14, FR16, FR23
**NFRs addressed:** NFR2 (backward compat), NFR4 (agent adoption)
**Files:** `sm-setup.md`, `tea.md`, `dev.md`, `reviewer.md`, `reviewer-preflight.md`, `guides/session-artifacts.md`

**Gate:** Finding format validation — a gate script confirms all findings in the session match R1 format (type, urgency, description, affected spec, proposed action) before Epic 2 compilation can proceed.

**Standalone value:** Session files capture what agents learned. Reviewer works without PR_NUMBER. Even without summary compilation, the boss can read Delivery Findings directly.

### Epic 2: Impact Summary & Boss-Readable PR
Boss can understand a story's upstream effects in 30 seconds via Impact Summary, delivered through a self-contained, jargon-free PR description generated from the session file.

**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR15, FR20, FR21, FR22
**NFRs addressed:** NFR1 (performance), NFR3 (schema consistency)
**Files:** `sm-finish.md`, `sm.md`, `guides/session-artifacts.md`

**Standalone value:** The boss reads the PR and gets the full picture — what was done, what was revealed, what docs may need updating. Impact Summary compiles from findings; PR body translates to boss-readable language. One user outcome: "boss understands the story."

### Epic 3: Sprint Findings Aggregation
Sprint retro can surface cross-story patterns from aggregated findings — identifying systemic issues across the sprint.

**FRs covered:** FR17, FR18, FR19
**Files:** New aggregation script, retro workflow integration

**Standalone value:** Growth epic. Uses archived sessions from Epics 1+2. Sprint-level visibility into recurring gaps, conflicts, and improvement opportunities.

---

## Epic 1: Agent Finding Capture & Workflow Unblocking

Agents can systematically record upstream findings discovered during their phase. The reviewer workflow is unblocked to operate without a PR. A validation script confirms finding format correctness before downstream compilation.

### Story 1.1: Add Delivery Findings section to session template

As a SM agent setting up a new story,
I want the session template to include a `## Delivery Findings` section placeholder,
So that agents have a designated location to append their findings during subsequent phases.

**Acceptance Criteria:**

**Given** SM runs story setup via `sm-setup`
**When** the session file is created from the template
**Then** the session file contains a `## Delivery Findings` section positioned before agent assessment sections
**And** the section contains the text "No findings yet."

**Given** an existing archived session file without a `## Delivery Findings` section
**When** `sm-finish` processes it
**Then** it completes without error (backward compatibility)

**FRs:** FR8
**NFRs:** NFR2
**Files:** `agents/sm-setup.md`
**Points:** 1

### Story 1.2: Add finding-capture to agent exit behaviors

As a TEA/Dev/Reviewer agent completing my phase,
I want a finding-capture template in my exit behavior,
So that I can record upstream findings (or explicitly note "no findings") before handoff.

**Acceptance Criteria:**

**Given** TEA completes the RED phase and discovered a spec ambiguity
**When** TEA writes their assessment
**Then** TEA also appends a finding to `## Delivery Findings` in the format: `- **{Type}** ({urgency}): {description}. Affects \`{path}\` ({what needs to change}). *Found by {Agent} during {human-phase-name}.*`
**And** the type is one of: Gap, Conflict, Question, Improvement
**And** the urgency is one of: blocking, non-blocking
**And** the human-phase-name is "test design" (not "red" or "RED")

**Given** Dev completes the GREEN phase with no upstream findings
**When** Dev writes their assessment
**Then** Dev appends `- No upstream findings during implementation.` to the Delivery Findings section

**Given** Reviewer completes the REVIEW phase
**When** Reviewer writes their assessment
**Then** Reviewer appends findings (or explicit "no findings") to the Delivery Findings section
**And** Reviewer uses human-phase-name "code review" (not "review" or "REVIEW")

**Given** any agent appends to `## Delivery Findings`
**When** another agent's entries already exist in the section
**Then** the new agent's entries are appended below existing entries without modifying or removing them (R2)

**Given** Reviewer is invoked during the review phase
**When** no PR exists yet (late PR creation workflow)
**Then** `reviewer-preflight` completes without error when PR_NUMBER is absent
**And** preflight step 5 (PR-specific checks) is skipped gracefully

**Given** Reviewer's agent definition
**When** checking required parameters
**Then** PR_NUMBER is not listed as a required parameter

**FRs:** FR9, FR10, FR11, FR12, FR13, FR14, FR16, FR23
**NFRs:** NFR4
**Files:** `agents/tea.md`, `agents/dev.md`, `agents/reviewer.md`, `agents/reviewer-preflight.md`
**Points:** 3

### Story 1.3: Create finding format validation gate

As a gate system verifying story readiness,
I want a validation script that confirms all Delivery Findings match the R1 format,
So that malformed findings are caught before Impact Summary compilation in Epic 2.

**Acceptance Criteria:**

**Given** a session file with correctly formatted Delivery Findings entries
**When** the validation gate script runs against it
**Then** the script exits with status 0 (pass)
**And** reports the count of findings parsed

**Given** a session file with a finding missing the type (e.g., no bold `**Gap**`)
**When** the validation gate script runs
**Then** the script exits with status 1 (fail)
**And** reports which finding failed and what is missing

**Given** a session file with a finding using an invalid type (e.g., "Bug" instead of Gap/Conflict/Question/Improvement)
**When** the validation gate script runs
**Then** the script exits with status 1 (fail)
**And** reports the invalid type value

**Given** a session file with a finding using an invalid urgency (e.g., "critical" instead of blocking/non-blocking)
**When** the validation gate script runs
**Then** the script exits with status 1 (fail)

**Given** a session file where all agent phases have explicit "No upstream findings" entries
**When** the validation gate script runs
**Then** the script exits with status 0 (pass — explicit no-findings is valid)

**Given** a session file with no `## Delivery Findings` section (legacy session)
**When** the validation gate script runs
**Then** the script exits with status 0 (pass — backward compatible, section is optional)

**FRs:** FR16
**NFRs:** NFR2, NFR3
**Files:** New gate script (e.g., `scripts/validate-findings.sh` or `pf/gates/findings.py`)
**Points:** 2

### Story 1.4: Update session-artifacts guide for Delivery Findings

As an agent reading the session-artifacts guide,
I want documentation of the `## Delivery Findings` section format and my capture responsibilities,
So that I know exactly what to write and where.

**Acceptance Criteria:**

**Given** an agent reads `guides/session-artifacts.md`
**When** looking for Delivery Findings documentation
**Then** the guide contains a section describing the `## Delivery Findings` format
**And** includes the finding template: `- **{Type}** ({urgency}): {description}. Affects \`{path}\` ({what needs to change}). *Found by {Agent} during {human-phase-name}.*`
**And** lists valid types: Gap, Conflict, Question, Improvement
**And** lists valid urgencies: blocking, non-blocking
**And** documents the "No upstream findings" explicit entry format
**And** documents the human-phase-name mapping: RED→"test design", GREEN→"implementation", REVIEW→"code review"

**Given** the updated session-artifacts guide
**When** comparing the documented section order to ADR-0031
**Then** the guide reflects: Description → ACs → Technical Context → Delivery Findings → Impact Summary → Assessments → Phase Log

**Given** an agent reading the guide
**When** looking for append-only rules
**Then** the guide documents R2 (agents only append, never edit others' entries) and R3 ("no findings" is explicit)

**FRs:** FR9, FR10, FR11 (documentation of format)
**NFRs:** NFR4 (template snippets provided)
**Files:** `guides/session-artifacts.md`
**Points:** 1

---

## Epic 2: Impact Summary & Boss-Readable PR

Boss can understand a story's upstream effects in 30 seconds via Impact Summary, delivered through a self-contained, jargon-free PR description generated from the session file.

### Story 2.1: Add Impact Summary compilation to SM finish flow

As the boss reviewing a completed story,
I want an Impact Summary section in the session file compiled from Delivery Findings,
So that I can understand the story's upstream effects in 30 seconds without reading full assessments.

**Acceptance Criteria:**

**Given** a session file with 3 Delivery Findings (1 Gap, 1 Conflict, 1 Improvement, all non-blocking)
**When** SM runs the finish phase
**Then** `sm-finish` writes an `## Impact Summary` section to the session file
**And** the summary contains `**Upstream Effects:** 3 findings (1 Gap, 1 Conflict, 0 Question, 1 Improvement)`
**And** the summary contains `**Blocking:** None`
**And** the summary contains one line per finding with `- **{Type}:** {description}. Affects \`{path}\`.`
**And** the summary includes a `**Docs that may need updating:**` list with deduplicated paths

**Given** a session file with a blocking finding
**When** SM runs the finish phase
**Then** the Impact Summary contains `**BLOCKING:**` on a dedicated line before the finding list
**And** the blocking finding is listed first

**Given** a session file where all agents wrote "No upstream findings"
**When** SM runs the finish phase
**Then** the Impact Summary contains `**Upstream Effects:** No upstream effects noted`
**And** the Blocking line reads `**Blocking:** None`

**Given** SM compiles the Impact Summary
**When** writing the section
**Then** the summary is placed after `## Delivery Findings` and before agent assessment sections
**And** the summary is compiled from findings verbatim (R6 — not editorial)

**Given** a completed session file with Impact Summary
**When** the session is archived
**Then** the archived file preserves the Impact Summary section intact

**FRs:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR15
**NFRs:** NFR1 (< 30s), NFR3
**Files:** `agents/sm-finish.md`, `agents/sm.md`
**Points:** 3

### Story 2.2: Generate boss-readable PR body from session file

As the boss reading a PR description,
I want a self-contained, jargon-free summary of what was done and what was revealed,
So that I can understand the story without using Pennyfarthing or reading raw session files.

**Acceptance Criteria:**

**Given** SM has compiled the Impact Summary
**When** SM generates the PR body
**Then** the PR body follows this structure: Summary, What Was Done, What This Work Revealed, Docs That May Need Updating, Details (Test Design, Implementation, Code Review, Full Findings)

**Given** a session file with TEA, Dev, and Reviewer assessments
**When** SM generates the PR body
**Then** framework jargon is translated: TEA→"Test design", Dev→"Implementation", Reviewer→"Code review", SM→"Story completion", Acceptance Criteria→"Requirements"
**And** no references to "RED phase", "GREEN phase", "REVIEW phase", "sm-finish", or other framework terms appear

**Given** the PR body includes the "What This Work Revealed" section
**When** the boss reads it
**Then** it contains the Impact Summary content (findings count, blocking status, per-finding descriptions)

**Given** the PR body includes "Docs That May Need Updating"
**When** findings reference affected specs
**Then** the doc paths are deduplicated and listed with reasons

**Given** SM generates the PR body
**When** creating the PR with `gh pr create`
**Then** the full body is passed via `--body` flag
**And** the PR is created after reviewer approval (not before)

**Given** `reviewer-preflight` runs after PR creation
**When** a PR now exists
**Then** preflight step 5 (PR-specific checks) executes normally

**FRs:** FR20, FR21, FR22
**NFRs:** NFR1
**Files:** `agents/sm-finish.md`, `agents/sm.md`
**Points:** 3

### Story 2.3: Update session-artifacts guide for Impact Summary and PR body

As an SM agent reading the session-artifacts guide,
I want documentation of the Impact Summary format and PR body generation process,
So that I know exactly how to compile findings and generate the boss-readable PR.

**Acceptance Criteria:**

**Given** an SM agent reads `guides/session-artifacts.md`
**When** looking for Impact Summary documentation
**Then** the guide documents the full Impact Summary format including: upstream effects count, blocking status, per-finding lines, docs-that-may-need-updating list

**Given** the session-artifacts guide
**When** documenting the PR body structure
**Then** the guide includes the complete PR body template (Summary, What Was Done, What This Work Revealed, Docs, Details)
**And** includes the jargon translation map

**Given** the updated guide
**When** comparing section order to ADR-0031
**Then** the complete session file structure is documented: Description → ACs → Technical Context → Delivery Findings → Impact Summary → Assessments → Phase Log

**FRs:** FR1, FR5 (documentation of format and process)
**NFRs:** NFR3
**Files:** `guides/session-artifacts.md`
**Points:** 1

---

## Epic 3: Sprint Findings Aggregation

Sprint retro can surface cross-story patterns from aggregated findings — identifying systemic issues across the sprint.

### Story 3.1: Create sprint findings aggregation script

As an SM running a sprint retrospective,
I want a script that collects Delivery Findings across all archived sessions for a sprint,
So that I can identify recurring patterns and systemic issues.

**Acceptance Criteria:**

**Given** a sprint with 5 archived sessions, 3 of which contain Delivery Findings
**When** running the aggregation script with the sprint identifier
**Then** the script collects all findings from all archived sessions for that sprint
**And** outputs findings grouped by type (all Gaps together, all Conflicts together, etc.)
**And** outputs findings grouped by affected spec (all findings referencing the same doc together)
**And** completes in < 10 seconds

**Given** archived sessions that predate the Delivery Findings feature (no section)
**When** the aggregation script encounters them
**Then** they are skipped without error

**Given** the aggregation output
**When** reviewing grouped findings
**Then** each finding retains its source attribution (story ID, agent, phase)

**FRs:** FR17, FR18
**NFRs:** NFR1 (< 10s for 20 stories), NFR2
**Files:** New script (e.g., `pf/sprint/aggregate_findings.py`)
**Points:** 2

### Story 3.2: Integrate aggregated findings into retrospective workflow

As an SM facilitating a sprint retro,
I want the retro workflow to consume aggregated findings as input,
So that the retro discussion is grounded in what stories actually revealed.

**Acceptance Criteria:**

**Given** the retro workflow is started for a sprint
**When** the workflow loads input data
**Then** it runs the aggregation script and includes findings summary as context

**Given** aggregated findings show 3 stories found Gaps in `session-artifacts.md`
**When** the retro presents patterns
**Then** the pattern is surfaced: "3 stories found gaps in session-artifacts.md"

**Given** a sprint with no Delivery Findings in any archived session
**When** the retro workflow loads findings
**Then** it reports "No delivery findings recorded this sprint" and continues without error

**FRs:** FR19
**Files:** Retro workflow definition, aggregation script integration
**Points:** 2
