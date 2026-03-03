---
parent: context-epic-138.md
workflow: trivial
---

# Story 138-7: Define SIMPLIFY_RESULT structured finding format

## Business Context

The three simplify teammates and TEA's aggregation logic need a shared contract for communicating findings. The `SIMPLIFY_RESULT` format defines this contract — a structured YAML block that every simplify teammate returns and TEA parses. Without a consistent format, TEA cannot reliably aggregate results from parallel teammates, and the confidence-based apply/reject decision logic breaks down. This is the data contract that ties the entire simplify feature together.

## Technical Guardrails

### SIMPLIFY_RESULT Schema

Every simplify teammate returns findings in this YAML format:

```yaml
SIMPLIFY_RESULT:
  agent: simplify-reuse | simplify-quality | simplify-efficiency
  status: clean | findings
  findings:
    - file: "path/to/file.ts"
      line: 42
      category: "duplicated-logic" | "naming" | "over-engineering" | etc.
      description: "What was found"
      suggestion: "What to do about it"
      confidence: high | medium | low
```

### Field Definitions

| Field | Type | Required | Valid Values | Purpose |
|-------|------|----------|--------------|---------|
| `agent` | enum | Yes | `simplify-reuse`, `simplify-quality`, `simplify-efficiency` | Identifies which teammate generated this result |
| `status` | enum | Yes | `clean`, `findings` | Overall result — `clean` if no issues, `findings` if one or more findings present |
| `findings[]` | array | When status=findings | Array of finding objects | List of specific issues discovered |
| `file` | string | Per finding | Relative path (e.g., `src/utils.ts`) | File containing the issue |
| `line` | number | Per finding | Integer ≥ 1 | Line number where issue starts |
| `category` | string | Per finding | Teammate-specific (see below) | Category of the finding |
| `description` | string | Per finding | Free text | Human-readable description of what was found |
| `suggestion` | string | Per finding | Free text | Specific action to resolve the issue |
| `confidence` | enum | Per finding | `high`, `medium`, `low` | Confidence level in finding correctness |

### Category Values by Teammate

**simplify-reuse categories:**
- `duplicated-logic` — Code that appears in multiple files with identical or near-identical logic
- `extractable-helper` — Repeated pattern that could be extracted into a shared function
- `shared-constant` — Constant values that should be defined once and reused
- `shared-type` — Type definitions that could be shared across files

**simplify-quality categories:**
- `naming` — Variable, function, or class names that don't reflect intent
- `dead-code` — Unreachable or unused code
- `unclear-structure` — Function/class structure that makes intent hard to follow
- `unnecessary-comment` — Comments that restate code instead of explaining why
- `readability` — General readability improvements (line length, nesting, spacing)

**simplify-efficiency categories:**
- `over-engineering` — Unnecessary abstraction or generalization for a single use case
- `unnecessary-complexity` — Complex approach when a simpler one suffices
- `redundant-operation` — Repeated computation that could be cached or computed once
- `premature-abstraction` — Abstraction added before it's actually needed

### Confidence Level Semantics

- **`high`** — Unambiguous, safe, clearly correct. TEA applies automatically without manual review.
- **`medium`** — Likely correct but may have context-dependent nuance. TEA reviews manually before applying.
- **`low`** — Suggestion or observation, not a clear defect. TEA documents but does not apply without explicit review.

### Format Requirements

- **Machine-parseable:** YAML syntax must be valid and parseable by TEA's aggregation logic
- **Status consistency:** When `status: clean`, findings array must be empty or absent
- **Line numbers:** Must be positive integers, correspond to actual source file lines
- **File paths:** Relative to repository root; use forward slashes even on Windows

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

## Example Outputs

### Example 1: Clean Report (No Findings)

```yaml
SIMPLIFY_RESULT:
  agent: simplify-reuse
  status: clean
  findings: []
```

### Example 2: Single High-Confidence Finding

```yaml
SIMPLIFY_RESULT:
  agent: simplify-quality
  status: findings
  findings:
    - file: "src/services/user-service.ts"
      line: 42
      category: naming
      description: "Variable 'x' does not indicate its purpose; appears to be a user configuration object"
      suggestion: "Rename 'x' to 'userConfig' to improve code clarity"
      confidence: high
```

### Example 3: Multiple Findings with Mixed Confidence

```yaml
SIMPLIFY_RESULT:
  agent: simplify-efficiency
  status: findings
  findings:
    - file: "src/utils/validators.ts"
      line: 12
      category: redundant-operation
      description: "The validation regex is compiled in every function call; should be defined once at module level"
      suggestion: "Extract regex to module-level constant: const EMAIL_PATTERN = /^[^@]+@[^@]+\\.[^@]+$/; and reuse in all functions"
      confidence: high
    - file: "src/components/form.tsx"
      line: 88
      category: over-engineering
      description: "Custom form state management layer wraps React Hook Form; adds unnecessary indirection"
      suggestion: "Consider using React Hook Form directly without the wrapper to reduce indirection and improve maintainability"
      confidence: medium
    - file: "src/api/client.ts"
      line: 156
      category: unnecessary-complexity
      description: "Error retry logic uses exponential backoff with jitter; simple linear retry would suffice for this API"
      suggestion: "Simplify retry strategy from exponential backoff to linear backoff (e.g., 1s, 2s, 3s)"
      confidence: low
```

## Key References

- **Epic Context:** `sprint/context/context-epic-138.md` — Overview and data flow
- **PRD:** `sprint/planning/prd.md` — FR-5 (Structured Finding Format) and user journeys
- **Guides:** `pennyfarthing-dist/guides/fan-out-fan-in-pattern.md` — Parallel agent result aggregation patterns

## AC Context

### AC-1: Schema Documentation Exists

A new file `pennyfarthing-dist/schemas/simplify-result-schema.md` documents:
- Complete SIMPLIFY_RESULT YAML structure with all required and optional fields
- Field type definitions and constraints (enum values, required/conditional fields)
- Category value taxonomy for each teammate specialization
- Confidence level definitions and how TEA interprets each level
- Minimum 3 complete example outputs:
  - Clean report (no findings)
  - Single finding with high confidence
  - Multiple findings with mixed confidence levels

**Testable:** The file exists, is well-formed Markdown, contains all required sections, and can be referenced by agent definitions.

### AC-2: Format Supports Non-Finding Cases

The documentation clearly shows how to represent "no issues found" using `status: clean` and an empty findings array. TEA can distinguish between "no findings" and "no response from teammate."

**Testable:** Example outputs in the schema show both `status: clean` and `status: findings` cases.

### AC-3: Category Values are Documented per Teammate

The schema includes a table or section listing valid `category` values for each teammate type:
- simplify-reuse categories (duplicated-logic, extractable-helper, shared-constant, shared-type)
- simplify-quality categories (naming, dead-code, unclear-structure, unnecessary-comment, readability)
- simplify-efficiency categories (over-engineering, unnecessary-complexity, redundant-operation, premature-abstraction)

**Testable:** Categories are discoverable in the schema document; agents can reference them for validation.

### AC-4: Confidence Level Semantics are Clear

The documentation explicitly defines how TEA should interpret confidence levels:
- `high`: Auto-apply without manual review
- `medium`: Review manually before applying
- `low`: Document findings but do not apply without explicit review

**Testable:** TEA agent definition (story 138-4) can reference these semantics when implementing decision logic.

### AC-5: Schema References Agent Definitions

The schema or related guide explicitly states that this format is used by:
- `pennyfarthing-dist/agents/simplify-reuse.md`
- `pennyfarthing-dist/agents/simplify-quality.md`
- `pennyfarthing-dist/agents/simplify-efficiency.md`
- `pennyfarthing-dist/agents/tea.md` (for aggregation)

**Testable:** Schema file mentions these four agent definitions by name.
