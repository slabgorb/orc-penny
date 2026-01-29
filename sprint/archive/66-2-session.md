# Story 66-2: Update clip-orchestrator to latest

**Story:** 66-2
**Workflow:** trivial
**Phase:** done
**Agent:** sm
**Repos:** clip-orchestrator
**Started:** 2026-01-29T22:30:00Z
**Completed:** 2026-01-29T22:55:00Z

## Story Details

Update clip-orchestrator to latest @pennyfarthing/core version (currently 8.0.4).

## Acceptance Criteria

- [x] npm install @pennyfarthing/core@latest
- [x] Run pennyfarthing init
- [x] Verify /sm agent loads correctly
- [x] Verify build passes

## Progress

### Step 1: Locate repo
- Found at ~/Projects/clip-orchestrator
- Current version: @pennyfarthing/core@^7.8.4 (uncommitted)
- Has old-style symlinks in .pennyfarthing/

### Step 2: Clean upgrade to latest
- Stashed existing WIP changes
- Removed old .pennyfarthing, .claude, node_modules
- npm install @pennyfarthing/core@latest → 8.0.4
- npx pennyfarthing init → success

### Step 3: Migrate sidecars
- Old location: `.claude/project/agents/{agent}-sidecar/`
- New location: `.pennyfarthing/sidecars/{agent}/`
- Migrated all 10 agent sidecars with content preserved

### Step 4: Verification
- ✅ `/sm` agent loads correctly
- ✅ manifest.json shows version 8.0.4
- ✅ Symlinks point to @pennyfarthing/core package

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `package.json` - Added @pennyfarthing/core@^8.0.4
- `.gitignore` - Updated for new runtime paths
- `.claude/` - Updated config files
- `.pennyfarthing/` - New symlinks to package, migrated sidecars

**PR:** #1 - chore: update @pennyfarthing/core to 8.0.4
**Branch:** chore/66-2-update-pennyfarthing-latest (merged)

**Status:** DONE
