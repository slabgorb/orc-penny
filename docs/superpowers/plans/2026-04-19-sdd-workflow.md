# SDD Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `sdd` phased workflow — a parallel to `tdd.yaml` that layers named `superpowers:*` skill invocations onto TEA/Dev/Reviewer phases with attestation-based exit gates.

**Architecture:** Five-phase phased workflow (setup → red → green → review → finish). Per-phase `skills.required` list in the workflow YAML. Two new composite gates (`sdd-red-exit`, `sdd-green-exit`) that chain existing gates (`tests-fail`, `dev-exit`) with inline skill-attestation checks reading `<skills-invoked>` from the session file. One small Python helper and prime integration to surface required skills to the activating agent. No hook changes, no markers, no Skill-tool interception.

**Tech Stack:** YAML workflow definitions, Markdown gate files (Haiku-evaluated), Python (`pf.prime.workflow`) for phase config reads, session XML for attestation records.

**Spec reference:** `docs/superpowers/specs/2026-04-19-sdd-workflow-design.md`

**Repo target:** All framework code lands in `pennyfarthing/` (gitflow, PRs target `develop`). Orchestrator-side changes (if any follow-up is needed) stay on `feat/sdd-workflow` in the orchestrator repo.

---

## File Structure

**New files (all under `pennyfarthing/pennyfarthing-dist/`):**

| Path | Responsibility |
|------|----------------|
| `workflows/sdd.yaml` | Workflow definition — 5 phases with per-phase `skills.required` lists |
| `gates/skill-attested.md` | Reference/template gate documenting the attestation check format (not directly referenced by workflow YAML) |
| `gates/sdd-red-exit.md` | Composite gate: `tests-fail` + skill-attested(`test-driven-development`) |
| `gates/sdd-green-exit.md` | Composite gate: `dev-exit` + skill-attested(`test-driven-development`, `verification-before-completion`, `requesting-code-review`) |

**Modified files (all under `pennyfarthing/pennyfarthing-dist/`):**

| Path | Change |
|------|--------|
| `schemas/session-schema.md` | Document the `<skills-invoked>` element |
| `src/pf/prime/workflow.py` | Add `get_phase_skills(workflow, phase, root)` helper |
| `src/pf/prime/cli.py` | Surface required skills block in prime output when phase has `skills.required` |
| `src/pf/tests/test_prime.py` | Add tests for `get_phase_skills` and prime output |
| `guides/gates.md` | Add `skill-attested` row to built-in gates table; note composite pattern for SDD |
| `CLAUDE.md` | Note `sdd` as an available workflow |

**Out of scope for this plan:**
- ADR writeup (follow-up in orchestrator repo)
- Finish-phase attestation gate (finish-phase skills are advisory — SM's existing behavior invokes `finishing-a-development-branch` naturally)
- Backporting to BDD/trivial workflows

---

## Task 1: Session Schema — document `<skills-invoked>`

**Files:**
- Modify: `pennyfarthing/pennyfarthing-dist/schemas/session-schema.md`

Add a new section documenting the `<skills-invoked>` element. This is doc-only; the schema-validation hook (`pf/hooks/schema_validation.py`) does not whitelist elements, so no hook change is needed.

- [ ] **Step 1: Open the schema doc at the bottom of the `<work-log>` section**

Find the `### <work-log>` section. Immediately after its `#### <assessment>` subsection and before the "---" separator, insert the new subsection below.

- [ ] **Step 2: Append the `<skills-invoked>` documentation block**

Insert into `pennyfarthing/pennyfarthing-dist/schemas/session-schema.md` after the `<assessment>` subsection:

````markdown
---

### `<skills-invoked>`

**Purpose:** Attestation log for superpowers skills invoked during a phase. Used by the SDD workflow and any future workflow that requires skill-attestation gates. Optional element; present only when a phase requires skill attestation.

**Child Elements:**

#### `<skill>`

**Attributes:**
| Attribute | Required | Description |
|-----------|----------|-------------|
| `name` | Yes | Skill identifier without plugin prefix (e.g., `test-driven-development`) |
| `phase` | Yes | Phase during which the skill was invoked (e.g., `red`, `green`) |
| `at` | Yes | ISO 8601 timestamp of invocation (e.g., `2026-04-19T14:22:03Z`) |

**Content:** Empty element (self-closing).

**Example:**

```xml
<skills-invoked>
  <skill name="test-driven-development" phase="red" at="2026-04-19T14:22:03Z"/>
  <skill name="verification-before-completion" phase="green" at="2026-04-19T15:01:47Z"/>
  <skill name="requesting-code-review" phase="green" at="2026-04-19T15:02:14Z"/>
</skills-invoked>
```

**Agent protocol:** When a workflow phase has `skills.required` in its YAML definition, the activating agent invokes each listed skill via the Skill tool, then appends a `<skill>` entry to `<skills-invoked>` in the session file. Composite exit gates (e.g., `sdd-red-exit`, `sdd-green-exit`) read this element to verify required skills have been attested.
````

- [ ] **Step 3: Commit**

```bash
cd pennyfarthing
git checkout -b feat/sdd-workflow
git add pennyfarthing-dist/schemas/session-schema.md
git commit -m "docs(schema): document <skills-invoked> session element for SDD workflow"
```

---

## Task 2: Generic `skill-attested` reference gate

**Files:**
- Create: `pennyfarthing/pennyfarthing-dist/gates/skill-attested.md`

This file documents the attestation-check format. Composite gates for the SDD workflow (red-exit, green-exit) include their own inline skill-attested check with phase-specific required skills; this file is the canonical reference / template for future workflows that need the same pattern.

- [ ] **Step 1: Create the gate file with full content**

Write the entire file `pennyfarthing/pennyfarthing-dist/gates/skill-attested.md`:

````markdown
<gate name="skill-attested" model="haiku">

<purpose>
Reference template for verifying that required superpowers skills have been
invoked and attested in the session file.

This file is NOT referenced directly by workflow YAML. Composite gates that
need skill attestation (e.g., gates/sdd-red-exit, gates/sdd-green-exit)
include their own `<check name="skill-attested">` block with phase-specific
required skills listed inline.
</purpose>

<check name="skill-attested">
Read the session file at `.session/{STORY_ID}-session.md`.

Look for a <skills-invoked> element containing one <skill/> per invocation:

    <skills-invoked>
      <skill name="test-driven-development" phase="red" at="2026-04-19T14:22:03Z"/>
      <skill name="verification-before-completion" phase="green" at="2026-04-19T15:01:47Z"/>
    </skills-invoked>

For each skill name in the composite gate's required list:
- Find at least one <skill/> element whose `name` attribute matches AND
  whose `phase` attribute equals the current phase.
- If missing, fail with recovery guidance to invoke the skill and attest.
</check>

<pass>
All required skills have attestation entries for the current phase.

GATE_RESULT:
  status: pass
  gate: skill-attested
  message: "All required skills attested for phase {phase}"
  checks:
    - name: skill-attested
      status: pass
      detail: "Attested: {comma-separated skill names}"
</pass>

<fail>
One or more required skills has no attestation entry for the current phase.

GATE_RESULT:
  status: fail
  gate: skill-attested
  message: "Missing skill attestations: {missing list}"
  checks:
    - name: skill-attested
      status: fail
      detail: "Expected: {required}. Found: {found}. Missing: {missing}"
  recovery:
    - "Invoke each missing skill via the Skill tool"
    - "After invocation, append an entry to <skills-invoked> in the session file:"
    - "  <skill name=\"<name>\" phase=\"<current-phase>\" at=\"<ISO8601 timestamp>\"/>"
    - "Re-run the exit protocol"
</fail>

</gate>
````

- [ ] **Step 2: Commit**

```bash
git add pennyfarthing-dist/gates/skill-attested.md
git commit -m "feat(gates): add skill-attested reference gate for SDD workflow"
```

---

## Task 3: Composite gate — `sdd-red-exit`

**Files:**
- Create: `pennyfarthing/pennyfarthing-dist/gates/sdd-red-exit.md`

- [ ] **Step 1: Study the existing composite-gate pattern**

Read `pennyfarthing/pennyfarthing-dist/gates/dev-exit.md` to confirm the `<ref gate="..."/>` + `<check name="...">` structure. The new file follows the same shape.

- [ ] **Step 2: Create the composite gate file**

Write `pennyfarthing/pennyfarthing-dist/gates/sdd-red-exit.md`:

````markdown
<gate name="sdd-red-exit" model="haiku">

<purpose>
Composite gate for TEA RED-phase handoff in the SDD workflow.
Extends tests-fail with a skill-attested check for the
test-driven-development skill.
</purpose>

<ref gate="gates/tests-fail" />

<check name="skill-attested">
Read the session file at `.session/{STORY_ID}-session.md`. Look for a
<skills-invoked> element.

The RED phase of the SDD workflow requires attestation for:
  - test-driven-development

For each required skill, find at least one <skill/> element with
  name="{skill}" phase="red"

If any are missing, fail with recovery guidance.
</check>

<pass>
Run all checks from gates/tests-fail first (ac-coverage, tests-red),
then run the skill-attested check.

If ALL pass:

GATE_RESULT:
  status: pass
  gate: sdd-red-exit
  message: "RED complete: {N} failing tests, TDD skill attested"
  checks:
    - name: ac-coverage
      status: pass
      detail: "All ACs have test coverage"
    - name: tests-red
      status: pass
      detail: "{N} tests failing as expected"
    - name: skill-attested
      status: pass
      detail: "Attested: test-driven-development"
</pass>

<fail>
If ANY check fails, run all remaining checks (don't short-circuit) and return:

GATE_RESULT:
  status: fail
  gate: sdd-red-exit
  message: "RED gate failed: {summary of failures}"
  checks:
    - name: ac-coverage
      status: pass | fail
      detail: "{coverage summary or list of uncovered ACs}"
    - name: tests-red
      status: pass | fail
      detail: "{test state or list of tests that shouldn't be passing yet}"
    - name: skill-attested
      status: pass | fail
      detail: "Expected: test-driven-development. Found: {found}. Missing: {missing}"
  recovery:
    - "Add tests for any uncovered ACs"
    - "Verify all new tests are failing (RED) — implementation should not yet exist"
    - "Invoke superpowers:test-driven-development skill if not yet done"
    - "Append attestation to <skills-invoked> in session file:"
    - "  <skill name=\"test-driven-development\" phase=\"red\" at=\"<ISO8601>\"/>"
</fail>

</gate>
````

- [ ] **Step 3: Commit**

```bash
git add pennyfarthing-dist/gates/sdd-red-exit.md
git commit -m "feat(gates): add sdd-red-exit composite gate"
```

---

## Task 4: Composite gate — `sdd-green-exit`

**Files:**
- Create: `pennyfarthing/pennyfarthing-dist/gates/sdd-green-exit.md`

- [ ] **Step 1: Create the composite gate file**

Write `pennyfarthing/pennyfarthing-dist/gates/sdd-green-exit.md`:

````markdown
<gate name="sdd-green-exit" model="haiku">

<purpose>
Composite gate for Dev GREEN-phase handoff in the SDD workflow.
Extends dev-exit with a skill-attested check for three superpowers skills.
</purpose>

<ref gate="gates/dev-exit" />

<check name="skill-attested">
Read the session file at `.session/{STORY_ID}-session.md`. Look for a
<skills-invoked> element.

The GREEN phase of the SDD workflow requires attestation for:
  - test-driven-development
  - verification-before-completion
  - requesting-code-review

For each required skill, find at least one <skill/> element with
  name="{skill}" phase="green"

If any are missing, fail with recovery guidance.
</check>

<pass>
Run all checks from gates/dev-exit first (test-suite, working-tree,
branch-status, no-debug-code), then run the skill-attested check.

If ALL pass:

GATE_RESULT:
  status: pass
  gate: sdd-green-exit
  message: "GREEN complete: tests pass, tree clean, all required skills attested"
  checks:
    - name: test-suite
      status: pass
      detail: "{passed}/{total} tests passing"
    - name: working-tree
      status: pass
      detail: "No uncommitted changes"
    - name: branch-status
      status: pass
      detail: "On branch {branch}, HEAD at {short-sha}"
    - name: no-debug-code
      status: pass
      detail: "No debug patterns found"
    - name: skill-attested
      status: pass
      detail: "Attested: test-driven-development, verification-before-completion, requesting-code-review"
</pass>

<fail>
If ANY check fails, run all remaining checks (don't short-circuit):

GATE_RESULT:
  status: fail
  gate: sdd-green-exit
  message: "GREEN gate failed: {summary of failures}"
  checks:
    - name: test-suite
      status: pass | fail
      detail: "{test results or failure list}"
    - name: working-tree
      status: pass | fail
      detail: "{clean or list of uncommitted files}"
    - name: branch-status
      status: pass | fail
      detail: "{branch match or mismatch details}"
    - name: no-debug-code
      status: pass | fail
      detail: "{clean or list of debug code locations}"
    - name: skill-attested
      status: pass | fail
      detail: "Expected: test-driven-development, verification-before-completion, requesting-code-review. Found: {found}. Missing: {missing}"
  recovery:
    - "Fix failing tests in: {file1}, {file2}"
    - "Commit or stash uncommitted changes"
    - "Remove debug code: {file:line patterns}"
    - "Invoke any missing superpowers skills"
    - "Append attestations to <skills-invoked> in session file:"
    - "  <skill name=\"<name>\" phase=\"green\" at=\"<ISO8601>\"/>"
</fail>

</gate>
````

- [ ] **Step 2: Commit**

```bash
git add pennyfarthing-dist/gates/sdd-green-exit.md
git commit -m "feat(gates): add sdd-green-exit composite gate"
```

---

## Task 5: Workflow definition — `sdd.yaml`

**Files:**
- Create: `pennyfarthing/pennyfarthing-dist/workflows/sdd.yaml`

- [ ] **Step 1: Create the workflow YAML**

Write `pennyfarthing/pennyfarthing-dist/workflows/sdd.yaml`:

```yaml
# SDD Workflow - Superpower Driven Development
# Parallels tdd.yaml but layers superpowers skills onto agent phases.
# Composability experiment — opt-in via `workflow: sdd` on a story.
#
# Flow: SM → TEA → Dev → Reviewer → SM
# No architect phases. No separate verify phase.
# Per-phase `skills.required` lists the superpowers skills agents must
# invoke and attest to in the session file's <skills-invoked> element.

workflow:
  name: sdd
  description: Superpower Driven Development — TDD skeleton with superpowers skill attestation
  version: "1.0.0"

  phases:
    - name: setup
      agent: sm
      output: [session_file, branches, story_context]
      gate:
        file: gates/sm-setup-exit
        type: sm_setup_exit
        condition: Session file created with workflow, phase, context, and branch
        recovery:
          epic-context-validated:
            action: create_context
            type: epic
            max_attempts: 1
          story-context-validated:
            action: create_context
            type: story
            max_attempts: 1

    - name: red
      agent: tea
      input: [session_file, story_context]
      output: [failing_tests]
      entry_gate:
        file: gates/tea-context
        type: tea_context
        condition: Story context validated before RED phase
      skills:
        required:
          - superpowers:test-driven-development
      gate:
        file: gates/sdd-red-exit
        type: sdd_red_exit
        condition: All ACs have failing tests AND test-driven-development skill attested

    - name: green
      agent: dev
      input: [failing_tests, story_context]
      output: [implementation, passing_tests]
      skills:
        required:
          - superpowers:test-driven-development
          - superpowers:verification-before-completion
          - superpowers:requesting-code-review
      gate:
        file: gates/sdd-green-exit
        type: sdd_green_exit
        condition: Tests green, tree clean, no debug code AND required skills attested

    - name: review
      agent: reviewer
      input: [implementation, passing_tests]
      output: [approval]
      entry_gate:
        file: gates/status-sync
        type: status_sync
        condition: Story status is in_review in both YAML and Jira
      gate:
        file: gates/approval
        type: approval
        condition: Code review approved, no blocking issues
        recovery:
          reviewer-verdict:
            action: rework
            target_phase: green
            max_attempts: 3

    - name: finish
      agent: sm
      input: [approval]
      output: [archived_session, story_summary]
      skills:
        # Advisory only — no exit gate enforces attestation for finish.
        # SM's normal finish ceremony naturally invokes this skill.
        required:
          - superpowers:finishing-a-development-branch
      entry_gate:
        file: gates/status-sync
        type: status_sync
        condition: Story status is in_review in both YAML and Jira

  triggers:
    types: [feature, enhancement]
    points:
      min: 3
    default: false
```

- [ ] **Step 2: Verify YAML parses**

Run:

```bash
cd pennyfarthing
python3 -c "import yaml; yaml.safe_load(open('pennyfarthing-dist/workflows/sdd.yaml'))" && echo "YAML OK"
```

Expected: `YAML OK`

- [ ] **Step 3: Verify `pf workflow show sdd` loads**

Run from orchestrator root:

```bash
cd /Users/keithavery/Projects/pf-1
pf workflow show sdd
```

Expected: tabular output listing setup/red/green/review/finish with agents sm/tea/dev/reviewer/sm and gates sm_setup_exit/sdd_red_exit/sdd_green_exit/approval/none.

- [ ] **Step 4: Commit**

```bash
cd pennyfarthing
git add pennyfarthing-dist/workflows/sdd.yaml
git commit -m "feat(workflows): add SDD workflow (Superpower Driven Development)"
```

---

## Task 6: Prime helper — `get_phase_skills` (TDD)

**Files:**
- Modify: `pennyfarthing/pennyfarthing-dist/src/pf/prime/workflow.py`
- Test: `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_prime.py`

- [ ] **Step 1: Write the failing test**

Open `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_prime.py`. Add these tests at the bottom of the file (adjust imports at top if needed to include `get_phase_skills`):

```python
import tempfile
from pathlib import Path
import textwrap

import pytest

from pf.prime.workflow import get_phase_skills


class TestGetPhaseSkills:
    """Tests for get_phase_skills helper used by SDD workflow."""

    @pytest.fixture
    def fake_project(self, tmp_path: Path) -> Path:
        """Create a fake project root with a workflows directory."""
        (tmp_path / "pennyfarthing-dist" / "workflows").mkdir(parents=True)
        return tmp_path

    def _write_workflow(self, project_root: Path, name: str, yaml_body: str) -> None:
        path = project_root / "pennyfarthing-dist" / "workflows" / f"{name}.yaml"
        path.write_text(textwrap.dedent(yaml_body).lstrip())

    def test_returns_skills_when_phase_has_required_list(self, fake_project: Path) -> None:
        self._write_workflow(
            fake_project,
            "sdd",
            """
            workflow:
              name: sdd
              phases:
                - name: red
                  agent: tea
                  skills:
                    required:
                      - superpowers:test-driven-development
            """,
        )
        result = get_phase_skills("sdd", "red", fake_project)
        assert result == ["superpowers:test-driven-development"]

    def test_returns_multiple_skills(self, fake_project: Path) -> None:
        self._write_workflow(
            fake_project,
            "sdd",
            """
            workflow:
              name: sdd
              phases:
                - name: green
                  agent: dev
                  skills:
                    required:
                      - superpowers:test-driven-development
                      - superpowers:verification-before-completion
                      - superpowers:requesting-code-review
            """,
        )
        result = get_phase_skills("sdd", "green", fake_project)
        assert result == [
            "superpowers:test-driven-development",
            "superpowers:verification-before-completion",
            "superpowers:requesting-code-review",
        ]

    def test_returns_none_when_phase_has_no_skills_block(self, fake_project: Path) -> None:
        self._write_workflow(
            fake_project,
            "tdd",
            """
            workflow:
              name: tdd
              phases:
                - name: red
                  agent: tea
            """,
        )
        assert get_phase_skills("tdd", "red", fake_project) is None

    def test_returns_none_when_phase_not_found(self, fake_project: Path) -> None:
        self._write_workflow(
            fake_project,
            "sdd",
            """
            workflow:
              name: sdd
              phases:
                - name: red
                  agent: tea
            """,
        )
        assert get_phase_skills("sdd", "nonexistent", fake_project) is None

    def test_returns_none_when_workflow_file_missing(self, fake_project: Path) -> None:
        assert get_phase_skills("does-not-exist", "red", fake_project) is None

    def test_returns_none_when_required_is_empty(self, fake_project: Path) -> None:
        self._write_workflow(
            fake_project,
            "sdd",
            """
            workflow:
              name: sdd
              phases:
                - name: red
                  agent: tea
                  skills:
                    required: []
            """,
        )
        assert get_phase_skills("sdd", "red", fake_project) is None
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd pennyfarthing
python3 -m pytest pennyfarthing-dist/src/pf/tests/test_prime.py::TestGetPhaseSkills -v
```

Expected: all 6 tests fail with `ImportError` or `AttributeError: has no attribute 'get_phase_skills'`.

- [ ] **Step 3: Add `get_phase_skills` to `prime/workflow.py`**

Open `pennyfarthing/pennyfarthing-dist/src/pf/prime/workflow.py`. Immediately after the existing `get_phase_team_config` function (around line 418) and before `get_step_tandem_config`, add:

```python
def get_phase_skills(
    workflow_name: str, phase_name: str, project_root: Path | None = None
) -> list[str] | None:
    """Extract required skills for a specific workflow phase.

    Reads the workflow YAML and returns the list of superpowers skills that
    the agent is expected to invoke during this phase. Returns None when the
    phase has no ``skills.required`` configuration or the list is empty.

    Args:
        workflow_name: Workflow name (sdd, tdd, etc.)
        phase_name: Phase name (setup, red, green, review, finish)
        project_root: Project root path (auto-detected if not provided)

    Returns:
        List of skill identifiers (e.g. ``["superpowers:test-driven-development"]``)
        or None when there are no required skills for this phase.
    """
    root = project_root or get_project_root()
    dist_root = get_dist_root(project_root=root)
    if dist_root:
        workflow_path = dist_root / "workflows" / f"{workflow_name}.yaml"
    else:
        workflow_path = root / "pennyfarthing-dist" / "workflows" / f"{workflow_name}.yaml"

    if not workflow_path.exists():
        return None

    try:
        data = yaml.safe_load(workflow_path.read_text())
        phases = data.get("workflow", {}).get("phases", [])

        for phase in phases:
            if isinstance(phase, dict) and phase.get("name") == phase_name:
                skills = phase.get("skills")
                if isinstance(skills, dict):
                    required = skills.get("required")
                    if isinstance(required, list) and required:
                        return [str(s) for s in required]
                return None

        return None
    except Exception:
        return None
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd pennyfarthing
python3 -m pytest pennyfarthing-dist/src/pf/tests/test_prime.py::TestGetPhaseSkills -v
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add pennyfarthing-dist/src/pf/prime/workflow.py pennyfarthing-dist/src/pf/tests/test_prime.py
git commit -m "feat(prime): add get_phase_skills helper for SDD workflow"
```

---

## Task 7: Prime output — surface Skills Required section

**Files:**
- Modify: `pennyfarthing/pennyfarthing-dist/src/pf/prime/cli.py`
- Test: `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_prime.py`

- [ ] **Step 1: Write the failing test**

Append to `pennyfarthing-dist/src/pf/tests/test_prime.py`:

```python
from click.testing import CliRunner

from pf.cli import cli as pf_cli


class TestPrimeSkillsRequiredSection:
    """Prime output must surface `skills.required` from the current phase."""

    def test_prime_output_includes_skills_section_when_phase_has_required(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange: fake project with SDD workflow in RED phase
        project = tmp_path / "proj"
        (project / ".session").mkdir(parents=True)
        (project / "pennyfarthing-dist" / "workflows").mkdir(parents=True)

        (project / "pennyfarthing-dist" / "workflows" / "sdd.yaml").write_text(
            textwrap.dedent(
                """
                workflow:
                  name: sdd
                  phases:
                    - name: red
                      agent: tea
                      skills:
                        required:
                          - superpowers:test-driven-development
                """
            ).lstrip()
        )

        session_md = (
            "# Session\n\n"
            "## Workflow Phase\n"
            "- **Workflow:** sdd\n"
            "- **Current Phase:** red\n"
        )
        (project / ".session" / "TEST-1-session.md").write_text(session_md)

        monkeypatch.chdir(project)

        # Act
        runner = CliRunner()
        result = runner.invoke(pf_cli, ["agent", "start", "tea", "--quiet"])

        # Assert
        assert result.exit_code == 0, result.output
        assert "Skills Required" in result.output
        assert "superpowers:test-driven-development" in result.output

    def test_prime_output_omits_skills_section_when_phase_has_no_required(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        project = tmp_path / "proj"
        (project / ".session").mkdir(parents=True)
        (project / "pennyfarthing-dist" / "workflows").mkdir(parents=True)

        (project / "pennyfarthing-dist" / "workflows" / "tdd.yaml").write_text(
            textwrap.dedent(
                """
                workflow:
                  name: tdd
                  phases:
                    - name: red
                      agent: tea
                """
            ).lstrip()
        )
        (project / ".session" / "TEST-1-session.md").write_text(
            "## Workflow Phase\n- **Workflow:** tdd\n- **Current Phase:** red\n"
        )

        monkeypatch.chdir(project)

        runner = CliRunner()
        result = runner.invoke(pf_cli, ["agent", "start", "tea", "--quiet"])

        assert result.exit_code == 0, result.output
        assert "Skills Required" not in result.output
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd pennyfarthing
python3 -m pytest pennyfarthing-dist/src/pf/tests/test_prime.py::TestPrimeSkillsRequiredSection -v
```

Expected: first test FAILs on the `"Skills Required" in result.output` assertion.

- [ ] **Step 3: Update prime/cli.py imports**

Open `pennyfarthing/pennyfarthing-dist/src/pf/prime/cli.py`. Find the block near line 58 that imports phase config helpers and extend it:

Locate the existing line:

```python
from pf.prime.workflow import (
    ...
    get_phase_team_config,
    ...
)
```

Add `get_phase_skills` to that import list alongside the other `get_phase_*` helpers. The exact import block structure is already established — add `get_phase_skills,` to the sorted list.

- [ ] **Step 4: Add the Skills Required block to prime output**

In `pennyfarthing/pennyfarthing-dist/src/pf/prime/cli.py`, find the "PRIORITY 4c: Gate recovery guide" block (around line 577-587). Immediately after that block and before "PRIORITY 5: Sprint context", insert:

```python
    # ==========================================================================
    # PRIORITY 4d: Skills Required (only when phase has skills.required)
    # ==========================================================================
    if agent_name and not json_output and result.workflow_status:
        ws = result.workflow_status
        if ws.workflow and ws.phase:
            required_skills = get_phase_skills(ws.workflow, ws.phase, root)
            if required_skills:
                _print_header("Skills Required", quiet)
                print(
                    f"The `{ws.phase}` phase of the `{ws.workflow}` workflow "
                    f"requires invocation and attestation of the following skills:\n"
                )
                for skill in required_skills:
                    print(f"- `{skill}`")
                print(
                    "\nAfter invoking each skill via the Skill tool, append an "
                    "entry to the `<skills-invoked>` element in the session "
                    "file. Example:\n\n"
                    '    <skill name="<name>" phase="' + ws.phase + '" '
                    'at="<ISO8601 timestamp>"/>\n\n'
                    "The phase exit gate will verify every listed skill has an "
                    "attestation entry for this phase."
                )
```

- [ ] **Step 5: Run the new tests to verify they pass**

```bash
cd pennyfarthing
python3 -m pytest pennyfarthing-dist/src/pf/tests/test_prime.py::TestPrimeSkillsRequiredSection -v
```

Expected: both tests pass.

- [ ] **Step 6: Run the full prime test module to verify no regressions**

```bash
python3 -m pytest pennyfarthing-dist/src/pf/tests/test_prime.py -v
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add pennyfarthing-dist/src/pf/prime/cli.py pennyfarthing-dist/src/pf/tests/test_prime.py
git commit -m "feat(prime): surface Skills Required block when phase has skills.required"
```

---

## Task 8: Documentation — `guides/gates.md`

**Files:**
- Modify: `pennyfarthing/pennyfarthing-dist/guides/gates.md`

- [ ] **Step 1: Add `skill-attested` row to the built-in gates table**

Open `pennyfarthing/pennyfarthing-dist/guides/gates.md`. Find the "Built-in Gates" markdown table (around line 11-27). Insert a new row before the closing (keep alphabetical-ish order but match the existing style — insert after `reviewer-preflight-check`):

```markdown
| **skill-attested** | `gates/skill-attested.md` | Verify required superpowers skills have been invoked and attested in session `<skills-invoked>` | SDD workflow composite gates (sdd-red-exit, sdd-green-exit) |
```

- [ ] **Step 2: Add an SDD-focused note after the table**

After the "Built-in Gates" table and before the "Gate File Format" section, add a new subsection:

```markdown
### SDD Composite Gates

The `sdd` workflow uses two composite gates that combine an existing artifact check with skill attestation:

- **`sdd-red-exit`** = `tests-fail` + `skill-attested(test-driven-development)`
- **`sdd-green-exit`** = `dev-exit` + `skill-attested(test-driven-development, verification-before-completion, requesting-code-review)`

Each composite gate file lists its required skills inline in a `<check name="skill-attested">` block. The generic `gates/skill-attested.md` file is a reference template — it is not directly referenced by workflow YAML.
```

- [ ] **Step 3: Commit**

```bash
git add pennyfarthing-dist/guides/gates.md
git commit -m "docs(gates): document skill-attested gate and SDD composite pattern"
```

---

## Task 9: Documentation — framework `CLAUDE.md`

**Files:**
- Modify: `pennyfarthing/CLAUDE.md`

- [ ] **Step 1: Note SDD in the workflows section**

Open `pennyfarthing/CLAUDE.md`. Find the "Workflows & Agents" `<info>` block. After the existing text that says "Workflow definitions live in `pennyfarthing-dist/workflows/*.yaml` — read the YAML for phase order, agents, tandem/team pairings, and gates," add a bullet line noting SDD:

Add immediately before the agent-role table:

```markdown
**Experimental workflows:**
- `sdd` (Superpower Driven Development): Parallels `tdd.yaml` with per-phase `skills.required` lists that agents invoke and attest to in the session file. Composite gates (`sdd-red-exit`, `sdd-green-exit`) verify both artifacts and skill attestation. Opt-in via `workflow: sdd` on a story.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: note SDD workflow as opt-in experimental workflow"
```

---

## Task 10: End-to-end validation

**Files:** None modified — verification only.

- [ ] **Step 1: Run `pf validate workflow` (if available) or parse all workflow YAMLs**

From orchestrator root:

```bash
cd /Users/keithavery/Projects/pf-1
pf validate workflow 2>&1 | tail -20
```

Expected: `sdd` workflow parses without errors. If `pf validate workflow` doesn't exist or doesn't cover this, fall back to:

```bash
python3 -c "
import yaml, pathlib
for p in pathlib.Path('pennyfarthing/pennyfarthing-dist/workflows').glob('*.yaml'):
    yaml.safe_load(p.read_text())
    print(f'OK: {p.name}')
"
```

Expected: `OK: sdd.yaml` in the output among other workflows.

- [ ] **Step 2: Confirm `pf workflow list` lists `sdd`**

```bash
pf workflow list 2>&1 | grep sdd
```

Expected: a line containing `sdd`.

- [ ] **Step 3: Confirm `pf workflow show sdd` produces expected phase table**

```bash
pf workflow show sdd
```

Expected output includes:
- All 5 phases (setup, red, green, review, finish)
- Correct agent per phase (sm, tea, dev, reviewer, sm)
- Correct gate types (sm_setup_exit, sdd_red_exit, sdd_green_exit, approval, none)
- `Default: no` in the triggers block

- [ ] **Step 4: Confirm `pf agent start tea` emits Skills Required block in a mocked SDD session**

Create a throwaway test session:

```bash
mkdir -p /tmp/sdd-smoke/.session /tmp/sdd-smoke/pennyfarthing-dist/workflows
cp pennyfarthing/pennyfarthing-dist/workflows/sdd.yaml /tmp/sdd-smoke/pennyfarthing-dist/workflows/
cat > /tmp/sdd-smoke/.session/TEST-1-session.md <<'EOF'
## Workflow Phase
- **Workflow:** sdd
- **Current Phase:** red
EOF
cd /tmp/sdd-smoke && pf agent start tea --quiet 2>&1 | grep -A2 "Skills Required"
```

Expected: a `Skills Required` heading and the `superpowers:test-driven-development` bullet.

Clean up afterwards:

```bash
rm -rf /tmp/sdd-smoke
```

- [ ] **Step 5: Run the full Python test suite**

```bash
cd /Users/keithavery/Projects/pf-1/pennyfarthing
python3 -m pytest pennyfarthing-dist/src/pf/tests/ -v 2>&1 | tail -20
```

Expected: no regressions. All previously-passing tests still pass, plus the new `TestGetPhaseSkills` and `TestPrimeSkillsRequiredSection` classes.

- [ ] **Step 6: Push the feature branch and open a PR against `develop`**

```bash
git push -u origin feat/sdd-workflow
gh pr create --base develop --title "feat: add SDD (Superpower Driven Development) workflow" --body "$(cat <<'EOF'
## Summary

Adds a new phased workflow `sdd` that parallels `tdd.yaml` but layers named `superpowers:*` skill invocations onto TEA/Dev/Reviewer phases with attestation-based exit gates. Composability experiment — existing gate machinery reused, no new hooks or markers.

- `workflows/sdd.yaml` — 5 phases (setup/red/green/review/finish), opt-in trigger
- `gates/sdd-red-exit.md`, `gates/sdd-green-exit.md` — composite gates chaining existing checks + skill-attested
- `gates/skill-attested.md` — reference template
- `schemas/session-schema.md` — documents `<skills-invoked>` element
- `src/pf/prime/workflow.py` — new `get_phase_skills` helper
- `src/pf/prime/cli.py` — surfaces Skills Required block when phase has `skills.required`

Spec: `docs/superpowers/specs/2026-04-19-sdd-workflow-design.md` (orchestrator repo)

## Test plan
- [x] `pytest pennyfarthing-dist/src/pf/tests/test_prime.py` — new tests pass
- [x] `pf workflow show sdd` — phase table renders correctly
- [x] `pf agent start tea` in a SDD session — Skills Required section appears
- [x] Full test suite — no regressions
EOF
)"
```

Expected: PR opened, CI runs.

---

## Self-Review Notes

Checked against `docs/superpowers/specs/2026-04-19-sdd-workflow-design.md`:

- **Workflow shape** ✓ Task 5 creates all 5 phases with the agents from the spec.
- **Skills mapping** ✓ Task 5 YAML lists red/green/finish skills as specified. Review phase has no `skills.required` — the spec notes `receiving-code-review` is invoked by Dev during rework loop, which is behavioral (dev handles it on re-entry to green), not phase-pinned.
- **Gate composition** ✓ Tasks 3 and 4 create the composite gates using the existing `<ref gate=...>` pattern.
- **No new machinery** ✓ No hook changes. Session schema update is doc-only (validator is permissive). Prime addition is a single new helper + small output block mirroring existing tandem/team/recovery patterns.
- **Trigger** ✓ Task 5 sets `default: false` with `points.min: 3` and `types: [feature, enhancement]`.
- **Advisory finish-phase skills** ✓ Task 5 YAML includes `skills.required` on finish but no exit gate enforces it — documented inline.
- **Open Question 1 (prime surfacing)** ✓ Resolved by Tasks 6-7.
- **Open Question 2 (schema validation)** ✓ Resolved by investigating `hooks/schema_validation.py` — validator is permissive; doc update is sufficient.
- **Open Question 3 (composite gate format)** ✓ Resolved by reading `dev-exit.md`; `<ref gate=...>` + `<check>` pattern applied in Tasks 3-4.

No placeholders in any step. File paths are absolute within the repo structure. Code blocks are complete.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-19-sdd-workflow.md`. Two execution options:

1. **Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
