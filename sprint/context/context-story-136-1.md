---
parent: context-epic-136.md
workflow: tdd
---

# Story 136-1: Unified pf discovery — fix PATH resolution in hooks, launchers, and setup

## Business Context

Every pip/pipx/uv consumer of Pennyfarthing hits the same silent failure on first install: Claude Code hooks do nothing. The hooks are written as bare `pf hooks <name>` commands in `settings.local.json`, but Claude Code executes hooks in a subprocess whose PATH does not include `~/.local/bin` (pipx/pip) or `~/.local/share/uv/tools/*/bin` (uv). The hooks fail silently, meaning session-start setup never runs, bell-mode injection never fires, pre-edit protections are absent, and the status line is blank. The user sees no error — the framework just appears broken.

This story creates a single discovery mechanism that resolves `pf` to an absolute path at init time and writes that absolute path into all hook commands. This is the P1 foundation for the rest of Epic 136 — stories 136-2 and 136-3 depend on the discovery function introduced here.

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/common/discovery.py` | **New file.** Single `resolve_pf_binary()` function that probes a prioritized list of candidate paths, returns the absolute path to the `pf` executable, and caches the result. This is the canonical discovery function used by all other consumers. |
| `pennyfarthing-dist/src/pf/common/hooks.py` | Replace bare `pf hooks <name>` strings in `INFRASTRUCTURE_HOOKS` with a function that templates in the absolute path from `resolve_pf_binary()`. Bare `pf` becomes a fallback only when discovery returns `None`. |
| `pennyfarthing-dist/src/pf/init/core.py` | Update `verify_pf_cli()` to use `resolve_pf_binary()` instead of `shutil.which("pf")`. Update `init_project()` to resolve the absolute pf path at init time and write it into `settings.local.json` hook commands. |
| `pennyfarthing-dist/scripts/hooks/session-start.sh` | Replace `exec pf hooks session-start` with a resolver shim pattern that enriches PATH or calls the absolute binary. |
| `pennyfarthing-dist/scripts/hooks/session-stop.sh` | Same resolver shim treatment. |
| `pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` | Same resolver shim treatment. |
| `pennyfarthing-dist/scripts/hooks/pre-edit-check.sh` | Same resolver shim treatment. |
| `pennyfarthing-dist/scripts/hooks/context-warning.sh` | Same resolver shim treatment. |
| `pennyfarthing-dist/src/pf_launcher.py` | Minor: after resolving the local source, also export the resolved pf binary path as an environment variable so child processes inherit it. |
| `packages/core/src/cli/utils/python.ts` | Update `getPfVersion()` to check absolute candidate paths (`~/.local/bin/pf`, uv tool dirs) before falling back to bare `spawnSync('pf', ...)`. |

### Key Files to Consume (Read-Only)

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/src/pf/common/config.py` | `get_project_root()` and `get_dist_root()` — 5-step resolution strategies. Discovery function should follow the same layered approach. |
| `packages/core/src/cli/utils/python.ts` | Node-side pf detection patterns to keep consistent. |
| `.claude/settings.local.json` | Understand the hook command structure that init writes. |
| `pennyfarthing-dist/src/pf/common/hooks.py` | Current `INFRASTRUCTURE_HOOKS` dict structure (static strings). |

### Patterns to Follow

- **Result-object pattern:** `resolve_pf_binary()` must return `{success, data?, error?}` with `data` containing `path` (absolute) and `install_method` (pip/pipx/uv/monorepo)
- **Layered resolution (same as `get_project_root`):** environment override first, then specific probes, then `shutil.which()` fallback
- **Idempotent init:** Running `pf init` twice must produce identical `settings.local.json` content regardless of whether the binary path changed between runs
- **Shell shim resolver pattern:** Each `.sh` hook shim should source a common `_resolve-pf.sh` helper that enriches PATH or resolves the absolute binary, avoiding duplicated logic across 5+ shims
- **No external dependencies:** Discovery runs at import time in some paths; must use only stdlib (pathlib, shutil, os, subprocess)
- **Python 3.10+ only** — `match`/`case` and `X | Y` union syntax are acceptable

### What NOT to Touch

- `pennyfarthing-dist/src/pf/common/config.py` (`get_dist_root`) — read-only dependency; do not change its resolution logic
- WheelHub path resolution (that is story 136-2)
- Init/doctor prefix filtering (that is story 136-3)
- TUI color thresholds (that is story 136-4)
- TUI data pipeline (that is story 136-5)
- The `pf_launcher.py` CWD walk-up logic for finding project-local `pf/cli.py` — that mechanism is correct; only add the PATH export
- Hook shim files not listed above (e.g., `cyclist-pretooluse-hook.sh`, `schema-validation.sh`) — address in a follow-up if needed

## Scope Boundaries

**In scope:**
- New `resolve_pf_binary()` discovery function in `pf.common.discovery`
- Probe chain: `PF_BINARY` env var, `~/.local/bin/pf` (pip/pipx), `~/.local/share/uv/tools/*/bin/pf` (uv), `shutil.which("pf")` fallback, monorepo direct path
- Rewrite `INFRASTRUCTURE_HOOKS` to use absolute paths from discovery
- `pf init` writes resolved absolute paths into `settings.local.json` hook commands
- Common `_resolve-pf.sh` shell helper sourced by all hook shims
- Update all 5 hook shim `.sh` files to use the common resolver
- `pf_launcher.py` exports `PF_BINARY` env var for child processes
- Node-side `getPfVersion()` checks absolute candidate paths
- Tests for all install-method scenarios (pip, pipx, uv, monorepo)
- Error reporting when `pf` cannot be found (clear message with install hint)

**Out of scope:**
- WheelHub `PACKAGE_ROOT` and monorepo path traversals (136-2)
- Bundling commands/skills into pip `_dist/` package (136-3)
- TUI color thresholds or data pipeline fixes (136-4, 136-5)
- Automatic reinstallation or auto-upgrade of pf
- Windows support (macOS and Linux only)
- Changing the `pf_launcher.py` CWD walk-up source resolution logic

## AC Context

### AC1: Discovery resolves pf for pip user install

**Given** pf is installed via `pip install --user pennyfarthing-pf` with the binary at `~/.local/bin/pf`
**When** `resolve_pf_binary()` is called
**Then** it returns `{success: True, data: {path: "/home/user/.local/bin/pf", install_method: "pip"}}`

**Edge cases:**
- `~/.local/bin` exists but `pf` is not there — falls through to next probe
- `~/.local/bin/pf` exists but is not executable — skipped, falls through
- `HOME` env var is not set — uses `Path.home()` fallback

### AC2: Discovery resolves pf for pipx install

**Given** pf is installed via `pipx install pennyfarthing-pf` with a symlink at `~/.local/bin/pf` pointing into the pipx venv
**When** `resolve_pf_binary()` is called
**Then** it returns `{success: True, data: {path: "/home/user/.local/bin/pf", install_method: "pipx"}}`

**Edge cases:**
- Symlink exists but target venv is deleted (stale shim) — discovery resolves the path, but `verify_pf_cli()` catches the broken shim via `pf --version` execution check
- pipx ensurepath was not run — `~/.local/bin/pf` still exists on disk even if not on interactive PATH

### AC3: Discovery resolves pf for uv tool install

**Given** pf is installed via `uv tool install pennyfarthing-pf` with the binary at `~/.local/share/uv/tools/pennyfarthing-pf/bin/pf`
**When** `resolve_pf_binary()` is called
**Then** it returns `{success: True, data: {path: "/home/user/.local/share/uv/tools/pennyfarthing-pf/bin/pf", install_method: "uv"}}`

**Edge cases:**
- Multiple uv tool versions exist — picks the first match by glob order
- uv uses `pennyfarthing-scripts` as the package name — glob pattern must match both `pennyfarthing-pf` and `pennyfarthing-scripts` directory names
- `~/.local/share/uv/tools/` directory does not exist — skipped, falls through

### AC4: Discovery resolves pf in monorepo development layout

**Given** the developer is working in the pennyfarthing monorepo with `pennyfarthing-dist/src/pf/cli.py` present
**When** `resolve_pf_binary()` is called
**Then** it returns `{success: True, data: {path: "<abs-path>/pennyfarthing-dist/src/pf_launcher.py", install_method: "monorepo"}}`
**Or** if the global pf is also installed, it may return the global binary with the correct install method

**Edge cases:**
- Both monorepo source and global pip install exist — environment override (`PF_BINARY`) takes precedence; without override, the globally installed binary is preferred (since it is what hooks will actually call)
- Orchestrator layout (`pennyfarthing/pennyfarthing-dist/`) — detected correctly via the same walk-up that `_find_local_src()` uses

### AC5: PF_BINARY environment override

**Given** the `PF_BINARY` environment variable is set to `/opt/custom/bin/pf`
**When** `resolve_pf_binary()` is called
**Then** it returns `{success: True, data: {path: "/opt/custom/bin/pf", install_method: "env_override"}}`
**And** no further probing occurs

**Edge cases:**
- `PF_BINARY` points to a nonexistent file — returns `{success: False, error: "PF_BINARY set to /opt/custom/bin/pf but file does not exist"}`
- `PF_BINARY` points to a directory — returns error with clear message

### AC6: Discovery failure with actionable error

**Given** pf is not installed by any method and `PF_BINARY` is not set
**When** `resolve_pf_binary()` is called
**Then** it returns `{success: False, error: "pf CLI not found", install_hint: "pipx install pennyfarthing-pf"}`
**And** the error includes all locations that were probed

### AC7: Hook commands use absolute paths after init

**Given** pf is installed via pipx at `~/.local/bin/pf`
**When** `pf init` runs
**Then** `.claude/settings.local.json` contains hook commands like `"/home/user/.local/bin/pf" hooks session-start` (quoted absolute path) instead of bare `pf hooks session-start`
**And** the `statusLine` command also uses the absolute path

**Edge cases:**
- Re-running `pf init` after upgrading pf (new binary path) — the path is re-resolved and updated
- Running `pf init` with `--dry-run` — shows the resolved path in the plan but does not write it

### AC8: Hook shell shims use common resolver

**Given** the file `pennyfarthing-dist/scripts/hooks/_resolve-pf.sh` exists as a common resolver
**When** any hook shim (e.g., `session-start.sh`) is invoked by Claude Code
**Then** it sources `_resolve-pf.sh` which enriches PATH with known install locations (`~/.local/bin`, uv tool dirs) before calling `pf`
**And** if `PF_BINARY` env var is set, it is used directly without PATH manipulation

**Edge cases:**
- `_resolve-pf.sh` is not found (e.g., stale install) — shim falls back to bare `pf` (same as current behavior, no regression)
- Shim runs in a restricted shell — PATH enrichment uses `export PATH=...` not `source ~/.bashrc`

### AC9: pf_launcher exports PF_BINARY for child processes

**Given** a user runs `pf hooks session-start` directly (interactive shell)
**When** `pf_launcher.py` resolves and launches the CLI
**Then** it sets `PF_BINARY` in `os.environ` to its own absolute path (via `sys.argv[0]` resolved or `shutil.which('pf')`)
**And** any child process spawned by the CLI (e.g., subagent) can read `PF_BINARY`

### AC10: Node-side detection uses absolute path probing

**Given** `pf` is installed via uv and not on the subprocess PATH
**When** `getPfVersion()` in `python.ts` is called
**Then** it checks `~/.local/bin/pf` and `~/.local/share/uv/tools/*/bin/pf` before falling back to bare `spawnSync('pf', ...)`
**And** returns the version string if found at any probe location

### AC11: Backward compatibility with existing settings.local.json

**Given** a project with an existing `settings.local.json` containing bare `pf hooks <name>` commands (written by a previous version)
**When** `pf init` is run (upgrade path)
**Then** the bare `pf` commands are upgraded to absolute-path commands
**And** any user-added custom hooks (not matching `pf hooks`) are preserved unchanged
**And** the hook upgrade logic in `_upgrade_hooks()` handles both bare and absolute-path patterns

**Edge cases:**
- Mixed state: some hooks already have absolute paths, others are bare — both are handled correctly
- User manually edited a hook command — if it does not match the `pf hooks` pattern, it is left untouched
