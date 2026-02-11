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

1. Multi-session support — multiple BikeRacks feeding one BikeShop; sessions visible in the ShowRoom (see Appendix Ideas B, E)
2. BikeRack-specific settings panel — configure dashboard layout, panel preferences
3. Session picker — switch between active CLI sessions via ShowRoom tiles or CLI commands (see Appendix Idea B)

### Vision (Future)

**Standalone & CLI integration:**
1. BikeRack as a standalone installable (without full Cyclist/Electron)
2. Browser-only mode — pure web dashboard, no Electron dependency
3. CLI-driven panel focus — surface panels from the keyboard without leaving the terminal (Appendix Idea A)

**Team & multi-session:**
4. BikeShop as session router — multiple BikeRacks feed one BikeShop, visible in the ShowRoom with launch URLs (Appendix Idea B)
5. Cross-BikeShop casting — restream telemetry between BikeShops for team visibility, remote observation, and opt-in remote control (Appendix Idea C) **(⚠ see [Remote Control Caution](#remote-control-caution))**
6. ShowRoom dashboard — always-on BikeShop overview with session tiles, sortable metrics, and ShopOwner controls (Appendix Idea E)
7. Leaderboards and races — aggregated cross-session rankings, sprint-scoped competitions, and a query language for ad-hoc comparisons (Appendix Idea G)

**Resilience & capture:**
8. Telemetry capture & replay — BikeShows with no live spectators are written to disk; replay with full time controls (Appendix Idea D)
9. BikeShop auto-failover — preferred/alternate BikeShop with failover timer, local caching, holddown timer, and configurable auto-failback (Appendix Idea F)

**Visualization:**
10. Bike display density modes — thin/compact, boxed, and full/exploded views, auto-scaling by session count (Appendix Idea H)
11. Rider display and party mode — solo, tandem, and multi-agent visualization across ShowRoom and BikeShow views (Appendix Idea I)
12. Context compaction as crash events — collisions in race progress and bike status, crash frequency as a health signal (Appendix Idea J)
13. Status line connection indicators — colored circles in the Claude Code status line showing BikeShop connection health, latency, and authorization level (Appendix Idea K)
14. RaceCoach — workflow feedback and efficiency tips delivered via telemetry analysis, from human-curated rules to behavioral linting to AI-driven suggestions (Appendix Idea L)

**Collaboration:**
15. TeamGear — shared file drive for skills, workflows, knowledge, RAG, commands, and documents between Claude Code sessions; git-backed or lighter sync (Appendix Idea M)
16. Tandem — multi-operator collaboration layering output/input sharing, agent-to-agent bridging, and flow control on top of TeamGear (Appendix Idea N)

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

## Appendix: Ideas & Future Exploration

> **Status:** The following are unvetted ideas and discussion notes. They are not accepted requirements and have not been scoped, estimated, or committed to. Captured here to preserve intent and inform future planning.

> **Terminology note:** The term "BikeRack" is overloaded in this document. In MVP, BikeRack refers to the launcher that starts WheelHub + Claude CLI. In the ideas below, a "coordinating service" emerges as a distinct concept — the process that listens for telemetry, manages session-to-port routing, and can restream data. Whether BikeRack is the launcher, the coordinating service, or both remains an open naming question. The term "coordinating service" is used below as a neutral placeholder for the process that receives, routes, and optionally restreams telemetry and coordinates local session views/tabs.
>
> **Naming brainstorm (evolving):** The ecosystem has distinct roles that benefit from distinct names:
>
> **Components:**
> - **BikeRack** — the launcher and transmitter. Starts a Claude Code session, handles its lifecycle, and transmits telemetry to a BikeShop. One BikeRack per Claude Code session.
> - **BikeShop** — the coordinating service / venue. Receives data from one or more BikeRacks. Creates and manages BikeShows. Has its own ShowRoom. Can also act as a BikeRack to other BikeShops (relay/federation).
> - **ShowRoom** — the BikeShop's native dashboard. Shows status, a visual router of connected sessions, and optionally a session launcher. The "front page" of a BikeShop.
> - **BikeShow** — a live dashboard view of a specific session, created by a BikeShop from a BikeRack's data. A BikeShop creates one or more BikeShows. If no BikeShow is created (no live spectators), the data is still captured to disk.
>
> **Authorization (ssh keypair-based):**
> - **BikeShopPass** — authorization to send data. SSH keypair where the public key is registered with the BikeShop as a "Customer" and the private key is held by the BikeRack. Grants: transmit telemetry, be listed in the ShowRoom.
> - **BikeShopKey** — authorization for remote control. SSH keypair where the public key is registered with the BikeShop as a "ShopOwner" and the private key is held by the BikeRack operator. Grants: create BikeShows, surface/switch panels within a BikeShow, manage routing, and other administrative actions. **(⚠ see [Remote Control Caution](#remote-control-caution) — primary use case is first-party mobile access to your own sessions)**
>
> **Data flow:**
> - BikeRack (launcher) → authenticates with BikeShopPass → BikeShop (receiver)
> - BikeShop creates BikeShow(s) from incoming session data → serves to browser
> - BikeShop (acting as BikeRack) → authenticates with BikeShopPass → another BikeShop (relay)
> - Operator with BikeShopKey → remote control actions on BikeShop (create shows, surface panels, manage routing) **(⚠ [RC Caution](#remote-control-caution))**
>
> **CLI naming (needs work):**
> `/brc` was initially "BikeRackControl" but doesn't map cleanly to all contexts — some commands target the BikeRack (launcher), some target a BikeShop, some target a BikeShow within a BikeShop. Possible directions:
> - Keep `/brc` as a unified entry point with subcommand routing (like `git` — one command, many targets)
> - Split by target: `/rack` for launcher, `/shop` for coordinating service, `/show` for display
> - Use a single short prefix with the target as the first argument: `/brc rack ...`, `/brc shop ...`, `/brc show ...`
>
> No decisions made here; just capturing the naming direction.

### ⚠ Author's Note: On Remote Control and Multi-User Session Access {#remote-control-caution}

> **The author is uncomfortable with the second-party remote control concepts presented in this document.** Several ideas below describe scenarios where someone other than the session owner (e.g., a team lead, a ShopOwner) can remotely control another person's Claude Code session — surfacing panels, creating BikeShows, or issuing commands. These are captured as brainstorming artifacts, not as endorsed designs.
>
> **The primary use case for remote control is first-party mobile access:** the owner/operator of a Bike (Claude Code session) checking on their own long-running sessions from a phone, authorizing permission prompts, starting or progressing work, or reviewing status. This is the Keith-at-dinner scenario (US-K1) — you remote-control your own bikes, not someone else's.
>
> **Actual collaboration should look different.** Rather than one person controlling another person's AI session, collaboration should involve:
> - **Display sharing** — view-only access to a session's BikeShow, so a colleague can see what's happening without being able to act on it
> - **Shared materials** — a protocol for working on shared artifacts (documents, code, specs) where each participant operates their own AI tooling and systems independently
> - **Selective input/output sharing** — maybe sharing some prompts or results between sessions, but each person remains the operator of their own Claude Code instance
> - **Agent-to-agent collaboration** — optional participation in tandem or joint-party workflows where agents coordinate, but this remains dubious and is not a near-term priority
>
> The distinction matters: **sharing what you see is different from controlling what someone else does.** The BikeShop/ShowRoom model is strong for display and observation. Extending it to second-party control of another person's AI session raises questions about agency, consent, and workflow integrity that are not resolved here. Ideas and stories below that reference second-party remote control should be read with this caveat in mind — they are flagged with **(⚠ see [Remote Control Caution](#remote-control-caution))** where they appear.

### Idea A: CLI-Driven Panel Focus (`/brc show`)

The dashboard is passive in MVP — the user must manually switch browser tabs or scroll to find the right panel. A lightweight CLI command could let the user surface a specific panel without leaving the keyboard.

**Concept:**
- Commands like `/brc show sprints`, `/brc show diffs`, `/brc show audit` issued from within Claude Code
- The targeted panel becomes active/visible in the browser — e.g., if it's in a background tab or collapsed, it comes to the foreground
- No layout control, no resizing, no repositioning — just "make this panel the one I'm looking at"
- Primary use case: hands-on-keyboard workflow, user switches dashboard context without mouse or cursor repositioning

**Open questions:**
- What transport carries the focus command from CLI to browser? WebSocket message on an existing channel? New `/ws/control` channel?
- How does "make visible" work across different browser arrangements (multiple tabs vs. single page with panels)?
- Does the dashboard need a panel multiplexer/tab bar to support foreground/background switching within a single browser tab?

### Idea B: BikeShop as Multi-Session Router

MVP is single-session. A BikeShop could receive telemetry from multiple BikeRacks, creating a BikeShow for each and presenting them all in the ShowRoom.

**Concept:**
- A BikeShop runs on a configurable port and acts as the central receiver for one or more BikeRacks
- Each BikeRack authenticates with a BikeShopPass and begins transmitting session telemetry
- The ShowRoom displays a routing view showing which BikeRack sessions are connected and which ports serve their BikeShows
- The BikeShop can create BikeShow instances on specific ports to serve individual sessions
- Launch URLs available from the ShowRoom — e.g., clicking a session tile opens its BikeShow, or CLI commands like `/brc open mybike`, `/brc open hub`, `/brc open bike5` trigger `os open` on the appropriate URL+port
- The ShowRoom routing view is visually navigable and may allow reassigning session-to-port mappings (ShopOwner only, requires BikeShopKey)

**Open questions:**
- Is the BikeShop a new service or an extension of WheelHub?
- Port allocation strategy — static config, dynamic assignment, range-based?
- How does a BikeRack discover its BikeShop? Manual config? mDNS? A registry?
- Does the BikeShop own the BikeShow lifecycle, or do BikeShows self-register?

### Idea C: Cross-BikeShop Casting

BikeShops can forward telemetry to other BikeShops, enabling team-visible dashboards or remote observation. A BikeShop acting as a relay authenticates to the downstream BikeShop using a BikeShopPass, just as a BikeRack would.

**Concept:**
- A BikeShop can restream/cast its session data to another BikeShop at a different address
- Enables scenarios like: team lead watches multiple developers' dashboards, pair programming with shared visibility, remote mentoring
- The receiving BikeShop can also send commands back (remote control) if the sending BikeShop opts in and the operator holds a BikeShopKey on the sender **(⚠ see [Remote Control Caution](#remote-control-caution))**
- Port remapping is automatic within defined ranges to avoid conflicts — each BikeShop has a configured source port range and display port range
- The ShowRoom's visual routing view shows the full topology: which sessions are local, which are relayed from other BikeShops, where data is flowing

**CLI interface (notional):**
- `/brc cast localhost:4456` — stream current session to a local BikeShop on port 4456
- `/brc cast 192.0.2.15:5454` — stream to a remote BikeShop
- `/brc shop3 cast 192.0.2.25:3540` — instruct a named BikeShop ("shop3") to cast to another BikeShop
- `/brc shop3 cast https://myteams.url.invalid/` — cast to a team URL endpoint (HTTPS)
- `/brc shop3 cast ssh://myteams.url.invalid/` — cast to a team endpoint via SSH tunnel

**Configuration:**
- Streaming can be enabled/disabled in preferences or toggled via CLI
- Remote control (receiving commands from a downstream BikeShop) is opt-in, requires BikeShopKey **(⚠ [RC Caution](#remote-control-caution))**
- Port ranges for source and display ports are configurable per BikeShop instance

**Open questions:**
- Latency budget for restreamed data — how many hops before panels feel laggy?
- Conflict resolution when two ShopOwners try to control the same session via different BikeShops? **(⚠ [RC Caution](#remote-control-caution))**
- Is this WebSocket forwarding, OTEL re-export, or a custom protocol?
- How does this interact with corporate firewalls, VPNs, NAT?

### Idea D: Telemetry Capture & Replay

A BikeShow with no live spectators is still a BikeShow — the telemetry data exists whether or not anyone is watching. Capture writes that data to disk. Replay brings it back.

**Concept:**
- When a BikeRack transmits to a BikeShop but no BikeShow is created (no browser viewing it), the BikeShop writes the telemetry to a capture file on disk. The session happened; it just had no live audience.
- A BikeRack can also write captures directly if no BikeShop is running at all — pure local capture with no network dependency.
- The capture file format preserves timestamps and event ordering so sessions can be replayed faithfully.
- A replay mode reads a capture file and feeds it into a BikeShop (or directly into WheelHub) as if it were a live BikeRack session. The BikeShop creates a BikeShow from the replayed data.
- Replay includes time controls: play, pause, speed up, slow down, scrub to timestamp, skip idle gaps.
- Any BikeShop can optionally enable capture alongside its normal live-serving role — record while you watch. This means every BikeShow can also be a capture file.
- Capture can be toggled via preferences or CLI: `/brc capture on`, `/brc capture off`, `/brc capture ~/sessions/debug-2026-02-11.brc`

**Use cases:**
- Post-session review — "what happened in that 3-hour coding session?" without needing live observation
- Debugging — replay a session to understand how a bug was introduced, step through tool calls
- Onboarding/training — record an expert session, replay it for new team members with the full BikeShow panel experience
- Async code review — reviewer replays the session to understand the developer's process, not just the final diff
- Incident forensics — capture is always on in CI/automated sessions, replay when something goes wrong
- Failover gap recovery — cached telemetry during a BikeShop failover window (Idea F) can be written in capture format, making the gap replayable

**Open questions:**
- File format — structured (JSON-lines, protobuf) or OTEL-native export format?
- File size management — how large do capture files get for a multi-hour session? Compression? Rotation?
- Selective capture — can you record only specific channels/panels, or is it always the full stream?
- Replay fidelity — do file watchers (git, sprint YAML) also need captured state, or just OTEL/WebSocket data?
- How does replay interact with the panel state recovery mechanism (FR-15)? Is replay just "reconnection with a historical dataset"?
- Could capture files be shared as artifacts — attached to PRs, Jira tickets, team channels?

### Idea E: The ShowRoom — BikeShop Dashboard & Session Overview

The ShowRoom is the BikeShop's always-on front page. It is not a BikeShow — it's the venue's own view of everything happening inside it.

**Concept:**
- The ShowRoom is always displayed by a BikeShop. It is the default view when you open a BikeShop's URL.
- Provides a visual overview of all active BikeShows: summarized cards or tiles per session
- Each session tile surfaces key metadata at a glance: agent persona/portrait, current workflow stage, context window usage, session duration, story/ticket being worked
- Tiles may include mini-panel previews or sparklines for key metrics

**ShowRoom metrics and sorting:**
- Sessions can be sorted automatically or pinned to fixed positions based on configurable metrics:
  - **Session time** — how long the session has been active
  - **Tokens used** — total token consumption in the session
  - **Velocity** — rate of tokens used over time (speed = "distance/time"); a high-velocity session is burning through work fast
  - **Workflow stage** — where in the workflow the agent currently is (e.g., planning, coding, testing, reviewing)
  - **Story/ticket number** — group or sort by the work item being addressed
  - **Stories completed** — count of completed work items in the session
  - **Context window** — percentage of context consumed; flags sessions approaching limits
- TopN panels: the ShowRoom may feature automatic "top N" views — e.g., "3 most active sessions," "sessions nearest context limit," "longest-running sessions"
- Sorting can be toggled between automatic (metric-driven) and fixed (manually pinned order)

**ShowRoom as launcher:**
- A ShopOwner (BikeShopKey holder) can create new BikeShows from the ShowRoom
- Clicking a session tile opens that session's full BikeShow in a new tab/view
- The ShowRoom may also provide controls to start/stop capture, surface specific panels within a BikeShow, or launch new BikeRack sessions if the BikeShop supports it

**Open questions:**
- How much data do tiles show before it becomes noise? What's the right default card layout?
- Are ShowRoom metrics computed by the BikeShop from raw telemetry, or do BikeRacks transmit pre-aggregated stats?
- Does the ShowRoom support filtering (e.g., "show only sessions on epic X")?
- How does the ShowRoom handle 20+ sessions without becoming unusable? Pagination? Grouping by team/project?
- Can ShowRoom layout/sort preferences be saved per-user or are they BikeShop-wide?

### Idea F: BikeShop Auto-Failover

A BikeRack configured with a preferred and alternate BikeShop can automatically fail over when the preferred shop becomes unavailable, with configurable timers to prevent flapping.

**Concept:**

A BikeRack maintains a connection to its preferred BikeShop. If that connection is lost, the BikeRack doesn't immediately switch — it caches telemetry locally and waits for a configurable **failover timer** to elapse. During this window, the preferred BikeShop may recover (brief network blip, restart, etc.) and the BikeRack reconnects without disruption. If the failover timer expires and the preferred BikeShop is still down, the BikeRack fails over to the alternate BikeShop.

The BikeRack periodically probes the alternate BikeShop in the background to determine if it is "open" (available to receive Customers). Failover only occurs if the alternate is confirmed open. If the alternate is also down, the BikeRack continues caching locally until one of the two becomes available.

**Failover behavior:**
- **Failover timer** (configurable) — the BikeRack does not fail over until this timer elapses after losing the preferred BikeShop. Telemetry is cached locally during this window.
- On failover, the cached telemetry is flushed to the alternate BikeShop so no data is lost.
- The BikeRack authenticates to the alternate BikeShop with its BikeShopPass (the alternate must have the BikeRack's public key registered).

**Failback behavior — two modes:**

*Automatic failback enabled:*
- After failover, a **holddown timer** (configurable) begins. The BikeRack will not fail back to the original preferred BikeShop until the holddown timer elapses, even if the preferred shop recovers immediately. This prevents flapping.
- Once the holddown timer elapses AND the preferred BikeShop is confirmed open, the BikeRack fails back to the preferred BikeShop automatically.

*Automatic failback disabled:*
- After failover, the BikeRack does NOT fail back to the original preferred BikeShop, regardless of the holddown timer. Instead, it swaps the preference order — the alternate becomes the new preferred, and the original becomes the new alternate.
- The holddown timer still runs, but only governs eligibility for a *subsequent* failover. A second failover (from the now-preferred to the now-alternate) only triggers if ALL of the following are true:
  1. The now-preferred BikeShop (originally the alternate) goes down
  2. The now-alternate BikeShop (originally the preferred) is confirmed open
  3. The holddown timer from the original failover has elapsed
- This means in the no-auto-failback case, a recovered BikeShop sits as a warm standby until it's actually needed again.

**Configuration (notional):**
```
bikeshop:
  preferred: ssh://teamshop.internal:4456/
  alternate: ssh://teamshop-backup.internal:4457/
  failover_timer: 30        # seconds before failover
  holddown_timer: 300       # seconds before failback eligible
  auto_failback: true       # or false
```

**CLI (notional):**
- `/brc failover status` — show current preferred/alternate, connection state, timer states
- `/brc failover now` — force immediate failover (bypasses failover timer)
- `/brc failback now` — force immediate failback (bypasses holddown timer, only if auto_failback is enabled or as manual override)

**Open questions:**
- How much telemetry can be cached locally before memory/disk pressure becomes a concern? Is there a cache size limit or eviction policy?
- Should the cached data be written to the capture file format (Idea D) so it's recoverable even if the BikeRack itself crashes during the failover window?
- Does the alternate BikeShop need to know it's an alternate, or is it just another shop that accepts Customers?
- Should failover events be visible in the ShowRoom (Idea E) — e.g., a session tile showing "failed over from teamshop-primary"?
- Can there be more than two BikeShops in a failover chain (primary → secondary → tertiary), or is it strictly a pair?
- How does failover interact with BikeShop-to-BikeShop relay (Idea C)? If a relaying shop fails over, does the downstream shop see a disruption?

### Idea G: Leaderboards & Races

BikeShops don't just display live sessions — they can aggregate data across sessions and time to produce leaderboards and competitive/comparative views.

**Leaderboards:**
- BikeShops can compute and display leaderboards from historical and live session data
- Leaderboard scopes: all-time, time-ranged (this week, this sprint, custom range), or per-race
- Leaderboard metrics mirror ShowRoom metrics (Idea E) but aggregated: total tokens, stories completed, velocity, session hours, context efficiency, etc.
- Leaderboards rank Bikes (sessions/developers) in a TopN panel display

**Races:**
- A "race" is a scoped competition or comparison — not fully defined, but likely maps to activity during a sprint, a milestone, an epic, or an arbitrary query
- Races are defined by some query language that combines data from multiple sessions: filters (which sessions, which time range, which work items), an ordering metric, and a display format
- Examples: "Top 5 bikes by stories completed in Sprint 47," "Fastest bike to close Story #142," "Most tokens burned this week"
- Races could be predefined (sprint-scoped, auto-created) or ad-hoc (ShopOwner creates one from the ShowRoom)

**Open questions:**
- What is the race query language? SQL-like? A structured config? A ShowRoom UI builder?
- Are leaderboards public to all ShowRoom viewers, or can they be scoped by BikeShopKey permissions?
- How do races handle sessions that span multiple sprints or work items?
- Do races have a "finish line" (terminal condition) or are they continuously updated?
- Can races include replayed capture data (Idea D), or only live/historical session data?

### Idea H: Bike Display Density Modes

Bikes displayed in BikeShop and BikeShow views can be rendered at different density levels depending on screen real estate, user preference, or the number of sessions being shown.

**Display modes:**
- **Thin/Compact** — dense, minimal. Shows the essentials: bike name, rider persona icon, a single key metric (e.g., workflow stage or velocity), and a status indicator. Suitable for ShowRooms with many sessions or for sidebar/ticker views. Think: one-line-per-bike.
- **Boxed** — moderate detail. A card/tile with persona portrait, 3-5 key metrics, workflow stage, story number, and mini sparklines. The default ShowRoom tile size. Enough to understand what's happening at a glance without opening the full BikeShow.
- **Full/Exploded** — expanded view with all major elements visible: full persona portrait, all metrics, panel previews, recent activity feed, context window gauge, token burn chart. Useful when focused on a single bike or when screen space permits.

**Behavior:**
- Display mode can be set globally (all bikes in a view) or per-bike
- The ShowRoom may auto-select density based on session count — e.g., >10 sessions defaults to thin, 4-10 defaults to boxed, <4 defaults to full
- Users/ShopOwners can override the auto-selection

**Open questions:**
- Are density modes a ShowRoom-only concept, or do they apply within BikeShows too (e.g., a BikeShow's panel sidebar)?
- Can density modes be mixed in one view — e.g., one featured bike in full, the rest in thin?
- How do density transitions animate — instant swap, or smooth resize?

### Idea I: Rider Display & Party Mode

Bikes in BikeShop and BikeShow views show who's riding — the active agent persona(s). This extends the PortraitPanel concept (FR-19–21) to the ShowRoom and multi-session views.

**Rider display modes:**
- **Solo rider** — a single agent persona is active. The bike shows one rider portrait/icon (name, persona image, role). This is the default for most sessions.
- **Tandem riders** — two agents are active (e.g., TEA + Architect in a tdd-tandem workflow). The bike shows both riders with the primary (driver) prominent and the backseat (advisor) secondary. Matches the existing PortraitPanel main-over-backseat layout but applied to ShowRoom tiles and compact views.
- **Party mode** — more than two agents or a collaborative/swarm session. Multiple rider portraits displayed, possibly with role indicators. The visual treatment differs from tandem — it's a group, not a driver/passenger pair.

**Behavior:**
- Rider display updates in real-time as agents change during workflow handoffs
- In thin/compact density (Idea H), rider display may collapse to an icon + count (e.g., persona icon with "×2" for tandem, "×4" for party)
- In full/exploded density, all riders are shown with names, roles, and portraits

**Open questions:**
- What constitutes "party mode" technically? A threshold of active agents? A specific workflow type?
- How does party mode interact with the PortraitPanel in a BikeShow — does the PortraitPanel itself support party layout, or is this ShowRoom-only?
- Should rider history be visible — e.g., "TEA drove for 20 min, then Architect took over"?

### Idea J: Context Compaction as Collision/Crash Events

Context compaction — when the context window is compressed, summarized, or reset to free up space — is a significant session event. In the cycling metaphor, it maps naturally to a collision or crash: the bike was riding along, hit a wall (context limit), and had to recover.

**Concept:**
- Context compaction events are visually represented as collisions/crashes in race views and bike status displays
- In a race progress view (Idea G), a compaction shows as a crash icon or interruption in the bike's progress line — the bike stumbles, recovers, and continues
- In bike status tiles (Idea H), a recent compaction might show as a crash indicator with recovery state: "crashed 3 min ago, recovered, 22% context now"
- Multiple compactions in a session tell a story — a bike that keeps crashing may be on a bad road (poorly scoped task, runaway context growth)

**Visual treatment (notional):**
- Race/progress view: smooth line interrupted by a crash icon, then resuming at a lower position (context % dropped)
- Tile/card: a small crash badge or icon with count ("2 crashes") and time-since-last
- Full/exploded view: a timeline of compaction events with before/after context percentages and what was lost

**Open questions:**
- Are all compaction types treated the same (crash), or are graceful compactions (planned summarization) visually distinct from emergency compactions (hard limit hit)?
- Should crash frequency factor into leaderboard/race scoring (Idea G)? E.g., a bike that completes more stories with fewer crashes ranks higher?
- Does a crash event pause the bike's velocity calculation, or does recovery time count against it?
- Should the ShowRoom alert when a bike is approaching a crash (context window > 85%)?

### Idea K: Claude Code Status Line — BikeRack Connection Indicators

The Claude Code status line displays one or more colored circles indicating the live status of the BikeRack's connection to each configured BikeShop. This gives the CLI user at-a-glance visibility into their dashboard infrastructure without leaving the terminal.

**Connection status colors:**
- **Green** — connected, healthy
- **Yellow** — connected, elevated jitter or latency (threshold configurable, e.g., >200ms)
- **Orange** — connected, high jitter or latency (threshold configurable, e.g., >500ms)
- **Red** — disconnected (connection lost, failover timer may be running)
- **Gray** — not configured / no BikeShop target
- **White/flashing** — unauthorized (BikeShopPass rejected or not yet authenticated)

**Authorization/role indicators:**
Each circle is visually modified to indicate the operator's authorization level on that BikeShop:
- **Plain circle** — Customer (BikeShopPass only, can transmit telemetry)
- **Circle with key icon** — ShopOwner (BikeShopKey held, can manage BikeShop via remote control)
- **Circle with bisecting line** — Remote Control active (operator is currently remote-controlling one of their own Bikes on that BikeShop) **(⚠ [RC Caution](#remote-control-caution))**
- **Circle with outer ring** — alternative/additional indicator (exact visual treatment TBD)

The specific glyphs/decorators are TBD and may depend on terminal capabilities (Unicode support, color depth), but the principle is: connection health is the circle color, authorization level is the circle decoration.

**Behavior:**
- One circle per configured BikeShop (preferred and alternate at minimum, more if multiple shops configured)
- Circles update in real-time as connection state changes
- During failover (Idea F), the preferred circle goes red while the alternate circle transitions from gray to green
- Hovering or focusing the status line area (if the terminal supports it) could show a tooltip with detailed stats: latency in ms, jitter, uptime, auth level, BikeShop name
- If no BikeShop is configured (MVP local-only mode), no circles are shown

**Open questions:**
- Where exactly in the Claude Code status line do the circles appear? Left, right, near the model indicator?
- How many BikeShops can be shown before the status line becomes cluttered? Is there a max, or does it collapse to a summary (e.g., "3/4 connected")?
- Should the latency thresholds for yellow/orange be configurable per-BikeShop or global?
- Do the circles need to be accessible to colorblind users? If so, shape or pattern variations may be needed alongside color.
- Can the user click/interact with a circle to get details, or is it purely informational?
- Should there be a distinct indicator for "caching locally" state (failover timer running, data buffering)?

### Idea L: RaceCoach — Workflow Feedback and Efficiency Tips

A RaceCoach observes the telemetry stream and provides actionable feedback to the Claude Code user when inefficiencies, missed opportunities, or anti-patterns are detected in their session.

**Concept:**

A RaceCoach analyzes the data flowing through the BikeRack/BikeShop pipeline — context window usage, workflow stage transitions, persona switches, tool call patterns, gate completions, document interactions — and surfaces tips, warnings, or suggestions to the operator. It's a feedback layer, not a control layer: the RaceCoach advises, the rider decides.

**Feedback categories:**
- **Context window efficiency** — "You're at 72% context and haven't compacted. Consider summarizing before starting the next story." / "Your last 3 sessions all crashed at ~90% context. Try compacting proactively at 70%."
- **Workflow step ordering** — "You skipped the acceptance criteria review step. Sessions that complete AC review before coding have 40% fewer rework cycles." / "Consider running tests before the diff review — catches issues earlier."
- **Persona suggestions** — "You've been in Architect for 45 minutes on implementation work. Consider switching to TEA for the TDD cycle." / "This workflow stage typically runs faster with White Rabbit."
- **Agent action triggers** — "Story #188 has unresolved acceptance criteria. Consider triggering the AC gate before moving to the next story." / "The sprint YAML hasn't been updated in 3 hours — your velocity tracking may be stale."
- **Document timing** — "The design doc was last reviewed at the start of the session. Consider re-reading it before the integration phase — requirements may have evolved." / "You have uncommitted changes across 12 files. Consider a checkpoint commit."

**RaceCoach sources (from least to most autonomous):**
- **Human-originated** — a ShopOwner or team lead writes tips manually and attaches them to workflow stages, persona transitions, or metric thresholds. Essentially curated advice triggered by telemetry conditions. These could be maintained as a library of tips shared across a BikeShop.
- **Behavioral linter** — a rules engine that evaluates telemetry against configurable patterns. "If context > 80% AND no compaction in last 30 min, suggest compaction." / "If workflow = tdd-tandem AND persona = Architect AND duration > 30 min, suggest persona switch." Deterministic, auditable, version-controlled rules.
- **AI-driven** — an AI model observes the telemetry stream and generates contextual suggestions. More adaptive than rules but less predictable. Could reference historical session data ("developers who worked on this codebase typically switched personas at this stage"). Raises questions about cost, latency, and trust.

**Delivery mechanisms:**
- **BikeShow overlay** — tips appear as non-intrusive notifications in the BikeShow browser view (toast, sidebar, or inline on relevant panels)
- **CLI notification** — tips appear in the Claude Code status line or as a bracketed message in the terminal output
- **ShowRoom integration** — the ShowRoom could show a "coaching summary" per session: tips delivered, tips acted on, efficiency score
- **Capture annotation** — tips are recorded in capture files (Idea D) alongside the telemetry, so replayed sessions include the coaching context

**Behavior:**
- RaceCoach is opt-in — disabled by default, enabled per-session or per-BikeShop
- Tips can be dismissed, snoozed, or marked as "not helpful" to improve future suggestions
- Frequency is configurable — "at most one tip every 5 minutes" to prevent nagging
- Tips never block or interrupt the Claude Code session — they are advisory only

**Open questions:**
- Who authors the behavioral linter rules? The operator? The ShopOwner? A shared team config?
- How does the AI-driven coach avoid being annoying or wrong? Is there a confidence threshold below which tips are suppressed?
- Should RaceCoach feedback be visible to others in the ShowRoom, or only to the session operator? (Privacy implications — a team lead seeing "you should have compacted 20 minutes ago" on someone else's tile feels judgmental)
- Can RaceCoach tips be scoped to specific workflows, personas, or project types?
- How does RaceCoach interact with the crash metaphor (Idea J)? Does it become a "pit crew" that warns before crashes?
- Cost model for AI-driven coaching — is it a separate API call per tip? Batch analysis? On-device model?
- Could RaceCoach tips be crowd-sourced across a BikeShop — "3 of 5 developers who hit this pattern found this tip helpful"?

### Idea M: TeamGear — Shared Materials Between Sessions

TeamGear is a shared file "drive" between two or more Claude Code sessions. It provides a common surface for skills, workflows, knowledge bases, RAG sources, commands, and documents — without involving any shared control of the AI sessions themselves.

**Concept:**

TeamGear is **not** Tandem (Idea N). It is not co-work, not agent bridging, not input/output sharing. It is a shared filing cabinet: multiple Claude Code sessions (whether on the same machine or operated by different people) can read from and write to a common set of materials.

**What can be shared via TeamGear:**
- **Skills** — slash commands, skill definitions, prompt templates
- **Workflows** — workflow definitions, stage configs, gate criteria
- **Knowledge** — reference documents, architecture docs, runbooks, onboarding guides
- **RAG sources** — indexed document sets that sessions can query against
- **Commands** — shared aliases, macros, or composite commands
- **Documents** — working documents, specs, design docs, meeting notes, any file that multiple sessions need to reference or co-edit

**Backing mechanism (TBD):**
- **Git-backed with fast path** — a shared git repo with automerge for non-conflicting changes. Sessions push/pull automatically. Conflicts are flagged rather than silently resolved. This gives versioning, history, and diff visibility for free, but may be heavy for frequent small updates.
- **Lighter file sharing** — a shared directory (local filesystem, NFS, or synced folder) with file-level locking or last-write-wins semantics. Faster for small, frequent changes but no built-in history.
- **Hybrid** — lightweight sync for hot files (active documents, current workflow state), git-backed for durable artifacts (skills, knowledge, RAG indexes).

**Access model:**
- TeamGear is configured per-session: each Claude Code instance opts in to a specific TeamGear set
- Multiple TeamGear sets can exist (e.g., "team-frontend-gear", "project-alpha-gear", "keith-personal-gear")
- Read/write permissions may be scoped — some sessions read-only, some read-write
- TeamGear lives independently of any BikeShop — it's a session-to-session concern, not a display concern. But a BikeShop's ShowRoom could display TeamGear status (which sessions are connected to which gear sets, last sync time, conflicts)

**Open questions:**
- How does a session discover available TeamGear sets? Config file? BikeShop registry? Manual path?
- Conflict resolution — what happens when two sessions modify the same skill file? Automerge? Last-write-wins? Prompt the operator?
- How does TeamGear interact with CLAUDE.md and existing per-project configs? Is TeamGear a layer above, below, or beside project-local settings?
- Performance — how fast do changes propagate? Seconds? Sub-second? Does it matter for most use cases?
- Versioning — can a session pin to a specific version of a skill or workflow from TeamGear, or is it always latest?
- Security — can TeamGear contain secrets (API keys, credentials)? If so, how are they protected at rest and in transit?
- Does TeamGear have a CLI? e.g., `/gear sync`, `/gear status`, `/gear add workflow.yaml`

### Idea N: Tandem — Multi-Operator Collaboration

> **Terminology note:** "Tandem" is already used in this document and in Cyclist to describe two-agent workflows (e.g., tdd-tandem where TEA and Architect cooperate within a single session). Idea N uses "Tandem" to describe **multi-operator** collaboration — two or more humans, each with their own Claude Code session, working together. These are different concepts. The naming may need to diverge (e.g., "agent tandem" vs. "operator tandem" or a different term entirely for multi-operator collaboration). Captured here under "Tandem" as a placeholder.

Tandem builds on TeamGear (Idea M) but goes further: it adds input/output sharing, agent-to-agent communication bridging, and flow control between sessions operated by different people.

**Concept:**

Where TeamGear shares static materials (files, skills, knowledge), Tandem shares the live session: what the agents are doing, what they're producing, and optionally what they should do next. This is the actual human-AI co-work concept — not one person controlling another's session **(⚠ see [Remote Control Caution](#remote-control-caution))**, but two operators working in parallel with their AI agents coordinating.

**Tandem capabilities (layered, each optional):**
- **TeamGear (base layer)** — shared skills, workflows, knowledge, documents (Idea M). Always present in a Tandem session.
- **Output sharing** — one session's agent output (diffs, test results, summaries, artifacts) is selectively visible to another session. Not full telemetry streaming (that's what BikeShop does) — this is curated, relevant output surfaced in the other operator's context.
- **Input sharing** — one operator can share a prompt, instruction, or context snippet with another session. The receiving session's operator decides whether to act on it. Think: passing a note, not taking the wheel.
- **Agent-to-agent bridging** — the agents in two sessions can communicate directly: "I've finished the API endpoint, here's the interface contract" → the other session's agent receives this and can act on it. This requires a message protocol between agents and raises significant questions about trust, context pollution, and runaway coordination.
- **Flow control** — coordinating the order of operations across sessions. "Session A completes the schema migration, then Session B runs the integration tests." Could be manual (operators coordinate via chat) or automated (a shared workflow definition with cross-session gates).

**What Tandem is NOT:**
- Not remote control — each operator controls their own session
- Not screen sharing — each operator has their own view (though they may share a BikeShop/ShowRoom for visibility)
- Not a single shared session — each operator has their own Claude Code instance, their own context window, their own agent

**Open questions:**
- How is a Tandem session initiated? One operator invites another? Both join a named Tandem room?
- Trust boundaries — when Agent A sends a message to Agent B, how does Agent B's operator verify the message is legitimate and useful? Is there a review step?
- Context pollution — does receiving another agent's output consume context window? How is this budgeted?
- Flow control complexity — automated cross-session gates could become a distributed workflow engine. Is that desirable, or should flow control remain human-coordinated?
- How does Tandem interact with the BikeShop? Are Tandem sessions visually linked in the ShowRoom? Do they share a BikeShow, or each have their own?
- Is agent-to-agent bridging even a good idea? The author has significant reservations (see [Remote Control Caution](#remote-control-caution) for related concerns about agency and consent). Agents coordinating without human review at each step could produce unexpected or undesirable outcomes.
- What's the minimum viable Tandem? Probably just TeamGear + output sharing. Input sharing and agent bridging are progressively more ambitious and dubious.

### Appendix User Stories

> **Status:** These stories illustrate how the appendix ideas might work in practice. They are exploratory — not committed scope. They use the evolving BikeRack/BikeShop/BikeShow/ShowRoom terminology.

#### Story US-A1: CLI-Driven Panel Focus

Keith is deep in a TDD cycle. Claude just ran tests and three failed. Keith types `/brc show diffs` in his terminal — the DiffsPanel surfaces in his browser without Keith touching the mouse. He scans the changes, types `/brc show audit` to check the tool call spans, spots the issue, and goes back to his terminal. His hands never left the keyboard.

**Exercises:** Idea A — CLI-to-browser focus commands, hands-on-keyboard workflow.

#### Story US-B1: Second Session in the ShowRoom

Keith has a Claude session working on a refactor. He opens a second terminal and runs `bikerack --shop local` to connect a new session to his local BikeShop. He opens the ShowRoom in his browser — both sessions appear as tiles. The first tile shows "White Rabbit / tdd-tandem / Story #142 / 47 min / 38k tokens." The second shows "Architect / planning / Story #155 / 2 min / 1.2k tokens." He clicks the second tile to open its BikeShow.

**Exercises:** Idea B — multi-session routing; Idea E — ShowRoom overview tiles with metadata.

#### Story US-B2: Opening a BikeShow from CLI

Keith doesn't want to switch to the browser to find his session. He types `/brc open refactor-session` — his OS opens a browser tab directly to that BikeShow's URL on the BikeShop's port. He also tries `/brc open showroom` to pull up the ShowRoom itself.

**Exercises:** Idea B — launch URLs from CLI, `/brc open` commands.

#### Story US-D1: Capture with No Live Spectators

Keith starts a long-running automated Claude session overnight. No BikeShop is running — there's no audience. BikeRack writes telemetry to `~/.bikerack/captures/2026-02-11-migration.brc`. In the morning, Keith starts his BikeShop, loads the capture file, and replays it. He scrubs to the 2-hour mark where the migration hit an error, slows playback to 0.25x, and watches the AuditLog and DiffsPanel step through what happened.

**Exercises:** Idea D — capture-only mode (no live spectators), replay with time controls (scrub, slow-motion).

#### Story US-D2: Record While You Watch

Keith is working a live session with his BikeShop running. He types `/brc capture on` — the BikeShop starts writing telemetry to disk alongside serving live BikeShows. At the end of the session, Keith has both the live experience and a capture file he can attach to his PR for async review.

**Exercises:** Idea D — optional capture alongside live serving, capture files as shareable artifacts.

#### Story US-C1: Publishing to a Team BikeShop

Keith's team runs a shared BikeShop on an internal server. Keith's local BikeShop is already running. He types `/brc cast ssh://teamshop.internal:4456/` — his local BikeShop authenticates with its BikeShopPass and begins relaying his session's telemetry to the team BikeShop. On the team ShowRoom, Keith's session appears as a new tile alongside his teammates' sessions.

**Exercises:** Idea C — BikeShop-to-BikeShop relay, BikeShopPass authentication, SSH transport.

#### Story US-E1: Team Lead Monitors from the ShowRoom

Dana is the team lead. She opens the team BikeShop's ShowRoom and sees 4 active sessions. She sorts by velocity — Keith's session is burning through tokens fastest. She sorts by workflow stage — two sessions are in "testing," one is in "planning," one is in "reviewing." She clicks Keith's tile to open his BikeShow and watches his DiffsPanel to stay current on the refactor.

**Exercises:** Idea E — ShowRoom sorting by metrics (velocity, workflow stage), tile-to-BikeShow navigation.

#### Story US-E2: ShopOwner Remote Control **(⚠ see [Remote Control Caution](#remote-control-caution))**

> **Note:** This story depicts second-party remote control of another person's session. The author considers this dubious as a design direction. Display sharing (view-only BikeShow access) covers most of this scenario without the control implications. Included here to illustrate the concept, not to endorse it.

Dana notices Keith's session is approaching the context window limit (ShowRoom tile shows 89% context). She holds a BikeShopKey. From the ShowRoom, she surfaces Keith's AcceptanceCriteriaPanel to check if the current story is close to done, then creates a new BikeShow combining Keith's and Amir's sessions side by side to compare their approaches to the same epic.

**Exercises:** Idea E — ShowRoom context window metric, BikeShopKey remote control (surface panels, create BikeShows).

#### Story US-C2: BikeShop-to-BikeShop Relay

The team has two BikeShops — one in the Portland office, one in the Dublin office. Dana (Portland, ShopOwner on both) types `/brc portland relay ssh://dublin.internal:5500/` — the Portland BikeShop begins relaying all its sessions to Dublin. The Dublin ShowRoom now shows both local Dublin sessions and relayed Portland sessions, distinguished visually. Port remapping happens automatically within Dublin's configured range.

**Exercises:** Idea C — cross-shop relay, automatic port remapping, visual routing topology.

#### Story US-F1: New Developer Onboarding

Amir just joined the team. Dana generates a BikeShopPass for him and sends the keypair. Amir configures his local BikeRack with the private key and the team BikeShop's address. He runs `bikerack --shop team` — his session authenticates and appears in the team ShowRoom. He also loads one of Keith's capture files from the team's shared drive and replays it in his local BikeShop to learn how the codebase is typically worked.

**Exercises:** BikeShopPass onboarding, capture replay for training, discovery via manual config.

#### Story US-F1b: BikeShopPass Revocation

Amir leaves the team. Dana revokes his BikeShopPass by removing his public key from the team BikeShop. The next time Amir's BikeRack tries to connect, the BikeShop rejects the authentication. Amir's BikeRack logs the rejection and falls back to local capture — his Claude session continues uninterrupted in the terminal, but telemetry is written to disk instead of streaming to the team BikeShop. Amir sees a clear error: "BikeShopPass rejected by teamshop.internal — key not recognized. Session data is being captured locally." His session tile no longer appears in the team ShowRoom. If Amir later rejoins and Dana issues a new BikeShopPass, he reconfigures and reconnects.

**Exercises:** BikeShopPass revocation, graceful auth rejection, fallback to local capture, no disruption to CLI session.

#### Story US-F2: BikeShop Goes Down — Failover with Auto-Failback

Keith is mid-session when the team BikeShop goes down. His BikeRack detects the lost connection but doesn't panic — it starts caching telemetry locally and begins counting down the 30-second failover timer. Claude continues running in his terminal, unaffected. At 15 seconds, the BikeShop is still down. At 30 seconds, the failover timer expires. Keith's BikeRack has been probing the alternate BikeShop (`teamshop-backup`) and confirms it's open. The BikeRack fails over — flushes its cached telemetry to the backup and starts streaming live. Keith's session tile appears in the backup ShowRoom. Two minutes later, the primary BikeShop recovers. But Keith's BikeRack doesn't switch back yet — the 5-minute holddown timer is still running. After 5 minutes with the primary confirmed open, the BikeRack automatically fails back. Keith's session tile reappears in the primary ShowRoom. He never left his terminal.

**Exercises:** Idea F — failover timer, local caching, alternate probing, auto-failback with holddown timer, zero disruption to CLI.

#### Story US-F3: BikeShop Goes Down — Failover without Auto-Failback

Same scenario, but Keith's team has `auto_failback: false`. The primary BikeShop goes down, the failover timer expires, and Keith's BikeRack fails over to the backup. The primary recovers 2 minutes later. Keith's BikeRack does NOT switch back. Instead, it swaps preference order — backup is now preferred, primary is now alternate. Keith stays on the backup. The holddown timer runs in the background. Hours later, the backup BikeShop has a planned maintenance window and goes down. The holddown timer from the original failover has long since elapsed, and the original primary is confirmed open — so Keith's BikeRack fails over again, back to the original. The preference order swaps once more.

**Exercises:** Idea F — no-auto-failback mode, preference reordering, holddown timer governing subsequent failover eligibility.

#### Story US-F4: Brief Outage — Failover Timer Absorbs the Blip

Keith's team BikeShop restarts for a quick update — it's down for 12 seconds. Keith's BikeRack detects the lost connection and starts caching, but the 30-second failover timer hasn't elapsed yet. The BikeShop comes back at 12 seconds. The BikeRack reconnects to the preferred shop, flushes the 12 seconds of cached data, and resumes streaming. No failover occurred. The backup BikeShop never saw Keith's session.

**Exercises:** Idea F — failover timer preventing unnecessary failover on brief outages, cache flush on reconnect.

#### Story US-G1: Sprint Leaderboard

It's mid-sprint. Dana opens the team BikeShop's ShowRoom and switches to the leaderboard view. She selects "Sprint 47" scope and sorts by stories completed. Keith leads with 7, Amir has 5, Li has 4. She switches the metric to velocity — now Li is on top, burning through tokens at the highest rate despite fewer completions. Dana makes a mental note to check if Li's current story is unusually large. The leaderboard updates in real-time as sessions progress.

**Exercises:** Idea G — time-ranged leaderboard (sprint-scoped), multiple sort metrics, live updates.

#### Story US-G2: Ad-Hoc Race

Dana wants to compare how three developers tackled the same epic over the past week. She creates an ad-hoc race from the ShowRoom: scope is "Epic #23, last 7 days," participants are Keith, Amir, and Li, metric is stories completed weighted by crash count. The race view shows three bikes on a progress track — Keith is ahead on completions but has had 4 context crashes; Amir is close behind with zero crashes. Dana shares the race URL with the team for the retro.

**Exercises:** Idea G — ad-hoc race creation, query combining sessions by epic and time range, composite metrics, shareable race view.

#### Story US-H1: ShowRoom Auto-Density

Dana's team BikeShop has 12 active sessions. The ShowRoom auto-selects thin/compact view — each bike is a single dense row: name, rider icon, workflow stage, velocity sparkline, and a context gauge. Dana clicks Keith's row — it expands to boxed view inline, showing his full tile with 5 metrics and portrait. She double-clicks to open his full BikeShow. Later, it's evening and only 2 sessions are active. The ShowRoom auto-switches to full/exploded — each bike gets the full treatment with panel previews and activity timelines.

**Exercises:** Idea H — auto-density based on session count, thin/compact for many, full/exploded for few, per-bike override via click.

#### Story US-I1: Tandem Riders in the ShowRoom

Keith is in a tdd-tandem workflow. In the ShowRoom, his bike tile shows two riders: TEA (driver, prominent) over Architect (backseat, smaller). Mid-session, the workflow hands off — Architect takes over. The tile animates the swap: Architect moves to the driver position, TEA drops to backseat. In thin/compact density, this shows as a persona icon with "×2" and the driver's name.

**Exercises:** Idea I — tandem rider display, real-time handoff animation, density-appropriate rendering.

#### Story US-I2: Party Mode

Amir kicks off an experimental swarm workflow with 4 agents collaborating. His bike in the ShowRoom shifts to party mode — four small rider portraits arranged in a cluster, distinct from the tandem driver/passenger layout. The tooltip shows all four agents and their roles. In thin/compact view, the tile shows a party icon with "×4."

**Exercises:** Idea I — party mode display for multi-agent sessions, visual distinction from tandem.

#### Story US-J1: Context Crash During a Race

Keith's bike is leading in the Sprint 47 race. He's been pushing hard on a large refactor and his context window hits 98%. Compaction fires — in the race progress view, Keith's bike shows a crash icon. His progress line stutters and drops (context reset from 98% to 24%). He recovers and keeps going, but the crash cost him time. Amir, riding steady with no crashes, closes the gap. The leaderboard optionally factors crash count into the ranking — Keith still leads on raw completions but Amir leads on "clean completions."

**Exercises:** Idea J — compaction as crash in race view, Idea G — crash-aware leaderboard scoring.

#### Story US-J2: Repeated Crashes as a Warning Signal

Li's session has hit 3 context compactions in the last hour. In the ShowRoom, Li's bike tile shows a crash badge "3 crashes" with a warning color. Dana notices and checks — Li is working on a massive file with a sprawling context. The full/exploded view shows a timeline: crash at 2:14pm (95%→18%), crash at 2:47pm (92%→21%), crash at 3:12pm (89%→19%). The pattern suggests the task may need to be scoped differently. Dana messages Li to suggest breaking the story into smaller pieces.

**Exercises:** Idea J — crash frequency as health signal, crash timeline in exploded view, Idea H — full density for investigation.

#### Story US-K1: Mobile Remote Control — Dinner Interlude

Keith is at dinner with his Queen. She gets pulled into an emergency work call. Keith has a few minutes — he pulls out his phone and opens the team BikeShop in his mobile browser. The BikeShop is public-facing (available on the internet), and Keith has BikeShopKeys generated on his phone and registered with the BikeShop, giving him ShopOwner-level remote control.

The ShowRoom loads in a mobile-friendly layout — compact tiles, touch-optimized. He sees three of his bikes from earlier in the day, idle but still connected. He taps into the first bike's BikeShow. The mobile view offers two modes: a **console tab** showing Claude Code output (scrollable, last N lines buffered) with an input bar for entering prompts, acknowledging or denying permission requests; and a **compact GUI BikeShow** with the key panels rendered in a touch-friendly density.

Keith switches to the console tab on bike 1 and kicks off a workflow: `/dev story-188`. He swipes to bike 2, enters a skill command. Bike 3 gets a quick prompt to unblock a stalled test run. He flips back to bike 1 — the workflow is already underway, the compact BikeShow shows White Rabbit active in the PortraitPanel, DiffsPanel updating. A permission prompt comes in — he taps "Allow."

His Queen returns from the call. Keith locks his phone and they resume their evening, both happier — she resolved her emergency, he unblocked three sessions that would have sat idle until morning. Opportunity seized in the gap, not at the expense of the moment.

**Exercises:** Mobile-friendly BikeShop/ShowRoom, BikeShopKey on mobile device, remote control (Idea C) from phone, console tab with scrollback/input/permission handling, compact GUI BikeShow (Idea H — thin/compact density on small screen), multi-session management from mobile, public-facing BikeShop with auth.

#### Story US-K2: Status Line — Connection at a Glance

Keith starts his morning. He runs `bikerack --shop team` and Claude Code launches. In the status line, two circles appear: a green circle with a key icon (team BikeShop — connected, ShopOwner) and a gray plain circle (backup BikeShop — configured but not active). He starts working.

Mid-morning, the team BikeShop hits a load spike. The green circle shifts to yellow — latency has crossed 200ms. Keith notices but keeps working; the panels are still updating, just slightly slower. A minute later it recovers — back to green. Later, a network hiccup drops the connection entirely. The first circle goes red. The second circle transitions from gray to green as the BikeRack fails over to the backup. Keith sees the state change in his status line without checking the browser — red dot, green dot, he knows exactly what happened.

After lunch, Keith starts a remote control session on one of his own idle bikes from his terminal. A third indicator appears: a green circle with a bisecting line — he's actively remote-controlling one of his Bikes via the team BikeShop. When he finishes and disconnects the remote session, the bisecting line disappears, reverting to the key-decorated circle. **(⚠ see [Remote Control Caution](#remote-control-caution) — remote control of another person's Bike is not the intended use case; this story depicts first-party access to Keith's own sessions)**

**Exercises:** Idea K — status line circles, color transitions (green→yellow→red→green), authorization decorators (key for ShopOwner, bisecting line for active remote control), failover visibility (Idea F), multi-BikeShop indicators.

#### Story US-L1: RaceCoach — Behavioral Linter Tip

Keith is 40 minutes into a coding session. His context window is at 76% and climbing. A small notification appears in his BikeShow's sidebar: "Context at 76% with no compaction this session. Your last 3 sessions crashed between 88-94%. Consider compacting now to preserve headroom." Keith glances at it, agrees — he'd been heads-down and lost track. He triggers a compaction. The tip is recorded in the capture file. Later, reviewing the session replay, he can see exactly when the coach nudged him and that he acted on it.

**Exercises:** Idea L — behavioral linter rule (context threshold + historical crash pattern), BikeShow overlay delivery, tip recorded in capture (Idea D).

#### Story US-L2: RaceCoach — Workflow Step Suggestion

Amir is working a tdd-tandem workflow. He's been in the Architect persona for 35 minutes writing implementation code. A RaceCoach tip appears in his terminal status area: "You've been in Architect for 35 min on implementation. This workflow stage typically runs faster with TEA driving the TDD cycle. Consider switching personas." Amir dismisses it — he knows why he's in Architect for this particular task. He marks it "not helpful." The behavioral linter learns that this tip has a low action rate for Amir and reduces its frequency for him.

**Exercises:** Idea L — persona switch suggestion, CLI delivery, dismiss/feedback loop, per-user adaptation.

#### Story US-L3: RaceCoach — Team-Level Coaching Patterns

Dana opens the team BikeShop's ShowRoom and checks the RaceCoach summary panel. It shows aggregate coaching stats for the sprint: "12 compaction warnings delivered, 9 acted on. 6 persona switch suggestions, 2 acted on. 3 workflow ordering tips, 3 acted on." She notices that the persona switch tips have a low action rate — maybe the rules don't match how her team actually works. She edits the behavioral linter config to relax the persona duration threshold from 30 minutes to 60 minutes. She also adds a new team-specific rule: "If story has AC defined AND coding has started AND AC panel hasn't been opened, suggest reviewing AC before continuing."

**Exercises:** Idea L — ShowRoom coaching summary, team-level analytics on tip effectiveness, ShopOwner editing behavioral linter rules, custom rule authoring.

#### Story US-M1: TeamGear — Shared Skills Across Sessions

Keith and Amir are both working on the same project but in separate Claude Code sessions. They configure both sessions to connect to a shared TeamGear set: `project-alpha-gear`. Keith creates a new skill — `/validate-schema` — that runs a schema validation workflow he's been using. He saves it to TeamGear. Within seconds, Amir's session picks up the new skill. Amir runs `/validate-schema` in his own session, with his own agent, against his own working tree. They're sharing the tool, not the session.

**Exercises:** Idea M — shared skill propagation between sessions, git-backed or fast-sync, independent execution in each session.

#### Story US-M2: TeamGear — Shared Knowledge Base

Dana sets up a TeamGear set for the team: `team-portland-gear`. She adds the team's architecture decision records, API runbook, and onboarding guide. She also indexes a set of design docs as a RAG source. When any team member starts a Claude Code session connected to this gear set, their agent can reference these documents — "check the ADR for the auth decision" pulls from the shared knowledge base, not just the local repo. When the API runbook is updated, every connected session sees the latest version on next access.

**Exercises:** Idea M — shared knowledge and RAG sources, team-level document set, live updates propagated to connected sessions.

#### Story US-M3: TeamGear — Conflict on a Shared Workflow

Keith and Amir are both connected to `project-alpha-gear`. Keith modifies the `tdd-workflow.yaml` to add a new gate step. At the same time, Amir modifies the same file to change the test runner config. Both save. The git-backed TeamGear detects the conflict — neither change is lost. Both operators see a notification: "Conflict in tdd-workflow.yaml — two concurrent edits." Keith opens the diff, resolves the merge in his session, and pushes. Amir's session picks up the resolved version.

**Exercises:** Idea M — git-backed conflict detection, concurrent edits by different operators, manual conflict resolution, merge propagation.

#### Story US-N1: Tandem — Output Sharing Between Operators

Keith is building the API endpoints for a feature. Amir is building the frontend that will consume them. They start a Tandem session with shared TeamGear (`project-alpha-gear`) and output sharing enabled. When Keith's agent completes an endpoint, the interface contract (types, routes, response shapes) is automatically surfaced in Amir's session as a reference document. Amir's agent can see "Keith's session produced this API contract 3 minutes ago" and code against it. Amir doesn't control Keith's session. Keith doesn't control Amir's. They each work independently, but the output of one informs the other.

**Exercises:** Idea N — output sharing (selective, curated artifacts), TeamGear as base layer, independent operator control, agent awareness of shared output.

#### Story US-N2: Tandem — Manual Flow Control

Keith and Amir are working a coordinated migration. The plan: Keith runs the schema migration, then Amir runs the data backfill, then Keith runs the integration tests. They set up a simple Tandem flow: three steps, manual gates. Keith finishes step 1 and marks the gate as "done." Amir sees the gate clear in his session and starts step 2. When Amir finishes, he marks his gate. Keith picks up step 3. No agent-to-agent communication — just a shared checklist with visibility into each other's completion status via TeamGear.

**Exercises:** Idea N — manual flow control (shared gates), TeamGear for state visibility, no agent bridging required, operators coordinate through structure rather than control.
