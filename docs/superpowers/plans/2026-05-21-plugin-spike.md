# Pennyfarthing-as-Plugin — Plan 1: Gate 1 Spike

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal `pf-spike` Claude Code plugin and run four probes that empirically answer the open questions in `docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md` §10. Produce a spike-results document that updates the spec (or adjusts subsequent plans) before any production work begins.

**Architecture:** A throwaway plugin at `~/Projects/pf-spike/` with five small files (plugin manifest, hooks registration, a probe shell wrapper, a tiny uv-managed Python runtime, and a probe Python script). Install via Claude Code's plugin system, run four scripted probe scenarios in a clean test repo (`/tmp/pf-spike-target/`), capture observations to `/tmp/pf-spike.log`, and consolidate findings into `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md`.

**Tech Stack:** bash, Python 3.11+, uv, Claude Code plugin system (CLI: `claude plugin ...`).

**Scope Note:** This is Plan 1 of 5. Plans 2–5 (scaffold + paths refactor, content migration + prefix drop, hooks rewrite, migration tooling) cannot be written with confidence until this spike returns. Do not start Plan 2 until `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` exists and the spec has been amended with any design-impacting findings.

**Working Directory:** All implementation work for this plan happens **outside** the pennyfarthing/orc-penny repos. The spike plugin lives at `~/Projects/pf-spike/`. The only file written to a production repo is the final results document, committed to `orc-penny/` at task 11.

---

## File Structure

| File | Purpose |
|------|---------|
| `~/Projects/pf-spike/.claude-plugin/plugin.json` | Plugin manifest. Declares name `pf-spike`, version, deps. |
| `~/Projects/pf-spike/hooks/hooks.json` | Registers one SessionStart hook pointing at `scripts/hooks/probe.sh`. |
| `~/Projects/pf-spike/scripts/hooks/probe.sh` | Shell wrapper that appends env + cwd + args to `/tmp/pf-spike.log`, then execs into the Python runtime. |
| `~/Projects/pf-spike/runtime/pyproject.toml` | uv project root. One dep (none needed for spike; keep minimal). |
| `~/Projects/pf-spike/runtime/src/pf/__init__.py` | Empty package marker. |
| `~/Projects/pf-spike/runtime/src/pf/cli.py` | `pf probe` command that prints sys.argv, os.environ filtered for CLAUDE_*, cwd. |
| `~/Projects/pf-spike/.claude-plugin/marketplace.json` | Marketplace entry (single plugin), needed for `claude plugin install` from local path if marketplace-based install is required. |
| `/tmp/pf-spike-target/` | Throwaway target repo where the plugin runs. Recreated fresh for each probe. |
| `/tmp/pf-spike.log` | Probe output log. Inspected after each probe scenario. |
| `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` | Final deliverable. Lives in `orc-penny` repo. |

---

## Task 1: Verify Prerequisites

**Files:** none

- [ ] **Step 1: Check `uv` is installed**

Run: `uv --version`
Expected: outputs something like `uv 0.5.x` or later. If not present, run:

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Then re-verify with `uv --version`.

- [ ] **Step 2: Check `claude` CLI is installed and plugin commands work**

Run: `claude plugin --help`
Expected: subcommands listed include `install`, `marketplace`, `enable`, `disable`, `uninstall` (or whatever the current verb set is). Record the exact subcommand names in your shell — they go into the results doc.

- [ ] **Step 3: Check `claude plugin install` accepts a local source**

Run: `claude plugin install --help` (and `claude plugin marketplace --help` if it exists)
Expected: output names a flag for local installation. Common candidates: `--from-source <path>`, `--dir <path>`, `--local <path>`. Note the exact flag name — this is one of the unknowns the spike clarifies.

If no obvious local-install flag exists, the spike has to use the marketplace path (init a local git repo, add it as a marketplace, install from there). Either way, record the exact procedure that worked.

- [ ] **Step 4: Note current Claude Code version**

Run: `claude --version`
Expected: a version string. Record it — spike findings are tied to this version.

- [ ] **Step 5: Commit nothing (no files created yet); proceed to Task 2.**

---

## Task 2: Create Spike Plugin Repo Skeleton

**Files:**
- Create: `~/Projects/pf-spike/.claude-plugin/plugin.json`
- Create: `~/Projects/pf-spike/.claude-plugin/marketplace.json`
- Create: `~/Projects/pf-spike/hooks/hooks.json`
- Create: `~/Projects/pf-spike/scripts/hooks/probe.sh`
- Create: `~/Projects/pf-spike/runtime/pyproject.toml`
- Create: `~/Projects/pf-spike/runtime/src/pf/__init__.py`
- Create: `~/Projects/pf-spike/runtime/src/pf/cli.py`
- Create: `~/Projects/pf-spike/.gitignore`
- Create: `~/Projects/pf-spike/README.md`

- [ ] **Step 1: Create directory tree**

Run:

```sh
mkdir -p ~/Projects/pf-spike/{.claude-plugin,hooks,scripts/hooks,runtime/src/pf}
cd ~/Projects/pf-spike
git init
```

Expected: `.git/` created. `tree -L 3 ~/Projects/pf-spike` shows the directory structure.

- [ ] **Step 2: Write `plugin.json`**

Create `~/Projects/pf-spike/.claude-plugin/plugin.json`:

```json
{
  "name": "pf-spike",
  "description": "Throwaway spike plugin used to validate assumptions before the Pennyfarthing plugin migration. Delete after spike completes.",
  "version": "0.0.1",
  "author": { "name": "Keith Avery", "email": "slabgorb@gmail.com" },
  "license": "Apache-2.0"
}
```

- [ ] **Step 3: Write `marketplace.json`**

Create `~/Projects/pf-spike/.claude-plugin/marketplace.json`:

```json
{
  "name": "pf-spike",
  "owner": {
    "name": "Keith Avery",
    "email": "slabgorb@gmail.com"
  },
  "plugins": [
    {
      "name": "pf-spike",
      "source": ".",
      "description": "Throwaway spike plugin",
      "version": "0.0.1"
    }
  ]
}
```

(If the install flow in Task 1 step 3 uses a different schema, adjust here — record the schema variant used in spike-results.md.)

- [ ] **Step 4: Write `hooks.json`**

Create `~/Projects/pf-spike/hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/probe.sh session-start" }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/probe.sh pre-bash" }
    ]
  }
}
```

- [ ] **Step 5: Write the probe shell wrapper**

Create `~/Projects/pf-spike/scripts/hooks/probe.sh`:

```sh
#!/usr/bin/env bash
# Records every hook firing to /tmp/pf-spike.log so we can inspect what
# Claude Code passes us. Also delegates to the Python runtime so we can
# observe the runtime side of the same firing.

set -euo pipefail

LOG=/tmp/pf-spike.log
HOOK_TAG="${1:-unknown}"
TS="$(date -u +%Y-%m-%dT%H:%M:%S.%NZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "================================================================"
  echo "[${TS}] hook=${HOOK_TAG}"
  echo "  CLAUDE_PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT:-<unset>}"
  echo "  cwd=$(pwd)"
  echo "  PPID=${PPID}"
  echo "  argv=$*"
  echo "  --- env (CLAUDE_*, USER, HOME) ---"
  env | grep -E '^(CLAUDE_|USER=|HOME=|PWD=)' | sort
  echo "  --- stdin (first 1024 bytes) ---"
} >>"${LOG}"

# Read stdin (Claude Code may pass tool input/output JSON on stdin)
head -c 1024 >>"${LOG}" || true
echo "" >>"${LOG}"
echo "  --- end stdin ---" >>"${LOG}"

# Delegate to Python runtime so we observe both shell and Python views
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -d "${CLAUDE_PLUGIN_ROOT}/runtime" ]]; then
  uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" --quiet \
    pf probe "${HOOK_TAG}" >>"${LOG}" 2>&1 || \
    echo "  [pf probe failed: $?]" >>"${LOG}"
fi

exit 0  # Never block Claude Code — this is purely observational
```

Then: `chmod +x ~/Projects/pf-spike/scripts/hooks/probe.sh`

- [ ] **Step 6: Write the runtime `pyproject.toml`**

Create `~/Projects/pf-spike/runtime/pyproject.toml`:

```toml
[project]
name = "pf-spike-runtime"
version = "0.0.1"
description = "Spike runtime for plugin assumption probes"
requires-python = ">=3.11"
dependencies = []

[project.scripts]
pf = "pf.cli:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/pf"]
```

- [ ] **Step 7: Write the runtime probe Python module**

Create `~/Projects/pf-spike/runtime/src/pf/__init__.py` (empty file):

```python
```

Create `~/Projects/pf-spike/runtime/src/pf/cli.py`:

```python
"""Spike runtime probe. Prints what the runtime sees when invoked via uv from a plugin hook."""

import json
import os
import sys
from pathlib import Path


def main() -> int:
    tag = sys.argv[1] if len(sys.argv) > 1 else "no-tag"
    print(f"[runtime] tag={tag}")
    print(f"[runtime] sys.executable={sys.executable}")
    print(f"[runtime] sys.argv={sys.argv}")
    print(f"[runtime] cwd={os.getcwd()}")
    print(f"[runtime] __file__={Path(__file__).resolve()}")
    claude_env = {k: v for k, v in os.environ.items() if k.startswith("CLAUDE_")}
    print(f"[runtime] CLAUDE_env={json.dumps(claude_env, indent=2)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 8: Write `.gitignore` and `README.md`**

Create `~/Projects/pf-spike/.gitignore`:

```
__pycache__/
*.pyc
.venv/
uv.lock
```

(uv.lock intentionally not committed for a spike — it's throwaway.)

Create `~/Projects/pf-spike/README.md`:

```markdown
# pf-spike

Throwaway plugin used to answer the four open questions in
`orc-penny/docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md` §10.

DELETE after spike completes.
```

- [ ] **Step 9: Verify the runtime works locally before installing as plugin**

Run:

```sh
cd ~/Projects/pf-spike/runtime
uv run pf probe local-smoke-test
```

Expected: stdout shows lines like `[runtime] tag=local-smoke-test`, `[runtime] cwd=/Users/slabgorb/Projects/pf-spike/runtime`, `[runtime] CLAUDE_env={}`. If `uv` fails with a build/resolve error, fix the pyproject.toml before continuing.

- [ ] **Step 10: Commit the spike repo skeleton**

```sh
cd ~/Projects/pf-spike
git add .
git commit -m "spike: scaffold pf-spike plugin for plugin-assumption probes"
```

---

## Task 3: Install the Spike Plugin and Run Q1 — `${CLAUDE_PLUGIN_ROOT}` Semantics

**Files:**
- Create: `/tmp/pf-spike-target/` (throwaway target repo)
- Inspect: `/tmp/pf-spike.log`

**Question being answered:** Does `${CLAUDE_PLUGIN_ROOT}` expand correctly inside hook commands and inside agent markdown Bash invocations? What value does it hold? Is cwd inside the hook the user's project root, or something else?

- [ ] **Step 1: Clear the log**

Run: `rm -f /tmp/pf-spike.log && touch /tmp/pf-spike.log`

- [ ] **Step 2: Install the spike plugin from local source**

Run (use whichever syntax actually worked in Task 1 step 3; this is the most likely form):

```sh
claude plugin marketplace add ~/Projects/pf-spike
claude plugin install pf-spike@pf-spike
```

Expected: command succeeds. Verify install with:

```sh
cat ~/.claude/plugins/installed_plugins.json | grep -A 5 pf-spike
```

Expected: an entry for `pf-spike@pf-spike` with an `installPath`. Record the `installPath` — this is the value `${CLAUDE_PLUGIN_ROOT}` should expand to.

- [ ] **Step 3: Create a clean target repo and launch Claude Code in it**

```sh
rm -rf /tmp/pf-spike-target
mkdir -p /tmp/pf-spike-target
cd /tmp/pf-spike-target
git init
echo "spike target" > README.md
git add README.md
git commit -m "init"
```

Then launch Claude Code in this directory: `claude` (or however your session normally starts). Wait for the SessionStart hook to fire.

- [ ] **Step 4: Inspect the log**

Run: `cat /tmp/pf-spike.log`

Expected entries to verify and record:
- A `hook=session-start` block exists
- `CLAUDE_PLUGIN_ROOT=` shows a real path
- That path matches the `installPath` recorded in Step 2
- `cwd=` shows `/tmp/pf-spike-target` (or whatever cwd Claude Code provides — record what you actually see)
- The `[runtime]` block appears (proving uv-run from inside a hook works)
- `[runtime] CLAUDE_env=` shows whatever Claude-scoped env vars are exposed

- [ ] **Step 5: Trigger PreToolUse:Bash to confirm hook firing on tool use**

Inside the Claude session, run any Bash tool call (e.g., ask Claude to `ls` the cwd). Then back in your terminal:

```sh
grep "hook=pre-bash" /tmp/pf-spike.log
```

Expected: one or more `hook=pre-bash` entries with the same `CLAUDE_PLUGIN_ROOT` value as in step 4.

- [ ] **Step 6: Record findings for Q1**

In your scratch notes (will be consolidated in Task 7), write:

```
Q1: CLAUDE_PLUGIN_ROOT semantics
- Value: <recorded path>
- Stable across hook firings: yes / no
- cwd inside hook: <observed value>
- uv run works from inside hook: yes / no
- runtime sees CLAUDE_PLUGIN_ROOT in env: yes / no
- Any surprises: <note them>
```

---

## Task 4: Run Q2 — `--from-source` Hot-Reload Behavior

**Files:** modify `~/Projects/pf-spike/runtime/src/pf/cli.py`

**Question being answered:** If we install via local source and then edit a file inside the spike repo, does Claude Code pick up the change on the next session, or does it require a re-install?

- [ ] **Step 1: Verify current state**

Confirm the spike plugin is still installed (from Task 3). Run a probe to capture a baseline log entry. Note the current `print(f"[runtime] tag={tag}")` line is the line we will change.

- [ ] **Step 2: Edit the runtime to change probe output**

In `~/Projects/pf-spike/runtime/src/pf/cli.py`, change:

```python
print(f"[runtime] tag={tag}")
```

to:

```python
print(f"[runtime] tag={tag} EDIT-CHECK-Q2")
```

Commit (so the diff is observable):

```sh
cd ~/Projects/pf-spike
git add runtime/src/pf/cli.py
git commit -m "spike: edit probe for Q2 hot-reload test"
```

- [ ] **Step 3: Start a fresh Claude session WITHOUT reinstalling**

```sh
rm -f /tmp/pf-spike.log
cd /tmp/pf-spike-target
claude  # new session
# wait for SessionStart hook
```

Then exit Claude.

- [ ] **Step 4: Check whether the edit was picked up**

Run: `grep "EDIT-CHECK-Q2" /tmp/pf-spike.log`

Expected: either it appears (hot-reload works — `--from-source` is a live link to the repo) or it doesn't (Claude Code cached a copy at install time and ignores subsequent edits).

- [ ] **Step 5: If no hot-reload, test the explicit update path**

If step 4 found no EDIT-CHECK-Q2 entry, try whichever of these update commands actually exists:

```sh
claude plugin update pf-spike
# OR
claude plugin install pf-spike@pf-spike  # reinstall over existing
# OR
claude plugin marketplace update pf-spike
```

Record which command (if any) caused subsequent sessions to pick up the edit.

- [ ] **Step 6: Test the "uninstall + reinstall" loop time**

If no in-place update command works, measure the friction of uninstall+reinstall:

```sh
time claude plugin uninstall pf-spike
time claude plugin install pf-spike@pf-spike
```

Record the wall-clock time and whether this loop preserves the install path (or moves it).

- [ ] **Step 7: Record findings for Q2**

```
Q2: --from-source hot-reload
- Method used to install: <exact command(s) from Task 3 step 2>
- Edit picked up without reinstall: yes / no
- Update command that works (if needed): <command or "none">
- Uninstall+reinstall time: <seconds>
- Install path stable across reinstalls: yes / no
- Implication for D1 (orchestrator dogfooding): <note>
```

---

## Task 5: Run Q3 — Hook Ordering vs User `~/.claude/settings.json`

**Files:** temporarily modify `~/.claude/settings.json` (revert after task)

**Question being answered:** If the user has a SessionStart hook in their global settings AND the plugin registers a SessionStart hook, which fires first? Do both fire?

- [ ] **Step 1: Back up user settings**

```sh
cp ~/.claude/settings.json ~/.claude/settings.json.spike-backup
```

- [ ] **Step 2: Add a user-level probe hook**

Edit `~/.claude/settings.json` and add to the `hooks.SessionStart` array (create the keys if absent):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "command": "echo \"[USER-HOOK $(date -u +%H:%M:%S.%N)] cwd=$(pwd) CLAUDE_PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT:-<unset>}\" >> /tmp/pf-spike.log"
      }
    ]
  }
}
```

Be careful to merge with existing settings, not replace them. If your settings.json has other content, do a manual merge. Validate the result with: `jq . ~/.claude/settings.json` (must parse).

- [ ] **Step 3: Clear log and run a session**

```sh
rm -f /tmp/pf-spike.log
cd /tmp/pf-spike-target
claude  # fresh session, exit immediately
```

- [ ] **Step 4: Inspect ordering**

Run: `cat /tmp/pf-spike.log`

Expected: at least one `[USER-HOOK ...]` line and at least one `hook=session-start` block (from the plugin). Note the order they appear in. The earlier-written line fired first.

- [ ] **Step 5: Restore user settings**

```sh
mv ~/.claude/settings.json.spike-backup ~/.claude/settings.json
```

Verify: `jq . ~/.claude/settings.json` parses, and no `[USER-HOOK ...]` entries appear in subsequent logs.

- [ ] **Step 6: Record findings for Q3**

```
Q3: Hook ordering
- Both fired: yes / no
- Order: <user-first | plugin-first | indeterminate>
- CLAUDE_PLUGIN_ROOT visible to user hook: yes / no
- Implication for Pennyfarthing migration:
  (if order matters, document how to handle; e.g., "any user-installed
   hooks fire after plugin hooks, so user-level overrides are advisory")
```

---

## Task 6: Run Q4 — Long-Running Processes from Hooks

**Files:** temporarily modify `~/Projects/pf-spike/scripts/hooks/probe.sh`

**Question being answered:** Can a hook spawn a long-running process (like `pf frame start` would) and have it survive the hook's exit and the Claude Code session? Or does Claude Code kill it?

- [ ] **Step 1: Modify the probe to spawn a long-running sleep**

Edit `~/Projects/pf-spike/scripts/hooks/probe.sh`. Just before the final `exit 0`, add:

```sh
# Q4 probe: spawn a long-running child and record its PID
if [[ "${HOOK_TAG}" == "session-start" ]]; then
  (
    setsid bash -c 'sleep 120; echo "[long-process] survived until $(date -u +%H:%M:%S)" >> /tmp/pf-spike.log' &
    echo "[spawned long-running PID=$! at $(date -u +%H:%M:%S)]" >> /tmp/pf-spike.log
  ) </dev/null >/dev/null 2>&1 &
fi
```

Reinstall the spike if Q2 found that hot-reload doesn't work. Otherwise the edit is already live.

- [ ] **Step 2: Clear log, run session, exit immediately**

```sh
rm -f /tmp/pf-spike.log
cd /tmp/pf-spike-target
claude  # exit immediately after session start (Ctrl-C or /quit)
```

Note the time you exit.

- [ ] **Step 3: Wait 30 seconds, then check process is still alive**

```sh
sleep 30
ps aux | grep -E "sleep 120" | grep -v grep
```

Expected: one or more `sleep 120` processes still running (parent PID 1 if setsid worked).

- [ ] **Step 4: Wait the full 120s, then check the log for the survival message**

```sh
sleep 100
grep "long-process" /tmp/pf-spike.log
```

Expected: a line `[long-process] survived until HH:MM:SS` appears. If yes, long-running processes from hooks survive session exit — Frame server is viable.

If no: Claude Code is killing the process. Investigate whether `nohup`, `disown`, or some other mechanism preserves it. Try alternatives:

```sh
# Variant A: nohup
nohup bash -c '...' >/dev/null 2>&1 &

# Variant B: systemd-run --user (if available on macOS via launchd alternative)
launchctl submit -l pf-spike-q4 -- bash -c 'sleep 120; ...'
```

Record which (if any) variant survives.

- [ ] **Step 5: Cleanup any survivor processes**

```sh
pkill -f "sleep 120" || true
pkill -f "pf-spike-q4" || true
```

Revert the probe.sh changes (or leave; cleanup happens in Task 8).

- [ ] **Step 6: Record findings for Q4**

```
Q4: Long-running processes from hooks
- Plain `setsid ... &` survives: yes / no
- Survival message appeared in log: yes / no
- Working alternative (if needed): <command pattern>
- Implication for `pf frame start` launched from SessionStart:
  - If yes: Frame can be auto-started by plugin SessionStart hook
  - If no: Frame must be started manually by user via `pf frame start`
    (or we move to a launchctl/systemd model)
```

---

## Task 7: Write Spike Results Document

**Files:**
- Create: `/Users/slabgorb/Projects/orc-penny/docs/superpowers/spikes/2026-05-21-plugin-spike-results.md`

- [ ] **Step 1: Ensure spikes dir exists**

```sh
mkdir -p /Users/slabgorb/Projects/orc-penny/docs/superpowers/spikes
```

- [ ] **Step 2: Write the results document**

Create `/Users/slabgorb/Projects/orc-penny/docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` with this exact template, filling in the bracketed sections from your scratch notes in Tasks 3–6:

```markdown
# Pennyfarthing-as-Plugin Spike Results

**Date:** 2026-05-21
**Spec under test:** `docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md`
**Claude Code version:** [from Task 1 step 4]
**uv version:** [from Task 1 step 1]
**Plugin install path:** [from Task 3 step 2]

## Q1: `${CLAUDE_PLUGIN_ROOT}` semantics

- Value observed: [path]
- Stable across hook firings: [yes/no]
- cwd inside hook: [value]
- uv run works from inside hook: [yes/no]
- Runtime process sees CLAUDE_PLUGIN_ROOT in env: [yes/no]
- Anything else worth noting: [text]

**Spec impact:** [none / list amendments to §5.1 / etc.]

## Q2: `--from-source` hot-reload

- Install command used: [exact command]
- Edit picked up without reinstall: [yes/no]
- Update command that works: [command or "none — uninstall+reinstall required"]
- Uninstall+reinstall time: [seconds]
- Install path stable across reinstalls: [yes/no]

**Spec impact on D1 (orchestrator dogfooding, §8.2):** [text]

## Q3: Hook ordering vs user settings.json

- Both fired: [yes/no]
- Order: [user-first | plugin-first | indeterminate]
- CLAUDE_PLUGIN_ROOT visible to user hook: [yes/no]

**Spec impact:** [text]

## Q4: Long-running processes from hooks

- `setsid ... &` survives: [yes/no]
- Survival message appeared in log: [yes/no]
- Working alternative (if needed): [command pattern or "none required"]

**Spec impact on `pf frame start` (§9):** [text — either "Frame can be auto-started from SessionStart hook" or "Frame must remain a manual invocation"]

## Plan-of-Plans impact

Of plans 2–5 (in `docs/superpowers/plans/`), which need adjustment based on these findings?

- Plan 2 (scaffold + paths refactor): [text or "no change"]
- Plan 3 (content migration + prefix drop): [text or "no change"]
- Plan 4 (hooks rewrite): [text or "no change"]
- Plan 5 (migrate-from-legacy + cutover): [text or "no change"]

## Spec amendments required

[List exact section numbers and the text changes needed. Apply them as a follow-up commit to the spec file before Plan 2 is written.]

If none: "No spec changes required."
```

- [ ] **Step 3: Verify all four Qs are filled in (no "[text]" placeholders left)**

Run: `grep -n '\[' /Users/slabgorb/Projects/orc-penny/docs/superpowers/spikes/2026-05-21-plugin-spike-results.md`

Expected: no unfilled brackets remain. If any do, go back and fill them.

---

## Task 8: Apply Spec Amendments (if any)

**Files:**
- Modify: `/Users/slabgorb/Projects/orc-penny/docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md` (only if spike found design-impacting issues)

- [ ] **Step 1: Read the "Spec amendments required" section of the results doc**

Open `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md`. If it says "No spec changes required", skip to Task 9.

- [ ] **Step 2: Apply each amendment**

For each item, use the Edit tool with the exact section reference. Common cases and how to handle them:

- **If Q1 found `${CLAUDE_PLUGIN_ROOT}` doesn't auto-expand in `hooks.json`** → update spec §5.1 invocation examples to use whatever expansion form actually works.
- **If Q2 found hot-reload doesn't work** → update spec §8.2 to document the reinstall step in the dogfooding loop, and note in §10 risks that D1's "edits live in next session" needs an explicit `claude plugin install --reinstall` step.
- **If Q3 found user-settings hooks always fire before plugin hooks** → add a note in §6.1 that user settings can act as a pre-hook layer.
- **If Q4 found long-running processes are killed** → update spec §9 to say `pf frame start` must be manual, not hook-spawned; update §11 Gate 2 testing accordingly.

- [ ] **Step 3: Commit spec amendments**

```sh
cd /Users/slabgorb/Projects/orc-penny
git add docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md
git commit -m "docs(spec): amend plugin spec based on Q[N] spike findings"
```

Skip the commit if no amendments were needed.

---

## Task 9: Commit Spike Results

**Files:** stage the new spike-results doc.

- [ ] **Step 1: Stage and commit**

```sh
cd /Users/slabgorb/Projects/orc-penny
git add docs/superpowers/spikes/2026-05-21-plugin-spike-results.md
git commit -m "docs(spike): record plugin assumption probe results"
```

- [ ] **Step 2: Verify the doc is in git**

```sh
git log --oneline -3
git show --stat HEAD
```

Expected: most recent commit lists the spike-results file.

---

## Task 10: Cleanup Spike Plugin

**Files:** none (destructive operations only)

- [ ] **Step 1: Uninstall the spike plugin**

```sh
claude plugin uninstall pf-spike
```

Verify:

```sh
cat ~/.claude/plugins/installed_plugins.json | grep pf-spike
```

Expected: no entries.

If you used `claude plugin marketplace add ~/Projects/pf-spike`, also remove the marketplace:

```sh
claude plugin marketplace remove pf-spike  # exact subcommand may vary
```

- [ ] **Step 2: Archive or delete the spike repo**

Choose one:

```sh
# Option A: archive (keep as reference)
mv ~/Projects/pf-spike ~/Projects/_archive-pf-spike

# Option B: delete
rm -rf ~/Projects/pf-spike
```

- [ ] **Step 3: Cleanup probe log and target repo**

```sh
rm -f /tmp/pf-spike.log
rm -rf /tmp/pf-spike-target
```

- [ ] **Step 4: Cleanup any survivor processes from Q4 testing**

```sh
pkill -f "sleep 120" || true
pkill -f "pf-spike" || true
```

---

## Task 11: Hand Off to Plan 2

**Files:** none

- [ ] **Step 1: Verify the spike results doc is complete and committed**

```sh
cd /Users/slabgorb/Projects/orc-penny
git log --oneline | grep -E "(spike|plugin)" | head -5
```

Expected: at least one commit referencing the spike results, and possibly one referencing spec amendments.

- [ ] **Step 2: Surface the findings**

Open `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` and summarize in 3-5 bullet points: what the spike learned, what the spec amendments were, and what changes are needed in Plan 2.

- [ ] **Step 3: Trigger Plan 2 authoring**

Invoke the writing-plans skill again with this context:

```
Generate Plan 2 (Plugin scaffold + pf.paths chokepoint refactor) for the
pennyfarthing-as-plugin migration. The spec is at
docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md.
Spike results are at
docs/superpowers/spikes/2026-05-21-plugin-spike-results.md
and any spec amendments have already been applied.

Plan 2 scope:
- Add .claude-plugin/plugin.json and marketplace.json to the
  pennyfarthing/ repo
- Create runtime/pyproject.toml and runtime/uv.lock
- Move pennyfarthing-dist/src/pf/ → runtime/src/pf/ (preserve git history
  with git mv)
- Create runtime/src/pf/paths.py with origin-slug normalization and
  project-hash computation, TDD'd
- Refactor every existing call site that hardcodes .pennyfarthing/ to
  route through pf.paths instead
- Existing test suite (pennyfarthing/tests/python/) must still pass
- This plan does NOT yet drop the pf- prefix, does NOT yet move agents/
  commands/skills (those are Plan 3), and does NOT yet rewrite hooks
  (that's Plan 4). It establishes the foundation only.
```

---

## Acceptance Criteria

This plan is complete when ALL of the following are true:

1. `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` exists in `orc-penny`, has no unfilled bracket placeholders, and is committed.
2. Each of Q1, Q2, Q3, Q4 has a clear yes/no/value answer with empirical evidence (log excerpts may be appended as appendix if useful).
3. Any required spec amendments have been applied to `docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md` and committed.
4. `~/Projects/pf-spike/` is archived or deleted; spike plugin is uninstalled; `/tmp/pf-spike.log` and `/tmp/pf-spike-target/` are removed.
5. No leftover `sleep 120` or `pf-spike` background processes are running.
6. Plan 2 has been requested (Task 11 step 3) — but Plan 2 does not need to be written yet; this plan ends at the handoff.

---

## Notes for the Executor

- **This is investigative work, not feature delivery.** The "tests" in this plan are observations (`cat /tmp/pf-spike.log`, `ps aux`), not pytest assertions. That's intentional — the spike's purpose is empirical knowledge, not code.
- **If a probe contradicts the spec assumptions**, do not silently work around it. Document the contradiction in the results doc and apply the spec amendment in Task 8. Subsequent plans depend on the spec being accurate.
- **Do not generalize from a single run.** If a probe seems flaky, run it twice. Log everything.
- **Do not touch the `pennyfarthing/` repo's source code in this plan.** Only `orc-penny/docs/` should change in the production repos.
- **If `claude plugin install` syntax or behavior differs from what's documented here**, that's a finding — record the actual incantation in the results doc. The plan was written from inference; the executor's job is to ground it in reality.
