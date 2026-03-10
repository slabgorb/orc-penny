---
parent: context-epic-142.md
workflow: trivial
---

# Story 142-1: ADR and Comparison Methodology

## Business Context

This is the foundational story for the entire BMAD vs Pennyfarthing comparison. Without a documented, defensible methodology, any benchmark results can be dismissed as cherry-picked or biased. The ADR establishes the rules of engagement before any code is written or any runs are executed.

The audience is engineering leadership — people who approved BMAD and need to see that any counter-proposal is grounded in rigorous, fair methodology. The ADR must survive adversarial review: "Did you give BMAD a fair shot?"

## Technical Guardrails

- **Output:** `docs/adr/` with sequential numbering (next available number)
- **Format:** Standard ADR format (Context, Decision, Consequences) with additional appendices for context diff audit
- **BMAD source:** Reference files at `/Users/keithavery/Projects/BMAD-METHOD/` — pin to a specific commit hash for reproducibility
- **No code changes:** This is a documentation-only story in the orchestrator repo
- **Reference existing PRD:** The comparison PRD at `sprint/planning/bmad-comparison-prd.md` contains the technical architecture and fairness decisions — the ADR documents these decisions formally

### Key BMAD Files to Reference

| File | Purpose |
|------|---------|
| `src/bmm/agents/dev.agent.yaml` | "Amelia" persona definition |
| `src/bmm/workflows/4-implementation/dev-story/instructions.xml` | 10-step dev workflow |
| `src/bmm/workflows/4-implementation/dev-story/checklist.md` | Definition of Done |
| `src/bmm/workflows/4-implementation/code-review/instructions.xml` | 5-step adversarial review |
| `src/bmm/workflows/4-implementation/code-review/checklist.md` | Review checklist |

## Scope Boundaries

**In scope:**
- ADR documenting comparison methodology, fairness principles, and all translation decisions
- Context parity analysis: side-by-side of what each agent receives
- Phase mapping rationale (BMAD 2-phase vs PF 3-phase) documented as known asymmetry
- Controlled variables documented (same model, same scenario, same judge, same ground truth)
- BMAD commit hash pinned for reproducibility
- Runbook outline for how to execute comparison runs

**Out of scope:**
- BMAD simulator code (story 142-2)
- Pipeline replay adapter code (story 142-3)
- Actual context diff from real runs (story 142-4 — requires completed runs)
- Running any benchmarks (story 142-5)
- Statistical analysis (story 142-6)

## AC Context

### AC1: ADR documents BMAD source files and rationale

The ADR must list every BMAD file used in the simulator, explain WHY that file was chosen, and confirm it represents what a real BMAD dev agent would see. Must include the BMAD repo commit hash.

**Testable:** ADR contains a "BMAD Source Files" section with file paths, purposes, and a pinned commit hash.

### AC2: Context parity analysis with side-by-side appendix

An appendix showing two columns: what PF's dev agent receives (CLAUDE.md sections) vs what BMAD's dev agent will receive. Each difference annotated with rationale (e.g., "PF includes sidecars — legitimate framework advantage, not unfair addition").

**Testable:** ADR contains an appendix with a comparison table. Every row has a rationale annotation. No unexplained differences.

### AC3: Phase mapping documented as known asymmetry

BMAD's 2-phase (Dev->Reviewer) vs PF's 3-phase (TEA->Dev->Reviewer) must be documented as a design decision, not a flaw. The detection heatmap will reveal whether PF's phase separation adds value.

**Testable:** ADR contains a "Phase Mapping" section that explicitly calls this an asymmetry, explains why it's fair, and notes the heatmap will quantify the impact.

### AC4: Controlled variables documented

Same model (Opus), same scenarios (DPGD-116, DPGD-117), same judge, same ground truth. Any variable that differs between pipelines must be explicitly listed and justified.

**Testable:** ADR contains a "Controlled Variables" table with variable name, value, and rationale for any differences.

### AC5: Story file translation decisions documented

How PF scenario context maps to BMAD story file format. Either document that axiathon context IS the BMAD create-story output (with evidence), or document each translation choice.

**Testable:** ADR contains a "Story File Translation" section with specific mapping decisions and rationale.
