# CLAUDE.md — Pennyfarthing Orchestrator

Orchestrator for Pennyfarthing framework development. Manages sprint tracking, agent sessions, and coordinates work on the inlined framework repo at `pennyfarthing/`.

<critical>
## Two Git Repos

- `pennyfarthing-orchestrator/` (this repo) — sprint files, sessions, docs, orchestration
- `pennyfarthing/` (inlined) — framework source, separate git history

Sprint management stays here. Framework development happens in `pennyfarthing/`.
</critical>

<critical>
## Rules

1. **Never edit `.pennyfarthing/` symlinked directories** — they point to `pennyfarthing/pennyfarthing-dist/` - edit them in the child repo
2. **Never edit sprint YAML directly** — use scripts
3. **Sidecars are local** — `.pennyfarthing/sidecars/` is writable, captures agent learnings
4. **Publishing framework** — after changes in `pennyfarthing/`, build and publish to npm
</critical>

<critical>
## Framework Implementation Rules

1. **Modify `pennyfarthing/pennyfarthing-dist/`** — single source of truth for all definitions
2. **Use `.js` extensions** in all relative TypeScript imports
3. **Return result objects** `{success, data?, error?}` instead of throwing
4. **Use Haiku for subagents** — never Opus for mechanical tasks
5. **Scripts use `.pennyfarthing/` paths** — never `pennyfarthing-dist/` in runtime scripts
</critical>

<code-editing>
Never edit files inside `node_modules/` or symlink targets. Trace symlinks back to the actual source repo (`pennyfarthing/pennyfarthing-dist/`) and edit there.
</code-editing>

<git-operations>
Commit format: `<type>(<scope>): <subject>`

Per-repo branching is defined in `.pennyfarthing/repos.yaml` (`branch_strategy` and `default_branch` fields).

This repo uses **trunk-based development** (ADR-0026). Single long-lived branch: `main`.
Feature branches and PRs target `main` directly. There is no `develop` branch.

The `pennyfarthing/` child repo uses gitflow — PRs target `develop` there.

When user says "pull all repos" or "pull everything", include ALL repos in the workspace (including `pennyfarthing/` and any other related repos).

Framework commits go to the `pennyfarthing/` repo:
```bash
cd pennyfarthing && git add . && git commit -m "feat: add new feature"
```

Orchestrator commits stay here:
```bash
git add sprint/ && git commit -m "chore(sprint): update status"
```
</git-operations>

<info>
## Repository Structure

| Directory | Purpose |
|-----------|---------|
| `.pennyfarthing/` | Runtime framework (symlinks to `pennyfarthing/pennyfarthing-dist/`) — agents, guides, personas, scripts, workflows |
| `.pennyfarthing/sidecars/` | Agent learning files (local, writable, NOT symlinked) |
| `pennyfarthing/` | Inlined framework source repo |
| `sprint/` | Sprint tracking — `current-sprint.yaml` (index), `epic-*.yaml` (per-epic shards), `planning/`, `context/` |
| `.session/` | Active work sessions |
| `docs/` | Documentation — `adr/` (Architecture Decision Records) |
| `justfile` | Task runner recipes (`just help` for list) |
</info>

<info>
## Development

```bash
# Framework changes
cd pennyfarthing && pnpm install && pnpm build && pnpm test

# Just commands
just dev       # Start development environment
just test      # Run tests
just build     # Build framework
```
</info>

<info>
## Workflows & Agents

Use `/workflow list` to see available workflows, `/workflow` to check current status.

| Workflow | Flow |
|----------|------|
| `tdd` | SM → TEA → Dev → Reviewer → SM |
| `tdd-tandem` | SM → TEA+Architect → Dev+TEA → Reviewer+PM → SM |
| `trivial` | SM → Dev → Reviewer → SM |
| `bdd` | SM → UX → TEA → Dev → Reviewer → SM |
| `bdd-tandem` | SM → UX+Architect → TEA → Dev+UX → Reviewer+PM → SM |
| `agent-docs` | SM → Orchestrator → Tech Writer → SM |

| Command | Agent |
|---------|-------|
| `/sm` | Scrum Master (story management) |
| `/tea` | Test Engineer/Architect |
| `/dev` | Developer |
| `/reviewer` | Code Reviewer |
| `/architect` | System design |
| `/pm` | Product Manager |
| `/tech-writer` | Documentation |
| `/ux-designer` | UX design |
| `/devops` | Infrastructure and deployment |
| `/orchestrator` | Multi-agent coordination |
| `/ba` | Business Analyst (requirements discovery) |

**Sprint:** `/sprint status`, `/sprint backlog`, `/sprint work`

**Subagents** (via Task tool with `subagent_type`): `sm-setup`, `sm-finish`, `sm-handoff`, `testing-runner`, `handoff`, `reviewer-preflight`

**Handoff protocol:** Agent completes work → spawns subagent → subagent updates session → next agent reads state and continues.
</info>

<info>
## Framework Structure (inside `pennyfarthing/`)

| Directory | Purpose |
|-----------|---------|
| `pennyfarthing-dist/` | Published package (source of truth) — agents, commands, guides, skills, personas, workflows, scripts |
| `packages/core/` | Main package (`@pennyfarthing/core`) — CLI, server (WheelHub), API routes, shared utilities (theme-loader, portrait-resolver, markers) |
| `packages/cyclist/` | Visual terminal (Electron, React 19, Tailwind v4, shadcn/ui, dockview panels) — thin wrapper over core server |
| `packages/shared/` | **Deprecated** — absorbed into `packages/core/src/shared/` (story 98-16). Kept for backward compat |
| `packages/benchmark/` | Performance benchmarking and persona evaluation |
| `packages/themes-*/` | Theme packages (comedy, literary, mythology-fantasy, prestige-tv, realistic, scifi, superheroes) |
| `pennyfarthing_scripts/` | Distributed Python package (hooks, jira, sprint, story, prime) |
| `tests/` | Framework tests |

**Migration (98-16/17/18):** Shared utilities and WheelHub server moved into core. Cyclist is now a thin wrapper adding WebSocket + OTLP. Import shared utils from `packages/core/src/shared/`.

**Key files:**

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/agents/*.md` | Agent and subagent definitions |
| `.pennyfarthing/config.local.yaml` | Theme, bell_mode, relay_mode, permission_mode |
| `.session/{story-id}-session.md` | Active work context |
| `pennyfarthing-dist/guides/` | Behavior guides and component docs |
</info>

<info>
## Cyclist (Visual Terminal)

Electron app: React 19, Tailwind v4, shadcn/ui, dockview-react panels.

**Codenames:** WheelHub (server — `packages/core/src/server/`), TirePump (context clearing), JobFair (benchmarking), BikeRack (standalone panel viewer)

**Key components:** `DockviewWorkspace.tsx` (layout), `MessageView.tsx` (conversation), `ToolCallBlock.tsx` / `ToolStack.tsx` (tool visualization), `QuickActions.tsx` (Reflector marker detection)

**BikeRack:** Standalone panel viewer mode — Dockview layout with `?panel=X` routing, `--project-dir` for decoupled launch. Key files: `bikerack.ts` (entry), `BikeRackWorkspace.tsx` (layout), `StandalonePanel.tsx` (routing)

**Panels:** MessagePanel (sacred center), ProgressPanel, ChangedPanel, DiffsPanel, SprintPanel, BikeLanePanel, ACPanel, AcceptanceCriteriaPanel, SettingsPanel, DebugPanel, GitPanel, BackgroundPanel, TodoPanel, AuditLogPanel, WorkflowPanel, HotspotsPanel
</info>

<context>
## Component Guides

For detailed behavior, key files, configuration, and APIs for each Cyclist component:

| Component | What it is | Guide |
|-----------|-----------|-------|
| **BikeLane** | Workflow engine — phased, stepped, and procedural workflow orchestration | `pennyfarthing/pennyfarthing-dist/guides/bikelane.md` |
| **BikeRack** | Standalone panel viewer for CLI-first development — WheelHub without Cyclist UI | `pennyfarthing/pennyfarthing-dist/guides/bikerack.md` |
| **Gates** | Conditional checks blocking phase transitions until quality thresholds are met | `pennyfarthing/pennyfarthing-dist/guides/gates.md` |
| **Handoff CLI** | Phase gate resolution, session transitions, and marker generation | `pennyfarthing/pennyfarthing-dist/guides/handoff-cli.md` |
| **Hooks** | Claude Code hook system — session start, pre/post tool use, git hooks | `pennyfarthing/pennyfarthing-dist/guides/hooks.md` |
| **Bell Mode** | Message queue injection via PostToolUse hook — queue messages while Claude works | `pennyfarthing/pennyfarthing-dist/guides/bell-mode.md` |
| **Relay Mode** | Automatic agent handoff execution — skips user confirmation on HANDOFF markers | `pennyfarthing/pennyfarthing-dist/guides/relay-mode.md` |
| **TirePump** | Context clearing system — resets Claude session, reloads agent with fresh context | `pennyfarthing/pennyfarthing-dist/guides/tirepump.md` |
| **Prime** | Agent activation system — bootstraps agents with tiered context (identity, workflow, session) | `pennyfarthing/pennyfarthing-dist/guides/prime.md` |
| **Reflector** | Agent-to-UI protocol — `<!-- CYCLIST:TYPE:value -->` markers drive QuickActions buttons | `pennyfarthing/pennyfarthing-dist/guides/reflector.md` |
| **Tandem Protocol** | Background observer pairing and consultation protocol for agent collaboration | `pennyfarthing/pennyfarthing-dist/guides/tandem-protocol.md` |
| **Output Styles** | Configurable response modes (terse, verbose, teaching) | `pennyfarthing/pennyfarthing-dist/guides/output-styles.md` |
| **Brownfield Tools** | Codebase analysis — hotspots, complexity, dead code, dependencies, health score | `pennyfarthing/pennyfarthing-dist/guides/brownfield-tools.md` |
| **Benchmarks (JobFair)** | Persona evaluation — OCEAN trait correlation with agent task performance | `pennyfarthing/packages/benchmark/docs/benchmarks-guide.md` |
</context>
