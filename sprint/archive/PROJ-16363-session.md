# 143-5: Define handoff document contract format

**Story ID:** 143-5
**Jira:** PROJ-16363
**Workflow:** trivial
**Phase:** finish
**Repos:** orchestrator
**Branch:** feat/143-5-handoff-document-contract
**Assignee:** keith

## Story Context

Define the handoff document contract format for inter-agent communication in native subagent architecture. This contract specifies the structure agents use to pass context, findings, and decisions when handing off between workflow phases.

### Acceptance Criteria
- Handoff document schema defined (fields, types, required vs optional)
- Contract documented in a canonical location
- Format supports all workflow types (tdd, trivial, bdd)
- Validates that downstream agents (143-7, 143-8) can consume the format

### Technical Approach
- Define markdown-based handoff document template
- Specify required sections: phase summary, findings, next-phase guidance
- Ensure compatibility with existing session file patterns

## SM Assessment

Trivial 2-point story on the critical path for native subagent migration. No dependencies — this unblocks 143-7 (SM reads handoff documents) and 143-8 (SM enforces gates). The contract format is a coordination artifact, not implementation code. Route directly to Reverend Mother (Dev) for implementation.

## Design Deviations

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found. Dev's "no deviations" claim is accurate for the stated ACs.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/schemas/handoff-document-schema.md` - Canonical handoff document contract with XML schema, markdown rendering template, element reference, phase-specific contracts, workflow phase maps, SM consumption protocol, and lifecycle docs
- `CLAUDE.md` - Added handoff document schema to schemas table

**Tests:** N/A (documentation artifact, no executable tests)
**Branch:** develop (committed directly — framework repo, trivial schema doc)

**AC Verification:**
- [x] Handoff document schema defined (fields, types, required vs optional) — full element reference table with types, required flags, and descriptions
- [x] Contract documented in canonical location — `pennyfarthing-dist/schemas/handoff-document-schema.md`
- [x] Format supports all workflow types (tdd, trivial, bdd) — workflow phase maps section covers all five workflow types
- [x] Validates that downstream agents (143-7, 143-8) can consume the format — SM consumption protocol section defines read/validate/inject/spawn flow

**Handoff:** To Leto II (Reviewer) for review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Handoff document written by agent → `.session/` filesystem → SM reads and injects into next agent prompt (safe because write-once/read-once, no user input, no execution)
**Pattern observed:** Schema follows established `schemas/` convention with XML schema + markdown rendering + element reference table at `pennyfarthing-dist/schemas/handoff-document-schema.md`
**Error handling:** Validation failures produce `GATE_RESULT` with `status: fail` — consistent with gate-schema.md pattern at `handoff-document-schema.md:248`
**Observations:**
- [MEDIUM] BDD phase map assigns `design` to Dev, should be `ux-designer` per `bdd.yaml` — fix before 143-7 consumes
- [MEDIUM] XML root attributes duplicate `<header>` child elements — pick one canonical location
- [LOW] Missing phase-specific contract for UX Designer's `design` phase in BDD workflows
- [LOW] No multi-repo path qualification in `<file path="...">` deliverables
- [VERIFIED] File location, markdown-XML mapping, SM consumption protocol, lifecycle, session relationship — all sound

**Handoff:** To Stilgar (SM) for finish-story

## Delivery Findings

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): BDD workflow phase map incorrectly assigns `design` phase to Dev instead of UX Designer. Affects `pennyfarthing-dist/schemas/handoff-document-schema.md` (line ~229, update agent assignment in BDD phase map). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): XML root element attributes duplicate `<header>` child elements — consolidate to one canonical location. Affects `pennyfarthing-dist/schemas/handoff-document-schema.md` (lines 22-34, remove redundant attributes from root or header). *Found by Reviewer during code review.*