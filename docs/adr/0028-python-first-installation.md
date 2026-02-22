# ADR-0028: Python-First Installation

**Status:** Accepted
**Date:** 2026-02-22
**Author:** Architect (Zaphod Beeblebrox)
**Supersedes:** ADR-0027

## Context

ADR-0027 proposed a three-phase installation with Node as the primary package manager and Python deferred to a setup phase. That design preserved npm as the distribution channel for what is fundamentally a Python product — 260 files, 66K lines of Python, with a Click CLI as the primary interface.

The npm packaging layer has proven to be pure overhead:
- npm distributes Python code (wrong tool for the job)
- Postinstall scripts are untestable and fragile
- `workspace:*` refs leak if `pnpm publish` isn't used
- Two runtimes, two registries, two CI pipelines for one product
- The `pf` CLI is Python — Node is just a delivery truck

Meanwhile, the Python infrastructure is production-ready: pyproject.toml, setuptools entry point, lazy-loaded Click CLI, comprehensive test suite.

## Decision Drivers

- Eliminate npm as a distribution mechanism for Python code
- Global `pip install pf` from private PyPI — no uv, no pipx, no venv per project
- `pf init` handles everything: directory structure, config, Node package installation, auto-setup
- Node remains integral (BikeRack, Cyclist, WheelHub) but is a managed dependency, not the installer
- Electron is optional

## Decision

### Python is the installer. Node is a managed dependency.

**Installation:** `pip install pf` from private PyPI. The `pf` command is globally available.

**Bootstrap:** `pf init` in a project directory does everything:
1. Creates `.pennyfarthing/` and `.claude/` directory structure
2. Copies commands and skills (pf-* prefix)
3. Detects package manager (pnpm/yarn/npm), installs Node packages
4. Writes minimal `settings.local.json` (5 hooks)
5. Runs `/pf-setup` automatically — repo discovery, theme selection, git hooks
6. Updates `.gitignore`

**No two-phase install.** No setup-detector. No manifest flag. `pf init` is the complete experience.

### What's removed

| Component | Reason |
|-----------|--------|
| `npx pennyfarthing` entry point | Replaced by global `pf` command |
| `init.ts` (Node-based init) | Replaced by `pf init` (Python) |
| `setup-detector.js` | Unnecessary — setup runs during init |
| `session-start.js` | Python handles session start directly |
| `postinstall.cjs` | No npm postinstall needed |
| `run-pf.sh` / `pf.sh` wrapper chain | Global install — `pf` is just `pf` |
| uv dependency | Global pip install, no per-project venv |
| `@pennyfarthing/core` npm package | Python package `pf` on private PyPI |

### What stays

| Component | Role |
|-----------|------|
| Node/pnpm | BikeRack, Cyclist, WheelHub — installed by `pf init` |
| Frontmatter hooks | Self-contained agents and skills (ADR-0027 concept, still valid) |
| `config.local.yaml` | Single config file (ADR-0027 concept, still valid) |
| Click CLI (`pf`) | Primary interface, unchanged |

## Consequences

### Positive

- **One command to install:** `pip install pf`
- **One command to bootstrap:** `pf init`
- **One registry:** Private PyPI
- **One CI pipeline:** Python build + publish
- **Testable init:** Click command with unit tests, integration tests, `--dry-run`
- **No wrapper scripts:** Global `pf` replaces `pf.sh` → `run-pf.sh` → `uv run` chain
- **Node managed, not managing:** Python decides when and how Node packages are installed

### Negative

- **Breaking change:** Existing npm-based installs need migration via `pf upgrade`
- **Global install assumption:** All projects share one `pf` version (acceptable for team tooling)
- **Python required globally:** Must be on PATH (acceptable — macOS/Linux ship it, team controls environments)

## Related Decisions

- [ADR-0027: Installation Architecture Rethink](0027-installation-architecture-rethink.md) — superseded by this ADR. Frontmatter hooks and config consolidation concepts carry forward.
- [ADR-0021: Safe Install, Upgrade, and Namespace Isolation](0021-safe-install-upgrade-path.md) — pf- prefix namespace still valid
