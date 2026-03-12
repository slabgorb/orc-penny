---
parent: context-epic-144.md
workflow: tdd
---

# Story 144-3: Create AC-Completion Gate

## Business Context

The TDD pipeline has no mechanism to ensure every acceptance criterion is accounted for at Dev exit. ACs can be silently dropped — not implemented, not deferred with justification, just gone — and the pipeline proceeds. The boss has no visibility until an external reviewer surfaces the gap after merge.

Story 144-3 fixes this with a **standalone composable gate** (`ac-completion`) that runs after Dev's GREEN phase. The gate reads ACs from the story context document, checks each one for status (DONE, DEFERRED, or DESCOPED), and blocks handoff if any AC is unaccounted for. DEFERRED and DESCOPED entries prompt the operator in real-time for approval — with the default action set to "complete it." The operator's approval or rejection is recorded in the session file.

The real-time approval loop is the key design point. Dev must justify each deferral. The operator reviews the justification and decides. Weak justifications get rejected and Dev goes back. This is the human-in-loop forcing function that prevents well-intentioned deferrals from becoming silent drops.

This gate is part of the "Gates Over Goodwill" philosophy from epic 144 — agents cannot be trusted to self-certify AC completion any more than they can be trusted to self-certify deviation documentation.

## Technical Guardrails

### Key Files to Create

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/gates/ac-completion.md` | Gate definition — reads ACs, checks status, prompts operator, logs accountability table |

### Existing Gates to Use as Structural Reference

| File | What it shows |
|------|---------------|
| `pennyfarthing-dist/gates/deviations-logged.md` | Argument block pattern, GATE_RESULT YAML format, pass/fail/recovery structure |
| `pennyfarthing-dist/gates/approval.md` | Operator prompt pattern, nested gate structure, check list format |

### Gate File Format

Gate files follow the XML tag schema defined in `pennyfarthing-dist/schemas/gate-schema.md`. Required tags:
- `<gate name="..." model="haiku">` — outer wrapper; use `haiku` (mechanical check)
- `<purpose>` — what the gate verifies and when it runs
- `<arguments>` — parameters the gate accepts (table format)
- `<pass>` — what the gate checks and what GATE_RESULT YAML to emit on success
- `<fail>` — how to diagnose failures and what GATE_RESULT YAML to emit with recovery steps

### GATE_RESULT Contract

All gate results emit a YAML block with this structure:
```yaml
GATE_RESULT:
  status: pass | fail
  gate: ac-completion
  message: "{summary}"
  checks:
    - name: "{check-name}"
      status: pass | fail
      detail: "{detail}"
  recovery:          # only on fail
    - "{action}"
```

### Context Document AC Format

The gate reads ACs from the story context document's `## AC Context` section. AC status is tracked in the session file — the gate must scan the session for each AC's status marker. Status markers in the session file follow this pattern:
- `DONE` — AC is implemented
- `DEFERRED {justification}` — AC is deferred with a reason
- `DESCOPED {justification}` — AC is descoped with a reason

### What NOT to Build

- Changes to `tdd.yaml` — wiring the gate into the workflow is story 144-9
- Changes to Dev agent definition — that is story 144-2
- Any deviation format validation — that is story 144-1
- A session state file or external artifact — all data lives in the session file (NFR-7)
- Timeout or auto-reject behavior — operator approval has no timeout by design

## Scope Boundaries

**In scope:**
- `pennyfarthing-dist/gates/ac-completion.md` gate definition
- Logic to read AC list from story context document's `## AC Context` section
- Logic to check each AC for DONE/DEFERRED/DESCOPED status in the session file
- Real-time operator prompt for each DEFERRED or DESCOPED AC (default action: "complete it")
- Session file log entry for each operator approval or rejection (including timestamp)
- Full AC accountability table emitted to session file on pass
- Gate failure with specific AC identifier when an AC has no status
- Idempotent behavior — re-running on the same session produces the same result (NFR-4)
- Composable design — gate works when referenced from any workflow phase (NFR-6)

**Out of scope:**
- Wiring this gate into `tdd.yaml` (story 144-9)
- Auto-approval or timeout behavior (human-in-loop by design)
- Deviation format validation (story 144-1)
- Architect spec-reconcile review of deferral justifications (story 144-7)
- Any UI or dashboard representation of AC status

## AC Context

### AC-1: Gate reads AC list from story context document

**Given** a story context document with 10 acceptance criteria in `## AC Context`
**When** the `ac-completion` gate runs after Dev's GREEN phase
**Then** it reads the AC list from the story context document
**And** it checks the session file for each AC's status

What "reads the AC list" means precisely: the gate must parse the ACs from `## AC Context` in the context document. ACs may be numbered (AC-1, AC-2, ...) or presented as `Given/When/Then` blocks. The gate needs to identify each discrete AC and correlate it to a status entry in the session file.

Edge case: story context document not found — gate fails with: "Story context document not found at {path}. ac-completion gate requires a context document."

Edge case: `## AC Context` section missing from context document — gate fails with: "No AC Context section found in story context. Cannot determine AC list."

### AC-2: All DONE ACs pass without operator prompt

**Given** all 10 ACs are marked DONE in the session file
**When** the gate evaluates
**Then** it passes with a full AC accountability table logged in the session

The accountability table must list every AC with its status. Format: a markdown table or bullet list in the session file, emitted by the gate. This creates the audit trail.

Pass behavior: emit GATE_RESULT with status: pass and include the accountability table. No operator interaction required when all ACs are DONE.

### AC-3: DEFERRED ACs prompt operator in real-time

**Given** AC-7 is marked `DEFERRED` with justification "Requires config infrastructure from Story 1.20"
**When** the gate evaluates AC-7
**Then** it prompts the operator in real-time: "AC-7 deferred: 'Requires config infrastructure from Story 1.20'. Default action: complete it. Approve deferral? [y/N]"

The default action is "complete it" — lowercase N is the default (reject). This forces the operator to actively choose to approve a deferral, not passively accept one.

The prompt must include: the AC identifier, the deferral justification as supplied by Dev, and the explicit default action.

### AC-4: Operator-approved deferral is logged in session

**Given** the operator approves the deferral
**When** the approval is recorded
**Then** the session file logs: AC-7 DEFERRED (operator-approved), justification, and timestamp

The session file entry must be written atomically before the gate proceeds to the next AC. The timestamp is ISO 8601 format.

Gate result on all approved: GATE_RESULT status: pass, with the full accountability table including approved deferrals.

### AC-5: Operator-rejected deferral fails the gate

**Given** the operator rejects the deferral (default action: "complete it")
**When** the rejection is recorded
**Then** the gate fails and Dev must address AC-7 before re-triggering

Gate fails immediately on first rejected deferral. Dev re-implements and re-triggers the gate. Gate is idempotent — re-running after fixing AC-7 evaluates from the current session state, not a cached prior run.

Recovery message: "AC-7 deferral rejected by operator. Implement AC-7 or provide stronger justification for deferral."

### AC-6: DESCOPED ACs also prompt operator for approval

**Given** AC-3 is marked `DESCOPED` with justification
**When** the gate evaluates AC-3
**Then** it prompts the operator for approval the same way as DEFERRED

DESCOPED is treated identically to DEFERRED for approval purposes. The operator must explicitly approve removal of scope. Same prompt format, same logging, same default-to-reject behavior.

### AC-7: Unstatused ACs fail the gate with specific identifier

**Given** AC-5 has no status (not marked DONE, DEFERRED, or DESCOPED)
**When** the gate evaluates
**Then** it fails with: "AC-5 has no status. Mark as DONE, DEFERRED, or DESCOPED."

The gate fails on the first unstatused AC it encounters. The failure message names the specific AC so Dev knows exactly what to address. Recovery message should also include the three valid status options and their syntax.

Edge case: AC exists in context document but is not mentioned anywhere in the session file — treat as "no status," fail with the same specific message.

### AC-8: Gate is composable — works standalone from any workflow phase

**Given** the `ac-completion` gate definition
**When** referenced from any workflow phase (not just dev-exit)
**Then** it works standalone — composable, not coupled to a specific phase

The gate must accept `CONTEXT_FILE` and `SESSION_FILE` as arguments (following the pattern in `deviations-logged.md`). It must not hard-code any assumption about which phase triggered it or which agent is active. This satisfies NFR-6 (composable gate contracts).

## Assumptions

- Assumes story 144-5 (Add Assumptions section to context schema) will update the schema independently — this gate does not depend on the Assumptions section being present or validated.
- Assumes the story context document follows the existing context schema format (`## AC Context` section containing individual ACs). The gate reads from this section; malformed or missing sections produce gate failures described in AC-1.
- Assumes no dependency on 144-1's deviation format — the ac-completion gate is independent of deviation entry structure. It checks AC status, not deviation fields.
- Assumes the operator is present at Dev exit — real-time prompts for DEFERRED/DESCOPED ACs are blocking with no timeout. This is by design per the PRD (human-in-loop is expected).
- Assumes the session file is the single coordination artifact — the gate writes approval records into the session file, not an external state file (NFR-7).
- No cross-story assumptions. This is a standalone gate with no runtime dependency on other 144 stories' outputs.
