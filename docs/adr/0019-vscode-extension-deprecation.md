# ADR 0019: VS Code Extension Deprecation

## Status

Accepted

## Date

2026-02-02

## Context

Pennyfarthing had two UI surfaces for agent interaction:

1. **Cyclist** - Electron-based terminal wrapper with React UI
2. **VS Code Extension** - Chat participant using VS Code's Chat API

The VS Code extension was developed in Sprint 12 across two epics:
- PROJ-12042: VS Code Extension for Pennyfarthing (26 points)
- PROJ-12122: VS Code Extension UX/UI Pass (12 points, 6 cancelled)

During Sprint 12, the Cyclist React migration delivered significantly better UX:
- Full control over message rendering and streaming
- Custom panels for workflow, sprint, and agent status
- Flexible workspace with dockable panels
- Tiered context injection (84% token savings)
- Theme-aware subagent display

Meanwhile, the VS Code extension faced limitations:
- Chat API constraints on message formatting
- Limited control over streaming behavior
- No custom panel support (sidebar only)
- Duplicate maintenance effort for features already in Cyclist

## Decision

Deprecate and remove the VS Code extension entirely.

**Removed:**
- `pennyfarthing/packages/vscode-extension/` directory
- All source code (19 files), tests (22 files), and configuration
- Package definition `pennyfarthing-vscode`

**Preserved:**
- Historical session files in `sprint/archive/` for reference
- ADR-0011 (Reflector Marker Consolidation) remains valid for Cyclist
- Epic context files preserved for historical documentation

## Consequences

### Positive
- Reduced maintenance burden (one UI surface instead of two)
- Simplified monorepo structure (3 packages instead of 4)
- Development focus concentrated on Cyclist improvements
- No compatibility testing between two different UI patterns

### Negative
- Users who prefer VS Code integration lose that option
- 38 points of Sprint 12 work effectively deprecated
- Some architectural patterns (WheelHub adapter, chat participant) not reusable

### Neutral
- Reflector marker system remains in @pennyfarthing/shared (used by Cyclist)
- WebSocket-based communication patterns documented for future reference

## References

- Sprint 12 Retrospective: `sprint/archive/sprint-12-retro.md`
- Original VS Code Epic: PROJ-12042
- UX Polish Epic: PROJ-12122
- Cyclist React Migration: epic-69
