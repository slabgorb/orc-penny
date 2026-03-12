---
parent: context-epic-141.md
workflow: trivial
---

# Story 141-14: Improve agent handoff command documentation and examples

## Business Context

The handoff CLI is the critical path for every agent phase transition in the system. Agents that misuse it — passing agent names instead of phase names to `complete-phase`, omitting the assessment before gated transitions, or not checking the `relay: true` flag in marker output — cause broken sessions that require manual repair. The existing `guides/handoff-cli.md` covers the happy path but leaves out the `phase-check` command entirely, does not explain the full `RESOLVE_RESULT` output shape (including `next_agent`, `next_phase`, `gate_type` fields), and has no examples of common failure cases or the assessment guard that `complete-phase` enforces. Improving this documentation directly reduces agent errors and session-repair toil.

## Technical Guardrails

**Primary doc to update:**
- `pennyfarthing/pennyfarthing-dist/guides/handoff-cli.md` — the guide agents load at runtime. Edit the source here, not the symlink at `.pennyfarthing/guides/handoff-cli.md`.

**Source files to read before editing (do not modify):**
- `pennyfarthing/pennyfarthing-dist/src/pf/handoff/cli.py` — authoritative command signatures, including the undocumented `phase-check` command
- `pennyfarthing/pennyfarthing-dist/src/pf/handoff/resolve_gate.py` — full `RESOLVE_RESULT` dict shape (includes `next_agent`, `next_phase`, `gate_type`, `assessment_found`, `error` fields not shown in the current guide)
- `pennyfarthing/pennyfarthing-dist/src/pf/handoff/complete_phase.py` — assessment guard logic (gate_type not in `("skip", "manual", "-", None, "")` requires `## Assessment` section) and atomic write behavior; also handles tandem config updates on the session file
- `pennyfarthing/pennyfarthing-dist/src/pf/handoff/marker.py` — context-percent threshold logic (60% triggers warning), relay-off vs relay-on output difference, `--error` flag behavior
- `pennyfarthing/pennyfarthing-dist/src/pf/handoff/phase_check.py` — `PHASE_CHECK` output shape: `{action, agent, story_id, phase, phase_owner, message}`
- `pennyfarthing/pennyfarthing-dist/src/pf/handoff/gate_runner.py` — how gate files are parsed (reads `<gate name="..." model="...">` tag); default-deny if `GATE_RESULT` is missing
- `pennyfarthing/pennyfarthing-dist/guides/gates.md` — cross-referenced guide; keep cross-references consistent

**Related agent file:**
- `pennyfarthing/pennyfarthing-dist/guides/agent-behavior.md` — contains the one-paragraph handoff summary that agents see in their critical context; the guide and agent-behavior.md should be consistent

**Symlink rule:** `.pennyfarthing/guides/handoff-cli.md` is a symlink. Edit the source at `pennyfarthing/pennyfarthing-dist/guides/handoff-cli.md`. Changes appear in both locations automatically.

**No Python changes.** This story is documentation only. Do not modify any `.py` files.

## Scope Boundaries

**In scope:**
- Add the missing `phase-check` command section to `guides/handoff-cli.md`, documenting its signature, arguments, and `PHASE_CHECK` output shape
- Expand the `resolve-gate` section to show the full `RESOLVE_RESULT` output shape, including the `next_agent`, `next_phase`, `gate_type`, `assessment_found`, and `error` fields that the current doc omits
- Expand the `complete-phase` section to document the assessment guard: gated transitions (any gate_type other than `skip`, `manual`, `-`, or empty) require a `## Assessment` section in the session file, or the command returns `status: error`
- Document the context-percent behavior in the `marker` command: when context usage is at or above 60%, the fallback message includes a `/clear` recommendation
- Add a concrete worked example for the full exit protocol sequence showing all four commands in order with realistic argument values (e.g., story `141-14`, workflow `trivial`, phase `implement`)
- Add a common errors or troubleshooting subsection covering: passing an agent name instead of a phase name to `complete-phase` (the auto-correction behavior), calling `complete-phase` before writing the assessment (the error response), and what happens when `resolve-gate` returns `status: error` (workflow YAML not found or phase not found)
- Keep cross-references to `guides/gates.md` and `guides/agent-behavior.md` accurate

**Out of scope:**
- Modifying any Python source files in `src/pf/handoff/`
- Changing the `gates.md` guide (except to verify cross-references are still accurate)
- Documenting the gate recovery system (`gate_recovery.py` / `recovery:` block in workflow YAML) — that is a separate concern documented elsewhere
- Updating agent definition files (`.md` files in `agents/`) beyond verifying consistency with `agent-behavior.md`
- Adding new commands or changing CLI behavior

## AC Context

This story has no explicit ACs. The following are the concrete testable outcomes derived from the scope:

**AC1: `phase-check` command is documented**
The guide must include a `### phase-check` section with the command signature (`pf handoff phase-check AGENT`), the `PHASE_CHECK` output YAML block showing all fields (`action`, `agent`, `story_id`, `phase`, `phase_owner`, `message`), and an explanation of the two possible `action` values: `start` (proceed) and `redirect` (wrong agent — a handoff marker is also emitted). The section must clarify that `phase-check` is called at agent entry, not exit.

**AC2: `resolve-gate` output shape is complete**
The `RESOLVE_RESULT` YAML example in the guide must show all fields returned by `resolve_gate.py`: `status`, `gate_type`, `gate_file`, `next_agent`, `next_phase`, `assessment_found`, and `error`. The current guide shows only `status`, `gate_file`, and `reason`. The status table must also include `error` as a possible status value (workflow or phase not found).

**AC3: `complete-phase` assessment guard is documented**
The `complete-phase` section must state: "If `GATE_TYPE` is anything other than `skip`, `manual`, `-`, or empty, the command checks that the session file contains a `## Assessment` heading. If no assessment is found, it returns `COMPLETE_RESULT` with `status: error` and an error message. Write your assessment to the session file before calling `complete-phase` on gated transitions." The `COMPLETE_RESULT` example must include the `session_file` field (currently absent from the doc).

**AC4: `marker` context-percent behavior is documented**
The `marker` section must note that when context usage is at or above 60%, the `fallback` string includes a `/clear before continuing` recommendation, and that if context cannot be read the percent is reported as `unknown`. The existing relay-on/relay-off distinction is already documented correctly; no change needed there.

**AC5: Full worked example exists**
The guide must include a worked example section showing all four handoff commands in sequence for a realistic scenario. The example must use concrete values (e.g., story `141-14`, workflow `trivial`, phase `implement`, next phase implied by workflow). It must show the actual output blocks (`RESOLVE_RESULT`, `COMPLETE_RESULT`, `AGENT_COMMAND`) so agents know what to expect at each step.

**AC6: Common errors section exists**
The guide must include a troubleshooting or common errors section covering at least: (1) agent name passed as phase name — note that `complete-phase` auto-corrects this by resolving against the workflow YAML, but agents should use phase names explicitly to avoid ambiguity; (2) missing assessment for gated transition — the error response and the fix; (3) `resolve-gate` returns `status: error` — how to diagnose (workflow name wrong, phase name wrong, workflow YAML not found at `.pennyfarthing/workflows/`).

**AC7: Cross-references are consistent**
The footer `Related:` block in the guide must reference both `guides/gates.md` and `guides/agent-behavior.md`. The one-line handoff summary in `guides/agent-behavior.md` must remain consistent with the protocol described in the guide (no changes required if it already matches; verify only).
