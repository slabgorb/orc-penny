# Epic 138: Simplify Integration — automated code quality via TEA verify teammates

## Overview

Integrate Claude Code's `/simplify` concept into Pennyfarthing's TDD workflow as three specialized Haiku teammates running under TEA during the verify phase. Each teammate focuses on a single quality dimension (reuse, quality, efficiency) with isolated context windows, reporting structured findings that TEA aggregates and applies. The existing quality-pass gate serves as the regression safety net.

**Priority:** P0/P1
**Repo:** pennyfarthing
**Stories:** 7 (8 points)
**Jira:** MSSCI-16073

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **Simplify Integration PRD** (`sprint/planning/prd.md`) | All sections — success criteria, scope, journeys, functional/non-functional requirements |
| **Fan-out/Fan-in Pattern** (`pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md`) | Implementation methods, concurrency guidelines, error recovery |
| **Tandem Protocol** (`pennyfarthing-dist/guides/tandem-protocol.md`) | Team block mechanics, backseat spawning, observation injection |
| **Gates Guide** (`pennyfarthing-dist/guides/gates.md`) | quality-pass gate definition, gate evaluation flow |
| **Handoff CLI** (`pennyfarthing-dist/guides/handoff-cli.md`) | Agent exit protocol, resolve-gate → complete-phase → marker |

## Background

### Problem

Agentic coding sessions produce functional but often bloated code. Dev agents tend to over-engineer, duplicate logic across files, and introduce unnecessary complexity. Currently, the Reviewer agent is the only quality defense — but the Reviewer is adversarial (focused on logic bugs, security issues, coverage gaps), not constructive. Code quality issues like duplication, poor naming, and unnecessary abstractions create round-trip rejections between Reviewer and Dev, wasting tokens and time.

### Inspiration

Claude Code's `/simplify` command spawns three parallel subagents to review changed code: one for reuse opportunities, one for code quality, one for efficiency. It runs after implementation and catches a different class of problems than linters or reviewers. The insight: these checks are independent, mechanical, and parallelizable — perfect for Haiku teammates.

### Architectural Decision

Three placement options were evaluated:

| Option | Verdict | Reason |
|--------|---------|--------|
| New gate | Rejected | Gates are Haiku subagents — too mechanical for nuanced code quality judgment |
| Reviewer integration | Rejected | Mixes constructive (simplify) with adversarial (review) roles |
| **TEA verify phase** | **Selected** | TEA has test context, is constructive, already runs after Dev. Opposition dynamic preserved. |

TEA runs as team leader during verify, spawning three Haiku teammates in parallel. This uses the existing fan-out/fan-in pattern and team block infrastructure. No new workflow phases, gates, or agents (beyond the three subagent definitions).

## Technical Architecture

### Component Diagram

```
TDD Workflow: setup → red → green → VERIFY → review → finish
                                       │
                                       ▼
                              TEA (Opus, leader)
                                       │
                          ┌────────────┼────────────┐
                          ▼            ▼            ▼
                   simplify-reuse  simplify-quality  simplify-efficiency
                   (Haiku)         (Haiku)           (Haiku)
                          │            │            │
                          └────────────┼────────────┘
                                       ▼
                              TEA aggregates results
                              Applies / rejects findings
                              Commits fixes if any
                                       │
                                       ▼
                              quality-pass gate
                              (lint + typecheck + tests)
                                       │
                                       ▼
                              Handoff to Reviewer
```

### Key Files

| File | Status | Purpose |
|------|--------|---------|
| `pennyfarthing-dist/agents/simplify-reuse.md` | **Create** | Haiku subagent: find duplication, extraction opportunities |
| `pennyfarthing-dist/agents/simplify-quality.md` | **Create** | Haiku subagent: naming, readability, structure |
| `pennyfarthing-dist/agents/simplify-efficiency.md` | **Create** | Haiku subagent: unnecessary complexity, over-engineering |
| `pennyfarthing-dist/agents/tea.md` | **Modify** | Add verify-phase teammate spawning and aggregation logic |
| `pennyfarthing-dist/workflows/tdd.yaml` | **Modify** | Add `team:` block to verify phase |
| `pennyfarthing-dist/workflows/tdd-tandem.yaml` | **Modify** | Add `team:` block to verify phase (alongside architect) |
| `pennyfarthing-dist/gates/quality-pass.md` | Unchanged | Existing safety net — no modifications needed |

### Data Flow

1. TEA enters verify phase, reads session file
2. TEA runs `git diff --name-only` to identify changed files, filters non-code files
3. TEA spawns 3 Haiku teammates via Agent tool with `run_in_background: true`, each receiving the file list
4. Each teammate reads the changed files through its specific lens, returns `SIMPLIFY_RESULT` YAML
5. TEA collects results via `TaskOutput`, reviews findings by confidence level
6. TEA applies `high` confidence suggestions, reviews `medium`/`low` manually
7. If changes applied: TEA commits `refactor: simplify code per verify review`
8. quality-pass gate fires (lint + typecheck + tests) — catches any regressions
9. If gate fails post-simplify: TEA reverts offending change, re-runs gate
10. TEA writes Simplify Report section in assessment, hands off to Reviewer

### Structured Finding Format (SIMPLIFY_RESULT)

```yaml
SIMPLIFY_RESULT:
  agent: simplify-reuse | simplify-quality | simplify-efficiency
  status: clean | findings
  findings:
    - file: "path/to/file.ts"
      line: 42
      category: "duplicated-logic" | "naming" | "over-engineering" | etc.
      description: "What was found"
      suggestion: "What to do about it"
      confidence: high | medium | low
```

### Workflow YAML Change (tdd.yaml verify phase)

```yaml
- name: verify
  agent: tea
  input: [implementation, passing_tests]
  output: [quality_verified]
  gate:
    file: gates/quality-pass
    type: quality_pass
    condition: Lint, typecheck, and all tests passing
  team:
    teammates:
      - agent: simplify-reuse
        task: "Review changed files for code duplication and extraction opportunities. Report findings only."
      - agent: simplify-quality
        task: "Review changed files for naming, readability, and structural quality. Report findings only."
      - agent: simplify-efficiency
        task: "Review changed files for unnecessary complexity and over-engineering. Report findings only."
```

## Cross-Epic Dependencies

**Depends on:**
- None — TEA agent, TDD workflows, quality-pass gate, and fan-out pattern all exist

**Depended on by:**
- Epic 137 (Batch Execution) references simplify as a pre-merge quality check in batch PRD
