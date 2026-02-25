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
