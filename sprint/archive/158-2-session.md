---
story_id: "158-2"
jira_key: ""
epic: null
workflow: "tdd"
---
# Story 158-2: testing-runner clobbers the live workflow session file (gh #53)

## Story Details
- **ID:** 158-2
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-04T23:46:59Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-04T19:15:55.745237 | 2026-06-04T23:18:00Z | 4h 2m |
| red | 2026-06-04T23:18:00Z | 2026-06-04T23:28:44Z | 10m 44s |
| green | 2026-06-04T23:28:44Z | 2026-06-04T23:38:10Z | 9m 26s |
| review | 2026-06-04T23:38:10Z | 2026-06-04T23:46:59Z | 8m 49s |
| finish | 2026-06-04T23:46:59Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (blocking): The bash helpers `testing-runner.md` sources — `test-cache.sh` and `test-setup.sh` — have been DELETED; only `scripts/test/README.md` still lists them. The `source` silently fails, which is *why* the haiku agent improvises and clobbers the live session. Affects `pennyfarthing-dist/agents/testing-runner.md` (Setup + Test Cache sections) and `pennyfarthing-dist/scripts/test/README.md` (repoint or remove the stale script references as part of the fix).
- **Gap** (non-blocking): `pennyfarthing-dist/agents/README.md` mirrors the same clobbering cache-write (`SESSION_FILE=".session/${STORY_ID}-session.md"` at ~line 278, plus ~line 216) in its "Test Cache" docs. Affects `pennyfarthing-dist/agents/README.md` (fix the doc too, or the system stays half-broken and the next agent re-learns the bug). Not covered by my static guard, which targets only `testing-runner.md`.
- **Question** (non-blocking): `testing-runner` runs **bash**, so to call the new `pf.session.test_cache` helper it needs a shell-reachable entrypoint (a `pf` subcommand or `python -m pf.session.test_cache`). The wiring choice (CLI vs `python -m` vs a thin restored `test-cache.sh` that delegates) is Dev's. Affects `pennyfarthing-dist/agents/testing-runner.md` + the new module's public surface.

### Dev (implementation)
- **Gap** (non-blocking): `testing-runner.md`'s **Setup** section still `source`s the deleted `.pennyfarthing/scripts/test/test-setup.sh` (for `ensure_test_containers` / `generate_run_id`). Affects `pennyfarthing-dist/agents/testing-runner.md` (Setup section) — a separate, pre-existing container-setup breakage independent of the gh #53 data-loss fix; worth a follow-up story to repoint or reimplement in Python. *Found by Dev during implementation.*
- **Resolved** (non-blocking): TEA's finding that `agents/README.md` mirrors the clobber is **not applicable** — its `.session/{STORY_ID}-session.md` references are a path-standard example (~L216) and the `bg_task_add` background-task tracker (~L278), both legitimate session uses, not the test-result cache. No change made. *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): `main()` doesn't catch `get_project_root()`'s `FileNotFoundError` or `sys.stdin.read()` errors, so those paths emit a raw traceback instead of the structured `error:`+exit-1 the docstring promises (SOUL #10). Affects `pennyfarthing-dist/src/pf/session/test_cache.py:248-273` (wrap both in try/except → existing stderr path). Loud + benign (no cache, never a clobber); unreachable on the real runtime path. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the bash cache-write in `testing-runner.md` has no exit-code check, so a failed `python -m` call is a silent cache-miss. Affects `pennyfarthing-dist/agents/testing-runner.md` (add `|| echo "WARNING: cache write failed" >&2`). Benign vs the old clobber, but worth surfacing. *Found by Reviewer during code review.*
- **Improvement** (non-blocking, CWE-59, project rule python.md #5): `write_test_run_cache` never `.resolve()`s the target before the live-session guard/write, leaving a theoretical symlink-traversal gap if `.session/` or `test-runs/` were attacker-planted symlinks. Affects `pennyfarthing-dist/src/pf/session/test_cache.py:216-245` (resolve target + assert `is_relative_to(root.resolve())`). LOW — needs pre-existing FS write access on a single-user local tool; the RUN_ID allowlist already closes the realistic CWE-22 vector. *Found by Reviewer during code review.*
- **Improvement** (non-blocking, test coverage, project rule #6): the `OSError` write path and the defensive `is_live_session_file(target)` refuse-branch in `write_test_run_cache` have no test coverage; the `result.get("path") in (expected, str(expected))` assertion accepts a dead `str` form. Affects `pennyfarthing-dist/src/pf/tests/test_158_2_testrun_cache_isolation.py` (add OSError + guard-branch tests via monkeypatch; tighten to `== expected`). Correct code, untested branches. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `is_live_session_file` is a content heuristic (`^story_id:` / `## ... Assessment` anywhere) — fail-open on non-UTF-8 and a possible false-positive if a cache summary ever contained those markers (would refuse to refresh that RUN_ID's cache — fail-safe, stale cache only). Affects `pennyfarthing-dist/src/pf/session/test_cache.py:196-213` (anchor frontmatter to the `---` fence). LOW. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

5 deviations

- **Regression test targets the durable helper, not a live testing-runner invocation**
  - Rationale: `testing-runner` is the system under test and is non-deterministic (a haiku agent); spawning it with `STORY_ID: 158-2` would clobber THIS live session — reproducing the very data-loss bug on our own audit trail. The faithful, deterministic proof is the helper contract the agent will call (SOUL #11: promote to a script).
  - Severity: minor
  - Forward impact: Dev must wire `testing-runner.md` to actually call the helper; a full end-to-end agent run is out of scope for unit RED. Reviewer should confirm the markdown→helper wiring closes the loop.
- **RED verified via direct scoped pytest, not the testing-runner subagent**
  - Rationale: `testing-runner` (a) is the SUT and would clobber the live session, and (b) sources deleted scripts (`test-setup.sh`), so it cannot run cleanly. Direct scoped run avoids both, and the full suite is barred (the `test_git_utils.py` branch-leak caveat).
  - Severity: minor
  - Forward impact: none — Dev/Reviewer should likewise use scoped runs until this story lands.
- **Added a `python -m pf.session.test_cache` entrypoint + CLI test (beyond the RED contract)**
  - Rationale: honors One Truth (#2) — path logic lives once in Python, not duplicated in bash — and #11 (promote to a script). Chose `python -m` over a `pf` Click subcommand because this is an internal runner helper, not a user-facing command.
  - Severity: minor
  - Forward impact: none — additive internal surface, fully covered by tests.
- **Did NOT change `agents/README.md` despite TEA's finding flagging it**
  - Rationale: changing them would be wrong (they're not the defect) and scope creep. The test-cache clobber existed only in `testing-runner.md`.
  - Severity: minor
  - Forward impact: none — finding resolved as not-applicable; see Dev delivery finding below.
- **Scoped the fix to the cache write; left the Setup section's broken `source` for a follow-up**
  - Rationale: that is a separate container-setup breakage, not the gh #53 data-loss bug; fixing it here is scope creep. Logged as a Delivery Finding for a follow-up story.
  - Severity: minor
  - Forward impact: `testing-runner` container setup remains broken independent of this fix (pre-existing).

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Regression test targets the durable helper, not a live testing-runner invocation**
  - Spec source: .session/158-2-session.md, Acceptance Criteria (AC3)
  - Spec text: "A regression test proves a live session file survives a testing-runner invocation that uses the active story's STORY_ID."
  - Implementation: `test_write_does_not_modify_existing_live_session` proves a populated live session survives a `write_test_run_cache(...)` call keyed on a RUN_ID that embeds the active STORY_ID — the exact collision case — rather than spawning the `testing-runner` subagent.
  - Rationale: `testing-runner` is the system under test and is non-deterministic (a haiku agent); spawning it with `STORY_ID: 158-2` would clobber THIS live session — reproducing the very data-loss bug on our own audit trail. The faithful, deterministic proof is the helper contract the agent will call (SOUL #11: promote to a script).
  - Severity: minor
  - Forward impact: Dev must wire `testing-runner.md` to actually call the helper; a full end-to-end agent run is out of scope for unit RED. Reviewer should confirm the markdown→helper wiring closes the loop.
- **RED verified via direct scoped pytest, not the testing-runner subagent**
  - Spec source: agent-behavior guide, "Tests: Use testing-runner subagent, never run directly."
  - Spec text: "never run directly"
  - Implementation: RED confirmed with a single-file scoped run (`uv run pytest src/pf/tests/test_158_2_testrun_cache_isolation.py -q`) per the TEA `scoped-red-run` sidecar pattern.
  - Rationale: `testing-runner` (a) is the SUT and would clobber the live session, and (b) sources deleted scripts (`test-setup.sh`), so it cannot run cleanly. Direct scoped run avoids both, and the full suite is barred (the `test_git_utils.py` branch-leak caveat).
  - Severity: minor
  - Forward impact: none — Dev/Reviewer should likewise use scoped runs until this story lands.

### Dev (implementation)
- **Added a `python -m pf.session.test_cache` entrypoint + CLI test (beyond the RED contract)**
  - Spec source: TEA Assessment, "Contract for Dev (GREEN)" + Delivery Finding (Question, bash→python wiring)
  - Spec text: "testing-runner runs bash, so to call the new helper it needs a shell-reachable entrypoint … The wiring choice … is Dev's."
  - Implementation: added `main()` + `if __name__ == "__main__"` to `pf.session.test_cache` and a separate `test_158_2_test_cache_cli.py` (3 tests). The agent invokes `printf '%s' "$SUMMARY" | python -m pf.session.test_cache "$RUN_ID"`.
  - Rationale: honors One Truth (#2) — path logic lives once in Python, not duplicated in bash — and #11 (promote to a script). Chose `python -m` over a `pf` Click subcommand because this is an internal runner helper, not a user-facing command.
  - Severity: minor
  - Forward impact: none — additive internal surface, fully covered by tests.
- **Did NOT change `agents/README.md` despite TEA's finding flagging it**
  - Spec source: Delivery Findings → TEA (test design), "README.md mirrors the same clobbering cache-write"
  - Spec text: "fix the doc too, or the system stays half-broken"
  - Implementation: investigated `agents/README.md` lines ~216 and ~278; both are legitimate session uses (a path-standard *example*, and the `bg_task_add` background-task tracker that intentionally records into the live session), NOT the test-result cache. Left unchanged.
  - Rationale: changing them would be wrong (they're not the defect) and scope creep. The test-cache clobber existed only in `testing-runner.md`.
  - Severity: minor
  - Forward impact: none — finding resolved as not-applicable; see Dev delivery finding below.
- **Scoped the fix to the cache write; left the Setup section's broken `source` for a follow-up**
  - Spec source: Delivery Findings → TEA (test design), "Setup + Test Cache sections" source deleted scripts
  - Spec text: "test-cache.sh and test-setup.sh have been DELETED … repoint or remove the stale script references"
  - Implementation: fixed the Test Cache section (the data-loss path) + `scripts/test/README.md`. The Setup section still `source`s the deleted `test-setup.sh` (`ensure_test_containers`/`generate_run_id`) — left as-is.
  - Rationale: that is a separate container-setup breakage, not the gh #53 data-loss bug; fixing it here is scope creep. Logged as a Delivery Finding for a follow-up story.
  - Severity: minor
  - Forward impact: `testing-runner` container setup remains broken independent of this fix (pre-existing).

### Reviewer (audit)
- **TEA: regression test targets the helper, not a live testing-runner invocation** → ✓ ACCEPTED by Reviewer: correct call — driving the SUT with `STORY_ID: 158-2` would clobber the live session; the helper contract is the right deterministic proof.
- **TEA: RED verified via direct scoped pytest, not testing-runner** → ✓ ACCEPTED by Reviewer: the runner is the SUT and sources deleted scripts; scoped run is the only safe path. Matches the `scoped-red-run` pattern.
- **Dev: added `python -m pf.session.test_cache` entrypoint + CLI test** → ✓ ACCEPTED by Reviewer: honors One Truth (#2) and #11; `python -m` over a `pf` subcommand is reasonable for an internal helper.
- **Dev: did NOT change `agents/README.md`** → ✓ ACCEPTED by Reviewer: independently verified — README ~L216 is a path-standard example and ~L278 is the `bg_task_add` background-task tracker; neither is the test-result cache. Leaving them is correct, not a gap.
- **Dev: scoped the fix to the cache write; left Setup's broken `source` for follow-up** → ✓ ACCEPTED by Reviewer: the deleted `test-setup.sh` source is a separate container-setup breakage, not the data-loss bug. Correct scoping; tracked as a Delivery Finding.

## Sm Assessment

**Routing:** 3-pt `tdd` bug fix → full pipeline: TEA (RED) → Dev (GREEN) → Reviewer → finish. No TEA skip (that's only for 1-2pt trivial).

**Scope (for TEA/Dev):** This is a P1 data-loss bug in the `pennyfarthing/` repo, gh #53. The `testing-runner` subagent's result-cache write collides with the live workflow session at `.session/{STORY_ID}-session.md` and clobbers it. The fix is path-namespacing, not logic — preferred approaches are option 1 (cache to `.session/test-runs/{RUN_ID}.md`) or option 2 (key the filename on the already-unique RUN_ID). Option 3 (refuse-to-write guard) is a defensive complement, not the primary fix.

**RED phase focus (Igor):** Write a failing regression test proving a populated live session file survives a `testing-runner` invocation that uses the *active story's* STORY_ID. The repro from #53: live session holds the audit trail → testing-runner runs with that STORY_ID → session is replaced by a `# Test Session:` summary. Test should assert the workflow frontmatter / `## ... Assessment` content is intact after the run.

**Branch:** `feat/158-2-testing-runner-session-clobber` off `origin/develop` (pennyfarthing is gitflow — PR targets `develop`, NOT main).

**Hard caveat:** Do NOT run the full pytest suite — `test_git_utils.py` leaks a `feature/test` checkout onto the live branch. Use targeted runs; commit before any full-suite run.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (17 failed, 1 passed — ready for Dev)

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_158_2_testrun_cache_isolation.py` (new) — 18 tests, 3 groups.

**Tests Written:** 18 tests covering 3 ACs.

| AC | Tests | What it proves |
|----|-------|----------------|
| AC2 — namespaced + RUN_ID-keyed cache path | `TestTestRunCachePath` (9) | cache lives under `.session/test-runs/<run_id>.md`, never equals the live session path, distinct per RUN_ID; input validation (empty / `..` traversal / NUL byte) |
| AC1 + AC3 — live session survives | `TestLiveSessionProtection` (6) | a populated live session is byte-identical after a cache write; cache lands at the namespaced path; `is_live_session_file()` guard detects frontmatter & assessment headings, rejects cache files & missing files |
| System fix — instructional | `TestTestingRunnerAgentDoc` (3) | `testing-runner.md` no longer instructs a bare `{STORY_ID}-session.md` cache write; routes the cache through a RUN_ID-keyed `test-runs/` path |

**Contract for Dev (GREEN):** Implement `pf.session.test_cache` with:
- `test_run_cache_path(root: Path, run_id: str) -> Path` → `<root>/.session/test-runs/<run_id>.md`; validate `run_id` (`[A-Za-z0-9_-]+`, non-empty; reject traversal/NUL) and raise `ValueError` (mirror `pf.session.paths.canonical_session_path`).
- `is_live_session_file(path: Path) -> bool` → True iff the file exists and contains `story_id:` frontmatter or an `## ... Assessment` heading.
- `write_test_run_cache(root, run_id, content) -> dict` → result object `{success, path?, error?}` (SOUL #10); writes to the namespaced path (mkdir parents); never writes a live session.
Then update `agents/testing-runner.md` (Test Cache + Setup sections) to route the cache through that helper, and clean up the stale `test-cache.sh`/`test-setup.sh` references (see Delivery Findings). The module-import RED failures are `ModuleNotFoundError: pf.session.test_cache` — exactly the missing implementation.

### Rule Coverage (python lang-review)

| Rule | Test(s) | Status |
|------|---------|--------|
| #11 input validation / CWE-22 path traversal | `test_rejects_path_traversal_run_id`, `test_rejects_empty_run_id`, `test_rejects_nul_byte_run_id` | failing |
| path-handling (pathlib, no string concat) | `test_returns_pathlib_path`, `test_path_is_under_root` | failing |
| return Result objects (SOUL #10) | `test_write_does_not_modify_existing_live_session` (asserts `{success: True}`) | failing |
| error-path logging | NOTE for Dev: log a `warning` when the guard refuses a write (not unit-asserted) | — |

**Rules checked:** 3 of 3 applicable lang-review rules have test coverage (input-validation, path-handling, result-return).
**Self-check:** 0 vacuous tests — every test has a meaningful assertion; no `let _ =` / `assert True` / always-None checks. The 1 passing test is an intentional doc-exists sanity check.

**Handoff:** To Ponder Stibbons (Dev) for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Tests:** 21/21 passing (GREEN) — 18 in `test_158_2_testrun_cache_isolation.py` (TEA) + 3 in `test_158_2_test_cache_cli.py` (Dev).
**Branch:** `feat/158-2-testing-runner-session-clobber` (pushed to origin)
**Commit:** `1fd984e6d` (GPG-signed)

**Files Changed:**
- `pennyfarthing-dist/src/pf/session/test_cache.py` (new) — `test_run_cache_path()` (namespaces to `.session/test-runs/{RUN_ID}.md`, validates RUN_ID), `is_live_session_file()` (frontmatter/assessment detector), `write_test_run_cache()` (result object, refuses to overwrite a live session), and a `python -m` entrypoint. Mirrors `pf.session.paths` conventions (regex allowlist, `ValueError`, `TypedDict`).
- `pennyfarthing-dist/agents/testing-runner.md` — Test Cache section rewritten to pipe the summary through `python -m pf.session.test_cache "$RUN_ID"`; removed the deleted-script `source` and the bare-session-path write; args table + execution-steps gate updated to reflect RUN_ID keying.
- `pennyfarthing-dist/scripts/test/README.md` — corrected stale references to the removed bash scripts; documents the new entrypoint.
- `pennyfarthing-dist/src/pf/tests/test_158_2_test_cache_cli.py` (new) — covers the CLI entrypoint (write, live-session protection, invalid RUN_ID).
- `pennyfarthing-dist/src/pf/tests/test_158_2_testrun_cache_isolation.py` — ruff import-order autofix (1 line).

**Verification:**
- Scoped pytest (the 5 changed/related test files): 56 passed. `ruff check` clean on all changed Python.
- **Real end-to-end smoke test** (per my own "smoke-test against reality" gotcha): ran `python -m pf.session.test_cache 67-1-dev-green-rework2` against a sandbox repo holding a populated `67-1-session.md`; the live session was **byte-identical** (md5 match) afterward and the summary landed at `.session/test-runs/67-1-dev-green-rework2.md`. The clobber is fixed at the source.
- Did NOT run the full suite (the `test_git_utils.py` branch-leak caveat) and did NOT spawn `testing-runner` with `STORY_ID: 158-2` (it is the SUT).

**ACs:** AC1 (never overwrites a live session) ✅, AC2 (namespaced, RUN_ID-keyed cache) ✅, AC3 (regression proves a live session survives) ✅.

**Handoff:** To Igor (TEA) for the verify phase (simplify + quality-pass).

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 (GREEN 21/21, ruff clean, 0 smells) | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 6 | confirmed 5 (severity-downgraded), dismissed 0, deferred 1 (TOCTOU) |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 3 | confirmed 3 (severity-downgraded), dismissed 0, deferred 0 |
| 4 | reviewer-test-analyzer | Yes | findings | 7 | confirmed 4 (severity-downgraded), dismissed 0, deferred 3 (low/dup) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — self-checked: docstrings accurate, no stale comments |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — self-checked: `CacheWriteResult` TypedDict + `Path` returns sound |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 1 (LOW, CWE-59), 1 informational (no injection) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — self-checked: module is minimal, no over-engineering |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — I ran the rule-by-rule enumeration myself (see Rule Compliance) |

**All received:** Yes (5 enabled returned, 4 disabled pre-filled)
**Total findings:** 13 confirmed (all MEDIUM/LOW, non-blocking, with rationale), 0 dismissed, 4 deferred/dup

## Reviewer Assessment

**Verdict:** APPROVED

**Why approved despite 13 findings:** All three ACs are met and independently verified (Dev smoke-tested the real entrypoint — a populated live session was byte-identical after a cache write). Every confirmed finding, severity-assessed *in context*, is MEDIUM or LOW: the failure modes are **loud** (traceback + non-zero exit), **benign** (a missing cache, never the old clobber), or **threat-model-inapplicable** (CWE-59 needs pre-existing filesystem write access on a single-user local tool). Nothing reintroduces data loss — this change *removes* a P1 data-corruption bug. No Critical/High → no block. The high-value hardening is captured as non-blocking Delivery Findings for a follow-up.

**Data flow traced:** `RUN_ID` (agent-set, e.g. `67-1-dev-green`) → bash `"$RUN_ID"` (double-quoted, no split/injection) → argv → `test_run_cache_path` allowlist `^[A-Za-z0-9_-]+$` (rejects `/`,`.`,`\`,NUL → no CWE-22) → `<root>/.session/test-runs/<run_id>.md`. The summary (`$RESULT_SUMMARY` via `printf '%s\n'`, no format-injection) → stdin → `write_test_run_cache` → namespaced file. The live session path `<root>/.session/<story>-session.md` is never on this path. Safe.

### Observations

- `[VERIFIED]` Cache path can never equal the live session path — `test_cache.py:191-193` builds `.session/test-runs/<run_id>.md`; the `test-runs/` segment guarantees orthogonality from `.session/<story>-session.md`. Proven by `test_never_equals_live_session_path` and the real smoke test (md5 unchanged). Complies with the One-Truth/SOUL-#2 intent.
- `[SEC]` `[RULE]` CWE-59: `write_test_run_cache` writes an unresolved `target` (`test_cache.py:216-245`) — LOW; matches project rule python.md #5 (confirmed, not dismissed; downgraded — allowlist blocks CWE-22, symlink vector needs FS write access on a local tool).
- `[EDGE]` `[SILENT]` `main()` leaves `get_project_root()` `FileNotFoundError` and `sys.stdin.read()` errors uncaught (`test_cache.py:248-273`) → raw traceback vs the docstring's promised structured `error:` (SOUL #10). MEDIUM — unreachable on the real runtime path; loud + benign. Two specialists corroborated.
- `[SILENT]` The bash cache-write (`testing-runner.md`) has no exit-code check → silent cache-miss on failure. MEDIUM — benign vs the prior clobber.
- `[TEST]` The `OSError` write path and the defensive guard branch are untested; `result.get("path") in (expected, str(expected))` accepts a dead `str` form (`test_*_isolation.py:233`). MEDIUM (rule #6) — correct code, untested branches.
- `[EDGE]` `is_live_session_file` is a content heuristic — fail-open on non-UTF-8, possible false-positive (fail-safe → stale cache only). LOW.
- `[VERIFIED]` `[TYPE]` (self-checked, type_design disabled) — `CacheWriteResult(TypedDict, total=False)` + `Path` returns + `ValueError` on bad input mirror the sibling `pf.session.paths` conventions exactly (`test_cache.py:163-193`). Sound type design.
- `[VERIFIED]` `[DOC]` (self-checked, comment_analyzer disabled) — module + function docstrings accurately describe behavior and cite gh #53/SOUL principles; `scripts/test/README.md` corrected to match reality. No stale/misleading docs.
- `[VERIFIED]` `[SIMPLE]` (self-checked, simplifier disabled) — module is minimal: three small functions + a thin CLI. No dead code beyond the documented defensive guard, no over-engineering.
- `[VERIFIED]` No command injection — `"$RUN_ID"` double-quoted, `printf '%s\n' "$RESULT_SUMMARY"` routes content as stdin data, Python re-validates RUN_ID. Confirmed by reviewer-security.

### Rule Compliance (python lang-review, enumerated by Reviewer — rule_checker disabled)

| # | Rule | Verdict |
|---|------|---------|
| 1 | Silent exception swallowing | PASS — `is_live_session_file` catches specific `(OSError, UnicodeDecodeError)` returning False (predicate contract); `write_test_run_cache` catches specific exceptions returning result objects. No bare except. (LOW note: no logging, consistent with SOUL #10.) |
| 2 | Mutable default arguments | PASS — only `main(argv=None)`. |
| 3 | Type annotation gaps at boundaries | PASS — all public functions fully annotated incl. returns. |
| 4 | Logging coverage/correctness | N/A — module does not import logging; uses result objects (SOUL #10) + CLI stderr. |
| 5 | Path handling | PARTIAL — pathlib throughout, `encoding="utf-8"` on read/write (CWE-838 ✓); **missing `.resolve()` before the guard (CWE-59)** — confirmed LOW finding `[SEC]`. |
| 6 | Test quality | PARTIAL — no vacuous `assert True`; meaningful assertions; **but** error/guard branches untested + one loose `str` assertion — confirmed MEDIUM finding `[TEST]`. |
| 7 | Resource leaks | PASS — `read_text`/`write_text`, no dangling handles. |
| 8 | Unsafe deserialization | PASS — no pickle/eval/yaml.load; bash uses no `shell=True`, content via stdin. |
| 9 | Async/await pitfalls | N/A — no async. |
| 10 | Import hygiene | PASS — `__all__` defined, no star imports; `import argparse` lazy in `main()` (acceptable); no cycles (`pf.common.config` is a leaf). |
| 11 | Input validation at boundaries | PASS — RUN_ID allowlist at the CLI/path boundary blocks CWE-22; content is opaque text. |
| 12 | Dependency hygiene | PASS — no new dependencies. |
| 13 | Fix-introduced regressions | PASS — the fix introduces no new #1-12 violations beyond the LOW CWE-59 noted. |

### Devil's Advocate

Let me argue this code is broken. First, the whole fix hinges on a *content heuristic* to recognise a live session — `^story_id:` or `## ... Assessment` anywhere in a file. That is fragile: the day someone renames the assessment heading, or a session uses a different frontmatter key, the guard goes blind. But — and this is why it doesn't sink the change — the guard is only a *backstop*; the real protection is structural namespacing (`test-runs/`), which no heuristic weakness can defeat. The clobber cannot happen because the write target is never the session path, heuristic or not.

Second, a malicious or confused actor: could they make the runner write somewhere dangerous? Only via a symlink planted at `.session/test-runs/` (CWE-59), which presupposes they already hold write access to the project tree — at which point they need no exploit. RUN_ID itself is neutered by the allowlist; `--help` as a RUN_ID would make argparse exit 0 without writing (a benign no-op the caller can't distinguish from success — noted, low). What would a stressed filesystem do? A read-only `.session/`, disk-full, or a regular file where a directory is expected → `OSError`, caught, returned as `{success: False}` — except the two `main()` paths (`get_project_root`, `stdin.read`) that escape as tracebacks. A confused user piping nothing writes an empty cache file — harmless. What if `pf` isn't importable in the agent's `python`? The call fails loudly and the cache simply isn't written — the session is untouched. Every adversarial path I can construct ends in one of three places: a loud error, a benign missing cache, or an attack that already requires higher privilege than the exploit grants. The one thing the original bug did — silently destroy the audit trail — is exactly the thing this code makes impossible. The defects that remain are robustness polish on a correct, safe core. That is an APPROVE, not a REJECT — but the `main()` error-handling and the `.resolve()` hardening are worth a quick follow-up so a fix-for-a-data-loss-bug is itself bulletproof.

**Handoff:** To Captain Carrot (SM) for finish-story.

## Additional Context

### P1 Data-Loss Bug (gh issue #53)

**Problem:**
The `testing-runner` subagent writes its test-result summary to `.session/{STORY_ID}-session.md` — the SAME path as the live workflow session file owned by the SM/TEA/Dev/Architect handoff machinery. When invoked with the active story's STORY_ID (the normal case during TDD GREEN/verify), it OVERWRITES the live session file, destroying agent assessments, Delivery Findings, Design Deviations, and Workflow Tracking that the handoff gates parse. Session file is gitignored → clobber is unrecoverable except by hand.

**Root Cause:**
testing-runner's test-result cache write shares the `.session/{STORY_ID}-session.md` namespace with the live session; it is not namespaced away.

**Suggested Fixes (any one closes it):**
1. Namespace the test-result cache to a distinct path, e.g. `.session/test-runs/{RUN_ID}.md` — never the bare `{STORY_ID}-session.md`.
2. Key the results filename on RUN_ID (already unique per run, e.g. `67-1-dev-green-rework2`) not STORY_ID.
3. Refuse to write if the target already contains workflow frontmatter (`story_id:` / `## ... Assessment`) — fail loud instead of overwriting.

### Acceptance Criteria
- testing-runner never overwrites a live `.session/{STORY_ID}-session.md` workflow session file.
- Test-result summaries are written to a distinct, namespaced path (keyed on RUN_ID).
- A regression test proves a live session file survives a testing-runner invocation that uses the active story's STORY_ID.

### Important Caveat (Downstream Agents)
The full pytest suite switches the live git branch (`test_git_utils.py` leaks a `feature/test` checkout). Use TARGETED test runs for this story; commit before any full-suite run.

### Files Likely Involved
- testing-runner subagent definition at `pennyfarthing/pennyfarthing-dist/agents/`
- Python helper that computes the session/results path
- Test case to verify regression fix

## Branch Info
**Branch Strategy:** gitflow (feat/158-2-testing-runner-session-clobber)
**Repository:** pennyfarthing
**Repo Root:** /Users/slabgorb/Projects/orc-penny/pennyfarthing