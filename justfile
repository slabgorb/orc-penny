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
# Build & Test - delegates to pennyfarthing repo
# =============================================================================

# Build all packages
build:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" build

# Run tests for all packages
test:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" test

# Run tests for GUI package only
test-gui:
    just --justfile "{{pennyfarthing}}/justfile" --working-directory "{{pennyfarthing}}" test-gui

# =============================================================================
# Git
# =============================================================================

# Pull orchestrator + pennyfarthing onto their default branches (feature branches left alone)
pull:
    #!/usr/bin/env bash
    set -uo pipefail
    failed=""
    pull_one() {
      dir="$1"; name="$2"; target="$3"
      echo "==> $name"
      if ! cur=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null); then
        echo "    !! not a git checkout — skipped"
        failed="$failed $name"
        return
      fi
      if [ "$cur" = "$target" ]; then
        git -C "$dir" pull --rebase --autostash origin "$target" || failed="$failed $name"
      else
        echo "    on '$cur', not '$target' — your checkout is left alone; advancing $target"
        if ! git -C "$dir" fetch origin "$target:$target"; then
          echo "    !! could not fast-forward $target — it has diverged from origin."
          echo "       Fetched anyway; reconcile by hand: git -C $dir log $target..origin/$target"
          git -C "$dir" fetch origin "$target"
          failed="$failed $name"
        fi
      fi
    }
    pull_one {{root}} "orc-penny (orchestrator)" main
    pull_one {{pennyfarthing}} "pennyfarthing" develop
    if [ -n "$failed" ]; then
      echo
      echo "!! pull incomplete:$failed"
      exit 1
    fi
    echo
    echo "pull complete."

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

# Launch TUI in dev mode (auto-reload on Python file changes)
tui-dev:
    #!/usr/bin/env bash
    set -euo pipefail

    # pf launch frame is idempotent — probes /health and reuses a live instance
    just --justfile "{{root}}/justfile" frame

    port=$(cat "{{root}}/.frame-port" 2>/dev/null)
    if [[ -z "$port" ]]; then
        echo "Error: Frame server port not found"
        exit 1
    fi

    PYTHONPATH="{{root}}/pennyfarthing/pennyfarthing-dist/src" \
        python3 -c "from pf.tui.app import dev_main; from pathlib import Path; dev_main(port=$port, project_dir=Path('{{root}}'))"

# =============================================================================
# tmux — see .pennyfarthing/justfile.pf
# =============================================================================

# =============================================================================
# Development
# =============================================================================

# Build the web dashboard (React/Vite) and write assets into pf/frame/webui/dist/
web-build:
    cd {{pennyfarthing}}/web && npm ci && npm run build

# Launch the web GUI — builds if needed, starts Frame if needed, opens browser
gui:
    #!/usr/bin/env bash
    set -euo pipefail

    # Frame mounts the webui dir at startup, so ensure the build exists first
    if [[ ! -f "{{pennyfarthing}}/pennyfarthing-dist/src/pf/frame/webui/dist/index.html" ]]; then
        echo "No web build found — running web-build..."
        just --justfile "{{root}}/justfile" web-build
    fi

    # pf launch frame is idempotent — probes /health and reuses a live instance
    just --justfile "{{root}}/justfile" frame

    port=$(cat "{{root}}/.frame-port" 2>/dev/null)
    if [[ -z "$port" ]]; then
        echo "Error: Frame server port not found (.frame-port missing)" >&2
        exit 1
    fi
    open "http://localhost:$port"

# Launch the web GUI in dev mode (vite hot reload, proxies API/WS to Frame)
gui-dev:
    #!/usr/bin/env bash
    set -euo pipefail

    just --justfile "{{root}}/justfile" frame

    port=$(cat "{{root}}/.frame-port" 2>/dev/null || true)
    if [[ "$port" != "2898" ]]; then
        echo "Warning: Frame is on port ${port:-unknown} but vite proxies to 2898 (web/vite.config.ts)" >&2
        echo "Restart Frame on the default port: just frame-stop && FRAME_PORT=2898 just frame" >&2
    fi
    cd "{{pennyfarthing}}/web" && npm run dev -- --open

# Watch pennyfarthing for changes and auto-rebuild (runs pnpm dev)
dev:
    cd {{pennyfarthing}} && pnpm dev

# =============================================================================
# Setup
# =============================================================================

# Bootstrap workspace from scratch (fresh clone).
# Framework is Python-only (v13+); no Node/pnpm required.
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

    # Step 1: Clone pennyfarthing repo if missing (inlined framework source)
    if [ ! -d "{{pennyfarthing}}" ]; then
        echo "Step 1/4: Cloning pennyfarthing framework..."
        git clone git@github.com:slabgorb/pennyfarthing.git "{{pennyfarthing}}"
    else
        echo "Step 1/4: pennyfarthing/ already exists, skipping clone"
    fi

    # Step 2: Install pf CLI (editable install from the inlined repo — stays in sync)
    echo "Step 2/4: Installing pf CLI from local repo..."
    just --justfile "{{root}}/justfile" update-pf
    if ! command -v pf >/dev/null 2>&1; then
        echo ""
        echo "Warning: pf installed but not on PATH."
        echo "  If using uv/pipx, ensure ~/.local/bin is on PATH."
        echo "  Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo "  Then restart your shell and re-run: just setup"
        exit 1
    fi
    echo "  Installed: $(pf --version 2>&1)"

    # Step 3: Initialize project — dogfooding-aware (creates symlinks, not copies)
    echo "Step 3/4: Initializing Pennyfarthing project..."
    cd "{{root}}" && pf init --yes

    # Step 4: Install required Claude Code plugin (idempotent; /plugin install is a no-op if present)
    echo "Step 4/4: Checking superpowers Claude Code plugin..."
    if [ -d "$HOME/.claude/plugins/cache/claude-plugins-official/superpowers" ]; then
        echo "  superpowers plugin already installed"
    else
        echo "  superpowers plugin not found."
        echo "  Inside Claude Code, run:  /plugin install superpowers@claude-plugins-official"
    fi

    echo ""
    echo "=== Setup complete ==="
    echo ""
    echo "Verify: pf doctor"
    echo "Next:   pf theme set <name>   # see: pf theme list"
    echo "Then:   claude                # start Claude Code"

# Update the global pf CLI from the local framework source.
# Editable install keeps pure-Python changes live automatically; --force re-resolves
# dependencies and refreshes entry points. Run after pulling pennyfarthing/ when
# dependencies or the pf entry point change (a plain code pull needs no reinstall).
update-pf:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Updating pf CLI (editable) from {{pennyfarthing}}..."
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
    hash -r 2>/dev/null || true
    # Non-fatal: setup handles the not-on-PATH case with a friendlier message.
    echo "  Installed: $(pf --version 2>&1 || echo 'pf not yet on PATH')"

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
