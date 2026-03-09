---
story_id: "48-1"
jira_key: "MSSCI-16313"
epic: "MSSCI-16312"
workflow: "tdd"
---
# Story 48-1: FastAPI skeleton + OTLP receiver + launcher switch

## Story Details
- **ID:** 48-1
- **Jira Key:** MSSCI-16313
- **Workflow:** tdd
- **Points:** 3
- **Epic:** 48 — Python WheelHub Migration (MSSCI-16312)
- **Branch:** feat/48-1-fastapi-skeleton-otlp-receiver (pennyfarthing repo)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-09T12:22:14Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-09 | 2026-03-09T12:02:25Z | 12h 2m |
| red | 2026-03-09T12:02:25Z | 2026-03-09T12:08:33Z | 6m 8s |
| green | 2026-03-09T12:08:33Z | 2026-03-09T12:10:43Z | 2m 10s |
| verify | 2026-03-09T12:10:43Z | 2026-03-09T12:19:32Z | 8m 49s |
| review | 2026-03-09T12:19:32Z | 2026-03-09T12:22:14Z | 2m 42s |
| finish | 2026-03-09T12:22:14Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## SM Assessment

**Setup complete.** Story 48-1 is Phase 1 of the Python WheelHub Migration (ADR-0022).

- Jira MSSCI-16313 claimed and In Progress
- Branch `feat/48-1-fastapi-skeleton-otlp-receiver` created off develop in pennyfarthing/ repo
- Context document at `sprint/context/context-story-48-1.md` with full technical approach from ADR-0022
- Key files to port: `packages/core/src/server/server.ts`, `otlp-receiver.ts`
- Target location: `pennyfarthing-dist/src/pf/wheelhub/`
- New dependencies: fastapi, uvicorn, websockets

**Routing to Igor (TEA) for RED phase** — write failing tests for the FastAPI server skeleton and OTLP receiver before implementation.

### TEA (test design)

- No upstream findings during test design.

## TEA Assessment

**Tests Required:** Yes
**Reason:** New Python server module — all functionality needs test coverage

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_wheelhub_server.py` — 30 tests covering all 6 ACs

**Tests Written:** 30 tests covering 6 ACs

| Class | Tests | AC Coverage |
|-------|-------|-------------|
| `TestHealthEndpoint` | 2 | AC1 — health check returns {"status":"ok"} |
| `TestOTLPEndpoints` | 6 | AC2 — /v1/logs, /v1/metrics, /v1/traces + empty payloads |
| `TestPortFileLifecycle` | 4 | AC4 — write, cleanup, missing file, overwrite |
| `TestTokenStatsAggregation` | 5 | AC5 — parse metrics, ignore non-token, aggregate, initial zeros |
| `TestOTLPLogParsing` | 4 | AC5 — tool events, timestamps, empty, booleans |
| `TestLauncherSwitch` | 2 | AC3 — uses Python/uvicorn, not node |
| `TestDependencies` | 3 | AC6 — fastapi, uvicorn, pf.wheelhub importable |
| `TestEdgeCases` | 4 | Edge — missing attrs, missing sum, missing body, partial data |

**Status:** RED (failing — `ModuleNotFoundError: No module named 'pf.wheelhub'`)

**Key design decisions:**
- Tests import from `pf.wheelhub.app` (create_app, write_port_file, cleanup_port_file, get_server_command)
- Tests import from `pf.wheelhub.otlp` (parse_otlp_metrics, parse_otlp_logs, OTLPReceiver)
- OTLP payloads match exact format from Node.js `otlp-receiver.ts` — same JSON structure
- `OTLPReceiver` class expected for stateful token aggregation (vs module-level globals)
- Uses `starlette.testclient.TestClient` for HTTP endpoint testing

**Handoff:** To Ponder Stibbons (Dev) for GREEN phase — implement `pf.wheelhub` package

### TEA (test verification)

- **Improvement** (non-blocking): Module-level `_receiver = OTLPReceiver()` singleton in `app.py` is shared across all `create_app()` calls, creating test isolation risk. Consider moving instantiation inside `create_app()`. Affects `pennyfarthing-dist/src/pf/wheelhub/app.py` (receiver lifecycle). *Found by TEA during test verification.*
- **Improvement** (non-blocking): OTLP route handlers use `except Exception: pass` with no logging — errors are invisible. Consider adding `logging.debug` for observability. Affects `pennyfarthing-dist/src/pf/wheelhub/app.py` (error handling in /v1/* routes). *Found by TEA during test verification.*

### Reviewer (code review)

- **Improvement** (non-blocking): `process_logs()` returns parsed events but the `/v1/logs` route handler discards the return value — data flow dead end. Future stories should wire events to storage/broadcast. Affects `pennyfarthing-dist/src/pf/wheelhub/app.py` (line 35). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `parse_otlp_logs` only handles 3 of 7 OTLP value types (string, int, bool — missing double, array, kvlist, bytes). Acceptable for current scope but will need expansion. Affects `pennyfarthing-dist/src/pf/wheelhub/otlp.py` (lines 77-82). *Found by Reviewer during code review.*

### Dev (implementation)

- No upstream findings during implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/wheelhub/__init__.py` - Package init
- `pennyfarthing-dist/src/pf/wheelhub/app.py` - FastAPI app, health check, OTLP routes, port file ops, get_server_command()
- `pennyfarthing-dist/src/pf/wheelhub/otlp.py` - OTLP receiver: parse_otlp_metrics, parse_otlp_logs, OTLPReceiver class

**Tests:** 30/30 passing (GREEN)
**Branch:** feat/48-1-fastapi-skeleton-otlp-receiver (pushed)

**Handoff:** To Granny Weatherwax (Reviewer) for review

## TEA Verify Assessment

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 4

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | 2 high (test fixture, parametrize), 3 low (intentional port, TOKEN_FIELDS) |
| simplify-quality | 7 findings | 5 high (unused imports), 2 medium (singleton, error handling) |
| simplify-efficiency | 5 findings | 3 high (inline imports, fixture, unused imports), 2 medium (singleton, TestDependencies) |

**Applied:** 5 high-confidence fixes
- Removed unused imports: json, signal, textwrap, MagicMock, patch (test file)
- Removed unused import: Any (app.py)
- Extracted pytest `client` fixture for TestClient setup (eliminated 9x repetition)
- Parametrized 3 identical empty-payload tests into 1 parametrized test
- Moved inline imports to module level (27 inline imports → 3 module-level)

**Flagged for Review:** 3 medium-confidence findings
- Module-level `_receiver` singleton creates test isolation risk (app.py:21)
- Silent `except Exception: pass` in OTLP routes hinders debugging (app.py:37,46,55)
- TestDependencies class is redundant with other tests (test file) — kept for AC6 traceability

**Noted:** 3 low-confidence observations
- Cross-language port duplication (intentional per ADR-0022)
- TOKEN_FIELDS constant extraction opportunity (low priority at 4 fields)

**Regression Check:** 30/30 tests passing after simplify changes
**Overall:** simplify: applied 5 fixes

**Handoff:** To Granny Weatherwax (Reviewer) for review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**

1. **[VERIFIED]** Faithful port of Node.js `parseOTLPMetrics` — same overwrite semantics at `otlp.py:17-24`, same field mapping, same early returns. Confirmed against `packages/core/src/server/otlp-receiver.ts:292-314`.
2. **[VERIFIED]** `parseOTLPLogs` — same nested iteration, ns→ms timestamp conversion, attribute extraction at `otlp.py:54-87`. Matches TS source at line 329.
3. **[VERIFIED]** Security: `docs_url=None, redoc_url=None` at `app.py:26` disables auto-generated API docs. No Swagger/ReDoc exposure on internal server.
4. **[VERIFIED]** `get_token_stats()` returns shallow copy via `{**self._token_stats}` at `otlp.py:103` — prevents external mutation of internal state.
5. **[VERIFIED]** `get_server_command` uses `sys.executable` at `app.py:78` — ensures same Python interpreter launches uvicorn. Avoids PATH resolution issues.
6. **[MEDIUM]** Module-level `_receiver` singleton at `app.py:20` — shared across all `create_app()` calls. Tests currently safe because they test `OTLPReceiver` directly, not via HTTP endpoints for state. Latent issue for future tests. (Concur with TEA verify finding.)
7. **[MEDIUM]** Silent `except Exception: pass` at `app.py:36-38,45-47,54-56` — correct per OTLP spec (return 200 always) but zero observability. (Concur with TEA verify finding.)
8. **[LOW]** `process_logs` return value discarded at `app.py:35` — data flow dead end. Acceptable for skeleton, deferred to later stories.
9. **[LOW]** `parse_otlp_logs` handles only string/int/bool OTLP value types at `otlp.py:77-82`. Missing doubleValue, arrayValue, kvlistValue, bytesValue. Acceptable for current token-stats scope.
10. **[VERIFIED]** Tests: 30/30 passing, all 6 ACs covered, edge cases for missing attributes/body/sum/partial data. Clean fixture extraction by TEA verify.

**Data flow traced:** HTTP POST `/v1/metrics` → `request.json()` → `_receiver.process_metrics()` → `parse_otlp_metrics()` → `aggregate_token_stats()` → `_token_stats` dict. Safe — no user input reaches eval, exec, or shell commands.
**Pattern observed:** App factory pattern (`create_app()`) at `app.py:24` — standard FastAPI pattern, good for testing.
**Error handling:** `cleanup_port_file` correctly catches `FileNotFoundError` at `app.py:70-72`. OTLP routes catch `Exception` (broad but intentional per OTLP spec).

**No Critical or High issues. Code is correct for story scope.**

**Handoff:** To Captain Carrot Ironfoundersson (SM) for finish-story