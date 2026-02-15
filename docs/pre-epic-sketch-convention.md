# Pre-Epic Sketch Convention

**Date:** 2026-02-15
**Origin:** Observed during poller-orchestrator OCSF architecture phase
**Relates to:** Lifecycle Composition Initiative (lifecycle-improvement-rs.md, Gap #6: no feedback artifact)

---

## The Observation

During the stepped workflow sequence (PRD → Architecture → Epics & Stories → Sprint Planning), earlier phases naturally produce forward-looking artifacts that formally belong to later phases. The architect sketches stories while designing the system. The PM hints at sprint priorities while writing the PRD. This is healthy — it captures context at the moment it's freshest.

But the current BikeLane lifecycle treats each phase's output as canonical. When the architect writes stories in the architecture document, those stories look identical to stories produced by the formal `create-epics-and-stories` workflow. The SM has no signal that these are sketches vs approved work items.

## The Problem

```
Architecture phase               Epics & Stories phase
┌─────────────────────┐          ┌──────────────────────────┐
│ ADRs                │          │ Reads architecture doc   │
│ Integration points  │          │ Extracts requirements    │
│ ...                 │          │ Designs epics            │
│ Story sketches  ←───┼── ? ──→ │ Are these stories done?  │
│                     │          │ Or architect suggestions? │
└─────────────────────┘          └──────────────────────────┘
```

Without a convention, the SM either:
- Treats architect sketches as canonical (skipping the epic/story design process)
- Ignores them entirely (losing valuable context)
- Has to ask "did you mean this as a real story or a sketch?" every time

## The Convention

### Section Naming

When a stepped workflow phase produces artifacts that belong to a later phase, the section title must include **"(Pre-Epic Sketch)"** or the equivalent marker for the target phase:

```markdown
## Work Decomposition (Pre-Epic Sketch)

> **Note to SM:** These work units are the architect's preliminary decomposition
> based on technical dependencies. They exist to communicate scope and sequencing,
> not to prescribe the sprint plan. The SM owns the final decomposition — re-slice,
> re-size, reorder, or restructure as needed when the formal planning workflow
> begins. Nothing here is load-bearing until the SM says it is.
```

The pattern: **"(Pre-{TargetPhase} Sketch)"** — readable, clear about origin, clear about non-canonical status.

### Frontmatter Signal

Architecture documents containing pre-epic sketches should include a frontmatter field:

```yaml
---
contains_sketches:
  - type: epic-breakdown
    section: "Work Decomposition (Pre-Epic Sketch)"
    status: draft-for-sm
    note: "Architect's decomposition. SM owns final version."
---
```

This is machine-readable. The `create-epics-and-stories` workflow's Step 1 (Validate Prerequisites) can detect this field and inform the SM that architect sketches exist as input material.

### What the SM Does With Sketches

When the `create-epics-and-stories` workflow encounters an architecture document with `contains_sketches` frontmatter:

1. **Read the sketches** as input alongside FRs and technical requirements
2. **Treat them as the architect's decomposition hypothesis** — the architect's view of how the work breaks down technically
3. **Reorganize by user value** — the workflow's Step 2 (Design Epics) explicitly organizes by user value, not technical layers. The architect's technical-layer decomposition is input, not output.
4. **Preserve attribution** — if a story in the final epic breakdown originated from the architect's sketch, note it. If the SM restructured or merged sketches, that's fine — the sketches served their purpose.

### What Sketches Are NOT

- Not canonical stories — the `create-epics-and-stories` workflow produces canonical stories
- Not sized — point estimates in sketches are the architect's rough guess, not planning poker
- Not sprint-assigned — sprint assignment is the SM's job during sprint planning
- Not acceptance criteria — the workflow's Step 3 produces proper Given/When/Then ACs
- Not approved — no user gate has approved these as work items

### What Sketches ARE

- The architect's mental model of how the system decomposes into buildable units
- A dependency map (what must be built before what)
- A scope signal (roughly how much work this architecture implies)
- Context that would otherwise be lost between the architecture phase and the epic/story phase

## Why This Matters

The lifecycle composition research (Track 5, Product Decomposition) found that specification artifacts are hypotheses, not edicts. The architect's story sketch is a hypothesis about work decomposition. The SM's epic design is a hypothesis about value delivery. Both are inputs to the delivery tier. The convention makes the hypothesis status explicit.

## Implementation

To adopt this convention:

1. **Architecture workflow** (Step 7: Documentation): Add guidance that story sketches in architecture docs should use the "(Pre-Epic Sketch)" naming convention
2. **Epics & Stories workflow** (Step 1: Validate Prerequisites): Add detection of `contains_sketches` frontmatter; inform SM that architect sketches exist
3. **SM sidecar** (patterns.md): Add pattern for consuming pre-epic sketches as input

These are small changes — naming convention + frontmatter field + one paragraph of guidance in 3 places.
