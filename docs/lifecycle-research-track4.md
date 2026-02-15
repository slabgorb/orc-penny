# Research Track 4: Architectural Integrity and Integration in AI-Agent-Driven Development

**Date:** 2026-02-14
**Citation Style:** University of Chicago Author-Date (17th ed.)

---

## Track 4A: Architectural Drift and Change Propagation

### 1. Foundations: Software Architecture, Erosion, and Drift

The formal study of software architecture begins with Perry and Wolf's landmark paper, which defined software architecture as comprising three components: elements, form, and rationale. Elements are the processing, data, and connecting components of a system; form defines the properties of and relationships among those elements; and rationale captures the underlying design reasoning derived from system requirements (Perry and Wolf 1992, 40--42). Critically, Perry and Wolf introduced the distinction between two forms of architectural decay: "Erosion results from violating architectural principles while drift is caused by insensitivity to the architecture" (Perry and Wolf 1992, 50). Erosion is active damage, where a change directly contradicts an architectural rule. Drift is passive decay, where incremental changes accumulate without regard to the architecture's organizing principles, until the implemented system no longer resembles its intended design.

This distinction is foundational for AI-agent-driven spec-based development. When AI agents generate code from specifications, both forms of decay remain possible. An agent that misinterprets a specification and violates a layering constraint causes erosion. An agent that produces correct but architecturally indifferent code -- say, introducing a shortcut dependency that works but bypasses the intended abstraction -- causes drift. In a multi-agent parallel workflow, drift is the more insidious risk because no single change may be incorrect in isolation, but their accumulation degrades the system's coherence.

**Application to AI-agent-driven development:** If specifications are the source of truth, the Perry-Wolf framework suggests that erosion becomes detectable (spec violation) but drift requires continuous structural comparison between spec intent and implementation shape. Automated fitness functions and conformance checking become essential, not optional.

### 2. Architectural Degeneration

Lindvall and Tvedt extended these ideas by studying architectural degeneration empirically. They found that "software systems undergo constant change causing the architecture of the system to degenerate over time" and that "redirecting development effort toward reversing system degeneration takes extra effort and delays the release of the next version" (Lindvall and Tvedt 2002, 565). Their contribution was methodological: they defined two maintainability metrics -- "coupling-between-modules" (CBM) and "coupling-between-module-classes" (CBMC) -- to measure architectural degeneration quantitatively. Their empirical work demonstrated that degeneration is not an abstract risk but a measurable phenomenon that correlates with increased coupling and maintenance cost.

**Application to AI-agent-driven development:** When multiple agents produce code in parallel, the coupling metrics Lindvall defined become leading indicators of integration difficulty. An orchestrator that monitors CBM/CBMC across agent outputs could detect emergent coupling before integration, triggering architectural review before merging parallel work products.

### 3. Systematic Understanding of Architecture Erosion

Li et al. conducted the most thorough systematic mapping study of architecture erosion to date, analyzing 73 studies. They identified four categories of erosion symptoms: "structural symptoms (e.g., cyclic dependencies), violation symptoms (e.g., violation of the layered pattern), quality symptoms (e.g., high defect rate), and evolution symptoms (e.g., rigidity and brittleness of the software system)" (Li et al. 2022, 3). Their analysis found that "non-technical reasons that cause AEr should receive the same attention as technical reasons, and practitioners should raise awareness of the grave consequences of AEr" (Li et al. 2022, 4). Non-technical causes include organizational pressure, insufficient documentation, and developer turnover -- factors that manifest differently but no less acutely in AI-agent workflows.

De Silva and Balasubramaniam's earlier survey classified erosion-control strategies into three generic categories: "process-oriented architecture conformance, architecture evolution management, [and] architecture design enforcement" (de Silva and Balasubramaniam 2012, 133). They argue that "no single strategy can address the problem of erosion" and explore combining strategies (de Silva and Balasubramaniam 2012, 148). This layered defense approach maps directly to the lifecycle design challenge: spec validation (enforcement), agent workflow constraints (process orientation), and evolutionary spec management (evolution management) must all operate together.

### 4. Evolutionary Architecture and Fitness Functions

Ford, Parsons, and Kua introduced the concept of architectural fitness functions: "An architectural fitness function provides an objective integrity assessment of some architectural characteristic(s)" (Ford, Parsons, and Kua 2017, 5). Fitness functions employ tests, metrics, monitoring, and other mechanisms to protect architectural dimensions. Their framework distinguishes triggered versus continual, atomic versus holistic fitness functions.

The core insight is that "building an evolutionary architecture consists of three primary concerns: fitness functions, incremental change, and appropriate coupling" (Ford, Parsons, and Kua 2017, 6). Fitness functions are the automated equivalent of architectural vigilance -- they encode design intent as executable checks.

**Application to AI-agent-driven development:** Fitness functions are the natural bridge between specification intent and implementation reality. If each specification defines not only behavior but also architectural constraints (layering rules, dependency direction, performance bounds), then fitness functions derived from specifications become the automated verification layer that detects both erosion and drift across parallel agent outputs. An agent's work product is not merely "correct" if it passes unit tests; it must also pass fitness functions that verify architectural compliance.

### 5. Change Impact Analysis

Bohner and Arnold defined change impact analysis as "identifying the potential consequences of a change, or estimating what needs to be modified to accomplish a change" (Bohner and Arnold 1996, 3). Their taxonomy distinguished traceability-based impact analysis, which "captures links between requirements, specifications, design elements, and tests that can be analyzed to determine the scope of a change" (Bohner and Arnold 1996, 37), from dependency-based impact analysis, which traces implementation-level dependencies.

The ripple effect, first analyzed by Yau, Collofello, and MacGregor, provides a formal measure of change propagation: "the ripple effect which results as a consequence of program modification was analyzed, and a technique was developed to analyze this ripple effect from both functional and performance perspectives" (Yau, Collofello, and MacGregor 1978, 60). Subsequent work by Yau and Collofello defined stability measures based on tracing variable paths through programs (Yau and Collofello 1980, 354).

**Application to AI-agent-driven development:** When a specification changes, impact analysis determines which agents' work products are affected. In a parallel development model, ripple effect analysis becomes pre-integration work: before merging agent outputs, the orchestrator must trace specification changes through all downstream work products. Traceability matrices linking spec sections to agent work assignments, design elements, and tests enable this analysis.

### 6. Requirements Traceability

ISO/IEC/IEEE 29148:2018, which superseded IEEE 830, recommends "maintaining a requirements traceability mechanism to ensure consistency from stakeholder needs to final implementation and test" (ISO/IEC/IEEE 2018, sec. 5.2.8). A traceability matrix maps "artifacts of one type (e.g., requirements) depicted in columns to artifacts of another type (e.g., source code) depicted in rows" with cells visualizing traces between artifacts (ISO/IEC/IEEE 2018, sec. 5.2.8).

**Application to AI-agent-driven development:** In a spec-based multi-agent system, the traceability matrix extends naturally: specification sections trace to agent work assignments, which trace to generated code, which traces to tests. This four-level traceability enables both forward tracing (if a spec changes, what code and tests are affected?) and backward tracing (if a test fails, which spec and agent produced the failing code?).

### 7. Reflexion Models and Architecture Conformance Checking

Murphy, Notkin, and Sullivan developed the reflexion model technique to compare design intent against implementation reality. The technique "helps engineers perform various software engineering tasks by exploiting the drift between design and implementation, and assists engineers in comparing artifacts by summarizing where one artifact (such as a design) is consistent with and inconsistent with another artifact (such as source)" (Murphy, Notkin, and Sullivan 2001, 18). Reflexion models were applied to "an experimental reengineering of the million-lines-of-code Microsoft Excel product" (Murphy, Notkin, and Sullivan 2001, 19), demonstrating scalability.

Rosik et al. applied reflexion modelling to an in-vivo longitudinal case study and found that "although the utility of the approach for detecting inconsistencies was demonstrated in most cases, it also served to hide several inconsistencies and did not act as a trigger for their removal" (Rosik et al. 2011, 63). This finding is sobering: detection alone is insufficient. There must be a forcing function that requires remediation.

**Application to AI-agent-driven development:** Reflexion models provide the formal apparatus for comparing spec-level architecture against agent-generated implementation. The orchestrator maintains the high-level model (derived from specifications), extracts the source model (from generated code), and computes the reflexion model to find convergences, divergences, and absences. Rosik's finding implies that the system must not merely detect divergence but enforce resolution -- perhaps by blocking merges of agent work products that introduce reflexion-model violations.

### 8. Architecture Decision Records as Drift Anchors

Michael Nygard proposed Architecture Decision Records (ADRs) in 2011 as lightweight documentation of architecturally significant decisions. Each ADR captures "Context (describing forces at play), Decision (response to those forces), Status (such as 'proposed' or 'accepted'), and Consequences (describing the resulting context)" (Nygard 2011). Nygard defined architecturally significant decisions as those affecting "the structure, non-functional characteristics, dependencies, interfaces, or construction techniques" of the system (Nygard 2011).

Recent research by Posser and Teixeira extends this to AI-assisted engineering, arguing that "LLM coding assistants generate decisions faster than teams can validate them, yet no widely-adopted framework distinguishes conjecture from verified knowledge, prevents trust inflation through conservative aggregation, or detects when evidence expires" (Posser and Teixeira 2025, 1). They propose three requirements: "(1) epistemic layers that separate unverified hypotheses from empirically validated claims, (2) conservative assurance aggregation grounded in the Godel t-norm that prevents weak evidence from inflating confidence, and (3) automated evidence decay tracking that surfaces stale assumptions before they cause failures" (Posser and Teixeira 2025, 2).

**Application to AI-agent-driven development:** ADRs become drift anchors for agent workflows. Each architectural decision in the specification should have a corresponding ADR, and agents should be constrained to operate within ADR boundaries. Posser and Teixeira's epistemic framework suggests that agent-generated architectural decisions should be tagged with their validation status and tracked for temporal decay.

### 9. Technical Debt as Architectural Drift

Ward Cunningham introduced the technical debt metaphor at OOPSLA 1992: "Shipping first time code is like going into debt. A little debt speeds development so long as it is paid back promptly with a rewrite... The danger occurs when the debt is not repaid. Every minute spent on not-quite-right code counts as interest on that debt" (Cunningham 1992, 29). Kruchten, Nord, and Ozkaya systematized this into a landscape framework, identifying technical debt items, their causes, consequences, principal, interest, and timelines (Kruchten, Nord, and Ozkaya 2019, chs. 1--5). They argue that technical debt manifests not as a single form but across code, design, architecture, test, and documentation dimensions.

**Application to AI-agent-driven development:** AI agents that generate "good enough" code accumulate technical debt. In a parallel multi-agent system, debt accumulates multiplicatively: each agent's individual shortcuts compound when integrated. The Kruchten-Nord-Ozkaya framework provides the vocabulary for classifying the types of debt agents introduce and prioritizing repayment.

### 10. Automated Architecture Verification Tools

ArchUnit provides "a free, simple and extensible library for checking the architecture of your Java code using any plain Java unit test framework" that can "check dependencies between packages and classes, layers and slices, check for cyclic dependencies and more" (TNG Technology Consulting 2024). jQAssistant takes a different approach, analyzing code into a Neo4j graph database where "files, classes, interfaces, packages, fields, methods and annotations are created as nodes [with] connections represented by keywords such as CONTAINS, DEPENDS_ON, INVOKES, DECLARES, IMPLEMENTS and RETURNS" (Schwartau 2018).

**Application to AI-agent-driven development:** These tools provide the enforcement layer for architectural fitness functions. In an AI-agent pipeline, ArchUnit-style tests execute after each agent completes its work, verifying that the generated code respects architectural constraints before integration. jQAssistant's graph-based approach enables richer queries, such as detecting emergent coupling patterns across multiple agents' outputs.

### 11. Spec-Driven Development and Drift Dynamics

Piskala's recent arxiv paper argues that spec-driven development (SDD) "inverts the traditional workflow by treating specifications as the source of truth and code as a generated or verified secondary artifact" (Piskala 2026, 1). Under SDD, "drift is any divergence between declared system intent and observed system behavior [and] that divergence may be structural, behavioral, semantic, security-related, or evolutionary" (Piskala 2026, 5). The paper identifies three levels of specification rigor: "spec-first, spec-anchored, and spec-as-source" representing increasing levels of enforcement (Piskala 2026, 8).

The key insight for drift management is: "Once specifications become authoritative, drift detection is no longer a testing convenience; it becomes a mandatory architectural capability that turns intent into an invariant" (Piskala 2026, 12). Yet "drift detection can identify that a system has diverged, but it cannot, on its own, decide whether that divergence is acceptable, accidental, or desirable -- some drift represents defects, while other drift represents evolution" (Piskala 2026, 13).

**Application to AI-agent-driven development:** SDD reframes the drift problem from "implementation diverges from undocumented intent" to "implementation diverges from explicit specification." This is a fundamental improvement because the specification provides a machine-readable baseline against which agent outputs can be automatically compared. However, the human judgment requirement remains: when an agent's output diverges from spec, the system must determine whether the spec needs updating or the code needs correction.

### 12. Laws of Software Evolution

Lehman's laws of software evolution, distilled from empirical observation, state that "an E-type system must be continually adapted or it becomes progressively less satisfactory" and "as an E-type system evolves, its complexity increases unless explicit work is done to maintain or reduce it" (Lehman 1980, 1061--1062). These laws apply to any software that operates in a real-world context, and they predict that architectural drift is not a failure of discipline but a natural consequence of system evolution.

**Application to AI-agent-driven development:** Lehman's laws imply that even a perfectly specified system will experience drift as its operational context changes. The lifecycle must therefore include not only drift detection but also specification evolution mechanisms. The specification itself must evolve, and the system must track which parts of the implementation are aligned with current versus outdated specifications.

---

## Track 4B: Integration Problem Patterns (Conceptual Merge Conflicts)

### 1. The Feature Interaction Problem

The feature interaction problem, originally identified in telecommunications systems, describes the phenomenon where "features work individually but conflict when combined" (Calder et al. 2003, 115). Calder, Kolberg, Magill, and Reiff-Marganiec reviewed the state of the art, "concentrating on three major research trends: software engineering approaches, formal methods, and on line techniques" (Calder et al. 2003, 115). They observed that "in telecommunications with distributed control and data of large scale developed by numerous disjoint teams, this software experienced the feature interaction problem first" (Calder et al. 2003, 116).

The feature interaction problem is structural, not accidental. It arises whenever features are developed independently and combined later. Apel et al. extended this to software product lines, publishing work on "feature-interaction detection based on feature-based specifications" (Apel et al. 2013, 2399) and demonstrating that formal specification of features enables automated interaction detection.

**Application to AI-agent-driven development:** Multi-agent parallel development is precisely the scenario that produces feature interactions. Each agent works on a bounded feature, and conflicts emerge only at integration time. This is the telecommunications problem replicated at the code level. The specification must define not only individual feature behavior but also cross-feature interaction constraints. Without explicit interaction specifications, the orchestrator has no basis for detecting conflicts until runtime failures reveal them.

### 2. Architectural Mismatch

Garlan, Allen, and Ockerbloom identified "architectural mismatch" as "a type of incompatibility stemming from incompatible assumptions about the overall structure and operation of the system of which the component is a part" (Garlan, Allen, and Ockerbloom 1995, 17). Their case study of the Aesop project revealed that architectural mismatches are "usually more subtle and pervasive than low-level incompatibilities" and that they stem from "mismatched assumptions [that] are almost always implicit, making them extremely difficult to analyze before building the system" (Garlan, Allen, and Ockerbloom 1995, 18). The Aesop integration took "five times as long and five times as much effort to get working -- approximately five person-years of work during a two-and-a-half-year period" (Garlan, Allen, and Ockerbloom 1995, 20).

**Application to AI-agent-driven development:** AI agents carry implicit assumptions encoded in their training data and context windows. When two agents produce components that make different assumptions about threading models, error handling conventions, data ownership, or lifecycle management, architectural mismatch results. Explicit specification of these assumptions -- what Garlan called making the implicit explicit -- is the primary defense. Each agent's assignment must include not only functional requirements but also structural assumptions about the execution environment.

### 3. Information Hiding and Decomposition for Integration

Parnas's foundational principle holds that "every module in the second decomposition is characterized by its knowledge of a design decision which it hides from all others. More specifically, one begins with a list of difficult design decisions or design decisions which are likely to change. Each module is then designed to hide such a decision from the others" (Parnas 1972, 1056). This principle directly addresses integration: if modules hide their decisions well, integration surface area is minimized.

**Application to AI-agent-driven development:** The Parnas principle provides the decomposition strategy for assigning work to agents. Each agent should own a module boundary that encapsulates a design decision. The specification should define the interface contract (what the module reveals) and the agent should have freedom over the implementation (what the module hides). This minimizes the integration surface between agents and localizes the impact of any individual agent's implementation choices.

### 4. NASA/Aerospace Integration and Verification

NASA's systems engineering approach to integration relies on Interface Control Documents (ICDs) that "define and control all interface information generated for a project, including specifications for physical, electrical, mechanical, functional, and software interactions between system components" (NASA 2016, sec. 6.3). NASA's Lessons Learned Information System records that the Mars Pathfinder project experienced "problems during MPF spacecraft integration and test due to out-of-date or incomplete interface documentation" with "electrical connector discrepancies found between the MPF main wiring harness and circuit boards" (NASA LLIS 2000, lesson 569).

NASA-STD-8739.8 defines Independent Verification and Validation (IV&V) as "a technical discipline of SA, which employs rigorous analysis and testing methodologies identifying objective evidence and conclusions to provide an independent assessment of products and processes throughout the life cycle" (NASA 2022, sec. 4.1). The key word is "independent": verification is performed by a party separate from the development team.

DO-178C, the avionics software certification standard, mandates layered verification: "low-level [unit] tests, software integration tests, and hardware-software integration tests" addressing "the low-level testing, software integration testing and hardware/software testing perspectives" (RTCA 2012, sec. 6.4). Software is classified into five Design Assurance Levels from A (catastrophic failure consequence) to E (no effect), with verification rigor scaling to criticality.

**Application to AI-agent-driven development:** The NASA/aerospace model maps to multi-agent development as follows: ICDs become interface specifications between agent work boundaries; IV&V becomes an independent verification agent that reviews other agents' outputs without participating in their generation; and DO-178C's layered testing model maps to unit tests (per-agent), integration tests (cross-agent boundary), and system tests (full assembled product). The Mars Pathfinder lesson is directly applicable: interface specifications between agent boundaries must be kept current as work progresses.

### 5. Consumer-Driven Contract Testing

The Pact framework implements consumer-driven contract testing, defined as "a type of contract testing where a Consumer of a Provider service expresses its expectations about the Provider's behavior in a contract and shares the contract with the Provider [who] uses the given contract to verify that it meets the expectations" (Pact Foundation 2024). Pact "enables the identification of mismatches between consumer and provider early in the development process, reducing the likelihood of integration failures during later stages" (Pact Foundation 2024).

The contract serves as an intermediary that decouples provider and consumer development. "Since Pact tests are focused on the interactions between services, developers can get quicker feedback on whether a change in one service breaks the contract with another" (Pact Foundation 2024). The Pact Broker provides shared state for "integrating Pact into continuous integration and continuous delivery (CI/CD) pipelines" (Pact Foundation 2024).

**Application to AI-agent-driven development:** Consumer-driven contracts provide the mechanism for verifying integration across agent boundaries. When Agent A produces a component that Agent B consumes, Agent B's specification defines the contract. Agent A's output is verified against that contract independently of Agent B's work. This enables parallel development without deferring integration verification to the end. The orchestrator plays the role of the Pact Broker, maintaining contracts and verifying compliance.

### 6. Semantic Versioning for Internal Interfaces

Tom Preston-Werner's Semantic Versioning specification defines that version changes "convey meaning about the underlying code and what has been modified from one version to the next" with MAJOR versions for incompatible changes, MINOR for backwards-compatible additions, and PATCH for bug fixes (Preston-Werner 2013). Applied to internal component interfaces, semantic versioning enables independent teams to detect breaking changes before integration.

**Application to AI-agent-driven development:** When agents work on components with defined interfaces, semantic versioning of those interfaces provides a mechanical detection mechanism for breaking changes. If Agent A modifies a component's interface in a way that would require a MAJOR version bump, the orchestrator can identify all agents whose work depends on that interface and flag them for re-verification.

### 7. The Big Bang Integration Anti-Pattern

Big bang integration testing, where all components or modules are integrated and tested as a single unit after all modules have been completed, is widely recognized as an anti-pattern for complex systems because it does not allow for incremental testing, which means that errors can go undetected until all the modules are integrated and tested together, and it is not easy to detect the root cause of a particular defect since all the modules are integrated together already.

Incremental integration strategies -- top-down, bottom-up, and sandwich approaches -- provide alternatives where components are tested one at a time or in small groups, enabling earlier defect detection and easier root cause analysis.

**Application to AI-agent-driven development:** A naive multi-agent workflow that allows all agents to complete independently and then merges everything at once is a big bang integration. The lifecycle must instead define an integration order, where agent outputs are integrated incrementally as they become available, with verification at each integration step. This requires the orchestrator to model dependencies between agent work products and schedule integration accordingly.

### 8. Contract-First Design as Integration Insurance

Contract-first API design involves first defining the contract, and then implementing the service, using specifications like OpenAPI to share interface definitions between teams. The benefit is that developers get early feedback on API design before investing weeks in implementation, frontend and backend teams can work simultaneously instead of sequentially, and cross-team coordination improves when everyone references the same specification.

**Application to AI-agent-driven development:** Contract-first design is the native integration strategy for spec-driven multi-agent development. The specification defines all interface contracts before any agent begins work. Agents implement against contracts, not against each other's code. Integration verification becomes contract compliance verification, which can execute independently for each agent. This eliminates the need for agents to coordinate during development, while ensuring their outputs will integrate correctly.

### 9. Dependency Structure Matrices for Integration Analysis

Design Structure Matrices (DSMs) provide a simple, compact and visual representation of a system or project in the form of a square matrix that is used in systems engineering and project management to model the structure of complex systems. DSMs have been used widely to visualize the architecture of and measure the coupling between the components of individual software systems.

Baldwin and Clark's modularity framework argues that "the value of modular systems comes, in large part, from hidden subsystems" and that "dominating decisions, such as interfaces between components, [are] design rule decisions" that enable decoupled development (Baldwin and Clark 2000, 73). DSM analysis can identify clusters of tightly coupled components that should be assigned to a single agent, and loosely coupled clusters that can be developed in parallel.

**Application to AI-agent-driven development:** DSM analysis of the specification provides the basis for agent work assignment. Components that form a tight cluster in the DSM should be assigned to a single agent to avoid high-frequency cross-agent integration. Loose coupling between clusters enables parallel agent work. The DSM becomes the integration planning tool that determines the optimal decomposition of work across agents.

### 10. Architecture-Based Integration Testing

Muccini, Bertolino, and Inverardi proposed using "formal architectural descriptions to model the 'interesting' behavior of the software architecture, and derived a graph of all the possible behaviors of the system in terms of the interactions between its components" (Muccini, Bertolino, and Inverardi 2004, 235). Their approach generates integration test cases from architectural descriptions, ensuring that the tests cover the interaction patterns that the architecture prescribes.

**Application to AI-agent-driven development:** If the specification includes an architectural description with interaction patterns, integration tests can be derived before any agent writes code. These pre-generated integration tests become acceptance criteria for the integrated system. Agents produce components; the orchestrator runs architecture-derived integration tests against assembled components. This closes the loop between specification intent and integration verification.

### 11. Multi-Agent Integration: A New Class of Problem

He, Treude, and Lo's systematic review of LLM-based multi-agent systems for software engineering found that these systems "enable autonomous problem-solving, improving robustness, and providing scalable solutions for managing the complexity of real-world software projects" (He, Treude, and Lo 2025, 1). The review identified 41 primary studies across the software development lifecycle.

Mason observes that "Git worktrees enable multiple agents to work simultaneously without conflicts -- this is becoming the standard isolation mechanism" but that "agents excel at bounded tasks with clear acceptance criteria" while struggling with "anything requiring architectural judgment" (Mason 2026). The Google DORA Report finding that "90% AI adoption increase correlates with a 9% climb in bug rates, 91% increase in code review time, and 154% increase in PR size" (Mason 2026) suggests that multi-agent development amplifies integration problems rather than reducing them.

**Application to AI-agent-driven development:** Multi-agent parallel code generation introduces a new class of integration problem that combines feature interaction, architectural mismatch, and contract violation in a single workflow. The orchestrator must simultaneously manage: (a) feature interactions between agents' behavioral contributions, (b) architectural mismatch between agents' structural assumptions, and (c) contract violations between agents' interface expectations. No single existing technique addresses all three; the lifecycle must compose techniques from telecommunications (feature interaction detection), systems engineering (ICDs and IV&V), microservices (contract testing), and architecture verification (reflexion models and fitness functions).

---

## Synthesis: Implications for Lifecycle Design

The research across both tracks converges on several principles for a lifecycle that coordinates AI agents working from specifications in parallel:

1. **Specifications must encode not only behavior but also architectural constraints.** Perry and Wolf's distinction between erosion and drift, combined with Ford et al.'s fitness functions, demonstrates that behavioral correctness is insufficient. Agents must be given constraints on structure, coupling, and dependency direction, encoded as executable checks.

2. **Integration must be incremental, not big bang.** The aerospace IV&V model, the big bang anti-pattern, and Mason's observations about multi-agent coherence all point to the same conclusion: parallel work products must be integrated and verified incrementally, not assembled at the end.

3. **Contracts between agent boundaries are the primary integration mechanism.** Pact's consumer-driven contracts, NASA's ICDs, and contract-first design all demonstrate that defining interfaces before implementation prevents the most severe integration problems.

4. **Drift detection requires both automated checking and human judgment.** Piskala's observation that "drift detection can identify that a system has diverged, but it cannot, on its own, decide whether that divergence is acceptable" means that the lifecycle must include human review points, not merely automated gates.

5. **Traceability from specification through agent assignment through implementation through test is essential.** ISO/IEC/IEEE 29148's traceability matrices, Bohner and Arnold's impact analysis, and Yau and Collofello's ripple effect analysis provide the formal tools for this traceability, which enables change propagation analysis when specifications evolve.

6. **The feature interaction problem is the dominant integration risk.** When agents implement features in parallel, Calder et al.'s feature interaction problem predicts that individually correct features will conflict when combined. The specification must define cross-feature interaction constraints, and the orchestrator must verify them at integration time.

---

## Bibliography

Apel, Sven, Alexander von Rhein, Thomas Thum, and Christian Kastner. 2013. "Feature-Interaction Detection Based on Feature-Based Specifications." *Computer Networks* 57 (12): 2399--2409.

Baldwin, Carliss Y., and Kim B. Clark. 2000. *Design Rules: The Power of Modularity*. Cambridge, MA: MIT Press.

Bass, Len, Paul Clements, and Rick Kazman. 2021. *Software Architecture in Practice*. 4th ed. Boston: Addison-Wesley.

Bohner, Shawn A., and Robert S. Arnold, eds. 1996. *Software Change Impact Analysis*. Los Alamitos, CA: IEEE Computer Society Press.

Calder, Muffy, Mario Kolberg, Evan H. Magill, and Stephan Reiff-Marganiec. 2003. "Feature Interaction: A Critical Review and Considered Forecast." *Computer Networks* 41 (1): 115--141.

Cunningham, Ward. 1992. "The WyCash Portfolio Management System." In *Addendum to the Proceedings of OOPSLA '92*, 29--30. New York: ACM.

de Silva, Lakshitha, and Dharini Balasubramaniam. 2012. "Controlling Software Architecture Erosion: A Survey." *Journal of Systems and Software* 85 (1): 132--151.

Ford, Neal, Rebecca Parsons, and Patrick Kua. 2017. *Building Evolutionary Architectures: Support Constant Change*. Sebastopol, CA: O'Reilly Media.

Garlan, David, Robert Allen, and John Ockerbloom. 1995. "Architectural Mismatch: Why Reuse Is So Hard." *IEEE Software* 12 (6): 17--26.

He, Junda, Christoph Treude, and David Lo. 2025. "LLM-Based Multi-Agent Systems for Software Engineering: Literature Review, Vision and the Road Ahead." *ACM Transactions on Software Engineering and Methodology* 34 (5): 1--30.

ISO/IEC/IEEE. 2018. *ISO/IEC/IEEE 29148:2018 Systems and Software Engineering -- Life Cycle Processes -- Requirements Engineering*. Geneva: International Organization for Standardization.

Kruchten, Philippe, Robert Nord, and Ipek Ozkaya. 2019. *Managing Technical Debt: Reducing Friction in Software Development*. Boston: Addison-Wesley.

Lehman, Meir M. 1980. "Programs, Life Cycles, and Laws of Software Evolution." *Proceedings of the IEEE* 68 (9): 1060--1076.

Li, Ruiyin, Peng Liang, Mohamed Soliman, and Paris Avgeriou. 2022. "Understanding Software Architecture Erosion: A Systematic Mapping Study." *Journal of Software: Evolution and Process* 34 (3): e2423.

Lindvall, Mikael, and Roseanne Tvedt. 2002. "An Empirically-Based Process for Software Architecture Evaluation." *Empirical Software Engineering* 7 (4): 563--573.

Mason, Mike. 2026. "AI Coding Agents in 2026: Coherence Through Orchestration, Not Autonomy." Blog post, January.

Muccini, Henry, Antonia Bertolino, and Paola Inverardi. 2004. "Using Software Architecture for Code Testing." *IEEE Transactions on Software Engineering* 30 (3): 160--171.

Murphy, Gail C., David Notkin, and Kevin J. Sullivan. 2001. "Software Reflexion Models: Bridging the Gap between Design and Implementation." *IEEE Transactions on Software Engineering* 27 (4): 364--380.

NASA. 2016. *NASA Systems Engineering Handbook*. Rev. 2. NASA/SP-2016-6105. Washington, DC: National Aeronautics and Space Administration.

NASA. 2022. *NASA-STD-8739.8B: Software Assurance and Software Safety Standard*. Washington, DC: National Aeronautics and Space Administration.

NASA Lessons Learned Information System (LLIS). 2000. "Interface Control and Verification." Lesson 569.

Nygard, Michael. 2011. "Documenting Architecture Decisions." Cognitect Blog, November 15.

Pact Foundation. 2024. "Introduction to Pact." https://docs.pact.io/.

Parnas, David L. 1972. "On the Criteria To Be Used in Decomposing Systems into Modules." *Communications of the ACM* 15 (12): 1053--1058.

Perry, Dewayne E., and Alexander L. Wolf. 1992. "Foundations for the Study of Software Architecture." *ACM SIGSOFT Software Engineering Notes* 17 (4): 40--52.

Piskala, Deepak Babu. 2026. "Spec-Driven Development: From Code to Contract in the Age of AI Coding Assistants." arXiv preprint arXiv:2602.00180.

Posser, Bruno, and Leonel Teixeira. 2025. "AI-Assisted Engineering Should Track the Epistemic Status and Temporal Validity of Architectural Decisions." arXiv preprint arXiv:2601.21116.

Preston-Werner, Tom. 2013. "Semantic Versioning 2.0.0." https://semver.org/.

Rosik, Jacek, Andrew Le Gear, Jim Buckley, Muhammad Ali Babar, and Dave Connolly. 2011. "Assessing Architectural Drift in Commercial Software Development: A Case Study." *Software: Practice and Experience* 41 (1): 63--86.

RTCA. 2012. *DO-178C: Software Considerations in Airborne Systems and Equipment Certification*. Washington, DC: RTCA, Inc.

Schwartau, Meinert. 2018. "Leichgewichtige Architekturvalidierung mit ArchUnit." Blog post.

TNG Technology Consulting. 2024. "ArchUnit." https://www.archunit.org/.

Yau, Stephen S., and James S. Collofello. 1980. "Some Stability Measures for Software Maintenance." *IEEE Transactions on Software Engineering* SE-6 (6): 545--552.

Yau, Stephen S., James S. Collofello, and T. M. MacGregor. 1978. "Ripple Effect Analysis of Software Maintenance." In *Proceedings of COMPSAC '78: The IEEE Computer Society's Second International Computer Software and Applications Conference*, 60--65. Chicago, IL: IEEE.
