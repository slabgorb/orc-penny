---
story_id: "153-1"
jira_key: null
epic: "153"
workflow: "tdd"
---

# Story 153-1: sm-setup writes session files to .session/ (not sprint/); migrate legacy session files

## Story Details
- **ID:** 153-1
- **Jira Key:** (local-only, no Jira key)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** approved
**Phase Started:** 2026-05-20T17:40:42Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-05-20T16:32:22Z | 2026-05-20T16:34:43Z | 2m 21s |
| red | 2026-05-20T16:34:43Z | 2026-05-20T16:42:25Z | 7m 42s |
| green | 2026-05-20T16:42:25Z | 2026-05-20T16:49:38Z | 7m 13s |
| spec-check | 2026-05-20T16:49:38Z | 2026-05-20T16:52:24Z | 2m 46s |
| verify | 2026-05-20T16:52:24Z | 2026-05-20T16:59:18Z | 6m 54s |
| review | 2026-05-20T16:59:18Z | 2026-05-20T17:17:28Z | 18m 10s |
| green | 2026-05-20T17:17:28Z | 2026-05-20T17:25:53Z | 8m 25s |
| spec-check | 2026-05-20T17:25:53Z | 2026-05-20T17:28:46Z | 2m 53s |
| verify | 2026-05-20T17:28:46Z | 2026-05-20T17:33:57Z | 5m 11s |
| review | 2026-05-20T17:33:57Z | 2026-05-20T17:38:51Z | 4m 54s |
| green | 2026-05-20T17:38:51Z | - | - |

## Delivery Findings

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Question** (non-blocking): The sm-setup.md `Step 4: Write Session File` template currently lacks an explicit literal path instruction (`.session/{STORY_ID}-session.md`) — the path only appears later in `SETUP_RESULT` output, which Haiku-class subagents may interpret as documentation rather than a directive. Affects `pennyfarthing-dist/agents/sm-setup.md` (Step 4 needs explicit "Write the file to `.session/{STORY_ID}-session.md`" instruction line). *Found by TEA during test design.*
- **Improvement** (non-blocking): No canonical session path helper currently exists in Python — every caller open-codes the `.session/<id>-session.md` join. The new `pf.session.paths` module proposed by the red tests provides one place to centralize this and prevent regression. Affects `pennyfarthing-dist/src/pf/session/paths.py` (new module per RED tests). *Found by TEA during test design.*
- **Gap** (non-blocking): There is no CLI surface for triggering migration. Tests only cover the library function; if Dev wants `pf session migrate-paths` as a CLI command, additional Click wiring under `pf/session/cli.py` will be needed. ACs do not require a CLI, so this is left to Dev's discretion. *Found by TEA during test design.*

### Architect (spec-check, round 2)
- **Improvement** (non-blocking): The `pennyfarthing-dist/agents/*.md` files use prose-as-template — placeholders like `{REPO_ROOT}`, `{STORY_ID}`, `{JIRA_KEY}`, `{NOW}` are resolved by the activating subagent reading the markdown, not by any pre-render layer. Round-2 fix #11 (relative→absolute path) papered over a real symptom of this: a relative-path directive becomes a Write-tool failure because the subagent has no template engine to resolve it against `cwd`. Recommend a `pf agent render-template` pre-step that materialises placeholders before the subagent sees them. Affects all agent definitions in `pennyfarthing-dist/agents/`; touch points include `pf/prime/` (would emit rendered templates) and a new `pf/agent/render.py` helper. *Found by Architect during round-2 spec-check.*

## Impact Summary

**Upstream Effects:** 2 findings (0 Gap, 0 Conflict, 1 Question, 1 Improvement)
**Blocking:** None

- **Question:** The sm-setup.md `Step 4: Write Session File` template currently lacks an explicit literal path instruction (`.session/{STORY_ID}-session.md`) — the path only appears later in `SETUP_RESULT` output, which Haiku-class subagents may interpret as documentation rather than a directive. Affects `pennyfarthing-dist/agents/sm-setup.md`.
- **Improvement:** No canonical session path helper currently exists in Python — every caller open-codes the `.session/<id>-session.md` join. The new `pf.session.paths` module proposed by the red tests provides one place to centralize this and prevent regression. Affects `pennyfarthing-dist/src/pf/session/paths.py`.

### Downstream Effects

Cross-module impact: 2 findings across 2 modules

- **`pennyfarthing-dist/agents`** — 1 finding
- **`pennyfarthing-dist/src/pf/session`** — 1 finding

## Design Deviations

No design deviations.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec. Implemented `pf.session.paths` with the three contracted functions and the sm-setup.md Step 4 directive as specified. Did not add the optional `pf session migrate-paths` CLI surface (TEA logged this as a non-blocking Gap; out of scope for this story).

### Dev (rework — round 2)
- **Contract refinement (within Architect's accepted AC2 interpretation):** Identical-content cleanups now report under a new `cleaned` key in the `MigrationResult` TypedDict, rather than under `migrated`. The semantic distinction (move vs. duplicate-cleanup) survives intact and is now visible to callers. `migrated` is reserved for actual relocations. Architect's "two semantically distinct collision branches" forward guidance still holds — the branches are simply more clearly named in the result schema.
- **Byte-IO instead of text-IO for migration:** Switched `read_text`/`write_text` to `read_bytes`/`write_bytes` for both the conflict-compare and the move. This addresses Reviewer's Major #1 (UnicodeDecodeError escape) at the root rather than via exception catching alone — the encoding error class can't arise from a byte compare. The defensive `except (OSError, UnicodeDecodeError)` is kept as belt-and-suspenders for any future text-IO regressions. Test `test_uses_utf8_when_reading_and_writing` still passes because byte-for-byte preservation is a stronger guarantee than utf-8 round-trip.

### Architect (spec-check)
- **Deviation:** `migrate_legacy_sessions` cleans up byte-identical legacy duplicates rather than treating them as "collision → log + skip."
  - **Spec source:** `sprint/context/context-story-153-1.md` — Acceptance Criterion #2.
  - **Spec text (quoted):** *"Does not overwrite an existing `.session/{story-id}-session.md` (collision → log + skip, do not destroy)."*
  - **Implementation:** When `.session/<id>-session.md` exists with content byte-identical to the legacy `sprint/<id>-session.md`, the legacy file is `unlink()`-ed and reported under `result["migrated"]`. Only **different-content** collisions are skipped and reported under `result["skipped"]`. The canonical file is never overwritten or destroyed in either branch.
  - **Rationale:** "Do not destroy" guards against data loss; byte-identical duplication is not data loss. Leaving identical orphans in `sprint/` defeats the migrator's hygiene purpose — the duplicate would re-surface on every subsequent run and could drift if either copy is edited.
  - **Forward impact:** Sibling stories (153-2 through 153-6) should treat `pf.session.paths.migrate_legacy_sessions` as having two semantically distinct collision branches: identical → cleanup, different → skip. Any future CLI wrapper (the deferred `pf session migrate-paths` from 153-3) should surface both counts. The conservative-read alternative was considered and rejected; if a downstream story prefers strict skip-on-any-collision, that's a contract change, not a bug.
  - **Logged by:** Architect (spec-check phase) — 2026-05-20.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/session/paths.py` (new) — `canonical_session_path`, `find_legacy_sessions`, `migrate_legacy_sessions`. Pure-IO, no deps beyond stdlib `pathlib`.
- `pennyfarthing/pennyfarthing-dist/agents/sm-setup.md` — Step 4 now contains a literal directive instructing `Write` tool use against `.session/{STORY_ID}-session.md`, plus a self-creating reminder for the directory. The `Write the session file ... sprint/` adjacency that tripped the negative-instruction guard test was avoided by splitting the warning into separate paragraphs.

**Tests:** 29/29 passing on `test_153_1_session_path_fix.py` (GREEN). Full suite delta vs. baseline: net -1 failure (my changes fixed 1 test, no regressions). The other pre-existing failures (test_143_9 e2e, test_148_23 reviewer gate clarity, test_peloton tmux panes, test_pypi packaging, test_141_20 agent validator) are unrelated to my touch points — confirmed by `git stash && pytest` baseline.

**Heads-up:** `test_143_9_tdd_cycle_e2e.py` actually checked out a different branch (`feature/test`) during my full-suite run — that test does live git operations and is not sandboxed. I switched back to `feat/153-1-sm-setup-session-path-fix` and verified all my edits are intact. Worth flagging to the team but out of scope here.

**Branch:** `feat/153-1-sm-setup-session-path-fix` (pushed after commit).

**Handoff:** → Reviewer (Granny) for review phase.

## Dev Assessment (rework — round 2)

**Trigger:** Granny's REQUEST-CHANGES from round-1 review — 13-item fix batch (2 Majors, 6 Minors, 4 Trivials, with #5 a test-broadening directive).

**All 13 items addressed:**

| # | Severity | Item | Resolution |
|---|----------|------|------------|
| 1 | Major | `UnicodeDecodeError` escapes per-file handler | Switched migration to byte-IO; defensive catch `(OSError, UnicodeDecodeError)` retained. Regression test `test_non_utf8_file_does_not_abort_migration` with Granny's `b'\xff\xfe\xfd'` reproducer. |
| 2 | Major | Null byte bypasses path-traversal validator | Replaced blocklist with allowlist `^[A-Za-z0-9_-]+$`. Three new regression tests: null byte, Windows drive letter `C:foo`, Cyrillic homoglyph. |
| 3 | Minor | Symlinks not skipped in `find_legacy_sessions` | `entry.is_symlink()` short-circuit added before `is_file()`. Regression test `test_skips_symlinks_in_sprint_dir` with cross-tree symlink. |
| 4 | Minor | Dry-run identical-content misreported as `migrated` | Introduced `cleaned` field; identical-content cleanups (real and dry-run) now route there. Regression test `test_dry_run_identical_content_not_reported_as_migrated`. |
| 5 | Minor | Negative-instruction guard regex too narrow | Broadened to (a) any directive verb in {write,save,create,place,put,store,emit,output,persist} adjacent to "session...sprint/", and (b) any `sprint/<X>-session.md` mention not under `archive/`. |
| 6 | Trivial | Dead `_ARCHIVE_DIR_NAME` constant | Removed. |
| 7 | Trivial | `ruff check --fix` | Applied (I001 import sort). Ruff now clean. |
| 8 | Trivial | Redundant mkdir paragraph in sm-setup.md | Collapsed into the Write-tool note (the Write tool creates parent dirs). |
| 9 | Minor | Lying/incomplete docstring | Rewritten — adds partial-completion semantics: non-empty `errors` ⇒ run completed but did not process every legacy file. |
| 10 | Minor | "byte-for-byte" comment misleading | Implementation now actually uses `read_bytes()` — true byte compare. Comment updated to match. |
| 11 | Minor | sm-setup.md prepend used relative path | Reworded to `{REPO_ROOT}/.session/{STORY_ID}-session.md` with explicit instruction to resolve `{REPO_ROOT}` from activation context. |
| 12 | Minor | Heterogeneous `dict[str, list]` return | Introduced `MigrationResult(TypedDict)` with typed fields `migrated: list[Path]`, `cleaned: list[Path]`, `skipped: list[str]`, `errors: list[str]`. |
| 13 | Trivial | Missing `__all__` | Added with the four public symbols. |

**Tests:** 35/35 passing on `test_153_1_session_path_fix.py` (was 29). Six new tests for items 1, 2 (×3), 3, 4.
**Ruff:** clean on `paths.py`.
**Broader suite:** baseline pre-existing failures (test_143_9, test_148_23, test_peloton, test_pypi, test_141_20) unchanged — no new regressions from this rework.

**Files Changed (round 2):**
- `pennyfarthing/pennyfarthing-dist/src/pf/session/paths.py` — full rewrite: `MigrationResult` TypedDict, `__all__`, allowlist validator, symlink-skip, byte-IO migration, `cleaned` field, expanded docstrings, dead-constant removal. Imports sorted.
- `pennyfarthing/pennyfarthing-dist/agents/sm-setup.md` — Step 4 prose reworded to use absolute `{REPO_ROOT}/...` template and removed redundant mkdir paragraph.
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_153_1_session_path_fix.py` — 6 new tests + broadened forbidden-pattern set.

**Branch:** `feat/153-1-sm-setup-session-path-fix` (pushed after commit).

**Handoff:** → Architect (Leonard) for spec-check pass before Igor verifies and Granny re-reviews.

## TEA Assessment

**Phase:** approved
**Tests Required:** Yes
**Status:** RED (27 failing — ready for Dev)

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_153_1_session_path_fix.py` — 29 tests across 4 classes covering both ACs and Python lang-review rules.

**Expected Module (to implement):** `pf.session.paths`
- `canonical_session_path(root: Path, story_id: str) -> Path` — always `<root>/.session/<id>-session.md`; validates story_id (rejects empty, rejects `..` traversal).
- `find_legacy_sessions(root: Path) -> list[Path]` — finds `<root>/sprint/*-session.md`; ignores `sprint/archive/`, `.session/`, and non-session files.
- `migrate_legacy_sessions(root: Path, *, dry_run: bool = False) -> dict` — moves legacy session files to canonical; returns `{migrated, skipped, errors}`; idempotent; non-destructive on canonical conflict; safe-deletes legacy when content identical to canonical.

**Expected Agent Definition Fix:** `pennyfarthing-dist/agents/sm-setup.md` `## Step 4: Write Session File` must contain a literal directive instructing writing to `.session/{STORY_ID}-session.md`. Currently the path only appears in the `SETUP_RESULT` output template.

**Test Status Summary:**
| Class | Failing | Passing |
|-------|---------|---------|
| TestCanonicalSessionPath | 8 | 0 |
| TestSmSetupAgentDocSpecifiesCanonicalPath | 1 | 2 (regression guards) |
| TestFindLegacySessions | 6 | 0 |
| TestMigrateLegacySessions | 12 | 0 |
| **Total** | **27** | **2** |

The 2 passing tests are not vacuous — they encode invariants we want preserved (sm-setup.md file exists, no sprint/-path instruction was ever added). They will keep passing after the fix and serve as regression guards.

### Rule Coverage (Python lang-review)

| Rule | Test(s) | Status |
|------|---------|--------|
| #3 Type annotations at boundaries | `test_returns_pathlib_path_not_string` (asserts return type contract) | failing |
| #5 Path handling — pathlib not str | `test_returns_pathlib_path_not_string`, `test_uses_utf8_when_reading_and_writing` | failing |
| #5 Path handling — explicit encoding= | `test_uses_utf8_when_reading_and_writing` (non-ASCII content survives migration) | failing |
| #6 Test quality — meaningful assertions | self-check passed: every test asserts a specific value/path/state, no `assert True`, no truthy-only checks on always-truthy values | n/a (self-check) |
| #11 Input validation at boundaries | `test_rejects_empty_story_id`, `test_rejects_path_traversal_in_story_id` (CWE-22) | failing |

**Rules checked:** 4 of 13 lang-review rules have direct test coverage. Remaining rules (#1 silent exceptions, #2 mutable defaults, #4 logging, #7 resource leaks, #8 unsafe deserialization, #9 async, #10 imports, #12 deps, #13 fix-regressions) are not applicable to this small pure-IO module — Dev should still self-check during green.

**Self-check:** 0 vacuous tests found.

**Self-Review:**
- [x] Tests fail for the right reasons (ModuleNotFoundError + content assertions on existing file)
- [x] No implementation code written
- [x] Correct branch: `feat/153-1-sm-setup-session-path-fix`
- [x] Both ACs covered
- [x] Edge cases: empty input, path traversal, missing dirs, multiple files, dry-run, idempotency, non-destructive overwrite, identical-content cleanup, archive isolation, unicode content
- [x] Working tree clean (only the new test file added)

**Pre-existing unrelated failure:** `test_141_20_agent_validator.py::TestOnActivationLinePosition::test_on_activation_after_line_100_warns` fails on develop too — not caused by this story.

**Handoff:** To Ponder Stibbons (Dev) for GREEN phase.

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned (with one logged interpretation deviation)
**Mismatches Found:** 1 deliberate, 1 partial-coverage observation

### AC Trace

| AC | Spec | Implementation | Status |
|----|------|----------------|--------|
| AC1 | `sm-setup` writes session files to `.session/{story-id}-session.md`; verified by automated test | `pennyfarthing-dist/agents/sm-setup.md` Step 4 now opens with literal directive: *"Write the session file to the canonical path: `.session/{STORY_ID}-session.md`"* + `mkdir` reminder. Test `test_write_session_file_step_mentions_canonical_path` greps the directive; negative-guard `test_agent_doc_does_not_instruct_sprint_path` blocks regression. | **Met** |
| AC2 | Migration helper: detects legacy; relocates without data loss; idempotent on clean state; does not overwrite — collision → log + skip, do not destroy | `pf.session.paths` provides `find_legacy_sessions` + `migrate_legacy_sessions`. Non-destructive on **different-content** collision (test `test_non_destructive_when_canonical_already_exists_with_different_content`); idempotent (`test_is_idempotent_when_no_legacy_remains`); identical-content branch cleans up the legacy duplicate (see deviation below). | **Met** (interpretation logged) |
| AC3 | Existing sm-setup behavior (frontmatter, content, branch creation, workflow routing) unchanged | Step 4 was extended at its head with one paragraph; the template body (frontmatter, content blocks, Step 5 branch creation, Step 6 routing) is byte-identical against `develop`. `git diff develop..HEAD -- pennyfarthing-dist/agents/sm-setup.md` = 6 lines added, 0 removed. No assertion-style test proves "unchanged"; coverage is observational. | **Met** (coverage partial — see Finding) |
| AC4 | New tests cover: write-path correctness, migration happy path, migration idempotency, migration collision-skip | 29 tests across 4 classes. Write-path: `TestSmSetupAgentDocSpecifiesCanonicalPath`. Happy path: `test_moves_legacy_file_to_canonical_location` + `test_preserves_file_content`. Idempotency: `test_is_idempotent_when_no_legacy_remains`. Collision-skip: `test_non_destructive_when_canonical_already_exists_with_different_content`. | **Met** |

### Mismatches

- **AC2 identical-content cleanup goes beyond literal spec** (Different behavior — Behavioral, Minor)
  - Spec: AC2 reads *"collision → log + skip, do not destroy."* A literal read treats *any* existing canonical file as a collision.
  - Code: When canonical exists with byte-identical content, the legacy duplicate in `sprint/` is `unlink()`-ed and reported under `migrated` (not `skipped`). Only **different-content** collisions are log+skip.
  - Recommendation: **A — Update spec.** Keep the aggressive cleanup. Rationale: (1) "do not destroy" protects against data loss; byte-identical duplication is not data; (2) leaving identical orphans in `sprint/` invites future drift (edit-one-not-the-other), which re-creates the collision next run; (3) the migrator's job is hygiene — leaving a known-duplicate violates the spirit of idempotency. Logging this as a deliberate interpretation deviation for traceability.

- **AC3 coverage is observational, not asserted** (Missing in code — Behavioral, Trivial)
  - Spec: AC3 requires "existing sm-setup behavior unchanged."
  - Code: No automated assertion proves invariance of Step 5/6 or frontmatter template. Coverage rests on the diff being a pure insertion at the head of Step 4.
  - Recommendation: **D — Defer.** Don't block on this. A "byte-snapshot" of sm-setup.md is wasteful test scaffolding for a single-paragraph change. If the framework grows further structural drift, raise a follow-up to add a `sm-setup-template-shape.snap` golden. Granny may exercise judgment; I would not block on it.

### Scope Discipline

- **153-6 (context-file creation):** No bleed. Implementation touches no path under `sprint/context/`. ✅
- **153-3 (move/--epic CLI surface):** No bleed. No new Click command added; TEA's Gap finding for `pf session migrate-paths` is deferred per Dev's explicit note. ✅

### Architectural Gut-Check: `pf.session.paths`

Shape: 3 module-level pure functions, stdlib-only (`pathlib`), no class, single `__future__` import.

Fits convention. Sibling `pf.session.append_only` follows the exact same pattern (module-level helpers, stdlib-only, no class — see `append_only._parse_frontmatter`). The `pf/` package favors flat-module pure functions over class-based encapsulation for utility code; introducing a class here would be over-engineering. Module placement (`pf/session/`, not `pf/sprint/`) correctly distinguishes runtime session-file concerns from sprint-tracking concerns.

One latent reuse opportunity (not for this story): `pf/prime/session.py:27` still open-codes `project_root / ".session" / "agents"`. That's a *different* path (the agents subdir), but the same anti-pattern of open-coded session-path joins. A follow-up could extend `pf.session.paths` with `agent_session_dir(root) -> Path` and migrate that caller. **Not in scope for 153-1.** Logging as upstream finding.

### Clockwork Migrator Notes (for the curious — not blocking)

A small modular escapement could be fitted to the migrator such that, when invoked on a directory tree, it would walk every potential session-bearing nook and tick off file relocations with a satisfying clockwork rhythm. The mechanism would naturally extend to context files (153-6) and could perhaps even auto-detect drift in `.session/agents/` if a tiny mainspring were wound on each `pf prime`. — I can't imagine why anyone would object to that. I shall sketch it in my journal.

### Decision

**Proceed to review.** Hand off to Granny Weatherwax. Both findings above are documented for her audit; neither requires Dev rework.

### Architect (spec-check, round 2)

Commit reviewed: `c6aa6c471` — *fix(153-1): address round-1 review fix batch (13 items)*. Scope: deltas only.

**1. `MigrationResult.cleaned` field — ratified.**

The round-1 deviation I logged stated that `migrate_legacy_sessions` had "two semantically distinct collision branches — identical → cleanup, different → skip" that were collapsed under `migrated`. Round 2 formalises that distinction in the return contract: `migrated` is now reserved for true relocations (canonical did not exist), `cleaned` carries identical-content unlinks, `skipped` carries different-content conflicts, `errors` carries per-file failures. The `TypedDict` is exported via `__all__`, so the contract is public.

- **Name:** `cleaned` is correct. Conveys "the legacy duplicate was tidied away," distinct from `migrated` (real move) and `skipped` (untouched conflict). Considered alternatives (`deduplicated`, `pruned`, `redundant`) all add length without adding clarity.
- **Shape:** `list[Path]`, matching `migrated`. Symmetric. The `list[str]` for `skipped`/`errors` is intentional asymmetry — they carry context strings while paths are just paths. Acceptable; consistent with round 1.
- **Test coverage:** `test_dry_run_identical_content_not_reported_as_migrated` directly asserts dry-run identical-content lands in `cleaned`, not `migrated`. Good.
- **Net effect on round-1 deviation:** the deviation is now *encoded in the type*, not just documented in prose. The round-1 deviation entry stays in place for the audit trail and should be read as "this distinction was logged as a deviation, then promoted to the formal return schema in round 2 — see `MigrationResult`."

**Verdict:** Approve as designed. No further changes requested.

**2. `{REPO_ROOT}` placeholder — semantically robust given existing convention.**

The fix changes Step 4 from a relative path (`.session/{STORY_ID}-session.md`) to an absolute path (`{REPO_ROOT}/.session/{STORY_ID}-session.md`) with a prose definition: *"`{REPO_ROOT}` is the project root (the directory containing `.pennyfarthing/`)."* This is materially correct — the Claude Code `Write` tool refuses relative paths, so the round-1 directive was structurally broken. That is very plausibly the bug class that originally led to session files landing in `sprint/`: a subagent that can't resolve a relative path falls back to writing somewhere it shouldn't. The round-2 fix attacks the actual root cause.

Is it papering over a missing template? Partially. There is no formal template-substitution layer between agent definitions and the activating subagent — every placeholder in this file (`{STORY_ID}`, `{JIRA_KEY}`, `{EPIC_JIRA_KEY}`, `{WORKFLOW}`, `{DEPENDS_ON}`, `{NOW}`, `{TITLE}`) is resolved by the subagent reading prose and substituting from its activation context. `{REPO_ROOT}` joins that crowd consistently; it does not introduce a new debt, only sits on existing debt.

The robust long-term fix is a pre-render step (`pf agent render-template`) that fills these placeholders before the subagent sees them — turn prose-as-template into actual template. That belongs in a separate framework-reliability story. Logging as an upstream Improvement finding for follow-up.

**Verdict:** Accept the round-2 wording for 153-1. The fix is correct and consistent with the file's existing pattern. The template-system gap is a separate, larger problem.

**3. Scope check — clean.**

- Three files touched, same set as round 1: `agents/sm-setup.md`, `src/pf/session/paths.py`, `src/pf/tests/test_153_1_session_path_fix.py`.
- No writes under `sprint/context/` → no bleed to 153-6.
- No new Click command, no `pf session migrate-paths` surface → no bleed to 153-3.

**4. AC trace delta:**

| AC | Round-1 status | Round-2 change | Round-2 status |
|----|---------------|----------------|----------------|
| AC1 | Met (directive present) | Directive now absolute path — fixes likely root cause of the original bug class | **Met, improved** |
| AC2 | Met (interpretation deviation logged) | Distinction promoted from deviation-in-prose to formal `MigrationResult` return contract; new tests for symlink-skip (CWE-59), allowlist (null byte / drive letter / homoglyph), non-UTF-8 byte-IO | **Met, strengthened** |
| AC3 | Met (observational) | sm-setup.md delta +3/-3 lines, all inside Step 4; Steps 5/6 + frontmatter untouched | **Met (unchanged)** |
| AC4 | Met (29 tests) | Tests grew 29 → 35; six additions are non-vacuous and target round-1 findings + new `cleaned` bucket | **Met, broader** |

**Decision:** Proceed to verify. No mismatches require Dev rework.

## Tea Verify

**Phase:** approved
**Status:** PASS — all 4 verify items green; ready for Reviewer (Granny Weatherwax).
**HEAD:** `8369446cc feat(153-1): canonical .session/ path + legacy migration helper`

### Verify Checklist

| # | Item | Result | Detail |
|---|------|--------|--------|
| 1 | `test_153_1_session_path_fix.py` all 29 pass at `8369446cc` | **PASS** | `29 passed in 0.13s` |
| 2 | Broader `pf` test suite — no NEW regressions | **PASS** | 4430 passed; 21 failed + 4 errored (all pre-existing on `develop`, confirmed via branch-checkout diff) |
| 3 | Integration: mixed identical+differing legacy in same tree | **PASS** | Identical legacy unlinked; differing legacy preserved AND reported in `skipped[]` with both paths in the log message |
| 4 | `dry_run=True` mutates nothing on disk | **PASS** | File-existence and mtime_ns snapshotted before/after — bit-for-bit unchanged; `result['migrated']` still reports planned actions (2 plans + 1 skip for 3 input files) |

### Pre-Existing Failures (NOT introduced by 153-1)

Verified on `develop` (no 153-1 commits) — these fail there too:

| File | Failures |
|------|----------|
| `test_141_20_agent_validator.py` | 2 (line-position warning, file-length error) |
| `test_143_9_tdd_cycle_e2e.py` | 8 (full-cycle, phase-history, finish-state, frontmatter) |
| `test_143_10_reviewer_dev_roundtrip.py` | 1 (full_rework_then_approval) |
| `test_143_12_subagent_dispatch.py` | 2 (missing-tags, scattered-tags) |
| `test_148_23_reviewer_gate_clarity.py` | 4 (gate clarity ACs) |
| `test_peloton_pane_layout.py` | 2 (cli/tui pane not killed) |
| `test_pypi_packaging.py` | 1 fail + 4 errors (wheel build) |

**Team-lead listed 21**; observed 24 fail+err — the extra 3 (`test_143_10`, `test_143_12`) are also pre-existing per direct check on `develop`. Worth a separate ticket but **not blocking** for 153-1.

### Integration Evidence (real impl, not stubs)

```
=== Mixed scenario ===
  identical-content legacy unlinked: PASS
    canonical_a preserved: '# Story A\nidentical content\n'
  differing-content legacy preserved + skipped+logged: PASS
    skipped[0]: '<tmp>/sprint/B-1-session.md: canonical <tmp>/.session/B-1-session.md exists with different content'
  migrated=['<tmp>/sprint/A-1-session.md']
  errors=[]

=== Dry-run scenario (3 input files: identical, differing, new) ===
  before: 5 files snapshotted (existence + mtime_ns)
  after: filesystem byte-identical (mtime-stable, no new files)
  result reported plan: migrated=2 skipped=1
```

The differing-content adjacency proof matters: in the mixed scenario, `A-1` (identical) is unlinked while `B-1` (differing) is **preserved alongside its canonical** — confirming the impl distinguishes the two cases when they coexist in the same migration call. Not a stub artifact.

### Aggressive AC2 Interpretation — Confirmed by Spot-Check

Per Leonard's spec-check: the impl treats identical-content collisions as duplicate cleanup, not "log+skip". The integration scenario validates BOTH paths fire correctly in the same tree — identical→unlink, differing→preserve+log. This is the safer interpretation (no orphan duplicates left to drift).

### Implementation Quality Observations

- 122 lines of well-documented Python (`pf/session/paths.py`). Three module-level constants for the path tokens (`_SESSION_DIR_NAME`, `_SPRINT_DIR_NAME`, `_SESSION_SUFFIX`) — no scattered string literals.
- Validates input at the boundary (CWE-22): rejects `..`, `/`, `\\` in `story_id`.
- Uses `pathlib` throughout; reads/writes with explicit `encoding="utf-8"` (Python lang-review rule #5).
- Wraps file ops in `try/except OSError`, collecting failures in `result["errors"]` rather than raising — graceful degradation suitable for a migration helper. Catches narrowly on `OSError`, not bare `Exception` (rule #1).
- Returns Results-style dict (`{migrated, skipped, errors}`) per SOUL principle #10.

### Simplify Fan-Out

**Skipped per team-lead's tailored verify checklist.** Code surface is 122 lines, single-purpose, no duplication observed. I read the impl end-to-end and saw nothing the three simplify lenses would flag:
- Reuse: only one open-coded path join elsewhere (`pf/prime/session.py:27` for the agents subdir — *different* path, separate concern, logged as a non-blocking finding for a future story).
- Quality: naming is consistent (`legacy`, `canonical`), no dead code, no over-long functions.
- Efficiency: O(N) over legacy files; no quadratic scans; `Path.read_text` once per file with no redundant reads.

### Self-Review Before Handoff

- [x] All 4 verify items PASS
- [x] No new regressions in broader suite (confirmed via branch checkout)
- [x] Integration scenario tested against real impl, not stubs
- [x] dry-run truly inert (mtime_ns stable)
- [x] Working tree clean apart from session file edits (and `?? scripts/portraits/` which is unrelated stash from prior work)
- [x] Architect's two findings noted in this assessment for Granny
- [x] No code changes made during verify — TEA does not edit source in this phase

**Handoff:** → Reviewer (Granny Weatherwax) for code review.

## Reviewer Assessment

**Phase:** approved
**Verdict:** REQUEST-CHANGES
**HEAD:** `8369446cc feat(153-1): canonical .session/ path + legacy migration helper`
**Reviewer:** Granny Weatherwax

### Headline

The migration helper's stated contract — "graceful per-file handling, errors collected in `result['errors']`" — is contradicted by the implementation. A single non-UTF-8 legacy file crashes the entire migration mid-loop and leaves subsequent files unprocessed. Reproduced live with `b'\xff\xfe\xfd'` payload. For a **P0 framework reliability fix** whose whole purpose is a defensive migrator, that's the wrong shape to ship. Add to that an incomplete path-traversal validator (null byte bypass) and the story needs one more pass.

The interpretation deviation Leonard logged for AC2 (identical-content cleanup) is **accepted with rationale** below.

### Findings

**Specialist-tag legend** (for tracing each finding to its surfacing specialist):
`[DOC]` = reviewer-comment-analyzer · `[EDGE]` = reviewer-edge-hunter · `[RULE]` = reviewer-rule-checker · `[SEC]` = reviewer-security · `[SILENT]` = reviewer-silent-failure-hunter · `[SIMPLE]` = reviewer-simplifier · `[TEST]` = reviewer-test-analyzer · `[TYPE]` = reviewer-type-design

| # | Severity | Tags | Issue | Location | Fix |
|---|----------|------|-------|----------|-----|
| 1 | **Major** | `[SILENT]` `[EDGE]` `[RULE]` `[DOC]` | `UnicodeDecodeError` escapes `except OSError` — a single non-UTF-8 legacy file aborts the migration loop, leaving pending files unprocessed and nothing in `result['errors']`. Live-reproduced traceback. The function's contract is per-file graceful handling; this breaks it. Rule-checker also flags as Rule #1 violation (TEA's RED-phase audit incorrectly declared the rule non-applicable). Comment-analyzer flags the docstring's "Idempotent and non-destructive" claim as a lie under this path. | `paths.py:119` (catch) reading at `:98,:115` | Change `except OSError` to `except (OSError, UnicodeDecodeError)`. Add a regression test that plants a `b'\xff\xfe\xfd'` legacy file alongside a valid one and verifies the valid one still migrates and the bad one appears in `errors`. |
| 2 | **Major** | `[SEC]` `[EDGE]` | `canonical_session_path` accepts `\x00` in `story_id`. The validator advertises CWE-22 protection but null byte is the canonical CWE-158 path-truncation vector. Reproduced — `canonical_session_path(root, 'abc\x00xyz')` returns a path with embedded null and only fails later when `open()` rejects it. Defense-in-depth gap on a function whose only job is input validation at the boundary. | `paths.py:39` | Add `'\x00' in story_id` to the rejection condition. Add a regression test. Optional but cleaner: tighten to an allowlist (`re.fullmatch(r'[A-Za-z0-9_-]+', story_id)`) — kills null byte, Windows drive-letter (`C:foo`), Unicode-homoglyph, and any future bypass in one stroke. |
| 3 | Minor | `[EDGE]` `[SEC]` `[SIMPLE]` | Symlinks under `sprint/` are followed: a symlink `sprint/foo-session.md → ../OUTSIDE-session.md` causes the target's content to be copied into `.session/foo-session.md`. CWE-59. Low practical risk on a single-user dev box, but real if `sprint/` is ever on shared CI infra, and trivial to defend against. Reproduced. Simplifier separately observed that `legacy.rename(canonical)` would be atomic and faster than the current `read+write+unlink` sequence. | `paths.py:59` | Add `if entry.is_symlink(): continue` before `is_file()` in `find_legacy_sessions`. Alternative: use `legacy.rename(canonical)` instead of `read_text + write_text + unlink` in the move branch — also faster and atomic. |
| 4 | Minor | `[SILENT]` | `dry_run=True` with identical-content canonical still appends to `result['migrated']` even though nothing happens. Misleading: caller counting `len(result['migrated'])` overstates planned changes. | `paths.py:102-104` | Either skip the append in dry-run mode for the identical-content branch, surface it under a `would_clean` key, or document the conflation explicitly in the docstring. |
| 5 | Minor | `[TEST]` | Negative-instruction guard regex in tests is too narrow — only catches literal `{STORY_ID}` placeholder forms. Paraphrases like `"save session file under sprint/"` or `"session file path: sprint/153-1-session.md"` slip through. False confidence on the regression guard whose entire purpose is to prevent the bug returning. | `test_153_1_session_path_fix.py:179-183` | Replace with one broader pattern: `r'sprint/[^"\s/]*-session\.md'` (catches any concrete or templated session path under sprint/), plus a directional-prose check like `r'(?:write\|save\|place\|put\|create)[^\n]{0,80}sprint/[^\n]*session'` (case-insensitive). |
| 6 | Trivial | `[SIMPLE]` `[DOC]` | `_ARCHIVE_DIR_NAME = "archive"` is defined but never referenced. Dead code. Comment-analyzer additionally notes the module docstring claims archive files are "intentionally left alone" without describing the implicit `is_file()` skip mechanism. | `paths.py:25` | Delete the constant. (The archive exclusion happens implicitly via the non-recursive `iterdir()`.) Optionally add an inline comment at the `is_file()` guard explaining the skip. |
| 7 | Trivial | *(preflight)* | Ruff `I001`: import block not sorted in `paths.py`. Auto-fixable. | `paths.py:18` | `ruff check --fix pennyfarthing-dist/src/pf/session/paths.py`. |
| 8 | Trivial | `[SIMPLE]` | sm-setup.md middle paragraph ("If the `.session/` directory does not exist yet, create it first.") is largely redundant — the `Write` tool auto-creates parents. Not a bug; keeping the line as a belt-and-braces hint for haiku subagents is defensible, but reviewer's preference is to delete it to keep the prompt focused. | `agents/sm-setup.md:157` | Optional removal. Will not block on this. |
| 9 | Minor | `[DOC]` | Docstring on `migrate_legacy_sessions` claims "Idempotent and non-destructive" without qualification; under Finding 1's UnicodeDecodeError path, both claims fail. Also no docstring text describes the contract that `result['errors']` being non-empty means partial completion. | `paths.py:67-83` (docstring) | After fixing Finding 1, update the docstring to either say "Idempotent and non-destructive on a per-file basis; errors are collected in `result['errors']`" or explicitly call out the post-fix exception coverage. Document the partial-completion semantics of non-empty `errors`. |
| 10 | Minor | `[DOC]` | Inline comment at `:96-97` says "Compare content byte-for-byte using utf-8" but the actual comparison (`legacy_content == canonical_content`) is decoded-string equality after both are `read_text(encoding="utf-8")`-decoded. A file with a BOM or mixed line endings could compare equal/unequal in unintuitive ways. | `paths.py:96-97` | Either correct the comment to "Compare decoded utf-8 content" or switch the implementation to `legacy.read_bytes() == canonical.read_bytes()` if true byte parity is the intent. Reviewer's preference: comment correction (decoded compare is the right semantics for markdown session files). |
| 11 | Minor | `[DOC]` | The 6-line prepend in `sm-setup.md` Step 4 instructs the subagent to "Use the `Write` tool with file path `.session/{STORY_ID}-session.md`" — a **relative** path. Claude Code's `Write` tool requires absolute paths (`The absolute path to the file to write (must be absolute, not relative)`). A Haiku-class subagent following the instruction literally will either error or — depending on its CWD — silently write to the wrong absolute location. This may, ironically, be the root-cause class of the bug 153-1 is fixing. | `agents/sm-setup.md:155-159` | Reword to direct the subagent to resolve project root first and pass an absolute path: e.g., *"Use the `Write` tool with file path `<project_root>/.session/{STORY_ID}-session.md` (use an absolute path — resolve the project root from the session context or by walking up looking for `.pennyfarthing/`)."* Verify via test that the prepend's instruction is unambiguous to a Haiku subagent. |
| 12 | Minor | `[TYPE]` `[RULE]` | Return type of `migrate_legacy_sessions` is bare `dict` in the signature while the local at `:84` carries the more precise `dict[str, list]`. Worse, the contents are heterogeneous: `migrated` holds `Path` objects; `skipped` and `errors` hold `str`. A `TypedDict` makes the contract explicit and lets mypy catch a future regression that appends a string to `migrated` (or a Path to `errors`). Reviewer-type-design noted that `pf/session/append_only.py`'s plain-dict convention does NOT neutralize this — its dict is homogeneous-str. Rule-checker also flags this against Rule #3 (complete annotations at boundaries). | `paths.py:67, 84` | Introduce a `TypedDict` (e.g., `class MigrationResult(TypedDict): migrated: list[Path]; skipped: list[str]; errors: list[str]`) and use it as the return annotation. |
| 13 | Trivial | `[RULE]` | `pf.session.paths` is a new public module exporting three public functions with no `__all__` declaration. Project rule #10 (import hygiene) flags missing `__all__` on public modules as unclear public API. Low severity (callers import by explicit name), but the rule text is unambiguous. Corrects TEA's RED-phase audit which declared rule #10 non-applicable. | `paths.py:1-20` (module head) | Add `__all__ = ["canonical_session_path", "find_legacy_sessions", "migrate_legacy_sessions"]` near the top of the module. |

### Test-Coverage Observations (non-blocking)

- No test for a non-UTF-8 legacy file (the bug in Finding 1 has no failing test). Add as part of the Finding 1 fix.
- No test for the mixed-scenario "one identical legacy + one conflicting legacy in the same call." Architect's verify exercised it manually but it isn't pinned in the unit suite. Add as a follow-up.
- `_AGENT_DOC = Path(__file__).resolve().parents[3] / "agents" / "sm-setup.md"` is depth-fragile. Acceptable today; flagging only.
- No test for `dry_run=True` interacting with the identical-content branch (Finding 4). Add as part of that fix.

### Deviation Audit

- **Architect — AC2 identical-content cleanup**: **ACCEPTED**. The spec text "log + skip, do not destroy" is operatively about preventing data loss. Byte-identical duplication is, by definition, not data loss. Leaving identical orphans in `sprint/` defeats the migrator's hygiene purpose and invites future drift. The aggressive read is sound and the 6-field deviation entry is the right way to document it. Sibling stories 153-2 through 153-6 should treat the migrator as having two semantically distinct collision branches: identical → cleanup, different → skip.
- **Architect — AC3 observational coverage**: **ACCEPTED**. A byte-snapshot of sm-setup.md is wasteful test scaffolding for a 6-line insertion. The two regression-guard tests (`test_agent_doc_file_exists`, `test_agent_doc_does_not_instruct_sprint_path`) suffice — though see Finding 5 about tightening the negative-guard regex.
- **Dev — deferred `pf session migrate-paths` CLI**: **ACCEPTED**. TEA's Gap finding explicitly logged this as discretionary and out of scope.

### Mandatory Review Checklist

- [x] Diff scope verified: 3 files, 574 additions, 0 deletions, matches team-lead's manifest exactly.
- [x] Data flow traced: `story_id` (from sprint YAML, written by sm-setup) → `canonical_session_path` (validation) → `Path` join → `Write` tool target. Boundary validation lives only in the Python helper; the LLM-side template in `sm-setup.md` does not call it. Acceptable today (`story_id` is internal), flagged for hardening if external input ever reaches it (edge-hunter Finding on `agents/sm-setup.md:155`).
- [x] Wiring: helper is library-only; no CLI wired up (TEA's Gap, deferred — fine). Tests import directly via `from pf.session.paths import ...` and import resolves cleanly under the project's `src/` layout. **However, no production caller exists yet** — confirmed by simplifier subagent's search. The migrator is correctness-tested but not yet invoked from anywhere (e.g., `pf prime`, `pf session migrate-paths`). That wiring belongs to a sibling story; not blocking here, but flagging upstream.
- [x] Pattern: matches sibling `pf/session/append_only.py` — module-level pure functions, stdlib-only, no class. Convention respected.
- [x] Error handling: confirmed broken for `UnicodeDecodeError` (Finding 1). All other paths route through the `except OSError` block correctly.
- [x] Security: confirmed null-byte bypass (Finding 2) and symlink-following (Finding 3) live. No `subprocess`, no `eval`, no deserialization, no network. Local-tool threat model.
- [x] Hard inputs probed: empty (rejected), `..` substring (rejected including false-positive `foo..bar`), null byte (BYPASSED — Finding 2), `C:foo` (passed — same allowlist fix kills this), `.hidden` (passed — acceptable), invalid UTF-8 file (CRASHES — Finding 1).
- [x] Subagent findings (6 specialists) incorporated above with confirm/dismiss rationale embedded.

### Subagent Findings Disposition

| Subagent | Findings raised | Confirmed | Dismissed (with reason) |
|----------|-----------------|-----------|--------------------------|
| preflight | 1 lint (I001), 0 test regressions | Finding 7 | — |
| edge-hunter | 14 entries (null byte, NFC/NFD, drive-letter, leading dot, long ids, UnicodeDecodeError, dry_run+mkdir, sprint/ symlink, entry symlink, .session-as-file, two races, ordering, sm-setup.md unguarded) | Findings 1, 2, 3, 8 + null/drive/Unicode-homoglyph rolled into Finding 2 allowlist | NFC/NFD bypass: dismissed for non-blocking; allowlist fix in Finding 2 closes it. Leading dot: low value, dismissed. >255 byte filename: filesystem will raise OSError and that's caught; dismissed as covered. Two-process race: real but out of scope for a non-concurrent dev tool; dismissed (could revisit if migration ever runs in CI). iterdir ordering: no ordering dependency in current logic; dismissed as covered. `.session/` as file: caught by `OSError`; dismissed. sm-setup.md unguarded: deferred — `story_id` is internal today. |
| silent-failure | 4 findings | Findings 1, 4 + result.errors-never-surfaced docstring point folded into Finding 4's docstring guidance | mkdir-inside-loop misleading errors: real but low; dismissed as documentation nit. |
| test-analyzer | 6 findings | Findings 5 + non-UTF-8 test gap + mixed-scenario test gap + dry-run-variant test gap (folded into Findings 1, 4 fix-up) | `parents[3]` brittleness: dismissed as flagged-only. |
| security | 6 findings | Findings 2, 3 (null byte + Unicode + drive-letter all addressed by Finding 2 allowlist fix; symlink by Finding 3) | TOCTOU concerns: real but out-of-scope for a dev tool; dismissed. Info leakage in error strings: local-only context; dismissed. |
| simplifier | 4 findings | Findings 6, 8 + list comprehension suggestion (folded into "nice to have" — not blocking) | `rename()` over `read+write+unlink`: ties to Finding 3's atomicity suggestion — non-blocking. |

### Reviewer (re-review)

**Round:** 2  |  **HEAD:** `c6aa6c471 fix(153-1): address round-1 review fix batch (13 items)`  |  **Verdict:** **APPROVED**

All 13 round-1 items closed. All four of my original live repros now produce the correct outcome against the new code; six dedicated regression tests pin them down. 35/35 story tests pass at HEAD; Igor reported 0 new broader-suite regressions.

#### Round-1 disposition check

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 1 | `UnicodeDecodeError` escape | **Closed** | Migration switched to byte-IO (`read_bytes`/`write_bytes` at `paths.py:157,173`). The encoding-error class is no longer reachable on the hot path; `except (OSError, UnicodeDecodeError)` at `:176` is belt-and-braces with an inline comment explaining the keep. Live repro re-run: bad file routed to `skipped` (content differs from canonical), good sibling 200-1 still migrates cleanly. New test `test_non_utf8_file_does_not_abort_migration` covers it. |
| 2 | Null byte / allowlist | **Closed** | `_STORY_ID_RE = re.compile(r"^[A-Za-z0-9_-]+$")` at `:39`. Three regression tests added (null byte, `C:foo`, Cyrillic homoglyph). Live re-run confirms all five vectors from round-1 (`abc\x00xyz`, `C:foo`, `.hidden`, `foo..bar`, `аbc`) are rejected. |
| 3 | Symlink skip | **Closed** | `is_symlink()` short-circuit before `is_file()` at `paths.py:100`. Test `test_skips_symlinks_in_sprint_dir` added. Live re-run: symlink not picked up by `find_legacy_sessions`, migration result empty, target file untouched. |
| 4 | Dry-run identical-content misreport | **Closed** | New `cleaned: list[Path]` field on the `MigrationResult` TypedDict (Architect-ratified). Identical-content cleanups route to `cleaned`, not `migrated`. Live re-run: `migrated=[], cleaned=[<legacy>], skipped=[], errors=[]`. New test `test_dry_run_identical_content_not_reported_as_migrated` covers it. |
| 5 | Negative-instruction regex too narrow | **Closed** | Two new patterns in the negative-guard test: directive-verb + session + sprint/ on one line (case-insensitive); direct-path mention `sprint/(?!archive/)<X>-session.md`. Negative-guard test still passes — no false-positive against legitimate sm-setup.md text. |
| 6 | `_ARCHIVE_DIR_NAME` dead | **Closed** | Removed. |
| 7 | Ruff I001 | **Closed** | Import block sorted. |
| 8 | Redundant mkdir paragraph | **Closed** | Collapsed into the Write-tool paragraph with explicit ".session/ created by Write tool" phrasing. |
| 9 | Lying docstring | **Closed** | `migrate_legacy_sessions` docstring at `:131-135` documents partial-completion semantics explicitly. `MigrationResult` docstring at `:52-54` echoes the same. |
| 10 | "byte-for-byte" comment | **Closed** | Implementation now actually byte-compares; the comment is honest. |
| 11 | sm-setup.md relative path | **Closed** | Step 4 now reads `{REPO_ROOT}/.session/{STORY_ID}-session.md` with explicit prose: *"`{REPO_ROOT}` is the project root (the directory containing `.pennyfarthing/`). The `Write` tool requires an absolute path; resolve `{REPO_ROOT}` from your activation context, then pass the joined path verbatim."* Unambiguous to a Haiku-class subagent. Template-render-layer absence acknowledged as separate story. |
| 12 | TypedDict | **Closed** | `class MigrationResult(TypedDict)` at `:42` with four typed fields. Return annotation on `migrate_legacy_sessions` updated. mypy would now catch a Path-into-`skipped` regression. |
| 13 | `__all__` | **Closed** | Four exports declared at `:24-29`. |

#### Worth-scrutinizing items from team-lead's brief

- **Byte-IO and line-endings / BOM:** No behavior regression. `read_text(encoding='utf-8')` preserves both CRLF and a stray BOM (`utf-8` doesn't strip BOM — that would be `utf-8-sig`). Byte-IO preserves the same bytes. Both old (string-equality) and new (bytes-equality) would classify a BOM-prefixed vs un-BOM'd file as different — same call. Net change is a **gain in tolerance** (non-UTF-8 files no longer trip a decoder), not a behavioral regression.
- **`cleaned` field contract crispness:** Yes. `MigrationResult` docstring distinguishes all four outcomes (migrated / cleaned / skipped / errors) in one paragraph; `migrate_legacy_sessions` repeats the contract under "Per-file outcomes." Caller code that previously did `len(result['migrated'])` to total hygiene work would now undercount — but there are no production callers (round-1 Delivery Finding), so the schema-change blast radius is zero.
- **`{REPO_ROOT}` resolution unambiguity:** Acceptable. The prose names what to resolve, where to get it (activation context), what marker identifies it (`.pennyfarthing/`), and why it matters (Write tool requires absolute). I'd prefer a future template-render layer for safety but that's explicitly out of scope.
- **Round-1 latents re-checked:**
  - `legacy.name` bypass of validator on the migration path — **still latent, still non-blocking**. Defenses upstream are stronger now (symlink skip + allowlist), so a name slipping through `find_legacy_sessions` would have to be a regular file whose stem violates the allowlist. The resulting `canonical = canonical_dir / legacy.name` would still produce a path under `.session/` (no traversal escape), just with an oddly-named target. Acceptable.
  - mkdir-in-loop misleading per-file errors — **still latent, still non-blocking**.
- **New latent observation (not blocking, future-proofing note only):** `canonical.exists()` at `:153` follows symlinks. If `.session/<story>-session.md` is itself a symlink (atypical — `.session/` is created by the migrator under normal flow), the byte-compare reads through the link and `write_bytes` would write through. Worth a note for a future story that hardens `.session/` ingestion. Inert today.

#### Trivial test-coverage gap (non-blocking, not for re-loop)

`test_safe_to_delete_legacy_when_canonical_identical` asserts the legacy is removed and canonical preserved but does NOT verify the new `cleaned` field is populated in the non-dry-run case. The new `test_dry_run_identical_content_not_reported_as_migrated` covers the dry-run path. A future tightening could add a one-line `assert legacy in result['cleaned']` to the non-dry-run test. Not worth a third iteration.

#### Decision

**APPROVE.** Full approve, not approve-with-conditions. The remaining items (single-line test-coverage tightening on `cleaned`, the three round-1 latents that were never blocking) do not warrant a third loop. Excellence-over-optimization holds: the fix batch closed every substantive issue from round 1 and the changes only made the module stronger.

PR open against `develop` next, then exit protocol for SM (finish phase).

— Granny

### Handoff (round 2)

→ SM (Captain Carrot) for finish phase. PR open against `develop`. Architect deviations remain accepted. Round-1 latents documented but non-blocking. Recommend SM run finish ceremony once PR clears any external review.

---

### Handoff (round 1 — superseded, retained for traceability)

→ Dev (Ponder Stibbons) for green-phase rework. Recommended fix batch (now **13 items** after the second-wave subagent fan-out surfaced 5 more):

**Majors:**
1. Add `UnicodeDecodeError` to the catch in `migrate_legacy_sessions` (Finding 1) + regression test that plants a non-UTF-8 legacy file alongside a valid one.
2. Add `\x00` to the validator — preferably an allowlist `^[A-Za-z0-9_-]+$` (Finding 2) + regression tests for null byte and Windows `C:foo`.

**Minors:**
3. Skip symlinks in `find_legacy_sessions` (Finding 3) + regression test.
4. Fix dry-run identical-content reporting (Finding 4) + test.
5. Broaden the negative-instruction guard regex (Finding 5).
9. Update docstring on `migrate_legacy_sessions` to match post-fix exception coverage and document partial-completion semantics of `result['errors']` (Finding 9).
10. Correct or replace the "byte-for-byte" inline comment at `paths.py:96-97` (Finding 10).
11. Reword sm-setup.md Step 4 prepend to use an absolute path resolution instead of a bare relative path (Finding 11) — **this may be the actual root-cause class of the original bug, treat with care**.
12. Introduce `MigrationResult` TypedDict for `migrate_legacy_sessions` return type (Finding 12).

**Trivials:**
6. Delete `_ARCHIVE_DIR_NAME` (Finding 6).
7. Ruff `--fix` (Finding 7).
8. *(Optional)* Remove redundant `mkdir` instruction in `sm-setup.md` (Finding 8).
13. Add `__all__` declaration to `pf/session/paths.py` (Finding 13).

After fixes land, TEA re-verifies and Granny re-reviews. The Architect deviations stay accepted; nothing to revisit there.

— Granny

## Subagent Results

**All received: Yes** — all 9 specialists ran against the diff in two parallel waves (6 in the first batch during initial review, 3 in a follow-up batch after the gate flagged the audit trail as incomplete). Findings and dispositions below.

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | completed | 29/29 story tests pass; no NEW regressions in broader suite (4052 passed, 374 deselected as pre-existing); 1 ruff `I001` import-sort on `paths.py:18` (auto-fixable); mypy not configured; working tree clean. | Confirmed all results. Lint finding → **Trivial #7** in assessment. Tests-green is necessary but not sufficient — adversarial pass still found 2 Majors the suite did not. |
| 2 | reviewer-edge-hunter | Yes | completed | 14 entries: null byte bypass, NFC/NFD normalization, Windows drive-letter `C:foo`, leading dot, oversized story_id, `UnicodeDecodeError` escape, dry-run+mkdir asymmetry, sprint/ as symlink, entry symlink-following, `.session/` as file, two race conditions, iterdir ordering, sm-setup.md template unguarded. | **Confirmed → Findings 1, 2, 3, 8** (with null-byte/drive-letter/Unicode-homoglyph rolled into Finding 2's allowlist recommendation). **Dismissed**: NFC/NFD (allowlist closes it), leading dot (low-value), >255 byte filenames (caught by OSError), two-process race (out of scope for non-CI dev tool), iterdir ordering (no dependency in current logic), `.session/` as file (covered by OSError catch), sm-setup.md template unguarded (deferred — story_id is internal today). |
| 3 | reviewer-silent-failure-hunter | Yes | completed | 4 findings: `UnicodeDecodeError` not covered by `except OSError` (HIGH); `result['errors']` never surfaced to callers contract-wise; `dry_run` identical-content branch misreports under `migrated`; mkdir-in-loop produces misleading per-file error messages. | **Confirmed → Findings 1, 4**. The errors-never-surfaced concern folded into Finding 4's docstring guidance. **Dismissed**: mkdir-loop misleading errors — real but documentation-nit-level. |
| 4 | reviewer-test-analyzer | Yes | completed | 6 findings: no test for null byte in `story_id`; negative-instruction regex too narrow (paraphrases slip through); dry-run identical-content branch untested; no test for non-UTF-8 legacy file; `_AGENT_DOC = parents[3]` depth-fragile; no test for mixed identical+conflicting in one call. | **Confirmed → Finding 5** + Test-Coverage Observations section (folded into Findings 1, 4 fix-up). **Dismissed**: `parents[3]` brittleness — flagged-only, acceptable today. |
| 5 | reviewer-comment-analyzer | Yes | completed | 5 findings: docstring claim "Idempotent and non-destructive" lies under the UnicodeDecodeError path; `_ARCHIVE_DIR_NAME` is dead code without explanatory comment; module docstring's "archive files intentionally left alone" doesn't describe the implicit `is_file()` skip mechanism; inline comment "byte-for-byte using utf-8" is misleading — actual compare is decoded-string equality; sm-setup.md prepend instructs `Write` tool with a relative path while the tool requires absolute. | **Confirmed → Findings 1 (reinforced), 6 (reinforced), 9 (NEW), 10 (NEW), 11 (NEW)**. The lying-docstring observation strengthens Finding 1 — fix must update the docstring as well as the catch. The relative-path concern is real and material (NEW Finding 11). |
| 6 | reviewer-type-design | Yes | completed | 3 findings: `dict[str, list]` annotation is heterogeneous (Paths in `migrated`, strings in `skipped`/`errors`) — `TypedDict` would catch a future regression mypy can't see today (Medium); implicit invariant `legacy.parent == sprint_dir` is enforced only documentarily (Low); concurs `append_only.py`'s plain-dict convention does NOT neutralize the TypedDict suggestion because that one is homogeneous-str. | **Confirmed → Finding 12 (NEW)**. Overrides my initial inline-skip judgment ("matches sibling convention") because the convention argument doesn't address the heterogeneity. **Dismissed**: implicit-invariant assertion — useful documentation but not blocking. |
| 7 | reviewer-security | Yes | completed | 6 findings: null byte path-traversal (CWE-22/CWE-158); Unicode normalization gap; Windows drive-letter; reuse of `legacy.name` bypasses validator on the migration path; symlink-following content replication (CWE-59); info leakage in error strings. | **Confirmed → Findings 2, 3** (null/Unicode/drive-letter all closed by Finding 2's allowlist; symlink by Finding 3). **Dismissed**: legacy.name-bypass-validator — `endswith('-session.md')` filter limits exposure today, real risk only if `find_legacy_sessions` ever relaxes (noted as latent); info leakage — local-only dev tool, dismissed. |
| 8 | reviewer-simplifier | Yes | completed | 4 findings: `_ARCHIVE_DIR_NAME` is dead code; `find_legacy_sessions` could be a list comprehension; `rename()` would be atomic over `read+write+unlink`; sm-setup.md middle paragraph (mkdir reminder) redundant with the Write tool's auto-parent-creation. | **Confirmed → Findings 6, 8** + atomicity suggestion folded into Finding 3's recommendation. **Dismissed**: list-comprehension stylistic — non-blocking nit. |
| 9 | reviewer-rule-checker | Yes | completed | 19 rules audited (13 Python lang-review + 6 project-level), 47 total instances, **3 violations**: Rule #1 `except OSError` too narrow for `UnicodeDecodeError` (high, confirms Finding 1); Rule #3 bare `dict` return annotation at `:67` vs precise `dict[str, list]` at `:84` (low — folds into Finding 12); Rule #10 missing `__all__` on new public module (low, NEW). Also explicitly **corrects TEA's RED-phase audit**: TEA called rule #1 non-applicable; rule-checker disagrees and flags it as violated. | **Confirmed → Findings 1 (reinforced w/ rule citation), 12 (reinforced — bare `dict` folds into TypedDict), 13 (NEW — missing `__all__`)**. Rule #15 (orchestrator's "return result objects, don't throw") flagged but **dismissed** — that rule is in the orchestrator's CLAUDE.md targeting TS/JS CLI scripts, not Python library code, and Python idiom is to raise at boundary validation (`canonical_session_path` raising `ValueError` is correct). |

**Skip rationale (legacy — superseded).** Earlier this section recorded 3 specialists as skipped-with-rationale; the gate (strict mode) required actual results regardless of surface size. All 3 (comment-analyzer, type-design, rule-checker) have now been run and reported. Their findings yielded **5 NEW findings** (numbered 9–13 in the updated table below) that my inline judgment had dismissed or missed — particularly the `sm-setup.md` relative-path concern (Finding 11) and the `TypedDict` need (Finding 12, where convention-argument did not in fact neutralize the heterogeneity risk). The strict-mode gate earned its keep on this pass.

## Delivery Findings

### Reviewer (code review)
- **Gap** (non-blocking): `pf.session.paths.migrate_legacy_sessions` has no production caller yet. The bug surfaced in downstream projects (oq-1, oq-2) but nothing in the framework currently invokes this helper to fix those projects. Affects: a future story (likely 153-3's deferred `pf session migrate-paths` CLI surface, or a hook in `pf prime`). The library is correct (after this round of fixes) but inert. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `pf/prime/session.py:27` still open-codes `project_root / ".session" / "agents"` — same anti-pattern this story is fixing. A follow-up could extend `pf.session.paths` with `agent_session_dir(root) -> Path` and migrate that caller. Architect already flagged this as out-of-scope upstream finding; reviewer concurs. Affects `pf/prime/session.py`. *Found by Reviewer during code review (consistent with Architect's earlier observation).*
- **Question** (non-blocking): Should the validator on `canonical_session_path` be an explicit allowlist (`^[A-Za-z0-9_\-]+$`) rather than a blocklist? The current blocklist has already missed two characters (null byte, colon); allowlist is cheaper to audit and closes future bypasses in one place. Affects `pf.session.paths.canonical_session_path`. *Found by Reviewer during code review.*

## Tea Verify (round 2)

**Phase:** approved (round 2 — post round-1 review rework)
**Status:** PASS — all 5 verify items green; ready for Reviewer (Granny) for round-2 review.
**HEAD:** `c6aa6c471 fix(153-1): address round-1 review fix batch (13 items)`

### Verify Checklist (round 2)

| # | Item | Result | Detail |
|---|------|--------|--------|
| 1 | `test_153_1_session_path_fix.py` — 35/35 at HEAD | **PASS** | `35 passed in 0.59s`. +6 new tests since round-1 verify: null byte, drive letter, Unicode homoglyph, symlink skip, non-UTF-8 file mid-migration, dry-run identical-content `cleaned` reporting. |
| 2 | Broader `pf` suite — no NEW regressions | **PASS** | `4436 passed; 21 failed + 4 errored`. Identical failure set to round-1 verify (test_141_20, test_143_9, test_143_10, test_143_12, test_148_23, test_peloton, test_pypi). +6 new test passes vs round-1 (4436−4430=6) — matches the new regression tests added in the rework. |
| 3 | Granny's repros covered by new regression tests | **PASS** | Each of the four repros has a dedicated test AND was re-validated against the real impl: <br>• `b'\xff\xfe\xfd'` non-UTF-8 → `test_non_utf8_file_does_not_abort_migration` + scenario shows migration completes with no `errors[]` entry and byte content preserved. <br>• `abc\x00xyz` null byte → `test_rejects_null_byte_in_story_id` + scenario rejects with `ValueError: ...[A-Za-z0-9_-]+`. <br>• `C:foo` drive letter → `test_rejects_windows_drive_letter_in_story_id` + scenario rejects. <br>• Cyrillic homoglyph `аbc` → `test_rejects_unicode_homoglyph_story_id` + scenario rejects. |
| 4 | `MigrationResult.cleaned` populated in real-run AND dry-run | **PASS** | Real-run scenario: 1 new + 1 identical-dup + 1 differing → `migrated=[new-1]`, `cleaned=[dup-1]`, `skipped=[diff-1: ...]`, `errors=[]`. Filesystem matches: legacy_new moved, legacy_dup unlinked, legacy_diff and both canonicals preserved. Dry-run scenario: same 3-input setup, `mtime_ns` snapshotted before/after — bit-for-bit unchanged across 5 files; plan still reports `migrated=[new-1]` and `cleaned=[dup-1]` and `skipped=[diff-1]` correctly. |
| 5 | Broadened negative-instruction guard passes | **PASS** | `test_agent_doc_does_not_instruct_sprint_path` PASSED on current `sm-setup.md`. The expanded regex now catches paraphrases (write/save/create/place/put/store/emit/output/persist) + direct path mentions outside `archive/`. Step 4 directive `{REPO_ROOT}/.session/{STORY_ID}-session.md` satisfies the substring-match in `test_write_session_file_step_mentions_canonical_path`. |
| dev | reviewer | approval | PASSED | 2026-05-20T17:40:42Z |
| reviewer | sm | complete | PASSED | 2026-05-20T17:40:42Z |

### Integration Evidence (round 2 — real impl, not stubs)

```
=== new-schema real run ===
  migrated: ['<tmp>/sprint/new-1-session.md']
  cleaned:  ['<tmp>/sprint/dup-1-session.md']
  skipped:  ['<tmp>/sprint/diff-1-session.md: canonical <tmp>/.session/diff-1-session.md exists with different content']
  errors:   []
  PASS

=== new-schema dry-run ===
  plan migrated: ['<tmp>/sprint/new-1-session.md']
  plan cleaned:  ['<tmp>/sprint/dup-1-session.md']
  plan skipped:  ['<tmp>/sprint/diff-1-session.md: canonical <tmp>/.session/diff-1-session.md exists with different content']
  FS unchanged:  5/5 files stable (existence + mtime_ns)
  PASS

=== Granny's repros ===
  non-UTF-8 file migrated cleanly: PASS
  null-byte story_id rejected: PASS (story_id must match [A-Za-z0-9_-]+; got 'abc\x00xyz')
  drive-letter story_id rejected: PASS (story_id must match [A-Za-z0-9_-]+; got 'C:foo')
  cyrillic-homoglyph rejected: PASS (story_id must match [A-Za-z0-9_-]+; got 'аbc')

=== symlink in sprint/ (bonus, CWE-59) ===
  symlink skipped from find_legacy_sessions list: PASS
  symlink not migrated/cleaned: PASS
  symlink target file SECRET\n untouched: PASS
```

### Quality Observations on the Rework (`c6aa6c471`)

- **Byte-IO** (`read_bytes`/`write_bytes`) cleanly kills the `UnicodeDecodeError` class — migration no longer needs to care about encoding at all. The `try/except (OSError, UnicodeDecodeError)` is now defensive-in-depth rather than load-bearing.
- **Allowlist regex** `^[A-Za-z0-9_-]+$` is right-sized — closes null byte, drive letter, homoglyph, NFC/NFD, and any future "what character did we forget" bypass in one place. The error message echoes `story_id!r` so debugging is straightforward.
- **`MigrationResult` TypedDict** with the `cleaned` channel cleanly separates "relocation" from "duplicate removal" — downstream callers (the deferred `pf session migrate-paths` CLI from 153-3) can now surface both counts naturally. The schema is structurally sound and the field semantics match my round-1 mental model.
- **Symlink skip** is correctly ordered *before* `is_file()` (which would follow the link). Comment cites CWE-59 explicitly.
- **`__all__`** matches the four public names. No bleed.
- **sm-setup.md `{REPO_ROOT}` prepend** is the right call — addresses the relative-path ambiguity Granny flagged. Substring match in my static test still succeeds because `{REPO_ROOT}/.session/{STORY_ID}-session.md` contains `.session/{STORY_ID}-session.md`. Belt + braces.

### Branch Sandboxing Note (informational, NOT blocking)

The branch flipped to `feature/test` again during the full `pf` test run — `test_143_9_tdd_cycle_e2e.py` continues to perform live `git checkout` operations against the repo it's running in, not a sandboxed copy. I switched back, verified working tree integrity (`c6aa6c471` clean), and re-ran the round-2 integration scenarios from the correct branch. **All test results above are confirmed-clean.** This is the same flake noted in round-1 verify; team-lead is aware. Worth a follow-up ticket but out of scope for 153-1.

### Self-Review Before Handoff

- [x] All 5 verify items PASS
- [x] No NEW regressions in broader suite (identical failure set to round-1)
- [x] Each of Granny's 4 round-1 repros has a dedicated regression test AND was re-validated against the real impl
- [x] `MigrationResult.cleaned` populated correctly in real-run and dry-run; the four-field schema is consistent across both modes
- [x] Broadened negative-instruction guard passes against current `sm-setup.md`
- [x] No code changes made during verify — TEA does not edit source in this phase

**Handoff:** → Reviewer (Granny Weatherwax) for round-2 review.

## Sm Assessment

**Story:** sm-setup writes session files to `.session/` (not `sprint/`); migrate legacy session files.

**Context:** P0 framework reliability bug surfaced in downstream projects (oq-1, oq-2). The `sm-setup` subagent has been writing session files to the wrong path. Two parts:
1. Fix sm-setup so new session files land in `.session/` (the canonical path used by `pf prime`, gates, and runtime scripts).
2. Migrate any legacy session files written to the wrong location so existing in-flight stories don't break on next prime.

**Repo:** `pennyfarthing/` (inlined framework source). Base branch: `develop`. Feature branch: `feat/153-1-sm-setup-session-path-fix`.

**Workflow:** tdd (2 points — at boundary, but tdd was selected because this touches behavior with multiple call sites). Phases: setup → red → green → review → finish.

**Mode:** Peloton team `peloton-153-1` is active. tea/dev/architect/reviewer teammates are spawned and persistent across phases.

**Acceptance:**
- sm-setup writes session files to `.session/{story-id}-session.md` (verified by test).
- Migration helper handles legacy files in the wrong location (idempotent, non-destructive).
- Existing tests pass; new tests cover both new-write path and migration.

**Handoff:** → TEA (Igor) for red phase.