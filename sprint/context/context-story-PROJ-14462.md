# Story Context: 82-1 - Agent load API endpoint

## Summary

Create a new Express API router at `GET /api/agent-load` that runs `getPrimeContextJson()` for all 10 primary agents at FULL tier and returns an array of per-agent token breakdowns. Results are cached for 60 seconds since prime invocation is expensive (spawns a Python process per agent). The router follows the existing `hotspots.ts` pattern: factory function accepting `getProjectDir`, mounted in `server.ts`.

## Current State

### Prime Context System

`getPrimeContextJson()` at `packages/cyclist/src/prime.ts` lines 327-369 is the core function. It calls `buildPrimeCommand(agentName, tier, true)` (line 344) which produces `python3 -m pennyfarthing_scripts.cli agent start "<name>" --quiet --tier FULL --json`. The command runs via `execSync` with a 10-second timeout (line 350) and the output is parsed by `parsePrimeOutput()` (line 355) into a `PrimeOutput` object.

The `PrimeOutput` interface (lines 143-156) contains:
```typescript
export interface PrimeOutput {
  context?: string;          // Full assembled system prompt (DO NOT expose)
  tier?: ContextTier;
  agentName?: string;
  tokenCounts?: Record<string, number>;
  totalTokens?: number;
  components?: PrimeComponent[];
}
```

The `PrimeComponent` interface (lines 131-138):
```typescript
export interface PrimeComponent {
  name: string;     // e.g., "agent_definition", "persona", "sidecars"
  tokens: number;
  source?: string;  // e.g., ".pennyfarthing/agents/dev.md"
}
```

### Async Wrapper

`getPrimeContextAsync()` at `prime.ts` lines 111-118 wraps the sync call in `setImmediate` to avoid blocking the event loop:
```typescript
export async function getPrimeContextAsync(agentName: string, projectDir: string): Promise<string | null> {
  return new Promise((resolve) => {
    setImmediate(() => {
      resolve(getPrimeContext(agentName, projectDir));
    });
  });
}
```
There is no async equivalent for `getPrimeContextJson()` yet -- one must be created or the same `setImmediate` pattern applied.

### Python Side

The Python CLI at `pennyfarthing_scripts/prime/cli.py` line 524 handles `--json` output by calling `_build_json_result()` (lines 137-172), which calls `load_tier_components()` (tiers.py lines 84-201) and assembles `PrimeComponent` objects (models.py lines 134-153) with `name`, `tokens`, and `source` fields. Component sources are mapped at cli.py lines 108-121 (e.g., sidecars -> `.pennyfarthing/sidecars/{agent_name}/`).

Token estimation uses `estimate_tokens()` at `tiers.py` lines 19-35: `max(1, len(text) // 4)`.

### Existing API Pattern

`hotspots.ts` (`packages/cyclist/src/api/hotspots.ts`, 59 lines) is the closest reference:
- Factory: `createHotspotsRouter(getProjectDir: () => string): Router` (line 6)
- Single GET handler spawning Python via `execFile` (lines 31-55)
- JSON parse of stdout, error handling for spawn failure and parse failure
- Mounted in `server.ts` line 138: `app.use('/api/hotspots', createHotspotsRouter(getProjectDir))`
- Exported from `api/index.ts` line 9: `export { createHotspotsRouter } from './hotspots.js'`

### No Agent Load API Exists

There is currently no `/api/agent-load` endpoint. No file `api/agent-load.ts` exists. The agent list is not codified in TypeScript -- the 10 primary agents are defined by the presence of `.pennyfarthing/agents/{name}.md` files and matching sidecar directories at `.pennyfarthing/sidecars/`.

### Agent List (10 primary agents)

Confirmed from `.pennyfarthing/sidecars/` directory listing and epic context:
`sm`, `tea`, `dev`, `reviewer`, `architect`, `pm`, `tech-writer`, `ux-designer`, `devops`, `orchestrator`

## Target State

After implementation:

1. New file `packages/cyclist/src/api/agent-load.ts` with `createAgentLoadRouter(getProjectDir: () => string): Router`
2. `GET /api/agent-load` returns `{ agents: [...], cachedAt: string, totalAcrossAllAgents: number }`
3. Each agent entry: `{ agent, totalTokens, tokenCounts, components }` -- no `context` field (security: would leak full system prompt)
4. Results cached in module-level variable; cache hit returns immediately if `Date.now() - cachedAt < 60_000`
5. All 10 agents run in parallel via `Promise.all` with `setImmediate`-wrapped `getPrimeContextJson()` calls
6. Partial failures handled gracefully: failed agent has `totalTokens: null` and `error` field
7. Router mounted in `server.ts` and exported from `api/index.ts`
8. Cache is exported (module-level) so story 82-2 can invalidate it after sidecar prune

## Key Files

### Files to Create

| File | Location | What It Does |
|------|----------|--------------|
| `agent-load.ts` | `pennyfarthing/packages/cyclist/src/api/agent-load.ts` | Express router with GET `/` handler, cache logic, parallel prime execution |

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `api/index.ts` | `pennyfarthing/packages/cyclist/src/api/index.ts` | Add `export { createAgentLoadRouter, invalidateAgentLoadCache } from './agent-load.js'` |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | Import `createAgentLoadRouter`, mount at `/api/agent-load` (after line 138) |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `prime.ts` | `pennyfarthing/packages/cyclist/src/prime.ts` | `getPrimeContextJson()` (lines 327-369), `PrimeOutput` interface (lines 143-156), `PrimeComponent` (lines 131-138), `getPrimeContextAsync()` pattern (lines 111-118) |
| `hotspots.ts` | `pennyfarthing/packages/cyclist/src/api/hotspots.ts` | Reference API pattern: factory function, error handling, JSON response |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | Router mounting pattern (lines 107-138), `getProjectDir()` helper (lines 93-95) |
| `api/index.ts` | `pennyfarthing/packages/cyclist/src/api/index.ts` | Export barrel pattern (40 lines) |
| `tiers.py` | `pennyfarthing/pennyfarthing_scripts/prime/tiers.py` | `load_tier_components()` (lines 84-201), `estimate_tokens()` (lines 19-35) |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/prime/cli.py` | `_build_json_result()` (lines 137-172), `_component_source()` (lines 108-121), JSON output format |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/prime/models.py` | `PrimeResult.to_dict()` (lines 190-206), `PrimeComponent` dataclass (lines 134-153) |

## Technical Approach

### 1. Create `agent-load.ts`

Define the 10 primary agents as a constant:
```typescript
const PRIMARY_AGENTS = [
  'sm', 'tea', 'dev', 'reviewer', 'architect',
  'pm', 'tech-writer', 'ux-designer', 'devops', 'orchestrator',
] as const;
```

### 2. Add async wrapper for `getPrimeContextJson`

Create a `getPrimeContextJsonAsync` helper following the `getPrimeContextAsync` pattern at `prime.ts` lines 111-118:
```typescript
function getPrimeContextJsonAsync(
  agentName: string,
  projectDir: string,
  tier: ContextTier
): Promise<PrimeOutput | null> {
  return new Promise((resolve) => {
    setImmediate(() => {
      resolve(getPrimeContextJson(agentName, projectDir, tier));
    });
  });
}
```

### 3. Implement cache

Module-level cache with 60-second TTL:
```typescript
interface AgentLoadCache {
  data: AgentLoadResponse;
  cachedAt: number;
}

let cache: AgentLoadCache | null = null;
const CACHE_TTL_MS = 60_000;

export function invalidateAgentLoadCache(): void {
  cache = null;
}
```

Export `invalidateAgentLoadCache` so story 82-2 can clear it after a sidecar prune.

### 4. Build the GET handler

```typescript
export function createAgentLoadRouter(getProjectDir: () => string): Router {
  const router = Router();

  router.get('/', async (_req, res) => {
    // Check cache
    if (cache && Date.now() - cache.cachedAt < CACHE_TTL_MS) {
      return res.json(cache.data);
    }

    const projectDir = getProjectDir();

    // Run all 10 agents in parallel
    const results = await Promise.all(
      PRIMARY_AGENTS.map(async (agent) => {
        try {
          const output = await getPrimeContextJsonAsync(agent, projectDir, 'FULL');
          if (!output) {
            return { agent, totalTokens: null, error: 'Prime returned null' };
          }
          return {
            agent,
            totalTokens: output.totalTokens ?? 0,
            tokenCounts: output.tokenCounts ?? {},
            components: output.components ?? [],
          };
        } catch (err) {
          return { agent, totalTokens: null, error: String(err) };
        }
      })
    );

    const totalAcrossAllAgents = results.reduce(
      (sum, r) => sum + (r.totalTokens ?? 0), 0
    );

    const response = {
      agents: results,
      cachedAt: new Date().toISOString(),
      totalAcrossAllAgents,
    };

    cache = { data: response, cachedAt: Date.now() };
    res.json(response);
  });

  return router;
}
```

### 5. Mount in `server.ts`

Add after the hotspots router mount (line 138):
```typescript
import { createAgentLoadRouter } from './api/index.js';
// ...
app.use('/api/agent-load', createAgentLoadRouter(getProjectDir));
```

### 6. Export from `api/index.ts`

Add to the barrel file:
```typescript
// Epic 82: Agent Load Analyzer
export { createAgentLoadRouter, invalidateAgentLoadCache } from './agent-load.js';
```

## Acceptance Criteria

- `GET /api/agent-load` returns JSON with `agents` array containing all 10 primary agents
- Each agent entry includes `agent` (name), `totalTokens`, `tokenCounts` (per-component), and `components` (with source paths)
- The `context` field from `PrimeOutput` is **not** included in the response (security: leaks full system prompt)
- Results are cached for 60 seconds; subsequent requests within the TTL return the cached result
- Cache includes a `cachedAt` ISO timestamp so the UI can show freshness
- `totalAcrossAllAgents` sums all agents' `totalTokens`
- If one agent fails (prime returns null or throws), its entry has `totalTokens: null` and `error` string; other agents are unaffected
- All 10 prime invocations run in parallel via `Promise.all` (not sequentially)
- Router is mounted at `/api/agent-load` in `server.ts`
- `invalidateAgentLoadCache()` is exported for story 82-2 to call after sidecar prune
- Existing tests and other API endpoints are unaffected

## Dependencies

### Depends On

- **PROJ-12800** (Token counting in prime JSON output) -- **DONE**. The `tokenCounts`, `totalTokens`, and `components` fields exist in `PrimeOutput`.
- **PROJ-12796** (Tiered context injection) -- **DONE**. The `getPrimeContextJson()` function accepts a `tier` parameter.

### Depended On By

- **82-2** (Sidecar pruning API) -- adds POST handler to the same router, calls `invalidateAgentLoadCache()` after prune
- **82-3** (Agent load React hook + dialog) -- fetches from `GET /api/agent-load` to render the UI

## Risks / Open Questions

1. **Blocking event loop with `execSync`:** `getPrimeContextJson()` uses `execSync` internally (prime.ts line 346). Even with `setImmediate` wrapping, 10 simultaneous `execSync` calls will compete for the event loop. In practice each call takes 0.5-2 seconds and they're staggered by `setImmediate`, but under load WheelHub could become unresponsive for ~2-5 seconds. Consider a longer-term migration to `execFile` (async spawn) like `hotspots.ts` uses. For this story, the `setImmediate` pattern is acceptable since the endpoint is user-triggered (not called in a hot loop).

2. **Cache invalidation on config change:** If the user changes theme or persona config, the cached token counts become stale. The 60-second TTL mitigates this, but a config change notification could proactively invalidate the cache. This is an enhancement for a follow-up, not this story.

3. **Python dependency:** The endpoint requires `python3` and `pennyfarthing_scripts` to be on the path. If the Python package is missing, all 10 agents will fail. The endpoint should return a clear 500 error with `"Could not find pennyfarthing_scripts"` rather than 10 individual agent errors.

4. **Response size:** With 10 agents x ~7 components each, the response is ~3-5 KB of JSON. This is well within reasonable limits and does not need pagination.

5. **Agent list maintenance:** The 10-agent constant is hardcoded. If agents are added/removed from `pennyfarthing-dist/agents/`, the constant must be updated. An alternative is to read the agent list dynamically from the filesystem, but the epic context explicitly lists 10 agents and excludes subagents. Hardcoding is correct for now.
