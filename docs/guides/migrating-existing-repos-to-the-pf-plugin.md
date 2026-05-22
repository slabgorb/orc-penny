# Migrating an Existing Repo to the `pf` Plugin

A runbook for cutting an existing Pennyfarthing-using repo over from the legacy
invasive install (`.pennyfarthing/` + hooks written into `.claude/settings.local.json`
+ a global `pf`) to the Claude Code **`pf` plugin**.

This is a **manual, per-repo** process by design — there is no `pf migrate-from-legacy`
command and none is planned. The steps are copy-paste-able; you run them once per repo.

> **Status note (2026-05-22):** the plugin's hooks are code-complete on
> `feat/plugin-scaffold-and-paths` but a few plugin behaviors are still being
> verified end-to-end (plugin `env`/`gh` token merging, a full live-session run,
> and `statusLine` support). Where a step depends on one of those, it's flagged
> inline. Don't cut a repo over until the plugin is merged to `develop` and installed.

---

## Mental model: what moves where

After migration, every piece of Pennyfarthing data lives in exactly one of three tiers:

| Tier | Where | Migrate it? |
|------|-------|-------------|
| **Framework code** (agents, commands, skills, hooks, the Python runtime) | `~/.claude/plugins/cache/pennyfarthing/pf/<version>/` (plugin-managed) | No — the plugin owns it. The old `.pennyfarthing/` symlink tree is deleted. |
| **Project artifacts** (git-tracked audit trail) | stays in the repo: `sprint/`, `docs/adr/`, `.session/archived/` | No — leave in place, keep committing. |
| **Runtime state** (ephemeral) | `~/.claude/plugins/data/pennyfarthing-pf/` (or `~/.claude/data/pf/` fallback) | Optionally — active sessions, sidecars, `config.local.yaml`. Recreatable if you skip it. |

The invariant: anything outside the repo's git-tracked tier is recreatable from the
framework + the repo. If you lose runtime state you lose in-flight sessions and
accumulated agent learnings, nothing canonical.

---

## Prerequisites (once per machine)

1. **`uv` installed** — the plugin runs the Python runtime via `uv run`. If missing:
   ```sh
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```
   (uv fetches a managed CPython if the host lacks 3.11+, so no separate Python install is needed.)

2. **Install the plugin** (once):
   ```sh
   # From the published repo:
   claude plugin marketplace add slabgorb/pennyfarthing
   claude plugin install pf@pennyfarthing

   # — or, for local dogfooding from a source checkout:
   claude plugin marketplace add ~/Projects/orc-penny/pennyfarthing
   claude plugin install pf@pennyfarthing
   ```
   For directory-source installs, `${CLAUDE_PLUGIN_ROOT}` resolves to the source
   directory itself, so edits to plugin source are live in the next session — no
   reinstall ceremony.

   Verify the commands are available — in a Claude Code session, `/pf:` should
   autocomplete (`/pf:work`, `/pf:sprint`, …). Note the **`pf:` namespace** — the
   old `pf-` prefix (`/pf-work`) is gone.

---

## Per-repo cutover

Run these in each repo you're migrating. Examples assume the repo root is the cwd.

### 1. Stop any running Frame processes

```sh
pf frame stop 2>/dev/null
pkill -f "pf frame" 2>/dev/null
pkill -f "pf.frame.app" 2>/dev/null
```

### 2. ⚠️ Fix `.claude/settings.local.json`: delete the hooks, repoint the statusLine

The legacy install wrote six lifecycle-hook entries **and** a `statusLine` entry into
`.claude/settings.local.json`, all pointing at `.pennyfarthing/bin/pf …`. These two get
different treatment:

- **`hooks` → DELETE.** The plugin now provides these via its own `hooks/hooks.json`.
  If you leave them while the plugin is enabled, every hook fires twice — including two
  Frame server launches per session (**double-dispatch**).
- **`statusLine` → REPOINT, don't delete.** Plugins *cannot* supply a status bar
  (confirmed: `statusLine` is a user/project-settings-only feature, not a plugin
  capability). So keep your `statusLine`, just change its command off the dead
  `.pennyfarthing/bin/pf` path to the repointed shim (`pf`, see Step 5). Delete it and
  your status bar disappears with nothing to replace it.

If you have no hand-added non-pf hooks, this jq does both (review before moving into place):

```sh
jq 'del(.hooks)
    | (if .statusLine then .statusLine.command = "pf hooks statusline" else . end)' \
  .claude/settings.local.json > .claude/settings.local.json.new \
  && mv .claude/settings.local.json.new .claude/settings.local.json
```

If you *did* add your own hooks, delete only the pf hook entries (and still repoint statusLine):

```sh
jq 'if .hooks then .hooks |= with_entries(.value |= map(select(
      (.hooks // []) | all(.command | tostring | contains(".pennyfarthing") | not)
    )) ) else . end
    | (.hooks |= with_entries(select((.value | length) > 0)))
    | (if .statusLine then .statusLine.command = "pf hooks statusline" else . end)' \
  .claude/settings.local.json > .claude/settings.local.json.new \
  && mv .claude/settings.local.json.new .claude/settings.local.json
```

Then sanity-check no **executable** `.pennyfarthing` paths remain (hook/statusLine commands):

```sh
grep -n "\.pennyfarthing" .claude/settings.local.json
```
The only remaining hits should be cosmetic `spinnerTipsOverride` strings (flavor text
that happens to mention `.pennyfarthing/` paths — harmless). There must be **no**
`"command": ".../.pennyfarthing/..."` lines and no `hooks` block. Optionally delete the
stale tips too with `jq 'del(.spinnerTipsOverride)'`.

> The `pf hooks statusline` command relies on the `pf` shim (Step 5) being on your PATH.
> If you don't install the shim, use the absolute form instead:
> `uv run --project ~/.claude/plugins/cache/pennyfarthing/pf/current/runtime --quiet pf hooks statusline`.

### 3. (Optional) Preserve runtime state

Skip this if you don't care about in-flight sessions or accumulated sidecars.
The plugin's runtime-state root is `${CLAUDE_PLUGIN_DATA}` (typically
`~/.claude/plugins/data/pennyfarthing-pf/`), with `~/.claude/data/pf/` as the
fallback when running outside a plugin hook. The runtime keys most state on a
**project hash** = `sha256(git-toplevel-abspath)[:12]`.

- **Sidecars** (agent learnings): move `.pennyfarthing/sidecars/*` into the data dir's
  `sidecars/<hash>/` bucket. (Sidecars are per-working-copy now — they are not shared
  across worktrees of the same origin.)
- **Local config**: move `.pennyfarthing/config.local.yaml` →
  `…/projects/<hash>/config.local.yaml`.
- **Active (non-archived) sessions**: move `.session/<story>-session.md` →
  `…/projects/<hash>/.session/`.
- **Leave** `sprint/`, `docs/adr/`, and `.session/archived/` exactly where they are —
  they belong in the repo.

If you're between stories, the simplest path is to skip this and let state regenerate.

### 4. Delete the legacy `.pennyfarthing/` tree

```sh
rm -rf .pennyfarthing/
```

This removes the symlink façade into the old dist, the local `bin/pf` shim, and the
runtime cache files. The `.gitignore` entries the legacy install added are harmless to
leave; remove them if you want a clean diff.

### 5. Repoint (or remove) the interactive `pf` shim

If you use a terminal `pf` outside Claude Code (`~/.local/bin/pf`), repoint it from the
migration worktree to the installed plugin's runtime:

```sh
# ~/.local/bin/pf
#!/usr/bin/env bash
PLUGIN_ROOT="${HOME}/.claude/plugins/cache/pennyfarthing/pf/current"
exec uv run --project "$PLUGIN_ROOT/runtime" --quiet pf "$@"
```

The shim is optional — every Pennyfarthing-internal invocation uses the verbose
`uv run` form already. It's only a convenience for typing `pf sprint status` in a shell.

---

## Verify the cutover

Start a fresh Claude Code session in the migrated repo and check:

1. **Commands resolve:** `/pf:work` (and friends) are available.
2. **No double hooks:** session startup doesn't run twice; there is exactly **one**
   Frame server:
   ```sh
   pgrep -fa "pf.frame.app" | wc -l   # expect 1 (or 0 if Frame is disabled)
   ```
3. **Sprint history intact:** `pf sprint status` reads your existing `sprint/` files.
4. **No leftover `.pennyfarthing/`:** `ls .pennyfarthing 2>/dev/null` → nothing.
5. **A `sprint/` YAML edit still gets validated** (PostToolUse hook fires once, via the
   plugin).

---

## Turning it off / uninstalling

- **Disable:** `claude plugin disable pf` — commands and hooks go dormant; your repo's
  `sprint/`, `docs/adr/`, and runtime state are untouched and return on re-enable.
- **Uninstall:** `claude plugin uninstall pf` — commands and hooks gone; project
  artifacts preserved. Runtime state in `~/.claude/plugins/data/pennyfarthing-pf/`
  (or `~/.claude/data/pf/`) persists; `rm -rf` it manually for a clean slate.

There is no `.claude/settings.json` surgery to undo — the plugin never modified it
(that's the whole point of the migration).

---

## Caveats

- **`gh` and `GITHUB_TOKEN`:** RESOLVED (2026-05-22). The stale `GITHUB_TOKEN` that used
  to shadow the `gh` keyring (causing 401s) has been removed permanently — `gh` now works
  on the keyring with no workaround, so the old `env -u GITHUB_TOKEN` prefix is no longer
  needed. Plugin-level `env` declaration is not required for this. (Closed spike Q4 — the
  practical `gh` concern is moot.)
- **`statusLine`:** plugins **cannot** supply a status bar — it's a user/project-settings
  feature only, not a plugin capability. That's why Step 2 *repoints* your existing
  `statusLine` (to `pf hooks statusline`) instead of deleting it. The rendering command
  (`pf hooks statusline`) still ships in the plugin runtime; only the wiring is yours to
  keep. Cosmetic — omit it and you just lose the status bar.
- **Worktrees of the same repo** no longer share sidecars — each working copy keeps its
  own agent learnings (keyed on the working-copy path).

---

## Reference

- Design spec: `docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md`
  (§3 storage tiers, §6 hooks, §8 migration).
- Hooks model: `pennyfarthing/guides/hooks.md` (the plugin's dispatcher model).
- Spike findings (install/hot-reload/hook-ordering/nohup): `docs/superpowers/spikes/2026-05-21-plugin-spike-results.md`.
