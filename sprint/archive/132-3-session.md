# Story 132-3: Create What Pennyfarthing Does Reference Card

**Story ID:** 132-3
**Jira:** (none)
**Points:** 2
**Workflow:** agent-docs
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** (none yet)

## Acceptance Criteria

(None specified in epic)

## Context

Create a reference card that explains what Pennyfarthing does. This is part of the Developer Discovery & Onboarding epic (Epic 132).

**Type:** feature
**Priority:** P2
**Status:** in-progress

## Implementation Assessment (Orchestrator — implement)

**Files created:**
- `pennyfarthing-dist/guides/what-is-pennyfarthing.md` — Reference card (~85 lines). Covers three pillars, workflow loop, key concepts glossary, entry points, display modes, what-it-is-not section, and file layout.

**Files modified:**
- `pennyfarthing-dist/commands/pf-help.md` — Added link to reference card in quick-start section.

**Design decisions:**
- Placed in `guides/` alongside other component docs (not a standalone README or top-level doc)
- Under 100 lines, table-heavy, no prose walls — optimized for scanning
- "What Pennyfarthing Is NOT" section sets expectations and reduces confusion
- Glossary covers all codenames (BikeLane, BikeRack, Cyclist, WheelHub, TirePump, etc.)

**Ready for Tech Writer review.**

## Review Assessment (Tech Writer — review)

**Verdict: APPROVED**

Reviewed against documentation quality checklist. Structure is clean, BikeLane-centric as requested, scannable in under 60 seconds. Fixed one minor issue (`/trivial` → `trivial` — it's a workflow name, not a slash command). Help file cross-link is correct. Ready for SM to finish.