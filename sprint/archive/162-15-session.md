---
story_id: "162-15"
jira_key: ""
epic: ""
workflow: "trivial"
---
# Story 162-15: Revert Ghostty tab-title feature (PR #154): inert under Claude Code

## Story Details
- **ID:** 162-15
- **Jira Key:** (none)
- **Workflow:** trivial
- **Stack Parent:** none
- **Branch:** feat/162-15-revert-ghostty
- **PR:** #256

## Acceptance Criteria

Revert PR #154 (merge commit a2d96e282) cleanly:
- Remove all Ghostty tab-title sync feature code paths
- No dead statusline OSC-2 title code left behind
- Test suite exits 0 after revert

## Technical Approach

**Root cause (confirmed live):**
1. The statusline hook writes an OSC 2 title escape to a tty
2. `/dev/tty` is unavailable in the hook subprocess (Errno 6), fallback to `_resolve_ancestor_tty`
3. Claude Code writes terminal title per-turn to the same tty
4. Hook's change-detection cache suppresses re-writes after first
5. Result: Claude Code is always the last writer, feature appears inert

**Why revert (not fix):**
- `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` broken for ongoing updates (upstream anthropics/claude-code#47397, feature request #56933)
- Feature fails invisibly (caches success while doing nothing)
- No supported fix available

**Revert target:** framework PR #154, base `develop`

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-08-18T14:18:20Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-18T14:03:13Z | 2026-08-18T14:05:14Z | 2m 1s |
| implement | 2026-08-18T14:05:14Z | 2026-08-18T14:11:43Z | 6m 29s |
| review | 2026-08-18T14:11:43Z | 2026-08-18T14:18:20Z | 6m 37s |
| finish | 2026-08-18T14:18:20Z | - | - |

## SM Assessment

Story routed as `trivial` (2pt, p3) → SM → Dev (skip TEA). Setup verified: bare
session name, phase `setup`, working branch cut off `develop` (gitflow), status
`in_progress`, no Jira (YAML-only). Poison-token discipline held — field tokens
live only in Story Details.

This is a **revert** story, not a feature build. Guidance for Dev (implement phase):
- Target is framework PR `#154`, merge commit `a2d96e282` (base `develop`). Prefer a
  clean `git revert -m 1 a2d96e282` if the tree still applies; if the merge has drifted,
  do a surgical manual removal of the Ghostty tab-title / statusline OSC-2 title code
  paths and say so as a deviation.
- Acceptance is: feature code paths gone, no dead OSC-2 title code left behind, suite
  exits 0 (the known 7 loud xfails are expected — suite stays exit 0).
- No test-authoring ceremony (trivial); verification is suite-green + grep-confirming the
  reverted paths are absent. Reviewer follows.

Handoff to Dev (implement phase).

## Dev Assessment

**Implementation Complete:** Yes

**Approach:** Clean merge-revert. `git revert -m 1 a2d96e282` applied without
conflict — the feature was purely additive (481 insertions, 0 prior deletions)
and no commit had touched either file since the merge, so the revert restored the
exact pre-feature state.

**Files Changed:**
- `pennyfarthing-dist/src/pf/hooks/statusline.py` — removed the five feature
  helpers (`_get_phase`, `_compose_tab_title`, `_resolve_ancestor_tty`,
  `_write_title_to_tty`, `_set_terminal_title`), the `main()` call site, and the
  now-unused `import time` (129 lines removed).
- `pennyfarthing-dist/src/pf/tests/test_statusline_tab_title.py` — deleted (the
  feature's own 352-line test file).

**Verification:**
- Codebase-wide grep: zero surviving references to any removed symbol and no
  `tab-title`/`tab_title` cache paths remain. The `_get_phase*` grep hits are
  unrelated `handoff` module functions, not the reverted statusline helper.
- `python3 -m py_compile statusline.py` — OK.
- Remaining statusline tests (`test_statusline_model_persist.py`,
  `test_subagent_statusbar.py`) — 14/14 GREEN (scoped run; full suite avoided
  per branch-leak discipline).
- `ruff check src/pf/hooks/statusline.py` — All checks passed.

**Commit:** `89152fd` (GPG-signed, verified Good) on branch
`feat/162-15-revert-ghostty`, pushed to origin.

**Handoff:** To Reviewer for code review.

## Delivery Findings

### Dev (implementation)
- No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)
- No blocking upstream findings. Two pre-existing, non-blocking test-quality
  observations in files NOT touched by this revert (`test_subagent_statusbar.py`
  vacuous `len>0` assertion; `_write_tmux_cache` integration gap in `statusline.py`)
  were surfaced by reviewer-test-analyzer and dispositioned `drop` (chore-grade,
  out of scope for a revert PR — ride the next edit of those files per the
  lang-review checklist). Not filed as stories per ADR-0043.

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- **Dev: "No deviations from spec."** → ✓ ACCEPTED by Reviewer: correct. Dev
  used the exact approach the SM assessment recommended (`git revert -m 1
  a2d96e282`); the revert applied cleanly with no drift, so there was nothing to
  deviate from. No undocumented spec divergence found — the diff is a complete,
  faithful reversal of PR #154 (481 deletions mirror the 481 insertions).

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 2 | confirmed 2 (both drop — pre-existing, out of scope), dismissed 0, deferred 0 |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings |
| 6 | reviewer-type-design | Yes | clean | none | N/A |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | clean | none | N/A |

**All received:** Yes (5 enabled returned, 4 disabled pre-filled)
**Total findings:** 2 confirmed (both dispositioned `drop`), 0 dismissed, 0 deferred

**Working-tree audit:** `pf reviewer audit-tree` reported DIRTY, but ONLY on
orchestrator-repo files (`sprint/epic-162.yaml` status bump, untracked
`sprint/context/context-story-162-15.md` sm-setup artifact) — the known false
positive. The REVIEWED repo `pennyfarthing/` is clean (`git -C pennyfarthing
status --porcelain` empty). No mutation-testing subagent ran (all specialists
read-only). Did NOT run `git clean -fd` (would destroy SM's legitimate setup
artifacts).

### Finding Dispositions (ADR-0043)
- **[TEST] Vacuous `len>0` assertion in `test_subagent_statusbar.py:158`** —
  disposition: **drop**. Pre-existing, in a file NOT in this diff; not `[SEC]`,
  not a correctness bug. Chore-grade test-hardening that rides the next edit of
  that file. Not promoted to a story.
- **[TEST] `_write_tmux_cache` integration path unexercised (`statusline.py:447`)** —
  disposition: **drop**. Pre-existing gap (low confidence), predates this revert;
  not `[SEC]`/correctness. Chore-grade. Not promoted to a story.

## Reviewer Assessment

**Verdict:** APPROVED

This is a pure-deletion revert of framework PR #154 (the Ghostty tab-title
statusline feature), 481 lines removed across `statusline.py` (-129) and the
feature's own deleted test file (-352). I verified the removal is complete,
faithful, and leaves the surviving module self-consistent. Five enabled
specialists returned clean or out-of-scope-only; I covered the four disabled
domains first-hand (tagged below).

**Data flow traced:** The removed feature read the session file's `**Phase:**`
line → composed `<dir> <story> <phase>` → wrote an OSC-2 escape to a tty. All
three legs (`_get_phase` → `_compose_tab_title` → `_write_title_to_tty`) and the
`main()` call site are gone atomically. The surviving `main()` data flow
(workspace JSON → `dir_name`/`story_id` → Claude Code status bar + tmux cache)
is untouched and reads only through still-defined helpers.

**Observations (≥5):**
- `[VERIFIED]` Surviving `main()` is self-consistent — every function it calls
  (`_parse_input`, `_persist_model`, `_get_context_pct`, `_get_story_id`,
  `_write_tmux_cache`, `_get_character_display`, …) is still defined;
  `statusline.py:445-470` shows the removed 4-line `_set_terminal_title` block
  gone with no dangling call. Evidence: `py_compile` OK, ruff clean.
- `[VERIFIED]` `import time` removal is safe — the only surviving `time` user is
  `_resolve_agent`'s self-contained inline `__import__("time").time()`
  (statusline.py:~253), independent of the removed top-level import; ruff
  confirms no module-level `time` reference remains.
- `[TYPE]` type-design clean — all five removed symbols were underscore-private,
  no `__all__`, zero external imports (cross-package grep). No type contract
  broken by the deletion.
- `[SEC]` security clean — the OSC-2 escape-injection surface is *eliminated*,
  not degraded: the `re.sub(r"[\x00-\x1f\x7f-\x9f]", "", title)` sanitizer and
  the tty writer were removed together (no half-revert). No tty write path
  survives; no secrets/paths were guarded by the removed code.
- `[RULE]` rule-checker clean — 15 rules / 31 instances / 0 violations; edit is
  in the correct source location (`pennyfarthing-dist/`, not a symlink runtime
  path); no dangling cross-module references.
- `[TEST]` test-analyzer surfaced 2 observations, BOTH pre-existing in files not
  in this diff (`test_subagent_statusbar.py`, unchanged `statusline.py` region).
  Neither is caused by the revert; the deleted test file targeted ONLY the
  removed feature (22 feature-specific tests). Dispositioned `drop` (above).
- `[EDGE]` (specialist disabled — covered first-hand): a pure deletion introduces
  no new boundary conditions. The removed code's own edge handling (missing
  session file, no tty, backoff sentinel) is deleted wholesale; no partial path
  survives. Surviving `main()` branch conditions (`PF_SUBAGENT`, empty cwd) are
  unchanged.
- `[SILENT]` (disabled — covered first-hand): no swallowed-error regression. The
  removed `except OSError: pass` blocks were fail-soft cache guards deleted in
  full; surviving `except` blocks in `main()`/`_write_tmux_cache`/`_get_story_id`
  are byte-identical to develop (not in the diff).
- `[DOC]` (disabled — covered first-hand): no stale documentation. Docstrings of
  the removed functions were deleted with them; grep finds no surviving comment,
  guide, or docstring that references tab-title / OSC-2 / the removed symbols.
- `[SIMPLE]` (disabled — covered first-hand): the change IS a simplification —
  it removes 481 lines of code that was inert under Claude Code (SOUL #1: fix
  the system, don't ship a feature that caches success while doing nothing).

### Rule Compliance
Rules enumerated against the diff (lang-review/python + SOUL/CLAUDE). Because the
diff is pure deletion (0 added lines), every rule that scans added code has no
in-scope instance; the applicable checks are (a) the removal introduces no
violation and (b) the edit location/backwards-compat rules:
- **One Truth / correct source location** — compliant: edited
  `pennyfarthing-dist/src/pf/hooks/statusline.py`, not a `.pennyfarthing/`
  symlink target.
- **Return Results, don't throw (SOUL #10)** — N/A: no functions added; surviving
  result-contract functions untouched.
- **Import hygiene** — compliant: `import time` removed with its last user; no
  orphaned import (ruff clean).
- **No dangling references** — compliant: cross-package grep finds zero surviving
  references to the five removed symbols (`_get_phase*` hits are unrelated
  `pf.handoff` functions).
- **Backwards-compat (pf-init-impact)** — compliant: only private helpers removed;
  no public API / YAML schema change; the removed runtime cache files
  (`.pennyfarthing/.runtime/tab-title*`) are ephemeral, not a contract.

### Devil's Advocate
Let me try to break this. *Could the revert be incomplete — a sanitizer left
without its writer, or a writer without its guard?* No: security confirmed the
`re.sub` sanitizer and both `open()` tty writes were removed as one unit, and
rule-checker enumerated the deletion function-by-function. *Could removing
`import time` break a surviving caller?* The obvious trap — `_resolve_agent` uses
`time.time()` — turns out to use an inline `__import__("time")`, so it never
depended on the top-level import; ruff and py_compile both pass, which they would
not if a module-level `time.` reference survived. *Could a consumer or another
module import one of the deleted private helpers and now crash on upgrade?* Three
independent greps (preflight, type-design, security) across the whole `pf`
package found zero external importers; the only importers of `statusline`
reference `main`/`_persist_model`/`_get_character_display`, all surviving. *Does
deleting the test file silently drop coverage of live code?* No — the 22 deleted
tests exercised only the removed functions; the surviving `main()` paths keep
their coverage in `test_statusline_model_persist.py` / `test_subagent_statusbar.py`
(14/14 green). *Is there a behavioral regression for users who liked the tab
title?* The feature was inert under Claude Code by design (Claude is always the
last writer to the tty; upstream bug #47397) — users saw nothing, so they lose
nothing; a real fix is blocked upstream and out of scope. *Runtime side effects
of the removed cache files?* They live under `.pennyfarthing/.runtime/` and are
regenerated/ignored; no cleanup migration needed. Nothing here rises to
Medium+; the two test-quality notes are pre-existing and out of scope.

**Specialist findings incorporated:** [EDGE] no new boundaries (disabled;
covered first-hand) · [SILENT] no swallow regression (disabled; covered
first-hand) · [TEST] 2 pre-existing out-of-scope, dropped · [DOC] no stale docs
(disabled; covered first-hand) · [TYPE] clean · [SEC] attack surface eliminated ·
[SIMPLE] revert is a net simplification (disabled; covered first-hand) · [RULE]
15/31/0 violations.

**Error handling:** Surviving fail-soft paths unchanged; top-level `main()`
handler prints only `⚠ error` (no path/stacktrace leak) — statusline.py:~557.

**Handoff:** To SM for finish-story.