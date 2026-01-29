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
