---
story_id: "162-8"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-8: Sibling-template PF_PY sweep: sm-setup, testing-runner, pf-standalone still run pf.* via project .venv; add ${PF_PY:?} fail-loud guards uniformly (155-11 follow-up)

## Story Details
- **ID:** 162-8
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-8-pf-py-template-sweep
- **PR:** #180

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-05T17:11:09Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-05T15:27:36Z | 2026-08-05T15:29:02Z | 1m 26s |
| red | 2026-08-05T15:29:02Z | 2026-08-05T16:00:13Z | 31m 11s |
| green | 2026-08-05T16:00:13Z | 2026-08-05T16:10:42Z | 10m 29s |
| review | 2026-08-05T16:10:42Z | 2026-08-05T16:41:35Z | 30m 53s |
| green | 2026-08-05T16:41:35Z | 2026-08-05T16:48:41Z | 7m 6s |
| review | 2026-08-05T16:48:41Z | 2026-08-05T17:11:09Z | 22m 28s |
| finish | 2026-08-05T17:11:09Z | - | - |

## Sm Assessment

**Scope:** 2-pt p2 bug, TDD, 155-11 follow-up. 155-11 established the `${PF_PY:?}` fail-loud pattern for templates invoking `python -m pf.*` — no silent fallback to a project `.venv` python. This story sweeps the sibling templates that still do it: `sm-setup` (agents/), `testing-runner` (agents/), `pf-standalone` (commands/ or skills/), plus any other offender in `pennyfarthing-dist/` (agents/, commands/, skills/, templates/, scripts/).

**Technical approach for TEA:** Find the 155-11 template-lint test suite (`test_155_11*`) and its guard-shape convention. Extend it to cover the sibling templates: a failing test per offender asserting every `pf.*` invocation goes through the `${PF_PY:?...}` guard shape (or the suite's equivalent policy check across ALL dist templates — prefer a sweep-proof policy test over per-file pins so future templates can't regress). Then confirm the named files currently FAIL it.

**Acceptance criteria:**
1. sm-setup, testing-runner, pf-standalone (and any other found offender) use the uniform `${PF_PY:?}` guard for every pf.* invocation — no `.venv/bin/python` or bare `python` fallbacks.
2. Policy test covers all dist templates so new offenders fail CI.
3. Suite stays exit 0 (only the 7 loud 162-5 xfails).

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### TEA (test design)
- **Gap** (non-blocking): `agents/sm-finish.md` — the file 155-11 supposedly fixed — is itself an offender under the uniform fail-loud rule. It derives PF_PY correctly but expands it as plain `"$PF_PY"`. When `pf` is not on PATH the derivation leaves PF_PY empty and the invocation becomes an empty argv[0], i.e. a bare "command not found" instead of a diagnosis. Affects `pennyfarthing-dist/agents/sm-finish.md` (5 invocation lines need the fail-loud expansion). *Found by TEA during test design.*
- **Gap** (non-blocking): `scripts/hooks/pre-commit.sh` runs `pf.sprint.validate_cmd` on a bare `python3` resolved from PATH, with a PYTHONPATH fallback, and skips validation entirely when no python is found. It is a git hook that must degrade gracefully on machines without pf installed, so forcing the fail-loud guard there would break the graceful path. Deliberately left out of the policy sweep (shell scripts are code, not templates). Affects `pennyfarthing-dist/scripts/hooks/pre-commit.sh` — worth its own story to decide the hook's contract. *Found by TEA during test design.*
- **Improvement** (non-blocking): `guides/tui.md` documents running the TUI as `.venv/bin/python3 -m pf.frame.tui` from this repo's own venv. Correct for source-tree dev, wrong shape if copied into a template. Excluded from the sweep by the documented scope decision. Affects `pennyfarthing-dist/guides/tui.md` (would need a "dev-only, not the template pattern" note). *Found by TEA during test design.*
- **Gap** (non-blocking): `scripts/test/README.md` duplicates the testing-runner cache invocation verbatim. It is inside the sweep and will be fixed by this story, but the duplication itself is the drift risk — the README and the agent template have no shared source. Affects `pennyfarthing-dist/scripts/test/README.md`. *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): the policy sweep's fence-level discovery predicate could not see a correctly guarded fence. `_executes_pf` recognized an interpreter only by the literal word python, but the guard rewrite removes that word from the line, so `agents/sm-setup.md` and `commands/pf-standalone.md` dropped out of the detected set the moment they were fixed — the two sweep-integrity tests failed on a correct implementation. Fixed here by also accepting a PF_PY expansion as an interpreter reference. Affects `pennyfarthing-dist/src/pf/tests/test_162_8_template_pf_py_policy.py` (already applied). The broader lesson for future policy suites: a discovery regex keyed on the pre-fix spelling makes the post-fix state invisible. *Found by Dev during implementation.*
- **Improvement** (non-blocking): `pennyfarthing-dist/build/lib/pf/_dist/agents/sm-finish.md` is a stale build artifact carrying the pre-155-11 plain-expansion copy of sm-finish. It sits outside TEMPLATE_ROOTS so the sweep ignores it, and it is not the installed path, but it is a checked-in copy of a template with a known bug that grep will surface. Affects `pennyfarthing-dist/build/` (should be gitignored or removed). *Found by Dev during implementation.*
- **Improvement** (non-blocking): the two `workflows/scenario-builder/steps-{code,open}/step-06-validate.md` files are byte-identical in the region this story touched and were edited by a scripted twin-rewrite. Same drift risk TEA flagged for `scripts/test/README.md`. Affects both step files (no shared source). *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (blocking): the `gates/` root is outside TEMPLATE_ROOTS and holds five agent-executed fences running bare `python3 -c` with a `from pf.*` payload — the identical gh #112 shape this story targets. No gate file references PF_PY. Gate fences execute on every handoff gate resolution, so the ModuleNotFoundError thrash is live on any uv-tool install. Affects `pennyfarthing-dist/gates/{ac-completion,deviations-logged,spec-check,spec-reconcile-pass,spec-drift-precheck}.md` and TEMPLATE_ROOTS in the policy suite (add the root, guard the five fences, or document the exclusion as guides/ was). *Found by Reviewer during code review.*
- **Gap** (non-blocking): four fences interpolate agent-assembled data straight into a double-quoted Python source string — `format_pr_title(jira_key='${JIRA_KEY}', title='${TITLE}')` and `get_repo_config('{REPOS}')` — while `agents/sm-setup.md` one directory over documents and implements the correct positional-argument defense. A PR title containing an apostrophe breaks these fences today; a crafted one injects Python (CWE-78). Confirmed pre-existing: the diff does not touch a single one of these payload lines. Affects `pennyfarthing-dist/agents/sm-finish.md` (lines 31, 41), `commands/pf-standalone.md` (155), `workflows/git-cleanup/steps/step-03-execute.md` (157) — each needs the sm-setup treatment, passing data via argv or the environment. *Found by Reviewer during code review.*
- **Gap** (non-blocking): the repo-root `tests/` directory (97 files, 2947 tests) is 290-failed on develop and 287-failed on this branch — this story fixed three by accident and nobody noticed the root exists. TEA, Dev and this review all measured only the dist suite. There is also no CI workflow config in the repo, so nothing enforces either root. Affects `pennyfarthing/tests/` (decide whether that root is live, quarantined, or deleted, and wire up CI accordingly) — worth its own story. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the policy sweep has three reproduced blind spots — a heredoc with no dash argument, a version-pinned interpreter such as `python3.12`, and an untagged or `console`-tagged fence. Each admits a new offender with no test failing. No current template uses them. Affects `pennyfarthing-dist/src/pf/tests/test_162_8_template_pf_py_policy.py` (widen the fence-tag alternation and the interpreter pattern, normalize line continuations). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the fail-loud guard is loud but not fatal at eight of fourteen sites. Verified in bash — inside a command substitution the diagnostic reaches stderr but the script continues with an empty value, and on the right of a pipe the pipeline fails while the fence carries on. No regression, since bare python failed the same way with a worse message, but a template relying on the guard to halt a workflow will be disappointed. Affects the command-substitution and pipeline sites in `agents/sm-setup.md`, `agents/sm-finish.md`, `agents/testing-runner.md`, `commands/pf-standalone.md`, `workflows/git-cleanup/steps/step-03-execute.md` (needs an explicit exit check where the value is load-bearing). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): SENTINEL_TEMPLATES does not include a `gates/` file, so the root that was missed entirely still has no anti-vacuity sentinel. A rename or move of that directory would leave the five gate fences unwatched with the suite green. Affects `pennyfarthing-dist/src/pf/tests/test_162_8_template_pf_py_policy.py` (add one gate file to the sentinel tuple). *Found by Reviewer during delta review.*
- **Gap** (non-blocking): the policy predicate scans fence text for a pf import, so a fence invoking a `.py` script that itself imports pf is invisible to the sweep. No script under `scripts/` imports pf today, so this is latent — but it is the exact shape `gates/quality-pass.md` would take if `check.py` ever grew a pf import, and nothing would fail. Affects `pennyfarthing-dist/src/pf/tests/test_162_8_template_pf_py_policy.py` (consider resolving invoked script paths, or pin that the small set of template-invoked scripts stays pf-free). *Found by Reviewer during delta review.*
- **Gap** (non-blocking): `pf/gates/deviations.py` rejects a Spec source that does not match a file-path/AC/section pattern, but `guides/deviation-format.md` documents no such constraint — an agent following the guide exactly can still fail the gate, which is what happened to Dev's own first-pass entries during this story. Corroborates Dev's smoke-test finding. Affects `pennyfarthing-dist/guides/deviation-format.md` (document the Spec source specificity rule and the enumerated Severity/Forward impact values). *Found by Reviewer during delta review.*
- **Resolved** (was Question, non-blocking): `gates/quality-pass.md` keeps its venv-activate prelude by design and the earlier concern is withdrawn. Verified that `check.py` contains zero pf references and that it runs the project's own lint/typecheck/test tooling, which legitimately needs the project `.venv`; the PF_PY guard would point it at the wrong interpreter. It also falls outside the policy by the predicate itself rather than by an allowlist, so AC2's no-allowlist property is intact. The residual latent risk is captured in the script-path finding above. *Assessed by Reviewer during delta review.*
- **Superseded** (non-blocking): the interpolated-payload finding above now spans nine sites rather than four — the five gate fences interpolate the session path, context path and agent name into a double-quoted Python source string in the same shape. Confirmed pre-existing; the rework touches only the interpreter line in each file. Practical risk is lower than the PR-title sites because these values are framework-generated paths, not human-typed titles. Affects `pennyfarthing-dist/gates/{ac-completion,deviations-logged,spec-check,spec-drift-precheck,spec-reconcile-pass}.md`. *Found by Reviewer during delta review.*
- **Question** (superseded, non-blocking): `gates/quality-pass.md` line 13 still runs `source .venv/bin/activate && python3 .pennyfarthing/scripts/workflow/check.py`. That `check.py` imports only stdlib today, so it is not a gh #112 offender, but the venv-activate prelude is the same anti-pattern this story deleted elsewhere and it will bite the moment check.py imports pf. Affects `pennyfarthing-dist/gates/quality-pass.md`. *Found by Reviewer during code review.*

- **Gap** (non-blocking): `gates/quality-pass.md` line 13 still opens with a `source .venv/bin/activate &&` prelude, now the only venv-activate left in the dist tree. It runs `python3 .pennyfarthing/scripts/workflow/check.py`, a script path rather than a pf module, and that script imports no pf code (verified: stdlib only, shells out to project tooling), so the policy sweep correctly does not flag it and the PF_PY guard would be the wrong fix. But the prelude still assumes a project `.venv` exists at CWD and silently runs whatever interpreter it finds. Affects `pennyfarthing-dist/gates/quality-pass.md` (needs a decision on the contract: require the venv, or fall back explicitly). *Found by Dev during rework.*
- **Gap** (non-blocking): the `deviations-logged` gate validator is stricter than the format documented in `guides/deviation-format.md` and in the gate's own prose. The prose says Forward impact "starts with none, minor, or breaking", but `pf.gates.deviations` splits on an em dash and requires an exact match on the first segment, so "none for sibling stories" is rejected while "none — for sibling stories" passes. Spec source is likewise required to match a file/AC/section regex that the prose does not mention. Both bit this story's own entries and were only caught by smoke-running the rewritten fence. Affects `pennyfarthing-dist/src/pf/gates/deviations.py` and `pennyfarthing-dist/guides/deviation-format.md` (docs should state the em-dash separator and the spec-source requirement). *Found by Dev during rework.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### TEA (test design)
- **New policy suite instead of extending test_155_11:** SM's approach said "extend the 155-11 suite". Tests live in a new file `test_162_8_template_pf_py_policy.py` that imports the 155-11 behavioral fixtures rather than editing that file. Reason: 155-11's suite is a per-file pin on sm-finish and its failure messages name that file; a tree-wide sweep with per-file messages grafted on top would report offenders as "sm-finish.md still ..." and mislead. The fixtures (fake uv-tool launcher, decoy project venv) are reused by import, so there is no duplication.
- **Guard shape upgraded beyond the 155-11 precedent:** 155-11's shipped shape is plain `"$PF_PY"`. The story title asks for the fail-loud `${PF_PY:?}` form, so the policy requires the fail-loud expansion everywhere, which makes sm-finish an offender too. Reason: the story's own wording, plus the empty-PF_PY hole described in Delivery Findings. Dev must update sm-finish as well as the named siblings.
- **Sweep scope excludes guides/:** The policy walks `agents/`, `commands/`, `skills/`, `workflows/`, `templates/` and `scripts/` markdown, not `guides/`. Reason: guide pf invocations are source-tree dev instructions with a different contract (see Delivery Findings). Logged rather than silently narrowed — the scope constant and the rationale are in the suite docstring.
- **Prose instructions treated as offenders:** Tests also fail on inline code spans in prose that tell an agent to run pf code via bare python, not just bash fences. Reason: an agent executes an inline instruction exactly as written, so `- Run: python -c "from pf..."` is the same bug with different punctuation. This adds three offenders SM did not name.

### Dev (implementation)
- **Broadened the policy suite's fence-level discovery predicate**
  - Spec source: TEA Assessment (162-8 session), Guard Shape Spec for Dev; test file `test_162_8_template_pf_py_policy.py`
  - Spec text: "the guard token followed by `-c \"from pf....\"`" — i.e. rewrite every site so the literal interpreter name disappears from the invocation line
  - Implementation: also changed `_executes_pf` in the test file to accept a PF_PY expansion, not only a literal python/python3, as the interpreter reference
  - Rationale: the spec as given was unsatisfiable. `_executes_pf` gated fence detection on the literal word python, which the prescribed rewrite deletes, so `agents/sm-setup.md` and `commands/pf-standalone.md` left the detected set the moment they were correctly fixed and `TestPolicySweepIntegrity` failed on a correct implementation (2 failures, verified). The change strictly widens detection — no assertion was relaxed, no offender was allowlisted, and the two integrity tests plus all 14 policy tests pass afterward. It also closes a real hole: without it, a guarded fence that omitted its local derivation, or regressed to a non-fail-loud expansion, would be invisible to the sweep.
  - Severity: minor
  - Forward impact: none — no sibling story depends on the predicate. The reviewer should confirm the widened predicate rather than the templates, since it is the one test-file edit made during GREEN.
- **Prose offenders rewritten as guarded fences rather than deleted alternatives**
  - Spec source: .session/162-8-session.md, ## TEA Assessment > Guard Shape Spec for Dev, "Prose instruction" rewrite row
  - Spec text: "either drop the bare-python alternative and name the `pf` launcher, or show the full guarded form"
  - Implementation: took the first option for `commands/pf-prime.md` (the `pf agent start` launcher was already named alongside the bare-python alternative, so the alternative was dropped) and the second for both `step-06-validate.md` files, where the validator has no CLI entry point — the inline instruction became a real bash fence with the local derivation plus the guard, feeding the scenario data on stdin through a single-quoted heredoc
  - Rationale: `pf.benchmark.scenario_validator.validate_scenario` is a library function with no `pf` subcommand, so "name the launcher" was not available there. The heredoc form also avoids interpolating agent-assembled scenario data into a Python source string (same CWE-78 posture as the sm-setup fence).
  - Severity: minor
  - Forward impact: none — the fences are new prose-to-code conversions, not API changes.

- **Added the `gates/` root to the policy sweep (reviewer blocking finding)**
  - Spec source: .session/162-8-handoff-review.md, HIGH blocking finding; test_162_8_template_pf_py_policy.py:75 (TEMPLATE_ROOTS)
  - Spec text: TEA's scope decision enumerated the swept roots as "agents/, commands/, skills/, workflows/, templates/ and scripts/ markdown, not guides/" — `gates/` was named in neither the swept set nor the documented exclusions
  - Implementation: added `gates` to TEMPLATE_ROOTS and applied the standard derivation-plus-guard rewrite to the five gate fences the addition exposed
  - Rationale: `gates/` markdown is agent-executed on every handoff gate resolution, and five of those fences ran `python3 -c` on a `from pf.gates...` payload — the identical gh #112 shape this story exists to remove. AC2 claims the policy covers all dist templates, so an undocumented missing root made that claim false. Confirmed RED first (3 tests failing, exactly the 5 files the reviewer named), then GREEN.
  - Severity: minor
  - Forward impact: none — the guard shape is unchanged; only the swept surface grew.
- **Left `gates/quality-pass.md` venv-activate prelude in place**
  - Spec source: .session/162-8-handoff-review.md, upstream note on gates/quality-pass.md:13
  - Spec text: "Also flagged upstream (fix while you're in there if trivially in-pattern, else leave)"
  - Implementation: left the line unchanged and filed it as a Delivery Finding instead
  - Rationale: it runs `python3 .pennyfarthing/scripts/workflow/check.py`, a script path rather than a pf module or a `from pf` payload. Verified `scripts/workflow/check.py` imports no pf code at all — it is stdlib-only and shells out to project tooling. The PF_PY guard would therefore be the wrong fix (pf's interpreter is not what that script needs), and deleting the activate prelude could break projects whose lint and test tooling genuinely lives in the project `.venv`. Not in-pattern, so per the instruction it was left alone. The policy sweep does not flag it, which is consistent.
  - Severity: minor
  - Forward impact: none — nothing changed; the decision is recorded so the next sweep does not rediscover it as silence.

## Story Context

Story 162-8 is a follow-up to 155-11, which established the `${PF_PY:?}` fail-loud pattern for agent/command templates that invoke `python -m pf.*` modules. This pattern prevents templates from silently falling back to a project `.venv` python, which may lack the pf package or be the wrong environment.

This story sweeps SIBLING templates that still use the old pattern:
- `sm-setup` (agents/)
- `testing-runner` (agents/)
- `pf-standalone` (commands/ or skills/)
- Any other template in `pennyfarthing-dist/` that runs `pf.*` via `.venv/bin/python` or bare `python`

**Acceptance Criteria:**
1. Search `pennyfarthing-dist/agents/`, `commands/`, `skills/`, `templates/`, `scripts/` for templates running `pf.*` via `.venv` or bare `python`
2. Apply uniform `${PF_PY:?PF_PY not set — ...}` guard pattern from 155-11
3. Extend the test suite (find `test_155_11*` for the pattern) to cover the sibling templates
4. All tests pass; no new linting warnings

## TEA Assessment

**Tests Required:** Yes
**Reason:** Behavioral bug with an enforceable invariant. AC2 explicitly asks for a CI-enforced policy, so a test is the deliverable, not just a guard rail.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_8_template_pf_py_policy.py` — discovery-based policy sweep over all dist templates for unguarded pf.* invocations. Imports the 155-11 behavioral fixtures (fake uv-tool launcher with a space in its path, decoy project venv whose python cannot import pf) rather than duplicating them.

**Tests Written:** 16 tests in 5 classes covering 3 ACs. 9 fail (RED), 7 pass. The 7 passing are the sweep-integrity checks plus two derivation behaviors already correct in sm-finish — they are the anti-vacuity harness, not filler: if a regex tweak makes discovery stop finding templates, they go red instead of letting the whole policy pass silently.

**Status:** RED (9 failing) — full suite is 9 failed, 5635 passed, 4 skipped, 7 xfailed. The 7 xfails are the documented 162-5 baseline. No new failures outside this file.

### Offender Table

Enumerated by sweep, not by hand. SM named three files; the sweep found nine.

| # | File | Offending form | Sites | Named by SM |
|---|------|----------------|-------|-------------|
| 1 | `agents/sm-setup.md` | bare `python3 -c` with an inline `from pf.jira.client` payload | 1 | yes |
| 2 | `agents/sm-setup.md` | bare `python3 - "{REPOS}"` heredoc running `from pf.git.repos` — the stdin/heredoc form 155-11's regex never matched | 1 | yes |
| 3 | `agents/testing-runner.md` | bare `python -m pf.session.test_cache` on the right side of a pipe | 1 | yes |
| 4 | `commands/pf-standalone.md` | `source .venv/bin/activate && python -c` running `from pf.git.repos` — the exact gh #112 root cause | 1 | yes |
| 5 | `workflows/git-cleanup/steps/step-03-execute.md` | same venv-activate form as pf-standalone (copy of the same block) | 1 | no |
| 6 | `agents/sm-finish.md` | derives PF_PY correctly but expands it as plain `"$PF_PY"`, which silently becomes an empty argv[0] when the derivation fails | 5 | no |
| 7 | `commands/pf-prime.md` | prose advertises `python3 -m pf.cli agent start <name>` as an alternative to the pf launcher — teaches the anti-pattern | 1 | no |
| 8 | `workflows/scenario-builder/steps-code/step-06-validate.md` | prose instruction "Run: `python -c "from pf.benchmark.scenario_validator import ..."`" | 1 | no |
| 9 | `workflows/scenario-builder/steps-open/step-06-validate.md` | same instruction as #8 | 1 | no |
| 10 | `scripts/test/README.md` | duplicates testing-runner's bare `python -m pf.session.test_cache` line | 1 | no |

Not offenders, checked and cleared: no template anywhere invokes pf code via an explicit `.venv/bin/python` path (a test pins that anyway, since it is the obvious way to "fix" the activate form while keeping the bug).

Out of sweep by deliberate scope decision — see Delivery Findings: `scripts/hooks/pre-commit.sh` and `guides/tui.md`.

### Guard Shape Spec for Dev

Two parts, both required per bash fence. The tests check the shape by regex AND execute the guard token in a real bash to confirm the behavior, so a lookalike expansion such as a `-` default or a `:=` assign-default will fail.

**1. Derivation — once inside every fence that runs pf code** (fences are run independently by subagents, so it cannot be inherited from an earlier fence). Use the 155-11 line verbatim: `PF_PY="$(sed -n '1s/^#!//p' "$(command -v pf)")"`. The inner command substitution must stay double-quoted — the test fixture puts a space in the launcher's directory precisely to catch an unquoted variant.

**2. Invocation — every site, uniformly:** `"${PF_PY:?PF_PY not set - could not resolve the pf launcher interpreter}"` in place of `"$PF_PY"`, bare `python`, `python3`, or the venv-activate prelude.

Message rules enforced by test: it must contain the string PF_PY, must be at least four words, and must not contain a closing brace. Prefer a plain hyphen over an em dash inside the message.

Rewrites, by offender shape:
- Bare module run: `python -m pf.session.test_cache "$RUN_ID"` becomes the guard token followed by `-m pf.session.test_cache "$RUN_ID"`.
- Inline payload: `python3 -c "from pf...."` becomes the guard token followed by `-c "from pf...."`.
- Heredoc: `python3 - "{REPOS}" <<'PYEOF'` becomes the guard token followed by `- "{REPOS}" <<'PYEOF'`. Keep the positional argument and the single-quoted heredoc delimiter — that is the CWE-78 defense the fence comment documents, and it must survive the rewrite.
- Venv activate: delete the `source .venv/bin/activate &&` prelude entirely, add the derivation line above the invocation, then use the guard token.
- Prose instruction: either drop the bare-python alternative and name the `pf` launcher, or show the full guarded form. Do not leave a bare python in an inline code span — an agent runs it exactly as written.

Behavior Dev should expect and not "fix": with no pf on PATH the derivation resolves to empty and the guard aborts the fence nonzero with the message on stderr. That is the point. A test asserts the derivation neither hangs (sed must not fall back to stdin) nor invents a value in that case.

### Rule Coverage

Language is Python for the test file, but the artifacts under test are markdown templates and shell fences, so the applicable rules are project rules rather than a lang-review checklist:

- **Fail loud, no silent fallback** (project rule 6 spirit, and the 155-11 precedent): covered by the whole `TestFailLoudGuardShape` class, including two behavioral tests that run the guard token with PF_PY unset and set.
- **No vacuous assertions** (TEA rule): every guard-inspecting test asserts its input collection is non-empty before iterating, so none of them can pass while the templates are unguarded. `TestPolicySweepIntegrity` does the same job for discovery: it pins that the sweep still sees the four sentinel templates and still extracts invocation lines from each.
- **Negative case present:** `test_fail_loud_guard_passes_value_through_when_set` is the counterweight to the abort test — a guard that always aborted would satisfy the abort assertion and break every template.
- **Injection safety** (CWE-78, already documented in the sm-setup fence): the heredoc rewrite guidance preserves the positional-argument and single-quoted-delimiter defense; the reviewer should confirm Dev did not collapse the heredoc into an interpolated `-c` string.

**Handoff:** To Dev for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/agents/sm-setup.md` - both offending sites guarded: the `python3 -c` Jira-detection line and the `python3 - "{REPOS}"` heredoc. The heredoc keeps its positional argument and single-quoted delimiter, so the documented CWE-78 defense survives intact; only the interpreter token changed.
- `pennyfarthing-dist/agents/testing-runner.md` - local derivation added inside the `if` block, cache write now runs through the guard on the right side of the pipe.
- `pennyfarthing-dist/agents/sm-finish.md` - all 5 plain `"$PF_PY"` expansions replaced with the fail-loud form (the gap TEA reported in 155-11's own fix). Derivation lines untouched.
- `pennyfarthing-dist/commands/pf-standalone.md` - the gh #112 root cause: `source .venv/bin/activate &&` prelude deleted, derivation plus guard in its place.
- `pennyfarthing-dist/workflows/git-cleanup/steps/step-03-execute.md` - same venv-activate block, same rewrite.
- `pennyfarthing-dist/commands/pf-prime.md` - dropped the `python3 -m pf.cli` alternative from the CLI reference line; the `pf` launcher is now the only documented entry point.
- `pennyfarthing-dist/workflows/scenario-builder/steps-code/step-06-validate.md` - prose instruction replaced by a guarded bash fence.
- `pennyfarthing-dist/workflows/scenario-builder/steps-open/step-06-validate.md` - identical rewrite (twin file).
- `pennyfarthing-dist/scripts/test/README.md` - the duplicated testing-runner invocation, guarded to match.
- `pennyfarthing-dist/src/pf/tests/test_162_8_template_pf_py_policy.py` - one predicate widened, see Design Deviations. No assertion weakened.

**Guard applied uniformly:** derivation `PF_PY="$(sed -n '1s/^#!//p' "$(command -v pf)")"` once per pf-executing fence, then the fail-loud token with the message "PF_PY not set - could not resolve the pf launcher interpreter" at every site. 10 offending forms across 9 files.

**Verification:**
- Story suite: 16/16 passing (GREEN). Was 9 failed / 7 passed at RED.
- 155-11 suite: 6/6 still passing - no regression on the precedent it set.
- Full framework suite: 5644 passed, 4 skipped, 7 xfailed, exit 0. The 7 xfails are the documented 162-5 baseline; no failures.
- `ruff check` clean on the story file, `ruff format --check` clean. Package-wide count is 86 errors both with and without this branch's changes, i.e. pre-existing and untouched.
- `pf validate` identical to baseline (211 passed, 118 warnings, 358 errors with the changes stashed and unstashed) - pre-existing, unrelated.
- Smoke-executed the rewritten fences against the real installed launcher: derivation resolved to the uv-tool interpreter, the Jira detection, the repos heredoc, and the test-cache module run all produced correct output.

**Tests:** 16/16 passing (GREEN)
**Branch:** feat/162-8-pf-py-template-sweep (pushed)

**Handoff:** To review phase

## Subagent Results

| # | Subagent | Received | Status | Findings | Confirmed | Notes |
|---|----------|----------|--------|----------|-----------|-------|
| 1 | reviewer-preflight | Yes (error) | Failed (API 529 Overloaded) | partial, discarded | N/A | Terminated early by a server-side API error. Its partial output was contaminated by the Reviewer's concurrent probe files and was discarded. Every mechanical check it owned was re-run by hand — see Verification Performed. |
| 2 | reviewer-edge-hunter | N/A | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | N/A | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | Findings | 10 | 3 | Seven vacuity findings downgraded — protection is centralized in TestPolicySweepIntegrity rather than per-test. Independently confirms the widened predicate cannot narrow detection. |
| 5 | reviewer-comment-analyzer | N/A | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | Findings | 7 | 3 | Independently predicted the three sweep blind spots the Reviewer then reproduced by probe. |
| 7 | reviewer-security | Yes | Findings | 4 | 4 | All four are pre-existing interpolated payloads, untouched by this diff. Verified the new fences are injection-clean. |
| 8 | reviewer-simplifier | N/A | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | Clean | 0 violations | N/A | 22 rules / 67 instances. Surfaced the gates/ lead that became the blocking finding. |

**All received: Yes** — 5 enabled subagents accounted for (4 returned results, 1 failed with an API error and its checks were performed manually by the Reviewer). 4 disabled via `workflow.reviewer_subagents`.

**Challenged:** none. No VERIFIED in this assessment contradicts a subagent finding. The seven vacuity findings and the four CWE-78 findings were confirmed as real and carried forward with documented severity downgrades — the vacuity ones because CI runs the whole file and TestPolicySweepIntegrity does turn red on discovery breakage, the injection ones because the diff provably touches none of those payload lines. Neither set was dismissed.

## Reviewer Assessment

**Verdict:** REJECTED

One blocking issue. The nine template rewrites are correct and the policy suite is real, but the sweep omits a dist root that contains five live instances of the exact bug this story exists to eliminate, and that omission is undocumented.

### Blocking

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| HIGH | [RULE] [TEST] The gates/ root is absent from TEMPLATE_ROOTS, and gates/ contains five agent-executed fences running bare python3 -c with a from pf.* payload — the identical gh #112 shape the story targets. Zero gate files reference PF_PY. AC2 ("policy test covers all dist templates so new offenders fail CI") is therefore false as written, and the suite docstring's claim that it discovers "every template" and that "a future template that bypasses the guard fails CI without anyone editing this file" is false. | TEMPLATE_ROOTS at test_162_8_template_pf_py_policy.py:75; offenders at gates/ac-completion.md:25, gates/deviations-logged.md:25, gates/spec-check.md:28, gates/spec-reconcile-pass.md:24, gates/spec-drift-precheck.md:27 | Add gates to TEMPLATE_ROOTS and apply the established derivation + fail-loud guard to the five fences. Mechanically identical to work already done. If gates/ is instead to be excluded, that requires an explicit documented scope decision with rationale, as guides/ and pre-commit.sh received — silence is not a scope decision. |

Why this blocks rather than defers: 162-8 exists because 155-11 fixed the one file it looked at, declared the pattern, and left its siblings unswept. Shipping a tree-wide policy that misses a whole root of live offenders reproduces that failure mode a third time. The gate fences run on every handoff gate resolution, so the ModuleNotFoundError thrash is live on any uv-tool install. The fix is roughly a one-line root addition plus five fence rewrites.

### Verification Performed

The Dev test-file edit was the priority and it holds up under adversarial reproduction.

- **Unsatisfiability of TEA's predicate: REPRODUCED.** Checked out the RED version of the test file against Dev's fixed templates in the working tree (hash-verified, self-restoring). Result was exactly Dev's claim: 2 failed / 14 passed, with TestPolicySweepIntegrity reporting the detected set as sm-finish, testing-runner and scripts/test/README only — agents/sm-setup.md and commands/pf-standalone.md had dropped out precisely because the correct rewrite deletes the literal word the predicate keyed on. TEA's spec was genuinely unsatisfiable. Tree restored, checksum verified.
- **The edit is one logical line.** Diff between the two commits touches only the _executes_pf gate, changing an AND-guard into an OR that also accepts a PF_PY expansion, plus a docstring. No assertion relaxed, no allowlist, no file exempted. Note that _pf_exec_lines already accepted PF_PY expansions at RED — the fence-level predicate was simply inconsistent with the line-level one, which corroborates oversight rather than convenience.
- **Cannot be gamed — probed, not reasoned.** Scratch template files under agents/, one shape per run, each removed immediately and the tree verified clean afterward. A classic bare python3 -c offender fails 3 tests. An explicit .venv/bin/python offender fails 3. A venv-activate offender fails 4. A regression from fail-loud back to plain expansion fails the guard-shape test. A guarded fence missing its local derivation fails the derivation test — which is the real hole Dev claimed the widening closes, and it does. The specific gaming scenario in the review brief (a fence mentioning PF_PY in a comment while executing bare python elsewhere) does not work: line-level checks are independent, so the bare-python line is still flagged regardless of what any other line says.
- **CWE-78 defense intact.** sm-setup's heredoc keeps both properties: the repo name still arrives as a positional argument read via sys.argv[1], and the delimiter is still single-quoted. Only the interpreter token moved. The documenting comment survives.
- **New fences smoke-executed.** Ran the scenario-builder validator fence against the real installed launcher with a hostile payload in the heredoc body containing a command substitution, backticks and an rm invocation. It returned valid JSON and the payload was completely inert — single-quoted delimiter, stdin only, nothing interpolated into Python source. Confirmed validate_scenario takes a dict and returns a JSON-serializable dict, so the new fence is not just well-shaped but correct.
- **All 14 guard sites are double-quoted** and carry one identical message. Exactly one derivation form exists tree-wide.
- **Suite re-measured by hand** after the preflight subagent died: dist tests exit 0 at 5644 passed / 4 skipped / 7 xfailed with zero XPASS. Story suite 16/16, 155-11 suite 6/6. Both commits carry a Good GPG signature. Working tree clean.
- **Second test root investigated.** The repo-root tests/ directory (97 files) is 287 failed on this branch but 290 failed on develop, measured in a throwaway worktree. This branch reduces failures by three and adds none. That root is pre-existing red and is not what anyone in this story measured — filed below.

### Non-Blocking Findings

| Severity | Issue | Location |
|----------|-------|----------|
| MEDIUM | [TYPE] Three sweep blind spots, each reproduced by probe: a heredoc without the dash argument, a version-pinned interpreter such as python3.12, and an untagged or console-tagged fence. Each lets a new offender pass CI silently. No current template uses any of them, so AC1 is unaffected, but they weaken AC2's guarantee. | test_162_8_template_pf_py_policy.py:87, :97, :99 |
| MEDIUM | [TEST] The session claims every guard-inspecting test asserts its input collection is non-empty before iterating. That is false for six tests. Vacuity protection is real but centralized in TestPolicySweepIntegrity rather than per-test, so an isolated single-test run has no guard. Downgraded from the subagent's High because CI runs the whole file and discovery breakage does turn it red. | test_162_8_template_pf_py_policy.py:275, :295, :312, :320, :335, :359, :556 |
| MEDIUM | [TEST] [TYPE] The two behavioral guard tests interpolate the extracted guard token into a bash string, so a future guard message containing a double quote would produce a shell syntax error and a misleading failure. Passing the token through the environment removes the surface. | test_162_8_template_pf_py_policy.py:403, :439 |
| LOW | [SEC] The fail-loud guard is loud but not fatal at the eight command-substitution and pipeline sites. Verified in bash: at a direct invocation the fence aborts, but inside a command substitution the message reaches stderr and the script continues with an empty value, and on the right of a pipe the pipeline fails while the fence continues. Not a regression — the pre-change bare python failed the same way with a worse message — but downstream consumers of an empty PR title still proceed quietly. | sm-setup.md:110, :281; sm-finish.md:28, :29, :39; pf-standalone.md:153; step-03-execute.md:155; testing-runner.md:89 |
| LOW | [TEST] Roots are skipped silently when absent, and the file-count sentinel would still pass if one root vanished, so a whole category could go unswept without failing. This is the same structural weakness that produced the blocking finding. | test_162_8_template_pf_py_policy.py:115 |
| LOW | [TYPE] The derived-interpreter import test exercises only the first derivation rather than all of them. Impact is minimal because exactly one derivation form exists tree-wide, but the guarantee is narrower than the test name suggests. | test_162_8_template_pf_py_policy.py:527 |

### Deviation Audit

All six logged deviations are ACCEPTED. One undocumented deviation found.

- TEA, new policy suite instead of extending 155-11: ACCEPTED. The fixture reuse by import is real and the per-file failure messages would genuinely have misreported tree-wide offenders.
- TEA, guard shape upgraded past the 155-11 precedent: ACCEPTED. Matches the story title and closes the empty-argv[0] hole, which I confirmed behaviorally.
- TEA, guides/ excluded: ACCEPTED. Sound judgment — guides/tui.md deliberately runs the TUI from this repo's own venv, which is a different contract from a template invoking an installed pf. Documented with rationale rather than silently narrowed.
- TEA, pre-commit.sh excluded: ACCEPTED. Sound. A git hook must degrade on machines without pf, and the fail-loud guard would break that path. Correctly identified as needing its own story to settle the hook's contract.
- TEA, prose instructions treated as offenders: ACCEPTED, and the right call. An agent runs an inline instruction exactly as written. The inline-span test does real work.
- Dev, broadened the discovery predicate: ACCEPTED after independent reproduction of the unsatisfiability and adversarial probing of the widened form. Correctly logged, correctly scoped, and it closes a real hole.
- Dev, prose offenders rewritten as guarded fences: ACCEPTED. The heredoc choice for the scenario-builder steps is better than the alternative TEA offered, since validate_scenario has no CLI entry point and the heredoc keeps agent-assembled data out of the Python source.
- UNDOCUMENTED: gates/ was never considered for the sweep and received neither inclusion nor a rationale for exclusion. This is the blocking finding.

### Observations

1. Verified good: the CWE-78 posture of the new scenario-builder fences is stronger than the prose they replaced, and was proven by execution with a hostile payload rather than by inspection.
2. Verified good: the guard shape is genuinely uniform — 14 sites, one message, one derivation form, every site double-quoted against space-containing launcher paths.
3. [SEC] Bad pattern, pre-existing: four sites interpolate story titles and repo names directly into a double-quoted Python source string while sm-setup one directory over documents the correct defense. A PR title containing an apostrophe breaks those fences today. Not touched by this diff — filed below.
4. Good pattern: the anti-vacuity harness in TestPolicySweepIntegrity is the reason the RED predicate's unsatisfiability was caught at all. It did exactly the job TEA designed it for, on Dev rather than on a future author.
5. Error handling gap: fail-loud means diagnosable, not fatal, at eight of fourteen sites. Worth knowing before anyone relies on the guard to halt a workflow.
6. Structural: TEMPLATE_ROOTS is the single point of failure for the entire policy, and it has no test asserting its roots exist or that it covers the dist tree. Both the blocking finding and two non-blocking ones trace back to it.

## Reviewer Assessment — Delta Review (rework 623f1bb00)

**Verdict:** APPROVED

The HIGH blocker is resolved. Delta is 6 files, 29 insertions — five gate fences plus one root added to TEMPLATE_ROOTS. Every claim Dev made was verified independently rather than accepted.

### Blocker Resolution — Verified

- **RED-first: REPRODUCED.** Restored the five gate files to their pre-rework state while keeping the new TEMPLATE_ROOTS, then ran the suite. Exactly 3 tests failed, and the offender files named in the output were exactly the five I identified, with no sixth. This confirms both that the new root genuinely catches them and that my original enumeration was complete. All 28 gate files restored and hash-verified afterward.
- **Fix is byte-identical to the established pattern.** Tree-wide there is now exactly one derivation form and exactly one guard token across 19 sites in 13 files, up from 14 sites. No variant crept in with the five new sites.
- **Zero residual offenders anywhere in the dist tree,** including the roots the policy still does not walk (guides, patterns, protocols, schemas, output-styles, personas). The sweep and the tree now agree.
- **The gate fences are the fatal guard shape,** not the diagnostic-only one. They are direct top-level invocations rather than command substitutions, so the guard aborts the fence — these five sites do not carry the LOW severity caveat that applies to the other eight.
- **Executed the rewritten deviations-logged fence verbatim** against this session file using the real installed launcher. It returned status pass, 4 entries, 0 errors, exit 0. The full path works end to end: derivation, guard, pf import, validation, exit code. Dev's claim 3 confirmed, and the gate validated the very session documenting its own fix.
- **Suite re-measured: exit 0, 5644 passed, 4 skipped, 7 xfailed, zero XPASS.** Story suite 16/16, 155-11 suite 6/6, ruff check and format clean. Commit carries a Good GPG signature. Working tree and worktree list clean, no probe residue.

### Judgment Call Assessed: gates/quality-pass.md

**SOUND scope call, not a dodge.** Verified independently:

- check.py contains zero references to pf — no import, no deferred import, nothing. The gh #112 failure mode is structurally absent, so there is no bug to fix.
- The script runs the *project's* lint, typecheck and test commands concurrently. Those live in the project .venv, so the activate prelude is load-bearing. Applying the PF_PY guard would point the script at the pf CLI's interpreter, which is the wrong environment — the guard is genuinely the wrong instrument here.
- Best part: quality-pass.md falls outside the policy *by the predicate itself*, because its fence carries no pf import, rather than by an allowlist. The no-allowlist property of AC2 survives intact. That is the right architecture, and it is why this exclusion needed no special-casing.

My earlier Question finding on this file is withdrawn as resolved-as-designed. The residual latent risk is recorded below as the script-path blind spot.

### Delta Findings (all non-blocking, deferred)

| Severity | Issue | Location |
|----------|-------|----------|
| MEDIUM | [TEST] SENTINEL_TEMPLATES still names only the four original files, so the newly added gates root has no sentinel. If gates discovery ever regressed — a root rename, a directory move — TestPolicySweepIntegrity would stay green and the five fences would go unwatched again. This is exactly the failure mode that produced the blocker, and it is one tuple entry away from being closed. Adding a gate file to the sentinel set is the belt-and-braces. | test_162_8_template_pf_py_policy.py:80 |
| LOW | [TYPE] Script-path blind spot: the predicate scans fence text for a pf import, so a fence invoking a .py script that itself imports pf is invisible to the policy. Verified no script under scripts/ imports pf today, so this is latent only — but it is the shape quality-pass.md would take if check.py ever grew a pf import. | test_162_8_template_pf_py_policy.py:140 |
| LOW | [SEC] The pre-existing interpolated-payload finding now spans nine sites rather than four: the five gate fences interpolate the session path, context path and agent name into a double-quoted Python source string, exactly as the four PR-title sites do. Confirmed pre-existing — the delta touches only the interpreter line in each file, never a payload line. Lower practical risk than the PR-title sites, since these values are framework-generated paths rather than human-typed titles. | gates/ac-completion.md:28, deviations-logged.md:28, spec-check.md:31, spec-drift-precheck.md:30, spec-reconcile-pass.md:27 |
| LOW | [RULE] Doc drift confirmed, and Dev's finding is accurate: pf/gates/deviations.py rejects a Spec source that does not match a file-path/AC/section pattern, and guides/deviation-format.md documents none of that constraint. An agent following the guide exactly can still fail the gate — which is what happened to Dev's own first-pass entries. | src/pf/gates/deviations.py:325 vs guides/deviation-format.md:7 |

### Delta Deviation Audit

- Dev, gates/quality-pass.md deliberately not guarded: **ACCEPTED**, with rationale independently verified on all three grounds above. Correctly logged as a deviation plus a Delivery Finding rather than silently skipped — which is precisely the difference between this and the undocumented omission that caused the rejection.
- No undocumented deviations in the delta.

**Handoff:** To SM for finish. Four deferred findings, none blocking.

## Dev Assessment Addendum (rework after review rejection)

**Blocking finding addressed:** HIGH — `gates/` absent from TEMPLATE_ROOTS while `pennyfarthing-dist/gates/` held five agent-executed fences running bare `python3 -c` on `from pf.gates...` payloads. The reviewer was right and the omission was mine: `gates/` is executed on every handoff gate resolution, so it is exactly as live as `agents/`, and unlike `guides/` it had never been named as a documented exclusion.

**Changes:**
- `pennyfarthing-dist/src/pf/tests/test_162_8_template_pf_py_policy.py` - added `gates` to TEMPLATE_ROOTS.
- `pennyfarthing-dist/gates/ac-completion.md`, `deviations-logged.md`, `spec-check.md`, `spec-reconcile-pass.md`, `spec-drift-precheck.md` - derivation plus fail-loud guard, identical shape to the other 14 sites. Guard token and message unchanged, so the suite's behavioral guard tests cover these too.

**RED confirmed before fixing,** per instruction: with `gates` added and the fences untouched, 3 tests failed and named exactly the five files the reviewer listed - `test_no_bare_python_runs_pf_code`, `test_every_pf_exec_line_references_pf_py`, `test_pf_exec_fences_derive_pf_py_locally`. No sixth offender appeared.

**`gates/quality-pass.md` deliberately left alone.** It runs a script path, not a pf module, and `scripts/workflow/check.py` imports no pf code at all, so the guard is the wrong instrument and removing the prelude risks projects whose lint and test tooling lives in the project `.venv`. Logged as a deviation and a Delivery Finding. `gates/tests-fail.md` line 14 mentions `python3 -m pytest` in prose - pytest, not pf code, correctly not an offender.

**Unexpected catch:** smoke-running the rewritten `deviations-logged` fence against this very session file returned status fail and exposed two format defects in my own Design Deviations entries from the first pass - one Forward impact missing its em-dash separator, one Spec source with no file reference. Both fixed; that gate now returns pass with 4 entries and 0 errors. The rewritten fence proving itself by failing my own work is the best evidence it executes correctly.

**Deferred, untouched per instruction:** sweep blind-spot shapes, guard-not-fatal sites, and the pre-existing CWE-78 payloads on lines this diff does not touch. All belong to follow-up stories.

**Verification:**
- Story suite: 16/16 passing (GREEN), including the 3 that went red when `gates` was added.
- 155-11 suite: 6/6 passing.
- Full framework suite: 5644 passed, 4 skipped, 7 xfailed, exit 0. The 7 xfails are the documented 162-5 baseline.
- `ruff check` and `ruff format --check` clean on the story file; package-wide count still 86, unchanged from baseline.
- Smoke: the rewritten `deviations-logged` gate fence executed end to end against the real installed launcher.

**Commit:** 623f1bb00 (GPG signed, Good signature), pushed. Working tree clean.

**Handoff:** Back to review phase.