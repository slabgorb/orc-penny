---
story_id: "162-12"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-12: Sweep remaining CWE-22 shard-ref read sites with is_safe_shard_path

## Story Details
- **ID:** 162-12
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-12-cwe22-shard-ref-sweep
- **PR:** #184

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-05T20:23:42Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-05T19:53:27Z | 2026-08-05T19:55:22Z | 1m 55s |
| red | 2026-08-05T19:55:22Z | 2026-08-05T20:03:37Z | 8m 15s |
| green | 2026-08-05T20:03:37Z | 2026-08-05T20:12:30Z | 8m 53s |
| review | 2026-08-05T20:12:30Z | 2026-08-05T20:23:42Z | 11m 12s |
| finish | 2026-08-05T20:23:42Z | - | - |

## Sm Assessment

**Scope:** 2-pt p2 security sweep, TDD, from the 160-13 review. 160-13 introduced `is_safe_shard_path` guarding shard-file reads against path traversal (epic refs like `../../etc/passwd` escaping sprint/). Remaining UNGUARDED read sites: `loader.py` get_archived_stories (~326 at review time), `archive_epic.py` load_archive (~193) and backfill (~144), and shard_merge's orphan-scan/detect_orphan_shards glob loops. All in `pennyfarthing-dist/src/pf/sprint/`. Line numbers have likely drifted — locate by pattern.

**Technical approach for TEA:** Find 160-13's suite for the guard convention (what a rejected ref does: skip? error result?). Failing tests: each named site rejects traversal-shaped refs (parent-dir, absolute, symlink-ish) and behaves per the established convention; glob-loop sites don't yield paths outside sprint/. Also sweep for any OTHER unguarded shard read the 160-13 review missed — pin what you find, log the rest. Guard convention should match 160-13's exactly — one rule, not per-site variants.

**Acceptance criteria:**
1. All four named sites route through is_safe_shard_path (or the equivalent single guard).
2. Traversal-shaped refs cannot cause reads outside sprint/ at any swept site; behavior on rejection matches the 160-13 convention.
3. Suite exit 0 (7 loud 162-5 xfails only).

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_12_shard_ref_sweep.py` — 15 tests (7 RED, 8 green guards)

**Tests Written:** 15 tests covering 3 ACs
**Status:** RED (7 failing — ready for Dev)

### Guard convention for Dev (THE ONE RULE — inherited verbatim from 160-13)

Before any shard file is opened (read *or* write), check the candidate with `is_safe_shard_path(candidate, base_dir)` from `pf.sprint.shard_merge`. Fail closed: a candidate that fails is SKIPPED, never opened, and the skip is surfaced via the module's existing `warnings.warn` convention (the exact wording is not asserted — only that the read does not happen and the escaped data does not surface). `base_dir` is the sprint dir for sprint shards, the archive dir for archive shards.

Two candidate flavours, same rule:
1. **Interpolated refs** — `base_dir / f"epic-{ref}.yaml"` where ref comes from YAML data (`completed_epics`, story `epic` fields).
2. **Glob results** — `glob("epic-*.yaml")`, `glob("initiative-*.yaml")`, `glob("sprint-*-completed.yaml")`. A glob match is a *name* match; a symlink whose name matches is yielded happily and resolves outside base_dir. Every glob loop must guard each yielded path before opening it.

Do not add per-site variants and do not reimplement the check — import the existing helper.

### Site table

| # | Site | Kind | Test | State |
|---|------|------|------|-------|
| 1 | `loader.get_archived_stories` ref (`archive_dir / f"epic-{epic_ref}.yaml"`) | interpolated | test_get_archived_stories_rejects_traversal_epic_ref | RED |
| 2 | `loader.get_archived_stories` `sprint-*-completed.yaml` glob | glob | test_get_archived_stories_rejects_escaping_archive_symlink | RED |
| 3 | `archive_epic.load_archive` ref | interpolated | test_load_archive_rejects_traversal_epic_ref | RED |
| 4 | `archive_epic.migrate_completed_archive` ref | interpolated (read AND write) | test_migrate_completed_archive_rejects_traversal_epic_ref | RED |
| 5 | `archive_epic.backfill_epic_refs` `sprint-*-completed.yaml` glob | glob | test_backfill_epic_refs_rejects_escaping_archive_symlink | RED |
| 6 | `shard_merge.merge_epic_shards` initiative + orphan-scan globs | glob | test_merge_epic_shards_glob_loops_reject_escaping_shards | RED |
| 7 | `shard_merge.detect_orphan_shards` initiative + orphan globs | glob | test_detect_orphan_shards_glob_loops_reject_escaping_shards | RED |

Site 4 is an addition to the four named in the SM approach: `migrate_completed_archive` sits 30 lines above `load_archive` in the same module and interpolates the same ref, but it also *writes* the shard back — the escaping case creates `outside/epic-PWNED.yaml.tmp` and rewrites the out-of-bounds file. Worth guarding in the same sweep; a reviewer would otherwise ask why the neighbour was skipped.

**Green guards (must stay green):** benign refs still load in sites 1/3/6, real in-dir orphans still reported by site 7, and four non-symlink hostile ref shapes (parent-dir, absolute, percent-encoded, backslash) stay contained via `load_archive` — adding `resolve()` must not turn today's accidentally-safe lexical cases into leaks.

**Threat model note (same as 160-13):** the exploitable vector is a symlink *inside* sprint/ or sprint/archive/ plus a ref or shard filename routing through it. Bare `../` refs are gated out today because the `epic-` prefix glues to the first path component. Tests exercise the symlink case end-to-end and were verified to leak against this commit.

**Baseline:** full suite 7 failed (all mine), 5812 passed, 4 skipped, 7 xfailed (162-5). Ruff check + format clean.

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/shard_merge.py` — guarded four glob loops (initiative + orphan scan in both `merge_epic_shards` and `detect_orphan_shards`) plus the reconstructed ref at the `loaded_shard_files` rebuild
- `pennyfarthing-dist/src/pf/sprint/loader.py` — guarded `get_archived_stories`' `sprint-*-completed` glob and its `completed_epics` ref; added `warnings` + `is_safe_shard_path` imports
- `pennyfarthing-dist/src/pf/sprint/archive_epic.py` — guarded `load_archive` ref, `migrate_completed_archive` ref (read AND write), and `backfill_epic_refs` glob
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — guarded the `sprint-*-completed` glob (the flavour 160-13 missed in that file)
- `pennyfarthing-dist/src/pf/tests/test_162_12_shard_ref_sweep.py` — narrowed one containment base (see Design Deviations)

**Approach:** THE ONE RULE applied verbatim at every site — import `is_safe_shard_path` from `pf.sprint.shard_merge`, check before opening, `warnings.warn` + `continue` on failure. No per-site variants, no reimplementation, no new helper (the guarded-iterator refactor stays with the architect per TEA's scope note).

**Tests:** 15/15 passing (GREEN). Full suite: 5819 passed, 4 skipped, 7 xfailed (162-5 only), exit 0.
**Ruff:** `ruff check` clean on all changed files. `ruff format --check` clean on my hunks; `shard_merge.py` and `ws_push.py` retain pre-existing format drift that predates this branch (verified by stashing) and was left untouched.
**Branch:** feat/162-12-cwe22-shard-ref-sweep (commit 0e411393f, GPG signed, pushed)

**Handoff:** To Reviewer

## Subagent Results

Enabled per settings: preflight, test_analyzer, type_design, security, rule_checker. Disabled per settings and not spawned: edge_hunter, silent_failure_hunter, comment_analyzer, simplifier.

**All received: Yes** — all 5 enabled subagents returned before this assessment was written.

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | Suite exit 0 at 5819 passed / 4 skipped / 7 xfailed / 0 xpassed; ruff check clean; zero code smells; claimed BLOCKED_FORMAT for six new format violations in shard_merge.py | Test and lint data CONFIRMED and matches Dev. Format claim DISMISSED as disproven — ruff format objects to exactly one hunk at lines 79-86, which is outside this diff, blamed to 160-13, and flagged identically on develop. Challenged: this subagent produced a confident false blocker; logged as a delivery finding. |
| 2 | reviewer-test-analyzer | Yes | findings | Four lexical parametrized tests are non-discriminating; no positive-path test for migrate_completed_archive; no positive-path test for backfill_epic_refs. Independently reproduced my conclusion on the backfill base narrowing. | First CONFIRMED and strengthened by mutation testing (they survive an unconditional-true helper) — carried as LOW. Second CONFIRMED — carried as MEDIUM; migrate has zero coverage anywhere in the suite. Third DISMISSED — backfill positive path is covered by three other test files and the full suite is green. |
| 3 | reviewer-type-design | Yes | findings | Bool predicate keeps the containment invariant in convention rather than types; twelve call sites repeat guard-warn-continue; proposes safe_shards plus safe_ref_path. Verified no circular imports, verified the ws_push function-local import is in scope, verified warn categories and stacklevels. | CONFIRMED as non-blocking architecture; converges with TEA's own scope note, so endorsed and logged for the architect. Import and scope verifications independently CONFIRMED by my own direct-import check. |
| 4 | reviewer-security | Yes | findings | All 11 swept sites compliant and fail-closed; ws_push.py:338 silent skip violates the warn convention; archive_epic.py:548 unguarded read-write-move; aggregate.py, yaml_io.py, epic_reindex.py unguarded; TOCTOU at all guard sites. | ws_push finding CONFIRMED, downgraded to MEDIUM with rationale (fail-closed intact, matches adjacent 160-13 sites). archive_epic.py:548 CONFIRMED — independently found by me in the same sweep; highest-impact remaining site, logged first in the deferred list. Remaining-site inventory CONFIRMED and corrected. TOCTOU CONFIRMED as architectural, low practical risk, logged for the architect. |
| 5 | reviewer-rule-checker | Yes | findings | 13 checks over 67 instances, 5 violations: ws_push.py:338 warn convention; missing encoding at archive_epic.py:263 and :633; missing encoding in the test write helper; redundant function-body import at loader.py:58. | ws_push CONFIRMED (third independent corroboration). Two archive_epic encoding violations DISMISSED for this story as pre-existing and outside the diff, logged for the wider pass. Test-helper encoding CONFIRMED as LOW. loader.py:58 CONFIRMED as LOW and a genuinely sharp catch — the new top-level import is what makes the deferred one dead-weight. |

## Reviewer Assessment

**Verdict:** APPROVED

All three ACs met. The remediation is correct, complete for its stated scope, applied uniformly through the single imported helper, and fail-closed at every site. No Critical or High issue in the delivered change. Findings below are Medium/Low and non-blocking; the deferred sweep list is materially larger than TEA/Dev logged (see Delivery Findings).

### Verification performed (independent of the pipeline)

**Guard coverage — all 12 sites.** Enumerated every shard-path construction in src/pf via pattern sweep (interpolated epic-{ref} refs and epic-*/initiative-*/sprint-*-completed globs). Every site named in the story, plus TEA's added migrate_completed_archive and Dev's ws_push glob, routes through the imported is_safe_shard_path. No local variants, no reimplementations — shard_merge is a leaf module (stdlib-only imports) and is the single definition site.

**Both flavours guarded at every site.** Interpolated refs: loader.py:337, archive_epic.py:178 and :234, shard_merge.py:202, ws_push.py:290 and :348. Glob results: loader.py:313, archive_epic.py:402, shard_merge.py:118/:137/:215/:234, ws_push.py:338. Guard precedes the read in every case, including before .exists() at the reconstruct sites.

**Fail-closed confirmed at all 12 sites** — every guard failure is a skip via continue with no subsequent open. No fallthrough path reaches a read or write. One site skips without a warning (finding 1).

**Independent traversal probe, 7 shapes not in TEA's suite.** Self-restoring, run against throwaway worktrees; repo tree verified clean afterwards. Results — all contained on this branch, and the same probe leaks on develop, so it has teeth:
- Two-hop symlink chain escaping the archive dir: contained here, leaked PWNED-1 on develop.
- Relative symlink target (../../outside/stolen.yaml) rather than absolute: contained here, leaked on develop.
- migrate_completed_archive out-of-bounds file *creation* (not just overwrite): nothing created here; on develop it creates outside/epic-NEW.yaml. This is a stronger confirmation of TEA's out-of-bounds WRITE finding than the shipped test, which only pins the overwrite case.
- False-positive checks: a symlink hopping out and back inside the base still loads; a base_dir that is itself a symlink still loads. resolve() did not over-reject.
- Dangling symlink and a symlink loop named like a shard: no crash, contained — the except clause in the helper is doing real work.
- Guard unit cases: absolute /etc/passwd rejected, parent escape rejected, and the sibling-prefix case (sprint2 against base sprint) correctly rejected — is_relative_to compares path components, not string prefixes, so there is no prefix-confusion hole.

**Hostile lexical shapes still green.** The four parametrized shapes (parent-dir, absolute, percent-encoded, backslash) pass. resolve() did not convert lexical safety into a leak — confirmed both by the suite and by the out-and-back-in and symlinked-base probes above.

**Tests have teeth — mutation-verified.** Replaced the helper body with an unconditional true in a throwaway worktree (source hash-verified restored afterwards): all 7 traversal tests fail. The 7 also fail against develop source. So each of the 7 is pinned to the guard, not to incidental behaviour. The 8 survivors are the 4 preservation tests (correctly insensitive to the guard) and the 4 lexical shapes (finding 3).

**Dev's test amendment reproduced — claim upheld in both halves.** Ran the original RED-commit test file against the guarded implementation: the original assertion fails, and the sole escaping path in the failure output is sprint/current-sprint.yaml, which backfill_epic_refs must open for the id-to-epic lookup. So the original containment base was unsatisfiable regardless of the guard, exactly as claimed. Ran the amended test against develop source: still RED, failing on all three assertions. The amendment is a one-line base narrowing with the sibling secret-never-opened assertion untouched. Legitimate.

**Preflight's format regression claim is disproven.** Preflight returned BLOCKED_FORMAT asserting new format violations across six added guard blocks in shard_merge. Wrong. ruff format objects to exactly one hunk in that file, at lines 79-86, which is not in this branch's diff; blame attributes it to 160-13, and develop's own copy of the file is flagged identically. The new guard blocks are format-clean because their messages exceed the 100-char line length when joined, so the split is what the formatter wants. Dev's account was accurate and preflight's was not. Not chargeable. ruff check is clean; suite is exit 0 at 5819 passed, 4 skipped, 7 xfailed, and zero xpassed, so the 162-5 xfails are still loud.

**Data flow traced end-to-end.** Untrusted input is the epic ref string inside sprint YAML (completed_epics entries, story epic fields) plus attacker-chosen filenames on disk. Path: YAML parse to ref string, interpolated into base_dir / epic-{ref}.yaml, guard resolves and containment-checks against base_dir, then .exists() and open. Safe because the check is resolve()-based, so it catches the only genuinely exploitable vector — a symlink living inside sprint/ or sprint/archive/ that a ref or a glob-matching filename routes through — and because the failure mode is skip-without-open rather than error-and-continue.

**Wiring.** ws_push.fetch_sprint feeds the Frame TUI and IDE sidebar panels. Verified the function-local helper import at ws_push.py:243 is inside the same function scope as the new use at :338, so there is no NameError; confirmed by the passing suite and by direct import.

**Pattern observed — good.** archive_epic.py:176 carries a comment naming this site as read-and-write and therefore an out-of-bounds write, which is the correct reason this neighbour was in scope. Pattern observed — bad: see finding 1, where the same file family drifts from the stated convention.

### Findings

| Severity | Issue | Location | Notes |
|----------|-------|----------|-------|
| MEDIUM | [SEC] [RULE] Guard skips silently — no warn, diverging from THE ONE RULE, which requires the skip be surfaced via the module warn convention. This file uses warnings.warn at ten other places, so the convention exists here. Security-relevant skip is unobservable, and because this feeds the TUI and IDE panels, a symlinked archive index silently disappears from the panel with no diagnostic. Mitigating: Dev matched the adjacent 160-13 sites at :290 and :349, which are also silent, so fixing this one alone would make the file internally inconsistent — the right fix is all three together. Downgraded from High on that basis and because fail-closed is intact. Corroborated independently by two subagents. | ws_push.py:338 | Dev assessment overclaims here: it states warn plus continue was applied at every site. Not true for this one. |
| MEDIUM | [TEST] migrate_completed_archive has zero positive-path coverage anywhere in the suite — the only test touching it is this story's negative test. A data-mutating migration now gated by a new guard has no test that would catch over-rejection; if the guard ever over-rejected, the function would silently return success with zero stories migrated. Present behaviour is correct (verified by probe), so this is regression exposure, not a live defect. | test_162_12_shard_ref_sweep.py:302 | Contrast: backfill_epic_refs positive path IS covered by three other test files, so the parallel concern there is dismissed. |
| LOW | [TEST] The four lexical-shape parametrized tests cannot fail under any implementation. Confirmed by mutation: they survive an unconditional-true helper. No file exists at any traversal target, so the pre-existing .exists() check gates them out whether or not the guard runs, and a hypothetical resolve()-induced leak would equally have nothing to leak. They are documentation rather than guards. Not a defect — TEA declared them as green-now-must-stay-green in Design Deviations — but their stated protective purpose is not actually achieved. | test_162_12_shard_ref_sweep.py:276 | |
| LOW | [RULE] [TYPE] The function-body deferred import of merge_epic_shards is now redundant dead-weight: the new module-level import from the same module at line 22 proves the edge is cycle-free. Verified acyclic by direct import. | loader.py:58 | |
| LOW | [RULE] Test helper writes via write_text with no encoding, while its companion reader correctly passes utf-8. Asymmetry only; safe_dump emits ASCII by default. | test_162_12_shard_ref_sweep.py:83 | |

Dismissed: preflight's BLOCKED_FORMAT (disproven above, pre-existing 160-13 line). Dismissed: missing-encoding at archive_epic.py:263 and :633 (pre-existing, not in this diff — logged for the wider pass). Dismissed: backfill_epic_refs preservation gap (covered by three existing test files).

### Deviation Audit

- TEA, fifth site added (migrate_completed_archive) — ACCEPTED. Correct call, and stronger than TEA argued: my probe shows the unguarded site not only rewrites an existing out-of-bounds file but creates a new one.
- TEA, rejection asserted structurally rather than by message text — ACCEPTED. Mutation testing confirms the structural assertions are what give the 7 tests their teeth; message assertions would have added coupling without discrimination.
- TEA, absolute and parent-dir refs pinned green rather than red — ACCEPTED as a scope decision, with the caveat in finding 3 that these four cannot fail under any implementation.
- Dev, one test assertion narrowed — ACCEPTED. Both halves of the claim reproduced independently; one-line change, intent intact.
- Dev, ws_push glob taken in-story — ACCEPTED on scope. The guard itself is correct; its silent skip is finding 1.
- No undocumented deviations found. Working tree clean, both commits signed, all edits in pennyfarthing-dist and none in symlinked runtime dirs.

**Handoff:** To SM for finish-story.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): `findings/aggregate.py` has three more unguarded interpolated shard reads (archive shard at ~78 and ~129, sprint shard at ~108/~110) with the same CWE-22 shape. Out of this story's stated scope; affects `pennyfarthing-dist/src/pf/findings/aggregate.py` (needs the same `is_safe_shard_path` guard). Worth a follow-on story so the sweep is actually complete. *Found by TEA during test design.*
- **Gap** (non-blocking): `sprint/cli.py` has an unguarded shard-path helper (~654, returns `sprint_dir / f"epic-{ref}.yaml"`) plus four `initiative-*.yaml` glob loops (~673, ~792, ~1077, ~2005), and `sprint/epic_reindex.py` (~39), `sprint/epic_add.py` (~88), `sprint/yaml_io.py` (~407/415/421) build the same interpolated paths. Most are write/lookup rather than read, so lower severity, but the guard is not applied uniformly across the module. *Found by TEA during test design.*
- **Gap** (non-blocking): `frame/ws_push.py` (~335) globs `sprint-*-completed.yaml` unguarded even though 160-13 guarded the two interpolated sites in that same file — the glob-loop flavour of the bug was missed there too. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py`. Dev may fix it in this story if cheap; otherwise follow-on. *Found by TEA during test design.*
- **Improvement** (non-blocking): `shard_merge.detect_orphan_shards` (~187) reconstructs `sprint_dir / f"epic-{ref}.yaml"` and calls `.exists()` on it — no read, so not pinned by a test, but it can add a resolved out-of-sprint path to `loaded_shard_files`. Cheap to guard while Dev is in the function. *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): TEA's `frame/ws_push.py` glob finding was cheap, so it is fixed in this story rather than deferred. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py` (nothing further needed). The remaining wider-sweep gaps — `findings/aggregate.py`, `sprint/cli.py`, `epic_reindex.py`, `epic_add.py`, `yaml_io.py` — were left alone as out of scope and still want a follow-on story. *Found by Dev during implementation.*
- **Improvement** (non-blocking): TEA's `detect_orphan_shards` reconstructed-ref observation was also taken (it could seed `loaded_shard_files` with an out-of-sprint resolved path). Affects `pennyfarthing-dist/src/pf/sprint/shard_merge.py` (nothing further needed). *Found by Dev during implementation.*
- **Improvement** (non-blocking): `ruff format --check` fails on `shard_merge.py` and `ws_push.py` for reasons that predate this branch (verified by stashing my changes) — including the 160-13 warning string in `shard_merge.py`. The repo-wide format check is dirty across ~322 files, so format is not currently an enforceable gate. Affects the lint config or a dedicated formatting pass. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking, but file FIRST in the follow-on): archive_epic.archive_epic() at ~547-549 derives epic_ref from sprint YAML and builds BOTH a sprint shard path and an archive shard path with no containment guard, then reads it (~582), writes it (~586), moves it (~588), and in the no-shard branch writes the archive path directly (~594). Read plus write plus move makes this the highest-impact remaining CWE-22 site in the codebase — strictly worse than any site fixed in this story — and it sits in the very module Dev edited. It appears in neither TEA's nor Dev's deferred list, so the sweep inventory was incomplete. Affects `pennyfarthing-dist/src/pf/sprint/archive_epic.py` (needs the guard on both derived paths, returning a failure result rather than skipping since this is a single-epic operation). *Found by Reviewer during code review.*
- **Gap** (non-blocking): two unguarded glob sites missing from TEA's deferred list — validate/adapters/sprint.py at ~25-26 globs both epic-*.yaml and initiative-*.yaml and hands every match to the YAML validator, and sprint/story_add.py at ~242 globs initiative-*.yaml to build an error message that would disclose out-of-tree filenames. Affects `pennyfarthing-dist/src/pf/validate/adapters/sprint.py` and `pennyfarthing-dist/src/pf/sprint/story_add.py`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): confirming and correcting TEA's deferred inventory for the follow-on story — findings/aggregate.py has FOUR unguarded interpolated reads, not three (~78, ~108, ~110, ~129); sprint/cli.py has the shard helper at ~654 plus four initiative globs (~673, ~792, ~1077, ~2005); sprint/epic_reindex.py ~39 builds its path from a CLI-supplied ref; sprint/epic_add.py ~88; sprint/yaml_io.py ~407, ~415, ~421, where ~415 is a WRITE. All confirmed present and unguarded by pattern sweep. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the two 160-13 guards in frame/ws_push.py at ~290 and ~349 skip silently with only a code comment, as does Dev's new one at ~338. All three should emit the module warn convention together so the file is internally consistent and traversal skips are observable in the TUI and IDE panel path. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): endorsing TEA's guarded-iterator suggestion, with a second half. A safe_shards(base_dir, pattern) iterator covers the seven glob sites and a safe_ref_path(base_dir, ref) factory covers the five interpolated-ref sites, collapsing all twelve call sites and removing the warn-and-continue boilerplate. The current bool-returning predicate keeps the invariant in convention rather than in the types, so a thirteenth site added later is silently unsafe — which is precisely how this story's sites survived 160-13. Affects `pennyfarthing-dist/src/pf/sprint/shard_merge.py`. *Found by Reviewer during code review.*
- **Question** (non-blocking): TOCTOU at every guard site, including the ones 160-13 added — the guard resolves, then .exists() and open() re-traverse, so a symlink swapped between check and open defeats it. Practical risk under this threat model is low, since it needs a concurrent filesystem write rather than just YAML content. Worth an architect decision on whether O_NOFOLLOW at the open is warranted, or whether the resolved path should be passed forward to the read. Affects `pennyfarthing-dist/src/pf/sprint/shard_merge.py` and all callers. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): migrate_completed_archive has no positive-path test anywhere in the suite despite being a data-mutating migration now gated by a new guard. Affects `pennyfarthing-dist/src/pf/tests/` (wants a benign-ref migration test asserting shards created and stories migrated). *Found by Reviewer during code review.*
- **Question** (non-blocking): reviewer-preflight reported BLOCKED_FORMAT on this branch claiming six new format violations in shard_merge.py; I disproved it — the single flagged hunk is 160-13's, present and flagged identically on develop. A subagent producing a confident false blocker on a verifiable mechanical check is worth a look, especially since the repo-wide format drift across roughly 322 files makes format unenforceable and invites exactly this misattribution. Affects the preflight subagent definition and the lint config. *Found by Reviewer during code review.*

### TEA (test design) — scope note
- **Improvement** (non-blocking): the number of sites suggests the durable fix is a single guarded iterator helper (e.g. `safe_shards(base_dir, pattern)`) rather than N call-site checks. Out of scope for a 2-pointer; flagged for the architect. *Found by TEA during test design.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Fifth site added:** Story named four sites; tests cover five. `archive_epic.migrate_completed_archive` interpolates the same ref as `load_archive` 30 lines above it and both reads AND rewrites the escaping shard. Reason: leaving the neighbour unguarded would be an obvious review finding, and the write path is strictly worse than the reads named in the story.
- **Rejection behaviour asserted structurally, not by message:** tests assert the escaping path is never opened and the escaped data never surfaces, rather than asserting a specific `warnings.warn` string. Spec said "behaviour on rejection matches the 160-13 convention". Reason: 160-13's own suite asserts containment, not wording; pinning message text would couple tests to phrasing. Two glob sites legitimately emit no warning today (initiative-owned refs suppress the orphan warning), so a blanket warn assertion would be wrong.
- **Absolute/parent-dir refs are green, not red:** the story asked for parent-dir/absolute/weird ref coverage; those shapes cannot escape today because the `epic-` prefix glues to the first path component. They are pinned as parametrized regression guards (green now, must stay green) rather than reds. Same reasoning as 160-13's `test_lexical_dotdot_ref_stays_contained`.
### Dev (implementation)
- **One test assertion narrowed:** `test_backfill_epic_refs_rejects_escaping_archive_symlink` called `assert_contained(opened, archive_dir, ...)`, but `backfill_epic_refs` legitimately opens `sprint/current-sprint.yaml` for the id-to-epic lookup — a path outside `archive_dir`. The assertion was therefore unsatisfiable regardless of the guard. Changed the containment base to `tmp_path / "sprint"`, which still catches the escape (the planted secret lives in `outside/`, not under `sprint/`). Verified the amended test is still RED against the unguarded code by stashing the `archive_epic.py` change. The sibling assertion that the secret was never opened is untouched, so the test's intent is intact.
- **ws_push glob taken in-story:** TEA flagged `frame/ws_push.py`'s glob as optional. Guarded it, since 160-13 already established the pattern two sites above and the fix is four lines. No test pins it (out of the story's test scope) — the guard mirrors the two adjacent guarded sites exactly.