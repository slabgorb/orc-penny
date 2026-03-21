---
story_id: "150-15"
jira_key: "MSSCI-16655"
epic: "MSSCI-16564"
workflow: "tdd"
---
# Story 150-15: pf sprint story split — decompose stories with dependency tracking

## Story Details
- **ID:** 150-15
- **Jira Key:** MSSCI-16655
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 3

## Acceptance Criteria

1. `pf sprint story split STORY_ID` command exists and decomposes a story into sub-stories
2. User provides a split plan (number of sub-stories, titles, point allocation) interactively or via flags
3. Sub-stories are created under the same epic with `depends_on` linking to the parent or siblings
4. Original story points are redistributed across sub-stories (total must equal original)
5. Original story status transitions to `split` (or equivalent) with references to child stories
6. `--dry-run` flag previews the split without making changes

## Story Context

This story adds a `pf sprint story split` CLI command that lets SM or the user decompose a story that turned out to be too large. The command handles the bookkeeping: creating child stories under the same epic, redistributing points, setting up `depends_on` relationships, and marking the parent.

**Related patterns:**
- `pf sprint story add` — creates stories under an epic (reuse for child creation)
- `pf sprint story update` — updates story fields (reuse for parent status)
- Sprint YAML is sharded — stories live in `sprint/epic-{ref}.yaml` files
- `write_sprint()` from `yaml_io` handles shard writes

**Implementation should follow existing CLI patterns in `pennyfarthing-dist/src/pf/sprint/`.**

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-21T11:24:18Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-21T11:11:31Z | 2026-03-21T11:13:35Z | 2m 4s |
| red | 2026-03-21T11:13:35Z | 2026-03-21T11:16:43Z | 3m 8s |
| green | 2026-03-21T11:16:43Z | 2026-03-21T11:19:33Z | 2m 50s |
| spec-check | 2026-03-21T11:19:33Z | 2026-03-21T11:20:23Z | 50s |
| verify | 2026-03-21T11:20:23Z | 2026-03-21T11:21:01Z | 38s |
| review | 2026-03-21T11:21:01Z | 2026-03-21T11:23:53Z | 2m 52s |
| spec-reconcile | 2026-03-21T11:23:53Z | 2026-03-21T11:24:18Z | 25s |
| finish | 2026-03-21T11:24:18Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings

## Sm Assessment

**Story:** 150-15 — pf sprint story split with dependency tracking
**Workflow:** TDD (3 pts) → TEA → Dev → Reviewer
**Repos:** pennyfarthing (targets develop)
**Branch:** feat/150-15-sprint-story-split
**Jira:** MSSCI-16655 (claimed, In Progress)

**Routing:** TEA for RED phase.

**Key context for TEA:**
- Existing CLI patterns in `pennyfarthing-dist/src/pf/sprint/` — especially `story_add.py` for creating stories and `story_update.py` for updating fields
- Sprint YAML is sharded per the SM sidecar pattern — use `load_sprint()`/`write_sprint()` from `yaml_io`
- The `depends_on` field may not exist yet in the story schema — TEA should check

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec. → ✓ ACCEPTED by Reviewer: correct — implementation matches all 6 ACs.

### Reviewer (audit)
- No additional deviations found.

### Architect (reconcile)
- No additional deviations found. All 6 ACs implemented as specified. The one trivial spec ambiguity (AC3 "parent or siblings") was resolved correctly — parent-only linking is the right design for split operations.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_split.py` — `split_story()` function + `story_split_command` Click command
- `pennyfarthing-dist/src/pf/sprint/validator.py` — added `split` to `VALID_STORY_STATUSES`
- `pennyfarthing-dist/src/pf/sprint/yaml_io.py` — added `split_into` to `STORY_KEY_ORDER`
- `pennyfarthing-dist/src/pf/sprint/cli.py` — registered `story.split` command

**Tests:** 23/23 passing (GREEN)
**Branch:** feat/150-15-sprint-story-split (pushed)

**AC Coverage:**
- AC1: `split_story()` creates sub-stories under same epic ✓
- AC2: Interactive prompts via Click command, `--into` flag for count ✓
- AC3: `depends_on` links children to parent ✓
- AC4: Points sum validated, rejects mismatch and zero ✓
- AC5: Parent status → `split`, `split_into` field records child IDs ✓
- AC6: `--dry-run` previews without modifying files ✓

**Handoff:** To next phase

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** 1 (trivial)

- **AC3 says "parent or siblings", code links to parent only** (Ambiguous spec — Behavioral, Trivial)
  - Spec: "Sub-stories are created under the same epic with `depends_on` linking to the parent or siblings"
  - Code: All children get `depends_on: parent_id`, no sibling linking
  - Recommendation: A (Update spec) — Parent-only linking is correct for split. Sibling deps would create circular complexity. The "or siblings" was aspirational, not required.

**Decision:** Proceed to verify. Implementation is clean, follows existing patterns (`story_add.py`, `read_sprint`/`write_sprint`), all ACs substantively met.

## Tea Verify Assessment

**Verification:** PASS
**Tests:** 23/23 passing
**Regressions:** None

**Handoff:** To Queen of Hearts (Reviewer) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 1 | confirmed — unused `find_epic` import |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** **Yes** (2 returned, 7 disabled via settings)
**Total findings:** 1 confirmed, 0 dismissed, 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

### Observations

1. [VERIFIED] Result dict pattern throughout `split_story()` — all error paths return `{success: False, error: ...}`, success paths return `{success: True, child_ids: [...]}`. Complies with SOUL.md #10. Evidence: story_split.py lines 63, 68, 74, 85, 93, 104, 115, 155.

2. [VERIFIED] Reuses existing infrastructure — `generate_story_id()` from story_add.py, `find_story()` from loader.py, `read_sprint()`/`write_sprint()` from yaml_io.py, `STORY_KEY_ORDER` for canonical key ordering. No reinvented patterns. Complies with SOUL.md #2.

3. [VERIFIED] Dry-run returns before write — line 115 returns early with `dry_run: True` flag, `write_sprint()` never called. Test `test_dry_run_does_not_modify_file` proves this by comparing file content before/after.

4. [VERIFIED] Guard logic correct — rejects done/split status (line 82-85), rejects points mismatch (line 93-99), rejects zero-point children (line 72-78), rejects < 2 sub-stories (line 66-69). All return error dicts, never throw.

5. [LOW] Unused import: `find_epic` imported at line 18 but never called. `_find_story_and_epic()` iterates epics directly. Should be removed.

6. [MEDIUM] Placeholder trick for ID generation (lines 101-112): creates temporary CommentedMap placeholders, appends to epic stories, then pops them. Correct but couples to `generate_story_id()`'s internal implementation detail (it counts existing stories). Acceptable for now — the alternative would be passing an offset parameter, which is over-engineering.

7. [SEC] Security clean — no path traversal risk (sprint_path comes from CLI arg or project root), no injection (YAML library handles escaping), no secrets, no network calls.

### Devil's Advocate

What if the placeholder pop (lines 110-112) goes wrong? If `generate_story_id` throws between appends, the epic's stories list is corrupted with partial placeholders. But `generate_story_id` only does dict lookups and int parsing — it can't throw in normal operation. And even if it did, the data isn't written to disk until `write_sprint()` at line 153, so the file is safe.

What if someone calls `split_story` concurrently? Two processes could read the same YAML, generate overlapping IDs, and write conflicting children. This is the same TOCTOU risk as `story_add` — not new to this PR, and the CLI is single-user.

What about the `remaining` auto-assignment in the CLI (line 218)? If the user over-allocates points to earlier children, `remaining` goes negative, and the last child gets negative points. But `split_story` validates `points <= 0` at line 73, so it fails safely with a clear error.

**Decision:** APPROVED. One low finding (unused import) — non-blocking.

**Handoff:** To the Mad Hatter (SM) for finish-story

## Tea Assessment

**Test file:** `pennyfarthing-dist/src/pf/tests/test_150_15_story_split.py`
**Tests:** 23 (all RED — `ModuleNotFoundError: No module named 'pf.sprint.story_split'`)
**Branch:** feat/150-15-sprint-story-split

### Tests by AC

| AC | Tests | What they verify |
|----|-------|-----------------|
| AC1 | 4 | `split_story()` and `story_split_command` importable, returns result dict, creates sub-stories with correct titles |
| AC2 | 2 | Sub-story IDs follow epic sequence, account for existing stories |
| AC3 | 2 | `depends_on` links children to parent, children in same epic |
| AC4 | 3 | Points sum equals original, rejects mismatch, rejects zero-point children |
| AC5 | 3 | Parent status → `split`, parent has `split_into` field, `split` is a valid status |
| AC6 | 2 | Dry-run returns success, does not modify file |
| Errors | 7 | Not found, empty list, single story, done/split guard, field inheritance |

### Guidance for Dev

1. **Create `pf/sprint/story_split.py`** with `split_story()` function and `story_split_command` Click command
2. **Follow patterns from `story_add.py`** — reuse `generate_story_id()`, `read_sprint()`/`write_sprint()`, `find_story()`, `find_epic()`
3. **Add `"split"` to `VALID_STORY_STATUSES`** in `validator.py`
4. **Add `"split_into"` to `STORY_KEY_ORDER`** in `yaml_io.py`
5. **Register command** in `cli.py`: `story.add_command(story_split_command, "split")`
6. The sub-stories dict format is `{"title": str, "points": int}` — simple input, no optional fields
7. Children inherit `repos`, `workflow` from parent, get `status: backlog` and `depends_on: parent_id`

**Handoff:** To the White Rabbit (Dev) for GREEN phase