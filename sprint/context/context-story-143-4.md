---
parent: context-epic-143.md
workflow: tdd
---

# Story 143-4: Adapt pf prime for subagent-compatible context output

## Business Context

Native subagents (from 143-1/2/3) have their own agent definitions baked into `.claude/agents/*.md` files. When SM spawns a subagent via the Agent tool, the agent definition is already loaded by Claude Code itself — Prime should NOT re-inject it. However, subagents still need dynamic context that only Prime can provide: session state, sprint info, repos topology, sidecars, and persona.

This story adds a new output mode to Prime that produces context optimized for native subagent consumption — excluding components that the agent definition already provides, and formatting output for injection into an Agent tool prompt rather than the main conversation.

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/prime/cli.py` | Add `--subagent` flag or new tier, wire up subagent output path |
| `pennyfarthing-dist/src/pf/prime/tiers.py` | Add SUBAGENT tier with appropriate component set |
| `pennyfarthing-dist/src/pf/prime/loader.py` | May need new loader for story context file |
| `pennyfarthing-dist/src/pf/prime/models.py` | May need to extend ContextTier enum |

### Patterns to Follow

- **Tiered context pattern:** Prime already has FULL/REFRESH/HANDOFF/MINIMAL tiers in `tiers.py`. The subagent tier follows the same pattern — define which components to include, load them, estimate tokens.
- **Component architecture:** Each context piece (agent def, persona, sprint, session, sidecars) is a separate loader function in `loader.py`. Compose the subagent tier from existing loaders.
- **CLI flag pattern:** Existing `--tier` option accepts string values. Either add SUBAGENT as a new tier choice, or add a separate `--subagent` boolean flag.

### What NOT to Include in Subagent Output

The native agent `.md` file already contains:
- Agent definition (role, discipline, workflow)
- Tool restrictions (YAML frontmatter)

So the subagent tier should **exclude**:
- `agent_definition` component
- `behavior_guide` component (agent .md files include relevant guidance)
- `soul` component (can be loaded via CLAUDE.md)
- `output_style` component

### What TO Include in Subagent Output

- `persona` — Character voice (subagent needs this; it's not in the .md file)
- `sprint_context` — Current sprint info
- `repos_topology` — File ownership, symlinks, never-edit zones
- `session_header` + `session_assessment` — Story context and last assessment
- `sidecars` — Agent-specific patterns, gotchas, decisions
- `story_context` — Story context document from `sprint/context/` (NEW loader needed)
- `workflow_state` — Current workflow/phase state

### Dependencies

- Story context files are at `sprint/context/context-story-{id}.md` — loader needs to find the right one based on session
- Sidecars are at `.pennyfarthing/sidecars/{agent}/` — existing loader works
- Persona loading already has `format_persona_compressed` for reduced output

## Scope Boundaries

**In scope:**
- New SUBAGENT context tier in `tiers.py` with appropriate component set
- CLI support to invoke the new tier (`--tier subagent` or `--subagent` flag)
- Text output mode for subagent context (injected into Agent tool prompt)
- Story context loader (reads `sprint/context/context-story-{id}.md` based on session)
- Token estimation for new tier

**Out of scope:**
- SM spawning logic (143-6)
- Handoff document format (143-5)
- JSON output mode for subagent tier (can be added later)
- Changes to existing tiers (FULL/REFRESH/HANDOFF/MINIMAL)
- Changes to native agent `.md` files
- BikeRack integration for subagent context

## AC Context

1. **New SUBAGENT tier exists in ContextTier enum and is selectable via CLI**
   - `pf prime tea --tier subagent` produces output
   - The tier enum value is added to `ContextTier` in `tiers.py`
   - The CLI `--tier` choice list includes "subagent"
   - Edge case: What if agent_name is not provided? Should error clearly.

2. **Subagent tier excludes agent definition, behavior guide, soul, output style**
   - These are already in the native `.md` file
   - Verify by comparing output of `--tier full` vs `--tier subagent` — subagent should be significantly smaller

3. **Subagent tier includes persona, sprint, repos, session, sidecars, story context**
   - Persona: Uses `format_persona_output` (full, not compressed — subagent has room)
   - Sprint: Brief sprint info (name, goal, progress)
   - Repos topology: Full topology from repos.yaml
   - Session: Header + last assessment
   - Sidecars: All sidecar files for the agent
   - Story context: Content of `sprint/context/context-story-{id}.md` where id comes from session

4. **Story context loader finds the right file based on active session**
   - Reads session file to get story ID
   - Looks up `sprint/context/context-story-{story_id}.md`
   - Returns content or None if not found
   - Edge case: Session exists but no context file → graceful None, not error

5. **Output is plain text suitable for injection into Agent tool prompt**
   - Section headers with `#` markdown
   - No JSON wrapping (text mode)
   - Compact but readable

6. **Token estimate for subagent tier is reasonable (~1500-2500 tokens)**
   - Smaller than FULL (~4000) since it excludes agent def + guides
   - Larger than HANDOFF (~700) since it includes session + sidecars + story context
