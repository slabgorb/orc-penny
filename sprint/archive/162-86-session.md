---
story_id: "162-86"
jira_key: null
epic: "162"
workflow: "tdd"
---
# Story 162-86: Finish staleness configured-remote honoring

## Story Details
- **ID:** 162-86
- **Jira Key:** (none — Jira not enabled)
- **Workflow:** tdd
- **Points:** 2
- **Stack Parent:** none
- **Branch:** feat/162-86-finish-staleness
- **PR:** #247

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-17T15:00:43Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-17T14:30:30Z | 2026-08-17T14:32:31Z | 2m 1s |
| red | 2026-08-17T14:32:31Z | 2026-08-17T14:39:51Z | 7m 20s |
| green | 2026-08-17T14:39:51Z | 2026-08-17T14:44:42Z | 4m 51s |
| review | 2026-08-17T14:44:42Z | 2026-08-17T14:54:20Z | 9m 38s |
| green | 2026-08-17T14:54:20Z | 2026-08-17T14:58:09Z | 3m 49s |
| review | 2026-08-17T14:58:09Z | 2026-08-17T15:00:43Z | 2m 34s |
| finish | 2026-08-17T15:00:43Z | - | - |

## Technical Approach

This story consolidates parallel repo configuration maps and threads the configured remote through the staleness summary banner. It is a follow-up to two non-blocking findings from the 162-71 review (see `sprint/archive/162-71-session.md`).

**Target file:** `pennyfarthing/pennyfarthing-dist/src/pf/sprint/staleness.py`

### Change A: Consolidate Parallel Repo Maps

Currently `staleness.py` holds two parallel per-repo dicts:
- `_BASE_BRANCH_BY_REPO` — base branches keyed by repo
- `_REMOTE_BY_REPO` — remotes keyed by repo (added in 162-71 as a mirror)

Consolidate into ONE guarded lookup (single dict/dataclass keyed by repo, carrying both base and remote). This ensures a non-origin remote is honored by updating a single entry instead of two.

### Change B: Thread Remote Into Summary

Currently `_print_human_summary` hardcodes a literal `origin/` prefix in the drift banner (prints `on origin/{base_branch}`). The configured `remote` was honored in `_resolve_revision`, `_run_git_log`, and `check_story_staleness` in 162-71 but was NOT threaded into the result dict or summary banner.

Thread `remote` through the result dict into `_print_human_summary` so the banner shows the configured remote, not a hardcoded `origin/`.

### Scope Guard

Base/remote come from `repos.yaml` config, NOT operator-supplied session fields. Full-ref-path / gitrevisions-DWIM hardening is OUT OF SCOPE. This is configured-remote honoring only.

### Acceptance Criteria

- The two parallel repo maps (`_BASE_BRANCH_BY_REPO` + `_REMOTE_BY_REPO`) are consolidated into a single guarded per-repo lookup carrying both base branch and remote.
- `_print_human_summary` renders the configured remote (threaded via the result dict), no hardcoded literal `origin/`.
- A non-origin remote is exercised by a test (banner + lookup honor it).
- Existing 162-71 staleness pins continue to pass; no full-ref-path hardening added (out of scope).

## Delivery Findings

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): the drift banner date slice `c.get('date', '')[:10]` in `_print_human_summary` assumes ISO `%aI` format; not in 162-86 scope but worth a glance if remote-threading touches that print block. Affects `pennyfarthing-dist/src/pf/sprint/staleness.py` (display-only). *Found by TEA during test design.*
- **Question** (non-blocking): Change A is a behavior-parity refactor; the only test that enforces the *consolidation* itself (vs. the threading) is the module-attribute invariant `test_parallel_remote_map_is_consolidated_away`. If Dev prefers a different unified shape, the invariant still holds as long as the standalone `_REMOTE_BY_REPO` dict is gone. *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation. TEA's date-slice Improvement (`c.get('date','')[:10]`) was reviewed — it is untouched by this change (the remote thread only edits the `on <remote>/<base>` clause), so it stays out of scope as TEA noted.

### Reviewer (review)
- **Gap** (blocking): AC-3's "lookup honor [a non-origin remote]" is untested — no test drives a non-origin remote through `check_story_staleness`. Affects `pennyfarthing-dist/src/pf/tests/test_162_86_staleness_remote_consolidation.py` (add a monkeypatched-`_REPO_CONFIG` end-to-end assertion). *Found by Reviewer during review.*
- **Improvement** (non-blocking): `_print_human_summary` silent `or 'origin'` fallback should be removed/made-loud. Affects `pennyfarthing-dist/src/pf/sprint/staleness.py:596`. *Found by Reviewer during review.*
- **Improvement** (non-blocking): `_REPO_CONFIG` could use a `TypedDict` for mypy-checked key access. Affects `pennyfarthing-dist/src/pf/sprint/staleness.py:58`. *Found by Reviewer during review.*

## Design Deviations

None yet.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Consolidation (Change A) pinned via a structural module-attribute invariant, not pure behavior**
  - Spec source: session Technical Approach, AC-1 ("two parallel repo maps consolidated into a single guarded per-repo lookup")
  - Spec text: "consolidate base/remote repo maps into one guarded lookup"
  - Implementation: behavior tests cannot distinguish "merged into one map" from "kept two maps but also threaded remote into the result." So the consolidation deliverable is enforced by `assert not hasattr(staleness, "_REMOTE_BY_REPO")` — a stable attribute invariant (reformat-safe, unlike a `getsource` text match), paired with a behavior pin that both fields resolve from the lookup.
  - Rationale: a structural refactor has no observable behavior of its own; the invariant fails exactly when the two maps stay divergent — the violation the AC targets. Dev retains full freedom over the unified carrier's shape/name.
  - Severity: minor
  - Forward impact: if Dev names the unified carrier something new and removes both old dicts, the invariant still passes; it only forbids retaining the standalone parallel remote map.

### Dev (implementation)
- **Threaded `remote` into the skipped/error result paths too, not only the tested clean/drift returns**
  - Spec source: session AC-2 + `test_151_5::TestResultShapeUniformity` (result-shape contract)
  - Spec text: "`_print_human_summary` renders the configured remote (threaded via the result dict)"
  - Implementation: `_result` gained a `remote: str = ""` field always present in the out-dict (mirroring `base_branch`); the skipped return and the git-failure error return also pass `remote=remote` since it is already resolved at those points.
  - Rationale: matches the existing uniformity contract (every result carries `base_branch`, even error paths at default `""`); a `remote` key that appears only on clean/drift would reintroduce the exact conditional-key shape 151-5 pins against.
  - Severity: minor
  - Forward impact: consumers can `result.get("remote")` uniformly; pre-resolution error paths carry `remote=""` (same as `base_branch=""`).
- **Drift banner uses `result.get('remote') or 'origin'` (defensive default)**
  - Spec source: session AC-2
  - Spec text: "no hardcoded literal `origin/`"
  - Implementation: the banner reads the threaded remote but falls back to `'origin'` if the key is empty/absent.
  - Rationale: a drift result always carries a real remote today, but the `or 'origin'` guard prevents a degenerate `/develop` banner if a future/hand-built result omits it — no hardcoded prefix on the real path.
  - Severity: minor
  - Forward impact: none for real results; purely defensive for malformed inputs.

### Reviewer (audit)
- **TEA: consolidation pinned via module-attribute invariant (`not hasattr(_REMOTE_BY_REPO)`)** → ✓ ACCEPTED by Reviewer: a stable, reformat-safe structural invariant is a defensible way to pin a behavior-parity refactor; weak alone but paired with the resolve-both-fields behavior test it is adequate. (Test-analyzer's suggestion to add a positive `_REPO_CONFIG` structural assertion is a [LOW] nice-to-have, not required.)
- **Dev: threaded `remote` into skipped/git-error result paths for shape uniformity** → ✓ ACCEPTED by Reviewer: matches the `_result` unconditional-key contract 151-5 pins (`base_branch` present on every path); consistent and correct.
- **Dev: drift banner uses `result.get('remote') or 'origin'` (defensive default)** → ✗ FLAGGED by Reviewer: three specialists (rule-checker §1+§13 high, security low, type-design low) converged on this as a silent display fallback. On the drift arm `remote` is always populated, so the `or 'origin'` is unreachable dead code today, but it silently substitutes a possibly-wrong remote if a future/malformed drift result omits the key — the exact silent-fallback shape the module docstring disavows. Added as a [LOW] finding (fold in the same rework cycle). See finding F2.

## SM Assessment

Setup complete for 162-86 (2pt, p1, tdd). This is a clean two-part follow-up from the 162-71 review, both findings non-blocking and well-scoped:

1. **Consolidation** — merge the two parallel per-repo maps into one guarded lookup. Pure refactor with behavior parity as the safety net.
2. **Thread remote into the summary banner** — small interface extension (`remote` into the result dict) plus display change in `_print_human_summary`.

Both changes live in a single file (`staleness.py`), and the scope guard is explicit: configured-remote honoring only, no full-ref-path/gitrevisions-DWIM hardening. The 162-71 pins are the regression net — they must stay green.

**Routing:** TDD phased → TEA owns the RED phase. TEA writes failing pins for (a) the consolidated lookup carrying both base+remote, and (b) `_print_human_summary` rendering a NON-origin remote through the result dict. Existing 162-71 staleness pins must continue to pass.

Handing off to Captain Murdock (TEA).

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (failing — ready for Dev)

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_162_86_staleness_remote_consolidation.py` — 8 tests: 5 RED (new behavior), 3 green-on-arrival guards.

**Tests Written:** 8 tests covering both changes + the guarded-lookup invariant + §3 rule coverage.

**RED breakdown (5 failing — the work Dev must make pass):**
| Test | Pins |
|------|------|
| `test_clean_result_carries_configured_remote` | Change B — `remote` key in result dict (clean) |
| `test_drift_result_carries_configured_remote` | Change B — `remote` key in result dict (drift) |
| `test_drift_banner_shows_configured_remote_not_hardcoded_origin` | Change B — banner renders `<remote>/<base>`, no hardcoded `origin/` |
| `test_parallel_remote_map_is_consolidated_away` | Change A — `_REMOTE_BY_REPO` folded into one guarded lookup |
| `test_known_repo_resolves_both_base_and_remote_from_one_lookup` | Change A — single lookup carries both fields (observed via result) |

**Green-on-arrival guards (3 passing — must stay green):**
- `test_drift_banner_shows_origin_for_origin_repo` — origin parity (fix must not regress the common case).
- `test_unknown_repo_still_guarded_after_consolidation` — the unknown-repo guard survives the refactor.
- `test_public_check_story_staleness_annotations_intact` — §3 annotation rule coverage.

### Rule Coverage

| Rule (lang-review/python.md) | Test(s) | Status |
|------|---------|--------|
| §1 silent exception / silent fallback | `test_unknown_repo_still_guarded_after_consolidation` (+ 151-5 `TestUnknownRepoSilentFallback`) | passing guard |
| §3 type annotations at boundaries | `test_public_check_story_staleness_annotations_intact` | passing guard |
| §6 test quality (self-check) | all 8 tests carry meaningful value assertions; 0 vacuous | n/a |

**Rules checked:** §1, §3, §6 are the applicable ones for a config-map refactor + display threading (remote/base are repos.yaml config, not user input, so §11 injection surface is unchanged and already pinned by 151-5). 
**Self-check:** 0 vacuous tests. The banner test asserts both presence (`upstream/develop`) AND absence (`origin/develop`) so it cannot pass on a partial fix.

**Regression net verified green now:** `test_162_71_staleness_configured_remote.py` + `test_151_5_staleness_preflight.py` — 44 passed. These MUST remain green after Dev's change.

**Implementation notes for Dev (B.A.):**
- `remote` is already computed at `staleness.py:212` (`_REMOTE_BY_REPO.get(repo_name, "origin")`). After consolidating, thread it into `_result(...)` (add a `remote` param + key, mirroring `base_branch`) at the clean/drift/skipped success returns, and read `result.get("remote")` in `_print_human_summary`'s drift banner instead of the literal `origin/`.
- Consolidation: one lookup keyed by repo carrying both base + remote. Keep the unknown-repo guard (currently the `if repo_name not in _BASE_BRANCH_BY_REPO` check + error string) pointed at the unified structure.
- Scope guard: configured-remote honoring ONLY — no full-ref-path/gitrevisions-DWIM hardening.

**Handoff:** To Dev (Sergeant B.A. Baracus) for GREEN.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/staleness.py` — (A) consolidated `_BASE_BRANCH_BY_REPO` + `_REMOTE_BY_REPO` into a single guarded lookup `_REPO_CONFIG: dict[str, dict[str, str]]` keyed by repo, each entry carrying `{"base", "remote"}`; rewrote the unknown-repo guard to `_REPO_CONFIG.get(repo_name)` with a `None` check. (B) added a `remote` field to `_result` (always present, mirroring `base_branch`), threaded the resolved `remote` into the clean/drift/skipped/git-error returns, and changed `_print_human_summary`'s drift banner from a hardcoded `origin/{base}` to `{remote or 'origin'}/{base}`.

**Approach:** Minimal, behavior-parity. Change A is a pure refactor — the guard and both values now come from one map so a non-origin repo is a single-entry edit. Change B threads the already-resolved remote through the result contract into the banner. No new imports, no full-ref-path hardening (scope guard honored).

**Tests:** 52/52 passing (GREEN) — 8 story (`test_162_86_*`) + 6 (`test_162_71_*`) + 38 (`test_151_5_*`). The 5 previously-RED pins now pass; the 3 green-on-arrival guards stayed green. Real tmp-git-repo fixtures (not mocks) exercise the resolution + banner end-to-end.

**Quality:** `ruff check` clean on both files. Type: `_REPO_CONFIG` annotated; `repo_cfg["base"/"remote"]` reached only after the `None` guard (str). No other module references the removed dict names (grep clean across `src/pf/`).

**Self-review:**
- [x] All ACs met: consolidated guarded lookup carrying both (A); banner + result honor configured remote, no hardcoded `origin/` (B); non-origin remote exercised by tests; 162-71 pins stay green; no full-ref-path hardening.
- [x] Follows project patterns (result-dict contract, self-contained module, `Return Results Don't Throw`).
- [x] Error handling: unknown-repo guard preserved on the unified lookup.
- [x] Wired: `check_story_staleness` → `staleness_cli` → `_print_human_summary` all consume the threaded remote.

**Handoff:** To Reviewer (Colonel Decker) for adversarial review.

## Dev Rework (Cycle 1)

Addressed Colonel Decker's cycle-0 rejection. Per-finding disposition:

- **F1 [HIGH] — non-origin remote not exercised end-to-end → FIXED.** Added `test_non_origin_remote_traverses_lookup_into_result_end_to_end` (test_162_86_...py). It `monkeypatch.setitem`s the `pennyfarthing` `_REPO_CONFIG` entry to `remote="upstream"`, drives `check_story_staleness` end-to-end, and asserts `result["remote"] == "upstream"`. A hardcoded `_result(remote="origin")` fails this — the origin-only tautology is killed. AC-3's "lookup honor [a non-origin remote]" is now pinned at the pipeline level (banner half was already covered).
- **F2 [LOW] — silent `or 'origin'` banner fallback → FIXED.** Changed `_print_human_summary` drift banner from `result.get('remote') or 'origin'` to `result.get('remote')` (matching the no-default treatment of `result.get('base_branch')` on the same line). The drift arm always supplies a non-empty remote (unknown repos error before drift), so this removes the silent substitution without changing real output; a missing remote would now render loudly, not masquerade as `origin`.
- **F3 [LOW] — stringly `_REPO_CONFIG` → FIXED.** Introduced `class _RepoConfig(TypedDict): base: str; remote: str` and annotated `_REPO_CONFIG: dict[str, _RepoConfig]`. Runtime-identical (TypedDict is a dict at runtime); mypy now checks `repo_cfg["base"/"remote"]` access and flags a missing key at the definition site. Import: `from typing import Any, TypedDict`.

**Verification:** 53/53 green (162-86 now 9 tests + 162-71 6 + 151-5 38), `ruff check` clean on both files. `test_drift_banner_shows_origin_for_origin_repo` and `_configured_remote_not_hardcoded_origin` both stay green under the F2 change.

**Handoff:** Back to Reviewer (Colonel Decker) for cycle-1 re-review.

## Subagent Results

**Cycle: 0**

| # | Subagent | Received | Status | Findings | Decision |
|---|----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 52/52 green, ruff clean, 0 smells; confirmed |
| 2 | reviewer-test-analyzer | Yes | findings | 4 | 1 confirmed→blocking (F1 non-origin e2e), 3 deferred/low |
| 3 | reviewer-type-design | Yes | findings | 2 | 1 low confirmed (TypedDict, F3), 1 low folded into F2 |
| 4 | reviewer-security | Yes | findings | 1 | confirmed low, folded into F2 (`or 'origin'`) |
| 5 | reviewer-rule-checker | Yes | findings | 3 (13 checks, 2 viol.) | 2 confirmed→F2 (§1/§13 same line), 1 dismissed (test docstring) |
| 6 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 8 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (5 enabled returned, 4 disabled pre-filled)

**Working-tree audit:** `pf reviewer audit-tree` reported DIRTY, but the sole flagged path is `sprint/context/context-story-162-86.md` — an untracked **orchestrator-repo** context doc created by sm-setup at 10:30 (before the work phases; validated by the setup-exit gate). The **`pennyfarthing/` source tree under review is CLEAN** and `staleness.py` matches committed HEAD with no leftover mutation. Benign false-positive; `git clean -fd` deliberately NOT run (would delete sm-setup's legitimate context file).

### Rule Compliance (lang-review/python.md)

| # | Rule | Verdict | Evidence |
|---|------|---------|----------|
| 1 | Silent exception / fallback | **1 violation** | `staleness.py:596` `result.get('remote') or 'origin'` — silent display substitution (see F2). Unknown-repo guard (`if repo_cfg is None`) and OSError handlers surface explicit errors — compliant. |
| 2 | Mutable defaults | pass | `remote: str = ""`, `paths_checked/commits=None` sentinels — all immutable/None. |
| 3 | Type annotations at boundaries | pass | `_REPO_CONFIG: dict[str, dict[str, str]]` annotated; `remote: str`; `check_story_staleness` sig unchanged & fully annotated. |
| 4 | Logging | n/a | module uses `print()` + result-dict returns (SOUL #10), no logging import. |
| 5 | Path handling | pass | no new path ops in diff; test helpers use `Path`/`encoding='utf-8'`. |
| 6 | Test quality | pass | every test has specific value assertions; 0 vacuous (banner test asserts presence AND absence). |
| 7 | Resource leaks | pass | no new handles; `write_text`/`subprocess.run` are non-persistent. |
| 8 | Unsafe deserialization | pass | `subprocess.run(shell=False)` argv at both git sites; no pickle/eval/yaml.load. |
| 9 | Async | n/a | no async code. |
| 10 | Import hygiene | pass | no new imports in `staleness.py`; test imports explicit. |
| 11 | Input validation | pass | `remote`/`base` sourced from `_REPO_CONFIG` constant, never operator input (scope guard verified by security subagent). |
| 12 | Dependency hygiene | n/a | no dependency files changed. |
| 13 | Fix-introduced regression | **1 violation** | same instance as #1 — the banner de-hardcoding introduced a silent-fallback the old literal couldn't exhibit (F2). |

### Observations

- `[TEST] [HIGH]` **F1** — Non-origin remote is never exercised end-to-end through `check_story_staleness`; the pipeline-level pin `test_known_repo_resolves_both_base_and_remote_from_one_lookup` uses `remote="origin"` (the only `_REPO_CONFIG` entry), so a hardcoded `_result(remote="origin")` would pass it — a tautology on the story's central claim. `test_162_86_...py:281` + `staleness.py:265`.
- `[RULE] [SEC] [TYPE] [LOW]` **F2** — `_print_human_summary` `result.get('remote') or 'origin'` is a silent display fallback (§1/§13); dead code today but substitutes a possibly-wrong remote silently. `staleness.py:596`.
- `[TYPE] [LOW]` **F3** — `_REPO_CONFIG: dict[str, dict[str, str]]` is a stringly nested dict; a `TypedDict(base, remote)` would make `repo_cfg["base"/"remote"]` mypy-checked. Non-blocking (KeyError impossible on the static literal — rule-checker confirmed). `staleness.py:58`.
- `[VERIFIED]` Behavior parity of Change A — old `_REMOTE_BY_REPO.get(repo_name, "origin")` vs new `repo_cfg["remote"]`: every known repo carried both keys in both old maps, so the `.get` default never fired; `staleness.py:208-209` reads both from the guarded entry. Complies with SOUL #2 (one mirror not two).
- `[VERIFIED]` No injection — `remote` flows to `_resolve_revision` → `["git",...,"rev-parse","--verify",ref]` argv with `shell=False` (`staleness.py:464`); value is a module constant regardless. Confirmed by security subagent.
- `[VERIFIED]` Unknown-repo guard preserved — `_REPO_CONFIG.get(repo_name); if repo_cfg is None: return error naming the repo` (`staleness.py:195-206`); `test_unknown_repo_still_guarded_after_consolidation` + 151-5 `TestUnknownRepoSilentFallback` both green.
- `[VERIFIED]` Regression net intact — 52/52 (162-86 + 162-71 + 151-5) via preflight; 162-71 non-origin `_resolve_revision` resolution pins still pass, so the *resolution* half of non-origin honoring is covered even though the *result-threading* half (F1) is not.
- `[DISMISSED]` rule-checker's test-docstring story-reference note — the pinned rule `test_module_docstring_does_not_reference_specific_story_or_incident` scopes explicitly to `staleness.py`'s production docstring; every `test_NNN_*.py` in the repo names its story by convention. Dismissed citing the rule's own scope.

### Devil's Advocate

Argue this is broken. The whole point of 162-86 is *configured-remote honoring* — making a non-origin repo work. Yet not one test ever pushes a non-origin remote through the real code path (`check_story_staleness` → `_REPO_CONFIG` lookup → `remote` var → `_result`). The only non-origin exercise (`test_drift_banner_shows_configured_remote_not_hardcoded_origin`) hand-builds a result dict and calls `_print_human_summary` in isolation, so it proves the *renderer* honors a remote key — but says nothing about whether the *lookup-to-result pipeline* ever puts a non-origin value there. A malicious (or merely careless) future refactor could replace `_result(remote=remote)` with `_result(remote="origin")` and the entire suite stays green, because the sole `_REPO_CONFIG` entry a pipeline test can reach is itself `origin`. That is not a hypothetical: this project has already been burned by exactly this tautology shape — the 151-5 suite had to add `impl_repo_feature_checkout` specifically because every fixture used `git init -b develop`, making a HEAD-vs-base bug invisible. The same blind spot is back, on the feature's headline behavior. And the fix Dev chose for the banner — `result.get('remote') or 'origin'` — quietly reintroduces a silent fallback into a module whose own docstring declares "silent fallbacks defeat the whole purpose of the check": if a remote ever goes missing, the banner will confidently print `origin/...` and lie about which upstream was compared. A stressed operator debugging a non-origin repo would read that banner, trust it, and chase the wrong branch. Neither issue corrupts data today, but the test gap means the feature's correctness rests on "it's obviously right," which is precisely what a reviewer must refuse to accept. The code is likely correct; the *proof* is not there.

## Reviewer Assessment

**Verdict:** REJECTED — 1 blocking finding (AC-3 not fully met)

**Specialist findings incorporated:** `[TEST]` test-analyzer surfaced F1 (non-origin never driven end-to-end — high). `[RULE]` rule-checker (§1/§13) and `[SEC]` security both flagged F2 (the `or 'origin'` silent display fallback). `[TYPE]` type-design raised F3 (stringly `_REPO_CONFIG`, suggest `TypedDict`) and corroborated F2. `[RULE]` rule-checker's test-docstring note was dismissed (rule scoped to production docstring). Preflight: 52/52 green, ruff clean.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | **F1** — AC-3 ("a non-origin remote exercised by a test — banner **+ lookup** honor it") is only half-met. The lookup→result pipeline is pinned exclusively with `remote="origin"`, so `test_known_repo_resolves_both_base_and_remote_from_one_lookup` is tautological — a hardcoded `_result(remote="origin")` passes it. The feature's central claim (configured-remote honoring end-to-end) is unproven. | `test_162_86_...py:281`, `staleness.py:265` | Add a test that monkeypatches `staleness._REPO_CONFIG` to inject an entry with a **non-origin** remote (e.g. `{"base":"develop","remote":"upstream"}`), drives `check_story_staleness` end-to-end (via `repo_path_overrides`), and asserts `result["remote"] == "upstream"`. This proves the value traverses lookup→`_result`, killing the origin-only tautology. |
| [LOW] | **F2** (fold in same cycle) — `result.get('remote') or 'origin'` is a silent display fallback (§1/§13; 3 specialists concur). Dead today but substitutes a possibly-wrong remote silently. | `staleness.py:596` | Prefer `result.get('remote')` (the drift arm always supplies a non-empty remote), or make a missing remote loud — do not silently substitute `origin`. Cheap, in the file you're already editing. |
| [LOW] | **F3** (optional, may defer) — `_REPO_CONFIG` inner dict is stringly-typed. | `staleness.py:58` | Optional: `class RepoConfig(TypedDict): base: str; remote: str` → `dict[str, RepoConfig]` for mypy-checked key access. Not required this cycle. |

**Rework brief for Dev (B.A.):** F1 is blocking — one new end-to-end non-origin test. F2 is a cheap in-file fold (drop the silent `or 'origin'`). F3 optional. Per-finding disposition required on return (FIXED / DEFERRED each). After the rework commit, do NOT re-run the exit protocol — the green→review phase advance already happened; SM verifies via `pf handoff phase-check` and re-reviews.

**Handoff:** Back to Dev for fixes.

## Subagent Results

**Cycle: 1**

Re-review method: **targeted re-verification** of the three characterized cycle-0 findings via direct probes (not a fresh generalist sweep). Each enabled specialist's domain was re-checked against the exact rework diff; a decisive mutation probe was run for the blocking finding.

| # | Subagent | Received | Status | Findings | Decision |
|---|----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (re-verified) | clean | none | 53/53 green, ruff clean, source tree clean — confirmed by direct run |
| 2 | reviewer-test-analyzer | Yes (re-verified) | resolved | F1 fixed | New e2e test added; MUTATION PROBE confirms non-tautology (hardcoding `remote="origin"` → `assert 'origin' == 'upstream'` FAIL) |
| 3 | reviewer-type-design | Yes (re-verified) | resolved | F3 fixed | `_RepoConfig(TypedDict)` + `dict[str, _RepoConfig]`; ruff clean, runtime-identical |
| 4 | reviewer-security | Yes (re-verified) | resolved | F2 fixed | silent `or 'origin'` removed; no injection surface changed (still argv/shell=False) |
| 5 | reviewer-rule-checker | Yes (re-verified) | resolved | F2 (§1/§13) fixed | banner now `result.get('remote')` — no silent substitution; no new §1 violation |
| 6 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 8 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (5 enabled re-verified via targeted probes, 4 disabled pre-filled)

**Working-tree audit:** source tree CLEAN after the mutation probe (probe restored via `git checkout --`). The orchestrator context-doc false-positive from cycle 0 is unchanged and benign.

## Reviewer Assessment

**Verdict:** APPROVED — all three cycle-0 findings verified fixed via targeted re-verification.

**Specialist re-verification incorporated:**
- `[TEST]` F1 (blocking) FIXED — `test_non_origin_remote_traverses_lookup_into_result_end_to_end` monkeypatches `_REPO_CONFIG["pennyfarthing"]` to `remote="upstream"`, drives `check_story_staleness` end-to-end, asserts `result["remote"] == "upstream"`. Because `"upstream"` exists ONLY in the patched config, it can reach the result solely via the real lookup→`_result` thread — non-tautological by construction, and a **mutation probe** (hardcoding `remote="origin"` at the result site) makes it FAIL `assert 'origin' == 'upstream'`. AC-3's "lookup honor [a non-origin remote]" is now pinned at the pipeline level; the banner half remains covered.
- `[RULE] [SEC]` F2 FIXED — the silent `result.get('remote') or 'origin'` fallback is gone; the banner reads `result.get('remote')`, matching the no-default treatment of `base_branch` on the same line. `test_drift_banner_shows_configured_remote_not_hardcoded_origin` and `_origin_repo` both stay green; no injection surface changed (security).
- `[TYPE]` F3 FIXED — `_RepoConfig(TypedDict)` gives mypy-checked `base`/`remote` access; runtime-identical, ruff clean.

**Data flow re-traced:** `_REPO_CONFIG[repo]["remote"]` → `remote` → `_result(remote=remote)` → `result["remote"]` → `_print_human_summary` banner. Non-origin value now proven to traverse the full path end-to-end.
**Error handling:** unknown-repo guard intact (`if repo_cfg is None`); no silent fallbacks remain.
**Regression:** 53/53 (162-86 9 + 162-71 6 + 151-5 38), ruff clean, source tree clean.

**Handoff:** To SM for finish-story.