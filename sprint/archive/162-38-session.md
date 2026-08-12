---
story_id: "162-38"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-38: PF_PY policy hardening (162-8 tail): add gate-fence sentinels to SENTINEL_TEMPLATES (the unswept-root failure mode is one rename from recurring — highest-value); note the script-path blind spot (fence invoking a .py that imports pf is invisible to the predicate); pin the sweep blind-spot shapes (dash-less heredoc, python3.12, untagged fence); document deviations.py's Spec-source specificity rule in guides/deviation-format.md (from 162-8 review)

## Story Details
- **ID:** 162-38
- **Jira Key:** (none — Jira not configured for this project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-38-pf-py-policy-hardening-sentinels-blindspots
- **PR:** (none yet — recorded when the PR is created)
- **Repos:** pennyfarthing

## SM Assessment

**Spec:** the title is the full spec (162-8 review). FOUR deliverables in the PF_PY policy area (grep `SENTINEL_TEMPLATES` + the PF_PY/`python` policy sweep under `pennyfarthing-dist/src/pf/`):

1. **Add gate-fence sentinels to `SENTINEL_TEMPLATES`** (HIGHEST VALUE): the unswept-root failure mode is one rename away from recurring. Add sentinel entries for the gate-fence shape so the policy sweep catches a regression. Read what SENTINEL_TEMPLATES currently holds and mirror the pattern.
2. **Note the script-path blind spot:** a fence that invokes a `.py` which imports `pf` is INVISIBLE to the policy predicate (the predicate looks for inline `python`, not an indirect script invocation). Document this blind spot (comment/doc) so it's a known limitation, not a silent gap.
3. **Pin the sweep blind-spot shapes** with tests: (a) dash-less heredoc, (b) `python3.12` (version-suffixed), (c) untagged fence. These are shapes the current sweep may miss — pin them so the coverage is explicit (either the sweep catches them, or the test documents the known gap; follow 162-8's disposition style).
4. **Document `deviations.py`'s Spec-source specificity rule** in `pennyfarthing-dist/guides/deviation-format.md` — the rule deviations.py enforces about how a deviation must cite its spec source specifically. Read deviations.py to state the rule accurately.

**TEA (RED):** failing tests pinning: the gate-fence sentinel is present in SENTINEL_TEMPLATES / caught by the sweep; the three blind-spot shapes (dash-less heredoc, python3.12, untagged fence) — assert current detection behavior and pin the intended contract; a test/assertion anchoring the deviation-format doc rule. Read the 162-8 tests + SENTINEL_TEMPLATES first for the exact shape.

**Constraints (binding):** scoped runs — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/<pf_py / policy / sentinel tests>.py -q`. NEVER full suite. `ruff check`. Result objects, not throws. Match 162-8's disposition discipline (a genuine blind spot that can't be closed cheaply gets DOCUMENTED, not papered over).

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_38_pf_py_policy_hardening.py` — hardens the 162-8 PF_PY policy sweep: gate-fence sentinel, script-path blind spot, three sweep blind-spot shapes, deviation-format Spec-source doc rule.

**Tests Written:** 32 tests (13 failing / 19 passing) covering all 4 deliverables
**Status:** RED
**Commit:** `db070d0` (signed)
**Scoped run:** `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_38_pf_py_policy_hardening.py -q` → `13 failed, 19 passed in 0.43s`. `ruff check` + `ruff format` clean.

### Failing tests (RED) and why

| Test | Deliverable | Failure |
|---|---|---|
| `TestGateFenceSentinel::test_sentinel_templates_includes_a_gate_fence` | 1 | `SENTINEL_TEMPLATES` = `['agents/sm-finish.md','agents/sm-setup.md','agents/testing-runner.md']`; gates that DO run pf code: `ac-completion, deviations-logged, spec-check, spec-drift-precheck, spec-reconcile-pass` |
| `TestScriptPathBlindSpotIsDocumented::test_script_path_blind_spot_is_documented_in_the_policy_module` | 2 | 162-8 module docstring missing markers `['blind spot', '.py']` |
| `TestDashlessHeredocShape::test_dashless_heredoc_is_detected_as_pf_execution` | 3a | `_executes_pf("python3 <<'PYEOF'\nfrom pf.sprint.status import main…") is False` |
| `TestDashlessHeredocShape::test_dashless_heredoc_is_flagged_as_bare_python` | 3a | `BARE_PYTHON_EXEC_RE` does not match `python3 <<'PYEOF'` |
| `TestVersionSuffixedPythonShape::test_version_suffixed_interpreter_is_detected[dash-c]` | 3b | `_executes_pf('python3.12 -c "from pf…"') is False` |
| `TestVersionSuffixedPythonShape::test_version_suffixed_interpreter_is_flagged_as_bare_python[dash-c]` | 3b | `BARE_PYTHON_EXEC_RE` misses `python3.12 -c` |
| `TestVersionSuffixedPythonShape::test_version_suffixed_interpreter_is_flagged_as_bare_python[dash-m]` | 3b | `BARE_PYTHON_EXEC_RE` misses `python3.12 -m pf.sprint.status` (fence IS swept via `-m pf.`, so the bare offence passes silently) |
| `TestUntaggedFenceShape::test_untagged_fence_is_extracted_by_the_sweep` | 3c | `_bash_fences` returns `[]` for an untagged ``` fence |
| `TestUntaggedFenceShape::test_untagged_pf_fence_would_be_detected_end_to_end` | 3c | same, end-to-end |
| `TestDeviationFormatDocumentsSpecSourceRule::test_guide_has_a_spec_source_rule_section` | 4 | no `Spec source` heading section in `guides/deviation-format.md` |
| `…::test_guide_states_the_accepted_spec_source_forms` | 4 | section absent (must state file-with-extension / `AC-3`/`AC3` / `Section N` / `SOUL.md` / heading, and that anything else is "vague") |
| `…::test_guide_names_the_gate_consequence` | 4 | section absent (must say the gate FAILS the entry) |
| `…::test_guide_shows_a_rejected_counter_example` | 4 | section absent; requires ≥1 inline example that `deviations.py::_VALID_SPEC_SOURCE_RE` actually rejects |

### Disposition: intended fix vs documented gap

- **Intended fix (Dev makes green):** gate-fence sentinel (add a `gates/*.md` entry to `SENTINEL_TEMPLATES`); dash-less heredoc; `python3.12` version-suffixed interpreter; untagged fence discovery; the `deviation-format.md` Spec-source section. Verified 0 live offenders in the tree for all three shapes, so widening the sweep cannot break the 162-8 suite.
- **Documented gap (stays a documented limitation):** the script-path invocation — a fence handing a `.py` that imports pf to the interpreter is invisible to the predicate, because closing it needs cross-file import resolution through `.pennyfarthing/` symlinks. Pinned two ways: `test_script_path_invocation_is_invisible_to_the_predicate` asserts `False` (flip it if ever closed), and `test_no_live_script_path_offender_in_the_tree` (green) keeps the gap latent. Dev's job here is the KNOWN LIMITATION note in the 162-8 policy module docstring, not a predicate change.

**Where the fix lands:** the sweep IS the 162-8 test module (`test_162_8_template_pf_py_policy.py` regexes + `SENTINEL_TEMPLATES`), so deliverables 1–3 are edits to that module plus `guides/deviation-format.md` for 4. Negative-case tests are included for every widening (guarded heredoc, `${PF_PY:?}` expansion, ```yaml/```json/```python fences must NOT be flagged/swept) so a greedy regex cannot buy green.

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/tests/test_162_8_template_pf_py_policy.py` — added `gates/ac-completion.md` to `SENTINEL_TEMPLATES`; widened `BARE_PYTHON_EXEC_RE`/`ANY_PYTHON_EXEC_RE` (shared `_EXEC_FORM`: `-m`/`-c`/bare `-`/`<<` heredoc, optional `.N` version suffix); replaced `BASH_FENCE_RE` with line-based `_bash_fences` + `FENCE_DELIM_RE`/`SHELL_INFO_STRINGS` so untagged fences are swept and yaml/json/python fences are not; added KNOWN LIMITATION note for the script-path blind spot to the module docstring
- `pennyfarthing-dist/guides/deviation-format.md` — new `### Spec source specificity (enforced)` section: accepted forms table, gate consequence, REJECTED counter-examples

**Tests:** 48/48 passing (GREEN) — 32 in `test_162_38_pf_py_policy_hardening.py` (13 formerly-RED now green, 19 guards green) + 16 in `test_162_8_template_pf_py_policy.py`. Regression-checked: `test_155_11_sm_finish_pf_py.py` (6), `tests/python/test_deviations_gate.py` + `test_spec_reconcile_gate.py` (117). pf-exec fence discovery unchanged at 11 templates.
**Branch:** feat/162-38-pf-py-policy-hardening-sentinels-blindspots (pushed)

**Handoff:** To Reviewer

### Fix Round 1 (Reviewer REJECTED — 1 HIGH, 1 MEDIUM, 2 LOW)

**Commit:** `04f7820f1` (signed, pushed)

| Finding | Addressed | How |
|---|---|---|
| [HIGH] `_bash_fences` drops 9 previously-swept bash bodies | Yes | `FENCE_DELIM_RE` now captures `(?P<ticks>`{3,})(?P<info>[^\s`]*)(?P<rest>[^`]*)`; a delimiter CLOSES only when `not info and not rest.strip() and len(ticks) >= open_ticks` (opening run length tracked). Also: attributed info strings (```bash title="x") now OPEN a fence instead of being read as body; blockquoted fences (`> ```bash`) are paired (step-01-connect.md's two bodies were regex-swept before); a NON-shell fence body is RESCANNED for inner shell fences instead of being discarded. Outer fences widened to four backticks in `skills/pf-ux-tandem/ux-tandem.md` and `workflows/project-setup/steps/step-05-shared-context.md` (the two docs that actually nested same-length fences; `judge.md`, `step-01-connect.md`, `step-04-claude-md.md` needed no edit once run-length pairing + rescan landed — measured, not assumed). Measured loss over the 358-template tree: **0**. |
| [HIGH] missing regression guard | Yes | `TestFenceScannerLosesNoPreviouslySweptBody` in `test_162_38_pf_py_policy_hardening.py`: baseline `OLD_BASH_FENCE_RE` (the pre-162-38 ```bash regex) vs `_bash_fences` over the real tree, per template, compared per CONTENT LINE (old-regex bodies carry pairing artifacts — trailing `> ` markers, closing-delimiter indentation — so raw body equality would false-alarm). Plus an anti-vacuity floor (baseline ≥ 200 content lines) and two unit cases (nested shell fence inside a ````markdown sample is swept; untagged YAML/Task body is not). |
| [MEDIUM] untagged non-shell block swept as shell | Yes | Kept untagged-in-`SHELL_INFO_STRINGS`, but `_is_shell_fence()` excludes an untagged body whose first content line is a YAML-style `key:` mapping (the `ux-tandem.md:54` Task spec). Non-shell bodies are still rescanned, so a real ```bash fence nested inside one stays under policy — the fix narrows the false-shell classification without narrowing coverage. |
| [LOW] doc conflates empty vs vague Spec source | Yes | `guides/deviation-format.md` now has a two-row table mapping empty → `has empty Spec source — must cite a specific document or section` (deviations.py:319) and non-empty-unspecific → `has vague Spec source '<value>' — …` (:324). |
| [LOW] sentinel count floor (marked Optional) | No | Declined: Reviewer ruled 1 sentinel sufficient and the floor "optional strengthening". Out of scope for a rework round; no test demands it. |

**Regression test before/after:** with the pre-fix scanner and pre-fix docs restored (`git stash` of all R1 changes, new test file copied in) → `2 failed, 2 passed` — `test_no_previously_swept_bash_line_left_the_sweep` and `test_untagged_non_shell_body_is_not_swept_as_shell` both FAIL. After the fix → all 4 pass. The guard reproduces the HIGH.

**Scoped runs:**
- `uv run pytest src/pf/tests/test_162_38_pf_py_policy_hardening.py src/pf/tests/test_162_8_template_pf_py_policy.py src/pf/tests/test_155_11_sm_finish_pf_py.py -q` → **58 passed in 1.98s** (36 + 16 + 6; 162-38 grew 32 → 36)
- `uv run pytest ../tests/python/test_deviations_gate.py ../tests/python/test_spec_reconcile_gate.py -q` → **117 passed**
- `ruff check` + `ruff format --check` clean on both touched test modules (the wider `src/pf/tests/` has pre-existing lint noise in untouched files).
- `_pf_exec_fences()` still reaches **15 fences across 11 templates** (all five gates included) — sweep coverage unchanged.

## Reviewer Assessment

**Verdict:** REJECTED (needs-rework — one HIGH)

**Verification run (mine, scoped):** `test_162_38_pf_py_policy_hardening.py` + `test_162_8_template_pf_py_policy.py` + `test_155_11_sm_finish_pf_py.py` → 54 passed. `tests/python/test_deviations_gate.py` + `test_spec_reconcile_gate.py` → 117 passed. `ruff check` clean. So the suite is green — and green is exactly the problem: the new fence scanner silently drops real bash fences with every test still passing, which is the unswept/blind failure mode this suite exists to prevent.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | `_bash_fences` mis-pairs nested/same-length fences and **drops 9 bash fence bodies the old `BASH_FENCE_RE` swept** (`skills/pf-ux-tandem/ux-tandem.md`, `skills/pf-judge/judge.md`, `workflows/interactive-debug/steps/step-01-connect.md`, `workflows/project-setup/steps/step-04-claude-md.md`, `step-05-shared-context.md`). Root cause: `FENCE_DELIM_RE` accepts **any** info string as a CLOSING delimiter and does not track backtick run length, so an inner ```` ```bash ```` line closes an enclosing ````` ```markdown ````/untagged block and every later pairing slides. Same class of bug as the one the deviation claims to fix, just in the other direction. Also drops the fence entirely when the opening has an attributed info string (```` ```bash title="x" ````) and then swallows the following real bash fence. | `src/pf/tests/test_162_8_template_pf_py_policy.py:_bash_fences` / `FENCE_DELIM_RE` | Track the opening tick count and only close on a delimiter with an EMPTY info string whose run length ≥ the opening (`^[ \t]*(?P<ticks>`{3,})(?P<info>[^\s`]*)[ \t]*$`, close iff `not info and len(ticks) >= open_ticks`). Verified locally: this recovers 3 of the 9 immediately; the rest are genuinely nested same-length fences in the four files above and need either 4-backtick outer fences in those docs or an explicit nesting decision. Add a pinning test: for every template, no fence body that `BASH_FENCE_RE` used to yield may vanish from `_bash_fences` (the missing regression guard). |
| [MEDIUM] | Treating `""` as a shell info string means untagged **non-shell** blocks are now swept as bash. Concretely `skills/pf-ux-tandem/ux-tandem.md:54` is an untagged Task-tool YAML spec whose body is now a "shell fence". Harmless today (no pf python inside), but any doc block that quotes `python3 -c "from pf..."` inside an untagged fence will fail the policy gate on a file no agent executes as shell. | same | Either restrict untagged sweeping (e.g. skip bodies that parse as `key:`-leading YAML / Task specs) or accept it explicitly with a comment + a test recording the trade-off. |
| [LOW] | `guides/deviation-format.md` says an **empty** Spec source "fails the gate with `vague Spec source '<value>' — …`". `deviations.py:319` emits a different message for empty (`has empty Spec source — must cite a specific document or section`); the `vague` message is the non-empty-but-unspecific branch (`:324`). | `pennyfarthing-dist/guides/deviation-format.md` | Split the two sentences, or drop "An empty value, or". |
| [LOW] | Sentinel robustness: `SENTINEL_TEMPLATES` names one gate file; the comment asserts "five pf-executing gate templates". A filename sentinel dies on rename. | `test_162_8_template_pf_py_policy.py:SENTINEL_TEMPLATES` | Optional: add a count floor (≥5 `gates/` entries in `_pf_exec_fences()`), which survives renames better than more filenames. |

**Ruling — 1 sentinel vs 5:** ONE is sufficient. Verified `_pf_exec_fences()` reaches all five gates (`ac-completion, deviations-logged, spec-check, spec-drift-precheck, spec-reconcile-pass`) plus `scripts/test/README.md` and both `scenario-builder/step-06-validate.md` — 11 templates. The sentinel's job is anti-vacuity for root discovery, and one `gates/` entry proves the `gates` root is swept and the gate fence shape still matches; the other four share root and shape, so they add churn, not detection. Not a gap. The count-floor idea above is the cheap strengthening, not five filenames.

**Regex widening — adversarial result: no over-match.** Detects `python3.12 -c`, `python3.12 -m pf.x`, dash-less `python3 <<'PYEOF'`, `python3 <<<`, `python -c'…'`. Negative guards intact: `"${PF_PY:?msg}" -m`, `"${PF_PY:?msg}" - <<`, `"${PF_PY:?msg}" <<` all BARE=0 (caught via the PF_PY-expansion path instead); `python3-config --libs` no match; `.venv/bin/python3 <<EOF` and `/usr/bin/python3 -c` excluded from BARE by the existing lookbehind and handled by the VENV/ANY rules. Pre-existing (not introduced) false negatives: `python3.12.1`, `pythonw`, `python -cfoo`, `python3 -B -c`. Pre-existing false positives: `python3 -c` inside a `#` comment or an `echo "…"` string is still flagged. None of these are regressions.

**Fence scanner soundness: UNSOUND as written** (see HIGH). Cases tried, NEW vs OLD: yaml-then-bash ✓; untagged ✓ (new capability); attributed info string ✗ (drops body AND swallows the next real bash fence); 4-backtick outer wrapping ```bash — sweeps the example (unchanged from OLD); `~~~` block containing a ``` line — now mis-swept; unterminated trailing fence — dropped (same as OLD, acceptable); indented list fence ✓; delimiter with trailing spaces ✓ (new capability); consecutive untagged ✓; no trailing newline ✓; ```python/```yaml/```json not swept ✓. Then measured against the real tree (358 templates): 9 previously-swept bodies lost.

**Blind spot documented, not falsely closed:** confirmed. Module docstring KNOWN LIMITATION is accurate — `source .venv/bin/activate && python3 script.py` yields BARE=0/ANY=0/`_executes_pf`=False, exactly matching the prose, and `test_no_live_script_path_offender_in_the_tree` keeps the gap latent. TEA's `gates/quality-pass.md` finding is a real instance of the shape.

**deviation-format doc vs `_VALID_SPEC_SOURCE_RE`:** accurate apart from the LOW above. All five accepted forms map 1:1 to the regex alternatives (`\S+\.\w+`, `AC-?\d+`, `[Ss]ection\s+\d+`, `SOUL\.md`, `##?\s+`), the gate message is quoted verbatim from `deviations.py:328`, and `test_guide_shows_a_rejected_counter_example` / `test_guide_accepted_examples_pass_the_real_validator` validate the doc's examples against the imported regex rather than a copy — good anti-drift design.

**Test hygiene:** non-vacuous. Real negative guards (`test_non_shell_info_strings_are_still_not_swept`, `test_guarded_dashless_heredoc_is_not_flagged_as_bare`, `test_pf_py_expansion_is_still_not_flagged_as_bare_python`), every sentinel checked for on-disk existence, and tree-wide "no live offender" guards keeping widenings honest. The one missing test is the fence-rewrite regression guard named in the HIGH.

**Deviation audit:** TEA's untagged-fence disposition — **ACCEPTED** (measured the tree first; matches 162-8's close-it-if-cheap bar). Dev's line-scanner deviation — **FLAGGED**: the stated rationale is sound, but the implementation reintroduces the same mis-pairing it was meant to eliminate. No undocumented deviations found.

**Handoff:** Back to Dev

## Subagent Results

Re-review round (scoped to `a98e554c9..04f7820f1`). **All received: Yes** (5/5).

| # | Specialist | Received | Status | Findings | Decision |
| 1 | reviewer-preflight | Yes | clean | 58 passed / 0 failed; ruff check + format PASS; 0 code smells (no TODOs, skips, commented code, debug leftovers); diff 5 files +168/-9 | N/A |
| 2 | reviewer-rule-checker | Yes | clean | none — all 5 changed paths are regular files under `pennyfarthing-dist/` (source of truth), no `.pennyfarthing/` symlink or `node_modules/` edits, no runtime-path violations | N/A |
| 3 | reviewer-security | Yes | findings | (a) `_is_shell_fence` YAML heuristic = sweep-evasion shape for untagged fences (medium conf); (b) unbounded recursion in the non-shell rescan (low conf) | (a) CONFIRMED → [LOW] non-blocking; (b) DISMISSED |
| 4 | reviewer-test-analyzer | Yes | findings | (a) per-file content-line SET comparison can mask a dropped fence whose lines are duplicated by a sibling fence; (b) `any("-m pf." in f)` passes on an over-broad envelope; (c) anti-vacuity floor is a unique-line count only; (d) `bash{.x}` pandoc info string untested; (e) `_is_shell_fence` first-content-line-only boundary untested | (a) CONFIRMED, quantified → [LOW]; (b) CONFIRMED → [LOW]; (c),(e) noted, non-blocking; (d) DISMISSED (not a regression) |
| 5 | reviewer-type-design | Yes | findings | (a) `_is_shell_fence(info, body)` receives `str \| None` at the call site; (b) `open_ticks` is parallel implicit state that must stay in sync with `info`; (c) `""`-means-untagged vs `None`-means-closed in-band sentinel collision | all three CONFIRMED as design observations → [LOW] non-blocking (no live defect; control flow narrows correctly and no mypy gate exists on this package) |

## Reviewer Assessment

**RE-REVIEW — Fix Round 1 (`a98e554c9..04f7820f1`)**

**Verdict:** APPROVED

**Verification run (mine, scoped):** `test_162_38_pf_py_policy_hardening.py` + `test_162_8_template_pf_py_policy.py` + `test_155_11*.py` → **58 passed in 1.84s**. `ruff check` + `ruff format --check` clean on both touched modules. Working tree clean, branch correct.

| Prior finding | Verdict |
|---|---|
| [HIGH] `_bash_fences` drops 9 previously-swept bash bodies + missing regression guard | **ADDRESSED** |
| [MEDIUM] untagged non-shell block swept as shell | **ADDRESSED** |
| [LOW] doc conflates empty vs vague Spec source | **ADDRESSED** |
| [LOW] sentinel count floor | **NOT ADDRESSED — accepted** (I marked it Optional; my own ruling was that one sentinel is sufficient) |

**Zero-fence-loss: independently verified, not taken on trust.** I wrote my own comparison (`/tmp/verify_fences.py`) rather than trusting the new test's normalizer, over all 358 templates:
- Old `BASH_FENCE_RE` = 441 bodies; new `_bash_fences` = 624. **Content-line losses: 0.**
- Stricter whole-body-containment check: 2 "misses", both in `workflows/interactive-debug/steps/step-01-connect.md` — artifacts of the `> ` blockquote prefix the old regex carried into its bodies. Content is present in the new coverage. Not losses.
- **Policy-relevant outcome identical:** `_executes_pf` over old bodies = 15 fences / 11 templates; over new bodies = 15 fences / 11 templates. Zero templates lost, zero gained, no per-file count drift. So the rewrite is a strict superset in coverage and a no-op in current policy verdicts.
- Superset claim confirmed structurally too: only a line *starting* with 3+ backticks can open a fence (`^[ \t]*(?:>[ \t]*)*`), so prose mentioning ```` ```bash ```` mid-sentence cannot false-open; an attributed opening now opens instead of being read as body; over-inclusive merges (e.g. a `` ``` done `` line that no longer closes) keep content in the sweep rather than dropping it.

**Regression guard is genuinely reproducing the HIGH — not vacuous.** Ran the new test file against the pre-fix scanner and pre-fix docs in a detached worktree at `a98e554c9`: `2 failed, 2 passed` — `test_no_previously_swept_bash_line_left_the_sweep` and `test_untagged_non_shell_body_is_not_swept_as_shell` both fail with the exact loss listings. The anti-vacuity floor (baseline ≥ 200 content lines) is real (baseline is well above it), and the guard is tree-wide, so any future doc that reintroduces same-length nesting fails loudly instead of silently leaving the policy. This is the right fix for the failure class, not just for the 9 instances.

**[MEDIUM] `_is_shell_fence()` — both directions tested.** Untagged Task/YAML body (`Task:\n  subagent_type: …` containing `python3 -m pf.x`) → NOT swept ✓. Genuinely-shell untagged fence (`python3 -c "from pf.sprint.status import main"`) → swept, `_executes_pf` True ✓. Untagged shell starting with a `#` comment → swept ✓. Coverage is not narrowed: `ux-tandem.md:54`'s non-shell body is still **rescanned**, and its inner ```bash at :72 is swept.

**[LOW] doc:** two-row table matches `deviations.py` exactly — `:319` empty → `has empty Spec source — must cite a specific document or section`; `:324` non-empty-unspecific → `has vague Spec source '<value>' — must reference a file path, AC, or section`. Verified against the source, not the diff.

**NEW-BREAKAGE SCAN of the added complexity — nothing Critical/Important.** 20 adversarial docs run through the new scanner:
- attributed info string, closed (`bash`/`yaml`/`markdown`, 3- and 4-tick) → pairs correctly, following real fence still swept ✓
- attributed fence never closed → swallows to the next bare delimiter; content stays *inside* a swept body (no loss). If the unclosed fence is NON-shell, the rescan drops the inner shell fence — but that is a malformed-doc shape with **0 live instances**, and the tree-wide guard catches any introduction.
- blockquote fence interleaved with a normal fence (`> ```bash` … then plain ```` ```bash ````) → 2 fences, both swept ✓; mixed `>`-open/plain-close also pairs ✓
- non-shell outer → nested non-shell → sibling shell fence (````markdown / ```yaml / ```bash) → both shell bodies swept, yaml not ✓; 5-deep nesting ✓
- shell outer containing a shell inner → **one** body, not two — **no double-counting** anywhere; a body is either swept or rescanned, never both. Recursion terminates (body strictly shorter than input).
- `~~~bash` and an info string containing a backtick → not swept; both were also invisible to the old regex, so not regressions.
- **Widened docs verified:** `ux-tandem.md` (outer ```` at 54/114, inner ```bash at 72) → 5 fences, inner shell fence swept, backtick balance intact; `step-05-shared-context.md` (outer ```` at 103/134, four inner ```bash) → 7 fences, all inner fences pair. Both are now *valid* CommonMark where they previously were not — rendering improved, not broken. No non-markdown consumer references either path.

**Residual latent gaps (LOW, non-blocking, no live instances, all guarded by the tree-wide test):**
1. **[SEC]** `UNTAGGED_YAML_KEY_RE` false-negative — CONFIRMED, severity downgraded. An untagged fence that *is* shell but whose first content line matches `key:` (e.g. `usage: pf …` then `python3 -c "from pf…"`) is not swept; `reviewer-security` frames it as a deliberate sweep-evasion shape. Verified by hand: `usage: pf\npython3 -c "from pf.x import y"` → 0 fences. Not blocking, because (i) it only narrows the *new* untagged capability and never drops below the old `BASH_FENCE_RE` baseline (which swept no untagged fence at all), (ii) 0 live instances, (iii) the threat model is a template author evading a lint gate in a repo they can already commit to — not a security boundary. Cheap hardening for a follow-up: require *every* content line to be YAML-key-shaped rather than just the first, or bail out of the heuristic if the body contains `python`/`${PF_PY`.
2. Same-length nested fences (3-tick non-shell wrapping 3-tick shell) and unterminated non-shell fences still lose the inner body. 0 live instances after the two doc widenings; the Delivery Finding about malformed nesting in dist docs stands as the durable fix.
3. **[TEST]** Guard sensitivity — CONFIRMED and quantified. `test_no_previously_swept_bash_line_left_the_sweep` compares per-file content-line *sets*, so a future dropped fence whose every line is duplicated by a sibling fence in the same file would be invisible. I measured the blind spot: **15 of 441** old bodies (3.4%) are subset-maskable, so the guard is ~96.6% sensitive — and it detected 100% of the actual 9-body regression. I also ran the stronger form (each old body's line-set must be a subset of a *single* new body's line-set): **0 failures today**, so the strengthening is free and there is no loss currently hiding behind the weaker comparison. Follow-up nicety, not a blocker.
4. **[TEST]** `test_inner_shell_fence_inside_a_markdown_sample_is_still_swept` asserts `any("-m pf." in f)`, which would also pass on a scanner returning the whole ````markdown envelope. Tighten to an exact-body assertion. Dismissed as blocking: I verified the actual return is the inner body only. The `bash{.x}` pandoc-attribute case is **DISMISSED** — the old regex did not sweep it either, so it is not a regression.
5. **[TYPE]** State-machine shape — CONFIRMED as observations, no live defect. `info: str | None` is passed to `_is_shell_fence(info: str, …)` (safe: the `if info is None: … continue` branch narrows it, and no mypy gate runs on this package — `ruff` only); `open_ticks` is parallel implicit state kept in sync only by execution order; `""` (untagged) and `None` (closed) are both falsy, so the three-way distinction rests on `is None` discipline. Collapsing a single `if info is None` into `if not info` would reintroduce the fence-dropping bug — the tree-wide guard would catch it, which is precisely why the guard matters more than the type shape here. A `_Closed`/`_Open(info, ticks, body)` variant pair would make it structurally impossible; worth doing if this scanner is ever promoted out of the test module into `pf/validate/` (see TEA's standing Delivery Finding).
6. **[SEC]** Unbounded recursion in the non-shell rescan — **DISMISSED**. Depth equals non-shell fence nesting depth; the deepest committed template nests 2, input is repo-local markdown only, and the reporting specialist itself rated it low confidence. Would matter only if `_bash_fences` were ever exposed to untrusted text.

**[RULE] Project-rule compliance: clean.** All five changed paths are regular files under `pennyfarthing-dist/` (the single source of truth) — no `.pennyfarthing/` symlink-target edits, no `node_modules/`, no sprint-YAML hand-editing, no runtime script pointed at `pennyfarthing-dist/`. The result-object rule does not apply (test-module predicates, assertions not error returns). Signed commit `04f7820f1` on the correct branch, working tree clean.

**Deviation audit:** Dev's line-scanner deviation — previously FLAGGED, now **ACCEPTED**: the implementation matches the stated rationale and the measured claim holds under independent verification. Both fix-round-1 deviations (four-backtick outer fences in two docs; rescan of non-shell bodies) — **ACCEPTED**, each cites the Reviewer finding as spec source, and "measured, not assumed" checks out (I reproduced the measurement). TEA's untagged-fence disposition — **ACCEPTED** (unchanged). No undocumented deviations.

**Handoff:** To SM for finish-story

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T13:19:36Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T12:40:45Z | 2026-08-12T12:42:09Z | 1m 24s |
| red | 2026-08-12T12:42:09Z | 2026-08-12T12:48:38Z | 6m 29s |
| green | 2026-08-12T12:48:38Z | 2026-08-12T12:54:14Z | 5m 36s |
| review | 2026-08-12T12:54:14Z | 2026-08-12T13:19:36Z | 25m 22s |
| finish | 2026-08-12T13:19:36Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): the PF_PY policy sweep lives entirely inside a test module (`src/pf/tests/test_162_8_template_pf_py_policy.py`), so hardening it means editing a test file rather than production code. Affects `pennyfarthing-dist/src/pf/` (a future story could promote the sweep predicates into e.g. `pf/validate/` and have `pf validate` run it, with the test file as a thin caller). *Found by TEA during test design.*
- **Gap** (non-blocking): `gates/quality-pass.md` runs `source .venv/bin/activate && python3 .pennyfarthing/scripts/workflow/check.py` — the exact script-path shape in the documented blind spot. `check.py` does not import `pf` today, so it is not a live gh #112 offender, but the fence would be invisible if it ever did. *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings.

### Reviewer (code review)
- **Gap** (non-blocking): four dist templates nest same-length fences (an inner bash fence inside an untagged or `markdown` block) — `skills/pf-ux-tandem/ux-tandem.md:54`, `skills/pf-judge/judge.md`, `workflows/interactive-debug/steps/step-01-connect.md`, `workflows/project-setup/steps/step-04-claude-md.md`, `workflows/project-setup/steps/step-05-shared-context.md:103`. That is malformed CommonMark and is what makes any correct fence pairer lose those inner fences. Affects `pennyfarthing-dist/` (outer fences should use four backticks, or the docs restructured) — fixing it would make the 162-8 sweep robust without special-casing. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Untagged fence dispositioned as intended-fix, not documented gap**
  - Spec source: .session/162-38-session.md, SM Assessment deliverable 3
  - Spec text: "either the sweep catches them, or the test documents the known gap; follow 162-8's disposition style"
  - Implementation: all three blind-spot shapes (dash-less heredoc, python3.12, untagged fence) are asserted as INTENDED FIXES; only the script-path shape is pinned as a documented gap
  - Rationale: measured the tree first — 0 untagged pf-executing fences, 0 dash-less heredocs, 0 version-suffixed interpreters — so widening the sweep is cheap and cannot break the 162-8 suite, which is 162-8's own bar for "close it rather than document it"
  - Severity: minor
  - Forward impact: none

### Dev (implementation)
- **Untagged-fence support replaced the fence regex with a line-based scanner**
  - Spec source: .session/162-38-session.md, SM Assessment deliverable 3
  - Spec text: "Pin the sweep blind-spot shapes with tests: ... (c) untagged fence"
  - Implementation: `_bash_fences` now pairs fence delimiters line-by-line (`FENCE_DELIM_RE` + `SHELL_INFO_STRINGS`); `BASH_FENCE_RE` removed
  - Rationale: merely allowing an empty info string in the whole-text regex makes the CLOSING delimiter of a ```yaml block look like the OPENING of an untagged fence, shifting every later pairing and silently dropping real bash fences from the sweep
  - Severity: minor
  - Forward impact: none

### Dev (implementation) — fix round 1
- **Two dist docs rewritten to four-backtick outer fences**
  - Spec source: .session/162-38-session.md, Reviewer Assessment HIGH
  - Spec text: "need either 4-backtick outer fences in those docs or an explicit nesting decision"
  - Implementation: `skills/pf-ux-tandem/ux-tandem.md` and `workflows/project-setup/steps/step-05-shared-context.md` outer fences widened to four backticks; the other three named docs were left alone because run-length pairing plus non-shell-body rescan already recovers their fences (measured: 0 lost content lines tree-wide)
  - Rationale: fixing malformed CommonMark in the docs is cheaper and more correct than special-casing the scanner, and touching only the docs that actually need it keeps the diff honest
  - Severity: minor
  - Forward impact: none
- **Scanner rescans non-shell fence bodies instead of discarding them**
  - Spec source: .session/162-38-session.md, Reviewer Assessment MEDIUM
  - Spec text: "Either restrict untagged sweeping ... or accept it explicitly with a comment + a test recording the trade-off"
  - Implementation: untagged bodies whose first content line is a YAML-style mapping are not treated as shell, and every non-shell body is rescanned for nested shell fences
  - Rationale: a shell fence inside a four-backtick markdown sample IS an execution site (the sample is copied into a CLAUDE.md an agent then runs), so restricting the classification must not restrict coverage — otherwise the new regression guard goes red
  - Severity: minor
  - Forward impact: none