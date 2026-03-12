---
parent: context-epic-45.md
workflow: tdd
---

# Story 45-2: Update judge to use gold standard as calibration

## Business Context

With gold standards defined in scenarios (45-1), the judge can use them as calibration anchors. Instead of scoring in a vacuum, the judge sees: "Here is an expert-level response that scores 92. Compare the agent's response against this benchmark." This reduces score drift and central tendency bias.

## Technical Guardrails

**Key files to modify:**
- `pennyfarthing-dist/skills/pf-judge/SKILL.md` — Add gold standard as calibration context

**Patterns to follow:**
- Gold standard is presented as reference, not as the "correct answer" — agent may take a different valid approach
- Judge instruction: "Use this expert response as a calibration point. A response of similar quality should score similarly. Responses that miss key insights from the gold standard should score lower."
- Gold standard score (e.g., 92) anchors the scale for this specific scenario

**Do NOT:**
- Make gold standard a required field (must work without it)
- Penalize agents for different-but-equally-valid approaches
- Include gold standard in the agent's input (only the judge sees it)

## Scope Boundaries

**In scope:**
- Judge prompt includes gold standard response + score when available
- Calibration instruction in judge prompt
- Backward compatibility — judge works normally without gold standard

**Out of scope:**
- Schema changes (45-1)
- Writing gold standards (45-3)
- Variance measurement (45-4)

## AC Context

**AC: Judge prompt includes gold standard when available**
- Test: Scenario with gold_standard → judge prompt contains the expert response and score
- Test: Scenario without gold_standard → judge prompt unchanged

**AC: Calibration instruction present**
- Judge told to use gold standard as anchor, not as only correct answer
- Test: Instruction mentions comparing quality level, not penalizing different approaches

**AC: Backward compatibility**
- Test: Judge on scenario without gold standard produces identical results to current behavior
