# BMAD vs Pennyfarthing: Strategic Comparison

**Date:** 2026-02-13
**Audience:** 1898 & Co engineering team
**Purpose:** Evaluate whether to adopt BMAD, Pennyfarthing, or both

---

## Executive Summary

BMAD and Pennyfarthing solve different halves of the same problem. BMAD front-loads quality into requirements, architecture, and solutioning before code is written ("moving process left"). Pennyfarthing orchestrates the implementation cycle with coordinated agents, real-time feedback, and persistent learning ("moving process right").

The key finding: Pennyfarthing has already ported all nine of BMAD's Phase 1-3 planning workflows into its BikeLane workflow engine. The frameworks are not competing alternatives — Pennyfarthing is a superset that absorbed BMAD's planning model and added an implementation layer BMAD doesn't have.

---

## What Each Framework Does

### BMAD (Breakthrough Method of Agile AI-Driven Development)

**Version:** 6.0.0-Beta.8 | **License:** MIT | **Status:** Public open-source

BMAD organizes AI-driven development into four sequential phases:

1. **Analysis** — Brainstorming, market/domain/technical research, product briefs
2. **Planning** — PRD creation (12-step workflow), UX design specification
3. **Solutioning** — Architecture decisions, epic/story breakdown, implementation readiness checks
4. **Implementation** — Sprint planning, story execution, code review, retrospectives

Its core philosophy is "Human Amplification, Not Replacement" — structured workflows guide human-AI collaboration through decision points with menus and validation steps. Each workflow runs in a fresh conversation to prevent context pollution.

BMAD defines 9 agent personas (Business Analyst, PM, Architect, Scrum Master, Developer, QA, UX Designer, Technical Writer, Quick Flow Solo Dev) and supports 6+ IDEs (Claude, Cursor, Windsurf, Roo, Kiro, OpenCode).

### Pennyfarthing

**Version:** 12.1.0 | **License:** Internal | **Status:** In-house framework

Pennyfarthing is a multi-agent orchestration framework built around Claude Code. It manages the full sprint lifecycle: story assignment, test-driven development, automated agent handoffs, code review, and sprint completion.

It defines 11 coordinated agents (SM, PM, Architect, Dev, TEA, Reviewer, Tech Writer, UX Designer, DevOps, Orchestrator, BA) with 7 Haiku-based subagents for mechanical tasks. Agents hand off work automatically through workflow phases, with session files tracking state across context boundaries.

Pennyfarthing includes Cyclist, a visual terminal (Electron/React 19) with 16 draggable panels for real-time sprint monitoring, diff viewing, health scoring, and workflow navigation.

---

## The "Left vs Right" Framework

### Moving Process Left (BMAD's Strength)

BMAD catches expensive mistakes before implementation begins:

- **Requirements validation:** PRD goes through structured steps covering density, measurability, traceability, domain compliance, and implementation leakage detection
- **Architecture documentation:** Explicit technology decisions (REST vs GraphQL, monolith vs microservices) documented before agents diverge
- **Implementation readiness:** Adversarial review using pre-mortem analysis, red team/blue team, first principles thinking
- **Consistency enforcement:** Architecture documents prevent Agent A using REST while Agent B uses GraphQL

The cost argument: catching alignment issues in solutioning is significantly faster than discovering them during implementation.

### Moving Process Right (Pennyfarthing's Strength)

Pennyfarthing catches quality issues during and after implementation:

- **Workflow orchestration:** Automated agent-to-agent handoffs (SM -> TEA -> Dev -> Reviewer -> SM) with relay mode for unattended execution
- **Real-time feedback:** Cyclist panels show diffs, acceptance criteria status, codebase health scores, and sprint progress while agents work
- **Tandem pair programming:** Background Haiku agent observes primary agent's work via git diff, auto-injects observations through PostToolUse hooks
- **Persistent learning:** Agent sidecars (patterns, gotchas, decisions) survive across sessions and inform future work
- **Telemetry:** OTEL span interception and enrichment provides structured observability into agent behavior
- **Health monitoring:** Continuous codebase health scoring (dead code, complexity, dependencies) with hotspot visualization

### The Integration Point

Pennyfarthing already ported BMAD's Phase 1-3 workflows into its BikeLane workflow engine. The planning phase produces structured artifacts (stories with BDD acceptance criteria). The execution phase consumes those artifacts through TDD/BDD agent workflows. No conversion required — the formats are natively compatible.

```
BMAD Planning (now inside BikeLane)         Pennyfarthing Execution
+-----------------------------------+       +--------------------------------+
| /workflow start product-brief     |       | /sprint work                   |
| /workflow start prd --mode create |       |                                |
| /workflow start architecture      |       | SM -> TEA (RED) -> Dev (GREEN) |
| /workflow start ux-design         | ----> |    -> Reviewer -> SM           |
| /workflow start epics-and-stories |       |                                |
| /workflow start implementation-   |       | Cyclist monitors in real-time  |
|   readiness                       |       | Sidecars capture learnings     |
+-----------------------------------+       +--------------------------------+
     Stepped workflows                          Phased workflows
     Progressive disclosure                     Automated handoffs
     User approval gates                        Relay mode execution
```

---

## Feature Comparison

### Planning & Design (Phases 1-3)

| Capability | BMAD | Pennyfarthing | Status |
|-----------|------|---------------|--------|
| Product brief | Stepped workflow | Ported into BikeLane | Parity |
| PRD creation | 12-step, tri-modal (create/validate/edit) | Ported with tri-modal support | Parity |
| Architecture | Dedicated Phase 3, A/P/C collaboration menus | Ported with A/P/C menus + web search + party mode viewpoints | Parity+ |
| UX design | 14-step workflow | Ported 14 steps | Parity |
| Research | Market, domain, technical tracks | Ported with routing-based mode selection | Parity |
| Epics & stories | Story breakdown from PRD + architecture | Ported with auto-import to sprint backlog | Parity+ |
| Implementation readiness | Adversarial review gate | Ported as stepped workflow | Parity |
| Sprint planning | Sprint status tracking | Ported + full sprint YAML management | Parity+ |

All nine major BMAD planning workflows have been natively reimplemented in BikeLane's stepped workflow format (validated YAML schema, XML-tagged step files, variable resolution chain).

### Implementation & Execution (Phase 4)

| Capability | BMAD | Pennyfarthing |
|-----------|------|---------------|
| Agent orchestration | Single Dev agent (Amelia), sequential stories | 11 agents, 7 subagents, automated handoffs, relay mode |
| TDD/BDD | Dev agent follows TDD instructions | First-class RED/GREEN/REFACTOR phases, BDD workflow (SM -> UX -> TEA -> Dev -> Reviewer) |
| Code review | "Must find issues" philosophy in workflow | Dedicated Reviewer agent (adversarial by design), reviewer-preflight subagent, CI quality gates |
| Parallel work | Sequential story execution | Git worktree mode with port management, multiple concurrent stories |
| Tandem mode | Not available | Background Haiku observer, auto-injected observations during implementation |
| Sprint management | `sprint-status.yaml` | Full YAML shard system, Jira bidirectional sync, story lifecycle, merge gates |
| Context management | Fresh Chat Protocol (intentionally stateless) | Prime with 4 tiers (FULL/REFRESH/HANDOFF/MINIMAL), TirePump context clearing |
| Persistent memory | None (by design) | Agent sidecars: patterns, gotchas, decisions — written before every handoff, loaded on activation |

### Visual Terminal & Tooling

| Capability | BMAD | Pennyfarthing |
|-----------|------|---------------|
| Visual terminal | None | Cyclist: 16 draggable panels (Electron, React 19, Tailwind v4, shadcn/ui, Dockview) |
| Real-time monitoring | None | Sprint panel, diff viewer, health score gauge, acceptance criteria tracking, workflow navigation |
| Standalone dashboards | None | BikeRack: decoupled panel viewer with `--project-dir` flag, `?panel=X` routing, runs against any project |
| Message queuing | None | Bell mode: queue messages while agent works, inject at next tool execution |
| Agent visualization | None | Agent portraits (97 per theme), persona headers with thinking throbber, tandem portrait indicators |
| Workflow control | Slash commands | Permission mode (plan/manual/accept), relay mode (auto-execute handoffs), bell mode |

### Validation & Quality Assurance

| Approach | BMAD | Pennyfarthing |
|----------|------|---------------|
| **Mechanism** | AI reads markdown checklists and self-validates | Programmatic scripts enforce constraints |
| PRD validation | 12 markdown validation steps (density, measurability, traceability, etc.) — AI-interpreted | Stepped workflow with scripted schema validation |
| Sprint validation | Informal tracking | Sprint YAML schema validator enforces structure at write time |
| Workflow validation | None — markdown files are freeform | Workflow YAML schema validation, step file XML tag validation |
| Cross-references | None | Cross-file reference validator checks 4 reference types across codebase |
| Installation health | None | `pennyfarthing doctor` runs programmatic health checks, `--fix` auto-remediates |
| Hook enforcement | None | Python hooks enforce behavior: reflector marker presence, pre-edit file protection, session lifecycle |

The validation philosophy is fundamentally different. BMAD's "12-step PRD validation" means the AI reads a markdown list of what to check and reports findings — it's non-deterministic, and running it twice may produce different results. Pennyfarthing's validation is scripted: Python and TypeScript validators programmatically enforce schemas, check file references, and block invalid states. One approach hopes the AI catches problems. The other prevents them structurally.

### Persona & Benchmarking

| Capability | BMAD | Pennyfarthing |
|-----------|------|---------------|
| Agent personas | 9 named agents with personality traits and communication styles | 11 agents x 98 themes = 1,078 unique character configurations |
| Personality modeling | Descriptive traits per agent | OCEAN Big Five scores for every character, mapped to performance |
| Performance research | None | JobFair: controlled benchmarks running same scenario across characters, measuring detection rate, depth, quality, organization, persona engagement |
| Error taxonomy | None | TRAIL framework: categorizes errors (reasoning, planning, execution) and correlates with personality dimensions |
| Statistical rigor | None | Cohen's d effect sizes, multivariate OCEAN regression, mean/std_dev/top-performer analysis |
| Key finding | — | Deep personality modeling provides measurable lift. "Stoic Analyst" profile (Low O, High C, Low E, Low N) empirically excels at code review. Character expertise often trumps abstract trait scores. |
| Theme customization | Fixed agent names | 98 themes across 8 packages (comedy, literary, mythology, prestige TV, realistic, sci-fi, superheroes, core) with theme creation wizard |

This is not cosmetic theming. Pennyfarthing runs scientific studies measuring whether personality depth improves agent output quality, and uses the results to optimize character-role assignments.

### Observability & Telemetry

| Capability | BMAD | Pennyfarthing |
|-----------|------|---------------|
| Telemetry | None | OTEL span interception, enrichment, and correlation |
| Agent load monitoring | None | Agent-load API endpoint, sidecar pruning, useAgentLoad hook |
| Background task tracking | None | Utilities for managing background tasks (add, update, cleanup, list, check, summary) |
| Audit trail | None | AuditLogPanel with timestamped action history |
| Token monitoring | None | Prime context token metrics in DebugPanel, context percentage in TirePump |

### Workflow Customization

| Aspect | BMAD | Pennyfarthing |
|--------|------|---------------|
| Creating workflows | Write markdown files, informal structure | Write against validated YAML schema with `type: stepped | phased | procedural` |
| Step definitions | Markdown with YAML frontmatter | Markdown with XML tags (`<purpose>`, `<instructions>`, `<output>`, `<step-meta>`, `<gate>`, `<collaboration-menu>`) |
| Validation | None — any markdown file works | Schema validation on workflow YAML and step file structure |
| Variable system | `{config_source}:variable` with CSV lookups | Priority chain: workflow YAML -> session file -> config -> environment -> defaults |
| Gate system | Embedded in step content | First-class `gates:` section in workflow YAML (`after_steps`, `gate_marker`) |
| Mode system | Tri-modal (create/validate/edit) | Tri-modal + custom routing modes (research: market/domain/technical) |
| Collaboration menus | Per-workflow custom | Standardized A/P/C across all stepped workflows |
| Workflow count | 17 | 32 (11 phased + 21 stepped) |

---

## The 1898 & Co Factor

### Already Integrated

Pennyfarthing is already configured for the 1898 workflow:

- **Jira integration:** Bidirectional sync with PROJ project keys, story creation, epic management
- **Team assignment:** `assigned_to` fields with `@slabgorb.io` email addresses, sprint panel filters by assignee
- **Sprint management:** Story lifecycle matching actual team cadence
- **Workflow selection:** TDD for features, trivial for small changes, patch for hotfixes — matching how the team actually works

BMAD would require customization to reach this level of integration. Pennyfarthing is already there.

### Iteration Velocity

Both projects are actively developed:

| Metric | BMAD | Pennyfarthing |
|--------|------|---------------|
| Current version | 6.0.0-Beta.8 | 12.1.0 |
| Changelog lines | 1,673 | 2,489 |
| Latest release | February 8, 2026 | February 12, 2026 |

Pennyfarthing iterates faster because there is no community consensus process. When 1898 needs a feature, it ships that sprint. BMAD moves on its own timeline.

### The Credibility Question

BMAD has the advantage of a large online following, MIT license, documentation website, and community contributions. Pennyfarthing is homegrown.

The counter-arguments:

1. **Pennyfarthing already contains BMAD's planning model.** The nine major Phase 1-3 workflows were ported into BikeLane. Choosing Pennyfarthing doesn't mean losing BMAD's strengths.
2. **Validation is stronger, not weaker.** BMAD validates with markdown checklists (AI-interpreted). Pennyfarthing validates with scripts (deterministic).
3. **The research is original.** No other framework runs controlled personality benchmarks with statistical analysis (Cohen's d, OCEAN correlation, TRAIL mapping). This work has no public equivalent.
4. **The visual terminal is unique.** No agent framework — public or private — offers a 16-panel real-time dashboard with standalone viewer mode.
5. **Velocity is the product.** An internal framework that ships weekly beats an external framework that ships monthly.

---

## Recommendation

The question is not "BMAD or Pennyfarthing." It is "why use the subset when you already have the superset?"

Pennyfarthing absorbed BMAD's planning workflows. It added scripted validation where BMAD uses markdown checklists. It added a visual terminal, telemetry, persistent agent memory, tandem pair programming, scientific persona benchmarking, and a full sprint management system that already integrates with 1898's Jira and team structure.

BMAD's remaining unique value is community credibility and multi-IDE support. For a team that uses Claude Code and needs deep workflow integration, neither of those advantages applies.

**Use Pennyfarthing.** The planning workflows from BMAD are already inside it. The implementation layer, visual tooling, validation rigor, and persona research are not available anywhere else.
