# CLAUDE.md — Pennyfarthing Orchestrator

Orchestrator for Pennyfarthing framework development. Manages sprint tracking, agent sessions, and coordinates work on the inlined framework repo at `pennyfarthing/`.

<critical>
## Two Git Repos

- **This repo** (`pennyfarthing-orchestrator/`) — sprint files, sessions, docs, orchestration. Trunk-based: PRs target `main`.
- **`pennyfarthing/`** (inlined) — framework source, separate git history. Gitflow: PRs target `develop`.
</critical>

<critical>
## Rules

1. **Never edit `.pennyfarthing/` symlinked dirs** — edit source at `pennyfarthing/pennyfarthing-dist/`
2. **Never edit sprint YAML directly** — use `pf sprint story` commands
3. **Never edit `node_modules/`** — trace symlinks to source repo
4. **Modify `pennyfarthing/pennyfarthing-dist/`** — single source of truth for all distributed files
5. **Use `.js` extensions** in relative TypeScript imports
6. **Return result objects** `{success, data?, error?}` — don't throw
7. **Use Haiku for subagents** — never Opus for mechanical tasks
8. **Runtime scripts use `.pennyfarthing/` paths** — never `pennyfarthing-dist/`
9. **Dogfood symlinks** — `.claude/commands/` and `.claude/skills/` symlink to `pennyfarthing-dist/`. Edit source, not targets.
</critical>

<git-operations>
NEVER skip GPG/SSH commit signing. If signing fails, stop and tell the user.

Commit format: `<type>(<scope>): <subject>`

Branching per `.pennyfarthing/repos.yaml`. This repo: `main`. `pennyfarthing/`: `develop`.

"Pull all repos" = include ALL workspace repos including `pennyfarthing/`.

Framework commits: `cd pennyfarthing && git add . && git commit -m "feat: ..."`
Orchestrator commits: `git add sprint/ && git commit -m "chore(sprint): ..."`
</git-operations>

<info>
## Repository Structure

| Directory | Purpose |
|-----------|---------|
| `.pennyfarthing/` | Runtime framework (symlinks → `pennyfarthing/pennyfarthing-dist/`) |
| `.pennyfarthing/sidecars/` | Agent learning files (local, writable, NOT symlinked) |
| `pennyfarthing/` | Inlined framework source repo |
| `sprint/` | Sprint tracking — `current-sprint.yaml` (index), `epic-*.yaml` (shards) |
| `.session/` | Active work sessions |
| `docs/adr/` | Architecture Decision Records |
| `justfile` | Task runner (`just help`) |
</info>

<info>
## Workflows & Agents

`/workflow list` for all workflows, `/workflow` for current status.

Workflow definitions live in `pennyfarthing/pennyfarthing-dist/workflows/*.yaml`. Each YAML defines phases, agents, tandem/team pairings, and gates. **Read the YAML — don't rely on summaries.**

- `pf workflow list` — all available workflows
- `pf workflow show <name>` — phase details for a specific workflow
- Session file `**Workflow:**` line tells you which workflow is active

| Command | Agent | Command | Agent |
|---------|-------|---------|-------|
| `/sm` | Scrum Master | `/pm` | Product Manager |
| `/tea` | Test Engineer | `/tech-writer` | Documentation |
| `/dev` | Developer | `/ux-designer` | UX Design |
| `/reviewer` | Code Reviewer | `/devops` | Infrastructure |
| `/architect` | System Design | `/orchestrator` | Meta-operations |
| `/ba` | Business Analyst | | |

**Sprint:** `/sprint status`, `/sprint backlog`, `/sprint work`

**Subagents** (Task tool): `sm-setup`, `sm-finish`, `sm-file-summary`, `testing-runner`, `reviewer-preflight`, `tandem-backseat`

**Handoff:** Agent writes assessment → `pf.sh handoff resolve-gate` → `complete-phase` → `marker` → next agent activates.
</info>

<info>
## Framework Structure (`pennyfarthing/`)

| Directory | Purpose |
|-----------|---------|
| `pennyfarthing-dist/` | Published package (source of truth) — agents, commands, guides, skills, personas, workflows, scripts |
| `pennyfarthing-dist/pf/` | Python CLI package (hooks, jira, sprint, story, prime) |
| `packages/core/` | `@pennyfarthing/core` — CLI, WheelHub server, API routes, shared utilities |
| `packages/cyclist/` | Visual terminal (React 19, Tailwind v4, dockview) — thin wrapper over core |
| `packages/electron/` | Electron shell (legacy, minimal use) |
| `packages/benchmark/` | Persona benchmarking (JobFair) |
| `packages/themes-*/` | Theme packages (comedy, literary, mythology-fantasy, prestige-tv, realistic, scifi, superheroes) |

**Display modes:** BikeRack panels render in three contexts:
- **TUI** — `pf bikerack start` launches panels alongside Claude Code CLI in the terminal
- **GUI** — Cyclist web UI with full dockview panel layout in a browser
- **IDE** — VS Code / Cursor sidebar panels via WheelHub API

**Key files:**

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/agents/*.md` | Agent and subagent definitions |
| `.pennyfarthing/config.local.yaml` | Theme, bell_mode, relay_mode, permission_mode, statusbar |
| `.pennyfarthing/repos.yaml` | Repo topology — ownership, symlinks, branch strategy, never-edit zones |
| `.session/{story-id}-session.md` | Active work context |
| `pennyfarthing-dist/guides/` | Behavior guides and component docs |
</info>

<context>
## Component Guides

Read guides for detailed behavior, key files, and APIs. All at `pennyfarthing/pennyfarthing-dist/guides/`.

| Component | Guide | Purpose |
|-----------|-------|---------|
| BikeLane | `bikelane.md` | Workflow engine — phased, stepped, procedural |
| BikeRack | `bikerack.md` | Standalone panel viewer for CLI-first dev |
| Gates | `gates.md` | Phase transition quality checks |
| Handoff CLI | `handoff-cli.md` | Gate resolution, session transitions, markers |
| Hooks | `hooks.md` | Claude Code hooks — session, pre/post tool use |
| Bell Mode | `bell-mode.md` | Message queue injection via PostToolUse |
| Relay Mode | `relay-mode.md` | Auto-handoff execution |
| TirePump | `tirepump.md` | Context clearing and session reload |
| Prime | `prime.md` | Agent activation with tiered context |
| Reflector | `reflector.md` | Agent-to-UI markers for QuickActions |
| Tandem | `tandem-protocol.md` | Background observer pairing |
| Output Styles | `output-styles.md` | Response modes (terse, verbose, teaching) |
| Brownfield | `brownfield-tools.md` | Codebase analysis — hotspots, complexity, health |
| Benchmarks | `../../packages/benchmark/docs/benchmarks-guide.md` | Persona evaluation (OCEAN traits) |
</context>
