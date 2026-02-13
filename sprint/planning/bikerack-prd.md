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
inputDocuments: []
workflowType: 'prd'
documentCounts:
  briefCount: 0
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 0
classification:
  projectType: Desktop App (Electron) / Developer Tooling
  domain: Developer Experience (DX) / Agent Infrastructure
  complexity: Medium
  projectContext: brownfield
---

# Product Requirements Document - BikeRack Mode

**Author:** Keith Avery
**Date:** 2026-02-11

## Success Criteria

### User Success

- A CLI-preferring developer runs the BikeRack launcher and gets Claude Code in their terminal with a live dashboard in their browser — no workflow change required
- All first-class panels update in real-time as they work (sprint, git, diffs, todos, workflow, spans, changed files, acceptance criteria, background tasks, debug, TTY, BikeLane)
- The new PortraitPanel shows the current agent identity with tandem mode support
- The dashboard feels like a companion, not a replacement — the terminal stays the primary interaction surface

### Business Success

- Expands the Cyclist ecosystem to developers who prefer CLI workflows
- Lowers the barrier to Pennyfarthing adoption — no need to commit to the full Cyclist terminal experience
- The PortraitPanel + tandem support showcases agent identity in a way CLI users have never seen

### Technical Success

- WheelHub starts standalone without spawning/managing a Claude session
- BikeRack launcher configures OTEL env vars and starts both WheelHub and Claude CLI in one command
- All existing panel WebSocket channels work identically whether data comes from a Cyclist-managed session or a BikeRack-launched CLI session
- No changes to panel components themselves — they consume the same WebSocket data
- New PortraitPanel implemented and functional

### Measurable Outcomes

| Metric | Target | Measurement |
|--------|--------|-------------|
| OTEL data flowing | All span types visible in AuditLog panel | Manual verification |
| Panel update latency | Same as existing Cyclist (<500ms from tool event) | WheelHub timing |
| Panels functional | 13/13 panels render with live data | Integration checklist |
| PortraitPanel | Shows agent + tandem correctly | Visual verification |
| Launcher reliability | WheelHub + Claude start successfully | Launch test |

## Product Scope

### MVP - Minimum Viable Product

1. **BikeRack launcher command** — starts WheelHub in background, launches Claude CLI with OTEL config in foreground
2. **WheelHub standalone mode** — runs without Claude session management (no MessagePanel, no session spawning)
3. **Web mode only** — panels served via WheelHub HTTP, opened in browser; user arranges via browser tabs, tiling, or OS window management. No dockview/Electron layout for MVP.
4. **New PortraitPanel** — agent identity display with tandem mode support

### Growth Features (Post-MVP)

1. **CLI-driven panel focus** — `/bc {panel}` writes panel config via `pf bc` command; BikeShow reacts by showing only that panel. `/bc reset` returns to saved layout. No stash stack — reset always restores the last saved state. (~5 pts, Idea A)
2. **Telemetry capture & replay** — BikeRack always writes telemetry to disk; replay feeds it back through the same pipeline for post-session review, debugging, async code review, and onboarding (~12 pts, Idea D)
3. **BikeRack-specific settings panel** — configure dashboard layout, panel preferences
4. **PortraitPanel party mode** — extend solo/tandem display to 3+ agent swarm sessions when swarm workflows land (Idea I)

### Vision (Future)

> **Terminology:** The ecosystem has distinct roles that benefit from distinct names. See [Glossary](#glossary) for definitions.

**Standalone & CLI integration:**
1. BikeRack as a standalone installable (without full Cyclist/Electron)
2. Browser-only mode — pure web dashboard, no Electron dependency
3. Status line connection indicators — colored circles showing BikeShop connection health (Idea K)

**Multi-session (requires BikeShop):**
4. BikeShop as multi-session router — multiple BikeRacks feed one BikeShop, visible in the ShowRoom (~25 pts, Ideas B+E)
5. ShowRoom dashboard — always-on BikeShop overview with session tiles, sortable metrics, display density modes (Ideas E+H)
6. Session picker — switch between active CLI sessions via ShowRoom or CLI

**Resilience & capture:**
7. BikeShop auto-failover — preferred/alternate BikeShop with failover timer, local caching, holddown timer (Idea F)
8. Context compaction as crash events — visual crash indicators in timeline/race views (Idea J)

**Collaboration & beyond (separate initiatives):**
9. Cross-BikeShop casting — relay telemetry between BikeShops for team visibility (Idea C)
10. Leaderboards and races — aggregated cross-session rankings and competitions (Idea G)
11. RaceCoach — workflow feedback via behavioral linting and telemetry analysis (Idea L — deserves own PRD)
12. TeamGear — shared file drive for skills, workflows, knowledge between sessions (Idea M — deserves own PRD)
13. Tandem — multi-operator collaboration layering output/input sharing on top of TeamGear (Idea N — research territory)

### Out of Scope

- **MessagePanel** — CLI owns the conversation; no message rendering in BikeRack
- **SettingsPanel** — Cyclist-specific configuration UI
- **Bell mode** — message queue injection is a Cyclist feature; dormant via `IS_BIKERACK`
- **Permissions/ApprovalModal** — CLI handles its own permission prompts natively
- **Reflector markers** — drive QuickActions in Cyclist's message view, not relevant to BikeRack
- **Dockview/Electron layout** — web mode only for MVP; users arrange panels via browser/OS
- **Hook registration** — BikeRack does not register Cyclist-specific hooks; only configures OTEL
- **Panel bug fixes** — BikeRack ships existing panels as-is; panel data issues are separate work
- **Multi-session support** — single session for MVP (Growth feature)
- **HotspotsPanel** — deprecated, not included

## User Journeys

### Journey 1: CLI Developer — First Launch (Happy Path)

Keith prefers his terminal. He's heard about Cyclist's panels but doesn't want to give up his Ghostty/Warp/Kitty/Alacritty workflow. He runs `bikerack` — WheelHub starts in the background, Claude CLI launches in his terminal. He opens `localhost:{port}` in his browser. Immediately he sees SprintPanel showing his current sprint, GitPanel with repo status. He starts working with Claude — `/dev` activates the White Rabbit — and the PortraitPanel lights up with the agent's identity. As Claude edits files, DiffsPanel updates. As tools run, AuditLogPanel shows enriched spans. He never left his terminal, but he has full visibility.

**Capabilities revealed:** Launcher, WheelHub standalone, OTEL pipeline, all panel WebSocket channels, PortraitPanel, web-served panel pages.

### Journey 2: Tandem Workflow

Keith is in a `tdd-tandem` workflow. TEA and Architect are both active. The PortraitPanel shows the primary agent prominently with the backseat agent secondary — main over backseat, same layout as current Cyclist. As the workflow progresses and agents hand off, the portrait updates. He can see at a glance who's driving and who's advising.

**Capabilities revealed:** PortraitPanel tandem support (main over backseat), agent change detection via OTEL/session data.

### Journey 3: Disconnection / Reconnection

Keith closes his browser tab mid-session. Claude keeps running in the terminal — nothing breaks. He reopens the dashboard later — WheelHub is still running, panels reconnect via WebSocket and show current state. No data lost.

**Capabilities revealed:** WheelHub persistence independent of browser, WebSocket reconnection with state recovery.

### Journey 4: New User On-Ramp

A colleague sees Keith's dashboard. "What's that?" Keith explains BikeRack. The colleague installs Pennyfarthing, runs `bikerack`, and gets the same experience without learning Cyclist's full Electron app. The panels teach them what Pennyfarthing tracks by simply being visible.

**Capabilities revealed:** Low barrier to entry, self-explanatory panel layout, no Cyclist prerequisite knowledge needed.

### Journey Requirements Summary

| Journey | Capabilities Required |
|---------|----------------------|
| First Launch | Launcher, WheelHub standalone, OTEL config, web-served panels, all panels, PortraitPanel |
| Tandem | PortraitPanel main-over-backseat layout, agent detection |
| Disconnect/Reconnect | WheelHub persistence, WebSocket reconnect with state |
| New User | Simple install/launch, self-describing panels |

## Developer Tooling Specific Requirements

### Architecture Overview

BikeRack is a new mode within Cyclist that decouples the WheelHub dashboard server from Claude session management. It reuses all existing infrastructure — WheelHub HTTP/WebSocket server, OTEL receiver, file watchers, panel React components — and serves them via web mode to the user's browser.

The central mode switch is the `IS_BIKERACK` environment variable. When set, WheelHub skips ClaudeService process management and Cyclist-specific features (bell mode, permissions, reflector) auto-skip via their existing guards.

### Launcher

A `just` recipe or Python CLI command (e.g., `just bikerack` or `pf bikerack`) that orchestrates startup. See FR-1 through FR-6 for detailed requirements.

### Platform

- macOS primary (matches current Cyclist support)
- No additional platform requirements beyond what Cyclist already supports

### Key Technical Constraints

- WheelHub must start without its Claude session spawning logic — it receives OTEL data but doesn't manage the Claude process lifecycle
- Panels served as individual web pages/routes, no Electron renderer needed
- Existing WebSocket channels (`/ws/sprint`, `/ws/git`, `/ws/diffs`, etc.) work unchanged
- File watchers (sprint YAML, session files, git) work unchanged since they watch the filesystem, not the Claude process

### Implementation Considerations

- No changes to existing panel components
- New PortraitPanel extracts portrait rendering from MessageView into a standalone panel component
- WheelHub needs a "bikerack" startup mode gated by `IS_BIKERACK` env var — skips ClaudeService process management
- `IS_BIKERACK` env var is the single mode switch: WheelHub checks it on startup, Cyclist-specific features (bell mode, permissions, reflector) auto-skip based on it
- Web serving of panel pages needs a simple index/routing layer
- Cyclist-specific hook features already have "skip if not Cyclist" guards — no new isolation work needed, `IS_BIKERACK` ensures they stay dormant

## Functional Requirements

### Launcher & Lifecycle

- **FR-1:** User can start a BikeRack session via a single command (`just bikerack` or `pf bikerack`) that launches both WheelHub and Claude CLI
- **FR-2:** Launcher sets `IS_BIKERACK` env var before starting WheelHub
- **FR-3:** Launcher configures Claude CLI with OTEL env vars (`OTEL_EXPORTER_OTLP_ENDPOINT`, etc.) pointed at the WheelHub port
- **FR-4:** Launcher writes `.cyclist-port` file so hooks can discover WheelHub
- **FR-5:** When Claude CLI exits, WheelHub process is cleaned up automatically
- **FR-6:** Claude CLI runs in the foreground in the user's current terminal

### WheelHub Standalone Mode

- **FR-7:** WheelHub can start in BikeRack mode (gated by `IS_BIKERACK`), skipping ClaudeService process management
- **FR-8:** WheelHub receives OTEL telemetry (metrics and logs) from the externally-launched Claude CLI session
- **FR-9:** All existing WebSocket channels broadcast data identically in BikeRack mode as in Cyclist mode
- **FR-10:** All file watchers (sprint YAML, session files, git) operate unchanged in BikeRack mode
- **FR-11:** Cyclist-specific features (bell mode, permissions/ApprovalModal, reflector) remain dormant when `IS_BIKERACK` is set

### Web Panel Serving

- **FR-12:** WheelHub serves panel pages via HTTP in BikeRack mode, accessible in any browser
- **FR-13:** Each first-class panel is accessible as a standalone web page
- **FR-14:** Panels connect to WheelHub via WebSocket and receive initial state on connection
- **FR-15:** Panels reconnect automatically after browser tab close/reopen with current state recovery

### Panel Roster

- **FR-16:** The following panels are available in BikeRack mode: SprintPanel, GitPanel, DiffsPanel, TodoPanel, WorkflowPanel, BackgroundPanel, AuditLogPanel, ChangedPanel, AcceptanceCriteriaPanel, TTYPanel, DebugPanel, BikeLanePanel
- **FR-17:** MessagePanel is not available in BikeRack mode (CLI owns the conversation)
- **FR-18:** SettingsPanel is not available in BikeRack mode (Cyclist-specific)

### PortraitPanel

- **FR-19:** A new PortraitPanel displays the current agent's identity (name, persona, portrait image)
- **FR-20:** PortraitPanel supports tandem mode — shows primary agent prominently with backseat agent secondary (main over backseat layout)
- **FR-21:** PortraitPanel updates in real-time as agents change during workflow handoffs

## Non-Functional Requirements

### NFR-1: Performance

- Panel data updates reach the browser within 500ms of the originating tool event (matching existing Cyclist performance)
- WheelHub startup completes within 3 seconds, ready to receive OTEL data
- WebSocket reconnection after browser tab reopen completes within 2 seconds with full state recovery

### NFR-2: Reliability

- WheelHub process remains stable for the duration of a Claude CLI session (hours)
- If WheelHub crashes, Claude CLI continues unaffected in the terminal (no dependency)
- Launcher cleanup reliably terminates WheelHub on Claude CLI exit (no orphan processes)
- `.cyclist-port` file is cleaned up on shutdown

### NFR-3: Compatibility

- BikeRack mode does not interfere with a concurrent Cyclist instance (different port)
- `IS_BIKERACK` env var cleanly disables all Cyclist-specific features without side effects
- OTEL data format from Claude CLI is consumed identically to Cyclist-managed sessions
- Existing Cyclist tests (panel components, WebSocket channels) pass unchanged

---

## Glossary {#glossary}

| Term | Definition |
|------|-----------|
| **BikeRack** | The launcher and transmitter. Starts a Claude Code session, handles its lifecycle, and transmits telemetry to a BikeShop. One BikeRack per Claude Code session. |
| **BikeShop** | The coordinating service / venue. Receives data from one or more BikeRacks. Creates and manages BikeShows. Has its own ShowRoom. Can also relay to other BikeShops. |
| **ShowRoom** | The BikeShop's native dashboard. Shows status, a visual router of connected sessions, and optionally a session launcher. The "front page" of a BikeShop. |
| **BikeShow** | A live dashboard view of a specific session, created by a BikeShop from a BikeRack's data. If no BikeShow is created (no live spectators), data is still captured to disk. |
| **BikeShopPass** | Authorization to send data. SSH keypair where the public key is registered with the BikeShop as a "Customer" and the private key is held by the BikeRack. |
| **BikeShopKey** | Authorization for administrative actions. SSH keypair granting ShopOwner access to create BikeShows, manage routing, and (with caution) remote control. |

> **MVP note:** Only BikeRack is relevant for MVP. BikeShop, ShowRoom, BikeShow, and authorization concepts apply to Vision-phase work.

## Design Principles

### Remote Control Caution

The primary use case for remote control is **first-party mobile access:** the owner/operator of a session checking on their own long-running work from a phone — authorizing permission prompts, starting workflows, reviewing status.

**Sharing what you see is different from controlling what someone else does.** The BikeShop/ShowRoom model is strong for display and observation. Second-party control of another person's AI session raises unresolved questions about agency, consent, and workflow integrity. Vision items that reference remote control should be evaluated with this principle in mind.

Actual collaboration should look like: display sharing (view-only), shared materials (TeamGear), and selective output sharing — not one person controlling another person's AI session.

---

## Appendix: Idea Triage

> **Source:** Extended brainstorming appendix contributed by M. Pursifull (2026-02-11). Ideas A through N with detailed user stories. Full source preserved in `bikerack-prd-ideas.md`.

### Triage Summary

| Idea | Title | Verdict | Timing | Est. Size |
|------|-------|---------|--------|-----------|
| **A** | CLI-Driven Panel Focus | **Growth feature** | Post-MVP | ~5 pts |
| **B** | BikeShop Multi-Session Router | **Follow-up epic** | Vision | ~25 pts |
| **C** | Cross-BikeShop Casting | **Out of scope** | 2+ quarters | Large |
| **D** | Telemetry Capture & Replay | **Growth feature** | Post-MVP, early | ~12 pts |
| **E** | ShowRoom Dashboard | **Follow-up** (bundle w/ B) | Vision | Bundled |
| **F** | BikeShop Auto-Failover | **Out of scope** | Preserve as ADR | Large |
| **G** | Leaderboards & Races | **Out of scope** | Post-ShowRoom | Medium |
| **H** | Display Density Modes | **Follow-up** (bundle w/ E) | ShowRoom stories | Bundled |
| **I** | Rider Display & Party Mode | **Partially in MVP** | Party mode later | Small |
| **J** | Context Compaction as Crashes | **Follow-up story** | When timeline exists | ~2 pts |
| **K** | Status Line Indicators | **Follow-up epic** | Post-BikeShop | ~5 pts |
| **L** | RaceCoach | **Separate PRD** | Own initiative | Large |
| **M** | TeamGear | **Separate PRD** | Own initiative | Large |
| **N** | Multi-Operator Tandem | **Out of scope** | Research / 2027 | Research |

### Triage Details

**Integrate into Growth (post-MVP):**

- **Idea A — CLI Panel Focus:** Low effort, high value for CLI-first users. `/bc {panel}` runs a `pf bc` command that writes to a config file; BikeShow watches the file and reacts. `/bc reset` restores the saved layout (no stash stack). Panels: sprint, git, settings, diffs, debug, audit, todo, ac. Needs MVP web serving to land first.
- **Idea D — Capture & Replay:** "BikeShow with no spectators still writes to disk" — elegant capture model. Replay feeds a file back through the same pipeline. Strong use cases: post-session review, debugging, onboarding, async code review.
- **Idea I (partial) — Party Mode:** Solo/tandem already covered by FR-19–21. Party mode (3+ agents) deferred until swarm workflows exist.

**Follow-up epics (Vision phase):**

- **Ideas B+E+H — BikeShop + ShowRoom + Density:** The natural second act. Multi-session routing, session tiles with metrics, auto-density based on session count. One large epic (~25 pts). Requires MVP to prove out first.
- **Idea J — Crash Events:** Small visualization story (~2 pts) for when a timeline or progress view exists. Context compaction rendered as crash icons.
- **Idea K — Status Line Indicators:** CLI-side companion to the browser dashboard. Colored circles showing connection health. Requires BikeShop to exist.

**Separate PRDs recommended:**

- **Idea L — RaceCoach:** Workflow feedback and efficiency tips via behavioral linting and AI analysis. Genuinely interesting product concept but orthogonal to BikeRack — it's a coaching layer, not a dashboard feature.
- **Idea M — TeamGear:** Shared file/skill/knowledge system between sessions. Completely independent of BikeRack — doesn't require a dashboard. Needs its own PRD covering sync mechanism, conflict resolution, and access model.

**Out of scope (preserved for reference):**

- **Idea C — Cross-BikeShop Casting:** Federation between BikeShops. Networking, auth, relay protocols, SSH transport. Requires Idea B to be fully landed. Scope creep magnet.
- **Idea F — Auto-Failover:** Well-designed (failover timer, holddown timer, preference-swap) but 3+ dependency layers deep. Preserve the design thinking in an ADR; don't build this year.
- **Idea G — Leaderboards & Races:** Gamification of developer sessions. Good demo/marketing feature for when ShowRoom exists. Requires B+E+historical data.
- **Idea N — Multi-Operator Tandem:** The author flagged this as dubious. Minimum viable version requires TeamGear (Idea M). Agent-to-agent bridging is research territory. 2027 conversation.

### Suggested Sequencing

```
MVP (this epic)
  └→ Growth: CLI Panel Focus (A) + Capture & Replay (D) + Party Mode (I)
       └→ Vision: BikeShop + ShowRoom (B+E+H) + Status Line (K)
            └→ Vision: Crash Events (J) + Leaderboards (G)
                 └→ Future: Casting (C) + Failover (F)

Separate tracks (independent of BikeRack):
  - RaceCoach (L) — own PRD
  - TeamGear (M) — own PRD
  - Tandem (N) — research, blocked on M
```
