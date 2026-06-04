---
story_id: "156-3"
jira_key: ""
epic: "156"
workflow: "tdd"
---
# Story 156-3: clarify sprint command surface; story move dependency-rewrite (gh #13)

## Story Details
- **ID:** 156-3
- **Jira Key:** (kanban-only — no Jira)
- **Workflow:** tdd
- **Repo:** pennyfarthing
- **Branch:** feat/156-3-story-move-dep-rewrite
- **Branch Strategy:** gitflow (PR → develop)

## Workflow Tracking
**Workflow:** tdd
**Phase:** green
**Phase Started:** 2026-06-04T06:26:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-04T06:15:00Z | 2026-06-04T06:16:00Z | ~1m |
| red   | 2026-06-04T06:16:00Z | 2026-06-04T06:26:00Z | ~10m |
| green | 2026-06-04T06:26:00Z | 2026-06-04T06:36:00Z | ~10m |
| docs  | 2026-06-04T06:36:00Z | 2026-06-04T06:45:00Z | ~9m |
| review| 2026-06-04T06:45:00Z | - | - |

**DOCS result:** `guides/story-lifecycle.md` + `.gitignore` (`runtime/`) — commit `c21a8f6`. AC5 satisfied.

**RED result:** 9 failed / 3 passed (AC4 guards) — commit `3a53352`. KEY: `depends_on` is SCALAR string (not list). BLOCKING: move is currently broken for any depended-upon story (validator aborts on dangling old_id). Fix: rewrite `depends_on == old_id → new_id` across epics/standalone/top-level BEFORE validate.

**GREEN result:** 12/12 passing (incl. 3 AC4 guards still green) — commit `a55d72d`. Fix: `_rewrite_dependencies(data, old_id, new_id)` helper, called after `new_id` computed and before `validate_sprint_document`. Scoped regression `-k "story_move or 156_3 or move"` = 100 passed.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_move.py` — added `_rewrite_dependencies` helper + call site before validation (renumber → rewrite-deps → validate → write).

**Tests:** 12/12 passing (GREEN); scoped regression 100/100. 3 AC4 guards stayed green.
**Branch:** feat/156-3-story-move-dep-rewrite (pushed, commit `a55d72d`)

**Handoff:** To review phase (AC5 docs is a later Tech Writer phase, not this commit)

## Context (from gh #13) — SCOPED

**Discovery:** The headline ask of #13 — `pf sprint story move <id> --to-epic <epic>` —
**already exists** (`sprint/story_move.py`, wired into CLI; renumbers to target epic's
next id; survives the sharded layout via `write_sprint`). So #13 is ~70% pre-built.

**Approved scope for 156-3 (user decision):**
1. **CODE (TDD) — dependency-rewrite gap.** `move_story` renumbers `old_id → new_id`
   (story_move.py:110-114) but does NOT rewrite `depends_on` references elsewhere in the
   sprint. Any other story with `depends_on: [old_id]` is left pointing at a dead ID
   after a move. The issue explicitly demands "remove/insert/renumber/**dependency-rewrite**
   in one atomic operation." Fix: on move, rewrite every `depends_on` entry across all
   epics/standalone/top-level stories that referenced `old_id` to `new_id`, atomically,
   before validation + write.
2. **DOCS — story-lifecycle guide.** Add a concise `guides/story-lifecycle.md` documenting
   the full `pf sprint story` CLI surface (add, update + its fields, move, finish, remove,
   split, transition, claim) — the "which ops are CLI-supported vs manual / document in one
   place" ask. Note move's dependency-rewrite behavior once implemented.

**Deferred (filed as follow-ups, NOT this story):**
- `--epic` on `story update` (redundant now that `move` exists).
- Splitting `update`'s grab-bag / `--help` flag grouping.
- Broader surface audit (rename, re-parent dependencies).

**Code pointers:**
- `pennyfarthing-dist/src/pf/sprint/story_move.py` — `move_story()`; renumber at :110-114.
- `depends_on` is consumed in `story_add.py`, `validator.py`, `story_split.py`, `yaml_io.py`.
- A story's `depends_on` is a list of story-id strings (confirm shape in validator/schema).

## Acceptance Criteria (TEA to finalize in RED)
- AC1: after `move_story(old_id → new epic)`, any OTHER story whose `depends_on` contained
  `old_id` now contains `new_id` instead (across epics/standalone/top-level).
- AC2: the moved story's OWN `depends_on` entries are preserved unchanged (their targets
  didn't move).
- AC3: a `depends_on` entry that referenced a DIFFERENT (unmoved) story is untouched.
- AC4: the rewrite is atomic — if post-move validation fails, nothing is written (existing
  contract preserved); dry-run reports the planned rewrite without writing.
- AC5 (docs): `guides/story-lifecycle.md` exists and lists the story CLI surface incl.
  `move`'s dependency-rewrite. (Verified by Tech Writer + a light presence check.)

## Delivery Findings
**Types:** Gap, Conflict, Question, Improvement | **Urgency:** blocking, non-blocking
<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (blocking): Today `move_story` is not merely missing the dep-rewrite — it is *broken for any story that has dependents*. Order is renumber → `validate_sprint_document` → write; the validator's `_validate_depends_on` catches the now-dangling `old_id` and the move returns `success: False`, writing nothing. So a depended-upon story currently CANNOT be moved at all. Affects `pennyfarthing-dist/src/pf/sprint/story_move.py` (rewrite all `depends_on == old_id` to `new_id` across epics/standalone_stories/top-level `stories` BEFORE the validate step). *Found by TEA during test design.*
- **Question** (non-blocking): Session ACs describe `depends_on` as a list (`depends_on: [A_old_id]`), but the real data model is a SCALAR string — `story_add.py` types it `str | None`, `story_split.py` writes a single id, `validator._validate_depends_on` coerces with `str(dep)`. Tests are built against the scalar shape. If a future multi-dep model is intended, that is a separate story. Affects `pennyfarthing-dist/src/pf/sprint/story_move.py` (rewrite must handle scalar). *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): An untracked runtime log `runtime/src/.session/frame.log` keeps appearing in the worktree and was nearly swept into the fix commit by `git add -A` (caught and removed via `--amend`). Affects repo hygiene — `runtime/src/.session/` (a runtime path) should be gitignored so future `git add -A` doesn't capture it. *Found by Dev during implementation.*

### Tech Writer (documentation)
- **Improvement** (non-blocking): `pf sprint story add` exposes `--epic` (overrides the positional `EPIC_ID`) but `update` does not — documented the asymmetry in the guide ("changing a story's epic is a `move`, not an `update`"). The flag names also differ slightly from prose: the dependency flag is `--depends-on` (hyphen) while the YAML field is `depends_on` (underscore). Both noted accurately in `guides/story-lifecycle.md`. *Found by Tech Writer during documentation.*
- **Improvement** (non-blocking): Repo-hygiene gitignore — `runtime/` had zero tracked files (`git ls-files runtime/` empty), so the precise correct entry is `runtime/` (not the deeper `runtime/src/.session/`). Added under the "Pennyfarthing runtime" section. *Found by Tech Writer during documentation.*

## Tech Writer Assessment

**Documentation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/guides/story-lifecycle.md` — concise story-lifecycle CLI reference (AC5): full `pf sprint story` subcommand table, `update` fields, `move`'s renumber + re-parent + dependency-rewrite, and a CLI-supported-vs-manual boundary section.
- `.gitignore` — added `runtime/` under the Pennyfarthing runtime section to stop the runtime log from being swept into commits.

**Audience:** developers (PF framework + orchestrator users)
**Quality Checks:** command surface verified against live `--help` (no invented flags); `move` behavior verified against `story_move.py`; `depends_on` confirmed scalar; gitignore verified — `runtime/` untracked, no tracked file newly ignored.

**Handoff:** To review phase (AC5 satisfied).

## Review (Granny Weatherwax) — APPROVE-WITH-NITS @ c21a8f6
Verified: RED returns (remove call site → 9 fail), GREEN 12/12, edge cases (None/absent/int/non-dict/None-container) no crash, whole-value match holds (`10-10`/`1010` untouched moving `10-1`), all 3 containers walked, ordering correct (after new_id, before validate), AC4 atomicity pinned, guide accurate vs live --help, `.gitignore runtime/` ignores nothing tracked. No Blocking/High/Medium.
- **Nit:** `test_substring_decoy_story_id_intact` near-vacuous (real coverage in `test_substring_decoy_dependent_untouched`). No fix required.
- **Nit (pre-existing, FILE follow-up):** `validator._validate_depends_on` (validator.py:515-531) only validates `depends_on` in `epics[].stories`, not `standalone_stories`/top-level `stories` — a dangling dep there would pass. Not a 156-3 regression.
- Self-dependency self-cycle: validator already rejects; rewrite doesn't create it. Out of scope.

## Design Deviations
<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **depends_on shape:** ACs say list (`[A_old_id]`); tests use SCALAR string (`depends_on: "10-1"`). Reason: actual data model is a single id string across `story_add.py` / `story_split.py` / `validator.py` / `yaml_io.py`. No list form exists.
- **new_id is asserted concretely:** Tests pin `10-1` -> `20-2` (target epic 20 pre-seeded with `20-1`; `generate_story_id` = `{epic}-{max_seq+1}`). Reason: renumbering is deterministic, so dependents' rewritten value is checkable exactly, and old != new makes the rewrite observable.

### Dev (implementation)
- **Scalar-only rewrite:** Implemented `_rewrite_dependencies` against the scalar-string `depends_on` model (whole-value equality, `==`), matching TEA's data-model finding. No list handling added (no list form exists; multi-dep would be a separate story).

## TEA Assessment

**Tests Required:** Yes
**Reason:** TDD RED phase — dependency-rewrite gap on `move_story`.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_156_3_move_dep_rewrite.py` — 12 tests across AC1-AC4 for depends_on rewrite on story move.

**Tests Written:** 12 tests covering AC1-AC4 (AC5 is docs, later phase)
**Status:** RED (9 failing as expected, 3 AC4 guard-tests green pinning the existing atomic/dry-run contract that must be preserved)

**Handoff:** To Dev for implementation
