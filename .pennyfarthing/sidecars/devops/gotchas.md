# DevOps Agent Gotchas

<gotcha name="hook-paths" severity="critical">
Hook commands fail from subdirectories. Always use `$CLAUDE_PROJECT_DIR`, not relative paths.
</gotcha>

<gotcha name="nested-repos">
`git rev-parse --show-toplevel` returns wrong root in nested repos. Use `$CLAUDE_PROJECT_DIR` or climber.
</gotcha>

<gotcha name="git-index-lock">
`git status --porcelain` locks index, causing race conditions. Use `git diff-index --quiet HEAD` (read-only, no lock).
</gotcha>

<gotcha name="electron-entry">
`package.json` `"main"` points to server.js. Dev scripts must specify `electron dist/main.js` explicitly.
</gotcha>

<gotcha name="subagent-types">
Task tool only accepts built-in types (`Bash`, `general-purpose`, `Explore`, `Plan`). Use `general-purpose` + prompt to read custom subagent definition.
</gotcha>

<gotcha name="monorepo-build-order">
`just cyclist` auto-detects missing workspace deps. If `@pennyfarthing/core` not found, run `pnpm run build` first.
</gotcha>

<gotcha name="tmux-send-keys-enter">
`tmux send-keys ... Enter` doesn't submit in some zsh configs. Use `C-j` (line feed) instead of `Enter` to execute commands in tmux panes.
</gotcha>

<gotcha name="lfs-portraits-dev" severity="high">
Dev environment portrait files are LFS pointers (130-byte ASCII text). Run `git lfs pull` in `pennyfarthing/` before `pf init` from dev to get real PNGs. The pip-installed `pf._dist` always has real images (wheel build resolves LFS).
</gotcha>

<gotcha name="wheelhub-self-contained" severity="info">
WheelHub (`wheelhub.mjs`) is fully bundled (~1.8MB) — express, ws, yaml all baked in. Consumer projects do NOT need `npm install` for WheelHub to work. Only `node` binary needed.
</gotcha>

<gotcha name="wheelhub-barrel-import" severity="critical">
Server code (`plugin-loader.ts`) must NOT import from the barrel `../index.js`. The barrel re-exports `benchmark/index.js` which re-exports `benchmark-integration.js` — that file has module-level `findMonorepoRoot(__dirname)` that crashes in pip-installed environments. Import directly from `../plugins/plugin-discovery.js` instead.
</gotcha>

<gotcha name="wheelhub-bundle-rebuild" severity="high">
After rebuilding wheelhub.mjs with esbuild, you MUST patch the CJS shim for Node 24 ESM compat. Replace the default `typeof require` Proxy shim with:
```js
import { createRequire as __createRequire } from "node:module";
var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : __createRequire(import.meta.url))(0);
```
Without this, bundled CJS deps fail with "Dynamic require of X is not supported" on Node 24.
</gotcha>

<gotcha name="wheelhub-project-dir-env" severity="info">
WheelHub uses `WHEELHUB_PROJECT_DIR` with fallback to `CYCLIST_PROJECT_DIR`. Cyclist Electron app uses `CYCLIST_PROJECT_DIR` directly. The Python launcher (`start_wheelhub`) sets `WHEELHUB_PROJECT_DIR` when spawning the Node process.
</gotcha>
