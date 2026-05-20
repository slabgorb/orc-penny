# Epic PROJ-12793: Tiered Context Injection System

## Overview
Implement session-aware context tiers to reduce token overhead from agent context injection. Currently Cyclist sends ~4000 tokens via --append-system-prompt on every turn, even when resuming sessions where the agent already has context.

**Jira Key:** PROJ-12793
**Priority:** P1
**Status:** In Progress
**Total Points:** 18
**Repos:** pennyfarthing

## Problem Statement

Current overhead per turn:
- **First turn**: ~4000 tokens (necessary)
- **Resumed session, same agent**: ~4000 tokens (wasteful - 85% redundant)
- **Agent handoff**: ~4000 tokens (partially wasteful - 50% redundant)
- **Deep conversation (turn 10+)**: ~4000 tokens (extremely wasteful - 95% redundant)

## Solution: Four Context Tiers

| Tier | Tokens | When Used |
|------|--------|-----------|
| FULL | ~4000 | First turn of new session |
| REFRESH | ~600 | Resumed session, same agent |
| HANDOFF | ~700 | Resumed session, different agent |
| MINIMAL | ~200 | Deep conversation (turn 3+), same agent |

### Projected Savings

| Scenario | Current | Proposed | Savings |
|----------|---------|----------|---------|
| 10-turn same-agent session | 40,000 | 6,400 | 84% |
| 5 agent handoffs | 20,000 | 7,500 | 62% |
| Mixed 20-turn session | 80,000 | 12,000 | 85% |

## Stories

### PROJ-12795: Session state tracking in ClaudeService (3 pts) - DONE
Add SessionContextState interface to ClaudeService:
- Track lastAgent, turnCount, injectedComponents
- Update on each message
- Reset on resetSession()

**Completed:** 2026-02-01

### PROJ-12796: Tier selection logic (2 pts) - DONE
Implement selectContextTier() function with decision logic:
- No lastAgent -> FULL
- Different agent -> HANDOFF
- Same agent, turn > 3 -> MINIMAL
- Else -> REFRESH

Unit tests for all tier transitions.

**Completed:** 2026-02-01

### PROJ-12797: Python prime tier support (5 pts) - IN PROGRESS
Add --tier argument to prime script:
- Implement tier-specific component loading
- Add compressed persona format
- Maintain backward compatibility (default FULL)

**Branch:** feat/PROJ-12797-python-prime-tier-support
**Assignee:** kavery

### PROJ-12798: TypeScript tier integration (3 pts) - BACKLOG
Wire tier selection into message flow:
- Call selectContextTier() before getPrimeContext()
- Pass tier to Python script
- Update state after successful message

### PROJ-12799: Debug panel tier display (2 pts) - BACKLOG
Show current tier in DebugPanel:
- Add tier to ContextInfo interface
- Display tier badge with color coding
- Show potential savings

### PROJ-12800: Component-level token tracking (3 pts) - BACKLOG
Add token counting per component:
- Approximate token count per component
- Pass breakdown to UI
- Collapsible component list in DebugPanel

## Technical Architecture

### Session Metadata Tracking (TypeScript)
```typescript
interface SessionContextState {
  lastAgent: string | null;
  turnCount: number;
  injectedComponents: Set<string>;
  lastWorkflowHash: string | null;
}
```

### Tier Selection Logic (TypeScript)
```typescript
function selectContextTier(
  agentName: string,
  state: SessionContextState
): 'FULL' | 'REFRESH' | 'HANDOFF' | 'MINIMAL' {
  if (!state.lastAgent) return 'FULL';
  if (state.lastAgent !== agentName) return 'HANDOFF';
  if (state.turnCount > 3) return 'MINIMAL';
  return 'REFRESH';
}
```

### Tier Content Definitions

**FULL (~4000 tokens)** - All 10 components:
1. workflow-state (~200)
2. agent-definition (~400)
3. persona (~300)
4. behavior-guide (~800)
5. crew-manifest (~500)
6. sprint-context (~150)
7. session-header (~200)
8. sidecars (~1200)
9. domain-docs (~450)
10. redirect-marker (variable)

**REFRESH (~600 tokens)** - Dynamic state only:
1. workflow-state (~200)
2. sprint-context (~150)
3. session-header (~200)
4. Note: "Full context already in conversation history"

**HANDOFF (~700 tokens)** - New agent essentials:
1. workflow-state (~200)
2. agent-definition (~400)
3. persona-compressed (~100)
4. Note: "Behavior guides in conversation history"

**MINIMAL (~200 tokens)** - Routing only:
1. workflow-state (~200)
2. Optional: workflow change notification

### Compressed Persona Format
```xml
<persona agent="dev" character="Rosie the Riveter">
  <voice>Can-do wartime spirit, practical, determined</voice>
  <catchphrase>"We Can Do It!"</catchphrase>
  <style>Direct, encouraging, efficiency-focused</style>
</persona>
```

## Success Metrics

1. **Token Reduction**: System prompt tokens per turn < 1000 avg (currently ~4000)
2. **Time to Error**: Time to 'Prompt too long' error: 2x current
3. **Behavior Fidelity**: Agent persona consistency: no regression

## Key Files

### TypeScript (Cyclist)
- `packages/cyclist/src/claude-service.ts` - Session state tracking
- `packages/cyclist/src/prime.ts` - Tier selection, Python invocation
- `packages/cyclist/src/api/context.ts` - ContextInfo interface

### Python (Prime)
- `pennyfarthing_scripts/prime/cli.py` - --tier argument
- `pennyfarthing_scripts/prime/tiers.py` - Tier loading logic (new)
- `pennyfarthing_scripts/prime/persona.py` - Compressed format

### UI
- `packages/cyclist/src/public/components/panels/DebugPanel.tsx` - Tier display

## Reference Documents
- Full specification: `sprint/context/PROJ-12787-reference/tiered-context-story-draft.md`

## Dependencies
- check-context.sh provides baseline/usable breakdown
- ContextInfo interface has component fields (unused)
- Session resumption via --resume already works
