# Feature Journey: From Concept to Archive

How a feature moves through the Pennyfarthing system — the files, states, and transitions that carry an idea from inception to completed work. Companion to [lifecycle-workflow-maps.md](lifecycle-workflow-maps.md) which covers agent workflows.

---

## 1. The Full Journey (Macro View)

A feature passes through five phases. Each phase produces artifacts consumed by the next.

```mermaid
graph TD
    subgraph "PHASE 1: DISCOVERY"
        direction TB
        IDEA["Idea / Problem"]
        PB["Product Brief<br/><small>→ sprint/planning/product-brief.md</small>"]
        RES["Research<br/><small>→ sprint/planning/research.md</small>"]
        PRD["PRD<br/><small>→ sprint/planning/prd.md</small>"]
        UX["UX Design<br/><small>→ sprint/planning/ux-design-specification.md</small>"]
    end

    subgraph "PHASE 2: DESIGN"
        direction TB
        ARCH["Architecture<br/><small>→ sprint/planning/architecture.md</small>"]
        ES["Epics & Stories<br/><small>→ sprint/future.yaml</small><br/><small>→ initiative-*.yaml</small>"]
    end

    subgraph "PHASE 3: SPRINT INTAKE"
        direction TB
        PROMOTE["Promote to Sprint<br/><small>pf sprint promote</small>"]
        SHARD["Epic Shard Created<br/><small>→ sprint/epic-PROJ-XXXXX.yaml</small>"]
        INDEX["Sprint Index Updated<br/><small>→ sprint/current-sprint.yaml</small>"]
    end

    subgraph "PHASE 4: IMPLEMENTATION"
        direction TB
        CLAIM["SM Claims Story<br/><small>→ .session/{id}-session.md</small>"]
        WORK["Agent Workflow<br/><small>TDD / BDD / Trivial</small>"]
        PR["PR Created<br/><small>→ feat/{id}-slug branch</small>"]
        REVIEW["Review & Merge"]
    end

    subgraph "PHASE 5: COMPLETION"
        direction TB
        FINISH["SM Finish<br/><small>pf sprint story finish</small>"]
        ARCHIVE_S["Session Archived<br/><small>→ sprint/archive/PROJ-XXXXX-session.md</small>"]
        ARCHIVE_E["Epic Archived<br/><small>(when all stories done)</small><br/><small>→ sprint/archive/epic-PROJ-XXXXX.yaml</small>"]
    end

    IDEA --> PB
    PB --> RES
    PB --> PRD
    RES --> PRD
    PRD --> UX
    PRD --> ARCH
    UX --> ARCH
    ARCH --> ES
    ES --> PROMOTE
    PROMOTE --> SHARD
    SHARD --> INDEX
    INDEX --> CLAIM
    CLAIM --> WORK
    WORK --> PR
    PR --> REVIEW
    REVIEW --> FINISH
    FINISH --> ARCHIVE_S
    FINISH --> ARCHIVE_E

    style IDEA fill:#fff3e0,stroke:#e65100
    style ARCHIVE_S fill:#e8f5e9,stroke:#2e7d32
    style ARCHIVE_E fill:#e8f5e9,stroke:#2e7d32
```

---

## 2. Story State Machine

Every story follows this state machine. Transitions are enforced by `pf sprint story` commands — never by direct YAML edits.

```mermaid
stateDiagram-v2
    [*] --> backlog : Story created

    backlog --> in_progress : SM claims story
    backlog --> canceled : Story dropped

    in_progress --> in_review : PR submitted for review
    in_progress --> canceled : Story abandoned

    in_review --> done : Reviewer approves + merges
    in_review --> canceled : Story abandoned

    done --> [*] : Archived

    canceled --> [*] : Terminal state

    note right of backlog
        Fields set: id, title, points,
        priority, status, workflow
    end note

    note right of in_progress
        Fields added: assigned_to,
        started, repos
        Session created, branch created
    end note

    note right of in_review
        Fields added: pr
        PR open on GitHub
    end note

    note right of done
        Fields added: completed,
        review_verdict, delivered_in
        Session archived, branch deleted
    end note
```

---

## 3. Sprint File Structure

Sprint data is **sharded** — the index file references epic shards by Jira key, and each shard contains its own stories. The loader merges them transparently.

```mermaid
graph TD
    subgraph "sprint/"
        CSY["current-sprint.yaml<br/><small>Sprint metadata +<br/>epic refs (string list)</small>"]
        E1["epic-PROJ-15676.yaml<br/><small>Epic dict + stories[]</small>"]
        E2["epic-PROJ-15680.yaml<br/><small>Epic dict + stories[]</small>"]
        E3["epic-PROJ-15685.yaml<br/><small>Epic dict + stories[]</small>"]
        FUT["future.yaml<br/><small>initiatives[] refs</small>"]
        I1["initiative-tech-debt.yaml<br/><small>Initiative details +<br/>standalone_stories[]</small>"]
    end

    subgraph "sprint/archive/"
        ARC["sprint-2608-completed.yaml<br/><small>completed_epics[] +<br/>completed_stories[]</small>"]
        AE1["epic-PROJ-15680.yaml<br/><small>Archived epic shard</small>"]
        AS1["PROJ-15695-session.md<br/><small>Archived session</small>"]
    end

    subgraph ".session/"
        SESS["129-6-session.md<br/><small>Active work session</small>"]
    end

    CSY -->|"refs"| E1
    CSY -->|"refs"| E2
    CSY -->|"refs"| E3
    FUT -->|"refs"| I1

    E2 -.->|"epic complete"| AE1
    SESS -.->|"story finish"| AS1
    E2 -.->|"sprint close"| ARC

    style CSY fill:#e3f2fd,stroke:#1565c0
    style FUT fill:#fff3e0,stroke:#e65100
    style ARC fill:#e8f5e9,stroke:#2e7d32
    style SESS fill:#fce4ec,stroke:#c62828
```

### Sprint Index (`current-sprint.yaml`)

```yaml
sprint:
  name: "TO Sprint 2608"
  jira_sprint_id: 310
  goal: "Installation, agents and workflows"
  start_date: '2026-02-16'
  end_date: '2026-03-01'
  status: active

epics:              # String refs → shard files
  - PROJ-15676
  - PROJ-15680
  - PROJ-15685

stories: []         # Orphan stories (not in epics)
standalone_stories: []
```

### Epic Shard (`epic-PROJ-15680.yaml`)

```yaml
id: '129'
type: epic
title: 'Epic: Hook System & Installation'
priority: P1
status: in_progress
jira: PROJ-15680
repos: pennyfarthing
points: 16
stories:
  - id: 129-1
    jira: PROJ-15681
    title: Story title here
    points: 2
    priority: P1
    status: done
    workflow: tdd
    completed: '2026-02-20'
  - id: 129-2
    # ...more stories
```

---

## 4. Initiative → Sprint → Archive Flow

The file-level journey of a feature from future backlog to archived history.

```mermaid
sequenceDiagram
    participant F as sprint/future.yaml
    participant I as initiative-*.yaml
    participant C as current-sprint.yaml
    participant E as epic-PROJ-*.yaml
    participant S as .session/{id}-session.md
    participant A as sprint/archive/

    Note over F,I: Phase 2: Design output
    F->>I: Initiative file created<br/>with epics & stories

    Note over F,C: Phase 3: Sprint intake
    I->>E: pf sprint promote<br/>Creates epic shard file
    C->>C: Epic ref added to index

    Note over E,S: Phase 4: Implementation
    E->>E: Story status: backlog → in_progress
    S->>S: Session file created<br/>by SM setup phase
    E->>E: Story status: in_progress → done

    Note over S,A: Phase 5: Completion
    S->>A: pf sprint story finish<br/>Session archived
    E->>E: Check: all stories done?

    alt All stories done
        E->>A: Epic shard moved to archive
        C->>C: Epic ref removed from index
    else Stories remaining
        E->>E: Epic stays in sprint
    end
```

---

## 5. BikeLane Workflow Selection

When a story enters implementation, BikeLane selects the orchestration pattern. The story's `workflow` field determines which agent chain runs.

```mermaid
graph TD
    STORY["Story enters<br/>implementation"]
    HAS_WF{"workflow: field<br/>set in YAML?"}

    subgraph "Explicit Selection"
        USE_WF["Use specified workflow"]
    end

    subgraph "Auto-Selection (SM Fallback)"
        PTS{"Story points?"}
        TYPE{"Story type?"}
        SM_TDD["tdd"]
        SM_TRIV["trivial"]
    end

    subgraph "Phased Workflows"
        direction TB
        WF_TDD["tdd<br/><small>SM → TEA → Dev → TEA → Rev → SM</small>"]
        WF_BDD["bdd<br/><small>SM → UX → TEA → Dev → Rev → SM</small>"]
        WF_TRIV["trivial<br/><small>SM → Dev → Rev → SM</small>"]
        WF_PATCH["patch<br/><small>Dev only (interrupt)</small>"]
        WF_ADOCS["agent-docs<br/><small>SM → Orch → TW → SM</small>"]
    end

    subgraph "Stepped Workflows"
        direction TB
        WF_PRD["prd<br/><small>PM leads, user-gated</small>"]
        WF_ARCH["architecture<br/><small>Architect leads, 7 steps</small>"]
        WF_ES["epics-and-stories<br/><small>Architect leads, 5 steps</small>"]
        WF_RES["research<br/><small>Architect leads, tri-modal</small>"]
        WF_REL["release<br/><small>SM leads, 13 steps</small>"]
    end

    STORY --> HAS_WF
    HAS_WF -->|"Yes"| USE_WF
    HAS_WF -->|"No"| PTS

    PTS -->|"1-2 pts"| TYPE
    PTS -->|"3+ pts"| SM_TDD

    TYPE -->|"chore / fix"| SM_TRIV
    TYPE -->|"feature / enhancement"| SM_TDD

    USE_WF --> WF_TDD
    USE_WF --> WF_BDD
    USE_WF --> WF_TRIV
    USE_WF --> WF_PATCH
    USE_WF --> WF_ADOCS
    USE_WF --> WF_PRD
    USE_WF --> WF_ARCH
    USE_WF --> WF_ES
    USE_WF --> WF_RES
    USE_WF --> WF_REL

    SM_TDD --> WF_TDD
    SM_TRIV --> WF_TRIV

    style WF_TDD fill:#e8f5e9,stroke:#2e7d32
    style WF_BDD fill:#e8f5e9,stroke:#2e7d32
    style WF_TRIV fill:#e8f5e9,stroke:#2e7d32
    style WF_PRD fill:#e3f2fd,stroke:#1565c0
    style WF_ARCH fill:#e3f2fd,stroke:#1565c0
```

### Phased vs Stepped

| Aspect | Phased | Stepped |
|--------|--------|---------|
| **Pacing** | Machine-driven | Human-gated |
| **Agents** | Chain with handoffs | Single agent guides user |
| **Gates** | Automatic quality checks | User confirms at each gate |
| **Session** | `.session/{id}-session.md` | BikeLane step tracking |
| **Purpose** | Implementation | Discovery & planning |
| **Start** | `pf sprint work {id}` | `/pf-workflow start {name}` |

---

## 6. Session File Lifecycle

The session file is the heartbeat of an active story. It tracks which agent owns the current phase and records each agent's assessment.

```mermaid
stateDiagram-v2
    [*] --> Created : SM setup phase

    state Created {
        [*] --> Writing
        Writing : sm-setup writes<br/>story details, workflow,<br/>branches, context
    }

    Created --> Active : Handoff to first agent

    state Active {
        [*] --> PhaseN
        PhaseN : Agent reads session<br/>Does work<br/>Writes assessment
        PhaseN --> PhaseN : Handoff updates<br/>Phase: field
    }

    Active --> Finishing : All phases complete

    state Finishing {
        [*] --> Preflight
        Preflight : sm-finish checks<br/>PR merged, tests pass
        Preflight --> Archive
        Archive : Moved to<br/>sprint/archive/
    }

    Finishing --> [*] : Session file removed<br/>from .session/
```

### Session File Structure

```
.session/129-6-session.md
├── Story Details (ID, Jira, Workflow, Assigned)
├── Description
├── Workflow Tracking
│   ├── Phase: (current phase)
│   ├── Phase Started: (ISO timestamp)
│   └── Phase History (table of all phases)
├── SM Assessment
├── TEA Assessment
├── Dev Assessment
├── TEA Verify Assessment
└── Reviewer Assessment
```

---

## 7. Epic Lifecycle

Epics are containers for related stories. They live as shard files alongside the sprint index.

```mermaid
stateDiagram-v2
    [*] --> Future : Created in initiative

    state Future {
        [*] --> Planned
        Planned : Lives in initiative-*.yaml<br/>Referenced from future.yaml
    }

    Future --> Sprint : pf sprint promote

    state Sprint {
        [*] --> backlog
        backlog : Epic shard created<br/>epic-PROJ-XXXXX.yaml
        backlog --> in_progress : First story claimed
        in_progress : Stories being worked
        in_progress --> done : All stories done/canceled
    }

    Sprint --> Archived : pf sprint epic archive

    state Archived {
        [*] --> Stored
        Stored : Shard moved to sprint/archive/<br/>Ref removed from index<br/>Added to sprint-YYWW-completed.yaml
    }

    Archived --> [*]

    note right of Future
        File: initiative-{slug}.yaml
        Ref: sprint/future.yaml
    end note

    note right of Sprint
        File: sprint/epic-PROJ-XXXXX.yaml
        Ref: sprint/current-sprint.yaml
    end note

    note right of Archived
        File: sprint/archive/epic-PROJ-XXXXX.yaml
        Ref: sprint/archive/sprint-YYWW-completed.yaml
    end note
```

---

## 8. The Handoff Chain (TDD Example)

How control passes between agents during a TDD story, with the files touched at each step.

```mermaid
sequenceDiagram
    participant SM as SM<br/>(Carrot)
    participant TEA as TEA<br/>(Igor)
    participant Dev as Dev<br/>(Ponder)
    participant Rev as Reviewer<br/>(Granny)
    participant Files as Files Changed

    rect rgb(255, 243, 224)
        Note over SM: SETUP PHASE
        SM->>Files: Create .session/{id}-session.md
        SM->>Files: Create branch feat/{id}-slug
        SM->>Files: Update epic shard (status: in_progress)
        SM->>SM: pf handoff complete-phase setup red
        SM->>SM: pf handoff marker tea
    end

    rect rgb(255, 235, 238)
        Note over TEA: RED PHASE
        TEA->>Files: Write failing tests
        TEA->>Files: Write assessment to session
        TEA->>TEA: Gate: tests_fail (all tests fail correctly)
        TEA->>TEA: pf handoff complete-phase red green
        TEA->>TEA: pf handoff marker dev
    end

    rect rgb(232, 245, 233)
        Note over Dev: GREEN PHASE
        Dev->>Files: Implement to make tests pass
        Dev->>Files: Push branch, create PR
        Dev->>Files: Write assessment to session
        Dev->>Dev: Gate: dev_exit (tests green, clean tree)
        Dev->>Dev: pf handoff complete-phase green verify
        Dev->>Dev: pf handoff marker tea
    end

    rect rgb(227, 242, 253)
        Note over TEA: VERIFY PHASE
        TEA->>TEA: Run lint, typecheck, all tests
        TEA->>Files: Write verify assessment
        TEA->>TEA: Gate: quality_pass
        TEA->>TEA: pf handoff complete-phase verify review
        TEA->>TEA: pf handoff marker reviewer
    end

    rect rgb(237, 231, 246)
        Note over Rev: REVIEW PHASE
        Rev->>Rev: Adversarial code review
        Rev->>Files: Write review verdict to session
        Rev->>Rev: Gate: approval
        Rev->>Rev: pf handoff complete-phase review finish
        Rev->>Rev: pf handoff marker sm
    end

    rect rgb(232, 245, 233)
        Note over SM: FINISH PHASE
        SM->>Files: Merge PR (squash)
        SM->>Files: Archive session to sprint/archive/
        SM->>Files: Update epic shard (status: done)
        SM->>Files: Remove .session/{id}-session.md
        SM->>SM: pf sprint story finish {id}
    end
```

---

## Cross-Reference

| Topic | Document |
|-------|----------|
| Agent workflows and selection logic | [lifecycle-workflow-maps.md](lifecycle-workflow-maps.md) |
| Tier definitions (discovery → implementation) | [lifecycle-tier-definitions.md](lifecycle-tier-definitions.md) |
| Tier work products | [lifecycle-tier-work-products.md](lifecycle-tier-work-products.md) |
| Pre-epic sketch conventions | [pre-epic-sketch-convention.md](../../conventions/pre-epic-sketch-convention.md) |
| BikeLane engine details | `pennyfarthing/pennyfarthing-dist/guides/bikelane.md` |
| Handoff CLI reference | `pennyfarthing/pennyfarthing-dist/guides/handoff-cli.md` |
| Gate system | `pennyfarthing/pennyfarthing-dist/guides/gates.md` |
