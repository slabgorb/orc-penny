# ADR-0024: BikeRack Mode — Decoupled WheelHub Dashboard for CLI-First Development

## Status: Accepted

## Context

Cyclist is Pennyfarthing's visual terminal — an Electron app with dockview-based panel layout, Claude process management via ClaudeService, and real-time data visualization. It works well, but it bundles the conversation UI and the dashboard panels into a single application. CLI-first developers who prefer Claude Code in their own terminal cannot access the dashboard panels (sprint status, git diffs, workflow, audit log, etc.) without also using Cyclist's conversation interface.

### The Opportunity

WheelHub (Cyclist's Express/WebSocket backend) already serves panels over HTTP and WebSocket. The panels are standalone React components exported individually from `panels/index.ts`. The only Cyclist-specific coupling is ClaudeService (which manages the Claude process) and dockview (which arranges panels in a grid). If we gate ClaudeService and bypass dockview, WheelHub becomes a standalone dashboard server that any browser can consume.

### PRD Reference

Full requirements in `sprint/planning/bikerack-prd.md`: 21 functional requirements, 3 non-functional requirements, 4 user journeys. Ideas appendix at `sprint/planning/bikerack-prd-ideas.md` (14 ideas triaged into MVP/Growth/Vision/OOS).

### Existing Architecture Surveyed

- **WheelHub:** Express HTTP server on port 1898, 17 WebSocket channels, 31 API routers, OTLP receiver, file watchers
- **ClaudeService:** The only component requiring gating in BikeRack mode
- **Panels:** Already standalone React components; WebSocket URLs auto-resolve via `window.location.host`
- **Env var pattern:** `CYCLIST=1` for in-process detection (ADR-0023) — BikeRack extends this pattern
- **Portrait system:** PersonaHeader, TandemPortrait, AgentPopup — data layer reusable, UI needs new panel
- **Mode guards:** Bell mode, relay mode, reflector already have skip-guards — `IS_BIKERACK` extends this

### ADRs Reviewed

5 high-impact for BikeRack: ADR-0004 (WheelHub consolidation), ADR-0011 (OTEL), ADR-0015 (panel architecture), ADR-0016 (WebSocket channels), ADR-0017 (portrait system). 23 total reviewed.

## Decision

Introduce **BikeRack mode**: a runtime mode where WheelHub starts without ClaudeService, serves panels individually via `?panel=X` query params, and receives OTEL telemetry from a separately-launched Claude CLI process. A Python launcher (`pf bikerack start`) orchestrates the startup, port discovery, and lifecycle cleanup.

### Architectural Patterns Selected

| Concern | Pattern | Rationale |
|---------|---------|-----------|
| **Mode detection** | Env var `IS_BIKERACK=1` + centralized `isBikeRackMode()` | Follows ADR-0023 `CYCLIST=1` precedent. ~5 call sites is proportional, not scattered. |
| **Process lifecycle** | Shell trap + PID file | `trap EXIT` catches all exit paths. PID file enables `pf bikerack stop` for manual cleanup. Matches existing `.cyclist-pid` pattern. |
| **Panel routing** | URL query param `?panel=X` + index page at `/bikerack` | Reuses existing SPA entry point. No per-panel HTML files. Least-work path. |
| **PortraitPanel** | New standalone component, shared data hooks | Different layout needs than PersonaHeader. Shares `usePersona()` hook and `/ws/persona` channel — reuses data, not UI. |
| **Port isolation** | Default port 2898, separate `.bikerack-port` file | Avoids collision with Cyclist (1898). Both have auto-increment. |
| **ClaudeService gating** | Skip `/ws/claude` setup when `isBikeRackMode()` | Simplest: don't create what you don't need. |

### Rejected Alternatives

- **Separate server binary** — Over-engineered. WheelHub with 5 if-checks is simpler than two server codepaths.
- **Microservice split (standalone OTLP receiver)** — The receiver is ~200 lines embedded in the server. Extracting gains nothing for MVP.
- **Docker/container-based** — Targets CLI developers on macOS. Containers add friction, not value.
- **Plugin architecture** — Designing a plugin system for a binary feature flag is textbook over-engineering.
- **Electron webview for panels** — Contradicts the premise. The user wants their browser, not another Electron window.

### Component Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         BikeRack Launcher                           │
│  (Python: `pf bikerack` / just recipe)                              │
│                                                                      │
│  1. Start WheelHub (background, IS_BIKERACK=1)                      │
│  2. Wait for .bikerack-port                                          │
│  3. Set OTEL env vars from port                                      │
│  4. Exec Claude CLI (foreground)                                     │
│  5. trap EXIT → kill WheelHub PID                                    │
└──────────┬───────────────────────────┬───────────────────────────────┘
           │                           │
           ▼                           ▼
┌─────────────────────┐    ┌─────────────────────────────┐
│    Claude CLI        │    │    WheelHub (BikeRack mode)  │
│  (user's terminal)   │    │  (background, IS_BIKERACK=1) │
│                      │    │                               │
│  OTEL telemetry ─────┼───▶│  /v1/logs, /v1/metrics       │
│  (HTTP POST)         │    │  OTLP receiver (unchanged)    │
│                      │    │                               │
│  File writes ────────┼───▶│  fs.watch() (unchanged)       │
│  (.session/, sprint/)│    │  File watchers                │
│                      │    │                               │
│                      │    │  ClaudeService: SKIPPED       │
│                      │    │  Bell/Relay/Reflector: DORMANT│
└──────────────────────┘    │                               │
                            │  HTTP: Express static + APIs  │
                            │  WS: 16 channels (no /ws/claude)│
                            │                               │
                            │  NEW: /bikerack index page    │
                            │  NEW: ?panel=X routing        │
                            └───────────┬───────────────────┘
                                        │
                            WebSocket + HTTP │
                                        ▼
                            ┌───────────────────────┐
                            │   Browser (user's)     │
                            │                        │
                            │  /bikerack → index     │
                            │  ?panel=sprint → panel │
                            │  ?panel=portrait → NEW │
                            │                        │
                            │  Panels render as full- │
                            │  screen standalone React│
                            │  components (no dockview)│
                            └────────────────────────┘
```

### New Files

| File | Purpose |
|------|---------|
| `src/bikerack.ts` | BikeRack-mode WheelHub entry point (sets `IS_BIKERACK=1`, calls `createTerminalServer()`, listens on 2898) |
| `src/public/components/panels/PortraitPanel.tsx` | Agent identity display with tandem support, subscribes to `/ws/persona` via existing `usePersona()` hook |
| `src/public/components/BikeRackIndex.tsx` | Panel listing page served at `/bikerack` |
| `src/public/components/StandalonePanel.tsx` | Full-screen panel wrapper for `?panel=X` routing, contains `PANEL_REGISTRY` |
| `pennyfarthing_scripts/bikerack.py` | `pf bikerack` launcher CLI (start/stop/status) |

### Modified Files

| File | Change | Scope |
|------|--------|-------|
| `src/server.ts` | Export `isBikeRackMode()`, add `/bikerack` route | ~10 lines |
| `src/websocket.ts` | Skip `/ws/claude` setup when `isBikeRackMode()` | ~3 lines |
| `src/public/App.tsx` | Add `?panel=X` detection before DockviewWorkspace render | ~15 lines |
| `src/public/components/panels/index.ts` | Export PortraitPanel | 1 line |
| `justfile` | Add `bikerack` recipe | ~5 lines |

### Implementation Consistency Rules

These rules prevent AI agents from making conflicting implementation choices:

1. **Mode detection is ALWAYS `isBikeRackMode()`** — never check `process.env.IS_BIKERACK` directly.
2. **Panels receive NO BikeRack-specific props** — same components, different container.
3. **PortraitPanel uses `/ws/persona` and `/api/portrait`** — no new endpoints (CE-1, CE-5).
4. **Port file is `.bikerack-port`** — separate from `.cyclist-port` for coexistence.
5. **Launcher sets exactly 5 OTEL env vars** — no extras, no traces exporter.
6. **Default port is 2898** — Cyclist uses 1898.
7. **No dockview dependency in BikeRack rendering path** — StandalonePanel uses plain div.
8. **Launcher cleanup is `trap EXIT`** — not `trap INT TERM`.
9. **WheelHub BikeRack entry point is `src/bikerack.ts`** — not `main.ts` (Electron entry).
10. **Client-side BikeRack detection is URL-based** — `?panel=X` presence, no `window.IS_BIKERACK`.

### Contract Enforcement

- **CE-1:** PortraitPanel must use existing `usePersona()` hook — no duplicate WebSocket connections.
- **CE-2:** `PANEL_REGISTRY` in StandalonePanel is the single source of truth for `?panel=` routing.
- **CE-3:** Port file write happens AFTER `server.listen()` callback — readiness signal, not optimistic.
- **CE-4:** Launcher uses `exec` (not `spawn`) for Claude CLI — foreground process IS Claude, not a wrapper.
- **CE-5:** Zero new WebSocket channels — BikeRack reuses all 16 existing channels.

### Key Interfaces

**Launcher CLI:**
```
pf bikerack [start]     # Start BikeRack (default)
pf bikerack stop        # Kill WheelHub via PID file
pf bikerack status      # Show running state
just bikerack           # Alias
```

**Browser URLs:**
| URL | Renders |
|-----|---------|
| `http://localhost:{port}/bikerack` | Panel index page |
| `http://localhost:{port}/?panel=sprint` | SprintPanel full-screen |
| `http://localhost:{port}/?panel=portrait` | PortraitPanel (new) |
| `http://localhost:{port}/` | Normal Cyclist SPA (if no `?panel=`) |

**13 panels available:** sprint, git, diffs, todos, workflow, background, audit, changed, ac, tty, debug, bikelane, portrait.

**Mode gate function:**
```typescript
// src/server.ts
export function isBikeRackMode(): boolean {
  return process.env.IS_BIKERACK === '1';
}
```

**Port file protocol:** `{projectDir}/.bikerack-port` — plain integer written after `server.listen()`, deleted on shutdown.

**PID file protocol:** `{projectDir}/.bikerack-pid` — WheelHub PID written by launcher, deleted in `trap EXIT`.

## Consequences

### Positive

- **CLI developers get dashboard panels** without switching to Cyclist's conversation UI.
- **Zero changes to existing panels** — they already work as standalone React components over WebSocket.
- **Minimal new code** — ~5 new files, ~30 lines of modifications to existing files, 5 if-checks.
- **Coexists with Cyclist** — separate port, separate port file, independent processes.
- **OTEL pipeline reused entirely** — same receiver, same WebSocket fan-out, same panels.
- **Pattern established** for future modes (BikeShop multi-user dashboard in Growth/Vision scope).

### Negative

- **No MessagePanel** — deliberate exclusion, but means BikeRack users can't see formatted conversation. CLI owns conversation; this is a feature, not a gap.
- **Single session for MVP** — multiple Claude sessions sharing one WheelHub requires port routing and session scoping. Deferred to Growth phase.
- **Orphan process risk on SIGKILL** — mitigated by PID file and `pf bikerack stop`, but not eliminated. Accepted for a local dev tool.
- **Mode detection adds conditional paths** — 5 if-checks is manageable. If it grows beyond ~10, revisit with startup-time composition (Pattern 1B).

### Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Orphan WheelHub on SIGKILL | Med | Med | PID file + `pf bikerack stop` + stale check on next start |
| Port file race condition | High | Low | Polling (100ms/5s timeout) + write in `listen()` callback |
| OTEL data loss during startup | Med | Low | Launcher waits for port file before exec |
| New feature misses `isBikeRackMode()` check | Med | Med | Review practice + integration test |

## Related

- **PRD:** `sprint/planning/bikerack-prd.md`
- **Ideas:** `sprint/planning/bikerack-prd-ideas.md`
- **ADR-0004:** WheelHub consolidation (foundation architecture)
- **ADR-0023:** Cyclist env var detection (pattern precedent for `IS_BIKERACK`)
- **Architecture session:** `.session/architecture-workflow-session.md`
