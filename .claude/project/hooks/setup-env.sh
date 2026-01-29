#!/usr/bin/env zsh
# Project-specific environment setup
# Called during Claude Code session start

# Export to CLAUDE_ENV_FILE for session persistence
if [ -n "$CLAUDE_ENV_FILE" ]; then
    {
        echo "export PROJECT_NAME=\"pennyfarthing-orchestrator\""
        echo "export PROJECT_LABEL=\"pennyfarthing-orchestrator\""
        # pennyfarthing_scripts is in local dev repo (not published to npm yet)
        # This allows prime.py to find the module
        echo "export PYTHONPATH=\"\${PROJECT_ROOT:-$PWD}/pennyfarthing:\${PYTHONPATH:-}\""
    } >> "$CLAUDE_ENV_FILE"
fi

# Display project info
echo "Project: pennyfarthing-orchestrator"
echo "Pennyfarthing: npm package"
