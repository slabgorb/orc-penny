# Epic 136: Post-install Reliability — Fix Consumer-Facing Bugs from Python-First Migration

## Overview

Five root causes account for 18 of 30 open issues across pennyfarthing and orc-penny consumer installs. All stem from the migration to a Python-first distribution (`pip`/`pipx`/`uv tool install`) while the codebase retains monorepo path assumptions from the original npm layout. This epic fixes PATH resolution for the `pf` binary, removes hardcoded monorepo traversals in WheelHub, corrects init/doctor filtering for the Python dist layout, extracts duplicated TUI color thresholds, and adds proper fallback handling to the TUI data pipeline.

**Why now:** Every pip consumer hits at least one of these bugs on first install. The Python-first migration (epic 125) shipped the distribution mechanism but left the runtime wiring assuming monorepo paths. These are P1 reliability issues blocking adoption.

## Background

### Current State

The `pf` CLI is distributed as a Python package (`pennyfarthing-pf`) installable via pip, pipx, or uv. The package entry point is `pf_launcher.py`, which walks up from CWD to find a project-local `pf/cli.py` and delegates to it. This launcher works when `pf` is on the user's interactive shell PATH, but three classes of failure emerge in non-interactive contexts:

1. **PATH failures** — Claude Code hooks execute in a subprocess whose PATH does not include `~/.local/bin` (pipx) or `~/.local/share/uv/tools/*/bin` (uv). Every hook is a bare `pf hooks <name>` command that silently fails when `pf` is not discoverable.

2. **Monorepo path assumptions** — WheelHub (the Node.js panel server), context API routes, and the BikeRack launcher all compute paths by traversing `../../../` from `__file__` or `__dirname`, expecting to reach a monorepo root. In a pip-installed layout, these traversals land in `site-packages/` and every path resolution fails.

3. **Distribution layout mismatches** — `pf init` and `pf doctor` assume `commands/` and `skills/` directories exist relative to a `pennyfarthing-dist/` root. The pip package's `_dist/` stub does not bundle these directories, so `init` copies nothing and `doctor` reports false positives.

Additionally, two TUI-layer issues predate the migration but are exacerbated by it:

4. **Color threshold duplication** — The green/yellow/red percentage bands (50/80) are copy-pasted across `base_panel.py`, `debug_panel.py`, and `context_meter_footer.py`. No shared constants exist.

5. **Data pipeline fragility** — TUI panels display "No data" placeholders indefinitely when WheelHub API endpoints fail (e.g., `context.py not found`). No retry, error distinction, or loading states exist. The WebSocket client stays CONNECTED while individual data channels produce no output.

### Install Methods and PATH Implications

| Install Method | Binary Location | In Interactive Shell PATH? | In Claude Code Hook PATH? |
|---------------|----------------|---------------------------|--------------------------|
| pip (user) | `~/.local/bin/pf` | Usually (if `--user`) | No |
| pipx | `~/.local/bin/pf` (symlink) | Yes (pipx ensurepath) | No |
| uv tool install | `~/.local/share/uv/tools/.../bin/pf` | Yes (uv adds shim) | No |
| Monorepo dev | `./pennyfarthing-dist/src/pf_launcher.py` | N/A (runs directly) | N/A |

### Monorepo vs Pip Layout

```
MONOREPO (development):                  PIP INSTALL (consumer):
pennyfarthing/                           site-packages/
├── pennyfarthing-dist/                    ├── pf/
│   ├── commands/pf-*.md                   │   ├── cli.py
│   ├── skills/pf-*/                       │   ├── common/
│   ├── src/pf/                            │   ├── init/
│   │   ├── cli.py                         │   ├── doctor/
│   │   ├── bikerack/                      │   ├── bikerack/
│   │   └── common/config.py               │   └── _dist/
│   └── src/pf_launcher.py                 │       └── __init__.py  (stub)
├── packages/core/                         ├── pf_launcher.py
│   ├── src/server/pennyfarthing.ts        └── pennyfarthing_pf-*.dist-info/
│   └── dist/server/entry.js
└── packages/cyclist/
```

The `_dist/` directory in the pip package is a stub with only `__init__.py`. It does not contain `commands/`, `skills/`, `agents/`, or `server/wheelhub.mjs`. This is the root cause for stories 136-2 and 136-3.

## Technical Architecture

### Story Map and Dependencies

```
136-1 (5pt, P1) PATH resolution
  ↓
136-2 (3pt, P1) WheelHub monorepo paths  ← depends on 136-1 for pf discovery
  ↓
136-3 (2pt, P2) init/doctor filtering     ← depends on 136-1 for dist_root resolution
136-4 (2pt, P2) TUI color extraction      ← independent
136-5 (3pt, P2) TUI data pipeline         ← partially depends on 136-2 (context.py resolution)
```

### Key Files by Story

#### 136-1: Unified pf Discovery (5pt)

| File | Purpose | Issue |
|------|---------|-------|
| `pennyfarthing-dist/src/pf_launcher.py` | Global entry point, CWD walk-up to find local `pf/cli.py` | Works standalone but PATH-dependent |
| `pennyfarthing-dist/src/pf/common/hooks.py` | `INFRASTRUCTURE_HOOKS` — writes bare `pf hooks <name>` commands into `settings.local.json` | No absolute path or PATH enrichment |
| `pennyfarthing-dist/scripts/hooks/session-start.sh` (and all hook shims) | `exec pf hooks <name>` — one-liner shell scripts | Bare `pf` call, no fallback |
| `pennyfarthing-dist/src/pf/init/core.py` (`verify_pf_cli`) | Detects install method (pipx/uv/pip) by string-matching resolved binary path | Detection works but result is not used for PATH enrichment |
| `packages/core/src/cli/utils/python.ts` | Node-side `pf` detection: `spawnSync('pf', ['--version'])`, fallback to `uv run pf` | No absolute-path resolution |

**Pattern:** Every consumer of `pf` assumes bare PATH resolution. The fix needs a single discovery function that resolves `pf` to an absolute path at init time, then writes that absolute path into hook commands and launcher configs.

#### 136-2: WheelHub Monorepo Paths (3pt)

| File | Purpose | Issue |
|------|---------|-------|
| `pennyfarthing-dist/src/pf/bikerack/launcher.py` (`_find_wheelhub_entry`) | Finds `entry.js` or `wheelhub.mjs` | 5-level parent traversal assumes monorepo; pip fallback `_dist/server/wheelhub.mjs` does not exist |
| `packages/core/src/server/pennyfarthing.ts` | `PACKAGE_ROOT = join(__dirname, '..', '..', '..')` | Assumes `dist/server/` sits inside monorepo `packages/core/` |
| `packages/core/src/server/paths.ts` (`resolvePennyfarthingDist`) | Multi-strategy path resolution (env var → Electron → walk-up → npm) | Robust but not used by `pennyfarthing.ts`'s `PACKAGE_ROOT` |
| `packages/core/src/server/api/context.ts` | Lists 4 hardcoded path candidates for `context.py` | Missing pip-installed site-packages path |

**Pattern:** `PACKAGE_ROOT` in `pennyfarthing.ts` must use `resolvePennyfarthingDist()` or equivalent. The BikeRack launcher must discover `wheelhub.mjs` from the pip package's bundled assets (which means the build must actually bundle it into `_dist/server/`).

#### 136-3: Init/Doctor Prefix Filtering (2pt)

| File | Purpose | Issue |
|------|---------|-------|
| `pennyfarthing-dist/src/pf/init/core.py` (`_find_pf_commands`, `_find_pf_skills`) | Globs `dist_root/commands/pf-*.md` and `dist_root/skills/pf-*` | `dist_root` resolves to pip `_dist/` which has no `commands/` or `skills/` |
| `pennyfarthing-dist/src/pf/common/config.py` (`get_dist_root`) | 5-step resolution: env var → monorepo → symlink → walk-up → pip `_dist` fallback | Pip fallback returns `_dist/` path but that directory is a stub |
| `pennyfarthing-dist/src/pf/doctor/checks.py` | `check_commands()`, `check_skills()`, `check_symlinks()`, `check_node_packages()` | Misleading labels (calls file copies "symlinks"); warns on missing `node_modules` even for pip-only installs |

**Pattern:** Either the pip build must bundle `commands/` and `skills/` into `_dist/`, or `get_dist_root()` must have a pip-specific strategy that locates these from the installed package's data files.

#### 136-4: TUI Color Thresholds (2pt)

| File | Purpose | Duplicated Pattern |
|------|---------|-------------------|
| `pennyfarthing-dist/src/pf/bikerack/base_panel.py` (`render_progress_bar`, lines 76-79) | Base progress bar | `if percent < 50: green elif <= 80: yellow else: red` |
| `pennyfarthing-dist/src/pf/bikerack/debug_panel.py` (`_render_sparkline`, lines 402-406) | Debug sparkline + context | Same thresholds, plus `_TIER_STYLES` dict with hardcoded Rich styles |
| `pennyfarthing-dist/src/pf/bikerack/context_meter_footer.py` (`_render_context_bar`, lines 254-259) | Footer context bar | Same thresholds |

**Note:** `base_panel.render_progress_bar` accepts a `fill_style` override, so callers like `ProgressPanel._render_burndown` bypass thresholds entirely. Extraction must preserve this override capability.

#### 136-5: TUI Data Pipeline (3pt)

| File | Purpose | Issue |
|------|---------|-------|
| `pennyfarthing-dist/src/pf/bikerack/debug_panel.py` | Subscribes to 2 WS channels (`context` + `token-stats`), own state management | Does not use `BasePanel.handle_message`; ignores error fields in WS messages; "No context data" placeholder is permanent |
| `pennyfarthing-dist/src/pf/bikerack/sprint_panel.py` | `Widget` (not `BasePanel`), own WS subscription | "Waiting for sprint data..." placeholder persists indefinitely on failure |
| `pennyfarthing-dist/src/pf/bikerack/context_meter_footer.py` | Placeholder `░░░░░░░░░░ --% ` bar | Never transitions from placeholder if context API fails |
| `pennyfarthing-dist/src/pf/bikerack/ws_client.py` | WS reconnection state machine (CONNECTED/DISCONNECTED/RECONNECTING) | Stays CONNECTED even when API endpoints fail server-side — no per-channel error signaling |
| `packages/core/src/server/api/context.ts` (`getContextUsage`) | Returns `{error: 'context.py not found', percent: null}` when script missing | Error response has no `context` key, so panel receives empty dict |

**Architectural constraint:** Three different subscription patterns exist:
- `BasePanel` — single channel, `handle_message` callback
- `DebugPanel` — dual channel, manual state management, `BasePanel` subclass that ignores base payload
- `SprintPanel` — `Widget` subclass, separate class hierarchy entirely

Any pipeline fix must handle all three without forcing a refactor of SprintPanel's class hierarchy.

### Cross-Epic Dependencies

- **Epic 125 (Python-first migration)** — Shipped the distribution mechanism. This epic fixes the runtime gaps it left.
- **Epic 133 (BikeRack TUI)** — Established the panel architecture. Stories 136-4 and 136-5 improve its reliability without changing the architecture.

### Constraints

- **No breaking changes to monorepo dev workflow** — All fixes must work in both monorepo (development) and pip-installed (consumer) layouts
- **Hook commands are static strings** — Written once by `pf init` into `settings.local.json`. If absolute paths change (e.g., user runs `pipx upgrade`), hooks break again. Consider a resolver shim.
- **WheelHub is optional** — pip-only consumers may not have Node.js. Stories 136-2 and 136-5 must degrade gracefully when WheelHub is unavailable.
- **Python 3.10+ required** — All TUI code uses `match`/`case` and `|` union types
- **Rich library for TUI styling** — Color constants must produce valid Rich style strings
