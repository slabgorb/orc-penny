---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7]
prd: sprint/planning/context-gate-prd.md
date: 2026-02-23
author: architect (Leonard of Quirm)
status: in-progress
---

# Architecture Decision: Formalized Epic & Story Context Creation

## Architecture Session

### Inputs Gathered
- **PRD:** `sprint/planning/context-gate-prd.md` (297 lines, 8 sequenced deliverables, 26 FRs, 9 NFRs)
- **Existing ADRs (relevant):**
  - ADR-0009: Session File Coordination — session file patterns, phase ownership
  - ADR-0012: Tandem Agent Pairing — tandem protocol, consultation mode, dialogue files
  - ADR-0025: Script-First Gate Extraction — gate file schema, handoff CLI, resolve-gate/complete-phase
- **Existing infrastructure:**
  - `gates/sm-setup-exit.md` — already checks epic context existence (check #3: `story-context-exists`)
  - `gates/context-ok.md` — context window gate (unrelated, naming collision noted)
  - ~50 epic context files in `sprint/context/` (ad-hoc format, no schema)
  - Story context files using `context-story-{N-N}.md` pattern (sparse, only a few exist)
  - No `/pf-context` skill exists yet
  - TEA agent definition does NOT currently reference context documents

### Existing Patterns to Reuse
- **Gate file schema** (`<gate>` XML format) — ADR-0025, already in use
- **Skill directory structure** — `pf-{name}/skill.md` + optional `usage.md`, `examples.md`
- **Tandem protocol** — background backseat observer via `tandem-backseat.md` subagent
- **Session file coordination** — markdown with structured sections, assessment-before-handoff
- **Python CLI (`pf/`)** — validation scripts, sprint data resolution
- **Context files** — ~120 exist with ad-hoc structure, no frontmatter, no schema

### Stakeholders
- **Decision maker:** Keith Avery (project owner)
- **Affected agents:** SM (gate enforcement), PM (context author), Architect (technical review/tandem), UX-Designer (UX tandem), TEA (context consumer), Dev (indirect consumer)

### Key Constraints
- Context creation must work within existing skill invocation infrastructure
- Tandem sessions must reuse existing tandem protocol — no new plumbing
- Gate files follow ADR-0025 `<gate>` schema
- Validation must work from both Python (`pf/`) and TypeScript (Cyclist) — NFR9
- Bug fixes for `checkStoryContext` and `checkEpicContext` may be moot if story 125-3 already removed/replaced those functions with Python subprocess calls

### Open Questions — Resolved

1. **Were `checkStoryContext`/`checkEpicContext` removed by 125-3?** NO — both still exist in `sprint-data.ts:187-201`. Story 125-3 context file _describes_ removing them, but they remain live in the codebase.
2. **Validation script language?** Python — aligns with the `pf/` CLI pattern and NFR9 (dual consumer via subprocess from TS).
3. **SM setup context creation?** Currently SM relies on `generic-sm-setup.ts:checkEpicContext()` which only checks existence. No creation workflow exists — SM warns but doesn't block.

---

## Architecture Context

### Bug Analysis (Confirmed)

**Bug 1: `checkStoryContext` (sprint-data.ts:198-201)**
```typescript
function checkStoryContext(projectDir: string, storyId: string): boolean {
  const contextPath = join(projectDir, 'sprint', 'context', `${storyId}-context.md`);
  return existsSync(contextPath);
}
```
Looks for `125-3-context.md` but actual files use `context-story-125-3.md`. **Every story context check returns false.**

**Bug 2: `checkEpicContext` (sprint-data.ts:187-193)**
```typescript
function checkEpicContext(projectDir: string, epicId: string): boolean {
  const match = epicId.match(/epic-(\d+)/i);
  if (!match) return false;
  // ...
}
```
Regex `\d+` fails for PROJ-keyed epics (e.g., `PROJ-11942`). **PROJ epic context always returns false.**

**Separate impl in `generic-sm-setup.ts:429-447`:** This `checkEpicContext()` takes a raw `epicId` and builds `context-epic-${epicId}.md` directly — no regex. Works for numeric IDs but depends on caller passing the clean ID (not `epic-123` format).

### Technical Constraints (from PRD)

| Constraint | Source | Impact |
|-----------|--------|--------|
| Validation < 2s per file | NFR1 | Script must be fast — no LLM, pure parsing |
| Template population < 30s (non-tandem) | NFR2 | Template is filled by PM agent, not a slow pipeline |
| Full tandem session < 10 min | NFR3 | Acceptable — existing tandem protocol handles timing |
| Gate overhead < 3s | NFR4 | Validation callable by bash, no subprocess startup |
| Dual-consumer (Python + TS) | NFR9 | Python script, TS calls via subprocess (existing pattern from 125-3) |
| No new runtime plumbing | NFR6, NFR7 | Skill invocation + tandem protocol + gate files — all existing |

### Current Landscape

**Three context-checking implementations exist today:**

| Location | What It Does | Bugs |
|----------|-------------|------|
| `sprint-data.ts:checkStoryContext()` | Cyclist sprint panel `hasContext` | Wrong filename pattern |
| `sprint-data.ts:checkEpicContext()` | Cyclist sprint panel `hasContext` | PROJ regex failure |
| `generic-sm-setup.ts:checkEpicContext()` | SM setup gate (soft warn) | Works for numeric, untested for PROJ |

**Existing context file inventory:**
- ~50 epic context files (`context-epic-{N}.md`) — ad-hoc format, no frontmatter, no schema
- ~7 PROJ-keyed epic context files (`context-epic-PROJ-*.md`) — never detected by Cyclist
- Very few story context files (`context-story-{N-N}.md`) — creation is manual, inconsistent

**Gate system (ADR-0025):**
- `sm-setup-exit.md` already has check #3 "story-context-exists" — but only checks epic context existence, not story context
- No separate TEA gate for context validation
- Gate files use `<gate>` XML schema, evaluated by haiku subagent

**Tandem protocol (ADR-0012):**
- Implemented as background backseat observer (`tandem-backseat.md`)
- Session file `**Tandem:**` line triggers spawn
- Observation file at `.session/{story}-tandem-{agent}.md`
- PostToolUse hook injects observations as `[Tandem] {character}: {observation}`

**Skill infrastructure:**
- Skills at `pennyfarthing-dist/skills/pf-{name}/skill.md`
- No `/pf-context` skill exists
- Skills are invoked by name, receive args, can call `pf.sh` CLI

### Key Architectural Concerns

**1. Validation Placement — Where does validation logic live?**
- PRD says "gates call validator" — gate stays pass/fail, validator does the work
- Python script in `pf/` aligns with existing patterns (loader.py, resolver.py)
- TS consumers (Cyclist) call Python via subprocess (established pattern from story 125-3)
- The `sm-setup-exit` gate and new TEA gate both need to call the same validator

**2. Template vs Schema — One document, two concerns**
- Template: what sections to include when creating (PM+tandem fill it in)
- Schema: what sections must be present when validating (gate checks it)
- PRD says "single template with optional sections" controlled by frontmatter `sections:` field
- Risk: template drift from schema if maintained separately

**3. Tandem Orchestration within SM Setup — Complexity hotspot**
- SM gate fails → SM invokes `/pf-context create` → skill spawns PM+tandem → context produced → SM re-runs gate
- This is SM invoking a skill that spawns agents mid-setup — a new pattern
- Fallback (PRD risk): PM-only creation if tandem orchestration is too complex
- Recommendation: keep first impl as PM-only, add tandem in phase 2

**4. Two-Level Context Cascade — Epic gates story**
- Epic context must exist before story context can be created (story context references epic via `parent:` frontmatter)
- SM setup gate checks epic first, then story — sequential cascade
- If both missing, SM creates epic context, then story context — two skill invocations in sequence

**5. `checkStoryContext`/`checkEpicContext` Ownership Question**
- Story 125-3 planned to remove these from sprint-data.ts and delegate to Python
- If 125-3 lands first, the bug fix (PRD deliverable #1) becomes a no-op
- If this lands first, fix the regex/filename patterns, knowing they may be removed later
- Recommendation: fix is trivial (2-line change), deliver it regardless — it's a correctness issue for any build that ships before 125-3

---

## Pattern Analysis

### Technology Stack (Fixed — No Version Discovery Needed)

This is an internal framework extension. All technology choices are predetermined:

| Technology | Usage | Notes |
|------------|-------|-------|
| Python (Click CLI) | Validation script, context CLI commands | Existing `pf/` package pattern |
| TypeScript (Node) | Bug fixes in sprint-data.ts, generic-sm-setup.ts | Existing Cyclist/core packages |
| Markdown + YAML frontmatter | Context document format | Existing context file convention |
| `<gate>` XML schema | Gate file definitions | ADR-0025, 11 gate files in use |
| Skill markdown | `/pf-context` skill definition | Existing skill infrastructure |

### Candidate Patterns

| Pattern | Addresses Concern | Reuses Existing | Complexity | Fit |
|---------|-------------------|-----------------|------------|-----|
| **A. ValidationResult pattern** (validator.py) | #1 Validation placement | `ValidationResult` dataclass, `add_error()` method, severity levels | None — copy existing | 5/5 |
| **B. Gate-calls-script** (ADR-0025) | #1 Validation placement | Gate file `<pass>` section calls `pf context validate`, branches on exit code | None — existing pattern | 5/5 |
| **C. Single-source schema** | #2 Template-schema drift | Template and schema derive from ONE definition file (YAML or Python dict) | Low — one new file | 4/5 |
| **D. Separate template + schema** | #2 Template-schema drift | Template as markdown, schema as Python validation | None — but drift risk | 3/5 |
| **E. SM-invokes-skill** | #3 Tandem orchestration | SM invokes `/pf-context create` skill, skill is PM-driven | Medium — new call pattern for SM | 3/5 |
| **F. SM-creates-inline** | #3 Tandem orchestration | SM reads template, fills from sprint YAML, no skill invocation | None — simple but no tandem | 4/5 |
| **G. Sequential cascade gate** | #4 Two-level cascade | Gate checks epic first, then story; fails with specific error per level | Low — extends existing gate | 5/5 |
| **H. Python _check_context_files pattern** | #5 Bug fixes | `story_detail_data.py:177-208` already has correct filename logic | None — copy to TS | 5/5 |

### Selected Patterns

**1. ValidationResult Pattern (A) + Gate-Calls-Script (B)**

New Python module: `pf/context/validate.py`
- `validate_context_file(path) → ValidationResult` — checks structure, required sections, frontmatter
- `validate_epic_context(epic_id, context_dir) → ValidationResult` — existence + schema
- `validate_story_context(story_id, context_dir) → ValidationResult` — existence + schema + parent link
- CLI: `pf context validate <path>` — exit code 0/1, YAML output for gates

**Why:** Follows `sprint/validator.py` exactly. Gates call `pf context validate`, parse YAML output. No new patterns. The `ValidationResult` dataclass is proven across 10+ validators.

**2. Single-Source Schema (C)**

One YAML definition at `pennyfarthing-dist/templates/context-schema.yaml`:
```yaml
epic:
  required_sections: [Overview, Background, Technical Architecture]
  optional_sections: [Planning Documents, Cross-Story Dependencies]
story:
  required_sections: [Business Context, Technical Guardrails, Scope Boundaries, AC Context]
  optional_sections: [Interaction Patterns, Accessibility Requirements, Visual Constraints]
  required_frontmatter: [parent]
```

Template generation reads this schema. Validation reads this schema. One source, two consumers.

**Why:** Eliminates drift between template and validation. Template is generated from schema, not maintained separately. Schema is the authority.

**3. SM-Invokes-Skill with Tandem (E)**

`/pf-context create story {id}` skill:
- Reads story workflow field → selects tandem partner (tdd/trivial → Architect, bdd → UX-Designer)
- Spawns PM as primary author with tandem partner as backseat observer
- PM reads epic context + sprint YAML + AC, fills template from schema
- Tandem partner injects observations via existing PostToolUse hook
- Produces `context-story-{N-N}.md` in `sprint/context/`

SM gate failure flow: gate fails → SM invokes `/pf-context create` → context produced → SM re-runs gate.

**Why:** The tandem protocol, backseat observer, observation injection, and skill infrastructure all exist. The only new piece is the skill file itself and SM knowing to invoke it on gate failure. Manual escape hatch: operator runs `/pf-context create story {id}` directly without tandem (`--no-tandem` flag).

**4. Sequential Cascade Gate (G)**

Update `sm-setup-exit.md` check #3 from "check epic context exists" to:
1. `pf context validate epic {N}` — if fail, report and stop
2. `pf context validate story {N-N}` — if fail, report and stop

Gate stays declarative. Validator does the work.

**5. Filename Fix (H) — Direct Port**

Copy the correct logic from `story_detail_data.py:196-208`:
- Epic: `context-epic-{epic_num}.md` (extract first part of story ID)
- Story: `context-story-{story_id}.md`

Apply to both `sprint-data.ts` functions. Two-line fix each.

### Rejected Alternatives

- **JSON Schema for context files (D-variant):** Over-engineered. Context files are markdown with YAML frontmatter. A Python validator that checks section headers and frontmatter is simpler and more maintainable than JSON Schema for markdown.
- **SM-creates-inline (no skill):** Simpler but loses tandem collaboration. The whole point is that PM+specialist produce better context than one agent alone.
- **New gate type:** No need. `sm-setup-exit` already has a context check — extend it, don't create a new gate.
- **TypeScript validator:** NFR9 says dual-consumer. Python is canonical; TS calls via subprocess. Writing validation in TS creates a second implementation to maintain.

---

## Component Design

### Component Diagram

```
SM Agent (setup phase)
  │
  │ 1. handoff resolve-gate → sm-setup-exit gate
  │    gate calls: pf context validate epic {N}
  │                pf context validate story {N-N}
  │
  │ 2. If fail → invoke /pf-context create
  ▼
┌─────────────────────────────────────────────────────┐
│  /pf-context Skill                                  │
│                                                     │
│  Reads: story workflow field → selects tandem partner│
│  Spawns: PM (primary) + Partner (backseat)          │
│                                                     │
│  ┌────────────┐    tandem     ┌──────────────────┐  │
│  │ PM Agent   │◄──injection──►│ Architect or UX  │  │
│  │ (primary)  │               │ (backseat)       │  │
│  └─────┬──────┘               └──────────────────┘  │
│        │                                            │
│        │ Reads schema → fills template → writes     │
│        ▼                                            │
│  sprint/context/context-{type}-{id}.md              │
└─────────────────────────────────────────────────────┘
  │
  │ 3. SM re-runs gate → pass
  ▼
TEA Agent (RED phase)
  │ Reads: context-epic-{N}.md + context-story-{N-N}.md
  │ Uses context for test strategy
  ▼
Dev Agent (GREEN phase)
  │ Reads: context files as reference
  ▼
  ...

Separately (bug fix):
┌──────────────────────────────┐
│ sprint-data.ts               │
│ checkStoryContext() ← fix    │
│ checkEpicContext()  ← fix    │
│ hasContext fields → Cyclist   │
└──────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Data Owned | Location |
|-----------|---------------|------------|----------|
| **Context Schema** | Defines required/optional sections for epic and story context | Section definitions, frontmatter rules | `pennyfarthing-dist/templates/context-schema.yaml` |
| **Context Validator** | Validates context files against schema — existence, structure, content, parent links | ValidationResult output | `pf/context/validate.py` |
| **Context Validator CLI** | Exposes validator as `pf context validate {type} {id}` with exit code 0/1 and YAML output | None (delegates to validator) | `pf/context/cli.py` |
| **Context Templates** | Markdown templates generated from schema for epic and story context | Template files | `pennyfarthing-dist/templates/context-epic.md`, `context-story.md` |
| **`/pf-context` Skill** | Orchestrates context creation — reads workflow, selects tandem, spawns PM+partner | Skill definition | `pennyfarthing-dist/skills/pf-context/skill.md` |
| **sm-setup-exit Gate** | Sequential cascade: validate epic context → validate story context → pass/fail | Gate definition | `pennyfarthing-dist/gates/sm-setup-exit.md` |
| **TEA Context Gate** | Validates story context before RED phase | Gate definition | New check in TEA's activation or existing gate |
| **Bug Fixes** | Fix filename pattern and PROJ regex in sprint-data.ts | None (correctness fix) | `packages/cyclist/src/sprint-data.ts` |

### Boundary Decisions

**Boundary 1: Gate → Validator**
- Gate file calls `pf context validate {type} {id}` via bash
- Communication: exit code (0=pass, 1=fail) + YAML on stdout
- Gate parses YAML for check details, maps to GATE_RESULT format
- Validator knows nothing about gates — pure file validation

**Boundary 2: Skill → Agents**
- Skill spawns PM as a Task subagent (haiku model for mechanical template filling, or sonnet if tandem quality matters)
- Tandem partner spawned as background Task subagent using existing tandem-backseat protocol
- Communication: PM writes context file, tandem writes observations, PostToolUse hook injects observations into PM's context
- Skill orchestrates lifecycle: spawn → wait for PM completion → terminate tandem → validate output

**Boundary 3: SM → Skill**
- SM invokes `/pf-context create {type} {id}` when gate fails
- Skill is self-contained — SM doesn't know about tandem internals
- SM re-runs gate after skill completes

**Boundary 4: Schema → Template + Validator**
- Schema YAML is the single source of truth
- Template generation reads schema to produce markdown skeleton
- Validator reads schema to check section presence and frontmatter
- Neither template nor validator hardcodes section names

### Implementation Consistency Rules

> These rules prevent AI agents from making conflicting implementation choices.

1. **Context file naming is canonical:** Epic = `context-epic-{id}.md`, Story = `context-story-{id}.md`. The `{id}` is the raw epic/story ID (e.g., `97`, `PROJ-11942`, `125-3`). No `epic-` prefix in the ID itself.

2. **Schema is the ONLY authority for required sections.** Templates and validators MUST read `context-schema.yaml`. Never hardcode section names in Python, TypeScript, or gate files.

3. **Validator returns ValidationResult, not exceptions.** Follow `sprint/validator.py` pattern: `ValidationResult(valid=bool, errors=[ValidationError(...)])`. Never throw.

4. **Gate calls `pf context validate`, not Python directly.** Gates are evaluated by haiku subagents that run bash commands. The CLI is the interface, not `import pf.context.validate`.

5. **Tandem partner selection follows workflow field.** `tdd`/`trivial` → Architect, `bdd`/`bdd-tandem` → UX-Designer. No other logic. Override via `--tandem` flag only.

6. **SM attempts ONE creation per level, then fails.** Epic missing → create epic → if still fails, stop with message. Story missing → create story → if still fails, stop with message. No retry loops.

7. **Context files live in `sprint/context/` only.** Not `.session/`, not `docs/`. This is where all 120+ existing files live. Don't change the convention.

8. **Story context frontmatter MUST have `parent:` field.** Links to epic context filename (e.g., `parent: context-epic-97.md`). Validator checks the referenced file exists.

9. **`--no-tandem` flag skips partner spawn.** Skill creates context with PM-only. Manual escape hatch for operators and spikes.

10. **Bug fixes are additive, not restructuring.** Fix `checkStoryContext` filename pattern and `checkEpicContext` regex. Don't refactor the surrounding functions or change their signatures.

---

## Interface Definitions

### CLI Commands

**`pf context validate {type} {id} [--context-dir PATH]`**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `type` | yes | `epic` or `story` |
| `id` | yes | Epic ID (e.g., `97`, `PROJ-11942`) or Story ID (e.g., `125-3`) |
| `--context-dir` | no | Override `sprint/context/` default |

**Output (stdout, YAML):**
```yaml
valid: true|false
type: epic|story
id: "97"
file: "sprint/context/context-epic-97.md"
errors:
  - message: "Missing required section: Technical Architecture"
    path: "sections.technical_architecture"
    severity: error|warning
```

**Exit codes:** 0 = valid, 1 = invalid, 2 = file not found

Note: module lives at `pf/context_docs/validate.py` (not `pf/context/validate.py`) because `pf/context.py` already exists for context window checking. CLI registration in `pf/context_docs/cli.py` under `pf context-docs` group, aliased as `pf context validate` via sugar shortcut.

---

**`/pf-context create {type} {id} [--no-tandem] [--tandem architect|ux]`**

This is a **skill**, not a CLI command. Invoked by SM or operator via skill invocation.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `type` | yes | `epic` or `story` |
| `id` | yes | Epic or story ID |
| `--no-tandem` | no | Skip tandem partner, PM-only creation |
| `--tandem` | no | Override partner selection (default: auto from workflow field) |

**Behavior:**
1. Read `context-schema.yaml` for required sections
2. Read sprint YAML for story/epic metadata
3. If `type=story`, verify epic context exists (fail if not)
4. Determine tandem partner (auto or override)
5. Spawn PM agent (Task subagent) with template + context
6. If tandem: spawn backseat observer in background
7. PM fills template, tandem injects observations
8. Write to `sprint/context/context-{type}-{id}.md`
9. Run `pf context validate` on output — if fail, PM fixes
10. Terminate tandem backseat

**Output:** Path to created context file, or error message.

### File Formats

**Context Schema (`pennyfarthing-dist/templates/context-schema.yaml`):**

```yaml
epic:
  required_sections:
    - name: Overview
      description: Epic summary, goals, and scope
    - name: Background
      description: Why this epic exists, what problem it solves
    - name: Technical Architecture
      description: Key technical decisions, component map, data flow
  optional_sections:
    - name: Planning Documents
      description: Links to PRDs, design docs, prior ADRs
    - name: Cross-Story Dependencies
      description: Inter-story dependencies within the epic
  required_frontmatter: []

story:
  required_sections:
    - name: Business Context
      description: Why this story matters, user impact
    - name: Technical Guardrails
      description: Constraints, dependencies, patterns to follow
    - name: Scope Boundaries
      description: What's in scope and explicitly out of scope
    - name: AC Context
      description: Deeper context behind each acceptance criterion
  optional_sections:
    - name: Interaction Patterns
      description: UX flows, user interactions (bdd/bdd-tandem only)
    - name: Accessibility Requirements
      description: A11y constraints (bdd/bdd-tandem only)
    - name: Visual Constraints
      description: Layout, responsive, visual design rules (bdd/bdd-tandem only)
  required_frontmatter:
    - parent  # must reference existing epic context file
  optional_frontmatter:
    - workflow  # tdd, bdd, trivial, etc.
```

**Epic Context File Format (`sprint/context/context-epic-{id}.md`):**

```markdown
# Epic {id}: {title}

## Overview
{content}

## Background
{content}

## Technical Architecture
{content}

## Planning Documents
{content — optional, may be absent}

## Cross-Story Dependencies
{content — optional, may be absent}
```

No frontmatter required for epic context (backward compatible with ~50 existing files).

**Story Context File Format (`sprint/context/context-story-{id}.md`):**

```markdown
---
parent: context-epic-{N}.md
workflow: tdd
---

# Story {id}: {title}

## Business Context
{content}

## Technical Guardrails
{content}

## Scope Boundaries
{content}

## AC Context
{content}

## Interaction Patterns
{content — present only for bdd/bdd-tandem workflows}

## Accessibility Requirements
{content — present only for bdd/bdd-tandem workflows}

## Visual Constraints
{content — present only for bdd/bdd-tandem workflows}
```

### Internal Contracts

**Gate → Validator:**

| From | To | Type | Contract |
|------|----|----- |----------|
| Gate haiku subagent | `pf context validate` | Bash subprocess | Exit code 0/1/2 + YAML stdout |

Gate evaluator runs the command, reads YAML output, maps to GATE_RESULT:
```yaml
# Mapping: pf context validate output → GATE_RESULT
valid: true  → check.status: pass
valid: false → check.status: fail, detail from errors[0].message
exit code 2  → check.status: fail, detail: "Context file not found"
```

**Skill → PM Agent:**

| From | To | Type | Contract |
|------|----|----- |----------|
| `/pf-context` skill | PM subagent (Task tool) | Spawn prompt | Schema + metadata + template instructions |

PM subagent prompt includes:
- Context schema (required sections for this type)
- Sprint YAML data (epic/story metadata, ACs)
- Epic context content (when creating story context)
- Output path
- Instruction: fill each required section, write to output path

**Skill → Tandem Backseat:**

| From | To | Type | Contract |
|------|----|----- |----------|
| `/pf-context` skill | Tandem backseat (Task tool, background) | Spawn prompt per `tandem-backseat.md` |

Backseat parameters:
```yaml
PARTNER: "architect"  # or "ux-designer"
CHARACTER: "{from theme}"
STORY_ID: "{id}"
SCOPE: "context-watch"  # new scope — reviews context quality
OBSERVATION_FILE: ".session/context-{id}-tandem-{partner}.md"
SESSION_FILE: "sprint/context/context-{type}-{id}.md"  # PM's output file
```

Note: `context-watch` scope is a new variant of the existing backseat scopes. The backseat reads what PM is writing and injects domain-specific observations (technical guardrails from Architect, interaction patterns from UX-Designer).

**SM → Skill:**

| From | To | Type | Contract |
|------|----|----- |----------|
| SM agent | `/pf-context create` | Skill invocation | SM says "create epic/story context for {id}" |

SM does not know about tandem internals. Skill is self-contained.

**Validator → Schema:**

| From | To | Type | Contract |
|------|----|----- |----------|
| `validate.py` | `context-schema.yaml` | File read (YAML) | Schema defines section names + frontmatter requirements |

Validator loads schema once, checks file against it. Schema location resolved via `find-root.sh` pattern (walk up to `.pennyfarthing/`).

### Conventions

- **Naming:** Python modules use `snake_case`. CLI commands use `kebab-case` (e.g., `pf context validate`). File names use `kebab-case` (e.g., `context-epic-97.md`).
- **Errors:** Never throw. Return `ValidationResult` objects. CLI maps to exit codes.
- **YAML output:** Always valid YAML. Parseable by both Python and bash (`yq`). Errors are lists of dicts with `message`, `path`, `severity`.
- **Section matching:** Case-insensitive `## {section name}` header match. Validator strips leading `#` and whitespace, compares lowercase.

### Contract Enforcement

1. **Validator output format is frozen.** Any consumer of `pf context validate` depends on the YAML structure above. Add fields, never remove or rename.
2. **Schema file is the interface.** Adding a required section to the schema automatically makes the validator check for it and the template include it. No code changes needed.
3. **Exit code semantics are fixed.** 0 = valid, 1 = invalid (has errors), 2 = file not found. Gates branch on exit code first, then parse YAML for details.
4. **Tandem scope `context-watch` follows existing backseat protocol.** No new observation format, no new hook behavior. Backseat reads and writes to observation file per `tandem-backseat.md`.
5. **Skill argument parsing follows existing skill patterns.** Args are positional (`type`, `id`) with optional flags. No JSON input, no complex parsing.

---

## Risk Assessment

### Technical Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Backward incompatibility with ~50 existing epic context files** | High — gate rejects all existing context, blocking every story | Med | Validator treats missing frontmatter as valid for epics (no frontmatter required). Required sections checked with fuzzy matching (existing files use varied heading styles). Add `--strict` flag for new files only. |
| **`pf/context.py` naming collision** | Med — import confusion, test discovery issues | High | Module at `pf/context_docs/` with CLI group `pf context-docs`, sugar alias `pf cdocs validate`. Avoids any collision with existing context window module. |
| **Tandem backseat fails to spawn or crashes mid-creation** | Low — context still created, just without partner input | Med | PM is primary author and doesn't depend on tandem. If backseat spawn fails, log warning and continue PM-only. Skill catches TaskError on spawn. |
| **Gate cascade adds latency to SM setup** | Med — SM setup takes 3-6s longer | High | Two subprocess calls (`pf context validate epic` + `pf context validate story`). Each < 2s (NFR1). Total < 4s added. Acceptable per NFR4 (< 3s per gate check — the cascade is two checks). |
| **Story 125-3 lands first, removes checkStoryContext/checkEpicContext** | Low — bug fix becomes a no-op | Med | Fix is 2 lines per function. If 125-3 removes them, the fix is harmlessly gone. No wasted effort. |
| **Schema YAML not found at runtime** | High — validator fails, gates fail, all stories blocked | Low | Schema path resolved via `find-root.sh` pattern (proven). Fallback: hardcoded section list in validator if schema file missing. Log warning. |

### Failure Modes

| Component | Failure Mode | Detection | Recovery |
|-----------|--------------|-----------|----------|
| Context Validator | Returns false positive (valid when invalid) | Gate subagent can't find expected sections when reading context | Fix validator logic, re-run gate |
| Context Validator | Returns false negative (invalid when valid) | SM gate fails on context that exists and looks correct | Run `pf context-docs validate` manually, inspect errors. If false negative: check section heading case matching |
| `/pf-context` Skill | PM subagent produces empty/garbage context | Validator catches on post-creation validation step (step 9 in skill flow) | Skill reports failure, SM falls back to manual creation message |
| sm-setup-exit Gate | Cascade logic runs epic check but skips story check | Gate subagent logs show only one `pf context-docs validate` call | Fix gate file check ordering in `sm-setup-exit.md` |
| Tandem Backseat | Observation file never written (backseat stuck) | No observations injected into PM context after 2+ minutes | PM proceeds without observations. Context still valid, just less rich. |
| Bug Fix | Regex fix breaks numeric epic IDs | `checkEpicContext` returns false for ALL epics | TS test for `checkEpicContext` with both numeric and PROJ IDs |

### Security Considerations

Minimal — this is a local developer tool, not a production service:

- **No auth/authz required.** All operations are local filesystem, local CLI.
- **No secrets in context files.** Context documents contain architectural descriptions, not credentials. Schema doesn't define secret-holding sections.
- **File write location constrained.** Context files always go to `sprint/context/`. Validator rejects paths outside this directory.

### AI Implementation Risks

| Risk | Could Cause | Prevention |
|------|-------------|------------|
| **Agent hardcodes section names instead of reading schema** | Template and validator diverge. New section added to schema but validator doesn't check it | Consistency Rule #2: schema is ONLY authority. Code review checks for string literals matching section names |
| **Agent creates validator that throws instead of returning ValidationResult** | Gate subagent can't parse output, defaults to fail | Consistency Rule #3: never throw, return ValidationResult. Sprint validator.py is the reference impl |
| **Agent builds tandem into the validator instead of the skill** | Validator becomes stateful, can't be called from gates | Component boundary: validator is pure file checking, skill orchestrates agents |
| **Agent puts context templates in `.pennyfarthing/templates/` instead of `pennyfarthing-dist/templates/`** | Templates not version-controlled, lost on reinstall | Consistency Rule from CLAUDE.md: modify `pennyfarthing-dist/`, runtime uses `.pennyfarthing/` paths |
| **Agent creates `pf/context/` package, colliding with `pf/context.py`** | Import errors, CLI registration failures | Module named `pf/context_docs/`. Risk explicitly called out in interface spec |
| **Gate agent calls `pf context validate` (no `docs` disambiguation)** | Wrong command, or command not found | Sugar alias from `pf context-docs validate` → `pf cdocs validate`. Gate file specifies exact command |

### Operational Readiness

- **Monitoring:** None needed — local developer tool. Errors surface immediately in agent output.
- **Rollback:** Context validation is additive. If gates are too strict, revert `sm-setup-exit.md` to previous version. One-file rollback.
- **Migration:** Existing ~50 epic context files don't need modification. Validator handles them as-is (no frontmatter required for epics). New story context files created going forward follow the schema.
- **Testing:** Unit tests for validator (section detection, frontmatter parsing, parent link checking). Integration test: create context via skill, validate via CLI, run through gate.

---

## Decision Document

**ADR-0029** written to `docs/adr/0029-context-gate-architecture.md`.

Contains all sections from steps 2-6: context analysis, pattern selection, component design, interface definitions, and risk assessment. 10 implementation consistency rules. 8 sequenced deliverables with dependency map.
