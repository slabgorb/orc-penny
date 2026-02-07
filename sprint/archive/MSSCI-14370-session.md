# MSSCI-14370: Update init command for bootstrapping install

**Status:** In Progress
**Workflow:** tdd
**Phase:** finish
**Epic:** epic-85 (Clean Install Consolidation)
**Jira:** MSSCI-14370
**Epic Jira:** MSSCI-14364
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14370-update-init-command
**Points:** 5
**Priority:** P0

## Acceptance Criteria

- [ ] `init.ts` creates consolidated `.pennyfarthing/` layout
- [ ] Manifest moves to `.pennyfarthing/manifest.json`
- [ ] Preferences moves to `.pennyfarthing/preferences.yaml`
- [ ] Project hooks move to `.pennyfarthing/project/hooks/`
- [ ] Settings.local.json canonical location is `.pennyfarthing/` with symlink at `.claude/`
- [ ] Agent scopes move to `.pennyfarthing/project/docs/agent-scopes.yaml`
- [ ] Pennyfarthing-settings moves to `.pennyfarthing/project/pennyfarthing-settings.yaml`
- [ ] Shared-context stays at `.claude/project/docs/shared-context.md` (user file)
- [ ] `.claude/commands/` and `.claude/skills/` continue to work (Claude Code discovery)
- [ ] Backward compatibility: existing installs still function
- [ ] All existing init tests pass or are updated

## Context

This is the keystone story of epic-85. Stories 1.2-1.5 (MSSCI-14366 through MSSCI-14369) moved individual file groups under `.pennyfarthing/`. This story updates the init command itself to use the new consolidated layout as the default for fresh installs.

Key source files:
- `packages/core/src/cli/commands/init.ts` - Main init command
- `packages/core/src/cli/utils/constants.ts` - Path constants
- `packages/core/src/cli/utils/symlinks.ts` - Symlink/copy helpers
- `packages/core/src/cli/utils/settings.ts` - Settings merge logic
- `packages/core/src/cli/utils/manifest.ts` - Manifest read/write
- `packages/core/src/cli/utils/files.ts` - File system helpers

See `sprint/context/context-epic-85.md` for full architecture details.

## TEA Assessment

**Tests Required:** Yes
**Test File:** `packages/core/src/cli/commands/init-consolidation.test.ts`
**Tests Written:** 17 tests (7 failing, 10 passing)
**Status:** RED (failing — ready for Dev)

### Failing Tests (7) — require implementation changes:
1. `getManifestPath()` → must return `.pennyfarthing/manifest.json`
2. `writeManifest()` → must write to `.pennyfarthing/` not `.claude/`
3. `manifestExists()` → must find manifest at `.pennyfarthing/`
4. `readManifest()` → must read from `.pennyfarthing/`
5. `.pennyfarthing/` manifest precedence over `.claude/`
6. `createManifest()` managedPaths → `.pennyfarthing/` paths for symlinked dirs
7. `createManifest()` → must NOT list legacy `.claude/agents`, `.claude/guides`, etc.

### Implementation Guidance for Dev:

**Primary change: `manifest.ts`**
- Change `MANIFEST_PATH` from `'.claude/manifest.json'` to `'.pennyfarthing/manifest.json'`
- Add fallback in `manifestExists()` and `readManifest()` to check `.claude/manifest.json` for backward compat
- New location takes precedence when both exist
- Update `writeManifest()` to `ensureDirSync('.pennyfarthing')` instead of `.claude`
- Update `createManifest()` managedPaths to use `.pennyfarthing/` prefixes

**Secondary change: `init.ts`**
- Update `directories` array: `.claude/project/*` → `.pennyfarthing/project/*`
- Update `skipIfExistsTemplates` destinations:
  - `persona-config.yaml` → `.pennyfarthing/persona-config.yaml`
  - `preferences.yaml` → `.pennyfarthing/preferences.yaml`
  - `agent-scopes.yaml` → `.pennyfarthing/project/docs/agent-scopes.yaml`
  - `pennyfarthing-settings.yaml` → `.pennyfarthing/project/pennyfarthing-settings.yaml`
  - `setup-env.sh` → `.pennyfarthing/project/hooks/setup-env.sh`
  - `shared-context.md` → stays at `.claude/project/docs/shared-context.md` (user file)
- Update manifest write log message: `.pennyfarthing/manifest.json`
- Update `copyCommandsDirectory` and `copySkillsDirectory` to read user commands/skills from `.pennyfarthing/project/` instead of `.claude/project/`

**Settings already done:** MSSCI-14366 moved settings.local.json — that AC is already green.

### Handoff: To Dev (Roy Batty) for implementation

## Dev Assessment

**Status:** GREEN (all 17 tests passing)
**Commits:** 2 (test + implementation)

### Changes Made:

**`manifest.ts`** (primary):
- `MANIFEST_PATH` → `.pennyfarthing/manifest.json`
- Added `LEGACY_MANIFEST_PATH` = `.claude/manifest.json`
- `manifestExists()` checks both locations (new first)
- `readManifest()` falls back to legacy `.claude/` location; `.pennyfarthing/` takes precedence
- `writeManifest()` ensures `.pennyfarthing/` dir instead of `.claude/`
- `createManifest()` managedPaths updated: `.pennyfarthing/{agents,guides,output-styles,personas,scripts,workflows}` + `.claude/{commands,skills}`

**`init.ts`** (secondary):
- `directories` array: `.claude/project/*` → `.pennyfarthing/project/*`
- `skipIfExistsTemplates`: all destinations moved to `.pennyfarthing/` except `shared-context.md` (stays at `.claude/`)
- User commands/skills source: `.pennyfarthing/project/{commands,skills}`
- Log messages updated

**`update.ts`** (alignment):
- Project commands/skills dirs → `.pennyfarthing/project/`
- Manifest log message → `.pennyfarthing/manifest.json`

### Regression Check:
- 1578 total tests, 1491 pass, 86 fail (all pre-existing — OCEAN profiles, Cyclist, legacy doctor)
- settings-consolidation.test.ts (MSSCI-14366): all pass
- init-consolidation.test.ts (MSSCI-14370): 17/17 pass

### Handoff: To Reviewer (J.F. Sebastian) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #697

### Observations (7 verified, 3 noted):

| Severity | Finding | Location |
|----------|---------|----------|
| `[VERIFIED]` | MANIFEST_PATH correctly at .pennyfarthing/, LEGACY fallback correct | `manifest.ts:20-21` |
| `[VERIFIED]` | writeManifest() ensures .pennyfarthing/ dir | `manifest.ts:75` |
| `[VERIFIED]` | init directories array uses .pennyfarthing/project/* | `init.ts:96-106` |
| `[VERIFIED]` | Template destinations all correct, shared-context stays at .claude/ | `init.ts:330-337` |
| `[VERIFIED]` | managedPaths match constants.ts MANAGED_PATHS | `manifest.ts:98-107` |
| `[VERIFIED]` | update.ts aligned to .pennyfarthing/ paths | `update.ts:173-219` |
| `[VERIFIED]` | readManifest() precedence: .pennyfarthing/ > .claude/ | `manifest.ts:46-48` |
| `[MEDIUM]` | uninstall.ts MANAGED_PATHS still .claude/ only (pre-existing) | `uninstall.ts:16-26` |
| `[MEDIUM]` | Stale .claude/pennyfarthing/ in checkForUpdates (dead code path) | `update.ts:352` |
| `[LOW]` | skill/command create targets .claude/project/ vs init reads .pennyfarthing/project/ | `skill.ts:149`, `command.ts:146` |

**Data flow traced:** init → createDirs → symlinks → copyCommands/Skills → writeManifest → .gitignore. On update: manifestExists checks both → readManifest with precedence → safe.
**Pattern observed:** Clean TDD (test commit then impl commit). Tests exercise manifest API directly.
**Error handling:** readManifest try/catch, writeManifest ensureDirSync, dryRun guards. Adequate.
**Security:** No user input in file path construction. All paths from constants + process.cwd().
**Tests:** 17/17 pass.

**Handoff:** To SM (Captain Bryant) for finish-story
