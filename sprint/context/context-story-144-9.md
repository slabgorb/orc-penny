---
parent: context-epic-144.md
workflow: trivial
---

# Story 144-9: Update TDD Workflow with New Phases and Gates

## Business Context

This is the capstone story for Epic 144. Every prior story in this epic delivers an individual piece — a gate file, a phase agent, an agent definition update — but none of them individually changes what the pipeline does. Story 144-9 is the moment those pieces become a system: `tdd.yaml` is updated, all gates are wired, and the full 8-phase spec-fidelity pipeline goes live.

The problem being solved is pipeline trust. External reviewers have repeatedly surfaced findings the internal pipeline missed (PR #50: 13+6 findings; PR #52: 8 findings). The root cause was structural — agents could hand off without documenting deviations, ACs could silently drop, and there was no phase validating spec alignment before coding started or after review. The boss had no single readable artifact to audit without re-reading the spec himself.

After this story lands, the TDD workflow enforces spec fidelity at every handoff: Architect validates assumptions before RED, gate-blocked deviation logging at TEA and Dev exit, AC accountability with operator approval at Dev exit, deviation audit at Reviewer exit, and Architect produces the definitive manifest after review. The session file becomes the audit artifact it was always supposed to be.

The workflow goes from 6 phases to 8:

```
SM (setup) → Architect (spec-check) → TEA (red) → Dev (green) → TEA (verify) → Reviewer → Architect (spec-reconcile) → SM (finish)
```

## Technical Guardrails

**File to modify:** `pennyfarthing-dist/workflows/tdd.yaml` — the single source of truth for the TDD workflow definition.

**Do not modify:**
- Any gate files (`pennyfarthing-dist/gates/`) — these were delivered by earlier stories (144-1, 144-3, 144-6, 144-7) and must be consumed as-is
- Agent definitions — delivered by 144-2
- `context-schema.yaml` — delivered by 144-5
- Any other workflow file — only `tdd.yaml` is in scope

**Version bump required:** The workflow version must be incremented. The current version is `"1.0.0"`. Use `"2.0.0"` — this is a breaking structural change (two new phases, all gates wired), not a patch.

**Gate references must match filenames exactly.** The gate `file:` field in tdd.yaml references files relative to the workflow root. The existing pattern is `gates/<name>` (no extension). Follow this pattern for all new gate references.

**Existing gate patterns from the current tdd.yaml to preserve:**
- `gate` (exit gate on a phase) and `entry_gate` (entry gate before a phase begins) are both valid fields — use the right one per phase
- Gate objects contain `file:`, `type:`, `condition:`, and optionally `recovery:` fields
- The `team:` block on verify (simplify teammates) is controlled by the 144-4 `simplify_enabled` toggle — preserve the team block as-is; the toggle logic lives in repos.yaml, not here

**Gate wiring per phase (from PRD FR-9 and Gate Architecture table):**

| Phase | Agent | Exit Gate(s) |
|-------|-------|--------------|
| setup | sm | `sm-setup-exit` (existing) |
| spec-check | architect | `spec-check-pass` (new, from 144-6) |
| red | tea | `tests-fail` (existing) + `deviations-logged` (existing, now wired) |
| green | dev | `dev-exit` (existing) + `deviations-logged` (existing) + `ac-completion` (new, from 144-3) |
| verify | tea | `quality-pass` (existing) |
| review | reviewer | `approval` (existing) + `deviations-audited` (existing, now wired) |
| reconcile | architect | `spec-reconcile-pass` (new, from 144-7) |
| finish | sm | (no exit gate — terminal phase) |

The existing `entry_gate` on the red phase (`tea-context` gate) and the `entry_gate` on review and finish (`status-sync`) should be preserved unchanged.

**No backward-compatibility shim.** The PRD is explicit: clean cut, no migration layer. Any stories still using `tdd-tandem` were reassigned by 144-8. The version bump communicates the breaking change.

## Scope Boundaries

**In scope:**
- Modify `pennyfarthing-dist/workflows/tdd.yaml` to add spec-check and reconcile phases with their agents, inputs, outputs, and gates
- Wire all previously unwired gates (`deviations-logged`, `deviations-audited`) into their correct phases
- Add new gate references for `spec-check-pass`, `ac-completion`, and `spec-reconcile-pass`
- Bump version from `"1.0.0"` to `"2.0.0"`
- Verify `pf workflow show tdd` displays all 8 phases correctly after the edit

**Out of scope:**
- Writing or modifying any gate files — those are done
- Modifying any agent definitions — done in 144-2
- Modifying `bdd.yaml` or any other workflow — TDD only
- Redesigning the tandem pattern — explicitly deferred to a future epic (144-8 deleted tandem files, no replacement here)
- Changing the `triggers:` block — the routing rules (`min: 3 points`, `default: true`) do not change
- Changing the simplify `team:` block on the verify phase — that block is correct as-is; the toggle behavior is in repos.yaml (144-4)

## AC Context

**AC: 8 phases in order — setup, spec-check, red, green, verify, review, reconcile, finish**

The YAML `phases:` array must have exactly 8 entries in this sequence. The workflow engine processes phases in declaration order. Inserting spec-check as index 1 (after setup) and reconcile as index 6 (after review, before finish) is the structural change. Each phase needs `name:`, `agent:`, and appropriate `input:`/`output:` arrays for context threading.

- spec-check inputs: `[session_file, story_context]`; outputs: `[spec_check_findings]`
- reconcile inputs: `[approval, spec_check_findings]`; outputs: `[deviation_manifest, archived_session, story_summary]`

**AC: spec-check phase references `spec-check-pass` gate**

The exit gate on the spec-check phase must reference `spec-check-pass`. The gate is advisory (passes even with broken assumptions found, fails only if story context is missing or Assumptions section absent — that logic is in the gate file itself). The workflow just wires it.

Expected YAML shape:
```yaml
- name: spec-check
  agent: architect
  input: [session_file, story_context]
  output: [spec_check_findings]
  gate:
    file: gates/spec-check-pass
    type: spec_check_pass
    condition: Story context with Assumptions section validated before RED phase
```

**AC: red phase references `deviations-logged`**

The existing red phase has a `tests-fail` exit gate and a `tea-context` entry gate. The `deviations-logged` gate must be added as an additional exit gate. The workflow schema supports multiple gates per phase — check how the existing workflow structures this if multiple gates are needed (may require a `gates:` array rather than a single `gate:` key — review tdd.yaml current structure and follow the existing pattern).

**AC: green phase references `deviations-logged` and `ac-completion`**

Two gates on dev exit. Same multiple-gate pattern as red. The `ac-completion` gate is standalone and composable — it reads the story context AC list independently. Wire it alongside `deviations-logged` and the existing `dev-exit` gate.

**AC: review phase references `deviations-audited`**

The existing review phase has an `approval` exit gate and a `status-sync` entry gate. Add `deviations-audited` as an additional exit gate. The Reviewer cannot exit review until both approval and deviation audit are complete.

**AC: reconcile phase references `spec-reconcile-pass`**

New phase, new gate. The reconcile phase is the Architect's final pass — it runs after reviewer approval and before SM finish. Gate passes when the `### Architect (reconcile)` subsection exists in `## Design Deviations`.

**AC: version bump**

Change `version: "1.0.0"` to `version: "2.0.0"`. The comment block at the top of tdd.yaml should be updated to reflect the new flow description: `# Flow: SM → Architect (spec-check) → TEA → Dev → TEA (verify) → Reviewer → Architect (spec-reconcile) → SM`.

**AC: `pf workflow show tdd` displays all 8 phases**

After editing, run `pf workflow show tdd` and confirm all 8 phase names appear with their agents and gates. This is the acceptance smoke test — it validates the YAML parses cleanly against the workflow loader.

## Assumptions

- Assumes 144-1 delivers the upgraded `deviations-logged` gate at `pennyfarthing-dist/gates/deviations-logged.md` with 6-field format validation (wiring it into red and green phases here will invoke the upgraded validator, not the old existence-check version)
- Assumes 144-3 delivers the `ac-completion` gate at `pennyfarthing-dist/gates/ac-completion.md` as a standalone composable gate before this story begins
- Assumes 144-6 delivers the `spec-check-pass` gate at `pennyfarthing-dist/gates/spec-check-pass.md` before this story begins
- Assumes 144-7 delivers the `spec-reconcile-pass` gate at `pennyfarthing-dist/gates/spec-reconcile-pass.md` before this story begins
- Assumes 144-8 has deleted `tdd-tandem.yaml`, `review-tandem.yaml`, and `bdd-tandem.yaml` — tdd.yaml is the only active TDD workflow and editing it is a clean operation with no tandem entanglements
- Assumes all new gate files exist at `pennyfarthing-dist/gates/` before this story wires them into the workflow — this story does not create gate files, only references them
- Assumes `deviations-audited.md` already exists at `pennyfarthing-dist/gates/deviations-audited.md` (it existed before this epic, just unwired) — no file creation needed, just the wire-in
- Assumes the workflow YAML schema (as documented in `pennyfarthing-dist/schemas/workflow-schema.md`) supports the gate structure patterns already present in tdd.yaml — no schema changes required
