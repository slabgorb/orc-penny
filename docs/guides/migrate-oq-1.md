# Cutover checklist: `oq-1` → `pf` plugin

Filled-in runbook for this specific repo. See
[`migrating-existing-repos-to-the-pf-plugin.md`](migrating-existing-repos-to-the-pf-plugin.md)
for the rationale behind each step.

| | |
|---|---|
| Repo path | `/Users/slabgorb/Projects/oq-1` |
| Origin | `git@github.com:slabgorb/sidequest.git` (shared with `oq-2` — independent working copies) |
| Project hash | `1f6855cc0778` |
| Theme | `shakespeare` |
| **State to preserve** | sidecars, `config.local.yaml`, **9 active `.session/*.md` files** |
| In-repo (leave alone) | `sprint/`, `docs/adr/` |

> ⚠️ This repo has **9 active (non-archived) sessions** — the only one of the three
> with in-flight work. If any of those stories are mid-flight, do Step 3 (don't skip it),
> or finish/archive them first.

Prereq: `uv` installed and `claude plugin install pf@pennyfarthing` done once (see general guide).

### 1. Stop Frame
```sh
cd /Users/slabgorb/Projects/oq-1
pf frame stop 2>/dev/null; pkill -f "pf frame" 2>/dev/null; pkill -f "pf.frame.app" 2>/dev/null
```

### 2. Fix settings.local.json: delete hooks (double-dispatch), repoint statusLine
```sh
cd /Users/slabgorb/Projects/oq-1
jq 'del(.hooks)
    | (if .statusLine then .statusLine.command = "pf hooks statusline" else . end)' \
  .claude/settings.local.json > .claude/settings.local.json.new \
  && mv .claude/settings.local.json.new .claude/settings.local.json
grep -n "\.pennyfarthing" .claude/settings.local.json   # only cosmetic spinnerTips text, no command/hook lines
```
Deletes the pf hooks (the plugin provides them); **repoints** statusLine instead of
deleting it (plugins can't supply a status bar — `pf hooks statusline` uses the Step-5
shim). Keeps `permissions`, `spinnerVerbs`, `spinnerTipsOverride`. If you ever hand-added
non-pf hooks, use the selective jq from the general guide instead.

### 3. Preserve runtime state (do this — active sessions present)
```sh
DATA="$HOME/.claude/plugins/data/pennyfarthing-pf"   # confirm after install: ls ~/.claude/plugins/data/
H=1f6855cc0778
mkdir -p "$DATA/projects/$H/.session" "$DATA/sidecars/$H"

# Active sessions (9 files)
cp -a /Users/slabgorb/Projects/oq-1/.session/*.md "$DATA/projects/$H/.session/" 2>/dev/null

# Local config
cp -a /Users/slabgorb/Projects/oq-1/.pennyfarthing/config.local.yaml "$DATA/projects/$H/config.local.yaml" 2>/dev/null

# Sidecars
cp -a /Users/slabgorb/Projects/oq-1/.pennyfarthing/sidecars/. "$DATA/sidecars/$H/" 2>/dev/null
```
Leave `sprint/` and `docs/adr/` in the repo.

### 4. Delete the legacy tree
```sh
rm -rf /Users/slabgorb/Projects/oq-1/.pennyfarthing/
```

### 5. Verify (fresh Claude session in the repo)
- `/pf:work` resolves; `pf sprint status` reads existing `sprint/`.
- Exactly one Frame: `pgrep -fa "pf.frame.app" | wc -l` → `1` (or `0` if disabled).
- `ls /Users/slabgorb/Projects/oq-1/.pennyfarthing 2>/dev/null` → nothing.
- Your 9 sessions appear (check `pf sprint status` / session resume).
