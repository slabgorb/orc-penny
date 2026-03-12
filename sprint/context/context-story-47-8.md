# Story 47-8: Question Quality Instrumentation — PM Research Patterns

## Overview

Instrument PM persona behavior during context generation to measure research question quality. Different personas may ask different types of questions during planning — this story captures and scores those patterns.

**Points:** 3 | **Workflow:** tdd | **Jira:** MSSCI-16301
**Priority:** P3 — exploratory, pursue if capacity allows

## Objective

When a PM generates context, they implicitly "ask questions" about the codebase: What are the security concerns? What's the error handling strategy? How are inputs validated? The quality and coverage of these implicit questions determines context quality. This story makes those questions explicit and measurable.

## Approach

### Instrumentation

1. Modify context generation to log PM "research questions" as structured output
2. Capture: question text, question category (security, architecture, domain, testing), specificity (generic vs codebase-specific)
3. Run across 3 themes (same as 47-3) to compare question patterns

### Question Quality Rubric

| Dimension | 1 (Poor) | 3 (Adequate) | 5 (Excellent) |
|-----------|----------|-------------|---------------|
| **Relevance** | Generic software questions | Domain-appropriate | Scenario-specific |
| **Depth** | Surface-level | Explores trade-offs | Anticipates failure modes |
| **Coverage** | Single concern area | Multiple areas | Maps to full concern manifest |
| **Actionability** | Abstract worries | Suggests investigation areas | Frames as testable hypotheses |

### Analysis

- Question count and category distribution per theme
- Quality scores per theme
- Correlation: do better questions predict better context docs (from 47-5)?
- Pattern identification: which persona traits drive question quality?

## Acceptance Criteria

- [ ] Question capture mechanism implemented
- [ ] 3 themed PM runs with questions logged
- [ ] Question quality scoring against rubric
- [ ] Correlation analysis with context doc scores (if 47-5 data available)
- [ ] Results in `internal/results/pm-question-patterns-dpgd-116.md`

## Dependencies

- 47-3 (PM context generation — this story instruments that process)
- 47-5 (correlation data, optional)
