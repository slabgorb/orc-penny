# Workflow Session: architecture

**Workflow:** architecture
**Type:** stepped
**Agent:** architect
**Started:** 2026-03-12T01:59:46Z

## Workflow State
- **Workflow Name:** architecture
- **Type:** stepped
- **Mode:** create
- **Started:** 2026-03-12T01:59:46Z
- **Last Updated:** 2026-03-12T01:59:46Z
- **Current Step:** 7
- **Steps Completed:** [1, 2, 3, 4, 5, 6, 7]
- **Status:** complete
- **Notes:** All steps completed. ADR-0037 written to docs/adr/

## Progress
- Total Steps: 8
- Completion: 100%

---

## Architecture Session: Native Subagent Migration

### Inputs Gathered
- **PRD:** `sprint/planning/native-subagent-migration-prd.md` (complete, 12-step workflow)
- **Relevant ADRs:**
  - ADR-0007: Subagent Delegation Model (Opus/Haiku split) — current model being replaced
  - ADR-0012: Tandem Agent Pairing — consultation protocol, must survive migration
  - ADR-0017: Relay Mode (automatic handoff) — marker-based, mechanism changes with native subagents
  - ADR-0034: Post-Migration Architecture — Python runtime + React GUI boundary
- **Constraints:** MVP scope (Phase 1 only), brownfield, medium complexity

### Stakeholders
- Decision maker: Keith Avery (sole developer/user)
- Reviewers: N/A (personal tool)

### Key Architectural Questions
1. How do `.claude/agents/*.md` definitions map from existing `pennyfarthing-dist/agents/*.md`?
2. How does SM spawn subagents — via Agent tool or Task tool? What prompt does it pass?
3. What is the handoff document contract format?
4. How do tool restrictions work with Claude Code's native `tools` allowlist?
5. How does relay mode change when SM explicitly spawns vs emitting HANDOFF markers?
6. How do Tandem and Team mode work with isolated subagent contexts?
7. How does the persona/theme system inject into native agent definitions?

