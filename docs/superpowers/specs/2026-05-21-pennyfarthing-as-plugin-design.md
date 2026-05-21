# Pennyfarthing as a Claude Code Plugin — Design

**Date:** 2026-05-21
**Status:** Draft (pending user review)
**Author:** Architect (Leonard of Quirm)
**Audience:** Implementation planner (writing-plans next)

## 1. Motivation

The current Pennyfarthing install is "invasive" — it requires a global `pip install pennyfarthing`, a per-project `pf init` that drops `.pennyfarthing/` into the user's repo, symlinks into `.claude/agents`/`commands`/`skills`, and direct edits to `.claude/settings.json` for hooks. There is no uninstaller. Turning Pennyfarthing on and off in a project is laborious and leaves debris.

Goals for this change:

1. **One-step install** — `claude plugin install pf` and nothing else.
2. **Clean on/off** — Claude Code's plugin enable/disable toggle is the only thing the user touches; no per-project setup, no surgical edits to settings files.
3. **Zero project pollution** — the user's repo gains no Pennyfarthing-specific directory. Sprint history and ADRs (legitimately project artifacts) remain in the repo because the user wants them in git; everything else moves out.
4. **No global PATH munging** — no `pip install pennyfarthing`, no global `pf` binary required for the framework to function.
5. **Drop hand-rolled `pf-` prefix** — adopt Claude Code's native `<plugin>:<command>` namespacing (matching `superpowers:brainstorming` style).

Non-goals:

- Not redesigning agents, gates, workflows, or any *behavioral* part of Pennyfarthing. This is a packaging / distribution refactor.
- Not maintaining backwards compatibility with the legacy install layout (single user; clean break is cheaper than coexistence code).
- Not changing Cyclist (it is dead) or any other deprecated subsystem.
- Not submitting to `claude-plugins-official` in v1.

## 2. Constraints and Context

- **Single user today.** Keith Avery is the only real Pennyfarthing user. Migration cost is bounded; there is no public deprecation cycle.
- **Pennyfarthing has a Python runtime.** Sprint management, gates, handoff, Frame FastAPI server, jira, prime — all Python (`pf` package). Total dist size ~43 MB including personas/portraits. The runtime must come along; rewriting it to pure shell/markdown is impractical and out of scope.
- **Pennyfarthing has project state.** Sprint YAML, sessions, ADRs, sidecars. Some of this is git-worthy (audit trail); some is ephemeral. The design must split these cleanly.
- **Reference precedent exists.** Keith already authored `brm` as a Claude Code plugin, so the `.claude-plugin/plugin.json` manifest format is known ground. `superpowers` is a deeper reference for plugin patterns.

## 3. Architecture

### 3.1 Repo & Plugin Layout

The plugin source lives in the existing `pennyfarthing/` repo (the framework repo). One repo, one plugin, one marketplace entry.

```
github.com/slabgorb/pennyfarthing
├── .claude-plugin/
│   ├── plugin.json              # name="pf", version, deps
│   └── marketplace.json         # advertises this plugin
├── agents/                      # /pf:* agents (markdown, no pf- prefix on filenames)
├── commands/                    # /pf:* commands (markdown)
├── skills/                      # pf:* skills (markdown)
├── hooks/
│   └── hooks.json               # registers all PreToolUse / SessionStart / etc.
├── workflows/                   # workflow YAMLs
├── personas/                    # themes, portraits, attributes
├── gates/                       # gate definitions
├── templates/, output-styles/, schemas/, guides/
├── runtime/
│   ├── pyproject.toml           # uv project; deps pinned
│   ├── uv.lock                  # committed
│   └── src/pf/                  # full Python package (moved from pennyfarthing-dist/src/pf/)
├── scripts/
│   └── hooks/                   # one-line shell wrappers that exec `uv run pf hooks <name>`
└── README.md                    # install instructions, uv prereq, /pf:* command list
```

Plugin name is `pf` (matches the CLI binary, short, matches `pf:` prefix). Marketplace name is `pennyfarthing` (the repo).

### 3.2 Three Storage Tiers

Every piece of "Pennyfarthing data" lives in exactly one of three tiers. This is the central invariant of the design.

| Tier | Location | Owner | Contents |
|------|----------|-------|----------|
| **Code** (read-only) | `~/.claude/plugins/cache/pennyfarthing/pf/<version>/` | Plugin | All framework code: agents, commands, skills, hooks, gates, workflows, personas, the Python `pf` runtime |
| **Project artifacts** (git-tracked) | `<project>/sprint/`, `<project>/docs/adr/`, `<project>/.session/archived/` | User repo | Sprint history, ADRs, archived sessions — the durable audit trail |
| **Runtime state** (ephemeral) | `${CLAUDE_PLUGIN_DATA}/...` (= `~/.claude/plugins/data/pennyfarthing-pf/`) | User home | Active sessions, sidecars, local config, Frame state |

> **Spike-validated (2026-05-21):** Claude Code injects `CLAUDE_PLUGIN_DATA` into every plugin hook environment, pointing to a per-plugin writable directory under `~/.claude/plugins/data/<marketplace>-<plugin>/`. `pf.paths` resolves runtime state by reading this env var. When `pf` is invoked outside a plugin hook (the §5.2 user shim), `pf.paths` falls back to `~/.claude/data/pf/` so the two contexts agree. See `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` Q1.

Within the runtime-state tier, the discriminator differs by data type (paths written below assume `$PF_DATA = ${CLAUDE_PLUGIN_DATA:-~/.claude/data/pf}`):

| State | Discriminator | Location |
|-------|---------------|----------|
| **Sidecars** (agent learnings — patterns, gotchas, decisions) | `git remote get-url origin` → normalized slug | `$PF_DATA/sidecars/<origin-slug>/<agent>/{patterns,gotchas,decisions}.md` |
| **Active session** | cwd → project hash | `$PF_DATA/projects/<hash>/.session/` |
| **Local config** (`config.local.yaml`) | cwd → project hash | `$PF_DATA/projects/<hash>/config.local.yaml` |
| **Frame server state** (sockets, PIDs, panel snapshots) | cwd → project hash | `$PF_DATA/projects/<hash>/frame/` |

**Rationale for split discriminators:** sidecars are properties of the codebase (two worktrees of the same repo accumulate shared learnings). Active session and Frame state are properties of the working copy (two worktrees may have different in-flight stories). Local config is preference and tied to working copy.

**The invariant:** anything in `$PF_DATA` is recreatable from the framework + the project repo. If you `rm -rf $PF_DATA`, you lose active in-flight sessions and accumulated agent learnings, but nothing canonical. Sprint history, ADRs, archived sessions — all safe in git.

### 3.3 Origin Slug Normalization

Sidecar bucket lookup. Given `git remote get-url origin`, produce a slug:

```
git@github.com:slabgorb/pennyfarthing.git    → github.com/slabgorb/pennyfarthing
https://github.com/slabgorb/pennyfarthing    → github.com/slabgorb/pennyfarthing
ssh://git@github.com/slabgorb/pennyfarthing  → github.com/slabgorb/pennyfarthing
git@gitlab.com:foo/bar.git                   → gitlab.com/foo/bar
(no origin / no remote)                      → _local/<project-hash>
```

Algorithm: strip protocol prefix → strip user@ → replace `:` separator (SSH form) with `/` → strip trailing `.git` → lowercase host. If `git remote get-url origin` fails or returns empty, fall back to `_local/<project-hash>` so unrooted projects still work.

### 3.4 Project Hash

Deterministic per-working-copy identifier. Computed as `sha256(absolute_path_of_git_toplevel)[:12]`. If not in a git repo, falls back to `sha256(cwd)[:12]`. Stable across sessions on the same machine; differs between worktrees of the same origin (correct behavior — they have independent active sessions).

### 3.5 Activation Model

No per-project opt-in. Plugin installed = `/pf:*` commands available in every Claude Code session, everywhere. Sprint/session state gets created lazily, only when a user runs a command that requires it (e.g., `/pf:work` is the first command that materializes `sprint/` in the project).

- `claude plugin install pf@pennyfarthing` → done.
- In a project: `/pf:work` → creates `<project>/sprint/`, `~/.claude/data/pf/projects/<hash>/`, sidecar dirs on demand.
- In a project never touched by `/pf:*` → zero footprint, zero state.
- `claude plugin disable pf` → commands disappear; project artifacts (`sprint/`) and runtime state preserved for next enable.
- `claude plugin uninstall pf` → commands and hooks gone; project artifacts preserved; runtime state in `~/.claude/data/pf/` preserved (manual `rm -rf` if user wants a clean slate).

## 4. Components

| Component | Lives in plugin | Responsibility |
|-----------|-----------------|----------------|
| Plugin manifest (`.claude-plugin/plugin.json`, `marketplace.json`) | Yes | Declares plugin `pf`, version, deps. Marketplace entry. |
| Slash commands (`commands/*.md`) | Yes | Thin invocation files; each activates an agent or runs a skill. Filenames lose the `pf-` prefix. |
| Agents (`agents/*.md`) | Yes | Existing agent personae (architect, dev, tea, reviewer, sm, pm, ba, tech-writer, ux-designer, devops, orchestrator). |
| Skills (`skills/<name>/`) | Yes | Existing skill set (sprint, prime, work, …) referenced via the `Skill` tool. |
| Hooks registration (`hooks/hooks.json`) | Yes | Maps lifecycle events to bundled shell wrappers. Replaces all current `.claude/settings.json` hook entries. |
| Hook shell wrappers (`scripts/hooks/*.sh`) | Yes | One-line wrappers: `exec uv run --project ${CLAUDE_PLUGIN_ROOT}/runtime pf hooks <name> "$@"`. |
| Python runtime (`runtime/`) | Yes | The current `pf` package, moved verbatim from `pennyfarthing-dist/src/pf/`. uv-managed. |
| Workflows / personas / templates / gates / output-styles / guides | Yes | Data files the runtime reads. |
| `paths.py` (NEW) | Yes (in `runtime/src/pf/`) | Single chokepoint that resolves PROJECT_ROOT, PROJECT_DATA, SIDECARS, CONFIG from cwd + git state. |
| Sprint history (`sprint/current-sprint.yaml`, `sprint/epic-*.yaml`) | No — user repo | Written by `pf sprint` commands. Git-tracked. |
| ADRs (`docs/adr/*.md`) | No — user repo | Written by architect agent. Git-tracked. |
| Archived sessions (`.session/archived/*.md`) | No — user repo | Moved here on `pf sprint story finish`. Git-tracked. |
| Active session (`.session/<story-id>-session.md`) | No — `~/.claude/data/pf/projects/<hash>/.session/` | Auto-migrated into repo on story finish. |
| Sidecars (`<agent>/{patterns,gotchas,decisions}.md`) | No — `~/.claude/data/pf/sidecars/<origin-slug>/` | Per-agent learnings, writable. Shared across worktrees of same origin. |
| Local config (`config.local.yaml`) | No — `~/.claude/data/pf/projects/<hash>/` | Theme, bell mode, statusbar, permission mode. |
| Frame server state | No — `~/.claude/data/pf/projects/<hash>/frame/` | OTLP collector socket, panel snapshots, runtime PIDs. |

**What goes away entirely:**

- `.pennyfarthing/` directory in user projects (deleted).
- Symlinks from `.claude/agents`/`commands`/`skills` (deleted).
- `pf-` prefix on every command, agent, and skill filename (renamed).
- `pip install pennyfarthing` (no longer required; PyPI namespace can be retained as a redirect or squat).
- Global `pf` binary on PATH (replaced by optional user shim — see §5.2).
- Hook entries in user's `.claude/settings.json` (moved to plugin's own `hooks/hooks.json`).

## 5. Execution Model

### 5.1 Runtime Invocation

Every invocation of the Python runtime goes through `uv run` rooted at the plugin's runtime dir.

```sh
uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" --quiet pf <subcommand> [args...]
```

`${CLAUDE_PLUGIN_ROOT}` is expanded by Claude Code at hook execution and is available as a literal token in agent markdown's Bash invocations.

> **Spike-validated (2026-05-21):** For directory-source marketplace installs (the dogfooding case in §8.2), `${CLAUDE_PLUGIN_ROOT}` resolves to the **source directory** the marketplace was added from — not a cache copy. Edits to plugin source files are therefore live in the next session without any reinstall ceremony (no `--from-source` flag exists; the route is `claude plugin marketplace add <path>` followed by `claude plugin install <name>@<marketplace>`). See `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` Q1, Q2.

**From a hook shell script** (`scripts/hooks/session-start.sh`):

```sh
#!/usr/bin/env bash
set -euo pipefail
exec uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" --quiet \
  pf hooks session-start "$@"
```

**From an agent's activation step** (in `agents/architect.md`):

```
FIRST: Use Bash tool to run:
  uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" --quiet pf agent start architect
```

**From a long-running process** (`pf frame start`):

```sh
uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" pf frame start --background
```

### 5.2 Optional Interactive Shim

For users (Keith) who want to type `pf sprint status` in a terminal outside Claude Code, a small shim script is provided in the README as a copy-paste install:

```sh
# Drop in ~/.local/bin/pf and chmod +x
#!/usr/bin/env bash
# Resolve the plugin's install dir. Exact path-discovery command depends on
# Claude Code's current API; the fallback is the documented cache layout.
PLUGIN_ROOT="${HOME}/.claude/plugins/cache/pennyfarthing/pf/current"
exec uv run --project "$PLUGIN_ROOT/runtime" --quiet pf "$@"
```

The shim is **optional**. The plugin works fully without it; every Pennyfarthing-internal invocation uses the verbose `uv run` form. The shim is a quality-of-life affordance for shell-level use.

### 5.3 Dependency Management

- `runtime/uv.lock` is committed. Reproducible resolutions across plugin versions.
- `runtime/pyproject.toml` pins major versions; `uv.lock` pins exact.
- First-run dep install runs in the `SessionStart` hook, so the first user-visible command doesn't pay the cost. Cold cache ~1-3s; warm cache ~50ms.
- uv handles Python version itself — `uv run` can fetch a managed CPython if the host doesn't have 3.11+. Zero-host-Python install is supported.

### 5.4 Failure Modes

| Failure | Behavior |
|---------|----------|
| `uv` not on PATH | First hook fails with: `"uv not found. Install via: curl -LsSf https://astral.sh/uv/install.sh \| sh"`. README leads with this. |
| Python 3.11+ unavailable | uv fetches managed CPython; no user action required. |
| Network down on first dep install | First command fails with uv's native error; subsequent runs succeed once cache is warm. Not engineered around. |
| Plugin version mismatch with session file on disk | Existing `pf doctor`-style staleness check covers it, just reads from new location. |
| User edits files in `~/.claude/plugins/cache/...` | README + comment headers warn against it; `pf doctor` can checksum and warn on drift. Not actively prevented — single user, low risk. |

## 6. Hooks Migration

### 6.1 The Settings.json Change

Today, `pf init` writes hook entries into the user's `.claude/settings.json`:

```jsonc
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": ".pennyfarthing/scripts/hooks/session-start.sh" }] }
    ],
    "PostToolUse":  [
      { "matcher": "Write", "hooks": [{ "type": "command", "command": ".pennyfarthing/scripts/hooks/sprint-yaml-validation.sh" }] }
    ]
    // ... ~10 more
  }
}
```

After: the user's `.claude/settings.json` is **never modified by Pennyfarthing**. All hooks register in the plugin's own `hooks/hooks.json`:

```jsonc
// ${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "Write", "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/sprint-yaml-validation.sh" }] }
    ],
    "PreToolUse": [
      { "matcher": "Write", "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/schema-validation.sh" }] }
    ]
    // ... full set
  }
}
```

> **Spike-validated (2026-05-21):** The current Claude Code hooks schema requires the nested `{"hooks": [{"type": "command", "command": "..."}]}` form (both in user `settings.json` and plugin `hooks.json`); the older flat `{"command": "..."}` form is rejected by `claude plugin validate`. When both a user-settings SessionStart hook and a plugin SessionStart hook are registered, the **user hook fires first** (deterministic, ~14ms ahead of the plugin hook). `CLAUDE_PLUGIN_ROOT` is NOT exposed to user-settings hooks — only to plugin hooks. See `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` Q3.

Plugin enable → hooks active. Plugin disable → hooks dormant. Plugin uninstall → hooks gone. Same toggle as commands.

### 6.2 Hook Inventory Mapping

| Today's hook script | Trigger | New location |
|---------------------|---------|--------------|
| `session-start.sh` | SessionStart | `scripts/hooks/session-start.sh` → `pf hooks session-start` |
| `session-stop.sh` | SessionStop | `scripts/hooks/session-stop.sh` → `pf hooks session-stop` |
| `welcome-hook.sh` | SessionStart | Merge into `session-start.sh` (or keep distinct if order matters) |
| `pre-edit-check.sh` | PreToolUse: Edit | `scripts/hooks/pre-edit-check.sh` |
| `pre-commit.sh` | PreToolUse: Bash (git commit) | likewise |
| `pre-push.sh` | PreToolUse: Bash (git push) | likewise |
| `post-merge.sh` | PostToolUse: Bash | likewise |
| `schema-validation.sh` | PreToolUse: Write | likewise |
| `sprint-yaml-validation.sh` | PostToolUse: Write | **Rewrite in Python** (currently broken — Node `yaml` dep missing). Becomes `pf hooks sprint-yaml-validate`. |
| `context-warning.sh`, `context-circuit-breaker.sh` | various | likewise |
| `question-reflector-check.sh` | PreToolUse: AskUserQuestion | likewise |
| `otel-auto-config.sh` | SessionStart | likewise (Frame OTLP setup) |
| `dispatcher-template.sh` | (template, not registered) | stays in plugin source as template |

The `sprint-yaml-validation.sh` rewrite is the only hook with logic changes; everything else is path-substitution. `ruamel.yaml` is already in `pf`'s dependency set, so the Python rewrite is straightforward.

### 6.3 Gates

Gates are pure-Python today (`pf.gates.*`), invoked from agent handoff flow via `pf handoff resolve-gate`. They have no shell layer. The only change: they load from `${CLAUDE_PLUGIN_ROOT}/runtime/src/pf/gates/` instead of the pip-installed location. Path resolution happens through Python's import system; no code change required.

### 6.4 Skills

Claude Code plugins surface skills by directory presence — `skills/<name>/SKILL.md`. Today's `.pennyfarthing/skills/` symlinks vanish; the plugin's `skills/` dir is canonical and Claude Code reads it directly.

## 7. Data Flow

### 7.1 First-time Install

```
1. claude plugin marketplace add slabgorb/pennyfarthing
2. claude plugin install pf@pennyfarthing
   → Claude Code clones repo to ~/.claude/plugins/cache/pennyfarthing/pf/<version>/
   → Reads .claude-plugin/plugin.json
   → Registers commands, agents, skills, hooks from plugin manifest
3. Plugin's first hook firing (or first /pf:* command):
   → uv run --project ${CLAUDE_PLUGIN_ROOT}/runtime pf --version
   → uv resolves deps on first run, caches in ~/.cache/uv/
   → Subsequent runs warm-cache (~50ms)
4. Nothing else. No pf init, no .pennyfarthing/, no settings.json edits.
```

### 7.2 Starting Work in a Project

```
User in ~/Projects/some-repo runs /pf:work
  │
  ▼
Command resolves to agent (SM by default) → loads agent prompt
  │
  ▼
Agent prompt runs `pf agent start sm` (via uv run)
  │
  ▼
pf.paths.discover():
  - cwd ........................ ~/Projects/some-repo
  - git rev-parse --show-toplevel  → PROJECT_ROOT
  - sha256(PROJECT_ROOT)[:12] .. project_hash
  - git remote get-url origin .. origin_slug (or _local/<hash>)
  │
  ▼
pf.paths returns:
  PROJECT_ROOT  = ~/Projects/some-repo
  PROJECT_DATA  = ~/.claude/data/pf/projects/<hash>/    (mkdir -p)
  SIDECARS      = ~/.claude/data/pf/sidecars/<origin>/  (mkdir -p)
  CONFIG        = $PROJECT_DATA/config.local.yaml       (defaults if absent)
  │
  ▼
Agent reads CONFIG (theme, bell, etc.), loads sidecars from SIDECARS,
checks PROJECT_ROOT/sprint/current-sprint.yaml for active sprint
```

Every project-relative path in current code (`.pennyfarthing/...`, project-local `.session/...`) routes through `pf.paths` exactly once. This is the single chokepoint of the migration.

### 7.3 Story Lifecycle

```
SM creates story
  → writes sprint/current-sprint.yaml              [PROJECT — git-tracked]
  → writes $PROJECT_DATA/.session/STORY-session.md [RUNTIME]

Agents work through phases (TEA → Dev → Architect → Reviewer)
  → each agent appends to .session file            [RUNTIME]
  → each agent updates sidecars on exit            [SIDECARS — per origin]
  → ADRs land in docs/adr/                         [PROJECT — git-tracked]

SM finishes story
  → mv $PROJECT_DATA/.session/STORY-session.md
       <project>/.session/archived/STORY-session.md  [PROJECT — git-tracked]
  → updates sprint/ YAML status                    [PROJECT — git-tracked]
  → commits sprint/ + .session/archived/ + docs/adr/
```

## 8. Migration Plan

### 8.1 Keith's One-time Cutover

```sh
# 1. Stop running pf processes
pf frame stop 2>/dev/null
pkill -f "pf frame" 2>/dev/null

# 2. Uninstall the global Python package
pip uninstall pennyfarthing

# 3. Clean each pennyfarthing-using project
for proj in $(pf migrate-from-legacy --scan ~/Projects --list); do
  cd "$proj"
  rm -rf .pennyfarthing/
  # Remove hook entries pointing into .pennyfarthing/
  jq 'del(.hooks[][]? | select(.command | tostring | contains(".pennyfarthing")))' \
    .claude/settings.json > .claude/settings.json.new
  mv .claude/settings.json.new .claude/settings.json
done

# 4. Install uv if not present
curl -LsSf https://astral.sh/uv/install.sh | sh

# 5. Install the plugin
claude plugin marketplace add slabgorb/pennyfarthing
claude plugin install pf@pennyfarthing

# 6. One-shot state migration (dry-run by default)
pf migrate-from-legacy --scan ~/Projects --dry-run
pf migrate-from-legacy --scan ~/Projects --apply
```

`pf migrate-from-legacy` behavior:
- For each detected legacy project under the scan root:
  - Move `.pennyfarthing/sidecars/*` → `~/.claude/data/pf/sidecars/<origin-slug>/`
  - Move `.pennyfarthing/config.local.yaml` → `~/.claude/data/pf/projects/<hash>/config.local.yaml`
  - Move active `.session/*.md` (non-archived) → `~/.claude/data/pf/projects/<hash>/.session/`
- Leave `sprint/`, `docs/adr/`, `.session/archived/` in place (they stay in repo).
- Default `--dry-run` prints the move plan; `--apply` performs it.

`pf migrate-from-legacy` is removed in the v1.0.1 release (single-use, single-user).

### 8.2 Orchestrator Dogfooding

Choice: **D1 — Local-source plugin install.**

```sh
claude plugin marketplace add ~/Projects/orc-penny/pennyfarthing
claude plugin install pf@pennyfarthing
```

> **Spike-validated (2026-05-21):** The `--from-source` flag in earlier drafts does not exist. The actual incantation is `marketplace add <path>` (registers the directory as a single-plugin marketplace) followed by `install <plugin>@<marketplace>`. `${CLAUDE_PLUGIN_ROOT}` resolves to the source directory itself, so edits to `pennyfarthing/agents/architect.md` are picked up by the next session with zero reinstall ceremony — D1 is essentially free. See `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` Q2.

The `orc-penny/` orchestrator repo becomes "just" a Pennyfarthing-using project. Its `.pennyfarthing/` dir goes away like everyone else's. Sprint history continues to live in `orc-penny/sprint/`.

D2 (collapse `orc-penny/` into `pennyfarthing/`) is explicitly **not** in scope. It can be done later if the two-repo split stops serving a purpose; this design accommodates either.

### 8.3 Release Ordering

```
v0.x  (on a branch in pennyfarthing/ repo)
  ├── Add .claude-plugin/{plugin.json, marketplace.json}
  ├── Move pennyfarthing-dist/src/pf/ → runtime/src/pf/
  ├── Move pennyfarthing-dist/agents/* → agents/* (drop pf- prefix)
  ├── Move pennyfarthing-dist/commands/* → commands/* (drop pf- prefix)
  ├── Move pennyfarthing-dist/skills/* → skills/* (drop pf- prefix)
  ├── Move pennyfarthing-dist/{workflows,personas,gates,...} to repo root
  ├── Create runtime/pyproject.toml + uv.lock from existing pyproject.toml
  ├── Create hooks/hooks.json from current settings.json hook entries
  ├── Rewrite scripts/hooks/*.sh as one-line uv-run wrappers
  ├── Rewrite scripts/hooks/sprint-yaml-validation as pf hooks sprint-yaml-validate
  ├── Add runtime/src/pf/paths.py + refactor all project-relative path lookups
  ├── Find/replace all /pf-foo → /pf:foo references in agents, skills, commands, guides
  ├── Write pf migrate-from-legacy
  ├── Spike validation (§10 Gate 1)
v1.0  Cut release tag, marketplace.json points at it
  ├── claude plugin marketplace add slabgorb/pennyfarthing
  ├── Keith runs pf migrate-from-legacy on each machine
  ├── Delete legacy .pennyfarthing/ dirs everywhere
v1.0.1  Remove migrate-from-legacy command
```

## 9. Error Handling and Edge Cases

- **No git repo** — `pf.paths.discover()` falls back to `_local/<sha256(cwd)[:12]>` as both project_hash and origin_slug bucket. All commands continue to function; sidecars accumulate per absolute path.
- **Git repo with no remote** — same fallback; `_local/<hash>` for origin slug.
- **Project hash collision** (theoretical — 48 bits of entropy, single user) — out of scope. `pf doctor` can add a collision check later.
- **Two Claude Code sessions in the same working copy** — share project_hash, share active `.session/` directory. Existing per-story session-file naming (`{story-id}-session.md`) prevents collision as long as the two sessions work on different stories. This matches current behavior.
- **Plugin update mid-session** — Claude Code's plugin update timing is its own concern. Worst case: a session continues running against the old runtime version it was started with, picks up the new version on next SessionStart. Acceptable.
- **Frame server (long-running) outliving the session** — Frame is launched via `pf frame start --background` and is intended to outlive sessions. **Spike-validated (2026-05-21):** plain backgrounding and `setsid` are killed when the hook's process group exits on macOS, but `nohup … & disown` survives (re-parented to PID 1). The SessionStart hook wrapper must use the `nohup` pattern: `nohup uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" pf frame start --background >/dev/null 2>&1 & disown`. See `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md` Q4.

## 10. Risks and Open Questions

### Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `uv` not installed on host | Medium (single-user has it; hypothetical future users won't) | README leads with install command; hooks fail loudly with the install command in the error message |
| `${CLAUDE_PLUGIN_ROOT}` semantics differ from assumption | Medium | Validate via §10.1 spike before scaffolding the runtime |
| First-run uv resolve is slow | Low | `uv sync` in SessionStart hook absorbs the cost before the first user-visible command |
| Project-hash collisions across worktrees | Very low (48 bits, single user) | `pf doctor` collision check, not designed around now |
| Origin-slug collisions (same repo name on different hosts) | Very low | Slug includes host; different hosts → different buckets |
| Plugin source dir looks editable | High annoyance, low danger | README + per-file header comment warns against it; `pf doctor` can checksum and warn |
| Hook runs before cwd is set | Low | All hooks run with cwd = project root by Claude Code convention; `pf.paths.discover()` always works |
| `pf migrate-from-legacy` damages something | Single-run, single-user | `--dry-run` default; requires explicit `--apply` |

### Open questions (spike before commit)

1. ~~**Does `claude plugin install --from-source` hot-reload edits**~~ — **RESOLVED 2026-05-21.** Directory-source marketplace installs make `${CLAUDE_PLUGIN_ROOT}` point at the source dir; edits are live in the next session, no `--from-source` flag exists. See spike results Q2.
2. ~~**Hook ordering between plugin-registered hooks and user `.claude/settings.json` hooks**~~ — **RESOLVED 2026-05-21.** Both fire; user-settings hook first (~14ms ahead, deterministic). `CLAUDE_PLUGIN_ROOT` not visible to user hooks. See spike results Q3.
3. ~~**Long-running processes spawned by hooks**~~ — **RESOLVED 2026-05-21.** `setsid` does NOT survive on macOS; `nohup … & disown` DOES (re-parented to PID 1). `launchctl submit` also works but needs `KeepAlive=false` to avoid restart loops. See spike results Q4.
4. **Plugin-declared permissions vs user settings** — STILL OPEN. Verify how plugin-declared `permissions` and `env` appear and merge so we don't lose current behavior (e.g., the `gh` token unset shim noted in auto-memory). **Micro-spike before Plan 4**: declare a plugin-level `env: { GITHUB_TOKEN: "" }` and check that `gh` works. Until validated, all `gh` invocations from inside the plugin must defensively prefix with `env -u GITHUB_TOKEN`.

Q1–Q3 resolved by Gate 1 spike (`docs/superpowers/spikes/2026-05-21-plugin-spike-results.md`); Q4 remains open and is a precondition for Plan 4 (hooks rewrite).

## 11. Testing Strategy

The work is mechanical but pervasive — many files moved, many path lookups refactored. Four gates.

### Gate 1 — Spike validates assumptions (do this first)

**Status: PASSED 2026-05-21** (Q1–Q3); **Q4 open** (plugin permissions / env merging) — micro-spike scheduled before Plan 4.

- Plan executed: `docs/superpowers/plans/2026-05-21-plugin-spike.md`
- Results: `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md`
- Spec amendments from spike findings are applied above (§3.2, §5.1, §6.1, §8.2, §9, §10).

### Gate 2 — Full plugin works in a fresh project

- After migration: `cd /tmp && mkdir testrepo && cd testrepo && git init`
- `claude plugin install --from-source ~/Projects/orc-penny/pennyfarthing`
- Run a full story arc: `/pf:work` → SM creates story → TEA → Dev → Architect → Reviewer → SM finish.
- Verify:
  - `<testrepo>/sprint/`, `<testrepo>/docs/adr/`, `<testrepo>/.session/archived/` populate
  - `~/.claude/data/pf/projects/<hash>/` populates with runtime state
  - `~/.claude/data/pf/sidecars/_local/<hash>/` populates with learnings (no origin yet)
  - All hook firings observable in `~/.claude/data/pf/projects/<hash>/frame/` or a verbose log

### Gate 3 — Orchestrator dogfooding works

- On `orc-penny/` after migration: run a real sprint story end-to-end using the locally-installed plugin.
- Edit `pennyfarthing/agents/architect.md` (e.g., add a marker comment); confirm change reflects on next session — validates D1.
- Confirm sprint history still commits to `orc-penny/` repo.

### Gate 4 — Existing test suite passes

- `pf` Python unit tests in `pennyfarthing/tests/` run unchanged after the `src/pf/` move — they're agnostic to install path.
- One new test module: `runtime/tests/test_paths.py` covering:
  - Origin slug normalization across all forms in §3.3
  - Project hash determinism for same input
  - Project hash difference between worktrees of same origin
  - Fallback to `_local/<hash>` when no git or no remote

## 12. Out of Scope

- Cyclist (dead; will not be packaged in the plugin).
- Behavioral changes to agents, gates, workflows, or any framework logic.
- Submission to `claude-plugins-official`.
- Coexistence with the legacy install (no backwards-compat code).
- PyPI publishing of the runtime as a standalone package (the runtime is plugin-only).
- Two-repo collapse (orchestrator into framework).
- Multi-user release polish (no user docs beyond the README, no deprecation announcements).

## 13. Summary

Convert Pennyfarthing from an invasive global+per-project install into a Claude Code plugin named `pf`. The plugin lives in the existing `pennyfarthing/` repo, advertises via its own marketplace, and bundles the Python runtime via uv. Three storage tiers — plugin code (read-only), project artifacts (git-tracked), runtime state (`~/.claude/data/pf/...`) — make the on/off story trivial: the user's repo gains no Pennyfarthing dir, settings.json is never touched, and uninstall is just `claude plugin uninstall pf`. Activation is implicit (commands available everywhere, state created lazily). Migration is a one-shot command run once by the single current user, then deleted.

The change is large in scope (many files moved, many paths refactored, hooks rewritten) but small in user impact (one user, clean break, no compatibility shims). The behavioral surface of Pennyfarthing — agents, gates, workflows, story lifecycle — is unchanged.
