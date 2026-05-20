# Epic 42: Anchored Rubric Criteria

## Overview

Replace abstract scoring guidelines with behaviorally anchored rubric scales. Each score level (1-10) on each dimension gets concrete behavioral exemplars so judges evaluate consistently against observable behaviors rather than subjective impressions.

**Priority:** P0
**Repo:** pennyfarthing
**Stories:** 3 (6 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **persona-effectiveness.md** (`pennyfarthing-dist/guides/persona-effectiveness.md`) | §Measurement Methodologies — PersonaScore calibrated exemplars, ensemble judging research |
| **measurement-framework.md** (`pennyfarthing-dist/guides/measurement-framework.md`) | Wallach L3 Operationalization — rubric design principles |
| **Old epic context** (`sprint/context/context-epic-44.md`) | Prompt variations concept — precursor to anchored rubrics |

## Background

### The Scoring Ambiguity Problem

Current judge rubrics describe dimensions (correctness, depth, quality, persona) with general guidance but lack concrete anchors for what constitutes a 3 vs a 5 vs an 8. This creates inconsistency — different judge invocations (or different models) interpret "moderate depth" differently. PersonaGym addresses this by generating exemplar responses at each score level.

### Research Basis

The Galileo AI framework defines a 3-tier rubric taxonomy (7 top-level → 25 mid-level → 130 specific criteria) demonstrating that granular, anchored criteria reduce inter-rater disagreement. PersonaGym (EMNLP 2025) achieves 75% Spearman correlation with human judges by calibrating exemplar responses at each score level. Without anchors, LLM judges default to central tendency (scores cluster around 6-7).

### Why This Is P0

Anchored rubrics are the second-highest priority after multi-judge validation. Even with multiple judges, if the rubric is ambiguous, judges will disagree for the wrong reasons — not because the construct is complex, but because the scale is unclear. Anchored rubrics reduce this measurement noise.

## Technical Architecture

### Deliverable: rubric-anchors.md

A new guide document at `pennyfarthing-dist/guides/rubric-anchors.md` containing behavioral scales for each judge dimension:

```
Dimension: Correctness (1-10)
  1-2: Response contains factual errors or misidentifies the problem
  3-4: Identifies the problem but proposed solution has significant gaps
  5-6: Correct identification and reasonable solution with minor gaps
  7-8: Accurate analysis with comprehensive solution covering edge cases
  9-10: Expert-level analysis, identifies non-obvious issues, solution is production-ready
```

### Key Files

| File | Purpose | Story |
|------|---------|-------|
| `pennyfarthing-dist/guides/rubric-anchors.md` | Behavioral scale definitions | 42-1 |
| `pennyfarthing-dist/skills/pf-judge/SKILL.md` | Reference anchors in judge prompts | 42-2 |
| `internal/results/` | CV comparison data | 42-3 |

### Validation Approach

Story 42-3 measures coefficient of variation (CV) before and after anchoring on the same scenarios. Expected: CV reduction of 15-30% on dimension scores.

## Cross-Epic Dependencies

**Depends on:**
- PROJ-16214 (Multi-Judge Validation) — multi-judge data reveals which dimensions have highest disagreement, prioritizing anchor development

**Depended on by:**
- PROJ-16212 (Gold Standard References) — anchored rubrics inform what "correct" scoring looks like for gold standards
- PROJ-16213 (Difficulty Profile Enhancement) — anchored rubrics may need difficulty-aware calibration
