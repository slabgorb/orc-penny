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
  projectType: Web App / Developer Tooling
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
| Panels functional | 14/14 panels render with live data | Integration checklist |
| PortraitPanel | Shows agent + tandem correctly | Visual verification |
| Launcher reliability | WheelHub + Claude start successfully | Launch test |

## Product Scope

### MVP - Minimum Viable Product

1. **BikeRack launcher command** — starts WheelHub in background, launches Claude CLI with OTEL config in foreground
2. **WheelHub standalone mode** — runs without Claude session management (no MessagePanel, no session spawning)
3. **Browser-based dockview layout** — panels served via WheelHub HTTP, opened in browser with dockview-react layout. No Electron dependency.
4. **New PortraitPanel** — agent identity display with tandem mode support

### Growth Features (Post-MVP)

1. Multi-session per folder — multiple CLI terminals in the same folder feeding one dashboard
2. BikeRack-specific settings panel — configure dashboard layout, panel preferences
3. Cross-folder session picker — view/switch between BikeRack sessions from different project folders

### Vision (Future)

1. BikeRack as a standalone installable (without full Cyclist)
2. Team dashboard — multiple developers' sessions on one screen

### Out of Scope

- **MessagePanel** — CLI owns the conversation; no message rendering in BikeRack
- **SettingsPanel** — Cyclist-specific configuration UI
- **Bell mode** — message queue injection is a Cyclist feature; dormant via `IS_BIKERACK`
- **Permissions/ApprovalModal** — CLI handles its own permission prompts natively
- **Reflector markers** — drive QuickActions in Cyclist's message view, not relevant to BikeRack
- **Electron** — BikeRack is browser-based with dockview; no Electron dependency
- **Hook registration** — BikeRack does not register Cyclist-specific hooks; only configures OTEL
- **Panel bug fixes** — BikeRack ships existing panels as-is; panel data issues are separate work
- **Multi-session per folder** — one session per folder for MVP
- **HotspotsPanel** — deprecated, not included

## User Journeys

### Journey 1: CLI Developer — First Launch (Happy Path)

Keith prefers his terminal. He's heard about Cyclist's panels but doesn't want to give up his iTerm workflow. He runs `bikerack` — WheelHub starts in the background, Claude CLI launches in his terminal. He opens `localhost:{port}` in his browser. Immediately he sees SprintPanel showing his current sprint, GitPanel with repo status. He starts working with Claude — `/dev` activates the White Rabbit — and the PortraitPanel lights up with the agent's identity. As Claude edits files, DiffsPanel updates. As tools run, AuditLogPanel shows enriched spans. He never left his terminal, but he has full visibility.

**Capabilities revealed:** Launcher, WheelHub standalone, OTEL pipeline, all panel WebSocket channels, PortraitPanel, web-served panel pages.

### Journey 2: Tandem Workflow

Keith is in a `tdd-tandem` workflow. TEA and Architect are both active. The PortraitPanel shows the primary agent prominently with the backseat agent secondary — main over backseat, same layout as current Cyclist. As the workflow progresses and agents hand off, the portrait updates. He can see at a glance who's driving and who's advising.

**Capabilities revealed:** PortraitPanel tandem support (main over backseat), agent change detection via OTEL/session data.

### Journey 3: Disconnection / Reconnection

Keith closes his browser tab mid-session. Claude keeps running in the terminal — nothing breaks. He reopens the dashboard later — WheelHub is still running, panels reconnect via WebSocket and show current state. No data lost.

**Capabilities revealed:** WheelHub persistence independent of browser, WebSocket reconnection with state recovery.

### Journey 4: New User On-Ramp

A colleague sees Keith's dashboard. "What's that?" Keith explains BikeRack. The colleague installs Pennyfarthing, runs `bikerack`, and gets the same experience without learning Cyclist's full app. The panels teach them what Pennyfarthing tracks by simply being visible.

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

BikeRack is a new mode within Cyclist that decouples the WheelHub dashboard server from Claude session management. It reuses all existing infrastructure — WheelHub HTTP/WebSocket server, OTEL receiver, file watchers, panel React components, dockview-react layout — and serves them via browser (no Electron). Each folder gets its own BikeRack session (one WheelHub instance per project directory).

The central mode switch is the `IS_BIKERACK` environment variable. When set, WheelHub skips ClaudeService process management and Cyclist-specific features (bell mode, permissions, reflector) auto-skip via their existing guards.

### Launcher

A `just` recipe or Python CLI command (e.g., `just bikerack` or `pf bikerack`) that orchestrates startup. See FR-1 through FR-6 for detailed requirements.

### Platform

- macOS primary (matches current Cyclist support)
- No additional platform requirements beyond what Cyclist already supports

### Key Technical Constraints

- WheelHub must start without its Claude session spawning logic — it receives OTEL data but doesn't manage the Claude process lifecycle
- Panels served via browser with dockview-react layout, no Electron renderer needed
- Existing WebSocket channels (`/ws/sprint`, `/ws/git`, `/ws/diffs`, etc.) work unchanged
- File watchers (sprint YAML, session files, git) work unchanged since they watch the filesystem, not the Claude process

### Implementation Considerations

- No changes to existing panel components
- New PortraitPanel extracts portrait rendering from MessageView into a standalone panel component
- WheelHub needs a "bikerack" startup mode gated by `IS_BIKERACK` env var — skips ClaudeService process management
- `IS_BIKERACK` env var is the single mode switch: WheelHub checks it on startup, Cyclist-specific features (bell mode, permissions, reflector) auto-skip based on it
- Browser-served dockview layout reuses existing panel components with a BikeRack-specific panel roster (no MessagePanel, no SettingsPanel)
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

- **FR-12:** WheelHub serves the BikeRack dashboard via HTTP in BikeRack mode, accessible in any browser
- **FR-13:** Panels are rendered in a dockview-react layout in the browser, reusing existing panel components
- **FR-14:** Panels connect to WheelHub via WebSocket and receive initial state on connection
- **FR-15:** Panels reconnect automatically after browser tab close/reopen with current state recovery

### Panel Roster

- **FR-16:** The following panels are available in BikeRack mode: SprintPanel, GitPanel, DiffsPanel, TodoPanel, WorkflowPanel, BackgroundPanel, AuditLogPanel, ChangedPanel, ACPanel, AcceptanceCriteriaPanel, TTYPanel, DebugPanel, BikeLanePanel
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
