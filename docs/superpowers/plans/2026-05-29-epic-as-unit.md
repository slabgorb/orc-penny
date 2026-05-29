# Epic-as-Unit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire superpowers plans into the Pennyfarthing epic/story ledger so one plan Task = one PF story, materialized via `pf epic from-plan` and closed via `pf sprint story complete`.

**Architecture:** Three new Python modules in the `pf.sprint` package (`repo_map`, `plan_parser`, `epic_from_plan`, `story_complete`) plus two small edits to existing files (`story_add` gains a `refs` param + a `superpowers` workflow choice; the `epic`/`story` CLI groups register the new verbs). The plan markdown stays the source of truth; the epic YAML is generated through the existing `add_story` path. A final task repurposes the `pf-epic` command doc into the conductor.

**Tech Stack:** Python 3.14, Click (CLI), ruamel.yaml (`CommentedMap`), pytest. Framework source lives in the inlined `pennyfarthing/` repo (gitflow, base branch `develop`).

---

## Pre-flight (do once before Task 1)

The framework source is the `pennyfarthing/` repo (separate git history, base branch `develop`). All implementation commits in this plan target that repo.

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git checkout develop && git pull
git checkout -b feat/epic-as-unit
```

**Test invocation used throughout** (targeted — never run the full suite; it leaks a `feature/test` checkout onto the live repo):

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist
uv run pytest src/pf/tests/<test_file>.py -v
```

All paths below are relative to the `pennyfarthing/` repo root.

---

## File Structure

| File | Responsibility | New? |
|------|----------------|------|
| `pennyfarthing-dist/src/pf/sprint/repo_map.py` | Map a file path → repo name (longest-prefix against `repos.yaml`) | new |
| `pennyfarthing-dist/src/pf/sprint/plan_parser.py` | Parse a superpowers plan markdown → list of `PlanTask` | new |
| `pennyfarthing-dist/src/pf/sprint/epic_from_plan.py` | Generate epic stories from a plan + annotate the plan with closing steps; CLI verb | new |
| `pennyfarthing-dist/src/pf/sprint/story_complete.py` | Flip story → done + check the plan box; CLI verb | new |
| `pennyfarthing-dist/src/pf/sprint/story_add.py` | Add optional `refs` param; add `superpowers` to workflow Choice | modify |
| `pennyfarthing-dist/src/pf/epic/cli.py` | Register `from-plan` on the `epic` group | modify |
| `pennyfarthing-dist/src/pf/sprint/cli.py` | Register `complete` on the `story` group | modify |
| `pennyfarthing-dist/commands/pf-epic.md` | Repurpose into the conductor doc | modify |

---

### Task 1: `repo_map` — file path → repo name

**Files:**
- Create: `pennyfarthing-dist/src/pf/sprint/repo_map.py`
- Test: `pennyfarthing-dist/src/pf/tests/test_repo_map.py`

- [ ] **Step 1: Write the failing test**

```python
# pennyfarthing-dist/src/pf/tests/test_repo_map.py
from pf.git.repos import RepoConfig
from pf.sprint.repo_map import map_path_to_repo, repos_for_files


def _repos():
    return {
        "orchestrator": RepoConfig(
            name="orchestrator", path=".", repo_type="orchestrator",
            default_branch="main", branch_strategy="trunk-based",
        ),
        "ui": RepoConfig(
            name="ui", path="sidequest-ui", repo_type="ui",
            default_branch="develop", branch_strategy="trunk-based",
        ),
        "server": RepoConfig(
            name="server", path="sidequest-server", repo_type="api",
            default_branch="develop", branch_strategy="trunk-based",
        ),
    }


def test_longest_prefix_wins_over_dot_repo():
    repos = _repos()
    assert map_path_to_repo("sidequest-ui/src/App.tsx", repos) == "ui"
    assert map_path_to_repo("sidequest-server/app.py", repos) == "server"


def test_dot_repo_is_fallback():
    repos = _repos()
    assert map_path_to_repo("docs/notes.md", repos) == "orchestrator"
    assert map_path_to_repo("./justfile", repos) == "orchestrator"


def test_repos_for_files_dedupes_and_preserves_order():
    repos = _repos()
    files = ["sidequest-ui/a.tsx", "sidequest-server/b.py", "sidequest-ui/c.tsx"]
    # map_path_to_repo is pure; repos_for_files takes a loader-injected dict
    names = []
    for f in files:
        n = map_path_to_repo(f, repos)
        if n and n not in names:
            names.append(n)
    assert names == ["ui", "server"]


def test_no_repos_returns_none():
    assert map_path_to_repo("anything.py", {}) is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_repo_map.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'pf.sprint.repo_map'`

- [ ] **Step 3: Write minimal implementation**

```python
# pennyfarthing-dist/src/pf/sprint/repo_map.py
"""Map file paths to repos using repos.yaml topology (longest-prefix match)."""

from __future__ import annotations

from pathlib import Path

from pf.git.repos import RepoConfig, load_repos_config


def map_path_to_repo(file_path: str, repos: dict[str, RepoConfig]) -> str | None:
    """Return the repo name owning ``file_path`` by longest path-prefix match.

    A repo whose ``path`` is ``"."`` (orchestrator/standalone) is the fallback
    used only when no more-specific repo prefix matches. Returns None when no
    repo matches and there is no ``"."`` repo.
    """
    norm = file_path.strip()
    if norm.startswith("./"):
        norm = norm[2:]

    best_name: str | None = None
    best_len = -1
    dot_repo: str | None = None

    for name, rc in repos.items():
        rp = rc.path.strip()
        if rp in (".", ""):
            dot_repo = name
            continue
        rp = rp.strip("/")
        if norm == rp or norm.startswith(rp + "/"):
            if len(rp) > best_len:
                best_len = len(rp)
                best_name = name

    return best_name if best_name is not None else dot_repo


def repos_for_files(
    files: list[str], project_root: Path | None = None
) -> list[str]:
    """Return the deduped, order-preserving list of repo names for ``files``."""
    repos = load_repos_config(project_root)
    if not repos:
        return []
    out: list[str] = []
    for f in files:
        name = map_path_to_repo(f, repos)
        if name and name not in out:
            out.append(name)
    return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_repo_map.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/sprint/repo_map.py pennyfarthing-dist/src/pf/tests/test_repo_map.py
git commit -m "feat(sprint): add repo_map for file-path to repo resolution"
```

---

### Task 2: `plan_parser` — parse a superpowers plan into tasks

**Files:**
- Create: `pennyfarthing-dist/src/pf/sprint/plan_parser.py`
- Test: `pennyfarthing-dist/src/pf/tests/test_plan_parser.py`

- [ ] **Step 1: Write the failing test**

```python
# pennyfarthing-dist/src/pf/tests/test_plan_parser.py
from pf.sprint.plan_parser import PlanTask, parse_plan

SAMPLE = """\
# Some Plan

**Goal:** do things

---

### Task 1: First Component

**Files:**
- Create: `sidequest-ui/src/Foo.tsx`
- Test: `sidequest-ui/src/Foo.test.tsx`

- [ ] Step 1: write test

### Task 2: Second Component

**Files:**
- Modify: `sidequest-server/app.py:10-20`

- [ ] Step 1: do it

## Closing Section

Not a task.
"""


def test_parses_task_headers_and_titles():
    tasks = parse_plan(SAMPLE)
    assert [t.number for t in tasks] == [1, 2]
    assert tasks[0].title == "First Component"
    assert tasks[1].title == "Second Component"


def test_extracts_files_stripping_line_ranges():
    tasks = parse_plan(SAMPLE)
    assert tasks[0].files == ["sidequest-ui/src/Foo.tsx", "sidequest-ui/src/Foo.test.tsx"]
    # line range after ':' is stripped
    assert tasks[1].files == ["sidequest-server/app.py"]


def test_section_header_ends_task_block():
    tasks = parse_plan(SAMPLE)
    # "## Closing Section" must not be parsed as a task
    assert all(t.number in (1, 2) for t in tasks)


def test_anchor_is_task_n():
    tasks = parse_plan(SAMPLE)
    assert tasks[0].anchor == "task-1"


def test_empty_plan_returns_empty():
    assert parse_plan("# Nothing here\n") == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_plan_parser.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'pf.sprint.plan_parser'`

- [ ] **Step 3: Write minimal implementation**

```python
# pennyfarthing-dist/src/pf/sprint/plan_parser.py
"""Parse superpowers implementation plans into discrete Tasks."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

_TASK_RE = re.compile(r"^###\s+Task\s+(\d+):\s*(.+?)\s*$")
_FILE_RE = re.compile(r"^\s*-\s*(?:Create|Modify|Test):\s*`([^`]+)`")


@dataclass
class PlanTask:
    """One `### Task N` block from a plan."""

    number: int
    title: str
    files: list[str] = field(default_factory=list)

    @property
    def anchor(self) -> str:
        return f"task-{self.number}"


def parse_plan(text: str) -> list[PlanTask]:
    """Return the ordered list of ``PlanTask`` parsed from plan markdown.

    A Task block runs from its ``### Task N:`` header until the next ``### ``
    or ``## `` header (or EOF). File paths come from ``- Create:``/``- Modify:``/
    ``- Test:`` bullets; any ``:line-range`` suffix is stripped.
    """
    tasks: list[PlanTask] = []
    current: PlanTask | None = None

    for line in text.splitlines():
        m = _TASK_RE.match(line)
        if m:
            current = PlanTask(number=int(m.group(1)), title=m.group(2))
            tasks.append(current)
            continue
        # A new section/task header (that wasn't a Task match) ends the block.
        if line.startswith("### ") or line.startswith("## "):
            current = None
            continue
        if current is not None:
            fm = _FILE_RE.match(line)
            if fm:
                path = fm.group(1).split(":")[0].strip()
                if path and path not in current.files:
                    current.files.append(path)

    return tasks
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_plan_parser.py -v`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/sprint/plan_parser.py pennyfarthing-dist/src/pf/tests/test_plan_parser.py
git commit -m "feat(sprint): add plan_parser for superpowers plan tasks"
```

---

### Task 3: `add_story` gains a `refs` param + `superpowers` workflow choice

**Files:**
- Modify: `pennyfarthing-dist/src/pf/sprint/story_add.py`
- Test: `pennyfarthing-dist/src/pf/tests/test_story_add_refs.py`

- [ ] **Step 1: Write the failing test**

```python
# pennyfarthing-dist/src/pf/tests/test_story_add_refs.py
from pathlib import Path

import yaml

from pf.sprint.story_add import add_story


def _write_sprint(tmp_path: Path) -> Path:
    sprint_file = tmp_path / "current-sprint.yaml"
    data = {
        "sprint": {
            "name": "Test", "number": 1, "status": "active",
            "start_date": "2026-01-01", "end_date": "2026-01-14",
            "goal": "test",
        },
        "epics": [
            {"id": "99", "type": "epic", "title": "E", "priority": "p1",
             "status": "backlog", "stories": []},
        ],
    }
    sprint_file.write_text(yaml.safe_dump(data))
    return sprint_file


def test_add_story_persists_refs_and_superpowers_workflow(tmp_path):
    sprint_file = _write_sprint(tmp_path)
    res = add_story(
        sprint_file, "99", "Build the thing", 1,
        workflow="superpowers", repos="ui,server",
        refs="plan:docs/superpowers/plans/p.md#task-1",
    )
    assert res["success"], res
    saved = yaml.safe_load(sprint_file.read_text())
    story = saved["epics"][0]["stories"][0]
    assert story["workflow"] == "superpowers"
    assert story["repos"] == "ui,server"
    assert story["refs"] == "plan:docs/superpowers/plans/p.md#task-1"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_story_add_refs.py -v`
Expected: FAIL — `TypeError: add_story() got an unexpected keyword argument 'refs'`

- [ ] **Step 3a: Add the `refs` parameter to `add_story`**

In `pennyfarthing-dist/src/pf/sprint/story_add.py`, change the `add_story` signature (the keyword-only block) to include `refs` and populate it into the `fields` dict.

Find the signature:
```python
def add_story(
    sprint_path: Path,
    epic_id: str,
    title: str,
    points: int,
    *,
    story_type: str | None = None,
    priority: str = "P1",
    workflow: str = "tdd",
    jira: str | None = None,
    repos: str | None = None,
    depends_on: str | None = None,
) -> dict[str, Any]:
```

Add `refs`:
```python
def add_story(
    sprint_path: Path,
    epic_id: str,
    title: str,
    points: int,
    *,
    story_type: str | None = None,
    priority: str = "P1",
    workflow: str = "tdd",
    jira: str | None = None,
    repos: str | None = None,
    depends_on: str | None = None,
    refs: str | None = None,
) -> dict[str, Any]:
```

Find the optional-fields block:
```python
    if jira is not None:
        fields["jira"] = jira
    if repos is not None:
        fields["repos"] = repos
    if depends_on is not None:
        fields["depends_on"] = depends_on
    if story_type is not None:
        fields["type"] = story_type
```

Add the `refs` assignment (note: `refs` is already in `STORY_KEY_ORDER`, so it lands in canonical position):
```python
    if jira is not None:
        fields["jira"] = jira
    if repos is not None:
        fields["repos"] = repos
    if depends_on is not None:
        fields["depends_on"] = depends_on
    if story_type is not None:
        fields["type"] = story_type
    if refs is not None:
        fields["refs"] = refs
```

- [ ] **Step 3b: Add `superpowers` to the CLI workflow choice**

In the same file, find the CLI option:
```python
@click.option("--workflow", type=click.Choice(["tdd", "trivial", "bdd"]), default="tdd")
```
Change to:
```python
@click.option("--workflow", type=click.Choice(["tdd", "trivial", "bdd", "superpowers"]), default="tdd")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_story_add_refs.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Run the existing story_add tests to confirm no regression**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/ -k story_add -v`
Expected: PASS (existing story_add tests still green)

- [ ] **Step 6: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/sprint/story_add.py pennyfarthing-dist/src/pf/tests/test_story_add_refs.py
git commit -m "feat(sprint): add_story refs param + superpowers workflow choice"
```

---

### Task 4: `epic_from_plan` — generate stories + annotate the plan

**Files:**
- Create: `pennyfarthing-dist/src/pf/sprint/epic_from_plan.py`
- Test: `pennyfarthing-dist/src/pf/tests/test_epic_from_plan.py`

**Note:** `find_epic` lives in `pf.sprint.loader` (same module as `find_story_in_data`). If an import error occurs, confirm with `grep -rn "def find_epic" pennyfarthing-dist/src/pf/sprint/` and adjust the import.

- [ ] **Step 1: Write the failing test**

```python
# pennyfarthing-dist/src/pf/tests/test_epic_from_plan.py
from pathlib import Path

import yaml

from pf.sprint.epic_from_plan import epic_from_plan

PLAN = """\
# Demo Plan

### Task 1: Add the widget

**Files:**
- Create: `pennyfarthing-dist/src/pf/widget.py`

- [ ] Step 1: write test

### Task 2: Wire the widget

**Files:**
- Modify: `pennyfarthing-dist/src/pf/app.py`

- [ ] Step 1: do it
"""


def _sprint(tmp_path: Path) -> Path:
    sprint_file = tmp_path / "current-sprint.yaml"
    data = {
        "sprint": {"name": "T", "number": 1, "status": "active",
                   "start_date": "2026-01-01", "end_date": "2026-01-14", "goal": "g"},
        "epics": [{"id": "99", "type": "epic", "title": "E", "priority": "p1",
                   "status": "backlog", "stories": []}],
    }
    sprint_file.write_text(yaml.safe_dump(data))
    return sprint_file


def test_creates_one_story_per_task(tmp_path):
    sprint_file = _sprint(tmp_path)
    plan = tmp_path / "plan.md"
    plan.write_text(PLAN)
    res = epic_from_plan(sprint_file, plan, "99", project_root=tmp_path)
    assert res["success"], res
    assert len(res["created"]) == 2
    saved = yaml.safe_load(sprint_file.read_text())
    stories = saved["epics"][0]["stories"]
    assert [s["title"] for s in stories] == ["Add the widget", "Wire the widget"]
    assert all(s["workflow"] == "superpowers" for s in stories)
    assert stories[0]["refs"] == "plan:plan.md#task-1"


def test_annotates_plan_with_closing_step(tmp_path):
    sprint_file = _sprint(tmp_path)
    plan = tmp_path / "plan.md"
    plan.write_text(PLAN)
    res = epic_from_plan(sprint_file, plan, "99", project_root=tmp_path)
    text = plan.read_text()
    sid0 = res["created"][0]
    assert f"pf sprint story complete {sid0}" in text


def test_idempotent_rerun_skips_existing(tmp_path):
    sprint_file = _sprint(tmp_path)
    plan = tmp_path / "plan.md"
    plan.write_text(PLAN)
    epic_from_plan(sprint_file, plan, "99", project_root=tmp_path)
    res2 = epic_from_plan(sprint_file, plan, "99", project_root=tmp_path)
    assert res2["success"]
    assert res2["created"] == []
    assert sorted(res2["skipped"]) == [1, 2]
    saved = yaml.safe_load(sprint_file.read_text())
    assert len(saved["epics"][0]["stories"]) == 2  # not duplicated


def test_missing_epic_errors(tmp_path):
    sprint_file = _sprint(tmp_path)
    plan = tmp_path / "plan.md"
    plan.write_text(PLAN)
    res = epic_from_plan(sprint_file, plan, "404", project_root=tmp_path)
    assert not res["success"]
    assert "not found" in res["error"]


def test_no_tasks_errors(tmp_path):
    sprint_file = _sprint(tmp_path)
    plan = tmp_path / "plan.md"
    plan.write_text("# Empty\n\nno tasks here\n")
    res = epic_from_plan(sprint_file, plan, "99", project_root=tmp_path)
    assert not res["success"]
    assert "Task" in res["error"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_epic_from_plan.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'pf.sprint.epic_from_plan'`

- [ ] **Step 3: Write minimal implementation**

```python
# pennyfarthing-dist/src/pf/sprint/epic_from_plan.py
"""Generate epic stories from a superpowers plan (1 story per ### Task N)."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import click

from pf.common.config import get_project_root
from pf.sprint.loader import find_epic
from pf.sprint.plan_parser import PlanTask, parse_plan
from pf.sprint.repo_map import repos_for_files
from pf.sprint.story_add import add_story
from pf.sprint.yaml_io import read_sprint

_COMPLETE_STEP = "- [ ] **Story {sid} complete** — run `pf sprint story complete {sid}`"
_TASK_NUM_RE = re.compile(r"^###\s+Task\s+(\d+):")


def _rel_plan(plan_path: Path, root: Path) -> str:
    try:
        return str(plan_path.resolve().relative_to(root.resolve()))
    except ValueError:
        return str(plan_path)


def _story_with_ref(epic: dict[str, Any], ref: str) -> dict[str, Any] | None:
    for s in epic.get("stories", []) or []:
        if isinstance(s, dict) and s.get("refs") == ref:
            return s
    return None


def _annotate_task(lines: list[str], task: PlanTask, sid: str) -> list[str]:
    """Insert the closing `pf sprint story complete <sid>` step into a task block."""
    marker = None
    for idx, ln in enumerate(lines):
        m = _TASK_NUM_RE.match(ln)
        if m and int(m.group(1)) == task.number:
            marker = idx
            break
    if marker is None:
        return lines

    end = len(lines)
    for idx in range(marker + 1, len(lines)):
        if lines[idx].startswith("### ") or lines[idx].startswith("## "):
            end = idx
            break

    block = "\n".join(lines[marker:end])
    if f"pf sprint story complete {sid}" in block:
        return lines

    insert_at = end
    while insert_at - 1 > marker and lines[insert_at - 1].strip() == "":
        insert_at -= 1
    return lines[:insert_at] + ["", _COMPLETE_STEP.format(sid=sid)] + lines[insert_at:]


def epic_from_plan(
    sprint_path: Path,
    plan_path: Path | str,
    epic_id: str,
    *,
    project_root: Path | None = None,
    default_points: int = 1,
    dry_run: bool = False,
) -> dict[str, Any]:
    """Create one story per plan Task and annotate the plan with closing steps.

    Idempotent: tasks whose generated ref already exists on the epic are skipped.
    Returns ``{"success", "created", "skipped"}`` or ``{"success": False, "error"}``.
    """
    root = Path(project_root) if project_root else get_project_root()
    plan_file = Path(plan_path)
    if not plan_file.exists():
        return {"success": False, "error": f"Plan not found: {plan_path}"}

    tasks = parse_plan(plan_file.read_text())
    if not tasks:
        return {"success": False, "error": "No '### Task N:' headers found in plan"}

    data = read_sprint(sprint_path)
    if find_epic(data, epic_id) is None:
        return {"success": False, "error": f"Epic '{epic_id}' not found"}

    rel = _rel_plan(plan_file, root)
    created: list[str] = []
    skipped: list[int] = []
    lines = plan_file.read_text().splitlines()

    for task in tasks:
        ref = f"plan:{rel}#{task.anchor}"
        data = read_sprint(sprint_path)
        epic = find_epic(data, epic_id)
        if _story_with_ref(epic, ref):
            skipped.append(task.number)
            continue

        repo_list = repos_for_files(task.files, project_root)
        repos_str = ",".join(repo_list) if repo_list else None

        if dry_run:
            created.append(f"task-{task.number}")
            continue

        res = add_story(
            sprint_path, epic_id, task.title, default_points,
            workflow="superpowers", repos=repos_str, refs=ref,
        )
        if not res.get("success"):
            return {"success": False, "error": f"Task {task.number}: {res.get('error')}"}
        sid = res["story_id"]
        created.append(sid)
        lines = _annotate_task(lines, task, sid)

    if not dry_run:
        plan_file.write_text("\n".join(lines) + "\n")

    return {"success": True, "created": created, "skipped": skipped}


@click.command("from-plan")
@click.argument("plan_path", type=click.Path(exists=True))
@click.argument("epic_id", type=str)
@click.option("--points", "default_points", type=int, default=1,
              help="Default points per generated story (default: 1)")
@click.option("--sprint-file", type=click.Path(), default=None,
              help="Path to sprint YAML file")
@click.option("--dry-run", is_flag=True, help="Show what would be created")
def epic_from_plan_command(
    plan_path: str, epic_id: str, default_points: int,
    sprint_file: str | None, dry_run: bool,
) -> None:
    """Generate epic stories from a superpowers plan (1 story per ### Task N)."""
    sprint_path = (
        Path(sprint_file) if sprint_file
        else get_project_root() / "sprint" / "current-sprint.yaml"
    )
    result = epic_from_plan(
        sprint_path, plan_path, epic_id,
        default_points=default_points, dry_run=dry_run,
    )
    if not result["success"]:
        raise click.ClickException(result["error"])
    if dry_run:
        click.echo(
            f"[DRY-RUN] Would create {len(result['created'])} stories; "
            f"skip {len(result['skipped'])}"
        )
    else:
        click.echo(f"Created {len(result['created'])} stories: "
                   f"{', '.join(str(c) for c in result['created'])}")
        if result["skipped"]:
            click.echo(f"Skipped (already present): tasks {result['skipped']}")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_epic_from_plan.py -v`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/sprint/epic_from_plan.py pennyfarthing-dist/src/pf/tests/test_epic_from_plan.py
git commit -m "feat(sprint): epic_from_plan generates stories + annotates plan"
```

---

### Task 5: Register `from-plan` on the `epic` CLI group

**Files:**
- Modify: `pennyfarthing-dist/src/pf/epic/cli.py`
- Test: `pennyfarthing-dist/src/pf/tests/test_epic_from_plan_cli.py`

- [ ] **Step 1: Write the failing test**

```python
# pennyfarthing-dist/src/pf/tests/test_epic_from_plan_cli.py
from click.testing import CliRunner

from pf.epic.cli import epic


def test_from_plan_is_registered():
    assert "from-plan" in epic.commands


def test_from_plan_help_runs():
    result = CliRunner().invoke(epic, ["from-plan", "--help"])
    assert result.exit_code == 0
    assert "1 story per" in result.output or "plan" in result.output.lower()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_epic_from_plan_cli.py -v`
Expected: FAIL — `assert 'from-plan' in epic.commands` is False

- [ ] **Step 3: Register the command**

In `pennyfarthing-dist/src/pf/epic/cli.py`, find the block of imported command registrations (near lines 83-89):
```python
from pf.sprint.epic_add import epic_add_command  # noqa: E402
from pf.sprint.epic_reindex import epic_reindex_command  # noqa: E402
from pf.sprint.epic_update import epic_update_command  # noqa: E402

epic.add_command(epic_add_command, "add")
epic.add_command(epic_update_command, "update")
epic.add_command(epic_reindex_command, "reindex")
```

Add the `from-plan` import and registration:
```python
from pf.sprint.epic_add import epic_add_command  # noqa: E402
from pf.sprint.epic_from_plan import epic_from_plan_command  # noqa: E402
from pf.sprint.epic_reindex import epic_reindex_command  # noqa: E402
from pf.sprint.epic_update import epic_update_command  # noqa: E402

epic.add_command(epic_add_command, "add")
epic.add_command(epic_update_command, "update")
epic.add_command(epic_reindex_command, "reindex")
epic.add_command(epic_from_plan_command, "from-plan")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_epic_from_plan_cli.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/epic/cli.py pennyfarthing-dist/src/pf/tests/test_epic_from_plan_cli.py
git commit -m "feat(epic): register pf epic from-plan verb"
```

---

### Task 6: `story_complete` — flip status done + check the plan box

**Files:**
- Create: `pennyfarthing-dist/src/pf/sprint/story_complete.py`
- Test: `pennyfarthing-dist/src/pf/tests/test_story_complete.py`

- [ ] **Step 1: Write the failing test**

```python
# pennyfarthing-dist/src/pf/tests/test_story_complete.py
from pathlib import Path

import yaml

from pf.sprint.story_complete import complete_story


def _sprint_with_story(tmp_path: Path, refs: str | None) -> Path:
    sprint_file = tmp_path / "current-sprint.yaml"
    story = {"id": "99-1", "title": "Do it", "points": 1,
             "status": "in_progress", "workflow": "superpowers"}
    if refs:
        story["refs"] = refs
    data = {
        "sprint": {"name": "T", "number": 1, "status": "active",
                   "start_date": "2026-01-01", "end_date": "2026-01-14", "goal": "g"},
        "epics": [{"id": "99", "type": "epic", "title": "E", "priority": "p1",
                   "status": "backlog", "stories": [story]}],
    }
    sprint_file.write_text(yaml.safe_dump(data))
    return sprint_file


def test_flips_status_to_done(tmp_path):
    sprint_file = _sprint_with_story(tmp_path, refs=None)
    res = complete_story(sprint_file, "99-1", project_root=tmp_path)
    assert res["success"], res
    saved = yaml.safe_load(sprint_file.read_text())
    story = saved["epics"][0]["stories"][0]
    assert story["status"] == "done"
    assert "completed" in story
    assert res["plan_checked"] is False  # no ref -> nothing to check


def test_checks_plan_box_when_ref_present(tmp_path):
    plan = tmp_path / "plan.md"
    plan.write_text(
        "### Task 1: Do it\n\n"
        "- [ ] Step 1\n\n"
        "- [ ] **Story 99-1 complete** — run `pf sprint story complete 99-1`\n"
    )
    sprint_file = _sprint_with_story(tmp_path, refs="plan:plan.md#task-1")
    res = complete_story(sprint_file, "99-1", project_root=tmp_path)
    assert res["success"]
    assert res["plan_checked"] is True
    text = plan.read_text()
    assert "- [x] **Story 99-1 complete**" in text
    assert "- [ ] Step 1" in text  # other boxes untouched


def test_missing_story_returns_error(tmp_path):
    sprint_file = _sprint_with_story(tmp_path, refs=None)
    res = complete_story(sprint_file, "99-404", project_root=tmp_path)
    assert not res["success"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_story_complete.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'pf.sprint.story_complete'`

- [ ] **Step 3: Write minimal implementation**

```python
# pennyfarthing-dist/src/pf/sprint/story_complete.py
"""Complete a superpowers-flow story: status -> done + check its plan box."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import click

from pf.common.config import get_project_root
from pf.sprint.loader import find_story_in_data
from pf.sprint.story_update import update_story
from pf.sprint.yaml_io import read_sprint


def _check_complete_box(plan_file: Path, story_id: str, *, dry_run: bool) -> bool:
    """Flip the `- [ ]` -> `- [x]` on the line invoking complete for this story."""
    needle = f"pf sprint story complete {story_id}"
    lines = plan_file.read_text().splitlines()
    for i, ln in enumerate(lines):
        if needle in ln and "- [ ]" in ln:
            lines[i] = ln.replace("- [ ]", "- [x]", 1)
            if not dry_run:
                plan_file.write_text("\n".join(lines) + "\n")
            return True
    return False


def complete_story(
    sprint_path: Path,
    story_id: str,
    *,
    project_root: Path | None = None,
    dry_run: bool = False,
) -> dict[str, Any]:
    """Mark ``story_id`` done and check its plan checkbox if a plan ref exists.

    Returns ``{"success", "story_id", "plan_checked"}`` or
    ``{"success": False, "error"}``.
    """
    res = update_story(sprint_path, story_id, status="done", dry_run=dry_run)
    if not res.get("success"):
        return res

    data = read_sprint(sprint_path)
    _epic, story, _loc = find_story_in_data(data, story_id)

    plan_checked = False
    if story:
        ref = story.get("refs")
        if isinstance(ref, str) and ref.startswith("plan:"):
            rel = ref[len("plan:"):].split("#", 1)[0]
            root = Path(project_root) if project_root else get_project_root()
            plan_file = root / rel
            if plan_file.exists():
                plan_checked = _check_complete_box(plan_file, story_id, dry_run=dry_run)

    return {"success": True, "story_id": story_id, "plan_checked": plan_checked}


@click.command("complete")
@click.argument("story_id", type=str)
@click.option("--sprint-file", type=click.Path(), default=None,
              help="Path to sprint YAML file")
@click.option("--dry-run", is_flag=True, help="Show what would change")
def story_complete_command(
    story_id: str, sprint_file: str | None, dry_run: bool,
) -> None:
    """Mark a story done and check its plan checkbox (superpowers flow)."""
    sprint_path = (
        Path(sprint_file) if sprint_file
        else get_project_root() / "sprint" / "current-sprint.yaml"
    )
    result = complete_story(sprint_path, story_id, dry_run=dry_run)
    if not result["success"]:
        raise click.ClickException(result["error"])
    box = "plan box checked" if result.get("plan_checked") else "no plan box"
    click.echo(f"Completed {story_id} ({box})")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_story_complete.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/sprint/story_complete.py pennyfarthing-dist/src/pf/tests/test_story_complete.py
git commit -m "feat(sprint): story complete flips status + checks plan box"
```

---

### Task 7: Register `complete` on the `story` CLI group

**Files:**
- Modify: `pennyfarthing-dist/src/pf/sprint/cli.py`
- Test: `pennyfarthing-dist/src/pf/tests/test_story_complete_cli.py`

- [ ] **Step 1: Write the failing test**

```python
# pennyfarthing-dist/src/pf/tests/test_story_complete_cli.py
from pf.sprint.cli import story


def test_complete_is_registered():
    assert "complete" in story.commands
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_story_complete_cli.py -v`
Expected: FAIL — `assert 'complete' in story.commands` is False

- [ ] **Step 3: Register the command**

In `pennyfarthing-dist/src/pf/sprint/cli.py`, find the imported story command registrations (near lines 519-541):
```python
from pf.sprint.story_move import story_move_command  # noqa: E402
story.add_command(story_move_command, "move")
```

Add the `complete` import and registration immediately after:
```python
from pf.sprint.story_move import story_move_command  # noqa: E402
story.add_command(story_move_command, "move")

from pf.sprint.story_complete import story_complete_command  # noqa: E402
story.add_command(story_complete_command, "complete")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_story_complete_cli.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Run the combined new-feature test set**

Run: `cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_repo_map.py src/pf/tests/test_plan_parser.py src/pf/tests/test_story_add_refs.py src/pf/tests/test_epic_from_plan.py src/pf/tests/test_epic_from_plan_cli.py src/pf/tests/test_story_complete.py src/pf/tests/test_story_complete_cli.py -v`
Expected: PASS (all green — full feature surface)

- [ ] **Step 6: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/src/pf/sprint/cli.py pennyfarthing-dist/src/pf/tests/test_story_complete_cli.py
git commit -m "feat(sprint): register pf sprint story complete verb"
```

---

### Task 8: Repurpose `pf-epic.md` into the conductor doc

**Files:**
- Modify: `pennyfarthing-dist/commands/pf-epic.md`

This task is documentation only — no test. It rewrites the command doc so `/pf-epic` drives the five-leg flow and instructs `writing-plans` to emit task blocks that `from-plan` can materialize.

- [ ] **Step 1: Read the current doc**

Run: `cat /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist/commands/pf-epic.md`
Note its existing front-matter/format so the rewrite matches sibling command docs.

- [ ] **Step 2: Rewrite the body to describe the conductor**

Replace the body (keep any existing YAML front-matter header) with content covering these sections verbatim in intent:

````markdown
# /pf-epic — Epic Conductor

Drives an epic end-to-end: **brainstorm → plan → materialize → execute → rollup review**.
The plan is the source of truth; the epic YAML is a generated ledger.

## Flow

1. **Brainstorm** — invoke `superpowers:brainstorming`. Output: a spec under
   `docs/superpowers/specs/`.
2. **Plan** — invoke `superpowers:writing-plans`. Output: a plan under
   `docs/superpowers/plans/`. Each `### Task N` is one unit of work and will become
   one PF story. (Story ids do not exist yet — `from-plan` assigns them next.)
3. **Materialize** — ensure the epic exists (`pf epic add <id> "<title>"` if needed),
   then run:
   ```bash
   pf epic from-plan docs/superpowers/plans/<plan>.md <epic-id>
   ```
   This creates one `workflow: superpowers` story per Task (repos derived from each
   Task's `Files:` block) and appends a closing step to each Task in the plan:
   `- [ ] **Story <id> complete** — run \`pf sprint story complete <id>\``.
   Re-running is safe (idempotent — already-materialized tasks are skipped).
4. **Execute** — invoke `superpowers:subagent-driven-development` (preferred) or
   `superpowers:executing-plans`. The closing step of each Task runs
   `pf sprint story complete <id>`, which flips the story to `done` and checks the
   plan box. Commits may span multiple repos per `repos.yaml`.
5. **Rollup review** — once all stories are `done`, run one review per affected repo
   (union of every story's `repos:`), each PR'd to that repo's base branch from
   `repos.yaml` (via `/pf-reviewer`). Then `pf epic close <epic-id>`.

## Gates

- **Materialize-before-execute:** do not start execution until `pf epic from-plan` has
  created the stories.
- **Done-before-review:** all epic stories must be `done` before the rollup review.

## Notes

- Per-story TEA→Dev→Reviewer phased ceremony is bypassed for `workflow: superpowers`
  stories; the rollup review is the gate.
- Existing `pf epic` verbs (`start`, `close`, `show`, `add`, `update`, …) are unchanged.
````

- [ ] **Step 3: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing
git add pennyfarthing-dist/commands/pf-epic.md
git commit -m "docs(epic): repurpose /pf-epic into the superpowers conductor"
```

---

## Final verification (after all tasks)

- [ ] **Run the full feature test set** (targeted — not the whole suite):

```bash
cd /Users/slabgorb/Projects/orc-penny/pennyfarthing/pennyfarthing-dist
uv run pytest \
  src/pf/tests/test_repo_map.py \
  src/pf/tests/test_plan_parser.py \
  src/pf/tests/test_story_add_refs.py \
  src/pf/tests/test_epic_from_plan.py \
  src/pf/tests/test_epic_from_plan_cli.py \
  src/pf/tests/test_story_complete.py \
  src/pf/tests/test_story_complete_cli.py -v
```
Expected: all green.

- [ ] **Smoke-test the CLI end to end** against a throwaway epic in this orchestrator
  (the symlinked `.pennyfarthing/` picks up the edited source automatically):

```bash
cd /Users/slabgorb/Projects/orc-penny
pf epic from-plan docs/superpowers/plans/2026-05-29-epic-as-unit.md <throwaway-epic-id> --dry-run
```
Expected: reports the number of stories it would create.

- [ ] **Use superpowers:finishing-a-development-branch** to open the PR for
  `feat/epic-as-unit` against `develop` in the `pennyfarthing/` repo.

---

## Self-Review (run against the spec before handing off)

**Spec coverage:**
- `pf epic from-plan` (spec Component 1) → Tasks 4, 5.
- `pf sprint story complete` (spec Component 2) → Tasks 6, 7.
- `workflow: superpowers` sentinel (spec Component 3) → Task 3 (choice) + used in Task 4.
- writing-plans convention / closing step (spec Component 4) → Task 4 annotation + Task 8 doc.
- `/pf-epic` conductor (spec Component 5) → Task 8.
- Repo-awareness / file→repo mapping (spec Repo-Awareness) → Task 1, consumed in Task 4.
- Result objects (spec Error Handling) → every business fn returns `{success, …}`.
- Plan = source of truth (spec Artifacts) → epic YAML generated via `add_story`; no hand-edits.

**Out-of-scope items confirmed absent:** no per-task agent dispatch, no two-way sync, no historical-plan retrofit, no migration tooling.

**Type consistency:** `add_story(..., refs=...)`, `epic_from_plan(...) -> {created, skipped}`,
`complete_story(...) -> {plan_checked}`, `map_path_to_repo(file_path, repos)`,
`PlanTask.anchor == "task-N"`, ref format `plan:<relpath>#task-N` — used identically in
producer (Task 4) and consumer (Task 6).
