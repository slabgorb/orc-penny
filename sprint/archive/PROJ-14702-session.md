# Story 98-5: Sprint shard migration as versioned migration

## Story Details
- **ID:** 98-5
- **Jira Key:** PROJ-14702
- **Title:** Sprint shard migration as versioned migration
- **Epic:** epic-98 (Safe Install, Upgrade, and Namespace Isolation)
- **Points:** 3
- **Priority:** P1
- **Repos:** pennyfarthing
- **Workflow:** trivial
- **Assigned To:** kavery

## Description
Add migration that checks sprint/current-sprint.yaml format. If epics[0] is dict (monolithic), run shard extraction: split inline epics to epic-{ref}.yaml files, replace with string references. Leverages existing logic from sprint/migrate-to-shards.py. Include --dry-run support.

## Context
This story is part of Epic 98 (Safe Install, Upgrade, and Namespace Isolation) - PROJ-14697. The epic redesigns the install/upgrade path to prevent data loss, automate post-update setup, add versioned migrations, namespace skills/commands with pf- prefix, and integrate sprint shard migration.

### Precursor Stories (Completed)
- 98-1: Version sentinel file and auto-update detection (DONE)
- 98-2: Versioned migration runner infrastructure (DONE)
- 98-3: Refactor update.ts inline migrations to migration files (DONE)
- 98-4: Prefix built-in skills and commands with pf- (DONE)

### Related Implementation
- **Existing Python Migration Script:** `sprint/migrate-to-shards.py` contains the shard extraction logic
- **Migration Infrastructure:** `pennyfarthing-dist/migrations/` directory with numbered migration files (from 98-2)
- **Update.ts:** Runner in `packages/core/` invokes migrations during update

## Acceptance Criteria
1. Create versioned migration file in `pennyfarthing-dist/migrations/` that:
   - Checks sprint/current-sprint.yaml format
   - Detects monolithic format (epics[0] is dict)
   - Extracts and splits inline epics to `epic-{ref}.yaml` files
   - Replaces with string references
   - Leverages existing logic from `sprint/migrate-to-shards.py`
   - Includes `--dry-run` support for testing

2. Integration with migration runner:
   - Migration registers with runner
   - Properly updates manifest on successful run
   - Handles errors gracefully

3. Testing:
   - Test monolithic -> sharded conversion
   - Test dry-run mode
   - Test idempotency (re-running doesn't duplicate)

## Workflow Tracking
**Workflow:** trivial
**Phase:** review
**Phase Started:** 2026-02-14T06:35:38Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-14T06:07:15Z | 2026-02-14T06:07:30Z | 15s |
| implement | 2026-02-14T06:07:30Z | 2026-02-14T06:35:38Z | 28m |

## Handoff Log

### SM → Dev (Setup → Implement)
**Timestamp:** 2026-02-14T06:07:30Z
**From:** Stilgar (SM)
**To:** Reverend Mother Gaius Helen Mohiam (Dev)

**Context:** Story setup complete. Trivial workflow — Dev implements versioned migration for sprint shard extraction. Include --dry-run support. Leverages existing sprint/migrate-to-shards.py logic.

**Deliverables:**
- Versioned migration file in pennyfarthing-dist/migrations/
- Checks sprint/current-sprint.yaml format
- Detects monolithic format (epics[0] is dict)
- Extracts and splits inline epics to epic-{ref}.yaml files
- Replaces with string references
- Includes --dry-run support
- Tests: monolithic→sharded, dry-run mode, idempotency

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/migrations/008-sprint-shard-migration.js` — Migration: detects monolithic format, extracts epics to shard files, replaces with string refs
- `pennyfarthing-dist/migrations/008-sprint-shard-migration.d.ts` — Type definitions for test import
- `packages/core/src/cli/utils/008-sprint-shard-migration.test.ts` — 14 tests covering conversion, dry-run, idempotency, edge cases

**Tests:** 14/14 passing (GREEN)
**PR:** #865 — feat(98-5): sprint shard migration as versioned migration
**Branch:** feature/98-5-sprint-shard-migration (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** sprint/current-sprint.yaml → parse → extract epics → atomicWrite shard files → update index (safe: only `data.epics` mutated, all other keys preserved through round-trip)
**Pattern observed:** Atomic write via tmp+rename at `008-sprint-shard-migration.js:51-60` — matches Python script's safety pattern
**Error handling:** Missing sprint dir → graceful skip (L67-69). Missing epic id → warning + skip (L94-96). Partial failure → existsSync guard prevents duplicate shard files (L109)
**Idempotency:** Double-checked via `check()` (L148) AND `up()` early return (L83). Both verified correct.
**Low observations:** No backup before mutation (consistent with 001-007). Mixed-format edge case handled safely.

**Handoff:** To SM for finish-story

## Handoff History

| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| implement (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-14T06:35:38Z |
