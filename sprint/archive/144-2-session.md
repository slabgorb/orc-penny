# Story 144-2: Update TEA and Dev agent definitions for deviation logging

**Story ID:** 144-2
**Jira:** (none)
**Epic:** 144 — Specification Fidelity Gates
**Points:** 2
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/story-144-2-update-tea-dev-agent-defs-deviation-logging
**Assigned:** keith.avery@1898andco.io
**Started:** 2026-03-12

## Story Context

Story 144-2 closes the behavioral gap in TEA and Dev agent definitions. Story 144-1 delivered the 6-field deviation format spec (`pennyfarthing-dist/guides/deviation-format.md`) and upgraded the `deviations-logged` gate to validate that format. This story updates both agent definitions to mandate that format by reference — making real-time logging the explicit, non-optional instruction.

**Files to modify:**
- `pennyfarthing-dist/agents/tea.md` — replace `<deviation-tracking>` with `<deviation-logging>`
- `pennyfarthing-dist/agents/dev.md` — replace `<deviation-tracking>` with `<deviation-logging>`

**What NOT to touch:** Gate files, guide files, exit sections, workflow YAML, any other agent definitions.

## Acceptance Criteria

### AC-1: TEA agent definition includes `<deviation-logging>` section
- Section replaces `<deviation-tracking>` with `<deviation-logging>` tag
- Names three spec sources: story context, epic context, sibling story ACs
- Specifies subsection header: `### TEA (test design)`
- Instructs real-time logging at moment of decision, not at phase exit
- States: "Never assume simplification is acceptable — log it as a deviation"
- Includes 6-field format with one example, references the guide

### AC-2: Dev agent definition includes the same `<deviation-logging>` section
- Same requirements as AC-1 with subsection `### Dev (implementation)`
- Dev's spec sources include tests TEA wrote plus original context documents

### AC-3: Agents log deviations immediately, not at phase exit
- Wording explicitly distinguishes "at the moment of the decision" from "during exit"
- Framed as requirement, not suggestion

## SM Assessment

Trivial 2pt story — agent definition updates only, no code. Depends on 144-1 which is already done. Routing directly to Naomi (Dev) for implementation.

## Design Deviations

### Dev (implementation)
- No deviations from spec.

## Delivery Findings

### Dev (implementation)
- No upstream findings during implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/tea.md` — replaced `<deviation-tracking>` with `<deviation-logging>`, 6-field format, guide reference, real-time logging mandate
- `pennyfarthing-dist/agents/dev.md` — same replacement, Dev-specific subsection and spec sources (includes TEA's tests)

**Tests:** N/A (agent definition markdown, no code)
**Branch:** feature/story-144-2-update-tea-dev-agent-defs-deviation-logging (pushed)

**AC Coverage:**
- AC-1: TEA section has all required elements — tag name, three spec sources, subsection header, real-time instruction, no-simplification rule, 6-field example with guide reference
- AC-2: Dev section mirrors TEA with `### Dev (implementation)` and adds TEA's tests as a spec source
- AC-3: Both sections say "at the moment of the decision, not at phase exit" — framed as requirement via gate consequence

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

10 observations, all verified clean. Symmetric changes to two files, correct tag rename, guide reference over inline duplication (Principle 2), real-time logging mandate with gate-consequence framing (Principle 6). Scope respected — no changes outside the two `<deviation-logging>` sections.

**Handoff:** To SM for finish-story

### Reviewer (code review)
- No upstream findings during code review.

## Session Log

- 2026-03-12: Session created by SM setup
- 2026-03-12: SM assessment complete, handing off to Dev (implement phase)
- 2026-03-12: Dev implementation complete, 2 files changed, branch pushed
- 2026-03-12: Reviewer approved — clean, symmetric, spec-compliant