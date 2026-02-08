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

<pattern name="command-consolidation">
When consolidating slash commands (e.g., `/set-theme` → `/theme set`): (1) rewrite the parent skill with args routing, (2) create a command `.md` for tab-completion discoverability, (3) deprecate old command files with `deprecated: true` + `redirect:` in frontmatter, (4) update `skill-registry.yaml` examples, (5) update `generate-slash-commands.js` to skip `deprecated: true` files, (6) grep for stale references in help, setup, scripts. Follow the `/story` → `/sprint story` pattern.
</pattern>

<pattern name="command-vs-skill">
Command files (`commands/*.md`) are the discoverable entry point — tab completion picks them up via `generate-slash-commands.js`. Skill files (`skills/*/skill.md`) hold the deep implementation details. Every user-facing slash command needs both: a command `.md` for discoverability and a skill `.md` for behavior.
</pattern>
