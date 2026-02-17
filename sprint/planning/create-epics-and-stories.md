---
stepsCompleted: [1, 2, 3]
inputDocuments:
  - docs/adr/0027-installation-architecture-rethink.md
  - .session/architecture-workflow-session.md
  - sprint/planning/install-overhaul-epics.md
---

# Installation Architecture Rethink - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for the Installation Architecture Rethink (ADR-0027), decomposing the architecture decisions into implementable stories. The initiative redesigns Pennyfarthing's installation from a 19-operation, two-runtime gauntlet into a three-phase progressive system with frontmatter-scoped hooks, deferred Python install, and polite config management.

**Supersedes:** sprint/planning/install-overhaul-epics.md (previous 10-story, 34-point breakdown)

## Requirements Inventory

### Functional Requirements

FR1: Init command MUST complete in 8 operations: create .pennyfarthing/, create .claude/, find node_modules, copy commands (pf-* prefix), copy skills (pf-* prefix), write base settings.local.json (5 hooks), write manifest (setup_completed: false), update .gitignore

FR2: Setup Detector (SessionStart hook, Node) MUST read manifest.json and inject additionalContext triggering /pf-setup when setup_completed is false

FR3: Setup Detector MUST use manifest flags only, never filesystem heuristics (CE-1)

FR4: Setup Workflow (/pf-setup) MUST interactively walk user through: repo discovery (repos.yaml), CLAUDE.md generation, theme selection (config.local.yaml), git hook installation (opt-in), Python CLI installation (required)

FR5: Setup Workflow MUST write setup_completed: true to manifest on completion

FR6: Agent .md files MUST declare their own hooks in frontmatter, calling pf directly: pre-edit-check, context-warning, context-breaker, bell-mode

FR7: Skill directories MUST declare their own hooks in frontmatter, calling pf directly: sprint-yaml validation, schema-validation

FR8: settings.local.json MUST contain exactly 5 hooks: setup-detector (startup), session-start, setup-env, session-stop, statusline

FR9: session-start.js (Node) MUST write PROJECT_ROOT and SESSION_ID to CLAUDE_ENV_FILE

FR10: Config Manager MUST use config.local.yaml as single source of truth, absorbing preferences.yaml and persona-config.yaml

FR11: File Copier MUST overwrite only pf-* prefixed files on update, never touch unprefixed user files (CE-4)

FR12: Sidecar creation MUST be lazy — created on first agent activation, not at init

FR13: Update command MUST run pending migrations and refresh framework files while preserving user customizations

FR14: Doctor command MUST reduce to ~10 health checks (down from 30), including Python CLI availability check

FR15: Init MUST be deterministic and idempotent — same input produces same output (CE-3)

FR16: Git hook installation MUST be opt-in, offered during Setup Workflow, never during Init

FR17: Init MUST detect installationType (symlink for dogfooding, copy for end-user) and write to manifest

FR18: Uninstall command MUST remove .pennyfarthing/ and clean .claude/ of pf-* files

FR19: Migration 0006 MUST migrate preferences.yaml settings into config.local.yaml

FR20: Migration 0007 MUST shrink settings.local.json from 13 hooks to 5, preserving user custom hooks

### NonFunctional Requirements

NFR1: Init MUST complete without prompting the user (--yes semantics), except optionally for project name

NFR2: Init phase MUST require only Node.js — Python installed during Setup phase, not Init

NFR3: All config reads MUST specify default values — missing key means default, not error (CE-5)

NFR4: Init MUST be fast — no network calls, no Python install, no git hook installation

NFR5: Framework MUST never write to user-owned files after init (sidecars, config, repos.yaml, CLAUDE.md are written by Setup Workflow with user interaction only)

NFR6: Setup Detector MUST fire only once per session (session-scoped guard file prevents re-trigger)

NFR7: Backward compatibility — upgrade from v11.x to v12.x MUST preserve user custom hooks, commands, and skills

### Additional Requirements

**From Architecture (ADR-0027):**

- Frontmatter hooks spike MUST be completed before any implementation (Phase 0) — test with 3 agents, verify lifecycle, verify no conflicts
- Major version bump to v12.0.0 required for the migration
- Manifest schema must include: version, projectName, installationType, nodeModulesPath, setup_completed, migrationsRun, installedAt, updatedAt, fileHashes
- session-start.js must be ported from Python to Node — behavior must match exactly
- All readers of preferences.yaml and persona-config.yaml must be updated atomically
- postinstall.cjs must add symlink repair (not just chmod)
- Naming conventions: hook scripts in kebab-case, framework files with pf- prefix, config keys in snake_case (YAML) / camelCase (JSON)
- Python CLI is a required runtime dependency — installed via `uv tool install` during Setup phase

**From Existing Install Epics (superseded but relevant context):**

- settings.local.json canonical location consideration (ADR decision: stays at .claude/settings.local.json, framework manages content)
- persona-config.yaml consolidation (ADR decision: absorbed into config.local.yaml)
- Project hooks location (.pennyfarthing/project/hooks/ for framework, .claude/project/ for user)
- End-to-end testing for fresh install and upgrade paths

**Contract Enforcement Rules (hard invariants):**

- CE-1: Setup Detector reads manifest only, never filesystem heuristics
- CE-2: Frontmatter hooks call `pf` directly — Python CLI is a required runtime dependency
- CE-3: Init output is deterministic and idempotent
- CE-4: Framework files require pf- prefix — violating this destroys user content
- CE-5: Config reads MUST have defaults — missing key = default, not error

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | Epic 2 | Init command — 8 operations |
| FR2 | Epic 3 | Setup Detector reads manifest, triggers /pf-setup |
| FR3 | Epic 3 | Setup Detector uses manifest flags only (CE-1) |
| FR4 | Epic 3 | Setup Workflow interactive configuration |
| FR5 | Epic 3 | Setup Workflow writes setup_completed: true |
| FR6 | Epic 1 (spike), Epic 5 (full) | Agent frontmatter hooks |
| FR7 | Epic 1 (spike), Epic 5 (full) | Skill frontmatter hooks |
| FR8 | Epic 2 | settings.local.json with 5 hooks |
| FR9 | Epic 2 | session-start.js Node port |
| FR10 | Epic 4 | config.local.yaml as single source of truth |
| FR11 | Epic 2 | File Copier pf-* prefix only (CE-4) |
| FR12 | Epic 6 | Lazy sidecar creation |
| FR13 | Epic 6 | Update command with migrations |
| FR14 | Epic 6 | Reduced doctor (~10 checks) |
| FR15 | Epic 2 | Init deterministic/idempotent (CE-3) |
| FR16 | Epic 3 | Git hooks opt-in during Setup |
| FR17 | Epic 2 | installationType detection |
| FR18 | Epic 2 | Uninstall command |
| FR19 | Epic 4, Epic 6 | Migration 0006: preferences → config.local.yaml |
| FR20 | Epic 5, Epic 6 | Migration 0007: shrink settings.local.json |

## Epic List

### Epic 1: Spike — Validate Frontmatter Hooks

The team confirms that Claude Code frontmatter hooks work reliably with Pennyfarthing agents before committing to the new architecture. This is the go/no-go gate for the entire initiative.

**FRs covered:** FR6, FR7 (validation only — not full implementation)

### Epic 2: Minimal Init — Fast, Silent, Node-Only Bootstrap

A user runs `npx pennyfarthing init` and gets a working Pennyfarthing install in seconds — no Python required at this phase, no prompts, no git hooks. Just the plumbing.

**FRs covered:** FR1, FR8, FR9, FR11, FR15, FR17, FR18
**NFRs:** NFR1, NFR2, NFR4

### Epic 3: Auto-Setup — Claude Guides Project Configuration

On the first Claude session after init, the Setup Detector triggers and Claude walks the user through configuring their project — repos, CLAUDE.md, theme, git hooks, and Python CLI installation. All interactive, all polite.

**FRs covered:** FR2, FR3, FR4, FR5, FR16
**NFRs:** NFR5, NFR6

### Epic 4: Config Consolidation — Single Source of Truth

All user configuration lives in one file (config.local.yaml). preferences.yaml and persona-config.yaml are dead. All readers updated atomically.

**FRs covered:** FR10, FR19
**NFRs:** NFR3

### Epic 5: Frontmatter Hook Migration — Self-Contained Agents and Skills

Each agent and skill declares its own hooks in frontmatter, calling `pf` directly. settings.local.json shrinks from 13 hooks to 5.

**FRs covered:** FR6, FR7, FR20

### Epic 6: Upgrade Path — Safe Migration from v11 to v12

Existing users upgrade smoothly. Custom hooks preserved, user files untouched, config migrated, doctor validates the new layout.

**FRs covered:** FR12, FR13, FR14, FR19, FR20
**NFRs:** NFR7

---

## Epic 1: Spike — Validate Frontmatter Hooks

The team confirms that Claude Code frontmatter hooks work reliably with Pennyfarthing agents before committing to the new architecture. This is the go/no-go gate for the entire initiative.

### Story 1.1: Test frontmatter hooks with three Pennyfarthing agents

As a framework developer,
I want to add frontmatter hooks to three existing agents (dev, tea, reviewer) in a test branch and verify they fire correctly,
So that we have evidence that Claude Code frontmatter hooks work at Pennyfarthing's scale before committing to the architecture.

**Acceptance Criteria:**

**Given** agent .md files for pf-dev, pf-tea, and pf-reviewer with frontmatter hooks declaring `pf hooks bell-mode` (PostToolUse) and `pf hooks pre-edit-check` (PreToolUse)
**When** each agent is activated in a Claude Code session
**Then** the frontmatter hooks fire on the correct tool events
**And** the hooks do not fire when a different agent is active
**And** hook cleanup occurs when switching between agents
**And** overlapping hook events (two agents both declaring PreToolUse) do not conflict

### Story 1.2: Test frontmatter hooks with skill directories

As a framework developer,
I want to add frontmatter hooks to the pf-sprint skill and verify they fire only when that skill is invoked,
So that we confirm skill-scoped hooks work for sprint-yaml validation and schema-validation.

**Acceptance Criteria:**

**Given** the pf-sprint skill directory with frontmatter hooks declaring `pf hooks sprint-yaml` (PostToolUse on Edit|Write)
**When** the pf-sprint skill is invoked during a Claude session
**Then** the sprint-yaml validation hook fires on Edit/Write tool uses
**And** the hook does NOT fire when pf-sprint is not the active skill
**And** the hook does NOT interfere with agent-level frontmatter hooks running concurrently

### Story 1.3: Document spike findings and update ADR-0027

As a framework developer,
I want a written spike report documenting what worked, what didn't, and any gotchas,
So that the team has clear guidance for the frontmatter migration and ADR-0027 status is updated to Accepted or revised.

**Acceptance Criteria:**

**Given** spike stories 1.1 and 1.2 are complete
**When** the spike report is written
**Then** it documents: hook lifecycle behavior, cleanup semantics, performance observations, edge cases found, and go/no-go recommendation
**And** if go: ADR-0027 status is updated from Proposed to Accepted
**And** if no-go: ADR-0027 documents the fallback (reduced settings.local.json with ~8 hooks)

---

## Epic 2: Minimal Init — Fast, Silent, Node-Only Bootstrap

A user runs `npx pennyfarthing init` and gets a working Pennyfarthing install in seconds — no Python required at this phase, no prompts, no git hooks. Just the plumbing.

### Story 2.1: Rewrite init command to 8 operations

As a framework user,
I want `npx pennyfarthing init` to complete in 8 fast, silent operations,
So that installation is quick and predictable without requiring Python or user interaction.

**Acceptance Criteria:**

**Given** a project with `@pennyfarthing/core` in node_modules
**When** I run `npx pennyfarthing init`
**Then** it creates `.pennyfarthing/` directory structure
**And** it creates `.claude/` directory structure
**And** it finds node_modules path and records it in manifest
**And** it copies commands to `.claude/commands/` with pf-* prefix
**And** it copies skills to `.claude/skills/` with pf-* prefix
**And** it writes `settings.local.json` with exactly 5 hooks (setup-detector, session-start, setup-env, session-stop, statusline)
**And** it writes manifest with `setup_completed: false`
**And** it updates `.gitignore` with Pennyfarthing entries
**And** it completes without prompting the user (NFR1)
**And** it requires only Node.js, no Python (NFR2)

### Story 2.2: Write session-start.js (Node port)

As a framework developer,
I want a Node.js session-start hook that writes PROJECT_ROOT and SESSION_ID to CLAUDE_ENV_FILE,
So that session environment is established without requiring Python at init time.

**Acceptance Criteria:**

**Given** Claude Code starts a session and fires SessionStart
**When** session-start.js executes
**Then** it writes `PROJECT_ROOT` to the path specified by `CLAUDE_ENV_FILE`
**And** it writes `SESSION_ID` (generated UUID) to `CLAUDE_ENV_FILE`
**And** it creates `.session/` directory if missing
**And** its behavior matches the existing Python `pf hooks session-start` for these specific responsibilities

### Story 2.3: Write setup-detector.js (SessionStart hook)

As a framework user,
I want the Setup Detector to automatically detect incomplete setup on my first Claude session,
So that I'm guided to configure my project without needing to know about `/pf-setup`.

**Acceptance Criteria:**

**Given** init has run and manifest has `setup_completed: false`
**When** Claude Code fires SessionStart (startup)
**Then** setup-detector.js reads `.pennyfarthing/manifest.json`
**And** returns JSON with `additionalContext` telling Claude to run `/pf-setup`
**And** writes a session-scoped guard file to prevent re-triggering in the same session (NFR6)

**Given** setup has already completed (`setup_completed: true`)
**When** Claude Code fires SessionStart
**Then** setup-detector.js exits 0 silently with no output

**Given** manifest.json is missing or unreadable
**When** setup-detector.js runs
**Then** it exits 0 silently (don't block Claude startup)

### Story 2.4: Make init deterministic and idempotent

As a framework developer,
I want init to produce identical output for identical input and be safe to re-run,
So that testing is reliable and users can re-run init without fear.

**Acceptance Criteria:**

**Given** init has already run on a project
**When** I run `npx pennyfarthing init` again
**Then** it exits with code 2 (already-installed) and does not modify existing files

**Given** I run `npx pennyfarthing init --force`
**When** init completes
**Then** framework files (pf-* prefixed) are refreshed
**And** user files are not touched
**And** the output is identical to a fresh init with the same package version and project name (CE-3)

### Story 2.5: Implement installationType detection and uninstall command

As a framework user,
I want init to detect whether this is a dogfooding (symlink) or end-user (copy) install, and I want a clean uninstall option,
So that the right strategy is used and I can fully remove Pennyfarthing if needed.

**Acceptance Criteria:**

**Given** the project has `.pennyfarthing/` symlinked to `pennyfarthing/pennyfarthing-dist/`
**When** init runs
**Then** manifest records `installationType: "symlink"`

**Given** the project installed via npm (no symlinks)
**When** init runs
**Then** manifest records `installationType: "copy"`

**Given** a project with Pennyfarthing installed
**When** I run `npx pennyfarthing uninstall`
**Then** `.pennyfarthing/` is removed
**And** `.claude/commands/pf-*` and `.claude/skills/pf-*` are removed
**And** framework hooks are removed from `settings.local.json` (user custom hooks preserved)
**And** user files (CLAUDE.md, repos.yaml, sidecars) are NOT removed

---

## Epic 3: Auto-Setup — Claude Guides Project Configuration

On the first Claude session after init, the Setup Detector triggers and Claude walks the user through configuring their project — repos, CLAUDE.md, theme, git hooks, and Python CLI installation. All interactive, all polite.

### Story 3.1: Update /pf-setup workflow for deferred configuration

As a framework user,
I want the /pf-setup workflow to handle all the configuration that init used to do,
So that I'm guided through setting up repos, CLAUDE.md, theme, git hooks, and Python CLI interactively.

**Acceptance Criteria:**

**Given** Claude triggers /pf-setup after Setup Detector fires
**When** the setup workflow runs
**Then** it walks through repo discovery and writes `repos.yaml`
**And** it generates `CLAUDE.md` based on discovered repos
**And** it offers theme selection and writes to `config.local.yaml`
**And** it offers git hook installation (opt-in) and installs only if user consents (FR16)
**And** it installs Python CLI via `uv tool install pennyfarthing-scripts` (required step)
**And** it writes `setup_completed: true` to manifest on completion (FR5)

### Story 3.2: Setup Workflow handles partial completion and re-entry

As a framework user,
I want to be able to exit setup partway through and resume later,
So that I'm not forced to complete everything in one session.

**Acceptance Criteria:**

**Given** the user exits /pf-setup before completing all steps
**When** the next Claude session starts
**Then** Setup Detector fires again (setup_completed is still false)
**And** /pf-setup resumes from where the user left off (reads existing repos.yaml, config, etc.)
**And** already-completed steps are skipped or shown as done

**Given** the user completes all setup steps
**When** setup writes `setup_completed: true`
**Then** Setup Detector never triggers /pf-setup again in future sessions

---

## Epic 4: Config Consolidation — Single Source of Truth

All user configuration lives in one file (config.local.yaml). preferences.yaml and persona-config.yaml are dead. All readers updated atomically.

### Story 4.1: Write migration 0006 — preferences.yaml to config.local.yaml

As a framework developer,
I want preferences.yaml settings absorbed into config.local.yaml,
So that there's one config file instead of three scattered across two wrong paths.

**Acceptance Criteria:**

**Given** a project with `.pennyfarthing/preferences.yaml` or `.claude/pennyfarthing/preferences.yaml`
**When** migration 0006 runs
**Then** `character_voice`, `explain_decisions`, and `auto_commit` are merged into `config.local.yaml` under a `preferences:` key
**And** existing config.local.yaml values are preserved (additive merge, not overwrite)
**And** the old preferences.yaml file is removed
**And** manifest records migration 0006 as complete

**Given** no preferences.yaml exists
**When** migration 0006 runs
**Then** config.local.yaml gets a `preferences:` section with defaults (`character_voice: true`, `explain_decisions: true`, `auto_commit: false`)

### Story 4.2: Update all config readers to use config.local.yaml

As a framework developer,
I want all code that reads preferences.yaml or persona-config.yaml to read from config.local.yaml instead,
So that the dead files are truly dead and the single source of truth is enforced.

**Acceptance Criteria:**

**Given** `persona.py` currently reads from `.claude/pennyfarthing/preferences.yaml`
**When** this story is complete
**Then** `persona.py` reads `preferences.character_voice` from `.pennyfarthing/config.local.yaml` with default `true`

**Given** `agent-session.sh` currently reads from `.claude/pennyfarthing/preferences.yaml`
**When** this story is complete
**Then** `agent-session.sh` reads from `.pennyfarthing/config.local.yaml` with default `true`

**And** every config read has a default value (CE-5)
**And** the preferences.yaml template is removed from `pennyfarthing-dist/templates/`
**And** `pf agent start` works correctly with the new config path for every agent

---

## Epic 5: Frontmatter Hook Migration — Self-Contained Agents and Skills

Each agent and skill declares its own hooks in frontmatter, calling `pf` directly. settings.local.json shrinks from 13 hooks to 5.

### Story 5.1: Add frontmatter hooks to all agent .md files

As a framework developer,
I want every Pennyfarthing agent to declare its own hooks in frontmatter,
So that component-specific hooks are self-contained and don't pollute settings.local.json.

**Acceptance Criteria:**

**Given** agent .md files (pf-dev, pf-tea, pf-reviewer, pf-sm, pf-architect, pf-pm, pf-tech-writer, pf-ux-designer, pf-devops, pf-orchestrator, pf-ba)
**When** frontmatter hooks are added
**Then** each agent declares PreToolUse hooks for `pre-edit-check`, `context-warning`, `context-breaker` (matcher: Edit|Write|Bash|Task)
**And** each agent declares PostToolUse hook for `bell-mode`
**And** hooks call `pf` directly (e.g., `pf hooks bell-mode`)
**And** agents that are Cyclist-specific additionally declare `reflector-check` and `cyclist-pretooluse`

### Story 5.2: Add frontmatter hooks to relevant skill directories

As a framework developer,
I want skills that need validation hooks to declare them in their own frontmatter,
So that sprint-yaml and schema-validation only fire when the skill is active.

**Acceptance Criteria:**

**Given** the pf-sprint skill directory
**When** frontmatter hooks are added
**Then** it declares PostToolUse hook for `sprint-yaml` (matcher: Edit|Write)
**And** it declares PreToolUse hook for `schema-validation` (matcher: Write)

**Given** other skills that don't need hooks
**When** reviewed
**Then** no frontmatter hooks are added (hooks only where needed)

### Story 5.3: Write migration 0007 — shrink settings.local.json

As a framework developer,
I want migration 0007 to remove the 8 hooks that moved to frontmatter from settings.local.json,
So that existing installs are updated to the new 5-hook minimal settings.

**Acceptance Criteria:**

**Given** an existing settings.local.json with 13 hooks
**When** migration 0007 runs
**Then** hooks for pre-edit-check, context-warning, context-breaker, bell-mode, sprint-yaml, schema-validation, reflector-check, and cyclist-pretooluse are removed
**And** the 5 infrastructure hooks remain: setup-detector, session-start, setup-env, session-stop, statusline
**And** any user-added custom hooks (non pf-* entries) are preserved
**And** manifest records migration 0007 as complete

---

## Epic 6: Upgrade Path — Safe Migration from v11 to v12

Existing users upgrade smoothly. Custom hooks preserved, user files untouched, config migrated, doctor validates the new layout.

### Story 6.1: Implement update command with migration runner

As a framework user,
I want `npx pennyfarthing update` to run pending migrations and refresh framework files,
So that I can upgrade from v11 to v12 without manual intervention.

**Acceptance Criteria:**

**Given** a v11.x Pennyfarthing install
**When** I run `npx pennyfarthing update` after installing v12.x package
**Then** it reads manifest `migrationsRun` and executes pending migrations (0006, 0007) in order
**And** it refreshes pf-* prefixed commands and skills from the new package
**And** it does NOT touch unprefixed user commands or skills (CE-4)
**And** it updates manifest version to 12.0.0
**And** if any migration fails, it stops and reports the error without updating manifest version

### Story 6.2: Implement lazy sidecar creation

As a framework developer,
I want sidecars created on first agent activation instead of at init,
So that init is fast and new agents added in future versions get their sidecars automatically.

**Acceptance Criteria:**

**Given** init has run but no agents have been activated
**When** I check `.pennyfarthing/sidecars/`
**Then** no agent sidecar directories exist

**Given** an agent is activated for the first time (e.g., `pf agent start dev`)
**When** the agent's sidecar directory doesn't exist
**Then** it is created from templates (patterns.md, gotchas.md, decisions.md)
**And** subsequent activations of the same agent reuse the existing sidecar

### Story 6.3: Reduce doctor to ~10 health checks

As a framework user,
I want `pennyfarthing doctor` to run fewer, more meaningful checks,
So that doctor reflects the simpler architecture and doesn't cry wolf.

**Acceptance Criteria:**

**Given** a healthy v12 install
**When** I run `pennyfarthing doctor`
**Then** it runs ~10 checks: manifest exists, manifest version matches package, 5 settings.local.json hooks present, pf CLI installed and reachable, config.local.yaml parseable, .pennyfarthing/ structure intact, no dangling symlinks (if installationType=symlink), pf-* commands/skills present, .gitignore has Pennyfarthing entries
**And** `--fix` auto-repairs: refresh pf-* files, regenerate missing manifest, repair symlinks

**Given** a v11 install that hasn't been updated
**When** I run `pennyfarthing doctor`
**Then** it detects the version mismatch and recommends `npx pennyfarthing update`

### Story 6.4: End-to-end test — fresh install and upgrade

As a framework developer,
I want automated tests verifying both fresh install and v11-to-v12 upgrade,
So that we can ship with confidence that both paths work.

**Acceptance Criteria:**

**Given** a temporary empty git repo
**When** the fresh install test runs `npx pennyfarthing init` and `pennyfarthing doctor`
**Then** doctor reports all checks passing
**And** manifest shows `setup_completed: false` and correct version

**Given** a temporary repo set up with v11-style install (13 hooks, preferences.yaml, old structure)
**When** the upgrade test runs `npx pennyfarthing update` and `pennyfarthing doctor`
**Then** migrations 0006 and 0007 complete successfully
**And** settings.local.json has 5 hooks (plus any user custom hooks)
**And** config.local.yaml has preferences section
**And** doctor reports all checks passing
