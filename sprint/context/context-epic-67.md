# Epic 67: Pennyfarthing Python CLI

## Overview

Unified CLI entry point using Click. Phase 1 covers agent activation commands (highest frequency). Phase 2 covers core operations.

## Epic Details

- **Jira**: PROJ-12655
- **Points**: 19
- **Priority**: P1
- **Status**: In Progress
- **Repos**: pennyfarthing

## Stories

### Phase 1 (Agent Activation - Highest Frequency)

| Story | Title | Points | Status |
|-------|-------|--------|--------|
| PROJ-12656 | Add Click dependency and create CLI entry point | 2 | done |
| PROJ-12657 | Implement pf workflow check command | 2 | done |
| PROJ-12658 | Implement pf workflow phase-check command | 2 | done |
| PROJ-12659 | Implement pf agent start command | 3 | done |
| PROJ-12660 | Update agent command files to use Python CLI | 2 | backlog |

### Phase 2 (Core Operations)

| Story | Title | Points | Status |
|-------|-------|--------|--------|
| PROJ-12661 | Add startup benchmark to CI | 1 | backlog |
| PROJ-12662 | Migrate sprint/cli.py to Click | 2 | backlog |
| PROJ-12663 | Implement pf workflow handoff command | 2 | done |
| PROJ-12664 | Implement pf sprint story command | 1 | backlog |
| PROJ-12665 | Integration tests for bash/Python parity | 2 | backlog |

## CLI Architecture

The Python CLI uses Click with lazy-loaded subgroups for fast startup (<200ms target):

```
pf [command-group] [command] [options]
```

### Command Groups

- `pf agent` - Agent session management
- `pf workflow` - Workflow state and transitions
- `pf sprint` - Sprint operations
- `pf jira` - Jira integration
- `pf story` - Story management

### Key Commands

```bash
# Agent activation (highest frequency)
pf agent start <name> [--session-id ID] [--no-persona]

# Workflow state
pf workflow check [--json]
pf workflow phase-check <workflow> <phase>
pf workflow handoff <agent>

# Sprint/story
pf sprint story <id> [--json]
```

## Technical Notes

- All imports are lazy (inside functions) to maintain fast startup
- Click decorators replace argparse
- Python CLI complements but doesn't replace bash scripts (fallback available)
- PROJ-12657, PROJ-12658, PROJ-12663 were delivered as part of PROJ-12656

## Current Story: PROJ-12660

**Title**: Update agent command files to use Python CLI

**Description**: Update agent command files (sm.md, dev.md, etc.) to use Python CLI invocation instead of bash scripts.

**Acceptance Criteria**:
- All agent commands use Python CLI invocation
- Bash scripts remain available as fallback
