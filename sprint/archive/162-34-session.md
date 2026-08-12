---
story_id: "162-34"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-34: Fix remaining false-positive jira dry-runs: claim (pure echo, no lookup — highest-frequency agent-facing path), move (missing issue OR nonexistent target transition both preview as success), create story (parent epic key never validated) — same truthful-dry-run contract as 162-7 (from 162-7 AC4 audit)

## Story Details
- **ID:** 162-34
- **Jira Key:** (Jira not enabled for this project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-34-truthful-jira-dry-runs-claim-move-create
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the title is the full spec (162-7 AC4 audit). Apply 162-7's TRUTHFUL-DRY-RUN contract to THREE jira commands so `--dry-run` previews only what would actually succeed (validate against the real issue/transition/parent state; do NOT echo blind success). Code in `pennyfarthing-dist/src/pf/jira/`.

**First:** read how 162-7 implemented its truthful dry-run (grep `162-7` / the dry-run pattern in `jira/`) and MIRROR it — same contract shape.

Three defects:
1. **claim** (`claim.py` — highest-frequency agent-facing path): dry-run is a PURE ECHO with no lookup. It must look up the issue and report truthfully (issue exists? assignable? already claimed?) instead of always previewing success.
2. **move** (`cli.py` move): a MISSING issue OR a NONEXISTENT target transition BOTH currently preview as success. Dry-run must verify the issue exists AND the target transition is valid/available before previewing success.
3. **create story** (`story.py`): the PARENT EPIC KEY is never validated. Dry-run must verify the parent epic exists before previewing success.

**TEA (RED):** failing tests faking the jira transport/API seam (Jira is disabled locally — the transport is the seam; no live calls). Pin:
- claim dry-run against a missing/unassignable/already-claimed issue → preview reflects the real state, not blind success.
- move dry-run with (a) a missing issue and (b) a nonexistent target transition → each previews FAILURE, not success.
- create-story dry-run with a nonexistent parent epic → previews FAILURE, not success.
- Guard tests: the happy path (valid issue/transition/epic) still previews success (don't over-abort).

**Constraints (binding):** scoped runs — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/<jira tests>.py -q`. NEVER full suite. Fake the transport; no network. Result objects `{success, error?}`, not throws. `ruff check`. Match 162-7's contract exactly so the four dry-run paths are consistent.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_34_truthful_jira_dry_runs.py` — truthful dry-run contract for claim / move / create-story, mirroring 162-7

**Tests Written:** 13 tests covering 5 ACs (AC1 claim state, AC2 move missing issue, AC3 move unavailable transition, AC4 create-story parent epic, AC5 guards + no-write)
**Status:** RED — 8 failing, 5 passing (guards / rule-6 integrity, which must stay green)

**Seam:** `get_client` monkeypatched in `pf.jira.claim`, `pf.jira.operations`, `pf.jira.create` with a `_StubJiraClient` that records reads and writes separately. No network.

**Contract Dev must implement:**
- `JiraClient.get_transitions_sync(issue_key) -> list[dict] | None` — read-only transition list; `None` means the issue does not exist (so "no transitions" is never confused with "transition unavailable"). Extract from the GET inside `transition_sync` and reuse it there.
- `move_issue(..., dry_run=True)` — verify the issue exists AND the target transition is offered before previewing; error text names the key and lists available transitions.
- `pf jira move --dry-run` CLI must not print `Moved ...` and must exit non-zero on failure (today it prints both the dry-run line and `Moved`).
- `pf jira claim --dry-run` must run the real availability lookup (`check_availability`) — no pure echo — exiting non-zero for missing / already-claimed, naming the assignee, and writing nothing.
- `create_story_in_jira(..., dry_run=True)` must validate the parent epic key against Jira (`get_issue_sync`), not just the sprint YAML.

**Failing output (one line each):**
- `test_claim_dry_run_fails_for_missing_issue` — previewed success for a nonexistent issue: `[DRY-RUN] Would claim PROJ-999 ...`
- `test_claim_dry_run_looks_the_issue_up` — never looked the issue up; it echoed the input
- `test_claim_dry_run_fails_when_already_claimed` — previewed success for an already-claimed issue
- `test_move_dry_run_fails_for_missing_issue` — `{'success': True, 'dry_run': True}` for a missing issue
- `test_move_dry_run_fails_for_unavailable_transition` — `{'success': True, 'dry_run': True}` for a transition Jira does not offer
- `test_move_cli_dry_run_exits_nonzero_for_unavailable_transition` — exited 0 and printed `Moved PROJ-1 to 'Shipped'`
- `test_create_story_dry_run_fails_for_missing_parent_epic` — `{'success': True, 'dry_run': True, ...}` with a parent epic absent from Jira
- `test_create_story_dry_run_validates_parent_against_jira` — never asked Jira whether the parent epic exists

**Commit:** `907f7d505` (signed)
**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/jira/client.py` — extracted `get_transitions_sync(key) -> list[dict] | None` (None = transitions unreadable/issue absent); `transition_sync` now calls it, so dry-run and real path share one resolution rule (mirrors 162-7's `find_user_sync`)
- `pennyfarthing-dist/src/pf/jira/operations.py` — `move_issue(dry_run=True)` fails for a missing issue and for a target status Jira does not offer; error lists the available transitions. No print — callers own output
- `pennyfarthing-dist/src/pf/jira/cli.py` — `claim --dry-run` runs `check_availability` (real lookup): missing → `not found` + exit 2, already-claimed → names the assignee + exit 1, no writes. `move --dry-run` prints `[DRY RUN] Would move ...` instead of `Moved ...` and exits non-zero on failure
- `pennyfarthing-dist/src/pf/jira/create.py` — `create_story_in_jira(dry_run=True)` validates the parent epic key against Jira via `get_issue_sync` before previewing; nonexistent parent → FAILURE

**Partial work from the interrupted attempt:** REUSED. The uncommitted `client.py` / `operations.py` / `cli.py` (claim) changes were correct and complete against TEA's contract — verified by test run (11/13 passing with them in place). Only `create.py` (AC4) was missing, plus the `move` CLI dry-run preview line the contract required.

**Tests:** 13/13 passing (GREEN) — `src/pf/tests/test_162_34_truthful_jira_dry_runs.py`, all 5 guards still green (no over-abort)
**Regression:** 214 passed — jira batch (152-1, 152-2, 156-2, 158-5, 160-3, jira_cli_disabled_gate, jira_package, event_driven_jira_sync, story_transition, 162-7 assign dry-run)
**Lint:** `ruff check` clean on all 4 changed files
**Commit:** `0f8866c74` (signed, verified)
**Branch:** feat/162-34-truthful-jira-dry-runs-claim-move-create (pushed)

**Handoff:** To Reviewer

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 62 passed / 0 failed, ruff clean, tree clean, no code smells | N/A |
| 2 | reviewer-security [SEC] | Yes | clean | none — all 3 dry-run branches provably GET-only; no token/email/URL leakage; `is_jira_enabled` gate still fires first; issue-key-in-URL is pre-existing and non-shell (`subprocess` list, no `shell=True`) | CONFIRMED clean |
| 3 | reviewer-test-analyzer [TEST] | Yes | findings | 5: (a) `test_claim_dry_run_writes_nothing` has no exit-code assert — passes on a crash; (b) no CLI-level `move --dry-run` happy-path test; (c) no stub-integrity test (162-7 has one); (d) epic with no `jira` key at all untested; (e) `test_move_dry_run_never_raises` parametrizes status but not issue key | (a),(b) CONFIRMED → [LOW] finding 3 below (I verified both paths manually). (c),(d),(e) CONFIRMED but [LOW] — logged as follow-up, not blocking. Its "incomplete-mock" reasoning self-refutes: the `get_client` seam IS correctly patched per-module. |
| 4 | reviewer-type-design [TYPE] | Yes | findings | 3: (1) `str(t.get("name")).lower()` can yield `"none"` and pollute the error list; (2) `create story` CLI uses `not result.get("dry_run")` as a failure-suppression guard (fragile vs `move`'s explicit if/elif); (3) dry-run + `already_at_status` returns no `dry_run` key, so that one path prints without a `[DRY RUN]` prefix | (1) CONFIRMED [LOW] — requires a nameless Jira transition AND target literally `"None"`; cosmetic. (2) CONFIRMED but PRE-EXISTING (`cli.py:358`, not in the diff) and correct today (failed dry-runs carry no `dry_run` key) → [LOW] follow-up. (3) CONFIRMED [LOW] — output is still truthful (no write happens or is needed) and it matches 162-7's `already_assigned` precedent, so it is contract-consistent, not a regression. Verified the tri-state `None` vs `[]` contract is honored at both call sites and the `transition_sync` refactor is behavior-preserving — matches my own analysis. |
| 5 | reviewer-rule-checker [RULE] | Yes | clean | 0 violations across 8 rules / 31 instances — all edits under `pennyfarthing-dist/`, no sprint YAML touched, rule-6 result dicts everywhere, `SystemExit` in Click commands matches sibling convention, lazy imports preserved, `get_transitions_sync` docstring/type hints match its siblings | CONFIRMED clean |

**All received: Yes** (5 of 5 enabled subagents returned). No specialist finding rose above [MEDIUM]/[LOW]. Nothing blocking.

## Reviewer Assessment

**Verdict:** APPROVED

**Tests (run by Reviewer):** `uv run pytest src/pf/tests/test_162_34_truthful_jira_dry_runs.py src/pf/tests/test_162_7_assign_dry_run_truthful.py -q` → **62 passed**. `ruff check src/pf/jira/` clean. Working tree clean.

**Per-defect soundness:**
1. **claim** (`cli.py:87-101`) — SOUND. `--dry-run` calls `check_availability(key)`, a real `get_issue_sync`. Missing → `Failed: PROJ-999 not found` + exit 2; already-claimed → names the assignee + exit 1. No writes (stub `writes` stays empty). Not an echo — `issue_reads` proves the lookup.
2. **move** (`operations.py:53-68`, `cli.py:122-124`) — SOUND at both layers. Missing issue → failure naming the key; unavailable target → failure listing available transitions. CLI prints `[DRY RUN] Would move ...` and never `Moved`, exits non-zero on failure. `get_transitions_sync` is used, and the `transition_sync` refactor is **semantics-preserving**: old `if not transitions_data:` ⇔ new `if transitions is None:` (helper returns None exactly when the payload is falsy), same `.get("transitions", [])`. No duplicated resolution logic, no change to the real path.
3. **create-story** (`create.py:105-115`) — SOUND for the documented calling form. Validates `epic.get("jira") or epic_jira_key` via `get_issue_sync` before previewing; nonexistent parent → FAILURE. See finding 1 for the epic-id form.
4. **Guards** — verified no over-abort. Reviewer probed the two CLI happy paths not covered by the suite: `claim PROJ-1 --dry-run` → exit 0, `[DRY-RUN] Would claim PROJ-1 ...`; `move PROJ-1 "In Progress" --dry-run` → exit 0, `[DRY RUN] Would move PROJ-1 to 'In Progress'`, no `Moved`.
5. **Contract consistency with 162-7** — consistent, and slightly stronger: `move_issue` resolves issue existence *and* transition availability before the dry-run branch, the same "resolve before preview, callers own output, result dicts only" shape as `assign_issue`. Both keep the resolution rule in one place (`find_user_sync` / `get_transitions_sync`).
6. **Test hygiene** — GOOD. Transport faked at the `get_client` seam in all three modules; `is_jira_enabled` patched so the group gate doesn't short-circuit; no network. Reads and writes recorded separately, so "read the real state" and "wrote nothing" are both provable. Negative assertions present (`"would claim" not in output`, `"moved" not in output`). RED-for-right-reason documented per test with the actual false-positive output.

**Data flow traced:** `pf jira claim PROJ-999 --dry-run` → group gate (`is_jira_enabled`) → `check_availability` → `JiraClient.get_issue_sync` (GET only) → `available: False, exit_code: 2` → stderr + `SystemExit(2)`. No mutating client method is reachable on the dry-run branch in any of the three paths.

**Specialist incorporation:** [SEC] clean — every `--dry-run` branch is provably GET-only (`get_issue_sync` / `get_transitions_sync`); no mutating client method is reachable, no credential/email/internal-URL leakage in the new error strings (`assigned_to` is `displayName` only), and the group's fail-closed `is_jira_enabled()` gate still runs before all three new branches. [RULE] clean — 0 violations across 8 rules / 31 instances: all edits under `pennyfarthing-dist/`, no sprint YAML touched, rule-6 result dicts on every new return, `SystemExit` in Click commands matches the sibling `check`/`move` convention, lazy imports preserved, `get_transitions_sync` docstring and type hints match its client.py siblings. [TEST] and [TYPE] findings are all [LOW] and are carried in the table below plus the Delivery Findings.

**Findings (none blocking):**
| Severity | Issue | Location | Fix |
|----------|-------|----------|-----|
| [MEDIUM] | Dry-run validates `epic.get("jira") or epic_jira_key`, but the real create still sends `"parent": {"key": epic_jira_key}` (the raw arg). Because the epic lookup also matches `e.get("id")`, `create story 162 162-34 --dry-run` previews SUCCESS (validated PROJ-100) while the real create would POST `parent: {"key": "162"}` and fail. Verified by probe. | `create.py:107` vs `create.py:133` | One-line follow-up: real path should resolve the same key. Strict improvement over pre-162-34 (no lookup at all), so non-blocking. |
| [LOW] | `claim --dry-run` validates assignability only; the real claim also transitions to In Progress, whose availability is not checked. Partial truthfulness — meets AC1 as written. | `cli.py:87-101` | Follow-up: also check the In Progress transition. |
| [LOW] | `test_claim_dry_run_writes_nothing` asserts only `writes == []`, which holds even if the command crashed — no `exit_code` assertion. No CLI-level test for the `move --dry-run` success branch either. Reviewer verified both manually. | `test_162_34...py:286`, `:332` | Add exit-code assertions. |
| [LOW] | Availability-failure message formatting duplicated between `cli.py` dry-run and `claim.main()`. | `cli.py:91-99` | Shared formatter (already logged by Dev). |
| [LOW] [TYPE] | `available = [t.get("name") for t in transitions]` then `str(n).lower()` — a nameless transition becomes the string `"none"` in both the match set and the user-facing error list. | `operations.py:62-63` | `[t["name"] for t in transitions if t.get("name")]`. |
| [LOW] [TYPE] | `--dry-run` + issue already at the target status returns `{success, already_at_status}` with no `dry_run` key, so the CLI prints `already at '...'` with no `[DRY RUN]` prefix — the one dry-run outcome without one. Still truthful (no write happens or is needed) and it matches 162-7's `already_assigned` precedent. | `operations.py:51` | Optional: tag the early return with `"dry_run": dry_run` in both `move_issue` and `assign_issue` together. |
| [LOW] [TYPE] | PRE-EXISTING (not in this diff): `create story` CLI suppresses the failure branch with `not result.get("dry_run")` rather than `move`'s explicit `already_at_status → dry_run → success → else` chain. Correct today because failed dry-runs carry no `dry_run` key, but it would silently swallow a future `dry_run`-tagged failure. | `cli.py:358` | Mirror the `move` if/elif chain. |
| [LOW] [TEST] | No stub-integrity test (162-7 has `TestStubIntegrity`), so a future seam change could let these tests pass vacuously. Also untested: an epic with no `jira` key at all, and `test_move_dry_run_never_raises` varies the status but always uses `MISSING_ISSUE`. | `test_162_34...py:189, 393` | Add a stub-integrity test + widen the parametrize. |

**`create_epic_in_jira` out-of-scope check: CONFIRMED out of scope.** Its dry-run has its own inline child-preview loop (`create.py:311-313`) and never calls `create_story_in_jira(dry_run=True)`, so 162-34's fix cannot reach it; it also fabricates `epic_jira_key = "PROJ-XXXXX"` (`create.py:234`). Same false-positive class, separate code path, needs its own story.

**Deviation audit:** session records "No design deviations" — confirmed against the diff. The only spec drift is the SM's `story.py`/`claim.py` file pointers, already logged by TEA as a Delivery Finding (defect actually lives in `create.py` and the `claim` command in `cli.py`). ACCEPTED — pointer error, not a design deviation.

**Handoff:** To SM for finish-story

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T11:07:11Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T21:24:32Z | 2026-08-11T21:25:49Z | 1m 17s |
| red | 2026-08-11T21:25:49Z | 2026-08-11T22:28:59Z | 1h 3m |
| green | 2026-08-11T22:28:59Z | 2026-08-12T10:54:34Z | 12h 25m |
| review | 2026-08-12T10:54:34Z | 2026-08-12T11:07:11Z | 12m 37s |
| finish | 2026-08-12T11:07:11Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### TEA (test design)
- **Gap** (non-blocking): the create-story defect lives in `pf/jira/create.py` (`create_story_in_jira`), not `pf/jira/story.py` as the SM pointer said — `story.py` only holds the CLI wiring. Affects the Dev pointer only.
- **Improvement** (non-blocking): `JiraClient` has no read-only transition lookup; `transition_sync` inlines the GET. Affects `pf/jira/client.py` (extract `get_transitions_sync` and have `transition_sync` call it, so dry-run and real path share one resolution rule — the same shape 162-7 used for `find_user_sync`).

### Dev (implementation)
- **Improvement** (non-blocking): `create_epic_in_jira` dry-run still fabricates a parent key (`epic_jira_key = "PROJ-XXXXX"`) and previews child-story creates without any Jira lookup — the same false-positive class as the three fixed here, one level up. Affects `pf/jira/create.py` (`create_epic_in_jira`); out of 162-34's scope. *Found by Dev during implementation.*
- **Improvement** (non-blocking): `pf jira claim --dry-run` now duplicates availability-failure formatting that `claim.main()` already owns. Affects `pf/jira/cli.py` — a shared formatter would keep the dry-run and real messages from drifting. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking): `create_story_in_jira`'s real path posts `"parent": {"key": epic_jira_key}` (the raw argument) while the new dry-run validates `epic.get("jira") or epic_jira_key`. Since the epic lookup also matches `e.get("id")`, `pf jira create story 162 162-34 --dry-run` previews SUCCESS but the real create would POST `parent: {"key": "162"}` and fail. Affects `pf/jira/create.py` (the real path should resolve the same key the dry-run validates — one line). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `pf jira claim --dry-run` validates assignability only; the real claim also transitions the issue to In Progress, and that transition's availability is never checked. Affects `pf/jira/cli.py` / `pf/jira/claim.py` (add a `get_transitions_sync` check to make the claim preview fully truthful). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): CONFIRMS Dev's finding — `create_epic_in_jira`'s dry-run is genuinely out of 162-34's scope: it previews child stories through its own inline loop (`create.py:311-313`) and never calls `create_story_in_jira(dry_run=True)`, plus it fabricates `epic_jira_key = "PROJ-XXXXX"`. Affects `pf/jira/create.py` — needs its own story to close the last dry-run false positive in the family. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): two dry-run CLI success paths have no test — `claim --dry-run` exit 0 and `move --dry-run` printing `[DRY RUN] Would move`; `test_claim_dry_run_writes_nothing` would also pass if the command crashed (no exit-code assertion). Reviewer verified both manually. Affects `pf/tests/test_162_34_truthful_jira_dry_runs.py`. *Found by Reviewer during code review.*

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

No design deviations

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->