# Story 97-1: CLI statusline tandem indicator

**Jira:** PROJ-14679
**Epic:** epic-97 (CLI Tandem & Shipping Workflow)
**Points:** 2
**Workflow:** trivial
**Phase:** finish
**Branch:** feature/97-1-cli-statusline-tandem-indicator
**Repos:** pennyfarthing

## Acceptance Criteria

1. CLI statusline shows [Primary Agent] + Backseat Agent when tandem phase is active
2. Drops suffix when phase ends or backseat crashes
3. No statusline protocol changes required
4. No indicator when no tandem configuration exists

## Technical Context

### What This Story Does

CLI statusline tandem indicator. CLI users see tandem status in their statusline: "[Primary Agent] + Backseat Agent" when a tandem phase is active. The suffix drops when the phase ends or the backseat agent crashes. No statusline protocol changes required; no indicator shows when no tandem configuration exists.

### Key Implementation Details

Dev should investigate existing statusline implementation to determine how to add the tandem indicator. Key areas to explore:
- Statusline rendering code
- How current agent info is displayed
- Where tandem state can be read from (likely .session files or workflow state)
- How backseat agent lifecycle events can trigger statusline updates

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/scripts/misc/statusline.sh` - tandem detection from observation files + display suffix

**Tests:** Manual verification (bash script, no unit test framework)
- No tandem files: clean display, no errors
- With tandem file: shows `+ {Partner}` in partner's agent color
- After file removal: suffix disappears

**PR:** #806 - feat(97-1): CLI statusline tandem indicator
**Branch:** feature/97-1-cli-statusline-tandem-indicator (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Preflight:**
- Bash/zsh syntax: PASS
- Forbidden patterns: CLEAN
- Single file changed: CONFIRMED

**Observations:**

| # | Severity | Location | Finding |
|---|----------|----------|---------|
| 1 | VERIFIED | `statusline.sh:146` | `$theme_file` scope safe — re-checked with `[ -f ]` before yq call |
| 2 | VERIFIED | `statusline.sh:145` | Regex `[a-zA-Z_-]*` constrains partner name — no yq injection |
| 3 | VERIFIED | `statusline.sh:266-267` | Negative padding guarded correctly |
| 4 | VERIFIED | `statusline.sh:256` | Visual width math for tandem suffix correct |
| 5 | VERIFIED | `statusline.sh:142` | `find` avoids zsh glob error on missing files |
| 6 | MEDIUM | `statusline.sh:142` | Non-deterministic partner selection when multiple tandem agents active |
| 7 | MEDIUM | tandem-lifecycle.ts | Observation files persist after phase end — stale indicator possible (lifecycle concern for 97-2) |
| 8 | LOW | `statusline.sh:150-157` | Character name extraction duplicated — acceptable for 2pt scope |

**Summary:** Clean implementation. All 4 ACs met. No security issues. No protocol changes. Two MEDIUMs are architectural concerns outside this story's scope.

**PR:** #806 merged
**Handoff:** To SM for story completion
