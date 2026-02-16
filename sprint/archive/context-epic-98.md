# Epic 98: Safe Install, Upgrade, and Namespace Isolation

**Jira:** MSSCI-14697
**ADR:** 0021
**Repo:** pennyfarthing

## Overview

Redesign the install/upgrade path to prevent data loss, automate post-update setup, add versioned migrations, namespace skills/commands with pf- prefix, and integrate sprint shard migration.

## Key Directories

- `pennyfarthing/packages/core/` — CLI: init, update, doctor, uninstall
- `pennyfarthing/pennyfarthing-dist/` — Published package (source of truth)
- `pennyfarthing/pennyfarthing_scripts/` — Python scripts (hooks, sprint, jira)
- `pennyfarthing/packages/cyclist/` — Visual terminal (Electron app)

## Stories

| ID | Title | Pts | Priority | Status |
|----|-------|-----|----------|--------|
| 98-1 | Version sentinel file and auto-update detection | 2 | P0 | backlog |
| 98-2 | Versioned migration runner infrastructure | 5 | P0 | backlog |
| 98-3 | Refactor update.ts inline migrations to migration files | 3 | P0 | backlog |
| 98-4 | Prefix built-in skills and commands with pf- | 5 | P1 | backlog |
| 98-5 | Sprint shard migration as versioned migration | 3 | P1 | backlog |
| 98-6 | Protective symlink pre-flight checks | 2 | P1 | backlog |
| 98-7 | Update agent definitions and docs for pf- skill refs | 2 | P2 | backlog |
| 98-8 | Fix Cyclist false-positive detection in CLI mode | 3 | P0 | in_progress |
