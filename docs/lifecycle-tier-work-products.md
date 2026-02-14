# Input A: Tier Work Products

**Initiative:** Lifecycle Composition — Tier Communication Protocol
**Date:** 2026-02-14
**Agent:** BA (Avasarala)
**Product:** Axiathon (enterprise SIEM platform)
**Team:** 7-12 people (PM/PO, Architect, platform engineers, professional SE)
**Index:** `lifecycle-composition-index.md`

---

## The Problem This Document Solves

You cannot define tiers, communication channels, or organizational structure until you know what work each tier produces. Structure follows function. This document defines the **artifacts** — what gets made at each level of the product lifecycle — grounded in the reality of axiathon: a multi-crate Rust SIEM platform being built by a team using spec-driven development with LLM tooling.

---

## The Axiathon Reality

### What Exists Today (The Left-Shifted Artifact Stack)

Axiathon's planning phase produced an enormous, detailed specification corpus:

| Artifact | Scale | Author(s) |
|----------|-------|-----------|
| Product Brief | 56KB, competitive analysis, market positioning | Josh + AI |
| PRD | 14 sections, ~990 FRs, ~228 NFRs | Josh + AI |
| Architecture | 28+ decisions, strict crate dependency hierarchy | Josh + AI |
| UX Specifications | 42 files, design system, component patterns | Josh + AI |
| Wireframes | 175 Excalidraw diagrams (architecture, web, TUI, mobile) | Josh + AI |
| Epics | 30 (24 implementation + 6 planning) | Josh + AI |
| Stories | 222+ across 3 phases | Josh + AI |
| Research | 54+ documents (market, technical, domain) | Josh + AI |
| Jira Tickets | 1,101 (planning phase, all complete) | Josh + AI |

**Total:** ~110,755 lines of specification across 338 markdown files.

### What This Stack Is Missing

This artifact stack is a monument to solo left-shifted thinking. It is thorough, it is detailed, and it has a structural problem: **it was designed to be consumed by one person with an LLM, not by a team of 7-12**.

| Gap | Consequence |
|-----|-------------|
| **No crate interface contracts** | The architecture defines crate boundaries and dependencies, but not the APIs between them. When two people work on connected crates simultaneously, they discover mismatched assumptions at integration time. |
| **No decision delegation framework** | All 28+ architecture decisions came from one mind. When a platform engineer encounters an undocumented decision, the only process is "ask Josh." Josh becomes the bottleneck. |
| **No change propagation path** | When implementation proves an architectural assumption wrong, there is no defined process for updating the architecture doc, identifying affected stories, and notifying people working on dependent crates. |
| **No specification versioning** | The PRD is a single 73KB file. When it changes, how do you know which stories are now stale? What was the spec when a given story was implemented? |
| **No cross-crate integration specification** | Epics are decomposed along crate boundaries, but the integration points between crates (event format, error handling conventions, async patterns, tenant context propagation) are implicit in the architecture, not specified as verifiable contracts. |
| **No feedback artifact** | The artifact stack flows downward: Brief → PRD → Architecture → Epics → Stories. There is no upward-flowing artifact — no "implementation finding" or "spec correction request" — that feeds learning back to the appropriate level. |

### The Core Tension

BMAD's process — and by extension, early-stage spec-driven development — assumes:

1. One person can think through the entire system
2. Specs are written once, then executed against
3. The spec is correct; deviations are bugs in execution

Reality at axiathon's scale:

1. No single person can hold 990 FRs, 28 architecture decisions, and 8 crate boundaries in working memory
2. Specs are hypotheses that implementation validates or invalidates
3. Deviations are sometimes bugs in execution *and sometimes bugs in the spec*

The tier work products must account for both directions: specs flowing down (decomposition) and findings flowing up (correction and learning).

---

## The Three Tiers and What They Produce

### Tier Naming Convention

We adopt names that describe *what the tier does*, not organizational rank:

| Tier | Name | Scope | Cadence | Axiathon Example |
|------|------|-------|---------|------------------|
| 1 | **Product** | The whole system, its market position, its boundaries | Monthly to quarterly | Axiathon as a SIEM platform |
| 2 | **Domain** | A bounded subsystem with its own architecture and team(s) | Weekly to per-sprint | `axiathon-detection` + `axiathon-query` (the "detection domain") |
| 3 | **Delivery** | A single implementable unit of work | Daily to per-story | "Implement Sigma rule parser with 90% compatibility" |

**Why "Domain" not "Feature" or "Tactical":** A domain is a bounded context (Evans 2003) — a subsystem where a particular model applies. Axiathon's crate structure maps naturally to domains: Ingestion, Detection, Storage, Query, OT, API, TUI. Some domains span multiple crates (Detection + Query share the detection model). Domains are the natural unit at which an architect can operate and a sub-team can own.

**Why "Delivery" not "Execution":** The word "execution" implies following orders. Delivery implies producing something. At the delivery tier, people (with LLM tooling) make implementation decisions, discover problems, and produce code that either validates or invalidates the domain specification. Delivery is not a passive tier.

---

## Tier 1: Product Work Products

### What This Tier Produces

The Product tier defines *what we are building and why*. Its artifacts bound the entire system. Changes at this tier ripple to every domain and every delivery unit.

| Artifact | Current Axiathon Equivalent | Format | Lifecycle |
|----------|---------------------------|--------|-----------|
| **Product Brief** | `product-brief-axiathon-2026-01-02.md` | Narrative markdown | Stable. Changes quarterly or on market events. |
| **Product Requirements Document** | `prd/` (14 sections) | Structured markdown with numbered FRs | Evolves per phase. Sections may be amended by domain findings. |
| **Product Architecture** | `architecture/` (28+ decisions) | Decision records + diagrams | Evolves as domains discover constraints. Must version decisions. |
| **Phase Strategy** | `prd/project-scoping-phased-development.md` | Phased roadmap with epic assignments | Revised per phase boundary. |
| **Cross-Domain Interface Contracts** | **Does not exist** | Needs definition (see below) | Evolves as domains implement. Versioned. |
| **Product Design Rules** | **Partially exists** in architecture decisions | Architectural invariants + style conventions | Stable within a phase. Amended by ADR process. |

### New Artifact: Cross-Domain Interface Contracts

This is the missing artifact at the Product tier. It defines the API surface between domains — not the internal implementation, but the contracts that domains must honor when they communicate.

For axiathon, these contracts include:

| Contract | Between | What It Defines |
|----------|---------|-----------------|
| OCSF Event Schema | Ingestion → Detection, Storage, Query | Canonical event structure, required fields, extension mechanism |
| Tenant Context Propagation | Core → All crates | How `TenantContext` is threaded through all operations |
| Error Handling Convention | All crates | Error types, propagation rules, logging requirements |
| Async Runtime Convention | All crates | Tokio runtime assumptions, cancellation behavior |
| Storage API | Storage → Ingestion, Query, Detection | Write path, read path, retention, tier migration triggers |
| Detection Alert Format | Detection → API, TUI, Integrations | Alert structure, severity levels, enrichment fields |
| Plugin Interface | Core → Ingestion, Detection | WASM plugin contract, capabilities, resource limits |
| Configuration Schema | Core → All crates | TOML structure, overlay rules, environment precedence |

**Format:** Each contract is a versioned document specifying:
- Interface signature (types, methods, protocols)
- Behavioral contract (preconditions, postconditions, invariants — Meyer 1997)
- Compatibility rules (what changes are breaking vs. non-breaking)
- Verification method (how compliance is tested)

**Why this matters:** When a platform engineer in `axiathon-ingestion` produces an OCSF event, and another in `axiathon-detection` consumes it, the contract is the source of truth for what that event looks like. Without this contract, both engineers are independently interpreting the architecture document and hoping they agree. With it, both can verify compliance independently (Pact-style consumer-driven contracts — Pact Foundation 2024).

### New Artifact: Product Design Rules

Drawing from Baldwin and Clark (2000, 63), design rules are the architectural invariants that all domains must obey. They are distinct from architecture decisions (which explain *why* a choice was made) — design rules state *what must always be true*.

For axiathon:

| Rule | Scope | Rationale |
|------|-------|-----------|
| All crate dependencies are acyclic | All crates | Architecture decision: strict dependency hierarchy |
| All public APIs accept `TenantContext` as first parameter | All crates | Multi-tenancy is structural, not bolted on |
| All errors implement `std::error::Error` and carry tenant context | All crates | Error handling convention |
| No crate directly accesses another crate's storage | Storage boundary | Storage API is the only access path |
| All user-facing text uses the i18n framework | API, TUI, WebUI | Internationalization from day one |
| All configuration is TOML with environment overlays | All crates | Configuration schema contract |

**Format:** Each rule is a one-sentence invariant with a rationale. Rules are verifiable — ideally through automated fitness functions (Ford, Parsons, and Kua 2017). When a rule must be changed, it goes through the ADR process because changing a rule ripples to every domain.

---

## Tier 2: Domain Work Products

### What This Tier Produces

The Domain tier translates product-level specs into bounded subsystem designs. Its artifacts define *how a particular subsystem works* within the constraints set by product-level design rules and contracts.

| Artifact | Current Axiathon Equivalent | Format | Lifecycle |
|----------|---------------------------|--------|-----------|
| **Domain Architecture** | **Partially exists** in crate-level architecture decisions | Decision records + component diagrams | Evolves as delivery reveals constraints |
| **Domain Interface Spec** | **Does not exist** | Internal API definitions, module boundaries | Evolves with implementation. Versioned. |
| **Epic Specifications** | `epics/epic-*.md` | Narrative + story list | Created during planning. Amended by domain findings. |
| **Story Specifications** | Stories within epics | Structured: goal, ACs, constraints | Created during sprint planning. Amended during delivery. |
| **Domain Integration Test Spec** | **Does not exist** | Cross-crate test scenarios derived from contracts | Created from contracts. Updated when contracts change. |
| **Spec Correction Request** | **Does not exist** | Upward-flowing artifact (see below) |  |

### The Domain As a Bounded Context

A domain in axiathon is not necessarily a single crate. It is a bounded context (Evans 2003) — a subsystem where a particular model applies and a particular sub-team can operate with relative autonomy.

Proposed domain mapping for axiathon:

| Domain | Crates | Model | Team Size |
|--------|--------|-------|-----------|
| **Ingestion** | `axiathon-ingestion`, part of `axiathon-core` (OCSF types) | Event normalization, source adapters, parsing | 1-2 |
| **Detection** | `axiathon-detection`, part of `axiathon-query` | Rules, DSL, Sigma, evaluation, alerting | 1-2 |
| **Storage** | `axiathon-storage` | Tiered persistence, indexing, retention, query execution | 1 |
| **OT Security** | `axiathon-ot` | Industrial protocols, asset discovery, OT-specific rules | 1 |
| **Platform** | `axiathon-api`, `axiathon-core` (shared types, auth, config) | External API, auth, multi-tenancy, plugin system | 1-2 |
| **Interface** | `axiathon-tui`, (future: `axiathon-webui`) | User interaction, visualization, workflow | 1-2 |
| **Infrastructure** | Helm, KOTS, CI/CD, Docker | Deployment, monitoring, operations | 1 |

**Note:** These domains will shift as the team discovers what work naturally clusters together. The domain structure is itself a hypothesis — validated or invalidated by delivery experience (double-loop learning, Argyris 1977).

### Domain Architecture: What the Architect Would Have Decided

This is the artifact that enables "thinking like Josh." A domain architecture document captures:

1. **Domain model** — the key entities, their relationships, and their invariants within this bounded context
2. **Internal module structure** — how the crate is decomposed internally (Parnas 1972: organize around design decisions that might change)
3. **Decision log** — architectural decisions specific to this domain, including the reasoning
4. **Technology choices** — within the domain's scope (e.g., which parsing library for Sigma rules)
5. **Quality attributes** — performance targets, security constraints, reliability requirements specific to this domain
6. **Constraints from above** — which product-level design rules and contracts apply, and how this domain satisfies them
7. **The "Josh Test"** — for each major decision area, a brief description of the architectural intent: "If Josh were making this decision, he would prioritize X because Y." This captures architectural *judgment*, not just architectural *decisions*. It helps a platform engineer choose between two technically valid approaches by understanding the architect's priorities.

**Format:** Markdown with structured sections. Versioned. Changes tracked through domain-level ADRs.

**Who writes it:** Initially, Josh (the architect) writes the domain architecture for each domain. As the team matures, domain leads contribute and Josh reviews. The goal is that domain architectures become *owned* by domain teams, with Josh maintaining product-level coherence.

### New Artifact: Spec Correction Request (SCR)

This is the upward-flowing artifact that currently does not exist. When delivery work reveals a problem in a domain or product specification, the SCR captures:

1. **What was specified** — the specific requirement, decision, or contract that is problematic
2. **What was discovered** — the implementation finding that conflicts with the spec
3. **Impact assessment** — what other stories, domains, or contracts are affected
4. **Proposed correction** — what the spec should say instead (optional — the correction may require product-tier judgment)
5. **Urgency** — can work continue with a workaround, or is this blocking?

**Direction:** Flows upward. Delivery → Domain, or Domain → Product.

**Response:** The receiving tier must acknowledge, assess impact, and either:
- Amend the spec (and notify all affected downstream work)
- Reject the correction with rationale (and the delivery tier adjusts implementation)
- Escalate further upward

This is Beer's algedonic signal formalized as a document. It is also the mechanism for Argyris's double-loop learning: the spec itself is questioned, not just the execution against it.

---

## Tier 3: Delivery Work Products

### What This Tier Produces

The Delivery tier produces working, tested code that satisfies story specifications within domain boundaries. Its artifacts are the smallest units of the system — the level at which LLM tooling generates content and code.

| Artifact | Current Axiathon/Pennyfarthing Equivalent | Format | Lifecycle |
|----------|------------------------------------------|--------|-----------|
| **Story Spec** | Story definitions within epics | Structured: goal, ACs, constraints, domain context | Created during sprint planning. Immutable during delivery (changes go through SCR). |
| **Test Specification** | TEA agent output | Test cases derived from ACs | Created by TEA agent before implementation (TDD red phase) |
| **Implementation** | Dev agent output | Rust code within domain boundaries | Created by Dev agent, verified against tests and contracts |
| **Code Review Assessment** | Reviewer agent output | Structured review with architectural compliance check | Created by Reviewer agent. May trigger SCR if issues found. |
| **Delivery Finding** | **Does not exist** (partially captured in session file) | Structured note about spec gaps, ambiguities, or errors | Created during any delivery phase. May become an SCR. |

### The Delivery Finding

This is the smallest upward-flowing artifact. During implementation, the person (with LLM tooling) discovers things:

- "The OCSF event schema doesn't have a field for OT-specific protocol metadata. I added one. This needs to be ratified into the contract."
- "The architecture says use `tokio::sync::RwLock` for the rule cache, but benchmarks show `dashmap` is 3x faster for our access pattern."
- "AC-3 says 'support Sigma rules with 90% compatibility' but doesn't define which 10% is excluded. I need a decision."

Currently, these discoveries disappear into Slack conversations, ad-hoc Josh consultations, or git commit messages. The delivery finding gives them a structured home and a defined routing path.

**Format:**
- **Type:** Gap (spec doesn't address this) | Conflict (spec says X, reality requires Y) | Question (spec is ambiguous) | Improvement (found a better approach)
- **Source:** Story ID, phase, agent/person
- **Affected Spec:** Which spec at which tier
- **Description:** What was found
- **Proposed Action:** Update contract? Amend architecture? Clarify AC? Decision needed?
- **Urgency:** Blocking (can't continue) | Non-blocking (workaround applied, needs ratification)

**Routing:** Delivery Finding → Domain owner for triage. If domain-level, resolved at domain tier. If product-level (affects contracts or design rules), escalated as SCR to product tier.

---

## Artifact Flow: The Full Picture

```
PRODUCT TIER (Monthly/Quarterly)
├── Product Brief ────────────────────────────────────────────┐
├── PRD (versioned sections) ────────────────────────────┐    │
├── Product Architecture (ADRs) ─────────────────────┐   │    │
├── Cross-Domain Interface Contracts (versioned) ─┐   │   │    │
├── Product Design Rules ─────────────────────┐   │   │   │    │
│                                             │   │   │   │    │
│   ┌─────── Spec Correction Requests ────────┤   │   │   │    │
│   │         (upward flow)                   │   │   │   │    │
│   ▼                                         ▼   ▼   ▼   ▼    ▼
│  DOMAIN TIER (Weekly/Sprint)
│  ├── Domain Architecture ◄── design rules, contracts
│  ├── Domain Interface Spec ◄── contracts
│  ├── Epic Specifications ◄── PRD, architecture
│  ├── Story Specifications ◄── epics, domain arch
│  ├── Domain Integration Test Spec ◄── contracts
│  │
│  │   ┌─────── Delivery Findings ──────────────────────────┐
│  │   │         (upward flow)                              │
│  │   ▼                                                    ▼
│  │  DELIVERY TIER (Daily/Per-Story)
│  │  ├── Story Spec (immutable during delivery)
│  │  ├── Test Specification (TEA phase)
│  │  ├── Implementation (Dev phase)
│  │  ├── Code Review Assessment (Review phase)
│  │  └── Delivery Findings (any phase) ──► Domain Tier
│  │
│  └── Spec Correction Requests ──────────────────► Product Tier
│
└── (responses flow back down through amended specs)
```

### Downward Flow (Decomposition)

| From | To | What Flows | Trigger |
|------|----|-----------|---------|
| Product → Domain | Domain Architecture, Epic Specs | Product architecture decisions, design rules, contracts | Phase planning, architecture change |
| Domain → Delivery | Story Specs, Test Specs | Domain architecture, AC, constraints, domain context | Sprint planning, story assignment |

### Upward Flow (Feedback and Correction)

| From | To | What Flows | Trigger |
|------|----|-----------|---------|
| Delivery → Domain | Delivery Findings | Gaps, conflicts, questions, improvements | Any phase of delivery work |
| Domain → Product | Spec Correction Requests | Domain-level findings that affect product-level specs | Domain triage of delivery findings + domain-level discoveries |

### Lateral Flow (Coordination)

| Between | What Flows | Trigger |
|---------|-----------|---------|
| Domain ↔ Domain | Contract change notifications | Interface contract amendment |
| Delivery ↔ Delivery | *None currently defined* | N/A (coordination happens through domain tier) |

---

## How This Addresses the Core Problems

### "One architect can't think through everything"

**Mechanism:** Domain Architecture documents distribute architectural thinking. Josh writes the product architecture and design rules. Domain leads write domain architectures constrained by those rules. The "Josh Test" section in each domain architecture captures Josh's priorities so domain leads can extrapolate his judgment.

### "The spec becomes the bottleneck"

**Mechanism:** Specs at lower tiers are smaller and independently writable. Domain architectures are owned by domain leads, not by Josh. Story specs are derived from domain architectures by sprint planning. The bottleneck shifts from "Josh writes all specs" to "Josh maintains product-level coherence while domain leads handle domain-level detail."

### "Implementation discovers spec errors with no correction path"

**Mechanism:** Delivery Findings and Spec Correction Requests provide structured upward-flowing artifacts. A platform engineer who discovers a contract inconsistency doesn't need to hunt down Josh — they file a Delivery Finding routed to the domain owner. If it's a product-level issue, it escalates as an SCR.

### "Multiple people making conflicting decisions"

**Mechanism:** Cross-Domain Interface Contracts and Product Design Rules bound the decision space. Two people working in different crates can make independent decisions as long as both honor the contracts and rules. Conflicts arise only when someone violates a contract — which is detectable by automated verification (Pact-style testing, fitness functions).

### "Changes ripple through the system with no tracking"

**Mechanism:** Spec versioning + contract versioning + traceability. When a product-level spec changes, the versioning system identifies which domain architectures reference the changed section. When a contract changes, all domains implementing that contract are notified. The impact analysis isn't a manual hunt — it's a structural consequence of versioned, linked artifacts.

---

## Open Questions for Tier Definition (Input B)

This document defines *what each tier produces*. The following questions remain for *how the tiers are organized*:

1. **Who owns each domain?** Is it a person, a role, or whoever is currently working in that area?
2. **How are domain boundaries revised?** When implementation reveals that the domain mapping is wrong (e.g., Detection and Query should be one domain), what triggers the change?
3. **What's the cadence for product-tier reviews?** When SCRs accumulate, how often does the product tier convene to assess and amend?
4. **How formal are delivery findings?** Is every observation a structured document, or is there a threshold below which informal communication suffices?
5. **What tooling supports contract verification?** Can we use Rust's type system as the contract enforcement mechanism? (Trait definitions as contracts, compile-time verification as fitness functions.)

---

## References

Argyris, Chris. 1977. "Double Loop Learning in Organizations." *Harvard Business Review* 55 (September-October): 115-125.

Baldwin, Carliss Y., and Kim B. Clark. 2000. *Design Rules: The Power of Modularity*. Cambridge, MA: MIT Press.

Evans, Eric. 2003. *Domain-Driven Design: Tackling Complexity in the Heart of Software*. Boston: Addison-Wesley.

Ford, Neal, Rebecca Parsons, and Patrick Kua. 2017. *Building Evolutionary Architectures: Support Constant Change*. Sebastopol, CA: O'Reilly Media.

Meyer, Bertrand. 1997. *Object-Oriented Software Construction*. 2nd ed. Upper Saddle River, NJ: Prentice Hall.

Pact Foundation. 2024. "Introduction to Pact." https://docs.pact.io/.

Parnas, David L. 1972. "On the Criteria To Be Used in Decomposing Systems into Modules." *Communications of the ACM* 15 (12): 1053-58.
