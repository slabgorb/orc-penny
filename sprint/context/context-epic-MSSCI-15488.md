# Epic Context: Python-First Installation (MSSCI-15488)

**Epic ID:** 126
**Jira:** MSSCI-15488
**Status:** In Progress (3 of 10 stories done)
**Repos:** pennyfarthing
**ADR:** [ADR-0028: Python-First Installation](../../docs/adr/0028-python-first-installation.md)
**Supersedes:** ADR-0027, epics 111-116

---

## Summary

Replace npm-based installation with a Python-first approach. Global `pip install pf` from private PyPI, `pf init` handles full bootstrap including Node package installation and auto-setup. Eliminates uv, npm distribution, Node-based init, and the `run-pf.sh`/`pf.sh` wrapper script chain.

## Architecture (ADR-0028)

**Core principle:** Python is the installer. Node is a managed dependency.

- **Install:** `pip install pf` from private CloudSmith PyPI
- **Bootstrap:** `pf init` in a project directory does everything — directory structure, commands/skills, Node packages, settings, setup workflow
- **No two-phase install.** No setup-detector. No manifest flag. `pf init` is the complete experience.

### What's Removed

| Component | Replacement |
|-----------|-------------|
| `npx pennyfarthing` entry point | Global `pf` command |
| `init.ts` (Node-based init) | `pf init` (Python) |
| `setup-detector.js` | Setup runs during init |
| `session-start.js` | Python handles session start |
| `postinstall.cjs` | No npm postinstall needed |
| `run-pf.sh` / `pf.sh` wrapper chain | Global `pf` — just `pf` |
| uv dependency | Global pip install |
| `@pennyfarthing/core` npm package | Python package on private PyPI |

### What Stays

| Component | Role |
|-----------|------|
| Node/pnpm | BikeRack, Cyclist, WheelHub — installed by `pf init` |
| `config.local.yaml` | Single config file |
| Click CLI (`pf`) | Primary interface |

## Story Sequence

| Story | Title | Pts | Status | Key Outcome |
|-------|-------|-----|--------|-------------|
| 126-1 | Publish pf to private PyPI | 3 | **Done** | `src/pf/` layout, pyproject.toml, CI pipeline |
| 126-2 | Rewrite pf init in Python | 5 | **Done** | Directory scaffolding, command/skill copy, settings, --dry-run |
| 126-3 | Auto-setup in pf init | 5 | **Done** | Repo discovery, theme, git hooks, Node install — all in one flow |
| 126-4 | Remove wrapper chain | 2 | Backlog | Delete run-pf.sh, pf.sh; hooks call bare `pf` |
| 126-5 | Config consolidation | 3 | Backlog | Migrate preferences.yaml into config.local.yaml |
| 126-6 | Frontmatter hooks | 5 | Backlog | Agent/skill hooks in frontmatter, settings.local.json → 5 hooks |
| 126-7 | pf upgrade command | 5 | Backlog | Detect npm install, migrate to Python-based |
| 126-8 | Reduce doctor checks | 3 | Backlog | ~10 checks with --fix mode |
| 126-9 | Remove Node init artifacts | 2 | Backlog | Delete init.ts, postinstall.cjs, setup-detector.js |
| 126-10 | E2E test suite | 5 | Backlog | Fresh install, upgrade, dry-run, idempotency in CI |

**Total:** 38 points (13 done, 25 remaining)

## Completed Work

### 126-1: src/ Layout Migration + PyPI Publishing
- Migrated `pf/` → `src/pf/` (269 files)
- Version aligned to `11.5.0-alpha.0` (matches framework)
- Pure `pyproject.toml` with dynamic version, setuptools entry point
- `MANIFEST.in` prunes 12 non-package dirs
- tox.ini with build/test/release/smoke environments
- 49 packaging tests, all passing
- Branch: `feature/MSSCI-15489-publish-pf-pypi` (merged)

### 126-2: pf init Command
- `pf/init/core.py` — `init_project(target_dir, dist_root, dry_run)`
- Creates `.pennyfarthing/` and `.claude/` directory structures
- Copies pf-* commands and skills to both directories
- Writes `settings.local.json` with 5 hooks (guarded — won't overwrite)
- Init manifest (`init-manifest.json`) with version + timestamp
- Updates `.gitignore` with dedup logic
- `--dry-run` support, idempotent, returns result objects
- 55 tests (48 original + 7 from reviewer), all passing
- Branch: `feature/MSSCI-15490-pf-init-python` (merged)

### 126-3: Auto-Setup Integration
- `pf/init/setup.py` — `run_setup()` orchestrator
- `detect_package_manager()` walks up for lockfiles (pnpm > yarn > npm)
- `discover_repos()` with git root detection
- `write_repos_yaml()`, `write_theme_config()` (read-modify-write)
- `get_setup_state()` enables re-entry for partial completion
- `install_node_packages()` with dry-run support
- Git hooks opt-in via `_install_git_hooks()`
- 46 tests, all passing
- Branch: `feature/MSSCI-15491-auto-setup-pf-init` (merged)

## Key Files

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/src/pf/init/core.py` | Init scaffolding logic |
| `pennyfarthing-dist/src/pf/init/setup.py` | Auto-setup workflow |
| `pennyfarthing-dist/src/pf/init/cli.py` | Click command for `pf init` |
| `pennyfarthing-dist/src/pf/cli.py` | Main CLI with lazy command registry |
| `pennyfarthing-dist/pyproject.toml` | Package config, entry point |
| `pennyfarthing-dist/src/pf/tests/test_init_command.py` | 55 init tests |
| `pennyfarthing-dist/src/pf/tests/test_init_auto_setup.py` | 46 setup tests |
| `docs/adr/0028-python-first-installation.md` | Architecture decision |
| `docs/adr/0027-installation-architecture-rethink.md` | Superseded ADR |

## Dependencies & Risks

- **126-4 (wrapper removal) is the big disruption** — touches every hook command, agent activation, and shell script. Everything currently using `run-pf.sh`/`pf.sh` breaks until updated.
- **126-6 (frontmatter hooks) changes every agent .md file** — high surface area but mechanical.
- **126-7 (upgrade) needs careful user-data preservation** — custom hooks, commands, and skills must survive migration.
- **Node stays as managed dependency** — BikeRack/Cyclist/WheelHub still require pnpm/Node.

## Planning Docs

- [ADR-0028](../../docs/adr/0028-python-first-installation.md) — accepted architecture
- [ADR-0027](../../docs/adr/0027-installation-architecture-rethink.md) — superseded predecessor
- [Installation Architecture Rethink](../planning/installation-archtecture-rethink.md) — epic breakdown from ADR-0027 era
- [Install Overhaul Epics](../planning/install-overhaul-epics.md) — earlier planning (superseded)
