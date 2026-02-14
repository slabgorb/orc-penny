# Dogfooding

How to consume Pennyfarthing from source during framework development. The orchestrator repo inlines the framework repo and uses symlinks to bypass the published npm package, ensuring changes are tested live before publishing.

> **Two consumption modes exist.** Normal projects install `@pennyfarthing/core` from npm and get `node_modules/` paths. Dogfooding projects inline the framework repo and symlink to `pennyfarthing-dist/` directly. When things drift between these two, skills/commands/agents may silently load stale definitions from the published package.

## Architecture

```
project-root/
├── .claude/
│   ├── commands → ../pennyfarthing/pennyfarthing-dist/commands   ← Claude reads these
│   ├── skills   → ../pennyfarthing/pennyfarthing-dist/skills     ← Claude reads these
│   └── settings.local.json → ../.pennyfarthing/settings.local.json
├── .pennyfarthing/
│   ├── agents       → ../pennyfarthing/pennyfarthing-dist/agents
│   ├── guides       → ../pennyfarthing/pennyfarthing-dist/guides
│   ├── output-styles → ../pennyfarthing/pennyfarthing-dist/output-styles
│   ├── personas     → ../pennyfarthing/pennyfarthing-dist/personas
│   ├── scripts      → ../pennyfarthing/pennyfarthing-dist/scripts
│   ├── skills       → ../pennyfarthing/pennyfarthing-dist/skills
│   ├── workflows    → ../pennyfarthing/pennyfarthing-dist/workflows
│   ├── sidecars/    ← real directory (local, writable)
│   ├── config.local.yaml
│   └── settings.local.json
├── pennyfarthing/                ← inlined framework repo (separate git)
│   └── pennyfarthing-dist/      ← source of truth
└── node_modules/
    └── @pennyfarthing/core/
        └── pennyfarthing-dist/  ← published snapshot (STALE in dogfooding)
```

## Symlink Layers

There are two symlink layers, each serving a different consumer:

| Layer | Consumer | Points to |
|-------|----------|-----------|
| `.claude/commands` | Claude Code (slash commands) | `pennyfarthing/pennyfarthing-dist/commands` |
| `.claude/skills` | Claude Code (skills) | `pennyfarthing/pennyfarthing-dist/skills` |
| `.pennyfarthing/*` | Framework scripts, hooks, agents | `pennyfarthing/pennyfarthing-dist/*` |

**Both layers must point to the dev source** (`pennyfarthing/pennyfarthing-dist/`), never to `node_modules/`. The published package in `node_modules/` is a frozen snapshot from the last `npm publish` — it will not reflect uncommitted changes.

## Common Drift Scenarios

### 1. Skills/Commands renamed but symlinks still point to node_modules

**Symptom:** Claude shows old skill names, new commands don't appear, `/pf-sprint` not recognized.

**Cause:** `.claude/skills` or `.claude/commands` symlink targets `node_modules/@pennyfarthing/core/pennyfarthing-dist/...` instead of the dev source.

**Fix:**
```bash
rm .claude/skills && ln -s ../pennyfarthing/pennyfarthing-dist/skills .claude/skills
rm .claude/commands && ln -s ../pennyfarthing/pennyfarthing-dist/commands .claude/commands
```

### 2. Permission entries use old names

**Symptom:** Skill invocation prompts for permission even though `Skill(*)` is in the allow list, or specific `Skill(name)` entries don't match actual skill directory names.

**Cause:** `settings.local.json` has `Skill(sprint)` but the skill directory is now `pf-sprint`.

**Fix:** Update permission entries in `.pennyfarthing/settings.local.json` to match current skill directory names.

### 3. Missing .pennyfarthing symlink

**Symptom:** Framework scripts can't find a resource, or an agent definition references a path that doesn't resolve.

**Cause:** A new resource type was added to `pennyfarthing-dist/` but the corresponding symlink in `.pennyfarthing/` was never created.

**Fix:**
```bash
ln -s ../pennyfarthing/pennyfarthing-dist/{resource} .pennyfarthing/{resource}
```

Then add the path to `managedPaths` in `.pennyfarthing/manifest.json`.

### 4. pennyfarthing init/update overwrites dogfooding symlinks

**Symptom:** After running `pennyfarthing update`, symlinks revert to `node_modules/` paths.

**Cause:** The CLI's update command assumes the standard installation mode and rewrites symlinks to point at the npm package.

**Fix:** Re-run the symlink setup after any `pennyfarthing init` or `pennyfarthing update`. Consider adding a `just dogfood` recipe to automate this.

## Verification Checklist

Run this to verify all symlinks point to dev source, not `node_modules`:

```bash
# All .claude symlinks should point to ../pennyfarthing/pennyfarthing-dist/
ls -la .claude/commands .claude/skills

# All .pennyfarthing symlinks should point to ../pennyfarthing/pennyfarthing-dist/
ls -la .pennyfarthing/agents .pennyfarthing/guides .pennyfarthing/output-styles \
       .pennyfarthing/personas .pennyfarthing/scripts .pennyfarthing/skills \
       .pennyfarthing/workflows

# None should contain "node_modules"
readlink .claude/commands .claude/skills | grep -c node_modules
# Expected: 0
```

## Symlink Setup (Full)

For setting up dogfooding from scratch or after a `pennyfarthing update` overwrites:

```bash
# .pennyfarthing layer (framework scripts, agents, hooks)
ln -sf ../pennyfarthing/pennyfarthing-dist/agents       .pennyfarthing/agents
ln -sf ../pennyfarthing/pennyfarthing-dist/guides       .pennyfarthing/guides
ln -sf ../pennyfarthing/pennyfarthing-dist/output-styles .pennyfarthing/output-styles
ln -sf ../pennyfarthing/pennyfarthing-dist/personas     .pennyfarthing/personas
ln -sf ../pennyfarthing/pennyfarthing-dist/scripts      .pennyfarthing/scripts
ln -sf ../pennyfarthing/pennyfarthing-dist/skills       .pennyfarthing/skills
ln -sf ../pennyfarthing/pennyfarthing-dist/workflows    .pennyfarthing/workflows

# .claude layer (Claude Code reads these)
ln -sf ../pennyfarthing/pennyfarthing-dist/commands     .claude/commands
ln -sf ../pennyfarthing/pennyfarthing-dist/skills       .claude/skills
```

## Non-Dogfooding Paths

These directories are **not symlinked** and are real, local directories:

| Path | Why |
|------|-----|
| `.pennyfarthing/sidecars/` | Agent learning files — per-project, writable |
| `.pennyfarthing/project/` | Project-local overrides (skills, config) |
| `.pennyfarthing/artifacts/` | Build/session artifacts |
| `.pennyfarthing/.cache/` | Runtime caches |
| `.pennyfarthing/config.local.yaml` | Project configuration |
| `.pennyfarthing/settings.local.json` | Claude Code settings (permissions, hooks) |

## Naming Conventions

Framework resources use the `pf-` prefix to avoid collisions with user-defined or third-party resources:

| Resource | Dev source name | Invocation |
|----------|----------------|------------|
| Skills | `pf-sprint/` | `/pf-sprint` |
| Commands | `pf-dev.md` | `/pf-dev` |

**Exception:** Benchmark skills (`finalize-run`, `judge`, `persona-benchmark`) in `packages/benchmark/skills/` do not use the prefix — they are package-scoped, not framework-scoped.

## Manifest

`.pennyfarthing/manifest.json` tracks which paths are managed by the framework installer. When adding a new symlinked resource type, add it to `managedPaths`:

```json
{
  "managedPaths": [
    ".claude/commands",
    ".claude/skills",
    ".pennyfarthing/agents",
    ".pennyfarthing/guides",
    ".pennyfarthing/output-styles",
    ".pennyfarthing/personas",
    ".pennyfarthing/scripts",
    ".pennyfarthing/skills",
    ".pennyfarthing/workflows"
  ]
}
```
