# ADR-0034: Post-Migration Architecture — Python Runtime with React GUI

**Status:** Superseded by [ADR-0039](0039-react-gui-removal-python-only.md)
**Date:** 2026-03-09
**Author:** Architect Agent (Paul Atreides)
**Context:** ADR-0022 (Python WheelHub) implemented, ADR-0028 (Python-First Install) accepted

> **Superseded (2026-03-11):** The React presentation layer this ADR documents was
> removed entirely two days after acceptance — see
> [ADR-0039: React GUI Removal](0039-react-gui-removal-python-only.md). The
> "React layer" sections below describe a state that no longer exists; they are
> retained as the historical record of the intermediate two-layer architecture.

## Context

With the completion of Epic 48 (Python WheelHub Migration), the Pennyfarthing architecture has crossed a fundamental boundary. Python is now the sole runtime for all server, CLI, and hook operations. TypeScript/React exists only for the browser GUI layer.

This ADR documents the current architecture, identifies remaining TypeScript that is legacy or duplicated, and updates the status of several related ADRs.

### Architecture Before (pre-Epic 48)

```
Claude Code CLI
    │
    ├── Hooks (Python) ──→ HTTP ──→ WheelHub (Node.js Express)
    │                                  ├── subprocess → pf (Python)
    │                                  ├── WebSocket broadcast
    │                                  └── OTLP receiver
    │
    ├── pf CLI (Python) ──→ Sprint, Jira, workflow, agents
    │
    └── GUI (React) ──→ WheelHub (Node.js) ──→ subprocess → pf (Python)
```

**Problems:** Dual runtime, circular delegation (Node→Python→Node), fragile build pipeline, 1.7MB bundle artifact.

### Architecture Now (post-Epic 48)

```
Claude Code CLI
    │
    ├── Hooks (Python) ──→ HTTP ──→ WheelHub (Python FastAPI)
    │                                  ├── direct import → pf modules
    │                                  ├── WebSocket broadcast (FastAPI)
    │                                  └── OTLP receiver (ported)
    │
    ├── pf CLI (Python) ──→ Sprint, Jira, workflow, agents
    │
    └── GUI (React) ──→ WheelHub (Python FastAPI) ──→ direct import → pf modules
```

**Single runtime for all server operations.** No subprocess delegation. No build pipeline for the server.

## Current Codebase Inventory

### Python (the runtime) — 373 .py files

| Directory | Purpose | Status |
|-----------|---------|--------|
| `pennyfarthing-dist/src/pf/` | CLI package root | Active |
| `pf/wheelhub/` | FastAPI server (1,726 lines) | Active — new |
| `pf/bikerack/` | TUI launcher, panel management | Active |
| `pf/hooks/` | Claude Code hooks (session, statusline, pre/post tool) | Active |
| `pf/sprint/` | Sprint YAML management | Active |
| `pf/jira/` | Jira integration (bidirectional sync) | Active |
| `pf/prime/` | Agent activation, persona loading | Active |
| `pf/brownfield/` | Codebase analysis (hotspots, deadcode, complexity) | Active |
| `pf/git/`, `pf/gate/`, `pf/workflow/` | Workflow engine, gates, handoffs | Active |
| `pf/benchmark/` | Peloton replay, scoring | Active |
| `pf/tests/` | Python test suite | Active |

### TypeScript/React (the GUI) — 325 .ts/.tsx files in core, 3 in cyclist

| Directory | Purpose | Status |
|-----------|---------|--------|
| `packages/core/src/public/` | React panel components (131 files) | **Active** — the GUI |
| `packages/core/src/workflow/` | Workflow engine (gate handling, session state, ~30 files) | **Active** — used by GUI |
| `packages/core/src/shared/` | Theme loader, skill search, portrait resolver (~15 files) | **Duplicated** — Python has canonical versions |
| `packages/core/src/benchmark/` | JobFair aggregator, scenario validator (~5 files) | **Active** — used by GUI |
| `packages/core/src/cli/` | Node CLI commands (doctor, init, theme, update, ~20 files) | **Legacy** — superseded by `pf` CLI (ADR-0028) |
| `packages/core/src/bmad/` | Story/epic parsers (~5 files) | **Legacy** — Python handles this |
| `packages/core/src/consultation/` | Tandem protocol (~3 files) | **Active** — used by GUI |
| `packages/core/src/jira/` | Jira epic creation (~2 files) | **Legacy** — Python `pf jira` is canonical |
| `packages/cyclist/src/` | React entry points (3 files) | **Active** — minimal |

### Identified Dead/Legacy TypeScript

| Component | Files | Reason | Action |
|-----------|-------|--------|--------|
| `packages/core/src/cli/` | ~20 | `pf` Python CLI is the primary interface (ADR-0028) | Remove or deprecate |
| `packages/core/src/bmad/` | ~5 | Python sprint/story management is canonical | Remove |
| `packages/core/src/jira/` | ~2 | `pf jira` Python commands are canonical | Remove |
| `packages/core/src/shared/theme-loader.ts` | 1 | Python `themes.py` is canonical (MEMORY.md) | Keep for GUI, mark as consumer |
| `packages/core/src/shared/skill-search.ts` | 1 | Python skill discovery is canonical | Keep for GUI, mark as consumer |

## Decision

### 1. Document the two-layer architecture

**Python layer** (runtime): Everything that runs on the server, in hooks, or via CLI. This is the single source of truth for all business logic.

**React layer** (presentation): Browser GUI components that consume WheelHub's HTTP/WebSocket APIs. No business logic — pure presentation and client-side state.

### 2. Node.js role is now build-time only

Node.js is required for:
- `pnpm run build` — TypeScript compilation + Vite React build
- `pnpm run dev` — GUI development server with HMR
- `pnpm test` — TypeScript test suite

Node.js is **not** required for:
- Running the WheelHub server (Python uvicorn)
- Running hooks (Python)
- Running the CLI (`pf`)
- BikeRack TUI mode

### 3. ADR-0030 (BikeRack Extraction) needs revision

ADR-0030 planned to extract BikeRack from Cyclist by moving code from `packages/core/src/server/` to `packages/bikerack/`. That directory no longer exists — the server is Python. The extraction concept has three possible futures:

**Option A: No extraction needed.** Cyclist is already almost empty (3 files). BikeRack's server logic is in Python (`pf/wheelhub/`). The React components live in core. The package boundary ADR-0030 wanted already exists — it's the Python/TypeScript boundary.

**Option B: Consolidate React into one package.** Merge `packages/cyclist/` (3 files) into `packages/core/src/public/`. Cyclist as a separate package no longer carries its weight.

**Option C: Extract React panels into `packages/bikerack/`.** Keep the BikeRack extraction concept but scope it to the React layer only — panel components, workspaces, data sources. This is smaller than the original plan.

**Recommendation:** Option B for immediate simplification. The three Cyclist files are just React entry points that belong in core's public directory.

### 4. Legacy TypeScript cleanup path

The following can be removed in a future cleanup epic:
- `packages/core/src/cli/` — Dead since ADR-0028 made `pf` the CLI
- `packages/core/src/bmad/` — Python sprint management is canonical
- `packages/core/src/jira/` — Python Jira integration is canonical
- `packages/electron/` — Legacy, minimal use (noted in existing docs)

This is not urgent — the code isn't causing harm, just occupying space in the build.

## Consequences

### Positive

- **Clear mental model:** Python = runtime, React = GUI. No ambiguity.
- **Single runtime for operations:** `pip install pf` gives you everything except the GUI.
- **No build pipeline for the server:** Python source runs directly.
- **Simplified dependency graph:** GUI depends on Python WheelHub API, not on shared TypeScript libraries.

### Negative

- **Two test suites:** Python (`pytest`) and TypeScript (`node --test` + `vitest`). Both must pass.
- **Shared utilities exist in both languages:** Theme loader, skill search have Python and TypeScript implementations. The Python versions are canonical; TypeScript versions are consumers that may drift.
- **Build still requires Node:** The React GUI needs TypeScript compilation and Vite bundling. This is development-time only, not runtime.

### Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| TypeScript shared utilities drift from Python canonical | Medium | Document which implementations are canonical. Consider generating TS types from Python models. |
| Legacy TypeScript confuses contributors | Low | Mark legacy dirs with README.md files noting they're superseded. |
| GUI development requires understanding both stacks | Low | Clear boundary: Python developers never touch `packages/`, React developers never touch `pf/`. |

## Related

- [ADR-0022: Python WheelHub Replacement](../pennyfarthing/docs/adr/0022-python-wheelhub-replacement.md) — The migration this ADR documents the outcome of
- [ADR-0028: Python-First Installation](0028-python-first-installation.md) — Made `pf` the primary CLI
- [ADR-0030: BikeRack Package Extraction](0030-bikerack-package-extraction.md) — Needs revision (Proposed → Needs Revision)
- [ADR-0004: WheelHub Background Agent Coordination](0004-wheelhub-background-agent-coordination.md) — Original Node.js architecture (superseded by ADR-0022)
