# Installer Issues — Fresh Setup Notes (pf-2)

## Steps taken to get pennyfarthing working in a fresh orchestrator clone

### 1. Clone pennyfarthing repo manually
- Had to `gh repo clone 1898andco/pennyfarthing` before anything else
- The orchestrator repo doesn't document this step clearly
- **Fix:** `pennyfarthing init` or docs should mention cloning the framework repo if the project expects it inlined

### 2. `npm install` — postinstall fails (non-blocking)
- `pennyfarthing update` runs in postinstall but fails with "not initialized" error
- The `|| true` swallows it, so packages install fine, but user sees an error
- **Fix:** postinstall script should check if initialized first and skip gracefully (no error output)

### 3. `pennyfarthing init` crashes on `settings.local.json` symlink
- **Error:** `EEXIST: file already exists, symlink '../.pennyfarthing/settings.local.json' -> '.claude/settings.local.json'`
- The file `.claude/settings.local.json` already existed as a regular file (copied from pf-1)
- Init tries to create a symlink at that path but doesn't handle the case where a regular file already exists
- **Workaround:** Had to manually move the file to `.pennyfarthing/settings.local.json` and create the symlink myself
- **Fix:** Init should detect if `.claude/settings.local.json` exists as a regular file, back it up or move it to `.pennyfarthing/settings.local.json`, then create the symlink. Or at minimum, catch EEXIST and provide a helpful error message instead of a raw Node stack trace

### 4. Hooks not executable after init
- Doctor flagged 7 hooks as "Not executable"
- `doctor --fix` resolved them all
- **Fix:** `init` should set executable permissions on hooks when it installs them, not require a separate `doctor --fix` step

### 5. No theme configured (warning)
- Minor — just a preference, not a blocker
- Could prompt during init or default to a theme

## Summary of installer improvements needed

| Issue | Severity | Fix |
|-------|----------|-----|
| postinstall error output on fresh install | Low | Guard with init check |
| EEXIST crash on settings.local.json | **High** | Handle existing regular file gracefully |
| Hooks not executable after init | Medium | Set +x during init, not just doctor --fix |
| No guidance on cloning framework repo | Low | Add to init prompts or docs |

---

## Post-init issues found by next session (2026-02-07)

After `pennyfarthing init` + `doctor --fix` passed, a new Claude session still couldn't start work. Three additional issues:

### 6. `config.local.yaml` missing
- `pennyfarthing init` creates `persona-config.yaml` but NOT `config.local.yaml`
- `config.local.yaml` is the file that controls theme, workflow settings (permission_mode, bell_mode, relay_mode), and display prefs
- Without it, the framework has no runtime config — theme resolution fails silently
- **Workaround:** Manually created `.pennyfarthing/config.local.yaml` with theme + workflow defaults
- **Fix:** `init` should generate a default `config.local.yaml` alongside `persona-config.yaml`

### 7. `setup-env.sh` hook referenced but missing
- `settings.local.json` SessionStart hooks reference `.claude/project/hooks/setup-env.sh`
- Neither the directory nor the file existed after init
- The hook runs on every session start — if the shell script is missing, the hook fails silently
- **Workaround:** Created `.claude/project/hooks/setup-env.sh` with minimal env export
- **Fix:** `init` should create this file, or the settings template shouldn't reference it

### 8. Additional hooks still not executable after `doctor --fix`
- `session-stop.sh`, `schema-validation.sh`, `otel-auto-config.sh`, `welcome-hook.sh`, `pre-commit.sh`, `post-merge.sh`, `pre-push.sh` were all `644`
- These are symlinked from `node_modules/` which doesn't preserve `+x` on install
- Only the hooks that `doctor --fix` specifically targets got fixed; the rest stayed `644`
- **Workaround:** `chmod +x` on all `.sh` files in the hooks directory
- **Fix:** `init` (or `update`) should `chmod +x` ALL `.sh` files in `.pennyfarthing/scripts/hooks/`, not just the ones doctor knows about

## Updated summary

| Issue | Severity | Status |
|-------|----------|--------|
| postinstall error output on fresh install | Low | Open |
| EEXIST crash on settings.local.json | **High** | Open |
| Hooks not executable after init | Medium | Open (broader than originally thought) |
| No guidance on cloning framework repo | Low | Open |
| `config.local.yaml` not created by init | **High** | Open — blocks theme + workflow config |
| `setup-env.sh` hook missing | Medium | Open — dead reference in settings template |
| Incomplete chmod coverage in doctor --fix | Medium | Open — only fixes known hooks, misses others |
