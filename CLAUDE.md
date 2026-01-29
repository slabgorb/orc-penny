# CLAUDE.md - Pennyfarthing Orchestrator

This is the orchestrator repo for Pennyfarthing agent development. It manages sprint tracking, agent sessions, and workflow coordination while the Pennyfarthing framework source lives in a separate nested repo.

## Project Overview

This repo orchestrates AI agents through BikeLane workflows for development work. The `pennyfarthing/` directory is a separate git repo (gitignored) that provides the framework via npm link.

## Repository Structure

```
pennyfarthing-orchestrator/      # This repo (orchestrator)
├── .claude/                     # Claude Code discovery
│   ├── commands/                # Symlinks to node_modules
│   └── skills/                  # Symlinks to node_modules
├── .pennyfarthing/              # Symlinks to node_modules/@pennyfarthing/core
│   ├── agents/                  # Agent definitions
│   ├── guides/                  # Behavior guides
│   ├── personas/                # Themed personas
│   ├── scripts/                 # Utility scripts
│   ├── workflows/               # Workflow definitions
│   └── sidecars/                # Agent learning files (local, writable)
├── sprint/                      # Sprint tracking
│   ├── current-sprint.yaml      # Active sprint
│   ├── archive/                 # Completed stories
│   └── context/                 # Epic context files
├── .session/                    # Active work sessions
├── docs/adr/                    # Architecture Decision Records
└── pennyfarthing/               # SEPARATE GIT REPO (gitignored)
```

## Orchestrator Pattern

This follows the same pattern as other orchestrator repos:
- `conductor/` → `conductor-api/`, `conductor-ui/`
- `siemulator/` → `siemulator-api/`, `siemulator-ui/`
- `poller-orchestrator/` → poller apps (external)

**Key principle:** Sprint management and agent housekeeping stay in the orchestrator. Application code lives in separate repos.

## Workflows

Use `/workflow list` to see available workflows, `/workflow start <name>` to begin.

**Main workflows:**
- `tdd` - Test-driven development (SM → TEA → Dev → Reviewer)
- `trivial` - Quick changes (SM → Dev → Reviewer, skips TEA)
- `bdd` - Behavior-driven development

## Agent Commands

- `/sm` - Scrum Master (story management)
- `/tea` - Test Engineer/Architect
- `/dev` - Developer
- `/reviewer` - Code Reviewer
- `/architect` - System design
- `/pm` - Product Manager

## Development Workflow

```bash
# Build pennyfarthing (from nested repo)
cd pennyfarthing
npm run build
npm link

# Orchestrator picks up changes via node_modules symlinks
```

## Sprint Management

- `/sprint status` - View current sprint
- `/sprint backlog` - Available stories
- `/sprint work` - Start a story
- `/story finish` - Complete current story

## Commits

```
<type>(<scope>): <subject>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

## Important Notes

1. **Never edit `.pennyfarthing/` symlinked directories** - they point to node_modules
2. **Sidecars are local** - `.pennyfarthing/sidecars/` is writable, captures agent learnings
3. **Sprint YAML access** - Use scripts, never edit directly
4. **Framework changes** - Make in `pennyfarthing/` repo, rebuild, npm link
5. **PRs for pennyfarthing** - Go to the pennyfarthing repo, not this orchestrator
