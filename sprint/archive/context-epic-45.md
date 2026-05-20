# Epic 45: Gold Standard References

## Overview

Create curated "gold standard" reference responses for benchmark scenarios. Judges use these as calibration anchors — comparing agent output against a known-good response to reduce score drift and central tendency bias.

**Priority:** P2
**Repo:** pennyfarthing
**Stories:** 4 (8 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **persona-effectiveness.md** (`pennyfarthing-dist/guides/persona-effectiveness.md`) | §Measurement Methodologies — calibrated exemplars, LLM-as-Judge limitations |
| **measurement-framework.md** (`pennyfarthing-dist/guides/measurement-framework.md`) | Wallach L3-L4 — operationalization and scoring reliability |

## Background

### The Calibration Drift Problem

Without a reference point, LLM judges score relative to their own internal standards, which shift between invocations and model versions. A response that scores 80 today might score 72 tomorrow with the same judge prompt. Gold standard references anchor the evaluation — "here's what a 9/10 looks like for this scenario."

### Research Basis

PersonaGym generates exemplar responses at each score level as calibration anchors. The Galileo framework uses minority-veto where any judge can flag deviations from established standards. CharacterEval (ACL 2024) trains domain-specific reward models on curated reference data, achieving higher agreement than uncalibrated GPT-4 judging.

### Approach

Gold standards are human-curated (or human-validated best-of-N) responses stored alongside scenarios. The judge prompt includes the gold standard as a reference point: "Here is an expert-level response for this scenario. Use it to calibrate your scoring."

## Technical Architecture

### Schema Extension

Add `gold_standard` field to scenario YAML:

```yaml
scenario:
  name: order-service-review
  gold_standard:
    response: |
      [curated expert response]
    score: 92
    notes: "Identifies race condition, suggests mutex pattern, covers edge cases"
```

### Key Files

| File | Purpose | Story |
|------|---------|-------|
| Scenario YAML schema | Add `gold_standard` field | 45-1 |
| `pennyfarthing-dist/skills/pf-judge/SKILL.md` | Reference gold standard in judge prompt | 45-2 |
| 5 scenario YAML files | Curated gold standard responses | 45-3 |
| `internal/results/` | With/without gold standard comparison | 45-4 |

### Validation Approach

Story 45-4 compares judge variance with and without gold standard references on the same 5 scenarios. Expected: reduced score variance and higher inter-judge agreement (if multi-judge is available).

## Cross-Epic Dependencies

**Depends on:**
- PROJ-16214 (Multi-Judge Validation) — multi-judge measures whether gold standards improve agreement
- PROJ-16210 (Anchored Rubric Criteria) — anchored rubrics define what scores mean; gold standards exemplify them

**Depended on by:**
- PROJ-16213 (Difficulty Profile Enhancement) — gold standard scores contribute to difficulty calibration
