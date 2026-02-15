# Research Track 3: Development Methodology and Innovation Management

## Spec-Driven Development Maturity (3A) and R&D / Product Incubation (3B)

*Research Report prepared 2026-02-14*

---

## Part I: Spec-Driven Development Maturity (Track 3A)

### 1. Model-Driven Architecture and Model-Driven Engineering

The Object Management Group's Model-Driven Architecture (MDA) represents the most sustained institutional effort to make specifications the primary development artifact. MDA separates concerns into three layers: the Platform-Independent Model (PIM), the Platform-Specific Model (PSM), and the Platform Description Model (PDM), with automated transformations between them (Kleppe, Warmer, and Bast 2003, 12-15). The foundational insight---that models should drive code generation rather than merely document it---directly anticipates the spec-driven AI development paradigm.

Jean Bezivin formalized the intellectual foundation for this movement. He defined model-driven engineering as "a software engineering methodology which uses formal models, i.e., models which are machine-readable and processable, to produce executable software systems semi-automatically" (Bezivin 2005, 2). Bezivin's central principle is that models and their meta-models are "first-class entities" from requirements capture through implementation and runtime adaptation. Every model instance is tied to a meta-model, enabling static type-checking, semantic validation, and automated transformation (Bezivin 2006, 175).

Brambilla, Cabot, and Wimmer extended this into a practitioner's guide, documenting how model-based approaches improve daily software practice. Their treatment spans building domain-specific modeling languages, describing model-to-text and model-to-model transformations, and selecting tools for managing MDSE projects. They note that "MDSE practices have proved to increase efficiency and effectiveness in software development, as demonstrated by various quantitative and qualitative studies" (Brambilla, Cabot, and Wimmer 2017, 4).

Volter and Stahl provided the engineering-management bridge. They define MDSD as using "domain-specific languages to create models that express application structure or behaviour in an efficient and domain-specific way," with models "subsequently transformed into executable code by a sequence of model transformations" (Stahl and Volter 2006, 7). Their emphasis on the separation of domain concern from technical concern parallels the spec-driven development approach, where the specification captures domain intent and the AI agent handles technical implementation.

**Application to AI-agent spec-driven development:** MDA/MDE demonstrated that specifications can be primary artifacts from which executable systems are derived. The key lesson is that the specification language must be precise enough for machine processing yet expressive enough for domain experts. In AI-agent development, the spec serves the same role as the PIM---capturing intent independent of implementation platform---while the AI agent replaces the model transformation engine.

### 2. Formal Methods in Industry

#### 2.1 TLA+ and Amazon Web Services

The most significant industrial validation of formal specification came from Amazon Web Services. Newcombe et al. reported that since 2011, AWS engineers had used TLA+ for formal specification and model checking of critical distributed systems. Their conclusion was direct: "Engineers use TLA+ to prevent serious but subtle bugs from reaching production" (Newcombe et al. 2015, 66). Seven AWS teams applied TLA+ to systems including S3, DynamoDB, and EBS, finding that "subtle bugs can hide in complex concurrent fault-tolerant systems" and that conventional testing and code review could not reliably surface them.

The practical accessibility of formal methods was a key finding. Newcombe et al. reported that "engineers from entry-level to principal have been able to learn TLA+ from scratch and get useful results in two to three weeks, in some cases in their personal time on weekends and evenings, without further help or training" (Newcombe et al. 2015, 70). This demolished the longstanding objection that formal methods are too difficult for working engineers.

Leslie Lamport developed TLA+ as a formal specification language based on temporal logic and set theory. His textbook *Specifying Systems* presents TLA+ as enabling mathematical precision in describing the set of all possible legal behaviors of a system (Lamport 2002, 3). The language's power lies in its ability to specify both safety properties (nothing bad happens) and liveness properties (something good eventually happens).

**Application to AI-agent spec-driven development:** TLA+ demonstrates that formal specifications of system behavior catch errors that no amount of testing will find. For AI agent teams, the implication is that the more formally constrained the specification, the more reliably agents can execute against it. The Amazon experience shows a practical middle ground: specifications need not be fully formal proofs, but structured precision dramatically improves outcomes.

#### 2.2 Alloy and Lightweight Formal Methods

Daniel Jackson's Alloy language introduced the concept of "lightweight formal methods"---drawing on the rigor of formal specification but replacing theorem proving with automated analysis that gives designers immediate feedback. Jackson describes this as "agile modeling," taking "from formal specification the idea of a precise and expressive notation based on a tiny core of simple and robust concepts but replac[ing] conventional analysis based on theorem proving with a fully automated analysis" (Jackson 2012, xii). Alloy uses a minimal toolkit of mathematical notions to capture the essence of software abstractions, with the Alloy Analyzer providing automatic counterexample generation.

Jackson collaborated with NASA on air-traffic control, Massachusetts General Hospital on proton therapy, and Toyota on autonomous cars---all domains where specification errors have life-or-death consequences (Jackson 2012). His work earned ACM Impact and Outstanding Research Awards.

**Application to AI-agent spec-driven development:** Lightweight formal methods represent the most promising approach for AI-agent specifications. Full formal verification is too heavy for most development workflows, but Alloy-style automated analysis of specs before passing them to AI agents could catch structural inconsistencies, missing edge cases, and contradictory requirements. The spec becomes both the instruction to the agent and the verification criteria for its output.

#### 2.3 Z, B Method, and VDM

Z notation, the B-Method, and VDM are model-based formal specification languages that use mathematical notation for unambiguous requirements specification (Kaur 2012, 227). Z is particularly popular in safety-critical systems, while the B method was used for the Paris Metro Line 14 driverless system and the Roissy Charles de Gaulle airport shuttle---systems requiring zero-defect software. VDM has been applied to real-time control systems and trading platforms (Kaur 2012, 229). NASA's Formal Methods Specification and Verification Guidebook documents the agency's systematic use of these approaches for flight software and mission-critical systems (NASA 1998).

### 3. Design by Contract

Bertrand Meyer's Design by Contract (DbC) introduced a paradigm where software correctness is defined through preconditions, postconditions, and class invariants. Meyer coined the term in connection with the Eiffel programming language, first describing it in the 1988 and 1997 editions of *Object-Oriented Software Construction*. The contractual metaphor is precise: "If the class invariant AND precondition are true before a supplier is called by a client, then the invariant AND the postcondition will be true after the service has been completed" (Meyer 1997, 342). Under inheritance, subclasses may weaken preconditions but not strengthen them, and may strengthen postconditions but not weaken them---the Liskov Substitution Principle formalized as contract refinement.

Meyer's contribution extends beyond individual function boundaries. When applied at the system level, contracts become specifications of inter-component agreements. Each module advertises what it requires (preconditions) and what it guarantees (postconditions), with invariants defining the consistent state space.

**Application to AI-agent spec-driven development:** Design by Contract maps directly to spec-driven agent work. Each agent task can be specified with preconditions (what must be true before the agent begins), postconditions (what must be true when the agent finishes), and invariants (what must never be violated during execution). This transforms vague task descriptions into verifiable contracts. If the agent produces output that violates a postcondition, the work is automatically flagged---no human review needed for structural compliance.

### 4. Domain-Driven Design as Living Specification

Eric Evans's *Domain-Driven Design* introduced the concept of ubiquitous language---"a common, rigorous language between developers and users" that is used "not only in discussions about the requirements for a software product but in discussions of design as well and all the way into the product's source code itself" (Evans 2003, 24-25). The domain model serves as the backbone of the system, with bounded contexts establishing clear specification boundaries within which terms have consistent, unambiguous meaning.

Evans defined DDD as an approach that focuses on three activities: "(1) Focus on the core domain; (2) Explore models in a creative collaboration of domain practitioners and software practitioners; (3) Speak a ubiquitous language within an explicitly bounded context" (Evans 2003, xxii). Bounded contexts are regions where "ambiguity is eliminated"---a boundary within which particular terms, definitions, and rules apply consistently.

**Application to AI-agent spec-driven development:** DDD's ubiquitous language is the natural language equivalent of a formal specification language. For AI agents, bounded contexts solve a critical problem: they constrain the semantic space within which the agent must interpret instructions. A spec written within a well-defined bounded context eliminates the ambiguity that causes AI agents to hallucinate or misinterpret requirements. The spec becomes more reliable not because it is more formal, but because the language within it has been rigorously defined through domain modeling.

### 5. Executable Specifications and Behavior-Driven Development

#### 5.1 BDD Origins

Dan North introduced Behavior-Driven Development in 2006, describing it as an evolution of TDD where "the shift from thinking in tests to thinking in behaviour" was "so profound that he started referring to TDD as BDD" (North 2006). Working with business analyst Chris Matts, North developed the Given/When/Then template to capture acceptance criteria in an executable form. This was directly influenced by Evans's ubiquitous language: BDD bridges the gap "between business people and technical people by encouraging collaboration across roles to build shared understanding of the problem to be solved" (Cucumber Documentation 2024).

#### 5.2 Specification by Example

Gojko Adzic's *Specification by Example* formalized BDD into a collaborative method featuring seven process patterns. The central insight is that "an automated specification with examples, still in a human-readable form and easily accessible to all team members, becomes an executable specification" (Adzic 2011, 4). The end product is "living documentation"---specifications that are always up-to-date because they are automatically checked against system behavior.

Adzic's seven patterns---deriving scope from goals, specifying collaboratively, illustrating with examples, refining specifications, automating without changing specifications, validating frequently, and evolving living documentation---describe a complete lifecycle from requirement to verified behavior (Adzic 2011, 12-15).

**Application to AI-agent spec-driven development:** BDD/Specification by Example provides the most direct precedent for AI-agent spec execution. The Given/When/Then format is essentially a structured prompt that an AI agent can parse and execute. The living documentation concept means specs and tests are the same artifact---precisely the "spec as source of truth" paradigm. The key advance for AI agents is that these executable specifications can serve simultaneously as instructions (telling the agent what to build), acceptance criteria (testing whether the agent built it correctly), and documentation (recording what was built and why).

### 6. Literate Programming: The Original Spec-Code Unity

Donald Knuth introduced literate programming in 1984 with a radical reframing: "Let us change our traditional attitude to the construction of programs: Instead of imagining that our main task is to instruct a computer what to do, let us concentrate rather on explaining to human beings what we want a computer to do" (Knuth 1984, 97). His WEB system used two operations---TANGLE (producing compilable source code) and WEAVE (producing formatted documentation)---from a single source that interleaved natural language explanation with code.

Knuth argued that literate programming "provides higher-quality programs, since it forces programmers to explicitly state the thoughts behind the program, making poorly thought-out design decisions more obvious" (Knuth 1984, 99). The program is written as an article explaining the design, with all source code embedded within that explanation.

**Application to AI-agent spec-driven development:** Literate programming anticipated the spec-driven paradigm by forty years. Knuth's insight that explaining intent to humans improves code quality maps directly to the AI-agent context, where the "human" reading the explanation is now an LLM. The spec-as-article concept---where narrative explanation and executable instructions coexist in a single document---is precisely what modern spec-driven development tools produce. The difference is that while Knuth's TANGLE extracted code from prose, AI agents generate code from prose.

### 7. Specification-First API Development

The OpenAPI (formerly Swagger) specification represents a widely adopted micro-example of spec-driven development. The design-first approach "advocates for designing the API's contract first before writing any code," using the specification document to "create mock servers and mock APIs, which allow you to try out API designs and test APIs before deploying them" (Stoplight 2024). This enables parallel development across teams, automatic generation of client libraries and documentation, and earlier error detection---"fixing issues once the API is coded costs far more than fixing them during the design phase" (Stoplight 2024).

**Application to AI-agent spec-driven development:** OpenAPI demonstrates that even a relatively simple specification format dramatically improves development coordination. For multi-agent systems, API-style contracts between agents---specifying inputs, outputs, error conditions, and behavioral guarantees---could enable agents to develop interacting components in parallel, just as human teams use OpenAPI specs for parallel development.

### 8. The Emerging Discipline of Spec-Driven AI Development

The convergence of these traditions has produced a new discipline. Piskala identifies three levels of specification rigor in AI-agent development: "spec-first" (a specification is written before AI-assisted coding begins), "spec-anchored" (the specification guides iterative AI development), and "spec-as-source" (the specification is the primary artifact, edited by humans while agents generate code) (Piskala 2026, 3-4). This taxonomy maps directly to the MDA hierarchy: spec-first corresponds to code generation from PIM, spec-anchored to iterative model refinement, and spec-as-source to the full MDE vision where the model IS the system.

Thoughtworks identified spec-driven development as "one of the most important practices to emerge in 2025," noting that "even simply applying a more structured prompt and more explicit technical constraints can produce better code than a plain PRD" (Thoughtworks 2025). Controlled studies suggest that "human-refined specs significantly improve LLM-generated code quality, with error reductions of up to 50%" (Piskala 2026, 11).

The key finding across this research is that specification quality and agent effectiveness are directly correlated. As specifications move from natural language toward structured, bounded, contractual forms---drawing on DDD's ubiquitous language, Meyer's design by contract, Adzic's specification by example, and formal methods' mathematical rigor---AI agents produce more reliable, correct, and maintainable output.

---

## Part II: R&D and Product Incubation / Centers of Excellence (Track 3B)

### 1. Bell Labs: The Integrated Innovation Model

Jon Gertner's history of Bell Labs documents the most successful industrial research laboratory in history. Approximately 15 percent of Bell Labs staff worked in pure research---physicists, chemists, and metallurgists seeking new knowledge---while the larger group worked in development (Gertner 2012, 78). The critical organizational feature was the deliberate integration of these groups.

Mervin Kelly, who led Bell Labs through its golden era, designed the physical and organizational environment to force interaction. Gertner reports that the "handoff between the three departments at Bell Labs was often (and intentionally) quite casual," and that what made the Labs function as "a living organism" were "social and professional exchanges that moved back and forth between pure researchers and applied engineers through formal talks and informal chats, which were always encouraged" (Gertner 2012, 134). Kelly even created "branch laboratories" at Western Electric factories so that researchers could participate directly in the transition from development to manufacturing (Gertner 2012, 138).

Kelly's successor understood how to "manage this diverse cohort and above all how to promote an ethic of generally unstinting cooperation, open doors, and what is now called mentoring" (Gertner 2012, 151).

**Application to AI-agent spec-driven development:** Bell Labs' integrated model suggests that the handoff between spec creation, agent execution, and production deployment should be intentionally casual and continuous, not gated and formal. The "branch laboratory" concept translates to embedding spec-driven development teams within production operations so they understand real constraints. The social exchange between researchers and engineers maps to iterative collaboration between spec authors and AI agents, where both sides learn from each other across iterations.

### 2. Xerox PARC: Innovation Without Transfer

Michael Hiltzik's account of Xerox PARC documents a research organization that produced extraordinary innovations---the graphical user interface, the laser printer, Ethernet, the personal computer---but failed to commercialize them. Hiltzik attributes PARC's creative success to "robust financial support from Xerox headquarters, a historical moment of dynamic change in computer technology, an economy conducive to recruiting top talent, and leadership that knew how to maximize human capital" (Hiltzik 1999, 23). Xerox headquarters "gave the PARC team complete freedom from deadlines and directives to foster a creative environment---it worked perhaps too well" (Hiltzik 1999, 102).

The failure was structural, not intellectual. Hiltzik argues that "Xerox's size may have served as an impediment to commercializing PARC's innovations" and that Xerox management "ultimately did not know what to make of their inventions and enter an entirely new business that no one at the time knew what it really was" (Hiltzik 1999, 390). Xerox's "approach to developing this technology grew out of traditional Xerox methods---viewing it as a large-scale program that would take five years to reach market when they could have reached market much sooner" (Hiltzik 1999, 356).

**Application to AI-agent spec-driven development:** PARC's lesson is that innovation must be structurally connected to commercialization pathways. For spec-driven development, this means that research specs (exploring what AI agents can do) must share format, tooling, and review processes with production specs (defining what agents will do in production). A separate spec format or workflow for "research" versus "production" creates the same transfer gap that hobbled PARC.

### 3. DARPA: Empowered Program Managers and Bounded Time

DARPA's organizational model is characterized by "a flat organization that empowers its tenure-limited program managers with trust, autonomy, and the ability to take risks on innovative ideas" (Bonvillian, Van Atta, and Windham 2019, 12). Program managers are hired from technical positions in academia, industry, and government, typically serving one term of three to five years. They "focus on high-risk/high-payoff projects that typically run for four to six years each, with well-defined metrics to measure success" (Bonvillian 2018, 901).

DARPA attributes its success to four factors: "(1) trust and autonomy; (2) limited tenure and the urgency it promotes; (3) a sense of mission; and (4) risk-taking and tolerance for failure" (DARPA 2024). The agency's program managers are "charged with creating new programs and projects and quickly funding innovative ideas," unlike most program managers in federal R&D agencies who manage existing portfolios (Bonvillian 2018, 903).

The time-bounded nature of DARPA programs is particularly instructive. Limited tenure creates urgency, prevents bureaucratic accretion, and forces clear success criteria at the outset. Programs that do not demonstrate progress against well-defined metrics are terminated.

**Application to AI-agent spec-driven development:** DARPA's model suggests that spec-driven innovation projects should have empowered owners with bounded time horizons and clear metrics. Each spec project should define its kill criteria upfront. The flat organization and program manager autonomy translate to giving spec authors direct authority over the AI agents executing their specifications, without layers of approval that slow iteration.

### 4. Google X: Kill Criteria and Staged Evaluation

Alphabet's X (formerly Google X) operationalizes rapid-evaluation innovation. Astro Teller, X's "Captain of Moonshots," describes a process of "greenlighting everything" and then "redlighting most projects quickly, following kill criteria you've agreed to in advance" (Teller 2023). X maintains a deliberate 2% success rate across more than 100 annual projects.

The evaluation process has two stages. In the first, "investigators get a few weeks and a few thousand dollars to try to understand a nascent moonshot's biggest risks; this kills many dozens of ideas quickly." The second stage provides "a couple of team members a few months and a bit more money to build prototypes, running at the hardest and riskiest parts of the technology" (Teller 2023). X maintains a "Design Kitchen and several hardware labs that teams can tap for design sprints, rapid prototyping, and failure analysis," enabling small teams to "act like teams of fifty" (Teller 2023).

The organizational culture "constantly tr[ies] to find reasons to kill off projects by tackling the hardest parts first, and both celebrat[es] and reward[s] staff when projects [are] killed" (Teller 2023). This inverts the typical incentive structure where teams defend their projects to survive.

**Application to AI-agent spec-driven development:** X's model maps directly to spec-driven innovation. Stage 1 rapid evaluation is writing a minimal spec and having an AI agent attempt the hardest part first. If the agent cannot produce viable output from the specification, the concept is killed early at minimal cost. Stage 2 prototyping is a more complete spec execution. The "Design Kitchen" shared infrastructure corresponds to shared spec templates, agent tooling, and review processes that reduce per-project overhead. Kill criteria should be embedded in the spec itself---conditions under which the spec is declared infeasible.

### 5. Stage-Gate Process

Robert Cooper's Stage-Gate system provides the dominant framework for managing new product development, now implemented by "almost 80% of North American companies" (Cooper 2017, 5). The system consists of a series of stages, "each prescrib[ing] the key tasks and best practices for the project team to execute," preceded by gates that are "the quality check and Go/Kill or investment decision points" (Cooper 2017, 12). At each gate, one of five decisions is made: Go, Kill, Hold, Recycle, or Conditional Go.

Cooper has evolved Stage-Gate to incorporate agile methods, creating the Agile-Stage-Gate hybrid that "has been made more adaptive, agile, and flexible" and "modified to suit the new world of open innovation" (Cooper 2017, 22). This hybrid represents "a significant change to our thinking about how new-product development should be done since the introduction of today's popular gating systems thirty years ago" (Cooper 2016, 424).

**Application to AI-agent spec-driven development:** Stage-Gate maps naturally to spec-driven development governance. Each stage corresponds to a spec maturity level: ideation (natural language concept), scoping (structured requirements), development (executable specification with test criteria), testing (agent-executed spec with validation), and launch (production-grade spec). Gates are review points where the spec is evaluated for completeness, feasibility, and business value before advancing to the next level of AI agent investment.

### 6. Lean Startup at Organizational Scale

Eric Ries defined a startup as "an organization dedicated to creating something new under conditions of extreme uncertainty" and argued that this definition applies to teams within large organizations as much as to garage ventures (Ries 2011, 8). His Build-Measure-Learn feedback loop speeds through three phases: building a minimum viable product (MVP), measuring customer response with actionable metrics, and learning "whether to pivot or persevere" (Ries 2011, 75).

Ries introduced innovation accounting as a framework for measuring progress under uncertainty. It operates in three steps: "(1) Use a minimum viable product to establish real data on where the company is right now. (2) Startups must attempt to tune the engine from the baseline toward the ideal. (3) Pivot or persevere" (Ries 2011, 117). The central insight is that "the only way to win is to learn faster than anyone else" (Ries 2011, 5).

Validated learning---"the unit of progress for lean startups"---is demonstrated by running experiments that test elements of the business model, not by producing features or writing code (Ries 2011, 49). This distinguishes real progress from "vanity metrics" that look good but do not indicate whether the product is moving toward viability.

**Application to AI-agent spec-driven development:** The Lean Startup framework directly applies to spec-driven R&D. A minimum viable specification (MVS) is the smallest spec that can produce an agent-executed prototype sufficient to test a hypothesis. Innovation accounting for specs measures: how many iterations to reach acceptable output, what percentage of spec changes result in measurably better agent output, and whether the spec is converging toward a production-ready state or oscillating. The Build-Measure-Learn loop becomes Write-Execute-Evaluate: write the spec, let the agent execute it, evaluate the output against success criteria, and refine.

### 7. Three Horizons Framework

Baghai, Coley, and White's Three Horizons framework, introduced in *The Alchemy of Growth*, addresses the problem that "successful incumbents tended to optimize the core business (Horizon 1) while underinvesting in emerging businesses (Horizon 2) and future options (Horizon 3)" (Baghai, Coley, and White 1999, 4-5). The framework provides a "simple, shared language and structure to manage a balanced growth portfolio---protecting and optimizing H1 while systematically building H2 and planting H3 options" (McKinsey 2009).

- **Horizon 1:** Core businesses at scale requiring continuous improvement and defend/extend measures.
- **Horizon 2:** Emerging businesses with product-market fit in sight, needing scaling and selective innovation.
- **Horizon 3:** Options for future growth---early-stage ideas, experiments, or technologies being validated.

**Application to AI-agent spec-driven development:** The Three Horizons provide a natural portfolio structure for spec-driven work. H1 specs are production specifications that agents execute reliably and repeatedly---these need governance, version control, and regression testing. H2 specs define emerging capabilities being scaled---agent-executed but still being refined through iteration. H3 specs are experimental---exploring what new things agents might accomplish, with high failure rates expected and encouraged. Organizations must deliberately allocate spec-authoring effort across all three horizons.

### 8. Ambidextrous Organization

O'Reilly and Tushman's research on organizational ambidexterity demonstrated that firms must simultaneously exploit existing capabilities and explore new opportunities. They found that "more than 90% of those using the ambidextrous structure succeeded in their attempts, while none of the cross-functional or unsupported teams, and only 25% of those using functional designs, reached their goals" (O'Reilly and Tushman 2004, 76).

The ambidextrous structure "separate[s] their new, exploratory units from their traditional, exploitative ones, allowing them to have different processes, structures, and cultures; at the same time, they maintain tight links across units at the senior executive level" (O'Reilly and Tushman 2004, 74). This "mental balancing act is one of the toughest of all managerial challenges---it requires executives to explore new opportunities even as they work diligently to exploit existing capabilities" (O'Reilly and Tushman 2004, 80).

**Application to AI-agent spec-driven development:** The ambidextrous model applies directly. Exploitative spec-driven development (agents executing well-understood specifications for production workloads) requires different processes, tools, and cultures than exploratory spec-driven development (testing whether agents can handle novel specification types). These should be structurally separated but linked at the leadership level, so that successful explorations can be transferred to production. Attempting to run both in a single team with a single process creates the conflict that O'Reilly and Tushman document: exploitation always wins because it has shorter feedback loops and clearer metrics.

### 9. The Innovator's Dilemma and Structural Solutions

Clayton Christensen's foundational work demonstrated that "in the cases of well-managed firms, good management was the most powerful reason they failed to stay atop their industries. Precisely because these firms listened to their customers, invested heavily in new technologies that would provide their customers more and better products of the sort they wanted, and because they carefully studied market trends and systematically allocated investment capital to innovations that promised the best returns, they lost their positions of leadership" (Christensen 1997, xii).

Christensen's structural solution is to "maintain small, nimble divisions that attempt to replicate [disruptive innovation] internally to avoid being blindsided and overtaken by startup competitors" (Christensen 1997, 182). Alternatively, acquiring a smaller company can "leverage its capabilities toward success" (Christensen 1997, 185). The key insight is that disruptive innovation cannot be managed within the same organizational unit that serves existing customers---it requires structural separation.

**Application to AI-agent spec-driven development:** AI-agent spec-driven development is itself a disruptive technology relative to traditional software development. Organizations that optimize their existing development processes---code review, manual testing, human-only architecture decisions---will be disrupted by organizations that shift to spec-driven agent development. Christensen's prescription applies: the spec-driven development capability must be structurally separated from existing development teams, with its own processes, metrics, and customer relationships, or it will be killed by the gravity of the existing development organization.

### 10. Exploration vs. Exploitation in Organizational Learning

James March's seminal paper established the theoretical foundation for balancing exploration and exploitation. He demonstrated that "the choice to rapidly develop exploitation over exploration might be effective in the short term, but is potentially detrimental to the firm in the long term" (March 1991, 71). Organizations that over-exploit converge prematurely on suboptimal approaches; organizations that over-explore never capture the value of what they learn.

**Application to AI-agent spec-driven development:** March's framework provides the theoretical basis for portfolio allocation of spec-driven work. Over-exploiting means running agents only against well-understood spec patterns---efficient but non-adaptive. Over-exploring means constantly writing novel specs that agents may or may not be able to handle---creative but non-productive. The optimal balance shifts over time as agent capabilities mature, requiring continuous recalibration.

### 11. Centers of Excellence: Governance for Transition

Centers of Excellence (CoEs) provide organizational structures for managing the transition from incubation to production. Research identifies three governance models: centralized (a single CoE controls all activities), federated (distributed CoEs within business units), and hybrid (centralized standards with distributed execution) (Batra 2024). Organizations typically begin with a centralized model that evolves toward hybrid as adoption grows.

Effective CoEs introduce "clear intake criteria, exceptions-based approvals, and well-defined roles to ensure that the right stakeholders are involved at the right time without slowing down innovation" (Batra 2024). A typical environment strategy separates development, user acceptance testing, and production, "ensuring changes don't impact critical business processes while allowing innovation to flourish" (Batra 2024). Organizations track the ratio of successful pilot-to-production transitions as a key CoE effectiveness metric.

**Application to AI-agent spec-driven development:** A Spec-Driven Development CoE would own the specification standards, agent tooling, review processes, and transition criteria. It would provide shared infrastructure (spec templates, agent configurations, validation frameworks) that reduces per-project overhead---analogous to X's Design Kitchen. The CoE would govern the transition from experimental specs (H3) through scaling specs (H2) to production specs (H1), with clear criteria at each transition point.

### 12. How Spec-Driven AI Development Changes R&D Economics

The research converges on a structural shift in R&D economics when AI agents execute from specifications:

1. **Lower cost of exploration.** March's exploration-exploitation tradeoff shifts because AI agents reduce the cost of exploration. Writing a spec and having an agent attempt it is orders of magnitude cheaper than having human developers build a prototype. This means organizations can afford to explore more broadly (Piskala 2026, 15).

2. **Faster feedback loops.** Ries's Build-Measure-Learn loop accelerates when "build" means "agent-execute a spec" rather than "human-code a prototype." The time from hypothesis to tested MVP shrinks from weeks or months to hours or days (Thoughtworks 2025).

3. **Specification as organizational knowledge.** Unlike code, which encodes *how* something is done, specifications encode *what* should be done and *why*. Specs are portable across agent generations---a spec written for today's LLM should work with tomorrow's, unlike code optimized for a particular framework. This makes specs a more durable knowledge asset than code (Piskala 2026, 8).

4. **Kill criteria become cheaper to evaluate.** X's rapid-evaluation model becomes even more rapid when the "hardest part first" test is an agent attempting the riskiest aspect of the spec. The cost of a failed experiment drops to the cost of writing and running a spec, not the cost of building and discarding a prototype.

5. **Stage-Gate gates can be automated.** Cooper's go/no-go decisions can be partially automated when the deliverable at each stage is a spec with measurable agent-execution results. Gate criteria become: does the agent produce output that meets the spec's postconditions? Does it do so within cost and time constraints?

---

## Bibliography

Adzic, Gojko. 2011. *Specification by Example: How Successful Teams Deliver the Right Software*. Shelter Island, NY: Manning Publications.

Baghai, Mehrdad, Stephen Coley, and David White. 1999. *The Alchemy of Growth: Practical Insights for Building the Enduring Enterprise*. Cambridge, MA: Perseus Publishing.

Batra, Mannoj. 2024. "Understanding Center of Excellence (CoE) Operating Models." LinkedIn, accessed February 14, 2026.

Bezivin, Jean. 2005. "On the Unification Power of Models." *Software and Systems Modeling* 4 (2): 171-88.

Bezivin, Jean. 2006. "Model Driven Engineering: An Emerging Technical Space." In *Generative and Transformational Techniques in Software Engineering*, edited by Ralf Lammel, Joost Visser, and Joao Saraiva, 171-206. Berlin: Springer.

Bonvillian, William B. 2018. "DARPA and Its ARPA-E and IARPA Clones: A Unique Innovation Organization Model." *Industrial and Corporate Change* 27 (5): 897-914.

Bonvillian, William B., Richard Van Atta, and Patrick Windham, eds. 2019. *The DARPA Model for Transformative Technologies: Perspectives on the U.S. Defense Advanced Research Projects Agency*. Cambridge: Open Book Publishers.

Brambilla, Marco, Jordi Cabot, and Manuel Wimmer. 2017. *Model-Driven Software Engineering in Practice*. 2nd ed. San Rafael, CA: Morgan and Claypool.

Christensen, Clayton M. 1997. *The Innovator's Dilemma: When New Technologies Cause Great Firms to Fail*. Boston: Harvard Business Review Press.

Cooper, Robert G. 2016. "Agile-Stage-Gate Hybrids: The Next Stage for Product Development." *Research-Technology Management* 59 (1): 21-29.

Cooper, Robert G. 2017. *Winning at New Products: Creating Value Through Innovation*. 5th ed. New York: Basic Books.

Cucumber Documentation. 2024. "Behaviour-Driven Development." Accessed February 14, 2026. https://cucumber.io/docs/bdd/.

DARPA. 2024. "About DARPA." Accessed February 14, 2026. https://www.darpa.mil/about.

Evans, Eric. 2003. *Domain-Driven Design: Tackling Complexity in the Heart of Software*. Boston: Addison-Wesley.

Gertner, Jon. 2012. *The Idea Factory: Bell Labs and the Great Age of American Innovation*. New York: Penguin.

Hiltzik, Michael A. 1999. *Dealers of Lightning: Xerox PARC and the Dawn of the Computer Age*. New York: HarperBusiness.

Jackson, Daniel. 2012. *Software Abstractions: Logic, Language, and Analysis*. Rev. ed. Cambridge, MA: MIT Press.

Kaur, Arvinder. 2012. "Analysis of Three Formal Methods: Z, B and VDM." *International Journal of Engineering Research and Technology* 1 (4): 227-32.

Kleppe, Anneke G., Jos Warmer, and Wim Bast. 2003. *MDA Explained: The Model Driven Architecture---Practice and Promise*. Boston: Addison-Wesley.

Knuth, Donald E. 1984. "Literate Programming." *The Computer Journal* 27 (2): 97-111.

Lamport, Leslie. 2002. *Specifying Systems: The TLA+ Language and Tools for Hardware and Software Engineers*. Boston: Addison-Wesley.

Loch, Christoph H., Arnoud DeMeyer, and Michael T. Pich. 2006. *Managing the Unknown: A New Approach to Managing High Uncertainty and Risk in Projects*. Hoboken, NJ: Wiley.

March, James G. 1991. "Exploration and Exploitation in Organizational Learning." *Organization Science* 2 (1): 71-87.

McKinsey and Company. 2009. "Enduring Ideas: The Three Horizons of Growth." *McKinsey Quarterly*, December. Accessed February 14, 2026.

Meyer, Bertrand. 1997. *Object-Oriented Software Construction*. 2nd ed. Upper Saddle River, NJ: Prentice Hall.

NASA. 1998. *Formal Methods Specification and Verification Guidebook for Software and Computer Systems*. NASA Technical Report NASA-GB-002-95. Washington, DC: NASA.

Newcombe, Chris, Tim Rath, Fan Zhang, Bogdan Munteanu, Marc Brooker, and Michael Deardeuff. 2015. "How Amazon Web Services Uses Formal Methods." *Communications of the ACM* 58 (4): 66-73.

North, Dan. 2006. "Introducing BDD." *Better Software*, March. Reprinted at https://dannorth.net/blog/introducing-bdd/.

O'Reilly, Charles A., and Michael L. Tushman. 2004. "The Ambidextrous Organization." *Harvard Business Review* 82 (4): 74-82.

Piskala, Deepak Babu. 2026. "Spec-Driven Development: From Code to Contract in the Age of AI Coding Assistants." arXiv preprint arXiv:2602.00180.

Ries, Eric. 2011. *The Lean Startup: How Today's Entrepreneurs Use Continuous Innovation to Create Radically Successful Businesses*. New York: Crown Business.

Stahl, Thomas, and Markus Volter. 2006. *Model-Driven Software Development: Technology, Engineering, Management*. Chichester: Wiley.

Stoplight. 2024. "API-First, API Design-First, or Code-First: Which Should You Choose?" Stoplight Blog. Accessed February 14, 2026.

Teller, Astro. 2023. "A Peek Inside the Moonshot Factory Operating Manual." X Blog. Accessed February 14, 2026. https://blog.x.company/.

Thoughtworks. 2025. "Spec-Driven Development: Unpacking One of 2025's Key New AI-Assisted Engineering Practices." Thoughtworks Insights Blog. Accessed February 14, 2026.
