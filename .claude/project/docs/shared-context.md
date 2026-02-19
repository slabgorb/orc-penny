# Shared Agent Context

This file contains common context loaded by all agents.

## Project

- **Name:** pennyfarthing-orchestrator
- **Sprint Status:** `sprint/current-sprint.yaml`
- **Active Work:** `.session/{story-id}-session.md`
- **Agent Framework:** Pennyfarthing (npm)

### Tech Stack

| Component | Language | Framework | Notes |
|-----------|----------|-----------|-------|
| Orchestrator | JavaScript | Node.js (ES modules) | Sprint management, coordination |
| Core (`@pennyfarthing/core`) | TypeScript | Node.js, Express | CLI, WheelHub server, API routes, shared utilities |
| Cyclist | TypeScript | React 19, Electron, Tailwind v4, dockview | Visual terminal UI |
| Benchmark | TypeScript | Node.js | Persona evaluation, JobFair |
| Theme Packs | TypeScript | - | comedy, literary, mythology-fantasy, prestige-tv, realistic, scifi, superheroes |
| Scripts | Python | Click, PyYAML | Hooks, Jira, sprint, story management |

### Repo Structure

```
pennyfarthing-orchestrator/          # Orchestrator (trunk-based, main)
├── .pennyfarthing/                  # Runtime framework (symlinks → pennyfarthing-dist/)
│   ├── agents/                      # Agent definitions (symlinked)
│   ├── guides/                      # Component guides (symlinked)
│   ├── personas/                    # Persona themes (symlinked)
│   ├── scripts/                     # Framework scripts (symlinked)
│   ├── workflows/                   # Workflow definitions (symlinked)
│   ├── sidecars/                    # Agent learnings (local, writable)
│   ├── config.local.yaml            # Theme, bell_mode, relay_mode
│   └── repos.yaml                   # Repository configuration
├── sprint/                          # Sprint tracking (YAML shards)
│   ├── current-sprint.yaml          # Sprint index
│   ├── epic-*.yaml                  # Per-epic story shards
│   ├── initiative-*.yaml            # Backlog initiatives
│   ├── planning/                    # Sprint planning artifacts
│   └── context/                     # Story context files
├── .session/                        # Active work sessions
├── docs/                            # Documentation, ADRs
├── justfile                         # Task runner recipes
├── pennyfarthing/                   # Inlined framework repo (gitflow, develop)
│   ├── pennyfarthing-dist/          # Published package content (source of truth)
│   ├── packages/core/               # @pennyfarthing/core
│   ├── packages/cyclist/            # Visual terminal (Electron + React)
│   ├── packages/benchmark/          # Performance benchmarking
│   ├── packages/themes-*/           # Theme packages
│   ├── pennyfarthing-dist/pf/       # Distributed Python package
│   └── tests/                       # Framework tests
└── .claude/                         # Claude Code configuration
    └── project/docs/                # This file, agent context
```

## Git Branch Strategy

Per-repo branching is defined in `.pennyfarthing/repos.yaml` (`branch_strategy` and `default_branch` fields).

### Orchestrator repos (trunk-based — ADR-0026)
- **Trunk:** `main` (single long-lived branch)
- **All work:** Feature branches off `main`
- **PRs target:** `main`
- **No `develop` branch** — its absence is the enforcement mechanism
- **Naming:** `feat/[story]-[description]` or `fix/[issue]-[description]`

### Framework/application repos (gitflow)
- **Branch from:** `develop`
- **PRs target:** `develop`
- **Releases:** `develop` → `main` with version tags
- **Naming:** `feat/[story]-[description]` or `fix/[issue]-[description]`

## TDD Workflow

1. **SM** creates story and hands off to TEA
2. **TEA** writes failing tests, hands off to Dev
3. **Dev** implements to pass tests, hands off to Reviewer
4. **Reviewer** reviews code, approves or requests changes

## Testing Commands

### Framework (pennyfarthing/)
```bash
cd pennyfarthing && pnpm test              # Run all tests
cd pennyfarthing && pnpm test -- --grep "pattern"  # Run specific test
```

### Orchestrator
```bash
just test                                  # Run tests via justfile
```

## Building

### Framework (pennyfarthing/)
```bash
cd pennyfarthing && pnpm install           # Install dependencies
cd pennyfarthing && pnpm build             # TypeScript compilation (tsc)
cd pennyfarthing && pnpm run dev           # Watch mode (tsc --watch)
cd pennyfarthing && pnpm run lint          # ESLint
```

### Orchestrator
```bash
npm install                                # Install + pennyfarthing update
just build                                 # Build via justfile
just dev                                   # Start development environment
```
