# Context: Story 42-2 — Reference anchors in judge prompts

**Jira Issue:** MSSCI-16220
**Points:** 2
**Priority:** P0
**Epic:** 42 — Anchored Rubric Criteria (MSSCI-16210)
**Workflow:** tdd

## Problem

The judge skill (`pf-judge/SKILL.md`) currently uses bare dimension labels with minimal guidance — e.g., "Score 1-10 on Correctness (25%) - Technical accuracy." Without concrete behavioral descriptions for each score level, LLM judges default to central tendency, clustering scores around 6-7. This produces high variance and low discriminability between genuinely different response qualities.

Story 42-1 created `rubric-anchors.md` with behaviorally anchored rating scales (BARS) for all four judge dimensions. This story wires those anchors into the actual judge prompts so that evaluation invocations include concrete behavioral descriptions at each score band.

## Architecture

### Current Judge Prompt Flow

```
pf-judge/SKILL.md defines prompt templates
  → Solo mode: "Score 1-10 on Correctness, Depth, Quality, Persona"
  → Compare mode: same dimensions, two contestants
  → Phase modes: dimension-specific rubrics (Clarity, Coverage, Detection, etc.)
  → Executed via: cat prompt.txt | claude -p --output-format json
```

The judge prompts are defined entirely in `pf-judge/SKILL.md` as inline prompt templates within `<details>` blocks. There is no programmatic prompt construction — the skill file IS the prompt specification, read by Claude at invocation time.

### Target State

```
pf-judge/SKILL.md references rubric-anchors.md
  → Solo generic: each dimension includes 5-band behavioral anchors
  → Solo checklist: quality + persona get anchors (detection keeps precision/recall)
  → Compare: all four dimensions get anchors
  → Phase modes: relevant anchors for phase-specific dimensions
```

### Key Files

| File | Role | Change |
|------|------|--------|
| `pennyfarthing-dist/skills/pf-judge/SKILL.md` | Judge prompt templates | Modify prompts to include behavioral anchors |
| `pennyfarthing-dist/guides/rubric-anchors.md` | Behavioral scales (42-1) | Source of truth — read, not modified |
| `pennyfarthing-dist/guides/measurement-framework.md` | Wallach L3 theory | Reference only |
| `pennyfarthing-dist/guides/persona-effectiveness.md` | PersonaScore calibration | Reference only |

### Current Solo Mode Prompt (Generic Rubric)

The current prompt says:
```
Score 1-10 on each dimension:
1. **Correctness (25%)** - Technical accuracy
2. **Depth (25%)** - Thoroughness
3. **Quality (25%)** - Clarity and actionability
4. **Persona (25%)** - Character embodiment
```

This should become something like:
```
Score 1-10 on each dimension using the behavioral anchors below:

### Correctness (25%) - Technical accuracy
- 1-2: Response contains factual errors or misidentifies the core problem...
- 5-6: Correctly identifies the main issue with a reasonable solution...
- 9-10: Expert-level analysis that identifies non-obvious issues...

### Depth (25%) - Thoroughness
...
```

### Behavioral Anchors (from rubric-anchors.md)

Each dimension has 5 band levels (1-2, 3-4, 5-6, 7-8, 9-10) with concrete behavioral descriptions. These are the rating scales from the PersonaGym/Galileo research basis that reduce inter-rater disagreement.

## Acceptance Criteria

### AC1: Solo mode generic rubric references behavioral anchors
- **Given** a solo mode judge invocation with no baseline_issues
- **When** the judge prompt is constructed
- **Then** each of the four dimensions includes behavioral anchor descriptions at all 5 band levels
- **And** the anchors match the text in rubric-anchors.md

### AC2: Solo mode checklist rubric references behavioral anchors
- **Given** a solo mode judge invocation WITH baseline_issues (checklist mode)
- **When** the judge prompt is constructed
- **Then** quality and persona dimensions include behavioral anchors
- **And** detection dimension retains its precision/recall scoring (not overridden)

### AC3: Compare mode rubric references behavioral anchors
- **Given** a compare mode judge invocation
- **When** the judge prompt is constructed
- **Then** all four dimensions include behavioral anchor descriptions

### AC4: Phase-specific rubrics reference relevant anchors
- **Given** a phase-specific judge invocation (SM, TEA, Dev, Reviewer)
- **When** the phase prompt is constructed
- **Then** relevant behavioral anchors are included for phase-specific dimensions

### AC5: Anchor references are sourced from rubric-anchors.md
- **Given** the SKILL.md file
- **When** reading the anchor text in prompts
- **Then** SKILL.md contains a reference pointing to rubric-anchors.md as the source of truth

## Implementation Notes

### Approach

The primary change is to `pf-judge/SKILL.md`. Since judge prompts are defined as markdown templates in the skill file (not programmatically constructed in code), this is largely a documentation/prompt engineering task:

1. **Inline anchor text** into the solo/compare/phase prompt templates in SKILL.md
2. **Add cross-reference** to rubric-anchors.md at the top of the rubric section
3. **Keep detection scoring unchanged** in checklist mode (precision/recall math stays)
4. **For phase modes**, map existing phase dimensions to the most relevant anchors

### Dependency Note

Story 42-1's rubric-anchors.md must be on the working branch. It was created on `feature/MSSCI-16219-rubric-anchors-behavioral-scales` and needs to be merged to develop or cherry-picked before 42-2 implementation begins.

### Testing Strategy

Tests should validate that:
- SKILL.md prompt templates contain behavioral anchor text for each dimension
- Anchor text in SKILL.md matches rubric-anchors.md (no drift)
- Detection scoring formulas in checklist mode are preserved unchanged
- Phase-specific prompts include relevant anchors

## Dependency Notes

- **Depends on 42-1:** rubric-anchors.md must exist on the branch
- **Depended on by 42-3:** Variance test (MSSCI-16221) will measure CV reduction from anchored prompts
- **Related to 44-1:** Multi-judge validation (MSSCI-16214) provides disagreement data that motivates anchoring

## Out of Scope

- Modifying rubric-anchors.md itself (that's 42-1)
- Measuring variance reduction (that's 42-3)
- Changing judge scoring formulas or weights
- Modifying Python or TypeScript benchmark code (prompts are in SKILL.md)
