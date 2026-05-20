# Epic 43: False Positive Traps (Red Herrings)

## Overview

Add deliberately misleading elements to benchmark scenarios that test whether agents can distinguish real issues from distractors. Measures precision — agents that flag everything score lower than agents that accurately identify genuine problems while ignoring red herrings.

**Priority:** P1
**Repo:** pennyfarthing
**Stories:** 3 (7 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **persona-effectiveness.md** (`pennyfarthing-dist/guides/persona-effectiveness.md`) | §Instance-Level Problem — same persona helps on some instances, hurts on others |
| **measurement-framework.md** (`pennyfarthing-dist/guides/measurement-framework.md`) | Wallach L2 Systematized Concept — construct validity requires measuring what you intend to measure |

## Background

### The False Positive Problem

Current benchmark scenarios contain only genuine issues. An agent that flags everything — every variable name, every comment, every style choice — can score well on recall without demonstrating judgment. This inflates scores for verbose, low-precision agents and fails to distinguish careful analysis from shotgun criticism.

### Why Red Herrings Matter

In real code review, most code is correct. An effective reviewer identifies the 2-3 real issues in a 200-line diff, not 15 "issues" of which 3 are real. Red herrings test this discrimination ability — they're code patterns that look suspicious but are actually correct (or intentional).

### Research Connection

The persona effectiveness research shows that personas can degrade rationale quality while appearing to improve classification accuracy [35]. Red herrings specifically test whether persona-driven agents maintain analytical precision or just produce more verbose output.

## Technical Architecture

### Schema Extension

Add `red_herrings` field to scenario YAML:

```yaml
scenario:
  name: order-service-review
  red_herrings:
    - description: "Unused import that's actually used via reflection"
      location: "line 12"
      trap_type: "false-unused"
    - description: "Magic number that's actually a well-known HTTP status"
      location: "line 45"
      trap_type: "false-magic-number"
```

### Judge Updates

The judge evaluates whether the agent:
1. Correctly identifies genuine issues (recall)
2. Avoids flagging red herrings (precision)
3. Provides reasoning that distinguishes real from false issues

A new `precision` sub-score within the correctness dimension.

### Key Files

| File | Purpose | Story |
|------|---------|-------|
| Scenario YAML schema | Add `red_herrings` field | 43-1 |
| `pennyfarthing-dist/skills/pf-judge/SKILL.md` | Precision scoring for red herring detection | 43-2 |
| `order-service` scenario | Pilot with 3-4 red herrings added | 43-3 |

### Pilot Approach

Story 43-3 adds red herrings to the existing `order-service` scenario as a pilot. This tests the schema and judge changes on a known scenario before broader rollout.

## Cross-Epic Dependencies

**Depends on:**
- PROJ-16214 (Multi-Judge Validation) — multi-judge measures whether red herrings cause judge disagreement (judges may disagree on what counts as "correctly ignored")

**Depended on by:**
- PROJ-16213 (Difficulty Profile Enhancement) — red herring count/subtlety is a difficulty dimension
