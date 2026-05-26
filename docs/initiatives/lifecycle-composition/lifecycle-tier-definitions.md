---
bibliography: ../../../references.bib
csl: chicago-author-date.csl
---

# Input B + C: Tier Definitions and VSM Mapping

**Initiative:** Lifecycle Composition — Tier Communication Protocol
**Date:** 2026-02-14
**Agent:** BA (Avasarala)
**Depends On:** Input A (Tier Work Products)
**Index:** `INDEX.md`
**Confidence:** Medium — untested design. Will be revised by delivery experience.

---

## Tier Definitions

### Tier 1: Product

| Attribute | Definition |
|-----------|-----------|
| **Scope** | The whole system — consumer-project as a SIEM platform |
| **Cadence** | Monthly review cycle. Quarterly phase boundaries. Ad-hoc on SCR escalation. |
| **People** | Product Manager, Product Owner, Architect (Josh) |
| **Decisions owned** | Market positioning, phase strategy, cross-domain contracts, design rules, technology stack choices, non-functional requirements, compliance framework scope |
| **Decisions escalated here** | Anything that changes the product architecture, affects multiple domains, or modifies a cross-domain contract |
| **Artifacts produced** | Product Brief, PRD, Product Architecture (ADRs), Cross-Domain Interface Contracts, Product Design Rules, Phase Strategy |
| **Artifacts consumed** | Spec Correction Requests (from Domain tier), market/competitive intelligence, user feedback |
| **Lifecycle loop** | Discover (market analysis, feedback triage) → Design (architecture, contracts) → Plan (phase strategy, epic decomposition) → Verify (fitness function results, drift reports) → Learn (SCR review, retrospective) |

### Tier 2: Domain

| Attribute | Definition |
|-----------|-----------|
| **Scope** | A bounded subsystem — one or more crates sharing a domain model |
| **Cadence** | Weekly sync. Per-sprint planning. Continuous during delivery. |
| **People** | Domain lead (may be the person most experienced in that area, not a formal title), engineers assigned to the domain's stories |
| **Decisions owned** | Internal module structure, implementation approach within design rules, technology choices within domain scope (e.g., which parsing library), test strategy, performance optimization approach |
| **Decisions escalated from here** | Cross-domain contract changes, design rule conflicts, architectural discoveries that affect other domains |
| **Decisions escalated to here** | Delivery Findings that affect the domain architecture or domain-level specs |
| **Artifacts produced** | Domain Architecture, Domain Interface Spec (internal), Epic Specs (amended), Story Specs, Domain Integration Test Spec, Spec Correction Requests (to Product) |
| **Artifacts consumed** | Product Architecture, Cross-Domain Contracts, Design Rules, Delivery Findings (from Delivery tier) |
| **Lifecycle loop** | Discover (delivery findings triage, domain backlog review) → Design (domain architecture refinement, story spec writing) → Plan (sprint planning, story assignment) → Verify (domain integration tests, code review) → Learn (delivery finding patterns, domain retro) |

**Initial consumer-project domain mapping:**

| Domain | Crates | Likely Lead | Key Contracts Consumed |
|--------|--------|-------------|----------------------|
| Ingestion | `consumer-project-ingestion`, OCSF types from `core` | Engineer with data pipeline experience | OCSF Schema, Storage API, Plugin Interface |
| Detection | `consumer-project-detection`, query integration from `consumer-project-query` | Security engineer or detection-focused engineer | OCSF Schema, Alert Format, Storage API |
| Storage | `consumer-project-storage` | Performance-oriented engineer | Storage API (provider side), Config Schema |
| OT Security | `consumer-project-ot` | OT/ICS specialist | OCSF Schema, Asset Graph interface |
| Platform | `consumer-project-api`, `consumer-project-core` (auth, config, tenancy) | Professional SE | TenantContext, Error Convention, Config Schema, all outward-facing APIs |
| Interface | `consumer-project-tui`, future WebUI | UI-focused engineer | API contracts (consumer side), Alert Format |
| Infrastructure | Helm, KOTS, CI/CD, Docker, monitoring | DevOps engineer | Deployment specs, monitoring contracts |

**Note:** This mapping is a starting hypothesis. When someone working in Detection discovers they spend 60% of their time in Query, the domains should merge. When Platform proves too large for one person, it should split. The domain map is mutable.

### Tier 3: Delivery

| Attribute | Definition |
|-----------|-----------|
| **Scope** | A single story — one implementable unit of work |
| **Cadence** | Daily. Per-story cycle (1-5 days typical). |
| **People** | The engineer assigned to the story, with LLM tooling (Claude Code). Reviewer is a second person or the domain lead. |
| **Decisions owned** | Implementation details within module boundaries, variable naming, algorithm choice (within performance constraints), test structure, refactoring within the story's scope |
| **Decisions NOT owned** | Module boundaries, public API signatures, anything that changes a contract or violates a design rule |
| **Artifacts produced** | Test Specification, Implementation (code), Code Review Assessment, Delivery Findings |
| **Artifacts consumed** | Story Spec, Domain Architecture, relevant Cross-Domain Contracts, Design Rules |
| **Lifecycle loop** | Spec (read story + domain context) → Red (write failing tests from ACs) → Green (implement to pass tests) → Review (code review + architectural compliance) → Finding (capture what was learned) |

---

## VSM Mapping: Beer's Five Systems at Each Tier

Beer's VSM says every viable system contains the same five subsystems. Here's how they manifest at each tier of consumer-project's lifecycle.

### System 1 (Operations): The Units That Do the Work

| Tier | S1 Manifestation |
|------|-----------------|
| Product | The domains themselves — each domain is an S1 unit of the product |
| Domain | The delivery units (stories/sprints) — each story is an S1 unit of the domain |
| Delivery | The implementation acts — writing tests, writing code, running tests |

### System 2 (Coordination / Anti-Oscillation): Preventing Clashes

| Tier | S2 Manifestation |
|------|-----------------|
| Product | Cross-Domain Interface Contracts. When Ingestion and Detection both want to change the OCSF schema, the contract prevents oscillation. Sprint planning that sequences cross-domain work. |
| Domain | Story dependencies within the domain. When two stories in Detection both modify the rule evaluation engine, S2 ensures they don't conflict. Branch strategy and merge ordering. |
| Delivery | LLM tooling constraints — the test spec prevents the implementation from drifting. Linting, formatting, type checking. The TDD red-green cycle itself is an S2 mechanism. |

**Key insight:** S2 is not a person or a meeting. It's a *mechanism*. Contracts, type systems, CI pipelines, and TDD are all S2. The goal is to make coordination structural, not conversational.

### System 3 (Control / Optimization): The Internal Eye

| Tier | S3 Manifestation |
|------|-----------------|
| Product | Product Manager reviewing domain progress, sprint metrics, velocity across domains, resource allocation between domains. DORA metrics at the product level. |
| Domain | Domain lead reviewing delivery progress, story completion rates, integration test results, code quality metrics. Deciding which stories to prioritize within the domain. |
| Delivery | The code review phase. The reviewer agent/person looks at the implementation, verifies it meets the story spec, checks architectural compliance, and assesses quality. |

### System 3* (Audit / Sporadic Monitoring): Ground Truth Check

| Tier | S3* Manifestation |
|------|-----------------|
| Product | Periodic architecture compliance audit — do the domains still conform to design rules? Fitness function suite run. Drift detection report. Not every sprint — sporadic. |
| Domain | Random deep review of a completed story — not just code review but "does this actually do what the domain architecture intended?" Spot-check integration tests. |
| Delivery | Mutation testing. Fuzz testing. The occasional "let me read this code without looking at the spec and see if it makes sense." |

**Key insight:** S3* is specifically *not* routine. It bypasses normal reporting to get unfiltered ground truth. If every code review is S3, then S3* is the surprise audit that checks whether the code reviews are actually catching problems.

### System 4 (Intelligence / Adaptation): The External Eye

| Tier | S4 Manifestation |
|------|-----------------|
| Product | Market monitoring, competitor analysis, technology trend scanning, user feedback analysis. "What's changing in the SIEM market that should affect our roadmap?" BA and PM functions. |
| Domain | Technology scanning within the domain's scope. "Is there a new Rust crate that would replace our hand-rolled parser?" "Did Sigma release a new version with features we should support?" |
| Delivery | Discovery during implementation. "This approach won't scale to 100K EPS." "The library we chose has a security vulnerability." Delivery Findings are the S4 output at this tier. |

**The S3/S4 Homeostat:** At every tier, there's a tension between S3 (optimize what we're doing now) and S4 (adapt to what's changing). Product tier: should we optimize the current MVP plan or pivot based on a competitor move? Domain tier: should we finish the current epic or refactor based on what we learned? Delivery tier: should we implement the story as specified or raise a finding that the spec is wrong?

S5 at each tier mediates this tension.

### System 5 (Identity / Policy / Ethos): What We Are

| Tier | S5 Manifestation |
|------|-----------------|
| Product | The Product Brief. The non-negotiable identity of consumer-project: open-source, Rust-powered, detection-as-code, unified IT/OT, MSSP-first. When S3 and S4 conflict, S5 decides based on identity. |
| Domain | The domain's architectural intent — the "Josh Test." When a domain engineer faces a choice between two valid approaches, the domain's stated priorities (performance over flexibility? simplicity over feature-richness?) guide the decision. |
| Delivery | The story's acceptance criteria. When implementation could go several directions, the ACs define what "done" means. The ACs are S5 at the delivery level. |

---

## The Recursive Property

The VSM mapping confirms [@beer_1979]'s recursion: each tier IS a viable system containing the same five functions. A domain is not just "a piece of the product" — it's a viable system with its own operations (stories), coordination (branch strategy), control (domain lead review), audit (spot checks), intelligence (technology scanning), and identity (domain architecture).

This means:
- You don't need to design different governance for each tier. You design the governance pattern once and parameterize it for scope.
- When a new domain is created (e.g., splitting Platform into Auth and API), it inherits the full governance pattern.
- When a domain is too small to justify all five functions explicitly, some collapse (the domain lead is S3, S3*, and S5 in one person) — but the *functions* still exist, just consolidated.

---

## Algedonic Signals: Emergency Escalation

[@beer_1979; @beer_1985]'s algedonic signals bypass normal channels. They go directly from any level to S5 when something is critically wrong.

| Signal | From | To | Example |
|--------|------|----|---------|
| **Blocking Finding** | Delivery | Domain + Product | "The cross-domain contract for TenantContext is internally inconsistent. All crates are affected. Can't proceed." |
| **Architecture Break** | Domain | Product | "We discovered that the storage tier architecture can't achieve 100K EPS with the current design. Fundamental redesign needed." |
| **External Threat** | Any tier | Product | "Critical CVE in a core dependency. Affects all crates. Need immediate response." |
| **Scope Explosion** | Domain | Product | "Epic 3 (Detection Engine) is 3x larger than estimated. Sigma compatibility alone is 40 stories, not 8." |

**Response requirement:** Algedonic signals require acknowledgment within the current work day. They are not queued for the next review cycle.

---

## Open Questions for Channel Taxonomy (Input D)

1. **How are contracts enforced mechanically?** Rust trait definitions? Runtime test suites? Both?
2. **What is the minimum S3* audit cadence?** Every sprint? Every phase? Random?
3. **How does S4 (intelligence) operate in practice?** Is it a scheduled activity or triggered by delivery findings?
4. **Should domains have formal weekly syncs, or is async communication sufficient?** The answer likely depends on how coupled the domains are.
5. **Who mediates the S3/S4 homeostat at each tier?** At Product, it's the PM. At Domain, it's the domain lead. At Delivery, it's the engineer. Is this right?

---

## References

::: {#refs}
:::
