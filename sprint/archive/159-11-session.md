---
story_id: "159-11"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 159-11: TUI crash in textual widget._compose - needs triage (gh #131)

## Story Details
- **ID:** 159-11
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Type:** bug
- **Points:** 2
- **Priority:** p2

## Story Context

**Issue:** gh #131 — TUI crash when clicking into a story whose `acceptance_criteria` are plain STRINGS (free-text, not structured dicts).

**Root Cause (ground truth from traceback):**
- File: `pennyfarthing/pennyfarthing-dist/src/pf/tui/story_detail_screen.py` around line 187
- Code: `done_count = sum(1 for ac in acs if ac.get("done"))`
- Problem: `acs = data.get("acceptance_criteria", [])` can be a list of STRINGS, but line 187 assumes every AC is a dict `{text, done}`
- Calling `.get()` on a `str` raises `AttributeError: 'str' object has no attribute 'get'`
- This surfaces inside textual's `widget._compose`

**Technical Approach:**
The TUI must normalize AC shape — handle both string-form ACs and dict-form ACs `{text, done}`. A string AC has no "done" state. Fix belongs in the TUI normalization layer, not input validation.

**Acceptance Criteria:**
1. StoryDetailScreen renders without crashing when `acceptance_criteria` is a list of plain strings.
2. StoryDetailScreen still renders the AC progress bar correctly when ACs are dict-form `{text, done}`.
3. A regression test covers the string-form AC case.

**Implementation Notes:**
- Edit SOURCE at `pennyfarthing/pennyfarthing-dist/src/pf/tui/`, never the symlinked `.pennyfarthing/` runtime
- Pennyfarthing repo uses gitflow — this branch targets `develop`

## SM Assessment

Story scoped and ready for TEA. This is a contained, well-understood defect:

- **Ground truth is in hand.** The traceback (gh #131) pins the crash to `story_detail_screen.py:187` — `.get()` called on a string-form AC. No triage ambiguity remains; the user's initial "stray quote" hypothesis was ruled out by the locals dump.
- **Scope is one shape mismatch.** The TUI assumes dict-form ACs `{text, done}`; some external projects emit free-text string ACs. Fix is normalization at the render layer, not input validation.
- **Routing:** tdd / phased → TEA writes a failing test reproducing the string-form AC crash (and a passing case for dict-form), then Dev makes it green. 2pts, p2.
- **Repo discipline:** pennyfarthing/ source only (`pennyfarthing-dist/src/pf/tui/`), gitflow → `develop`. Branch `feat/159-11-textual-crash` created.

Handing off to TEA (Lord Melchett) for the RED phase.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Reproducible crash with a clear behavioral contract (gh #131).

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_159_11_story_detail_ac_crash.py` (new) — string/mixed/non-dict AC shapes across both render paths (StoryDetailScreen + StoryDetailWidget).

**Tests Written:** 10 tests (7 RED + 3 green regression guards) covering 3 ACs across 2 render paths.
**Status:** RED (7 failing — ready for Dev). Verified by direct scoped run: `7 failed, 3 passed, 0 errored`; all 7 fail on the real `AttributeError: 'str' object has no attribute 'get'` at `story_detail_screen.py:187` / `story_detail_widget.py:43`.

### Rule Coverage

| Rule (python lang-review) | Test(s) | Status |
|------|---------|--------|
| #1 fail-soft render (no silent/total crash on bad element) | `test_non_dict_non_str_ac_does_not_crash` | failing (RED) |
| #6 test quality (meaningful assertions) | self-check — every test asserts a concrete count / text / widget-presence / no-raise | pass |

**Rules checked:** 2 of 13 lang-review rules are directly applicable to a render-normalization fix (the rest — deserialization, async, deps, paths — do not apply to this change).
**Self-check:** 0 vacuous tests — no `assert True`, no bare truthiness; each test pins a specific count token (`0/3`, `1/3`, `0/1`, `1/2`, `50%`), rendered AC text, or section presence/absence.

### Designed Interface (for Dev — GREEN)

Normalize AC shape in ONE shared place (SOUL #2) and apply to **both** render paths:
- `story_detail_screen.py:187` — `done_count = sum(1 for ac in acs if ac.get("done"))`
- `story_detail_widget.py:43` (count) **and** `:115-117` (per-AC marks + text)

Contract the tests pin (fix-agnostic — `isinstance(ac, dict)` guard OR up-front normalization both pass):
- **string ACs** → no crash; count `0/N`; the string itself is shown as the criterion text (widget).
- **mixed** → no crash; count only dict-`done` entries (`1/2`, `1/3`); both string and dict texts shown.
- **non-dict (`None`)** → counts as not-done, no crash.
- **dict ACs** → unchanged (`1/2`, `50%`, `✓`/`○` marks).
- **empty** → AC section omitted (no div-by-zero).

A string AC's text is the string (`ac if isinstance(ac, str) else ac.get("text", "")`), not an empty `.get("text")`.

**Handoff:** To Dev (Baldrick) for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/tui/ac_shapes.py` (new) — single AC-shape normalizer: `ac_is_done` (non-dict ⇒ not done, never raises), `ac_done_count`, `ac_label` (a string AC is its own label).
- `pennyfarthing-dist/src/pf/tui/story_detail_screen.py` — L187 count now `ac_done_count(acs)` (+ import).
- `pennyfarthing-dist/src/pf/tui/story_detail_widget.py` — L43 count + per-AC marks/text now via `ac_done_count` / `ac_is_done` / `ac_label` (+ import).
- `pennyfarthing-dist/src/pf/tests/test_159_11_story_detail_ac_crash.py` — mechanical ruff lint/format only (TEA's tests; behavior unchanged).

**Tests:** 10/10 passing (GREEN). Adjacent suites green too — `test_tui_focus`, `test_tui_panel_persistence`, `test_150_10_session_append_only` → 72 passed total, 0 failed. Ruff check + format clean on all changed files.

**Smoke (prove the work):** Reproduced the exact gh #131 data shape (the `tempest` story `5-9` string-form ACs) through BOTH render paths → screen `AC [░░░░░░░░░░] 0%  0/3`, widget title `Acceptance Criteria  0/3`, no crash.

**Branch:** feat/159-11-textual-crash (pushed)

**Handoff:** To Reviewer (Captain Darling) for the review phase.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (10/10 tests pass, ruff clean, 0 smells) | N/A |
| 2 | reviewer-edge-hunter | Yes | Skipped | disabled | Disabled via settings — analyzed by Reviewer |
| 3 | reviewer-silent-failure-hunter | Yes | Skipped | disabled | Disabled via settings — analyzed by Reviewer |
| 4 | reviewer-test-analyzer | Yes | Skipped | disabled | Disabled via settings — analyzed by Reviewer |
| 5 | reviewer-comment-analyzer | Yes | Skipped | disabled | Disabled via settings — analyzed by Reviewer |
| 6 | reviewer-type-design | Yes | Skipped | disabled | Disabled via settings — analyzed by Reviewer |
| 7 | reviewer-security | Yes | clean | none (rules #1/#5/#8/#11 checked) | N/A |
| 8 | reviewer-simplifier | Yes | Skipped | disabled | Disabled via settings — analyzed by Reviewer |
| 9 | reviewer-rule-checker | Yes | Skipped | disabled | Disabled via settings — analyzed by Reviewer |

**All received:** Yes (2 enabled returned — preflight + security; 7 disabled via `workflow.reviewer_subagents`, their domains analyzed by Reviewer per `disabled-reviewer-subagents-shift-burden-to-you`)
**Total findings:** 0 confirmed blocking, 0 dismissed, 3 LOW/non-blocking notes captured as Delivery Findings.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** an acceptance-criterion value (from story YAML via `story_detail_data.fetch_story_detail`, or a Frame WebSocket payload) → `data["acceptance_criteria"]` → `ac_done_count(acs)` / `ac_label(ac)` → rendered into a Rich `Text` → `Static`/`Collapsible` widget → terminal. **Safe** because `Text.append(content, style=...)` stores `content` as a literal span (Rich only parses markup via `Text.from_markup`/`Console.print`), the `style=` argument is hardcoded (`"green"`/`""`), and there is no path/shell/SQL/HTML sink downstream — only an integer count and a display string.

**Pattern observed:** single-source-of-truth normalization (`pf/tui/ac_shapes.py`) replacing a copy-pasted `ac.get("done")` that lived in two render paths — SOUL #2 done correctly.

**Error handling:** the fix adds no `try/except`; it removes the crash class by tolerating non-dict ACs via `isinstance` guards (`ac_is_done`, `ac_label`). `ac_shapes.py:20` — `isinstance(ac, dict) and bool(ac.get("done"))` — a non-dict can never reach `.get()`.

### Observations

- `[VERIFIED] Single done-predicate` — `ac_shapes.py:20` `ac_is_done` returns `isinstance(ac, dict) and bool(ac.get("done"))`; non-dict ⇒ False, never raises. Complies with lang-review #1 (no swallow) and #3 (typed public fn).
- `[VERIFIED] Both render paths consolidated` — `story_detail_screen.py:188` (`ac_done_count`) and `story_detail_widget.py:45` + `:117-120` (`ac_done_count`/`ac_is_done`/`ac_label`). The duplicated `ac.get("done")` that caused gh #131 is fully removed; `grep` confirms no raw `ac.get("done")` remains in either file.
- `[SEC] Rich-markup / terminal-escape injection via ac_label` — CONFIRMED NOT EXPLOITABLE: `Text.append()` treats content as a literal span; `style=` is hardcoded. security subagent returned clean. Evidence: `story_detail_widget.py:120`.
- `[SILENT] No swallowed errors` — zero `try/except` in the diff; shape ambiguity handled by `isinstance` guards, not by suppression. (silent-failure-hunter disabled; verified by Reviewer against `ac_shapes.py`.)
- `[EDGE] Div-by-zero guarded` — `story_detail_screen.py:189` `pct = ... if total > 0 else 0`; empty `acs` skipped by `if acs:`; `ac_done_count([]) == 0`. No boundary crash. (edge-hunter disabled; verified by Reviewer.)
- `[EDGE][LOW] Bare-string acceptance_criteria` — if the key were ever a single string (not a list), `ac_done_count` would iterate characters → count 0, `total = len(str)`; a confusing display but no crash. Degenerate, out of producer scope. Non-blocking.
- `[TYPE][LOW] ac_label(None) → "None"` — a non-dict/non-str AC renders the literal text "None"; cosmetic, fail-soft, matches TEA's defensive contract. Acceptable. Evidence: `ac_shapes.py:44`. (type-design disabled; verified by Reviewer.)
- `[TEST][LOW] Tests couple to Textual private attrs` — `_Static__content` / `_contents_list` are read directly because the pinned Textual version exposes no public render accessor outside an app cycle; correct today, brittle across Textual upgrades. Documented in the test. Non-blocking. (test-analyzer disabled; verified by Reviewer.)
- `[SIMPLE] No over-engineering` — three small pure functions; `ac_done_count` composes `ac_is_done`; the change net-removes duplication. (simplifier disabled; verified by Reviewer.)
- `[DOC] Docstrings accurate` — `ac_shapes.py` and the test reference gh #131 + SOUL #2; no stale/misleading comments. (comment-analyzer disabled; verified by Reviewer.)
- `[RULE] python lang-review` — #1 ✓ (no swallow), #3 ✓ (public funcs typed), #6 ✓ (meaningful test asserts, no vacuous), #10 ✓ (clean imports; `ac_shapes` imports only `typing` ⇒ no cycle with the tui modules that import it); #5/#7/#8/#9/#12 N/A to this diff. (rule-checker disabled; verified by Reviewer.)

### Rule Compliance (python lang-review)

| # | Rule | Applies? | Verdict |
|---|------|----------|---------|
| 1 | Silent exception swallowing | Yes | Compliant — no `except` added; `isinstance` guards |
| 2 | Mutable default args | No | — |
| 3 | Type annotations at boundaries | Yes | Compliant — `ac_is_done/ac_done_count/ac_label` fully annotated |
| 4 | Logging coverage/correctness | No | — (pure render helpers) |
| 5 | Path handling | No | — (no path/`open()`) |
| 6 | Test quality | Yes | Compliant — concrete assertions; inverse-binding probe proves binding |
| 7 | Resource leaks | No | — |
| 8 | Unsafe deserialization | No | — |
| 9 | Async pitfalls | No | — |
| 10 | Import hygiene | Yes | Compliant — explicit imports, no star, no cycle |
| 11 | Input validation at boundaries | Yes | Compliant — shape normalized before render; no injection sink |
| 12 | Dependency hygiene | No | — |
| 13 | Fix-introduced regressions | Yes | Compliant — no broad except / wrong type introduced |

### Devil's Advocate

Suppose this is broken. The normalizer trusts that `acceptance_criteria` is a *list*. If a producer ever emits a bare string for that key, `if acs:` is truthy and `ac_done_count("do the thing")` iterates the string character-by-character — count 0, `total = len(string)` — rendering a nonsense `0/15`. No crash, but a confusing display. A careless author could embed a 50,000-character AC; `ac_label` returns it whole and Rich lays out a massive `Text` — a soft render-cost issue, but only on the local single-user terminal. A confused user might write `{"text": "x", "done": "false"}` — `"false"` is a *truthy string*, so `bool(ac.get("done"))` returns True and the AC shows as done when "not done" was meant. That is a real footgun, but it is the producer's data-quality problem and pre-exists this change (the old `if ac.get("done")` had the same truthiness). Under a stressed filesystem, `_enrich`'s `fetch_story_detail` could throw — but that path is wrapped (`except Exception: return ws_data`), so rendering still proceeds. A dict with `{"text": None}` yields `str(None)` = "None", displayed literally — cosmetic. None of these cross a trust boundary, corrupt data, or reintroduce the gh #131 crash; the worst realistic case is a cosmetically-odd local render. The fix holds.

**Verification performed:** inverse-binding probe (reverted both source files to `origin/develop`, kept the branch test file → 7 failed / 3 passed → tests bind to the fix), then restored cleanly (`git diff HEAD` empty, fix symbols present). Preflight GREEN, ruff clean, security clean.

**Handoff:** To SM (Edmund Blackadder) for finish-story.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-28T13:32:42Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-28T13:05:55Z | 2026-06-28T13:07:34Z | 1m 39s |
| red | 2026-06-28T13:07:34Z | 2026-06-28T13:19:09Z | 11m 35s |
| green | 2026-06-28T13:19:09Z | 2026-06-28T13:25:46Z | 6m 37s |
| review | 2026-06-28T13:25:46Z | 2026-06-28T13:32:42Z | 6m 56s |
| finish | 2026-06-28T13:32:42Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings (setup phase).

### TEA (test design)
- **Gap** (blocking): The identical AC dict-shape assumption exists in a second, live render path — `StoryDetailWidget` (used by the ProgressPanel drill-through per its docstring) — at L43 (`done_count`), L115-116 (`ac.get("done")` per-AC marks), and L117 (`ac.get("text")`). A screen-only fix ships a live crash twin. Affects `pennyfarthing-dist/src/pf/tui/story_detail_widget.py` (normalize AC shape identically; ideally extract ONE shared helper used by both files per SOUL #2). *Found by TEA during test design.*
- **Gap** (non-blocking): sm-setup's `SETUP_RESULT` reported `branch: feat/159-11-textual-crash` but the branch was never created — the pennyfarthing repo was still on `develop`. TEA created it off develop before committing. Affects the `sm-setup` subagent / setup flow (it should create AND verify the branch, or not report one it did not create). *Found by TEA during test design.*
- **Question** (non-blocking): Upstream emits `acceptance_criteria` as plain strings for some projects (e.g. the `tempest` story `5-9` in the gh #131 traceback) while pennyfarthing emits `{text, done}` dicts. Render-layer normalization is the correct scoped fix, but the producer-side shape inconsistency is worth a follow-up look. Affects `pennyfarthing-dist/src/pf/tui/story_detail_data.py` / the WS data producer. *Found by TEA during test design.*

### Dev (implementation)
- No new upstream findings during implementation. TEA's blocking finding (the `StoryDetailWidget` twin crash) is **resolved** in this commit — both render paths now route AC-shape handling through the shared `pf/tui/ac_shapes.py` normalizer. TEA's non-blocking findings (phantom sm-setup branch; producer-side AC shape inconsistency in `story_detail_data.py`) are out of scope for this fix and remain open for follow-up. *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): The new tests read Textual private attributes (`_Static__content`, `_contents_list`) because the pinned Textual version exposes no public render accessor outside an app render cycle — correct today, but they will break silently on a Textual upgrade that renames those internals. Affects `pennyfarthing-dist/src/pf/tests/test_159_11_story_detail_ac_crash.py` (consider a thin public accessor or an `App.run_test()`-based render assertion if these tests become flaky on upgrade). *Found by Reviewer during code review.*
- **Question** (non-blocking): Seconding TEA's finding — the producer emitting `acceptance_criteria` as strings for some projects vs `{text, done}` dicts is a data-shape inconsistency worth a follow-up at the source (`story_detail_data.py` / the Frame WS payload). The render-layer normalization shipped here is the correct scoped fix; aligning the producer would let the TUI assume one shape. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

No deviations (setup phase).

### TEA (test design)
- **Test coverage extended to StoryDetailWidget beyond the gh #131 traceback file**
  - Spec source: context-story-159-11.md (Scope) + session SM Assessment
  - Spec text: gh #131 traceback names only `story_detail_screen.py:187`; SM framed the fix as "the TUI normalization layer"
  - Implementation: RED also covers `story_detail_widget.py` (3 RED + 1 green guard) — the ProgressPanel drill-through path with the same bug
  - Rationale: identical root cause on a live reachable path; a screen-only fix ships a half-crash (SOUL #1/#2)
  - Severity: minor
  - Forward impact: Dev must fix BOTH files (ideally one shared helper); the GREEN gate expects both green
- **Three regression guards are green-on-arrival (intentional, not spurious)**
  - Spec source: session Story Context, AC2
  - Spec text: "StoryDetailScreen still renders the AC progress bar correctly when ACs are dict-form {text, done}"
  - Implementation: `test_dict_form_acs_render_correct_count`, `test_empty_acs_omits_section`, `test_widget_dict_form_acs_render_count_and_marks` pass today
  - Rationale: the dict-form path already works; these pin that the fix does not regress it (per the ac-as-green-regression-guard pattern)
  - Severity: trivial
  - Forward impact: none — they must stay green after the fix
- **Defensive non-dict (`[None]`) AC test goes beyond the two literal data shapes (string/dict)**
  - Spec source: session Story Context (Technical Approach)
  - Spec text: "handle both string-form ACs and dict-form ACs {text, done}"
  - Implementation: added `test_non_dict_non_str_ac_does_not_crash` — a `None` entry must count as not-done, not crash
  - Rationale: a TUI render path must fail soft on any unexpected element (lang-review #1); the fix should generalize, not special-case `str`
  - Severity: minor
  - Forward impact: nudges Dev toward `isinstance(ac, dict)`-style normalization over a str-only guard
- **RED verified via direct scoped pytest, not the testing-runner subagent**
  - Spec source: TEA agent workflow (RED), step 6
  - Spec text: "Spawn `testing-runner` to verify RED state"
  - Implementation: verified with `uv run pytest src/pf/tests/test_159_11_story_detail_ac_crash.py -rA` (7 failed on the real AttributeError, 3 green guards, 0 errored)
  - Rationale: TEA sidecar gotchas (`testing-runner-hallucinates-failure-reasons`, `dont-run-the-SUT-runner`) — for crash/contract RED the spy can misreport WHY a test fails and can clobber the live session; the direct run is the source of truth
  - Severity: trivial
  - Forward impact: none

### Dev (implementation)
- **Created a shared `ac_shapes.py` normalizer instead of inline guards in two files**
  - Spec source: session Story Context (Technical Approach) + TEA Designed Interface
  - Spec text: "Fix belongs in the TUI normalization layer" / "Normalize AC shape in ONE shared place (SOUL #2)"
  - Implementation: added `pennyfarthing-dist/src/pf/tui/ac_shapes.py` (`ac_is_done`, `ac_done_count`, `ac_label`); both `story_detail_screen` and `story_detail_widget` import it
  - Rationale: the bug was a copy-pasted dict-shape assumption (screen:187 + widget:43 were twins); consolidating removes the duplication that caused it (SOUL #2), and matches the TEA-designed interface
  - Severity: minor
  - Forward impact: future AC consumers should import these helpers rather than re-implement `ac.get("done")`
- **Applied a mechanical ruff lint/format fix to TEA's test file**
  - Spec source: TEA's RED test file (commit `cc2982084`)
  - Spec text: `getattr(static_widget, "_Static__content")` flagged by ruff B009 (get-attr-with-constant) + one formatting reflow
  - Implementation: `ruff check --fix` (getattr → direct attribute access) + `ruff format`; no assertion, value, or test behavior changed — all 10 tests still pass
  - Rationale: keep the working tree lint-clean for the verify/review handoff; the change is purely mechanical
  - Severity: trivial
  - Forward impact: none

### Reviewer (audit)
- **TEA: test coverage extended to StoryDetailWidget** → ✓ ACCEPTED by Reviewer: sound — the widget is a live ProgressPanel drill-through path with the identical bug; Dev fixed both via the shared normalizer. SOUL #1/#2.
- **TEA: three regression guards green-on-arrival** → ✓ ACCEPTED by Reviewer: correct intentional-green guards; the dict-form path already worked and they pin it stays working.
- **TEA: defensive `[None]` test beyond literal shapes** → ✓ ACCEPTED by Reviewer: fail-soft on any unexpected element is the right generalization (lang-review #1); drove `ac_label`'s `str(ac)` fallback.
- **TEA: RED verified via direct scoped pytest, not testing-runner** → ✓ ACCEPTED by Reviewer: defensible given the documented spy hazards; I independently re-verified binding via the inverse-binding probe.
- **Dev: shared `ac_shapes.py` instead of inline guards** → ✓ ACCEPTED by Reviewer: SOUL #2 done correctly — net-removes the duplication that caused gh #131; matches the TEA-designed interface.
- **Dev: mechanical ruff fix to TEA's test file** → ✓ ACCEPTED by Reviewer: confirmed non-behavioral — ruff clean, all 10 tests pass, and the inverse-binding probe (which used the post-fix test file) still flips RED/green correctly.
- No undocumented deviations found: the diff matches the logged TEA/Dev entries exactly.