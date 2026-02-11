# Product Requirements Document — RaceCoach (Stub)

**Status:** Stub — awaiting full PRD development
**Origin:** BikeRack PRD Appendix, Idea L (contributed by M. Pursifull, 2026-02-11)
**Source material:** `sprint/planning/bikerack-prd-ideas.md`, Idea L section + user stories US-L1, US-L2, US-L3

## Concept

RaceCoach is a workflow feedback and efficiency layer that observes the telemetry stream and surfaces actionable tips, warnings, or suggestions to the Claude Code operator. It advises; the rider decides.

## Why It Deserves Its Own PRD

RaceCoach is orthogonal to BikeRack — it's a coaching product, not a dashboard feature. It could run in Cyclist, BikeRack, or standalone. The three-tier source model (human-curated rules, behavioral linter, AI-driven) each have different effort/risk profiles that need independent scoping.

## Key Questions to Answer

- What is the minimum viable RaceCoach? (Likely: behavioral linter with 5-10 rules)
- Where does feedback surface? (BikeShow overlay, CLI status line, both?)
- Who authors the rules? (Operator, team lead, shared config?)
- How does the AI-driven tier avoid being annoying or wrong?
- Cost model for AI-driven coaching — separate API calls? On-device model?
- Privacy implications of team-visible coaching feedback
- How does it interact with capture/replay (Idea D)?

## Feedback Categories (from source)

1. Context window efficiency
2. Workflow step ordering
3. Persona suggestions
4. Agent action triggers
5. Document timing

## Dependencies

- Telemetry pipeline (exists in Cyclist, will exist in BikeRack MVP)
- No hard dependency on BikeShop/ShowRoom for basic operation
- ShowRoom integration (team-level coaching summary) requires Ideas B+E

## Illustrative User Stories (from source)

- **US-L1:** Behavioral linter tip about context window approaching crash threshold
- **US-L2:** Persona switch suggestion, dismissed by operator, feedback loop adapts
- **US-L3:** Team lead reviews coaching summary in ShowRoom, edits linter rules
