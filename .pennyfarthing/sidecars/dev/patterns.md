# Dev Agent Patterns

<pattern name="complete-phase-subgate">
To make a markdown gate's check mechanically enforced, add a subgate in `complete_phase()` (`pennyfarthing-dist/src/pf/handoff/complete_phase.py`), keyed on `gate_type`, placed AFTER the assessment guard but BEFORE `now = datetime.now(...)` and the session-mutation block — so a failed check returns `{"status": "error", "session_file": str(session_path), "error": <actionable msg>}` and leaves the session untouched (the half-mutated-session corruption is what these stories are usually about). Mirror the existing `_check_subagent_completion`/assessment return shape. Story 158-3: `gate_type == "sm_setup_exit"` now requires `sprint/context/context-epic-{N}.md` + `context-story-{N-N}.md` (epic `N = story_id.split("-")[0]`) to exist and be non-empty; presence+non-empty mirrors the gate's documented Fallback — don't couple the hot handoff path to the full `pf validate context-*` schema validator. `complete_phase` already receives an explicit `project_root`, so tests pass a `tmp_path` project cleanly (no env/cwd root-resolution trap). Verify GREEN with the scoped `uv run pytest src/pf/tests/test_X.py -q` + re-run `test_handoff_cli.py test_handoff_e2e.py` for regressions — never the full suite (branch leak).
</pattern>

<pattern name="jira-less-local-fallback">
When a `pf` command must work on kanban-only projects (story 158-5/gh #48: `pf sprint story claim`), gate the *programmatic wrapper* (`claim_issue`), not just the CLI — so CLI + any caller get the fallback. Branch on `pf.jira.client.is_jira_enabled()` (re-reads config each call): True → existing Jira path untouched; False → a local-only helper that mutates sprint YAML with NO `get_client()`/`check_availability()`. Reuse `transition_story(root, id, target)` for the status change — it already skips Jira via its `if jira_key:` guard, so don't reimplement YAML writes. transition_story re-reads+writes internally, so set sibling fields (e.g. `assigned_to`) on a FRESH `read_sprint` AFTER it returns, else its write clobbers your in-memory change. Resolve identity with `get_current_user_email()` (local: JIRA_USER env → git config, no Jira). Block real conflicts by NAMING the assignee (never default to "unknown"). Return result dicts with `exit_code`, never raise (SOUL #10). `pf jira claim` (jira/cli.py) already had this gate; the bug was the *separate* sprint-level command.
</pattern>

<pattern name="paths">
Always use `$CLAUDE_PROJECT_DIR` as base. Multi-repo: `source $CLAUDE_PROJECT_DIR/scripts/repo-utils.sh`.
</pattern>

<pattern name="assessment">
```
## Dev Assessment
**Implementation Complete:** Yes
**Files Changed:** `path` - description
**Tests:** N/N passing (GREEN)
**PR:** #N — title
**Handoff:** To Reviewer for code review
```
</pattern>

<pattern name="self-dev">
`.claude/` dirs are symlinks to `pennyfarthing-dist/`. Edit source, changes are immediate.
</pattern>

<pattern name="notifications">
Message view IS the notification system. Errors to `console.error`, no toast UI.
</pattern>

<pattern name="yaml-rw">
Read-modify-write YAML. Never overwrite entire file to set one field.
```typescript
let existing = fs.existsSync(path) ? parseYaml(fs.readFileSync(path, 'utf-8')) : {};
existing.field = newValue;
fs.writeFileSync(path, stringifyYaml(existing));
```
</pattern>

<pattern name="electron-storage">
Use `path` option for per-project storage: `windowStateKeeper({ path: join(projectDir, '.pennyfarthing') })`.
</pattern>

<pattern name="benchmark-cli">
Benchmark CLI at `pennyfarthing-dist/src/pf/benchmark/cli.py`. When adding commands: filter extra keys from `majority_vote.yaml` findings (has `votes` etc not in `FindingScore`). Use `.get()` with defaults for `scenario_id`/`run_id` — not all score files have them. Theme dimensions: `data['theme']['dimensions']` not `data['dimensions']`.
</pattern>

<pattern name="gate-admonition">
Frame all mandatory steps as blocking admonitions, never suggestions. Use "Do not proceed with [next action] until [condition]" — not "you MUST", "please check", or "you should". Models treat suggestions as optional under pressure; admonitions define a precondition that blocks progression.
</pattern>
