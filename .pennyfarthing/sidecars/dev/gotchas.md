# Dev Agent Gotchas

<gotcha name="install">
`pf` is Python-only. Global install: `pipx install pennyfarthing-dist/ --force`. Editable (dogfood repos): `pip install -e pennyfarthing-dist/` via direnv. No npm involvement.
</gotcha>

<gotcha name="symlinks">
`.claude/` and `.pennyfarthing/` symlink to `pennyfarthing/pennyfarthing-dist/` (in dogfood repos) or to the pipx-installed package (consumer repos). Missing commands? Reinstall via pipx.
</gotcha>

<gotcha name="dead-code">
Delete unused code immediately. Don't ask, don't comment out.
</gotcha>

<gotcha name="tool-ids">
Never show raw `toolu_*` IDs to users. Display tool name instead.
</gotcha>

<gotcha name="cyclist-cwd">
Start Cyclist from project root (where `.claude/` exists), not `packages/cyclist/`. Wrong cwd = skills not recognized.
</gotcha>

<gotcha name="project-root-marker">
Use `.pennyfarthing/` as root marker, not `pennyfarthing-dist/` (symlink in `packages/core/` causes false match).
</gotcha>

<gotcha name="shell">
All scripts use `#!/usr/bin/env zsh`. PATH issues = user env, not script.
</gotcha>

<gotcha name="tailwind-v4">
`@import "tailwindcss"` not `@tailwind` directives. v3 syntax silently tree-shakes styles.
</gotcha>

<gotcha name="websocket-not-ipc">
All Cyclist features use WebSocket (`/ws/claude`, `/ws/context`, `/ws/stats`, `/ws/settings`, `/ws/bell`). Never add IPC handlers.
</gotcha>

<gotcha name="nested-scroll">
Only leaf elements scroll. Parents use `overflow: hidden`. `.message-panel-content` is hidden; `.message-list` scrolls.
</gotcha>

<gotcha name="pf-install-dual">
`pf` CLI has two installs: **editable** in direnv for dogfooding repos (`pip install -e pennyfarthing-dist/`), **global** via pipx for consumer repos (`pipx install pennyfarthing-dist/ --force`). After version bumps, re-run both. The direnv install takes priority when inside pf-1/pf-2; pipx is the fallback for all other repos.
</gotcha>

<gotcha name="core-test-hang">
`node --test dist/**/*.test.js` in `packages/core` can hang for 3+ minutes on `server.test.js` (tries real HTTP connections on port 3000). Pipe-to-grep also hangs because of buffering. Use `> /tmp/file 2>&1` redirect instead of pipes. Run individual test files when debugging: `node --test dist/path/to/specific.test.js`.
</gotcha>

<gotcha name="all-tests-all-languages">
"Run all tests" means ALL languages: `pnpm test` (TypeScript/Node) AND `python3 -m pytest` (Python). Always run both. Python tests live at `pennyfarthing-dist/src/pf/tests/`.
</gotcha>

<gotcha name="stale-tests">
Tests referencing non-existent packages (bikerack-extraction, data-source, websocket-otlp-extraction) are dead. `packages/shared/` was absorbed into core (Story 98-16). Tandem portraits (`cyclist-tandem.png`) were never generated. Skill registry has 22 skills not 23.
</gotcha>
