# DevOps Agent Patterns

<pattern name="hook-paths">
Use `$CLAUDE_PROJECT_DIR` for hook commands in settings.local.json. Don't use `git rev-parse --show-toplevel` (wrong root in nested repos).
</pattern>

<pattern name="just-commands">
`just test`, `just lint`, `just build`, `just dev` — standard project commands.
</pattern>

<pattern name="npm-git-install" status="DEPRECATED">
OBSOLETE — npm install of pennyfarthing is no longer used. See `pf-init-install` pattern.
</pattern>

<pattern name="pf-init-install">
Consumer projects install pennyfarthing via `pf init <target-dir>`. This copies content dirs (agents, guides, personas, workflows, etc.) from the pf CLI's bundled dist root. No npm, no git submodules. Re-run `pf init` to update.

**Global install:** `pipx install <path-to-pennyfarthing-source>` (e.g. `pipx install ~/Projects/pf-1/pennyfarthing/`). Not on PyPI — must install from local source. The direnv-local version takes precedence inside dev repos.
</pattern>

<pattern name="consumer-projects">
Consumer orchestrator repos in ~/Projects:
- **co-1**, **co-2**, **co-3** — all use pennyfarthing in orchestrator mode
- Install method: `pf init` (Python CLI copies content dirs)
- WheelHub is self-contained (`wheelhub.mjs` ~1.8MB, fully bundled) — NO npm install needed
- Portraits centralized to `~/.local/share/pennyfarthing/portraits/` (symlinked per project)
- `pf init` auto-cleans: stale npm deps from package.json, old symlinks, duplicate settings, preferences.yaml
- `@pennyfarthing/core` npm dep and node_modules/@pennyfarthing are legacy — cleaned by pf init
</pattern>

<pattern name="portrait-centralization">
Portraits live in `~/.local/share/pennyfarthing/portraits/` (XDG_DATA_HOME).
- Source: pip-installed `pf._dist` has real PNGs; dev source tree has LFS pointers
- `pf init` copies once, creates `.pennyfarthing/personas/portraits` → symlink
- Version-stamped manifest at `.manifest.json` prevents re-copy
- TypeScript resolvers (portrait-resolver.ts, paths.ts) check XDG path first
- Run `git lfs pull` in pennyfarthing/ to resolve dev-env LFS pointers
</pattern>

<pattern name="python-hook-wrapper">
Shell wrapper → `find-root.sh` → set PYTHONPATH (dogfooding or node_modules) → `python3 -m pennyfarthing_scripts.<module>`. Don't use relative `../../..` traversal.
</pattern>

<pattern name="bikerack-architecture">
BikeRack is the integration layer between Claude Code, WheelHub (Node server), and the TUI/GUI.

**Components:**
- **WheelHub** — Node Express server (`wheelhub.mjs`), serves dashboard + receives OTEL on same HTTP port
- **OTEL** — Claude Code sends spans/logs/metrics to `http://localhost:{port}/v1/*`
- **TUI** — Python terminal UI, connects to WheelHub via HTTP/WS
- **GUI** — React browser UI (Cyclist/dockview), connects to WheelHub

**Port/PID files** (project root, gitignored):
- `.bikerack-port` — HTTP port (default 2898, range 2898-2907), dot-prefixed
- `bikerack-pid` — WheelHub Node process PID, no dot prefix
- `bikerack-tui-pid` — TUI process PID, no dot prefix
- OTEL endpoint = same port as dashboard (no separate OTEL port)

**Startup chain:**
1. `just wheelhub` → checks running, stops if needed, starts WheelHub, writes `bikerack.port` + `bikerack.pid`
2. `just claude` → reads `bikerack.port`, sets OTEL env vars, execs claude
3. `just tui` / `just gui` → reads `bikerack.port`, connects to WheelHub

**Key files:**
- Node entry: `pennyfarthing/packages/core/src/server/entry.ts` (PORT_FILE const, findAvailablePort)
- Python launcher: `pennyfarthing/pennyfarthing-dist/src/pf/bikerack/launcher.py` (write_port_file, write_pid_file)
- Justfile: `.pennyfarthing/justfile.pf` (distributed recipes, source at pennyfarthing-dist)
- Health check: `GET /health` → `{status: 'ok'}`
</pattern>

<pattern name="wheelhub-bundle-rebuild">
WheelHub bundle rebuild: `cd pennyfarthing && ./scripts/build-wheelhub.sh [--install]`
Prereq: `cd packages/core && pnpm run build:tsc` (if source changed).
The script handles esbuild, CJS shim patching, validation, and copy to pennyfarthing-dist.
`--install` flag also runs `pipx install --force`. Then `pf init` in consumer projects.
</pattern>
