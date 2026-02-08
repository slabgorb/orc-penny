# First-Run Experience Bugs

Found during testing pennyfarthing installation and CLI on 2026-01-02.

## Confirmed Issues

### Bug 1: CLI fails without npm install ✅ FIXED (PR #58)

**Symptom:**
```
Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'commander'
```

**Context:** Running `./bin/pennyfarthing.js --help` before `npm install`

**Fix:** Added friendly error message in `bin/pennyfarthing.js`

---

### Bug 2: Stale minimalist.yaml reference in manifest ✅ FIXED (PR #58)

**Symptom:**
```
pennyfarthing doctor
✗ completeness - 1 file(s) missing
```

**Context:** Manifest references `.claude/pennyfarthing/personas/themes/minimalist.yaml` but this was renamed to `control.yaml` in commit `20d6687` by Keith.

**Fix:** Removed stale entry from manifest.json fileHashes

---

### Bug 3: Manifest version out of sync ✅ FIXED (PR #58)

**Symptom:**
```
i Version: 4.0.0 (installed) / 4.3.0 (package)
```

**Context:** `.claude/manifest.json` has version 4.0.0, `package.json` has 4.3.0

**Fix:** Updated VERSION and manifest.json to 4.3.0

---

### Bug 4: `pennyfarthing init` doesn't support dogfooding mode

**Symptom:**
```
✗ node_modules/pennyfarthing not found
✗
✗ Pennyfarthing requires npm installation:
✗   npm install pennyfarthing
✗   npx pennyfarthing init
✗
✗ For dogfooding (pennyfarthing repo itself), ensure .claude/scripts symlink exists.
```

**Context:** After `pennyfarthing uninstall`, running `pennyfarthing init` fails because it expects `node_modules/pennyfarthing` to exist. The error message mentions dogfooding but doesn't explain how to do it.

**Root cause:** `init` command has no `--dogfood` flag or auto-detection for running from the pennyfarthing repo itself.

**Fix needed:**
- Add `--dogfood` flag to init, OR
- Auto-detect when running from pennyfarthing repo (check for `pennyfarthing-dist/` in cwd)
- Create symlinks: `.claude/pennyfarthing -> ../pennyfarthing-dist`

---

### Bug 5: `pennyfarthing uninstall` breaks dogfooding without warning

**Symptom:** After uninstall, the `.claude/pennyfarthing` symlink is removed along with all dependent symlinks (agents, commands, etc.), leaving broken symlinks.

**Context:** Uninstall removes the core symlink but leaves dependent symlinks pointing to the now-missing `.claude/pennyfarthing/` directory.

**Fix needed:**
- Warn when running uninstall in dogfooding mode
- OR provide clear instructions for re-establishing dogfood symlinks
- OR add `pennyfarthing init --dogfood` to recreate them

---

### Bug 6: Error message shows then continues anyway

**Symptom:** Init shows error "node_modules/pennyfarthing not found" but then continues with "Installing Pennyfarthing... Creating directories..."

**Context:** The error handling doesn't exit; it prints an error then proceeds to partial initialization.

**Fix needed:**
- Either exit on error, or
- If continuing is intentional, don't show it as an error

---

## Not Bugs (Investigated and Dismissed)

### ~~Missing dogfooding docs~~
**Status:** INVALID - `docs/DOGFOODING.md` exists and is comprehensive

---

## Manual Recovery After Uninstall (Dogfooding)

If you run `pennyfarthing uninstall` in the pennyfarthing repo, you can manually restore with:

```bash
# 1. Recreate core symlink
cd .claude && ln -sf ../pennyfarthing-dist pennyfarthing

# 2. Restore manifest from git
git checkout HEAD -- .claude/manifest.json

# 3. Verify
./bin/pennyfarthing.js doctor
```

---

## Notes

- `pennyfarthing doctor --fix` successfully fixed missing SessionStart hooks
- 46 files showing as "modified locally" is expected in development context
- All 91 themes validate correctly with yq
