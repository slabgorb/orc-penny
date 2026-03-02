# Dev Agent Gotchas

<gotcha name="install">
Install from GitHub: `npm install github:1898andCo/pennyfarthing`. Not published to npm. `npm link` won't work.
</gotcha>

<gotcha name="symlinks">
`.claude/` symlinks to `node_modules/pennyfarthing/pennyfarthing-dist/`. Missing commands? Reinstall from GitHub.
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
