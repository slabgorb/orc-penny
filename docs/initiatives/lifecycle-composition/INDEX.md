# Lifecycle Composition Initiative — Index & Progress Tracker

**Initiative:** Evolving BikeLane's product lifecycle into a composable, tiered, recursive engine
**Started:** 2026-02-14
**Status:** Protocol v0.1 drafted. Ready for team review or RFC authoring.
**Agent:** BA (Avasarala) — requirements discovery phase
**RFC Ticket:** MSSCI-15086

---

## Document Inventory

| # | Document | Purpose | Status |
|---|----------|---------|--------|
| 1 | `lifecycle-workflow-maps.md` | Current state: visual maps of all 22 BikeLane workflows | Done |
| 2 | `lifecycle-improvement-rs.md` | Product brief: 5 gaps, vision, phased proposal | Done |
| 3 | `lifecycle-research-bootstrap.md` | Track 1 research: VSM, Auftragstaktik, cybernetic feedback (30 sources) | Done |
| 4 | `research-track-2-organizational-structure.md` | Track 2 research: tiered architecture, distributed decisions, Conway's Law (39 sources) | Done |
| 5 | `lifecycle-research-track3.md` | Track 3 research: spec-driven development, R&D/CoE, innovation management (31 sources) | Done |
| 6 | `lifecycle-research-track4.md` | Track 4 research: architectural drift, integration patterns (33 sources) | Done |
| 7 | `lifecycle-research-track5.md` | Track 5 research: product decomposition, process simulations (38 sources) | Done |
| 8 | `lifecycle-research-synthesis.md` | Unified synthesis: hypothesis validation, 9 convergent principles, gap-to-mechanism mapping | Done |
| 9 | `lifecycle-tier-work-products.md` | Tier work product definitions: what each tier produces and consumes | **Draft complete** |
| 10 | `lifecycle-tier-definitions.md` | Formal tier definitions + VSM S1-S5 mapping (Inputs B+C combined) | **Draft complete** |
| 11 | *(merged into #10)* | VSM mapping merged into tier definitions | N/A |
| 12 | *(merged into #13)* | Channel taxonomy is Part I of the protocol | N/A |
| 13 | `lifecycle-tier-comm-protocol.md` | Full protocol: channels, messages, triggers, flows, implementation mapping | **Draft complete** |
| 14 | ADR-0027 (or next) | Architecture decision record for the composable lifecycle | **Not started** |
| 15 | RFC (MSSCI-15086) | Full RFC for team review | **Not started** |

---

## What's Been Completed

### Phase 0: Current State Mapping (Done)
- [x] Mapped all 22 existing BikeLane workflows visually
- [x] Identified 5 structural gaps in the current lifecycle

### Phase 1: Product Brief (Done)
- [x] Wrote product brief proposing Composable Lifecycle Engine
- [x] Filed ADR-0026 (trunk-based for orchestrator repos)
- [x] Filed MSSCI-15086 (RFC ticket)

### Phase 2: Deep Research (Done)
- [x] Track 1: VSM + Auftragstaktik + Cybernetic Feedback
- [x] Track 2: Tiered Architecture + Distributed Decisions + Conway's Law
- [x] Track 3: Spec-Driven Development + R&D/CoE + Innovation Management
- [x] Track 4: Architectural Drift + Integration Patterns
- [x] Track 5: Product Decomposition + Process Simulations
- [x] Unified synthesis across all 5 tracks (~130 sources, Chicago author-date)
- [x] All 5 original hypotheses validated against literature
- [x] 9 convergent design principles extracted
- [x] Current handoff/communication system audited (10 gap categories found)

---

## What's In Progress

### Phase 3: Design Inputs (Current Phase)

The tier communication protocol requires six inputs developed in sequence. The critical insight: **we must define what work each tier produces before we can define the tiers themselves or the channels between them.**

#### Input Sequence

| # | Input | Depends On | Status | Document |
|---|-------|------------|--------|----------|
| **A** | **Tier Work Products** | Research (done) | **Draft complete** | `lifecycle-tier-work-products.md` |
| B+C | Tier Definitions + VSM Map | A | **Draft complete** | `lifecycle-tier-definitions.md` |
| D+E+F | Channel Taxonomy + Schema + Triggers | A, B+C | **Draft complete** | `lifecycle-tier-comm-protocol.md` (Parts I-III) |

**Input A (Tier Work Products)** is the foundation. It answers:
- What specification artifacts does each tier produce?
- What does a strategic spec look like vs. a tactical spec vs. an execution spec?
- What deliverables flow downward (decomposition) and upward (feedback/findings)?
- What is the format, granularity, and lifecycle of each artifact?

Without this, tier definitions are organizational charts without substance, and channels are pipes with nothing to carry.

---

## What's Next

### Phase 4: Protocol Design
- [ ] Design the tier communication protocol (channels, messages, triggers)
- [ ] Define escalation paths and algedonic signals
- [ ] Define bidirectional feedback mechanisms
- [ ] Map current gaps to protocol solutions

### Phase 5: Prototype
- [ ] Prototype two-tier lifecycle (Tactical + Execution)
- [ ] Validate core mechanisms: inheritance, feedback, recursive instantiation

### Phase 6: RFC
- [ ] Write full RFC incorporating research, design, and prototype findings
- [ ] Submit for team review (Keith, Mike R, Musthaq)

---

## Key Decisions Made

| Decision | Rationale | Source |
|----------|-----------|-------|
| Three tiers (Strategic / Tactical / Execution) | Matches NIST RMF, VSM recursion, and product brief's fractal vision | Research synthesis |
| Each tier runs a full process cycle | Beer's recursion theorem; NIST bidirectional model | Track 1, Track 2 |
| Distributed architects at each tier | Subsidiarity principle; Conant-Ashby theorem | Track 1, Track 2 |
| Specifications are the primary artifact | MDE/MDA precedent; TLA+ at Amazon; spec quality research | Track 3 |
| Contract-first integration between agents | NASA IV&V; Pact contracts; feature interaction problem | Track 4 |
| Small batches with fast feedback | Reinertsen flow theory; DORA metrics | Track 5 |

## Key Decisions Pending

| Decision | Blocking | Options |
|----------|----------|---------|
| What artifacts does each tier produce? | Everything downstream | Needs BA discovery (Input A) |
| How formal should tier specs be? | Tier definitions, agent parameterization | Spectrum from natural language to TLA+-style |
| How do tiers synchronize? | Protocol design | Event-driven vs cadence-driven vs hybrid |
| What triggers escalation? | Protocol design | Threshold, event, or agent judgment |

---

## Resume Instructions

1. Load BA agent (`/ba`)
2. Read THIS file first (`docs/initiatives/lifecycle-composition/INDEX.md`)
3. Check "What's In Progress" for current phase and next input needed
4. Read the relevant prior documents listed in the Document Inventory
5. Continue from where we left off
