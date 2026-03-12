# Story 141-25: Support Project-Level Workflow Definitions

## Summary
3pt story to add a second workflow lookup path at `.pennyfarthing/project/workflows/` that overrides or extends the distributed defaults in `.pennyfarthing/workflows/` (symlinked from `pennyfarthing-dist/workflows/`). This enables projects to customize workflows without modifying the framework source.

## Technical Approach

### Override semantics
Project-level workflows override distributed workflows by **name**. When both directories contain a workflow with the same name (e.g., `tdd.yaml`), the project version wins. Workflows that exist only in the project directory are additive (shown alongside distributed ones). This is a simple "project wins" model with no merging of individual fields.

### Key change: introduce `get_all_workflow_dirs()` and update `find_workflow_file()`

The current architecture routes everything through two functions in `helpers.py`:

1. **`get_workflows_dir()`** -- returns a single path: `{root}/.pennyfarthing/workflows/`
2. **`find_workflow_file()`** -- looks for `{name}.yaml` or `{name}/workflow.yaml` in that single directory

The approach:

1. Add `get_project_workflows_dir()` in `helpers.py` that returns `{root}/.pennyfarthing/project/workflows/`. This directory may not exist (and that is fine -- no error).

2. Update `find_workflow_file()` to accept a list of directories (or search project dir first, then distributed dir). Project directory is checked first; if found there, it wins. Signature becomes:
   ```python
   def find_workflow_file(
       workflows_dirs: list[Path] | Path,
       workflow_name: str
   ) -> Path | None
   ```
   For backward compatibility, accept a single `Path` as well (wrap in list internally).

3. Update `workflow_list_cmd()` in `cli.py` to collect files from both directories, deduplicating by workflow name (project wins). Add a `Source` column to the table output showing `project` or `dist` origin.

4. Update `workflow_show_cmd()` in `cli.py` to search both directories via the updated `find_workflow_file()`.

5. Update all other callers of `find_workflow_file()` and `get_workflows_dir()` in `cli.py` to pass both directories:
   - `workflow_phases()`
   - `workflow_type_cmd()`
   - `workflow_start_cmd()`
   - `workflow_resume_cmd()`
   - `workflow_status_cmd()`
   - `workflow_complete_step_cmd()`
   - `workflow_fix_phase_cmd()` (uses hardcoded phase defs, not file lookup -- no change needed)

### Helper function additions (`helpers.py`)

```python
def get_project_workflows_dir(project_root: Path | None = None) -> Path:
    """Get the project-level workflows directory path."""
    root = project_root or get_project_root()
    return root / ".pennyfarthing" / "project" / "workflows"

def get_all_workflows_dirs(project_root: Path | None = None) -> list[Path]:
    """Get workflow directories in priority order (project first, then dist)."""
    root = project_root or get_project_root()
    dirs = []
    project_dir = get_project_workflows_dir(root)
    if project_dir.is_dir():
        dirs.append(project_dir)
    dist_dir = get_workflows_dir(root)
    if dist_dir.is_dir():
        dirs.append(dist_dir)
    return dirs
```

### Validation
Project workflow YAMLs must conform to the same schema as distributed workflows. No special validation beyond what `load_workflow_data()` already does (YAML parsing). The existing `pf validate workflow` command should be extended to scan the project directory too, but that can be a follow-up if out of scope for 3 points.

## Key Files (likely affected)

- `pennyfarthing-dist/src/pf/workflow/helpers.py` -- add `get_project_workflows_dir()`, `get_all_workflows_dirs()`, update `find_workflow_file()` signature
- `pennyfarthing-dist/src/pf/workflow/cli.py` -- update `workflow_list_cmd()`, `workflow_show_cmd()`, and all other commands that call `find_workflow_file()` or `get_workflows_dir()`

## Architecture Considerations

- **No deep merge.** A project workflow replaces the entire distributed workflow of the same name. This keeps the mental model simple and avoids ambiguity about which phases come from where.
- **Directory may not exist.** `.pennyfarthing/project/workflows/` is optional. All code must gracefully handle its absence (check `is_dir()` before globbing).
- **Source transparency.** `pf workflow list` should indicate whether each workflow comes from `project` or `dist` so the user can tell at a glance what has been customized.
- **No symlink changes.** `.pennyfarthing/workflows/` remains a symlink to `pennyfarthing-dist/workflows/`. The project directory is a separate, local, writable path -- consistent with how `.pennyfarthing/project/hooks/` already works.

## Acceptance Criteria Mapping

| AC | Implementation |
|----|---------------|
| `pf workflow list` shows project-level workflows alongside distributed ones | Update `workflow_list_cmd()` to collect from both dirs, deduplicate, add Source column |
| Project workflows in `.pennyfarthing/project/workflows/` override distributed workflows with the same name | `find_workflow_file()` checks project dir first; `workflow_list_cmd()` deduplicates with project winning |
| `pf workflow show` works for project-level workflow definitions | `workflow_show_cmd()` uses updated `find_workflow_file()` that searches both dirs |
