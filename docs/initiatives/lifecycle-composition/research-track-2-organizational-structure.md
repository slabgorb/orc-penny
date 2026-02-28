# Research Track 2: Organizational Structure and Decision-Making for Tiered Software Development Lifecycles

**Author:** BA Agent (Research Analyst)
**Date:** 2026-02-14
**Citation Style:** University of Chicago Author-Date (17th ed.)

---

## Part 2A: Tiered Process Architecture

### 1. The NIST Risk Management Framework as Structural Analogy

The National Institute of Standards and Technology's Special Publication 800-39 establishes a three-tier model for managing information security risk that provides a direct structural analogy for tiered software development organization. NIST defines three tiers: Tier 1 (Organization), Tier 2 (Mission/Business Process), and Tier 3 (Information System), each with its own complete risk management cycle (NIST 2011).

The critical structural insight is that each tier operates a full process cycle---risk framing, risk assessment, risk response, and risk monitoring---at its own scope and cadence. Tier 1 "addresses risk from an organizational perspective and implements the first component of risk management (i.e., risk framing), providing the context for all risk management activities carried out by organizations" (NIST 2011, 9). Tier 2 translates organizational risk frames into mission-specific architectures and processes. Tier 3 applies these to specific information systems.

What distinguishes the NIST model from a simple hierarchy is its explicit bidirectionality. "The bidirectional arrows in the figure indicate that the information and communication flows among the risk management components as well as the execution order of the components, may be flexible and respond to the dynamic nature of the risk management process as it is applied across all three tiers" (NIST 2011, 11). Feedback from Tier 3 operations can trigger revisions at Tier 2 and even at Tier 1, resulting in "revisions to the organizational risk frame or affecting risk management activities carried out at Tier 1" (NIST 2011, 12).

**Application to AI-agent-driven development:** The NIST three-tier model maps naturally to a Strategic-Tactical-Execution lifecycle. An AI orchestrator at each tier runs its own process loop (discover-design-build-ship-learn), with agents at Tier 3 providing operational feedback that propagates upward to modify tactical and strategic decisions. The key design requirement: each tier's agent ensemble must have access to a complete process cycle, not a subset of one.

### 2. Fractal Agile and Scale-Invariant Development

The concept of "fractal agile" treats the agile process pattern as self-similar across organizational scales. In the Scaled Agile Framework (SAFe), "every level of an organization has a prioritized backlog, a system for testing hypotheses, and a process for capturing lessons learned. Such self-resemblance of a pattern throughout and at every scale is best understood as a fractal" (Hilton 2023). The Agile Release Train (ART) is described as "a larger fractal scale of the Agile Team," with the Release Train Engineer serving as "a larger fractal scale of the SAFe Scrum Master Role" (Teunissen 2023).

This fractal quality---the same pattern recurring at different scales---is the structural principle that distinguishes a tiered architecture from a traditional hierarchy. In a hierarchy, each level has a different process (strategy at the top, execution at the bottom). In a fractal-tiered architecture, every level runs the same kind of process cycle, just scoped differently. As one practitioner observes, "Rather than a hierarchical structure, there is organic growth and replication of what worked before to new domains" (Hilton 2023).

**Application to AI-agent-driven development:** Fractal self-similarity means the same agent roles (Scrum Master, Architect, Developer, Reviewer) can be instantiated at every tier with different scope parameters. A strategic-tier Architect agent reasons about portfolio-level modularity; a tactical-tier Architect agent reasons about feature boundaries; an execution-tier Architect agent reasons about component interfaces. The process pattern (discover, design, build, verify, reflect) is identical; only the scope of concern changes.

### 3. SAFe's Tiered Structure: Lessons Learned

The Scaled Agile Framework defines four configurations at increasing scale: Essential SAFe (Team + ART levels), Large Solution SAFe, Portfolio SAFe, and Full SAFe (Leffingwell 2011; Scaled Agile Inc. 2024). Dean Leffingwell's foundational work organized agile requirements into three levels: "the team level, covering User Stories and Spikes," "the program level, including vision, features, and the roadmap," and "the highest level...the transition toward agile portfolio management" (Leffingwell 2011, Parts II-IV).

SAFe provides empirical evidence that tiered organization can work at scale, but its critics identify structural problems relevant to our design:

1. **Hierarchical rigidity:** "SAFe encourages a hierarchical, or top-down, organizational structure, which is a deviation from what is typically considered Lean-Agile thinking" (Wikipedia contributors 2024).
2. **Slow feedback loops:** "Customer feedback must be captured at the Program level, communicated at the team level, and updated at the portfolio level, limiting scope for responding to change" (AltexSoft 2024).
3. **Excessive coordination overhead:** "Pivoting might involve multiple layers of approval from portfolio managers to product owners, where each layer must assess changes and recalibrate priorities, which can slow response times" (Enov8 2024).

These criticisms point to a design requirement: tiers must not become bureaucratic gatekeepers. Each tier must be genuinely autonomous within its scope, with coordination happening through shared context and regular touchpoints rather than approval chains.

**Application to AI-agent-driven development:** AI agents can potentially avoid SAFe's bureaucratic overhead because inter-tier communication is programmatic rather than meeting-based. An execution-tier agent can query the tactical tier's current context in milliseconds rather than waiting for a PI Planning event. The challenge shifts from reducing meeting overhead to designing the right information interfaces between tiers.

### 4. The Spotify Model: Autonomy Within Alignment

Henrik Kniberg and Anders Ivarsson described Spotify's organizational model in a 2012 whitepaper that has become one of the most referenced scaling patterns in industry. The model organizes around four structures: Squads (autonomous cross-functional teams of 6-12), Tribes (collections of 3-5 Squads, capped at ~150 people per Dunbar's number), Chapters (professional communities across Squads within a Tribe, with a Chapter Lead as formal line manager), and Guilds (cross-Tribe communities of interest with no formal leader) (Kniberg and Ivarsson 2012).

The Spotify model's most relevant contribution is its explicit treatment of the autonomy-alignment tension. Squads "can choose the framework that works best for them, which could be Scrum, Kanban, or whatever else that squad prefers" (Kniberg and Ivarsson 2012). The model "focuses on organizing around work and not necessarily processes and ceremonies, giving an organization greater flexibility" (Atlassian 2024). The Trio (Tribe Lead, Product Lead, Design Lead) ensures "continuous alignment between these three perspectives when working on features areas" (Atlassian 2024).

However, Kniberg himself cautioned that the model "was not intended to be a generic framework" and was merely a snapshot of "how Spotify worked in 2012" (Kniberg 2012). Multiple retrospectives have noted that even Spotify moved away from the model as described in the whitepaper.

**Application to AI-agent-driven development:** The Spotify model's Guild and Chapter structures---horizontal knowledge communities cutting across vertical delivery teams---suggest a need for cross-tier agent knowledge sharing. An "Architecture Guild" equivalent might be a shared context repository that all Architect agents across tiers can read and contribute to, ensuring consistency without requiring centralized control.

### 5. Nexus and LeSS: Minimalist Multi-Team Coordination

Nexus (Ken Schwaber) and Large-Scale Scrum (LeSS, Craig Larman and Bas Vodde) represent contrasting approaches to multi-team coordination. Nexus "concentrates on handling dependencies and interoperability by incorporating new roles and incidents," while LeSS "maintains basic Scrum structures with slight additions" and "emphasizes the importance of organisational design and structure in enabling agility" (ValueX2 2024).

LeSS is particularly relevant because of its explicit minimalism: "instead of adding management layers to handle multiple teams, LeSS emphasizes scaling down by promoting self-managing teams that collaborate without extra hierarchy" (ValueX2 2024). This aligns with the principle that tiers should not add bureaucracy---they should add scope, not overhead.

Nexus introduces the Integration Team concept, "which ensures that the work of different teams is correctly combined throughout the Sprint" (CBTW 2024). This role is analogous to a tier-boundary coordination mechanism: something that ensures work products from one tier integrate correctly with the expectations of adjacent tiers.

**Application to AI-agent-driven development:** LeSS's minimalism suggests that tier boundaries should be thin interfaces rather than thick coordination layers. The Integration Team concept maps to a dedicated integration-verification agent that runs at each tier boundary, checking that outputs from a lower tier conform to the constraints set by the tier above.

### 6. Multi-Level Organizational Theory

The academic foundation for multi-level organizational design rests on Kozlowski and Klein's (2000) landmark work, which establishes the axiom that "organizations are multilevel systems." Their framework addresses a critical issue: "linkages are more likely to be exhibited for constructs that tap content domains underlying meaningful interactions across levels" (Kozlowski and Klein 2000, 14). Furthermore, "multilevel relationships are not always unidirectional; instead, over time the relationship between phenomena at different levels may prove bidirectional or reciprocal" (Kozlowski and Klein 2000, 55).

This academic grounding validates the intuition that a tiered development architecture must account for bidirectional influence. Strategy shapes execution, but execution experience shapes strategy. Any lifecycle model that treats this as a one-way cascade is theoretically incomplete.

Jay Galbraith's (1973) information-processing theory of organizational design provides a complementary lens. Galbraith argued that "task uncertainty increases the complexity of organizations, necessitating enhanced information processing" (Galbraith 1973). His design strategies for managing uncertainty include the "creation of self-contained tasks" (reducing cross-unit information needs) and the "creation of lateral relations" (increasing information processing capacity). Both strategies are directly applicable to tier design: self-contained tiers with well-defined interfaces reduce cross-tier coordination needs, while lateral relations (cross-tier touchpoints) increase the system's capacity to handle the remaining coordination.

James D. Thompson's (1967) typology of organizational interdependence offers a vocabulary for describing how tiers relate. Thompson identifies three patterns of dependency---pooled, sequential, and reciprocal---with corresponding coordination mechanisms: standardization, planning, and mutual adjustment. He "further suggests that organizational hierarchies will tend to cluster groups with reciprocal interdependencies most closely" (Thompson 1967, 59). In a tiered lifecycle, adjacent tiers (Strategic-Tactical, Tactical-Execution) have reciprocal interdependencies requiring mutual adjustment, while non-adjacent tiers (Strategic-Execution) have more pooled interdependencies manageable through standardization.

**Application to AI-agent-driven development:** Thompson's interdependence typology suggests that the coordination mechanism between tiers should vary by proximity. Adjacent tiers need rich, bidirectional, conversational interfaces (reciprocal interdependence via mutual adjustment). Non-adjacent tiers need shared standards and conventions (pooled interdependence via standardization). This maps to agent design: adjacent-tier agents engage in dialogue, while distant-tier agents share structured artifacts.

### 7. The V-Model as Hierarchical Decomposition and Integration

The aerospace systems engineering V-Model provides a structural template for hierarchical decomposition matched with hierarchical integration. "The left side of the 'V' represents the decomposition of requirements and the creation of system specifications, while the right side represents an integration of parts and their validation" (Wikipedia contributors 2024b). Critically, the V-Model is recursive: "When a system is decomposed into components, each of these components can again be decomposed. Each component can thus be viewed as 'just another development effort' which in turn is described by the V-model. A given 'V' has 'smaller V's' inside it---like a multi-dimensional Russian Doll" (V-Model practitioners 2024).

This recursive nesting is precisely the fractal property that distinguishes a tiered architecture from a flat hierarchy. Each tier runs its own V (decompose then integrate), and the tiers nest within each other.

**Application to AI-agent-driven development:** The V-Model's recursive nesting suggests that each tier should have both a "decomposition phase" (breaking work into sub-units for the tier below) and an "integration phase" (assembling and verifying work products from the tier below). AI agents at each tier boundary need both decomposition capability (Architect-like) and integration capability (Reviewer-like).

---

## Part 2B: Distributed Architecture Decision-Making

### 1. The Subsidiarity Principle in Software Architecture

The principle of subsidiarity---that decisions should be made by the smallest, lowest, or least centralized competent authority---has a long history in political philosophy and organizational theory. Applied to software architecture, it means that "any decision not affecting parallel teams or domains can and should be made at the team level (as long as they follow global guidelines & standards)" (Tahar 2023). The principle offers several benefits: "shorter reaction time to changes as local decision makers don't need to wait for instructions, improved motivation as local decision makers are empowered, and better total performance in achieving the overall goal" (Thinking Sideways 2023).

The microservices movement can be understood through this lens: "The big hype around micro services can be seen as a drive to get the subsidiarity principle implemented via software architecture, as if every micro service is owned by an individual team, it is guaranteed that only this team will make the decisions" (Thinking Sideways 2023).

**Application to AI-agent-driven development:** Subsidiarity maps directly to parameterized architect agents at each tier. A strategic architect agent makes portfolio-wide technology decisions; a tactical architect agent makes feature-boundary and integration decisions; an execution architect agent makes component-level design decisions. Each operates within the constraints set by the tier above but has full autonomy within its scope. The "lowest competent level" is whichever tier has sufficient context to make the decision well.

### 2. Conway's Law and the Inverse Conway Maneuver

Melvin Conway's 1968 observation remains one of the most validated principles in software engineering: "Any organization that designs a system (defined broadly) will produce a design whose structure is a copy of the organization's communication structure" (Conway 1968, 31). Conway further noted that "the very act of organizing a design team means that certain design decisions have already been made" (Conway 1968, 29).

MacCormack, Baldwin, and Rusnak (2012) provided rigorous empirical validation of what they call the "mirroring hypothesis." Studying pairs of software products with the same function but developed by different organizational forms, they "found strong evidence to support the mirroring hypothesis---in all of the pairs examined, the product developed by the loosely-coupled organization is significantly more modular than the product from the tightly-coupled organization" with "differences being substantial---up to a factor of eight in terms of the potential for a design change in one component to propagate to others" (MacCormack, Baldwin, and Rusnak 2012, 1315).

Nagappan, Murphy, and Basili (2008) demonstrated the practical impact at Microsoft: "organizational complexity metrics were the strongest defect predictors" for Windows Vista, outperforming "traditional metrics like churn, complexity, coverage, dependencies, and pre-release bug measures" (Nagappan, Murphy, and Basili 2008, 525). This finding was so significant that "Microsoft reorganized the subteams around features, resulting in a clear responsibility (or 'one cook') for each feature" (Nagappan, Murphy, and Basili 2008, 528).

The Inverse Conway Maneuver---deliberately designing the organization to produce the desired architecture---has gained substantial traction. Forsgren, Humble, and Kim (2018) endorsed it in *Accelerate*: "organizations should evolve their team and organizational structure to achieve the desired architecture" (Forsgren, Humble, and Kim 2018, 53). They found that "high performance is possible with all kinds of systems, provided that systems---and the teams that build and maintain them---are loosely coupled" (Forsgren, Humble, and Kim 2018, 48).

**Application to AI-agent-driven development:** Conway's Law applies to AI agent organizations just as it applies to human ones. If tier-level agent ensembles are structured as isolated silos, they will produce siloed architectures. If they share cross-cutting communication channels (like Guilds or advisory forums), they will produce more integrated architectures. The Inverse Conway Maneuver for AI agents means deliberately designing the agent communication topology to produce the desired system architecture.

### 3. SAFe's Architecture Roles: A Tiered Model

SAFe defines three architect roles that directly correspond to its organizational tiers: Enterprise Architect (Portfolio level), Solution Architect (Large Solution level), and System Architect (ART/Team level) (Scaled Agile Inc. 2024). Enterprise Architects "translate business goals into actionable roadmaps, standards, and guidelines that ensure consistency across the portfolio" (Agile Seekers 2024). Solution Architects align "many solution builders across multiple Agile Release Trains and Suppliers to a shared technical direction" (Scaled Agile Inc. 2024). System Architects have "deep knowledge about the solution that the Agile Release Train is building" (Premier Agile 2024).

SAFe explicitly addresses the centralization-decentralization tension: "While the principle of decentralized decision-making is preferred within SAFe, certain design decisions are better managed centrally" (Scaled Agile Inc. 2024). Architects "create the environment for decentralized decision-making by defining and communicating the architectural vision and strategy and then collaborating with and coaching the teams who build it" (Scaled Agile Inc. 2024). This is a guardrails-not-gatekeepers model: the higher tier sets constraints, the lower tier makes decisions within those constraints.

**Application to AI-agent-driven development:** SAFe's three-tier architect model maps directly to parameterized Architect agents. The key insight is that higher-tier architects do not make lower-tier decisions---they set constraints (architectural guardrails, fitness functions, design principles) within which lower-tier architects have full autonomy. For AI agents, these constraints can be encoded as structured context that the lower-tier agent receives as part of its prompt.

### 4. Fred Brooks and the Conceptual Integrity Problem

Fred Brooks articulated the fundamental tension in distributed architectural decision-making: "If a system is to have conceptual integrity, someone must control the concepts. That is an aristocracy that needs no apology" (Brooks 1975, 45). Brooks argued that "conceptual integrity is the most important consideration in system design" and that "it is better to have a system omit certain anomalous features but reflect one set of design ideas, than to have one containing many good but independent and uncoordinated ideas" (Brooks 1975, 44).

This appears to contradict the case for distributed architecture. However, Brooks was writing about a single system at a single scale. The reconciliation comes from recognizing that conceptual integrity is a property that must be maintained *within each tier*, not necessarily by a single mind across all tiers. A strategic architect maintains conceptual integrity of the portfolio. A tactical architect maintains conceptual integrity of a feature set. An execution architect maintains conceptual integrity of a component. As long as the interfaces between tiers are well-defined, each tier can have its own "aristocracy" maintaining integrity at its own scope.

This reconciliation echoes the V-Model's recursive nesting: each "V" has its own integrity requirement, maintained by the architect at that level.

**Application to AI-agent-driven development:** Brooks's warning is directly relevant. An AI agent system that distributes architecture decisions without any integrity mechanism will produce incoherent designs. The solution is not to centralize all decisions in one agent, but to ensure each tier's architect agent maintains integrity within its scope, and that the interfaces between tiers (the "design rules" in Baldwin and Clark's terminology) are explicit and enforced.

### 5. Team Topologies: Cognitive Load and Interaction Modes

Matthew Skelton and Manuel Pais (2019) introduced a model of team organization grounded in cognitive load theory. Their central insight is that "software that is too big for our heads works against organizational agility" and that leaders should "limit the size of services or products to the cognitive load that the team can handle, with each service being fully owned by a team with sufficient cognitive capacity" (Skelton and Pais 2019, 51). Martin Fowler describes this as "the bright insight of Team Topologies" (Fowler 2019).

The model defines four team types (Stream-aligned, Enabling, Complicated Subsystem, Platform) and three interaction modes (Collaboration, X-as-a-Service, Facilitation). The interaction modes are particularly relevant to inter-tier relationships:

- **Collaboration:** Two teams working together for a defined period to discover something new---analogous to adjacent-tier agents jointly exploring a design space.
- **X-as-a-Service:** One team provides a service consumed by others---analogous to a lower tier producing artifacts consumed by a higher tier's verification process.
- **Facilitation:** One team helps another improve---analogous to a higher tier coaching a lower tier's agent ensemble.

The Inverse Conway Maneuver is central to Team Topologies: "By applying a 'reverse Conway manoeuvre,' organizations can design their teams to 'match' the required software architecture" (Skelton and Pais 2019, 18).

**Application to AI-agent-driven development:** Cognitive load theory applies to AI agents through context window limits. An agent with too broad a scope loses coherence just as a team with too much cognitive load loses effectiveness. Tiering agent responsibilities limits the "cognitive load" on each agent's context, allowing it to maintain deeper understanding of its scope. The interaction modes (Collaboration, X-as-a-Service, Facilitation) provide a vocabulary for designing how agent ensembles at different tiers communicate.

### 6. Martin Fowler and Evolutionary Architecture

Fowler and colleagues advocate for an approach to architecture "as a series of conversations, driven by a decentralised and empowering decision-making technique" supported by four mechanisms: "Decision Records, Advisory Forum, Team-sourced Principles, and a Technology Radar" (Harmel-Law 2021). The core mechanism is the Advice Process: "anyone can make an architectural decision" provided they first consult "everyone who will be meaningfully affected by the decision" and "people with expertise in the area the decision is being taken" (Harmel-Law 2021).

Neal Ford, Rebecca Parsons, and Patrick Kua (2017) introduce architectural fitness functions---automated checks that "monitor the state of the architecture" and "guide changes to the architecture to protect those characteristics" (Ford, Parsons, and Kua 2017, 28). The practice of evolutionary software architecture means "making decisions as late as possible (last responsible moment) and setting up cross-functional requirements that the architecture has to meet" (Ford, Parsons, and Kua 2017, 34).

**Application to AI-agent-driven development:** The Advice Process maps naturally to an agent protocol: before an architect agent at any tier makes a structural decision, it queries affected agents (at the same tier and adjacent tiers) for input. It receives advice, not vetoes. The decision remains with the local agent. Fitness functions can be encoded as automated verification agents that run continuously at each tier boundary, checking that architectural invariants are maintained as the system evolves.

### 7. Architecture Decision Records as Distributed Coherence Mechanism

Michael Nygard (2011) proposed Architecture Decision Records (ADRs) as a lightweight mechanism for documenting architectural decisions: "a short text file in a format similar to an Alexandrian pattern" with sections for Context, Decision, Status, and Consequences. Nygard's insight was that "the need for architecture decision records increases for larger or more distributed projects, especially those where no single architect is available" (Nygard 2011).

ADRs serve as a mechanism for distributed coherence: they allow many decision-makers to operate independently while maintaining a shared, searchable, versioned record of what was decided and why. When stored in the same repository as the code, they become "lightweight documents...that blend well with the development workflow everyone already uses" (Agile Alliance 2024).

**Application to AI-agent-driven development:** ADRs are an ideal interface artifact for distributed AI architect agents. Each tier's architect agent produces ADRs documenting decisions within its scope. Adjacent-tier agents can read these ADRs to understand the constraints and rationale they must work within. The ADR format (Context, Decision, Consequences) maps cleanly to structured data that agents can parse and reason about.

### 8. Military Command and Control: Mission Command

Modern military doctrine provides the most mature example of distributed decision-making under uncertainty. The U.S. military's Mission Command philosophy is built on "Centralized Command---Distributed Control---Decentralized Execution (CC-DC-DE)" (U.S. Air Force 2023). The principle is that "commanders direct 'what' and 'why'; subordinate commanders devise 'how'" (U.S. Air Force 2023). Execution "hinges on subordinates' understanding of the commander's guidance and intent" with "the commander's role [changing] to empower subordinates to make decisions on their behalf" (U.S. Air Force 2023).

This doctrine directly parallels the tiered lifecycle model: strategic tiers define intent and constraints ("what" and "why"); tactical and execution tiers determine implementation approach ("how"). The critical enabler is shared understanding: subordinate units must understand the broader intent well enough to make local decisions that serve the overall mission even when conditions change.

**Application to AI-agent-driven development:** Mission Command maps directly to tiered agent orchestration. A strategic-tier agent defines the "commander's intent" (product vision, architectural constraints, quality requirements). Tactical-tier agents translate this into feature-level plans. Execution-tier agents implement with full autonomy over local design decisions. The key requirement: every tier's agents must have access to the intent of the tier above, not just its directives. In agent terms, this means including strategic context in every agent's prompt, not just the immediate task specification.

### 9. Amazon's Two-Pizza Teams and Decentralized Service Ownership

Amazon's organizational transformation provides a case study in applied subsidiarity. Jeff Bezos restructured Amazon around "two-pizza teams"---teams small enough to be fed by two pizzas, ideally fewer than 10 people---with each team owning a specific service end-to-end (AWS Executive Insights 2024). The famous "API mandate" required that "all teams will henceforth expose their data and functionality through service interfaces" (AWS Executive Insights 2024).

The organizational restructuring was inseparable from the architectural one: "Amazon fundamentally changed its technical architecture to what became known as a microservices architecture, decoupling their monolithic architecture into a vast network of single, standalone services" (AWS Executive Insights 2024). Amazon introduced the "single-threaded leader" concept---leaders "who had a single area of responsibility, ensuring that each team had a clear leader who was fully accountable for its success and had no other distractions" (AWS Executive Insights 2024).

**Application to AI-agent-driven development:** Amazon's model reinforces that architecture and organization are inseparable. In AI-agent terms, each agent ensemble (the equivalent of a two-pizza team) should own a well-defined scope with clear interface contracts (the equivalent of APIs). The "single-threaded leader" concept maps to each agent ensemble having a single coordinating agent accountable for its outcomes.

### 10. Distributed Decision-Making in Healthcare

Healthcare governance provides an additional domain example of multi-tiered decision distribution. Research shows "the prominence of balancing between top-down and bottom-up decision-making (such as strategic vs steering committees), with formal procedural arrangements and strategic governing bodies in stimulating participative decision-making, collaboration and sense of ownership" (Unravelling Collaborative Governance 2024). Healthcare organizations exhibit "an emergent decoupling between governance initiatives formulated at the macro- and micro-levels," with macro-level governance directed toward institutional performance targets and micro-level governance overseeing the direct patient-physician relationship (Bodolica and Spraggon 2014, 93).

The subsidiarity principle manifests in healthcare through cascading leadership: "leadership plans were to be cascaded down to the local and individual level, guided by the overarching activities of the newly formed NHS Leadership Council" (NCBI 2024). This cascade model---strategic intent flowing down, operational reality flowing up---mirrors the bidirectional tier communication the lifecycle model requires.

**Application to AI-agent-driven development:** Healthcare's experience with macro-micro decoupling is a warning: without explicit mechanisms for cross-tier alignment, distributed decision-making naturally fragments. The lifecycle model must include specific alignment artifacts (shared context documents, tier-boundary verification checks) to prevent macro-level architectural decisions from becoming disconnected from micro-level implementation reality.

---

## Part 2C: The Relationship Between Product Decomposition and Organizational Structure

### 1. Conway's Law: The Original Observation

Melvin Conway's 1968 paper "How Do Committees Invent?" established the foundational observation: "The basic formulation of this article is that organizations which design systems (in the broad sense used here) are constrained to produce designs which are copies of the communication structures of these organizations" (Conway 1968, 31). Conway further observed that "the very act of organizing a design team means that certain design decisions have already been made, explicitly or otherwise" (Conway 1968, 29). The paper was originally submitted to the Harvard Business Review, which rejected it for insufficient evidence---an ironic outcome given that the observation has since become one of the most empirically validated principles in software engineering.

### 2. Baldwin and Clark: The Power of Modularity

Carliss Baldwin and Kim Clark's *Design Rules: The Power of Modularity* (2000) provides the theoretical foundation for understanding how modular design creates organizational flexibility. They argue that the computer industry "experienced previously unimaginable levels of innovation and growth because it embraced the concept of modularity, building complex products from smaller subsystems that can be designed independently yet function together as a whole" (Baldwin and Clark 2000, 2). The critical insight is that "modularity freed designers to experiment with different approaches, as long as they obeyed the established design rules" (Baldwin and Clark 2000, 5).

The concept of "design rules"---the constraints that enable independent module development---is directly analogous to the tier-boundary interfaces in a tiered lifecycle. As long as each tier produces outputs that conform to the design rules established by the tier above, the tiers can operate independently. Baldwin and Clark's work has had "a profound impact on organization theory, competitive strategy, and innovation research, as well as on technical studies of system architecture and performance" (Industrial and Corporate Change 2023, 1).

**Application to AI-agent-driven development:** Baldwin and Clark's "design rules" concept provides the theoretical basis for defining tier-boundary interfaces. Each tier's architect agent establishes design rules for the tier below---interface contracts, architectural constraints, quality requirements---that enable autonomous operation while maintaining coherence. The design rules are the "what" and "why"; the implementation within those rules is the "how" that the lower tier controls.

### 3. Domain-Driven Design: Bounded Contexts as Organizational Boundaries

Eric Evans (2003) introduced the concept of the Bounded Context as a mechanism for managing complexity in large software systems. Evans defined it as "the limit of applicability of a model" and prescribed that teams should "explicitly define the context within which a model applies. Explicitly set boundaries in terms of team organization, usage within specific parts of the application, and physical manifestations such as code bases and database schemas" (Evans 2003, 336). Critically, Evans observed that "usually the dominant factor drawing boundaries between contexts is human culture, since models act as Ubiquitous Language, you need a different model when the language changes" (Evans 2003, 341).

Martin Fowler elaborates that "a Bounded Context is typically the responsibility of a single team: the size of the model is usually small enough, and having multiple teams work on the same model without sharing the same design approach is generally a recipe for disaster" (Fowler 2014). Bounded contexts thus serve simultaneously as technical decomposition boundaries and organizational boundaries.

**Application to AI-agent-driven development:** Bounded contexts map naturally to agent ensemble boundaries. Each agent ensemble (the team equivalent) operates within a bounded context with its own ubiquitous language. Cross-context communication happens through explicitly defined interfaces (context maps in DDD terminology). At the tier level, strategic tiers may operate with a more abstract ubiquitous language, while execution tiers use a more implementation-specific one. The boundary between tiers is itself a context boundary requiring explicit translation.

### 4. Parnas: Information Hiding as Decomposition Principle

David Parnas's (1972) seminal paper "On the Criteria To Be Used in Decomposing Systems into Modules" established that decomposition should be driven by information hiding, not by processing flow. Parnas argued that "it is almost always incorrect to begin the decomposition of a system into modules on the basis of a flowchart. Instead, one should begin with a list of difficult design decisions or design decisions which are likely to change. Each module is then designed to hide such a decision from the others" (Parnas 1972, 1056).

This principle extends to organizational decomposition: tiers should be defined not by sequential processing stages, but by the categories of decisions they encapsulate. A strategic tier hides market and portfolio decisions from tactical tiers. A tactical tier hides feature prioritization and architecture decisions from execution tiers. An execution tier hides implementation details from tactical tiers. The interfaces between tiers expose only what needs to be shared.

**Application to AI-agent-driven development:** Parnas's information hiding principle suggests that agent context should be scoped by tier. An execution-tier agent does not need (and should not have) full strategic context---it needs the distilled decisions (constraints, interfaces, acceptance criteria) that affect its work. Overloading an agent's context with full multi-tier information reduces the signal-to-noise ratio and wastes context window capacity.

### 5. Systems Engineering Decomposition Methods

Systems engineering offers three complementary decomposition methods relevant to tiered lifecycle design:

**Functional decomposition** breaks a system into functions, producing a Functional Breakdown Structure (FBS)---"a structured, modular breakdown of every function that must be addressed to perform a generic mission" (NASA 2013). Unlike a Work Breakdown Structure, "the FBS is a function-oriented tree, not a product-oriented tree, and details not products, but operations or activities that should be performed" (NASA 2013).

**Physical decomposition** breaks a system into physical components, producing a product-oriented WBS. Program offices develop WBSs "tailoring the guidance provided in MIL-HDBK-881" (DoD 2018).

**Behavioral decomposition** breaks a system into behaviors or scenarios, capturing how the system acts under different conditions.

The standard Work Breakdown Structure has limitations: it tends toward product orientation and may not capture cross-cutting concerns, behavioral properties, or emergent interactions between components. Alternatives like the FBS address some of these limitations by focusing on function rather than product.

**Application to AI-agent-driven development:** A tiered lifecycle benefits from multiple decomposition views. The strategic tier may use functional decomposition (what capabilities does the product need?). The tactical tier may use behavioral decomposition (what scenarios must features support?). The execution tier may use physical decomposition (what components must be built?). Each tier uses the decomposition method best suited to its scope.

### 6. Hierarchical Task Network (HTN) Planning

Hierarchical Task Network planning, from AI planning research, provides a formal model for recursive task decomposition. In HTN planning, tasks are classified as "abstract (need decomposition) or primitive (directly executable)," with methods describing "how an abstract task can be decomposed into an ordered list of subtasks" (GeeksforGeeks 2024). The decomposition process "performs a depth-first search on the domain graph" starting "at the top-level compound task and hierarchically expands it into a sequence of primitive tasks, which represent a plan" (Wikipedia contributors 2024c).

HTN planning is "an effective yet knowledge intensive problem-solving technique that requires humans to encode knowledge in the form of methods and action models, where methods describe how to decompose tasks into subtasks and the preconditions under which those methods are applicable" (Learning HTN Domains 2014, 4).

**Application to AI-agent-driven development:** HTN provides a formal framework for how a tiered lifecycle decomposes work. A strategic-tier agent defines abstract tasks (epics, initiatives). A tactical-tier agent applies decomposition methods to break these into sub-tasks (features, stories). An execution-tier agent further decomposes into primitive tasks (implementation steps, test cases). The decomposition methods themselves are tier-specific knowledge that can be captured as agent instructions. The key HTN insight: decomposition requires domain knowledge encoded in methods, not just generic subdivision.

### 7. The Tension Between Decomposition for Parallelism and Coherence

Research on software decomposition strategies reveals a fundamental tension. On one hand, "the modular nature induced by decomposition facilitates parallel development, and as software projects grow in complexity and scale, having multiple teams working on disparate modules simultaneously becomes not just beneficial but essential" (Shcherbyna 2024). On the other hand, decomposition that prioritizes parallelism may sacrifice coherence: Tiwana (2008) found that "the performance benefits of development coordination tools are contingent on the salient types of novelty in a project" and that "some classes of tools introduce an efficiency-effectiveness tradeoff" (Tiwana 2008, 2).

Brooks's (1975) observation that conceptual integrity requires unified vision appears to conflict with the need for parallel, autonomous work. The reconciliation lies in the concept of design rules (Baldwin and Clark 2000): if the interfaces between modules are well-defined before parallel work begins, each module can be developed independently without sacrificing overall coherence. The strategic and tactical tiers' primary responsibility is establishing these design rules; the execution tier's responsibility is building within them.

**Application to AI-agent-driven development:** The parallelism-coherence tension is amplified in AI-agent systems because agents can operate in truly parallel threads. The mitigation is the same as in human organizations but can be more rigorous: explicit interface contracts (defined by tactical-tier architects), automated coherence checks (fitness functions run by verification agents), and regular synchronization touchpoints (orchestrated by coordination agents at each tier boundary).

### 8. Galbraith's Star Model and Organizational Fit

Jay Galbraith's Star Model establishes that organizational effectiveness requires alignment among five design elements: Strategy, Structure, Processes, Rewards, and People (Galbraith 1960s-2000s). Applied to a tiered lifecycle: the strategy must define why tiers exist, the structure must define what each tier contains, the processes must define how tiers operate and interact, the reward mechanisms must incentivize both intra-tier excellence and cross-tier collaboration, and the people (or agents) must have the skills and context appropriate to their tier.

Galbraith's core principle is that "organizational effectiveness is greatest when there is a fit among the points of the star" (Galbraith 2014). In a tiered lifecycle, this means that the tier structure, the processes within each tier, the interfaces between tiers, and the capabilities of the agents at each tier must all be coherently designed together.

---

## Synthesis: Implications for AI-Agent-Driven Tiered Lifecycle Design

The research across organizational theory, military doctrine, scaling frameworks, and software architecture converges on several principles for designing a tiered lifecycle:

1. **Each tier needs a complete process cycle.** The NIST RMF, fractal agile, and the recursive V-Model all demonstrate that tiers are not stages in a pipeline---they are autonomous units running full loops at different scopes and cadences.

2. **Feedback must be bidirectional.** NIST's bidirectional arrows, Thompson's reciprocal interdependence, Kozlowski and Klein's multilevel relationships, and Mission Command's emphasis on shared understanding all require that information flows up as well as down.

3. **Architectural coherence emerges from design rules, not central control.** Baldwin and Clark's design rules, Brooks's conceptual integrity (applied within each tier), Parnas's information hiding, and Evans's bounded contexts all point to the same mechanism: define the interfaces explicitly, then let each tier operate autonomously within those constraints.

4. **Distributed architects, not delegating architects.** SAFe's three-tier architect model, the subsidiarity principle, Harmel-Law's Advice Process, and Amazon's single-threaded ownership all support the hypothesis that each tier needs its own architect with genuine decision-making authority, not a proxy for a central authority.

5. **Organization structure and product architecture are inseparable.** Conway's Law, the mirroring hypothesis, the Inverse Conway Maneuver, Team Topologies, and Nagappan et al.'s empirical findings all confirm that the tier structure of the lifecycle will directly shape the architecture of the product. Design both together.

6. **Coordination mechanisms should vary by tier proximity.** Thompson's interdependence typology and Galbraith's information-processing theory suggest that adjacent tiers need rich mutual adjustment (dialogue, shared context), while distant tiers need standardization (design rules, fitness functions).

7. **Cognitive load must be managed per tier.** Skelton and Pais's cognitive load principle, applied to AI agents via context window limits, means each tier's agents should receive only the context relevant to their scope. Overloading agents with full cross-tier context degrades performance just as cognitive overload degrades human team performance.

---

## Bibliography

Agile Alliance. 2024. "Distribute Design Authority with Architecture Decision Records." Agile Alliance Experience Reports. https://agilealliance.org/resources/experience-reports/distribute-design-authority-with-architecture-decision-records/.

Agile Seekers. 2024. "The Role of Enterprise Architects in SAFe Transformations." Agile Seekers Blog. https://agileseekers.com/blog/the-role-of-enterprise-architects-in-safe-transformations.

AltexSoft. 2024. "Scaled Agile Framework: Overview, Pros and Cons, Alternative." AltexSoft Blog. https://www.altexsoft.com/blog/scaled-agile-framework-safe/.

Atlassian. 2024. "Discover the Spotify Model." Atlassian Agile Coach. https://www.atlassian.com/agile/agile-at-scale/spotify.

AWS Executive Insights. 2024. "Amazon's Two Pizza Team." Amazon Web Services. https://aws.amazon.com/executive-insights/content/amazon-two-pizza-team/.

Baldwin, Carliss Y., and Kim B. Clark. 2000. *Design Rules, Volume 1: The Power of Modularity*. Cambridge, MA: MIT Press.

Bodolica, Virginia, and Martin Spraggon. 2014. "Clinical Governance Infrastructures and Relational Mechanisms of Control in Healthcare Organizations." *Journal of Health Management* 16 (1): 85-104.

Brooks, Frederick P., Jr. 1975. *The Mythical Man-Month: Essays on Software Engineering*. Reading, MA: Addison-Wesley.

CBTW. 2024. "Mastering Scrum Scaling: LeSS vs Nexus Explained." CBTW Tech Insights. https://cbtw.tech/insights/mastering-scrum-scaling-less-vs-nexus-explained.

Conway, Melvin E. 1968. "How Do Committees Invent?" *Datamation* 14 (4): 28-31.

Enov8. 2024. "The SAFe Hierarchy and Levels, Explained in Depth." Enov8 Blog. https://www.enov8.com/blog/the-hierarchy-of-safe-scaled-agile-framework-explained/.

Evans, Eric. 2003. *Domain-Driven Design: Tackling Complexity in the Heart of Software*. Boston: Addison-Wesley.

Ford, Neal, Rebecca Parsons, and Patrick Kua. 2017. *Building Evolutionary Architectures: Support Constant Change*. Sebastopol, CA: O'Reilly Media.

Forsgren, Nicole, Jez Humble, and Gene Kim. 2018. *Accelerate: The Science of Lean Software and DevOps: Building and Scaling High Performing Technology Organizations*. Portland, OR: IT Revolution Press.

Fowler, Martin. 2014. "Bounded Context." Martin Fowler's Bliki. https://martinfowler.com/bliki/BoundedContext.html.

Fowler, Martin. 2019. "Team Topologies." Martin Fowler's Bliki. https://martinfowler.com/bliki/TeamTopologies.html.

Galbraith, Jay R. 1973. *Designing Complex Organizations*. Reading, MA: Addison-Wesley.

Galbraith, Jay R. 2014. "The Star Model." Jay Galbraith Management Consultants. https://jaygalbraith.com/services/star-model/.

Harmel-Law, Andrew. 2021. "Scaling the Practice of Architecture, Conversationally." Martin Fowler's Website, December 15. https://martinfowler.com/articles/scaling-architecture-conversationally.html.

Hilton, Alexander. 2023. "Mimicking Mother Nature: The Art of Fractal Patterns in Agile Scaling." Medium. https://medium.com/@alexdh359/mimicking-mother-nature-the-art-of-fractal-patterns-in-agile-scaling-297d35a3bb5c.

Industrial and Corporate Change. 2023. "The Power of Modularity Today: 20 Years of 'Design Rules'." *Industrial and Corporate Change* 32 (1): 1-24.

Kniberg, Henrik, and Anders Ivarsson. 2012. "Scaling Agile @ Spotify with Tribes, Squads, Chapters & Guilds." Crisp's Blog, October. https://blog.crisp.se/wp-content/uploads/2012/11/SpotifyScaling.pdf.

Kozlowski, Steve W. J., and Katherine J. Klein. 2000. "A Multilevel Approach to Theory and Research in Organizations: Contextual, Temporal, and Emergent Processes." In *Multilevel Theory, Research, and Methods in Organizations: Foundations, Extensions, and New Directions*, edited by Katherine J. Klein and Steve W. J. Kozlowski, 3-90. San Francisco: Jossey-Bass.

Leffingwell, Dean. 2011. *Agile Software Requirements: Lean Requirements Practices for Teams, Programs, and the Enterprise*. Upper Saddle River, NJ: Addison-Wesley.

MacCormack, Alan, Carliss Baldwin, and John Rusnak. 2012. "Exploring the Duality between Product and Organizational Architectures: A Test of the 'Mirroring' Hypothesis." *Research Policy* 41 (8): 1309-1324.

Nagappan, Nachiappan, Brendan Murphy, and Victor Basili. 2008. "The Influence of Organizational Structure on Software Quality: An Empirical Case Study." In *Proceedings of the 30th International Conference on Software Engineering*, 521-530. New York: ACM.

NASA. 2013. "The Functional Breakdown Structure (FBS) and Its Relationship to Life Cycle Cost." NASA Technical Reports Server. https://ntrs.nasa.gov/citations/20130012526.

NIST (National Institute of Standards and Technology). 2011. *Managing Information Security Risk: Organization, Mission, and Information System View*. NIST Special Publication 800-39. Gaithersburg, MD: NIST.

Nygard, Michael. 2011. "Documenting Architecture Decisions." Cognitect Blog, November 15. https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions.

Parnas, David L. 1972. "On the Criteria To Be Used in Decomposing Systems into Modules." *Communications of the ACM* 15 (12): 1053-1058.

Premier Agile. 2024. "Scaled Agile System Architect." Premier Agile. https://premieragile.com/scaled-agile-system-architect/.

Scaled Agile Inc. 2024. "Agile Architecture in SAFe." Scaled Agile Framework. https://framework.scaledagile.com/agile-architecture.

Skelton, Matthew, and Manuel Pais. 2019. *Team Topologies: Organizing Business and Technology Teams for Fast Flow*. Portland, OR: IT Revolution Press.

Tahar, Raphael. 2023. "Software Architecture: Making Decisions at Scale." Medium (Decathlon Digital). https://medium.com/decathlondigital/software-architecture-making-decisions-f04cdd2cb3cf.

Teunissen, Brian. 2023. "Fractal Structure Patterns When Scaling Agile." LinkedIn. https://www.linkedin.com/pulse/fractal-structure-patterns-when-scaling-agile-brian-teunissen.

Thinking Sideways. 2023. "The Subsidiarity Principle in Software Development." Thinking Sideways Blog. https://thinkingsideways.net/processes/subsidiarity.html.

Thompson, James D. 1967. *Organizations in Action: Social Science Bases of Administrative Theory*. New York: McGraw-Hill.

Tiwana, Amrit. 2008. "Impact of Classes of Development Coordination Tools on Software Development Performance: A Multinational Empirical Study." *ACM Transactions on Software Engineering and Methodology* 17 (2): Article 10.

U.S. Air Force. 2023. *Air Force Doctrine Publication 1-1: Mission Command*. Washington, DC: Department of the Air Force.

U.S. Department of Defense. 2018. *Work Breakdown Structures for Defense Materiel Items*. MIL-STD-881D. Washington, DC: Department of Defense.

ValueX2. 2024. "Nexus vs LeSS: Which Scaled Agile Framework is Best for You?" ValueX2. https://www.valuex2.com/nexus-vs-less-comparison-of-scaling-agile-frameworks/.

Wikipedia contributors. 2024a. "Scaled Agile Framework." Wikipedia. https://en.wikipedia.org/wiki/Scaled_agile_framework.

Wikipedia contributors. 2024b. "V-model." Wikipedia. https://en.wikipedia.org/wiki/V-model.

Wikipedia contributors. 2024c. "Hierarchical Task Network." Wikipedia. https://en.wikipedia.org/wiki/Hierarchical_task_network.
