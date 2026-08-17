---
story_id: "162-88"
jira_key: ""
epic: "162"
workflow: "trivial"
---
# Story 162-88: data_proxy 162-87 test-hardening: tighten test_get_git_warns_on_empty_repos_config assertion to pin 'root'; add AC2 default-fill coverage (repos.yaml entry omitting default_branch/remote_name -> base=develop/remote=origin); confirm web baseBehind type rename compiles under the web toolchain

## Story Details
- **ID:** 162-88
- **Jira Key:** (none)
- **Workflow:** trivial
- **Stack Parent:** none
- **Branch:** feat/162-88-data-proxy-test-hardening
- **PR:** #249
- **Repos:** pennyfarthing

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-08-17T19:46:54Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-17T19:09:09Z | 2026-08-17T19:10:56Z | 1m 47s |
| red (aborted — reclassified) | 2026-08-17T19:10:56Z | 2026-08-17T19:10:56Z | reclassified to trivial |
| implement | 2026-08-17T19:10:56Z | 2026-08-17T19:37:00Z | 26m 4s |
| review | 2026-08-17T19:37:00Z | 2026-08-17T19:43:42Z | 6m 42s |
| implement | 2026-08-17T19:43:42Z | 2026-08-17T19:45:08Z | 1m 26s |
| review | 2026-08-17T19:45:08Z | 2026-08-17T19:46:54Z | 1m 46s |
| finish | 2026-08-17T19:46:54Z | - | - |

### Reclassification Note
Workflow switched `tdd` -> `trivial` during the red phase. TEA established
(baseline run: 11/11 green) that all three ACs are green-on-arrival hardening of
already-correct 162-87 code, so no honest RED state exists to satisfy the `tdd`
`tests-fail` gate. Per the 1-2pt routing rule this 1pt story belongs on `trivial`
(SM -> Dev -> Reviewer). Decision confirmed by the Client. Dev owns the implement phase.

## Acceptance Criteria

AC1: Tighten the assertion in `test_get_git_warns_on_empty_repos_config` to pin the returned `'root'` value (currently under-specified).

AC2: Add default-fill coverage — a `repos.yaml` entry that omits `default_branch` and `remote_name` must resolve to `base=develop` / `remote=origin`.

AC3: Confirm the web `baseBehind` type rename (from 162-87) compiles under the web toolchain.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (review)
- **Improvement** (non-blocking, deferred → follow-up): default-fill coverage does not
  exercise the explicit-empty-string case (`default_branch: ""` / `remote_name: ""`),
  only key-absent. Both currently route through `or "develop"`/`or "origin"`, but a
  future refactor to an `is None` guard would silently break the `""` fallback. Beyond
  this story's literal AC ("omitting"), so deferred, not folded into rework.
  `test_162_87_data_proxy_polish.py:254` (reviewer-test-analyzer, medium).
- **Improvement** (non-blocking): both root-warning tests pin only the trigger word
  `"root"`, not the actionable fix text (`path '.'` / `repos.yaml`); a degraded warning
  with no operator guidance could still pass. `test_162_87_data_proxy_polish.py:316`
  (reviewer-test-analyzer, low).

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No design deviations. Implemented exactly per the Implement Guidance: test-file
  changes only, zero edits to `data_proxy.py`. (Note: guidance estimated "13/13"
  tests; actual is 12 — AC1 was a tightening of an existing test, not a new test,
  so only one net-new test was added. Not a spec deviation, a count correction.)

## Dev Assessment (rework — cycle 1)

**Verdict:** GREEN. Addressed the single blocking `[TYPE]` finding from cycle-0 review.
Commit `dbd90094d`: changed the two AC2 assertions from `entry["base"]`/`entry["remote"]`
(unsafe subscript on `total=False` keys) to `entry.get("base")`/`entry.get("remote")`.
Type-sound, internally consistent with the failure messages (which already used `.get`),
and equally strong as a mutation-probe (`None != "develop"`). No other changes.
Re-verified: `TestAC2ReposConfigContract` 3/3 PASSED, ruff clean. Deferred non-blocking
findings (empty-string edge, actionable-text pin, coupling) intentionally NOT touched.

## Dev Assessment (cycle 0)

**Verdict:** GREEN. All three ACs satisfied as green-on-arrival hardening of the
already-correct 162-87 code. No production behavior changed.

**Changes** (`pennyfarthing-dist/src/pf/tests/test_162_87_data_proxy_polish.py`, commit `5d457e81a`):
- **AC1 (162-87 F3):** tightened `test_get_git_warns_on_empty_repos_config` from the
  weak `"root" in msg or "repos" in msg` disjunction to `assert "root" in msg`,
  matching its sibling `test_get_git_warns_when_no_root_repo_among_multiple`. Closes
  the asymmetric-assertion gap so the two edge cases can no longer silently diverge.
- **AC2 (162-87 F4):** added `test_repos_yaml_entry_omitting_base_remote_defaults_develop_origin`
  + `_write_repo_omitting_base_remote` fixture. Pins the default-fill branch
  (`data_proxy.py:353-356`, `.get(...) or "develop"`/`or "origin"`) that the prior
  AC2 tests never exercised (they always supplied both keys). Mutation-probe:
  hardcoding `""` there would now fail. Non-tautological — asserts the exact
  defaulted values `base=="develop"`, `remote=="origin"`.
- **AC3:** confirmed the `baseBehind` type rename compiles. `web/src/api/types.ts:52`
  declares `baseBehind: number | null`; zero `developBehind` remain in `web/src`.

**Verification (evidence):**
- `pytest test_162_87_data_proxy_polish.py -v` → **12/12 PASSED** (baseline was 11;
  +1 new AC2 test; AC1 tightening still green). RUN_ID `162-88-dev-green`.
- `ruff check` on the changed file → **All checks passed**.
- `cd web && pnpm run typecheck` (`tsc -b --noEmit`) → **exit 0** (AC3). Required a
  one-time `pnpm install` (web `node_modules` was absent); the stray untracked
  `web/pnpm-lock.yaml` it generated was removed to keep the tree to the single test
  change. `node_modules` is gitignored.
- `git status --porcelain` → only the one test file (now committed); tree clean.
- Branch `feat/162-88-data-proxy-test-hardening` (base `develop`), pushed.

**Full-suite regression (RUN_ID `162-88-dev-fullsuite`):** 7585 passed, 1 failed, 4
skipped, 1 xfailed. The single failure —
`test_162_5_quarantine_policy::test_every_xfail_cites_a_tracking_reference` (offender
`test_162_83_toctou_decision.py`) — is PRE-EXISTING and unrelated: `git diff
--name-only develop...HEAD` shows my branch changed ONLY
`test_162_87_data_proxy_polish.py`; the checker (`test_162_5`) and offender
(`test_162_83`) are byte-identical to `develop`, so the result is deterministic on
the baseline. Same failure documented in the SM sidecar from the 162-87 run.
Report-not-block through dev-exit and downstream gates.

**Dev-exit + extension gate evidence:**
- `dev-exit`/`tests-pass` → PASS. test-suite: story file 12/12 + full suite 7585 pass
  (1 pre-existing unrelated failure, proven above). working-tree clean. branch correct.
  no-debug-code: none (no `breakpoint`/`pdb`/stray `print` in the added test/fixture).
- `pf-init-impact` → PASS. The changed file is package test source under
  `pennyfarthing-dist/src/pf/tests/`; it is NOT seeded to consumer `.pennyfarthing/`
  on `pf init`, no schema/rename/removal, no gate/config precedence change.
- `lang-review/python` → PASS. Test-only additions: fixture has a return annotation
  (`-> str`); no bare/broad `except`, no mutable defaults, no logging, no path handling,
  no silent swallow. Assertions are meaningful (exact-value pins, non-tautological).
- `review-correlation` → PASS. This story IS the correlation of the 162-87 internal
  reviewer findings F3/F4; per the 162-87 session they already map to the existing
  `python-review` check #6 (test-quality). No new checklist entry needed — an
  existing-check mapping, not a knowledge gap.

## Subagent Results

**Cycle: 0**

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | 12/12 green, ruff clean, tree clean, scope=1 file |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 4 | confirmed 0 blocking, deferred 2 (F-empty-string, F-actionable-text), dismissed 1 (coupling — established pattern), 1 was a clean confirmation (genuine mutation-probe) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | findings | 2 | confirmed 1 blocking (lines 270/274 total=False subscript — the two are one fix) |
| 7 | reviewer-security | Yes | clean | none | no secrets/injection/escape in the tmp_path fixture |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | clean | none | 13 python-review rules checked, 0 violations |

**All received:** Yes

**Working-tree audit:** `pf reviewer audit-tree` reported DIRTY, but on ORCHESTRATOR-repo
files only — `.pennyfarthing/sidecars/dev/gotchas.md` (Dev sidecar learning),
`sprint/epic-162.yaml` (bookkeeping), `sprint/context/context-story-162-88.md` (sm-setup
artifact). The REVIEWED repo `pennyfarthing/` is CLEAN (`git -C pennyfarthing
status --porcelain` empty). Known false positive (SM sidecar 162-86/162-87). `git clean
-fd` NOT run — it would delete legitimate orchestrator artifacts.

## Reviewer Assessment

**Verdict:** REJECTED

One blocking finding; the change is otherwise clean, green (12/12), and lint-clean.

**Blocking — `[TYPE]` type-unsound access on `total=False` keys (lines 270, 274):**
The new AC2 test asserts `entry["base"] == "develop"` and `entry["remote"] == "origin"`
via direct subscript. `base`/`remote` are declared `total=False` on `RepoConfig`
(`data_proxy.py:310-322`), so subscript access is type-unsound — a static checker treats
the keys as possibly-absent. Adversarially verified: (a) runtime-SAFE — `_get_repos_config`
default-fills both on every repos.yaml path (`data_proxy.py:353-356`), so the test passes;
(b) no mypy/pyright config exists in the repo, so no gate breaks TODAY; (c) but it is a real
smell IN THE DIFF — the assertion uses the UNSAFE `entry["base"]` while its OWN failure
message uses the SAFE `entry.get("base")`, and it diverges from the sibling
`test_repos_yaml_entries_carry_base_and_remote` which guards with `assert "base" in e`
before subscripting. This epic's 162-87 F1 blocker was precisely `RepoConfig` type-honesty
(SOUL #14); shipping a new honesty-hardening test that accesses those very keys
type-unsoundly is the same defect class, and the fix is 2 characters × 2 lines.
**Fix (route to implement/Dev):** change `entry["base"]` → `entry.get("base")` and
`entry["remote"]` → `entry.get("remote")` in the assertions (the failure messages already
use `.get`). Equally strong as a mutation-probe — `None != "develop"` still fails — and now
type-sound and internally consistent. Do NOT add a `"base" in entry` guard (redundant with
`.get` equality).

**Non-blocking (deferred, see Delivery Findings):** `[TEST]` missing `default_branch: ""`
explicit-empty-string edge (medium, beyond the AC's literal "omitting" — follow-up);
`[TEST]` root-warning tests pin only the trigger word, not actionable fix text (low);
`[TEST]` `_get_repos_config` direct-call coupling (low, DISMISSED — established AC2-class
pattern, behavior is otherwise only observable by mocking subprocess).

**Specialist findings incorporated:** `[TEST]` reviewer-test-analyzer (1 blocking-adjacent
mutation-probe confirmation + 3 non-blocking, adjudicated above); `[TYPE]` reviewer-type-design
(1 blocking, confirmed first-hand); `[SEC]` reviewer-security (clean — benign tmp_path
fixture, no secret/injection/escape); `[RULE]` reviewer-rule-checker (clean — 13 python-review
rules, 0 violations); reviewer-preflight (green/clean). Disabled specialists
`[EDGE][SILENT][DOC][SIMPLE]` covered first-hand: no unhandled paths (test-only, no branches
added), no swallowed errors (no try/except), docstrings accurate incl. the `data_proxy.py:353-356`
line reference (verified current), no over-engineering (fixture mirrors the file's three
existing `_write_*` helpers).

**Rule Compliance:** python-review checklist — silent-exceptions (n/a), mutable-defaults
(pass), type-annotations (pass — fixture `-> str`, test `-> None`), logging (n/a),
path-handling (pass — pathlib + explicit `encoding="utf-8"`), test-quality (pass — meaningful
non-vacuous assertions, genuine mutation-probe), resource-leaks (pass — `write_text`),
deserialization (n/a), async (n/a), imports (n/a). 0 violations. The blocking finding is a
type-soundness/consistency issue not enumerated as a hard checklist rule but weighted under
SOUL #14 given the epic's contract-honesty theme.

## Subagent Results

**Cycle: 1**

Targeted re-verification of the single cycle-0 blocking finding — NOT a fresh subagent
sweep (the cycle-0 characterization was precise, so a targeted probe is the stronger
evidence per the re-review protocol). No specialist subagents re-spawned this cycle; each
enabled specialist's cycle-0 result carries forward (the 2-line accessor swap cannot affect
their domains), re-verified first-hand against the rework diff.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (cycle-0, re-verified) | clean | none | 12/12 green + ruff clean re-confirmed on rework `dbd90094d` |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings; assessed first-hand — no branches added |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings; assessed first-hand — no error handling |
| 4 | reviewer-test-analyzer | Yes (cycle-0, re-verified) | findings | 4 | deferred 2 (still open), dismissed 1 (coupling), 1 clean confirmation; unaffected by the accessor swap |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings; assessed first-hand — no doc drift |
| 6 | reviewer-type-design | Yes (cycle-0, re-verified) | findings | 2 | the 1 blocking finding is now FIXED (`.get()`); re-verified against `dbd90094d` |
| 7 | reviewer-security | Yes (cycle-0, re-verified) | clean | none | benign tmp_path fixture unchanged |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings; assessed first-hand — no added complexity |
| 9 | reviewer-rule-checker | Yes (cycle-0, re-verified) | clean | none | 13 python-review rules, 0 violations; `.get()` swap introduces none |

**All received:** Yes

**Re-verification evidence (rework commit `dbd90094d`):**
- `git show dbd90094d` → diff is EXACTLY the two swaps `entry["base"]` → `entry.get("base")`
  and `entry["remote"]` → `entry.get("remote")`; nothing else changed.
- `pytest test_162_87_data_proxy_polish.py -q` → **12 passed**.
- Mutation-probe strength preserved: `entry.get("base") == "develop"` still fails on
  `None`/`""`/`"main"`, so the fix is type-sound AND equally strong.
- Reviewed repo `pennyfarthing/` clean; `pf reviewer audit-tree` exit 0.

## Reviewer Assessment

**Verdict:** APPROVED

The single cycle-0 blocking `[TYPE]` finding is resolved (commit `dbd90094d`): the two AC2
assertions now use the type-sound `entry.get(...)` accessor, consistent with their own
failure messages and the sibling test's guarded pattern, with mutation-probe strength
intact. No other changes; no new findings introduced by the 2-line edit. Full file 12/12
green, ruff clean, reviewed tree clean.

**Specialist findings incorporated:** `[TYPE]` cycle-0 blocker CONFIRMED FIXED via targeted
re-verification (diff re-read + test re-run — no fresh sweep, per re-review protocol);
`[TEST]` `[SEC]` `[RULE]` cycle-0 results stand (nothing in the 2-line accessor change
could affect them); `[EDGE][SILENT][DOC][SIMPLE]` (disabled) — the rework adds no branches,
no error handling, no doc drift, no complexity. Non-blocking deferrals (empty-string edge →
follow-up; actionable-text pin; coupling) remain as recorded in Delivery Findings, correctly
NOT pulled into this cycle.

## SM Assessment

Follow-up to 162-87's `data_proxy` review (F3/F4 deferrals). Scope is test-hardening plus one type-compile confirmation — no production-behavior change intended.

Routing: 1pt p1 `tdd` (phased). Setup → red (TEA) → green (Dev) → review (Reviewer) → finish (SM). Base branch for `pennyfarthing` is `develop`.

TEA baseline finding (informs the reclassification): the 162-87 test file runs 11/11
GREEN and production behavior is already correct for all three ACs, so this is
green-on-arrival hardening — see the Reclassification Note above.

## Implement Guidance (Dev — trivial implement phase)

All three ACs are green-on-arrival hardening of already-correct 162-87 code. This is
NOT a behavior change; do NOT modify `data_proxy.py`. If any pin FAILS against current
production, STOP and report — that would be a real regression, not expected.

Target test file: `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_87_data_proxy_polish.py`
(pennyfarthing repo, branch `feat/162-88-data-proxy-test-hardening`, base `develop`).

- AC1 (162-87 F3): tighten `test_get_git_warns_on_empty_repos_config`. Its assertion is
  the weak `"root" in messages.lower() or "repos" in messages.lower()` disjunction —
  asymmetrically weaker than its sibling `test_get_git_warns_when_no_root_repo_among_multiple`,
  which pins `"root"` only. Change it to `assert "root" in messages.lower()` and update the
  message to cite 162-88/F3. The empty-`repos: {}` warning already contains "root", so this
  stays green — the point is closing the divergence between the two edge-case assertions.

- AC2 (162-87 F4): add default-fill coverage in `TestAC2ReposConfigContract`. Add a fixture
  that writes a `repos.yaml` entry OMITTING both `default_branch` and `remote_name`, then
  assert `data_proxy._get_repos_config(project)` returns an entry with `base == "develop"`
  and `remote == "origin"`. Mutation-probe framing: a regression hardcoding `""` (instead of
  `.get(...) or "develop"`/`or "origin"`, data_proxy.py:353-356) would fail this. The existing
  AC2 tests always supply both keys, so this default-fill branch is currently untested.

- AC3: confirm the web `baseBehind` type rename compiles. Run the web typecheck:
  `cd pennyfarthing/web && (pnpm typecheck || npm run typecheck)` (script: `tsc -b --noEmit`).
  `web/src/api/types.ts:52` already declares `baseBehind: number | null` and there is zero
  `developBehind` left in `web/src` — green-on-arrival; log the typecheck result as evidence.

Verify: run the full `test_162_87_data_proxy_polish.py` file (should be 13/13 green after the
two additions) + ruff on the changed test file + the web typecheck. Commit
`test: 162-88 data_proxy hardening (162-87 F3/F4 tighten + default-fill)`.