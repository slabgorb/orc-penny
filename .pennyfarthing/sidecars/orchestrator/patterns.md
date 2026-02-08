# Orchestrator Patterns

<pattern name="automatic-vs-instructional">
Critical behaviors → scripts (automatic). Optional behaviors → markdown (instructional). Scripts survive handoffs; markdown doesn't.
</pattern>

<pattern name="script-output">
Output in XML tags for agents to parse: `echo "<persona agent=\"${name}\" theme=\"${theme}\">"`.
</pattern>

<pattern name="claude-climber">
`$CLAUDE_PROJECT_DIR` unavailable in Bash tool. Use inline climber:
`d="$PWD"; while [[ ! -d "$d/.claude" ]] && [[ "$d" != "/" ]]; do d="$(dirname "$d")"; done`
</pattern>

<pattern name="skill-tool-use">
Code blocks in skill files are docs, not executed. Write explicit "Use Bash tool to run:" instructions.
</pattern>

<pattern name="drift-detection">
Signals: reviewer approving without comments, SM skipping handoffs, dev not testing.
Script: `.pennyfarthing/scripts/health/drift-detection.sh [--verbose]`
Healthy rates: reviewer rubber-stamp <5%, dev no-test <5%, SM no-target <15%, TEA no-files <10%.
</pattern>

<pattern name="shared-state">
Any shared mutable state between concurrent processes is a bug. Each session uses its own files.
</pattern>
