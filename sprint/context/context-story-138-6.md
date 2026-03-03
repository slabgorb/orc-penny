---
parent: context-epic-138.md
workflow: trivial
---

# Story 138-6: Update TEA assessment template with simplify report section

## Business Context

Human operators need visibility into what the three simplify teammates (reuse, quality, efficiency) found and how their suggestions were applied. Currently, the TEA assessment template has no section for simplify findings—operators can't see what improvements were made or rejected. Story 138-6 adds a new "Simplify Report" section to the TEA assessment, giving human operators a clear summary of each teammate's findings and whether suggestions were applied, rejected, or had issues.

## Technical Guardrails

The assessment template lives in `pennyfarthing-dist/agents/tea.md` under the `<assessment-template>` section (lines 114-152). The template is a markdown block embedded in the agent definition, shown to TEA as a reference for what to write into the session file.

The new Simplify Report section follows this pattern:

```markdown
### Simplify Report
- **Reuse:** {findings summary or "No issues found"}
- **Quality:** {findings summary or "No issues found"}
- **Efficiency:** {findings summary or "No issues found"}
- **Applied:** {N}/{total} suggestions | **Rejected:** {M} ({reasons})
```

**Key markdown format rules:**
- Subsection header: `### Simplify Report` (not `##` — this is a subsection within the TEA Assessment)
- Four bullet points: one for each teammate, plus a summary of applied/rejected counts
- Each teammate bullet: `**{Name}:**` (bold) followed by either a one-line summary of findings or "No issues found"
- Applied/Rejected line: `**Applied:** {count}/{total}` and `**Rejected:** {count}` with brief reasons in parentheses
- This section appears AFTER the `**Handoff:**` line in the template but BEFORE any delivery findings (delivery findings go in a separate session section, not the assessment)

**Assessment template context:**
- Used by TEA during RED, GREEN, and VERIFY phases
- RED phase (test design) assessment is simpler — just test files and status
- VERIFY phase (test verification, where simplify happens) assessment should include the Simplify Report
- The template is a reference guide TEA reads; TEA adapts it based on context (e.g., RED assessment ≠ VERIFY assessment)

## Scope Boundaries

**In scope:**
- Update `<assessment-template>` section in `pennyfarthing-dist/agents/tea.md` to include the new Simplify Report subsection
- Include an example showing how simplify findings map to the report format
- Document that the Simplify Report only appears in VERIFY phase assessments, not RED assessments

**Out of scope:**
- Implementing the logic that populates the report (that's in TEA's VERIFY phase behavior — 138-4)
- The structured finding format or SIMPLIFY_RESULT YAML (that's 138-7)
- BikeRack visualization of simplify findings (that's Growth, not MVP)
- Creating actual simplify teammate definitions (that's 138-1, 138-2, 138-3)

## AC Context

**Testable detail:** The updated `tea.md` file at `pennyfarthing-dist/agents/tea.md` lines 114-152 (the `<assessment-template>` section) must include a `### Simplify Report` subsection with the four-bullet format shown above. An example assessment should demonstrate all three teammates reporting findings and the applied/rejected summary. The section must be clearly marked as VERIFY-phase-only (RED phase assessments don't include it).

**Acceptance criteria:**
1. `<assessment-template>` section in `pennyfarthing-dist/agents/tea.md` includes a `### Simplify Report` subsection after the Handoff line
2. The report format matches the template: three teammate bullets + applied/rejected summary
3. An example TEA assessment shows what a real Simplify Report looks like (e.g., "Reuse: Extracted shared validation to validate_input() (3 call sites)")
4. The template notes that Simplify Report is VERIFY-phase-only; RED assessments don't include it
5. The documentation is clear enough for TEA to use as a reference when writing assessments during VERIFY

**Depends on:**
- 138-4 (TEA verify extension) — so TEA knows how to gather simplify findings
- 138-7 (SIMPLIFY_RESULT format) — so the findings have a consistent structure to aggregate
