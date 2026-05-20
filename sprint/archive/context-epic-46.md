# Epic 46: Difficulty Profile Enhancement

## Overview

Add structured difficulty metadata to benchmark scenarios so results can be stratified by difficulty tier. Enables analysis of how agent performance and judge agreement vary across easy, medium, hard, and extreme scenarios.

**Priority:** P2
**Repo:** pennyfarthing
**Stories:** 3 (5 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **persona-effectiveness.md** (`pennyfarthing-dist/guides/persona-effectiveness.md`) | §6 Context Collapse — personas drop under cognitive load; difficulty stratification measures this |
| **measurement-framework.md** (`pennyfarthing-dist/guides/measurement-framework.md`) | Wallach L3 — operationalization includes controlling for confounding variables like difficulty |

## Background

### The Difficulty Confound

Current benchmarks don't formally track scenario difficulty. A mean score of 75 on "easy" scenarios means something very different from 75 on "hard" scenarios. Without difficulty metadata, we can't tell whether a persona helps on hard problems (where it matters most) or only on easy ones (where any approach works).

### Research Basis

Context collapse research [48] shows that personas abandon character-specific reasoning under high cognitive load. Difficulty profiling lets us measure this directly: does persona adherence (judge dimension) drop as difficulty increases? The persona effectiveness research also shows that expert personas provide no consistent benefit on PhD-level benchmarks [15] — difficulty stratification tests whether this holds in our specific benchmark scenarios.

### Calibration from Baseline Data

Rather than manually assigning difficulty, profiles are populated from existing baseline data — scenarios where control agents score high are "easy," scenarios with high variance or low mean scores are "hard." This empirical approach avoids subjective difficulty assignment.

## Technical Architecture

### Schema Extension

Add `difficulty_profile` field to scenario YAML:

```yaml
scenario:
  name: order-service-review
  difficulty_profile:
    tier: medium          # easy | medium | hard | extreme
    dimensions:
      code_complexity: 6  # 1-10
      domain_knowledge: 4 # 1-10
      red_herring_count: 2
      issue_subtlety: 5   # 1-10
    calibration:
      control_mean: 72.5
      control_stddev: 8.3
      n_runs: 4
```

### Key Files

| File | Purpose | Story |
|------|---------|-------|
| Scenario YAML schema | Add `difficulty_profile` field | 46-1 |
| Existing scenario files | Populate profiles from baseline data | 46-2 |
| `pennyfarthing-dist/schemas/` | Document new fields | 46-3 |

### Tier Assignment Algorithm

```
easy:    control_mean >= 80, control_stddev < 8
medium:  control_mean 65-79, control_stddev < 12
hard:    control_mean 50-64 OR control_stddev >= 12
extreme: control_mean < 50
```

## Cross-Epic Dependencies

**Depends on:**
- PROJ-16214 (Multi-Judge Validation) — agreement metrics vary by difficulty; need multi-judge data to measure this
- PROJ-16210 (Anchored Rubric Criteria) — anchored rubrics may need difficulty-aware calibration
- PROJ-16211 (False Positive Traps) — red herring count is a difficulty dimension
- PROJ-16212 (Gold Standard References) — gold standard scores contribute to difficulty calibration

**Depended on by:**
- (None in current sprint — this is a terminal node in the dependency chain)
