# The Pennyfarthing Project: A Field History

*Based on 11,404 commits across two repositories, 120 tagged releases, 27 Architecture Decision Records, and one very persistent developer.*

---

## Part I: Genesis — "In the Beginning, There Was BMAD"

**December 21, 2025.** The very first commit reads: `feat: initial pennyfarthing framework`. But that's a lie — or at least a retroactive truth. The project was born as **BMAD**, renamed to Pennyfarthing within hours of its creation. (It would be renamed *again* later — from "Conductor" to "Pennyfarthing" on January 19th.)

What was it? A multi-agent orchestration framework for Claude Code. Eleven agents — SM, TEA, Dev, Reviewer, Architect, PM, Tech Writer, UX Designer, DevOps, Orchestrator, and thirteen Haiku-based subagents. Three themes (Discworld, Star Trek TNG, Literary Classics). A TDD workflow. All bash scripts and markdown files.

The velocity was immediate and staggering. **Six version bumps in the first two days** (v1.3 through v2.0). By December 23rd — day three — there were already release scripts, structured logging, session file locking, and new themes (Star Trek TOS, Jane Austen, Shakespeare). Sprint 1's retrospective was written the same day the sprint started.

**The seed that mattered:** Sidecar memory files. Day two. A small feature — agents writing learnings to local files that persist across sessions. This would become one of the framework's defining patterns: agents that *remember*.

---

## Part II: The Theme Explosion — From 3 to 100

**December 22-24, 2025.** What started as three flavor options detonated into an obsession. Star Trek TOS. Breaking Bad. Firefly. Game of Thrones. Marvel MCU. The Wire. By January 5th there were **91 themes with 910 characters**, each with OCEAN personality profiles (Openness, Conscientiousness, Extraversion, Agreeableness, Neuroticism).

This wasn't decorative. It was *scientific*. Version 5.0 (January 2nd) introduced the **TRAIL-OCEAN hypothesis** — the idea that personality traits correlate with agent task performance. A benchmarking framework called **JobFair** emerged to test it. Standardized scenarios. Ground-truth judges. Cohen's d effect size tracking. A static Astro showcase website was built with **768 generated pages** of personality data.

**The pivot nobody expected:** AI-generated portraits. What started as text-only agent names became Rider-Waite tarot-style character art generated via Flux, with portrait-resolver services, size subdirectories, npm tarball exclusions, and eventually a **Git LFS migration** because the images were too large for regular git. One hundred themes. One thousand characters. Each with a face.

**Small feature, big fruit:** The `/job-fair` command. Started as a simple benchmark runner script. Grew into a systematic evaluation pipeline that could cross-test agents across roles (`--as` flag), calculate aggregate statistics, and identify which personas actually perform best at code review versus test writing. The data drove optimization of 53 themes.

---

## Part III: The Installation Wars

If Pennyfarthing has a recurring villain, it's installation. The project has pivoted its distribution model **five times** and dedicated **four separate epics** to fixing install issues.

| Era | Model | Problem |
|-----|-------|---------|
| v1-v3 | File copying | Pollutes user's codebase |
| v4 | Symlinks to `node_modules/` | Requires npm install first; breaks if node_modules moves |
| v7 | Scoped npm packages (`@pennyfarthing/core`) | 12 packages; confusing multi-install |
| v10 | `.pennyfarthing/` consolidation | Files scattered across `.claude/` and `.pennyfarthing/` |
| v11+ | Single package + progressive setup (ADR-0027) | Still in progress |

Epic 85 (Clean Install). Epic 98 (Safe Install/Upgrade). Epic 117 (Consumer Install Fixes — 12 stories fixing real-world failures discovered from a diagnostic). Epic 123 (Release Tooling Hardening).

The February 17th ADR-0027 represents the current thinking: **three-phase progressive installation**. Fast Node-only init (8 operations, no Python). First-session auto-setup via hook. Runtime component activation via frontmatter declarations. The goal: installation time under 2 minutes with zero path-related errors.

**The lesson the project kept learning:** Every installation model works for the developer. None of them work for the user — until you've watched them fail.

---

## Part IV: The UI Odyssey — CLI to Electron to VS Code to Electron to TUI

The user interface story of Pennyfarthing is a journey through the entire spectrum of developer tooling, including one complete dead end.

**Phase 1: CLI Only (v1-v5).** Pure terminal. Markdown files, bash scripts, slash commands. It worked.

**Phase 2: Cyclist Electron App (v6+).** January 8th. React 19, Tailwind v4, shadcn/ui, Dockview panels. The WheelHub server. Tool Activity Bar. Abort Button. Mermaid diagrams. Telemetry dashboards. The visual terminal became a first-class product with **13 monitoring panels** — messages, progress, diffs, sprint, git, workflow, debug, settings, audit log, portraits, and more.

**Phase 3: The VS Code Detour (v7.3).** January 21st, Epic 50 introduced a VS Code extension. By February 2nd — twelve days later — **ADR-0019 deprecated it**. The extension was *completely removed* in v9.0. The reasoning: Claude Code's own VS Code integration made a separate extension redundant and confusing.

**Phase 4: React Migration (v9.0).** February 2nd. The Cyclist UI underwent a massive rewrite. Vanilla JS to React 19 hooks. MessageView, DockingWorkspace (later replaced by Dockview), drag-and-drop layouts. Tufte-inspired message redesign — stripped chat bubbles, left-border tool calls. WCAG AA compliance. **116 stories across 17 epics.** The UI went from functional to genuinely beautiful.

**Phase 5: BikeRack TUI (v11.0).** February 14th — the biggest single day in the project's history with **507 commits**. A complete Python Textual-based terminal UI emerged as a parallel interface. WebSocket client, sprint panel, git panel, audit log, context meter, auto-reload, focus management. The project now supports **three interface paradigms**: CLI, Electron GUI, and terminal TUI.

**Small feature, big fruit:** The Reflector protocol. A simple idea — `<!-- CYCLIST:TYPE:value -->` HTML comment markers embedded in agent output. These invisible markers drive QuickActions buttons in the Cyclist UI. Handoff buttons, yes/no prompts, choice menus — all rendered from structured comments that are invisible in CLI mode. One pattern bridging two interfaces.

---

## Part V: The Workflow Engine — From Linear to Orchestral

The workflow system evolved through four distinct generations:

**Gen 1: Hardcoded TDD (v1-v5).** SM → TEA → Dev → Reviewer → SM. One workflow. Take it or leave it.

**Gen 2: YAML Workflow Definitions (v6.4, Epic 31).** January 13th. A state machine driven by YAML files. Story-to-workflow routing. The trivial workflow appeared (SM → Dev → Reviewer → SM, skipping TEA for quick fixes). BDD workflows for UX-driven stories.

**Gen 3: Stepped Workflows (v7.3).** January 21st. Inspired by BMAD, stepped workflows guide users through multi-phase processes with gates at each transition. Architecture reviews, PRD creation, sprint planning — structured but human-paced.

**Gen 4: Tandem + Teams (v10.2-v11.2).** February 2026. Two breakthrough patterns:

- **Tandem Protocol:** A background observer agent watches your work and injects observations via PostToolUse hooks. Your Architect partner notices a coupling issue and whispers it into your context. You never asked — but you needed to hear it.

- **Native Teams:** Phase-scoped agent teams using Claude Code's Agent Teams. The phase owner becomes team lead, spawns teammates, coordinates via SendMessage. Teams are created at phase start and destroyed before handoff.

**The gate system** (ADR-0025, February 12th) replaced the fragile handoff subagent pattern. Declarative gate files with pass/fail criteria. Bash scripts handle state transitions atomically. Agents make decisions; scripts make guarantees. The architecture went from agent-centric to **script-first coordination** — one of the most significant pivots in the project.

---

## Part VI: The Consolidation Arc

A pattern emerges in the ADR progression: **distribute, then consolidate**.

- Twelve npm packages → one (`@pennyfarthing/core`, ADR-0026)
- `packages/shared/` → absorbed into `packages/core/src/shared/` (Story 98-16)
- Benchmark package → extracted then re-absorbed into core
- WheelHub server → moved from cyclist to core (Story 98-17)
- React UI build → moved from cyclist to core (Story 98-18)
- `.claude/` scattered files → consolidated under `.pennyfarthing/` (v10.0)
- Gitflow (develop + main) → **trunk-based development** (ADR-0026, February 15th)

The February 13th consolidation was the inflection point. The project shed complexity it had accumulated during rapid exploration. Cyclist became a thin Electron wrapper. Core became the gravity well that everything orbits.

**Small feature, big fruit:** The `pf.sh` wrapper script. A single entry point that self-locates via `BASH_SOURCE`, detects monorepos, handles nested repos, and routes to the Python CLI. Started as a convenience; became the **canonical way to invoke anything** in the framework. Every hook, every agent activation, every sprint operation goes through it.

---

## Part VII: The Chernoff Face Incident and Other Dead Ends

Not everything stuck. An honest history includes the experiments that didn't survive:

- **Chernoff Faces (January 19th).** Built and killed on the same day. Statistical personality visualizations rendered as faces with features mapped to OCEAN traits. Technically clever. Practically useless.

- **VS Code Extension (January 21st - February 2nd).** Twelve days of development, then deprecated. The right idea at the wrong time — Claude Code's native VS Code support made it redundant.

- **TTY Panel / node-pty.** A terminal panel inside Cyclist using node-pty for native terminal access. Removed because it introduced a native module dependency that prevented clean npm installs. The TUI (BikeRack) solved the same need without the dependency.

- **DockingWorkspace.** Custom docking implementation replaced by Dockview, a mature third-party library. Sometimes the best code is code you delete.

- **`packages/shared/`.** Created as a shared utilities package. Absorbed back into core within weeks. The abstraction was premature.

---

## Part VIII: By the Numbers

| Metric | Value |
|--------|-------|
| **Age** | 63 days (Dec 21, 2025 — Feb 21, 2026) |
| **Framework commits** | ~10,641 (effective ~3,500 unique) |
| **Orchestrator commits** | 763 |
| **Tagged releases** | 120 (v1.3.0 through v11.4.0) |
| **Pull requests merged** | 1,054+ |
| **Architecture Decision Records** | 27 |
| **Breaking version bumps** | 7 (v2.2, v3.0, v4.0, v7.0, v8.0, v9.0, v10.0) |
| **Epics completed** | 60+ |
| **Stories delivered** | 500+ |
| **Story points** | 1,000+ |
| **Agents** | 11 core + 13 subagents |
| **Themes** | 100 |
| **Characters** | 1,000+ |
| **Workflow types** | 7 (tdd, tdd-tandem, trivial, bdd, bdd-tandem, agent-docs, stepped) |
| **Average commits/day** | ~169 (framework), ~30 (orchestrator) |
| **Peak day** | Feb 14, 2026 — 507 commits |
| **Contributors** | Keith Avery (93%), Michael Pursifull (7%), + 3 others |

---

## Part IX: Where It's Going

### Immediate (Sprint 2608, in progress)

- BikeRack TUI enhancements (progress enrichment, reconnection fixes, settings toggles)
- Release tooling hardening (package assertions, changelog automation, consumer smoke tests)
- Installation architecture rethink (ADR-0027 implementation)

### Near-term (Future initiatives)

- **BikeRack Extraction** — Full standalone dashboard, potentially as BikeShow.app (Electron wrapper)
- **Complete Python CLI Migration** — Remaining bash scripts ported to the `pf` Click CLI
- **Agent Quality Awareness** — Tandem mode fixes, capability detection, smarter agent routing
- **Multi-session WheelHub** — Port routing for multiple Claude instances sharing one dashboard

### Strategic direction

- **Progressive disclosure** — Fast minimal install, complexity revealed on demand
- **Script-first coordination** — Scripts guarantee state; agents make decisions
- **Interface pluralism** — CLI, web dashboard, Electron app, and terminal TUI coexisting
- **Plugin architecture** — Project-specific command extensions beyond the core framework

The trajectory is clear: from a collection of agent definitions and bash scripts to a **mature development infrastructure platform** — one that coordinates AI agents the way a conductor coordinates an orchestra.

---

## Appendix: Version Timeline

| Version | Date | Milestone |
|---------|------|-----------|
| v1.0.0 | 2025-12-21 | Initial framework — 11 agents, 3 themes, TDD workflow |
| v2.0.0 | 2025-12-23 | Release scripts, structured logging, session locking |
| v3.0.0 | 2025-12-24 | Official subagents (YAML format), session file overhaul |
| v4.0.0 | 2025-12-31 | Symlink-based installation, hook system |
| v5.0.0 | 2026-01-02 | Scientific benchmarking, TRAIL-OCEAN, showcase website |
| v6.0.0 | 2026-01-08 | Cyclist Electron app, pnpm monorepo, 40+ features |
| v7.0.0 | 2026-01-17 | npm publishing, `@pennyfarthing/core`, directory restructure |
| v8.0.0 | 2026-01-29 | Script path resolution overhaul, Python CLI migration |
| v9.0.0 | 2026-02-02 | React migration, VS Code removed, Reflector protocol |
| v10.0.0 | 2026-02-06 | Permission system, `.pennyfarthing/` consolidation |
| v11.0.0 | 2026-02-14 | BikeRack TUI, core consolidation, gate system |
| v11.4.0 | 2026-02-20 | Git panel consolidation, release tooling, current |

---

## Appendix: Architecture Decision Records

| ADR | Date | Title | Status |
|-----|------|-------|--------|
| 0001 | 2025-12-31 | Consolidate Code Duplication | Accepted |
| 0002 | 2026-01-03 | Context Budget Optimization | Superseded |
| 0003 | 2026-01-09 | Cyclist Claude Code Alignment | Superseded |
| 0004 | 2026-01-18 | WheelHub Background Agent Coordination | Accepted |
| 0005 | 2026-01-19 | Single Source of Truth via Symlinks | Accepted |
| 0006 | 2026-01-19 | State Detection Over Explicit Commands | Accepted |
| 0007 | 2026-01-19 | Subagent Delegation Model (Opus/Haiku) | Accepted |
| 0008 | 2026-01-19 | Result Object Error Handling | Accepted |
| 0009 | 2026-01-19 | Session File Coordination Protocol | Accepted |
| 0010 | 2026-01-19 | ESM Module Requirements | Accepted |
| 0011 | 2026-01-23 | Reflector Marker Consolidation | Accepted |
| 0012 | 2026-01-23 | Tandem Agent Pairing | Proposed |
| 0013 | 2026-01-19 | Stepped Workflow Support (BMAD-Inspired) | Accepted |
| 0014 | 2026-01-19 | CDN-Based Portrait Storage | Proposed |
| 0015 | 2026-01-28 | Prime Activation System | Accepted |
| 0016 | 2026-01-28 | Bell Mode (Message Queue Injection) | Accepted |
| 0017 | 2026-01-28 | Relay Mode (Automatic Agent Handoff) | Accepted |
| 0018 | 2026-01-28 | Sprint YAML Script Access Pattern | Accepted |
| 0019 | 2026-02-02 | VS Code Extension Deprecation | Accepted |
| 0020 | 2026-02-07 | Benchmark Package Extraction | Proposed |
| 0021 | 2026-02-09 | Safe Install, Upgrade, and Namespace Isolation | Proposed |
| 0022 | 2026-02-10 | Sprint Shard Validation and Reference Integrity | Accepted |
| 0023 | 2026-02-10 | Cyclist Detection via Environment Variable | Accepted |
| 0024 | 2026-02-11 | BikeRack Mode — Decoupled WheelHub Dashboard | Accepted |
| 0025 | 2026-02-12 | Script-First Gate Extraction | Accepted |
| 0026 | 2026-02-13 | Single Package Consolidation | Accepted |
| 0027 | 2026-02-17 | Installation Architecture Rethink | Proposed |
