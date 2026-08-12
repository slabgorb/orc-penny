---
story_id: "162-71"
jira_key: ""
epic: "epic-162"
workflow: "tdd"
---
# Story 162-71: Finish-probe ref-prefix and case-fold hardening (final sweep)

## Story Details
- **ID:** 162-71
- **Jira Key:** (none — framework-internal story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-71-ref-prefix-hardening
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T17:06:15Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T11:23:43Z | 2026-08-12T11:25:47Z | 2m 4s |
| red | 2026-08-12T11:25:47Z | 2026-08-12T14:32:47Z | 3h 7m |
| green | 2026-08-12T14:32:47Z | 2026-08-12T16:17:01Z | 1h 44m |
| review | 2026-08-12T16:17:01Z | 2026-08-12T17:06:15Z | 49m 14s |
| finish | 2026-08-12T17:06:15Z | - | - |

## Technical Context

### Problem Statement
Combines backlog follow-ups from the 162-4/162-3 lineage. This is a final sweep covering three sub-areas:

1. **162-24: Merge state case-folds (mergeable/mergeStateStatus)**
   - Decision point: de-fold vs pin for case-folds that feed BLOCKING predicate
   - Folding biases toward blocking behavior
   - Approach: pin with lowercase test inputs to verify correctness

2. **162-26: Ref-qualified Branch double-prefix issue**
   - Problem: Branch values like `origin/x` and `refs/heads/x` double-prefix in `_branch_merge_state` and abort
   - Root cause: `strip-prefix` approach is UNSOUND (collides with 162-4 look-alike threat)
   - Decision point: widen validator vs reject in extractor
   - Documentation: base field dual shape at `story_finish.py:371`

3. **162-27: Ref-prefix sweep of remaining probe sites**
   - Scope: `staleness.py:443`, `frame/routes/data_proxy.py:189`
   - Decision point: honor configured-remote parameter or use defaults

### Technical Approach
TEA will define detailed test strategy during RED phase based on these problem areas. The three sub-problems represent independent decisions about ref-prefix handling and case-fold behavior in the finish probe.

### Acceptance Criteria
(To be defined by TEA in RED phase based on technical context above)

## SM Assessment

Story 162-71 (p1, 3 pts, tdd) is the final sweep of the finish-probe ref-prefix / case-fold
lineage (absorbs 162-24, 162-26, 162-27). This is finish-truthfulness machinery — the ceremony
my own handoffs depend on — so it earns the p1 pick and the tdd ceremony.

Setup verified: bare session name, `Phase: setup`, bare `tdd`, branch `feat/162-71-ref-prefix-hardening`
cut off `develop` in the `pennyfarthing/` repo (gitflow — targets develop, not main). No Jira key;
Jira operations skipped by design.

Three independent decisions carry real design risk — TEA and Dev should treat each as a distinct
pin/design call, not a mechanical edit:
- 162-24: the mergeable/mergeStateStatus case-folds feed a BLOCKING predicate, so a fold biases
  toward blocking. Prefer pinning with lowercase test inputs over silently de-folding.
- 162-26: strip-prefix on ref-qualified Branch values is UNSOUND — it collides with the 162-4
  look-alike threat. Decide widen-validator vs reject-in-extractor deliberately; do NOT reach for
  the naive strip. Document the base-field dual shape at `story_finish.py:371`.
- 162-27: sweep the remaining bare-ref probe sites and decide configured-remote honoring rather
  than hardcoding `origin/`.

Handing off to TEA (Igor) for the RED phase to design the failing tests that pin these decisions.

## TEA Assessment

### Red Phase (test writing)

**Tests Required:** Yes
**Status:** RED confirmed (4 clean assertion failures, 3 green-on-arrival guards, 0 errors)

**Material scope finding:** Of the three sub-areas this "final sweep" absorbs, TWO are already
landed and pinned — so the genuine remaining work is 162-27 only:
- 162-24 (mergeable/mergeStateStatus case-fold): already pinned by
  `test_162_19_classify_pr.py::test_case_folded_conflict_fields_still_block` (lowercase
  `conflicting`/`dirty` -> BLOCKED) and `test_162_3_view_is_merged_strict_state.py`. The fold
  lives in `_classify_pr` (`.upper()`), not the stale line ~321-322 the story cites. No new test.
- 162-26 (ref-qualified branch double-prefix in `_branch_merge_state`): the widen-not-strip fix
  landed in commit d3357227f (#218), covered by `test_162_26_*` / `test_162_4_*`; the base
  dual-shape is documented in the `_branch_merge_state` docstring (not the stale :371). No new test.

**162-27 decisions (from the two AskUserQuestion product calls this phase):**
1. Sweep depth = **configured-remote honoring**; full-ref-path / gitrevisions-DWIM hardening is
   OUT OF SCOPE (base/remote come from repos.yaml config, not operator-supplied session fields, so
   the 162-4 threat model does not apply). Probes stay in the bare `<remote>/<base>` shape.
2. data_proxy `developBehind` = **honor per-repo `default_branch`** (main for the orchestrator,
   develop for pennyfarthing). Field rename `developBehind` -> `baseBehind` is a SUGGESTED
   follow-up flagged for Reviewer/frontend, not mandated — see Delivery Findings.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_71_staleness_configured_remote.py` — pins
  `staleness._resolve_revision` honoring a configured remote (real temp git repos; a
  `upstream/<base>` tracking ref with no `origin/<base>` must still resolve).
- `pennyfarthing-dist/src/pf/tests/test_162_71_data_proxy_base_branch.py` — pins the Frame git
  route (`/api/git/all` and `/api/git/`) probing the repo's configured base, not hardcoded
  `origin/develop` (asserts on the git ARGV via a monkeypatched `subprocess.run`, so it survives a
  later field rename).

**Tests Written:** 7 tests (4 RED for the two defects, 3 green-on-arrival regression guards).

### Rule Coverage

| Rule (python.md) | Test(s) | Status |
|------|---------|--------|
| #6 test-quality (meaningful asserts, real fixtures) | all 7 (assert exact revision / argv, not truthiness) | self-checked, no vacuous |
| #8/#11 subprocess ref args stay config-derived (not user-injected) | data_proxy argv probes, staleness `<remote>/<base>` | pinned |
| #13 fix must not regress the origin/develop default | `TestResolveRevisionOriginDefaultPreserved`, `TestGitAllPreservesGitflowBase` | green-on-arrival guards |

**Rules checked:** 3 of 13 applicable to this fix surface have direct test coverage; #3
(type-annotate Dev's new `remote`/`base` params) is a Dev/Reviewer check, not RED-testable.
**Self-check:** 0 vacuous assertions found.

**Handoff:** To Dev (Ponder Stibbons) for GREEN — implement 162-27 only; 162-24/162-26 need no code.

## Dev Assessment

**Implementation Complete:** Yes

**Scope:** 162-27 only, per TEA (162-24/162-26 already landed and pinned — no code).

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/staleness.py` — `_resolve_revision`/`_run_git_log` now take a
  `remote` param (default `origin`) and probe `<remote>/<base>`; `check_story_staleness` resolves
  it from a new `_REMOTE_BY_REPO` inline mirror (both `origin` today) alongside `_BASE_BRANCH_BY_REPO`.
- `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` — `_get_repos_config` now surfaces each
  repo's `default_branch`/`remote_name` as `base`/`remote`; `_get_git_info` takes `base`/`remote`
  and probes `HEAD..<remote>/<base>` for the behind-count; `get_git` (single route) resolves the
  root (path ".") repo's config; `get_git_all` threads each repo's config. JSON field
  `developBehind` name unchanged (rename deferred per product call).

**Tests:** 7/7 story tests GREEN. Regression batch 113/113 (frame_routes + 160-16/17/18/19/22
data_proxy fail-loud/sanitization suites). Ruff clean on both files. Live smoke against the real
orchestrator: `/api/git/all` now returns real `developBehind` counts for the trunk-based
orchestrator (`origin/main`, previously `None` against non-existent `origin/develop`) and
pennyfarthing (`origin/develop`).

**Branch:** feat/162-71-ref-prefix-hardening (framework repo, targets `develop`)

**Handoff:** To Reviewer (Granny Weatherwax) for code review.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)
- **Improvement** (non-blocking): `staleness._REMOTE_BY_REPO` is a behavior-neutral seam (both
  values `origin`) that is over-built (six subagents flagged it) yet under-guarded (`.get(...,"origin")`
  default vs the hard membership guard on `_BASE_BRANCH_BY_REPO`). Affects
  `pennyfarthing-dist/src/pf/sprint/staleness.py` (consolidate the two parallel dicts into one
  dict/dataclass keyed by repo so a new repo co-registers base+remote under the existing guard, OR
  remove the dict and use a `remote="origin"` default param until staleness reads repos.yaml).
  *Found by Reviewer during code review.*
- **Gap** (non-blocking): the data_proxy tests never exercise a non-`origin` `remote_name` (all use
  the `origin` default), so a regressor that re-hardcodes `remote="origin"` while keeping `base`
  dynamic stays green. Affects `pennyfarthing-dist/src/pf/tests/test_162_71_data_proxy_base_branch.py`
  (add a `_write_project(..., remote_name="upstream")` case asserting `upstream` appears in the probe
  argv). Note: the staleness suite DOES pin the remote axis (`upstream/develop`), so the contract is
  substantially covered. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_get_repos_config` docstring claims "Each entry carries `base` and
  `remote`" but the single-repo fallback omits both keys; `list[dict[str, str]]` also hides the
  optional-key contract. Affects `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (scope the
  docstring to the repos.yaml path; consider a `TypedDict(total=False)`). *Found by Reviewer during
  code review.*
- **Improvement** (non-blocking): `get_git` root-repo selection falls to `repos[0]` when repos.yaml
  declares no `.`-path repo among multiple repos, and an empty `repos: {}` yields silent
  develop/origin defaults — both on repos.yaml shapes not present in-tree. Affects
  `frame/routes/data_proxy.py` (log/surface a mismatch, or validate config shape).
  *Found by Reviewer during code review.*

### Dev (implementation)
- **Improvement** (non-blocking): `staleness._print_human_summary` hardcodes `origin/` in the
  drift banner. Now that `check_story_staleness` honors the configured remote, the banner is the
  last `origin`-assuming spot. Affects `pennyfarthing-dist/src/pf/sprint/staleness.py`
  (thread `remote` into the result dict + summary). *Found by Dev during implementation.*
- **Improvement** (non-blocking): confirming TEA's `developBehind` → `baseBehind` finding — the
  field now carries a per-repo base count (main for the orchestrator), so the `develop`-flavored
  name is actively misleading. Affects `frame/routes/data_proxy.py` (`_get_git_info` return +
  `get_git_all`) and the `web/` consumer. *Found by Dev during implementation.*

### TEA (test design)
- **Improvement** (non-blocking): Two of the story's three sub-areas (162-24, 162-26) are already
  landed and pinned; only 162-27 needs code. Affects the story's point estimate/scope (a 3-pt story
  with ~1pt of real work remaining). *Found by TEA during test design.*
- **Question** (non-blocking): data_proxy's JSON field `developBehind` leaks a gitflow assumption
  into a repo-agnostic panel; once it honors per-repo `default_branch`, `baseBehind` is a clearer
  name. Affects `frame/routes/data_proxy.py` (`_get_git_info` return dict + `get_git_all`) and the
  `web/` consumer. Deferred to Reviewer/frontend per the product call — NOT changed in RED.
  *Found by TEA during test design.*
- **Gap** (non-blocking): `staleness._resolve_revision`/`_run_git_log`/`check_story_staleness` have
  no per-repo remote source (the module is deliberately self-contained via inline
  `_BASE_BRANCH_BY_REPO`). The RED pins the `_resolve_revision` unit honoring a configured `remote`;
  Dev must decide how the public entry supplies it (e.g. a `_REMOTE_BY_REPO` mirror, or a
  `repo_remote_overrides` seam like `repo_path_overrides`). Affects `sprint/staleness.py`.
  Note: neither configured repo uses a non-origin remote, so this defect is LATENT — no end-to-end
  demonstrable case exists in-tree, which is why the RED is unit-level. *Found by TEA during test design.*
- **Gap** (non-blocking): the Frame git ROUTE (`get_git` / `get_git_all`) currently reads only
  `{name, path}` from repos.yaml (`_get_repos_config`) — it drops `default_branch`/`remote_name`.
  Dev must extend `_get_repos_config` and thread base+remote into `_get_git_info(repo_path)`. Affects
  `frame/routes/data_proxy.py`. *Found by TEA during test design.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

6 deviations

- **`_print_human_summary` drift line keeps a literal `origin/` prefix**
  - Rationale: the remote is not part of the result-dict contract and the banner is
  - Severity: minor
  - Forward impact: a future non-origin repo would show a cosmetically wrong remote in the
- **staleness remote source wired via a `_REMOTE_BY_REPO` inline mirror**
  - Rationale: keeps the module self-contained (same pattern as `_BASE_BRANCH_BY_REPO`), makes
  - Severity: minor
  - Forward impact: a non-origin repo is honored by updating one dict entry.
- **data_proxy single-repo fallback dict left without `base`/`remote` keys**
  - Rationale: preserving the shape avoids breaking two shipped sibling-story pins; the `.get`
  - Severity: minor
  - Forward impact: none — fallback behavior is unchanged (develop/origin).
- **No new tests for 162-24 and 162-26 (test omission)**
  - Rationale: SOUL #2 (one truth) — duplicating existing pins adds maintenance, not safety.
  - Severity: minor
  - Forward impact: Dev implements 162-27 only; 162-24/162-26 need no code change.
- **Skipped full-ref-path / gitrevisions-DWIM hardening at the swept sites**
  - Rationale: base/remote are repos.yaml config, not operator-supplied session fields, so the
  - Severity: minor
  - Forward impact: if a future site takes an operator-controlled ref, full-ref hardening returns
- **staleness RED asserts a `remote` parameter on `_resolve_revision` (interface definition)**
  - Rationale: "honor configured remote" necessarily introduces an interface; a clean fail beats an
  - Severity: minor
  - Forward impact: Dev owns the exact caller wiring (see Delivery Finding on the missing remote source).

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **`_print_human_summary` drift line keeps a literal `origin/` prefix**
  - Spec source: session product call (162-27 = configured-remote honoring)
  - Spec text: "honor configured remote rather than hardcoding origin/"
  - Implementation: `_resolve_revision`/`_run_git_log`/`check_story_staleness` now honor the
    configured remote, but the human-readable drift banner still prints
    `on origin/{base_branch}` (the `remote` is not threaded into the result dict).
  - Rationale: the remote is not part of the result-dict contract and the banner is
    display-only, untested cosmetic text; all in-tree repos use `origin`, so it is accurate
    today. Threading `remote` into `_result`/`_print_human_summary` is scope beyond the pinned
    behavior. Logged as a Delivery Finding for a follow-up.
  - Severity: minor
  - Forward impact: a future non-origin repo would show a cosmetically wrong remote in the
    drift banner (the actual probe target is correct).
- **staleness remote source wired via a `_REMOTE_BY_REPO` inline mirror**
  - Spec source: TEA Delivery Finding (Gap) — "Dev must decide how the public entry supplies it
    (e.g. a `_REMOTE_BY_REPO` mirror, or a `repo_remote_overrides` seam)"
  - Spec text: RED pins only the `_resolve_revision(remote=...)` unit; caller wiring is Dev's.
  - Implementation: added `_REMOTE_BY_REPO = {"pennyfarthing": "origin", "orchestrator":
    "origin"}` mirroring `_BASE_BRANCH_BY_REPO`, resolved in `check_story_staleness` and threaded
    through `_run_git_log` → `_resolve_revision`.
  - Rationale: keeps the module self-contained (same pattern as `_BASE_BRANCH_BY_REPO`), makes
    the new `remote` param non-dead. Both values are `origin` today (defect is latent per TEA).
  - Severity: minor
  - Forward impact: a non-origin repo is honored by updating one dict entry.
- **data_proxy single-repo fallback dict left without `base`/`remote` keys**
  - Spec source: pinned tests `test_160_16_fail_loud_3.py`, `test_160_18_warning_sink_sanitization.py`
  - Spec text: both assert the fallback shape is exactly `[{"name": ..., "path": "."}]`.
  - Implementation: `_get_repos_config`'s main path returns `base`/`remote`; the single-repo
    fallback keeps its original 2-key shape. The git-route callers default missing keys to
    `develop`/`origin` via `.get`.
  - Rationale: preserving the shape avoids breaking two shipped sibling-story pins; the `.get`
    defaults make the callers tolerant, so the fallback needs no keys.
  - Severity: minor
  - Forward impact: none — fallback behavior is unchanged (develop/origin).

### TEA (test design)
- **No new tests for 162-24 and 162-26 (test omission)**
  - Spec source: context-story-162-71.md, Problem (absorbs 162-24, 162-26, 162-27)
  - Spec text: "Combines backlog follow-ups... Absorbs 162-24, 162-26, 162-27."
  - Implementation: Wrote RED tests only for 162-27. Verified 162-24 is already pinned
    (`test_162_19_classify_pr.py`, `test_162_3_*`) and 162-26 landed in d3357227f (#218) with
    `test_162_26_*`/`test_162_4_*` coverage.
  - Rationale: SOUL #2 (one truth) — duplicating existing pins adds maintenance, not safety.
  - Severity: minor
  - Forward impact: Dev implements 162-27 only; 162-24/162-26 need no code change.
- **Skipped full-ref-path / gitrevisions-DWIM hardening at the swept sites**
  - Spec source: session product call (Sweep depth = configured-remote honoring)
  - Spec text: story title "ref-prefix sweep of remaining bare-ref probe sites"
  - Implementation: RED pins configured-remote honoring only; probes stay bare `<remote>/<base>`
    (not full `refs/remotes/<remote>/<base>`).
  - Rationale: base/remote are repos.yaml config, not operator-supplied session fields, so the
    162-4 attacker-controlled-ref threat that drove full-ref hardening in story_finish does not
    apply here. Confirmed as a product decision.
  - Severity: minor
  - Forward impact: if a future site takes an operator-controlled ref, full-ref hardening returns
    as its own story.
- **staleness RED asserts a `remote` parameter on `_resolve_revision` (interface definition)**
  - Spec source: session product call (configured-remote honoring)
  - Spec text: "honor configured remote rather than hardcoding origin/"
  - Implementation: RED uses `inspect.signature` to require a `remote` param (clean AssertionError
    today instead of a TypeError-error) alongside the behavioral `revision == "upstream/develop"` pin.
  - Rationale: "honor configured remote" necessarily introduces an interface; a clean fail beats an
    errored test. Dev may name/shape the param differently as long as the behavioral pin passes —
    the sig check is the tripwire, not the contract.
  - Severity: minor
  - Forward impact: Dev owns the exact caller wiring (see Delivery Finding on the missing remote source).

### Reviewer (audit)
- **Dev: `_print_human_summary` keeps literal `origin/`** → ✓ ACCEPTED: display-only banner, not part
  of the result-dict contract; accurate for all in-tree repos (both `origin`). Corroborated by
  [DOC]/[SIMPLE] as a non-blocking consistency gap; captured as a Delivery Finding for follow-up.
- **Dev: staleness remote wired via `_REMOTE_BY_REPO` inline mirror** → ✓ ACCEPTED: TEA's Delivery
  Finding explicitly pre-sanctioned "a `_REMOTE_BY_REPO` mirror" as one of two valid wirings.
  Behavior-neutral (both `origin`); cannot misfire today (the `repo_name not in _BASE_BRANCH_BY_REPO`
  guard at staleness.py:188 rejects unknown repos before the remote lookup). Six subagents converged
  on this seam as over-built/under-guarded — real, but MEDIUM/LOW and latent. Captured as a Delivery
  Finding recommending consolidation (single dict/dataclass) or removal.
- **Dev: data_proxy fallback dict without base/remote keys** → ✓ ACCEPTED: preserves the exact
  fallback shape pinned by `test_160_16`/`test_160_18`; callers default via `.get("base","develop")`
  / `.get("remote","origin")`, so the fallback is behavior-identical to pre-162-27.
- **TEA: no new tests for 162-24/162-26** → ✓ ACCEPTED: verified 162-24 pinned by
  `test_162_19_classify_pr.py`/`test_162_3_*` and 162-26 landed in d3357227f (#218) with
  `test_162_26_*`/`test_162_4_*`. Duplicating existing pins would violate SOUL #2.
- **TEA: skipped full-ref-path hardening; RED asserts `remote` param via `inspect.signature`** →
  ✓ ACCEPTED: the config-not-session-input threat boundary is confirmed sound by [SEC]. The
  `inspect.signature` tripwire is redundant with the behavioral pin ([TEST] noted); harmless,
  non-blocking.

## Subagent Results

**Cycle: 0** (first review — session carries no `**Round-Trip Count:**`; all 9 subagents run fresh against the full diff)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 (113 tests pass, ruff clean, no debug code) | N/A — corroborated by my own independent run (94/94 + 113/113) |
| 2 | reviewer-edge-hunter | Yes | findings | 4 | confirmed 3 (MEDIUM/LOW, non-blocking), dismissed 1 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 2 | confirmed 2 (MEDIUM/LOW, non-blocking) |
| 4 | reviewer-test-analyzer | Yes | findings | 4 | confirmed 2 (1 MEDIUM coverage gap, 1 LOW), dismissed 2 |
| 5 | reviewer-comment-analyzer | Yes | findings | 3 | confirmed 2 (LOW), dismissed 1 |
| 6 | reviewer-type-design | Yes | findings | 2 | confirmed 2 (LOW, non-blocking) |
| 7 | reviewer-security | Yes | clean | 0 (config-not-input premise verified; no injection/leak) | N/A |
| 8 | reviewer-simplifier | Yes | findings | 4 | confirmed 3 (MEDIUM/LOW), dismissed 1 |
| 9 | reviewer-rule-checker | Yes | findings | 2 | confirmed 2 (LOW; 13 lang rules + 2 SOUL rules clean across 62 instances) |

**All received:** Yes (9 returned; preflight re-run once after a transient 529)
**Total findings:** 12 confirmed (all MEDIUM/LOW, none blocking), 5 dismissed (with rationale), 0 deferred

**Working-tree audit:** `pf reviewer audit-tree` returned DIRTY (exit 1) — FALSE POSITIVE. The three
dirty paths are all orchestrator-repo agent artifacts, NOT reviewer-subagent source mutations:
`.pennyfarthing/sidecars/dev/patterns.md` (my Dev green-phase learning, +4), `sidecars/tea/patterns.md`
(dirty at session start, +28), and the untracked `sprint/context/context-story-162-71.md` (present at
session start). The **framework repo** (`pennyfarthing/`, where the reviewed code lives) is fully
clean — verified via `git status --porcelain` — proving no subagent altered the reviewed source (all
9 were read-only Bash/Read/Glob/Grep). Did NOT run `git checkout -- . && git clean -fd`: that would
destroy legitimate agent learnings and the audit's actual concern (subagent-injected source mutation)
did not occur.

### Dismissed findings (rationale)
- [TEST] `inspect.signature` "redundant with TypeError" → dismissed as blocking: it is a TEA-designed
  tripwire giving a clearer message than a raw TypeError; harmless. Noted as LOW.
- [TEST] copy-paste of the two data_proxy tests / signature block could parametrize → dismissed:
  style-only, no correctness impact.
- [DOC] `developBehind`→`baseBehind` rename deferral lacks a story ID → dismissed as blocking; the
  deferral is already captured as a Delivery Finding (TEA + Dev), which is the trackable reference.
- [SIMPLE] `get_git` re-reads repos.yaml overhead → dismissed: file read on a low-frequency dashboard
  poll route; the coupling is deliberate (honor repos.yaml on the single route too).
- [EDGE] non-string `default_branch` passes the `or` guard → dismissed as blocking: requires a
  malformed repos.yaml; worst case is a failed probe (returncode!=0 → None), not incorrect data.

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** Story 162-71 (162-27 sub-area) de-hardcodes `origin/develop` at two git-probe sites so
each honors the repo's configured `default_branch`/`remote_name`. The load-bearing fix — the
trunk-based orchestrator's `developBehind` was silently `None` against a non-existent `origin/develop`
and now returns a real count against `origin/main` — is correct, secure, and verified. No Critical or
High findings from any of the 9 subagents or my own analysis. The 12 confirmed findings are all
MEDIUM/LOW maintainability/coverage/doc items on latent, not-in-tree-reachable paths.

**Data flow traced:** repos.yaml `default_branch`/`remote_name` → `_get_repos_config` (`yaml.safe_load`,
`encoding="utf-8"`) → `base`/`remote` dict keys → `_get_git_info(base, remote)` →
`f"HEAD..{remote}/{base}"` as a single argv token in `subprocess.run([...], shell=False)`. Safe:
shell metachars inert (shell=False), and the token begins with `HEAD..` so it cannot be misparsed as
an option. Config is checked-in and trusted (not operator/session/HTTP input) — premise verified by
[SEC]. Live-smoked in green phase: orchestrator→`origin/main` real count, pennyfarthing→`origin/develop`.

**Observations (12 confirmed + verifieds):**
1. [VERIFIED] The behind-probe correctness fix is real — `_get_git_info` data_proxy.py:280
   `f"HEAD..{remote}/{base}"` replaces the hardcoded `origin/develop`; both `/api/git/` and
   `/api/git/all` covered by tests; complies with lang-review #5/#8/#11 (argv, shell=False, safe_load).
2. [VERIFIED] No security regression — [SEC] clean: config-not-input premise holds, no injection, no
   ref-prefix (162-4) vuln reintroduced, response shape unchanged (`developBehind: int|None`).
3. [SILENT]/[EDGE]/[TYPE]/[SIMPLE]/[RULE] `[MEDIUM]` `_REMOTE_BY_REPO` seam at staleness.py:62 —
   over-built (both `origin`, zero behavioral differentiation) AND under-guarded (`.get` default vs
   the hard membership guard on `_BASE_BRANCH_BY_REPO`). Cannot misfire today (guard rejects unknown
   repos; both repos `origin`); TEA pre-sanctioned the mirror. Non-blocking; consolidation filed.
4. [TEST] `[MEDIUM]` data_proxy tests never exercise a non-`origin` `remote_name` at
   test_162_71_data_proxy_base_branch.py:88 — remote axis not pinned end-to-end for the route (it IS
   pinned in the staleness suite via `upstream/develop`). Coverage gap, non-blocking; filed.
5. [EDGE] `[MEDIUM]` `get_git` root selection falls to `repos[0]` for a no-`.`-path multi-repo
   repos.yaml (data_proxy.py:361), and empty `repos: {}` silently defaults — both on shapes absent
   in-tree. Non-blocking; filed.
6. [DOC]/[TYPE] `[LOW]` `_get_repos_config` docstring/annotation overclaim vs the key-omitting
   fallback (data_proxy.py:306) — accurate inline fallback comment, but the function docstring says
   "Each entry carries base/remote". Non-blocking; filed.
7. [DOC]/[SIMPLE] `[LOW]` `_print_human_summary` still prints `origin/{base}` (staleness.py:~593, not
   in diff) — cosmetic, accurate today; Dev already logged as a deviation + finding.
8. [RULE] `[LOW]` async blocking I/O: `get_git` now calls `_get_repos_config` (read_text + safe_load)
   from an `async def` — extends the pre-existing blocking pattern already in `get_git_all`; negligible
   for a poll route. Non-blocking.
9. [VERIFIED] Backward compatibility — the `origin` default on all new params + the key-omitting
   fallback + `.get` defaults preserve pre-162-27 behavior; the two green-on-arrival regression guards
   (origin default; gitflow develop) pass.

**Pattern observed:** Minimal, TEA-interface-faithful threading of `base`/`remote` through private
helpers, with defaults preserving legacy behavior — good. The parallel `_BASE_BRANCH_BY_REPO` /
`_REMOTE_BY_REPO` dicts are the one anti-pattern (mirrored config, asymmetric access) — real but LOW.

**Error handling:** `_get_git_info` degrades to `develop_behind=None` when the `<remote>/<base>` ref
is absent (returncode!=0 → `_run` returns None) — same as pre-diff, not a new silent failure.
`_resolve_revision` returns an error tuple (never throws); pre-existing broad `except Exception` blocks
(warnings-sanitized, 160-16..22) are outside this diff's added lines.

### Rule Compliance
Lang-review `python.md` — checked by [RULE] across 62 instances, cross-verified by me:
- #1 silent-exceptions: compliant (new `.get` default documented; no new bare/blanket catch).
- #2 mutable-defaults: compliant (all new defaults are `str` literals; `_REMOTE_BY_REPO` is a
  module constant, not a default arg).
- #3 type-annotations: compliant (all changed helpers fully annotated; `Any` in `_get_git_info`
  return is justified by the heterogeneous response dict).
- #4 logging, #5 path-handling (encoding="utf-8", pathlib, argv tokens not file paths), #6
  test-quality (no vacuous asserts; correct monkeypatch target), #7 resource-leaks (read_text/run
  self-closing), #8 unsafe-deserialization (`yaml.safe_load`, `shell=False`), #10 import-hygiene
  (function-local imports are the established pattern here), #11 input-validation (config, not user
  input), #13 fix-regressions: all compliant.
- #9 async-pitfalls: one LOW (blocking `_get_repos_config` in `get_git` async) — extends existing
  pattern, non-blocking.
- #12 dependency-hygiene: N/A (no dependency files changed).
SOUL: #10 return-results (documented tuples / JSONResponse) compliant; #2 one-truth — `_REMOTE_BY_REPO`
duplicates repos.yaml (LOW, latent, accepted deviation).

### Devil's Advocate
Argue this is broken. First attack — the "honoring" is theater: `_REMOTE_BY_REPO` maps both repos to
`origin`, identical to the `.get` default, and staleness never reads repos.yaml, so the seam auto-syncs
nothing. A cynic says the story claims to "honor the configured remote" while shipping code that, for
every repo that exists, behaves exactly as the hardcoded `origin/` it replaced — the only *proven*
behavioral change is in data_proxy (base branch), not the remote. Rebuttal: that is precisely why Dev
logged it as a deviation and I filed a consolidation finding; the data_proxy half IS a real, smoked
behavioral fix (orchestrator `developBehind` went from `None` to a real count), and the staleness
`remote` param is a correct, tested generalization even if latent. Second attack — a malicious or
fat-fingered `repos.yaml`: `default_branch: "; rm -rf ~"` or `--upload-pack=evil`. Could that reach a
shell or inject a git option? Traced: it lands as one argv element in a `shell=False` list, and the
data_proxy token is `HEAD..<value>` (never option-like); staleness's `<remote>/<base>` could be
option-like only if `remote` started with `-`, but `remote` there comes from a Python-source dict, not
the file. [SEC] confirmed no injection surface; worst case is a failed probe. Third attack — a confused
operator with a multi-repo repos.yaml where the root project isn't declared at path `.`: `get_git`
silently reports the first repo's base. Real, but a not-in-tree misconfig and a wrong *count*, not
corruption — MEDIUM, filed. Fourth — the test suite lies: a regressor re-hardcoding `remote="origin"`
in data_proxy stays green because no test uses a non-origin remote. True and the most actionable gap;
it's non-blocking because the code threads `remote` identically to `base` (which IS pinned) and the
staleness suite pins the remote axis directly. Nothing here rises to data loss, security, or a
currently-reachable wrong result. The devil finds polish, not a blocker.

**Handoff:** To SM for finish-story.