# ADR-0032: Stepped Workflow `<switch>`, `<gate>`, and `<output>` Tag Design

**Status:** Proposed
**Date:** 2026-03-01
**Author:** dev (Korben Dallas)
**Story:** 137-1 (Epic 137: Stepped workflow modernization)

## Context

Stepped workflows use conditional branching extensively but lack a formal vocabulary for it. An audit of ~90 step files across 14 stepped workflows reveals five distinct branching patterns implemented ad hoc:

| Pattern | Occurrences | Mechanism |
|---------|-------------|-----------|
| Mode detection | 1 workflow (quick-dev) | Frontmatter `nextStepFile_modeA/modeB` + state variables |
| User choice menus | 6+ workflows | `<collaboration-menu>`, `<switch>`, `[A]/[P]/[C]/[R]` text |
| Conditional step skipping | 1 workflow (release) | `prerelease_skip_steps` YAML array |
| Continuation detection | 4 workflows | `step-01b-continue.md` + frontmatter `stepsCompleted` |
| Tri-modal routing | 1 workflow (PRD) | `modes:` YAML with separate step directories |

Three problems arise:

1. **`<switch>` is informal.** Some workflows use `<switch>` with `<option>` elements, others use `<collaboration-menu>` with `[A]/[P]/[C]` text, others use inline markdown menus. No consistent schema exists.

2. **`<gate>` is overloaded.** The `<gate>` tag serves two purposes: general prerequisite checklists in agent files (priority tag) and step completion criteria in stepped workflow files. The workflow-step-schema defines `<gate>` but doesn't specify how BikeLane should evaluate it programmatically.

3. **`<output>` is underspecified.** Step `<output>` tags mix deliverable descriptions, markdown templates, and NEXT directives. There is no contract for what a step produces, where it writes, or what format it uses.

### Decision Drivers

1. Step files are prompts consumed by LLMs — tags must be self-documenting
2. `AskUserQuestion` tool exists and should replace text-based menus (story 137-2)
3. BikeLane `pf workflow complete-step` needs machine-readable gate criteria (story 137-3)
4. Backward compatibility — existing step files must continue to work without migration
5. Tags are XML-in-markdown — keep attribute syntax minimal and YAML-like content

## Decision Outcome

### 1. `<switch>` Tag Specification

The `<switch>` tag formalizes conditional branching in step files. It replaces ad-hoc menu patterns with a structured format that can map to `AskUserQuestion` tool calls.

#### Schema

```xml
<switch on="{condition}" tool="AskUserQuestion">
  <case value="{value}" next="{step-file-or-action}">
    {Label} — {Description of what happens}
  </case>
  <case value="{value}" next="{step-file-or-action}">
    {Label} — {Description}
  </case>
  <default next="{step-file-or-action}">
    {Label} — {Description}
  </default>
</switch>
```

#### Attributes

**`<switch>`:**
| Attribute | Required | Description |
|-----------|----------|-------------|
| `on` | No | Variable or condition driving the switch. Omit for user-choice switches. |
| `tool` | No | `AskUserQuestion` to use structured tool call. Omit for agent-evaluated conditions. |

**`<case>`:**
| Attribute | Required | Description |
|-----------|----------|-------------|
| `value` | Yes | Value to match against `on` condition, or user selection label |
| `next` | Yes | Next step file (e.g., `step-03-execute`), action (`EXIT`), or `LOOP` to repeat |

**`<default>`:**
| Attribute | Required | Description |
|-----------|----------|-------------|
| `next` | Yes | Fallback navigation |

#### Examples

**User choice (maps to AskUserQuestion):**
```xml
<switch tool="AskUserQuestion">
  <case value="continue" next="step-04-components">
    Continue — Proceed to Component Design
  </case>
  <case value="revise" next="LOOP">
    Revise — Update pattern selection
  </case>
  <case value="advanced" next="LOOP">
    Advanced Elicitation — Explore unconventional patterns
  </case>
</switch>
```

**State-driven (agent evaluates):**
```xml
<switch on="execution_mode">
  <case value="tech-spec" next="step-03-execute">
    Tech-spec mode — skip context gathering, load spec directly
  </case>
  <case value="direct" next="step-02-context-gathering">
    Direct mode — gather context from user description
  </case>
  <default next="step-02-context-gathering">
    Fallback — treat as direct mode
  </default>
</switch>
```

**Continuation detection (agent evaluates):**
```xml
<switch on="existing_document">
  <case value="true" next="step-01b-continue">
    Existing workflow found — resume from last completed step
  </case>
  <default next="CONTINUE">
    No existing document — proceed with fresh initialization
  </default>
</switch>
```

#### Migration from `<collaboration-menu>`

`<collaboration-menu>` remains valid as a simpler alternative when all options loop (no branching). Use `<switch>` when options lead to different next steps. Story 137-2 will migrate menus that branch.

| Before | After |
|--------|-------|
| `<collaboration-menu>` with all options looping | Keep `<collaboration-menu>` (no change) |
| `<collaboration-menu>` with `[C]` going to next step | Replace with `<switch tool="AskUserQuestion">` |
| Inline `[A]/[P]/[C]` text menus | Replace with `<switch tool="AskUserQuestion">` |
| Frontmatter `nextStepFile_modeA/modeB` | Replace with `<switch on="condition">` |

---

### 2. Enhanced `<gate>` Tag Specification

The `<gate>` tag in workflow step files is enhanced to support programmatic evaluation by `pf workflow complete-step`.

#### Schema

```xml
<gate>
## Completion Criteria
- [ ] {Criterion 1}
- [ ] {Criterion 2}
- [ ] {User confirmation criterion}
</gate>
```

Optionally, a `gate_file` reference for complex validation:

```xml
<gate gate_file="gates/architecture-components">
## Completion Criteria
- [ ] At least 3 components identified
- [ ] Component boundaries justified
- [ ] Dependency graph documented
</gate>
```

#### Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `gate_file` | No | Path to external gate file (relative to `pennyfarthing-dist/`). When present, `pf workflow complete-step` spawns a Haiku subagent with the gate file for evaluation. |

#### Behavior

1. **`gate: true` in `<step-meta>`** — BikeLane enforces the `<gate>` before allowing `complete-step`
2. **`gate: false` in `<step-meta>`** — `<gate>` tag is informational only (agent self-checks)
3. **Inline criteria** — LLM reads checklist and evaluates each criterion against step output
4. **External `gate_file`** — Haiku subagent spawned with gate file for structured evaluation

#### Interaction with `<switch>`

A `<gate>` is evaluated BEFORE the `<switch>`. The step progression is:

```
Execute step → Evaluate <gate> → Present <switch> → Navigate to next
```

If the gate fails, the `<switch>` is not presented. The agent must fix issues and re-evaluate.

#### Distinction from Agent `<gate>` Tags

| Context | Tag | Purpose | Evaluated by |
|---------|-----|---------|-------------|
| Agent files | `<gate>` | Procedural checkpoint / prerequisite | Agent (self-check) |
| Step files | `<gate>` | Step completion criteria | BikeLane / Haiku subagent |

The tag name is intentionally shared — both represent "conditions that must be met before proceeding." The context (agent file vs. step file) disambiguates.

---

### 3. `<output>` Tag Contract

The `<output>` tag is rationalized so every step declares what it produces, where it writes, and what sections are required.

#### Schema

```xml
<output format="{format}" target="{file_path}">
{Description of what this step produces.}

{Markdown template with required sections.}
</output>
```

#### Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `format` | No | Output format: `markdown` (default), `yaml`, `json`. Omit for default. |
| `target` | No | File path to write output (using variable placeholders). Omit when output is conversational (no file written). |

#### Content Contract

The body of `<output>` contains:
1. **Description** — What the step produces (1-2 sentences)
2. **Template** — Markdown template with required sections (if applicable)

#### Removed: NEXT Directives

`NEXT:` directives inside `<output>` are relocated to `<next-step>` or `<switch>` tags. The `<output>` tag is strictly about deliverables.

| Before | After |
|--------|-------|
| `NEXT: Load step-02.md` inside `<output>` | `<next-step>step-02-discovery</next-step>` |
| Conditional NEXT inside `<output>` | `<switch on="condition">` after `</output>` |

#### Examples

**File output with template:**
```xml
<output format="markdown" target="{output_file}">
Add Pattern Analysis section to architecture document.

```markdown
## Pattern Analysis

### Technology Versions (as of {date})
| Technology | Current Version | Notes |
|------------|-----------------|-------|

### Candidate Patterns
| Pattern | Addresses | Trade-offs | Fit Score |
|---------|-----------|------------|-----------|

### Selected Pattern(s)
1. **[Primary pattern]**: [rationale]

### Rejected Alternatives
- [Pattern]: [reason]
```
</output>
```

**Conversational output (no file):**
```xml
<output>
Present the audit findings to the user as a summary table. No file is written.
</output>
```

**YAML output:**
```xml
<output format="yaml" target="sprint/current-sprint.yaml">
Update sprint YAML with validated story assignments.
</output>
```

---

## Step File Tag Order

The recommended tag order in step files is now:

```
# Step N: Title
<step-meta>          # Machine-readable metadata
<purpose>            # What this step accomplishes
<prerequisites>      # What must be true before starting
<instructions>       # Step-by-step execution guide
<actions>            # File operations (Check/Read/Write/Run)
<output>             # What this step produces (deliverable only)
<gate>               # Completion criteria (if gate: true)
<switch>             # Conditional navigation (if branching)
<collaboration-menu> # Simple loop menus (if no branching)
<next-step>          # Linear navigation (if no branching)
```

The `<gate>` → `<switch>` → `<next-step>` ordering reflects execution: validate, then branch or proceed.

## Consequences

### Positive

- **Consistent vocabulary** — All conditional branching uses `<switch>`, all completion validation uses `<gate>`, all deliverables use `<output>`
- **Machine-readable** — `<switch>` maps directly to `AskUserQuestion` tool calls (story 137-2)
- **Programmable gates** — `gate_file` attribute enables `pf workflow complete-step` to evaluate criteria (story 137-3)
- **Clean separation** — `<output>` is about deliverables, `<next-step>` and `<switch>` are about navigation
- **Backward compatible** — Existing `<collaboration-menu>` remains valid; `<gate>` without `gate_file` behaves as before

### Negative

- **Three tag vocabularies for flow control** — `<switch>`, `<collaboration-menu>`, and `<next-step>` overlap. Necessary because they serve different branching semantics.
- **Migration work** — Story 137-2 must update ~90 files to migrate text menus to `<switch>`
- **`<output>` attribute adoption** — Existing step files don't have `format`/`target` attributes; adding them is optional and backward-compatible

### Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| LLMs ignore `<switch>` attributes | Medium | Keep content human-readable inside `<case>` — attributes are hints, content is authoritative |
| `gate_file` spawns add latency | Low | Only used for complex gates; inline checklists remain default |
| NEXT directive removal breaks existing flows | Medium | `<next-step>` tag already exists; migration is mechanical |

## Implementation Consistency Rules

- **R1:** `<switch>` with `tool="AskUserQuestion"` MUST have `<case>` elements with user-facing labels
- **R2:** `<switch>` with `on="{condition}"` MUST be evaluated by the agent, not presented to user
- **R3:** `<gate>` in step files requires `gate: true` in `<step-meta>` for enforcement; otherwise informational
- **R4:** `<output>` MUST NOT contain navigation directives (NEXT, load step, etc.)
- **R5:** `<collaboration-menu>` is valid only when all options loop back (no step transitions)

## Files Affected

| File | Change |
|------|--------|
| `schemas/workflow-step-schema.md` | Add `<switch>` element, update `<gate>` and `<output>` specs |
| `guides/taxonomy/xml-tags.md` | Add `<switch>`, `<case>`, `<default>` to Workflow Step Tags section |
| `workflows/architecture/steps/step-03-patterns.md` | Prototype: add `<switch>` and enhanced `<output>` |

## Related Decisions

- ADR-0013: BMAD Workflow Import — original stepped workflow adoption
- ADR-0025: Script-First Gate Extraction — gate pattern for phased workflows
- ADR-0029: Context Gate Architecture — gate system design
- Story 137-2: Replace static menus with AskUserQuestion (consumes `<switch>` spec)
- Story 137-3: Gate validation for stepped workflows (consumes `<gate>` spec)
