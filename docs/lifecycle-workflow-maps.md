# Pennyfarthing Workflow Visual Maps

## Terminology

**BikeLane** is the workflow engine. It orchestrates three types of workflows:

| Type | Description | Examples |
|------|-------------|----------|
| **Stepped** | Progressive disclosure with user gates. Human-paced, planning-oriented. | PRD, Architecture, Epics & Stories, Release |
| **Phased** | Agent-driven with automatic handoffs. Machine-paced, implementation-oriented. | TDD, BDD, Trivial, Patch |
| **Procedural** | Flexible checklists, no fixed sequence. Agent discretion on order. | Brainstorming, Code Review, Retrospective |

The full product lifecycle is not a single named workflow — it is a **chain of BikeLane workflows** that progresses from discovery through implementation to release. Each link in the chain is a standalone workflow that produces artifacts consumed by the next.

---

## 1. Full Product Lifecycle (Macro View)

This is the end-to-end chain. Each box is a separate BikeLane workflow. Stepped workflows are human-gated; phased workflows are agent-driven.

```mermaid
graph TD
    subgraph "DISCOVERY — Stepped Workflows"
        PB["Product Brief<br/><small>Agent: PM</small>"]
        R["Research<br/><small>Agent: Architect</small><br/><small>Modes: market / domain / technical</small>"]
        PRD["PRD<br/><small>Agent: PM</small><br/><small>Modes: create / validate / edit</small>"]
        UX["UX Design<br/><small>Agent: UX Designer</small>"]
    end

    subgraph "DESIGN — Stepped Workflows"
        ARCH["Architecture<br/><small>Agent: Architect</small><br/><small>7 steps, 3 gates</small>"]
        ES["Epics & Stories<br/><small>Agent: Architect</small><br/><small>→ sprint/future.yaml</small>"]
        PC["Project Context<br/><small>Agent: Architect</small><br/><small>→ project-context.md</small>"]
    end

    subgraph "PLANNING — Stepped Workflows"
        SP["Sprint Planning<br/><small>Agent: SM</small><br/><small>→ sprint-status.yaml</small>"]
        IR["Implementation Readiness<br/><small>Agent: SM</small><br/><small>Adversarial validation</small>"]
    end

    subgraph "IMPLEMENTATION — Phased Workflows"
        TDD["TDD / BDD / Trivial<br/><small>Agent chain: SM→TEA→Dev→Reviewer→SM</small>"]
        PATCH["Patch<br/><small>Agent: Dev (interrupt-driven)</small>"]
    end

    subgraph "COMPLETION — Stepped Workflows"
        GC["Git Cleanup<br/><small>Agent: Orchestrator</small>"]
        REL["Release<br/><small>Agent: SM</small><br/><small>13 steps, 5 gates</small>"]
    end

    PB --> R
    PB --> PRD
    R --> PRD
    R --> ARCH
    PRD --> UX
    PRD --> ARCH
    UX --> ARCH
    ARCH --> ES
    ARCH --> PC
    ES --> SP
    PC --> SP
    SP --> IR
    IR --> TDD
    TDD --> GC
    TDD -.->|"blocking bug"| PATCH
    PATCH -.->|"resume"| TDD
    GC --> REL
```

---

## 2. Discovery Phase Detail

```mermaid
graph LR
    subgraph "Product Brief"
        PB1["Collaborative discovery<br/>with user as peer"]
        PB2["→ sprint/planning/<br/>product-brief.md"]
    end

    subgraph "Research (tri-modal)"
        RM["Market Research<br/><small>Web search required</small>"]
        RD["Domain Research<br/><small>Web search required</small>"]
        RT["Technical Research<br/><small>Web search required</small>"]
    end

    subgraph "PRD (tri-modal)"
        PC["Create mode<br/><small>Gates at steps 2, 8, 12</small>"]
        PV["Validate mode"]
        PE["Edit mode"]
    end

    subgraph "UX Design"
        UX1["Discovery &<br/>emotional design"]
        UX2["Visual foundation &<br/>user journeys"]
        UX3["Component strategy &<br/>accessibility"]
    end

    PB2 --> RM
    PB2 --> RD
    PB2 --> RT
    RM --> PC
    RD --> PC
    RT --> PC
    PC --> PV
    PV --> PE
    PC --> UX1
    UX1 --> UX2
    UX2 --> UX3
```

---

## 3. Implementation Phased Workflows

### 3a. TDD (Default)

```mermaid
graph LR
    SETUP["SETUP<br/><small>Agent: SM</small><br/><small>Create session, branch,<br/>claim story</small>"]
    RED["RED<br/><small>Agent: TEA</small><br/><small>Write failing tests</small><br/><small>Gate: tests_fail</small>"]
    GREEN["GREEN<br/><small>Agent: Dev</small><br/><small>Implement to pass</small><br/><small>Gate: tests_pass</small>"]
    REVIEW["REVIEW<br/><small>Agent: Reviewer</small><br/><small>Adversarial review</small><br/><small>Gate: approval</small>"]
    FINISH["FINISH<br/><small>Agent: SM</small><br/><small>Archive, Jira sync</small>"]

    SETUP -->|"sm-handoff<br/>(Haiku)"| RED
    RED -->|"handoff<br/>(Haiku)"| GREEN
    GREEN -->|"handoff<br/>(Haiku)"| REVIEW
    REVIEW -->|"APPROVE"| FINISH
    REVIEW -->|"REJECT"| GREEN

    style RED fill:#fee,stroke:#c33
    style GREEN fill:#efe,stroke:#3a3
    style REVIEW fill:#eef,stroke:#33c
```

**Triggers:** `feature`, `enhancement`, 3+ story points, or `default: true`

### 3b. BDD

```mermaid
graph LR
    SETUP["SETUP<br/><small>Agent: SM</small>"]
    DESIGN["DESIGN<br/><small>Agent: UX Designer</small><br/><small>Spec, wireframes,<br/>behaviors</small><br/><small>Gate: design_review</small>"]
    RED["RED<br/><small>Agent: TEA</small><br/><small>Tests from behavior<br/>scenarios</small><br/><small>Gate: tests_fail</small>"]
    GREEN["GREEN<br/><small>Agent: Dev</small><br/><small>Implement UX spec</small><br/><small>Gate: tests_pass</small>"]
    REVIEW["REVIEW<br/><small>Agent: Reviewer</small><br/><small>Code + UX review</small><br/><small>Gate: approval</small>"]
    FINISH["FINISH<br/><small>Agent: SM</small>"]

    SETUP --> DESIGN
    DESIGN --> RED
    RED --> GREEN
    GREEN --> REVIEW
    REVIEW -->|"APPROVE"| FINISH
    REVIEW -->|"REJECT"| GREEN

    style DESIGN fill:#fef,stroke:#939
    style RED fill:#fee,stroke:#c33
    style GREEN fill:#efe,stroke:#3a3
    style REVIEW fill:#eef,stroke:#33c
```

**Triggers:** `ui`, `ux`, `behavior`, `component` types; `bdd`, `ux-first` tags; 2+ points

### 3c. Trivial

```mermaid
graph LR
    SETUP["SETUP<br/><small>Agent: SM</small>"]
    IMPL["IMPLEMENT<br/><small>Agent: Dev</small><br/><small>No TEA phase</small><br/><small>Gate: tests_pass</small>"]
    REVIEW["REVIEW<br/><small>Agent: Reviewer</small><br/><small>Gate: approval</small>"]
    FINISH["FINISH<br/><small>Agent: SM</small>"]

    SETUP --> IMPL
    IMPL --> REVIEW
    REVIEW -->|"APPROVE"| FINISH
    REVIEW -->|"REJECT"| IMPL

    style IMPL fill:#efe,stroke:#3a3
    style REVIEW fill:#eef,stroke:#33c
```

**Triggers:** `chore`, `fix`, `refactor` types; max 2 story points

### 3d. TDD-Tandem

```mermaid
graph LR
    SETUP["SETUP<br/><small>Agent: SM</small>"]
    RED["RED<br/><small>Primary: TEA</small><br/><small>Backseat: Architect</small><br/><small>Scope: file-watch</small>"]
    GREEN["GREEN<br/><small>Primary: Dev</small><br/><small>Backseat: TEA</small><br/><small>Scope: file-watch</small>"]
    REVIEW["REVIEW<br/><small>Primary: Reviewer</small><br/><small>Backseat: PM</small><br/><small>Scope: file-watch</small>"]
    FINISH["FINISH<br/><small>Agent: SM</small>"]

    SETUP --> RED
    RED --> GREEN
    GREEN --> REVIEW
    REVIEW -->|"APPROVE"| FINISH
    REVIEW -->|"REJECT"| GREEN

    style RED fill:#fee,stroke:#c33
    style GREEN fill:#efe,stroke:#3a3
    style REVIEW fill:#eef,stroke:#33c
```

**Tandem mechanism:** Backseat agent (Haiku, background) watches primary via `git diff` / file reads. Observations injected automatically through PostToolUse hook and bell-mode.

### 3e. BDD-Tandem

```mermaid
graph LR
    SETUP["SETUP<br/><small>Agent: SM</small>"]
    DESIGN["DESIGN<br/><small>Primary: UX Designer</small><br/><small>Backseat: Architect</small>"]
    RED["RED<br/><small>Primary: TEA</small><br/><small>Backseat: Architect</small>"]
    GREEN["GREEN<br/><small>Primary: Dev</small><br/><small>Backseat: UX Designer</small>"]
    REVIEW["REVIEW<br/><small>Primary: Reviewer</small><br/><small>Backseat: PM</small>"]
    FINISH["FINISH<br/><small>Agent: SM</small>"]

    SETUP --> DESIGN
    DESIGN --> RED
    RED --> GREEN
    GREEN --> REVIEW
    REVIEW -->|"APPROVE"| FINISH
    REVIEW -->|"REJECT"| GREEN

    style DESIGN fill:#fef,stroke:#939
    style RED fill:#fee,stroke:#c33
    style GREEN fill:#efe,stroke:#3a3
    style REVIEW fill:#eef,stroke:#33c
```

### 3f. 2Party-TDD (Story Refinement + TDD)

The most complex workflow. Pre-implementation brainstorming ensures story clarity before any code is written.

```mermaid
graph TD
    SETUP["SETUP<br/><small>Agent: SM</small>"]

    subgraph "Story Refinement (Party Mode)"
        P1["Party 1: What does Dev need?<br/><small>Perspectives: Dev, Architect, Reviewer</small>"]
        P2["Party 2: What does TEA need?<br/><small>Perspectives: TEA, Dev, Reviewer</small>"]
        QC["Quality Pass<br/><small>Story readiness check</small><br/><small>Gate: quality_pass</small>"]
    end

    subgraph "Implementation"
        RED["RED<br/><small>Agent: TEA</small>"]
        GREEN["GREEN<br/><small>Agent: Dev</small>"]
    end

    subgraph "Verification & Review"
        QA["QA Verification<br/><small>Agent: TEA</small><br/><small>All quality gates</small>"]
        REVIEW["REVIEW<br/><small>Agent: Reviewer</small><br/><small>+ PR lifecycle triage</small>"]
    end

    FINISH["FINISH<br/><small>Agent: SM</small>"]

    SETUP --> P1
    P1 --> P2
    P2 --> QC
    QC --> RED
    RED --> GREEN
    GREEN --> QA
    QA --> REVIEW
    REVIEW -->|"APPROVE"| FINISH
    REVIEW -->|"REJECT"| GREEN

    style P1 fill:#fff3e0,stroke:#e65100
    style P2 fill:#fff3e0,stroke:#e65100
    style QC fill:#fff3e0,stroke:#e65100
    style RED fill:#fee,stroke:#c33
    style GREEN fill:#efe,stroke:#3a3
    style REVIEW fill:#eef,stroke:#33c
```

### 3g. Agent-Docs

```mermaid
graph LR
    SETUP["SETUP<br/><small>Agent: SM</small>"]
    ANALYZE["ANALYZE<br/><small>Agent: Orchestrator</small><br/><small>Audit agent files</small>"]
    IMPL["IMPLEMENT<br/><small>Agent: Orchestrator</small><br/><small>Make changes</small>"]
    REVIEW["REVIEW<br/><small>Agent: Tech Writer</small><br/><small>Doc quality check</small>"]
    FINISH["FINISH<br/><small>Agent: SM</small>"]

    SETUP --> ANALYZE
    ANALYZE --> IMPL
    IMPL --> REVIEW
    REVIEW --> FINISH

    style ANALYZE fill:#fff3e0,stroke:#e65100
    style IMPL fill:#efe,stroke:#3a3
    style REVIEW fill:#eef,stroke:#33c
```

**Triggers:** `docs`, `refactor`, `infrastructure` types; `agent-file`, `process-improvement` labels

### 3h. Patch (Interrupt-Driven)

```mermaid
graph TD
    ACTIVE["Active Story Work<br/><small>(any workflow, any phase)</small>"]
    STASH["Stack State<br/><small>Branch from FEATURE branch</small><br/><small>Preserve workflow state</small>"]
    FIX["FIX<br/><small>Agent: Dev only</small><br/><small>No TEA, no review</small>"]
    MERGE["Merge to FEATURE<br/><small>(not develop)</small>"]
    RESTORE["Restore State<br/><small>TirePump context reload</small><br/><small>Resume previous workflow</small>"]

    ACTIVE -->|"/patch or /fix-blocker"| STASH
    STASH --> FIX
    FIX --> MERGE
    MERGE --> RESTORE
    RESTORE --> ACTIVE

    style FIX fill:#fee,stroke:#c33
    style STASH fill:#ffe,stroke:#993
    style RESTORE fill:#ffe,stroke:#993
```

---

## 4. Release Stepped Workflow

```mermaid
graph TD
    PRE["1. Preflight<br/><small>Verify clean state</small>"]
    BUMP["2. Version Bump"]
    G1{{"Gate 1"}}
    CL["3. Changelog"]
    G2{{"Gate 2"}}
    README["4. README"]
    CLAUDE["5. CLAUDE.md"]
    RETRO["6. Retro<br/><small>(optional)</small>"]
    COMMIT["7. Commit"]
    G3{{"Gate 3"}}
    MERGE["8. Merge"]
    PUSH["9. Push"]
    G4{{"Gate 4"}}
    PUB["10. Publish"]
    G5{{"Gate 5"}}
    FIN["11. Finalize"]

    PRE --> BUMP
    BUMP --> G1
    G1 --> CL
    CL --> G2
    G2 --> README
    README --> CLAUDE
    CLAUDE --> RETRO
    RETRO --> COMMIT
    COMMIT --> G3
    G3 --> MERGE
    MERGE --> PUSH
    PUSH --> G4
    G4 --> PUB
    PUB --> G5
    G5 --> FIN

    style G1 fill:#ffe,stroke:#993
    style G2 fill:#ffe,stroke:#993
    style G3 fill:#ffe,stroke:#993
    style G4 fill:#ffe,stroke:#993
    style G5 fill:#ffe,stroke:#993
```

Each gate pauses for user confirmation. Every destructive/irreversible step is gated.

---

## 5. Agent Hierarchy

```mermaid
graph TD
    subgraph "Strategic Agents (Full Project Scope)"
        ORC["Orchestrator<br/><small>Process improvement,<br/>multi-agent coordination</small>"]
        PM["PM<br/><small>Backlog, roadmap,<br/>prioritization</small>"]
        ARCH["Architect<br/><small>Design decisions,<br/>patterns, ADRs</small>"]
        DEVOPS["DevOps<br/><small>Infrastructure,<br/>CI/CD, deployment</small>"]
    end

    subgraph "Tactical Agents (Story-Scoped)"
        SM["SM<br/><small>Setup, finish,<br/>session management</small>"]
        TEA["TEA<br/><small>RED phase,<br/>failing tests</small>"]
        DEV["Dev<br/><small>GREEN phase,<br/>implementation</small>"]
        REV["Reviewer<br/><small>Adversarial<br/>code review</small>"]
    end

    subgraph "Support Agents"
        UX["UX Designer<br/><small>UI/UX design</small>"]
        TW["Tech Writer<br/><small>Documentation</small>"]
        BA["BA<br/><small>Requirements<br/>discovery</small>"]
    end

    subgraph "Subagents (Haiku)"
        SMS["sm-setup"]
        SMF["sm-finish"]
        SMH["sm-handoff"]
        HO["handoff"]
        TR["testing-runner"]
        RP["reviewer-preflight"]
    end

    SM --> SMS
    SM --> SMF
    SM --> SMH
    TEA --> HO
    DEV --> HO
    DEV --> TR
    REV --> RP
```

---

## 6. Handoff Protocol

```mermaid
sequenceDiagram
    participant SM as SM (Opus)
    participant Sub as Subagent (Haiku)
    participant Session as .session/
    participant TEA as TEA (Opus)

    SM->>SM: Complete setup phase
    SM->>Sub: Spawn sm-handoff subagent
    Sub->>Session: Write session file<br/>(phase: red, agent: tea)
    Sub->>Sub: Verify branch, Jira state
    Sub-->>SM: Return HANDOFF marker

    Note over SM,TEA: Relay Mode auto-executes<br/>or user confirms handoff

    TEA->>Session: Read session file
    TEA->>TEA: Load story context, AC
    TEA->>TEA: Write failing tests
    TEA->>Sub: Spawn handoff subagent
    Sub->>Session: Update (phase: green, agent: dev)
    Sub-->>TEA: Return HANDOFF marker
```

---

## 7. Tandem Protocol

```mermaid
sequenceDiagram
    participant Primary as Primary Agent (Opus)
    participant Hook as PostToolUse Hook
    participant Backseat as Backseat Agent (Haiku, bg)
    participant ObsFile as .session/*-tandem-*.md

    Note over Primary,Backseat: Phase starts

    Primary->>Primary: Begin work
    activate Backseat
    Backseat->>Backseat: Watch via git diff / file reads

    loop Every observation trigger
        Backseat->>ObsFile: Write observation
        Hook->>ObsFile: Detect new content
        Hook->>Primary: Inject via bell-mode
        Primary->>Primary: Surface in own voice
    end

    Primary->>Primary: Complete phase
    Primary->>Backseat: Terminate
    deactivate Backseat
    Primary->>Primary: Handoff to next phase
```

---

## 8. Workflow Selection Logic

```mermaid
graph TD
    STORY["Story assigned"]
    TAG{"Has explicit<br/>workflow: tag?"}
    MATCH{"Match trigger<br/>rules?"}
    DEFAULT["Use default<br/>(TDD)"]

    BDD_T{"Tags: bdd-tandem<br/>or ux-first + tandem?"}
    TDD_T{"Tags: tandem?"}
    BDD_C{"Types: ui, ux,<br/>component?"}
    TRIV{"Types: chore, fix?<br/>Max 2 points?"}
    DOCS{"Types: docs?<br/>Labels: agent-file?"}
    PARTY{"Tags: 2party?"}

    W_BDD_T["BDD-Tandem"]
    W_TDD_T["TDD-Tandem"]
    W_BDD["BDD"]
    W_TRIV["Trivial"]
    W_DOCS["Agent-Docs"]
    W_PARTY["2Party-TDD"]
    W_TDD["TDD"]

    STORY --> TAG
    TAG -->|"Yes"| W_TDD
    TAG -->|"No"| MATCH

    MATCH --> BDD_T
    BDD_T -->|"Yes"| W_BDD_T
    BDD_T -->|"No"| TDD_T
    TDD_T -->|"Yes"| W_TDD_T
    TDD_T -->|"No"| PARTY
    PARTY -->|"Yes"| W_PARTY
    PARTY -->|"No"| BDD_C
    BDD_C -->|"Yes"| W_BDD
    BDD_C -->|"No"| TRIV
    TRIV -->|"Yes"| W_TRIV
    TRIV -->|"No"| DOCS
    DOCS -->|"Yes"| W_DOCS
    DOCS -->|"No"| DEFAULT
    DEFAULT --> W_TDD
```

---

## 9. Complete Workflow Inventory

### Phased (8 workflows)

| Workflow | Flow | Trigger |
|----------|------|---------|
| **tdd** | SM → TEA → Dev → Reviewer → SM | Default; feature/enhancement, 3+ pts |
| **bdd** | SM → UX → TEA → Dev → Reviewer → SM | ui/ux/component types; bdd tag |
| **trivial** | SM → Dev → Reviewer → SM | chore/fix/refactor, max 2 pts |
| **tdd-tandem** | SM → TEA+Architect → Dev+TEA → Reviewer+PM → SM | tandem tag, 3+ pts |
| **bdd-tandem** | SM → UX+Architect → TEA → Dev+UX → Reviewer+PM → SM | bdd-tandem tag |
| **2party-tdd** | SM → Party(Dev) → Party(TEA) → QC → TEA → Dev → QA → Reviewer → SM | 2party tag |
| **agent-docs** | SM → Orchestrator → Orchestrator → Tech Writer → SM | docs type; agent-file label |
| **patch** | Dev only (interrupt, stack-based) | /patch or /fix-blocker command |

### Stepped (11 workflows)

| Workflow | Agent | Purpose | Output |
|----------|-------|---------|--------|
| **product-brief** | PM | Product discovery | product-brief.md |
| **research** | Architect | Market/domain/tech research | research.md |
| **prd** | PM | Requirements (create/validate/edit) | prd.md |
| **ux-design** | UX Designer | Visual design, accessibility | ux-design-specification.md |
| **architecture** | Architect | Technical design, 7 steps | architecture doc |
| **epics-and-stories** | Architect | PRD → epic/story breakdown | sprint/future.yaml |
| **project-context** | Architect | AI agent context rules | project-context.md |
| **sprint-planning** | SM | Sprint status generation | sprint-status.yaml |
| **implementation-readiness** | SM | Pre-implementation validation | readiness-report.md |
| **git-cleanup** | Orchestrator | Organize uncommitted changes | Clean commits |
| **release** | SM | Version, changelog, publish | Published package |

### Procedural (3+ workflows)

| Workflow | Agent | Purpose |
|----------|-------|---------|
| **brainstorming** | Any | 62 techniques, structured problem-solving |
| **code-review** | Reviewer | Review checklists |
| **retrospective** | SM | Sprint retrospective |
