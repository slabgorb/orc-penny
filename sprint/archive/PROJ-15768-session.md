# Story 132-3: Automate changelog comparison link updates

## Story Details
- **ID:** 132-3
- **Jira Key:** PROJ-15768
- **Workflow:** trivial
- **Assignee:** Keith Avery

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-27T11:54:52Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-27T00:00:00Z | 2026-02-27T11:35:26Z | 11h 35m |
| implement | 2026-02-27T11:35:26Z | 2026-02-27T11:39:59Z | 4m 33s |
| review | 2026-02-27T11:39:59Z | 2026-02-27T11:44:55Z | 4m 56s |
| implement | 2026-02-27T11:44:55Z | 2026-02-27T11:53:13Z | 8m 18s |
| review | 2026-02-27T11:53:13Z | 2026-02-27T11:54:52Z | 1m 39s |
| finish | 2026-02-27T11:54:52Z | - | - |

## SM Assessment

**Story:** 132-3 — Automate changelog comparison link updates
**Points:** 1 | **Workflow:** trivial | **Epic:** 132 (Release Workflow Hardening)

**Setup complete.** Jira claimed (PROJ-15768), session created, feature branch `feat/132-3-automate-changelog-comparison-link` cut in `pennyfarthing/` repo. Routing to Dev for implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/workflows/release/steps/step-03-changelog.md` - Replace manual link instructions with changelog-links.sh --fix call
- `pennyfarthing-dist/gates/release-ready.md` - Add changelog-links-valid check to release gate
- `pennyfarthing-dist/scripts/git/release.sh` - Auto-validate and fix changelog links during pre-flight

**Tests:** N/A (markdown and shell script changes, validated manually with `changelog-links.sh --validate`)
**Branch:** feat/132-3-automate-changelog-comparison-link (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Auto-fix creates uncommitted changes after clean-tree pre-flight. `git checkout` can fail. | `release.sh:176-178` | Replace auto-fix with error/exit. User should run `--fix` manually. |
| [LOW] | Validation output suppressed — user can't see what's wrong. | `release.sh:172` | Remove `> /dev/null 2>&1` |

**Data flow traced:** release.sh pre-flight (clean tree check) → new code (auto-fix dirties tree) → git checkout (fails on dirty tree). `deploy.sh` is safe because it commits immediately after fix.
**Pattern observed:** Self-contradicting invariant — script enforces clean tree then breaks it at `release.sh:134` vs `release.sh:177`.
**Error handling:** Auto-fix path has no commit step, unlike deploy.sh which commits at line 290.

**Handoff:** Back to Dev for fixes (lint/format category — no new tests needed)

## Dev Assessment (Round 2)

**Fixes Applied:**
- `pennyfarthing-dist/scripts/git/release.sh` - Replaced auto-fix with validate-only + error exit. Removed output suppression so user sees diagnostic details.

**Both review findings addressed:**
1. [HIGH] Auto-fix replaced with `error` call — script exits cleanly, no tree mutation
2. [LOW] Output suppression removed — `--validate` output flows to terminal

**Branch:** feat/132-3-automate-changelog-comparison-link (pushed)

**Handoff:** To Reviewer for re-review

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED
**Data flow traced:** release.sh → pre-flight chain → changelog-links.sh --validate (read-only) → exit 0 (continue) or exit 1 → error() → exit 1 (terminate). No file mutation on any path.
**Pattern observed:** New check follows identical pre-flight guard pattern as workspace dep check at `release.sh:159-164`.
**Error handling:** `error()` at `release.sh:77` does `echo + exit 1`. Script terminates before git operations if links invalid.
**Previous findings:** Both addressed — auto-fix removed, output suppression removed.

**Handoff:** To SM for finish-story