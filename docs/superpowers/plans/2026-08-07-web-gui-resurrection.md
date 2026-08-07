# Web GUI Resurrection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A browser dashboard (Sprint Board, Workflow Activity, Git Status + settings header) served by the existing Frame FastAPI server, as a pure view-layer client of the Frame API.

**Architecture:** Greenfield `web/` directory in the pennyfarthing repo — React + TypeScript + Vite + Tailwind. Vite builds static assets directly into `pennyfarthing-dist/src/pf/frame/webui/dist/` (gitignored, shipped in the wheel); Frame mounts that directory via FastAPI `StaticFiles` at `/` when present. Panels are WebSocket-only clients of Frame's existing per-channel sockets (`/ws/sprint`, `/ws/story`, `/ws/git`, `/ws/persona`); REST is used only for settings reads/writes and two small new routes.

**Tech Stack:** React 18, TypeScript, Vite, Tailwind CSS v4, Vitest + Testing Library (frontend); FastAPI/pytest (Python side).

**Spec:** `docs/superpowers/specs/2026-08-07-web-gui-resurrection-design.md` (orchestrator repo)

## Spec Deltas (ground-truth corrections)

Discovered while grounding the plan in the actual Frame code; each simplifies or unblocks the spec:

1. **WS-only panels, no REST snapshot layer.** Frame's WS handler sends a full snapshot on connect (`type: "init"`) and full refreshes every 5s (`type: "update"`, `ws_push.py POLL_CHANNELS`). The spec's "REST snapshot then WS patch" flow is unnecessary — reconnect re-snapshot comes free from the server.
2. **React Query dropped.** With WS-only panels, only three REST calls remain (settings GET/PATCH, themes list, workflow GET). Plain `fetch` — a query cache would be dead weight.
3. **shadcn deferred.** v1 panels are plain Tailwind. shadcn's interactive init doesn't belong in an agent-executed plan; add it later if a component warrants it (YAGNI).
4. **Phase sequence needs a new route.** No existing endpoint returns a workflow's phase list. Per the boundary rule (no client-side YAML parsing), Task 5 adds `GET /api/workflow/` reading the workflow YAML server-side.
5. **Portraits need a file route.** `GET /api/persona/` returns `portraitPath` as a *filesystem* path a browser can't load. Task 5 adds `GET /api/persona/portrait` (FileResponse).
6. **Settings PATCH is in-memory only** (`state.py:64-68`). Task 9 adds persistence to `config.local.yaml` for the keys the header mutates, following the existing `patch_layout` pattern.
7. **Open PRs need enrichment.** Git payloads have no PR data. Task 7 adds `openPrs` via `gh pr list` with a 60s cache (the git channel polls every 5s; a network call per poll is unacceptable).

## Global Constraints

- **Boundary rule:** the frontend renders Frame responses verbatim. No client-side derivation of workflow state, no YAML parsing, no theme logic. A needed computation becomes a Frame route.
- **Python is the only language *with logic*** in this repo; `web/` is a pure view layer (framework CLAUDE.md amendment is Task 12).
- Frame default port **2898** (`FRAME_PORT`); when served by Frame the app is same-origin (relative `/api`, `ws://${location.host}/ws/...`).
- Frontend degradation posture: *degrade visibly, never guess* — banner + dimmed stale panels on disconnect; no optimistic UI for settings.
- Python tests: `python3 -m pytest pennyfarthing-dist/src/pf/tests/<file> -v` from the pennyfarthing repo root. Frontend tests: `npm test` (vitest) from `web/`.
- Pennyfarthing repo uses gitflow — feature branch off `develop`. Orchestrator repo (Task 12's ADR) branches off `main`.
- Commit format `<type>(<scope>): <subject>`. Never skip commit signing.
- Result-shaped errors: new Python routes return `{"error": ...}` with an HTTP error status, never raise to the client.

---

### Task 1: Frame serves the static web UI

**Files:**
- Modify: `pennyfarthing/pennyfarthing-dist/src/pf/frame/app.py` (add `_resolve_webui_dir()`, mount in `create_app()`)
- Test: `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_frame_webui_static.py`

**Interfaces:**
- Consumes: existing `create_app()` factory.
- Produces: `_resolve_webui_dir() -> Path | None` (env `FRAME_WEBUI_DIR` override, else packaged `pf/frame/webui/dist`); `GET /` serves `index.html` when the dir exists; all existing routes keep precedence; no dir → Frame behaves exactly as today.

- [ ] **Step 1: Write the failing tests**

```python
"""Static web UI serving — ADR web-gui-resurrection. Frame mounts webui/dist
when present; absent dir leaves the server exactly as before."""
from pathlib import Path

from fastapi.testclient import TestClient


def _make_webui(tmp_path: Path) -> Path:
    (tmp_path / "index.html").write_text(
        "<html><body>pf-webui-sentinel</body></html>", encoding="utf-8"
    )
    return tmp_path


def test_serves_index_when_webui_dir_set(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAME_WEBUI_DIR", str(_make_webui(tmp_path)))
    from pf.frame.app import create_app

    client = TestClient(create_app())
    resp = client.get("/")
    assert resp.status_code == 200
    assert "pf-webui-sentinel" in resp.text


def test_api_routes_take_precedence_over_static(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAME_WEBUI_DIR", str(_make_webui(tmp_path)))
    from pf.frame.app import create_app

    client = TestClient(create_app())
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_missing_webui_dir_is_not_mounted(tmp_path, monkeypatch):
    # Env set but pointing nowhere: resolver returns None, no mount.
    monkeypatch.setenv("FRAME_WEBUI_DIR", str(tmp_path / "nonexistent"))
    from pf.frame.app import create_app

    client = TestClient(create_app())
    assert client.get("/").status_code == 404
    assert client.get("/health").status_code == 200


def test_resolver_env_override_and_default(tmp_path, monkeypatch):
    from pf.frame.app import _resolve_webui_dir

    monkeypatch.setenv("FRAME_WEBUI_DIR", str(_make_webui(tmp_path)))
    assert _resolve_webui_dir() == tmp_path
    monkeypatch.setenv("FRAME_WEBUI_DIR", str(tmp_path / "gone"))
    assert _resolve_webui_dir() is None
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m pytest pennyfarthing-dist/src/pf/tests/test_frame_webui_static.py -v`
Expected: FAIL — `ImportError: cannot import name '_resolve_webui_dir'` / 404 assertions on `/`.

- [ ] **Step 3: Implement**

In `app.py`, module level (near `_resolve_project_dir`):

```python
def _resolve_webui_dir() -> Path | None:
    """Locate the built web UI, if any.

    FRAME_WEBUI_DIR env wins (tests, dev overrides); when set, it must exist —
    no silent fallback. Otherwise use the packaged build at pf/frame/webui/dist
    (populated by `vite build`; absent in a source tree with no web build).
    """
    env = os.environ.get("FRAME_WEBUI_DIR")
    if env:
        path = Path(env)
        return path if path.is_dir() else None
    packaged = Path(__file__).parent / "webui" / "dist"
    return packaged if packaged.is_dir() else None
```

At the **end** of `create_app()`, after the WebSocket channel loop (mount order is what gives `/health`, `/api/*`, `/ws/*`, `/v1/*` precedence — registered routes always win over a `/` mount):

```python
    # --- Static web UI (ADR web-gui-resurrection) ---
    webui_dir = _resolve_webui_dir()
    if webui_dir is not None:
        from fastapi.staticfiles import StaticFiles

        app.mount("/", StaticFiles(directory=str(webui_dir), html=True), name="webui")

    return app
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest pennyfarthing-dist/src/pf/tests/test_frame_webui_static.py pennyfarthing-dist/src/pf/tests/test_frame_routes.py -v`
Expected: PASS (including the existing route suite — proves no regression).

- [ ] **Step 5: Commit**

```bash
git add pennyfarthing-dist/src/pf/frame/app.py pennyfarthing-dist/src/pf/tests/test_frame_webui_static.py
git commit -m "feat(frame): serve static web UI from webui/dist when present"
```

---

### Task 2: Web scaffold — Vite + React + TypeScript + Tailwind + Vitest

**Files:**
- Create: `pennyfarthing/web/` (scaffold: `package.json`, `vite.config.ts`, `tsconfig.json`, `index.html`, `src/main.tsx`, `src/App.tsx`, `src/index.css`, `src/test/setup.ts`, `src/App.test.tsx`, `web/.gitignore`)
- Modify: `pennyfarthing/.gitignore` (add `pennyfarthing-dist/src/pf/frame/webui/dist/`)

**Interfaces:**
- Produces: `npm run dev` (HMR against a running Frame on :2898), `npm run build` (emits to `../pennyfarthing-dist/src/pf/frame/webui/dist`), `npm test` (vitest), `npm run lint`, `npm run typecheck`. `src/App.tsx` renders the app shell later tasks mount panels into.

- [ ] **Step 1: Scaffold**

```bash
cd pennyfarthing
npm create vite@latest web -- --template react-ts
cd web
npm install
npm install tailwindcss @tailwindcss/vite
npm install -D vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom
```

- [ ] **Step 2: Configure Vite (build target, dev proxy, vitest)**

Replace `web/vite.config.ts`:

```ts
/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// Frame default port — see pf/frame/app.py _resolve_port()
const FRAME = 'http://localhost:2898'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    // Frame serves this directory via StaticFiles (Task 1). Gitignored;
    // shipped in the wheel as pf.frame package data (Task 10).
    outDir: '../pennyfarthing-dist/src/pf/frame/webui/dist',
    emptyOutDir: true,
  },
  server: {
    proxy: {
      '/api': FRAME,
      '/health': FRAME,
      '/ws': { target: FRAME.replace('http', 'ws'), ws: true },
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    globals: true,
  },
})
```

Create `web/src/test/setup.ts`:

```ts
import '@testing-library/jest-dom/vitest'
```

Replace `web/src/index.css` with Tailwind v4 entry:

```css
@import 'tailwindcss';
```

In `web/package.json` scripts, set:

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "lint": "eslint .",
    "typecheck": "tsc -b --noEmit",
    "test": "vitest run",
    "preview": "vite preview"
  }
}
```

- [ ] **Step 3: Minimal app shell + failing render test**

Replace `web/src/App.tsx`:

```tsx
export default function App() {
  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100 p-4">
      <header className="flex items-center gap-3 pb-4" data-testid="app-header">
        <h1 className="text-lg font-semibold tracking-wide">Pennyfarthing</h1>
      </header>
      <main
        className="grid grid-cols-1 xl:grid-cols-3 gap-4 items-start"
        data-testid="panel-grid"
      />
    </div>
  )
}
```

Create `web/src/App.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react'
import App from './App'

test('renders the app shell with header and panel grid', () => {
  render(<App />)
  expect(screen.getByText('Pennyfarthing')).toBeInTheDocument()
  expect(screen.getByTestId('panel-grid')).toBeInTheDocument()
})
```

- [ ] **Step 4: Verify the toolchain end to end**

Run: `cd web && npm test && npm run typecheck && npm run build`
Expected: test PASS; typecheck clean; build emits `../pennyfarthing-dist/src/pf/frame/webui/dist/index.html`.

- [ ] **Step 5: Gitignore the build output, verify Frame serves it**

Create `web/.gitignore`:

```
node_modules
dist
```

Append to `pennyfarthing/.gitignore`:

```
pennyfarthing-dist/src/pf/frame/webui/dist/
```

Verify: `git status --short` shows no `webui/dist` entries. Optional manual smoke: `pf frame start` from the orchestrator root, open `http://localhost:2898` — the shell renders.

- [ ] **Step 6: Commit**

```bash
git add web/ .gitignore
git commit -m "feat(web): scaffold Vite+React+Tailwind web UI with vitest toolchain"
```

---

### Task 3: WebSocket client, useChannel hook, connection registry, payload types

**Files:**
- Create: `web/src/api/types.ts`, `web/src/api/ws.ts`, `web/src/api/useChannel.ts`, `web/src/api/connection.ts`
- Test: `web/src/api/ws.test.ts`, `web/src/api/useChannel.test.tsx`

**Interfaces:**
- Consumes: Frame WS endpoints `/ws/{channel}`; every message is a **full snapshot** (`type: "init"` on connect, `"update"` on 5s polls — persona sends a bare payload with no `type`).
- Produces (later tasks rely on these exact names):
  - `useChannel<T>(channel: string): { data: T | null; connected: boolean; lastUpdated: number | null }`
  - `useConnectionStatus(): boolean` (true iff every registered channel is connected)
  - Types: `SprintMessage`, `StoryMessage`, `GitMessage`, `GitRepo`, `PersonaPayload`, `Epic`, `Story`

- [ ] **Step 1: Write payload types (verbatim from Frame's fetchers — `ws_push.py`)**

Create `web/src/api/types.ts`:

```ts
// Shapes mirror pf/frame/ws_push.py fetchers verbatim. Do NOT add derived
// fields here — computation belongs in Frame routes (boundary rule).

export interface Story {
  id: string
  title: string
  points?: number
  status?: string
  jira?: string
}

export interface Epic {
  id: string
  title: string
  jiraKey: string
  status: string
  stories: Story[]
}

export interface SprintSummary {
  number: string | number
  name: string
  goal: string
  done: number
  remaining: number
  inProgress: number
  inReview: number
}

export interface SprintMessage {
  type: 'init' | 'update'
  sprint: SprintSummary
  epics: Epic[]
  completedEpics: Epic[]
}

export interface StoryMessage {
  type?: 'init' | 'update'
  id: string | null
  title: string | null
  phase: string | null
  workflow: string | null
}

export interface GitRepo {
  name: string
  path: string
  branch: string
  clean: boolean
  ahead: number | null
  behind: number | null
  developBehind: number | null
  dirtyFiles: { path?: string; status?: string }[]
  openPrs?: { number: number; title: string; isDraft: boolean }[]
}

export interface GitMessage {
  type: 'init' | 'update'
  repos: GitRepo[]
}

// fetch_persona returns the payload bare — no `type` field.
export interface PersonaPayload {
  character?: string
  role?: string
  roleDescription?: string
  quote?: string
  theme?: string
  trait?: string
  portraitPath?: string | null
}
```

- [ ] **Step 2: Write the failing ChannelSocket tests**

Create `web/src/api/ws.test.ts`:

```ts
import { describe, expect, test, vi, beforeEach, afterEach } from 'vitest'
import { ChannelSocket } from './ws'

class FakeWebSocket {
  static instances: FakeWebSocket[] = []
  onopen: (() => void) | null = null
  onclose: (() => void) | null = null
  onerror: (() => void) | null = null
  onmessage: ((ev: { data: string }) => void) | null = null
  closed = false
  constructor(public url: string) {
    FakeWebSocket.instances.push(this)
  }
  close() {
    this.closed = true
    this.onclose?.()
  }
}

beforeEach(() => {
  FakeWebSocket.instances = []
  vi.useFakeTimers()
})
afterEach(() => vi.useRealTimers())

function make(onMessage = vi.fn(), onStatus = vi.fn()) {
  const sock = new ChannelSocket(
    'sprint',
    onMessage,
    onStatus,
    (url) => new FakeWebSocket(url) as unknown as WebSocket,
  )
  return { sock, onMessage, onStatus }
}

test('connects to /ws/{channel} and reports connected on open', () => {
  const { sock, onStatus } = make()
  sock.connect()
  const ws = FakeWebSocket.instances[0]
  expect(ws.url).toContain('/ws/sprint')
  ws.onopen?.()
  expect(onStatus).toHaveBeenCalledWith(true)
})

test('parses JSON messages into the callback', () => {
  const { sock, onMessage } = make()
  sock.connect()
  FakeWebSocket.instances[0].onmessage?.({ data: '{"type":"init","x":1}' })
  expect(onMessage).toHaveBeenCalledWith({ type: 'init', x: 1 })
})

test('reconnects with backoff after close', () => {
  const { sock, onStatus } = make()
  sock.connect()
  FakeWebSocket.instances[0].onclose?.()
  expect(onStatus).toHaveBeenCalledWith(false)
  expect(FakeWebSocket.instances).toHaveLength(1)
  vi.advanceTimersByTime(1000)
  expect(FakeWebSocket.instances).toHaveLength(2)
  // second failure backs off longer
  FakeWebSocket.instances[1].onclose?.()
  vi.advanceTimersByTime(1000)
  expect(FakeWebSocket.instances).toHaveLength(2)
  vi.advanceTimersByTime(1000)
  expect(FakeWebSocket.instances).toHaveLength(3)
})

test('close() stops reconnecting', () => {
  const { sock } = make()
  sock.connect()
  sock.close()
  vi.advanceTimersByTime(60000)
  expect(FakeWebSocket.instances).toHaveLength(1)
})
```

- [ ] **Step 3: Run to verify failure**

Run: `cd web && npx vitest run src/api/ws.test.ts`
Expected: FAIL — `./ws` module not found.

- [ ] **Step 4: Implement ChannelSocket and the connection registry**

Create `web/src/api/ws.ts`:

```ts
const BACKOFF_MS = [1000, 2000, 4000, 8000, 15000]

export type SocketFactory = (url: string) => WebSocket

export class ChannelSocket<T = unknown> {
  private ws: WebSocket | null = null
  private attempts = 0
  private stopped = false
  private timer: ReturnType<typeof setTimeout> | null = null

  constructor(
    private channel: string,
    private onMessage: (data: T) => void,
    private onStatus: (connected: boolean) => void,
    private makeSocket: SocketFactory = (url) => new WebSocket(url),
  ) {}

  connect(): void {
    if (this.stopped) return
    const proto = location.protocol === 'https:' ? 'wss' : 'ws'
    const ws = this.makeSocket(`${proto}://${location.host}/ws/${this.channel}`)
    this.ws = ws
    ws.onopen = () => {
      this.attempts = 0
      this.onStatus(true)
    }
    ws.onmessage = (ev) => this.onMessage(JSON.parse(ev.data) as T)
    ws.onclose = () => {
      this.onStatus(false)
      this.scheduleReconnect()
    }
    ws.onerror = () => ws.close()
  }

  private scheduleReconnect(): void {
    if (this.stopped) return
    const delay = BACKOFF_MS[Math.min(this.attempts, BACKOFF_MS.length - 1)]
    this.attempts += 1
    this.timer = setTimeout(() => this.connect(), delay)
  }

  close(): void {
    this.stopped = true
    if (this.timer) clearTimeout(this.timer)
    this.ws?.close()
  }
}
```

Create `web/src/api/connection.ts`:

```ts
import { useSyncExternalStore } from 'react'

// Registry of per-channel connection status; the app banner shows when any
// registered channel is down.
const status = new Map<string, boolean>()
const listeners = new Set<() => void>()

export function setChannelStatus(channel: string, connected: boolean): void {
  status.set(channel, connected)
  listeners.forEach((l) => l())
}

export function dropChannel(channel: string): void {
  status.delete(channel)
  listeners.forEach((l) => l())
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

function allConnected(): boolean {
  for (const connected of status.values()) if (!connected) return false
  return true
}

export function useConnectionStatus(): boolean {
  return useSyncExternalStore(subscribe, allConnected)
}
```

- [ ] **Step 5: Write the failing useChannel test, then implement**

Create `web/src/api/useChannel.test.tsx`:

```tsx
import { renderHook, act } from '@testing-library/react'
import { expect, test, vi, beforeEach } from 'vitest'

const sockets: MockSocket[] = []
class MockSocket {
  onMessage!: (d: unknown) => void
  onStatus!: (c: boolean) => void
  connect = vi.fn()
  close = vi.fn()
}
vi.mock('./ws', () => ({
  ChannelSocket: class {
    constructor(
      _ch: string,
      onMessage: (d: unknown) => void,
      onStatus: (c: boolean) => void,
    ) {
      const s = new MockSocket()
      s.onMessage = onMessage
      s.onStatus = onStatus
      sockets.push(s)
      return s
    }
  },
}))

import { useChannel } from './useChannel'

beforeEach(() => (sockets.length = 0))

test('exposes snapshot data, connected flag, and lastUpdated', () => {
  const { result } = renderHook(() => useChannel<{ type: string }>('sprint'))
  expect(result.current.data).toBeNull()
  expect(result.current.connected).toBe(false)

  act(() => sockets[0].onStatus(true))
  expect(result.current.connected).toBe(true)

  act(() => sockets[0].onMessage({ type: 'init' }))
  expect(result.current.data).toEqual({ type: 'init' })
  expect(result.current.lastUpdated).not.toBeNull()
})

test('keeps last snapshot when disconnected (stale, not blank)', () => {
  const { result } = renderHook(() => useChannel<{ type: string }>('git'))
  act(() => {
    sockets[0].onStatus(true)
    sockets[0].onMessage({ type: 'init' })
    sockets[0].onStatus(false)
  })
  expect(result.current.connected).toBe(false)
  expect(result.current.data).toEqual({ type: 'init' })
})

test('closes the socket on unmount', () => {
  const { unmount } = renderHook(() => useChannel('story'))
  unmount()
  expect(sockets[0].close).toHaveBeenCalled()
})
```

Create `web/src/api/useChannel.ts`:

```ts
import { useEffect, useState } from 'react'
import { ChannelSocket } from './ws'
import { dropChannel, setChannelStatus } from './connection'

export interface ChannelState<T> {
  data: T | null
  connected: boolean
  lastUpdated: number | null
}

// Every Frame WS message is a full snapshot (init on connect, update on
// 5s polls) — replace wholesale, never merge. Reconnect re-snapshot is
// server behavior (send_initial_data on connect).
export function useChannel<T>(channel: string): ChannelState<T> {
  const [state, setState] = useState<ChannelState<T>>({
    data: null,
    connected: false,
    lastUpdated: null,
  })

  useEffect(() => {
    const sock = new ChannelSocket<T>(
      channel,
      (data) => setState((s) => ({ ...s, data, lastUpdated: Date.now() })),
      (connected) => {
        setChannelStatus(channel, connected)
        setState((s) => ({ ...s, connected }))
      },
    )
    sock.connect()
    return () => {
      sock.close()
      dropChannel(channel)
    }
  }, [channel])

  return state
}
```

- [ ] **Step 6: Run all frontend tests**

Run: `cd web && npm test`
Expected: PASS (ws, useChannel, App).

- [ ] **Step 7: Commit**

```bash
git add web/src/api/
git commit -m "feat(web): WebSocket channel client with reconnect, useChannel hook, connection registry"
```

---

### Task 4: PanelShell + Sprint Board panel

**Files:**
- Create: `web/src/components/PanelShell.tsx`, `web/src/panels/SprintBoard.tsx`, `web/src/test/fixtures/sprint.ts`
- Modify: `web/src/App.tsx` (mount SprintBoard in the grid)
- Test: `web/src/components/PanelShell.test.tsx`, `web/src/panels/SprintBoard.test.tsx`

**Interfaces:**
- Consumes: `useChannel<SprintMessage>('sprint')` from Task 3.
- Produces: `PanelShell({ title, connected, lastUpdated, children })` — shared chrome all later panels use (title bar, live dot, staleness dimming); `SprintBoard()` component; `CopyChip({ value })` inside SprintBoard (click → `navigator.clipboard.writeText(value)`).

- [ ] **Step 1: Failing PanelShell test**

Create `web/src/components/PanelShell.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react'
import { PanelShell } from './PanelShell'

test('shows title and children when connected', () => {
  render(
    <PanelShell title="Sprint" connected={true} lastUpdated={Date.now()}>
      <div>body</div>
    </PanelShell>,
  )
  expect(screen.getByText('Sprint')).toBeInTheDocument()
  expect(screen.getByText('body')).toBeInTheDocument()
  expect(screen.queryByText(/stale/i)).not.toBeInTheDocument()
})

test('dims and labels stale content when disconnected', () => {
  render(
    <PanelShell title="Sprint" connected={false} lastUpdated={Date.now() - 60_000}>
      <div>body</div>
    </PanelShell>,
  )
  expect(screen.getByText(/stale/i)).toBeInTheDocument()
  expect(screen.getByTestId('panel-body')).toHaveClass('opacity-50')
})

test('shows waiting state when no data has ever arrived', () => {
  render(
    <PanelShell title="Sprint" connected={false} lastUpdated={null}>
      {null}
    </PanelShell>,
  )
  expect(screen.getByText(/waiting for frame/i)).toBeInTheDocument()
})
```

- [ ] **Step 2: Implement PanelShell**

Create `web/src/components/PanelShell.tsx`:

```tsx
import type { ReactNode } from 'react'

interface Props {
  title: string
  connected: boolean
  lastUpdated: number | null
  children: ReactNode
}

export function PanelShell({ title, connected, lastUpdated, children }: Props) {
  return (
    <section className="rounded-lg border border-zinc-800 bg-zinc-900">
      <header className="flex items-center justify-between border-b border-zinc-800 px-3 py-2">
        <h2 className="text-sm font-semibold">{title}</h2>
        <span className="flex items-center gap-2 text-xs text-zinc-400">
          {!connected && lastUpdated !== null && (
            <span>stale · {new Date(lastUpdated).toLocaleTimeString()}</span>
          )}
          <span
            aria-label={connected ? 'connected' : 'disconnected'}
            className={`h-2 w-2 rounded-full ${connected ? 'bg-emerald-400' : 'bg-red-500'}`}
          />
        </span>
      </header>
      <div
        data-testid="panel-body"
        className={`p-3 ${!connected && lastUpdated !== null ? 'opacity-50' : ''}`}
      >
        {lastUpdated === null ? (
          <p className="text-sm text-zinc-500">Waiting for Frame…</p>
        ) : (
          children
        )}
      </div>
    </section>
  )
}
```

Run: `cd web && npx vitest run src/components/PanelShell.test.tsx` — Expected: PASS.

- [ ] **Step 3: Sprint fixture + failing SprintBoard test**

Create `web/src/test/fixtures/sprint.ts` (shape verbatim from `ws_push.fetch_sprint`):

```ts
import type { SprintMessage } from '../../api/types'

export const sprintFixture: SprintMessage = {
  type: 'init',
  sprint: {
    number: 2632,
    name: 'Frontier Model Changes 2632',
    goal: 'Adopt frontier model changes',
    done: 8,
    remaining: 40,
    inProgress: 3,
    inReview: 2,
  },
  epics: [
    {
      id: '163',
      title: 'Web GUI Resurrection',
      jiraKey: 'PROJ-16300',
      status: 'in_progress',
      stories: [
        { id: '163-1', title: 'Frame static serving', points: 2, status: 'in_progress', jira: 'PROJ-16301' },
        { id: '163-2', title: 'Web scaffold', points: 2, status: 'backlog', jira: 'PROJ-16302' },
      ],
    },
  ],
  completedEpics: [],
}
```

Create `web/src/panels/SprintBoard.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'
import type { SprintMessage } from '../api/types'
import { sprintFixture } from '../test/fixtures/sprint'

const channelState = {
  data: sprintFixture as SprintMessage | null,
  connected: true,
  lastUpdated: Date.now() as number | null,
}
vi.mock('../api/useChannel', () => ({ useChannel: () => channelState }))

import { SprintBoard } from './SprintBoard'

test('renders sprint header with points summary', () => {
  render(<SprintBoard />)
  expect(screen.getByText(/Frontier Model Changes 2632/)).toBeInTheDocument()
  expect(screen.getByText(/8/)).toBeInTheDocument() // done points
})

test('renders epics with their stories and status', () => {
  render(<SprintBoard />)
  expect(screen.getByText('Web GUI Resurrection')).toBeInTheDocument()
  expect(screen.getByText('Frame static serving')).toBeInTheDocument()
  expect(screen.getAllByText('in_progress').length).toBeGreaterThan(0)
})

test('click on a story id copies it to the clipboard', async () => {
  const writeText = vi.fn().mockResolvedValue(undefined)
  Object.assign(navigator, { clipboard: { writeText } })
  render(<SprintBoard />)
  await userEvent.click(screen.getByRole('button', { name: '163-1' }))
  expect(writeText).toHaveBeenCalledWith('163-1')
})

test('empty sprint renders a friendly empty state', () => {
  channelState.data = { ...sprintFixture, epics: [], completedEpics: [] }
  render(<SprintBoard />)
  expect(screen.getByText(/no stories/i)).toBeInTheDocument()
  channelState.data = sprintFixture
})
```

- [ ] **Step 4: Implement SprintBoard**

Create `web/src/panels/SprintBoard.tsx`:

```tsx
import { useChannel } from '../api/useChannel'
import type { Epic, SprintMessage, Story } from '../api/types'
import { PanelShell } from '../components/PanelShell'

const STATUS_STYLES: Record<string, string> = {
  done: 'bg-emerald-900 text-emerald-300',
  completed: 'bg-emerald-900 text-emerald-300',
  in_progress: 'bg-amber-900 text-amber-300',
  in_review: 'bg-sky-900 text-sky-300',
  backlog: 'bg-zinc-800 text-zinc-400',
}

function CopyChip({ value }: { value: string }) {
  return (
    <button
      type="button"
      onClick={() => navigator.clipboard.writeText(value)}
      title={`Copy ${value}`}
      className="rounded bg-zinc-800 px-1.5 py-0.5 font-mono text-xs text-zinc-300 hover:bg-zinc-700 active:bg-zinc-600"
    >
      {value}
    </button>
  )
}

function StoryRow({ story }: { story: Story }) {
  const status = story.status ?? 'backlog'
  return (
    <li className="flex items-center gap-2 py-1">
      <CopyChip value={story.id} />
      {story.jira && <CopyChip value={story.jira} />}
      <span className="flex-1 truncate text-sm">{story.title}</span>
      {story.points != null && (
        <span className="text-xs text-zinc-500">{story.points}pt</span>
      )}
      <span
        className={`rounded px-1.5 py-0.5 text-xs ${STATUS_STYLES[status] ?? STATUS_STYLES.backlog}`}
      >
        {status}
      </span>
    </li>
  )
}

function EpicBlock({ epic }: { epic: Epic }) {
  return (
    <div className="pt-2">
      <h3 className="flex items-center gap-2 text-sm font-medium text-zinc-300">
        {epic.title}
        {epic.jiraKey && <CopyChip value={epic.jiraKey} />}
      </h3>
      <ul className="divide-y divide-zinc-800/60">
        {epic.stories.map((s) => (
          <StoryRow key={s.id} story={s} />
        ))}
      </ul>
    </div>
  )
}

export function SprintBoard() {
  const { data, connected, lastUpdated } = useChannel<SprintMessage>('sprint')
  const epics = data?.epics ?? []
  return (
    <PanelShell title="Sprint" connected={connected} lastUpdated={lastUpdated}>
      {data && (
        <div>
          <p className="text-sm text-zinc-300">
            {data.sprint.name}
            <span className="ml-2 text-xs text-zinc-500">
              done {data.sprint.done} · in&nbsp;progress {data.sprint.inProgress} ·
              review {data.sprint.inReview} · remaining {data.sprint.remaining}
            </span>
          </p>
          {epics.length === 0 ? (
            <p className="pt-2 text-sm text-zinc-500">No stories in this sprint.</p>
          ) : (
            epics.map((e) => <EpicBlock key={e.id} epic={e} />)
          )}
        </div>
      )}
    </PanelShell>
  )
}
```

In `web/src/App.tsx`, mount it inside the grid `<main>`:

```tsx
import { SprintBoard } from './panels/SprintBoard'
// inside <main ...>:
<SprintBoard />
```

- [ ] **Step 5: Run tests**

Run: `cd web && npm test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add web/src/
git commit -m "feat(web): PanelShell chrome and Sprint Board panel with copyable story ids"
```

---

### Task 5: Frame routes — persona portrait file + workflow phases

**Files:**
- Modify: `pennyfarthing/pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` (portrait route on the existing `persona_router`; new `workflow_router`; register in `all_data_proxy_routers`)
- Test: `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_frame_web_routes.py`

**Interfaces:**
- Consumes: `build_persona_payload(project_dir)` from `pf.frame.ws_push` (story 162-49); `_get_story_info(project_dir)`; `_read_yaml_file` from `pf.frame.ws_push`.
- Produces:
  - `GET /api/persona/portrait` → image `FileResponse`, or 404 `{"error": "no portrait"}`.
  - `GET /api/workflow/` → `{"workflow": str|null, "phase": str|null, "phases": [{"name": str, "agent": str}]}` — phase list read server-side from `.pennyfarthing/workflows/{name}.yaml` (boundary rule: the browser never parses YAML).

- [ ] **Step 1: Write the failing tests**

Create `pennyfarthing-dist/src/pf/tests/test_frame_web_routes.py`:

```python
"""Web-GUI support routes: persona portrait file, workflow phases."""
from pathlib import Path

from fastapi.testclient import TestClient


def _client(monkeypatch, project_dir: Path) -> TestClient:
    monkeypatch.setenv("PF_PROJECT_DIR", str(project_dir))
    monkeypatch.delenv("FRAME_WEBUI_DIR", raising=False)
    from pf.frame.app import create_app

    return TestClient(create_app())


def test_portrait_returns_file_when_persona_has_one(tmp_path, monkeypatch):
    png = tmp_path / "carrot.png"
    png.write_bytes(b"\x89PNG\r\n\x1a\nfake")
    monkeypatch.setattr(
        "pf.frame.ws_push.build_persona_payload",
        lambda project_dir, full=False: {"character": "Carrot", "portraitPath": str(png)},
    )
    resp = _client(monkeypatch, tmp_path).get("/api/persona/portrait")
    assert resp.status_code == 200
    assert resp.content.startswith(b"\x89PNG")


def test_portrait_404_when_no_persona_or_missing_file(tmp_path, monkeypatch):
    monkeypatch.setattr(
        "pf.frame.ws_push.build_persona_payload",
        lambda project_dir, full=False: {},
    )
    resp = _client(monkeypatch, tmp_path).get("/api/persona/portrait")
    assert resp.status_code == 404
    assert resp.json() == {"error": "no portrait"}


def _write_session_and_workflow(project_dir: Path) -> None:
    session = project_dir / ".session"
    session.mkdir(parents=True)
    (session / "163-1-session.md").write_text(
        "# Story 163-1: Frame static serving\n"
        "**Story ID:** 163-1\n**Phase:** red\n**Workflow:** tdd\n",
        encoding="utf-8",
    )
    wf_dir = project_dir / ".pennyfarthing" / "workflows"
    wf_dir.mkdir(parents=True)
    (wf_dir / "tdd.yaml").write_text(
        "name: tdd\nphases:\n"
        "  - name: setup\n    agent: sm\n"
        "  - name: red\n    agent: tea\n"
        "  - name: green\n    agent: dev\n",
        encoding="utf-8",
    )


def test_workflow_route_returns_phases_from_yaml(tmp_path, monkeypatch):
    _write_session_and_workflow(tmp_path)
    resp = _client(monkeypatch, tmp_path).get("/api/workflow/")
    assert resp.status_code == 200
    body = resp.json()
    assert body["workflow"] == "tdd"
    assert body["phase"] == "red"
    assert {"name": "red", "agent": "tea"} in body["phases"]


def test_workflow_route_degrades_without_session(tmp_path, monkeypatch):
    resp = _client(monkeypatch, tmp_path).get("/api/workflow/")
    assert resp.status_code == 200
    assert resp.json() == {"workflow": None, "phase": None, "phases": []}
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 -m pytest pennyfarthing-dist/src/pf/tests/test_frame_web_routes.py -v`
Expected: FAIL — 404 on `/api/workflow/`, portrait route missing.

- [ ] **Step 3: Implement**

In `routes/data_proxy.py`, add to the persona router section:

```python
@persona_router.get("/portrait")
async def get_persona_portrait():
    """Serve the active persona's portrait as a file (web GUI).

    /api/persona returns portraitPath as a *filesystem* path; a browser
    cannot load that, so this route streams the file itself.
    """
    from fastapi.responses import FileResponse

    import pf.frame.ws_push as ws_push

    project_dir = _get_project_dir()
    payload = ws_push.build_persona_payload(project_dir)
    path = payload.get("portraitPath")
    if not path or not Path(path).is_file():
        return JSONResponse({"error": "no portrait"}, status_code=404)
    return FileResponse(path)
```

Add a workflow router (near the story router, which it composes):

```python
# ---------------------------------------------------------------------------
# Workflow router — phase list for the web GUI (boundary rule: the browser
# never parses workflow YAML; this route does).
# ---------------------------------------------------------------------------

workflow_router = APIRouter(prefix="/api/workflow", tags=["workflow"])


@workflow_router.get("/")
async def get_workflow() -> JSONResponse:
    from pf.frame.ws_push import _read_yaml_file

    project_dir = _get_project_dir()
    story = _get_story_info(project_dir)
    name = story.get("workflow")
    phases: list[dict[str, str]] = []
    if name:
        wf_path = Path(project_dir, ".pennyfarthing", "workflows", f"{name}.yaml")
        data = _read_yaml_file(wf_path)
        if isinstance(data, dict):
            for ph in data.get("phases") or []:
                if isinstance(ph, dict) and ph.get("name"):
                    phases.append(
                        {"name": str(ph["name"]), "agent": str(ph.get("agent", ""))}
                    )
    return JSONResponse(
        {"workflow": name, "phase": story.get("phase"), "phases": phases}
    )
```

Register `workflow_router` in the `all_data_proxy_routers` list at the bottom of the file.

Note the portrait handler imports `ws_push` as a module and calls `ws_push.build_persona_payload(...)` — that is what lets the test's `monkeypatch.setattr("pf.frame.ws_push.build_persona_payload", ...)` take effect (a `from ... import` binding would bypass the patch).

- [ ] **Step 4: Run tests**

Run: `python3 -m pytest pennyfarthing-dist/src/pf/tests/test_frame_web_routes.py pennyfarthing-dist/src/pf/tests/test_frame_routes.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pennyfarthing-dist/src/pf/frame/routes/data_proxy.py pennyfarthing-dist/src/pf/tests/test_frame_web_routes.py
git commit -m "feat(frame): persona portrait file route and workflow phases route for web GUI"
```

---

### Task 6: Workflow Activity panel

**Files:**
- Create: `web/src/panels/WorkflowActivity.tsx`, `web/src/api/rest.ts`, `web/src/test/fixtures/workflow.ts`
- Modify: `web/src/App.tsx` (mount panel)
- Test: `web/src/panels/WorkflowActivity.test.tsx`, `web/src/api/rest.test.ts`

**Interfaces:**
- Consumes: `useChannel<StoryMessage>('story')`, `useChannel<PersonaPayload>('persona')` (Task 3); `GET /api/workflow/` and `GET /api/persona/portrait` (Task 5).
- Produces: `WorkflowActivity()` component; `getJSON<T>(path: string): Promise<T>` in `rest.ts` (throws `Error` with status text on non-2xx — later tasks reuse it).

- [ ] **Step 1: REST helper with failing test**

Create `web/src/api/rest.test.ts`:

```ts
import { expect, test, vi, afterEach } from 'vitest'
import { getJSON } from './rest'

afterEach(() => vi.restoreAllMocks())

test('getJSON returns parsed body on 200', async () => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(
    new Response(JSON.stringify({ ok: 1 }), { status: 200 }),
  ))
  await expect(getJSON('/api/workflow/')).resolves.toEqual({ ok: 1 })
})

test('getJSON throws with status on failure', async () => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('', { status: 500 })))
  await expect(getJSON('/api/workflow/')).rejects.toThrow('500')
})
```

Create `web/src/api/rest.ts`:

```ts
export async function getJSON<T>(path: string): Promise<T> {
  const resp = await fetch(path)
  if (!resp.ok) throw new Error(`GET ${path} failed: ${resp.status}`)
  return (await resp.json()) as T
}

export async function patchJSON<T>(path: string, body: unknown): Promise<T> {
  const resp = await fetch(path, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!resp.ok) throw new Error(`PATCH ${path} failed: ${resp.status}`)
  return (await resp.json()) as T
}
```

Run: `cd web && npx vitest run src/api/rest.test.ts` — Expected: PASS.

- [ ] **Step 2: Fixture + failing panel test**

Create `web/src/test/fixtures/workflow.ts`:

```ts
import type { PersonaPayload, StoryMessage } from '../../api/types'

export const storyFixture: StoryMessage = {
  type: 'init',
  id: '163-1',
  title: 'Story 163-1: Frame static serving',
  phase: 'red',
  workflow: 'tdd',
}

export const personaFixture: PersonaPayload = {
  character: 'Igor',
  role: 'tea',
  roleDescription: 'Test Engineer',
  quote: 'We athk not why, marthter.',
  theme: 'discworld',
}

export interface WorkflowInfo {
  workflow: string | null
  phase: string | null
  phases: { name: string; agent: string }[]
}

export const workflowFixture: WorkflowInfo = {
  workflow: 'tdd',
  phase: 'red',
  phases: [
    { name: 'setup', agent: 'sm' },
    { name: 'red', agent: 'tea' },
    { name: 'green', agent: 'dev' },
    { name: 'review', agent: 'reviewer' },
    { name: 'finish', agent: 'sm' },
  ],
}
```

Create `web/src/panels/WorkflowActivity.test.tsx`:

```tsx
import { render, screen, waitFor } from '@testing-library/react'
import { expect, test, vi } from 'vitest'
import type { PersonaPayload, StoryMessage } from '../api/types'
import { personaFixture, storyFixture, workflowFixture } from '../test/fixtures/workflow'

const channels: Record<string, { data: unknown; connected: boolean; lastUpdated: number | null }> = {
  story: { data: storyFixture as StoryMessage, connected: true, lastUpdated: Date.now() },
  persona: { data: personaFixture as PersonaPayload, connected: true, lastUpdated: Date.now() },
}
vi.mock('../api/useChannel', () => ({ useChannel: (ch: string) => channels[ch] }))
vi.mock('../api/rest', () => ({ getJSON: vi.fn().mockResolvedValue(workflowFixture) }))

import { WorkflowActivity } from './WorkflowActivity'

test('shows active story, workflow, and persona', async () => {
  render(<WorkflowActivity />)
  expect(screen.getByText(/163-1/)).toBeInTheDocument()
  expect(screen.getByText(/Igor/)).toBeInTheDocument()
  await waitFor(() => expect(screen.getByText('green')).toBeInTheDocument())
})

test('highlights the current phase in the sequence', async () => {
  render(<WorkflowActivity />)
  await waitFor(() => {
    expect(screen.getByTestId('phase-red')).toHaveAttribute('data-current', 'true')
    expect(screen.getByTestId('phase-green')).toHaveAttribute('data-current', 'false')
  })
})

test('renders idle state when no story is active', () => {
  channels.story = {
    data: { type: 'init', id: null, title: null, phase: null, workflow: null },
    connected: true,
    lastUpdated: Date.now(),
  }
  render(<WorkflowActivity />)
  expect(screen.getByText(/no active story/i)).toBeInTheDocument()
  channels.story = { data: storyFixture, connected: true, lastUpdated: Date.now() }
})
```

- [ ] **Step 3: Implement WorkflowActivity**

Create `web/src/panels/WorkflowActivity.tsx`:

```tsx
import { useEffect, useState } from 'react'
import { getJSON } from '../api/rest'
import { useChannel } from '../api/useChannel'
import type { PersonaPayload, StoryMessage } from '../api/types'
import { PanelShell } from '../components/PanelShell'

interface WorkflowInfo {
  workflow: string | null
  phase: string | null
  phases: { name: string; agent: string }[]
}

export function WorkflowActivity() {
  const story = useChannel<StoryMessage>('story')
  const persona = useChannel<PersonaPayload>('persona')
  const [workflow, setWorkflow] = useState<WorkflowInfo | null>(null)
  const [workflowError, setWorkflowError] = useState<string | null>(null)

  const workflowName = story.data?.workflow ?? null
  useEffect(() => {
    if (!workflowName) {
      setWorkflow(null)
      return
    }
    let cancelled = false
    getJSON<WorkflowInfo>('/api/workflow/')
      .then((w) => !cancelled && (setWorkflow(w), setWorkflowError(null)))
      .catch((e: Error) => !cancelled && setWorkflowError(e.message))
    return () => {
      cancelled = true
    }
    // Refetch whenever the active workflow or phase changes.
  }, [workflowName, story.data?.phase])

  const connected = story.connected && persona.connected
  const lastUpdated = story.lastUpdated

  return (
    <PanelShell title="Workflow" connected={connected} lastUpdated={lastUpdated}>
      {story.data?.id == null ? (
        <p className="text-sm text-zinc-500">No active story.</p>
      ) : (
        <div className="space-y-3">
          <div>
            <p className="font-mono text-sm text-zinc-300">{story.data.id}</p>
            <p className="text-sm">{story.data.title}</p>
            <p className="text-xs text-zinc-500">workflow: {story.data.workflow}</p>
          </div>
          {workflowError && (
            <p className="text-xs text-red-400">workflow phases unavailable: {workflowError}</p>
          )}
          {workflow && (
            <ol className="flex flex-wrap gap-1">
              {workflow.phases.map((ph) => {
                const current = ph.name === story.data?.phase
                return (
                  <li
                    key={ph.name}
                    data-testid={`phase-${ph.name}`}
                    data-current={current}
                    className={`rounded px-2 py-1 text-xs ${
                      current
                        ? 'bg-amber-800 font-semibold text-amber-100'
                        : 'bg-zinc-800 text-zinc-400'
                    }`}
                  >
                    {ph.name} <span className="opacity-60">· {ph.agent}</span>
                  </li>
                )
              })}
            </ol>
          )}
          {persona.data?.character && (
            <div className="flex items-center gap-3 border-t border-zinc-800 pt-3">
              <img
                src="/api/persona/portrait"
                alt=""
                className="h-10 w-10 rounded-full object-cover"
                onError={(e) => ((e.target as HTMLImageElement).style.display = 'none')}
              />
              <div>
                <p className="text-sm font-medium">{persona.data.character}</p>
                <p className="text-xs text-zinc-500">
                  {persona.data.role} — {persona.data.roleDescription}
                </p>
              </div>
            </div>
          )}
        </div>
      )}
    </PanelShell>
  )
}
```

Mount `<WorkflowActivity />` in `App.tsx`'s grid next to `<SprintBoard />`.

- [ ] **Step 4: Run tests**

Run: `cd web && npm test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web/src/
git commit -m "feat(web): Workflow Activity panel with phase sequence and persona"
```

---

### Task 7: Open PRs in the git payload (Frame, Python)

**Files:**
- Modify: `pennyfarthing/pennyfarthing-dist/src/pf/frame/ws_push.py` (`_get_open_prs()` with TTL cache; enrich `fetch_git`)
- Test: `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_ws_push_open_prs.py`

**Interfaces:**
- Consumes: `gh pr list --json number,title,isDraft --limit 20` (subprocess, cwd=repo).
- Produces: each repo dict in the `git` channel payload gains `"openPrs": [{"number": int, "title": str, "isDraft": bool}]` (empty list when `gh` is missing, errors, or times out). `_get_open_prs(repo_path: str) -> list[dict]`, cached 60s per repo path (`_OPEN_PR_TTL_S = 60.0`) — the git channel polls every 5s and a network call per poll is unacceptable.

- [ ] **Step 1: Write the failing tests**

Create `pennyfarthing-dist/src/pf/tests/test_ws_push_open_prs.py`:

```python
"""Open-PR enrichment for the git channel — gh-backed, TTL-cached."""
import json
import subprocess

import pf.frame.ws_push as ws_push


def _fake_run(payload):
    def run(cmd, **kwargs):
        class R:
            returncode = 0
            stdout = json.dumps(payload)
            stderr = ""
        return R()
    return run


def setup_function(_fn):
    # Each test starts with a cold cache.
    ws_push._open_pr_cache.clear()


def test_returns_parsed_prs(monkeypatch, tmp_path):
    monkeypatch.setattr(ws_push.shutil, "which", lambda name: "/usr/bin/gh")
    monkeypatch.setattr(
        ws_push.subprocess, "run",
        _fake_run([{"number": 7, "title": "feat: x", "isDraft": False}]),
    )
    prs = ws_push._get_open_prs(str(tmp_path))
    assert prs == [{"number": 7, "title": "feat: x", "isDraft": False}]


def test_empty_when_gh_missing(monkeypatch, tmp_path):
    monkeypatch.setattr(ws_push.shutil, "which", lambda name: None)
    assert ws_push._get_open_prs(str(tmp_path)) == []


def test_empty_on_subprocess_failure(monkeypatch, tmp_path):
    monkeypatch.setattr(ws_push.shutil, "which", lambda name: "/usr/bin/gh")

    def boom(cmd, **kwargs):
        raise subprocess.TimeoutExpired(cmd, 5)

    monkeypatch.setattr(ws_push.subprocess, "run", boom)
    assert ws_push._get_open_prs(str(tmp_path)) == []


def test_cache_prevents_repeat_calls_within_ttl(monkeypatch, tmp_path):
    calls = []
    monkeypatch.setattr(ws_push.shutil, "which", lambda name: "/usr/bin/gh")

    def counting_run(cmd, **kwargs):
        calls.append(cmd)
        class R:
            returncode = 0
            stdout = "[]"
            stderr = ""
        return R()

    monkeypatch.setattr(ws_push.subprocess, "run", counting_run)
    ws_push._get_open_prs(str(tmp_path))
    ws_push._get_open_prs(str(tmp_path))
    assert len(calls) == 1
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 -m pytest pennyfarthing-dist/src/pf/tests/test_ws_push_open_prs.py -v`
Expected: FAIL — `ws_push` has no `_get_open_prs` / `_open_pr_cache` / module-level `shutil`/`subprocess`.

- [ ] **Step 3: Implement**

In `ws_push.py`, add `import shutil`, `import subprocess`, `import time` to the module imports, then above `fetch_git`:

```python
# Open-PR cache: {repo_path: (monotonic_ts, prs)}. The git channel polls every
# POLL_INTERVAL_S (5s); gh hits the network, so cache for 60s per repo.
_OPEN_PR_TTL_S = 60.0
_open_pr_cache: dict[str, tuple[float, list[dict[str, Any]]]] = {}


def _get_open_prs(repo_path: str) -> list[dict[str, Any]]:
    """Open PRs for a repo via gh, TTL-cached. Empty list on any failure."""
    cached = _open_pr_cache.get(repo_path)
    if cached and (time.monotonic() - cached[0]) < _OPEN_PR_TTL_S:
        return cached[1]

    gh_bin = shutil.which("gh")
    if not gh_bin:
        return []

    prs: list[dict[str, Any]] = []
    try:
        result = subprocess.run(
            [gh_bin, "pr", "list", "--json", "number,title,isDraft", "--limit", "20"],
            cwd=repo_path, capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            import json

            parsed = json.loads(result.stdout)
            if isinstance(parsed, list):
                prs = [
                    {
                        "number": p.get("number"),
                        "title": p.get("title", ""),
                        "isDraft": bool(p.get("isDraft", False)),
                    }
                    for p in parsed
                    if isinstance(p, dict)
                ]
    except Exception as exc:
        # Fail-loud (gh #50): warn once per failure, degrade to [].
        warnings.warn(f"Failed to list PRs for {repo_path}: {exc}", stacklevel=2)
    _open_pr_cache[repo_path] = (time.monotonic(), prs)
    return prs
```

In `fetch_git`, add to each repo dict:

```python
            "openPrs": _get_open_prs(repo_path),
```

Note: `fetch_diffs` currently imports `shutil`/`subprocess` locally — the new module-level imports make those redundant but harmless; leave them.

- [ ] **Step 4: Run tests**

Run: `python3 -m pytest pennyfarthing-dist/src/pf/tests/test_ws_push_open_prs.py pennyfarthing-dist/src/pf/tests/ -k "ws_push or frame" -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pennyfarthing-dist/src/pf/frame/ws_push.py pennyfarthing-dist/src/pf/tests/test_ws_push_open_prs.py
git commit -m "feat(frame): enrich git channel with TTL-cached open PR list via gh"
```

---

### Task 8: Git Status panel

**Files:**
- Create: `web/src/panels/GitStatus.tsx`, `web/src/test/fixtures/git.ts`
- Modify: `web/src/App.tsx` (mount panel)
- Test: `web/src/panels/GitStatus.test.tsx`

**Interfaces:**
- Consumes: `useChannel<GitMessage>('git')` (Task 3 types, Task 7 `openPrs` field).
- Produces: `GitStatus()` component.

- [ ] **Step 1: Fixture + failing tests**

Create `web/src/test/fixtures/git.ts`:

```ts
import type { GitMessage } from '../../api/types'

export const gitFixture: GitMessage = {
  type: 'init',
  repos: [
    {
      name: 'orchestrator',
      path: '.',
      branch: 'main',
      clean: true,
      ahead: 0,
      behind: 0,
      developBehind: null,
      dirtyFiles: [],
      openPrs: [],
    },
    {
      name: 'pennyfarthing',
      path: 'pennyfarthing',
      branch: 'feat/163-2-web-scaffold',
      clean: false,
      ahead: 2,
      behind: 0,
      developBehind: 1,
      dirtyFiles: [{ path: 'web/src/App.tsx', status: 'M' }],
      openPrs: [{ number: 191, title: 'feat(web): scaffold', isDraft: false }],
    },
  ],
}
```

Create `web/src/panels/GitStatus.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react'
import { expect, test, vi } from 'vitest'
import type { GitMessage } from '../api/types'
import { gitFixture } from '../test/fixtures/git'

const channelState = {
  data: gitFixture as GitMessage | null,
  connected: true,
  lastUpdated: Date.now() as number | null,
}
vi.mock('../api/useChannel', () => ({ useChannel: () => channelState }))

import { GitStatus } from './GitStatus'

test('renders each repo with branch and clean state', () => {
  render(<GitStatus />)
  expect(screen.getByText('orchestrator')).toBeInTheDocument()
  expect(screen.getByText('main')).toBeInTheDocument()
  expect(screen.getByText('feat/163-2-web-scaffold')).toBeInTheDocument()
  expect(screen.getByText(/1 dirty/)).toBeInTheDocument()
})

test('shows ahead count and open PRs', () => {
  render(<GitStatus />)
  expect(screen.getByText(/↑2/)).toBeInTheDocument()
  expect(screen.getByText(/#191/)).toBeInTheDocument()
  expect(screen.getByText(/feat\(web\): scaffold/)).toBeInTheDocument()
})
```

- [ ] **Step 2: Implement GitStatus**

Create `web/src/panels/GitStatus.tsx`:

```tsx
import { useChannel } from '../api/useChannel'
import type { GitMessage, GitRepo } from '../api/types'
import { PanelShell } from '../components/PanelShell'

function RepoRow({ repo }: { repo: GitRepo }) {
  const dirty = repo.dirtyFiles?.length ?? 0
  return (
    <div className="border-t border-zinc-800/60 py-2 first:border-t-0">
      <div className="flex items-center gap-2">
        <span className="text-sm font-medium">{repo.name}</span>
        <span className="font-mono text-xs text-zinc-400">{repo.branch}</span>
        <span className="flex-1" />
        {repo.ahead ? <span className="text-xs text-amber-400">↑{repo.ahead}</span> : null}
        {repo.behind ? <span className="text-xs text-sky-400">↓{repo.behind}</span> : null}
        <span
          className={`rounded px-1.5 py-0.5 text-xs ${
            repo.clean ? 'bg-emerald-900 text-emerald-300' : 'bg-amber-900 text-amber-300'
          }`}
        >
          {repo.clean ? 'clean' : `${dirty} dirty`}
        </span>
      </div>
      {(repo.openPrs?.length ?? 0) > 0 && (
        <ul className="pt-1">
          {repo.openPrs!.map((pr) => (
            <li key={pr.number} className="truncate text-xs text-zinc-400">
              <span className="font-mono">#{pr.number}</span> {pr.title}
              {pr.isDraft && <span className="ml-1 text-zinc-600">(draft)</span>}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export function GitStatus() {
  const { data, connected, lastUpdated } = useChannel<GitMessage>('git')
  return (
    <PanelShell title="Git" connected={connected} lastUpdated={lastUpdated}>
      {data && data.repos.map((r) => <RepoRow key={r.name} repo={r} />)}
    </PanelShell>
  )
}
```

Mount `<GitStatus />` in `App.tsx`'s grid.

- [ ] **Step 3: Run tests**

Run: `cd web && npm test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add web/src/
git commit -m "feat(web): Git Status panel with per-repo branch, dirty state, and open PRs"
```

---

### Task 9: Settings persistence (Frame) + header strip with theme/toggles + disconnect banner

**Files:**
- Modify: `pennyfarthing/pennyfarthing-dist/src/pf/frame/routes/state.py` (persist whitelisted keys in `patch_settings`)
- Create: `web/src/components/HeaderControls.tsx`, `web/src/components/DisconnectBanner.tsx`
- Modify: `web/src/App.tsx` (banner + header controls)
- Test: `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_settings_persistence.py`, `web/src/components/HeaderControls.test.tsx`, `web/src/components/DisconnectBanner.test.tsx`

**Interfaces:**
- Consumes: `GET /api/settings/`, `GET /api/settings/themes`, `PATCH /api/settings/` (existing routes); `patchJSON` / `getJSON` (Task 6); `useConnectionStatus()` (Task 3).
- Produces: `PATCH /api/settings/` now persists `theme`, `bell_mode`, `relay_mode` to `.pennyfarthing/config.local.yaml` (other keys stay in-memory as today); `HeaderControls()`; `DisconnectBanner()`.

- [ ] **Step 1: Failing Python persistence test**

Create `pennyfarthing-dist/src/pf/tests/test_settings_persistence.py`:

```python
"""PATCH /api/settings persists whitelisted keys to config.local.yaml."""
from pathlib import Path

import yaml
from fastapi.testclient import TestClient


def _client(monkeypatch, project_dir: Path) -> TestClient:
    monkeypatch.setenv("PF_PROJECT_DIR", str(project_dir))
    monkeypatch.delenv("FRAME_WEBUI_DIR", raising=False)
    from pf.frame.app import create_app

    return TestClient(create_app())


def test_patch_persists_theme_to_config(tmp_path, monkeypatch):
    (tmp_path / ".pennyfarthing").mkdir()
    client = _client(monkeypatch, tmp_path)
    resp = client.patch("/api/settings/", json={"theme": "discworld"})
    assert resp.status_code == 200
    config = yaml.safe_load(
        (tmp_path / ".pennyfarthing" / "config.local.yaml").read_text()
    )
    assert config["theme"] == "discworld"


def test_patch_preserves_existing_config_keys(tmp_path, monkeypatch):
    pf_dir = tmp_path / ".pennyfarthing"
    pf_dir.mkdir()
    (pf_dir / "config.local.yaml").write_text("statusbar: full\ntheme: scifi\n")
    client = _client(monkeypatch, tmp_path)
    client.patch("/api/settings/", json={"bell_mode": True})
    config = yaml.safe_load((pf_dir / "config.local.yaml").read_text())
    assert config == {"statusbar": "full", "theme": "scifi", "bell_mode": True}


def test_patch_nonpersisted_key_touches_no_file(tmp_path, monkeypatch):
    (tmp_path / ".pennyfarthing").mkdir()
    client = _client(monkeypatch, tmp_path)
    resp = client.patch("/api/settings/", json={"ephemeral_thing": 1})
    assert resp.status_code == 200
    assert not (tmp_path / ".pennyfarthing" / "config.local.yaml").exists()


def test_patch_write_failure_returns_error(tmp_path, monkeypatch):
    # No .pennyfarthing dir at all -> write fails -> result-shaped error.
    client = _client(monkeypatch, tmp_path)
    resp = client.patch("/api/settings/", json={"theme": "discworld"})
    assert resp.status_code == 500
    assert "error" in resp.json()
```

- [ ] **Step 2: Run to verify failure, then implement**

Run: `python3 -m pytest pennyfarthing-dist/src/pf/tests/test_settings_persistence.py -v` — Expected: FAIL.

Replace `patch_settings` in `state.py` (follows the existing `patch_layout` persistence pattern):

```python
# Keys the web/TUI settings surface mutates that must survive a Frame restart.
_PERSISTED_SETTINGS_KEYS = ("theme", "bell_mode", "relay_mode")


@settings_router.patch("/")
async def patch_settings(request: Request) -> JSONResponse:
    body = await request.json()
    _settings.update(body)

    persisted = {k: v for k, v in body.items() if k in _PERSISTED_SETTINGS_KEYS}
    if persisted:
        project_dir = _get_project_dir()
        config_path = Path(project_dir, ".pennyfarthing", "config.local.yaml")
        try:
            import yaml

            config: dict[str, Any] = {}
            if config_path.is_file():
                config = yaml.safe_load(config_path.read_text()) or {}
            config.update(persisted)
            config_path.write_text(yaml.dump(config, default_flow_style=False))
        except Exception as exc:
            return JSONResponse(
                {"error": f"Failed to persist settings: {exc}"}, status_code=500
            )
    return JSONResponse({"success": True})
```

Run: `python3 -m pytest pennyfarthing-dist/src/pf/tests/test_settings_persistence.py pennyfarthing-dist/src/pf/tests/test_frame_routes.py -v` — Expected: PASS.

Commit:

```bash
git add pennyfarthing-dist/src/pf/frame/routes/state.py pennyfarthing-dist/src/pf/tests/test_settings_persistence.py
git commit -m "feat(frame): persist theme/bell_mode/relay_mode from PATCH /api/settings"
```

- [ ] **Step 3: Failing frontend tests for banner + header**

Create `web/src/components/DisconnectBanner.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react'
import { expect, test, vi } from 'vitest'

let connected = true
vi.mock('../api/connection', () => ({ useConnectionStatus: () => connected }))

import { DisconnectBanner } from './DisconnectBanner'

test('renders nothing while connected', () => {
  connected = true
  const { container } = render(<DisconnectBanner />)
  expect(container).toBeEmptyDOMElement()
})

test('shows retry banner when any channel is down', () => {
  connected = false
  render(<DisconnectBanner />)
  expect(screen.getByText(/frame disconnected — retrying/i)).toBeInTheDocument()
})
```

Create `web/src/components/HeaderControls.test.tsx`:

```tsx
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi, beforeEach } from 'vitest'

const getJSON = vi.fn()
const patchJSON = vi.fn().mockResolvedValue({ success: true })
vi.mock('../api/rest', () => ({
  getJSON: (p: string) => getJSON(p),
  patchJSON: (p: string, b: unknown) => patchJSON(p, b),
}))

import { HeaderControls } from './HeaderControls'

beforeEach(() => {
  getJSON.mockImplementation((path: string) => {
    if (path === '/api/settings/themes')
      return Promise.resolve({ themes: ['discworld', 'scifi'] })
    return Promise.resolve({ theme: 'discworld', bell_mode: false, relay_mode: true })
  })
  patchJSON.mockClear()
})

test('loads themes and current settings', async () => {
  render(<HeaderControls />)
  await waitFor(() =>
    expect(screen.getByLabelText(/theme/i)).toHaveValue('discworld'),
  )
  expect(screen.getByRole('option', { name: 'scifi' })).toBeInTheDocument()
})

test('changing theme PATCHes settings and refetches (no optimistic UI)', async () => {
  render(<HeaderControls />)
  await waitFor(() => expect(screen.getByLabelText(/theme/i)).toHaveValue('discworld'))
  await userEvent.selectOptions(screen.getByLabelText(/theme/i), 'scifi')
  expect(patchJSON).toHaveBeenCalledWith('/api/settings/', { theme: 'scifi' })
})

test('toggling bell mode PATCHes the flag', async () => {
  render(<HeaderControls />)
  await waitFor(() => expect(screen.getByLabelText(/bell/i)).not.toBeChecked())
  await userEvent.click(screen.getByLabelText(/bell/i))
  expect(patchJSON).toHaveBeenCalledWith('/api/settings/', { bell_mode: true })
})

test('failed PATCH surfaces an error message', async () => {
  patchJSON.mockRejectedValueOnce(new Error('PATCH /api/settings/ failed: 500'))
  render(<HeaderControls />)
  await waitFor(() => expect(screen.getByLabelText(/theme/i)).toHaveValue('discworld'))
  await userEvent.selectOptions(screen.getByLabelText(/theme/i), 'scifi')
  await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent(/500/))
})
```

- [ ] **Step 4: Implement banner + header controls**

Create `web/src/components/DisconnectBanner.tsx`:

```tsx
import { useConnectionStatus } from '../api/connection'

export function DisconnectBanner() {
  const connected = useConnectionStatus()
  if (connected) return null
  return (
    <div className="mb-3 rounded border border-red-800 bg-red-950 px-3 py-2 text-sm text-red-300">
      Frame disconnected — retrying…
    </div>
  )
}
```

Create `web/src/components/HeaderControls.tsx`:

```tsx
import { useCallback, useEffect, useState } from 'react'
import { getJSON, patchJSON } from '../api/rest'

interface Settings {
  theme?: string
  bell_mode?: boolean
  relay_mode?: boolean
}

// No optimistic UI (spec): every change PATCHes, then re-reads the server's
// confirmed state.
export function HeaderControls() {
  const [themes, setThemes] = useState<string[]>([])
  const [settings, setSettings] = useState<Settings>({})
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(() => {
    getJSON<Settings>('/api/settings/').then(setSettings).catch((e: Error) => setError(e.message))
  }, [])

  useEffect(() => {
    getJSON<{ themes: string[] }>('/api/settings/themes')
      .then((r) => setThemes(r.themes))
      .catch((e: Error) => setError(e.message))
    refresh()
  }, [refresh])

  const apply = (patch: Settings) => {
    setError(null)
    patchJSON('/api/settings/', patch)
      .then(refresh)
      .catch((e: Error) => setError(e.message))
  }

  return (
    <div className="ml-auto flex items-center gap-4 text-sm">
      <label className="flex items-center gap-2">
        <span className="text-zinc-400">Theme</span>
        <select
          aria-label="theme"
          value={settings.theme ?? ''}
          onChange={(e) => apply({ theme: e.target.value })}
          className="rounded border border-zinc-700 bg-zinc-900 px-2 py-1"
        >
          {themes.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </select>
      </label>
      <label className="flex items-center gap-2">
        <span className="text-zinc-400">Bell</span>
        <input
          type="checkbox"
          aria-label="bell mode"
          checked={settings.bell_mode ?? false}
          onChange={(e) => apply({ bell_mode: e.target.checked })}
        />
      </label>
      <label className="flex items-center gap-2">
        <span className="text-zinc-400">Relay</span>
        <input
          type="checkbox"
          aria-label="relay mode"
          checked={settings.relay_mode ?? false}
          onChange={(e) => apply({ relay_mode: e.target.checked })}
        />
      </label>
      {error && (
        <span role="alert" className="text-xs text-red-400">
          {error}
        </span>
      )}
    </div>
  )
}
```

In `App.tsx`: render `<HeaderControls />` inside the header (after the `<h1>`), and `<DisconnectBanner />` between header and `<main>`.

- [ ] **Step 5: Run all tests**

Run: `cd web && npm test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add web/src/
git commit -m "feat(web): header settings controls and disconnect banner"
```

---

### Task 10: Packaging — ship the built UI in the wheel

**Files:**
- Modify: `pennyfarthing/pyproject.toml` (package-data for `pf.frame`)
- Modify: `pennyfarthing/justfile` (or create recipe location per repo convention — check `just --list` first) — `web-build` recipe
- Test: manual verification steps below (packaging is config, not logic; the wheel check is the test)

**Interfaces:**
- Consumes: Vite build output at `pennyfarthing-dist/src/pf/frame/webui/dist/` (Task 2).
- Produces: wheels built after `npm run build` include the UI; `just web-build` one-shot recipe.

- [ ] **Step 1: Package data**

In `pyproject.toml` under `[tool.setuptools.package-data]` add:

```toml
"pf.frame" = ["webui/dist/**/*"]
```

- [ ] **Step 2: Build recipe**

Add to the pennyfarthing `justfile` (create the recipe following existing recipe style — inspect the file first):

```make
# Build the web UI into pf/frame/webui/dist (shipped in the wheel)
web-build:
    cd web && npm ci && npm run build
```

- [ ] **Step 3: Verify the wheel actually contains the UI**

```bash
cd pennyfarthing
just web-build
python3 -m pip wheel . --no-deps -w /tmp/pf-wheel
python3 -c "
import glob, zipfile
w = glob.glob('/tmp/pf-wheel/*.whl')[0]
names = zipfile.ZipFile(w).namelist()
hits = [n for n in names if 'webui/dist' in n]
assert any(n.endswith('index.html') for n in hits), hits
print(f'OK: {len(hits)} webui files in wheel')
"
```

Expected: `OK: N webui files in wheel`.

- [ ] **Step 4: Document the release step**

Add to the framework release documentation (wherever the version-bump/release checklist lives — search `grep -ril "release" pennyfarthing/docs/ pennyfarthing/pennyfarthing-dist/guides/`): a wheel built without running `just web-build` first ships without the dashboard (Frame degrades gracefully — Task 1); release builds must run `just web-build` before packaging.

- [ ] **Step 5: Commit**

```bash
git add pyproject.toml justfile
git commit -m "chore(build): ship built web UI as pf.frame package data with just web-build recipe"
```

---

### Task 11: Isolated frontend CI job

**Files:**
- Create: `pennyfarthing/.github/workflows/web.yml` (check `.github/workflows/` for existing conventions first and mirror them — runner, node version pinning, concurrency groups)

**Interfaces:**
- Consumes: `npm run lint` / `typecheck` / `test` / `build` from Task 2.
- Produces: a `web` check that runs **only** when `web/**` changes; it never gates Python merges (path filter is the isolation mechanism — pytest workflows remain untouched).

- [ ] **Step 1: Write the workflow**

```yaml
name: web

on:
  pull_request:
    paths:
      - 'web/**'
  push:
    branches: [develop]
    paths:
      - 'web/**'

jobs:
  web:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: web
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
          cache-dependency-path: web/package-lock.json
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test
      - run: npm run build
```

- [ ] **Step 2: Verify existing Python workflows have no `web/**` awareness**

Run: `grep -rn "web" pennyfarthing/.github/workflows/ --include="*.yml" | grep -v "web.yml"`
Expected: no Python workflow references `web/` (no accidental coupling).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/web.yml
git commit -m "ci(web): isolated frontend job gated on web/** paths only"
```

---

### Task 12: ADR + documentation updates

**Files:**
- Create: `docs/adr/0042-web-gui-resurrection.md` (**orchestrator repo** — branch off `main`)
- Modify: `pennyfarthing/CLAUDE.md` (amend implementation rule 6; add web/ row to directory table)
- Modify: `.pennyfarthing/repos.yaml` → **source at** `pennyfarthing/pennyfarthing-dist/` — locate with `grep -rn "ui_layer\|UI Layer" pennyfarthing/pennyfarthing-dist/` and edit the source file, never the symlink target

**Interfaces:**
- Consumes: the shipped implementation (Tasks 1–11) and ADR-0039's Consequences section.
- Produces: the canonical decision record; corrected repo metadata.

- [ ] **Step 1: Write the ADR**

Create `docs/adr/0042-web-gui-resurrection.md` in the orchestrator repo:

```markdown
# ADR-0042: Web GUI Resurrection — Browser Client of the Frame API

**Status:** Accepted
**Date:** 2026-08-07
**Author:** PM (Lord Vetinari) / Architect review
**Amends:** [ADR-0039: React GUI Removal — Python-Only Architecture](0039-react-gui-removal-python-only.md)

## Context

ADR-0039 removed the React GUI because it carried three specific costs: a second
CI gate (vitest alongside pytest), canonical-logic drift (TS reimplementations of
Python logic), and a Node build pipeline required for a layer with no business
logic. Its Consequences section explicitly left the door open: "Any future rich
web UI is a greenfield effort that would consume the Frame API as a client."

This is that effort. The Frame FastAPI server now has a mature API surface
(story, sprint, git, persona, settings, analysis routes; per-channel WebSocket
push) already consumed by the TUI and IDE panels. A browser dashboard is a third
client of an API that has two.

## Decision

1. **A greenfield `web/` directory** (React + TypeScript + Vite + Tailwind) in the
   pennyfarthing repo builds static assets into `pf/frame/webui/dist`.
2. **Frame serves the build via FastAPI StaticFiles** at `/` when present; absent,
   Frame behaves exactly as before. Assets ship in the wheel — users never need Node.
3. **Boundary rule:** the frontend renders Frame responses verbatim. No client-side
   derivation of workflow state, no YAML parsing, no theme logic. Needed
   computations become Frame routes (e.g. `/api/workflow/`, `/api/persona/portrait`).
4. **CI isolation:** the frontend job triggers only on `web/**` paths and never
   gates Python merges. pytest remains the sole gate for Python.
5. **Scope:** observability panels (Sprint, Workflow, Git) plus settings/theme
   controls and copyable story ids. Explicitly NOT a Cyclist resurrection — no
   terminal wrapper, no Electron, no dockable panels, no auth (localhost only).

## Why this does not reintroduce ADR-0039's diseases

| ADR-0039 disease | Immunization |
|---|---|
| Two test suites gating CI | web job path-filtered to `web/**`; never gates Python |
| Canonical-logic drift | Boundary rule: zero logic in the frontend to drift |
| Node required at build/runtime | Node is dev-time only; wheels ship prebuilt assets; Frame degrades gracefully without them |

## Consequences

- ADR-0039's "No browser GUI" consequence is superseded; its architectural
  rationale (Python owns all logic) is preserved and enforced by the boundary rule.
- The framework repo regains a `package.json` — scoped to `web/`, invisible to
  Python tooling.
- Release builds must run `just web-build` before packaging or the wheel ships
  without the dashboard (documented in the release checklist).

## Related

- Amends [ADR-0039](0039-react-gui-removal-python-only.md)
- Spec: `docs/superpowers/specs/2026-08-07-web-gui-resurrection-design.md`
- Plan: `docs/superpowers/plans/2026-08-07-web-gui-resurrection.md`
```

- [ ] **Step 2: Update ADR-0039 with a superseded-by pointer**

In `docs/adr/0039-react-gui-removal-python-only.md`, change the Status line to:

```markdown
**Status:** Accepted · "No browser GUI" consequence amended by [ADR-0042](0042-web-gui-resurrection.md)
```

- [ ] **Step 3: Amend framework CLAUDE.md**

In `pennyfarthing/CLAUDE.md`, replace implementation rule 6:

```markdown
6. **Python owns all logic** — `web/` is a pure view layer over the Frame API (ADR-0042 boundary rule: no client-side workflow derivation, YAML parsing, or theme logic; computations become Frame routes). No other JavaScript/TypeScript in this repo.
```

Add to the directory table:

```markdown
| `web/` | Browser dashboard (React/Vite) — pure Frame API client, builds into `pf/frame/webui/dist` |
```

- [ ] **Step 4: Update repos.yaml source**

Locate the repos topology source in `pennyfarthing/pennyfarthing-dist/` (grep for `ui_layer`). For the pennyfarthing repo entry, set the UI layer/components metadata to reflect reality:

```yaml
ui_layer: react
components: web/src
```

(The current value references the removed `packages/cyclist/src/components` — stale since v13.)

- [ ] **Step 5: Commit (two repos, two branches)**

```bash
# Orchestrator repo (from repo root, branch off main):
git add docs/adr/
git commit -m "docs(adr): ADR-0042 web GUI resurrection, amend ADR-0039 status"

# Pennyfarthing repo (branch off develop):
cd pennyfarthing
git add CLAUDE.md pennyfarthing-dist/
git commit -m "docs: record web/ view layer and boundary rule (ADR-0042)"
```

---

## Final Verification (after all tasks)

- [ ] `cd pennyfarthing && python3 -m pytest pennyfarthing-dist/src/pf/tests/ -v` — full Python suite green.
- [ ] `cd pennyfarthing/web && npm run lint && npm run typecheck && npm test && npm run build` — frontend green, build emits.
- [ ] Manual smoke from the orchestrator root: `pf frame start`, open `http://localhost:2898` — three panels render live data; kill Frame → banner appears, panels dim; restart → panels recover; click a story id → paste it in the terminal; change theme → `config.local.yaml` updated.
- [ ] `pf validate` passes.
