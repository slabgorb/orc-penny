# Epic 71: Codebase Awareness

**Jira:** PROJ-12709
**Status:** In Progress
**Total Points:** 8

## Overview

Users can see what files Claude modified, review diffs with syntax highlighting, and monitor their context usage. This epic is part of the Cyclist React migration, building React components for the VS Code extension.

## Stories

| ID | Title | Points | Status |
|----|-------|--------|--------|
| PROJ-12710 | FileTree Component | 2 | In Progress |
| PROJ-12711 | DiffViewer Component | 2 | Backlog |
| PROJ-12712 | ContextIndicator Component | 2 | Backlog |
| PROJ-12713 | ApprovalModal Component | 2 | Backlog |

## Technical Context

### Architecture

These components live in the Cyclist React package (`packages/cyclist/`) and integrate with the VS Code extension webview. They follow the established patterns from Epic 70 (Flexible Workspace).

### Key Files

- `packages/cyclist/src/public/components/` - Component directory
- `packages/cyclist/tests/` - Test files
- `packages/cyclist/src/public/App.tsx` - Main app entry

### Dependencies

- React 18
- VS Code Webview API
- Existing DockingWorkspace infrastructure from Epic 70

### Design Patterns

- Functional components with hooks
- TypeScript strict mode
- Vitest for testing
- CSS modules for styling

## Related Epics

- Epic 70: Flexible Workspace (provides DockingWorkspace foundation)
- Epic 65: Cyclist React Migration (overall migration effort)
