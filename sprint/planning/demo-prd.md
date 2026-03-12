---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
inputDocuments: []
documentCounts:
  briefs: 0
  research: 0
  brainstorming: 0
  projectDocs: 0
workflowType: 'prd'
classification:
  projectType: developer_tool
  domain: general
  complexity: medium
  projectContext: brownfield
---

# Product Requirements Document — Story Demo Artifact Generator

**Author:** Keith Avery
**Date:** 2026-03-12
**Status:** Draft

## Executive Summary

Every completed story should produce a presentation-ready demo artifact — automatically, with zero developer effort. The artifact explains what changed, why it matters, and why this engineering approach was chosen, written at ELI5 level for non-technical management audiences.

**Problem:** When engineering teams deliver technical stories, someone must translate the work into language management understands. This translation is manual, time-consuming, and happens under meeting pressure. The burden falls on the engineering lead, who must review every story against its spec and prepare a demo — for every story, every meeting.

**Solution:** A Pennyfarthing framework extension that auto-generates demo artifacts on story completion. The system collects story signals (ACs, PR diff, commits, session context, review findings), classifies the story type, and produces the appropriate artifact: slide decks with screenshots for UI work, architecture diagrams for backend work, and demo scripts for all story types. The developer reviews before handoff; the boss presents without preparation.

**Differentiator:** Classification-based format selection — the system decides the right artifact format per story type, not a one-size-fits-all template. Backend stories get diagrams and narratives, not screenshot attempts. UI stories get Playwright captures and click-by-click demo scripts.

**Target users:** Pennyfarthing consumer projects. Any PF-managed project gets this capability.

## Success Criteria

### User Success

- Every completed story produces a demo artifact with zero developer effort
- Artifacts explain what changed, why it matters, and why this approach — ELI5 level
- Presenter can walk into a meeting and present directly without preparation
- Non-technical audience understands engineering reasoning, not just the feature
- Demo scripts enable a non-technical presenter to perform a live demo step-by-step

### Business Success

- Demo prep time drops from hours to near-zero per story
- Engineering decisions are defensible to management through the artifacts
- Continuous visibility into technical work — management sees value delivered
- Scales across all Pennyfarthing consumer projects

### Measurable Outcomes

- 100% of completed stories have an artifact
- Presenter spends < 5 minutes reviewing per story
- Fewer "what does this mean" follow-ups from management

## User Journeys

### Journey 1: Developer — Story Completion

Dev finishes a story. `pf sprint story finish` fires. The generator collects story ACs, PR diff, commits, session context, review findings. It classifies the story — this one touched the UI, so it captures screenshots via Playwright, generates a slide deck with a demo script. Artifact lands in `sprint/demos/<story-id>/`. Dev doesn't think about it. Done.

### Journey 2: Presenter — Pre-Meeting Prep

Boss has a meeting in 2 hours. Opens `sprint/demos/`, finds 4 story packages from this sprint. Each is a concise deck + demo script. He reads story 5.1 — deeply technical, Boolean logic. The deck says: "Problem: Users couldn't combine search filters. Now they can. Here's why we built a full expression engine instead of AND/OR." Diagrams show before/after. Demo script says "Open search, type X, click Y, notice Z." He spots a claim that doesn't match the spec — kicks it back.

### Journey 3: Presenter — Last Minute

Meeting in 15 minutes. Boss grabs artifacts, skims, presents as-is. Artifact quality survives presenting cold.

### Journey 4: Developer — Revision Kickback

Boss flags: "Slide 2 says 40% improvement but spec said 30%." Dev regenerates with corrections. Updated version replaces the original.

### Journey 5: Framework Admin — Configuration

New PF consumer onboards. Admin configures output format preferences, branding, classification rules in a checked-in config file. Sets and forgets.

## Developer Tool Requirements

### Interface

- CLI: `pf demo generate <story-id>`
- Skill: `/pf-demo`
- Python API underneath, consistent with PF architecture

### Output Storage

- `sprint/demos/<story-id>/` — version-controlled, shareable
- Not `.session/` (gitignored)

### Configuration

- Checked-in config file (`repos.yaml` extension or dedicated `demo.yaml`)
- Covers: output format preferences, branding (logo, colors, fonts), story-type-to-format classification rules, template overrides

### Story Type Classification

Classification-based format selection (not degradation/fallback):

| Story Type | Artifacts |
|------------|-----------|
| UI feature | Screenshots + slide deck + demo script |
| Backend/infrastructure | Architecture diagrams + narrative + demo script |
| Refactoring/tech debt | Before/after comparison + rationale narrative |
| Bug fix | Problem statement + resolution narrative |

Classification rules configurable per consumer project.

## Scope

### MVP (Phase 1)

- Auto-collect all story signals on completion
- Classification-based format selection
- Slide deck generation (PDF/PPTX): problem, what, why, before/after
- Playwright screenshot capture for UI stories
- Mermaid diagram generation for backend stories
- Demo script generation — step-by-step presenter walkthrough
- CLI + skill wrapper
- Output to `sprint/demos/<story-id>/`
- Checked-in configuration
- Hook into `pf sprint story finish` for auto-trigger

### Phase 2 (Growth)

- Multiple output formats per preference
- Cumulative sprint/epic rollup summaries
- Template customization per consumer
- Presentation tool integration (Google Slides, PowerPoint)

### Phase 3 (Vision)

- Recorded demos via browser automation
- Interactive demo mode
- Voice-narrated walkthroughs
- Management dashboard with embedded demos

### Risks

| Risk | Mitigation |
|------|------------|
| AI translation quality | Human review loop — developer checks before presenter sees |
| Playwright integration | Explicit per-project screenshot config; app must be runnable |
| PPTX rendering fidelity | Simple slide templates |

## Functional Requirements

### Signal Collection

- FR1: System auto-collects story ACs, PR diff, commit messages, session context, and review findings on story completion
- FR2: Collection requires zero developer intervention
- FR3: Developer can manually trigger collection for a specific story via CLI

### Story Classification

- FR4: System classifies completed stories by type (UI, backend, refactoring, bug fix, infrastructure)
- FR5: System maps story type to artifact format based on classification rules
- FR6: Admin can configure classification rules per consumer project

### Artifact Generation — Slide Deck

- FR7: System generates a slide deck (PDF/PPTX) from collected signals
- FR8: Deck presents: problem statement, what was built, why this approach, before/after
- FR9: Deck content written at ELI5 level for non-technical audience
- FR10: Deck explains engineering reasoning and decision rationale

### Artifact Generation — Screenshots

- FR11: System captures UI screenshots via Playwright for UI-type stories
- FR12: Screenshots incorporated into slide decks at appropriate positions

### Artifact Generation — Diagrams

- FR13: System generates architecture/data flow diagrams (mermaid) for backend stories
- FR14: System renders mermaid diagrams to images for deck inclusion
- FR15: Diagrams show before/after state when applicable

### Artifact Generation — Demo Scripts

- FR16: System generates step-by-step demo scripts for non-technical presenters
- FR17: Scripts specify what to click, what to say, what to point out
- FR18: Scripts appropriate to story type (UI walkthrough vs. architectural explanation)

### Output Management

- FR19: Artifacts stored in `sprint/demos/<story-id>/`
- FR20: Re-run overwrites previous artifacts
- FR21: Developer reviews artifacts before presenter receives them
- FR22: Developer can regenerate with corrections after feedback

### Configuration

- FR23: Admin configures output format preferences per project
- FR24: Admin configures branding (logo, colors, fonts)
- FR25: Admin configures classification rules
- FR26: Configuration in version-controlled file

### Integration

- FR27: Triggered via `pf demo generate <story-id>`
- FR28: Triggered via `/pf-demo` skill
- FR29: Hooks into `pf sprint story finish` for automatic generation

## Non-Functional Requirements

### Performance

- Generation completes within minutes per story
- Playwright has hard timeouts — fail, don't hang

### Reliability

- Fail hard on any component failure — no partial output, no placeholders
- Clear error messages for developer to fix and regenerate
- Consistent with PF's `{success, data?, error?}` return pattern

### Integration

- Works with PF's existing CLI, skill system, and hook pipeline
- Reads existing story/session/sprint data without requiring modifications
- Playwright required for consumer projects with UI stories

### Output Completeness

- Artifact length driven by story complexity, not tool limitations
- 30-slide deck if needed — split across generation passes if necessary
- Demo scripts as long as the demo requires
- Tool limitations are engineering problems, never reasons to reduce quality
