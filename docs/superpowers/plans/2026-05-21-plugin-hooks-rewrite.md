# Plugin Hooks Rewrite (Plan 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all Pennyfarthing Claude Code lifecycle hooks from the user's `.claude/settings.json` into the plugin's own `hooks/hooks.json`, so plugin enable/disable is the only toggle — and make Frame auto-start survive the plugin's hook process-group kill.

**Architecture:** The live system already uses a **single-dispatcher** model — `.claude/settings.json` registers one hook per lifecycle event (`SessionStart`, `Stop`, `PreToolUse`, `PostToolUse`, `SessionEnd`, `PreCompact`) pointing at `pf hooks dispatch <Event>`, and `runtime/src/pf/hooks/dispatch.py` does all matcher routing (Write/Edit/Bash/etc.) internally in one Python process. Plan 4 preserves that model: the plugin's `hooks/hooks.json` registers the same 6 events, each invoking a one-line shell wrapper that runs `uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" --quiet pf hooks dispatch <Event>`. The SessionStart wrapper additionally launches the Frame server with `nohup … & disown` (the only spawn pattern that survives the macOS process-group kill — spike Q4), and the Python `session_start` handler stops spawning Frame itself (a Popen child there would be killed).

**Tech Stack:** Python 3.11+ (uv-managed runtime), Click CLI (`pf`), `ruamel.yaml` (already a dependency), bash hook wrappers, Claude Code plugin `hooks.json` (nested schema), pytest (run with `--extra test`).

---

## Working context (read before starting)

- **Do ALL work in the migration worktree:** `/Users/slabgorb/Projects/orc-penny-pf-migration` (pinned to branch `feat/plugin-scaffold-and-paths`). NOT in `pennyfarthing/`.
- **This plan document lives in the orchestrator repo** (`/Users/slabgorb/Projects/orc-penny/docs/...`); the *code* it describes lives in the worktree.
- **Plugin content root = worktree root.** `agents/`, `commands/`, `skills/`, `gates/`, `scripts/`, etc. are at the worktree root. `pennyfarthing-dist/` is **deleted** (Plan 3).
- **Python runtime:** `runtime/src/pf/`. `pf.common.config.get_dist_root()` returns the plugin content root (`CLAUDE_PLUGIN_ROOT` env, else `__file__` parents[4]).
- **Run tests** (the `--extra test` is REQUIRED — pytest-asyncio):
  ```bash
  cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime && uv run --extra test pytest src/pf/tests/ -q
  ```
  Suite baseline after Plan 3: **4473 passed / 0 failed / 0 errors.** It must stay at 0 failed / 0 errors.
- **Commits:** GPG-signed, on `feat/plugin-scaffold-and-paths`, in the worktree. Never `--no-verify` or `--amend`.
- **`gh` calls:** until Q4 (Task 1) is resolved, prefix every `gh` invocation with `env -u GITHUB_TOKEN` (auto-memory: stale PAT in the long-running tmux server env shadows the keyring).
- **Symlink trap:** before moving or deleting any tree, run `find <dir> -type l`. The repo uses symlink façades.

---

## Design decisions that diverge from the spec's literal §6.2 — READ FIRST

The spec (`docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md` §6.2) lists a per-script hook inventory (`session-start.sh → SessionStart`, `schema-validation.sh → PreToolUse:Write`, …) as if each script is registered individually. **The live code does not work that way** — it uses the dispatcher described above (confirmed in `runtime/src/pf/hooks/dispatch.py` and the orchestrator's `.claude/settings.local.json`). The following decisions resolve that gap; flag any you disagree with **before execution**:

1. **Preserve the dispatcher.** `hooks/hooks.json` registers 6 events, not ~13 scripts. Matcher routing stays inside `dispatch.py`. Rationale: one `uv run` process per event instead of N (uv startup cost is real); matches the live system; SOUL §2 "one truth".
2. **Delete the obsolete individual hook shims.** `scripts/hooks/{session-start,session-stop,schema-validation,pre-edit-check,context-warning,context-circuit-breaker,question-reflector-check,sprint-yaml-validation,welcome-hook}.sh` are not registered under the dispatcher — they are dead. Delete them.
3. **Retire `runtime/src/pf/tests/test_wrapper_removal.py`.** Its AC4 (`test_no_uv_run_in_any_script`) asserts *no* `scripts/**/*.sh` may contain `uv run`. The plugin model *requires* `uv run` in the hook wrappers. The test's premise is inverted by this migration. Replace it with a new test that asserts the dispatcher wrappers are correct.
4. **Relocate Frame launch to the SessionStart shell wrapper.** Spike Q4: a Popen child spawned from inside a plugin hook is killed when the hook's process group exits (macOS); only `nohup … & disown` survives. Today `session_start.py:_ensure_frame()` spawns Frame via Popen — doomed under the plugin. So: the SessionStart wrapper launches Frame via `nohup uv run … pf frame start --background & disown`; the Python handler stops spawning Frame and instead only *reads* the port (brief poll) to write OTEL env. This is a behavioral relocation, validated end-to-end in Task 8.
5. **Git hooks are OUT of scope.** `scripts/hooks/{pre-commit,pre-push,post-merge}.sh` and `dispatcher-template.sh` are git hooks installed into `.git/hooks/` by `pf git install-hooks` — they are NOT Claude Code lifecycle hooks and do not belong in `hooks.json`. Their internals still reference the deleted `pennyfarthing-dist/` path and pipx; that is a separate cleanup, noted as a follow-up, not fixed here. (Branch protection is already covered Claude-side by `branch_protection.py` on `PreToolUse:Bash`.)
6. **`pf hooks sprint-yaml` keeps its name.** The spec suggests renaming to `sprint-yaml-validate`. The dispatcher references the *module* (`pf.hooks.sprint_yaml_validation`), not the CLI name, so the rename is pure churn. We rewrite the *internals* (Node → ruamel) and keep the CLI subcommand name `sprint-yaml`. Flagged as a deviation from the spec's wording.
7. **`otel-auto-config.sh` is deleted.** It is a `source`-d script that exports env vars into the calling shell — that mechanism cannot work as a plugin hook command (hooks run in a subshell; exports do not propagate). OTEL config already flows through `session_start.py:_write_env_file()` via `CLAUDE_ENV_FILE`, which Claude Code sources. The `.sh` is dead.
8. **statusLine is verified, not assumed.** It is registered today as a top-level `statusLine` key in settings (not a `hooks` event). Whether a plugin can supply `statusLine` is unknown; Task 9 verifies and either registers it or documents the one-line manual fallback. Non-blocking.

---

## File structure

| File | Responsibility | Action |
|------|----------------|--------|
| `runtime/src/pf/frame/cli.py` | `pf frame start` CLI | Modify — add `--background` (server-only, no `exec_claude`) |
| `runtime/src/pf/hooks/session_start.py` | SessionStart handler | Modify — drop Frame *spawn*; poll-read port for OTEL only |
| `runtime/src/pf/hooks/sprint_yaml_validation.py` | PostToolUse YAML check | Rewrite — Node subprocess → `ruamel.yaml` |
| `hooks/hooks.json` | Plugin lifecycle hook registration | Create |
| `scripts/hooks/session-start.sh` | SessionStart wrapper (nohup Frame + dispatch) | Create (replaces dead shim) |
| `scripts/hooks/dispatch.sh` | Generic dispatch wrapper for other events | Create |
| `runtime/src/pf/tests/test_plugin_hooks.py` | Tests for hooks.json + wrappers | Create |
| `runtime/src/pf/tests/test_wrapper_removal.py` | Obsolete (inverted premise) | Delete |
| `scripts/hooks/{session-start,session-stop,schema-validation,pre-edit-check,context-warning,context-circuit-breaker,question-reflector-check,sprint-yaml-validation,welcome-hook,otel-auto-config}.sh` | Dead shims | Delete |
| `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` | Spike record | Modify — close Q4 |

---

## Task 1: Q4 micro-spike — plugin-declared `env` / `permissions` merging

**This is a precondition. Do it first. It is a spike, not TDD — investigate, then record the finding and a decision.**

**The question:** Can a plugin declare `env: { "GITHUB_TOKEN": "" }` (and `permissions`) such that, inside plugin hooks and plugin-invoked `pf` runs, `gh` falls back to the keyring instead of being shadowed by the stale `GITHUB_TOKEN` in the environment? (See auto-memory "gh 401 — GITHUB_TOKEN shadows keyring".) If yes, we can drop the defensive `env -u GITHUB_TOKEN` prefix. If no, the prefix stays.

**Files:**
- Modify: `.claude-plugin/plugin.json` (or wherever plugin env is declared — discover this) for the experiment
- Modify (record results): `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md`

- [ ] **Step 1: Discover where a plugin declares `env`/`permissions`.**

Run `claude plugin validate` against the current manifest to confirm baseline, then determine the schema for plugin-level `env`/`permissions`:
```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
claude plugin validate 2>&1 | head -40
claude plugin --help 2>&1 | head -40
```
Check whether `plugin.json` accepts an `env` key, or whether plugin settings live elsewhere (e.g., a plugin-scoped `settings.json`). Capture exact findings — do not assume.

- [ ] **Step 2: Run the experiment.**

Declare `env: { "GITHUB_TOKEN": "" }` in the discovered location. With a stale `GITHUB_TOKEN` exported in the shell, start a fresh Claude session with the plugin installed (directory-source: `claude plugin marketplace add /Users/slabgorb/Projects/orc-penny-pf-migration && claude plugin install pf@pennyfarthing`), and from a plugin hook (or `pf` invocation) run `gh auth status` / `gh api user`. Observe whether the empty plugin-level `env` shadows the stale token (making `gh` fall back to the keyring).

- [ ] **Step 3: Record the decision in the spike results doc.**

Append a `## §10.4 — RESOLVED <date>` section to `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` stating: where plugin env is declared, whether the empty-`env` shadow works, and the decision:
  - **If it works:** declare `env: { "GITHUB_TOKEN": "" }` in the plugin manifest (keep this change) and note that the defensive prefix is no longer required.
  - **If it does not work:** revert the experimental manifest change and state that all plugin-internal `gh` calls must keep the `env -u GITHUB_TOKEN` prefix.

- [ ] **Step 4: Commit.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add .claude-plugin/plugin.json docs/superpowers/spikes/2026-05-21-plugin-spike-results.md 2>/dev/null
git commit -m "spike(plugin): resolve Q4 — plugin env/permissions merging"
```
(Stage only the files that actually changed. If the experiment was reverted, the manifest may be unchanged — commit just the spike doc.)

---

## Task 2: Add `pf frame start --background` (server-only, no Claude exec)

**Why:** The SessionStart wrapper must launch *only* the Frame server (uvicorn), detached, without execing Claude. Today `pf frame start` always `exec_claude(...)` at the end (it is the interactive launcher). We add a `--background` flag that starts the server, writes the pid file, waits for the port file, then **blocks serving** (so the surrounding `nohup … & disown` keeps the whole tree alive) — and never calls `exec_claude`.

**Files:**
- Modify: `runtime/src/pf/frame/cli.py:32-90` (the `start` command)
- Test: `runtime/src/pf/tests/test_frame_background.py` (create)

- [ ] **Step 1: Write the failing test.**

Create `runtime/src/pf/tests/test_frame_background.py`:
```python
"""Tests for `pf frame start --background` (server-only mode, no Claude exec)."""

from unittest.mock import MagicMock, patch

from click.testing import CliRunner

from pf.frame.cli import frame


def test_background_flag_exists():
    """`pf frame start --help` advertises a --background flag."""
    runner = CliRunner()
    result = runner.invoke(frame, ["start", "--help"])
    assert result.exit_code == 0
    assert "--background" in result.output


def test_background_does_not_exec_claude(tmp_path):
    """With --background, the server starts but Claude is never exec'd."""
    fake_proc = MagicMock()
    fake_proc.pid = 4321
    with (
        patch("pf.frame.launcher.resolve_project_dir", return_value=tmp_path),
        patch("pf.frame.launcher.is_already_running", return_value=(False, None, None)),
        patch("pf.frame.launcher.start_frame", return_value=fake_proc),
        patch("pf.frame.launcher.write_pid_file"),
        patch("pf.frame.launcher.poll_for_port_file", return_value=9999),
        patch("pf.frame.launcher.exec_claude") as mock_exec,
        patch("pf.frame.launcher.register_cleanup"),
    ):
        # In --background mode the command blocks on proc.wait(); make it return.
        fake_proc.wait.return_value = 0
        runner = CliRunner()
        result = runner.invoke(frame, ["start", "--background", "--project-dir", str(tmp_path)])

    assert result.exit_code == 0
    mock_exec.assert_not_called()
    fake_proc.wait.assert_called_once()
```

- [ ] **Step 2: Run the test to verify it fails.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_frame_background.py -q
```
Expected: FAIL — `--background` is not a recognized option (and/or `exec_claude` is still called).

- [ ] **Step 3: Implement the `--background` flag.**

In `runtime/src/pf/frame/cli.py`, add the option to the `start` command and branch before any `exec_claude` call. The full updated `start` command:
```python
@frame.command()
@click.option(
    "--project-dir",
    type=click.Path(exists=True, file_okay=False, resolve_path=True),
    default=None,
    help="Project directory (where .pennyfarthing/ lives). Falls back to FRAME_PROJECT_DIR env var, then cwd.",
)
@click.option("--dry-run", is_flag=True, help="Show what would be done without making changes")
@click.option(
    "--background",
    is_flag=True,
    help="Start only the Frame server (no Claude exec). Blocks serving; intended to be wrapped in `nohup … & disown`.",
)
def start(project_dir, dry_run, background):
    """Start Frame mode.

    Starts Frame server in background, waits for readiness,
    sets OTEL env vars, and execs Claude CLI.

    With --background, starts only the server and blocks (no Claude exec).
    """
    from pf.frame.launcher import (
        build_otel_env,
        exec_claude,
        is_already_running,
        poll_for_port_file,
        register_cleanup,
        resolve_project_dir,
        start_frame,
        write_pid_file,
    )

    project_dir = resolve_project_dir(project_dir)

    if dry_run:
        click.echo("[DRY-RUN] Would start Frame mode")
        click.echo(f"  Project: {project_dir}")
        click.echo("  Actions: start Frame server, set OTEL env, exec Claude CLI")
        return

    running, pid, port = is_already_running(project_dir)
    if running:
        if background:
            # Server already up — nothing to do in server-only mode.
            click.echo(f"Frame already running (PID {pid}, port {port})")
            return
        # Idempotent: Frame already up, just exec Claude with OTEL env
        click.echo(f"Frame already running (PID {pid}, port {port})")
        otel_env = build_otel_env(port)
        click.echo("Starting Claude CLI...")
        exec_claude(otel_env, project_dir)

    click.echo("Starting Frame mode...")
    try:
        proc = start_frame(project_dir)
        if isinstance(proc, dict):
            click.echo(f"Error: {proc['error']}", err=True)
            sys.exit(1)
        write_pid_file(project_dir, proc.pid)

        port = poll_for_port_file(project_dir, proc=proc)
        click.echo(f"Frame server listening on port {port}")

        if background:
            # Server-only: keep this process alive babysitting uvicorn so the
            # enclosing `nohup … & disown` keeps the whole tree alive. No Claude exec.
            register_cleanup(project_dir, proc.pid)
            proc.wait()
            return

        otel_env = build_otel_env(port)
        click.echo("Setting OTEL environment variables...")

        register_cleanup(project_dir, proc.pid)

        click.echo("Starting Claude CLI...")
        exec_claude(otel_env, project_dir)
    except (RuntimeError, TimeoutError) as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)
```
(If the existing `start` body already has a trailing `except` block past line 90, preserve it; the key edits are the `--background` option, the early `return` in the already-running branch, and the `if background: … proc.wait(); return` block before `exec_claude`.)

- [ ] **Step 4: Run the test to verify it passes.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_frame_background.py -q
```
Expected: PASS (2 passed).

- [ ] **Step 5: Commit.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add runtime/src/pf/frame/cli.py runtime/src/pf/tests/test_frame_background.py
git commit -m "feat(frame): add --background server-only mode for plugin SessionStart hook"
```

---

## Task 3: Stop the SessionStart Python handler from spawning Frame

**Why:** A Popen child spawned inside the plugin SessionStart hook dies on process-group exit (spike Q4). Frame is launched by the shell wrapper via `nohup` instead (Task 6). The Python handler must no longer *spawn* Frame; it only *reads* the port (brief poll) to write OTEL env, so OTEL still works within the session once the nohup'd server comes up.

**Files:**
- Modify: `runtime/src/pf/hooks/session_start.py:171-193` (`_ensure_frame`) and `:414` (its call site)
- Test: `runtime/src/pf/tests/test_session_start_no_spawn.py` (create)

- [ ] **Step 1: Write the failing test.**

Create `runtime/src/pf/tests/test_session_start_no_spawn.py`:
```python
"""SessionStart handler must NOT spawn Frame (the shell wrapper does, via nohup)."""

import io
import json
from unittest.mock import patch

import pf.hooks.session_start as ss


def test_session_start_does_not_spawn_frame(tmp_path, monkeypatch):
    """main() must not call start_frame; Frame spawning moved to the shell wrapper."""
    monkeypatch.setenv("CLAUDE_PROJECT_DIR", str(tmp_path))
    monkeypatch.delenv("CLAUDE_ENV_FILE", raising=False)
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps({"session_id": "x", "source": "startup"})))

    with patch("pf.frame.launcher.start_frame") as mock_start:
        try:
            ss.main()
        except SystemExit:
            pass

    mock_start.assert_not_called()


def test_await_frame_port_reads_existing_port(tmp_path):
    """_await_frame_port returns the port from an existing .frame-port without spawning."""
    (tmp_path / ".frame-port").write_text("12345")
    assert ss._await_frame_port(tmp_path, timeout=0.1) == 12345


def test_await_frame_port_returns_none_when_absent(tmp_path):
    """_await_frame_port returns None (no spawn) if no port file appears in time."""
    assert ss._await_frame_port(tmp_path, timeout=0.1) is None
```

- [ ] **Step 2: Run the test to verify it fails.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_session_start_no_spawn.py -q
```
Expected: FAIL — `_await_frame_port` does not exist; `start_frame` is still called via `_ensure_frame`.

- [ ] **Step 3: Replace `_ensure_frame` with a poll-only `_await_frame_port`.**

In `runtime/src/pf/hooks/session_start.py`, replace the `_ensure_frame` function (currently lines ~171-193) with:
```python
# =============================================================================
# Frame Port (read-only — Frame is launched by the SessionStart shell wrapper)
# =============================================================================


def _await_frame_port(project_dir: Path, timeout: float = 5.0) -> int | None:
    """Read the Frame server port written by the nohup-launched server.

    Frame is started by the SessionStart shell wrapper (`nohup … pf frame
    start --background & disown`), not by this handler — a Popen child here
    would be killed when the hook's process group exits (spike Q4). We only
    poll briefly for the .frame-port file so OTEL env can be wired this session.
    Returns the port, or None if Frame has not come up in time.
    """
    import time

    port_file = project_dir / ".frame-port"
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if port_file.exists():
            try:
                return int(port_file.read_text().strip())
            except (ValueError, OSError):
                return None
        time.sleep(0.2)
    return None
```
Then update the call site in `main()` (currently `otel_port = _ensure_frame(project_dir)` at ~line 414):
```python
        otel_port = _await_frame_port(project_dir)
        _write_env_file(project_dir, session_id, otel_port)
```
Remove the now-unused `pf.frame.launcher` import inside the old `_ensure_frame` (it lived in the function body, so deleting the function removes it). Do not touch `_write_env_file`, `detect_incomplete_setup` (the legacy-detection path — keep it, per instructions), or any other handler logic.

- [ ] **Step 4: Run the test to verify it passes.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_session_start_no_spawn.py -q
```
Expected: PASS (3 passed).

- [ ] **Step 5: Run the existing session_start tests to check for regressions.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/ -q -k "session_start or session-start"
```
Expected: PASS. If a pre-existing test asserted `_ensure_frame` was called, update it to reflect the new no-spawn contract (Frame launch is now the wrapper's job).

- [ ] **Step 6: Commit.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add runtime/src/pf/hooks/session_start.py runtime/src/pf/tests/test_session_start_no_spawn.py
git commit -m "refactor(hooks): SessionStart no longer spawns Frame (wrapper uses nohup)"
```

---

## Task 4: Rewrite `sprint_yaml_validation.py` in Python (ruamel.yaml)

**Why:** The current handler shells out to Node (`node --input-type=module … import { parse } from 'yaml'`). The `yaml` npm package is not reliably present (broken in the orchestrator — see auto-memory), so the hook silently no-ops. `ruamel.yaml` is already a runtime dependency and parses YAML 1.2, matching the strictness the Cyclist SprintPanel needs.

**Files:**
- Rewrite: `runtime/src/pf/hooks/sprint_yaml_validation.py`
- Test: `runtime/src/pf/tests/test_sprint_yaml_validation_hook.py` (create)

- [ ] **Step 1: Write the failing test.**

Create `runtime/src/pf/tests/test_sprint_yaml_validation_hook.py`:
```python
"""PostToolUse sprint-yaml hook: ruamel-based YAML 1.2 validation."""

import io
import json

import pf.hooks.sprint_yaml_validation as syv


def _run(monkeypatch, capsys, tool_name, file_path):
    payload = {"tool_name": tool_name, "tool_input": {"file_path": file_path}}
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    try:
        syv.main()
    except SystemExit:
        pass
    return capsys.readouterr().out


def test_valid_sprint_yaml_is_silent(tmp_path, monkeypatch, capsys):
    f = tmp_path / "sprint" / "current-sprint.yaml"
    f.parent.mkdir(parents=True)
    f.write_text("sprint: 2618\nstories:\n  - id: '8-1'\n    status: active\n")
    out = _run(monkeypatch, capsys, "Write", str(f))
    assert out.strip() == ""


def test_invalid_sprint_yaml_emits_additional_context(tmp_path, monkeypatch, capsys):
    f = tmp_path / "sprint" / "current-sprint.yaml"
    f.parent.mkdir(parents=True)
    # Tab indentation is invalid YAML — guaranteed parse error.
    f.write_text("stories:\n\t- id: bad\n")
    out = _run(monkeypatch, capsys, "Write", str(f))
    assert "SPRINT YAML VALIDATION FAILED" in out
    data = json.loads([ln for ln in out.splitlines() if ln.startswith("{")][0])
    assert "additionalContext" in data["hookSpecificOutput"]


def test_non_sprint_file_skipped(tmp_path, monkeypatch, capsys):
    f = tmp_path / "notes.yaml"
    f.write_text("\t bad: yaml")
    out = _run(monkeypatch, capsys, "Write", str(f))
    assert out.strip() == ""


def test_non_write_tool_skipped(tmp_path, monkeypatch, capsys):
    f = tmp_path / "sprint" / "current-sprint.yaml"
    f.parent.mkdir(parents=True)
    f.write_text("\t bad")
    out = _run(monkeypatch, capsys, "Read", str(f))
    assert out.strip() == ""
```

- [ ] **Step 2: Run the test to verify it fails.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_sprint_yaml_validation_hook.py -q
```
Expected: FAIL — the invalid-YAML case currently no-ops (Node path), so no `additionalContext` is emitted.

- [ ] **Step 3: Rewrite the handler with ruamel.yaml.**

Replace the body of `runtime/src/pf/hooks/sprint_yaml_validation.py` with:
```python
"""
Sprint YAML validation hook (PostToolUse) — validate sprint YAML after edits.

Validates that sprint YAML files parse under YAML 1.2 (the strictness the
Cyclist SprintPanel's parser requires). When validation fails, returns
additionalContext prompting the agent to fix the format. Uses ruamel.yaml
(a runtime dependency) — no Node toolchain required.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from pf.hooks import (
    HookResponse,
    output_hook_response,
)


def main() -> None:
    """Main entry point for sprint YAML validation hook."""
    try:
        raw = sys.stdin.read()
        try:
            input_data = json.loads(raw)
        except (json.JSONDecodeError, ValueError):
            sys.exit(0)

        tool_name = input_data.get("tool_name", "")
        tool_input = input_data.get("tool_input", {})
        file_path = tool_input.get("file_path", "")

        if tool_name not in ("Edit", "Write"):
            sys.exit(0)

        if not re.search(r"sprint/.*\.(yaml|yml)$", file_path):
            sys.exit(0)

        path = Path(file_path)
        if not path.is_file():
            sys.exit(0)

        from ruamel.yaml import YAML
        from ruamel.yaml.error import YAMLError

        yaml = YAML(typ="safe")
        yaml.version = (1, 2)
        try:
            with path.open(encoding="utf-8") as fh:
                yaml.load(fh)
        except YAMLError as exc:
            error_text = str(exc).replace("\n", " ").strip()
            output_hook_response(
                HookResponse(
                    event_name="PostToolUse",
                    additional_context=(
                        f"SPRINT YAML VALIDATION FAILED\n\n"
                        f"File: {file_path}\n"
                        f"Error: {error_text}\n\n"
                        f"The sprint YAML file has invalid syntax that will break the "
                        f"Cyclist SprintPanel.\n\n"
                        f"Common fix: Single-quoted strings cannot contain blank lines in "
                        f"YAML 1.2. Use literal block scalars (|) for multiline strings instead."
                    ),
                )
            )

    except SystemExit:
        raise
    except Exception:
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the test to verify it passes.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_sprint_yaml_validation_hook.py -q
```
Expected: PASS (4 passed).

- [ ] **Step 5: Confirm `ruamel.yaml` is a declared dependency.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -i ruamel runtime/pyproject.toml
```
Expected: a `ruamel.yaml` entry. If absent (it is used elsewhere, so it should be present transitively), add it explicitly to `runtime/pyproject.toml` `[project] dependencies` and run `uv lock` in `runtime/`, then commit `uv.lock`.

- [ ] **Step 6: Commit.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add runtime/src/pf/hooks/sprint_yaml_validation.py runtime/src/pf/tests/test_sprint_yaml_validation_hook.py
git commit -m "fix(hooks): rewrite sprint-yaml validation in Python (ruamel, drop Node)"
```

---

## Task 5: Create the dispatch wrapper scripts

**Files:**
- Create: `scripts/hooks/dispatch.sh`
- Create: `scripts/hooks/session-start.sh` (replaces the deleted dead shim)

- [ ] **Step 1: Write the generic dispatch wrapper.**

Create `scripts/hooks/dispatch.sh`:
```bash
#!/usr/bin/env bash
# Plugin lifecycle hook wrapper: run the pf dispatcher for one event.
# Registered in hooks/hooks.json. $1 is the event name (PreToolUse, etc).
set -uo pipefail
exec uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" --quiet \
  pf hooks dispatch "$1"
```

- [ ] **Step 2: Write the SessionStart wrapper (Frame nohup + dispatch).**

Create `scripts/hooks/session-start.sh`:
```bash
#!/usr/bin/env bash
# SessionStart plugin hook wrapper.
# 1. Launch the Frame server detached so it outlives this session.
#    `nohup … & disown` is the ONLY spawn pattern that survives Claude Code's
#    hook process-group kill on macOS (spike Q4); plain backgrounding and
#    `setsid` get killed.
# 2. Run the SessionStart dispatcher (session setup, OTEL wiring, agent context).
set -uo pipefail

nohup uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" --quiet \
  pf frame start --background >/dev/null 2>&1 &
disown

exec uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" --quiet \
  pf hooks dispatch SessionStart
```

- [ ] **Step 3: Make both wrappers executable.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
chmod +x scripts/hooks/dispatch.sh scripts/hooks/session-start.sh
```

- [ ] **Step 4: Sanity-check the wrappers parse as bash.**

```bash
bash -n scripts/hooks/dispatch.sh && bash -n scripts/hooks/session-start.sh && echo "OK"
```
Expected: `OK`.

- [ ] **Step 5: Commit.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add scripts/hooks/dispatch.sh scripts/hooks/session-start.sh
git commit -m "feat(hooks): add plugin dispatch wrappers (SessionStart launches Frame via nohup)"
```

---

## Task 6: Create `hooks/hooks.json`

**Files:**
- Create: `hooks/hooks.json`

- [ ] **Step 1: Write the manifest (nested schema).**

Create `hooks/hooks.json`. The 6 events match `DISPATCH_REGISTRY` in `dispatch.py`. SessionStart uses the Frame-launching wrapper; the rest use the generic wrapper with the event name as the argument. No `matcher` keys are needed — `dispatch.py` does matcher routing internally.
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/dispatch.sh Stop" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/dispatch.sh PreToolUse" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/dispatch.sh PostToolUse" }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/dispatch.sh SessionEnd" }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/dispatch.sh PreCompact" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate the manifest with the plugin validator.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
claude plugin validate 2>&1 | tail -20
```
Expected: validation passes (no schema errors for `hooks.json`). If the validator rejects the `dispatch.sh PreToolUse` argument form (command-with-arg), fall back to per-event wrapper files (`pretooluse.sh`, `posttooluse.sh`, …) each hardcoding its event, and update this task's files accordingly. Capture the validator output either way.

- [ ] **Step 3: Commit.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add hooks/hooks.json
git commit -m "feat(hooks): register lifecycle hooks in plugin hooks.json (dispatcher, nested schema)"
```

---

## Task 7: Delete obsolete shims and retire `test_wrapper_removal.py`

**Files:**
- Delete: `scripts/hooks/{session-start,session-stop,schema-validation,pre-edit-check,context-warning,context-circuit-breaker,question-reflector-check,sprint-yaml-validation,welcome-hook,otel-auto-config}.sh` — **except** `session-start.sh`, which Task 5 just (re)created with new content. (i.e. delete the other dead shims; the new `session-start.sh` and `dispatch.sh` stay.)
- Delete: `runtime/src/pf/tests/test_wrapper_removal.py`
- Create: `runtime/src/pf/tests/test_plugin_hooks.py`

- [ ] **Step 1: Check for symlinks before deleting (trap guard).**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
find scripts/hooks -type l
```
Expected: no output (no symlinks). If any listed file is a symlink, trace it before removing.

- [ ] **Step 2: Delete the dead shims.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git rm scripts/hooks/session-stop.sh scripts/hooks/schema-validation.sh \
  scripts/hooks/pre-edit-check.sh scripts/hooks/context-warning.sh \
  scripts/hooks/context-circuit-breaker.sh scripts/hooks/question-reflector-check.sh \
  scripts/hooks/sprint-yaml-validation.sh scripts/hooks/welcome-hook.sh \
  scripts/hooks/otel-auto-config.sh
```
(Do NOT remove `pre-commit.sh`, `pre-push.sh`, `post-merge.sh`, `dispatcher-template.sh` — those are git hooks, out of scope. Do NOT remove the new `session-start.sh` / `dispatch.sh`.)

- [ ] **Step 3: Write the replacement test.**

Create `runtime/src/pf/tests/test_plugin_hooks.py`:
```python
"""Plugin hooks wiring: hooks.json registers the dispatcher; wrappers are correct."""

import json

from pf.common.config import get_dist_root

_ROOT = get_dist_root()
_EVENTS = {"SessionStart", "Stop", "PreToolUse", "PostToolUse", "SessionEnd", "PreCompact"}


def test_hooks_json_exists_and_parses():
    hj = _ROOT / "hooks" / "hooks.json"
    assert hj.is_file(), "hooks/hooks.json missing"
    data = json.loads(hj.read_text())
    assert set(data["hooks"]) == _EVENTS


def test_hooks_use_nested_command_schema():
    """Every registration uses the nested {hooks:[{type:command,command}]} form."""
    data = json.loads((_ROOT / "hooks" / "hooks.json").read_text())
    for event, entries in data["hooks"].items():
        for entry in entries:
            assert "hooks" in entry, f"{event}: missing nested 'hooks' key"
            for h in entry["hooks"]:
                assert h["type"] == "command"
                assert "${CLAUDE_PLUGIN_ROOT}" in h["command"]


def test_session_start_wrapper_launches_frame_with_nohup():
    w = _ROOT / "scripts" / "hooks" / "session-start.sh"
    assert w.is_file()
    text = w.read_text()
    assert "nohup" in text and "disown" in text, "Frame must be launched nohup … & disown (spike Q4)"
    assert "pf frame start --background" in text
    assert "pf hooks dispatch SessionStart" in text


def test_dispatch_wrapper_runs_uv_dispatch():
    w = _ROOT / "scripts" / "hooks" / "dispatch.sh"
    assert w.is_file()
    text = w.read_text()
    assert "uv run --project" in text
    assert "pf hooks dispatch" in text


def test_dead_shims_removed():
    hooks_dir = _ROOT / "scripts" / "hooks"
    for dead in ("session-stop.sh", "schema-validation.sh", "otel-auto-config.sh", "welcome-hook.sh"):
        assert not (hooks_dir / dead).exists(), f"dead shim {dead} should be deleted"
```

- [ ] **Step 4: Delete the obsolete test.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git rm runtime/src/pf/tests/test_wrapper_removal.py
```

- [ ] **Step 5: Run the new test.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_plugin_hooks.py -q
```
Expected: PASS (5 passed).

- [ ] **Step 6: Commit.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A scripts/hooks runtime/src/pf/tests/test_plugin_hooks.py
git commit -m "chore(hooks): delete dead shims; retire inverted test_wrapper_removal"
```

---

## Task 8: End-to-end verification — hooks fire and Frame survives

**Why:** The unit tests prove wiring shape; this proves real behavior. Per CLAUDE.md ("test the feature in the real app") and SOUL §14 ("prove the work"). Spike Q4 validated the nohup *pattern* with a toy process — this validates it for the *actual* Frame server.

**Files:** none (verification only).

- [ ] **Step 1: Install the plugin from the worktree source.**

```bash
claude plugin marketplace add /Users/slabgorb/Projects/orc-penny-pf-migration
claude plugin install pf@pennyfarthing
```
Expected: install succeeds. (`${CLAUDE_PLUGIN_ROOT}` will resolve to the worktree — spike Q1/Q2.)

- [ ] **Step 2: Verify hooks fire in a throwaway repo.**

```bash
cd /tmp && rm -rf hooks-verify && mkdir hooks-verify && cd hooks-verify && git init -q
```
Start a fresh Claude Code session in `/tmp/hooks-verify` (with the plugin enabled). In that session, observe: (a) no startup error from the SessionStart hook; (b) a PostToolUse edit to a malformed `sprint/current-sprint.yaml` produces the "SPRINT YAML VALIDATION FAILED" additionalContext. Record what you observe — if you cannot drive a real session here, say so explicitly rather than claiming success.

- [ ] **Step 3: Verify Frame survives session exit.**

After the session in Step 2 has started Frame, exit the session, then:
```bash
sleep 2
cat /tmp/hooks-verify/.frame-port 2>/dev/null && echo "port file present"
pgrep -f "uvicorn pf.frame" || pgrep -f "pf.frame.app" || echo "NO frame process"
```
Expected: the Frame uvicorn process is still alive after the session exits (proves `nohup … & disown` worked for the real server). If it is dead, the nohup relocation failed — STOP and debug before proceeding (do not claim success).

- [ ] **Step 4: Clean up.**

```bash
cd /tmp && rm -rf hooks-verify
# Optionally: claude plugin uninstall pf  (leave installed if continuing to dogfood)
```

- [ ] **Step 5: Record the verification outcome** in the session/handoff notes (pass/fail per step). No commit (no files changed).

---

## Task 9: statusLine — verify plugin support or document fallback

**Why:** The statusbar (`pf hooks statusline`) is registered today as a top-level `statusLine` settings key, not a `hooks` event. Plan 4 must not silently drop it.

**Files:**
- Possibly modify: `hooks/hooks.json` or a plugin settings file (only if plugins support statusLine)
- Modify: `README.md` (worktree root) — document the statusLine setup if manual

- [ ] **Step 1: Determine whether a plugin can supply `statusLine`.**

```bash
claude plugin validate 2>&1 | grep -i status || true
```
Check Claude Code plugin docs / `claude plugin --help` for `statusLine` support in plugin manifests. Capture the finding.

- [ ] **Step 2a: If plugins support statusLine** — register it (in the location the docs specify) pointing at `uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" --quiet pf hooks statusline`, validate, and commit.

- [ ] **Step 2b: If plugins do NOT support statusLine** — add a short "Status line (optional)" subsection to `README.md` giving the one-line `statusLine` entry the user can paste into their `~/.claude/settings.json`:
```json
"statusLine": {
  "type": "command",
  "command": "uv run --project <plugin-runtime-path> --quiet pf hooks statusline"
}
```
Note that this is the one piece of setup the plugin model cannot fully automate, and that it is cosmetic (no functional impact if omitted).

- [ ] **Step 3: Commit.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "docs(hooks): document statusLine setup under plugin model"
```

---

## Task 10: Full suite green + final review

- [ ] **Step 1: Run the entire Python suite.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/ -q
```
Expected: **0 failed / 0 errors.** (Pass count will differ from 4473 — `test_wrapper_removal.py` was removed and new test modules added.) If anything fails, fix it before proceeding — do not leave the suite red.

- [ ] **Step 2: Grep for stragglers referencing the deleted shims or the Node YAML path.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -rn "otel-auto-config\|sprint-yaml-validation.sh\|welcome-hook.sh\|--input-type=module" \
  --include="*.py" --include="*.json" --include="*.md" --include="*.yaml" . \
  | grep -v node_modules | grep -v docs/superpowers | grep -v docs/archive || echo "clean"
```
Investigate any hit outside docs. The `workflows/installation-check/steps/step-04-scripts.md` table lists the old shims — update it to reflect the dispatcher wrappers if that workflow is still live.

- [ ] **Step 3: Confirm the working tree is clean and on the right branch.**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git status && git branch --show-current
```
Expected: clean tree, branch `feat/plugin-scaffold-and-paths`.

- [ ] **Step 4: Request code review** via superpowers:requesting-code-review (or the subagent-driven review stages) before considering Plan 4 complete.

---

## Self-review (author check against the spec)

- **Spec coverage:** §6.1 (settings.json → hooks.json, nested schema) → Task 6. §6.2 (hook inventory) → Tasks 5/6 via dispatcher (decision #1). §6.2 sprint-yaml Python rewrite → Task 4. §9 / §5.1 (Frame nohup) → Tasks 2/3/5. §10.1 Q4 (env/permissions) → Task 1. §6.3 gates (no shell layer) → no change needed (correct). §6.4 skills (directory presence) → out of scope (Plan 3). statusLine (not in spec) → Task 9.
- **Placeholder scan:** every code step contains full code; every command has expected output. No TBDs.
- **Type/name consistency:** `_await_frame_port` (Task 3) defined and used consistently; `--background` flag (Task 2) referenced by the wrapper (Task 5) and asserted (Task 7); event set `{SessionStart,Stop,PreToolUse,PostToolUse,SessionEnd,PreCompact}` matches `DISPATCH_REGISTRY` and the test in Task 7.
- **Known residual risks (flagged, not silently resolved):** (a) Task 6 Step 2 may reveal the validator rejects the `dispatch.sh <Event>` arg form → fallback to per-event wrappers documented inline. (b) Task 9 statusLine support is genuinely unknown → branch handled. (c) Git-hook internals (`pre-commit/pre-push/post-merge.sh`) still reference deleted `pennyfarthing-dist/` paths — out of scope, follow-up.
