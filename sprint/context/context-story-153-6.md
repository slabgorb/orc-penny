# Story 153-6 Context

## Title
sm-setup doesn't create sprint/context/context-story-{ID}.md but TEA on-activation expects it — gate sm-setup-exit doesn't enforce; either create or stop requiring

## Type
bug (P2, 3 points, tdd workflow)

## Repo
`pennyfarthing/` (inlined framework source). Base branch: `develop`.

## Problem
The TDD workflow defines a gate `tea-context` (RED phase entry gate) that validates story context via `pf check` and expects a context file at `sprint/context/context-story-{ID}.md` to exist before TEA activation. However, `sm-setup` does not create this file, and the `sm-setup-exit` gate does not enforce its creation or block the workflow if it's missing.

This creates a gap in the setup pipeline:
1. SM runs setup and writes the session file + branch
2. SM completes and transitions to RED phase
3. TEA is activated and immediately fails on `tea-context` entry gate because the expected context file does not exist
4. The workflow stalls, waiting for manual context-file creation

Root cause: either (a) `sm-setup` should create the context file as part of setup, or (b) the requirement for the context file should be removed from the `tea-context` gate. The decision impacts both the gate definition and sm-setup behavior.

Symptom: The workflow gap was discovered when setting up story 153-6 itself — the missing file would have blocked TEA on-activation.

## Scope

**In scope:**
1. Decide whether the context file is a requirement or optional:
   - **Option A (Create):** sm-setup generates `sprint/context/context-story-{STORY_ID}.md` with story metadata, technical approach, and acceptance criteria.
   - **Option B (Stop requiring):** Remove the context-file requirement from the `tea-context` entry gate; TEA reads context from the session file only.
2. If Option A (Create):
   - sm-setup generates the context file with a standard template (metadata, approach, acceptance criteria).
   - File is generated from story fields (title, description, acceptance_criteria) in epic YAML.
   - Update `sm-setup-exit` gate to enforce successful context-file creation (add recovery action for `context-file-created`).
3. If Option B (Stop requiring):
   - Remove or modify `tea-context` gate to not validate the context file.
   - Simplify the entry gate — TEA only needs the session file.
4. Document the decision in the session file under "Technical Approach."

**Out of scope:**
- Changing the session file format (that was story 153-1).
- Changing the branch-creation behavior (that was story 153-2).
- Changes to other gates or workflow phases.

## Acceptance Criteria

1. **Decision Made:** Session file documents whether the story implements Option A (create) or Option B (stop requiring).
2. **If Option A (Create):**
   - sm-setup generates `sprint/context/context-story-{STORY_ID}.md` at activation time.
   - Context file includes metadata section (Story ID, title, type, points, workflow, repo).
   - Context file includes technical approach (problem, scope, approach hints).
   - Context file includes acceptance criteria from epic YAML.
   - sm-setup-exit gate verifies context-file creation and fails if it's missing.
   - sm-setup completes with context file written and gate passing.
3. **If Option B (Stop requiring):**
   - `tea-context` entry gate is removed or modified to not require the context file.
   - TEA can activate immediately after SM finish without a pre-existing context file.
   - Session file documents that context comes from session file only.
4. **No workflow stalls:** After setup, TEA on-activation does not fail due to missing context files.
5. **Tests verify:**
   - SM setup creates the expected artifact (context file OR no-gate-requirement).
   - TEA can activate without manual intervention.
   - Workflow transitions cleanly from setup to RED.

## Approach Hints (non-binding)

- The `tea-context` entry gate is defined in `tdd.yaml` (phase "red" has an `entry_gate`).
- The session file is written by sm-setup in `.session/{STORY_ID}-session.md`.
- The context file template can be inspired by existing context files in `sprint/context/context-story-*.md`.
- Story metadata (title, description, acceptance_criteria) is available from the epic shard YAML and session file.
- sm-setup lives in `pennyfarthing-dist/agents/native/sm-setup.md` or similar (check the agent definition).
- The gate logic for `tea-context` lives in `pennyfarthing-dist/gates/tea-context.md` or similar.

## Test Strategy (RED targets)

1. sm-setup on a 3-point story → context file created (or gate requirement removed) before TEA activation.
2. Context file (if created) includes all required sections: metadata, approach, acceptance criteria.
3. TEA on-activation passes the `tea-context` entry gate without manual file creation.
4. Workflow transitions cleanly from setup to RED phase.
5. Session file documents the decision (create vs. stop requiring).

## Out-of-band notes

- Part of the epic 153 framework-reliability sweep sourced from downstream usage (`oq-1`, `oq-2`).
- Sibling stories: 153-1 (session-file location, done), 153-2 (branch-strategy, done), 153-3 (CLI surface, done), 153-4 (shard-file commands, done), 153-5 (context validators, done).
- This story's setup process itself exercised the gap — the missing context file would have blocked downstream workflow testing.
