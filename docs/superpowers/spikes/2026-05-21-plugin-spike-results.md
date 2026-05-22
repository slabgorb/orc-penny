# Pennyfarthing-as-Plugin Spike Results

**Date:** 2026-05-21
**Spec under test:** `docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md`
**Plan executed:** `docs/superpowers/plans/2026-05-21-plugin-spike.md`
**Claude Code version:** 2.1.146
**uv version:** 0.11.7 (Homebrew, aarch64-apple-darwin)
**Plugin install path (cache, metadata only):** `/Users/slabgorb/.claude/plugins/cache/pf-spike/pf-spike/0.0.1`
**Plugin source path (where `${CLAUDE_PLUGIN_ROOT}` actually resolves):** `/Users/slabgorb/Projects/pf-spike/`

---

## Headline Finding

For directory-source marketplace installs on macOS, **`${CLAUDE_PLUGIN_ROOT}` points to the user's source tree, not the cache copy**. This makes hot-reload free and changes the mental model the spec was written from: there is no "install copy" to keep in sync with the source.

This single fact resolves Q1, Q2, and the D1 dogfooding question in §8.2 simultaneously.

---

## Q1: `${CLAUDE_PLUGIN_ROOT}` semantics

- **Value observed:** `/Users/slabgorb/Projects/pf-spike/` (the source directory, with trailing slash)
- **Stable across hook firings:** yes — identical value across three observed firings (2× `SessionStart`, 1× `PreToolUse:Bash`)
- **cwd inside hook:** the target repo (`/tmp/pf-spike-target`), not the plugin dir
- **uv run works from inside hook:** yes — `uv run --project ${CLAUDE_PLUGIN_ROOT}/runtime pf probe …` executed cleanly from inside `probe.sh`
- **Runtime process sees `CLAUDE_PLUGIN_ROOT` in env:** yes — visible to the Python process via `os.environ`

**Other env vars exposed to plugin hooks** (in addition to the documented ones):

| Var | Example value | Notes |
|---|---|---|
| `CLAUDE_PLUGIN_ROOT` | `/Users/slabgorb/Projects/pf-spike/` | source dir, not cache |
| `CLAUDE_PLUGIN_DATA` | `~/.claude/plugins/data/pf-spike-pf-spike` | per-plugin writable data dir — provided by Claude Code |
| `CLAUDE_PROJECT_DIR` | `/private/tmp/pf-spike-target` | symlink-resolved (canonical) project root |
| `CLAUDE_CODE_SESSION_ID` | `<uuid>` | stable across hooks within a session |
| `CLAUDE_CODE_ENTRYPOINT` | `sdk-cli` | `claude -p` mode also fires hooks |
| `CLAUDE_CODE_EXECPATH` | path to `claude` binary | |
| `CLAUDE_ENV_FILE` | `…/sessionstart-hook-N.sh` | only present on `SessionStart`; hook-slot number is observable |

PreToolUse:Bash hooks receive the **tool input JSON on stdin**, including `command`, `description`, `tool_use_id`. This is richer than the spec assumed.

**Spec impact:**

- **§5.1 (Runtime Invocation)** — assumption validated. The `uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime"` pattern works exactly as written.
- **§3.2 (Three Storage Tiers)** — Claude Code already provides `CLAUDE_PLUGIN_DATA` (`~/.claude/plugins/data/<marketplace>-<plugin>/`). The spec's "runtime state under `~/.claude/data/pf/…`" tier should pivot to `${CLAUDE_PLUGIN_DATA}` as the base path. This is cleaner: per-plugin isolation provided by the host, no naming collision with other plugins. **Spec amendment required.**
- **§7.2 (paths chokepoint)** — `pf.paths` should read `CLAUDE_PLUGIN_DATA` from env and use it as the runtime-state root, falling back to `~/.claude/data/pf/` if absent (e.g., when running outside a plugin hook). The fallback covers Keith's `~/.local/bin/pf` shim from §5.2.

---

## Q2: `--from-source` hot-reload

- **Install command used:** `claude plugin marketplace add ~/Projects/pf-spike && claude plugin install pf-spike@pf-spike`. The `--from-source` flag from the spec **does not exist**; the route is marketplace-add-from-path then install.
- **Edit picked up without reinstall:** **yes** — the `EDIT-CHECK-Q2` marker appeared in the log on the very first fresh session after the source edit, with zero reinstall ceremony.
- **Update command that works (if needed):** none required.
- **Uninstall+reinstall time:** ~0.23s uninstall + ~0.72s install = **~0.95s total**. Registry bookkeeping only; no dep resolution or file copy.
- **Install path stable across reinstalls:** yes — `CLAUDE_PLUGIN_ROOT` resolves to the same source path before and after.

**Spec impact on §8.2 (D1 — Orchestrator Dogfooding):**

- The spec's `claude plugin install --from-source ~/Projects/orc-penny/pennyfarthing` invocation is wrong syntax — replace with:
  ```sh
  claude plugin marketplace add ~/Projects/orc-penny/pennyfarthing
  claude plugin install pf@pennyfarthing      # or whatever marketplace/plugin name the manifest declares
  ```
- D1's "edits live in the next session" is **confirmed**. No reinstall ceremony, no force-update.
- The cache at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` exists but is metadata-only for directory-source installs; the Python venv is created at `${source}/runtime/.venv`, not at `${cache}/…/.venv`. This means dev-time `uv sync` runs against the source tree.

**Spec amendment required.**

---

## Q3: Hook ordering vs user `settings.json`

- **Both fired:** yes
- **Order:** user-first, deterministic across 3 runs (gap ~14ms)
- **`CLAUDE_PLUGIN_ROOT` visible to user hook:** no — `<unset>` in the user-settings hook environment
- **Hook-slot evidence:** the `CLAUDE_ENV_FILE` path's `sessionstart-hook-N.sh` suffix moves from slot 1 (plugin-only) to slot 2 (user+plugin), confirming the assignment order: user settings.json → plugin manifests.

**Settings.json schema observation:** the plan's snippet used the legacy form `{"command": "..."}` for hook entries, but the current Claude Code schema requires the nested form `{"hooks": [{"type": "command", "command": "..."}]}` — same shape used by plugin `hooks.json`. (This was discovered in Task 2 and re-confirmed in Task 5.)

**Spec impact on §6.1 (Settings.json Change):**

- The spec's example `settings.json` snippet (`{"hooks": {"SessionStart": [{"command": "..."}]}}`) is **out of date** — current Claude Code requires the nested form `{"hooks": [{"type": "command", "command": "..."}]}`. The plugin `hooks.json` example below it also needs the same treatment. **Spec amendment required.**
- Plugin hooks always run AFTER user-settings hooks. The spec's "Plugin enable → hooks active" framing is correct, but it should add: **user hooks remain authoritative for any setup that must precede plugin hooks** (none currently in scope).
- `CLAUDE_PLUGIN_ROOT` is not propagated into user hooks. A user hook cannot reference plugin paths via this variable.

---

## Q4: Long-running processes from hooks

- **Plain `setsid bash -c '…' &` survives:** **no** — Claude Code's process-group kill on hook exit catches the setsid'd child before it fully escapes on macOS
- **`nohup … & disown` survives:** **yes** — re-parented to PID 1 immediately after session exit, ran to completion, survival message appeared in log
- **`launchctl submit -l … -- bash -c '…'` survives:** **yes**, but with a caveat — the default behaviour re-launches the job after exit (`OnDemand=false` semantics); for a one-shot use, a `.plist` with `KeepAlive=false` (or `launchctl remove` cleanup) is required
- **Survival message appeared in log:** yes (both nohup and launchctl patterns)
- **Working alternative:** `nohup bash -c '...' >/dev/null 2>&1 & disown` — simplest pattern, no restart-loop risk

**Spec impact on §5.1 / §9 (`pf frame start` from SessionStart):**

- **Frame CAN be auto-started by the plugin SessionStart hook** — the spec's assumption holds, but the spawn pattern must be `nohup … & disown`, not plain backgrounding or `setsid`.
- Recommended pattern for the SessionStart hook:
  ```sh
  nohup uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime" \
    pf frame start --background >/dev/null 2>&1 & disown
  ```
- The spec's §9 entry "Frame server (long-running) outliving the session" should be updated from "flagged in §10 as a spike question" to **"validated: `nohup … & disown` pattern required."** **Spec amendment required.**

---

## §10.4 — Plugin permissions / env merging (NOT TESTED)

The spec's §10 lists **four** open questions; the plan only covered Q1 (added) and §10.1–3. §10.4 — "Plugin-declared permissions vs user settings — verify how plugin-declared `permissions` and `env` appear and merge so we don't lose current behavior (e.g., the `gh` token unset shim noted in auto-memory)" — was **not exercised by this spike**. This remains an open question for Gate 2 (full plugin works in fresh project) or a follow-up micro-spike.

**UPDATE (2026-05-22) — the `gh` driver for this question is gone.** The stale `GITHUB_TOKEN` that shadowed the keyring has been removed permanently; `gh` now works on the keyring with no workaround. The `gh 401 — GITHUB_TOKEN shadows keyring` concern that motivated declaring `env: { GITHUB_TOKEN: "" }` is therefore **moot** — no shadowing token to neutralize, and no plugin-level `env` declaration is needed for `gh`. The defensive `env -u GITHUB_TOKEN gh …` prefix is **no longer required** anywhere. The general "how do plugin-declared `permissions`/`env` merge with user settings" question remains theoretically open, but it no longer has a concrete blocker — defer to a follow-up only if a real need arises.

~~**Recommended follow-up:** before Plan 4 (hooks rewrite), add a micro-spike that declares `env` and `permissions` in a plugin manifest and observes merging behavior with `~/.claude/settings.json`.~~ (Dropped — the `gh`/`env` micro-spike is unnecessary now that the token shadow is gone.)

---

## Schema-shape findings (not from any single Q, accumulated across tasks)

These are findings that affect the manifests Plan 2 / Plan 3 will write. The spec's example JSON snippets need updates to match current schemas:

### `marketplace.json` schema

| Field | Plan/spec assumed | Actually required |
|---|---|---|
| `$schema` | absent | required for validation to pass |
| Top-level `description` | absent | required |
| `plugins[].source` | `"."` | must be `"./"` (trailing slash) |
| `plugins[].author` | absent (top-level `owner` only) | required inside each plugin entry |

Minimal valid `marketplace.json` for a single-plugin directory source:

```json
{
  "$schema": "https://claude.ai/schemas/marketplace.json",
  "name": "pf",
  "description": "Pennyfarthing agent framework",
  "owner": { "name": "Keith Avery", "email": "slabgorb@gmail.com" },
  "plugins": [
    {
      "name": "pf",
      "source": "./",
      "description": "Pennyfarthing plugin",
      "version": "1.0.0",
      "author": { "name": "Keith Avery", "email": "slabgorb@gmail.com" }
    }
  ]
}
```

(Replace `$schema` URL with the actual one when discovered — `claude plugin validate` rejects the manifest without it but does not document the canonical URL inline. Plan 2 should resolve this with `claude plugin validate` against an empty stub and capture the URL.)

### `hooks/hooks.json` schema

The simpler form the spec uses (`{"command": "..."}` at the leaf) is rejected by the current Claude Code validator. The required form is:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/schema-validation.sh" }
        ]
      }
    ]
  }
}
```

The `${CLAUDE_PLUGIN_ROOT}` literal **is expanded** by Claude Code before invoking the command (validated in Q1). No additional shell layer is needed for expansion.

### `plugin.json`

The spec's `plugin.json` example matches the current schema. No changes needed.

---

## Plan-of-Plans impact

| Plan | Adjustment required |
|---|---|
| **Plan 2** (scaffold + `pf.paths` chokepoint refactor) | Use canonical nested `hooks.json` form. Add `$schema` URL to `marketplace.json`. `pf.paths` should base runtime-state at `${CLAUDE_PLUGIN_DATA}` with `~/.claude/data/pf/` fallback for shim invocations. Plugin install command in Plan 2's local-test instructions must be `marketplace add` + `install`, not `--from-source`. |
| **Plan 3** (content migration + `pf-` prefix drop) | No structural change. Verify any embedded path examples reflect the source-directory-as-CLAUDE_PLUGIN_ROOT model when used as documentation. |
| **Plan 4** (hooks rewrite) | Hook spawn patterns for any long-running process must use `nohup … & disown`. Add a micro-spike for §10.4 (env / permissions merging) **before** Plan 4 finalizes. The `sprint-yaml-validation` Python rewrite is unaffected. |
| **Plan 5** (`pf migrate-from-legacy` + cutover) | The cutover script in §8.1 needs the same `marketplace add` + `install` correction. Move target for runtime state should be `${CLAUDE_PLUGIN_DATA}` if present, with fallback to `~/.claude/data/pf/`. |

---

## Spec amendments required

Apply as a follow-up commit to `docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md` before Plan 2 is written:

1. **§3.2 (Three Storage Tiers)** — replace `~/.claude/data/pf/…` references with `${CLAUDE_PLUGIN_DATA}` as the primary path; document the `~/.claude/data/pf/` fallback for non-plugin contexts (the §5.2 shim).
2. **§5.1 (Runtime Invocation)** — no change to the `uv run --project "${CLAUDE_PLUGIN_ROOT}/runtime"` pattern; it works as written. Add a note that `CLAUDE_PLUGIN_ROOT` resolves to the source directory for directory-source installs (so dev-time edits are live).
3. **§6.1 (Settings.json Change)** — update both code blocks to use the nested `{"hooks": [{"type": "command", "command": "..."}]}` form for both user `settings.json` and plugin `hooks.json`. Add a note that plugin hooks fire AFTER user-settings hooks (deterministic, ~14ms gap).
4. **§8.1 (Cutover script)** — replace `claude plugin marketplace add slabgorb/pennyfarthing` + `claude plugin install pf@pennyfarthing` to reflect the actual command sequence (it already does — only confirm), and note that the `--from-source` flag does not exist.
5. **§8.2 (Orchestrator Dogfooding D1)** — replace `claude plugin install --from-source ~/Projects/orc-penny/pennyfarthing` with:
   ```sh
   claude plugin marketplace add ~/Projects/orc-penny/pennyfarthing
   claude plugin install pf@pennyfarthing
   ```
   Add: "Hot-reload validated by Gate 1 spike — edits to plugin source are live in the next session with no reinstall."
6. **§9 (Edge case row: Frame server outliving the session)** — change "flagged in §10 as a spike question" to "validated: spawn via `nohup … & disown` in SessionStart hook."
7. **§10 (Open questions)** — mark Q1–3 as resolved with a pointer to this results doc. Q4 (permissions / env merging): the `gh`/`GITHUB_TOKEN` driver is **closed (2026-05-22)** — the shadowing token was removed permanently, so `gh` works on the keyring with no `env -u GITHUB_TOKEN` prefix and no plugin-level `env` declaration. The general permissions/env-merging question has no remaining concrete blocker; defer indefinitely.
8. **§11 (Gate 1)** — mark **passed** with a pointer to this results doc.

---

## Appendix A — Probe artifacts

- Spike repo: `~/Projects/pf-spike/` (archived/deleted at Task 10 of the executing plan)
- Probe log: `/tmp/pf-spike.log` (deleted at Task 10)
- Target repo: `/tmp/pf-spike-target/` (deleted at Task 10)
- Plugin install path (cache, metadata only): `/Users/slabgorb/.claude/plugins/cache/pf-spike/pf-spike/0.0.1`
- Two commits landed in the spike repo before deletion:
  - `cbfeb10` — scaffold
  - `575c723` — Q2 hot-reload edit (`EDIT-CHECK-Q2` marker)
