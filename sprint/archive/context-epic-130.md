# Epic 130: Automated Context Creation

## Overview

Build the `/pf-context` skill that generates epic and story context documents. PM is always the primary author. For story context, a tandem partner (Architect or UX-Designer) observes and injects domain-specific guardrails. This is the critical path epic — it produces the documents that gates enforce and agents consume.

**Priority:** P1
**Repo:** pennyfarthing
**Stories:** 3 (7 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **PRD** (`sprint/planning/context-gate-prd.md`) | FR6-FR11 (context creation), FR22-FR24 (agent integration), Journey 2 (PM+Architect), Journey 3 (PM+UX-Designer), Journey 5 (epic context cascade), Journey 6 (manual creation) |
| **ADR-0029** (`docs/adr/0029-context-gate-architecture.md`) | Component structure diagram (lines 81-108), tandem partner selection (line 157), consistency rules 5-6 and 9, implementation plan items 5-6 |
| **Tandem Protocol** (`pennyfarthing-dist/guides/tandem-protocol.md`) | Backseat spawn, observation file format, consultation protocol |

## Background

### Why Tandem

A PM writing context alone produces business context but misses technical constraints. An Architect alone misses business priority. The tandem model — PM primary + specialist backseat — produces richer context than either agent alone. The backseat observes and injects: "This touches the WebSocket broadcast path — Dev needs to know about the event loop constraint."

### Why Skill, Not Workflow

Context creation is a sub-task invoked by SM during setup, not a standalone BikeLane workflow. Skills are the right delivery mechanism: they can be invoked programmatically by agents (`/pf-context create story 129-1`) and manually by the operator.

### Tandem Partner Selection

Per ADR-0029 Rule #5 and PRD:
- `tdd` / `trivial` workflows → PM + Architect (technical guardrails)
- `bdd` / `bdd-tandem` workflows → PM + UX-Designer (interaction patterns, accessibility)
- `--tandem architect|ux` flag overrides automatic selection
- `--no-tandem` flag skips partner spawn entirely (manual escape hatch, Rule #9)

### What PM Reads to Write Context

**Epic context:** Epic YAML definition (from sprint shard), planning docs (PRD, ADR), existing related epic contexts.

**Story context:** Story YAML (ACs, points, workflow type, type), parent epic context, session file (if it exists), planning docs referenced in epic context.

## Technical Architecture

### Component Map

```
SM Agent (setup phase)
  |  Gate fails → missing context
  |  Invokes: /pf-context create story {id}
  v
/pf-context Skill (pennyfarthing-dist/skills/pf-context/skill.md)
  |  1. Reads story workflow field from sprint YAML
  |  2. Selects tandem partner (architect or ux-designer)
  |  3. Reads context-schema.yaml for required sections
  |  4. Reads template from pennyfarthing-dist/templates/
  v
PM Agent (primary)                                    <-- 130-1, 130-2
  |  Reads: epic YAML, story YAML, planning docs, parent epic context
  |  Fills template sections with business context, scope, ACs
  |
  +-- Tandem Partner (backseat, Haiku)                <-- 130-3
  |     Observes PM writing, injects domain observations:
  |     Architect: technical guardrails, dependencies, constraints
  |     UX-Designer: interaction patterns, accessibility, visual
  |
  v
sprint/context/context-{type}-{id}.md                 <-- output
```

### Skill Architecture

The `/pf-context` skill is a markdown skill definition (not a Python script). It instructs the invoking agent (or PM, if invoked directly) on what to read, what to write, and how to spawn the tandem.

**Invocation patterns:**
- `pf-context create epic 129` — PM creates epic context, no tandem (epics are simpler)
- `pf-context create story 129-3` — PM + tandem partner create story context
- `pf-context create story 129-3 --no-tandem` — PM-only, skip backseat

### Key Files (New)

| File | Path | Purpose |
|------|------|---------|
| Context skill | `pennyfarthing-dist/skills/pf-context/skill.md` | Skill definition — orchestrates creation flow |
| Skill metadata | `pennyfarthing-dist/skills/pf-context/metadata.yaml` | Skill registration for discovery |

### Key Files (Reference/Consumed)

| File | Path | Purpose |
|------|------|---------|
| Context schema | `pennyfarthing-dist/templates/context-schema.yaml` | Section requirements (from Epic 129-2) |
| Epic template | `pennyfarthing-dist/templates/context-epic-template.md` | Base template for epic context (from Epic 129-4) |
| Story template | `pennyfarthing-dist/templates/context-story-template.md` | Base template for story context (from Epic 129-4) |
| Tandem protocol | `pennyfarthing-dist/guides/tandem-protocol.md` | Backseat spawn and observation protocol |
| Sprint YAML shards | `sprint/epic-*.yaml` | Epic definitions, story metadata, ACs |
| Planning docs | `sprint/planning/*.md` | PRDs, ADRs referenced by epics |
| Existing context | `sprint/context/context-epic-*.md` | Parent epic context for story creation |

### Epic Context Creation Flow (130-1)

1. Read epic YAML shard (`sprint/epic-{jira_key}.yaml` or by ordinal ID)
2. Read planning docs referenced in epic description (PRD, ADR paths)
3. Read `context-schema.yaml` for required epic sections
4. Load `context-epic-template.md`
5. Fill sections: Overview (from epic title/description), Background (from planning docs), Technical Architecture (from ADR/planning), Planning Documents (table of referenced docs)
6. Write to `sprint/context/context-epic-{id}.md`
7. No tandem — epic context is strategic summary, not implementation detail

### Story Context Creation Flow (130-2)

1. Read story from sprint YAML (ACs, points, workflow, type)
2. Read parent epic context (`sprint/context/context-epic-{N}.md`)
3. Read `context-schema.yaml` for required story sections
4. Load `context-story-template.md`
5. Determine tandem partner from story workflow field (Rule #5)
6. If tandem enabled: spawn backseat partner via tandem protocol
7. PM fills sections: Business Context (from epic + story ACs), Technical Guardrails (from epic arch + tandem injections), Scope Boundaries (explicit in/out), AC Context (expand terse ACs into testable detail)
8. Write frontmatter: `parent: context-epic-{N}.md`, `workflow: {workflow}`
9. Write to `sprint/context/context-story-{id}.md`

### Tandem Integration (130-3)

**Backseat spawn prompt pattern:**
```
Read .pennyfarthing/agents/tandem-backseat.md for your instructions.

PARTNER: "architect"
CHARACTER: "{theme_character}"
STORY_ID: "{story_id}"
SCOPE: "context-creation"
OBSERVATION_FILE: ".session/{story_id}-tandem-{partner}.md"
```

**Observation injection points:**
- After PM drafts Technical Guardrails → Architect injects constraints, dependencies
- After PM drafts Scope Boundaries → Architect injects "don't touch X" warnings
- After PM drafts AC Context → UX-Designer injects accessibility/interaction requirements

**Failure handling:** ADR-0029 — tandem backseat failure is silent. PM continues solo. Context is still valid but may lack specialist input. Warning logged.

## Stories

| Story | Title | Points | Workflow | Dependencies |
|-------|-------|--------|----------|-------------|
| 130-1 | /pf-context create epic Skill | 2 | tdd | 129-2 (schema), 129-4 (templates) |
| 130-2 | /pf-context create story Skill (PM-Only Mode) | 3 | tdd | 130-1 |
| 130-3 | Tandem Partner Selection and Integration | 2 | tdd | 130-2 |

## Story Notes

### 130-1: /pf-context create epic Skill

**What to do:** Create the skill definition at `pennyfarthing-dist/skills/pf-context/skill.md` with the epic creation flow. Skill reads sprint YAML for epic data, reads schema for section requirements, populates template, writes output.

**Key constraints:**
- Schema is the ONLY authority for sections (Rule #2)
- Output naming: `context-epic-{id}.md` (Rule #1)
- No tandem for epic context — single-agent operation

**Test criteria:** Invoking `/pf-context create epic {id}` produces a valid context file that passes `pf context-docs validate epic {id}`.

### 130-2: /pf-context create story Skill (PM-Only Mode)

**What to do:** Extend the skill to handle story context creation. PM reads parent epic context + story YAML, fills story template with frontmatter. This story implements the PM-only path; tandem is added in 130-3.

**Key constraints:**
- Story context MUST have `parent:` frontmatter linking to existing epic context (Rule #8)
- If parent epic context doesn't exist, fail with message — don't create it implicitly
- SM attempts ONE creation per level, then fails (Rule #6)

**Test criteria:** Invoking `/pf-context create story {id}` produces a valid context file with correct frontmatter that passes `pf context-docs validate story {id}`.

### 130-3: Tandem Partner Selection and Integration

**What to do:** Add tandem partner selection to story context creation. Read workflow field → select partner (Rule #5). Spawn backseat via existing tandem protocol. Handle `--no-tandem` flag (Rule #9). Handle backseat failure gracefully (PM continues solo).

**Selection logic:**
- `tdd` or `trivial` → Architect
- `bdd` or `bdd-tandem` → UX-Designer
- `--tandem architect|ux` → explicit override
- `--no-tandem` → skip partner spawn

**Test criteria:** Story context created with tandem includes domain-specific observations (technical guardrails from Architect, interaction patterns from UX-Designer) that wouldn't appear in PM-only mode.

## Constraints

- **Schema-driven:** Skill reads `context-schema.yaml` — never hardcodes section names
- **Skill-based delivery:** Not a BikeLane workflow — invocable by SM or operator
- **One attempt per level:** SM invokes creation once per missing level (epic, story), then fails (Rule #6)
- **Parent required:** Story context cannot be created without existing parent epic context
- **Tandem is optional:** `--no-tandem` always available as escape hatch

## Cross-Epic Dependencies

**Depends on:**
- Epic 129-2 (Context Schema YAML) — defines what sections to include
- Epic 129-4 (Context Document Templates) — provides the base template to fill

**Depended on by:**
- Epic 131-2 (SM Auto-Triggers Context Creation) — SM invokes this skill on gate failure
