# Pennyfarthing-as-Plugin — Plan 3: Content Migration + Drop `pf-` Prefix

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all framework *content* (`agents/`, `commands/`, `skills/`, `gates/`, `guides/`, `workflows/`, `personas/`, `templates/`, `output-styles/`, `schemas/`, `scripts/`, plus `data/`, `patterns/`, `protocols/`, registries) out of `pennyfarthing-dist/` up to the plugin root (siblings of `runtime/`), drop the hand-rolled `pf-` prefix on command and skill filenames so Claude Code's native `pf:` namespacing produces `/pf:work` etc., repoint every Python content-path resolver at the new layout, delete `pennyfarthing-dist/` entirely, and green the test suite.

**Architecture:** Content directories become direct children of the plugin root (the repo root that already holds `.claude-plugin/` and `runtime/`). The Python runtime resolves content through one helper, `pf.common.config.get_dist_root()`, which now returns the plugin root via `CLAUDE_PLUGIN_ROOT` (set by Claude Code) with a `__file__`-relative fallback. The dead `pf._dist` symlink package and the legacy pip-packaging surface are removed. Agents are *not* renamed (they were never `pf-` prefixed); only commands (38) and skills (25) lose the prefix.

**Tech Stack:** Python 3.11+, `uv` (project-managed venv), `pytest` (+ `pytest-asyncio` via the `test` extra), Claude Code plugin manifest schema, `git mv` for history preservation.

---

## Scope Notes

- **Working directory:** ALL implementation happens in the migration worktree at `/Users/slabgorb/Projects/orc-penny-pf-migration`, which is pinned to branch `feat/plugin-scaffold-and-paths` (Plan 2's branch). Do **not** work in `/Users/slabgorb/Projects/orc-penny/pennyfarthing/` — its working tree gets switched between branches during normal work and is not on the migration branch.
- **The plan document lives in the orchestrator repo** (`orc-penny/docs/superpowers/plans/`). The orchestrator repo is never modified by execution; only the worktree is.
- **Test command (exact):** `cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime && uv run --extra test pytest src/pf/tests/ -q`. The `--extra test` is **required** (pulls in `pytest-asyncio`). Omitting it produces spurious async errors.
- **Baseline (pre-Plan-3):** `4068 passed, 188 failed, 35 skipped, 236 errors`. Every failure/error is the package↔content split: tests resolve dist content relative to the package (`runtime/src/pf/...`) while content still lives at `pennyfarthing-dist/`. **Greening this suite is Plan 3's primary success signal.** There are ZERO chokepoint regressions from Plan 2 — do not touch `pf.paths`.
- **Plan 3 does NOT rewrite hooks.** That is Plan 4. The hook *content* (`scripts/hooks/*.sh`, `hooks/` if any) moves as plain files; their internals are not edited. The legacy-detection path in `hooks/session_start.py` is explicitly **kept** as-is.
- **No legacy install preservation, no migration tooling.** There is no `pip install`, `pipx`, or npm path to keep working. The `pf._dist` package (pip-bundled content) is deleted. Do not add `try/except ImportError` guards around `pf.*` imports — they are internal siblings and always importable.
- **`scripts/` merge decision (user-confirmed 2026-05-21):** the plugin root already has a small dev-only `scripts/` tree; `pennyfarthing-dist/scripts/` is a larger distributed tree. **Merge the distributed tree into the existing `scripts/`.** All colliding files were verified byte-identical, so collisions are resolved by keeping one copy. (See Task 4.)
- **Branch base:** the worktree is already on `feat/plugin-scaffold-and-paths` (off `develop`). All Plan 3 commits land on that same branch. When Plan 3's suite is green, Plan 2 + Plan 3 merge to `develop` together (out of plan scope — Keith does the merge).
- **GPG signing is required** on every commit. Never `--no-verify`, never `--amend`, never `--no-gpg-sign`. If signing fails, stop and tell the user.

---

## File Structure (after Plan 3)

```
orc-penny-pf-migration/                  # = plugin root (${CLAUDE_PLUGIN_ROOT})
├── .claude-plugin/{plugin.json,marketplace.json}
├── agents/                              # MOVED from pennyfarthing-dist/agents/ (no rename — never pf- prefixed)
├── commands/                            # MOVED + pf- prefix DROPPED (pf-work.md → work.md)
├── skills/                              # MOVED + pf- prefix DROPPED (pf-sprint/ → sprint/)
├── gates/  guides/  workflows/          # MOVED from pennyfarthing-dist/
├── personas/  templates/  output-styles/
├── schemas/  data/  patterns/  protocols/
├── command-registry.yaml  command-registry.schema.json  demo.yaml   # MOVED
├── scripts/                             # MERGED: dev-only tree + distributed tree
│   ├── core/ git/ health/ jira/ lib/ maintenance/ misc/ portraits/  # from dist
│   ├── sprint/ story/ test/ tests/ theme/ workflow/                  # from dist
│   ├── hooks/ utils/                                                 # merged (identical files)
│   ├── handoff-cli.sh migrate-assets-to-slug.sh resize-portraits.sh run.sh  # dev-only kept
├── runtime/
│   ├── pyproject.toml  uv.lock
│   └── src/pf/                          # Python package (NO _dist/ anymore)
│       ├── paths.py  common/config.py (get_dist_root rewritten)  ...
│       └── tests/
├── tests/                               # framework dev tests (unchanged location)
├── pyproject.toml                       # repo-root: testpaths + packages.find updated
└── (pennyfarthing-dist/  DELETED)
```

---

## Task 1: Pre-Flight — Confirm Worktree, Branch, and Baseline

**Files:** none (git + environment state only)

- [ ] **Step 1: Confirm you are in the migration worktree on the right branch**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
pwd
git branch --show-current
```

Expected: path is `/Users/slabgorb/Projects/orc-penny-pf-migration`; branch is `feat/plugin-scaffold-and-paths`. If either differs, **stop and ask** — do not switch branches or `cd` elsewhere.

- [ ] **Step 2: Inspect working tree state**

```bash
git status --short
```

Expected: at most an untracked `runtime/src/.session/` directory (a stray test artifact). If there are other uncommitted *tracked* changes, **stop and ask**.

- [ ] **Step 3: Remove the stray test artifact and ignore it**

```bash
rm -rf runtime/src/.session
grep -q '^\.session/$' runtime/.gitignore 2>/dev/null || printf '\n.session/\n' >> runtime/.gitignore
git status --short
```

Expected: clean tree except possibly a modified `runtime/.gitignore`. Stage and commit that gitignore tweak now so the tree is clean before content moves:

```bash
git add runtime/.gitignore
git commit -m "chore(runtime): ignore stray .session/ test artifact"
```

(If `runtime/.gitignore` already ignored `.session/`, skip the commit.)

- [ ] **Step 4: Capture the baseline test result**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/ -q 2>&1 | tail -3
```

Expected last line resembles: `188 failed, 4068 passed, 35 skipped, 19 warnings, 236 errors`. Record the exact four numbers. Plan 3's end state (Task 15) must show **0 failed, 0 errors** with passed count ≥ 4068 (minus any deliberately deleted obsolete tests, accounted for in Task 12).

- [ ] **Step 5: Verify the content actually lives in `pennyfarthing-dist/` and `_dist/` is broken**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
ls pennyfarthing-dist/agents/ | head -3
ls runtime/src/pf/_dist/agents/ 2>&1 | head -1   # expect: "No such file or directory" (broken symlink)
```

Expected: `pennyfarthing-dist/agents/` lists real `.md` files; `_dist/agents` is a dangling symlink. This confirms `pennyfarthing-dist/` is the real source of truth and `_dist/` is dead.

---

## Task 2: Move the Simple Content Directories to the Plugin Root

These directories have **no collision** at the plugin root and move wholesale via `git mv` (history preserved). `scripts/` is handled separately in Task 4 because it collides.

**Files:**
- Move: `pennyfarthing-dist/{agents,commands,skills,gates,guides,workflows,personas,templates,output-styles,schemas,data,patterns,protocols}` → plugin root
- Move: `pennyfarthing-dist/{command-registry.yaml,command-registry.schema.json,demo.yaml}` → plugin root

- [ ] **Step 1: Confirm none of these already exist at the plugin root**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
for d in agents commands skills gates guides workflows personas templates output-styles schemas data patterns protocols; do
  [ -e "$d" ] && echo "COLLISION: $d already exists at root" || true
done
echo "check complete"
```

Expected: only `check complete` (no `COLLISION` lines). If any collide, **stop and ask** — the plan assumed only `scripts/` collides.

- [ ] **Step 2: Move the content directories**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
for d in agents commands skills gates guides workflows personas templates output-styles schemas data patterns protocols; do
  git mv "pennyfarthing-dist/$d" "$d"
done
```

Expected: no output (success). Each is a tracked rename.

- [ ] **Step 3: Move the loose content files**

```bash
git mv pennyfarthing-dist/command-registry.yaml command-registry.yaml
git mv pennyfarthing-dist/command-registry.schema.json command-registry.schema.json
git mv pennyfarthing-dist/demo.yaml demo.yaml
```

Expected: no output. (If any of these three is absent, note it and continue — `ls pennyfarthing-dist/` to confirm what remains.)

- [ ] **Step 4: Repoint the repo-root tmux symlinks**

The plugin root has three symlinks (`tmux.conf.left`, `tmux.conf.right`, `tmux.conf.vert`) pointing into `pennyfarthing-dist/templates/`. After the move they dangle. Repoint them at the new `templates/` location.

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
ls -la tmux.conf.left tmux.conf.right tmux.conf.vert
```

Expected current targets like `pennyfarthing-dist/templates/tmux.conf.left.template`. Recreate them pointing at `templates/`:

```bash
ln -sf templates/tmux.conf.left.template tmux.conf.left
ln -sf templates/tmux.conf.right.template tmux.conf.right
ln -sf templates/tmux.conf.vert.template tmux.conf.vert
git add tmux.conf.left tmux.conf.right tmux.conf.vert
ls -la tmux.conf.left && readlink tmux.conf.left   # verify it resolves
test -f tmux.conf.left && echo "OK symlink resolves" || echo "BROKEN symlink"
```

Expected: `OK symlink resolves`. If `BROKEN`, inspect `templates/` for the real filename (`ls templates/tmux.conf.*`) and adjust.

- [ ] **Step 5: Verify what remains in `pennyfarthing-dist/`**

```bash
ls -la pennyfarthing-dist/
```

Expected remaining entries (handled later): `scripts/` (Task 4), `MANIFEST.in`, `tox.ini`, `.pypirc.template` (Task 4 Step 6), and possibly `data/` was moved already. Anything unexpected → record it; the final `pennyfarthing-dist/` deletion is Task 14.

- [ ] **Step 6: Commit the content move**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "feat(plugin): move framework content dirs to plugin root

git mv agents/, commands/, skills/, gates/, guides/, workflows/,
personas/, templates/, output-styles/, schemas/, data/, patterns/,
protocols/ and the command-registry + demo.yaml content files out of
pennyfarthing-dist/ up to the plugin root (siblings of runtime/), so
Claude Code surfaces them natively. Repoint repo-root tmux.conf
symlinks at the new templates/ location. History preserved via git mv.

Resolvers (get_dist_root) still point at the old layout and are fixed
in a later task; the suite is expected to stay red until then.

See: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md §3.1"
```

Expected: GPG-signed commit succeeds. Suite is still red at this point — that is expected; do not run it here.

---

## Task 3: Verify Claude Code Plugin Validation Still Passes

Moving `agents/`, `commands/`, `skills/` to the plugin root is what Claude Code's plugin loader expects. Validate the manifest now (a quick structural check before the larger edits).

**Files:** none

- [ ] **Step 1: Run plugin validation**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
claude plugin validate .
```

Expected: `✔ Validation passed`. If it fails complaining about command/skill naming (it should not yet — they still have `pf-` prefixes, which are valid filenames), record the exact error. The `pf-` prefix is dropped in Tasks 5–6; validation must still pass with the prefix present.

If validation fails for a missing `$schema` or similar manifest issue unrelated to this task, that is a Plan 2 carryover — note it and continue (do not fix manifest schema here unless it blocks).

---

## Task 4: Merge the Distributed `scripts/` Tree into the Plugin-Root `scripts/`

The plugin root already has a dev-only `scripts/` (entries: `generate-skill-docs.sh`, `handoff-cli.sh`, `hooks/`, `migrate-assets-to-slug.sh`, `README.md`, `resize-portraits.sh`, `run.sh`, `utils/`). The distributed `pennyfarthing-dist/scripts/` adds `core/ git/ health/ jira/ lib/ maintenance/ misc/ portraits/ sprint/ story/ test/ tests/ theme/ workflow/` and collides on `hooks/`, `utils/`, `README.md`. **All colliding files are byte-identical** (verified 2026-05-21), so we keep the existing copies and move only the non-colliding content in.

**Files:**
- Move: dist-only subdirs of `pennyfarthing-dist/scripts/` → `scripts/`
- Delete: byte-identical duplicate files under `pennyfarthing-dist/scripts/{hooks,utils,README.md}`

- [ ] **Step 1: Move the dist-only top-level subdirectories**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
for d in core git health jira lib maintenance misc portraits sprint story test tests theme workflow; do
  git mv "pennyfarthing-dist/scripts/$d" "scripts/$d"
done
```

Expected: no output. (If any listed subdir is absent, `ls pennyfarthing-dist/scripts/` and move only what exists.)

- [ ] **Step 2: Confirm the colliding files are byte-identical, then drop the dist duplicates**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
# hooks/ — every file should be identical
diff -rq scripts/hooks pennyfarthing-dist/scripts/hooks && echo "hooks identical" || echo "HOOKS DIFFER — inspect"
diff -q scripts/utils/generate-skill-docs.sh pennyfarthing-dist/scripts/utils/generate-skill-docs.sh && echo "utils identical"
diff -q scripts/README.md pennyfarthing-dist/scripts/README.md && echo "readme identical"
```

Expected: `hooks identical`, `utils identical`, `readme identical`. If any reports a difference, **stop and inspect** — manually merge the differing file (keep the dist version's behavior, since it is the canonical distributed copy) before deleting.

Once confirmed identical, remove the dist duplicates (keep the existing plugin-root copies):

```bash
git rm -r pennyfarthing-dist/scripts/hooks
git rm pennyfarthing-dist/scripts/utils/generate-skill-docs.sh
git rm pennyfarthing-dist/scripts/README.md
```

- [ ] **Step 3: Move any remaining files from `pennyfarthing-dist/scripts/utils/` and the dir itself**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
ls pennyfarthing-dist/scripts/utils/ 2>/dev/null   # any non-duplicate files left?
```

If files remain, `git mv` each into `scripts/utils/`. Then confirm `pennyfarthing-dist/scripts/` is empty:

```bash
find pennyfarthing-dist/scripts -type f 2>/dev/null
```

Expected: no output (empty). If files remain, `git mv` them to the matching `scripts/` location (they are dist-only) and re-check.

- [ ] **Step 4: Verify the formerly-broken symlink now resolves**

`scripts/utils/generate-skill-docs.sh` is a symlink `→ ../misc/generate-skill-docs.sh`. It was broken at the plugin root (no `misc/`) but Step 1 moved `misc/` in.

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
test -f scripts/utils/generate-skill-docs.sh && echo "symlink resolves" || echo "STILL BROKEN"
```

Expected: `symlink resolves`.

- [ ] **Step 5: Remove the now-empty dist scripts dir**

```bash
rmdir pennyfarthing-dist/scripts/utils 2>/dev/null || true
rmdir pennyfarthing-dist/scripts 2>/dev/null || true
ls pennyfarthing-dist/ | grep -c scripts || echo "scripts gone"
```

Expected: `scripts gone` (or `0`).

- [ ] **Step 6: Delete legacy packaging leftovers**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git rm pennyfarthing-dist/MANIFEST.in 2>/dev/null || true
git rm pennyfarthing-dist/tox.ini 2>/dev/null || true
git rm pennyfarthing-dist/.pypirc.template 2>/dev/null || true
ls -la pennyfarthing-dist/ 2>&1
```

These are setuptools/pip-publishing artifacts with no place in the plugin model. Record whatever still remains in `pennyfarthing-dist/` — ideally nothing, leaving it ready for outright deletion in Task 14.

- [ ] **Step 7: Commit the scripts merge**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "feat(plugin): merge distributed scripts/ into plugin-root scripts/

Move the distributed script subtrees (core, git, health, jira, lib,
maintenance, misc, portraits, sprint, story, test, tests, theme,
workflow) from pennyfarthing-dist/scripts/ into the existing
plugin-root scripts/. Colliding hooks/, utils/, and README.md were
byte-identical; the dist duplicates are dropped and the existing
copies kept. Delete legacy packaging files (MANIFEST.in, tox.ini,
.pypirc.template).

get_dist_root()/scripts/hooks now resolves at the plugin root.

See: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md §3.1"
```

---

## Task 5: Drop the `pf-` Prefix on Command Filenames (38 files)

Claude Code namespaces a plugin's commands as `<plugin>:<command-filename>`. With plugin name `pf`, `commands/work.md` surfaces as `/pf:work`. The hand-rolled `pf-` prefix would otherwise produce the redundant `/pf:pf-work`. Rename every `commands/pf-*.md` to drop the prefix.

**Files:**
- Rename: `commands/pf-*.md` → `commands/*.md` (38 files)

- [ ] **Step 1: List the prefixed command files and confirm the count**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
ls commands/ | grep '^pf-' | wc -l
ls commands/ | grep -v '^pf-'   # expect: no non-prefixed .md command files
```

Expected: `38`; the second command lists no `.md` files (only non-command entries if any). If the count differs from 38, do not silently adjust — record the actual list and proceed with whatever `pf-*.md` files exist.

- [ ] **Step 2: Rename each via `git mv`**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
for f in commands/pf-*.md; do
  base=$(basename "$f")
  git mv "$f" "commands/${base#pf-}"
done
ls commands/ | grep '^pf-' || echo "no pf- prefixed commands remain"
```

Expected: `no pf- prefixed commands remain`. Verify a sample resolved correctly:

```bash
ls commands/work.md commands/dev.md commands/sprint.md
```

Expected: all three exist.

- [ ] **Step 3: Commit the command rename**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "feat(plugin): drop pf- prefix from command filenames

Rename commands/pf-*.md -> commands/*.md (38 files) so Claude Code's
native pf: namespacing yields /pf:work, /pf:dev, etc. instead of the
redundant /pf:pf-work. Markdown cross-references (/pf-foo -> /pf:foo)
are updated in a later task.

See: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md §4"
```

---

## Task 6: Drop the `pf-` Prefix on Skill Directory Names (25 dirs)

Skills are surfaced by directory presence (`skills/<name>/SKILL.md`); the plugin namespaces them as `pf:<name>`. Rename each `skills/pf-*/` to drop the prefix. Leave non-skill entries (`skill-registry.yaml`, `skill-registry.schema.json`) untouched.

**Files:**
- Rename: `skills/pf-*/` → `skills/*/` (25 dirs)

- [ ] **Step 1: List the prefixed skill dirs and confirm the count**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
ls -d skills/pf-*/ | wc -l
ls skills/ | grep -v '^pf-'   # expect only: skill-registry.yaml, skill-registry.schema.json
```

Expected: `25`; the second lists only the two registry files. If different, record the actual set and proceed with the `pf-*` dirs that exist.

- [ ] **Step 2: Rename each skill dir via `git mv`**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
for d in skills/pf-*/; do
  base=$(basename "$d")
  git mv "$d" "skills/${base#pf-}"
done
ls -d skills/pf-*/ 2>/dev/null || echo "no pf- prefixed skills remain"
```

Expected: `no pf- prefixed skills remain`. Verify a sample:

```bash
ls skills/sprint/SKILL.md skills/testing/SKILL.md skills/handoff/SKILL.md
```

Expected: all exist (the `SKILL.md` filename inside is unchanged).

- [ ] **Step 3: Check the skill registry for stale `pf-` keys**

The registry files may key skills by their old prefixed names.

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -n 'pf-' skills/skill-registry.yaml | head -40
```

If the registry lists skill ids/paths like `pf-sprint` or `skills/pf-sprint/`, update them to the unprefixed form (`sprint`, `skills/sprint/`). Edit `skills/skill-registry.yaml` accordingly. If a test validates the registry against the directory listing (see `test_dist_root.py` / skill-command validators in Task 15), this keeps it consistent. If the registry has no `pf-` references, skip the edit.

- [ ] **Step 4: Commit the skill rename**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "feat(plugin): drop pf- prefix from skill directory names

Rename skills/pf-*/ -> skills/*/ (25 dirs) so the Skill tool surfaces
them as pf:sprint, pf:testing, etc. Update skill-registry.yaml keys to
the unprefixed form where present. SKILL.md filenames unchanged.

See: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md §6.4"
```

---

## Task 7: Update `/pf-foo` → `/pf:foo` References in Markdown Content

Markdown across `commands/`, `skills/`, `agents/`, `guides/`, `workflows/`, `schemas/`, `templates/`, `gates/` references slash commands as `/pf-foo`. These must become `/pf:foo` to match the new namespacing. There are ~600 occurrences across ~80 files.

**Files:**
- Modify: every markdown file under the moved content dirs containing `/pf-`

- [ ] **Step 1: Scope the references before changing anything**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -rl '/pf-' agents commands skills guides workflows schemas templates gates 2>/dev/null | sort > /tmp/pf_ref_files.txt
wc -l /tmp/pf_ref_files.txt
grep -rho '/pf-[a-z][a-z-]*' agents commands skills guides workflows schemas templates gates 2>/dev/null | sort | uniq -c | sort -rn | head -60
```

Record the distinct `/pf-foo` tokens. Cross-check each against the renamed command/skill list — every token should correspond to a real command (Task 5) or skill (Task 6). Flag oddballs like a bare `/pf-` (prefix in prose/regex) or `/pf-replay` (not a real command) for manual handling in Step 3.

- [ ] **Step 2: Apply the bulk transform `/pf-<word>` → `/pf:<word>`**

The transform replaces `/pf-` followed by a lowercase letter with `/pf:`. This avoids mangling unrelated strings (it requires the `/pf-` slash-prefixed form). Run it file-by-file over the scoped list:

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
while IFS= read -r f; do
  # Only rewrite the slash-command invocation form: /pf-<letter> -> /pf:<letter>
  perl -i -pe 's{/pf-([a-z])}{/pf:$1}g' "$f"
done < /tmp/pf_ref_files.txt
```

> Rationale for the regex: the `[a-z]` lookahead requires a real command word after `/pf-`, so a literal bare `/pf-` in prose (no following lowercase letter) is left alone for manual review. The `perl -i -pe` form edits in place without a backup file.

- [ ] **Step 3: Re-grep and manually resolve residual `/pf-` occurrences**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -rn '/pf-' agents commands skills guides workflows schemas templates gates 2>/dev/null
```

For each remaining hit, decide by hand:
  - Bare `/pf-` used as a literal prefix in documentation/regex → leave as-is or reword if it now reads wrong.
  - `/pf-replay` or any token with no matching command → likely a doc error; correct to the real command name or to `/pf:` form if it maps to something real.
  - Anything inside a fenced code block that is a *filename* reference (e.g. `commands/pf-work.md`) → that is a Task 8 concern (filename refs), not a slash-command ref; note it but do not change here.

Apply hand edits with the Edit tool. Re-grep until only intentional literals remain.

- [ ] **Step 4: Spot-check a converted file**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -n '/pf:' guides/handoff-cli.md | head -5     # adjust to a file you know had refs
```

Expected: shows `/pf:foo` forms. Confirm no `/pf::` (double colon) or `/pf:-` artifacts were introduced:

```bash
grep -rn '/pf::\|/pf:-' agents commands skills guides workflows schemas templates gates 2>/dev/null || echo "no artifacts"
```

Expected: `no artifacts`.

- [ ] **Step 5: Commit the reference update**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "docs(plugin): rewrite /pf-foo slash refs to /pf:foo

Bulk-convert /pf-<command> invocations to the native /pf:<command>
namespaced form across agents, commands, skills, guides, workflows,
schemas, templates, and gates markdown. Residual bare /pf- literals in
prose/regex left intentionally.

See: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md §4"
```

---

## Task 8: Update Filename References to Renamed Commands/Skills in Content & Code

Some markdown and Python references the old prefixed *filenames/paths* (e.g. `commands/pf-work.md`, `skills/pf-sprint`). These are distinct from slash-command refs (Task 7) and must point at the new unprefixed paths.

**Files:**
- Modify: any markdown/Python referencing `pf-*.md`, `commands/pf-`, `skills/pf-`

- [ ] **Step 1: Find filename/path references to the old prefixed names**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -rn 'commands/pf-\|skills/pf-\|pf-[a-z-]*\.md' \
  agents commands skills guides workflows schemas templates gates runtime/src/pf \
  --include='*.md' --include='*.py' --include='*.yaml' 2>/dev/null \
  | grep -v '__pycache__' | grep -v '/tests/'
```

Record the hits. Common forms:
  - `commands/pf-work.md` → `commands/work.md`
  - `skills/pf-sprint/` → `skills/sprint/`
  - `pf-dev.md` (in a guide) → `dev.md`

- [ ] **Step 2: Apply targeted edits**

For path-form references, transform with a path-aware substitution per file (only where the grep found hits):

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
# Rewrite commands/pf-foo and skills/pf-foo path references
grep -rl 'commands/pf-\|skills/pf-' agents commands skills guides workflows schemas templates gates runtime/src/pf --include='*.md' --include='*.py' --include='*.yaml' 2>/dev/null | grep -v __pycache__ | grep -v '/tests/' | while IFS= read -r f; do
  perl -i -pe 's{(commands/)pf-}{$1}g; s{(skills/)pf-}{$1}g' "$f"
done
```

For bare `pf-foo.md` filename references not preceded by a directory (rarer), handle with the Edit tool individually after re-grepping — a blanket `pf-*.md → *.md` substitution risks hitting prose, so do these by hand.

- [ ] **Step 3: Re-grep to confirm no stale prefixed paths remain**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -rn 'commands/pf-\|skills/pf-' agents commands skills guides workflows schemas templates gates runtime/src/pf --include='*.md' --include='*.py' --include='*.yaml' 2>/dev/null | grep -v __pycache__ | grep -v '/tests/' || echo "no stale prefixed paths"
```

Expected: `no stale prefixed paths`.

- [ ] **Step 4: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "docs(plugin): repoint filename refs at unprefixed commands/skills

Update commands/pf-foo.md and skills/pf-foo path references to the
renamed unprefixed locations across content and Python source."
```

(If Steps 1–3 found no hits, skip this task's commit and note that there were no filename references.)

---

## Task 9: Rewrite `get_dist_root()` for the Plugin-Root Layout

`pf.common.config.get_dist_root()` is the single content-path resolver (26 callers, each doing `get_dist_root() / "<contentdir>"`). It currently returns `pennyfarthing-dist/`. After the move, content lives at the plugin root, discoverable via `CLAUDE_PLUGIN_ROOT` (set by Claude Code in plugin context) or by walking up from `__file__` to the plugin root.

**Files:**
- Modify: `runtime/src/pf/common/config.py` (`get_dist_root`, lines ~71–123)
- Test: `runtime/src/pf/tests/test_dist_root.py`

- [ ] **Step 1: Read the existing test to learn the contract**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
sed -n '1,80p' runtime/src/pf/tests/test_dist_root.py
```

Read what `test_dist_root.py` asserts (return type, what subdir it checks for, how it sets up fixtures). The rewrite must keep these tests meaningful — update fixtures here if they construct a fake `pennyfarthing-dist/`.

- [ ] **Step 2: Write/adjust a failing test for plugin-root resolution**

Add to `runtime/src/pf/tests/test_dist_root.py` a test asserting that when `CLAUDE_PLUGIN_ROOT` is set to a dir containing `agents/` and `commands/`, `get_dist_root()` returns it; and that with the env unset, it falls back to the `__file__`-relative plugin root (the real repo root, which now has `agents/`):

```python
class TestPluginRootResolution:
    """get_dist_root resolves the plugin root in the plugin model (spec §3.1)."""

    def test_uses_claude_plugin_root_env(self, tmp_path, monkeypatch):
        (tmp_path / "agents").mkdir()
        (tmp_path / "commands").mkdir()
        monkeypatch.setenv("CLAUDE_PLUGIN_ROOT", str(tmp_path))
        from pf.common.config import get_dist_root
        assert get_dist_root() == tmp_path

    def test_env_ignored_when_content_absent(self, tmp_path, monkeypatch):
        # env points somewhere with no content dirs → fall through to __file__ root
        monkeypatch.setenv("CLAUDE_PLUGIN_ROOT", str(tmp_path))  # empty dir
        from pf.common.config import get_dist_root
        result = get_dist_root()
        # the real plugin root (repo root) has agents/ after the content move
        assert result is not None
        assert (result / "agents").is_dir()

    def test_fallback_to_file_relative_root(self, monkeypatch):
        monkeypatch.delenv("CLAUDE_PLUGIN_ROOT", raising=False)
        from pf.common.config import get_dist_root
        result = get_dist_root()
        assert result is not None
        assert (result / "agents").is_dir()
        assert (result / "commands").is_dir()
```

Run it (expect failure, since the implementation still looks for `pennyfarthing-dist/`):

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_dist_root.py::TestPluginRootResolution -v
```

Expected: the new tests FAIL (current impl returns None or the old path).

- [ ] **Step 3: Rewrite `get_dist_root` in `runtime/src/pf/common/config.py`**

Replace the entire `get_dist_root` function (currently lines ~71–123) with:

```python
def get_dist_root(project_root: Path | None = None) -> Path | None:
    """Resolve the plugin root, which holds the framework content directories.

    In the plugin model, content (agents/, commands/, skills/, gates/,
    guides/, workflows/, personas/, templates/, output-styles/, schemas/,
    scripts/, data/) lives at the plugin root — the directory that also
    contains ``.claude-plugin/`` and ``runtime/``.

    Resolution order:
      1. ``CLAUDE_PLUGIN_ROOT`` (set by Claude Code in plugin context), when
         it actually contains content (``agents/``).
      2. Relative to this file: ``runtime/src/pf/common/config.py`` → up 5
         levels to the plugin root. This covers the §5.2 user shim and any
         non-hook invocation where ``CLAUDE_PLUGIN_ROOT`` is unset.

    The ``project_root`` argument is retained for signature compatibility but
    is no longer used: framework content is bundled with the plugin, not the
    consumer's project.

    Returns the plugin root ``Path``, or ``None`` if content cannot be found.
    """
    env_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if env_root:
        candidate = Path(env_root).resolve()
        if (candidate / "agents").is_dir():
            return candidate

    # config.py → common → pf → src → runtime → <plugin root>
    plugin_root = Path(__file__).resolve().parents[4]
    if (plugin_root / "agents").is_dir() and (plugin_root / "commands").is_dir():
        return plugin_root

    return None
```

> Note: the old fallback #4 (`from pf._dist import get_root, is_populated`) is removed here — `pf._dist` is deleted in Task 10. Do not add a `try/except ImportError` for it.

- [ ] **Step 4: Confirm the new tests pass**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_dist_root.py -v
```

Expected: `TestPluginRootResolution` passes, and any pre-existing `test_dist_root.py` tests pass (update their fixtures if they built a fake `pennyfarthing-dist/`; replace that with `monkeypatch.setenv("CLAUDE_PLUGIN_ROOT", str(tmp_path))` + creating `tmp_path/"agents"` etc.). Do not weaken assertions to pass — adjust fixtures to the new layout.

- [ ] **Step 5: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add runtime/src/pf/common/config.py runtime/src/pf/tests/test_dist_root.py
git commit -m "feat(paths): resolve content via plugin root in get_dist_root

get_dist_root now returns the plugin root (CLAUDE_PLUGIN_ROOT when set
and populated, else __file__-relative parents[4]) where the content
dirs now live, instead of pennyfarthing-dist/. The project_root arg is
kept for compatibility but unused — content ships with the plugin. The
pip-bundled pf._dist fallback is dropped (the package is deleted next).

See: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md §3.1, §5.1"
```

---

## Task 10: Delete the Dead `pf._dist` Package and Its Import Sites

`runtime/src/pf/_dist/` is the pip-bundling shim: an `__init__.py` plus broken symlinks (`_dist/agents → ../../../agents`, now dangling). Two files import from it as a fallback. Both fallbacks are obsolete now that `get_dist_root` resolves the plugin root.

**Files:**
- Delete: `runtime/src/pf/_dist/` (whole package)
- Modify: `runtime/src/pf/init/core.py:1142–1144` (remove the `from pf._dist import ...` fallback)
- Verify: `runtime/src/pf/common/config.py` no longer imports `pf._dist` (handled in Task 9)

- [ ] **Step 1: Confirm the only remaining importers**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -rn 'pf\._dist\|from pf import _dist\|import _dist' runtime/src/pf/ --include='*.py' | grep -v __pycache__ | grep -v '/tests/'
```

Expected: only `runtime/src/pf/init/core.py` (around line 1144). `common/config.py` should no longer match (Task 9 removed it). If `config.py` still matches, the Task 9 edit was incomplete — fix it first.

- [ ] **Step 2: Read the `init/core.py` usage context**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
sed -n '1120,1160p' runtime/src/pf/init/core.py
```

Understand what the fallback does (it locates bundled portrait images when no `dist_root` is found). In the plugin model, `get_dist_root()` always resolves the plugin root which contains `personas/` (with portraits), so the `pf._dist` branch is dead.

- [ ] **Step 3: Remove the `pf._dist` fallback in `init/core.py`**

Delete the `try: from pf._dist import get_root, is_populated ... except` block (the lines around 1142–1150 that reference `pf._dist`). Replace its behavior with a direct `get_dist_root()`-based lookup. Concretely, find the block resembling:

```python
    # Fall back to pip-installed _dist (always has real images from wheel)
    try:
        from pf._dist import get_root, is_populated
        if is_populated():
            return get_root() / "personas" / ...
    except (ImportError, ModuleNotFoundError):
        pass
    return None
```

and replace it with the plugin-root resolution (use the actual surrounding variable/return shape you see in Step 2 — adapt this skeleton to match):

```python
    # Plugin model: content (incl. portraits) lives at the plugin root.
    dist_root = get_dist_root()
    if dist_root is not None:
        candidate = dist_root / "personas" / ...  # match the original subpath
        if candidate.exists():
            return candidate
    return None
```

Ensure `get_dist_root` is imported in `init/core.py` (it almost certainly already is — `grep -n 'get_dist_root' runtime/src/pf/init/core.py`). If not, add `from pf.common.config import get_dist_root`.

- [ ] **Step 4: Delete the `_dist` package**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git rm -r runtime/src/pf/_dist
```

Expected: removes `__init__.py` and the dangling symlinks.

- [ ] **Step 5: Verify nothing imports `_dist` anymore**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -rn 'pf\._dist\|import _dist' runtime/src/pf/ --include='*.py' | grep -v __pycache__ || echo "no _dist imports remain"
```

Expected: `no _dist imports remain` — **including test files**. If `runtime/src/pf/tests/` still imports `pf._dist`, those tests are obsolete (they tested the pip-bundling shim); they are handled in Task 12.

- [ ] **Step 6: Sanity-import the package**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run python -c "import pf.init.core; import pf.common.config; print('imports ok')"
```

Expected: `imports ok`. If `ModuleNotFoundError: pf._dist`, a non-test importer was missed — re-grep and fix.

- [ ] **Step 7: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "refactor(paths): delete dead pf._dist pip-bundling package

Remove runtime/src/pf/_dist/ (an __init__ plus now-dangling content
symlinks from the pip-install era) and its last importer fallback in
init/core.py, which now resolves portraits via get_dist_root() at the
plugin root. No try/except ImportError shims — pf.* are internal."
```

---

## Task 11: Make `get_project_root()` Resilient to `pennyfarthing-dist/` Removal

`get_project_root()` (99 callers) finds the *project* root by walking up for a `pennyfarthing-dist/` marker (preferred) then `.pennyfarthing/`. Deleting `pennyfarthing-dist/` removes the marker the framework repo relied on, so in-repo calls with no args would raise `FileNotFoundError`. Add `.claude-plugin/` as a recognized marker (it sits at the framework/plugin repo root).

**Files:**
- Modify: `runtime/src/pf/common/config.py` (`get_project_root`, lines ~16–64)
- Test: `runtime/src/pf/tests/test_dist_root.py` (or wherever project-root tests live)

- [ ] **Step 1: Add a failing test for the `.claude-plugin/` marker**

Add to the test file:

```python
class TestProjectRootPluginMarker:
    """get_project_root recognizes a .claude-plugin/ dir as a root marker."""

    def test_claude_plugin_marker(self, tmp_path, monkeypatch):
        monkeypatch.delenv("PROJECT_ROOT", raising=False)
        monkeypatch.delenv("CLAUDE_PROJECT_DIR", raising=False)
        (tmp_path / ".claude-plugin").mkdir()
        nested = tmp_path / "runtime" / "src"
        nested.mkdir(parents=True)
        from pf.common.config import get_project_root
        assert get_project_root(nested) == tmp_path.resolve()
```

Run (expect failure — current impl doesn't know `.claude-plugin/`):

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_dist_root.py::TestProjectRootPluginMarker -v
```

Expected: FAIL with `FileNotFoundError`.

- [ ] **Step 2: Add the marker to `get_project_root`**

In `get_project_root`, the first marker pass currently looks for a non-symlink `pennyfarthing-dist/`. Add a pass for `.claude-plugin/` *before* the `.pennyfarthing/` fallback. Edit the function so the marker walk also checks `.claude-plugin`:

```python
    # First pass: prefer pennyfarthing-dist/ (legacy framework repo layout)
    # or .claude-plugin/ (plugin repo root). Must be a real directory.
    check = current
    while check != check.parent:
        candidate = check / "pennyfarthing-dist"
        if candidate.is_dir() and not candidate.is_symlink():
            return check
        if (check / ".claude-plugin").is_dir():
            return check
        check = check.parent
```

(Keep the existing `.pennyfarthing/` second pass unchanged — it remains the consumer-project fallback / legacy detection.)

- [ ] **Step 3: Confirm the test passes**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/test_dist_root.py::TestProjectRootPluginMarker -v
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add runtime/src/pf/common/config.py runtime/src/pf/tests/test_dist_root.py
git commit -m "feat(paths): recognize .claude-plugin/ as a project-root marker

pennyfarthing-dist/ is being deleted, removing the marker get_project_root
walked up for in the framework repo. Add .claude-plugin/ (present at the
plugin repo root) to the first marker pass so in-repo no-arg calls keep
resolving. The .pennyfarthing/ consumer fallback is unchanged."
```

---

## Task 12: Fix Benchmark `__file__` Path Navigation and Prune Obsolete Install/Packaging Tests

Two cleanups: (a) `benchmark/pipeline_replay.py` and `benchmark/integration.py` compute dist-content paths via fragile `__file__` walks and hardcoded `"pennyfarthing-dist"` strings; reroute through `get_dist_root()`. (b) Tests that exercised the deleted pip-bundling/`.pennyfarthing/`-install surface are obsolete and must be removed (they import `pf._dist` or build wheels).

**Files:**
- Modify: `runtime/src/pf/benchmark/pipeline_replay.py` (lines ~129, 613–615, 1099–1100)
- Modify: `runtime/src/pf/benchmark/integration.py` (lines ~117–139)
- Delete/rework: obsolete test modules (enumerated below)

- [ ] **Step 1: Reroute `pipeline_replay.py` content lookups through `get_dist_root()`**

Confirm `get_dist_root` is imported (`grep -n 'get_dist_root\|from pf.common.config' runtime/src/pf/benchmark/pipeline_replay.py`); add `from pf.common.config import get_dist_root` if missing.

Replace line ~129:
```python
        agents_dir = pf_repo / "pennyfarthing-dist" / "agents"
```
with:
```python
        agents_dir = get_dist_root() / "agents"
```

Replace the two `lang-review` lookups (lines ~613–615 and ~1099–1100), each of which navigates `__file__` to reach `pennyfarthing-dist` then `gates/lang-review/<lang>.md`:
```python
            pf_dist = Path(__file__).parent.parent.parent  # ...
            pf_dist = pf_dist.parent  # → pennyfarthing-dist
            lang_review = pf_dist / "gates" / "lang-review" / f"{primary_lang}.md"
```
and
```python
        pf_dist = Path(__file__).parent.parent.parent.parent  # → pennyfarthing-dist
        lang_review = pf_dist / "gates" / "lang-review" / f"{primary_lang}.md"
```
with the single-line form (at each site):
```python
        lang_review = get_dist_root() / "gates" / "lang-review" / f"{primary_lang}.md"
```

> Guard for None if the surrounding code does not already: `dist = get_dist_root(); lang_review = dist / "gates" / ... if dist else None`. Match the existing None-handling style of each call site.

- [ ] **Step 2: Reroute `integration.py` theme path**

Replace line ~139:
```python
    return os.path.join(_project_root(), "pennyfarthing-dist", "personas", "themes")
```
with a `get_dist_root`-based form:
```python
    from pf.common.config import get_dist_root
    dist = get_dist_root()
    return str(dist / "personas" / "themes") if dist else ""
```

Inspect lines ~117–127 (`_project_root()` and its `"pennyfarthing-dist"` existence check). If `_project_root()` is used *only* to build the themes path, you may leave it (it still works via `get_project_root`), but its `pennyfarthing-dist` directory check at line 119 is now always false in-repo — update that check to also accept `.claude-plugin` or simply rely on `get_dist_root()`. Keep the change minimal: the themes path is the behavior under test.

- [ ] **Step 3: Identify obsolete test modules**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -rln 'pf\._dist\|import _dist' runtime/src/pf/tests/ --include='*.py' | grep -v __pycache__
```

Plus the known pip-packaging suite. The candidates for deletion (they test the deleted pip/wheel/`.pennyfarthing/`-symlink-install surface):
  - `runtime/src/pf/tests/test_pypi_packaging.py` — builds a wheel and asserts `pf._dist` content is bundled. Pip packaging is gone.
  - Any module from the `pf._dist` grep above that *only* asserts the bundled-package shim (e.g. checks `pf._dist.is_populated()`).

For each candidate, read it first:

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
sed -n '1,40p' runtime/src/pf/tests/test_pypi_packaging.py
```

- [ ] **Step 4: Delete the genuinely-obsolete modules; rework the salvageable ones**

Decision criteria:
  - Test asserts wheel build / `pf._dist` bundling / pip-install layout → **delete** (`git rm`).
  - Test asserts content *exists and is well-formed* but resolved it via `pf._dist` → **rework** to resolve via `get_dist_root()` instead of deleting (the content assertion is still valuable).

Example deletion:
```bash
git rm runtime/src/pf/tests/test_pypi_packaging.py
```

For reworks, change `from pf._dist import get_root` → `from pf.common.config import get_dist_root` and `get_root()` → `get_dist_root()` within the test, keeping its content assertions intact. Read each before deciding; record in the commit message which were deleted vs reworked, and adjust the Task 1 baseline expectation (passed count drops by the number of *deleted* tests, not reworked ones).

- [ ] **Step 5: Run the benchmark and affected test modules**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/ -q -k "benchmark or pipeline or integration or dist_root or packaging" 2>&1 | tail -15
```

Expected: no failures/errors in the selected set (deleted modules simply do not collect).

- [ ] **Step 6: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "refactor(benchmark): resolve dist content via get_dist_root; drop pip tests

Reroute pipeline_replay.py and integration.py off fragile __file__
navigation and hardcoded 'pennyfarthing-dist' strings onto
get_dist_root(). Delete obsolete pip-packaging/_dist-bundling tests
(test_pypi_packaging.py, ...) that asserted a wheel layout the plugin
model no longer has; rework content-existence tests to use get_dist_root."
```

---

## Task 13: Rework the Remaining Legacy `.pennyfarthing/`-Install Sites

Per the Plan 3 brief, these modules still reference the legacy `.pennyfarthing/` layout. They split into **keep** (legacy *detection*, still valid) and **rework/delete** (legacy *creation*, obsolete in the plugin model). The goal here is only to (a) stop anything from importing deleted symbols and (b) keep their tests green — **not** to fully redesign `pf init` (that is beyond Plan 3). Be conservative: make the minimal change that greens the suite without breaking legacy-detection behavior.

**Files (per Explore findings):**
- KEEP as-is (legacy *detection* — do not change): `runtime/src/pf/hooks/session_start.py:~240–269`, `runtime/src/pf/doctor/checks.py`, `runtime/src/pf/config_migration.py`, `runtime/src/pf/healthscore/analyze.py:~660–667`, `runtime/src/pf/upgrade/core.py`
- REWORK only if their tests fail after the move: `runtime/src/pf/init/setup.py`, `runtime/src/pf/init/core.py`

- [ ] **Step 1: Run the full suite to see what legacy sites actually break**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/ -q 2>&1 | tail -25 > /tmp/plan3_after_core.txt
cat /tmp/plan3_after_core.txt
```

Record the remaining failures/errors. Categorize each failing test by the module it exercises (init, upgrade, doctor, healthscore, hooks, agent_create, etc.).

- [ ] **Step 2: For each failing legacy test, diagnose create-vs-detect**

For every failure, open the test and the code it drives. Apply this rule:
  - **Failure because content moved** (test resolves `get_dist_root()/...` and the impl still hardcoded `pennyfarthing-dist` or `pf._dist`): fix the *impl* to use `get_dist_root()`. This is the common, safe fix.
  - **Failure because the test asserts the legacy `.pennyfarthing/` *install* is created** (symlinks/copies into `.pennyfarthing/`): the install behavior is obsolete in the plugin model. Prefer **deleting the obsolete test** over rewriting `pf init` end-to-end. Record the deletion and rationale.
  - **Legacy *detection* test** (asserts the code notices a pre-existing `.pennyfarthing/`): **keep** both test and impl; if it fails, it is incidental to the content move — fix the resolver, not the detection logic.

- [ ] **Step 3: Apply minimal impl fixes**

Typical fix — in `init/core.py` or `agent_create.py`, a hardcoded content path like `root / "pennyfarthing-dist" / "agents"` becomes `get_dist_root() / "agents"`. Re-grep for stragglers:

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -rn '"pennyfarthing-dist"\|/ "pennyfarthing-dist"\|pennyfarthing-dist/' runtime/src/pf/ --include='*.py' | grep -v __pycache__ | grep -v '/tests/'
```

For each remaining production hit, decide:
  - Content lookup → reroute through `get_dist_root()`.
  - Legacy-detection string (e.g. checking whether a *consumer* has an inlined `pennyfarthing/pennyfarthing-dist/`) → may stay, but confirm a test still justifies it; if it is dead, remove it.

Do **not** touch `hooks/session_start.py`'s legacy-detection path (keep its old `.pennyfarthing/` references — Plan 4 owns hooks).

- [ ] **Step 4: Re-run the suite**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/ -q 2>&1 | tail -5
```

Iterate Steps 2–3 until failures/errors are driven to zero (or only deliberately-deleted obsolete modules are gone). If a class of failures is larger or more entangled than this task anticipated (e.g. `pf init` needs a real redesign to pass), **stop and surface it** — that may be Plan 4 scope, not Plan 3.

- [ ] **Step 5: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "refactor(paths): reroute legacy install sites off pennyfarthing-dist

Point remaining production content lookups (init/, agent_create, etc.)
at get_dist_root(); delete obsolete tests that asserted the legacy
.pennyfarthing/ install layout. Legacy-detection paths (doctor,
healthscore, config_migration, upgrade, hooks/session_start) are left
intact — they detect pre-existing legacy installs, which is still valid."
```

---

## Task 14: Delete `pennyfarthing-dist/` Entirely and Update Repo-Root `pyproject.toml`

With all content moved and resolvers repointed, `pennyfarthing-dist/` should be empty. Delete it, and fix the repo-root `pyproject.toml`, which still declares the legacy setuptools layout (`packages.find` at `pennyfarthing-dist/src`, `package-data` for `pf._dist`, `testpaths` at `pennyfarthing-dist/src/pf/tests`).

**Files:**
- Delete: `pennyfarthing-dist/` (and possibly repo-root `setup.py` if it references the dead layout)
- Modify: `pyproject.toml` (repo root)

- [ ] **Step 1: Confirm `pennyfarthing-dist/` is empty of meaningful files**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
find pennyfarthing-dist -type f 2>/dev/null
find pennyfarthing-dist -type l 2>/dev/null
```

Expected: no output (no files, no symlinks). If anything remains, move it to the right plugin-root location (content) or `git rm` it (legacy packaging), and re-check. Do not delete the directory while real files remain.

- [ ] **Step 2: Delete the directory**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git rm -r pennyfarthing-dist 2>/dev/null || rm -rf pennyfarthing-dist
git status --short | grep pennyfarthing-dist || echo "pennyfarthing-dist gone"
```

Expected: `pennyfarthing-dist gone` (or staged deletions).

- [ ] **Step 3: Update the repo-root `pyproject.toml`**

Edit `pyproject.toml` at the repo root:
  - `[tool.pytest.ini_options] testpaths` → `["runtime/src/pf/tests"]`
  - `[tool.setuptools.packages.find] where` → `["runtime/src"]`
  - Remove the `[tool.setuptools.package-data] "pf._dist" = [...]` block entirely (the package is deleted).

Resulting relevant sections:

```toml
[tool.setuptools.packages.find]
where = ["runtime/src"]
include = ["pf*"]

[tool.pytest.ini_options]
testpaths = ["runtime/src/pf/tests"]
python_files = ["test_*.py"]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
```

(Delete the `[tool.setuptools.package-data]` block. Leave `[project]`, `dependencies`, `[tool.ruff]` as-is.)

- [ ] **Step 4: Check repo-root `setup.py`**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
grep -n 'pennyfarthing-dist\|_dist\|package_dir\|src' setup.py
```

If `setup.py` hardcodes `pennyfarthing-dist/src`, update it to `runtime/src` for parity, OR — since the runtime is built from `runtime/pyproject.toml` (hatchling) in the plugin model and this repo-root setuptools build is legacy — note whether it is still needed. Make the minimal change: if a test (`test_pypi_packaging.py` was deleted in Task 12) or tooling builds from repo root, point it at `runtime/src`; otherwise leave a TODO comment is **not** allowed (no placeholders) — either fix it to `runtime/src` or, if confirmed dead, `git rm setup.py`. Decide based on whether anything references it (`grep -rn 'setup.py' justfile scripts/ runtime/ tests/`).

- [ ] **Step 5: Verify pytest still discovers from repo root**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/ --collect-only -q 2>&1 | tail -3
```

Expected: collects the full suite with no collection errors.

- [ ] **Step 6: Commit**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "feat(plugin): delete pennyfarthing-dist/ and fix repo-root pyproject

All content moved to the plugin root; pennyfarthing-dist/ is empty and
removed. Repo-root pyproject.toml testpaths/packages.find now point at
runtime/src; the dead pf._dist package-data block is dropped. setup.py
updated/removed to match the runtime/ layout.

Completes the §3.1 content migration.
See: docs/superpowers/specs/2026-05-21-pennyfarthing-as-plugin-design.md §3.1, §8.3"
```

---

## Task 15: Green the Full Suite and Validate the Plugin

**Files:** none (verification); fix-ups as needed

- [ ] **Step 1: Run the entire suite**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run --extra test pytest src/pf/tests/ -q 2>&1 | tail -8
```

Expected: `0 failed`, `0 errors`. Passed count should be ≥ baseline 4068 minus the count of deliberately-deleted obsolete tests (Tasks 12–13). Skips may differ slightly. If any failure/error remains:
  - Content-resolution failure → a missed `pennyfarthing-dist`/`pf._dist`/`__file__` site; grep and reroute through `get_dist_root()`.
  - Legacy-install failure → re-apply the Task 13 create-vs-detect rule.
  - Do **not** weaken assertions or `skip`/`xfail` to force green — fix the cause.

- [ ] **Step 2: Confirm no stale references remain anywhere in production code**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
echo "--- pennyfarthing-dist refs (prod) ---"
grep -rn 'pennyfarthing-dist' runtime/src/pf/ --include='*.py' | grep -v __pycache__ | grep -v '/tests/' || echo none
echo "--- pf._dist refs ---"
grep -rn 'pf\._dist' runtime/src/pf/ --include='*.py' | grep -v __pycache__ || echo none
echo "--- /pf- slash refs in content ---"
grep -rn '/pf-[a-z]' agents commands skills guides workflows 2>/dev/null || echo none
```

Expected: `none` for `pf._dist` and `/pf-` slash refs. A small number of *intentional* legacy-detection `pennyfarthing-dist` references may remain (e.g. detecting a consumer's inlined framework) — confirm each is justified by a passing test; otherwise remove.

- [ ] **Step 3: Validate the plugin manifest**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
claude plugin validate .
```

Expected: `✔ Validation passed`.

- [ ] **Step 4: Smoke-test the runtime entrypoint**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration/runtime
uv run pf --version
CLAUDE_PLUGIN_ROOT="$(cd .. && pwd)" uv run python -c "from pf.common.config import get_dist_root; r=get_dist_root(); print('dist root:', r); assert (r/'agents').is_dir() and (r/'commands').is_dir() and (r/'skills').is_dir(); print('content resolves OK')"
```

Expected: prints the version, the plugin root, and `content resolves OK`.

- [ ] **Step 5: Commit any fix-ups**

If Steps 1–2 required fixes, commit them:

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git add -A
git commit -m "fix(plugin): reroute final stray content lookups to get_dist_root

Drive the suite to 0 failed / 0 errors after the content migration."
```

(If no fix-ups were needed, skip.)

---

## Task 16: Push and Hand Off to Plan 4

**Files:** none

- [ ] **Step 1: Review the commit series**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git log --oneline origin/feat/plugin-scaffold-and-paths..HEAD
```

Expected: the Plan 3 commits (content move, scripts merge, command rename, skill rename, ref rewrites, get_dist_root, _dist deletion, get_project_root marker, benchmark/test cleanup, legacy rework, pennyfarthing-dist deletion, green fix-ups). No fixup-of-fixup churn.

- [ ] **Step 2: Confirm GPG signatures on the new commits**

```bash
git log --show-signature -1 2>&1 | grep -i 'good signature' && echo "signed OK"
```

Expected: `signed OK`. If any Plan 3 commit is unsigned, **stop and tell the user** (do not rewrite history to re-sign without explicit instruction).

- [ ] **Step 3: Push the branch**

```bash
cd /Users/slabgorb/Projects/orc-penny-pf-migration
git push origin feat/plugin-scaffold-and-paths
```

Expected: push succeeds (the branch already tracks origin from Plan 2; this adds Plan 3's commits). The branch targets `develop` for any PR — not `main`.

- [ ] **Step 4: Report completion**

Summarize for the user: suite is green (state the final passed/skipped numbers and that failed=errors=0), `pennyfarthing-dist/` is gone, commands/skills are unprefixed, plugin validates. Note that **Plan 4 (hooks rewrite)** is next: create `hooks/hooks.json`, rewrite `scripts/hooks/*.sh` as `uv run` wrappers, rewrite `sprint-yaml-validation` in Python, and resolve open question Q4 (plugin permissions / env merging). Plan 2 + Plan 3 merge to `develop` together when Keith is ready (out of plan scope).

- [ ] **Step 5: This plan ends here.**

---

## Acceptance Criteria

Plan 3 is complete when all of the following hold (verified in the worktree on `feat/plugin-scaffold-and-paths`):

1. Content directories (`agents/`, `commands/`, `skills/`, `gates/`, `guides/`, `workflows/`, `personas/`, `templates/`, `output-styles/`, `schemas/`, `scripts/`, `data/`, `patterns/`, `protocols/`) and the registry/`demo.yaml` files live at the plugin root; `git mv` preserved history.
2. `pennyfarthing-dist/` no longer exists.
3. Command files have no `pf-` prefix (`/pf:work` resolves to `commands/work.md`); skill dirs have no `pf-` prefix (`pf:sprint` → `skills/sprint/`). Agents are unchanged (were never prefixed).
4. No markdown contains `/pf-foo` slash-command references (only intentional bare-`/pf-` literals, if any); no content/code references the old `commands/pf-*` or `skills/pf-*` paths.
5. `pf.common.config.get_dist_root()` resolves the plugin root (via `CLAUDE_PLUGIN_ROOT` or `__file__` parents[4]); all 26 callers resolve content correctly. `get_project_root()` recognizes `.claude-plugin/` as a marker.
6. The `pf._dist` package is deleted; nothing imports it; no `try/except ImportError` shims were added for `pf.*`.
7. `benchmark/pipeline_replay.py` and `benchmark/integration.py` resolve content via `get_dist_root()`, not `__file__` navigation or hardcoded `"pennyfarthing-dist"`.
8. Legacy-*detection* sites (`doctor/checks.py`, `healthscore/analyze.py`, `config_migration.py`, `upgrade/core.py`, `hooks/session_start.py`) are unchanged in behavior; legacy-*creation*/pip-packaging tests are deleted.
9. Repo-root `pyproject.toml` `testpaths`/`packages.find` point at `runtime/src`; the `pf._dist` `package-data` block is removed.
10. `cd runtime && uv run --extra test pytest src/pf/tests/ -q` reports **0 failed, 0 errors** (passed ≥ 4068 − deleted-obsolete-test count).
11. `claude plugin validate .` passes.
12. All commits are GPG-signed, follow `<type>(<scope>): <subject>`, and are pushed to `origin/feat/plugin-scaffold-and-paths`.

---

## Notes for the Executor

- **Worktree, not `pennyfarthing/`.** Every command runs in `/Users/slabgorb/Projects/orc-penny-pf-migration`. The `pf` shim points at `…/orc-penny-pf-migration/runtime`, so plain `pf` and `uv run pf` both exercise this branch's runtime.
- **`--extra test` is mandatory** on every `pytest` invocation, or async tests error spuriously.
- **Trust the spike, then the spec, then this plan.** If the spec contradicts a spike finding, the spike wins. If this plan's line numbers are stale (earlier tasks shift them), re-grep before editing — line numbers were captured pre-execution.
- **No `try/except ImportError` around `pf.*` imports** — they are internal siblings, always importable. A guarded import is a forbidden anti-pattern here.
- **Grep traps:** path construction takes multiple forms. When sweeping for content-path sites, check all of: `/ "pennyfarthing-dist"`, `Path(a, b, c)` comma-form, two-step `pf_dir = root / "x"` then `pf_dir / "y"`, `os.path.join(..., "pennyfarthing-dist", ...)`, and bare string literals `"pennyfarthing-dist/..."`. The Task 15 Step 2 grep is the backstop.
- **Don't redesign `pf init`.** Task 13 is deliberately conservative: reroute content lookups, delete obsolete create-tests, keep detection. A genuine `pf init` redesign is out of scope — surface it if the suite demands it.
- **Process:** execute with superpowers:subagent-driven-development — fresh implementer per task, then a spec-compliance review, then a code-quality review. Commit per task (GPG-signed). Never `--no-verify` or `--amend`.
- **Commit hygiene:** one commit per task as written. If a task makes no changes (e.g. Task 8 finds no filename refs), skip its commit and note it.
