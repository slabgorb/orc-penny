# ADR-0039: React GUI Removal — Python-Only Architecture

**Status:** Accepted
**Date:** 2026-03-11 (decision) · recorded retroactively 2026-05-27
**Author:** Architect Agent (Leonard of Quirm)
**Supersedes:** [ADR-0034: Post-Migration Architecture — Python Runtime with React GUI](0034-post-migration-architecture.md)

## Context

ADR-0034 (Accepted 2026-03-09) documented a **two-layer architecture**: a Python
runtime plus a React presentation layer (the browser GUI). It planned to prune
only *legacy* TypeScript (dead CLI/bmad/jira modules) while keeping the React
panels in `packages/core` and `packages/cyclist` as "Active — the GUI."

Two days later — **v13.0.0-alpha.1 (2026-03-11)** — the project removed the React
GUI and Electron app **entirely**: *"BREAKING: React GUI and Electron app removed
— all JavaScript/TypeScript application code removed; framework is now
Python-only."* The cleanup was finalized through the v13.1.x line ("GUI packages
removed", commit `bd292b7`; WheelHub/BikeRack renamed to Frame/TUI across the
framework).

This was a **breaking architectural reversal** of ADR-0034's central "React layer"
pillar, but it was never recorded as its own decision. The CHANGELOG entry cited
"(ADR-0034)" as the authority — incorrectly, since ADR-0034 argued to *keep* the
GUI. The decision was effectively orphaned. This ADR records it and corrects the
record (SOUL: *One Truth, One Place*; *Prove the Work*).

### Why the GUI was removed

> Rationale reconstructed from ADR-0034's own stated Negatives/Risks and the
> v13.0.0-alpha.1 CHANGELOG. ADR-0034 predicted exactly the costs that drove the
> removal.

The Python WheelHub → Frame (FastAPI) migration (ADR-0022) made the Node.js server
obsolete. Keeping React purely for presentation still imposed:

- **Two test suites** — `pytest` *and* `vitest`/`node --test`, both gating CI.
- **Canonical-logic drift** — TypeScript reimplementations (theme loader, skill
  search) that could silently diverge from the canonical Python (ADR-0034 listed
  this as a Medium risk).
- **A full Node/Vite build pipeline** — TypeScript compilation and Vite bundling
  required at build time for a layer that carried no business logic.

Consolidating to Python-only eliminated all three. The dashboard need was met by
the Frame TUI (Python/Textual) and IDE panels, which already consume the Frame API.

## Decision

1. **Remove all JavaScript/TypeScript application code** — the React GUI
   (`packages/core`, `packages/cyclist`), the Electron app, and the legacy TS
   CLI/bmad/jira modules. The `packages/` directory no longer exists.
2. **Python is the only language, at runtime and build time.** No Node, pnpm, or
   Vite is required for any framework operation, including the build.
3. **The dashboard surface is Frame** — the Frame TUI (Python/Textual) running
   alongside the Claude Code CLI, plus IDE sidebar panels via the Frame API. The
   WheelHub/BikeRack names are retired in favor of Frame/TUI.
4. **Themes are data, not packages.** The former TypeScript theme packages are now
   persona/theme definitions under `pennyfarthing-dist/personas/themes/`.

## Consequences

### Positive

- **One language, one runtime, one test suite** (`pytest`). No build pipeline.
- **Eliminates TypeScript↔Python drift** — the canonical Python implementations are
  now the *only* implementations.
- **Smaller install and simpler dependency graph** — no Node toolchain.
- **One truth, one place** for presentation: it lives in Python/Textual, not a
  parallel TS stack.

### Negative

- **No browser GUI.** Dashboards are terminal (TUI) and IDE only. Any future rich
  web UI is a greenfield effort that would consume the Frame API as a client.
- **Removed code lives only in git history** — archaeology requires checking out
  pre-removal commits.

### Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Docs continue to reference the removed GUI (`just gui`, browser dashboards) | High → realized | The doc sweep that prompted this ADR; this ADR is the canonical record |
| External consumers expect a browser GUI | Low | Frame TUI + IDE panels are the supported surfaces; document the migration |

## Related

- **Supersedes** [ADR-0034](0034-post-migration-architecture.md) — Post-Migration
  Architecture (Python Runtime with React GUI)
- [ADR-0022: Python WheelHub Replacement](../../pennyfarthing/docs/adr/0022-python-wheelhub-replacement.md)
  — the migration that obsoleted the Node server
- [ADR-0028: Python-First Installation](0028-python-first-installation.md)
- [ADR-0030: BikeRack Package Extraction](0030-bikerack-package-extraction.md) —
  moot once `packages/` was removed
- CHANGELOG `[13.0.0-alpha.1] - 2026-03-11` — the removal; its `(ADR-0034)`
  citation is corrected to point here

## Notes

- **Recorded retroactively** on 2026-05-27 to close an orphaned decision. The
  decision date (2026-03-11) is preserved above; the authoring date reflects when
  the gap was found and filled.
- **Known ADR-numbering debt (out of scope, tracked separately):** this repo
  carries number collisions (two `0034`, two `0026`), the index omits 0035–0038,
  and the orchestrator/framework ADR sequences share numbers for different
  decisions. Reconciling that requires a dedicated effort, not a drive-by here.
