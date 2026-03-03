# Story 136-28: Fix pf sprint story add --repos flag not persisting repos field

**Story ID:** 136-28
**Jira Key:** MSSCI-16110
**Date Started:** 2026-03-03
**Assignee:** keith.avery@1898andco.io
**Status:** in_progress
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing

---

## Story Context

Fix the `pf sprint story add --repos` flag so that the repos field is persisted to the sprint YAML when a new story is created.

## Branch Information

- **Repo:** pennyfarthing
- **Base Branch:** develop
- **Feature Branch:** fix/136-28-fix-repos-flag

## Acceptance Criteria

- [ ] `pf sprint story add --repos <repos>` persists the repos field to the sprint YAML
- [ ] Verification that the field is present in the epic YAML after creation
- [ ] No regressions in other `pf sprint story add` flags

---

## SM Assessment

**Routing:** Trivial workflow (1-point bug fix) → Dev (Korben Dallas)

**Summary:** The `pf sprint story add --repos` flag is not persisting the repos field to the epic shard YAML. The fix is in the `pf` CLI story-add code path — likely in `pennyfarthing-dist/pf/` where story creation writes to YAML. Dev should trace the `--repos` argument through the CLI to where it writes to the shard file and ensure it's included in the story dict.

**Scope:** pennyfarthing repo only. Single bug fix in the pf CLI Python code.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_add.py` - Added `repos` param to `add_story()`, included in fields dict, wired through CLI epic mode call

**Tests:** Functional verification passed (add story with --repos, read back, repos field present)
**Branch:** fix/136-28-fix-repos-flag (pushed)

**Handoff:** To Reviewer (Zorg) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** CLI `--repos` → `story_add_command` → `add_story(repos=...)` → `fields["repos"]` → `CommentedMap` → `write_sprint()` → YAML (safe — ruamel handles escaping)
**Pattern observed:** Follows identical pattern to `jira` optional field at `story_add.py:112-115`
**Error handling:** Validation-then-rollback pattern at `story_add.py:134-137` unaffected by new field
**Tests:** 44/44 passing (1 pre-existing failure on `develop`: priority case sensitivity unrelated)

**Handoff:** To Ruby Rhod (SM) for finish-story

## Delivery Findings

<!-- Dev findings below -->
### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): `add_story()` docstring missing `repos` param description. Affects `pennyfarthing-dist/src/pf/sprint/story_add.py` (add repos to Args section). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Pre-existing `test_cli_with_priority_option` test failure — Click `case_sensitive=False` lowercases priority values. Affects `pennyfarthing-dist/src/pf/sprint/story_add.py:281` (normalize priority to uppercase after Click parsing). *Found by Reviewer during code review.*

## Notes

Session created for SM-setup phase.