---
story_id: "153-11"
jira_key: ""
epic: "153"
workflow: "tdd"
---
# Story 153-11: pf doctor doesn't verify the project-local .pennyfarthing/bin/pf shim — stays green while every 'just pf' recipe and the statusline hook are broken

## Story Details
- **ID:** 153-11
- **Jira Key:** N/A (local-only sprint)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-10T16:37:36Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-10T16:28:35Z | 2026-06-10T16:29:52Z | 1m 17s |
| red | 2026-06-10T16:29:52Z | 2026-06-10T16:32:16Z | 2m 24s |
| green | 2026-06-10T16:32:16Z | 2026-06-10T16:35:01Z | 2m 45s |
| review | 2026-06-10T16:35:01Z | 2026-06-10T16:37:36Z | 2m 35s |
| finish | 2026-06-10T16:37:36Z | - | - |

## Sm Assessment

**Setup complete; routing to TEA for red phase.**

- Session file created with workflow `tdd` (phased); story context at `sprint/context/context-story-153-11.md`.
- Feature branch `feat/153-11-doctor-project-shim-check` created off `develop` in `pennyfarthing/` and checked out.
- Jira intentionally skipped — local-only sprint, no Jira key for this story.
- Scope: add a `project_shim` check to `pf doctor` verifying `.pennyfarthing/bin/pf` exists, is executable, and execs (`pf --version` through the shim); failure must be non-green with remediation pointing at `pf init`. Regression tests must cover missing, present-but-not-executable, and present-and-working states.
- Mode: peloton-inline — SM drives TEA → Dev → Reviewer as subagents (Opus); SM owns PR create/merge and finish ceremony.

## Tea Assessment

**Tests Required:** Yes
**Status:** RED (failing — ready for Dev)

**Test file:** `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_doctor_project_shim.py` (18 tests)

### Designed interface (implement against this exactly)

New check function in `pf/doctor/checks.py`:

```python
def check_project_shim(root: Path) -> CheckResult:
    """Verify .pennyfarthing/bin/pf exists, is executable, and execs `pf --version`."""
```

- **Check id / `CheckResult.name`:** `"project_shim"`
- **Return type:** `CheckResult` (existing dataclass: `name`, `status`, `detail`, `fix_fn`)
- **status values:** `"pass"` (working) or `"fail"` (missing / not-executable / non-zero exec). No `"warn"`.
- **Shim path:** `root / ".pennyfarthing" / "bin" / "pf"`
- **Pass condition (ALL must hold):**
  1. shim file exists
  2. executable bit set (`os.access(shim, os.X_OK)` or `mode & stat.S_IXUSR`)
  3. `subprocess.run([str(shim), "--version"])` returns exit code 0
- **Fail condition:** any of the above fails → `status="fail"`, with `detail` containing the literal substring `pf init` as remediation. (Tests assert `"pf init" in result.detail` on every failure path.)
- **Pass `detail`:** must NOT contain `pf init` (test asserts no nag on success).
- **Must not crash** when `.pennyfarthing/` is entirely absent — return fail with `pf init` remediation.

### Wiring (two registry edits)

1. `pf/doctor/checks.py` — add `("project_shim", "<description>")` to the `CHECKS` list (description must be a non-empty string).
2. `pf/doctor/core.py` — add `"project_shim": check_project_shim` to `_CHECK_FNS` and add `check_project_shim` to the import from `pf.doctor.checks`. `run_doctor` iterates `CHECKS` and looks up `_CHECK_FNS[name]`, so both edits are required or it KeyErrors.

### Implementation notes for Dev

- The shim is written by `write_shim` (`pf/common/discovery.py:176`) at `0o755`; gitignored (`.gitignore:51`), so missing after `git clean` / fresh clone — that is the failure the check must catch.
- A `fix_fn` is **optional** for this story (no AC requires `--fix` to regenerate the shim; remediation text pointing at `pf init` satisfies AC2). If added, it would call init's shim writer — but tests do not require it. Keep scope minimal.
- Verify with a targeted run only: `python3 -m pytest pennyfarthing-dist/src/pf/tests/test_doctor_project_shim.py -q`. Do NOT run the full suite (`test_git_utils.py` leaks a branch checkout onto the live repo).

**RED verification:** All tests fail at collection with `ImportError: cannot import name 'check_project_shim'` — failing for the right reason (function unimplemented).

**Handoff:** To Dev for GREEN implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/doctor/checks.py` — added `check_project_shim(root)`, `subprocess` import, and `("project_shim", ...)` registry entry
- `pennyfarthing/pennyfarthing-dist/src/pf/doctor/core.py` — imported `check_project_shim` and wired it into `_CHECK_FNS`
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_doctor.py` — added working shim to `healthy_project` fixture; bumped check-count bound 13→14 (see Design Deviations)

**Tests:** 66/66 passing (GREEN) — 18 new `test_doctor_project_shim.py` + 48 existing `test_doctor.py`. Targeted run only (full suite skipped per `test_git_utils.py` branch-leak warning).
**Ruff:** clean on all changed files.
**Branch:** feat/153-11-doctor-project-shim-check (committed; NOT pushed — peloton-inline, SM owns PR)

**Handoff:** To Reviewer.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Gap** (non-blocking): TEA's `healthy_project` fixture in `test_doctor.py` predates this check and lacked a project shim, so the new check exposed that "healthy" was under-specified. Fixed in this story by adding a working shim to the fixture. Affects `pennyfarthing-dist/src/pf/tests/test_doctor.py` (future fixtures representing a healthy project must include `.pennyfarthing/bin/pf`). *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): A dangling shim symlink (target deleted) fails correctly via `Path.is_file()` returning False, but the detail reports "missing" rather than "broken symlink". Cosmetic; remediation (`pf init`) is still correct. Affects `pennyfarthing-dist/src/pf/doctor/checks.py` (`check_project_shim` could distinguish `shim.is_symlink() and not shim.exists()` for a clearer message). *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 1 findings (1 Gap, 0 Conflict, 0 Question, 0 Improvement)
**Blocking:** None

- **Gap:** TEA's `healthy_project` fixture in `test_doctor.py` predates this check and lacked a project shim, so the new check exposed that "healthy" was under-specified. Fixed in this story by adding a working shim to the fixture. Affects `pennyfarthing-dist/src/pf/tests/test_doctor.py`.

### Downstream Effects

- **`pennyfarthing-dist/src/pf/tests`** — 1 finding

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **subprocess timeout added:** Spec left the shim-exec timeout to Dev's discretion ("if tests allow"). Implemented `subprocess.run([shim, "--version"], timeout=10)` so a hung shim can't hang doctor; `subprocess.SubprocessError` (incl. `TimeoutExpired`) is caught and mapped to a `fail` with `pf init` remediation. Tests still pass.
- **Edited existing `test_doctor.py` (not in TEA's interface):** Adding the 14th check broke two pre-existing tests because the `healthy_project` fixture had no `.pennyfarthing/bin/pf` shim, and `test_checks_count_approximately_10` capped at 13. A truly healthy project HAS a working shim, so I added one to the fixture (mirroring TEA's working-shim body) and bumped the soft count bound 13→14. This satisfies AC3 (idempotent with existing output) — without it, doctor would never report green on a real healthy project. No production-code behavior changed by these test edits.

### Reviewer (audit)
- **subprocess timeout added** → ✓ ACCEPTED by Reviewer: SM-sanctioned and defensively correct. A hung shim hanging `pf doctor` indefinitely would be a worse failure mode than the bug being fixed. `subprocess.SubprocessError` is the parent of `TimeoutExpired`, so the existing `except (OSError, subprocess.SubprocessError)` already catches the timeout and maps it to a `fail` with `pf init` remediation — verified at checks.py:319.
- **Edited existing `test_doctor.py`** → ✓ ACCEPTED by Reviewer: The fixture edit is the correct fix, not a test-bending workaround. The old `healthy_project` fixture modeled an under-specified "healthy" state (no shim). The new 14th check correctly exposed that gap; a real healthy project DOES carry `.pennyfarthing/bin/pf`. The soft-bound bump 13→14 mirrors the genuine registry growth. No production code was altered to make a test pass. Verified test_doctor.py:69-75 (fixture shim) and :166-167 (bound).
- No undocumented deviations found. The implementation matches TEA's designed interface exactly (name `project_shim`, `CheckResult` return, pass/fail only, shim path, `pf init` remediation substring on every fail path, no-crash on absent `.pennyfarthing/`).

## Subagent Results

Peloton-inline mode: specialist subagents not spawned (SM drives roles directly). Reviewer performed all specialist-domain analysis inline against the diff. Rows reflect inline coverage of each domain.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Inline | clean | 66/66 tests pass, ruff clean | N/A |
| 2 | reviewer-edge-hunter | Inline | clean | all 4 fail paths + pass path enumerated | N/A |
| 3 | reviewer-silent-failure-hunter | Inline | clean | no swallowed errors; exec failure → explicit fail | N/A |
| 4 | reviewer-test-analyzer | Inline | clean | 4 AC states covered, no vacuous asserts | N/A |
| 5 | reviewer-comment-analyzer | Inline | clean | docstring accurate, no stale comments | N/A |
| 6 | reviewer-type-design | Inline | clean | returns `CheckResult`, no stringly-typed leaks | N/A |
| 7 | reviewer-security | Inline | clean | exec-from-tree assessed, threat-model-inapplicable | N/A |
| 8 | reviewer-simplifier | Inline | clean | minimal; no dead code or over-engineering | N/A |
| 9 | reviewer-rule-checker | Inline | clean | SOUL #10 return-results honored | N/A |

**All received:** Yes (inline coverage — peloton-inline mode, no separate subagent dispatch)
**Total findings:** 0 confirmed blocking, 0 dismissed, 1 deferred (non-blocking Delivery Finding below)

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `root` (project dir) → `check_project_shim` builds `root/.pennyfarthing/bin/pf` → `is_file()` / `os.access(X_OK)` / `subprocess.run([shim, "--version"], capture_output=True, timeout=10)` → `CheckResult(status=fail|pass)` → `run_doctor` aggregates → `report.success = all(c.status != "fail")` (core.py:70). A missing/non-exec/non-zero/hung shim now flips `report.success` to False (verified: `test_run_doctor_fails_overall_when_shim_missing`). Safe because the exec'd file is the user's own shim (same one every `just pf` invokes), `capture_output=True` keeps its output out of the report, and `timeout=10` bounds the call.

**Pattern observed:** Clean four-gate guard with early returns (missing → not-executable → exec-error → non-zero), each fail carrying the `pf init` remediation substring. Mirrors the existing `check_repos_topology` style (checks.py:289-335). `[SIMPLE]` minimal, no `fix_fn` added (correctly out of scope per TEA notes).

**Error handling:** `except (OSError, subprocess.SubprocessError)` (checks.py:319) catches exec failure, permission error, and `TimeoutExpired` (subclass of SubprocessError) → explicit `fail` with remediation. `[SILENT]` no swallowed errors — every failure path returns a visible `fail`. No-crash on absent `.pennyfarthing/` verified (`test_missing_shim_when_no_pennyfarthing_dir`).

**Security analysis:** `[SEC]` The check execs a file from the project tree. Threat model: single-user local dev tool, doctor run by the repo owner, shim authored by their own `pf init` from local binary discovery — it is the exact file already exec'd on every `just pf` recipe and the statusline hook. No privilege boundary, no untrusted input, no new attack surface. `--version` is a benign read-only probe (write_shim generates `exec "$path" "$@"`, discovery.py:185). Acceptable.

**Observations (5+):**
- `[VERIFIED]` AC1 (exists + executable + execs `pf --version`): checks.py:301/307/314 — all three gates present, `--version` matches the real shim contract (discovery.py).
- `[VERIFIED]` AC2 (missing/broken/stale → FAIL with `pf init`): every fail branch embeds `remediation = "run \`pf init\` to regenerate it"` (checks.py:299); tests assert `"pf init" in result.detail` on all four fail paths.
- `[VERIFIED]` AC3 (passing + idempotent): pass `detail` omits `pf init` (test_working_shim_no_init_remediation); `run_doctor` includes `project_shim` without dragging down a healthy project (test_run_doctor_green_shim_does_not_drag_down_success); fixture updated so `healthy_project` stays green.
- `[VERIFIED]` AC4 (regression tests: missing / not-executable / working): all three fixtures present plus a broken-non-zero case — `test_doctor_project_shim.py` 18 tests, registry+wiring tests included.
- `[VERIFIED]` Wiring: `check_project_shim` imported and registered in `_CHECK_FNS` (core.py:19,44) AND in `CHECKS` (checks.py:378) — both required or `run_doctor` KeyErrors. test_project_shim_wired_into_check_fns confirms identity.
- `[VERIFIED]` Diff base clean: `merge-base origin/develop HEAD == origin/develop`; diff scoped to exactly 4 expected files, no stale churn.

**Deferred (non-blocking):** A symlinked shim whose target is missing — `Path.is_file()` follows symlinks and returns False, so it correctly fails, but the detail says "missing" rather than "broken symlink". Cosmetic only; the remediation (`pf init`) is still correct. Captured as a Delivery Finding, not a blocker for a 2-point bugfix.

**Handoff:** To SM (Stilgar) for finish-story.