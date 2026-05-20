# Epic 44: Multi-Judge Validation

## Overview

Replace single LLM-as-judge evaluation with ensemble multi-judge scoring to improve benchmark reliability. Each agent run is scored by N independent judge invocations with randomized presentation order, producing inter-rater agreement metrics (Krippendorff's Alpha, Cronbach's Alpha) alongside aggregated scores.

**Priority:** P0
**Repo:** pennyfarthing
**Stories:** 4 (10 points)
**Jira:** PROJ-16214

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **Old epic context** (`sprint/context/context-epic-44.md`) | Full technical spec — Krippendorff formula, implementation plan, storage format, test protocol |
| **persona-effectiveness.md** (`pennyfarthing-dist/guides/persona-effectiveness.md`) | §Ensemble Judging — Galileo error rates, proven mitigations, PersonaGym ensemble approach |
| **measurement-framework.md** (`pennyfarthing-dist/guides/measurement-framework.md`) | Wallach four-level framework — reliability evidence requirements |

## Background

### The Single-Judge Reliability Problem

Current benchmarking uses a single LLM-as-judge invocation per agent run. Research (Galileo AI Framework) documents error rates exceeding 50% in single LLM judges, driven by position bias, length bias, and agreeableness bias. This means our existing benchmark scores have unknown reliability — a score of 78 could easily be 65 or 90 with a different judge invocation.

### Research Basis

PersonaGym (EMNLP 2025 Findings) uses multi-evaluator ensemble scoring as standard practice. The Galileo framework recommends a 3-tier rubric taxonomy with ensemble judging and minority-veto for safety-critical findings. CharacterEval (ACL 2024) demonstrated that domain-specific reward models beat GPT-4 as a single judge across 13 metrics. The consensus across 2024-2026 literature is clear: single-judge evaluation is insufficient for reliable measurement.

### Why This Is P0

Without reliable measurement, all other benchmark improvements (anchored rubrics PROJ-16210, gold standards PROJ-16212, false positive traps PROJ-16211) rest on an unreliable foundation. Multi-judge validation is the prerequisite that makes the entire measurement stack trustworthy.

### Evolution from Epic 44

This epic updates the original epic 44 design with research-informed changes:
- **Randomized presentation order** (not prompt variations) to control position bias
- **Krippendorff's Alpha on dimension scores** (1-10) not just totals (1-100)
- **Cronbach's Alpha** added for internal consistency
- **Per-dimension agreement reporting** to identify unreliable rubric dimensions
- **TypeScript implementation** in `packages/core/` (not Python as originally planned)

## Technical Architecture

### Current Judge Flow

```
/solo → Execute agent → /judge (single) → /finalize-run → Save
```

### Multi-Judge Flow

```
/solo --multi-judge 3 → Execute agent → /judge ×3 (parallel, randomized order) → Aggregate (mean + Alpha) → /finalize-run → Save
```

### Key Files

| File | Purpose | Story |
|------|---------|-------|
| `pennyfarthing-dist/skills/pf-judge/SKILL.md` | Add `--judges N` parameter | 44-1 |
| `pennyfarthing-dist/commands/pf-solo.md` | Wire `--multi-judge` flag | 44-1 |
| `packages/core/src/benchmark/job-fair-aggregator.ts` | Add Krippendorff's Alpha, Cronbach's Alpha | 44-2 |
| `packages/core/src/benchmark/benchmark-integration.ts` | Agreement reporting | 44-2 |
| `packages/core/src/benchmark/index.ts` | Export new functions | 44-2 |
| `pennyfarthing-dist/skills/pf-finalize-run/SKILL.md` | Validate judge arrays, agreement metrics | 44-3 |
| `internal/results/multi-judge-validation/` | Validation test results | 44-4 |

### Storage Format (Multi-Judge)

```
internal/results/benchmarks/{scenario}/{theme}-{role}/
├── summary.yaml           # Includes multi_judge.reliability section
├── runs/
│   ├── run_1.json         # Agent response
│   ├── judge_1_0.json     # Judge invocation 0
│   ├── judge_1_1.json     # Judge invocation 1
│   ├── judge_1_2.json     # Judge invocation 2
```

### Agreement Thresholds

| Alpha | Classification | Action |
|-------|---------------|--------|
| >= 0.80 | Reliable | High confidence |
| 0.67-0.79 | Acceptable | Standard confidence |
| < 0.67 | Unreliable | Flag dimension, recommend rubric revision |

### Story Dependencies

- 44-1 and 44-2 can run in parallel
- 44-3 depends on 44-1 (needs multi-judge data structure)
- 44-4 depends on all three (needs full system working)

## Cross-Epic Dependencies

**Depends on:**
- PROJ-16127 (Tech Debt Audit) — clean benchmark infrastructure baseline

**Depended on by:**
- PROJ-16210 (Anchored Rubric Criteria) — multi-judge reveals which dimensions need better anchoring
- PROJ-16212 (Gold Standard References) — multi-judge validates whether gold standards improve agreement
- PROJ-16211 (False Positive Traps) — multi-judge measures whether red herrings cause judge disagreement
- PROJ-16213 (Difficulty Profile Enhancement) — multi-judge agreement varies by difficulty tier
