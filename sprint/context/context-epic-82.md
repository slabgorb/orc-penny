# Epic 82: Agent Load Analyzer

## Overview

Tool to evaluate agent context budget by running `getPrimeContextJson()` for all agents at FULL tier. Shows per-component token breakdown (agent definition, persona, behavior guide, sprint context, session, sidecars). Enables viewing and pruning sidecar files that have grown too large. Express API on WheelHub server + React dialog in Cyclist.

**Prior work:** PROJ-12800 added component-level token tracking to prime JSON output. PROJ-12796 built the tiered context injection system. This epic exposes that data through a dedicated analysis UI.

## Background

### The Prime Context System

Every Pennyfarthing agent (sm, tea, dev, reviewer, architect, pm, tech-writer, ux-designer, devops, orchestrator) gets a system prompt assembled by the **prime** module. Prime loads up to 7 component types in priority order:

1. **workflow_state** -- routing decision (always included)
2. **agent_definition** -- from `.pennyfarthing/agents/{name}.md`
3. **persona** -- character voice from active theme
4. **behavior_guide** -- shared agent behavior from `.pennyfarthing/guides/agent-behavior.md`
5. **sprint_context** -- from `sprint/current-sprint.yaml`
6. **session_header** / **session_assessment** -- from `.session/*-session.md`
7. **sidecars** -- agent learning files from `.pennyfarthing/sidecars/{name}/` (patterns.md, gotchas.md, decisions.md)

### Tiered Context

Prime selects a tier based on session state to manage token overhead:

| Tier | ~Tokens | Components |
|------|---------|------------|
| FULL | 4000 | All 7 component types |
| REFRESH | 600 | workflow, sprint, session_header |
| HANDOFF | 700 | workflow, agent_definition, persona_compressed |
| MINIMAL | 200 | workflow only |

The Agent Load Analyzer always runs FULL tier to show the complete cost picture.

### Sidecar Files

Each agent has up to 3 sidecar files in `.pennyfarthing/sidecars/{agent}/`:

| File | Purpose | Max Lines |
|------|---------|-----------|
| `patterns.md` | Successful implementation patterns | 50 |
| `gotchas.md` | Common pitfalls and edge cases | 50 |
| `decisions.md` | Architecture decision records | 40 |

Sidecars grow over time as agents learn. The existing `sidecar-health.sh` script checks for bloat but requires manual CLI invocation. This epic provides a UI for viewing sidecar content and pruning back to the header template.

### Template Headers

Each sidecar type has a template at `pennyfarthing-dist/templates/sidecar/`:
- `patterns.md.template` (35 lines) -- pattern documentation format with `${AGENT_NAME}` placeholder
- `gotchas.md.template` (38 lines) -- gotcha documentation format
- `decisions.md.template` (41 lines) -- ADR documentation format

Pruning resets a sidecar to its template content with the agent name substituted.

## Technical Architecture

### Component Map

```
Cyclist Main Process (Node/Electron)
  └── WheelHub Server (Express)
        ├── GET /api/agent-load
        │     ├── Check cache (60s TTL)
        │     │   ├── Cache hit? → return cached result
        │     │   └── Cache miss? → run prime for all 10 agents
        │     ├── For each agent: getPrimeContextJson(agent, projectDir, 'FULL')
        │     │   └── Python: pennyfarthing_scripts.prime --agent <name> --tier FULL --json
        │     └── Return array of {agent, totalTokens, components, tokenCounts}
        │
        └── POST /api/agent-load/prune-sidecar
              ├── Validate {agent, file} (e.g., {agent: "dev", file: "patterns.md"})
              ├── Read current file size → compute tokensFreed
              ├── Read template from pennyfarthing-dist/templates/sidecar/{file}.template
              ├── Substitute ${AGENT_NAME} → write to .pennyfarthing/sidecars/{agent}/{file}
              └── Return {success, tokensFreed}

Cyclist Renderer (React 19)
  └── AgentLoadDialog (shadcn Dialog)
        ├── useAgentLoad() hook → fetches GET /api/agent-load
        ├── Ranked table: agents sorted by totalTokens desc
        │   └── Expandable rows: per-component breakdown
        ├── Sidecar viewer: shows content of selected sidecar
        └── Prune button → POST /api/agent-load/prune-sidecar
              └── ConfirmDialog for destructive action
```

### Key Files

| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| `packages/cyclist/src/prime.ts` | 369 | `getPrimeContextJson()`, `PrimeOutput` interface, `PrimeComponent` interface | Exists, core dependency |
| `packages/cyclist/src/server.ts` | 506 | Express app, router mounting pattern | Exists, mount point for new router |
| `packages/cyclist/src/api/index.ts` | 40 | API module exports barrel | Exists, add new export |
| `packages/cyclist/src/api/hotspots.ts` | 59 | Reference API pattern (GET, child_process, JSON) | Exists, pattern to follow |
| `packages/cyclist/src/public/hooks/useHotspots.ts` | 113 | Reference hook pattern (fetch, abort, loading/error) | Exists, pattern to follow |
| `packages/cyclist/src/public/components/panels/DebugPanel.tsx` | 268 | Existing token display, `formatComponentName()` | Exists, reuse formatting |
| `packages/cyclist/src/public/components/ConfirmDialog.tsx` | 168 | shadcn AlertDialog + `useConfirmDialog()` hook | Exists, reuse for prune confirm |
| `pennyfarthing_scripts/prime/tiers.py` | 201 | `load_tier_components()`, `estimate_tokens()`, `ContextTier` enum | Exists, core dependency |
| `pennyfarthing_scripts/prime/loader.py` | 239 | `load_sidecars()`, sidecar path: `.pennyfarthing/sidecars/{agent}/` | Exists, sidecar paths |
| `pennyfarthing_scripts/prime/models.py` | 207 | `PrimeResult.to_dict()`, `PrimeComponent` dataclass | Exists, JSON output schema |
| `pennyfarthing_scripts/prime/cli.py` | 646 | CLI `--json` flag, `_build_json_result()` | Exists, invoked by TS |
| `pennyfarthing-dist/scripts/maintenance/sidecar-health.sh` | 91 | Existing sidecar health check (line count thresholds) | Exists, reference for limits |
| `pennyfarthing-dist/templates/sidecar/patterns.md.template` | 35 | Template for pruned patterns.md | Exists, read by prune API |
| `pennyfarthing-dist/templates/sidecar/gotchas.md.template` | 38 | Template for pruned gotchas.md | Exists, read by prune API |
| `pennyfarthing-dist/templates/sidecar/decisions.md.template` | 41 | Template for pruned decisions.md | Exists, read by prune API |
| `packages/cyclist/src/api/agent-load.ts` | -- | **NEW**: Agent load API router | To create |
| `packages/cyclist/src/public/hooks/useAgentLoad.ts` | -- | **NEW**: React hook for agent load data | To create |
| `packages/cyclist/src/public/components/AgentLoadDialog.tsx` | -- | **NEW**: Dialog with ranked table + sidecar viewer | To create |

### API Contracts

**GET /api/agent-load**
```json
// Response (200)
{
  "agents": [
    {
      "agent": "dev",
      "totalTokens": 4200,
      "tokenCounts": {
        "workflow_state": 45,
        "agent_definition": 1200,
        "persona": 800,
        "behavior_guide": 950,
        "sprint_context": 80,
        "session_header": 120,
        "session_assessment": 205,
        "sidecars": 800
      },
      "components": [
        {
          "name": "agent_definition",
          "tokens": 1200,
          "source": ".pennyfarthing/agents/dev.md"
        },
        {
          "name": "persona",
          "tokens": 800,
          "source": null
        },
        {
          "name": "sidecars",
          "tokens": 800,
          "source": ".pennyfarthing/sidecars/dev/"
        }
      ]
    }
  ],
  "cachedAt": "2026-02-07T12:00:00.000Z",
  "totalAcrossAllAgents": 38500
}

// Response (500) - if prime fails for all agents
{
  "error": "Failed to load agent context",
  "details": "Could not find pennyfarthing_scripts"
}
```

**POST /api/agent-load/prune-sidecar**
```json
// Request
{
  "agent": "dev",
  "file": "patterns.md"
}

// Response (200)
{
  "success": true,
  "tokensFreed": 650,
  "agent": "dev",
  "file": "patterns.md"
}

// Response (400) - invalid input
{
  "success": false,
  "error": "Invalid sidecar file. Must be one of: patterns.md, gotchas.md, decisions.md"
}

// Response (404) - sidecar not found
{
  "success": false,
  "error": "Sidecar file not found: .pennyfarthing/sidecars/dev/patterns.md"
}
```

### Agent List

The 10 primary agents (from `pennyfarthing-dist/agents/`), matching sidecar directories:

| Agent | Definition File | Has Sidecar Dir |
|-------|----------------|-----------------|
| sm | `agents/sm.md` | Yes |
| tea | `agents/tea.md` | Yes |
| dev | `agents/dev.md` | Yes |
| reviewer | `agents/reviewer.md` | Yes |
| architect | `agents/architect.md` | Yes |
| pm | `agents/pm.md` | Yes |
| tech-writer | `agents/tech-writer.md` | Yes |
| ux-designer | `agents/ux-designer.md` | Yes |
| devops | `agents/devops.md` | Yes |
| orchestrator | `agents/orchestrator.md` | Yes |

Note: Subagents (sm-setup, sm-finish, sm-handoff, handoff, reviewer-preflight, testing-runner, workflow-status-check, sm-file-summary) are excluded -- they use reduced tiers and don't have sidecar directories.

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|-------------|
| 82-1 | Agent load API endpoint | 2 | P0 | None |
| 82-2 | Sidecar pruning API | 1 | P1 | 82-1 |
| 82-3 | Agent load React hook + dialog | 2 | P0 | 82-1 |

### Story Notes

**82-1: Agent load API endpoint**

Create `packages/cyclist/src/api/agent-load.ts` following the `hotspots.ts` pattern:

- `createAgentLoadRouter(getProjectDir: () => string): Router`
- GET `/` handler iterates the 10 primary agents, calling `getPrimeContextJson(agent, projectDir, 'FULL')` for each
- `getPrimeContextJson()` calls `execSync()` with a 10-second timeout per agent (`buildPrimeCommand(agentName, tier, true)`) -- total worst-case is ~100 seconds if all agents are slow
- Run agents in parallel using `Promise.all` with the async wrapper `getPrimeContextAsync()` -- or better, spawn all 10 `execSync` calls via a `Promise.all` of `setImmediate`-wrapped calls to avoid blocking the event loop serially
- Cache result in a module-level variable with a `cachedAt` timestamp; return cached if `Date.now() - cachedAt < 60_000`
- Invalidate cache on prune (82-2 clears the cache after successful prune)
- Mount at `/api/agent-load` in `server.ts` alongside other routers
- Export `createAgentLoadRouter` from `api/index.ts`
- Return the `PrimeOutput` fields: `agent` (name), `totalTokens`, `tokenCounts`, `components` from each `getPrimeContextJson()` call
- Handle partial failures gracefully: if one agent fails, include it with `totalTokens: null` and `error` field

Key function signatures to use from `prime.ts`:
```typescript
// Line 327-369
export function getPrimeContextJson(
  agentName: string,
  projectDir: string,
  tier: ContextTier
): PrimeOutput | null

// PrimeOutput interface (line 143-156)
export interface PrimeOutput {
  context?: string;
  tier?: ContextTier;
  agentName?: string;
  tokenCounts?: Record<string, number>;
  totalTokens?: number;
  components?: PrimeComponent[];
}
```

**82-2: Sidecar pruning API**

Add POST handler to the same `agent-load.ts` router:

- POST `/prune-sidecar` accepts `{agent: string, file: string}`
- Validate `agent` is one of the 10 primary agents
- Validate `file` is one of `patterns.md`, `gotchas.md`, `decisions.md`
- Resolve sidecar path: `join(projectDir, '.pennyfarthing', 'sidecars', agent, file)`
- Check file exists, read current content, compute current tokens via `estimate_tokens()` equivalent (character count / 4)
- Read template from `pennyfarthing-dist/templates/sidecar/{file}.template`
  - Template path resolution: use same `findPennyfarthingScripts()` approach from `prime.ts` or check `node_modules/@pennyfarthing/core/pennyfarthing-dist/templates/sidecar/`
  - Fallback: check relative to Cyclist source (`join(__dirname, '..', '..', '..', 'pennyfarthing-dist', 'templates', 'sidecar')`)
- Replace `${AGENT_NAME}` with the formatted agent name (capitalize first letter of each word: "dev" -> "Dev", "tech-writer" -> "Tech-Writer")
- Write template content to sidecar file
- Compute `tokensFreed = oldTokens - newTokens`
- Clear the 82-1 cache so next GET reflects the change
- Return `{success: true, tokensFreed, agent, file}`

**82-3: Agent load React hook + dialog**

Create two new files:

1. **`packages/cyclist/src/public/hooks/useAgentLoad.ts`** following `useHotspots.ts` pattern:
   - `useAgentLoad()` returns `{data, isLoading, error, refresh}`
   - Fetches `GET /api/agent-load` on demand (not auto -- user triggers via dialog open)
   - `pruneSidecar(agent, file)` method that POSTs to `/api/agent-load/prune-sidecar` and auto-refreshes on success
   - AbortController for cleanup on unmount

2. **`packages/cyclist/src/public/components/AgentLoadDialog.tsx`**:
   - shadcn Dialog (not AlertDialog -- this is informational, not destructive)
   - Triggered from DebugPanel or a toolbar button
   - On open: calls `refresh()` to fetch fresh data
   - Ranked table showing all 10 agents sorted by `totalTokens` descending
   - Each row shows: agent name, total tokens (formatted with `toLocaleString()`), bar visualization
   - Expandable rows using shadcn Collapsible: click to show per-component breakdown
   - Reuse `formatComponentName()` from `DebugPanel.tsx` (export it or extract to shared util)
   - Sidecar section: for each agent with sidecars, show file names + token counts
   - Prune button next to each sidecar file -- uses `ConfirmDialog` for confirmation (`useConfirmDialog` from `ConfirmDialog.tsx`)
   - After prune: show "X tokens freed" feedback, auto-refresh the table
   - Total bar at bottom: sum of all agents' `totalTokens`

## Constraints

- **Performance**: Running `getPrimeContextJson()` for all 10 agents involves 10 `execSync` calls to Python, each with a 10-second timeout. Worst case is ~100 seconds. In practice each call takes 0.5-2 seconds. The 60-second cache prevents repeated expensive calls. Consider running agents in parallel (Promise.all with setImmediate wrappers) to reduce total latency to ~2 seconds.
- **Blocking event loop**: `getPrimeContextJson()` uses `execSync` which blocks the Node.js event loop. For the load analyzer, use `getPrimeContextAsync()` or wrap in `setImmediate` (as the existing async wrapper does at line 111-118 of `prime.ts`). Running 10 sequentially would block for ~10-20 seconds; parallel via `Promise.all` is mandatory.
- **Cache invalidation**: The 60-second cache must be invalidated after a sidecar prune so the dialog shows updated token counts immediately.
- **Sidecar file paths**: Sidecars live at `.pennyfarthing/sidecars/{agent}/` in the project root, NOT inside `node_modules` or symlinked directories. The prune operation writes directly to this writable location.
- **Template path resolution**: Templates are in the source package at `pennyfarthing-dist/templates/sidecar/`. Use the same multi-location resolution pattern as `findPennyfarthingScripts()` in `prime.ts` (node_modules, .pennyfarthing symlink, dev mode relative path).
- **Agent name formatting**: The `${AGENT_NAME}` placeholder in templates expects title-case agent names (e.g., "Dev", "Tech-Writer"). Use a formatter that capitalizes each hyphen-separated word.
- **Existing sidecar health thresholds**: `sidecar-health.sh` defines limits of 50/50/40 lines for patterns/gotchas/decisions. The dialog could display a warning indicator when files exceed these thresholds.
- **No persona in response**: The `PrimeOutput.context` field contains the full assembled system prompt text. Do NOT include `context` in the API response -- it would leak the full agent prompt. Only return `tokenCounts`, `totalTokens`, and `components` (metadata without content).
- **Token estimation**: The Python side uses `len(text) // 4` as a character-to-token approximation. The TypeScript side should use the same formula for `tokensFreed` calculation consistency.
