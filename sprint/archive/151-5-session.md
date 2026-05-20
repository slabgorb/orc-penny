# Story 151-5: Staleness Preflight

## Status: RED (Round 3 - Dev Implementation)

**Staleness Preflight Tests (Verification Run)**
- Pass: 33
- Fail: 7
- Duration: 32.88s
- Exit: 1 (RED)

## Failing Tests (7)

1. `test_ack_on_clean_result_does_not_set_acknowledged_key` — acknowledged flag leaking into clean results
2. `test_root_slash_surface_path_does_not_match_every_file` — `/` surface path vulnerability
3. `test_files_overlap_lists_all_modified_surface_files_in_one_commit` — NUL-separated file parsing missing entries
4. `test_long_title_does_not_stall_preflight` — ReDoS in path heuristic regex (29.53s execution)
5. `test_malformed_start_date_yields_hard_error_not_silent_clean` — malformed date silent clean bug
6. `test_cli_malformed_start_date_yields_exit_code_two` — exit code 0 instead of 2
7. `test_list_with_non_string_entries_yields_error_not_partial_check` — list validation silent pass

## Key Issues

- **acknowledged flag**: Contaminating clean results
- **Path heuristic**: ReDoS vulnerability on long titles (should be <0.2s, actual 29.53s)
- **Git log parsing**: Missing files in multi-file commits due to NUL separator handling
- **Input validation**: Three tests failing due to silent pass on malformed/invalid input

## Next Step

Dev: Implement fixes for these 7 failing test cases.

Workflow: TDD

---

## Design Deviations

### Dev (implementation)
- No deviations from spec. Each of the six round-3 fixes implements the contract pinned by the corresponding round-3 RED test exactly as Igor's TEA hint described:
  - `_path_matches('/')` rejected via `not surface_path.strip("/")`
  - `acknowledged=True` only when `status == "drift"`
  - `start_date` validated against `^\d{4}-\d{2}-\d{2}.*` at the YAML boundary
  - non-string entries in `implementation_surface` rejected at the boundary with the offending index named in the error
  - ReDoS bounded by truncating heuristic input to 2000 chars (operator-realistic ceiling)
  - `_parse_git_log` reshape detects header tokens by structure (3 pipe-fields + first is a SHA) so multi-file commits keep every file rather than dropping all but the first

Round-2 [LOW] items intentionally deferred (TEA flagged in round-3 RED Delivery Findings):
- `from __future__ import annotations` redundancy on Python ≥3.10 — non-test cleanup, not fixed
- Missing module `__all__` — non-test cleanup, not fixed
- `staleness_cli --help` exit-0 indistinguishability — open question, no test, not fixed
- Stale `origin/<base>` warning — open question, no test, not fixed
- Comma-string repos field gold-plating — optional, not taken (no test)

These are non-blocking and consistent with the TEA round-3 handoff.

### TEA (test verification)
- No deviations from spec.

### Reviewer (audit)
- **Dev's six round-3 implementation entries** → ✓ ACCEPTED by Reviewer: each fix matches the round-3 RED test contract verbatim; verified line-by-line against test classes during diff audit (see ## Reviewer Findings below).
- **Dev's deferred [LOW] list (annotations import, `__all__`, --help exit code, stale origin warning, comma-string repos)** → ✓ ACCEPTED by Reviewer: TEA → Architect → Reviewer chain agrees these are non-blocking follow-ups consistent with the round-3 RED scope.
- **Architect's "shape-only start_date regex" deferral** → ✓ ACCEPTED by Reviewer: residual silent-clean on `9999-99-99`-shaped values is real but architect explicitly ruled it out of round-3 scope; flagged in this assessment as a follow-up so the next reviewer (external) sees it without having to re-derive.
- **UNDOCUMENTED — vacuous secondary assertion in `test_long_title_does_not_stall_preflight`** (test:1773): TEA introduced `assert result.get("success") in (True, False)` in round 3. Per python.md §6 (test quality) and §13 (fix-introduced regression), this should have been logged as a deviation by TEA at the moment of writing. It was not. Severity: medium. Recorded here so the audit trail reflects it. Not blocking given the test's primary assertion (`elapsed < 2.0`) is sound, but the next round of TEA should self-check more strictly.
- **UNDOCUMENTED — module comment line 48-53 not updated to match the round-3 `_parse_git_log` reshape** (staleness.py): the comment asserts file lists are "newline-separated under `--name-only`" — this contradicts the `-z` reality the new parser depends on. Round 3 reshaped the parser but did not update the supporting comment. Should have been a Dev deviation entry. Severity: medium. Recorded here.

### Architect (reconcile)

The boss reads this section. Every round-3 deviation is captured below in 6-field form so the audit trail stands on its own without external lookups.

- **start_date validation is shape-only, not calendrically valid**
  - Spec source: round-2 reviewer findings (`sprint/epic-MSSCI-17079.yaml#stories[151-5].review_findings`), MEDIUM row "`--since` accepts free-text date"; pinned by `tests/python/test_151_5_staleness_preflight.py::TestSinceDateValidation`
  - Spec text: "Git silently treats an unrecognised free-text date as 'match nothing'" (round-3 RED test docstring)
  - Implementation: `pennyfarthing-dist/src/pf/sprint/staleness.py:124` uses `re.fullmatch(r"\d{4}-\d{2}-\d{2}.*", start_date_str)` — accepts `9999-99-99` and other calendrically-invalid shapes; trailing `.*` permits arbitrary suffix.
  - Rationale: Architect ruled stricter calendar validation out-of-scope for round 3 during spec-check. The pinned test only requires free-text rejection; impossible-date residue and suffix-permissiveness fall to a follow-up.
  - Severity: minor (residual silent-clean — same anti-pattern the story exists to prevent, but architect-deferred)
  - Forward impact: minor — a follow-up using `datetime.date.fromisoformat(start_date_str[:10])` plus `re.fullmatch(r"\d{4}-\d{2}-\d{2}(T[\d:.+-]+Z?)?$", ...)` closes both gaps. Sibling stories 151-6 / 151-7 do not depend on the start_date shape.

- **Module comment at staleness.py:48-53 contradicts the round-3 `_parse_git_log` reshape**
  - Spec source: round-3 implementation contract (the new `_parse_git_log` keys on token shape because files arrive as bare NUL-separated tokens under `-z`)
  - Spec text: from the new `_parse_git_log` docstring at `staleness.py:516` — "subsequent files arrive as their own bare NUL-separated tokens"
  - Implementation: `staleness.py:48-53` still says "the format string output is followed by `\n` then the file list (newline-separated under `--name-only`)" — the older no-`-z` shape, which is the OPPOSITE of what the new parser requires
  - Rationale: comment was carried forward unchanged through round 3; nobody (Dev, TEA, Architect spec-check) caught it until Reviewer. Should have been a Dev deviation log at the moment the parser was reshaped.
  - Severity: minor (comment, not logic — but actively misleading to future maintainers)
  - Forward impact: minor — one-line rewrite to match the `-z` reality. No code change.

- **Vacuous secondary assertion in `test_long_title_does_not_stall_preflight`**
  - Spec source: python.md §6 (test quality) — "`assert result` without checking specific value — truthy check misses wrong values"; also python.md §13 (fix-introduced regressions, meta-check)
  - Spec text: from `gates/lang-review/python.md`, rule §6: "Search test files for: assert True or assert not False — vacuously true; assert result without checking specific value — truthy check misses wrong values"
  - Implementation: `tests/python/test_151_5_staleness_preflight.py:1773` adds `assert result.get("success") in (True, False)` as a secondary assertion. Comment promises a structural check; assertion only verifies bool-ness. The same kind of weak assertion round-2 was rejected for.
  - Rationale: TEA self-check (Phase C) did not catch the weak assertion at write time. Primary assertion in the test (`elapsed < 2.0`) is sound — the test's correctness gate is intact, but the §6 violation persists.
  - Severity: minor (test still bites via the primary assertion)
  - Forward impact: minor — replace with `assert result.get("status") == "skipped"` (matches the no-extension-match contract the test already constructs). One line, no logic change.

- **`acknowledged=True` semantics changed for `skipped` and `error` statuses (not just `clean`)**
  - Spec source: pinned by `TestAcknowledgmentBehavior::test_ack_on_clean_result_does_not_set_acknowledged_key`
  - Spec text: "acknowledged=True on a clean result misleads audit consumers — the flag must only be set when drift was detected and overridden"
  - Implementation: `staleness.py:345` gates on `ack and status == "drift"` — strips `acknowledged` from clean / skipped / error results, not just clean.
  - Rationale: the test pins the `clean` case; Dev correctly generalised the contract to "drift only" rather than "not-clean only". Skipped/error behaviour is now also stripped of the flag, which is the intent (nothing to override on skipped/error either).
  - Severity: trivial (broader scope than tested, but consistent with the spec's stated semantics)
  - Forward impact: none — sibling stories don't read `acknowledged` from non-drift results.

- **Reviewer findings deferred to follow-up (not a deviation per se, but a manifest for the boss)**
  - The following [LOW] items were known and explicitly deferred by TEA → Architect → Reviewer:
    - Missing module `__all__` (python.md §10)
    - `from __future__ import annotations` redundant on Py ≥3.10
    - `staleness_cli --help` exit-0 indistinguishable from clean (open question)
    - Stale `origin/<base>` ref returns silent-stale data (open question)
    - Comma-string repos field gold-plating
    - Missing wildcard test for `_path_matches`
    - `dict[str, Any]` for commit records lacks §3 comment
    - `_resolve_paths` retains a now-redundant filter
    - `_print_human_summary` "origin/" hardcode (pre-existing)
    - SOUL.md §10 envelope shape is flat, not `{success, data?, error?}` (pre-existing)
  - These are non-blocking and consistent across all three reviewer phases; the audit trail records them so a follow-up story can cherry-pick.

**No additional deviations found beyond the manifest above.**

---

## Delivery Findings

### Dev (implementation)
- **Improvement** (non-blocking): The full python test suite has 21 unrelated failures + 4 errors at this commit (test_143_9_tdd_cycle_e2e, test_148_23_reviewer_gate_clarity, test_141_20_agent_validator, test_pypi_packaging, test_peloton_pane_layout, test_143_10_reviewer_dev_roundtrip, test_143_12_subagent_dispatch). Confirmed pre-existing by stashing the 151-5 staleness diff and re-running — the failures persist at baseline. Affects multiple files under `pennyfarthing-dist/src/pf/tests/` (orthogonal to 151-5). *Found by Dev during regression-check.*
- **Question** (non-blocking): Subagent (`testing-runner`) summary mis-attributed those pre-existing failures as "introduced by recent staleness fixes" in its `next_steps`. The body data was correct; the synthesis was wrong. May warrant a sidecar pattern note for the testing-runner persona to caution against attribution claims when the diff scope is narrow. Affects `pennyfarthing-dist/agents/testing-runner.md` (or its persona). *Found by Dev during regression-check.*
- **Gap** (non-blocking): A `testing-runner` subagent silently switched the working tree from `feat/151-5-sm-setup-base-branch-staleness-preflight` to `feature/test` between RED-verify and GREEN-verify (reflog HEAD@{1}: "checkout: moving from feat/151-5-... to feature/test"). The first commit landed on the wrong branch and was recovered manually (`git branch -f` then push). Both branches now exist on origin and point to the same SHA. The `testing-runner` agent should not be permitted to checkout branches; the safety contract is "run, don't mutate." Affects `pennyfarthing-dist/agents/testing-runner.md` and possibly its sandbox permission set. *Found by Dev during commit step.*
- **Question** (non-blocking): The stray `origin/feature/test` ref now points at the round-3 GREEN commit. SM or Reviewer may want to delete it during cleanup; not deleted from Dev because remote-branch deletion is a destructive op outside auto-mode authorization. *Flagged by Dev for SM/Reviewer.*

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/staleness.py` — six round-3 fixes (root-slash guard, acknowledged-only-on-drift, start_date shape validation, non-string surface rejection, ReDoS input bound, multi-file commit parser reshape)

**Tests:** 40/40 passing (GREEN)
- Wall: 3.59s (was 32.85s; ReDoS test alone went from 29.05s to ~0.05s)
- No regressions: every test that passed under round-2 still passes
- Full python suite: 21 pre-existing failures + 4 errors confirmed unrelated by baseline-stash check (see Delivery Findings)

**Branch:** `feat/151-5-sm-setup-base-branch-staleness-preflight` (will push)

**Handoff:** To Reviewer (Granny Weatherwax) for round-3 code review

---

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None
**Gate (gates/spec-check):** ready (resolve-gate confirmed assessment_found=true, status=ready)

### What I checked

The "spec" for round 3 is the round-2 reviewer severity table (3 HIGH + 5 MEDIUM that the round-2 verdict rejected on) plus the round-3 RED tests TEA wrote to pin each row. I walked the diff (`HEAD~1..HEAD` on `pennyfarthing-dist/src/pf/sprint/staleness.py`) against each pinned contract:

| Round-2 finding | Pinned by RED test | Implementation | Verdict |
|-----------------|-------------------|---------------|---------|
| [HIGH] `_parse_git_log` drops files after the first | `TestMultiFileCommit::test_files_overlap_lists_all_modified_surface_files_in_one_commit` | Header detection now keys on token shape (3 pipe-fields + first matches `_HASH_RE`); bare tokens become file paths on the most-recent commit. Docstring updated to reflect the new contract. | Aligned |
| [HIGH] `_PATH_HEURISTIC_RE` ReDoS | `TestPathHeuristicReDoS::test_long_title_does_not_stall_preflight` | `bounded = str(text)[:2000]` before `findall()`. Wall dropped from 29.05s → ~0.05s. | Aligned |
| [MEDIUM] `--since` accepts free-text date | `TestSinceDateValidation::test_malformed_start_date_yields_hard_error_not_silent_clean` | `re.fullmatch(r"\d{4}-\d{2}-\d{2}.*", start_date_str)` boundary-validates immediately after extracting `start_date`. Error names both the field and the offending value. | Aligned |
| [MEDIUM] CLI surface for malformed start_date | `TestSinceDateValidation::test_cli_malformed_start_date_yields_exit_code_two` | Closed transitively via the result-dict fix above (`success=False` already routes the CLI to exit 2). | Aligned |
| [MEDIUM] `_resolve_paths` non-string entries silently filtered | `TestExplicitSurfaceFiltering::test_list_with_non_string_entries_yields_error_not_partial_check` | List walked at the public boundary; first non-string or empty entry yields `success=False, status=error` with the offending index named. | Aligned |
| [MEDIUM] `_path_matches('/')` matches every absolute path | `TestPathMatchingHelper::test_root_slash_surface_path_does_not_match_every_file` | Empty-guard generalised to `not surface_path.strip("/")` — catches both `""` and `"/"` (and any all-slash path). | Aligned |
| [MEDIUM] `acknowledged=True` on non-drift results | `TestAcknowledgmentBehavior::test_ack_on_clean_result_does_not_set_acknowledged_key` | `_result()` gates the flag on `ack and status == "drift"`; clean / skipped / error results never carry the key. | Aligned |
| [HIGH] vacuous shell-injection test | TEA reshape (`TestRuleInputValidation::test_unknown_story_id_is_rejected_at_boundary_no_subprocess_call` + `test_shell_metacharacters_in_implementation_surface_pass_through_safely`) | No Dev work needed — TEA owned the test rework, impl already correct. | Aligned |

### Substantive observations (not mismatches)

These are design choices matching TEA's hints. Documenting them so Reviewer doesn't have to re-derive the rationale:

- **Start-date regex is shape-only.** `\d{4}-\d{2}-\d{2}.*` accepts impossible dates like `9999-99-99`. The pinned test only asserts free-text `"not-a-date"` is rejected and the field name appears in the error; stricter calendrical validation is out-of-scope for this round. If `9999-99-99` ever leaks through, `git log --since` would still treat it as match-nothing — the existing silent-clean is the residual risk. Worth a follow-up story (cheap: `datetime.date.fromisoformat(start_date_str[:10])`).
- **ReDoS fix is input-bounding, not regex rewrite.** TEA's hint #5 explicitly accepted either approach; bounding to 2000 chars is the minimal-footprint change and 2000 is well above any realistic operator-authored title/description. Pattern simplification can be a follow-up if a future story exercises long descriptions.
- **`_path_matches` uses `strip("/")` rather than `surface_path in {"", "/"}`.** Slightly more general — also catches `"//"`, `"///"`, etc. Same contract, no behavioural surprise; the simpler equality form would have worked equally well.
- **Header detection by SHA shape.** Robust to commit subjects that contain pipes (`|` is not in the hex alphabet) and to filenames that contain pipes (a 40-char-hex-prefixed filename token would be the only collision; vanishingly unlikely and not a realistic threat). Docstring explains the contract.

### Deferred LOW items (consistent with TEA round-3 Delivery Findings)

These were [LOW] in round-2 and explicitly held by TEA out of round-3 RED scope; Dev correctly did not address them. None are spec drift:

| Deferred | Reason | Disposition |
|----------|--------|-------------|
| `from __future__ import annotations` redundancy on Py ≥3.10 | non-test cleanup | follow-up |
| Missing module `__all__` | non-test cleanup | follow-up |
| `staleness_cli --help` exit-0 indistinguishable from clean | argparse `SystemExit(0)` is the standard pattern; reviewer/PM call | open question, no test |
| Stale `origin/<base>` ref returns silent-stale data | testing this requires either a network-fetch fixture or impl-coupled mock | open question, deferred |
| Comma-string repos field gold-plating | optional one-line cleanup, no test | optional |

### Delivery Findings — Architect notes (spec-check)

- **Question** (non-blocking): The story 151-5 has no `acceptance_criteria`, `description`, or `implementation_surface` field in `sprint/epic-MSSCI-17079.yaml`, and there is no `sprint/context/151-5-context.md` either. Round-3 spec lives entirely in (a) the round-2 reviewer findings YAML field, (b) TEA's session-file assessment, (c) the round-3 RED test names. This makes the spec-check phase work but ties spec audit to session-file longevity. If the session is later archived or trimmed, the audit trail thins. Worth a SM-side process note for chore-type stories that iterate via review findings rather than ACs. *Found by Architect during spec-check.*
- **Confirmation** (non-blocking): The Dev-flagged `feature/test` branch issue and `testing-runner` branch-checkout incident are real and worth following up — but they are scope-orthogonal to 151-5 and properly belong to a framework story. Leaving the Dev findings intact for SM to triage.

**Decision:** Proceed to TEA verify (next phase per workflow).

---

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed (40/40, RUN_ID `151-5-tea-verify`, wall 3.55s)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 2 (`pennyfarthing-dist/src/pf/sprint/staleness.py`, `tests/python/test_151_5_staleness_preflight.py`)

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | clean | 0 findings — production and test helpers serve distinct purposes; no extractable cross-file duplication |
| simplify-quality | clean | 0 findings |
| simplify-efficiency | clean | 0 findings — error-handling breadth is required by SOUL.md "Return Results, Don't Throw"; defensive `subprocess.run(shell=False)` is required by python.md §11 |

**Applied:** 0 high-confidence fixes
**Flagged for Review:** 0 medium-confidence findings
**Noted:** 0 low-confidence observations
**Reverted:** 0

**Overall:** simplify: clean

### Quality Checks

- 151-5 staleness suite: 40/40 PASS, wall 3.55s, no regressions vs. round-3 GREEN baseline
- Wider python suite carries 21 unrelated pre-existing failures + 4 errors (Dev confirmed by stash-and-rerun in round-3 — see `### Dev (implementation)` Delivery Findings). Not gating; out of scope for 151-5.

### Rule Coverage (verify pass)

The round-3 RED file already covers all 13 numbered checks in `gates/lang-review/python.md` (TEA round-3 RED assessment, Rule Coverage section). No new rule-axis tests added in verify — verify is for simplification + quality regression checks, not net-new test design. The round-3 RED axis stands.

### Design Deviations

### TEA (test verification)
- No deviations from spec. Verify ran the simplify fan-out and the GREEN regression check exactly as the workflow YAML specifies; no scope changes, no test additions, no test removals.

### Delivery Findings

### TEA (test verification)
- **Improvement** (non-blocking): Workflow doc references `pf check` as the project-agnostic quality runner ("Step 7: Regression Detection" in tea.md), but `pf check` is not a registered command in the orchestrator install (`pf check → No such command 'check'`). Project tooling falls through to `just test` (pytest only). Either implement `pf check` to wrap `just check` / `pf-check` skill / language-specific runners, or update tea.md to reference the actual runner used by this project. Affects `pennyfarthing-dist/agents/tea.md` and `pennyfarthing-dist/scripts/workflow/check.py` (or wherever the agnostic runner lives). *Found by TEA during test verification.*
- **Confirmation** (non-blocking): The `testing-runner` session-stomp bug filed in round-1 has now stayed quiet across rounds 1, 2, 3, plus this verify run (four clean invocations). Risk seems contained but the underlying framework question remains open. *Found by TEA during test verification.*

**Handoff:** To Reviewer (Granny Weatherwax) for round-3 code review

I'm Igor. Teht patient'th vital thigns are thtable. The doctor — Ponder — and the inventor — Leonard — both thigned off. Now Granny gets the final cackle.

---

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 | N/A — tests 40/40 GREEN, 0 code smells |
| 2 | reviewer-edge-hunter | Yes | findings | 3 (1 medium, 2 low) | confirmed 1, downgraded 1, deferred 1 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 1 (medium) | dismissed 1 (theoretical only — git cannot emit the shape) |
| 4 | reviewer-test-analyzer | Yes | findings | 8 (2 high, 4 medium, 2 low) | confirmed 3, deferred 4, dismissed 1 |
| 5 | reviewer-comment-analyzer | Yes | findings | 3 (all high confidence) | confirmed 2, deferred 1 (pre-existing) |
| 6 | reviewer-type-design | Yes | findings | 4 (1 high, 2 medium, 1 low) | confirmed 1 (deferred per TEA), deferred 2 (architectural/pre-existing), downgraded 1 |
| 7 | reviewer-security | Yes | findings | 1 (low) | confirmed 1 (defense-in-depth, not exploitable) |
| 8 | reviewer-simplifier | Yes | findings | 3 (2 medium, 1 low) | confirmed 2, downgraded 1 |
| 9 | reviewer-rule-checker | Yes | findings | 2 (both high — same line, two rule angles) | confirmed 1 |

**All received:** Yes (9 of 9 returned, 8 with findings)
**Total findings:** 7 confirmed, 4 deferred (with rationale), 4 dismissed/downgraded (with rationale)

---

## Rule Compliance (python.md + SOUL.md)

The rule-checker enumerated all 13 numbered checks in `gates/lang-review/python.md` plus 3 SOUL.md cross-cuts. 14 of 16 rules are fully compliant; rules #6 (test quality) and #13 (fix-introduced regressions) each carry one violation — the same line, two angles.

| Rule | Status | Notes |
|------|--------|-------|
| #1 Silent exceptions | Pass | All `except` clauses catch specific types; errors surface via result tuples |
| #2 Mutable defaults | Pass | All 12 function signatures use `None` defaults with in-body materialisation |
| #3 Type annotations | Pass (borderline) | Public surface fully annotated. `dict[str, Any]` for commit records lacks the explanatory comment §3 prefers — see TYPE finding below. Sprint YAML's `Any` is structurally forced (free-form YAML); not a violation. |
| #4 Logging | N/A | Module imports neither `logging` nor `structlog` — rule scope does not apply |
| #5 Path handling | Pass | `pathlib.Path` throughout; `encoding='utf-8'` on all `write_text`; no string concat |
| #6 Test quality | **Fail (1 violation)** | `tests/python/test_151_5_staleness_preflight.py:1773` — see [TEST] finding below |
| #7 Resource leaks | Pass | No `open()`; no `requests`/`sqlite3`/`Lock` — nothing to leak |
| #8 Unsafe deserialization | Pass | No pickle/eval; all `subprocess.run(shell=False)` |
| #9 Async pitfalls | N/A | Module is fully synchronous |
| #10 Import hygiene | Borderline (deferred) | No star imports / no circular imports. Missing `__all__` is the round-2 [LOW] TEA explicitly deferred — see [TYPE] finding |
| #11 Input validation | Pass | start_date shape, list-element types, root-slash path all validated at boundary; user-controlled inputs flow as argv |
| #12 Dependency hygiene | N/A | Diff does not touch `pyproject.toml` |
| #13 Fix-introduced regressions | **Fail (1 violation)** | The vacuous assertion at test:1773 is a fresh round-3 introduction of the §6 pattern — same line, meta-check angle |
| SOUL.md §1 Fix-the-system | Pass | Round 3 closes 5 silent-degradation paths in pipeline-detected code |
| SOUL.md §10 Return Results, Don't Throw | Pass (envelope shape borderline) | All error paths return `_result(success=False, ...)`. Envelope is flat (not nested under `data:`) — pre-existing module shape; see [TYPE] finding |
| SOUL.md §13 Excellence Over Optimization | Pass | No validation skipped for token economy; all 8 boundary checks present |

---

## Reviewer Findings (confirmed)

### [MEDIUM] [TEST][RULE] Vacuous secondary assertion in `test_long_title_does_not_stall_preflight`

`tests/python/test_151_5_staleness_preflight.py:1773`

```python
assert result.get("success") in (True, False), (
    "result must be a structured dict regardless of input shape; "
    f"got {result}"
)
```

The comment promises a structural check ("result must be a structured dict regardless of input shape") but the assertion only verifies that `success` is a bool. It would technically catch `success` being absent or set to `None`, but it does not enforce the stated structural contract. Two subagents flagged this independently at high confidence; rule-checker called it out under both python.md §6 (test quality) and §13 (fix-introduced regression). The primary assertion in the same test (`elapsed < 2.0`) is sound and catches the real ReDoS regression — so the test's biting tooth is intact, but this redundant tooth doesn't bite. **Severity is MEDIUM, not HIGH, because the test still catches its primary target.**

The irony: round-2 was rejected partly for vacuous tests; round-3 introduces another. Defer to a one-line follow-up commit on this branch before SM finish: replace with `assert result.get("status") == "skipped"` (matches the test's setup — pathological title, no extension match → no inferable surface → skipped) or `assert isinstance(result, dict) and "success" in result`.

### [MEDIUM] [DOC] Stale module-level comment contradicts the round-3 reshape

`pennyfarthing-dist/src/pf/sprint/staleness.py:48-53` (the comment block above `_COMMIT_RECORD_SEP`)

> "Within each NUL-separated chunk the format string output is followed by `\n` then the file list (newline-separated under `--name-only`)."

Under `git log -z`, the file list is **NOT** newline-separated per commit — each file is its own NUL-terminated token (and round-3's `_parse_git_log` reshape is built on exactly that fact). This comment was correct for the no-`-z` shape; round-2 already used `-z` but the comment was carried forward. Round-3's reshape made it actively misleading because the new code's correctness depends on the OPPOSITE of what this comment claims.

Fix: rewrite to "Under `-z` each file is a separate NUL-separated token; the first file token is glued to the format-output by `\n`, subsequent files arrive as bare tokens." This is the exact contract the new `_parse_git_log` implements.

### [LOW] [DOC] `_parse_git_log` docstring contradicts its own inline comment

`pennyfarthing-dist/src/pf/sprint/staleness.py:516` (docstring) vs `:552` (inline comment)

Docstring says: "subsequent files arrive as their own bare NUL-separated tokens with no leading `\n`."
Inline comment 36 lines later says: "Strip any leading newline defensively (some git versions add one, others do not)."

Pick one. If the leading newline is impossible, drop the `lstrip("\n")` and the comment. If it's possible, the docstring should hedge.

### [MEDIUM] [TEST][RULE] Missing wildcard-pattern test for `_path_matches`

`pennyfarthing-dist/src/pf/sprint/staleness.py:420-422`

```python
if "*" in surface_path or "?" in surface_path:
    return fnmatch.fnmatch(commit_file, surface_path)
```

Confirmed by grep: no test in the suite contains a `*` or `?` in a surface path that reaches `_path_matches`. The fnmatch branch is **dead from the suite's perspective** — a regression that removed the branch (e.g., `if False:`) would pass all 40 tests. The shell-injection test uses `foo.py; rm -rf /` which has no glob meta. Round 1/2/3 didn't add a wildcard fixture either; this is a coverage gap inherited from the original RED.

Fix: one direct unit test in `TestPathMatchingHelper`, e.g.,
```python
assert _path_matches("src/pf/sprint/work.py", "src/**/*.py") is True
assert _path_matches("docs/readme.md", "src/**") is False
```

### [LOW] [TYPE][RULE] Missing `__all__` (TEA-deferred, accepted)

`pennyfarthing-dist/src/pf/sprint/staleness.py` module level

python.md §10 requires `__all__` on public modules. Module exports `check_story_staleness` and `staleness_cli`. TEA flagged as deferred [LOW] in round-2 review_findings and explicitly held out of round-3 RED scope. Architect accepted the deferral. Granny accepts the chain. Add to follow-up cleanup (one line):
```python
__all__ = ["check_story_staleness", "staleness_cli"]
```

### [LOW] [TYPE] `dict[str, Any]` for commit records lacks §3 comment

`pennyfarthing-dist/src/pf/sprint/staleness.py:72, 327, 528, 534`

The commit-record dict has a fully-known shape (hash, short_hash, date, subject, files, files_overlap). python.md §3 says "Any only with comment". A `TypedDict` would be ideal; a one-line comment justifying `Any` is the minimum. Defer to a typing-pass follow-up — not blocking.

### [LOW] [SIMPLE] `_resolve_paths` retains a now-redundant filter

`pennyfarthing-dist/src/pf/sprint/staleness.py:367`

```python
return [str(p) for p in explicit if isinstance(p, str) and p]
```

After the round-3 boundary check at line 171–185 rejects non-string entries, `_resolve_paths` cannot receive a bad list via `check_story_staleness`. The internal filter is now dead for the validated path. Defense-in-depth, but inconsistent with the "no silent filtering" principle the boundary check enforces. Either remove the filter (boundary owns validation) or add an `assert all(isinstance(p, str) and p for p in explicit), "expected pre-validated list"`. Defer.

---

## Reviewer Findings (downgraded / deferred)

### [LOW] [EDGE][SEC] start_date regex permits impossible dates (downgraded MEDIUM → LOW)

`pennyfarthing-dist/src/pf/sprint/staleness.py:124`

Edge-hunter, simplifier, and security all flagged `r"\d{4}-\d{2}-\d{2}.*"` accepts `9999-99-99`-shaped values. Security additionally noted the trailing `.*` allows arbitrary suffix (defense-in-depth gap, not exploitable due to `shell=False`). Architect explicitly addressed this in spec-check: "Stricter calendrical validation is out-of-scope for this round" with a follow-up suggested. Granny defers to the architect's call — the boundary intent (catch free-text dates) is met; the residual silent-clean on calendrically-invalid dates is a known follow-up, not a round-3 regression. Recommended follow-up: `datetime.date.fromisoformat(start_date_str[:10])` in a try/except, plus anchoring the regex with `$` or `(T...)?$` to close the suffix window.

### [LOW] `bounded` named local could be inlined (style — accepting as-is)

Simplifier suggestion. The named local makes the intent slightly clearer in tandem with the comment; inlining would also be defensible. Author's-prerogative call — accepting.

### [LOW] `_HASH_RE` premature abstraction (style — accepting as-is)

Simplifier flagged single-use module constant. Symmetric with `_PATH_HEURISTIC_RE` and `_COMMIT_RECORD_SEP` (both module-level, single-use). Consistency wins. Accepting.

### [LOW] [EDGE] `_HASH_RE` matches lowercase only (downgraded — git default is lowercase)

`pennyfarthing-dist/src/pf/sprint/staleness.py:47`

Edge-hunter's hypothetical: some older git builds output uppercase `%H`. Modern git (≥2.0) produces lowercase consistently. Defense-in-depth fix is one character (`[0-9a-fA-F]`); accept as a future-proofing observation but not blocking.

### Pre-existing (not introduced by round 3 — defer to follow-up story)

| Finding | Source | Disposition |
|---------|--------|-------------|
| `_print_human_summary` hardcodes `origin/` prefix even when local ref was used | comment-analyzer | Pre-existing in round-1 code; new follow-up story to expose `ref_used` in the result dict and print that |
| SOUL.md §10 envelope flat (no `data:` nesting) | type-design | Pre-existing module shape; refactor would touch all 9 callers — separate story |
| `_find_story` `standalone_stories` branch untested | test-analyzer | Pre-existing; coverage gap in original RED |

### Dismissed

| Finding | Source | Tag | Rationale |
|---------|--------|-----|-----------|
| `_parse_git_log` orphan-token silent drop | silent-failure-hunter (medium confidence) | [SILENT] | Git cannot emit a file token before its header — the token order in `git log -z --name-only` is fixed by git itself, not configurable. Defensive code (`current is not None` guard at `staleness.py:554`) is correct; the dismissed concern requires a malformed git binary, not a realistic input. |

---

## Devil's Advocate

Let me argue this code is broken.

**The whole story exists to prevent silent-clean false-negatives.** Round 3's boundary validations close five silent-degradation paths — but the start_date regex `\d{4}-\d{2}-\d{2}.*` LEAVES one open: feed it `9999-99-99` and it passes the validation, flows into `git log --since=9999-99-99`, which interprets as "since this far-future date" and returns no commits. **`status: clean`.** The very anti-pattern the story exists to prevent. Three independent subagents flagged this. Architect calls it "deferred follow-up." But the round-2 verdict rejected on similar "silent-clean residue" grounds — what makes this one OK?

**Counter:** the spec source for round-3 was the round-2 reviewer findings table. The round-2 verdict pinned "free-text dates" — `not-a-date`. It did not pin calendrically-invalid dates. The architect, who owns spec-check, ruled this out of scope explicitly. If round-4 were to be opened on this finding, every silent-degradation path that exists in any module touched anywhere in the repo could justify a round. The line is drawn at "what was specifically reviewer-flagged." Granny accepts that line — but flags it visibly so the next reviewer knows it's pending.

**The vacuous assertion is more troubling than I'm making it.** Round-2 was rejected for vacuous tests. Round-3 fixes those AND introduces a new one. The pattern is "TEA writes weak secondary assertions when they think the primary one is sufficient." If we approve here, the pattern continues. Every future TEA round will carry one weak assertion that "doesn't really matter because the primary is sound." That's how vacuous tests propagate.

**Counter:** the vacuous assertion's bite depends on context. If `result.get("success")` returned None on a dict-shape failure, this assertion catches it. The §6 rule's plain-text patterns (`assert True`, `assert result`) don't include this exact form — it's weak, not vacuous in the §6 sense. Still, "weak when the comment promises strong" is real. Required follow-up: replace before merge.

**What about the multi-file commit parser reshape?** Round-2 had the parser silently dropping files; round-3 reshapes the header detection. Could the new shape be wrong? The new code says: "if 3 pipe-fields AND first looks like a SHA, it's a header." A pathological case: a file path token of exactly 40 lowercase hex chars with two pipes in it. Possible? Yes, in theory. Likely? `[0-9a-f]{40}|x|y` as a filename. This requires a filename containing a `|`. Git allows this. So a malicious or unusual repo with file `0123456789abcdef0123456789abcdef01234567|x|y` would be misclassified as a header by `_parse_git_log`. The probability is essentially zero in practice. **Granny notes:** this is not blocking, but a comment explaining the assumption ("file paths cannot contain pipes in the projects we care about") would help future maintainers. Defer to the type-pass follow-up.

**What about race conditions?** None — module is fully synchronous, no shared state.

**What about resource leaks?** None — no `open()`, no connection pools.

**What about the test suite's flakiness?** test-analyzer flagged the 2.0s ReDoS threshold. On a contended CI machine it could fail spuriously. But: the unfixed measurement is 30s and the fixed measurement is ~50ms. The threshold has 40x safety margin. Fine in practice.

**Net devil's advocate verdict:** Two real concerns survive — start_date residual and the vacuous assertion. Both are explicitly contained: architect deferred the first, the test's primary assertion catches its target. APPROVED with required follow-up commit before SM finish.

---

## Reviewer Assessment

**Verdict:** APPROVED

**Round-3 contract closed:** All 8 round-2 findings (3 HIGH, 5 MEDIUM) closed cleanly. 40/40 staleness tests passing; wall time 32.85s → 3.59s.

### Findings Summary by Specialist Tag

Cross-reference of confirmed/deferred/dismissed findings to their originating subagent (full detail in `## Reviewer Findings (confirmed)` and `## Reviewer Findings (downgraded / deferred)` above):

- **[EDGE]** edge-hunter — start_date impossible-date residue (downgraded LOW, deferred per architect); `_HASH_RE` lowercase-only (LOW, accept); `_resolve_paths` dead-code filter (LOW, defer)
- **[SILENT]** silent-failure-hunter — `_parse_git_log` orphan-token concern (dismissed: git cannot emit that token order; defensive guard at `staleness.py:554` is correct)
- **[TEST]** test-analyzer — vacuous secondary assertion at `tests/python/test_151_5_staleness_preflight.py:1773` (MEDIUM, follow-up); missing wildcard test for `_path_matches` (MEDIUM, follow-up); other gaps deferred to follow-up
- **[DOC]** comment-analyzer — stale module comment at `staleness.py:48-53` (MEDIUM, follow-up); `_parse_git_log` docstring vs inline comment contradiction (LOW, follow-up); `_print_human_summary` "origin/" hardcode (deferred — pre-existing)
- **[TYPE]** type-design — missing `__all__` (LOW, deferred per TEA); `dict[str, Any]` lacks §3 comment (LOW, defer to typing pass); flat envelope shape (deferred — pre-existing module shape); `Literal["clean"|...]` for status (low confidence, accept)
- **[SEC]** security — start_date regex permits arbitrary suffix (LOW, defense-in-depth, not exploitable due to `shell=False`; same line as the EDGE finding)
- **[SIMPLE]** simplifier — `bounded` named local (LOW, accept); `_HASH_RE` premature abstraction (LOW, accept — symmetric with `_PATH_HEURISTIC_RE`); `datetime.date.fromisoformat()` over regex (overlaps with EDGE finding)
- **[RULE]** rule-checker — confirms vacuous assertion as the single project-rule violation (python.md §6 + §13 — same line as the TEST finding); 14 of 16 rules fully compliant


**Data flow traced:** `sprint.start_date` (YAML) → `re.fullmatch` shape check (line 124) → `f"--since={since}"` argv element (line 488) → `subprocess.run(shell=False)` (line 489). Safe because: shape check rejects free-text dates; argv form rules out shell injection; impossible calendar dates flow through git which silently no-matches them (residual silent-clean, deferred per architect).

**Pattern observed:** Round-3 introduces `_HASH_RE`-based header detection in `_parse_git_log` — keys on token shape rather than the leading-`\n` accident. Symmetric with `_COMMIT_RECORD_SEP` and `_PATH_HEURISTIC_RE` (`pennyfarthing-dist/src/pf/sprint/staleness.py:46-55`). Robust to subjects containing pipes.

**Error handling:** Every error path returns `_result(success=False, status='error', ...)` per SOUL.md §10. No raises on the public surface. `subprocess` errors caught specifically as `(FileNotFoundError, OSError)` and surfaced via tuple-return (`pennyfarthing-dist/src/pf/sprint/staleness.py:441-450, 488-497`).

**Required follow-up commit before SM finish (one short patch on this branch):**
- Replace `tests/python/test_151_5_staleness_preflight.py:1773` vacuous assertion with `assert result.get("status") == "skipped"` (matches the no-extension-match contract the test already constructs)
- Update `pennyfarthing-dist/src/pf/sprint/staleness.py:48-53` module comment to match the `-z` reality (`-z` makes file tokens NUL-separated, not newline-separated)

**Recommended for a separate follow-up story (not blocking):**
- Add wildcard test for `_path_matches` (covers the fnmatch branch)
- Tighten start_date with `datetime.date.fromisoformat()` to close the calendrically-invalid silent-clean residue
- Add `__all__` per python.md §10
- TypedDict for commit records per python.md §3
- Update `_parse_git_log` docstring vs inline comment contradiction (pick one)
- Address `_print_human_summary` "origin/" hardcode (pre-existing)

**Handoff:** To SM (Captain Carrot) for finish-story, after the two required follow-up patches land.

**Delivery Findings — Reviewer**

### Reviewer (audit)
- **Improvement** (non-blocking): The pattern of "round-N introduces a weak assertion despite round-N-1 having been rejected for weak assertions" suggests a TEA-side checklist gap. Self-check (assessment template Phase C) caught nothing this round. Worth tightening the §6 self-check rubric: "every secondary assertion must have a contract distinct from the primary, OR be removed." Affects `pennyfarthing-dist/agents/tea.md` (Phase C self-check). *Found by Reviewer during code review.*
- **Question** (non-blocking): `pf check` is referenced by `pennyfarthing-dist/agents/tea.md` (verify Step 7 "Regression Detection") but is not a registered `pf` command — TEA's verify phase fell through to `just test` with no harm. Either implement `pf check` or update the reference. Already flagged by TEA in the verify Delivery Findings; Granny confirms.
- **Confirmation** (non-blocking): The Architect's spec-check assessment is unusually thorough — every round-2 row explicitly mapped to its round-3 RED test contract with a verdict. This is what the gate was meant to produce. Worth referencing as a template in `pennyfarthing-dist/agents/architect.md`. *Found by Reviewer during code review.*

I am Granny Weatherwax. I see what's there and I see what isn't. The patient lives. Two stitches need tightening before the wound closes — Ponder, fix them, then Carrot can take this to finish. Tell Igor he did good work this round, but tell him "not vacuous" requires more than "I checked the box."