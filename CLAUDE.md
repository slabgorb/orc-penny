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

1. **Never edit `.pennyfarthing/` symlinked directories** — they point to node_modules
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
5. **Commit `dist/`** alongside `src/` changes
6. **Scripts use `.pennyfarthing/` paths** — never `pennyfarthing-dist/` in runtime scripts
</critical>

<code-editing>
Never edit files inside `node_modules/` or symlink targets. Trace symlinks back to the actual source repo (`pennyfarthing/pennyfarthing-dist/`) and edit there.
</code-editing>

<git-operations>
Commit format: `<type>(<scope>): <subject>`

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
| `.pennyfarthing/` | Runtime framework (symlinks to node_modules) — agents, guides, personas, scripts, workflows |
| `.pennyfarthing/sidecars/` | Agent learning files (local, writable, NOT symlinked) |
| `pennyfarthing/` | Inlined framework source repo |
| `sprint/` | Sprint tracking — `current-sprint.yaml`, `future.yaml`, `completed.yaml`, `context/` |
| `.session/` | Active work sessions |
| `docs/` | Documentation — `adr/` (Architecture Decision Records), `planning/` |
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
| `trivial` | SM → Dev → Reviewer → SM |
| `bdd` | SM → UX → TEA → Dev → Reviewer → SM |
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

**Sprint:** `/sprint status`, `/sprint backlog`, `/sprint work`

**Subagents** (via Task tool with `subagent_type`): `workflow-status-check`, `sm-setup`, `sm-finish`, `sm-handoff`, `testing-runner`, `handoff`, `reviewer-preflight`

**Handoff protocol:** Agent completes work → spawns subagent → subagent updates session → next agent reads state and continues.
</info>

<info>
## Framework Structure (inside `pennyfarthing/`)

| Directory | Purpose |
|-----------|---------|
| `pennyfarthing-dist/` | Published package (source of truth) — agents, commands, guides, skills, personas, workflows, scripts |
| `packages/core/` | Main package (`@pennyfarthing/core`) — CLI: init, update, doctor, uninstall |
| `packages/cyclist/` | Visual terminal (Electron, React 19, Tailwind v4, shadcn/ui, dockview panels) |
| `packages/shared/` | Shared utilities (portrait resolution, YAML helpers, marker detection) |
| `packages/themes-*/` | Theme packages (comedy, literary, mythology-fantasy, prestige-tv, realistic, scifi, superheroes) |
| `pennyfarthing_scripts/` | Distributed Python package (hooks, jira, sprint, story, prime) |
| `tests/` | Framework tests |

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

**Codenames:** WheelHub (server — `packages/cyclist/src/server.ts`), TirePump (context clearing), JobFair (benchmarking)

**Key components:** `DockviewWorkspace.tsx` (layout), `MessageView.tsx` (conversation), `ToolCallBlock.tsx` / `ToolStack.tsx` (tool visualization), `QuickActions.tsx` (Reflector marker detection)

**Panels:** MessagePanel (sacred center), ChangedPanel, DiffsPanel, SprintPanel, ProgressPanel, BikeLanePanel, AcceptanceCriteriaPanel, SettingsPanel, DebugPanel, GitPanel, BackgroundPanel, TodoPanel, AuditLogPanel, TTYPanel, WorkflowPanel
</info>

<context>
## Component Guides

For detailed behavior, key files, configuration, and APIs for each Cyclist component:

| Component | What it is | Guide |
|-----------|-----------|-------|
| **Bell Mode** | Message queue injection via PostToolUse hook — queue messages while Claude works | `pennyfarthing/pennyfarthing-dist/guides/bell-mode.md` |
| **Relay Mode** | Automatic agent handoff execution — skips user confirmation on HANDOFF markers | `pennyfarthing/pennyfarthing-dist/guides/relay-mode.md` |
| **TirePump** | Context clearing system — resets Claude session, reloads agent with fresh context | `pennyfarthing/pennyfarthing-dist/guides/tirepump.md` |
| **Prime** | Agent activation system — bootstraps agents with tiered context (identity, workflow, session) | `pennyfarthing/pennyfarthing-dist/guides/prime.md` |
| **Reflector** | Agent-to-UI protocol — `<!-- CYCLIST:TYPE:value -->` markers drive QuickActions buttons | `pennyfarthing/pennyfarthing-dist/guides/reflector.md` |
| **Benchmarks (JobFair)** | Persona evaluation — OCEAN trait correlation with agent task performance | `pennyfarthing/pennyfarthing-dist/guides/benchmarks.md` |
| **BikeLane** | Workflow engine — phased, stepped, and procedural workflow orchestration | `pennyfarthing/pennyfarthing-dist/guides/bikelane.md` |
</context>
