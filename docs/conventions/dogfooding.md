# Dogfooding

How to consume Pennyfarthing from source during framework development. The orchestrator repo inlines the framework repo and uses symlinks to bypass the published package, ensuring changes are tested live before publishing.

> **Two consumption modes exist.** Normal consumer projects run `pf init` and get flat file copies in `.pennyfarthing/`. Dogfooding projects inline the framework repo and symlink to `pennyfarthing-dist/` directly. `pf init` **auto-detects** dogfooding mode and preserves symlinks.

## Architecture

```
project-root/
├── .claude/
│   ├── commands → ../pennyfarthing/pennyfarthing-dist/commands   ← Claude reads these
│   ├── skills   → ../pennyfarthing/pennyfarthing-dist/skills     ← Claude reads these
│   └── settings.local.json
├── .pennyfarthing/
│   ├── agents       → ../pennyfarthing/pennyfarthing-dist/agents
│   ├── commands     → ../pennyfarthing/pennyfarthing-dist/commands
│   ├── data         → ../pennyfarthing/pennyfarthing-dist/data
│   ├── gates        → ../pennyfarthing/pennyfarthing-dist/gates
│   ├── guides       → ../pennyfarthing/pennyfarthing-dist/guides
│   ├── output-styles → ../pennyfarthing/pennyfarthing-dist/output-styles
│   ├── personas     → ../pennyfarthing/pennyfarthing-dist/personas
│   ├── scripts      → ../pennyfarthing/pennyfarthing-dist/scripts
│   ├── skills       → ../pennyfarthing/pennyfarthing-dist/skills
│   ├── templates    → ../pennyfarthing/pennyfarthing-dist/templates
│   ├── workflows    → ../pennyfarthing/pennyfarthing-dist/workflows
│   ├── bin/
│   │   └── pf                ← shim (machine-specific, gitignored)
│   ├── sidecars/             ← real directory (local, writable)
│   ├── config.local.yaml
│   └── repos.yaml
├── pennyfarthing/            ← inlined framework repo (separate git)
│   └── pennyfarthing-dist/   ← source of truth
└── .envrc                    ← direnv activates Python environment
```

## How `pf init` Works in Dogfooding Mode

`pf init` detects dogfooding by checking whether `pennyfarthing/pennyfarthing-dist/` exists and resolves to the same path as the dist root it was given. When detected:

| Step | Consumer mode | Dogfooding mode |
|------|--------------|-----------------|
| Directory creation | Creates `.pennyfarthing/*` dirs | Skips dirs that will be symlinks |
| Commands/skills/content | Flat copies from dist | Symlinks to `pennyfarthing-dist/` |
| Pf shim (`.pennyfarthing/bin/pf`) | Created | Created |
| `repos.yaml` | Auto-discovered | Preserved (hand-maintained) |
| `config.local.yaml` theme | Written with default | Preserved (existing config) |
| Portrait LFS pull | Yes | Skipped (personas dir is a symlink) |
| `settings.local.json` | Written/upgraded | Written/upgraded |
| `.gitignore` | Updated | Updated |
| Justfile | Updated | Updated |
| WheelHub server | Installed | Installed |

Running `pf init` in the dogfooding repo is safe and idempotent. It repairs broken symlinks without destroying hand-maintained config.

## Symlink Layers

There are two symlink layers, each serving a different consumer:

| Layer | Consumer | Points to |
|-------|----------|-----------|
| `.claude/commands` | Claude Code (slash commands) | `pennyfarthing/pennyfarthing-dist/commands` |
| `.claude/skills` | Claude Code (skills) | `pennyfarthing/pennyfarthing-dist/skills` |
| `.pennyfarthing/*` | Framework scripts, hooks, agents | `pennyfarthing/pennyfarthing-dist/*` |

**Both layers must point to the dev source** (`pennyfarthing/pennyfarthing-dist/`), never to flat copies. Symlinks ensure edits to `pennyfarthing-dist/` are reflected immediately at runtime.

## Python Environment (direnv)

The dogfooding repo uses `.envrc` with direnv for Python environment management:

```bash
# .envrc activates the Python venv and adds pf to PATH
# direnv automatically loads/unloads when entering/leaving the directory
direnv allow
```

The `pf` CLI is installed via `pipx install pennyfarthing-scripts` (or pip editable install for development). The `.pennyfarthing/bin/pf` shim delegates to the installed `pf` binary with the correct `PYTHONPATH`.

## Common Drift Scenarios

### 1. Skills/commands not updating after edits

**Symptom:** Claude shows old skill names, new commands don't appear.

**Cause:** `.claude/skills` or `.claude/commands` is a flat directory (not a symlink) — likely from a previous `pf init` before dogfooding detection existed.

**Fix:** `pf init` now auto-repairs this. Or manually:
```bash
rm -rf .claude/skills && ln -s ../pennyfarthing/pennyfarthing-dist/skills .claude/skills
rm -rf .claude/commands && ln -s ../pennyfarthing/pennyfarthing-dist/commands .claude/commands
```

### 2. Permission entries use old names

**Symptom:** Skill invocation prompts for permission even though `Skill(*)` is in the allow list.

**Cause:** `settings.local.json` has `Skill(sprint)` but the skill directory is now `pf-sprint`.

**Fix:** Update permission entries in `.claude/settings.local.json` to match current skill directory names.

### 3. Missing `.pennyfarthing/bin/pf` shim

**Symptom:** Every hook errors with "pf: command not found" or similar.

**Cause:** `git clean` or `git checkout -- .` deleted the shim. The shim is gitignored because it contains machine-specific absolute paths.

**Fix:** Run `pf init` (restores the shim) or manually:
```bash
python3 -c "
from pf.common.discovery import resolve_pf_binary, write_shim
r = resolve_pf_binary()
if r['success']: write_shim('.', r)
"
```

### 4. `pf init` preserves symlinks automatically

In previous versions, running `pf init` would overwrite dogfooding symlinks with flat copies. This is now fixed — `pf init` auto-detects dogfooding mode and creates/repairs symlinks instead of copying.

## Verification Checklist

Run this to verify all symlinks point to dev source:

```bash
# All .claude symlinks should point to ../pennyfarthing/pennyfarthing-dist/
ls -la .claude/commands .claude/skills

# All .pennyfarthing symlinks should point to ../pennyfarthing/pennyfarthing-dist/
ls -la .pennyfarthing/agents .pennyfarthing/commands .pennyfarthing/data \
       .pennyfarthing/gates .pennyfarthing/guides .pennyfarthing/output-styles \
       .pennyfarthing/personas .pennyfarthing/scripts .pennyfarthing/skills \
       .pennyfarthing/templates .pennyfarthing/workflows

# Shim should exist and work
.pennyfarthing/bin/pf --version

# Hooks should dispatch correctly
.pennyfarthing/bin/pf hooks dispatch Stop < /dev/null
```

## Non-Symlinked Paths

These directories are **not symlinked** and are real, local directories:

| Path | Why |
|------|-----|
| `.pennyfarthing/sidecars/` | Agent learning files — per-project, writable |
| `.pennyfarthing/project/` | Project-local overrides (skills, config) |
| `.pennyfarthing/artifacts/` | Build/session artifacts |
| `.pennyfarthing/.cache/` | Runtime caches |
| `.pennyfarthing/config.local.yaml` | Project configuration |
| `.pennyfarthing/repos.yaml` | Repository topology (hand-maintained in dogfooding) |
| `.pennyfarthing/bin/` | Machine-specific pf shim (gitignored) |

## Naming Conventions

Framework resources use the `pf-` prefix to avoid collisions with user-defined or third-party resources:

| Resource | Dev source name | Invocation |
|----------|----------------|------------|
| Skills | `pf-sprint/` | `/pf-sprint` |
| Commands | `pf-dev.md` | `/pf-dev` |

**Exception:** Benchmark skills (`finalize-run`, `judge`, `persona-benchmark`) in `packages/benchmark/skills/` do not use the prefix — they are package-scoped, not framework-scoped.
