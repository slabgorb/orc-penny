# Epic 41: Precision/Recall Detection Scoring

## Overview

Separate detection scoring into precision and recall components to make evaluation trade-offs explicit and measurable. The current formula conflates finding issues (recall) with avoiding false positives (precision), obscuring important distinctions in agent behavior.

**Epic ID:** epic-41
**Points:** 8
**Priority:** P1
**Marker:** benchmark
**Repos:** pennyfarthing
**Status:** planning

## Goals

1. Replace the conflated detection formula with separate precision/recall metrics
2. Make the recall vs. precision trade-off explicit and transparent
3. Provide more diagnostic insight into agent behavior
4. Align with HELM benchmark methodology (Stanford CRFM)
5. Support the measurement framework from Wallach et al. (2025)

## Framework Alignment

This is a **Level 4 improvement** in the measurement framework:
- Separates scores for distinct constructs (finding issues vs. avoiding false alarms)
- Addresses the anti-pattern of "conflating operationalization with construct"
- Makes it clear when an agent is aggressive (high recall, lower precision) vs. conservative (high precision, lower recall)

## Technical Approach

### Current Detection Formula (v1 - Legacy)

The original formula used weighted sums with a false positive penalty:

```
detection = (criticals × 15) + (highs × 10) + (mediums × 5) + (lows × 2) + (novel × 5) - (false_positives × 5)
```

**Problems:**
- Single score hides whether agent is missing issues vs. hallucinating
- False positive penalty is arbitrary (why 5 points?)
- Hard to compare agents with different recall/precision profiles
- Novel findings treated identically to baseline findings

### New Detection Formula (v2 - Precision/Recall)

Two separate metrics, each measuring a distinct construct:

```
precision = true_positives / (true_positives + false_positives)
recall = weighted_found / weighted_total

precision_score = precision × 25  (max 25 pts)
recall_score = recall × 25        (max 25 pts)

detection.subtotal = precision_score + recall_score
```

**Note:** The current SKILL.md shows a 30/10 split favoring recall. The epic proposes a balanced 25/25 split. Story 41-1 should evaluate which weighting is more appropriate:
- 30/10 split: Emphasizes finding issues over avoiding false alarms
- 25/25 split: Treats both constructs as equally important
- Alternative: F2 score weighting (recall weighted 4x precision)

### Supporting Metrics

```
f2_score = 5 × (precision × recall) / (4 × precision + recall)
```

The F2 score provides a single number when needed but should not replace the separate precision/recall metrics in primary reporting.

### Severity Weighting for Recall

Recall is weighted by issue severity:

| Severity | Weight |
|----------|--------|
| Critical | 15 |
| High | 10 |
| Medium | 5 |
| Low | 2 |

```
weighted_found = sum(found_issues × severity_weight)
weighted_total = sum(all_baseline_issues × severity_weight)
recall = weighted_found / weighted_total
```

## Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing/pennyfarthing-dist/skills/judge/SKILL.md` | Update checklist rubric formula (lines 179-332) |
| Benchmark result files | Update JSON output format |
| Analysis scripts | Update to read new schema |

### Primary File: SKILL.md

Path: `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/skills/judge/SKILL.md`

Key sections to update:
- **Solo Mode Prompt (Checklist Rubric v2)** (lines 177-277): Update detection scoring rules
- **Detection Scoring Deep Dive** (lines 279-332): Clarify formula and rationale
- **JSON output format**: Ensure schema matches story 41-2 requirements

## JSON Output Schema

### Current Schema (lines 213-260 in SKILL.md)

```json
{
  "detection": {
    "by_severity": {
      "critical": {"found": 5, "total": 6},
      "high": {"found": 4, "total": 6},
      "medium": {"found": 3, "total": 8},
      "low": {"found": 1, "total": 2}
    },
    "novel_valid": 2,
    "false_positive_count": 1,
    "metrics": {
      "weighted_found": 98,
      "weighted_total": 120,
      "recall": 0.817,
      "precision": 0.929,
      "f2_score": 0.843
    },
    "components": {
      "recall_score": 24.5,
      "precision_score": 9.3,
      "novel_bonus": 6.0
    },
    "subtotal": 39.8
  }
}
```

### Target Schema (from story 41-2)

```json
{
  "detection": {
    "true_positives": 8,
    "false_positives": 1,
    "total_baseline": 10,
    "precision": 0.89,
    "recall": 0.80,
    "precision_score": 22.2,
    "recall_score": 20.0,
    "subtotal": 42.2
  }
}
```

**Note:** The current schema is more detailed. Story 41-2 should consider whether to simplify or keep the detailed breakdown. Recommendation: Keep `by_severity` and `metrics` for diagnostic purposes; add `true_positives`/`false_positives` counts.

## Story-by-Story Technical Notes

### Story 41-1: Update judge SKILL.md with precision/recall formula (3 pts)

**Objective:** Replace detection scoring section with balanced precision/recall formula.

**Technical tasks:**
1. Update "Detection Scoring Rules" section (line 263-274)
2. Change weighting from 30/10/10 (recall/precision/novel) to 25/25 or justified alternative
3. Update the JSON output format in the prompt template
4. Remove or repurpose novel_bonus (consider: keep as separate metric, not added to subtotal)
5. Update example calculations section (lines 307-322)

**Key decision:** Should novel findings bonus be removed entirely, kept as diagnostic metric, or incorporated into precision/recall? Recommendation: Remove from subtotal but keep as diagnostic field.

**Acceptance criteria:**
- Checklist rubric prompt uses precision/recall formula
- Formula is documented with clear rationale
- Example calculations are updated and verified

### Story 41-2: Update judge JSON output schema (2 pts)

**Objective:** Define and implement the new detection output format.

**Technical tasks:**
1. Define canonical schema with TypeScript types (if applicable)
2. Update SKILL.md JSON examples
3. Ensure backward compatibility or document breaking changes
4. Add `true_positives` and `false_positives` counts explicitly

**Schema design decisions:**
- Keep `by_severity` breakdown for diagnostic purposes
- Add explicit TP/FP counts (currently only `false_positive_count` exists)
- Consider adding `total_findings` for easy precision calculation

**Acceptance criteria:**
- JSON schema is documented in SKILL.md
- Schema includes all metrics needed to reconstruct precision/recall
- Breaking changes (if any) are documented

### Story 41-3: Regression test comparing new vs old scores (3 pts)

**Objective:** Validate the new formula doesn't dramatically alter rankings.

**Technical tasks:**
1. Collect existing benchmark results (ideally 20+ runs across different agents/scenarios)
2. Calculate scores under both formulas
3. Compute correlation (target: r > 0.9)
4. Identify any ranking inversions and analyze causes
5. Document any systematic biases introduced or removed

**Test scenarios to include:**
- High recall / low precision agent (aggressive finder)
- High precision / low recall agent (conservative finder)
- Balanced agent
- Agent with many novel findings
- Agent with zero false positives

**Acceptance criteria:**
- Correlation between old and new scores > 0.9
- Any ranking inversions are explained and justified
- Results documented with analysis

## Success Criteria

1. **Formula clarity:** Precision and recall are separate, visible metrics
2. **Diagnostic value:** Can easily identify aggressive vs. conservative agents
3. **Stability:** New scores correlate > 0.9 with old scores
4. **Documentation:** SKILL.md fully documents the new approach
5. **Schema stability:** JSON output is backward-compatible or migration path documented

## Metrics

| Metric | Target | Rationale |
|--------|--------|-----------|
| Old/new score correlation | > 0.9 | Stability |
| Inter-judge agreement (if multi-judge) | Krippendorff's Alpha > 0.65 | Reliability |
| False positive detection rate | Measurable per agent | Diagnostic value |

## Dependencies

- No external dependencies
- Story 41-1 must complete before 41-2 (schema follows formula)
- Story 41-3 depends on having benchmark data available

## Research References

- **HELM Benchmark Methodology** (Stanford CRFM): Separates evaluation into multiple metrics rather than single scores
- **Wallach et al. (2025)**: "Position: Evaluating Generative AI Systems Is a Social Science Measurement Challenge" (ICML 2025)
- **Measurement Framework Guide**: `pennyfarthing-dist/guides/measurement-framework.md`

## Open Questions

1. **Weighting decision:** Should precision/recall be 25/25 (equal) or keep current 30/10 (recall-favored)?
2. **Novel findings:** Should novel_bonus remain in subtotal or become diagnostic-only?
3. **Backward compatibility:** Is breaking the JSON schema acceptable, or should we support both formats?
4. **Severity weighting:** Should precision also be severity-weighted (penalize false positives on critical issues more)?
