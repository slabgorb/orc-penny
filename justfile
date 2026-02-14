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

# Launch BikeRack mode (WheelHub on port 2898)
# Run modes: here, dir=/path, stop, status, debug
bikerack *args:
    #!/usr/bin/env bash
    set -euo pipefail

    # Transform 'here' to use invocation directory when delegating
    args="{{args}}"
    if [[ "$args" == *"here"* ]]; then
        args="${args/here/dir={{invocation}}}"
    fi

    # Default to orchestrator root if no dir= given (unless it's stop/status)
    first="${args%% *}"
    if [[ "$first" != "stop" ]] && [[ "$first" != "status" ]]; then
        if [[ "$args" != *"dir="* ]]; then
            args="${args:+$args }dir={{root}}"
        fi
    fi

    # For stop/status, pass --project-dir so it finds the right pid/port files
    if [[ "$first" == "stop" ]] || [[ "$first" == "status" ]]; then
        args="$args --project-dir {{root}}"
    fi

    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" bikerack $args

# Launch BikeRack TUI (connects to running WheelHub)
tui *args:
    #!/usr/bin/env bash
    set -euo pipefail

    args="{{args}}"
    if [[ "$args" == *"here"* ]]; then
        args="${args/here/dir={{invocation}}}"
    fi

    # Default to orchestrator root for port file discovery
    if [[ "$args" != *"dir="* ]]; then
        args="${args:+$args }dir={{root}}"
    fi

    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" tui $args

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
