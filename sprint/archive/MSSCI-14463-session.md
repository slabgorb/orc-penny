# Story 82-2: Sidecar pruning API

**Jira:** MSSCI-14463
**Epic:** 82 — Agent Load Analyzer
**Points:** 1
**Priority:** P1
**Workflow:** tdd
**Phase:** approved
**Repos:** pennyfarthing
**Branch:** feature/82-2-sidecar-pruning-api
**Assignee:** keith.avery

## Description

New Express API: POST /api/agent-load/prune-sidecar

Body: {agent, sidecar}. Resets sidecar file to its header template (preserves # Title and > description, clears content below --- separator). Returns {success, tokensFreed}.

## Acceptance Criteria

1. POST /api/agent-load/prune-sidecar endpoint implemented in `packages/cyclist/src/api/agent-load.ts`
2. Validates {agent, file} input (agent must be one of 10 primary agents, file must be patterns.md/gotchas.md/decisions.md)
3. Reads current sidecar file size and computes tokensFreed using character count / 4 formula
4. Reads template from pennyfarthing-dist/templates/sidecar/{file}.template
5. Replaces ${AGENT_NAME} placeholder with formatted agent name (title-case with hyphen separation)
6. Writes template content to .pennyfarthing/sidecars/{agent}/{file}
7. Clears the 82-1 cache so next GET reflects the change
8. Returns {success: true, tokensFreed, agent, file}
9. Handles errors gracefully: 400 for invalid input, 404 for missing sidecar
10. Tests cover happy path, invalid agent, invalid file, and missing sidecar scenarios

## Technical Context

### Dependencies

Story 82-2 depends on 82-1 (Agent load API endpoint) which:
- Implements GET /api/agent-load with 60-second cache
- Calls getPrimeContextJson() for all 10 agents at FULL tier
- Returns array of {agent, totalTokens, components, tokenCounts}

The prune endpoint invalidates the 82-1 cache after successful write.

### Key Files to Modify/Create

| File | Purpose |
|------|---------|
| `packages/cyclist/src/api/agent-load.ts` | Add POST /prune-sidecar handler (82-1 creates GET /, 82-2 adds POST) |
| Test file (TBD by workflow) | Unit tests for prune endpoint |

### Key Files to Reference

| File | Purpose | Lines |
|------|---------|-------|
| `packages/cyclist/src/api/hotspots.ts` | Reference API pattern (GET, child_process, JSON) | 59 |
| `packages/cyclist/src/prime.ts` | getPrimeContextJson(), PrimeOutput interface, token estimation | 369 |
| `packages/cyclist/src/server.ts` | Express app, router mounting pattern | 506 |
| `packages/cyclist/src/api/index.ts` | API module exports barrel | 40 |
| `pennyfarthing-dist/templates/sidecar/*.template` | Template files for pruning | 35-41 lines each |
| `pennyfarthing_scripts/prime/models.py` | PrimeResult.to_dict(), PrimeComponent dataclass | 207 |

### Sidecar File Structure

Each agent has up to 3 sidecar files in `.pennyfarthing/sidecars/{agent}/`:

| File | Template Lines | Format |
|------|----------------|--------|
| `patterns.md` | 35 | Successful implementation patterns |
| `gotchas.md` | 38 | Common pitfalls and edge cases |
| `decisions.md` | 41 | Architecture decision records |

Templates located at `pennyfarthing-dist/templates/sidecar/` with ${AGENT_NAME} placeholder for agent name formatting.

### 10 Primary Agents

sm, tea, dev, reviewer, architect, pm, tech-writer, ux-designer, devops, orchestrator

### Token Estimation

Use character count / 4 formula for consistency with Python side:
```typescript
const tokensFreed = Math.floor((oldContent.length - newContent.length) / 4);
```

### API Contract

**POST /api/agent-load/prune-sidecar**

Request:
```json
{
  "agent": "dev",
  "file": "patterns.md"
}
```

Response (200):
```json
{
  "success": true,
  "tokensFreed": 650,
  "agent": "dev",
  "file": "patterns.md"
}
```

Response (400 - invalid input):
```json
{
  "success": false,
  "error": "Invalid sidecar file. Must be one of: patterns.md, gotchas.md, decisions.md"
}
```

Response (404 - sidecar not found):
```json
{
  "success": false,
  "error": "Sidecar file not found: .pennyfarthing/sidecars/dev/patterns.md"
}
```

### Implementation Notes

- **Path resolution**: Sidecars are in `.pennyfarthing/sidecars/` at project root (writable location, NOT node_modules)
- **Template paths**: Check node_modules/@pennyfarthing/core/pennyfarthing-dist/templates/sidecar/ or relative to Cyclist source
- **Agent name formatting**: Convert "dev" → "Dev", "tech-writer" → "Tech-Writer"
- **Cache invalidation**: After successful prune, clear module-level cache variable from 82-1
- **Error handling**: Return result objects {success, data?, error?} instead of throwing
- **Parallel execution in 82-1**: Use Promise.all with setImmediate wrappers to avoid blocking event loop (10 agents sequentially would block ~10-20s, parallel is ~2s)

### Prior Work Context

- MSSCI-12800: Component-level token tracking in prime JSON output
- MSSCI-12796: Tiered context injection system
- sidecar-health.sh: Existing CLI tool for sidecar health (50/50/40 line limits)

This epic exposes prime data and sidecar management through dedicated UI (dialog, API, React hook).

## TEA Assessment

**Tests Required:** Yes
**Reason:** API endpoint with input validation, file I/O, cache invalidation, and security (agent/file whitelisting)

**Test Files:**
- `packages/cyclist/tests/MSSCI-14463-sidecar-pruning-api.test.ts` — 18 tests, 9 AC groups

**Tests Written:** 18 tests covering 9 ACs
**Status:** RED (18 failing — all fail on "No POST /prune-sidecar route found on router")

**Test Groups:**
- AC1: POST /prune-sidecar route exists (1 test)
- AC2: Input validation — invalid agent, invalid file, missing fields, all valid agents, all valid files (6 tests)
- AC3: tokensFreed computation via char count / 4 (1 test)
- AC4: Template reading from pennyfarthing-dist/templates/sidecar/ (1 test)
- AC5: ${AGENT_NAME} replacement — simple, hyphenated, ux-designer (3 tests)
- AC6: Writes to correct sidecar path (1 test)
- AC7: Cache invalidation — GET cache cleared after successful prune (1 test)
- AC8: Response shape {success, tokensFreed, agent, file} (1 test)
- AC9: Error handling — 404 missing sidecar, 400 invalid agent, 400 invalid file (3 tests)

**Implementation notes for Dev:**
- Add POST `/prune-sidecar` handler to existing `createAgentLoadRouter` in `agent-load.ts`
- Tests mock `node:fs` (readFileSync, writeFileSync, existsSync) — implementation should use these
- Cache invalidation: set the module-level `cache = null` after successful prune
- Agent name formatting: title-case each hyphen-separated segment (dev→Dev, tech-writer→Tech-Writer, ux-designer→UX-Designer)
- Template path: resolve to `pennyfarthing-dist/templates/sidecar/{file}.template` relative to project dir
- Sidecar path: `.pennyfarthing/sidecars/{agent}/{file}` relative to project dir

**Handoff:** To Dev for implementation (GREEN phase)

## Dev Assessment

**Status:** GREEN (18/18 tests passing)
**PR:** #733 (pennyfarthing)

**Files changed:**
- `packages/cyclist/src/api/agent-load.ts` — Added POST /prune-sidecar handler (+70 lines)

**Implementation:**
- `router.post('/prune-sidecar')` validates agent against `PRIMARY_AGENTS` and file against `VALID_SIDECAR_FILES`
- Reads current sidecar via `fs.readFileSync`, reads template from `pennyfarthing-dist/templates/sidecar/{file}.template`
- `formatAgentName()` title-cases each hyphen segment, with `UPPERCASE_SEGMENTS` set for abbreviations like `ux` → `UX`
- Writes resolved template to `.pennyfarthing/sidecars/{agent}/{file}`
- Computes `tokensFreed = Math.floor((oldLen - newLen) / 4)`
- Sets `cache = null; cachedAtMs = 0` to invalidate GET cache
- Error responses: 400 (invalid input), 404 (missing sidecar)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | VERIFIED | Input whitelisting safe — agent/file validated against const arrays before any fs ops | `agent-load.ts:120,128` |
| 2 | VERIFIED | Path traversal impossible — `join()` only receives pre-validated whitelist values | `agent-load.ts:137,152` |
| 3 | VERIFIED | No user input reaches template regex — `$\{AGENT_NAME\}` replacement uses formatted whitelist value | `agent-load.ts:155` |
| 4 | VERIFIED | Cache invalidation correct — sets both `cache = null` and `cachedAtMs = 0` | `agent-load.ts:161-162` |
| 5 | VERIFIED | Error responses use consistent `{success: false, error}` shape | `agent-load.ts:121-123,129-131,141-143` |
| 6 | MEDIUM | Synchronous fs ops (`readFileSync`, `writeFileSync`, `existsSync`) block event loop — acceptable for local-only server, but note for future | `agent-load.ts:140,149,153,158` |
| 7 | VERIFIED | `express.json()` middleware mounted — POST body parsing confirmed | `server.ts:57` |
| 8 | VERIFIED | `formatAgentName` handles edge case: `UPPERCASE_SEGMENTS` Set for abbreviations | `agent-load.ts:16-22` |

**Tests:** 18/18 passing | **Regression:** 23/23 (82-1) passing | **Forbidden patterns:** None | **Type errors:** None

**PR #733 Status:** Merging to develop

**Handoff:** To SM for finish-story
