# Dev Agent Patterns

<pattern name="load-file-callback-warning-ownership">
When fail-louding a `load_file`-style callback passed into `merge_epic_shards` (story 160-4, gh #50): warn INSIDE the callback for parse failures and non-dict payloads, but catch `OSError` separately and return None SILENTLY — `merge_epic_shards` owns the missing-file "not found" warning via its `exists()` check, and ws_push's pre-resolve `ref_by_id` loop calls the callback on paths that may not exist (a parse-flavored warning there breaks the AC4 missing-vs-malformed distinction). Return None (not the scalar) for non-dict so merge's `if epic_data is None: continue` skips it instead of crashing on `.get` at shard_merge.py:79. The callback fires up to 3× per shard (pre-resolve, merge, orphan-scan) → duplicate warnings are acceptable per the pinned tests (presence, not count). Preserve the `or {}` empty-file semantics (`loaded is None → {}`).
</pattern>

<pattern name="complete-phase-subgate">
To make a markdown gate's check mechanically enforced, add a subgate in `complete_phase()` (`pennyfarthing-dist/src/pf/handoff/complete_phase.py`), keyed on `gate_type`, placed AFTER the assessment guard but BEFORE `now = datetime.now(...)` and the session-mutation block — so a failed check returns `{"status": "error", "session_file": str(session_path), "error": <actionable msg>}` and leaves the session untouched (the half-mutated-session corruption is what these stories are usually about). Mirror the existing `_check_subagent_completion`/assessment return shape. Story 158-3: `gate_type == "sm_setup_exit"` now requires `sprint/context/context-epic-{N}.md` + `context-story-{N-N}.md` (epic `N = story_id.split("-")[0]`) to exist and be non-empty; presence+non-empty mirrors the gate's documented Fallback — don't couple the hot handoff path to the full `pf validate context-*` schema validator. `complete_phase` already receives an explicit `project_root`, so tests pass a `tmp_path` project cleanly (no env/cwd root-resolution trap). Verify GREEN with the scoped `uv run pytest src/pf/tests/test_X.py -q` + re-run `test_handoff_cli.py test_handoff_e2e.py` for regressions — never the full suite (branch leak).
</pattern>

<pattern name="jira-less-local-fallback">
When a `pf` command must work on kanban-only projects (story 158-5/gh #48: `pf sprint story claim`), gate the *programmatic wrapper* (`claim_issue`), not just the CLI — so CLI + any caller get the fallback. Branch on `pf.jira.client.is_jira_enabled()` (re-reads config each call): True → existing Jira path untouched; False → a local-only helper that mutates sprint YAML with NO `get_client()`/`check_availability()`. Reuse `transition_story(root, id, target)` for the status change — it already skips Jira via its `if jira_key:` guard, so don't reimplement YAML writes. transition_story re-reads+writes internally, so set sibling fields (e.g. `assigned_to`) on a FRESH `read_sprint` AFTER it returns, else its write clobbers your in-memory change. Resolve identity with `get_current_user_email()` (local: JIRA_USER env → git config, no Jira). Block real conflicts by NAMING the assignee (never default to "unknown"). Return result dicts with `exit_code`, never raise (SOUL #10). `pf jira claim` (jira/cli.py) already had this gate; the bug was the *separate* sprint-level command.
</pattern>

<pattern name="delegate-to-existing-resolver">
When TEA flags a duplicate-resolver bug — function A computes X wrong while a sister B already computes X correctly (story 155-3/gh #28: `archive.py::archive_story`'s inline `jira_sprint_name` regex defaulting to `"unknown"` vs `archive_epic.py::get_archive_path`'s name→number→fail-loud from 151-1) — the MINIMAL green is delegation, not re-implementing B's logic inside A (that re-duplicates and violates SOUL #2 again). Three-edit shape: (1) add the top-level import; (2) replace A's resolver block with a call to B, passing the root you already resolved (`get_archive_path(project_root=root)`) so you don't double-resolve via `get_project_root`; (3) delete now-dead imports (`import re` was function-local — ruff flags it; the scoped test run won't). Bridge the contract mismatch: B *raises* `ValueError`, but `archive_story` returns result dicts everywhere (SOUL #10), so wrap — `try: ... except ValueError as e: return {"success": False, "error": str(e)}`. TEA's fail-loud test accepted either raise or result, so the result-object choice is honored without changing the test. Verify GREEN with the scoped new-file run PLUS the sibling tests of the function you reused (`test_get_archive_path.py`, `test_archive_epic.py`) — never the full suite (branch leak). Caller (`cli.py::archive_story`) needs no change: signature + result-dict contract preserved.
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
