# ADR-0042: Web GUI Resurrection — Browser Client of the Frame API

**Status:** Accepted
**Date:** 2026-08-07
**Author:** PM (Lord Vetinari) / Architect review
**Amends:** [ADR-0039: React GUI Removal — Python-Only Architecture](0039-react-gui-removal-python-only.md)

- [ ] **Story 165-12 complete** — run `pf sprint story complete 165-12`

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
