# Epic 47: Strategic Role Benchmarking (PM & Architect)

## Overview

Extend peloton-style benchmarking beyond the TEA→Dev→Reviewer pipeline to evaluate PM and Architect personas. These strategic roles produce context documents (epic context, story context) that shape downstream pipeline behavior. This epic measures whether persona choice at the strategic level affects pipeline outcomes.

**Priority:** P1
**Repo:** pennyfarthing
**Stories:** 8 (23 points)
**Jira:** PROJ-16293

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **persona-effectiveness.md** (`pennyfarthing-dist/guides/persona-effectiveness.md`) | §2 Multi-persona collaboration — strategic roles add upstream diversity; §5 Irrelevant detail sensitivity — PM/Architect character details may propagate into context docs |
| **measurement-framework.md** (`pennyfarthing-dist/guides/measurement-framework.md`) | Wallach L2-L3 — systematized concept: "does upstream persona choice affect downstream defect detection?" |
| **rubric-anchors.md** (`pennyfarthing-dist/guides/rubric-anchors.md`) | BARS scoring for evaluating context doc quality |
| **dpgd-116 comparison.yaml** (`internal/results/pipeline-replay/dpgd-116/comparison.yaml`) | Existing pipeline results across 20 themes — baseline for A/B experiments |

## Background

### The Strategic Layer Gap

Pipeline-replay benchmarks (dpgd-116/117) measure TEA, Dev, and Reviewer performance. But the PM and Architect produce the context documents that prime these agents — epic context, story context, acceptance criteria, architectural decisions. If a PM persona writes weak ACs, even a strong Reviewer can't catch what wasn't specified.

### Cascade Attribution

Current scoring attributes defect catches to the phase that found them (TEA, Dev, Reviewer). Cascade attribution traces further: which upstream context enabled the catch? If a PM's concern manifest listed "input validation" and the Reviewer caught an injection bug, the PM contributed. This measures strategic role value without running new pipelines.

### Research Basis

The persona-effectiveness research [43] shows multi-persona collaboration outperforms static assignment. The PM and Architect roles add the "task-relevant persona identification" that SPP achieves dynamically — but our system does it structurally through workflow phases. The irrelevant detail sensitivity finding [15] is especially relevant: PM/Architect character voice may inject thematic color into context docs that either helps (by adding creative perspective) or hurts (by adding noise that downstream agents parse as signal).

## Approach: Exploratory, Pivot on Signal

This epic is exploratory. Stories are ordered by cost and information value:

1. **Low-cost analysis** (47-1, 47-2, 47-5): Mine existing data and write reference documents
2. **Medium-cost runs** (47-3, 47-4): Generate context docs from 3 PM + 3 Architect personas
3. **High-cost experiments** (47-6, 47-7, 47-8): Full pipeline A/B and ablation — only if earlier stories show signal

If cascade attribution (47-1) shows no meaningful variance, the expensive experiments can be deprioritized.

## Key Concepts

### Concern Manifest
A structured list of concerns the PM/Architect should flag for a scenario. Analogous to ground truth findings for the pipeline, but at the strategic planning level. Used to score whether context documents address the right issues.

### AC Manifest
The set of acceptance criteria that a well-informed PM would generate for the scenario's story. Scored against generated context docs to measure PM persona quality.

### Context Ablation
Remove specific sections from context documents (architecture decisions, risk notes, domain background) and re-run the pipeline to measure which sections actually affect downstream detection rates.

## Technical Architecture

### Existing Infrastructure

| Component | Path | Role in Epic |
|-----------|------|-------------|
| Pipeline replay | `pf benchmark replay run` | Runs TDD pipeline against scenarios |
| Score YAML | `internal/results/pipeline-replay/*/score.yaml` | Per-run detection results |
| Theme dimensions | `pennyfarthing-dist/personas/themes/*.yaml` | Personality and cultural metadata |
| Context skill | `/pf-context` | Generates epic/story context docs |
| Viz dashboard | `internal/results/benchmark-dashboard.html` | Visualize results by dimension |

### New Artifacts

| Artifact | Purpose | Story |
|----------|---------|-------|
| Cascade attribution analysis | Trace catches to upstream context | 47-1 |
| Concern manifest (dpgd-116) | Ground truth for strategic concerns | 47-2 |
| AC manifest (dpgd-116) | Ground truth for acceptance criteria | 47-2 |
| PM context docs (3 themes) | Generated epic contexts | 47-3 |
| Architect context docs (3 themes) | Generated story contexts | 47-4 |
| Manifest scores | Theme differentiation on strategic quality | 47-5 |
| Ablation results | Section-level impact measurement | 47-6 |
| A/B pipeline results | Full pipeline with/without context | 47-7 |

## Cross-Epic Dependencies

**Depends on:**
- dpgd-116 results (complete — 20 themes, 4 runs each)
- Theme dimension metadata (complete — all 100 themes tagged with slicing dimensions)

**Related:**
- Epic 44 (Multi-Judge Validation) — judge reliability affects all scoring
- Epic 46 (Difficulty Profiles) — difficulty interacts with strategic context value

**Depended on by:**
- (None — this is an exploratory epic that produces signal for future work)
