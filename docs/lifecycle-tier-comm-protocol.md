---
bibliography: ../references.bib
csl: chicago-author-date.csl
---

# Tier Communication Protocol

**Initiative:** Lifecycle Composition
**Date:** 2026-02-14
**Agent:** BA (Avasarala)
**Version:** 0.1 (first draft — will not survive contact with reality)
**Depends On:** Input A (Work Products), Input B+C (Tier Definitions + VSM Mapping)
**Index:** `lifecycle-composition-index.md`

---

## Design Principles

1. **Structural over conversational.** Prefer mechanisms (contracts, types, CI checks) over meetings. Conversations are S4 (intelligence); mechanisms are S2 (coordination).
2. **Upward flow is as important as downward flow.** Every downward channel (spec → implementation) has a corresponding upward channel (finding → spec amendment).
3. **Algedonic signals bypass everything.** Emergency escalation goes direct to the tier that can resolve it.
4. **Async by default, sync by exception.** Most communication is written artifacts. Synchronous communication is reserved for S3/S4 homeostat decisions (ambiguous situations where judgment is needed).
5. **The protocol is a hypothesis.** It will be revised after the first sprint of actual use.

---

## Part I: Channel Taxonomy

### Channel Types

Seven channel types, derived from [@beer_1979] VSM communication channels, [@mcchrystal_etal_2015] shared consciousness model, and the gap analysis of the current Pennyfarthing handoff system.

| # | Channel | Beer Equivalent | Direction | Mode | Purpose |
|---|---------|----------------|-----------|------|---------|
| 1 | **Intent** | S5 → S1 | Down | Async | Communicating what to build and why. Specs, contracts, design rules. |
| 2 | **Coordination** | S2 | Lateral | Structural | Preventing clashes between parallel work. Contracts, CI, type system, branch strategy. |
| 3 | **Status** | S1 → S3 | Up | Async | Reporting progress, completion, metrics. Story status, sprint progress, DORA metrics. |
| 4 | **Finding** | S4 (at lower tier) | Up | Async | Reporting discoveries. Delivery Findings, Spec Correction Requests. |
| 5 | **Audit** | S3* | Down (sporadic) | Async/Sync | Verifying ground truth. Fitness functions, spot-check reviews, drift detection. |
| 6 | **Query** | *New* | Both | Sync | Requesting clarification or a decision. "Is this the right interpretation of AC-3?" |
| 7 | **Alert** | Algedonic | Up (bypass) | Sync | Emergency escalation. Blocking findings, architecture breaks, external threats. |

### Channel Details

#### Channel 1: Intent (Down)

**What flows:** Specifications, contracts, design rules, architectural decisions, acceptance criteria.

**Product → Domain:**
- Cross-Domain Interface Contracts (new or amended)
- Product Design Rules (new or amended)
- Product Architecture decisions (ADRs)
- Phase strategy and epic assignments
- Responses to Spec Correction Requests (amendment or rejection with rationale)

**Domain → Delivery:**
- Story Specifications (goal, ACs, constraints, domain context)
- Domain Architecture excerpts relevant to the story
- Applicable contracts and design rules
- The "Josh Test" guidance for the story's decision space
- Responses to Delivery Findings (resolution or escalation notice)

**Format:** Markdown documents in the repository, versioned with git. Amendments are tracked through version history.

**Trigger:** Sprint planning (routine), architecture change (event-driven), SCR response (event-driven).

**Latency:** Hours to days. Intent is deliberate, not real-time.

#### Channel 2: Coordination (Lateral)

**What flows:** Structural mechanisms that prevent parallel work from conflicting.

**Between Domains:**
- Cross-Domain Interface Contracts (the contract IS the coordination mechanism)
- Contract change notifications (when a domain proposes a contract amendment, all consuming domains are notified)
- Shared CI pipeline that verifies contract compliance across crate boundaries
- Branch strategy for cross-domain changes (feature branches that touch multiple crates require coordinated merge)

**Between Delivery Units (within a domain):**
- Module ownership within the crate (informal, but explicit: "I'm working in the rule_parser module this sprint")
- Git branch conventions (feature branches per story, merge to domain integration branch)
- Type system as coordination (Rust's trait definitions and type signatures prevent many integration conflicts at compile time)
- Shared test fixtures and mocks (domain-level test infrastructure)

**Format:** Contracts (markdown + Rust traits). CI configuration. Git conventions documented in domain architecture.

**Trigger:** Continuous (CI runs on every push). Event-driven (contract change proposals).

**Latency:** Seconds (CI), hours (contract change review).

**Key insight:** Coordination is the channel most naturally handled by machinery rather than people. Rust's type system, the CI pipeline, and contract compliance tests do most of the S2 work. Human coordination is needed only when the machinery can't decide — which is the Query channel.

#### Channel 3: Status (Up)

**What flows:** Progress information, completion signals, metrics.

**Delivery → Domain:**
- Story completion (tests pass, PR submitted, review requested)
- Sprint burndown (stories completed vs planned)
- Blocked status (with reason — may trigger a Finding or Alert)
- Implementation metrics (test coverage, build time, code size)

**Domain → Product:**
- Epic progress (stories completed / total, velocity)
- Domain health metrics (integration test pass rate, contract compliance, tech debt indicators)
- Sprint summary (what was delivered, what slipped, why)
- DORA metrics aggregated to domain level

**Format:** Automated where possible (Jira status, CI dashboard, git activity). Narrative summary for sprint reviews.

**Trigger:** Story completion (event-driven). Sprint boundary (cadence-driven). On request (pull).

**Latency:** Story completion: immediate. Sprint summary: end of sprint. Metrics: continuous/dashboard.

#### Channel 4: Finding (Up)

**What flows:** Discoveries that challenge or extend the current specifications.

**Delivery → Domain (Delivery Finding):**

```yaml
finding:
  id: DF-{STORY_ID}-{SEQ}
  type: gap | conflict | question | improvement
  source:
    story: MSSCI-XXXX
    phase: red | green | review
    person: {name}
  affected_spec:
    tier: domain | product
    artifact: "{document name or section}"
  description: |
    {What was discovered}
  proposed_action: |
    {What should change, if known}
  urgency: blocking | non-blocking
  workaround: |
    {What was done to continue, if non-blocking}
```

**Domain → Product (Spec Correction Request):**

```yaml
scr:
  id: SCR-{DOMAIN}-{SEQ}
  source_findings:
    - DF-{ID}
    - DF-{ID}
  affected_spec:
    tier: product
    artifact: "{contract, design rule, architecture decision, or PRD section}"
  description: |
    {What needs to change at the product level}
  impact_assessment: |
    {Which domains and stories are affected}
  proposed_correction: |
    {What the spec should say instead}
  urgency: blocking | degraded | advisory
```

**Response requirement:**
- Blocking findings: acknowledged within 4 hours, resolution plan within 1 business day
- Non-blocking findings: triaged within the current sprint
- SCRs: reviewed at next product-tier review or within 1 week, whichever is sooner

**Routing:**
1. Delivery Finding → Domain lead triages
2. If domain-scoped: domain lead resolves, amends domain architecture, notifies affected stories
3. If product-scoped: domain lead escalates as SCR → Product tier
4. Product tier reviews SCR, amends contract/rule/architecture, notifies all affected domains

#### Channel 5: Audit (Down, Sporadic)

**What flows:** Verification requests and results that bypass normal reporting.

**Product → Domain:**
- Architecture compliance audit: "Run the fitness function suite and report results"
- Drift detection: "Compare current implementation against architecture spec X"
- Random deep review: "Review story MSSCI-1234 for architectural compliance, not just code correctness"

**Domain → Delivery:**
- Spot-check review: domain lead reviews a completed story in depth, beyond normal code review
- Mutation testing run: verify test quality, not just test passage
- Contract compliance spot-check: verify a specific contract is actually honored in implementation

**Format:** Audit request (informal — a message or ticket). Audit result (structured report with findings, which may generate Delivery Findings or SCRs).

**Trigger:** Sporadic by design. Not every sprint. Suggested: at least once per phase (MVP, Growth, Expansion) at the product level; at least once per epic at the domain level.

**Latency:** Days. Audits are not urgent — they are investigative.

#### Channel 6: Query (Both Directions)

**What flows:** Questions requiring human judgment. Clarification requests. Decision requests.

**Delivery → Domain:**
- "AC-3 says 'support Sigma rules with 90% compatibility.' Which 10% is excluded? I need a decision to write tests."
- "The domain architecture says use approach X, but I've found approach Y is 3x faster. Permission to deviate?"
- "Two stories in this sprint modify the same module. Who goes first?"

**Domain → Product:**
- "The Detection domain needs to extend the OCSF schema with a custom field. This changes the cross-domain contract. Approve?"
- "Epic 3 is significantly larger than estimated. Should we split it or extend the timeline?"

**Domain → Domain:**
- "We (Detection) need Storage to support a new query pattern for real-time rule evaluation. Is this feasible within the current sprint?"

**Format:** Direct communication. Slack message, PR comment, or in-person conversation. The query itself is informal; the *decision* that results is captured as an amendment to the relevant spec (domain architecture, contract, story AC).

**Trigger:** Event-driven. Someone has a question they can't answer from existing specs.

**Latency:** Hours. Queries should be answered within the current work day. If they can't be, the questioner should be unblocked with a workaround or the story should be paused.

**Key rule:** The answer to a Query must be *captured* in a spec amendment, not left as a Slack message. Decisions that live only in conversation are lost institutional knowledge. The query is ephemeral; the decision is permanent.

#### Channel 7: Alert (Up, Bypass)

**What flows:** Emergency signals that bypass normal routing.

**Any tier → Product:**
- "The Storage architecture cannot achieve 100K EPS. Fundamental design change needed."
- "Critical CVE in `tokio` affects all crates. Immediate response required."
- "Three domains have independently discovered the same contract inconsistency. This is systemic."

**Any tier → Domain:**
- "My story is blocked because the domain architecture contradicts the cross-domain contract. Can't proceed."
- "Tests are failing in CI for all stories in this domain. Build infrastructure issue."

**Format:** Direct, immediate communication. Slack @here, phone call, or in-person. Followed by a structured Finding or SCR for the record.

**Trigger:** Threshold — the person making the alert has determined that normal channels are too slow for the severity of the problem.

**Latency:** Acknowledgment within hours. Response plan within 1 business day.

**[@beer_1985] algedonic rule:** An alert that is not acknowledged within its expected latency automatically escalates to the next tier up. A delivery alert ignored by the domain escalates to the product tier. This prevents the "scream into the void" failure mode.

---

## Part II: Message Schema

All structured messages (Findings, SCRs, Contract amendments) share a common envelope:

```yaml
message:
  id: "{TYPE}-{SOURCE}-{SEQ}"
  channel: intent | coordination | status | finding | audit | query | alert
  timestamp: "{ISO 8601}"
  source:
    tier: product | domain | delivery
    domain: "{domain name, if applicable}"
    person: "{name}"
    story: "{JIRA key, if applicable}"
  target:
    tier: product | domain | delivery
    domain: "{domain name, if applicable}"
    person: "{name or role, if applicable}"
  urgency: blocking | degraded | routine | informational
  payload:
    type: "{channel-specific payload type}"
    # ... channel-specific fields
  response_expected: true | false
  response_deadline: "{ISO 8601, if response expected}"
```

**Implementation note:** This schema is for conceptual clarity. The actual implementation may be YAML files in the repo, Jira ticket fields, structured Slack messages, or a combination. The schema defines what information must be captured, not which tool captures it.

---

## Part III: Trigger and Cadence Rules

### Cadence-Driven (Scheduled)

| Event | Cadence | Channel | Participants |
|-------|---------|---------|-------------|
| Sprint planning | Biweekly | Intent (Domain → Delivery) | Domain lead + domain engineers |
| Sprint review | Biweekly | Status (Domain → Product) | All domains + PM/PO |
| Domain sync | Weekly | Query + Coordination (Domain ↔ Domain) | Domain leads |
| Product review | Monthly | Status + Finding (All → Product) | PM, PO, Architect, domain leads |
| SCR review | Biweekly or on accumulation | Finding (Domain → Product) | PM, Architect |
| Architecture audit | Per phase (3-4 months) | Audit (Product → Domain) | Architect + domain leads |

### Event-Driven (Triggered)

| Trigger | Channel | Action |
|---------|---------|--------|
| Story completed | Status | Delivery → Domain: story done, PR ready for review |
| Story blocked | Query or Alert | Delivery → Domain: need decision or escalation |
| Delivery Finding filed | Finding | Delivery → Domain: discovery needs triage |
| SCR filed | Finding | Domain → Product: spec change needed |
| Contract change proposed | Coordination | Domain → All consuming domains: review requested |
| Contract change approved | Intent | Product → All domains: updated contract, version bump |
| CI failure across domain | Alert | Domain → affected delivery units: investigate |
| Fitness function failure | Audit result | Product → Domain: architectural compliance issue |
| External threat (CVE, etc.) | Alert | Any → Product: immediate response needed |

### Threshold-Driven (Metric-Based)

| Threshold | Channel | Action |
|-----------|---------|--------|
| >3 Delivery Findings from same domain in one sprint | Finding escalation | Domain lead reviews for systemic spec issue → potential SCR |
| >2 stories blocked in same domain | Alert | Domain → Product: domain may need architectural attention |
| Contract compliance test failure rate >10% | Audit trigger | Product triggers architecture audit for affected domains |
| Sprint velocity <50% of planned | Status escalation | Domain → Product: capacity or spec issue |

---

## Part IV: Protocol Flows

### Flow 1: Normal Delivery (Happy Path)

```
Product ──[Intent: story spec]──→ Domain ──[Intent: story + context]──→ Delivery
                                                                          │
                                                                    [does the work]
                                                                          │
Delivery ──[Status: story complete]──→ Domain ──[Status: sprint progress]──→ Product
```

No findings, no queries, no alerts. The spec was right, the implementation matched, everyone's happy. This should be the most common flow.

### Flow 2: Delivery Discovers a Gap

```
Delivery ──[Finding: gap in AC-3]──→ Domain Lead
                                        │
                                   [triages: domain-scoped]
                                        │
Domain Lead ──[Intent: clarified AC-3]──→ Delivery
                                            │
                                      [resumes work]
```

The domain lead resolves the ambiguity by amending the story spec or domain architecture. The amendment is captured in the spec, not just communicated verbally.

### Flow 3: Delivery Discovers a Contract Problem

```
Delivery ──[Finding: OCSF schema missing OT field]──→ Domain Lead (OT)
                                                          │
                                                     [triages: product-scoped,
                                                      affects cross-domain contract]
                                                          │
Domain Lead ──[SCR: amend OCSF contract]──→ Product Tier
                                               │
                                          [reviews SCR]
                                               │
Product ──[Intent: amended contract v1.1]──→ All Domains
                                               │
                               ┌───────────────┼───────────────┐
                               ▼               ▼               ▼
                          Ingestion       Detection        Storage
                        [updates impl]  [updates impl]  [updates impl]
```

The contract change ripples through all domains that implement or consume the contract. Each domain assesses the impact on its in-progress stories and adjusts.

### Flow 4: Emergency Alert (Architecture Break)

```
Delivery ──[Alert: storage can't achieve 100K EPS]──→ Domain Lead (Storage)
                                                          │
Domain Lead ──[Alert: fundamental architecture issue]──→ Product Tier
                                                          │
                                                     [emergency review:
                                                      PM + Architect + domain leads]
                                                          │
Product ──[Intent: revised storage architecture ADR]──→ All affected domains
         [Intent: amended contracts]                      │
         [Status: affected stories paused]                │
                                                     [domains assess impact,
                                                      re-plan affected work]
```

Algedonic path: the alert went from Delivery to Domain to Product within a day. Normal channels would have taken a sprint or more.

### Flow 5: Cross-Domain Query

```
Domain Lead (Detection) ──[Query: need new Storage query pattern]──→ Domain Lead (Storage)
                                                                        │
                                                                   [assesses feasibility]
                                                                        │
Domain Lead (Storage) ──[Response: feasible, here's the interface]──→ Domain Lead (Detection)
                              │
                         [if interface changes contract:
                          proposes contract amendment ──→ Product tier]
```

Lateral communication between domain leads. If the answer changes a contract, it escalates to the Product tier for approval and propagation.

### Flow 6: Audit Cycle

```
Product ──[Audit: run fitness functions]──→ All Domains
                                              │
                                         [domains run fitness functions]
                                              │
All Domains ──[Audit Result: 2 violations in Platform, 1 in OT]──→ Product
                                                                       │
                                                                  [reviews results]
                                                                       │
Product ──[Finding → SCR or Intent: corrective action]──→ Affected domains
```

Sporadic, not every sprint. The audit bypasses normal status reporting to get ground truth on architectural compliance.

---

## Part V: Implementation Mapping

How this protocol maps to actual tools the team will use:

| Channel | Primary Tool | Secondary Tool | Record of Truth |
|---------|-------------|----------------|-----------------|
| Intent | Markdown docs in git repo | Jira epic/story descriptions | Git repo (versioned) |
| Coordination | Rust type system + CI | Cross-domain contract tests | CI pipeline + repo |
| Status | Jira board + sprint metrics | Slack standup thread | Jira |
| Finding | Structured YAML in `.findings/` directory | Jira ticket (type: Finding) | Git repo |
| Audit | Fitness function suite (CI job) | Manual review documented in repo | Git repo |
| Query | Slack channel (per-domain + cross-domain) | PR comments, in-person | Decision captured in spec amendment (git repo) |
| Alert | Slack @here + direct message | Phone/in-person | Followed by structured Finding in repo |

**The "capture rule":** Every decision made through a Query or Alert must be captured as a spec amendment in the git repo within 24 hours. The ephemeral channel (Slack, phone) is for speed; the repo is for permanence.

---

## Part VI: What This Protocol Does NOT Address (Known Gaps)

1. **Onboarding.** How does a new team member learn the protocol? Training doc needed.
2. **Tooling.** The Finding and SCR formats are defined but no tooling exists to create, route, or track them. A CLI command (`pf finding create`, `pf scr create`) would reduce friction.
3. **Metrics on the protocol itself.** How do we know if the protocol is working? Suggested: track finding-to-resolution time, SCR-to-amendment time, alert acknowledgment time. But this is meta-process and can wait.
4. **Graceful degradation.** When the team is small (first sprint, 3-4 people), most of these channels collapse. The full protocol is designed for 7-12 people across 7 domains. At 3-4 people, domains collapse, roles merge, and the protocol should shed complexity. How to scale down needs definition.
5. **AI agent integration.** This protocol is designed for a human team using LLM tooling. When/if Pennyfarthing agents operate within this protocol (e.g., an agent files a Delivery Finding automatically), the agent integration needs design. That's a separate concern.
6. **Conflict resolution.** When two domain leads disagree on a contract change, who decides? The protocol says "escalate to Product tier," but the Product tier may also disagree internally. PM/Architect escalation path needs definition.

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-02-14 | Initial draft. Research-based, untested. |

---

## References

::: {#refs}
:::
