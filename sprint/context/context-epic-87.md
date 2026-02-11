# Epic 87: Repo Topology & Agent Spatial Awareness

**Jira:** MSSCI-14784
**Repo:** pennyfarthing
**Priority:** P1

## Description

Extend repos.yaml with ownership boundaries, never-edit zones, symlink mappings, UI layer identification, and rendering context. This becomes the spatial awareness manifest every agent loads at startup, preventing wrong-file/wrong-repo/wrong-layer errors.

The #1 friction category (25 incidents) in the Insights report is agents targeting the wrong file or repo. A machine-readable topology eliminates guesswork: agents know which repo owns which concerns, where UI components live vs CLI, and what paths are off-limits.

Extends existing repos.yaml rather than creating a new file.

## Stories

| ID | Title | Pts | Status |
|----|-------|-----|--------|
| 87-1 | Extend repos.yaml schema with ownership and boundaries | 2 | in_progress |
| 87-2 | Wire topology into agent prime context | 2 | planning |
| 87-3 | Add topology validation to pre-edit guide | 1 | planning |

## Key Files

- `.pennyfarthing/repos.yaml` — current repos config (symlinked from pennyfarthing-dist)
- `pennyfarthing/pennyfarthing-dist/repos.yaml` — source of truth
- `pennyfarthing/pennyfarthing-dist/scripts/core/` — agent scripts that load context
- `pennyfarthing/pennyfarthing-dist/guides/` — behavior guides
