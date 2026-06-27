# Story 155-12 Context

## Title
Finish completes ceremony when merge_pr fails on a CONFLICTING/DIRTY PR - done-but-unmerged (gh #113)

## Metadata
- **Story ID:** 155-12
- **Type:** bug
- **Points:** 2
- **Priority:** p1
- **Workflow:** tdd
- **Repo:** pennyfarthing
- **Epic:** 155 — Finish/merge/archive truthfulness
- **Source:** GitHub issue slabgorb/pennyfarthing#113

## Problem
`pf sprint story finish <id>` runs a 7-step ceremony:

```
1. archive_session
2. merge_pr
3. jira_done
4. yaml_update
5. archive_epics
6. git_cleanup
7. remove_session
```

When **step 2 (`merge_pr`) fails because the PR is not mergeable** — e.g.
`mergeStateStatus: DIRTY` / `mergeable: CONFLICTING` because the base branch
(`develop`) moved under the feature branch — **the ceremony continues anyway.**
It archives + removes the session, updates the sprint YAML, and archives the
epic. The story is now recorded as **done**, but its code is **not merged**
(PR still `OPEN`, `mergedAt: null`).

This is a data-integrity bug: it violates Pennyfarthing's **No Silent Fallbacks**
principle (a failed merge is masked by a green-looking finish) and leaves the
tracker in a lying "done over an unmerged PR" state that is only caught if the
operator independently checks `mergedAt`. Recovery is manual and easy to forget.

## Repro (observed live, 2026-06-13)
1. A feature branch's PR is open and approved, but `develop` advanced with a
   sibling PR touching the same files → PR becomes `CONFLICTING`.
2. Run `pf sprint story finish <id>`.
3. Output lists all steps including `merge_pr` with **no error surfaced**.
4. `gh pr view <#> --json state,mergedAt` → still `OPEN`, `mergedAt: null`.
5. But the session is archived + removed and `current-sprint.yaml` /
   `*-completed.yaml` already mark the story done.

## Scope
- **In scope:** the `pf` finish ceremony path (`story_finish.py`) and/or the
  `sm-finish` preflight (`pf.preflight`). Make a failed/incomplete merge a hard
  stop *before* any irreversible step (archive/remove session, YAML update,
  epic archive).
- **Out of scope:** unrelated finish-flow refactors; the `pf.*` interpreter
  issue in the `sm-finish` template (that is sibling story 155-11 / gh #112).

## Acceptance Criteria
_(derived from the issue's suggested fix — TEA refines exact test seams in RED)_

- **AC1 — Pre-merge hard gate:** before merging, check
  `gh pr view --json mergeable,mergeStateStatus`. If not `MERGEABLE`/`CLEAN`,
  **stop the ceremony with a non-zero exit** and a clear message (e.g.
  `"PR #N is CONFLICTING — rebase on develop and resolve before finishing"`).
  Do **not** archive/remove the session or touch the YAML.
- **AC2 — Post-merge verification:** after attempting the merge, **verify
  `mergedAt != null`** (or that a merge commit exists) before proceeding to
  `archive_session` / `yaml_update` / `remove_session`.
- **AC3 — Preflight surfacing:** the `sm-finish` preflight reports
  `ready_to_finish: false` with the PR state in `issues[]`, so SM blocks rather
  than running `finish` on an unmergeable PR.
- **AC4 — Tests pin both paths:** a `CONFLICTING`/`DIRTY` PR makes `finish`
  abort **before any irreversible step** (session intact, YAML untouched, exit
  non-zero); a `CLEAN`/`MERGEABLE` PR proceeds normally through the full
  ceremony.

## Notes
- p1 because it corrupts the sprint ledger (records unmerged work as done).
- Behaviour must fail loud, consistent with SOUL principle #10 (Return Results,
  Don't Throw) and the No Silent Fallbacks line the issue cites.

---
_Enriched by SM from gh #113 (the `pf context create` stub had no description/ACs)._
