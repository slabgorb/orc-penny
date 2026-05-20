# Epic 90: Confidence Circuit Breaker (via Gate)

**Jira:** PROJ-14662
**Repo:** pennyfarthing
**PRD:** `sprint/planning/gate-prd.md`

## Overview

Implement confidence gates using the BikeLane Gate Extraction system. Agents pause and ask for clarification when intent is ambiguous, using gate files rather than ad-hoc decision logic. The Gate PRD defines the file schema (`<gate>`, `<purpose>`, `<pass>`, `<fail>`), subagent runner, model inheritance, and nesting.

## Stories

| ID | Title | Pts | Priority | Status |
|----|-------|-----|----------|--------|
| 90-1 | Spike: define confidence circuit breaker pattern | 2 | P1 | done (Gate PRD) |
| 90-2 | Implement SM confidence gate file | 2 | P1 | in progress |
| 90-3 | Evaluate and document results | 1 | P1 | planning |

## Dependencies

- **Epic 106** (Gate Files & First Migration) — provides gate file schema, gate subagent runner, and gate file discovery/resolution
- `gates/tests-pass.md` — existing gate file to use as schema reference
- `sprint/planning/gate-prd.md` — Gate PRD with full schema specification

## Key Files

- `pennyfarthing-dist/gates/tests-pass.md` — existing gate file (schema example)
- `pennyfarthing-dist/gates/` — target location for new gate files
- `pennyfarthing-dist/agents/sm.md` — SM agent definition (where gate would be triggered)

## Context

Story 90-2 creates `gates/confidence-sm.md` — a gate that checks whether an instruction to the SM agent is ambiguous (e.g., "continue", "next", "start" without clear target). If ambiguous, `<fail>` returns clarifying options. If unambiguous, `<pass>` lets the agent proceed. This validates the gate schema, runner, and model inheritance in a real workflow context.
