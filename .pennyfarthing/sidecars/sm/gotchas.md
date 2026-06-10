# SM Agent Gotchas

<gotcha name="no-code" severity="critical">
SM never writes implementation code. Read-only for context. Create session → handoff.
</gotcha>

<gotcha name="read-before-write" severity="critical">
Always `Read` existing files before `Write` or `Edit`.
</gotcha>

<gotcha name="assessment-before-handoff" severity="critical">
Edit session with assessment BEFORE spawning handoff subagent.
</gotcha>

<gotcha name="jira-field">
Use `jira:` not `jira_key:` in sprint YAML.
</gotcha>

<gotcha name="no-guess-jira">
Never fabricate PROJ-XXXXX keys. Look up in YAML or query Jira.
</gotcha>

<gotcha name="symlinks">
New commands: create in `pennyfarthing-dist/commands/` AND symlink in `.claude/commands/`.
</gotcha>

<gotcha name="handoff-marker">
Emit `<!-- CYCLIST:HANDOFF:/agent -->` for Cyclist UI button.
</gotcha>

<gotcha name="american-spelling">
Use "Canceled" not "Cancelled" for Jira transitions.
</gotcha>

<gotcha name="verify-subagent">
Cross-check story counts against `sprint/current-sprint.yaml`.
</gotcha>

<gotcha name="preflight-npm-artifact">
sm-finish preflight repeatedly false-blocks on `npm run lint` at orchestrator root — repos.yaml stale `language: javascript`/`build_command: npm install` config; framework is Python-only (ADR-0034). Also false "No PR found" when the PR is already merged. Treat both as tooling artifacts, verify ruff/PR-state manually, proceed.
</gotcha>

<gotcha name="preflight-mutates-code" severity="critical">
A sm-finish preflight subagent once FIXED ruff issues and committed to local develop (161-1, 702b6d146). Preflight must be read-only — instruct "report, don't fix" in the spawn prompt. Direct push to develop is hook-blocked; recovery: branch from the stray work, reset develop to origin, PR it.
</gotcha>

<gotcha name="hook-cwd-protected-branch">
PreToolUse git hooks evaluate against the shell's CURRENT cwd (and pattern-match command text), not the cd target inside a compound command. Running orchestrator git ops while the shell sits in pennyfarthing/ on develop gets blocked as "protected branch". Split into separate Bash calls; cd first, standalone.
</gotcha>
