#!/usr/bin/env bash
# Auto-load /sm agent on new session start
# Injects additionalContext telling Claude to invoke the SM agent
# and confirm the load visually so users can distinguish fresh from stale

set -euo pipefail

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "AGENT RELOAD on startup: Run `pf agent start sm` via Bash as your FIRST action to load the SM agent. Then tell the user: \"SM agent loaded fresh for this session. Ready for sprint coordination.\" Do not greet the user or do anything else before loading the agent."
  }
}
EOF
