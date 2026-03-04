---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-15: Delete Dead Shell/Python Scripts That Duplicate pf CLI

## Business Context

The pennyfarthing framework accumulated shell and Python scripts over its evolution that are now fully superseded by `pf` CLI subcommands. These dead scripts create three problems: they mislead agents and developers into using the wrong interface, they carry maintenance surface area that drifts from the canonical implementation, and they represent the pattern the tech debt audit is explicitly designed to eliminate. This is a 1-point chore with no user-visible impact — pure housekeeping that makes the codebase unambiguous about the right entry point for each operation.

`get-workflow-type.py` already carries an explicit deprecation notice in the companion `.sh` wrapper. `check-context.sh` self-announces deprecation on stderr. `validate-subagent-frontmatter.sh` duplicates a strict subset of `validate-agent-schema.sh`, which itself overlaps with `pf validate agent`. `backlog.sh` duplicates `pf sprint backlog` (also available as `pf backlog`). The `output_persona()` function in `agent-session.sh` is dead: the `start` action now delegates entirely to `pf prime`, and `refresh` is the only internal caller — but `pf prime` handles persona loading via `pf/prime/persona.py`.

## Technical Guardrails

**Files to delete:**
- `pennyfarthing/pennyfarthing-dist/scripts/misc/backlog.sh` — duplicates `pf sprint backlog` / `pf backlog`
- `pennyfarthing/pennyfarthing-dist/scripts/workflow/get-workflow-type.py` — duplicates `pf workflow type`, already deprecated; the `.sh` wrapper at `scripts/workflow/get-workflow-type.sh` calls `pf workflow type` directly and is tracked by `test_wrapper_removal.py`
- `pennyfarthing/pennyfarthing-dist/scripts/core/check-context.sh` — explicitly self-deprecated; duplicates `pf context`
- `pennyfarthing/pennyfarthing-dist/scripts/misc/validate-subagent-frontmatter.sh` — strict subset of `scripts/validation/validate-agent-schema.sh` (577 lines), which itself overlaps with `pf validate agent`

**Dead function to remove:**
- `output_persona()` in `pennyfarthing/pennyfarthing-dist/scripts/core/agent-session.sh` (lines 102–198) and its sole call site in the `refresh` case (line 375). The `refresh` case should either be removed entirely or reduced to a stub that tells the user to use `pf prime`.

**Known stale references (must update, not just delete):**
- `pennyfarthing/pennyfarthing-dist/agents/templates/agent-template-tactical.md` line 124: references `check-context.sh` — update to `pf context`
- `pennyfarthing/pennyfarthing-dist/patterns/approval-gates-pattern.md` line 407: references `check-context.sh` — update to `pf context`
- `pennyfarthing/pennyfarthing-dist/patterns/tdd-flow-pattern.md` line 304: references `check-context.sh` — update to `pf context`
- `pennyfarthing/pennyfarthing-dist/scripts/core/README.md`: remove `check-context.sh` entry
- `pennyfarthing/pennyfarthing-dist/scripts/misc/README.md`: remove `backlog.sh` and `validate-subagent-frontmatter.sh` entries
- `pennyfarthing/pennyfarthing-dist/src/pf/hooks/__init__.py` line 254: comment references `check-context.sh` — update to reference `pf context`

**pf CLI equivalents (must remain working):**
- `pf sprint backlog` (also `pf backlog`) → replaces `backlog.sh`
- `pf workflow type <name>` → replaces `get-workflow-type.py`
- `pf context` → replaces `check-context.sh`
- `pf validate agent` → replaces `validate-subagent-frontmatter.sh`
- `pf prime --agent <name>` → already handles persona; replaces `output_persona()`

**Caller verification:** As of audit, no active scripts in `pennyfarthing-dist/` call `backlog.sh`, `get-workflow-type.py`, `validate-subagent-frontmatter.sh`, or `output_persona()` directly. `check-context.sh` is referenced only in documentation/pattern files (not invoked by any hook or runtime script). The `.sh` wrapper `get-workflow-type.sh` is tracked by `test_wrapper_removal.py` as a deprecated wrapper — it is NOT being deleted; only the `.py` script is.

**Test file note:** `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_wrapper_removal.py` references `get-workflow-type.sh` (the shell wrapper) in `TestDeprecatedWrappersClean.DEPRECATED_WRAPPERS`. It does NOT reference `get-workflow-type.py`. No test changes required for the `.py` deletion.

**Repo:** All changes are in `pennyfarthing/pennyfarthing-dist/`. Commit goes to `pennyfarthing/` repo targeting `develop`.

## Scope Boundaries

**In scope:**
- Delete `scripts/misc/backlog.sh`
- Delete `scripts/workflow/get-workflow-type.py`
- Delete `scripts/core/check-context.sh`
- Delete `scripts/misc/validate-subagent-frontmatter.sh`
- Remove `output_persona()` function body and its `refresh` call site from `scripts/core/agent-session.sh`
- Update all documentation references from deleted scripts to their `pf` CLI equivalents
- Remove deleted script entries from README files in their respective script subdirectories

**Out of scope:**
- `scripts/workflow/get-workflow-type.sh` — this is the deprecated shell wrapper tracked by `test_wrapper_removal.py`; leave it
- `scripts/validation/validate-agent-schema.sh` — the superset validator; leave it
- `pf validate agent` Python implementation — leave it
- The `refresh` command verb in `agent-session.sh` may be kept as a stub pointing to `pf prime`, or removed; either is fine, but do not leave `output_persona()` code behind
- Any changes to `pf` CLI commands themselves
- Any changes outside `pennyfarthing/pennyfarthing-dist/`

## AC Context

**AC: Listed scripts deleted or dead functions removed**

Test: After deletion, `git status` in `pennyfarthing/` shows the four files removed. `agent-session.sh` no longer contains the string `output_persona`. Verify with `grep -r "output_persona" pennyfarthing-dist/` returns no results.

Red test (write first): A test asserting these four file paths do not exist under `pennyfarthing-dist/scripts/`. Can be added to the existing `test_wrapper_removal.py` file or a new `test_dead_scripts.py`. Pattern: `assert not path.exists(), f"Dead script should be deleted: {path}"`.

**AC: No remaining callers reference deleted scripts**

Test: `grep -r "backlog\.sh\|get-workflow-type\.py\|check-context\.sh\|validate-subagent-frontmatter\.sh" pennyfarthing-dist/` returns no hits in any `.sh`, `.py`, `.md`, `.yaml`, `.ts`, or `.js` file. Stale README entries and pattern file references must be cleaned up before this passes.

Red test: A test scanning all distributed files for references to the deleted script names. Similar to `test_wrapper_removal.py`'s approach — collect violations, assert empty list.

**AC: pf validate, pf sprint backlog, pf workflow type, pf context still work**

Test: Run each command in the integration test environment and assert exit code 0:
- `pf sprint backlog` — should list backlog stories without error
- `pf backlog` — sugar alias for the above; same assertion
- `pf workflow type tdd` — should return `"phased"` or `"stepped"`; assert output is non-empty and exit 0
- `pf context` — should return context percentage output; assert exit 0
- `pf validate agent` — should complete agent validation; assert exit 0

These are smoke tests to catch regressions — the deleted scripts were NOT the implementation, so these commands should continue working unchanged. If any fail, the issue is a pre-existing bug unrelated to this story, not a regression introduced here.
