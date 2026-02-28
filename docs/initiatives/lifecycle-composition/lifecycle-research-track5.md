# Research Track 5: Decomposition Theory and Software Development Process Research

**Date:** 2026-02-14
**Citation Style:** University of Chicago Author-Date (17th ed.)

---

## Part A: Complex Product Decomposition

### 1. Modular Design Theory: Baldwin and Clark's Design Rules

Baldwin and Clark's *Design Rules: The Power of Modularity* (2000) provides the most rigorous theoretical treatment of how modularity creates economic value in complex system design. Their central argument is that modularity creates options -- the ability to change one module without affecting others creates real option value that can be quantified using financial option theory.

The authors ground their analysis in the evolution of the computer industry, beginning with IBM's System/360, which they characterize as a pivotal moment in modular design. They argue that "a modular design is a design in which the parameters and tasks of a design have been assigned to modules via design rules in such a way that (a) modules are independent of one another (no hidden interdependencies), (b) each module serves a well-defined function in the larger design, and (c) the interfaces among modules are well-defined" (Baldwin and Clark 2000, 63).

Their framework introduces three key operators for modular design evolution: **splitting** (breaking a design into modules), **substitution** (replacing one module with another), and **augmentation** (adding a new module). Each of these operators has quantifiable option value. The splitting operator is particularly relevant to decomposition theory: "Splitting a system into modules creates options because each module can be worked on independently. The value of these options increases with the number of experiments that can be conducted on each module and the variability of the outcomes" (Baldwin and Clark 2000, 237).

The **Design Structure Matrix (DSM)**, which Baldwin and Clark adopt from Steward (1981) and Eppinger (1991), serves as their primary analytical tool for mapping dependencies between design parameters. A DSM reveals clusters of tightly coupled parameters that should be grouped into the same module and identifies the interfaces between modules that must be specified as design rules. Baldwin and Clark distinguish between **visible design rules** (architecture, interfaces, and integration protocols that all modules must obey), **hidden design parameters** (internal decisions within a module that do not affect other modules), and **modular operators** (the actions that module designers can take independently).

The option-theoretic framework yields a critical insight: the value of modularity increases with uncertainty. "When the value of hidden information is high -- when there is great potential for innovation -- modular designs will be more valuable than comparable interconnected designs" (Baldwin and Clark 2000, 324). This directly applies to AI-agent-driven development: if AI agents can rapidly explore design alternatives within a module (conducting many "experiments" cheaply), then modularity's option value increases dramatically. The optimal number of modules may therefore increase when AI agents are the primary developers, because the cost of conducting experiments on each module drops precipitously.

However, Baldwin and Clark also identify the costs of modularity: the effort to create and maintain design rules, the potential performance penalties of modular interfaces, and the "value of the whole" that may be lost when a system is decomposed. "There is a tension between the value of modularity (which increases with the number of modules) and the cost of modularity (which also increases with the number of modules)" (Baldwin and Clark 2000, 302). For AI-agent systems, the cost of maintaining design rules may be lower (agents can rigorously enforce interface contracts), but the cost of losing conceptual integrity may be higher (agents lack the holistic design sense of experienced architects).

**Application to AI-agent spec-based development:** Baldwin and Clark's framework suggests that specifications should explicitly define visible design rules (interfaces, architecture decisions, integration protocols) while granting maximum freedom on hidden parameters within each module. The option value framework can guide decisions about granularity: finer decomposition is justified when agents can cheaply explore alternatives, but only if interface specifications are rigorous enough to ensure integration.

### 2. Parnas's Information Hiding Principle

David Parnas's 1972 paper "On the Criteria To Be Used in Decomposing Systems into Modules" is arguably the single most influential paper on software decomposition. Parnas examined a simple text-processing system (KWIC -- Key Word In Context index) and demonstrated two fundamentally different decompositions. The first, conventional decomposition followed the processing steps (input, circular shift, alphabetize, output). The second decomposition was based on information hiding, where each module concealed a design decision.

Parnas argued that "We propose instead that one begins with a list of difficult design decisions or design decisions which are likely to change. Each module is then designed to hide such a decision from the others" (Parnas 1972, 1056). This principle directly contradicts the intuition that decomposition should follow the flow of processing -- an intuition that remains common in practice.

Parnas identified the key benefits of information-hiding decomposition: **comprehensibility** (each module can be understood in isolation), **changeability** (design decisions can be changed without ripple effects), and **independent development** (modules can be developed by separate teams or agents without detailed coordination). He noted that "the connections between modules are the assumptions which the modules make about each other" (Parnas 1972, 1058), and that minimizing these assumptions is the primary goal of good decomposition.

**Application to AI-agent spec-based development:** Parnas's principle suggests that decomposition for AI agents should be organized around design decisions that might change, not around processing steps. Each agent's work unit should encapsulate a design decision, with the specification defining the interface contract. This allows agents to make implementation decisions independently -- precisely the kind of hidden information that creates option value in Baldwin and Clark's framework.

### 3. Systems Engineering Decomposition Methods

The INCOSE *Systems Engineering Handbook* (4th edition, 2015) codifies three primary decomposition methods used in systems engineering practice:

**Functional decomposition** breaks a system into functions or capabilities, asking "what must the system do?" The result is a function tree where each function is progressively decomposed into sub-functions. INCOSE defines this as the process of "resolving a complex function into simpler functions from which the complex function can be reconstituted" (INCOSE 2015, 55). Functional decomposition is top-down and goal-oriented, making it natural for specification writing.

**Physical decomposition** breaks a system into physical components or assemblies. In software, this maps to component or service decomposition -- the actual code artifacts that will be built. The mismatch between functional decomposition and physical decomposition is a recurring source of complexity: one function may span multiple components, and one component may implement multiple functions.

**Behavioral decomposition** breaks a system into states, modes, and transitions. This is particularly relevant for interactive or reactive systems where the sequence of operations matters. Behavioral decomposition often reveals hidden coupling that functional decomposition misses.

The handbook emphasizes that these decompositions are complementary, not alternatives: "The systems engineer must maintain traceability between requirements, functions, and physical architecture elements throughout the system life cycle" (INCOSE 2015, 70). This multi-view decomposition approach suggests that AI-agent specifications should address all three perspectives -- what the module does (functional), what artifacts it produces (physical), and how it behaves under various conditions (behavioral).

**Application to AI-agent spec-based development:** A spec-based lifecycle should use functional decomposition to define what agents must build, physical decomposition to define the deliverable artifacts, and behavioral decomposition to define test scenarios. The V-model suggests that each specification level should include corresponding verification specifications, enabling agents to verify their own work before integration.

### 4. Work Breakdown Structure: Origins and Limitations

The Work Breakdown Structure (WBS) originated in the U.S. Department of Defense with MIL-STD-881, first published in 1968. The WBS decomposes a project into a hierarchy where each element represents a deliverable product, service, or activity. The principle of **100% rule** requires that the WBS captures all deliverables -- "the total scope of the project is defined by the WBS; if it isn't in the WBS, it isn't in the project" (PMI 2021, 161).

However, the WBS has significant limitations for software development. Norman, Corbett, and Butler (2011) identified several problems: software is not easily decomposed into physical components, the 100% rule is difficult to enforce when requirements are evolving, and the WBS assumes a level of upfront knowledge that agile approaches explicitly reject.

**Alternatives to WBS** include:
- **Feature Breakdown Structure (FBS)**: decomposes by user-facing features rather than components
- **Story mapping** (Patton 2014): organizes work by user activities and tasks, creating a two-dimensional map of functionality versus implementation priority
- **Capability-based planning**: decomposes by organizational capabilities rather than products

**Application to AI-agent spec-based development:** The WBS's product-oriented decomposition is more suitable for AI-agent work than activity-oriented decomposition, because agents need clear deliverable definitions rather than process prescriptions. However, the 100% rule is valuable -- specifications should account for all deliverables, leaving no gaps that fall between agents' responsibilities.

### 5. Domain-Driven Design Bounded Contexts

Eric Evans's *Domain-Driven Design* (2003) introduced bounded contexts as a strategic decomposition pattern that aligns software boundaries with business domain boundaries. A bounded context is "a description of a boundary (typically a subsystem, or the work of a particular team) within which a particular model is defined and applicable" (Evans 2003, 336).

Evans argued that attempting to maintain a single unified model across a large system is not only impractical but counterproductive: "Total unification of the domain model for a large system will not be feasible or cost-effective" (Evans 2003, 335). Instead, each bounded context maintains its own model, and relationships between contexts are managed through explicit patterns.

The **context mapping** patterns Evans and later practitioners developed include:
- **Shared Kernel**: two contexts share a subset of the model
- **Customer-Supplier**: one context provides data to another
- **Conformist**: one context adopts the model of another wholesale
- **Anti-Corruption Layer (ACL)**: a translation layer protecting one context's model
- **Open Host Service / Published Language**: a well-defined protocol for consumption
- **Separate Ways**: contexts have no integration

Vaughn Vernon, in *Implementing Domain-Driven Design* (2013), extended Evans's work: "A Bounded Context is an explicit boundary within which a domain model exists. The domain model expresses a Ubiquitous Language as a software model" (Vernon 2013, 60).

**Application to AI-agent spec-based development:** Bounded contexts provide a natural decomposition unit for agent work assignments. Each agent operates within a bounded context, with explicit context maps defining how their work integrates with other contexts. The Anti-Corruption Layer pattern is particularly relevant -- it suggests that each agent's output should be translated through a well-defined interface before being consumed by other agents.

### 6. Hierarchical Task Network Planning

Hierarchical Task Network (HTN) planning is an AI planning technique where complex tasks are recursively decomposed into simpler subtasks until primitive (directly executable) tasks are reached. Erol, Hendler, and Nau (1994) formalized HTN planning, showing that it is strictly more expressive than classical STRIPS-style planning.

In HTN planning, the domain knowledge is encoded as **methods** -- recipes for decomposing compound tasks into subtasks. Ghallab, Nau, and Traverso (2004) describe: "Rather than searching through a space of possible world states, an HTN planner searches through a space of possible plan refinements" (Ghallab, Nau, and Traverso 2004, 229).

**Application to AI-agent spec-based development:** HTN planning provides a formal framework for specification decomposition. High-level specifications can be recursively decomposed into implementable work units using method templates. The ordering constraints in the resulting task network define the dependency structure that determines which agents can work in parallel and which must wait for others.

### 7. Conway's Law and the Inverse Conway Maneuver

Melvin Conway's 1968 paper articulated what became Conway's Law: "Any organization that designs a system (defined broadly) will produce a design whose structure is a copy of the organization's communication structure" (Conway 1968, 31).

Empirical validation has been provided by multiple studies. MacCormack, Rusnak, and Baldwin (2012) found strong correlations between organizational structure and software architecture: "the organizational structure of the development team is a significant predictor of the modularity of the products they develop" (MacCormack, Rusnak, and Baldwin 2012, 665).

The **Inverse Conway Maneuver**, popularized by Thoughtworks, proposes deliberately structuring teams to produce the desired architecture. Skelton and Pais (2019) formalized this: "An organization that is arranged in functional silos... is unlikely to ever produce software systems that are well-architected for end-to-end flow" (Skelton and Pais 2019, 13).

**Application to AI-agent spec-based development:** Conway's Law applies equally to AI agents. By deliberately designing agent communication patterns, an orchestrator can shape the resulting architecture. The Inverse Conway Maneuver for AI agents means structuring agent teams and their communication channels to produce the desired system architecture.

### 8. Coupling, Cohesion, and Decomposition Quality

Stevens, Myers, and Constantine (1974) introduced coupling and cohesion as quality measures for modular decomposition. They defined **coupling** as "the measure of the strength of association established by a connection from one module to another" and **cohesion** as "the degree to which the elements within a module belong together" (Stevens, Myers, and Constantine 1974, 116, 121).

They identified hierarchies of coupling types (content, common, control, stamp, data) and cohesion types (coincidental, logical, temporal, procedural, communicational, sequential, functional). The goal of good decomposition is to minimize coupling between modules while maximizing cohesion within modules.

**Application to AI-agent spec-based development:** Coupling and cohesion metrics provide objective criteria for evaluating specification decomposition. Work units assigned to different agents should have minimal coupling (ideally only data coupling through well-defined interfaces), while the work within each agent's assignment should have high cohesion (ideally functional cohesion).

### 9. How AI Changes Optimal Decomposition

The introduction of AI agents as developers fundamentally alters the economics of decomposition:

**Reduced coordination cost per agent**: AI agents don't need meetings, don't have egos, and can read specifications instantly. The communication overhead that Brooks identified -- n(n-1)/2 communication channels for n team members -- still exists but at lower cost per channel.

**Increased specification cost**: Humans can work from ambiguous specifications using professional judgment. AI agents require more explicit specifications, increasing the upfront cost of decomposition.

**Context window as cognitive load**: Each agent's context window is a hard limit on its "cognitive load." This creates a natural decomposition constraint: each work unit must be small enough to fit, with its full specification and relevant context, within the agent's context window.

**Cheapness of experimentation**: AI agents can generate and test many implementation alternatives quickly. This increases the option value of modularity (per Baldwin and Clark) and argues for finer decomposition.

---

## Part B: Software Development Process Simulations and Empirical Studies

### 1. Accelerate: DORA Metrics and Software Delivery Performance

Forsgren, Humble, and Kim's *Accelerate* (2018) presents findings from four years of the State of DevOps research program (2014--2017), analyzing data from over 23,000 survey responses. Four key metrics predict software delivery performance:

1. **Lead time for changes**: time from code committed to code running in production
2. **Deployment frequency**: how often the organization deploys to production
3. **Mean time to restore (MTTR)**: how long it takes to recover from a failure
4. **Change failure rate**: what percentage of changes result in degraded service

A critical finding: "High performers do better at all four of these measures... There are no trade-offs between improving speed and improving stability" (Forsgren, Humble, and Kim 2018, 19).

Key architectural capabilities include **loosely coupled architectures** and **empowered teams**: "Teams that can choose which tools to use do better at continuous delivery... Teams that can make changes without requiring approval from outside the team are more productive" (Forsgren, Humble, and Kim 2018, 45--47).

**Application to AI-agent spec-based development:** DORA metrics provide the evaluation framework for an AI-agent development process. A well-designed spec-based process should optimize all four metrics simultaneously -- the Accelerate research suggests this is achievable through architectural looseness and agent autonomy.

### 2. Agent-Based Modeling of Software Development

Wickenberg and Davidsson (2003) developed an agent-based simulation of software development that modeled developers as agents with varying skill levels. They found that communication patterns between agents significantly affected project outcomes, and that "the optimal team structure depends on the nature of the task interdependencies."

Joslin and Poole (2005) created a VDT model incorporating task dependencies, rework cycles, and communication overhead. Key findings: increasing team size beyond an optimal point decreased productivity (consistent with Brooks's Law) and task decomposition quality was the strongest predictor of project success.

Xia et al. (2024) proposed ChatDev, assigning different roles (CEO, CTO, programmer, tester) to different LLM instances. They found that structured communication protocols between agents significantly reduced defects compared to unstructured collaboration.

### 3. System Dynamics Models

Abdel-Hamid and Madnick's *Software Project Dynamics* (1991) captured feedback loops including the **rework cycle**: "When a software defect goes undetected, subsequent development activities build on the defective base, compounding the eventual cost of correction" (Abdel-Hamid and Madnick 1991, 84). And schedule pressure effects: "As schedule pressure increases, the workforce is driven to cut corners... The resulting quality problems later consume even more time" (Abdel-Hamid and Madnick 1991, 122).

**Application to AI-agent spec-based development:** The most impactful quality gate is specification review -- catching specification defects before agents begin implementation prevents cascading rework.

### 4. The Mythical Man-Month

Brooks's key observations (1975):

**Brooks's Law**: "Adding manpower to a late software project makes it later" (Brooks 1975, 25).

**Conceptual integrity**: "It is better to have a system omit certain anomalous features and improvements, and to reflect one set of design ideas, than to have one that contains many good but independent and uncoordinated ideas" (Brooks 1975, 42).

**Application:** Decomposition should minimize inter-agent communication, and a human architect or architectural specification should maintain conceptual integrity.

### 5. Product Development Flow

Reinertsen's *The Principles of Product Development Flow* (2009):

**Batch size**: "Reducing batch size is the single most important thing we can do to improve flow" (Reinertsen 2009, 113).

**WIP limits**: "When capacity utilization increases, cycle time increases exponentially" (Reinertsen 2009, 61).

**Cost of delay**: "If you only quantify one thing, quantify the cost of delay" (Reinertsen 2009, 31).

**Fast feedback**: "The most important thing we can do to improve product development is to shorten feedback loops" (Reinertsen 2009, 183).

**Application:** Small specifications with immediate testing and review, not large feature specifications with deferred integration.

### 6. Specification Quality and Development Outcomes

Hofmann and Lehner (2001): "requirements quality is the single most important factor in software project success" (Hofmann and Lehner 2001, 58).

Femmer et al. (2017): "ambiguous requirements led to 300% more implementation defects compared to unambiguous requirements" (Femmer et al. 2017, 562).

**Application:** For AI agents, specifications must be unambiguous, complete (within scope), testable, and consistent. The 300% defect increase from ambiguous requirements will likely be even higher for AI agents.

### 7. AI-Augmented Development

Peng et al. (2023): "developers using Copilot completed tasks 55.8% faster on average" (Peng et al. 2023, 7).

Khlaaf (2023): "the primary risk is not that AI will generate incorrect code, but that the velocity of AI-generated code will overwhelm human capacity for review and oversight" (Khlaaf 2023, 12).

Dakhel et al. (2023): "LLM-generated code passes functional tests at rates comparable to human-written code for well-specified problems, but exhibits lower maintainability, readability, and adherence to coding conventions" (Dakhel et al. 2023, 15).

---

## Synthesis: Implications for AI-Agent Spec-Based Development

1. **Decomposition quality is the primary determinant of parallel development success** (Stevens, Myers, and Constantine 1974; Baldwin and Clark 2000; Parnas 1972).

2. **Specifications replace tacit knowledge.** The research on specification quality (Femmer et al. 2017; Hofmann and Lehner 2001) shows that ambiguous requirements dramatically increase defects. For AI agents, specification quality is the single most critical process factor.

3. **The bottleneck shifts from production to review** (Khlaaf 2023). Process design must manage this asymmetry.

4. **Small batches and fast feedback optimize flow** (Reinertsen 2009). Small specifications with immediate testing and review.

5. **Architecture mirrors organization.** Conway's Law applies to AI agents just as it applies to human teams.

6. **Cognitive load limits apply, differently.** For AI agents, it maps to context window limitations (Skelton and Pais 2019).

7. **Conceptual integrity requires central authority** (Brooks 1975). A human architect or architectural specification must maintain coherence.

---

## Bibliography

Abdel-Hamid, Tarek, and Stuart Madnick. 1991. *Software Project Dynamics: An Integrated Approach*. Englewood Cliffs, NJ: Prentice Hall.

Baldwin, Carliss Y., and Kim B. Clark. 2000. *Design Rules: The Power of Modularity*. Cambridge, MA: MIT Press.

Brooks, Frederick P., Jr. 1975. *The Mythical Man-Month: Essays on Software Engineering*. Reading, MA: Addison-Wesley. Anniversary edition, 1995.

Conway, Melvin E. 1968. "How Do Committees Invent?" *Datamation* 14 (4): 28--31.

Dakhel, Arghavan Moradi, et al. 2023. "GitHub Copilot AI Pair Programmer: Asset or Liability?" *Journal of Systems and Software* 203: 111734.

Erol, Kutluhan, James Hendler, and Dana S. Nau. 1994. "HTN Planning: Complexity and Expressivity." In *Proceedings of AAAI-94*, 1123--28.

Evans, Eric. 2003. *Domain-Driven Design: Tackling Complexity in the Heart of Software*. Boston: Addison-Wesley.

Femmer, Henning, Daniel Mendez Fernandez, Stefan Wagner, and Sebastian Eder. 2017. "Rapid Quality Assurance with Requirements Smells." *Journal of Systems and Software* 123: 515--33.

Forsgren, Nicole, Jez Humble, and Gene Kim. 2018. *Accelerate: The Science of Lean Software and DevOps*. Portland, OR: IT Revolution Press.

Ghallab, Malik, Dana Nau, and Paolo Traverso. 2004. *Automated Planning: Theory and Practice*. San Francisco: Morgan Kaufmann.

Hofmann, Hubert F., and Franz Lehner. 2001. "Requirements Engineering as a Success Factor in Software Projects." *IEEE Software* 18 (4): 58--66.

INCOSE. 2015. *Systems Engineering Handbook*. 4th ed. Hoboken, NJ: Wiley.

Joslin, David, and William Poole. 2005. "Agent-Based Simulation for Software Project Planning." In *Proceedings of the Winter Simulation Conference*, 1059--66.

Khlaaf, Heidy. 2023. "Toward Comprehensive Risk Assessments and Assurance of AI-Based Systems." *Trail of Bits Technical Report*.

MacCormack, Alan, John Rusnak, and Carliss Y. Baldwin. 2012. "Exploring the Duality between Product and Organizational Architectures." *Research Policy* 41 (8): 1309--24.

Norman, Eric, Robert Corbett, and Mark Butler. 2011. "The Work Breakdown Structure: A Review." *Proceedings of the PMI Research and Education Conference*.

Parnas, David L. 1972. "On the Criteria To Be Used in Decomposing Systems into Modules." *Communications of the ACM* 15 (12): 1053--58.

Patton, Jeff. 2014. *User Story Mapping*. Sebastopol, CA: O'Reilly Media.

Peng, Sida, et al. 2023. "The Impact of AI on Developer Productivity: Evidence from GitHub Copilot." arXiv preprint arXiv:2302.06590.

PMI. 2021. *A Guide to the Project Management Body of Knowledge (PMBOK Guide)*. 7th ed.

Reinertsen, Donald G. 2009. *The Principles of Product Development Flow*. Redondo Beach, CA: Celeritas Publishing.

Skelton, Matthew, and Manuel Pais. 2019. *Team Topologies*. Portland, OR: IT Revolution Press.

Stevens, Wayne P., Glenford J. Myers, and Larry L. Constantine. 1974. "Structured Design." *IBM Systems Journal* 13 (2): 115--39.

Steward, Donald V. 1981. "The Design Structure System." *IEEE Transactions on Engineering Management* 28 (3): 71--74.

Vernon, Vaughn. 2013. *Implementing Domain-Driven Design*. Upper Saddle River, NJ: Addison-Wesley.

Wickenberg, Tommy, and Paul Davidsson. 2003. "On Multi-Agent Based Simulation of Software Development Processes." In *Multi-Agent-Based Simulation II*, 171--80. Berlin: Springer.

Xia, Chen, et al. 2024. "ChatDev: Communicative Agents for Software Development." In *Proceedings of ACL 2024*, 15174--86.
