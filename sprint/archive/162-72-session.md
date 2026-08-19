---
story_id: "162-72"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-72: Jira dry-run and transport truthfulness completion

## Story Details
- **ID:** 162-72
- **Jira Key:** (not applicable — no Jira integration)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-72-jira-dry-run-transport-truthfulness
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** red
**Phase Started:** 2026-08-19T12:44:12Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-19T12:42:58Z | 2026-08-19T12:44:12Z | 1m 14s |
| red | 2026-08-19T12:44:12Z | - | - |

## Sm Assessment

Setup complete for 162-72. Story consolidates loops 162-34/35/36 into one contract: truthful dry-runs (claim/move/create-story must validate before previewing success), single user resolution on the assign path (no re-resolution, respect raw-input rule), credentials guard on sprint-add/link dry-runs, URL-encoded `find_user_sync` query, and a `_call_api_sync` that distinguishes a 204 empty body from a curl failure.

Scope is entirely within `pennyfarthing/` (targets develop). No Jira. Workflow is TDD/phased — routing to TEA for the RED phase to write failing tests against these five contract points before any implementation.

**CLOSURE (2026-08-19, SM):** Closed as **done — already delivered**. TEA measured before writing RED tests and found all five contract points already implemented and merged to develop under the original loops (162-34 #230, 162-35 #231, 162-36 #232), covered by `test_162_34/35/36_*.py` — 176 passing. 162-72 was a consolidation wrapper created during the epic-162 backlog squash (32→12); no code delta. No PR (empty branch), so the finish `merge_pr` step was skipped; status set done via `pf sprint story update`, branch deleted, session archived. Keith authorized "done — delivered" (velocity credit) over cancel.

**ACs (from story description):**
- Dry-run for claim/move/create-story returns failure when the underlying entity is missing or the transition is invalid.
- Assign path resolves the user exactly once; second-stage failures report raw input, not the substituted email.
- Credentials guard present on sprint-add/link dry-runs.
- `find_user_sync` query is URL-encoded.
- `_call_api_sync` no longer returns unconditional success on write ops — a 204 empty body is distinguishable from a curl failure.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

- **Conflict / blocking (TEA, red phase):** Story 162-72 absorbs loops 162-34/35/36, but all three already shipped and merged to develop under their own PRs (#230 truthful dry-runs, #231 assign truthfulness tail, #232 transport 204-vs-failure). Dedicated tests exist and pass: `test_162_34_truthful_jira_dry_runs.py`, `test_162_35_assign_truthfulness_tail.py`, `test_162_36_transport_truthfulness.py` (+ `test_162_7_assign_dry_run_truthful.py`) — 176 passed. All five contract points are verified in source: `_request_sync` distinguishes 204/HTTP-error/curl-failure (client.py:450), `_call_api_sync` returns data only on 2xx (client.py:546), `find_user_sync` uses `urlencode(..., quote_via=quote)` (client.py:679), `move_issue` validates transitions in dry-run (operations.py:54), `assign_issue` resolves the user once before the dry-run branch (operations.py:109-134). No RED phase possible — the work is done. Recommend closing 162-72 as already-delivered rather than running it through TDD.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

No design deviations.