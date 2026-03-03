---
parent: context-epic-137.md
workflow: trivial
---

# Story 137-3: Extend Session Tooling for Unit Status Updates

## Business Context

During batch fan-out, orchestrator spawns parallel agents in worktrees. Each agent works on a unit and must report back unit status changes (pending → in_progress → completed/failed) without clobbering other units in the session file. The orchestrator needs a programmatic way to update individual unit status atomically. This is the foundation for tracking parallel progress and detecting failures that block review gates.

**Why it matters:** Without this tooling, units can't report status after completion, leaving batch session files stale and defeating the purpose of batch visibility. The review gate won't know if a unit failed until manually inspected.

## Technical Guardrails

### fix-phase Command Pattern

The existing `pf workflow fix-phase STORY_ID PHASE` command (from story 105-1) follows this pattern:

1. **Session file discovery**: Find `.session/{story_id}-session.md`
2. **Atomic update**: Use temp file + rename (never in-place edit)
3. **Regex-based patching**: Search/replace phase name, timestamps, history table rows
4. **No XML parsing**: Avoid heavyweight XML libraries; use grep/sed patterns

From `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/src/pf/workflow/cli.py` (lines 779-937):
- Command validates phase sequence before updating
- Collects transitions needed (from_phase → to_phase) via phase_defs tuple
- Updates `**Phase:**` line, `**Phase Started:**` timestamp
- Inserts Handoff History rows at correct table position
- Returns success/error with file path

### Session Units XML Structure

From story 137-2 (adds units element), the session will have:

```xml
<units>
  <unit id="1" status="pending" branch="batch-137-1">
    Add aria-labels to form components A-E
  </unit>
  <unit id="2" status="in_progress" branch="batch-137-2" pr="https://github.com/...">
    Add aria-labels to form components F-J
  </unit>
</units>
```

Valid unit status values: `pending`, `in_progress`, `completed`, `failed`

### Argument Parsing Pattern

Extend `pf workflow fix-phase` with optional `--unit` and `--status` flags:

```bash
# Fix phase (existing behavior)
pf workflow fix-phase 137-1 review

# Update unit status (new behavior)
pf workflow fix-phase 137-1 --unit 2 --status completed
```

When `--unit` is specified:
- Locate `<unit id="2"...>` element
- Update `status` attribute only
- Preserve all other unit attributes (id, branch, pr)
- Preserve all other units unchanged

## Scope Boundaries

**In scope:**
- Extend `pf workflow fix-phase` command to accept `--unit <id> --status <status>` arguments
- Update only the target unit's status attribute in `<units>` XML
- Support all unit status values: `pending`, `in_progress`, `completed`, `failed`
- Atomic file update (temp + rename pattern, no in-place edits)
- Validate unit exists before updating (error if id not found)
- Validate status is one of the four allowed values

**Out of scope:**
- Creating the `<units>` element — that's story 137-2
- Orchestrator agent behavior calling this command — that's story 137-4
- File-overlap checking — that's epic 138
- Workflow YAML — that's story 137-1
- Session schema documentation — that's story 137-2 (modifies session-schema.md)

## AC Context

### AC 1: Command accepts `--unit` and `--status` flags

**Testable:** `pf workflow fix-phase 137-1 --unit 2 --status completed` runs without error

- `--unit` accepts numeric ID (1, 2, ..., N)
- `--status` accepts: `pending`, `in_progress`, `completed`, `failed`
- Both flags required when unit-mode is used (can't have one without the other)
- Command returns success message with unit ID and new status

### AC 2: Updates single unit without clobbering others

**Testable:** After running command, only target unit's status changes; all others remain unchanged

Setup:
```xml
<units>
  <unit id="1" status="pending" branch="batch-137-1">Unit 1</unit>
  <unit id="2" status="in_progress" branch="batch-137-2" pr="https://...">Unit 2</unit>
  <unit id="3" status="pending" branch="batch-137-3">Unit 3</unit>
</units>
```

Command: `pf workflow fix-phase 137-1 --unit 2 --status completed`

Verify:
- Unit 1 remains `status="pending"`, branch unchanged
- Unit 2 now `status="completed"`, branch and pr attributes preserved
- Unit 3 remains `status="pending"`, branch unchanged

### AC 3: Validates unit exists and status value

**Testable:** Command rejects invalid unit ID or status with clear error message

- `pf workflow fix-phase 137-1 --unit 99 --status completed` → Error: "Unit 99 not found"
- `pf workflow fix-phase 137-1 --unit 2 --status invalid` → Error: "Invalid status 'invalid'. Must be one of: pending, in_progress, completed, failed"
- Non-existent story ID still caught as before: "Session file not found"

### AC 4: Preserves all unit attributes except status

**Testable:** pr, branch, id, and unit text content remain unchanged after status update

Before:
```xml
<unit id="3" status="pending" branch="batch-137-3" pr="https://github.com/anthropic/batch-pr-3">
  Implement feature X
</unit>
```

Command: `pf workflow fix-phase 137-1 --unit 3 --status completed`

After:
```xml
<unit id="3" status="completed" branch="batch-137-3" pr="https://github.com/anthropic/batch-pr-3">
  Implement feature X
</unit>
```

### AC 5: Uses atomic file update (no corruption risk)

**Testable:** File update is atomic; session file never in partially-written state

- Write to temp file in same directory
- Rename temp → target (atomic on POSIX)
- Never edit in place
- Cleanup temp on error

## Implementation Notes

### Command Signature

Extend Python Click command in `src/pf/workflow/cli.py`:

```python
@workflow.command("fix-phase")
@click.argument("story_id")
@click.argument("target_phase", required=False)
@click.option("--unit", type=int, default=None, help="Unit ID to update")
@click.option("--status", type=str, default=None, help="New unit status (pending, in_progress, completed, failed)")
@click.option("--dry-run", is_flag=True, help="Preview without making changes")
def workflow_fix_phase_cmd(story_id: str, target_phase: str | None, unit: int | None, status: str | None, dry_run: bool):
    """Update phase or unit status in session file."""
```

### Logic Flow

1. Validate arguments (unit/status must be paired, OR target_phase alone for traditional mode)
2. Find session file
3. Read content
4. If unit mode:
   - Validate unit ID exists in XML
   - Validate status is in {pending, in_progress, completed, failed}
   - Use regex to find and replace: `<unit id="N" status="old_status"` → `<unit id="N" status="new_status"`
5. If phase mode (existing):
   - Use existing phase transition logic
6. Write temp file, rename atomically
7. Return success with confirmation

### Regex Pattern for Unit Status Update

```python
import re

# Match specific unit and replace its status attribute
pattern = r'(<unit id="%d" status=")[^"]*(' % unit_id
replacement = r'\1' + new_status + r'\2'
content = re.sub(pattern, replacement, content)
```

This preserves everything else in the unit element (other attributes, text content, etc.).

## Reference Files

- **Batch PRD** (FR-4): `/Users/keithavery/Projects/pf-1/sprint/planning/batch-prd.md`
- **Epic Context**: `/Users/keithavery/Projects/pf-1/sprint/context/context-epic-137.md`
- **Session Schema**: `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/schemas/session-schema.md` (will be updated in 137-2)
- **Existing fix-phase impl**: `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/src/pf/workflow/cli.py` (lines 779-937)
- **Fan-out/Fan-in Pattern**: `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md`
