---
parent: context-epic-42.md
workflow: tdd
---

# Story 42-2: Reference anchors in judge prompts

## Business Context

The behavioral anchors from 42-1 are only useful if judges actually use them. This story wires the anchors into the judge prompt so each dimension's scoring instructions include the concrete behavioral descriptions. This should reduce score variance by giving judges a shared reference frame.

## Technical Guardrails

**Key files to modify:**
- `pennyfarthing-dist/skills/pf-judge/SKILL.md` — Reference rubric-anchors.md in scoring instructions

**Patterns to follow:**
- Include anchors inline in the judge prompt (not as a file reference — judge can't read files)
- Keep anchors concise in the prompt to manage token budget
- Include at minimum the boundary descriptions (1-2, 5-6, 9-10) — full 10-level detail in the guide

**Integration points:**
- Depends on 42-1 (rubric-anchors.md must exist)
- Judge prompt changes affect all benchmark runs going forward

**Do NOT:**
- Change scoring weights or dimension definitions
- Add new dimensions
- Modify the judge's output format

## Scope Boundaries

**In scope:**
- Add behavioral anchor descriptions to each dimension's scoring instructions in judge prompt
- Use abbreviated anchors (boundary descriptions) to manage prompt token budget
- Reference full rubric-anchors.md as authoritative source in prompt preamble

**Out of scope:**
- Creating the anchors document (42-1)
- Measuring variance reduction (42-3)
- Changing scoring weights or dimension structure

## AC Context

**AC: Each dimension's scoring instructions include behavioral anchors**
- Judge prompt for correctness includes: what a 1-2 looks like, what a 5-6 looks like, what a 9-10 looks like
- Same for depth, quality, persona
- Test: Read judge prompt, verify each dimension has at least 3 anchor levels described

**AC: Token budget managed**
- Anchors add reasonable token overhead (estimate: 200-400 tokens per dimension, ~1000-1600 total)
- Test: Measure judge prompt token count before and after — increase < 2000 tokens

**AC: Full guide referenced**
- Judge prompt includes: "See rubric-anchors.md for complete behavioral scale definitions"
- Test: Reference present in prompt preamble
