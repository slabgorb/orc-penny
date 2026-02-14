# Story 98-12: Git hook chaining with .d/ dispatcher pattern

**Jira:** MSSCI-15067
**Epic:** 98 (Safe Install, Upgrade, and Namespace Isolation)
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/98-12-git-hook-chaining-dispatcher
**Assignee:** Keith Avery
**Started:** 2026-02-14

## Context

This story is part of Epic 98, which redesigns the install/upgrade path to prevent data loss, automate post-update setup, add versioned migrations, namespace skills/commands with pf- prefix, and integrate sprint shard migration.

Story 98-12 focuses on implementing git hook chaining with a `.d/` dispatcher pattern. This is a P1 priority feature that supports the overall install/upgrade improvement initiative.

Key directories involved:
- `pennyfarthing/packages/core/` — CLI: init, update, doctor, uninstall
- `pennyfarthing/pennyfarthing-dist/` — Published package (source of truth)
- `pennyfarthing/pennyfarthing_scripts/` — Python scripts (hooks, sprint, jira)

## Acceptance Criteria

Implementation should:
- Establish git hook chaining architecture using a `.d/` dispatcher pattern
- Ensure hooks can be extended and composed without conflicts
- Support pre-commit, pre-push, and post-merge hooks
- Integrate with the framework's install/upgrade flow
- Maintain backward compatibility

## Technical Approach

This story involves designing and implementing a dispatcher pattern for git hooks that allows multiple hooks to be chained together in a `.d/` directory structure. This is part of the larger install/upgrade v2 initiative.

## SM Assessment

- Story set up and ready for TDD workflow
- Feature branches created in both repos
- Jira MSSCI-15067 moved to In Progress
- Routing to TEA for test design (red phase)
- 3-point story, full TDD ceremony

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `packages/core/src/cli/commands/hook-chaining.test.ts` — 21 tests covering all 5 ACs

**Tests Written:** 21 tests covering 5 acceptance criteria
**Status:** RED (20 failing, 1 passing — all assertion failures, no import/syntax errors)

**Test Coverage by AC:**
- **AC1 (Dispatcher architecture):** 5 tests — .d/ directory creation, dispatcher script installation, pennyfarthing hook placement, iteration logic, executability
- **AC2 (Extension/composition):** 4 tests — user hook preservation, idempotent re-install, stale hook updates, multi-tool coexistence
- **AC3 (All hook types):** 5 tests — pre-commit/pre-push/post-merge dispatchers, argument forwarding, stdin forwarding
- **AC4 (Install/upgrade integration):** 4 tests — template generation, dry-run behavior, missing sources, non-git repos
- **AC5 (Backward compatibility):** 3 tests — migrate existing pf hooks, migrate user hooks, idempotent upgrade, .backup handling

**Implementation Guidance for Dev:**
- Modify `installGitHooks()` in `packages/core/src/cli/commands/init.ts` to use `.d/` pattern
- Create a dispatcher script template (bash) that iterates `.d/` directory, runs executable scripts in sorted order, propagates exit codes, forwards args and stdin
- Use `pennyfarthing-dispatcher` marker in dispatcher for detection
- Use numeric prefixes for ordering (e.g., `10-pennyfarthing-pre-commit.sh`)
- Migrate existing single-file hooks (both pennyfarthing and user) into `.d/` on install
- Consider also updating `install-git-hooks.sh` for framework dev symlink mode

**Handoff:** To Dev for implementation (GREEN phase)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/commands/init.ts` — Rewrote `installGitHooks()` to use `.d/` dispatcher pattern with `generateDispatcher()` helper
- `pennyfarthing-dist/scripts/git/install-git-hooks.sh` — Updated framework dev script to use `.d/` pattern with symlinks

**Tests:** 28/28 passing (GREEN)
**PR:** #882 — feat(hooks): .d/ dispatcher pattern for git hook chaining (98-12)
**Branch:** feature/98-12-git-hook-chaining-dispatcher (pushed)

**Key design decisions:**
- Dispatcher generated inline via `generateDispatcher()` — no separate template file needed
- Numeric prefixes: `10-` for pennyfarthing hooks, `50-` for migrated user hooks
- Stdin captured once and piped to each hook (for pre-push ref forwarding)
- Existing hooks auto-detected: dispatchers recognized by marker, pf hooks by marker, user hooks migrated

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Dispatcher template duplicated between TS and bash — maintenance trap | `init.ts:272-318` + `install-git-hooks.sh:43-91` | Extract to shared template file at `pennyfarthing-dist/scripts/hooks/dispatcher-template.sh` — both paths read from single source |
| [MEDIUM] | Unused imports: `readdirSync`, `chmodSync` never used | `init.ts:1` | Remove unused imports |
| [MEDIUM] | Mixed fs API: uses `existsSync` when `pathExists` already imported | `init.ts:383-422` | Use `pathExists` consistently |

**Data flow traced:** source hook → `.d/` directory → dispatcher → execution (clean, no injection)
**Template escaping:** Verified correct — all bash vars survive JS interpolation
**Error handling:** Exit code propagation correct via `$?` check
**Backward compat:** Existing hooks properly migrated

**Handoff:** Back to Dev for fixes

## Dev Assessment (Round 2)

**Implementation Complete:** Yes — all reviewer issues addressed
**Files Changed:**
- `pennyfarthing-dist/scripts/hooks/dispatcher-template.sh` — NEW shared template (single source of truth)
- `packages/core/src/cli/commands/init.ts` — Reads template via `generateDispatcher(hookName, template)`, removed unused imports (`readdirSync`, `chmodSync`), replaced all `existsSync` with `pathExists`
- `pennyfarthing-dist/scripts/git/install-git-hooks.sh` — Replaced heredoc with `sed` substitution from shared template
- `packages/core/src/cli/commands/hook-chaining.test.ts` — Test creates dispatcher template in beforeEach

**Tests:** 28/28 passing (GREEN)
**PR:** #882 — updated with fixes
**Branch:** feature/98-12-git-hook-chaining-dispatcher (pushed)

**Reviewer Issues Resolved:**
- [HIGH] Dispatcher template extracted to `dispatcher-template.sh` — both TS and bash read from single source
- [MEDIUM] Removed unused imports `readdirSync`, `chmodSync`
- [MEDIUM] Replaced all `existsSync` with `pathExists` for consistent fs API usage

**Handoff:** To Reviewer for re-review

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

**Round 1 fixes verified:**
- [VERIFIED] Template deduplication — `dispatcher-template.sh` is single source of truth, both TS and bash read from it
- [VERIFIED] Unused imports removed — `readdirSync`, `chmodSync` gone from `init.ts`
- [VERIFIED] Consistent fs API — all `existsSync` replaced with `pathExists` in `installGitHooks`

**Additional observations:**
- [VERIFIED] Data flow traced: template file → `readFileSync` → `replace(/__HOOK_NAME__/g)` → `writeFileSync` with 0o755. No injection vectors.
- [VERIFIED] Sed substitution in bash uses hardcoded hook names from HOOKS array. No user input.
- [VERIFIED] Error handling: bash has explicit template existence check; TS fails hard on missing template (acceptable for corrupt package).
- [VERIFIED] Exit code propagation correct via `$?` check with `set -uo pipefail`.
- [LOW] Unused `chmodSync` import in test file — cosmetic lint warning, not blocking.

**Tests:** 28/28 passing (GREEN)
**Forbidden patterns:** None
**Lint:** Clean (1 warning in test file, pre-existing errors in unrelated file)

**Handoff:** To SM for finish-story
