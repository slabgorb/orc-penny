---
parent: context-epic-144.md
workflow: tdd
---

# Story 144-6: Create Architect Spec-Check Phase and Gate

## Business Context

The current TDD pipeline has no forward-looking spec validation. TEA writes tests based on story context assumptions about sibling stories — but if a completed sibling story deviated from its spec, those assumptions may already be wrong before a single test is written. The result: TEA writes tests against an outdated interface, Dev implements against those tests, and the mismatch isn't caught until external review (or not at all).

Story 144-6 fixes the earliest failure point in the pipeline: the gap between SM setup and TEA's first test. The Architect activates as a new spec-check phase, reads the story's declared assumptions, cross-references them against completed sibling stories' deviation manifests and sprint YAML ACs, and surfaces any broken or at-risk assumptions before testing begins.

This is the preventive half of the Architect's bookend design (see 144-7 for the auditive half). The boss doesn't need to red-flag the pipeline retroactively — the Architect flags conflicts before coding starts.

**FR:** FR-4 (Architect Spec-Check Phase)

**Value delivered:** TEA enters the RED phase knowing whether its assumptions are still valid. Broken assumptions become documented findings, not silent sources of test debt.

## Technical Guardrails

### Key Files to Create

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/gates/spec-check-pass.md` | New gate definition — spec-check phase exit gate |
| `pennyfarthing-dist/agents/architect.md` | Add `<spec-check>` phase workflow to existing Architect definition |

### Key Files to Read (Do Not Modify)

| File | Why |
|------|-----|
| `pennyfarthing-dist/agents/architect.md` | Existing Architect definition — add spec-check workflow, do not restructure |
| `pennyfarthing-dist/gates/deviations-logged.md` | Gate structural reference — `spec-check-pass` follows same `<gate>` XML schema |
| `pennyfarthing-dist/schemas/gate-schema.md` | Gate file format and GATE_RESULT contract |
| `pennyfarthing-dist/guides/gates.md` | Gate behavior patterns |

### Patterns to Follow

- **Gate file structure:** Follow the `<gate name="..." model="haiku">` XML pattern from `deviations-logged.md`. Gate has `<purpose>`, `<arguments>`, `<pass>`, and `<fail>` sections. GATE_RESULT is a YAML block.
- **Agent definition structure:** Existing Architect definition uses `<workflows>` with numbered workflow sections. Add spec-check as a new numbered workflow — do not restructure existing workflows.
- **Graceful degradation (NFR-3):** When sibling story context documents are missing, fall back to story titles and ACs from sprint YAML. Log the fallback as a finding, not a crash.
- **Advisory gate (not blocking):** The `spec-check-pass` gate passes when findings are documented — broken assumptions are surfaced but do not block. The gate only fails when the story context is missing entirely or the `## Assumptions` section is absent.
- **Model:** Gate runs on Haiku (mechanical check). Architect spec-check analysis is Opus (strategic reasoning).
- **No implementation code:** Architect reads, analyzes, and documents. Never modifies source files.

### Dependencies and Integration Points

- **144-5 (Assumptions section in context schema):** The `## Assumptions` section must exist in the context schema before Architect can anchor on it. This story assumes 144-5 is done.
- **144-1 (Deviation format spec):** Architect reads completed sibling stories' deviation manifests. The manifests must exist in the 6-field structured format for Architect to cross-reference assumptions. This story assumes 144-1 is done.
- **144-2 (TEA/Dev agent definitions):** TEA must know to read Architect spec-check output before writing tests. This story adds a `<spec-check>` workflow to the Architect definition; 144-2 adds the corresponding `<spec-check-input>` guidance to TEA. This story assumes 144-2 is done.
- **Epic 143 (Native Subagent Migration):** Architect runs as a native subagent in the spec-check phase. Epic 143 stories (143-1 through 143-8, all complete) provide the spawning infrastructure. This story does not add new subagent infrastructure — it uses what Epic 143 delivered.
- **144-9 (TDD workflow update):** This story delivers the gate definition and Architect workflow. Wiring the gate into `tdd.yaml` between setup and RED is 144-9's responsibility. This story does not touch `tdd.yaml`.

### What NOT to Touch

- `pennyfarthing-dist/workflows/tdd.yaml` — phase wiring is 144-9's scope
- `pennyfarthing-dist/agents/tea.md` — TEA's spec-check input instructions are 144-2's scope
- `pennyfarthing-dist/agents/dev.md` — Dev's deviation-logging section is 144-2's scope
- `pennyfarthing-dist/gates/deviations-logged.md` — format validation upgrade is 144-1's scope
- `pennyfarthing-dist/schemas/context-schema.yaml` — Assumptions section addition is 144-5's scope

## Scope Boundaries

**In scope:**
- New gate file: `pennyfarthing-dist/gates/spec-check-pass.md` with full gate contract (purpose, arguments, pass/fail conditions, GATE_RESULT blocks)
- Add spec-check phase workflow to `pennyfarthing-dist/agents/architect.md` — the inputs Architect loads, validation logic, output format written to session file, and handoff signal to TEA
- Gate logic: pass when findings are documented; fail when story context is missing or `## Assumptions` section is absent
- Fallback behavior: when sibling story context is missing, fall back to story titles + ACs from sprint YAML and log the fallback

**Out of scope:**
- Wiring `spec-check-pass` into `tdd.yaml` (144-9)
- TEA's instructions for reading spec-check output (144-2)
- The `## Assumptions` section in the context schema (144-5)
- The 6-field deviation format specification (144-1)
- Architect spec-reconcile phase and `spec-reconcile-pass` gate (144-7)
- Any subagent infrastructure (Epic 143)

## AC Context

### AC-1: Architect loads the correct context set on activation

**Given** the Architect activates for the spec-check phase on story 5-2
**When** loading context
**Then** it reads: story 5-2 context (including `## Assumptions`), epic context, sibling story ACs from sprint YAML, and prior sibling session archives

**What this means in practice:**
- "Story context including `## Assumptions`" — the full `sprint/context/context-story-{id}.md` for the current story, not just the sprint YAML entry. The `## Assumptions` section (added by 144-5) is the structural anchor.
- "Sibling story ACs from sprint YAML" — all stories in the same epic, read from `current-sprint.yaml` and the relevant `epic-{N}.yaml` shard. Fallback when context docs are missing.
- "Prior sibling session archives" — completed stories' `sprint/archive/{id}-session.md` files. This is where deviation manifests live. Architect reads the `## Design Deviations` section of each.
- Architect does not need to load context for in-progress or not-yet-started sibling stories — only completed ones have reliable session archives to cross-reference against.

**Test for this AC:** The `<spec-check>` workflow section in `architect.md` lists exactly these four inputs. A reviewer reading the definition can verify the inputs without running the agent.

### AC-2: Broken assumptions are flagged with structured output

**Given** story 5-2 assumes "5-1 delivers `Regex { pattern: String, flags: String }`"
**And** story 5-1's session archive shows a deviation: Regex flattened to `Regex(String)`
**When** the Architect compares assumptions against deviations
**Then** it flags the assumption as **broken** with: story ID, assumption text, actual implementation from deviation manifest

**What "structured output" means:**
The Architect writes spec-check findings to the session file under a `## Spec-Check Findings` section (or equivalent). Each finding must include:
- Assumption text (quoted from the `## Assumptions` section)
- Source sibling story ID
- Status: `VALIDATED` | `BROKEN` | `UNVERIFIABLE` (no session archive available)
- For BROKEN: the actual implementation drawn from the sibling's deviation manifest
- For UNVERIFIABLE: the fallback source used (sprint YAML ACs or story title only)

This structured output is what TEA reads before writing tests. It must be machine-scannable — no prose-only findings blocks.

### AC-3: Missing sibling context triggers graceful degradation, not failure

**Given** story 5-2 assumes something about story 5-3 which has no context document
**When** the Architect attempts to validate
**Then** it falls back to story 5-3's title and ACs from sprint YAML
**And** logs: "Story 5-3 context document not found — validated against sprint YAML only"

**Edge cases to handle:**
- Sibling has no context document AND no session archive: validate against sprint YAML ACs only. Mark assumption as `UNVERIFIABLE`.
- Sibling has a session archive but no `## Design Deviations` section: note absence, cannot confirm or deny. Mark `UNVERIFIABLE`.
- Sibling has a session archive with "No deviations from spec." — mark assumption as `VALIDATED` (no deviation means the spec was followed as declared).
- Sprint YAML has no story with the referenced ID: log as finding, do not crash.

**NFR-3 compliance:** Missing context is a logged finding, not a gate failure. The gate passes with findings documented.

### AC-4: Gate passes with findings documented, fails only on missing context or absent Assumptions

**Given** the Architect completes spec-check with 2 broken assumptions and 1 validated
**When** the `spec-check-pass` gate evaluates
**Then** it passes — findings are documented, not blocking (spec-check is advisory)

**Given** the story context document is missing entirely
**When** the `spec-check-pass` gate evaluates
**Then** it fails: "Story context document required for spec-check"

**Given** the story context exists but `## Assumptions` section is absent
**When** the `spec-check-pass` gate evaluates
**Then** it fails: "Assumptions section required in story context"

**Gate contract design:**
The `spec-check-pass` gate is a structural check, not a content judgment. It verifies:
1. Story context document exists at `sprint/context/context-story-{id}.md`
2. `## Assumptions` section is present and non-empty (or explicitly "No cross-story assumptions")
3. Spec-check findings are recorded in the session file (the Architect ran and wrote output)

The gate does NOT evaluate whether the Architect's findings are correct or complete — that is Architect judgment, not a mechanical gate check.

**GATE_RESULT shape on pass:**
```yaml
GATE_RESULT:
  status: pass
  gate: spec-check-pass
  message: "Spec-check complete — {N} assumptions validated, {M} broken, {K} unverifiable"
  checks:
    - name: context-exists
      status: pass
    - name: assumptions-section
      status: pass
    - name: findings-recorded
      status: pass
```

**GATE_RESULT shape on fail:**
```yaml
GATE_RESULT:
  status: fail
  gate: spec-check-pass
  message: "{specific failure reason}"
  checks:
    - name: context-exists
      status: fail
      detail: "Story context document not found at sprint/context/context-story-{id}.md"
  recovery:
    - "Create story context document with ## Assumptions section before running spec-check"
```

### AC-5: TEA reads Architect findings before writing tests

**Given** the Architect produces spec-check findings
**When** TEA activates for the RED phase next
**Then** TEA reads the Architect's findings and adjusts test design accordingly

**What this story delivers for this AC:**
This story ensures the Architect's output is in a documented, readable location in the session file. The `<spec-check>` workflow in `architect.md` must specify WHERE findings are written (session file section name/heading) so TEA knows where to look.

The reciprocal — TEA's `<spec-check-input>` instructions telling TEA to read that section — is 144-2's scope. This story sets the contract; 144-2 fulfills it on the TEA side.

**Testable check:** The `<spec-check>` workflow in `architect.md` names the session file section where findings are recorded. A reviewer can confirm TEA will know where to find it (assuming 144-2 correctly references the same section name).

## Assumptions

- Assumes 144-5 delivers the `## Assumptions` section in the story context schema. Without the schema addition, the gate's check for `## Assumptions` presence has no authoritative spec to reference.
- Assumes 144-1 delivers the deviation format spec (`pennyfarthing-dist/guides/deviation-format.md`) and the 6-field structured format. The Architect reads sibling stories' deviation manifests to find broken assumptions — the manifests must exist in structured format for cross-referencing to work.
- Assumes 144-2 delivers updated TEA agent definition with instructions to read spec-check output from the session file. This story names the output location; TEA's ability to consume it depends on 144-2.
- Assumes Epic 143 native subagent infrastructure is available for Architect to run as a subagent in the spec-check phase. Stories 143-1 through 143-8 are confirmed complete per epic context.
