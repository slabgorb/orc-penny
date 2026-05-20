# ADR-0030: BikeRack Standalone Package Extraction

**Status:** Proposed (Needs Revision — see ADR-0034)
**Date:** 2026-02-24
**Author:** architect (Vito Cornelius)
**Supersedes:** [ADR-0026: Single Package Consolidation](0026-single-package-consolidation.md)
**Extends:** [ADR-0024: BikeRack Mode](0024-bikerack-mode.md)
**Epic:** PROJ-15551
**Source:** [Extraction Proposal](../../sprint/planning/bikerack-extraction-proposal.md) (M. Pursifull, 2026-02-20), [Design Review Checklist](../../sprint/planning/bikeshop-design-review-checklist.md) (10 issues resolved)

## Context

ADR-0024 established BikeRack as a runtime mode within Cyclist — WheelHub started with `IS_BIKERACK=1`, skipping ClaudeService. This works but creates a dependency paradox: BikeRack exists so developers can skip Electron, yet it requires `@pennyfarthing/cyclist` (which bundles Electron and node-pty) to run.

ADR-0026 proposed solving this by consolidating all packages into `@pennyfarthing/core`. That approach eliminates the dependency wall but collapses architectural boundaries that are load-bearing for the BikeShop team server product on the roadmap.

The extraction proposal (M. Pursifull, 2026-02-20) identified the deeper problem: **BikeRack and WheelHub are not two things.** WheelHub is an implementation detail inside BikeRack. BikeRack is everything that isn't Electron. The `IS_BIKERACK` env var is a mode flag masking what should be a package boundary.

### Why ADR-0026 is superseded

ADR-0026's thesis — one npm package, zero native modules — correctly identified the install pain. But consolidating everything into core creates a monolith where three products with distinct control boundaries (observe, control, aggregate) share one undifferentiated package. This blocks clean ownership for BikeShop and makes the dependency graph lie about what depends on what.

The three products have fundamentally different jobs:

- **BikeRack** observes a session it doesn't control
- **Cyclist** controls the session it owns
- **BikeShop** aggregates sessions it doesn't control

These distinctions are architectural, not cosmetic. A package boundary enforces them at the dependency level.

### Design review findings

A formal design review (M. Pursifull, 2026-02-20) identified and resolved 10 architectural issues. The key findings that shape this decision:

1. **Panel data abstraction is required** (Issue 1) — Panels today are coupled to BikeRack's WebSocket channel contracts. For panels to render data from any source (live, SQLite, replay), a typed `DataSource<T>` provider interface must exist in core.

2. **Cyclist is not "paper-thin" after extraction** (Issue 8) — Cyclist retains the irreducible IDE control plane: ClaudeService, MessagePanel, bell mode, Reflector, TirePump, permissions, dockview. Measuring post-extraction value by lines of code confuses shared infrastructure with product identity.

3. **The BikeRack-to-BikeShop protocol needs a typed contract** (Issue 9) — Protocol message types defined in core enable both BikeRack's client module and BikeShop's server to share a compile-time-checked interface.

## Decision

Extract BikeRack from Cyclist into `packages/bikerack/` as a standalone npm package. Introduce a `DataSource<T>` provider interface in core. Define protocol message types in core. Remove the `IS_BIKERACK` env var gate.

### New package topology

```
@pennyfarthing/core            Shared contracts + UI
├── DataSource<T> interface    Provider abstraction for panel data
├── Protocol message types     BikeRack ↔ BikeShop contract (DR-4)
├── Panel components           Consumed by BikeRack, Cyclist, BikeShop
├── Shared UI primitives       Styles, types, Radix components
└── CLI + framework            Agents, workflows, guides, scripts

@pennyfarthing/bikerack        Session observer + data infrastructure
├── Server engine              Express app, API routes (30+), static serving
├── WebSocket channels (15)    Real implementations (from cyclist)
├── OTLP receiver              Real implementation (from cyclist)
├── File watchers              Sprint, session, git
├── WebSocketDataSource        Implements DataSource<T> for live data
├── Settings management        Config read/write
├── Launcher                   Start server + Claude CLI, cleanup
└── BikeRack display           BikeRackWorkspace, BikeRackIndex, StandalonePanel

@pennyfarthing/cyclist         AI coding IDE (depends on bikerack)
├── ClaudeService              Session lifecycle ownership
├── MessagePanel               Primary interaction surface
├── Bell mode                  Message queue injection
├── Reflector markers          Agent-to-UI protocol, QuickActions
├── TirePump                   Context clearing + session reload
├── Permissions/ApprovalModal  Tool approval in Cyclist UI
├── Dockview layout            IDE spatial workspace
├── /ws/claude channel         Registered by ClaudeService on startup
└── Electron shell             Main process, IPC, menus

@pennyfarthing/themes-*        Optional theme packs (unchanged)
```

### Dependency graph

```
@pennyfarthing/core
    ↑              ↑
@pennyfarthing/bikerack    (future) @pennyfarthing/bikeshop
    ↑
@pennyfarthing/cyclist
```

Cyclist depends on BikeRack for data infrastructure. BikeRack depends on core for shared contracts and panel components. BikeShop (future) depends on core for the same shared contracts. No circular dependencies. Each package can be installed independently except Cyclist (which needs BikeRack).

### What moves where

**From `packages/core/src/server/` → `packages/bikerack/`:**
- `server.ts` — Express app factory, route mounting
- `api/` — all 30+ API routers
- `env.ts` — mode detection (simplified, `IS_BIKERACK` removed)
- `otlp-receiver.ts` — provider interface
- `settings.ts`, `settings-store.ts` — config management
- `paths.ts` — project directory resolution
- `story-parser.ts`, `story-context.ts`, `agent-context.ts` — data parsing
- `pennyfarthing.ts` — project detection

**From `packages/cyclist/src/` → `packages/bikerack/`:**
- `websocket.ts` (~1,600 lines) — real WebSocket channel handlers
- `otlp-receiver.ts` (~1,000 lines) — real OTLP implementation
- `bikerack.ts` (52 lines) — entry point, expanded into full launcher
- `git-cache.ts`, `git-diff.ts` — git data caching
- `span-enrichment.ts`, `span-correlation.ts` — telemetry enrichment

**From `packages/core/src/public/` → `packages/bikerack/`:**
- `BikeRackWorkspace.tsx` — dockview panel layout for BikeRack
- `BikeRackIndex.tsx` — panel listing page
- `StandalonePanel.tsx` — `?panel=X` full-screen routing

**Stays in `packages/core/`:**
- All panel components (`SprintPanel`, `GitPanel`, `DiffsPanel`, etc.)
- Panel registry
- React contexts, hooks (refactored to consume `DataSource<T>`)
- Shared UI primitives, styles, types
- CLI, agents, workflows, guides, scripts

**Stays in `packages/cyclist/`:**
- ClaudeService, MessagePanel, bell mode, Reflector, TirePump
- Permissions/ApprovalModal, dockview layout
- Electron main process, IPC, menus
- `DockviewWorkspace.tsx`

### DataSource\<T\> provider interface (DR-1)

Panels currently consume hardcoded WebSocket URLs. The extraction introduces a typed provider interface in core:

```typescript
// @pennyfarthing/core — DataSource provider interface

interface DataSource<T> {
  subscribe(callback: (data: T) => void): () => void;
  getSnapshot(): T | null;
}

interface DataSourceProvider {
  sprint: DataSource<SprintData>;
  git: DataSource<GitStatus>;
  diffs: DataSource<DiffData>;
  tokenStats: DataSource<TokenStats>;
  persona: DataSource<PersonaData>;
  story: DataSource<StoryData>;
  auditLog: DataSource<ToolEvent[]>;
  settings: DataSource<SettingsData>;
  // ... remaining panel data types
}

// Panel hooks consume the provider
function useSprint(): SprintData;       // reads from context provider
function useGitStatus(): GitStatus;     // reads from context provider
function useDiffs(): DiffData;          // reads from context provider
```

Each product implements the provider through its own pipeline:

| Product | Implementation | Data source |
|---------|---------------|-------------|
| BikeRack | `WebSocketDataSource` | Live WebSocket channels + file watchers |
| BikeShop (future) | `SQLiteDataSource` | SQLite queries over aggregated session data |
| Testing | `MockDataSource` | Fixture data for unit tests |
| Replay (future) | `ReplayDataSource` | Timestamped capture files |

The interface supports parameterized queries for future multi-session composition: `useDataSource('diffs', { session: 'holden' })`.

### Protocol message types (DR-4)

Shared TypeScript types in core define the BikeRack ↔ BikeShop contract:

```
BikeRack → BikeShop:
  telemetry         Enriched OTEL span (JSON OTLP format)
  session:start     {agent, story, repo, branch, workflow, identity}
  session:meta      Session metadata update
  session:end       {reason}
  sprint:event      {eventType, story, details}
  subscribe         {topics: string[]} (reserved, post-MVP)

BikeShop → BikeRack:
  notification      {scope, eventType, content, metadata}
  catchup           {events[], fromTimestamp, toTimestamp}
  changelog         {fromVersion, toVersion, entries}
  subscribe:ack     {topics: string[]} (reserved, post-MVP)

Envelope (both directions):
  { type, sessionId, timestamp, payload }
```

Types are defined in core and imported by both BikeRack's client module and BikeShop's server. Design works backward from DataSource: DataSource types define what must be queryable → SQLite schema stores it → protocol messages carry enough to populate it.

### IS_BIKERACK removal

The `IS_BIKERACK` env var and `isBikeRackMode()` function are eliminated. After extraction:

- `/ws/claude` only exists when Cyclist's ClaudeService registers it. BikeRack never registers it. No flag needed.
- Client-side layout is determined by entry point (`BikeRackWorkspace` vs `DockviewWorkspace`), not a runtime flag.
- Mode-specific behavior is expressed through package boundaries, not conditional branches.

### Rejected alternatives

**Single package consolidation (ADR-0026)** — Solves install pain but creates an undifferentiated monolith. Three products with distinct control boundaries need distinct packages. The install simplification ADR-0026 sought is preserved: `npm install @pennyfarthing/bikerack` has zero native modules and works standalone.

**Separate server binary** — Over-engineered. WheelHub is an implementation detail of BikeRack, not a separate deployable.

**Microservice split (standalone OTLP receiver)** — The receiver is embedded in the server. Extracting it gains nothing.

**Plugin architecture** — Designing a plugin system for what is a package boundary is textbook over-engineering.

## Implementation

Six stories, ~18 points. See [epic breakdown](../../sprint/planning/bikerack-extraction-epics.md) for full acceptance criteria.

| Story | Points | Scope |
|-------|--------|-------|
| 124-1 | 5 | Extract server engine into `packages/bikerack/` |
| 124-2 | 3 | Move WebSocket + OTLP from Cyclist to BikeRack |
| 124-3 | 3 | Introduce `DataSource<T>`, refactor panel hooks, implement `WebSocketDataSource` |
| 124-4 | 3 | Rewire Cyclist to depend on BikeRack, remove `IS_BIKERACK` |
| 124-5 | 2 | Move display components, update entry points |
| 124-6 | 2 | CI, build, test fixup |

### Implementation consistency rules

1. **Panel components stay in core.** They are shared by BikeRack, Cyclist, and future BikeShop.
2. **Panels receive no product-specific props.** Same components, different `DataSourceProvider` in context.
3. **No `IS_BIKERACK` checks survive.** Package boundary replaces env var gating.
4. **`/ws/claude` is registration-based.** Cyclist registers it via ClaudeService. BikeRack never does.
5. **Port convention preserved.** BikeRack: 2898. Cyclist: 1898.
6. **Entry point determines layout.** `BikeRackWorkspace` (BikeRack) vs `DockviewWorkspace` (Cyclist). No runtime flag.
7. **DataSource interface is the shared contract.** Panels depend on the abstraction, sources implement it.
8. **Protocol types live in core.** Shared by BikeRack client and BikeShop server. Not duplicated.

### Contract enforcement

- **CE-1:** `DataSource<T>` must be a compile-time contract. Missing implementation = build error.
- **CE-2:** Panel hooks must not import from `@pennyfarthing/bikerack` directly. They consume the provider interface from core.
- **CE-3:** Cyclist imports BikeRack's server engine via the package dependency, not by duplicating code.
- **CE-4:** BikeRack's `package.json` must have zero Electron-related dependencies.
- **CE-5:** Protocol message types are defined once in core, imported by consumers. No type duplication.

## Consequences

### Positive

- **BikeRack installs without Cyclist.** `npm install @pennyfarthing/bikerack` — zero native modules, no Electron.
- **Clean ownership for BikeShop.** BikeShop client code lands in BikeRack. Protocol types shared via core. No ambiguity.
- **DataSource enables testing.** Mock providers replace brittle WebSocket-dependent tests.
- **Package boundaries enforce product identity.** BikeRack can't accidentally gain IDE capabilities. Cyclist can't accidentally lose them.
- **Cyclist gets BikeShop connectivity for free.** It imports BikeRack, which includes the BikeShop connection module.
- **IS_BIKERACK elimination.** Five conditional branches replaced by clean package separation.

### Negative

- **Monorepo restructure.** Moving ~6,600 lines across packages is a significant one-time effort.
- **Import path churn.** Every consumer of the moved code needs updated imports. Mitigated by doing the DataSource refactor simultaneously (paths are already breaking).
- **Three packages to version and publish.** More coordination than one, less than twelve.

### Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| DataSource interface wrong on first attempt | High | Medium | Design backward from BikeShop's SQLite queries. Validate with mock provider in tests before committing interface. |
| Circular dependency between bikerack and core | High | Low | Strict rule: core never imports from bikerack. Panels consume interface, not implementation. |
| Cyclist breaks during rewiring | Medium | Medium | Story 124-4 (rewire) has dedicated scope. Test Cyclist end-to-end before merging. |
| Sprint state consolidation conflict | Medium | Low | Sprint data reader in BikeRack designed to accommodate `SprintContext` object (see sprint-state-consolidation-proposal.md). |

## Related

- **[ADR-0024: BikeRack Mode](0024-bikerack-mode.md)** — Established BikeRack as a runtime mode. This ADR promotes it to a package.
- **[ADR-0026: Single Package Consolidation](0026-single-package-consolidation.md)** — Superseded by this ADR. Install simplification preserved; monolith topology rejected.
- **[Extraction Proposal](../../sprint/planning/bikerack-extraction-proposal.md)** — M. Pursifull. Full architectural analysis and design review decisions DR-1 through DR-8.
- **[Design Review Checklist](../../sprint/planning/bikeshop-design-review-checklist.md)** — 10 resolved issues informing this decision.
- **[BikeShop PRD](../../sprint/planning/bikeshop-prd.md)** — Downstream product enabled by this extraction.
- **[Sprint State Consolidation](../../sprint/planning/sprint-state-consolidation-proposal.md)** — M. Pursifull. Adjacent concern — affects how BikeRack reads sprint data.
- **[Epic Breakdown](../../sprint/planning/bikerack-extraction-epics.md)** — FR/NFR mapping, 6 stories with acceptance criteria.
