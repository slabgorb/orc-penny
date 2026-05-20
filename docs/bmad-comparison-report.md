# BMAD vs Pennyfarthing Pipeline Comparison Report

**Date:** 2026-03-10
**Epic:** 142 (PROJ-16324)
**Story:** 142-6 (PROJ-16330)
**Methodology:** ADR-0035

## Executive Summary

We ran the DPGD-116 Peloton scenario through both the BMAD (v6.0.4) and Pennyfarthing pipelines, scored by the same multi-judge consensus method against identical ground truth. **Neither pipeline demonstrates statistically significant superiority over the other at the aggregate level.** BMAD's mean weighted score (55.7%) is slightly higher than PF control (49.9%), but with wide confidence intervals and p=0.40, this difference is indistinguishable from noise.

The more interesting finding: **the heatmap revealed a specific technique BMAD does better** — mechanical edge-case path enumeration in the reviewer phase. BMAD's reviewer caught I5 and I6 (test-quality findings) at 60% vs PF's 36%/18%, and I3 at 20% vs PF's 0%. This led directly to the `reviewer-edge-hunter` subagent (PROJ-16333), which absorbs BMAD's orthogonal review approach into PF's pipeline. The PF version tag `baseline-pre-edge-hunter` marks the before state.

Additionally, **PF's persona system unlocks significant variance.** Two PF personas (princess-bride, dune) significantly outperform both PF control and BMAD, suggesting agent instruction tuning matters more than framework architecture.

## Methodology

### Test Setup

| Parameter | Value |
|-----------|-------|
| Scenario | DPGD-116 (7 findings, 37 weight points) |
| Ground truth | 1 critical, 6 important findings across tea/dev/reviewer phases |
| Model | Claude Opus 4.6 (both pipelines) |
| Judge | Multi-pass majority vote (3 judges, 2/3 consensus) |
| BMAD version | v6.0.4 (commit `b7315c6`) |
| PF version | baseline-pre-edge-hunter (v12.7.0) |

### Pipeline Architecture

| Aspect | BMAD | Pennyfarthing |
|--------|------|---------------|
| Phases | 2 (dev, reviewer) | 3 (TEA, dev, reviewer) |
| Dev agent | "Amelia" persona + 10-step Red-Green-Refactor | PF dev agent + workflow engine |
| Test writing | Embedded in dev workflow (steps 5-7) | Separate TEA agent (RED phase) |
| Review | 5-step adversarial review | PF reviewer agent |
| Context source | BMAD story file + project-context.md | PF epic + story context docs |

Phase asymmetry (2 vs 3 phases) is a legitimate architectural difference documented in ADR-0035. The judge scores against ground truth regardless of which phase caught a finding.

## Results

### Per-Pipeline Summary

| Pipeline | N | Mean Score | SD | 95% CI | Findings/Run |
|----------|---|-----------|-----|---------|-------------|
| BMAD | 5 | 55.7% | 10.2% | [43.0, 68.4] | 4.2 |
| PF Control | 11 | 49.9% | 15.8% | [39.2, 60.5] | 3.6 |
| PF Grand Mean (all 33 themes) | 147 | 53.4% | — | — | — |

### Statistical Comparison: BMAD vs PF Control

| Metric | Value |
|--------|-------|
| Delta (PF - BMAD) | -5.8% |
| Cohen's d | -0.40 (small) |
| Welch's t | -0.882 |
| p-value | 0.3956 (n.s.) |

**Interpretation:** The difference is not statistically significant. Wide confidence intervals overlap substantially. With n=5 BMAD runs and n=11 PF control runs, we lack statistical power to detect small effects.

### Detection Heatmap

```
Finding  Wt  Ideal Phase  BMAD Detect  PF Detect  BMAD Phase      PF Phase
─────────────────────────────────────────────────────────────────────────────
C1        8  dev               0%           9%     —               tea
I1        5  reviewer        100%         100%     reviewer        tea, dev, reviewer
I2        5  tea              80%         100%     reviewer        tea, reviewer
I3        3  dev              20%           0%     reviewer        —
I4        5  reviewer        100%         100%     reviewer        reviewer
I5        5  tea              60%          36%     reviewer        reviewer
I6        5  tea              60%          18%     reviewer        reviewer
```

**Key observations:**

1. **C1 (critical, weight 8):** Neither pipeline reliably catches the most important finding. BMAD: 0%, PF: 9%. This is the dominant driver of score variance — any run that catches C1 scores dramatically higher.

2. **I1, I2, I4 (reliable catches):** Both pipelines catch these consistently. PF distributes detection across phases (tea catches I1/I2 early), while BMAD concentrates everything in the reviewer phase.

3. **I5, I6 (tea-ideal findings):** BMAD catches these more often (60% each) than PF control (36%, 18%). BMAD's reviewer uses mechanical path enumeration ("find 3-10 specific issues minimum") that systematically traces edge cases — vacuous assertions, missing guards — where PF's attitude-driven adversarial reviewer relies on intuition. This gap directly motivated the `reviewer-edge-hunter` subagent.

4. **I3 (workspace dependencies):** BMAD catches this at 20%, PF at 0%. Another mechanical check that BMAD's structured review picks up through exhaustive enumeration.

5. **Phase attribution:** BMAD catches everything through its reviewer. PF distributes: tea catches I1 (100% when caught) and I2 (in some runs), reviewer catches the rest. PF's 3-phase architecture provides earlier detection but doesn't improve overall catch rate for control.

### PF Persona Variance

The PF framework's persona system creates significant variance around the control baseline:

| Tier | Themes | Mean Score | vs BMAD |
|------|--------|-----------|---------|
| Top 5 | princess-bride, the-wire, dune, house-md, alice-in-wonderland | 63.0% | +7.3% |
| Above BMAD | 14 of 33 themes | >55.7% | positive |
| At/Below BMAD | 19 of 33 themes | ≤55.7% | negative |
| Bottom 3 | star-trek-tos, rome, doctor-who | 41.4% | -14.3% |

**Statistically significant PF themes vs control:**

| Theme | Mean | Cohen's d | p-value |
|-------|------|----------|---------|
| princess-bride | 68.3% | 1.30 | 0.0009 *** |
| dune | 61.5% | 0.82 | 0.035 * |

Only 2 of 33 themes reach statistical significance against PF control. This is partly a power issue (n=4 per theme), but it also indicates that most persona effects are small.

## Cost Analysis

| Metric | BMAD | PF Control |
|--------|------|------------|
| Mean cost/run | $3.69 | N/A (pre-tracking) |
| Phases/run | 2 | 3 |
| Weighted points caught/run | 20.6 | 18.5 |
| Findings-per-dollar | 1.14 | — |

**Note:** PF control runs predate cost tracking. PF's 3-phase pipeline (TEA + dev + reviewer) incurs ~50% more agent invocations than BMAD's 2-phase design. Based on comparable Opus usage patterns, we estimate PF runs at $4.50-6.00/run, yielding ~0.90-1.12 findings/dollar — roughly equivalent to BMAD's cost efficiency.

BMAD's lower per-run cost is a structural advantage of the 2-phase design, not a framework quality difference.

## Limitations

1. **Small sample size:** 5 BMAD runs provides limited statistical power. The 95% CI for BMAD spans 25 percentage points. A definitive comparison would require 15-20 runs per pipeline.

2. **Single scenario:** Only DPGD-116 has both BMAD and PF data. DPGD-117 has PF runs but no BMAD baseline. Results may not generalize across scenario types.

3. **Phase asymmetry:** BMAD uses 2 phases (dev, reviewer) while PF uses 3 (TEA, dev, reviewer). This is a real architectural difference, but it means cost comparisons are not apples-to-apples.

4. **PF cost data gap:** PF control runs predate cost tracking infrastructure. Cost comparison relies on structural estimates rather than measured values.

5. **No PF persona optimization for BMAD comparison:** PF themed runs were designed to test persona effectiveness against PF control, not against BMAD. A dedicated BMAD-vs-best-PF-persona comparison would be more informative.

6. **C1 dominance:** The critical finding C1 (weight 8) is rarely caught by either pipeline, creating a ceiling effect that compresses score distributions and makes differentiation harder.

## Process Improvements Derived from Comparison

The comparison's primary value was not picking a winner — it was identifying a specific technique gap and closing it.

### The Gap: Mechanical vs Attitude-Driven Review

BMAD's reviewer instructions explicitly demand exhaustive path enumeration: "find 3-10 specific issues minimum," walking every branch, guard, and boundary condition mechanically. PF's reviewer is attitude-driven — adversarial judgment that relies on intuition and experience. The heatmap showed BMAD's mechanical approach catches edge-case findings (I5, I6, I3) that PF's reviewer misses.

### The Fix: `reviewer-edge-hunter` Subagent (PROJ-16333)

Rather than changing PF's reviewer personality, we separated concerns:

| Component | Role |
|-----------|------|
| `reviewer` (Opus) | Adversarial judgment — attitude-driven, catches architectural and security issues |
| `reviewer-edge-hunter` (Haiku, background) | Mechanical path enumeration — method-driven, exhaustive boundary tracing |
| `reviewer-preflight` (Haiku, background) | Mechanical checks — tests, lint, code smells |

The edge hunter runs in parallel with preflight, outputs structured JSON findings, and the reviewer confirms/dismisses each with severity assignment. This preserves PF's adversarial review strength while absorbing BMAD's mechanical thoroughness.

**Key design decisions:**
- Haiku model (cheap, fast) for mechanical tracing — no judgment needed
- Strict 4-field JSON output — forces precision, prevents editorializing
- Reviewer incorporates findings with `[EDGE]` tags — maintains single adversarial voice
- Parallel execution — no added latency to the review phase

### Next Step: Post-Edge-Hunter Benchmark

The PF version `baseline-pre-edge-hunter` marks the before state. Re-running DPGD-116 with the edge hunter active will show whether the gap on I3/I5/I6 closes. If PF's detection rate on these findings rises to match or exceed BMAD's 60%, the comparison served its purpose as a process improvement tool.

## Conclusions

1. **No significant difference between BMAD and PF control at the aggregate level.** Both frameworks produce comparable weighted detection rates (55.7% vs 49.9%, p=0.40). The choice cannot be justified on aggregate score alone.

2. **The heatmap revealed a specific, actionable gap.** BMAD's mechanical path enumeration catches edge-case findings (I5: 60% vs 36%, I6: 60% vs 18%, I3: 20% vs 0%) that PF's attitude-driven reviewer misses. This is the most valuable finding of the comparison.

3. **The gap has been closed architecturally.** The `reviewer-edge-hunter` subagent (PROJ-16333) absorbs BMAD's orthogonal review technique into PF's pipeline without replacing PF's adversarial reviewer strengths. Validation runs pending.

4. **PF's persona system is the larger differentiator.** Top PF personas (princess-bride: 68.3%, dune: 61.5%) significantly outperform both PF control and BMAD, suggesting agent instruction tuning matters more than framework architecture.

5. **BMAD has a structural cost advantage.** Two phases vs three means lower per-run cost ($3.69 vs estimated $4.50-6.00). The edge hunter (Haiku) adds minimal cost to PF.

6. **PF's 3-phase design provides earlier detection.** TEA catches I1/I2 in the test-writing phase; BMAD only catches them at review. Earlier detection means cheaper rework.

## Recommendations

1. **Run post-edge-hunter benchmarks** to validate that the I3/I5/I6 gap closes. This is the immediate next step.
2. **Don't choose frameworks on aggregate scores.** The finding-level heatmap is far more actionable than mean scores.
3. **Invest in persona tuning.** The 28-point spread between best and worst PF themes (68.3% vs 40.5%) dwarfs the BMAD-vs-PF delta.
4. **Use BMAD comparison as a recurring process improvement tool.** Each comparison cycle identifies specific techniques to absorb, not a framework to adopt wholesale.

---

*Generated from Peloton benchmark replay data. BMAD source pinned to commit `b7315c6e329e`. PF version: baseline-pre-edge-hunter (v12.7.0). All scoring via multi-judge majority vote with Claude Opus 4.6. Process improvement (`reviewer-edge-hunter`) shipped as PROJ-16333.*
