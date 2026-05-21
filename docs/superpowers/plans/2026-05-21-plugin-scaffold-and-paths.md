# Pennyfarthing-as-Plugin — Plan 2: Scaffold + `pf.paths` Chokepoint

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Claude Code plugin manifest and `runtime/` skeleton to the `pennyfarthing/` repo, move the existing Python package into `runtime/src/pf/`, introduce `pf.paths` as the single chokepoint for runtime-state paths, and refactor every runtime-state call site to route through it. After Plan 2 the plugin installs and the existing Python test suite still passes; agents/commands/skills still live under `pennyfarthing-dist/` (Plan 3 moves those).

**Architecture:** Three storage tiers per the design spec — code under `${CLAUDE_PLUGIN_ROOT}/runtime/`, project artifacts in the user repo, runtime state under `${CLAUDE_PLUGIN_DATA}` (with `~/.claude/data/pf/` fallback). `pf.paths` is the single Python module that resolves runtime-state paths; every read of session files, sidecars, and `config.local.yaml` routes through it. Legacy install paths (`init/`, `upgrade/`, `doctor/`, etc.) are left tagged for removal in later plans — Plan 2 deliberately does not refactor them.

**Tech Stack:** Python 3.11+, `uv` (project-managed venv), `hatchling` (build backend), `pytest`, Claude Code plugin manifest schema.

**Scope notes:**

- **No legacy install preservation.** There is no `pip install -e pennyfarthing-dist/` to keep working. `pennyfarthing-dist/pyproject.toml` and `pennyfarthing-dist/setup.py` get deleted in Task 7.
- **No migration tooling.** The previously planned Plan 5 (`pf migrate-from-legacy`) is descoped. Cutover is manual.
- **Plan 2 does not move agents/commands/skills.** Those live under `pennyfarthing-dist/_dist/` or `pennyfarthing-dist/<dir>/` and get moved in Plan 3. Plan 2 only touches Python source.
- **Plan 2 does not drop the `pf-` prefix.** Commands, agents, and skills keep their filenames. Plan 3 handles the rename to `/pf:*` namespacing.
- **Plan 2 does not rewrite hooks.** Plan 4 owns that.
- **`runtime/uv.lock` IS committed.** The `runtime/.venv/` directory is NOT — it is created by `uv` on first hook invocation in the consumer's environment (validated by Gate 1 spike).
- Branch base: `develop` (not `main`) per `repos.yaml` for the `pennyfarthing/` repo. All commits in this plan land on a fresh feature branch off `develop`.

**Working directory:** All implementation work for this plan happens in the `pennyfarthing/` framework repo at `/Users/slabgorb/Projects/orc-penny/pennyfarthing/`. No files are written to the `orc-penny/` orchestrator repo by this plan.

---

## File Structure

After Plan 2, the `pennyfarthing/` repo looks like:

```
pennyfarthing/
├── .claude-plugin/                          # NEW
│   ├── plugin.json                          # NEW — declares pf plugin
│   └── marketplace.json                     # NEW — single-plugin marketplace
├── runtime/                                 # NEW — Python package home
│   ├── pyproject.toml                       # NEW — hatchling-based
│   ├── uv.lock                              # NEW — committed
│   └── src/
│       └── pf/                              # MOVED from pennyfarthing-dist/src/pf/
│           ├── paths.py                     # NEW — single chokepoint
│           ├── tests/
│           │   └── test_paths.py            # NEW
│           └── ... (every other file moves verbatim)
└── pennyfarthing-dist/                      # essentially empty after Plan 2
    └── src/                                 # NOW EMPTY (pf/ moved into runtime/)
    # (pennyfarthing-dist/pyproject.toml and setup.py DELETED in Task 7)
    # (pennyfarthing-dist/src/pf_launcher.py DELETED in Task 6)
    # Plan 3 deletes pennyfarthing-dist/ entirely.

# Agents, commands, skills, etc. (currently at pennyfarthing-dist/src/pf/_dist/)
# get moved INTO runtime/src/pf/_dist/ as part of the git mv in Task 5.
# Plan 3 then lifts them OUT of the Python package to the plugin root.
```

**Files added:** 5 new files in Plan 2 (`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `runtime/pyproject.toml`, `runtime/uv.lock`, `runtime/src/pf/paths.py`, `runtime/src/pf/tests/test_paths.py` — 6 total, one is generated).

**Files moved:** the entire `pennyfarthing-dist/src/pf/` tree (preserves git history via `git mv`).

**Files deleted:** `pennyfarthing-dist/pyproject.toml`, `pennyfarthing-dist/setup.py`, `pennyfarthing-dist/src/pf_launcher.py` (the launcher is obsolete in the plugin model).

**Files modified:** ~8–12 Python files in `runtime/src/pf/` (the runtime-state call sites) plus a small number of test fixtures. Exact list in Tasks 14–18.

---

## Task 1: Pre-Flight — Branch from `develop`

**Files:** none (git state only)

- [ ] **Step 1: Verify clean working tree in `pennyfarthing/`**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git status --short
```

Expected: no output (clean tree). If there are uncommitted changes, **stop and ask**. Do not stash, commit, or discard.

- [ ] **Step 2: Switch to `develop` and pull**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git checkout develop
git pull --ff-only origin develop
```

Expected: HEAD at the latest `origin/develop` commit. If `pull --ff-only` reports diverging history, **stop and ask** — do not force-merge.

- [ ] **Step 3: Branch for this plan**

```bash
git checkout -b feat/plugin-scaffold-and-paths
```

Expected: `git branch --show-current` prints `feat/plugin-scaffold-and-paths`.

- [ ] **Step 4: Verify Python tooling**

```bash
uv --version
python3 --version
```

Expected: `uv 0.5.x` or later (already installed per Gate 1 spike); Python 3.11+.

- [ ] **Step 5: Capture baseline test count**

Before any changes, capture how many tests currently pass so the post-move test run has a comparison baseline:

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
python3 -m pytest pennyfarthing-dist/src/pf/tests/ --collect-only -q 2>&1 | tail -5
```

Record the number reported (e.g., `442 tests collected`). The post-move run in Task 19 must collect the same number.

---

## Task 2: Create `.claude-plugin/plugin.json`

**Files:**
- Create: `pennyfarthing/.claude-plugin/plugin.json`

- [ ] **Step 1: Create the directory**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
mkdir -p .claude-plugin
```

- [ ] **Step 2: Write the manifest**

Create `pennyfarthing/.claude-plugin/plugin.json` with this exact content:

```json
{
  "name": "pf",
  "description": "Pennyfarthing agent orchestration framework: TDD-disciplined sprint workflow with phase-separated agent personas (SM, TEA, Dev, Reviewer, Architect, PM, BA).",
  "version": "1.0.0-alpha.1",
  "author": {
    "name": "Keith Avery",
    "email": "slabgorb@gmail.com"
  },
  "license": "Apache-2.0",
  "homepage": "https://github.com/slabgorb/pennyfarthing"
}
```

- [ ] **Step 3: Verify it parses as JSON**

```bash
jq . .claude-plugin/plugin.json
```

Expected: pretty-printed JSON output, no errors.

---

## Task 3: Create `.claude-plugin/marketplace.json`

**Files:**
- Create: `pennyfarthing/.claude-plugin/marketplace.json`

- [ ] **Step 1: Write the marketplace manifest**

Schema discovered during Gate 1 spike: requires top-level `description`, `source: "./"` (trailing slash), and per-plugin `author`. The `$schema` URL is required by validation; if `claude plugin validate` rejects the manifest below for a missing `$schema`, capture the URL it suggests and add it as a top-level key.

Create `pennyfarthing/.claude-plugin/marketplace.json`:

```json
{
  "name": "pennyfarthing",
  "description": "Single-plugin marketplace for the Pennyfarthing agent orchestration framework.",
  "owner": {
    "name": "Keith Avery",
    "email": "slabgorb@gmail.com"
  },
  "plugins": [
    {
      "name": "pf",
      "source": "./",
      "description": "Pennyfarthing agent orchestration plugin",
      "version": "1.0.0-alpha.1",
      "author": {
        "name": "Keith Avery",
        "email": "slabgorb@gmail.com"
      }
    }
  ]
}
```

- [ ] **Step 2: Validate the manifest**

```bash
claude plugin validate /Users/slabgorb/Projects/orc-penny/pennyfarthing
```

Expected: `✔ Validation passed`. If validation fails on a missing `$schema` field, add it per the validator's suggestion (the spike's working spike manifest also needed it; see `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` schema-shape findings) and re-validate.

If validation fails for any other reason, capture the exact error and adjust the manifest accordingly. Record any deviation in the assessment.

---

## Task 4: Create `runtime/pyproject.toml`

**Files:**
- Create: `pennyfarthing/runtime/pyproject.toml`

- [ ] **Step 1: Create the runtime directory**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
mkdir -p runtime/src
```

- [ ] **Step 2: Write the pyproject.toml**

Dependencies copied verbatim from `pennyfarthing-dist/pyproject.toml` (which gets deleted in Task 7). Build backend changes to `hatchling` (validated by Gate 1 spike). The `[project.scripts]` entry now points at `pf.cli:main` directly — the obsolete `pf_launcher` is dropped.

Create `pennyfarthing/runtime/pyproject.toml`:

```toml
[project]
name = "pf"
version = "1.0.0a1"
description = "Pennyfarthing agent orchestration runtime"
requires-python = ">=3.11"
dependencies = [
  "pyyaml>=6.0",
  "ruamel.yaml>=0.18",
  "httpx>=0.28",
  "click>=8.0",
  "pydriller>=2.6",
  "textual>=1.0",
  "websockets>=12.0",
  "textual-image>=0.7.0",
  "watchfiles>=1.0",
  "fastapi>=0.115",
  "uvicorn[standard]>=0.34"
]

[project.optional-dependencies]
test = [
  "pytest>=8.0",
  "pytest-mock>=3.14",
  "pytest-asyncio>=1.0",
  "build>=1.0"
]

[project.scripts]
pf = "pf.cli:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/pf"]

[tool.pytest.ini_options]
testpaths = ["src/pf/tests"]
```

- [ ] **Step 3: Verify the TOML parses**

```bash
python3 -c "import tomllib; tomllib.load(open('runtime/pyproject.toml','rb'))"
```

Expected: no output (success). If `tomllib` is unavailable on Python <3.11, this step's command itself signals the wrong Python — investigate.

---

## Task 5: Move `pennyfarthing-dist/src/pf/` → `runtime/src/pf/`

**Files:**
- Move (preserving git history): the entire `pennyfarthing-dist/src/pf/` tree to `runtime/src/pf/`.

- [ ] **Step 1: Confirm source location**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
ls pennyfarthing-dist/src/pf/ | head -5
```

Expected: lists Python modules (e.g., `__init__.py`, `cli.py`, `agent_create.py`, ...).

- [ ] **Step 2: Perform the move with `git mv`**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git mv pennyfarthing-dist/src/pf runtime/src/pf
```

Expected: no output on success. `git mv` preserves history; subsequent `git log --follow runtime/src/pf/cli.py` will trace back to `pennyfarthing-dist/src/pf/cli.py` and earlier.

- [ ] **Step 3: Verify the move**

```bash
ls runtime/src/pf/ | head -5
ls pennyfarthing-dist/src/
```

Expected: `runtime/src/pf/` shows the modules; `pennyfarthing-dist/src/` shows only `pf_launcher.py` (or `pf_launcher.py` plus `pennyfarthing_scripts.egg-info/` if not gitignored) and `__pycache__/` — no `pf/` directory.

- [ ] **Step 4: Snapshot for sanity**

```bash
git status --short | head -20
```

Expected: shows many `R  pennyfarthing-dist/src/pf/... -> runtime/src/pf/...` rename entries. Git treats this as renames (history preserved).

---

## Task 6: Delete the obsolete `pf_launcher.py`

**Files:**
- Delete: `pennyfarthing-dist/src/pf_launcher.py`

The launcher walks up from cwd to find the project-local pf source — necessary under the pipx install model. In the plugin model, `uv run --project ${CLAUDE_PLUGIN_ROOT}/runtime` always resolves the source unambiguously. The launcher has no callers in the new model.

- [ ] **Step 1: Verify nothing imports `pf_launcher`**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
grep -r "pf_launcher" . --include="*.py" --exclude-dir=__pycache__ --exclude-dir=.venv 2>/dev/null
```

Expected: matches limited to the launcher file itself and possibly references in the OLD `pennyfarthing-dist/pyproject.toml` `[project.scripts]` entry. No Python code should `import pf_launcher`.

If unexpected matches appear (e.g., a runtime module imports it), **stop and ask** before deleting.

- [ ] **Step 2: Remove the file**

```bash
git rm pennyfarthing-dist/src/pf_launcher.py
```

Expected: `rm 'pennyfarthing-dist/src/pf_launcher.py'`.

---

## Task 7: Delete the obsolete legacy install files

**Files:**
- Delete: `pennyfarthing-dist/pyproject.toml`
- Delete: `pennyfarthing-dist/setup.py` (if present)

No legacy install path needs to remain valid (per project guidance: no pip/npm install for pennyfarthing, and no migration tooling is being built).

- [ ] **Step 1: Verify these files exist**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
ls -la pennyfarthing-dist/pyproject.toml pennyfarthing-dist/setup.py 2>&1
```

Record output. If `setup.py` is absent (`No such file or directory`), only delete `pyproject.toml`.

- [ ] **Step 2: Remove the files**

```bash
git rm pennyfarthing-dist/pyproject.toml
git rm pennyfarthing-dist/setup.py 2>/dev/null || true   # tolerate absence
```

- [ ] **Step 3: Verify removal**

```bash
ls pennyfarthing-dist/pyproject.toml pennyfarthing-dist/setup.py 2>&1
```

Expected: `No such file or directory` for both.

---

## Task 8: Generate `runtime/uv.lock`

**Files:**
- Create (via `uv lock`): `pennyfarthing/runtime/uv.lock`

- [ ] **Step 1: Run `uv lock`**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv lock
```

Expected: `Resolved N packages in <time>s.` and creation of `uv.lock`. If resolution fails, capture the error (likely a deps issue — investigate before proceeding).

- [ ] **Step 2: Verify the lockfile**

```bash
ls -la uv.lock
head -10 uv.lock
```

Expected: file exists, header reads `# This file was autogenerated by uv via the following command:`.

- [ ] **Step 3: Ensure `.venv` is NOT staged**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git status --short | grep -E "runtime/\.venv" || echo "OK: .venv not tracked"
```

Expected: `OK: .venv not tracked`. If `.venv/` appears in `git status`, add to `runtime/.gitignore` per Step 4 before committing.

- [ ] **Step 4: Ensure `runtime/.gitignore` excludes `.venv` and friends**

Create `pennyfarthing/runtime/.gitignore`:

```
.venv/
__pycache__/
*.pyc
*.egg-info/
.pytest_cache/
```

---

## Task 9: Initial Validation Checkpoint and Commit

After Tasks 2–8 the plugin manifest is in place and the Python source has moved. This is a logical checkpoint — commit before the chokepoint refactor.

- [ ] **Step 1: Validate the plugin manifest end-to-end**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
claude plugin validate .
```

Expected: `✔ Validation passed`.

- [ ] **Step 2: Verify Python imports still resolve**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run python -c "import pf; print(pf.__version__)"
```

Expected: prints `13.1.2` (or whatever the current `pf/__init__.py` `__version__` is). If import fails with `ModuleNotFoundError`, the `[tool.hatch.build.targets.wheel] packages = ["src/pf"]` entry may be misconfigured — debug before proceeding.

- [ ] **Step 3: Smoke-test one runnable subcommand**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pf --version
```

Expected: prints the version (e.g., `pf 13.1.2`). If this fails, the click entrypoint resolution in `runtime/pyproject.toml` is wrong.

- [ ] **Step 4: Stage and commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add .claude-plugin/ runtime/ pennyfarthing-dist/
git status --short | head -20
git commit -m "feat(plugin): scaffold .claude-plugin manifest and runtime/ skeleton

Add Claude Code plugin manifests (plugin.json, marketplace.json) and
move the Python package to runtime/src/pf/ using git mv to preserve
history. Drop the legacy setuptools pyproject and pf_launcher; runtime
now ships via hatchling for invocation through 'uv run --project
\${CLAUDE_PLUGIN_ROOT}/runtime pf ...' from plugin hooks.

Manifest schemas validated by 'claude plugin validate'. uv.lock
committed; .venv excluded via runtime/.gitignore.

See: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md"
```

Expected: commit succeeds with GPG signature. If signing fails, **stop and tell the user** (per repo rules).

---

## Task 10: TDD — `pf.paths.origin_slug()` (RED)

`pf.paths` is the chokepoint module. Origin slug normalization is the first function: given a `git remote get-url origin` value, produce a stable bucket key per spec §3.3.

**Files:**
- Create: `pennyfarthing/runtime/src/pf/tests/test_paths.py` (RED — failing test)

- [ ] **Step 1: Create the test file with the origin-slug test**

Create `pennyfarthing/runtime/src/pf/tests/test_paths.py`:

```python
"""Tests for pf.paths — the runtime-state path chokepoint."""

from __future__ import annotations

import pytest

from pf import paths


class TestOriginSlug:
    """Normalize git remote origin URLs to stable bucket keys (spec §3.3)."""

    @pytest.mark.parametrize(
        "url, expected",
        [
            ("git@github.com:slabgorb/pennyfarthing.git", "github.com/slabgorb/pennyfarthing"),
            ("https://github.com/slabgorb/pennyfarthing", "github.com/slabgorb/pennyfarthing"),
            ("https://github.com/slabgorb/pennyfarthing.git", "github.com/slabgorb/pennyfarthing"),
            ("ssh://git@github.com/slabgorb/pennyfarthing", "github.com/slabgorb/pennyfarthing"),
            ("ssh://git@github.com/slabgorb/pennyfarthing.git", "github.com/slabgorb/pennyfarthing"),
            ("git@gitlab.com:foo/bar.git", "gitlab.com/foo/bar"),
            ("https://GitHub.com/slabgorb/Pennyfarthing", "github.com/slabgorb/Pennyfarthing"),
        ],
        ids=[
            "ssh_with_dot_git",
            "https_no_dot_git",
            "https_with_dot_git",
            "ssh_url_form",
            "ssh_url_form_with_dot_git",
            "gitlab_ssh",
            "uppercase_host_lowercased",
        ],
    )
    def test_known_forms(self, url: str, expected: str) -> None:
        assert paths.origin_slug(url) == expected

    def test_empty_url_returns_none(self) -> None:
        assert paths.origin_slug("") is None

    def test_unrecognized_form_returns_none(self) -> None:
        # An obviously broken/non-git URL — caller should fall back to _local
        assert paths.origin_slug("not-a-url") is None
```

- [ ] **Step 2: Run the test and confirm RED**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/test_paths.py -v
```

Expected: `ModuleNotFoundError: No module named 'pf.paths'` or `ImportError: cannot import name 'paths' from 'pf'`. Any error proving the module does not exist yet is acceptable RED — do not proceed until the test fails for the right reason.

---

## Task 11: GREEN — implement `pf.paths.origin_slug()`

**Files:**
- Create: `pennyfarthing/runtime/src/pf/paths.py`

- [ ] **Step 1: Create the chokepoint module**

Create `pennyfarthing/runtime/src/pf/paths.py`:

```python
"""Runtime-state path chokepoint for the pf plugin.

This module is the *single* place that knows how to derive runtime-state
locations for sessions, sidecars, and config. Every other module that
needs a runtime path imports from here.

Two environments are supported:

- Plugin context: ``CLAUDE_PLUGIN_DATA`` is set by Claude Code on hook
  invocation and points at ``~/.claude/plugins/data/<marketplace>-<plugin>/``.
  This is the primary path.

- Outside-plugin context (Keith's optional ``pf`` shim per spec §5.2):
  ``CLAUDE_PLUGIN_DATA`` is unset. Fall back to ``~/.claude/data/pf/``
  so both contexts agree.

Design references:
- Storage tiers: design spec §3.2
- Origin slug normalization: design spec §3.3
- Project hash: design spec §3.4
- Paths chokepoint discussion: design spec §7.2
"""

from __future__ import annotations

import hashlib
import os
import re
from pathlib import Path
from typing import Optional


_FALLBACK_DATA_ROOT = Path.home() / ".claude" / "data" / "pf"
_GIT_DOT_GIT_SUFFIX = re.compile(r"\.git$")


def origin_slug(url: str) -> Optional[str]:
    """Normalize a git remote URL to a stable ``host/owner/repo`` slug.

    Returns ``None`` if the URL does not resemble a git remote. Callers
    that need a guaranteed-non-None bucket key (e.g., for sidecar dirs)
    should fall back to ``_local/<project_hash>`` themselves.
    """
    if not url:
        return None

    candidate = url.strip()

    # Strip ssh://user@ prefix
    if candidate.startswith("ssh://"):
        candidate = candidate[len("ssh://"):]
        if "@" in candidate.split("/", 1)[0]:
            candidate = candidate.split("@", 1)[1]
        # ssh://host/owner/repo — already path-form
    elif candidate.startswith("http://") or candidate.startswith("https://"):
        candidate = candidate.split("://", 1)[1]
        # https://host/owner/repo — already path-form
    elif "@" in candidate and ":" in candidate:
        # git@github.com:owner/repo.git form
        user_host, sep, path = candidate.partition(":")
        if not sep:
            return None
        _, _, host = user_host.rpartition("@")
        candidate = f"{host}/{path}"
    else:
        return None

    # Strip trailing .git
    candidate = _GIT_DOT_GIT_SUFFIX.sub("", candidate)

    # Lowercase the host segment only (keep owner/repo casing)
    host_part, sep, rest = candidate.partition("/")
    if not sep or not rest:
        return None
    return f"{host_part.lower()}/{rest}"
```

- [ ] **Step 2: Run the test and confirm GREEN**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/test_paths.py::TestOriginSlug -v
```

Expected: all parametrized cases plus `test_empty_url_returns_none` and `test_unrecognized_form_returns_none` PASS.

If any case fails, fix `origin_slug` until the test is green. Do NOT change the test expectations.

---

## Task 12: TDD — `pf.paths.project_hash()` (RED then GREEN)

Per spec §3.4: `sha256(git_toplevel_abs_path)[:12]`, falling back to `sha256(cwd)[:12]` if not in a git repo.

**Files:**
- Modify: `pennyfarthing/runtime/src/pf/tests/test_paths.py` (add tests)
- Modify: `pennyfarthing/runtime/src/pf/paths.py` (add function)

- [ ] **Step 1: Add tests for `project_hash`**

Append to `pennyfarthing/runtime/src/pf/tests/test_paths.py`:

```python


class TestProjectHash:
    """sha256-derived per-working-copy identifier (spec §3.4)."""

    def test_deterministic_for_same_path(self, tmp_path: Path) -> None:
        from pathlib import Path  # local re-import to make the snippet hermetic
        h1 = paths.project_hash(tmp_path)
        h2 = paths.project_hash(tmp_path)
        assert h1 == h2

    def test_length_is_12(self, tmp_path: Path) -> None:
        h = paths.project_hash(tmp_path)
        assert isinstance(h, str)
        assert len(h) == 12
        assert all(c in "0123456789abcdef" for c in h)

    def test_different_paths_yield_different_hashes(self, tmp_path: Path) -> None:
        a = tmp_path / "a"
        b = tmp_path / "b"
        a.mkdir()
        b.mkdir()
        assert paths.project_hash(a) != paths.project_hash(b)

    def test_uses_absolute_path(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        # Hash for a relative-vs-absolute version of the same dir must agree.
        (tmp_path / "sub").mkdir()
        monkeypatch.chdir(tmp_path)
        absolute_hash = paths.project_hash(tmp_path / "sub")
        relative_hash = paths.project_hash(Path("sub"))
        assert absolute_hash == relative_hash
```

Also add the missing import at the top of the test file. Edit the imports block of `test_paths.py` to include `from pathlib import Path`:

```python
from __future__ import annotations

from pathlib import Path

import pytest

from pf import paths
```

- [ ] **Step 2: Run the tests and confirm RED**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/test_paths.py::TestProjectHash -v
```

Expected: `AttributeError: module 'pf.paths' has no attribute 'project_hash'` for each case.

- [ ] **Step 3: Implement `project_hash`**

Append to `pennyfarthing/runtime/src/pf/paths.py`:

```python


def project_hash(path: Path | None = None) -> str:
    """12-character hex digest identifying a working copy.

    ``path`` defaults to ``Path.cwd()``. The hash is computed from the
    *absolute* path so that relative and absolute references to the same
    directory agree. This matches spec §3.4.

    Note: this function does NOT attempt git-toplevel discovery — the
    caller passes the directory they want hashed. The "use git toplevel
    when in a git repo" policy is implemented by ``project_root()``
    below; ``project_hash`` just hashes whatever path it is given.
    """
    if path is None:
        path = Path.cwd()
    absolute = Path(path).resolve()
    return hashlib.sha256(str(absolute).encode("utf-8")).hexdigest()[:12]
```

- [ ] **Step 4: Run the tests and confirm GREEN**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/test_paths.py::TestProjectHash -v
```

Expected: 4 tests PASS.

---

## Task 13: TDD — `pf.paths.project_root()` and `pf.paths.project_origin_slug()`

These wrap the "use git when present, fall back otherwise" policy that `project_hash` deliberately left out.

**Files:**
- Modify: `pennyfarthing/runtime/src/pf/tests/test_paths.py`
- Modify: `pennyfarthing/runtime/src/pf/paths.py`

- [ ] **Step 1: Add tests**

Append to `test_paths.py`:

```python


class TestProjectRoot:
    """Resolve the working copy root — git toplevel if available, else cwd."""

    def test_no_git_returns_resolved_path(self, tmp_path: Path) -> None:
        # tmp_path is not a git repo
        result = paths.project_root(tmp_path)
        assert result == tmp_path.resolve()

    def test_in_git_repo_returns_toplevel(self, tmp_path: Path) -> None:
        import subprocess
        subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
        nested = tmp_path / "sub" / "dir"
        nested.mkdir(parents=True)
        result = paths.project_root(nested)
        assert result == tmp_path.resolve()


class TestProjectOriginSlug:
    """Resolve the origin slug for the current project, with _local fallback."""

    def test_no_git_falls_back_to_local(self, tmp_path: Path) -> None:
        slug = paths.project_origin_slug(tmp_path)
        # _local/<hash> — exact hash depends on path
        assert slug.startswith("_local/")
        assert len(slug) == len("_local/") + 12

    def test_git_no_origin_falls_back_to_local(self, tmp_path: Path) -> None:
        import subprocess
        subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
        slug = paths.project_origin_slug(tmp_path)
        assert slug.startswith("_local/")

    def test_git_with_origin_returns_normalized_slug(self, tmp_path: Path) -> None:
        import subprocess
        subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
        subprocess.run(
            ["git", "remote", "add", "origin", "git@github.com:slabgorb/pennyfarthing.git"],
            cwd=tmp_path,
            check=True,
        )
        slug = paths.project_origin_slug(tmp_path)
        assert slug == "github.com/slabgorb/pennyfarthing"
```

- [ ] **Step 2: Run tests and confirm RED**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/test_paths.py::TestProjectRoot src/pf/tests/test_paths.py::TestProjectOriginSlug -v
```

Expected: `AttributeError: module 'pf.paths' has no attribute 'project_root'` (and `project_origin_slug`).

- [ ] **Step 3: Implement both functions**

Append to `paths.py`:

```python


def project_root(path: Path | None = None) -> Path:
    """Resolve the working-copy root.

    If ``path`` (or cwd) is inside a git repo, return ``git rev-parse
    --show-toplevel`` as a ``Path``. Otherwise return the resolved
    absolute path of the input. The result is always absolute.
    """
    import subprocess

    start = Path(path).resolve() if path is not None else Path.cwd().resolve()
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=start,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        # git not on PATH — fall back
        return start
    if result.returncode != 0:
        return start
    top = result.stdout.strip()
    if not top:
        return start
    return Path(top).resolve()


def project_origin_slug(path: Path | None = None) -> str:
    """Origin slug for sidecar bucketing.

    Falls back to ``_local/<project_hash>`` when no git remote, no git
    repo, or an unparseable origin URL is detected. Never returns None;
    the caller can use the result directly as a directory name segment.
    """
    import subprocess

    root = project_root(path)
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "remote", "get-url", "origin"],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return f"_local/{project_hash(root)}"
    if result.returncode != 0:
        return f"_local/{project_hash(root)}"
    slug = origin_slug(result.stdout.strip())
    if slug is None:
        return f"_local/{project_hash(root)}"
    return slug
```

- [ ] **Step 4: Run tests and confirm GREEN**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/test_paths.py::TestProjectRoot src/pf/tests/test_paths.py::TestProjectOriginSlug -v
```

Expected: 5 tests PASS.

---

## Task 14: TDD — `pf.paths.runtime_data()`, `session_dir()`, `sidecars_dir()`, `config_path()`

These compose the previous primitives into the actual paths the rest of `pf` will call.

**Files:**
- Modify: `pennyfarthing/runtime/src/pf/tests/test_paths.py`
- Modify: `pennyfarthing/runtime/src/pf/paths.py`

- [ ] **Step 1: Add tests**

Append to `test_paths.py`:

```python


class TestRuntimeData:
    """${CLAUDE_PLUGIN_DATA} with fallback to ~/.claude/data/pf/."""

    def test_uses_env_when_set(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("CLAUDE_PLUGIN_DATA", str(tmp_path / "plugin-data"))
        assert paths.runtime_data() == tmp_path / "plugin-data"

    def test_falls_back_when_env_unset(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("CLAUDE_PLUGIN_DATA", raising=False)
        result = paths.runtime_data()
        assert result == Path.home() / ".claude" / "data" / "pf"

    def test_returns_path_object(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("CLAUDE_PLUGIN_DATA", str(tmp_path))
        assert isinstance(paths.runtime_data(), Path)


class TestComposedPaths:
    """session_dir, sidecars_dir, config_path — composed on the primitives."""

    def test_session_dir_uses_project_hash(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("CLAUDE_PLUGIN_DATA", str(tmp_path))
        sd = paths.session_dir(tmp_path)
        assert sd == tmp_path / "projects" / paths.project_hash(tmp_path) / ".session"

    def test_config_path_uses_project_hash(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("CLAUDE_PLUGIN_DATA", str(tmp_path))
        cp = paths.config_path(tmp_path)
        assert cp == (
            tmp_path / "projects" / paths.project_hash(tmp_path) / "config.local.yaml"
        )

    def test_sidecars_dir_uses_origin_slug(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        import subprocess
        subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
        subprocess.run(
            ["git", "remote", "add", "origin", "git@github.com:slabgorb/foo.git"],
            cwd=tmp_path,
            check=True,
        )
        monkeypatch.setenv("CLAUDE_PLUGIN_DATA", str(tmp_path / "data"))
        sd = paths.sidecars_dir(tmp_path)
        assert sd == tmp_path / "data" / "sidecars" / "github.com/slabgorb/foo"

    def test_sidecars_dir_local_fallback(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("CLAUDE_PLUGIN_DATA", str(tmp_path / "data"))
        sd = paths.sidecars_dir(tmp_path)
        ph = paths.project_hash(tmp_path)
        assert sd == tmp_path / "data" / "sidecars" / "_local" / ph
```

- [ ] **Step 2: Confirm RED**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/test_paths.py::TestRuntimeData src/pf/tests/test_paths.py::TestComposedPaths -v
```

Expected: `AttributeError` for each function.

- [ ] **Step 3: Implement the composed paths**

Append to `paths.py`:

```python


def runtime_data() -> Path:
    """Resolve the runtime-state root.

    Reads ``CLAUDE_PLUGIN_DATA`` (set by Claude Code in plugin hooks);
    falls back to ``~/.claude/data/pf`` when unset (the §5.2 shim case).
    """
    env = os.environ.get("CLAUDE_PLUGIN_DATA")
    if env:
        return Path(env)
    return _FALLBACK_DATA_ROOT


def session_dir(path: Path | None = None) -> Path:
    """Active-session directory for the current working copy."""
    root = project_root(path)
    return runtime_data() / "projects" / project_hash(root) / ".session"


def config_path(path: Path | None = None) -> Path:
    """Local config (``config.local.yaml``) location for current working copy."""
    root = project_root(path)
    return runtime_data() / "projects" / project_hash(root) / "config.local.yaml"


def sidecars_dir(path: Path | None = None) -> Path:
    """Sidecar root for the current project (bucketed by origin slug)."""
    slug = project_origin_slug(path)
    return runtime_data() / "sidecars" / slug
```

- [ ] **Step 4: Confirm GREEN**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/test_paths.py -v
```

Expected: ALL TestPaths tests pass (origin slug + project hash + project root + project origin slug + runtime data + composed paths). No failures.

- [ ] **Step 5: Commit the paths module**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add runtime/src/pf/paths.py runtime/src/pf/tests/test_paths.py
git commit -m "feat(paths): add pf.paths chokepoint for runtime-state resolution

Single Python module that knows how to derive every runtime-state
path. Reads CLAUDE_PLUGIN_DATA (set by Claude Code on plugin hooks)
with fallback to ~/.claude/data/pf/ for the optional outside-plugin
shim. Origin slug normalization and project hash per spec §3.3-3.4.

Functions exposed:
  - origin_slug(url)              normalize a remote URL to host/owner/repo
  - project_root(path)            git toplevel or resolved path
  - project_hash(path)            sha256 of absolute path, 12 chars
  - project_origin_slug(path)     origin slug with _local/<hash> fallback
  - runtime_data()                CLAUDE_PLUGIN_DATA root (with fallback)
  - session_dir(path)             active .session/ for working copy
  - config_path(path)             config.local.yaml location
  - sidecars_dir(path)            sidecar root for the project

Tests cover every form from spec §3.3 and the no-git / no-origin
fallbacks. See: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md §3, §7.2"
```

---

## Task 15: Refactor `config.local.yaml` call sites (6 sites in 5 files)

Per the grep findings, six lines in five files hardcode `<project_root>/.pennyfarthing/config.local.yaml`. Route them through `pf.paths.config_path()`.

**Files:**
- Modify: `runtime/src/pf/context_window.py` (line 135)
- Modify: `runtime/src/pf/settings/settings.py` (lines 133, 161)
- Modify: `runtime/src/pf/bc/focus.py` (lines 80, 117, 338)
- Modify: `runtime/src/pf/core/resolver.py` (line 112)

> Line numbers reflect pre-refactor file state; re-grep before editing if any earlier task touched these files.

For each file, **the literal `Path(...) / ".pennyfarthing" / "config.local.yaml"` becomes `paths.config_path(<that-root>)`**, with `from pf import paths` added to the imports.

- [ ] **Step 1: Confirm exact call-site list before editing**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
grep -n '"\.pennyfarthing" *\/ *"config\.local\.yaml"' src/pf/context_window.py src/pf/settings/settings.py src/pf/bc/focus.py src/pf/core/resolver.py
```

Expected: 7 lines listed (1 in context_window.py + 2 in settings/settings.py + 3 in bc/focus.py + 1 in core/resolver.py).

> **If grep reports a different count from what is documented here, do not silently adjust scope.** The plan was written from inference and a re-grep at execution time supersedes this list. Update the list, then proceed.

- [ ] **Step 2: Edit `context_window.py:135`**

Locate the existing line:

```python
    yaml_path = Path(project_dir) / ".pennyfarthing" / "config.local.yaml"
```

Replace with:

```python
    yaml_path = paths.config_path(Path(project_dir))
```

Add `from pf import paths` to the imports if not already present (place near the top of the file with the other absolute-import lines).

- [ ] **Step 3: Edit `settings/settings.py:133` and `:161`**

Both lines look like:

```python
    config_path = root / ".pennyfarthing" / "config.local.yaml"
```

Replace each with:

```python
    config_path = paths.config_path(root)
```

Add the import: `from pf import paths`.

> **Naming clash:** the local variable is named `config_path` and `pf.paths.config_path` is now a function with the same name. The reassignment still works (`config_path = paths.config_path(root)`) but the local name shadows the function on subsequent calls within scope. If a single function reads the config twice, hoist to a different local name (`config_yaml = paths.config_path(root)`) to avoid confusion. Inspect each call site's usage before deciding.

- [ ] **Step 4: Edit `bc/focus.py:80`, `:117`, `:338`**

Same pattern — three sites in `focus.py`. Each looks like:

```python
    config_path = root / ".pennyfarthing" / "config.local.yaml"
```

Replace with:

```python
    config_path = paths.config_path(root)
```

Add `from pf import paths` if absent.

- [ ] **Step 5: Edit `core/resolver.py:112`**

Same pattern. Replace and add import.

- [ ] **Step 6: Run the existing test suite to catch regressions**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/ -x --ignore=src/pf/tests/test_paths.py 2>&1 | tail -40
```

Expected: same number of tests pass as the Task 1 baseline. **Do not proceed if any test that previously passed now fails.** Many existing tests construct their own fake `.pennyfarthing/` trees in tmp dirs and pass `project_dir`/`root` arguments to the refactored functions — those tests still exercise the legacy path layout because they pre-populate the test's `tmp_path / ".pennyfarthing/"` directory, which `paths.config_path` will *not* read.

This means **some tests may legitimately need updates** to match the new path layout. For each failing test:

  - Read the test fixture setup.
  - If the test was writing to `tmp_path / ".pennyfarthing" / "config.local.yaml"`, it must now write to `paths.config_path(tmp_path)` instead (likely requires `monkeypatch.setenv("CLAUDE_PLUGIN_DATA", str(tmp_path / "data"))` so the test controls where the runtime data lands).
  - Update the test fixture, not the production code. Confirm GREEN.

Count expected fixture updates: ~3–6 tests across `test_paths.py`-adjacent test files (the production refactor unblocked them; the fixtures need to match). If you find more than ~10, **stop and surface** — the refactor scope may be wider than the plan accounted for.

- [ ] **Step 7: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add runtime/src/pf/context_window.py runtime/src/pf/settings/settings.py runtime/src/pf/bc/focus.py runtime/src/pf/core/resolver.py runtime/src/pf/tests/
git commit -m "refactor(paths): route config.local.yaml reads through pf.paths

7 call sites across 4 files now use paths.config_path() instead of
hardcoded Path(...) / '.pennyfarthing' / 'config.local.yaml'. Test
fixtures updated for tests that materialized the old layout in tmp
dirs.

This is the start of the §7.2 chokepoint refactor. Legacy install
sites (init/, upgrade/, doctor/) are intentionally left untouched and
will be removed in Plans 3-4 when the .pennyfarthing/ directory is
no longer created at all.

See: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md §7.2"
```

---

## Task 16: Refactor `persona-config.yaml` call site (1 site)

Spec §7.2 names `config.local.yaml` explicitly; `persona-config.yaml` lives alongside it in `config_migration.py`. Treat as the same chokepoint.

**Files:**
- Modify: `runtime/src/pf/config_migration.py` (lines 31, 36)

- [ ] **Step 1: Read the current usage**

Open `runtime/src/pf/config_migration.py` and read lines 25–60 to understand the context (likely a migration helper that reads both YAMLs).

- [ ] **Step 2: Decide whether to add a `paths.persona_config_path()` helper**

If the code reads `persona-config.yaml` in exactly one place (this file), inline the path: `paths.runtime_data() / "projects" / paths.project_hash(paths.project_root(root)) / "persona-config.yaml"`. That is verbose; instead, add a helper:

In `runtime/src/pf/paths.py`, append:

```python


def persona_config_path(path: Path | None = None) -> Path:
    """Optional persona-overlay config (``persona-config.yaml``).

    Co-located with ``config.local.yaml`` because it is per-working-copy
    user preference. Returns the same directory ``config_path`` returns,
    with the persona filename.
    """
    return config_path(path).with_name("persona-config.yaml")
```

Add a matching test in `test_paths.py` (mirror the `test_config_path_uses_project_hash` pattern but expect `persona-config.yaml`).

- [ ] **Step 3: Run paths tests**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/test_paths.py -v
```

Expected: new test plus existing tests all pass.

- [ ] **Step 4: Refactor `config_migration.py`**

Replace lines 31 and 36 patterns:

```python
        config_path = project_root / ".pennyfarthing" / "config.local.yaml"
```
becomes
```python
        config_path = paths.config_path(project_root)
```

and:
```python
        persona_config = project_root / ".pennyfarthing" / "persona-config.yaml"
```
becomes
```python
        persona_config = paths.persona_config_path(project_root)
```

Add `from pf import paths`.

- [ ] **Step 5: Run pytest and confirm GREEN**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/ -x 2>&1 | tail -20
```

Expected: full test suite green.

- [ ] **Step 6: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add runtime/src/pf/paths.py runtime/src/pf/config_migration.py runtime/src/pf/tests/test_paths.py
git commit -m "refactor(paths): route persona-config.yaml through pf.paths

Add persona_config_path() helper co-located with config_path()
(same per-working-copy directory, different filename). Update the
one call site in config_migration.py."
```

---

## Task 17: Sweep for session and sidecar reads

The two remaining runtime-state categories from spec §3.2 are *active session* and *sidecars*. Find every read site and route through `paths.session_dir()` / `paths.sidecars_dir()`.

**Files:**
- Modify: any file that reads `<project_root>/.session/...` or sidecar files

- [ ] **Step 1: Find session-reading call sites**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
grep -rn '"\.session"' src/pf/ --include="*.py" | grep -v "__pycache__" | grep -v "tests/"
grep -rn '/ "\.session"\|/.session/' src/pf/ --include="*.py" | grep -v "__pycache__" | grep -v "tests/"
```

Record every match. Filter manually to runtime-state reads (the session file the active agent is writing to). Tests that build a fake `.session/` in tmp dirs are NOT in scope here — they exercise the abstraction and adapt in Step 4 below.

- [ ] **Step 2: Find sidecar-reading call sites**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
grep -rn 'sidecars' src/pf/ --include="*.py" | grep -v "__pycache__" | grep -v "tests/"
grep -rn '\.pennyfarthing/sidecars' src/pf/ --include="*.py" | grep -v "__pycache__"
```

Record every match.

- [ ] **Step 3: Refactor each match**

For session-file reads:

```python
session_file = project_root / ".session" / f"{story_id}-session.md"
# becomes
session_file = paths.session_dir(project_root) / f"{story_id}-session.md"
```

For sidecar reads:

```python
sidecar_path = project_root / ".pennyfarthing" / "sidecars" / agent / "patterns.md"
# becomes
sidecar_path = paths.sidecars_dir(project_root) / agent / "patterns.md"
```

Add `from pf import paths` where missing.

- [ ] **Step 4: Update test fixtures**

Test files that materialize `tmp_path / ".session" / "..."` directly need to instead set `CLAUDE_PLUGIN_DATA` and write to `paths.session_dir(tmp_path)`. Same pattern as Task 15 Step 6.

- [ ] **Step 5: Full suite green**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/ -x 2>&1 | tail -20
```

Expected: baseline count of tests pass (Task 1 baseline plus the new `pf.paths` tests).

- [ ] **Step 6: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add runtime/src/pf/
git commit -m "refactor(paths): route session and sidecar reads through pf.paths

Completes the §7.2 chokepoint for runtime-state reads. All session
files and sidecars are now resolved via paths.session_dir() and
paths.sidecars_dir() — single chokepoint that knows about
CLAUDE_PLUGIN_DATA vs. the ~/.claude/data/pf/ fallback.

Test fixtures updated for tests that pre-populated tmp-dir layouts;
they now monkeypatch CLAUDE_PLUGIN_DATA and write to the
paths-resolved locations."
```

---

## Task 18: Tag legacy-install call sites for later removal

The remaining `.pennyfarthing/` references in `init/`, `upgrade/`, `doctor/`, `agent_create.py`, `benchmark/`, `bmad/`, `tui/`, `extensions.py`, `handoff/gate_file.py`, `handoff/resolve_gate.py`, `handoff/complete_phase.py`, `healthscore/analyze.py` are about reading or writing the legacy `.pennyfarthing/` directory itself. **Plan 2 does not refactor them.** They get removed in Plans 3–4 when the plugin model no longer creates that directory.

To prevent confusion (and future scope creep), tag them with a comment.

- [ ] **Step 1: List the legacy-install files**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
grep -rln '"\.pennyfarthing"' src/pf/ --include="*.py" | grep -v "__pycache__" | grep -v "tests/" | sort
```

Expected: ~15 files. (Inspect the list before scripting any tags.)

- [ ] **Step 2: Add a single top-of-file comment to each**

For each file in the list, add immediately below the module docstring (or at the top if no docstring):

```python
# NOTE: This module still references the legacy ``.pennyfarthing/`` directory
# layout. The references are intentional — this module reads/writes the
# legacy install. Plans 3-4 of the plugin migration remove this module's
# need to know about ``.pennyfarthing/`` entirely. Do not refactor these
# references to pf.paths in Plan 2; they refer to install artifacts, not
# runtime state.
```

If a file has only one or two legacy-install references but ALSO has runtime-state references that Plan 2 already refactored, do not add the blanket comment — instead add a single-line comment on each remaining legacy reference:

```python
    # legacy install path — removed in Plans 3-4
    pf_dir = root / ".pennyfarthing"
```

Use judgment: the comment is documentation, not code, and over-commenting hurts more than helps.

- [ ] **Step 3: Confirm no behavior change**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/ -x 2>&1 | tail -10
```

Expected: full test suite still green; comments don't affect runtime.

- [ ] **Step 4: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add runtime/src/pf/
git commit -m "docs(paths): tag legacy .pennyfarthing/ call sites for Plans 3-4

Plan 2's pf.paths chokepoint covers runtime state (session, sidecars,
config). The remaining .pennyfarthing/ references belong to the
legacy install layer (init, upgrade, doctor, agent_create, benchmark
fixtures, etc.) and are removed wholesale in Plans 3-4. Tagged here
so future readers don't mistake the leftover references for missed
refactors."
```

---

## Task 19: Run the full test suite and capture coverage baseline

- [ ] **Step 1: Full test run**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/runtime
uv run pytest src/pf/tests/ -v 2>&1 | tail -30
```

Expected: all tests that passed at Task 1 baseline still pass, PLUS the new `test_paths.py` tests. Total = baseline + ~25 new tests.

If any pre-existing test fails, **stop and investigate**. The failure may be:
- A test that pre-built a `.pennyfarthing/` layout that Plan 2's refactor no longer reads from. → Update fixture (see Task 15 Step 6).
- A test that imports a runtime-state path the refactor changed. → Update test.
- A real production-code regression. → Fix in production code, not the test.

- [ ] **Step 2: Compare count to baseline**

The expected delta is positive (new paths tests added) — no tests should have disappeared. If a test that previously collected is now missing from the collect-only count, identify it and explain (probably a file rename collateral; restore the test).

- [ ] **Step 3: Validate the plugin manifest one more time**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
claude plugin validate .
```

Expected: `✔ Validation passed`.

---

## Task 20: Final commit and hand off to Plan 3

- [ ] **Step 1: Push the branch**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git push -u origin feat/plugin-scaffold-and-paths
```

Expected: push succeeds. The pennyfarthing repo's branch strategy targets `develop`, so a PR (if Keith wants one) opens against `develop`, not `main`.

- [ ] **Step 2: Verify git history is clean**

```bash
git log --oneline develop..HEAD
```

Expected: a handful of commits — scaffold, paths module, config refactor, persona-config refactor, session+sidecar refactor, legacy tags, plus optional fix-up commits. No fixup-of-fixup churn.

- [ ] **Step 3: Trigger Plan 3 authoring**

Open a new architect session and invoke `superpowers:writing-plans` with this context:

```
Generate Plan 3 of 4 (Content migration + drop pf- prefix) for the
pennyfarthing-as-plugin migration.

Spec: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md
Spike: docs/superpowers/spikes/2026-05-21-plugin-spike-results.md
Plan 2 (just landed): docs/superpowers/plans/2026-05-21-plugin-scaffold-and-paths.md

Plan 3 scope:
- Move runtime/src/pf/_dist/agents/* → agents/* (plugin root)
- Move runtime/src/pf/_dist/commands/* → commands/* and drop the
  pf- prefix on filenames (so /pf:work resolves to commands/work.md,
  not commands/pf-work.md)
- Move runtime/src/pf/_dist/skills/* → skills/* and drop the pf-
  prefix (so the Skill tool finds /pf:sprint via skills/sprint/SKILL.md)
- Move runtime/src/pf/_dist/{gates,guides,personas,workflows,
  templates,output-styles,schemas,scripts}/* → corresponding
  plugin-root dirs (siblings of runtime/)
- Update any Python imports of pf._dist that break after the move
  (the pf._dist namespace likely goes away entirely)
- Update /pf-foo references in agents/skills/commands markdown to /pf:foo
- pennyfarthing-dist/ is empty after Plan 2; delete the directory
  outright at the end of Plan 3.

Plan 3 does NOT yet rewrite hooks — that is Plan 4.
```

- [ ] **Step 4: This plan ends here.**

---

## Acceptance Criteria

Plan 2 is complete when all of the following are true:

1. `pennyfarthing/.claude-plugin/plugin.json` and `pennyfarthing/.claude-plugin/marketplace.json` exist and pass `claude plugin validate`.
2. `pennyfarthing/runtime/pyproject.toml` and `pennyfarthing/runtime/uv.lock` exist; `runtime/.venv/` is gitignored, not committed.
3. `pennyfarthing/runtime/src/pf/` contains the Python package (history preserved via `git mv` — `git log --follow runtime/src/pf/cli.py` traces back to `pennyfarthing-dist/src/pf/cli.py`).
4. `pennyfarthing-dist/pyproject.toml`, `pennyfarthing-dist/setup.py`, and `pennyfarthing-dist/src/pf_launcher.py` are deleted.
5. `pennyfarthing/runtime/src/pf/paths.py` exists with the documented function set; `pennyfarthing/runtime/src/pf/tests/test_paths.py` exists and passes.
6. Every read of `config.local.yaml`, `persona-config.yaml`, `.session/`, or sidecars in `runtime/src/pf/` goes through `pf.paths` (verified by a final grep for `".pennyfarthing"` showing only legacy-install references, all tagged with the explanatory comment).
7. The full pre-existing pytest suite still passes (baseline from Task 1 Step 5), plus the new `test_paths.py` tests.
8. All commits are GPG-signed and follow the `<type>(<scope>): <subject>` format.
9. The branch is pushed to `origin/feat/plugin-scaffold-and-paths` (off `develop`, not `main`).

---

## Notes for the Executor

- **Branching:** `pennyfarthing/` uses gitflow; all of Plan 2 happens on `feat/plugin-scaffold-and-paths` off `develop`. If the repo is on a different branch at start, **switch to develop and pull before doing anything**.
- **No legacy install considerations.** There is no `pip install`, `pipx install`, or npm package for pennyfarthing. The Dev sidecar's `pf-install-dual` gotcha is stale. Do NOT add transition shims to keep `pennyfarthing-dist/pyproject.toml` valid.
- **No migration tooling.** Plan 5 (`pf migrate-from-legacy`) is descoped. Do NOT add `--dry-run` flags, scanner logic, or any per-project migration helper.
- **`uv.lock` IS committed; `.venv` is NOT.** First-run dep install happens lazily in the consumer's hook environment (validated by Gate 1 spike).
- **Run pytest after every refactor commit.** The chokepoint refactor changes behavior for tests that pre-build the old layout in tmp dirs; fix the fixtures, not the production code.
- **If anything in the spec contradicts what the spike found**, trust the spike. The spec was amended on 2026-05-21 with spike findings (commit `a46d23e` in orc-penny). If you find spec text that wasn't amended but contradicts the spike results, flag it and update the spec rather than working around it.
- **Filename references in the plan are the pre-refactor state.** If an earlier task in the plan touched a file before you reach a later task that names the same file, re-grep before editing — line numbers in particular will have shifted.
- **Do not touch agents/commands/skills/etc. in Plan 2.** Those move in Plan 3.
- **Do not touch hooks in Plan 2.** Those move in Plan 4.
