---
story_id: "160-8"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-8: Dangling depends_on to a completed/archived story fails whole-sprint validation, blocking ALL story update & finish (gh #90)

## Story Details
- **ID:** 160-8
- **Jira Key:** (not tracked)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-10T11:49:02Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-10T00:00:00Z | 2026-06-10T11:36:20Z | 11h 36m |
| red | 2026-06-10T11:36:20Z | 2026-06-10T11:40:19Z | 3m 59s |
| green | 2026-06-10T11:40:19Z | 2026-06-10T11:44:43Z | 4m 24s |
| review | 2026-06-10T11:44:43Z | 2026-06-10T11:49:02Z | 4m 19s |
| finish | 2026-06-10T11:49:02Z | - | - |

## Sm Assessment

**Routing:** tdd (phased) → TEA (red). 5-pt P1 bug, full TEA→Dev→Reviewer pipeline. Peloton inline mode: SM drives all agents as inline subagents (Opus), no tmux panes.

**Story:** gh#90 — merged-sprint validator treats `depends_on` → archived story as "non-existent" and hard-errors, blocking ALL `pf sprint story update`/`finish` sprint-wide. Full problem statement, repro, technical approach, and ACs written to `sprint/context/context-story-160-8.md`.

**Approach (for TEA/Dev to refine):** validator should resolve `depends_on` against the archive before declaring a ref dangling — archived dep = satisfied, accepted (warning at most). Truly non-existent refs still ERROR. Optional cheap hardening: `--clear-depends-on` on `pf sprint story update`.

**Boundaries:** do NOT absorb story 160-2 (standalone_stories validation gap), validation-scoping redesign, auto-prune-at-finish, or the secondary PR-detection observation in gh#90.

**Branch:** `feat/160-8-dangling-depends-on-validation` in `pennyfarthing/` (targets `develop`).

## TEA Assessment

**Tests Required:** Yes
**Reason:** P1 bug fix with explicit behavioral ACs — RED-phase regression tests required.

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_160_8_archived_depends_on.py` — archived `depends_on` resolution + gh#90 repro

**Tests Written:** 8 tests covering all 4 ACs
- AC1 (archived dep = satisfied): `test_depends_on_archived_story_passes_full_sprint_validation`, `test_archived_dependency_emits_no_hard_error` — FAIL (RED, correct)
- AC2 (nonexistent still errors): `test_depends_on_nowhere_story_still_fails`, `test_nonexistent_dep_errors_even_with_empty_archive` — PASS (negative guards; behavior already correct, locks it so the fix can't over-relax)
- AC3 (gh#90 repro via `update_story`): `test_update_unrelated_story_succeeds_when_dep_is_archived` — FAIL (RED, correct); `test_update_still_blocked_by_truly_dangling_dep` — PASS (boundary guard)
- AC4 (existing behavior preserved): `test_active_intra_sprint_dependency_still_passes`, `test_circular_dependency_still_detected` — PASS

**RED Evidence:** 3 failed, 5 passed in the new file. All 3 failures fail for the right reason — the validator reports `depends_on '160-1' references non-existent story` for an archived dependency (no archive awareness in `_validate_depends_on`). Existing `test_sprint_validator.py` + `test_story_update.py` suites: 94 passed (AC4 baseline intact).

**Test Strategy / Contract Notes (latitude for Dev):**
- The bug is in `validator.py::_validate_depends_on` — `all_story_ids` only contains *active* stories; archived IDs aren't consulted. Fix should resolve `depends_on` against the archive (via `loader.get_archived_stories()` / `sprint/archive/`) before declaring a ref dangling.
- Tests pin **behavior**, not internal signatures: they drive the public `validate_full_sprint` and `update_story` entry points and rely on a real `tmp_path` archive file. Dev may add archive lookup inside `_validate_depends_on` or thread archived IDs through `validate_full_sprint` — either passes.
- Archive lookup must resolve `get_project_root()` (tests monkeypatch `pf.sprint.loader.get_project_root` + `pf.common.config.get_project_root`). Whatever path the fix uses to read the archive must honor that resolution and must NOT depend on `only_current`/`exclude_current` (which need `get_sprint_info`) — consult the full archive.
- Missing archive dir must be safe (no crash) and must still let a truly dangling ref ERROR — covered by `test_nonexistent_dep_errors_even_with_empty_archive`.
- Out of scope per SM boundaries: `standalone_stories` (160-2), validation-scoping redesign, auto-prune-at-finish, `--clear-depends-on` CLI flag (optional, not tested here).

**Status:** RED (failing — ready for Dev)
**Handoff:** To Dev for implementation (GREEN)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/validator.py` — `_validate_depends_on` now resolves a `depends_on` miss against the archive before declaring it dangling. Added helper `_get_archived_story_ids()` (lazy-imports `loader.get_archived_stories()` with no scoping flags, so it honors `get_project_root()` and never needs `get_sprint_info`; missing archive dir → empty set; exceptions swallowed → empty set). Archive IDs resolved lazily on first active-sprint miss to avoid disk I/O when all deps resolve in-sprint.

**Approach:** Minimal. Active-sprint membership is checked first (existing behavior, cycle graph unchanged). Only on a miss do we consult the archive; an archived match is treated as satisfied (no error, no warning). Truly non-existent refs (neither active nor archived) still hard-ERROR. Cycle detection is unaffected — archived deps are simply not added to the `deps` graph (terminal, like any out-of-sprint satisfied ref).

**Tests:** 8/8 passing in `test_160_8_archived_depends_on.py` (GREEN). Validator + story_update baseline: 102/102 (94 prior + 8 new). 28 unrelated pre-existing failures in the full suite (peloton portrait panes, tdd-cycle e2e, init justfile, sharded-yaml mutation) confirmed present on TEA's RED commit before my change — not caused by and not in scope for 160-8.

**Branch:** `feat/160-8-dangling-depends-on-validation` (pushed)

**Handoff:** To Reviewer (review phase)

## Delivery Findings

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)
- **Improvement** (non-blocking): `_get_archived_story_ids()` swallows ALL exceptions to an empty set (`except Exception: return set()`). On a corrupt/malformed archive YAML this silently degrades to pre-fix behavior — an archived dep would be re-reported as "non-existent" and could re-surface the gh#90 symptom for that one operator. It fails LOUD (the validation error still surfaces) and cannot corrupt data, so non-blocking, but a narrowed catch (`OSError`/`yaml.YAMLError`) plus a `logger.warning` would make the degradation diagnosable. Affects `pennyfarthing-dist/src/pf/sprint/validator.py:519-525` (`_validate_depends_on` archive resolution). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Archived deps are silent-satisfied with no warning. ACs allow "warning at most"; Dev chose none to avoid sprint-wide noise (sound). If operators later want to know a dep was satisfied-by-archive vs in-sprint, an INFO-level note could be added. Affects `pennyfarthing-dist/src/pf/sprint/validator.py:555-557`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): Sibling/symmetric scope check (per gotcha `jira-less-fallback-check-the-symmetric-op`) — `_validate_depends_on` only iterates `data["epics"][].stories`, NOT `standalone_stories`. A `depends_on` on a standalone story is never validated at all (neither errors nor archive-resolves). This is explicitly story 160-2's territory and OUT OF SCOPE here per SM boundaries; naming it so it is not lost. Affects `pennyfarthing-dist/src/pf/sprint/validator.py:540-562`. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 1 findings (0 Gap, 0 Conflict, 0 Question, 1 Improvement)
**Blocking:** None

- **Improvement:** `_get_archived_story_ids()` swallows ALL exceptions to an empty set (`except Exception: return set()`). On a corrupt/malformed archive YAML this silently degrades to pre-fix behavior — an archived dep would be re-reported as "non-existent" and could re-surface the gh#90 symptom for that one operator. It fails LOUD (the validation error still surfaces) and cannot corrupt data, so non-blocking, but a narrowed catch (`OSError`/`yaml.YAMLError`) plus a `logger.warning` would make the degradation diagnosable. Affects `pennyfarthing-dist/src/pf/sprint/validator.py:519-525`.

### Downstream Effects

- **`pennyfarthing-dist/src/pf/sprint`** — 1 finding

## Subagent Results

> Inline peloton mode: no native Task subagents available in this harness. Each specialist's domain was analyzed directly by the Reviewer (Opus) against the diff and verified empirically (test runs, develop-revert reproduction, edge-case probes). Rows reflect that direct analysis.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 blocking | 102/102 target tests pass against branch code (PYTHONPATH-corrected); ruff clean; gh#90 repro proven load-bearing via develop-revert (3 fail / 5 guard-pass). confirmed 0, dismissed 0, deferred 0 |
| 2 | reviewer-edge-hunter | Yes | findings | 3 | Edges probed: corrupt archive → `set()` (degrades to ERROR, AC2-safe); active/archive ID collision → active checked first, wins (correct); missing archive dir → loader returns `[]` cleanly. confirmed 1 (corrupt-archive degradation, downgraded to non-blocking), dismissed 2 (collision + missing-dir are correct-by-design with evidence), deferred 0 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 1 | Broad `except Exception: return set()` at validator.py:523. Matches python.md rule #1. Confirmed (not dismissed) but downgraded to non-blocking by blast radius — loud failure, no corruption, only degrades to pre-fix behavior on corrupt archive. confirmed 1, dismissed 0, deferred 0 |
| 4 | reviewer-test-analyzer | Yes | clean | 0 blocking | 8 tests, all behavioral (drive `validate_full_sprint` + `update_story`), no vacuous asserts, real tmp_path archive, negative guards (AC2) + cycle/active-dep guards (AC4) included; verified non-existent assertions check the specific message+id, not truthy. confirmed 0, dismissed 0, deferred 0 |
| 5 | reviewer-comment-analyzer | Yes | clean | 0 | Docstrings on `_get_archived_story_ids` + updated `_validate_depends_on` are accurate to the code (gh#90 rationale, get_project_root honoring, missing-dir safety). No stale/misleading comments. confirmed 0, dismissed 0, deferred 0 |
| 6 | reviewer-type-design | Yes | clean | 0 | Return types annotated (`set[str]`), lazy sentinel typed `set[str] | None`, IDs coerced to `str` consistently with `all_story_ids`. No stringly-typed regressions vs existing module style. confirmed 0, dismissed 0, deferred 0 |
| 7 | reviewer-security | Yes | clean | 0 | Archive read uses `load_yaml_config` → `yaml.safe_load` (python.md rule #8 satisfied). No user-controlled path join (archive_dir derived from `get_project_root()`), no injection, no secrets. Local single-user tool, no tenant model. confirmed 0, dismissed 0, deferred 0 |
| 8 | reviewer-simplifier | Yes | findings | 1 | Lazy `archived_ids is None` sentinel adds a small branch vs eager fetch; justified — avoids disk I/O on the all-in-sprint common path (Dev's stated rationale). Minor, accepted. confirmed 0, dismissed 1 (complexity is warranted, evidence: avoids I/O per validation call), deferred 0 |
| 9 | reviewer-rule-checker | Yes | findings | 1 | python.md exhaustive pass: #1 silent-exceptions → flagged (broad except, see row 3, non-blocking); #3 type-annotations pass; #5 path-handling pass (pathlib via loader); #6 test-quality pass; #8 unsafe-deser pass (safe_load). confirmed 1 (= row 3, no double-count), dismissed 0, deferred 0 |

**All received:** Yes (9 analyzed inline, 3 with findings)
**Total findings:** 1 confirmed-and-downgraded (broad except, non-blocking), 3 dismissed with rationale, 3 captured as non-blocking Delivery Findings. No Critical/High.

### Rule Compliance (python.md, applied to the diff)

- **#1 Silent exception swallowing** — `_get_archived_story_ids` uses `except Exception: return set()` (validator.py:523). VIOLATION of the letter of the rule. The error path is file I/O (archive read), which #1 says "MUST be handled explicitly." Per project rule I do NOT dismiss; I CONFIRM it. Downgraded to non-blocking (severity by blast radius, per sidecar gotcha): the only realistic trigger is a corrupt archive YAML, the failure is loud (validation ERROR still surfaces), and it degrades to the exact pre-fix behavior rather than corrupting state. Captured as a Delivery Finding recommending a narrowed catch + `logger.warning`.
- **#3 Type annotations at boundaries** — `_get_archived_story_ids() -> set[str]` annotated; both helpers are private (underscore) so the boundary rule is relaxed, but they are annotated anyway. COMPLIANT.
- **#5 Path handling** — No new path manipulation in the diff; archive path is built inside `loader.get_archived_stories` via `get_project_root() / "sprint" / "archive"` (pathlib). COMPLIANT.
- **#6 Test quality** — `test_160_8_archived_depends_on.py`: every test asserts specific values/messages, none vacuous; `patch` targets `pf.sprint.loader.get_project_root` / `pf.common.config.get_project_root` (where USED for resolution), not where defined; no skips. COMPLIANT.
- **#8 Unsafe deserialization** — archive YAML loaded via `load_yaml_config` → `yaml.safe_load` (config.py:137). COMPLIANT.
- **#13 Fix-introduced regressions** — Dev's fix adds error handling that catches too broadly (the #1 finding) — exactly the #13 pattern. Noted, non-blocking, same as #1.

### Devil's Advocate

Assume this code is broken. The most dangerous claim in the PR is "missing archive dir is safe." It IS safe — but the safety lives in `get_archived_stories` (loader.py:280 `if not archive_dir.is_dir(): return []`), NOT in the new helper. The new helper's safety net is the blanket `except Exception`. So what happens when the archive dir EXISTS but a shard is corrupt, half-written, or has a `completed_stories` value that is a dict instead of a list? `load_yaml_config` (safe_load) may parse junk into a non-iterable, `stories.extend(...)` or the comprehension `for s in archived` could raise — and the helper silently returns `set()`. The consequence: an operator who genuinely finished and archived story B, with A still depending on B, runs `pf sprint story update <unrelated>` and gets the EXACT gh#90 error this PR claims to fix — but now it's intermittent and tied to an unrelated corrupt archive file, far harder to diagnose than the original deterministic bug. That is the worst realistic case. It is still strictly better than develop (which fails for ALL archived deps unconditionally) and it fails loud, so it does not block — but it is why the broad-except is a real finding, not a nit.

A confused user: someone hand-edits an archive file (the repo forbids hand-editing sprint YAML but not archive YAML explicitly) and breaks its YAML — they'd see unrelated stories' validation fail. A malicious user is not in the threat model (single-user local dev tool, no untrusted input crossing a trust boundary). ID-collision: I probed it — an ID present in BOTH active and archive resolves as active (checked first), which is correct: an active story takes precedence and joins the cycle graph; the archive lookup is never consulted for it. Story-archived-mid-session: the archive is read fresh on each validation call (lazy, per-call, no caching across calls), so a story archived between two `update` invocations is picked up on the next call — no stale-cache hazard. Cycle detection: archived deps are never added to `deps`, so they're terminal — confirmed by `test_circular_dependency_still_detected` passing. The fix holds up.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Design Deviations

No deviations logged.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Reviewer (audit)
- TEA/Dev logged no deviations. Spec audit: implementation matches the SM/TEA-approved approach (resolve in `_validate_depends_on`, archive-as-satisfied, lazy lookup, no cycle-graph change). No undocumented spec deviations found.
- **Silent-satisfied (no warning) for archived deps** → ✓ ACCEPTED by Reviewer: ACs say "warning at most"; emitting nothing is within spec and avoids sprint-wide noise. Agrees with Dev reasoning (handoff Key Decisions).
- **Scope honored** → ✓ ACCEPTED: standalone_stories (160-2), validation-scoping redesign, auto-prune, and `--clear-depends-on` CLI flag all correctly untouched. No scope creep.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `pf sprint story update <id>` → `update_story()` writes then calls `validate_full_sprint(merged)` → `_validate_depends_on(data, all_story_ids, result)` → for each `depends_on` miss against active IDs, lazily loads `_get_archived_story_ids()` (→ `loader.get_archived_stories()` → `sprint/archive/sprint-*-completed.yaml` via `yaml.safe_load`) → archived match = satisfied (no error), else hard ERROR. Safe because: archive path is derived from `get_project_root()` (no user-controlled join), YAML is loaded with `safe_load`, and a missing/corrupt archive degrades to the strictly-better pre-fix ERROR (loud, non-corrupting), never a false pass.

**Pattern observed:** Lazy archive resolution (sentinel `archived_ids: set[str] | None`, fetched only on first active-sprint miss) at validator.py:538/553 — zero extra I/O on the common all-in-sprint path. Good pattern, correctly applied.

**Error handling:** Broad `except Exception: return set()` at validator.py:519-525 — confirmed against python.md #1, downgraded to non-blocking by blast radius (loud failure, degrades to pre-fix behavior, cannot corrupt). Captured as a Delivery Finding (narrow the catch + log a warning).

**Findings:** 0 Critical, 0 High, 3 non-blocking Delivery Findings (broad-except hardening, optional satisfied-by-archive INFO, standalone_stories gap = 160-2's scope). All ACs met and independently verified: AC1/AC3 proven load-bearing (3 new tests fail on develop, pass on branch), AC2 boundary guards confirmed (non-existent + empty-archive still ERROR), AC4 preserved (active-dep + cycle tests pass). Tests: 102/102 against branch code (PYTHONPATH-corrected to the worktree, not the installed pf-1 package). ruff clean.

**Tags:** [EDGE] corrupt-archive/collision/missing-dir verified · [SILENT] broad-except confirmed+downgraded · [TEST] behavioral, non-vacuous, guards present · [DOC] docstrings accurate · [TYPE] annotated, str-coerced · [SEC] safe_load, no path injection · [SIMPLE] lazy sentinel warranted · [RULE] python.md #1 confirmed non-blocking

**Handoff:** To SM for finish-story (PR creation + merge per inline-mode override).