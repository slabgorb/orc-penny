# Context: Story 125-8 — Event-driven Jira sync on story transitions

**GitHub Issue:** slabgorb/pennyfarthing-orchestrator (PROJ-15429)
**Points:** 3
**Epic:** 125 — Sprint State Engine Consolidation

## Problem

Currently, Jira sync is **batch-only** and **manual**. Users run `pf sprint sync` and `pf sprint reconcile` commands to push changes from sprint YAML to Jira, but this creates a **time window of drift** between when a story transitions locally and when it appears in Jira.

On 2026-02-21, a single reconciliation pass found **11 status mismatches** — proof that batch sync causes drift in production. These mismatches accumulate because:

1. Every `pf sprint story update --status in_progress` changes the YAML but doesn't immediately sync to Jira
2. Users forget to run `pf sprint sync` after updates
3. Other tools (Jira Web UI, external bots) may update Jira directly, and we only discover the mismatch during a manual reconciliation run
4. `pf sprint reconcile` currently **fixes drift by updating YAML** from Jira, but doesn't sync back — creating a one-way sync that hides changes

**After this story:** Every `pf sprint story update` or state transition immediately syncs to Jira in real-time. The batch commands (`pf sprint sync`, `pf sprint reconcile`) become **audit-only tools** that report drift without fixing it. This eliminates the gap and ensures Jira is always the live mirror of sprint state.

## Architecture

### Current Flow (Batch Sync)

```
pf sprint story update 125-8 --status in_progress
  → update_story() modifies YAML in-memory
  → write_sprint() saves to disk
  → (no Jira sync happens)

[User must manually:]
pf sprint sync 125
  → sync_story() for each story
    → fetch current Jira status
    → if different, call transition_async()
  → report results

[Or:]
pf sprint reconcile
  → compare_against_jira()
  → report mismatches
  → optionally --fix (updates YAML from Jira, doesn't sync back)
```

### Target Flow (Event-Driven)

```
pf sprint story update 125-8 --status in_progress
  → validate transition via state machine (125-7)
  → update YAML
  → [NEW] sync_to_jira_async() — immediate, atomic
    → validate Jira issue exists
    → transition_async(PROJ-15429, "In Progress")
    → handle errors, report clearly
  → return result object {success, synced_to_jira, error?}

pf sprint reconcile [--dry-run]
  → [CHANGED] audit-only: compare YAML vs Jira
  → report any mismatches (no --fix option)
  → document what differs and why (e.g., "Jira was updated directly")
```

### Key Files

| File | Role | Change |
|------|------|--------|
| `pennyfarthing-dist/pf/sprint/story_update.py` | Story update command | Add real-time Jira sync call after YAML write |
| `pennyfarthing-dist/pf/jira/sync.py` | Sync implementation | Extract `sync_story()` logic into reusable `sync_single_story_async()` |
| `pennyfarthing-dist/pf/jira/reconcile.py` | Reconciliation report | Remove `--fix` logic, keep audit/report only |
| `pennyfarthing-dist/pf/jira/client.py` | JiraClient | Ensure `transition_async()` is reliable and reports clear errors |
| `pennyfarthing-dist/pf/sprint/state_machine.py` | State machine (125-7) | Dependency: state transitions call sync on success |

### Sync Guarantee

- **Atomic per story:** If YAML updates but Jira sync fails, report the failure immediately so the user can retry
- **Non-blocking:** Jira sync is async; don't block CLI response waiting for API calls
- **Idempotent:** Syncing the same status twice should be safe (no error if already in target state)
- **Clear errors:** If Jira key is missing or transition is invalid, report the exact reason

### Reconcile Becomes Audit-Only

The `reconcile()` function will:
- Still fetch YAML and Jira data
- Still report mismatches, orphans, missing keys
- Remove the `--fix` flag and auto-fix logic
- Remove the `add_to_sprint_sync()` calls
- Output a report explaining drift, not fixing it

Users who need to fix drift will run the report and manually decide to re-sync, re-create, or update Jira directly.

## Acceptance Criteria

### AC1: Story transitions sync to Jira in real-time
- **Given** a story with `jira: PROJ-15429`
- **When** I run `pf sprint story update 125-8 --status in_progress`
- **Then** the YAML updates, and within 5 seconds the Jira issue is transitioned to "In Progress"
- **And** the CLI output confirms "Synced to Jira: PROJ-15429"

### AC2: Sync failures are reported clearly
- **Given** a story with an invalid or missing Jira key
- **When** I update the story status
- **Then** the CLI reports "Failed to sync to Jira: Issue not found" (or other clear reason)
- **And** the local YAML still updates so the user can investigate and retry
- **And** the error doesn't cause a cascade failure to other stories

### AC3: pf sprint reconcile becomes audit-only
- **Given** I run `pf sprint reconcile`
- **When** there are status mismatches between YAML and Jira
- **Then** the report lists all mismatches with details (YAML status, Jira status, story key)
- **And** there is no `--fix` option
- **And** the output suggests manual resolution steps (e.g., "Re-run `pf sprint sync 125` to push YAML to Jira")

### AC4: Reconcile report format remains helpful
- **Given** the reconcile command runs
- **When** I review the report
- **Then** I can understand:
  - How many status mismatches exist
  - Which stories have missing Jira keys
  - Which Jira issues are orphaned (not in YAML)
  - Which stories are not in the Jira sprint

### AC5: Jira sync is idempotent
- **Given** a story is already "In Progress" in both YAML and Jira
- **When** I run `pf sprint story update 125-8 --status in_progress` again
- **Then** the command succeeds without error
- **And** Jira is not unnecessarily transitioned

## Implementation Notes

### Depends on Move 3 (125-7)

Story 125-7 implements the state machine with atomic multi-system transitions. This story (125-8) will integrate with that state machine so that:
1. State machine validates the transition
2. On success, state machine calls Jira sync
3. On Jira sync failure, the state machine reports the error but YAML is already updated (user can retry)

### Integration Point

The state machine transition function will:
```python
def transition_story(story_id, new_status):
  # 1. Validate transition
  if not is_valid_transition(current, new_status):
    raise InvalidTransition(...)

  # 2. Update YAML (from 125-7 state machine)
  update_story(story_id, status=new_status)

  # 3. [NEW for 125-8] Sync to Jira
  result = sync_to_jira(story)  # async, don't block

  # 4. Return success + sync status
  return {
    success: True,
    synced_to_jira: result.get('success'),
    jira_error: result.get('error'),
  }
```

### Reconcile Refactor

Remove this code from `reconcile.py`:
- `--fix` command-line option
- `fix_mode` logic block
- `add_to_sprint_sync()` calls
- "Applying Fixes..." output section

Keep:
- All comparison logic (mismatches, orphans, etc.)
- Report generation
- Clear output sections

Update the report to suggest:
```
Fix mode is no longer supported. To sync changes back to Jira:
  1. Review mismatches above
  2. Run: pf sprint sync <epic_id> --transition --points
```

### Error Handling

When sync fails:
- If issue doesn't exist in Jira: report "Story not linked to Jira (jira field empty or invalid)"
- If transition is invalid in Jira workflow: report "Jira workflow doesn't allow this transition (transition not available)"
- If API error: report "Jira API error: {status_code} {message}"
- For network timeouts: report "Jira sync timeout (connection failed after 10s)"

All errors should be user-actionable, not just "sync failed".

### Testing Strategy

1. **Unit tests** for `sync_to_jira()` function with mocked JiraClient
   - Test successful sync
   - Test missing Jira key
   - Test invalid transition
   - Test idempotent (already in target state)

2. **Integration test** with real Jira endpoint (optional, behind `--integration` flag)
   - Create test story + Jira issue
   - Verify transition propagates

3. **Reconcile tests** verify audit-only behavior
   - Report structure unchanged
   - No `--fix` option exists
   - Mismatches are clearly listed

