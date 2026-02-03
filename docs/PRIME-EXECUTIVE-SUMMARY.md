# Prime Activation System - Executive Summary

## Overview

Prime is Pennyfarthing's unified Python-based activation system that bootstraps AI agents with consistent, contextually-relevant information. It replaces scattered shell scripts with a single entry point that intelligently loads context based on workflow state and session history.

## Key Innovations

### 1. Workflow State Detection

Prime automatically detects one of four workflow states by analyzing session files and sprint backlog:

| State | Condition | Recommended Action |
|-------|-----------|-------------------|
| `FINISH_STATE` | Session exists with approved/finish phase | SM completes story |
| `IN_PROGRESS_STATE` | Active session with work in progress | Continue with phase owner |
| `NEW_WORK_STATE` | No session, backlog has stories | SM picks next story |
| `EMPTY_BACKLOG_STATE` | No session, empty backlog | Product planning needed |

This enables intelligent agent routing—if a user activates the wrong agent for the current phase, Prime can redirect to the appropriate phase owner.

### 2. Tiered Context Injection

Rather than loading everything or nothing, Prime implements four context tiers optimized for different scenarios:

| Tier | Tokens | Use Case | Components |
|------|--------|----------|------------|
| `FULL` | ~4000 | New session | Agent def, persona, guide, sprint, session, sidecars |
| `REFRESH` | ~600 | Same agent continues | Sprint, session header |
| `HANDOFF` | ~700 | Different agent takes over | Agent def, compressed persona |
| `MINIMAL` | ~200 | Deep conversation (turn 3+) | Workflow state only |

This dramatically reduces token waste—a developer 10 turns into debugging doesn't need their full persona re-injected.

### 3. Persona System Integration

Prime loads character personas from themed YAML files (102 themes available), providing:
- Character identity and communication style
- Crew manifest for proper handoff addressing
- User title customization (e.g., "Bossmang" for The Expanse theme)
- Compressed persona format (~100 tokens vs ~300 for full)

### 4. Sidecar Learning

Agents accumulate institutional knowledge in sidecar files:
- `patterns.md` - Reusable solutions
- `gotchas.md` - Common pitfalls
- `decisions.md` - Historical context

Prime loads these in priority order, ensuring agents learn from experience.

### 5. Session Parsing

Prime extracts structured data from markdown session files:
- Story ID from filename
- Current phase and status from headers
- Latest assessment section for context continuity

### 6. JSON Output for Cyclist Integration

Prime outputs structured JSON that Cyclist (the visual terminal) consumes:

```json
{
  "agent_name": "dev",
  "workflow_status": {"state": "IN_PROGRESS_STATE", "phase": "green", ...},
  "persona": {"character": "Naomi Nagata", "style": "...", ...},
  "tier": "FULL",
  "token_counts": {"agent_definition": 800, "persona": 250, ...},
  "total_tokens": 2450
}
```

## Performance Characteristics

- **Target latency**: <200ms startup time
- **Lazy imports**: Python modules only loaded when needed
- **Token estimation**: ~4 chars/token approximation (within 10% accuracy)

## Architecture Benefits

| Before Prime | After Prime |
|--------------|-------------|
| Scattered shell scripts | Single Python entry point |
| No state awareness | 4-state workflow detection |
| All-or-nothing context | 4 context tiers |
| Manual agent selection | Automatic redirect suggestions |
| No token tracking | Per-component token estimates |
| Shell YAML parsing | Proper Python YAML handling |

## Source Files

```
pennyfarthing_scripts/prime/
├── __init__.py      # Public API: prime()
├── cli.py           # CLI entry point with lazy loading
├── loader.py        # Context loading (agent, guide, session, sidecars)
├── models.py        # Data models (WorkflowState, Persona, PrimeResult)
├── persona.py       # Persona loading and formatting
├── tiers.py         # Tiered context injection
└── workflow.py      # Workflow state detection
```

## Related Documentation

- [ADR-0015: Prime Activation System](./adr/0015-prime-activation-system.md) - Full architecture decision record
- [ADR-0016: Bell Mode](./adr/0016-bell-mode-message-injection.md) - Message queue injection
- [ADR-0017: Relay Mode](./adr/0017-relay-mode-automatic-handoff.md) - Automatic agent handoff

## Summary

Prime transforms agent activation from a dumb context dump into an intelligent, session-aware system that:

1. **Knows what work state you're in** - Detects workflow phase from session files
2. **Loads only the context needed** - Tiered injection reduces token waste
3. **Suggests the right agent** - Redirects if wrong agent activated for phase
4. **Tracks token usage** - Per-component estimates for optimization
5. **Provides structured output** - JSON for Cyclist UI integration

The result is faster startup, more relevant context, and better agent coordination across complex multi-phase workflows.
