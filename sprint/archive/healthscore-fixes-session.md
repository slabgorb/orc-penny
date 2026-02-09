# Work Session: Health Score Panel Fixes

## Session Details
- **Date:** 2026-02-09
- **Agent:** Dev (Trillian)
- **Type:** Ad-hoc bug fix + enhancement
- **Repos:** pennyfarthing (pennyfarthing_scripts, packages/cyclist)

## Summary
Health score panel had 4 broken/missing dimensions (TODO Density showing wrong score, Deprecation Debt showing --, Agent Context Efficiency showing --, Test Gaps showing -- and opening wrong dialog). Root cause: 3 of 8 probe functions were never implemented in the healthscore analyzer. Additionally integrated PyDriller for smarter churn/hotspot analysis and improved test gap detection heuristic.

## Issues Found

### 1. Missing Probe Functions (Root Cause)
`healthscore/analyze.py` `_probe_dimension()` dispatch map only had 5 of 8 probes:
- `churn` ✓
- `todo_density` ✓
- `complexity` ✓
- `dead_code` ✓
- `dependency_freshness` ✓
- `test_gaps` ✗ — returned None silently
- `deprecation_debt` ✗ — returned None silently
- `agent_context_efficiency` ✗ — returned None silently

### 2. Test Gaps Opening Wrong Dialog
`DebugPanel.tsx` `handleDimensionClick()` had `test_gaps` falling through to `churn` case, opening HotspotsDialog instead of its own dialog.

### 3. No Debug Logging
All probes had bare `except Exception: return None` — failures were invisible.

### 4. Churn Noise
Hotspot analyzer included config/docs files (package.json, CLAUDE.md, *.yaml) that churn naturally but aren't code quality signals.

## Changes Made

### Files Modified

| File | Change |
|------|--------|
| `pennyfarthing_scripts/healthscore/analyze.py` | Added 3 missing probes (`_probe_deprecation_debt`, `_probe_test_gaps`, `_probe_agent_context_efficiency`), added INFO/ERROR logging to all probes, integrated PyDriller for churn with fallback |
| `pennyfarthing_scripts/healthscore/__main__.py` | Added `logging.basicConfig()` so probe logs appear on stderr |
| `pennyfarthing_scripts/hotspots/analyze.py` | Replaced git-log-shelling with PyDriller-backed analysis (with git-log fallback), expanded DEFAULT_EXCLUDES to filter config/docs/yaml noise, added logging, extracted `_build_hotspot_result()` to share between PyDriller and fallback paths |
| `packages/cyclist/src/api/health-score.ts` | Added request/response logging, always log stderr from Python, added `--no-cache` flag, log dimension scoring summary |
| `packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Fixed `test_gaps` click handler — separated from `churn` case so it no longer opens HotspotsDialog |
| `pyproject.toml` | Added `pydriller>=2.6` to dependencies |

### New Probe Implementations

#### `_probe_deprecation_debt`
- Wires to existing `codemarkers.analyze.analyze_deprecations()`
- Scores: each @deprecated symbol deducts 5pts, each one still actively called deducts 10pts more
- Data was always there in codemarkers module, just never wired to healthscore

#### `_probe_test_gaps`
- Directory-aware file matching (not just stem-name matching)
- Filters non-testable files (index.ts, types.ts, configs, __init__.py)
- Matching strategies: direct stem, hyphen/underscore normalization, parallel directory paths
- Logs sample uncovered files for debugging

#### `_probe_agent_context_efficiency`
- Uses `prime.tiers.load_tier_components(FULL)` per agent
- Scores each agent against 4000-token budget target
- At/under budget = 100, 2x budget = 0, linear between
- Average across all 10 primary agents

### PyDriller Integration (Churn/Hotspots)
- `hotspots/analyze.py` now uses PyDriller `Repository.traverse_commits()` as primary engine
- Falls back to raw `git log --numstat` parsing if PyDriller unavailable
- Smart filtering: only counts source code files (.ts, .tsx, .js, .py, etc.)
- Excludes: package.json, *.md, *.yaml, tsconfig.json, sprint/*, docs/*
- Same scoring algorithm (`calculate_hotspot_score`) — just cleaner data input

### Expanded Hotspot Excludes
Added to `DEFAULT_EXCLUDES`:
- `package.json`, `*/package.json` — manifest churn
- `tsconfig.json`, `tsconfig.*.json` — config churn
- `*.md` — documentation churn
- `CLAUDE.md`, `CLAUDE-*.md` — agent config churn
- `docs/*` — documentation directory
- `*.yaml`, `*.yml` — operational config churn

## Testing Status
- [ ] Run healthscore analysis end-to-end (all 8 dimensions)
- [ ] Verify hotspots dialog shows filtered results
- [ ] Verify Cyclist panel displays all dimension scores
- [ ] Confirm test_gaps click no longer opens HotspotsDialog

## Technical Notes
- PyDriller installed in `.venv/` — the API endpoint calls system `python3`, may need venv activation or path update in health-score.ts
- Logging goes to stderr (not stdout) to avoid corrupting JSON output
- Health probe cache bypassed via `--no-cache` in API endpoint for debugging; revert to cached mode once stable
