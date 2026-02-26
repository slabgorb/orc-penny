# Pennyfarthing Orchestrator tasks
# Delegates to pennyfarthing/ for dev commands

# Root directory of this justfile
root := justfile_directory()
pennyfarthing := root / "pennyfarthing"
# Directory from which just was invoked
invocation := invocation_directory()

import '.pennyfarthing/justfile.pf'


# Default recipe - list available commands
default:
    @just --list

# =============================================================================
# Cyclist - delegates to pennyfarthing repo
# =============================================================================

# Cyclist - unified command for all Cyclist operations
# Run modes: here, web, server, verbose, dir=/path
# Maintenance: setup, doctor, build, clean, rebuild, package, install
cyclist *args:
    #!/usr/bin/env bash
    set -euo pipefail

    # Transform 'here' to use invocation directory when delegating
    args="{{args}}"
    if [[ "$args" == *"here"* ]]; then
        # Replace 'here' with explicit dir= pointing to where user ran just
        args="${args/here/dir={{invocation}}}"
    fi

    # Run just from pennyfarthing directory
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" cyclist $args

# =============================================================================
# Build & Test - delegates to pennyfarthing repo
# =============================================================================

# Build all packages
build:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" build

# Run tests for all packages
test:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" test

# Run tests for cyclist package only
test-cyclist:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" test-cyclist

# =============================================================================
# Portraits
# =============================================================================

# Portraits: generate <theme|all>, preview <theme|all>
portraits *args:
    #!/usr/bin/env bash
    set -euo pipefail
    script="{{pennyfarthing}}/pennyfarthing-dist/scripts/portraits/generate-portraits.sh"
    args=({{args}})
    cmd="${args[0]:-}"
    target="${args[1]:-}"
    case "$cmd" in
        generate)
            if [[ "$target" == "all" || -z "$target" ]]; then
                "$script" --skip-existing
            else
                "$script" --theme "$target" --skip-existing
            fi
            ;;
        preview)
            if [[ "$target" == "all" || -z "$target" ]]; then
                "$script" --dry-run
            else
                "$script" --theme "$target" --dry-run
            fi
            ;;
        *)
            echo "Usage: just portraits <generate|preview> [theme|all]"
            exit 1
            ;;
    esac

# [pf-migrated] # Start WheelHub server (API + WebSocket on port 2898)
# [pf-migrated] # Usage: just wheelhub [start|stop|status]
# [pf-migrated] wheelhub *args:
# [pf-migrated]     #!/usr/bin/env bash
# [pf-migrated]     set -euo pipefail

# [pf-migrated]     project_dir="{{root}}"
# [pf-migrated]     pid_file="$project_dir/.wheelhub-pid"
# [pf-migrated]     port_file="$project_dir/.bikerack-port"
# [pf-migrated]     logfile="$project_dir/.session/wheelhub.log"

# [pf-migrated]     subcmd="{{args}}"
# [pf-migrated]     case "${subcmd:-start}" in
# [pf-migrated]         stop)
# [pf-migrated]             if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
# [pf-migrated]                 kill "$(cat "$pid_file")"
# [pf-migrated]                 rm -f "$pid_file" "$port_file"
# [pf-migrated]                 echo "WheelHub stopped"
# [pf-migrated]             else
# [pf-migrated]                 rm -f "$pid_file" "$port_file"
# [pf-migrated]                 echo "WheelHub not running"
# [pf-migrated]             fi
# [pf-migrated]             ;;
# [pf-migrated]         status)
# [pf-migrated]             if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
# [pf-migrated]                 port=$(cat "$port_file" 2>/dev/null || echo "?")
# [pf-migrated]                 echo "WheelHub running (PID: $(cat "$pid_file"), port: $port)"
# [pf-migrated]                 echo "  http://127.0.0.1:$port"
# [pf-migrated]             else
# [pf-migrated]                 echo "WheelHub not running"
# [pf-migrated]             fi
# [pf-migrated]             ;;
# [pf-migrated]         start)
# [pf-migrated]             # Idempotent — already running? Just report.
# [pf-migrated]             if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
# [pf-migrated]                 port=$(cat "$port_file" 2>/dev/null || echo "?")
# [pf-migrated]                 echo "WheelHub already running (port: $port)"
# [pf-migrated]                 exit 0
# [pf-migrated]             fi

# [pf-migrated]             rm -f "$pid_file" "$port_file"

# [pf-migrated]             bikerack_js="{{pennyfarthing}}/packages/cyclist/dist/bikerack.js"
# [pf-migrated]             if [[ ! -f "$bikerack_js" ]]; then
# [pf-migrated]                 echo "Build required..."
# [pf-migrated]                 cd "{{pennyfarthing}}" && pnpm run build
# [pf-migrated]             fi

# [pf-migrated]             mkdir -p "$(dirname "$logfile")"
# [pf-migrated]             IS_BIKERACK=1 CYCLIST_PROJECT_DIR="$project_dir" \
# [pf-migrated]                 node "$bikerack_js" >> "$logfile" 2>&1 &
# [pf-migrated]             echo $! > "$pid_file"

# [pf-migrated]             # Wait for port file (up to 10s)
# [pf-migrated]             for i in $(seq 1 20); do
# [pf-migrated]                 if [[ -f "$port_file" ]]; then
# [pf-migrated]                     port=$(cat "$port_file")
# [pf-migrated]                     echo "WheelHub running at http://127.0.0.1:$port"
# [pf-migrated]                     exit 0
# [pf-migrated]                 fi
# [pf-migrated]                 sleep 0.5
# [pf-migrated]             done
# [pf-migrated]             echo "Warning: WheelHub didn't start within 10s. Check $logfile"
# [pf-migrated]             ;;
# [pf-migrated]         *)
# [pf-migrated]             echo "Usage: just wheelhub [start|stop|status]"
# [pf-migrated]             exit 1
# [pf-migrated]             ;;
# [pf-migrated]     esac

# [pf-migrated] # Launch TUI (starts WheelHub if needed)
# [pf-migrated] tui:
# [pf-migrated]     #!/usr/bin/env bash
# [pf-migrated]     set -euo pipefail

# [pf-migrated]     pid_file="{{root}}/.wheelhub-pid"
# [pf-migrated]     port_file="{{root}}/.bikerack-port"

# [pf-migrated]     # Start WheelHub if not running
# [pf-migrated]     if ! ([[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null); then
# [pf-migrated]         just --justfile "{{root}}/justfile" wheelhub start
# [pf-migrated]     fi

# [pf-migrated]     port=$(cat "$port_file" 2>/dev/null)
# [pf-migrated]     if [[ -z "$port" ]]; then
# [pf-migrated]         echo "Error: WheelHub port not found"
# [pf-migrated]         exit 1
# [pf-migrated]     fi

# [pf-migrated]     pf launch tui --port "$port" --project-dir "{{root}}" --foreground

# Launch TUI in dev mode (auto-reload on Python file changes)
tui-dev:
    #!/usr/bin/env bash
    set -euo pipefail

    pid_file="{{root}}/.wheelhub-pid"
    port_file="{{root}}/.bikerack-port"

    # Start WheelHub if not running
    if ! ([[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null); then
        just --justfile "{{root}}/justfile" wheelhub start
    fi

    port=$(cat "$port_file" 2>/dev/null)
    if [[ -z "$port" ]]; then
        echo "Error: WheelHub port not found"
        exit 1
    fi

    PYTHONPATH="{{root}}/pennyfarthing/pennyfarthing-dist/src" \
        python3 -c "from pf.bikerack.tui import dev_main; from pathlib import Path; dev_main(port=$port, project_dir=Path('{{root}}'))"

# [pf-migrated]     pid_file="{{root}}/.wheelhub-pid"
# [pf-migrated]     port_file="{{root}}/.bikerack-port"

# [pf-migrated]     # Start WheelHub if not running
# [pf-migrated]     if ! ([[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null); then
# [pf-migrated]         just --justfile "{{root}}/justfile" wheelhub start
# [pf-migrated]     fi

# [pf-migrated]     port=$(cat "$port_file" 2>/dev/null)
# [pf-migrated]     if [[ -z "$port" ]]; then
# [pf-migrated]         echo "Error: WheelHub port not found"
# [pf-migrated]         exit 1
# [pf-migrated]     fi

# [pf-migrated]     url="http://127.0.0.1:$port"
# [pf-migrated]     echo "Opening $url"
# [pf-migrated]     open -a "Google Chrome" "$url"

# [pf-migrated] # Launch Claude with OTEL pre-configured for WheelHub/BikeRack
# [pf-migrated] claude:
# [pf-migrated]     #!/usr/bin/env bash
# [pf-migrated]     set -euo pipefail

# [pf-migrated]     project_dir="{{root}}"
# [pf-migrated]     PORT=""

# [pf-migrated]     # Check .cyclist-port first, then .bikerack-port (same order as session_start.py)
# [pf-migrated]     for port_file in "$project_dir/.cyclist-port" "$project_dir/.bikerack-port"; do
# [pf-migrated]         if [[ -f "$port_file" ]]; then
# [pf-migrated]             candidate=$(cat "$port_file" 2>/dev/null)
# [pf-migrated]             if [[ "$candidate" =~ ^[0-9]+$ ]]; then
# [pf-migrated]                 # Verify port is actually listening
# [pf-migrated]                 if (echo >/dev/tcp/localhost/"$candidate") 2>/dev/null; then
# [pf-migrated]                     PORT="$candidate"
# [pf-migrated]                     break
# [pf-migrated]                 else
# [pf-migrated]                     echo "[just claude] Stale port file $port_file (port $candidate not listening), skipping" >&2
# [pf-migrated]                 fi
# [pf-migrated]             fi
# [pf-migrated]         fi
# [pf-migrated]     done

# [pf-migrated]     if [[ -n "$PORT" ]]; then
# [pf-migrated]         echo "[just claude] OTEL configured → http://localhost:$PORT" >&2
# [pf-migrated]         export CLAUDE_CODE_ENABLE_TELEMETRY="1"
# [pf-migrated]         export OTEL_EXPORTER_OTLP_PROTOCOL="http/json"
# [pf-migrated]         export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:$PORT"
# [pf-migrated]         export OTEL_LOGS_EXPORTER="otlp"
# [pf-migrated]         export OTEL_METRICS_EXPORTER="otlp"
# [pf-migrated]     else
# [pf-migrated]         echo "[just claude] No WheelHub/BikeRack running — launching without OTEL" >&2
# [pf-migrated]         echo "[just claude] Start one first: just wheelhub start" >&2
# [pf-migrated]     fi

# [pf-migrated]     exec claude

# [pf-migrated] # Launch tmux dev layout (2 columns: pf-1 + pf-2, each with Claude + TUI)
# [pf-migrated] tmux-dev:
# [pf-migrated]     #!/usr/bin/env bash
# [pf-migrated]     set -euo pipefail
# [pf-migrated]     if [[ ! -f "{{root}}/tmux-dev" ]]; then
# [pf-migrated]         echo "No tmux-dev found. Copy from sample:"
# [pf-migrated]         echo "  cp tmux-dev.sample tmux-dev && chmod +x tmux-dev"
# [pf-migrated]         echo "  cp tmux.conf.sample tmux.conf"
# [pf-migrated]         exit 1
# [pf-migrated]     fi
# [pf-migrated]     exec "{{root}}/tmux-dev"

# =============================================================================
# tmux — see .pennyfarthing/justfile.pf
# =============================================================================

# =============================================================================
# Development
# =============================================================================

# Watch pennyfarthing for changes and auto-rebuild (runs pnpm dev)
dev:
    cd {{pennyfarthing}} && pnpm dev

# =============================================================================
# Setup
# =============================================================================

# Bootstrap workspace from scratch (fresh clone)
setup:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== Pennyfarthing Orchestrator Setup ==="
    echo ""

    # Validate Python version early
    if ! python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)" 2>/dev/null; then
        echo "Error: Python 3.11+ is required but not found."
        echo "  Install: brew install python@3.11  (or pyenv install 3.11)"
        exit 1
    fi

    # Step 1: Clone pennyfarthing repo if missing
    if [ ! -d "{{pennyfarthing}}" ]; then
        echo "Step 1/6: Cloning pennyfarthing framework..."
        git clone git@github.com:1898andCo/pennyfarthing.git "{{pennyfarthing}}"
    else
        echo "Step 1/6: pennyfarthing/ already exists, skipping clone"
    fi

    # Step 2: Install framework dependencies
    echo "Step 2/6: Installing framework dependencies..."
    cd "{{pennyfarthing}}" && pnpm install

    # Step 3: Build framework
    echo "Step 3/6: Building framework..."
    cd "{{pennyfarthing}}" && pnpm build

    # Step 4: Install pf CLI (editable-install from local repo to stay current)
    echo "Step 4/6: Installing pf CLI from local repo..."
    if command -v uv >/dev/null 2>&1; then
        uv tool install --editable "{{pennyfarthing}}" --force --quiet 2>/dev/null \
            || uv tool install --editable "{{pennyfarthing}}" --force
    elif command -v pipx >/dev/null 2>&1; then
        pipx install --editable "{{pennyfarthing}}" --force --quiet 2>/dev/null \
            || pipx install --editable "{{pennyfarthing}}" --force
    else
        pip3 install -e "{{pennyfarthing}}" --quiet 2>/dev/null \
            || pip3 install -e "{{pennyfarthing}}" --break-system-packages
    fi
    if ! command -v pf >/dev/null 2>&1; then
        echo ""
        echo "Warning: pf installed but not on PATH."
        echo "  If using uv/pipx, ensure ~/.local/bin is on PATH."
        echo "  Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo "  Then restart your shell and re-run: just setup"
        exit 1
    fi
    echo "  Installed: $(pf --version 2>&1)"

    # Step 5: Install orchestrator deps (triggers postinstall -> pennyfarthing update)
    echo "Step 5/6: Installing orchestrator and linking..."
    cd "{{root}}" && npm install

    # Step 6: Initialize project (creates settings.local.json with hooks)
    echo "Step 6/6: Initializing Pennyfarthing project..."
    cd "{{root}}" && pf init

    echo ""
    echo "=== Setup complete ==="
    echo ""
    echo "Next steps:"
    echo "  just claude       # start Claude Code"
    echo "  /guided-tour      # interactive walkthrough"

# =============================================================================
# Orchestrator-specific tasks
# =============================================================================

# Check sidecar files for bloat
sidecar-health:
    .pennyfarthing/scripts/maintenance/sidecar-health.sh

# Archive bloated sidecars and prepare for pruning
sidecar-prune:
    .pennyfarthing/scripts/maintenance/sidecar-health.sh --fix

# =============================================================================
# Validation - delegates to pennyfarthing repo
# =============================================================================

# Run all validations (agents, subagents, sprint)
validate:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" validate-agents
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" validate-subagents
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" validate-sprint
