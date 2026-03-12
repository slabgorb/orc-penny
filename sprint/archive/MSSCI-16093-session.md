# Story 140-3: Extend Session Tooling for Unit Status Updates

**Jira:** MSSCI-16093
**Epic:** 140 — Batch Execution & Tracking
**Points:** 1
**Repos:** pennyfarthing
**Branch:** chore/140-3-extend-session-tooling-unit-status
**Workflow:** trivial
**Phase:** finish
**Assigned:** Keith Avery

## Acceptance Criteria

### AC 1: Command accepts `--unit` and `--status` flags
**Testable:** `pf workflow fix-phase 140-1 --unit 2 --status completed` runs without error

- `--unit` accepts numeric ID (1, 2, ..., N)
- `--status` accepts: `pending`, `in_progress`, `completed`, `failed`
- Both flags required when unit-mode is used (can't have one without the other)
- Command returns success message with unit ID and new status

### AC 2: Updates single unit without clobbering others
**Testable:** After running command, only target unit's status changes; all others remain unchanged

- Unit 1 remains unchanged
- Unit 2 status updated correctly
- Unit 3 remains unchanged

### AC 3: Validates unit exists and status value
**Testable:** Command rejects invalid unit ID or status with clear error message

- `pf workflow fix-phase 140-1 --unit 99 --status completed` → Error: "Unit 99 not found"
- `pf workflow fix-phase 140-1 --unit 2 --status invalid` → Error: "Invalid status. Must be one of: pending, in_progress, completed, failed"

### AC 4: Preserves all unit attributes except status
**Testable:** pr, branch, id, and unit text content remain unchanged after status update

- All attributes except status preserved
- Unit text content unchanged
- XML structure intact

### AC 5: Uses atomic file update (no corruption risk)
**Testable:** File update is atomic; session file never in partially-written state

- Write to temp file in same directory
- Rename temp → target (atomic on POSIX)
- Never edit in place
- Cleanup temp on error

## Technical Approach

Extend the existing `pf workflow fix-phase` command in `src/pf/workflow/cli.py` to accept optional `--unit` and `--status` flags. When these flags are provided, use regex-based atomic file update to replace the status attribute of the specified unit in the `<units>` XML element without affecting other units or file structure. Follow the same atomic file pattern (temp file + rename) used by the existing fix-phase implementation.

Key implementation points:
1. Add Click options for `--unit` (int) and `--status` (str)
2. Validate unit ID exists and status is in the allowed set
3. Use regex pattern to find and replace: `<unit id="N" status="old_status"` → `<unit id="N" status="new_status"`
4. Preserve all other unit attributes and XML structure
5. Write to temp file, validate, rename atomically

## SM Assessment

Story setup complete. 1-point trivial workflow — ready for development. Routes to Keith Avery (Dev).

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/workflow/cli.py` — Added `--unit`/`--status` options to `fix-phase` command with argument validation, unit XML regex matching, and atomic file write (temp + rename)

**Tests:** Manual verification — all 5 ACs confirmed:
- AC1: `--unit 2 --status completed` runs without error, returns success
- AC2: Only target unit status changes; others preserved
- AC3: Invalid unit ID → "Unit 99 not found"; invalid status → error with valid values; missing pair → "must be used together"
- AC4: Branch, PR, text content all preserved after update
- AC5: Atomic write via `tempfile.mkstemp` + `os.rename`; cleanup on error

**Branch:** `chore/140-3-extend-session-tooling-unit-status` (pushed, commit `ca662fdb7`)

**Handoff:** To Reviewer (Chrisjen Avasarala) for re-review

### Dev Fix (post-rejection)
- Reset local `develop` to `origin/develop` (unpushed commit removed)
- Cherry-picked `e08637632` → `ca662fdb7` onto feature branch
- Pushed feature branch — now 1 commit ahead of develop
- Branch ready for PR creation

## Delivery Findings

<!-- delivery-findings-marker -->
### Dev (implementation)
- **Gap** (non-blocking): Story 140-2 schema docs for `<units>` element never landed on `develop` branch despite story being marked done. Schema file has no unit references. Affects `pennyfarthing-dist/schemas/session-schema.md` (needs merge or re-implementation).

### Reviewer (code review)
- **Gap** (resolved): Commit originally landed on `develop` instead of feature branch. Dev fixed by resetting develop and cherry-picking onto feature branch (`ca662fdb7`). *Found by Reviewer during code review.*

---

## Reviewer Assessment (Re-review)

**Verdict:** APPROVED

**Previous review:** REJECTED — commit on wrong branch (HIGH). Resolved by Dev.

**Data flow traced:** `--unit N --status S` → Click type validation (int/str) → enum check against `("pending", "in_progress", "completed", "failed")` → regex search in session file → `unit_pattern.sub()` replacement → atomic write via `tempfile.mkstemp` + `os.rename`. Safe — no user input reaches shell execution, int validation prevents regex injection.

**Pattern observed:** Good atomic write pattern at `pennyfarthing-dist/src/pf/workflow/cli.py:886-898` — `mkstemp` in same dir ensures same filesystem for atomic rename. Cleanup in nested try/except on failure.

**Error handling:** All error paths emit to stderr and raise `SystemExit(1)` — missing flags, invalid status, unit not found, session file not found. Verified at lines 822-838.

**Observations:**
1. [VERIFIED] Regex matches schema-defined XML attribute order (`id` before `status`)
2. [VERIFIED] Input validation covers all AC3 error cases
3. [VERIFIED] Atomic write follows AC5 spec (temp + rename, cleanup on error)
4. [MEDIUM] No automated tests — consistent with existing phase mode code, non-blocking
5. [LOW] Whitespace normalization between XML attributes (cosmetic)
6. [LOW] `mkstemp` 0600 permissions vs original file (inconsequential for session files)

**Handoff:** To Camina Drummer (SM) for finish-story

---

## Handoff History

| Phase | Assigned | Status | Notes |
|-------|----------|--------|-------|
| setup | Keith Avery | completed | SM-setup: Session file created, branch initialized |
| implement | Keith Avery | completed | Dev: 1 file changed, 93 insertions |