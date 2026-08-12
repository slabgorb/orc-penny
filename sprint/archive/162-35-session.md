---
story_id: "162-35"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-35: 162-7 truthfulness tail: real assign path resolves the user TWICE (second stage re-looks-up by substituted email — second-stage failures report the substituted email, breaking the raw-input rule; preview/write divergence window); email-withheld display puts the input string in the email slot (echo-the-input dressed as resolved); add the credentials guard to sprint-add/link dry-runs (applied to 1 of 3 paths); URL-encode find_user_sync query (curl exit 3 on spaces makes display-name lookups unresolvable) (from 162-7 review F1/F3/F4/F5)

## Story Details
- **ID:** 162-35
- **Jira Key:** (none — sprint-only)
- **Workflow:** tdd
- **Type:** bug
- **Points:** 2
- **Stack Parent:** none
- **Branch:** feat/162-35-jira-assign-truthfulness-tail-f1-f3-f4-f5
- **PR:** (none yet)

## SM Assessment

**Spec:** the title is the full spec (162-7 review F1/F3/F4/F5). FOUR jira-truthfulness defects in `pennyfarthing-dist/src/pf/jira/` (`operations.py` assign path + `find_user_sync`, `client.py`, `cli.py` sprint-add/link). Base includes 162-34 (just landed). Read the 162-7 pattern first.

- **F1 — double user-resolution in the REAL assign path:** the real assign resolves the user, substitutes an email, then a SECOND stage RE-LOOKS-UP by the substituted email. Two problems: (a) second-stage failures report the SUBSTITUTED email, breaking the raw-input rule (errors must quote the user's raw input, per 162-7); (b) a preview/write divergence window (dry-run resolved once, real path resolves twice → they can disagree). Fix: resolve ONCE, reuse the resolved account id/email for the write; on failure report the RAW input.
- **F3 — email-withheld display echoes the input:** when the resolved user's email is withheld, the display puts the INPUT STRING in the email slot (echo-the-input dressed up as resolved). Fix: when email is withheld, show a truthful "email withheld"/account-id form, never the raw input masquerading as the resolved email.
- **F4 — credentials guard applied to only 1 of 3 dry-run paths:** the credential-scrub guard (from 162-7/162-32) is on 1 of 3; add it to the sprint-add and link dry-runs too (all 3 paths scrub credentials from any echoed URL/stderr).
- **F5 — URL-encode `find_user_sync` query:** a display-name query with spaces makes curl exit 3 (unresolvable). URL-encode the query param so display-name lookups work.

**TEA (RED):** failing tests, faking the jira transport (no network):
- F1: real assign where the substituted-email second lookup FAILS → error quotes the RAW input, not the substituted email; and assert the user is resolved exactly ONCE (no divergence window) — pin the call count / single-resolution.
- F3: resolved user with withheld email → display does NOT put the raw input in the email slot (truthful withheld form).
- F4: sprint-add dry-run and link dry-run each scrub a token-bearing URL/stderr (parametrize all 3 paths).
- F5: `find_user_sync` with a display name containing spaces → the query is URL-encoded (assert the encoded query string reaches the transport; today spaces break it).

**Constraints (binding):** scoped runs — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/<jira tests>.py -q`. NEVER full suite. Fake transport; no network. Result objects, not throws. `ruff check`. Keep tightly scoped to jira/ (a parallel session may touch jira). Preserve 162-7/162-34 dry-run contract + 162-32 credential-scrub shape.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T11:36:17Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T11:10:18Z | 2026-08-12T11:11:42Z | 1m 24s |
| red | 2026-08-12T11:11:42Z | 2026-08-12T11:17:43Z | 6m 1s |
| green | 2026-08-12T11:17:43Z | 2026-08-12T11:23:39Z | 5m 56s |
| review | 2026-08-12T11:23:39Z | 2026-08-12T11:36:17Z | 12m 38s |
| finish | 2026-08-12T11:36:17Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings.

### Reviewer (code review)
- **Gap** (non-blocking): `JiraClient.assign_issue_sync` returns `{"success": True}` unconditionally after the assignee PUT, ignoring the response — a 400/403/404 still prints "Assigned KEY to X". Affects `pennyfarthing-dist/src/pf/jira/client.py:687` (the PUT result must be inspected before claiming success). Same shape applies to `add_comment_sync`, `add_to_sprint_sync`, and the transition POST. This is the largest remaining truthfulness hole in the assign path and is out of 162-35's scope. *Found by Reviewer during code review.*
- **Gap** (non-blocking): a Jira user record with no `accountId` makes the assign path silently UNASSIGN the issue and report success (`{"accountId": None}` PUT). Affects `pennyfarthing-dist/src/pf/jira/operations.py:137` (guard `if not account_id` before the write). Pre-existing outcome, not a 162-35 regression. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the `already_assigned` idempotence check compares `emailAddress`, which is `None` for withheld accounts; comparing `fields.assignee.accountId` is the robust form. Affects `pennyfarthing-dist/src/pf/jira/operations.py:130`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the credentials guard is now at the operations layer for assign/link but only in the CLI for sprint-add; `create.py:157` and `cli.py:430` still call `add_to_sprint_sync` unguarded and would blame the operator's data. Affects `pennyfarthing-dist/src/pf/jira/cli.py:524` (hoist to an operations-layer `add_to_sprint`). *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Resolution carried to the write via a `ResolvedUser(str)` value type, not a new client method or extra parameter:** the single-resolution fix needs the resolved accountId to reach `client.assign_issue_sync`, but 162-7 pins `assign_issue_sync(ISSUE_KEY, KNOWN_EMAIL)` against a stub whose signature is exactly two positional args — a third arg or a keyword would `TypeError` that stub, and a renamed method would `AttributeError`. Implemented `ResolvedUser(str)` in `client.py`: it compares equal to the plain identifier (so 162-7's assertion and `claim.py`/`story_update.py` are untouched) and carries `account_id`, which `assign_issue_sync` consumes to skip the second lookup. Unresolved callers still get the old lookup path.
- **Withheld email is `None` in result data, not a substitute string:** spec said "truthful withheld/account-id form". `data["email"]` is now `None` (Jira said nothing) and the CLI renders `Dana Reyes (email withheld; accountId acct-...)`. The write identifier falls back to the accountId, so a withheld account still assigns.
- **F4 credentials guard placed before the dry-run branch, not inside it:** the real sprint-add and link paths have the same blame-the-data failure mode as their previews, so the guard covers both. Matches `assign_issue`, which checks `client.token` unconditionally.

### TEA (test design)
- **F4 framed as the credentials guard, not a URL-token scrub:** the prompt described F4 as "each dry-run scrubs a token-bearing URL/stderr (`https://oauth2:<TOKEN>@...`)". No scrub helper and no token-bearing URL/stderr echo exists anywhere in `pf/jira/` (grepped: no `scrub`/`redact`/`oauth2:` outside tests) — a scrub test there would pass vacuously today, i.e. not RED. The real 1-of-3 defect is the CREDENTIALS guard: `operations.assign_issue` checks `client.token`; the `sprint add` and `link` dry-runs do not, so a missing token is reported as `Issue not found: KEY` (tooling failure blamed on the operator's data). Tested that, parametrized across all 3 paths, and kept the no-leak assertion as a companion guard (client built with credentials in `base_url` and `user`; output must never contain the token).
## TEA Assessment

**Tests Required:** Yes
**Reason:** n/a

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_35_assign_truthfulness_tail.py` - F1/F3/F4/F5 pinned against a fake transport at the `JiraClient._call_api_sync` seam (no network; real `JiraClient`, since all four defects live inside its own methods or between it and `operations.assign_issue`, where a 162-7-style client stub is blind)

**Tests Written:** 43 tests (16 failing / 27 guards) covering 4 ACs (F1, F3, F4, F5)
**Status:** RED (failing - ready for Dev)

**RED breakdown:**
- F1 (4 red): real assign issues 2 `user/search` GETs for one identifier; dry-run 1x vs real 2x divergence; display-name input resolvable on the first lookup fails the real run (`User not found: dana.reyes@corp.example.com`) after the dry-run previewed success; that error quotes the substituted email instead of the raw `Dana Reyes`. Also pinned: the assignee PUT must carry the already-resolved `accountId`.
- F3 (3 red): withheld `emailAddress` prints `Dana Reyes <Dana Reyes>` and `data["email"] == "Dana Reyes"` — the input in the email slot. Must be a withheld/accountId form; the real run must still assign by accountId.
- F4 (4 red): `sprint add` and `link` dry-runs report `Issue not found: PROJ-1` with no token instead of naming credentials. `assign` already passes (the 1 of 3).
- F5 (5 red): `?query=Dana Reyes` reaches the transport with a raw space (curl exit 3); `&`, `#`, `+` are unencoded too — `#` truncates the URL, `&` injects a second param, `+` decodes to a space. Round-trip parametrized over 7 inputs.

**Verification:** `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_35_assign_truthfulness_tail.py -q` -> `16 failed, 27 passed`. `ruff check` clean, `ruff format` applied.

**Commit:** `75c58a56e` (signed)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/jira/client.py` - added `ResolvedUser(str)` (identifier + resolved accountId); `assign_issue_sync` reuses a caller's resolution instead of re-looking-up (F1); `find_user_sync` builds its endpoint with `urlencode({"query": q}, quote_via=quote)` so spaces/`&`/`#`/`+`/`/` round-trip (F5)
- `pennyfarthing-dist/src/pf/jira/operations.py` - `assign_issue` records `email` as `None` when Jira withholds it instead of echoing the input, and hands the write a `ResolvedUser` carrying the accountId (F1/F3); `link_issues` gained the `client.token` credentials guard (F4)
- `pennyfarthing-dist/src/pf/jira/cli.py` - `assign` prints `(email withheld; accountId ...)` when Jira withheld the address (F3); `sprint add` gained the credentials guard (F4)

**Tests:** 43/43 passing in `test_162_35_assign_truthfulness_tail.py` (16 previously-failing now green, 27 guards still green)
**Regression:** 282/282 across the jira batch — `test_162_7_*`, `test_162_34_*`, `test_162_35_*`, `test_152_1/152_2/156_2/158_5/160_3_*jira*`, `test_162_20_dry_run_block_parity`, `test_162_79_story_update_*`, `test_event_driven_jira_sync`, `test_jira_cli_disabled_gate`, `test_jira_package`, `test_story_finish_no_jira`. No full suite (per constraints).
**Lint:** `ruff check` + `ruff format --check` clean on all 3 changed files.
**Branch:** feat/162-35-jira-assign-truthfulness-tail-f1-f3-f4-f5 (pushed)
**Commit:** `367a78084` (signed)

**Handoff:** To Reviewer
## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | tree clean; 2 commits both GPG-signed (`75c58a56e`, `367a78084`); `ruff check` + `ruff format --check` pass; 157 passed / 0.70s across 6 jira test files; 0 debug prints, 0 TODO/FIXME, 0 skips, 0 test deletions; `assign_issue` 68 lines | ACCEPTED — no action; the one "long function" note is acceptable domain logic |
| 2 | reviewer-edge-hunter | Yes | findings | (a) `or ""` -> `ResolvedUser("")` -> `{"accountId": None}` PUT = silent unassign reported as success; (b) `already_assigned` unreachable for withheld accounts; (c) F4 guard in CLI for sprint-add vs operations layer for link/assign; (d) `quote` `safe='/'` leaves `/` literal | (a) CONFIRMED [MEDIUM], (b) CONFIRMED but downgraded [LOW] — Jira withholds the issue's assignee email symmetrically, so `current_email` is `""` either way and the pre-change `or query` fallback did not help; (c) CONFIRMED [LOW]; (d) **DISMISSED** — `urlencode` passes its own `safe=''` down to `quote_via`, so `/` `#` `?` `&` `+` and CRLF all percent-encode. Verified: `urlencode({'query':'Dana/Reyes'}, quote_via=quote)` -> `query=Dana%2FReyes` |
| 3 | reviewer-security | Yes | findings | (a) same `or ""` unassign, framed as auth-bypass (confidence low); (b) pre-existing: `-u user:token` sits in the curl argv and is visible in `ps`. Injection: clean (list argv, no `shell=True`, CRLF encodes to `%0D%0A`). Credential echo: clean. Guards fail closed. `accountId` is less identifying than the email it replaces | (a) CONFIRMED, deduped with edge-hunter (a) [MEDIUM]; (b) CONFIRMED but PRE-EXISTING and out of scope -> Delivery Finding, not a gate item |
| 4 | reviewer-test-analyzer | Yes | findings | (a) `test_error_never_names_the_substituted_email` is vacuous on the green path (guarded by `if "not found" in text`); (b) no fixture for a user record missing `accountId` — the branch that re-opens double-resolution; (c) the plain-`str` fallback branch (claim.py / story_update.py) is untested here; (d) `test_exits_nonzero` is non-discriminating for sprint-add/link; (e) harness test touches private `_call_api_sync` | (a) CONFIRMED [LOW] — sibling `test_real_run_succeeds_where_the_dry_run_previewed_success` carries the mutation signal; (b) CONFIRMED [MEDIUM], pairs with the `or ""` code gap; (c) CONFIRMED [LOW]; (d) **DISMISSED** — redundant but harmless, `test_names_the_credentials_problem` and `test_does_not_blame_the_data` are the discriminating pins; (e) **DISMISSED** — naming the injected seam is the entire point of a harness-integrity test |
| 5 | reviewer-type-design | Yes | findings | (a) `str` subclass = implicit side-channel; any `str` op silently drops `account_id` (high); (b) signature declares `str \| None` while the body `getattr`s `account_id` — no type checker configured in `pyproject.toml`, so the mismatch is invisible; (c) same `or ""` gap; (d) `resolved["email"]` widened `str` -> `str \| None` with no declared type | (a) CONFIRMED as fragility, ACCEPTED as a trade-off — see my ruling below; the agent's claim that a third optional param "would not break the 2-arg stub" is **WRONG**: `operations.assign_issue` has no knowledge of the stub, so passing `account_id=` would reach `test_162_7`'s 2-positional stub and `TypeError`. Dev's stated blocker is real; the clean fix requires editing that stub, which is out of this story's scope. (b) CONFIRMED [LOW], merged with the rule-checker docstring finding; (c) deduped [MEDIUM]; (d) CONFIRMED [LOW] — `cli.py:163` is the only non-test consumer and it branches on None correctly |
| 6 | reviewer-rule-checker | Yes | findings | 8 rules / 24 instances / 1 violation: `assign_issue_sync`'s docstring Args is stale re `ResolvedUser`. All 4 changed files verified as real files, not `.pennyfarthing/` symlinks. Result-object rule: compliant. `raise SystemExit(1)` matches the ~10 existing occurrences in `cli.py`. Python >=3.11.4 so bare PEP-604 unions are fine without `from __future__` | Violation CONFIRMED [LOW]. Its Rule-8 *reasoning* is **DISMISSED as incorrect** — it claims `ResolvedUser("")` produces `User not found: `; `""` is falsy, so control goes to the `else` branch and the PUT sends `{"accountId": None}` (an unassign). Three other specialists and my own read agree on the unassign |

**All received: Yes** — 6 of 6 specialists returned (5 enabled + reviewer-rule-checker). 0 timeouts, 0 errors.

## Reviewer Assessment

**Verdict:** APPROVED

**Scoped run (mine):** `test_162_35` + `test_162_7` + `test_162_34` -> **105 passed in 0.33s**. `ruff check` clean on all 4 files. Working tree clean.

**Per-defect soundness:**
- **F1 single-resolution — SOUND.** `operations.assign_issue` resolves once (operations.py:110) and hands the write a `ResolvedUser` carrying the accountId (operations.py:137); `client.assign_issue_sync` consumes it and skips the second lookup (client.py:619-621). Pinned three ways: exact query list `== [ACCOUNT_EMAIL]`, PUT body carries the resolved accountId, and dry-run/real lookup counts asserted equal. The divergence fixture (`resolvable`: directory answers the display name but NOT the account's own email) is the exact shape that used to fail after a successful preview — now green. Errors quote the raw input (`User not found: Nobody At All`, `User not found: {ACCOUNT_EMAIL}` from the harness-integrity test). `claim.py:112`, `claim.py:338`, `story_update.py:320` pass plain `str`/`None` -> `getattr` returns `None` -> untouched legacy lookup path. Not broken.
- **F3 withheld email — SOUND.** `data["email"]` is `None` (operations.py:120), CLI renders `Dana Reyes (email withheld; accountId acct-...)` (cli.py:163-170). `cli.py:163` is the only non-test consumer of `data["email"]` — nothing reintroduces the input. The withheld account still assigns by accountId (pinned).
- **F4 credentials guard — SOUND for the 3 named paths.** assign (operations.py:98), link (operations.py:166), sprint-add (cli.py:524). All three now exit non-zero, say "credential", never say "not found", never echo the token, and never write. Guards sit *before* the dry-run branch, so the real paths are covered too.
- **F5 url-encode — SOUND.** `urlencode({"query": q}, quote_via=quote)` (client.py:596). Round-trip parametrized over 7 inputs incl. space, `&`, `#`, `+`, `?`, `'`, `/`; asserted via `parse_qs` decode (server's view), not just "looks encoded". `_call_api_sync` uses `subprocess.run` with a list argv and no `shell=True` — no injection surface through the endpoint.

**Ruling on `ResolvedUser(str)`: SOUND, deliberately narrow, mildly fragile — accepted.**
Adversarial cases constructed and checked:
- Any `str` operation (`.strip()`, `.lower()`, `+`, f-string re-wrap) returns a plain `str` and **silently drops `account_id`**, reverting to double-resolution with no error. No path does this today (single caller -> single consumer, `getattr` first thing), and `test_real_assign_resolves_the_user_exactly_once` is the tripwire if anyone adds normalization. Same for `copy`/`pickle`/JSON round-trip (`__new__` defaults `account_id=None`) — none on the path.
- Equality/hash/dict-key/JSON all behave as the plain identifier, so 162-7's `assign_calls == [(ISSUE_KEY, KNOWN_EMAIL)]` assertion and its 2-positional-arg stub still pass. Verified.
- Can an error now print the accountId where it means the raw input? No: `f"User not found: {assignee_email}"` is only reachable when `account_id` is falsy, and the sole construction site sets value==account_id exactly when email is None and account_id is truthy. The one bad output is the `or ""` case below.
- Design cost: an implicit attribute channel is traded for an explicit parameter purely to preserve a hand-written test double's signature. The stub is a test artifact; updating it would be the cleaner fix. Not blocking — the type is documented, single-caller, and behaviourally inert.

**Data flow traced:** `pf jira assign PROJ-1 "Dana Reyes"` -> cli.py:151 -> operations.assign_issue -> token guard -> user_map -> `find_user_sync` (encoded GET, ONE call) -> `resolved{account_id, email|None, display_name}` -> `ResolvedUser` -> `assign_issue_sync` -> PUT `{"accountId": "acct-..."}`. Safe: the raw input never reaches the URL unencoded, and never reaches the email slot.

**Findings (none blocking):**

| Severity | Issue | Location | Fix |
|----------|-------|----------|-----|
| [MEDIUM] | `ResolvedUser(resolved["email"] or account_id or "")` — if Jira returns a user record with no `accountId`, the identifier is `""` -> falsy in `assign_issue_sync` -> `{"accountId": None}` -> the issue is **silently UNASSIGNED** and reported as `Assigned PROJ-1 to Dana Reyes (email withheld; accountId None)`. Same outcome pre-change (via the old re-lookup), so not a regression — but now a 2-line guard. [EDGE][SEC][TYPE][TEST] | operations.py:137 | `if not account_id: return {"success": False, "error": ...}` before the write |
| [MEDIUM] | `assign_issue_sync` returns `{"success": True}` unconditionally, ignoring the PUT's result — a 400/403 still prints "Assigned". Pre-existing, out of this story's scope; it is the largest remaining truthfulness hole in the assign path. [EDGE] | client.py:687 | follow-up story |
| [LOW] | The `already_assigned` idempotence check still compares `emailAddress`; with `email=None` for withheld accounts it can never fire for them (harmless today because Jira withholds the issue's assignee email symmetrically, so `current_email` is `""` either way). Comparing `fields.assignee.accountId` is the robust form. [EDGE] | operations.py:130 | compare accountId |
| [LOW] | F4 guard placement is asymmetric: assign/link guard at the operations layer, sprint-add only in the CLI. `create.py:157` and `cli.py:430` still call `add_to_sprint_sync` with no guard and would blame the data. [EDGE] | cli.py:524 | move to an operations-layer function |
| [LOW] | Single resolution removes the accidental disambiguation the second-stage email lookup used to provide: `find_user_sync` returns `users[0]` of an ambiguous multi-match. Mitigated — the CLI prints the resolved displayName, and `--dry-run` shows it first. [EDGE] | client.py:598 | note only |
| [LOW] | `test_error_never_names_the_substituted_email` is wrapped in `if "not found" in text` — vacuous on the green path. The real pin is its sibling `test_real_run_succeeds_where_the_dry_run_previewed_success`, so coverage is intact. [TEST] | test_162_35:358 | note only |
| [LOW] | `assign_issue_sync`'s docstring Args still says `assignee_email: Jira user email, or None to unassign` — stale now that a `ResolvedUser` short-circuits the lookup. The declared type `str \| None` also gives no caller any way to discover the fast path. [RULE][TYPE] | client.py:611 | document the `ResolvedUser` case |
| [LOW] | No test exercises `assign_issue_sync` with a **plain** `str` (the `claim.py:112` / `story_update.py:320` legacy fallback branch); if that branch broke, this file stays green. [TEST] | test_162_35 | add one direct-call test |

**Verified good:** transport faked at `_call_api_sync` with `subprocess.run` poisoned to prove no network; `TestHarnessIntegrity` pins that both `get_client` boundaries are patched and that emptying the directory turns success into loud failure (anti-vacuity); the F4 no-token fake reproduces the real client's `token`-less short-circuit rather than a friendlier world; every dry-run test asserts `writes == []`.

**Deviation audit:** all three Dev deviations **ACCEPTED**. `ResolvedUser(str)` — accepted with the fragility note above. `email = None` — accepted; it is the correct truthful encoding and the accountId fallback keeps withheld accounts assignable. Guard-before-dry-run-branch — accepted; matches `assign_issue` and fixes the real path too. No undocumented deviations found.

**Handoff:** To SM for finish-story