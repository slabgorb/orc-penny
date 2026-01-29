# Story 66-3: Update siemulator-orchestrator to latest

**Story:** 66-3
**Workflow:** trivial
**Phase:** done
**Agent:** sm
**Repos:** siemulator
**Started:** 2026-01-29T23:00:00Z
**Completed:** 2026-01-29T23:15:00Z

## Story Details

Update siemulator-orchestrator to latest @pennyfarthing/core version (currently 8.0.4).

## Acceptance Criteria

- [x] npm install @pennyfarthing/core@latest
- [x] Run pennyfarthing init
- [x] Verify /sm agent loads correctly
- [x] Verify build passes

## Progress

### Step 1: Locate repo
- Found at ~/Projects/siemulator
- Current version: @pennyfarthing/core v7.8.3 (GitHub install)
- Had old-style symlinks and legacy dependencies

### Step 2: Clean upgrade to latest
- Stashed existing WIP changes
- Restored clean state
- npm install @pennyfarthing/core@latest → 8.0.4
- npx pennyfarthing init → success (auto-migrated sidecars)

### Step 3: Cleanup
- Removed old pennyfarthing/pennyfarthing-monorepo dependencies
- Updated .gitignore for new runtime paths

### Step 4: Verification
- ✅ `/sm` agent loads correctly
- ✅ manifest.json shows version 8.0.4
- ✅ Sidecars migrated to .pennyfarthing/sidecars/

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `package.json` - Updated to @pennyfarthing/core@^8.0.4, removed legacy deps
- `package-lock.json` - Updated dependency tree
- `.gitignore` - Updated for new runtime paths
- `.claude/` - Commands and skills as files instead of symlinks
- `.pennyfarthing/` - New structure with sidecars

**PR:** #11 - chore: update @pennyfarthing/core to 8.0.4
**Branch:** chore/66-3-update-pennyfarthing-latest (merged)

**Status:** DONE
