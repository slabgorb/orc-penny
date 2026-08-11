---
story_id: "162-31"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-31: Quarantine exit-loudness + meta-guard hardening: strict=False xfails XPASS silently when B1/B2/B4 land — add a forcing function (strict where safe, or extend test_162_5_quarantine_policy to fail on XPASS); tighten the gameable tracking-reference regex; close the pytestmark/runtime-xfail discovery bypass; fix the two remaining vacuous portrait tests (:274, :372, same if-called pattern 162-5 fixed at :397); dedup the 4x 15-line quarantine comment in test_143_9 (from 162-5 review)

## Story Details
- **ID:** 162-31
- **Jira Key:** (not tracked in Jira — sprint-only)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-31-quarantine-exit-loudness-metaguard-hardening
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the title is the full spec — a 162-5 review follow-up with FIVE concrete deliverables in the canonical test tree (`pennyfarthing-dist/src/pf/tests/`):

1. **Quarantine exit-loudness:** the 162-5 quarantines are `xfail(strict=False)`, so when the underlying bugs (B1/B2/B4) get fixed the tests XPASS and the run still exits 0 — nobody is told to lift the quarantine. Add a FORCING FUNCTION: make the markers `strict=True` where safe, OR extend `test_162_5_quarantine_policy.py` to FAIL when a quarantined test XPASSes. Choose based on which is safe (some quarantines may be legitimately flaky/non-strict — inspect each).
2. **Tighten the gameable tracking-reference regex** in `test_162_5_quarantine_policy.py`: 162-5's review found it accepts junk like "flaky 3-14 on macos", "see 1-1", a bare year-month date. Require a real story reference (e.g. `\d+-\d+` in a recognizable context).
3. **Close the pytestmark/runtime-xfail discovery bypass:** the meta-guard's marker scan walks decorator lists only, so a module-level `pytestmark = pytest.mark.xfail(...)` or a runtime `pytest.xfail()` call bypasses the policy entirely. Extend discovery to catch module-level markers (and runtime xfail if feasible).
4. **Fix two remaining VACUOUS portrait tests** at lines ~274 and ~372 — same "if called" pattern that 162-5 already fixed at ~:397. Find the portrait test file (grep for the :397 fix pattern), apply the same de-vacuuming.
5. **Dedup the 4× ~15-line quarantine comment** in `test_143_9*` — extract to a single shared constant/reference. Cosmetic but in-scope.

**TEA (RED):** write failing tests that pin the meta-guard's NEW obligations — (a) a fixture quarantine that XPASSes is DETECTED/fails the policy; (b) a junk tracking-reference is REJECTED; (c) a module-level/runtime xfail bypass is CAUGHT. For the vacuous portrait tests, demonstrate they currently pass without exercising the real call (mutation: break the production path, test still green) — then they become RED once de-vacuumed. The dedup is a refactor (no behavior change) — a structural assertion is optional.

**Constraints (binding):** canonical tree only; scoped runs — `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_5_quarantine_policy.py src/pf/tests/<portrait> -q`; NEVER the full suite. Do NOT weaken the existing meta-guard. `ruff check` changed files. Result objects, no throws. Be careful: `strict=True` on a marker whose bug is NOT yet fixed will correctly stay xfail — only flip markers whose behavior warrants it; don't turn a real quarantine into a hard failure.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED — 15 failing in `test_162_31_quarantine_hardening.py`; existing 162-5 guard untouched and still green (29 passed across both scoped files).

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_31_quarantine_hardening.py` (NEW) — deliverables 1-3
- `pennyfarthing-dist/src/pf/tests/test_peloton_portrait_panes.py` (MODIFIED) — deliverable 4, de-vacuumed :274 and :372

**Scoped run:** `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_31_quarantine_hardening.py src/pf/tests/test_162_5_quarantine_policy.py src/pf/tests/test_peloton_portrait_panes.py -q`

### Deliverable 1 — XPASS forcing function (4 RED)

Pinned API Dev must add to `test_162_5_quarantine_policy.py`:
`find_xpasses(targets: list[Path]) -> list[str]` — runs pytest over `targets` and returns ids of tests that XPASSed (i.e. `xfail` markers whose bug is fixed). Detection must be runtime, not source-regex.

- `TestXpassIsLoud::test_xpassing_quarantine_is_detected` — `ImportError: cannot import name 'find_xpasses' from 'pf.tests.test_162_5_quarantine_policy'`
- `::test_still_failing_quarantine_is_not_reported` — same ImportError (reject-side control: live debt must NOT be flagged)
- `::test_clean_module_is_not_reported` — same ImportError
- `::test_in_scope_modules_have_no_xpass` — same ImportError (this is the actual policy; goes red when B1/B2/B4 land, which is the point)

Note: the import is deliberately lazy inside a local `find_xpasses` adapter — a module-scope import of a missing name is a *collection* error that would hide deliverables 2 and 3.

### Deliverable 2 — tracking-reference regex (6 RED)

`TestTrackingReferenceIsNotGameable`, parametrized. Currently-accepted junk that must be rejected:

- `test_junk_is_rejected[flaky 3-14 on macos]` — `AssertionError: 'flaky 3-14 on macos' is not a followable tracking reference`
- `test_junk_is_rejected[see 1-1]` — same shape
- `test_junk_is_rejected[quarantined 2026-08]` — same shape
- `test_junk_is_rejected[known bad since 2026-08-11]` — same shape
- `test_junk_is_rejected[top #5 flake in the suite]` — same shape
- `test_real_references_are_accepted[see PF-1234]` — `AssertionError: 'see PF-1234' is a legitimate tracking reference and must still be accepted`

Accept-side cases already green (`story 162-31: ...`, `tracked by story 3-14`, `epic 162 story 162-5 ...`, `gh #113`, `github #113`, `issue #113`) — do not regress them. Intended rule: a bare `\d+-\d+` or bare `#\d+` is not enough; require a keyword context (`story`/`epic`/`gh`/`github`/`issue`/`bug`/`pr`) or a Jira key (`PF-1234`).

**Dev must also update two 162-5 fixtures** (fixture text, not a weakening): `SYNTHETIC_MODULE`'s xfail reason `"synthetic 999-1: ..."` and the literal `_TRACKING_RE.search("162-29")` at ~:229 both rely on the bare-`\d+-\d+` form and will fail under the tightened regex. Reword to `"synthetic story 999-1: ..."` / `"story 162-29"`.

### Deliverable 3 — discovery bypass (5 RED)

`_markers_in_source` walks `decorator_list` only. Pinned contract: module-level `pytestmark` reported under the name `"<module>"`; a runtime `pytest.xfail("...")` reported under its enclosing test's name; `_reason_of` must also read a *positional* reason (runtime `pytest.xfail`).

- `TestDiscoveryCatchesBypasses::test_module_level_pytestmark_is_discovered` — `AssertionError: a module-level 'pytestmark = pytest.mark.xfail(...)' quarantines every test in the file and currently bypasses the policy entirely`
- `::test_module_level_pytestmark_list_is_discovered` — `AssertionError: assert [] == ['<module>']`
- `::test_runtime_xfail_call_is_discovered` — `AssertionError: a runtime pytest.xfail() call must be attributed to its test, got: []`
- `::test_runtime_xfail_reason_is_extracted` — `IndexError: list index out of range` (nothing discovered)
- `::test_module_level_bypass_is_subject_to_the_reason_policy` — `AssertionError: assert [] == ['<module>']`

Reject-side controls already green: `pytestmark = pytest.mark.slow` is ignored; returned nodes stay `ast.expr` so `ast.unparse` in the offender reports keeps working.

### Deliverable 4 — portrait vacuity: MUTATION PROOF

The two tests at `test_peloton_portrait_panes.py:274` and `:372` guarded their assertions behind `if mock_split.called:` — with no split, the loop body and the `else: pytest.fail(...)` never ran.

Proof (production mutated: `_maybe_add_portrait`'s `if self._use_tmux:` forced to `if False:`, so the portrait pane is created without any `split_pane` call — the exact regression these tests claim to catch):

| variant | result under mutated production |
|---------|---------------------------------|
| ORIGINAL (`if mock_split.called:`) | **2 passed** — vacuous, caught nothing |
| DE-VACUUMED (`assert mock_split.called` first) | **2 failed** at `:274` / `:381` |

Production file restored bit-for-bit after the experiment (`git status` clean apart from the two test files).

**These two are GREEN against unmutated production** — the real code does call `split_pane("h", 20)`, so de-vacuuming needs no Dev fix. The RED here is the mutation, not the current run. Dev: do not "fix" these; just do not reintroduce the shield.

### Deliverable 5 — test_143_9 comment dedup

No RED written — a no-behavior-change refactor (4x ~15-line quarantine comment → one shared reference). Dev handles it directly.

**Commit:** `2b7678d12` (signed)
**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/tests/test_162_5_quarantine_policy.py` — four changes:
  - **D1:** added `find_xpasses(targets: list[Path]) -> list[str]` — runs pytest in a subprocess with `-rX --tb=no` and parses the `XPASS ` short-summary lines, so detection is a real run, not a source regex. Returns offender ids (empty list when clean); the caller decides whether an XPASS is a failure, so no throws.
  - **D2:** tightened `_TRACKING_RE` to `\b(?:story|epic|issue|bug|pr|gh|github)\s*#?\s*\d+(?:-\d+)?\b|\b[A-Z][A-Z0-9]+-\d+\b` — a number only counts inside a context keyword, or as a Jira key. Bare `\d+-\d+` and bare `#\d+` no longer qualify.
  - **D3:** extended `_markers_in_source` with `_module_level_markers` (module-level `pytestmark`, single and list/tuple form, reported under `"<module>"`) and `_runtime_xfail_markers` (`pytest.xfail()` calls attributed to the enclosing function, deduped by node identity so a nested def is not double-reported). `_reason_of` now also reads a *positional* reason, restricted to non-`mark.*` calls — for `mark.skipif(cond, ...)` the first positional is the condition, and reading it would invent references.
  - Two fixture rewords per TEA's callout (fixture text, not a weakening): `SYNTHETIC_MODULE`'s xfail reason `"synthetic 999-1"` → `"synthetic story 999-1"`, and `_TRACKING_RE.search("162-29")` → `"story 162-29"`. Added a matching reject-side line (`not _TRACKING_RE.search("flaky 3-14 on macos")`) so the 162-5 liveness guard now pins the tightened rule too.
- `pennyfarthing-dist/src/pf/tests/test_143_9_tdd_cycle_e2e.py` — **D5:** the 4× ~8-line quarantine comment collapsed to one module-level `VERIFY_PHASE_UNQUARANTINE_NOTE` constant; each site now carries a one-line reference.
- `pennyfarthing-dist/src/pf/tests/test_peloton_portrait_panes.py` — **D4:** no Dev change needed. TEA's de-vacuumed `:274` / `:372` assertions (`assert mock_split.called` ahead of the shape checks) pass against unmutated production — the real code does call `split_pane(session, target, "h", 20)`, so `args[2]`/`args[3]` resolve. Production and test already agree; the shield was simply removed and not reintroduced.

**Tests:** 112/112 passing (GREEN) across the scoped run — was 15 failed / 97 passed at RED.
- `test_162_31_quarantine_hardening.py`: 15/15 (all 15 RED now green)
- `test_162_5_quarantine_policy.py`: **7/7 still green**
- `test_peloton_portrait_panes.py`: **22/22 still green** — 7 + 22 = the 29 TEA measured, unchanged
- `test_143_9_tdd_cycle_e2e.py`: 68/68 still green (dedup is behavior-neutral)

`ruff check` clean on all four files. Scoped runs only, never the full suite.

**Branch:** `feat/162-31-quarantine-exit-loudness-metaguard-hardening` (pushed)
**Commit:** `265df0efc` (GPG signed, verified)

**Handoff:** To Reviewer

## Subagent Results

**All received: Yes** (6 of 6 — the 5 enabled specialists plus reviewer-silent-failure-hunter, spawned as an extra given this story is entirely about a guard going silently green.)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 112 passed / 0 failed / 8.32s; ruff clean; HEAD GPG-signed; tree clean; scope confined to `src/pf/tests/` | N/A — corroborated by my own scoped run |
| 2 | reviewer-rule-checker | Yes | clean | 5 rules / 18 instances / 0 violations. Confirms edits are in the source tree (not `.pennyfarthing/` symlink targets), `cwd` resolves to the framework repo root, and the no-throw rule is honored | Accepted — no findings to carry |
| 3 | reviewer-security | Yes | findings | 2 Low: (a) no `timeout=` on the `find_xpasses` subprocess (CWE-400); (b) `literal_eval` handler misses `RecursionError`. Confirms `shell=False`/argv-form so no injection, no secrets, no dev paths, `literal_eval` not `eval` | (a) CONFIRMED → folded into [LOW-7]; (b) DISMISSED — requires a malicious commit to our own source tree; noted, not tracked |
| 4 | reviewer-test-analyzer | Yes | findings | 3 High-confidence vacuity findings, all one root cause: `find_xpasses` ignoring `returncode` makes the three `== []` assertions pass under a collapsed subprocess (proven by stubbing). Independently reproduced the portrait mutation proof and confirmed the discovery tests are non-vacuous against pre-fix code | CONFIRMED as one finding → [MEDIUM-1]; severity held at Medium on the mitigation evidence below |
| 5 | reviewer-type-design | Yes | findings | 1 High + 4 Low: `returncode` overload (same root cause as #4); `"<module>"` stringly-typed sentinel; `_reason_of` tri-state `None` collapse; `(str, ast.expr)` tuple vs NamedTuple; confirms PEP 604 `isinstance` unions are valid at the declared 3.11.4 floor | `returncode` MERGED into [MEDIUM-1]. Sentinel DISMISSED — no Python function can be named `<module>`, no consumer branches on it, and the `<unknown>` sentinel is pre-existing precedent. Tri-state and NamedTuple DISMISSED as stylistic: no current or proposed consumer needs the distinction. Version check → verified good |
| 6 | reviewer-silent-failure-hunter (extra) | Yes | findings | 3: `find_xpasses` returncode (same root cause); tree-wide `rglob` + swallowed `SyntaxError` means an unparseable module outside `IN_SCOPE_MODULES` is silently "quarantine-free"; `SYNTHETIC_MODULE` not extended to the new declaration forms | Returncode MERGED into [MEDIUM-1]. Swallowed `SyntaxError` CONFIRMED but PRE-EXISTING (162-5, untouched by this diff) → noted in [LOW-6] scope, not charged to this story. `SYNTHETIC_MODULE` gap CONFIRMED → [LOW-6] |

**Cross-specialist conflict resolved:** [TYPE] argues `find_xpasses` violates the project's result-object rule; [RULE] judged that rule as scoped to CLI handlers and production APIs, noting all five sibling helpers in the same module return plain values. I side with [RULE] on the rule question — `list[str]` is the established test-helper contract here. [MEDIUM-1] therefore stands on the false-green/ambiguity evidence, **not** on a rule violation.

## Reviewer Assessment

**Verdict:** APPROVED (7 non-blocking findings — 4 Medium, 3 Low; no Critical, no High)

**Scoped run (mine):** 112 passed / 0 failed in 8.32s across the four files; `ruff check` clean; HEAD `265df0efc` GPG-signed and verified; tree clean; diff confined to `pennyfarthing-dist/src/pf/tests/` (4 files, +497/-62). `test_162_5_quarantine_policy.py` standalone: **7/7 green in 4.71s.**

**162-5 meta-guard NOT weakened — verified structurally, not taken on trust:**
- Every change to the guard is additive. No test removed, no assertion loosened.
- `_reason_of`'s new positional branch is gated on `"mark." not in ast.unparse(dec.func)`. I confirmed every decorator marker and every `_module_level_markers` item unparses containing `mark.`, so the branch is unreachable for them — it cannot manufacture a reason for a previously-anonymous marker. Only the new runtime-xfail path uses it.
- The two fixture rewords are text (`"synthetic 999-1"` → `"synthetic story 999-1"`, `_TRACKING_RE.search("162-29")` → `"story 162-29"`), forced by a *stricter* regex — the definition of not-loosening.
- The guard gained a reject-side assertion (`not _TRACKING_RE.search("flaky 3-14 on macos")`), so it now pins the tightened rule from inside itself.

**Per-deliverable soundness**

| # | Deliverable | Ruling |
|---|---|---|
| 1 | XPASS forcing function | SOUND, with a gap. `find_xpasses` genuinely detects a synthetic XPASS. But it ignores `proc.returncode` — see [MEDIUM-1]. |
| 2 | Tightened tracking regex | SOUND for the named junk; INCOMPLETE. All 5 named junk cases + `''` + `'fails 2 of 3 runs'` reject; all 7 real refs accept. My own adversarial probe found residual holes — [MEDIUM-2], [MEDIUM-3]. |
| 3 | Discovery bypass | SOUND and broader than required — discovery feeds `_iter_quarantine_markers`, which rglobs the WHOLE tree, so module-level + runtime xfail are now policed tree-wide, not just in-scope. One obvious adjacent bypass remains — [MEDIUM-4]. |
| 4 | Portrait de-vacuum | SOUND — mutation proof independently reproduced. Mutated `_split_portrait_pane` to skip `split_pane`; both `:274` and `:374` FAILED on `assert mock_split.called`. Live tree verified clean afterwards. |
| 5 | Comment dedup in test_143_9 | SOUND — pure constant extraction, comments only, zero executable change. 143-9 green. |

**Synthetic-test power (Dev's caveat, checked):** I confirmed there are ZERO `mark.xfail` markers anywhere in `src/pf/tests/` outside the two policy files, and zero real `pytestmark`/`pytest.xfail` sites. So real-tree power today rests entirely on the synthetic fixtures — and they are NOT vacuous: the pre-162-31 decorator-only scanner returns `[]` for both `_MODULE_LEVEL_MARK` and `_RUNTIME_XFAIL`, so those assertions were genuinely RED on old code. Deliverable 1's positive test (`test_xpassing_quarantine_is_detected`) fails when the mechanism is stubbed, so it anchors the three `== []` controls against systemic breakage.

**Data flow traced:** quarantine reason string → `_markers_in_source` (3 declaration sites) → `_iter_quarantine_markers` (tree-wide rglob) → `_reason_of` → `_TRACKING_RE.search` → offender list → assertion message. Safe because the offender list is built by list comprehension and asserted empty with the ids inlined in the message; no throws, result-shaped returns throughout.

### Findings

| Severity | Issue | Location | Fix |
|----------|-------|----------|-----|
| [MEDIUM-1] [TEST] [TYPE] | `find_xpasses` never checks `proc.returncode`/`stderr`. A collapsed run (exit 2 collection error, exit 4 no-tests) yields `offenders == []` — indistinguishable from clean. Experimentally confirmed: stubbing `find_xpasses` to `return []` leaves `test_in_scope_modules_have_no_xpass` and both controls GREEN. The forcing function can report "clean" while checking nothing. **Mitigated** (why this is not High): the positive test exercises the same code path and cwd in the same session, and 162-5's untouched `test_in_scope_modules_pass` asserts `returncode == 0` over the *same six targets*, so a real collection error in an in-scope module still fails loudly. | `test_162_5_quarantine_policy.py:155` | Treat `returncode not in (0, 1)` as a guard failure (surface it in the returned result). ~4 lines. Strongly recommended given the story's whole premise is exit-loudness. |
| [MEDIUM-2] | The regex's second alternative `\b[A-Z][A-Z0-9]+-\d+\b` accepts non-references. My probe: `UTF-8`, `SHA-256`, `ISO-8601`, `X86-64`, `HTTP-2`, `AWS-1`, `CI-2` all ACCEPT. `reason="flaky on UTF-8 input"` is a plausible quarantine reason and sails through — the same class of hole 162-5's review flagged, narrowed but not closed. `_JUNK_REFERENCES` has no uppercase-acronym case, so the tests do not see it. | `test_162_5_quarantine_policy.py:53-56` | Constrain the Jira alternative (project-key allowlist, or `[A-Z]{2,}-\d{2,}`), and add an acronym junk case. |
| [MEDIUM-3] | Regex is case-SENSITIVE. `Story 162-40: ...`, `STORY 162-40`, `See PR 5` all REJECT. Reason strings routinely start capitalized, so the next author to quarantine correctly gets flagged as untracked. False-red (safe direction, loud) but confusing, and `_REAL_REFERENCES` contains no capitalized case so the tests miss it. | `test_162_5_quarantine_policy.py:53` | Add `re.IGNORECASE` (one flag) + a capitalized accept case. |
| [MEDIUM-4] | Deliverable 3 leaves an obvious adjacent bypass open: `_module_level_markers` walks `tree.body` only, so **class-level `pytestmark` inside a `class TestX:` body is NOT discovered** — a mainstream idiom that quarantines an entire class. Verified: returns `[]`. Also undiscovered: `pytestmark += [...]`, `request.applymarker(pytest.mark.xfail(...))`, and a module-scope `pytest.xfail()` call. The two forms the brief named ARE closed, so this is scope, not a defect. | `test_162_5_quarantine_policy.py:79-93` | Follow-up: also walk `ClassDef.body` for `pytestmark`, reporting as `<class:TestX>`. |
| [LOW-5] | Missed a cheaper and strictly broader forcing function: `pyproject.toml`'s `[tool.pytest.ini_options]` has no `xfail_strict`. One line (`xfail_strict = true`) makes *every* future xfail tree-wide strict at zero runtime cost — broader than `find_xpasses` over six modules, with per-marker `strict=False` opt-out still available. TEA's deviation ("zero markers to flip") is correct per-marker but overlooked the global knob. Complementary, not a replacement. | `pennyfarthing-dist/pyproject.toml` | Follow-up story. |
| [LOW-6] | Duplicated subprocess cost: `test_in_scope_modules_pass` and `find_xpasses` each spawn a pytest run over the identical six in-scope modules (which include the 68-test 143-9 module). One run with `-rX`, checked for both `returncode` and `XPASS` lines, would halve it. Also: 162-5's `SYNTHETIC_MODULE` / `test_marker_discovery_works` anti-vacuity guard was not extended to the two new declaration forms, so guard-the-guard for them lives only in the 162-31 file. | `test_162_5_quarantine_policy.py:143-171`, `:377` | Follow-up. |
| [LOW-7] [SEC] | `find_xpasses`'s `subprocess.run` has no `timeout=`, so a hanging or deadlocked collected test blocks the guard indefinitely with no escape hatch. Not reachable today (call sites pass only the hardcoded `IN_SCOPE_MODULES` or pytest's `tmp_path`), and 162-5's pre-existing `test_in_scope_modules_pass` has the same omission. `shell=False`/argv-form confirmed, so there is no injection vector. | `test_162_5_quarantine_policy.py:155` | Add `timeout=` + `TimeoutExpired` handling to both subprocess sites. |

**Clean specialist results (verified good, no findings):**
- [RULE] 5 rules / 18 instances / **0 violations** — edits are in `pennyfarthing-dist/` source, not `.pennyfarthing/` symlink targets; `cwd` resolves to the framework repo root (not `pennyfarthing-dist/`), matching the pre-existing pattern at `:365`; `from __future__ import annotations` present in all four files; all new helpers fully annotated; `_`-prefixed privates and `MODULE_MARKER_NAME` naming correct; new test file follows `test_<story>_<slug>.py` in `src/pf/tests/`.
- [SEC] No injection (argv-form, `shell=False`), no secrets/tokens/absolute developer paths, `ast.literal_eval` correctly used instead of `eval`/`exec`, synthetic modules confined to `tmp_path` and executed by path rather than imported into the test process. One `RecursionError` gap in the `literal_eval` handler DISMISSED — reaching it requires a malicious commit to our own source tree.
- [TYPE] PEP 604 unions inside `isinstance` (`ast.List | ast.Tuple`, `ast.FunctionDef | ast.AsyncFunctionDef`) are valid at the declared `requires-python = ">=3.11.4"` floor. Confirmed correct.

### Rulings on the two judgment calls

- **Excluding `pytest.skip` from runtime discovery — UPHELD.** I counted **64** `pytest.skip(` call sites in the tree; they overwhelmingly encode environment facts, not debt. Forcing tracking references onto them would manufacture exactly the fake references 162-5 exists to prevent. It is also *consistent with the existing policy*, which already exempts `skipif` from the tracking-reference requirement for the identical reason (`test_every_xfail_cites_a_tracking_reference`'s docstring). Correctly documented in Delivery Findings. Not a gap.
- **`find_xpasses` scoped to in-scope modules — ACCEPTED, with the follow-up redirected.** The limitation is narrower than it looks: the reason/tracking/discovery policy is already tree-wide via `_iter_quarantine_markers`; only XPASS detection is scoped. The cost argument (an extra whole-tree subprocess run inside a unit test) is sound and widening it is the wrong fix. The right route to tree-wide XPASS loudness is [LOW-5] `xfail_strict = true`, not a bigger subprocess. Defensible limitation, not a gap.

### Deviation audit

All five logged deviations **ACCEPTED**:
- TEA "policy helper instead of `strict=True`" — accepted; zero markers exist to flip, verified independently. (See [LOW-5] for the config knob that was missed; that is an addition, not a reversal.)
- TEA "deliverable 4 lands GREEN, not RED" — accepted; mutation is the correct vacuity proof when production and test already agree, and I reproduced it.
- Dev "`find_xpasses` in the 162-5 module" — accepted; it is the API the RED pinned and it sits with its sibling helpers.
- Dev "deliverable 4 required no change" — accepted; verified `test_peloton_portrait_panes.py` diff is TEA's de-vacuuming only, with no shield reintroduced.
- Dev "guard gained one reject-side line" / TEA "new file rather than appending" — accepted; both strengthen rather than weaken, and keeping the new obligations in a separate module is why the missing-name import was a visible RED.

No undocumented deviations found.

**Handoff:** To SM for finish-story. Findings [MEDIUM-1] through [LOW-6] are all test-only quality debt on code that is strictly better than `develop`; file them as a 162-31 follow-up story rather than blocking this merge. [MEDIUM-1] and [MEDIUM-3] are ~5 lines combined and worth folding in now if SM prefers.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T19:42:29Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T19:13:17Z | 2026-08-11T19:14:21Z | 1m 4s |
| red | 2026-08-11T19:14:21Z | 2026-08-11T19:20:47Z | 6m 26s |
| green | 2026-08-11T19:20:47Z | 2026-08-11T19:26:54Z | 6m 7s |
| review | 2026-08-11T19:26:54Z | 2026-08-11T19:42:29Z | 15m 35s |
| finish | 2026-08-11T19:42:29Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings.

### Dev (implementation)
- **Improvement** (non-blocking): runtime `pytest.skip("...")` is deliberately NOT treated as a quarantine by the extended discovery — 30+ existing call sites encode environment facts, not debt, so flagging them would demand fake tracking references. If runtime skips ever start being used to hide failures, that needs its own policy (and probably its own allowlist). Affects `pennyfarthing-dist/src/pf/tests/test_162_5_quarantine_policy.py` (`_RUNTIME_XFAIL_CALLS`). *Found by Dev during implementation.*
- **Improvement** (non-blocking): `find_xpasses()` is now available but only wired into `TestXpassIsLoud::test_in_scope_modules_have_no_xpass`, which covers the six 162-5 modules. Widening it to the whole tree would make every future stale xfail loud, but costs a full-suite subprocess run — a deliberate scope call, not an oversight. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking): `find_xpasses()` ignores the subprocess `returncode`, so a collapsed pytest run (exit 2/4) is indistinguishable from a clean one and the forcing function reports "no stale quarantines" while checking nothing. Affects `pennyfarthing-dist/src/pf/tests/test_162_5_quarantine_policy.py` (treat `returncode not in (0, 1)` as a guard failure). Mitigated today by the positive test and 162-5's `test_in_scope_modules_pass` covering the same targets. *Found by Reviewer during code review.*
- **Gap** (non-blocking): the tightened `_TRACKING_RE` still accepts uppercase-acronym junk (`UTF-8`, `SHA-256`, `ISO-8601`, `X86-64`, `CI-2`) via its Jira-key alternative, and is case-SENSITIVE so legitimate `Story 162-40` / `See PR 5` are rejected. Affects `pennyfarthing-dist/src/pf/tests/test_162_5_quarantine_policy.py` (constrain the Jira alternative, add `re.IGNORECASE`, add both missing test cases). *Found by Reviewer during code review.*
- **Gap** (non-blocking): class-level `pytestmark` inside a `class TestX:` body still bypasses discovery — `_module_level_markers` walks `tree.body` only. Quarantining a whole class is a mainstream idiom. Also open: `pytestmark += [...]`, `request.applymarker(...)`, module-scope `pytest.xfail()`. Affects `pennyfarthing-dist/src/pf/tests/test_162_5_quarantine_policy.py` (also walk `ClassDef.body`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `pennyfarthing-dist/pyproject.toml`'s `[tool.pytest.ini_options]` has no `xfail_strict`. Setting `xfail_strict = true` makes every future xfail strict tree-wide at zero runtime cost — broader than `find_xpasses` over six modules, with per-marker `strict=False` opt-out intact. This is the right route to tree-wide XPASS loudness rather than widening the subprocess. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `test_in_scope_modules_pass` and `find_xpasses` each spawn a separate pytest subprocess over the identical six in-scope modules; one run with `-rX` could serve both. Separately, 162-5's `SYNTHETIC_MODULE` anti-vacuity fixture was not extended to cover module-level/runtime declaration forms. Affects `pennyfarthing-dist/src/pf/tests/test_162_5_quarantine_policy.py`. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Deliverable 1 implemented as a policy helper, not `strict=True`:** SM offered either. There are currently **zero** `xfail` markers left in the canonical tree (162-29 paid off the last four), so there is no marker to flip — `strict=True` has nothing to apply to and would be dead. Pinned `find_xpasses()` in the meta-guard instead, which also covers xfails added later by anyone.
- **Deliverable 4 lands GREEN, not RED:** SM expected the de-vacuumed portrait tests to fail until the assertion is real. They pass against unmutated production (`split_pane` really is called with `"h", 20`). Vacuity was proven by mutation instead — original passes / de-vacuumed fails when the split is removed. Recorded in the TEA Assessment.
### Dev (implementation)
- **`find_xpasses` lives in the 162-5 module, not a new one:** TEA's adapter imports it from `pf.tests.test_162_5_quarantine_policy`, which is the API the RED pinned, so it went there alongside `_markers_in_source` and `_reason_of` rather than into a helper module. Keeps the meta-guard's helpers in one place.
- **Deliverable 4 required no production or test change:** TEA's de-vacuumed assertions already pass against real production. SM's brief said "make production/test agree so the real call is asserted" — they already agree; the only obligation was not reintroducing the `if mock_split.called:` shield. Nothing was touched in `test_peloton_portrait_panes.py` this phase.
- **`test_xfail_filter_and_tracking_regex_are_live` gained one reject-side line:** the constraint was not to *weaken* the 162-5 guard; adding `assert not _TRACKING_RE.search("flaky 3-14 on macos")` strengthens it and keeps the tightened rule pinned from inside the guard itself, not only from the 162-31 file.

- **New file rather than appending to the 162-5 guard:** the new obligations import the 162-5 helpers from outside, which keeps the existing meta-guard byte-identical (constraint: do not weaken it) and makes the import of the missing `find_xpasses` a visible RED rather than an edit to a passing guard.