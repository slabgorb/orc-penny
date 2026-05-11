---
story_id: "152-1"
jira_key: null
epic: "152"
workflow: "tdd"
---
# Story 152-1: Remove MSSCI hardcoding — config-driven project key with fail-loud, scrub templates and docs

## Story Details
- **ID:** 152-1
- **Jira Key:** None (local-only sprint)
- **Epic:** 152 (Jira isolation — config-driven project keys)
- **Workflow:** tdd
- **Branch:** feat/152-1-remove-mssci-hardcoding
- **Stack Parent:** none
- **Points:** 5
- **Priority:** p1

## Expanded Scope Context

The initial story scope is to:
1. Remove MSSCI hardcoding from framework — implement config-driven project key support
2. Implement fail-loud behavior (no silent defaults, no implicit fallbacks)
3. Scrub MSSCI references from templates and documentation

**User has expanded scope to include scrubbing references to:**
- **"1898"** — Investigate and remove (likely company brand/historical reference)
- **MSSCI Jira project key** — All hardcoded instances
- **Comments referencing the company's Jira board** — Strip professional company references
- **Other professional company references** — Full sweep for context isolation

This expanded context ensures TEA designs tests covering the broader refactoring scope, and Dev implements with awareness of the full cleanup required.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-05-11T20:40:58Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-05-04 | - | - |

## Sm Assessment

**Story:** 152-1 — Remove MSSCI hardcoding, fail-loud config-driven project keys, scrub templates/docs.

**Scope confirmed with user:** Beyond the core MSSCI removal, expand sweep to:
- Hardcoded `MSSCI` Jira project key references in code, configs, templates, docs
- "1898" references (likely company brand/numeric identifier — investigate before removing; could be year, version, or brand)
- Comments referencing the company's Jira board, workflows, or internal processes
- Any other professional-company-specific identifiers leaking into the open framework

**Repo:** `pennyfarthing/` (framework, not orchestrator). Gitflow → PR targets `develop`.

**Branch:** `feat/152-1-remove-mssci-hardcoding` created off `develop`.

**Workflow:** tdd (5 pts, p1) — TEA designs failing tests before any code.

**Out of scope (stays in orchestrator):** Sprint YAML history, archived sessions, planning docs that already shipped — these are local artifacts in this repo and don't redistribute. Framework-side scrub only. If TEA finds a leak path that *would* redistribute (e.g. a template, persona, or sprint-init asset), include it.

**Fail-loud requirement:** No silent fallbacks. If config is missing the project key, framework must error with a clear message — never default to MSSCI or any other key.

**Notes for TEA:**
- Inventory first: rg over `pennyfarthing/pennyfarthing-dist/` and `packages/` for `MSSCI`, `1898`, company name patterns. Distinguish file types: code vs benchmark fixtures vs test data vs personas.
- Test fixtures referencing MSSCI (e.g. `test_151_3_sharded_update_and_finish_loud.py`) may be intentional — assess case-by-case.
- Personas with embedded numbers (e.g. `norns-55231.png`) are hash suffixes, not company refs — leave alone.
- Benchmark `pipeline.yaml` results capturing real runs may legitimately contain MSSCI as historical data; user can decide.

## TEA Assessment

**Tests Required:** Yes
**Phase:** finish
**Status:** RED (5 failing — confirmed by testing-runner)

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py` — 4 tests, walks the framework repo and asserts absence of forbidden tokens.
- `pennyfarthing-dist/src/pf/tests/test_152_1_jira_project_fail_loud.py` — 3 tests, pins the contract that Jira operations must fail loudly when no project key is configured.

**Tests Written:** 7 tests covering the story's three implicit ACs.

| AC (implied) | Test(s) | Status |
|---|---|---|
| Remove MSSCI hardcoding from framework redistributables | `test_no_corporate_jira_key_in_framework_redistributables` | failing — 31 occurrences in 2 test fixtures |
| Remove 1898 (company year) from framework redistributables | `test_no_company_brand_number_in_framework_redistributables` | failing — 13 occurrences across docs/tests |
| Remove `1898&co` brand literal from framework redistributables | `test_no_company_brand_string_in_framework_redistributables` | passing — forward-looking guard |
| Walk-sanity check (avoid vacuous pass) | `test_skip_dirs_actually_exist_in_walk` | passing |
| Jira epic creation fails loud when project key empty | `test_build_epic_payload_fails_loud_when_project_unconfigured` | failing — payload builder accepts empty |
| Jira story creation fails loud when project key empty | `test_create_story_in_jira_fails_loud_when_project_unconfigured` | failing — API call would proceed |
| Resolution distinguishes unset from empty | `test_jira_project_resolution_distinguishes_unset_state` | failing — both return `""` silently |

**Self-check (vacuous-test scan):** All 7 tests have meaningful assertions tied to observable behavior. No `assert True`, no `let _`, no `is_none()`-on-always-None patterns. Forbidden tokens are constructed by string concatenation (`"MS" + "SCI"`, `"18" + "98"`, `"1898" + "&co"`) so the test file itself does not pollute its own scan.

**Notes for Dev (Ponder Stibbons):**
1. **Test fixture renames** (MSSCI → generic): `test_archive_epic_field_validation.py` and `test_151_3_sharded_update_and_finish_loud.py` use `MSSCI-17079`/`MSSCI-17082` etc. as test data. Replace with a generic key like `PROJ-17079` — the test logic is project-key-agnostic.
2. **Doc rewrites** (1898 → 2898): `docs/adr/0022-python-wheelhub-replacement.md` and `pennyfarthing-dist/guides/tui.md` reference port `1898`. The live code already uses port `2898` (see `pennyfarthing-dist/src/pf/hooks/__init__.py:36`); update the docs to match reality.
3. **Test fixture port updates**: `test_frame_server.py` and `test_frame_websocket.py` use the literal port `1898` in fixtures. Replace with `2898` (or with whatever `DEFAULT_FRAME_PORT` is at the time) to match the live default.
4. **Fail-loud implementation**: The cleanest path is a `require_jira_project()` helper in `pf/jira/client.py` that raises a `JiraConfigError` (or similar) with a message like `"Jira project key not configured. Set jira.project in .pennyfarthing/config.local.yaml or export JIRA_PROJECT."`. Have `build_epic_payload`, `create_story_in_jira`, and the `JIRA_PROJECT`-using payload builders call it before they reference the value.
5. **Import-time safety**: Do NOT make `pf.jira.client` raise at import — the framework must work in projects with no Jira at all. Fail at point of use, not at import.
6. **Leave benchmarks/results/** alone: The user has the option to keep historical pipeline run captures intact; the hygiene tests scan them and will fail until they're cleaned. If preservation is desired, gate the test on a path-exclusion the user opts into. **(Question for user — see Delivery Findings.)**

**Handoff:** To Dev (Ponder Stibbons) for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Phase:** finish
**Status:** GREEN — 198/198 passing on touched files (4 hygiene + 3 fail-loud + 191 pre-existing in modified fixtures)

**Files Changed (framework repo, branch `feat/152-1-remove-mssci-hardcoding`):**

Code:
- `pennyfarthing-dist/src/pf/jira/client.py` — added `JiraConfigError`, `require_jira_project()`; `_resolve_jira_config` now returns `(None, None)` for unset.
- `pennyfarthing-dist/src/pf/jira/epic.py` — `build_epic_payload` calls `require_jira_project` before emitting payload.
- `pennyfarthing-dist/src/pf/jira/create.py` — `create_story_in_jira` returns `{success: False, error: ...}` when project key unset; never reaches `get_client()`.

Tests + scrub:
- `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py` — added `.session` to SKIP_DIRS (gitignored runtime artifact).
- `pennyfarthing-dist/src/pf/tests/test_151_3_sharded_update_and_finish_loud.py` — `MSSCI-` → `PROJ-` in fixtures and docstring.
- `pennyfarthing-dist/src/pf/tests/test_archive_epic_field_validation.py` — `MSSCI-` → `PROJ-` in fixtures.
- `pennyfarthing-dist/src/pf/tests/test_frame_server.py` — port literal `1898` → `3898` (fictional port for tests; AC4 overwrite test now uses 3898 + 2898 as the two distinct values).
- `pennyfarthing-dist/src/pf/tests/test_frame_websocket.py` — port literal `1898` → `2898` (matches live default).
- `pennyfarthing-dist/src/pf/tests/test_jira_package.py` — pre-existing `test_build_epic_payload` and `test_create_epic_dry_run` updated to monkeypatch `JIRA_PROJECT="PROJ"`.

Docs:
- `pennyfarthing-dist/guides/tui.md` — `1898` → `2898` (live default); custom-port example bumped to `3898` to keep the example distinct from default.
- `docs/adr/0022-python-wheelhub-replacement.md` — diagrams updated to port `2898`; parallel-running paragraph rewritten to use `2898`/`2899` instead of `1898`/`2898`.

**Branch:** `feat/152-1-remove-mssci-hardcoding` pushed to origin.

**Self-review:**
- [x] Code is wired (the helpers are called from the two payload builders the test pinned)
- [x] Code follows project patterns (`{success, error}` return, no exceptions thrown to callers; module-level constants preserved for backward-compat)
- [x] All ACs (per Igor's tests) met — 7/7 hygiene + fail-loud tests pass
- [x] Error handling implemented — clear `JiraConfigError` message naming both config paths

**Pre-existing unrelated failures in broader suite (not regressions):**
- `test_143_9_tdd_cycle_e2e.py` — 8 failures about reviewer-rule-checker subagent table; unrelated.
- `test_148_23_reviewer_gate_clarity.py` — 4 failures; unrelated.
- `test_peloton_pane_layout.py` — 2 failures (tmux env); unrelated.
- `test_pypi_packaging.py` — 1 failure + 4 errors (wheel build env); unrelated.
- Verified pre-existing by stashing and re-running on develop's HEAD (27 failed without GREEN edits, 21 failed with — confirming all 21 are pre-existing and my changes only reduced failures).

**Handoff:** To Reviewer (Granny Weatherwax) for adversarial review.

## Architect Assessment (spec-check)

**Spec Alignment:** Drift detected — all drift is intentional and either deferred or accepted (no Hand-back-to-Dev required).
**Mismatches Found:** 4

The spec-check gate passed structurally (Dev Assessment present, ACs accounted for, deviations subsections well-formed). The substantive mismatches below reflect known scope decisions, not implementation defects.

### M1 — Fail-loud contract is partial across the Jira CLI

- **Spec:** SM Assessment §"Fail-loud requirement" — *"If config is missing the project key, framework must error with a clear message — never default to MSSCI or any other key."* Phrased as a global property of the framework.
- **TEA tests pinned:** Only `build_epic_payload` and `create_story_in_jira`.
- **Code:** `require_jira_project()` is wired only at those two sites. `pf/jira/reconcile.py:114,139` (JQL queries) and `pf/jira/cli.py:164,344` (assignment payload) still reference `JIRA_PROJECT` directly and will silently emit malformed queries / payloads when the project key is unset.
- **Category:** Missing in code · **Type:** Behavioral · **Severity:** Major (if those CLI paths are exercised without configured project)
- **Recommendation:** **D — Defer.** Per spec authority hierarchy, the session scope (highest authority) called for fail-loud broadly, but TEA's tests narrowed the contract to two functions, and Dev correctly implemented to the test. Migrating all `JIRA_PROJECT` callers without test coverage is scope creep. Dev already logged this as a non-blocking Question for a follow-up story; that is the correct disposition.

### M2 — Orchestrator-side leakage out of scope but worth a follow-up

- **Spec:** User asked to "scrub all references to my professional company". SM Assessment carved out *"Sprint YAML history, archived sessions, planning docs that already shipped"* as out of scope.
- **Code (in scope):** Framework repo cleanly scrubbed — hygiene tests green.
- **Code (out of scope, not addressed):** Orchestrator repo retains `1898 & Co` in `references.bib` (~22 BibTeX entries) and `docs/comparisons/bmad-vs-pennyfarthing.md` (5 mentions); `1898` as a port-convention identifier in `sprint/planning/bikerack-extraction-{epics,proposal}.md`.
- **Category:** Missing in code · **Type:** Behavioral · **Severity:** Major if orchestrator is or becomes public; Minor otherwise
- **Recommendation:** **D — Defer.** Cross-repo work needs its own branch and PR (different repo, different gitflow). Story 152-1's branch is in `pennyfarthing/`. Dev already logged this as a blocking-for-future-story Question. Recommend creating a sibling story (e.g. 152-3) under epic 152.

### M3 — Module-level `JIRA_PROJECT` constant preserved as string for backward compat

- **Spec:** Test 3 (`test_jira_project_resolution_distinguishes_unset_state`) requires that callers can distinguish unset from configured-empty.
- **Code:** `_resolve_jira_config()` returns `(None, None)` when unset (good), but the module-level `JIRA_PROJECT: str = _resolved_project or ""` collapses None back to `""` for legacy importers (`reconcile.py`, `cli.py`, `__init__.py` re-exports). The strict helper `require_jira_project()` is the only fail-loud path; direct imports of the constant retain the silent-empty behavior.
- **Category:** Different behavior (partial migration) · **Type:** Architectural · **Severity:** Minor
- **Recommendation:** **A — Update spec / accept.** Backward compat is the right call here — callers that read `JIRA_PROJECT` as a string today (e.g. JQL string interpolation in reconcile.py) would otherwise need a synchronized refactor outside this story's scope. Captured by M1's deferred follow-up.

### M4 — ADR-0022 historical port number rewritten

- **Spec:** Scrub `1898` references from framework redistributables.
- **Code:** `docs/adr/0022-python-wheelhub-replacement.md` had three references to port `1898` describing the legacy Node.js WheelHub server's actual historical port. Dev replaced them with `2898` (current default), making the ADR's historical narrative slightly inaccurate (it now says the Node.js server was on 2898, but it was on 1898 at the time of that ADR). The parallel-running paragraph was rewritten to use `2898`/`2899` instead of `1898`/`2898`.
- **Category:** Different behavior (historical record) · **Type:** Cosmetic / Documentation · **Severity:** Minor
- **Recommendation:** **A — Accept.** The story's primary goal is removing the company-year leak; preserving exact historical accuracy in an internal port-number choice is much less important than scrubbing the brand reference. This is a deliberate trade-off, not an oversight.

### Decision

**Proceed to TEA verify phase.** No mismatch warrants Hand-back-to-Dev. The implementation aligns with the test-pinned contract and the in-scope portion of the session spec. The two Major-severity items (M1, M2) are deliberate scope boundaries with explicit follow-up paths.

**Reuse-first audit:** Implementation reuses existing patterns — `{success, error}` return shape, module-level config constants, monkeypatch-based test fixtures. The only new construct is `JiraConfigError` + `require_jira_project()`, which is the minimum surface required to satisfy Test 3's distinguishability contract. No new infrastructure introduced.

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed (198/198 touched-file tests pass after simplify)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 10 (changed Python code + tests; ADR + guide markdown excluded as documentation)

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 6 findings | 2 high (pre-existing ADF dup), 3 medium (test helper extraction, OTLP fixtures, channel constants — all pre-existing or low-priority), 1 low |
| simplify-quality | 1 finding | 1 high (error-handling-gap in `build_epic_payload` / `create_epic`) |
| simplify-efficiency | 10 findings | 3 high (1 pre-existing ADF dup, 1 pre-existing test parameterization, 1 pre-existing add_comment dup), 5 medium (pre-existing async/force/test layering), 2 low |

**Aggregated High-Confidence Findings:**

| # | Source | File | Issue | Disposition |
|---|--------|------|-------|-------------|
| H1 | reuse + efficiency | `pf/jira/create.py` + `pf/jira/epic.py` | `_build_adf_description` and inline ADF builder are duplicated | **Pre-existing.** Out of 152-1 scope; deferred to follow-up. |
| H2 | quality | `pf/jira/epic.py:65` + `create_epic:94` | `build_epic_payload` raises but `create_epic` doesn't catch — breaks result-dict contract | **Applied.** Added try/except in `create_epic` to convert `JiraConfigError` into `{success: False, error: str(e)}`. Matches `create_story_in_jira` pattern. |
| H3 | efficiency | `pf/jira/client.py:550` | `add_comment_sync` builds ADF inline, duplicates `_build_adf_description` | **Pre-existing.** Out of 152-1 scope; deferred. |
| H4 | efficiency | `tests/test_frame_server.py` | OTLP endpoint tests could be parametrized | **Pre-existing.** Out of 152-1 scope; deferred. |

**Applied:** 1 high-confidence fix (H2). Test suite re-verified — 198/198 pass.

**Flagged for Manual Review (medium confidence, story-introduced):**
- `tests/test_152_1_no_company_leakage.py::_find_offenders` (extractable to shared utility once a second hygiene test exists). Defer until there's a real second consumer.

**Noted (low confidence or pre-existing):**
- `_iter_text_files` uses rglob with manual filtering; clearer alternative exists. Acceptable for a one-off hygiene scan.
- Test helper regex pattern `_empty_project_error_pattern` could live in shared utilities. Single-use; not worth extracting now.

**Reverted:** 0.

**Overall:** simplify: applied 1 fix.

### Quality-Pass Gate

198/198 tests on the 10 touched files pass. The 21 pre-existing failures in unrelated files (test_143_9, test_148_23, test_peloton_pane_layout, test_pypi_packaging) are documented in the Dev Assessment as pre-existing on develop and not caused by 152-1's changes.

**Handoff:** To Reviewer (Granny Weatherwax) for adversarial review.

## TEA Assessment (re-RED, round 2)

**Phase:** finish (re-entry after Reviewer REJECT)
**Status:** RED — 2 newly failing tests, 7 strengthened/passing
**Round-Trip:** 1 of 3 (max)

**Test changes (two existing files, no new files):**
- `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py`
  - `test_no_corporate_jira_key_in_framework_redistributables` — added `ignore_case=True` to mirror the brand-string scan; currently FAILS because lowercase `mssci-00000` exists at `tests/python/test_sprint_story_command.py:93`.
  - `test_skip_dirs_actually_exist_in_walk` — now counts files specifically under `pennyfarthing-dist/` (asserts `> 10`) instead of the all-walk count `> 100`; closes the loophole where a mis-rooted walk could pass via files outside the redistributable tree. Currently passes.
  - Module docstring rewritten to mention all three forbidden tokens.

- `pennyfarthing-dist/src/pf/tests/test_152_1_jira_project_fail_loud.py`
  - `test_jira_project_resolution_distinguishes_unset_state` — REPLACED with two independent tests so neither can pass vacuously:
    - `test_jira_project_resolution_returns_sentinel_when_unset` — asserts the resolver returns `None` or raises (no fallback to `""`).
    - `test_jira_project_strict_helper_is_exposed` — asserts `require_jira_project` exists.
  - `test_create_epic_in_jira_fails_loud_when_project_unconfigured` — NEW; mirrors the existing `create_story_in_jira` test for the sibling function. Asserts both `client.search_issues_sync` (the JQL line `create.py:232`) and `client.create_issue_sync` (the payload line `create.py:267`) are short-circuited when `JIRA_PROJECT == ""`. Currently FAILS — both API methods are still attempted.
  - Module docstring + per-test docstrings rewritten to describe the implemented contract instead of the pre-fix bug.

| Reviewer Finding | Test | Status |
|------------------|------|--------|
| F1 — `create_epic_in_jira` unguarded | `test_create_epic_in_jira_fails_loud_when_project_unconfigured` | failing — short-circuits via `not sentinel_called["created"]` |
| F2 — MSSCI scan case-sensitive | `test_no_corporate_jira_key_in_framework_redistributables` | failing — `tests/python/test_sprint_story_command.py:93` matches |
| F3 — `distinguishable` shorts on helper | `test_jira_project_resolution_returns_sentinel_when_unset` + `test_jira_project_strict_helper_is_exposed` | both passing on current impl; either regression now fails its dedicated test |
| M4 — walk-sanity could pass on wrong root | `test_skip_dirs_actually_exist_in_walk` | strengthened, still passing |
| M-DOC — stale "Current behavior (the bug)" docstrings | (in-place rewrite) | docstrings now describe implemented contract |

**Self-check (vacuous-test scan):**
- `test_jira_project_resolution_returns_sentinel_when_unset`: asserts `project_value is None or project_value is False` — concrete, not a tautology. Includes early-return when `raised_on_resolve` because raising is also acceptable per contract.
- `test_jira_project_strict_helper_is_exposed`: asserts `hasattr(client_module, ...)` — single positive contract, not a disjunction that can short-circuit.
- `test_create_epic_in_jira_fails_loud_*`: dual sentinel checks (`searched`, `created`) prevent partial-pass via swallowed warnings; full result-object inspection for clear error message; pattern matches via `_empty_project_error_pattern()` not raw substrings.
- All assertions exercise observable behavior; no `assert True`, no truthy-only checks where value matters.

**Notes for Dev (Ponder Stibbons) — round 2 implementation list:**

Primary fixes (drive RED tests to GREEN):
1. **Add `require_jira_project` guard to `create_epic_in_jira`** in `pennyfarthing-dist/src/pf/jira/create.py`. Resolve the project key BEFORE the duplicate-search block (so the JQL at line 232 uses the validated key) and use the same resolved value at line 267. On `JiraConfigError`, `return {"success": False, "error": str(e)}`. Mirror exactly the pattern used in `create_story_in_jira` lines 110-113.
2. **Fix the lowercase MSSCI leak** at `tests/python/test_sprint_story_command.py:93`. Replace `"mssci-00000"` with a generic placeholder (e.g. `"proj-00000"` or whatever neutral key the surrounding fixture uses).

Secondary cleanups (Reviewer MEDIUM/LOW findings, sweep while in the area):
3. Strip whitespace in `require_jira_project`: change `if not value` to `if not (value and value.strip())` and `value = value.strip()` before return (`pf/jira/client.py:51`).
4. Handle null YAML cleanly: `jira_cfg = config.get("jira") or {}` (`pf/jira/client.py:35`) so a null-valued `jira:` key doesn't trip the bare except.
5. Add explanatory comment to the bare except: `except Exception:  # config is optional; Jira ops work without it` (`pf/jira/client.py:36`).
6. Add `Raises: JiraConfigError` clause to `build_epic_payload` docstring (`pf/jira/epic.py:41-49`).
7. Add `assert result["payload"]["fields"]["project"]["key"] == "PROJ"` to `test_jira_package.py::test_create_epic_dry_run`.
8. Optional: remove the unused `FORBIDDEN_*` string-concatenation trick (`SKIP_FILES` already excludes the test file from the walk).

**Out of scope for round 2** (logged as Reviewer follow-up; not blockers):
- `reconcile.py:114,139` and `cli.py:164,344` JIRA_PROJECT direct usage (Architect M1 deferral remains valid).
- `create_epic_in_jira` partial-failure surfacing (story-adjacent silent failure in child-story loop).
- Git history rewrite for MSSCI in past commit blobs (cross-cutting; user opt-in).

**Handoff:** To Dev (Ponder Stibbons) for round-2 GREEN.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (198/198 tests pass) | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 6 | confirmed 4 (F1 dup, F1 dup, F-strip, F-null), dismissed 2 (low-priority docstring + REPO_ROOT robustness) |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 5 | confirmed 3 (F1 create_epic_in_jira, partial-failure, hygiene-skip), dismissed 1 (corollary of F1), deferred 1 (writeback pre-existing) |
| 4 | reviewer-test-analyzer | Yes | findings | 4 | confirmed 3 (F3 distinguishable, dry_run-payload-assert, walk-sanity-coverage), dismissed 1 (positive-path covered elsewhere) |
| 5 | reviewer-comment-analyzer | Yes | findings | 8 | confirmed 5 (5 stale "Current behavior (the bug)" docstrings in fail-loud tests + module-docstring brand-bullet), dismissed 0, deferred 2 (ADR-0022 narrative — already accepted as Architect M4), confirmed 1 (test_152_1_no_company_leakage docstring missing 1898&co bullet) |
| 6 | reviewer-type-design | Yes | findings | 4 | confirmed 3 (F1 dup, bare-except-no-comment, F1 dup at line 232), dismissed 1 (require_jira_project optional/None — low) |
| 7 | reviewer-security | Yes | findings | 4 | confirmed 2 (F2 lowercase mssci leak, hygiene scan asymmetry), deferred 2 (git history rewrite, info-leak defense-in-depth) |
| 8 | reviewer-simplifier | Yes | findings | 4 | confirmed 1 (concat trick unnecessary because SKIP_FILES handles self), dismissed 3 (parametrize style, walk-sanity arbitrariness, dead re-resolve branch — all minor / future cleanup) |
| 9 | reviewer-rule-checker | Yes | findings | 4 | confirmed all 4 (rule #1 bare-except, rule #4 no-logging, rule #6 distinguishable-shorts, rule #13 fix-regression at create_epic_in_jira) |

**All received:** Yes (9 returned, 8 with findings)
**Total findings:** 11 confirmed (3 HIGH, 6 MEDIUM, 2 LOW), 7 dismissed (with rationale), 4 deferred

## Reviewer Assessment

**Verdict:** REJECTED

The story's two stated primary deliverables — (1) fail-loud Jira project key resolution, (2) scrub corporate identifiers from framework redistributables — are each incompletely realized in the same files Dev modified. A third blocker concerns a test that cannot detect the regression it claims to catch. The pipeline produced clean test output and a green check, yet missed a leak and missed an unguarded sibling — exactly the class of finding the framework's "prove the work" principle exists to prevent.

### Severity Table

| Severity | Issue | Location | Source | Fix Required |
|---|---|---|---|---|
| [HIGH] | `create_epic_in_jira` builds Jira payload and JQL query with raw `JIRA_PROJECT` constant; sibling function `create_story_in_jira` in same file was patched, this one was missed. Story's own fail-loud requirement violated. [SILENT][TYPE][EDGE][RULE] | `pennyfarthing-dist/src/pf/jira/create.py:232,267` | silent-failure-hunter, type-design, edge-hunter, rule-checker (4× convergent) | Wrap `JIRA_PROJECT` use in `require_jira_project(JIRA_PROJECT)` with `JiraConfigError` catch returning `{success: False, error: str(e)}`. Mirror the pattern from `create_story_in_jira` lines 110-113. Apply to BOTH the JQL search at line 232 AND the payload at line 267. |
| [HIGH] | Hygiene test's MSSCI scan is case-sensitive, missing the lowercase `mssci-00000` literal in `tests/python/test_sprint_story_command.py:93`. Real corporate-key leak survives the hygiene gate. Story's own scrub requirement violated. [SEC] | `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py:138` AND `tests/python/test_sprint_story_command.py:93` | security | (a) Pass `ignore_case=True` to the `_find_offenders` call for `FORBIDDEN_JIRA_KEY`, AND (b) replace `mssci-00000` in the assert with `proj-00000` (or whatever generic the surrounding fixture uses). Re-run the hygiene test — it must now fail until the assert string is fixed. |
| [HIGH] | Test `test_jira_project_resolution_distinguishes_unset_state`'s `distinguishable` boolean short-circuits on `has_strict_helper` — which is `True` simply because the helper exists. The test passes vacuously regardless of whether `_resolve_jira_config` actually returns `None` for unset; a regression that breaks the resolver while keeping the helper would not be caught. [TEST][RULE] | `pennyfarthing-dist/src/pf/tests/test_152_1_jira_project_fail_loud.py:175-185` (the `distinguishable = ...` block, around lines 176-181) | test-analyzer, rule-checker (2× convergent) | Either (a) split into two independent tests — one asserts `hasattr(client_module, 'require_jira_project')`, the other asserts `_resolve_jira_config()` returns `(None, None)` or raises in a clean env — or (b) remove `has_strict_helper` from the `distinguishable` OR-chain so the resolver's return value actually has to be checked. |
| [MEDIUM] | Stale docstrings in `test_152_1_jira_project_fail_loud.py` describe pre-fix behavior as "Current behavior (the bug)..." even though the fix is in this same commit. Five separate docstring locations contradict the implementation. [DOC] | `pennyfarthing-dist/src/pf/tests/test_152_1_jira_project_fail_loud.py:3,14,39,64,144` | comment-analyzer | Rewrite to describe what the code now does, not what it used to do. |
| [MEDIUM] | `_resolve_jira_config` has `except Exception:` with no comment and no logging — Python lang-review rules #1 and #4. The pattern is now load-bearing for the new fail-loud contract (a YAML parse error becomes invisible "no project key configured"). [SILENT][TYPE][RULE] | `pennyfarthing-dist/src/pf/jira/client.py:36` | type-design, rule-checker | Add an inline comment explaining intentional swallow, e.g. `except Exception:  # config is optional; Jira ops work without it`. If a logger is introduced anywhere in `pf/jira/`, add `logger.debug("config load failed: %s", exc)`. |
| [MEDIUM] | `require_jira_project` doesn't strip whitespace; a config value of `"  "` passes `if not value` and is returned as the project key, eventually appearing in payloads as `{"key": "  "}`. [EDGE] | `pennyfarthing-dist/src/pf/jira/client.py:51` | edge-hunter | Change to `if not (value and value.strip())`; assign `value = value.strip()` before return. |
| [MEDIUM] | `config.get("jira", {})` returns `None` (not `{}`) when YAML has `jira:` with a null value, then `jira_cfg.get("project")` raises `AttributeError`. The bare `except` rescues it but masks the malformed-config condition. [EDGE] | `pennyfarthing-dist/src/pf/jira/client.py:35` | edge-hunter | Change to `jira_cfg = config.get("jira") or {}` to handle null cleanly without relying on the broad except. |
| [MEDIUM] | `test_create_epic_dry_run` monkeypatches `JIRA_PROJECT="PROJ"` but doesn't assert the key reaches the returned payload — a regression that ignored the constant would still pass. [TEST] | `pennyfarthing-dist/src/pf/tests/test_jira_package.py:310-318` | test-analyzer | Add `assert result["payload"]["fields"]["project"]["key"] == "PROJ"`. |
| [MEDIUM] | Walk-sanity test asserts `len(visited) > 100` and `pennyfarthing-dist/` is_dir; the count could be satisfied by files OUTSIDE `pennyfarthing-dist/`, so a mis-rooted walk that skipped the dist tree would still pass. [TEST][EDGE] | `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py:148-159` | test-analyzer, edge-hunter | Replace the `> 100` count with a targeted count: `dist_files = [p for p, _ in _iter_text_files(REPO_ROOT) if "pennyfarthing-dist" in str(p)]` and `assert len(dist_files) > 10`. |
| [LOW] | `FORBIDDEN_*` string concatenation (`"MS" + "SCI"`) is unnecessary because `SKIP_FILES` already excludes the test file itself. [SIMPLE] | `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py:29-31` | simplifier | Optional cleanup: write the constants as plain strings; remove the comment about "Constructed to avoid self-match". |
| [LOW] | `build_epic_payload` docstring doesn't document the `JiraConfigError` raise — silent contract change for any external caller importing it directly. [DOC] | `pennyfarthing-dist/src/pf/jira/epic.py:41-49` | edge-hunter, comment-analyzer | Add `Raises: JiraConfigError` clause to the docstring. |

### Rule Compliance

Mapped to `pennyfarthing-dist/gates/lang-review/python.md` (13 numbered checks):

| Rule | Subject | Status |
|------|---------|--------|
| #1 Silent exception swallowing | `_resolve_jira_config` line 36 bare except, no comment, no log | **VIOLATION** [RULE] |
| #2 Mutable default arguments | All 5 changed function signatures use `None`/str/bool defaults | Compliant |
| #3 Type annotations at boundaries | All 6 new/modified public surfaces annotated correctly | Compliant |
| #4 Logging coverage and correctness | `pf/jira/client.py` imports no `logging` module; new error path emits no log | **VIOLATION** [RULE] |
| #5 Path handling | `pathlib.Path` + `read_text(encoding="utf-8")` in hygiene scan; no bare `open()` | Compliant |
| #6 Test quality | `test_jira_project_resolution_distinguishes_unset_state` shorts on `has_strict_helper`; `test_create_epic_dry_run` missing payload assertion; walk-sanity weakly proves coverage | **VIOLATION** [TEST][RULE] |
| #7 Resource leaks | `pathlib` write/read; no naked file handles | Compliant |
| #8 Unsafe deserialization | `yaml.safe_dump`; no `pickle.loads`, `eval`, `exec`, or `shell=True` | Compliant |
| #9 Async/await | No async functions added or modified | N/A |
| #10 Import hygiene | No star imports; one-directional import chain (epic/create → client) | Compliant |
| #11 Input validation at boundaries | `require_jira_project` validates non-empty; **but** `create_epic_in_jira` bypasses it at lines 232/267 | **VIOLATION** [SILENT][EDGE][TYPE][RULE] |
| #12 Dependency hygiene | No new deps; `pyproject.toml` constraints unchanged | Compliant |
| #13 Fix-introduced regressions | Fix applied to one code path in create.py, missed sibling `create_epic_in_jira` in same file | **VIOLATION** [RULE] |

### Other Required Coverage

**[VERIFIED] Jira config does not eagerly raise at module import** — `pennyfarthing-dist/src/pf/jira/client.py:60-64` resolve config and assign to module constants; `_resolve_jira_config` does not raise on missing config (returns `(None, None)`); the framework imports cleanly in projects with no Jira config. Complies with story SM Assessment "Import-time safety" requirement.

**[VERIFIED] `JiraConfigError` message contains no PII or secret** — `pennyfarthing-dist/src/pf/jira/client.py:52-55` references only `jira.project`, `.pennyfarthing/config.local.yaml` (a public conventional path), and `JIRA_PROJECT` env var name. No tokens, passwords, or user identifiers. Complies with security rules.

**[VERIFIED] No unsafe deserialization or shell injection introduced** — Diff has `yaml.safe_dump` (test fixture build), no `pickle`, no `eval`, no `subprocess(..., shell=True)` interpolation. Complies with Python lang-review #8.

**[VERIFIED] Test fixtures' MSSCI→PROJ rename preserves test logic** — Tests in `test_151_3_sharded_update_and_finish_loud.py` and `test_archive_epic_field_validation.py` are project-key-agnostic; Dev's `MSSCI- → PROJ-` substitution is mechanical with no behavior change. 191 pre-existing tests in those files still pass.

**[VERIFIED] ADR-0022 port-number rewrite removes brand without breaking diagram structure** — Diagrams now consistently show port `2898`; the parallel-running paragraph cleanly references `2898`/`2899`. Reviewer-comment-analyzer flagged that the pre/post-migration diagrams now use the same port (erasing historical distinction); accepted as a known Architect-M4 trade-off (scrub > history).

### Tenant Isolation Audit

N/A. This story does not introduce or modify any code paths that handle multi-tenant data, trait methods accepting `TenantId`, or fields on tenant-bearing structs. The only data-handling addition is `JiraConfigError` (a value-less exception type) and `require_jira_project` (a string getter with empty-rejection). No tenant isolation boundary is at risk.

### Devil's Advocate

Suppose I'm a malicious or merely confused user. What would I exploit?

First, the fail-loud surface is asymmetric. `create_story_in_jira` and `build_epic_payload` are guarded; `create_epic_in_jira` is not. A user who accidentally clears `JIRA_PROJECT` (env-var unset, config file rotated) and runs `pf jira create epic` will get either a malformed JQL error from Jira (the `f'project = AND ...'` query) or — worse — a created Jira issue that looks correct in CI logs but is actually filed under whatever default project the Jira API server applies when given an empty key. Story 152-1 explicitly forbids "default to MSSCI or any other key" — yet the unguarded path can do exactly that. This isn't a hypothetical: the same SM Assessment that grounds this story called this out.

Second, the hygiene test is case-blind in one direction and case-sensitive in another. `1898&co` is matched case-insensitively (so `1898&Co` would be caught); `MSSCI` is matched case-sensitively (so `mssci` slips through). The test file at `tests/python/test_sprint_story_command.py:93` has `mssci-00000` in an assertion string — it would have been caught and removed by a uniform case-insensitive sweep, but the actual scan passes. A future dev who copies that style produces another lowercase reference, and the gate continues passing.

Third, the regression test is a fair-weather contract. `distinguishable = has_strict_helper or ...` is satisfied as long as the *name* `require_jira_project` exists on the module — even if its body has been gutted to `def require_jira_project(value=None): return value or "MSSCI"`. The test claims to verify that "callers can distinguish unset from configured-empty" but does not actually verify that contract once the helper exists. A future refactor that consolidates resolvers into a single function and silently restores the empty-string default would pass this test green.

Fourth, the `_resolve_jira_config` fallback `except Exception: jira_cfg = {}` swallows YAML parse errors with no comment and no log. A user who edits `.pennyfarthing/config.local.yaml`, accidentally introduces a tab character or breaks the indentation, will see `JiraConfigError: Jira project key not configured` — pointing at the wrong root cause. They'll set `JIRA_PROJECT` env-var, get a different "project not found" error from the Jira API, and never realize the config file was the actual problem.

Fifth, the FORBIDDEN_* concatenation is presented as a defense against self-match, but `SKIP_FILES = {Path(__file__).resolve()}` already does the work. The concatenation creates the illusion that the test is paranoid about its own contents — when the actual paranoia is a no-op. A reader who relies on the concatenation as a guard might use plain string literals in a *new* hygiene test elsewhere and get a false negative because they forgot to add the file to `SKIP_FILES`.

Each of these failures is the same class: **a clean preflight covering an incomplete contract**. The pipeline produced GREEN, ARCHITECT-PROCEED, and a tidy diff — yet the story's two primary deliverables are each incompletely fulfilled. The boss will catch this in external review and ask why our internal gates didn't.

### Recommended Routing

**Hand back to TEA (red rework)** — the failures are testable. TEA must:
1. Strengthen `test_jira_project_resolution_distinguishes_unset_state` to actually assert the resolver's return value (split into two tests, or remove the helper-exists shortcut).
2. Make the MSSCI hygiene scan case-insensitive (mirror the 1898&co treatment).
3. Tighten the walk-sanity to prove `pennyfarthing-dist/` is actually scanned.
4. Add `Raises:` docstring entry for `build_epic_payload`.

**Then to Dev (green rework)** — Dev must:
1. Apply `require_jira_project(JIRA_PROJECT)` guard to `create_epic_in_jira` at lines 232 (JQL) and 267 (payload), with `JiraConfigError` catch returning `{success: False, error: str(e)}`.
2. Replace `mssci-00000` in `tests/python/test_sprint_story_command.py:93` with a generic placeholder.
3. Strip whitespace in `require_jira_project` (`if not (value and value.strip())`).
4. Fix `config.get("jira") or {}` to handle null YAML.
5. Update stale "Current behavior (the bug)" docstrings in `test_152_1_jira_project_fail_loud.py` to describe the implemented behavior.
6. Add comment to the `_resolve_jira_config` bare-except explaining intentional swallow.
7. Remove the unused FORBIDDEN_* concatenation trick (cleanup, follow simplifier).
8. Add the missing `1898&co` bullet to the hygiene-test module docstring.
9. Optional: add `assert result["payload"]["fields"]["project"]["key"] == "PROJ"` to `test_create_epic_dry_run`.

**Handoff:** Back to TEA for re-RED.

## Dev Assessment (round 2)

**Phase:** finish (re-entry after Reviewer REJECT → TEA re-RED → Dev round 2)
**Round-Trip:** 1 of 3 (max)
**Implementation Complete:** Yes
**Tests:** 53/53 story-152-1 tests passing (GREEN). Pre-existing unrelated failures in async-config and brownfield modules untouched.
**Branch:** `feat/152-1-remove-mssci-hardcoding` (pushed — orchestrator HEAD `ed2267aae`)

**Files Changed (round 2):**
- `pennyfarthing-dist/src/pf/jira/create.py` — added `require_jira_project(JIRA_PROJECT)` resolution at the top of the non-dry-run branch in `create_epic_in_jira`; replaced raw `JIRA_PROJECT` with `project_key` at the JQL search (line 232) and the create payload (line 267). Mirrors the pattern in `create_story_in_jira` lines 110-113. On `JiraConfigError` returns `{"success": False, "error": str(e)}`.
- `pennyfarthing-dist/src/pf/jira/client.py` — `_resolve_jira_config` now uses `config.get("jira") or {}` (handles a null-valued YAML `jira:` key cleanly) and the bare `except Exception:` carries an inline comment documenting the intentional swallow. `require_jira_project` rejects whitespace-only values and strips the returned key.
- `pennyfarthing-dist/src/pf/jira/epic.py` — `build_epic_payload` docstring now documents `Raises: JiraConfigError`.
- `pennyfarthing-dist/src/pf/tests/test_jira_package.py` — `test_create_epic_dry_run` now asserts `result["payload"]["fields"]["project"]["key"] == "PROJ"` so a regression that ignored the constant would not pass green.
- `tests/python/test_sprint_story_command.py` — assertion at line 93 changed from `"mssci-00000"` to `"proj-00000"` (matches the fixture's lowercased `PROJ-00000` Jira key); removes the lowercase corporate-key leak the case-insensitive hygiene scan now catches.

**Reviewer findings addressed:**

| Reviewer Finding | Severity | Status |
|------------------|----------|--------|
| F1 — `create_epic_in_jira` unguarded JIRA_PROJECT at lines 232,267 | HIGH | Fixed (require_jira_project guard added) |
| F2 — case-sensitive MSSCI scan + lowercase leak in test_sprint_story_command.py | HIGH | Fixed by TEA (ignore_case=True) + Dev (proj-00000 placeholder) |
| F3 — `distinguishable` shorts on helper-existence | HIGH | Fixed by TEA (split into two independent tests) |
| MEDIUM — stale "Current behavior (the bug)" docstrings | MEDIUM | Fixed by TEA (re-RED rewrite) |
| MEDIUM — `_resolve_jira_config` bare except no comment | MEDIUM | Fixed (inline comment added) |
| MEDIUM — `require_jira_project` doesn't strip whitespace | MEDIUM | Fixed (whitespace-only rejected, value stripped) |
| MEDIUM — `config.get("jira", {})` returns None on null YAML | MEDIUM | Fixed (`or {}` idiom) |
| MEDIUM — `test_create_epic_dry_run` missing payload-key assertion | MEDIUM | Fixed (assertion added) |
| MEDIUM — walk-sanity test could pass on wrong root | MEDIUM | Fixed by TEA (targeted dist-tree count) |
| LOW — `build_epic_payload` docstring missing Raises clause | LOW | Fixed (Raises clause added) |
| LOW — FORBIDDEN_* string concatenation unnecessary | LOW | Deferred — out-of-scope cleanup; SKIP_FILES already neutralizes self-match. Logged as a Dev round-2 deferral below. |

**Self-review (round 2):**
- ✅ Tests green (53/53 story-152-1 tests; full Python suite shows only pre-existing unrelated failures)
- ✅ Working tree clean (post-commit `git status` = clean in `pennyfarthing/`)
- ✅ No debug code (no `print` statements added; no `breakpoint()` left)
- ✅ Correct branch (`feat/152-1-remove-mssci-hardcoding`, gitflow base `develop`)
- ✅ Code wired to Jira creation paths actually exercised by `pf jira create epic` and `pf jira create story`
- ✅ Code follows project patterns (mirror of `create_story_in_jira`'s pattern for symmetry)
- ✅ All Reviewer HIGH/MEDIUM findings addressed except the LOW deferral noted above
- ✅ Error handling at the system boundary (Jira API call sites); preserves SOUL #10 (return results, don't throw) at the orchestrator level

**Handoff:** To Reviewer (Granny Weatherwax) for round-2 review.

## Architect Assessment (spec-check, round 2)

**Spec Alignment:** Aligned (in-scope sweep complete)
**Mismatches Found:** 0 blocking, 1 non-blocking (carry-over deferral, re-affirmed with stronger rationale)
**Round-Trip:** 1 of 3 (architect re-engages spec-check after Reviewer REJECT → TEA re-RED → Dev round 2)

### Round-1 mistake explicitly corrected this round

In round 1, my M1 finding ("only 2 call sites guarded — defer reconcile.py + cli.py") deferred the **off-diff** sites but did **not enumerate the in-diff siblings**. The Reviewer's F1 caught `create_epic_in_jira` (same file as `create_story_in_jira`, both in `create.py`) — an in-file sibling I should have flagged at spec-check. Reviewer's Delivery Finding `### Reviewer (code review)` explicitly named this as the spec-check failure mode: *"Architect spec-check should enumerate every JIRA_PROJECT usage site in changed files going forward."*

### Exhaustive enumeration of `JIRA_PROJECT` usages in changed files (round 2)

| File | Line | Surface | Type | Guarded? | Source |
|------|------|---------|------|----------|--------|
| `pennyfarthing-dist/src/pf/jira/create.py` | 20 | `from pf.jira.client import JIRA_PROJECT, ...` | import | N/A | round 1 |
| `pennyfarthing-dist/src/pf/jira/create.py` | 111 | `create_story_in_jira` | write payload | ✓ via `require_jira_project(JIRA_PROJECT)` | round 1 |
| `pennyfarthing-dist/src/pf/jira/create.py` | 228 | `create_epic_in_jira` | write payload + JQL search | ✓ via `require_jira_project(JIRA_PROJECT)` | **round 2 (F1 fix)** |
| `pennyfarthing-dist/src/pf/jira/epic.py` | 20 | `from pf.jira.client import JIRA_PROJECT, ...` | import | N/A | round 1 |
| `pennyfarthing-dist/src/pf/jira/epic.py` | 69 | `build_epic_payload` | write payload | ✓ via `require_jira_project(JIRA_PROJECT)` | round 1 |
| `pennyfarthing-dist/src/pf/jira/client.py` | 38 | `_resolve_jira_config` env-var read | resolver | N/A (defines the resolver itself) | unchanged |
| `pennyfarthing-dist/src/pf/jira/client.py` | 46 | docstring | doc | N/A | round 1 |
| `pennyfarthing-dist/src/pf/jira/client.py` | 55 | error message | doc | N/A | round 1 |
| `pennyfarthing-dist/src/pf/jira/client.py` | 63 | `JIRA_PROJECT: str = ...` module constant | definition | N/A (allowed to be empty; callers use `require_jira_project`) | round 1 |

**Result: every write/read call site in changed files is guarded. The in-file sweep is complete.**

### Off-diff `JIRA_PROJECT` usage sites (M1 deferral, re-affirmed)

| File | Line | Surface | Risk class | Disposition |
|------|------|---------|------------|-------------|
| `pennyfarthing-dist/src/pf/jira/cli.py` | 161 | import | N/A | — |
| `pennyfarthing-dist/src/pf/jira/cli.py` | 164 | `pf jira search` JQL: `proj = project or JIRA_PROJECT` | read-only — Jira returns 400 on malformed JQL when `proj=""`; user sees explicit API error, **not silent** | **Defer** — out-of-scope for 152-1; follow-up story |
| `pennyfarthing-dist/src/pf/jira/cli.py` | 325 | import | N/A | — |
| `pennyfarthing-dist/src/pf/jira/cli.py` | 344 | `pf jira create standalone` payload: `{"project": {"key": JIRA_PROJECT}}` | **write** — Jira API rejects with 400 on empty `key`; user sees explicit "Failed to create story" error from line 354. Same pattern (and same per-call rejection at API boundary) as the now-fixed `create_epic_in_jira` payload. | **Defer with explicit follow-up story** — see severity discussion below |
| `pennyfarthing-dist/src/pf/jira/reconcile.py` | 23 | import | N/A | — |
| `pennyfarthing-dist/src/pf/jira/reconcile.py` | 114 | reconcile JQL `f"project={JIRA_PROJECT} AND ..."` | read-only — same as cli.py:164 | **Defer** — out-of-scope for 152-1; follow-up story |
| `pennyfarthing-dist/src/pf/jira/reconcile.py` | 139 | reconcile JQL `f"project={JIRA_PROJECT} AND ..."` | read-only — same as cli.py:164 | **Defer** — out-of-scope for 152-1; follow-up story |

**Severity discussion for `cli.py:344` (`create_standalone`):**

This is the closest-to-F1 of the off-diff sites — it's a write site that builds a Jira payload from `JIRA_PROJECT`. Argument for hand-back-to-Dev: story scope says *"no silent fallbacks"* and Reviewer's round-1 Improvement finding said *"splitting it across stories invites the same partial-coverage trap."*

Argument for **defer** (which I am choosing):

1. **Behavior is not silent.** Unlike `create_epic_in_jira`'s search-JQL path (where empty results were treated as "no duplicate"), `create_standalone` calls `client.create_issue_sync(payload)` directly. The Jira REST API rejects `{"project": {"key": ""}}` with a 400 response; the framework code at `cli.py:354` then raises `click.ClickException(f"Failed to create story: {response}")` — visible, not silent. The `create_epic_in_jira` JQL-search silent-failure mode does not exist on this path.
2. **Off-diff scope discipline.** Round 1's REJECT was specifically about the **in-file** sibling Dev modified. The Reviewer's `cli.py`/`reconcile.py` finding was Improvement-class (non-blocking) and explicitly framed as "consider also addressing as a single coherent fail-loud sweep" — a recommendation for follow-up scope, not a blocker.
3. **No test coverage exists.** TEA tests in both rounds did not pin `cli.py:344` or `reconcile.py:114,139`. Adding the guard without a test would create exactly the regression-risk class the Reviewer warned about (silent regression once the helper exists). Hand-back would require TEA re-RED + Dev round-3 + Reviewer round-3 — burning 1 of the 2 remaining round-trip slots on a non-silent issue.
4. **Round-trip budget.** This is round-trip 1 of 3. Burning round 3 on a deferred-and-acknowledged off-diff cleanup leaves zero margin for any genuinely new issues the Reviewer surfaces. Conservation here protects the merge window.
5. **Story-scope authority.** Story scope (highest authority per `<spec-authority>`) does not enumerate `cli.py` or `reconcile.py` as in-scope, and TEA tests do not pin them. Pulling them in changes the story shape after the fact.

**Required action: SM provisions a follow-up story (proposed: 152-2 or epic-152 child)** — *"Apply `require_jira_project()` to all remaining `JIRA_PROJECT` call sites in `pf/jira/`"*, with TEA-pinned tests for `cli.py:344` (write site) and JQL malformedness assertions for `cli.py:164`, `reconcile.py:114,139` (read sites). This is captured below in `## Delivery Findings → ### Architect (spec-check, round 2)`.

### Round-2 spec alignment per Reviewer finding

Each Reviewer round-1 finding mapped to round-2 code:

| Reviewer Finding | Spec source | Code location | Match? |
|------------------|-------------|---------------|--------|
| F1 — `create_epic_in_jira` unguarded JIRA_PROJECT (line 232/267) | Story scope: "no silent defaults"; mirror of `create_story_in_jira` lines 110-113 | `create.py:228-231` (resolution) → `create.py:236` (JQL `project = {project_key}`) → `create.py:271` (payload `{"key": project_key}`) | ✓ Matches — three-line guard exactly mirrors the round-1 pattern |
| F2 — case-sensitive MSSCI scan + lowercase leak | TEA test `_find_offenders(... ignore_case=True)`; `tests/python/test_sprint_story_command.py:93` use generic placeholder | TEA: `test_152_1_no_company_leakage.py:138` (`ignore_case=True` per re-RED line 249); Dev: `tests/python/test_sprint_story_command.py:93` `proj-00000` | ✓ Matches |
| F3 — vacuous `distinguishable` test | Either split into two tests, or remove `has_strict_helper` from OR-chain | TEA split into `test_jira_project_resolution_returns_sentinel_when_unset` + `test_jira_project_strict_helper_is_exposed` (per re-RED line 254-256) | ✓ Matches |
| MEDIUM — stale "Current behavior (the bug)" docstrings | Rewrite to describe implemented behavior | TEA: per re-RED line 258 ("Module docstring + per-test docstrings rewritten") | ✓ Matches |
| MEDIUM — bare except no comment | Inline comment explaining intentional swallow | `client.py:36` `except Exception:  # config is optional; Jira ops work without it` | ✓ Matches |
| MEDIUM — whitespace not stripped in `require_jira_project` | `if not (value and value.strip())`, return stripped | `client.py:51-57` `if not (value and value.strip()): raise ...; return value.strip()` | ✓ Matches |
| MEDIUM — `config.get("jira", {})` returns None on null YAML | `config.get("jira") or {}` | `client.py:35` `jira_cfg = config.get("jira") or {}` | ✓ Matches |
| MEDIUM — `test_create_epic_dry_run` missing payload-key assertion | `assert result["payload"]["fields"]["project"]["key"] == "PROJ"` | `test_jira_package.py:326` exactly that assertion | ✓ Matches |
| MEDIUM — walk-sanity could pass on wrong root | Replace `len(visited) > 100` with targeted dist-tree count | TEA per re-RED line 250 (now counts files specifically under `pennyfarthing-dist/`) | ✓ Matches |
| LOW — `build_epic_payload` missing `Raises:` | Add `Raises: JiraConfigError` clause | `epic.py:48-51` `Raises:\n    JiraConfigError: ...` | ✓ Matches |
| LOW — FORBIDDEN_* concat unnecessary | Optional cleanup | Dev deferred with rationale (logged in Design Deviations round 2) | ✓ Acceptable — Reviewer marked optional |

### Mismatches summary

- **Mismatches in round-2 in-scope code:** 0
- **Mismatches in round-2 deviation logs:** 0 (all 3 round-2 Dev deviations are accurate, well-formatted, severity-appropriate)
- **Carry-over deferral re-affirmed:** off-diff M1 (cli.py + reconcile.py); see "Delivery Findings → Architect (spec-check, round 2)" for follow-up story recommendation

### Decision

**Proceed to TEA verify phase.** Round-2 implementation aligns with the test-pinned contract, the Reviewer's prescribed fixes, and the in-scope portion of the session spec. The in-file sweep is complete (the failure mode that produced round-1 REJECT no longer exists in any changed file). The off-diff M1 deferral is re-affirmed with strengthened rationale and an explicit follow-up story request to SM.

## TEA Assessment (verify, round 2)

**Phase:** finish (round 2)
**Round-Trip:** 1 of 3 (verify re-engages after Reviewer REJECT → TEA re-RED → Dev round 2 → Architect round-2 spec-check)
**Status:** simplify: clean (no high-confidence fixes auto-applied — see Decision Rationale)
**Tests:** GREEN (Dev's round-2 testing-runner verified 53/53 story-152-1 tests passing; codebase unchanged since)
**Branch:** `feat/152-1-remove-mssci-hardcoding` (HEAD `ed2267aae`)

### Files Analyzed (round-2 deltas only)

Per simplify-workflow Step 1, identified the round-2 changed files (commit `ed2267aae`):

- `pennyfarthing-dist/src/pf/jira/client.py` — `or {}` idiom + bare-except inline comment + whitespace strip in `require_jira_project`
- `pennyfarthing-dist/src/pf/jira/create.py` — `create_epic_in_jira` guard (Reviewer F1 fix)
- `pennyfarthing-dist/src/pf/jira/epic.py` — `Raises: JiraConfigError` docstring clause
- `pennyfarthing-dist/src/pf/tests/test_jira_package.py` — payload-key assertion in `test_create_epic_dry_run`
- `tests/python/test_sprint_story_command.py` — `proj-00000` lowercase placeholder

Round-1 portions of the diff were already simplified during the round-1 verify phase; this pass focuses on round-2 deltas to avoid re-litigating accepted patterns.

### Simplify Report

**Teammates:** simplify-reuse, simplify-quality, simplify-efficiency
**Files Analyzed:** 5

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | findings | 2 HIGH (extract guard helper, move ADF builder), 1 MEDIUM (consolidate bare-except patterns) |
| simplify-quality | findings | 1 LOW (test casing — verified mistaken; dismissed) |
| simplify-efficiency | clean | 0 |

**Applied:** 0 high-confidence fixes
**Flagged for Review:** 0 medium-confidence (the 1 MEDIUM is dismissed as scope creep)
**Noted:** 1 low-confidence (dismissed as mistaken)
**Reverted:** 0

**Overall:** simplify: clean (no fixes applied — round-2 deltas are byte-identical to Dev's GREEN-verified state)

### Aggregated Findings & Disposition

| # | Agent | File:Line | Category | Confidence | Disposition |
|---|-------|-----------|----------|------------|-------------|
| 1 | reuse | create.py:110, create.py:227, epic.py:69 | extractable-helper (guard pattern at 3 sites) | HIGH | **NOT APPLIED** — see rationale below |
| 2 | reuse | create.py:46 vs epic.py:53-63 | duplicated-logic (ADF description builder) | HIGH | **NOT APPLIED** — see rationale below |
| 3 | reuse | create.py:36, create.py:262 | shared-validation (bare-except patterns) | MEDIUM | Flagged for follow-up; not auto-applied |
| 4 | quality | tests/python/test_sprint_story_command.py:93 | naming-inconsistency (test casing) | LOW | **DISMISSED** — see rationale below |
| 5 | efficiency | — | — | — | clean |

### Decision Rationale: Why HIGH-Confidence Fixes Were Not Applied

The simplify-workflow Step 5 says auto-apply confidence:high. I am deviating from that default for both findings; logged as a TEA verify deviation in `### TEA (verify)` under Design Deviations.

**Finding 1 — Extract `require_jira_project` guard helper across 3 call sites:**

The argument for extraction is that `create_story_in_jira:110-113`, `create_epic_in_jira:227-230`, and `build_epic_payload:69` use the same try-except pattern. Extracting a helper would shrink the diff by ~9 lines and centralize the guard.

**The argument against — and why this fix is rejected:**

1. **Round 1's REJECT class was specifically that one of these guards was MISSING.** The Reviewer's F1 caught `create_epic_in_jira` because the per-site guard was absent. The cure for "missing per-site guard" is **not** to centralize the guard behind a helper that hides which sites have it; the cure is to ensure every site has it explicitly. A helper makes "is this site guarded?" harder to answer at a glance — it would have made the round-1 missed sibling harder to spot, not easier.
2. **Round 1's verify accepted the per-site pattern.** Round 1's TEA verify (still in this session file at line ~501) accepted the duplicated try-except as in-spec. Re-litigating an accepted pattern in round 2 is scope creep that risks introducing the very class of regression we just fixed.
3. **Reviewer/Architect explicitly want enumerated per-site guards.** Architect's round-2 spec-check assessment (above) builds an explicit table of every JIRA_PROJECT call site and verifies each one is guarded. That auditability is destroyed if the guard is hidden inside a helper — Architect's table would no longer trace one-to-one to lines of code.
4. **The pattern is intentional duplication.** Three lines × three sites is not a candidate for extraction by the rule of three; it's a deliberate per-site invariant. Centralizing it is a textbook over-DRY refactor that obscures rather than clarifies.

**Finding 2 — Move `_build_adf_description` from `create.py` to `client.py`:**

The argument for move is that `_build_adf_description` (create.py:46-57) and the inline ADF construction in `build_epic_payload` (epic.py:53-63) build identical structures.

**The argument against — and why this fix is rejected:**

1. **Pre-existing duplication, not introduced in round 2.** Both implementations exist before this story's first commit. Round 1's verify simplify-reuse did not flag this (or flagged-and-deferred it). Round 2 should not change pre-existing accepted patterns unless the round-2 diff introduces new pressure on the duplication — it doesn't.
2. **Out-of-scope refactor.** Story 152-1 is "fail-loud Jira project key resolution + scrub corporate identifiers." Moving an ADF builder is unrelated mechanical refactor. Doing it here would inflate the diff, complicate review, and reduce signal on the actual change.
3. **Risk profile.** The two implementations are not byte-identical: `create.py:_build_adf_description` is a function with a typed signature; `epic.py:build_epic_payload` constructs `description_adf` as a local dict variable assigned to a different name. A move-to-shared-utility refactor is non-trivial and could introduce regressions in either consumer. Not worth carrying in a story already at round 2.
4. **Defer-with-traceability.** Logged as a follow-up Improvement in Delivery Findings → TEA (verify, round 2) so a future story can address it cleanly.

**Finding 3 — Consolidate bare-except patterns across `_resolve_jira_config` and the duplicate-search block in `create_epic_in_jira` (MEDIUM):**

Per simplify-workflow Step 5, MEDIUM findings are flagged, not auto-applied. The two except blocks have different intents:
- `client.py:36` — config-loading is *optional*, swallow expected when no config exists
- `create.py:262` — duplicate-title search is *best-effort*, swallow expected when Jira is reachable but the search fails

Consolidating them would conflate two distinct error policies. Decline, document.

**Finding 4 — Test casing inconsistency at `tests/python/test_sprint_story_command.py:93` (LOW):**

The simplify-quality teammate flagged that the test asserts lowercase `"proj-00000"` while the fixture uses uppercase `"PROJ-00000"`. **Verified incorrect**: line 92 is `output = result.output.lower()` — the assertion correctly checks the **lowercased** output. The teammate missed the `.lower()` call. Dismissed.

### Deviation Logging

Two deviations logged under `### TEA (verify)` in `## Design Deviations` (round 2 subsection):

1. Deviation from simplify-workflow Step 5 default ("auto-apply confidence:high") — both HIGH findings rejected with the rationale above.
2. No code changes applied — diff is byte-identical to Dev's GREEN state.

### Step 7 Regression Detection

**Skipped — by predicate.** Step 7 reads: *"After applying changes, re-run quality checks…"* No changes were applied; the codebase is byte-identical to the state Dev's testing-runner verified GREEN (53/53 story-152-1 tests). Re-running tests would burn time and risk re-triggering the testing-runner session-overwrite bug Architect logged in `### Architect (spec-check, round 2)`. The unchanged-codebase invariant is the strongest possible regression evidence.

### Quality-Pass Gate

The dev-exit gate already ran (Dev exit) and passed. The verify gate is Step 8 of the simplify-workflow; no auto-applied changes means there's nothing for it to validate beyond what dev-exit already confirmed. Proceed.

**Handoff:** To Reviewer (Granny Weatherwax) for round-2 adversarial review.

## Subagent Results (round 2)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (218/218 branch tests pass; 21 unrelated baseline failures pre-exist on develop; ruff clean on changed files) | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 5 | confirmed 4 (NBSP/non-ASCII whitespace bypass, non-string config crash, existing[0]['key'] KeyError, force-branch same KeyError), dismissed 0, deferred 1 (writeback dup with silent-failure-hunter) |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 5 | confirmed 2 (create.py:262 warnings.warn masks auth errors, epic.py:170 writeback failure invisible to CLI main), deferred 3 (client.py:272/323 pre-existing, client.py:582 pre-existing curl-return discard) |
| 4 | reviewer-test-analyzer | Yes | findings | 6 | confirmed 2 (dead `import pytest`, `.session/` exclusion silently masks live MSSCI in session file), dismissed 4 (low-confidence implementation-coupling and missing-negative notes) |
| 5 | reviewer-comment-analyzer | Yes | findings | 4 | confirmed 1 (require_jira_project docstring slightly misleading on empty-string handling), deferred 2 (ADR-0022 port — Architect M4 already accepted; story-id reference in public docstring — low impact), confirmed 1 (test_152_1_*:619 ghost `get_jira_project` reference) |
| 6 | reviewer-type-design | Yes | findings | 5 | confirmed 4 (JIRA_PROJECT empty-string sentinel, reconcile.py/cli.py unguarded sites — all M1 deferral re-affirmation), deferred 1 (build_epic_payload raises rather than returns — fail-loud-API by design) |
| 7 | reviewer-security | Yes | findings | 4 | confirmed 2 (JQL injection via epic title, require_jira_project doesn't validate key format), deferred 1 (cli.py:344 — M1 deferral), deferred 1 (git history leakage — out of scope, accepted by user) |
| 8 | reviewer-simplifier | Yes | findings | 8 | confirmed 2 (cli.py:344 and reconcile.py:114,139 unguarded — M1 deferral re-affirmation), dismissed 4 (require_jira_project None-branch simplification, redundant or "" coercion — both rejected: backward-compat preserved per Architect M3 acceptance), confirmed 0 of HIGH on test-helper extraction (declined — see Rationale), deferred 2 (test_151_3 + test_frame_server scrubs — driven by leakage gate, correct) |
| 9 | reviewer-rule-checker | Yes | findings | 3 | confirmed 3 (create.py:262 pre-existing broad except — already round-1 noted, test_152_1_jira_project_fail_loud.py:180 early-return without assertion, epic.py:155 latent fragility if error boundary moves) |

**All received:** Yes (9 returned, 8 with findings, preflight clean)
**Total findings:** 18 confirmed (0 HIGH new in round 2; 5 MEDIUM new; 13 LOW/cosmetic/pre-existing/M1-reaffirmation), 8 dismissed (with rationale), 7 deferred (to follow-up story 152-2 per Architect M1 disposition)

## Reviewer Assessment (round 2)

**Verdict:** APPROVED

The round-1 REJECT class — `create_epic_in_jira` missing the per-site `require_jira_project` guard in the same file Dev had patched — is fixed. Verified at `pennyfarthing-dist/src/pf/jira/create.py:228`: the guard is present, catches `JiraConfigError`, and returns `{success: False, error: str(e)}`. The hygiene-scan lowercase-MSSCI gap (round-1 F2) is fixed: the placeholder at `tests/python/test_sprint_story_command.py:93` is now `proj-00000` and the assertion at line 92 lowercases the captured output (`output = result.output.lower()`), so the case-sensitive scan now catches lowercase variants by construction. The vacuous distinguishability test (round-1 F3) was rewritten in TEA's re-RED to assert actual resolver behavior independently from helper-existence. All three round-1 HIGH findings are closed.

Round 2's adversarial sweep — 9 specialists across 1127 diff lines — found NO new Critical or High severity issues. The strongest new findings are Medium-severity: (a) JQL injection surface via epic title (developer-controlled sprint YAML, low practical exploitability), (b) `require_jira_project` accepts non-format-valid keys (only checks non-emptiness), (c) Unicode whitespace (NBSP, em-space) bypasses `str.strip()` and produces malformed Jira API calls instead of a clean `JiraConfigError`, (d) a non-string config value (`project: 1234`) raises `AttributeError` rather than `JiraConfigError`, breaking the result-dict contract that callers expect, (e) `existing[0]['key']` `KeyError` swallowed by the duplicate-search bare-except produces a misleading "search failed" warning while falling through to create a duplicate epic. None block the round-2 verdict; all are routed to the proposed `152-2` follow-up that already exists for M1 deferral.

The off-diff `JIRA_PROJECT` call sites (`cli.py:164,344`, `reconcile.py:114,139`) were flagged by three independent subagents (`reviewer-type-design`, `reviewer-simplifier`, `reviewer-security`). All three findings are re-affirmations of Architect's round-1 M1 deferral, already accepted by Reviewer round-1 audit, already logged as round-2 Architect spec-check carry-over, and already requested for follow-up story `152-2` provisioning. No new disposition required; the convergent flagging confirms the deferral remains correctly scoped.

### Severity Table

| Severity | Issue | Location | Source | Disposition |
|---|---|---|---|---|
| [MEDIUM] | JQL injection via epic `title` interpolated into `summary ~ "{title}"` clause. A double-quote in title would close the JQL string and allow predicate injection. Sprint YAML is developer-controlled (memory: sprints are local-only kanban), so practical exploit risk is low, but the rule still applies. [SEC] | `pennyfarthing-dist/src/pf/jira/create.py:237` (`f'project = {project_key} AND issuetype = Epic AND summary ~ "{title}"'`) | security | **Improvement** logged for `152-2`. Escape `"` or restructure search to avoid raw JQL. |
| [MEDIUM] | `require_jira_project` validates non-emptiness only — does NOT validate Jira project key format (regex `^[A-Z][A-Z0-9]+$`). A `JIRA_PROJECT` env value like `PROJ AND 1=1` passes the guard and lands in JQL unescaped. [SEC] | `pennyfarthing-dist/src/pf/jira/client.py:43-57` | security | **Improvement** logged for `152-2`. Add format validation. |
| [MEDIUM] | `str.strip()` strips ASCII whitespace only; `JIRA_PROJECT=" "` (NBSP from copy-paste) passes the guard and lands in API payload as malformed key, producing a Jira API error instead of `JiraConfigError`. [EDGE] | `pennyfarthing-dist/src/pf/jira/client.py:51` | edge-hunter | **Improvement** logged for `152-2`. |
| [MEDIUM] | Non-string config value (`project: 1234` in YAML) raises `AttributeError` (on `.strip()`) instead of `JiraConfigError`. Callers catch `JiraConfigError` only, so the `AttributeError` propagates uncaught and breaks the result-dict contract. [EDGE][TYPE] | `pennyfarthing-dist/src/pf/jira/client.py:38,51` | edge-hunter, type-design | **Improvement** logged for `152-2`. Coerce to `str` or add `isinstance` guard. |
| [MEDIUM] | `existing[0]['key']` raises `KeyError` if the first search result is malformed; the outer bare `except Exception as exc:` at `create.py:262` swallows it, emits a misleading "Jira search for duplicate titles failed" warning, and falls through to create a duplicate epic. Same misbehavior in the `force=True` branch at line 258. [EDGE][SILENT] | `pennyfarthing-dist/src/pf/jira/create.py:240, 258` | edge-hunter, silent-failure-hunter | **Improvement** logged for `152-2`. Use `.get('key')` with explicit handling. |
| [LOW] | Dead `import pytest` in hygiene-scan test file — no fixtures, no marks, no `pytest.raises`. Copy-paste artifact. [TEST] | `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py:28` | test-analyzer | **Improvement** logged for `152-2` (or trivial cleanup in any future touch of this file). |
| [LOW] | `.session/` exclusion in `SKIP_DIRS` is correct (gitignored runtime), but the hygiene-scan green result is achieved while `.session/152-1-session.md` itself contains 31 live `MSSCI` occurrences. A future reader could mistake green for "tree is clean". [TEST] | `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py:41` | test-analyzer | **Improvement** for `152-2`: add an explanatory comment naming the gitignored-runtime exclusion in the assertion message. |
| [LOW] | Test helper-existence check accepts EITHER `require_jira_project` OR `get_jira_project`; only `require_jira_project` exists on the module. Ghost reference to a never-shipped name in test body and module docstring. [DOC] | `pennyfarthing-dist/src/pf/tests/test_152_1_jira_project_fail_loud.py:427, 619` | comment-analyzer | **Improvement** for `152-2`. |
| [LOW] | `require_jira_project` docstring says "Pass an explicit value … to avoid re-resolving config" — the description glosses over that passing `value=""` does not re-resolve (the function raises directly). Subtly misleading for downstream callers. [DOC] | `pennyfarthing-dist/src/pf/jira/client.py:44` | comment-analyzer | **Improvement** for `152-2`. Clarify three-way contract: truthy-skip, None-resolve, empty-raise. |
| [LOW] | `test_jira_project_resolution_returns_sentinel_when_unset` has an early-return path that yields a passing test with no assertion if `_resolve_jira_config` raises for an unrelated reason. Mitigated by the separate `test_jira_project_strict_helper_is_exposed`, but the contract verification is not local. [TEST][RULE] | `pennyfarthing-dist/src/pf/tests/test_152_1_jira_project_fail_loud.py:180-188` | rule-checker | **Improvement** for `152-2`. |
| [LOW] | `create_epic_from_yaml` has no try/except wrapping `create_epic()`. Current behavior is correct because `create_epic` catches `JiraConfigError` internally and returns `{success: False}`. Latent fragility: a future refactor that moves the guard could let `JiraConfigError` propagate to `main()`. [RULE] | `pennyfarthing-dist/src/pf/jira/epic.py:155` | rule-checker | **Improvement** for `152-2`. Defensive try/except at the orchestrator boundary. |
| [LOW] | `build_epic_payload` `Raises:` docstring references "Story 152-1" — story IDs are local sprint artifacts, not stable cross-repo identifiers in a redistributable framework. Strip story reference from public-API docstring. [DOC] | `pennyfarthing-dist/src/pf/jira/epic.py:51` | comment-analyzer | **Improvement** for `152-2`. |

### Rule Compliance

Mapped to `pennyfarthing-dist/gates/lang-review/python.md` (13 numbered checks). Round-2 status reflects round-1 violations now closed by the round-2 diff:

| Rule | Subject | Round-1 Status | Round-2 Status |
|------|---------|---------------|----------------|
| #1 Silent exception swallowing | `_resolve_jira_config` bare except | VIOLATION (no comment, no log) | **Compliant** — inline comment added at `client.py:36`; broader-policy follow-ups deferred to `152-2` |
| #2 Mutable default arguments | All changed signatures | Compliant | Compliant |
| #3 Type annotations at boundaries | New public surfaces | Compliant | Compliant |
| #4 Logging coverage and correctness | `pf/jira/` no logger module | VIOLATION (architectural — no logger in jira package) | Same architectural pattern; not changed in round 2 — deferred. **Acknowledged as pre-existing** [SILENT][RULE] |
| #5 Path handling | pathlib + encoding | Compliant | Compliant |
| #6 Test quality | distinguishability shorts on helper-existence; missing payload assertion | VIOLATION | **Compliant** — re-RED rewrote the distinguishability test; round-2 added the dry-run payload-key assertion |
| #7 Resource leaks | pathlib + context managers | Compliant | Compliant |
| #8 Unsafe deserialization | safe_dump, no eval/exec | Compliant | Compliant |
| #9 Async/await | No async changes | N/A | N/A |
| #10 Import hygiene | No star imports; one-direction chain | Compliant | Compliant |
| #11 Input validation at boundaries | `create_epic_in_jira` bypassed `require_jira_project` | VIOLATION | **Compliant** in all changed files — guards present at `create.py:111` (story) + `create.py:228` (epic) + `epic.py:69` (payload). Off-diff M1 sites deferred to `152-2` per Architect disposition. |
| #12 Dependency hygiene | No new deps | Compliant | Compliant |
| #13 Fix-introduced regressions | Round-1 fix missed sibling | VIOLATION | **Compliant** — round-2 fix landed at sibling. Latent fragility at `epic.py:155` noted as LOW for `152-2`. |

### Other Required Coverage

**[VERIFIED] Round-1 F1 closed:** `create_epic_in_jira` per-site guard present at `pennyfarthing-dist/src/pf/jira/create.py:228` — `project_key = require_jira_project(JIRA_PROJECT)` inside try/except `JiraConfigError` returning `{success: False, error: str(e)}`. Mirrors `create_story_in_jira:111` pattern exactly. Subsequent uses of `project_key` (not raw `JIRA_PROJECT`) at lines 237 (JQL search) and 272 (create payload). Verified by direct file inspection on branch `feat/152-1-remove-mssci-hardcoding` @ `ed2267aae`.

**[VERIFIED] Round-1 F2 closed:** Hygiene case-sensitivity reconciled. At `pennyfarthing/tests/python/test_sprint_story_command.py:93` placeholder is `proj-00000`; the surrounding assertion at line 92 lowercases the captured output via `output = result.output.lower()`. Confirmed by TEA verify round-2 (line 725 of this session): "Verified incorrect: line 92 is `output = result.output.lower()` — the assertion correctly checks the lowercased output." The simplify-quality teammate's LOW finding was correctly dismissed. The hygiene-scan in `test_152_1_no_company_leakage.py` uses `re.IGNORECASE` for `FORBIDDEN_BRAND_NUMBER` and `FORBIDDEN_BRAND_STRING` and matches `FORBIDDEN_JIRA_KEY` (`MSSCI-NNNNN`) with explicit case-insensitivity per the round-1 prescription — both lowercase and uppercase variants would now be caught by the scan if reintroduced.

**[VERIFIED] Round-1 F3 closed:** TEA re-RED (round 2) rewrote the distinguishability test family. `test_jira_project_strict_helper_is_exposed` is a separate, narrow existence check. `test_jira_project_resolution_returns_sentinel_when_unset` independently verifies `_resolve_jira_config()` returns `(None, None)` (or raises) in a clean env. The OR-chain shortcut on `has_strict_helper` is gone; the resolver's return value is now actually inspected.

**[VERIFIED] Tests are GREEN at HEAD:** Preflight subagent confirmed 218/218 story-relevant tests pass. 21 pre-existing failures on `develop` baseline (test_141_20, test_143_*, test_148_23, test_peloton_pane_layout, test_pypi_packaging) are unchanged and unrelated.

**[VERIFIED] No new MSSCI / 1898 leakage introduced:** All MSSCI/1898 occurrences in the diff are line removals (scrubbing) or adversarial-fixture assertion strings in the hygiene-test file itself (correctly self-excluded via `SKIP_FILES`). Preflight smell scan returned 0.

**[VERIFIED] No new forbidden patterns:** No `console.log`, no `dangerouslySetInnerHTML`, no test skips without reason, no TODOs without ref, no hardcoded secrets, no unsanitized exec.

**[VERIFIED] Per-site guard auditability invariant preserved:** TEA verify round-2 explicitly declined the HIGH-confidence simplify-reuse finding to extract the guard helper across `create_story_in_jira`, `create_epic_in_jira`, and `build_epic_payload`. The per-site enumeration is the intended invariant — extraction would have hidden the very class of regression round 1 caught. Reviewer concurs: a future story should NOT extract this helper. Decision-of-record at TEA Assessment (verify, round 2) → Decision Rationale.

**[VERIFIED] M1 deferral correctly scoped:** Three subagents (`reviewer-type-design`, `reviewer-simplifier`, `reviewer-security`) independently flagged the off-diff `JIRA_PROJECT` sites at `cli.py:164,344` and `reconcile.py:114,139`. Architect's round-2 spec-check carry-over (line 681) names all four sites with severity disposition. The deferral is correctly framed as follow-up story `152-2` (proposed). All four sites fail with VISIBLE Jira-API errors when `JIRA_PROJECT` is empty (not silent defaults), so the round-1 F1 silent-fallback failure mode does not apply to them. Reviewer round-1 audit already stamped this deferral; round-2 audit re-stamps below.

### Tenant Isolation Audit

N/A. Story 152-1 does not introduce, modify, or affect any multi-tenant code paths. No `TenantId` parameters, no tenant-bearing structs, no trait methods that handle tenant data. The only data-handling additions are `JiraConfigError` (value-less exception type) and `require_jira_project` (string getter with empty-rejection). No tenant isolation boundary is at risk. Confirmed by `reviewer-security` analysis.

### Devil's Advocate

Suppose I'm a malicious user, or merely a confused developer. What in round-2 can I exploit or stumble into?

First, the off-diff sites at `cli.py:164,344` and `reconcile.py:114,139` still read bare `JIRA_PROJECT`. If I clear my Jira config and run `pf jira create standalone "fix"`, the framework will send `{"project": {"key": ""}}` to the Jira REST API; the API returns HTTP 400 and the framework surfaces `click.ClickException("Failed to create story: ...")`. This is a VISIBLE failure (not silent), but the error message is the Jira API response — not the framework's curated `JiraConfigError` guidance pointing me to `.pennyfarthing/config.local.yaml` or the `JIRA_PROJECT` env var. A new user would see a 400 and think their Jira credentials are wrong; the actual problem is config. Architect already disposed this as M1 deferral (severity: minor; out-of-scope; follow-up to `152-2`). I confirm: the failure mode is non-silent, so it does NOT replicate the round-1 F1 class. The deferral holds.

Second, can I exfiltrate the corporate identifier through a side channel? Two paths exist. (a) Git history: the `git log -p` of the framework repo includes commit `7522c99` with 33 lines of MSSCI in the committed blobs (security subagent confirmed). The hygiene test correctly scans live file content, not git history. If the repo is published publicly, anyone running `git log` recovers the corporate identifier. Round-1 Reviewer's Question finding (line 725) routed this to the user for a `git filter-repo` decision; not Reviewer's call to enforce. (b) Branch names in older merge commits: `1898andCo/feat/148-26-...` appears in merge-commit messages. Same disposition — out-of-scope, user-decision.

Third, can I confuse the fail-loud contract with a crafted config? Yes, several ways. (i) `JIRA_PROJECT=" "` (NBSP) — `str.strip()` does not remove NBSP, so the guard accepts it. Result: a malformed Jira API call instead of a clean `JiraConfigError`. (ii) `jira.project: 1234` in YAML — the integer flows through `or` chains, `value.strip()` raises `AttributeError`, propagates uncaught past callers that expect `JiraConfigError`. (iii) `JIRA_PROJECT="PROJ AND 1=1"` — passes the non-emptiness check, lands in JQL at `create.py:237`, broadens the duplicate-search scope. None of these are explicitly forbidden by the SM Assessment's "fail-loud requirement", which says "If config is missing the project key, framework must error with a clear message — never default to MSSCI or any other key." The current implementation honors the *missing* case; it does not honor the *malformed* case. This is a meaningful gap, but it is Medium severity (the round-1 RJECT class was *silent* fallback, and the round-2 contract handles silent fallback). Logged for `152-2`.

Fourth, can the duplicate-search idempotency check create a duplicate epic in a failure mode? Yes. If `search_issues_sync` returns a list where `existing[0]` is a dict without a `"key"` field (malformed API response, partial JSON, Jira server changes), `existing[0]["key"]` raises `KeyError` inside the bare-except at `create.py:262`. The except swallows the `KeyError`, emits "Jira search for duplicate titles failed" (a lie — the search succeeded; the parse failed), and falls through to create a new epic. The same failure mode applies to the `force=True` branch. The misleading warning makes diagnosis harder. Medium severity, logged for `152-2`.

Fifth, can I trip the test gate while leaking? The hygiene test excludes `.session/` (correct — gitignored runtime), but the orchestrator session file `.session/152-1-session.md` currently contains 31 live `MSSCI` occurrences and the test passes green. A future reader could mistake "test passes" for "tree is clean of MSSCI". Low severity, but worth a comment in the test asserting the exclusion is intentional. Logged for `152-2`.

Sixth, can the per-site guard pattern be undone by a well-intentioned refactor? Yes — if someone reads the three duplicate try/except blocks at `create.py:110-113`, `create.py:227-230`, and `epic.py:69` and "DRYs" them into a helper, the per-site auditability is destroyed and the round-1 F1 class becomes re-introducible. TEA verify round-2 explicitly logged a decision-of-record that this extraction must not be performed in any future story without revisiting the invariant. The session-file-as-coordination-layer principle (SOUL #5) makes this future-proof: anyone considering the extraction will encounter the decision-of-record in the session archive.

The trajectory is good: round 1 caught the in-file gap; round 2 closed it; round 2's adversarial sweep found only Medium-severity follow-up work. The pipeline corrected itself in one round-trip, and the corrections are framed correctly (per-site guards preserved, story scope respected, deferrals re-affirmed).

**Verdict:** APPROVED — no blockers; route to SM finish.

### Recommended Routing

**Hand off to SM (Captain Carrot Ironfoundersson) for finish-story.**

Pre-finish actions for SM:
1. Provision follow-up story `152-2` — *"Apply `require_jira_project()` to remaining `JIRA_PROJECT` call sites in `pf/jira/`; harden against malformed config (NBSP, non-string, format validation); fix duplicate-search KeyError; clean up cosmetic test gaps."* See `### Reviewer (code review)` round-2 entries below for the full scope list.
2. Create PR for `feat/152-1-remove-mssci-hardcoding` targeting `develop` (gitflow per `pennyfarthing` repo's branch strategy).
3. Run `pf sprint story finish 152-1` to archive session, transition Jira, clean up branch.

**Handoff:** To SM for finish-story.

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)

- **Question** (non-blocking): Does the user want `benchmarks/results/**` scrubbed of MSSCI references too?
  Affects `benchmarks/results/dpgd-116/**/pipeline.yaml` (~3 files contain `MSSCI` / `1898` from historical pipeline replays). These are committed run captures, not redistributed templates. The hygiene tests currently fail on them; Dev needs a decision: scrub them, exclude `benchmarks/results/` from the hygiene scan, or rerun the benchmarks against scrubbed input.
  *Found by TEA during test design.*

- **Gap** (non-blocking): Story title says "scrub templates and docs" but no per-story or epic context file exists at `sprint/context/context-story-152-1.md` / `sprint/context/context-epic-152.md`.
  Affects `sprint/context/` (no file to read for canonical AC list). TEA inferred ACs from the SM Assessment in the session file plus the user message. Recommend the SM populate context files for stories of this size in the future.
  *Found by TEA during test design.*

- **Improvement** (non-blocking): The hygiene scan would graduate well to a `pf validate` validator (e.g., `pf validate hygiene` or extending `pf validate context`) so the check runs on every PR rather than only when the test suite is invoked.
  Affects `pennyfarthing-dist/src/pf/validate/cli.py` (post-152-1 hardening; do not block this story on it).
  *Found by TEA during test design.*

- **Conflict** (non-blocking): `pf validate context-story 152-1` and `pf validate context-epic 152` both fail with `[ERROR] Unknown validator(s): context-story, 152-1` even though `pf validate context-story --help` lists both as registered subcommands. The Click subcommand routing for these two validators appears broken.
  Affects `pennyfarthing-dist/src/pf/validate/cli.py` (subcommand registration). Hit on activation while running the on-activation context-validation step from the TEA agent definition.
  *Found by TEA during test design.*

### Dev (implementation)

- **Question** (blocking-for-future-story): The orchestrator repo (the parent of the framework repo) contains the full `1898&co` brand string in `references.bib` and `docs/comparisons/bmad-vs-pennyfarthing.md`, plus references to `1898` as a port-convention identifier in `sprint/planning/bikerack-extraction-{epics,proposal}.md`. These are NOT scanned by Story 152-1's hygiene tests (the test scans `pennyfarthing/` framework repo only, per the SM Assessment "out of scope: stays in orchestrator").
  Affects orchestrator paths `references.bib`, `docs/comparisons/bmad-vs-pennyfarthing.md`, `sprint/planning/bikerack-extraction-epics.md`, `sprint/planning/bikerack-extraction-proposal.md` (≈30 occurrences total). If the orchestrator repo is meant to be public/redistributable, this is a leak surface that needs a follow-up story.
  *Found by Dev during implementation.*

- **Question** (non-blocking): Other Jira modules (`pf/jira/reconcile.py`, `pf/jira/cli.py`) reference `JIRA_PROJECT` directly in JQL queries and assignment-call payloads. They will silently emit `project= AND ...` if the constant is empty. Story 152-1 scope only required fail-loud at the two payload builders the TEA tests pinned (`build_epic_payload`, `create_story_in_jira`). A follow-up could call `require_jira_project()` at every `JIRA_PROJECT` usage site for consistent fail-loud behavior across the Jira CLI.
  Affects `pennyfarthing-dist/src/pf/jira/reconcile.py:114,139` and `pennyfarthing-dist/src/pf/jira/cli.py:164,344`. Out of scope for 152-1.
  *Found by Dev during implementation.*

- **Conflict** (non-blocking): During the testing-runner subagent's verification step the working git branch silently switched from `feat/152-1-remove-mssci-hardcoding` to `feature/test`. The cause is unclear — the subagent prompt did not request a branch operation. Recovered by stashing/checking out and re-applying the in-progress edits, but a leaked-side-effect from a subagent toolchain is concerning.
  Affects testing-runner subagent (or its tooling). Recommend the SM/orchestrator audit subagent git side-effects.
  *Found by Dev during implementation.*

- **Conflict** (blocking-for-process): Round 2 — the `testing-runner` subagent overwrote `.session/152-1-session.md` with a 73-line RED report, destroying all prior phase content (~480 lines: SM/TEA/Dev/Architect/Reviewer assessments, all delivery findings, all deviations). The same overwrite happened to `pennyfarthing/.session/152-1-session.md`. Because `.session/` is gitignored there is no git-history recovery; Dev reconstructed the file by replaying every Edit operation against the initial Read snapshot from `~/.claude/projects/.../*.jsonl`. The agent definition `pennyfarthing-dist/agents/testing-runner.md` must explicitly forbid writing to `.session/{story-id}-session.md`; the agent's prompt-template stating "Session file written to: ..." indicates a built-in behavior rather than a one-off mistake.
  Affects `pennyfarthing-dist/agents/testing-runner.md` (agent should write its summary to a sibling file like `.session/152-1-test-{run-id}.md` if it must persist, or just return the report as its tool result and not touch disk).
  *Found by Dev during round 2 implementation.*

- **Improvement** (non-blocking, round 2): The Reviewer LOW finding to remove the `FORBIDDEN_*` string concatenation trick is correct (`SKIP_FILES` already excludes the test file from self-match) but Dev opted to defer it. Rationale: the diff is smaller and lower risk if a third party still copies the pattern into a NEW hygiene test elsewhere; cleanup can land in a follow-up that simultaneously inlines the constants and audits any new hygiene tests for `SKIP_FILES` coverage. If the Reviewer prefers the cleanup land here, Dev will apply it.
  Affects `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py:29-31`.
  *Found by Dev during round 2 implementation (deferral note).*

- **Improvement** (non-blocking, round 2): The TEA re-RED list item 8 ("Add the missing `1898&co` bullet to the hygiene-test module docstring") was already addressed in TEA's round-2 module-docstring rewrite (line 250 of TEA Assessment round 2: "Module docstring rewritten to mention all three forbidden tokens"). No Dev action required — flagged here so Reviewer doesn't double-bill it.
  Affects `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py` (module docstring).
  *Found by Dev during round 2 implementation.*

### Architect (spec-check, round 2)

- **Improvement** (blocking-for-followup-story, non-blocking-for-152-1): Off-diff `JIRA_PROJECT` call sites at `pf/jira/cli.py:164` (`pf jira search` JQL), `pf/jira/cli.py:344` (`pf jira create standalone` payload), and `pf/jira/reconcile.py:114,139` (reconcile JQL) remain unguarded. The round-2 in-scope sweep guarded every site in the *changed files* (`create.py`, `epic.py`, `client.py`); these three files were not modified in this story. The most write-adjacent of these — `cli.py:344` `create_standalone` — is the same pattern as the round-1 F1 finding (raw `JIRA_PROJECT` in a Jira create payload), but its failure mode is non-silent (Jira API rejects empty `key` with HTTP 400, surfaced as `click.ClickException(f"Failed to create story: {response}")` at `cli.py:354`). Read-only sites (`cli.py:164`, `reconcile.py:114,139`) fail with visible API errors as well. **SM should provision a follow-up story** — proposed: 152-2 — *"Apply `require_jira_project()` to remaining `JIRA_PROJECT` call sites in `pf/jira/`"*. TEA tests should pin: (a) `pf jira create standalone` short-circuits on empty config (write-side regression coverage), and (b) JQL builders in `cli.py:164` + `reconcile.py:114,139` substitute the resolved project key (read-side regression coverage).
  Affects `pennyfarthing-dist/src/pf/jira/cli.py:164,344` and `pennyfarthing-dist/src/pf/jira/reconcile.py:114,139`. **Out-of-scope for 152-1; recommend SM provision follow-up before this story ships externally.**
  *Found by Architect during round-2 spec-check (carry-over from round-1 M1 deferral, re-affirmed with strengthened rationale).*

- **Improvement** (non-blocking, architectural): The `JIRA_PROJECT` module constant at `pf/jira/client.py:63` is exported as a public string and used by every Jira write path. The fail-loud contract is enforced by the *caller* discipline of wrapping it in `require_jira_project(JIRA_PROJECT)` at every use. A stronger architectural fix would rename the public symbol to `_JIRA_PROJECT_RAW` (private), remove it from `__init__.py:62`, and force all callers to go through a public `get_jira_project()` resolver that raises `JiraConfigError` if unset. This eliminates the foot-gun by construction rather than by callsite review. Out-of-scope for 152-1; suggested as part of the same follow-up story (152-2) that closes the off-diff sweep.
  Affects `pennyfarthing-dist/src/pf/jira/client.py:63`, `pennyfarthing-dist/src/pf/jira/__init__.py:41,62`, and every `from pf.jira.client import JIRA_PROJECT` consumer.
  *Found by Architect during round-2 spec-check (architectural-design observation).*

- **Question** (non-blocking, process): During round-2 testing-runner verification, the subagent **overwrote `.session/152-1-session.md` with a 73-line RED report** (also captured in Dev's round-2 Conflict finding above). The agent definition at `pennyfarthing-dist/agents/testing-runner.md` should explicitly forbid writes to `.session/{story-id}-session.md`. Recommendation: testing-runner returns its summary as the tool result only and never writes to `.session/`. If persistence is required for traceability, write to `.session/test-runs/{story-id}-{run-id}.md` (a sibling path), never to the canonical session file.
  Affects `pennyfarthing-dist/agents/testing-runner.md` (agent definition).
  *Found by Architect during round-2 spec-check (process-integrity observation).*

### TEA (verify, round 2)

- **Improvement** (non-blocking, follow-up): `_build_adf_description` (define in `pennyfarthing-dist/src/pf/jira/create.py:46-57`) is duplicated as inline ADF construction in `pennyfarthing-dist/src/pf/jira/epic.py:53-63`. Both build the same Atlassian Document Format wrapper around a plain-text description string. simplify-reuse flagged this as HIGH-confidence extractable. **Not applied in this story** because (a) it's pre-existing duplication, not introduced by 152-1; (b) round-1 verify already accepted it; (c) the move is not byte-mechanical (the two implementations differ — function vs. inline local); (d) story 152-1's scope is fail-loud Jira config and corporate-identifier scrub, not module-layout refactoring. Recommend a follow-up story to extract a shared `_build_adf_description` (or rename to public `build_adf_description`) into `pf/jira/client.py` or a new `pf/jira/_adf.py`.
  Affects `pennyfarthing-dist/src/pf/jira/create.py:46-57` and `pennyfarthing-dist/src/pf/jira/epic.py:53-63` (no action required for 152-1).
  *Found by TEA during round-2 verify (simplify-reuse subagent).*

- **Improvement** (non-blocking, architectural): simplify-reuse flagged the three `try: project_key = require_jira_project(JIRA_PROJECT) except JiraConfigError as e: return {"success": False, "error": str(e)}` blocks in `create_story_in_jira`, `create_epic_in_jira`, and (semantically equivalent) `build_epic_payload` for extraction into a shared helper. **Explicitly rejected** because the per-site guard pattern is the *intended* invariant — round-1 REJECT was caused by the absence of a guard at one site, and centralizing the guard would obscure the per-site auditability that Architect's spec-check enumeration depends on. This is a HIGH-confidence finding from simplify-reuse that I am formally declining; logged here so a future TEA/Architect/Reviewer reading the session understands the decline is deliberate, not an oversight. **Do not extract this helper in any future story without first revisiting the per-site auditability invariant.**
  Affects `pennyfarthing-dist/src/pf/jira/create.py:110-113,227-230` and `pennyfarthing-dist/src/pf/jira/epic.py:69` (no action required for 152-1 or for follow-ups).
  *Found by TEA during round-2 verify (simplify-reuse subagent); decision-of-record by TEA.*

- **Question** (non-blocking, follow-up): simplify-reuse MEDIUM finding suggested consolidating `except Exception:` patterns at `pennyfarthing-dist/src/pf/jira/client.py:36` (config-loading optional swallow) and `pennyfarthing-dist/src/pf/jira/create.py:262` (Jira duplicate-search best-effort swallow) into a shared safe-load helper. **Not applied in this story** because the two except blocks encode *different* error policies (one swallows missing-config, one swallows transient-Jira-failure) — collapsing them would conflate the policies and remove the per-call-site decision. If a future story unifies the framework's "swallow vs. propagate" policy across `pf/jira/`, this finding is the seed for that work.
  Affects `pennyfarthing-dist/src/pf/jira/client.py:36` and `pennyfarthing-dist/src/pf/jira/create.py:262` (no action required for 152-1).
  *Found by TEA during round-2 verify (simplify-reuse subagent).*

### Reviewer (code review)

- **Gap** (blocking, addressed by REJECT): Architect's spec-check M1 ("only 2 call sites guarded") missed `create_epic_in_jira` in the same file Dev modified. The deferral covered `reconcile.py`/`cli.py` (separate files, follow-up story scope) but did not enumerate `create.py:232,267` — the in-file sibling that was the most natural pair to the function Dev did patch. Architect spec-check should enumerate every `JIRA_PROJECT` usage site in changed files going forward.
  Affects `pennyfarthing/pennyfarthing-dist/src/pf/jira/create.py:232,267` (must be patched in this story before merge).
  *Found by Reviewer during code review (3 subagents convergent: silent-failure-hunter, type-design, edge-hunter, rule-checker).*

- **Gap** (blocking, addressed by REJECT): Hygiene MSSCI scan is case-sensitive while the brand scan is case-insensitive. A real lowercase corporate-key occurrence at `tests/python/test_sprint_story_command.py:93` survives the gate. Story's primary scrub deliverable is incomplete.
  Affects `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py:138` (add `ignore_case=True`) and `pennyfarthing/tests/python/test_sprint_story_command.py:93` (replace `mssci-00000` with generic).
  *Found by Reviewer during code review (security subagent).*

- **Gap** (blocking, addressed by REJECT): The fail-loud distinguishability test passes vacuously once `require_jira_project` exists on the module — even if `_resolve_jira_config` regresses to silent empty-string. The test's stated contract is not actually enforced.
  Affects `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_152_1_jira_project_fail_loud.py` (the `distinguishable` OR-chain).
  *Found by Reviewer during code review (test-analyzer + rule-checker convergent).*

- **Improvement** (non-blocking, follow-up): When the in-file fixes for create_epic_in_jira land, consider also addressing the Architect's deferred M1 (reconcile.py/cli.py JIRA_PROJECT usage) as a single coherent fail-loud sweep — splitting it across stories invites the same partial-coverage trap.
  Affects `pennyfarthing/pennyfarthing-dist/src/pf/jira/reconcile.py:114,139` and `pennyfarthing/pennyfarthing-dist/src/pf/jira/cli.py:164,344`.
  *Found by Reviewer during code review.*

- **Question** (non-blocking): Does the user want git history rewritten to remove MSSCI from past commit blobs? Reviewer-security flagged commit `7522c99` contains 33 lines with MSSCI in committed blobs; `git log -p | grep MSSCI` recovers the corporate identifier. Out of scope for this story unless the user opts in to a `git filter-repo` rewrite before any public push.
  Affects git history of `pennyfarthing` repo (not source files).
  *Found by Reviewer during code review (security subagent).*

#### Round 2

- **Improvement** (non-blocking, follow-up `152-2`): JQL injection surface — `pennyfarthing-dist/src/pf/jira/create.py:237` interpolates the epic `title` (read from sprint YAML) into `summary ~ "{title}"`. A `"` character in title would close the JQL string literal and allow predicate injection. Sprint YAML is developer-controlled (memory: `project_kanban` — sprints are local-only) so practical exploit risk is low; but the project rule on input validation at boundaries (Python lang-review #11) still applies. Recommend escaping `"` (or `\`) in `title` before interpolation, or using a structured search API.
  Affects `pennyfarthing-dist/src/pf/jira/create.py:237`.
  *Found by Reviewer during round-2 code review (security subagent).*

- **Improvement** (non-blocking, follow-up `152-2`): `require_jira_project()` validates only non-emptiness — it does not validate that the project key matches the Jira format (typically `^[A-Z][A-Z0-9]+$`). A `JIRA_PROJECT` env value like `PROJ AND 1=1` passes the guard and is interpolated unescaped into JQL.
  Affects `pennyfarthing-dist/src/pf/jira/client.py:43-57`.
  *Found by Reviewer during round-2 code review (security subagent).*

- **Improvement** (non-blocking, follow-up `152-2`): `str.strip()` strips ASCII whitespace only. A `JIRA_PROJECT=" "` (Unicode NBSP, U+00A0) — easy to introduce via copy-paste from web pages — passes the empty-check, is returned as the project key, and produces a malformed Jira API call instead of a clean `JiraConfigError`. Same problem applies to U+2003 EM SPACE, U+3000 IDEOGRAPHIC SPACE, etc.
  Affects `pennyfarthing-dist/src/pf/jira/client.py:51`.
  *Found by Reviewer during round-2 code review (edge-hunter subagent).*

- **Improvement** (non-blocking, follow-up `152-2`): Non-string config value (`jira.project: 1234` in YAML — integer) flows through the `or` chains in `_resolve_jira_config`, lands in `require_jira_project` as an int, raises `AttributeError` on `.strip()`. Callers catch `JiraConfigError` only — the `AttributeError` propagates uncaught and breaks the result-dict contract. Suggested fix: coerce to `str` early in `_resolve_jira_config`, or add `isinstance(value, str)` guard at the top of `require_jira_project`.
  Affects `pennyfarthing-dist/src/pf/jira/client.py:38, 51`.
  *Found by Reviewer during round-2 code review (edge-hunter + type-design convergent).*

- **Improvement** (non-blocking, follow-up `152-2`): Duplicate-search idempotency check in `create_epic_in_jira` has a latent fail-mode that creates a DUPLICATE epic. If `client.search_issues_sync` returns a list where `existing[0]` is a dict without a `"key"` field (malformed API response, Jira server changes, partial JSON), `existing[0]["key"]` raises `KeyError` inside the bare-except at `create.py:262`. The except swallows the `KeyError`, emits the misleading `"Jira search for duplicate titles failed"` warning (a lie — the search succeeded; the parse failed), and falls through to create a duplicate epic. Same misbehavior in the `force=True` branch at `create.py:258`.
  Affects `pennyfarthing-dist/src/pf/jira/create.py:240, 258`.
  *Found by Reviewer during round-2 code review (edge-hunter + silent-failure-hunter convergent).*

- **Improvement** (non-blocking, follow-up `152-2`): `create.py:262` bare-`except Exception` uses `warnings.warn()` which is silent under `-W ignore` or in CI environments where the warnings filter suppresses it. Network errors and auth failures are indistinguishable from "no duplicate found", so a 401 Unauthorized would silently fall through to a duplicate-create attempt. Recommend `logging.warning()` instead of `warnings.warn()` for visibility, and narrow the catch to `(httpx.HTTPError, OSError, subprocess.CalledProcessError)`.
  Affects `pennyfarthing-dist/src/pf/jira/create.py:262`.
  *Found by Reviewer during round-2 code review (silent-failure-hunter subagent).*

- **Improvement** (non-blocking, follow-up `152-2`): `create_epic_from_yaml` writeback (`epic.py:170`) silently swallows YAML-write failures (`PermissionError`, disk full, ruamel parse error) and records `result['jira_writeback'] = False`. The CLI `main()` checks only `result['success']`, so the user sees `"Created epic: PROJ-XXX"` with exit code 0 while the local sprint YAML is unchanged — silent divergence of two sources of truth. Pre-existing pattern, not introduced by 152-1, but now reachable through 152-1's `create_epic` path.
  Affects `pennyfarthing-dist/src/pf/jira/epic.py:158-172`.
  *Found by Reviewer during round-2 code review (silent-failure-hunter + edge-hunter convergent).*

- **Improvement** (non-blocking, follow-up `152-2` or trivial cleanup): Dead `import pytest` in hygiene-scan test file — no fixtures, no marks, no `pytest.raises` referenced. Copy-paste artifact.
  Affects `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py:28`.
  *Found by Reviewer during round-2 code review (test-analyzer subagent).*

- **Improvement** (non-blocking, follow-up `152-2`): `.session/` is correctly added to `SKIP_DIRS` (gitignored runtime), but the green hygiene-scan result is achieved while `.session/152-1-session.md` itself contains 31 live `MSSCI` occurrences. A future reader could mistake "test passes" for "tree is clean of MSSCI". Recommend an inline comment naming the gitignored-runtime exclusion in the test assertion message, or a separate sanity test that confirms `.session/` IS excluded by design.
  Affects `pennyfarthing-dist/src/pf/tests/test_152_1_no_company_leakage.py:41`.
  *Found by Reviewer during round-2 code review (test-analyzer subagent).*

- **Improvement** (non-blocking, follow-up `152-2`): Ghost reference to `get_jira_project` — `test_jira_project_strict_helper_is_exposed` accepts EITHER `require_jira_project` OR `get_jira_project` via `hasattr`; only `require_jira_project` exists on the module. Module docstring at line 427 lists both. The alternative name is never shipped. Either remove the alias from the docstring/test, or add a `get_jira_project` alias to `client.py` if intentional.
  Affects `pennyfarthing-dist/src/pf/tests/test_152_1_jira_project_fail_loud.py:427, 619`.
  *Found by Reviewer during round-2 code review (comment-analyzer subagent).*

- **Improvement** (non-blocking, follow-up `152-2`): `require_jira_project` docstring says "Pass an explicit value … to avoid re-resolving config." The description is subtly misleading: passing `value=""` does NOT re-resolve (the function raises directly on empty). Three-way contract is `truthy → skip`, `None → re-resolve`, `empty/whitespace → raise` — should be made explicit.
  Affects `pennyfarthing-dist/src/pf/jira/client.py:44-48`.
  *Found by Reviewer during round-2 code review (comment-analyzer subagent).*

- **Improvement** (non-blocking, follow-up `152-2`): `build_epic_payload` `Raises:` docstring references "Story 152-1". Story IDs are local sprint-tracking artifacts, not stable cross-repo identifiers; a redistributable framework's public API docstring should not point to a sprint slug. Strip the story reference; keep only the behavioral contract.
  Affects `pennyfarthing-dist/src/pf/jira/epic.py:50-53`.
  *Found by Reviewer during round-2 code review (comment-analyzer subagent).*

- **Improvement** (non-blocking, follow-up `152-2`): `test_jira_project_resolution_returns_sentinel_when_unset` has an early-return path with no assertion if `_resolve_jira_config` raises for any unrelated reason. Mitigated by the separate `test_jira_project_strict_helper_is_exposed`, but contract verification is not local. Add a positive assertion on what was raised or what was returned.
  Affects `pennyfarthing-dist/src/pf/tests/test_152_1_jira_project_fail_loud.py:180-188`.
  *Found by Reviewer during round-2 code review (rule-checker subagent).*

- **Improvement** (non-blocking, follow-up `152-2`): `create_epic_from_yaml` has no try/except wrapping its `create_epic()` call. Current behavior is correct (the inner function catches `JiraConfigError` and returns `{success: False}`), but a future refactor that moves the guard elsewhere would let the exception propagate uncaught to `main()`. Add a defensive try/except at the orchestrator boundary.
  Affects `pennyfarthing-dist/src/pf/jira/epic.py:155`.
  *Found by Reviewer during round-2 code review (rule-checker subagent).*

- **Confirmation** (non-blocking, M1 deferral re-affirmation): Three round-2 subagents (`reviewer-type-design`, `reviewer-simplifier`, `reviewer-security`) independently flagged the off-diff `JIRA_PROJECT` call sites at `cli.py:164,344` and `reconcile.py:114,139`. All three findings are re-affirmations of Architect's round-1 M1 deferral, already accepted by Reviewer round-1 audit (line 763), and already documented as round-2 carry-over by Architect (line 681). The proposed follow-up story `152-2` should absorb all round-2 Improvement findings above plus the M1 unguarded sites. Reviewer concurs with Architect's disposition: these sites fail with VISIBLE Jira-API errors (not silent defaults), so the round-1 F1 silent-fallback class does not replicate to them. No round-2 blocking action required.
  Affects `pennyfarthing-dist/src/pf/jira/cli.py:164, 344` and `pennyfarthing-dist/src/pf/jira/reconcile.py:114, 139` (out of scope for 152-1; rolled into proposed `152-2`).
  *Found by Reviewer during round-2 code review (type-design + simplifier + security convergent re-affirmation).*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)

- No deviations from spec.

### Architect (spec-check)

- No new deviations introduced at spec-check. Four mismatches recorded in the Architect Assessment above are all classified as Defer (M1, M2) or Accept (M3, M4); each maps to an existing in-flight deviation logged by TEA or Dev or to the deferred-follow-up Question logged by Dev. No spec authority conflicts requiring escalation.

#### Round 2

- **M1 deferral re-affirmed for round 2 (off-diff `JIRA_PROJECT` sites)**
  - Spec source: SM Assessment in session file (line 67) — *"Fail-loud requirement: No silent fallbacks. If config is missing the project key, framework must error with a clear message — never default to MSSCI or any other key."*
  - Spec text: as quoted above; story scope did not enumerate specific call sites, and TEA tests do not pin `cli.py` or `reconcile.py`.
  - Implementation: `cli.py:164` (`pf jira search` JQL), `cli.py:344` (`pf jira create standalone` payload), and `reconcile.py:114,139` (reconcile JQL) remain unguarded after round 2. The in-file sweep across changed files (`create.py`, `epic.py`, `client.py`) is complete.
  - Rationale: All four off-diff sites fail with visible Jira-API errors, not silent defaults — `cli.py:344` raises `click.ClickException` on the 400 response from `client.create_issue_sync`, the JQL paths hit Jira's malformed-query handler. None replicate the silent-empty-search-results failure mode of round-1 F1. Pulling these in-scope would require TEA re-RED + Dev round-3 + Reviewer round-3 (consuming round-trip 2 of 3 on a non-silent issue) and would change the story shape after the fact. Deferral is correctly framed as a follow-up story (proposed: 152-2) requested in `### Architect (spec-check, round 2)` under Delivery Findings.
  - Severity: minor (story-internal); minor-to-medium for the proposed 152-2 follow-up.
  - Forward impact: medium — until 152-2 lands, `pf jira create standalone` with no JIRA_PROJECT configured will hit the Jira REST 400 path rather than a clean `JiraConfigError`. The user-visible error message is the Jira server response, not the framework's curated guidance. Acceptable interim behavior; the reverberation risk to sibling stories in epic-152 is low because `create_standalone` is not on any other story's critical path.

- **No new architectural-design deviations at round-2 spec-check.** Round 2's polish items (whitespace strip, `or {}`, bare-except inline comment, docstring `Raises:`, dry-run payload assertion, lowercase placeholder) are all minor refinements that mirror Reviewer prescriptions exactly. No spec authority conflicts.

### Reviewer (audit)

Stamping each in-flight deviation:

- **TEA M1 deviation** (no deviations from spec recorded at red phase) → ✓ ACCEPTED by Reviewer: Igor's red-phase coverage was tightly aligned to the SM Assessment scope; absence of deviation is consistent with what was tested.
- **Dev (Pre-existing test pinned silently-empty project key — updated to use a configured key)** → ✓ ACCEPTED by Reviewer: the monkeypatch update is minimal and correct; the new assertion `payload["fields"]["project"]["key"] == "PROJ"` was added.
- **Dev (`.session/` added to hygiene-scan skip list)** → ✓ ACCEPTED by Reviewer: `.session/` is gitignored framework-wide; excluding it from the hygiene scan is correct. Verified entry is present in `SKIP_DIRS` at `test_152_1_no_company_leakage.py:36`.
- **Architect (no new deviations at spec-check)** → ✓ ACCEPTED by Reviewer: but see "Reviewer-found undocumented deviations" below — the architect's M1 ("only 2 call sites guarded") deferred reconcile.py and cli.py but did NOT enumerate `create_epic_in_jira` in create.py (same file as the patched function). This was a missed enumeration during spec-check.
- **TEA verify (Added try/except around build_epic_payload in create_epic)** → ✓ ACCEPTED by Reviewer: simplify-quality fix correctly bridges the transformer/orchestrator boundary; verified at `epic.py:91-95`. The try/except is correctly typed to catch only `JiraConfigError` (not all exceptions).

**Reviewer-found undocumented deviations:**

- **`create_epic_in_jira` in `create.py` left unguarded despite same-file fail-loud refactor:** Spec said *"never default to MSSCI or any other key"*; code at `create.py:232,267` builds a Jira JQL search and create payload using raw `JIRA_PROJECT` without `require_jira_project()`. Architect M1 noted similar gaps in `reconcile.py`/`cli.py` and deferred them, but did NOT enumerate this in-file sibling. Severity: HIGH. Logged as F1 in Reviewer Assessment.

- **Hygiene scan is case-asymmetric:** Spec said *"scrub all references"*; the brand-string scan is case-insensitive but the corporate-key scan is case-sensitive. `mssci-00000` (lowercase) at `tests/python/test_sprint_story_command.py:93` survives the gate. Severity: HIGH. Logged as F2 in Reviewer Assessment.

- **Test `distinguishable` boolean shorts on helper-existence:** Test docstring claims to verify resolver returns sentinel; in fact passes vacuously once the helper is present. Severity: HIGH. Logged as F3 in Reviewer Assessment.

#### Round 2

Stamping each in-flight deviation introduced or re-affirmed in round 2:

- **Architect M1 round-2 carry-over (off-diff `JIRA_PROJECT` sites at `cli.py:164,344` and `reconcile.py:114,139`)** → ✓ ACCEPTED (re-stamp) by Reviewer round-2: independently flagged by three round-2 subagents (type-design, simplifier, security); Architect's disposition (Major severity, D-Defer to follow-up story `152-2`) is correct — the four sites fail with VISIBLE Jira-API errors (HTTP 400 / malformed-query response) rather than silent defaults, so the round-1 F1 silent-fallback failure mode does not replicate. The deferral correctly framed as a follow-up story. Reviewer round-1 audit already accepted this; round-2 audit re-affirms. **SM should provision `152-2` before this story ships externally.**
- **Architect (proposed renaming `JIRA_PROJECT` to private `_JIRA_PROJECT_RAW` + public `get_jira_project()` resolver)** → ✓ ACCEPTED by Reviewer round-2 as architectural follow-up: this would eliminate the foot-gun by construction rather than by callsite review, and pairs naturally with the M1 sweep in `152-2`. Out-of-scope for `152-1`.
- **Architect (testing-runner overwrote `.session/152-1-session.md`)** → ✓ ACCEPTED by Reviewer round-2 as process-integrity concern: agent definition at `pennyfarthing-dist/agents/testing-runner.md` should be hardened to forbid writes to canonical session files. This is a framework-process bug, not a 152-1 deliverable; Architect's recommendation is sound. Reviewer concurs and notes this should be a separate story (proposed `152-3` or similar) since it touches agent definitions, not Jira logic.
- **TEA verify round-2 (no code changes; declined two HIGH-confidence simplify-reuse findings — guard helper extraction + ADF builder move)** → ✓ ACCEPTED by Reviewer round-2:
  - **Decline of guard-helper extraction**: Reviewer concurs that per-site auditability is the intended invariant. Extracting the helper would have hidden the very class of regression round 1 caught at `create_epic_in_jira`. The decision-of-record at TEA Assessment (verify, round 2) → Decision Rationale, Finding 1 is correct and binding. **Future stories MUST NOT extract this helper without revisiting the invariant.**
  - **Decline of `_build_adf_description` move**: Pre-existing duplication, not introduced by 152-1; out-of-scope refactor. Acceptable for a follow-up story dedicated to module layout.
- **TEA verify round-2 (Step 7 regression detection skipped because no changes were applied; bare-except consolidation MEDIUM finding declined)** → ✓ ACCEPTED by Reviewer round-2: predicate-skip is correctly reasoned (testing-runner session-overwrite hazard is real; codebase byte-identical means re-running tests adds zero signal). The bare-except consolidation decline is correctly framed (the two except blocks encode different error policies; merging them would conflate intents).
- **Dev round-2 deferral of LOW Reviewer finding (FORBIDDEN_* concat trick)** → ✓ ACCEPTED by Reviewer round-2: Reviewer round-1 marked this as LOW/optional and explicitly "Optional cleanup". Dev's deferral rationale (defense-in-depth against new hygiene-test authors who forget `SKIP_FILES`) is reasonable. Not blocking. Cleanup can land in `152-2`.

**Reviewer-found undocumented deviations (round 2):**

- **None new.** All round-2 mismatches against spec are either (a) re-affirmations of M1 (deferred), (b) pre-existing patterns surfaced by adversarial subagents but not introduced by 152-1, or (c) Medium/Low severity new findings that are now logged as Improvements under `### Reviewer (code review)` → `#### Round 2` for `152-2`. No new HIGH-severity undocumented deviations were found.

### TEA (re-RED, round 2)

- No new spec deviations; this round strengthens existing test contracts and adds one new test (`test_create_epic_in_jira_fails_loud_when_project_unconfigured`) that pins behaviour explicitly required by the SM Assessment's "Fail-loud requirement" but missed in round 1's test design. The round-1 absence of a test for the sibling function constituted a test-coverage gap, not a spec deviation; documenting here for traceability.

### TEA (verify)

- **Added try/except around `build_epic_payload` in `create_epic` orchestrator**
  - Spec source: SOUL.md principle #10 ("Return Results, Don't Throw"); the `create_epic` docstring contract `Returns: Result dict with success, key, error fields`
  - Spec text: *"Functions return `{success, data?, error?}` so every failure is visible and every caller decides what it means."*
  - Implementation: `create_epic` previously called `build_epic_payload` without exception handling; the new fail-loud `JiraConfigError` would propagate past it, breaking the result-dict contract. Wrapped the call in try/except returning `{success: False, error: str(e)}` to match the `create_story_in_jira` pattern.
  - Rationale: Surfaced by simplify-quality as a high-confidence error-handling-gap. Applying the fix in the orchestrator (not the transformer) preserves Igor's TEA test contract (`build_epic_payload` raises) while also satisfying SOUL #10 at the call boundary.
  - Severity: minor
  - Forward impact: none — refines an internal error-handling consistency, no API or test contract change.

#### Round 2

- **Declined two HIGH-confidence simplify-reuse findings (per-site guard helper extraction; ADF-builder move)**
  - Spec source: simplify-workflow Step 5 — *"For each finding with confidence: high: 1. Read the file at the specified line; 2. Apply the suggestion (edit the file); 3. Track what was changed and why."* (`pennyfarthing-dist/agents/tea.md` <verify-workflow> Step 5).
  - Spec text: as quoted above; the workflow's default action for HIGH-confidence findings is auto-apply.
  - Implementation: I declined both HIGH-confidence findings. Finding 1 (extract guard helper across `create_story_in_jira:110-113`, `create_epic_in_jira:227-230`, `build_epic_payload:69`) was rejected because per-site auditability is the *intended* invariant and round-1 REJECT was caused by exactly the absence of a per-site guard that a helper would obscure. Finding 2 (move `_build_adf_description` from `create.py` to a shared utility) was rejected because the duplication is pre-existing (not round-2-introduced), round-1 verify already accepted it, and the move is not byte-mechanical. Both decisions are documented in detail in TEA Assessment (verify, round 2) → Decision Rationale, and as Improvement findings in Delivery Findings → TEA (verify, round 2). Codebase is byte-identical to Dev's GREEN state; Step 7 regression detection is a no-op by predicate.
  - Rationale: Auto-applying these would (a) re-litigate round-1-accepted patterns; (b) inflate the round-2 diff with unrelated refactors; (c) for Finding 1 specifically, work *against* the Reviewer/Architect's per-site enumeration invariant that just landed in round-2 fixes; (d) consume scarce round-trip budget on cosmetic refactors when round 2 of 3 is already in flight. The simplify-workflow's default auto-apply behavior assumes findings target *the current story's diff*; round-2 verify must distinguish "round-2 over-reach" from "pre-existing duplication that has always been there." The latter is out-of-scope.
  - Severity: minor (process-level; no functional or test-contract change)
  - Forward impact: none for 152-1; future stories that touch these files should NOT extract the per-site guard helper (it would re-create the round-1 REJECT class). The ADF-builder move is acceptable for a follow-up story dedicated to module layout.

- **Skipped Step 7 regression detection because no changes were applied**
  - Spec source: simplify-workflow Step 7 (`pennyfarthing-dist/agents/tea.md` <verify-workflow>): *"After applying changes, re-run quality checks…"*
  - Spec text: as quoted above; the trigger is "after applying changes."
  - Implementation: No changes applied (previous deviation), so the trigger predicate is false. Skipped Step 7 invocation entirely. Codebase is byte-identical to Dev's round-2 GREEN testing-runner verification (53/53 story-152-1 tests passing); the unchanged-codebase invariant subsumes regression detection.
  - Rationale: Re-running the testing-runner subagent on an unchanged codebase would burn time and risk re-triggering the session-overwrite bug that Architect logged in `### Architect (spec-check, round 2)` Delivery Findings. The verify protocol's intent (catch regressions introduced by simplify edits) is moot when no edits were made.
  - Severity: minor
  - Forward impact: none — Reviewer can re-verify GREEN if desired by running pytest directly without spawning testing-runner.

- **Pre-existing test pinned silently-empty project key — updated to use a configured key**
  - Spec source: `test_152_1_jira_project_fail_loud.py::test_build_epic_payload_fails_loud_when_project_unconfigured`
  - Spec text: payload builders must refuse to emit `{"project": {"key": ""}}`
  - Implementation: `test_jira_package.py::test_build_epic_payload` and `test_create_epic_dry_run` previously called `build_epic_payload`/`create_epic` without configuring a project key. After the fail-loud change those tests would raise `JiraConfigError`. Updated both to `monkeypatch.setattr(epic_module, "JIRA_PROJECT", "PROJ")` so they exercise the configured-key path; assertions on the resulting payload preserved.
  - Rationale: The new contract is correct (don't allow empty project keys). The pre-existing tests captured the old buggy behavior implicitly. Patching them is in-scope for the same change.
  - Severity: minor
  - Forward impact: none — pre-existing tests now match the new contract.

- **`.session/` added to hygiene-scan skip list**
  - Spec source: `test_152_1_no_company_leakage.py::test_no_corporate_jira_key_in_framework_redistributables`
  - Spec text: hygiene scan walks every redistributable file in the framework repo
  - Implementation: Added `".session"` to `SKIP_DIRS`. The framework repo's `.session/` directory is gitignored (`.gitignore:81: .session/*`), so it is not redistributed; scanning it caused false positives on session-file content that documents the scrub work itself.
  - Rationale: SKIP_DIRS already excludes other gitignored runtime artifacts (`__pycache__`, `.venv`, `.pytest_cache`); `.session/` belongs in the same category. The hygiene contract is "no leakage in redistributables", and gitignored runtime files are not redistributables.
  - Severity: minor
  - Forward impact: none — Reviewer/SM should still verify nothing in `.session/` ships via build/packaging.

#### Round 2

- **Whitespace stripping in `require_jira_project` is broader than the Reviewer fix dictated**
  - Spec source: Reviewer M-finding "`require_jira_project` doesn't strip whitespace; a config value of `"  "` passes `if not value` and is returned as the project key"
  - Spec text: *"Change to `if not (value and value.strip())`; assign `value = value.strip()` before return."*
  - Implementation: Applied the Reviewer fix verbatim — `if not (value and value.strip())` raises `JiraConfigError` and `return value.strip()` removes leading/trailing whitespace from a valid key. Note: this also normalizes a key entered as `"  PROJ  "` to `"PROJ"`, which is a behavior addition beyond rejecting empty whitespace. Acceptable because Jira project keys are never legitimately whitespace-padded.
  - Rationale: Mirrors the Reviewer's prescribed fix exactly; the additional normalization is a side-benefit that hardens against config typos.
  - Severity: minor
  - Forward impact: none — no caller relies on whitespace-padded project keys.

- **`config.get("jira") or {}` swallows a malformed-config sentinel that the bare `except` was previously catching**
  - Spec source: Reviewer M-finding "`config.get("jira", {})` returns `None` (not `{}`) when YAML has `jira:` with a null value, then `jira_cfg.get("project")` raises `AttributeError`. The bare `except` rescues it but masks the malformed-config condition."
  - Spec text: *"Change to `jira_cfg = config.get("jira") or {}` to handle null cleanly without relying on the broad except."*
  - Implementation: Applied verbatim. The bare `except Exception:` now only catches truly exceptional config-loading failures (file unreadable, YAML parse error) — a null-valued `jira:` key flows through cleanly without exercising the except path.
  - Rationale: Reviewer-prescribed fix; Dev did not narrow the bare except (still catches all of `Exception` per the Reviewer's separate inline-comment suggestion, which Dev applied as documentation rather than narrowing).
  - Severity: minor
  - Forward impact: none — error semantics are unchanged for non-null configs; the null-config path is now slightly more readable.

- **Reviewer LOW finding "FORBIDDEN_* concat is unnecessary" intentionally not applied**
  - Spec source: Reviewer LOW finding (simplifier subagent) — *"`FORBIDDEN_*` string concatenation (`"MS" + "SCI"`) is unnecessary because `SKIP_FILES` already excludes the test file itself."*
  - Spec text: *"Optional cleanup: write the constants as plain strings; remove the comment about 'Constructed to avoid self-match'."*
  - Implementation: Not applied. Concatenation left in place; Reviewer marked this as LOW/optional. See round-2 Improvement finding above for rationale (defense-in-depth against new hygiene tests forgetting to add themselves to `SKIP_FILES`).
  - Rationale: Cost/benefit — applying a LOW cleanup widens the diff and risks reintroducing a self-match if a future hygiene test is added without `SKIP_FILES` discipline. Reviewer's prescription was explicitly "Optional cleanup".
  - Severity: minor
  - Forward impact: minor — if a future hygiene test author forgets `SKIP_FILES`, the concat trick still neutralizes self-match; if the Reviewer wants this cleanup mandatory, Dev will apply it on a re-review.

### Architect (reconcile)

**Context loaded:**
- Story scope: SM Assessment in session file lines 44-69 (no separate `sprint/context/context-story-152-1.md` exists — confirmed by `ls sprint/context/`).
- Epic shard: `sprint/epic-152.yaml` — Story 152-2 is already provisioned (title: *"Gate jira-cli lookups on jira.enabled config; skip assignee lookup for non-jira stories"*, 3 points, P1, backlog).
- PRD references: none in story or epic context; the SM Assessment is the canonical spec source for 152-1.
- Sibling story ACs: 152-2 scope (jira.enabled gating + assignee-lookup skip) overlaps with — but does NOT fully absorb — Reviewer round-2 follow-up findings.
- In-flight deviation logs: TEA (test design + re-RED + verify + verify round 2), Dev (implementation + round 2), Architect (spec-check + spec-check round 2), Reviewer (audit + audit round 2). All present and substantive.
- AC accountability: Implicit-AC table at session line 82 — 7 implicit ACs, all marked DONE by TEA verify round-2's 53/53 GREEN confirmation. **No deferrals.** Step 3 (AC-deferral verification) is a no-op.

**Existing deviation audit:**

I reviewed every entry in `### TEA (test design)`, `### Architect (spec-check)` (+ Round 2), `### Reviewer (audit)` (+ Round 2), `### TEA (re-RED, round 2)`, `### TEA (verify)` (+ Round 2), and the Dev-authored round-2 deviations. Each entry has:
- a real spec source that exists (SOUL.md, SM Assessment, agent definitions, lang-review/python.md, simplify-workflow, Reviewer findings)
- accurate quoted spec text
- implementation description matching what the code actually does (verified by spot-reading `client.py:36-57`, `create.py:111,228`, `epic.py:69-78`)
- forward impact accurately reflects downstream stories (M1 forward impact correctly names sibling story 152-2 by ID; the proposed scope expansion is correctly framed as needing SM action)
- all 6 fields present and substantive — no placeholder text

**No corrections needed on existing entries.** TEA verify round-2's decision-of-record on the per-site guard helper extraction is correctly framed and binding on future stories. Architect spec-check M1 disposition (D — Defer) is correctly tied to follow-up story 152-2. Reviewer round-1 F1/F2/F3 verdicts are correctly closed by round-2 evidence (verified during round-2 review).

**Missed deviations (added below):**

Four Medium-severity deviations from the SM Assessment's "Fail-loud requirement" spec are NOT logged by TEA/Dev/Reviewer-as-deviations (they appear as Improvement findings under Delivery Findings but not under Design Deviations). They emerge from the round-2 adversarial sweep and represent implicit implementation choices (validate-against-emptiness only, no format/type validation) that constitute partial fulfillment of the spec. Logging them here in 6-field format so the deviation manifest is complete and self-contained.

- **`require_jira_project` accepts non-ASCII whitespace, treating it as a valid project key**
  - Spec source: SM Assessment (session line 67) — *"Fail-loud requirement: No silent fallbacks. If config is missing the project key, framework must error with a clear message — never default to MSSCI or any other key."*
  - Spec text: as quoted above; "missing the project key" was implicitly broadened by Reviewer round-1 prescription (*"require_jira_project doesn't strip whitespace; a config value of `"  "` passes `if not value` and is returned as the project key"*) to include whitespace-only values.
  - Implementation: `pennyfarthing-dist/src/pf/jira/client.py:51` — `if not (value and value.strip()):` uses Python `str.strip()`, which strips ASCII whitespace (space, tab, CR, LF, FF, VT) but does NOT strip non-ASCII whitespace (U+00A0 NBSP, U+2003 EM SPACE, U+3000 IDEOGRAPHIC SPACE, etc.). A `JIRA_PROJECT=" "` env value (easy to introduce via copy-paste from rich-text sources) passes the guard, is returned as `" "`, and lands in Jira API payloads — producing a malformed REST call (likely HTTP 400 with an opaque server message) rather than a clean `JiraConfigError`.
  - Rationale: Round-1 Reviewer M-finding focused on ASCII whitespace only. The fix landed in round 2 mirrors that prescription verbatim. Extending the guard to all Unicode whitespace categories would require an `unicodedata`-aware check — a non-trivial spec extension that was not requested in round 1. Implicitly deferred during round-2 Dev; not flagged by TEA verify round 2 or by Reviewer round 1.
  - Severity: medium (Reviewer round-2 classification preserved)
  - Forward impact: medium — until 152-2 (or a follow-up) lands, a Unicode-whitespace-corrupted `JIRA_PROJECT` env var produces an opaque Jira API error instead of a curated framework error. Practical likelihood is low (most users won't paste NBSP into env vars); but the spec's "fail loud" intent is not honored for this edge.

- **`require_jira_project` raises `AttributeError` instead of `JiraConfigError` for non-string config values**
  - Spec source: SOUL.md principle #10 (*"Return Results, Don't Throw"*) AND the implicit contract of the new `require_jira_project` fail-loud exception ("raise `JiraConfigError`, not arbitrary exceptions").
  - Spec text: *"Functions return `{success, data?, error?}` so every failure is visible and every caller decides what it means."* The contract of `require_jira_project` (per its docstring at `client.py:43-48` and the new typed `JiraConfigError`) is that fail-loud means `JiraConfigError`, not any other exception type. Callers in `create.py:112` and `create.py:229` catch `JiraConfigError` only.
  - Implementation: `pennyfarthing-dist/src/pf/jira/client.py:38` — `jira_cfg.get("project") or os.environ.get("JIRA_PROJECT") or None` returns whatever value YAML loaded. If `jira.project: 1234` (integer in YAML), the `or` chain returns the integer; `JIRA_PROJECT: str = _resolved_project or ""` at line 63 then stores the integer (the `: str` annotation is not runtime-enforced); `require_jira_project(value)` at line 51 calls `value.strip()` on the int, raising `AttributeError`. Callers catch only `JiraConfigError`; the `AttributeError` propagates uncaught, breaking the `{success, error}` result-dict contract that callers expect.
  - Rationale: The implementation assumed config values would always be strings (a YAML-shape assumption). The round-1 spec did not pin "validate config value type"; round-2 Reviewer (edge-hunter + type-design convergent) surfaced the gap. Not logged by TEA or Dev as a deviation because both treated the YAML as developer-controlled and well-formed.
  - Severity: medium (Reviewer round-2 classification preserved)
  - Forward impact: medium — a malformed YAML config (`jira.project: 1234`) produces an unhandled `AttributeError` with a Python traceback rather than a curated `JiraConfigError`. User experience is degraded; result-dict contract is violated. Fixed by `isinstance(value, str)` guard at the top of `require_jira_project`, or by coercing to `str` early in `_resolve_jira_config`. Out-of-scope for 152-1; rolled into proposed scope expansion of 152-2 per Reviewer round-2 Improvement findings.

- **`require_jira_project` does not validate Jira project-key format (regex)**
  - Spec source: SM Assessment (session line 67) "fail-loud requirement" + Python lang-review #11 (*"User input MUST be validated before use (length, type, range)"*).
  - Spec text: *"never default to MSSCI or any other key"* — implies "do not accept arbitrary strings as project keys"; lang-review #11 explicitly requires input validation at boundaries.
  - Implementation: `pennyfarthing-dist/src/pf/jira/client.py:43-57` — `require_jira_project` validates only non-emptiness (`if not (value and value.strip())`) and returns the stripped value. It does NOT validate that the value matches the Jira project-key format (typically `^[A-Z][A-Z0-9]+$`). A `JIRA_PROJECT="PROJ AND 1=1"` env value passes the guard, lands in JQL at `create.py:237` (`f'project = {project_key} AND issuetype = Epic AND summary ~ "{title}"'`) unescaped, and broadens the duplicate-search scope (potential JQL-injection vector — see also Reviewer round-2 security finding on `title` interpolation).
  - Rationale: TEA's test design for round 1 pinned the "empty key" case but did not pin "malformed key" cases. Dev implemented to the test, not to the broader spec intent. The spec is interpretable either way ("missing" could mean only-when-absent OR also-when-malformed); the implementation chose the narrower reading. Round-2 Reviewer flagged this as Medium severity, not blocking, because no round-1 test pinned the broader contract.
  - Severity: medium
  - Forward impact: medium — combined with the JQL-injection surface at `create.py:237`, this enables a developer-controlled (sprint YAML / env var) JQL-injection vector. Practical exploit risk is low (developers control their own configs), but the input-validation rule applies. Out-of-scope for 152-1; rolled into 152-2 scope expansion.

- **Pre-existing `existing[0]["key"]` `KeyError` swallowed by bare-except — silent duplicate-epic creation in malformed-API-response failure mode**
  - Spec source: SOUL.md principle #10 (*"Return Results, Don't Throw"*) + ADR-0022 idempotency contract (the duplicate-search exists specifically to avoid duplicate-epic creation).
  - Spec text: SOUL #10 *"every failure is visible and every caller decides what it means"*; ADR-0022 idempotency *"prevent duplicate epic creation by searching for matching titles before creating"*.
  - Implementation: `pennyfarthing-dist/src/pf/jira/create.py:240, 258` — `existing[0]["key"]` accesses a dict that may or may not have a `"key"` field. If Jira returns a malformed search result (server changes, partial JSON, parsing edge), the `KeyError` is caught by the outer bare-except at line 262, which emits a misleading `"Jira search for duplicate titles failed"` warning (the search succeeded; the parse failed) and falls through to create a duplicate epic — the exact failure mode ADR-0022 was written to prevent. Same misbehavior in the `force=True` branch at line 258.
  - Rationale: Pre-existing code pattern not introduced by 152-1. The round-1 REJECT was focused on the empty-project-key class; the round-2 fix did not change `create.py:240` or the bare-except at line 262. Implicitly accepted by Dev round-2 (no change) and TEA verify round-2 (no change applied; codebase byte-identical). Round-2 Reviewer surfaced this via edge-hunter + silent-failure-hunter convergent finding.
  - Severity: medium
  - Forward impact: medium — until follow-up lands, a malformed Jira search response can cause duplicate epic creation with a misleading log message. The likelihood is low (Jira API responses are stable), but the impact is data-shape (duplicate Jira issue) rather than just user-visible error. Logged as Improvement for 152-2 by round-2 Reviewer.

**AC accountability verified — no deferrals.** All 7 implicit ACs from the TEA red-phase table (session line 82) are DONE per TEA verify round-2's 53/53 GREEN confirmation. No AC was deferred or descoped during this story. Reviewer round-2 did not invalidate any AC. AC-deferral verification is a no-op.

**Architect reconcile decision:**

The deviation manifest is now complete. All in-flight deviations are accurately documented; four newly-surfaced spec deviations from round-2 adversarial review are added above in 6-field format. The story is in a clean state for SM finish, with all in-scope work delivered and all out-of-scope work (M1 carry-over, Medium-severity follow-ups) correctly framed for 152-2 or future scoping.

**Note on 152-2 scope:** The current `sprint/epic-152.yaml` defines 152-2 as *"Gate jira-cli lookups on jira.enabled config; skip assignee lookup for non-jira stories"* (3 points, P1, backlog). This title does NOT fully cover the M1 carry-over (off-diff `JIRA_PROJECT` guards in `cli.py`/`reconcile.py`) or the round-2 Improvement findings (malformed-config hardening, JQL-injection mitigation, duplicate-search `KeyError`, cosmetic test gaps). **Recommendation to SM:** either (a) expand 152-2's scope to absorb the four Medium-severity deviations and the LOW Improvements, or (b) provision an additional story (e.g., 152-3 — *"Harden `pf/jira` against malformed config + complete `require_jira_project` sweep across `cli.py`/`reconcile.py`"*) so 152-2 stays focused on its current `jira.enabled` gating scope. The choice is SM's; the deviation manifest above lists every item that needs to land somewhere.

**Handoff:** To SM (Captain Carrot Ironfoundersson) for story finish.