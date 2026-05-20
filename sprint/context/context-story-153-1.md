# Story 153-1 Context

## Title
sm-setup writes session files to `.session/` (not `sprint/`); migrate legacy session files

## Type
bug (P0, 2 points, tdd workflow)

## Repo
`pennyfarthing/` (inlined framework source). Base branch: `develop`.

## Problem
The `sm-setup` subagent writes new story session files to the wrong directory in downstream projects (`oq-1`, `oq-2` reported it). Canonical path is `.session/{story-id}-session.md` — that's what `pf prime`, gates (`sm-setup-exit`), `pf handoff`, and runtime scripts read.

Symptom: a story is set up successfully, but the next agent activation can't find a session file and either fails the gate or falls back to no-context behavior. The wrong location collects orphan files no automation reads.

## Scope

**In scope:**
1. **New writes** — `sm-setup` writes to `.session/{story-id}-session.md`. No fallback path, no duplicate write.
2. **Migration** — detect legacy session files in the wrong location and relocate (or copy + leave a stub) so existing in-flight stories keep working after the fix lands. Idempotent: re-running the migrator on already-fixed state does nothing.

**Out of scope:**
- Schema/format changes to the session file
- Changing the canonical `.session/` path
- Adding new fields to the session frontmatter
- Context file creation (that's story 153-6)

## Acceptance Criteria

1. New session files created by `sm-setup` land at `.session/{story-id}-session.md` — verified by an automated test.
2. A migration helper exists that:
   - Detects session files written to the legacy/wrong location.
   - Relocates them to `.session/` without data loss.
   - Is idempotent (safe to re-run on clean state).
   - Does not overwrite an existing `.session/{story-id}-session.md` (collision → log + skip, do not destroy).
3. Existing sm-setup behavior (frontmatter, content, branch creation, workflow routing) is unchanged.
4. New tests cover: write-path correctness, migration happy path, migration idempotency, migration collision-skip.

## Approach Hints (non-binding)

- The sm-setup subagent is defined at `pennyfarthing-dist/agents/sm-setup.md`.
- Session-file writing likely happens via a helper module under `pennyfarthing-dist/src/pf/` (look for `session.py` / `sprint/session.py` / similar) or directly in the subagent template.
- `pf prime` is the canonical consumer — search there for the expected path.
- Migration should be a callable command (e.g. `pf sprint session migrate` or part of `pf doctor`) so users can run it once; or a startup auto-migration triggered by `pf prime` (TEA can decide which is cleaner).

## Out-of-band notes

- Story 153-6 covers the related-but-distinct problem of missing `sprint/context/context-story-{ID}.md` creation. Keep these fixes separate.
- This story is part of the framework reliability sweep (epic 153) that came back from downstream usage (`oq-1`, `oq-2`).
