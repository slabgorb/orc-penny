# Session: MSSCI-14372 — Update doctor to validate new file layout

**Story:** MSSCI-14372
**Epic:** MSSCI-14364 (Clean Install Consolidation)
**Jira:** MSSCI-14372
**Workflow:** tdd
**Phase:** approved
**Branch:** feat/MSSCI-14372-doctor-file-layout
**Repos:** pennyfarthing

---

## Acceptance Criteria

- [ ] Doctor checks files are in correct `.pennyfarthing/` locations
- [ ] Doctor flags old `.claude/` locations with migration instructions
- [ ] `--fix` migrates files automatically
- [ ] Existing doctor checks preserved (Cyclist spawn-helper, legacy statusline, etc.)
- [ ] New check category: "File Layout" or "Namespace"

## Context

Epic context: `sprint/context/context-epic-MSSCI-14364.md`

### Key Files
- Modify: `packages/core/src/cli/commands/doctor.ts`

### Technical Approach
- Add new check category for file layout validation
- Each check: "file X should be at .pennyfarthing/Y, found at .claude/Z"
- Fix function: move file + create symlink if needed
- Preserve all existing checks
- Check manifest at `.pennyfarthing/manifest.json`
- Check settings.local.json symlink validity
- Check persona config at `.pennyfarthing/config.local.yaml`

### Dependencies
- MSSCI-14369 (sidecars) — DONE
- MSSCI-14370 (init) — DONE
- MSSCI-14371 (update) — DONE

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** New check function with file system operations, fix migrations, and category naming

**Test Files:**
- `packages/core/src/cli/commands/doctor-file-layout.test.ts` — 19 tests covering all 5 ACs

**Tests Written:** 19 tests covering 5 ACs

| Category | Tests | ACs Covered |
|----------|-------|-------------|
| Result naming | 1 | AC5 (layout/ prefix) |
| Manifest validation | 2 | AC1 (correct location) |
| Config validation | 4 | AC1, AC2, AC3 (pass/warn/fix) |
| Settings validation | 2 | AC1 (pass/fail) |
| Sidecars validation | 3 | AC1, AC2, AC3 (pass/warn/fix) |
| Project hooks validation | 3 | AC1, AC2, AC3 (pass/warn/fix) |
| Edge cases | 4 | AC3, AC4 (empty dir, dual locations, no collisions, safe overwrite) |

**Status:** RED (19 failing — `checkFileLayout not implemented`)

**Implementation notes for Dev:**
- New exported function `checkFileLayout(projectRoot: string): CheckResult[]` in `doctor.ts`
- Stub exists (throws) — replace with implementation
- Results must use `layout/` prefix for category display
- Wire into `doctorCommand()` alongside existing checks
- Add `{ name: 'File Layout', filter: (r) => r.name.startsWith('layout/') }` to categories array
- Fix functions must not overwrite existing files at new locations

**Handoff:** To Dev for implementation

---

## Dev Assessment

**Implementation:** `checkFileLayout()` in `doctor.ts` — 140 lines added
**PR:** #712 (https://github.com/1898andCo/pennyfarthing/pull/712)
**Tests:** 19/19 GREEN
**Pre-existing failures:** 3 doctor-legacy tests (statusline path format) — not in diff

**Changes:**
- Replaced stub with full implementation of `checkFileLayout(projectRoot)`
- 8 layout checks: manifest, config, settings, sidecars, project-hooks (each with old-location detection)
- Fix functions: `renameSync` for moves, `ensureDirSync` for dirs, safe no-overwrite guard
- Wired into `doctorCommand()` pipeline and added "File Layout" category to display
- Uses existing `pathExists`, `isDirectory`, `ensureDirSync`, `removeSync` from codebase

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `existsSync(path)` → result status → fix closures capture correct path variables at definition time, no stale refs
**Pattern observed:** Fix safety guards (`!existsSync(dest)` before rename/copy) consistent at `doctor.ts:1757,1807,1842`
**Error handling:** try/catch on `readdirSync` at `doctor.ts:1819,1847` — matches existing patterns, cleanup failures non-critical
**Edge cases verified:** Empty dir (returns array), dual locations (both flagged correctly), no-overwrite guard tested

| Severity | Issue | Location | Notes |
|----------|-------|----------|-------|
| [MEDIUM] | Duplicate config detection with `checkLegacyFiles` | `doctor.ts:1751` vs `1493` | Different categories, both accurate. Legacy version has richer YAML parsing. |
| [MEDIUM] | Duplicate sidecar detection with `checkLegacyFiles` | `doctor.ts:1790` vs `1543` | Legacy version is safer (only removes if new exists). |
| [MEDIUM] | Duplicate hooks detection with `checkLegacyFiles` | `doctor.ts:1835` vs `1603` | Different granularity (dir vs specific file). |
| [LOW] | Unused `symlinkSync` import in test | `doctor-file-layout.test.ts:15` | Harmless. |
| [VERIFIED] | No forbidden patterns | — | No console.log, no secrets, no skipped tests |
| [VERIFIED] | Category wiring correct | `doctor.ts:83,101` | Layout runs before Legacy, display order logical |
| [VERIFIED] | 19/19 tests GREEN | — | Pre-existing 3 legacy failures not in diff |

**Note:** Duplication with `checkLegacyFiles` is a pre-existing architecture issue — new category was explicitly requested by ACs. Consolidation should be a separate story.

**Handoff:** To SM for finish-story
