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

<gotcha name="frame-project-dir-env" severity="info">
The Python Frame server (`pf frame start`) uses `FRAME_PROJECT_DIR` with fallback to `PF_PROJECT_DIR`. These env vars tell Frame which project root to serve.
</gotcha>

<gotcha name="release-workflow-vs-branch-protection" severity="high">
The release stepped workflow (v13.4.0 run, 2026-07-27) conflicts with the branch-protection hook: step 9's `git push origin develop` is BLOCKED (explicit push target on a gitflow default branch), so the user must push develop themselves (`! git -C <path> push origin develop`). Pushes to main/tags are allowed (hook only protects the gitflow repo's default_branch = develop). Note the hook evaluates the CURRENT branch at command submission, so `git checkout develop && git merge ...` slips through _COMMIT_PATTERNS (TOCTOU gap) — the release's merge-to-develop worked only by that accident. Candidate framework fix: release-context bypass in `pf/hooks/branch_protection.py`.
</gotcha>

<gotcha name="release-entry-point" severity="info">
`pf git release` does NOT exist (skill doc stale) — start the release with `pf workflow start release`, advance with `pf workflow complete-step release`. Step 10's pipx instructions are stale too: use `just update-pf` (editable uv-tool install).
</gotcha>
