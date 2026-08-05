---
story_id: "162-7"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-7: pf jira assign --dry-run false-positive success + ambiguous identifier contract (gh #146)

## Story Details
- **ID:** 162-7
- **Jira Key:** (none — no Jira integration for this story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-7-jira-assign-dry-run-truthful
- **PR:** #179

## Acceptance Criteria

- AC1: pf jira assign --dry-run performs the real user lookup and fails loudly (non-zero, 'User not found: X') for unresolvable identifiers, without mutating the issue
- AC2: dry-run and real output both print the resolved Jira account (email + display name) that will be assigned
- AC3: help text clarifies USER means GitHub username or Jira account email, and that non-Jira emails will not resolve
- AC4: Audit + fix sibling --dry-run false-positive paths (at minimum pf jira sprint add)

## Story Type
Bug

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-05T15:16:45Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-05T14:36:08.507984Z | 2026-08-05T14:37:39Z | 1m 30s |
| red | 2026-08-05T14:37:39Z | 2026-08-05T14:53:45Z | 16m 6s |
| green | 2026-08-05T14:53:45Z | 2026-08-05T15:04:26Z | 10m 41s |
| review | 2026-08-05T15:04:26Z | 2026-08-05T15:16:45Z | 12m 19s |
| finish | 2026-08-05T15:16:45Z | - | - |

## Context Summary

**Background:** gh #146 reported two distinct truthfulness bugs in `pf jira assign KEY USER`.

**Bug 1 — False-Positive Success:** The `--dry-run` flag echoes the input verbatim and prints 'Assigned ...' without resolving the user against Jira. Example: `pf jira assign MSSCI-18553 slabgorb@gmail.com --dry-run` reports success while the real call then fails 'User not found'. The dry-run is useless for validating an identifier before a live call. **Same pattern reportedly exists in `pf jira sprint add`.** Audit and fix at minimum both paths.

**Bug 2 — Ambiguous Contract:** The help text says "email or GitHub username" but is ambiguous about which email: must be the Jira ACCOUNT email (corporate SSO, e.g. `keith.avery@1898andco.io`), not any personal email. A non-Jira email looks valid until the real call fails. Only the GitHub username resolved in the live session.

**Fix Scope:**
1. Make `--dry-run` perform the **real user lookup** and fail loudly (non-zero, `User not found: X`) without mutating the issue.
2. Print the **resolved Jira account** (email + display name) in both dry-run and real output.
3. Clarify help text: `USER: GitHub username, or the user Jira account email; non-Jira emails will not resolve`.
4. Audit sibling `--dry-run` paths for the same false-positive pattern (e.g. `pf jira sprint add`).

**Design Constraint:** Dry-run doing a real READ-ONLY lookup requires credentials. Tests must stub the Jira client boundary (proven pattern in 162-5's test_153_4 `get_client` stub with integrity tests). **Decide and document behavior when credentials are absent in dry-run:** fail loudly with a distinct message, not false success. The test suite (from 162-5) must stay exit 0.

**Jira Code Location:** `pennyfarthing-dist/src/pf/jira/`

## Sm Assessment

**Scope:** 3-pt p2 bug (gh #146), TDD. Two truthfulness bugs in `pf jira assign KEY USER`: dry-run false-positive success (echoes input, prints 'Assigned' without resolving), and ambiguous email contract (Jira ACCOUNT email vs any email). Plus AC4: audit sibling --dry-run paths (at minimum `pf jira sprint add`) for the same false-positive pattern.

**Technical approach for TEA:** Code in `pennyfarthing-dist/src/pf/jira/`. Failing tests: (1) dry-run with unresolvable identifier → non-zero exit, 'User not found: X', issue NOT mutated (assert no write call reaches the client); (2) dry-run AND real run print the RESOLVED account (email + display name); (3) credentials absent in dry-run → loud distinct failure, never false success; (4) help text pins the identifier contract; (5) sibling audit — enumerate all --dry-run paths in the jira package, pin the false-positive pattern out of at least `pf jira sprint add`. Stub the client at the get_client boundary per the 162-5 pattern WITH stub-integrity tests (one proving a stubbed lookup FAILURE propagates).

**Decision pre-authorized:** dry-run performs the real read-only lookup. Absent credentials → fail loudly with a message distinct from 'User not found' (e.g. 'Cannot validate user: no Jira credentials'). Return-result discipline (rule 6): `{success, data?, error?}`, no throws.

**Acceptance criteria:** the 4 ACs in the section above, verbatim from story YAML.

**Suite discipline:** 162-5 retired the baseline — suite stays exit 0; only your reds until Dev lands.

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED — 30 failing, 13 passing (the passers are regression guards on behavior that is already correct: dry-run not writing, the mutating paths still mutating, the user_map mapping path).

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_7_assign_dry_run_truthful.py` — 43 tests, all 4 ACs plus the designed client boundary and stub integrity.

**Tests Written:** 43 tests covering 4 ACs (30 currently red).

### Designed interface — Dev implements to this

**New read-only lookup on JiraClient** (`pennyfarthing-dist/src/pf/jira/client.py`):

- `find_user_sync(query: str) -> dict[str, Any] | None`
- GET only, against the existing user-search endpoint. Returns the first matching account dict (keys `accountId`, `emailAddress`, `displayName`), `None` when the list is empty AND `None` when `_call_api_sync` returns `None` (transport/auth failure). Never raises.
- Rationale: resolution today lives welded inside `assign_issue_sync`, immediately before the mutating PUT. That coupling is the structural reason dry-run had nothing to reuse. Extract it; `assign_issue_sync` should call the same helper so there is exactly one resolution rule.

**Resolution in `pennyfarthing-dist/src/pf/jira/operations.py`:**

- `assign_issue(issue_key, assignee, *, dry_run=False)` resolves the identifier BEFORE branching on `dry_run`. Both paths resolve; only the real path writes.
- Resolution order: explicit `jira.user_map` entry wins; otherwise query Jira with the identifier the user typed. Do NOT fall back to `get_current_user_email()` — see Delivery Findings, this is the "only the GitHub username resolved" illusion in gh #146.
- Success shape: `{"success": True, "data": {"account_id": ..., "email": ..., "display_name": ...}, "dry_run": bool}`.
- Failure shapes (result objects, no raises — rule 6):
  - unresolvable: `{"success": False, "error": "User not found: {identifier}"}` where `{identifier}` is the raw user input, not a substituted email.
  - no credentials (`not client.token`): `{"success": False, "error": "..."}` containing the word `credential` and NOT containing `User not found`. Suggested text: `Cannot validate user: no Jira credentials`.

**Exit codes / output** (`pennyfarthing-dist/src/pf/jira/cli.py`):

| Path | Exit | Output contract |
|------|------|-----------------|
| assign, resolvable, real | 0 | names resolved email AND display name |
| assign, resolvable, dry-run | 0 | names resolved email AND display name; must NOT contain `Assigned {KEY}` |
| assign, unresolvable, either mode | non-zero | `User not found: {identifier}`; zero write calls |
| assign, no credentials, either mode | non-zero | message contains `credential`, not `User not found`; zero write calls |

Tests assert non-zero rather than a specific code, so 1 or 2 both satisfy; pick one and be consistent.

**Help text (AC3):** `pf jira assign --help` must contain, case-insensitively, `GitHub username`, `Jira account email`, and both `non-Jira` and `resolve`. Suggested: `USER: GitHub username, or the user Jira account email; non-Jira emails will not resolve.`

### AC4 sibling audit — all dry-run paths in the jira package

| Path | Current dry-run behavior | Verdict | Action |
|------|--------------------------|---------|--------|
| `jira assign` (operations.py) | echoes input, no lookup, prints success | broken — the story | fixed here |
| `jira sprint add` (cli.py) | pure echo, never builds a client | broken, AC4 minimum | pinned here — must verify the issue exists, fail `Issue not found: {KEY}` |
| `jira link` (operations.py) | returns before building a client | broken, same module | pinned here — must verify BOTH endpoint keys exist |
| `jira claim` (cli.py) | pure echo, no lookup at all | broken | logged as a finding — not pinned, keeps this diff scoped |
| `jira move` (operations.py) | reads the issue, but a missing issue or a nonexistent target transition both preview as success | broken | logged as a finding |
| `jira create story` (create.py) | prints and returns success without validating the parent epic key | broken | logged as a finding |
| `jira create epic` (epic.py) | returns the built payload without contacting Jira | acceptable — a create has no prior state to validate; payload build already fails loudly on bad config | none |
| `jira sync` / `story.py sync_story` | performs real reads, then reports what it would change | acceptable | none |
| `jira bidirectional` | builds a real plan from real reads before the dry-run branch | acceptable | none |

**Stub boundary:** patched at both `pf.jira.operations.get_client` and `pf.jira.client.get_client` (operations binds the name at import time, so one patch alone leaves the assign path on the real client). Stub-integrity tests prove the patch lands at both names, that the real assignment reaches the stub, that an injected WRITE failure propagates to a non-zero exit, and that an injected READ failure (emptying the fake directory) turns a previously-green resolution red.

**Suite discipline:** full python suite is `31 failed, 5591 passed, 4 skipped, 7 xfailed` — 30 are mine, and 1 is `test_152_1_no_company_leakage` which my first draft tripped by quoting the real corporate Jira key in a docstring; scrubbed to fictional identifiers and re-verified green. The 7 xfails are the expected 162-5 quarantines.

**Handoff:** To Dev for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Tests:** 43/43 passing (GREEN). Full python suite: 5622 passed, 4 skipped, 7 xfailed, 0 failed — the 7 xfails are the expected 162-5 quarantines, zero new failures. TEA's 30 reds are green and the 13 regression guards still hold.
**Branch:** feat/162-7-jira-assign-dry-run-truthful (pushed, commit 28cf977e2, GPG signed, good signature)
**Lint:** ruff check clean and ruff format clean on all touched files. Repo-wide ruff reports 153 pre-existing errors, none in this diff.

**Files Changed:**
- `pennyfarthing-dist/src/pf/jira/client.py` — added `find_user_sync(query)`: GET-only lookup against the existing user-search endpoint, returns the first matching account dict or None on both an empty list and a None from `_call_api_sync` (no credentials, transport failure). Never raises. `assign_issue_sync` now resolves through it, so there is exactly one resolution rule. `map_github_to_jira` fallback removed.
- `pennyfarthing-dist/src/pf/jira/operations.py` — `assign_issue` resolves before branching on `dry_run`; returns `data` with account_id, email, display_name; distinct credential failure; `link_issues` verifies both endpoints in dry-run.
- `pennyfarthing-dist/src/pf/jira/cli.py` — assign help text pins the identifier contract, assign output names the resolved account on both paths and no longer says "Assigned" for a preview, link preview says "Would link", `sprint add --dry-run` verifies the issue exists.

**Exit-code choice:** 1 for every failure path (assign unresolvable, assign no-credentials, sprint add missing issue, link missing endpoint), matching the pre-existing `raise SystemExit(1)` convention in this CLI module. The jira group's own fail-closed guard keeps its distinct 2.

**Fallback-removal impact analysis (TEA's pinned third bug):** `map_github_to_jira` had exactly one production caller in the tree — `operations.assign_issue`. It is also re-exported from `pf/jira/__init__.py`, but nothing imports it from there. So removing the `get_current_user_email()` fallback affects only the assign path, which is precisely the path where retargeting to the operator was the bug. No caller needed operator-self-resolution through this function: the two legitimate self-resolution sites, `jira/claim.py` (two call sites) and `sprint/work.py` (two call sites), already call `get_current_user_email()` directly and explicitly, and are untouched. `get_current_user_email` itself is unchanged and still exported. No test in the suite asserted the fallback behavior — the only references were 162-7's own tests plus a docstring note in test_152_2. An unmapped username now returns None, and `assign_issue` then queries Jira with the raw identifier the user typed, so a username that happens to be a real Jira account name still resolves; one that does not fails loudly naming what was typed.

**Deliberate non-changes:** `jira claim`, `jira move`, and `jira create story` dry-runs remain false-positive — TEA logged them as findings to keep this 3-point diff scoped, and I left them alone. They need a follow-up story.

**Handoff:** To review phase.

## Subagent Results

**All received: Yes** — 5 enabled subagents all returned; 4 disabled via `workflow.reviewer_subagents`.

| # | Subagent | Received | Status | Findings | Confirmed | Notes |
|---|----------|----------|--------|----------|-----------|-------|
| 1 | reviewer-preflight | Yes | Returned | 0 | n/a | Reported tests GREEN but its own prose contradicted its count ("3 pre-existing failures ... leakage"). **Challenged and re-run by hand** — see Suite Verification below. |
| 2 | reviewer-edge-hunter | Yes (disabled) | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Yes (disabled) | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | Returned | 4 | 3 | Confirmed: unassign dry-run untested, second-stage lookup untested, sibling no-credential cases untested. Downgraded to Low: negative-only assertion in the no-completion-claim test (positive coverage exists in a sibling class). |
| 5 | reviewer-comment-analyzer | Yes (disabled) | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | Returned | 5 | 4 | Confirmed: `email` fallback holds a non-email; discarded `account_id`; unassign double-output; `find_user_sync` None conflation. Downgraded to Low: `map_github_to_jira` nullability collapse (sole caller handles it). |
| 7 | reviewer-security | Yes | Returned | 2 | 2 | Unencoded URL query **downgraded High→Medium** with rationale (see F4). Sibling credential guard confirmed. Verified no remaining fallback-to-operator path; no company leakage in the new test file. |
| 8 | reviewer-simplifier | Yes (disabled) | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | Returned | 2 | 2 | 18 rules / 67 instances, 2 violations — both independently reproduced (unencoded query, unassign double-print). Confirmed both commits conventionally formatted and GPG-signed, all edits under `pennyfarthing-dist/`. |

## Reviewer Assessment

**Verdict:** APPROVED

**Suite Verification (independent):** I re-ran the full suite myself because preflight self-contradicted. Result: `1 failed, 5621 passed, 4 skipped, 7 xfailed`, zero XPASS. The single failure is `test_152_1_no_company_leakage::test_no_company_brand_number_in_framework_redistributables`, and the offender is `venv/lib/.../pip-26.1.2.dist-info/RECORD` line 411 — the byte-count field of a vendored pip file happens to be the forbidden token. The gate's `SKIP_DIRS` lists `.venv` but not `venv`, so any local environment using the unprefixed name trips it. Nothing in this diff is implicated; with that scan artifact excluded the numbers match Dev's claim exactly (5622 passed). Verified as environmental, not a regression. Logged below as a gate-hygiene finding.

**Dry-run genuinely does not mutate — traced, then proved.** I enumerated every client call reachable on each dry-run path: assign → `find_user_sync` (GET) and `get_issue_sync` (GET); link → `get_issue_sync` on both endpoints (GET); sprint add → `get_issue_sync` (GET). No writer is reachable. I then drove the real Click command against an instrumented client for every branch (unassign, resolvable, email-withheld, no-match) and every dry-run invocation recorded zero write calls. AC1's no-mutation half is solid.

**Data flow traced end-to-end:** operator types USER → `assign_issue` credential gate → `query` = the typed string if it contains `@`, else the `jira.user_map` entry, else the typed string verbatim → `find_user_sync` GET → `resolved` → dry-run returns / real path writes. Safe because nothing on the path can substitute a third party's identity: the only substitution left is map-driven and operator-configured.

**Fallback-removal audit — Dev's claim CONFIRMED by grep, with one addition.** `map_github_to_jira` has exactly one production caller, `operations.assign_issue`. The two legitimate self-resolution sites, `jira/claim.py` and `sprint/work.py`, call `get_current_user_email` directly and are untouched. I also found a second assign path Dev did not mention — `sprint/story_update.py` calls `assign_issue_sync` directly — and confirmed it never routed through `map_github_to_jira`, so it is unaffected. Separately, `tests/python/test_jira_lib_port.py::TestMapGithubToJira` still asserts the removed fallback; that directory sits outside `testpaths` and I verified in a throwaway worktree that the same three tests fail identically on develop, so it is not a regression this diff created (probe removed, tree clean).

**Also verified good:** the unresolvable error quotes the RAW input (`operations.py` uses `assignee`, not the resolved `query`) on the dry-run path; the credentials error is distinct, contains `credential`, omits `User not found`, and is returned before any network call; the only None reaching `assign_issue_sync` is the explicit unassign intent, so the accidental-unassign footgun is closed; ruff check and format clean on touched files.

**Findings (none blocking).** Tags credit the originating specialist: [SEC] reviewer-security, [TYPE] reviewer-type-design, [TEST] reviewer-test-analyzer, [RULE] reviewer-rule-checker. Untagged rows are my own analysis.


| Severity | Issue | Location | Fix |
|----------|-------|----------|-----|
| [MEDIUM] F1 [TYPE] | Real path re-resolves the user instead of using the `account_id` it already holds. `assign_issue` calls `find_user_sync`, then hands the resolved email to `assign_issue_sync`, which calls `find_user_sync` again — two GETs per write, `account_id` computed and discarded. Confirmed consequence: a failure at the second lookup reports the substituted email, not what the operator typed (probe: input `some-gh-user` → `Failed: User not found: fake@example.com`), so the raw-input rule the dry-run honours breaks on the real path. Also a preview/write divergence window if the second query's first hit differs from the first's. | `jira/operations.py:115`, `jira/client.py:576` | Thread `account_id` through to the PUT (new by-id writer) so one lookup serves both. |
| [MEDIUM] F2 [RULE] [TYPE] | Unassign dry-run prints two contradictory lines. Reproduced: `[DRY RUN] Would unassign FAKE-1` from operations, then `[DRY RUN] Would assign FAKE-1 to nobody` from the CLI, because that branch returns no `data` and the CLI cannot tell unassign from assign. Introduced by this diff; no test covers the path. Bare `print` also bypasses the module's `click.echo` convention. | `jira/operations.py:84`, `jira/cli.py:133` | Drop the `print` and flag the intent in the result so the CLI renders one honest line. Trivial — worth folding in before merge if SM prefers. |
| [MEDIUM] F3 [TYPE] | When Jira withholds `emailAddress`, the output presents the input string in the email slot: `[DRY RUN] Would assign FAKE-1 to Fake Person <some-gh-user>` (reproduced). That is the echo-the-input pattern the story exists to remove, dressed as a resolved account, and AC2 asks for the resolved email specifically. Same fallback also makes the already-assigned comparison unmatchable in that case, costing a redundant write. | `jira/operations.py:101`, `jira/cli.py:132` | Show `account_id` or omit the bracket slot when Jira withholds the address; keep the write-path fallback as-is. |
| [MEDIUM] F4 [SEC] [RULE] | `find_user_sync` interpolates `query` into the URL unencoded. Honest severity: `_call_api_sync` uses `subprocess.run` with a list argv and no shell, and the endpoint is a read-only GET on operator-typed input, so there is no shell injection and no privilege boundary crossed — security subagent's High downgraded on that basis. The real damage is functional: I confirmed curl exits 3 on an unencoded space, so the display-name lookup this method's own docstring advertises returns None for any name with a space and surfaces as `User not found: Dana Reyes`. Values with `&` or `=` splice extra parameters into the operator's own read. Pre-existing text, but the diff promotes it to a public helper and widens the documented contract to display names. | `jira/client.py:560` | `urllib.parse.quote(query, safe="")`, matching the JQL path in the same class. |
| [MEDIUM] F5 [SEC] [TEST] | `sprint add --dry-run` and `link --dry-run` acquire a client but never check `token`, so with credentials absent both report `Issue not found: {KEY}` for a key that exists — the exact misattribution the assign path was given a distinct message for. The design constraint for this story was decided for one of the three fixed paths only. Untested. | `jira/cli.py:487`, `jira/operations.py:141` | Mirror the `token` guard into both dry-run branches. |
| [LOW] F6 [TYPE] | `find_user_sync` collapses no-match and call-failed into one None (documented, deliberate). With the upstream token guard this no longer produces false success, but an expired token or transport blip on assign still misdiagnoses as `User not found`. | `jira/client.py:556` | Distinguish the two, or defer with F4. |
| [LOW] F7 [TEST] | Coverage gaps that let F1, F2 and F5 through: no test exercises unassign in either mode, none exercises a second-stage lookup failure, none covers absent credentials for the two sibling dry-runs. Test design is otherwise strong — the stub-integrity class genuinely proves both patch sites and that an injected read failure turns a green resolution red. | `test_162_7_assign_dry_run_truthful.py` | Add the three cases with the fixes. |
| [LOW] F8 [SEC] | Company-leakage gate is environment-sensitive: `SKIP_DIRS` covers `.venv` but not `venv`, so a local virtualenv under the unprefixed name fails the gate on a byte-count field inside a vendored pip RECORD. This is how "suite is green" stops being reproducible between agents. | `test_152_1_no_company_leakage.py:39` | Add `venv` (and prefer scanning tracked files only). |

**Deviation audit:**
- **Unmapped username falls through to a raw Jira query — ACCEPTED.** It does not reintroduce silent wrong-user assignment: the substitution that retargeted the operator is gone, and what goes to Jira is the literal string typed, so a wrong hit now requires Jira itself to match that string rather than the tool inventing an identity. Caveat: the display-name case that justifies the deviation is currently unreachable because of F4, so the rationale is sound but unrealizable until that is encoded. Flagged, not blocking.
- **`data.email` falls back to the query string — ACCEPTED for the write path, FLAGGED for display (F3).** Avoiding a None into `assign_issue_sync` is the right call; presenting the fallback as a resolved email is not.
- **Credential check ahead of the unassign path — ACCEPTED.** Consistent with the rest of the diff; unassigning without credentials cannot succeed either.
- **Undocumented deviations found:** none.

**Deferred, explicitly out of scope for this story:** `jira claim`, `jira move`, `jira create story` dry-run false-positives (TEA-scoped out, need a follow-up story); the write-confirmation gap where `_call_api_sync` cannot tell a 204 from a curl failure so real writes can still lie (Dev's finding — confirmed, needs a shared-transport change); `test_frame_routes.py` order-dependent flake (already logged).

**Rationale for approval:** the reported bug is genuinely closed and I could not break the no-mutation guarantee or the raw-input contract on any dry-run path. Every finding above is either pre-existing, non-mutating, or confined to output wording — no Critical, no High. F2 is a one-line fix and SM may reasonably fold it in before merge rather than deferring it.

**Handoff:** To SM for finish-story.

### Dev Addendum — review finding F2 folded

**Commit:** f52ef7d52 (GPG signed, pushed). Reviewer's F2 confirmed and fixed.

**The bug:** `pf jira assign KEY none --dry-run` printed two contradictory lines because two layers were both writing output — `operations.assign_issue` printed the unassign preview, then the CLI printed its own generic success line, which rendered as "Would assign KEY to nobody". My first pass introduced the second line when I made the CLI the output owner but left the unassign print in place. Reviewer was right that it belongs in this story: a preview that contradicts itself is the same defect class the story exists to close.

**Fix:** `assign_issue` no longer prints at all; it returns `unassign: True` and the CLI owns every line, so there is exactly one writer. The unassign path prints one line and never names an account it did not resolve. Real unassign now reads "Unassigned KEY" instead of the old "Assigned KEY to none".

**Tests:** 6 added, closing the F7 coverage gap on this path — exactly one line for each of the `none`/`null`/`x` sentinels (parametrized), no contradictory assign claim, no writes during the preview, and a guard that the real unassign still reaches the client with None. Story file now 49/49.

**Suite:** 5627 passed, 4 skipped, 7 xfailed, 1 failed. The failure is `test_152_1_no_company_leakage::test_no_company_brand_number_in_framework_redistributables` and it is NOT from this diff — verified by stashing all my changes and re-running, where it fails identically. Cause is a `pennyfarthing/venv/` created at 11:06 today, after my earlier clean full-suite run; the leakage scan walks it and trips on a pip RECORD line whose sha256 CSV row happens to end in the forbidden token. Environment artifact, logged as a finding below.

**Lint:** ruff check and ruff format clean on all touched files. F1/F3/F4/F5 deliberately untouched per SM.

## Delivery Findings

### Dev (implementation)
- **Gap** (non-blocking): `test_152_1_no_company_leakage` scans the whole worktree including untracked, non-redistributable directories, so an ordinary local `venv/` fails the suite the moment a dependency ships a file whose hash or size digit sequence contains the forbidden token — currently a pip RECORD row for `idna/intranges.py`. The test's own docstring scopes it to "framework redistributables", so `venv/`, `.venv/`, and `site-packages/` should be excluded the way build output presumably already is. Affects `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py` (its exclusion list). Reproduced with all 162-7 changes stashed, so it is not this story's regression, but it will fail for anyone who creates a venv in the repo. *Found by Dev during implementation.*
- **Gap** (non-blocking): `assign_issue_sync` treats the assignee PUT as unconditionally successful — it fires `_call_api_sync("PUT", ...)` and returns `{"success": True}` without inspecting the return, because the endpoint answers 204 with an empty body and `_call_api_sync` cannot distinguish "204 empty" from "curl failed" (both are None). `transition_sync` has the identical shape. So a rejected write still reports success, which is the same truthfulness defect one layer down from the one this story fixed: 162-7 makes the dry-run honest, but the real assignment it validates can still lie. Affects `pennyfarthing-dist/src/pf/jira/client.py` (`_call_api_sync` needs to surface the HTTP status, e.g. curl `-w` or `--fail-with-body`, and the 204-returning writers need to check it). Out of scope here — no AC or test touches the write-confirmation path, and fixing it means changing the shared transport every Jira caller uses. *Found by Dev during implementation.*
- **Improvement** (non-blocking): `find_user_sync` interpolates the query straight into the URL query string (inherited verbatim from the code it replaced), so an identifier containing `&` or `#` corrupts the request. Should be `urllib.parse.quote`. Affects `pennyfarthing-dist/src/pf/jira/client.py`. Left as-is because it is pre-existing behavior no test pins and encoding it is a behavior change outside the ACs. *Found by Dev during implementation.*

### TEA (test design)
- **Gap** (non-blocking): `map_github_to_jira` falls back to `get_current_user_email()` for any GitHub username absent from `jira.user_map`, so `pf jira assign KEY teammate` silently assigns the issue to the OPERATOR rather than failing. This is why gh #146 observed that "only the GitHub username resolved" — it resolved the reporter, not the target. Affects `pennyfarthing-dist/src/pf/jira/client.py` (`map_github_to_jira`) and every caller of it. Pinned in this story's tests as `TestNoSilentFallbackToOperator` because a dry-run that reports the wrong user is the same truthfulness defect as one that cannot fail; flagging it explicitly since it is broader than the ACs' literal wording and may have other callers relying on the fallback. *Found by TEA during test design.*
- **Gap** (non-blocking): three further false-positive dry-run paths found by the AC4 audit but deliberately NOT pinned here, to keep the 3-point diff scoped — `pf jira claim` (pure echo, no lookup whatsoever, and the highest-frequency agent-facing dry-run of the three), `pf jira move` (a missing issue or a nonexistent target transition both preview as success), `pf jira create story` (never validates the parent epic key). Affects `pennyfarthing-dist/src/pf/jira/cli.py`, `operations.py`, `create.py`. Suggest one follow-up story applying the same read-before-preview rule. *Found by TEA during test design.*
- **Question** (non-blocking): `test_frame_routes.py::TestPersonaRoute` (3 tests) plus `TestBackwardCompatibility::test_error_responses_have_error_field` failed on one full-suite run and passed both in isolation and on an identical re-run — an order- or filesystem-dependent flake unrelated to this story, surviving the 162-5 triage. Affects `pennyfarthing-dist/src/pf/tests/test_frame_routes.py`. Worth a story: an intermittent red in a 5600-test suite is how baselines rot back. *Found by TEA during test design.*

### Reviewer (code review)
- **Gap** (non-blocking): the real assign path resolves the user twice — `assign_issue` calls `find_user_sync`, keeps `account_id`, then discards it and passes the email to `assign_issue_sync`, which looks the user up again. Two GETs per write, and a failure at the second lookup names the substituted email rather than what the operator typed, so the raw-input rule the dry-run honours breaks on the real path. Affects `pennyfarthing-dist/src/pf/jira/operations.py` and `client.py` (thread `account_id` to the PUT via a by-id writer). *Found by Reviewer during code review.*
- **Gap** (non-blocking): unassign dry-run emits two contradictory lines — `[DRY RUN] Would unassign KEY` from operations plus `[DRY RUN] Would assign KEY to nobody` from the CLI, because the branch returns no `data`. Reproduced against the real Click command. Affects `pennyfarthing-dist/src/pf/jira/operations.py` and `cli.py` (drop the bare `print`, signal unassign intent in the result). *Found by Reviewer during code review.*
- **Gap** (non-blocking): when Jira withholds `emailAddress` the output shows the input string in the email slot, e.g. a GitHub username rendered as `Display Name <username>` — the echo-the-input pattern this story removes, presented as a resolved account. Affects `pennyfarthing-dist/src/pf/jira/operations.py` and `cli.py` (display `account_id` or omit the slot). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `sprint add --dry-run` and `link --dry-run` never check `token`, so absent credentials report `Issue not found: {KEY}` for keys that exist — the misattribution the assign path was explicitly given a distinct message for. Affects `pennyfarthing-dist/src/pf/jira/cli.py` and `operations.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): confirming Dev's unencoded-query finding with a functional consequence they did not name — curl exits 3 on an unencoded space, so the display-name lookup `find_user_sync` advertises in its own docstring can never resolve a name containing a space and reports `User not found` instead. No injection exposure (list argv, no shell, read-only GET), so this is correctness rather than security. Affects `pennyfarthing-dist/src/pf/jira/client.py` (`urllib.parse.quote`). *Found by Reviewer during code review.*
- **Gap** (non-blocking): the company-leakage gate is environment-sensitive — `SKIP_DIRS` covers `.venv` but not `venv`, so a local virtualenv under the unprefixed name fails the gate on a byte-count field inside a vendored pip RECORD file. This is why suite-green claims diverged between agents on this story. Affects `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py` (add `venv`; prefer scanning tracked files only). *Found by Reviewer during code review.*
- **Question** (non-blocking): `tests/python/test_jira_lib_port.py::TestMapGithubToJira` still asserts the fallback this story removed. It sits outside `testpaths` so it never runs, and the same three tests fail identically on develop — but a stale assertion of deleted behavior in an uncollected directory is dead weight worth either wiring in or deleting. Affects `tests/python/test_jira_lib_port.py`. *Found by Reviewer during code review.*

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Design Deviations

### Dev (implementation)
- **Unmapped GitHub usernames still reach Jira:** TEA's spec said resolution order is "explicit `jira.user_map` entry wins; otherwise query Jira with the identifier the user typed". Implemented exactly that, which means removing the `map_github_to_jira` fallback does not by itself make an unmapped username fail — it falls through to a Jira query on the raw string. Reason: a bare username can legitimately be a Jira display name or account id, and failing before asking would be a new false negative. The operator-retargeting bug is still closed because the fallback that substituted the operator's email is gone.
- **Resolved email falls back to the query string:** `data.email` is `account.emailAddress or query`. Reason: Jira Cloud commonly withholds `emailAddress` for privacy, and passing a None email into `assign_issue_sync` would have silently UNASSIGNED the issue — a new false-success of exactly the kind this story exists to remove.
- **Credential check moved ahead of the unassign path:** `assign_issue` returns the credentials error before handling `assignee` values like `none`/`null`/`x`. Spec did not say where the check sits. Reason: unassigning without credentials cannot succeed either, so reporting success there would be the same lie.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->