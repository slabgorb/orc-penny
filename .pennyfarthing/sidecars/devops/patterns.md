# DevOps Agent Patterns

> Pennyfarthing-specific infrastructure patterns

## Claude Code Hook Paths

### Use $CLAUDE_PROJECT_DIR for Hooks
Always use `$CLAUDE_PROJECT_DIR` for hook commands in settings.local.json:

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/hooks/session-start.sh"
      }]
    }]
  }
}
```

**Why:** `$CLAUDE_PROJECT_DIR` is set by Claude Code to the directory where it was started. Relative paths break when Claude runs from subdirectories.

**Anti-pattern:** Don't use `git rev-parse --show-toplevel` as fallback - returns wrong root in nested repos.

## Just Commands

### Standard Project Commands
```bash
just test       # Run all tests
just lint       # Run linters
just build      # Build application
just dev        # Start development server
```

## npm Git-Based Install

### Installing Pennyfarthing from GitHub
Projects can install pennyfarthing directly from GitHub instead of npm registry:

```json
{
  "devDependencies": {
    "pennyfarthing": "github:1898andCo/pennyfarthing#develop"
  }
}
```

**Key learnings:**
1. `dist/` must be committed to git - devDependencies (typescript) aren't installed when package is a dependency
2. The `prepare` script runs after git clone but typescript won't be available
3. Use `#branch` or `#commit` suffix to pin versions
4. Delete `package-lock.json` and `node_modules/pennyfarthing` to force fresh install when debugging

### Root package.json for Monorepos
For projects with sub-packages (e.g., siemulator with siemulator-ui):

```json
{
  "name": "project-name",
  "private": true,
  "workspaces": ["sub-package"],
  "scripts": {
    "dev": "npm run dev --workspace=sub-package"
  },
  "devDependencies": {
    "pennyfarthing": "github:1898andCo/pennyfarthing#develop"
  }
}
```

## Hook Wrappers for Python Scripts

### Established Pattern: find-root.sh + PYTHONPATH + python3 -m
When a Claude Code hook needs to call Python from `pennyfarthing_scripts/`, follow the pattern in `schema-validation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/../lib/find-root.sh"

# Set PYTHONPATH for pennyfarthing_scripts
PENNYFARTHING_SCRIPTS=""
if [[ -d "$PROJECT_ROOT/pennyfarthing" ]]; then
    # Dogfooding: framework inlined in orchestrator
    PENNYFARTHING_SCRIPTS="$PROJECT_ROOT/pennyfarthing"
elif [[ -d "$PROJECT_ROOT/node_modules/@pennyfarthing/core" ]]; then
    # Normal install
    PENNYFARTHING_SCRIPTS="$PROJECT_ROOT/node_modules/@pennyfarthing/core"
fi

if [[ -n "$PENNYFARTHING_SCRIPTS" ]]; then
    export PYTHONPATH="$PENNYFARTHING_SCRIPTS:${PYTHONPATH:-}"
fi

python3 -m pennyfarthing_scripts.module_name
```

**Key points:**
- Shell wrappers live in `pennyfarthing-dist/scripts/hooks/` (distributed via `.pennyfarthing/scripts/` symlink)
- Python implementations live in `pennyfarthing_scripts/` (the Python package)
- `find-root.sh` resolves PROJECT_ROOT from any call site (symlink, direct, etc.)
- PYTHONPATH fallback handles both dogfooding (inlined repo) and normal installs (node_modules)
- Use `python3 -m pennyfarthing_scripts.<module>` not direct file paths
- Template references hooks via `"$CLAUDE_PROJECT_DIR"/.pennyfarthing/scripts/hooks/<name>.sh`

**Anti-pattern:** Don't create hooks that use `pwd -P` + relative `../../..` traversal — it breaks across install layouts.

---

*Add infrastructure patterns discovered during DevOps work below*
