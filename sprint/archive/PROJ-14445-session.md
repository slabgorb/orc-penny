# Session: 79-5 — Hotspot: expand artifact exclusions + client filters

## Story
- **ID:** 79-5
- **Jira:** PROJ-14445
- **Epic:** epic-79 (Dialog Infrastructure + Hotspot Refactor)
- **Points:** 2
- **Workflow:** tdd
- **Repos:** pennyfarthing

## Description
Expand DEFAULT_EXCLUDES in analyze.py to filter dotfiles, images, fonts, generated files (.d.ts, .snap), CI config (.github/*). Add client-side filter toggles in HotspotsDialog: "Code only" (positive filter for source extensions), "Include config" toggle.

## Acceptance Criteria
- [ ] DEFAULT_EXCLUDES expanded: dotfiles (.*), images (*.png, *.jpg, *.gif, *.svg, *.ico), fonts (*.woff, *.woff2, *.ttf, *.eot), generated files (*.d.ts, *.snap, *.d.ts.map), CI config (.github/*)
- [ ] HotspotsDialog has "Code only" toggle that filters to source extensions (.ts, .tsx, .js, .jsx, .py, .md, .css, .scss, .html)
- [ ] HotspotsDialog has "Include config" toggle for config files (.json, .yaml, .yml, .toml, .env)
- [ ] Client filters apply post-fetch (no API changes needed)
- [ ] Tests cover new exclusions in analyze.py
- [ ] Tests cover client filter logic

## Key Files
- `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` — DEFAULT_EXCLUDES (line 32)
- `pennyfarthing/packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx` — Client UI
- `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` — Data hook
- `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` — CLI interface

## Phase
- **Current:** finish
- **Agent:** SM
- **PR:** https://github.com/slabgorb/pennyfarthing/pull/742

## Test Design (TEA)
### Python tests: `tests/python/test_hotspots.py::TestExpandedDefaultExcludes`
- 8 tests: dotfiles, images, fonts, generated, CI config, source-not-excluded, config-not-excluded, integration
- 6 RED (new exclusion patterns needed), 2 GREEN (negative cases already pass)

### TypeScript tests: `packages/cyclist/tests/PROJ-14445-hotspot-client-filters.test.tsx`
- 11 tests across 4 ACs: "Code only" toggle, "Include config" toggle, post-fetch filtering, filter combinations
- 9 RED (UI elements don't exist yet), 2 GREEN (existing behavior)

### Implementation guidance
1. **analyze.py** — Expand `DEFAULT_EXCLUDES` list with new fnmatch patterns
2. **HotspotsDialog.tsx** — Add two state toggles + `useMemo` filter logic on `allFiles`/`allDirs`, update summary counts

## Branch
- pennyfarthing: `feature/PROJ-14445-hotspot-artifact-exclusions-client-filters`

## Notes
- This is the last story in epic-79 (4 of 5 complete)
- Client filters should be post-fetch (filter the results in the component, no API changes)
- DEFAULT_EXCLUDES uses fnmatch patterns
