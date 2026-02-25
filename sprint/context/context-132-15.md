# Context: 132-15 Add practice story to guided tour sprint step

## Goal

Transform step-04-sprint from a passive explanation of sprint concepts into a hands-on exercise where the developer creates a practice story, claims it, starts a session, makes a change, and completes it. The developer should *feel* the sprint lifecycle instead of just reading about it. This is the "learn by doing" upgrade to onboarding.

## Current State

`step-04-sprint.md` is explanation-only:

1. Explains the sprint/epic/story hierarchy
2. Runs `pf sprint status` and `pf sprint backlog` as read-only demonstrations
3. Shows `pf sprint story show <id>` for story details
4. Mentions Jira integration and the `/pf-sprint work` command
5. Offers a "Try It" switch option, but it only runs status/backlog commands -- no write operations
6. Has a deep-dive section covering YAML shards, epic lifecycle, archive process, and Jira sync

The step never creates, claims, transitions, or completes a story. The developer leaves step 4 knowing the vocabulary but never having touched the machinery.

## Technical Approach

### Practice Epic and Story

Create a dedicated practice epic and story dynamically during the tour. The epic uses a reserved ID namespace (`tour-practice`) that signals "this is a tour artifact" to any code that encounters it.

**Option A -- Temporary shard file (recommended):**
- Create `sprint/epic-tour-practice.yaml` with a single practice story
- Add the epic ref `tour-practice` to the current sprint's epics list
- On cleanup, remove the shard file and the ref from the sprint index
- Advantage: fully isolated, no risk of polluting real sprint data
- Disadvantage: requires write to `current-sprint.yaml` to register the epic ref

**Option B -- In-memory only (simulated):**
- Don't actually write to sprint YAML; simulate the commands with `--dry-run`
- Advantage: zero side effects
- Disadvantage: the developer doesn't *feel* the system working for real

Recommendation: Option A with a robust cleanup routine. The whole point is tactile learning.

### Practice Story Structure

```yaml
# sprint/epic-tour-practice.yaml
id: epic-tour-practice
title: "Guided Tour Practice Epic"
jira: null
status: active
tour_artifact: true
stories:
  - id: tour-practice-1
    title: "Practice: Add a comment to a file"
    points: 1
    priority: P3
    status: backlog
    workflow: trivial
    tour_artifact: true
```

Key fields:
- `tour_artifact: true` -- marker that allows tooling to identify and skip/clean tour data
- `workflow: trivial` -- skips TDD phases so the developer isn't dragged through RED/GREEN/REFACTOR on a practice task
- `jira: null` -- no Jira interaction; works in local-only mode
- Points and priority are minimal to avoid distorting velocity metrics

### Jira-less Mode

The practice flow must work without Jira configured:
- `story_add.py` already accepts `jira=None`
- `work.py`'s `start_work()` works with local YAML only
- `story_finish.py` handles missing Jira keys (skips Jira transitions)
- `story_transition.py` writes YAML first, then attempts Jira as best-effort

The only risk is `get_current_user_email()` in `work.py`'s `get_next_story()`, which calls the Jira client. The practice flow should use explicit story ID selection (`pf sprint work tour-practice-1`) rather than `next` to avoid this codepath.

### Cleanup Strategy

Cleanup runs at the end of the practice section (before moving to step 5) and also as a safety net in `step-05-config`:

1. Remove `sprint/epic-tour-practice.yaml` shard file
2. Remove `tour-practice` ref from `current-sprint.yaml` epics list
3. Remove any session file: `.session/tour-practice-1-session.md`
4. Remove any archive artifact: `sprint/archive/tour-practice-1-session.md`
5. Revert any git changes to practice files (if a branch was created)

Implement as a new helper: `pf tour cleanup` or a function in the guided-tour step itself. The step markdown should call it explicitly, and the gate should verify cleanup succeeded.

### Guard Rails

- The practice epic ID `tour-practice` is intentionally outside the numeric ID space used by real epics (e.g., `epic-63`, `epic-85`). No collision risk.
- Sprint validation (`validate_full_sprint`) needs to tolerate the `tour_artifact` field, or the field should be placed in a location the validator ignores.
- If the developer exits the tour mid-practice, the next tour resume or `pf sprint validate` should detect orphaned tour artifacts and offer cleanup.

## Practice Flow

The developer experiences these steps, guided by the orchestrator agent:

### Phase 1: Setup (automated by the tour)
1. Tour explains: "Let's create a practice story so you can try the workflow."
2. Tour creates `sprint/epic-tour-practice.yaml` and registers it in the sprint index.
3. Tour runs `pf sprint status` -- developer sees the new practice epic appear.
4. Tour runs `pf sprint backlog` -- developer sees the practice story in the backlog.

### Phase 2: Claim and Start (developer-driven with guidance)
5. Developer runs: `pf sprint work tour-practice-1`
   - Story status transitions: backlog -> in_progress
   - Session file created: `.session/tour-practice-1-session.md`
6. Tour shows the session file and explains its structure.

### Phase 3: Do the Work (developer-driven)
7. Tour instructs: "Add a code comment to any file -- this is your practice change."
8. Developer makes a trivial edit (e.g., adds `// Tour practice edit` to a file).
9. Tour explains: "In a real story, you'd run tests, get a review, and create a PR. For practice, we'll skip ahead."

### Phase 4: Complete (developer-driven with guidance)
10. Developer runs: `pf sprint story finish tour-practice-1`
    - Story status transitions: in_progress -> in_review -> done
    - Session file archived (or the tour intercepts and cleans up)
11. Tour runs `pf sprint status` -- developer sees the story marked done.

### Phase 5: Cleanup (automated by the tour)
12. Tour explains: "We'll clean up the practice story now."
13. Tour removes the practice epic shard, session artifacts, and the sprint index ref.
14. Tour runs `pf sprint status` -- developer confirms the practice data is gone.
15. Tour reverts the developer's practice file edit via `git checkout` on that file.

### Fallback: Simulated Mode
If write operations fail (permissions, validation errors, etc.), fall back to a "simulated" walkthrough that uses `--dry-run` flags and explains what *would* happen. The gate criteria should accept either real or simulated completion.

## Key Files

### Modify
| File | Change |
|------|--------|
| `pennyfarthing/pennyfarthing-dist/workflows/guided-tour/steps/step-04-sprint.md` | Add practice story section with setup, guided exercise, and cleanup phases |
| `pennyfarthing/pennyfarthing-dist/workflows/guided-tour/workflow.yaml` | Possibly add a variable for `practice_epic_id` |

### Create
| File | Purpose |
|------|---------|
| `pennyfarthing/pennyfarthing-dist/src/pf/tour/practice.py` | Practice story lifecycle: create_practice_epic(), cleanup_practice(), detect_orphaned_practice() |
| `pennyfarthing/pennyfarthing-dist/workflows/guided-tour/templates/epic-tour-practice.yaml` | Template for the practice epic shard (copied into `sprint/` at runtime) |

### Reference (read-only context)
| File | Why |
|------|-----|
| `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_add.py` | `add_story()` API for programmatic story creation |
| `pennyfarthing/pennyfarthing-dist/src/pf/sprint/work.py` | `start_work()` and `check_story()` for claiming stories |
| `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` | `finish_story()` for completing the practice story |
| `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_transition.py` | State machine transitions, Jira-optional behavior |
| `pennyfarthing/pennyfarthing-dist/src/pf/sprint/loader.py` | `load_sprint()`, `find_epic()`, shard merging |
| `pennyfarthing/pennyfarthing-dist/src/pf/sprint/yaml_io.py` | `read_sprint()`, `write_sprint()` for YAML manipulation |
| `pennyfarthing/pennyfarthing-dist/src/pf/sprint/validator.py` | `validate_full_sprint()` -- must tolerate tour artifacts |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Practice story pollutes sprint metrics/velocity | Medium | Medium | `tour_artifact: true` marker; exclude from velocity calculations; cleanup removes all traces |
| Cleanup fails mid-way, leaving orphaned shard | Medium | Low | Idempotent cleanup function; `pf sprint validate` detects orphans; step-05 runs cleanup as safety net |
| Developer exits tour mid-practice | High | Low | Session-start hook or tour resume detects orphaned practice artifacts and offers cleanup |
| Sprint validation rejects `tour_artifact` field | Medium | Medium | Either add `tour_artifact` as an allowed optional field in the schema, or place the marker in a comment/metadata block the validator ignores |
| `get_current_user_email()` fails without Jira | Low | Medium | Practice flow uses explicit story ID, never `next`; wrap Jira calls in try/except in practice path |
| Practice edit accidentally committed to real branch | Low | High | Practice flow does not create a branch or commit; cleanup reverts the file edit via `git checkout` |
| Concurrent tour runs collide on practice epic ID | Very Low | Low | Practice epic uses a fixed ID; if shard already exists, skip creation and reuse |

## Acceptance Criteria

- [ ] Running the guided tour step 4 creates a practice epic and story in sprint YAML
- [ ] Developer can claim the practice story with `pf sprint work tour-practice-1`
- [ ] Developer can make a trivial edit and complete the story with `pf sprint story finish tour-practice-1`
- [ ] `pf sprint status` shows the practice story progressing through backlog -> in_progress -> done
- [ ] All practice artifacts are cleaned up before proceeding to step 5
- [ ] The practice flow works without Jira configured (local-only mode)
- [ ] Sprint validation passes both during and after the practice exercise
- [ ] If the tour is interrupted mid-practice, resuming the tour or running cleanup detects and removes orphaned artifacts
- [ ] The "Try It" and "Dig In" switch options still work alongside the new practice section
- [ ] Existing step-04 explanatory content is preserved -- the practice section augments, not replaces
