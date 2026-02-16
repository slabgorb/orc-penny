# pennyfarthing-orchestrator

Sprint management, agent coordination, and framework development orchestration for the [Pennyfarthing](https://github.com/1898andCo/pennyfarthing) project.

## What This Repo Does

This is the **orchestrator** — it tracks sprint work, manages agent sessions, hosts documentation and ADRs, and coordinates development on the Pennyfarthing framework. The framework source lives in an inlined `pennyfarthing/` repo with its own git history.

| Concern | Where |
|---------|-------|
| Sprint tracking | `sprint/` — YAML shards, epic files, initiative backlogs |
| Agent sessions | `.session/` — active work context per story |
| Documentation | `docs/` — lifecycle research, gap analyses, measurement data |
| Architecture decisions | `docs/adr/` — 26 ADRs covering framework design |
| Framework source | `pennyfarthing/` — inlined repo, separate git history |
| Task runner | `justfile` — delegates build/test/cyclist commands to framework |

## Getting Started

### Prerequisites

- Node.js 20+
- [pnpm](https://pnpm.io/) (for framework packages)
- [just](https://github.com/casey/just) (task runner)
- Git SSH access to `1898andCo` org repos

### Setup

```bash
git clone git@github.com:1898andCo/pennyfarthing-orchestrator.git
cd pennyfarthing-orchestrator
just setup
just doctor    # verify everything is wired up
```

`just setup` clones the pennyfarthing framework repo, installs dependencies, builds packages, and links the orchestrator.

### Common Commands

```bash
just build        # Build all framework packages
just test         # Run framework tests
just dev          # Watch mode — auto-rebuild on changes
just cyclist      # Launch Cyclist visual terminal
just bikerack     # Launch BikeRack standalone dashboard
just validate     # Run all validators (agents, subagents, sprint YAML)
just doctor       # Check workspace health
just sidecar-health  # Check agent sidecar files for bloat
```

## Repository Structure

```
pennyfarthing-orchestrator/
├── .pennyfarthing/        # Runtime framework (symlinks → pennyfarthing/pennyfarthing-dist/)
│   ├── agents/            #   Agent definitions (SM, Dev, TEA, Reviewer, etc.)
│   ├── guides/            #   Component behavior guides
│   ├── scripts/           #   Python scripts (sprint, hooks, handoff)
│   ├── sidecars/          #   Agent learning files (local, writable, NOT symlinked)
│   ├── skills/            #   Skill definitions for /slash commands
│   └── workflows/         #   BikeLane workflow YAML files
├── docs/                  # Documentation
│   ├── adr/               #   Architecture Decision Records
│   ├── lifecycle-*.md     #   Lifecycle composition research
│   └── context-window-*.md #  Context measurement methodology and data
├── pennyfarthing/         # Inlined framework source (separate git repo)
├── sprint/                # Sprint tracking
│   ├── current-sprint.yaml #  Active sprint index
│   ├── epic-*.yaml        #  Per-epic story shards
│   ├── initiative-*.yaml  #  Backlog initiatives
│   ├── context/           #  Per-story and per-epic deep context
│   ├── planning/          #  PRDs, architecture docs, spike planning
│   └── archive/           #  Completed sprints, sessions, retired epics
├── references.bib         # Centralized BibTeX citations (Pandoc)
└── justfile               # Task runner (delegates to pennyfarthing/)
```

## Two Git Repos

This workspace contains two repositories with independent git histories:

| Repo | Branch strategy | Default branch | Purpose |
|------|----------------|----------------|---------|
| `pennyfarthing-orchestrator/` (this repo) | Trunk-based | `main` | Sprint files, sessions, docs, orchestration |
| `pennyfarthing/` (inlined) | Gitflow | `develop` | Framework source, packages, tests |

Orchestrator commits stay here. Framework commits go to `pennyfarthing/`:

```bash
# Orchestrator work
git add sprint/ && git commit -m "chore(sprint): update status"

# Framework work
cd pennyfarthing && git add . && git commit -m "feat: add new feature"
```

## Agent Workflows

The orchestrator coordinates AI agent workflows via BikeLane:

| Workflow | Agent sequence |
|----------|---------------|
| `tdd` | SM → TEA → Dev → Reviewer → SM |
| `tdd-tandem` | SM → TEA+Architect → Dev+TEA → Reviewer+PM → SM |
| `trivial` | SM → Dev → Reviewer → SM |
| `bdd` | SM → UX → TEA → Dev → Reviewer → SM |
| `agent-docs` | SM → Orchestrator → Tech Writer → SM |

Agents are invoked via slash commands (`/sm`, `/dev`, `/tea`, `/reviewer`, `/architect`, `/pm`, `/tech-writer`, `/ux-designer`, `/devops`). Each agent has a persona from the active theme and structured handoff protocols.

## Sprint Management

Sprints are tracked in sharded YAML — an index file (`current-sprint.yaml`) references per-epic shard files. This keeps context loading efficient for AI agents.

```bash
pf sprint status       # Current sprint overview
pf sprint backlog      # Available stories
pf sprint story finish # Archive completed story
```

Never edit sprint YAML directly — use `pf sprint` CLI commands.

## Documentation

Key documents in `docs/`:

| Document | Purpose |
|----------|---------|
| [Lifecycle Improvement Brief](docs/lifecycle-improvement-rs.md) | Product brief for Composable Lifecycle Engine |
| [BMAD vs Pennyfarthing](docs/bmad-vs-pennyfarthing.md) | Feature comparison between frameworks |
| [Gap Analysis](docs/bmad-pennyfarthing-gap-analysis.md) | Agent, workflow, and infrastructure gaps |
| [Context Window Measurements](docs/context-window-measurement-results.md) | Empirical data from 5 projects |
| [Research Synthesis](docs/lifecycle-research-synthesis.md) | Unified synthesis across 5 research tracks |

Citations use Pandoc BibTeX syntax (`[@citekey]`) with `references.bib`. Render with:

```bash
pandoc doc.md --citeproc --bibliography=references.bib -o output.html
```

## Architecture Decisions

26 ADRs document framework design choices. See [docs/adr/README.md](docs/adr/README.md) for the full index. Key decisions:

- **ADR-0005:** Single source of truth via symlinks (`.pennyfarthing/` → `pennyfarthing-dist/`)
- **ADR-0009:** Session file coordination protocol
- **ADR-0015:** Prime activation system (tiered context loading)
- **ADR-0022:** Sprint shard validation and reference integrity
- **ADR-0025:** Script-first gate extraction
- **ADR-0026:** Trunk-based development for orchestrator

## Related Repositories

| Repository | Purpose |
|-----------|---------|
| [pennyfarthing](https://github.com/1898andCo/pennyfarthing) | Framework source (TypeScript, Electron, React) |
| [spike-ocsf-rs1](https://github.com/1898andCo/spike-ocsf-rs1) | OCSF normalization research spike |
| [poller-orchestrator](https://github.com/1898andCo/poller-orchestrator) | Sibling orchestrator for poller platform |
