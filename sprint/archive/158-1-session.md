---
story_id: "158-1"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 158-1: pf agent start crashes with stack trace when .session symlink target is missing (gh #63)

## Story Details
- **ID:** 158-1
- **Jira Key:** (none — Jira disabled)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-04T11:12:36Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-04T10:58:34Z | 2026-06-04T10:59:55Z | 1m 21s |
| red | 2026-06-04T10:59:55Z | 2026-06-04T11:04:07Z | 4m 12s |
| green | 2026-06-04T11:04:07Z | 2026-06-04T11:06:47Z | 2m 40s |
| review | 2026-06-04T11:06:47Z | 2026-06-04T11:12:36Z | 5m 49s |
| finish | 2026-06-04T11:12:36Z | - | - |

## Sm Assessment
**Story:** 158-1 — `pf agent start` crashes on a dangling `.session` symlink (gh #63). p1 bug, 2pts, tdd workflow, pennyfarthing repo (targets develop).

**Why now:** p1 — agent activation is the front door of every workflow. A fresh clone/worktree carrying the `.session → sprint/.session` symlink without the target dir crashes `pf agent start` with a raw traceback before any work can begin.

**Scope:** Single well-isolated fix in `src/pf/prime/session.py` `register_session` (~line 73). The `agents_dir.mkdir(parents=True, exist_ok=True)` call assumes `.session` is a real dir; on a dangling symlink it raises `FileExistsError`. Fix is to resolve the symlink target before mkdir, and/or detect the dangling link and emit an actionable error. Optional bootstrap of `sprint/.session/` is in scope as a bonus, not required for AC pass.

**Routing:** TDD phased → TEA (Igor) writes the RED regression test reproducing the dangling-symlink crash (AC3), then Dev (Ponder) makes it green with the minimal fix. Watch AC2: the agents dir must land at the resolved target (`sprint/.session/agents`), not as a literal `.session/agents` that shadows the symlink.

**Handoff to TEA:** Reproduce the dangling-symlink scenario in a tmpdir/fixture, assert no `FileExistsError`/traceback, and protect the happy-path (real `.session` dir) from regression (AC4).

## Problem
`pf agent start <agent>` hard-crashes with an unhandled exception when `.session` is a symlink whose target directory does not exist (dangling symlink). A fresh checkout/worktree that includes the `.session → sprint/.session` symlink but not the target dir hits this immediately.

## Root Cause
`register_session` in `src/pf/prime/session.py` (~line 73) calls `agents_dir.mkdir(parents=True, exist_ok=True)` on `.session/agents`. Because `.session` is a broken symlink (not a real dir), `mkdir(parents=True)` tries to create the parent `.session`, which "exists" as a dangling symlink → `FileExistsError`. The command aborts with a Python traceback instead of an actionable error.

## Suggested Fix (for Dev — not binding)
In `register_session` (and anywhere `.session` is assumed to be a real dir):
- Resolve the symlink and create the target directory (`agents_dir.resolve().mkdir(parents=True, exist_ok=True)`), OR
- Detect a dangling `.session` symlink and either create its target or emit a clear, actionable error instead of a traceback.
Bonus: project setup/clone bootstrap could create `sprint/.session/` so the symlink is never dangling on fresh checkout.

## Acceptance Criteria
- AC1: `pf agent start <agent>` succeeds (or fails with a clear, actionable message — no raw traceback) when `.session` is a dangling symlink whose target dir does not exist.
- AC2: When the fix auto-creates the target, the symlink resolves correctly and the agents dir is created at the symlink target (sprint/.session/agents), not as a literal `.session/agents` shadowing the link.
- AC3: A regression test reproduces the dangling-symlink scenario and asserts no FileExistsError/traceback.
- AC4: Existing happy-path (real `.session` dir) behavior is unchanged.

## Crash Reference
- File: src/pf/prime/session.py:73 — register_session
- Errors: FileNotFoundError on `.session/agents` then FileExistsError [Errno 17] on `.session`
- Reproduce: `.session` symlink → `sprint/.session` where `sprint/.session/` does NOT exist, then `pf agent start "devops"`.
- Workaround: `mkdir -p sprint/.session/agents`

## TEA Assessment

**Tests Required:** Yes
**Reason:** P1 bug fix with a precise, reproducible crash — TDD RED is warranted (a regression test is explicitly AC3).

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_158_1_dangling_session_symlink.py` (new) — 6 tests exercising `register_session` against dangling / real / existing-target `.session` paths.

**Tests Written:** 6 tests covering 4 ACs
**Status:** RED confirmed — `4 failed, 2 passed in 0.25s` (scoped single-file run; full suite avoided per the `test_git_utils.py` branch-leak landmine).

The 4 failing tests all fail for the *right* reason: `FileExistsError [Errno 17]` raised at `src/pf/prime/session.py:73` (`agents_dir.mkdir(parents=True, exist_ok=True)`) — the exact bug. No collection/import errors. The 2 passing tests are AC4 regression guards (real dir + symlink-to-existing-target), asserting Dev's fix must not break already-working cases.

| Test | AC | RED status |
|------|-----|-----------|
| `test_register_session_dangling_symlink_does_not_raise` | AC1/AC3 | failing (FileExistsError) |
| `test_register_session_dangling_symlink_no_file_exists_error` | AC3 | failing (FileExistsError) |
| `test_register_session_dangling_symlink_creates_resolved_target` | AC2 | failing (FileExistsError) |
| `test_register_session_dangling_symlink_not_shadowed` | AC2 | failing (FileExistsError) |
| `test_register_session_real_session_dir_unchanged` | AC4 | passing (guard) |
| `test_register_session_symlink_to_existing_target_unchanged` | AC4 | passing (guard) |

### Rule Coverage

| Rule (lang-review/python.md) | Test(s) | Status |
|------|---------|--------|
| #5 Path handling — missing `Path.resolve()` before symlink-sensitive op (CWE-59) | `..._creates_resolved_target`, `..._not_shadowed` | failing |
| #6 Test quality — no vacuous asserts | self-check (all tests assert concrete values; `pytest.fail` is a meaningful negative assertion) | n/a |

**Rules checked:** 1 of 6 applicable lang-review rules has direct test coverage. Rules #1–4 (exception swallowing, mutable defaults, type-annotation gaps, logging) do not apply — the fix is a single mkdir-target change with no new error handling, defaults, signatures, or logging.
**Self-check:** 0 vacuous tests found.

**Guidance for Dev (Ponder):** The clean fix is to create the *resolved* target before mkdir, e.g. `agents_dir.resolve().mkdir(parents=True, exist_ok=True)` (Python `resolve(strict=False)` resolves the dangling link to `sprint/.session/agents` without requiring existence). Do **not** replace the `.session` symlink with a real dir — `test_..._not_shadowed` asserts the link survives. Keep the happy-path branch intact (AC4 guards).

**Handoff:** To Dev (Ponder Stibbons) for GREEN implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/prime/session.py` — in `register_session`, resolve the agents path before creating it: `agents_dir.resolve().mkdir(parents=True, exist_ok=True)`. `resolve()` follows the `.session` symlink to its real target (`sprint/.session/agents`) so a dangling link creates the target instead of crashing on the existing-but-dangling symlink. One-line change + explanatory comment referencing gh #63.

**Approach:** Took TEA's recommended fix exactly — the minimal change at the crash site. No bootstrap of `sprint/.session/` was added (explicitly out of scope per SM; the resolve() fix handles the dangling case at point-of-use, which is more robust than a one-time bootstrap). The symlink is left intact (never replaced by a real dir), satisfying AC2.

**Tests:** 6/6 passing (GREEN) — scoped run `0.14s`. Sibling `test_prime.py::TestSessionRegistration` (5 tests) still pass — no regression. Full suite intentionally not run (avoids the `test_git_utils.py` branch-leak landmine); scoped + sibling coverage is sufficient for this single-function change.
**Branch:** `feat/158-1-agent-start-dangling-session-symlink` (pushed to origin)

**AC verification:**
- AC1 ✓ — `register_session` succeeds on a dangling `.session` symlink (no traceback)
- AC2 ✓ — agents dir created at resolved `sprint/.session/agents`; `.session` stays a symlink (not shadowed)
- AC3 ✓ — regression tests reproduce the dangling scenario and assert no `FileExistsError`
- AC4 ✓ — real-dir and symlink-to-existing-target paths unchanged (guards green)

**Handoff:** To Reviewer (Granny Weatherwax) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 1 (lint I001) | confirmed 1 (LOW), dismissed 0, deferred 0 |
| 2 | reviewer-edge-hunter | Yes | findings | 6 | confirmed 1 (LOW, known-limitation), dismissed 5 (pre-existing / not introduced by diff) |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 3 | confirmed 1 (LOW→delivery), dismissed 2 (pre-existing, not in diff) |
| 4 | reviewer-test-analyzer | Yes | findings | 6 | confirmed 1 (LOW), dismissed 5 (out-of-AC-scope / covered by sibling test) |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings |
| 6 | reviewer-type-design | No | Skipped | disabled | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 1 (MEDIUM, pre-existing→delivery Gap), 1 (LOW→delivery Improvement); 0 in-scope blocking |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings |
| 9 | reviewer-rule-checker | No | Skipped | disabled | Disabled via settings (rule compliance done manually below) |

**All received:** Yes (5 enabled returned, 4 disabled/skipped)
**Total findings:** 2 confirmed in-scope (both LOW, non-blocking), 12 dismissed/deferred (with rationale), 2 routed to Delivery Findings (pre-existing, out of diff)

## Reviewer Assessment

**Verdict:** APPROVED

The fix is exactly right and minimal: `agents_dir.resolve().mkdir(parents=True, exist_ok=True)` (session.py:79). `resolve()` (strict=False default) follows the `.session` symlink to its real target *without* requiring the target to exist, so a dangling link now creates `sprint/.session/agents` instead of crashing on the existing-but-dangling parent symlink. The `.session` symlink is left intact (not shadowed). All 4 ACs are satisfied and the test suite is GREEN (11/11: 6 story tests + 5 sibling `TestSessionRegistration` — no regression).

**Data flow traced:** `register_session(agent_name, session_id, project_root)` → `agents_dir = root/.session/agents` → `agents_dir.resolve().mkdir(...)` creates the real target → `session_file = agents_dir / session_id` (unresolved) `.write_text(agent_name)`. I verified the post-mkdir use of the *unresolved* `agents_dir` (in `_purge_stale_agents` and the file write) is safe: once the resolved target exists, the symlink resolves correctly and both operations land at the same real location (confirmed by `test_..._creates_resolved_target`, which reads back through the symlink path).

**Observations (8):**
1. `[VERIFIED]` resolve()-before-mkdir is correct — session.py:79. Complies with python lang-review **#5** (Path.resolve before symlink-sensitive op, CWE-59). Evidence: `test_register_session_dangling_symlink_creates_resolved_target` + `..._not_shadowed` both green; sibling `TestSessionRegistration` green.
2. `[VERIFIED]` No regression — AC4 guards (`..._real_session_dir_unchanged`, `..._symlink_to_existing_target_unchanged`) green; `test_prime.py::TestSessionRegistration` (5) green. The unresolved-path operations after the resolved mkdir still work.
3. `[SEC]` `[LOW]` resolve() performs no post-resolve containment check — a misconfigured/malicious `.session` symlink pointing outside the project would have a directory created at its target. session.py:79. **Non-blocking:** `.session` is a repo-committed, developer-trusted symlink (`.session -> sprint/.session`); this is a local CLI tool, not an untrusted-input boundary. The previous code also followed existing symlink targets — the fix does not introduce a new *trust* boundary, only makes the dangling case succeed. Routed to Delivery Findings as a hardening Improvement.
4. `[SEC]` `[MEDIUM]` `session_id` (incl. `os.environ['SESSION_ID']`) is joined to `agents_dir` as a path component without sanitization → CWE-22 traversal on write (line 92), read (line 149), unlink (line 173). **Dismissed as a blocker for THIS PR: pre-existing — none of those lines are in the diff.** Real and worth fixing; routed to Delivery Findings as a Gap for a follow-up story.
5. `[EDGE]` `[LOW]` `.session` symlink pointing to a *file* (or an intermediate symlink-to-non-dir) still raises (`NotADirectoryError`/`FileExistsError`). **Known limitation, out of AC scope:** the committed symlink is dir-or-missing, never a file; the *old* code also crashed on this input, so it is not a regression. Noted, not blocking.
6. `[TEST]` `[LOW]` `test_register_session_dangling_symlink_no_file_exists_error` asserts nothing on the success path (a hypothetical silent `return None` would pass). **Minor:** the sibling `..._does_not_raise` asserts `result.session_id`/`agent_name` on the identical scenario, so the no-op case is in fact covered. The other missing-case suggestions (env SESSION_ID, idempotency, symlink-to-file, `result.file_path`) are out of this story's AC scope.
7. `[LOW]` Lint: `I001` import-block-unsorted in `test_158_1_dangling_session_symlink.py:29` — independently confirmed via `uv run ruff check`. Auto-fixable (`ruff check --fix`); production `session.py` is lint-clean. Non-blocking per severity rubric, but **should be `--fix`'d before the PR is created** (one command).
8. `[SILENT]` Pre-existing best-effort error-swallowing in `_purge_stale_agents` (line 46) and ambiguous `False` in `unregister_session` (line 178) — not introduced by this diff, not in scope. Noted only.

**Disabled specialists:** `[DOC]` comment-analyzer, `[TYPE]` type-design, `[SIMPLE]` simplifier, `[RULE]` rule-checker — disabled via `workflow.reviewer_subagents`. I performed the rule pass manually (see Rule Compliance). Type/comment/simplify surface area is trivial for a one-line change with a clear explanatory comment.

### Rule Compliance (python lang-review)

- **#5 Path handling (resolve before symlink op, CWE-59):** session.py:79 — COMPLIANT (the fix *is* the resolve()).
- **#11 Input validation / path traversal (CWE-22):** the changed line adds no user-input path join; the pre-existing `session_id` join (lines 87/92/149/173) is a latent violation but is OUT OF DIFF — recorded as a Delivery Gap, not a gate on this PR.
- **#1 silent exceptions / #2 mutable defaults / #3 type annotations / #7 resource leaks / #8 unsafe deserialization:** N/A — the diff adds no except blocks, defaults, signatures, file/resource handles, or deserialization. The existing function signature retains its annotations (unchanged).
- **#6 Test quality:** test file has meaningful, concrete assertions; one weak case (obs. 6) mitigated by a sibling test. No vacuous `assert True`, no unexplained skips.

### Devil's Advocate

Let me argue this code is broken. The most dangerous word in the diff is `resolve()`. By calling `agents_dir.resolve()` the code abandons the lexical safety of staying inside the project tree and hands directory-creation authority to whatever `.session` points at. A malicious teammate could commit `.session -> ../../../../etc/cron.d` and the next `pf agent start` would `mkdir -p` straight into a system directory as the running user — `resolve(strict=False)` won't blink, `mkdir(exist_ok=True)` won't complain, and `write_text(agent_name)` will drop a file named by an env-controlled `SESSION_ID` (which itself can be `../../somewhere`). Two unsanitized primitives — symlink-following and a raw `session_id` path join — now sit on the same write path with no containment assertion. A stressed filesystem makes it worse: between the resolved `mkdir` (line 79) and the unresolved `write_text` (line 93) another process can delete the directory, and the resulting `PermissionError`/`OSError` escapes `register_session` as a raw traceback — the exact "actionable error, not a stack trace" failure the story set out to eliminate, just relocated. And a confused user who symlinks `.session` to an existing *file* still gets a traceback, because the fix only anticipated the missing-directory shape of the bug.

How much of that actually lands? The symlink-escape and `SESSION_ID` traversal are genuine (CWE-59/CWE-22) but live behind a developer-trusted, repo-committed surface in a local CLI — and the `SESSION_ID` join is **pre-existing**, untouched by this diff, so it cannot be a regression of this change. The TOCTOU and symlink-to-file tracebacks are real but are unhandled-exception shapes that also existed before (the function never wrapped its I/O in the result-object contract). None is introduced-and-in-scope, and none is reproducible under the story's threat model. They are worth a hardening follow-up — captured below — but they do not make *this* fix wrong. The change does precisely what AC1–AC4 demand and nothing it shouldn't. Verdict stands: APPROVED, with the lint cleaned up before merge.

**Handoff:** To SM for finish-story.

## Delivery Findings

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No upstream findings.

### Dev (implementation)
- No upstream findings.

### Reviewer (code review)
- **Gap** (non-blocking): `session_id` (including `os.environ['SESSION_ID']`) is joined to `agents_dir` as a path component with no sanitization, enabling CWE-22 traversal on write/read/unlink. Affects `pennyfarthing-dist/src/pf/prime/session.py` (sanitize `session_id` — reject `/` and `..`, or use `Path(session_id).name` — in `register_session`/`get_session_agent`/`unregister_session`). Pre-existing; out of this diff. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `agents_dir.resolve()` has no post-resolve containment check, so a misconfigured/malicious `.session` symlink could create a dir outside the project root. Affects `pennyfarthing-dist/src/pf/prime/session.py` (assert the resolved path stays under `root.resolve()` and raise a descriptive error otherwise). Developer-trusted surface today; worth hardening if `pf` ever runs in shared/CI contexts. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Lint `I001` (import-block-unsorted) in `pennyfarthing-dist/src/pf/tests/test_158_1_dangling_session_symlink.py:29` — run `uv run ruff check --fix` on the file before the PR is created. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

1 deviation

- **AC1 narrowed to the auto-create-success branch (not the "actionable error" alternative)**
  - Rationale: The issue's primary suggested fix and the SM scope both call for resolving + creating the target (the bonus even asks setup to pre-create it). Auto-create is the stronger, more useful contract and makes the disjunction in AC1 deterministic for Dev. Covering both branches would require Dev to pick one anyway; pinning the recommended one avoids an ambiguous GREEN.
  - Severity: minor
  - Forward impact: If Dev deliberately chooses the actionable-error path instead, these tests would need revising — Dev should raise it as a deviation before diverging.

## Design Deviations

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **AC1 narrowed to the auto-create-success branch (not the "actionable error" alternative)**
  - Spec source: context-story-158-1.md, AC1
  - Spec text: "`pf agent start <agent>` succeeds (or fails with a clear, actionable message — no raw traceback) when `.session` is a dangling symlink"
  - Implementation: Tests assert `register_session` *succeeds* and auto-creates the resolved target; they do not cover the alternative "fail with a clear actionable message" path.
  - Rationale: The issue's primary suggested fix and the SM scope both call for resolving + creating the target (the bonus even asks setup to pre-create it). Auto-create is the stronger, more useful contract and makes the disjunction in AC1 deterministic for Dev. Covering both branches would require Dev to pick one anyway; pinning the recommended one avoids an ambiguous GREEN.
  - Severity: minor
  - Forward impact: If Dev deliberately chooses the actionable-error path instead, these tests would need revising — Dev should raise it as a deviation before diverging.

### Dev (implementation)
- No deviations from spec. Implemented TEA's recommended auto-create-success fix exactly; the AC1 narrowing logged by TEA was adopted as-is (auto-create, not the actionable-error branch).

### Reviewer (audit)
- **TEA's AC1 narrowing (auto-create-success, not actionable-error)** → ✓ ACCEPTED by Reviewer: the auto-create branch is the issue's primary suggested fix and the stronger contract; pinning it removed AC1's ambiguity and produced a deterministic GREEN. Sound.
- **Dev's "no bootstrap of `sprint/.session/`" choice** → ✓ ACCEPTED by Reviewer: bootstrap was explicitly out of scope per SM, and resolving at point-of-use is strictly more robust than a one-time bootstrap. Agrees with author reasoning.
- No undocumented spec deviations found. The implementation matches the ACs and the tests TEA wrote; nothing diverged silently.