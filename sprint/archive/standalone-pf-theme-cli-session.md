# Session: standalone-pf-theme-cli

**Story:** Consolidate theme commands into `pf theme` Python CLI
**Type:** standalone
**Workflow:** trivial
**Phase:** approved
**Repos:** pennyfarthing
**Branch:** develop (standalone will create feature branch after implementation)

## Objective

Add `pf theme` command group to the Python CLI with `list`, `show`, `set`, `create` subcommands. Update slash commands and skill docs to use `pf theme` instead of mixed shell/Node.js/manual approaches.

## Plan

See `/Users/keithavery/.claude/plans/transient-gliding-boot.md` for full plan.

## Summary

### Files to Create
1. `pennyfarthing/pennyfarthing_scripts/theme/__init__.py` — module init
2. `pennyfarthing/pennyfarthing_scripts/theme/__main__.py` — module runner
3. `pennyfarthing/pennyfarthing_scripts/theme/cli.py` — Click command group (list, show, set, create)

### Files to Modify
4. `pennyfarthing/pennyfarthing_scripts/cli.py` — register theme group
5. `pennyfarthing/pennyfarthing-dist/commands/show-theme.md` — use `pf theme show`
6. `pennyfarthing/pennyfarthing-dist/commands/list-themes.md` — use `pf theme list`
7. `pennyfarthing/pennyfarthing-dist/commands/set-theme.md` — use `pf theme set`
8. `pennyfarthing/pennyfarthing-dist/commands/create-theme.md` — use `pf theme create`
9. `pennyfarthing/pennyfarthing-dist/skills/theme/skill.md` — update references

### Key Reuse
- `common/themes.py`: `format_theme_list()`, `get_current_theme()`, `resolve_theme_path()`, `list_themes()`
- `common/config.py`: `load_yaml_config()`, `get_project_root()`
- Port `set` config-write + `theme_characters` baking from Node.js `themes.ts`

### --full flag (show command)
Adds: OCEAN scores, trait, expertise, role, quirks, catchphrases, emoji, helper per agent

## Acceptance Criteria
- [x] `pf theme list` shows all themes with current marked and tier annotations
- [x] `pf theme show` shows current theme agents (character + style)
- [x] `pf theme show blade-runner --full` shows extended details (OCEAN, quirks, etc.)
- [x] `pf theme set <name>` updates config.local.yaml with theme + theme_characters
- [x] `pf theme create <name>` creates skeleton from base theme
- [x] All 4 command .md files updated to reference `pf theme`
- [x] Skill .md updated to reference `pf theme`

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/theme/cli.py` - Fixed `--base` default from non-existent 'minimalist' to current theme
- `pennyfarthing-dist/commands/create-theme.md` - Updated docs to reflect new default

**Note:** Core implementation (theme module, CLI registration, command/skill docs) was already complete from prior work (PR #749). This PR fixes the broken default base theme for `pf theme create`.

**Tests:** All 4 subcommands verified manually (list, show, show --full, set round-trip, create)
**PR:** #750 - fix: use current theme as default base for pf theme create
**Branch:** fix/theme-create-default-base (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `--base` arg → `None` → `get_current_theme()` (config.local.yaml) → `or "blade-runner"` fallback → `resolve_theme_path()` validation → safe
**Pattern observed:** Null-safe chain with downstream validation at `cli.py:238-239,253-256`
**Error handling:** All paths covered — missing config, missing theme file, invalid theme name all raise `ClickException`
**Observations:**
- [VERIFIED] Type annotation `str | None` correct for `default=None`
- [VERIFIED] `get_current_theme()` returns `str | None`, handled by `or` fallback
- [VERIFIED] Hard-coded `blade-runner` fallback exists as real S-tier theme
- [VERIFIED] Doc update matches new behavior
- [LOW] `if not base:` catches empty string too — not harmful, Click won't pass empty
**PR:** #750 merged
**Handoff:** To SM for finish-story
