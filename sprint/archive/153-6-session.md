---
story_id: "153-6"
jira_key: ""
epic: "153"
workflow: "tdd"
---
# Story 153-6: sm-setup doesn't create sprint/context/context-story-{ID}.md but TEA on-activation expects it — gate sm-setup-exit doesn't enforce; either create or stop requiring

## Story Details

- **ID:** 153-6
- **Jira Key:** (local-only, no external Jira)
- **Epic:** 153 — Framework reliability fixes from downstream reports
- **Title:** sm-setup doesn't create sprint/context/context-story-{ID}.md but TEA on-activation expects it — gate sm-setup-exit doesn't enforce; either create or stop requiring
- **Type:** bug
- **Priority:** P2
- **Points:** 3
- **Repos:** pennyfarthing
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/153-6-context-story-file-gate

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-05-26T16:41:46Z

### Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-05-26T00:00:00Z | 2026-05-26T16:13:27Z | 16h 13m |
| red | 2026-05-26T16:13:27Z | 2026-05-26T16:23:58Z | 10m 31s |
| green | 2026-05-26T16:23:58Z | 2026-05-26T16:30:49Z | 6m 51s |
| spec-check | 2026-05-26T16:30:49Z | 2026-05-26T16:32:02Z | 1m 13s |
| verify | 2026-05-26T16:32:02Z | 2026-05-26T16:36:52Z | 4m 50s |
| review | 2026-05-26T16:36:52Z | 2026-05-26T16:40:48Z | 3m 56s |
| spec-reconcile | 2026-05-26T16:40:48Z | 2026-05-26T16:41:46Z | 58s |
| finish | 2026-05-26T16:41:46Z | - | - |

---

## Context Summary

The TDD workflow has a gate `tea-context` (RED phase entry gate) that validates story context and expects a context file at `sprint/context/context-story-{ID}.md` to exist before TEA activation. However, `sm-setup` does not create this file during story activation, and the `sm-setup-exit` gate does not enforce its creation.

**Gap:** TEA on-activation fails immediately because the expected context file does not exist.

**Decision point:** Either (A) have sm-setup create the context file, or (B) remove the context-file requirement from the tea-context gate.

## Acceptance Criteria

1. **Decision Made:** Session file documents whether the story implements Option A (create) or Option B (stop requiring).

2. **If Option A (Create):**
   - sm-setup generates `sprint/context/context-story-{STORY_ID}.md` at activation time.
   - Context file includes metadata section (Story ID, title, type, points, workflow, repo).
   - Context file includes technical approach (problem, scope, approach hints).
   - Context file includes acceptance criteria from epic YAML.
   - sm-setup-exit gate verifies context-file creation and fails if it's missing.
   - sm-setup completes with context file written and gate passing.

3. **If Option B (Stop requiring):**
   - `tea-context` entry gate is removed or modified to not require the context file.
   - TEA can activate immediately after SM finish without a pre-existing context file.
   - Session file documents that context comes from session file only.

4. **No workflow stalls:** After setup, TEA on-activation does not fail due to missing context files.

5. **Tests verify:**
   - SM setup creates the expected artifact (context file OR no-gate-requirement).
   - TEA can activate without manual intervention.
   - Workflow transitions cleanly from setup to RED.

## Technical Approach

### Problem Analysis

**Current state:**
- `sm-setup` writes session file + branch, but does NOT create context file
- `tea-context` gate (RED phase entry) validates story context and expects context file
- Gate fails when file is missing, stalling the workflow at RED entry

**Root cause:** Disconnect between setup output and gate input requirements.

### Decision: Implement Option A (Create)

We will **create the context file in sm-setup**. Rationale:
- Context files (e.g., `context-story-153-2.md`) already exist as a well-established pattern in the codebase.
- TEA needs context to write failing tests; providing it at setup time (from epic YAML) is cleaner than requiring manual creation.
- The gate can then enforce that the file exists, providing a hard contract.

### Implementation Steps (RED Phase)

1. **Read context from epic YAML:** sm-setup has access to the story's epic shard; extract title, description, acceptance_criteria, type, points, priority.

2. **Generate context file:** Create `sprint/context/context-story-{STORY_ID}.md` with:
   - Story metadata (ID, title, type, points, workflow, repo)
   - Problem section (from story description)
   - Scope section (what is in/out)
   - Technical approach (hints from description if present, otherwise placeholder)
   - Acceptance criteria (copied from epic YAML)
   - Test strategy section (placeholder for TEA to fill in)
   - Out-of-band notes (any additional context)

3. **Update sm-setup-exit gate:** Add a recovery action `context-file-created` that verifies the file was written. If not, the gate fails and blocks workflow progression.

4. **Test coverage:**
   - Unit test: context file generated with all required sections
   - Integration test: full setup workflow creates context file
   - Gate test: tea-context gate passes when file exists

### Key Decision Points for Dev/Architect

- **Template format:** Use existing context-story files as a template (see `sprint/context/context-story-153-2.md`).
- **File location:** Always `sprint/context/context-story-{STORY_ID}.md` relative to repo root.
- **Content sourcing:** Title, type, points, workflow from epic YAML; description and acceptance_criteria from story fields.
- **Gate enforcement:** sm-setup-exit MUST verify the file exists; if not, exit code 1 (failure).

## SM Assessment

**Setup complete. Routing to TEA (Igor) for RED phase.**

- **Story type/size:** 3-point bug in `pennyfarthing/` repo → phased TDD (SM → TEA → Dev → Reviewer).
- **Session + context artifacts:** Both written and verified — `.session/153-6-session.md` and `sprint/context/context-story-153-6.md`. Branch `feat/153-6-context-story-file-gate` created off `develop`.
- **Coordinator note on the decision:** sm-setup pre-recorded "Option A (create the context file)" in Technical Approach. This is a genuine design fork (create the artifact vs. drop the gate requirement). TEA/Dev should treat that as a *recommendation*, not a locked decision — validate it against the actual `tea-context` gate behavior before writing tests. Notably, this very setup run *did* produce the context file, so part of the gap may already be addressed; the real work is making the behavior intentional and gate-enforced.
- **No Jira:** Sprints are local-only; no external claim needed.
- **Handoff target:** TEA for failing tests covering (a) sm-setup produces the context artifact and (b) workflow transitions setup→RED without manual intervention.

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed (15/15 — `test_153_6_context_creation.py`)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3 (`generate.py`, `cli.py`, `test_153_6_context_creation.py`)

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 3 findings | `_CONTEXT_ID_RE` dup w/ validate/cli.py (high); CLI command dup (high); shared ResultDict type (med) |
| simplify-quality | clean | code follows project conventions; no violations |
| simplify-efficiency | 3 findings | CLI command dup (med); dead `project_root` param (high); field-getter helper (low) |

**Applied (2 high-confidence, in-scope):**
- Extracted `_run_create(context_type, target_id)` helper in `cli.py` — `create story`/`create epic` were ~95% identical.
- Removed the dead `project_root` parameter from `generate_context()` — no caller passed it; tests inject via `PROJECT_ROOT` env.

**Flagged for Review (not auto-applied):**
- `_CONTEXT_ID_RE` duplicates `pf.validate.cli` (high confidence on the duplication, but the fix crosses into an out-of-scope file and needs a new shared module — diff-widening + placement decision left explicit for Granny Weatherwax / a follow-up). SOUL #2 candidate.
- Shared `ResultDict`/`OperationResult` type (medium) — codebase-wide refactor, out of this story's scope.

**Noted (low):** repeated `.get()` field extraction in the `_render_*` functions — current code is readable; consolidation not worth the indirection.

**Reverted:** 0.

**Overall:** simplify: applied 2 fixes (behavior-preserving — full suite still 15/15, ruff clean).

**Quality Checks:** ruff clean on all changed files; targeted test suite green. (Full-suite run deliberately avoided — known `test_git_utils` branch-leak hazard.)

**Handoff:** To Reviewer (Granny Weatherwax) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (15/15 green, ruff pass, 0 smells) | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Skipped | disabled | N/A | Disabled via settings |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (1 enabled subagent returned; 8 disabled via `workflow.reviewer_subagents` and pre-filled)
**Total findings:** 3 confirmed (all LOW, non-blocking), 0 dismissed, 0 deferred

> Note: only `preflight` is enabled in this project's `workflow.reviewer_subagents`. I performed the edge/silent-failure/test/type/security/simplifier analyses myself (see observations + Devil's Advocate) since those subagents were disabled — I do not claim coverage from agents that did not run.

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
- [VERIFIED] Result-objects throughout — `generate_context` returns `{success, error?}` / `{success, path?}` (generate.py:134,151,163,172); CLI checks `result["success"]` (cli.py:46). Complies with SOUL #10.
- [VERIFIED] Path-traversal guarded — `_CONTEXT_ID_RE` (generate.py:27,136) rejects `/`, `\`, `.`, `..` before any filesystem access, so the `f"context-{type}-{target_id}.md"` interpolation (generate.py:169) cannot escape `sprint/context/`. Same threat model as `pf.validate.cli` (validate/cli.py:25). Covered by `TestUnknownStoryErrorContract`.
- [VERIFIED] Errors surface, not swallowed — failure path echoes to stderr and exits non-zero (cli.py:47-48); no bare except, no silent fallback in generate.py.
- [VERIFIED] Graceful degradation w/o ACs — `_render_acceptance_criteria` returns a non-empty placeholder when `acceptance_criteria` is absent (generate.py:36-40), so the validator's non-empty check still passes. Covered by `TestGracefulWhenAcsAbsent`. This matters because real shard stories (incl. 153-6) carry no ACs.
- [VERIFIED] Gate contract holds — generate→`pf validate context-story` flips exit 2→0 (`TestGenerateThenValidatePasses`, incl. real-subprocess chain). This is the load-bearing AC (no workflow stall).
- [LOW][SIMPLE] Redundant `load_sprint` — story branch calls `load_sprint(root)` (generate.py:146) for `find_epic`, then `get_story_by_id` (149) re-loads via `get_all_stories()`. Double read of the same files; no correctness/staleness risk. Non-blocking; could thread `sprint_data` through or drop the explicit load.
- [LOW][SOUL-2] `_CONTEXT_ID_RE` is now defined in both `generate.py:27` and `validate/cli.py:25` — a "one truth, one place" duplication. TEA flagged this in the verify Simplify Report. **Confirmed** (rule-matching finding — not dismissable), severity downgraded to LOW (one-line constant, identical semantics). Recommend extracting to a shared module in a follow-up; the fix crosses out-of-scope files so it is correctly left out of this PR.
- [LOW] Silent overwrite — `out_path.write_text` (generate.py:170) clobbers an existing context file without warning. Benign in the normal flow (sm-setup runs it once at setup, before any hand-authoring), but a re-run or a future recovery-pipeline invocation would overwrite richer hand-authored content. See Delivery Findings.

**Data flow traced:** `target_id` (user/CLI arg) → `_CONTEXT_ID_RE` validation (rejects path metacharacters) → `get_story_by_id`/`find_epic` lookup (None → clean error, no write) → `_render_*` (read-only formatting) → `write_text` at a fully-validated, contained path. Safe.

**Pattern observed:** clean CLI-delegates-to-logic split (cli.py → generate.py), lazy import for startup perf (cli.py:43), shared `_run_create` helper. Matches existing `pf` conventions.

**Error handling:** unknown type/invalid id/missing story/missing epic all return result dicts → CLI maps to stderr + exit 1 (generate.py:134-164, cli.py:46-48).

### Rule Compliance

| Rule (source) | Applies to | Verdict |
|---------------|-----------|---------|
| SOUL #10 Return results, don't throw | `generate_context`, `_run_create` | ✅ compliant — result dicts, no raises |
| SOUL #11 Automatic beats instructional | the generator itself | ✅ compliant — promotes prose-instruction to a deterministic command |
| SOUL #2 One truth, one place | `_CONTEXT_ID_RE` | ⚠️ violation (LOW) — duplicated across generate.py + validate/cli.py; follow-up to extract |
| CLAUDE: modify `pennyfarthing-dist/` (source of truth) | all changed files | ✅ compliant — edits in `pennyfarthing-dist/`, not symlinks |
| CLAUDE: Python is the only language | generate.py, cli.py | ✅ compliant |
| Path-safety (validate/cli.py precedent) | `target_id` interpolation | ✅ compliant — regex guard before fs access |

(No `.pennyfarthing/gates/lang-review/python.md` exists in this repo, so the lang-review rubric is N/A; rules drawn from SOUL.md + CLAUDE.md.)

### Devil's Advocate

Argue this is broken. **Data loss:** the strongest attack is the silent overwrite. If an operator has lovingly hand-authored `context-story-153-6.md` (as happened in this very story) and then runs `pf context create story 153-6` — or a future recovery pipeline does — `write_text` flattens it to the thin auto-template with zero warning and no backup. A confused user re-running setup to "fix" a branch issue could destroy real context. The code does not check whether a non-empty file already exists. **Garbage-in:** `_render_acceptance_criteria` does `f"- {item}"` over whatever the YAML holds; if a project ever uses structured (dict) ACs, the output is `- {'ac': ...}` — ugly but non-fatal and validator still passes. **Epic-num parsing:** `target_id.split("-")[0]` on a regex-legal but odd id like `"-5"` yields `""`, and `find_epic("", ...)` silently returns None → epic title blank; harmless because `get_story_by_id("-5")` returns None first → clean error. **Filesystem stress:** if `sprint/` is read-only, `write_text` raises `OSError` — and here generate_context does NOT catch it, so the CLI would traceback instead of returning a result dict (a small SOUL-#10 seam). But this is the same behavior as the rest of the CLI and not introduced risk for the AC. **Stale cache:** none — `load_sprint` reads fresh each call. None of these rise to blocking: the overwrite is the only one with real teeth, and it is out-of-band for the tested flow. Logged as a non-blocking Delivery Finding.

**Handoff:** To SM for finish-story.

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned (two minor, already-logged deviations)
**Mismatches Found:** 2

- **AC-2e "sm-setup-exit gate verifies context-file creation and fails if missing" is softened by a kept fallback** (Different behavior — Behavioral, Minor)
  - Spec: the `sm-setup-exit` gate should *fail* when the story-context file is missing.
  - Code: sm-setup Step 4b now *creates* the file at setup time, so in the normal flow the artifact always exists; the gate's SM-Assessment fallback (sm-setup-exit.md lines 44-48) was left intact as a safety net rather than removed/tightened.
  - Recommendation: **A — accept deviation.** The AC's *intent* (file present at TEA activation → no workflow stall, AC-4) is met by creation-at-setup. Keeping the fallback is defensible belt-and-suspenders that avoids hard-stalls on edge cases; hard-removing it has no failing test and risks regressions in stories that legitimately lack a context file. Already logged by Dev.

- **`pf context create epic` added beyond the tested `create story`** (Extra in code — Behavioral, Trivial)
  - Spec: tests only exercise `create story`.
  - Code: a symmetric `create epic` was added sharing one `generate_context()` helper.
  - Recommendation: **A — accept.** Matches the established `pf context create {type} {id}` surface (`/pf-context create {type} {id}` skill + gate-recovery messages); the asymmetric alternative would be worse. Purely additive. Already logged by Dev.

**Deferred (not this story):** the `create_context` recovery-pipeline *executor* (auto-create on gate failure, not just at sm-setup time) — **D — defer.** TEA already filed it as a non-blocking Delivery Finding. This story delivers the generator the executor would call.

**Reuse note (pragmatic-restraint):** Dev correctly extended the existing `pf context` group and `pf.sprint.loader` rather than introducing new infrastructure; the generator mirrors `pf.validate.cli`'s `_CONTEXT_ID_RE` path-traversal guard. No new patterns introduced.

**Decision:** Proceed to review.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed (pennyfarthing repo, source of truth):**
- `pennyfarthing-dist/src/pf/context/generate.py` (new) — `generate_context(type, id)` reads the sprint YAML and writes a populated `sprint/context/context-{type}-{id}.md`. Result-objects (SOUL #10); `_CONTEXT_ID_RE` guard against path-traversal in the id; graceful when `acceptance_criteria`/`description` absent.
- `pennyfarthing-dist/src/pf/context/cli.py` — added a `create` subgroup with `story` and `epic` commands wrapping the generator.
- `pennyfarthing-dist/agents/sm-setup.md` — added Step 4b (run `pf context create story {STORY_ID}`) + checklist item, so setup produces the artifact the `tea-context` / `sm-setup-exit` gates validate.

**Tests:** 15/15 passing (GREEN) — `test_153_6_context_creation.py`. Verified via testing-runner (RUN_ID 153-6-dev-green). Full-suite run avoided (known git-branch-leak in test_git_utils).

**Branch:** feat/153-6-context-story-file-gate (pennyfarthing repo, base `develop`).

**Environment note (not in the commit):** the installed `pf` shim resolves to a separate migration runtime copy, not the source tree. The testing-runner synced the two new context files into that runtime so the subprocess-based tests exercise the real `pf` binary. The canonical edits are in `pennyfarthing-dist/src/pf/`; the runtime copy is a local install artifact outside this repo.

**Handoff:** To Reviewer (Granny Weatherwax) for code review.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (failing — ready for Dev)

**Test File:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_153_6_context_creation.py` — 15 tests covering the Option A context generator and its wiring.

**RED verification:** 7 failed, 5 errored (fixture-setup, same root cause), 3 passed (precondition guards). All failures/errors trace to the missing `pf context create` subcommand and unwired `sm-setup.md` — RED for the right reason. **No** collection/import/syntax errors.

**Design decision (the A/B fork):** Implemented as **Option A** — a deterministic, non-interactive `pf context create story {id}` generator that reads the sprint YAML and writes `sprint/context/context-story-{id}.md`. The seam is the `pf context` CLI group (matching the 153-5 suite style) so Dev keeps internal-naming freedom. See Design Deviations for full rationale (SOUL #11) and the Option-B invalidation warning.

### Coverage Map

| AC / Rule | Test(s) | Status |
|-----------|---------|--------|
| AC-2 core (command exists) | `TestCreateCommandRegistered` | failing |
| AC-2a (file generated) | `TestCreateStoryGeneratesFile` (in-proc + subprocess) | failing |
| AC-2b/c/d (metadata, approach, ACs) | `TestGeneratedContentSections` (5 tests) | erroring (fixture) |
| Graceful w/o ACs (real-shard shape) | `TestGracefulWhenAcsAbsent` | failing |
| AC-2e/AC-4/AC-5 (generate→validate passes) | `TestGenerateThenValidatePasses` (3 tests) | 1 pass (guard) / 2 failing |
| Error contract (unknown story) | `TestUnknownStoryErrorContract` (2 tests) | passing (guards) |
| Wiring (sm-setup invokes generator) | `TestSmSetupWiresContextCreation` | failing |

**Self-check:** No vacuous assertions — every test asserts a concrete exit code, file existence, or specific content token. No `let _ =` / `assert True` equivalents.

**What Dev must build (GREEN):**
1. A `create` subcommand on `pf context` (`pf/context/cli.py`) → `create story {id}` (and ideally `create epic {id}`), backed by a generator that reads `get_story_by_id` / sprint YAML and writes a populated `context-story-{id}.md` with metadata + approach + ACs sections. Must degrade gracefully when `acceptance_criteria`/`description` are absent. Return-results style; unknown story → non-zero exit, no file written.
2. Wire `sm-setup.md` to invoke `pf context create story {STORY_ID}` during setup.
3. (Optional follow-ups, see Delivery Findings) recovery-executor wiring + sm-setup-exit fallback decision.

**Handoff:** To Dev (Ponder Stibbons) for GREEN.

## Delivery Findings

No upstream findings at setup stage.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)
- **Improvement** (non-blocking): `generate_context` overwrites an existing context file unconditionally via `write_text`. Affects `pennyfarthing-dist/src/pf/context/generate.py` (consider skipping or backing up when a non-empty `context-{type}-{id}.md` already exists, to avoid clobbering hand-authored content on a re-run or recovery-pipeline invocation). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_CONTEXT_ID_RE` is duplicated between `generate.py` and `pf/validate/cli.py` (SOUL #2). Affects both files (extract to a shared constant/module). *Found by Reviewer during code review.*

### Dev (implementation)
- No new upstream findings during implementation. The `create_context` recovery-executor wiring and the `sm-setup-exit` fallback decision (both raised by TEA below) remain open as non-blocking follow-ups; this story delivers the generator + sm-setup wiring that those follow-ups would build on.

### TEA (test design)
- **Improvement** (non-blocking): The `create_context` recovery action is declared in `tdd.yaml` and parsed by `pf.handoff.gate_recovery.get_recovery_actions()`, but no code ever *executes* it — the action dicts are returned and dropped. Affects `pennyfarthing-dist/src/pf/handoff/` (the resolve-gate → complete-phase recovery flow) (needs an executor that invokes the new generator on gate failure so creation is automatic, not only at sm-setup time). *Found by TEA during test design.*
- **Gap** (non-blocking): `gates/sm-setup-exit.md` (story-context-validated, lines 44-48) has a fallback that accepts an "SM Assessment section" in lieu of a context file — this is why 153-6's own setup didn't hard-stall. Option A intends the context file to be the authoritative artifact. Affects `pennyfarthing-dist/gates/sm-setup-exit.md` (Dev/Reviewer should decide whether to keep the escape hatch once generation is automatic). *Found by TEA during test design.*

## Impact Summary

**Upstream Effects:** 2 findings (1 Gap, 0 Conflict, 0 Question, 1 Improvement)
**Blocking:** None

- **Improvement:** `generate_context` overwrites an existing context file unconditionally via `write_text`. Affects `pennyfarthing-dist/src/pf/context/generate.py`.
- **Gap:** `gates/sm-setup-exit.md` (story-context-validated, lines 44-48) has a fallback that accepts an "SM Assessment section" in lieu of a context file — this is why 153-6's own setup didn't hard-stall. Option A intends the context file to be the authoritative artifact. Affects `pennyfarthing-dist/gates/sm-setup-exit.md`.

### Downstream Effects

Cross-module impact: 2 findings across 2 modules

- **`pennyfarthing-dist/gates`** — 1 finding
- **`pennyfarthing-dist/src/pf/context`** — 1 finding

### Deviation Justifications

4 deviations

- **Added `pf context create epic` alongside the (tested) `create story`**
  - Rationale: The command surface `pf context create {type} {id}` mirrors the existing `/pf-context create {type} {id}` skill and the gate-recovery messages; shipping `story` only would be an asymmetric half-feature and would leave the epic-context check with no non-interactive path.
  - Severity: minor
  - Forward impact: none — purely additive; no test depends on the epic path.
- **Kept the `sm-setup-exit` SM-Assessment fallback; did not wire the recovery executor**
  - Rationale: Minimalist discipline — the AC is satisfied (gate validates; file now exists at setup time). Removing the fallback and wiring the recovery executor are larger systemic changes TEA flagged as non-blocking follow-ups; doing them here would be scope creep beyond the failing tests.
  - Severity: minor
  - Forward impact: the recovery-executor wiring (auto-create on gate failure rather than only at sm-setup time) remains a follow-up — see Delivery Findings.
- **Encoded Option A via a new non-interactive `pf context create` CLI generator**
  - Rationale: SOUL #11 (Automatic Beats Instructional) — a Haiku sm-setup following prose cannot be relied upon to author a valid file; it must call a script. The existing `/pf-context` skill is interactive and tandem-requiring, so it is uncallable by sm-setup or the recovery pipeline.
  - Severity: minor
  - Forward impact: Dev adds a `create` subcommand + generator to `pf/context/`. If Reviewer prefers Option B (drop the gate requirement), this entire suite is invalidated and must be rewritten — surface that objection before GREEN, not after.
- **Scoped tests to the generator + sm-setup wiring; did not unit-test recovery-executor or gate-markdown tightening**
  - Rationale: The load-bearing, testable contract is the generate→validate chain (`TestGenerateThenValidatePasses`). Markdown-gate execution is performed by a Haiku agent and has no Python entry point to assert against.
  - Severity: minor
  - Forward impact: A follow-up may wire `create_context` into the recovery pipeline (see Delivery Findings) so creation is automatic on gate failure, not only at sm-setup time.

## Design Deviations

No spec deviations at setup stage.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Added `pf context create epic` alongside the (tested) `create story`**
  - Spec source: TEA test suite (`test_153_6_context_creation.py`) + context-story-153-6.md Scope
  - Spec text: tests only exercise `pf context create story {id}`; the `sm-setup-exit` gate also runs `pf validate context-epic {N}`.
  - Implementation: Implemented `create` as a subgroup with both `story` and `epic`, sharing one `generate_context(context_type, target_id)` helper.
  - Rationale: The command surface `pf context create {type} {id}` mirrors the existing `/pf-context create {type} {id}` skill and the gate-recovery messages; shipping `story` only would be an asymmetric half-feature and would leave the epic-context check with no non-interactive path.
  - Severity: minor
  - Forward impact: none — purely additive; no test depends on the epic path.
- **Kept the `sm-setup-exit` SM-Assessment fallback; did not wire the recovery executor**
  - Spec source: context-story-153-6.md, AC-2e
  - Spec text: "sm-setup-exit gate verifies context-file creation and fails if it's missing."
  - Implementation: sm-setup now *creates* the file (Step 4b), so the gate's existing story-context check passes on the real artifact. The SM-Assessment fallback (gates/sm-setup-exit.md lines 44-48) was left intact as a safety net, and the `create_context` recovery-pipeline executor was NOT added.
  - Rationale: Minimalist discipline — the AC is satisfied (gate validates; file now exists at setup time). Removing the fallback and wiring the recovery executor are larger systemic changes TEA flagged as non-blocking follow-ups; doing them here would be scope creep beyond the failing tests.
  - Severity: minor
  - Forward impact: the recovery-executor wiring (auto-create on gate failure rather than only at sm-setup time) remains a follow-up — see Delivery Findings.

### TEA (test design)
- **Encoded Option A via a new non-interactive `pf context create` CLI generator**
  - Spec source: context-story-153-6.md, AC-1 / Scope ("Option A vs Option B")
  - Spec text: "Decide whether the context file is a requirement or optional: Option A (Create) ... Option B (Stop requiring)"
  - Implementation: The RED suite encodes Option A through a new `pf context create story {id}` command (deterministic, reads sprint YAML), NOT the existing interactive `/pf-context create story` skill. Session file already recorded Option A.
  - Rationale: SOUL #11 (Automatic Beats Instructional) — a Haiku sm-setup following prose cannot be relied upon to author a valid file; it must call a script. The existing `/pf-context` skill is interactive and tandem-requiring, so it is uncallable by sm-setup or the recovery pipeline.
  - Severity: minor
  - Forward impact: Dev adds a `create` subcommand + generator to `pf/context/`. If Reviewer prefers Option B (drop the gate requirement), this entire suite is invalidated and must be rewritten — surface that objection before GREEN, not after.
- **Scoped tests to the generator + sm-setup wiring; did not unit-test recovery-executor or gate-markdown tightening**
  - Spec source: context-story-153-6.md, Scope item 2 + AC-2e
  - Spec text: "Update sm-setup-exit gate to enforce successful context-file creation (add recovery action for context-file-created)."
  - Implementation: Tests pin (a) the generator command and (b) `sm-setup.md` referencing it. They do NOT assert that `gate_recovery` *executes* `create_context`, nor that the `sm-setup-exit` markdown gate removes its SM-Assessment fallback — both are agent/orchestration-layer behaviors, not pytest-unit-testable.
  - Rationale: The load-bearing, testable contract is the generate→validate chain (`TestGenerateThenValidatePasses`). Markdown-gate execution is performed by a Haiku agent and has no Python entry point to assert against.
  - Severity: minor
  - Forward impact: A follow-up may wire `create_context` into the recovery pipeline (see Delivery Findings) so creation is automatic on gate failure, not only at sm-setup time.

### Reviewer (audit)
- **TEA: Encoded Option A via new `pf context create` CLI generator** → ✓ ACCEPTED by Reviewer: Option A is the session-recorded decision and the SOUL #11-compliant choice; the CLI seam is sound.
- **TEA: Scoped tests to generator + sm-setup wiring (no recovery-executor / gate-markdown unit tests)** → ✓ ACCEPTED by Reviewer: those layers are agent-executed and not pytest-unit-testable; the generate→validate chain is the right load-bearing contract.
- **Dev: Added `pf context create epic` beyond tested `create story`** → ✓ ACCEPTED by Reviewer: symmetric, additive, matches the `/pf-context create {type} {id}` surface; no risk.
- **Dev: Kept sm-setup-exit SM-Assessment fallback; did not wire recovery executor** → ✓ ACCEPTED by Reviewer (concurs with Architect spec-check): AC-4 intent (no stall) is met by create-at-setup; removing the fallback has no failing test and risks regressions. Recovery-executor wiring is a tracked follow-up.
- No undocumented deviations found beyond those above. The `_CONTEXT_ID_RE` duplication and silent-overwrite are logged as Reviewer findings/Delivery Findings rather than spec deviations.

### Architect (reconcile)

Verified the four prior deviation entries (TEA ×2, Dev ×2): each carries all six fields, quotes real text from `sprint/context/context-story-153-6.md` (AC-1, AC-2e, Scope), and accurately describes the shipped code. The Reviewer audit stamped all four ACCEPTED; I concur.

- No additional deviations found.

**AC accountability:** No ACs were deferred or descoped. AC-1 (decision documented), AC-2a–d (generator produces metadata/approach/ACs), AC-4 (no stall — generate→validate chain green), and AC-5 (tests verify) are all addressed by the implementation. AC-2e ("gate fails if missing") is satisfied in intent via create-at-setup with the fallback retained — accepted as a minor deviation by both Reviewer and this reconcile. The Option-B branch (AC-3) is moot: Option A was chosen and recorded.

**Audit note for the boss:** the only open items are two non-blocking follow-ups (recovery-pipeline executor wiring; `_CONTEXT_ID_RE` dedup per SOUL #2) and one non-blocking Reviewer finding (silent overwrite of an existing context file). None block this story.