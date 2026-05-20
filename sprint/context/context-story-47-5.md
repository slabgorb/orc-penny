# Story 47-5: Score Context Docs Against Manifests — Theme Differentiation

## Overview

Score the PM and Architect context documents (from 47-3, 47-4) against the ground truth manifests (from 47-2). Quantify whether theme/persona choice produces measurably different strategic output quality.

**Points:** 2 | **Workflow:** trivial | **Jira:** PROJ-16298

## Objective

This is the signal story. If context docs from different themes score identically against manifests, then persona choice doesn't matter at the strategic level — and stories 47-6 through 47-8 can be deprioritized. If there's meaningful variance, those experiments become high-value.

## Approach

### Scoring Protocol

For each context doc × manifest, score:

1. **Coverage** (0-100%): What fraction of manifest concerns/ACs are addressed?
2. **Depth** (1-5): How thoroughly is each addressed concern explored?
3. **Noise** (count): How many irrelevant or distracting concerns were raised?
4. **Voice leakage** (qualitative): Did character voice introduce thematic noise into technical content?

### Analysis

- Compare scores across 3 themes for PM and Architect separately
- Calculate effect sizes (Cohen's d) between theme pairs
- Test hypothesis: adversarial scrutiny themes produce higher coverage but more noise
- Test hypothesis: analytical intellectual style produces higher depth

## Key Files

| File | Purpose |
|------|---------|
| `internal/results/manifests/dpgd-116-concern-manifest.yaml` | PM scoring rubric |
| `internal/results/manifests/dpgd-116-ac-manifest.yaml` | Architect scoring rubric |
| `internal/results/pm-context/dpgd-116/*/epic-context.md` | PM outputs (from 47-3) |
| `internal/results/architect-context/dpgd-116/*/story-context.md` | Architect outputs (from 47-4) |

## Acceptance Criteria

- [ ] Scoring matrix: 3 themes × 2 roles × 4 metrics
- [ ] Cohen's d effect sizes for each theme pair
- [ ] Go/no-go recommendation for 47-6, 47-7, 47-8
- [ ] Results in `internal/results/strategic-role-scores-dpgd-116.md`

## Dependencies

- 47-2 (manifests), 47-3 (PM contexts), 47-4 (Architect contexts)
