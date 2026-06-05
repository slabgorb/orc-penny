---
story_id: "158-4"
jira_key: "none"
epic: "158"
workflow: "tdd"
---
# Story 158-4: SM handoff exit protocol: undocumented required args + missing Sm Assessment precondition (gh #49)

## Story Details
- **ID:** 158-4
- **Jira Key:** none (Jira-less project — local kanban only)
- **Type:** bug
- **Points:** 2
- **Epic:** 158
- **Workflow:** tdd
- **Repository:** pennyfarthing
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-05T11:14:34Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-05T10:14:49Z | 2026-06-05T10:16:42Z | 1m 53s |
| red | 2026-06-05T10:16:42Z | 2026-06-05T10:43:30Z | 26m 48s |
| green | 2026-06-05T10:43:30Z | 2026-06-05T10:53:09Z | 9m 39s |
| review | 2026-06-05T10:53:09Z | 2026-06-05T11:01:47Z | 8m 38s |
| red | 2026-06-05T11:01:47Z | 2026-06-05T11:04:42Z | 2m 55s |
| green | 2026-06-05T11:04:42Z | 2026-06-05T11:08:27Z | 3m 45s |
| review | 2026-06-05T11:08:27Z | 2026-06-05T11:14:34Z | 6m 7s |
| finish | 2026-06-05T11:14:34Z | - | - |

## Technical Approach

This is a bug fix story addressing two friction points in the SM agent's handoff exit protocol, filed by the SM during story 22-1 setup→red transition.

### Problem 1: Undocumented Required Arguments
The SM agent guide presents the exit protocol as:
```
pf handoff resolve-gate → pf handoff complete-phase → pf handoff marker
```

But all three commands require positional arguments not documented in the agent-behavior guide:
- `pf handoff resolve-gate STORY_ID WORKFLOW PHASE`
- `pf handoff complete-phase STORY_ID WORKFLOW FROM_PHASE TO_PHASE GATE_TYPE`
- `pf handoff marker NEXT_AGENT`

Running them as documented fails with "Missing argument" errors. An agent fresh after context clear must discover the required args via trial-and-error or `pf workflow show <workflow>`.

### Problem 2: Missing Precondition on `complete-phase`
`resolve-gate` reports `assessment_found: true`, yet `complete-phase` hard-fails if the session file lacks a `## Sm Assessment` heading:

```
error: 'No assessment found in session file. To fix: Add a `## Sm Assessment`
heading to the session file before completing the phase.'
```

The mismatch:
- `sm-setup` template does not include `## Sm Assessment`
- `resolve-gate` does not require it (reports `assessment_found: true` regardless)
- `complete-phase` fails without it

This causes a preventable round-trip for every SM handoff.

## Acceptance Criteria

The story fixes both friction points with one of these approaches per problem:

**Problem 1:** Document undocumented arguments in one of:
- (a) Update `guides/handoff-cli.md` with full command signatures and a worked example for `tdd` workflow (setup → red transition)
- (b) Update the SM agent definition's `<exit>` section with explicit argument documentation
- (c) Enhance the CLI commands to infer args from the active session file (`.session/{STORY_ID}-session.md`) so the bare invocation works

**Problem 2:** Unify the precondition by one of:
- Make `resolve-gate` block with an actionable error if `## Sm Assessment` is missing (so both commands agree on the requirement)
- Add `## Sm Assessment` heading to the `sm-setup` session template (or to the SM pre-handoff checklist) so it's present before the exit protocol runs

## Sm Assessment

Setup complete and verified. Story 158-4 is a 2-point p2 bug in the `pennyfarthing` repo, tdd workflow (phased: setup → red → green → review → finish).

- Session file created with story context, technical approach, and acceptance criteria (above).
- Context docs created: `sprint/context/context-story-158-4.md`, `sprint/context/context-epic-158.md`.
- Feature branch `feat/158-4-sm-handoff-exit-protocol-docs` created off `develop` per repos.yaml gitflow.
- Story status set to `in_progress` via `pf sprint story` commands.
- Jira explicitly skipped — Jira-less project, local kanban only.
- Notable: both friction points described by this story reproduced live during this very handoff (missing-args errors on `resolve-gate`/`complete-phase`, then the `## Sm Assessment` hard-fail), confirming the bug report is accurate and current.

**Routing:** Hand off to TEA (red phase) to write failing tests covering the chosen fix approach per the acceptance criteria.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Both problems are mechanical CLI/function behavior — testable contracts, not doc-only.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_158_4_handoff_exit_protocol.py` — 20 tests pinning the exit-protocol contract (committed `2b46d2e49`)

**Tests Written:** 20 tests (11 failing RED, 9 green-on-arrival regression pins)
**Status:** RED (failing on assertions — ready for Dev)

### Contract for Dev (Ponder Stibbons)

**Problem 2 (fix first — smaller):** `resolve_gate()` must perform the SAME assessment check `complete_phase()` performs (`^##\s+.*Assessment`, gated transitions only — skip/manual exempt) instead of hardcoding `assessment_found=True` at `resolve_gate.py:183`. Missing heading (or missing session file) on a gated phase → `status: "blocked"` + actionable error naming the heading. Extract a shared helper so the two can never disagree again (SOUL #2).

**Problem 1:** Make the three CLI commands' positional args optional, inferred from the active session (SOUL #3). Building blocks already exist: `pf.prime.workflow.find_active_session` / `parse_session_header`, and `handoff status`'s workflow-YAML lookup (cli.py:160-218). Inference sources:
- `resolve-gate`: story_id/workflow/phase from session
- `complete-phase`: from_phase = session phase; to_phase + gate_type from workflow YAML (next phase)
- `marker`: target = **CURRENT phase owner** (post-complete-phase call site — session already shows the new phase). Do NOT reuse `handoff status`'s `next_agent` (that's the phase *after* current and the test pins `dev not in output` for a red-phase session).
- Bare invocation with no active session → actionable error mentioning the session, exit ≠ 0. Inference must NOT bypass any guard (assessment, context) — pinned.

**Verification:** scoped run only — `cd pennyfarthing-dist && uv run pytest src/pf/tests/test_158_4_handoff_exit_protocol.py -q` (full suite leaks a branch checkout; see TEA sidecar).

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| SOUL #10 return-results (never raises) | `test_missing_session_file_blocks_not_crashes` | failing |
| SOUL #6 gates-over-goodwill (agreement property) | `TestResolveCompleteAgreement` (2) | 1 failing / 1 pin |
| SOUL #3 detect-state (bare inference) | `TestCliBare*` (9) | 6 failing / 3 pins |
| Actionable errors (fail-loud, gh #50 spirit) | `*_is_actionable`, `*_mentions_assessment_heading` (3) | failing |
| Guard not bypassed by new path | `test_bare_invocation_still_requires_assessment` | failing |
| Backward compat (explicit args) | `test_explicit_*_still_work` (3) | pins, passing |

**Rules checked:** 4 SOUL principles + error-actionability mapped to tests
**Self-check:** 0 vacuous tests — every test asserts specific status/value/output; one fixture defect (dedent) found and fixed before commit

**Handoff:** To Dev for implementation

### Rework Cycle 1 (TEA)

**Tests Written:** 7 failing tests pinning the Reviewer's confirmed findings (commit `fd1cf5efb`), appended to the story suite under `# Rework cycle 1`:

| Test | Finding | Contract |
|------|---------|----------|
| RW1 `test_traversal_workflow_value_rejected_as_invalid` | [SEC-M] CWE-22 | inferred workflow must be validated as an identifier — error says "invalid", proving validation (not path lookup) fired |
| RW2 `test_config_error_not_masked_as_no_session` | [SILENT-M] | non-FileNotFoundError from `get_project_root` surfaces verbatim, exit ≠ 0; only no-root falls back to cwd |
| RW3 `test_unreadable_session_is_error_not_missing_heading` | [SILENT-M] | chmod-000 session → `status: "error"`, never "Add a `##…` heading" |
| RW4 `test_bare_cli_handles_unreadable_session_without_traceback` | [EDGE-M] | inference boundary returns a result; no exception escapes (SOUL #10) |
| RW5 `test_resolve_gate_exits_nonzero_on_error_status` | [EDGE-M] | `status: "error"` → exit ≠ 0 (fail-loud) |
| RW6 `test_resolve_gate_read_text_specifies_encoding` | [SEC-L] static guard | no bare `read_text()` in resolve_gate.py |
| RW7 `test_bare_marker_does_not_emit_phase_name_as_agent` | [LOW] | unknown phase owner → fail loud, never `/pf-{phase}` |

**Status:** RED — 7 failing on assertions, 20 originals green.
**Not test-pinned (Dev must still fix):** stale class docstring at `test_handoff_cli.py:288` ([TEST-M]) — doc fix, Reviewer will verify on re-review. Optional: unify `status_cmd` session selection with `find_active_session` (Reviewer Delivery Finding).

## Dev Assessment

**Status:** GREEN — all 20 story tests pass; 320 tests pass across the 12 handoff-adjacent files.

**Implementation (commit `a1b694fd4`):**
- `pf/handoff/session_assessment.py` (new) — single shared definition of the assessment precondition: regex, exempt gate types, error message (SOUL #2)
- `pf/handoff/resolve_gate.py` — reads the session file, reports `assessment_found` truthfully, blocks gated transitions with the same actionable error complete-phase raises; stale "checks live in complete_phase" docstring rewritten
- `pf/handoff/complete_phase.py` — inline check replaced by the shared module (no behavior change)
- `pf/handoff/cli.py` — all positional args optional; `_infer_session_args()` resolves story/workflow/phase via `find_active_session`/`parse_session_header`; complete-phase derives to-phase/gate-type through `resolve_gate` (inference cannot bypass guards); marker infers the CURRENT phase owner via `_get_phase_agent`; no-session errors are actionable

**Test updates (logged as deviations):**
- `test_handoff_cli.py`: 2 pins of the superseded "ready without assessment" behavior updated to the new contract
- `test_143_10_reviewer_dev_roundtrip.py`, `test_gate_extensions.py`: fixtures seeded with session files so they test their own concern

**Pre-existing failures (NOT this story):** `test_143_9_tdd_cycle_e2e.py` — 4 verify-phase `phase_owner` failures present on the unmodified tree (verified via stash). Untouched.

**Verification:** scoped runs only per TEA instruction; lint clean (`ruff`).

**Note:** the live orchestrator still runs the installed pf 13.3.0 wheel — bare invocation works after the next `uv tool install` reinstall (build/ dir purge first, per standing gotcha).

**Handoff:** To Reviewer.

### Rework Cycle 1 (Dev)

**Status:** GREEN — all 27 story tests pass (20 original + 7 rework); 300 pass across adjacent handoff suites; ruff clean.

**Fixes (commit `919733546`):**
- RW1 [SEC]: `_infer_session_args` validates inferred story/workflow/phase against `[A-Za-z0-9][A-Za-z0-9._-]*` — traversal values from session content are rejected with an "invalid" error before any path interpolation (cli.py)
- RW2 [SILENT]: root detection catches only `FileNotFoundError` for the cwd fallback; any other exception returns `ok: False` with the original message (cli.py)
- RW3 [SILENT]: resolve_gate distinguishes `FileNotFoundError` (→ assessment-missing flow) from other `OSError`/`UnicodeDecodeError` (→ `status: "error"` naming the real problem) (resolve_gate.py)
- RW4 [EDGE]: `find_active_session`/`parse_session_header` wrapped in `try/except OSError` → clean `ok: False` result (cli.py)
- RW5 [EDGE]: resolve-gate CLI exits 1 on `status: "error"` as well as `"blocked"` (cli.py)
- RW6 [SEC]: `encoding="utf-8"` on both `read_text` calls in resolve_gate.py — the static guard caught the pre-existing workflow-YAML read too
- RW7 [EDGE]: bare marker does an explicit owner lookup via `_load_workflow_phases`; unknown phase → `UsageError`, never a phase-name target (cli.py)
- [TEST-M]: stale `TestResolveGateBlocked` docstring rewritten to the 158-4 contract (test_handoff_cli.py)

**Rule #13 re-scan of the fix diff:** narrow excepts only (`FileNotFoundError`, `OSError`, `UnicodeDecodeError`); no new broad catches; all new error strings actionable; no mutable defaults; annotations intact.

**Not done (deferred per Reviewer):** `status_cmd` session-selection unification — recorded as a Delivery Finding, pre-existing command outside story ACs.

**Handoff:** Back to Reviewer for re-review (rework cycle 1).

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 9 | confirmed 4, dismissed 3, deferred 2 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 4 | confirmed 3, dismissed 1, deferred 0 |
| 4 | reviewer-test-analyzer | Yes | findings | 9 | confirmed 1, dismissed 0, deferred 8 |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 3 | confirmed 2, dismissed 1, deferred 0 |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (5 enabled returned, 4 disabled skipped)
**Total findings:** 10 confirmed, 5 dismissed (with rationale), 10 deferred

### Re-review — Rework Cycle 1 (fresh dispatch)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (306 green, ruff clean, tree clean) | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 5 | confirmed 2, dismissed 2, deferred 1 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 3 (+3 FIXED verdicts) | confirmed 1, deferred 2 |
| 4 | reviewer-test-analyzer | Yes | findings | 3 | deferred 3 (test hardening) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 2 (+2 FIXED verdicts) | deferred 2 (pre-existing) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (5 enabled returned for cycle 1 re-review)
**Cycle-1 fix verification:** silent-failure-hunter FIXED 3/3; security FIXED (inferred-path CWE-22 — regex adversarially probed: leading-alnum requirement kills `.`/`..`, no separators in class, no URL-decoding occurs; RW6 encoding FIXED both reads); preflight 306 green incl. all 27 story tests.
**New this cycle:** 1 confirmed in-diff consistency gap (UnicodeDecodeError missing from the new except tuple, cli.py:57 — LOW: session files are tooling-written UTF-8; the wrapped read is pre-existing exposure that previously had NO guard at all); everything else pre-existing outside the diff or test-hardening — recorded as Delivery Findings, none rule-matching within changed lines.

**Dismissals (evidence-cited):**
- [SEC] story_id path traversal via session *filename* — dirent names cannot contain `/` (POSIX invariant); embedded `..` cannot escape the `f"{story_id}-session.md"` template. Not exploitable from the inference path.
- [SILENT] Frame `emit_subagent_event` swallow — documented intentional design ("observability should never block workflow", complete_phase.py:268), pre-existing, untouched by diff.
- [EDGE] to_phase-explicit-without-gate_type still enforces assessment — intentional; TEA pinned "inference must not bypass any guard"; full explicit args remain the escape hatch.
- [EDGE] phase missing `agent:` key degrades error wording — workflow schema requires `agent`; cosmetic degradation only, no real workflow lacks it.
- [EDGE] phase-history row absent → no insertion — pre-existing complete_phase behavior on untouched lines; out of diff scope (own story if wanted).

**Deferrals:** 8 test-robustness improvements ([TEST] YAML-parse assertions instead of substrings, parametrized agreement over more gate types, all-phase-lines check, PROJECT_ROOT-without-chdir case, fixture disambiguation asserts) — tests pass and pin correct behavior today; hardening, not defects. [EDGE] partial-explicit-args cross-session mismatch — documented single-active-session model; warrants a docs note, not a redesign. [EDGE] `### `/lowercase heading variants not matched — mirrors the pre-existing complete_phase contract exactly; loosening is out of story scope.

## Reviewer Assessment

**Verdict:** APPROVED (rework cycle 1 — initial verdict REJECTED, all 8 confirmed findings fixed in `919733546` and verified by fresh subagent dispatch)

### Re-review summary (cycle 1)

All cycle-1 findings verified FIXED: [SEC] inferred-identifier validation (regex adversarially probed by security subagent — sound), [SILENT] config-error visibility + unreadable-vs-missing distinction, [EDGE] OSError boundary guard + exit-1-on-error, [SEC] encoding on both resolve_gate reads, [EDGE] marker explicit owner lookup, [TEST] docstring rewritten. 306 tests green (27 story tests), ruff clean, tree clean.

Remaining items are LOW/pre-existing/out-of-diff and recorded as Delivery Findings: UnicodeDecodeError absent from the new except tuple (one-line; exotic trigger on tooling-written UTF-8 files), encoding= sweep for complete_phase.py's five pre-existing reads/writes, `status_cmd` bare-except + session-selection unification, `nxt["agent"]` bare lookups on untouched lines, three test-hardening suggestions. None Critical/High; no rule-matching violation within changed lines. Per the severity rubric these do not block.

### Initial review (cycle 0) — verdict REJECTED

**Data flow traced:** bare `pf handoff complete-phase` → `_infer_session_args()` (cli.py:24) → session filename/content → `resolve_gate()` → workflow YAML path construction (`_find_workflow_yaml`, resolve_gate.py:253) — content-derived `workflow` reaches the filesystem path **unvalidated** (the traversal confirmed below). Blocked/error short-circuits exit before any session mutation (cli.py:184) — verified safe.

**Pattern observed (good):** shared-precondition module `session_assessment.py` — one regex, one exemption list, one message used by both protocol steps (SOUL #2); pure extraction verified byte-equivalent to the old inline check at complete_phase.py:96-110.

**Error handling:** the new inference paths return actionable errors for the common cases (no session, missing fields, no next phase — cli.py:44,57,186) but three gaps confirmed below.

| Severity | Tag | Issue | Location | Fix Required |
|----------|-----|-------|----------|--------------|
| [MEDIUM] | [SEC] | Inferred `workflow` (session *content*, `**Workflow:**` line) interpolated into YAML paths without validation — `../../evil` escapes `workflows/` (CWE-22, rule #11) | cli.py:51 → resolve_gate.py:253, complete_phase.py:344 | Validate inferred workflow (and story_id for hygiene) against `[A-Za-z0-9_-]+` in `_infer_session_args`; return `ok: False` on mismatch |
| [MEDIUM] | [SILENT] | `except Exception: root = Path.cwd()` masks real config errors as "No active session found" | cli.py:34 | Narrow to `FileNotFoundError`; other exceptions → `ok: False` with the original message |
| [MEDIUM] | [SILENT] | Present-but-unreadable session ≡ missing: emits "Add a `## Sm Assessment` heading" when the real fix is permissions | resolve_gate.py:95 | Catch `FileNotFoundError` for the empty fallback; other `OSError` → `status: "error"` with the OS message |
| [MEDIUM] | [EDGE] | `_infer_session_args` calls `find_active_session`/`parse_session_header` unguarded — `OSError` escapes as a traceback (violates SOUL #10 at a CLI boundary) | cli.py:41-50 | Wrap in `try/except OSError` → `ok: False` |
| [MEDIUM] | [EDGE] | `resolve-gate` exits 0 on `status: "error"` (workflow/phase not found) — relay/scripts proceed on genuine errors (pre-existing, in-scope file, fail-loud per gh #50) | cli.py:134 | `if result.get("status") in ("blocked", "error"): raise SystemExit(1)` |
| [MEDIUM] | [TEST] | Stale class docstring asserts the OLD contract ("resolve-gate no longer blocks… moved to complete_phase") directly above tests rewritten to assert blocking | test_handoff_cli.py:288 | Rewrite docstring to the 158-4 contract |
| [LOW] | [SEC] | `read_text()` without `encoding=` in new code (CWE-838, rule #5) | resolve_gate.py:96 | `read_text(encoding="utf-8")` |
| [LOW] | [SILENT]/[EDGE] | `_get_phase_agent` falls back to the *phase name* as agent on YAML lookup failure — bare marker silently emits `/pf-red` | cli.py:240 ← complete_phase.py:344 | Error marker (or UsageError) when the owner lookup fails, instead of the phase-name fallback |

**Rule Compliance (lang-review python.md, applied to every changed `.py`):**
- #1 silent exceptions — **violation ×2** (cli.py:34 broad except; resolve_gate.py:95 OSError conflation) — findings above
- #2 mutable defaults — compliant (no mutable defaults in `_infer_session_args`, `resolve_gate`, `session_assessment` signatures)
- #3 type annotations — compliant (`_infer_session_args() -> dict`, all new public signatures annotated, `str | None` on CLI params)
- #5 path handling — **violation** (resolve_gate.py:96 `read_text()` no encoding) — finding above; pathlib used throughout otherwise
- #6 test quality — compliant in new suite (every test asserts specific status/value; deferred robustness notes are hardening) — one doc defect (stale docstring) confirmed
- #8 unsafe deserialization — compliant (`yaml.safe_load` everywhere: resolve_gate.py:57; `yaml.dump` output only in cli.py)
- #10 import hygiene — compliant (function-local imports match the file's lazy-loading convention; no cycles: session_assessment imports nothing from handoff)
- #11 input validation — **violation** (inferred workflow unvalidated at CLI boundary) — finding above
- #13 fix-regressions — the rework diff must be re-scanned against #1-#12 (note for Dev)

**Five observations (beyond subagents):**
1. [VERIFIED] `complete_phase` refactor is behavior-preserving — regex `^##\s+.*Assessment` (session_assessment.py:20), exempt tuple (line 23), and message text are byte-identical to the removed inline versions (diff complete_phase.py:96-110). Complies with SOUL #2; checked rules #1/#3 against the new module — clean.
2. [VERIFIED] inference cannot bypass guards — bare complete-phase routes through `resolve_gate` (cli.py:177-189) which enforces the assessment precondition; blocked → exit 1 *before* `complete_phase` is called; session file not mutated (pinned by `test_bare_invocation_still_requires_assessment`).
3. [VERIFIED] marker targets current phase owner, not `handoff status`'s next-agent — cli.py:226-240 with explanatory comment; pinned by `test_bare_invocation_targets_current_phase_owner` (red → tea, dev excluded).
4. [VERIFIED] gate skip semantics agree across both steps — resolve_gate skip/manual paths (resolve_gate.py:121-141) and `requires_assessment` exemption use the same EXEMPT_GATE_TYPES; `gate_type or "skip"` in cli.py:189 lands in the exempt set.
5. [MEDIUM→table] `status` command and inference disagree on "active session" (sorted-first vs most-recent-mtime) when multiple sessions exist — cli.py:282 vs prime/workflow.py:47. Pre-existing command, but the diff introduces the second convention; folded into the rework as optional unification, recorded as Delivery Finding.

### Devil's Advocate

Assume this diff is broken and I'm defending it to a wizard. The bare protocol's entire premise is "the most-recently-modified session file is the active one" — a stressed filesystem or a checkpoint-writing hook touching an OLD session file flips which story the bare commands operate on, and nothing cross-checks the inferred story against the phase the operator believes they're completing; the command would cheerfully complete-phase a story the agent isn't working on, and the only tell is the story id in YAML output nobody reads. A malicious (or merely confused) repo could commit a `.session/evil-session.md` with `**Workflow:** ../../../tmp/planted` and a `## X Assessment` heading: bare resolve-gate would safe_load YAML from outside the project — safe_load caps the damage at data, not code, but the phases/agents it returns drive which agent persona activates next; that's workflow-control injection via a text file (hence the MEDIUM, not LOW). A confused user who passes only STORY_ID gets workflow/phase from whatever session is freshest — a silent cross-story hybrid. An unreadable session file tells the agent to add a heading that's already there — an instruction that, followed literally by an LLM agent, would APPEND a duplicate heading and "fix" the wrong thing, possibly corrupting the session. And the exit-0-on-error hole means relay automation treats "workflow not found" as success and marches on. None of these are exotic: agents are exactly the kind of user who follows error messages literally and never reads YAML output. The diff's core design is sound — but it ships with the sharp edges above, which is why it goes back.

**Handoff:** Back via red rework — findings are testable behavior changes (validation, error paths, exit codes); Igor pins them, Ponder fixes them.

## Delivery Findings

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): once bare invocation lands, `guides/agent-behavior.md` line 6's bare protocol becomes literally executable; add a parenthetical "(args inferred from the active session; explicit args still supported)" for clarity. Affects `pennyfarthing-dist/guides/agent-behavior.md` (one-line doc touch). *Found by TEA during test design.*
- **Gap** (non-blocking): `pf handoff status` computes `next_agent` as the phase AFTER current — correct for its pre-transition call site but wrong for bare `marker` (post-transition). Dev must use the current-phase-owner lookup; the naming collision invites reuse of the wrong helper. Consider renaming or documenting the two semantics. Affects `pennyfarthing-dist/src/pf/handoff/cli.py` (status command docstring). *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): 4 pre-existing failures in `test_143_9_tdd_cycle_e2e.py` (verify-phase `phase_owner` returns None) on unmodified develop — verified via stash before/after. Affects `pennyfarthing-dist/src/pf/tests/test_143_9_tdd_cycle_e2e.py` (needs triage as its own bug/chore). *Found by Dev during implementation.*
- **Improvement** (non-blocking): the bare exit protocol only reaches live agents after the global pf wheel is reinstalled (`rm -rf pennyfarthing-dist/build` then `uv tool install ./pennyfarthing-dist --force --reinstall --no-cache`). Affects deployment, not code. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking): `pf handoff status` selects the active session alphabetically (sorted-first) while the new inference uses most-recent-mtime via `find_active_session` — two definitions of "active" diverge when multiple sessions exist. Affects `pennyfarthing-dist/src/pf/handoff/cli.py` (status_cmd should call `find_active_session`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the 158-4 test suite asserts marker/RESOLVE_RESULT content via substrings ("tea" in output); parsing the YAML block and asserting fields exactly would be sturdier against future output changes. Affects `pennyfarthing-dist/src/pf/tests/test_158_4_handoff_exit_protocol.py` (assertion hardening). *Found by Reviewer during code review.*

### Reviewer (re-review, rework cycle 1)
- **Gap** (non-blocking): the new `except OSError` in `_infer_session_args` omits `UnicodeDecodeError` — a non-UTF-8 session file escapes as a traceback through all three bare commands; resolve_gate's equivalent handler (added in the same rework) catches it. Affects `pennyfarthing-dist/src/pf/handoff/cli.py:57` (extend tuple to `(OSError, UnicodeDecodeError)`). *Found by Reviewer during re-review.*
- **Improvement** (non-blocking): encoding hygiene sweep — `complete_phase.py` has five pre-existing `read_text()`/`write_text()` calls without `encoding=` (lines 93, 238, 334, 348, 410) on the same files resolve_gate now reads as UTF-8; also `gate_runner.py:76` and `cli.py:317`. A one-commit chore unifies CWE-838 posture. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py` (+2 siblings). *Found by Reviewer during re-review.*
- **Improvement** (non-blocking): test hardening from re-review — RW6 static guard couples to single-line formatting (regex the arg list instead); RW7 lacks a positive assertion on the owner-guard message; RW3/RW4 chmod tests false-negative under euid 0. Affects `pennyfarthing-dist/src/pf/tests/test_158_4_handoff_exit_protocol.py`. *Found by Reviewer during re-review.*
- **Question** (non-blocking): `nxt["agent"]` bare key lookups (resolve_gate.py, pre-existing untouched lines) raise KeyError on an agent-less phase — schema requires `agent`, but `.get()` would match the module's defensive style. Affects `pennyfarthing-dist/src/pf/handoff/resolve_gate.py` (two lookups). *Found by Reviewer during re-review.*

## Design Deviations

### TEA (test design)
- **Pinned CLI arg-inference (AC option c) instead of doc-only fixes (options a/b)**
  - Spec source: session-file ACs (Problem 1), gh #49 suggested fixes
  - Spec text: "Document undocumented arguments in (a) guides… (b) SM agent exit section… or (c) enhance the CLI commands to infer args from the active session file"
  - Implementation: tests pin option (c) — bare invocation infers from session; explicit args pinned as regression guards
  - Rationale: SOUL #3 (Detect State, Don't Demand Commands) + SOUL #11 (Automatic Beats Instructional): docs decay across context clears, inference makes the already-documented bare protocol correct; the issue itself notes agents reconstruct state "from the session file alone"
  - Severity: minor
  - Forward impact: guides need no mandatory change (see Delivery Findings improvement)
- **Rejected the "seed `## Sm Assessment` into sm-setup template" option for Problem 2**
  - Spec source: session-file ACs (Problem 2), gh #49 suggested fixes
  - Spec text: "add `## Sm Assessment` to the sm-setup session template (or to the SM pre-handoff checklist) so it's present before the exit protocol runs"
  - Implementation: tests pin resolve-gate/complete-phase agreement only; sm-setup template deliberately untouched
  - Rationale: a pre-seeded empty heading satisfies `complete_phase`'s `^##\s+.*Assessment` regex forever, turning the mechanical assessment guard into a vacuous check — the cure would erase the gate (SOUL #6)
  - Severity: minor
  - Forward impact: SM agents must still write a real assessment before the exit protocol; resolve-gate now fails loud one step earlier with the heading name in the error

### Dev (implementation)
- **Updated two existing tests pinning the superseded resolve-gate behavior**
  - Spec source: test_handoff_cli.py (105-1 pins) vs context-story-158-4.md ACs
  - Spec text: "resolve-gate returns ready regardless of assessment (guard moved to complete-phase)"
  - Implementation: `test_missing_assessment_resolve_gate_still_ready` → `..._blocks`, `test_missing_session_file_resolve_gate_ready` → `..._blocks`; both now assert `blocked` + `assessment_found is False`
  - Rationale: the 105-1 pins document the exact behavior 158-4 removes; keeping both contracts is impossible
  - Severity: minor
  - Forward impact: none — new pins mirror the 158-4 contract
- **Seeded session files into two unrelated test fixtures**
  - Spec source: story scope (158-4) — "out of scope: unrelated changes"
  - Spec text: fixtures for 143-10 routing and gate-extension tests created `.session/` but no session file
  - Implementation: fixtures now write a minimal session with a `## Dev Assessment` heading
  - Rationale: those tests exercise recovery-routing/extension resolution, not the assessment guard; without sessions they'd fail on the new precondition for reasons unrelated to their concern
  - Severity: minor
  - Forward impact: none — fixture-only, no production code touched

### Reviewer (audit)
- TEA "Pinned CLI arg-inference (AC option c) instead of doc-only fixes" → ✓ ACCEPTED by Reviewer: agrees with author reasoning — SOUL #3/#11; the AC explicitly offered option (c), and inference makes the documented bare protocol truthful.
- TEA "Rejected the seed-`## Sm Assessment`-template option for Problem 2" → ✓ ACCEPTED by Reviewer: correct call — a pre-seeded empty heading satisfies the `^##\s+.*Assessment` regex forever and would render the mechanical guard vacuous (verified against session_assessment.py:20).
- Dev "Updated two existing tests pinning the superseded resolve-gate behavior" → ✓ ACCEPTED by Reviewer: the 105-1 pins assert the precise behavior 158-4 removes; coexistence impossible. NOTE: the class docstring above those tests still states the old contract — confirmed as [MEDIUM] finding, fix in rework.
- Dev "Seeded session files into two unrelated test fixtures" → ✓ ACCEPTED by Reviewer: fixtures must satisfy the new precondition to keep testing their own concern; comments at both seed sites explain the dependency.