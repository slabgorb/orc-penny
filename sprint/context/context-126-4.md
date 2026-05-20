# Context: 126-4 Remove uv/pf.sh wrapper chain

## Technical Approach
- Audit all references to `pf.sh`, `run-pf.sh`, and `uv run` in the codebase
- Replace wrapper invocations with direct `pf` calls
- Remove the wrapper scripts themselves
- Update hook commands in settings.local.json
- Update agent activation commands in agent definitions
- Verify no uv references remain in runtime paths

## Key Files
- `.pennyfarthing/scripts/core/pf.sh` — wrapper to remove
- `.pennyfarthing/scripts/lib/run-pf.sh` — wrapper lib to remove
- Agent definitions in `pennyfarthing-dist/agents/`
- Hook definitions in settings
- Skills that reference the wrapper chain

## Dependencies
- 126-3 (PROJ-15491) delivered — auto-setup complete
- `pf` must be globally installable via pip/pipx
