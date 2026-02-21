---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
  - step-05-import-to-future
inputDocuments:
  - sprint/planning/bikerack-extraction-proposal.md
  - sprint/planning/bikeshop-design-review-checklist.md
  - sprint/planning/bikeshop-prd.md
---

# BikeRack Extraction - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for the BikeRack extraction from Cyclist, decomposing the requirements from the extraction proposal and design review decisions into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR1: BikeRack package (`packages/bikerack/`) absorbs the non-Electron server stack — Express app factory, route mounting, API routers (30+), OTLP receiver, WebSocket channels (15), file watchers (sprint, session, git), settings management
- FR2: BikeRack entry point replaces `bikerack.ts` (currently 52 lines in Cyclist) with an expanded standalone launcher including session lifecycle (start server + Claude CLI) and cleanup (port file, process management)
- FR3: BikeRack display components (BikeRackWorkspace, BikeRackIndex, StandalonePanel) move from `packages/core/src/public/` to `packages/bikerack/`
- FR4: WebSocket channel handlers (real implementations, ~1,600 lines) and OTLP processing (~1,000 lines) move from `packages/cyclist/src/` to `packages/bikerack/`
- FR5: `DataSource<T>` typed provider interface introduced in `@pennyfarthing/core` — panels consume this interface instead of hardcoded WebSocket URLs (DR-1)
- FR6: 11+ panel hooks (`useSprint`, `useGitStatus`, `useDiffs`, etc.) refactored to consume `DataSource<T>` (DR-1)
- FR7: `WebSocketDataSource` implementation in BikeRack for live local data (DR-1)
- FR8: Cyclist rewired to import `@pennyfarthing/bikerack` as a dependency — starts BikeRack's server engine, wires ClaudeService and `/ws/claude` channel, adds IDE control plane on top
- FR9: `IS_BIKERACK` env var gate removed — mode determined by entry point and service registration, not runtime flag
- FR10: `/ws/claude` WebSocket channel only exists when Cyclist's ClaudeService registers it — BikeRack never registers it, no flag needed
- FR11: Panel components remain in `@pennyfarthing/core`, shared by BikeRack, Cyclist, and future BikeShop
- FR12: Cyclist retains irreducible IDE control plane: ClaudeService, MessagePanel, bell mode, Reflector, TirePump, permissions/ApprovalModal, dockview layout

### NonFunctional Requirements

- NFR1: `npm install @pennyfarthing/bikerack` works without any Electron dependency
- NFR2: `pf bikerack start` developer experience unchanged post-extraction
- NFR3: Cyclist developer experience unchanged — starts BikeRack's server engine transparently via package dependency
- NFR4: All existing tests pass after import path rewiring
- NFR5: CI/build pipeline updated for new three-package structure (core, bikerack, cyclist)
- NFR6: Port convention preserved (BikeRack: 2898, Cyclist: 1898)

### Additional Requirements

- DR-1 (DataSource): Interface must support parameterized queries for future BikeShow multi-session composition: `useDataSource('diffs', { session: 'holden' })`. Enables mock providers for testing. TypeScript enforces contract at compile time.
- DR-4 (Protocol types): Shared TypeScript message types (`telemetry`, `session:start/meta/end`, `sprint:event`, `notification`, `catchup`, `changelog`, `subscribe/ack`) defined in `@pennyfarthing/core` during extraction. Structurally needed — BikeShop client module in BikeRack will import these types.
- DR-8 (Cyclist identity): Cyclist is a focused IDE package, not a thin wrapper. The extraction removes shared infrastructure, not Cyclist's unique contribution. Three-peer model (BikeRack observes, Cyclist controls, BikeShop aggregates) is load-bearing.
- Package naming: `@pennyfarthing/bikerack` — the session observer, full non-Electron product for single-session local use
- Core post-extraction contents: `DataSource<T>` interface, panel components, protocol message types, shared UI primitives, types, styles

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | Epic 1 | Server stack extraction to `packages/bikerack/` |
| FR2 | Epic 1 | BikeRack entry point / launcher |
| FR3 | Epic 1 | Display component migration |
| FR4 | Epic 1 | WebSocket + OTLP migration from Cyclist |
| FR5 | Epic 1 | `DataSource<T>` interface in core |
| FR6 | Epic 1 | Panel hook refactor to consume DataSource |
| FR7 | Epic 1 | `WebSocketDataSource` implementation |
| FR8 | Epic 1 | Cyclist rewired to depend on BikeRack |
| FR9 | Epic 1 | `IS_BIKERACK` removal |
| FR10 | Epic 1 | `/ws/claude` channel registration change |
| FR11 | Epic 1 | Panel components stay in core |
| FR12 | Epic 1 | Cyclist retains IDE control plane |

## Epic List

### Epic 1: BikeRack Standalone Package Extraction

Developers can install and run BikeRack (`npm install @pennyfarthing/bikerack`) without Electron. Cyclist works unchanged as a focused IDE that depends on BikeRack. Panel components consume a typed `DataSource<T>` interface enabling future data sources (BikeShop SQLite, capture replay). The package boundary is clean for BikeShop client code to land in BikeRack.

**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR8, FR9, FR10, FR11, FR12
**NFRs covered:** NFR1, NFR2, NFR3, NFR4, NFR5, NFR6
**DRs addressed:** DR-1, DR-4, DR-8
**Estimated size:** ~18 points across 6 stories

## Epic 1: BikeRack Standalone Package Extraction

Developers can install and run BikeRack (`npm install @pennyfarthing/bikerack`) without Electron. Cyclist works unchanged as a focused IDE that depends on BikeRack. Panel components consume a typed `DataSource<T>` interface enabling future data sources (BikeShop SQLite, capture replay). The package boundary is clean for BikeShop client code to land in BikeRack.

### Story 1.1: Extract Server Engine into `packages/bikerack/`

**Points:** 5

As a **Pennyfarthing developer**,
I want the server engine (Express, API routes, OTLP receiver, file watchers, settings) extracted into `packages/bikerack/`,
So that BikeRack has its own package with the complete non-Electron server stack.

**Acceptance Criteria:**

**Given** the server code currently lives in `packages/core/src/server/`
**When** the extraction is complete
**Then** `packages/bikerack/src/` contains: Express app factory, route mounting, all 30+ API routers, OTLP receiver interface, file watchers (sprint, session, git), settings management, story-parser, sprint-data, env detection, paths resolution
**And** `packages/bikerack/` has its own `package.json` with `@pennyfarthing/bikerack` name
**And** `packages/bikerack/` builds independently via the monorepo build toolchain
**And** no Electron dependency exists in `packages/bikerack/package.json`

### Story 1.2: Move WebSocket and OTLP from Cyclist to BikeRack

**Points:** 3

As a **Pennyfarthing developer**,
I want the real WebSocket channel handlers and OTLP implementation moved from Cyclist to BikeRack,
So that BikeRack owns the complete data pipeline without depending on Cyclist.

**Acceptance Criteria:**

**Given** WebSocket handlers (~1,600 lines) and OTLP processing (~1,000 lines) currently live in `packages/cyclist/src/`
**When** the migration is complete
**Then** all 15 WebSocket channel handlers are in `packages/bikerack/`
**And** the real OTLP receiver implementation is in `packages/bikerack/`
**And** core retains only interface stubs (not implementations)
**And** BikeRack can start its server and serve all WebSocket channels without Cyclist

### Story 1.3: Introduce `DataSource<T>` and Refactor Panel Hooks

**Points:** 3

As a **Pennyfarthing developer**,
I want a typed `DataSource<T>` provider interface in core and all panel hooks refactored to consume it,
So that panels can render data from any source (live WebSocket, SQLite, replay) through a single typed contract.

**Acceptance Criteria:**

**Given** panel hooks currently use hardcoded WebSocket URLs
**When** the DataSource refactor is complete
**Then** `@pennyfarthing/core` exports a `DataSource<T>` typed provider interface
**And** 11+ panel hooks (`useSprint`, `useGitStatus`, `useDiffs`, etc.) consume `DataSource<T>` instead of direct WebSocket URLs
**And** the interface supports parameterized queries: `useDataSource('diffs', { session: 'holden' })`
**And** `WebSocketDataSource` is implemented in `packages/bikerack/` for live local data
**And** TypeScript enforces the contract at compile time — a missing implementation is a build error
**And** mock providers can be created for testing

### Story 1.4: Rewire Cyclist to Depend on BikeRack

**Points:** 3

As a **Pennyfarthing developer**,
I want Cyclist to import `@pennyfarthing/bikerack` as a dependency for data infrastructure,
So that Cyclist is a focused IDE that gets server engine, WebSocket, and data pipeline from BikeRack.

**Acceptance Criteria:**

**Given** Cyclist currently contains server engine and WebSocket code directly
**When** the rewiring is complete
**Then** `packages/cyclist/package.json` lists `@pennyfarthing/bikerack` as a dependency
**And** Cyclist starts BikeRack's server engine on launch
**And** Cyclist wires ClaudeService and registers the `/ws/claude` channel on top of BikeRack's server
**And** `IS_BIKERACK` env var is removed — mode is determined by entry point and service registration
**And** `/ws/claude` channel only exists when ClaudeService registers it (BikeRack never registers it)
**And** Cyclist's IDE control plane (ClaudeService, MessagePanel, bell mode, Reflector, TirePump, permissions, dockview) remains in `packages/cyclist/`

### Story 1.5: Move Display Components and Update Entry Points

**Points:** 2

As a **Pennyfarthing developer**,
I want BikeRack's display components and entry points consolidated in `packages/bikerack/`,
So that BikeRack is a complete standalone product with its own UI and launcher.

**Acceptance Criteria:**

**Given** BikeRackWorkspace, BikeRackIndex, StandalonePanel currently live in `packages/core/src/public/`
**And** the BikeRack entry point is `bikerack.ts` (52 lines) in `packages/cyclist/`
**When** the migration is complete
**Then** BikeRackWorkspace, BikeRackIndex, StandalonePanel are in `packages/bikerack/`
**And** the entry point is expanded in `packages/bikerack/src/index.ts` with full launcher (start server + Claude CLI) and cleanup (port file, process management)
**And** `pf bikerack start` works and launches the standalone BikeRack product
**And** panel components remain in core (shared by BikeRack, Cyclist, and future BikeShop)
**And** port 2898 convention is preserved for BikeRack (vs 1898 for Cyclist)

### Story 1.6: CI, Build, and Test Fixup

**Points:** 2

As a **Pennyfarthing developer**,
I want the CI pipeline, build configuration, and test suite updated for the new package structure,
So that the monorepo builds, tests, and publishes correctly with three packages (core, bikerack, cyclist).

**Acceptance Criteria:**

**Given** the monorepo previously had core, cyclist, and shared packages
**When** the CI/build fixup is complete
**Then** `pnpm build` succeeds across all packages with correct dependency ordering
**And** all existing tests pass with updated import paths
**And** CI pipeline handles `packages/bikerack/` as a build and test target
**And** package publish configuration is correct for `@pennyfarthing/bikerack`
**And** `npm install @pennyfarthing/bikerack` works in isolation without pulling Electron
