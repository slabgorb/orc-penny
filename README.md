# orc-penny

Sprint management, agent coordination, and framework development orchestration for the [Pennyfarthing](https://github.com/1898andCo/pennyfarthing) project.

This is the **orchestrator** — it tracks sprint work, manages agent sessions, hosts documentation and ADRs, and coordinates development on the Pennyfarthing framework. The framework source lives in an inlined `pennyfarthing/` repo with its own git history.

## Quick Start

<img align="right" src="https://github.com/user-attachments/assets/05fd41f3-c311-4eda-9cbe-f42cadd942c7" width="200">

### Prerequisites

- Node.js 18+
- [pnpm](https://pnpm.io/) 9+
- Python 3.11+
- [just](https://github.com/casey/just) (task runner)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Git SSH access to `1898andCo` org repos

### Setup

```bash
git clone git@github.com:1898andCo/orc-penny.git
cd orc-penny
npm install
just wheelhub start
just claude
```

Then inside Claude Code, run `/pf-health-check` to verify everything is wired up.

## Repository Structure

```
orc-penny/
├── .pennyfarthing/        # Runtime framework (symlinks → pennyfarthing/pennyfarthing-dist/)
│   ├── agents/            #   Agent definitions (SM, Dev, TEA, Reviewer, etc.)
│   ├── guides/            #   Component behavior guides
│   ├── gates/             #   Quality gate definitions
│   ├── scripts/           #   Python scripts (sprint, hooks, handoff)
│   ├── sidecars/          #   Agent learning files (local, writable, NOT symlinked)
│   ├── skills/            #   Skill definitions for /slash commands
│   ├── workflows/         #   BikeLane workflow YAML files
│   ├── personas/          #   Theme persona files
│   ├── output-styles/     #   Configurable response modes
│   └── templates/         #   File templates
├── docs/                  # Documentation
│   ├── adr/               #   Architecture Decision Records (27)
│   └── *.md               #   Research, gap analyses, measurement data
├── pennyfarthing/         # Inlined framework source (separate git repo)
├── sprint/                # Sprint tracking
│   ├── current-sprint.yaml #  Active sprint index
│   ├── epic-*.yaml        #  Per-epic story shards
│   ├── initiative-*.yaml  #  Backlog initiatives
│   ├── context/           #  Per-story and per-epic deep context
│   ├── planning/          #  PRDs, architecture docs, spike planning
│   └── archive/           #  Completed sprints, sessions, retired epics
├── logos/                 # Project logos and branding
├── references.bib         # Centralized BibTeX citations (Pandoc)
└── justfile               # Task runner (delegates to pennyfarthing/)
```

## Common Commands

```bash
# Day-to-day
just wheelhub start   # Start WheelHub server (API + WebSocket)
just wheelhub stop    # Stop WheelHub
just claude           # Launch Claude with OTEL pre-configured
just tui              # Launch TUI (starts WheelHub if needed)
just gui              # Open GUI in Chrome (starts WheelHub if needed)

# Build & test
just build            # Build all framework packages
just test             # Run framework tests
just dev              # Watch mode — auto-rebuild on changes
just sync             # Manual rebuild + symlink update
just install          # Install framework dependencies

# Health & validation
just doctor           # Check workspace health
just validate         # Run all validators (agents, subagents, sprint YAML)
just sidecar-health   # Check agent sidecar files for bloat

# Cyclist & infrastructure
just cyclist          # Cyclist operations (run, setup, doctor, build, etc.)
just tmux-dev         # Launch tmux dev layout
```

## Two Git Repos

This workspace contains two repositories with independent git histories:

| Repo | Branch strategy | Default branch | Purpose |
|------|----------------|----------------|---------|
| `orc-penny/` (this repo) | Trunk-based | `main` | Sprint files, sessions, docs, orchestration |
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
| `bdd-tandem` | SM → UX+Architect → TEA → Dev+UX → Reviewer+PM → SM |
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

## Architecture Decisions

27 ADRs document framework design choices. See [docs/adr/README.md](docs/adr/README.md) for the full index. Key decisions:

- **ADR-0005:** Single source of truth via symlinks (`.pennyfarthing/` → `pennyfarthing-dist/`)
- **ADR-0009:** Session file coordination protocol
- **ADR-0015:** Prime activation system (tiered context loading)
- **ADR-0022:** Sprint shard validation and reference integrity
- **ADR-0025:** Script-first gate extraction
- **ADR-0026:** Trunk-based development for orchestrator
- **ADR-0027:** Installation architecture rethink

## Related Repositories

| Repository | Purpose |
|-----------|---------|
| [pennyfarthing](https://github.com/1898andCo/pennyfarthing) | Framework source (TypeScript, Electron, React) |
| [poller-orchestrator](https://github.com/1898andCo/poller-orchestrator) | Sibling orchestrator for poller platform |
