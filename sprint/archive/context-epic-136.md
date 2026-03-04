# Epic 136: Post-install reliability — fix consumer-facing bugs from Python-first migration

## Overview

Umbrella epic for consumer-facing bugs surfaced after the Python-first migration (ADR-0028). Covers PATH resolution, WheelHub monorepo assumptions, init/doctor filtering, TUI fixes, sprint tooling bugs, and MCP tool integrations. Stories are loosely related by "things that broke or are missing post-migration" rather than a unified architecture.

**Priority:** P1
**Repo:** pennyfarthing
**Stories:** 20 (56 points)

## Background

The Python-first migration (ADR-0028) replaced shell scripts with a Python CLI (`pf`) and restructured distribution layout. This surfaced ~30 consumer-facing bugs across two repos. Epic 136 groups the fixes into thematic clusters:

- **PATH/discovery** (136-1, 136-13): Hook commands fail silently because `pf` isn't on subprocess PATH
- **WheelHub** (136-2, 136-6, 136-7, 136-8, 136-10): Server assumes monorepo layout, crashes on pip/pipx/uv installs
- **Init/doctor** (136-3, 136-9, 136-11): Prefix filtering and missing search paths in distributed layout
- **TUI** (136-4, 136-5): Color constants and data pipeline fallbacks
- **Sprint tooling** (136-14, 136-15, 136-18): Status display bugs, missing review status
- **Workflow/setup** (136-12, 136-16, 136-17): CLI gaps, phase naming, missing recipes
- **MCP integrations** (136-19, 136-20): Context7 and Perplexity tool integration for agents

## Technical Architecture

No unified architecture — each story cluster has its own technical approach. See individual story context documents for architectural details.

## Cross-Epic Dependencies

**Depends on:**
- ADR-0028 (Python-first installation) — the migration that created these bugs

**Depended on by:**
- Epic 137 (Stepped workflow modernization) — clean install path required before workflow upgrades
