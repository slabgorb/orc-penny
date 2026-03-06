---
parent: context-epic-43.md
workflow: tdd
---

# Story 43-3: Pilot — Add red herrings to order-service scenario

## Business Context

This pilot tests the red herring system end-to-end on a real scenario. The `order-service` review scenario is well-understood with existing baseline data, making it ideal for measuring the impact of red herrings on agent scoring. Results validate whether the schema and judge changes from 43-1 and -2 work in practice.

## Technical Guardrails

**Key files to modify:**
- Order-service scenario YAML — add 3-4 red herrings

**Red herring design principles:**
- Must be plausible — code patterns that look wrong to a cursory review but are actually correct
- Varied trap types: false-unused import, intentional magic number, deliberate style violation, correct-but-unusual pattern
- Located near real issues to test whether agents distinguish adjacent good/bad code

**Depends on:**
- 43-1 (schema) and 43-2 (judge) must be complete

**Do NOT:**
- Modify real issues in the scenario — only add distractors
- Add so many red herrings that the scenario becomes unrealistic (3-4 is right)

## Scope Boundaries

**In scope:**
- 3-4 red herrings added to order-service scenario YAML
- Run benchmark with and without red herrings to measure impact
- Report: do agents flag the red herrings? Does precision scoring change rankings?

**Out of scope:**
- Adding red herrings to other scenarios (future work after pilot validates approach)
- Automated red herring generation

## AC Context

**AC: 3-4 red herrings added to order-service scenario**
- Each with description, location, trap_type
- Varied trap types (not all the same category)
- Plausible — would fool a hasty reviewer but not a careful one
- Test: Scenario validates against updated schema

**AC: Benchmark comparison with and without red herrings**
- Run order-service with existing baseline agents
- Compare scores: do verbose agents lose points? Do precise agents maintain or gain?
- Test: Results show measurable scoring difference when red herrings present

**AC: Pilot report**
- Which agents flagged which red herrings?
- Did precision scoring change relative rankings?
- Are the red herrings too easy or too hard?
- Recommendations for broader rollout
