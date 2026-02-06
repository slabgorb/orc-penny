# Epic 45: Gold Standard References - Technical Context

## Epic Overview

- **Epic ID:** epic-45
- **Title:** Gold Standard References
- **Points:** 8 (2 + 2 + 3 + 1)
- **Priority:** P2
- **Marker:** benchmark
- **Repos:** pennyfarthing
- **Status:** planning

## Goal

Add human-curated ideal responses to scenarios that the Judge can use as calibration references. This reduces scoring variance and provides consistent evaluation anchored to known-good examples.

## Research Basis

| Source | Contribution |
|--------|--------------|
| Wallach et al. | Operationalization needs clear anchoring to ensure consistent interpretation |
| HELM | Uses reference implementations for calibration |
| MLPerf | Provides gold standards for performance comparison |

**Framework Alignment:** Level 3 improvement - calibration anchors for the evaluation pipeline.

## Problem Statement

Current Judge evaluation has variance issues:

1. **Subjective interpretation** - Same response may score differently across runs
2. **No calibration anchor** - Judge has no concrete example of "high quality"
3. **Drift potential** - Without reference points, scoring can drift over time
4. **New evaluator onboarding** - Hard to understand what "good" looks like

## Gold Standard Concept

A gold standard is a human-curated "ideal" response for a scenario that represents what a high-quality agent response should look like. It serves as:

1. **Calibration Reference** - Judge compares actual responses against the gold standard
2. **Scoring Anchor** - Provides concrete example of what scores 90-100
3. **Variance Reducer** - Consistent reference point across evaluation runs
4. **Quality Definition** - Documents what "good" looks like for each scenario

### Benefits

| Benefit | Mechanism |
|---------|-----------|
| Reduced variance | Judge has concrete anchor instead of abstract rubric |
| Consistent scoring | Same reference used across all runs |
| Faster calibration | New evaluators see real examples |
| Objective baseline | Less reliance on Judge's interpretation |

## Schema Design

### New `gold_standard` Field

Add to `pennyfarthing/scenarios/schema.yaml`:

```yaml
gold_standard:
  type: object
  required: false
  description: "Human-curated ideal response for calibration"
  schema:
    response:
      type: string
      multiline: true
      description: "The ideal response text"

    score:
      type: integer
      range: [90, 100]
      description: "Expected score for this response"

    author:
      type: string
      description: "Who curated this gold standard"

    version:
      type: string
      description: "Version for tracking updates"

    rationale:
      type: string
      multiline: true
      description: "Why this response is considered ideal"

    key_elements:
      type: array
      items: string
      description: "Critical elements that make this response high-quality"

    coverage:
      type: object
      description: "For checklist scenarios - which baseline items are found"
      schema:
        baseline_found:
          type: array
          items: string
          description: "IDs of baseline issues/criteria addressed"
        bonus_found:
          type: array
          items: string
          description: "IDs of bonus items addressed"
```

### Example Usage

```yaml
# In pennyfarthing/scenarios/code-review/order-service.yaml

gold_standard:
  response: |
    ## Critical Security Issues

    ### 1. SQL Injection Vulnerabilities (CRITICAL)

    **Line 107 - GetOrder:**
    ```go
    query := fmt.Sprintf("SELECT * FROM orders WHERE id = %s", orderID)
    ```
    This is textbook SQL injection. An attacker can pass `1 OR 1=1` to dump all orders.

    **Fix:** Use parameterized queries:
    ```go
    row := s.db.QueryRow("SELECT * FROM orders WHERE id = ?", orderID)
    ```

    [... continues with all 22 baseline issues ...]

    ## Summary
    Found 22 baseline issues (6 critical, 6 high, 8 medium, 2 low) plus 8 bonus issues.
    This code should NOT be merged until at least all critical and high issues are fixed.

  score: 95
  author: "Lord Varys (human review)"
  version: "1.0"
  rationale: |
    This response demonstrates ideal code review behavior:
    - Finds all 22 baseline issues with correct severity
    - Provides specific line numbers and code examples
    - Includes working fixes for each issue
    - Prioritizes by severity (critical first)
    - Clear merge recommendation

  key_elements:
    - "All 6 critical SQL injection issues identified"
    - "All 6 high-severity auth/data exposure issues found"
    - "Specific line numbers provided"
    - "Working code fixes included"
    - "Clear severity classification"
    - "Actionable merge recommendation"

  coverage:
    baseline_found:
      - SQL_INJECTION_GET_ORDER
      - SQL_INJECTION_CANCEL
      - SQL_INJECTION_USER_ORDERS
      - SQL_INJECTION_REFUND_LOG
      - SQL_INJECTION_EXPORT
      - CREDIT_CARD_STORED
      # ... all 22 baseline IDs
    bonus_found:
      - NO_TRANSACTION
      - SAGA_PATTERN_MISSING
      - NO_IDEMPOTENCY
      # ... 8 bonus items
```

## Judge Calibration Integration

### How Judge Uses Gold Standard

When `gold_standard` is present in a scenario, the Judge prompt includes:

```
## Calibration Reference (Gold Standard)

Below is a human-curated ideal response for this scenario. Use it to calibrate your scoring:

### Gold Standard Response
{gold_standard.response}

### Expected Score: {gold_standard.score}

### Key Elements That Make This High Quality:
{gold_standard.key_elements as bullet list}

### Scoring Guidance:
- Responses matching most key elements: 85-100
- Responses missing some key elements: 70-85
- Responses missing many key elements: 50-70
- Responses fundamentally different: <50

Compare the actual response against this gold standard when assigning scores.
```

### Calibration Mode

New Judge mode for validation:

```
/judge --mode calibrate --data <json>
```

**Input:**
```json
{
  "scenario": "order-service",
  "gold_standard_response": "<the gold standard>",
  "expected_score": 95
}
```

**Output:**
```json
{
  "calibration_score": 94.5,
  "deviation": -0.5,
  "within_tolerance": true,
  "tolerance": 5.0
}
```

If Judge scores the gold standard more than 5 points below expected, calibration warning is raised.

## Story-by-Story Technical Notes

### Story 45-1: Add gold_standard Schema to Scenarios (2 pts)

**Scope:**
1. Update `pennyfarthing/scenarios/schema.yaml` with `gold_standard` field definition
2. Add schema validation in scenario loader
3. Document field in README

**Files to Modify:**
- `pennyfarthing/scenarios/schema.yaml` - Add gold_standard section
- `pennyfarthing/scenarios/README.md` - Document new field

**Acceptance Criteria:**
- [ ] Schema defines all gold_standard subfields
- [ ] Scenarios with gold_standard pass validation
- [ ] Scenarios without gold_standard still work (optional field)

---

### Story 45-2: Update Judge to Use Gold Standard as Calibration (2 pts)

**Scope:**
1. Modify Judge prompt construction to include gold_standard when present
2. Add calibration guidance to scoring rubric
3. Add `calibrate` mode for testing gold standard scoring

**Files to Modify:**
- `pennyfarthing/pennyfarthing-dist/skills/judge/SKILL.md` - Add gold standard section
- Judge prompt construction logic (wherever judge prompts are built)

**Key Changes:**

```markdown
## Judge Prompt (with Gold Standard)

When scenario has gold_standard, add to prompt:

### Calibration Reference

Use this human-curated ideal response to anchor your scoring:

**Gold Standard Response:**
{scenario.gold_standard.response}

**Expected Score:** {scenario.gold_standard.score}

**Key Quality Elements:**
{scenario.gold_standard.key_elements}

Score the actual response relative to this calibration anchor.
```

**Acceptance Criteria:**
- [ ] Judge prompt includes gold standard when present
- [ ] Judge prompt unchanged when no gold standard
- [ ] `calibrate` mode validates Judge scores gold standard correctly

---

### Story 45-3: Create Gold Standards for 5 High-Variance Scenarios (3 pts)

**Target Scenarios:**
Select 5 scenarios with highest CV (coefficient of variation) from control baselines:

| Scenario | Category | Current CV | Notes |
|----------|----------|------------|-------|
| layoff-planning | sm | ~35% | Ethical dilemma, high variance |
| three-sprint-failure | sm | ~30% | Complex facilitation |
| microservice-integration-tests | tea | ~25% | Technical depth varies |
| cli-tool-tests | tea | ~22% | Edge case coverage varies |
| migration-disaster | dev | ~20% | Architecture decisions vary |

**For Each Scenario:**
1. Run scenario with best-performing personas
2. Synthesize ideal response from top 3 runs
3. Have human curator refine and annotate
4. Document key_elements and rationale
5. Validate with calibration mode

**Deliverables:**
- 5 scenario YAML files updated with `gold_standard` section
- Each gold standard has:
  - Full response text
  - score (90-100)
  - author attribution
  - rationale
  - key_elements list
  - coverage (for checklist scenarios)

**Acceptance Criteria:**
- [ ] 5 scenarios have gold_standard field populated
- [ ] Each gold standard validated with calibrate mode
- [ ] Gold standards score within 5 points of expected

---

### Story 45-4: Variance Comparison: With/Without Gold Standard (1 pt)

**Experiment Design:**

1. **Select 3 scenarios** with gold standards from 45-3
2. **Run 10 evaluations each** in two conditions:
   - Condition A: Judge without gold standard (current behavior)
   - Condition B: Judge with gold standard calibration
3. **Measure:**
   - Mean score
   - Standard deviation
   - Coefficient of variation (CV = std/mean)
4. **Compare CV** between conditions

**Expected Result:**
- CV decrease of 50% or more with gold standard calibration
- Example: If current CV is 20%, expect CV < 10% with gold standard

**Output:**
- `internal/results/gold-standard-variance-study/` directory
- Summary report with statistics
- Recommendation for gold standard rollout

**Acceptance Criteria:**
- [ ] 30 runs per condition (3 scenarios x 10 runs)
- [ ] CV calculated for both conditions
- [ ] Variance reduction documented (target: 50% decrease)
- [ ] Report with methodology and findings

## Implementation Sequence

```
45-1 (Schema) ─────────┬──────> 45-3 (Create Gold Standards)
                       │                    │
45-2 (Judge Update) ───┘                    │
                                            v
                                  45-4 (Variance Study)
```

**Dependencies:**
- 45-3 depends on both 45-1 (schema) and 45-2 (judge can use it)
- 45-4 depends on 45-3 (needs gold standards to test)

## Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| CV Reduction | >= 50% | Compare CV with/without gold standard |
| Schema Validation | 100% | All gold standards pass validation |
| Calibration Accuracy | +/- 5 pts | Judge scores gold standard within 5 of expected |
| Coverage | 5 scenarios | 5 high-variance scenarios have gold standards |

## Key Files

| File | Purpose |
|------|---------|
| `pennyfarthing/scenarios/schema.yaml` | Schema definition (modify) |
| `pennyfarthing/pennyfarthing-dist/skills/judge/SKILL.md` | Judge skill (modify) |
| `pennyfarthing/scenarios/sm/*.yaml` | SM scenarios (add gold standards) |
| `pennyfarthing/scenarios/tea/*.yaml` | TEA scenarios (add gold standards) |
| `pennyfarthing/scenarios/dev/*.yaml` | Dev scenarios (add gold standards) |
| `internal/results/gold-standard-variance-study/` | Variance study results (new) |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Gold standard biases scoring | Use diverse curation team, rotate authors |
| Gold standard becomes stale | Version field, periodic review schedule |
| Judge overfits to gold standard | Keep gold standard in calibration role, not as answer key |
| Human curation expensive | Start with 5 highest-variance scenarios only |

## Future Considerations

1. **Automated gold standard generation** - Use ensemble of top runs as draft
2. **Multi-gold-standard support** - Multiple valid approaches for open-ended scenarios
3. **Gold standard versioning** - Track changes over time
4. **Community contributions** - Allow users to submit gold standard candidates

---

*Context created for epic-45 sprint planning*
