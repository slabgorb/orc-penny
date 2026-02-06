# Epic 46: Difficulty Profile Enhancement - Technical Context

## Overview

**Epic:** epic-46
**Title:** Difficulty Profile Enhancement
**Priority:** P2
**Points:** 5
**Status:** Planning
**Repos:** pennyfarthing

Replace the single `difficulty` label (easy/medium/hard/extreme) with a multi-dimensional `difficulty_profile` that decomposes difficulty into measurable sub-constructs. This enables better scenario selection and more meaningful score interpretation.

## Goals

1. **Decompose "difficulty"** into three measurable dimensions
2. **Add percentile bands** derived from empirical baseline data
3. **Enable scenario filtering** by specific difficulty dimensions
4. **Improve score interpretation** with percentile context

## Framework Alignment

Per Wallach et al.'s construct validity framework, this is a **Level 2 improvement** - multi-dimensional construct decomposition.

**Problem with current approach:**
- Single "difficulty" label is too vague
- Does not capture WHY a scenario is difficult
- Cannot differentiate scenarios that are hard for different reasons
- Example: A scenario might be "hard" due to complex reasoning OR due to requiring niche domain knowledge - these require different skills

**Solution:**
- Decompose into explicit sub-constructs: detection_challenge, reasoning_complexity, domain_knowledge
- Each dimension is independently measurable
- Enables matching scenarios to specific capability testing needs

## Difficulty Dimensions

### 1. detection_challenge

**Definition:** How hard is it to identify the core issue(s)?

| Level | Range | Interpretation | Examples |
|-------|-------|----------------|----------|
| low | 1-3 | Issues are obvious, explicit | Syntax errors, clear violations |
| medium | 4-6 | Issues require attention | Subtle bugs, implicit patterns |
| high | 7-10 | Issues are deeply hidden | Race conditions, timing attacks |

**Measurement:** Correlates with baseline false_negative rate (missed issues).

### 2. reasoning_complexity

**Definition:** How much multi-step reasoning is required?

| Level | Range | Interpretation | Examples |
|-------|-------|----------------|----------|
| low | 1-3 | Single-step reasoning | Direct cause-effect |
| medium | 4-6 | Multi-step chains | Dependency analysis |
| high | 7-10 | Complex inference graphs | Architectural trade-offs |

**Measurement:** Correlates with TRAIL planning/reasoning error rates.

### 3. domain_knowledge

**Definition:** How much specialized knowledge is required?

| Level | Range | Interpretation | Examples |
|-------|-------|----------------|----------|
| low | 1-3 | General programming | Basic patterns, common idioms |
| medium | 4-6 | Domain-specific | GraphQL security, TDD patterns |
| high | 7-10 | Expert/niche | PCI compliance, cryptography |

**Measurement:** Performance delta between domain expert vs generalist personas.

## Schema Format

### New `difficulty_profile` Field

```yaml
# PROPOSED: Replace simple difficulty enum with profile object
# Legacy 'difficulty' field remains for backward compatibility

difficulty_profile:
  # Individual dimension scores (1-10 scale)
  detection_challenge: 6
  reasoning_complexity: 7
  domain_knowledge: 8

  # Aggregate: maintains backward compatibility
  # Computed as weighted average: (D + R + K) / 3, mapped to band
  aggregate: hard

  # Percentile bands from empirical baseline data
  # Format: [p25, p50, p75] from 10-run control baseline
  percentile_bands:
    overall: [62, 71, 79]      # Score percentiles
    detection: [0.65, 0.75, 0.82]  # Recall percentiles
    quality: [18, 21, 23]      # Quality dimension percentiles
```

### Backward Compatibility

The existing `difficulty` field remains valid:

```yaml
# LEGACY (still supported)
difficulty: medium

# NEW (preferred)
difficulty_profile:
  detection_challenge: 5
  reasoning_complexity: 4
  domain_knowledge: 6
  aggregate: medium
  percentile_bands:
    overall: [75, 80, 85]
```

When only `difficulty` is present, assume uniform distribution across dimensions:
- easy -> all dimensions = 3
- medium -> all dimensions = 5
- hard -> all dimensions = 7
- extreme -> all dimensions = 9

### Schema.yaml Updates

```yaml
# New section in schema.yaml
difficulty_profile:
  type: object
  description: "Multi-dimensional difficulty decomposition"
  schema:
    detection_challenge:
      type: integer
      range: [1, 10]
      description: "How hard to identify core issues"
    reasoning_complexity:
      type: integer
      range: [1, 10]
      description: "Multi-step reasoning requirements"
    domain_knowledge:
      type: integer
      range: [1, 10]
      description: "Specialized knowledge requirements"
    aggregate:
      type: enum
      values: [easy, medium, hard, extreme]
      description: "Backward-compatible difficulty label"
    percentile_bands:
      type: object
      description: "Empirical percentiles from baseline runs"
      schema:
        overall:
          type: array
          items: number
          description: "[p25, p50, p75] score percentiles"
        detection:
          type: array
          items: number
          description: "[p25, p50, p75] recall percentiles"
        quality:
          type: array
          items: number
          description: "[p25, p50, p75] quality score percentiles"
```

## Percentile Band Calculation

### Methodology (MLPerf-inspired)

From each scenario's 10-run control baseline:

1. **Collect scores** from `internal/results/baselines/{scenario}/{role}/summary.yaml`
2. **Calculate percentiles** using standard quartile method
3. **Derive bands** for overall score and key dimensions

### Algorithm

```python
import numpy as np

def calculate_percentile_bands(scores: list[float]) -> dict:
    """
    Calculate p25, p50, p75 from baseline scores.

    Args:
        scores: List of scores from baseline runs

    Returns:
        Dict with percentile bands
    """
    return {
        'p25': np.percentile(scores, 25),
        'p50': np.percentile(scores, 50),  # median
        'p75': np.percentile(scores, 75),
    }

def interpret_score(score: float, bands: dict) -> str:
    """
    Interpret a score relative to percentile bands.

    Returns:
        One of: 'below_p25', 'p25_to_p50', 'p50_to_p75', 'above_p75'
    """
    if score < bands['p25']:
        return 'below_p25'  # Bottom quartile
    elif score < bands['p50']:
        return 'p25_to_p50'  # Second quartile
    elif score < bands['p75']:
        return 'p50_to_p75'  # Third quartile
    else:
        return 'above_p75'  # Top quartile
```

### Data Sources

| Source | Location | Fields Used |
|--------|----------|-------------|
| Baseline summaries | `internal/results/baselines/{scenario}/{role}/summary.yaml` | statistics.scores |
| Detection metrics | Run JSON files | detection.recall, detection.precision |
| Dimension scores | Run JSON files | dimensions.{name}.score |

### Minimum Data Requirements

- **n >= 10 runs** for percentile stability
- **std_dev > 5** to ensure meaningful variance
- If insufficient data, omit `percentile_bands` field

## Story Breakdown

### Story 46-1: Add difficulty_profile schema to scenarios (2 points)

**Scope:**
- Add `difficulty_profile` field definition to `scenarios/schema.yaml`
- Define all three dimensions with validation rules
- Add `aggregate` field computation logic
- Add `percentile_bands` subschema
- Ensure backward compatibility with existing `difficulty` field

**Technical Notes:**
- Schema location: `/Users/keithavery/Projects/pf-1/pennyfarthing/scenarios/schema.yaml`
- Add after existing `difficulty_calibration` section (lines 311-373)
- No breaking changes to existing scenarios

**Acceptance Criteria:**
- [ ] New `difficulty_profile` field defined in schema
- [ ] All three dimensions documented with ranges
- [ ] Validation rules added for 1-10 scale
- [ ] Examples updated with new field

### Story 46-2: Populate difficulty profiles from baseline data (2 points)

**Scope:**
- Create script to analyze baseline data and generate profiles
- Populate `difficulty_profile` for all 24+ calibrated scenarios
- Calculate percentile bands from existing baseline runs
- Manual review and adjustment of dimension scores

**Technical Notes:**
- Baseline data location: `pennyfarthing/internal/results/baselines/`
- Each scenario has `summary.yaml` with statistics
- Run data has dimension breakdowns for percentile calculation
- Dimension scores (detection/reasoning/domain) require manual assessment initially

**Algorithm for Initial Population:**
1. Parse `summary.yaml` for each scenario
2. Calculate percentile bands from scores array
3. Derive aggregate from existing difficulty label
4. Set dimension scores based on category heuristics:
   - code-review: high detection, medium reasoning, varies domain
   - architecture: medium detection, high reasoning, medium domain
   - sm: low detection, high reasoning, low domain
   - dev/tea: medium detection, medium reasoning, varies domain

**Acceptance Criteria:**
- [ ] Script created to extract/compute percentile bands
- [ ] All 24 calibrated scenarios have `difficulty_profile`
- [ ] Percentile bands populated from empirical data
- [ ] Dimension scores assigned (can be refined later)

### Story 46-3: Update schema.yaml with new fields documentation (1 point)

**Scope:**
- Document percentile band interpretation
- Add examples with new difficulty_profile format
- Document dimension score guidelines for future scenarios
- Update difficulty_calibration section to reference profiles

**Technical Notes:**
- Add documentation section explaining dimension scoring
- Provide concrete examples for each difficulty level
- Cross-reference with existing calibration data
- Add interpretation guide for percentile bands

**Acceptance Criteria:**
- [ ] Dimension scoring guidelines documented
- [ ] Percentile band interpretation documented
- [ ] Example scenarios updated with full profiles
- [ ] Calibration section references new profile system

## Success Criteria

1. **Schema compatibility:**
   - New `difficulty_profile` field validates correctly
   - Existing scenarios with only `difficulty` continue to work
   - Schema documentation is complete

2. **Data completeness:**
   - All 24+ calibrated scenarios have profiles populated
   - Percentile bands derived from actual baseline data
   - Dimension scores are reasonable (can be refined iteratively)

3. **Usability:**
   - Clear documentation on dimension meanings
   - Guidance for scoring new scenarios
   - Examples demonstrate proper usage

## Research Basis

### ARC-AGI Difficulty Dimensions

ARC-AGI (Chollet, 2019) separates difficulty into:
- **Priors required**: What concepts must the agent already know?
- **Task complexity**: How many reasoning steps?
- **Solution uniqueness**: How constrained is the valid solution space?

Our three dimensions map roughly:
- detection_challenge ~ solution uniqueness
- reasoning_complexity ~ task complexity
- domain_knowledge ~ priors required

### MLPerf Percentile Methodology

MLPerf benchmarks use percentile bands for:
- Comparing results across different hardware
- Establishing "zones" of performance
- Normalizing for result reporting

We adapt this for:
- Comparing persona scores against control baseline
- Establishing performance zones relative to empirical data
- Score interpretation in context

## Key Files

| File | Purpose |
|------|---------|
| `pennyfarthing/scenarios/schema.yaml` | Primary schema definition |
| `pennyfarthing/scenarios/README.md` | Scenario documentation |
| `pennyfarthing/internal/results/baselines/` | Empirical baseline data |
| `pennyfarthing/internal/results/baselines/schema.yaml` | Baseline data schema |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Dimension scores are subjective | Start with heuristics, refine with user feedback |
| Insufficient baseline data for some scenarios | Only add percentile_bands when n >= 10 |
| Breaking existing tooling | Maintain backward compatibility with `difficulty` field |
| Over-engineering for limited benefit | Start minimal, expand based on actual usage |

---

*Context created for Epic 46, 2026-02-04*
