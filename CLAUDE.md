# CLAUDE.md - Pennyfarthing Orchestrator

This is the orchestrator repo for Pennyfarthing framework development. It manages sprint tracking, agent sessions, and coordinates work on the framework itself.

## Project Overview

Unlike other orchestrators (conductor, siemulator) which coordinate api/ui subrepos, this orchestrator manages the **pennyfarthing framework** as an inlined development repo. The framework source lives in `pennyfarthing/` and changes here are the primary focus.

## Repository Structure

```
pennyfarthing-orchestrator/      # This repo (orchestrator)
├── .claude/                     # Claude Code discovery (symlinks to node_modules)
├── .pennyfarthing/              # Runtime framework (symlinks to node_modules/@pennyfarthing/core)
│   ├── agents/                  # Agent definitions
│   ├── guides/                  # Behavior guides
│   ├── personas/                # Themed personas
│   ├── scripts/                 # Utility scripts
│   ├── workflows/               # Workflow definitions
│   └── sidecars/                # Agent learning files (local, writable, NOT symlinked)
├── pennyfarthing/               # INLINED: Framework source repo for development
│   ├── pennyfarthing-dist/      # Built output (published to npm)
│   ├── pennyfarthing_scripts/   # Python scripts
│   ├── packages/                # NPM packages
│   ├── tests/                   # Test suite
│   ├── scenarios/               # Test scenarios
│   └── benchmarks/              # Performance benchmarks
├── sprint/                      # Sprint tracking for framework work
│   ├── current-sprint.yaml      # Active sprint
│   ├── future.yaml              # Backlog
│   ├── completed.yaml           # Done archive
│   ├── sprint-template.yaml     # Template for new sprints
│   ├── archive/                 # Old stories
│   └── context/                 # Epic context files
├── .session/                    # Active work sessions
├── docs/                        # Documentation
│   ├── adr/                     # Architecture Decision Records
│   └── planning/                # Planning documents
├── repos.yaml                   # Repository configuration
└── justfile                     # Task runner recipes
```

## Architecture

This orchestrator differs from others:

| Orchestrator | Pattern | Subrepos |
|--------------|---------|----------|
| conductor | api + ui | conductor-api/, conductor-ui/ |
| siemulator | api + ui | siemulator-api/, siemulator-ui/ |
| **pennyfarthing-orchestrator** | framework dev | pennyfarthing/ (inlined) |

**Key principle:** Sprint management stays in the orchestrator. Framework development happens in the inlined `pennyfarthing/` directory.

## Development Workflow

### Framework Changes (Primary Work)
```bash
# Work in the inlined pennyfarthing repo
cd pennyfarthing
pnpm install
pnpm build

# Test changes
pnpm test

# Commits go to the pennyfarthing repo
git add . && git commit -m "feat: add new feature"
git push origin <branch>
```

### Orchestrator-Only Changes
```bash
# Sprint files, session management, docs
# These stay in pennyfarthing-orchestrator repo
git add sprint/ && git commit -m "chore(sprint): update status"
```

## Just Commands

Run `just help` to see available recipes. Key commands:
- `just dev` - Start development environment
- `just test` - Run tests
- `just build` - Build framework

## Workflows

Use `/workflow list` to see available workflows, `/workflow` to check current status.

**Main workflows:**
- `tdd` - Test-driven development (SM → TEA → Dev → Reviewer)
- `trivial` - Quick changes (SM → Dev → Reviewer, skips TEA)
- `bdd` - Behavior-driven development
- `agent-docs` - Agent documentation workflow

## Agent Commands

- `/sm` - Scrum Master (story management)
- `/tea` - Test Engineer/Architect
- `/dev` - Developer
- `/reviewer` - Code Reviewer
- `/architect` - System design
- `/pm` - Product Manager
- `/tech-writer` - Documentation
- `/ux-designer` - UX design
- `/devops` - Infrastructure and deployment
- `/orchestrator` - Multi-agent coordination

## Sprint Management

- `/sprint status` - View current sprint
- `/sprint backlog` - Available stories
- `/sprint work` - Start a story

## Commits

```
<type>(<scope>): <subject>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

## Important Notes

1. **Two git repos in play:**
   - `pennyfarthing-orchestrator/` - orchestrator repo (sprint, sessions, docs)
   - `pennyfarthing/` - framework repo (inlined, separate git history)

2. **Never edit `.pennyfarthing/` symlinked directories** - they point to node_modules

3. **Sidecars are local** - `.pennyfarthing/sidecars/` is writable, captures agent learnings

4. **Sprint YAML access** - Use scripts, never edit directly

5. **Publishing framework** - After changes in `pennyfarthing/`, build and publish to npm
