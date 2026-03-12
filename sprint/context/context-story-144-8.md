---
parent: context-epic-144.md
workflow: trivial
---

# Story 144-8: Remove Tandem Workflows

## Business Context

The tandem workflow files (`tdd-tandem.yaml`, `review-tandem.yaml`, `bdd-tandem.yaml`) were designed around a "background observer" pattern — a partner agent watching in file-watch mode during phases. With Epic 144 adding explicit Architect phases (spec-check before RED, spec-reconcile after Reviewer), the structural role tandem was fulfilling is superseded. Architect now participates in the TDD pipeline with dedicated phases and gates, not as a passive observer.

Leaving the tandem files in place creates confusion: a developer selecting a workflow sees `tdd-tandem` as a viable option, but it routes Architect as a background tandem partner instead of through the new spec-check and spec-reconcile gates. The two approaches conflict. Tandem removal eliminates this ambiguity and establishes the new TDD workflow (story 144-9) as the only production path.

The tandem pattern itself is not deprecated permanently — it needs a full rethink in light of the new Architect phase architecture. That rethink is a future epic. This story makes a clean cut now so 144-9 can wire the new workflow without competing definitions.

**Value delivered:** Operators have one unambiguous workflow path. The `pf workflow list` output is clean. Story 144-9 can update `tdd.yaml` against a filesystem that contains only the workflows that will remain active.

## Technical Guardrails

**Files to delete (all in `pennyfarthing/pennyfarthing-dist/workflows/`):**

- `tdd-tandem.yaml` — TDD with Architect + PM tandem observers on all phases (v3.0.0). Defined `team` and `tandem` blocks on red, green, verify, and review phases.
- `review-tandem.yaml` — TDD with Architect tandem on review phase only (v1.0.0). Lighter variant for large refactors.
- `bdd-tandem.yaml` — BDD with full tandem chain: UX-Designer + Architect, TEA + Dev, Dev + UX-Designer, Reviewer + PM (v1.0.0).

**Sprint YAML reassignment:**

- Active sprint YAML files (non-archive) have no stories currently assigned to `tdd-tandem`, `review-tandem`, or `bdd-tandem`. The grep confirms all remaining references are in `sprint/archive/` (completed stories in MSSCI-15488, MSSCI-15310, MSSCI-14819 epics) and planning documents. Archived stories do not require reassignment — they are done.
- No active story reassignment work is needed. AC-2 and AC-3 are satisfied vacuously for active sprint YAML.

**Workflow registry:** `pf workflow list` reads from `pennyfarthing-dist/workflows/`. Deletion from that directory is sufficient for the command to stop listing the tandem workflows. No separate registry file to update.

**Commit target:** `pennyfarthing/` repo, branch `develop`. Framework commits use `cd pennyfarthing && git add . && git commit -m "..."`.

**Do not touch:**
- `tdd.yaml` — that is story 144-9's scope
- Any agent definitions — no tandem-specific behavior in agent files
- The `tandem-backseat` subagent definition — it is not specific to these workflow files; leave for the future tandem rethink epic
- `pennyfarthing-dist/guides/tandem-protocol.md` — same, leave for future rethink

## Scope Boundaries

**In scope:**
- Delete `tdd-tandem.yaml`, `review-tandem.yaml`, and `bdd-tandem.yaml` from `pennyfarthing/pennyfarthing-dist/workflows/`
- Verify `pf workflow list` no longer shows any of the three deleted workflows
- Confirm no active (non-archived) sprint YAML references the deleted workflow IDs

**Out of scope:**
- Redesigning a replacement tandem pattern — future epic
- Updating `tdd.yaml` — story 144-9
- Removing or modifying the `tandem-backseat` subagent
- Removing `guides/tandem-protocol.md`
- Any changes to sprint archive files — archived stories referencing old workflow values are historical records, not broken references

## AC Context

**AC-1: All three workflow files are deleted**

Given the three files exist at `pennyfarthing-dist/workflows/tdd-tandem.yaml`, `review-tandem.yaml`, and `bdd-tandem.yaml` — when this story is complete, all three are absent from the filesystem. A simple `ls pennyfarthing-dist/workflows/` confirms they are gone. No stubs, no renames, no deprecation comments — hard delete.

**AC-2: Active sprint YAML stories with `workflow: tdd-tandem` are reassigned to `workflow: tdd`**

The grep over `sprint/` (excluding archive) shows zero active matches for `workflow: tdd-tandem`, `workflow: review-tandem`, or `workflow: bdd-tandem`. This AC passes vacuously — there are no active stories to reassign. No sprint YAML edits are needed. The archived references in `sprint/archive/` are historical records of completed work; they do not require updating.

**AC-3: Active sprint YAML stories with `workflow: review-tandem` or `workflow: bdd-tandem` are reassigned to `workflow: tdd`**

Same finding as AC-2 — zero active matches in non-archived sprint YAML. Passes vacuously.

**AC-4: `pf workflow list` does not show the deleted workflows**

After deletion, run `pf workflow list` (or inspect the workflows directory) and confirm `tdd-tandem`, `review-tandem`, and `bdd-tandem` are absent from the output. This is the observable verification that the deletions took effect and no other file is re-registering them.

## Assumptions

No cross-story assumptions within Epic 144.

Phase A (independent). This story has no dependencies on any other epic 144 story and no story in epic 144 depends on this story's output — except story 144-9, which updates `tdd.yaml`. Story 144-9 does not need the tandem files to be gone in order to do its work, but tandem removal should be complete before 144-9 ships to avoid a window where the new `tdd.yaml` is live alongside the old tandem alternatives.

Assumes no active stories are currently running on tandem workflows. The sprint grep confirms this — all tandem workflow references are in `sprint/archive/`. If a story were actively mid-flight on `tdd-tandem`, deletion could leave it in an inconsistent state. That situation does not exist here.

Story 144-9 depends on tandem removal being complete before updating `tdd.yaml`. The new TDD workflow is the only phased workflow operators should select; having `tdd-tandem` still visible in `pf workflow list` while 144-9 ships would create an ambiguous choice. Complete 144-8 before marking 144-9 as in-progress.
