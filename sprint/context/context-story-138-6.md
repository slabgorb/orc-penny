---
parent: 138
workflow: trivial
---

# Story 138-6: Update TEA assessment template with simplify report section

## Business Context

Transparency is a core success criterion for the simplify feature. Human operators reviewing session files need to see exactly what each simplify teammate found, what TEA applied, and what was rejected (and why). This story adds a structured "Simplify Report" section to TEA's session assessment template, making simplify results visible in every story's session file. This enables tracking of simplify effectiveness over time and builds trust in the automated quality process.

## Technical Guardrails

- **Modify:** TEA assessment template section (in `pennyfarthing-dist/agents/tea.md` or the session assessment template, wherever the assessment format is defined)
- **Format:** Per FR-4.1 in PRD — structured markdown with per-teammate summaries and applied/rejected counts
- **Section placement:** After existing assessment sections, before handoff notes
- **Clean code case:** When all teammates report `status: clean`, the section should still appear with "No issues found" entries (Journey 2 in PRD)
- **Regression case:** When a simplify fix is reverted, the section should document what was reverted and why (Journey 3 in PRD)

## Scope Boundaries

**In scope:**
- Define the Simplify Report section format in TEA's assessment template
- Cover all reporting scenarios: findings applied, findings rejected, clean code, teammate failure, regression/revert
- Ensure the format is human-readable in session file markdown

**Out of scope:**
- TEA integration logic for populating the template (story 138-4)
- Subagent definitions (stories 138-1, 138-2, 138-3)
- BikeRack metrics dashboard (post-MVP growth feature)
- Historical trend tracking (post-MVP)

## AC Context

1. **Simplify Report section defined** — TEA assessment template includes a `### Simplify Report` section with the format specified in FR-4.1:
   - Per-teammate summary line (Reuse, Quality, Efficiency) with findings or "No issues found"
   - Applied/rejected counts with rejection reasons
2. **Clean code scenario handled** — When all three teammates report `status: clean`, the section renders with "No issues found" for each category and "Applied: 0/0 suggestions"
3. **Regression scenario handled** — When a simplify fix is reverted due to quality-pass gate failure, the section documents what was reverted and references the failing test/check
4. **Teammate failure scenario handled** — If a teammate failed or timed out, the section notes the failure rather than silently omitting the category
5. **Section integrates with existing assessment** — The Simplify Report does not break or overlap with existing TEA assessment sections
