# Cutover checklist: `words` → `pf` plugin

Filled-in runbook for this specific repo. See
[`migrating-existing-repos-to-the-pf-plugin.md`](migrating-existing-repos-to-the-pf-plugin.md)
for the rationale behind each step.

| | |
|---|---|
| Repo path | `/Users/slabgorb/Projects/words` |
| Origin | `git@github.com:slabgorb/gamebox.git` |
| Project hash | `bc2e1773b8d9` |
| Theme | `the-expanse` |
| **State to preserve** | `config.local.yaml` only — **no sidecars, no active sessions** |
| In-repo (leave alone) | `sprint/` (no `docs/adr/` here) |

> Simplest of the three: no sidecars dir, no active sessions, no `docs/adr/`. The only
> thing worth keeping is the `the-expanse` theme setting, and even that regenerates.

Prereq: `uv` installed and `claude plugin install pf@pennyfarthing` done once (see general guide).

### 1. Stop Frame
```sh
cd /Users/slabgorb/Projects/words
pf frame stop 2>/dev/null; pkill -f "pf frame" 2>/dev/null; pkill -f "pf.frame.app" 2>/dev/null
```

### 2. Fix settings.local.json: delete hooks (double-dispatch), repoint statusLine
```sh
cd /Users/slabgorb/Projects/words
jq 'del(.hooks)
    | (if .statusLine then .statusLine.command = "pf hooks statusline" else . end)' \
  .claude/settings.local.json > .claude/settings.local.json.new \
  && mv .claude/settings.local.json.new .claude/settings.local.json
grep -n "\.pennyfarthing" .claude/settings.local.json   # only cosmetic spinnerTips text, no command/hook lines
```
Deletes the pf hooks (the plugin provides them); **repoints** statusLine instead of
deleting it (plugins can't supply a status bar — `pf hooks statusline` uses the Step-5
shim). Keeps `permissions`, `spinnerVerbs`, `spinnerTipsOverride`.

### 3. Preserve runtime state (optional — theme only)
```sh
DATA="$HOME/.claude/plugins/data/pennyfarthing-pf"   # confirm after install: ls ~/.claude/plugins/data/
H=bc2e1773b8d9
mkdir -p "$DATA/projects/$H"
cp -a /Users/slabgorb/Projects/words/.pennyfarthing/config.local.yaml "$DATA/projects/$H/config.local.yaml" 2>/dev/null
```
Leave `sprint/` in the repo. (Skip entirely if you'll just re-set the theme with `pf theme set the-expanse`.)

### 4. Delete the legacy tree
```sh
rm -rf /Users/slabgorb/Projects/words/.pennyfarthing/
```

### 5. Verify (fresh Claude session in the repo)
- `/pf:work` resolves; `pf sprint status` reads existing `sprint/`.
- Exactly one Frame: `pgrep -fa "pf.frame.app" | wc -l` → `1` (or `0` if disabled).
- `ls /Users/slabgorb/Projects/words/.pennyfarthing 2>/dev/null` → nothing.
