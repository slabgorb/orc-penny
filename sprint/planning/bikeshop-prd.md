---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain (skipped)
  - step-06-innovation (skipped)
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - sprint/planning/bikerack-prd-ideas.md
  - sprint/planning/bikerack-prd.md
  - sprint/planning/bikerack-extraction-proposal.md
  - docs/adr/0024-bikerack-mode.md
  - sprint/archive/epic-PROJ-14819.yaml
workflowType: 'prd'
documentCounts:
  briefCount: 0
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 5
classification:
  projectType: Server / Developer Infrastructure
  domain: Developer Experience (DX) / Agent Infrastructure
  complexity: High (phased delivery)
  projectContext: brownfield
revisionNote: >
  Revised to reflect BikeRack extraction proposal and design review decisions
  DR-1 through DR-8 (see bikeshop-design-review-checklist.md). Key changes:
  DataSource<T> provider abstraction (DR-1), OpenSSH keypair auth from MVP
  (DR-2), stepped notification filtering (DR-3), typed WebSocket protocol
  (DR-4), BikeShow two-step delivery (DR-5), Docker confirmed (DR-7),
  Cyclist as focused IDE (DR-8).
---

# Product Requirements Document - BikeShop (Revised)

**Author:** Keith Avery
**Date:** 2026-02-20
**Revised by:** M. Pursifull (2026-02-20) — terminology alignment and design review decisions per [BikeRack extraction proposal](bikerack-extraction-proposal.md) and [design review checklist](bikeshop-design-review-checklist.md)

> **Why this revision exists:** The original BikeShop PRD named WheelHub as the component that connects to BikeShop. [That's architecturally incorrect.](bikerack-extraction-proposal.md) WheelHub is the internal name for BikeRack's server engine — not a separate component. BikeRack is the full non-Electron stack: telemetry collection, enrichment, file watchers, WebSocket channels, panel serving, and (new for BikeShop) upstream connectivity. There is no interface boundary between "WheelHub" and "BikeRack" because they are the same process. Additionally, design review decisions (DR-1 through DR-8) revised the auth model, panel data architecture, protocol contract, notification filtering, BikeShow delivery strategy, and Cyclist's role. See the [extraction proposal](bikerack-extraction-proposal.md) for the full architectural rationale and decision records.

## Terminology

| Term | Role |
|------|------|
| **The Bike** | Claude Code + Pennyfarthing — the actual work happening |
| **BikeRack** | The full non-Electron product — collects OTEL telemetry, enriches it, serves panels via browser, runs file watchers, broadcasts via WebSocket. Implements `WebSocketDataSource` for panel data. Optionally connects upstream to a BikeShop via authenticated WebSocket. One BikeRack per developer session. |
| **WheelHub** | Internal name for BikeRack's Express server engine. Not a separate component — an implementation detail, like Express is an implementation detail inside WheelHub. |
| **Cyclist** | AI coding IDE — a separate product that shares data infrastructure with BikeRack. Owns the Claude session lifecycle (ClaudeService), conversation UI (MessagePanel), interaction patterns (bell mode, Reflector, TirePump, permissions), and spatial workspace (dockview). Depends on BikeRack for server engine and data pipeline. Not a thin wrapper — an IDE with a distinct control plane. |
| **BikeShop** | Team aggregation server — receives enriched telemetry from multiple BikeRack instances via typed WebSocket protocol (DR-4), persists to SQLite, computes catch-up deltas, broadcasts notifications, serves the ShowRoom. Implements `SQLiteDataSource` for panel data in Phase 2. |
| **ShowRoom** | BikeShop's web dashboard — session tiles, real-time state, team visibility. BikeShop-native UI (Phase 1). |
| **BikeShow** | Configurable multi-session dashboard served by BikeShop. Composes shared panel components from multiple sessions using dockview-react layout and `SQLiteDataSource` (Phase 2). |
| **BikeShopPass** | OpenSSH keypair for BikeRack authentication. Public key registered with BikeShop, private key held by BikeRack operator. Per-identity — revocation affects one BikeRack, not the team. |
| **DataSource\<T\>** | Typed provider interface in `@pennyfarthing/core`. Panel hooks consume it; data sources (WebSocket, SQLite, replay) implement it. The shared contract between panels and any data pipeline. |

**Data flow:**
```
The Bike (Claude Code)
    ↓ OTEL spans
BikeRack (collect, enrich, serve panels, forward upstream)
    ↓ optional authenticated WebSocket (OpenSSH keypair)
    ↓ typed message envelope (DR-4 protocol)
BikeShop (aggregate, persist, compute, broadcast)
    ↓
ShowRoom (display)        SQLite (persist)
```

**Control boundaries:**
```
@pennyfarthing/core  ← DataSource<T>, panel components, types, styles
    ↑           ↑              ↑
BikeRack      Cyclist        BikeShop
(observes     (controls       (aggregates
 sessions —    the session —   sessions —
 CLI+browser   IDE, owns       team server,
 dashboard)    lifecycle)      multi-session)
```

## Success Criteria

### User Success

- A team lead opens the ShowRoom and immediately understands the state of all active sessions — who's working on what, how far along they are, and whether anyone is stuck
- A developer starting a new session receives relevant context pushed by BikeShop through their BikeRack — recent changelogs, team announcements, relevant pattern updates — without having to go looking for it
- A developer's work is visible to the team through activity sharing without any extra effort on their part — no manual status updates, no standups just to say "I'm on story X"
- Teams can review aggregated data to answer "what's working?" — which workflows produce the fewest rework cycles, which themes correlate with higher velocity, which skills are actually used

### Business Success

- Pennyfarthing adoption moves from individual to team — BikeShop is the reason a team lead says "everyone should use this"
- Operational visibility reduces coordination overhead — fewer "what are you working on?" interruptions, fewer duplicate efforts
- Data-driven workflow optimization — teams iterate on their processes based on real usage data, not gut feel
- BikeShop becomes the connective tissue that makes Pennyfarthing a team product, not just a solo developer tool

### Technical Success

- BikeShop receives enriched telemetry from multiple BikeRack instances simultaneously without data loss or lag
- ShowRoom renders real-time session state with <500ms latency target
- Automated push delivery (changelogs, sprint catch-up, live notifications) reaches sessions within seconds
- OpenSSH keypair authentication (BikeShopPass) works reliably for BikeRack registration and per-identity authorization
- BikeShop runs as a persistent service that stays healthy for days/weeks without intervention

### Measurable Outcomes

| Metric | Target | Measurement |
|--------|--------|-------------|
| Multi-session support | 10+ concurrent BikeRacks streaming to one BikeShop | Load test |
| ShowRoom latency | Session state updates in <500ms | End-to-end timing |
| Push delivery | Automated context reaches new session within 5s of connection | Integration test |
| Uptime | BikeShop stable for 7+ days continuous operation | Operational monitoring |
| Auth reliability | OpenSSH keypair authentication (BikeShopPass) works 100% of the time | Auth test suite |

## Product Scope

### MVP — Phase 1: Team Awareness

1. **BikeShop server** — persistent Docker-deployed service that receives enriched telemetry from multiple BikeRack instances via typed WebSocket protocol (DR-4)
2. **ShowRoom** — web dashboard (BikeShop-native UI) showing all connected sessions with real-time session tiles (agent, story, workflow stage, duration, context %)
3. **OpenSSH keypair authentication (BikeShopPass)** — per-identity keys for BikeRack authentication. Operator registers public keys; BikeRack authenticates with private key on connect. Per-identity revocation without team-wide disruption. (DR-2)
4. **Automated push delivery** — framework changelog on version change, sprint catch-up on connect, live sprint notifications broadcast to all connected BikeRacks. MVP uses broadcast-all with naive local filtering at each BikeRack; topic-based routing deferred to post-MVP. (DR-3)
5. **Connection resilience** — BikeRack caches messages locally (DR-4 envelope format) when BikeShop is down, flushes on reconnect, zero disruption to developer workflow

### Phase 2: Intelligence (Post-MVP)

1. **Analytics dashboard** — workflow comparison, theme correlation, skill tracking, with CSV/JSON export
2. **BikeShow Step 1: single-bike view** — BikeShop serves a `SQLiteDataSource` for one remote session, shared panel components render in the browser. Validates the full DataSource pipeline end-to-end. (DR-5)
3. **BikeShow Step 2: multi-session view** — dockview-react layout composing panels from multiple sessions via parameterized `SQLiteDataSource`. Per-session identity cards (portrait, workflow iconograph, context sparkline, velocity). Configurable panel rows. This is the larger deliverable. (DR-5)
4. **Topic-based notification filtering** — BikeRack declares subscription topics on connect; BikeShop routes by topic instead of broadcasting all. Backward-compatible with MVP BikeRacks. (DR-3)
5. **Session tile sorting/filtering** — by metadata (workflow, agent, story, duration)
6. **Onboarding bundles** — curated first-connect experience for new team members

### Phase 3: Scale (Future)

1. **Queryable REST API** — programmatic access to session and analytics data
2. **Cross-BikeShop casting** — relay telemetry between BikeShops for multi-team visibility
3. **BikeShop failover** — preferred/alternate with failover timer, holddown, auto-failback
4. **Pattern recommendations** — "teams using workflow X on this type of story complete 30% faster"
5. **Leaderboards and races** — sprint-scoped competitions, ad-hoc comparisons

### Vision

1. **Federated BikeShop network** — multiple BikeShops aware of each other, cross-team visibility
2. **AI-driven pattern discovery** — automated insights from aggregate telemetry
3. **BikeShop as the team operating system** — the central nervous system for a team using Pennyfarthing
4. **Mobile ShowRoom** — first-party access to session state from phone

## User Journeys

### Journey 1: Team Lead — Morning Dashboard (Primary User, Happy Path)

Drummer manages a team of five developers all using Pennyfarthing. She opens her browser to the BikeShop ShowRoom before her first meeting. Five session tiles are live — Holden is deep in a TDD cycle on story #188, Alex just started and is still in planning, Naomi has been running for three hours with two context crashes. Drummer sorts by workflow stage — three in coding, one in testing, one in planning. She clicks into Holden's tile to see his BikeShow — DiffsPanel shows the refactor is substantial, AuditLogPanel shows clean tool execution. She switches to the analytics view: over the past two sprints, the `tdd-tandem` workflow has produced 35% fewer rework cycles than `trivial` for stories over 3 points. She drafts a team recommendation. She never interrupted anyone. She never asked "what are you working on?"

**Capabilities revealed:** ShowRoom session overview, per-session drill-down into BikeShow, sorting/filtering by metadata, analytics dashboard with historical trend data, zero-interruption visibility.

### Journey 2: Team Lead — Automated Context Delivery

Drummer just merged a significant API contract change. Her BikeRack's file watcher detects the sprint file mutation and forwards a scoped notification to BikeShop: "sprint context changed — story #185 completed, API contract v3 merged." BikeShop broadcasts to all connected BikeRacks. Alex starts a new session ten minutes later. On connect, his BikeRack requests a catch-up from BikeShop. BikeShop computes the delta since Alex's last session and pushes it — the API contract change, two story completions, and a workflow recommendation update. Alex's BikeRack delivers the context to his agent before he writes a single line of code. No Slack message lost in a thread. No "did you see the email?" No manual authoring. The system is the messenger.

**Capabilities revealed:** Automated push delivery, sprint catch-up on connect, BikeRack-originated notifications, BikeShop broadcast relay, zero manual authoring.

### Journey 3: Team Lead — Pattern Discovery

It's sprint retro time. Drummer opens the BikeShop analytics view and filters to the current sprint. The data shows: 78% of stories used `tdd` workflow, 15% used `trivial`, 7% used `bdd`. Average completion time for `tdd` stories: 2.1 hours. For `trivial`: 1.4 hours, but with 2.3x the rework rate. She drills into theme performance — the team switched from `alice-in-wonderland` to `the-expanse` mid-sprint. Post-switch, context crash rate dropped 18% and reviewer pass rate increased. She filters by skill usage — `/pf-testing` is used in 90% of sessions, `/pf-mermaid` in 12%. She exports the summary for the retro deck. The data tells the story. No opinions, no guessing.

**Capabilities revealed:** Sprint-scoped analytics, workflow comparison, theme performance correlation, skill usage tracking, exportable summaries.

### Journey 4: Developer — Transparent Activity Sharing

Holden starts his day. He runs `pf bikerack start --shop team` — his BikeRack authenticates with his OpenSSH private key (BikeShopPass) and connects to BikeShop. On connect, BikeShop pushes the catch-up delta: a framework changelog update and two story completions since Holden's last session. Holden's BikeRack broadcasts both to his local session. He starts `/pf-dev` on story #192. His session telemetry flows from BikeRack to BikeShop automatically — agent, story, workflow, tool calls, context usage. He never thinks about it. Drummer can see his progress in the ShowRoom. His teammates can see he's on story #192 if they check. When he hits a context crash at 87%, it's logged. When he completes the story, it's logged. Zero extra effort. The work *is* the status update.

**Capabilities revealed:** BikeRack-to-BikeShop connection, OpenSSH keypair auth (BikeShopPass), automated catch-up on connect, telemetry streaming, passive activity sharing.

### Journey 5: Developer — Edge Case: Connection Loss

Holden is mid-session when the BikeShop goes down for maintenance. His BikeRack detects the lost connection. Claude keeps running in his terminal — nothing breaks. His status line indicator shifts from green to red. BikeRack caches telemetry locally. Two minutes later, BikeShop comes back. BikeRack reconnects, flushes the cached data. His session tile reappears in the ShowRoom with no gap. He never left his terminal.

**Capabilities revealed:** Graceful disconnection, local telemetry caching, automatic reconnection with cache flush, zero disruption to developer workflow.

### Journey 6: BikeShop Operator — Setup and Onboarding

Amos is the team's infrastructure person. He runs `docker run -p 4456:4456 -v /var/bikeshop:/data pennyfarthing/bikeshop`. BikeShop initializes its SQLite data store and starts listening. Each developer generates an SSH keypair (or uses an existing one) and sends their public key to Amos. Amos registers each public key with BikeShop as a BikeShopPass. Each developer adds their private key path and BikeShop URL to their BikeRack config. On first connect, BikeRack authenticates via key challenge/response and BikeShop registers the session. When Alex leaves the team, Amos removes Alex's public key from BikeShop — Alex's next connection attempt is rejected. Everyone else's connections are unaffected. No token rotation, no team-wide disruption.

**Capabilities revealed:** Docker deployment, OpenSSH keypair registration (BikeShopPass), per-identity BikeRack authentication, per-identity revocation without team disruption.

### Journey 7: New Team Member — First Day

Bobbie joins the team. She generates an SSH keypair and sends her public key to Amos. Amos registers it with BikeShop as a BikeShopPass. Bobbie adds her private key path and BikeShop URL to her BikeRack config and runs `pf bikerack start --shop team` for the first time. On connect, her BikeRack authenticates via key challenge/response. BikeShop computes a full catch-up — the entire active sprint state, recent changelogs, and any pending notifications. Her BikeRack broadcasts the context to her session, and her agent has team context before she types a single prompt. She runs `/pf-sprint status` and sees the full picture. She picks a story, starts working. Her session appears in the ShowRoom. Drummer sees a new tile and knows Bobbie is up and running. No onboarding meeting needed for tooling setup.

**Capabilities revealed:** Sprint catch-up on first connect, OpenSSH keypair onboarding (BikeShopPass), immediate team integration, ShowRoom visibility of new members.

### Journey 8: Engineering Manager — BikeShow Multi-Session View (Phase 2)

Drummer opens the BikeShop ShowRoom on a Wednesday morning. The ShowRoom header shows the shop status: 7 BikeRacks connected, 2 ShopOwners present (Drummer and Amos), 2 active BikeShows, 0 pending BikeShopPass requests. Below the header, the ShowRoom lists the two active BikeShows as cards:

- **Axiathon** — 3 connected sessions (Holden, Naomi, Alex). Created by Drummer yesterday for the hackathon push.
- **ProductX Sprint 49** — 4 connected sessions (Bobbie, Amos, Clarissa, Prax). The ongoing sprint work.

Drummer taps into the Axiathon BikeShow.

The view opens to a three-column layout — one column per developer. Each column is a session card showing, top to bottom:

**Identity block:** The persona portrait centered at the top — Holden's White Rabbit, Naomi's Granny Weatherwax, Alex's Ponder Stibbons. Below each portrait, the developer's name and the active agent role.

**Work context:** Story number, sprint, repo, and branch. Holden is on `HACK-042` in `axiathon-repo` on `feature/hack-042-realtime-feed`, branch created 6 hours ago. Naomi is on `HACK-043`, same repo, `feature/hack-043-auth-layer`. Alex is on `HACK-041`, different repo (`axiathon-shared`), `feature/hack-041-schema`.

**Context window:** A gauge showing current context usage — Holden at 62%, Naomi at 34%, Alex at 78%. Below each gauge, a sparkline showing context trend over the last hour. Holden's line is climbing steadily. Alex's shows a sawtooth — he's had two compactions already, recovering each time to ~20% before climbing again. Naomi's is flat and low; she compacts proactively.

**Workflow map:** Centered under the persona, an iconograph showing the workflow path. Past steps are rendered as completed nodes trailing to the left — small, muted, showing what already happened. The current step is the center node, larger, highlighted: Holden is in `coding` (Dev phase), Naomi is in `testing` (TEA phase), Alex is in `review` (Reviewer phase). Future steps trail to the right as expected-next nodes — Holden's path shows `testing → review → finish`, Naomi's shows `review → finish`, Alex's shows `finish`. The whole thing reads like a GPS route: where you've been, where you are, where you're going.

**Velocity indicator:** A small metric below the workflow map. Holden: 2.1 stories/day, trending up (arrow). Naomi: 1.8 stories/day, steady (dash). Alex: 2.4 stories/day, trending down (arrow) — the compactions are costing him momentum.

**Configurable panels:** Below the fixed cards, Drummer has pinned a shared panel row across all three sessions: DiffsPanel side by side, showing each developer's current uncommitted changes. She could reconfigure this — swap in AuditLogPanel, AcceptanceCriteriaPanel, or any panel available from the shared core library, fed by BikeShop's data pipeline for each session.

Drummer scans the three columns in seconds. She sees that Alex is burning context fast and might need to break his story down. She sees that Naomi is ahead — already in testing while the others are still coding or reviewing. She sees that Holden is steady. She doesn't message anyone. She doesn't interrupt. She has the picture.

She taps the back arrow, returns to the ShowRoom, and opens the ProductX BikeShow to check the sprint team. Four columns. Same layout, different sessions, different stories. The work speaks for itself.

**Capabilities revealed:** ShowRoom overview (shop status, active BikeShows, connected BikeRacks, ShopOwners), BikeShow as multi-session composed view, per-session identity/work/context/workflow/velocity cards, workflow iconograph (past → current → future as GPS-style path), context trend sparklines, configurable shared panel rows, cross-session comparison without interruption.

### Journey Requirements Summary

| Journey | Capabilities Required | Phase |
|---------|----------------------|-------|
| Team Lead — Dashboard | ShowRoom, session tiles, metadata display | MVP |
| Team Lead — Automated Context | Automated push delivery, sprint catch-up, BikeRack broadcast, naive local filtering | MVP |
| Team Lead — Analytics | Historical data store, workflow/theme/skill tracking, comparison views, export | Phase 2 |
| Developer — Activity | OpenSSH keypair auth (BikeShopPass), automated push receive, telemetry streaming | MVP |
| Developer — Disconnection | BikeRack local cache (DR-4 envelope), reconnection, cache flush, status indicators | MVP |
| Operator — Setup | Docker deployment, BikeShopPass key registration/revocation | MVP |
| New Member — Onboarding | BikeShopPass registration, sprint catch-up on first connect, immediate ShowRoom presence | MVP |
| Eng Manager — BikeShow (single-bike) | SQLiteDataSource, shared panel components for one remote session | Phase 2 (Step 1) |
| Eng Manager — BikeShow (multi-session) | ShowRoom overview, dockview-react layout, per-session identity cards, configurable panels | Phase 2 (Step 2) |

## Server / Developer Infrastructure Specific Requirements

### Project-Type Overview

BikeShop is a persistent Docker-deployed server that aggregates enriched OTEL telemetry from multiple BikeRack instances, providing team-wide session visibility, automated notifications, and sprint analytics. It operates as a hub in a hub-and-spoke model where BikeRack instances are the spokes.

### Technical Architecture Considerations

**Communication Model (DR-4):**
- BikeRack collects and enriches raw Claude Code telemetry, then forwards to BikeShop via a single authenticated WebSocket connection
- The connection uses a typed message envelope: `{type, sessionId, timestamp, payload}`. Telemetry payloads use OTEL span format (JSON OTLP). Control messages (notifications, catch-up, lifecycle) use purpose-built typed messages.
- BikeShop does not communicate directly with Claude Code sessions — BikeRack is the only intermediary
- ShowRoom connects to BikeShop via BikeShop's own WebSocket channels (separate from the BikeRack ↔ BikeShop protocol)

**Data Flow:**
```
Claude Code → BikeRack (collect, enrich, forward) → BikeShop (aggregate, persist, broadcast) → ShowRoom
                  ↓ typed WebSocket (DR-4)              ↓
                  ↓ OpenSSH auth (DR-2)           SQLite (persist)
```

**Protocol message types (DR-4):**

| Direction | Type | Payload |
|-----------|------|---------|
| BikeRack → BikeShop | `telemetry` | Enriched OTEL span (JSON OTLP) |
| BikeRack → BikeShop | `session:start` | Agent, story, repo, branch, workflow, identity |
| BikeRack → BikeShop | `session:meta` | Session metadata update |
| BikeRack → BikeShop | `session:end` | Reason |
| BikeRack → BikeShop | `sprint:event` | Event type, story, details |
| BikeRack → BikeShop | `subscribe` | Topics (post-MVP, reserved) |
| BikeShop → BikeRack | `notification` | Scope, event type, content, metadata |
| BikeShop → BikeRack | `catchup` | Events since last session, timestamp range |
| BikeShop → BikeRack | `changelog` | Version diff entries |
| BikeShop → BikeRack | `subscribe:ack` | Acknowledged topics (post-MVP, reserved) |

**Authentication (DR-2):**
- OpenSSH keypair (BikeShopPass) from MVP — no shared-secret phase
- Operator registers each developer's public key with BikeShop
- BikeRack authenticates via key challenge/response over the WebSocket before any data messages
- Per-identity revocation: removing one public key disconnects one BikeRack, no team-wide impact
- Key infrastructure is familiar to the target audience (developers manage `~/.ssh/` daily)

**Storage:**
- SQLite — zero-dependency, single-file, fits the "runs on an internal server for weeks" deployment model
- Stores session history, sprint event log, analytics aggregates
- Schema designed to support future `DataSource<T>` queries (DR-1) for Phase 2 BikeShow panel rendering

### Automated Push Delivery

All push content is system-generated. There is no operator authoring UI.

**Three automated channels:**

| Channel | Trigger | Delivery |
|---------|---------|----------|
| Framework changelog | Pennyfarthing version change detected | On next session connect |
| Sprint catch-up | Sprint file state changed since user's last session | On session connect — recap of what happened while away |
| Live sprint events | BikeRack reports sprint mutation (story finish, status change) | Real-time broadcast to all connected BikeRacks |

**Notification architecture (DR-3 — stepped approach):**

BikeRack detects local events via its own file watchers (sprint file mutations, story completions) and sends `sprint:event` messages to BikeShop via the DR-4 protocol. BikeShop is a stateful relay — it persists events to SQLite, computes catch-up deltas for reconnecting sessions, and tracks per-identity last-seen timestamps.

**MVP (Step 1):** BikeShop broadcasts all notifications to all connected BikeRacks. Each receiving BikeRack applies a naive local filter: match on current epic, current repo, current story. Notifications that don't match are silently dropped. This is simple and functional for teams of 5–10. It validates the notification value proposition before investing in routing infrastructure.

**Post-MVP (Step 2):** BikeRack declares subscription topics on connect (`{epic, repo, sprint}`) and updates them as context changes. BikeShop maintains a topic → BikeRack routing table and only forwards matching notifications. BikeRack continues fine-filtering against local state. Backward-compatible — BikeRacks that don't declare topics get everything (Step 1 behavior). The DR-4 protocol reserves `subscribe` and `subscribe:ack` message types for this.

### Installation & Distribution

- **Docker-first deployment** — `docker run pennyfarthing/bikeshop`
- Lives in monorepo at `packages/bikeshop/`
- Shares dependencies, build toolchain, and component ecosystem
- No npm standalone distribution for MVP

### ShowRoom Dashboard

- Built with React 19, Tailwind v4, shadcn/ui — shared component ecosystem
- Connects to BikeShop via WebSocket for real-time session tile updates
- See Functional Requirements (FR24–FR26) for capability details

### Implementation Considerations

- BikeShop must handle graceful disconnection — BikeRack reconnects and flushes cached messages (DR-4 envelope format) with no data gap
- SQLite must handle concurrent reads from ShowRoom queries while ingesting spans (WAL mode)
- MVP notification broadcast is simple — BikeShop relays to all connected BikeRacks, naive filtering at each BikeRack. Post-MVP adds topic-based routing (DR-3)
- ShowRoom must maintain the <500ms latency target from the success criteria even with 10+ concurrent sessions
- SQLite schema must be designed to support future `DataSource<T>` queries for Phase 2 BikeShow panel rendering (DR-1)
- Protocol message types (DR-4) must be defined as shared TypeScript types in `@pennyfarthing/core` before BikeShop implementation begins
- **Prerequisite:** BikeRack extraction from Cyclist (see [extraction proposal](bikerack-extraction-proposal.md)), including `DataSource<T>` interface introduction (DR-1). BikeShop client code lives in the BikeRack package.

### BikeShop Views {#bikeshop-views}

BikeShop has three distinct view types, delivered across phases (DR-5):

**ShowRoom (Phase 1)** — BikeShop-native overview. The shop's own status page: connected BikeRacks, active BikeShows, ShopOwners present, BikeShopPass holders, shop health metrics, quick-view summaries of each connected Bike. This is entirely BikeShop UI — no shared panel components, no DataSource wiring. BikeRack has no concept of any of it.

**Single-bike view (Phase 2, Step 1)** — BikeShop serves a `SQLiteDataSource` for one remote session. Shared panel components from core render in the browser, consuming the same `DataSource<T>` interface they use in BikeRack (but backed by SQLite instead of live WebSocket). Validates the full DataSource pipeline end-to-end: BikeRack → DR-4 protocol → BikeShop SQLite → `SQLiteDataSource` → panel components.

**BikeShow (Phase 2, Step 2)** — configurable multi-session dashboard using dockview-react for layout composition. A BikeShow is not a single BikeRack viewed remotely. It's a composed view that can:
- Display panels from multiple sessions side by side via parameterized DataSource: `useDataSource('diffs', { session: 'holden' })` (DR-1)
- Include per-session identity cards (portrait, workflow iconograph, context sparkline, velocity) as custom components within dockview panels
- Aggregate data across sessions (context crash rates across three Bikes)
- Configure panel rows (pin DiffsPanel across all sessions, swap in AuditLogPanel)

**Data pipeline:** BikeShop feeds these views through its own data pipeline: SQLite → `SQLiteDataSource` (implements `DataSource<T>`) → shared panel components from core. It does not embed or depend on BikeRack's server engine. BikeRack's file watchers, OTEL receiver, session lifecycle, and local WebSocket channels are irrelevant to BikeShop — they serve the local single-session case.

The shared surface between BikeRack and BikeShop is `@pennyfarthing/core` — the `DataSource<T>` provider interface, panel components, protocol types (DR-4), and styles:

```
@pennyfarthing/core  ← DataSource<T>, panel components, protocol types, styles
    ↑           ↑              ↑
BikeRack      Cyclist        BikeShop
(observes     (controls       (aggregates
 sessions —    the session —   sessions —
 CLI+browser   IDE, owns       team server,
 dashboard)    lifecycle)      multi-session)
```

## Scoping & MVP Strategy

### MVP Philosophy

**Approach:** Platform MVP — the value is in the connective tissue between sessions, not a single killer feature. The minimum that makes a team lead say "everyone should use this" is: I can see all active sessions and get notified when work unblocks mine.

**Resource Requirements:** Solo developer (framework author). BikeShop leverages existing BikeRack infrastructure and OTEL pipeline. New work is the aggregation server, SQLite storage, ShowRoom UI, notification broadcast logic, and the BikeShop client module within BikeRack (auth, forwarding, caching).

### MVP Scope Rationale

Phased feature breakdown is defined in Product Scope above. The MVP (Phase 1) was scoped by asking one question per capability: *without this, does the product fail?*

| Capability | Rationale |
|-----------|-----------|
| BikeShop server (Docker, SQLite, OpenSSH keypair auth) | Foundation — everything depends on it |
| Typed WebSocket protocol (DR-4) | Integration contract — defines what flows between BikeRack and BikeShop |
| OpenSSH keypair auth (BikeShopPass) (DR-2) | Per-identity lifecycle is essential for a team product. Avoids throwaway shared-secret code |
| BikeRack → BikeShop telemetry forwarding | Data plane — no data, no product |
| ShowRoom session tiles (real-time) | Core visibility — "who's doing what right now" |
| Live sprint notifications with naive local filtering (DR-3) | Killer feature — "Alex finished AAA-111, your AAA-112 is unblocked" |
| Sprint catch-up on connect | Session start context — "here's what happened while you were away" |
| Framework changelog on connect (version-diff) | Prevents stale-tool surprises |
| Graceful disconnect/reconnect with cache flush | Reliability — BikeShop going down must not disrupt developer work |

**Explicitly deferred from MVP:**
- Analytics dashboard views (Phase 2)
- CSV/JSON export (Phase 2)
- BikeShow single-bike view (Phase 2, Step 1)
- BikeShow multi-session view (Phase 2, Step 2)
- Topic-based notification filtering (Phase 2)
- Session tile sorting/filtering (Phase 2)
- Onboarding bundles (Phase 2)

**Core MVP Journeys:** 1 (Dashboard — tiles only), 4 (Activity Sharing), 5 (Connection Loss), 7 (New Member — catch-up only)

### Risk Mitigation

| Risk | Category | Mitigation |
|------|----------|------------|
| Protocol payloads aren't rich enough for DataSource queries | Technical | Design backward from DataSource types (DR-1) → SQLite schema → protocol payloads (DR-4). Define types in core before implementation. |
| SQLite write contention under 10+ concurrent sessions | Technical | WAL mode, batch inserts, read-only ShowRoom connections |
| MVP broadcast-all generates noise at scale | Technical | Naive local filtering is functional for 5–10 sessions. Topic-based routing (DR-3 Step 2) addresses scale. MVP validates notification value first. |
| OpenSSH key distribution friction slows onboarding | Adoption | Target audience manages SSH keys daily. The ceremony is familiar, not foreign. Key registration is a one-time cost per team member. |
| Team doesn't change habits — ShowRoom goes unused | Adoption | MVP emphasizes push (notifications come to you) over pull (you go to dashboard). Value arrives without behavior change. |
| Solo-developer users see no value in BikeShop | Adoption | BikeShop is explicitly team-only. Solo users don't need it. No pretending otherwise. |
| Scope creep from analytics before MVP proves core value | Resource | Analytics is Phase 2. MVP ships tiles + notifications. Period. |
| BikeRack extraction delays BikeShop work | Dependency | Extraction (~18 pts including DataSource refactor) is a prerequisite — scope as a separate epic, ship first |

## Functional Requirements

### Session Visibility

- **FR1:** Team leads can view all currently connected sessions with key metadata (agent, story, workflow phase, duration, context usage)
- **FR2:** Team leads can see when a session connects or disconnects in real time
- **FR3:** Team members can see which stories their teammates are working on

### Sprint Notifications

- **FR4:** BikeRack can detect local events (sprint file mutations, story completions) and send scoped notifications to BikeShop
- **FR5:** BikeShop can broadcast received notifications to all connected BikeRack instances
- **FR6:** Receiving BikeRack can evaluate notification relevance and broadcast relevant ones on its local WebSocket channels
- **FR7:** Developers receive relevant notifications in their active session without action on their part

### Session Catch-Up

- **FR8:** Developers receive a summary of sprint changes that occurred since their last session on connect
- **FR9:** Developers receive framework changelog information when Pennyfarthing version has changed since their last session
- **FR10:** BikeShop tracks last-seen timestamp per BikeRack identity to identify what's new

### Telemetry Ingestion

- **FR11:** BikeShop can accept enriched OTEL spans from multiple BikeRack instances simultaneously
- **FR12:** BikeShop can identify and associate spans from the same session across time
- **FR13:** BikeShop persists session telemetry data for historical queries
- **FR14:** BikeRack instances authenticate with BikeShop using OpenSSH keypair (BikeShopPass) via key challenge/response over the WebSocket connection

### Connection Resilience

- **FR15:** BikeRack can cache telemetry locally when BikeShop is unreachable
- **FR16:** BikeRack can flush cached telemetry to BikeShop on reconnection without data loss
- **FR17:** Developer workflow is uninterrupted when BikeShop is temporarily unavailable
- **FR18:** BikeShop can accept and process backfilled telemetry from reconnecting BikeRack instances

### Server Operations

- **FR19:** Operators can deploy BikeShop as a Docker container
- **FR20:** Operators can configure BikeShop connection settings (port, data directory)
- **FR21:** Operators can register OpenSSH public keys (BikeShopPass) for BikeRack authentication
- **FR22:** Operators can revoke individual BikeShopPass keys without affecting other connected BikeRacks
- **FR23:** BikeShop can run as a persistent service for extended periods

### ShowRoom Dashboard

- **FR24:** Team leads can access the ShowRoom via web browser
- **FR25:** ShowRoom displays session tiles that update in real time as telemetry arrives
- **FR26:** ShowRoom displays basic session health indicators derived from existing telemetry metadata (context %, active duration, last activity time)

## Non-Functional Requirements

### Performance

- **NFR1:** ShowRoom session tiles update within 500ms of BikeShop receiving a span from BikeRack
- **NFR2:** Sprint notifications are delivered to receiving BikeRack instances within 2 seconds of origination
- **NFR3:** Sprint catch-up summary is computed and delivered within 5 seconds of session connect
- **NFR4:** BikeShop supports 10+ concurrent BikeRack connections with no degradation to tile update latency
- **NFR5:** SQLite ingestion keeps pace with span arrival from 10 concurrent sessions without queuing backpressure

### Reliability

- **NFR6:** BikeShop runs continuously for 7+ days without restart or intervention
- **NFR7:** BikeShop unavailability does not interrupt any active Claude Code session
- **NFR8:** No telemetry data is lost during BikeRack disconnect/reconnect cycles
- **NFR9:** BikeShop recovers cleanly from unexpected restart — SQLite state is consistent on next launch
- **NFR10:** ShowRoom displays accurate "last seen" timestamps so stale data is obvious

### Security

- **NFR11:** BikeRack-to-BikeShop connections are authenticated via OpenSSH keypair (BikeShopPass) with key challenge/response before any data messages
- **NFR12:** Unauthenticated and unauthorized (revoked key) connection attempts are rejected and logged
- **NFR13:** Telemetry data at rest in SQLite is not exposed via ShowRoom beyond intended dashboard views

### Scalability

- **NFR14:** BikeShop is designed for team-scale usage (5–15 concurrent sessions), not enterprise-scale
- **NFR15:** Adding a new BikeRack connection does not require BikeShop restart or reconfiguration
- **NFR16:** SQLite storage is bounded — telemetry older than a configurable retention period is pruned automatically

### Integration

- **NFR17:** BikeShop accepts messages in the typed envelope format defined by the DR-4 protocol contract. Telemetry payloads use OTEL span format (JSON OTLP). Protocol types are defined in `@pennyfarthing/core` and shared by both BikeRack and BikeShop.
- **NFR18:** ShowRoom reuses the shared React 19 / Tailwind v4 / shadcn/ui component ecosystem. Phase 2 BikeShow views additionally consume the `DataSource<T>` provider interface (DR-1).
- **NFR19:** BikeShop is packaged as a Docker image with configurable environment variables
- **NFR20:** BikeRack-to-BikeShop communication uses a single authenticated WebSocket connection with the DR-4 typed message envelope. This is a purpose-built protocol — not the same WebSocket patterns used for panel data within BikeRack/Cyclist.
