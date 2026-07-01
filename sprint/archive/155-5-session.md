---
story_id: "155-5"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-5: sm-finish preflight false-blocks: stale repos.yaml language:javascript drives npm lint on Python-only root; 'No PR found' on already-merged PRs

## Story Details
- **ID:** 155-5
- **Jira Key:** (none — internal framework story, Jira skipped)
- **Workflow:** tdd
- **Stack Parent:** none

## Story Context

**Title:** sm-finish preflight false-blocks: stale repos.yaml language:javascript drives npm lint on Python-only root; 'No PR found' on already-merged PRs

**Type:** Bug
**Points:** 2

**Problem:** The `sm-finish` preflight repeatedly false-blocks handoffs at the orchestrator root. Two distinct failure modes:

1. `.pennyfarthing/repos.yaml` (source: `pennyfarthing/pennyfarthing-dist/` — trace the symlink; never edit the symlinked `.pennyfarthing/` copy) declares the orchestrator repo with `language: javascript` and `build_command: npm install` (lines ~20-21). The orchestrator is Python-only (ADR-0034). This drives preflight to run `npm run lint` on a root with no npm lint setup, producing a spurious BLOCK. Correct config: Python (ruff), not javascript/npm.

2. Preflight reports "No PR found" as a blocking condition even when the PR for the story has already been merged. A merged PR should not block finish.

**Technical Approach:**
- Fix source of truth: `pennyfarthing/pennyfarthing-dist/` config for the orchestrator repo language/build/lint (Python/ruff, not javascript/npm). Confirm exact file (repos.yaml template vs generated).
- Preflight PR-state logic: treat an already-merged PR as PASS, not "No PR found" block.
- This is `tdd` workflow: TEA writes failing tests first (RED) reproducing both false-blocks, then Dev makes them pass (GREEN).

**Acceptance Criteria:**
- AC1: Orchestrator repo config declares Python/ruff tooling; preflight no longer runs npm lint on the Python-only root.
- AC2: sm-finish preflight treats an already-merged PR as a passing/non-blocking state (no "No PR found" false-block).
- AC3: Regression tests cover both false-block scenarios.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-01T13:37:30Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-01T12:55:04Z | 2026-07-01T12:55:04Z | 0m |
| red | 2026-07-01T12:55:04Z | 2026-07-01T13:07:34Z | 12m 30s |
| green | 2026-07-01T13:07:34Z | 2026-07-01T13:14:17Z | 6m 43s |
| review | 2026-07-01T13:14:17Z | 2026-07-01T13:24:33Z | 10m 16s |
| green | 2026-07-01T13:24:33Z | 2026-07-01T13:30:19Z | 5m 46s |
| review | 2026-07-01T13:30:19Z | 2026-07-01T13:37:30Z | 7m 11s |
| finish | 2026-07-01T13:37:30Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Conflict** (blocking): AC1 is split across two repos and the story context misdirects on the config location. The lint-tooling CODE fix (`check_lint` must stop hardcoding npm / become language-aware) lives in **this** repo (`pennyfarthing/pennyfarthing-dist/src/pf/preflight/finish.py`). But the repos.yaml CONFIG fix (`language: javascript` → `python`) lives in the **orchestrator** repo at `.pennyfarthing/repos.yaml` — a real, non-symlinked, non-distributed local file. The story context's "trace the symlink to `pennyfarthing-dist/`" is wrong for repos.yaml. Dev cannot fully land AC1 from within the pennyfarthing repo. Affects `.pennyfarthing/repos.yaml` (orchestrator repo — separate commit/PR to `main`). *Found by TEA during test design.*
- **Improvement** (non-blocking): `check_lint` needs language detection; a project-agnostic one already exists at `pennyfarthing-dist/scripts/workflow/check.py` (`detect_project_type`, `run_lint` honoring `repo_config.lint_cmd`). Dev should reuse it rather than write new detection. Affects `pennyfarthing-dist/src/pf/preflight/finish.py` (`check_lint`). *Found by TEA during test design.*
- **Gap** (non-blocking): the real mechanism differs from the story title — `check_lint` never reads repos.yaml at all; it hardcodes `npm run lint` regardless of language. The "stale repos.yaml drives npm lint" framing is inaccurate; the code is simply language-blind. Tests target the actual mechanism (npm hardcoded on a Python root). Affects `pennyfarthing-dist/src/pf/preflight/finish.py`. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): TEA's blocking cross-repo finding is RESOLVED by the chosen fix. `check_lint` now detects the linter from the project layout (package.json→npm, pyproject.toml→ruff, neither→skip-clean), so the orchestrator-root false-block is fixed entirely within this repo. The `.pennyfarthing/repos.yaml` `language: javascript` edit is no longer REQUIRED for the lint false-block, but it remains inaccurate (Python-only per ADR-0034) and may misdirect other consumers (e.g. lang-review checklist selection). Recommend a separate orchestrator-repo edit to `language: python`. Affects `.pennyfarthing/repos.yaml` (orchestrator repo, non-blocking). *Found by Dev during implementation.*
- **Gap** (non-blocking): pre-existing, environment-dependent test failures unrelated to this change — `test_independence.py::TestCli::{test_cli_with_independent_units,test_cli_with_overlapping_units}` fail with `ModuleNotFoundError: No module named 'pf'` because they spawn `sys.executable -m pf.preflight` as a subprocess needing `pf` installed on the bare interpreter. Confirmed to fail identically with this story's change stashed. Affects `pennyfarthing-dist/src/pf/tests/test_independence.py` (make the CLI smoke tests robust to an uninstalled interpreter, or mark them integration). *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (blocking): incomplete fix — `aggregate_results` still hardcodes the lint-failure remediation `fix="Run 'npm run lint' and fix errors"`; on a Python project's `ruff` failure this now emits wrong npm guidance (the same npm-on-Python bug the story fixes, in the recovery text). Affects `pennyfarthing-dist/src/pf/preflight/finish.py:400` (make the message language-aware/generic; pin with a test). *Found by Reviewer during code review.*
- **Gap** (blocking): Bug-1 lint tests are one-sided — proven to pass even when Python linting is silently disabled (`_detect_lint_command`→None), so they don't actually cover AC1/AC3. Affects `pennyfarthing-dist/src/pf/tests/test_155_5_preflight_false_blocks.py:157,172` (add a positive assertion that ruff runs). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): fallback `_lookup_merged_pr_by_branch` masks infra failure — a non-zero `gh pr list` or parse error returns `None` indistinguishably from "no merged PR", with no log. Fails safe (still blocks) but hurts troubleshooting truthfulness. Affects `pennyfarthing-dist/src/pf/preflight/finish.py:166-171`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): CWE-88 — `branch`/`repo` reach `gh` argv unvalidated; a leading-dash value could be misparsed as a gh flag. Weak threat model (locally-controlled branch) but a rule #11 match. Affects `pennyfarthing-dist/src/pf/preflight/finish.py:184,151` (validate git-ref/owner-repo, or add `--`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `LintResult.clean=True` overloads "passed" and "skipped/no lintable project"; `JiraStatus.skipped` is the existing precedent. Add `LintResult.skipped` for truthful preflight reporting (fits the epic). Affects `pennyfarthing-dist/src/pf/preflight/finish.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking, round-2): the neither-manifest branch of `_detect_lint_command` (the real orchestrator-root path → `clean=True`, `command=""`) has no test; and `Path.exists()` runs synchronously in async `check_lint` (rule #9, ACCEPTED as Low). Fold into a single **preflight-hardening follow-up story** together with CWE-88 branch/repo validation and `LintResult.skipped`. Affects `pennyfarthing-dist/src/pf/preflight/finish.py` + `test_155_5_preflight_false_blocks.py`. *Found by Reviewer during re-review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **AC1 config half not unit-tested from this repo**
  - Spec source: context-story-155-5.md, AC1 ("Orchestrator repo config declares Python/ruff tooling")
  - Spec text: "Orchestrator repo config declares Python/ruff tooling; preflight no longer runs npm lint on the Python-only root."
  - Implementation: Tests cover only the CODE half (`check_lint` must not run npm and must reflect the Python linter on a Python project). The repos.yaml `language: python` config change is orchestrator-repo, non-distributed, and cannot be exercised by a pennyfarthing pytest.
  - Rationale: Framework-repo tests can only assert framework-repo behavior; the config edit is verified by the orchestrator repo (see blocking Delivery Finding).
  - Severity: minor
  - Forward impact: Dev/SM must land the `.pennyfarthing/repos.yaml` change separately (orchestrator PR to `main`) for AC1 to be fully satisfied end-to-end.

### Dev (implementation)
- **AC1 satisfied via file-based language detection, not repos.yaml**
  - Spec source: context-story-155-5.md, AC1 + story title ("stale repos.yaml language:javascript drives npm lint")
  - Spec text: "Orchestrator repo config declares Python/ruff tooling; preflight no longer runs npm lint on the Python-only root."
  - Implementation: `check_lint` now selects the linter from the project layout (`package.json`→npm, else `pyproject.toml`→ruff, else skip-clean) instead of consulting `repos.yaml` `language`. The orchestrator root has neither file, so lint is skipped (clean) — no npm false-block.
  - Rationale: `check_lint` never read `repos.yaml`; layout detection is self-contained in this repo, fixes the false-block without depending on the orchestrator-repo config edit, and needs no new cross-repo coupling. Reused the same detection precedence as `scripts/workflow/check.py::detect_project_type` (package.json→node) rather than importing that script module (a non-packaged `scripts/` file).
  - Severity: minor
  - Forward impact: The `.pennyfarthing/repos.yaml` `language` field is no longer load-bearing for preflight lint; its inaccuracy is downgraded to non-blocking (see Dev Delivery Finding).
- **Deferred two non-blocking reviewer findings out of this story (rework round-trip 1)**
  - Spec source: Reviewer Assessment (155-5), findings #4 (CWE-88) and #5 (LintResult.skipped)
  - Spec text: reviewer marked both as Low / non-blocking `Improvement`
  - Implementation: Not addressed in this rework; the two blocking findings + the corroborated fallback-robustness tests were addressed instead.
  - Rationale: Scope discipline (minimalism) — CWE-88 has a weak threat model (branch/repo are locally-controlled by the same agent that created the branch), and `LintResult.clean=True`-on-skip is functionally correct; neither blocks. Bundling them risks a wider diff and another review cycle for Low-value changes.
  - Severity: minor
  - Forward impact: Recommend a small follow-up story (preflight hardening: `--`/git-ref validation + `LintResult.skipped` for honest reporting). Captured as Reviewer Delivery Findings.

### Reviewer (audit)
- **TEA "AC1 config half not unit-tested from this repo"** → ✓ ACCEPTED by Reviewer: correct — framework-repo pytest can only cover the code half; sound scoping.
- **Dev "AC1 satisfied via file-based language detection, not repos.yaml"** → ✓ ACCEPTED by Reviewer: the layout-detection approach is a legitimate, more-robust root-cause fix (SOUL #1) that dissolves the cross-repo dependency. Rule-checker concurred it addresses the system, not the symptom. **HOWEVER** the deviation is only PARTIALLY realized: the fix updated detection but left the downstream `aggregate_results` remediation text hardcoded to npm (finish.py:400) — the fix-the-system principle applies to the recovery message too. Flagged as a blocking finding (not a reversal of the deviation, an incompleteness in executing it).
- **Undocumented divergence:** `check_lint` now returns `clean=True` for a root with no lintable project (skip), silently changing preflight lint from "always ran (npm)" to "may be a no-op" — not logged as a deviation by Dev. Spec (AC1) said "no longer runs npm lint on the Python-only root"; code goes further ("runs nothing on a root with neither manifest"). Reasonable, but should have been logged. Severity: Low. → Now documented by Dev in the round-1 deviation ("undocumented skip path"); resolved.
- **Dev "Deferred two non-blocking reviewer findings" (rework r1)** → ✓ ACCEPTED by Reviewer: scoping the Low CWE-88 + LintResult.skipped items to a follow-up is sound — both are non-blocking and bundling them would widen the diff for little value. Recommend a single preflight-hardening follow-up story.
- **Round 2 accept decision:** rule #9 blocking `Path.exists()` in async `check_lint` → ✓ ACCEPTED (explicit, not silent): fast local stat, dominated by the awaited subprocess, matches the module's existing `check_acceptance_criteria` pattern; `asyncio.to_thread` wrapping is a micro-opt SOUL #13 does not require. Tracked as follow-up.

## Sm Assessment

**Setup complete — routing to TEA (RED phase).**

This is a well-scoped 2pt bug in the `pennyfarthing/` repo (gitflow → `develop`, branch `feat/155-5`) with two independent false-block defects in `sm-finish` preflight. Both are documented ground truth from the SM sidecar (`preflight-npm-artifact`, `preflight-mutates-code`) — not speculation.

**Scope guardrails for the team:**
- Source of truth is `pennyfarthing/pennyfarthing-dist/` — trace the symlink. NEVER edit the `.pennyfarthing/` symlinked copy (repos.yaml lives behind a symlink).
- Root cause 1 confirmed present: orchestrator repo declared `language: javascript` / `build_command: npm install` — orchestrator is Python-only per ADR-0034. Correct to Python/ruff.
- Root cause 2: preflight PR-state logic must treat an already-merged PR as PASS, not "No PR found".
- Two orthogonal defects → two failing tests minimum (AC3). Keep them independent so a fix to one doesn't mask the other.

**Jira:** none — internal framework story, explicitly skipped.

**Next:** TEA (Captain Murdock) writes the failing RED tests reproducing both false-blocks, then hands to Dev for GREEN.

## TEA Assessment

### Red Phase (test writing)

**Tests Required:** Yes
**Reason:** Bug fix with two distinct false-block failure modes — both need regression coverage (AC3).

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_5_preflight_false_blocks.py` — 7 tests over `pf.preflight.finish`

**Tests Written:** 7 tests covering AC1 + AC2 (+ over-reach guards for AC3)
**Status:** RED (4 failing — ready for Dev; 3 guards green now and must stay green)

**RED tests (fail now, pass after fix):**
| Test | AC | Proves |
|------|----|--------|
| `test_check_lint_does_not_invoke_npm_on_python_project` | AC1 | `check_lint` runs npm on a Python root |
| `test_check_lint_reports_clean_when_python_linter_passes` | AC1 | npm failure reported as not-clean; Python linter ignored |
| `test_check_pr_status_detects_merged_pr_when_branch_deleted` | AC2 | merged-but-branch-deleted PR reads as "no PR found" |
| `test_preflight_does_not_block_merged_pr_with_deleted_branch` | AC2 | merged PR false-blocked as critical "No PR found" |

**Guard tests (green now, must stay green — prevent over-reach):**
| Test | Guards |
|------|--------|
| `test_check_lint_still_uses_npm_on_a_node_project` | Node projects must still npm-lint |
| `test_check_pr_status_genuinely_missing_pr_still_flags` | A never-merged branch must still surface an error |
| `test_preflight_still_blocks_when_pr_genuinely_missing` | Genuinely missing PR must still block finish |

### Rule Coverage

| Rule (lang-review/python.md) | Test(s) | Status |
|------|---------|--------|
| #1 silent exception swallowing | over-reach guards assert a missing PR still surfaces `error` (fallback must not swallow) | enforced |
| test quality (no vacuous asserts) | every test asserts a concrete value (`merged`/`clean`/issue text); self-checked | pass |
| mock target correctness | subprocess patched at the used site (`asyncio.create_subprocess_exec` + `create_subprocess_shell`), not where defined | pass |

**Rules checked:** 3 of 3 applicable to this bug (this is I/O-dispatch + error-path code, not type/enum design — most lang-review rules N/A).
**Self-check:** 0 vacuous tests found.

**Verification contract for Dev (GREEN):**
- `check_lint`: detect language (reuse `check.py::detect_project_type` / `repo_config.lint_cmd`); on Python run ruff, never npm; reflect that tool's returncode in `LintResult.clean`.
- `check_pr_status`: when `gh pr view <branch>` reports "no pull requests found", fall back to a head-branch merged-PR lookup (`gh pr list --state merged --head <branch>`, consistent with story 155-1) and set `merged=True`, `error=None` when a merged PR is found. Do NOT swallow the error when no merged PR exists.
- **Cross-repo:** the `.pennyfarthing/repos.yaml` `language: python` edit is orchestrator-repo (see Delivery Finding + Deviation). Code fix here is independent and testable on its own.

**Handoff:** To Dev (Sergeant B.A. Baracus) for implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/preflight/finish.py` — two fixes:
  - `check_lint` is now language-aware via new `_detect_lint_command` (package.json→`npm run lint`, else pyproject.toml→`ruff check .`, else skip→clean). No more hardcoded npm on a Python/empty root.
  - `check_pr_status` now falls back to `_lookup_merged_pr_by_branch` (`gh pr list --state merged --head <branch>`) when `gh pr view` reports "no pull requests found", so a merged-but-branch-deleted PR is recognized as merged instead of "No PR found".

**Tests:** 7/7 passing in `test_155_5_preflight_false_blocks.py` (GREEN). 4 prior RED tests now pass; 3 over-reach guards stayed green.
**Regressions:** None attributable to this change. Related suites `test_155_1`, `test_155_12` pass (35 passed). Two `test_independence.py::TestCli` failures are pre-existing (env-dependent subprocess smoke tests; confirmed identical with this change stashed).
**Lint:** `ruff check` clean on changed files.
**Branch:** feat/155-5 (pushed to origin)

**Minimalism note:** Reused existing detection precedence rather than importing the non-packaged `scripts/workflow/check.py`; no new abstractions beyond the two small private helpers each test requires.

**Handoff:** To Reviewer (Colonel Decker) for adversarial review.

### Dev Rework (round-trip 1 — addressing REJECTED review)

**Blocking findings — FIXED:**
- **Stale npm remediation (finish.py:400):** Added `LintResult.command` (records the linter actually run, e.g. `ruff check .`); `check_lint` sets it; `aggregate_results` now emits `Run '{command}' and fix errors` (or a generic fallback), so a Python `ruff` failure names ruff, not npm. Root-cause-complete (SOUL #1) — the npm string no longer survives anywhere in the lint path.
- **One-sided Bug-1 tests:** Added positive assertions that `ruff` actually appears in the invoked commands (both Bug-1 tests) + `LintResult.command == "ruff check ."`. The tests now fail if linting is silently disabled (verified against the reviewer's `_detect_lint_command`→None scenario).

**Non-blocking findings folded in (cheap + corroborated):**
- Added `test_python_lint_failure_remediation_names_ruff_not_npm` (pins the message fix).
- Added `test_check_pr_status_surfaces_error_when_fallback_lookup_fails` and `test_check_pr_status_survives_malformed_gh_list_json` — pin the fallback's fail-safe behavior (original error surfaces; no crash on gh failure / malformed JSON).

**Non-blocking findings DEFERRED to follow-up (scope discipline):**
- CWE-88 `branch`/`repo` argv validation (Low, self-controlled local branch, weak threat model).
- `LintResult.skipped` field (observability nicety; `clean=True` on skip is functionally correct).
See Design Deviation + Delivery Findings for the follow-up recommendation.

**Tests:** 10/10 passing (was 7; +3 new). Related suites `test_155_1`, `test_155_12` green (20 passed). Ruff clean. Branch pushed.

**Handoff:** To Reviewer (Colonel Decker) for re-review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 | 7/7 tests green, ruff clean, 0 smells; pre-existing `test_independence::TestCli` failures confirmed unrelated |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via `workflow.reviewer_subagents.edge_hunter=false` — edge cases assessed by lead |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings — silent-failure domain assessed by lead (see fallback finding) |
| 4 | reviewer-test-analyzer | Yes | findings | 5 | confirmed 2 (one-sided Bug-1 tests [blocking], fallback-error path untested), deferred 3 (multi-PR, non-matching-error, over-reach) |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings — stale `npm` remediation comment caught by rule-checker instead |
| 6 | reviewer-type-design | Yes | findings | 6 | confirmed 2 (LintResult.clean overload, fallback None-overload), dismissed 1 (Any-in-private-helper: rule #3 exempts private), deferred 3 (dict-vs-dataclass, Literal enums, mergeable-unset=harmless) |
| 7 | reviewer-security | Yes | findings | 4 | confirmed 1 non-blocking (CWE-88 arg-injection, Low), deferred 3 (json isinstance, swallow-no-log, all fail-safe); no Critical/High — argv-form neutralizes shell injection |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings — no over-engineering observed by lead (2 small private helpers) |
| 9 | reviewer-rule-checker | Yes | findings | 3 | confirmed 3 (stale npm remediation [blocking], silent None on gh-list-fail, blocking stat in async [Low]) |

**All received:** Yes (5 enabled returned, 4 disabled pre-filled)
**Total findings:** 4 confirmed blocking-relevant (2 blocking + corroboration), 5 confirmed non-blocking, 1 dismissed (with rule citation), 7 deferred

### Round 2 re-review (after rework)

| # | Specialist | Received | Status | Result |
|---|-----------|----------|--------|--------|
| 1 | reviewer-preflight | Yes | clean | 10/10 tests green, ruff clean, 0 smells, diff tightly scoped |
| 4 | reviewer-test-analyzer | Yes | findings | Both blocking findings **mutation-verified CLOSED** (detection→None now fails; reverting message/swallowing error fails guards). 1 new LOW: neither-manifest skip branch untested. |
| 9 | reviewer-rule-checker | Yes | findings | Rule #13 npm-remediation **CLOSED** (grep-confirmed, regression test pins it); rule #1 silent-None **ADDRESSED** (fail-safe, 2 tests); rule #9 async-stat REMAINS (Low, unchanged) → **ACCEPTED** by lead. |
| 6,7 | type-design, security | Carry-forward | — | No new code in domain except annotated `LintResult.command` field (compliant); prior non-blocking findings deferred to follow-up (documented). |

**Round 2 all received:** Yes (3 re-run on the rework diff + 2 carried forward with rationale; 4 disabled unchanged)
**Round 2 verdict:** both Round-1 blocking findings CLOSED and mutation-verified → APPROVED.

## Rule Compliance

Enumerated against `.pennyfarthing/gates/lang-review/python.md` (13 checks) + SOUL/CLAUDE additions:

| # | Rule | Result |
|---|------|--------|
| 1 | Silent exception swallowing | **PARTIAL** — `except (OSError, JSONDecodeError): return None` is compliant (specific, commented, fails safe). BUT `if proc.returncode != 0: return None` (finish.py:166) silently discards gh stderr — [RULE][SILENT] finding, non-blocking (fail-safe). |
| 2 | Mutable default arguments | PASS — `repo: str|None`, `project_root=None`; no mutable defaults. |
| 3 | Type annotations at boundaries | PASS — both new fns fully annotated. `dict[str,Any]` in `_lookup_merged_pr_by_branch` is a **private** helper → rule's own "internal/private helpers exempt" clause applies. [TYPE] flag DISMISSED on that basis. |
| 4 | Logging coverage/correctness | N/A — module imports no logger. |
| 5 | Path handling | PASS — pathlib throughout (`project_root / "package.json"`); no string concat, no `open()` added. |
| 6 | Test quality | **FAIL** — Bug-1 lint tests one-sided (pass even if lint disabled), proven experimentally. [TEST] **blocking**. Bug-2 tests + mock target compliant. |
| 7 | Resource leaks | PASS — subprocess `communicate()` matches existing convention. |
| 8 | Unsafe deserialization / subprocess | PASS — `create_subprocess_exec` argv (no shell=True); `json.loads` guarded by try/except. |
| 9 | Async pitfalls | **MINOR** — blocking `Path.exists()` stat inside async `check_lint` under `gather` (finish.py:250); rule #9 literal match, negligible (2 stats). [RULE] Low, deferred. `gather` already has `return_exceptions=True`. |
| 10 | Import hygiene | PASS — explicit imports, no star/circular. |
| 11 | Input validation at boundaries | **MINOR** — CWE-88 branch/repo unvalidated into gh argv (finish.py:151,184). [SEC] Low, non-blocking (self-controlled branch), deferred. |
| 12 | Dependency hygiene | N/A — no dep files changed. |
| 13 | Fix-introduced regressions | **FAIL** — `aggregate_results` stale `fix="Run 'npm run lint'..."` (finish.py:400): Python ruff failure emits npm guidance. [RULE] **blocking**. |
| + | SOUL #1 fix-the-system | PARTIAL — root-cause fix good; remediation-text symptom left (same as #13). |
| + | CLAUDE #6 return-results | PASS — all paths return result objects, no throws. |

## Devil's Advocate

Assume this code is broken. The most damning case: the story's own goal is "stop running npm lint on the Python-only root," yet after this change a Python project whose `ruff` check fails is told, verbatim, to *"Run 'npm run lint' and fix errors"* (finish.py:400). The fix cured the disease in `check_lint` and left the same pathogen in the patient's discharge instructions. An operator following that guidance runs npm, gets nothing, and distrusts the whole preflight — the exact confusion this epic ("finish/merge/archive truthfulness") exists to eliminate. That is not a cosmetic nit; it is the story bug, relocated.

Second: the Bug-1 tests give false confidence. The test-analyzer *proved* that stubbing `_detect_lint_command` to always return `None` — i.e. silently disabling linting for every project, Python included — leaves both positive tests green. So the regression these tests nominally guard (AC3) is not actually pinned: a future refactor could disable Python linting entirely and CI would stay green. A test that passes when the feature is removed tests nothing.

Third, a confused-user/stressed-filesystem angle: `check_lint` at a root with neither `package.json` nor `pyproject.toml` now reports `clean=True` — "lint passed" — when in truth nothing ran. On the real orchestrator root that is the *normal* path, so preflight's lint signal is now permanently green-by-absence, indistinguishable in `to_dict()` from a genuine clean run. The `JiraStatus.skipped` precedent right next to it shows the codebase already knows the honest way to model this and this change didn't follow it.

Fourth, infra failure: if `gh` is broken (auth expired, rate-limited) during the fallback, `_lookup_merged_pr_by_branch` returns `None`, and the user sees only "No PR found" — misdirected toward "create a PR" when the real problem is a broken `gh`. Fails safe (blocks), but lies about why. None of these are crashes or CVEs — but three of the four are *truthfulness* defects in a truthfulness epic, and two are incomplete-AC. That is enough to send back.

## Reviewer Assessment

**Verdict:** APPROVED (round-trip 1 — Round 1 REJECTED, rework verified closed in Round 2)

### Round 1 findings (REJECTED) — resolution status

| Severity | Issue | Round-2 status |
|----------|-------|----------------|
| [MEDIUM] `[RULE]` Incomplete fix — lint remediation hardcoded "Run 'npm run lint'" (finish.py:400) | **CLOSED** — `LintResult.command` records the linter run; `aggregate_results` now emits `Run '{command}' and fix errors`. rule-checker grep confirmed no npm remediation remains; pinned by `test_python_lint_failure_remediation_names_ruff_not_npm` (mutation-verified: reverting the message fails the test). |
| [MEDIUM] `[TEST]` Bug-1 lint tests one-sided (finish.py detection→None still green) | **CLOSED** — positive assertions added (`any("ruff" in ...)`, `command == "ruff check ."`); test-analyzer re-ran the detection→None stub and both tests now FAIL as required. |
| [LOW] `[RULE][SILENT][SEC]` Fallback masks infra failure | **CLOSED (fail-safe pinned)** — 2 new tests (`..._surfaces_error_when_fallback_lookup_fails`, `..._survives_malformed_gh_list_json`) assert the original blocking error surfaces on gh failure / bad JSON. Observability logging deferred (module has no logger). |
| [LOW] `[SEC]` CWE-88 branch/repo validation | **DEFERRED** — non-blocking follow-up (weak threat model; branch is locally-controlled). Logged as Dev deviation + Reviewer Delivery Finding. |
| [LOW] `[TYPE]` LintResult.clean skipped-vs-passed overload | **DEFERRED** — non-blocking follow-up (functionally correct). |

### Round 2 re-review — new findings

| Severity | Issue | Location | Decision |
|----------|-------|----------|----------|
| [LOW] `[RULE]` | Blocking `Path.exists()` stat inside async `check_lint` via `_detect_lint_command` (rule #9); unchanged by rework | `finish.py:251,238,240` | **ACCEPTED** (explicit) — fast local `stat()`, not network/large-read; the dominant blocking cost is the awaited linter subprocess; the sibling `check_acceptance_criteria` already does the same synchronous `.exists()/.read_text()` in async (established module pattern). Wrapping two stats in `asyncio.to_thread()` is a micro-optimization SOUL #13 does not require. Tracked as a non-blocking follow-up. |
| [LOW] `[TEST]` | The neither-manifest skip branch of `_detect_lint_command` (the real orchestrator-root path → clean, command="") is untested | `test_155_5...py` | Non-blocking follow-up — benign no-op path; captured as a Delivery Finding. |

**Subagent tag coverage (Round 2):** `[TEST]` one-sided lint tests CLOSED (mutation-verified) + new untested-skip-branch (Low) · `[RULE]` npm-remediation regression CLOSED, silent-None CLOSED (fail-safe), async-stat ACCEPTED (Low) · `[TYPE]` LintResult overload deferred, `LintResult.command` field annotated (compliant) · `[SEC]` CWE-88 deferred (Low), argv-form still neutralizes shell injection (VERIFIED) · `[SILENT]` fallback now pinned fail-safe by 2 tests · `[EDGE]` disabled — fallback/detection paths assessed by lead · `[DOC]` disabled · `[SIMPLE]` disabled — no over-engineering (`LintResult.command` is a minimal, justified field)

**Verified good:**
- `[VERIFIED]` Both blocking findings mutation-verified closed — test-analyzer reverted the fix / stubbed detection and the guard tests failed correctly; rule-checker grep confirmed no npm remediation path remains (finish.py:399-403 conditional on `lint.command`).
- `[VERIFIED]` No shell injection — `create_subprocess_exec(*cmd)` argv form; no `shell=True` (rule #8, confirmed both rounds).
- `[VERIFIED]` Fallback fails safe — merged PR skips blocking; gh-failure/bad-JSON degrade to the original blocking error (finish.py:167-171 + 2 new tests).
- `[VERIFIED]` 10/10 tests green, ruff clean; `test_155_1`/`test_155_12` regression suites green (20 passed).

**Data flow traced:** `branch` (session `Branch:` → sm-finish) → `gh pr view`/`gh pr list` argv (safe, discrete tokens) → `PRStatus` → `aggregate_results` → block/pass. `project_root` (cwd) → `_detect_lint_command` (file-presence) → linter argv → `LintResult` → truthful remediation. Both paths fail safe.

**Handoff:** To SM (Faceman) for finish-story. Non-blocking follow-ups (CWE-88 validation, `LintResult.skipped`, async-stat `to_thread`, skip-branch test) recommended as a single small preflight-hardening story.

## Branch

**Branch Strategy:** gitflow (feat/155-5)
**Base Branch:** develop (pennyfarthing repo)
**Target Repo:** pennyfarthing