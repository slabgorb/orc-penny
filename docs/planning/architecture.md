# Architecture Decision: Pennyfarthing Python CLI

**Status:** Proposed
**Date:** 2026-01-30
**Author:** Mimir (Architect)
**PRD:** docs/planning/prd.md

## Context

Pennyfarthing agent commands rely on bash scripts accessed through symlink chains (`.pennyfarthing/scripts/` → `node_modules/@pennyfarthing/core/scripts/`). These symlinks break frequently, causing agents to waste context debugging paths instead of doing work.

### Problem Statement

- Symlink chains break due to npm reinstalls, permission issues, or platform differences
- Agents see "script not found" errors and attempt manual workarounds
- Path discovery logic (`run.sh` walking up directories) is fragile
- Maintaining bash + symlinks + node is complex

### Existing Infrastructure

| Component | Version | Status |
|-----------|---------|--------|
| `pennyfarthing_scripts/` | 7.6.1 | 60+ files, 9 packages |
| `sprint/cli.py` | Working | argparse-based CLI |
| `prime/` | Working | Agent context priming |
| `workflow.py` | Working | Scale level detection |

## Decision Drivers

1. **Zero path errors** - Commands must execute without path debugging
2. **< 200ms startup** - Agent activation must be fast (NFR2)
3. **Coexistence** - Bash scripts must work during migration
4. **Developer ergonomics** - Easy to add new commands (FR18)
5. **Reuse-first** - Leverage existing Python infrastructure

## Considered Options

### Option 1: Keep argparse (Existing Pattern)

- **Pros:** No new dependency, existing pattern in sprint/cli.py
- **Cons:** Verbose, manual subcommand handling, PRD specifies Click

### Option 2: Click with Lazy Loading (Selected)

- **Pros:** PRD-specified, decorator-based, natural command groups, rich help
- **Cons:** New dependency (~80KB)

### Option 3: Typer

- **Pros:** Type hints, modern DX
- **Cons:** Extra dependency layer, 0.x version less stable

## Decision Outcome

**Selected: Click with Lazy Loading**

Click provides the decorator-based extension pattern specified in the PRD (FR18), with `@click.group()` for natural command hierarchy. Lazy imports maintain startup performance.

### Invocation Pattern

```bash
# Module-based (works everywhere)
python -m pennyfarthing_scripts.cli <group> <command>

# Future: entry point script
pf <group> <command>
```

## Component Structure

```
pennyfarthing_scripts/
├── cli.py              # Entry point (@click.group pf)
├── agent/              # Agent lifecycle
│   ├── session.py      # Session file management
│   ├── sidecar.py      # Sidecar memory (patterns, gotchas, decisions) [FR12]
│   └── cli.py          # pf agent start/stop/list/refresh
├── workflow/           # Workflow operations
│   ├── check.py        # Workflow state detection
│   ├── handoff.py      # Handoff marker + validation
│   └── cli.py          # pf workflow check/handoff/phase-check
├── persona/            # Persona/theme handling
│   └── theme.py        # Theme loading, version check
├── config/             # Configuration
│   └── preferences.py  # User preferences, project root
├── sprint/             # EXISTING: Migrate from argparse to Click
│   └── story.py        # Story details by ID [FR15]
├── prime/              # EXISTING: Context priming (loads sidecars)
├── common/             # EXISTING: Shared utilities
│   ├── output.py       # Formatted output, error handling
│   ├── paths.py        # Project root discovery
│   └── errors.py       # Error handling, auto-bug creation [FR16]
└── sidecar/            # Sidecar file operations
    └── loader.py       # Load patterns.md, gotchas.md, decisions.md
```

## Interfaces

### CLI Commands

| Command | Purpose | Exit Codes |
|---------|---------|------------|
| `pf agent start <name>` | Start agent session (loads sidecar) | 0=success, 1=error |
| `pf agent stop` | Stop current session | 0=success |
| `pf agent sidecar <agent>` | Load sidecar memory (FR12) | 0=always |
| `pf workflow check` | Get workflow state | 0=always |
| `pf workflow handoff <agent>` | Emit handoff marker | 0=success |
| `pf sprint status` | Show sprint state | 0=always |
| `pf sprint backlog` | List available work | 0=always |
| `pf sprint story <id>` | Get story details by ID (FR15) | 0=found, 1=not found |

### Output Format

- **Default:** Markdown (agent-friendly)
- **`--json` flag:** JSON (machine parsing)
- **Errors:** stderr, non-zero exit

### Contracts

1. Exit code 0 for valid empty states (e.g., no session)
2. Exit code 1+ for real errors only
3. All output UTF-8 encoded
4. No interactive prompts (agent context)
5. Never silently fail - always produce output or error (NFR4)
6. Respect existing file formats (session .md, sprint YAML) (NFR9)

### Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Startup time | < 200ms | `time python -m pennyfarthing_scripts.cli --help` |
| Command completion | < 500ms | Typical operations (NFR1) |
| JSON overhead | Negligible | No measurable difference vs markdown (NFR3) |

### Error Handling & Graceful Degradation

| Scenario | Behavior |
|----------|----------|
| **Partial failure** (e.g., one field missing) | Continue with available data, warn on stderr (NFR5) |
| **Optional dependency unavailable** | Degrade gracefully, skip feature (NFR6) |
| **Hard failure** (unrecoverable) | Auto-create bug story in sprint YAML (FR16) |
| **Missing file** | Clear error message, exit 1 |

#### Auto-Bug Creation (FR16)

On unrecoverable errors, `common/errors.py` creates a bug story:

```python
def handle_hard_failure(error: Exception, context: str) -> None:
    """Log error, create bug story, exit non-zero."""
    # 1. Write error details to stderr
    # 2. Create bug story in sprint/current-sprint.yaml
    # 3. Exit with code 1
```

## Consequences

### Positive

- **Eliminates symlink failures** - Module resolution replaces path hunting
- **Single entry point** - All commands via `pf` or `python -m`
- **Faster development** - Click decorators vs bash functions
- **Testable** - Python unit tests vs bash integration tests
- **Type hints** - Better IDE support

### Negative

- **New dependency** - Click added to pyproject.toml
- **Migration effort** - Must port bash logic to Python
- **Coexistence complexity** - Two systems during transition

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Startup > 200ms | Lazy imports, benchmark in CI |
| Command > 500ms | Profile slow paths, async where beneficial |
| Bash/Python parity | Integration tests comparing output |
| Incomplete migration | Phased approach, bash preserved until complete |
| Silent failures | R8/R9 rules, always produce output |
| Corrupted sprint YAML | Validate before write, backup on modify |

## Implementation Consistency Rules

> Rules that ensure AI agents implement consistently

| Rule | Specification |
|------|---------------|
| R1 | All CLI commands use `@click.command()` decorators |
| R2 | Exit 0 for success/empty, non-zero for errors only |
| R3 | Default output Markdown, `--json` for JSON |
| R4 | Lazy imports via `from x import y` inside functions |
| R5 | Project root via `common/paths.get_project_root()` |
| R6 | Errors to stderr via `common/output.error()` |
| R7 | All handlers return `int` (exit code) |
| R8 | Partial failures: continue with available data, warn stderr |
| R9 | Hard failures: call `common/errors.handle_hard_failure()` |
| R10 | Sidecar loading: use `sidecar/loader.py` for memory files |

## Migration Phases

### Phase 1: MVP (Stop the Bleeding)

Scripts called on every agent activation:

| Bash Script | Python Command |
|-------------|----------------|
| `agent-session.sh start` | `pf agent start` |
| `phase-check-start.sh` | `pf workflow phase-check` |
| `workflow-status-check` | `pf workflow check` |

### Phase 2: Core Operations

| Bash Script | Python Command |
|-------------|----------------|
| `sprint-status.sh` | `pf sprint status` |
| `available-stories.sh` | `pf sprint backlog` |
| `handoff-marker.sh` | `pf workflow handoff` |

### Phase 3: Full Migration

Remaining scripts migrated as bandwidth allows. Low-frequency utilities can stay bash longer.

## Dependencies

```toml
# pyproject.toml
dependencies = [
    "pyyaml>=6.0",
    "httpx>=0.28",
    "click>=8.0,<9.0",  # NEW
]
```

## Related Decisions

- [ADR-0005: Single Source of Truth via Symlinks](../adr/0005-single-source-of-truth-symlinks.md) - The problem being solved
- [ADR-0018: Sprint YAML Script Access](../adr/0018-sprint-yaml-script-access.md) - Related script patterns

## Next Steps

1. Add Click to dependencies
2. Create `cli.py` entry point with lazy-loaded groups
3. Implement `pf agent start` (highest frequency)
4. Update agent command files to use Python invocation
5. Run parallel with bash until validated
