---
story_id: "155-11"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-11: sm-finish runs pf.* with project .venv -> ModuleNotFoundError + subagent retry storm (gh #112)

## Story Details
- **ID:** 155-11
- **Jira Key:** (none)
- **Epic:** 155 (Finish/merge/archive truthfulness)
- **Workflow:** tdd
- **Type:** bug
- **Points:** 2
- **Priority:** p2
- **Repo:** pennyfarthing
- **Branch:** fix/155-11-sm-finish-venv

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-30T21:09:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-30T20:45:17Z | 2026-07-30T20:47:17Z | 2m |
| red | 2026-07-30T20:47:17Z | 2026-07-30T20:55:46Z | 8m 29s |
| green | 2026-07-30T20:55:46Z | 2026-07-30T21:00:30Z | 4m 44s |
| review | 2026-07-30T21:00:30Z | 2026-07-30T21:09:00Z | 8m 30s |
| finish | 2026-07-30T21:09:00Z | - | - |

## Story Context

### Technical Background

The `sm-finish.md` agent template invokes Pennyfarthing Python helpers with the **project's** `.venv`:

```bash
source .venv/bin/activate && python -m pf.preflight finish ...
source .venv/bin/activate && python -c "from pf.findings.summary import ..."
python3 -c "from pf.git.repos import get_repo_config; ..."
```

When Pennyfarthing is installed as a **uv tool** (the documented setup), the `pf` package lives in the tool's isolated venv at `~/.local/share/uv/tools/pf/` — NOT in the project's `.venv`. On projects whose `.venv` is application-specific (e.g., FastAPI orchestrator, SideQuest), `python -m pf.*` and `from pf... import` fail immediately with:

```
ModuleNotFoundError: No module named 'pf'
```

### Observed Impact

The `sm-finish` subagent (haiku model) doesn't fail fast. Instead, it retries venv activation, path manipulation, and interpreter variations — burning ~30 tool calls in a visible thrashing loop before giving up. The preflight and Impact Summary steps never execute.

### Root Cause

The template assumes `pf` is importable from the project's `.venv`. This is only true when Pennyfarthing is `pip install`-ed into the same environment — not the uv-tool installation path.

### Acceptance Criteria

1. **AC1:** Extract the `pf` CLI interpreter from the launcher shebang: `PF_PY="$(sed -n '1s/^#!//p' "$(command -v pf)")"`
2. **AC2:** Replace all `pf.*` invocation sites in `sm-finish.md` to use `$PF_PY` instead of sourcing `.venv`:
   - `pf.common.pr_config` 
   - `pf.preflight finish`
   - `pf.findings.summary.write_impact_summary_to_session`
   - `pf.git.repos` (get_repo_config, format_pr_title)
   - Any other `pf.*` module imports
3. **AC3:** Each bash fence deriving `PF_PY` is self-contained (re-derive if in separate fence) since subagents may run fences independently
4. **AC4:** Test coverage: verify the fix works on a project whose `.venv` does NOT contain the `pf` package (e.g., SideQuest or a fresh test project)
5. **AC5:** Confirm no regressions on projects where `pf` IS installed in the `.venv` (fallback case)

## Delivery Findings

No upstream findings at setup time.

### TEA (test design)
- **Gap** (non-blocking): The same project-`.venv` pf.* invocation class exists in three sibling templates: `sm-setup.md` L106 (`python3 -c "from pf.jira.client import is_jira_enabled..."`) and L273 (`from pf.git.repos import get_repo_config`), `testing-runner.md` L86 (`python -m pf.session.test_cache`), and `commands/pf-standalone.md` L150 (`source .venv/bin/activate && python -c "from pf.git.repos import format_pr_title..."`).
  Affects `pennyfarthing-dist/agents/sm-setup.md`, `pennyfarthing-dist/agents/testing-runner.md`, `pennyfarthing-dist/commands/pf-standalone.md` (each needs the same PF_PY derivation — follow-up sweep story, out of 155-11 scope which the session pins to sm-finish.md).
  *Found by TEA during test design.*
- **Improvement** (non-blocking): `sm-finish.md` has duplicate section numbering — two `## 3.` headings (L86 "Compile Impact Summary", L106 "Run Preflight Script").
  Affects `pennyfarthing-dist/agents/sm-finish.md` (renumber while Dev is editing the file anyway).
  *Found by TEA during test design.*
- **Question** (non-blocking): gh #112's "secondary issue" (finish completes ceremony over a CONFLICTING PR) is already covered by shipped story 155-12 (`test_155_12_finish_conflicting_pr.py`) — Reviewer may want to confirm the issue comment gets updated so it isn't refiled.
  Affects `gh issue #112` (comment/close-scope note only).
  *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): TEA's AC4 fixture pointed the fake launcher shebang at `sys.executable`, which under `uv run pytest` is a uv-managed homebrew python WITHOUT pf — the linchpin AC4 import test silently skipped in the primary dev environment. Fixed the fixture (assertions unchanged): `_pf_capable_interpreter()` prefers the dist dev venv python, falls back to `sys.executable`, skips only if neither can import pf.
  Affects `pennyfarthing-dist/src/pf/tests/test_155_11_sm_finish_pf_py.py` (fixture interpreter selection — done in this story).
  *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): Add a fail-loud guard after each PF_PY derivation — `: "${PF_PY:?pf launcher not found on PATH or has no shebang}"` — so a missing/shebang-less `pf` fails with an actionable message instead of an opaque `: command not found` (the residual thrash-class edge). Fold into the sibling-template sweep story so the guard ships uniformly.
  Affects `pennyfarthing-dist/agents/sm-finish.md` L25/L38/L99/L117 (one guard line per fence; TEA's tests are guard-compatible — the guard line contains `PF_PY` and is not an assignment).
  *Found by Reviewer during code review.*
- **Improvement** (non-blocking): The three static tests in `TestNoProjectVenvInvocation` lack the `assert _bash_fences()` / `assert _pf_exec_fences()` non-empty guards that `TestFenceSelfContainment` has — if the fence regex ever stops matching (e.g. fence tag change), those three pass vacuously. The suite as a whole still fails loudly (the self-containment test's guard catches it), so this is consistency hardening, not a live hole.
  Affects `pennyfarthing-dist/src/pf/tests/test_155_11_sm_finish_pf_py.py` (add the guard to the three tests or factor into a fixture).
  *Found by Reviewer during code review.*
- **Gap** (non-blocking): Pre-existing CWE-94-class interpolation in the PR_TITLE fence: `format_pr_title(jira_key='${JIRA_KEY:-$STORY_ID}', title='${title}', scope='${scope}')` splices bash vars into Python string literals inside the `-c` payload — a single quote in a story title breaks out into code. Identical pattern pre-dates this diff (interpreter swap didn't widen it) and recurs in `commands/pf-standalone.md` L150. Fix shape: pass values via argv or JSON-on-stdin.
  Affects `pennyfarthing-dist/agents/sm-finish.md` L36, `pennyfarthing-dist/commands/pf-standalone.md` (fold into the sibling-sweep/hardening follow-up).
  *Found by Reviewer during code review.*
- **Question** (non-blocking): Optional hardening for the PATH-lookup surface (`command -v pf`): a `pf --print-python` subcommand would make interpreter resolution first-party instead of shebang-parsing. Worth weighing when the sibling sweep lands; the current derivation is baseline-equivalent (every `pf` invocation framework-wide is already a PATH lookup).
  Affects `pennyfarthing-dist/src/pf/` CLI (new subcommand, then templates use it).
  *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

6 deviations

- **AC record lives in the test-file docstring**
  - Rationale: Keeps the spec adjacent to the tests that enforce it; the context file explicitly delegates AC authorship to TEA.
  - Severity: minor
  - Forward impact: Reviewer should treat the test docstring as the AC source.
- **AC5 (pip-install-in-.venv regression) has no dedicated test**
  - Rationale: A dedicated fixture (a real venv with pf pip-installed) costs a full venv build for no additional discriminating power.
  - Severity: minor
  - Forward impact: none; Reviewer may override and request the heavier fixture.
- **Quoting enforcement tightened beyond issue text**
  - Rationale: lang-review #5 (path handling) — enforces the quoting the issue snippet already carries, mechanically.
  - Severity: minor
  - Forward impact: Dev must keep the inner `"$(command -v pf)"` quotes at every site.
- **AC4 test carries an environment skip-guard**
  - Rationale: Avoids a false-red in exotic runner environments; in the repo dev env the guard never fires (probed: imports OK).
  - Severity: minor
  - Forward impact: none.
- **AC4 skip-guard replaced with pf-capable interpreter selection**
  - Rationale: A linchpin test that always skips where the suite actually runs is vacuous; the fixture change models the uv-tool venv more faithfully and keeps every assertion intact.
  - Severity: minor
  - Forward impact: none — skip remains only for genuinely pf-less environments.
- **Duplicate section numbering fixed alongside**
  - Rationale: One-character doc fix in the file under edit; no behavior change.
  - Severity: minor
  - Forward impact: none.

## Design Deviations

No deviations from the issue spec at setup time.

### TEA (test design)
- **AC record lives in the test-file docstring**
  - Spec source: context-story-155-11.md, "Acceptance Criteria"
  - Spec text: "No acceptance criteria recorded in the sprint YAML — TEA to define during the RED phase."
  - Implementation: The authoritative AC record (AC1–AC5) is the module docstring of `test_155_11_sm_finish_pf_py.py`, derived from the session ACs + gh #112.
  - Rationale: Keeps the spec adjacent to the tests that enforce it; the context file explicitly delegates AC authorship to TEA.
  - Severity: minor
  - Forward impact: Reviewer should treat the test docstring as the AC source.
- **AC5 (pip-install-in-.venv regression) has no dedicated test**
  - Spec source: session file AC5
  - Spec text: "Confirm no regressions on projects where `pf` IS installed in the `.venv` (fallback case)"
  - Implementation: Covered implicitly — the AC1 test proves the PF_PY derivation never consults CWD/`.venv` (decoy `.venv` present, result unaffected), so project-venv contents are irrelevant in both directions.
  - Rationale: A dedicated fixture (a real venv with pf pip-installed) costs a full venv build for no additional discriminating power.
  - Severity: minor
  - Forward impact: none; Reviewer may override and request the heavier fixture.
- **Quoting enforcement tightened beyond issue text**
  - Spec source: gh #112 "Suggested fix"
  - Spec text: `PF_PY="$(sed -n '1s/^#!//p' "$(command -v pf)")"`
  - Implementation: The fake launcher lives in a directory containing a space ("tool bin"), so an unquoted `$(command -v pf)` fails the derivation test.
  - Rationale: lang-review #5 (path handling) — enforces the quoting the issue snippet already carries, mechanically.
  - Severity: minor
  - Forward impact: Dev must keep the inner `"$(command -v pf)"` quotes at every site.
- **AC4 test carries an environment skip-guard**
  - Spec source: session file AC4
  - Spec text: "verify the fix works on a project whose `.venv` does NOT contain the `pf` package"
  - Implementation: If the test runner's own interpreter cannot `import pf`, the AC4 import test skips (the fake-launcher fixture points its shebang at that interpreter, so the check cannot be hosted).
  - Rationale: Avoids a false-red in exotic runner environments; in the repo dev env the guard never fires (probed: imports OK).
  - Severity: minor
  - Forward impact: none.

### Dev (implementation)
- **AC4 skip-guard replaced with pf-capable interpreter selection**
  - Spec source: TEA Design Deviations, "AC4 test carries an environment skip-guard"
  - Spec text: "If the test runner's own interpreter cannot `import pf`, the AC4 import test skips"
  - Implementation: The guard fired in the primary dev env (`uv run pytest` → sys.executable is a uv-managed python without pf), permanently skipping the AC4 proof. Replaced with `_pf_capable_interpreter()` (dist venv python → sys.executable → skip), so AC4 executes here: 6/6 pass, 0 skipped.
  - Rationale: A linchpin test that always skips where the suite actually runs is vacuous; the fixture change models the uv-tool venv more faithfully and keeps every assertion intact.
  - Severity: minor
  - Forward impact: none — skip remains only for genuinely pf-less environments.
- **Duplicate section numbering fixed alongside**
  - Spec source: TEA Delivery Findings, Improvement (duplicate `## 3.` headings)
  - Spec text: "renumber while Dev is editing the file anyway"
  - Implementation: Second `## 3.` (Run Preflight Script) renumbered to `## 4.`.
  - Rationale: One-character doc fix in the file under edit; no behavior change.
  - Severity: minor
  - Forward impact: none.

### Reviewer (audit)
- TEA "AC record lives in the test-file docstring" → ✓ ACCEPTED by Reviewer: context file explicitly delegated AC authorship; docstring is thorough and the tests match it.
- TEA "AC5 has no dedicated test" → ✓ ACCEPTED by Reviewer: AC1's decoy-venv fixture proves derivation is CWD/.venv-independent in both directions; a pip-installed fixture adds no discriminating power.
- TEA "Quoting enforcement tightened beyond issue text" → ✓ ACCEPTED by Reviewer: space-in-dir launcher mechanically enforces the quoting the issue snippet carries; test-analyzer confirmed the value assertion (not returncode) is what catches unquoted forms — genuine enforcement, not theater.
- TEA "AC4 test carries an environment skip-guard" → ✓ ACCEPTED by Reviewer as historical record: superseded in the same story by Dev's fixture fix (below); the entry accurately describes round-1 design.
- Dev "AC4 skip-guard replaced with pf-capable interpreter selection" → ✓ ACCEPTED by Reviewer: verified 6 passed / 0 skipped in the primary env; assertions unchanged; a linchpin test that always skips where the suite runs would have been vacuous (test-analyzer independently flagged the skip semantics). Residual: in a hypothetical env with no pf-capable interpreter AC4 still skips silently — noted in Delivery Findings alongside the fence-guard hardening.
- Dev "Duplicate section numbering fixed alongside" → ✓ ACCEPTED by Reviewer: one-character doc fix answering TEA's Improvement finding; no behavior change.

## Sm Assessment

**Story Ready:** Yes

**Technical Assessment:**
- Bug is well-characterized in gh #112 with clear root cause and tested fix approach
- Solution is low-risk: extracting PF_PY from the tool shebang works across all Pennyfarthing installations
- Identified call sites are mechanical replacements (no logic changes)
- Scope is confined to `pennyfarthing-dist/agents/sm-finish.md`

**Effort:** 2 pts is appropriate for shebang parsing + template edits + test validation on reference projects

**Dependencies:** None blocking; orthogonal to finish-truthfulness flow improvements (155-1 through 155-10 are complete)

**Context Confidence:** High — issue reporter (Keith) has verified the fix on SideQuest; solution is already deployed there.

**Recommended approach:** 
- TEA will write test case covering a project with isolated `.venv` 
- Dev will apply shebang extraction + template rewrites
- Reviewer will validate on both uv-tool and pip-install setups

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_11_sm_finish_pf_py.py` — static fence guards + behavioral PF_PY-derivation contract for the sm-finish template (new)

**Tests Written:** 6 tests covering 5 ACs (AC record in the test-file docstring; AC5 covered implicitly — see Design Deviations)
**Status:** RED (6 failed, 0 errored, all assertion-level — verified by direct scoped run AND testing-runner RUN_ID 155-11-tea-red)

**Test design:**
- Static guards (fix-agnostic, parse the template's ```bash fences): no `source .venv/bin/activate` in any fence; no bare `python`/`python3 -m|-c` executing pf.* code; every pf-executing line routes through `$PF_PY`; every pf-executing fence derives `PF_PY=` locally (AC3 self-containment — subagents run fences independently).
- Behavioral contract (executes the template's own `PF_PY=` assignment lines in bash): a fake uv-tool `pf` launcher (shebang → real interpreter) in a dir **containing a space**, CWD = a decoy project whose `.venv/bin/python` always ModuleNotFoundErrors. Every assignment must resolve to the launcher's shebang interpreter, and that interpreter must import all four template modules (`pf.common.pr_config`, `pf.findings.summary`, `pf.git.repos`, `pf.preflight`).
- Green-simulation run: applied the gh-#112 suggested fix to a scratch copy of the template and ran this suite against it — passes. The contract is satisfiable exactly as designed.

**Designed interface for Dev (B.A.):** per pf-executing fence, add
`PF_PY="$(sed -n '1s/^#!//p' "$(command -v pf)")"`
and route all five call sites (`pr_config`, `get_repo_config`, `format_pr_title`, `write_impact_summary_to_session`, `preflight finish`) through `"$PF_PY"`. Keep the inner `"$(command -v pf)"` quotes — the space-in-dir test enforces them. Scope is `pennyfarthing-dist/agents/sm-finish.md` only; sibling templates are a filed follow-up Gap.

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #5 path handling/quoting | `test_derivation_resolves_launcher_shebang` (space-in-dir launcher) | failing |
| #6 test quality | self-check pass: every test asserts on offender lists/derived values; no vacuous asserts; ruff clean | done |
| #13 fix-introduced regressions | `test_pf_exec_fences_derive_pf_py_locally` (AC3), decoy-venv independence (AC5 implicit) | failing |
| #1,2,3,4,7–12 | N/A — diff is a markdown agent template + tests; no runtime Python source touched | n/a |

**Rules checked:** 3 of 3 applicable lang-review rules have coverage
**Self-check:** 0 vacuous tests found

**Handoff:** To Dev (B.A. Baracus) for implementation

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/agents/sm-finish.md` — all 4 pf-executing bash fences now derive `PF_PY="$(sed -n '1s/^#!//p' "$(command -v pf)")"` locally and route all five call sites (`pr_config`, `get_repo_config`, `format_pr_title`, `write_impact_summary_to_session`, `preflight finish`) through `"$PF_PY"`; no `source .venv/bin/activate` remains; a constraint comment explains WHY at the first derivation; duplicate `## 3.` heading renumbered to `## 4.`
- `pennyfarthing-dist/src/pf/tests/test_155_11_sm_finish_pf_py.py` — fixture fix only (see Dev deviation): fake-launcher shebang now uses a pf-capable interpreter so AC4 actually executes; all assertions unchanged

**Tests:** 6/6 passing, 0 skipped (GREEN — was 5 pass + 1 silent skip before the fixture fix)
**Regression:** 125 passed (agent-template parsers: test_143_12, test_141_20, test_validate_agent_models; finish-flow: test_155_1, test_155_12). `ruff check` clean.
**Live smoke (real uv-tool install, the gh #112 scenario):** `PF_PY` derived → `~/.local/share/uv/tools/pennyfarthing-scripts/bin/python`; all four modules import; the exact template command `PR_MODE=$("$PF_PY" -m pf.common.pr_config)` returns `draft` from the orchestrator root.
**Branch:** fix/155-11-sm-finish-venv (pushed)

**Handoff:** To Reviewer (Colonel Lynch) for code review
## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 6/6 green, tree clean, no smells |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly by Reviewer (empty `command -v`, env-style shebang, `${JIRA_KEY:-$STORY_ID}` default; see assessment) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — covered directly: no `2>/dev/null`/`|| true`/swallows added; step-3 log-and-continue is pre-existing documented non-blocking behavior |
| 4 | reviewer-test-analyzer | Yes | findings | 5 | confirmed 5 (3 high→MEDIUM deferred, 1 medium→LOW noted, 1 low noted); 0 dismissed |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — covered directly: WHY comment accurate, heading renumber fixes stale numbering, no stale docs |
| 6 | reviewer-type-design | Yes | findings | 3 | confirmed 3 (PF_PY guard high→MEDIUM deferred; negative-path tests medium→deferred; annotations low noted — rule #3 exempts test methods per rule-checker, kept as LOW cosmetic) |
| 7 | reviewer-security | Yes | findings | 4 | confirmed 4 (CWE-426 med→LOW baseline-equivalent; CWE-94 title interpolation med→MEDIUM deferred pre-existing; test bash -c low noted; STORY_ID path low noted) — 0 dismissed |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — covered directly: per-fence duplication is AC3-mandated (rule-checker concurs); no over-engineering in tests |
| 9 | reviewer-rule-checker | Yes | clean | none | N/A — 16 rules, 61 instances, 0 violations; judgment calls on SOUL #2 (AC3-justified duplication) and SOUL #10 (pytest helper assert idiom) reviewed and endorsed |

**All received:** Yes (5 returned, 4 disabled with domains covered directly)
**Total findings:** 12 confirmed, 0 dismissed, 0 deferred-without-decision

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `{STORY_ID}/{BRANCH}/{JIRA_KEY}` placeholders → haiku agent interpolates into fence → `"$PF_PY" -m pf.preflight finish ...` argv (same surface as before the diff; the PF_PY derivation itself consumes no user input — `command -v pf` → launcher shebang → interpreter path, quoted end-to-end). Safe because no new interpolation sink was added and the one pre-existing sink (`'${title}'`) is captured as a deferred finding.

**Pattern observed:** Per-fence self-contained derivation (sm-finish.md:25,38,99,117) — deliberate AC3-mandated duplication because subagents execute fences independently; endorsed over a DRY refactor ([RULE] rule-checker SOUL-#2 judgment concurs).

**Error handling:** Derivation is quoted against space-bearing paths (proven by the "tool bin" fixture); residual empty-PF_PY edge (pf absent from PATH — unreachable in a pf-orchestrated session, since SM just ran `pf` to spawn this subagent) fails loud-but-opaque → `${PF_PY:?}` guard deferred to the sibling sweep ([TYPE] confirmed MEDIUM non-blocking).

**Verification performed:**
- [VERIFIED] Fix eliminates the gh #112 class — grep: zero `source .venv`/bare-python-pf invocations remain in sm-finish.md; all 5 call sites route through `"$PF_PY"`; complies with lang-review #13 (no leftover same-class instances in-file). Evidence: rule-checker #13 grep + my own `grep -n "\.venv|python"` (one explanatory comment is the only hit).
- [VERIFIED] Inverse-binding probe — template reverted to origin/develop with test file kept: exactly 6 failed (predicted 6); restored: 6 passed, `git status` clean, 9 PF_PY refs back. Tests bind to the fix.
- [VERIFIED] Live uv-tool proof — Dev's smoke re-checked: `PF_PY` derives to `~/.local/share/uv/tools/pennyfarthing-scripts/bin/python`; `PR_MODE=$("$PF_PY" -m pf.common.pr_config)` → `draft` from orchestrator root. The exact gh #112 scenario works.
- [VERIFIED] Quoting enforcement is real, not theater — [TEST] test-analyzer traced that the unquoted-mutation is caught by the value assertion (bash lacks set -e so returncode alone would miss it); the space-in-dir fixture drives it. Complies with lang-review #5.
- [VERIFIED] Regression surface — 125 passed across agent-template parsers (test_143_12, test_141_20, test_validate_agent_models) + finish-flow (test_155_1, test_155_12); ruff clean ([SIMPLE]/[SILENT]/[DOC]/[EDGE] domains checked directly, disabled subagents' rows honest).

**Findings (all non-blocking):**
| Severity | Tag | Issue | Location | Route |
|----------|-----|-------|----------|-------|
| [MEDIUM] | [TYPE] | No `${PF_PY:?}` non-empty guard after derivation (opaque failure if pf off PATH / no shebang / env-style shebang) | sm-finish.md:25,38,99,117 | Delivery Finding → sibling-sweep follow-up |
| [MEDIUM] | [TEST] | 3 static tests lack non-empty fence guards (suite-level guard exists in self-containment test, so no silent-vacuous risk today) | test_155_11:175,185,198 | Delivery Finding → same follow-up |
| [MEDIUM] | [SEC] | Pre-existing `'${title}'` CWE-94 interpolation into `-c` literal (unchanged by diff; recurs in pf-standalone.md) | sm-finish.md:36 | Delivery Finding → hardening follow-up |
| [LOW] | [SEC] | CWE-426 PATH lookup for `pf` — baseline-equivalent to every framework `pf` invocation; old `.venv` sourcing was more attacker-adjacent | sm-finish.md:25 | noted; `pf --print-python` idea recorded |
| [LOW] | [TEST] | AC4 skips silently in envs with no pf-capable interpreter (none known; repo has no CI) | test_155_11:259 | noted |
| [LOW] | [TYPE] | Test methods lack `-> None`/`tmp_path: Path` annotations (repo convention mixed; rule #3 exempts non-boundary functions) | test_155_11 | noted, cosmetic |
| [LOW] | [EDGE] | env-style shebang (`#!/usr/bin/env python3`) would produce a two-token PF_PY that fails closed — not produced by uv/pipx/pip installers | sm-finish.md:25 | noted with guard deferral |

### Rule Compliance
Mapped to `.pennyfarthing/gates/lang-review/python.md` (rule-checker exhaustive sweep, 61 instances, cross-checked by me):
- #1 silent-exceptions: compliant — no try/except in tests; no `|| true`/`2>/dev/null` in fences. [RULE]
- #2 mutable-defaults: compliant (8 helpers checked). #3 annotations: compliant at boundaries; test methods exempt (LOW cosmetic note). #4 logging: N/A.
- #5 path-handling: compliant — pathlib + `encoding="utf-8"` throughout; fence quoting proven by fixture. [RULE]/[SEC]
- #6 test-quality: compliant per rule-checker; test-analyzer's sharper empirical pass found the 3 missing non-empty guards — **Challenged:** empirical analysis overrides checklist pattern-match, finding stands as MEDIUM deferred (suite-level guard prevents a live hole).
- #7 resource-leaks / #8 unsafe-deserialization: compliant — one-shot subprocess.run, list-form argv, `bash -c` payload sourced from the repo's own template (trust boundary bounded by repo write access). #9 async / #12 deps: N/A. #10 imports / #11 input-validation: compliant.
- #13 fix-regressions: compliant — zero leftover `.venv`/bare-python-pf instances in the fixed file; no new bug class introduced. Sibling files (sm-setup.md, testing-runner.md, pf-standalone.md) carry the class — already TEA's filed Gap, endorsed.
- SOUL #2: per-fence duplication AC3-justified. SOUL #10: pytest-helper assert idiom accepted. SOUL #14: 6/6 proven behaviorally + live smoke + binding probe.

### Devil's Advocate
Suppose this is broken. The nastiest attack: the haiku subagent runs a fence in a cwd where PATH resolves `pf` to something unexpected — a direnv-prepended project bin with a stale shim, say. Then PF_PY is a wrong-but-real interpreter and `-m pf.common.pr_config` either ModuleNotFoundErrors (right back to thrashing) or executes a different pf install's code. How likely? The shim would have to be named `pf`, be on PATH ahead of the real tool, and carry a shebang — at which point every `pf sprint`/`pf handoff` call in the whole session already routed through that same shim; the derivation inherits the session's existing trust in PATH, it doesn't extend it. The old code trusted something strictly worse: whatever `.venv/bin/activate` the current directory happened to contain. Second attack: a story title like `'); import os; os.system('...` reaching the PR_TITLE fence — real, pre-existing, and now recorded as a deferred finding rather than silently carried. Third: the fence regex rots when someone reformats the template, and three of six tests go quiet — but the self-containment test's `assert fences` fails loudly on that exact rot, so the suite degrades to noisy, not silent. Fourth: a consumer installs pf via some exotic wrapper whose launcher has an env-style shebang; the fence fails closed with "No such file or directory" — worse UX than today? No: today that consumer gets ModuleNotFoundError thrash. Every residual edge I can construct is either fail-closed, baseline-equivalent, or already ledgered. What would actually reintroduce gh #112 — a bare `python -m pf.x` creeping back — is exactly what the static tests pin. I could not construct a scenario that blocks this PR.

**Observations count:** 6 VERIFIED + 7 findings = 13 (≥5 satisfied). Tenant isolation: N/A (no tenant-bearing types in diff). Wiring: template consumed via `.claude/agents` symlink → source edit propagates immediately (dogfood symlink model).

**Handoff:** To SM (Faceman) for finish-story — PR creation, merge, ceremony.