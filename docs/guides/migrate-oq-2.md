# Cutover checklist: `oq-2` → `pf` plugin

Filled-in runbook for this specific repo. See
[`migrating-existing-repos-to-the-pf-plugin.md`](migrating-existing-repos-to-the-pf-plugin.md)
for the rationale behind each step.

| | |
|---|---|
| Repo path | `/Users/slabgorb/Projects/oq-2` |
| Origin | `git@github.com:slabgorb/sidequest.git` (shared with `oq-1` — independent working copies) |
| Project hash | `acc31d04eaba` |
| Theme | `mash` |
| **State to preserve** | sidecars, `config.local.yaml` (no active sessions) |
| In-repo (leave alone) | `sprint/`, `docs/adr/` |

> `oq-2` is a separate working copy of the same origin as `oq-1`. Under the plugin model
> sidecars are keyed per working-copy (hash `acc31d04eaba`), so `oq-2` keeps its own
> learnings — they are not shared with `oq-1`. No active sessions here, so Step 3 is optional.

Prereq: `uv` installed and `claude plugin install pf@pennyfarthing` done once (see general guide).

### 1. Stop Frame
```sh
cd /Users/slabgorb/Projects/oq-2
pf frame stop 2>/dev/null; pkill -f "pf frame" 2>/dev/null; pkill -f "pf.frame.app" 2>/dev/null
```

### 2. Fix settings.local.json: delete hooks (double-dispatch), repoint statusLine
```sh
cd /Users/slabgorb/Projects/oq-2
jq 'del(.hooks)
    | (if .statusLine then .statusLine.command = "pf hooks statusline" else . end)' \
  .claude/settings.local.json > .claude/settings.local.json.new \
  && mv .claude/settings.local.json.new .claude/settings.local.json
grep -n "\.pennyfarthing" .claude/settings.local.json   # only cosmetic spinnerTips text, no command/hook lines
```
Deletes the pf hooks (the plugin provides them); **repoints** statusLine instead of
deleting it (plugins can't supply a status bar — `pf hooks statusline` uses the Step-5
shim). Keeps `permissions`, `spinnerVerbs`, `spinnerTipsOverride`.

### 3. Preserve runtime state (optional — no active sessions)
```sh
DATA="$HOME/.claude/plugins/data/pennyfarthing-pf"   # confirm after install: ls ~/.claude/plugins/data/
H=acc31d04eaba
mkdir -p "$DATA/projects/$H" "$DATA/sidecars/$H"
cp -a /Users/slabgorb/Projects/oq-2/.pennyfarthing/config.local.yaml "$DATA/projects/$H/config.local.yaml" 2>/dev/null
cp -a /Users/slabgorb/Projects/oq-2/.pennyfarthing/sidecars/. "$DATA/sidecars/$H/" 2>/dev/null
```
Leave `sprint/` and `docs/adr/` in the repo. (Skip this whole step if you don't care about
the `mash` theme setting or accumulated sidecars — they regenerate.)

### 4. Delete the legacy tree
```sh
rm -rf /Users/slabgorb/Projects/oq-2/.pennyfarthing/
```

### 5. Verify (fresh Claude session in the repo)
- `/pf:work` resolves; `pf sprint status` reads existing `sprint/`.
- Exactly one Frame: `pgrep -fa "pf.frame.app" | wc -l` → `1` (or `0` if disabled).
- `ls /Users/slabgorb/Projects/oq-2/.pennyfarthing 2>/dev/null` → nothing.
