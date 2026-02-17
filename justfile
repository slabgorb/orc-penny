# Pennyfarthing Orchestrator tasks
# Delegates to pennyfarthing/ for dev commands

# Root directory of this justfile
root := justfile_directory()
pennyfarthing := root / "pennyfarthing"
# Directory from which just was invoked
invocation := invocation_directory()

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

# Install dependencies
install:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" install

# =============================================================================
# VS Code Extension - delegates to pennyfarthing repo
# =============================================================================

# VS Code extension commands
vscode *args:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" vscode {{args}}

# =============================================================================
# Portraits - delegates to pennyfarthing repo
# =============================================================================

# Generate portraits for a theme
portraits theme:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" portraits {{theme}}

# Preview portrait generation (dry-run)
portraits-preview theme:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" portraits-preview {{theme}}

# Generate portraits for all themes
portraits-all:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" portraits-all

# Start WheelHub server (API + WebSocket on port 2898)
# Usage: just wheelhub [start|stop|status]
wheelhub *args:
    #!/usr/bin/env bash
    set -euo pipefail

    project_dir="{{root}}"
    pid_file="$project_dir/.wheelhub-pid"
    port_file="$project_dir/.wheelhub-port"
    logfile="$project_dir/.session/wheelhub.log"

    subcmd="{{args}}"
    case "${subcmd:-start}" in
        stop)
            if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
                kill "$(cat "$pid_file")"
                rm -f "$pid_file" "$port_file"
                echo "WheelHub stopped"
            else
                rm -f "$pid_file" "$port_file"
                echo "WheelHub not running"
            fi
            ;;
        status)
            if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
                port=$(cat "$port_file" 2>/dev/null || echo "?")
                echo "WheelHub running (PID: $(cat "$pid_file"), port: $port)"
                echo "  http://127.0.0.1:$port"
            else
                echo "WheelHub not running"
            fi
            ;;
        start)
            # Idempotent — already running? Just report.
            if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
                port=$(cat "$port_file" 2>/dev/null || echo "?")
                echo "WheelHub already running (port: $port)"
                exit 0
            fi

            rm -f "$pid_file" "$port_file"

            bikerack_js="{{pennyfarthing}}/packages/cyclist/dist/bikerack.js"
            if [[ ! -f "$bikerack_js" ]]; then
                echo "Build required..."
                cd "{{pennyfarthing}}" && pnpm run build
            fi

            mkdir -p "$(dirname "$logfile")"
            IS_BIKERACK=1 CYCLIST_PROJECT_DIR="$project_dir" \
                node "$bikerack_js" >> "$logfile" 2>&1 &
            echo $! > "$pid_file"

            # Wait for port file (up to 10s)
            for i in $(seq 1 20); do
                if [[ -f "$port_file" ]]; then
                    port=$(cat "$port_file")
                    echo "WheelHub running at http://127.0.0.1:$port"
                    exit 0
                fi
                sleep 0.5
            done
            echo "Warning: WheelHub didn't start within 10s. Check $logfile"
            ;;
        *)
            echo "Usage: just wheelhub [start|stop|status]"
            exit 1
            ;;
    esac

# Launch TUI (starts WheelHub if needed)
tui:
    #!/usr/bin/env bash
    set -euo pipefail

    pid_file="{{root}}/.wheelhub-pid"
    port_file="{{root}}/.wheelhub-port"

    # Start WheelHub if not running
    if ! ([[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null); then
        just --justfile "{{root}}/justfile" wheelhub start
    fi

    port=$(cat "$port_file" 2>/dev/null)
    if [[ -z "$port" ]]; then
        echo "Error: WheelHub port not found"
        exit 1
    fi

    PYTHONPATH="{{pennyfarthing}}:${PYTHONPATH:-}" \
        python3 -m pennyfarthing_scripts.bikerack.tui --port "$port" --project-dir "{{root}}"

# Launch GUI in Chrome (starts WheelHub if needed)
gui:
    #!/usr/bin/env bash
    set -euo pipefail

    pid_file="{{root}}/.wheelhub-pid"
    port_file="{{root}}/.wheelhub-port"

    # Start WheelHub if not running
    if ! ([[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null); then
        just --justfile "{{root}}/justfile" wheelhub start
    fi

    port=$(cat "$port_file" 2>/dev/null)
    if [[ -z "$port" ]]; then
        echo "Error: WheelHub port not found"
        exit 1
    fi

    url="http://127.0.0.1:$port"
    echo "Opening $url"
    open -a "Google Chrome" "$url"

# =============================================================================
# Development - orchestrator sync with pennyfarthing
# =============================================================================

# Watch pennyfarthing for changes and auto-rebuild (runs pnpm dev)
dev:
    cd {{pennyfarthing}} && pnpm dev

# Manual sync: rebuild pennyfarthing (symlinks auto-update via npm link)
sync:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building pennyfarthing..."
    cd {{pennyfarthing}} && npm run build
    echo "✓ Pennyfarthing rebuilt"
    echo "✓ Symlinks automatically updated (npm link in place)"
    # Show version for confirmation
    echo ""
    echo "Linked version:"
    cat {{pennyfarthing}}/VERSION

# =============================================================================
# Setup & Health
# =============================================================================

# Bootstrap workspace from scratch (fresh clone)
setup:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== Pennyfarthing Orchestrator Setup ==="
    echo ""

    # Step 1: Clone pennyfarthing repo if missing
    if [ ! -d "{{pennyfarthing}}" ]; then
        echo "Step 1/4: Cloning pennyfarthing framework..."
        git clone git@github.com:1898andCo/pennyfarthing.git "{{pennyfarthing}}"
    else
        echo "Step 1/4: pennyfarthing/ already exists, skipping clone"
    fi

    # Step 2: Install framework dependencies
    echo "Step 2/4: Installing framework dependencies..."
    cd "{{pennyfarthing}}" && pnpm install

    # Step 3: Build framework
    echo "Step 3/4: Building framework..."
    cd "{{pennyfarthing}}" && pnpm build

    # Step 4: Install orchestrator deps (triggers postinstall -> pennyfarthing update)
    echo "Step 4/4: Installing orchestrator and linking..."
    cd "{{root}}" && npm install

    echo ""
    echo "=== Setup complete ==="
    echo "Run 'just doctor' to verify."

# Check workspace health
doctor:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== Workspace Health Check ==="
    errors=0

    # Check pennyfarthing/ exists
    if [ -d "{{pennyfarthing}}" ]; then
        echo "  [OK] pennyfarthing/ exists"
    else
        echo "  [FAIL] pennyfarthing/ missing (run: just setup)"
        errors=$((errors + 1))
    fi

    # Check node_modules
    if [ -d "{{root}}/node_modules" ]; then
        echo "  [OK] node_modules/ exists"
    else
        echo "  [FAIL] node_modules/ missing (run: npm install)"
        errors=$((errors + 1))
    fi

    # Check .pennyfarthing symlinks resolve
    for link in agents guides scripts workflows personas; do
        target="{{root}}/.pennyfarthing/$link"
        if [ -L "$target" ] && [ -e "$target" ]; then
            echo "  [OK] .pennyfarthing/$link symlink resolves"
        elif [ -L "$target" ]; then
            echo "  [FAIL] .pennyfarthing/$link broken symlink"
            errors=$((errors + 1))
        else
            echo "  [WARN] .pennyfarthing/$link does not exist"
        fi
    done

    # Check sprint loader health
    export PYTHONPATH="{{pennyfarthing}}:${PYTHONPATH:-}"
    if python3 -c "
    import sys
    sys.path.insert(0, '{{pennyfarthing}}')
    from pennyfarthing_scripts.sprint.loader import load_sprint
    data = load_sprint(project_root=None)
    if data and 'epics' in data:
        epics = data['epics']
        if epics and isinstance(epics[0], str):
            print('  [FAIL] Sprint loader returns unmerged string refs')
            sys.exit(1)
        elif epics and isinstance(epics[0], dict):
            print('  [OK] Sprint loader returns full epic dicts (' + str(len(epics)) + ' epics)')
        else:
            print('  [OK] Sprint has no epics (empty)')
    else:
        print('  [WARN] No sprint data found')
    " 2>/dev/null; then
        :
    else
        echo "  [FAIL] Sprint loader health check failed"
        errors=$((errors + 1))
    fi

    echo ""
    if [ $errors -eq 0 ]; then
        echo "All checks passed."
    else
        echo "$errors check(s) failed."
        exit 1
    fi

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

# Validate agent files against schema
validate-agents *args:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" validate-agents {{args}}

# Validate subagent YAML frontmatter
validate-subagents:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" validate-subagents

# Validate sprint YAML structure
validate-sprint *args:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" validate-sprint {{args}}

# Run all validations
validate: validate-agents validate-subagents validate-sprint
