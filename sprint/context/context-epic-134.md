# Epic 134: Impact Summary & Boss-Readable PR

## Overview

Boss can understand a story's upstream effects in 30 seconds via Impact Summary, delivered through a self-contained, jargon-free PR description generated from the session file. This is the second epic in the session-feedback initiative — it consumes the Delivery Findings captured by Epic 133 and compiles them into actionable summaries.

**Priority:** P1
**Repo:** pennyfarthing
**Stories:** 3 (7 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **Session Feedback PRD** (`sprint/planning/session-feedback-prd.md`) | Phase 1: Impact Summary (FR1-FR7), SM Finish Enhancement, Session File Schema Extension |
| **Epic Breakdown** (`sprint/planning/create-epics-and-stories.md`) | Epic 2 stories, FRs FR1-FR7/FR15/FR20-FR22, ADR-0031 guardrails |
| **PRD Validation** (`sprint/planning/session-feedback-prd-validation.md`) | FR mapping to epics, validation of requirements |
| **Epic 133 Context** (`sprint/archive/context-epic-133.md`) | R1 format spec, findings capture module, validation gate |

## Background

The session-feedback initiative has three epics: 133 (finding capture), 134 (impact summary), 135 (sprint aggregation). Epic 133 is now complete — agents capture structured R1-format findings during their phases, and a validation module (`pf.findings.capture`) parses them.

However, the captured findings sit inert in session files. The boss must still read the raw `## Delivery Findings` section to understand a story's upstream effects. There is no compilation step that transforms raw findings into a quick-scan summary, and no mechanism to generate boss-readable PR descriptions from session data.

Epic 134 closes this gap with two capabilities:
1. **Impact Summary compilation** — SM's finish flow reads Delivery Findings and writes a `## Impact Summary` section with finding counts, blocking status, and one-line descriptions
2. **Boss-readable PR body** — SM generates a PR description that translates framework jargon into plain language, structured for the boss to understand in 30 seconds

### Key Design Decisions

- Impact Summary is compiled from findings verbatim (R6 — not editorial). SM reads and summarizes, doesn't reinterpret.
- PR body uses zero framework jargon — translation map: TEA→"Test design", Dev→"Implementation", Reviewer→"Code review", SM→"Story completion", AC→"Requirements"
- Section order in session file: Delivery Findings → Impact Summary → Assessments (summary follows findings, precedes assessments)
- PR is created late — after review approval, not before. This is a change from previous workflow where PRs existed during review.

## Technical Architecture

### Data Flow

```
Delivery Findings (from agents)
  → pf.findings.capture.parse_delivery_findings()  [Epic 133]
  → Impact Summary compilation (sm-finish)          [134-1]
  → Write ## Impact Summary to session file          [134-1]
  → PR body generation from session file             [134-2]
  → gh pr create with boss-readable body             [134-2]
```

### Key Files

| File | Role | Story |
|------|------|-------|
| `pennyfarthing-dist/agents/sm-finish.md` | Subagent that compiles Impact Summary during finish | 134-1 |
| `pennyfarthing-dist/agents/sm.md` | SM agent definition — finish flow orchestration | 134-1, 134-2 |
| `pennyfarthing-dist/src/pf/findings/capture.py` | Parse findings from session (from Epic 133) | consumed by 134-1 |
| `pennyfarthing-dist/guides/session-artifacts.md` | Documentation of Impact Summary format | 134-3 |

### Impact Summary Format (FR1-FR7)

```markdown
## Impact Summary

**Upstream Effects:** {count} findings ({N} Gap, {N} Conflict, {N} Question, {N} Improvement)
**Blocking:** {None | N BLOCKING items — see below}

**BLOCKING:**
- **{Type}:** {description}. Affects `{path}`.

- **{Type}:** {description}. Affects `{path}`.
```

When no findings exist: `**Upstream Effects:** No upstream effects noted`

### PR Body Structure (FR20-FR22)

```
## Summary
## What Was Done
## What This Work Revealed (Impact Summary)
## Docs That May Need Updating
## Details
  ### Test Design
  ### Implementation
  ### Code Review
  ### Full Findings
```

### Guardrails (from ADR-0031)

- R5: Impact Summary section placed after Delivery Findings, before agent assessments
- R6: Summary is compiled from findings verbatim — SM reads, doesn't editorialize
- FR20: PR created after review approval (late PR creation)
- FR21: Zero framework jargon in PR body
- FR22: PR body must include all six sections

## Cross-Epic Dependencies

**Depends on:**
- Epic 133 (Agent Finding Capture) — provides R1-format Delivery Findings in session files and `pf.findings.capture` module for parsing. **Complete.**

**Depended on by:**
- Epic 135 (Sprint Findings Aggregation) — consumes Impact Summaries from archived sessions for sprint-level pattern analysis
