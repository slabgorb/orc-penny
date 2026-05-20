# Context: 132-9 Add pf CLI installation to just setup bootstrap

**Jira Issue:** PROJ-15645
**Points:** 3
**Priority:** P1
**Epic:** 132 — Guided Tour Enhancements (PROJ-15616)
**Workflow:** tdd

## Goal

After running `just setup`, the `pf` CLI must be available on PATH. Currently it is not installed, so a new developer immediately hits `pf: command not found` when hooks fire, sprint commands are invoked, or `pf init` is attempted. This is a zero-day onboarding blocker because every hook in `settings.local.json` calls `pf hooks <name>`.

## Current State

The `setup` recipe in `justfile` (lines 302-330) runs four steps:

```
Step 1/4: git clone pennyfarthing/ (if missing)
Step 2/4: cd pennyfarthing && pnpm install
Step 3/4: cd pennyfarthing && pnpm build
Step 4/4: cd root && npm install
```

There is no step that installs the Python `pf` CLI. After setup completes, the Node packages are built and linked, but:

- `pf` is not on PATH -- hooks fail immediately
- `pf init` cannot run (it calls `verify_pf_cli()` at `pennyfarthing-dist/src/pf/init/core.py:47-108`, which checks `shutil.which("pf")`)
- `pf hooks session-start`, `pf hooks bell-mode`, and all other hooks referenced in `settings.local.json` error out
- The `tui` and `tui-dev` recipes already assume `uv` is available (lines 173-179) but the `pf` package itself is never installed

The Python package is defined in two `pyproject.toml` files:

1. **`pennyfarthing/pyproject.toml`** (lines 1-64) -- the canonical project definition for the monorepo. Entry point: `pf = "pf.cli:main"`. Source discovery: `where = ["pennyfarthing-dist/src"]`. Core dependencies: pyyaml, ruamel.yaml, httpx, click, pydriller. Optional extras: `tui`, `portraits`, `dev`.

2. **`pennyfarthing/pennyfarthing-dist/pyproject.toml`** (lines 1-19) -- a secondary/dist copy with the same entry point but inlined dependencies (includes textual, websockets in core deps rather than extras).

ADR-0028 (`docs/adr/0028-python-first-installation.md`) establishes that `pf` is the primary interface and Python is the installer. It prescribes `pip install pf` from private PyPI for production, but during local development the editable install (`pip install -e .`) from the monorepo is the correct approach.

## Technical Approach

### Recommended: `pip install -e` in a step between pnpm build and npm install

Add a new step to the `setup` recipe that performs an editable install of the `pf` package from the `pennyfarthing/` directory. This makes the `pf` command available globally (or in the active venv) and tracks source changes without reinstallation.

**Option A -- Direct pip editable install (simplest, recommended):**

```bash
# Step 4/5 (new): Install pf CLI
echo "Step 4/5: Installing pf CLI..."
pip install -e "{{pennyfarthing}}"
```

This works because `pennyfarthing/pyproject.toml` defines `[project.scripts] pf = "pf.cli:main"` and `[tool.setuptools.packages.find] where = ["pennyfarthing-dist/src"]`.

**Option B -- pipx for isolation:**

```bash
pipx install -e "{{pennyfarthing}}"
```

Pros: isolated venv, no pollution of system Python. Cons: requires `pipx` as a prerequisite, which is yet another tool to install. The `verify_pf_cli()` function already detects pipx installs (core.py:96-97).

**Option C -- uv tool install:**

```bash
uv tool install -e "{{pennyfarthing}}"
```

Pros: fast, the `tui` recipe already requires `uv`. Cons: requires `uv` as a prerequisite, though the justfile already checks for it in the `tui` recipe.

### Recommendation

Use **Option A** (`pip install -e`) as the default, with a prerequisite check for Python >= 3.11. Reasons:

1. Simplest -- no extra tooling required beyond Python itself
2. Editable install means framework source changes are reflected immediately
3. ADR-0028 says "pip install pf" is the canonical method
4. `verify_pf_cli()` detects the install method from the resolved path, so pip installs are handled

### Idempotency

`pip install -e` is already idempotent -- re-running it on an existing editable install is a no-op (or a fast upgrade). The step should:

1. Check if `pf` is already on PATH and functional (`pf --version`)
2. If yes, skip with a message ("pf CLI already installed")
3. If no, run the install
4. Verify after install (`pf --version`)

### Step renumbering

Current steps are 1/4 through 4/4. Adding the pf install makes it 1/5 through 5/5. The new step should be **Step 4/5**, after pnpm build (Step 3) and before npm install (Step 5), because the orchestrator's npm install may trigger postinstall scripts that assume `pf` is available.

## Key Files

| File | Action | Purpose |
|------|--------|---------|
| `justfile` | **Modify** (lines 302-330) | Add pf CLI install step to `setup` recipe |
| `pennyfarthing/pyproject.toml` | Read-only reference | Defines `pf` entry point and dependencies |
| `pennyfarthing/pennyfarthing-dist/src/pf/init/core.py` | Read-only reference | `verify_pf_cli()` function shows expected behavior |
| `docs/adr/0028-python-first-installation.md` | Read-only reference | Architectural justification |

## Dependencies

- **Python >= 3.11** must be available on the developer's machine (already required by `pyproject.toml` `requires-python = ">=3.11"`)
- **pip** must be available (ships with Python, but could be missing in some minimal installs)
- **pnpm build** must complete first (Step 3) so that `pennyfarthing-dist/src/` exists with the full source tree before pip resolves the package
- **No dependency on `uv` or `pipx`** -- those are optional enhancements, not prerequisites

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **System Python pollution** | `pip install -e` modifies the active Python environment's site-packages | Document that developers should use a venv or pyenv. Consider detecting active venv and warning if installing globally. |
| **PATH issues after install** | pip may install the `pf` script to a `bin/` directory not on PATH (e.g., `~/.local/bin/` on Linux) | After install, verify with `which pf` and print a PATH hint if not found. macOS Homebrew Python puts scripts in a PATH-included location by default. |
| **Python version mismatch** | Developer has Python 3.10 or earlier | Add a version check at the start of setup: `python3 -c "import sys; assert sys.version_info >= (3, 11)"` |
| **pip not available** | Some minimal Python installs omit pip | Check `command -v pip3 || command -v pip` before attempting install. Suggest `python3 -m ensurepip` if missing. |
| **Conflicting global pf install** | Developer already has `pf` installed from PyPI (not editable) | The editable install will override it. Print a warning if `pf` exists before install and is not an editable install pointing to this repo. |
| **venv not activated** | If a project venv exists but is not activated, pip installs to global | Consider creating/activating a `.venv` in the orchestrator root, but this adds complexity. For now, document the expected environment. |

## Acceptance Criteria

### AC1: `just setup` installs the pf CLI
- **Given** a fresh clone with no `pf` on PATH
- **When** `just setup` completes successfully
- **Then** `pf --version` succeeds and prints the version
- **And** `which pf` points to the editable install from `pennyfarthing/`

### AC2: Setup is idempotent
- **Given** `just setup` has already been run
- **When** `just setup` is run again
- **Then** the pf install step completes without error
- **And** `pf --version` still works
- **And** the output indicates "already installed" or performs a fast re-install

### AC3: Python version is validated
- **Given** a system with Python < 3.11
- **When** `just setup` reaches the pf install step
- **Then** setup fails with a clear error message naming the minimum version
- **And** setup does not attempt the pip install

### AC4: Post-install verification
- **Given** `pip install -e` completed
- **When** the setup recipe continues
- **Then** `pf --version` is called to verify the install
- **And** if verification fails, setup prints a diagnostic (PATH hint, Python version, pip location)

### AC5: Step numbering and output are updated
- **Given** the setup recipe has been modified
- **When** `just setup` runs
- **Then** output shows 5 steps (not 4)
- **And** the new step is clearly labeled (e.g., "Step 4/5: Installing pf CLI...")
- **And** existing steps retain their original behavior
