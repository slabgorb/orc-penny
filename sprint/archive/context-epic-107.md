# Epic 107: Gate Validation & Authoring

**Jira:** (not yet created)
**ADR:** 0025
**Repo:** pennyfarthing
**PRD:** `sprint/planning/gate-prd.md`

## Overview

Gate schema validation at parse time — catch missing elements, cycles, and excessive nesting before any subagent spawns. Plus an authoring guide and validation command so workflow authors can write custom gates with confidence.

## Stories

| ID | Title | Pts | Priority | Workflow |
|----|-------|-----|----------|----------|
| 107-1 | Gate schema validation at parse time | 3 | P2 | tdd |
| 107-2 | Acyclic validation and depth limit enforcement | 2 | P2 | tdd |
| 107-3 | Gate authoring guide and validation command | 1 | P2 | trivial |

## Prerequisite

**Epic 106** must be complete — gate file schema and at least one gate file (`tests-pass.md`) must exist. This epic adds validation on top of the established format.

## Gate File Schema (Reference)

```xml
<gate name="tests-pass" model="haiku">
  <purpose>What this gate checks</purpose>
  <pass>Pass criteria instructions</pass>
  <fail>Failure report instructions</fail>

  <!-- Optional: nested gates (max depth 3) -->
  <gate name="child-gate" model="haiku">
    <purpose>...</purpose>
    <pass>...</pass>
    <fail>...</fail>
  </gate>
</gate>
```

**Required:** `name` attribute on `<gate>`, `<purpose>`, `<pass>`, `<fail>`
**Optional:** `model` attribute (default: haiku), nested `<gate>` elements

## Story 107-1: Gate Schema Validation at Parse Time

### Validation Rules

| Rule | Error Message |
|------|--------------|
| Missing `name` attribute on `<gate>` | "Gate element missing required 'name' attribute" |
| Missing `<purpose>` | "Gate '{name}' missing required `<purpose>` block" |
| Missing `<pass>` | "Gate '{name}' missing required `<pass>` block" |
| Missing `<fail>` | "Gate '{name}' missing required `<fail>` block" |
| Empty `<pass>` block | "Gate '{name}' has empty `<pass>` block" |
| Empty `<fail>` block | "Gate '{name}' has empty `<fail>` block" |

### Where Validation Runs

Validation should run:
1. **At gate evaluation time** — before spawning the gate subagent (in the agent exit protocol, between resolve-gate and gate subagent spawn)
2. **Via validation command** — `pf gate validate <file>` (story 107-3)

### Implementation Approach

**Option A (recommended): Bash script** — `pennyfarthing-dist/scripts/core/gate-validate.sh`
- Parse XML tags with grep/sed (gate files are simple, not full XML)
- Return structured validation result
- Called by agents before spawning gate subagent
- Called by validation command

**Option B: Python** — add to `pennyfarthing_scripts/`
- Use Python's `xml.etree.ElementTree` or regex
- More robust but adds Python dependency to exit path

### Parsing Strategy

Gate files use a limited XML subset — no attributes beyond `name` and `model`, no CDATA, no namespaces. Simple regex/grep suffices:

```bash
# Check for <gate name="...">
if ! grep -q '<gate[[:space:]].*name=' "$GATE_FILE"; then
  errors+=("Gate element missing required 'name' attribute")
fi

# Extract gate name
GATE_NAME=$(grep -oP '<gate[^>]*name="\K[^"]+' "$GATE_FILE")

# Check required blocks
for block in purpose pass fail; do
  if ! grep -q "<${block}>" "$GATE_FILE"; then
    errors+=("Gate '${GATE_NAME}' missing required <${block}> block")
  fi
done
```

### Validation Output

```yaml
VALIDATE_RESULT:
  valid: true | false
  gate: "tests-pass"
  errors:
    - "Gate 'tests-pass' missing required <fail> block"
  warnings: []
```

---

## Story 107-2: Acyclic Validation and Depth Limit

### Depth Limit

**Hard limit: 3 levels of nesting.**

```
Level 0: <gate name="root">
Level 1:   <gate name="child-1">
Level 2:     <gate name="grandchild-1">
Level 3:       ← MAX DEPTH, anything deeper is rejected
```

**Error:** "Gate depth limit exceeded: {gate-name} at depth 4 (max 3)"

### Cycle Detection

If gate files can reference other gate files (deferred feature), cycles must be detected. For MVP with inline nesting only, cycles are structurally impossible (a file can't nest itself). But the validation should still build a directed graph and check:

```
gate-A → child-B → child-C    ✓ (acyclic)
gate-A → child-B → gate-A     ✗ (cycle: A → B → A)
```

**Error:** "Cycle detected: gate-A → gate-B → gate-A"

### Implementation

Depth counting is straightforward — count nesting level of `<gate>` tags:

```bash
depth=0
max_depth=0
while IFS= read -r line; do
  if echo "$line" | grep -q '<gate[[:space:]]'; then
    ((depth++))
    ((depth > max_depth)) && max_depth=$depth
  fi
  if echo "$line" | grep -q '</gate>'; then
    ((depth--))
  fi
done < "$GATE_FILE"

if ((max_depth > 3)); then
  errors+=("Gate depth limit exceeded at depth $max_depth (max 3)")
fi
```

---

## Story 107-3: Authoring Guide and Validation Command

### Guide File

**Create:** `pennyfarthing-dist/guides/gate-schema.md`

Contents:
1. Gate file purpose and when to create one
2. Complete schema with all elements and attributes
3. Working example (`tests-pass.md` as reference)
4. Nesting rules and depth limits
5. Model attribute and inheritance
6. How gate files are discovered (project-local → built-in)
7. How to test a gate file with the validation command

### Validation Command

**Create:** `pf gate validate <file>`

**Registration:** Add `gate` group to `pennyfarthing_scripts/cli.py` with `validate` subcommand.

```python
@cli.group()
def gate():
    """Gate file operations."""
    pass

@gate.command("validate")
@click.argument("file", type=click.Path(exists=True))
def gate_validate(file):
    """Validate a gate file for schema, cycles, and depth."""
    # Call gate-validate.sh or implement in Python
    # Report ALL errors at once (not just first)
    # On success: "Gate '{name}' is valid (depth: 1, children: 0)"
```

**Key behavior:** Report ALL errors at once, not just the first one. This is critical for authoring experience — authors fix everything in one pass.

### Files to Create

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/scripts/core/gate-validate.sh` | Validation logic (bash) |
| `pennyfarthing-dist/guides/gate-schema.md` | Authoring guide |
| `pennyfarthing_scripts/gate/__init__.py` | Python package |
| `pennyfarthing_scripts/gate/cli.py` | `pf gate validate` command |

### Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing_scripts/cli.py` | Register `gate` group |

## Dependencies

- **Blocked by:** Epic 106 (gate file format must be established)
- **Blocks:** Nothing directly — validation is additive
- **Enhances:** Epic 108 (authors creating new gate files benefit from validation)

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Regex XML parsing misses edge cases | Low | Gate files are very simple XML subset; test with malformed inputs |
| Bash depth counting fragile | Low | Gate nesting is rare in practice; test with synthetic examples |
| Guide becomes stale | Low | Gate schema is small and stable; link from gate files back to guide |
