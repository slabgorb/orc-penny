# Tech Debt Audit - Epic Breakdown

## Overview

Tech debt audit findings from March 2026 hull inspection. Covers dependency hygiene, dead code cleanup, test coverage gaps, error handling pattern violations, and type safety improvements across the pennyfarthing framework.

**Points:** 32

## Epic 1: Dependency Hygiene

**User Outcome:** Monorepo dependencies are deduplicated, version-aligned, and maintainable

**Points:** 3

### Story 1.1: Hoist Shared UI Dependencies to Monorepo Root

I want **shared UI dependencies (20+ @radix-ui packages, clsx, cmdk, class-variance-authority, lucide-react, tailwind-merge) moved from individual package devDependencies to the monorepo root so they are installed once and resolved consistently**,

**Points:** 2

### Story 1.2: Unify Dependency Version Drift

I want **@types/ws (8.5.10 vs 8.18.1) and yaml (2.3.4 vs 2.8.2) unified to single versions across all packages so there are no subtle behavioral differences from version drift**,

**Points:** 1

## Epic 2: Dead Code Cleanup

**User Outcome:** No orphaned hooks, deprecated shims, or stale package references exist in the codebase

**Points:** 4

### Story 2.1: Audit Unexported Hooks — Export or Delete

I want **the 20 React hooks in packages/core/src/public/hooks/ that are created but not exported from index.ts to be either exported or deleted, and deprecated useMessageStream removed in favor of ClaudeContext**,

**Points:** 3

### Story 2.2: Remove Deprecated Bikerack Shim and Stale References

I want **cyclist/src/bikerack.ts shim removed and all source code references to packages/bikerack/ and packages/shared/ cleaned up since bikerack never existed and shared was absorbed into core in Story 98-16**,

**Points:** 1

## Epic 3: Server API Route Test Coverage

**User Outcome:** All 24 WheelHub server API route handlers have test coverage protecting the external-facing surface area

**Points:** 13

### Story 3.1: Add Tests for Core API Routes (agent-load through dependencies)

I want **test files for agent-load, approval-gate, audit-log, bell, code-markers, complexity, context, dead-code, and dependencies API routes with happy path and at least one error case each**,

**Points:** 5

### Story 3.2: Add Tests for Core API Routes (evaluation through portrait)

I want **test files for evaluation, file-browser, git, health-score, hook-request, hotspots, identity, mode, otlp, permissions, persona, and portrait API routes with happy path and at least one error case each**,

**Points:** 5

### Story 3.3: Add Tests for Core API Routes (settings through welcome)

I want **test files for settings, stats, story, telemetry, theme-agents, todos, token-stats, and welcome API routes with happy path and at least one error case each**,

**Points:** 3

## Epic 4: Convert Throw Patterns to Result Objects

**User Outcome:** Non-React production code consistently returns result objects instead of throwing, matching Rule 6 convention

**Points:** 8

### Story 4.1: Convert Throw to Result Objects in Scripts and Generators

I want **scripts/generate-report.ts (18 throws), shared/generate-skill-docs.ts (7 throws), and shared/skill-search.ts (3 throws) converted to return {success, data?, error?} result objects with all callers updated**,

**Points:** 3

### Story 4.2: Convert Throw to Result Objects in CLI Utils

I want **cli/utils/themes.ts (5 throws), cli/utils/files.ts, cli/utils/version.ts, and cli/utils/manifest.ts converted to return result objects with all callers updated**,

**Points:** 3

### Story 4.3: Convert Throw to Result Objects in Cyclist File-Browser

I want **cyclist/src/file-browser.ts (6 throw sites) converted to return result objects with all callers updated**,

**Points:** 2

## Epic 5: Eliminate as-any Type Assertions

**User Outcome:** TypeScript type safety is enforced at critical runtime boundaries with proper interfaces instead of unsafe casts

**Points:** 4

### Story 5.1: Type OTLP Receiver Payloads Properly

I want **TypeScript interfaces defined for OTLP metric and log payloads replacing all 3 as-any casts in otlp-receiver.ts so payload parsing is type-safe at runtime**,

**Points:** 2

### Story 5.2: Remove as-any from UI Components

I want **DockviewWorkspace.tsx panel ID assertions, ProgressPanel.tsx criteria/todo filtering, and MessageView.tsx message group assertions replaced with proper types, and SprintPanel.tsx Electron API references removed since Electron is deprecated**,

**Points:** 2
