# Story 125-3: Replace TypeScript sprint-data.ts resolution with SprintContext

**Jira:** PROJ-15424
**Points:** 2
**Priority:** P1
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/PROJ-15424-replace-ts-sprint-data-with-sprintcontext
**Assignee:** slabgorb@gmail.com

## Acceptance Criteria
- sprint-data.ts uses SprintContext (via subprocess or shared logic)
- Orphan epic shard detection matches Python behavior
- Future initiative resolution matches Python behavior
- WebSocket broadcast still works with new data path

## Context
Replace sprint-data.ts independent resolution logic with SprintContext. TypeScript can either call resolve_sprint_context via subprocess or share the resolution algorithm. Eliminates the TS/Python divergence in shard merging and registry resolution.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core data resolution logic change — must verify context-aware paths

**Test Files:**
- `packages/cyclist/tests/125-3-sprint-context-resolution.test.ts` — 13 tests covering all 4 ACs

**Tests Written:** 13 tests covering 4 ACs
**Status:** RED (4 failing on assertions, 9 passing for parity/regression)

**Failing Tests (assertions — correct RED):**
1. AC1: should use resolved sprint file path instead of hardcoded default
2. AC1: should include registry metadata for non-default sprint context
3. AC3: should resolve future.yaml from SprintContext context_root
4. AC4: should preserve metrics calculation with resolved context

**Key Implementation Notes for Dev:**
- `sprint-data.ts:304` hardcodes `join(projectDir, 'sprint', 'current-sprint.yaml')` — must resolve via SprintContext
- `sprint-data.ts:305` hardcodes `join(projectDir, 'sprint', 'future.yaml')` — must use context_root
- SprintData output needs `_registry` field for non-default contexts (matches Python loader pattern)
- Python resolver at `pf/core/resolver.py` — can call via subprocess or reimplement in TS
- Tests mock both subprocess (execSync) and filesystem (readFileSync) — either approach works
- WebSocket consumers (`websocket.ts:944`, `:1633`) call `getSprintData(projectDir)` — signature unchanged

**Handoff:** To Ponder Stibbons (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/sprint-data.ts` — Added `resolveSprintContext()` with subprocess + shared-logic fallback, replaced hardcoded paths, added `_registry` to SprintData

**Tests:** 13/13 passing (GREEN)
**Branch:** feature/PROJ-15424-replace-ts-sprint-data-with-sprintcontext (pushed)

**Implementation Approach:**
- `resolveSprintContext()` tries Python subprocess first (`pf.sh sprint resolve-context --json`), falls back to reading `config.local.yaml` + `sprints.yaml` directly, then to default `current-sprint.yaml`
- `context_root` from resolved context used for `future.yaml` path
- `_registry` metadata added to output for non-default contexts (matches Python loader pattern)
- `getSprintData()` signature unchanged — WebSocket consumers unaffected

**Pre-existing Failures (not from this change):**
- 10 archived-epic tests failing due to prior archive path migration (commit a1da75133)
- 1 unrelated hook registration test

**Handoff:** To Granny Weatherwax (Reviewer) for code review

## TEA Verify Assessment

**GREEN State Verified:** Yes — 13/13 tests passing independently
**Test Quality:** Satisfactory

**Coverage Check:**
- AC1 (SprintContext resolution): 4 tests — subprocess, fallback, failure recovery, registry metadata
- AC2 (Epic shard parity): 4 tests — shard resolution, orphan handling, malformed YAML, double-prefix
- AC3 (Future initiative parity): 3 tests — context_root resolution, shard resolution, completed filtering
- AC4 (WebSocket compatibility): 2 tests — shape verification, metrics with resolved context

**Mock Isolation:** Proper — vi.mock hoisted, beforeEach/afterEach lifecycle, dynamic imports
**Edge Cases:** Covered — orphan refs, malformed YAML, subprocess failure, double-prefix prevention
**Regressions:** None introduced — pre-existing failures documented by Dev are unrelated

**Handoff:** To Granny Weatherwax (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `projectDir` → `resolveSprintContext()` → subprocess/config/default → `ResolvedSprintContext` → feeds `currentSprintPath`, `futurePath`, `sprintDir`. All paths null-safe via `??`.

**Pattern observed:** Three-tier fallback (subprocess → config files → default) at `sprint-data.ts:319-388`. Clean separation, each tier isolated by try/catch. Matches Python resolver priority chain.

**Error handling:** Empty `catch {}` at lines 348, 383 — intentional fallthrough for graceful degradation. Subprocess bounded by 5s timeout. JSON.parse wrapped in try/catch. Follows existing patterns in file.

**Wiring:** `getSprintData()` signature unchanged. `SprintData._registry` is optional — non-breaking. WebSocket consumers unaffected.

**Security:** Command at line 333 uses quoted static path, hardcoded args. No injection vector.

**Observations:**
| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [VERIFIED] | Data flow safe, null-guarded | `sprint-data.ts:319-388` | Three-tier resolution |
| [VERIFIED] | Interface non-breaking | `sprint-data.ts:86-91` | `_registry` optional |
| [VERIFIED] | Error handling correct | `sprint-data.ts:348,383` | Graceful degradation |
| [VERIFIED] | Security clean | `sprint-data.ts:333` | Static command, quoted path |
| [VERIFIED] | Conditional spread correct | `sprint-data.ts:627` | `is_default: false` logically sound |
| [MEDIUM] | Subprocess per call, no caching | `sprint-data.ts:333` | Doubles execSync overhead |
| [LOW] | Pre-existing console.log stubs | `sprint-data.ts:642,653` | Out of scope |

**Handoff:** To Captain Carrot (SM) for finish-story