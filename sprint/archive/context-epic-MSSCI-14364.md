# Epic 85: Clean Install Consolidation (MSSCI-14364)

## Overview

Move all Pennyfarthing-managed files under `.pennyfarthing/`, rework init to bootstrap then hand off to interactive workflow, rework update to migrate old layouts, and validate with end-to-end tests against real repos.

**Current state:** Files scattered across `.claude/` and `.pennyfarthing/` — manifest at `.claude/manifest.json`, persona config at `.claude/persona-config.yaml`, hooks at `.claude/project/hooks/`, commands/skills copied into `.claude/`
**Target state:** All Pennyfarthing-owned files live under `.pennyfarthing/` with symlinks only where Claude Code requires `.claude/` discovery

**Points:** 34

## Background

### The Problem

Pennyfarthing's installation creates and manages files in two namespaces:

| Location | What | Why |
|----------|------|-----|
| `.pennyfarthing/agents/` | Agent definitions (symlink) | Our namespace |
| `.pennyfarthing/guides/` | Behavior guides (symlink) | Our namespace |
| `.pennyfarthing/personas/` | Themed personas (symlink) | Our namespace |
| `.pennyfarthing/scripts/` | Utility scripts (symlink) | Our namespace |
| `.pennyfarthing/workflows/` | Workflow definitions (symlink) | Our namespace |
| `.pennyfarthing/sidecars/` | Agent learning files (writable) | Our namespace |
| `.claude/manifest.json` | Install metadata | Historical accident |
| `.claude/persona-config.yaml` | Theme selection | Historical — should be in our namespace |
| `.claude/settings.local.json` | Hook registration | **Required by Claude Code** |
| `.claude/commands/` | Slash commands | **Required by Claude Code** |
| `.claude/skills/` | Skill definitions | **Required by Claude Code** |
| `.claude/project/hooks/` | Setup scripts | Referenced by settings.local.json |

The split makes it hard to reason about what Pennyfarthing owns vs. user files. The update command already migrates sidecars from old locations but doesn't consolidate everything. Doctor checks existence but doesn't enforce canonical layout.

### Success Criteria (Epic-Level)

- All Pennyfarthing-managed files have canonical location under `.pennyfarthing/`
- Files that Claude Code must discover in `.claude/` use symlinks from `.pennyfarthing/` originals
- `pennyfarthing init` bootstraps then hands off to interactive setup
- `pennyfarthing update` migrates old layouts automatically
- `pennyfarthing doctor` validates the new layout and flags old-location files
- End-to-end tests prove fresh install and upgrade paths work

## Technical Architecture

### Where Code Lives

```
pennyfarthing/packages/core/src/cli/
├── commands/
│   ├── init.ts          # MODIFY: Rework for bootstrap + handoff
│   ├── update.ts        # MODIFY: Add file migration logic
│   └── doctor.ts        # MODIFY: Validate new layout, flag old locations
├── utils/
│   ├── manifest.ts      # MODIFY: Move manifest to .pennyfarthing/
│   ├── settings.ts      # MODIFY: Generate in .pennyfarthing/, symlink to .claude/
│   ├── symlinks.ts      # MODIFY: Update symlink targets
│   ├── constants.ts     # MODIFY: Update path constants
│   └── themes.ts        # EXISTING: Already prefers .pennyfarthing/config.local.yaml
```

### Existing Infrastructure

| Component | Location | Relevance |
|-----------|----------|-----------|
| `init.ts` | `commands/init.ts` (412 lines) | Creates dirs, symlinks, copies commands/skills, generates templates, writes manifest |
| `update.ts` | `commands/update.ts` (375 lines) | Version check, sidecar migration, re-symlink, settings merge, runs doctor |
| `doctor.ts` | `commands/doctor.ts` (1602 lines) | Validates manifest, symlinks, hooks, user files, directories, legacy files, Cyclist |
| `manifest.ts` | `utils/manifest.ts` (137 lines) | Read/write `.claude/manifest.json` with version, paths, installation type |
| `settings.ts` | `utils/settings.ts` (348 lines) | Merge hooks into settings.local.json, migrate legacy paths, register skills |
| `symlinks.ts` | `utils/symlinks.ts` (409 lines) | Create/verify directory symlinks, individual command/skill symlinks |
| `constants.ts` | `utils/constants.ts` | CORE_AGENTS list, DIRECTORY_SYMLINKS, ALL_SYMLINKS definitions |
| `themes.ts` | `utils/themes.ts` | Theme discovery, already reads `.pennyfarthing/config.local.yaml` first |

### Current File Layout (What Init Creates)

```
project/
├── .claude/
│   ├── manifest.json           # → MOVE to .pennyfarthing/
│   ├── persona-config.yaml     # → MOVE to .pennyfarthing/config.local.yaml
│   ├── settings.local.json     # → Generate in .pennyfarthing/, symlink here
│   ├── commands/               # Must stay (Claude Code discovery)
│   │   ├── sm.md → symlink     #   but originals move to .pennyfarthing/commands/
│   │   └── ...
│   ├── skills/                 # Must stay (Claude Code discovery)
│   │   ├── sprint.md → symlink #   but originals move to .pennyfarthing/skills/
│   │   └── ...
│   └── project/
│       └── hooks/              # → MOVE to .pennyfarthing/project/hooks/
│           ├── setup-env.sh
│           └── ...
├── .pennyfarthing/
│   ├── agents/ → symlink
│   ├── guides/ → symlink
│   ├── personas/ → symlink
│   ├── scripts/ → symlink
│   ├── workflows/ → symlink
│   ├── output-styles/ → symlink
│   └── sidecars/               # Writable, NOT symlinked
│       ├── dev/
│       ├── tea/
│       └── ...
```

### Target File Layout

```
project/
├── .claude/
│   ├── settings.local.json → ../.pennyfarthing/settings.local.json
│   ├── commands/               # Symlinks to .pennyfarthing/commands/*
│   └── skills/                 # Symlinks to .pennyfarthing/skills/*
├── .pennyfarthing/
│   ├── manifest.json           # MOVED from .claude/
│   ├── config.local.yaml       # MOVED from .claude/persona-config.yaml
│   ├── settings.local.json     # CANONICAL location (symlinked from .claude/)
│   ├── agents/ → symlink
│   ├── guides/ → symlink
│   ├── personas/ → symlink
│   ├── scripts/ → symlink
│   ├── workflows/ → symlink
│   ├── output-styles/ → symlink
│   ├── commands/               # Canonical, symlinked into .claude/commands/
│   ├── skills/                 # Canonical, symlinked into .claude/skills/
│   ├── project/
│   │   └── hooks/              # MOVED from .claude/project/hooks/
│   │       ├── setup-env.sh
│   │       └── ...
│   └── sidecars/               # Unchanged (already here)
```

### Key Design Decisions

#### 1. Symlink Strategy for Claude Code Discovery

Claude Code requires certain files in `.claude/` — settings.local.json, commands/, skills/. We can't move these entirely. Strategy: canonical files live in `.pennyfarthing/`, with symlinks in `.claude/` pointing back.

**Commands/Skills:** Currently individual files are symlinked from node_modules into `.claude/commands/` and `.claude/skills/`. New approach: files live in `.pennyfarthing/commands/` and `.pennyfarthing/skills/`, then symlinked into `.claude/`.

**settings.local.json:** Generated at `.pennyfarthing/settings.local.json`, symlinked from `.claude/settings.local.json`.

#### 2. Migration Safety

The update command must handle:
- Fresh installs (no migration needed)
- Old installs with files only in `.claude/` (full migration)
- Partially migrated installs (idempotent — don't double-move)
- User-customized files (preserve content, just move location)

Detection: check if `.pennyfarthing/manifest.json` exists. If not but `.claude/manifest.json` does, migration is needed.

#### 3. Manifest Location Change

Manifest moves from `.claude/manifest.json` to `.pennyfarthing/manifest.json`. The `readManifest()` and `writeManifest()` functions in `manifest.ts` need to:
1. Check `.pennyfarthing/manifest.json` first (new location)
2. Fall back to `.claude/manifest.json` (old location)
3. On write, always write to `.pennyfarthing/manifest.json`
4. After successful migration, remove `.claude/manifest.json`

#### 4. Hook Path Updates

Hooks in settings.local.json reference paths like `.pennyfarthing/scripts/hooks/...`. The project hooks (setup-env.sh) currently reference `.claude/project/hooks/`. After migration, these paths must update to `.pennyfarthing/project/hooks/`. The `mergeSettingsLocalJson()` function already handles path migration — extend it.

### Dependencies

**Already available:**
- `fs-extra` (used throughout for file operations)
- Node.js `fs` (symlinks, stats, chmod)
- `path` (path resolution)

**No new dependencies needed.**

### Testing Strategy

**Test location:** `pennyfarthing/packages/core/src/cli/commands/` (alongside existing doctor-legacy.test.ts)

**Run tests:**
```bash
cd pennyfarthing && pnpm build --filter @pennyfarthing/core && node --test packages/core/dist/cli/commands/*.test.js
```

**Existing test infrastructure:**
- `doctor-legacy.test.ts` — tests for legacy statusline detection/cleanup (pattern to follow)
- Node native test runner (`node:test`)
- No mocking framework — tests use real filesystem with temp directories

## Story Breakdown

### MSSCI-14365: Audit and map all files (2 pts, P0, trivial)

Inventory of every file and directory Pennyfarthing creates outside `.pennyfarthing/`. Each file gets a migration plan: move, symlink, or deprecate.

**Deliverables:**
- Document listing every file init/update creates in `.claude/` and elsewhere
- Migration plan per file (move to `.pennyfarthing/`, symlink, or keep)
- Identify any files that **must** stay in `.claude/` for Claude Code

**Key files:**
- Create: `docs/planning/install-audit.md` (or similar)
- Read: `packages/core/src/cli/commands/init.ts`
- Read: `packages/core/src/cli/utils/symlinks.ts`
- Read: `packages/core/src/cli/utils/settings.ts`

**Technical notes:**
- Run `pennyfarthing init` in a temp directory and diff the tree
- Check both `.claude/` and project root for generated files
- Map each file to its init.ts/update.ts creation point

---

### MSSCI-14366: Move settings.local.json into .pennyfarthing (3 pts, P0, TDD)

Generate settings.local.json at `.pennyfarthing/settings.local.json` with a symlink at `.claude/settings.local.json`.

**Deliverables:**
- `mergeSettingsLocalJson()` writes to `.pennyfarthing/settings.local.json`
- Symlink created at `.claude/settings.local.json` → `../.pennyfarthing/settings.local.json`
- Migration: existing real file at `.claude/settings.local.json` moved on update
- Tests for symlink creation and migration

**Key files:**
- Modify: `packages/core/src/cli/utils/settings.ts`
- Modify: `packages/core/src/cli/commands/init.ts`
- Modify: `packages/core/src/cli/commands/update.ts`
- Modify: `packages/core/src/cli/commands/doctor.ts` (check symlink validity)

**Technical notes:**
- Relative symlink: `../.pennyfarthing/settings.local.json` from `.claude/`
- Must handle case where `.claude/settings.local.json` is already a symlink (idempotent)
- Must handle case where it's a real file with user customizations (move, preserve content)

---

### MSSCI-14367: Move persona-config.yaml into .pennyfarthing (3 pts, P1, TDD)

Consolidate persona/theme configuration to `.pennyfarthing/config.local.yaml` exclusively.

**Deliverables:**
- Init creates `config.local.yaml` at `.pennyfarthing/config.local.yaml`
- Update migrates `.claude/persona-config.yaml` → `.pennyfarthing/config.local.yaml`
- Doctor detects old location and offers migration
- All code paths reading persona config updated

**Key files:**
- Modify: `packages/core/src/cli/commands/init.ts`
- Modify: `packages/core/src/cli/commands/update.ts`
- Modify: `packages/core/src/cli/commands/doctor.ts`
- Modify: `packages/core/src/cli/utils/themes.ts` (already prefers new location)

**Technical notes:**
- `themes.ts` already checks `.pennyfarthing/config.local.yaml` first — good
- Need to stop creating `.claude/persona-config.yaml` in init
- Migration: move file, update any references
- Rename from `persona-config.yaml` to `config.local.yaml` (consolidating naming)

---

### MSSCI-14368: Move project hooks into .pennyfarthing/project (3 pts, P1, TDD)

Move project-specific hooks from `.claude/project/` to `.pennyfarthing/project/`.

**Deliverables:**
- Init creates hooks at `.pennyfarthing/project/hooks/`
- Update migrates `.claude/project/hooks/` contents
- settings.local.json hook paths updated to new location
- `.claude/project/` cleaned up if empty after migration

**Key files:**
- Modify: `packages/core/src/cli/commands/init.ts`
- Modify: `packages/core/src/cli/commands/update.ts`
- Modify: `packages/core/src/cli/utils/settings.ts` (path migration)
- Modify: `packages/core/src/cli/commands/doctor.ts`

**Technical notes:**
- Hook paths in settings.local.json must be updated atomically (update paths + move files together)
- `setup-env.sh` is referenced in SessionStart hook — path must match
- Check for user-added hooks in `.claude/project/hooks/` that aren't ours

---

### MSSCI-14369: Consolidate sidecars directory (2 pts, P2, trivial)

Ensure sidecars live only at `.pennyfarthing/sidecars/`. Remove stale `.claude/sidecars/` references.

**Deliverables:**
- Update merges any `.claude/sidecars/` content into `.pennyfarthing/sidecars/`
- Grep codebase for `.claude/sidecars/` references and update
- Doctor checks no sidecars exist at old location

**Key files:**
- Modify: `packages/core/src/cli/commands/update.ts` (already has sidecar migration)
- Modify: `packages/core/src/cli/commands/doctor.ts`
- Search: all references to `.claude/sidecars/`

**Technical notes:**
- update.ts already migrates from `.claude/project/agents/{agent}-sidecar/` and `sprint/sidecars/`
- May also need to check `.claude/sidecars/` as another legacy location
- Merge strategy: don't overwrite newer files in destination

---

### MSSCI-14370: Update init command for bootstrapping (5 pts, P0, TDD)

Rework `pennyfarthing init` to do minimal bootstrapping then hand off to interactive setup.

**Deliverables:**
- Init creates `.pennyfarthing/` with core files, registers hooks
- Prints instructions to start interactive setup workflow
- Interactive workflow guides theme selection, sprint setup, persona config
- All files created in `.pennyfarthing/` namespace

**Key files:**
- Modify: `packages/core/src/cli/commands/init.ts` (major rework)
- Modify: `packages/core/src/cli/utils/constants.ts` (update paths)
- Modify: `packages/core/src/cli/utils/symlinks.ts` (update targets)

**Technical notes:**
- This depends on MSSCI-14365 (audit) to know the full file list
- This depends on MSSCI-14366 (settings), MSSCI-14367 (persona), MSSCI-14368 (hooks) for new locations
- Bootstrap phase: create dirs, symlink framework content, register hooks
- Interactive phase: theme picker, sprint setup, persona config generation
- Must remain idempotent (re-running init doesn't break things)

---

### MSSCI-14371: Update update command for file migration (5 pts, P0, TDD)

Rework `pennyfarthing update` to detect and migrate files from old locations.

**Deliverables:**
- Detects files in `.claude/` that should be in `.pennyfarthing/`
- Migrates: manifest, persona-config, settings.local.json, hooks
- Creates symlinks where Claude Code needs `.claude/` discovery
- Doctor passes after update completes

**Key files:**
- Modify: `packages/core/src/cli/commands/update.ts` (major rework)
- Modify: `packages/core/src/cli/utils/manifest.ts` (dual-location read)

**Technical notes:**
- Migration detection: check `.pennyfarthing/manifest.json` existence
- Must handle partial migrations (idempotent)
- Manifest read should check new location first, fall back to old
- After migration, verify with doctor (already calls doctor at end)

---

### MSSCI-14372: Update doctor to validate new file layout (3 pts, P1, TDD)

Extend doctor to check files are in correct `.pennyfarthing/` locations.

**Deliverables:**
- Check manifest at `.pennyfarthing/manifest.json`
- Check settings.local.json symlink validity
- Check persona config at `.pennyfarthing/config.local.yaml`
- Flag files at old `.claude/` locations with migration instructions
- `--fix` migrates automatically

**Key files:**
- Modify: `packages/core/src/cli/commands/doctor.ts`

**Technical notes:**
- New check category: "File Layout" or "Namespace"
- Each check: "file X should be at .pennyfarthing/Y, found at .claude/Z"
- Fix function: move file + create symlink if needed
- Preserve existing checks (Cyclist spawn-helper, legacy statusline, etc.)

---

### MSSCI-14373: End-to-end test — fresh repo install (5 pts, P0, TDD)

Automated test that creates a new repo, runs `pennyfarthing init`, validates with doctor.

**Deliverables:**
- Test script creates temp git repo
- Runs `pennyfarthing init`
- Validates doctor passes
- Exercises just scripts (dev, test, build)
- Cleans up temp repo

**Key files:**
- Create: `packages/core/src/cli/commands/init.e2e.test.ts` (or `tests/e2e/`)
- Read: existing doctor-legacy.test.ts for test patterns

**Technical notes:**
- Needs real filesystem (no mocking)
- May need to install pennyfarthing as npm dependency in temp repo
- Alternative: test with local path dependency (`file:../..`)
- Consider timeout — init + doctor + just recipes may take time
- Must clean up even on test failure (try/finally)

---

### MSSCI-14374: End-to-end test — existing repo upgrade (3 pts, P0, TDD)

Automated test that sets up old-style install, runs `pennyfarthing update`, validates migration.

**Deliverables:**
- Test creates temp repo with old-style layout (files in `.claude/`)
- Runs `pennyfarthing update`
- Validates: doctor passes, files in `.pennyfarthing/`, symlinks exist
- Cleans up

**Key files:**
- Create: `packages/core/src/cli/commands/update.e2e.test.ts` (or `tests/e2e/`)

**Technical notes:**
- Must create a realistic old-style install (manifest in `.claude/`, persona-config in `.claude/`, etc.)
- Verify each migrated file:
  - `.pennyfarthing/manifest.json` exists
  - `.pennyfarthing/config.local.yaml` exists
  - `.claude/settings.local.json` is a symlink to `.pennyfarthing/settings.local.json`
- Verify doctor reports all pass

## Dependency Graph

```
MSSCI-14365 (audit) ──→ MSSCI-14370 (init rework)
                    └──→ MSSCI-14371 (update rework)

MSSCI-14366 (settings) ──┐
MSSCI-14367 (persona)  ──┼──→ MSSCI-14370 (init rework)
MSSCI-14368 (hooks)    ──┤    MSSCI-14371 (update rework)
MSSCI-14369 (sidecars) ──┘    MSSCI-14372 (doctor layout)

MSSCI-14370 (init)   ──→ MSSCI-14373 (e2e fresh)
MSSCI-14371 (update) ──→ MSSCI-14374 (e2e upgrade)
MSSCI-14372 (doctor) ──→ MSSCI-14373 + MSSCI-14374
```

**Phase 1 (can parallelize):** MSSCI-14365 (audit), MSSCI-14366 (settings), MSSCI-14367 (persona), MSSCI-14368 (hooks), MSSCI-14369 (sidecars)
**Phase 2 (depends on Phase 1):** MSSCI-14370 (init), MSSCI-14371 (update), MSSCI-14372 (doctor)
**Phase 3 (depends on Phase 2):** MSSCI-14373 (e2e fresh), MSSCI-14374 (e2e upgrade)

## Risks

| Risk | Mitigation |
|------|------------|
| Breaking existing installs | Dual-location reads (check new first, fall back to old) |
| Claude Code can't find files | Only symlink away from `.claude/` for files CC discovers there |
| Symlink loops or broken paths | Doctor validates symlink targets, `--fix` repairs |
| User-customized files lost during migration | Move (preserve content), never overwrite without backup |
| Partial migration state | Idempotent operations — re-running update/doctor --fix converges |

## References

- [Install Overhaul Planning Doc](/docs/planning/install-overhaul-epics.md)
- [Init Command](/pennyfarthing/packages/core/src/cli/commands/init.ts)
- [Update Command](/pennyfarthing/packages/core/src/cli/commands/update.ts)
- [Doctor Command](/pennyfarthing/packages/core/src/cli/commands/doctor.ts)
- [Manifest Utils](/pennyfarthing/packages/core/src/cli/utils/manifest.ts)
- [Settings Utils](/pennyfarthing/packages/core/src/cli/utils/settings.ts)
- [Symlink Utils](/pennyfarthing/packages/core/src/cli/utils/symlinks.ts)
- [Constants](/pennyfarthing/packages/core/src/cli/utils/constants.ts)
