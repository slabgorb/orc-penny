# Story 86-8: Teammate activation via spawn prompts

**Status:** in-progress
**Jira:** PROJ-14503
**Branch:** feature/PROJ-14503-teammate-activation-spawn-prompts
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** finish
**Assigned:** keith.avery@slabgorb.io
**Sprint:** 2606

---

## Context

Story 86-8 implements lightweight spawn prompt activation for native Agent Teams. When a phase lead spawns a teammate in Phase 2, the spawn prompt triggers normal Prime activation by running `pf agent start {agent}`, allowing teammates to auto-load CLAUDE.md, MCP servers, and skills from the working directory. This keeps the prompt minimal (under 500 tokens) while ensuring teammates activate with full persona, sidecars, and session context — no context rebuild needed in the prompt itself.

## Acceptance Criteria

- [ ] Spawn prompt runs `pf agent start {agent}` for full Prime activation
- [ ] Spawn prompt includes: story ID, task assignment, phase context
- [ ] Teammates activate with persona, sidecars, and session context via Prime (not prompt injection)
- [ ] Spawn prompt stays under 500 tokens (activation command + task)
- [ ] Works with all 10 core agents
- [ ] Teammate correctly reads session file and workflow state

## Technical Approach

The spawn prompt is a thin wrapper that:

1. Invokes `pf agent start {agent}` to trigger Prime activation with the agent's persona and workflow context
2. Passes story ID, task description, and phase context as arguments or environment
3. Relies on Prime to load the agent definition from `.pennyfarthing/agents/{agent}.md`
4. Lets teammates read the session file (`.session/{story-id}-session.md`) and workflow state directly
5. Creates `pennyfarthing-dist/scripts/core/build-spawn-prompt.sh` as the main implementation
6. Adds `<team-mode>` section to `pennyfarthing-dist/agents/agent-behavior.md` documenting teammate behavior

Key insight: teammates inherit the working directory context (MCP servers, skills, sidecars) automatically from Claude Code's environment — the spawn prompt only needs to activate the agent identity and task assignment.

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core spawn prompt builder needs comprehensive coverage across all 6 ACs

**Test Files:**
- `packages/core/src/shared/spawn-prompt.test.ts` — 39 tests covering all 6 ACs
- `packages/core/src/shared/spawn-prompt.ts` — stub module (compiles, returns defaults)

**Tests Written:** 39 tests covering 6 ACs
**Status:** RED (34 failing on assertions, 5 passing on coincidental stub defaults)

**Note:** Tests placed in `packages/core/src/shared/` (matching 86-7 capabilities.ts pattern). Module exports `buildSpawnPrompt()`, `estimateTokenCount()`, `validateSpawnPrompt()`, and `CORE_AGENTS` constant. The stub returns `{success: false}` for all build calls and empty `CORE_AGENTS` array.

**Key design decisions:**
- `buildSpawnPrompt()` returns result object `{success, prompt?, tokenEstimate?, error?}` — consistent with capabilities.ts pattern
- `CORE_AGENTS` exported as readonly array — all 11 agents (sm, tea, dev, reviewer, architect, pm, tech-writer, ux-designer, devops, orchestrator, ba)
- `estimateTokenCount()` uses ~4 chars/token heuristic for budget enforcement
- `validateSpawnPrompt()` checks both token limit and activation command presence
- Tests verify prompt does NOT contain inline persona/sidecar/behavior content (AC3 anti-injection)
- Tests verify prompt stays under 500 tokens even with long task descriptions (AC4 boundary)

**Handoff:** To Dev for implementation

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/shared/spawn-prompt.ts` - Implemented buildSpawnPrompt(), estimateTokenCount(), validateSpawnPrompt(), and CORE_AGENTS constant

**Tests:** 39/39 passing (GREEN)
**PR:** #938 - feat(86-8): teammate activation via spawn prompts
**Branch:** feature/PROJ-14503-teammate-activation-spawn-prompts (pushed)

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** SpawnPromptConfig → validation → template interpolation → SpawnPromptResult (pure function, no I/O, no injection vectors)
**Pattern observed:** Result object envelope `{success, prompt?, tokenEstimate?, error?}` consistent with capabilities.ts at `spawn-prompt.ts:29-36`
**Error handling:** Empty required fields return `{success: false, error}` at `spawn-prompt.ts:52-64`; unknown agents rejected with descriptive error listing valid agents at line 63
**Security:** Pure string construction — no file I/O, no process spawn, no network calls. Anti-injection verified: prompt contains no `<persona>`, `<pattern>`, `<gotcha>`, or `<agent-exit-protocol>` content
**Observations:** 8 total (5 verified-good, 1 LOW severity). LOW: redundant `as const` on line 17 (harmless, widened by explicit `readonly string[]` annotation)
**Tests:** 39/39 passing (GREEN)

**Handoff:** To SM for finish-story