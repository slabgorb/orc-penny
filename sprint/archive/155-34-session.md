---
story_id: "155-34"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-34: finish must not mark a story done when no PR resolves but the branch has unmerged commits (155-1 guarantee only covers the resolved-PR path)

## Story Details
- **ID:** 155-34
- **Jira Key:** (none — sprints are local-only)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/155-34-finish-no-pr-unmerged-commits
- **PR:** #167 - finish verifies the branch actually landed in the no-PR path

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-01T17:41:51Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-01T16:59:28Z | 2026-08-01T17:02:20Z | 2m 52s |
| red | 2026-08-01T17:02:20Z | 2026-08-01T17:21:58Z | 19m 38s |
| green | 2026-08-01T17:21:58Z | 2026-08-01T17:31:28Z | 9m 30s |
| review | 2026-08-01T17:31:28Z | 2026-08-01T17:41:51Z | 10m 23s |
| finish | 2026-08-01T17:41:51Z | - | - |

## Story Context

### Technical Approach
This story extends the 155-1 finish-truthfulness guarantee. The issue: `pf sprint story finish` on a story whose session has no resolvable PR can take the no-PR arm and mark the story done even if the story branch has commits not merged into develop — a silent false-done.

The fix belongs in `pennyfarthing/pennyfarthing-dist/src/pf/` finish/merge path (likely `finish_story` / merge_pr step area — TEA/Dev will locate exact files). 

**Key acceptance criterion:** finish must detect unmerged branch commits in the no-PR path and abort loudly (result object, not throw) rather than marking done.

From the acceptance criteria: the placeholder-shape no-resolution world (from 155-40) means a placeholder or empty Branch/PR value in Story Details now blocks later-section fallback, so the placeholder-plus-hand-written-recovery session resolves nothing — the loud abort must fire for this shape instead of the accepted no-PR done path.

### Acceptance Criteria
1. Cover the placeholder-shape no-resolution world (from 155-40): a placeholder or empty Branch/PR value in Story Details now blocks later-section fallback (security-correct), so the placeholder-plus-hand-written-recovery session resolves nothing — the loud abort must fire for this shape instead of the accepted no-PR done path

## Sm Assessment

**Story selection:** 155-34 picked manually over four other p1s (155-35/36/37 are 1-pt siblings from the same review; 159-15 is a 3-pt broad triage). Rationale: highest-leverage ceremony de-risk — it closes the last known false-done hole in the 155-1 finish-truthfulness guarantee (the no-PR arm marking done while the story branch holds unmerged commits). Merge gate was clean in both repos at selection time.

**Scope guardrails for the pipeline:**
- Code lives in `pennyfarthing/pennyfarthing-dist/src/pf/` finish path (the `finish_story` no-PR arm and its session-field resolution). The 155-40 anchored parser is live — the placeholder-shape AC exists precisely because placeholder/empty field values now block later-section fallback.
- Failure mode must be a loud abort via result object (`{success: False, error: ...}`), never a throw, per project convention.
- The accepted no-PR done path (155-1: genuinely absent PR, branch fully merged) must REMAIN accepted — the new guard only fires when the branch has commits not merged into `develop`.
- Poison-token discipline applies to every agent writing this session: bold field tokens only in Story Details / Workflow Tracking; backticks in prose.

**Routing:** tdd (phased) → TEA (red) → Dev (green) → Reviewer (review) → SM (finish). Jira explicitly skipped (local-only sprint, no key).

## Delivery Findings

No upstream findings

### TEA (test design)

- **Question** (non-blocking): sessions lacking the merge-target keys entirely (pre-155-33 legacy shape, no `Branch`/`PR` lines at all) are deliberately unpinned — the suite pins placeholder/empty (abort) and sentinel (accept) only. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (Dev chooses: uniform abort for unresolvable worlds, or legacy acceptance; document the choice). *Found by TEA during test design.*
- **Question** (non-blocking): dry-run preview parity for the new abort — the preview's no-PR arm still promises the full done plan for a session the real run will now refuse. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (155-31's parity principle suggests the preview should predict the abort; 155-39 dry-run polish may be the right home). *Found by TEA during test design.*
- **Gap** (non-blocking): the new probe targets `project_root`, but in the real orchestrator deployment the code branch lives in `pennyfarthing/` while `project_root` is the orchestrator — the same repo-routing gap 155-18 owns for the gh calls. The fixture pins the single-repo contract only. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (fold the git probe into 155-18's cwd routing when that story lands). *Found by TEA during test design.*
- **Improvement** (non-blocking): the finish preflight (`pf/preflight/finish.py`) has no notion of the unmerged-branch-no-PR world either — it could warn before the ceremony ever starts. Affects `pennyfarthing-dist/src/pf/preflight/finish.py` (sibling of 155-14/155-19 scope). *Found by TEA during test design.*

### Dev (implementation)

- **Conflict** (non-blocking): the dry-run preview now drifts from the real run for the new abort worlds — it still previews "No PR to merge" plus the full done plan for a session the real run refuses. The 155-31 preview/reality-parity class; needs its own preview pins, so deferred rather than done untested. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (dry-run Step 2 preview should predict the abort; fold into 155-39 or a new story). *Found by Dev during implementation.*
- **Gap** (non-blocking): TEA's sibling sweep counted merge-target fields per FILE, which misses per-SESSION gaps in multi-session files — four more worlds needed the sentinel pre-adjustment at green (`test_story_finish_no_jira.py` HOBBY_SESSION, `test_160_3_jira_sentinel_gating.py` template session, `test_155_6_finish_not_found_lists_candidates.py` KNOWN_SESSION, `test_153_4_story_mutation_on_sharded_yaml.py` inline PROJ-17083 session). Affects the TEA sweep recipe (count fields per session fixture, not per file). *Found by Dev during implementation.*
- **Improvement** (non-blocking): `_resolve_base_branch` and Step 6's root-repo lookup each call `load_repos_config` (two YAML reads per finish) — a tiny consolidation candidate. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (share one lookup). *Found by Dev during implementation.*

### Reviewer (code review)

- **Improvement** (non-blocking): harden the merge-state probe candidates against option-shaped values by ref-prefixing — probes proved `git rev-parse --verify --quiet -- <branch>` BREAKS resolution (post-`--` tokens read as paths, rc=1 on a real branch), while `refs/heads/<branch>` / `refs/remotes/origin/<branch>` resolve correctly and cannot be flag-parsed; today an option-shaped value fails closed into the loud abort (probed rc=1/rc=128), so this is forward-looking consistency with the `_git_cleanup` `--` precedent, not a live hole. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_branch_merge_state` candidates; needs its own RED — the naive `--` fix ships a regression). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): wrap the `load_repos_config` consumers in finish against a malformed `repos.yaml` raising through the no-throw boundary — the class is PRE-EXISTING (line 1045 runs on every completed finish, post-merge, where the strand is worse); the new line-342 call narrows the damage window to pre-irreversible. Same wrap-fragile-reads family as backlog story 155-45 — fold there via an added AC rather than a new story. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` + `pf/git/repos.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): test-polish — three defensive paths are unpinned (fixture keeps local and origin refs in sync, so mutations dropping the `origin/<base>` preference or the `origin/<branch>` fallback candidate survive; the backticked/annotated sentinel variant is live-smoked but untested). Fold into 155-42's conftest/test-hygiene scope or a 1-pt sibling. Affects `pennyfarthing-dist/src/pf/tests/test_155_34_finish_no_pr_unmerged_branch.py`. *Found by Reviewer during code review.*
- **Question** (non-blocking): squash-merged-without-recorded-PR worlds read as unmerged (probed: `rev-list --count` = 1 after `git merge --squash`) and abort — the safe direction, and recording the PR (whose metadata a squash-merge always has) is the documented recovery; `git cherry` would not help (patch-ids diverge on squash). Worth a line in the finish guide when one exists. Affects docs only. *Found by Reviewer during code review.*

## Design Deviations

### TEA (test design)
- **Missing-branch-ref world pinned as abort (beyond the literal AC)**
  - Spec source: context-story-155-34.md, AC + story title
  - Spec text: "the loud abort must fire for this shape instead of the accepted no-PR done path" (title adds the unmerged-commits world)
  - Implementation: `test_session_branch_missing_from_repo_aborts` pins a session naming a branch absent from the repo and its origin as a loud abort, not done
  - Rationale: rule #1 (unknown is never merged) — finish cannot verify a branch it cannot see; the truthful wedge (operator affirms state, retries) beats a silent false-done; TEA contract call, Reviewer override invited
  - Severity: minor
  - Forward impact: a deleted-branch recovery world (placeholder `PR` field plus branch already merged-and-deleted out of band) now requires the operator to record the PR or sentinel the branch field before finish passes
  - → ✓ ACCEPTED by Reviewer: rule #1 correctly applied; my scratch-repo probes confirm ghost and even option-like branch values land in the loud abort (rev-parse rc=1, rev-list rc=128 → unknown), never a false-done — the wedge is truthful and the message actionable
- **Sentinel-vs-placeholder three-way contract forced via raw field values**
  - Spec source: context-story-155-34.md AC; 155-33 sentinel semantics; 155-1 product decision (2026-06-04)
  - Spec text: AC names placeholder/empty as abort; 155-1 accepted the no-PR done path
  - Implementation: sentinel `none` (affirmative absence) stays accepted; placeholder/empty (unrecorded) aborts; key-absent legacy shape left unpinned (Question finding)
  - Rationale: extraction collapses all three to None, so the tests force Dev to read the raw session field; preserves both the AC and the shipped 155-1/155-33 pins without breaking either
  - Severity: minor
  - Forward impact: Dev must distinguish raw values (the `_BRANCH_SENTINELS` set vs empty/parenthetical placeholder); key-absent behavior is Dev's documented choice
  - → ✓ ACCEPTED by Reviewer: the three-way contract preserves both the AC's abort and the shipped 155-1/155-33 pins; implementation reads the raw field exactly as designed and reuses the extraction's own normalization
- **Five sibling suites pre-adjusted to the none-sentinel shape**
  - Spec source: sibling suites 155-1, 155-15, 147-12, 151-3, 153-4 (shipped pins)
  - Spec text: their no-PR worlds pinned ceremony success with incidental real branch names
  - Implementation: converted their session fixtures' `Branch` values to the sentinel `none` (155-1 got a dedicated sentinel session; its overreach-test docstring records the 155-34 reinterpretation)
  - Rationale: post-fix those worlds would meet the new probe with generic rc0/empty mocks — a parse-shape lottery; the sentinel keeps each test's actual intent (transition chain, shard mutation, no-stray-archive) green on HEAD and post-fix; coverage of the real-branch no-PR world moves to the 155-34 suite with a real git fixture
  - Severity: minor
  - Forward impact: none — 379 family tests green on HEAD after adjustment
  - → ✓ ACCEPTED by Reviewer: verified the conversions preserve each suite's actual intent (transition chains, shard mutation, no-stray-archive) and the family runs 383 green post-fix; the coverage of the real-branch no-PR world genuinely moved to the new suite rather than vanishing
- **Green-on-arrival guards are intentional**
  - Spec source: context-story-155-34.md AC (preservation half)
  - Spec text: abort "instead of the accepted no-PR done path" implies the accepted path survives elsewhere
  - Implementation: fully-merged world, sentinel world, and the AST subprocess-inside-`_run` convention pin are green on HEAD by design
  - Rationale: over-reach guards constrain the fix shape (and the merged/abort pair enforces `cwd=project_root` on any probe — see the suite docstring's cwd-forcing note)
  - Severity: minor
  - Forward impact: Dev green on these three is verification, not vacuity
  - → ✓ ACCEPTED by Reviewer: the cwd-forcing pair is sound design (a cwd-less probe fails one side of the pair whichever way its error path leans) and the AST seam guard protects two dozen sibling harnesses
- **RED verified by direct scoped runs; testing-runner not spawned**
  - Spec source: agent definition step 6 (spawn testing-runner) vs sidecar gotchas (runner hallucinates failure reasons; runner clobbers live sessions)
  - Spec text: "Spawn testing-runner to verify RED state"
  - Implementation: direct `uv run pytest` scoped runs (suite + 5 adjusted files + 24-file family sweep), failure reasons read first-hand
  - Rationale: this story's suite IS about session parsing and the live session is the poison-incident class; the runner's known session-clobber and reason-hallucination risks outweigh ceremony; all evidence recorded in the assessment
  - Severity: minor
  - Forward impact: Dev/Reviewer re-verify with the same scoped commands
  - → ✓ ACCEPTED by Reviewer: direct scoped evidence with first-hand failure-reason reads beats the haiku runner's known hallucination risk on a parser-family story; Dev's later runner invocation with the leash returned consistent numbers (390/0)

### Dev (implementation)
- **Uniform abort for key-absent legacy sessions (TEA's open Question, answered)**
  - Spec source: TEA Delivery Finding (Question) + test-file docstring "Deliberately unpinned"
  - Spec text: "sessions lacking the merge-target keys entirely ... Dev's call; document the choice"
  - Implementation: the resolves-nothing abort arm catches absent keys the same as empty/placeholder values; only a sentinel or a verified-merged branch is accepted
  - Rationale: unresolvable is unverifiable regardless of why — one rule, no template archaeology; every live suite fixture in that world was pre-adjusted to the sentinel, so nothing shipped depends on fieldless acceptance
  - Severity: minor
  - Forward impact: a hand-built minimal session must carry a `Branch` line (sentinel or real) to finish; the abort message says exactly that
  - → ✓ ACCEPTED by Reviewer: uniform-abort is the coherent closure of TEA's open Question — every live fixture in that world was verifiably adjusted (I re-ran the family), the direction is safe (abort, never false-done), and the recovery is one actionable line
- **Base-branch fallback to develop when no repos.yaml root resolves**
  - Spec source: TEA designed interface (fixture declares gitflow develop; fallback shape unspecified)
  - Spec text: "config-driven, hardcoded-develop, and origin/develop resolutions all agree" in the fixture
  - Implementation: root repo `default_branch` from repos.yaml when present, else the literal `develop` (the gitflow base this finish flow serves); probe prefers `origin/<base>` over the possibly-stale local ref
  - Rationale: an unresolved root cannot be guessed at reliably; develop matches the module's gitflow world, and a wrong guess degrades to an unknown-state loud abort, never a silent done — live smoke confirmed the fallback fires for `pennyfarthing/` (its repos.yaml lives at the orchestrator root)
  - Severity: minor
  - Forward impact: trunk-based repos without repos.yaml probing no-PR worlds will read unknown and abort; recording the PR (the normal path) is unaffected
  - → ✓ ACCEPTED by Reviewer: a wrong base guess degrades to the loud abort, never a silent done — the failure direction makes the fallback safe; live smoke proved the fallback fires in the real pennyfarthing/ layout
- **Four additional sibling pre-adjustments beyond TEA's five, plus in-diff lint cleanup**
  - Spec source: TEA Design Deviation "Five sibling suites pre-adjusted" + the 383-green family bar
  - Spec text: "379 family tests green on HEAD after adjustment"
  - Implementation: sentinel-converted the four sweep-missed worlds (no_jira, 160-3, 155-6, 153-4-inline); fixed pre-existing F401/C416 in `test_160_3` (file already in the story diff)
  - Rationale: identical fix-agnostic move TEA established; leaving them red would fail the family bar for incidental fixture reasons
  - Severity: minor
  - Forward impact: none — family now 383/383 green post-fix
  - → ✓ ACCEPTED by Reviewer: same fix-agnostic move as TEA's five, verified in my own family run; the in-diff lint cleanup is confirmed pre-existing (the diff touches only fixture text near those lines)
- **Truthful step-record key on the verified-merged skip**
  - Spec source: TEA merged-world guard (step shape unpinned) + epic 155 truthful-records class
  - Spec text: abort records "must not carry the silent skipped wording"
  - Implementation: the accepted merged-world skip carries `branch_verified_merged_into: origin/<base>` so the report says WHY the skip is sound; sentinel skip stays the bare shape sibling suites know
  - Rationale: SOUL #14 — the record distinguishes verified-skip from affirmed-skip; no test pins against extra keys
  - Severity: minor
  - Forward impact: none
  - → ✓ ACCEPTED by Reviewer: SOUL #14 — the record distinguishing verified-skip from affirmed-skip is honest reporting; no sibling pin constrains the key
- **Dry-run preview left unchanged**
  - Spec source: TEA Delivery Finding (Question) routing preview parity to 155-39
  - Spec text: "dry-run preview parity for the new abort — left to Dev/Reviewer"
  - Implementation: no dry-run changes; the drift is recorded as a Dev Conflict finding
  - Rationale: preview logic needs its own pins (155-31 precedent); untested preview branches are the 160-20 scope-creep trap
  - Severity: minor
  - Forward impact: dry-run over-promises for abort worlds until 155-39 (or a sibling) closes it
  - → ✓ ACCEPTED by Reviewer: correct scope discipline — untested preview branches are the 160-20 trap; the drift is disclosed as a Conflict finding and 155-39 is the thematically-exact home. Preview parity needs its own pins (155-31 precedent)

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_field_is_sentinel` + `_resolve_base_branch` + `_branch_merge_state` helpers and the no-PR verification gate replacing the bare skip arm (+186/-1)
- `pennyfarthing-dist/src/pf/tests/test_story_finish_no_jira.py`, `test_160_3_jira_sentinel_gating.py`, `test_155_6_finish_not_found_lists_candidates.py`, `test_153_4_story_mutation_on_sharded_yaml.py` — sweep-missed sibling worlds sentinel-converted (green pre- and post-fix); `test_160_3` pre-existing lint cleaned

**Tests:** 7/7 story suite; 383/383 full finish family (24 suites); testing-runner confirmation 390 passed / 0 failed with report-don't-fix leash, working tree diff-verified untouched after the run
**Live smoke:** `_branch_merge_state` against the real repo — this story's own branch reads `unmerged, count 1, base origin/develop`; a ghost branch reads `unknown / branch not found locally or on origin`; sentinel predicate rejects the template placeholder and empty values, accepts `none` and backticked/annotated sentinels
**Lint:** `ruff check` clean on all six touched files
**Branch:** feat/155-34-finish-no-pr-unmerged-commits (pushed; commits 4b1c25ead RED, f4c245bd2 GREEN)

**Handoff:** To The Queen of Hearts (Reviewer) for review — the gate's contract, the uniform-abort choice on legacy sessions, and the abort-on-unknown stance (TEA invited override) are the judgment calls worth her scrutiny.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_34_finish_no_pr_unmerged_branch.py` (new) — 4 RED + 3 green guards
- Pre-adjusted (green on HEAD): `test_155_1_finish_verifies_merge.py`, `test_155_15_finish_blocked_merge_no_stray_archive.py`, `test_147_12_finish_backlog_bridge.py`, `test_151_3_sharded_update_and_finish_loud.py`, `test_153_4_story_mutation_on_sharded_yaml.py`

**Tests Written:** 7 tests covering the story-YAML AC plus 3 TEA-defined ACs (AC record lives in the test-file docstring, 155-13 precedent)
**Status:** RED (4 failing on assertions, 0 errored — ready for Dev)

**Evidence (direct scoped runs, 2026-08-01):**
- New suite: `4 failed, 3 passed in 2.99s`; all 4 failures are the `success is True` false-done assert (counted 4/4 via grep) — right reasons confirmed first-hand
- Family sweep (all 24 suites importing the finish module): `4 failed, 379 passed in 8.75s` — the only failures are the new REDs; zero sibling breakage
- `ruff check` clean on all 6 touched files
- RED commit on `feat/155-34-finish-no-pr-unmerged-commits`: 4b1c25ead

**The hole being closed:** Step 2's last unguarded arm — when neither the session nor `gh pr list --head` resolves a PR, finish records a silent skip and completes the done ceremony even when the story branch holds commits never merged into the base. After 155-40, a placeholder/empty merge-target field in Story Details correctly blocks later-section fallback, which makes the resolves-nothing glide MORE reachable, not less.

**Contract pinned (fix-agnostic):**
1. Unmerged branch + no resolvable PR (empty answer or errored probe) → loud abort: result `success` False, error names the branch and says unmerged, session kept, no archive copy, no done transition, no `gh pr merge`, no lying skipped step record.
2. Placeholder/empty merge-target fields resolving nothing (the AC shape, recovery hand-writes blocked by 155-40 authority) → same loud abort, error points at the unresolvable fields.
3. Branch named but absent from repo and origin → abort (unknown is never merged; TEA call, see deviations).
4. Preserved accepted worlds: sentinel `none` (affirmative absence) and fully-merged branch both still finish, archive, and transition done.

**Designed interface for Dev (docstring has the full version):** route the probe through `_run` with explicit `cwd=str(project_root)` (the AST guard pins the convention; the real-git fixture + unique branch name enforce the cwd); base branch resolutions agree in the fixture (repos.yaml gitflow `develop`, live origin); distinguish sentinel from placeholder/empty via the RAW session field value, not the collapsed extraction.

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| SOUL #10 / py #13 result-not-throw | every abort test calls `finish_story` bare; a raised exception errors the test | failing (RED asserts) |
| py #1 no-silent-swallow | `test_gh_list_error_with_unmerged_branch_still_aborts`, `test_session_branch_missing_from_repo_aborts` | failing |
| Truthful step records (epic 155 class) | silent-skip wording assert in `_assert_abort_invariants` | failing |
| Hermetic seam convention (py #6 patch-where-used family) | `test_no_direct_subprocess_outside_run` (AST) | passing guard |
| 155-15 no-stray-archive extension | archive-absence assert in `_assert_abort_invariants` | failing |
| py #5 encoding on reads | no new reads introduced by tests; module pin already shipped in 155-40 suite | covered by sibling |

**Rules checked:** 5 applicable lang-review/SOUL rules have direct coverage; encoding pin inherited from the 155-40 sibling suite
**Self-check:** 0 vacuous assertions found (every assert pins a value or a concrete absence; no `let _`-equivalents, no always-true gets; conditional-arm audit per 155-30 done — `_assert_abort_invariants` asserts run unconditionally)

**Handoff:** To Dev (The White Rabbit) for GREEN — implement the no-PR verification per the designed interface; the 4 REDs plus 379 green family tests define done.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — story suite 7/7, family 383/383, ruff clean, no debug code, tree clean, branch pushed |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly: option-like/ghost/range-poison probes (all fail closed to abort), squash-merge world probed (reads unmerged, safe direction), human-mode and dry-run arms traced |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly: zero new except blocks beyond one typed int-parse guard that returns unknown into the loud abort; no new swallows; sentinel skip is affirmative by design |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered directly via mutation reasoning: state-comparison and sentinel-arm mutations killed by the suite; three surviving defensive-path mutations recorded as a test-polish Delivery Finding |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered directly: gate comment, helper docstrings (incl. the origin-preference claim), and module header verified against behavior |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — domain covered directly: all new helpers fully annotated; merge_state dict keys verified used only in arms where they are set; stringly state matches module result-dict idiom |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 2 (both downgraded LOW, deferred with routing), dismissed 0, deferred 2; one Challenged note — the "previously-unreachable path" claim on finding 2 is wrong in emphasis (line 1045 pre-existing on every finish); its `--` fix suggestion empirically breaks --verify (probed rc=1) — refs-prefix is the correct follow-up shape |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — domain covered directly: no dead code, no over-abstraction; the duplicated load_repos_config lookup already disclosed by Dev as an Improvement finding |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — 13-check sweep done personally (see Rule Compliance); two confirmed-LOW rule-matching findings, rest compliant |

**All received:** Yes (2 returned, 7 disabled with domains covered directly)
**Total findings:** 6 confirmed (2 security-LOW deferred, 1 test-polish MEDIUM deferred, 1 squash-merge Question, 2 disclosed-by-Dev drift/duplication), 0 dismissed, 0 blocking

## Reviewer Assessment

**Verdict:** APPROVED

**Binding evidence (classifier-safe, commit-order form, 4th consecutive use):** test commit 4b1c25ead precedes impl commit f4c245bd2 (`git log origin/develop..HEAD`); RED was verified at the test commit by direct scoped run (4 failed on the exact false-done assert, 0 errored, right-reason grep 4/4) — the source at that run was byte-identical to develop, so the recorded RED/green split is the inverse-probe result. Post-impl: 7/7 story, 383/383 family, preflight-confirmed.

**Data flow traced:** session `Branch` field → anchored 155-40 parse (Story Details authority) → `_extract_branch` → `_branch_merge_state(project_root, branch)` → argv-list git probes through `_run` with explicit cwd (`story_finish.py:374-405`) → three-state classification → accept only on affirmatively-verified `merged` (:743) → abort result object with actionable error (:756-775). Safe because: argv lists (no shell), fails closed on every probe error (probed empirically), never joined into a Path, and the abort runs before archive/transition/merge — the 155-15 ordering extended.

**Pattern observed (good):** the gate composes with every shipped sibling guarantee rather than re-implementing — 155-1's accepted worlds preserved via sentinel + verified-merged arms (:743-751, :784-787), 155-15's no-stray-archive extended to the new aborts (asserted in `_assert_abort_invariants`), 155-40's authority semantics are what make the placeholder world reach the gate at all.

**Error handling:** all three unknown exits of `_branch_merge_state` (:377-405) carry a `reason` consumed only in the unknown arm (:763); result objects at every abort; the one caught exception (int parse) degrades to unknown → loud abort, never silent.

**Observations (tags per dispatch):**
- `[VERIFIED]` Gate placement pre-irreversible — `story_finish.py:724-800` inside Step 2's else arm; aborts return before archive (Step 1 at :802+), transitions, and any `gh pr merge`. Complies with 155-15 ordering + SOUL #10 (checked: result dicts, no raise).
- `[VERIFIED]` Rule #1 unknown≠merged — only `state == "merged"` accepts (:743); unmerged AND unknown abort. Probes: `rev-parse --verify --quiet --help` rc=1, `rev-list develop..--help` rc=128, ghost branch → all land in abort.
- `[VERIFIED]` Sentinel classification (:315-332) reuses `_extract_branch`'s own normalization; live smoke: `none` and backticked/annotated sentinels accepted, template placeholder and empty rejected. Complies with 155-33 sentinel semantics.
- `[SEC]` (confirmed, LOW, deferred) CWE-88-shaped unguarded candidate at :374-377 — fails closed today (two independent probe sets); correct hardening is refs-prefixing, NOT `--` (which breaks `--verify`, probed). Rule #11/#13 match — not dismissible, deferred with a named follow-up per the scoped-fix precedent.
- `[SEC]` (confirmed, LOW, deferred, Challenged) malformed repos.yaml raises through the no-throw boundary via :342 — class pre-existing at :1045 on EVERY finish (post-merge, worse strand); the new site narrows the window. Fold into 155-45's wrap-fragile-reads family.
- `[EDGE]` (self, N/A-disabled domain) squash-merge world reads unmerged (probed count=1) → abort, safe direction, recovery = record the PR; human-mode no-PR arm unaffected (no done transition); dry-run drift disclosed and deferred to 155-39.
- `[SILENT]` (self) no new swallows; `[TEST]` (self) three surviving defensive-path mutations → test-polish finding; `[DOC]` (self) comments match behavior; `[TYPE]` (self) annotations complete, per-arm key usage verified; `[SIMPLE]` (self) no dead code; `[RULE]` (self) 13-check sweep clean beyond the two confirmed-LOWs.

### Rule Compliance

| Check | Instances in diff | Result |
|-------|-------------------|--------|
| #1 silent swallowing | 1 new try/except (int parse :400-405); 3 unknown exits | compliant — all degrade to unknown → loud abort |
| #2 mutable defaults | 3 new function signatures | compliant — none |
| #3 annotations at boundaries | `_field_is_sentinel`, `_resolve_base_branch`, `_branch_merge_state` | compliant — full param/return annotations |
| #4 logging | module uses result objects, no logging | N/A per module idiom |
| #5 path handling | no new opens/reads; cwd=str(project_root) on every probe | compliant in diff (repos.py `open()` without encoding is pre-existing, out of diff) |
| #6 test quality | new suite + 8 fixture conversions | compliant — no vacuous asserts, patch-where-used consistent with family; three defensive paths unpinned (deferred polish) |
| #7 resource leaks | subprocess.run with capture_output | compliant |
| #8 unsafe deserialization / shell | all probes argv-list via `_run` | compliant — no shell=True, no eval |
| #9 async | none | N/A |
| #10 import hygiene | one local import with circular-dep rationale mirroring step-6 precedent | compliant |
| #11 boundary validation | branch value → git argv (3 sites) | one LOW gap (rev-parse candidates unguarded; fails closed; deferred with probed fix shape) |
| #12 dependencies | none touched | N/A |
| #13 fix-introduced regressions | gate scoped to auto-mode no-PR arm; human/dry-run/PR arms untouched; 383 family green | compliant — one LOW echo of #11 (validation parity with _git_cleanup's `--` guard), deferred |

### Devil's Advocate

Let me argue this code is broken. The strongest attack: the sentinel is an escape hatch. Any agent — or any sufficiently confused operator — can write `Branch: none` into a session whose branch carries three days of unmerged work, and finish will cheerfully mark it done. The gate does not verify the AFFIRMATION, only the absence of one. But follow the trust model: the session file is the coordination layer, writable by exactly the actors who could also hand-edit the sprint YAML status or merge the branch manually. The gate's mandate (the story title, the epic) is to kill SILENT false-dones — the glide path where nobody affirmed anything — not to defeat a deliberate false affirmation by a trusted writer. The 155-33 sentinel semantics predate this story; re-litigating them here would be scope invention. Second attack: stale remote-tracking refs. The probe prefers `origin/develop`, but that ref only moves on fetch — a laptop that hasn't fetched in a week could read a long-merged branch as unmerged and wedge the finish. True — and the failure direction is an actionable abort, never a false done; the operator fetches or records the PR. Third: the probe has no timeout — a pathologically wedged git object store could hang finish. Real, pre-existing across every `_run` call, owned by backlog 155-38. Fourth: a malformed repos.yaml now crashes the no-PR arm with a raw traceback — confirmed, but the identical crash already lives post-merge at :1045 where it strands a half-done ceremony; this diff strictly shrinks that blast radius. Fifth: squash-merges read as unmerged — probed, safe direction, recovery documented. I hunted for a path where the gate produces a FALSE DONE — the failure class this epic exists to kill — and found none: every uncertain world aborts. The residual risks are wedges, and wedges are truthful.

**Handoff:** To The Mad Hatter (SM) for finish — PR creation, merge, ceremony. Follow-up routing per Delivery Findings: refs-prefix hardening (new 1-pt), repos.yaml wrap → fold into 155-45, test-polish → fold into 155-42 or sibling, squash-merge doc note. File AFTER the code PR merges (id-collision rule).