# Epic 85: Clean Install Consolidation

## Overview

Move all Pennyfarthing-managed files under `.pennyfarthing/`, update init to bootstrap then hand off to an interactive workflow, and validate the install against real repos. Currently files are scattered across `.claude/`, `.pennyfarthing/`, `.git/hooks/`, and `.session/`, making it hard to reason about what Pennyfarthing owns vs user files.

**Epic Jira:** MSSCI-14364
**Stories:** MSSCI-14365 through MSSCI-14374 (10 stories, 34 points)
**Planning doc:** `docs/planning/install-overhaul-epics.md`

## Background

### The Problem

A `pennyfarthing init` run creates files in **5+ locations** outside `.pennyfarthing/`. This makes it difficult to:
- Know what Pennyfarthing owns vs what the user created
- Cleanly uninstall or upgrade
- Reason about the install layout

### Current File Layout (What Init Creates)

#### `.claude/` (Claude Code discovery namespace)
| File/Dir | Type | Purpose | Owner |
|----------|------|---------|-------|
| `manifest.json` | file | Install metadata (version, paths, hashes) | Pennyfarthing |
| `preferences.yaml` | template | User preferences (skip-if-exists) | User (after first edit) |
| `settings.local.json` | file | Permissions, hooks, env vars, statusLine | Pennyfarthing (merged) |
| `commands/` | dir | Command .md files (copied from node_modules + project) | Pennyfarthing |
| `skills/` | dir | Skill subdirs (copied from node_modules + project) | Pennyfarthing |
| `project/docs/shared-context.md` | template | Project description | User |
| `project/docs/agent-scopes.yaml` | template | Agent scope definitions | Pennyfarthing |
| `project/hooks/setup-env.sh` | template | Environment setup hook | User |
| `project/pennyfarthing-settings.yaml` | template | Repo/test/build config | User |
| `project/repos.yaml` | file | Repository definitions | User |
| `project/commands/` | dir | User custom commands (empty initially) | User |
| `project/skills/` | dir | User custom skills (empty initially) | User |

**Note:** `commands/` and `skills/` in `.claude/` are **required** by Claude Code for discovery. These can't simply move - they need to stay or be symlinked.

#### `.pennyfarthing/` (Framework runtime)
| File/Dir | Type | Purpose |
|----------|------|---------|
| `agents/` | symlink → node_modules | Agent definitions |
| `guides/` | symlink → node_modules | Behavior guides |
| `output-styles/` | symlink → node_modules | Output formatting |
| `personas/` | symlink → node_modules | Themed personas |
| `scripts/` | symlink → node_modules | Utility scripts |
| `workflows/` | symlink → node_modules | Workflow definitions |
| `sidecars/{agent}/` | dir (writable) | Agent learning files |
| `config.local.yaml` | file (runtime) | Theme/Cyclist config |
| `window-state.json` | file (runtime) | Cyclist window state |
| `bell-queue.json` | file (runtime) | Bell queue state |

#### `.git/hooks/` (Git integration)
| Hook | Source | Purpose |
|------|--------|---------|
| `pre-commit` | `scripts/hooks/pre-commit.sh` | Branch protection, file validation |
| `pre-push` | `scripts/hooks/pre-push.sh` | Jira sync reminder |
| `post-merge` | `scripts/hooks/post-merge.sh` | Sprint YAML auto-update |

#### Other locations
| Path | Purpose |
|------|---------|
| `.session/` | Active work sessions (gitignored) |
| `sprint/` | Sprint tracking (YAML files) |
| `.gitignore` entries | Auto-added Pennyfarthing sections |

## Technical Architecture

### Key Source Files

| File | Purpose |
|------|---------|
| `packages/core/src/cli/commands/init.ts` | Init command (main entry) |
| `packages/core/src/cli/commands/update.ts` | Update command with migration |
| `packages/core/src/cli/commands/doctor.ts` | Health check and auto-repair |
| `packages/core/src/cli/utils/constants.ts` | DIRECTORY_SYMLINKS, MANAGED_PATHS, CORE_AGENTS |
| `packages/core/src/cli/utils/symlinks.ts` | Symlink/copy helpers for commands, skills, dirs |
| `packages/core/src/cli/utils/settings.ts` | settings.local.json merge logic |
| `packages/core/src/cli/utils/manifest.ts` | Manifest read/write/create |
| `packages/core/src/cli/utils/node-modules.ts` | node_modules path discovery |
| `packages/core/src/cli/utils/files.ts` | File system helpers |

### Constants (constants.ts)

```typescript
DIRECTORY_SYMLINKS = [
  { name: 'agents', link: '.pennyfarthing/agents' },
  { name: 'guides', link: '.pennyfarthing/guides' },
  { name: 'output-styles', link: '.pennyfarthing/output-styles' },
  { name: 'personas', link: '.pennyfarthing/personas' },
  { name: 'scripts', link: '.pennyfarthing/scripts' },
  { name: 'workflows', link: '.pennyfarthing/workflows' }
];

ALL_SYMLINKS = [...DIRECTORY_SYMLINKS,
  { name: 'commands', link: '.claude/commands' },
  { name: 'skills', link: '.claude/skills' }
];

CORE_AGENTS = ['dev','tea','sm','reviewer','architect','pm',
               'tech-writer','ux-designer','devops','orchestrator'];
```

### Init Flow (init.ts)

1. Check existing installation → abort/update/reinstall
2. Create directory structure: `.claude/`, `.claude/project/*`, `.pennyfarthing/`, `sprint/`, `.session/`
3. Find `node_modules/@pennyfarthing/core/pennyfarthing-dist`
4. Remove legacy `.claude/pennyfarthing/` and legacy `.claude/{agents,guides,personas,scripts}` symlinks
5. Create symlinks: `.pennyfarthing/{agents,guides,output-styles,personas,scripts,workflows}` → node_modules
6. Copy commands: node_modules `commands/*.md` + `project/commands/*.md` → `.claude/commands/`
7. Copy skills: node_modules `skills/*/` + `project/skills/*/` → `.claude/skills/`
8. Create agent sidecars: `.pennyfarthing/sidecars/{agent}/{patterns,gotchas,decisions}.md`
9. Install git hooks: `pre-commit`, `pre-push`, `post-merge` → `.git/hooks/`
10. Generate templates (skip-if-exists): persona-config.yaml, preferences.yaml, shared-context.md, agent-scopes.yaml, pennyfarthing-settings.yaml, setup-env.sh
11. Merge `settings.local.json` (hooks, permissions, statusLine, env vars)
12. Write `.claude/manifest.json`
13. Update `.gitignore`

### Update Flow (update.ts)

1. Check manifest exists
2. Compare versions (installed vs available)
3. Merge settings.local.json (idempotent)
4. Re-copy directories from node_modules to `.pennyfarthing/`
5. Ensure `.claude/project/{commands,skills}` dirs exist
6. Re-copy commands and skills
7. Migrate sidecars from legacy locations:
   - `.claude/project/agents/{agent}-sidecar/` → `.pennyfarthing/sidecars/{agent}/`
   - `sprint/sidecars/{agent}/` → `.pennyfarthing/sidecars/{agent}/`
8. Update manifest version
9. Run doctor

### Settings Merge (settings.ts)

The `mergeSettingsLocalJson()` function ensures required hooks exist in `.claude/settings.local.json`:
- **SessionStart**: `session-start.sh`
- **SessionEnd**: session cleanup
- **Stop**: `question-reflector-check`
- **PostToolUse**: `bell-mode-hook`
- **PreToolUse**: `context-circuit-breaker`, `schema-validation`
- **statusLine**: `.pennyfarthing/scripts/misc/statusline.sh`
- **permissions.allow**: all installed `Skill(name)` entries

Also migrates legacy hook paths from `.claude/scripts/` → `.pennyfarthing/scripts/`.

### Commands vs Skills Handling (symlinks.ts)

Commands and skills are **copied** (not symlinked) to allow merging built-in + user-custom:
- Built-in commands: `node_modules/.../commands/*.md` → `.claude/commands/`
- User commands: `.claude/project/commands/*.md` → `.claude/commands/` (no override)
- Built-in skills: `node_modules/.../skills/*/` → `.claude/skills/`
- User skills: `.claude/project/skills/*/` → `.claude/skills/` (no override)

**Constraint:** `.claude/commands/` and `.claude/skills/` must exist at those paths for Claude Code to discover them.

## Migration Considerations

### Files that CAN move to `.pennyfarthing/`
- `manifest.json` → `.pennyfarthing/manifest.json`
- `persona-config.yaml` → `.pennyfarthing/config.local.yaml` (partially done already)
- `project/hooks/setup-env.sh` → `.pennyfarthing/project/hooks/setup-env.sh`
- `project/docs/agent-scopes.yaml` → `.pennyfarthing/project/docs/agent-scopes.yaml`
- `project/pennyfarthing-settings.yaml` → `.pennyfarthing/project/pennyfarthing-settings.yaml`
- `preferences.yaml` → `.pennyfarthing/preferences.yaml`

### Files that MUST stay in `.claude/` (Claude Code requirement)
- `settings.local.json` - Claude Code reads this for hooks/permissions
- `commands/` - Claude Code command discovery
- `skills/` - Claude Code skill discovery

### Files that need symlinks
- `settings.local.json`: canonical at `.pennyfarthing/`, symlink at `.claude/`
- Commands/skills: continue current approach (Claude Code discovers at `.claude/`)

### Git hooks
- Already outside `.claude/` (in `.git/hooks/`)
- Could move source-of-truth to `.pennyfarthing/project/hooks/` with install step copying to `.git/hooks/`

## Story Sequence

| # | Story | Jira | Points | Depends On |
|---|-------|------|--------|------------|
| 1.1 | Audit and map all files outside .pennyfarthing | MSSCI-14365 | 2 | - |
| 1.2 | Move settings.local.json generation | MSSCI-14366 | 3 | 1.1 |
| 1.3 | Move persona-config.yaml | MSSCI-14367 | 3 | 1.1 |
| 1.4 | Move project hooks | MSSCI-14368 | 3 | 1.1 |
| 1.5 | Consolidate sidecars directory | MSSCI-14369 | 2 | 1.1 |
| 1.6 | Update init command | MSSCI-14370 | 5 | 1.2-1.5 |
| 1.7 | Update update command | MSSCI-14371 | 5 | 1.6 |
| 1.8 | Update doctor | MSSCI-14372 | 3 | 1.6 |
| 1.9 | E2E test - fresh install | MSSCI-14373 | 5 | 1.6-1.8 |
| 1.10 | E2E test - upgrade | MSSCI-14374 | 3 | 1.7-1.8 |

Story 1.1 (MSSCI-14365) is the audit - a research/documentation story that feeds all subsequent work.
