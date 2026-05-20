---
parent: context-epic-42.md
workflow: tdd
---

# Story 42-1: Create rubric-anchors.md with behavioral scales

## Business Context

Judges currently interpret score levels subjectively — "a 7 for correctness" means different things to different judge invocations. This story creates a behavioral anchoring document that defines what each score level looks like with concrete, observable behaviors. This is the foundation for both human review of benchmark results and consistent LLM judge scoring.

## Technical Guardrails

**Key files to create:**
- `pennyfarthing-dist/guides/rubric-anchors.md` — Behavioral scale definitions for all judge dimensions

**Patterns to follow:**
- Follow existing guide format (see `guides/persona-effectiveness.md` for style)
- Each dimension gets a full 1-10 behavioral scale
- Anchors must be observable and testable — not subjective ("good" → "identifies all edge cases")
- Draw from existing judge rubric dimensions: correctness, depth, quality, persona

**Reference:**
- Current judge rubric in `pennyfarthing-dist/skills/pf-judge/SKILL.md`
- PersonaGym calibrated exemplar approach
- Galileo 3-tier rubric taxonomy (7→25→130)

**Do NOT:**
- Modify the judge prompt yet (that's 42-2)
- Create exemplar responses (that's closer to gold standards, PROJ-16212)

## Scope Boundaries

**In scope:**
- Behavioral anchors for all 4 judge dimensions (correctness, depth, quality, persona)
- Each dimension: 1-2 (poor), 3-4 (below average), 5-6 (adequate), 7-8 (good), 9-10 (excellent)
- Concrete behavioral descriptions at each level
- Cross-references to measurement-framework.md and persona-effectiveness.md

**Out of scope:**
- Judge prompt modifications (42-2)
- Variance testing (42-3)
- Task-specific anchors (e.g., different anchors for code review vs test writing — future work)

## AC Context

**AC: Behavioral scales for correctness dimension**
- 1-2: Response contains factual errors, misidentifies the problem, or proposes broken solutions
- 5-6: Correctly identifies the main issue with a reasonable solution; minor gaps in edge case coverage
- 9-10: Expert analysis identifying non-obvious issues; production-ready solution with comprehensive edge case handling
- Test: Read scale and verify each level is distinguishable from adjacent levels

**AC: Behavioral scales for depth dimension**
- 1-2: Surface-level observation with no analysis
- 5-6: Identifies root cause with adequate explanation
- 9-10: Multi-layered analysis connecting symptoms to root causes to systemic patterns
- Test: Given two sample responses, the scale should unambiguously place them at different levels

**AC: Behavioral scales for quality dimension**
- Covers clarity, actionability, and communication effectiveness
- Test: Scale distinguishes between verbose-but-unhelpful and concise-but-actionable

**AC: Behavioral scales for persona dimension**
- Covers character voice, role-appropriate behavior, persona consistency
- Test: Scale distinguishes between surface mimicry (catchphrases) and deep behavioral alignment

**AC: Document follows guide format**
- Markdown, lives in `pennyfarthing-dist/guides/`, cross-referenced from measurement docs
