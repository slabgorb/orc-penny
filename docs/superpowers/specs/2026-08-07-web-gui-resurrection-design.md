# Web GUI Resurrection — Design

**Date:** 2026-08-07
**Status:** Approved (brainstorm)
**Supersedes (in part):** ADR-0039's "no browser GUI" consequence — a superseding ADR is part of this epic's scope.

## Summary

A greenfield browser dashboard for Pennyfarthing, built as a pure client of the existing Frame API (FastAPI). Read-only observability (sprint board, workflow/agent activity, git status) plus a minimal control tier (settings/theme toggles, click-to-copy story IDs). Localhost only, used side by side with the Claude Code terminal on the same machine.

This is **not** a Cyclist resurrection. ADR-0039 removed the React GUI because it carried business logic that drifted from Python, ran a second CI gate, and required Node at build/runtime. Each disease is specifically immunized here (see Boundary Rule, CI, Serving).

## Scope

**In:**
- Three panels: Sprint Board, Workflow Activity, Git Status
- Header strip: theme selector, bell/relay mode toggles (existing settings endpoints)
- Click-to-copy story IDs (clipboard affordance for pasting `PROJ-XXX` into the terminal)
- Live updates via the existing Frame WebSocket push
- Static build served by Frame via FastAPI `StaticFiles`; assets shipped in the wheel
- ADR superseding ADR-0039's "no browser GUI" consequence; CLAUDE.md and repos.yaml updates
- Isolated frontend CI job

**Out (explicitly):**
- Terminal wrapper, Electron, dockable panels (full Cyclist)
- Auth, remote access, responsive/mobile layout (localhost, desktop only)
- Gate/handoff/story mutation endpoints (dashboard observes; the terminal commands)
- Telemetry/analysis panels (later stories — routes already exist)
- E2E/Playwright suite

## Architecture

**Stack:** React + TypeScript + Vite, Tailwind + shadcn components. New top-level `pennyfarthing/web/` in the framework repo (deliberately not `packages/`).

```
pennyfarthing/web/
├── package.json          # React, Vite, TypeScript, Tailwind, shadcn
├── vite.config.ts        # dev proxy → Frame; build → dist/
├── src/
│   ├── api/              # typed fetch wrappers + WebSocket client (thin, no logic)
│   ├── panels/           # SprintBoard, WorkflowActivity, GitStatus
│   ├── components/       # shared UI primitives (shadcn)
│   └── App.tsx           # panel grid layout
└── dist/                 # build output (gitignored; shipped in wheel)
```

**Serving:** Frame mounts `dist/` via `StaticFiles` at `/`. API routes keep `/api/*` precedence; WebSocket path unchanged. If `dist/` is absent, Frame behaves exactly as today — the web layer is strictly additive. Users open `http://localhost:<port>`. The wheel includes `dist/`, so installed users need no Node.

**Dev loop:** `vite dev` proxies `/api` and the WS to a running Frame — HMR without touching Python. Node is a dev-time dependency only.

**Boundary rule (ADR-0039 immunization):** the frontend renders Frame responses verbatim. No client-side derivation of workflow state, no reimplemented YAML parsing, no theme logic. If a panel needs a computed value, the computation becomes a Frame route. This rule is recorded in the superseding ADR and the framework CLAUDE.md.

**CI:** one isolated job (lint + typecheck + vitest + build) gating only changes under `web/`. pytest remains the sole gate for Python. A red frontend job never blocks a framework merge.

## Panels & Data Flow

Fixed desktop CSS-grid layout — no dockable-workspace machinery.

1. **Sprint Board** — stories grouped by status (backlog / in progress / in review / done), epic grouping, sprint points progress, current story prominent, click-to-copy IDs. Source: existing `/api/story` routes.
2. **Workflow Activity** — active story's workflow name, phase sequence with current phase highlighted, phase owner with persona name and portrait. Live phase/handoff changes via WS. Source: `/api/story`, `/api/persona`, `/api/mode`, WS.
3. **Git Status** — per repo: branch, dirty/clean, ahead/behind, open PRs. Source: existing `/api/git/all`, `/api/repos`.

**Data flow:** on load each panel fetches its REST snapshot; thereafter a single shared WS connection dispatches typed push events and panels refetch or patch their slice. Reconnect loop with re-snapshot on reconnect (missed events can't leave stale state). Thin fetch layer using React Query — no Redux, no additional client cache layer.

**Gap check:** an early plan task inventories `ws_push` channels against panel needs; any missing channel is added as a small Python broadcast change, never client-side polling.

## Error Handling

Posture: *degrade visibly, never guess*.

- **Frame unreachable / WS dropped:** banner ("Frame disconnected — retrying…"), exponential backoff; panels keep last snapshot, dimmed with staleness timestamp; full re-snapshot on reconnect.
- **Route error:** affected panel shows error state (message + retry); other panels unaffected. Client renders the `error` field of result-shaped responses.
- **Settings/clipboard write fails:** toast with error text. No optimistic UI — toggles reflect server-confirmed state only.

## Testing

- **Vitest + Testing Library:** each panel rendered against fixture JSON captured from real Frame responses (fixtures are the API contract). States: loaded, empty, error, stale/disconnected.
- **WS client unit tests:** reconnect/backoff and re-snapshot behavior against a mock socket.
- **pytest:** the only new Python — `StaticFiles` mount (present/absent `dist/`, `/api` precedence) and any new WS broadcast channels.
- **No E2E suite in v1.** Manual smoke recipe in README/justfile.

## Paperwork

- ADR in orchestrator `docs/adr/` superseding ADR-0039's "no browser GUI" consequence: rationale for the reversal, the boundary rule, CI isolation, wheel packaging.
- Framework CLAUDE.md: `web/` conventions and the boundary rule.
- `repos.yaml`: `web/**` ownership and UI-layer entry for the pennyfarthing repo.
- Wheel packaging change to include `dist/`.

## Placement

Backlog — does not displace Sprint 2632 ("Frontier model changes") committed work.
