---
story_id: "162-33"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-33: Multi-repo session schema + finish edge-cases: document per-repo PR-field syntax in schemas/session-schema.md + agents/sm-setup.md (single PR line is single-repo-only since 162-6); move no-PR repo verification OUT of the merge loop (mixed multi-repo can land one PR then refuse); test + name-the-landed-repo recovery for second-merge-fails-after-first-landed; fix dry-run pairing first resolved PR with first repo (the 162-6 bug class in the preview path); reconcile the docstring's degradation claim for stories omitting repos: and decide epic-level repos: inheritance (from 162-6 review M3-M6)

## Story Details
- **ID:** 162-33
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-33-multi-repo-session-schema-finish-edgecases
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the title is the full spec (162-6 review M3-M6). SIX deliverables — docs, code, and one design decision. Code in `pennyfarthing-dist/src/pf/sprint/story_finish.py`; docs in `pennyfarthing-dist/schemas/session-schema.md` and `pennyfarthing-dist/agents/sm-setup.md`.

1. **Document per-repo PR-field syntax** (M3): since 162-6, a single `**PR:**` session line is single-repo-only. Document the per-repo PR-field syntax in `schemas/session-schema.md` AND `agents/sm-setup.md` so multi-repo sessions record a PR per repo.
2. **Move no-PR repo verification OUT of the merge loop** (M4): a mixed multi-repo story can currently land ONE PR then refuse (verification interleaved with merges → partial landing + false abort). Hoist all no-PR/verification checks BEFORE the merge loop so it's all-or-nothing (verify every repo first, then merge).
3. **Landed-repo recovery** (M5): when the second merge fails AFTER the first already landed, the result must NAME the landed repo(s) so recovery is possible (don't report a blanket failure that hides what already merged). Add a test pinning second-merge-fails-after-first-landed → result names the landed repo.
4. **Fix dry-run PR/repo pairing** (M6): the dry-run PREVIEW path pairs the first resolved PR with the first repo positionally — the same 162-6 bug class. Fix the preview to pair each repo with ITS own PR. Test it.
5. **Reconcile the docstring's degradation claim** for stories omitting `repos:` — make the docstring match actual behavior.
6. **Decide epic-level `repos:` inheritance** — should a story with no `repos:` inherit its epic's `repos:`? DEV DECISION (with rationale in the session + docstring/schema); Reviewer scrutinizes. If it turns out to be a genuine product/schema-breaking call, flag it to SM rather than guessing.

**TEA (RED):** failing tests (fake `_run`/subprocess seam, explicit roots):
- (2/3) multi-repo finish where repo A has a mergeable PR and repo B has none → today it can merge A then refuse; after fix, verification happens first so NOTHING merges (all-or-nothing), OR if a second merge fails after the first landed, the result NAMES the landed repo. Pin both the pre-merge-verification ordering and the landed-repo recovery message.
- (4) dry-run preview with two repos+two PRs asserts each repo is paired with its OWN PR (not first-PR-to-first-repo).
- (1/5) doc/docstring deliverables: a test asserting the schema/sm-setup doc documents per-repo PR syntax is optional; at minimum pin the docstring degradation claim matches behavior.

**Constraints (binding):** scoped runs — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/<finish tests>.py -q` + finish regression batch. NEVER full suite. `_run` seam; result objects, not throws. `ruff check`. Preserve 162-4/162-6/162-9/162-32 invariants (162-32 just landed dedup + existence guard + rc propagation in this same function — rebase-aware: your branch is off current develop which INCLUDES 162-32).

## TEA Assessment

**Tests Required:** Yes
**Reason:** n/a

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_33_multi_repo_finish.py` — multi-repo finish edge cases (M4/M5/M6 + docstring reconcile + doc presence)

**Tests Written:** 9 tests (7 RED, 2 green-on-arrival over-reach guards) covering deliverables 1, 2, 3, 4, 5.
**Status:** RED — commit `27019b783`, signed.

Seam: `pf.sprint.story_finish._run` faked and dispatched on the arriving `cwd`
(gh answered from that repo's world; `git` passes through to real fixture
repos). Explicit roots; no reliance on the runner's cwd. Result objects only.

**RED — exact failing reason (each is the defect, not a fixture error):**

| Test | Failing output (one line) |
|------|---------------------------|
| `TestPreMergeVerificationPrecedesEveryMerge::test_unverifiable_repo_blocks_all_merges` | `repo 'ui' cannot be verified, so this story is not finishable — yet finish irreversibly merged another repo's PR first: [(['gh','pr','merge','11','--squash','--delete-branch'], '…/orc/api')]` |
| `TestLandedRepoRecovery::test_second_merge_failure_names_the_landed_repo` | `assert 'api' in 'False 162-33 None PR #22 merge failed: GraphQL: Changes must be approved (mergePullRequest) — refusing to mark the story done with unmerged code'` |
| `TestDryRunPairsEachRepoWithItsOwnPr::test_both_repos_prs_are_previewed` | `the preview dropped ui's PR …: only "{'step': 2, 'action': 'Merge PR #11 (squash, delete branch)'}"` |
| `TestDryRunPairsEachRepoWithItsOwnPr::test_pr_number_is_never_probed_in_another_repo` | `the dry-run preview asked about a PR number in a repo that does not own it: [(['gh','pr','view','22',…], '…/orc/api')]` |
| `TestDegradationDocstringMatchesBehavior::test_partial_typo_claim_is_honest` | `a partial typo IS silently dropped ('api, tpyo' resolves only 'api'), so the docstring's claim … is false` |
| `TestPerRepoPrFieldIsDocumented::test_doc_mentions_per_repo_pr[schemas/session-schema.md]` | `schemas/session-schema.md does not document the per-repo PR field syntax` |
| `TestPerRepoPrFieldIsDocumented::test_doc_mentions_per_repo_pr[agents/sm-setup.md]` | `agents/sm-setup.md does not document the per-repo PR field syntax` |

**Green-on-arrival guards (must NOT be traded away):**
- `test_all_repos_verifiable_still_merges_every_pr` — hoisting verification must still merge BOTH PRs and go done.
- `test_story_without_repos_degrades_to_project_root` — degradation to `(project_root, root_config)` survives the docstring reconcile.

**Notes for Dev**
- Deliverable 6 (epic-level `repos:` inheritance) is deliberately UNPINNED — the decision plus rationale is yours.
- Deliverable 5 accepts either direction: reconcile the docstring, or make an unknown `repos:` name loud (then the test asserts the error names `tpyo`).
- The doc presence check is a loose regex (`pr … per-repo` within 80 chars, either order) — prose is yours.
- Regression baseline confirmed green before the commit: `test_162_6_finish_repo_context.py`, `test_164_9_finish_dry_run_preview_polish.py`, `test_155_31_finish_dry_run_merged_preview.py`, `test_155_34_finish_no_pr_unmerged_branch.py` → 37 passed.

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — new `_verify_no_pr_repo` (the 155-34 no-PR gate for ONE repo, pure/read-only) + `_repo_label`; the hoisted pre-merge pass now verifies EVERY repo (PR-conflict gate *and* no-PR/branch verification) before the merge loop, which only replays the recorded verdicts; `landed_repos` + a half-landed warning on all four merge-loop failure returns; the dry-run preview loops `repo_prs` and pairs each repo with its OWN PR; positional `pr_number`/`primary_repo_path` deleted; overclaiming 162-6 comment corrected; `_resolve_story_repos` docstring reconciled + inheritance decision pinned.
- `pennyfarthing-dist/schemas/session-schema.md` — new "Story Details Fields: `**Branch:**` and `**PR:**`" section: per-repo `**PR {repo}:**` syntax (parser-compatible bare-word key), what finish reads today, and "`repos:` is per story, never inherited" with the partial-typo caveat.
- `pennyfarthing-dist/agents/sm-setup.md` — Step 5: record a PR per repo for multi-repo stories; `repos:` is per story, never inherited.

**Per deliverable:**
1. M3 docs (per-repo PR syntax) — done in both files; syntax chosen to match the anchored session-field parser (`**PR api:**`, not `**PR (api):**`).
2. M4 verification hoisted — all-or-nothing: an unverifiable repo now merges NOTHING.
3. M5 landed-repo recovery — result carries `landed_repos` and the error names them; the rc!=0 / not-MERGED errors also name the repo, not just the PR number.
4. M6 dry-run pairing — one step-2 entry per repo, each probed in its own repo; no PR number is ever probed in a repo that does not own it.
5. Deliverable 5 — docstring reconciled (claim removed, actual partial-typo behavior stated); behavior unchanged, logged as a Delivery Finding.
6. Deliverable 6 — **NO epic-level inheritance** (rationale in Design Deviations); documented in docstring + schema + sm-setup.

**Tests:** 9/9 passing in `src/pf/tests/test_162_33_multi_repo_finish.py` (7 RED → GREEN, 2 over-reach guards still green).
**Regression:** finish batch (`git grep -l "story_finish\|_git_cleanup\|_resolve_story_repos" src/pf/tests/`, 50 files) → **975 passed**. `ruff check` + `ruff format --check` clean; `pf validate agent` 38 passed (2 pre-existing warnings, neither in sm-setup).

**Branch:** `feat/162-33-multi-repo-session-schema-finish-edgecases` (pushed) — commit `9029edd11`, signed.

**Handoff:** To Reviewer

### Fix Round 1 (post-review)

| Finding | Addressed | How | Covering test |
|---|---|---|---|
| [MEDIUM] M1 — per-repo PR key unparseable for hyphenated repo names | Yes | **Regex extension** (not doc-only): `SESSION_FIELD_RE` key class `\w[\w\s]*` → `\w[\w\s-]*` in `session_parse.py`, and the hook's byte-identical mirror `_FIELD_LINE_RE` in `hooks/schema_validation.py` (pinned equal by `test_162_11`'s drift test). Docs in both files now state the key is the `repos.yaml` name **verbatim, hyphens included**, and drop the "bare words only" claim. Chosen over prescribing `_`-mangled keys: the mangled form would make the documented key stop matching the repo's real name, which is a second trap for the reader *and* for finish when it starts reading the field. | `TestPerRepoPrFieldIsParseable::test_hyphenated_repo_key_parses_to_its_own_field` — `- **PR my-repo:** #227` → `pr my-repo`, distinct from `pr` (asserts `"pr" not in fields`), `branch` still parses |
| [MEDIUM] M2 — overclaiming `_verify_no_pr_repo` comment | Yes | Comment rewritten: the record reaches the report whenever the **merge loop** runs (which replays the verdicts), and it now states outright that a pre-pass abort suppresses the earlier repos' records, the abort's own error naming the failing repo instead. No behavior change. | n/a (comment) |
| [LOW] L1 — `ruff format --check` failed on the test file | Yes | `uv run ruff format` on it. My earlier "clean" claim was wrong. | n/a |
| L2–L5 | No — deferred as the Reviewer scoped them | — | — |

**Re-run:** `uv run pytest <all session-parse/schema-hook/finish-adjacent suites> src/pf/tests/test_162_33_multi_repo_finish.py -q` → **387 passed** (story file 10 passed, up from 9). `ruff check` + `ruff format --check` pass on all four changed source files.

**Commit:** `22c7f1b50`, signed (`G`), pushed.

## Subagent Results

**All received: Yes** (5 of 5 enabled specialists returned before this verdict was written.)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | ruff check clean on both files; `ruff format --check` FAILS on the test file (one collapsible `str.join` at ~549); 9 passed (story) + 37 passed (162-6/155-34/164-9/155-31); `pf validate agent` 38 passed, 2 pre-existing warnings (tech-writer, tandem-backseat — neither in sm-setup); no type checker configured; no TODO/FIXME/debug prints/dead code; `_verify_no_pr_repo` 119 lines, `finish_story` 889 (pre-existing) | CONFIRMED (format) → finding L1. Rest corroborates my own runs (975-file finish batch also green). Function length noted, not a finding — the extraction reduced `finish_story`. |
| 2 | reviewer-rule-checker | Yes | findings | 7 rules / 12 instances / 1 violation: `_verify_no_pr_repo` returns `{success, step, error}` — payload key is `step`, not the contract's `data` (every other result-carrying fn in the file uses `data`: 648/672/684/710). All four changed files verified regular files in `pennyfarthing-dist/` (no symlink edits); no sprint-YAML edits; no new `raise` | CONFIRMED but downgraded → finding L4. The no-throw half of rule 6 is satisfied; the key name is an internal private-helper naming inconsistency, not a boundary contract break. Non-blocking. |
| 3 | reviewer-security | Yes | findings | Substantively CLEAN on the four asked questions: `_repo_label` output never reaches `_run` argv (f-strings and step dicts only); `repo_pr` is digits-only via `#(\d+)` / gh `--json number`; the 162-4 branch guards still fire before `_verify_no_pr_repo` (`_branch_merge_state` → `check-ref-format`); `(project_root / rc.path).resolve()` + `is_dir()` blocks traversal; a no-PR repo cannot be leveraged to authorize another repo's merge. Two Low CWE-209 nits: absolute `{repo_path}` in the dry-run and pre-merge gate-timeout strings, and `gate_timeout` gh stderr not passed through the file's existing `_scrub_credentials` | ACCEPTED as clean. Both nits DISMISSED as pre-existing — the old code already interpolated `primary_repo_path` and the identical unscrubbed `gate_timeout` string; the diff copies the pattern per repo rather than introducing it. Rolled into finding L5 as a consistency note. |
| 4 | reviewer-test-analyzer | Yes | findings | `landed_repos` asserted only via stringified-all-values substring, not `result["landed_repos"] == ["api"]`; only the rc!=0 arm covered (merge-timeout and post-merge-verify arms carry the note untested); already-merged-then-second-merge-fails shape untested; multi-repo human mode untested; `test_both_repos_prs_are_previewed` asserts substrings, not one step-2 entry per repo with the right `repo` key; doc-presence regex narrow | CONFIRMED → finding L2. Partially MITIGATED: the sibling `test_pr_number_is_never_probed_in_another_repo` pins the pairing rigorously on the probe-cwd side, which is the M6 defect's teeth, so the weak preview assertion is not a coverage hole. Human-mode gap is not a regression — human mode skipped this verification before the diff too. |
| 5 | reviewer-type-design | Yes | findings | `_verify_no_pr_repo` returns an untyped 3-key dict where the same file already has `_PRClassification` (NamedTuple, line 372) as precedent; the success/error pairing invariant is unencoded; `getattr(repo_config, "name", "")` duck-types a declared `RepoConfig \| None` whose `name: str` is a required dataclass field; raw `Path` dict keys rely on call-site discipline for canonicality | CONFIRMED → finding L4 (NamedTuple inconsistency + `getattr`). Path-key finding DISMISSED: `_resolve_story_repos` returns `.resolve()`d paths and both write and read sites draw `repo_path` from the same `repo_prs` list, so no aliasing is reachable. |

## Reviewer Assessment

**Verdict:** APPROVED (2 Medium + 5 Low, all non-blocking; no Critical/High)

All 5 specialists returned (table above). [SEC] clean, [RULE] one downgraded naming
inconsistency, [TEST] coverage gaps on the untested `landed_repos` arms plus a format
violation, [TYPE] untyped-dict/`getattr` nits against the file's own `_PRClassification`
precedent. Nothing any specialist raised rises to blocking; the two Medium findings are
mine (a doc syntax that cannot parse hyphenated repo names, and an overclaiming comment).

**Evidence run:** `test_162_33_multi_repo_finish.py` → 9 passed. Finish regression
(`git grep -l story_finish src/pf/tests/`, 50 files) → **975 passed**. `ruff check`
clean; `ruff format --check` NOT clean (finding L1).

**Per deliverable:**

| # | Deliverable | Soundness |
|---|---|---|
| M4 | pre-merge verification hoisted | **SOUND.** No `gh pr merge` is reachable before every repo is verified: the `pr_merge_mode != "human"` pass (1597) runs both the no-PR gate and the PR-conflict gate for EVERY repo and returns on first failure; the merge loop (1706) only replays. Test asserts *zero* merge argv AND that api's PR is still `OPEN`. `no_pr_steps[repo_path]` cannot KeyError — human mode `continue`s at 1725 before the replay, and `_resolve_story_repos` dedupes on resolved path so keys are unique. `== "auto"` → `!= "human"` is exactly the complement of the loop's `== "human"` arm; `get_pr_merge_mode` validates to `{auto, human}` and defaults `auto`, so it is behavior-identical today, and the pass is read-only — it can only add aborts, never merge. No accidental-merge mode. |
| M5 | landed-repo recovery | **SOUND.** All four merge-loop failure arms carry `landed_repos` + `_half_landed_note()` (1793, 1817, 1851, 1874). `landed_repos.append` happens only AFTER post-merge `MERGED` verification (1878), and the already-merged short-circuit correctly does NOT append (it did not land *this run*). Actionability verified at the surface: `cli.py:481` raises `ClickException(result["error"])` and never reads `landed_repos`, so appending the warning to `error` is what makes M5 reach the operator. Correct call. |
| M6 | dry-run pairing | **SOUND.** One step-2 entry per repo, each probed with `cwd=repo_path`. `pr_number`/`primary_repo_path` fully deleted — `grep` confirms zero references in `src/` or anywhere in `pennyfarthing-dist/`; `cli.py` reads only `success`/`error`/`dry_run`/`jira_key`/`steps[step|action|warning|error]`. Dev's "nothing downstream read them" **confirmed**. Bonus: the preview now passes the repo's own `default_branch`/`remote_name` where the old code passed `None`, so preview and real run finally make the same probe (155-31 parity improved, not regressed). |
| 5 | docstring reconcile | **SOUND and honest.** Verified the defect: `resolved = [configs[name] for name in names if name in configs]` (682) drops unknown names whenever ≥1 resolves. Scoping ruling below. |
| M3 | docs | **Caveat accurate**, one Medium gap. Verified `session_pr = pr_number if len(story_repos) == 1 else None` (1433) and per-repo resolution via `gh pr list --head <branch>` with `cwd=repo_path` — finish does resolve from the branch, not the session field. Also verified `- **PR api:** #227` parses to key `"pr api"`, distinct from `"pr"`, so it cannot be mistaken for the single-repo field, and `**PR (api):**` is indeed unparseable. See M1. |
| 6 | inheritance | **DECISION UPHELD.** See ruling below. |

**Ruling — silent typo drop (deliverable 5 scoping): scoping ACCEPTED, urgency REJECTED.**
Doc-only is within spec (the story offered either direction, TEA's test accepts
either, and the behavior is pre-existing — this diff introduces no regression), so
it is not grounds to block. But Dev filed it as *Improvement / non-blocking* and that
classification is wrong: `repos: "api, tpyo"` finishes the story **done** with tpyo's
PR never merged — silent success over unlanded work, the exact defect class epic
155/162 exists to kill. Dev's "changes the finish outcome of existing stories"
objection is weak because it only ever converts a wrong success into a *retryable
refusal* (session kept, nothing irreversible), which is the safe direction. Re-filed
as a **Gap, blocking-priority** for the next story in epic 162; the hard-abort
direction (`{"success": False}` naming the unknown name) is the correct eventual fix.

**Ruling — NO inheritance: SOUND, doc-only is the right disposition.**
The rationale holds on all three legs, and leg (2) is the strongest: inheritance
would hand an all-typo story a plausible-but-WRONG repo set, whereas degradation to
the root either verifies or aborts loudly. Since the decision is "today's behavior is
already correct," there is genuinely no code to write — the deliverable IS the
documentation, and it landed in all three places (docstring, schema, sm-setup).
Verified no code anywhere inherits epic-level `repos:` (`context/generate.py:53` is
also story-only), so the docs match behavior. One follow-up filed: `sprint/epic-163.yaml:7`
already carries an epic-level `repos: pennyfarthing` that is now documented as never
read — a dead-but-plausible field is a trap and wants a loud guard.

**Data flow traced:** story YAML `repos:` → `_resolve_story_repos` (per-name resolve,
dedupe on resolved path, existence guard) → `repo_prs` (per-repo `gh pr list --head`
in that repo's cwd) → hoisted verify-every-repo pass → merge loop → `landed_repos` →
`result["error"]` → `ClickException` at the operator. Safe because every irreversible
`gh pr merge` is downstream of a completed all-repo read-only verification pass.

**Findings**

| Severity | Issue | Location | Fix |
|----------|-------|----------|-----|
| [MEDIUM] M1 | The documented per-repo key `**PR <repo-name>:**` is **unparseable for hyphenated repo names**. `SESSION_FIELD_RE = ^\s*(?:[-*]\s+)?\*\*(\w[\w\s]*):\*\*` allows word chars and spaces only — verified: `- **PR my-repo:** #227` → NO MATCH. Both docs say "keyed by the repo's `repos.yaml` name" and explicitly justify the syntax *by* parser compatibility, yet neither notes the constraint; hyphenated repo names are the norm. Harmless today (finish does not read the field) but a forward-compat trap: when finish does read it, a hyphenated repo silently has no PR field and falls into the no-PR arm. | `schemas/session-schema.md` (per-repo PR lines section), `agents/sm-setup.md` (Step 5) | State the constraint: the key must be `\w`+spaces only, so a hyphenated repo name is written with `_` (or note that such names cannot use this syntax yet). Two-line doc edit. |
| [MEDIUM] M2 | Comment overclaims — the same class TEA flagged for 162-6 and this story was meant to end. `_verify_no_pr_repo`'s comment asserts "an all-repos abort keeps the already verified repos' step records in the report", but the pre-merge pass stashes *successful* verdicts in `no_pr_steps` and appends them to `steps` only during the merge-loop replay. If a LATER repo aborts inside the pre-pass (conflict gate at 1673, or another repo's no-PR failure at 1606), the earlier verified-merged repo's step record is **absent** from the report — which is exactly the justification the comment gives for the `skipped: "branch-verified-merged"` value. | `story_finish.py` ~1237 | Either append verified steps in the pre-pass (and drop the replay), or scope the comment to "an abort in the merge loop". |
| [LOW] L1 [TEST] | `ruff format --check` **fails** on the new test file (one line-wrap, ~line 549). Dev's assessment claims "`ruff check` + `ruff format --check` clean" — that claim is false. | `test_162_33_multi_repo_finish.py:549` | `uv run ruff format` on the file. |
| [LOW] L2 [TEST] | Test gaps on M5: `landed_repos` is asserted only via a stringified-all-values substring (`"api" in reported`), never `result["landed_repos"] == ["api"]`, so dropping the structured key while keeping the note would still pass. Only the rc!=0 arm is covered — the merge-timeout (1793) and post-merge-verification-failure (1851/1874) arms also carry `landed_repos` and are untested. Also untested: already-merged-short-circuit-then-second-merge-fails (must keep `landed_repos == []`), and multi-repo human mode. | `test_162_33_multi_repo_finish.py:500-560` | Add the structured assert + the two arm cases. |
| [LOW] L3 | Failure returns *after* the merge loop (archive `OSError` at 1923, and the later status/transition arms) fire when ALL repos have landed but the story is not done, and carry neither `landed_repos` nor the note. Defensible — "revert those merges" would be wrong advice there and the retry is safe via the already-merged short-circuit — but the asymmetry is unremarked. | `story_finish.py:1923` and following | One comment stating why the note stops at the merge loop. |
| [LOW] L4 [RULE] [TYPE] | Result-shape inconsistency in the new helper. `_verify_no_pr_repo` returns `{success, step, error}` — the payload key is `step` where the project contract and every other result-carrying function in this file use `data` (648/672/684/710) — and it returns a bare `dict[str, Any]` even though this same file already establishes `_PRClassification` (NamedTuple, 372) as the pattern for "verdict plus supporting data", so the success/error pairing invariant is unencoded and callers index `["error"]` with only an `Any` promise. Relatedly, `_repo_label` uses `getattr(repo_config, "name", "")` against a declared `RepoConfig \| None` whose `name: str` is a required dataclass field — the fallback would silently absorb a rename into a misleading empty label instead of failing loudly. Internal private helper, so no boundary contract is broken; the no-throw half of the rule is satisfied (no `raise` added). | `story_finish.py:1195-1203`, `1183-1192` | Make it a `_NoPRVerification(NamedTuple)` mirroring `_PRClassification`, and use `repo_config.name if repo_config is not None else ""`. |
| [LOW] L5 [SEC] | Security is substantively clean (see Subagent Results #3 — no argv/flag injection, no traversal, 162-4 guards intact, no way to leverage a no-PR repo into authorizing a merge). Two pre-existing CWE-209 nits are now replicated per repo rather than once: the gate-timeout strings interpolate the absolute `{repo_path}` where every other new message in this diff uses `_repo_label`, and `gate_timeout` (raw `gh` stderr) is not passed through this file's own `_scrub_credentials` as the `_git_cleanup` path is. | `story_finish.py:1519`, `1627` | Swap `{repo_path}` → `_repo_label(...)` and wrap `gate_timeout` in `_scrub_credentials`. |

**Dismissed (specialist findings I checked and rejected):** unguarded `merge_state["base"]`/`["count"]`/`["reason"]` accesses — every `_branch_merge_state` return path carries `base`, definitive paths carry `count`, unknown/timeout carry `reason` (verified 919-1005), and the deleted inline code did the identical key access, so nothing is introduced. `_verify_no_pr_repo` not wrapped in try/except — the no-throw exposure is `_branch_merge_state`'s and is unchanged by this diff. Dry-run `base=default_branch` "regression" — preview and real run now agree, which is the 155-31 goal; 155-31/164-9 suites pass. `_repo_label` empty for `Path("/")` — unreachable given `_resolve_story_repos`' existence guard.

**Deviation audit:** both Dev deviations **ACCEPTED**. Deliverable-5 direction: spec-sanctioned, no regression (finding re-classified above, not the deviation). Deliverable 6: rationale upheld. The extra `pr_number`/`primary_repo_path` deletion and the `!= "human"` widening are both **ACCEPTED** — independently verified as no-op-or-safer, and the deletion resolves TEA's second Delivery Finding outright rather than deferring it.

**Handoff:** To SM for finish-story. M1 and M2 are cheap on-branch doc/comment edits (~4 lines total) in the very files that are this story's deliverable — SM's discretion whether to amend before merge or file as follow-up.

## Reviewer Assessment

**RE-REVIEW — Fix Round 1 (`9029edd11..22c7f1b50`)**

**Verdict:** APPROVED. All three findings ADDRESSED. One new [LOW] (non-blocking), no new
Critical/Important. Scoped to the fix diff only.

| Prior | Status | Evidence |
|---|---|---|
| [MEDIUM] M1 | **ADDRESSED** | Key class widened `\w[\w\s]*` → `\w[\w\s-]*` in BOTH `session_parse.py:23` and `hooks/schema_validation.py:42`. Verified at runtime: `- **PR my-repo:** #227` → key `pr my-repo`, distinct from `pr`; `pr` absent when only per-repo lines present. Regexes byte-identical (`.pattern` AND `.flags` compared live); parity test `test_162_11::test_consumer_parses_every_shape_the_hook_accepts` passes. Docs rewritten in both places to assert the *parseable* form and no longer prescribe an unparseable one. New test `TestPerRepoPrFieldIsParseable` pins key, sibling key, absence of `pr`, and `branch` survival. |
| [MEDIUM] M2 | **ADDRESSED** | `story_finish.py:1228` comment now states the mechanism honestly: the record reaches the report only when the merge loop replays recorded verdicts, so a pre-pass abort suppresses earlier repos' records, and the abort's own error names the failing repo instead. Verified against the code — accurate, no residual overclaim. |
| [LOW] L1 | **ADDRESSED** | `ruff format --check` on all four touched Python files → "4 files already formatted" (rc=0). `ruff check` → all passed. The offending wrap at old line 549 is collapsed to one line. |

**Regex-widening safety: SAFE — the change is strictly monotone.**
Ran a 25-case adversarial battery diffing old vs. new match+key on every line shape in a real
session file. **No line that matched before changes its key**; the only new matches are keys
containing a literal hyphen. The `-` is trailing in the char class, so it is a literal, not a range.

- **Non-fields stay non-fields:** `---` (hrule), `- - **PR:** #1`, `-**PR:** #5`, `## Story Details`,
  `### Reviewer (audit)`, `- **Gap** (non-blocking): thing` (colon outside the `**`),
  `text **PR:** #7` (mid-prose, anchor holds), `| **PR:** | x |`, `> - **PR x-y:** #2` (blockquote),
  `- ****:** v`, `- **-leading:** v` (leading `\w` still required), `- **PR (api):** #1` (parens still rejected).
  Markdown list dashes and headings do **not** become fields.
- **Existing single-repo parsing unchanged:** `- **PR:** #99` → `PR`, `- **Branch:** feat/…` → `Branch`,
  `**Workflow:** tdd` → `Workflow`, `- **PR my repo:** #3` → `PR my repo`, `- **PR:** #1 **Branch:** b` → `PR`.
  Greedy `[\w\s-]*` cannot cross `:` or `*`, so no key-extension backtracking hazard.
- **New matches are inert.** Two things make this a no-op rather than a behavior change:
  (1) every new key contains a hyphen, and (2) **every** consumer key is hyphen-free —
  `branch`, `pr`, `workflow`, `phase`, `jira`, `jira key`, `points`, `id`, `story id`,
  `review verdict`, `review findings`. So a newly-parsed key can never shadow a real one, and
  `setdefault` first-wins is unperturbed. Audited all consumers: `tui/story_detail_data.py:84`
  (explicit `_KEY_MAP` allowlist), `findings/aggregate.py:185`, `demo/collector.py:59`,
  `story_finish.py:1377` — **none** iterates or renders the full key set, so a spurious
  hyphenated key (e.g. prose `- **Pre-merge:** hoisted` now parsing) is dead data, not output.
- **Hook cannot be loosened into a false pass:** `_story_details_field_labels` feeds
  `_validate_session_fields`, which checks membership of `SESSION_REQUIRED_FIELDS` = `{branch, pr}`.
  Widening can only add hyphenated labels, which can never satisfy a hyphen-free requirement.
  No path where a session missing `**Branch:**`/`**PR:**` now passes the hook.

**Test result:** `test_162_33_multi_repo_finish.py` + `test_162_11_schema_hook_session_fields.py` +
`test_155_40_session_field_parse_anchor.py` + `test_164_11_…` + `test_164_13_…` +
`test_155_33_…` + `test_150_10_…` → **136 passed**, 0 failed, 5.63s. No session-parse regression.
(Scoped run, per protocol — no full suite.)

**Specialist domains — re-checked by me directly, not re-spawned.** The fix diff is 6 files /
+56/-13 lines and touches one char class, one comment, two doc paragraphs and one test class, so a
full specialist fan-out would re-scan the round-0 surface. Each domain was re-checked against the
fix diff only:

- **[SEC]** Clean. No new argv/subprocess/IO surface. The one input-handling change is the regex,
  which is a *widening* of an anchored, non-backtracking-hazardous pattern applied to
  operator-authored session files, not untrusted input; `[\\w\\s-]*` cannot cross `:` or `*` so
  there is no catastrophic-backtracking or key-injection path, and no new key reaches a shell,
  path, or `gh` flag. Round-0 [SEC] L5 (`{repo_path}` interpolation, unscrubbed `gate_timeout`)
  is untouched and remains open, non-blocking.
- **[TEST]** Round-0 L1 closed (`ruff format --check` rc=0). The new `TestPerRepoPrFieldIsParseable`
  is non-vacuous and well-targeted: it asserts the positive key, a second repo's key, the *negative*
  (`"pr" not in fields` — the collision that would matter), and that `branch` still parses, so it
  would fail if the widening had been done by loosening the anchor instead. It goes through the real
  `parse_session` on a real file, not the regex directly, so it pins behavior rather than the pattern.
  Round-0 L2 (structured `landed_repos` assert, untested timeout/post-verify arms) stays open,
  non-blocking. Gap I accept as adequate: no test pins the *negative* side of the widening
  (that `- **PR (api):**` and a markdown hrule still are not fields) — I verified those 12 cases
  by hand above, and `test_155_40_session_field_parse_anchor.py` (in the passing run) covers the
  anchor half.
- **[RULE]** Compliant. `.js`-extension and never-edit rules N/A; all edits are in
  `pennyfarthing-dist/` source, none in `.pennyfarthing/` symlinks or `node_modules/`. No `raise`
  added — result-object contract intact. The regex-parity rule this epic established (hook pattern
  IS the consumer's) is honored *and* machine-enforced: both constants changed in lockstep and
  each new comment cross-references the other plus the pinning test. Round-0 L4 (`step` vs `data`
  key, `getattr` fallback) untouched, open, non-blocking.
- **[TYPE]** No type surface changed. `SESSION_FIELD_RE`/`_FIELD_LINE_RE` stay `re.Pattern[str]`;
  `parse_session` stays `dict[str, str]`. Worth noting the widening makes the stringly-typed
  `dict[str, str]` field bag slightly leakier (an unbounded set of hyphenated keys can now appear),
  but every consumer reads by explicit hyphen-free key, so no contract is weakened — the round-0
  observation that this bag wants a typed accessor is unchanged in force, not made worse.

**New findings in the fix diff**

| Severity | Issue | Location | Fix |
|----------|-------|----------|-----|
| [LOW] N1 | Stale docstring, same class as M2. `_story_details_field_labels`' docstring still says "A line the consumer's pattern cannot parse (a qualified per-repo label, for now) contributes no label — it is tolerated, not counted." As of this diff a hyphenated per-repo label **does** parse and **does** contribute a label (`pr my-repo`); it is tolerated because the label differs from `pr`, not because it fails to parse. The behavior is correct; only the stated reason is now wrong. The `SESSION_REQUIRED_FIELDS["pr"]` message below it is still accurate (it cites the paren form). | `hooks/schema_validation.py:105-113` | Restate: per-repo labels parse to their own key and therefore do not satisfy the bare `pr` requirement. |

**Not filed (checked, below threshold):** the schema doc's "Word characters, spaces and hyphens
only" omits that the *first* character must be `\w` (a leading hyphen does not parse) — no real
`repos.yaml` name starts with a hyphen. The rewritten `sm-setup.md` sentence runs ~105 chars on
one line where its neighbours wrap at ~78 — markdown, no linter, cosmetic.

**Handoff:** To SM for finish-story. Open non-blocking list is unchanged except M1/M2/L1 now
closed and N1 added; L2-L5 from the first pass remain open and non-blocking.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T21:20:57Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T20:31:01Z | 2026-08-11T20:32:40Z | 1m 39s |
| red | 2026-08-11T20:32:40Z | 2026-08-11T20:38:51Z | 6m 11s |
| green | 2026-08-11T20:38:51Z | 2026-08-11T20:52:11Z | 13m 20s |
| review | 2026-08-11T20:52:11Z | 2026-08-11T21:11:09Z | 18m 58s |
| finish | 2026-08-11T21:11:09Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Improvement** (non-blocking): `_resolve_story_repos` still drops an unknown `repos:` name SILENTLY whenever at least one name resolves (`repos: "api, tpyo"` → only `api`), so that repo is never verified. Deliverable 5 was resolved by making the docstring honest (TEA's test accepts either direction) because turning an unknown name into a hard abort changes the finish outcome of existing stories with typo'd/renamed repo names. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_resolve_story_repos` — should return `{"success": False, error naming the unknown name}` when SOME names resolve and others do not). *Found by Dev during implementation.*
- **Gap** (non-blocking): the per-repo `**PR {repo}:**` syntax is now DOCUMENTED (schema + sm-setup) but not yet READ by finish — a multi-repo story's PRs are still resolved per repo from the shared branch via `gh pr list --head`. That is fine while the branch exists, but a multi-repo finish re-run after `--delete-branch` resolves no PR in the already-merged repo and falls into the no-PR/branch-verification arm. Affects `story_finish.py` (honor `pr <repo>` session fields) + `schemas/session-schema.md` (drop the "not read yet" caveat once it is). *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (blocking-priority for its own story — re-classification of Dev's non-blocking Improvement): `_resolve_story_repos` (`story_finish.py:682`, `resolved = [configs[name] for name in names if name in configs]`) drops an unknown `repos:` name silently whenever ≥1 name resolves, so `repos: "api, tpyo"` finishes the story **done** with tpyo's PR never merged — silent success over unlanded work, the defect class epic 155/162 exists to kill, not an "improvement". Dev's "changes existing stories' outcome" objection only ever converts a wrong success into a retryable refusal (session kept, nothing irreversible), i.e. the safe direction. Affects `story_finish.py` (`_resolve_story_repos` → `{"success": False}` naming the unknown name when SOME names resolve and others do not). *Found by Reviewer during code review.*
- **Gap** (non-blocking): the documented per-repo key `**PR <repo-name>:**` is unparseable for hyphenated repo names — `SESSION_FIELD_RE` (`session_parse.py:19`) allows `\w` and spaces only, so `- **PR my-repo:** #227` does not match. Neither doc notes the constraint despite justifying the syntax by parser compatibility. Affects `schemas/session-schema.md` + `agents/sm-setup.md` (state the constraint / prescribe `_` for hyphens), and `story_finish.py` when it starts reading the field. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): with NO inheritance now the documented rule, an epic-level `repos:` is dead-but-plausible data — `sprint/epic-163.yaml:7` already carries `repos: pennyfarthing`. An author who omits story-level `repos:` under that epic gets degradation to the project root (the orchestrator repo), i.e. verification of the wrong repo. Affects `pf validate` / `pf sprint story add` (warn, or propagate the epic value onto the story at write time) — a loud guard is what makes the NO-inheritance decision safe in practice. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `cli.py:485` renders dry-run steps as `f"  {step['step']}. {step['action']}"`, dropping the new per-repo `repo` key — so an M6 multi-repo preview prints two bare `Merge PR #11` / `Merge PR #22` lines with no repo label, and the dry-run branch also never prints `step['error']`, hiding the no-PR refusal text from the preview. The step data is now correct; the operator-facing render is not. Affects `src/pf/sprint/cli.py` (`story_finish` command output). *Found by Reviewer during code review.*

### TEA (test design)
- **Gap** (non-blocking): the M4 defect is broader than the story title says — the 162-6 comment above the `pr_views` gate already CLAIMS "Every repo is gated BEFORE any repo is merged", but only the PR-conflict half was hoisted; the no-PR/branch verification stayed in the merge loop. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (the comment must stop overclaiming, or the code must match it). *Found by TEA during test design.*
- **Gap** (non-blocking): the same positional pairing exists for the REPORTED PR on the real-run path — `pr_number = next((rp for … if rp), None)` is what the result/caller reports for a multi-repo story, so a two-repo finish reports one repo's PR number as "the" PR. Affects `story_finish.py` (`pr_number` / `primary_repo_path`). Not pinned here (M6 scopes the preview). *Found by TEA during test design.*
- **Question** (non-blocking): `_resolve_story_repos` drops unknown `repos:` names silently only when at least one name resolves — deliverable 5 and deliverable 6 (epic inheritance) interact here. If epic inheritance lands, an all-typo story would inherit the epic's repos instead of degrading to the project root, which changes what "cannot silently skip verification" means. Affects the docstring + `schemas/` decision record. *Found by TEA during test design.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Deliverable 5 direction:** spec offered "reconcile the docstring OR make the unknown name loud"; implemented the docstring reconcile and left behavior unchanged. Reason: making an unknown `repos:` name a hard abort changes the finish outcome for existing stories (renamed/typo'd repo names in live sprint YAML) and is not pinned by any test. Logged as a Delivery Finding for its own story.
- **Deliverable 6 (epic-level `repos:` inheritance) — DECISION: NO inheritance.** A story's `repos:` is read from the story dict only; an epic-level value is never inherited. Rationale: (1) `repos:` drives irreversible `gh pr merge` calls, so the set of repos a finish will touch must be visible in the same record the agent/operator is reading — inheritance makes it action-at-a-distance from a field the story author never saw; (2) the existing degradation (no `repos:` → project root + root config) is a SAFE default: the root repo either verifies or aborts loudly, whereas inheritance would hand an all-typo story a plausible-but-WRONG set of repos to verify (TEA's Question in Delivery Findings); (3) SM already writes `repos:` per story at setup, so the cost is one explicit field. Pinned in `_resolve_story_repos`'s docstring and in `schemas/session-schema.md` + `agents/sm-setup.md`. No code change needed — the decision is that today's behavior is correct and is now documented as intentional rather than accidental.
- **Extra (beyond M4/M5/M6):** `pr_number`/`primary_repo_path` (the positional "reported PR" TEA flagged as finding #2) were the only consumers of the positional pairing and are now DELETED rather than rewired — nothing downstream read them, so the wrong-repo report shape is gone instead of fixed. The pre-merge pass condition also moved from `== "auto"` to `!= "human"` so every mode the merge loop merges in records a verdict for the loop to replay (a third mode would otherwise KeyError out of a no-throw function).