---
parent: context-epic-143.md
workflow: tdd
---

# Story 143-7: SM reads handoff documents and chains phases

## Business Context

Story 143-6 established SM's ability to spawn a single native subagent and receive raw results. But a multi-phase workflow (e.g., TDD: setup → red → green → verify → review → finish) requires SM to **read the handoff document** produced by one subagent and **inject it as context** into the next subagent's prompt. This is the phase-chaining loop.

The handoff document contract (143-5) defines the XML schema. The subagent module (143-6) already has `build_subagent_prompt` accepting `prior_handoff_path` and `parse_subagent_result` extracting `SUBAGENT_RESULT` YAML blocks. What's missing is the SM-side orchestration logic that:

1. Parses the subagent result to find the handoff document path
2. Validates the handoff document exists and conforms to the contract
3. Determines the next phase and agent from the workflow definition
4. Spawns the next subagent with the prior handoff document injected

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/subagent/chain.py` (NEW) | Phase-chaining orchestration: read handoff → resolve next phase → build next spawn config |
| `pennyfarthing-dist/src/pf/subagent/result.py` | May need to extract handoff_path from SUBAGENT_RESULT |
| `pennyfarthing-dist/src/pf/subagent/__init__.py` | Export new chain module |

### Existing Infrastructure (DO NOT duplicate)

| File | What it provides |
|------|------------------|
| `pf/subagent/prompt.py` | `build_subagent_prompt(prior_handoff_path=...)` — already injects prior handoff content |
| `pf/subagent/result.py` | `parse_subagent_result()` — extracts SUBAGENT_RESULT YAML from raw output |
| `pf/subagent/spawn.py` | `build_spawn_config()` — assembles complete Agent tool config with optional prior_handoff_path |
| `pf/subagent/loader.py` | `get_native_agent_path()`, `get_agent_model()`, `get_agent_tool_restrictions()` |
| `pf/handoff/complete_phase.py` | `complete_phase()` — atomic session file update for phase transitions |
| `pf/handoff/phase_check.py` | `phase_check_start()` — determines which agent owns current phase |
| `pf/prime/workflow.py` | `detect_workflow_state()`, `check_redirect()`, `find_active_session()` |

### Patterns to Follow

- **Result object pattern:** Return `{success: bool, data?: ..., error?: str}` — don't throw (SOUL principle 10)
- **Workflow phase ordering:** Use `_load_workflow_phases()` from `complete_phase.py` or equivalent to look up next phase/agent from workflow YAML. TDD phases: setup → red → green → verify → review → finish
- **Handoff document location:** Subagents write handoff documents to `.session/` — the SUBAGENT_RESULT should include a `handoff_path` field pointing to the file
- **Existing chaining:** `build_spawn_config()` already accepts `prior_handoff_path` and passes it through to `build_subagent_prompt()` which reads and injects the content

### Data Flow (target state)

```
SM spawns TEA (red phase)
  → TEA writes handoff doc to .session/143-7-red-handoff.md
  → TEA returns SUBAGENT_RESULT: {status: success, handoff_path: .session/143-7-red-handoff.md}
  → SM parses result, extracts handoff_path
  → SM validates handoff document exists
  → SM looks up workflow: red → green (agent: dev)
  → SM calls complete_phase(from_phase=red, to_phase=green)
  → SM calls build_spawn_config(agent_name=dev, prior_handoff_path=handoff_path)
  → SM spawns Dev with TEA's handoff injected
```

### What NOT to Build

- Gate enforcement logic (that's 143-8)
- Multi-phase loop orchestration / retry logic (future story)
- Changes to existing handoff CLI commands (`pf handoff complete-phase`, `pf handoff marker`)
- Changes to native agent `.md` files
- BikeRack integration

## Scope Boundaries

**In scope:**
- Chain function: given a subagent result + current phase, determine next phase/agent and build spawn config
- Handoff document path extraction from SUBAGENT_RESULT
- Handoff document existence validation
- Next-phase resolution from workflow YAML (phase name → next phase name + agent)
- Integration with existing `build_spawn_config(prior_handoff_path=...)`
- Error cases: missing handoff doc, unknown phase, no next phase (workflow complete)

**Out of scope:**
- Gate enforcement between phases (143-8)
- Actually spawning the subagent (SM does that via Agent tool — this story provides the config)
- Session file updates (existing `complete_phase()` handles that)
- Handoff document content validation against XML schema (143-8)

## AC Context

1. **SM can extract handoff document path from subagent result**
   - `parse_subagent_result()` returns dict — chain function reads `handoff_path` key
   - Edge case: result has no `handoff_path` → return error result, not exception
   - Edge case: `handoff_path` is relative — resolve against project root

2. **SM can validate handoff document exists on disk**
   - `validate_handoff_reference()` in `result.py` already does this — reuse it
   - Edge case: path exists but file is empty → treat as invalid

3. **SM can resolve next phase and agent from workflow definition**
   - Given current workflow + current phase, return `{next_phase, next_agent}`
   - Use workflow YAML phase list ordering (same source as `complete_phase.py`)
   - Edge case: current phase is last (finish) → return `{next_phase: None}` (workflow complete)
   - Edge case: unknown phase name → return error

4. **SM can build spawn config for next phase with prior handoff injected**
   - Chain function composes: resolve next → build_spawn_config(next_agent, prior_handoff_path)
   - Returns ready-to-use config dict for the Agent tool
   - Edge case: next agent has no native definition → return error from build_spawn_config

5. **Chain function returns result objects, never throws**
   - All paths return `{success: bool, data?: dict, error?: str}`
   - Caller (SM) decides what to do with errors
