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
