# Story 48-2: Port core API routes to FastAPI (data proxy + state + analysis)

**Story ID:** 48-2
**Jira:** PROJ-16314
**Workflow:** tdd
**Phase:** finish
**Repos:** orchestrator,pennyfarthing
**Branch:** feature/48-2-port-core-api-routes-fastapi
**Assignee:** keithavery

## Story Context

Phase 2 of Epic 48 (Python WheelHub Migration, ADR-0022). Port the HTTP API routes from the Node.js Express server (`packages/core/src/server/`) to the Python FastAPI WheelHub server (`pennyfarthing-dist/src/pf/wheelhub/`). Story 48-1 created the FastAPI skeleton with health check, OTLP receiver, and port file management.

### Scope — Three Route Categories

**Data proxy routes** (~12 routes) — currently subprocess calls to `pf` CLI, become direct Python imports:
- `/api/persona` — persona loading
- `/api/story` — story context/parsing
- `/api/git` — git status, branches
- `/api/sprint` (stats) — sprint data
- `/api/context` — context usage
- `/api/theme-agents` — theme agent mapping
- `/api/mode` — mode detection
- `/api/identity` — identity info
- `/api/portrait` — portrait serving
- `/api/file-browser` (files) — file tree
- `/api/project-info` — project info

**State routes** (~8 routes) — file reads + in-memory state:
- `/api/settings` — contextual settings
- `/api/permissions` — grant management
- `/api/audit-log` — audit log entries
- `/api/todos` — web mode todos
- `/api/token-stats` — token usage stats
- `/api/telemetry` — telemetry config
- `/api/evaluation` — evaluation data
- `/api/spans` — enriched spans

**Analysis routes** (~6 routes) — subprocess calls to `pf debug` commands, become direct imports:
- `/api/hotspots` — code hotspot analysis
- `/api/dead-code` — stale/unused code
- `/api/complexity` — cyclomatic complexity
- `/api/dependencies` — dependency analysis
- `/api/health-score` — composite health score
- `/api/agent-load` — agent load analysis
- `/api/code-markers` — code markers

**Inline endpoints** (from server.ts, not separate routers):
- `/api/welcome` — welcome message broadcast
- `/api/bell-queue` — bell mode queue sync
- `/api/bell-consumed` — bell consumed broadcast
- `/api/pending-tool-input` — tool input forwarding
- `/api/hook-request` — hook approval routing

### Acceptance Criteria

1. All data proxy routes ported to FastAPI with direct Python imports (no subprocess)
2. All state routes ported with equivalent file I/O and in-memory management
3. All analysis routes ported with direct Python imports to `pf debug` modules
4. Inline endpoints (welcome, bell-queue, bell-consumed, pending-tool-input) ported
5. API response shapes are backward-compatible with Node.js server
6. Existing hooks that call WheelHub HTTP endpoints continue to work
7. Tests cover all ported routes

### Technical Notes

- Node.js source: `packages/core/src/server/api/*.ts` (~30 route files)
- Python target: `pennyfarthing-dist/src/pf/wheelhub/routes/` (new directory)
- Existing FastAPI app: `pennyfarthing-dist/src/pf/wheelhub/app.py` (from 48-1)
- Key advantage: data proxy routes that currently shell out to `pf` Python CLI can directly import the Python modules, eliminating subprocess overhead
- Feature branch includes 48-1 work (merged from `feat/48-1-fastapi-skeleton-otlp-receiver`)

### Key Reference Files

| File | Role |
|------|------|
| `pennyfarthing-dist/src/pf/wheelhub/app.py` | FastAPI app (extend with route mounts) |
| `pennyfarthing-dist/src/pf/wheelhub/otlp.py` | OTLP receiver (from 48-1) |
| `packages/core/src/server/server.ts` | Node.js Express app (route mounting reference) |
| `packages/core/src/server/api/index.ts` | All Node.js route exports |
| `packages/core/src/server/api/*.ts` | Individual route implementations |
| `docs/adr/0022-python-wheelhub-replacement.md` | Architecture decision |

### Out of Scope

- WebSocket channels and file watchers (story 48-3)
- Static file serving (portraits, React build, node_modules)
- Removal of Node.js server code (story 48-4)
- Plugin router loading

## Assessment

Story is well-scoped and builds directly on 48-1 infrastructure. The 48-1 feature branch has been merged into the 48-2 feature branch. The FastAPI skeleton, OTLP receiver, and test harness are in place. ADR-0022 Phase 2 is clearly documented. The Node.js route implementations are available as reference in `packages/core/src/server/api/`. Most data proxy and analysis routes are thin wrappers around Python `pf` CLI commands, so porting is straightforward — replace subprocess calls with direct imports. TDD workflow: TEA should write failing tests for each route category before Dev implements.

## TEA Assessment

**Tests Required:** Yes
**Reason:** All 7 ACs require route implementations that don't exist yet

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_wheelhub_routes.py` — 70 tests covering all route categories

**Tests Written:** 70 tests covering all 7 ACs
**Status:** RED (61 failing, 9 passing — failures are 404 Not Found because routes not mounted)

**Route coverage:**
- AC1 Data proxy: persona, story, git, context, theme-agents, mode, identity, project-info (16 tests)
- AC2 State: settings, permissions, audit-log, todos, token-stats, telemetry, evaluation, spans (28 tests)
- AC3 Analysis: hotspots, dead-code, complexity, dependencies, health-score, agent-load, code-markers (8 tests)
- AC4 Inline: welcome, bell-queue, bell-consumed, pending-tool-input, hook-request (5 tests)
- AC5 Backward compat: error shapes, JSON content-type, export formats (4 tests)
- AC6 Hook compat: health, OTLP, hook-request endpoints (3 tests)
- AC7 Registration: route prefix verification, no-subprocess assertions (3 tests)

**Implementation guidance for Dev:**
1. Create `pennyfarthing-dist/src/pf/wheelhub/routes/` package with modules: `data_proxy.py`, `state.py`, `analysis.py`, `inline.py`
2. Mount all route groups on the FastAPI app in `create_app()` under `/api/*` prefixes
3. Data proxy routes should directly import Python modules (persona, story, git, etc.) — NO subprocess
4. Analysis routes should directly import from `pf.hotspots`, `pf.deadcode`, `pf.healthscore` etc.
5. State routes need in-memory stores for permissions, todos, evaluation, spans, audit-log
6. Response shapes MUST match Node.js Express contracts (see test assertions)

**Handoff:** To Dev (Reverend Mother Gaius Helen Mohiam) for GREEN implementation

## Delivery Findings

<!-- Append findings below this line -->
### TEA (test design)
- **Gap** (non-blocking): No story context file at `sprint/context/context-story-48-2.md`. Session file has adequate context but formal context doc was not created by SM setup. Affects `sprint/context/` (create if needed for future reference). *Found by TEA during test design.*
- **Improvement** (non-blocking): The Node.js `portrait` and `file-browser` routes are in scope per session but have complex static-file and filesystem behaviors. Tests for these are lighter-touch — Dev should verify portrait serving works with real image files. Affects `pennyfarthing-dist/src/pf/wheelhub/routes/data_proxy.py`. *Found by TEA during test design.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/wheelhub/app.py` — mount all route groups on FastAPI app
- `pennyfarthing-dist/src/pf/wheelhub/routes/__init__.py` — routes package
- `pennyfarthing-dist/src/pf/wheelhub/routes/data_proxy.py` — persona, story, git, context, theme-agents, mode, identity, project-info
- `pennyfarthing-dist/src/pf/wheelhub/routes/state.py` — settings, permissions, audit-log, todos, token-stats, telemetry, evaluation, spans
- `pennyfarthing-dist/src/pf/wheelhub/routes/analysis.py` — hotspots, dead-code, complexity, dependencies, health-score, agent-load, code-markers
- `pennyfarthing-dist/src/pf/wheelhub/routes/inline.py` — welcome, bell-queue, bell-consumed, pending-tool-input, hook-request

**Tests:** 70/70 passing (GREEN) + 30/30 48-1 tests still passing
**Branch:** feature/48-2-port-core-api-routes-fastapi (pushed)

**Handoff:** To Leto II (The God Emperor) for review

### Dev (implementation)
- No upstream findings during implementation.

## TEA Verify Assessment

**Simplify Report**

**Teammates:** combined (single agent)
**Files Analyzed:** 5

| Teammate | Status | Findings |
|----------|--------|----------|
| combined | 12 findings | reuse: 4, quality: 2, efficiency: 1, dead-code: 5 |

**Applied:** 2 high-confidence fixes (dead imports in _get_git_info, unused body read in inline.py)
**Flagged for Review:** duplicate _get_project_dir across 3 files, duplicate layout handlers in state.py, repeated yaml imports
**Reverted:** 0

**Overall:** simplify: applied 2 fixes

### TEA (test verification)
- **Improvement** (non-blocking): `_get_project_dir()` is duplicated across data_proxy.py, state.py, analysis.py. Extract to routes/__init__.py. Affects `pennyfarthing-dist/src/pf/wheelhub/routes/`. *Found by TEA during test verification.*

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #1313 (merged to develop)
**Tests:** 100/100 passing (70 route + 30 server)
**Findings:** No blocking issues. Non-blocking duplication noted in delivery findings.

### Reviewer (code review)
- No upstream findings during code review.