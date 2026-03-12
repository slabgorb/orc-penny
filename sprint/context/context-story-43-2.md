---
parent: context-epic-43.md
workflow: tdd
---

# Story 43-2: Update judge for red herring detection

## Business Context

With red herrings defined in scenarios (43-1), the judge needs to evaluate agent precision — did the agent flag red herrings as real issues (false positive) or correctly ignore them? This adds a precision component to the correctness dimension, penalizing agents that report noise alongside signal.

## Technical Guardrails

**Key files to modify:**
- `pennyfarthing-dist/skills/pf-judge/SKILL.md` — Add red herring awareness to scoring

**Patterns to follow:**
- Red herring evaluation is part of the correctness dimension (not a new dimension)
- Judge receives the red_herrings list as part of scenario context
- Scoring: agent flagging a red herring as a real issue loses points on correctness
- Scoring: agent explicitly dismissing a red herring (noting it's not an issue) gains bonus

**Integration points:**
- Depends on 43-1 (schema must define red_herrings)
- Judge prompt receives red_herrings alongside existing scenario data

**Do NOT:**
- Create a new scoring dimension (precision lives within correctness)
- Change scoring for scenarios without red herrings (backward compat)

## Scope Boundaries

**In scope:**
- Judge prompt modification to include red_herrings from scenario
- Precision scoring within correctness dimension
- Clear rubric: flagging a red herring = penalty, correctly ignoring = neutral, explicitly dismissing = bonus

**Out of scope:**
- Schema changes (43-1)
- Creating scenario content with red herrings (43-3)
- Separate precision dimension or score

## AC Context

**AC: Judge receives red_herrings in scenario context**
- Test: Judge prompt for scenario with red_herrings includes the herring descriptions
- Test: Judge prompt for scenario without red_herrings is unchanged

**AC: Precision scoring in correctness dimension**
- Agent flags red herring as real issue → correctness penalty (specifics in rubric anchors)
- Agent ignores red herring → neutral (no penalty, no bonus)
- Agent explicitly notes "this looks suspicious but is actually correct because..." → small bonus
- Test: Two responses — one flagging herring, one ignoring it — score differently on correctness

**AC: Backward compatibility**
- Scenarios without red_herrings → judge behaves identically to current
- Test: Run judge on scenario without red_herrings, verify identical scoring
