---
parent: context-epic-141.md
workflow: trivial
---

# Story 141-13: Fix Jira story transition — claim stories as In Progress during setup

## Business Context

When the SM agent runs `pf jira claim {JIRA_KEY}` during story setup (sm-setup Step 3), Jira stories are assigned to the current user but are not transitioned to "In Progress." This means Jira shows the story as "To Do" even though active work has begun, creating a visibility gap for teammates and project managers watching the Jira board. The sprint YAML also stays at `status: backlog` when it should flip to `in_progress`, which causes `pf sprint status` to misreport active work.

The `claim_story()` function in `pf/jira/claim.py` does attempt to call `transition_story()` after assignment, but wraps the entire block in `except Exception: pass` (lines 131–155). Any failure — missing Jira key, story not found in YAML, invalid YAML status, or Jira API error — is silently swallowed. The result is a partial claim: the user is assigned in Jira but the status never moves. Since sm-setup does not check whether the transition succeeded, the bug goes undetected and setup completes with a false appearance of success.

## Technical Guardrails

**Primary file:**
- `pennyfarthing/pennyfarthing-dist/src/pf/jira/claim.py` — `claim_story()` at lines 97–190; the silent `except Exception: pass` at lines 131–155 is the root cause

**Supporting files (understand but do not gratuitously change):**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_transition.py` — `transition_story()` and the `TRANSITIONS` state machine; the valid backlog transition is `backlog -> in_progress`
- `pennyfarthing/pennyfarthing-dist/src/pf/jira/cli.py` — `pf jira claim` Click command (delegates to `claim_main([key, "--claim"])`)
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/cli.py` — `story_claim` command that calls `claim_issue()` from `claim.py`
- `pennyfarthing/pennyfarthing-dist/agents/sm-setup.md` — Step 3 specifies exactly `pf jira claim {JIRA_KEY}` and treats exit code 0 as full success

**State machine constraint:** `story_transition.py` only allows `backlog -> in_progress`. If a story has a non-standard status in the YAML (e.g., `ready`, `planning`), the transition call returns `{success: False, error: "Cannot transition from ..."}`. That error is currently silently dropped.

**Result object pattern:** All functions must return `{success, data?, error?}` — never raise. The fix should surface Jira transition failures in the returned dict without throwing, while still returning overall success when assignment succeeded.

**Return value contract for `claim_story()`:** Callers (`claim_issue()`, the sprint `story_claim` CLI) only read `result.get("success")` and `result.get("actions")`. The fix must preserve this interface.

**Test command:** `cd pennyfarthing && python -m pytest pennyfarthing-dist/src/pf/tests/ -k claim -x` (or equivalent; check for existing claim tests before adding new ones)

## Scope Boundaries

**In scope:**
- Fix the silent `except Exception: pass` in `claim_story()` so that Jira transition failures surface in the returned dict (either as a top-level `error` or in the `actions`/`errors` lists)
- Ensure `transition_story()` is called and its result is checked — if it fails, report the failure in the return value rather than silently continuing
- Handle the case where the story Jira key lookup inside `claim_story()` fails to find the story ID (currently the `story_id` lookup loop at lines 140–149 silently falls through with no transition attempted)
- Update the return dict when transition fails to set `success: False` with a `drift: True` flag and a `remediation` hint (consistent with `story_transition.py`'s own failure format)
- Optionally add a `--force` flag to `pf jira claim` to claim even if the story cannot be transitioned (for edge cases where YAML status is not `backlog`)

**Out of scope:**
- Changes to `story_transition.py` — the state machine and YAML-first write order are correct
- Changes to `sm-setup.md` — the agent calls `pf jira claim {JIRA_KEY}` which is the right command; the fix is in the command itself
- Fixing `start_work()` in `work.py` — that function has a stub body and is not called during sm-setup; it is a separate gap
- Changing the Jira API client or `client.transition_sync()` — those are working
- Bidirectional sync or reconcile behavior — out of scope for this targeted bug fix
- Adding story point sync or assignee sync during claim — only the status transition is in scope

## AC Context

**AC1: `pf jira claim {JIRA_KEY}` transitions the story to "In Progress" in Jira**

When `claim_story()` runs successfully, `transition_story(root, story_id, "in_progress")` must be called and must succeed. The result dict must include `"Moved to In Progress"` in `actions`. Verify by running `pf jira claim PROJ-16156` on a test story and confirming the Jira issue status changes from "To Do" to "In Progress." If `pf jira check PROJ-16156` shows status is not "In Progress" after the claim, the AC fails.

**AC2: Transition failures are reported, not silently swallowed**

If `transition_story()` returns `{success: False}` for any reason (story not found in YAML, invalid current status, Jira API error), `claim_story()` must return a result dict with `success: False`, a descriptive `error` string, `drift: True` (since assignment succeeded but status did not change), and a `remediation` field with the manual fix command (e.g., `pf jira move {JIRA_KEY} "In Progress"`). The caller (sprint CLI or sm-setup) must see a non-success result rather than false-positive success.

Concretely: the current `try/except Exception: pass` block at lines 131–155 of `claim.py` must be replaced with logic that:
1. Captures the exception or failed result
2. Appends an entry to `errors` (not `actions`)
3. Returns `{success: False, drift: True, remediation: ..., errors: [...], actions: [...]}`

**AC3: Story ID lookup failure does not silently skip the transition**

Inside `claim_story()`, the loop that maps `jira_key` back to a `story_id` (lines 140–149) currently falls through without transitioning if no match is found — e.g., when the YAML uses sharded epics and the lookup is reading from `current-sprint.yaml` (which is the shard index, not the merged data). The fix must ensure this failure path is reported rather than silently skipped. One correct approach: use `read_sprint()` (which merges shards) rather than relying on the caller to have a flat in-memory structure. If the story_id cannot be resolved, report it in `errors` and return `success: False`.

**AC4: Sprint YAML status updates to `in_progress` when claim succeeds**

After a successful claim, the story entry in the epic shard YAML (e.g., `sprint/epic-PROJ-16127.yaml`) must have `status: in_progress` and a `started` date set to today. This is handled by `transition_story()` — verify it writes through correctly when called from `claim_story()`. Confirm by reading the shard file directly after a successful `pf jira claim`.
