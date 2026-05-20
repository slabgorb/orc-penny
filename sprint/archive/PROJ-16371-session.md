# 143-13: PreToolUse hooks for branch protection

**Story:** 143-13
**Jira:** PROJ-16371
**Status:** in_progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** feat/143-13-pretooluse-hooks-branch-protection

## Acceptance Criteria
- PreToolUse hooks enforce branch protection rules
- Hooks prevent commits/pushes to protected branches (main, develop) during agent work
- Hooks integrate with existing hook infrastructure in pennyfarthing-dist/src/pf/hooks/

## Context
Part of epic 143 (native agent infrastructure). Adds PreToolUse hooks that check branch protection before allowing git operations.

## SM Assessment
Setup complete. 2-point trivial story — straight to Dev. Branch created on develop, session ready. Routing to Naomi for implementation.

## Design Deviations

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found. Dev's "no deviations" claim is accurate — implementation matches ACs directly.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/hooks/branch_protection.py` - New PreToolUse hook blocking git commit/merge/rebase on protected branches and git push to protected branches
- `pennyfarthing-dist/src/pf/hooks/dispatch.py` - Registered branch-protection in dispatch registry matching Bash tool
- `pennyfarthing-dist/src/pf/hooks/cli.py` - Added CLI command for standalone invocation
- `pennyfarthing-dist/src/pf/tests/test_143_13_branch_protection.py` - 20 tests covering all ACs

**Tests:** 20/20 passing (GREEN)
**Branch:** feat/143-13-pretooluse-hooks-branch-protection (pushed)

**Handoff:** To Reviewer for code review

## Delivery Findings

### Dev (implementation)
- **Improvement** (non-blocking): The sm-setup subagent pushed implementation code to the feature branch during setup — SM agents should never write code. The bad implementation was replaced via force push.
  Affects `pennyfarthing-dist/agents/sm-setup.md` (should reinforce no-code constraint for subagents).
  *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): Dead code `_CHECKOUT_PATTERN` at `branch_protection.py:31` — compiled regex never referenced in `main()`. Should be removed.
  Affects `pennyfarthing-dist/src/pf/hooks/branch_protection.py` (delete unused pattern).
  *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Performance — `find_project_root()`, YAML parse, and `subprocess.run` execute on every Bash tool call before checking if the command contains git. An early `"git" not in command` guard at line 111 would skip expensive work for non-git commands.
  Affects `pennyfarthing-dist/src/pf/hooks/branch_protection.py` (add early return).
  *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** stdin JSON → tool_name filter → command string → regex match against git commit/merge/rebase/push patterns → subprocess check of current branch → block with exit(2) or allow with exit(0). Safe — no user input reaches shell execution.

**Pattern observed:** Follows existing hook pattern from `pre_edit_check.py` — same stdin/JSON/exit-code contract, same fail-open design, same stderr messaging. Good consistency at `branch_protection.py:94-163`.

**Error handling:** Fail-open via `except Exception: pass` at `branch_protection.py:160-161` — consistent with framework convention. Subprocess timeout at 5s prevents hangs at `branch_protection.py:66`.

**Observations:**
1. [VERIFIED] All 3 ACs met — hook enforces protection, blocks commits/pushes, integrates with dispatch registry
2. [VERIFIED] Push target extraction handles flags, refspecs, delete refspecs correctly
3. [VERIFIED] 20 tests cover commit blocking, push blocking, feature branch allowlisting, tool filtering
4. [LOW] Dead code `_CHECKOUT_PATTERN` — non-blocking
5. [MEDIUM] Subprocess on every Bash call — non-blocking, bounded cost (~5ms)

**Subagent findings:** Preflight 20/20 pass, lint clean. Edge hunter confirmed refspec handling is correct, found no bypasses that reach production risk.

**Handoff:** To SM for finish-story