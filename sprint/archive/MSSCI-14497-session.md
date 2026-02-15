# Story 86-2: Consultation protocol implementation

**Jira:** MSSCI-14497
**Epic:** 86 — Agent Collaboration: Tandem to Teams
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** story/86-2-consultation-protocol-implementation
**Assigned:** keith.avery@1898andco.io

## Story Context

Story 86-2 builds on 86-1 (tandem schema validation), which added YAML parsing for `tandem:` blocks in workflows. Now we need to implement the actual **consultation protocol** — the structured request/response mechanism that lets one agent ask another agent a focused question during workflow execution.

From ADR-0012, the consultation pattern is:
1. **Leader agent** (e.g., Dev) encounters a decision point and spawns **partner agent** (e.g., Architect) as a Haiku subagent
2. Leader formats a **consultation request** with context, question, alternatives considered, and relevant code
3. Partner responds with a **consultation response** containing recommendation, rationale, watch-out-for, and confidence level
4. Leader receives structured response and continues work

This is different from the existing **tandem protocol** (currently shipping in tdd-tandem, bdd-tandem workflows):
- **Tandem:** Passive background observer (backseat) writes observations to a file, injected via bell-mode
- **Consultation:** Active request/response dialogue initiated by leader agent with immediate structured feedback

**Key shift:** 86-1 defined the `tandem:` block syntax. This story implements consultation — the **protocol and prompts** that drive structured agent-to-agent questions during work.

## Technical Approach

### 1. Consultation Request Format

Leader agent constructs a request following this schema:
```markdown
**Leader:** {leader-name} ({leader-character})
**Partner:** {partner-name}
**Context:** {brief background}
**Question:** {decision point}
**Alternatives Considered:** {list}
**Relevant Code/Files:** {code snippets or file references}
**Token Budget:** {budget from workflow tandem.token_budget}
```

### 2. Consultation Response Format

Partner responds with:
```markdown
**Recommendation:** {concise advice}
**Rationale:** {why this approach}
**Watch-Out-For:** {pitfalls or edge cases}
**Confidence:** {high|medium|low}
**Token Count:** {actual tokens consumed}
```

### 3. Implementation Details

- **Spawn partner via Task tool** with `model: sonnet` (not haiku, per ADR-0012 Table 2 — advisors use Sonnet)
- **Spawn prompt includes:**
  - Partner agent definition (e.g., architect.md)
  - Active persona/character from theme
  - Formatted consultation request
  - Token budget as hard instruction: "Your response must not exceed {budget} tokens"

- **Response parsing:** Leader parses response markdown to extract recommendation, rationale, watchout, confidence, token count
- **Error handling:** If partner spawn fails or times out, leader continues solo with warning message
- **Dialogue recording:** Response is appended to `.session/{story-id}-dialogue.md` (86-3 handles dialogue file management, but consultation response format must be compatible)

### 4. Leader Agent Awareness

Leader agents (Dev, TEA, Reviewer) get updated with:
- **When to consult:** Detect tandem config on current phase in workflow
- **How to spawn:** Task tool call with partner agent + formatted request
- **How to parse:** Extract structured fields from response
- **Error recovery:** Graceful degradation if consultation fails

### 5. Partner Agent Awareness

Partner agents (Architect, TEA, PM, DevOps) get guidance on:
- **Response format:** Structured markdown with recommendation, rationale, watch-outs, confidence
- **Token discipline:** Stay within budget, prioritize clarity
- **Consultation vs advice:** This is a focused answer to a specific question, not open-ended exploration

## Key Files

### New Files to Create
- `pennyfarthing-dist/protocols/tandem-consultation.md` — Protocol specification (prompts, formats, error handling)
- `packages/core/src/consultation/consultation-protocol.ts` — TypeScript utilities for request/response parsing and validation

### Files to Update
- `pennyfarthing-dist/agents/dev.md` — Add tandem consultation section with example request
- `pennyfarthing-dist/agents/tea.md` — Add tandem consultation section with example request
- `pennyfarthing-dist/agents/reviewer.md` — Add tandem consultation section with example request
- `pennyfarthing-dist/agents/architect.md` — Add consultation response guidance
- `pennyfarthing-dist/agents/pm.md` — Add consultation response guidance
- `pennyfarthing-dist/agents/devops.md` — Add consultation response guidance

## Acceptance Criteria

- [ ] Consultation request format defined: context, question, options considered, relevant code
- [ ] Consultation response format defined: recommendation, rationale, watch-out-for, confidence
- [ ] Leader spawns partner via Task tool with `model: sonnet`
- [ ] Partner prompt includes: agent definition, persona, consultation request
- [ ] Response parsed and available to leader for continued work
- [ ] Graceful degradation: partner failure → leader continues solo with warning
- [ ] Token budget enforced via prompt instruction
- [ ] Protocol spec document (tandem-consultation.md) created with examples
- [ ] Leader agents (dev, tea, reviewer) updated with tandem consultation guidance
- [ ] Partner agents (architect, pm, devops, tea) updated with response guidance

## Related Stories

- **86-1:** Tandem schema validation (completed) — `tandem:` block parsing from workflow YAML
- **86-3:** Dialogue file management — Persist consultation exchanges to `.session/{story-id}-dialogue.md`
- **86-4:** Agent tandem awareness — Update all agent definitions for consultation protocol

## Testing Strategy

1. **Unit tests:** Consultation request/response format validation
2. **Integration test:** Dev (leader) spawns Architect (partner) with consultation request, parses response
3. **Graceful degradation:** Partner spawn failure → leader continues with warning
4. **Token budget:** Response exceeding budget flagged in parsed result
5. **Prompt generation:** Verify leader and partner prompts include all required fields

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core protocol module with request/response parsing, validation, and graceful degradation — all require test coverage

**Test Files:**
- `packages/core/src/consultation/consultation-protocol.test.ts` — Full test suite for consultation protocol

**Tests Written:** 37 tests covering 7 ACs
- AC1 (request format): 9 tests — formatting, field validation, edge cases
- AC2 (response format): 8 tests — parsing, malformed input, whitespace handling
- AC3 (sonnet model): 3 tests — spawn params always return sonnet
- AC4 (prompt composition): 5 tests — agent def, persona, request, budget instruction, response format instructions
- AC5 (full execution): 3 tests — end-to-end with mock adapter, model verification, prompt completeness
- AC6 (graceful degradation): 4 tests — spawn failure, no-throw guarantee, unparseable response, error context
- AC7 (token budget): 3 tests — over-budget flag, within-budget, enforcement language in prompt

**ACs 8-10** (protocol spec doc, leader agent updates, partner agent updates) are markdown file deliverables — tested by existence and content review, not unit tests.

**Status:** RED (37 failing — all throw 'not implemented', no import/syntax errors)

**Stub module:** `packages/core/src/consultation/consultation-protocol.ts` — 7 exported functions with types, all throw on call

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/consultation/consultation-protocol.ts` — Full protocol implementation (formatRequest, parseResponse, validate, buildPrompt, executeConsultation)
- `pennyfarthing-dist/protocols/tandem-consultation.md` — Protocol specification with examples and API reference
- `pennyfarthing-dist/agents/dev.md` — Leader consultation guidance
- `pennyfarthing-dist/agents/tea.md` — Leader + partner consultation guidance
- `pennyfarthing-dist/agents/reviewer.md` — Leader consultation guidance
- `pennyfarthing-dist/agents/architect.md` — Partner response guidance
- `pennyfarthing-dist/agents/pm.md` — Partner response guidance
- `pennyfarthing-dist/agents/devops.md` — Partner response guidance

**Tests:** 37/37 passing (GREEN)
**PR:** #922 — feat(86-2): implement tandem consultation protocol
**Branch:** story/86-2-consultation-protocol-implementation (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #922
**Tests:** 37/37 passing, build clean, no forbidden patterns

**Observations (7):**
1. `extractField` regex `.+` captures single line only — acceptable by design (protocol defines single-line values)
2. Confidence matching is case-sensitive despite field regex using `'i'` flag — defensible (prompt instructs lowercase, degradation catches edge)
3. `leaderCharacter` and `alternativesConsidered` not validated — acceptable (cosmetic and optional respectively)
4. Clean adapter pattern (`ConsultationAdapter`) follows `ProcessAdapter` from `tandem-lifecycle.ts`
5. Protocol spec (`tandem-consultation.md`) accurate — comparison table, API reference, code examples match implementation
6. Result objects follow `{success, data?, error?}` framework pattern with `degraded` extension
7. Token budget is advisory (self-reported `tokenCount` + prompt enforcement) — matches spec

**AC Verification:**
- [x] AC1: Request format — `formatConsultationRequest` produces 7-field markdown
- [x] AC2: Response format — `parseConsultationResponse` extracts recommendation, rationale, watch-out-for, confidence, tokenCount
- [x] AC3: Sonnet model — `buildConsultationSpawnParams` always returns `model: 'sonnet'`
- [x] AC4: Prompt composition — `buildPartnerPrompt` includes agent def, persona, request, budget instruction
- [x] AC5: Response parsed — `executeConsultation` returns `data.response` on success
- [x] AC6: Graceful degradation — spawn failure and unparseable response both return `{success: false, degraded: true}`
- [x] AC7: Token budget — prompt includes "must not exceed", `overBudget` flag on response
- [x] AC8: Protocol spec created with examples and API reference
- [x] AC9: Leader agents (dev, tea, reviewer) updated with consultation guidance
- [x] AC10: Partner agents (architect, pm, devops, tea) updated with response format

**No blocking issues. Ready to merge.**

**Handoff:** To SM for merge and finish

## Dependencies

- ✅ 86-1 completed (tandem schema validation available)
- Need: Agent definition updates (86-4 scope, but consultation protocol must be defined first)
- Blocks: 86-3 (dialogue file persistence), 86-4 (agent awareness), 86-5 (workflow templates)