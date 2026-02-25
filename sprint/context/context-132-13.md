# Context: 132-13 Reconcile Getting Started guide with Python-first install (ADR-0028)

## Goal

Rewrite `pennyfarthing/docs/GETTING-STARTED.md` so the installation instructions match ADR-0028 (accepted 2026-02-22), which replaces the npm-first install (`npm install @pennyfarthing/core`) with a Python-first install (`pip install pf` then `pf init`). The guide currently describes an obsolete workflow that no longer matches how the framework is actually installed.

## Current State

### What the guide says now

1. **Prerequisites** list Node.js 18+ first, Python second. Implies Node is primary runtime.
2. **Step 1** is `npm install --save-dev @pennyfarthing/core` -- this package no longer exists under ADR-0028.
3. Optional theme packs installed via `npm install --save-dev @pennyfarthing/themes-*` -- also npm-based.
4. **Step 2** is `pf init` -- this is correct but the guide positions it as a post-npm step, not the primary bootstrap.
5. `pf init` description says it creates symlinks -- ADR-0028 says end-users get copies, not symlinks.
6. **Verify** section's `pf doctor` output includes `node_packages: node_modules/ present` as a top-level check -- this is now a managed dependency, not the user's concern.
7. **Updating** section says `npm update @pennyfarthing/core` and `npm update @pennyfarthing/themes-*`.
8. **Fresh reinstall** section says `pf uninstall && npm install --save-dev @pennyfarthing/core && pf init`.

### What ADR-0028 requires

1. **Install:** `pip install pf` (global, from private PyPI). No npm step for the user.
2. **Bootstrap:** `pf init` does everything -- directory structure, copies commands/skills, detects package manager, installs Node packages automatically, writes settings, runs `/pf-setup`, updates `.gitignore`.
3. **No `@pennyfarthing/core` npm package.** Python package `pf` on private PyPI replaces it.
4. **No wrapper scripts.** Global `pf` replaces the `pf.sh` -> `run-pf.sh` -> `uv run` chain.
5. **Node is managed, not managing.** Python decides when and how Node packages are installed. Users never run `npm install` for Pennyfarthing.
6. **Theme packs** are installed by `pf init` or `pf theme install` -- not by npm directly.

### What `pf init` actually does (core.py)

The implementation in `pennyfarthing-dist/src/pf/init/core.py` confirms the ADR-0028 model:
- Verifies `pf` CLI is on PATH first (requires prior `pip install pf` or `pipx install pennyfarthing-scripts`)
- Creates `.pennyfarthing/` and `.claude/` directories
- Copies pf-* commands and skills (copies, not symlinks)
- Writes or upgrades `settings.local.json` with infrastructure hooks
- Writes init manifest
- Updates `.gitignore`
- Triggers auto-setup workflow

## Specific Changes

### Prerequisites section (lines 13-23)

- Move **Python 3.11+** to the top of the list -- it is now the primary runtime
- Demote **Node.js 18+** to "installed automatically by `pf init` if needed for BikeRack/Cyclist" or similar language that makes clear it is a managed dependency
- Keep Git, Claude Code CLI, yq, jq as-is

### Step 1: Install the Package (lines 28-43)

Replace entirely:
- Old: `npm install --save-dev @pennyfarthing/core`
- New: `pip install pf` (or `pipx install pennyfarthing-scripts` as alternative)
- Remove the optional npm theme pack section. Theme packs are handled by `pf init` or `pf theme install` post-init.

### Step 2: Initialize Your Project (lines 45-59)

- `pf init` stays as the command
- Update the description: remove "symlinks (not copies)" language -- end-users get copies per ADR-0028
- Update the table to reflect what `pf init` actually creates (add settings.local.json, init manifest; note that Node packages are installed automatically)
- Mention that `pf init` auto-detects the package manager (pnpm/yarn/npm) and installs Node dependencies

### Step 3: Interactive Setup (lines 61-73)

- This may now happen automatically as part of `pf init` (core.py calls `setup.run_setup`)
- Clarify whether `/pf-setup` is still a separate manual step or is now folded into `pf init`

### Step 4: Verify / pf doctor output (lines 75-95)

- Update the example `pf doctor` output to remove `node_packages` as a prominent check or reframe it
- The output should reflect Python-first reality (pf CLI version, Python version, etc.)

### Updating section (lines 349-360)

Replace entirely:
- Old: `npm update @pennyfarthing/core`
- New: `pip install --upgrade pf` (or `pipx upgrade pennyfarthing-scripts`)
- Remove npm theme pack update commands

### Fresh reinstall / Troubleshooting (lines 389-395)

- Old: `pf uninstall && npm install --save-dev @pennyfarthing/core && pf init`
- New: `pf uninstall && pip install pf && pf init`

### Display Modes section (lines 299-308)

- The `npm run dev:web` command for Cyclist may need updating or a note that Node packages are managed by `pf init`

## Key Files

| File | Action |
|------|--------|
| `pennyfarthing/docs/GETTING-STARTED.md` | Primary file to rewrite -- reconcile with ADR-0028 |
| `docs/adr/0028-python-first-installation.md` | Reference -- the accepted architecture (read-only) |
| `docs/adr/0027-installation-architecture-rethink.md` | Reference -- superseded predecessor (read-only) |
| `pennyfarthing/pennyfarthing-dist/src/pf/init/core.py` | Reference -- what `pf init` actually does (read-only) |
| `pennyfarthing/pennyfarthing-dist/src/pf/init/setup.py` | Check what auto-setup does to confirm Step 3 guidance |

## Dependencies

- **ADR-0028 acceptance:** Confirmed accepted 2026-02-22. No blockers.
- **`pf init` implementation status:** `core.py` implements the Python-first flow. Verify `setup.py` (auto-setup) is complete to determine whether Step 3 (`/pf-setup`) is still a separate manual step.
- **Private PyPI availability:** ADR-0028 specifies `pip install pf` from private PyPI. The guide should include the registry URL or `--index-url` flag if the package is not yet on public PyPI.
- **Theme install mechanism:** Confirm how theme packs are installed post-ADR-0028 (is it `pf theme install`? automatic during `pf init`? or still npm but triggered by Python?).

## Acceptance Criteria

1. **No npm install instructions for Pennyfarthing.** The guide must not tell users to run `npm install @pennyfarthing/core` or `npm install @pennyfarthing/themes-*`.
2. **Primary install is `pip install pf`.** This is the first command in the Installation section.
3. **`pf init` described accurately.** The description matches what `core.py` actually does -- copies (not symlinks), auto-detects package manager, installs Node deps, writes settings.
4. **Prerequisites reflect Python-first.** Python 3.11+ is listed first. Node is described as a managed dependency.
5. **Update/reinstall instructions use pip.** No `npm update` commands in the Updating or Troubleshooting sections.
6. **Guide is self-consistent.** No leftover references to `@pennyfarthing/core` as an npm package anywhere in the document.
7. **Smoke test:** A new user following the guide on a clean project can install and initialize Pennyfarthing using only the documented steps.
