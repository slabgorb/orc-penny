# Story 155-32: Context

## Story Title
finish Step 2: consolidate the back-to-back gh pr view probes (_pr_block_reason + _pr_is_merged pre-check) into one shared call (from 155-29 review)

## Story Type
refactor

## Points
1

## Workflow
tdd

## Repository
pennyfarthing (gitflow — branch off `develop`)

## Background

Filed from the 155-29 review. 155-29 added the already-merged short-circuit to Step 2
of the finish flow. The reviewer noted that in auto merge mode the finish path now
shells out to `gh pr view` twice, back-to-back, for the same PR.

## Current State

`pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py`:

| Location | Probe | `gh` call |
|----------|-------|-----------|
| `_pr_block_reason` (L197) | pre-merge conflict gate | `gh pr view N --json mergeable,mergeStateStatus,baseRefName` |
| `_pr_is_merged` (L180) | merged-state check | `gh pr view N --json state` |

Call sites in `finish_story`:
- L384 — `_pr_block_reason(pr_number)`, gated on `pr_number and merge_mode == "auto"`
- L430 — `elif pr_number and _pr_is_merged(pr_number)` — the 155-29 short-circuit
- L480 — `if not _pr_is_merged(pr_number)` — **post-merge** verification (155-1)

L384 and L430 are the back-to-back pair. L480 is a different thing and must stay separate.

## Technical Approach

One `gh pr view` covering the union of fields (`state,mergeable,mergeStateStatus,baseRefName`),
with the two predicates reading from that shared snapshot. Shape of the refactor
(struct vs. optional-snapshot param vs. small fetch helper) is Dev's call.

## Acceptance Criteria

- **AC-1:** In auto merge mode with a PR present, the pre-merge path issues exactly
  **one** `gh pr view` invocation, not two.
- **AC-2:** Blocking behavior unchanged — a `CONFLICTING`/`DIRTY` PR still aborts finish
  before any irreversible step, with the same actionable rebase message.
- **AC-3:** Short-circuit behavior unchanged — a `MERGED` PR still skips `gh pr merge`
  and records `already_merged: true` on the Step 2 entry.
- **AC-4:** Failure semantics preserved — non-zero `gh` exit or unparseable JSON must
  yield *both* "do not block" and "not merged", so the flow falls through to the real
  merge attempt. An unverifiable PR state must never silently skip the merge.
- **AC-5:** The **post-merge** verification at L480 remains a fresh, separate
  `gh pr view` call. Reusing the pre-merge snapshot there would report the pre-merge
  state and defeat the gh #71/#60 guarantee.
- **AC-6:** Human merge mode still issues no pre-merge probe.

## Regression Surface

These suites exercise the probes and must stay green:

- `test_155_29_finish_short_circuit_merged_pr.py` — asserts probe ordering and error paths
- `test_155_12_finish_conflicting_pr.py` — counts `gh pr view` calls (see L461 comment;
  a call-count assertion there may legitimately need updating to reflect the new count)
- `test_155_1_finish_verifies_merge.py` — post-merge verification
- `test_155_15_finish_blocked_merge_no_stray_archive.py` — no stray archive on abort

Run: `python3 -m pytest pennyfarthing-dist/src/pf/tests/`

## Notes for TEA

The interesting RED cases are AC-1 (call count) and AC-4/AC-5 (a shared snapshot is
exactly the change most likely to break the fall-through and post-merge guarantees).
