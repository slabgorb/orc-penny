---
parent: context-epic-144.md
workflow: tdd
---

# Story 144-7: Create Architect Spec-Reconcile Phase and Gate

## Business Context

Every story in the current TDD pipeline ends with a Reviewer approval — but that approval doesn't answer the fundamental audit question: *does the final implementation match the spec, and is every departure from the spec documented?* TEA and Dev log deviations as they work, but their in-flight logs are working notes, not an authoritative manifest. Missing entries go undetected. The boss currently has to re-read specs and diff code to understand what actually changed.

This story delivers the Architect's **spec-reconcile phase** — a structured audit pass that runs after Reviewer, before SM finish. The Architect loads every available spec (story context, epic context, PRD references, sibling story ACs) alongside all in-flight deviation logs and produces the definitive deviation manifest. The `### Architect (reconcile)` subsection in `## Design Deviations` is what the boss reads. Everything else is working notes.

This is the auditive bookend to 144-6's preventive spec-check phase. Together they give the Architect two structured, gate-enforced roles in every TDD story: validate before coding starts, audit after the last review. Without 144-7, the pipeline has no final-authority audit step — deviation documentation is only as complete as the individual agents who wrote it.

**FR covered:** FR-5 (Architect Spec-Reconcile Phase)

## Technical Guardrails

### Key Files to Create

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/gates/spec-reconcile-pass.md` | New gate definition — checks for `### Architect (reconcile)` section existence in session file |
| `pennyfarthing-dist/agents/architect.md` | Modify — add `<spec-reconcile>` section describing phase behavior, context loading, and output format |

### Key Files to Read (Do Not Modify in This Story)

| File | What it provides |
|------|-----------------|
| `pennyfarthing-dist/agents/architect.md` | Existing Architect agent definition — add to it, don't replace existing sections |
| `pennyfarthing-dist/gates/spec-check-pass.md` | 144-6 gate — follow the same gate file structure for spec-reconcile-pass |
| `pennyfarthing-dist/gates/deviations-audited.md` | Existing gate — understand its structure before authoring spec-reconcile-pass |
| `pennyfarthing-dist/gates/deviations-logged.md` | Upgraded by 144-1 — understand format validation pattern the reconcile gate builds on |
| `pennyfarthing-dist/guides/deviation-format.md` | 144-1 deliverable — the 6-field format spec and subsection definitions Architect must use |
| `pennyfarthing-dist/schemas/gate-schema.md` | Gate file contract — gate output must conform to GATE_RESULT schema |
| `pennyfarthing-dist/schemas/session-schema.md` | Session file structure — reconcile section lives in `## Design Deviations` |

### Patterns to Follow

- **Gate file structure:** Follow `spec-check-pass.md` (144-6) as the direct model — same file structure, same GATE_RESULT contract, same fail-message format
- **Agent section style:** Follow the existing `<workflows>` section structure in `architect.md` — add `<spec-reconcile>` alongside existing workflow definitions, not replacing them
- **6-field deviation format:** Reconcile entries Architect adds go under `### Architect (reconcile)` using the exact same format as TEA and Dev entries (spec source, spec text, implementation, rationale, severity, forward impact)
- **Spec-check as predecessor:** The spec-check phase (144-6) established the pattern of Architect loading sibling story context and session archives. Reconcile follows the same loading approach but is retrospective rather than prospective
- **Result objects:** Return `{success, data?, error?}` — don't throw (SOUL principle 10)
- **Gate is advisory on findings, blocking on structure:** Gate passes when `### Architect (reconcile)` section exists (even if "No additional deviations found") — fails only when the section is absent entirely

### What NOT to Modify in This Story

- `pennyfarthing-dist/workflows/tdd.yaml` — wired in 144-9 only
- `pennyfarthing-dist/agents/tea.md` or `dev.md` — 144-2 owns those
- `pennyfarthing-dist/gates/deviations-logged.md` or `deviations-audited.md` — 144-1 owns those
- `pennyfarthing-dist/templates/context-schema.yaml` — 144-5 owns that
- Any existing Architect workflow sections — add new section, don't replace

## Scope Boundaries

**In scope:**
- New gate file: `pennyfarthing-dist/gates/spec-reconcile-pass.md`
  - Checks session file for `### Architect (reconcile)` subsection under `## Design Deviations`
  - Passes when section exists (even with "No additional deviations found")
  - Fails with: "Architect reconcile section required — run spec-reconcile phase"
  - Conforms to GATE_RESULT schema from `gate-schema.md`
- New `<spec-reconcile>` section in `pennyfarthing-dist/agents/architect.md`:
  - Phase trigger: activates after Reviewer exit, before SM finish
  - Context loading: story context, epic context, PRD references, sibling story ACs, all in-flight TEA/Dev deviation logs, AC deferral records from ac-completion gate
  - Work: review each existing deviation entry for accuracy and completeness; add missed entries under `### Architect (reconcile)`; verify AC deferral justifications remain accurate post-review
  - Output: `### Architect (reconcile)` section with entries or "No additional deviations found"
  - Gate trigger: `spec-reconcile-pass` resolves at phase exit

**Out of scope:**
- Wiring the reconcile phase into `tdd.yaml` (144-9)
- Changes to TEA, Dev, or Reviewer agent definitions (144-2, separate)
- Upgrading `deviations-logged` or `deviations-audited` gate format (144-1)
- Changes to `deviations-audited` gate behavior — Reviewer still runs that gate; reconcile is a separate, subsequent phase
- Tandem workflow removal (144-8)
- Context schema changes (144-5)
- Any implementation beyond gate file and architect.md section (Dev/TEA phases implement; Architect documents)

## AC Context

**AC 1: Architect loads full context on reconcile activation**

Given the Architect activates for spec-reconcile after Reviewer exits
When loading context
Then it reads: story context document, epic context document, all PRD references cited in the story context, sibling story ACs from sprint YAML, and all in-flight deviation logs from `### TEA (test design)` and `### Dev (implementation)` subsections.

Testable by: the `<spec-reconcile>` section in architect.md explicitly lists these context sources. The TEA agent definition (144-2 deliverable) and this story's gate require the subsections to exist.

Edge case: PRD references may not be linked from the story context — fall back to epic context's Planning Documents table if no explicit PRD reference is found in the story context.

**AC 2: Architect reviews each existing deviation entry for accuracy and completeness**

Given TEA and Dev logged N deviations during their phases
When the Architect reviews each entry
Then it confirms accuracy (spec text matches the actual spec, implementation description matches actual code) and completeness (all 6 fields present and substantive, not placeholder text).

Testable by: architect.md specifies review criteria: check that spec source is a real document path, spec text is a real quote, forward impact accurately reflects downstream stories. Architect annotates any inaccurate entry with a correction note rather than deleting it.

Edge case: If an existing entry is missing a field, Architect adds the missing field rather than flagging as a new deviation. The entry was logged correctly, just incompletely.

**AC 3: Architect adds missed deviations under `### Architect (reconcile)` with 6-field format**

Given the Architect finds a deviation TEA or Dev missed (e.g., a simplified cost model vs AC-6)
When documenting the finding
Then it adds the entry under `### Architect (reconcile)` using the full 6-field format defined in `deviation-format.md`.

Testable by: the `<spec-reconcile>` section in architect.md explicitly references `deviation-format.md` and specifies the `### Architect (reconcile)` subsection as the target. A test fixture with a known missed deviation confirms the entry appears under the correct subsection.

Edge case: If no missed deviations are found, the section still appears with: "No additional deviations found."

**AC 4: Architect verifies AC deferral justifications post-review**

Given the session file has AC deferrals logged by the ac-completion gate (from 144-3)
When the Architect reviews them
Then it verifies each deferral justification is still accurate post-review — i.e., the implementation didn't inadvertently complete or invalidate the deferred AC.

Testable by: architect.md instructs Architect to cross-reference the AC accountability table (written by ac-completion gate during Dev exit) against the Reviewer's findings. If a deferred AC was addressed during review, Architect notes the status change.

Edge case: If no ACs were deferred (all DONE or DESCOPED), this step is a no-op — architect.md should note this is conditional.

**AC 5: `spec-reconcile-pass` gate passes when `### Architect (reconcile)` section exists**

Given the Architect completed the reconcile pass and wrote the `### Architect (reconcile)` section
When the `spec-reconcile-pass` gate evaluates
Then it passes — regardless of whether the section contains entries or "No additional deviations found."

Testable by: gate file checks for the subsection string `### Architect (reconcile)` under `## Design Deviations` in the session file. Gate logic mirrors the structural check pattern from `spec-check-pass.md`.

Edge case: Section header exists but is empty (no content below it) — gate fails. The section must be non-empty: either at least one deviation entry or the explicit "No additional deviations found" statement.

**AC 6: `spec-reconcile-pass` gate fails with specific recovery message when section is absent**

Given the `### Architect (reconcile)` section is missing from the session file
When the `spec-reconcile-pass` gate evaluates
Then it fails with: "Architect reconcile section required — run spec-reconcile phase"
And the agent receives the message and knows exactly what to do to unblock.

Testable by: gate file defines the failure message verbatim. The GATE_RESULT block in the gate output includes `status: fail` and the recovery message.

**AC 7: Boss can audit the story from the session file alone after reconcile**

Given the completed reconcile manifest in `## Design Deviations` with three subsections (TEA, Dev, Architect)
When the boss reads the session archive
Then the Architect section is the definitive audit — each entry is self-contained, referencing the spec source document, the original spec text, what was implemented, why, severity, and forward impact on sibling stories. No external lookups required.

Testable by: architect.md specifies that entries must be self-contained (no "see above" or "see spec" — the spec text must be quoted inline). Review a completed session archive against this criterion.

## Assumptions

- Assumes 144-1 delivers the 6-field deviation format spec (`pennyfarthing-dist/guides/deviation-format.md`) and the `### TEA (test design)` / `### Dev (implementation)` / `### Architect (reconcile)` subsection convention — reconcile entries use the same format and the third subsection slot
- Assumes 144-2 delivers TEA and Dev agent definitions that produce properly formatted deviation entries with the `<deviation-logging>` section, so the Architect has structured in-flight logs to audit rather than freeform prose
- Assumes 144-6 delivers the `spec-check-pass` gate and the Architect spec-check phase definition — reconcile gate follows the same structural gate file pattern, and the `<spec-reconcile>` section in architect.md is a sibling to the `<spec-check>` section that 144-6 writes
- Assumes 144-3 delivers the ac-completion gate and the AC accountability table written to the session file — Architect's deferral justification review (AC 4) depends on that structured record existing
- Assumes Epic 143 native subagent infrastructure is available — the Architect spec-reconcile phase runs as a native subagent spawned by SM, using the spawn/prompt/result infrastructure from 143-1 through 143-8
