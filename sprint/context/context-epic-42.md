# Epic 42: Anchored Rubric Criteria - Technical Context

## Epic Overview

- **Epic ID:** 42
- **Points:** 6 (3 + 2 + 1)
- **Priority:** P1
- **Marker:** benchmark
- **Repos:** pennyfarthing
- **Status:** planning

## Goal

Replace vague rubric criteria like `clear_explanations` and `actionable_fixes` with behavioral anchors that define what each score level means concretely. This addresses Level 3 improvement in the framework alignment model: operationalization with explicit behavioral anchors.

**Research Basis:** Per Wallach et al., "A benchmark score tells us nothing without understanding the construct it purports to measure." The 2025 research on LLM-as-judge systems shows that few-shot examples don't fix judge self-inconsistency; explicit anchors reduce variance because they eliminate interpretation differences between judge runs.

## Why Behavioral Anchors Matter

### The Problem: Vague Criteria

Current rubric dimensions in `/judge` skill use subjective terms:

```yaml
quality:
  clear_explanations: 8   # What makes it "8"?
  actionable_fixes: 7     # How is "7" different from "6"?
```

Different judge runs interpret these differently, leading to:
- **High variance** (std dev > 15) on subjective dimensions
- **Low inter-rater reliability** (Krippendorff's alpha < 0.65)
- **Unpredictable scoring** that doesn't correlate with actual response quality

### The Solution: Explicit Score Level Definitions

Behavioral anchors define what each score level looks like with concrete examples:

```yaml
clear_explanations:
  9-10: "Explains root cause, impact, and why it's wrong with technical accuracy"
  7-8: "Identifies issue and explains why it matters, minor gaps"
  5-6: "Correctly identifies issue but explanation is superficial"
  3-4: "Vague explanation that doesn't demonstrate understanding"
  1-2: "Explanation is incorrect or missing"
```

This transforms subjective interpretation into objective measurement.

## Current State Analysis

### Existing Judge Infrastructure

The judge skill (`pennyfarthing-dist/skills/judge/SKILL.md`) already has:
- Unified rubric with 4 dimensions (Correctness, Depth, Quality, Persona)
- Checklist-based evaluation for detection scenarios
- Precision/recall scoring (implemented in v2)
- Phase-specific rubrics for relay workflows

### What's Underdefined (Quality Dimension Example)

```markdown
## From EVALUATION-IMPROVEMENTS.md (Priority 8)

quality:
  clear_explanations:
    score: 1-10
    rubric:
      9-10: "Explains root cause, impact, and why it's wrong with technical accuracy"
      7-8: "Identifies issue and explains why it matters, minor gaps"
      5-6: "Correctly identifies issue but explanation is superficial"
      3-4: "Vague explanation that doesn't demonstrate understanding"
      1-2: "Explanation is incorrect or missing"

  actionable_fixes:
    score: 1-10
    rubric:
      9-10: "Provides specific code fix with correct syntax, handles edge cases"
      7-8: "Provides correct approach but minor syntax/edge case issues"
      5-6: "General direction correct but lacks specificity"
      3-4: "Suggests fix but would not work or creates new problems"
      1-2: "No fix provided or completely wrong approach"
```

This is documented in EVALUATION-IMPROVEMENTS.md but NOT yet:
1. Formalized in a reusable anchors file
2. Injected into judge prompts
3. Applied across all rubric dimensions

## Key Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `pennyfarthing-dist/skills/judge/rubric-anchors.md` | **CREATE** | Master behavioral anchor definitions for all dimensions |
| `pennyfarthing-dist/skills/judge/SKILL.md` | **MODIFY** | Reference anchors file in judge prompt construction |
| `scenarios/**/*.yaml` | **MODIFY** | Add scenario-specific anchor overrides where needed |
| `tests/judge/anchor-variance.test.ts` | **CREATE** | Variance measurement test suite |

## Story-by-Story Technical Notes

### Story 42-1: Create rubric-anchors.md with behavioral scales (3 pts)

**Objective:** Create the master reference document defining behavioral anchors for all rubric dimensions.

**File:** `pennyfarthing-dist/skills/judge/rubric-anchors.md`

**Structure:**

```markdown
# Rubric Behavioral Anchors

## Detection Dimension (50 pts)
### For Checklist Scenarios
- Scoring via precision/recall (already operationalized)
- Anchors focus on evidence quality, not score level

## Quality Dimension (25 pts)
### clear_explanations (12.5 pts)
| Score | Behavioral Anchor |
|-------|-------------------|
| 9-10 | Explains root cause + impact + why it's wrong with technical accuracy |
| 7-8 | Identifies issue and explains significance, minor gaps |
| 5-6 | Correctly identifies issue but explanation is superficial |
| 3-4 | Vague explanation that doesn't demonstrate understanding |
| 1-2 | Explanation is incorrect or missing |

### actionable_fixes (12.5 pts)
| Score | Behavioral Anchor |
|-------|-------------------|
| 9-10 | Specific code fix with correct syntax, handles edge cases |
| 7-8 | Correct approach but minor syntax/edge case issues |
| 5-6 | General direction correct but lacks specificity |
| 3-4 | Suggests fix but would not work or creates new problems |
| 1-2 | No fix provided or completely wrong approach |

## Persona Dimension (25 pts)
### in_character (12.5 pts)
| Score | Behavioral Anchor |
|-------|-------------------|
| 9-10 | Unmistakably the character; voice, mannerisms, vocabulary consistent |
| 7-8 | Clearly recognizable character with occasional generic phrasing |
| 5-6 | Some character elements present but inconsistent |
| 3-4 | Minimal character flavor, mostly generic professional tone |
| 1-2 | No discernible character, or breaks character entirely |

### professional_tone (12.5 pts)
| Score | Behavioral Anchor |
|-------|-------------------|
| 9-10 | Character traits enhance rather than undermine professionalism |
| 7-8 | Professional delivery with character flavor |
| 5-6 | Adequate professionalism, character neither helps nor hurts |
| 3-4 | Character traits occasionally undermine credibility |
| 1-2 | Character overwhelms content or is inappropriate |

## Phase-Specific Anchors
### SM Phase (Clarity, Handoff, Completeness)
[Anchors for SM evaluation...]

### TEA Phase (Coverage, RED State, Handoff)
[Anchors for TEA evaluation...]

### Dev Phase (GREEN State, Code Quality, Handoff)
[Anchors for Dev evaluation...]

### Reviewer Phase (Detection, Verdict, Persona)
[Anchors for Reviewer evaluation...]
```

**Acceptance Criteria:**
- [ ] All dimensions from unified rubric have explicit behavioral anchors
- [ ] All phase-specific rubrics have explicit behavioral anchors
- [ ] Score levels use 5 bands (1-2, 3-4, 5-6, 7-8, 9-10)
- [ ] Each band has concrete, observable criteria (no vague terms like "good")
- [ ] Document follows existing skill file patterns

---

### Story 42-2: Reference anchors in judge prompts (2 pts)

**Objective:** Inject behavioral anchors into judge prompt construction so judges use them.

**Modify:** `pennyfarthing-dist/skills/judge/SKILL.md`

**Changes:**

1. **Add anchor loading section to Step 2 (Build Judge Prompt)**

```markdown
### Step 2.1: Load Behavioral Anchors

Before constructing the prompt, load applicable anchors:

1. Load `rubric-anchors.md` from skill directory
2. Extract relevant dimension anchors based on mode:
   - `solo/compare`: Quality + Persona anchors
   - `phase-*`: Phase-specific anchors
   - `checklist`: Detection evidence anchors + Quality + Persona
```

2. **Modify solo mode prompt template**

```markdown
## Evaluation

Score 1-10 on each dimension using these behavioral anchors:

### Quality: clear_explanations (12.5%)
- **9-10:** Explains root cause, impact, and why it's wrong with technical accuracy
- **7-8:** Identifies issue and explains why it matters, minor gaps
- **5-6:** Correctly identifies issue but explanation is superficial
- **3-4:** Vague explanation that doesn't demonstrate understanding
- **1-2:** Explanation is incorrect or missing

### Quality: actionable_fixes (12.5%)
- **9-10:** Provides specific code fix with correct syntax, handles edge cases
[... etc ...]

### Persona: in_character (12.5%)
[... anchors ...]

### Persona: professional_tone (12.5%)
[... anchors ...]

**CRITICAL: Use the anchors above to justify your scores. Quote specific behaviors from the response that match anchor descriptions.**
```

3. **Add evidence requirement to JSON output**

```json
{
  "scores": {
    "quality": {
      "clear_explanations": {
        "value": 8,
        "anchor_match": "7-8: Identifies issue and explains why it matters",
        "evidence": "Response explains the SQL injection risk and its impact on data integrity"
      }
    }
  }
}
```

**Acceptance Criteria:**
- [ ] Judge prompts include behavioral anchors inline
- [ ] JSON output requires anchor_match justification
- [ ] Evidence field links score to specific response text
- [ ] All modes (solo, compare, phase-*) updated

---

### Story 42-3: Variance test - measure CV reduction (1 pt)

**Objective:** Measure coefficient of variation (CV) before and after anchors to validate they reduce judge inconsistency.

**Create:** `tests/judge/anchor-variance.test.ts`

**Test Design:**

```typescript
import { describe, it, expect } from 'vitest';
import { runJudgeMultipleTimes, calculateCV } from './helpers';

describe('Behavioral Anchor Variance Reduction', () => {
  const SAMPLE_RESPONSE = `...`; // Fixed response for consistency testing
  const RUNS = 10;

  it('should have CV < 15% for Quality dimension with anchors', async () => {
    const scores = await runJudgeMultipleTimes({
      mode: 'solo',
      response: SAMPLE_RESPONSE,
      runs: RUNS,
      dimension: 'quality'
    });

    const cv = calculateCV(scores);
    expect(cv).toBeLessThan(0.15); // 15% CV threshold
  });

  it('should have CV < 15% for Persona dimension with anchors', async () => {
    const scores = await runJudgeMultipleTimes({
      mode: 'solo',
      response: SAMPLE_RESPONSE,
      runs: RUNS,
      dimension: 'persona'
    });

    const cv = calculateCV(scores);
    expect(cv).toBeLessThan(0.15);
  });

  it('should show CV reduction vs baseline (no anchors)', async () => {
    // This test compares against historical baseline data
    const withAnchors = await runJudgeMultipleTimes({
      mode: 'solo',
      response: SAMPLE_RESPONSE,
      runs: RUNS,
      useAnchors: true
    });

    const BASELINE_CV = 0.25; // Historical average without anchors
    const currentCV = calculateCV(withAnchors);

    expect(currentCV).toBeLessThan(BASELINE_CV * 0.7); // At least 30% reduction
  });
});
```

**Measurement Protocol:**

1. Select 3 diverse responses (low/medium/high quality)
2. Run judge 10 times on each with anchors
3. Calculate CV: `standard_deviation / mean`
4. Target: CV < 15% for all subjective dimensions

**Acceptance Criteria:**
- [ ] Test suite runs N=10 judge evaluations per sample
- [ ] CV calculated for Quality and Persona dimensions
- [ ] CV < 15% threshold enforced
- [ ] Baseline comparison shows measurable improvement
- [ ] Test results logged for future regression tracking

## Example Anchor Format by Rubric Dimension

### Detection (Checklist Mode)

Detection is already operationalized via precision/recall, but evidence quality can be anchored:

```yaml
evidence_quality:
  9-10: "Quotes specific code line/location, explains exactly why it's problematic"
  7-8: "Identifies correct location, explanation mostly complete"
  5-6: "Finds issue but location or explanation is vague"
  3-4: "Partial identification, significant gaps in evidence"
  1-2: "Issue missed or evidence is wrong"
```

### Correctness (Generic Rubric Mode)

```yaml
correctness:
  9-10: "All technical claims verifiable and accurate; no errors"
  7-8: "Mostly accurate with minor imprecisions that don't affect conclusions"
  5-6: "Core assertions correct but some peripheral errors"
  3-4: "Significant technical errors that undermine credibility"
  1-2: "Fundamentally incorrect or misleading"
```

### Depth (Generic Rubric Mode)

```yaml
depth:
  9-10: "Explores root causes, implications, and non-obvious connections"
  7-8: "Goes beyond surface level; considers multiple angles"
  5-6: "Adequate coverage but lacks deeper analysis"
  3-4: "Shallow treatment; states obvious without elaboration"
  1-2: "Superficial or incomplete; misses key aspects"
```

### Phase-Specific: SM Clarity

```yaml
sm_clarity:
  9-10: "Story fully contextualized; TEA can start immediately with no questions"
  7-8: "Clear context provided; minor clarifications might help"
  5-6: "Adequate briefing but TEA may need to ask follow-ups"
  3-4: "Vague or incomplete; significant gaps in context"
  1-2: "Confusing or missing; TEA cannot proceed confidently"
```

### Phase-Specific: TEA Coverage

```yaml
tea_coverage:
  9-10: "Tests cover all acceptance criteria, edge cases, and error paths"
  7-8: "Good coverage of AC; some edge cases may be missing"
  5-6: "Core paths tested; coverage gaps in edge cases"
  3-4: "Minimal test coverage; key scenarios missing"
  1-2: "Tests inadequate or don't compile"
```

## Success Criteria

| Metric | Baseline | Target |
|--------|----------|--------|
| Quality CV | ~25% (estimated) | **< 15%** |
| Persona CV | ~30% (estimated) | **< 15%** |
| Inter-run Score Delta | +/- 15 pts | **< +/- 8 pts** |
| Anchor Citation Rate | 0% | **> 90%** |

**Primary Success Metric:** Coefficient of Variation (CV) < 15% across 10 independent judge runs on the same response.

## Implementation Notes

### Anchor Injection Pattern

The anchors should be injected at prompt construction time, not read by the judge at runtime. This ensures:
1. Anchors are always present (no file access failures)
2. Prompt length is predictable
3. Judge has anchors inline for reference during scoring

### Backward Compatibility

Existing scenarios without explicit anchor overrides should use the master anchors from `rubric-anchors.md`. Scenario-specific overrides (e.g., GraphQL expertise anchors) can extend the base anchors.

### Dependencies

- Requires judge skill to support inline anchor injection
- Variance tests require deterministic test fixtures
- CV measurement assumes normal distribution of scores

---

*Generated for Epic 42: Anchored Rubric Criteria*
