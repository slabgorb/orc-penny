# Story 126-4: Remove uv/pf.sh wrapper chain — global pf invoked directly
**Jira:** PROJ-15492
**Epic:** PROJ-15488
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/PROJ-15492-remove-uv-pf-wrapper-chain
**Assigned:** keith.avery@slabgorb.io

## Description
Remove run-pf.sh, pf.sh wrapper, and all uv-based invocation logic. All hooks and scripts call pf directly (globally installed). Update settings.local.json hook commands, agent definitions, and any shell scripts that use the wrapper chain.

## Acceptance Criteria
- run-pf.sh removed
- pf.sh wrapper removed
- All hook commands reference bare pf (not wrapper)
- No uv references remain in runtime code
- All agent activation commands updated

## Context
This story is part of the Installation epic (PROJ-15488) — simplifying pf installation by removing the uv/wrapper indirection layer. After this story, `pf` is invoked directly as a globally installed command.

---
## SM Assessment (setup)

Story 126-4 claimed in Jira, branch `feature/PROJ-15492-remove-uv-pf-wrapper-chain` created from `develop`. This is a 2-point removal/cleanup story — audit all `pf.sh`, `run-pf.sh`, and `uv run` references, replace with direct `pf` calls, then delete the wrapper scripts. Context file written at `sprint/context/context-126-4.md` with key files and approach. Workflow is TDD — Igor (TEA) writes failing tests first, then Ponder (Dev) implements.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Removal story needs verification that all wrapper references are gone

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_wrapper_removal.py` — 12 tests covering all 5 ACs

**Tests Written:** 12 tests covering 5 ACs
- AC1 (run-pf.sh removed): 1 test
- AC2 (pf.sh removed): 1 test
- AC3 (hook shims clean): 3 tests (no source, no exec_pf, no uv run)
- AC4 (no uv in runtime): 4 tests (no source, no exec_pf, no run_pf, no uv run in any .sh)
- AC5 (agent defs updated): 2 tests (agent .md files, agent-behavior guide)
- Bonus: deprecated wrappers clean: 1 test

**Status:** RED (12/12 failing on assertions — ready for Dev)

**Handoff:** To Ponder Stibbons (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `scripts/lib/run-pf.sh` — deleted (AC1)
- `scripts/core/pf.sh` — deleted (AC2)
- `scripts/hooks/*.sh` (11 files) — replaced wrapper source+exec_pf with direct `exec pf` (AC3)
- `scripts/core/agent-session.sh` — removed run-pf.sh source, use bare `pf` (AC4)
- `scripts/core/prime.sh` — replaced wrapper with direct `exec pf` (AC4)
- `scripts/core/phase-check-start.sh` — replaced wrapper with direct `exec pf` (AC4)
- `scripts/misc/statusline.sh` — replaced wrapper with direct `exec pf` (AC4)
- `scripts/theme/list-themes.sh` — replaced run_pf calls with bare `pf` (AC4)
- `scripts/workflow/*.sh` (8 files) — replaced wrapper with direct `exec pf` (AC4)
- `scripts/git/*.sh` (4 files) — replaced wrapper with direct `exec pf` (AC4)
- `agents/sm.md`, `agents/sm-setup.md`, `agents/tea.md`, `agents/dev.md`, `agents/reviewer.md` — replaced pf.sh wrapper path with bare `pf` (AC5)
- `guides/agent-behavior.md` — updated wrapper instructions, exit protocol, wrong-phase-detection to use bare `pf` (AC5)

**Tests:** 12/12 passing (GREEN)
**Branch:** feature/PROJ-15492-remove-uv-pf-wrapper-chain (pushed)

**Handoff:** To Granny Weatherwax (Reviewer) for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [CRITICAL] | 12 command files still source deleted `run-pf.sh` — agent activation broken | `commands/pf-*.md:8` | Replace `source run-pf.sh && run_pf agent start` with `pf agent start` |
| [CRITICAL] | `init/core.py` generates hooks pointing to deleted `pf.sh` | `src/pf/init/core.py:25-65` | Replace `pf.sh hooks` with `pf hooks` |
| [CRITICAL] | Settings template references deleted `pf.sh` | `templates/settings.local.json.template:43-163` | Replace all `pf.sh` paths with bare `pf` |
| [HIGH] | `list-workflows.sh` still sources deleted `run-pf.sh` | `scripts/workflow/list-workflows.sh:4-5` | Replace with `exec pf workflow list` |
| [MEDIUM] | `agent-tag-taxonomy.md` references `pf.sh` path | `guides/agent-tag-taxonomy.md:178` | Update to bare `pf` |
| [MEDIUM] | `xml-tags.md` references `pf.sh` path | `guides/xml-tags.md:135` | Update to bare `pf` |

**Root cause:** Tests enumerate specific files but don't cover commands/, init/core.py, templates/, or list-workflows.sh. Dev followed the tests, not the ACs.

**Handoff:** Back to Dev for fixes

## Dev Assessment (round 2)

**Implementation Complete:** Yes — all reviewer findings addressed
**Additional Files Changed:**
- `commands/pf-*.md` (13 files) — replaced `source run-pf.sh && run_pf` with bare `pf`
- `src/pf/init/core.py` — replaced pf.sh hook commands with bare `pf`
- `templates/settings.local.json.template` — replaced pf.sh hook commands with bare `pf`
- `scripts/workflow/list-workflows.sh` — replaced wrapper with `exec pf`
- `guides/agent-tag-taxonomy.md` — updated pf.sh path to bare `pf`
- `guides/xml-tags.md` — updated pf.sh path to bare `pf`

**Tests:** 12/12 passing (GREEN)
**Branch:** feature/PROJ-15492-remove-uv-pf-wrapper-chain (pushed)
**Verification:** Full grep of pennyfarthing-dist/ confirms zero remaining wrapper references (outside test file)

**Handoff:** To Granny Weatherwax (Reviewer) for re-review

## Reviewer Assessment (round 2)

**Verdict:** APPROVED

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | Wrapper chain fully removed (pf.sh, run-pf.sh deleted) | `scripts/core/`, `scripts/lib/` |
| 2 | [VERIFIED] | All 11 hook shims call bare `exec pf hooks ...` | `scripts/hooks/*.sh` |
| 3 | [VERIFIED] | `verify_pf_cli()` catches stale shims before writing hooks | `core.py:98-159` |
| 4 | [LOW] | Redundant `import shutil as _shutil` inside verify_pf_cli (already imported at module level) | `core.py:108` |
| 5 | [MEDIUM] | `step-01-discover.md` instructs users to REMOVE global pf (now opposite of correct) | `workflows/project-setup/steps/step-01-discover.md:29-64` |
| 6 | [VERIFIED] | `detect_package_manager` parent walk-up has correct stop condition | `setup.py:262-269` |
| 7 | [VERIFIED] | `install_node_packages` validates input, rejects unknown managers | `setup.py:296-300` |
| 8 | [VERIFIED] | `discover_repos` return format change has no downstream breakage | `setup.py:127` |
| 9 | [VERIFIED] | Settings template: all 12 hook entries converted to bare `pf` | `templates/settings.local.json.template` |
| 10 | [VERIFIED] | 121 tests pass (20 wrapper + 55 init + 46 auto-setup) | Full suite GREEN |

**Data flow:** `pf init` → `verify_pf_cli()` (subprocess) → gates hook writes. Safe.
**Error handling:** TimeoutExpired, OSError, non-zero returncode all handled with install hint.

**Handoff:** To Captain Carrot (SM) for finish-story

---
## Work Log