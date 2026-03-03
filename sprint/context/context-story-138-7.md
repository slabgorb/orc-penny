---
parent: 138
workflow: trivial
---

# Story 138-7: Define SIMPLIFY_RESULT structured finding format

## Business Context

The three simplify teammates and TEA's aggregation logic need a shared contract for communicating findings. The `SIMPLIFY_RESULT` format defines this contract — a structured YAML block that every simplify teammate returns and TEA parses. Without a consistent format, TEA cannot reliably aggregate results from parallel teammates, and the confidence-based apply/reject decision logic breaks down. This is the data contract that ties the entire simplify feature together.

## Technical Guardrails

- **Define:** `SIMPLIFY_RESULT` YAML format as documented in FR-5 of the PRD and the epic context's "Structured Finding Format" section
- **Location:** The format should be documented in a shared location referenced by all three subagent definitions and TEA — likely `pennyfarthing-dist/schemas/` or within the agent definition files themselves
- **Fields:** `agent`, `status`, `findings[]` with `file`, `line`, `category`, `description`, `suggestion`, `confidence`
- **Confidence semantics:** `high` = TEA auto-applies; `medium` = TEA reviews manually; `low` = TEA reviews, likely rejects
- **Status values:** `clean` (no findings) or `findings` (has findings array)
- **Parseable:** Format must be machine-parseable by TEA for automated aggregation

## Scope Boundaries

**In scope:**
- SIMPLIFY_RESULT YAML format specification with all required fields
- Confidence level semantics and how TEA interprets each level
- Category taxonomy for each teammate type (reuse categories, quality categories, efficiency categories)
- Status field semantics (`clean` vs `findings`)
- Documentation of the format in an appropriate location

**Out of scope:**
- TEA's parsing and aggregation logic (story 138-4)
- Subagent definitions that use the format (stories 138-1, 138-2, 138-3)
- Assessment template that summarizes the results (story 138-6)
- Runtime validation of the format (not needed — teammates are prompted to produce it)

## AC Context

1. **Format documented** — The `SIMPLIFY_RESULT` YAML format is defined with all required fields: `agent`, `status`, `findings[]` where each finding has `file`, `line`, `category`, `description`, `suggestion`, `confidence`
2. **Agent field values specified** — `agent` must be one of `simplify-reuse`, `simplify-quality`, `simplify-efficiency`
3. **Status semantics defined** — `clean` means no issues found (findings array empty or absent); `findings` means the findings array is populated
4. **Confidence semantics defined** — `high`: strong signal, TEA should auto-apply; `medium`: reasonable signal, TEA reviews before applying; `low`: weak signal or ambiguous, TEA reviews and likely rejects
5. **Category taxonomy defined** — Each teammate type has its own valid categories: reuse (`duplicated-logic`, `extractable-helper`, `shared-pattern`), quality (`naming`, `readability`, `dead-code`, `unnecessary-comment`, `structure`), efficiency (`over-engineering`, `premature-abstraction`, `redundant-operation`, `unnecessary-complexity`)
6. **Example included** — At least one complete example of a `SIMPLIFY_RESULT` block with findings, demonstrating all fields
7. **Location accessible** — The format definition is in a location that all three subagent definitions and TEA can reference
