# Story Draft: Tiered Context Injection System

## Problem Statement

Cyclist sends ~4000 tokens of agent context via `--append-system-prompt` on **every turn**, even when resuming a session where the agent has already demonstrated understanding. This compounds with conversation history until hitting "Prompt too long" errors.

Current overhead per turn:
- **First turn**: ~4000 tokens (necessary)
- **Resumed session, same agent**: ~4000 tokens (wasteful - 85% redundant)
- **Agent handoff**: ~4000 tokens (partially wasteful - 50% redundant)
- **Deep conversation (turn 10+)**: ~4000 tokens (extremely wasteful - 95% redundant)

## Proposed Solution: Tiered Context Injection

Implement four context tiers based on session state:

| Tier | Tokens | When Used |
|------|--------|-----------|
| FULL | ~4000 | First turn of new session |
| REFRESH | ~600 | Resumed session, same agent |
| HANDOFF | ~700 | Resumed session, different agent |
| MINIMAL | ~200 | Deep conversation (turn 3+), same agent |

### Token Savings

| Scenario | Current | Proposed | Savings |
|----------|---------|----------|---------|
| 10-turn same-agent session | 40,000 | 6,400 | 84% |
| 5 agent handoffs | 20,000 | 7,500 | 62% |
| Mixed 20-turn session | 80,000 | 12,000 | 85% |

## Technical Design

### 1. Session Metadata Tracking

Add to `ClaudeService` (`claude-service.ts`):

```typescript
interface SessionContextState {
  lastAgent: string | null;
  turnCount: number;
  injectedComponents: Set<string>;
  lastWorkflowHash: string | null;
}
```

### 2. Tier Selection Logic

```typescript
function selectContextTier(
  agentName: string,
  state: SessionContextState
): 'FULL' | 'REFRESH' | 'HANDOFF' | 'MINIMAL' {
  // New session - need everything
  if (!state.lastAgent) return 'FULL';

  // Different agent - need agent def + persona
  if (state.lastAgent !== agentName) return 'HANDOFF';

  // Same agent, deep conversation - just workflow state
  if (state.turnCount > 3) return 'MINIMAL';

  // Same agent, early conversation - refresh dynamic state
  return 'REFRESH';
}
```

### 3. Tier Content Definitions

#### FULL (~4000 tokens) - Current behavior
All 10 components:
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

#### REFRESH (~600 tokens)
Dynamic state only:
1. workflow-state (~200) - routing decisions need current info
2. sprint-context (~150) - may have changed
3. session-header (~200) - current assessment
4. Note: "Full context already in conversation history"

#### HANDOFF (~700 tokens)
New agent essentials:
1. workflow-state (~200)
2. agent-definition (~400) - new agent needs this
3. persona-compressed (~100) - key traits only
4. Note: "Behavior guides in conversation history"

#### MINIMAL (~200 tokens)
Routing only:
1. workflow-state (~200) - always needed for phase transitions
2. Optional: workflow change notification

### 4. Python Prime Script Changes

Add `--tier` argument to `prime/cli.py`:

```python
@click.option('--tier', type=click.Choice(['FULL', 'REFRESH', 'HANDOFF', 'MINIMAL']))
def prime(agent_name: str, tier: str = 'FULL') -> str:
    if tier == 'FULL':
        return full_prime(agent_name)

    components = []

    # Always include workflow state
    components.append(load_workflow_state())

    if tier in ('REFRESH', 'HANDOFF'):
        components.append(load_sprint_context())

    if tier == 'REFRESH':
        components.append(load_session_header())
        components.append("<!-- Note: Full agent context in conversation history -->")

    if tier == 'HANDOFF':
        components.append(load_agent_definition(agent_name))
        components.append(load_persona_compressed(agent_name))
        components.append("<!-- Note: Behavior guides in conversation history -->")

    if tier == 'MINIMAL':
        components.append("<!-- Minimal context: see conversation history for full agent context -->")

    return '\n\n'.join(components)
```

### 5. Compressed Persona Format

Full persona (~300 tokens):
```markdown
## Rosie the Riveter - Developer Agent
You embody the spirit of Rosie the Riveter, the iconic symbol of American
women who worked in factories during World War II...
[extensive character description with examples]
```

Compressed persona (~100 tokens):
```xml
<persona agent="dev" character="Rosie the Riveter">
  <voice>Can-do wartime spirit, practical, determined</voice>
  <catchphrase>"We Can Do It!"</catchphrase>
  <style>Direct, encouraging, efficiency-focused</style>
</persona>
```

## Implementation Stories

### Story 1: Session State Tracking (3 pts)
Add `SessionContextState` to ClaudeService:
- Track `lastAgent`, `turnCount`, `injectedComponents`
- Update on each message
- Reset on `resetSession()`

**Files:**
- `cyclist/src/claude-service.ts`

### Story 2: Tier Selection Logic (2 pts)
Implement `selectContextTier()` function:
- Decision logic based on session state
- Unit tests for all tier transitions

**Files:**
- `cyclist/src/prime.ts` (new function)
- `cyclist/src/prime.test.ts` (new tests)

### Story 3: Python Prime Tier Support (5 pts)
Add `--tier` argument to prime script:
- Implement tier-specific component loading
- Add compressed persona format
- Maintain backward compatibility (default FULL)

**Files:**
- `pennyfarthing_scripts/prime/cli.py`
- `pennyfarthing_scripts/prime/tiers.py` (new)
- `pennyfarthing_scripts/prime/test_tiers.py` (new)

### Story 4: TypeScript Integration (3 pts)
Wire tier selection into message flow:
- Call `selectContextTier()` before `getPrimeContext()`
- Pass tier to Python script
- Update state after successful message

**Files:**
- `cyclist/src/claude-service.ts`
- `cyclist/src/prime.ts`

### Story 5: Debug Panel Tier Display (2 pts)
Show current tier in DebugPanel:
- Add tier to ContextInfo interface
- Display tier badge with color coding
- Show potential savings

**Files:**
- `cyclist/src/api/context.ts`
- `cyclist/src/public/components/panels/DebugPanel.tsx`

### Story 6: Component-Level Token Tracking (3 pts)
Add token counting per component:
- Approximate token count per component
- Pass breakdown to UI
- Collapsible component list in DebugPanel

**Files:**
- `pennyfarthing_scripts/prime/cli.py`
- `cyclist/src/api/context.ts`
- `cyclist/src/public/components/panels/DebugPanel.tsx`

## Total: 18 points (6 stories)

## Acceptance Criteria

1. **Token Reduction**: Resumed same-agent sessions use <800 tokens for system prompt
2. **Behavior Fidelity**: Agent maintains persona through tier transitions
3. **Observability**: DebugPanel shows current tier and component breakdown
4. **Backward Compatible**: `--tier` defaults to FULL, existing behavior unchanged
5. **Tests**: Unit tests for tier selection logic with >90% coverage

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Agent loses character in MINIMAL tier | Test persona retention; add "character refresh" on style drift |
| Workflow state stale | Always include workflow-state in all tiers |
| Turn count resets unexpectedly | Persist in session storage, not just memory |

## Metrics

- **Primary**: System prompt tokens per turn (target: <1000 avg)
- **Secondary**: Time to "Prompt too long" error (target: 2x current)
- **Guard**: Agent persona consistency score (target: no regression)

## Dependencies

- check-context.sh already provides baseline/usable breakdown
- ContextInfo interface already has component fields (unused)
- Session resumption via `--resume` already works

## Future Enhancements

1. **Adaptive tiers**: Monitor for persona drift, auto-inject refresh
2. **Component caching**: Hash components, skip if unchanged
3. **Conversation summarization**: Compress old turns instead of dropping context
