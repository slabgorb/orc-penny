# orc-penny

Sprint orchestrator and agent coordination for [Pennyfarthing](https://github.com/1898andCo/pennyfarthing) framework development.

## Quick Start

```bash
git clone git@github.com:1898andCo/orc-penny.git && cd orc-penny
just setup        # clones pennyfarthing/, installs deps, builds
just claude       # launches Claude Code with OTEL pre-configured
/guided-tour      # interactive walkthrough inside Claude Code
```

Prerequisites: Node 18+, [pnpm](https://pnpm.io/) 9+, Python 3.11+, [just](https://github.com/casey/just), [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI, Git SSH access to `1898andCo`.

## What's in this repo

| Directory | Purpose |
|-----------|---------|
| `pennyfarthing/` | Framework source (separate git repo, own history) |
| `sprint/` | Sprint tracking YAML, context files, archives |
| `docs/` | ADRs and research |
| `.pennyfarthing/` | Runtime framework (symlinks — don't edit directly) |
| `CLAUDE.md` | Agent instructions (read by Claude Code automatically) |
| `justfile` | Task runner — run `just` to see all commands |

## Two repos

This workspace contains two git repos. The orchestrator (`orc-penny/`) is trunk-based on `main` — sprint files, sessions, docs. The framework (`pennyfarthing/`) uses gitflow on `develop` — source code, packages, tests. Orchestrator commits stay here; framework commits go into `pennyfarthing/`.

## Benchmark Dashboard

Pipeline replay benchmark results with interactive D3.js visualization:

```bash
python3 scripts/benchmark-viz-data.py   # regenerate data
open internal/results/benchmark-dashboard.html
```

Or serve it: `cd internal/results && python3 -m http.server 8765` then visit `http://localhost:8765/benchmark-dashboard.html`

## Learn more

- `/guided-tour` — interactive walkthrough inside Claude Code
- [Getting Started](pennyfarthing/docs/GETTING-STARTED.md) — framework development guide
- [Architecture Decisions](docs/adr/README.md) — ADR index
- `just --list` — all available commands
