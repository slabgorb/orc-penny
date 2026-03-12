---
parent: context-epic-144.md
workflow: trivial
---

# Story 144-2: Update TEA and Dev Agent Definitions for Deviation Logging

## Business Context

The current TDD pipeline has a silent spec-drift problem: when TEA writes tests or Dev implements features, departures from story context, epic context, or PRD requirements go undocumented unless agents happen to mention them. The `deviations-logged` gate exists but only checks that a section is present — not that entries are complete. Agents defer documentation to phase exit (or skip it entirely), producing half-baked or missing entries that defeat the purpose of the gate.

This story closes the behavioral gap. TEA and Dev already have `<deviation-tracking>` sections in their agent definitions that describe the concept of logging deviations. Story 144-1 upgrades that concept with a strict 6-field structured format and a guide at `pennyfarthing-dist/guides/deviation-format.md`. Story 144-2 updates both agent definitions to mandate that format by reference — making real-time logging the explicit, non-optional instruction rather than a soft suggestion.

The goal is that agents log deviations at the moment of the decision, with all required fields, under the correct subsection header. The upgraded `deviations-logged` gate (144-1) then enforces format validity at exit. Together these two stories enforce the principle: **Gates Over Goodwill** (Principle 6). Neither agent can hand off without a complete deviation record or an explicit "No deviations from spec." statement.

This is a direct enforcement mechanism for FR-1 from the PRD: deviation entries must contain all 6 fields (spec source, spec text, implementation, rationale, severity, forward impact) and must be filed under the correct agent-specific subsection.

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/agents/tea.md` | Replace existing `<deviation-tracking>` section with upgraded `<deviation-logging>` section |
| `pennyfarthing-dist/agents/dev.md` | Replace existing `<deviation-tracking>` section with upgraded `<deviation-logging>` section |

### Dependency on 144-1

The `<deviation-logging>` section in each agent definition must reference the format spec guide delivered by 144-1 at `pennyfarthing-dist/guides/deviation-format.md`. The guide is the single source of truth for the 6-field format. Do not re-specify the full format inline in each agent file — reference the guide and include one inline example for clarity.

### Existing Structure to Replace

Both agent files have a `<deviation-tracking>` XML section with a simplified inline format:

```
- **{what you changed}:** Spec said {X}, implemented {Y}. Reason: {why in one sentence}.
```

This must be replaced with a `<deviation-logging>` section that:
- Names the correct subsection header for each agent (`### TEA (test design)` or `### Dev (implementation)`)
- Specifies the 6-field format with an example
- Mandates logging against story context, epic context, and sibling story ACs
- Explicitly states: "Never assume simplification is acceptable — log it as a deviation"
- Instructs agents to log at the moment of the decision, not at phase exit

### What NOT to Touch

- The `<exit>` section of either agent — it already references `gates/deviations-logged`. No change needed there.
- The gate file `pennyfarthing-dist/gates/deviations-logged.md` — owned by 144-1.
- The guide `pennyfarthing-dist/guides/deviation-format.md` — owned by 144-1.
- TEA's `<workflow>`, `<verify-workflow>`, `<assessment-template>`, `<finding-capture>`, or any other sections.
- Dev's `<workflow>`, `<assessment-template>`, `<self-review>`, `<finding-capture>`, or any other sections.
- Any other agent definition files.

### Tag Name Change

The XML tag changes from `<deviation-tracking>` to `<deviation-logging>` in both files. This is intentional — the new tag name reflects the mandatory, structured nature of the requirement versus the old advisory framing.

### Patterns to Follow

- **Symmetry:** Both files get identical `<deviation-logging>` content except for the subsection header (`### TEA (test design)` vs `### Dev (implementation)`) and agent-appropriate framing.
- **Guide reference over inline spec:** Point to the guide, include one example. Don't duplicate the full format definition.
- **XML tag convention:** Use `<deviation-logging>` (lowercase, hyphenated) to match existing tag conventions in these files.

## Scope Boundaries

**In scope:**
- Replace `<deviation-tracking>` with `<deviation-logging>` in `pennyfarthing-dist/agents/tea.md`
- Replace `<deviation-tracking>` with `<deviation-logging>` in `pennyfarthing-dist/agents/dev.md`
- Each new section mandates the 6-field format, references the guide, includes one example, states the no-simplification rule, and instructs real-time logging
- Verify the `<exit>` gate reference in each file still reads correctly alongside the new section

**Out of scope:**
- Modifying the `deviations-logged` gate (144-1)
- Creating the deviation format guide (144-1)
- Updating any other agent definitions (Reviewer, Architect)
- Adding deviation logging to TEA's verify workflow — verify is not a RED phase and does not produce implementation deviations
- Updating the Architect agent definition — Architect gets its own `### Architect (reconcile)` subsection instructions in stories 144-6 and 144-7
- Changes to any session schema, workflow YAML, or gate files

## AC Context

### AC 1: TEA agent definition includes `<deviation-logging>` section mandating logging against all available specs

The section must appear in `pennyfarthing-dist/agents/tea.md`, replacing `<deviation-tracking>`.

**What must be true:**
- Section header is `<deviation-logging>` (not `<deviation-tracking>`)
- Section explicitly names: story context, epic context, and sibling story ACs as the three spec sources TEA must check deviations against
- Section specifies the subsection header: `### TEA (test design)` — entries go here, not under any other subheading
- Section instructs real-time logging: "Log at the moment of the decision, not at phase exit"
- Section explicitly states: "Never assume simplification is acceptable — log it as a deviation"
- Section includes the 6-field format with one example entry (referencing the guide for the full spec)
- "No deviations from spec." explicit statement is valid when there are none

**Edge cases:**
- Test omissions count as deviations — if TEA decides not to test something the spec requires, that's a deviation entry, not silence
- Partial implementations of an AC (testing fewer cases than specified) are deviations
- A decision to use a different test strategy than the AC implies (e.g., property-based vs enumerated examples) is a deviation if it changes what gets tested

### AC 2: Dev agent definition includes the same `<deviation-logging>` section

The section must appear in `pennyfarthing-dist/agents/dev.md`, replacing `<deviation-tracking>`.

**What must be true:**
- All requirements from AC 1 apply, with these differences:
  - Subsection header is `### Dev (implementation)` (not `### TEA (test design)`)
  - "against the spec" framing refers to implementation diverging from story context, epic context, and test expectations — Dev's spec sources include the tests TEA wrote as well as the original context documents
- Section explicitly states: "Never assume simplification is acceptable — log it as a deviation"

**Edge cases:**
- Simplification of a data structure (e.g., flattening a struct that the spec called a nested type) is a deviation — must be logged even if it feels minor
- Using a different algorithm or approach than the AC specifies is a deviation if the AC was prescriptive
- Adding an abstraction not required by any test is scope creep — must be logged
- Implementation choices that affect a sibling story's assumptions (even if Dev doesn't know it) are deviations with "Forward impact" set appropriately

### AC 3: Agents log deviations immediately, not at phase exit

The agent definition must instruct TEA and Dev to log at the moment of the decision.

**What must be true:**
- The wording explicitly distinguishes "at the moment of the decision" from "during exit"
- This is framed as a requirement, not a suggestion ("must log", not "consider logging")
- The rationale is implicit in the framing: the gate at exit validates the format — if the agent waits until exit, rushed entries will miss fields and the gate will fail

**How a test would verify this:**
- Behavioral test: an agent given a scenario where it decides to deviate should produce a deviation entry before writing its assessment, not only in the assessment. The session file would show the deviation entry appearing before the assessment section.

## Assumptions

Depends on 144-1 delivering the deviation format spec at `pennyfarthing-dist/guides/deviation-format.md` with the 6-field structured format and agent-specific subsections. This story's `<deviation-logging>` section references that guide — if the guide doesn't exist or uses a different format, the reference will be stale and the example in the agent definition will be inconsistent with what the gate validates.

Specifically assumes:
- 144-1 finalizes these 6 fields with these exact names: Spec source, Spec text, Implementation, Rationale, Severity, Forward impact
- 144-1 finalizes these subsection headers: `### TEA (test design)`, `### Dev (implementation)`, `### Architect (reconcile)`
- 144-1 finalizes that "No deviations from spec." is the valid explicit no-deviation statement (exact phrasing matters — the gate will check for it)
- The guide path is `pennyfarthing-dist/guides/deviation-format.md` (not a different location)

No cross-story assumptions beyond 144-1. Stories 144-6 and 144-7 (Architect phases) depend on this story, not the other way around.
