# Plan: Wire Tandem Backseat Agent Spawning

## Context

Tandem workflows (`tdd-tandem`, `bdd-tandem`) define `tandem:` blocks on phases to pair a background observer ("backseat") with the primary agent. All infrastructure was built across Epics 94-97 (13 stories, all marked done): workflow YAML parsing, observation file writer, file-watch detection, bell mode injection hook, CLI statusline, Cyclist TandemPortrait. However, the **final wire** — telling agents to actually spawn the backseat — was deferred during Story 95-2 review as "a wiring task, not lifecycle logic" and no follow-up story was created.

**Result:** Tandem workflows load, handoff detects the partner, session shows `**Tandem:** architect (file-watch)`, but no backseat agent is ever spawned. The primary agent works alone.

**Root cause:** Agent prompt files (`dev.md`, `tea.md`, `reviewer.md`, `ux-designer.md`) contain zero instructions about tandem. They don't know what to do with the tandem info they receive.

**Fix:** Add tandem spawning instructions to agent prompts + create a backseat agent prompt template. No TypeScript changes needed — the spawning happens via the Task tool inside the Claude Code session, not in library code.

## Files to Create

### 1. `pennyfarthing/pennyfarthing-dist/guides/tandem-protocol.md`

Shared reference guide documenting the tandem observation loop. Contains:
- Overview of the push-based observation model (not consultation — ADR-0012 was superseded by the Tandem Mode PRD)
- How to detect tandem from session (`**Tandem:** {partner} ({scope})`)
- How to spawn backseat (Task tool params, model: haiku, run_in_background: true)
- Observation file format reference
- How bell mode injection delivers observations (automatic via PostToolUse hook)
- How to surface observations in own voice (`"{Persona} suggests..."`)
- Cleanup before handoff (terminate backseat task)
- Prerequisite: `bell_mode: true` in `.pennyfarthing/config.local.yaml`

### 2. `pennyfarthing/pennyfarthing-dist/agents/tandem-backseat.md`

Prompt template for the backseat agent. NOT a full agent definition (no `<helpers>`, `<handoff-gate>`, etc.) — this is a background subagent prompt. Contains:
- Role: background observer, advisory only
- Scope-specific behavior:
  - **file-watch:** Poll `git diff` periodically + use Glob/Grep to detect changes; write observations about pattern drift, duplication, AC gaps
  - **tool-watch:** Read tool call data from `.session/{story-id}-tool-log.md` (written by PostToolUse hook); observe test results, edit patterns
  - **context-watch:** Periodically summarize primary agent's progress from session file
- Observation file format (header + entries with `## [HH:MM] Observation` blocks)
- Selectivity guidance: only note things that matter (pattern drift, bugs, AC misalignment, security concerns); don't comment on every file save
- Tone: advisory, concise (1-3 sentences per observation)
- The backseat uses `initObservationFile()` format for the header and `appendObservation()` format for entries — but writes them directly via markdown (it's a Claude agent, not a TypeScript process)

## Files to Modify

### 3. `pennyfarthing/pennyfarthing-dist/agents/dev.md`

**Insert after `</on-activation>` (line 71), before `<delegation>` (line 72):**

Add `<tandem-protocol>` section with:
- On activation: check session for `**Tandem:**` line
- If present: spawn backseat via Task tool (run_in_background: true, model: haiku)
  - Prompt includes: backseat agent definition from `tandem-backseat.md`, story context, scope, observation file path, persona from theme
  - The primary agent reads the theme YAML to get the backseat partner's character name and passes it in the prompt
- During work: bell mode hook automatically injects observations — surface them in own voice
- Before handoff: terminate backseat (if spawned) before spawning handoff subagent

**Update `<helpers>` table (line 28-32):** Add `tandem-backseat` row: `| tandem-backseat | Background observer (spawned if tandem active) |`

**Update `<handoff-gate>` (line 109-115):** Add checklist item: `- [ ] Terminate tandem backseat (if active)`

### 4. `pennyfarthing/pennyfarthing-dist/agents/tea.md`

Same pattern as dev.md:
- Insert `<tandem-protocol>` after `</on-activation>` (line 70), before `<delegation>` (line 72)
- Update `<helpers>` table (line 25-32)
- Update `<handoff-gate>` (line 110-116)

### 5. `pennyfarthing/pennyfarthing-dist/agents/reviewer.md`

Same pattern, with one nuance — reviewer already spawns `reviewer-preflight` in background on activation:
- Insert `<tandem-protocol>` after `</on-activation>` (line 89), before `<review-checklist>` (line 91)
- Tandem spawn happens alongside (not instead of) preflight spawn
- Update `<helpers>` table (line 29-36)
- Update `<handoff-gate>` (line 123-130)

### 6. `pennyfarthing/pennyfarthing-dist/agents/ux-designer.md`

Same pattern:
- Insert `<tandem-protocol>` after `</on-activation>` (line 73), before `<workflow-participation>` (line 75)
- Update `<helpers>` table (line 20-26)
- Note: UX Designer has a simpler prompt structure (no `<handoff-gate>` with checklist), so cleanup instruction goes in the `<handoffs>` / `<exit>` section

## `<tandem-protocol>` Section Content (shared across all 4 agents)

```markdown
<tandem-protocol>
## Tandem Backseat Observer

On activation, check session file for a `**Tandem:**` line (e.g., `**Tandem:** architect (file-watch)`).

**If tandem is configured:**

1. **Resolve backseat persona** from theme:
   ```bash
   THEME=$(yq '.theme' .pennyfarthing/config.local.yaml)
   PARTNER_CHARACTER=$(yq ".agents.{PARTNER}.character" .pennyfarthing/personas/themes/${THEME}.yaml)
   ```

2. **Initialize observation file:**
   Create `.session/{STORY_ID}-tandem-{PARTNER}.md` with header:
   ```markdown
   # Tandem Observations: {STORY_ID}
   **Observer:** {PARTNER} ({PARTNER_CHARACTER})
   **Phase:** {PHASE}
   **Started:** {ISO_TIMESTAMP}

   ---
   ```

3. **Spawn backseat** (Task tool):
   ```yaml
   subagent_type: "general-purpose"
   model: "haiku"
   run_in_background: true
   prompt: |
     Read .pennyfarthing/agents/tandem-backseat.md for your instructions.

     PARTNER: "{PARTNER}"
     CHARACTER: "{PARTNER_CHARACTER}"
     STORY_ID: "{STORY_ID}"
     SCOPE: "{SCOPE}"
     OBSERVATION_FILE: ".session/{STORY_ID}-tandem-{PARTNER}.md"
     SESSION_FILE: ".session/{STORY_ID}-session.md"
   ```

4. **During work:** Bell mode PostToolUse hook automatically detects new observations
   and injects them as `[Tandem] {CHARACTER}: {observation}`.
   When you receive a tandem injection, surface it naturally:
   *"{PARTNER_CHARACTER} suggests we extract this into an adapter."*

5. **Before handoff:** Terminate the backseat background task, then proceed
   with normal handoff sequence.

**If no `**Tandem:**` line in session:** Skip entirely — no-op.

See `.pennyfarthing/guides/tandem-protocol.md` for full protocol details.
</tandem-protocol>
```

## Backseat Agent Prompt Template Content

The `tandem-backseat.md` file is a prompt template (not a full agent definition). Key sections:

- **Identity:** You are `{CHARACTER}` ({PARTNER}), observing the primary agent's work
- **Scope behavior:**
  - `file-watch`: Run `git diff --stat` every 2-3 tool cycles. Use Grep/Glob to inspect changed files. Note pattern violations, duplication, missing error handling, AC drift
  - `tool-watch`: Check `.session/{STORY_ID}-tool-log.md` for recent tool calls. Note test failures, suspicious edit patterns, skipped files
  - `context-watch`: Read session file periodically. Note scope drift, AC coverage gaps
- **Writing observations:** Append to observation file using the `## [HH:MM] Observation` format
- **Selectivity:** Only write when you have something genuinely useful. A good backseat writes 3-6 observations per phase, not 30.
- **Tone:** Concise, advisory, specific. Reference file paths and line numbers.

## What NOT to Change

- `tandem-lifecycle.ts` — Leave as-is. It's a clean library module for future WheelHub integration
- `workflow-executor.ts` — Manages stepped workflows, not phased workflow phase transitions
- `workflow/index.ts` — No need to export tandem-lifecycle for this fix
- `bell-mode-hook.sh` / `bellmode_hook.py` — Already handle tandem injection correctly
- `observation-writer.ts` / `file-watch.ts` — Already implemented and tested
- Workflow YAML files — Already correct
- `handoff.md` / `sm-handoff.md` — Already detect and pass tandem info

## Verification

1. **Unit test:** Start a `tdd-tandem` workflow on a test story. At the green phase, Dev should:
   - Detect `**Tandem:** tea (file-watch)` in session
   - Spawn a background Haiku subagent
   - The backseat writes observations to `.session/{story}-tandem-tea.md`
   - Bell mode hook injects observations into Dev's context
   - Dev surfaces them: "The Caterpillar notes that..."

2. **Cleanup test:** When Dev hands off to Reviewer, the backseat task should be terminated before the handoff subagent runs.

3. **No-op test:** Run a standard `tdd` workflow (no tandem). Agents should detect no `**Tandem:**` line and skip the protocol entirely.

4. **Prerequisite check:** Verify `bell_mode: true` in `.pennyfarthing/config.local.yaml`. If not enabled, tandem observations will be written but never injected.

## Execution Order

1. Create `tandem-backseat.md` (backseat prompt template)
2. Create `tandem-protocol.md` (shared guide)
3. Modify `dev.md` (add `<tandem-protocol>`, update helpers/gate)
4. Modify `tea.md` (same pattern)
5. Modify `reviewer.md` (same pattern, alongside preflight)
6. Modify `ux-designer.md` (same pattern, simpler structure)
7. Verify bell_mode is enabled in config
8. Manual test with a tandem workflow
