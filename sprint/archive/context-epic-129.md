# Epic 129: Context Validation & Visibility

## Overview

Fix the two bugs that prevent Cyclist from showing accurate context status, then build the schema and validator that all downstream context work depends on. This is the foundation epic — everything in Epics 130 and 131 builds on the schema and validator created here.

**Priority:** P1
**Repo:** pennyfarthing
**Stories:** 4 (6 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **PRD** (`sprint/planning/context-gate-prd.md`) | FR1-FR5 (context validation), FR17-FR19 (schema/validator infra), FR25-FR26 (bug fixes), NFR1 (validation perf), NFR9 (dual-consumer) |
| **ADR-0029** (`docs/adr/0029-context-gate-architecture.md`) | Full document — component structure, CLI interface contract, schema definition, consistency rules 1-10, implementation plan items 1-4 |

## Background

### The Two Bugs

Cyclist's sprint panel has a `ContextIndicator` component (`packages/core/src/public/components/panels/SprintPanel.tsx:150-175`) that renders a document emoji when `hasContext === true`. But `hasContext` is never accurately populated because the TypeScript enrichment in `sprint-data.ts` has two bugs:

1. **`checkStoryContext` (never implemented):** The `SprintStory` interface defines `hasContext?: boolean` (line 27) but the `transformCanonicalStory()` function (lines 176-199) never sets it. The field stays `undefined`, which the panel reads as `false`.

2. **`checkEpicContext` (never implemented):** Same pattern — `SprintEpic` interface has `hasContext?: boolean` (line 41) but `transformCanonicalEpic()` never populates it.

The **correct implementation** exists in Python at `pennyfarthing-dist/src/pf/bikerack/story_detail_data.py:177-239`. The `_check_context_files()` function handles both numeric IDs (`context-epic-{N}.md`) and PROJ-keyed epics (glob `sprint/epic-*.yaml`, parse Jira key, try `context-epic-{jira_key}.md`). This Python version is only used by BikeRack story detail — not by Cyclist or gates.

### Why Schema First

ADR-0029 Consistency Rule #2: "Schema is the ONLY authority for required sections." Templates, validators, and the creation skill all read `context-schema.yaml`. Building the schema before anything else prevents drift between components built in different stories.

### Existing Context Files

~145 context files exist in `sprint/context/`. Naming is inconsistent:
- Epic: `context-epic-{N}.md` (numeric) and `context-epic-{JIRA_KEY}.md` (PROJ-keyed)
- Story: Mix of `context-{N-N}.md` and `context-story-{N-N}.md`
- No YAML frontmatter on existing epic contexts
- Section headings vary (Overview, Goals, Technical Approach, Key Files, etc.)

The validator must be backward-compatible with these ~50 existing epic context files.

## Technical Architecture

### Component Map

```
sprint-data.ts (TypeScript, Cyclist)
  |  transformCanonicalStory() → sets hasContext  <-- BUG FIX (129-1)
  |  transformCanonicalEpic()  → sets hasContext  <-- BUG FIX (129-1)
  v
SprintPanel.tsx (React, existing)
  |  ContextIndicator renders 📄 when hasContext === true
  v
context-schema.yaml (YAML, new)                   <-- 129-2
  |  Defines required/optional sections for epic and story context
  v
pf/context_docs/validate.py (Python, new)          <-- 129-3
  |  Reads schema, validates context files
  |  Returns ValidationResult {valid, errors[], file, type, id}
  v
pf/context_docs/cli.py (Python, new)               <-- 129-3
  |  CLI: pf context-docs validate {type} {id}
  |  Exit codes: 0=valid, 1=invalid, 2=not found
  v
pennyfarthing-dist/templates/ (Markdown, new)       <-- 129-4
  |  Generated templates for epic and story context
  |  Sections driven by context-schema.yaml
```

### Key Files (Existing, to be Modified)

| File | Path | Lines | Change |
|------|------|-------|--------|
| Sprint data transforms | `packages/cyclist/src/sprint-data.ts` | 330 | Add context file existence checks in `transformCanonicalStory()` and `transformCanonicalEpic()`. Port logic from Python `_check_context_files()` |
| PF CLI entry point | `pennyfarthing-dist/src/pf/cli.py` | varies | Register `context-docs` Click group |

### Key Files (New)

| File | Path | Purpose |
|------|------|---------|
| Context schema | `pennyfarthing-dist/templates/context-schema.yaml` | Single source of truth for required/optional sections |
| Validator module | `pennyfarthing-dist/src/pf/context_docs/__init__.py` | Package init |
| Validator logic | `pennyfarthing-dist/src/pf/context_docs/validate.py` | Schema-driven validation, returns ValidationResult |
| Validator CLI | `pennyfarthing-dist/src/pf/context_docs/cli.py` | Click commands: `pf context-docs validate epic {id}`, `pf context-docs validate story {id}` |
| Epic template | `pennyfarthing-dist/templates/context-epic-template.md` | Generated from schema, used by `/pf-context create epic` |
| Story template | `pennyfarthing-dist/templates/context-story-template.md` | Generated from schema, used by `/pf-context create story` |

### Key Files (Reference Only)

| File | Path | Purpose |
|------|------|---------|
| Python context check | `pennyfarthing-dist/src/pf/bikerack/story_detail_data.py` | Working implementation at lines 177-239 — reference for TypeScript port |
| React sprint panel | `packages/core/src/public/components/panels/SprintPanel.tsx` | `ContextIndicator` at lines 150-175 — already renders correctly, just needs accurate data |
| Sprint validator | `pennyfarthing-dist/src/pf/sprint/validator.py` | ValidationResult pattern to follow |
| Existing context files | `sprint/context/context-epic-97.md` | Example of a well-structured epic context doc |

### CLI Interface Contract

Per ADR-0029:

```yaml
# pf context-docs validate epic 129
# stdout (YAML):
valid: true|false
type: epic|story
id: "129"
file: "sprint/context/context-epic-129.md"
errors:
  - message: "Missing required section: Technical Architecture"
    path: "sections.technical_architecture"
    severity: error|warning
```

Exit codes: 0 = valid, 1 = invalid, 2 = file not found.

### Schema Definition

Per ADR-0029:

```yaml
epic:
  required_sections: [Overview, Background, Technical Architecture]
  optional_sections: [Planning Documents, Cross-Story Dependencies]
  required_frontmatter: []
story:
  required_sections: [Business Context, Technical Guardrails, Scope Boundaries, AC Context]
  optional_sections: [Interaction Patterns, Accessibility Requirements, Visual Constraints]
  required_frontmatter: [parent]
```

Epic contexts have no required frontmatter (backward compat with ~50 existing files). Story contexts require `parent:` linking to the epic context file.

### Python Module Pattern

New module at `pf/context_docs/` follows established conventions from `pf/sprint/`, `pf/jira/`, `pf/bikerack/`:
- Click group registered in `pf/cli.py`
- `validate.py` contains core logic, returns dataclass result objects (not exceptions)
- `cli.py` wraps logic in Click commands with YAML stdout
- Project root resolution via `find-root.sh` pattern

## Stories

| Story | Title | Points | Workflow | Dependencies |
|-------|-------|--------|----------|-------------|
| 129-1 | Fix Context Check Bugs in sprint-data.ts | 1 | trivial | None |
| 129-2 | Create Context Schema YAML | 1 | trivial | None |
| 129-3 | Build Context Validator Python Module and CLI | 3 | tdd | 129-2 |
| 129-4 | Generate Context Document Templates from Schema | 1 | trivial | 129-2 |

## Story Notes

### 129-1: Fix Context Check Bugs in sprint-data.ts

**What to do:** Add context file existence checks to `transformCanonicalStory()` and `transformCanonicalEpic()` in `packages/cyclist/src/sprint-data.ts`. Port the logic from Python `_check_context_files()` (`story_detail_data.py:177-239`).

**Epic context check:** Try `context-epic-{numeric_id}.md` first. If epic has a Jira key (PROJ-prefixed), also try `context-epic-{jira_key}.md`. Return true if either exists.

**Story context check:** Look for `context-story-{story_id}.md` (canonical pattern per ADR-0029 Rule #1).

**Key constraint:** ADR-0029 Rule #10 — bug fixes are additive. Fix the patterns, don't refactor surrounding code. Two small additions to existing transform functions.

### 129-2: Create Context Schema YAML

**What to do:** Create `pennyfarthing-dist/templates/context-schema.yaml` with the section definitions from ADR-0029. This is the single source of truth that the validator (129-3), templates (129-4), and creation skill (130-1, 130-2) all read.

**Key constraint:** ADR-0029 Rule #2 — schema is the ONLY authority. Never hardcode section names in any downstream component.

### 129-3: Build Context Validator Python Module and CLI

**What to do:** Create `pf/context_docs/` module with `validate.py` (reads schema, validates markdown files against it) and `cli.py` (Click commands with YAML stdout and exit codes).

**Validation logic:**
- Check file exists at canonical path (`sprint/context/context-{type}-{id}.md`)
- Parse markdown headings, match against required sections from schema
- Use fuzzy heading match for backward compatibility (e.g., "Technical Approach" matches "Technical Architecture")
- Check frontmatter fields for story contexts (`parent:` required)
- Return ValidationResult dataclass (not exceptions, per Rule #3)

**Key constraint:** Gate calls CLI, not Python directly (Rule #4). The `pf context-docs validate` command is the interface.

### 129-4: Generate Context Document Templates from Schema

**What to do:** Create template files at `pennyfarthing-dist/templates/context-epic-template.md` and `context-story-template.md`. Templates are generated from `context-schema.yaml` — each required section becomes a heading with placeholder guidance text. Optional sections included with `<!-- optional -->` markers.

**Story template includes frontmatter:**
```yaml
---
parent: context-epic-{N}.md
workflow: {workflow}
---
```

## Constraints

- **Backward compatible:** ~50 existing epic contexts must pass validation without modification (no frontmatter required for epics, fuzzy section heading match)
- **Single source of truth:** Schema YAML is the only authority for section requirements
- **Dual-consumer ready:** Python validator is canonical; TypeScript calls via subprocess (NFR9)
- **Performance:** Validation under 2 seconds per file (NFR1)
- **Naming convention:** `context-epic-{id}.md`, `context-story-{id}.md` — raw ID, no prefix duplication

## Cross-Epic Dependencies

**Depended on by:**
- Epic 130 (Automated Context Creation) — needs schema (129-2) and templates (129-4) to generate context documents
- Epic 131 (Gate-Enforced Context Pipeline) — needs bug fixes (129-1) and validator CLI (129-3) for gate checks
