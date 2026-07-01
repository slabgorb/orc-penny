---
story_id: "159-12"
jira_key: ""
epic: "159"
workflow: "tdd"
---
# Story 159-12: Advisory never-edit-zone PreToolUse hook (ADR-0041 Phase 1)

## Story Details
- **ID:** 159-12
- **Jira Key:** (none — local kanban)
- **Workflow:** tdd
- **Stack Parent:** none
- **Epic:** 159 (Smaller standalone fixes)

## Acceptance Criteria

1. **PreToolUse hook wired:** New `advisory_never_edit_zone` handler exists alongside `pre_edit_check.py`, receives same dispatch signal, returns `additionalContext` (never blocks).

2. **Repository never-edit zones read from repos.yaml:** The hook queries the repos-config loader (existing code path) for the active repo's `never_edit_zones` field; no parallel config file. Fall-soft on missing field (repo has no zones → no context).

3. **Path matching is gitignore-style globs:** The edit target is matched against each never-edit zone pattern using **gitignore-style semantics** — a slashless pattern (`*.tsbuildinfo`) matches at any depth; `**` spans zero-or-more segments; a subtree pattern (`.pennyfarthing/agents/**`) matches the whole subtree. Pick/implement a matcher that honors these semantics — note `pathlib.Path.match()` does NOT (it lacks gitignore `**`/basename-at-any-depth), so it is not sufficient on its own. Check for an existing matcher in the codebase before writing one; see live-rules' matcher (referenced in ADR-0041) for the target behavior. Fail-soft: a malformed pattern → skip that pattern and continue, never raise.

4. **Context injection is advisory only — NO permission decision:** Hook appends a short reminder (< 200 characters) to `additionalContext` and returns **no permission field at all** — not `allow`, not `deny`. Emitting `permission: allow` is itself a decision: it can bypass the normal edit-approval flow and override a concurrent `deny` from `pre_edit_check`/`branch_protection`, so it is FORBIDDEN. Enforcement stays entirely with the existing block hooks. Example reminder: "⚠️ This is a .pennyfarthing/ symlink — edit the source at pennyfarthing/pennyfarthing-dist/ instead."

5. **Dispatch integration:** Hook is integrated into `hooks/dispatch.py` and exposed via `hooks/cli.py` so pf's hook event loop invokes it without duplicating registration logic.

6. **No Node, no every-prompt UserPromptSubmit:** Advisory context is injected ONLY on PreToolUse (edit-time), not on every prompt. No UserPromptSubmit hook is added (that would fight prime's tiering to MINIMAL). The injection is scoped to the moment of edit.

## Story Description

Implement ADR-0041 Phase 1: a new **advisory** (inform-only) PreToolUse hook that fires the instant Claude is about to edit a path in a repos.yaml never-edit zone, injecting a short reminder pointing at the correct source (e.g. edit pennyfarthing-dist/ source, not the .pennyfarthing/ symlink). Reads never-edit zones from repos.yaml (single source of truth — no restated rule file). Returns additionalContext ONLY, never a permission decision: enforcement stays with pre-edit-check/branch-protection. Steal live-rules' design (gitignore-style glob match, fail-soft). No Node; no every-prompt UserPromptSubmit hammer (that fights prime's deliberate shrink-to-MINIMAL tier — see ADR-0041 Defect 1). Wire into pf.hooks dispatch alongside existing PreToolUse handlers. Touch points: new handler sibling to hooks/pre_edit_check.py, existing repos.yaml loader, hooks/dispatch.py + hooks/cli.py.

## Technical Approach

Reference: **ADR-0041: Live Context Injection Layer** (docs/adr/0041-live-context-injection-layer.md)

**Phase 1 scope (this story):**
- Implement advisory-only PreToolUse hook (no permission block)
- Read never-edit zones from repos.yaml (one source of truth)
- Gitignore-style glob matching with fail-soft behavior
- Wire into existing hooks dispatch system
- Inject context reminder at edit-time only (no UserPromptSubmit)

**Design principles:**
- Fail-soft: malformed glob or missing zone → skip, log warning, allow edit
- Scoped advice: advisory-context only at PreToolUse, never every-prompt re-injection
- Reuse existing infrastructure (repos.yaml loader, hooks dispatch, hooks/cli.py)
- Match Eigenwise live-rules design for glob matching, not Node runtime

**Implementation touch points:**
- New file: `pennyfarthing-dist/src/pf/hooks/advisory_never_edit_zone.py`
- Modified: `pennyfarthing-dist/src/pf/hooks/dispatch.py` (register handler)
- Modified: `pennyfarthing-dist/src/pf/hooks/cli.py` (expose hook)
- No new config files (repos.yaml is the single source of truth)

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-01T11:32:47Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-01T10:29:18.240683Z | 2026-07-01T10:32:19Z | 3m |
| red | 2026-07-01T10:32:19Z | 2026-07-01T10:46:40Z | 14m 21s |
| green | 2026-07-01T10:46:40Z | 2026-07-01T10:58:38Z | 11m 58s |
| review | 2026-07-01T10:58:38Z | 2026-07-01T11:19:52Z | 21m 14s |
| green | 2026-07-01T11:19:52Z | 2026-07-01T11:28:25Z | 8m 33s |
| review | 2026-07-01T11:28:25Z | 2026-07-01T11:32:47Z | 4m 22s |
| finish | 2026-07-01T11:32:47Z | - | - |

## Delivery Findings

### TEA (test design)
- **Improvement** (non-blocking): stdlib `fnmatch` (used by `pre_edit_check.py`) does NOT implement gitignore semantics — it treats `**` as `*` and cannot distinguish slashless-basename-at-any-depth from a `/`-anchored pattern. Affects `pennyfarthing-dist/src/pf/hooks/advisory_never_edit_zone.py` (Dev must implement gitignore-style matching in stdlib, or add `pathspec`; reusing `fnmatch` alone will fail `test_glob_anchored_matches_dist_not_src` and `test_glob_slashless_matches_basename_any_depth`). *Found by TEA during test design.*
- **Question** (non-blocking): zones are per-repo and relative to each repo's `path`; the matcher must relativize the edited path into each repo's space before matching (a `pennyfarthing/…` edit matches pennyfarthing's zones; a root-level edit matches orchestrator's). Encoded in the glob tests. Affects the matcher design in `advisory_never_edit_zone.py`. *Found by TEA during test design.*
- **Improvement** (non-blocking): the enforcement sibling `pre_edit_check` matches only `Edit|Write`, while this advisory hook covers `Edit|Write|MultiEdit` per AC6 — advice and enforcement will fire on different tool sets. Consider widening `pre_edit_check`'s matcher in a follow-up. Affects `pennyfarthing-dist/src/pf/hooks/dispatch.py`. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): `get_project_root()` prefers a `PROJECT_ROOT` env override over `CLAUDE_PROJECT_DIR`; a Claude-Code hook that inspects the *edited* project should honor `CLAUDE_PROJECT_DIR` (as `pre_edit_check` and now this hook do). Other hooks using `get_project_root()` may read the wrong repo when `PROJECT_ROOT` diverges — worth an audit. Affects `pennyfarthing-dist/src/pf/hooks/*`. *Found by Dev during implementation.*
- **Improvement** (non-blocking): the gitignore-style matcher (`_translate`/`_matches`) lives inside `advisory_never_edit_zone.py`. If a second consumer needs true gitignore semantics (e.g. widening `pre_edit_check` beyond stdlib `fnmatch`), extract it to a shared util rather than duplicating. Affects `pennyfarthing-dist/src/pf/hooks/advisory_never_edit_zone.py`. *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking, RECOMMENDED FOLLOW-UP): harden `_translate`/`_matches` against ReDoS — collapse adjacent `**` groups (kills the PoC), and/or cap pattern `**` count + `file_path` depth, or replace the `**`→regex translation with a linear segment-by-segment matcher. Empirically 37 s for 8 chained `**` vs a 50-segment path; runs on the hot path of every edit. Not reachable from committed config, but worth a fast-follow story. Affects `pennyfarthing-dist/src/pf/hooks/advisory_never_edit_zone.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): normalize the relative-`file_path` branch (L144) the same way as the absolute branch (`(project_root / fp).resolve().relative_to(project_root)` under the same `ValueError` guard) for consistency. Affects `pennyfarthing-dist/src/pf/hooks/advisory_never_edit_zone.py`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): no test asserts AC4's "< 200 char" reminder bound; add a length test and optionally truncate very long reminders. Affects `pennyfarthing-dist/src/pf/tests/test_159_12_advisory_never_edit_zone.py` + hook. *Found by Reviewer during code review.*

## Design Deviations

### TEA (test design)
- **AC1 assertion scope: source directory, not fully-rewritten file path**
  - Spec source: context-story-159-12.md, AC-1
  - Spec text: "injects an advisory reminder that names the correct pennyfarthing-dist/ source path"
  - Implementation: AC1 tests assert the source *directory* (`pennyfarthing/pennyfarthing-dist/agents`) appears in `additionalContext`, not the fully-rewritten file path (`…/agents/tea.md`).
  - Rationale: avoids over-specifying the reminder's exact wording; the source directory is the load-bearing part of "correct source." Dev is encouraged to include the full file path — the test permits but does not require it.
  - Severity: trivial
  - Forward impact: none (Reviewer may tighten to full-path if desired)

### Dev (implementation)
- **Project root resolved from `CLAUDE_PROJECT_DIR` directly, not `get_project_root()`**
  - Spec source: TEA Assessment (session), "Designed Interface" step 2 ("Resolve project root from CLAUDE_PROJECT_DIR (via get_project_root)")
  - Spec text: "Resolve project root from `CLAUDE_PROJECT_DIR` (via `get_project_root`)"
  - Implementation: reads `os.environ["CLAUDE_PROJECT_DIR"]` directly (fallback `os.getcwd()`), matching the sibling hook `pre_edit_check.py`, instead of `pf.common.config.get_project_root()`.
  - Rationale: `get_project_root()` checks `PROJECT_ROOT` *before* `CLAUDE_PROJECT_DIR`; `PROJECT_ROOT` is set in this environment (and in `pf` tooling generally), so the hook would read a *different* repo's `repos.yaml` than the project Claude is editing. Honoring `CLAUDE_PROJECT_DIR` is both the correct Claude-Code-hook behavior and what TEA's tests (which set `CLAUDE_PROJECT_DIR`) require. This was the root cause of the first GREEN run's 6 failures.
  - Severity: minor
  - Forward impact: none (aligns with existing hook convention; Phase 2 hooks should follow the same pattern)
- **Rework: lexical `os.path.normpath`, NOT the Reviewer-suggested `.resolve()`, for path normalization**
  - Spec source: Reviewer rework scope (session), item 2 ("normalize the relative branch like the absolute branch: `(project_root / fp).resolve().relative_to(project_root)`")
  - Spec text: "normalize the relative-`file_path` branch (L144) the same way as the absolute branch"
  - Implementation: switched BOTH branches to lexical `os.path.normpath` (no filesystem resolution). Applying `.resolve()` as suggested would follow the `.pennyfarthing/` symlinks and rewrite the edited path to its *source*, missing the never-edit zone entirely — verified empirically. This also fixes a **latent correctness bug in the original absolute branch** (`fp.resolve()`): editing a real `.pennyfarthing/` symlink via an absolute path produced NO advisory. `normpath` collapses `.`/`..` (satisfying the reviewer's intent + CWE-59) while preserving the symlink path for zone matching.
  - Rationale: the reviewer's literal fix would have worsened the headline symlink case; lexical normalization is the correct way to achieve the same intent. New regression test `test_absolute_symlink_path_matches_zone` (real filesystem symlink) locks it in.
  - Severity: minor (fixes a latent bug; no behavior change for the passing tests)
  - Forward impact: none — improves correctness for the primary use case.

### Reviewer (audit)
- **TEA — AC1 assertion scope (source dir vs full path)** → ✓ ACCEPTED by Reviewer: sound, and Dev resolved it in the stricter direction (the reminder includes the full rewritten source *file* path, L109–112). No drift remains.
- **Dev — `CLAUDE_PROJECT_DIR` directly vs `get_project_root()`** → ✓ ACCEPTED by Reviewer: correct and necessary. `get_project_root()` prefers a `PROJECT_ROOT` override that would make the hook read a different repo's zones (the root cause of the first GREEN run's failures). Matches the `pre_edit_check` convention. Verified the comment at L133–135 documents this.
- **Dev (rework) — lexical `os.path.normpath` instead of the Reviewer-suggested `.resolve()`** → ✓ ACCEPTED by Reviewer: my Round-1 suggestion was wrong — `.resolve()` follows the `.pennyfarthing/` symlinks and misses the zone. Dev's lexical-normalization choice is correct, satisfies the `..`-normalization intent, and fixes a latent bug I had not diagnosed. Verified empirically + by `test_absolute_symlink_path_matches_zone`.
- No undocumented deviations found: the code matches the ACs and the TEA-designed interface.

**Setup complete — routing to TEA (RED phase).**

- **Source of spec:** `docs/adr/0041-live-context-injection-layer.md` (orchestrator). This story implements **Phase 1 only** — the surgical, inform-only `PreToolUse` advisory hook.
- **ACs:** 6 criteria transcribed from the ADR's Phase-1 test contract (fail-soft, no-permission-decision, repos.yaml as single source of truth, dispatch registration). TEA should turn these directly into RED tests.
- **Scope guard (do NOT implement):** No `UserPromptSubmit` every-prompt refresh (Phase 2). Per ADR-0041 Defect 1, that fights prime's deliberate shrink-to-MINIMAL tier and is explicitly out of scope. No Node. No auto-generated codebase docs. No parallel rule file — read never-edit zones from `repos.yaml`.
- **Enforcement boundary:** This hook is advisory. It must return `additionalContext` only and NEVER a permission verdict — `pre_edit_check`/`branch_protection` keep owning blocks. This is the single most important behavioral invariant to test.
- **Repo/branch:** `pennyfarthing` · `feat/159-12` off `develop` (gitflow). Implementation lives in `pennyfarthing-dist/src/pf/hooks/` + `hooks/dispatch.py`/`hooks/cli.py`.
- **Reuse pointers for TEA/Dev:** existing `repos.yaml` loader; sibling handler `hooks/pre_edit_check.py`; a gitignore-style glob matcher will be needed (zones are patterns like `.pennyfarthing/agents/**`) — check for an existing matcher before writing one.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED confirmed (via testing-runner, run 159-12-tea-red) — **20 tests: 18 failing on missing module, 2 regression guards green by design.** Branch verified `feat/159-12`.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_159_12_advisory_never_edit_zone.py` — pins the designed `pf.hooks.advisory_never_edit_zone` interface + dispatch wiring. Tmp-dir repos.yaml fixtures only; never touches the live topology.

### Designed Interface (for Dev — GREEN target)

`pf.hooks.advisory_never_edit_zone.main() -> None`:
1. Read PreToolUse payload from stdin: `{"tool_name": "...", "tool_input": {"file_path": "<path>"}}`.
2. Resolve project root from `CLAUDE_PROJECT_DIR` (via `get_project_root`).
3. Load zones with the **existing** loader `pf.git.repos.load_repos_config()` (single source of truth — do NOT re-parse repos.yaml).
4. Match the edited path (relativized per-repo) against each repo's `never_edit` with **gitignore semantics** (`fnmatch` alone is insufficient — see Delivery Findings).
5. On match → stdout `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "<reminder>"}}`, where the reminder names the correct source via the repo `symlinks` map. **No `permissionDecision`, ever. `sys.exit(0)` on every path.**
6. No match / missing-or-malformed repos.yaml / bad stdin → no output, exit 0.
7. Register in `dispatch.py` `DISPATCH_REGISTRY["PreToolUse"]` as `("advisory-never-edit-zone", "Edit|Write|MultiEdit", "pf.hooks.advisory_never_edit_zone")` and expose via `hooks/cli.py`. Do **not** add any `UserPromptSubmit` entry.

**The two green guard tests** (`test_existing_pretooluse_handlers_intact`, `test_no_userpromptsubmit_handler_added`) pass now and must STAY green — they catch Dev disturbing existing handlers or adding the every-prompt hammer.

### Rule Coverage (lang-review/python.md)

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 no silent swallowing / fail-soft | `test_missing_repos_yaml_failsoft`, `test_malformed_repos_yaml_failsoft`, `test_malformed_glob_pattern_is_skipped_not_fatal` | failing (RED) |
| #5 path handling (abs→rel, CWE-59) | `test_absolute_path_under_root_is_matched` | failing (RED) |
| #6 test quality (no vacuous asserts) | self-check — every test asserts a specific value/None | pass (self) |
| #8/#9 safe deserialization / Python-only | `test_reuses_existing_repos_loader` (reuses safe loader, no subprocess) | failing (RED) |
| #11 boundary input validation | `test_non_json_stdin_failsoft`, `test_empty_file_path_no_output`, `test_missing_tool_input_no_output` | failing (RED) |

**Rules checked:** 5 of the applicable lang-review rules have test coverage.
**Self-check:** 0 vacuous tests (every assertion checks a concrete value, presence/absence of a HookResponse, an exit code, or a specific substring).

**Handoff:** To Dev (Baldrick) for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/hooks/advisory_never_edit_zone.py` (new) — advisory PreToolUse hook: reads stdin, resolves root from `CLAUDE_PROJECT_DIR`, loads zones via the existing `load_repos_config`, gitignore-matches per-repo, and on a hit emits `additionalContext` (rewriting symlinked paths to their `pennyfarthing-dist/` source). No `permissionDecision`; `exit 0` on every path; fail-soft throughout.
- `pennyfarthing-dist/src/pf/hooks/dispatch.py` — registered `("advisory-never-edit-zone", "Edit|Write|MultiEdit", …)` as the 2nd PreToolUse handler.
- `pennyfarthing-dist/src/pf/hooks/cli.py` — exposed `pf hooks advisory-never-edit-zone`.

**Tests:** 22/22 passing (GREEN, run 159-12-dev-green-2). Regression run (159-12-dev-regression): 57/57 across the advisory + branch-protection + init-frontmatter suites — no regressions from the shared-file edits. Registry smoke-check confirms the handler is in position 2.

**Implementation notes:**
- Wrote a stdlib gitignore-style matcher (`_translate`/`_matches`) per TEA's warning that `fnmatch` is insufficient — no new dependency (`pathspec` avoided).
- One deviation logged: root resolved via `CLAUDE_PROJECT_DIR` directly, not `get_project_root()` (see Design Deviations → Dev). This was the root cause of the first GREEN run's 6 failures.
- AC1 reminder includes the full rewritten source *file* path (e.g. `pennyfarthing/pennyfarthing-dist/agents/tea.md`), exceeding the minimum the test required — resolving TEA's trivial deviation in the stricter direction.

**Branch:** feat/159-12 (pushed)

**Handoff:** To next phase (Reviewer / verify).

### Dev Rework (Round 1) — addressing Reviewer REJECTED

**Status:** GREEN (run 159-12-dev-green-rework) — **27/27 passing** (22 original + 5 new regression), ruff clean, branch `feat/159-12`.

**Changes to `advisory_never_edit_zone.py`:**
1. **ReDoS fix (required):** `_collapse_double_stars` collapses consecutive `**` segments before regex translation — kills the chained-`**` blowup (PoC pattern now translates to a single linear group). Tests: `test_collapse_adjacent_double_stars`, `test_chained_double_star_pattern_is_bounded_and_correct` (bounded < 2 s + semantics preserved).
2. **Path normalization → lexical `os.path.normpath` (both branches):** replaced `Path.resolve()`. **This also fixed a latent correctness bug I found while doing it** — `resolve()` follows the `.pennyfarthing/` symlinks and rewrote the edited path to its *source*, so editing a real symlinked zone via an **absolute path produced NO advisory** (the feature's headline case, hidden because tmp fixtures used no real symlinks). Verified empirically; see Design Deviations → Dev. Tests: `test_absolute_symlink_path_matches_zone` (real filesystem symlink), `test_relative_path_with_dotdot_is_normalized`.
3. **AC4 length (`_clip`):** reminders are now guaranteed < 200 chars (truncated with `…`). Test: `test_reminder_stays_under_200_chars_for_deep_path`.

No changes to `dispatch.py`/`cli.py` this round → prior dispatch regression run (57/57) still valid.

**Handoff:** Back to Reviewer (Captain Darling) for re-review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 (22/22 tests, ruff clean, 0 smells) | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | n/a | Disabled via settings — assessed manually |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | n/a | Disabled via settings — assessed manually |
| 4 | reviewer-test-analyzer | Skipped | disabled | n/a | Disabled via settings — assessed manually |
| 5 | reviewer-comment-analyzer | Skipped | disabled | n/a | Disabled via settings — assessed manually |
| 6 | reviewer-type-design | Skipped | disabled | n/a | Disabled via settings — assessed manually |
| 7 | reviewer-security | Yes | findings | 2 (1 Medium ReDoS, 1 Low path-norm) | confirmed 2, dismissed 0, deferred 0 |
| 8 | reviewer-simplifier | Skipped | disabled | n/a | Disabled via settings — assessed manually |
| 9 | reviewer-rule-checker | Skipped | disabled | n/a | Disabled via settings — assessed manually |

**All received:** Yes (2 enabled subagents returned; 7 disabled via `workflow.reviewer_subagents` and assessed manually)
**Total findings:** 2 confirmed by security (1 Medium, 1 Low) + 2 Low from my own analysis; 0 dismissed, 0 deferred.
**Round 2 (re-review):** preflight re-run (27/27 green, ruff clean); the Medium ReDoS re-verified **RESOLVED** by Reviewer (empirical 0.06 ms); Low findings addressed in the rework. No new subagent findings.

## Reviewer Assessment

**Verdict:** APPROVED (after Round-1 rework)

> **Round 1** rejected for a confirmed Medium ReDoS cliff; per user decision we hardened it before merge rather than deferring. **Round 2 (re-review):** the rework resolves it — empirically re-verified the exact PoC pattern dropped from ~37,000 ms to **0.06 ms** (it collapses to a single linear `^(?:[^/]+/)*nomatch$` group); 27/27 tests green (preflight re-run), ruff clean. The rework also surfaced and fixed a **latent correctness bug** (absolute-path edits of a real `.pennyfarthing/` symlink missed the zone under `Path.resolve()`) — a net correctness gain. Detail in "Re-Review (Round 2)" below.

**Data flow traced:** agent-controlled `tool_input.file_path` (stdin) → normalized to `rel_path` (L128–146) → string/regex match vs repos.yaml `never_edit` (L94–106) → emits FYI `additionalContext` (L150–159). The path is NEVER opened, executed, or used for an access-control decision — it only decides whether to print a reminder. Safe by construction.

**Pattern observed:** clean reuse — hook mirrors `pre_edit_check.py` conventions (stdin JSON, `CLAUDE_PROJECT_DIR`, fail-soft) and reuses the existing `load_repos_config` loader (SOUL #2). `advisory_never_edit_zone.py:27,133–136`.

**Findings (all non-blocking; no Critical/High):**

| Severity | Tag | Issue | Location | Decision |
|----------|-----|-------|----------|----------|
| MEDIUM | [SEC] | ReDoS: chained `**` groups in a `never_edit` pattern → polynomial backtracking (PoC: 8×`**` vs 50-seg path = 37 s) | advisory_never_edit_zone.py:51,73 | **RESOLVED** (Round 2): `_collapse_double_stars` folds adjacent `**` → PoC now 0.06 ms; regression tests added. |
| LOW | [SEC] | relative `file_path` branch skips `..` normalization (absolute branch resolves) | advisory_never_edit_zone.py:144 | CONFIRMED, cosmetic — rel_path never used for I/O, so no traversal. |
| LOW | [TEST] | AC4 "< 200 chars" reminder length neither enforced nor tested; deep symlinked paths can exceed it | advisory_never_edit_zone.py:109–112 | CONFIRMED, non-blocking. |
| LOW | [SIMPLE] | repos.yaml re-parsed on every matching edit (no cache) | advisory_never_edit_zone.py:94 | CONFIRMED, negligible. |

**Subagent-tag coverage** (disabled specialists assessed manually):
- **[SEC]** — 2 findings confirmed above (ReDoS Medium, path-norm Low).
- **[SILENT]** (disabled) — `except Exception: pass` (L162) is the *required* hook fail-soft; `SystemExit` re-raised first (L160–161) so intentional exits aren't masked. VERIFIED intentional, not a swallow bug.
- **[EDGE]** (disabled) — empty path (L130), missing `tool_input`, absolute-outside-root (L141–142 `ValueError`→exit), non-JSON stdin (L124–126), deep nesting: all covered by tests; the one genuine edge (match-depth blowup) is captured under [SEC].
- **[TEST]** (disabled) — 22 tests, meaningful assertions (HookResponse presence/absence, exit codes, specific substrings); gap: no reminder-length test (Low above).
- **[TYPE]** (disabled) — all functions annotated (L30,67,78,92,120); `str`-typed paths idiomatic; no newtype smell in a 169-line hook. Clean.
- **[DOC]** (disabled) — module + function docstrings accurate; L133–135 comment correctly justifies the `CLAUDE_PROJECT_DIR` choice. Clean.
- **[SIMPLE]** (disabled) — Low (repos.yaml re-parse) above; otherwise minimal, no dead code.
- **[RULE]** (disabled) — enumerated below; clean.

### Rule Compliance (.pennyfarthing/gates/lang-review/python.md)

| # | Rule | Verdict |
|---|------|---------|
| 1 | Silent exception swallowing | COMPLIANT — L162 broad catch is the required hook fail-soft; `SystemExit` re-raised (L160). |
| 2 | Mutable default args | COMPLIANT — none. |
| 3 | Type annotations at boundaries | COMPLIANT — all module fns annotated. |
| 4 | Logging coverage/correctness | N/A — no logger imported (acceptable; a debug log on the fail-soft catch would aid diagnosis). |
| 5 | Path handling | PARTIAL — absolute branch resolves (L140); relative branch (L144) does not (Low [SEC]); no `open()` added. |
| 6 | Test quality | COMPLIANT — concrete assertions; gap: no length test (Low [TEST]). |
| 7 | Resource leaks | COMPLIANT — no `open()` in hook; loader uses `with`. |
| 8 | Unsafe deserialization | COMPLIANT — reuses `yaml.safe_load`; no `yaml.load`. |
| 9 | Async pitfalls | N/A — synchronous. |
| 10 | Import hygiene | COMPLIANT — no star imports. |
| 11 | Input validation at boundaries | PARTIAL — file_path validated (empty/abs guards); ReDoS unbounded (Medium [SEC]). |
| 12 | Dependency hygiene | COMPLIANT — no new deps (`pathspec` avoided). |
| 13 | Fix-introduced regressions | COMPLIANT — CLAUDE_PROJECT_DIR fix added no broad catch / bad type. |

### Devil's Advocate

The most damning case is the [SEC] ReDoS: this hook runs synchronously on the hot path of every Edit/Write/MultiEdit, *before* the tool executes. If a `never_edit` pattern ever contains adjacent `**` groups, every edit in the session grinds to a ~37-second halt — a self-inflicted denial of service a maintainer could trigger by fat-fingering a pattern, with no error, no timeout, and no cap to save them. The fail-soft `except` does not help: the hang is *inside* `re.search`, not an exception. Second: AC4's "< 200 char" bound is quietly violated for deep symlinked paths, and nothing tests it, so the advisory bloats context on exactly the deeply-nested files where it most often fires. Third: the relative-path branch trusts `file_path` verbatim — a `../`-laden relative path is matched un-normalized, so the "correct source" rewrite could point at a wrong path for such input (cosmetic, but wrong). Fourth: re-reading and re-parsing repos.yaml on every edit multiplies I/O across a session on a slow filesystem. Fifth: a malicious repos.yaml in a cloned consumer repo is *trusted* by this code — but that is the same trust boundary as the rest of `pf`, not a new hole. What survives scrutiny: the advisory-only invariant is airtight (no `permissionDecision` path exists anywhere in the file), enforcement is untouched, and YAML loading is safe. Every blocking-severity claim collapses on reachability — each serious failure requires editing trusted, committed config. Conclusion: the code is correct for its real inputs, with one latent robustness cliff (ReDoS) worth a cheap hardening. Real Medium, not a blocker.

### Rework Scope (for TEA → Dev)

**Required (reason for rework):** Harden `_translate`/`_matches` so chained/adjacent `**` groups cannot cause polynomial backtracking. Simplest fix: collapse consecutive `**` segments during translation (`**/**` → `**`), which makes the PoC pattern linear. Add a regression test that a pattern like `**/**/**/**/**/**/**/**/nomatch` matched against a deep (~50-segment) path returns in bounded time (well under 1 s) and still yields correct results for normal single-`**` patterns.

**Include while in the same file (cheap, optional but preferred):**
- Normalize the relative-`file_path` branch (L144) like the absolute branch (`(project_root / fp).resolve().relative_to(project_root)` under the same `ValueError` guard).
- Add the AC4 reminder-length assertion (< 200 chars) and truncate the reminder if a path would exceed it.

**Handoff:** Back to Dev (Baldrick) for a GREEN-rework loop (fix + regression test, per the approval gate's `target_phase: green`), then re-review.

### Re-Review (Round 2) — after rework

**Verdict:** APPROVED.

**Rework verified:**
- **ReDoS [SEC] — RESOLVED.** Re-ran the exact PoC (`"**/"*8 + "nomatch"` vs a 60-segment non-matching path): **0.06 ms** (was ~37,000 ms). `_collapse_double_stars` folds adjacent `**` into one before translation, so the regex is a single linear `^(?:[^/]+/)*nomatch$`. Regression tests `test_collapse_adjacent_double_stars` + `test_chained_double_star_pattern_is_bounded_and_correct` lock it in.
- **Latent symlink bug — FIXED (bonus).** The rework replaced `Path.resolve()` with lexical `os.path.normpath`, fixing a real correctness bug: absolute-path edits of a genuine `.pennyfarthing/` symlink previously resolved to the source and missed the zone (no advisory). Verified the new `test_absolute_symlink_path_matches_zone` uses a real filesystem symlink. This is a net improvement over what Round 1 approved-modulo-ReDoS.
- **[TEST]** AC4 length now guaranteed by `_clip` (< 200) + `test_reminder_stays_under_200_chars_for_deep_path`. **[SEC]** relative-path `..` now normalized + escape-guarded (`test_relative_path_with_dotdot_is_normalized`).
- **Preflight (round 2):** 27/27 green, ruff clean, 0 smells, branch `feat/159-12`.

**Residual (noted, non-blocking):** `_collapse_double_stars` neutralizes *adjacent* `**` (the PoC and the realistic pathological form). A contrived *non-adjacent* chain (`**/x/**/x/…` with repeated literals) would still be higher-degree polynomial — same trusted-config-only class, even lower likelihood. A fully general fix (linear segment DP matcher) is already recorded as a future option in Delivery Findings. Not a blocker.

**No new Critical/High.** All Round-1 findings resolved or accepted.

**Handoff:** To SM (Edmund Blackadder) for finish-story.