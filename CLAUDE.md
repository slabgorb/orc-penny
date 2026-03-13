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

**Handoff:** Agent writes assessment → `pf handoff resolve-gate` → `complete-phase` → `marker` → next agent activates.
</info>

<info>
## Framework Structure (`pennyfarthing/`)

**Architecture:** Python runtime + React GUI. Python owns CLI, server (Frame/FastAPI), hooks, and all business logic. TypeScript/React is GUI-only. See ADR-0034.

| Directory | Purpose |
|-----------|---------|
| `pennyfarthing-dist/` | Published package (source of truth) — agents, commands, guides, skills, personas, workflows, scripts |
| `pennyfarthing-dist/src/pf/` | Python package — CLI, Frame server (FastAPI), hooks, jira, sprint, workflow, prime |
| `pennyfarthing-dist/src/pf/frame/` | Python FastAPI server (OTLP, WebSocket, API routes) — replaces old Node.js server |
| `packages/core/` | `@pennyfarthing/core` — React GUI components, workflow engine, shared utilities |
| `packages/cyclist/` | React entry points (minimal — 3 files) |
| `packages/themes-*/` | Theme packages (comedy, literary, mythology-fantasy, prestige-tv, realistic, scifi, superheroes) |

**Display modes:** TUI panels render in three contexts:
- **TUI** — `pf frame start` launches panels alongside Claude Code CLI in the terminal
- **GUI** — Browser UI with full dockview panel layout
- **IDE** — VS Code / Cursor sidebar panels via Frame API

**Key files:**

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/agents/*.md` | Agent and subagent definitions |
| `.pennyfarthing/config.local.yaml` | Theme, bell_mode, relay_mode, permission_mode, statusbar |
| `.pennyfarthing/repos.yaml` | Repo topology — ownership, symlinks, branch strategy, never-edit zones |
| `.session/{story-id}-session.md` | Active work context |
| `pennyfarthing-dist/guides/` | Behavior guides and component docs |
</info>

<info>
## Glossary

| Term | Definition |
|------|------------|
| Peloton test | Repeatable benchmark scenario for a full agent team (TEA→Dev→Reviewer), sourced from real external review findings. Ground truth = what the pipeline actually missed. Run via `pf benchmark replay`. |
| Pipeline replay | The harness (`pf benchmark replay run/score/compare`) that executes peloton tests against real code at a known commit. |
| JobFair | Single-agent benchmarking — tests one role in isolation against a rubric. |
</info>

<context>
## Component Guides

See `pennyfarthing/CLAUDE.md` for the full Component Guides table. All guides live at `pennyfarthing/pennyfarthing-dist/guides/`.
</context>
