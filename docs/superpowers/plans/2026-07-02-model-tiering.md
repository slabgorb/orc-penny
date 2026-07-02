# Model Tiering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Central `models.yaml` tier map driving every model assignment in Pennyfarthing (commands, subagents, validators, benchmarks, advisory hook), replacing scattered hardcodes from the pre-Claude-5 era.

**Architecture:** One YAML file in `pennyfarthing-dist/` maps capability tiers (judgment/heavyweight/analytical/mechanical) to Claude Code model *aliases* (`best`/`opus`/`sonnet`/`haiku`) and roles to tiers. A loader module (`pf/model_tiers.py`) resolves names → aliases; validators enforce that every frontmatter/hardcode projection matches the map; an advisory hook nudges (never blocks) when the interactive session's model mismatches the active phase's tier.

**Tech Stack:** Python 3.14, click, PyYAML, pytest. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-02-model-tiering-design.md` (orchestrator repo)

## Global Constraints

- Two repos: framework work in `pennyfarthing/` (branch `feat/model-tiering` off `develop`, PR → `develop`); doc-only Tasks 11 in the orchestrator repo (branch off `main`, PR → `main`). All framework paths below are relative to `pennyfarthing/pennyfarthing-dist/`.
- **NEVER run the bare full pytest suite** — `test_git_utils.py` leaks a `feature/test` checkout onto the live repo. Run ONLY the targeted test files named in each task, from `pennyfarthing/pennyfarthing-dist/`: `uv run pytest src/pf/tests/<file> -v`.
- pf functions return result objects `{success, data?, error?}` — never throw for expected failures.
- pf hands Claude Code **aliases** (`best`, `opus`, `sonnet`, `haiku`), never pinned `claude-*` IDs. Alias→model resolution is Claude Code's job.
- Hooks are fail-soft: any error → no output, exit 0. Advisory hooks emit `additionalContext` only, never permission decisions (mirror `pf/hooks/advisory_never_edit_zone.py`).
- Do not name anything `tiers.py` — `pf/prime/tiers.py` already exists (context tiers, unrelated). The new module is `pf/model_tiers.py`.
- Commit signing must never be skipped. Commit format `<type>(<scope>): <subject>`.
- The tier assignments themselves (who gets `best`, the reviewer-preflight downgrade) are decided in the spec — do not re-litigate them here.

---

### Task 1: Tier map file + loader/resolver module

**Files:**
- Create: `models.yaml` (i.e. `pennyfarthing/pennyfarthing-dist/models.yaml`)
- Create: `src/pf/model_tiers.py`
- Test: `src/pf/tests/test_model_tiers.py`

**Interfaces:**
- Produces: `load_model_map(project_root: Path | None = None) -> dict` (result object, `data` = merged map dict)
- Produces: `resolve_tier_alias(tier: str, model_map: dict) -> dict` (result object, `data` = alias str)
- Produces: `resolve_model(kind: str, name: str, project_root: Path | None = None) -> dict` (result object, `data` = `{"tier": str, "alias": str}`; `kind` ∈ `"agent" | "subagent" | "judge" | "native"`)
- Produces: `VALID_ALIASES = {"haiku", "sonnet", "opus", "fable", "best", "inherit"}` (module constant, imported by Tasks 2–3)
- Consumes: `pf.common.config.get_dist_root`, `load_yaml_config`, `load_pennyfarthing_config` (exist at `src/pf/common/config.py:69,124,140`)

- [ ] **Step 1: Write `models.yaml`**

```yaml
# models.yaml — single source of truth for model policy (SOUL #2, #4).
# Tiers map to Claude Code ALIASES (never pinned claude-* IDs); Claude Code
# resolves aliases per provider. `best` = Fable 5 where available, else Opus.
# Per-install override: `models:` section in .pennyfarthing/config.local.yaml
# (shallow merge per section key).
# Spec: docs/superpowers/specs/2026-07-02-model-tiering-design.md (orchestrator)

tiers:
  judgment: best      # decisions that cascade — design, adversarial review, planning
  heavyweight: opus   # deep execution — real reasoning, not judgment
  analytical: sonnet  # analytical middle
  mechanical: haiku   # runners, setup, summaries

agents: # main-session phase agents → /pf-* command frontmatter
  architect: judgment
  reviewer: judgment
  pm: judgment
  tea: judgment # red = test design; verify overspend is small (runners are haiku)
  dev: heavyweight
  sm: analytical
  ba: analytical
  ux-designer: analytical
  tech-writer: analytical
  devops: analytical
  orchestrator: analytical

subagents: # exact name beats glob; two matching globs = validation error
  "reviewer-*": analytical
  reviewer-preflight: mechanical # downgrade from sonnet — gathers diff stats
  tandem-backseat: analytical
  testing-runner: mechanical
  "sm-*": mechanical
  "simplify-*": mechanical

judges:
  benchmark: heavyweight # scoring consistency > peak brilliance
  peloton: heavyweight

native_agents: judgment # agents/native/*.md
```

- [ ] **Step 2: Write the failing tests**

```python
"""Tests for pf.model_tiers — central model tier map loader/resolver.

Spec: docs/superpowers/specs/2026-07-02-model-tiering-design.md (orchestrator).
"""

from pathlib import Path
from unittest.mock import patch

import pytest
import yaml

from pf.model_tiers import VALID_ALIASES, load_model_map, resolve_model, resolve_tier_alias

MINIMAL_MAP = {
    "tiers": {"judgment": "best", "heavyweight": "opus", "analytical": "sonnet", "mechanical": "haiku"},
    "agents": {"dev": "heavyweight", "architect": "judgment"},
    "subagents": {"reviewer-*": "analytical", "reviewer-preflight": "mechanical", "sm-*": "mechanical"},
    "judges": {"benchmark": "heavyweight"},
    "native_agents": "judgment",
}


@pytest.fixture
def dist(tmp_path: Path) -> Path:
    """tmp project with a dist root holding models.yaml."""
    dist_root = tmp_path / "pennyfarthing-dist"
    dist_root.mkdir()
    (dist_root / "models.yaml").write_text(yaml.dump(MINIMAL_MAP))
    return tmp_path


def _patched(tmp_root: Path):
    return (
        patch("pf.model_tiers.get_dist_root", return_value=tmp_root / "pennyfarthing-dist"),
        patch("pf.model_tiers.load_pennyfarthing_config", return_value={}),
    )


class TestLoadModelMap:
    def test_loads_dist_models_yaml(self, dist: Path) -> None:
        p1, p2 = _patched(dist)
        with p1, p2:
            result = load_model_map(dist)
        assert result["success"] is True
        assert result["data"]["tiers"]["heavyweight"] == "opus"

    def test_missing_file_fails_loudly(self, dist: Path) -> None:
        (dist / "pennyfarthing-dist" / "models.yaml").unlink()
        p1, p2 = _patched(dist)
        with p1, p2:
            result = load_model_map(dist)
        assert result["success"] is False
        assert "models.yaml" in result["error"]

    def test_config_local_override_merges_per_section(self, dist: Path) -> None:
        override = {"models": {"tiers": {"heavyweight": "sonnet"}}}
        p1 = patch("pf.model_tiers.get_dist_root", return_value=dist / "pennyfarthing-dist")
        p2 = patch("pf.model_tiers.load_pennyfarthing_config", return_value=override)
        with p1, p2:
            result = load_model_map(dist)
        assert result["data"]["tiers"]["heavyweight"] == "sonnet"
        assert result["data"]["tiers"]["judgment"] == "best"  # untouched keys survive


class TestResolveTierAlias:
    def test_known_tier(self) -> None:
        result = resolve_tier_alias("mechanical", MINIMAL_MAP)
        assert result == {"success": True, "data": "haiku"}

    def test_unknown_tier_lists_valid_set(self) -> None:
        result = resolve_tier_alias("galactic", MINIMAL_MAP)
        assert result["success"] is False
        assert "analytical" in result["error"]


class TestResolveModel:
    def test_agent(self, dist: Path) -> None:
        p1, p2 = _patched(dist)
        with p1, p2:
            result = resolve_model("agent", "dev", dist)
        assert result["data"] == {"tier": "heavyweight", "alias": "opus"}

    def test_subagent_exact_beats_glob(self, dist: Path) -> None:
        p1, p2 = _patched(dist)
        with p1, p2:
            result = resolve_model("subagent", "reviewer-preflight", dist)
        assert result["data"]["alias"] == "haiku"  # exact 'mechanical', not glob 'analytical'

    def test_subagent_glob_match(self, dist: Path) -> None:
        p1, p2 = _patched(dist)
        with p1, p2:
            result = resolve_model("subagent", "reviewer-security", dist)
        assert result["data"]["alias"] == "sonnet"

    def test_subagent_double_glob_is_error(self, dist: Path) -> None:
        bad = dict(MINIMAL_MAP)
        bad["subagents"] = {"reviewer-*": "analytical", "*-security": "mechanical"}
        (dist / "pennyfarthing-dist" / "models.yaml").write_text(yaml.dump(bad))
        p1, p2 = _patched(dist)
        with p1, p2:
            result = resolve_model("subagent", "reviewer-security", dist)
        assert result["success"] is False
        assert "multiple globs" in result["error"]

    def test_native(self, dist: Path) -> None:
        p1, p2 = _patched(dist)
        with p1, p2:
            result = resolve_model("native", "architect", dist)
        assert result["data"]["alias"] == "best"

    def test_judge(self, dist: Path) -> None:
        p1, p2 = _patched(dist)
        with p1, p2:
            result = resolve_model("judge", "benchmark", dist)
        assert result["data"]["alias"] == "opus"

    def test_unknown_name_fails(self, dist: Path) -> None:
        p1, p2 = _patched(dist)
        with p1, p2:
            result = resolve_model("agent", "nonexistent", dist)
        assert result["success"] is False

    def test_unknown_kind_fails(self, dist: Path) -> None:
        p1, p2 = _patched(dist)
        with p1, p2:
            result = resolve_model("wizard", "dev", dist)
        assert result["success"] is False


def test_valid_aliases_constant() -> None:
    assert VALID_ALIASES == {"haiku", "sonnet", "opus", "fable", "best", "inherit"}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_model_tiers.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'pf.model_tiers'`

- [ ] **Step 4: Write `src/pf/model_tiers.py`**

```python
"""Model tier map — single source of truth for model policy.

Loads pennyfarthing-dist/models.yaml, applies the optional ``models:``
override section from .pennyfarthing/config.local.yaml (shallow merge per
section key), and resolves agent/subagent/judge names to Claude Code model
ALIASES (best/opus/sonnet/haiku). Alias→model resolution is Claude Code's
job — never pin claude-* IDs here.

Not to be confused with pf.prime.tiers (context tiers).

Spec: docs/superpowers/specs/2026-07-02-model-tiering-design.md (orchestrator).
"""

from __future__ import annotations

from fnmatch import fnmatch
from pathlib import Path
from typing import Any

from pf.common.config import get_dist_root, load_pennyfarthing_config, load_yaml_config

VALID_ALIASES = {"haiku", "sonnet", "opus", "fable", "best", "inherit"}


def load_model_map(project_root: Path | None = None) -> dict[str, Any]:
    """Load models.yaml merged with the config.local.yaml ``models:`` override."""
    dist_root = get_dist_root(project_root)
    if dist_root is None:
        return {"success": False, "error": "pennyfarthing-dist root not found"}
    path = dist_root / "models.yaml"
    base = load_yaml_config(path)
    if base is None:
        return {"success": False, "error": f"models.yaml not found at {path}"}
    merged = dict(base)
    override = load_pennyfarthing_config(project_root).get("models") or {}
    for section, values in override.items():
        if isinstance(values, dict) and isinstance(merged.get(section), dict):
            merged[section] = {**merged[section], **values}
        else:
            merged[section] = values
    return {"success": True, "data": merged}


def resolve_tier_alias(tier: str, model_map: dict[str, Any]) -> dict[str, Any]:
    """Map a tier name to its model alias."""
    tiers = model_map.get("tiers") or {}
    alias = tiers.get(tier)
    if alias is None:
        return {
            "success": False,
            "error": f"Unknown tier '{tier}' (valid: {sorted(tiers)})",
        }
    return {"success": True, "data": str(alias)}


def _subagent_tier(name: str, subagents: dict[str, Any]) -> dict[str, Any]:
    if name in subagents:
        return {"success": True, "data": subagents[name]}
    globs = [k for k in subagents if "*" in k and fnmatch(name, k)]
    if len(globs) > 1:
        return {
            "success": False,
            "error": f"Subagent '{name}' matches multiple globs: {sorted(globs)}",
        }
    if not globs:
        return {"success": False, "error": f"No subagent tier mapping for '{name}'"}
    return {"success": True, "data": subagents[globs[0]]}


def resolve_model(kind: str, name: str, project_root: Path | None = None) -> dict[str, Any]:
    """Resolve a name to {tier, alias}. kind: agent | subagent | judge | native."""
    loaded = load_model_map(project_root)
    if not loaded["success"]:
        return loaded
    m = loaded["data"]

    if kind == "native":
        tier = m.get("native_agents")
        if tier is None:
            return {"success": False, "error": "models.yaml missing 'native_agents'"}
    elif kind == "subagent":
        found = _subagent_tier(name, m.get("subagents") or {})
        if not found["success"]:
            return found
        tier = found["data"]
    elif kind in ("agent", "judge"):
        section = "agents" if kind == "agent" else "judges"
        tier = (m.get(section) or {}).get(name)
        if tier is None:
            return {"success": False, "error": f"No {kind} tier mapping for '{name}'"}
    else:
        return {"success": False, "error": f"Unknown kind '{kind}'"}

    alias = resolve_tier_alias(str(tier), m)
    if not alias["success"]:
        return alias
    return {"success": True, "data": {"tier": str(tier), "alias": alias["data"]}}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_model_tiers.py -v`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git checkout -b feat/model-tiering develop
git add pennyfarthing-dist/models.yaml pennyfarthing-dist/src/pf/model_tiers.py pennyfarthing-dist/src/pf/tests/test_model_tiers.py
git commit -m "feat(models): central model tier map + loader (models.yaml, pf.model_tiers)"
```

---

### Task 2: Validate adapter for models.yaml

**Files:**
- Create: `src/pf/validate/adapters/models.py`
- Modify: `src/pf/validate/cli.py:28-40` (VALIDATORS dict — add one entry)
- Test: `src/pf/tests/test_validate_models_adapter.py`

**Interfaces:**
- Consumes: `pf.model_tiers.load_model_map`, `VALID_ALIASES` (Task 1)
- Produces: `run(root: Path, *, fix: bool = False, strict: bool = False) -> ValidateReport` — same adapter contract as `validate/adapters/adr.py:112`. Registered under the name `"models"`.

- [ ] **Step 1: Write the failing tests**

```python
"""Tests for the models.yaml validate adapter."""

from pathlib import Path
from unittest.mock import patch

import yaml

GOOD_MAP = {
    "tiers": {"judgment": "best", "heavyweight": "opus", "analytical": "sonnet", "mechanical": "haiku"},
    "agents": {"dev": "heavyweight"},
    "subagents": {"reviewer-*": "analytical"},
    "judges": {"benchmark": "heavyweight"},
    "native_agents": "judgment",
}


def _run(map_dict):
    from pf.validate.adapters.models import run

    with patch(
        "pf.validate.adapters.models.load_model_map",
        return_value={"success": True, "data": map_dict},
    ):
        return run(Path("/nonexistent"))


def test_good_map_passes() -> None:
    report = _run(GOOD_MAP)
    assert report.errors == []


def test_tier_alias_must_be_valid() -> None:
    bad = {**GOOD_MAP, "tiers": {**GOOD_MAP["tiers"], "judgment": "gpt-5"}}
    report = _run(bad)
    assert any("gpt-5" in e for e in report.errors)


def test_claude_full_name_allowed_as_tier_alias() -> None:
    ok = {**GOOD_MAP, "tiers": {**GOOD_MAP["tiers"], "judgment": "claude-fable-5"}}
    report = _run(ok)
    assert report.errors == []


def test_assignment_must_reference_known_tier() -> None:
    bad = {**GOOD_MAP, "agents": {"dev": "galactic"}}
    report = _run(bad)
    assert any("galactic" in e for e in report.errors)


def test_native_agents_must_reference_known_tier() -> None:
    bad = {**GOOD_MAP, "native_agents": "galactic"}
    report = _run(bad)
    assert any("native_agents" in e for e in report.errors)


def test_load_failure_is_error() -> None:
    from pf.validate.adapters.models import run

    with patch(
        "pf.validate.adapters.models.load_model_map",
        return_value={"success": False, "error": "models.yaml not found at /x"},
    ):
        report = run(Path("/nonexistent"))
    assert any("not found" in e for e in report.errors)


def test_registered_in_validators() -> None:
    from pf.validate.cli import VALIDATORS

    assert VALIDATORS["models"] == "pf.validate.adapters.models"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_validate_models_adapter.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'pf.validate.adapters.models'`

- [ ] **Step 3: Write the adapter**

```python
"""models.yaml structural validator adapter.

Checks: every tier maps to a valid Claude Code alias (or explicit claude-*
name); every agents/subagents/judges assignment and native_agents references
a defined tier.

Spec: docs/superpowers/specs/2026-07-02-model-tiering-design.md (orchestrator).
"""

from __future__ import annotations

from pathlib import Path

from pf.model_tiers import VALID_ALIASES, load_model_map
from pf.validate import ValidateReport


def run(root: Path, *, fix: bool = False, strict: bool = False) -> ValidateReport:
    report = ValidateReport(validator="models")
    loaded = load_model_map(root)
    if not loaded["success"]:
        report.errors.append(loaded["error"])
        return report
    m = loaded["data"]

    tiers = m.get("tiers") or {}
    if not tiers:
        report.errors.append("models.yaml has no 'tiers' section")
        return report

    for tier, alias in tiers.items():
        alias_s = str(alias)
        if alias_s not in VALID_ALIASES and not alias_s.startswith("claude-"):
            report.errors.append(
                f"tiers.{tier}: '{alias_s}' is not a valid alias "
                f"(valid: {sorted(VALID_ALIASES)}) or claude-* model name"
            )

    for section in ("agents", "subagents", "judges"):
        for name, tier in (m.get(section) or {}).items():
            if str(tier) not in tiers:
                report.errors.append(
                    f"{section}.{name}: unknown tier '{tier}' (valid: {sorted(tiers)})"
                )

    native = m.get("native_agents")
    if native is None:
        report.errors.append("models.yaml missing 'native_agents'")
    elif str(native) not in tiers:
        report.errors.append(
            f"native_agents: unknown tier '{native}' (valid: {sorted(tiers)})"
        )

    return report
```

- [ ] **Step 4: Register the adapter** — in `src/pf/validate/cli.py`, add to the VALIDATORS dict (after the `"agent"` entry at line 30):

```python
    "models": "pf.validate.adapters.models",
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_validate_models_adapter.py -v`
Expected: all PASS. Also run: `uv run pf validate models` — Expected: 0 errors against the real models.yaml.

- [ ] **Step 6: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/validate/ pennyfarthing-dist/src/pf/tests/test_validate_models_adapter.py
git commit -m "feat(validate): models.yaml adapter — tier aliases and assignments"
```

---

### Task 3: Agent validator — Claude 5 alias set + frontmatter checked against the map

**Files:**
- Modify: `src/pf/validate/adapters/agent.py:19` (VALID_MODELS), `:381-386` (subagent model check), `:423-428` (native model check)
- Modify: `agents/reviewer-preflight.md:5` (`model: sonnet` → `model: haiku` — the map-driven downgrade; this task's validator change is what catches the drift)
- Test: `src/pf/tests/test_validate_agent_models.py`

**Interfaces:**
- Consumes: `pf.model_tiers.VALID_ALIASES`, `resolve_model` (Task 1)
- Produces: subagent files whose stem has a `subagents:` mapping get an ERROR when frontmatter model ≠ mapped alias; native agents get a WARNING when frontmatter model ≠ the `native_agents` tier alias (replacing the hardcoded `expected 'opus'`).

- [ ] **Step 1: Write the failing tests**

```python
"""Tests for agent validator model checks against the tier map."""

from pathlib import Path
from unittest.mock import patch


def _write_subagent(tmp_path: Path, name: str, model: str) -> Path:
    p = tmp_path / f"{name}.md"
    p.write_text(
        f"---\nname: {name}\ndescription: x\ntools: Read\nmodel: {model}\n---\n"
        "<arguments>\n| a | b | c |\n</arguments>\n<output>\nx\n</output>\n"
    )
    return p


def test_valid_models_includes_claude5_aliases() -> None:
    from pf.validate.adapters.agent import VALID_MODELS

    assert {"fable", "best", "inherit"} <= VALID_MODELS


def test_subagent_model_drift_from_map_is_error(tmp_path: Path) -> None:
    from pf.validate.adapters.agent import validate_subagent

    p = _write_subagent(tmp_path, "reviewer-preflight", "sonnet")
    with patch(
        "pf.validate.adapters.agent.resolve_model",
        return_value={"success": True, "data": {"tier": "mechanical", "alias": "haiku"}},
    ):
        errors, warnings = validate_subagent(p)
    assert any("haiku" in e and "sonnet" in e for e in errors)


def test_subagent_matching_map_passes(tmp_path: Path) -> None:
    from pf.validate.adapters.agent import validate_subagent

    p = _write_subagent(tmp_path, "reviewer-preflight", "haiku")
    with patch(
        "pf.validate.adapters.agent.resolve_model",
        return_value={"success": True, "data": {"tier": "mechanical", "alias": "haiku"}},
    ):
        errors, warnings = validate_subagent(p)
    assert not any("model" in e.lower() for e in errors)


def test_subagent_without_mapping_is_not_flagged(tmp_path: Path) -> None:
    from pf.validate.adapters.agent import validate_subagent

    p = _write_subagent(tmp_path, "some-new-helper", "sonnet")
    with patch(
        "pf.validate.adapters.agent.resolve_model",
        return_value={"success": False, "error": "No subagent tier mapping for 'some-new-helper'"},
    ):
        errors, warnings = validate_subagent(p)
    assert not any("tier map" in e for e in errors)


def test_native_agent_expected_model_comes_from_map(tmp_path: Path) -> None:
    from pf.validate.adapters.agent import validate_native_agent

    p = tmp_path / "architect.md"
    p.write_text(
        "---\nname: architect\ndescription: x\nmodel: opus\nallowed-tools:\n  - Read\n---\nbody\n"
    )
    with patch(
        "pf.validate.adapters.agent.resolve_model",
        return_value={"success": True, "data": {"tier": "judgment", "alias": "best"}},
    ):
        errors, warnings = validate_native_agent(p)
    assert any("best" in w for w in warnings)
```

NOTE: the exact function names for the subagent path are in `agent.py` — the subagent model check currently lives in the function containing lines 381-386 (`valid_models = {"haiku", "sonnet", "opus"}`). If that function is not named `validate_subagent`, adjust the test imports to the real name; do NOT rename the production function.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_validate_agent_models.py -v`
Expected: FAIL (VALID_MODELS lacks fable/best/inherit; no map cross-check yet)

- [ ] **Step 3: Implement the validator changes** in `src/pf/validate/adapters/agent.py`:

At line 16 imports, add:

```python
from pf.model_tiers import VALID_ALIASES, resolve_model
```

Replace line 19:

```python
VALID_MODELS = set(VALID_ALIASES)
```

Replace the block at lines 381-386 (inside the subagent validation function):

```python
    # Model validation — aliases or explicit claude-* names
    if "model" in fm:
        model_val = str(fm["model"]).lower()
        if model_val not in VALID_MODELS and not model_val.startswith("claude-"):
            errors.append(
                f"Subagent model must be one of {sorted(VALID_MODELS)} or a "
                f"claude-* name, got '{fm['model']}'"
            )
        else:
            mapped = resolve_model("subagent", path.stem)
            if mapped["success"] and model_val != mapped["data"]["alias"]:
                errors.append(
                    f"Model '{model_val}' does not match tier map: "
                    f"'{path.stem}' is {mapped['data']['tier']} → "
                    f"'{mapped['data']['alias']}' (models.yaml)"
                )
```

Replace the native check at lines 423-428:

```python
    # Model must match the native_agents tier from models.yaml
    if "model" in fm:
        model_val = str(fm["model"]).lower()
        expected = resolve_model("native", path.stem)
        if expected["success"] and model_val != expected["data"]["alias"]:
            warnings.append(
                f"Native agent model is '{fm['model']}', expected "
                f"'{expected['data']['alias']}' (models.yaml native_agents tier)"
            )
```

- [ ] **Step 4: Apply the frontmatter downgrade** — `agents/reviewer-preflight.md:5`: change `model: sonnet` → `model: haiku`.

- [ ] **Step 4b: Spawn-template scan (spec §2, row 3).** Add to `agent.py` a body-level check for inline Task-spawn templates, plus tests in the same test file:

```python
# Matches a spawn block: a 'You are the <name> subagent' line followed
# (within the same fenced block) by a model: "<value>" line.
_SPAWN_RE = re.compile(
    r"You are the ([a-z0-9-]+) subagent.*?model:\s*\"?([a-z0-9-]+)\"?",
    re.DOTALL,
)


def validate_spawn_templates(content: str) -> list[str]:
    """Inline Task-spawn model values must match the tier map."""
    errors: list[str] = []
    for name, model in _SPAWN_RE.findall(content):
        mapped = resolve_model("subagent", name)
        if mapped["success"] and model != mapped["data"]["alias"]:
            errors.append(
                f"Spawn template for '{name}' uses model '{model}', tier map "
                f"says '{mapped['data']['alias']}' (models.yaml)"
            )
    return errors
```

Call it from the primary-agent validation path (where agent body content is already in hand) and extend the errors list. Add two tests: a body with `You are the testing-runner subagent.\n...\nmodel: "haiku"` passes (mock `resolve_model` → haiku); the same body with `model: "sonnet"` errors. Bound the regex match window if it over-matches across blocks (e.g. cap with `[^`]*?` inside a fenced-block-aware pre-split) — verify against real agent files: `uv run pf validate agent` must report 0 spawn-template errors on the current tree (tea.md, devops.md, architect.md spawns are all haiku and map to mechanical helpers).

- [ ] **Step 5: Run tests + full agent validator**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_validate_agent_models.py -v && uv run pf validate agent`
Expected: tests PASS; `pf validate agent` reports 0 model errors (native agents warn `best` until Task 10 updates their frontmatter — acceptable, warnings not errors; if you prefer zero warnings, update `agents/native/*.md` frontmatter `model: opus` → `model: best` here instead of Task 10, then keep Task 10 doc-only).

- [ ] **Step 6: Run the pre-existing agent validator tests to catch regressions**

Run: `uv run pytest src/pf/tests/test_141_20_agent_validator.py -v`
Expected: PASS. If a test asserts the old `{"haiku", "sonnet", "opus"}` set or the `expected 'opus'` warning string, update that assertion to the new behavior — the behavior change is the point of this task.

- [ ] **Step 7: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/validate/adapters/agent.py pennyfarthing-dist/agents/ pennyfarthing-dist/src/pf/tests/
git commit -m "feat(validate): agent models checked against tier map; reviewer-preflight → haiku"
```

---

### Task 4: Command frontmatter — `model:` on the 11 agent commands, validated

**Files:**
- Modify: `commands/pf-architect.md`, `commands/pf-ba.md`, `commands/pf-dev.md`, `commands/pf-devops.md`, `commands/pf-orchestrator.md`, `commands/pf-pm.md`, `commands/pf-reviewer.md`, `commands/pf-sm.md`, `commands/pf-tea.md`, `commands/pf-tech-writer.md`, `commands/pf-ux-designer.md` (frontmatter only)
- Modify: `src/pf/validate/adapters/skill_command.py` (add model↔map check)
- Test: `src/pf/tests/test_validate_command_models.py`

**Interfaces:**
- Consumes: `pf.model_tiers.resolve_model` (Task 1)
- Produces: each `commands/pf-<agent>.md` whose `<agent>` stem (after stripping the `pf-` prefix) has an `agents:` mapping must carry `model: <mapped alias>` in frontmatter; missing or drifted → validation ERROR. Commands without an agent mapping (pf-sprint, pf-git, …) are untouched and unchecked.

- [ ] **Step 1: Write the failing test**

```python
"""Command frontmatter model must match the tier map."""

from pathlib import Path
from unittest.mock import patch


def _cmd(tmp_path: Path, name: str, frontmatter: str) -> Path:
    p = tmp_path / f"{name}.md"
    p.write_text(f"---\n{frontmatter}\n---\nbody\n")
    return p


def _resolve(kind, name, root=None):
    mapping = {"dev": {"tier": "heavyweight", "alias": "opus"}}
    if name in mapping:
        return {"success": True, "data": mapping[name]}
    return {"success": False, "error": f"No {kind} tier mapping for '{name}'"}


def test_agent_command_missing_model_is_error(tmp_path: Path) -> None:
    from pf.validate.adapters.skill_command import validate_command_model

    p = _cmd(tmp_path, "pf-dev", "description: Developer")
    with patch("pf.validate.adapters.skill_command.resolve_model", side_effect=_resolve):
        errors = validate_command_model(p)
    assert any("model" in e for e in errors)


def test_agent_command_drifted_model_is_error(tmp_path: Path) -> None:
    from pf.validate.adapters.skill_command import validate_command_model

    p = _cmd(tmp_path, "pf-dev", "description: Developer\nmodel: sonnet")
    with patch("pf.validate.adapters.skill_command.resolve_model", side_effect=_resolve):
        errors = validate_command_model(p)
    assert any("opus" in e for e in errors)


def test_agent_command_matching_model_passes(tmp_path: Path) -> None:
    from pf.validate.adapters.skill_command import validate_command_model

    p = _cmd(tmp_path, "pf-dev", "description: Developer\nmodel: opus")
    with patch("pf.validate.adapters.skill_command.resolve_model", side_effect=_resolve):
        errors = validate_command_model(p)
    assert errors == []


def test_non_agent_command_is_ignored(tmp_path: Path) -> None:
    from pf.validate.adapters.skill_command import validate_command_model

    p = _cmd(tmp_path, "pf-sprint", "description: Sprint management")
    with patch("pf.validate.adapters.skill_command.resolve_model", side_effect=_resolve):
        errors = validate_command_model(p)
    assert errors == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_validate_command_models.py -v`
Expected: FAIL — `ImportError: cannot import name 'validate_command_model'`

- [ ] **Step 3: Implement `validate_command_model`** in `src/pf/validate/adapters/skill_command.py` (add import `from pf.model_tiers import resolve_model` at the top, reuse the module's existing `_parse_frontmatter`):

```python
def validate_command_model(path: Path) -> list[str]:
    """Agent-activation commands must pin the tier-mapped model alias.

    A command file pf-<name>.md whose <name> appears in the models.yaml
    ``agents:`` map must have frontmatter ``model:`` equal to the mapped
    alias. Non-agent commands are ignored.
    """
    stem = path.stem
    if not stem.startswith("pf-"):
        return []
    agent_name = stem[len("pf-"):]
    mapped = resolve_model("agent", agent_name)
    if not mapped["success"]:
        return []  # not an agent command — nothing to enforce
    fm = _parse_frontmatter(path.read_text()) or {}
    expected = mapped["data"]["alias"]
    actual = str(fm.get("model", "")).lower()
    if not actual:
        return [f"{path.name}: missing frontmatter 'model: {expected}' (models.yaml agents.{agent_name})"]
    if actual != expected:
        return [f"{path.name}: model '{actual}' does not match tier map — expected '{expected}' (models.yaml agents.{agent_name})"]
    return []
```

Wire it into the adapter's `run()` loop over command files (the module discovers command files via `discover_command_files` at `skill_command.py:36`): append `validate_command_model(path)` results to that file's errors.

- [ ] **Step 4: Add frontmatter to the 11 commands.** Each currently has only `description:`. Add one line per file. Example — `commands/pf-dev.md`:

```yaml
---
description: Developer - Feature implementation and coding
model: opus
---
```

Full assignment (from models.yaml): pf-architect `best`, pf-reviewer `best`, pf-pm `best`, pf-tea `best`, pf-dev `opus`, pf-sm `sonnet`, pf-ba `sonnet`, pf-ux-designer `sonnet`, pf-tech-writer `sonnet`, pf-devops `sonnet`, pf-orchestrator `sonnet`.

- [ ] **Step 5: Run tests + validator**

Run: `uv run pytest src/pf/tests/test_validate_command_models.py -v && uv run pf validate skill-command`
Expected: tests PASS; validator 0 errors.

- [ ] **Step 6: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/commands/ pennyfarthing-dist/src/pf/validate/adapters/skill_command.py pennyfarthing-dist/src/pf/tests/test_validate_command_models.py
git commit -m "feat(commands): tier-mapped model frontmatter on agent commands, validated"
```

---

### Task 5: `pf agent start` emits expected_model + state file

**Files:**
- Modify: `src/pf/prime/cli.py:118-124` (the Workflow State emission block ending with the `backlog_count` append at lines 123-124)
- Test: `src/pf/tests/test_prime_expected_model.py`

**Interfaces:**
- Consumes: `pf.model_tiers.resolve_model` (Task 1)
- Produces: (a) `expected_model: <alias>` line in the `# Workflow State` section of `pf agent start <name>` output; (b) JSON state file `.session/.expected-model` with `{"agent": str, "alias": str, "story_id": str|null, "phase": str|null}` — consumed by the advisory hook (Task 7). Both fail-soft: if resolution fails, no line, no file, no crash.

- [ ] **Step 1: Write the failing tests**

```python
"""pf agent start emits expected_model and writes .session/.expected-model."""

import json
from pathlib import Path
from unittest.mock import patch


def test_expected_model_line_and_state_file(tmp_path: Path) -> None:
    from pf.prime.cli import main

    pf_dir = tmp_path / ".pennyfarthing"
    (pf_dir / "agents").mkdir(parents=True)
    (pf_dir / "agents" / "dev.md").write_text("# Dev Agent")

    with (
        patch("pf.prime.cli.get_project_root", return_value=tmp_path),
        patch(
            "pf.prime.cli.resolve_model",
            return_value={"success": True, "data": {"tier": "heavyweight", "alias": "opus"}},
        ),
    ):
        main(["--agent", "dev", "--no-workflow", "--no-register"])

    state_file = tmp_path / ".session" / ".expected-model"
    assert state_file.exists()
    state = json.loads(state_file.read_text())
    assert state["agent"] == "dev"
    assert state["alias"] == "opus"


def test_resolution_failure_is_silent(tmp_path: Path) -> None:
    from pf.prime.cli import main

    pf_dir = tmp_path / ".pennyfarthing"
    (pf_dir / "agents").mkdir(parents=True)
    (pf_dir / "agents" / "dev.md").write_text("# Dev Agent")

    with (
        patch("pf.prime.cli.get_project_root", return_value=tmp_path),
        patch(
            "pf.prime.cli.resolve_model",
            return_value={"success": False, "error": "models.yaml not found"},
        ),
    ):
        rc = main(["--agent", "dev", "--no-workflow", "--no-register"])

    assert rc == 0
    assert not (tmp_path / ".session" / ".expected-model").exists()
```

Follow the arrange pattern of `src/pf/tests/test_prime.py` / `test_tiers.py` (they patch `pf.prime.cli.get_project_root` the same way); if `main` requires more scaffolding, copy the minimal fixture from those files. Capture stdout with capsys and additionally assert `"expected_model: opus"` appears in the output of the happy-path test if the `--no-workflow` flag still emits the Workflow State section; if `--no-workflow` suppresses the section, assert on the state file only (the line is covered by manual verification in Task 9's checklist).

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_prime_expected_model.py -v`
Expected: FAIL — no `resolve_model` attribute on `pf.prime.cli`, no state file written.

- [ ] **Step 3: Implement.** In `src/pf/prime/cli.py`: add import `from pf.model_tiers import resolve_model` at the top; in the Workflow State emission block (immediately after the `backlog_count` append at lines 123-124), add:

```python
    resolved = resolve_model("agent", agent_name)
    if resolved["success"]:
        alias = resolved["data"]["alias"]
        lines.append(f"expected_model: {alias}")
        try:
            session_dir = get_project_root() / ".session"
            session_dir.mkdir(exist_ok=True)
            (session_dir / ".expected-model").write_text(
                json.dumps(
                    {
                        "agent": agent_name,
                        "alias": alias,
                        "story_id": getattr(ws, "story_id", None),
                        "phase": getattr(ws, "phase", None),
                    }
                )
            )
        except OSError:
            pass  # advisory plumbing must never break activation
```

Use the local variable that holds the agent name in that scope (it may be `name` or `agent_name` — match the surrounding code) and add `import json` if absent. `ws` is the WorkflowState object already in scope (see `pf/prime/models.py:43`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `uv run pytest src/pf/tests/test_prime_expected_model.py src/pf/tests/test_prime.py -v`
Expected: PASS (including no regressions in test_prime.py).

- [ ] **Step 5: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/prime/cli.py pennyfarthing-dist/src/pf/tests/test_prime_expected_model.py
git commit -m "feat(prime): agent start emits expected_model + .session/.expected-model state"
```

---

### Task 6: Statusline persists the session's current model

**Files:**
- Modify: `src/pf/hooks/statusline.py` (near `_get_model_name`, line 128)
- Test: `src/pf/tests/test_statusline_model_persist.py`

**Interfaces:**
- Produces: `.pennyfarthing/.runtime/current-model` — one line, the raw model id (e.g. `claude-fable-5`), rewritten on every statusline render. Fail-soft. Consumed by the advisory hook (Task 7).
- Consumes: statusline stdin JSON `model` field (`{"id": ..., "name": ...}` or plain string — `_get_model_name` at `statusline.py:128-136` shows both shapes) and the workspace/project dir already parsed by the module.

- [ ] **Step 1: Write the failing tests**

```python
"""Statusline persists the current model id for the advisory hook."""

from pathlib import Path


def test_persist_model_writes_runtime_file(tmp_path: Path) -> None:
    from pf.hooks.statusline import _persist_model

    _persist_model({"model": {"id": "claude-fable-5"}}, tmp_path)
    f = tmp_path / ".pennyfarthing" / ".runtime" / "current-model"
    assert f.read_text() == "claude-fable-5"


def test_persist_model_string_shape(tmp_path: Path) -> None:
    from pf.hooks.statusline import _persist_model

    _persist_model({"model": "claude-opus-4-8"}, tmp_path)
    f = tmp_path / ".pennyfarthing" / ".runtime" / "current-model"
    assert f.read_text() == "claude-opus-4-8"


def test_persist_model_failsoft_on_missing_model(tmp_path: Path) -> None:
    from pf.hooks.statusline import _persist_model

    _persist_model({}, tmp_path)  # must not raise
    assert not (tmp_path / ".pennyfarthing" / ".runtime" / "current-model").exists()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_statusline_model_persist.py -v`
Expected: FAIL — `ImportError: cannot import name '_persist_model'`

- [ ] **Step 3: Implement** in `src/pf/hooks/statusline.py`:

```python
def _persist_model(data: dict, project_root: Path) -> None:
    """Persist the raw model id for the model-tier advisory hook. Fail-soft."""
    model_raw = data.get("model")
    if isinstance(model_raw, dict):
        model_id = model_raw.get("id") or model_raw.get("name")
    elif isinstance(model_raw, str):
        model_id = model_raw
    else:
        model_id = None
    if not model_id:
        return
    try:
        runtime = project_root / ".pennyfarthing" / ".runtime"
        runtime.mkdir(parents=True, exist_ok=True)
        (runtime / "current-model").write_text(model_id)
    except OSError:
        pass
```

Call it from the statusline main/render path right after the stdin JSON is parsed, passing the project root the module already derives from the input's workspace dir (find where the module resolves the workspace/current dir and reuse it; add `from pathlib import Path` if the signature needs it). Ensure `.runtime/` is covered by an existing gitignore for `.pennyfarthing/` local files — check `.gitignore` handling of `.pennyfarthing/sidecars/`; if `.pennyfarthing/.runtime/` is not ignored in consumer repos, add it to the init/setup gitignore template alongside wherever `sidecars` is handled (grep `sidecars` in `src/pf/init/`).

- [ ] **Step 4: Run tests + pre-existing statusline tests**

Run: `uv run pytest src/pf/tests/test_statusline_model_persist.py src/pf/tests/test_subagent_statusbar.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/hooks/statusline.py pennyfarthing-dist/src/pf/tests/test_statusline_model_persist.py
git commit -m "feat(statusline): persist current model id for tier advisory"
```

---

### Task 7: Advisory model-tier hook

**Files:**
- Create: `src/pf/hooks/advisory_model_tier.py`
- Modify: `src/pf/hooks/dispatch.py:24-33` (DISPATCH_REGISTRY PreToolUse list), `src/pf/hooks/cli.py` (new command, mirror `advisory-never-edit-zone` at lines 82-85)
- Test: `src/pf/tests/test_advisory_model_tier.py`

**Interfaces:**
- Consumes: `.session/.expected-model` (Task 5), `.pennyfarthing/.runtime/current-model` (Task 6).
- Produces: PreToolUse `additionalContext` advisory, at most once per (agent, story, phase, current-model) key; once-state in `.session/.model-advised`. Exit 0 on every path. Output JSON shape MUST be copied from `advisory_never_edit_zone.py`'s response emission (same `hookSpecificOutput.additionalContext` structure).

- [ ] **Step 1: Write the failing tests**

```python
"""Advisory model-tier hook — nudges once per phase on model/tier mismatch."""

import json
from pathlib import Path


def _setup(tmp_path: Path, expected_alias: str, current_id: str) -> None:
    session = tmp_path / ".session"
    session.mkdir()
    (session / ".expected-model").write_text(
        json.dumps({"agent": "dev", "alias": expected_alias, "story_id": "1-1", "phase": "green"})
    )
    runtime = tmp_path / ".pennyfarthing" / ".runtime"
    runtime.mkdir(parents=True)
    (runtime / "current-model").write_text(current_id)


def test_alias_satisfied_by_model_id() -> None:
    from pf.hooks.advisory_model_tier import _alias_satisfied

    assert _alias_satisfied("opus", "claude-opus-4-8")
    assert _alias_satisfied("sonnet", "claude-sonnet-5")
    assert _alias_satisfied("haiku", "claude-haiku-4-5-20251001")
    assert _alias_satisfied("fable", "claude-fable-5")
    assert _alias_satisfied("best", "claude-fable-5")
    assert _alias_satisfied("best", "claude-opus-4-8")  # best = fable-or-opus
    assert not _alias_satisfied("opus", "claude-fable-5")
    assert not _alias_satisfied("best", "claude-sonnet-5")
    assert _alias_satisfied("inherit", "claude-anything")  # inherit never nags


def test_mismatch_emits_advisory_once(tmp_path: Path) -> None:
    from pf.hooks.advisory_model_tier import check

    _setup(tmp_path, "opus", "claude-fable-5")
    out1 = check(tmp_path)
    assert out1 is not None
    assert "opus" in out1 and "fable" in out1
    out2 = check(tmp_path)  # same key — already advised
    assert out2 is None


def test_match_is_silent(tmp_path: Path) -> None:
    from pf.hooks.advisory_model_tier import check

    _setup(tmp_path, "opus", "claude-opus-4-8")
    assert check(tmp_path) is None


def test_missing_state_files_are_silent(tmp_path: Path) -> None:
    from pf.hooks.advisory_model_tier import check

    assert check(tmp_path) is None


def test_registered_in_dispatch() -> None:
    from pf.hooks.dispatch import DISPATCH_REGISTRY

    names = [entry[0] for entry in DISPATCH_REGISTRY["PreToolUse"]]
    assert "advisory-model-tier" in names
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_advisory_model_tier.py -v`
Expected: FAIL — module does not exist.

- [ ] **Step 3: Implement `src/pf/hooks/advisory_model_tier.py`**

```python
"""Advisory model-tier hook (PreToolUse).

Compares the session's actual model (persisted by the statusline hook) to the
active phase's expected tier alias (persisted by ``pf agent start``) and
injects a one-line advisory on mismatch — at most once per
(agent, story, phase, model) key.

ADVISORY ONLY: additionalContext, never a permission decision; exits 0 on
every path. Fail-soft: missing/corrupt state files mean silence.

Spec: docs/superpowers/specs/2026-07-02-model-tiering-design.md (orchestrator).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from pf.common.config import get_project_root

# alias → substrings that satisfy it in a full model id
_FAMILY: dict[str, tuple[str, ...]] = {
    "fable": ("fable",),
    "opus": ("opus",),
    "sonnet": ("sonnet",),
    "haiku": ("haiku",),
    "best": ("fable", "opus"),  # best = Fable where available, else Opus
}


def _alias_satisfied(alias: str, model_id: str) -> bool:
    if alias == "inherit":
        return True
    families = _FAMILY.get(alias)
    if families is None:
        return True  # unknown alias (e.g. explicit claude-*): never nag
    mid = model_id.lower()
    return any(f in mid for f in families)


def check(project_root: Path) -> str | None:
    """Return advisory text, or None. Never raises."""
    try:
        expected_file = project_root / ".session" / ".expected-model"
        current_file = project_root / ".pennyfarthing" / ".runtime" / "current-model"
        if not expected_file.exists() or not current_file.exists():
            return None
        expected = json.loads(expected_file.read_text())
        alias = str(expected.get("alias", ""))
        current = current_file.read_text().strip()
        if not alias or not current or _alias_satisfied(alias, current):
            return None
        key = f"{expected.get('agent')}|{expected.get('story_id')}|{expected.get('phase')}|{current}"
        advised_file = project_root / ".session" / ".model-advised"
        if advised_file.exists() and advised_file.read_text() == key:
            return None
        advised_file.write_text(key)
        phase = expected.get("phase") or "current"
        agent = expected.get("agent") or "agent"
        return (
            f"[model-tier advisory] {phase} phase ({agent}) expects `{alias}` "
            f"per models.yaml; session is on `{current}`. Consider `/model {alias}` "
            f"— advisory only, carry on if intentional."
        )
    except Exception:
        return None


def main() -> int:
    try:
        json.loads(sys.stdin.read() or "{}")  # payload unused; validate shape
        message = check(get_project_root())
        if message:
            # NOTE: copy the exact response emission (hookSpecificOutput /
            # additionalContext JSON) from advisory_never_edit_zone.main().
            print(
                json.dumps(
                    {
                        "hookSpecificOutput": {
                            "hookEventName": "PreToolUse",
                            "additionalContext": message,
                        }
                    }
                )
            )
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Before finalizing, open `advisory_never_edit_zone.py`'s `main()` and make the output emission byte-compatible with its shape (it is the proven ADR-0041 pattern; if it differs from the sketch above, the existing hook wins).

- [ ] **Step 4: Register.** In `dispatch.py` PreToolUse list, after the `advisory-never-edit-zone` entry:

```python
        (
            "advisory-model-tier",
            "Edit|Write|Bash|Task",
            "pf.hooks.advisory_model_tier",
        ),
```

In `hooks/cli.py`, mirror lines 82-85:

```python
@hooks.command("advisory-model-tier")
def advisory_model_tier():
    """Advisory nudge when session model mismatches the phase's tier."""
    from pf.hooks.advisory_model_tier import main

    raise SystemExit(main())
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `uv run pytest src/pf/tests/test_advisory_model_tier.py -v`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/hooks/ pennyfarthing-dist/src/pf/tests/test_advisory_model_tier.py
git commit -m "feat(hooks): advisory model-tier nudge (ADR-0041 pattern)"
```

---

### Task 8: Benchmark/demo stale-ID sweep — map-resolved defaults

**Files:**
- Modify: `src/pf/benchmark/pipeline_replay.py:1216-1219, 1587, 2839, 2924`
- Modify: `src/pf/benchmark/cli.py:466, 1115, 1215`
- Modify: `src/pf/peloton/result_aggregator.py:119`
- Modify: `src/pf/demo/generator.py:86`
- Test: `src/pf/tests/test_model_defaults_no_stale_ids.py`

**Interfaces:**
- Consumes: `pf.model_tiers.resolve_model`, `resolve_tier_alias`, `load_model_map` (Task 1)
- Produces: a helper in `pf/model_tiers.py`: `judge_alias(name: str, project_root: Path | None = None) -> str` — returns the mapped judge alias or the safe fallback `"opus"` (string, not result object: call sites are defaults, fallback must be infallible). Add it in this task:

```python
def judge_alias(name: str, project_root: Path | None = None) -> str:
    """Judge model alias from the map, falling back to 'opus'. Infallible."""
    resolved = resolve_model("judge", name, project_root)
    if resolved["success"]:
        return resolved["data"]["alias"]
    return "opus"


def subagent_alias(name: str, project_root: Path | None = None) -> str:
    """Subagent model alias from the map, falling back to 'sonnet'. Infallible."""
    resolved = resolve_model("subagent", name, project_root)
    if resolved["success"]:
        return resolved["data"]["alias"]
    return "sonnet"
```

- [ ] **Step 1: Write the failing test**

```python
"""No stale pinned model IDs in benchmark/demo/peloton defaults."""

import re
from pathlib import Path

SWEPT = [
    "src/pf/benchmark/pipeline_replay.py",
    "src/pf/benchmark/cli.py",
    "src/pf/peloton/result_aggregator.py",
    "src/pf/demo/generator.py",
]

# Pinned generation-4 IDs that must not survive the sweep
STALE = re.compile(r"claude-(opus|sonnet|haiku)-4[-\d]")


def test_no_stale_pinned_model_ids() -> None:
    root = Path(__file__).resolve().parents[2]  # pennyfarthing-dist/src
    offenders = []
    for rel in SWEPT:
        text = (root.parent / rel).read_text()
        for i, line in enumerate(text.splitlines(), 1):
            if STALE.search(line):
                offenders.append(f"{rel}:{i}: {line.strip()}")
    assert offenders == [], "\n".join(offenders)


def test_judge_alias_fallback() -> None:
    from unittest.mock import patch

    from pf.model_tiers import judge_alias

    with patch(
        "pf.model_tiers.resolve_model",
        return_value={"success": False, "error": "x"},
    ):
        assert judge_alias("benchmark") == "opus"
```

Adjust the `parents[...]` index so `root.parent / rel` resolves to real files — verify with a quick `python -c` before relying on it.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_model_defaults_no_stale_ids.py -v`
Expected: FAIL, listing every stale line found in Step 1's audit.

- [ ] **Step 3: Apply the edits** (add `from pf.model_tiers import judge_alias, subagent_alias` where used):

`pipeline_replay.py:1216-1219` — replace:

```python
        # Subagent models come from models.yaml (reviewer fleet = analytical)
        subagent_model = subagent_alias(name)
```

`pipeline_replay.py:1587` and `:2924` — in both scan invocations, replace `"--model", "claude-opus-4-6"` with:

```python
             "--model", subagent_alias(agent_name),
```

`pipeline_replay.py:2839` — replace `jmodel = judge_model or "claude-opus-4-6"` with:

```python
                    jmodel = judge_model or judge_alias("benchmark")
```

`benchmark/cli.py:466` and `:1115` — change both `--judge-model` options to `default=None` with help `"Claude model for scoring judge (default: models.yaml judges.benchmark)"`, and at each use site apply `judge_model = judge_model or judge_alias("benchmark")`. `cli.py:1215` — update the stale help text `(default: claude-sonnet-4-6)` to name the map.

`result_aggregator.py:119` — change the signature default to `judge_model: str | None = None` and resolve inside `score()`:

```python
        judge_model = judge_model or judge_alias("peloton")
```

`demo/generator.py:86` — replace `"claude-sonnet-4-6"` with `"sonnet"` (plain alias; the demo generator is not a mapped role — add the comment `# alias, resolved by claude CLI`).

- [ ] **Step 4: Run the sweep test + touched-module tests**

Run: `uv run pytest src/pf/tests/test_model_defaults_no_stale_ids.py src/pf/tests/test_model_tiers.py -v`
Then grep for regressions: `grep -rn "claude-opus-4-6\|claude-sonnet-4-6\|claude-sonnet-4-2025" src/pf/ --include="*.py" | grep -v tests` — Expected: no output.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/
git commit -m "fix(benchmark): stale pinned model IDs → tier-map aliases"
```

---

### Task 9: Framework docs sweep

**Files:**
- Modify: `guides/agent-coordination.md:284-293` (subagent table), `:445` (research-tools line)
- Modify: `guides/tandem-protocol.md:8, 76, 139`
- Modify: `agents/README.md:25-32`
- Modify: `agents/native/*.md` frontmatter `model: opus` → `model: best` (if not already done in Task 3 Step 5)
- Modify: delegation tables in `agents/{architect,ba,dev,orchestrator,pm,tea,devops}.md` — retitle `| I Do (Opus) | Helper Does (Haiku) |`

**Interfaces:** none (prose). No tests; verified by `pf validate agent` warnings dropping to zero and by grep.

- [ ] **Step 1: Update `guides/agent-coordination.md`.** Replace the intro at line 284 and the table's Model column with map-true values:

```markdown
Subagents are lightweight agents for mechanical and analytical tasks. Invoked via `Task tool`.
Model assignments come from `models.yaml` (the tier map) — the table below mirrors it.

| Subagent File | Purpose | Model |
|--------------|---------|-------|
| `sm-setup.md` | Research backlog (MODE=research) or setup story (MODE=setup) | haiku |
| `sm-finish.md` | Preflight checks (PHASE=preflight) or execute finish (PHASE=execute) | haiku |
| `sm-file-summary.md` | Summarize file changes for commits | haiku |
| `reviewer-preflight.md` | Pre-flight checks before review | haiku |
| `testing-runner.md` | Run tests and report results | haiku |
| `tandem-backseat.md` | Background observer for tandem mode | sonnet |
```

Line 445: replace `Subagents (haiku model) should NOT use ... Only strategic agents (Opus) use research tools.` with `Subagents (mechanical/analytical tiers) should NOT use Context7 or Perplexity. MCP round-trips on delegated tasks are waste. Only judgment-tier agents use research tools.`

- [ ] **Step 2: Update `guides/tandem-protocol.md`.** Line 8: `Backseat Agent (Haiku, background)` → `Backseat Agent (Sonnet, background)`. Line 76: the example spawn `model: "haiku"` → `model: "sonnet"`. Line 139: verify the `| Model | Haiku | Sonnet |` comparison row matches reality (backseat = sonnet) and fix if inverted.

- [ ] **Step 3: Update `agents/README.md:25-32`.** Retitle `### Official Subagents (Haiku-based)` → `### Official Subagents` and change the intro to: `Lightweight subagents for mechanical and analytical tasks. Model per subagent comes from models.yaml; invoke via Task tool with the mapped model.`

- [ ] **Step 4: Delegation tables.** In each primary agent body, change the table header `| I Do (Opus) | Helper Does (Haiku) |` → `| I Do (my tier) | Helper Does (helper tier) |`. Grep to enumerate: `grep -rln "I Do (Opus)" agents/`.

- [ ] **Step 5: Verify + commit**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pf validate agent && grep -rn "I Do (Opus)" agents/ | wc -l`
Expected: 0 native-model warnings, grep count 0.

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/guides/ pennyfarthing-dist/agents/
git commit -m "docs(models): four-tier model world — fix haiku/sonnet drift, tier language"
```

---

### Task 10: Framework verification + PR

**Files:** none new.

- [ ] **Step 1: Run the full targeted test set** (NEVER the bare suite — see Global Constraints):

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist
uv run pytest src/pf/tests/test_model_tiers.py src/pf/tests/test_validate_models_adapter.py \
  src/pf/tests/test_validate_agent_models.py src/pf/tests/test_validate_command_models.py \
  src/pf/tests/test_prime_expected_model.py src/pf/tests/test_statusline_model_persist.py \
  src/pf/tests/test_advisory_model_tier.py src/pf/tests/test_model_defaults_no_stale_ids.py \
  src/pf/tests/test_141_20_agent_validator.py src/pf/tests/test_prime.py -v
```

Expected: all PASS.

- [ ] **Step 2: Run all pf validators touched:**

```bash
uv run pf validate models && uv run pf validate agent && uv run pf validate skill-command
```

Expected: 0 errors.

- [ ] **Step 3: Manual smoke** (in the orchestrator checkout, which symlinks to this dist): run `pf agent start dev --no-persona --quiet | head -20` and confirm the `expected_model: opus` line appears in the Workflow State section.

- [ ] **Step 4: Create the PR** (needs manual merge per repo convention — no CI on this repo, local pytest is the gate):

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git push -u origin feat/model-tiering
gh pr create --base develop --title "feat(models): central model tier map for the Claude 5 era" \
  --body "Implements docs/superpowers/specs/2026-07-02-model-tiering-design.md (orchestrator repo).

- models.yaml tier map + pf.model_tiers loader/resolver (aliases only, best/opus/sonnet/haiku)
- validators: models adapter; agent/subagent/native/command frontmatter checked against map
- reviewer-preflight sonnet→haiku (spec'd downgrade)
- pf agent start emits expected_model + .session/.expected-model
- statusline persists current model; advisory-model-tier hook nudges on mismatch (ADR-0041 pattern)
- benchmark/demo/peloton stale claude-*-4-* IDs → map-resolved aliases
- docs: four-tier world, haiku/sonnet drift fixed

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

---

### Task 11: Orchestrator-repo doc updates (separate repo, separate PR)

**Files:**
- Modify: `/Users/slabgorb/Projects/orc-penny/SOUL.md` (principle 4)
- Modify: `/Users/slabgorb/Projects/orc-penny/CLAUDE.md` (rule 7)
- Modify: `/Users/slabgorb/Projects/orc-penny/docs/superpowers/specs/2026-07-02-model-tiering-design.md` (peloton deviation note)

- [ ] **Step 1: SOUL.md principle 4** — replace the body of `<principle name="right-model">` with:

```markdown
## 4. Right Model for the Right Job
Match model to task tier per `models.yaml`: Haiku for mechanical execution, Sonnet for analytical work, Opus for heavyweight execution, Fable (via `best`) for judgment that cascades. With 1M context, consistency matters more than token conservation.
```

- [ ] **Step 2: CLAUDE.md rule 7** — replace `**Match model to task** — Haiku for mechanical tasks, Sonnet/Opus for analytical subagents` with:

```markdown
7. **Match model to task** — tiers live in `pennyfarthing/pennyfarthing-dist/models.yaml`: haiku=mechanical, sonnet=analytical, opus=heavyweight, best(Fable/Opus)=judgment
```

- [ ] **Step 3: Record the peloton spec deviation.** Append to the spec's Decision trail section:

```markdown
- Deviation (plan, 2026-07-02): peloton panes do not spawn `claude` processes
  (pane content is driven by the team/subagent substrate), so the spec's
  "pane spawns `claude --model <alias>`" line is inoperative. Model policy
  reaches peloton through native-agent frontmatter, subagent spawns, and the
  `result_aggregator` judge default (all map-driven). `spawn_agent_panes`'s
  unused `model` param left as-is.
- Deviation (plan, 2026-07-02): current-model detection uses statusline
  persistence (`.pennyfarthing/.runtime/current-model`, written on every
  render from the statusline input's `model` field) instead of the spec's
  transcript parsing — statusline receives the model id directly from
  Claude Code, so no transcript format coupling. Advisory behavior unchanged.
```

- [ ] **Step 4: Commit on a branch + PR** (orchestrator main is push-protected):

```bash
cd /Users/slabgorb/Projects/orc-penny
git checkout -b docs/model-tiering-soul main
git add SOUL.md CLAUDE.md docs/superpowers/specs/2026-07-02-model-tiering-design.md
git commit -m "docs(models): SOUL #4 + rule 7 → four-tier model map; spec deviation note"
git push -u origin docs/model-tiering-soul
gh pr create --base main --title "docs(models): four-tier model policy" --body "Doc companion to pennyfarthing feat/model-tiering.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

---

## Out of scope (follow-up stories, not this plan)

- **Replay experiments** (spec §5): Dev on `opus` vs `sonnet`; reviewer-preflight `haiku` vs `sonnet`. Run via existing `pf benchmark replay run --model ...` after this lands.
- Skill `effort:` frontmatter tuning.
- Per-story model selection (trivial workflow → cheaper tiers).
