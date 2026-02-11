# Product Requirements Document — TeamGear (Stub)

**Status:** Stub — awaiting full PRD development
**Origin:** BikeRack PRD Appendix, Idea M (contributed by M. Pursifull, 2026-02-11)
**Source material:** `sprint/planning/bikerack-prd-ideas.md`, Idea M section + user stories US-M1, US-M2, US-M3

## Concept

TeamGear is a shared file "drive" between two or more Claude Code sessions. It provides a common surface for skills, workflows, knowledge bases, RAG sources, commands, and documents — without involving any shared control of the AI sessions themselves.

TeamGear is NOT Tandem (Idea N). It is not co-work, not agent bridging, not input/output sharing. It is a shared filing cabinet.

## Why It Deserves Its Own PRD

TeamGear is completely independent of BikeRack — it doesn't require a dashboard at all. It's a session-to-session concern with its own set of hard problems: sync mechanism, conflict resolution, access control, security. It also serves as the foundation layer for Tandem (Idea N) if that ever moves forward.

## Key Questions to Answer

- Backing mechanism: git-backed with fast path, lighter file sharing, or hybrid?
- How does a session discover available TeamGear sets? Config file? Registry?
- Conflict resolution: automerge, last-write-wins, prompt the operator?
- How does TeamGear interact with CLAUDE.md and per-project configs?
- Propagation latency requirements — seconds? Sub-second?
- Can sessions pin to a specific version of a shared skill/workflow?
- Security model for secrets (API keys, credentials) at rest and in transit
- CLI interface: `/gear sync`, `/gear status`, `/gear add`?

## What Can Be Shared

1. **Skills** — slash commands, skill definitions, prompt templates
2. **Workflows** — workflow definitions, stage configs, gate criteria
3. **Knowledge** — reference documents, architecture docs, runbooks
4. **RAG sources** — indexed document sets for session queries
5. **Commands** — shared aliases, macros, composite commands
6. **Documents** — working documents, specs, design docs, any co-referenced file

## Dependencies

- No dependency on BikeRack, BikeShop, or ShowRoom
- ShowRoom could display TeamGear status (which sessions connected, last sync, conflicts) but this is optional
- Tandem (Idea N) depends on TeamGear as its base layer

## Illustrative User Stories (from source)

- **US-M1:** Shared skill propagation — Keith creates `/validate-schema`, Amir's session picks it up within seconds
- **US-M2:** Shared knowledge base — team ADRs, API runbook, and RAG-indexed design docs available to all connected sessions
- **US-M3:** Conflict on a shared workflow — two concurrent edits detected, conflict surfaced, manual resolution, merge propagated
