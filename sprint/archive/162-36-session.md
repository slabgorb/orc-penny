---
story_id: "162-36"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-36: Jira transport truthfulness: _call_api_sync cannot distinguish a 204 empty body from a curl failure

## Story Details
- **ID:** 162-36
- **Jira Key:** (none — kanban-only story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-36-jira-transport-truthfulness-call-api-sync
- **PR:** (none yet — recorded when the PR is created)
- **Repos:** pennyfarthing

## SM Assessment

**Spec:** the title is the full spec (from 162-7). ROOT-CAUSE fix at the transport layer in `pennyfarthing-dist/src/pf/jira/client.py`: `_call_api_sync` cannot distinguish a legitimate **204 No Content** (empty body, the success shape for writes like assign/transition) from a **curl failure** (also empty output). Because both look like "empty", `assign_issue_sync`/`transition_sync` return UNCONDITIONAL success for writes — so even a dry-run that validated truthfully (162-34/162-35) can be followed by a real write that silently fails but reports success. (This is the transport root cause behind 162-35's MEDIUM findings / the just-filed 162-75.)

**Fix shape:** make `_call_api_sync` capture the real outcome — curl's exit code AND the HTTP status (e.g. `curl -w "%{http_code}"` / `--fail-with-body`, or check the exit code) — so it can return a distinguishable result: a 2xx (incl. 204 empty) is success; a non-zero curl exit or a 4xx/5xx is a FAILURE the caller surfaces truthfully. Then `assign_issue_sync`/`transition_sync` return success ONLY on a real 2xx, and report the actual error otherwise. This is a SHARED-TRANSPORT change — every `_call_api_sync` caller (get/search/create/etc.) must keep working; preserve the existing return contract for readers that expect parsed JSON on 200.

**TEA (RED):** failing tests faking the transport at the subprocess/curl seam (no network):
- A write (assign/transition) where the underlying call FAILS (curl non-zero exit, or 4xx/5xx) → `assign_issue_sync`/`transition_sync` return `{success: False, error}`, NOT success. Today they return success unconditionally.
- A write returning a legitimate **204 empty body** → still SUCCESS (don't over-correct: empty-but-2xx is the normal write success).
- A reader (get/search) returning 200 + JSON → unchanged (parsed result), and a reader failure → failure. Pin that the shared change didn't break read callers.

**Constraints (binding):** scoped runs — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/<jira transport tests>.py -q` + a broad jira regression batch (many callers). NEVER full suite. Fake the transport seam; no network. Result objects, not throws. `ruff check`. Keep scoped to `jira/` (parallel session may touch jira). Preserve 162-7/162-34/162-35 contracts (they'll be in the regression batch).

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T12:06:26Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T11:39:43Z | 2026-08-12T11:41:08Z | 1m 25s |
| red | 2026-08-12T11:41:08Z | 2026-08-12T11:46:25Z | 5m 17s |
| green | 2026-08-12T11:46:25Z | 2026-08-12T11:50:52Z | 4m 27s |
| review | 2026-08-12T11:50:52Z | 2026-08-12T12:06:26Z | 15m 34s |
| finish | 2026-08-12T12:06:26Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### Reviewer (code review)
- **Gap** (non-blocking): `create_issue_sync`'s callers lost their diagnostics. They error with `f"Failed to create story: {response}"` (`jira/create.py:139,289`, `jira/cli.py:418`, `jira/epic.py:111`); on develop a 400 returned the parsed error body so the operator saw `{'errorMessages': ['Field customfield_10031 is required']}`. Now `_call_api_sync` correctly returns `None`, so the message reads `Failed to create story: None`. Verified by executing the path. The status+body still exist in `_request_sync` — the fix is to switch these readers to `_request_sync` and surface `result["error"]`. Affects `pennyfarthing-dist/src/pf/jira/{create,cli,epic}.py`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): TEA's follow-up finding is now load-bearing and needs a filed story — `add_to_sprint_sync` (`client.py:770`), `link_issues_sync` (`client.py:821`) and `add_comment_sync` (`client.py:747`) still discard the transport result and return unconditional `{"success": True}`, and real consumers inspect it (`jira/cli.py:537`, `jira/operations.py:177`, `jira/story.py:180`). Not a regression from 162-36 and correctly out of its ACs, but the transport now exposes the status, so each is a one-line fix. Affects `pennyfarthing-dist/src/pf/jira/client.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `add_comment_sync`'s dead `if result is None: pass` comment (`client.py:752-756`) is now actively wrong — under the new `_call_api_sync` contract `None` means "non-2xx", not "201 with an empty body". Fold into the story above. Affects `pennyfarthing-dist/src/pf/jira/client.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): transport hardening, all confirmed non-reachable with real curl as invoked but cheap: (a) `rpartition("\n")` yields `status_text=""` if stdout ever ends in a newline after `%{http_code}` — `rstrip("\n")` first; (b) `status_text.isdigit()` accepts `000`, producing `"Jira returned HTTP 0"` — gate on `100 <= status <= 599`; (c) `_redact` scrubs the plaintext token but not the `base64(user:token)` Basic form curl derives from `-u`; (d) `_redact` also replaces `base_url`, which appears in every Jira self-link and makes the 500-char body excerpt harder to read. Affects `pennyfarthing-dist/src/pf/jira/client.py:443-540`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking, PRE-EXISTING — not from this diff, confirmed the `-u` lines are unchanged context): `_request_sync` passes `-u f"{user}:{token}"` on the curl argv, so the credential is visible in the process table (`ps aux`) for the subprocess's lifetime. `_get_auth_header()` already builds the header form and is unused on the sync path. Affects `pennyfarthing-dist/src/pf/jira/client.py:494`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): two test nits, neither blocking. `test_error_never_leaks_credentials` was green pre-fix (old `assign_issue_sync` had no `error` key, so `_error_text` was `""` and the `not in` was vacuous) — it is substantive now, but asserting the error text is non-empty first would make it a real regression net. And `HTTP_FAILURES` omits **401**, the primary expired-token failure mode and the one that best exercises redaction. Affects `pennyfarthing-dist/src/pf/tests/test_162_36_transport_truthfulness.py:306,407`. *Found by Reviewer during code review.*

### TEA (test design)
- **Gap** (non-blocking): the same "collapse to None" defect lies in the READ direction too — a 4xx JSON error body parses fine, so `get_issue_sync` returns Jira's `{"errorMessages": [...]}` payload as if it were an issue (and `get_transitions_sync` returns `[]` = "no transition available" instead of `None` = "could not read", undoing 162-34's rule on the HTTP-error path). Affects `pennyfarthing-dist/src/pf/jira/client.py` (`_call_api_sync` must return None, not the error body, on non-2xx). In scope for this story's transport fix; pinned by `TestReaderFailuresStillFail`. *Found by TEA during test design.*
- **Improvement** (non-blocking): `add_comment_sync`, `add_to_sprint_sync`, `link_issues_sync`, `update_issue_sync`, `create_issue_sync` are the same unconditional-success/None-collapse shape and are NOT covered by this story's ACs (assign/transition only). Once the transport exposes status they are one-line fixes; if Dev does not take them, they need a follow-up story. Affects `pennyfarthing-dist/src/pf/jira/client.py`. *Found by TEA during test design.*
- **Improvement** (non-blocking): `add_comment_sync` contains a dead `if result is None: pass` block whose comment asserts a contract the code does not implement. Affects `pennyfarthing-dist/src/pf/jira/client.py:666-671`. *Found by TEA during test design.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

- **Seam depth:** SM said "fake the transport seam"; 162-35 fakes `_call_api_sync` itself. These tests fake one level lower — `pf.jira.client.subprocess.run` — because the defect IS `_call_api_sync`, so a `_call_api_sync` fake cannot see it. Reason: the test must express "exit 0 + 204" vs "exit 0 + 403" vs "exit 3 + empty", which only exists at the process boundary.
- **Mechanism-agnostic fake:** `_FakeCurl` emulates real curl (`-w %{http_code}`/`--write-out`, `-i`/`--include`, `--fail`/`--fail-with-body` → exit 22) rather than pinning one option. Reason: the fix shape is Dev's call; the tests only require that the status be *asked for* somehow.
- **Dev — 162-35 fake follows the moved seam:** `test_162_35_assign_truthfulness_tail.py`'s `_FakeTransport` stubbed only `_call_api_sync`; the assignee PUT now goes through `_request_sync`, so 4 of its tests hit REAL curl (exit 6). Added `_FakeTransport.request` (same recording, wrapped in the result object; no-token → credentials failure) and bound it to `client._request_sync` in `_make_client`. No assertion was weakened — the fake now covers the new seam.
- **One mechanism assertion:** `test_transport_asks_curl_for_the_status` asserts on the curl argv, not on behaviour. Reason: today's transport gives the tests NO way to express an HTTP status (the argv never requests one) — that absence is the root defect, so it is pinned directly.

## TEA Assessment

**Tests Required:** Yes
**Reason:** transport-level truthfulness defect; behaviour is fully observable at the subprocess boundary.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_36_transport_truthfulness.py` — fakes `pf.jira.client.subprocess.run` with a faithful `_FakeCurl` (routes on method+URL; honours `-w`/`-i`/`--fail*`; unrouted request raises). No network.

**Tests Written:** 71 tests (33 failing / 38 passing guards) covering 4 ACs
**Status:** RED (failing — ready for Dev)

**Run:** `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_36_transport_truthfulness.py -q` → `33 failed, 38 passed`. `ruff check` + `ruff format` clean.

### Failing tests (the RED set) — exact output

AC-1 writes must not report success when the call failed:
- `TestAssignWriteFailureIsReported::test_curl_transport_failure_fails[curl-exit-6|7|28]` — `AssertionError: curl exited 6 — nothing reached Jira — yet the assignment was reported as done: {'success': True}`
- `TestAssignWriteFailureIsReported::test_http_error_status_fails[http-400|403|404|500|503-empty]` — `AssertionError: Jira rejected the assignee PUT with 403 and the caller was told it succeeded: {'success': True}`
- `TestAssignWriteFailureIsReported::test_unassign_failure_also_fails` — `AssertionError: failed unassign reported as done: {'success': True}`
- `TestTransitionWriteFailureIsReported::test_curl_transport_failure_fails[curl-exit-6|7|28]` — `AssertionError: curl exited 7 on the transition POST, reported as transitioned: {'success': True}`
- `TestTransitionWriteFailureIsReported::test_http_error_status_fails[http-400|403|404|500|503-empty]` — `AssertionError: Jira rejected the transition POST with 403; the issue is still in its old status but the caller was told otherwise: {'success': True}`

AC-2 the failure must name the status, leak nothing:
- `TestFailureNamesTheStatus::test_assign_error_mentions_the_http_status[400|403|404|500]` — `AssertionError: the operator cannot tell a permissions failure from an outage: {'success': True}`
- `TestFailureNamesTheStatus::test_transition_error_mentions_the_http_status[400|403|500]` — `AssertionError: the transition failure does not say what Jira answered: {'success': True}`
- `TestFailureNamesTheStatus::test_transport_asks_curl_for_the_status` — `AssertionError: the transport gives curl no way to report the HTTP status (-w '%{http_code}', -i, or --fail/--fail-with-body), so a 204 and a 403 arrive identically: [['curl','-s','-X','PUT',...]]`

AC-4 readers (same shared collapse, read direction):
- `TestReaderFailuresStillFail::test_get_issue_never_returns_the_error_body_as_an_issue[401|403|404|500]` — `AssertionError: HTTP 404 error body returned as an issue: {'errorMessages': [...]}`
- `TestReaderFailuresStillFail::test_get_transitions_returns_none_on_http_error[403|404|500]` — `assert [] is None`
- `TestReaderFailuresStillFail::test_no_token_short_circuits_without_invoking_curl` — `AssertionError: a write with no credentials cannot have happened`

### Passing guards (must STAY green — over-correction detectors)
- `TestEmptyButSuccessfulWrites` — 204 / 200-empty / 201-empty on assign + transition are SUCCESS; the 204 write still carries the resolved `accountId` (162-35 contract); unassign-204 sends `accountId: None`.
- `TestReadersStillParse2xxJson` — `get_issue_sync`, `search_issues_sync`, `get_transitions_sync`, `find_user_sync`, `create_issue_sync` all still return parsed JSON on 2xx. **Note for Dev:** if you append `%{http_code}` to stdout via `-w`, you must strip it before `json.loads` or these five flip red.
- `TestReaderFailuresStillFail` (transport-failure params), `TestTransitionWriteFailureIsReported::test_the_post_was_actually_attempted`, `TestFailureNamesTheStatus::test_error_never_leaks_credentials`, `TestHarnessIntegrity` (fake is the only exit; unrouted = loud; `-w` and `--fail-with-body` emulation self-checks).

### Transport seam contract Dev must implement

`_call_api_sync` currently returns `dict | None` and cannot express a status. Add a status-bearing layer beneath it:

```python
def _request_sync(self, method, endpoint, data=None) -> dict[str, Any]:
    """-> {"success": bool, "status": int | None, "data": Any | None, "error": str | None}"""
```

- Ask curl for the outcome — any of: `-w "\n%{http_code}"` (split the trailing status off stdout before parsing), `-i`, or `--fail-with-body` (exit 22 on >=400). The fake honours all three.
- `success` iff curl exit == 0 AND `200 <= status < 300`. A 204/200/201 with an empty body is success with `data=None`.
- Non-zero curl exit → `success: False`, `status: None`, `error` naming the transport failure (curl exit code / stderr). 4xx/5xx → `success: False`, `error` **containing the numeric status** (AC-2), redacted of `token`/`user`/credentialed base URL.
- Result objects, never throws.
- `_call_api_sync` stays as the reader wrapper: `r["data"] if r["success"] else None` — so a non-2xx returns `None`, never the parsed error body.
- `assign_issue_sync` / `transition_sync` switch to `_request_sync` and return `{"success": False, "error": r["error"]}` on failure, `{"success": True}` only on a real 2xx.
- No-credentials path unchanged (no curl invocation) but the write callers must report `success: False` for it.

**Handoff:** To Dev for implementation (GREEN)

**Commit:** `94d3100` (signed) — `test(162-36): pin transport distinguishes 204 from curl/HTTP failure for writes (RED)`

## Dev Assessment

**Implementation Complete:** Yes

**Seam built (as specified by TEA):**
- `JiraClient._request_sync(method, endpoint, data=None) -> {"success", "status", "data", "error"}` — adds `-w "\n%{http_code}"` to the curl argv, splits the trailing status off stdout with `rpartition("\n")` BEFORE `json.loads` (so readers still parse), success iff curl exit 0 AND `200 <= status < 300`. Empty 2xx body (204/200/201) → success with `data=None`. Non-zero curl exit → `success:False, status:None`, `"curl transport failure (exit N): <stderr>"`. Non-2xx → `success:False`, `"Jira returned HTTP <status>: <body|(empty response body)>"`. All operator-facing messages pass through a new `_redact()` that scrubs `token`, `user`, and the credentialed `base_url`. No-token short-circuit preserved (no curl invocation) and now reports `success:False`. Never throws.
- `_call_api_sync` is now a thin reader wrapper: `r["data"] if r["success"] else None` — a 4xx/5xx yields `None`, never the parsed error body (closes TEA's read-direction leak; `get_transitions_sync` → `None` on HTTP error, per 162-34).
- `assign_issue_sync` / `transition_sync` use `_request_sync` and return `{"success": False, "error": ...}` unless the write really got a 2xx.
- Not taken (out of ACs, remain the old shape): `add_comment_sync`, `add_to_sprint_sync`, `link_issues_sync`, plus the dead `if result is None: pass` block — TEA's follow-up-story finding stands.

**Files Changed:**
- `pennyfarthing-dist/src/pf/jira/client.py` — `_request_sync` + `_redact` added, `_call_api_sync` reduced to reader wrapper, both write callers switched
- `pennyfarthing-dist/src/pf/tests/test_162_35_assign_truthfulness_tail.py` — `_FakeTransport` follows the moved seam (see Design Deviations); no assertion weakened

**Tests:** 71/71 green in `test_162_36_transport_truthfulness.py` (33 RED → pass, 38 guards still pass).

**Broad jira regression:** 313 passed / 0 failed across all 11 transport-caller test files (`git grep -l` on `_call_api_sync|assign_issue_sync|transition_sync|get_issue_sync|find_user_sync`) — includes 162-7, 162-34, 162-35 all green. `ruff check` + `ruff format --check` clean on both changed files. No full-suite run.

**Branch:** `feat/162-36-jira-transport-truthfulness-call-api-sync` (pushed)
**Commit:** `0093cdc` (signed, G)

**Handoff:** To Reviewer
## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | tree clean; 2 commits both "Good signature: Keith Avery"; 176 passed / 0 failed on the scoped batch; ruff check + format PASS; no type checker configured; 0 TODOs/debug prints; 1 lone `pass` (client.py:757, the pre-existing documented no-op) | N/A — all green, corroborates my own runs |
| 2 | reviewer-security | Yes | findings (5) | base64(user:token) form not in `_redact`; 500-char body embedded raw (newline/ANSI injection); `base_url` over-redaction + short-`JIRA_USER` corruption; "no HTTP status" path bypasses `_redact` (static string, safe); `-u` creds in process table | 1 CONFIRMED as LOW hardening, 2 CONFIRMED LOW, 3 CONFIRMED LOW (no over-scrub of the status — verified), 4 partly DISMISSED (see below), 5 CONFIRMED but PRE-EXISTING |
| 3 | reviewer-test-analyzer | Yes | findings (2) | `test_error_never_leaks_credentials` was vacuous pre-fix; `HTTP_FAILURES` omits 401 | Both CONFIRMED as LOW. Its two headline rulings CONFIRMED and load-bearing: the 162-35 edit is purely additive/non-weakening, and `_FakeCurl._render_write_out` faithfully emulates curl's `\n` escape |
| 4 | reviewer-type-design | Yes | findings (5) | `_call_api_sync` annotation lies for list-returning endpoints; no TypedDict on the result; `status=0` pollutes `int` range; add_to_sprint/link_issues/add_comment not migrated | Invariant audit CONFIRMED sound (all 5 return sites internally consistent). Annotation lie DISMISSED as pre-existing (verified unchanged on develop). TypedDict + `status=0` CONFIRMED LOW. Unmigrated callers CONFIRMED but out-of-AC |
| 5 | reviewer-rule-checker | Yes | findings (2) | Rule 6: `_call_api_sync` returns bare `None` on failure; `_redact` docstring lacks Args/Returns | Rule 6 finding DISMISSED — the reader-wrapper contract was specified verbatim by TEA and is required by six read callers; write callers were correctly migrated. Docstring nit CONFIRMED LOW |

**All received: Yes** — 5/5 enabled subagents returned before this assessment was written.

**Additionally run:** reviewer-edge-hunter was also run (findings folded in below: unmigrated write callers CONFIRMED-but-out-of-AC, `rstrip` fragility CONFIRMED LOW, and its rpartition-misread claim DISMISSED as disproved empirically).

## Reviewer Assessment

**Verdict:** APPROVED

The root cause is genuinely fixed at the transport layer, and the fix is sound against **real curl**, not just against the fake. No Critical or High findings.

### Per-item verification (evidence)

**1. `_request_sync` correctness — SOUND.** Drove the real function with a stubbed `subprocess.run` across 14 shapes. `204`/`200`/`201` empty → `{success: True, status: N, data: None}`. `403` with a JSON error body → `{success: False, status: 403, error: 'Jira returned HTTP 403: {...}'}`. curl exit 6 → `{success: False, status: None, error: 'curl transport failure (exit 6): curl: (6) Could not resolve host'}`. Contract shape `{success,status,data,error}` holds on every path; never throws.

**2. The `%{http_code}` split — adversarially confirmed SAFE.** The split (`rpartition("\n")`) precedes `json.loads` and takes only the **last** line, and `-w` always appends exactly `\n` + status, so the last segment is always the status.
- Body whose last line looks like a status: stdout `'{"a":1}\n403\n200'` → `status=200` (**not** 403). The split cannot be fooled.
- Pretty-printed multi-line JSON → `status=200`, `data={'key': 'PROJ-1'}` — parsed correctly.
- JSON body with a trailing newline → `status=200`, body parsed correctly.

The load-bearing risk I chased: the code passes `"-w", "\\n%{http_code}"` — a **literal backslash-n**. Had curl not interpreted that escape, every real request would have failed `isdigit()` and returned "curl reported no HTTP status" while all 71 fake-based tests stayed green. Verified against the real binary (`curl -s -w '\n%{http_code}' https://example.com/`): stdout ended `...</html>\n\n200`, a real newline, `status_text='200'`, `isdigit()` True — and that response body itself ended in a newline, so the trailing-newline case is proven against real curl too. Independently, `_FakeCurl._render_write_out` emulates the escape the same way (`fmt.replace("\\n", "\n")`), so the fake is faithful rather than concealing.

**3. `_redact()` — SOUND, no leak.** With `base_url="https://tok:s3cr3t@acme.atlassian.net"`, `user="ops@acme.com"`, `token="s3cr3t"`, a 401 body echoing all three yields `Jira returned HTTP 401: {"m":"auth failed for [redacted] token [redacted] at https://tok:[redacted]@acme.atlassian.net/x"}` — the credential is gone. **No over-scrub of the status:** the numeric status sits in the `"Jira returned HTTP {status}"` prefix and survived every case. (The credentialed `base_url` is only partially replaced because token substitution runs first and breaks the literal match — benign, the secret is still redacted. Hardening notes in Delivery Findings.)

**4. Reader wrapper — SOUND, and a strict improvement.** `_call_api_sync` → `r["data"] if r["success"] else None`. Audited all seven reader callers (`client.py:575,586,598,614,680,747,799`): `get_issue_sync`/`create_issue_sync`/`update_issue_sync` return `None` per their documented contract; `get_transitions_sync` guards `if not transitions_data: return None` (restores 162-34's "could not read" ≠ "none available" on the HTTP-error path); `find_user_sync` guards `not users or not isinstance(users, list)`; `search_issues_sync` guards `if not result`. An HTTP error body is now **never** returned as an issue/result. Every external `create_issue_sync` caller guards with `if not response or "key" not in response`, so the `None` is caught — no new crash path. Parsed JSON still arrives on 2xx (`TestReadersStillParse2xxJson` green; confirmed directly with multi-line JSON). One cost: diagnostics degrade to `"...: None"` — logged as a non-blocking finding, not a merge blocker, since truthfulness was the AC and the status/body remain available in `_request_sync`.

**5. Writes — SOUND.** `assign_issue_sync` / `transition_sync` succeed only on a real 2xx; a curl failure or 4xx/5xx returns `{success: False, error}` with the status named. 204-empty is still success and still carries the resolved `accountId` (162-35 contract intact). Both return result objects; no throw. Checked the blast radius of the no-credentials path now reporting `success: False` for assign (it previously lied): all ten write call sites handle a falsy result without crashing — `sprint/story_update.py:320` records it in `jira_steps`, `jira/claim.py:112` appends to `errors`. `transition_sync`'s no-credential behaviour is unchanged (it already failed via `get_transitions_sync → None`).

**6. The 162-35 test edit — NECESSARY seam adaptation, NOT a weakening.** Ruling backed by three independent checks: `--numstat` is `24 added / 0 deleted`; grep for removed non-context lines returns **0**; `def test_` count is **25 on develop and 25 on HEAD**. No assertion was deleted, relaxed, or renamed. The adaptation is required because the assignee PUT moved from `_call_api_sync` to `_request_sync` — without the binding, 4 tests would escape the fake and hit real curl (exit 6). Non-vacuity: 162-35 asserts on *resolution* — recorded search queries, the `accountId` in the recorded PUT payload, and pre-write failure when the identifier is unresolvable (`client.py` returns before any write). None of those depend on the write seam's outcome, and the always-success fake matches what the old `_call_api_sync` fake effectively produced anyway. Force is identical.

**7. Regression breadth — GREEN.** Ran the full jira batch myself: all 14 jira-touching test files → **343 passed / 0 failed** in 1.47s, including 162-7, 162-34, 162-35, 162-36, plus the reader/gating suites (152-1, 152-2, 156-2, 158-5, 160-3, 164-20, event-driven sync, cli-disabled gate, jira_package, story-finish-no-jira). Scoped batch alone: 176 passed. `ruff check` + `ruff format --check` clean on all three changed files. No full-suite run.

### Findings

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] | `create_issue_sync` callers now print `Failed to create story: None`; the Jira error body that used to appear is discarded | `jira/create.py:139,289`, `jira/cli.py:418`, `jira/epic.py:111` | Follow-up: switch to `_request_sync`, surface `result["error"]`. Not blocking — truthfulness was the AC and the diagnostic is recoverable |
| [MEDIUM] | `add_to_sprint_sync` / `link_issues_sync` / `add_comment_sync` still return unconditional success | `client.py:747,770,821` | Follow-up story (TEA already flagged). PRE-EXISTING, explicitly out of ACs, consumers exist at `cli.py:537`, `operations.py:177`, `story.py:180` |
| [LOW] [SEC] | Transport hardening: `rstrip("\n")` before the split; reject `000` via `100 <= status <= 599`; add the `base64(user:token)` Basic form to `_redact` (curl derives it from `-u`, and `_redact` only scrubs the plaintext token); drop `base_url` from `_redact` (it appears in every self-link) | `client.py:443-540` | Optional. All confirmed non-reachable with real curl as invoked |
| [LOW] [SEC] | The 500-char body excerpt is embedded raw into the operator message — embedded `\n`/ANSI from a Jira body could forge log lines or emit terminal escapes | `client.py:529-534` | Optional: escape newlines and strip ESC sequences in `detail` |
| [LOW] [TYPE] | The 4-key result is an untyped `dict[str, Any]`; the codebase already uses `TypedDict` for this shape (`ratchet.py:16`, `gate_recovery.py:26`, `followups.py:27`). Also `status=0` (curl's `000`) pollutes the `int` range where `None` is the real "no HTTP exchange" sentinel | `client.py:450,526` | Optional: introduce a `SyncResult` TypedDict; map `000` → `status: None`. Invariants themselves verified sound — all 5 return sites internally consistent |
| [LOW] [RULE] | `_redact` has a one-line docstring only; every other method in the class with parameters has `Args:`/`Returns:` (`_get_headers`, `_request_sync`, `_call_api_sync`) | `client.py:443` | Optional two-line fix |
| [LOW] | `add_comment_sync`'s dead `if result is None: pass` comment is now actively wrong under the new contract | `client.py:752-756` | Fold into the follow-up story |
| [LOW] [SEC] | `-u user:token` on the curl argv is visible in `ps`; `_get_auth_header()` already builds the header form and is unused on the sync path | `client.py:494` | PRE-EXISTING (verified: unchanged context in the diff), separate story |
| [LOW] [TEST] | `test_error_never_leaks_credentials` was vacuous pre-fix (old `assign_issue_sync` had no `error` key → `_error_text` was `""`); `HTTP_FAILURES` omits 401, the primary expired-token mode | `test_162_36_...py:306,407` | Optional test strengthening |

**Dismissed:** [RULE] the Rule 6 flag on `_call_api_sync` returning bare `None` on failure — this reader-wrapper contract was specified verbatim by TEA (`r["data"] if r["success"] else None`), is required by all six read callers where `None` is the established not-found sentinel, and the write callers *were* correctly migrated to the result-object `_request_sync`. Correct as designed. [TYPE] the `dict[str, Any] | None` annotation being a lie for the list-returning user-search endpoint — real, but verified **pre-existing and unchanged** on develop (`git show origin/develop:...client.py` line 448 has the identical annotation), so not this diff's regression; also no type checker is configured, so nothing was suppressed. [SEC] the claim that a body ending in newline-then-digits could make `rpartition` misread the status — disproved empirically (`'{"a":1}\n403\n200'` → 200). And a 2xx body that fails `json.loads` collapsing to `data=None` is unchanged from develop (old code returned `None` on `JSONDecodeError`), correct for 204 writes, so not a regression.

### Deviation audit

All four logged deviations **ACCEPTED**:
- **Seam depth** (faking `subprocess.run`, not `_call_api_sync`) — correct and in fact mandatory; the defect *is* `_call_api_sync`, so a fake at that level is blind to it.
- **Mechanism-agnostic fake** — good practice, left the fix shape to Dev while still pinning the requirement.
- **162-35 fake follows the moved seam** — ACCEPTED, see item 6; verified additive and non-weakening.
- **One mechanism assertion** (`test_transport_asks_curl_for_the_status` asserts on argv) — ACCEPTED with a note: argv assertions are normally brittle, but the absence of any status request *is* the root defect and no behavioural assertion could express it pre-fix. It will need updating if the mechanism ever changes from `-w` to `-i`/`--fail-with-body`; the test docstring accepts all three, which limits the brittleness.

**Handoff:** To SM for finish-story