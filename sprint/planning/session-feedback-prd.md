---
classification:
  projectType: developer_tool
  domain: developer_productivity_agent_orchestration
  complexity: medium
  projectContext: brownfield
inputDocuments:
  - docs/lifecycle-tier-work-products.md
  - sprint/archive/MSSCI-15033-session.md
  - sprint/planning/prd-sprint-data-management.md
  - pennyfarthing/pennyfarthing-dist/guides/session-artifacts.md
workflowType: 'prd'
---

# PRD: Story Session Feedback System

**Version:** 1.0
**Date:** 2026-02-23
**Author:** Lady Jessica (PM Agent)
**Status:** Draft

---

## Executive Summary

The boss reviews session files to understand what happened during story delivery. Session files capture workflow mechanics faithfully — phases, handoffs, assessments — but lack structured feedback about upstream effects discovered during implementation: spec gaps, architecture issues, process friction. The tier model (`docs/lifecycle-tier-work-products.md`) defines "Delivery Findings" as the missing upward-flowing artifact, but it's unimplemented.

This PRD defines a two-phase Story Session Feedback System. **Phase 1** adds an Impact Summary section to session files — a quick-scan block the boss can read in 30 seconds to understand what a story revealed about the broader system. **Phase 2** adds structured Delivery Findings — systematic capture of gaps, conflicts, questions, and improvements that feed the Impact Summary and route actionable items to the appropriate tier.

**Key Deliverable:** New sections in session files that capture what implementation revealed about upstream specs, architecture, and process — the upward-flowing feedback loop the tier model prescribes but the tooling doesn't yet support.

---

## Problem Statement

### Current Pain Points

1. **No upward-flowing artifacts** — The session file records what happened (phases, assessments, test results) but not what was *learned*. When a Dev discovers a spec gap or an Architect assumption that doesn't hold, that knowledge lives in the assessment prose or disappears entirely.
2. **Boss must read entire sessions** — To understand a story's broader impact, the boss reads the full session file and mentally extracts findings. There is no summary block optimized for quick scanning.
3. **Findings are unstructured** — When agents do note issues (e.g., "AC-3 is ambiguous" in a TEA assessment), the observation is buried in free-text prose with no type, urgency, or routing information.
4. **No aggregation path** — Even when findings are captured, there's no mechanism to collect them across stories into sprint-level or epic-level views.
5. **Tier model gap** — `lifecycle-tier-work-products.md` (lines 228-248) defines the Delivery Finding artifact with types (Gap, Conflict, Question, Improvement) and urgency (Blocking, Non-blocking), but no tooling implements it.

### Root Cause

The session file was designed as a workflow tracking artifact, not a feedback artifact. It answers "what did the agents do?" but not "what did the story teach us?" The tier model identified this gap but the session schema was never updated to include the upward-flowing artifacts it prescribes.

### Evidence: Session File Gap

From `sprint/archive/MSSCI-15033-session.md` — a completed story with TEA, Dev, and Reviewer assessments:

- TEA found 5 audit issues (choice casing, param naming, missing sugar, missing help text) — these are structured findings about CLI inconsistency, but they're captured only as assessment prose
- Dev implemented fixes and noted backward-compat aliases — an architectural decision made during delivery with no formal record
- Reviewer verified 10 items and flagged 2 observations (medium + low) — the low-priority observation about validator count drift is exactly a "Gap" finding, but it has no routing

None of these observations flow upward. The boss would need to read all three assessments to extract the three findings that matter for future planning.

---

## Solution Overview

### Architecture

```
Session File (existing)
├── Phase Log (existing)
├── Agent Assessments (existing)
├── Impact Summary (Phase 1) ◄── NEW: boss-readable quick scan
└── Delivery Findings (Phase 2) ◄── NEW: structured findings feeding the summary

                    ┌──────────────────────┐
                    │   Session File       │
                    │                      │
                    │  ┌────────────────┐  │
                    │  │ Impact Summary │◄─┼── Generated from Delivery Findings
                    │  └────────────────┘  │
                    │                      │
                    │  ┌────────────────┐  │
                    │  │ Delivery       │  │
                    │  │ Findings       │◄─┼── Captured by agents during phases
                    │  └───────┬────────┘  │
                    └──────────┼───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Sprint Aggregation   │  (Phase 2 growth)
                    │ (cross-story view)   │
                    └──────────────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Extend session files, don't create new artifacts | Findings belong with the story context that produced them; avoids artifact sprawl |
| Impact Summary first (Phase 1) | Solves the boss's immediate need — quick scanning — before building the systematic capture |
| Structured findings second (Phase 2) | Once the summary section exists and proves useful, add the structured data that makes it reliable |
| Agent-written, SM-compiled | Each agent captures findings during their phase; SM compiles the Impact Summary at finish |

---

## Success Criteria

### User Success

| Criterion | Measure | Threshold |
|-----------|---------|-----------|
| Boss reads Impact Summary | Understands story's upstream effects without reading full session | 30 seconds |
| Agent captures finding | Structured entry with type, urgency, affected spec | Every finding |
| SM compiles summary | Impact Summary reflects all delivery findings | 100% coverage |
| No findings lost | Everything agents note about upstream issues is captured | Zero orphaned observations |

### Technical Success

| Criterion | Measure | Threshold |
|-----------|---------|-----------|
| Session schema updated | New sections validate against schema | 100% |
| Backward compatible | Existing sessions without new sections still parse | 100% |
| SM finish includes summary | `sm-finish` generates Impact Summary from findings | Every story |
| Archive preserves findings | Archived sessions retain Impact Summary and findings | 100% |

### Documentation Success

| Criterion | Measure | Threshold |
|-----------|---------|-----------|
| Session artifacts guide updated | `session-artifacts.md` reflects new sections | On completion |
| Tier model referenced | PRD traces requirements to tier model definitions | Explicit references |
| Agent guides updated | Agent definitions include finding capture responsibility | On completion |

---

## User Journeys

### J1: Boss Reviews Completed Story

**Actor:** Keith (the boss)
**Goal:** Understand what story 127-3 revealed about the broader system

**Current flow:**
1. Open `sprint/archive/MSSCI-15426-session.md`
2. Read TEA assessment (finds 2 paragraphs about test challenges)
3. Read Dev assessment (finds note about architecture assumption)
4. Read Reviewer assessment (finds medium-priority observation)
5. Mentally synthesize: "So the OCSF schema needs a new field, and the test fixtures are wrong"

**New flow (Phase 1):**
1. Open `sprint/archive/MSSCI-15426-session.md`
2. Read Impact Summary section at the top:
   ```
   ## Impact Summary

   **Upstream Effects:** 2 findings (1 Gap, 1 Conflict)
   **Urgency:** No blocking items

   - **Gap:** Session cleanup script doesn't handle nested agent directories.
     Workaround applied. Needs ratification in session-artifacts.md.
   - **Conflict:** TEA fixture assumptions don't match actual CLI output format
     after normalization. Test utilities need update across 3 other stories.
   ```
3. Done. Two findings, their types, and what to do about them — in 30 seconds.

### J2: TEA Agent Discovers Spec Ambiguity

**Actor:** Igor (TEA agent)
**Goal:** Note that AC-3 is ambiguous while writing tests

**Current flow:**
1. TEA writes in assessment: "AC-3 says 'support 90% compatibility' but doesn't define which 10% is excluded"
2. This prose is never extracted or routed

**New flow (Phase 2):**
1. TEA writes assessment as usual
2. TEA also adds a Delivery Finding entry:
   ```yaml
   - type: Question
     urgency: Non-blocking
     source: {story: "127-3", phase: "red", agent: "TEA"}
     affected_spec: "Story 127-3 AC-3"
     description: "AC-3 says 'support 90% compatibility' but doesn't define exclusion criteria"
     proposed_action: "Clarify AC with specific exclusion list or compatibility test suite"
   ```
3. SM sees this finding during finish phase, includes it in Impact Summary

### J3: Dev Discovers Architecture Conflict

**Actor:** Ponder Stibbons (Dev agent)
**Goal:** Record that the architecture document's recommendation doesn't work

**Current flow:**
1. Dev writes in assessment: "Architecture says use RwLock but benchmarks show dashmap is 3x faster"
2. Dev uses dashmap anyway. The deviation is in the code but not in any feedback artifact.

**New flow (Phase 2):**
1. Dev writes assessment as usual
2. Dev adds a Delivery Finding:
   ```yaml
   - type: Conflict
     urgency: Non-blocking
     source: {story: "127-3", phase: "green", agent: "Dev"}
     affected_spec: "Architecture Decision ADR-0015"
     description: "ADR-0015 recommends RwLock for cache. Benchmarks show dashmap 3x faster for read-heavy pattern."
     proposed_action: "Amend ADR-0015 with benchmark data. Document when each is appropriate."
   ```

### J4: Reviewer Flags Process Gap

**Actor:** Lord Vetinari (Reviewer agent)
**Goal:** Note that the review checklist is missing a category

**Current flow:**
1. Reviewer writes observation: "[LOW] validate section lists 4 subcommands but code has 5"
2. Observation lives in assessment text with a severity tag but no routing

**New flow (Phase 2):**
1. Reviewer writes assessment as usual
2. Reviewer adds a Delivery Finding:
   ```yaml
   - type: Gap
     urgency: Non-blocking
     source: {story: "127-3", phase: "review", agent: "Reviewer"}
     affected_spec: "pennyfarthing_scripts/CLAUDE.md validate section"
     description: "Validator count in docs (4) doesn't match code (5). skill-command validator undocumented."
     proposed_action: "Update CLAUDE.md validate section to include skill-command validator"
   ```

### J5: SM Compiles Impact Summary at Finish

**Actor:** Captain Carrot (SM agent)
**Goal:** Generate Impact Summary from accumulated findings

**Flow:**
1. SM enters finish phase
2. SM reads all Delivery Findings from session file
3. SM generates Impact Summary:
   - Count by type (N Gaps, N Conflicts, N Questions, N Improvements)
   - Flag any Blocking items prominently
   - One-line summary per finding
4. SM writes Impact Summary section to session file
5. Session is archived with both sections intact

### J6: Sprint Retro Uses Aggregated Findings (Phase 2 Growth)

**Actor:** SM during retrospective
**Goal:** Aggregate findings across all stories in the sprint

**Flow:**
1. SM reads archived sessions for the sprint
2. Collects all Delivery Findings
3. Groups by type and affected spec
4. Identifies patterns: "3 stories found gaps in the session-artifacts schema"
5. Produces sprint-level findings report for planning

---

## Functional Requirements

### Phase 1: Impact Summary

- **FR1:** Session files MUST include an `## Impact Summary` section after the Phase Log
- **FR2:** The Impact Summary MUST contain a count of findings by type (Gap, Conflict, Question, Improvement)
- **FR3:** The Impact Summary MUST flag Blocking items with a bold `**BLOCKING:**` prefix on a dedicated line before the finding list
- **FR4:** The Impact Summary MUST contain a one-line description per finding
- **FR5:** The `sm-finish` subagent MUST generate the Impact Summary by scanning agent assessments for upstream observations
- **FR6:** The Impact Summary MUST be generated even when no findings exist (showing "No upstream effects noted")
- **FR7:** Archived session files MUST preserve the Impact Summary section

### Phase 2: Structured Delivery Findings

- **FR8:** Session files MUST include a `## Delivery Findings` section after agent assessments
- **FR9:** Each Delivery Finding MUST include: type, urgency, source (story, phase, agent), affected spec, description, and proposed action
- **FR10:** Finding types MUST be one of: Gap, Conflict, Question, Improvement (per tier model definition)
- **FR11:** Finding urgency MUST be one of: Blocking, Non-blocking (per tier model definition)
- **FR12:** The TEA agent MUST capture findings during the RED phase
- **FR13:** The Dev agent MUST capture findings during the GREEN phase
- **FR14:** The Reviewer agent MUST capture findings during the REVIEW phase
- **FR15:** The `sm-finish` subagent MUST generate the Impact Summary from structured Delivery Findings (replacing the assessment-scanning approach from Phase 1)
- **FR16:** Delivery Findings MUST be parseable by scripts for aggregation

### Phase 2 Growth: Aggregation

- **FR17:** A script MUST be able to collect Delivery Findings across archived sessions for a given sprint
- **FR18:** Aggregated findings MUST be groupable by type, affected spec, and urgency
- **FR19:** The retrospective workflow SHOULD consume aggregated findings as input

---

## Non-Functional Requirements

### NFR1: Performance

| Operation | Target |
|-----------|--------|
| SM Impact Summary generation | < 30 seconds |
| Finding entry by agent | < 5 seconds (structured template fill) |
| Sprint aggregation script | < 10 seconds for 20 stories |

### NFR2: Backward Compatibility

- Existing session files without Impact Summary or Delivery Findings sections MUST continue to parse correctly
- `sm-finish` MUST handle sessions with no findings gracefully
- Archive scripts MUST not break on sessions with new sections
- **Verification:** Confirmed by running `sm-finish` against 10 archived sessions that lack the new sections; all must complete without error

### NFR3: Schema Consistency

- New sections MUST follow the existing session file structure (markdown with YAML frontmatter where structured data is needed)
- Delivery Finding entries MUST use YAML format within markdown code blocks for parseability
- Field names MUST match the tier model terminology exactly (type, urgency, source, affected_spec, description, proposed_action)
- **Verification:** A schema validation script parses the Delivery Findings YAML blocks and confirms all 6 required fields are present with valid enum values (type in {Gap, Conflict, Question, Improvement}, urgency in {Blocking, Non-blocking})

### NFR4: Agent Adoption

- Agent definitions MUST be updated to include finding capture as an explicit responsibility
- Finding capture MUST NOT add more than 2 minutes to any agent's phase time
- Template snippets MUST be provided in agent guides to minimize cognitive overhead

---

## Technical Design

### Session File Schema Extension

**Phase 1 — Impact Summary section:**

```markdown
## Impact Summary

**Upstream Effects:** {count} findings ({N} Gap, {N} Conflict, {N} Question, {N} Improvement)
**Urgency:** {No blocking items | N BLOCKING items — see below}

- **{Type}:** {One-line description}. {Proposed action or "Needs decision."}
- **{Type}:** {One-line description}. {Proposed action or "Needs decision."}
```

**Phase 2 — Delivery Findings section:**

```markdown
## Delivery Findings

### Finding 1: {Short title}

```yaml
type: Gap | Conflict | Question | Improvement
urgency: Blocking | Non-blocking
source:
  story: "{story-id}"
  phase: "{red|green|review|finish}"
  agent: "{TEA|Dev|Reviewer|SM}"
affected_spec: "{document or section reference}"
description: "{What was found}"
proposed_action: "{What should change, or 'Decision needed'}"
```

### Finding 2: {Short title}

...
```

### Updated Session File Structure

```
{STORY_ID}-session.md
├── Frontmatter (story metadata)
├── Description
├── Acceptance Criteria
├── Technical Context
├── Phase Log
├── ## Impact Summary          ◄── NEW (Phase 1)
├── ## TEA Assessment
├── ## Dev Assessment
├── ## Reviewer Assessment
├── ## Delivery Findings        ◄── NEW (Phase 2)
└── (archived with all sections)
```

### Agent Responsibility Matrix

| Agent | Phase | Finding Capture Responsibility |
|-------|-------|-------------------------------|
| TEA | RED | Spec ambiguities, missing ACs, untestable requirements |
| Dev | GREEN | Architecture conflicts, missing interfaces, dependency gaps |
| Reviewer | REVIEW | Process gaps, documentation drift, cross-story impacts |
| SM | FINISH | Compiles Impact Summary; may add process-level findings |

### SM Finish Enhancement

The `sm-finish` subagent gains a new step between "archive session" and "update sprint YAML":

**Phase 1 (assessment scanning):**
1. Read TEA, Dev, and Reviewer assessments
2. Identify observations about upstream specs, architecture, or process
3. Classify each as Gap/Conflict/Question/Improvement
4. Assign urgency (Blocking if work was stopped; Non-blocking otherwise)
5. Write Impact Summary section

**Phase 2 (structured findings):**
1. Read Delivery Findings section (already populated by agents)
2. Generate Impact Summary from structured data
3. Validate finding completeness (each agent's phase represented)

---

## Scope

### Phase 1: Impact Summary (This Epic)

1. Define Impact Summary section format
2. Update `sm-finish` subagent to scan assessments and generate Impact Summary
3. Update session file template to include Impact Summary placeholder
4. Update `session-artifacts.md` guide to document new section
5. Validate against 3 recent archived sessions (retroactive generation)

### Phase 2: Structured Delivery Findings (Next Epic)

1. Define Delivery Finding YAML schema
2. Update TEA agent definition to capture findings during RED
3. Update Dev agent definition to capture findings during GREEN
4. Update Reviewer agent definition to capture findings during REVIEW
5. Update `sm-finish` to generate Impact Summary from structured findings
6. Update session file template to include Delivery Findings section
7. Add finding template snippets to agent guides

### Phase 2 Growth: Aggregation (Future)

- Sprint-level findings aggregation script
- Retro workflow integration
- Cyclist panel showing finding trends
- Finding → SCR (Spec Correction Request) promotion workflow

### Out of Scope

- Spec Correction Requests (SCR) — these are a Domain/Product tier artifact; this PRD covers the Delivery tier only
- Automated routing of findings to spec owners — manual review by boss is the intended workflow
- Real-time finding capture during agent execution — findings are written at phase completion, not mid-phase
- Cross-repo findings — limited to the orchestrator session files

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Agents produce low-quality findings | Medium | Medium | Provide template snippets and examples in agent guides; SM validates during finish |
| Impact Summary adds noise to session files | Low | Medium | "No upstream effects noted" for clean stories; keep summaries to 5 lines max |
| Backward compatibility break | Low | High | New sections are additive; parsing treats them as optional |
| Finding capture slows agent phases | Low | Low | Structured template fill is < 2 minutes; non-blocking to workflow |
| Boss doesn't read Impact Summaries | Low | High | Place section prominently; validate utility with first 5 stories |

---

## Dependencies

### Required

- `sm-finish` subagent (exists — needs enhancement)
- Session file template (exists — needs new sections)
- `session-artifacts.md` guide (exists — needs update)

### Existing

- Agent assessment sections (TEA, Dev, Reviewer already write structured assessments)
- Session archive workflow (already preserves full session files)
- Sprint YAML management (`pf sprint` CLI)

### Tier Model Reference

This PRD implements the **Delivery Finding** artifact defined in `docs/lifecycle-tier-work-products.md` (lines 228-248):

> **Delivery Finding** — Structured note about spec gaps, ambiguities, or errors. Created during any delivery phase. May become an SCR.

Finding schema directly maps the tier model's definition:

| Tier Model Field | PRD Field | Values |
|-----------------|-----------|--------|
| Type | `type` | Gap, Conflict, Question, Improvement |
| Source | `source` | Story ID, phase, agent |
| Affected Spec | `affected_spec` | Document or section reference |
| Description | `description` | What was found |
| Proposed Action | `proposed_action` | What should change |
| Urgency | `urgency` | Blocking, Non-blocking |

---

## Migration Plan

### Phase 1: Impact Summary (Week 1-2)

1. **Define format** — Impact Summary section specification (this PRD)
2. **Update sm-finish** — Add assessment-scanning logic and summary generation
3. **Update session template** — Add Impact Summary placeholder after Phase Log
4. **Update session-artifacts.md** — Document new section in the guide
5. **Retroactive validation** — Generate Impact Summaries for 3 recent archived sessions to validate format
6. **Ship** — All new stories get Impact Summary via sm-finish

### Phase 2: Structured Delivery Findings (Week 3-4)

1. **Define schema** — Delivery Finding YAML specification
2. **Update agent definitions** — TEA, Dev, Reviewer gain finding capture responsibility
3. **Add template snippets** — Finding templates in agent guides
4. **Update sm-finish** — Switch from assessment-scanning to structured-findings compilation
5. **Update session template** — Add Delivery Findings section
6. **Ship** — All agents capture structured findings; Impact Summary generated from them

---

## Appendix: Example Session with New Sections

Below is an annotated example showing how a completed session file would look with both Phase 1 and Phase 2 additions:

```markdown
# Story 127-3: Add WebSocket broadcast for panel updates

**Jira:** MSSCI-15500
**Epic:** 127 — Real-Time Panel Communication
...

## Phase Log

| Phase | Agent | Status |
|-------|-------|--------|
| setup | SM | done |
| red | TEA | done |
| green | Dev | done |
| review | Reviewer | done |
| finish | SM | done |

## Impact Summary

**Upstream Effects:** 3 findings (1 Gap, 1 Conflict, 1 Improvement)
**Urgency:** No blocking items

- **Gap:** Session artifacts guide doesn't document WebSocket message format.
  Needs new section in session-artifacts.md.
- **Conflict:** Architecture ADR-0022 specifies polling for panel updates, but
  WebSocket broadcast is 10x more efficient. ADR needs amendment.
- **Improvement:** Event batching pattern discovered during implementation reduces
  broadcast frequency by 80%. Should be documented as a design pattern.

## TEA Assessment

**Tests Written:** 12 tests covering 4 ACs
...

## Dev Assessment

**Implementation Complete:** Yes
...

## Reviewer Assessment

**Verdict:** APPROVED
...

## Delivery Findings

### Finding 1: WebSocket message format undocumented

```yaml
type: Gap
urgency: Non-blocking
source:
  story: "127-3"
  phase: "green"
  agent: "Dev"
affected_spec: "pennyfarthing-dist/guides/session-artifacts.md"
description: "No documentation for WebSocket message format used in panel broadcasts"
proposed_action: "Add WebSocket message schema section to session-artifacts.md"
```

### Finding 2: ADR-0022 polling recommendation conflicts with implementation

```yaml
type: Conflict
urgency: Non-blocking
source:
  story: "127-3"
  phase: "review"
  agent: "Reviewer"
affected_spec: "docs/adr/ADR-0022-panel-communication.md"
description: "ADR-0022 specifies polling. Implementation uses WebSocket broadcast (10x efficiency). ADR is now stale."
proposed_action: "Amend ADR-0022 with benchmark data justifying WebSocket approach"
```

### Finding 3: Event batching reduces broadcast frequency

```yaml
type: Improvement
urgency: Non-blocking
source:
  story: "127-3"
  phase: "green"
  agent: "Dev"
affected_spec: "Architecture patterns (no existing doc)"
description: "Batching panel update events in 100ms windows reduces broadcast frequency by 80%"
proposed_action: "Document as architectural pattern for future real-time features"
```
```
