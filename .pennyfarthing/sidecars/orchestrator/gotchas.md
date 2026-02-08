# Orchestrator Gotchas

<gotcha name="no-project-dir-in-bash" severity="critical">
`$CLAUDE_PROJECT_DIR` only set for hooks/statusLine. In Bash tool, use `.claude` climber pattern.
</gotcha>

<gotcha name="nested-repos">
`git rev-parse --show-toplevel` returns wrong root in nested repos. Use climber or `$CLAUDE_PROJECT_DIR`.
</gotcha>

<gotcha name="skill-code-blocks">
Code blocks in skills are documentation, not executed. Write explicit tool-use instructions.
</gotcha>

<gotcha name="stop-hook">
Stop hook may not run on all exit paths. Prefer SessionStart hook for critical setup/cleanup.
</gotcha>
