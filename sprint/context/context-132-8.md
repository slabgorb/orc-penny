# Context: 132-8 Create root README.md with 4-step quick start

## Goal
Give a new developer who just cloned the orchestrator repo a clear, opinionated front door: what this repo is, how to get running in four commands, and where things live. Replace the current README.md which is overly detailed and buries the quick start under prerequisites and structural documentation.

## Technical Approach
- Rewrite `README.md` at project root — keep it short and scannable
- Lead with the 4-step quick start (clone, setup, claude, guided-tour) above the fold
- Add a brief directory map — just enough to stop the "what are all these folders" question
- Mention the two-repo architecture in 2-3 sentences, not a full table
- Link out to `pennyfarthing/docs/GETTING-STARTED.md` for framework-level details — do not duplicate it
- Link out to `docs/adr/README.md` for architecture decisions
- Remove or collapse sections that belong in other docs (agent workflow tables, sprint CLI reference, ADR summaries)

## Content Plan

### 1. Header + one-liner
Project name, one sentence: "Sprint orchestrator and agent coordination for Pennyfarthing framework development."

### 2. Quick Start (the 4 steps)
```bash
git clone git@github.com:1898andCo/orc-penny.git && cd orc-penny
just setup        # clones pennyfarthing/, installs deps, builds
just claude       # launches Claude Code with OTEL pre-configured
/guided-tour      # interactive walkthrough inside Claude Code
```
Prerequisites listed inline: Node 18+, pnpm 9+, Python 3.11+, just, Claude Code CLI, SSH access to 1898andCo.

### 3. What's in this repo (compact directory table)
One-level deep, ~8 rows:
- `.pennyfarthing/` — runtime framework (symlinks, don't edit directly)
- `pennyfarthing/` — inlined framework source (separate git repo)
- `sprint/` — sprint tracking YAML and context files
- `docs/` — ADRs and research
- `justfile` — task runner (run `just` to see all commands)
- `CLAUDE.md` — agent instructions (read by Claude Code automatically)

### 4. Two repos, briefly
This repo is trunk-based on `main`. The `pennyfarthing/` directory is a separate git repo using gitflow on `develop`. Orchestrator commits stay here; framework commits go into `pennyfarthing/`.

### 5. Next steps / links
- `/guided-tour` for an interactive walkthrough
- `pennyfarthing/docs/GETTING-STARTED.md` for framework development
- `docs/adr/README.md` for architecture decisions
- `just --list` for all available commands

### What to remove from current README
- Agent workflow table (belongs in guides or CLAUDE.md)
- Sprint CLI reference (covered by `pf sprint --help` and guided tour)
- ADR summary list (linked, not inlined)
- Common commands block (replaced by `just --list` pointer)
- Related repositories table (niche, can live in docs)

## Key Files
- `README.md` — file to rewrite (exists, 154 lines currently)
- `justfile` — reference for `setup` and `claude` recipes
- `pennyfarthing/docs/GETTING-STARTED.md` — link target, do not duplicate
- `docs/adr/README.md` — link target
- `.pennyfarthing/skills/guided-tour/` — the `/guided-tour` skill invoked in step 4

## Dependencies
- 132-7 (MSSCI-15642) delivered — `/guided-tour` skill exists and works
- `just setup` recipe exists and bootstraps from scratch
- `just claude` recipe exists and launches with OTEL

## Acceptance Criteria
- `README.md` exists at repo root and is under 80 lines
- Quick start section shows exactly 4 commands (clone, setup, claude, /guided-tour)
- Prerequisites are listed but do not dominate — no more than 1-2 lines
- Directory table covers top-level dirs without going deeper than one level
- Two-repo architecture mentioned in 2-3 sentences, not a full table
- No duplication of content from `pennyfarthing/docs/GETTING-STARTED.md`
- No agent workflow tables, sprint CLI docs, or ADR summaries inlined
- Links to GETTING-STARTED.md, ADR index, and `just --list` are present
