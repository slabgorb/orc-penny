# Story: Deprecate sprint bash shims and migrate remaining scripts to Python

**Story ID:** deprecate-sprint-shims
**Jira:** pending
**Workflow:** trivial
**Phase:** finish
**Branch:** chore/deprecate-sprint-bash-shims
**Repos:** pennyfarthing
**Assigned:** claude
**Points:** 3

## Context

PR #716 migrated 6 bash scripts to thin shims delegating to `pf sprint` Python CLI commands. But:
1. The shims themselves are now dead code — nothing calls them, agents use `pf sprint` directly
2. The remaining bash scripts (`archive-story.sh`, `list-future.sh`, `new-sprint.sh`, `promote-epic.sh`, `sprint-status.sh`, `validate-sprint-yaml.sh`) still have real bash logic and should also be migrated to Python CLI commands
3. Agent definitions (`sm.md`, `sm-setup.md`) still reference `.sh` scripts instead of `pf sprint` commands

## Work Items

### 1. Remove 6 dead shim scripts
Delete from `pennyfarthing-dist/scripts/sprint/`:
- `available-stories.sh` (shim → `pf sprint backlog`)
- `check-story.sh` (shim → `pf sprint check`)
- `get-story-field.sh` (shim → `pf sprint story field`)
- `get-epic-field.sh` (shim → `pf sprint epic field`)
- `sprint-info.sh` (shim → `pf sprint info`)
- `sprint-metrics.sh` (shim → `pf sprint metrics`)

### 2. Migrate remaining bash scripts to Python CLI
Create `pf sprint` commands for:

| Bash Script | New Python Command | Notes |
|---|---|---|
| `archive-story.sh` | `pf sprint archive` | Archive completed story session |
| `list-future.sh` | `pf sprint future` | Show future initiatives/epics |
| `new-sprint.sh` | `pf sprint new` | Create new sprint YAML |
| `promote-epic.sh` | `pf sprint promote` | Move epic from future to current |
| `sprint-status.sh` | `pf sprint status` (exists) | Verify existing command covers this |
| `validate-sprint-yaml.sh` | `pf sprint validate` | Validate sprint YAML structure |

Business logic goes in Python using `loader.py`'s shard-aware functions. After migration, convert these scripts to thin shims or remove them.

### 3. Update agent definitions
- `sm.md:171` — `get-story-field.sh` → `pf sprint story field`
- `sm-setup.md:29` — `available-stories.sh` → `pf sprint backlog`
- `sm-setup.md:95` — `get-epic-field.sh` → `pf sprint epic field`

### 4. Update docs
- `pennyfarthing-dist/scripts/sprint/README.md` — Remove deleted scripts, add Python equivalents
- `docs/adr/0018-sprint-yaml-script-access.md` — Add migration status note

## Key Files

- `pennyfarthing/pennyfarthing_scripts/sprint/cli.py` — Sprint CLI commands (add new ones here)
- `pennyfarthing/pennyfarthing_scripts/sprint/loader.py` — Shard-aware YAML loading
- `pennyfarthing-dist/scripts/sprint/` — Bash scripts to remove/migrate
- `pennyfarthing-dist/agents/sm.md` — SM agent definition
- `pennyfarthing-dist/agents/sm-setup.md` — SM setup subagent definition

## Acceptance Criteria

- [ ] 6 shim scripts removed from `pennyfarthing-dist/scripts/sprint/`
- [ ] `pf sprint archive` command works (replaces `archive-story.sh`)
- [ ] `pf sprint future` command works (replaces `list-future.sh`)
- [ ] `pf sprint new` command works (replaces `new-sprint.sh`)
- [ ] `pf sprint promote` command works (replaces `promote-epic.sh`)
- [ ] `pf sprint validate` command works (replaces `validate-sprint-yaml.sh`)
- [ ] `sprint-status.sh` coverage verified in existing `pf sprint status`
- [ ] Remaining bash scripts converted to shims or removed
- [ ] Agent definitions reference `pf sprint` commands, not `.sh` scripts
- [ ] README.md and ADR-0018 updated

## Reviewer Assessment (Round 1)

**Verdict:** REJECTED
**PR:** #718

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | 7 deleted script references in command definition | `commands/sprint.md` (lines 23,38,62,81,93,101,109) | Update all `<run>` blocks to `pf sprint` CLI |
| [HIGH] | `list-future.sh` still referenced | `agents/sm.md:229` | Change to `pf sprint future` |
| [HIGH] | `sprint-status.sh` still referenced | `agents/workflow-status-check.md:26` | Change to `pf sprint status` |
| [MEDIUM] | `sprint-common.sh` sourced (guarded) | `scripts/hooks/post-merge.sh:26` | Audit if functions are still needed |
| [MEDIUM] | Deleted script refs in guide docs | `guides/xml-tags.md`, `guides/skill-schema.md`, `scripts/README.md` | Update examples |
| [LOW] | `new_sprint` uses raw f-string YAML | `cli.py` new_sprint() | Consider `write_sprint()` for consistency |

**Data flow traced:** `pf sprint epic promote` → `_resolve_epic_ref()` → reads shard YAML → collision check → `write_sprint()` (safe, atomic)
**Pattern observed:** Result-object returns in `archive.py` (good pattern) at `archive.py:50-95`
**Error handling:** `epic_promote` raises `ClickException` on missing epic, missing sprint file, invalid data (verified)
**CI:** build SUCCESS, lint SUCCESS, Python CLI benchmark SUCCESS

**Handoff:** Back to Dev for fixes on HIGH issues

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED
**PR:** #718

| Finding | Status | Verification |
|---------|--------|--------------|
| [VERIFIED] All 3 HIGH issues fixed | `commands/sprint.md`, `agents/sm.md:229`, `agents/workflow-status-check.md:26` | All 7+2 script refs → `pf sprint` CLI |
| [VERIFIED] MEDIUM: post-merge.sh sprint-common.sh removed | Dead source removed, functions self-contained in file | `extract_story_id`, `update_story_status`, `log_reconciliation` all defined locally |
| [VERIFIED] MEDIUM: Guide docs updated | `xml-tags.md:450,476`, `skill-schema.md:149,198`, `scripts/README.md:11,30` | All examples use `pf sprint` |
| [VERIFIED] LOW: new_sprint uses write_sprint | `cli.py:1717-1731` | Tested: produces valid YAML with all fields |
| [VERIFIED] Bonus fixes | `step-05-import-to-future.md:129`, `sprint-yaml-validation.sh:18` | Additional stale refs caught |
| [VERIFIED] No remaining deleted-script references | grep scan of all added lines | Clean |
| [VERIFIED] CLI loads correctly | `pf sprint new --help` | Import chain intact |

**Data flow traced:** `new_sprint()` → builds dict → `write_sprint()` → `_write_yaml_file()` (atomic write)
**Pattern observed:** Archive file still uses f-string YAML (acceptable — different schema, not handled by `write_sprint`)
**Error handling:** `write_sprint` validates Mapping type, raises TypeError on bad input
**CLI:** All commands load, help text renders correctly

**Handoff:** To SM for finish-story

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `commands/sprint.md` - Updated 7 `<run>` blocks from deleted .sh scripts to `pf sprint` CLI
- `agents/sm.md` - `list-future.sh` → `pf sprint future`
- `agents/workflow-status-check.md` - `sprint-status.sh` → `pf sprint status`
- `scripts/hooks/post-merge.sh` - Removed dead `sprint-common.sh` source (functions defined locally)
- `guides/xml-tags.md` - Updated example script references
- `guides/skill-schema.md` - Updated example script references
- `scripts/README.md` - Updated directory structure comments
- `scripts/hooks/sprint-yaml-validation.sh` - Updated see-also comment
- `workflows/step-05-import-to-future.md` - `promote-epic.sh` → `pf sprint epic promote`
- `pennyfarthing_scripts/sprint/cli.py` - `new_sprint()` now uses `write_sprint()` for consistency

**Tests:** N/A (doc/reference fixes only)
**PR:** #718 - chore/deprecate-sprint-bash-shims
**Branch:** chore/deprecate-sprint-bash-shims (pushed)

**Handoff:** To Reviewer for re-review
