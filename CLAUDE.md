# CLAUDE.md - Pennyfarthing Orchestrator

This is the orchestrator repo for Pennyfarthing agent development. This repo uses Pennyfarthing as an installed package.

## Project Overview

This repo orchestrates AI agents through BikeLane workflows for development work. The framework is installed via npm link to the local pennyfarthing repo.

## Key Paths

```
.claude/                     # Claude Code discovery
├── commands/                # Built-in + custom commands
├── skills/                  # Built-in + custom skills
└── project/                 # Project customizations

.pennyfarthing/              # Pennyfarthing content (symlinks to node_modules)
├── agents/                  # Agent definitions
├── guides/                  # Behavior guides
├── personas/                # Themed personas
├── scripts/                 # Utility scripts
├── workflows/               # Workflow definitions
└── sidecars/                # Agent learning files (local, writable)

sprint/                      # Sprint tracking
├── current-sprint.yaml      # Active sprint
├── archive/                 # Completed stories
└── context/                 # Epic context files

.session/                    # Active work sessions
docs/adr/                    # Architecture Decision Records
```

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
# Update pennyfarthing from local development
cd ~/Projects/pennyfarthing
npm run build
npm link

# This repo picks up changes automatically via npm link
pennyfarthing update  # Refresh symlinks if needed
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
4. **Framework changes** - Make in `~/Projects/pennyfarthing`, then rebuild
