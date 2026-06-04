---
story_id: "156-2"
jira_key: ""
epic: "156"
workflow: "tdd"
---
# Story 156-2: story update leaks jira-cli email into personal-project YAMLs (gh #12)

## Story Details
- **ID:** 156-2
- **Jira Key:** (kanban-only — no Jira)
- **Workflow:** tdd
- **Repo:** pennyfarthing
- **Branch:** feat/156-2-gate-jira-assignee-lookup
- **Branch Strategy:** gitflow (PR → develop)

## Workflow Tracking
**Workflow:** tdd
**Phase:** green
**Phase Started:** 2026-06-04T05:52:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-04T05:40:00Z | 2026-06-04T05:41:00Z | ~1m |
| red   | 2026-06-04T05:41:00Z | 2026-06-04T05:52:00Z | ~11m |
| green | 2026-06-04T05:52:00Z | 2026-06-04T06:01:00Z | ~9m |
| review| 2026-06-04T06:01:00Z | - | - |

**RED result:** 1 failed / 13 passed — commit `3b43f54`. Live hole: `story.get("jira")` truthy for `"none"`. AC4 doc-scrub already satisfied (docs sanitized in 2e136d79c) — guards ship green.
**GREEN result:** 14/14 — commit `9ef1055`. Fix: `_has_real_jira_key(story)` helper (sentinels `{"", "none", "null", "x"}`) replaces truthy `story.get("jira")` gate. Scoped regression 247 passed; AC3 green.

## Context (from gh #12)

**Problem:** `pf sprint story update <id> --status in_progress` shells out to `jira me`
to auto-populate `assigned_to`, leaking the user's **work email** into the sprint YAML
of *personal* projects that have no Jira. Silent, no opt-in, re-injected on every update.

**Current state (partial fix already present):** `story_update.py:134-145` already gates
the `jira me` call behind `is_jira_enabled() and story.get("jira")` (added by 152-2).
**The live remaining hole:** `story.get("jira")` is **truthy for the literal string
`"none"`** (and any sentinel placeholder), so a story with `jira: none` STILL triggers
`jira me`. The gate must normalize none/empty/`"none"`/`"None"` → treated as no jira key.

**Code pointers:**
- `pennyfarthing-dist/src/pf/sprint/story_update.py:130-145` — the auto-assignee block.
  `subprocess.run(["jira","me"], ...)` at :141. Gate at :134-139.
- `pennyfarthing-dist/src/pf/jira/client.py:67` — `is_jira_enabled()`.
- Likely want a small helper `_has_real_jira_key(story)` (or reuse an existing
  normalizer) that returns False for `None`, `""`, `"none"`, `"None"`.

**Shipped-doc contamination (issue fix #4):**
- `pennyfarthing-dist/skills/pf-jira/jira.md:40` — "GitHub to Jira User Mapping" table.
- `pennyfarthing-dist/skills/pf-jira/examples.md` — embedded emails.
  Genericize to placeholders (e.g. `you@example.com`, `ghuser → JIRA-USER`); shipped
  skill docs must not embed real corporate emails / real-person mappings.

## Acceptance Criteria (TEA to finalize in RED)
- AC1: `story update <id> --status in_progress` on a story whose `jira` is `none`/`""`/
  absent does NOT invoke `jira me` and does NOT write any jira-derived `assigned_to`.
  (Mock the `jira me` subprocess to a sentinel email; assert it never lands in YAML.)
- AC2: explicit `--assigned-to <x>` is honored regardless of jira state (preferred).
- AC3: no regression — a story WITH a real jira key (and jira enabled) still auto-assigns
  from `jira me` as before.
- AC4: shipped `pf-jira` skill docs contain no hardcoded corporate emails / real-person
  mapping table (genericized to placeholders). A guard test greps the shipped skill
  files for an email-like corporate pattern and asserts none remain.

## Delivery Findings
**Types:** Gap, Conflict, Question, Improvement | **Urgency:** blocking, non-blocking
<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): AC4's premise is stale. The shipped `pf-jira` skill docs
  (`jira.md`, `examples.md`, `usage.md`) were ALREADY sanitized by commit `2e136d79c`
  ("open-source sanitization — strip company refs"). No real corporate emails or
  real-person mapping table remain at this commit — only placeholders
  (`user@your-org.com`, `jira-email@your-org.com`). The AC4 doc-scrub guard tests
  therefore PASS today. They are committed as forward regression guards, not RED.
  Dev has nothing to genericize for #4. *Found by TEA during test design.*
- **Gap** (non-blocking): The `jira: "none"` leak does NOT persist. The validator
  (`validate_sprint_document`) rejects the literal `none` as an invalid Jira-key
  format AFTER the auto-assign block runs, so `update_story` returns success=False
  and never writes. The privacy bug is the **`jira me` subprocess call itself**
  (work email shelled out + captured in process memory), not a value written to
  YAML. RED is asserted on the call, not the persisted dict. Dev's fix must
  normalize `none`/`None` to a falsy "no key" BEFORE the auto-assign gate at
  `story_update.py:134-139`. *Found by TEA during test design.*
- **Gap** (non-blocking): `jira: ""` and absent-jira cases are ALREADY safe — the
  existing `story.get("jira")` gate is falsy for both, so `jira me` is not called.
  Only the literal string `"none"`/`"None"` slips through. Those two cases are
  green regression coverage, not RED. *Found by TEA during test design.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_update.py` — added module-level helper `_has_real_jira_key(story)` (normalizes `None`/empty/whitespace + `none`/`null`/`x` sentinels, case-insensitive, to "no key") and swapped the truthy `story.get("jira")` in the in_progress auto-assign gate (~:152) for `_has_real_jira_key(story)`.

**Tests:** 14/14 passing (GREEN) for `test_156_2_jira_assignee_leak.py`. Scoped regression guard (`-k "story_update or 156_2 or jira"`) 247 passed / 0 failed. AC3 (`test_real_key_auto_assigns_from_jira_me`) explicitly re-run green.
**Branch:** feat/156-2-gate-jira-assignee-lookup
**Commit:** 9ef10553f (signed, `G`)

**Handoff:** To review.

### Dev (implementation)
- **Sentinel set chosen to match local convention:** Spec named `none`/`None`/empty/whitespace as the must-skip set. Implemented set is `{"", "none", "null", "x"}` (case-insensitive, stripped) to mirror the existing inline normalizer at `jira/operations.py:75` (`assignee in ("null", "x", "none")`). Reason: consistency with the only other jira-sentinel check in the codebase; `null`/`x` are existing placeholders that should never trigger `jira me` either. No test asserts on `null`/`x` for the jira-key field, so this is a superset of the AC, not a deviation from any assertion.
- **Helper introduced locally rather than reusing operations.py:** The `operations.py:75` normalizer is inline and coupled to assignee→email mapping (not a reusable key-validity predicate), so a small local `_has_real_jira_key` was added per the brief rather than refactoring an unrelated function. Out of scope to extract a shared util.

## Review (Granny Weatherwax) — APPROVE-WITH-NITS @ 9ef1055
Verified: RED reproduces (revert → `jira me` called), GREEN 14/14, edge matrix (`None`/absent/`""`/`"  none  "`/`NONE`/`null`/`X`) all suppress the subprocess; `"x"` can never be a real key under `JIRA_KEY_PATTERN`; AC4 docs confirmed clean (guard regex not vacuous). No Blocking/High.
- **M (Medium):** `story_update.py:188` jira-SYNC block still uses raw-truthy `story.get("jira")` — same bug class, unreachable today (validator blocks sentinel keys first) but latent. → FIX NOW (gate with `_has_real_jira_key`).
- **L (Nit):** sentinel-set divergence (no shared constant) between new helper and `operations.py:75`. → FILE follow-up.
- **L (Nit):** same raw-truthy pattern at `story_transition.py:75`, `story_finish.py:174`. → FILE follow-up.
- Silent `except Exception: pass` around `jira me` — pre-existing, acceptable.

## Design Deviations
<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **AC1 asserts on the subprocess call, not persisted YAML:** Spec hint said assert
  the sentinel email never lands in the story dict / persisted YAML. For `jira: "none"`
  the leak never persists (validator blocks the write on the bad key), so a
  persisted-value assertion would pass for the WRONG reason. The RED-critical
  assertion is therefore "`jira me` was not called". Sentinel-not-persisted is kept
  as a secondary (green) guard for the empty/absent cases.
- **AC2 no-jira case uses the `absent` fixture, not `none`:** With `jira: "none"` the
  write fails validation regardless of assignee, masking the assignee-preference
  behavior. The absent-jira fixture exercises AC2's "explicit wins, no jira call"
  path cleanly with a successful write.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Privacy/correctness bug (gh #12) — needs an executable guard.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_156_2_jira_assignee_leak.py` — AC1-AC4 for the
  jira-cli assignee email leak.

**Tests Written:** 14 tests (across 4 ACs). 1 FAILING (RED), 13 passing (regression/
forward guards).
**Status:** RED — the `jira: "none"` case calls `jira me` and leaks the work email.

**RED signal:** `TestNoJiraStoryDoesNotLeak::test_in_progress_does_not_call_jira_me[jira_none_file]`
asserts `jira me` is not shelled out for a `jira: "none"` story; it currently IS.

**Handoff:** To Dev for implementation (normalize `none`/`None`/empty → no-key before
the auto-assign gate at `story_update.py:134-139`).
