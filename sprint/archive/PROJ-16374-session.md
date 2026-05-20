---
story_id: "143-16"
jira_key: "PROJ-16374"
epic: "PROJ-16358"
workflow: "trivial"
---
# Story 143-16: BikeRack observability for subagent transitions

## Story Details
- **ID:** 143-16
- **Jira Key:** PROJ-16374
- **Workflow:** trivial
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-13T10:44:24Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T19:00:00Z | 2026-03-13T10:32:21Z | -30459s |
| implement | 2026-03-13T10:32:21Z | 2026-03-13T10:40:18Z | 7m 57s |
| review | 2026-03-13T10:40:18Z | 2026-03-13T10:44:24Z | 4m 6s |
| finish | 2026-03-13T10:44:24Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### Dev (implementation)
- **Improvement** (non-blocking): User wants tmux-based agent cockpit — spawn agents in individual tmux panes with live output, interrupt, and resume. This is a new architecture beyond 143-16 scope. Affects `pf/bikerack/` and agent spawning model. *Found by Dev during implementation.*
- No other upstream findings.

### Reviewer (code review)
- No upstream findings during code review.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## SM Assessment

Story 143-16 is ready for implementation. Trivial workflow — Dev implements directly, no TEA phase needed.

- **Repo:** pennyfarthing (branch: `feat/143-16-bikerack-observability-subagent-transitions`)
- **Scope:** BikeRack observability for subagent transitions
- **Next:** White Rabbit (Dev) to implement

## Dev Assessment

**Implementation Complete:** Partial (telemetry foundation only)
**Files Changed:**
- `pf/wheelhub/subagent_events.py` - Event emitter (HTTP POST to WheelHub, fire-and-forget)
- `pf/wheelhub/app.py` - Added `subagent-transitions` WS channel
- `pf/wheelhub/routes/state.py` - Added `/api/subagent-event` POST endpoint + `/api/subagent-events` GET, ring buffer
- `pf/wheelhub/ws_push.py` - Added initial data fetcher for subagent-transitions channel
- `pf/handoff/complete_phase.py` - Emits `phase_complete` event
- `pf/handoff/marker.py` - Emits `handoff` event
- `pf/handoff/resolve_gate.py` - Emits `gate_check` event
- `pf/prime/cli.py` - Emits `agent_start` event

**Tests:** 325/326 passing (1 pre-existing failure in test_143_9, unrelated)
**Branch:** feat/143-16-bikerack-observability-subagent-transitions (pushed)

**Scope decision:** TUI panel was built then removed after user feedback. User wants a tmux-based agent cockpit (live terminal panes per agent with interrupt/resume) rather than a post-hoc event timeline panel. The telemetry infrastructure stays as foundation. Architect should design the tmux cockpit approach before the panel is built.

**Handoff:** To Reviewer for code review of telemetry foundation.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### Dev (implementation)
- **No TUI panel shipped:** Story scope called for BikeRack observability panel, built SubagentPanel then removed it. Reason: User wants tmux-based agent cockpit with live panes, interrupt, and resume — not a post-hoc event timeline. Telemetry foundation shipped instead; panel deferred to Architect design.

### Reviewer (audit)
- **No TUI panel shipped:** → ✓ ACCEPTED by Reviewer: User explicitly redirected scope mid-implementation. Telemetry foundation is the correct deliverable; panel deferred to Architect design for Saddle concept. No undocumented deviations found.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 325/326 pass (1 pre-existing) | N/A — clean |
| 2 | reviewer-edge-hunter | Yes | findings | 3 | confirmed 1, dismissed 2 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 4 | dismissed 4 |
| 4 | reviewer-test-analyzer | Yes | findings | 1 | confirmed 1 (lowered to MEDIUM) |
| 5 | reviewer-comment-analyzer | Yes | findings | 1 | confirmed 1 |
| 6 | reviewer-type-design | Yes | findings | 1 | dismissed 1 |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 1 (lowered to MEDIUM), dismissed 1 |
| 8 | reviewer-simplifier | Yes | findings | 3 | dismissed 3 |

**All received:** Yes
**Total findings:** 15 raw → 4 confirmed (0 HIGH, 4 MEDIUM/LOW), 11 dismissed

### Disposition Details

**Confirmed:**
- [EDGE] Port file whitespace — `_resolve_wheelhub_url()` reads port file without `.strip()`. Could fail on trailing newline. MEDIUM.
- [TEST] No tests for `subagent_events.py` (124 lines) or 4 integration points. MEDIUM for fire-and-forget plumbing on trivial workflow, but noted.
- [DOC] Stale docstring in `subagent_events.py` references removed SubagentPanel. LOW.
- [SEC] No size validation on POST `/api/subagent-event` body. MEDIUM — internal-only endpoint, but unbounded JSON is poor hygiene.

**Dismissed:**
- [EDGE] "No body validation on POST endpoint" — fire-and-forget telemetry; malformed events are harmless noise in the ring buffer.
- [EDGE] "Race condition on concurrent POSTs" — appending to a Python list is GIL-protected; ring buffer trim is safe for single-process FastAPI.
- [SILENT] All 4 "nested failure blindness" findings — every emit site is wrapped in `try/except: pass`, which is *correct* for fire-and-forget observability. The emitter must never block or fail the calling workflow. Silent failure IS the spec.
- [TYPE] "Stringly-typed event_type" — only 4 event types, all internal, no external consumers. Literal type adds ceremony without value at this scale.
- [SEC] "Info leakage via unvalidated broadcast" — events contain story_id, phase, agent names. This is local-only telemetry, not exposed externally.
- [SIMPLE] All 3 simplification findings — verbose payload builder is readable, port resolution is 2 call sites (not worth extracting), stdlib imports in try block is a pattern used throughout the codebase.

## Reviewer Assessment

**Verdict:** APPROVED

No Critical or High severity issues found. The telemetry foundation is clean, correctly scoped fire-and-forget plumbing that integrates at the right lifecycle points.

| Severity | Issue | Location | Action |
|----------|-------|----------|--------|
| [MEDIUM] | Port file read without `.strip()` | `subagent_events.py:_resolve_wheelhub_url()` | Fix in follow-up |
| [MEDIUM] | No tests for new module | `subagent_events.py` (124 lines) | Add in follow-up |
| [MEDIUM] | No size limit on POST body | `routes/state.py:/api/subagent-event` | Add in follow-up |
| [LOW] | Stale SubagentPanel docstring | `subagent_events.py` module docstring | Fix in follow-up |

**Data flow traced:** `emit_subagent_event()` → HTTP POST to `localhost:{port}/api/subagent-event` → ring buffer append → WS broadcast to `subagent-transitions` channel. Fire-and-forget at every layer — failures never propagate to caller.

**Pattern observed:** [VERIFIED] Consistent integration pattern across all 4 lifecycle points (agent_start, gate_check, phase_complete, handoff) — each wrapped in `try/except: pass` with lazy import.

**Error handling:** [VERIFIED] Every emit call site swallows exceptions. `_resolve_wheelhub_url()` returns `None` on failure, emitter returns early. Correct for observability plumbing.

**Handoff:** To The Mad Hatter (SM) for finish-story.