---
parent: context-epic-45.md
workflow: tdd
---

# Story 45-3: Create gold standards for 5 high-variance scenarios

## Business Context

Gold standard responses need to be curated for scenarios where scoring is most inconsistent. High-variance scenarios benefit most from calibration anchors because that's where judges disagree most. This story creates expert-quality reference responses for the 5 scenarios with highest score variance in existing baselines.

## Technical Guardrails

**Selection criteria:**
- Sort scenarios by std_dev of existing baseline scores (descending)
- Select top 5 — these are where calibration will have the most impact
- May overlap with scenarios selected for 44-4 (multi-judge validation)

**Gold standard quality:**
- Human-curated or best-of-N with human validation
- Must be genuinely expert-level — not just "good enough"
- Include reasoning, not just conclusions
- Score assigned by human reviewer using anchored rubric (from MSSCI-16210 if available)

**Do NOT:**
- Use LLM-generated gold standards without human review
- Create gold standards for easy/low-variance scenarios (low impact)

## Scope Boundaries

**In scope:**
- 5 gold standard responses for high-variance scenarios
- Each with response text, score, and notes explaining quality
- Added to scenario YAML files using schema from 45-1

**Out of scope:**
- Gold standards for all scenarios (5 is the pilot set)
- Automated gold standard generation
- Variance measurement (45-4)

## AC Context

**AC: 5 scenarios selected by variance**
- Test: Selected scenarios have the 5 highest std_dev values in baseline data
- Selection documented with actual variance numbers

**AC: Each gold standard includes response, score, and notes**
- Test: All 5 scenario YAMLs validate with gold_standard field
- Response is substantive (not a stub)
- Score reflects honest expert assessment
- Notes explain what makes this response gold-standard quality
