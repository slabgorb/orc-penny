# Story Context: 91-12 - Agent Definition Structural Validation

## Summary

Add a `pf validate agent` subcommand that validates the 18 agent definition files in `pennyfarthing-dist/agents/`. Checks required sections (role, critical, helpers, parameters, skills), helper model values (haiku/sonnet/opus), and subagent reference integrity. Follows the existing adapter pattern used by `pf validate sprint` and `pf validate schema`.

## Epic Context

- **Epic 91:** Cross-File Reference & Schema Validation Pipeline (Layer 2: Schema Validation)
- **Layer 2 siblings:** 91-11 (Workflow YAML schema), 91-13 (Skill/command schema)
- **Prior art:** Sprint validator (`validate_cmd.py`), Schema validator (`migration/validate.py`)
- **Epic context:** `sprint/context/context-epic-91.md`

## Current State

### `pf validate` CLI Infrastructure

**Entry point:** `pennyfarthing/pennyfarthing_scripts/validate/cli.py`

Adapter registry pattern:
```python
VALIDATORS = {
    "sprint": "pennyfarthing_scripts.validate.adapters.sprint",
    "schema": "pennyfarthing_scripts.validate.adapters.schema",
}
```

Each adapter implements: `def run(root: Path, *, fix: bool, strict: bool) -> ValidateReport`

**ValidateReport dataclass:** `pennyfarthing/pennyfarthing_scripts/validate/__init__.py`

**Existing validators:**
- `pf validate sprint` — YAML syntax, schema, format, key ordering (40 warnings on current develop)
- `pf validate schema` — XML tag validation for sessions, skills, workflow steps (2 errors, 29 warnings)

### Agent Definition Files (18 total)

**Location:** `pennyfarthing/pennyfarthing-dist/agents/`

**Main agents (10):** sm, dev, tea, reviewer, architect, pm, orchestrator, devops, tech-writer, ux-designer

**Subagents (7):** sm-setup, sm-finish, sm-handoff, sm-file-summary, handoff, reviewer-preflight, testing-runner

**README.md** (1) — documentation, skip validation

### Current Validation Output

Running `pf validate` today shows:
- Sprint: 26 passed, 40 warnings (key order drift)
- Schema: 2 errors (missing `<run>` and `<output>` in a SKILL.md), 29 warnings
- No agent validation exists yet

## Target State

After implementation:
1. `pf validate agent` validates all 18 agent files with distinct rules for main agents vs subagents
2. `pf validate` (no args) includes agent validation alongside sprint and schema
3. Errors for structural issues that would break agent activation
4. Warnings for best-practice recommendations
5. `--strict` flag promotes warnings to errors

## Key Files

### Files to Create

| File | Path | Purpose |
|------|------|---------|
| Agent validator adapter | `pennyfarthing/pennyfarthing_scripts/validate/adapters/agent.py` | Main validation logic |
| Tests | `pennyfarthing/tests/validate/test_agent_validator.py` | Unit tests with fixtures |

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| CLI registry | `pennyfarthing/pennyfarthing_scripts/validate/cli.py` | Add `"agent"` to VALIDATORS dict |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| ValidateReport | `pennyfarthing/pennyfarthing_scripts/validate/__init__.py` | Return type contract |
| Sprint adapter | `pennyfarthing/pennyfarthing_scripts/validate/adapters/sprint.py` | Reference adapter pattern |
| Schema adapter | `pennyfarthing/pennyfarthing_scripts/validate/adapters/schema.py` | Reference adapter pattern |
| Sprint validator | `pennyfarthing/pennyfarthing_scripts/sprint/validate_cmd.py` | Error/warning reporting patterns |
| All 18 agent files | `pennyfarthing/pennyfarthing-dist/agents/*.md` | Subjects of validation |

## Technical Approach

### Architecture: New Adapter

Create `pennyfarthing_scripts/validate/adapters/agent.py` — follows the sprint/schema pattern:

```python
VALIDATORS = {
    "sprint": "...",
    "schema": "...",
    "agent": "pennyfarthing_scripts.validate.adapters.agent",  # NEW
}
```

### Agent Classification

Discover and classify files automatically:
- **Subagents** identified by YAML frontmatter (`---` block with `name:`, `model:` fields)
- **README.md** — skipped
- **Everything else** — main agent

### Validation Rules

#### Main Agent — ERRORS (required)

| Check | What | Why |
|-------|------|-----|
| `<role>` present | One-line role description | Agent identity — activation fails without it |
| `<critical>` present | At least one critical section | Safety rules — agent may misbehave without constraints |
| `<helpers>` present | Subagent table | Agents need to know their available helpers |
| Model value valid | `**Model:**` in helpers must be haiku, sonnet, or opus | Invalid model breaks subagent spawning |
| `<skills>` present | Available slash commands | Agents need to know what commands they can use |

#### Main Agent — WARNINGS (recommended)

| Check | What | Why |
|-------|------|-----|
| `<on-activation>` present | Startup behavior | Best practice, not all agents need it |
| `<exit>` present | Exit/handoff sequence | Best practice for workflow participants |
| `<parameters>` present when helpers exist | Subagent invocation details | Helpers without parameters are incomplete |
| Subagent refs exist as files | Names in helpers table match `agents/*.md` | Catches typos, stale references |

#### Subagent — ERRORS (required)

| Check | What | Why |
|-------|------|-----|
| YAML frontmatter present | `---` delimited block | Subagent identity |
| `name:` field | Subagent identifier | Required for spawning |
| `description:` field | Purpose statement | Required for Task tool |
| `tools:` field | Allowed tools list | Security boundary |
| `model:` field | Must be `haiku` | Cost control — subagents never use Opus |
| `<output>` present | Output format specification | Caller needs to know what to expect |

#### Subagent — WARNINGS (recommended)

| Check | What | Why |
|-------|------|-----|
| `<arguments>` present | Parameter documentation | Best practice |
| `<critical>` or `<gate>` present | Safety constraints | Best practice |

### Edge Cases

1. **Model value case:** Normalize to lowercase (`"Haiku"` → `"haiku"`)
2. **Backtick stripping:** Subagent names in helpers table may be wrapped in backticks
3. **Built-in agents:** Whitelist `Explore`, `Plan` as valid helper references (not file-backed)
4. **Empty helpers:** PM and UX Designer have minimal helpers sections — allow empty tables
5. **Tag variations:** Some agents use `<exit-sequence>` instead of `<exit>` — accept both
6. **Execution format variations:** Reviewer uses `**Pre-flight:** background | **Handoff:** foreground` vs standard `**Execution:** foreground` — match flexibly

### Test Strategy

Test fixtures (minimal markdown files) for:
- Valid main agent (all required sections)
- Valid subagent (frontmatter + required tags)
- Missing `<role>` → error
- Missing `<critical>` → error
- Invalid model value → error
- Subagent with `model: opus` → error
- Missing frontmatter → error
- Non-existent subagent reference → warning
- Built-in agent reference (`Explore`) → no warning
- README.md → skipped
- Strict mode → warnings become errors

## Acceptance Criteria

- `pf validate agent` validates all agent definition files in `pennyfarthing-dist/agents/`
- Main agents checked for required sections: `<role>`, `<critical>`, `<helpers>`, `<skills>`
- Subagents checked for YAML frontmatter with required fields: name, description, tools, model
- Model values validated: haiku/sonnet/opus for main agents, haiku-only for subagents
- Subagent references in helpers tables cross-checked against actual agent files (warnings)
- `pf validate` (no args) includes agent validation in its run
- `--strict` promotes warnings to errors
- README.md is excluded from validation
- Zero false positives on current develop branch agent files
- Tests cover all error and warning cases

## Dependencies

### Depends On

- None — `pf validate` infrastructure already exists

### Depended On By

- **91-13** (Skill/command schema) — similar pattern, may share utilities
- **91-15** (Cross-entity reference validation) — may consume agent metadata

## Risks / Open Questions

1. **False positive risk:** Must run validator against ALL 18 current agent files on develop and verify zero false positives before declaring done. Agents have organic structural variations.

2. **Tag detection approach:** Agents use XML-like tags in markdown (e.g., `<role>...</role>`). Need to decide: regex-based detection vs proper XML parsing. Recommendation: regex (consistent with schema validator approach, tags are markdown-embedded).

3. **Subagent identification heuristic:** Using YAML frontmatter presence to classify. If a main agent ever gets frontmatter, it would be misclassified. Low risk — main agents don't use frontmatter today.

4. **`--fix` support:** Sprint validator supports `--fix` for format issues. Agent validator could potentially fix model casing. Low priority — defer to future if needed.
