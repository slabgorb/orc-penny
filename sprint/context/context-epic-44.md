# Epic 44: Multi-Judge Validation

## Overview

- **Epic ID:** 44
- **Title:** Multi-Judge Validation
- **Points:** 10 (3 + 3 + 2 + 2)
- **Priority:** P2
- **Marker:** benchmark
- **Repos:** pennyfarthing
- **Status:** planning

## Vision

Measure judge reliability by running multiple judges with prompt variations. Calculate Krippendorff's Alpha to quantify inter-rater reliability. Flag results when Alpha < 0.65.

**Framework Alignment:** Reliability evidence. Per Wallach et al., "Annotator disagreement is not noise to be averaged away--it is meaningful data about construct complexity." Multi-judge validation quantifies measurement reliability and identifies constructs that need clearer operationalization.

**Research Basis:** Krippendorff's Alpha is standard for inter-rater reliability; 2025 research recommends Gwet's AC2 for skewed data.

## Krippendorff's Alpha

### What It Measures

Krippendorff's Alpha quantifies the agreement among multiple raters (judges) beyond what would be expected by chance. Unlike simple percentage agreement, it accounts for:
- Number of raters
- Possible categories
- Chance agreement
- Missing data

### Formula

```
Alpha = 1 - (D_observed / D_expected)
```

Where:
- **D_observed** = Observed disagreement among coders
- **D_expected** = Disagreement expected by chance

For ordinal data (scores 1-100), disagreement is calculated using the squared difference metric:

```
d(c, k) = (c - k)^2
```

### Interpretation Thresholds

| Alpha Value | Interpretation | Action |
|-------------|----------------|--------|
| >= 0.80 | Excellent reliability | High confidence in scores |
| 0.67 - 0.79 | Good reliability | Acceptable for most research |
| 0.65 - 0.66 | Borderline | Use with caution, add warning |
| < 0.65 | **Poor reliability** | **FLAG RESULT - needs investigation** |

### Why 0.65 Threshold?

Krippendorff originally recommended 0.80 for high-stakes decisions and 0.67 as minimum. The 0.65 threshold is the absolute floor below which results should be flagged for manual review.

### Calculation Example

Given three judges scoring one response:
```
Judge A: 78
Judge B: 82
Judge C: 75
```

Mean = 78.33, Variance = 8.22

For a small sample like this, we compute pairwise disagreements and compare to expected disagreement given the score distribution across all items in the dataset.

## Technical Implementation

### Story 44-1: Add --multi-judge Flag to /solo Command

**Goal:** Enable running multiple judges with prompt variations on a single agent response.

**File to Modify:**
- `pennyfarthing/pennyfarthing-dist/commands/solo.md`

**Changes Required:**

1. **New CLI argument:**
   ```
   --multi-judge N    Run N judges (default: 3, max: 5)
   ```

2. **Flow modification (Step 6):**
   ```
   If --multi-judge is specified:
     For i in 1..N:
       Apply prompt variation i (see variations below)
       Invoke /judge --mode solo --variation i
       Collect: score_i, judge_response_i, tokens_i

     Calculate Krippendorff's Alpha across scores
     If Alpha < 0.65:
       Set reliability_flag = "LOW_ALPHA"
       Log warning to console

     Use MEAN of scores as final score (with Alpha attached)
   ```

3. **Prompt Variations:**
   Create 5 prompt templates that vary emphasis without changing criteria:

   | Variation | Emphasis |
   |-----------|----------|
   | 1 (default) | Balanced - standard rubric |
   | 2 | Correctness-focused - "Pay special attention to technical accuracy" |
   | 3 | Depth-focused - "Prioritize thoroughness of analysis" |
   | 4 | Quality-focused - "Focus on clarity and actionability" |
   | 5 | Strict - "Be conservative in scoring" |

4. **Output Format:**
   ```markdown
   ## Multi-Judge Results

   | Judge | Score | Variation |
   |-------|-------|-----------|
   | 1 | 78 | balanced |
   | 2 | 82 | correctness |
   | 3 | 75 | depth |

   **Krippendorff's Alpha:** 0.72
   **Reliability:** GOOD
   **Final Score (mean):** 78.3
   ```

**Files to Reference:**
- `pennyfarthing/pennyfarthing-dist/skills/judge/SKILL.md` - Judge prompt templates

---

### Story 44-2: Implement Krippendorff's Alpha Calculation

**Goal:** Create a Python utility to calculate Alpha from judge scores.

**File to Create:**
- `pennyfarthing/pennyfarthing_scripts/stats/krippendorff.py`

**Implementation:**

```python
"""
Krippendorff's Alpha for ordinal data.

Usage:
    from pennyfarthing_scripts.stats.krippendorff import krippendorff_alpha

    scores = [[78, 82, 75], [85, 88, 86], [60, 65, 58]]  # items x judges
    alpha = krippendorff_alpha(scores)
"""

import numpy as np
from typing import List, Optional

def krippendorff_alpha(
    scores: List[List[float]],
    metric: str = "ordinal"
) -> float:
    """
    Calculate Krippendorff's Alpha for reliability analysis.

    Args:
        scores: 2D array where rows are items and columns are judges.
                Missing values represented as None or np.nan.
        metric: "ordinal" (default) for 1-100 scores, "nominal" for categories

    Returns:
        Alpha value between -1 and 1 (typically 0-1)

    Interpretation:
        >= 0.80: Excellent
        0.67-0.79: Good
        0.65-0.66: Borderline
        < 0.65: Poor (flag for review)
    """
    # Implementation using the standard formula
    # Reference: Krippendorff, K. (2011). Computing Krippendorff's Alpha-Reliability
    pass

def calculate_observed_disagreement(scores: np.ndarray) -> float:
    """Calculate D_observed using squared differences for ordinal data."""
    pass

def calculate_expected_disagreement(scores: np.ndarray) -> float:
    """Calculate D_expected based on marginal distribution."""
    pass

def classify_reliability(alpha: float) -> str:
    """Return reliability classification."""
    if alpha >= 0.80:
        return "EXCELLENT"
    elif alpha >= 0.67:
        return "GOOD"
    elif alpha >= 0.65:
        return "BORDERLINE"
    else:
        return "POOR"
```

**CLI Wrapper:**
- `pennyfarthing/pennyfarthing_scripts/stats/calc_alpha.py`

```bash
# Usage from /solo command:
python3 -m pennyfarthing_scripts.stats.calc_alpha --scores 78,82,75
# Output: {"alpha": 0.72, "reliability": "GOOD"}
```

**Tests:**
- `pennyfarthing/tests/test_krippendorff.py`
- Known values from published examples
- Edge cases: perfect agreement (alpha=1), random (alpha~0)

---

### Story 44-3: Update finalize-run for Multi-Judge Storage

**Goal:** Extend the finalize-run skill to handle multi-judge data.

**File to Modify:**
- `pennyfarthing/pennyfarthing-dist/skills/finalize-run/SKILL.md`

**Changes Required:**

1. **Extended Data Structure:**
   ```json
   {
     "type": "solo",
     "multi_judge": true,
     "judges": [
       {
         "variation": "balanced",
         "cli_timestamp": "ISO8601",
         "response_text": "...",
         "score": 78,
         "input_tokens": 2345,
         "output_tokens": 890
       },
       {
         "variation": "correctness",
         "cli_timestamp": "ISO8601",
         "response_text": "...",
         "score": 82,
         "input_tokens": 2400,
         "output_tokens": 920
       }
     ],
     "reliability": {
       "alpha": 0.72,
       "classification": "GOOD",
       "flagged": false
     },
     "scores": {"discworld:dev": 78.3}
   }
   ```

2. **New Validation Rules:**

   | Field | Rule | Action on Fail |
   |-------|------|----------------|
   | `judges[]` (if multi_judge) | Array of 2-5 judge objects | REJECT |
   | `reliability.alpha` | Number -1 to 1 | REJECT |
   | `reliability.flagged` | Boolean | WARN if true |

3. **Storage Format:**

   **Directory Structure (multi-judge):**
   ```
   internal/results/benchmarks/{scenario}/{theme}-{role}/
   ├── summary.yaml
   ├── runs/
   │   ├── run_1.json          # Agent response
   │   ├── judge_1_v1.json     # Judge variation 1
   │   ├── judge_1_v2.json     # Judge variation 2
   │   ├── judge_1_v3.json     # Judge variation 3
   │   └── reliability_1.json  # Alpha calculation for run 1
   ```

4. **Summary.yaml Extension:**
   ```yaml
   # discworld:dev on astropy-12907 (multi-judge)
   # Generated: 2026-02-04T12:00:00Z

   agent:
     theme: discworld
     role: dev
     spec: discworld:dev
     character: Ponder Stibbons

   scenario:
     name: astropy-12907
     category: dev
     difficulty: medium

   statistics:
     n: 4
     mean: 78.5
     std_dev: 3.2
     min: 74.0
     max: 83.0
     scores: [78.3, 75.0, 83.0, 78.0]

   # NEW: Multi-judge reliability data
   multi_judge:
     enabled: true
     judges_per_run: 3
     reliability:
       alpha_mean: 0.74
       alpha_min: 0.68
       alpha_max: 0.81
       flagged_runs: 0
       classification: "GOOD"

   baseline_comparison:
     control_mean: 77.50
     control_stddev: 8.54
     delta: +1.00
   ```

---

### Story 44-4: Multi-Judge Test on High-Variance Scenarios

**Goal:** Validate multi-judge system on scenarios known to produce variable scores.

**Scenarios to Test:**

1. **High Variance (expected low Alpha):**
   - `creative-writing-review` - Subjective quality assessment
   - `architecture-tradeoffs` - Multiple valid approaches

2. **Low Variance (expected high Alpha):**
   - `django-10554` - Clear right/wrong (SWE-bench)
   - `astropy-12907` - Deterministic debugging

**Test Protocol:**

```bash
# Run each scenario with 3 judges
/solo discworld:dev --scenario creative-writing-review --multi-judge 3 --runs 4
/solo discworld:dev --scenario django-10554 --multi-judge 3 --runs 4

# Expected results:
# - creative-writing-review: Alpha < 0.65 (should flag)
# - django-10554: Alpha > 0.80 (should not flag)
```

**Validation Criteria:**

| Test | Expected Alpha | Expected Flag |
|------|----------------|---------------|
| creative-writing-review | < 0.65 | YES |
| architecture-tradeoffs | 0.50-0.70 | MAYBE |
| django-10554 | > 0.80 | NO |
| astropy-12907 | > 0.75 | NO |

**Output:**
- Test results in `pennyfarthing/internal/results/multi-judge-validation/`
- Report: `multi-judge-validation-report.md`

## Key Files Summary

| File | Purpose | Story |
|------|---------|-------|
| `pennyfarthing-dist/commands/solo.md` | Add --multi-judge flag | 44-1 |
| `pennyfarthing-dist/skills/judge/SKILL.md` | Reference for prompt variations | 44-1 |
| `pennyfarthing_scripts/stats/krippendorff.py` | Alpha calculation | 44-2 |
| `pennyfarthing_scripts/stats/calc_alpha.py` | CLI wrapper | 44-2 |
| `pennyfarthing-dist/skills/finalize-run/SKILL.md` | Multi-judge storage | 44-3 |
| `tests/test_krippendorff.py` | Alpha unit tests | 44-2 |
| `tests/integration/test_multi_judge.sh` | End-to-end validation | 44-4 |

## Success Criteria

### Quantitative

1. **Alpha Calculation Accuracy:**
   - Known dataset (Krippendorff 2011 examples) produces expected values within 0.01

2. **Flagging Accuracy:**
   - Alpha < 0.65 always produces `flagged: true`
   - Alpha >= 0.65 never produces false positives

3. **Performance:**
   - 3-judge run completes in < 90 seconds (vs ~30s single judge)
   - Storage overhead < 3x single-judge run

### Qualitative

1. **High-variance scenarios** (subjective tasks) produce lower Alpha
2. **Low-variance scenarios** (deterministic tasks) produce higher Alpha
3. **Flagged results** identify genuine measurement issues

## Dependencies

- Stories 44-1 and 44-2 can run in parallel
- Story 44-3 depends on 44-1 (needs multi-judge data structure)
- Story 44-4 depends on 44-1, 44-2, 44-3 (needs full system working)

## References

- Krippendorff, K. (2011). *Computing Krippendorff's Alpha-Reliability*
- Wallach, H., et al. (2024). *Evaluating Large Language Models as Judges*
- Gwet, K. L. (2014). *Handbook of Inter-Rater Reliability* (4th ed.)
- [Inter-Rater Reliability Calculator](https://dfreelon.org/utils/recalfront/)

---

*Generated by SM on 2026-02-04*
