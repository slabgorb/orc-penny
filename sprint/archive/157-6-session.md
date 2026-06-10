---
story_id: "157-6"
jira_key: ""
epic: "157"
workflow: "tdd"
---
# Story 157-6: Setup gap: repos.yaml-declared repos never checked on disk; init materializes over broken symlinks

## Story Details
- **ID:** 157-6
- **Jira Key:** (none — Jira disabled)
- **Workflow:** tdd
- **Stack Parent:** none
- **Type:** bug
- **Points:** 5

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-10T13:16:05Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-10T12:51:40Z | 2026-06-10T12:53:58Z | 2m 18s |
| red | 2026-06-10T12:53:58Z | 2026-06-10T12:58:50Z | 4m 52s |
| green | 2026-06-10T12:58:50Z | 2026-06-10T13:09:13Z | 10m 23s |
| review | 2026-06-10T13:09:13Z | 2026-06-10T13:16:05Z | 6m 52s |
| finish | 2026-06-10T13:16:05Z | - | - |

## Sm Assessment

**Routing:** tdd (phased) → TEA (red). 5-pt P1, full TEA→Dev→Reviewer pipeline. Peloton inline mode: SM drives agents as inline subagents (Opus).

**Story:** pennyfarthing gh#98 — three compounding setup gaps let a completely broken dogfood topology pass green: setup discovery never cross-checks repos.yaml paths against disk; repos.yaml lacks `remote:` so nothing can offer a clone; doctor validates runtime not topology while `pf init` silently materializes over missing symlink targets. Full problem statement, approach (5 fix points), scope, and ACs in `sprint/context/context-story-157-6.md`.

**Boundaries:** materialize-fallback behavior stays (it's resilient) — it becomes loud and repairable. Other epic-157 stories (init double-dispatch 157-1, config path 157-2, agents-local 157-3, skill template 157-4, agent doctor 157-5) are out of scope.

**Caution for crew:** this repo's own `.pennyfarthing/repos.yaml` + symlink topology is the live dogfood example — use it as a fixture reference, do NOT break the orchestrator's working symlinks while testing. Tests should use tmp-dir fixtures.

**Branch:** `feat/157-6-repos-topology-verification` in `pennyfarthing/` (from develop @ 343d23d37).

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (20 failing, 1 passing — ready for Dev)

**Test File:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_157_6_repos_topology.py` — 21 tests covering AC1-AC4 (AC5 covered by the unchanged existing suites).

**Tests Written:** 21 tests across 5 ACs.
- AC2 (`remote:` field): `TestRemoteField` — RepoConfig.remote field + default, parsed from yaml, validator accepts it.
- AC1 parse prereq (symlinks map): `TestSymlinkMapParsing` — RepoConfig.symlinks dict + parsed from yaml.
- AC1 (doctor topology fail): `TestDoctorTopologyCheck` — check registered + importable; passes healthy; fails on missing repo path, materialized-as-dir, wrong-target symlink; no-repos.yaml no-crash; aggregate report goes red.
- AC3 (init loud warning): `TestInitMaterializeWarning` — result always carries `materialized_warnings` list; names the missing repo when target absent.
- AC4 (relink affordance): `TestRelinkAffordance` — `relink_topology` converts copy→symlink, idempotent, refuses to destroy content when target absent; `pf doctor --fix` relinks end-to-end.

**RED proof:** `pytest test_157_6_repos_topology.py` → 20 failed, 1 passed. Failures are missing functionality (no `remote`/`symlinks` fields, no `check_repos_topology`, no `materialized_warnings` key, no `relink_topology`), not test bugs. The 1 pass (`test_remote_field_validates`) is green-as-designed: the existing repo-field validator permissively accepts fields without a restrictive spec, so it already accepts `remote` — the test pins that it must keep doing so. Existing `test_doctor.py` + `test_init_auto_setup.py` → 94 passed (AC5 baseline intact).

**Designed interface for Dev** (no impl written):
1. `pf/git/repos.py` — `_parse_repo_entry` adds two `RepoConfig` fields:
   - `remote: str = ""` (from `data.get("remote", "")`) — AC2 clone URL.
   - `symlinks: dict[str, str] = field(default_factory=dict)` (from `data.get("symlinks", {}) or {}`) — declared link-path→target map. Both relative to project root. This is the single source of truth (the live repos.yaml already carries per-repo `symlinks:`); drive doctor + relink off this, NOT the hardcoded `_DOGFOODING_SYMLINKS` in init/core.py.
2. `pf/doctor/checks.py` — new `check_repos_topology(root) -> CheckResult(name="repos_topology", ...)`; register `("repos_topology", "...")` in `CHECKS` and add to `_CHECK_FNS` in `pf/doctor/core.py`. FAIL when a declared repo `path` is missing on disk OR a declared symlink doesn't resolve to its declared target (broken / materialized-as-dir / wrong target). `detail` names the offending repo/path. Attach `fix_fn=lambda: relink_topology(root)["success"]` so `--fix` repairs it. Missing repos.yaml → pass/warn, no crash.
3. `pf/init/core.py` — `init_project` result `data` gains `materialized_warnings: list[str]` (always present; one entry naming each repo whose declared symlink target was missing when init materialized a copy). Surface loudly in `init/cli.py`.
4. `pf/init/core.py` — new `relink_topology(root) -> {success, relinked, skipped, ...}`: for each declared symlink whose location is a materialized real dir, if the declared target exists, replace the copy with the relative symlink; idempotent (correct symlink → no-op); if target absent, skip and preserve content (`relinked` stays 0). Chosen relink surface: **`pf doctor --fix`** (documented choice — the topology check already fits doctor's fix-fn model and `--fix` exists, lower friction than a new `pf init --relink` flag).

**Handoff:** To Dev for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/git/repos.py` — added `RepoConfig.remote: str = ""` and `RepoConfig.symlinks: dict[str,str] = {}`; parsed both in `_parse_repo_entry` (AC2 + AC1 prereq).
- `pennyfarthing-dist/src/pf/doctor/checks.py` — new `check_repos_topology(root)`; FAILs naming the offender when a declared repo path is missing or a declared symlink doesn't resolve to its target; missing repos.yaml → pass; `fix_fn` → `relink_topology` via `_fix_relink_topology` helper; registered in `CHECKS` (AC1).
- `pennyfarthing-dist/src/pf/doctor/core.py` — wired `repos_topology` into `_CHECK_FNS` (AC1).
- `pennyfarthing-dist/src/pf/init/core.py` — `init_project` result `data` always carries `materialized_warnings: list[str]` (via `_collect_materialized_warnings`, naming each repo whose declared symlink target was missing); new `relink_topology(root) -> {success, relinked, skipped}` (copy→symlink when target exists, idempotent, refuses to destroy content when target absent) + `_declared_symlinks` helper (AC3 + AC4).
- `pennyfarthing-dist/src/pf/init/cli.py` — surfaces `materialized_warnings` loudly in yellow on `pf init` (AC3).
- `pennyfarthing-dist/src/pf/tests/test_doctor.py` — widened check-count range upper bound 12→13 (see deviation).

**Tests:** 21/21 story tests passing (GREEN). Baseline doctor + init_auto_setup: 94/94. Full suite: 4784 passed; 29 failures all in the known pre-existing set (test_143_9, test_143_10, test_153_4, test_init_justfile, test_peloton_portrait_panes, test_pypi_packaging wheel smoke — verified pre-existing at clean baseline). Ruff clean on all changed files.
**Branch:** feat/157-6-repos-topology-verification (pushed)

**Handoff:** To Reviewer.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)
- **Gap** (non-blocking): Topology coverage blind spot — the new doctor check + relink drive off the live repos.yaml `symlinks:` map (10 entries), but `_DOGFOODING_SYMLINKS` declares 14. Four links exist only in the hardcoded dict: `.pennyfarthing/data`, `.pennyfarthing/gates`, `.claude/commands`, `.claude/skills`. On THIS live project `.claude/commands` and `.claude/skills` are already materialized real dirs (not symlinks), yet `pf doctor` passes green for them — the exact gh#98 class of silent-green, for a subset of links. Affects `.pennyfarthing/repos.yaml` (orchestrator `symlinks:` map is incomplete) and/or `pf/init/core.py` (`_DOGFOODING_SYMLINKS` vs `RepoConfig.symlinks` unification). Pre-existing data gap, not introduced by this branch; story scoped source-of-truth to repos.yaml and kept the dict separate by design. Follow-up: complete the repos.yaml `symlinks:` map (and/or unify the two sources). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `relink_topology` does `shutil.rmtree(link_path)` when the declared target exists, silently discarding the materialized copy. Correct by design (the symlink targets are `never_edit` dist dirs and the real repo is authoritative once present), and AC4's content-safety guarantee is scoped to target-absent. But accidental local edits in a materialized copy would be clobbered without warning. Optional hardening: log what was replaced, or guard against a degenerate mapping where the declared target is nested inside its own link (would rmtree the target — no real topology produces this, theoretical only). Affects `pf/init/core.py::relink_topology`. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Relink surface choice:** Story (AC4) offered `pf init --relink` OR `pf doctor --fix`. Tests target `pf doctor --fix` (driving a `relink_topology` helper). Reason: the topology check already lives in doctor's `fix_fn` model and `--fix` already exists, so this reuses the established repair path rather than adding a new init flag.
- **Symlinks source of truth:** Tests drive doctor topology + relink off the per-repo `symlinks:` map parsed onto `RepoConfig` (already present in the live repos.yaml), not the hardcoded `_DOGFOODING_SYMLINKS` dict in `init/core.py`. Reason: AC1/AC4 say "declared symlink"; the declaration lives in repos.yaml, and keying off it makes the check work for any project's topology, not just the dogfood repo.

### Dev (implementation)
- **Widened doctor check-count assertion:** `test_doctor.py::test_checks_count_approximately_10` asserted `8 <= len(CHECKS) <= 12`. Adding `repos_topology` (in-scope, AC1) made it 13. Bumped the upper bound to 13. Reason: it's a soft "approximately 10" range guard, not a hard contract; the new check is required by the story.

## Subagent Results

Inline peloton mode: the reviewer performed each specialist's analysis directly (single Opus reviewer, no background subagent fan-out). Coverage per specialist below.

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (inline) | clean | 115/115 tests pass; ruff clean on 5 files; tree clean | N/A |
| 2 | reviewer-edge-hunter | Yes (inline) | findings | resolve() on missing target, wrong-target, materialized-as-dir, no-repos.yaml, attribution fallback — all probed and correct | confirmed-safe |
| 3 | reviewer-silent-failure-hunter | Yes (inline) | clean | relink try/except returns result-object; resolve() guarded by OSError; no swallowed errors masking real failures | N/A |
| 4 | reviewer-test-analyzer | Yes (inline) | clean | 21 tests cover AC1-AC4 incl. idempotency, content-preservation, aggregate-red, end-to-end --fix; AC5 by existing suites | N/A |
| 5 | reviewer-comment-analyzer | Yes (inline) | clean | docstrings accurate to behavior (content-safety scope, idempotency, source-of-truth); no stale docs | N/A |
| 6 | reviewer-type-design | Yes (inline) | clean | RepoConfig.remote/symlinks defaults correct (str=""; field(default_factory=dict)); result dict contract consistent | N/A |
| 7 | reviewer-security | Yes (inline) | findings | rmtree on declared paths only; no injection surface; data-loss path scoped + design-correct (see Improvement finding) | confirmed-acceptable |
| 8 | reviewer-simplifier | Yes (inline) | clean | no unnecessary complexity; two intentional code paths (dict vs repos.yaml) per documented scope decision | N/A |
| 9 | reviewer-rule-checker | Yes (inline) | findings | project rules upheld (result-objects not throws; .js-ext n/a; never-edit zones respected); cross-check surfaced repos.yaml-vs-_DOGFOODING_SYMLINKS coverage blind spot (see Gap finding) | logged non-blocking |

All received: Yes (all 9 specialist analyses completed inline by the reviewer; none pending).

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced (gh#98 repro → fix):** Re-init over a repos.yaml declaring an uncloned repo with a `symlinks:` map → `init_project` calls `_collect_materialized_warnings` (core.py:480) → `load_repos_config` reads declared `symlinks`, target absent → named warning in `data["materialized_warnings"]` (present in all 3 return paths: dry-run/dogfooding/normal) → `init/cli.py:88` renders bold-yellow `WARNING:`. Then `pf doctor` → `check_repos_topology` → declared path missing → FAIL naming offender, `report.success=False`. Then `pf doctor --fix` → `relink_topology`: target absent → `skipped`, content preserved; target present → copy replaced with relative symlink. The previously silent-green path is now loud at init, doctor, and fix. Safe.

**Pattern observed:** Result-object contract `{success, relinked, skipped, error?}` with `try/except` wrapper (core.py:173-208) — follows the project "return result objects, don't throw" rule. `materialized_warnings` always present (never conditionally omitted) — honest always-on contract.

**Error handling:** `relink_topology` never throws (catch-all → `{success:False,error}`). `check_repos_topology` guards `resolve()` with `try/except OSError`. Missing repos.yaml → clean pass, no crash (verified). `os`/`shutil` imports confirmed present (core.py:18-19).

**Critical-concern verdicts:**
- **relink data-loss:** Content-safe guarantee holds for the AC's scope (target absent → preserved, `relinked=0`). Target-present replacement is correct-by-design (targets are `never_edit` dist dirs; real repo is authoritative). Nested-target-inside-link is theoretical only — no declared topology produces it. → no blocker; logged as non-blocking Improvement.
- **check correctness:** `resolve()` strict=False normalizes non-existent paths so wrong-target detection works even when the declared target is missing (probed). Relative-to-root resolution correct. Missing/malformed repos.yaml safe.
- **materialized_warnings contract:** always present (3 paths verified); CLI surfacing is bold yellow `WARNING:`, not buried.
- **scope discipline:** `_DOGFOODING_SYMLINKS` and `RepoConfig.symlinks` are two clean, non-overlapping code paths — no half-migration. But the live repos.yaml `symlinks:` map is incomplete vs the dict → coverage blind spot logged as non-blocking Gap (pre-existing data, not this branch's defect).
- **live-fire:** `pf doctor` on the healthy orchestrator → `repos_topology` PASS, no false positive. Did NOT run `--fix` on the live project.

**Tests:** Story 21/21 + test_doctor + test_init_auto_setup = 115 passed (ran myself). Ruff clean on all 5 changed files. CHECKS=13, full CHECKS↔_CHECK_FNS parity, exactly one additive check.

**Specialist incorporation:**
- [EDGE] resolve() on missing/wrong/materialized-as-dir targets and no-repos.yaml all probed — boundary handling correct.
- [SILENT] relink try/except returns a result-object, resolve() guarded by OSError; no swallowed errors mask real failures.
- [TEST] 21 tests cover AC1-AC4 (idempotency, content-preservation, aggregate-red, end-to-end --fix); AC5 via existing suites. No gaps.
- [DOC] docstrings accurate to behavior (content-safety scope, idempotency, source-of-truth); no stale documentation.
- [TYPE] RepoConfig.remote (str="") and symlinks (field(default_factory=dict)) defaults correct; result-dict contract consistent.
- [SEC] rmtree confined to declared paths; no injection surface; data-loss path scoped and design-correct (see Improvement).
- [SIMPLE] no unnecessary complexity; two intentional code paths (dict vs repos.yaml) per documented scope decision.
- [RULE] project rules upheld (result-objects, never-edit zones); cross-check surfaced the repos.yaml-vs-_DOGFOODING_SYMLINKS coverage blind spot (see Gap).

**Observations:** 2 findings logged (1 Gap non-blocking, 1 Improvement non-blocking). No Critical/High. All 5 ACs met.

**Deviation audit:**
- TEA — Relink surface (`pf doctor --fix`): **ACCEPTED**. Reuses doctor's existing fix_fn model; lower friction than a new flag; tests + impl consistent.
- TEA — Symlinks source of truth (repos.yaml `symlinks:` over `_DOGFOODING_SYMLINKS`): **ACCEPTED**. Matches AC1/AC4 "declared symlink"; generalizes beyond the dogfood repo. Note: surfaced the live repos.yaml incompleteness as a non-blocking Gap.
- Dev — Check-count 12→13: **ACCEPTED**. Verified honest minimal change — exactly one check added, none removed/renamed, full registry parity. Soft range guard, not a behavior contract.
- Dev — Kept `_DOGFOODING_SYMLINKS`: **ACCEPTED**. Matches SM/TEA minimal-change guidance; coexistence is clean (distinct paths).

**Handoff:** To SM for finish-story.
- **Kept `_DOGFOODING_SYMLINKS`:** Did not rip out the hardcoded dict (per SM/TEA guidance — minimal change). The new verification/relink/warning paths key off `RepoConfig.symlinks` (repos.yaml) as the source of truth; the dogfooding init path still uses `_DOGFOODING_SYMLINKS` unchanged.