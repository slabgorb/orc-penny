# Proposal: Extract BikeRack from Cyclist

**Author:** M. Pursifull
**Date:** 2026-02-20
**Status:** Draft
**Companion:** [BikeShop PRD (revised)](bikeshop-prd-revised.md) — the BikeShop PRD with terminology corrected to reflect this proposal

## Problem

BikeRack is trapped inside Cyclist. Its entry point (`bikerack.ts`, 52 lines) lives in `packages/cyclist/`. Its display components (`BikeRackWorkspace.tsx`, `BikeRackIndex.tsx`, `StandalonePanel.tsx`) live in `packages/core/src/public/`. The server engine (Express, WebSocket, OTLP, file watchers, API routes) also lives in core under the name "WheelHub." There is no `packages/bikerack/`.

This means you need Cyclist installed to run BikeRack, which defeats the purpose. BikeRack exists so developers can skip Electron. Depending on Electron to skip Electron is wrong.

The deeper problem is that **WheelHub and BikeRack are not two things.** WheelHub is the internal name for the server engine. BikeRack is the product that runs it. The current code treats them as separate concerns with `IS_BIKERACK` as a mode flag between them, but there's no real boundary — BikeRack is just WheelHub started without Electron.

## The Insight

The original version of this proposal described BikeRack and WheelHub as separate components with an interface between them — BikeRack subscribing to WheelHub's events, injecting notifications back in. That created phantom interfaces that don't need to exist.

The truth is simpler: **BikeRack is everything that isn't Electron.** WheelHub is an implementation detail inside BikeRack, the way Express is an implementation detail inside WheelHub. There's one process, not two.

This matters for BikeShop. When BikeRack detects a sprint file mutation and forwards a notification to BikeShop, that's not a handoff between two components — it's one process detecting an event (via its file watcher) and sending it upstream (via its BikeShop connection). When BikeShop sends a notification back, BikeRack receives it and broadcasts it on its own WebSocket channels. No injection API needed. It's already the thing that owns those channels.

## Proposed Architecture

```
The Bike (Claude Code + Pennyfarthing)
    ↓ OTEL spans
BikeRack (packages/bikerack/)
  ┌──────────────────────────────────────────┐
  │  Server engine (currently "WheelHub")    │
  │  - Express HTTP + API routes             │
  │  - OTLP receiver                         │
  │  - WebSocket channels (15 channels)      │
  │  - File watchers (sprint, session, git)  │
  │  - Settings management                   │
  ├──────────────────────────────────────────┤
  │  DataSource providers                    │
  │  - WebSocketDataSource (live local data) │
  │  - Implements DataSource<T> from core    │
  ├──────────────────────────────────────────┤
  │  Display                                 │
  │  - Panel components (shared with Cyclist)│
  │  - BikeRack layouts (workspace, index)   │
  │  - Standalone panel mode (?panel=X)      │
  ├──────────────────────────────────────────┤
  │  Session lifecycle                       │
  │  - Launcher (starts server + Claude CLI) │
  │  - Cleanup (port file, process mgmt)     │
  ├──────────────────────────────────────────┤
  │  BikeShop connection (optional, new)     │
  │  - Auth (OpenSSH keypair / BikeShopPass) │
  │  - Span forwarding                       │
  │  - Notification receive/broadcast        │
  │  - Topic subscription (epic, repo, sprint│
  │    declared on connect, updated on change│
  │  - Local cache + flush on reconnect      │
  │  - Catch-up request on connect           │
  └──────────────────────────────────────────┘
      ↑ optional
      │
  BikeShop (team server) → ShowRoom

@pennyfarthing/core (shared)
  - DataSource<T> provider interface
  - Panel components (consume DataSource<T>)
  - Shared UI primitives, types, styles

Cyclist (separate package, depends on BikeRack)
  - AI coding IDE — controls the session it owns
  - ClaudeService (session lifecycle ownership)
  - MessagePanel (primary interaction surface)
  - Bell mode, Reflector, TirePump, Permissions
  - Dockview spatial workspace
  - Electron shell, IPC, menus
  - Imports BikeRack for data infrastructure
  - Gets BikeShop connectivity for free
```

## What Changes

### 1. Create `packages/bikerack/`

Absorb the non-Electron stack into a single package:

**From `packages/cyclist/`:**
- `bikerack.ts` → `packages/bikerack/src/index.ts` (entry point, expanded)

**From `packages/core/src/server/`:**
- `server.ts` — Express app factory, route mounting
- `env.ts` — mode detection (simplified, no more `IS_BIKERACK`)
- `otlp-receiver.ts` — telemetry provider interface
- `settings.ts` — config management
- `paths.ts` — project directory resolution
- `story-parser.ts`, `sprint-data.ts` — data parsing
- `api/` — all 30+ API routers

**From `packages/core/src/public/`:**
- `BikeRackWorkspace.tsx`, `BikeRackIndex.tsx`, `StandalonePanel.tsx` — BikeRack-specific layouts

**From `packages/cyclist/src/`:**
- `websocket.ts` — WebSocket channel handlers (the real ones, not core's stubs)
- `otlp-receiver.ts` — real OTLP implementation

**Stay in core (shared):**
- Panel components (`SprintPanel`, `GitPanel`, `DiffsPanel`, etc.) — used by both BikeRack and Cyclist
- Shared UI primitives, styles, types

### 2. Cyclist becomes a focused IDE package

After extraction, Cyclist contains the irreducible control plane for an AI coding session — the capabilities that make it an IDE, not a dashboard:

- **ClaudeService** — session lifecycle ownership (spawn, monitor, restart, stream)
- **MessagePanel** — the primary interaction surface (conversation UI)
- **Bell mode** — message queue injection during Claude work
- **Permissions/ApprovalModal** — tool approval in Cyclist's own UI
- **Reflector markers** — agent-to-UI protocol driving QuickActions
- **TirePump** — context clearing with session reload
- **Dockview layout** — the IDE's spatial workspace
- Electron main process, IPC, menus

Cyclist imports `@pennyfarthing/bikerack` as a dependency for data infrastructure (server engine, WebSocket channels, file watchers, OTEL, DataSource providers). It starts BikeRack's server engine, wires up ClaudeService and the `/ws/claude` channel, and adds its own control plane on top. This means Cyclist automatically gets BikeShop connectivity when BikeRack adds it — no separate integration needed.

### 3. Remove `IS_BIKERACK` as an env var gate

Currently `IS_BIKERACK` gates behavior in WheelHub (skip `/ws/claude`, inject mode into HTML). After extraction:

- The `/ws/claude` channel only exists when Cyclist's `ClaudeService` registers it. BikeRack never registers it. No flag needed.
- Client-side layout (BikeRackWorkspace vs DockviewWorkspace) is determined by the entry point, not a runtime flag.
- `IS_BIKERACK` becomes unnecessary and is removed.

### 4. BikeShop connection lives in BikeRack

The BikeShop client code (auth, span forwarding, notification handling, caching) is a module within `packages/bikerack/`. It's not a separate package because there's no separate consumer — Cyclist gets it through its BikeRack dependency.

BikeRack is the process that:
- Detects events (file watchers, OTLP spans) — it already does this
- Forwards them to BikeShop — new capability
- Receives notifications from BikeShop — new capability
- Broadcasts them on its WebSocket channels — it already does this

The BikeShop connection is just another module inside the same process. The one new interface introduced by the extraction is `DataSource<T>` in core (DR-1) — this is an external contract shared across packages, not an internal BikeRack boundary.

## What This Enables

- **BikeRack installs without Cyclist.** `npm install @pennyfarthing/bikerack` — no Electron.
- **Cyclist installs BikeRack as a dependency.** One dependency, full stack. BikeShop connectivity included.
- **BikeShop connection has clean ownership.** It's a BikeRack module. Not wedged between two components.
- **Future TUI mode** slots in as another entry point / display option within BikeRack.

## Relationship to BikeShop

BikeRack and BikeShop are **peers**, not parent-child. They share panel components from core but have fundamentally different jobs:

```
@pennyfarthing/core  ← shared panel components, DataSource<T>, types, styles
    ↑           ↑              ↑
BikeRack      Cyclist        BikeShop
(observes     (controls       (aggregates
 sessions —    the session —   sessions —
 CLI+browser   IDE, owns       team server,
 dashboard)    lifecycle)      multi-session)
```

BikeRack is a **single-session local product**. It collects telemetry from one Bike, enriches it, and renders panels for that one session.

BikeShop is a **multi-session team product**. It aggregates data from many BikeRacks, persists to SQLite, and serves its own views:

- **ShowRoom** — BikeShop-native UI. Status of the shop itself: connected BikeRacks, active BikeShows, ShopOwners present, BikeShopPass holders, shop health. BikeRack has no concept of any of this.
- **BikeShow** — a configurable multi-bike dashboard. Not a re-presentation of one BikeRack. A BikeShow might display DiffsPanel from Holden's session next to DiffsPanel from Alex's session, aggregate context crash rates across three sessions, or compose panels from different sessions into a single view. This is new multi-session composition that BikeRack doesn't do.
- **Single-bike view** — one configuration of a BikeShow that happens to look like a BikeRack dashboard for a remote session. Just one mode, not the default.

BikeShop needs access to the **underlying data**, not to BikeRack's server engine. It queries SQLite, aggregates across sessions, and feeds shared panel components through its own data pipeline. BikeRack's file watchers, OTEL receiver, session lifecycle, launcher, and local WebSocket channels are irrelevant to BikeShop.

The shared surface is `@pennyfarthing/core` — panel components, the `DataSource<T>` provider interface, types, and styles. Both BikeRack and BikeShop implement the DataSource interface through their own pipelines (see [Design Review Decisions](#design-review-decisions)).

## Design Review Decisions

> Decisions from the [design review checklist](bikeshop-design-review-checklist.md) (2026-02-20) that revise this proposal and the companion BikeShop PRD. Each records the options considered and the rationale for the chosen direction.

### DR-1: DataSource provider abstraction (checklist issues 1, 2, 4)

**Decision:** Introduce a typed `DataSource<T>` provider interface in `@pennyfarthing/core` during the BikeRack extraction. Panel hooks (`useSprint`, `useGitStatus`, `useDiffs`, etc.) consume this interface instead of hardcoded WebSocket URLs.

**Options considered:**
- **(A) WebSocket message shape is the abstraction — do nothing to panels.** Each new data source (BikeShop SQLite, capture replay) re-implements 15 WebSocket channel contracts. Simple to start but N sources × M channels = N×M implementations to keep in sync. Manual enforcement, drift risk, no compile-time safety. Maintenance cost grows with each new source.
- **(B) DataSource provider abstraction — refactor panel hooks.** Panels consume a typed interface. Each source implements it once. N + M instead of N × M. TypeScript enforces the contract. Enables mock providers for testing. Higher upfront cost (~3 points, 11+ hooks), but the extraction already breaks every import path — marginal cost is lower during extraction than as a second pass.
- **(C) Defer — BikeShop ShowRoom doesn't use panel components.** No premature abstraction. But "shared panel components" becomes aspirational until Phase 2, with risk of painting into a corner.

**Chosen:** Option B. The extraction is the right time — import paths are already broken. The interface bridges BikeRack (WebSocketDataSource), BikeShop Phase 2 (SQLiteDataSource), and future capture replay (ReplayDataSource). Testing benefits are immediate.

**Impact:** The original proposal's claim that "the extraction does not need to make BikeRack's data sources pluggable" is revised. The DataSource interface is real, justified, and load-bearing. It is the shared contract between panel components and any data source. Add ~3 points to the extraction estimate.

**Downstream:** Resolves the BikeShop PRD's Phase 1 / Phase 2 tension. Phase 1 ShowRoom is BikeShop-native UI (no panel components, no DataSource wiring). Phase 2 BikeShow adds a SQLiteDataSource and feeds shared panels through the typed interface. Phase 1's only forward obligation is SQLite schema design that supports future DataSource queries.

### DR-2: OpenSSH keypair auth from MVP (checklist issue 6)

**Decision:** Use OpenSSH keypair authentication (BikeShopPass) from MVP. No shared-secret phase.

**Options considered:**
- **(A) Shared-secret token for MVP, SSH keypair in Phase 2.** Fast onboarding (paste a token), but revoking one person rotates everyone's token. Operationally hostile at team scale. Forced reconnections disrupt the persistent connections the push notification system depends on. Builds throwaway auth code.
- **(B) OpenSSH keypair from MVP.** Per-identity revocation without team-wide disruption. Developers already have `~/.ssh/` infrastructure. No throwaway code. Higher onboarding ceremony (generate key, register pubkey with operator).
- **(C) Registration token exchanged for persistent keypair on first connect.** Shared-secret simplicity for onboarding, SSH keypair lifecycle after. More moving parts than either pure approach.

**Chosen:** Option B. The target audience manages SSH keys daily. The onboarding ceremony is familiar, not foreign. Per-identity lifecycle is essential for a team product. Avoids building and later replacing shared-secret auth.

**Impact:** Revised PRD must move SSH keypair auth from Phase 2 to Phase 1. Remove all shared-secret references (FR14, FR21, FR22, NFR11, NFR12). Rewrite Journey 6 (Operator Setup) and Journey 7 (New Member) around key registration. Update the architecture diagram's auth line.

### DR-3: Notification filtering — stepped approach (checklist issue 5)

**Decision:** Target pub/sub topic-based filtering (Option C: coarse server, fine client), but implement as a stepped progression starting with broadcast-all in MVP.

**Options considered:**
- **(A) BikeShop filters per-BikeRack.** Highest quality filtering — BikeShop has full team context. But requires per-session relevance logic on the server. N BikeRacks × M events = N×M evaluations server-side. Complex from day one.
- **(B) BikeShop broadcasts everything, BikeRack filters locally.** Simple server, scales naturally. But BikeRack lacks team context to filter well — can only match on local state (current story, epic, repo). Results in over-filtering (missed relevant notifications) or under-filtering (noise).
- **(C) BikeShop does coarse topic-based filtering, BikeRack does fine local filtering.** Pub/sub model: BikeRack declares subscription topics on connect (epic, repo, sprint) and updates them as context changes. BikeShop routes by topic. BikeRack filters the remainder against local state. Two filtering stages, but each is simple and operates with the context it actually has.
- **(D) BikeShop broadcasts with enriched metadata, BikeRack matches locally.** Keeps broadcast architecture but makes BikeRack filtering feasible by attaching scope metadata to every notification. Still broadcasts everything to everyone — bandwidth concern remains.

**Chosen:** Option C as the target architecture, with a stepped implementation:

**Step 1 (MVP):** Option B with an immature filter. BikeShop broadcasts all notifications. BikeRack applies a simple local filter: match on current epic, current repo, current story. This is naive but functional for a team of 5–10. Notifications that don't match are silently dropped. No subscription protocol needed — just broadcast and local matching. This ships fast and validates the notification value proposition before investing in routing infrastructure.

**Step 2 (Post-MVP):** Upgrade to Option C. BikeRack declares subscription topics on connect (`{epic: 'MSSCI-14819', repo: 'pennyfarthing-orc', sprint: 'sprint-49'}`). BikeShop maintains a topic → BikeRack routing table and only forwards matching notifications. BikeRack continues fine filtering against local state. The upgrade is backward-compatible — a BikeRack that doesn't declare topics gets everything (Step 1 behavior).

**Rationale for stepped approach:** The notification system's value is in the content (sprint catch-up, story unblocks, changelog delivery), not in the filtering precision. MVP should prove that value. Filtering precision becomes important at scale (10+ sessions generating cross-talk). By then, usage data will inform which topics matter and how fine-grained the routing needs to be.

**Impact:** BikeRack's BikeShop connection module should be designed with topic subscription in mind (the protocol should reserve space for it), even if MVP doesn't implement it. The notification receive path in BikeRack should be a filter chain that starts with the naive matcher and can be extended.

### DR-4: BikeRack ↔ BikeShop protocol contract (checklist issue 9)

**Decision:** Single authenticated WebSocket connection with a typed message envelope. Telemetry payloads use OTEL span format. Control messages (notifications, catch-up, lifecycle, subscriptions) use purpose-built typed messages.

**Options considered:**
- **(A) OTEL-native for everything.** Forward enriched OTEL spans as-is. Encode notifications and lifecycle events as synthetic OTEL spans with custom attributes. Single format, standard tooling works end-to-end. But notifications and catch-up don't fit the span model — spans represent operations with duration, not state deltas. Bidirectional communication (BikeShop → BikeRack) doesn't fit OTEL at all — OTEL is unidirectional (exporter → collector).
- **(B) Custom WebSocket protocol for everything.** Define a message envelope (`{type, sessionId, timestamp, payload}`) with typed message kinds. Clean fit for all concerns, bidirectional on a single connection. But not OTEL-native — BikeShop can't use standard OTEL receivers, and capture files are in a custom format.
- **(C) Hybrid — OTEL for telemetry, custom for control plane.** Two channels: OTLP (gRPC or HTTP) for telemetry, custom WebSocket for control. Clean separation of data plane and control plane. But two connections per BikeRack, two reconnection paths, two protocol lifecycles. More infrastructure to maintain.
- **(D) Custom WebSocket with OTEL-shaped telemetry payloads.** Single WebSocket connection with the typed envelope from Option B, but telemetry message payloads use OTEL span format (JSON serialization of OTLP spans). Single connection, typed routing, bidirectional. Telemetry payloads reuse OTEL parsing on ingestion. Not pure OTEL (can't point a standard collector at it), but BikeShop is a custom server anyway.

**Chosen:** Option D. Single connection simplifies reconnection, auth, and caching. Typed envelope gives clean routing for all message kinds. OTEL-shaped telemetry payloads let BikeShop reuse span parsing logic without requiring full OTEL infrastructure. Capture/replay gets a format for free — the capture file is the timestamped message stream.

**Protocol shape:**

```
BikeRack → BikeShop messages:

  telemetry         Enriched OTEL span (JSON OTLP format)
  session:start     {agent, story, repo, branch, workflow, identity}
  session:meta      Session metadata update (agent change, story switch, etc.)
  session:end       {reason}
  sprint:event      {eventType, story, details}
  subscribe         {topics: string[]} (post-MVP, reserved per DR-3)

BikeShop → BikeRack messages:

  notification      {scope, eventType, content, metadata}
  catchup           {events: CatchupEvent[], fromTimestamp, toTimestamp}
  changelog         {fromVersion, toVersion, entries}
  subscribe:ack     {topics: string[]} (post-MVP, reserved per DR-3)

Envelope (both directions):

  {
    type:      MessageType,
    sessionId: string,
    timestamp: number,
    payload:   <typed per message type>
  }
```

**Design constraint from DR-1:** The `telemetry` and `session:meta` payloads must carry enough data for BikeShop to populate SQLite and answer any `DataSource<T>` query. The design process is: DataSource types → SQLite schema → message payloads that populate that schema. This is the backward-from-output approach — the DataSource interface defines what must be queryable, the protocol defines what must be transmitted to make it queryable.

**Connection lifecycle:**
1. BikeRack opens WebSocket to BikeShop URL
2. BikeRack authenticates with OpenSSH keypair (DR-2) — key challenge/response over the WebSocket before any data messages
3. BikeRack sends `session:start` with identity and current context
4. BikeShop responds with `catchup` (delta since last session) and `changelog` (if version changed)
5. Steady state: BikeRack streams `telemetry` and `sprint:event`; BikeShop sends `notification` as events occur
6. On disconnect: BikeRack caches messages locally. On reconnect: re-auth, `session:start`, BikeShop sends new `catchup`, BikeRack flushes cached messages

**Capture format:** The capture file is the message stream with timestamps — one message per line, JSON, ordered by timestamp. Replay reads the file and feeds messages through a `ReplayDataSource` (DR-1) or through a replay server that re-serves the WebSocket channels. Both paths work because the message format is the same.

**Impact:** This contract must be defined formally (TypeScript types in `@pennyfarthing/core`) before BikeShop implementation begins. The types are shared — BikeRack's client module imports them to produce messages, BikeShop imports them to consume. The `subscribe` and `subscribe:ack` message types are reserved but not implemented in MVP (DR-3).

### DR-5: BikeShow scope and layout strategy (checklist issue 3)

**Decision:** BikeShow is delivered in two steps within Phase 2, using dockview-react for layout composition instead of a custom layout engine.

**Options considered:**
- **(A) Acknowledge as infrastructure, size as its own epic.** BikeShow's multi-session composition system (columns, session cards, configurable panel rows) is built as reusable layout infrastructure. Honest sizing but Phase 2 balloons — the PRD currently treats BikeShow as one line item.
- **(B) Simplify — single-bike view only in Phase 2, multi-session in Phase 3.** Validates SQLiteDataSource pipeline without layout complexity. But pushes the compelling vision (Journey 8) to Phase 3, weakening BikeShow's value proposition. Single-bike view is "BikeRack but remote" — not differentiated.
- **(C) Use dockview-react for layout, not a custom engine.** dockview-react (already a Cyclist dependency, framework-agnostic) handles panel arrangement, resize, drag-and-drop. Per-session identity cards (portrait, workflow iconograph, velocity) are custom components. The composition problem becomes "use dockview with multi-session DataSources" rather than "build a layout framework."

**Chosen:** Option C with Option B as a stepping stone.

**Step 1 (Phase 2 early):** Single-bike view. BikeShop serves a `SQLiteDataSource` for one remote session, panels render in the browser. Validates the full DataSource pipeline (DR-1) end-to-end: BikeRack → DR-4 protocol → BikeShop SQLite → SQLiteDataSource → panel components. No layout complexity.

**Step 2 (Phase 2 late):** Multi-session BikeShow. dockview-react provides the layout framework. Each panel is parameterized by session via `useDataSource('diffs', { session: 'holden' })` (DR-1). Per-session identity cards (portrait, context gauge, workflow map, velocity) are new custom components rendered within dockview panels. Configurable panel rows are dockview panel groups.

**Impact:** The revised PRD should split Phase 2 BikeShow into two deliverables and acknowledge Step 2 as the larger half. Journey 8 stays in Phase 2 but maps to Step 2, not to a single feature. The per-session identity card components (portrait, workflow iconograph, context sparkline, velocity indicator) should be sized individually — they are custom UI work even though the layout framework is off-the-shelf.

### DR-6: Appendix idea compatibility with new architecture (checklist issue 10)

**Assessment:** Three ideas from the BikeRack PRD appendix (Ideas A–N) need compatibility annotations after the extraction and design review decisions. The rest are unaffected.

**Idea D (Capture/Replay) — Compatible, works better.**
DR-4 defines the capture format: the timestamped BikeRack ↔ BikeShop message stream (one JSON message per line, ordered by timestamp). DR-1 defines the replay consumer: `ReplayDataSource` implements the typed `DataSource<T>` interface and feeds panel components from a capture file. Capture operates at two levels:
- BikeRack captures locally (no BikeShop required) — writes its own outbound message stream to disk
- BikeShop captures per-session — writes inbound messages to disk alongside SQLite ingestion

The original idea assumed BikeRack was a lightweight launcher capturing a raw telemetry stream. The new architecture is richer — BikeRack captures the full enriched message stream, which includes session metadata, sprint events, and lifecycle markers alongside OTEL spans. No revision needed.

**Idea F (Failover) — Compatible, simpler than described.**
The original idea described failover as redirecting a telemetry stream, implying the whole BikeRack process switches targets. Under the extraction, BikeRack is the full local server — it doesn't fail over. Its BikeShop *connection module* fails over:
- BikeRack keeps running locally (panels work, file watchers work, Claude CLI unaffected)
- Only the upstream WebSocket connection switches from preferred to alternate BikeShop
- Cached messages (DR-4 envelope format) flush to the alternate on failover
- Timers, holddown, and preference swapping operate on the connection module, not the process

This is connection-level failover, not process-level. The idea's mechanics all hold at smaller, cleaner scope. The original ideas doc's user stories (US-F2, US-F3, US-F4) are accurate — the developer experience is identical. Only the internal implementation is simpler.

**Idea C (Cross-BikeShop Casting) — Compatible, relay is cleaner.**
DR-4's typed message envelope makes BikeShop-to-BikeShop relay straightforward: the relaying BikeShop receives typed messages from upstream and forwards them downstream. The protocol is the same in both directions. BikeShop-side features described in the idea (port remapping, visual routing topology in ShowRoom, remote control via BikeShopKey) are unaffected by the extraction — they're BikeShop UI concerns.

**Ideas A, B, E, G–N — Unaffected.**
These are BikeShop-side features (ShowRoom, leaderboards, races, RaceCoach), CLI-side features (panel focus), or collaboration features (TeamGear, Tandem) that interact with BikeRack through the DR-4 protocol or through BikeShop's own UI. The extraction and design review decisions don't change their design.

### DR-8: Cyclist remains a separate package (checklist issue 8)

**Decision:** Cyclist stays as `packages/cyclist/`, a separate package that depends on `@pennyfarthing/bikerack`. It is not a build target of BikeRack.

**Options considered:**
- **(A) Keep Cyclist as a separate package.** Clean separation. Electron build toolchain (electron-builder, code signing, DMG packaging) stays isolated. `npm install @pennyfarthing/bikerack` remains Electron-free.
- **(B) Cyclist becomes a build target of BikeRack.** One package, `--target electron` produces the Electron app. Eliminates cross-package coordination. But Electron becomes a conditional dependency, build pipeline complexity increases, and Electron's native module toolchain contaminates BikeRack's simpler build.
- **(C) Same as A, explicitly documented as "thin shell."** Acknowledges Cyclist's small post-extraction codebase. Sets expectations.

**Chosen:** Option A, but the "thin shell" framing from Option C is rejected.

**Rationale:** Cyclist is not "BikeRack + Electron." It is an IDE that shares data infrastructure with BikeRack. The extraction moves observability and data infrastructure out of Cyclist — infrastructure that was never Cyclist's unique contribution, just code that happened to live there first. What remains in Cyclist is the irreducible control plane for an AI coding session:

- **ClaudeService** — session lifecycle ownership (spawn, monitor, restart, stream conversation state). BikeRack connects to an external CLI. Cyclist *is* the CLI experience, replaced and improved.
- **MessagePanel** — the primary interaction surface. The IDE's editor pane. Not one panel among fifteen.
- **Bell mode** — message queue injection during Claude work. A Cyclist-native interaction pattern with no BikeRack equivalent.
- **Permissions/ApprovalModal** — tool approval intercepted and presented in Cyclist's own UI.
- **Reflector markers** — agent-to-UI protocol driving QuickActions. Cyclist interaction intelligence. BikeRack has no conversation surface to drive.
- **TirePump** — context clearing with session reload. Cyclist manages the session it owns.
- **Dockview layout** — the IDE's spatial workspace, not just "panel arrangement."

These capabilities are unique to Cyclist and must not be present in BikeRack or BikeShop. The three products have distinct control boundaries:

- **BikeRack** observes a session it doesn't control
- **BikeShop** aggregates sessions it doesn't control
- **Cyclist** controls the session it owns

The three-peer model holds because the peers have distinct roles, not just distinct codebases. Measuring Cyclist's post-extraction value by lines of code is a statistical illusion — it confuses shared infrastructure with product identity.

**Impact:** The extraction proposal's "Cyclist becomes a thin Electron wrapper" language should be revised. Cyclist becomes a focused IDE package — smaller in shared infrastructure code, unchanged in unique capability. The peer diagram in the Relationship to BikeShop section should annotate Cyclist's role as session controller, not just "+ Electron."

### DR-7: Docker deployment (checklist issue 7)

**Decision:** Docker is the deployment model for BikeShop. No revision to the PRD needed.

**Options considered:**
- **(A) Docker-only.** BikeShop ships as a Docker image. Clean isolation, reproducible, familiar deployment pattern for server processes. Requires container runtime on the host.
- **(B) Node.js process only.** `pf bikeshop start` runs a bare Node process. Zero new dependencies for Node.js users. But no isolation, no built-in process supervision, host Node.js version dependency.
- **(C) Node.js primary, Docker as alternative.** Ship both distribution paths. Lowest friction for casual use, Docker for production. But two paths to maintain, documentation complexity.
- **(D) Node.js primary, Dockerfile included but not officially shipped.** One official path (npm), Dockerfile as a convenience. But Docker users must build their own image.

**Chosen:** Option A. The team is k8s-first infrastructure. Every team member runs OrbStack locally. Production deployments target Kubernetes. Docker is not added friction for this audience — it's the expected deployment model. Container isolation, reproducibility, and consistency with the team's existing infrastructure stack justify Docker as the primary and only official distribution path.

**No impact to other decisions.** Deployment model is orthogonal to the DataSource abstraction (DR-1), auth (DR-2), protocol (DR-4), and all other architectural choices.

## What This Does NOT Change

- Panel components — stay in core, shared by all packages. Now consume `DataSource<T>` instead of hardcoded WebSocket URLs (DR-1), but the components themselves remain in core.
- BikeShop PRD functional requirements — all hold, updated for OpenSSH auth (DR-2), stepped notification filtering (DR-3), typed protocol (DR-4), and phased BikeShow delivery (DR-5)
- The developer experience — `pf bikerack start` still works, Cyclist still works

## Sizing

This is not a small refactor. It reorganizes the package boundaries of the monorepo.

**Scope:** Extract ~4,000 lines of server code from core, ~1,600 lines of WebSocket handlers and ~1,000 lines of OTLP processing from cyclist, plus display components, into a new package. Rewire Cyclist to depend on the new package. Remove `IS_BIKERACK` gating. Introduce DataSource provider interface and refactor panel hooks. Update build config, test imports, CI.

**Estimate:** Epic-sized. Likely 4–6 stories:
1. Create `packages/bikerack/` with server engine extracted from core (~5 pts)
2. Move WebSocket + OTLP from cyclist into bikerack (~3 pts)
3. Introduce `DataSource<T>` interface in core, refactor 11+ panel hooks to consume it, implement `WebSocketDataSource` in bikerack (~3 pts) *(DR-1)*
4. Rewire Cyclist to depend on bikerack, remove `IS_BIKERACK` (~3 pts)
5. Move BikeRack display components, update entry points (~2 pts)
6. CI, build, test fixup (~2 pts)

**Total:** ~18 points. This is a prerequisite for BikeShop work — BikeShop's client code needs a home, and that home is BikeRack.

## Open Questions

1. **What stays in `@pennyfarthing/core`?** After the extraction, core contains: `DataSource<T>` interface (DR-1), panel components, protocol message types (DR-4), shared UI primitives, types, and styles. This is a substantial shared contract layer — justified as a package. Leaning confirmed: core is the shared contract + UI layer.

2. **Port assignment.** BikeRack currently uses 2898 (vs Cyclist's 1898). Keep this convention or make it fully dynamic?

3. **Package naming.** `@pennyfarthing/bikerack` is the obvious choice. BikeRack is the session observer — the full non-Electron product for single-session local use. The name originally meant "standalone panel viewer" but now means the data infrastructure product. This is fine — the metaphor holds (a rack holds one bike and displays it).
