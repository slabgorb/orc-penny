# DevOps Agent Patterns

<pattern name="hook-paths">
Use `$CLAUDE_PROJECT_DIR` for hook commands in settings.local.json. Don't use `git rev-parse --show-toplevel` (wrong root in nested repos).
</pattern>

<pattern name="just-commands">
`just test`, `just lint`, `just build`, `just dev` — standard project commands.
</pattern>

<pattern name="npm-git-install">
`"pennyfarthing": "github:1898andCo/pennyfarthing#develop"`. `dist/` must be committed (devDeps not installed). Pin with `#branch` or `#commit`.
</pattern>

<pattern name="python-hook-wrapper">
Shell wrapper → `find-root.sh` → set PYTHONPATH (dogfooding or node_modules) → `python3 -m pennyfarthing_scripts.<module>`. Don't use relative `../../..` traversal.
</pattern>
