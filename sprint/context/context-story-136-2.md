---
parent: context-epic-136.md
workflow: tdd
---

# Story 136-2: WheelHub pip-install support — remove monorepo path assumptions

## Business Context

Every pip-installed consumer who runs `pf bikerack start` hits a crash because the BikeRack launcher and WheelHub server both resolve paths by counting parent directories up to a monorepo root that does not exist in a pip layout. The launcher's `_find_wheelhub_entry()` walks five levels from `__file__` expecting `pennyfarthing/packages/core/dist/server/entry.js`; the server's `PACKAGE_ROOT` walks three levels from `__dirname` expecting the monorepo root; and the context API hardcodes four path candidates for `context.py`, none of which match a pip-installed `site-packages/pf/` tree.

A robust resolution strategy already exists in `resolvePennyfarthingDist()` (in both `paths.ts` and `portrait-resolver.ts`), which uses env var, Electron, walk-up, and npm fallbacks. But `pennyfarthing.ts` ignores it entirely, using a raw `join(__dirname, '..', '..', '..')` instead. This story makes all three files use proper multi-strategy resolution so WheelHub works in both monorepo and pip layouts, and degrades gracefully when WheelHub is unavailable (pip consumers may not have Node.js).

This story depends on 136-1 (pf discovery for `context.py` resolution), which ensures `pf` itself is discoverable. 136-2 then fixes the Node.js server paths that `pf bikerack start` launches.

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/bikerack/launcher.py` | Replace 5-level `Path(__file__).resolve().parent.parent...` traversal in `_find_wheelhub_entry()` with a multi-strategy discovery (monorepo walk-up, pip `_dist/server/wheelhub.mjs`, env var override). Raise descriptive `FileNotFoundError` with attempted paths on failure. |
| `packages/core/src/server/pennyfarthing.ts` | Replace `PACKAGE_ROOT = join(__dirname, '..', '..', '..')` with a call to `resolvePennyfarthingDist()` from `portrait-resolver.ts` (or a local equivalent). Fall back to the current `__dirname` traversal only when `resolvePennyfarthingDist()` returns null. Update all consumers of `PACKAGE_ROOT` (theme path resolution in `getCurrentPersona` and `getFullPersonaDetails`). |
| `packages/core/src/server/api/context.ts` | Add pip-installed path candidates for `context.py`: `site-packages/pf/context.py` resolved via the `pf` binary's location (from 136-1). Ensure the `resolvePennyfarthingDist()` fallback also checks `src/pf/context.py` relative to the resolved dist root. |

### Key Files to Consume (Read-Only)

| File | Purpose |
|------|---------|
| `packages/core/src/server/paths.ts` | Reference implementation of `resolvePennyfarthingDist()` with 5-strategy resolution (env var, Electron, walk-up, npm, scoped npm). Use as the model for what the fix should look like. |
| `packages/core/src/shared/portrait-resolver.ts` | Shared `resolvePennyfarthingDist()` already imported by `context.ts`. Understand its search order: env var, monorepo walk-up, sibling, scoped npm, legacy npm. |
| `tests/python/test_bikerack_launcher.py` | Existing launcher tests. New tests must follow the same patterns (tmp_path fixtures, mock Popen). |

### Patterns to Follow

- Use `resolvePennyfarthingDist()` from `portrait-resolver.ts` for all Node-side path resolution. Do not duplicate the walk-up logic in `pennyfarthing.ts`.
- In Python (`launcher.py`), implement a similar multi-strategy pattern: env var (`PENNYFARTHING_DIST`) first, then monorepo walk-up from `__file__`, then pip `_dist/server/` fallback. Log attempted paths in the error message on failure.
- Result-object pattern for any new Python functions: return `{success, data?, error?}` -- do not throw.
- Graceful degradation: when `_find_wheelhub_entry()` raises `FileNotFoundError`, callers should catch and report "WheelHub unavailable" rather than crashing. Pip consumers without Node.js should get a clear message, not a traceback.
- All relative TypeScript imports must use `.js` extensions.
- Tests must cover both monorepo and pip layout scenarios using filesystem fixtures (tmp directories with the expected file structure).

### What NOT to Touch

- `resolvePennyfarthingDist()` implementation in `portrait-resolver.ts` or `paths.ts` (these are correct; the fix is to *use* them)
- `pf_launcher.py` or `hooks.py` PATH resolution (that is 136-1)
- `pf init` / `pf doctor` filtering (that is 136-3)
- TUI color thresholds (that is 136-4)
- TUI data pipeline error handling / retry logic (that is 136-5)
- The pip build/packaging pipeline itself (the `_dist/server/wheelhub.mjs` bundling is a build concern prerequisite, not a runtime code change)

## Scope Boundaries

**In scope:**
- `_find_wheelhub_entry()` uses multi-strategy discovery instead of hardcoded parent traversal
- `PACKAGE_ROOT` in `pennyfarthing.ts` uses `resolvePennyfarthingDist()` instead of `join(__dirname, '..', '..', '..')`
- `context.ts` path candidates include pip-installed layout paths
- Graceful error when WheelHub entry point is not found (no Node.js installed, or `_dist/server/` not bundled)
- Monorepo dev workflow continues to work unchanged
- Tests for both layout scenarios

**Out of scope:**
- PATH resolution for the `pf` binary itself (136-1)
- Building/bundling `wheelhub.mjs` into the pip `_dist/server/` directory (build pipeline concern, prerequisite)
- `pf init` / `pf doctor` command filtering for pip layout (136-3)
- TUI panel error states or retry logic (136-5)
- Adding new strategies to `resolvePennyfarthingDist()` (it is already robust)

## AC Context

### AC1: Monorepo path resolution still works

**Given** WheelHub is running in a monorepo development environment where `packages/core/dist/server/entry.js` exists at the expected location
**When** `_find_wheelhub_entry()` is called from `launcher.py`
**Then** it returns the path to `packages/core/dist/server/entry.js`
**And** `PACKAGE_ROOT` in `pennyfarthing.ts` resolves to the monorepo root (same value as before)
**And** theme YAML files are found via the resolved root in `getCurrentPersona()`

**Edge cases:**
- Monorepo with `dist/` not yet built (no `entry.js`) -- should fall through to next strategy, not crash
- Monorepo with `PENNYFARTHING_DIST` env var set -- env var takes precedence

### AC2: Pip-installed WheelHub launches successfully

**Given** `pf` is installed via pip/pipx/uv and `_dist/server/wheelhub.mjs` exists in the pip package
**When** `_find_wheelhub_entry()` is called from `launcher.py`
**Then** it discovers `wheelhub.mjs` via the pip package's `_dist/server/` directory
**And** `start_wheelhub()` launches `node wheelhub.mjs` successfully

**Edge cases:**
- `_dist/server/` directory exists but `wheelhub.mjs` is missing (build not bundled) -- raises `FileNotFoundError` with clear message listing attempted paths
- `PENNYFARTHING_DIST` env var overrides pip path -- env var path is checked first

### AC3: context.py found in pip layout

**Given** `pf` is installed via pip and `context.py` lives at `site-packages/pf/context.py`
**When** `getContextUsage()` is called from `context.ts`
**Then** `context.py` is discovered via the `resolvePennyfarthingDist()` fallback path or a new pip-specific candidate
**And** context usage data is returned successfully

**Edge cases:**
- `resolvePennyfarthingDist()` returns the pip package root -- `pf/context.py` and `src/pf/context.py` paths are both checked relative to it
- Neither monorepo nor pip paths exist -- returns `{error: 'context.py not found'}` (existing behavior, no crash)
- Project dir has a local `pennyfarthing-dist/pf/context.py` (consumer monorepo) -- local path takes priority over pip path

### AC4: Graceful degradation when WheelHub is unavailable

**Given** a pip-installed environment where Node.js is not installed or `wheelhub.mjs` is not bundled
**When** `_find_wheelhub_entry()` is called
**Then** it raises `FileNotFoundError` with a message listing all attempted paths
**And** the caller (`start_wheelhub` or `pf bikerack start`) catches the error and displays a user-friendly message: "WheelHub is not available. BikeRack panels require Node.js and a bundled WheelHub server."
**And** no Python traceback is shown to the user

**Edge cases:**
- Node.js is installed but `wheelhub.mjs` is not bundled -- error message distinguishes "entry point not found" from "Node.js not installed"
- `pf bikerack status` should report `running: false` without error when WheelHub was never started

### AC5: PACKAGE_ROOT uses resolvePennyfarthingDist

**Given** `pennyfarthing.ts` is loaded by WheelHub
**When** `PACKAGE_ROOT` is computed at module initialization
**Then** it uses `resolvePennyfarthingDist()` (or the shared import from `portrait-resolver.ts`)
**And** falls back to `join(__dirname, '..', '..', '..')` only when resolution returns null
**And** all downstream consumers (`getCurrentPersona`, `getFullPersonaDetails`) use the resolved root for theme YAML lookups

**Edge cases:**
- `resolvePennyfarthingDist()` returns null (no pennyfarthing-dist found anywhere) -- falls back to `__dirname` traversal to avoid breaking unknown environments
- Module is loaded from npm `node_modules/@pennyfarthing/core/dist/server/` -- `resolvePennyfarthingDist()` walk-up finds `pennyfarthing-dist/` at the package root
