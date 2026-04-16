# Superpowers Integration — Stage 1 Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the brainstorming forwarder command + superpowers dependency declaration as a vertical slice proving the Track 1 integration pattern.

**Architecture:** `/pf-brainstorming` becomes a three-line forwarder that invokes `superpowers:brainstorming`. `pf doctor` gains a new check that verifies the superpowers plugin is installed. `/pf-setup` project-setup workflow gains an install step. Framework `CLAUDE.md` declares superpowers as a companion plugin.

**Tech Stack:** Python 3.14, pytest, click (CLI), existing pennyfarthing doctor check framework.

**Spec:** `docs/superpowers/specs/2026-04-16-superpowers-integration-design.md`

**Repo:** All changes land in `pennyfarthing/` (the inlined framework repo). That repo targets `develop` per `repos.yaml`. The orchestrator repo (this repo, `.`) stores the spec and plan docs only.

**Precondition:** The engineer must have the superpowers plugin installed in their Claude Code instance (`/plugin install superpowers@claude-plugins-official`) so the forwarder command can actually execute during smoke tests. The plugin cache path is `~/.claude/plugins/cache/claude-plugins-official/superpowers/<version>/`.

---

## File Structure

Files created or modified in this plan:

| Path | Repo | Responsibility |
|------|------|----------------|
| `pennyfarthing-dist/commands/pf-brainstorming.md` | pennyfarthing | Replace BMAD-style content with three-line forwarder |
| `pennyfarthing-dist/src/pf/doctor/checks.py` | pennyfarthing | Add `check_superpowers_plugin` function |
| `pennyfarthing-dist/src/pf/doctor/core.py` | pennyfarthing | Register new check in `_CHECK_FNS` |
| `pennyfarthing-dist/src/pf/tests/test_superpowers_doctor.py` | pennyfarthing | Unit tests for the new doctor check |
| `pennyfarthing-dist/workflows/project-setup/steps/step-10-superpowers.md` | pennyfarthing | New wizard step telling the user to install superpowers |
| `pennyfarthing-dist/workflows/project-setup/workflow.yaml` | pennyfarthing | Register new step in step order |
| `pennyfarthing/CLAUDE.md` | pennyfarthing | Declare superpowers as companion dependency |

Each file has one clear responsibility. The doctor check lives alongside existing install checks, the forwarder lives alongside existing command files, and the setup step slots into the numbered wizard sequence.

---

## Task 1: Doctor check — companion plugin presence

**Files:**
- Create: `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_superpowers_doctor.py`
- Modify: `pennyfarthing/pennyfarthing-dist/src/pf/doctor/checks.py` (add function + entry to `CHECKS` if present)
- Modify: `pennyfarthing/pennyfarthing-dist/src/pf/doctor/core.py` (register in `_CHECK_FNS`)

### Step 1: Write the failing tests

- [ ] Create `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_superpowers_doctor.py`:

```python
"""Tests for the superpowers companion plugin doctor check."""
from __future__ import annotations

from pathlib import Path

from pf.doctor.checks import check_superpowers_plugin


def test_check_superpowers_plugin_pass_when_plugin_installed(tmp_path, monkeypatch):
    """Check passes when superpowers plugin cache dir exists under HOME."""
    plugin_dir = (
        tmp_path
        / ".claude"
        / "plugins"
        / "cache"
        / "claude-plugins-official"
        / "superpowers"
    )
    plugin_dir.mkdir(parents=True)
    monkeypatch.setenv("HOME", str(tmp_path))

    result = check_superpowers_plugin(tmp_path)

    assert result.status == "pass"
    assert "superpowers" in result.detail.lower()


def test_check_superpowers_plugin_fail_when_missing(tmp_path, monkeypatch):
    """Check fails with remediation guidance when plugin dir absent."""
    monkeypatch.setenv("HOME", str(tmp_path))

    result = check_superpowers_plugin(tmp_path)

    assert result.status == "fail"
    assert "install" in result.detail.lower()
    assert "superpowers" in result.detail.lower()


def test_check_superpowers_plugin_has_stable_name():
    """Check name is stable for CLI output and JSON consumers."""
    import inspect
    from pf.doctor import checks

    # Function must be named check_superpowers_plugin; result.name is "superpowers_plugin"
    assert inspect.isfunction(checks.check_superpowers_plugin)
```

### Step 2: Run tests to verify they fail

- [ ] Run from `pennyfarthing/` directory:

```bash
cd pennyfarthing && python3 -m pytest pennyfarthing-dist/src/pf/tests/test_superpowers_doctor.py -v
```

Expected: `ImportError: cannot import name 'check_superpowers_plugin' from 'pf.doctor.checks'` or similar.

### Step 3: Implement the check function

- [ ] Open `pennyfarthing/pennyfarthing-dist/src/pf/doctor/checks.py`. At the bottom of the file, add:

```python
def check_superpowers_plugin(root: Path) -> CheckResult:
    """Check that the superpowers Claude Code plugin is installed.

    Pennyfarthing declares superpowers@claude-plugins-official as a required
    companion plugin. The plugin is installed via Claude Code's /plugin system
    and cached under ~/.claude/plugins/cache/claude-plugins-official/superpowers/.
    """
    import os

    home = Path(os.environ.get("HOME", ""))
    if not home:
        return CheckResult(
            name="superpowers_plugin",
            status="fail",
            detail="HOME environment variable not set; cannot locate plugin cache.",
        )

    plugin_root = home / ".claude" / "plugins" / "cache" / "claude-plugins-official" / "superpowers"
    if plugin_root.is_dir():
        return CheckResult(
            name="superpowers_plugin",
            status="pass",
            detail=f"superpowers plugin found at {plugin_root}",
        )

    return CheckResult(
        name="superpowers_plugin",
        status="fail",
        detail=(
            "superpowers plugin not installed. "
            "Run: /plugin install superpowers@claude-plugins-official"
        ),
    )
```

### Step 4: Register the check in doctor core

- [ ] Open `pennyfarthing/pennyfarthing-dist/src/pf/doctor/core.py`. In the import block at the top, add `check_superpowers_plugin` to the import from `pf.doctor.checks`:

```python
from pf.doctor.checks import (
    CHECKS,
    check_agents,
    check_commands,
    check_config_file,
    check_content_dirs,
    check_git_hooks,
    check_node_packages,
    check_pennyfarthing_dir,
    check_python_install,
    check_settings_hooks,
    check_skills,
    check_superpowers_plugin,
    check_theme,
)
```

- [ ] Add the entry to `_CHECK_FNS` (keep alphabetical ordering where the existing dict does):

```python
_CHECK_FNS = {
    "python_install": check_python_install,
    "pennyfarthing_dir": check_pennyfarthing_dir,
    "config_file": check_config_file,
    "settings_hooks": check_settings_hooks,
    "content_dirs": check_content_dirs,
    "agents": check_agents,
    "commands": check_commands,
    "skills": check_skills,
    "superpowers_plugin": check_superpowers_plugin,
    "node_packages": check_node_packages,
    "git_hooks": check_git_hooks,
    "theme": check_theme,
}
```

- [ ] If `doctor/checks.py` defines a `CHECKS` constant (list of check names), add `"superpowers_plugin"` to it. Grep to confirm:

```bash
grep -n "^CHECKS" pennyfarthing/pennyfarthing-dist/src/pf/doctor/checks.py
```

If `CHECKS` exists, append `"superpowers_plugin"` to the list in the same alphabetical-ish ordering as `_CHECK_FNS`.

### Step 5: Run tests to verify they pass

- [ ] Re-run the test file:

```bash
cd pennyfarthing && python3 -m pytest pennyfarthing-dist/src/pf/tests/test_superpowers_doctor.py -v
```

Expected: all three tests pass.

### Step 6: Smoke test the CLI integration

- [ ] Run `pf doctor` and confirm the new check appears in output:

```bash
pf doctor
```

Expected: a line reading `[OK] superpowers_plugin: superpowers plugin found at /Users/.../superpowers` (assuming plugin is installed per the precondition).

- [ ] Optionally test the fail path by temporarily pointing HOME at a scratch dir:

```bash
HOME=/tmp/fakehome pf doctor
```

Expected: `[FAIL] superpowers_plugin: superpowers plugin not installed. Run: /plugin install superpowers@claude-plugins-official`

### Step 7: Commit

- [ ] Stage and commit in the pennyfarthing repo:

```bash
cd pennyfarthing
git add pennyfarthing-dist/src/pf/doctor/checks.py \
        pennyfarthing-dist/src/pf/doctor/core.py \
        pennyfarthing-dist/src/pf/tests/test_superpowers_doctor.py
git commit -m "feat(doctor): check superpowers companion plugin presence

Pennyfarthing now declares superpowers@claude-plugins-official as a
required companion. The doctor check looks for the plugin cache dir at
~/.claude/plugins/cache/claude-plugins-official/superpowers/ and emits
install guidance when absent.

Refs: docs/superpowers/specs/2026-04-16-superpowers-integration-design.md"
```

---

## Task 2: Brainstorming forwarder command

**Files:**
- Modify (full replacement): `pennyfarthing/pennyfarthing-dist/commands/pf-brainstorming.md`

### Step 1: Back up and read current content

- [ ] Read the existing file so you know what is being replaced:

```bash
cat pennyfarthing/pennyfarthing-dist/commands/pf-brainstorming.md
```

The current content is a BMAD-derived structured-brainstorming session (Phase 1 Problem Definition, Phase 2 Divergent Thinking, etc.). Superpowers' own brainstorming skill covers this more thoroughly and feeds into `superpowers:writing-plans`, which is why we replace rather than merge.

### Step 2: Write the forwarder

- [ ] Replace the entire file content with:

```markdown
---
description: Brainstorm ideas into designs (forwarder to superpowers:brainstorming)
---

# /pf-brainstorming

Invoke the `superpowers:brainstorming` skill via the Skill tool. No preamble.

This command is a pennyfarthing-namespaced alias for `superpowers:brainstorming`; all logic lives in the superpowers plugin. See the spec: `docs/superpowers/specs/2026-04-16-superpowers-integration-design.md`.
```

### Step 3: Smoke test the command

- [ ] In a Claude Code session where superpowers is installed, type `/pf-brainstorming`. Verify that Claude invokes `superpowers:brainstorming` and begins the structured brainstorming flow.

Expected: Claude announces it is using the brainstorming skill, loads the spec/design flow, and starts asking clarifying questions one at a time.

### Step 4: Commit

- [ ] Stage and commit:

```bash
cd pennyfarthing
git add pennyfarthing-dist/commands/pf-brainstorming.md
git commit -m "feat(commands): convert pf-brainstorming to superpowers forwarder

The prior BMAD-derived structured-brainstorming command is fully
superseded by superpowers:brainstorming, which covers the same flow and
transitions into superpowers:writing-plans. /pf-brainstorming is now a
three-line forwarder preserving the /pf-* namespace.

Refs: docs/superpowers/specs/2026-04-16-superpowers-integration-design.md"
```

---

## Task 3: Setup wizard — install superpowers step

**Files:**
- Create: `pennyfarthing/pennyfarthing-dist/workflows/project-setup/steps/step-10-superpowers.md`
- Modify: `pennyfarthing/pennyfarthing-dist/workflows/project-setup/steps/step-09-jira.md` (redirect `NEXT STEP` pointer)

The `workflow.yaml` does **not** need editing — it auto-discovers steps via `steps.pattern: step-*.md`, so dropping the new file in is enough. Step ordering is by filename. Step 09 currently ends with a `NEXT STEP` reference to a non-existent `step-10-gui.md`; redirect it to our new step.

### Step 1: Create the new step file

- [ ] Create `pennyfarthing/pennyfarthing-dist/workflows/project-setup/steps/step-10-superpowers.md` using the same structure as `step-09-jira.md` (no frontmatter; XML tags for `<purpose>`, `<instructions>`, `<output>`; `##`-heading sections; `## SUCCESS CRITERIA` and `## NEXT STEP` at the end):

```markdown
# Step 10: Install Superpowers Companion Plugin

<purpose>
Pennyfarthing declares `superpowers@claude-plugins-official` as a required companion Claude Code plugin. It ships generic software-craft skills — brainstorming, writing-plans, verification-before-completion, systematic-debugging, test-driven-development — that pennyfarthing forwarder commands and enforcement gates reference. Without it, `/pf-brainstorming` cannot forward and several Track 2 gates cannot verify their artifacts.
</purpose>

<instructions>
1. Tell the user to install the superpowers plugin from Claude Code's plugin registry.
2. Wait for confirmation the install succeeded.
3. Run `pf doctor` and confirm the `superpowers_plugin` check reports OK.
4. If the check fails, ask the user to retry the install command and recheck.
</instructions>

<output>
- Superpowers plugin installed.
- `pf doctor` reports `[OK] superpowers_plugin: superpowers plugin found at ...`.
</output>

## INSTALL THE PLUGIN

```
📦 Superpowers Plugin Installation
═════════════════════════════════════

Pennyfarthing uses skills from the superpowers plugin for
brainstorming, plan writing, code review, TDD, and verification.

Install it from inside Claude Code (NOT the shell):

  /plugin install superpowers@claude-plugins-official

Once Claude confirms the install is complete, press Enter.
```

## VERIFICATION

```bash
pf doctor
```

Expected output includes:

```
[OK] superpowers_plugin: superpowers plugin found at /Users/<you>/.claude/plugins/cache/claude-plugins-official/superpowers/<version>
```

If you see `[FAIL] superpowers_plugin: ...`, ask the user to rerun the install command.

## CHANGING LATER

The plugin can be updated or removed via Claude Code's `/plugin` command at any time. Pennyfarthing will complain (via `pf doctor`) if it is missing.

## SUCCESS CRITERIA

- `superpowers@claude-plugins-official` plugin is installed in the user's Claude Code environment.
- `pf doctor` reports the `superpowers_plugin` check as `[OK]`.

## NEXT STEP

After confirming the plugin is installed, proceed to `step-11-complete.md` to finalize setup.
```

### Step 2: Redirect step-09's NEXT STEP pointer

- [ ] Open `pennyfarthing/pennyfarthing-dist/workflows/project-setup/steps/step-09-jira.md`. Its final section currently reads:

```
## NEXT STEP

After Jira configuration, proceed to `step-10-gui.md` to optionally configure the Frame GUI.
```

Replace with:

```
## NEXT STEP

After Jira configuration, proceed to `step-10-superpowers.md` to install the required superpowers companion plugin.
```

### Step 3: Smoke test step loads cleanly

- [ ] Validate the workflow still resolves step order:

```bash
pf workflow show project-setup
```

Expected: command exits cleanly and the step list includes `step-10-superpowers` between `step-09-jira` and `step-11-complete`.

### Step 4: Commit

- [ ] Stage and commit:

```bash
cd pennyfarthing
git add pennyfarthing-dist/workflows/project-setup/steps/step-10-superpowers.md \
        pennyfarthing-dist/workflows/project-setup/steps/step-09-jira.md
git commit -m "feat(setup): add superpowers install step to project-setup wizard

New step-10 prompts the user to install
superpowers@claude-plugins-official and verifies via pf doctor. Step 09
NEXT STEP pointer redirected from the non-existent step-10-gui.md to
the new step-10-superpowers.md.

Refs: docs/superpowers/specs/2026-04-16-superpowers-integration-design.md"
```

---

## Task 4: Framework CLAUDE.md — companion dependency declaration

**Files:**
- Modify: `pennyfarthing/CLAUDE.md`

### Step 1: Read the existing critical section

- [ ] Open `pennyfarthing/CLAUDE.md` and locate the `<critical>` block that currently contains the Implementation Rules list. The superpowers declaration belongs adjacent to that (not inside it — it's user-facing installation info, not a framework rule).

### Step 2: Add the companion dependency section

- [ ] Insert a new `<critical>` block (or a plain section near the top, matching the style of the existing `<critical>` blocks) reading:

```markdown
<critical>
## Required Companion Plugin

Pennyfarthing requires the `superpowers@claude-plugins-official` Claude Code plugin. Install it once per Claude Code environment:

```
/plugin install superpowers@claude-plugins-official
```

Superpowers provides the generic software-craft skills (brainstorming, writing-plans, verification-before-completion, test-driven-development, systematic-debugging, etc.) that pennyfarthing forwarder commands and gates reference. Running `pf doctor` will report `superpowers_plugin` as FAIL if it is missing.

Design: `docs/superpowers/specs/2026-04-16-superpowers-integration-design.md`.
</critical>
```

### Step 3: Commit

- [ ] Stage and commit:

```bash
cd pennyfarthing
git add CLAUDE.md
git commit -m "docs: declare superpowers as required companion plugin

Framework CLAUDE.md now declares superpowers@claude-plugins-official as
a required plugin alongside the existing implementation rules.

Refs: docs/superpowers/specs/2026-04-16-superpowers-integration-design.md"
```

---

## Task 5: Integration smoke — full pilot walkthrough

**Files:** none. This task validates the slice end-to-end.

### Step 1: Doctor reports green

- [ ] Run:

```bash
pf doctor
```

Expected: all checks pass including the new `superpowers_plugin` line.

### Step 2: /pf-brainstorming forwards correctly

- [ ] In a Claude Code session, type `/pf-brainstorming`. Confirm that Claude immediately invokes `superpowers:brainstorming` and begins the structured flow (clarifying questions, design presentation, etc.).

### Step 3: Setup wizard step renders

- [ ] Walk through the new setup step:

```bash
pf workflow show project-setup
```

Verify `step-10-superpowers` appears in the printed step list in the right position.

### Step 4: Framework CLAUDE.md is picked up

- [ ] Confirm the declaration is discoverable:

```bash
grep -A2 "superpowers@claude-plugins-official" pennyfarthing/CLAUDE.md
```

Expected: the new block is present.

### Step 5: Final commit sweep (if anything missed)

- [ ] Run `git status` in both repos:

```bash
git -C pennyfarthing status
git status
```

Expected: both clean. Any stray changes should be reviewed and committed or discarded.

### Step 6: Push

- [ ] The pennyfarthing repo targets `develop` per repos.yaml. Push when ready:

```bash
cd pennyfarthing && git push origin develop
```

(The orchestrator spec/plan commits stay local until their story completes.)

---

## Out of Scope for This Plan

- Remaining Track 1 forwarders (`/pf-write-plan`, `/pf-execute-plan`, `/pf-worktree`, `/pf-parallel`, `/pf-write-skill`, `/pf-systematic-debugging`) and the `delegates_to:` field on the skill registry — Stage 2, separate plan.
- Deleting `pennyfarthing-dist/skills/pf-systematic-debugging/` — Stage 2.
- All Track 2 atomic gate files — Stage 3+, separate plans.
- Agent `<skills>` block refresh — Stage 5, separate plan.

---

## Notes for the Engineer

- **Two repos.** The spec and plan live in the orchestrator repo (this directory, `.`, targets `main`). Implementation commits land in `pennyfarthing/` which targets `develop`. Don't cross the streams.
- **pre-commit hooks may sign commits.** Don't pass `--no-verify` or `--no-gpg-sign` unless a hook fails and you've diagnosed why. If a hook fails, stop and fix the root cause.
- **Forwarder simplicity is the point.** Do not add context injection, session wiring, or post-processing to `/pf-brainstorming`. If you feel the urge to enhance it, that's Track 2 (gates) territory — not this plan.
- **The test file does not carry a story ID yet.** Once SM creates the sprint story for this pilot, the file can be renamed `test_{story-id}_superpowers_doctor.py` to match pennyfarthing's convention. Renaming is safe — just `git mv` and re-commit.
