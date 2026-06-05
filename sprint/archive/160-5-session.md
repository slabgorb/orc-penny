---
story_id: "160-5"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 160-5: sprint new/update --dry-run doesn't exercise the write path — false-positive masks failures; make dry-run reach or assert the write (from 156-5/156-4)

## Story Details
- **ID:** 160-5
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 2
- **Type:** bug
- **Priority:** p2
- **Repo:** pennyfarthing (gitflow)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-05T06:24:23Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-05 | 2026-06-05T06:05:00Z | 6h 5m |
| red | 2026-06-05T06:05:00Z | 2026-06-05T06:11:57Z | 6m 57s |
| green | 2026-06-05T06:11:57Z | 2026-06-05T06:16:22Z | 4m 25s |
| review | 2026-06-05T06:16:22Z | 2026-06-05T06:24:23Z | 8m 1s |
| finish | 2026-06-05T06:24:23Z | - | - |

## Technical Context

### Problem
The `pf sprint new` and `pf sprint update` commands support a `--dry-run` flag that should preview changes without writing them to disk. However, the current implementation short-circuits the write path entirely before executing validation and serialization checks. This creates a false-positive: a dry-run reports success even when the actual write would fail due to schema/validation/serialization errors.

For example:
- User runs `pf sprint new --dry-run` with invalid payload
- Dry-run returns success (write path never executed)
- User runs same command without `--dry-run`
- Actual write fails (validation error)

This masks real failures and prevents early feedback.

### Root Cause
Dry-run branches early in the sprint new/update command handlers (likely in `pennyfarthing-dist/src/pf/sprint/`), returning success without:
1. Building the full payload
2. Running validation checks
3. Running serialization logic
4. Testing the write would succeed

### Acceptance Criteria
1. **Write-path coverage:** Dry-run exercises/validates the same write path used by the real write operation (same validation/serialization code)
2. **Error parity:** A payload that would fail the real write also fails dry-run with the same error message
3. **No persistence:** Dry-run still does NOT persist changes to disk (all write operations are discarded after validation)
4. **Test coverage:** Both `pf sprint new --dry-run` and `pf sprint update --dry-run` are tested, with test cases that verify error propagation

### Implementation Approach
1. Refactor the sprint new/update handlers to extract the write logic into a testable operation
2. Create a `validate_write` or `prepare_write` function that:
   - Builds the complete payload from command arguments
   - Runs all schema validation and serialization checks
   - Returns the validated payload WITHOUT writing it
3. Both dry-run and real-run should call this function; real-run continues to persist while dry-run stops after validation
4. Alternatively, implement dry-run using a transactional or in-memory approach where the write is attempted but rolled back

### Related Stories
- 156-5: Sprint context discovery (parent issue)
- 156-4: Sprint context discovery (sibling)

## SM Assessment

Setup complete and routed to TEA for the RED phase. This is a 2pt `tdd` bug in the `pennyfarthing` repo (gitflow — branch `feat/160-5-dry-run-write-path` off `develop`).

**What TEA needs to know:**
- The bug is a *false-negative-masking* defect: `--dry-run` on `pf sprint new`/`update` returns success without exercising the write path, so invalid payloads pass dry-run then fail the real run.
- Tests must prove **error parity** (AC2): construct a payload that fails the real write, assert the same failure occurs under `--dry-run`. This is the heart of the story — a passing dry-run on a payload that would fail for real is the bug.
- Tests must also prove **no persistence** (AC3): after a dry-run, on-disk sprint YAML/shards are unchanged. Guard against an over-correction where making dry-run "reach the write" accidentally writes.
- Cover **both** commands (`new` and `update`) per AC4.
- Source likely under `pennyfarthing-dist/src/pf/sprint/` where the dry-run branch short-circuits. TEA should locate the early-return and write tests against the public command surface, not internal helpers, so the implementation is free to refactor (extract `prepare_write` vs. transactional rollback — Dev's call).

No Jira (kanban/Jira-less — expected). No blockers. Branch verified on develop.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Two CLI commands silently mask write-path failures in `--dry-run`; behavior is testable and was the masking agent for a prior prod bug (156-5).

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_5_dry_run_write_path.py` (new) — 5 tests

**Tests Written:** 5 tests covering 4 ACs (3 RED parity, 2 green-guard no-persist)
**Status:** RED confirmed (scoped run: `3 failed, 2 passed`)

### The defect (for Dev)
- `new_sprint` (sprint/cli.py:2222-2227): `if dry_run: echo(...); return` short-circuits BEFORE building the payload, BEFORE validation, BEFORE `write_sprint`. Nothing about the would-be write is checked. This is the exact path that masked the 156-5 `FileNotFoundError`.
- `update_story` (sprint/story_update.py:175): validates the mutated doc, then `if dry_run: return {success: True}` — but `write_sprint` (line 182: serialization, shard-split, atomic replace, the 156-5 mkdir self-heal) is never exercised. So an IO/serialization failure still slips past dry-run.

### Test design (error-parity is the core)
Each RED test forces the documented write function (`write_sprint`) to fail — the same monkeypatch-the-write pattern 156-5's own suite used (`test_ac3_tmp_cleaned_on_write_failure` patched `os.replace`). It first asserts the REAL run fails (control — non-vacuous), then asserts dry-run surfaces the failure too. Today dry-run returns success/exit-0 → RED.

| Test | AC | State | Surface |
|------|----|----|---------|
| `test_new_dry_run_surfaces_write_failure_like_real_run` | AC1/AC2 | RED | CLI (`new_sprint` via CliRunner) |
| `test_new_dry_run_does_not_persist` | AC3 | green-guard | CLI |
| `test_update_dry_run_surfaces_write_failure_like_real_run` | AC1/AC2 | RED | fn (`update_story`) |
| `test_update_dry_run_via_cli_surfaces_write_failure` | AC1/AC2 | RED | CLI (`story_update_command`) |
| `test_update_dry_run_does_not_persist` | AC3 | green-guard | fn |

### Rule Coverage
| Rule (SOUL/lang-review) | Test(s) | Status |
|------|---------|--------|
| #10 return-results (don't throw) | parity tests accept raise OR `success:False`, not coupling to one | n/a-pass |
| Test quality (meaningful assertions) | every test asserts exit_code/`success`/on-disk state on both legs; no vacuous asserts | self-checked |
| #1 fix-the-system (mask source, not symptom) | parity drives dry-run through the *same* write path, not a parallel re-validate | RED |

**Rules checked:** 3 applicable. **Self-check:** 0 vacuous tests found.

### Dev guidance (GREEN)
Route `--dry-run` through the SAME write/serialization path the real run uses (call `write_sprint` into a throwaway location, or factor a shared `prepare_write`/validate both call) so a real write failure surfaces in dry-run — while NOT persisting to the live sprint file (AC3 guards enforce this). Do NOT "fix" by making dry-run merely re-validate the schema: `new`'s failure mode is serialization/IO, which schema validation alone won't catch (that's precisely why the no-persist guards pass today and the parity tests still RED).

**Handoff:** To Dev (Ponder Stibbons) for implementation.

## Dev Assessment

**Status:** GREEN — all 5 tests pass (`5 passed in 0.22s`, scoped run).

### Implementation
Both commands now route `--dry-run` through the **real** `write_sprint`, targeting a `tempfile.TemporaryDirectory()` instead of the live sprint file. `write_sprint` falls back to a single-file `_write_yaml_file` when the temp path isn't sharded-on-disk (`_is_sharded_on_disk` → False for a fresh path), so canonicalization + atomic temp-write + `os.replace` (the exact 156-5 failure surface) are exercised with zero side effects on the real `sprint/` dir.

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/sprint/cli.py` (`new_sprint`) | Moved `sprint_data` construction above the dry-run branch; dry-run now `write_sprint(tmp/"current-sprint.yaml", sprint_data)` before echoing, then returns. |
| `pennyfarthing-dist/src/pf/sprint/story_update.py` (`update_story`) | Dry-run now `write_sprint(tmp/"current-sprint.yaml", data)` before the `{success, dry_run}` return. |

### Why this approach (minimalism)
Chose the throwaway-temp-write over the spec's suggested `prepare_write`/transactional refactor (Implementation Approach #1-3). The temp-write reuses the existing `write_sprint` verbatim — no new function, no new abstraction, no change to the real write path — and satisfies AC1 (same serialization code), AC2 (a forced `write_sprint` failure now surfaces in dry-run), and AC3 (nothing touches the live file; the TemporaryDirectory is auto-removed). A shared `prepare_write` extraction would be larger surface area for no behavioral gain the tests require.

### Verification
- Target tests: `test_160_5_dry_run_write_path.py` → 5 passed (3 ex-RED parity now green, 2 no-persist guards still green).
- Regression: `test_156_5_sprint_new_mkdir.py`, `test_story_update.py`, `test_156_1_story_update_shards.py`, `test_sprint_package.py`, `test_cli_modules.py`, `test_epic_shard_validation.py` → 143 passed, 2 skipped, 0 failures.
- `ruff check` on all 3 changed files: clean.
- Commit `4cd21b9f6` (signed), pushed to `origin/feat/160-5-dry-run-write-path`.

**On TEA's Delivery Finding** (unwrapped `write_sprint` in `update_story`): left as-is. The parity contract is "dry-run behaves like the real run"; the real run currently raises on write failure, so dry-run raising too is correct parity. Wrapping only the dry-run leg in try/except would *break* parity (dry-run would mask what the real run surfaces). A `{success: False}` refactor would need to cover the real `write_sprint(sprint_path, data)` call too — out of scope for this bug. Deferred, not dismissed.

**Handoff:** To Reviewer (Granny Weatherwax) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 | n/a — 55 tests pass, ruff clean, 0 smells |
| 2 | reviewer-edge-hunter | Yes | findings | 3 actionable (2 high, 1 med) + low | confirmed 2 (sharding gap, contract-throw), dismissed 1 (interactive-dry-run — pre-existing, verified vs develop) |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 1 med + 2 pre-existing low | confirmed 1 (sharding gap, dup of edge), deferred 2 (yaml_io pre-existing, out of diff) |
| 4 | reviewer-test-analyzer | Yes | findings | 1 high, 1 med, 1 low | confirmed 3 (sharded coverage, OR-fragility, corrupt-read) — all non-blocking |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | clean | 0 | n/a — temp dir context-managed, no pickle/eval/injection surface |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (5 enabled returned, 4 disabled pre-filled)
**Total findings:** 3 confirmed non-blocking (sharding gap, contract-throw, test fragility), 1 dismissed (interactive-dry-run false alarm), 2 deferred (pre-existing yaml_io, out of diff)

## Reviewer Assessment

**Verdict:** APPROVED (with non-blocking follow-up findings)

**Data flow traced:** CLI args (`sprint_yyww`, `jira_id`, dates, `goal` for `new`; `--status` etc. for `update`) → in-memory dict/CommentedMap → `write_sprint(Path(tempfile.TemporaryDirectory())/"current-sprint.yaml", data)` → `_canonicalize` + `_write_yaml_file` (atomic temp-write + `os.replace`) → discarded with the TemporaryDirectory. Safe: the live `sprint/` tree is never the write target in dry-run; the only persisted-write path (`write_sprint(sprint_file/sprint_path, ...)`) remains behind `if not dry_run`.

### Observations
- `[VERIFIED]` Monkeypatch sites correct — evidence: `new_sprint` does a call-time `from pf.sprint.yaml_io import write_sprint` (cli.py:2223) and the test patches `yaml_io.write_sprint`; `update_story` binds module-level (story_update.py:21) and the test patches `story_update_mod.write_sprint`. Both resolve to the patched `_explode`, so the RED→GREEN transition is real, not a false-green. Confirmed independently by `[TEST]` and `[EDGE]`.
- `[VERIFIED]` No-persist holds — evidence: dry-run writes only inside `tempfile.TemporaryDirectory()` (cli.py:2245, story_update.py:180); `test_new_dry_run_does_not_persist` and `test_update_dry_run_does_not_persist` assert the live file is absent / byte-identical + re-read. Complies with AC3.
- `[VERIFIED]` Error parity is real and unswallowed — evidence: neither dry-run `write_sprint` call is wrapped in try/except, so a write failure propagates exactly as the real run’s would. `[SILENT]` confirms no swallow.
- `[VERIFIED][SEC]` No new attack surface — evidence: `tempfile.TemporaryDirectory()` is context-managed (no `delete=False`, OS-generated path, cleanup on exception); `Path(_td) / "current-sprint.yaml"` uses path-join not string concat; no pickle/eval/unsafe-yaml/subprocess introduced.
- `[MEDIUM][EDGE][SILENT][TEST]` **Sharded write branch not exercised by dry-run** at story_update.py:180 — `write_sprint` branches on `_is_sharded_on_disk(path)`; the fresh temp path is never sharded, so dry-run always takes the single-file `_write_yaml_file` branch. A real `update` on a production (sharded) sprint takes the sharded branch (`_get_epic_ref`, per-shard write, stale-unlink). Downgraded from the subagents’ "high confidence" to MEDIUM severity on impact: the un-exercised logic is shard *bookkeeping*, not content serialization (every epic/story IS canonicalized in the single-file write); and the realistic shard-only failures are either impossible on an update (refs already valid in existing data) or inherently uncatchable by any temp-write (real-dir IO failures occur on a different path than the tempdir). Recorded as a non-blocking Improvement.
- `[MEDIUM][EDGE]` **Dry-run `write_sprint` failure violates `update_story`’s `{success,error}` contract** at story_update.py:180 — propagates as an uncaught exception (SOUL #10), surfacing as a raw traceback at the CLI rather than a `ClickException`. Pre-existing on the real path (line 189) too; the dry-run branch newly adds an unguarded throw. Non-blocking; recorded for follow-up.
- `[LOW][TEST]` Parity tests’ `real_failed = raised or (result.get("success") is not True)` disjunction would print a misleading "real must fail" message if a future refactor made `update_story` return `None`. Test-hardening nicety, non-blocking.
- `[LOW][TEST]` No negative test for a corrupt/unreadable sprint file (read-path error before the write branch). Optional coverage.

### Rule Compliance (lang-review/python.md)
Enumerated every changed `.py` construct against the 13-check Python checklist:
- **#1 silent exceptions:** No bare/`pass` excepts in the diff. The dry-run `write_sprint` calls are intentionally unguarded (error parity). ✓ (see MEDIUM contract note — a *design* tension, not a #1 violation)
- **#2 mutable defaults:** None added. ✓
- **#3 type annotations at boundaries:** No signatures changed; `new_sprint`/`update_story` annotations unchanged. ✓
- **#4 logging:** Modules use `click.echo`, not `logging`; no sensitive data echoed. ✓
- **#5 path handling:** `Path(_td) / "current-sprint.yaml"` — pathlib, no string concat, no hardcoded sep. `_td` is OS temp, not user input → no resolve()-before-check needed. ✓
- **#6 test quality:** No `assert True`/vacuous asserts; every test asserts exit_code/`success`/on-disk state; mock targets correct (verified). One LOW disjunction-fragility note. ✓ (with note)
- **#7 resource leaks:** `tempfile.TemporaryDirectory()` as context manager in both sites — cleanup guaranteed; no `delete=False`. ✓
- **#8 unsafe deserialization:** None introduced; `write_sprint` uses ruamel round-trip, no pickle/eval. ✓ (`[SEC]` confirms)
- **#9 async:** N/A (sync). #10 imports: local `from pathlib import Path`/`import tempfile` — no star/circular. ✓
- **#11 input validation:** CLI scalars flow into YAML values only — no injection sink. ✓ #12 deps: none changed. ✓ #13 fix-regressions: re-scanned; no new bug class introduced. ✓

### Devil's Advocate
Argue the code is broken. The strongest case: a user trusts `pf sprint story update X --status done --dry-run` on a real production sprint, which is **sharded** (epics as string refs across `epic-*.yaml`). Dry-run prints "[DRY-RUN] Would update story X" and exits 0 — but it only serialized the merged document to a throwaway single file; it never ran the sharded write branch the real command will use. So the user’s "green dry-run" is, for the production layout, a partial validation — precisely the false-confidence this story exists to eliminate. A confused user reads "dry-run exercises the write path now" (the commit message) and over-trusts it. A stressed filesystem makes it worse: the dry-run writes to `$TMPDIR`, so a sprint dir that is read-only, full, or on a failing volume passes dry-run and fails for real — the temp-write fundamentally cannot observe the real target’s health, in *either* branch. Second angle: the dry-run now performs real I/O (temp file create+write+replace) where before it was pure echo; under a restrictive `TMPDIR` (sandbox, `noexec`/quota), dry-run could now *fail where the real run would succeed* — a false-negative inversion. Third: `update_story`’s dry-run throw breaks its result-dict contract, so a caller doing `result = update_story(...); if result["success"]` gets a traceback instead. **What this surfaces:** the temp-write strategy validates *payload serialization*, not *target-environment writability*, and skips shard plumbing. That is a real boundary worth stating — but on impact it is incompleteness, not breakage: content serialization is fully exercised, the realistic shard-only failures don’t arise on an update, no regression is introduced, and all written ACs pass. Hence MEDIUM/non-blocking, recorded loudly so it’s not mistaken for full coverage.

**Pattern observed:** Minimal, faithful reuse of the existing `write_sprint` (no new abstraction) at cli.py:2239-2251 and story_update.py:175-187 — good SOUL #13 restraint.
**Error handling:** Intentionally unguarded for parity; one MEDIUM contract tension noted.
**Handoff:** To SM for finish-story.

## Delivery Findings

### TEA (test design)
- **Improvement** (non-blocking): `update_story` calls `write_sprint` (story_update.py:182) with no try/except, so a write failure propagates as an unhandled exception rather than a `{success: False}` result — a minor SOUL #10 (return-results) violation. The parity tests tolerate either outcome so Dev isn't forced to change this, but wrapping it would be the cleaner GREEN. Affects `pennyfarthing-dist/src/pf/sprint/story_update.py`. *Found by TEA during test design.*
- No other upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)
- **Improvement** (non-blocking): dry-run never exercises `write_sprint`'s **sharded** branch — the throwaway temp path is never sharded-on-disk, so a real `update` on a production sharded sprint validates only the single-file write branch. Realistic shard-only failures are either impossible on an update (refs already valid) or uncatchable by any temp-write (real-dir IO), so impact is low — but a follow-up could seed the tempdir with the on-disk sharding state (copy index + shards) so the same branch is exercised, plus a sharded-sprint parity/no-persist test. Affects `pennyfarthing-dist/src/pf/sprint/{cli.py,story_update.py}` and `test_160_5_dry_run_write_path.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the dry-run `write_sprint` call in `update_story` throws on failure, violating the function's `{success, error}` return-dict contract (SOUL #10) and surfacing a raw traceback at the CLI instead of a `ClickException`. The real-write path (story_update.py:189) has the same pre-existing gap. A future story could wrap both in try/except returning `{success: False, error: str(exc)}`. Affects `pennyfarthing-dist/src/pf/sprint/story_update.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): parity-test control assertions use a `raised or success-is-not-True` disjunction that would emit a misleading message if `update_story` were refactored to return `None`; prefer `pytest.raises` / explicit dict-shape checks. Affects `pennyfarthing-dist/src/pf/tests/test_160_5_dry_run_write_path.py`. *Found by Reviewer during code review.*
- **Note** (non-blocking, pre-existing, out of diff): `yaml_io.py:408` (`except Exception: pass` on stale-shard cleanup) and `yaml_io.py:365` (`_is_sharded_on_disk` swallowing read errors → silently treats corrupt index as non-sharded) are pre-existing silent failures surfaced by `[SILENT]`. Not introduced here; candidates for a hardening story. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

2 deviations

- **AC1 ("same write path") expressed via forced write failure rather than a literal schema-validation assertion**
  - Rationale: `new_sprint` builds its own always-valid `sprint_data` from CLI args, so no schema-invalid payload is reachable through the public CLI surface; the real failure mode (156-5) is serialization/IO. A forced write-path failure is the faithful, reachable expression of "same write path". A schema-only test would be green-on-arrival for `update` and unreachable for `new`.
  - Severity: minor
  - Forward impact: Dev must make dry-run exercise the real write/serialization path (not a parallel re-validate) or the parity tests stay RED — this is intended.
- **Used throwaway-temp-write instead of the spec's `prepare_write`/transactional extraction**
  - Rationale: SOUL #13/minimalism — the temp-write reuses the real serialization code verbatim and satisfies AC1/AC2/AC3 with no new abstraction. The session also lists this transactional approach as the explicit alternative (#4: "the write is attempted but rolled back"), so this is within spec authority.
  - Severity: minor
  - Forward impact: none — `write_sprint` signature and the real write path are unchanged; a future `prepare_write` refactor (if ever needed) is unblocked.

## Design Deviations

### TEA (test design)
- **AC1 ("same write path") expressed via forced write failure rather than a literal schema-validation assertion**
  - Spec source: context-story-160-5.md / session ACs, AC1
  - Spec text: "Dry-run exercises/validates the same write path used by the real write operation (same validation/serialization code)"
  - Implementation: AC1 is driven jointly with AC2 by monkeypatching the documented write function (`write_sprint`) to fail and asserting dry-run surfaces it — not by a standalone "dry-run runs schema validation" assertion.
  - Rationale: `new_sprint` builds its own always-valid `sprint_data` from CLI args, so no schema-invalid payload is reachable through the public CLI surface; the real failure mode (156-5) is serialization/IO. A forced write-path failure is the faithful, reachable expression of "same write path". A schema-only test would be green-on-arrival for `update` and unreachable for `new`.
  - Severity: minor
  - Forward impact: Dev must make dry-run exercise the real write/serialization path (not a parallel re-validate) or the parity tests stay RED — this is intended.

### Dev (implementation)
- **Used throwaway-temp-write instead of the spec's `prepare_write`/transactional extraction**
  - Spec source: context-story-160-5.md / session ACs, Implementation Approach #1-3
  - Spec text: "Refactor the sprint new/update handlers to extract the write logic ... Create a `validate_write` or `prepare_write` function ... Both dry-run and real-run should call this function"
  - Implementation: Dry-run calls the existing `write_sprint` against a `tempfile.TemporaryDirectory()`; no new function extracted, real write path untouched.
  - Rationale: SOUL #13/minimalism — the temp-write reuses the real serialization code verbatim and satisfies AC1/AC2/AC3 with no new abstraction. The session also lists this transactional approach as the explicit alternative (#4: "the write is attempted but rolled back"), so this is within spec authority.
  - Severity: minor
  - Forward impact: none — `write_sprint` signature and the real write path are unchanged; a future `prepare_write` refactor (if ever needed) is unblocked.

### Reviewer (audit)
- **TEA deviation (AC1 via forced write failure)** → ✓ ACCEPTED by Reviewer: sound. `new_sprint` constructs its own valid payload from typed CLI args, so a schema-invalid input is genuinely unreachable through the public surface; forcing the documented write function to fail is the faithful, reachable expression of "same write path." Agrees with author reasoning.
- **Dev deviation (throwaway-temp-write instead of `prepare_write` extraction)** → ✓ ACCEPTED by Reviewer: within spec authority — the session's own Implementation Approach #4 names the transactional/throwaway alternative, and SOUL #13 favors reusing `write_sprint` verbatim over a new abstraction. Caveat recorded as a non-blocking finding: the temp-write validates payload serialization, not the sharded branch or real-target writability (see Reviewer code-review findings). Accepted for this 2pt fix; gap tracked for follow-up.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->