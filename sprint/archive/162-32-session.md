---
story_id: "162-32"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-32: Resolver guards for _resolve_story_repos

## Story Details
- **ID:** 162-32
- **Jira Key:** (none — Jira integration disabled)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-32-resolve-story-repos-guards-gitcleanup-rc
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the title is the full spec (162-6 review follow-up). THREE deliverables in `pennyfarthing-dist/src/pf/sprint/story_finish.py` (+ `git/repos.py` precedent):

1. **Existence-check the resolved cwd in `_resolve_story_repos`:** an uncloned topology entry currently RAISES out of the result contract (SOUL rule #6 — return `{success, error}`, don't throw). There is a precedent guard at `git/repos.py:141` — mirror its shape. Return a result object naming the missing/uncloned repo path instead of raising.
2. **Dedup the `repos:` list:** a duplicate repo name causes the SAME PR to be merged twice → the second merge exits non-zero → a FALSE ABORT on already-landed work. Dedup the resolved repos list (preserve order) so each repo is processed once.
3. **Stop discarding the three git return codes in `_git_cleanup`** while reporting "clean": `_git_cleanup` runs git subprocesses whose non-zero return codes are currently ignored, so it reports success even when a git step failed. Capture and propagate/report those return codes truthfully.

**TEA (RED):** failing tests, faking `_run`/subprocess as the hermetic seam, pass explicit `project_root`/`repo_path`:
- (1) `_resolve_story_repos` with an uncloned/missing topology entry returns a `{success: False, error: ...}` result naming the repo — NOT a raised exception. Pin against the current raise.
- (2) a `repos:` list containing a duplicate name results in the PR being merged exactly ONCE (assert the merge call count / no false abort).
- (3) `_git_cleanup` with a git step returning non-zero does NOT report clean — the failing return code surfaces in the result.
Read `git/repos.py:141` to match the precedent guard's shape.

**Constraints (binding):** scoped runs — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/<finish/repos tests>.py -q`; NEVER full suite. `_run` is THE seam. Result objects, not throws. `ruff check` changed files. Preserve 162-4/162-6/162-9 invariants already in story_finish.py.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (6 failing — ready for Dev)

**Test File:** `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_32_resolve_repos_guards.py`
(600 lines; hermetic — `_run` is the only seam, real git fixture repos with bare origins, explicit `project_root`/`repo_path`, no chdir)

**Tests Written:** 6 covering 3 ACs

AC1 — uncloned repo is a result, not a throw (`TestUnclonedRepoIsAResultNotAThrow`):
1. `test_resolve_story_repos_returns_result_naming_uncloned_repo`
   `AssertionError: _resolve_story_repos must answer with a result object so an uncloned repo can be reported instead of raised; got <class 'list'>`
2. `test_finish_story_reports_uncloned_repo_instead_of_raising`
   `Failed: finish_story raised instead of returning a result for an uncloned repo: FileNotFoundError: [Errno 2] No such file or directory: '.../orc/framework'`

AC2 — duplicate repo name merges once (`TestDuplicateRepoMergesOnce`):
3. `test_resolve_story_repos_dedups_preserving_order`
   `AssertionError: the same repo must resolve once, in order: [PosixPath('.../orc/framework'), PosixPath('.../orc/framework')]`
4. `test_duplicate_repo_merges_once_and_does_not_false_abort`
   `AssertionError: a repo named twice must be merged once, not 2 times: [(['gh','pr','merge','532','--squash','--delete-branch'], '.../orc/framework'), (same argv again)]`

AC3 — git-cleanup return codes surface (`TestGitCleanupPropagatesReturnCodes`):
5. `test_failed_pull_is_not_reported_as_clean`
   `AssertionError: the failing pull's stderr must reach the step-6 record; the record reports a clean cleanup instead: [{'step': 6, 'action': 'git_cleanup', 'branch': 'feat/162-32-...'}]`
6. `test_failed_branch_delete_is_not_reported_as_clean`
   `AssertionError: the refused delete's stderr must reach the step-6 record; ... [{'step': 6, 'action': 'git_cleanup', 'branch': 'feat/162-32-...'}]`

**Right-reason verification:** each failure was read individually. (2) fails inside the real defect path — `story_finish.py:1189` runs `_run(["gh","pr","list",...], cwd=<uncloned dir>)`, and the fake reproduces `subprocess`'s real behavior there (confirmed: real `subprocess.run(cwd=<missing>)` raises `FileNotFoundError`). (4) records TWO identical `gh pr merge` calls for one PR — the stale-`pr_views` snapshot mechanism, not a fixture artifact. (5)/(6) show the bare no-warning step-6 entry.

**GREEN reachability probed:** with a dedup shim over `_resolve_story_repos`, the AC2 end-to-end run reports `merges: 1, success: True` — the test is reachable, not over-specified against the fixture. Probe was temporary and removed.

**Interface note for Dev:** AC1 changes `_resolve_story_repos`'s return type from a bare list to a result object; every caller (`finish_story:1176`) must adapt. Tests read the resolved list via `_resolved_repos()`, which accepts either a bare list or `{"success": True, "data": [...]}`, so the dedup assertion does not double as a signature assertion. `_git_cleanup`'s existing `stopped()` helper is the natural home for AC3 — it already produces the "not a clean step 6" shape, and step 6 warnings must not fail the finish (the story shipped).

**Quality:** `ruff check` + `ruff format` clean. Scoped runs only; full suite never run.
**Commit:** `a9c5f55a5` (signed, framework repo)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — three guards:
  - `_resolve_story_repos` now returns a result object (`{success: True, data: [...]}` / `{success: False, error: ...}`), consistently on every arm including the two degrade paths. A resolved path that is not a directory returns the failure arm naming `repo (path)` — mirrors `git/repos.py:141`'s `exists()` precedent but LOUD, since silently dropping the repo would degrade the story to the project root and verify the wrong repository.
  - Names deduped in order via a `seen` set, so `repos: [framework, framework]` resolves once — kills the second `gh pr merge` off the stale pre-merge `pr_views` snapshot and the false abort it produced.
  - `finish_story` routes the failure arm at the resolution site: aborts with a result BEFORE any irreversible step (session kept, archive untouched), naming the repo to clone.
  - `_git_cleanup`'s chain loop now checks `result.returncode != 0` for EVERY command, not just the checkout, routing through the existing `stopped()` helper so the failing stderr reaches the step-6 record. Stopping the chain remains correct (a delete off a base the pull never updated is refused anyway), and step 6 warnings do not flip the finish to failure (162-9 preserved).
- `pennyfarthing-dist/src/pf/tests/test_164_12_finish_story_no_throw_guards.py` — two assertions read the resolved list through `["data"]`; behavior pinned is unchanged (signature-only adaptation TEA flagged in the interface note).

**Tests:** 6/6 passing on `test_162_32_resolve_repos_guards.py` (GREEN)
**Regression batch:** 961 passed, 0 failed — every test file matching `_resolve_story_repos|_git_cleanup|finish_story|story_finish`. Full suite never run.
**Quality:** `ruff check` clean on both changed files.
**Branch:** `feat/162-32-resolve-story-repos-guards-gitcleanup-rc` (pushed)
**Commit:** `53f2ee1a9` (signed, framework repo)

**Handoff:** To Reviewer

### Fix Round 1 (post-REJECT)

**Findings addressed:** H1, M3 [SEC], M1, M2 [TEST]. (L1/L2/L3/L4 left as the Reviewer scoped them.)

- **[HIGH] H1 — false step-6 warning on every healthy finish.** `_git_cleanup` now probes `git rev-parse --verify --quiet refs/heads/<branch>` before appending the delete to the chain (mirrors the base probe above it, same read-only shape and timeout routing) and omits the delete entirely when the branch is absent — so `gh pr merge --delete-branch` having already removed the local branch produces a clean step 6. A probe timeout still routes through `stopped()`. The rc that survives the guard is a *refused* delete, which is the case worth warning about.
  Covering test: `test_branch_already_deleted_by_merge_reports_no_warning` — `_cleanup_run(branch_exists=False)` models gh's local deletion; asserts `[e["warning"] for e in entries] == [None]` AND that `git branch -d` was never invoked.
- **[MEDIUM][SEC] M3 — credential leak.** New module-level `_scrub_credentials()` (`_CREDENTIAL_URL_RE = r"(https?://)[^@/\s]+@"` → `\1<credentials>@`), applied inside `stopped()` so EVERY arm of step 6 is scrubbed, not just the pull — one choke point, no arm can be added later that bypasses it.
  Covering test: `test_pull_stderr_does_not_leak_remote_credentials` — token-bearing `fatal: repository 'https://oauth2:<TOKEN>@github.com/...' not found`; asserts the token and `oauth2` are absent, `<credentials>@github.com` present, and `not found` still reported.
- **[MEDIUM] M1 — dedup keyed on name.** The name-keyed `seen` set is gone; dedup now runs over the RESOLVED PATH (`(project_root / rc.path).resolve()`), first occurrence wins, order preserved. Two repos.yaml names for one directory now collapse to one entry, so the per-repo loop cannot re-issue `gh pr merge` off the stale `pr_views` snapshot. Docstring updated.
  Covering tests: new `TestAliasedReposDedupOnPath` — `test_two_names_one_path_resolve_once` (unit) and `test_two_names_one_path_merges_once` (end-to-end, exactly 1 `gh pr merge`, `success is True`), against a new `REPOS_YAML_ALIASED` fixture (`framework` + `framework-alias`, same `path`).
- **[MEDIUM][TEST] M2 — 162-9 invariant unpinned.** New `TestFailedCleanupIsAWarningNotAFinishFailure::test_failing_cleanup_still_finishes_and_runs_step_7` runs `finish_story` end-to-end with the step-6 `git pull` forced to rc=1 and asserts `result["success"] is True`, the step-6 warning carries the stderr, a step-7 entry exists, and the session file was unlinked. Propagating the cleanup failure outward now fails this test.

**Tests:** 11/11 on `test_162_32_resolve_repos_guards.py` (6 original + 5 new).

```
$ cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_32_resolve_repos_guards.py -q
...........                                                              [100%]
11 passed in 3.79s

$ uv run pytest src/pf/tests/test_162_32_resolve_repos_guards.py src/pf/tests/test_164_12_finish_story_no_throw_guards.py -q
24 passed in 4.07s
```

**Regression batch (same 45 files as round 0 — every test file matching `_resolve_story_repos|_git_cleanup|finish_story|story_finish`):**

```
$ uv run pytest $(grep -rl "_resolve_story_repos\|_git_cleanup\|finish_story\|story_finish" src/pf/tests/ | grep '/test_.*\.py$' | sort) -q
966 passed in 100.25s (0:01:40)
```

(961 → 966: exactly the 5 new tests; no prior test changed state.) Full suite never run.

**Quality:** `ruff check` + `ruff format --check` clean on both changed files.
**Commit:** `b38d60bbc` (signed `G`, framework repo, pushed)

**Handoff:** Back to Reviewer

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 19 passed / 0 failed; ruff clean; all callers of both changed functions adapted (grep-verified) | N/A |
| 2 | reviewer-rule-checker | Yes | clean | 0 violations across 12 rules / 31 instances; SOUL #6 satisfied on every arm. Sub-threshold note: dead `# noqa: BLE001` at `test_162_32...py:426` (BLE not in ruff select) | Confirmed clean; noqa note not worth a rework cycle |
| 3 | reviewer-security | Yes | findings | (a) credential-bearing `git pull` stderr now reaches the step-6 warning and stdout; (b) `(project_root / rc.path).resolve()` has no confinement check (absolute/`..`/symlink escape) | (a) CONFIRMED → [SEC] M3 (newly introduced by this diff); (b) DISMISSED as pre-existing — the path construction predates the diff and `rc.path` is operator-authored repos.yaml, not external input; logged as [SEC] L3 |
| 4 | reviewer-test-analyzer | Yes | findings | 162-9 invariant not pinned end-to-end; order-preservation test vacuous with one distinct name; 164-12 edits are pure signature adaptation (no weakening) | First two CONFIRMED → [TEST] M2, L1. Third confirms Dev's deviation is safe |
| 5 | reviewer-type-design | Yes | findings | `dict[str, Any]` cannot express the success⇒data / failure⇒error discriminant; codebase has TypedDict precedent (`session/paths.py`, `handoff/gate_recovery.py`); dedup should key on resolved `Path` | TypedDict → [TYPE] L2 (no mypy/pyright configured; module-local convention is `dict[str, Any]`, so consistent as written). Path-keyed dedup corroborates M1 independently |
| 6 | reviewer-edge-hunter | Yes | findings | `branch -d` "not found" now chain-stops (previously benign); name-vs-path dedup; early return omits `steps` | First two CONFIRMED → H1 (reached independently and by a stronger route), M1. `steps` omission DISMISSED: matches the sibling early return at `:1266` and the CLI uses `.get("steps", [])` |
| 7 | reviewer-silent-failure-hunter | Yes | findings | `except (yaml.YAMLError, OSError)` arm reports `success: True`; unknown repo names silently dropped | First DISMISSED — 164-12 explicitly pins that degrade; changing it is a separate story. Second CONFIRMED as a real but pre-existing gap → L4 + Delivery Finding |

**All received: Yes** (7 of 7 specialists returned; none errored).

## Reviewer Assessment

**Verdict:** REJECTED (one HIGH — happy-path false warning introduced by AC3's generalized rc check)

**Evidence run (scoped):** `uv run pytest src/pf/tests/test_162_32_resolve_repos_guards.py src/pf/tests/test_164_12_finish_story_no_throw_guards.py -q` → **19 passed**. `ruff check` clean on all three changed files. Full suite never run.

**Per-deliverable soundness**

- **AC1 existence guard — SOUND.** `_resolve_story_repos` returns a result on all four arms (`story_finish.py:652, 668, 675, 685`); no arm can raise past the contract. SOUL #6 satisfied. The `is_dir()` check is the right predicate (stricter than the `exists()` precedent at `git/repos.py:141` — a file-at-that-path would still break `subprocess(cwd=)`). Failure routing at `story_finish.py:1224-1232` sits before `steps = []`, before the merge, the transition, the archive and the session unlink — the single caller unwraps `["data"]` exactly once. Early-return field shape matches its sibling at `:1266`. Session-kept / archive-untouched is actually asserted by the test, not just claimed.
- **AC2 dedup — SOUND for the reported defect.** `seen: set[str]` over `names` (`:661-666`) keeps first-occurrence order; nothing distinct is dropped, because the filter key is the repos.yaml key and `configs` is a dict (one entry per name). Merge count pinned at exactly 1 end-to-end. Residual: dedup keys on NAME, not resolved PATH — see M1.
- **AC3 rc propagation — CORRECT IN PRINCIPLE, WRONG ON THE HAPPY PATH.** Every non-zero rc now reaches the step-6 record via the existing `stopped()` helper, and step 6 stays a warning (`finish_story` still returns `success: True`; step 7 still unlinks). But the generalized check now fires on a `git branch -d` that failed for a benign reason — see H1.

**Chain-stop-on-failed-pull ruling: DATA-LOSS SAFE.** After a failed `git pull`, local base does not contain the squash commit, so `git branch -d` (safe delete) would be *refused* by git anyway — skipping it removes a redundant second warning, it does not skip a deletion that would have succeeded destructively. The one behavioral cost is the narrow case where base was already up to date before the failed pull: a deletable branch is left behind — and the step-6 warning tells the operator exactly that. Ordering (checkout → pull → delete, stop at first failure) is monotonically safer than the pre-diff behavior. Dev's deviation is ACCEPTED.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | **[EDGE] H1 (blocking).** Step 2 merges with `gh pr merge --squash --delete-branch`, and `-d` is documented as "Delete the **local** and remote branch after merge" — so by the time step 6 runs, the local feature branch is normally already gone. `git branch -d -- <branch>` then exits **rc=1, `error: branch 'X' not found`** (verified empirically). Pre-diff that rc was discarded and step 6 read clean; post-diff it routes through `stopped()` and every first-time successful gitflow finish now reports `git cleanup stopped in <repo>: error: branch 'X' not found — the story is done; finish the branch cleanup by hand`. A false alarm on the primary happy path, which trains operators to ignore exactly the step-6 warning this epic exists to make trustworthy. Invisible to the tests because `_cleanup_run`'s fake returns `delete_rc=0` for the delete and never models gh's local deletion. | `story_finish.py:1105` (guard) / `:1547` (`--delete-branch`) | Distinguish "already gone" from "refused as unmerged" before stopping: probe `git rev-parse --verify --quiet refs/heads/<branch>` and skip the delete cleanly when absent (mirrors the base-branch probe already at `:1090`), or treat rc≠0 with `not found` in stderr as a clean skip. Add a test that models gh having deleted the local branch and asserts step 6 carries NO warning. |
| [MEDIUM] | **[SEC] M3 (newly introduced).** The generalized rc arm now passes raw `git pull` stderr into `entry["warning"]`, which `cli.py:496` prints verbatim. With an HTTPS-with-token remote, a failed pull emits `fatal: repository 'https://oauth2:<TOKEN>@github.com/...' not found` — so a secret lands in the operator's terminal on a path that previously discarded that stderr entirely. `checkout` and `branch -d` carry no remote URL; the pull is the specific exposure. | `story_finish.py:1105` | Scrub credential-shaped substrings before `stopped()`: `re.sub(r"https?://[^@/\s]+@", "https://<credentials>@", stderr)`. Test with a token-bearing stderr fixture. |
| [MEDIUM] | **[TYPE]/[EDGE] M1.** Dedup keys on repo name, not resolved path. Two repos.yaml entries with different names and the same `path` both survive `seen`, both `is_dir()`, and the per-repo loop runs twice against one directory — re-issuing `gh pr merge` off the pre-merge `pr_views` snapshot, i.e. the exact false abort AC2 removes. | `story_finish.py:661-671` | Second dedup pass on the resolved absolute path (or key an ordered map by resolved path). |
| [MEDIUM] | **[TEST] M2.** The 162-9 invariant AC3's own comment asserts ("a warning, not a finish failure") is not pinned by any test. Both AC3 tests call `_git_cleanup` directly; none runs `finish_story` with a failing cleanup and asserts `result["success"] is True`. Propagating the cleanup failure into the outer result would leave all AC3 assertions green. | `test_162_32_resolve_repos_guards.py:557` | One end-to-end test: failing pull → `result["success"] is True` AND the step-6 warning present. |
| [LOW] | **[TEST] L1.** `test_resolve_story_repos_dedups_preserving_order` claims order preservation but passes `["framework", "framework"]` — a one-element result satisfies any ordering claim vacuously; an ordering regression is undetectable. | `test_162_32_resolve_repos_guards.py:460` | Add two distinct repos in both input orders. |
| [LOW] | **[SILENT] L4.** `_resolve_story_repos` still degrades silently to the project root when a name in the story's `repos:` field is absent from repos.yaml (`if name in configs`), so a typo verifies the WRONG repo — while a *cloned-but-missing* repo is now loud. Pre-existing (162-6), documented in the docstring, and pinned by `test_164_12`; noted as an inconsistency the new guard invites closing, not as a regression. | `story_finish.py:664` | Out of scope — recorded as a Delivery Finding. |
| [LOW] | **[TYPE] L2.** `dict[str, Any]` cannot express the discriminant (success ⇒ `data`, failure ⇒ `error`); the caller's `repos_result["data"]` is safe only by the gate above it. A `Literal`-discriminated TypedDict union — the pattern already used in `session/paths.py` and `handoff/gate_recovery.py` — would make it statically safe. Non-blocking: no mypy/pyright is configured, and `dict[str, Any]` is the established shape for every other result helper in this module (`:79`, `:820`, `:986`), so the diff is locally consistent. | `story_finish.py:617` | Optional; if taken, do it module-wide rather than for one helper. |
| [LOW] | **[SEC] L3.** `(project_root / rc.path).resolve()` has no confinement check — an absolute `rc.path` replaces `project_root` outright, and `..`/symlinks escape after `resolve()`; the result becomes the `cwd` for three mutating git commands. Pre-existing (the construction predates this diff) and the input is operator-authored repos.yaml, so no external-input path exists — but the new `is_dir()` guard is the natural place a confinement check would live. | `story_finish.py:671` | Out of scope; consider `p.is_relative_to(project_root)` as a follow-up alongside L4. |

**Verified good (not findings):** **[RULE]** rule-checker reports 0 violations over 12 rules / 31 instances — every arm of both changed functions honors SOUL #6, all edits are in `pennyfarthing-dist/` (no symlink target touched), runtime path resolution stays on `.pennyfarthing/`, and ruff's selected ruleset is clean; the `_run` patch is the only seam (real git fixtures with bare origins, no chdir, explicit `project_root`); the AC1 fake reproduces `subprocess`'s real `FileNotFoundError` on a missing `cwd` rather than papering over it; the two `test_164_12` edits are pure `["data"]` unwraps with byte-identical assertions below them — no weakening; the `except (yaml.YAMLError, OSError)` degrade arm returning `success: True` preserves 164-12's pinned behavior deliberately; no other caller of `_resolve_story_repos` or `_git_cleanup` needs adaptation (grep-verified across `src/pf/`).

**Out-of-scope confirmation:** `session_pr = pr_number if len(story_repos) == 1 else None` (`:1240`) is genuinely pre-existing 162-6, already carries a Delivery Finding, and the dedup only *widens* the honored case (a repo named twice now correctly resolves to `len == 1`). Not newly broken.

**Deviation audit:** result-object on ALL arms — **ACCEPTED** (a union return is what SOUL #6 exists to prevent; one shape, one unwrap). Failed pull stops the chain — **ACCEPTED** (data-loss safe, see ruling). `test_164_12` `["data"]` unwraps — **ACCEPTED** (signature-only; TEA's interface note anticipated it).

**Handoff:** Back to Dev (H1 is a 4-line guard plus a test; M1/M2 recommended in the same pass).

## Reviewer Assessment

**RE-REVIEW (fix round 1 — `53f2ee1a9..b38d60bbc`)**

**Verdict:** APPROVED

**Evidence run (scoped):**
```
uv run pytest src/pf/tests/test_162_32_resolve_repos_guards.py \
              src/pf/tests/test_164_12_finish_story_no_throw_guards.py -q  → 24 passed
uv run pytest src/pf/tests/test_162_6_finish_repo_context.py -q            → 14 passed
```
(162-6 run added by me: it is the file that pins the step-6 delete and the multi-distinct-repo
`[api, ui]` resolution — the two behaviors the H1 probe and the M1 rekey could have broken.)
Full suite never run.

| Finding | Verdict | Evidence |
|---------|---------|----------|
| **[HIGH] H1** false step-6 warning on healthy finish | **ADDRESSED** | `story_finish.py:1118-1139`: `git rev-parse --verify --quiet refs/heads/<branch>` gates the append; the delete is omitted entirely when absent, so the clean `entry` is returned. Real-git verified by me in a throwaway repo: `rev-parse --verify --quiet` → rc 0 present / rc 1 absent, and `git branch -d -- <absent>` → rc=1 `error: branch 'X' not found` — exactly the false warning, now unreachable. (a) `test_branch_already_deleted_by_merge_reports_no_warning` asserts `[e.get("warning") for e in entries] == [None]` **and** that `git branch -d` was never invoked — not vacuous (pre-fix it would warn). (b) `test_failed_branch_delete_is_not_reported_as_clean` (default `branch_exists=True`) still passes with `rec.matching("git","branch","-d")` as an explicit precondition, so a genuinely refused delete STILL warns — the guard narrowed the arm, it did not disable it. Probe timeout routes through `stopped()`; `_timed_out` is `isinstance(_TimedOutProcess)` so MagicMock fakes cannot read as timed out. |
| **[MED][SEC] M3** credential scrub | **ADDRESSED** | `_CREDENTIAL_URL_RE`/`_scrub_credentials` at `:990-1004`, applied inside `stopped()` (`:1060`) — the single output shape, so every arm (validation, both probes, both timeouts, every rc) is scrubbed. I ran the regex against 9 inputs myself: token URL → `https://<credentials>@github.com/...` with `not found` retained; **no over-scrub** — `https://github.com/o/r`, `see https://github.com/o/r/issues/1 and mail me@example.com`, and `git@github.com:o/r.git` are all untouched (`[^@/\s]+` cannot cross `/`, and the `https?://` anchor excludes SSH/bare-email forms). `entry` carries no `stdout` field, so the warning is the whole exposure surface. |
| **[MED] M1** dedup on resolved path | **ADDRESSED** | `:669-681`: `seen: set[Path]` over `(project_root / rc.path).resolve()`, first occurrence wins, appended in iteration order. Two names → one path merges once, pinned twice: `test_two_names_one_path_resolve_once` (asserts the resolved list is exactly `[(project/"framework").resolve()]`) and `test_two_names_one_path_merges_once` (end-to-end, exactly 1 `gh pr merge`, `success is True`), against the new `REPOS_YAML_ALIASED` fixture. Distinct paths preserved and order preserved — covered by 162-6's `[api, ui]` / `"api,ui"` cases, which I re-ran green. |
| **[MED][TEST] M2** 162-9 invariant | **ADDRESSED** | `TestFailedCleanupIsAWarningNotAFinishFailure::test_failing_cleanup_still_finishes_and_runs_step_7` calls `finish_story(project, STORY_ID)` (not `_git_cleanup`) with `git pull` forced to rc=1, and asserts `result["success"] is True`, the step-6 warning carries the stderr, a step-7 entry exists, and the session file is unlinked. Outward propagation of the cleanup rc would fail the first assertion — the test does the job it was asked for. |
| L1 / L2 / L3 / L4 | deferred as scoped | Left open by design (L1 vacuous ordering, L2 TypedDict, L3 path confinement, L4 unknown-name degrade); L3/L4 carry Delivery Findings. |

**New-breakage scan (fix diff only):** no Critical/Important. Deferred minors:
- **[LOW][SEC]** `_CREDENTIAL_URL_RE` is non-greedy on userinfo: a password containing a literal `@` (`https://user:p@ss@host/x`) redacts only up to the FIRST `@`, leaving `ss@` in the report. Percent-encoding is the normal form and git would mis-parse the raw variant anyway, so this is a narrow partial leak, not the reported exposure. `[^/\s]+@` (greedy) would close it. Also scheme-limited to `http(s)` — `ssh://u:pw@h` is not scrubbed (SSH URLs do not normally carry secrets).
- **[LOW][TYPE]** `paths: list[tuple[Path, Any]]` (`:675`) widens the element type to `Any` where the loop below relies on `rc.name`/`rc.path`; `RepoConfig` is already the concrete type in this module.
- The H1 probe adds one read-only `_run` per gitflow cleanup. Verified non-breaking against the two suites that model step 6 with real git fixtures (162-6, 162-32) plus 164-12.

**Verified good — [RULE]:** `ruff check` and `ruff format --check` clean on both changed files (re-run by me, not taken on report). Both edits are under `pennyfarthing-dist/` — no `.pennyfarthing/` symlink target touched. SOUL #6 holds on every arm of the fix diff: `_resolve_story_repos` still returns a result on all four arms, `_git_cleanup` never raises past its contract, and the new `exists` probe's timeout arm routes through `stopped()` rather than escaping. `_run` remains the only test seam (no chdir, explicit `project_root`/`repo_path`, real git fixtures with bare origins). Framework working tree clean; commit `b38d60bbc` signed and pushed.

**Deviation audit (R1 entries):** scrub inside `stopped()` — **ACCEPTED** (choke point beats call site; a future arm cannot bypass it). Probe placed with the base probe rather than immediately before the delete — **ACCEPTED** (read-only, answer cannot change across checkout/pull, and it mirrors the shape I asked for). Both are strict improvements on the fix note as written.

**Handoff:** To SM for finish-story

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T20:29:01Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T19:46:19Z | 2026-08-11T19:47:38Z | 1m 19s |
| red | 2026-08-11T19:47:38Z | 2026-08-11T19:53:31Z | 5m 53s |
| green | 2026-08-11T19:53:31Z | 2026-08-11T20:02:51Z | 9m 20s |
| review | 2026-08-11T20:02:51Z | 2026-08-11T20:16:21Z | 13m 30s |
| green | 2026-08-11T20:16:21Z | 2026-08-11T20:24:41Z | 8m 20s |
| review | 2026-08-11T20:24:41Z | 2026-08-11T20:29:01Z | 4m 20s |
| finish | 2026-08-11T20:29:01Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings

### Reviewer (code review)
- **Gap** (non-blocking): `_resolve_story_repos` degrades to the project root when a name in the story's `repos:` field matches no repos.yaml key, so a typo in `repos:` makes finish verify the WRONG repository — while a named-but-uncloned repo is now loud (162-32). Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py:664` (unknown names should be collected and reported like the uncloned arm; `test_164_12` currently pins the degrade, so the pin moves with it). *Found by Reviewer during code review.*
- **Gap** (non-blocking): step-6 cleanup runs after `gh pr merge --delete-branch` has already deleted the local branch, so `git branch -d` is a near-certain no-op in the normal flow. The step-6 chain would be clearer if it probed for the branch instead of assuming it exists. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py:1095-1121`. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **`_resolve_story_repos` returns a result object on ALL arms:** SM/TEA required the failure arm; the success and both degrade arms were wrapped too rather than returning a bare list sometimes and a dict others. Reason: TEA's `_resolved_repos()` accepts either shape, and a union return is the thing SOUL #6 exists to avoid — one shape, one unwrap at the single caller.
- **A failed `git pull` stops the cleanup chain (the `branch -d` does not run):** the spec said only "surface the return code". Reason: `stopped()` is the existing shape for "step 6 did not complete", and a delete off a base the pull never updated is refused by git anyway — running it would add a second, more confusing warning. The operator finishes by hand either way.
- **R1: `_scrub_credentials` applied inside `stopped()` rather than at the pull's call site:** the Reviewer's fix note said "before passing stderr into `stopped()`". Reason: `stopped()` is the single output shape for step 6, so scrubbing there covers the timeout arms and any arm added later; scrubbing a hand-written message is a no-op.
- **R1: the branch probe runs BEFORE the checkout/pull chain, not immediately before the delete:** it is read-only and its answer cannot change across a checkout or a pull, and placing it there keeps all probing in one block with the base probe (`:1071`) — the shape the Reviewer asked it to mirror.
- **Two assertions in `test_164_12_finish_story_no_throw_guards.py` updated to unwrap `["data"]`:** they bound to the old bare-list signature AC1 changes. Behavior pinned is identical; TEA's interface note anticipated caller adaptation. No other test touched, and no `ruff format` churn committed in that file.