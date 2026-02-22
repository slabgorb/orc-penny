# Story: td-6 — Make pf-settings skill config-structure-aware

**Status:** in-progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** chore/pf-settings-config-aware
**Jira:**

## Context

The `/pf-settings` skill doesn't expose the config file structure to the agent. When an agent runs `/pf-settings set statusbar true`, it creates a top-level `statusbar` key instead of setting the correct nested path. The skill needs to be more config-aware so the agent understands:

1. The nested structure of `config.local.yaml` (top-level keys: theme, workflow, display, split, layout, bikerack_layout, pennyfarthing, theme_characters, last_panel, statusbar)
2. Which dot-paths are valid (e.g., `workflow.statusbar`, `workflow.bell_mode`, `workflow.relay_mode`, `display.colorPreset`)
3. Common aliases or shortcuts that map to the correct dot-paths (e.g., plain "statusbar" → "workflow.statusbar", "bell_mode" → "workflow.bell_mode")

### Current Config Structure

Top-level keys in `config.local.yaml`:
- `theme` — Current theme name
- `workflow` — Workflow settings (bell_mode, git_monitor, permission_mode, relay_mode, statusbar)
- `display` — Display settings (colorPreset, fonts with uiFont, codeFont, uiFontSize, codeFontSize, customUiFont, customCodeFont)
- `layout` — GUI layout configuration
- `bikerack_layout` — BikeRack panel layout
- `pennyfarthing` — Nested theme override
- `theme_characters` — Character assignments per agent
- `last_panel` — Last viewed panel
- `split` — Split panel configuration (left, right)
- `statusbar` — Statusbar string (can be null)

### Acceptance Criteria
- [ ] Skill prompt includes config structure reference showing valid dot-paths
- [ ] Skill includes mapping of common aliases to their correct dot-paths
- [ ] Agent can correctly set nested values when given plain key names (e.g., "statusbar" → "workflow.statusbar")
- [ ] Skill examples cover the most common settings (workflow flags, display settings)

### Files to Modify
- `pennyfarthing/pennyfarthing-dist/skills/pf-settings/skill.md` — the skill definition

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/skills/pf-settings/skill.md` — Added config structure reference table, common mistake aliases, updated examples
- `.pennyfarthing/config.local.yaml` — Cleaned up stray top-level `statusbar: 'null'` key

**Tests:** N/A (skill markdown file, no runtime code)
**Branch:** chore/pf-settings-config-aware (pushed)

**What changed:**
1. Added "Config Structure" section with full dot-path reference table (17 settings)
2. Added "Keys that are NOT top-level" callout box listing the 5 most common mistakes
3. Updated examples to group by category (workflow flags, display, top-level)
4. Added warning note about never setting bare `statusbar`, `bell_mode`, or `relay_mode`

**Handoff:** To review phase

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** User invokes `/pf-settings set X Y` → agent reads skill.md → config structure table guides correct dot-path → `pf.sh settings set` writes to correct nested key
**Pattern observed:** Config reference table with "common mistakes" callout — effective at preventing bare-key errors (`skill.md:44-49`)
**Error handling:** N/A — documentation-only change, no runtime code
**Note:** [LOW] `display.fonts.uiFontSize` and `display.fonts.codeFontSize` missing from reference table — minor completeness gap, not blocking

**Handoff:** To SM for finish-story