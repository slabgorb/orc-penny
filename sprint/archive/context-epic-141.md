# Epic 141: Tech Debt Audit

## Overview

Systematic cleanup of technical debt identified during the March 2026 audit of the pennyfarthing framework. Covers dependency hygiene, dead code removal, test coverage gaps, error handling pattern violations (throw vs result objects), type safety improvements, and consolidation of duplicated logic between TypeScript and Python layers.

**Priority:** P2
**Repo:** pennyfarthing
**Stories:** 21 (60 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **CLAUDE.md** (`CLAUDE.md`) | Rule 6: Return result objects `{success, data?, error?}` — don't throw |
| **repos.yaml** (`.pennyfarthing/repos.yaml`) | Repo topology, never-edit zones, symlink mapping |

## Background

The March 2026 tech debt audit surfaced several categories of debt across the pennyfarthing framework:

### Dependency Hygiene (141-1, 141-2 — DONE)
Shared UI dependencies (`@radix-ui`, `clsx`, `lucide-react`, etc.) were duplicated across packages instead of hoisted to the monorepo root. Version drift existed for `@types/ws` and `yaml`.

### Dead Code & Deprecated Shims (141-4, 141-15)
The `cyclist/src/bikerack.ts` shim and references to the never-existed `packages/bikerack/` remain. Shell/Python scripts duplicate `pf` CLI commands and should be deleted.

### Test Coverage Gaps (141-5, 141-6, 141-7)
Core API routes lack test files. Routes from `agent-load` through `welcome` (~20 route handlers) have zero test coverage.

### Error Handling Violations (141-8, 141-9, 141-10)
Multiple modules use `throw` instead of the project-standard result object pattern `{success, data?, error?}`. Affects scripts, CLI utils, and cyclist file-browser.

### Type Safety (141-11, 141-12)
OTLP receiver payloads use `as any` casts instead of proper TypeScript interfaces. UI components have unnecessary type assertions and stale Electron references.

### Hook Audit (141-3)
Public hooks directory contains unexported hook files. `useMessageStream` is deprecated but not removed.

### TypeScript/Python Duplication (141-16 through 141-20)
The largest debt category. `story-parser.ts` (886 lines, duplicated in core AND cyclist), workflow engine files (~2300 lines), and `theme-loader.ts` (577 lines) all reimplement logic that exists in the `pf` Python CLI. The consolidation strategy is: add `--json` output to `pf` CLI commands (141-16), then replace TypeScript implementations with subprocess calls (141-17, 141-18, 141-19).

### Misplaced Business Logic (141-21)
Agent evaluation scoring logic lives in the GUI server instead of `packages/benchmark`. Slug generation is duplicated. Settings migration only runs in TypeScript.

## Technical Architecture

### Consolidation Pattern (141-16 → 141-17/18/19)

```
Before:  TypeScript → direct file parsing → YAML/markdown
After:   TypeScript → pf <cmd> --json (subprocess) → structured JSON
```

The `pf` CLI becomes the single source of truth for sprint data, workflow state, theme discovery, and persona assembly. TypeScript layers become thin wrappers that call `pf` and render the results.

### Result Object Pattern (141-8/9/10)

```typescript
// Before (violation)
function doThing(): Data {
  throw new Error("failed");
}

// After (project standard)
function doThing(): { success: boolean; data?: Data; error?: string } {
  return { success: false, error: "failed" };
}
```

### Key Directories

| Path | Relevance |
|------|-----------|
| `packages/core/src/routes/` | API route files needing tests (141-5/6/7) |
| `packages/core/src/` | story-parser, workflow engine, theme-loader (141-17/18/19) |
| `packages/cyclist/src/` | Duplicated story-parser, file-browser (141-10/17) |
| `pennyfarthing-dist/pf/` | Python CLI — target for --json additions (141-16) |
| `pennyfarthing-dist/scripts/` | Dead shell scripts to delete (141-15) |

## Cross-Epic Dependencies

**Depends on:**
- None — this is a standalone cleanup epic

**Depended on by:**
- Future GUI work benefits from TypeScript/Python consolidation (141-16 through 141-19)
- Future CLI consumers benefit from --json output (141-16)
