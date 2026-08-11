---
story_id: "164-19"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 164-19: Frame OTLP + subagent-event handlers fail-loud: replace silent except-pass with logging

## Story Details
- **ID:** 164-19
- **Jira Key:** (none — Jira not enabled)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-19-frame-otlp-subagent-fail-loud
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T13:43:46Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T13:25:14+00:00 | 2026-08-11T13:26:01Z | 47s |
| red | 2026-08-11T13:26:01Z | 2026-08-11T13:33:08Z | 7m 7s |
| green | 2026-08-11T13:33:08Z | 2026-08-11T13:36:33Z | 3m 25s |
| review | 2026-08-11T13:36:33Z | 2026-08-11T13:43:46Z | 7m 13s |
| finish | 2026-08-11T13:43:46Z | - | - |

## Acceptance Criteria

This is a REFACTOR story: replace silent exception handlers with logging in the Frame FastAPI server's OTLP (OpenTelemetry) and subagent-event handlers.

### Silent Swallow Sites Identified

**OTLP handlers (pennyfarthing-dist/src/pf/frame/app.py):**
1. `app.py:201` — POST `/v1/logs` handler (`otlp_logs` function)
2. `app.py:214` — POST `/v1/metrics` handler (`otlp_metrics` function)
3. `app.py:225` — POST `/v1/traces` handler (`otlp_traces` function)

**Broadcast helper (pennyfarthing-dist/src/pf/frame/app.py):**
4. `app.py:70` — `broadcast()` function exception when sending WebSocket message

**Subagent event handler (pennyfarthing-dist/src/pf/frame/routes/state.py):**
5. `routes/state.py:538` — POST `/api/subagent-event` handler broadcast call

**Event emitter (pennyfarthing-dist/src/pf/frame/subagent_events.py):**
6. `subagent_events.py:35` — `_get_frame_url()` reading port file from `FRAME_PROJECT_DIR` env
7. `subagent_events.py:44` — `_get_frame_url()` reading port file from CWD
8. `subagent_events.py:123` — `emit_subagent_event()` HTTP POST send to Frame

### AC1: Logging replaces silent swallows

For each identified silent swallow site (8 total):
- Replace bare `except Exception: pass` with proper logging
- Use logger: `logging.getLogger("uvicorn.error")` (consistent with existing frame code in lifecycle.py)
- Log level: ERROR with full exception traceback via `exc_info=True`
- Control flow preserved: do NOT change whether handlers crash the server (they don't) — handler MUST continue, but MUST LOG
- Example pattern:
  ```python
  import logging
  logger = logging.getLogger("uvicorn.error")
  try:
      # handler code
  except Exception:
      logger.error("Failed to ingest OTLP metrics", exc_info=True)
      # continue (e.g., return JSONResponse with partialSuccess)
  ```

### AC2: Test coverage — one test per site

For each of the 8 swallow sites, write a pytest test that:
- Injects a failure into the handler (e.g., malformed JSON, mocked exception)
- Verifies a log record at ERROR level is emitted with the exception info
- Verifies control flow is preserved (e.g., handler returns HTTPResponse, doesn't crash)

Test file: `pennyfarthing-dist/src/pf/tests/test_164_19_frame_fail_loud.py`

Example structure:
```python
def test_otlp_logs_handler_logs_on_exception(caplog):
    """AC2: POST /v1/logs logs exception on JSON decode failure."""
    client = TestClient(create_app())
    with caplog.at_level(logging.ERROR):
        response = client.post("/v1/logs", data="{invalid json}")
    assert response.status_code == 200  # Handler doesn't crash
    assert any("Failed to ingest OTLP logs" in rec.message for rec in caplog.records)
```

### AC3: Logger output routable to .session/frame.log

Confirm that log records from `logging.getLogger("uvicorn.error")` reach `.session/frame.log` when Frame is launched via `pf frame start`.

## Delivery Findings

No upstream findings.

## Design Deviations

No deviations — spec is straightforward.

## Sm Assessment

**Stage:** setup exit

All acceptance criteria are well-defined:
1. 8 identified silent swallow sites ready for refactor
2. Logging approach chosen (uvicorn.error logger, ERROR level)
3. Control flow contract clear: don't crash the server, but log
4. Test pattern established

**Handoff:** To TEA for red phase

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_164_19_frame_fail_loud.py` — one test class per swallow site; each asserts (a) an ERROR record on logger `uvicorn.error` carrying `exc_info`, and (b) the existing control-flow contract still holds.

**Tests Written:** 9 tests covering all 8 sites (AC1 + AC2; `/v1/metrics` has 2 — malformed body and parser raise)
**Status:** RED — all 9 fail at the same assertion (`no ERROR record on 'uvicorn.error'`, test helper line 93). Every control-flow assertion already passes today, so the only missing behavior is the logging.

**Per-site notes (failure injection -> control-flow contract pinned):**
| # | Site | Injection | Control-flow assertion |
|---|------|-----------|------------------------|
| 1 | `app.py` POST `/v1/logs` | malformed JSON body | 200 + `{"partialSuccess": {}}` |
| 2 | `app.py` POST `/v1/metrics` | malformed JSON body; separately `parse_otlp_metrics` raises RuntimeError | 200 + `{"partialSuccess": {}}` |
| 3 | `app.py` POST `/v1/traces` | malformed JSON body | 200 + `{"partialSuccess": {}}` |
| 4 | `app.py` `broadcast()` | stub client `send_text` raises RuntimeError | no raise; healthy client still receives; failing client still pruned from `_ws_clients` |
| 5 | `routes/state.py` POST `/api/subagent-event` | `app.broadcast` patched non-awaitable -> `ensure_future` TypeError | 200 `{"success": True}`; event still in ring buffer via GET `/api/subagent-events` |
| 6 | `subagent_events._get_frame_url` (FRAME_PROJECT_DIR) | `.frame-port` exists but `read_text` raises OSError | returns `None`, does not raise |
| 7 | `subagent_events._get_frame_url` (CWD) | same, cwd port file | returns `None`, does not raise |
| 8 | `subagent_events.emit_subagent_event` | `urllib.request.urlopen` raises ConnectionRefusedError | returns `{"success": False, "error": "Failed to reach Frame"}` |

**GREEN pre-verified:** temporary throwaway logging was applied to the 3 source files, all 9 tests passed, then the instrumentation was reverted (`git checkout`) — tests are back to RED and no source file is modified. Working tree contains only the test file.

**Regression check:** `test_frame_server.py`, `test_frame_routes.py`, `test_frame_websocket.py`, `test_164_16_*` -> 213 passed alongside the 9 new failures.

**Notes for Dev:**
- Sites 6/7 have *different indentation* on their `except Exception: pass` blocks — a blind single-occurrence replace patches only site 6. Patch both.
- AC3 (`.session/frame.log` routing) is not unit-testable here; it follows from using `uvicorn.error`, which uvicorn's own handler already writes to the frame log. No test written for AC3 — verify manually or leave to Reviewer.
- Log message wording is Dev's choice; tests assert level, logger name, `exc_info`, non-empty message, and the exception type.

**Handoff:** To Dev

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/app.py` — added module-level `_logger = logging.getLogger("uvicorn.error")`; ERROR + `exc_info=True` at sites 1-4 (`/v1/logs`, `/v1/metrics`, `/v1/traces`, `broadcast()`). Broadcast still prunes dead sockets; routes still return `{"partialSuccess": {}}` with 200.
- `pennyfarthing-dist/src/pf/frame/routes/state.py` — added `logging` import + module-level `_logger`; site 5 (`POST /api/subagent-event` broadcast dispatch) logs then still returns `{"success": True}` with the event already in the ring buffer.
- `pennyfarthing-dist/src/pf/frame/subagent_events.py` — added `logging` import + module-level `_logger`; sites 6, 7 (both port-file reads, at their two different indentation levels) and site 8 (HTTP POST to Frame). Site 6 still falls through to the CWD source, site 7 still returns `None`, site 8 still returns `{"success": False, "error": "Failed to reach Frame"}`.

No control flow changed at any site — logging only.

**Tests:** 9/9 passing in `test_164_19_frame_fail_loud.py` (GREEN), including the two distinct site-6/site-7 tests. Regression sweep `-k "frame or subagent or 164_16 or 164_19 or state"`: 840 passed, 0 failed.

**Branch:** `feat/164-19-frame-otlp-subagent-fail-loud` (pushed, commit `119b36a7e`, GPG signed)

**Notes:** AC3 (`.session/frame.log` routing) not unit-tested — follows from using the `uvicorn.error` logger, whose handler uvicorn already points at the frame log. Left for Reviewer to spot-verify.

**Handoff:** To Reviewer

## Subagent Results

**All received:** Yes

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | Clean | 9/9 pass; asyncio_mode=AUTO confirmed; async test runs genuinely; no code smells | Confirmed |
| 2 | reviewer-edge-hunter | Yes | Findings | Site 8 stale-port-file → ERROR spam + 2s timeout per call; empty port file yields malformed URL; sites 6/7 guarded correctly | [MEDIUM] stale-port flagged; [LOW] empty-port noted |
| 3 | reviewer-silent-failure-hunter | Yes | Findings | 5 remaining `except: pass` in state.py not covered by story (lines ~62, ~116, ~149, ~183, ~506); site 8 over-logging concern dismissed (gated behind URL resolution) | [MEDIUM] out-of-scope gaps noted; story scope confirmed correct |
| 4 | reviewer-test-analyzer | Yes | Clean | asyncio_mode=AUTO; all 9 tests exercise real assertions; RED/GREEN verified by TEA | Confirmed |
| 5 | reviewer-comment-analyzer | — | Not dispatched | Logging refactor; comments minimal and accurate | Not needed |
| 6 | reviewer-type-design | — | Not dispatched | No new types introduced | Not needed |
| 7 | reviewer-security | Yes | Findings | OTLP exc_info embeds JSONDecodeError fragments from input; pre-existing CORS wildcard; path in log message at site 6 | [LOW] info-leakage, localhost-only tool, no action required |
| 8 | reviewer-simplifier | — | Not dispatched | Mechanical one-for-one substitution; no complexity concerns | Not needed |
| 9 | reviewer-rule-checker | Yes | Pass | All edits under `pennyfarthing-dist/` only — no `.pennyfarthing/` symlink touches; both commits GPG-signed (G); subjects `refactor(164-19):` and `test(164-19):`; branch base is develop; test file named `test_164_19_frame_fail_loud.py` in `src/pf/tests/` — matches suite convention | All rules pass |

## Reviewer Assessment

**Verdict:** APPROVED

**Specialist synthesis:** [DOC] comments minimal and accurate — module-level logger comment matches lifecycle.py pattern; [EDGE] stale `.frame-port` after Frame crash causes ERROR spam + 2s timeout; empty port file yields malformed URL; [RULE] all edits under `pennyfarthing-dist/`, no symlink touches, both commits GPG-signed, format correct, test naming convention followed; [SEC] OTLP `exc_info=True` embeds JSONDecodeError input fragments in frame.log — localhost-only tool, no action required; [SILENT] 5 remaining `except: pass` in `state.py` outside story scope (~62, ~116, ~149, ~183, ~506); [SIMPLE] mechanical 1-for-1 substitution — no added complexity; [TEST] 9/9 real assertions verified; asyncio_mode=AUTO is library default not configured — unpinned fragility risk at site 4; [TYPE] no new types introduced; all pre-existing type contracts preserved.

**Data flow traced:** Malformed OTLP body → `request.json()` raises JSONDecodeError → caught by `except Exception:` → `_logger.error("Failed to ingest OTLP logs payload", exc_info=True)` → falls through → `return JSONResponse({"partialSuccess": {}})`. Safe because the return statement is outside the try block and executes unconditionally.

**Pattern observed:** Module-level `_logger = logging.getLogger("uvicorn.error")` at `app.py:26`, `routes/state.py:22`, `subagent_events.py:20` — consistent with existing `lifecycle.py` pattern. All three files now share the same logger identity.

**Error handling:** All 8 sites preserve the original continuation. Broadcast still appends to `dead` list after logging (`app.py:80`). OTLP routes still return `{"partialSuccess": {}}` with 200. `emit_subagent_event` still returns `{"success": False, "error": "Failed to reach Frame"}`. `_get_frame_url` still falls through to CWD or returns None.

**Observations:**

1. [MEDIUM] asyncio_mode=AUTO is the pytest-asyncio 1.3.0 **library default**, not a configured project value. No `[tool.pytest.ini_options]` section exists in `pyproject.toml`; no `asyncio_mode` entry appears anywhere. `TestBroadcastFailLoud.test_send_failure_is_logged_and_client_pruned` runs correctly today, but a future `asyncio_mode = "strict"` addition (likely when someone notices the missing config entry) would silently vacuate this test — the coroutine would be returned but never awaited, all assertions skipped, site 4 would lose all coverage. Two sibling test files (`test_155_14_*`, `test_155_5_*`) have inline comments falsely claiming this setting is in pyproject.toml. Fix: add `[tool.pytest.ini_options]` with `asyncio_mode = "auto"` to pyproject.toml. Not a blocker for this story (fix is a one-liner, arguably belongs in a separate hygiene chore), but flagged as medium risk.

2. [VERIFIED GOOD] Sites 6/7 are protected by `is_file()` guards before `read_text()`. Normal "Frame not running" (no port file) never reaches the except block. ERROR only fires on a genuine TOCTOU race or permission error — appropriate.

3. [VERIFIED GOOD] Site 8 (`emit_subagent_event`): early return `if not url: return {"success": False, "error": "Frame not running"}` at `subagent_events.py:90–91` handles the normal no-Frame case silently. The ERROR block is only reached when a port file existed and was readable, but the POST failed — that IS a genuine unexpected error.

4. [MEDIUM] Site 8 stale-port scenario: if Frame crashed without cleaning up `.frame-port`, `_get_frame_url()` returns a URL, and every subsequent agent handoff blocks 2s then logs ERROR. The docstring "silently returns {success: False}" implicitly covers this case in user expectation but the implementation does not. Post-story improvement: catch `urllib.error.URLError`/`socket.timeout` specifically and demote to WARNING or DEBUG, reserving ERROR for unexpected exception types. Not a blocker — the PR is strictly better than the all-silent baseline.

5. [MEDIUM] Site 4 (broadcast): WebSocket client disconnection is semi-expected during normal TUI shutdown (browser tab closed, pane killed). ERROR level may produce benign noise during session teardown. AC explicitly requires ERROR; flagged for future review. Not a blocker.

6. [MEDIUM] `state.py` has 5 remaining `except: pass` sites (lines ~62, ~116, ~149, ~183, ~506) outside this story's scope, the most structurally inconsistent being `post_benchmark_phase` (~506) which mirrors the `post_subagent_event` pattern that was fixed. Out-of-scope; recommend a follow-on chore.

7. [LOW] Empty `.frame-port` file (whitespace only) returns malformed URL `"http://127.0.0.1:"`. No guard between `strip()` and URL construction. Surfaces at site 8 as a misleading "Failed to POST" ERROR rather than a port-file-malformed diagnostic. Note only.

8. [LOW] OTLP `exc_info=True` causes `json.JSONDecodeError` to embed input fragments in `frame.log`. Low risk for a localhost-only tool, but OTLP payloads carry agent telemetry. No action required.

**AC3 spot-verification:** `logging.getLogger("uvicorn.error")` is the same logger uvicorn configures with its file handler during `pf frame start` (confirmed in `lifecycle.py`). Records from all three modules will land in `.session/frame.log` without additional configuration. AC3 is satisfied by construction.

**Design Deviations:** None declared; none found.

**Handoff:** To SM for finish-story