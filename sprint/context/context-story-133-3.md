# Context: 133-3 Create finding format validation gate

## Goal
Create a validation gate script that confirms all Delivery Findings in a session file match the R1 format before downstream compilation (Epic 134) can proceed. This is a quality gate — it catches malformed findings early.

## Technical Approach

### What to build
A Python gate script at `pennyfarthing-dist/src/pf/gates/findings.py` (or similar) that:
1. Parses the `## Delivery Findings` section from a session file
2. Validates each finding entry against R1 format
3. Returns pass/fail with diagnostics

### R1 Finding Format (from ADR)
Each finding is a markdown list item:
```
- **{Type}** ({urgency}): {description}. Affects `{path}` ({what needs to change}). *Found by {Agent} during {human-phase-name}.*
```

### Validation Rules
- **Type** must be one of: `Gap`, `Conflict`, `Question`, `Improvement` (bold, exact match)
- **Urgency** must be one of: `blocking`, `non-blocking` (parenthetical)
- **Description** must be non-empty
- **Affects path** must be present (backtick-wrapped relative path)
- **Agent attribution** must be present (italicized "Found by" suffix)
- **"No upstream findings"** entries are valid (explicit no-findings)
- **Missing section** is valid (legacy backward compatibility — exit 0)

### Exit Codes
- `0` — pass (all findings valid, or no section, or all explicit no-findings)
- `1` — fail (malformed findings detected)

### Output Format
Should report:
- Count of findings parsed
- For failures: which finding failed, what field is missing/invalid, line reference

## Existing Patterns to Follow

### Gate file pattern
Gates are markdown files in `pennyfarthing-dist/gates/`. See `gates/tests-pass.md` for the standard structure:
- `<gate name="..." model="haiku">` wrapper
- `<purpose>` section
- `<pass>` section with check list and GATE_RESULT YAML
- `<fail>` section with recovery guidance

### Gate resolution
`pf/handoff/gate_file.py` resolves gates — checks `.pennyfarthing/gates/` first, falls back to `pennyfarthing-dist/gates/`. The gate runner (`gate_runner.py`) executes the gate as a subagent.

### Two options for implementation

**Option A: Gate markdown only** — Create `pennyfarthing-dist/gates/finding-format-validation.md` that instructs the gate subagent to parse and validate findings inline. No Python script needed. Simpler, follows existing gate pattern.

**Option B: Python script + gate markdown** — Create a Python validation script at `pennyfarthing-dist/src/pf/gates/findings.py` that the gate markdown calls via Bash. More robust, reusable by aggregation (Epic 135).

The epic YAML has `gate: finding-format-validation` suggesting Option A or a hybrid.

## Acceptance Criteria (from PRD)

1. Session with correctly formatted findings → exit 0, reports finding count
2. Finding missing type (no bold `**Gap**` etc.) → exit 1, reports which finding and what's missing
3. Finding with invalid type (e.g., "Bug") → exit 1, reports invalid type
4. Finding with invalid urgency (e.g., "critical") → exit 1
5. All agents wrote explicit "No upstream findings" → exit 0 (valid)
6. No `## Delivery Findings` section (legacy) → exit 0 (backward compatible)

## Key Files
- `pennyfarthing-dist/gates/` — where the gate definition goes
- `pennyfarthing-dist/gates/tests-pass.md` — reference gate format
- `pennyfarthing-dist/src/pf/handoff/gate_file.py` — gate resolution
- `pennyfarthing-dist/src/pf/handoff/gate_runner.py` — gate execution
- `pennyfarthing-dist/agents/sm-setup.md` — session template with Delivery Findings section (from 133-1)
- `.session/133-3-session.md` — active session

## What NOT to Touch
- Agent exit behaviors (that's 133-2)
- Session template structure (done in 133-1)
- Impact Summary compilation (Epic 134)
- Guide documentation (133-4)
