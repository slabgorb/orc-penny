# Story 123-2: Automate changelog comparison link updates

**Jira:** PROJ-15367
**Epic:** 123 (Release Tooling Hardening)
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/123-2-automate-changelog-comparison-links
**Assignee:** keith.avery@slabgorb.io

## Acceptance Criteria

- [ ] Comparison links at the bottom of CHANGELOG.md are validated during release
- [ ] Version comparison links are automatically created for new releases
- [ ] Links remain consistent across releases

## Context

This story addresses technical debt in the release pipeline where comparison links at the bottom of CHANGELOG.md drifted during 11.x. The task is to automate the creation and validation of version comparison links during releases to prevent future drift.

This is part of Epic 123 (Release Tooling Hardening), which focuses on hardening the release pipeline after 11.3.x packaging failures. Story 123-1 (Package contents assertion test) has been completed; 123-2 is the next priority item.

Related issues and PRs: https://github.com/slabgorb/pennyfarthing-orchestrator#85

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/scripts/git/changelog-links.sh` - New script: parses version headers, generates/validates/fixes comparison links
- `scripts/deploy.sh` - Replace fragile sed-based link update with changelog-links.sh --fix call
- `package.json` - Wire --validate into prepublishOnly as publish gate
- `CHANGELOG.md` - Fix 17 missing links (11.x, 9.x-10.x series), reorder all 111 links
- `tests/unit/test_changelog_links.sh` - 10 assertions covering parse, validate, fix, print modes
- `tests/integration/test_changelog_gate.sh` - 4 assertions verifying wiring into deploy + prepublish

**Tests:** 14/14 passing (GREEN)
**Branch:** feat/123-2-automate-changelog-comparison-links (pushed)

**AC Coverage:**
- [x] Comparison links validated during release — `--validate` in prepublishOnly gate
- [x] Version comparison links automatically created — `--fix` called by deploy.sh
- [x] Links remain consistent — regenerated from headers, not sed pattern matching

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** CHANGELOG.md headers → BASH_REMATCH regex → VERSIONS array → generate_links() → file comparison/rewrite (safe — temp file pattern, no in-place sed on links)
**Pattern observed:** Header-first, links-second ordering in deploy.sh prevents VERSION file drift at `scripts/deploy.sh:245-254`
**Error handling:** set -euo pipefail propagates changelog-links.sh failures to abort release; graceful fallback for consumer installs at `scripts/deploy.sh:248-253`
**Findings:** 2 Low (no trap cleanup for temp files, no --repo-url test). No Critical or High.

**Handoff:** To SM for finish-story