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

<pattern name="frame-architecture">
Frame is the Python FastAPI server that connects Claude Code, the TUI, and the GUI.

**Components:**
- **Frame** — Python FastAPI server (`pf frame start`), serves API + WebSocket + OTEL ingestion
- **OTEL** — Claude Code sends spans/logs/metrics to `http://localhost:{port}/v1/*`
- **TUI** — Python Textual terminal UI, connects to Frame via WebSocket
- **GUI** — React browser UI (Cyclist/dockview), connects to Frame

**Port/PID files** (project root, dot-prefixed, gitignored):
- `.frame-port` — HTTP port
- `.frame-pid` — Frame server process PID

**Startup:** `pf frame start` handles everything (port selection, PID file, OTEL endpoint).

**Key files:**
- Python server: `pennyfarthing/pennyfarthing-dist/src/pf/frame/` (FastAPI routes, WebSocket, OTEL)
- Justfile: `.pennyfarthing/justfile.pf` (distributed recipes, source at pennyfarthing-dist)
- Health check: `GET /health` → `{status: 'ok'}`
</pattern>
