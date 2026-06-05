---
story_id: "158-5"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 158-5: pf sprint story claim fails on Jira-less projects with cryptic 'assigned to unknown' (gh #48)

## Story Details
- **ID:** 158-5
- **Jira Key:** (none — Jira-less project)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-05T12:14:46Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-05 | 2026-06-05T11:55:56Z | 11h 55m |
| red | 2026-06-05T11:55:56Z | 2026-06-05T12:04:04Z | 8m 8s |
| green | 2026-06-05T12:04:04Z | 2026-06-05T12:07:41Z | 3m 37s |
| review | 2026-06-05T12:07:41Z | 2026-06-05T12:14:46Z | 7m 5s |
| finish | 2026-06-05T12:14:46Z | - | - |

## Acceptance Criteria

**AC1:** `pf sprint story claim X-Y` on a Jira-less project (no jira config, story jira_key empty) succeeds via local YAML claim, setting status in_progress and assignee, with no Jira call.

**AC2:** The misleading "assigned to unknown" error no longer fires when assignee is null/empty.

**AC3:** Existing Jira-configured claim behavior is unchanged.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): `pf sprint story claim` (`sprint/cli.py::story_claim`) has no `is_jira_enabled()` gate, unlike `pf jira claim` (`jira/cli.py`) which already fails closed. The real fix belongs in `pf.jira.claim.claim_issue` so both the CLI and any programmatic caller get the local fallback. Affects `pennyfarthing-dist/src/pf/jira/claim.py` (`claim_issue`/`claim_story` need a Jira-absent branch).
- **Gap** (non-blocking): The error string at `claim.py:99` (`assigned to {availability.get('assigned_to', 'unknown')}`) defaults to "unknown" whenever the availability dict lacks `assigned_to` — including the "issue not found" path. Even inside the Jira path this message conflates "not found" with "assigned to someone". Dev should ensure the local path produces distinct, accurate messages. Affects `pennyfarthing-dist/src/pf/jira/claim.py`.

### Dev (implementation)
- **Improvement** (non-blocking): The Jira-enabled `claim_story` "assigned to unknown" message at `claim.py` (now line ~99) is unchanged by this story — it still defaults to "unknown" when `check_availability` returns the "issue not found" path. The local Jira-less path now produces accurate, distinct messages, but the Jira path's message could be clarified in a follow-up. Affects `pennyfarthing-dist/src/pf/jira/claim.py` (`claim_story` error string). Out of scope for 158-5 (AC3 = Jira path unchanged). *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking): `unclaim_issue` still calls `get_client()` unconditionally — the symmetric unclaim path (`pf sprint story claim --unclaim`) remains broken on Jira-less projects, the exact bug this story fixes for `claim`. Affects `pennyfarthing-dist/src/pf/jira/claim.py` (`unclaim_issue` needs the same `is_jira_enabled()` gate + local YAML path). Out of scope for 158-5 (AC covers claim only). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Two error-return paths in `_claim_local` are untested — "Sprint file not found" (exit 2) and "Story not found in sprint YAML" (exit 2). They are Jira-independent and could regress silently. Affects `pennyfarthing-dist/src/pf/tests/test_158_5_claim_jira_less.py` (add two cheap return-path tests). *Found by Reviewer during code review (corroborated by [TEST]/[EDGE]).*
- **Improvement** (non-blocking): Re-claiming a story you already own that is already `in_progress` returns a cryptic `exit_code 3` "Cannot transition from in_progress to in_progress" rather than an idempotent success or "already claimed by you". Both the Jira and local paths block re-claim, so this is not a regression, but the local message is unclear. Affects `pennyfarthing-dist/src/pf/jira/claim.py` (`_claim_local` could short-circuit when already owned + in_progress). *Found by Reviewer during code review (corroborated by [EDGE]).*
- **Improvement** (non-blocking): `_claim_local`'s docstring promises "never raises", but `write_sprint` can raise `OSError`/`TypeError` and is unwrapped (same unprotected pattern pre-exists in `claim_story`). Failure is loud (traceback + non-zero exit) and `write_sprint` is atomic (tmp+rename), so no corruption — but either wrap the write or soften the docstring. Affects `pennyfarthing-dist/src/pf/jira/claim.py`. *Found by Reviewer during code review (corroborated by [SILENT]).*
- **Improvement** (non-blocking): `get_current_user_email()` silently falls back to the placeholder `user@example.com` when neither `JIRA_USER` nor `git config user.email` is set, which `_claim_local` then records as the assignee. Pre-existing shared-helper behavior (also used by `sprint/work.py`), only fires on a fully unconfigured machine. Affects `pennyfarthing-dist/src/pf/jira/client.py` (`get_current_user_email`). *Found by Reviewer during code review (corroborated by [SILENT]/[EDGE]).*
- **Improvement** (non-blocking): `pennyfarthing-dist/src/pf/sprint/yaml_io.py` has four `open()` calls without `encoding=` (lines ~107, 349, 363, 404) — lang-review python rule #5. PRE-EXISTING; not in this diff, so out of scope for 158-5, but flagged (not dismissed — rule-matching). Affects `yaml_io.py`. *Found by Reviewer during code review ([SEC]).*

## Impact Summary

**Upstream Effects:** 3 findings (0 Gap, 0 Conflict, 0 Question, 3 Improvement)
**Blocking:** None

- **Improvement:** Two error-return paths in `_claim_local` are untested — "Sprint file not found" (exit 2) and "Story not found in sprint YAML" (exit 2). They are Jira-independent and could regress silently. Affects `pennyfarthing-dist/src/pf/tests/test_158_5_claim_jira_less.py`.
- **Improvement:** Re-claiming a story you already own that is already `in_progress` returns a cryptic `exit_code 3` "Cannot transition from in_progress to in_progress" rather than an idempotent success or "already claimed by you". Both the Jira and local paths block re-claim, so this is not a regression, but the local message is unclear. Affects `pennyfarthing-dist/src/pf/jira/claim.py`.
- **Improvement:** `get_current_user_email()` silently falls back to the placeholder `user@example.com` when neither `JIRA_USER` nor `git config user.email` is set, which `_claim_local` then records as the assignee. Pre-existing shared-helper behavior (also used by `sprint/work.py`), only fires on a fully unconfigured machine. Affects `pennyfarthing-dist/src/pf/jira/client.py`.

### Downstream Effects

Cross-module impact: 3 findings across 2 modules

- **`pennyfarthing-dist/src/pf/jira`** — 2 findings
- **`pennyfarthing-dist/src/pf/tests`** — 1 finding

### Deviation Justifications

2 deviations

- **AC3 covered by a regression guard that passes on HEAD (not RED)**
  - Rationale: AC3 is a preservation requirement, not new behavior. A green guard is the correct shape — it must stay green, and it goes red only if Dev over-applies the local path to the enabled case. All AC1/AC2 tests are genuinely RED.
  - Severity: minor
  - Forward impact: Dev must keep the enabled path routed through `check_availability`; do not collapse both paths into local-only.
- **RED reason for disabled-path tests is "Jira contacted", not the literal AC wording**
  - Rationale: Asserting on the AC's success/message directly would still surface the same bug, but pinning "no Jira contact" is the stable, root-cause-level contract and is independent of the local path's internal naming.
  - Severity: minor
  - Forward impact: none.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **AC3 covered by a regression guard that passes on HEAD (not RED)**
  - Spec source: 158-5 session, SM Assessment AC3 ("Jira-configured claim behavior unchanged")
  - Spec text: "Existing Jira-configured claim behavior is unchanged."
  - Implementation: `test_enabled_still_routes_through_check_availability` asserts the Jira path is still taken when Jira is enabled. Because that behavior already exists, the test is GREEN on HEAD rather than failing.
  - Rationale: AC3 is a preservation requirement, not new behavior. A green guard is the correct shape — it must stay green, and it goes red only if Dev over-applies the local path to the enabled case. All AC1/AC2 tests are genuinely RED.
  - Severity: minor
  - Forward impact: Dev must keep the enabled path routed through `check_availability`; do not collapse both paths into local-only.

- **RED reason for disabled-path tests is "Jira contacted", not the literal AC wording**
  - Spec source: 158-5 session, AC1/AC2
  - Spec text: "claim ... succeeds via local YAML ... no Jira call"; "'assigned to unknown' no longer fires"
  - Implementation: The disabled-path tests wrap the call in a `get_client` guard (`side_effect=AssertionError`). On HEAD they fail because `check_availability` → `get_client()` is reached — i.e. the failure proves the *root cause* (Jira is contacted), which is exactly what the local fallback removes.
  - Rationale: Asserting on the AC's success/message directly would still surface the same bug, but pinning "no Jira contact" is the stable, root-cause-level contract and is independent of the local path's internal naming.
  - Severity: minor
  - Forward impact: none.

### Dev (implementation)
- No deviations from spec. Implemented exactly as TEA scoped: gated `claim_issue` on `is_jira_enabled()`, added a local-only `_claim_local` that reuses `transition_story` (which already skips Jira for keyless stories), blocks real conflicts by name, and left the Jira-enabled path untouched. No data structures simplified, no abstractions added beyond the one helper the tests require.

### Reviewer (audit)
- **TEA deviation "AC3 covered by a regression guard that passes on HEAD"** → ✓ ACCEPTED by Reviewer: AC3 is a preservation requirement; a green guard is the correct shape. The [TEST] subagent did flag the guard as implementation-coupled (it patches `check_availability` and would stay green even if the Jira path were mis-routed) — a fair improvement, captured as a non-blocking finding — but the deviation's reasoning is sound and the guard fulfills its stated purpose (catching over-application of the local path).
- **TEA deviation "RED reason is 'Jira contacted', not literal AC wording"** → ✓ ACCEPTED by Reviewer: pinning "no Jira contact" via the `get_client` guard is the stable root-cause-level contract; verified the disabled-path tests genuinely fail on HEAD for that reason (preflight reproduced 8 RED on the pre-fix code earlier in the cycle).
- **Dev note "No deviations from spec"** → ✓ ACCEPTED by Reviewer: confirmed the implementation matches TEA's scope — `is_jira_enabled()` gate + `_claim_local` reusing `transition_story`, Jira path untouched (verified `claim_issue` has one caller and `pf jira claim` uses `claim.main`, unaffected).
- No UNDOCUMENTED deviations found. The implementation does not diverge from the tests or the ACs.

## SM Assessment

**Scope:** Bugfix in the pennyfarthing framework Python CLI — `pf sprint story claim`. Targets `develop` in the `pennyfarthing/` repo. 2 points, but tagged `tdd` (phased) — honoring the YAML workflow tag over the trivial fallback because this touches claim/assignment control flow and benefits from regression tests around the Jira-vs-local branching.

**The problem (gh #48):** On Jira-less projects, `pf sprint story claim X-Y` exits 2 with "Error: Story not available: assigned to unknown" even though `assignee` is null. Two failures here: (1) no local-YAML fallback when Jira is absent, and (2) a misleading error message that fires on an *empty* assignee as if it were a real assignment.

**Approach for TEA/Dev:** Detect Jira-absent context — no `[jira]` block in `.pennyfarthing/config.local.yaml`, or empty `jira_key` on the story — and route `claim` through the local YAML path (set status `in_progress` + assignee, no Jira call). Ensure the "assigned to unknown" path cannot fire when the assignee field is null/empty. Keep the Jira-configured path untouched.

**TEA focus areas (RED):**
- AC1: claim on a Jira-less project succeeds via local YAML, no Jira call (mock/assert no Jira invocation).
- AC2: null/empty assignee no longer produces "assigned to unknown".
- AC3: Jira-configured claim behavior unchanged (regression guard).

**Note:** This orchestrator project is itself Jira-less (sprints are local-only, Jira is kanban) — the bug is dogfood-relevant. Watch for the distinction between "story already claimed by someone else" (a legitimate block) vs "assignee is empty" (should proceed).

**Routing:** Phased TDD → handoff to TEA (Igor) for RED phase.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Bugfix touching claim/assignment control flow — needs failing tests that pin the Jira-less fallback and the error-message fix, plus a guard against breaking the Jira path.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_158_5_claim_jira_less.py` — Jira-less `claim_issue` behavior (local YAML fallback, no Jira call, correct messaging) + the `pf sprint story claim` CLI end-to-end + AC3 regression guard.

**Tests Written:** 9 tests covering 3 ACs
**Status:** RED confirmed — 8 failing + 1 regression guard passing (scoped run: `uv run pytest src/pf/tests/test_158_5_claim_jira_less.py -q`)

| AC | Tests | Status |
|----|-------|--------|
| AC1 (local claim, no Jira) | `test_claim_returns_success`, `test_claim_sets_status_in_progress`, `test_claim_records_current_user_as_assignee`, `test_claim_makes_no_jira_call`, `test_cli_claim_exits_zero` | failing (RED) |
| AC2 (no "assigned to unknown") | `test_no_assigned_to_unknown_when_assignee_null`, `test_claimed_by_other_blocks_and_names_them`, `test_claim_returns_result_object_never_raises` | failing (RED) |
| AC3 (Jira path unchanged) | `test_enabled_still_routes_through_check_availability` | passing (regression guard — see deviation) |

### Rule Coverage (lang-review/python.md)

| Rule | Test(s) | Status |
|------|---------|--------|
| #6 test-quality (meaningful assertions) | self-check — every test asserts a concrete value/state; no `assert True`, no truthy-only checks, no assertionless calls | clean |
| #1 silent-exceptions / SOUL #10 return-results | `test_claim_returns_result_object_never_raises` (claim returns `{success,...}`, never throws) | failing (RED) |
| #11 input-validation at CLI boundary | `test_cli_claim_exits_zero` (CLI entry `pf sprint story claim` on Jira-less project) | failing (RED) |

**Rules checked:** 3 of 13 lang-review rules are directly applicable to this bugfix and have coverage. (Most others — async, deserialization, dependency hygiene, path handling — don't apply to a claim-routing change.)
**Self-check:** 0 vacuous tests found.

### Implementation guidance for Dev (Ponder)

- Put the fix in `pf.jira.claim.claim_issue` (the function `pf sprint story claim` calls) so both CLI and programmatic callers get it. When `is_jira_enabled()` is False (drive it via `pf.common.config.load_pennyfarthing_config`), route to a **local-only** claim path:
  - Resolve current user via `get_current_user_email()` (already local, reads `JIRA_USER` then `git config`).
  - Find the story by id; if `assigned_to` is set and ≠ current user → block with a message that **names** that assignee (no "unknown").
  - Otherwise set `assigned_to` and transition to `in_progress`. `transition_story(root, id, "in_progress")` already skips Jira for keyless stories — reuse it rather than re-implementing.
  - Do **not** call `get_client()` / `check_availability()` on this path.
- Keep the `is_jira_enabled()`-True path exactly as-is (AC3 guard).
- Return a result dict `{success, error?}` — never raise (SOUL #10).

**Handoff:** To Dev (Ponder Stibbons) for GREEN.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/jira/claim.py` — `claim_issue` now gates on `is_jira_enabled()`; when Jira is absent it routes to a new `_claim_local(story_id)` helper (+81/-1). `_claim_local` blocks if the story is already claimed by another user (naming them — never "unknown"), then calls `transition_story(root, id, "in_progress")` (which already skips Jira for keyless stories) and records `assigned_to` on a fresh read. Returns a result dict, never raises. The Jira-enabled path is unchanged.

**Tests:** 9/9 passing (GREEN) — `uv run pytest src/pf/tests/test_158_5_claim_jira_less.py -q`
**Regression:** `test_jira_cli_disabled_gate.py` + `test_event_driven_jira_sync.py` → 25/25 pass. `ruff check` clean. (Full suite not run — it leaks a `feature/test` branch checkout; verified with targeted runs per project gotcha.)
**Branch:** `feat/158-5-claim-jira-less-projects` (pushed)

**Self-review:**
- [x] Code wired to the real entry point (`pf sprint story claim` → `claim_issue`) — CLI end-to-end test passes.
- [x] Follows project patterns (lazy imports inside the function like the rest of `claim.py`; reuses `transition_story` rather than reimplementing YAML mutation).
- [x] All ACs met (AC1 local claim + no Jira call, AC2 messaging, AC3 Jira path preserved).
- [x] Error handling: result objects with `exit_code`, conflict named, no raises (SOUL #10).

**Handoff:** To Reviewer (Granny Weatherwax) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 (66 tests green, ruff clean, no source mutation) | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 6 | confirmed 6 (all non-blocking), dismissed 0, deferred 0 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 4 | confirmed 3 (non-blocking), dismissed 0, deferred 1 (pre-existing, out of diff) |
| 4 | reviewer-test-analyzer | Yes | findings | 8 | confirmed 8 (non-blocking; several dup edge-hunter), dismissed 0, deferred 0 |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 5 | confirmed 1 (low, info-leak), deferred 4 (pre-existing yaml_io encoding=, out of diff); no traversal/deser issues |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (5 enabled subagents returned; 4 disabled via `workflow.reviewer_subagents`)
**Total findings:** 0 confirmed blocking; ~14 confirmed non-blocking (deduped across agents into 6 themes); 5 deferred (pre-existing / out of diff, captured as Delivery Findings)

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** A tight, well-isolated bugfix. `claim_issue` now gates on `is_jira_enabled()`; the Jira-less branch (`_claim_local`) claims against local sprint YAML with no Jira call, mirroring the proven `transition_story` read→mutate→write pattern. All three ACs are covered by green tests (9/9), plus 25 adjacent regression tests and 32 package-structure tests pass. No Critical/High issues. Every finding is non-blocking (test-coverage gaps on defensive paths, a docstring overpromise, pre-existing out-of-diff issues, and out-of-AC edge UX warts) — none can reintroduce the gh #48 breakage or cause data loss.

**Data flow traced:** `pf sprint story claim 22-1` → `story_claim` (sprint/cli.py:508) → `claim_issue` (claim.py:235) → `is_jira_enabled()` False → `_claim_local` → `find_story_in_data` (dict-key match, no Path interpolation) → conflict guard → `transition_story(root, "22-1", "in_progress")` (jira step skipped, no `jira_key`) → re-read → set `assigned_to` → `write_sprint` (atomic tmp+rename, shard-aware). Safe: `story_id` never reaches a filesystem path; YAML round-trips via ruamel `YAML()` (safe loader).

**Pattern observed:** `_claim_local` (claim.py:255) faithfully reuses the production `transition_story` round-trip rather than reimplementing YAML mutation — correct application of SOUL #2 (one truth) and the codebase's read-modify-write idiom.

**Error handling:** All expected failures return result objects with `exit_code` (sprint-missing → 2, not-found → 2, conflict → 1 naming the assignee, transition-fail → 3); no `raise` on expected paths (SOUL #10). Conflict path names the real assignee — the "assigned to unknown" bug cannot fire (claim.py:295–300).

### Rule Compliance (lang-review/python.md, applied to the diff)

- **#1 silent exceptions:** No bare `except`/swallow introduced in `claim.py`. `_resolve_jira_key`'s broad `except Exception: pass` is PRE-EXISTING and outside the diff. [VERIFIED] claim.py diff adds no try/except. → compliant (in-diff).
- **#3 type annotations at boundaries:** `_claim_local(story_id: str) -> dict[str, Any]` fully annotated; `claim_issue` signature unchanged and annotated. [VERIFIED] claim.py:255. → compliant.
- **#5 path handling / encoding:** In-diff code builds no path from user input (`sprint_path = get_project_root()/"sprint"/"current-sprint.yaml"`). The four `open()`-without-`encoding=` violations are in `yaml_io.py` (NOT in this diff) — flagged, not dismissed, deferred to a follow-up. → compliant (in-diff); pre-existing debt noted.
- **#6 test quality:** No `assert True`, no vacuous truthy-only asserts; every test checks a concrete value/state. `test_claim_returns_result_object_never_raises` is a near-duplicate of `test_claim_returns_success` ([TEST], low) — non-blocking. → compliant.
- **#8 unsafe deserialization:** ruamel `YAML()` round-trip loader, not `yaml.load`. [VERIFIED] yaml_io.py:19. → compliant.
- **#10 (SOUL) return results:** All paths return `{success, ...}`; `write_sprint` could raise `OSError` (loud, atomic write, pre-existing pattern) — docstring overpromise noted non-blocking. → substantially compliant.
- **#11 input validation at boundaries:** `story_id` validated by `transition_story` (`parts[-1].isdigit()`); never used in path construction. [VERIFIED] story_transition.py:51–60. → compliant.

### Observations

- [VERIFIED] No Jira contact on the disabled path — `_claim_local` imports only `get_project_root`, `get_current_user_email` (local), `find_story_in_data`, `transition_story`, `read/write_sprint`; `get_client` is never referenced. Test `test_claim_makes_no_jira_call` asserts call_count 0. claim.py:265–333.
- [VERIFIED] Change is isolated — `grep` confirms `claim_issue` has one caller (sprint/cli.py:508); `pf jira claim` uses `claim.main` (already gated, unaffected). No surprise behavior change.
- [EDGE][MEDIUM] Idempotent re-claim of your own already-`in_progress` story returns cryptic `exit_code 3` (transition error) instead of "already claimed by you" at claim.py:308. Out-of-AC; both Jira and local paths block re-claim. Non-blocking finding.
- [SILENT][MEDIUM] `write_sprint` unwrapped vs `_claim_local`'s "never raises" docstring (claim.py:317); same pattern pre-exists in `claim_story:186`. Loud, atomic, no corruption. Non-blocking.
- [SILENT][LOW] Re-read after `transition_story` returns None → `assigned_to` silently skipped while returning success (claim.py:314). Requires an intra-call race that cannot occur single-process. Non-blocking, defensive note.
- [TEST][MEDIUM] Two `_claim_local` error-return paths (sprint-missing, story-not-found) are untested; the AC-covered paths ARE tested. Non-blocking; recommend TEA add two cheap tests.
- [TEST][LOW] AC3 guard `test_enabled_still_routes_through_check_availability` is implementation-coupled (patches `check_availability`); TEA documented this as a deviation (accepted). A `get_client`-boundary assertion would be stronger. Non-blocking.
- [SEC][LOW] Error messages echo an email (`assigned_to`) and the sprint path — threat-model-inapplicable (single-user local CLI; user already owns the YAML). Non-blocking.
- [TYPE] Skipped — reviewer-type-design disabled via settings. Self-check: the one new public helper is fully annotated; no new stringly-typed boundary introduced.
- [DOC] Skipped — reviewer-comment-analyzer disabled. Self-check: docstrings accurate except the "never raises" overpromise noted above; the inline comment explaining the re-read-after-transition ordering is correct.
- [SIMPLE] Skipped — reviewer-simplifier disabled. Self-check: `_claim_local` is minimal (one helper, no speculative abstraction); reuses `transition_story` rather than duplicating YAML logic.
- [RULE] Skipped — reviewer-rule-checker disabled. Rule compliance enumerated manually above against lang-review/python.md.

### Devil's Advocate

Let me argue this code is broken. The dogfood repo (orc-penny) is itself Jira-less and uses SHARDED sprint YAML (epics as string refs + `epic-*.yaml` shards), but the test fixture uses a single INLINE epic. So the tests never prove that `write_sprint` persists `assigned_to` back into the correct shard file — a malicious gap where the happy-path test is green while a real `pf sprint story claim 159-1` writes nothing, or writes to the wrong file. Could the claim silently no-op on the real repo? I checked: `_claim_local` mirrors `transition_story` exactly (read_sprint→find_story_in_data→mutate→write_sprint), and `transition_story` IS the production transition path used against the sharded repo every workflow, with its shard write-back covered by `test_156_1_*`. `write_sprint(sprint_path, merged_data)` is documented and tested to route mutations back to shards. So the inline-vs-sharded fixture gap is a coverage thinness, not a bug — the behavior is exercised transitively by the proven helper. Still, I'd note it.

What would a confused user do? Run `pf sprint story claim 159-1` twice. The second call, if the story is now `in_progress` and owned by them, returns `exit_code 3` "Cannot transition from in_progress to in_progress" — bewildering, looks like a system crash. That's a real UX wart (captured), but it's loud and reversible, not corrupting. What about `--unclaim` on a Jira-less project? That path was NOT fixed and still calls `get_client()` → the very gh #48 error returns for unclaim. Captured as a finding; out of AC scope but a visible asymmetry. What about a stressed filesystem? `write_sprint` on a full disk raises `OSError` through the "never raises" docstring — but it writes atomically (tmp+rename), so the existing YAML is never half-written; the claim simply fails loudly. What if config has a `jira:` block with `project` set but `url` empty? `is_jira_enabled()` requires BOTH non-empty strings, so it correctly returns False and routes local — verified against client.py:88–93. What if `assigned_to` is an empty string from a hand-edited YAML? `if assigned_to and ...` treats `""` as unclaimed and proceeds — correct. None of these rise to blocking: the AC-covered behavior is correct, hermetically tested, and free of data-loss or security exposure. The devil finds warts, not wounds.

**Handoff:** To SM (Captain Carrot) for finish-story.

<!-- CYCLIST:HANDOFF:/pf-sm -->